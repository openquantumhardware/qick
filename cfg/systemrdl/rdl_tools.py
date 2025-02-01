#!/usr/bin/env python3

from systemrdl import RDLCompiler, RDLCompileError
from peakrdl_regblock import RegblockExporter
from peakrdl_regblock.udps import ALL_UDPS
from peakrdl_regblock.cpuif.axi4lite import AXI4Lite_Cpuif
from peakrdl_html import HTMLExporter
from ralbot.headergen import headerGenExporter
import os
import sys

def hdl_gen(output_dir, input_files):

    rdlc = RDLCompiler()

    for udp in ALL_UDPS:
        rdlc.register_udp(udp)

    try:
        for input_file in input_files:
            rdlc.compile_file(input_file)

        root = rdlc.elaborate()
    except RDLCompileError:
        sys.exit(1)

    exporter = RegblockExporter()
    exporter.export(
        root, output_dir,
        cpuif_cls=AXI4Lite_Cpuif
    )

def html_gen(output_dir, input_files):

    rdlc = RDLCompiler()
    try:
        for input_file in input_files:
            rdlc.compile_file(input_file)

        root = rdlc.elaborate()
    except RDLCompileError:
        sys.exit(1)

    exporter = HTMLExporter()
    exporter.export(
        root, output_dir
    )

def c_header_gen(output_dir, input_files, top_level):
    rdlc = RDLCompiler()
    try:
        for input_file in input_files:
            rdlc.compile_file(input_file)
            filename = os.path.basename(input_file)
            filename = os.path.splitext(filename)[0]
            filename = output_dir + "/" + filename

            root = rdlc.elaborate()
            exporter = headerGenExporter(languages='c')
            exporter.export(root, filename, top_level)
    except RDLCompileError:
        sys.exit(1)

def verilog_header_gen(output_dir, input_files, top_level):
    rdlc = RDLCompiler()
    try:
        for input_file in input_files:
            rdlc.compile_file(input_file)
            filename = os.path.basename(input_file)
            filename = os.path.splitext(filename)[0]
            filename = output_dir + "/" + filename

            root = rdlc.elaborate()
            exporter = headerGenExporter(languages='verilog')
            exporter.export(root, filename, top_level)
    except RDLCompileError:
        sys.exit(1)

if __name__ == '__main__':

    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument("files", nargs='+', help="list of .rdl files")
    parser.add_argument("--output", "-o", help="output directory", default=".")
    parser.add_argument("--toplevel", help="indicates if is top rdl or not")
    args = parser.parse_args()

    hdl_gen(args.output, args.files)
    html_gen(args.output, args.files)
    c_header_gen(args.output, args.files, args.toplevel)
    verilog_header_gen(args.output, args.files, args.toplevel)
