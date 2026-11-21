# ============================================================================
# QICK FuseSoC Makefile
# ============================================================================
#
# Central entry point for the QICK FuseSoC environment. All targets run from
# firmware/fusesoc/ and activate the shared project venv (../../.venv/, i.e.
# <repository>/.venv) internally (no need to `source` it first). This same
# venv is also used to build the Sphinx docs (docs/requirements.txt).
#
# QUICK REFERENCE
#   Setup:
#     make setup_environment              # one-time: submodules + venv + fusesoc env + Verilator + ossschem
#   Simulation / lint:
#     make sim         IP=<core>          # run SVUnit test target (single core, xsim)
#     make sim_svunit  [IP=<core>]        # make sim on every core with a test target (or IP), JUnit in report_svunit/
#     make lint        IP=<core>          # veriblelint / verilator lint-only
#   Code coverage:
#     make coverage    IP=<core>          # DUT line+toggle (verilator, default)
#     make coverage    IP=<core> COV_MIN=80 COV_DEFINE=SVUNIT
#     make coverage    IP=<core> COV_BACKEND=xsim COV=sb   # statement coverage
#     make coverage-matrix IP=<core> CONFIGS="--TB_N=64|--FWFT=1"   (merged report)
#     make coverage-all COV_FILTER='^qick:ip:'  |  make coverage-summary
#   Registers / drivers (PeakRDL):
#     make rdl-gen     IP=<ip>            # generate regmap package from RDL
#     make driver      IP=<ip>            # gen + symlink driver + register tests
#     make driver-test IP=<ip>           # register tests only (scaffolds if needed)
#     make driver-all                    # make driver for every IP
#     make driver-check IP=<ip>          # fail if tracked qick_lib/qick/rdl_pkgs is stale
#     make rdl-docs    IP=<ip>           # HTML register docs
#   RTL library docs:
#     make rtl-docs    [INPUT=<file>]    # Markdown docs for ../rtl_lib (all or one)
#     make rtl-docs-clean
#     make block-diagram TOP=<mod> [IP=<name>]  # real ports + wiring, SVG
#     make schematic TOP=<mod> | PROJ=<group>/<project>  # interactive schematic in VS Code (ossschem)
#     make tikz-diagrams | tikz-diagram NAME=<name>  # hand-drawn, for docs
#   Packaging (Vivado):
#     make package     IP=<ip> [VERSION=] [PART=] [DESCRIPTION=] [DISPLAY_NAME=]
#     make package-all
#     make package-dry IP=<ip>
#   Hog lists of the BD's qick:ip RTL (so the build SHA follows it):
#     make hog-lists PROJ=<group>/<project> [CHECK=1]
#     make hog-lists-all [CHECK=1]
#   Inspection:
#     make list-cores | core-info CORE=<vlnv> | deps IP=<ip> | verify-core IP=<ip>
#   Cleanup:
#     make clean
#
# VARIABLES
#   IP            Core / IP short name, e.g. axis_signal_gen_v6 (most targets).
#   CORE          Full VLNV, e.g. qick:ip:axis_signal_gen_v6 (core-info).
#   TOOL          EDA tool override for `make lint` (TOOL=verilator); unset: the core's default tool (Verible for lint, xsim for sim).
#   VERSION       IP version for packaging (default: 1.0).
#   PART          Target FPGA part (default: xczu49dr-ffvf1760-2-e).
#   INPUT         Single file/dir for rtl-docs (default: whole ../rtl_lib).
#   DESCRIPTION / DISPLAY_NAME   Optional IP metadata for packaging.
#
# GOTCHAS (learned the hard way)
#   * Recipes need TABs, not spaces (else "*** missing separator").
#   * venv activation must be on the SAME logical recipe line as the command
#     that needs it (joined with '\'), because each recipe line is a new shell.
#   * Sub-makes into cores/ip/<ip>/rdl/ (gen, driver, rdl-docs) MUST activate the
#     venv first, or python3 uses the system interpreter and systemrdl is missing.
#   * The venv lives at <repository>/.venv (shared with the docs build), not
#     under firmware/fusesoc/ — that's why every activation is '../../.venv/...'.
#   * Use '$$VAR' (double $) for shell vars inside recipes; single $ is Make's.
# ============================================================================

FUSESOC_CORES := --cores-root cores \
	         --cores-root common \
	         --cores-root generators

# Single-line form. $(FUSESOC_CORES) expands to several lines, which breaks
# quoting when it is interpolated into the middle of a shell construct such as a
# for-loop body or a command substitution.
FUSESOC_ROOTS := --cores-root cores --cores-root common --cores-root generators

# Default tool for simulation and linting.
TOOL ?= verilator

# The one Verilator every flow of the repository uses (coverage, lint, block-diagram, schematic,
# QICKEmu). make setup_environment / install_verilator build it into ~/.local/verilator-<version>
# without root, and when it is there every target puts it first on PATH, ahead of an older
# system Verilator. Validated moving from 5.042 to 5.052.
VERILATOR_VERSION ?= 5.052
VERILATOR_HOME    ?= $(HOME)/.local/verilator-$(VERILATOR_VERSION)
ifneq ($(wildcard $(VERILATOR_HOME)/bin/verilator),)
  export PATH := $(VERILATOR_HOME)/bin:$(PATH)
endif

# ossschem (https://github.com/markusdd/ossschem, MIT): the interactive schematic of
# `make schematic`, a command plus a VS Code extension. The release is pinned by its sha256
# (linux-x64; the release publishes no checksums, this is the archive that was tested).
OSSSCHEM_VERSION ?= 0.7.0
OSSSCHEM_SHA256  ?= ba7f94f23c2ed384b13686b6e195736c86a722c6ebc76506e1a184e47aa4676f
OSSSCHEM_HOME    ?= $(HOME)/.local/ossschem-$(OSSSCHEM_VERSION)

# ----------------------------------------------------------------------------
# Optional testbench knobs. Only appended when set, so 'make sim IP=<any>'
# keeps working for cores that do not declare these parameters.
#   make sim IP=fifo_async MODE=fwft
#   make sim IP=fifo_async MODE=fwft DEPTH=16 WIDTH=24 SWAP_CLK=1
# ----------------------------------------------------------------------------
MODE     ?=
DEPTH    ?=
WIDTH    ?=
SWAP_CLK ?=
ASYNC    ?=
FIFO     ?=
MEM      ?=


SIM_ARGS :=

ifeq ($(MEM),auto)
  SIM_ARGS += --TB_MEM=0
else ifeq ($(MEM),distributed)
  SIM_ARGS += --TB_MEM=1
else ifeq ($(MEM),block)
  SIM_ARGS += --TB_MEM=2
else ifeq ($(MEM),ultra)
  SIM_ARGS += --TB_MEM=3
else ifneq ($(MEM),)
  $(error MEM must be auto, distributed, block or ultra (got '$(MEM)'))
endif

ifneq ($(ASYNC),)
  SIM_ARGS += --ASYNC_CLK=$(ASYNC)
endif

ifeq ($(MODE),fwft)
  SIM_ARGS += --FWFT=1
else ifeq ($(MODE),std)
  SIM_ARGS += --FWFT=0
else ifneq ($(MODE),)
  $(error MODE must be 'std' or 'fwft' (got '$(MODE)'))
endif

ifneq ($(DEPTH),)
  SIM_ARGS += --TB_N=$(DEPTH)
endif
ifneq ($(WIDTH),)
  SIM_ARGS += --TB_B=$(WIDTH)
endif
ifneq ($(SWAP_CLK),)
  SIM_ARGS += --SWAP_CLK=$(SWAP_CLK)
endif


# RTL library documentation input/output (overridable).
RTL_DOCS_IN  ?= ../rtl_lib
RTL_DOCS_OUT ?= ../docs/rtl-md

# ----------------------------------------------------------------------------
# Code coverage knobs.
#
# Two backends, both of which run the SVUnit suites without editing any .core:
# the driver exports with 'fusesoc run --setup' and then calls the generated
# Makefile with the tool's options overridden on the command line.
#
#   COV_BACKEND=verilator (default)
#     Compiles the SVUnit testrunner to a native binary and runs it. Millisecond
#     simulation, and the only backend that instruments purely combinational
#     RTL: xsim reports 0 executable statements for assign-only modules such as
#     vec2bit.sv or bin2gray.sv, which read as 0% instead of "no data".
#     Gated metric: toggle coverage. Verilator's --coverage-line is not usable
#     here -- see ../docs/developer/COVERAGE.md.
#
#   COV_BACKEND=xsim
#     Re-elaborates with 'xelab --cc_type' and reports through xcrg. Needed for
#     statement coverage; costs far more time and memory, so keep it for
#     targeted audits rather than sweeps.
#
#   COV      xsim only: xelab --cc_type, any of s,b,c,t. Default sbct adds
#             toggle coverage, which is what finds dead branches in the FSMs
#             (avg_buffer, buffer, streamer, tproc) but costs the most
#             elaboration time and memory. Use COV=sb for a quick read.
#   COV_OUT  where reports land (annotated source + summary.json).
#   COV_MIN  fail the run if the backend's primary metric is below this percent.
#   COV_DEFINE  verilog defines for the Verilator run (e.g. COV_DEFINE="SVUNIT").
#   CONFIGS  pipe-separated sim configurations to merge into one report. Each one
#             becomes its own run and the coverage databases are unioned. For a
#             parameterized core, the default config alone badly under-reports
#             the RTL.
# ----------------------------------------------------------------------------
COV_BACKEND ?= verilator
COV      ?= sbct
COV_OUT  ?= report_cov
COV_MIN  ?=
CONFIGS  ?=
COV_FILTER ?=
COV_TIMEOUT ?= 1800
COV_DEFINE ?=
COV_JOBS ?= 4
COV_BUILD_JOBS ?=
COV_SOFT_ZERO ?=
COV_SORT ?=

ifeq ($(COV_BACKEND),verilator)
  COV_ARGS := --backend verilator --out $(COV_OUT) --timeout $(COV_TIMEOUT) \
    $(if $(COV_MIN),--min-toggle $(COV_MIN),) $(if $(COV_DEFINE),--define $(COV_DEFINE),)
else
  COV_ARGS := --backend xsim --cc-type $(COV) --out $(COV_OUT) \
    --timeout $(COV_TIMEOUT) $(if $(COV_MIN),--min-line $(COV_MIN),)
endif
ifneq ($(strip $(CONFIGS)),)
  # Quoted, because a config is a list of fusesoc flags and may contain spaces.
  # cov_run.py's normalize_flag_values() rewrites this to the "--configs=..."
  # form before argparse sees it, since a value starting with "--" would
  # otherwise be read as the next option.
  COV_CONFIG_ARGS := --configs "$(CONFIGS)"
endif

.PHONY: help setup_environment install_verilator install_ossschem schematic \
	sim sim_svunit lint \
	coverage coverage-all coverage-matrix coverage-summary \
	package package-all package-dry hog-lists hog-lists-all \
	clean \
	list-cores core-info deps verify-core \
	rdl-gen new-ip driver _driver driver-test driver-all driver-check driver-scaffold driver-bindings \
	rdl-docs rtl-docs rtl-docs-clean block-diagram tikz-diagrams tikz-diagram sim-streamer-matrix

# Default target: show the quick reference.
help:
	@sed -n '2,60p' $(MAKEFILE_LIST) | sed 's/^# \{0,1\}//'

# ----------------------------------------------------------------------------
# Environment Setup
# ----------------------------------------------------------------------------
# One-time setup after cloning: init submodules, build the shared project venv
# at <repository>/.venv (installs pyproject.toml deps incl. systemrdl-compiler
# / peakrdl-*, plus docs/requirements.txt so the same venv builds the Sphinx
# docs), build the FuseSoC env, create source symlinks, install the repository's
# Verilator and ossschem, and check that Verilator is usable. Run this before any
# other target on a fresh checkout (e.g. on a new machine).
#
# The Verilator and ossschem steps never fail the target (leading '-'): simulation
# under xsim needs neither, and a machine without the C++ build tools must still
# get the venv, libraries and symlinks. Both installs do nothing when that version
# is already there. `make coverage` / `make schematic` fail with an explicit message
# if what they need is genuinely absent.
setup_environment:
	git submodule init && git submodule update
	bash scripts/utils/build_virtualenv.sh
	bash scripts/utils/build_fusesocenv.sh
	-$(MAKE) --no-print-directory install_verilator
	-$(MAKE) --no-print-directory install_ossschem
	bash scripts/utils/build_verilator.sh
	bash scripts/utils/create_symlinks.sh

# Build VERILATOR_VERSION into ~/.local/verilator-<version> (no root, a few minutes
# the first time; nothing to do when it is already installed). setup_environment
# runs it; run it alone to update after VERILATOR_VERSION changes.
install_verilator:
	VERILATOR_VERSION=$(VERILATOR_VERSION) VERILATOR_PREFIX=$(VERILATOR_HOME) \
	bash scripts/utils/install_verilator.sh

# Install ossschem OSSSCHEM_VERSION into ~/.local/ossschem-<version> (checked
# against OSSSCHEM_SHA256; ~/.local/ossschem points at it) and its VS Code
# extension when `code` is on PATH. setup_environment runs it.
install_ossschem:
	@if [ -x "$(OSSSCHEM_HOME)/bin/ossschem" ]; then \
	  echo "ossschem $(OSSSCHEM_VERSION) already installed at $(OSSSCHEM_HOME)"; \
	else \
	  [ "$$(uname -sm)" = "Linux x86_64" ] || { echo "ossschem: only the linux-x64 release is pinned here; see https://github.com/markusdd/ossschem/releases"; exit 1; }; \
	  tmp=$$(mktemp -d) && \
	  curl -fsSL -o $$tmp/ossschem.tar.gz https://github.com/markusdd/ossschem/releases/download/v$(OSSSCHEM_VERSION)/ossschem-$(OSSSCHEM_VERSION)-linux-x64.tar.gz && \
	  echo "$(OSSSCHEM_SHA256)  $$tmp/ossschem.tar.gz" | sha256sum -c --quiet && \
	  mkdir -p $(OSSSCHEM_HOME) && tar -xzf $$tmp/ossschem.tar.gz -C $(OSSSCHEM_HOME) --strip-components=1 && \
	  rm -rf $$tmp && echo "ossschem $(OSSSCHEM_VERSION) installed at $(OSSSCHEM_HOME)"; \
	fi
	@ln -sfn $(OSSSCHEM_HOME) $(HOME)/.local/ossschem
	@if command -v code > /dev/null; then \
	  code --install-extension markusdd.ossschem@$(OSSSCHEM_VERSION) > /dev/null 2>&1 && \
	  echo "VS Code extension markusdd.ossschem@$(OSSSCHEM_VERSION) installed"; \
	else \
	  echo "VS Code ('code') not on PATH: install the extension markusdd.ossschem@$(OSSSCHEM_VERSION) from VS Code"; \
	fi

# ----------------------------------------------------------------------------
# Simulation and Testing
# ----------------------------------------------------------------------------
# `make sim` on every core that has a 'test' target, or only on IP=<core> (a
# bare name or a VLNV). Used by CI (.github/workflows/sim_svunit.yml). For each
# core report_svunit/ gets its log and its SVUnit JUnit report (tests.xml, one
# entry per test); a testbench that does not build gets a report with one
# failure instead. A core passes when SVUnit prints "[testrunner]: PASSED"
# (xsim exits 0 on failed tests too). Fails if any core failed.
SIM_TEST_CORES = $(shell grep -l -E '^  test:' $$(find cores -name '*.core') | xargs sed -n -E 's/^name *: *"?([^" ]+)"?.*/\1/p' | sort)

sim_svunit:
	@rm -rf report_svunit && mkdir -p report_svunit; \
	cores=""; \
	for c in $(SIM_TEST_CORES); do \
	  if [ -z "$(IP)" ] || [ "$(IP)" = "$$c" ] || [ "$(IP)" = "$${c%:*}" ] || [ "$(IP)" = "$$(echo $$c | cut -d: -f3)" ]; then \
	    cores="$$cores $$c"; \
	  fi; \
	done; \
	[ -n "$$cores" ] || { echo "sim_svunit: no core with a 'test' target matches '$(IP)'"; exit 1; }; \
	failed=""; \
	for c in $$cores; do \
	  id=$$(echo $$c | tr ':' '_'); \
	  rm -f build/$$id/test-xsim/tests.xml; \
	  $(MAKE) --no-print-directory sim IP=$$c > report_svunit/$$id.log 2>&1; \
	  if grep -q '\]\[testrunner\]: PASSED' report_svunit/$$id.log; then echo "PASS $$c"; \
	  else echo "FAIL $$c"; failed="$$failed $$c"; fi; \
	  if [ -f build/$$id/test-xsim/tests.xml ]; then cp build/$$id/test-xsim/tests.xml report_svunit/$$id.xml; \
	  else printf '<testsuites><testsuite name="%s"><testcase classname="%s" name="build"><failure message="the testbench did not build or run, see %s.log" type="failure"/></testcase></testsuite></testsuites>\n' $$c $$c $$id > report_svunit/$$id.xml; fi; \
	done; \
	n=$$(echo $$cores | wc -w); nf=$$(echo $$failed | wc -w); \
	echo "sim_svunit: $$((n - nf)) of $$n cores passed (report_svunit/)"; \
	[ -z "$$failed" ] || { echo "failed:$$failed"; exit 1; }

# Run the FuseSoC 'test' target (SVUnit via xsim) for a single core. Fast path.
#   make sim IP=lfsr
#   make sim IP=fifo_async MODE=fwft DEPTH=16 WIDTH=24
sim:
	. ../../.venv/bin/activate; \
	fusesoc $(FUSESOC_CORES) run --target test $(IP) $(SIM_ARGS)

# Sweep every fifo_async configuration that matters for the streamer swap:
#   read mode x {big/generic, streamer-sized} x clock ratio = 8 runs.
# Keeps going on failure and reports the list of failed configs at the end.
sim-fifo-matrix:
	@fail=0; failed=""; \
	for mode in std fwft; do \
	  for cfg in "2048 32" "16 24"; do \
	    set -- $$cfg; \
	    for swap in 0 1; do \
	      cfgname="MODE=$$mode DEPTH=$$1 WIDTH=$$2 SWAP_CLK=$$swap"; \
	      echo ""; \
	      echo "=============================================================="; \
	      echo "=== fifo_async  $$cfgname"; \
	      echo "=============================================================="; \
	      if ! $(MAKE) --no-print-directory sim IP=fifo_async \
	           MODE=$$mode DEPTH=$$1 WIDTH=$$2 SWAP_CLK=$$swap; then \
	        fail=1; failed="$$failed\n  $$cfgname"; \
	      fi; \
	    done; \
	  done; \
	done; \
	echo ""; \
	if [ $$fail -eq 0 ]; then \
	  echo "*** fifo_async matrix: all 8 configurations passed"; \
	else \
	  printf "*** fifo_async matrix FAILED for:%b\n" "$$failed"; \
	fi; \
	exit $$fail

sim-streamer-matrix:
	@fail=0; failed=""; \
	for ip in streamer axis_streamer; do \
	  for cfg in "16 auto" "1024 block"; do \
	    set -- $$cfg; \
	    echo ""; \
	    echo "=== $$ip  FIFO=$$1 MEM=$$2"; \
	    if ! $(MAKE) --no-print-directory sim IP=$$ip FIFO=$$1 MEM=$$2; then \
	      fail=1; failed="$$failed\n  $$ip FIFO=$$1 MEM=$$2"; \
	    fi; \
	  done; \
	done; \
	echo ""; \
	if [ $$fail -eq 0 ]; then \
	  echo "*** streamer matrix: all configurations passed"; \
	else \
	  printf "*** streamer matrix FAILED for:%b\n" "$$failed"; \
	fi; \
	exit $$fail

# Run the FuseSoC 'lint' target. Without TOOL the core's default tool runs (Verible: style and naming rules).
#   make lint IP=<core>                  Verible
#   make lint IP=<core> TOOL=verilator   Verilator lint-only, -Wall: widths, unused signals, latches
# TOOL counts only when given on the command line (or in the environment): the TOOL ?= default above is for other targets.
# NOTE: IPs instantiating Xilinx primitives (DSP/XPM/DDS) can't be linted by Verilator alone.
lint:
	. ../../.venv/bin/activate; \
	fusesoc $(FUSESOC_CORES) run --target lint $(if $(filter command line environment,$(origin TOOL)),--tool $(TOOL)) $(IP)

# ----------------------------------------------------------------------------
# Code Coverage
# ----------------------------------------------------------------------------
# Re-runs the SVUnit testbenches and reports DUT coverage. Neither backend
# instruments the testbench, clk_gen or vendor files: those outweigh the DUT
# by a wide margin (a 3-statement core sits next to a 500-statement testbench),
# so an unfiltered total measures the bench, not the design.
#
#   make coverage IP=cdc_handshake                        # Verilator, toggle
#   make coverage IP=cdc_handshake COV_MIN=80             # CI gate on toggle
#   make coverage IP=cdc_handshake COV_BACKEND=xsim COV=sb
#   make coverage IP=xcom COV_DEFINE=SVUNIT               # enable interface SVA
#   make coverage-summary
#
# IP= takes the short core name, a VLNV or a VLNV with version; an ambiguous
# short name is an error listing the candidates.
coverage:
	@if [ -z "$(IP)" ]; then \
	echo " Usage: make coverage IP=<ip_name> [COV_BACKEND=verilator|xsim] [CONFIGS=..|..] [COV_MIN=<pct>]"; \
	echo ""; \
	echo "Examples:"; \
	echo "  make coverage IP=cdc_handshake"; \
	echo "  make coverage IP=cdc_handshake COV_MIN=80"; \
	echo "  make coverage IP=fifo_async COV_BACKEND=xsim COV=sb"; \
	echo "  make coverage IP=fifo_async CONFIGS=\"--TB_N=64|--TB_N=256\""; \
	exit 1; \
	fi
	. ../../.venv/bin/activate; \
	echo "==> backend: $(COV_BACKEND)"; \
	python3 scripts/cov/cov_run.py --core $(IP) $(COV_ARGS) $(COV_CONFIG_ARGS)

# Aggregate every per-core summary.json into one table. --metric picks the
# column the gate reads; toggle is the only metric both backends measure, so it
# is the default and lets a sweep mix verilator and xsim cores.
#
# A core that has no score for the gated metric FAILS the gate rather than being
# skipped: a gate that quietly excludes unmeasured cores exits 0 and reads as
# "coverage is fine". Cores reporting zero coverage points are reported as
# unusable for the same reason; COV_SOFT_ZERO=1 downgrades only that case.
coverage-summary:
	. ../../.venv/bin/activate; \
	python3 scripts/cov/cov_summary.py --root $(COV_OUT) \
	  --sort $(if $(COV_SORT),$(COV_SORT),line_pct) \
	  $(if $(COV_MIN),--min-toggle $(COV_MIN),) \
	  $(if $(COV_SOFT_ZERO),--ignore-zero-statements,) \
	  --out $(COV_OUT)/summary_all.json

# Sweep a core's interesting configurations and merge the databases into one
# report. Intended to give a number reflecting the RTL you actually deploy
# rather than the single default parameterization.
#
# NOT WORKING in this tree, for any core or backend. Every core declaring
# `parameters:` on its test target uses `paramtype: vlogparam`, which edalize
# turns into a command-line override aimed at the toplevel -- and the toplevel
# is the svunit_gen-generated `testrunner`, which does not declare it. Both
# verilator and xsim reject it identically. The parsing below is correct; the
# core-side parameter mechanism is the blocker. See ../docs/developer/COVERAGE.md.
#   make coverage-matrix IP=fifo_async CONFIGS="--TB_N=16|--TB_N=2048"
coverage-matrix:
	@if [ -z "$(IP)" ] || [ -z "$(strip $(CONFIGS))" ]; then \
	echo " Usage: make coverage-matrix IP=<ip_name> CONFIGS=\"<cfg>|<cfg>|...\""; \
	exit 1; \
	fi
	$(MAKE) --no-print-directory coverage IP=$(IP) CONFIGS="$(CONFIGS)"

# Coverage for every core that declares a 'test' target.
#
# Cores instantiating Xilinx primitives (xpm_*, DSP) do not elaborate under
# Verilator and are reported as failures rather than silently skipped -- use
# COV_BACKEND=xsim for those. Testbenches that drive their DUT through the
# interface's clocking-block driver tasks cannot compile under Verilator either.
#
# Cores run COV_JOBS at a time (default 4). Verilator itself parallelises its
# C++ build via --build-jobs, so running many cores concurrently as well is
# what keeps the host busy; raise it on a machine with cores to spare, drop to
# 1 when debugging.
#
# COV_FILTER narrows the sweep to a regex on the VLNV:
#   make coverage-all                                   # all cores
#   make coverage-all COV_FILTER='^qick:ip:'             # the packaged IPs
#   make coverage-all COV_FILTER='^qick:mem:'
coverage-all:
	@echo " Coverage for all cores with a 'test' target ($(COV_BACKEND) backend, $(COV_JOBS) at a time)"
	. ../../.venv/bin/activate; \
	export PYTHONPATH=scripts:$$PYTHONPATH; \
	fusesoc $(FUSESOC_ROOTS) list-cores 2>/dev/null | cut -d: -f1-3 | sort -u \
	  | { $(if $(COV_FILTER),grep -E '$(COV_FILTER)',cat); } \
	  | xargs -P $(COV_JOBS) -I{} sh -c ' \
	      fusesoc $(FUSESOC_ROOTS) core-info {} 2>/dev/null \
	        | grep -qE "^test[ ]+:" || exit 0; \
	      echo ""; echo "=== {} ==="; \
	      python3 scripts/cov/cov_run.py --core {} $(COV_ARGS)' \
	  ; status=$$?; \
	echo ""; \
	if [ $$status -eq 0 ]; then \
	  echo "*** coverage-all: all cores reported"; \
	else \
	  echo "*** coverage-all: at least one core failed (see per-core output above)"; \
	fi; \
	exit $$status

# ----------------------------------------------------------------------------
# IP Packaging (Vivado; always resolves dependencies from rtl_lib/)
# ----------------------------------------------------------------------------
# Package a single IP via the ip_packager generator into build/package_<ip>/.
package:
	@if [ -z "$(IP)" ]; then \
	echo " Usage: make package IP=<ip_name> [DESCRIPTION=<description>] [VERSION=1.0] [PART=<part>]"; \
	echo ""; \
	echo "Examples:"; \
	echo "  make package IP=xcom"; \
	echo "  make package IP=xcom VERSION=2.0"; \
	echo "  make package IP=xcom PART=xczu28dr-ffvg1517-2-e"; \
	exit 1; \
	fi
	@echo " Packaging IP: $(IP)"
	. ../../.venv/bin/activate; \
	mkdir -p build/package_$(IP); \
	cd build/package_$(IP) && \
	python3 ../../generators/ip_gen/ip_packager.py \
	--ip-name    $(IP) \
	$(if $(VERSION),--version $(VERSION),) \
	--part       $(or $(PART),xczu49dr-ffvf1760-2-e) \
	--display-name "$(or $(DISPLAY_NAME),$(IP))" \
	$(if $(DESCRIPTION),--description "$(DESCRIPTION)",)

# Package every IP under cores/ip/. Keeps going if one IP fails to package
# (e.g. missing/invalid RTL or RDL source) instead of aborting the whole run;
# failures are collected and reported as a warning list at the end.
package-all:
	@echo " Packaging all IPs in cores/ip/..."
	@fail=0; failed=""; \
	for ip_dir in cores/ip/*/; do \
	ip=$$(basename $$ip_dir); \
	echo ""; \
	echo "=== Packaging $$ip ==="; \
	if ! $(MAKE) --no-print-directory package IP=$$ip; then \
	  echo " WARNING: $$ip failed to package -- run 'make verify-core IP=$$ip' to see what's missing"; \
	  fail=1; failed="$$failed\n  $$ip"; \
	fi; \
	done; \
	echo ""; \
	if [ $$fail -eq 0 ]; then \
	  echo " All IPs packaged successfully!"; \
	else \
	  printf " *** package-all: FAILED to package:%b\n" "$$failed"; \
	fi; \
	exit $$fail

# Generate the packaging TCL without running Vivado (inspection / debug).
# Hog list files with the exact RTL/XDC the pre-creation hook packages for a
# project's qick:ip IPs (list/qick_ip_rtl.src, list/qick_ip_xdc.con), so Hog's
# version and SHA follow that RTL. CHECK=1 only verifies (pre-creation runs it).
# See scripts/hog/gen_qick_ip_lists.py and HOG_QICK_Integration_Guide.md.
hog-lists:
	@if [ -z "$(PROJ)" ]; then echo " Usage: make hog-lists PROJ=<group>/<project> [CHECK=1]"; exit 1; fi
	. ../../.venv/bin/activate; \
	python3 ../scripts/hog/gen_qick_ip_lists.py $(if $(CHECK),--check,) $(if $(BD_DIR),--bd-dir $(BD_DIR),) $(PROJ)

# Every project that packages its BD IPs in pre-creation.
hog-lists-all:
	@. ../../.venv/bin/activate; rc=0; \
	for p in $$(cd .. && ls -d Top/*/*/pre-creation.tcl | xargs -n1 dirname); do \
	  python3 ../scripts/hog/gen_qick_ip_lists.py $(if $(CHECK),--check,) $$p || rc=1; \
	done; exit $$rc

package-dry:
	@if [ -z "$(IP)" ]; then \
	echo " Usage: make package-dry IP=<ip_name>"; \
	exit 1; \
	fi
	. ../../.venv/bin/activate; \
	mkdir -p build/package_$(IP); \
	cd build/package_$(IP) && \
	python3 ../../generators/ip_gen/ip_packager.py \
	--ip-name $(IP) \
	--dry-run

# ----------------------------------------------------------------------------
# Cleanup
# ----------------------------------------------------------------------------
# Removes build/, the pytest, SVUnit and coverage reports, Vivado leftovers and .fusesoc_libraries (the cloned
# SVUnit: the next `make sim`/`sim_svunit` clones it again, so it needs network).
# Does NOT touch venv/ or source symlinks.
clean:
	rm -rf build report_pytest report_svunit report_cov vivado* .Xil .fusesoc_libraries

# ----------------------------------------------------------------------------
# Core Information and Inspection
# ----------------------------------------------------------------------------
# List all cores across the four roots.
list-cores:
	. ../../.venv/bin/activate; \
	fusesoc $(FUSESOC_CORES) list-cores

# Show a core's filesets / targets / deps.  make core-info CORE=qick:ip:xcom
core-info:
	@if [ -z "$(CORE)" ]; then \
	echo " Usage: make core-info CORE=<core_name>"; \
	echo "Example: make core-info CORE=qick:ip:xcom"; \
	exit 1; \
	fi
	. ../../.venv/bin/activate; \
	fusesoc $(FUSESOC_CORES) core-info $(CORE)

# Resolved dependencies of a core, in compile order (scripts/core_deps.py: `fusesoc core-info` no longer prints them).
# IP is a bare name of any category (xcom, tpv2_alu) or a VLNV; TARGET picks the target (default: default).
deps:
	@if [ -z "$(IP)" ]; then \
	echo " Usage: make deps IP=<core_name> [TARGET=<target>]"; \
	echo "Example: make deps IP=xcom"; \
	exit 1; \
	fi
	. ../../.venv/bin/activate; \
	python3 scripts/core_deps.py $(FUSESOC_CORES) $(if $(TARGET),--target $(TARGET)) $(IP)

# Documentation completeness: every IP README has the template's sections, every Hog project and every
# library category has a README (the category lists all its cores), and no relative Markdown link is broken.
doc-check:
	@python3 scripts/doc_check.py

# Sanity-check that a core's dir, .core, RTL source and packaged source exist.
verify-core:
	@if [ -z "$(IP)" ]; then \
	echo " Usage: make verify-core IP=<ip_name>"; \
	exit 1; \
	fi
	@echo "=== Verifying core: qick:ip:$(IP) ==="
	@if [ -d "cores/ip/$(IP)" ]; then \
	echo " Core directory exists: cores/ip/$(IP)"; \
	else \
	echo " Core directory missing: cores/ip/$(IP)"; \
	fi
	@if [ -f "cores/ip/$(IP)/$(IP).core" ]; then \
	echo " Core file exists: cores/ip/$(IP)/$(IP).core"; \
	else \
	echo " Core file missing: cores/ip/$(IP)/$(IP).core"; \
	fi
	@if [ -d "../rtl_lib/ip/$(IP)" ]; then \
	echo " RTL source exists: ../rtl_lib/ip/$(IP)/"; \
	else \
	echo "  RTL source missing: ../rtl_lib/ip/$(IP)/ (create it!)"; \
	fi
	@if [ -d "../ip/$(IP)/src" ]; then \
	echo " Packaged IP source exists: ../ip/$(IP)/src"; \
	else \
	echo "  IP not packaged yet (run 'make package IP=$(IP)')"; \
	fi
	@echo ""
	@echo "=== Dependencies ==="
	$(MAKE) --no-print-directory deps IP=$(IP)

# ----------------------------------------------------------------------------
# Register map & driver (PeakRDL)
# ----------------------------------------------------------------------------
# Generate the PeakRDL regmap package from the IP's RDL.
# NOTE: activates venv and uses -C so systemrdl is available in the sub-make.
#   make rdl-gen IP=axis_constant_iq
# An IP configured only through a stream (axis_readout_v3, axis_dyn_readout_v1)
# keeps an rdl/ whose address map declares no register: there is nothing to
# generate, and rdl-gen, driver and driver-all say so and skip it.
RDL_HAS_REGS = grep -qE '^[[:space:]]*reg[[:space:]]*\{' cores/ip/$(1)/rdl/$(1)_regmap.rdl

rdl-gen:
	@if [ -z "$(IP)" ]; then \
	echo "Usage: make rdl-gen IP=<ip_name>"; \
	exit 1; \
	fi
	@if ! $(call RDL_HAS_REGS,$(IP)); then echo "$(IP): the RDL declares no registers, nothing to generate"; exit 0; fi; \
	. ../../.venv/bin/activate; \
	PYTHONHASHSEED=0 $(MAKE) -C cores/ip/$(IP)/rdl gen

# Scaffold cores/ip/<ip>/ (rdl/, driver/, hdl/, tests/).
new-ip:
	@if [ -z "$(IP)" ]; then \
	echo "Usage: make new-ip IP=<ip_name>"; \
	exit 1; \
	fi
	./scripts/create_ip.sh $(IP)

# Full driver flow: regmap gen -> create driver if missing -> symlink into qick_lib -> register tests.
driver:
	@if [ -z "$(IP)" ]; then echo "Usage: make driver IP=<ip_name>"; exit 1; fi
	@if ! $(call RDL_HAS_REGS,$(IP)); then echo "$(IP): the RDL declares no registers, no register driver to generate"; \
	else $(MAKE) --no-print-directory _driver IP=$(IP); fi

_driver:
	@echo "Generating driver for $(IP)..."
	. ../../.venv/bin/activate; \
	PYTHONHASHSEED=0 $(MAKE) -C cores/ip/$(IP)/rdl gen
	@./scripts/gen_driver.sh $(IP)
	@if [ -L cores/ip/$(IP)/driver/$(IP).py ]; then \
		echo "  driver is an alias of a monolithic qick_lib module: no qick_lib symlink needed"; \
	elif [ -f cores/ip/$(IP)/driver/$(IP).py ]; then \
		ln -sf ../../../firmware/fusesoc/cores/ip/$(IP)/driver/$(IP).py \
			     ../../qick_lib/qick/drivers/$(IP).py; \
		echo "  Symlink created (QickSoc auto-imports it from qick/drivers/)"; \
	fi
	@if [ -d cores/ip/$(IP)/rdl/$(IP)_regmap_pkg ]; then \
		mkdir -p ../../qick_lib/qick/rdl_pkgs; \
		rm -rf ../../qick_lib/qick/rdl_pkgs/$(IP)_regmap_pkg; \
		cp -r cores/ip/$(IP)/rdl/$(IP)_regmap_pkg ../../qick_lib/qick/rdl_pkgs/; \
		echo "  regmap_pkg copied to rdl_pkgs/"; \
	fi
	@$(MAKE) --no-print-directory driver-test IP=$(IP)

# Fail if a VLNV is bound by more than one driver class (../docs/user/IP_INTEGRATION.md, rule 1).
driver-bindings:
	@python3 scripts/check_driver_bindings.py

# Run the register-layer pytest only (no regeneration). Scaffolds tests if
# absent. Writes report_pytest/driver-<ip>-report.xml.
driver-test:
	@if [ -z "$(IP)" ]; then echo "Usage: make driver-test IP=<ip_name>"; exit 1; fi
	@if [ ! -f cores/ip/$(IP)/driver/tests/test_$(IP)_regs.py ]; then \
     echo "No driver tests for $(IP) — scaffolding from RDL..."; \
     $(MAKE) --no-print-directory driver-scaffold IP=$(IP); \
	fi
	@echo "Running driver register tests for $(IP)..."; \
	mkdir -p report_pytest; \
	if [ ! -d cores/ip/$(IP)/rdl/$(IP)_regmap_pkg ] && $(call RDL_HAS_REGS,$(IP)); then \
	  $(MAKE) --no-print-directory rdl-gen IP=$(IP); \
	fi; \
	. ../../.venv/bin/activate; \
	pytest cores/ip/$(IP)/driver/tests/ -v \
	  --junitxml=report_pytest/driver-$(IP)-report.xml

# Run `make driver` (gen + qick_lib symlink + rdl_pkgs copy + register tests) for every
# IP under cores/ip/ that has rdl/Makefile. Keeps going on failure and reports at the end.
driver-all:
	@failed=""; \
	for ip in $$(ls -d cores/ip/*/); do \
	ip_name=$$(basename $$ip); \
	if [ -f $$ip/rdl/Makefile ]; then \
	    if ! grep -qE '^[[:space:]]*reg[[:space:]]*\{' $$ip/rdl/$${ip_name}_regmap.rdl; then \
	        echo "skip $$ip_name: the RDL declares no registers"; continue; \
	    fi; \
	    $(MAKE) --no-print-directory driver IP=$$ip_name || failed="$$failed $$ip_name"; \
	fi; \
	done; \
	if [ -n "$$failed" ]; then echo "driver-all FAILED for:$$failed"; exit 1; fi

# Fail if the tracked qick_lib/qick/rdl_pkgs/<ip>_regmap_pkg no longer matches what the RDL
# generates now (generation is deterministic thanks to PYTHONHASHSEED=0). Fix: make driver IP=<ip>
driver-check:
	@if [ -z "$(IP)" ]; then echo "Usage: make driver-check IP=<ip_name>"; exit 1; fi
	@if [ ! -d ../../qick_lib/qick/rdl_pkgs/$(IP)_regmap_pkg ] \
	   && ! grep -qE "RDL_IP *= *'$(IP)'|$(IP)_regmap_pkg" ../../qick_lib/qick/drivers/*.py; then \
	  echo "$(IP): its driver does not use the register package, nothing to check"; exit 0; \
	fi; \
	. ../../.venv/bin/activate; \
	tmp=$$(mktemp -d); \
	( cd cores/ip/$(IP)/rdl && PYTHONHASHSEED=0 python3 ../../../../generators/systemrdl/rdl_tools.py $(IP)_regmap.rdl --output $$tmp --python >/dev/null ); \
	if diff -r -x __pycache__ -x tests -x lib_test $$tmp/$(IP)_regmap_pkg ../../qick_lib/qick/rdl_pkgs/$(IP)_regmap_pkg; then \
	    echo "OK: rdl_pkgs/$(IP)_regmap_pkg is up to date"; rm -rf $$tmp; \
	else \
	    echo "DRIFT: run 'make driver IP=$(IP)' and commit qick_lib/qick/rdl_pkgs/$(IP)_regmap_pkg"; rm -rf $$tmp; exit 1; \
	fi

# Scaffold driver/tests/ from the generated RDL package (idempotent).
driver-scaffold:
	@if [ -z "$(IP)" ]; then echo "Usage: make driver-scaffold IP=<ip_name>"; exit 1; fi
	. ../../.venv/bin/activate; \
	python3 scripts/gen_driver_tests.py $(IP)

# Generate HTML register documentation from RDL.
# NOTE: activates venv for the sub-make (PeakRDL needs systemrdl/peakrdl-html).
#   make rdl-docs IP=axis_constant_iq
rdl-docs:
	@if [ -z "$(IP)" ]; then echo "Usage: make rdl-docs IP=<ip_name>"; exit 1; fi
	. ../../.venv/bin/activate; \
	$(MAKE) -C cores/ip/$(IP)/rdl docs
	@echo "✓ Docs: cores/ip/$(IP)/rdl/docs/index.html"

# ----------------------------------------------------------------------------
# RTL Library Documentation (custom Markdown generator over ../rtl_lib)
# ----------------------------------------------------------------------------
# Generate Markdown docs (TerosHDL-style Generics/Ports tables) for the RTL
# library. Reads doc from //! blocks and legacy /** @port/@param */ headers.
# Excludes come from ../rtl_lib/.docsignore.
#   make rtl-docs                                   # document all of ../rtl_lib
#   make rtl-docs INPUT=../rtl_lib/dsp/sgv6_top.sv  # single file
rtl-docs:
	. ../../.venv/bin/activate; \
	python3 scripts/gen_docs.py \
	--input  $(if $(INPUT),$(INPUT),$(RTL_DOCS_IN)) \
	--outdir $(RTL_DOCS_OUT) \
	--index
	@echo "✓ RTL docs: $(RTL_DOCS_OUT)/README.md"

# Remove generated RTL docs (and any stale Doxygen output).
rtl-docs-clean:
	@rm -rf $(RTL_DOCS_OUT) ../docs/rtl
	@echo "✓ Cleaned RTL docs"

# ----------------------------------------------------------------------------
# Block Diagrams (real ports + real wiring between TOP's direct children,
# not gate-level)
# ----------------------------------------------------------------------------
# Elaborates TOP with Verilator and renders it as a real functional block
# diagram: TOP's own boundary ports, one box per direct-child instance with
# its actual port list (inputs left, outputs right), and wires connecting
# specific pins wherever they share a net -- not just a containment tree.
# Submodule names come straight from ../rtl_lib; siblings from a `generate`
# loop collapse into one "name (xN)" box (wiring shown is the first
# instance's, as a representative); SV interface instances are dropped.
#
# TOP is whichever module's boundary you want the diagram centered on --
# if the packaged IP is a thin wrapper around one real submodule (e.g.
# axis_dyn_readout_v1 -> readout_top_dynro), point TOP at that inner module
# instead to reach the real blocks in one diagram.
#
# For general/public docs, prefer the hand-drawn diagrams below
# (`make tikz-diagrams`) -- this auto-generated one is useful as a
# starting point or cross-check against the RTL, but reads more like a
# netlist dump than a diagram meant to teach someone the architecture.
#
# Missing vendor primitives (Xilinx XPM, etc.) need a blackbox stub added
# under scripts/block_diagram_stubs/ -- the error message names the module.
#   make block-diagram TOP=sgv6_top
#   make block-diagram TOP=readout_top_dynro IP=dyn_readout
block-diagram:
	@if [ -z "$(TOP)" ]; then \
	echo " Usage: make block-diagram TOP=<top_module> [IP=<output_name>]"; \
	exit 1; \
	fi
	. ../../.venv/bin/activate; \
	python3 scripts/gen_block_diagram.py $(TOP) \
	../docs/block-diagrams/$(or $(IP),$(TOP)).svg

# ----------------------------------------------------------------------------
# Interactive schematic (ossschem)
# ----------------------------------------------------------------------------
# The whole hierarchy of TOP as a schematic you expand and trace in VS Code (the
# ossschem extension): the same Verilator elaboration as block-diagram, written as
# build/schematic/<name>/schematic-ir.json and opened when `code` is on PATH. Needs
# Verilator >= 5.046 and ossschem (make setup_environment installs both).
# A module Verilator cannot find becomes a port-only blackbox: UNISIM/XPM from the
# Vivado install (source its settings64.sh), IP cores and block designs from the
# stubs Vivado wrote in the worktree (build that Vivado project once).
# PROJ=<group>/<project> draws a whole Vivado project of Top/: its top (set_property
# top, else d_1_wrapper), its block designs opened from what Vivado generated in
# Projects/ (the project must have been created: ./Hog/Do CREATE <group>/<project>)
# and, inside them, our IPs down to their RTL; vendor IPs stay blackboxes.
#   make schematic TOP=axis_avg_buffer
#   make schematic PROJ=216/xcom_async_mc3
schematic:
	@if [ -z "$(TOP)$(PROJ)" ]; then \
	echo " Usage: make schematic TOP=<top_module> | PROJ=<group>/<project> [TOP=<module>]"; \
	exit 1; \
	fi
	. ../../.venv/bin/activate; \
	out=build/schematic/$(if $(PROJ),$(subst /,_,$(PROJ)),$(TOP)); \
	python3 scripts/gen_block_diagram.py $(TOP) $(if $(PROJ),--proj $(PROJ)) --ir $$out \
	  --ossschem $(OSSSCHEM_HOME)/bin/ossschem && \
	{ command -v code > /dev/null && code -r $$out/schematic-ir.json || true; }

# ----------------------------------------------------------------------------
# Hand-Drawn Block Diagrams (TikZ/circuitikz, for general/public docs)
# ----------------------------------------------------------------------------
# Compiles ../docs/block-diagrams/tikz/<name>.tex to a tightly-cropped
# ../docs/block-diagrams/<name>.svg. These are hand-authored (in the style of
# prior QICK talk/seminar figures), not extracted from RTL -- each one's
# topology is verified by hand against the real source, but the diagram
# itself is drawn for clarity, not completeness. Requires pdflatex,
# ghostscript (gs) and poppler-utils (pdftocairo) on PATH.
#   make tikz-diagrams              # rebuild every diagram
#   make tikz-diagram NAME=sg_v6    # rebuild just one
tikz-diagrams:
	@for f in ../docs/block-diagrams/tikz/*.tex; do \
	name=$$(basename $$f .tex); \
	$(MAKE) --no-print-directory tikz-diagram NAME=$$name; \
	done

tikz-diagram:
	@if [ -z "$(NAME)" ]; then \
	echo " Usage: make tikz-diagram NAME=<name>  (reads ../docs/block-diagrams/tikz/<name>.tex)"; \
	exit 1; \
	fi
	bash scripts/gen_tikz_diagram.sh $(NAME)
