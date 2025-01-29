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

def start_server(ns_host, ns_port=8888, proxy_name='myqick', soc_class=QickSoc, iface='eth0', **kwargs):
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
    daemon = Pyro4.Daemon(host=host)

    # if you want to use a different firmware image or set some initialization options, you would do that here
    soc = soc_class(**kwargs)
    print("initialized QICK")

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
