.PHONY: help wave sim verilate clean
.DEFAULT_GOAL := help

TOP_MODULE = tb_qick_emu_verilator


# Paths
PROJ_ROOT     = ../../..
FIRMWARE_DIR  = $(PROJ_ROOT)/firmware
PULP_DIR      = $(PROJ_ROOT)/firmware/pulp_platform
AXI_DIR       = $(PULP_DIR)/axi
COM_VERIF_DIR = $(PULP_DIR)/common_verification
COMMON_CELLS_DIR = $(PULP_DIR)/common_cells

# New Emulator Models Paths (Relative to emulator/models/axis_signal_gen_v6)
EMU_DIR         = $(PROJ_ROOT)/emulator
MODELS_DIR      = $(EMU_DIR)/models
BRAM_DP_DIR     = $(MODELS_DIR)/bram_dp
FIFO_DIR        = $(MODELS_DIR)/fifo
DAC_MODEL_DIR   = $(MODELS_DIR)/dac_model
SIG_GEN_DDS_DIR = $(MODELS_DIR)/sig_gen_dds

TOP_MODULE_PARAMS = 
# -param EXAMPLE1=32 -param EXAMPLE2=16 

VERILOG_SOURCES = \
    $(wildcard $(FIRMWARE_DIR)/ip/axis_signal_gen_v6/src/*.v) \
    $(wildcard $(FIRMWARE_DIR)/ip/axis_signal_gen_v6/src/*.sv) \
    $(wildcard $(FIRMWARE_DIR)/ip/axis_signal_gen_v6/src/verilog/*.v) \
    $(wildcard $(FIRMWARE_DIR)/ip/axis_signal_gen_v6/src/verilog/*.sv) \
    \
    $(wildcard $(FIRMWARE_DIR)/ip/axis_dyn_readout_v1/src/*.v) \
    $(wildcard $(FIRMWARE_DIR)/ip/axis_dyn_readout_v1/src/*.sv) \
    $(wildcard $(FIRMWARE_DIR)/ip/axis_dyn_readout_v1/src/verilog/*.v) \
    $(wildcard $(FIRMWARE_DIR)/ip/axis_dyn_readout_v1/src/verilog/*.sv) \
    $(wildcard $(FIRMWARE_DIR)/ip/axis_dyn_readout_v1/src/fifo/verilog/*.v) \
    $(wildcard $(FIRMWARE_DIR)/ip/axis_dyn_readout_v1/src/fifo/verilog/*.sv) \
    \
    $(wildcard $(FIRMWARE_DIR)/ip/qick_processor/src/*.v) \
    $(wildcard $(FIRMWARE_DIR)/ip/qick_processor/src/*.sv) \
    $(wildcard $(FIRMWARE_DIR)/ip/qick_processor/src/verilog/*.v) \
    $(wildcard $(FIRMWARE_DIR)/ip/qick_processor/src/verilog/*.sv) \
    \
    $(wildcard $(FIRMWARE_DIR)/ip/axis_cdcsync_v1/src/*.v) \
    $(wildcard $(FIRMWARE_DIR)/ip/axis_cdcsync_v1/src/*.sv) \
    \
    $(wildcard $(FIRMWARE_DIR)/ip/qick_sg_translator/src/*.v) \
    $(wildcard $(FIRMWARE_DIR)/ip/qick_sg_translator/src/*.sv) \
    \
    $(wildcard $(FIRMWARE_DIR)/ip/axis_kidsim_v3/src/*.v) \
    $(wildcard $(FIRMWARE_DIR)/ip/axis_kidsim_v3/src/*.sv) \
    $(wildcard $(FIRMWARE_DIR)/ip/axis_kidsim_v3/src/dds/*.v) \
    $(wildcard $(FIRMWARE_DIR)/ip/axis_kidsim_v3/src/dds/*.sv) \
    \
    $(wildcard $(FIRMWARE_DIR)/ip/axis_avg_buffer/src/*.v) \
    $(wildcard $(FIRMWARE_DIR)/ip/axis_avg_buffer/src/*.sv) \
    $(wildcard $(FIRMWARE_DIR)/ip/axis_avg_buffer/src/verilog/*.v) \
    $(wildcard $(FIRMWARE_DIR)/ip/axis_avg_buffer/src/verilog/*.sv) \
    \
    $(wildcard $(MODELS_DIR)/axis_signal_gen_v6/*.sv) \
    $(wildcard $(MODELS_DIR)/bram_dp/*.sv) \
    $(wildcard $(MODELS_DIR)/dac_adc/*.sv) \
    $(wildcard $(MODELS_DIR)/dsp_macro/src/*.sv) \
    $(wildcard $(MODELS_DIR)/fifo/*.sv) \
    $(wildcard $(MODELS_DIR)/fir/*.sv) \
    $(wildcard $(MODELS_DIR)/sig_gen_dds/*.sv) \
    \
    $(COM_VERIF_DIR)/src/rand_id_queue.sv \
    $(AXI_DIR)/src/axi_intf.sv \
    $(AXI_DIR)/src/axi_pkg.sv \
    $(AXI_DIR)/src/axi_test.sv \
    \
    $(FIRMWARE_DIR)/testbench/qick_testbench/src/tb/tb_qick_emu_verilator.sv


# Flags
# -I resolves `include "file.svh"` 
# -y resolves missing modules dynamically
VERILATOR_FLAGS = --binary --exe --build -j 0 -Wall --trace-vcd --Wno-fatal \
    --timing \
    -Wno-DECLFILENAME -Wno-PINCONNECTEMPTY -Wno-VARHIDDEN \
    -Wno-TIMESCALEMOD -Wno-EOFNEWLINE -Wno-WIDTH \
    -Wno-PINMISSING -Wno-BADVLTPRAGMA -Wno-CONSTRAINTIGN \
    -I$(AXI_DIR)/include \
    -I$(COM_VERIF_DIR)/include \
    -I$(COMMON_CELLS_DIR)/include \
    -I$(FIRMWARE_DIR)/ip/qick_processor/src \
    -y $(BRAM_DP_DIR) \
    -y $(FIFO_DIR) \
    -y $(DAC_MODEL_DIR) \
    -y $(SIG_GEN_DDS_DIR) \
    -y $(SIG_GEN_DDS_DIR)/src \
    -y $(FIRMWARE_DIR)/ip/common \
    -y $(FIRMWARE_DIR)/ip/qick_common 


OBJ_DIR = obj_dir

wave:
	gtkwave $(OBJ_DIR)/waveform.vcd

SIM_ARGS =
# Pass SIM_EMU_DIR=path to override the default emulator input directory
# Pass TRACE=1 to enable VCD waveform dump (warning: very large files)
# Example: make sim SIM_EMU_DIR=../../../emulator/artifacts/00_intro/multi_pulse

sim:
	cp -f $(MODELS_DIR)/sig_gen_dds/LUT_generator/*.hex .
	cp -f $(MODELS_DIR)/fir/fir_coe.txt .
	./$(OBJ_DIR)/V$(TOP_MODULE) $(if $(SIM_EMU_DIR),+EMU_DIR=$(SIM_EMU_DIR)) $(if $(TRACE),+TRACE) $(SIM_ARGS)

verilate:
	verilator $(VERILATOR_FLAGS) verilator.vlt --top-module $(TOP_MODULE) $(VERILOG_SOURCES)

clean:
	rm -rf $(OBJ_DIR)
	rm -f trace.vcd
	rm -f *.o
	rm -f *.hex
	rm -f fir_coe.txt

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
	@echo "Simulation Options:"
	@echo "  SIM_EMU_DIR=<path> - Override emulator input directory (default: src/tb/emulator)"
	@echo "  TRACE=1            - Enable VCD waveform dump (large files!)"
	@echo "  SIM_ARGS=<args>    - Pass extra plusargs to simulation binary"
	@echo ""
	@echo "Typical Workflow:"
	@echo "  1. make verilate  - Compile the simulation"
	@echo "  2. make sim       - Run the simulation"
	@echo "  3. make wave      - View simulation results"
	@echo "  4. make clean     - Clean up when done"
	@echo ""
	@echo "Example with artifacts:"
	@echo "  make sim SIM_EMU_DIR=../../../emulator/artifacts/00_intro/multi_pulse"