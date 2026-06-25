# Options: tb_verilator, tb_siggen_dynamic_routed
TOP_MODULE ?= tb_siggen_dynamic_routed

# -------------------------------------------------------------------------
# Usage
# -------------------------------------------------------------------------
# Typical flow:
#   1) Build simulator:
#      make verilate
#   2) Run simulation:
#      make sim
#   3) Open waveform:
#      make wave
#
# Select a different testbench/top module:
#   make TOP_MODULE=tb_verilator verilate
#   make TOP_MODULE=tb_verilator sim
#
# Available TOP_MODULE values:
#   - tb_siggen_dynamic_routed (default)
#   - tb_verilator
#
# Cleanup:
#   make clean

# Paths
PROJ_ROOT     = ../../../
FIRMWARE_DIR  = $(PROJ_ROOT)firmware
SUBMODULES_DIR = $(PROJ_ROOT)emulator/submodules
IP_SRC_DIR    = $(FIRMWARE_DIR)/ip/axis_signal_gen_v6/src
IP_VERILOG_DIR = $(IP_SRC_DIR)/verilog
AXI_DIR       = $(SUBMODULES_DIR)/pulp_platform/axi
COM_VERIF_DIR = $(SUBMODULES_DIR)/pulp_platform/common_verification
COMMON_CELLS_DIR = $(SUBMODULES_DIR)/pulp_platform/common_cells

# New Emulator Models Paths (Relative to emulator/models/axis_signal_gen_v6)
MODELS_DIR      = ../
BRAM_DP_DIR     = $(MODELS_DIR)bram_dp
FIFO_DIR        = $(MODELS_DIR)fifo
DAC_MODEL_DIR   = $(MODELS_DIR)dac_model
SIG_GEN_DDS_DIR = $(MODELS_DIR)sig_gen_dds

# -------------------------------------------------------------------------
# Source File Groups
# -------------------------------------------------------------------------

# 1. Core Hardware (Force load ALL files to avoid hidden module names)
# We include both .v and .sv for every directory to ensure nothing is missed.
SIGGEN_SOURCES = \
	$(wildcard $(IP_SRC_DIR)/*.v) \
	$(wildcard $(IP_SRC_DIR)/*.sv) \
	$(wildcard $(IP_VERILOG_DIR)/*.v) \
	$(wildcard $(IP_VERILOG_DIR)/*.sv) \
	$(wildcard $(BRAM_DP_DIR)/*.v) \
	$(wildcard $(BRAM_DP_DIR)/*.sv) \
	$(wildcard $(FIFO_DIR)/*.v) \
	$(wildcard $(FIFO_DIR)/*.sv) \
	$(wildcard $(DAC_MODEL_DIR)/*.v) \
	$(wildcard $(DAC_MODEL_DIR)/*.sv) \
	$(wildcard $(SIG_GEN_DDS_DIR)/*.v) \
	$(wildcard $(SIG_GEN_DDS_DIR)/*.sv) \
	$(wildcard $(SIG_GEN_DDS_DIR)/src/*.v) \
	$(wildcard $(SIG_GEN_DDS_DIR)/src/*.sv) \
	$(wildcard $(FIRMWARE_DIR)/ip/common/*.v) \
	$(wildcard $(FIRMWARE_DIR)/ip/common/*.sv) \
	$(wildcard $(FIRMWARE_DIR)/ip/qick_common/*.v) \
	$(wildcard $(FIRMWARE_DIR)/ip/qick_common/*.sv)

# 2. AXI & Verification Infrastructure
AXI_LIB_SOURCES = \
	$(COM_VERIF_DIR)/src/rand_id_queue.sv \
	$(wildcard $(AXI_DIR)/src/*.sv) \
	$(wildcard $(COMMON_CELLS_DIR)/src/*.sv)

# 3. Interconnect Hardware
AXI_XBAR_SOURCES = \
	./axi_lite_interconnect_wrapper.sv

# -------------------------------------------------------------------------
# Dynamic Source Selection
# -------------------------------------------------------------------------

ifeq ($(TOP_MODULE),tb_siggen_dynamic_routed)
	VERILOG_SOURCES = $(SIGGEN_SOURCES) $(AXI_XBAR_SOURCES) $(AXI_LIB_SOURCES) ./$(TOP_MODULE).sv
else
	VERILOG_SOURCES = $(SIGGEN_SOURCES) $(AXI_LIB_SOURCES) ./$(TOP_MODULE).sv
endif

# -------------------------------------------------------------------------
# Build & Run Configuration
# -------------------------------------------------------------------------

# Flags
# -I resolves `include "file.svh"` 
# -y resolves missing modules dynamically
VERILATOR_FLAGS = --binary --exe --build -j 0 -Wall --trace-vcd --Wno-fatal \
	-Wno-DECLFILENAME -Wno-PINCONNECTEMPTY -Wno-VARHIDDEN \
	-Wno-TIMESCALEMOD -Wno-EOFNEWLINE -Wno-WIDTH \
	-Wno-PINMISSING -Wno-BADVLTPRAGMA -Wno-CONSTRAINTIGN \
	-I$(AXI_DIR)/include \
	-I$(COM_VERIF_DIR)/include \
	-I$(COMMON_CELLS_DIR)/include \
	-I$(IP_SRC_DIR) \
	-I$(IP_VERILOG_DIR) \
	-y $(BRAM_DP_DIR) \
	-y $(FIFO_DIR) \
	-y $(DAC_MODEL_DIR) \
	-y $(SIG_GEN_DDS_DIR) \
	-y $(SIG_GEN_DDS_DIR)/src \
	-y $(FIRMWARE_DIR)/ip/common \
	-y $(FIRMWARE_DIR)/ip/qick_common \
	-y $(IP_SRC_DIR) \
	-y $(IP_VERILOG_DIR)

OBJ_DIR = obj_dir

.PHONY: help verilate sim wave clean

verilate:
	verilator $(VERILATOR_FLAGS) --top-module $(TOP_MODULE) $(VERILOG_SOURCES)

sim: 
	cp -f $(FIRMWARE_DIR)/ip/axis_signal_gen_v6/tb/gauss.txt . 2>/dev/null || true
	./$(OBJ_DIR)/V$(TOP_MODULE) +AXI_REPLAY=./axi_replay.dat

wave:
	gtkwave $(OBJ_DIR)/waveform_$(if $(filter tb_siggen_dynamic_routed,$(TOP_MODULE)),dynamic_routed,dynamic).vcd

clean:
	rm -rf $(OBJ_DIR)
	rm -f *.o *.vcd *.csv *.hex gauss.txt

help:
	@echo "axis_signal_gen_v6 emulator Makefile"
	@echo ""
	@echo "Targets:"
	@echo "  make verilate                      Build Verilator simulation binary"
	@echo "  make sim                           Run simulation (expects built binary)"
	@echo "  make wave                          Open generated VCD in GTKWave"
	@echo "  make clean                         Remove build and generated artifacts"
	@echo ""
	@echo "Variables:"
	@echo "  TOP_MODULE=$(TOP_MODULE)"
	@echo ""
	@echo "Examples:"
	@echo "  make verilate"
	@echo "  make sim"
	@echo "  make TOP_MODULE=tb_verilator verilate sim"