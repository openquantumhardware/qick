#!/usr/bin/env python3
# Typically (use the IP and port of your Pyro nameserver):
# python -m qick.pyro_cli myqick -n 192.168.133.17 -p 8888
import sys, getopt
from qick.pyro import start_server

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
