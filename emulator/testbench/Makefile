# Verilator build of the QICK emulator (QICKEmu_harness) from the fusesoc cores.
#
# The sources are not listed here: fusesoc resolves qick:emulator:qickemu_harness (the harness, qick_dut, the
# qick:ip cores of the ported IPs, and the models of the vendor blocks that Verilator cannot read) and writes the
# file list; this Makefile only runs Verilator on it. The Python interface (software/qick_emu.py) calls
# `make verilate` and `make sim SIM_EMU_DIR=... SIM_ARGS=...` here.
#
# Needs fusesoc (pip install fusesoc) and the repository's Verilator: VERILATOR_VERSION of firmware/fusesoc/Makefile,
# put first on PATH from ~/.local/verilator-<version> when installed there (make install_verilator); VERILATOR_ROOT
# is still honoured.
.PHONY: help wave sim test_sim verilate setup clean profile
.DEFAULT_GOAL := help

TOP_MODULE   = QICKEmu_harness
CORE         = qick:emulator:qickemu_harness
CORE_DIR     = qick_emulator_qickemu_harness_1.0.1

PROJ_ROOT    = ../..
EMU_DIR      = $(PROJ_ROOT)/emulator
FUSESOC_DIR  = $(PROJ_ROOT)/firmware/fusesoc
FUSESOC     ?= fusesoc
FUSESOC_ROOTS = --cores-root $(FUSESOC_DIR)/cores --cores-root $(FUSESOC_DIR)/common --cores-root $(FUSESOC_DIR)/generators

# fusesoc build root: the file list, a copy of the sources and the Verilator output
BUILD_ROOT   = build
WORK_DIR     = $(BUILD_ROOT)/$(CORE_DIR)/verilate-verilator
VC_FILE      = $(CORE_DIR).vc
SIM_BIN      = $(WORK_DIR)/V$(TOP_MODULE)

# Verilator executable path
# The Verilator every flow of the repository uses, first on PATH when installed in ~/.local.
VERILATOR_VERSION ?= $(shell sed -n 's/^VERILATOR_VERSION *?= *//p' $(FUSESOC_DIR)/Makefile)
ifneq ($(wildcard $(HOME)/.local/verilator-$(VERILATOR_VERSION)/bin/verilator),)
  export PATH := $(HOME)/.local/verilator-$(VERILATOR_VERSION)/bin:$(PATH)
endif

# Uses VERILATOR_ROOT environment variable if set, otherwise falls back to 'verilator' in PATH
VERILATOR_BIN = $(if $(VERILATOR_ROOT),$(VERILATOR_ROOT)/bin/verilator,verilator)
VERILATOR_PROFCFUNC = $(if $(VERILATOR_ROOT),$(VERILATOR_ROOT)/bin/verilator_profcfunc,verilator_profcfunc)

VERILATOR_TRACE_FLAG = $(if $(TRACE),--trace)

# QICK_VERILATOR_TB enables the testbench master tasks of axi4_lite_if.
VERILATOR_FLAGS = --binary -j 0 -Wall $(VERILATOR_TRACE_FLAG) --Wno-fatal --error-limit 50 \
	--timing -DQICK_VERILATOR_TB \
	-Wno-DECLFILENAME -Wno-PINCONNECTEMPTY -Wno-VARHIDDEN \
	-Wno-TIMESCALEMOD -Wno-EOFNEWLINE -Wno-WIDTH \
	-Wno-PINMISSING -Wno-CONSTRAINTIGN $(EXTRA_VERILATOR_FLAGS)

# e.g. make verilate EXTRA_VERILATOR_FLAGS=-GRF_DELAY_TIME_NS=100 (transport delay DAC -> ADC, default 110 ns; HRL had 100)
EXTRA_VERILATOR_FLAGS ?=
SIM_ARGS =
# Pass SIM_EMU_DIR=path to override the default emulator input directory
# Pass TRACE=1 to enable VCD waveform dump (warning: very large files)
# Example: make sim SIM_EMU_DIR=artifacts/00_intro/multi_pulse
SIM_EMU_DIR ?= $(EMU_DIR)/artifacts/test_sim

wave:
	gtkwave $(SIM_EMU_DIR)/waveform.vcd

# fusesoc writes the file list and copies the sources (about a second)
setup:
	$(FUSESOC) $(FUSESOC_ROOTS) run --target verilate --tool verilator --setup --build-root $(BUILD_ROOT) $(CORE)

verilate: setup
	cd $(WORK_DIR) && $(VERILATOR_BIN) -f $(VC_FILE) $(VERILATOR_FLAGS) $(if $(wildcard $(CURDIR)/verilator.vlt),$(CURDIR)/verilator.vlt)

sim:
	./$(SIM_BIN) $(if $(SIM_EMU_DIR),+EMU_DIR=$(SIM_EMU_DIR)) $(if $(TRACE),+TRACE) $(SIM_ARGS)

test_sim: verilate
	./$(SIM_BIN) +EMU_DIR=$(EMU_DIR)/artifacts/test_sim $(SIM_ARGS)

clean:
	rm -rf $(BUILD_ROOT)
	rm -f trace.vcd *.o *.hex profcfunc.log gmon.out gprof.log

profile: clean verilate_profile test_sim_profile
	gprof $(SIM_BIN) gmon.out > gprof.log
	$(VERILATOR_PROFCFUNC) gprof.log > profcfunc.log
	@echo "Profiling complete. Check gprof.log and profcfunc.log for results."

verilate_profile: clean setup
	cd $(WORK_DIR) && $(VERILATOR_BIN) -f $(VC_FILE) $(VERILATOR_FLAGS) --prof-cfuncs $(if $(wildcard $(CURDIR)/verilator.vlt),$(CURDIR)/verilator.vlt)

test_sim_profile: verilate_profile
	./$(SIM_BIN) +EMU_DIR=$(EMU_DIR)/artifacts/test_sim $(SIM_ARGS)

help:
	@echo "QICKEmu_harness Testbench Simulator (sources from the fusesoc cores)"
	@echo ""
	@echo "Usage: make [target]"
	@echo "If no target is specified, this help message is displayed."
	@echo ""
	@echo "Available Targets:"
	@echo "  setup       - Resolve $(CORE) with fusesoc (file list + copy of the sources)"
	@echo "  verilate    - setup, then compile with Verilator"
	@echo "  sim         - Run the compiled simulation"
	@echo "  test_sim    - verilate and run the artifacts/test_sim stimulus"
	@echo "  wave        - Open the simulation waveform (VCD) from SIM_EMU_DIR in GTKWave"
	@echo "  clean       - Remove the build directory and profiling logs"
	@echo "  help        - Display this help message (default when no target given)"
	@echo ""
	@echo "Simulation Options:"
	@echo "  SIM_EMU_DIR=<path> - Override emulator input directory (default: artifacts/test_sim)"
	@echo "  TRACE=1            - Enable VCD waveform dump (large files!); also at verilate time"
	@echo "  SIM_ARGS=<args>    - Pass extra plusargs to simulation binary"
	@echo "  FUSESOC=<cmd>      - fusesoc executable (default: fusesoc)"
	@echo ""
	@echo "Profiling:"
	@echo "  make profile       - Clean, build with profiling, run test_sim, generate gmon.out, gprof.log, profcfunc.log"
	@echo ""
	@echo "Typical Workflow:"
	@echo "  1. make verilate  - Compile the simulation"
	@echo "  2. make sim       - Run the simulation"
	@echo "  3. make wave      - View simulation results"
	@echo "  4. make clean     - Clean up when done"
