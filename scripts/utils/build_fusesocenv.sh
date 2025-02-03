#!/usr/bin/bash

set -e

# Activate virtualenv
source venv/bin/activate

# Add libraries

# simulation libraries
fusesoc library add --location $PWD/.fusesoc_libraries/svunit_lib svunit_lib https://github.com/ivanvig/svunit.git

#zynq building library
fusesoc library add --locatio .fusesoc_libraries/fuse-zynq fuse-zynq https://github.com/craigjb/fuse-zynq

# add cores from root 
fusesoc library add --location .fusesoc_libraries/pynq_fused pynq_fused .

