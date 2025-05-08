#targets:
## setup_enviroment: config virtual environment and install all library need.
## sim_svunit: Run simulation with sv-unit.


#XILINX_HLS:=/tools/Xilinx/Vitis_HLS/2021.2/bin
#XILINX_VIVADO:=/tools/Xilinx/Vivado/2021.2/bin
#XILINX_VITIS:=/tools/Xilinx/Vitis/2021.2/bin
#
#XILINXD_LICENSE_FILE:=21000@10.98.0.17:21000@10.98.0.7
#
#export XILINXD_LICENSE_FILE
#
#export PATH:=$(XILINX_VIVADO):$(PATH)
#export PATH:=$(XILINX_VITIS):$(PATH)
#export PATH:=$(XILINX_HLS):$(PATH)
#
#export LD_LIBRARY_PATH=/tools/Xilinx/Vivado/2021.2/lib/lnx64.o

# target of configuration
setup_enviroment:
	git submodule init
	git submodule update
	bash ./scripts/utils/build_virtualenv.sh
	bash ./scripts/utils/build_fusesocenv.sh
	
sim_svunit: clean
	mkdir report_pytest
	. venv/bin/activate; python3 scripts/tests/svunit_test/get_core_name.py && pytest scripts/tests/ -v -m svunit_test  --junitxml=report_pytest/pytest-report.xml

# target generic
clean:
	rm -f vivado*
	rm -f pytest-report*
	rm -r -f .Xil
	rm -r -f build
	rm -r -f report_svunit/
	rm -r -f report_pytest/
	rm -r -f tmp/.Xil
	rm -r -f tmp/top_syncro
	rm -r -f tmp/build
	rm -r -f tmp/*.vcd
