#!/usr/bin/env python3
"""Register-map outputs of a QICK IP from its SystemRDL description (PeakRDL).

    rdl_tools.py <ip>_regmap.rdl [more.rdl ...] [--output DIR] [--python] [--html] [--hdl]

  --python  Python register model (peakrdl-python), written as DIR/<first rdl basename>_pkg/.
            This is what qick_lib/qick/rdl_pkgs/ holds and `make driver-check` compares.
  --html    HTML register documentation (peakrdl-html) in DIR.
  --hdl     SystemVerilog AXI4-Lite register block (peakrdl-regblock) in DIR.

All the .rdl files are compiled together, in the order given, and elaborated once.
Called by cores/ip/<ip>/rdl/Makefile (`make rdl-gen`, `make rdl-docs`) and by
`make driver-check`, which runs it with PYTHONHASHSEED=0 so the output is reproducible.
"""

import argparse
import shutil
import sys
import tempfile
from pathlib import Path

from systemrdl import RDLCompileError, RDLCompiler


def elaborate(rdl_files, udps=()):
    """Compile the .rdl files into one register tree; exit 1 on an RDL error."""
    compiler = RDLCompiler()
    for udp in udps:
        compiler.register_udp(udp)
    try:
        for rdl in rdl_files:
            compiler.compile_file(str(rdl))
        return compiler.elaborate()
    except RDLCompileError:
        # the compiler has already printed the diagnostics
        sys.exit(1)


def python_package(rdl_files, out_dir):
    """peakrdl-python into out_dir/<basename>_pkg, replacing what was there.

    peakrdl-python writes the package under a directory named after the
    register tree; its contents are moved up into <basename>_pkg so the import
    name follows the .rdl file, not the RDL addrmap name.
    """
    from peakrdl_python import PythonExporter

    root = elaborate(rdl_files)
    pkg = out_dir / f"{Path(rdl_files[0]).stem}_pkg"
    if pkg.exists():
        shutil.rmtree(pkg)
    pkg.mkdir(parents=True)
    with tempfile.TemporaryDirectory(dir=out_dir) as tmp:
        PythonExporter().export(node=root, path=tmp)
        for entry in Path(tmp).iterdir():
            sources = entry.iterdir() if entry.is_dir() else [entry]
            for src in sources:
                dst = pkg / src.name
                if src.is_dir():
                    shutil.copytree(src, dst, dirs_exist_ok=True)
                else:
                    shutil.copy2(src, dst)
    print(f"  python package: {pkg}")


def html_docs(rdl_files, out_dir):
    """peakrdl-html into out_dir (skipped, with a note, if it is not installed)."""
    try:
        from peakrdl_html import HTMLExporter
    except ImportError:
        print("  peakrdl-html is not installed: no HTML documentation")
        return
    HTMLExporter().export(elaborate(rdl_files), str(out_dir))
    print(f"  html documentation: {out_dir}")


def hdl_regblock(rdl_files, out_dir):
    """peakrdl-regblock with an AXI4-Lite CPU interface into out_dir."""
    from peakrdl_regblock import RegblockExporter
    from peakrdl_regblock.cpuif.axi4lite import AXI4Lite_Cpuif
    from peakrdl_regblock.udps import ALL_UDPS

    root = elaborate(rdl_files, ALL_UDPS)
    RegblockExporter().export(root, str(out_dir), cpuif_cls=AXI4Lite_Cpuif)
    print(f"  systemverilog register block: {out_dir}")


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("rdl", nargs="+", help=".rdl files, compiled in this order")
    ap.add_argument("--output", "-o", default=".", help="output directory (default: .)")
    ap.add_argument("--python", action="store_true", help="Python register package")
    ap.add_argument("--html", action="store_true", help="HTML documentation")
    ap.add_argument("--hdl", action="store_true", help="SystemVerilog AXI4-Lite register block")
    args = ap.parse_args()

    if not (args.python or args.html or args.hdl):
        ap.error("nothing to generate: give --python, --html and/or --hdl")
    out_dir = Path(args.output)
    out_dir.mkdir(parents=True, exist_ok=True)
    print(f"rdl_tools: {' '.join(args.rdl)}")
    if args.hdl:
        hdl_regblock(args.rdl, out_dir)
    if args.html:
        html_docs(args.rdl, out_dir)
    if args.python:
        python_package(args.rdl, out_dir)


if __name__ == "__main__":
    main()
