#!/usr/bin/env python3
import sys, getopt

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

import Pyro4
from qick import QickSoc

Pyro4.config.REQUIRE_EXPOSE = False
Pyro4.config.SERIALIZER = "pickle"
Pyro4.config.SERIALIZERS_ACCEPTED=set(['pickle'])
Pyro4.config.PICKLE_PROTOCOL_VERSION=4

print("looking for nameserver . . .")
ns = Pyro4.locateNS(host=ns_host, port=ns_port)
print("found nameserver")

# if we have multiple network interfaces, we want to register the daemon using the IP address that faces the nameserver
host = Pyro4.socketutil.getInterfaceAddress(ns._pyroUri.host)
daemon = Pyro4.Daemon(host=host)

# if you want to use a different firmware image or set some initialization options, you would do that here
soc = QickSoc()
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

