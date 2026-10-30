#!/bin/bash
# create_ip.sh - Creates the structure for a new IP core with support for PeakRDL
# Usage: ./scripts/create_ip.sh <ip_name>

IP_NAME=$1

if [ -z "$IP_NAME" ]; then
    echo "Uso: $0 <ip_name>"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib_vlnv.sh"
IP_DIR="cores/ip/$IP_NAME"

echo "Creating IP: $IP_NAME"

# Create directories
mkdir -p $IP_DIR/{hdl,rdl,constraints,driver,tests,data}

# Create symlink to HDL (assuming it is in rtl_lib/ip/)
ln -s ../../../../../rtl_lib/ip/${IP_NAME}.sv $IP_DIR/hdl/${IP_NAME}.sv 2>/dev/null || echo "  rtl_lib/ip/${IP_NAME}.sv was not found!"
# Create symlink to constraints (assuming it is in rtl_lib/constraints/)
ln -s ../../../../../rtl_lib/constraints/${IP_NAME}.xdc $IP_DIR/constraints/${IP_NAME}.xdc 2>/dev/null || echo "  rtl_lib/constraints/${IP_NAME}.xdc was not found!"
ln -s ../../../../../rtl_lib/constraints/${IP_NAME}_ooc.xdc $IP_DIR/constraints/${IP_NAME}_ooc.xdc 2>/dev/null || echo "  rtl_lib/constraints/${IP_NAME}_ooc.xdc was not found!"

# Create updated Makefile for the RDL
cat > $IP_DIR/rdl/Makefile << 'EOF'
IP_NAME    = $(shell basename $(shell dirname $(CURDIR)))
RDL_FILE   = $(IP_NAME)_regmap.rdl
GEN_SCRIPT = ../../../../generators/systemrdl/rdl_tools.py

gen:
	python3 $(GEN_SCRIPT) $(RDL_FILE) --output . --python

docs:
	python3 $(GEN_SCRIPT) $(RDL_FILE) --output . --html

clean: clean-docs
	rm -rf $(IP_NAME)_regmap_pkg $(IP_NAME)_regmap*.sv $(IP_NAME)_regmap*.svh

clean-docs:
	rm -rf index.html launcher* data search content css fonts js favicon.png

.PHONY: gen docs clean clean-docs
EOF
# Replace the placeholder with a real tab
sed -i 's/@@TAB@@/\t/' $IP_DIR/rdl/Makefile

# Create .gitignore for RDL
cat > $IP_DIR/rdl/.gitignore << 'GITIGNORE'
*_regmap_pkg/
*_regmap.sv
*_regmap_pkg.sv
*_regmap.svh
*.pyc
__pycache__/
GITIGNORE

# Create template from .rdl
cat > $IP_DIR/rdl/${IP_NAME}_regmap.rdl << EOF
// ${IP_NAME}_regmap.rdl
// SystemRDL register definition for ${IP_NAME} IP core

addrmap ${IP_NAME} {
    name = "${IP_NAME} Registers";
    desc = "Registers for the ${IP_NAME} IP core.";

    default regwidth = 32;
    default accesswidth = 32;
    default addressing = compact;

    // TODO: Define your registers here
    reg {
        name = "CTRL_REG";
        desc = "Control register";
        field {
            name = "ENABLE";
            desc = "Enable bit";
            sw = rw;
            hw = r;
        } ENABLE[0:0] = 0;
    } CTRL_REG @0x00;

    reg {
        name = "STATUS_REG";
        desc = "Status register";
        field {
            name = "READY";
            desc = "Ready flag";
            sw = r;
            hw = w;
        } READY[0:0] = 0;
    } STATUS_REG @0x04;
};
EOF

# Create template .core for the regmap
cat > $IP_DIR/rdl/${IP_NAME}_regmap.core << EOF
CAPI=2:
name: qick:ip:${IP_NAME}_regmap:0.1.0

filesets:
  rdl:
    files:
        - ${IP_NAME}_regmap.rdl : {file_type: user }
        - ${IP_NAME}_regmap.sv : {file_type: systemVerilogSource, is_include_file: true}
        - ${IP_NAME}_regmap_pkg.sv : {file_type: systemVerilogSource, is_include_file: true}
EOF

# Create template for the main .core 
cat > $IP_DIR/${IP_NAME}.core << EOF
CAPI=2:
name: qick:ip:${IP_NAME}:1.0.0
description: ${IP_NAME} IP core

filesets:
  hdl:
    files:
      - hdl/${IP_NAME}.sv
    file_type: systemVerilogSource
    depend:
      - qick:common:sim_base
      - qick:ip:${IP_NAME}_regmap

  tb:
    files:
      - tests/${IP_NAME}_tc00.sv
      - tests/${IP_NAME}_tests.sv: {is_include_file: true}
    file_type: systemVerilogSource
    depend:
      - qick:common:sim_base

generate:
  testrunner_gen:
    generator: svunit_gen
    parameters:
        test_files: 
          - tests/${IP_NAME}_tc00.sv

targets:
  default:
    filesets: [hdl]
    toplevel: ${IP_NAME}

  test:
    filesets: [hdl, tb]
    default_tool: xsim
    generate: [testrunner_gen]
    toplevel: testrunner
    tools:
      xsim:
        xelab_options: [-timescale=1ns/1ns -debug all -L XPM]
        xsim_options: [-testplusarg SVUNIT_FILTER="*" -onerror stop]
EOF

# Create template for the driver (PYNQ DefaultIP + PeakRDL reg model)
# CamelCase class name: axis_pid -> AxisPid
CLASS_NAME=$(echo "$IP_NAME" | sed -r 's/(^|_)([a-z])/\U\2/g')
DRIVER_FILE="$IP_DIR/driver/${IP_NAME}.py"
if [ -f "$DRIVER_FILE" ]; then
    echo "  driver ${IP_NAME}.py already exists — not overwriting"
else
cat > "$DRIVER_FILE" << EOF
"""
PYNQ driver for ${IP_NAME} IP core.
Wraps the PeakRDL-generated register model over PYNQ MMIO.

AUTO-GENERATED placeholder. Access registers via \`.regs\`, e.g.:
    ip = overlay.${IP_NAME}_0
    ip.regs.CTRL_REG.ENABLE.write(1)
Add high-level convenience methods below the marker; this file is only
generated once and never overwritten by the generator.
"""
import sys
from pathlib import Path
from pynq import DefaultIP

_REGMAP_DIR = Path(__file__).parent.parent / "rdl"
if str(_REGMAP_DIR) not in sys.path:
    sys.path.insert(0, str(_REGMAP_DIR))

from ${IP_NAME}_regmap_pkg.reg_model.${IP_NAME} import ${IP_NAME}_cls
from ${IP_NAME}_regmap_pkg.lib import NormalCallbackSet


def to_unsigned(val, bits=16):
    return val & ((1 << bits) - 1)


def to_signed(val, bits=16):
    half = 1 << (bits - 1)
    return val - (1 << bits) if val >= half else val


class ${CLASS_NAME}(DefaultIP):
    """PYNQ driver for ${IP_NAME}. Register access through \`.regs\`."""

    bindto = ['$(core_vlnv "$IP_NAME")']

    def __init__(self, description):
        super().__init__(description=description)
        self.regs = ${IP_NAME}_cls(
            callbacks=NormalCallbackSet(
                read_callback=self._reg_read,
                write_callback=self._reg_write,
            ),
            address=0,
        )

    # PeakRDL invokes these with keyword args (addr, width, accesswidth, data)
    def _reg_read(self, addr, **kwargs):
        return self.mmio.read(addr)

    def _reg_write(self, addr, data, **kwargs):
        self.mmio.write(addr, int(data) & 0xFFFFFFFF)

    # ── hand-written high-level methods below ──────────────────────────
EOF
    echo "  driver ${IP_NAME}.py created (PYNQ DefaultIP)"
fi

# Create template for the testbench
cat > $IP_DIR/tests/${IP_NAME}_tc00.sv << EOF
\`include "svunit_defines.svh"

module ${IP_NAME}_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "${IP_NAME}_ut";
    svunit_testcase svunit_ut;

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

    \`SVTEST(test_reset)
        \`FAIL_IF(0);
    \`SVTEST_END

    \`SVUNIT_TESTS_END
endmodule
EOF

cat > $IP_DIR/tests/${IP_NAME}_tests.sv << EOF
\`include "${IP_NAME}_tc00.sv"
EOF

# README for the person who uses the IP (from firmware/docs/developer/IP_README_TEMPLATE.md)
README_FILE="$IP_DIR/README.md"
if [ -f "$README_FILE" ]; then
    echo "  README.md already exists — not overwriting"
else
    sed "s/<ip_name>/${IP_NAME}/g" "$SCRIPT_DIR/../../docs/developer/IP_README_TEMPLATE.md" > "$README_FILE"
    echo "  README.md created from firmware/docs/developer/IP_README_TEMPLATE.md (fill it in: it is the IP's user guide)"
fi

echo ""
echo "✓ IP '$IP_NAME' created in $IP_DIR"
echo ""
echo "Next steps:"
echo "  1. Edit rdl/${IP_NAME}_regmap.rdl with registers"
echo "  2. cd rdl && make gen"
echo "  3. cd .. && fusesoc run --target=test qick:ip:${IP_NAME}"
echo "  4. Write README.md: the user guide of the IP (firmware/docs/developer/NEW_CORE.md, \"Documenting an IP\")"
