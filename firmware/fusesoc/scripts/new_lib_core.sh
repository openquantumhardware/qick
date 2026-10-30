#!/bin/bash
# ============================================================================
# new_lib_core.sh - Create a new library core under cores/lib/<category>/<core>/
#   with the standard QICK FuseSoC tree (anchors-based .core), a symlink to
#   rtl_lib/<category>/<core>.sv, and SVUnit testbench stubs.
#
# Layout:
#   firmware/fusesoc/cores/lib/<category>/<core>/   <- created here
#   firmware/rtl_lib/<category>/<core>.sv           <- symlink target
#
# Categories: utils | math | cdc | mem | axi | interfaces | processors
#
# Usage:
#   ./scripts/new_lib_core.sh <category> <core_name> [pkg_depend]
#
# Examples:
#   ./scripts/new_lib_core.sh utils lfsr
#   ./scripts/new_lib_core.sh math  tpv2_alu  qick:pkg:alu_pkg
#   ./scripts/new_lib_core.sh utils tpv1_ctrl qick:pkg:tproc_pkg
# ============================================================================
set -euo pipefail

CATEGORY="${1:-}"
CORE="${2:-}"
PKG_DEPEND="${3:-}"   # optional package dependency, e.g. qick:pkg:alu_pkg

if [ -z "$CATEGORY" ] || [ -z "$CORE" ]; then
    echo "Usage: $0 <category> <core_name> [pkg_depend]"
    echo "  categories: utils | math | cdc | mem | axi | interfaces | processors"
    echo "  e.g. $0 utils lfsr"
    echo "       $0 math  tpv2_alu qick:pkg:alu_pkg"
    exit 1
fi

# --- Locate roots -----------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FUSESOC_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"               # firmware/fusesoc
RTL_LIB_ROOT="$(cd "$FUSESOC_ROOT/../rtl_lib" && pwd)"     # firmware/rtl_lib

CORE_DIR="$FUSESOC_ROOT/cores/lib/$CATEGORY/$CORE"
RTL_FILE="$RTL_LIB_ROOT/$CATEGORY/${CORE}.sv"

# --- Sanity checks ----------------------------------------------------------
if [ -d "$CORE_DIR" ]; then
    echo "ERROR: core directory already exists: $CORE_DIR"
    exit 1
fi
if [ ! -f "$RTL_FILE" ]; then
    echo "WARNING: RTL source not found: $RTL_FILE"
    echo "         (symlink will be created anyway; add the RTL later)"
fi

echo "Creating library core:"
echo "  category : $CATEGORY"
echo "  name     : $CORE"
echo "  pkg dep  : ${PKG_DEPEND:-<none>}"
echo "  core dir : $CORE_DIR"
echo "  rtl file : $RTL_FILE"

# --- Directories ------------------------------------------------------------
mkdir -p "$CORE_DIR"/{data,hdl,lint,tests}

# --- Symlink to RTL (relative path computed automatically) ------------------
REL_RTL="$(realpath --relative-to="$CORE_DIR/hdl" "$RTL_FILE")"
ln -sf "$REL_RTL" "$CORE_DIR/hdl/${CORE}.sv"
echo "  symlink  : hdl/${CORE}.sv -> $REL_RTL"

# --- Build the hdl 'depend' block -------------------------------------------
# If a package dependency was given, include it; otherwise leave a placeholder.
if [ -n "$PKG_DEPEND" ]; then
    HDL_DEPEND="    depend:
      - ${PKG_DEPEND}"
else
    HDL_DEPEND="    # depend:
    #   - qick:pkg:<your_pkg>   # add package deps here if needed"
fi

# --- .core file -------------------------------------------------------------
cat > "$CORE_DIR/${CORE}.core" << EOF
CAPI=2:
name: qick:${CATEGORY}:${CORE}:1.0.0
description: ${CORE} (${CATEGORY} library core).

filesets:
  hdl:
    files:
      - hdl/${CORE}.sv
    file_type: systemVerilogSource
${HDL_DEPEND}
  tb:
    files:
      - tests/${CORE}_tc00.sv
      - tests/${CORE}_tests.sv: {is_include_file: true}
    file_type: systemVerilogSource
    depend:
      - qick:common:sim_base
  lint_files:
    depend:
      - qick:common:lint

generate:
  testrunner_gen:
    generator: svunit_gen
    parameters:
        test_files:
          - tests/${CORE}_tc00.sv

targets:
  default: &default
    filesets: [hdl]
    toplevel: ${CORE}
  lint:
    <<: *default
    filesets_append: [lint_files]
    default_tool: veriblelint
    toplevel: ${CORE}
    tools:
      verilator:
        mode: lint-only
        verilator_options: [-Wall]
  test:
    <<: *default
    description: Simulate the design
    filesets_append: [tb]
    default_tool: xsim
    generate: [testrunner_gen]
    toplevel: testrunner
    tools:
      xsim:
        xelab_options: [-timescale=1ns/1ns -debug all -L XPM]
        xsim_options: [-testplusarg SVUNIT_FILTER="*" -onerror stop]
EOF
echo "  core file: ${CORE}.core"

# --- Testbench stubs --------------------------------------------------------
cat > "$CORE_DIR/tests/${CORE}_tc00.sv" << EOF
// ============================================================================
// File: ${CORE}_tc00.sv
// Description: SVUnit testbench top-level for ${CORE}.
// ============================================================================
\`include "svunit_defines.svh"
\`include "svunit_assert_macros.svh"

module ${CORE}_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "${CORE}_ut";
    svunit_testcase svunit_ut;

    localparam real CLOCK_FREQUENCY = 200e6;

    logic tb_clk  = 1'b0;
    logic tb_rstn = 1'b1;

    clk_gen #(.FREQ (CLOCK_FREQUENCY)) u_clk (.i_enable(1'b1), .o_clk(tb_clk));

    // TODO: declare DUT signals

    initial begin
        \$dumpfile("${CORE}.vcd");
        \$dumpvars(0, dut);
    end

    // TODO: instantiate the DUT
    // ${CORE} dut ( ... );

    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    \`SVUNIT_TESTS_BEGIN
    \`include "${CORE}_tests.sv"
    \`SVUNIT_TESTS_END

endmodule
EOF
echo "  tb stub  : tests/${CORE}_tc00.sv"

cat > "$CORE_DIR/tests/${CORE}_tests.sv" << EOF
// ============================================================================
// File: ${CORE}_tests.sv
// Description: SVUnit test cases for ${CORE}. Included by ${CORE}_tc00.sv.
// ============================================================================

\`SVTEST(tc_smoke)
    \`FAIL_IF(0);
\`SVTEST_END
EOF
echo "  tb stub  : tests/${CORE}_tests.sv"

echo ""
echo "Done. Next steps:"
echo "  1. Ensure RTL exists: $RTL_FILE"
echo "  2. If the module needs a package, set the hdl 'depend' (or re-run with"
echo "     the optional pkg_depend arg)."
echo "  3. Overwrite the TB stubs with real tests."
echo "  4. Run: fusesoc ... run --target test qick:${CATEGORY}:${CORE}"
