# Virtual environment

Note: PyXSI needs libformat to be installed in the system

    $ sudo apt-get install -y libfmt-dev

Note: PyXSI need an environmental variable called XILINX_PATH. In this variable must contain 
the Xilinx installation path, i.e.:

    $ export XILINX_PATH=/tools/Xilinx/Vivado/2021.2

## To create the virtual environment you can run the Makefile located in the root. You must run:

    $ make setup_virtualenv


## Running cosimulation with pyxsi

    $ fusesoc run --build --target sim :rts:beamformer
    $ fusesoc --cores-root . run --build --target sim :rts:rx_chain
