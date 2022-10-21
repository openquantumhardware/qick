#!/usr/bin/env python3
# Typically (use the IP and port of your Pyro nameserver):
# sudo -s ./server.py myqick -n 192.168.133.17 -p 8888
import sys, getopt
import psutil, socket
import Pyro4
import Pyro4.naming
from qick import QickSoc, QickConfig

def start_nameserver(ns_port=8888):
    """Starts a Pyro4 nameserver that listens on all network interfaces.

    Parameters
    ----------
    ns_port : int
        the port number for the nameserver to listen on

    Returns
    -------
    """
    Pyro4.config.SERIALIZERS_ACCEPTED = set(['pickle'])
    Pyro4.config.PICKLE_PROTOCOL_VERSION=4
    Pyro4.naming.startNSloop(host='0.0.0.0', port=ns_port)

def start_server(ns_host, ns_port=8888, proxy_name='myqick', **kwargs):
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
        # get the IPv4 address of the eth0 interface
        # unless you have an unusual network config (e.g. VPN), this is the interface clients will want to connect to
        (myaddr,) = [addr for addr in psutil.net_if_addrs()['eth0'] if addr.family==socket.AddressFamily.AF_INET]
        host = myaddr.address
    daemon = Pyro4.Daemon(host=host)

    # if you want to use a different firmware image or set some initialization options, you would do that here
    soc = QickSoc(**kwargs)
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

def make_proxy(ns_host, ns_port='8888', proxy_name='myqick'):
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
    return(soc, soccfg)

if __name__ == '__main__':

    ns_host = None
    ns_port = None
    proxy_name = "myqick"

    options, remainder = getopt.gnu_getopt(sys.argv[1:], 'n:p:h')
    for opt, arg in options:
        if opt == '-n':
            ns_host = arg
        elif opt == '-p':
            ns_port = int(arg)
        elif opt == '-h':
            print("\nUsage: "+sys.argv[0]+" [server name]")
            print("Must be run as root.")
            print("Arguments: ")
            print("\t-n: nameserver hostname (default localhost)")
            print("\t-p: nameserver port (default 9090)")
            print("\t-i: network interface (default eth0)")
            print("\t-h: this message")
            print("\n")
            print("On pynq 2.7 you may get an error relating to pynq not loading, or no XRT devices being found.")
            print("If this happens, try the following (taken from /usr/local/bin/start_jupyter.sh):")
            print("\tsudo -s")
            print("\tfor f in /etc/profile.d/*.sh; do source $f; done")
            print("\t"+sys.argv[0]+" [options]")
            print("\n")
            sys.exit(0)

    if remainder:
        proxy_name = remainder[0]

    start_server(ns_host, ns_port, proxy_name)
