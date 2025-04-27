SIM_GLOBAL_DIR           := ../../../../../../common/sim/
COMMON_GLOBAL_DIR        := ../../../../../../common/design/
SRC_DIR                  := ../../src/
TESTS_DIR                := ../testcases/

SOURCES_SV_SIM_GLOBAL    := $(shell cat $(SIM_GLOBAL_DIR)/sources.list)
SOURCES_SV_SIM_GLOBAL    := $(addprefix $(SIM_GLOBAL_DIR), $(SOURCES_SV_SIM_GLOBAL))
SOURCES_SV_COMMON_GLOBAL := $(shell cat $(COMMON_GLOBAL_DIR)/sources.list)
SOURCES_SV_COMMON_GLOBAL := $(addprefix $(COMMON_GLOBAL_DIR), $(SOURCES_SV_COMMON_GLOBAL))
SOURCES_SV_TEST          := $(shell cat ../filelists/sv_sources_testcases.list)
TB_LIST                  := $(basename $(SOURCES_SV_TEST))
SOURCES_SV_TEST          := $(addprefix $(TESTS_DIR), $(SOURCES_SV_TEST))
SOURCES_SV               := $(SOURCES_SV_SIM_GLOBAL) $(SOURCES_SV_COMMON_GLOBAL) $(SOURCES_SV_TEST)
COMP_OPTS_SV             := --incr --relax
DEFINES_SV               :=
COMP_OPTS_VHDL           := --incr --relax
SOURCES_VHDL             := $(shell cat ../filelists/vhdl_sources.list)
TB_LIST_snapshot         := $(addsuffix _snapshot.wdb, $(TB_LIST))
TB_LIST_timestamp        := $(addprefix .elab.timestamp_, $(TB_LIST))

#==== Default target - running simulation without drawing waveforms ====#
.PHONY : simulate
simulate : $(TB_LIST_snapshot)

define make-simulate-target
.PHONY : simulate_$1
simulate_$1: $1_snapshot.wdb
endef

$(foreach element,$(TB_LIST),$(eval $(call make-simulate-target,$(element))))

.PHONY : elaborate
elaborate : $(TB_LIST_timestamp)

.PHONY : compile
compile : .comp_sv.timestamp .comp_vhdl.timestamp

#==== WAVEFORM DRAWING ====#
define make-waves-target
.PHONY : waves_$1
waves_$1: $1_snapshot.wdb
	xsim --gui $1_snapshot.wdb
endef

$(foreach element,$(TB_LIST),$(eval $(call make-waves-target,$(element))))

#==== SIMULATION ====#
define make-sim-target
$1_snapshot.wdb: .elab.timestamp_$1
	xsim $1_snapshot -tclbatch xsim_cfg.tcl
endef
	
$(foreach element,$(TB_LIST),$(eval $(call make-sim-target,$(element))))

#==== ELABORATION ====#
define make-elab-target
.elab.timestamp_$1: .comp_sv.timestamp .comp_vhdl.timestamp
	xelab -debug all -snapshot $1_snapshot -top $1
	touch .elab.timestamp_$1
endef

$(foreach element,$(TB_LIST),$(eval $(call make-elab-target,$(element))))

#==== COMPILING SYSTEMVERILOG SOURCES ====#
ifeq ($(SOURCES_SV),)
.comp_sv.timestamp :
	@echo
	@echo "### NO (SYSTEM)VERILOG SOURCES GIVEN ###"
	@echo "### SKIPPED SYSTEMVERILOG COMPILATION ###"
	touch .comp_sv.timestamp
else
.comp_sv.timestamp : $(SOURCES_SV)
	@echo
	@echo "### COMPILING SYSTEMVERILOG ###"
	xvlog --sv $(COMP_OPTS_SV) $(DEFINES_SV) $(SOURCES_SV) -log xvlog.log
	touch .comp_sv.timestamp
endif

#==== COMPILING VHDL SOURCES ====#
ifeq ($(SOURCES_VHDL),)
.comp_vhdl.timestamp :
	@echo
	@echo "### NO VHDL SOURCES GIVEN ###"
	@echo "### SKIPPED VHDL COMPILATION ###"
	touch .comp_vhdl.timestamp
else
.comp_vhdl.timestamp : $(SOURCES_VHDL)
	@echo
	@echo "### COMPILING VHDL ###"
	xvhdl $(COMP_OPTS_VHDL) $(SOURCES_VHDL) -log xvhdl.log
	touch .comp_vhdl.timestamp
endif

.PHONY : clean
clean :
	rm -rf *.jou *.log *.pb *.wdb xsim.dir .Xil
	rm -rf .*.timestamp*
