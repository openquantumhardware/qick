#!/bin/bash
# Start a Pyro4 nameserver.
# Typically:
# ./nameserver.sh -n 0.0.0.0 -p 8888
export PYRO_SERIALIZERS_ACCEPTED=pickle PYRO_PICKLE_PROTOCOL_VERSION=4

# pass all arguments to pyro4-ns
pyro4-ns $@
