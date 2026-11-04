import psutil, socket
import Pyro4
import Pyro4.naming
from .qick_asm import QickConfig
# QickSoc is needed for the server but not the client
# the client needs it to be defined because it's in the start_server definition
# but it doesn't need to be anything, so we use None as a dummy value
try:
    from .qick import QickSoc
except:
    QickSoc = None

import threading, time, functools, inspect

class ClientLock:
    """Gives one Pyro client (connection) at a time exclusive use of the QICK.

    A client becomes the owner on its first call, and stays the owner while it has a call in progress
    and for hold_time seconds after its last call (so a multi-round acquire() or a sweep loop is not interrupted).
    Other clients wait in a first-come-first-served queue until the owner is idle or disconnects.
    A client can either just make a call (it blocks until the QICK is free),
    or poll wait_for_lock() to get status updates (owner, queue position, owner progress) while it waits.
    Calls that don't come from a Pyro client (e.g. the streamer thread, or the QickSoc constructor) are never blocked.
    """
    def __init__(self, hold_time=5.0, queue_timeout=10.0):
        self.hold_time = hold_time
        # a queued client that stops polling wait_for_lock() for this long loses its place
        self.queue_timeout = queue_timeout
        # optional callable returning server-side readout progress, set by start_server()
        self.readout_progress = None
        # Condition uses an RLock, so nested calls within the same thread are fine
        self._cond = threading.Condition()
        self._owner = None
        self._active = 0
        self._last = 0.0
        self._addrs = {}     # client -> address, for clients that are queued or own the lock
        self._queue = []     # waiting clients, oldest first
        self._seen = {}      # client -> last time it was seen waiting
        self._progress = None  # (client, info dict, time) reported by the owner

    def _owner_busy(self):
        if self._owner is None:
            return False
        if self._active > 0:
            return True
        return time.time() - self._last < self.hold_time

    def _expire_queue(self):
        now = time.time()
        for client in list(self._queue):
            if now - self._seen.get(client, 0) > self.queue_timeout:
                print("QICK lock: client %s stopped waiting, removed from queue" % (self._addrs.get(client),))
                self._dequeue(client)

    def _dequeue(self, client):
        if client in self._queue:
            self._queue.remove(client)
        self._seen.pop(client, None)
        if client is not self._owner:
            self._addrs.pop(client, None)

    def _try_take(self, client, addr):
        """Wait in the queue for one step. Return True if the client now owns the lock."""
        if self._owner is client:
            return True
        if client not in self._queue:
            self._queue.append(client)
            self._addrs[client] = addr
            if self._owner_busy():
                print("QICK lock: client %s is waiting for client %s" % (addr, self._addrs.get(self._owner)))
        self._seen[client] = time.time()
        self._expire_queue()
        if self._owner_busy() or self._queue[0] is not client:
            return False
        self._queue.remove(client)
        self._seen.pop(client, None)
        if self._owner is not None:
            self._addrs.pop(self._owner, None)
        self._owner = client
        self._addrs[client] = addr
        self._active = 0
        self._last = time.time()
        self._progress = None
        print("QICK lock: client %s now owns the QICK" % (addr,))
        self._cond.notify_all()
        return True

    def enter(self, client, addr):
        with self._cond:
            # hold-time expiry doesn't notify, so wake up periodically
            while not self._try_take(client, addr):
                self._cond.wait(timeout=0.2)
            self._active += 1
            self._last = time.time()

    def exit(self, client):
        with self._cond:
            if self._owner is client:
                self._active -= 1
                self._last = time.time()
            self._cond.notify_all()

    def wait(self, client, addr, timeout):
        """Wait up to timeout seconds for the lock. Return a status dict; status['granted'] says if we got it.
        A granted client keeps the lock for hold_time seconds, so it should start using the QICK right away."""
        end = time.time() + max(0.0, float(timeout))
        with self._cond:
            while not self._try_take(client, addr):
                remaining = end - time.time()
                if remaining <= 0:
                    break
                self._cond.wait(timeout=min(0.2, remaining))
            else:
                self._last = time.time()
            return self._status(client, addr)

    def report_progress(self, client, info):
        """The owner can report its progress, so waiting clients can see it."""
        with self._cond:
            if self._owner is client:
                self._progress = (client, dict(info), time.time())

    def release(self, client):
        """Called when a client disconnects."""
        with self._cond:
            if self._owner is client:
                print("QICK lock: owner %s disconnected, releasing" % (self._addrs.get(client),))
                self._owner = None
                self._active = 0
                self._progress = None
            self._dequeue(client)
            self._addrs.pop(client, None)
            self._cond.notify_all()

    def _status(self, client, addr):
        busy = self._owner_busy()
        owner = self._owner if busy else None
        progress = None
        if owner is not None and self._progress is not None and self._progress[0] is owner:
            progress = dict(self._progress[1], age=time.time() - self._progress[2])
        readout = None
        if owner is not None and self.readout_progress is not None:
            try:
                readout = self.readout_progress()
            except Exception:
                readout = None
        position = self._queue.index(client) + 1 if client in self._queue else None
        return {'granted': owner is client or (owner is None and position is None),
                'you': addr,
                'owner': self._addrs.get(owner) if owner is not None else None,
                'owner_progress': progress,
                'owner_readout': readout,
                'position': position,
                'queue': [self._addrs.get(c) for c in self._queue],
                'idle_time': time.time() - self._last if owner is not None else None,
                'hold_time': self.hold_time}

    def status(self, client, addr):
        with self._cond:
            return self._status(client, addr)

def _pyro_caller():
    ctx = Pyro4.current_context
    return getattr(ctx, 'client', None), getattr(ctx, 'client_sock_addr', None)

def _locked_method(func, lock):
    @functools.wraps(func)
    def wrapper(*args, **kwargs):
        client, addr = _pyro_caller()
        if client is None:
            # not a Pyro request (internal call from a server-side thread)
            return func(*args, **kwargs)
        lock.enter(client, addr)
        try:
            return func(*args, **kwargs)
        finally:
            lock.exit(client)
    return wrapper

# methods that clients may call without waiting for the lock
LOCK_EXEMPT = {'get_cfg', 'dump_cfg', 'get_lock_status', 'wait_for_lock', 'report_lock_progress'}

def _make_locked_class(cls, lock):
    """Make a subclass of cls where every public method goes through the ClientLock."""
    attrs = {}
    for name in dir(cls):
        if name.startswith('_') or name in LOCK_EXEMPT:
            continue
        raw = inspect.getattr_static(cls, name)
        if inspect.isfunction(raw):
            attrs[name] = _locked_method(raw, lock)

    def get_lock_status(self):
        """Who owns the QICK, the queue, and the owner's progress. Never blocks."""
        return lock.status(*_pyro_caller())

    def wait_for_lock(self, timeout=1.0):
        """Wait up to timeout seconds to become the QICK owner, holding a place in the queue.
        Returns the get_lock_status() dict; 'granted' is True once this client owns the QICK.
        Call this repeatedly (at least every few seconds) to keep your place in the queue."""
        client, addr = _pyro_caller()
        if client is None:
            return {'granted': True}
        return lock.wait(client, addr, timeout)

    def report_lock_progress(self, info):
        """Owner-only: publish a progress dict (e.g. completed/total) for waiting clients to see."""
        client, _ = _pyro_caller()
        if client is not None:
            lock.report_progress(client, info)

    attrs.update(get_lock_status=get_lock_status, wait_for_lock=wait_for_lock,
                 report_lock_progress=report_lock_progress)
    return type(cls.__name__, (cls,), attrs)

class _LockingDaemon(Pyro4.Daemon):
    """Pyro daemon that releases the QICK lock when the owning client disconnects."""
    def __init__(self, lock, **kwargs):
        super().__init__(**kwargs)
        self._qick_lock = lock

    def clientDisconnect(self, conn):
        self._qick_lock.release(conn)
        super().clientDisconnect(conn)

def start_nameserver(ns_host='0.0.0.0', ns_port=8888):
    """Starts a Pyro4 nameserver.

    Parameters
    ----------
    ns_host : str
        the nameserver hostname
    ns_port : int
        the port number for the nameserver to listen on

    Returns
    -------
    """
    Pyro4.config.SERIALIZERS_ACCEPTED = set(['pickle'])
    Pyro4.config.PICKLE_PROTOCOL_VERSION=4
    Pyro4.naming.startNSloop(host=ns_host, port=ns_port)

def start_server(ns_host, ns_port=8888, proxy_name='myqick', soc_class=QickSoc, iface='eth0', client_lock=True, lock_hold_time=5.0, **kwargs):
    """Initializes the QickSoc and starts a Pyro4 proxy server.

    Parameters
    ----------
    ns_host : str
        hostname or IP address of the nameserver
        if the nameserver is running on the QICK board, "localhost" is fine
    ns_port : int
        the port number you used when starting the nameserver
    proxy_name : str
        name for the QickSoc proxy
        multiple boards can use the same nameserver, but must have different names
    soc_class : class
        class to proxy, if you want to use a class other than QickSoc (e.g. if you need to use RFQickSoc)
    iface : str
        network interface whose address will be advertised - this should be the interface you expect to make Pyro connections on
    client_lock : bool
        if True, only one client at a time can use the QICK; calls from other clients wait until it is free
        (the owner is free once it has been idle for lock_hold_time seconds, or disconnects)
    lock_hold_time : float
        how long (in seconds) a client keeps ownership after its last call;
        must be longer than the client-side gaps between calls within a measurement (e.g. between rounds or sweep points)
    kwargs : optional named arguments
        any other options will be passed to the QickSoc constructor;
        see QickSoc documentation for details

    Returns
    -------
    """
    Pyro4.config.REQUIRE_EXPOSE = False
    Pyro4.config.SERIALIZER = "pickle"
    Pyro4.config.SERIALIZERS_ACCEPTED=set(['pickle'])
    Pyro4.config.PICKLE_PROTOCOL_VERSION=4

    print("looking for nameserver . . .")
    ns = Pyro4.locateNS(host=ns_host, port=ns_port)
    print("found nameserver")

    # if we have multiple network interfaces, we want to register the daemon using the IP address that faces the nameserver
    host = Pyro4.socketutil.getInterfaceAddress(ns._pyroUri.host)
    # if the nameserver is running on the QICK, the above will usually return the loopback address - not useful
    if host=="127.0.0.1":
        # if the eth0 interface has an IPv4 address, use that
        # otherwise use the address of any interface starting with "eth0" (e.g. eth0:1, which is typically a static IP)
        # unless you have an unusual network config (e.g. VPN), this is the interface clients will want to connect to
        for name, addrs in psutil.net_if_addrs().items():
            addrs_v4 = [addr.address for addr in addrs if addr.family==socket.AddressFamily.AF_INET]
            if len(addrs_v4)==1:
                if name.startswith(iface):
                    host = addrs_v4[0]
                if name==iface:
                    break
    if client_lock:
        lock = ClientLock(hold_time=lock_hold_time)
        daemon = _LockingDaemon(lock, host=host)
        soc_class = _make_locked_class(soc_class, lock)
    else:
        daemon = Pyro4.Daemon(host=host)

    # if you want to use a different firmware image or set some initialization options, you would do that here
    soc = soc_class(**kwargs)
    print("initialized QICK")

    if client_lock:
        # the autoproxied members (tProc, streamer) can be called directly by clients, so lock them too
        for obj in soc.autoproxy:
            obj.__class__ = _make_locked_class(type(obj), lock)
        # let waiting clients see the progress of the current readout (shots in this round)
        streamer = getattr(soc, 'streamer', None)
        if streamer is not None:
            def readout_progress():
                if streamer.done_flag.is_set():
                    return None
                return {'completed': int(streamer.count), 'total': int(streamer.total_count), 'unit': 'shot'}
            lock.readout_progress = readout_progress
        print("client lock enabled (hold time %.1f s)" % (lock_hold_time,))

    # register the QickSoc in the daemon (so the daemon exposes the QickSoc over Pyro4)
    # and in the nameserver (so the client can find the QickSoc)
    ns.register(proxy_name, daemon.register(soc))
    print("registered QICK")

    # register in the daemon all the objects we expose as properties of the QickSoc
    # we don't register them in the nameserver, since they are only meant to be accessed through the QickSoc proxy
    # https://pyro4.readthedocs.io/en/stable/servercode.html#autoproxying
    # https://github.com/irmen/Pyro4/blob/master/examples/autoproxy/server.py
    for obj in soc.autoproxy:
        daemon.register(obj)
        print("registered member "+str(obj))
                    
    print("starting daemon")
    daemon.requestLoop() # this will run forever until interrupted

def make_proxy(ns_host, ns_port=8888, proxy_name='myqick', remote_traceback=True):
    """Connects to a QickSoc proxy server.

    Parameters
    ----------
    ns_host : str
        hostname or IP address of the nameserver
        if the nameserver is running on the same PC you are running make_proxy() on, "localhost" is fine
    ns_port : int
        the port number you used when starting the nameserver
    proxy_name : str
        name for the QickSoc proxy you used when running start_server()
    remote_traceback : bool
        if running in IPython (Jupyter etc.), reconfigure the IPython exception handler to print the remote Pyro traceback

    Returns
    -------
    Proxy
        proxy to QickSoc - this is usually called "soc" in demos
    QickConfig
        config object - this is usually called "soccfg" in demos
    """
    Pyro4.config.SERIALIZER = "pickle"
    Pyro4.config.PICKLE_PROTOCOL_VERSION=4

    ns = Pyro4.locateNS(host=ns_host, port=ns_port)

    # print the nameserver entries: you should see the QickSoc proxy
    for k,v in ns.list().items():
        print(k,v)

    soc = Pyro4.Proxy(ns.lookup(proxy_name))
    soccfg = QickConfig(soc.get_cfg())

    # adapted from https://pyro4.readthedocs.io/en/stable/errors.html and https://stackoverflow.com/a/70433500
    if remote_traceback:
        try:
            import IPython
            import sys
            ip = IPython.get_ipython()
            if ip is not None:
                def exception_handler(self, etype, evalue, tb, tb_offset=None):
                    sys.stderr.write("".join(Pyro4.util.getPyroTraceback()))
                    # self.showtraceback((etype, evalue, tb), tb_offset=tb_offset)  # standard IPython's printout
                ip.set_custom_exc((Exception,), exception_handler)  # register your handler
        except Exception as e:
            raise RuntimeError("Failed to set up Pyro exception handler: ", e)

    return(soc, soccfg)
