#!/bin/bash
# Start a Pyro4 nameserver.
export PYRO_SERIALIZERS_ACCEPTED=pickle PYRO_PICKLE_PROTOCOL_VERSION=4

# pass all arguments to pyro4-ns
pyro4-ns $@
