.PHONY: help wave sim verilate clean
.DEFAULT_GOAL := help

TOP_MODULE = tb_verilator

TOP_MODULE_PARAMS = 
# -param EXAMPLE1=32 -param EXAMPLE2=16 

FIRMWARE_DIR = ../../../../
EMU_DIR = ../../../../emulator/

AXI_DIR = $(EMU_DIR)/submodules/pulp_platform/axi/
COM_VERIF_DIR = $(EMU_DIR)/submodules/pulp_platform/common_verification/

VERILOG_SOURCES = $(wildcard ../src/*.v) $(wildcard ../src/*.sv) $(wildcard ../src/verilog/*.v) $(wildcard ../src/verilog/*.sv) $(wildcard $(EMU_DIR)/models/fifo/*.sv) $(wildcard $(EMU_DIR)/models/bram_dp/*.sv) $(wildcard $(EMU_DIR)/models/sig_gen_dds/src/*.sv) $(COM_VERIF_DIR)/src/rand_id_queue.sv $(AXI_DIR)/src/axi_intf.sv $(AXI_DIR)/src/axi_pkg.sv $(AXI_DIR)/src/axi_test.sv ./tb_verilator.sv

#$(wildcard ../../../hdl/*.sv)

VERILATOR_FLAGS = --binary --exe --build -j 0 -Wall --trace-vcd --Wno-fatal -I$(AXI_DIR)/include/

OBJ_DIR = obj_dir

wave:
	gtkwave $(OBJ_DIR)/waveform.vcd

sim: 
	./$(OBJ_DIR)/V$(TOP_MODULE)

verilate: 
	verilator $(VERILATOR_FLAGS) --top-module $(TOP_MODULE) $(VERILOG_SOURCES)

clean:
	rm -rf $(OBJ_DIR)
	rm -f trace.vcd
	rm -f *.o

help:
	@echo "QICK axis_signal_gen_v6 Testbench Simulator"
	@echo ""
	@echo "Usage: make [target]"
	@echo "If no target is specified, this help message is displayed."
	@echo ""
	@echo "Available Targets:"
	@echo "  verilate    - Compile Verilog/SystemVerilog sources using Verilator"
	@echo "  sim         - Run the compiled simulation (copies HEX files automatically)"
	@echo "  wave        - Open the simulation waveform (VCD) file in GTKWave"
	@echo "  clean       - Remove build artifacts and generated files"
	@echo "  help        - Display this help message (default when no target given)"
	@echo ""
	@echo "Typical Workflow:"
	@echo "  1. make verilate  - Compile the simulation"
	@echo "  2. make sim       - Run the simulation"
	@echo "  3. make wave      - View simulation results"
	@echo "  4. make clean     - Clean up when done"