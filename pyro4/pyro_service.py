#!/usr/bin/env python3
"""This file starts a pyro nameserver and the proxying server."""
from pathlib import Path
import subprocess
import time
from qick.pyro import start_server

HERE = Path(__file__).parent

############
# parameters
############

bitfile = '../qick_lib/qick/qick_4x2.bit'
proxy_name ='rfsoc'
ns_port = 8000
# set to 0.0.0.0 to allow access from outside systems
ns_host = 'localhost'

############

# start the nameserver process
ns_proc = subprocess.Popen(
    [f'PYRO_SERIALIZERS_ACCEPTED=pickle PYRO_PICKLE_PROTOCOL_VERSION=4 pyro4-ns -n {ns_host} -p {ns_port}'],
    shell=True
)

# wait for the nameserver to start up
time.sleep(5)

# start the qick proxy server
start_server(
    bitfile=str(HERE / bitfile),
    proxy_name=proxy_name,
    ns_host='localhost',
    ns_port=ns_port
)
