#!/usr/bin/env python3
"""
header_migrate.py — Normalize SystemVerilog headers to the TerosHDL `//!`
Doxygen style used by the FNAL/QICK template.

Handles, automatically, headers found in the wild:

  1. LEGACY banner : "Description:" prose, optional "Parameters:", and optional
     "Inputs:"/"Outputs:" port docs ("- name  description" lines).
  2. DOXYGEN block : /** ... */ or //! using @title/@brief/@details/@param/@port.
  3. NO HEADER     : insert a //! stub (with --stub-missing).

Non-doc noise is dropped: vim modelines, "Change history"/"Change log", and
banner rules.  Works for `module`, `interface`, and `package` declarations.

Usage:
    python header_migrate.py file.sv ...                       # dry-run diff
    python header_migrate.py --apply file.sv ...               # in-place (+.bak)
    python header_migrate.py --apply --author "@lharnaldi" \
                             --project "axis_kidsim_v3" *.sv
    python header_migrate.py --apply --stub-missing *.sv
    python header_migrate.py --apply --port-docs *.sv          # emit @port lines

Best-effort: always review the diff before applying.  Port docs from
Inputs:/Outputs: are emitted as //! @port lines in the header (with --port-docs)
or dropped with a warning otherwise; the port declarations themselves are never
edited.
"""

import argparse
import difflib
import re
import sys
from pathlib import Path

# Accept module / interface / package as the documented unit.
UNIT_RE = re.compile(r'^\s*(module|interface|package)\s+(\w+)', re.MULTILINE)

BANNER_KEYS = ("module :", "module:", "project:", "origin:", "file:",
               "interface:", "package:", "title:",
               "fermi national accelerator laboratory", "fermilab")

# Sections that are NOT documentation and must be dropped entirely.
DROP_SECTION_KEYS = ("change history:", "change log:", "changelog:",
                     "history:", "revision history:")

DOXY_TAG_RE = re.compile(r'@(\w+)\b')
MODELINE_RE = re.compile(r'^\s*//\s*vim:', re.IGNORECASE)
PORTDOC_RE = re.compile(r'^\s*-\s*(\w+)\s+(.*)')


def strip_comment_marker(line: str) -> str:
    s = line.rstrip("\n")
    s = re.sub(r'^\s*/\*\*?', '', s)      # /** or /*
    s = re.sub(r'\*/\s*$', '', s)         # */
    s = re.sub(r'^\s*//+!?\s?', '', s)    # // or //!
    s = re.sub(r'^\s*\*\s?', '', s)       # leading * in block comments
    return s


def is_banner_rule(line: str) -> bool:
    stripped = strip_comment_marker(line).strip()
    return bool(stripped) and set(stripped) <= set("=-_")


def find_header_block(lines, unit_line_idx):
    i = unit_line_idx - 1
    # skip blank lines AND compiler directives between header and 'module'
    while i >= 0 and (lines[i].strip() == ""
                      or lines[i].strip().startswith("`")):
        i -= 1
    if i < 0:
        return None
    stripped = lines[i].strip()
    if not (stripped.startswith("//") or stripped.startswith("*")
            or stripped.endswith("*/")):
        return None
    block_end = i + 1
    while i >= 0:
        s = lines[i].strip()
        if (s.startswith("//") or s.startswith("/*") or s.startswith("*")
                or s.endswith("*/") or s == ""):
            i -= 1
        else:
            break
    return i + 1, block_end


def parse_header(block_lines):
    """Return (banner, description_lines, params_dict, port_docs_dict, notes)."""
    banner, description_lines = [], []
    params, port_docs = {}, {}
    notes = []              # NEW: @note lines (Source:/Origin: provenance)
    mode = None
    for raw in block_lines:
        if is_banner_rule(raw) or MODELINE_RE.match(raw):
            continue
        content = strip_comment_marker(raw)
        low = content.strip().lower()

        mtag = DOXY_TAG_RE.match(content.strip())
        if mtag:
            tag = mtag.group(1).lower()
            rest = content.strip()[len(mtag.group(0)):].strip()
            if tag in ("brief", "details", "description", "title", "module"):
                mode = "description"
                if rest:
                    description_lines.append(rest)
                continue
            if tag == "param":
                pm = re.match(r'(\w+)\s+(.*)', rest)
                if pm:
                    params[pm.group(1)] = pm.group(2).strip()
                mode = None
                continue
            if tag == "port":
                pm = re.match(r'(\w+)\s+(.*)', rest)
                if pm:
                    port_docs[pm.group(1)] = pm.group(2).strip()
                mode = None
                continue
            if tag == "note":
                if rest:
                    notes.append(rest)
                mode = "note"
                continue
            if tag in ("file", "author", "version"):
                mode = None
                continue

        if any(low.startswith(k) for k in DROP_SECTION_KEYS):
            mode = "drop"
            continue

        # provenance -> @note
        if low.startswith(("source:", "origin:")):
            rest = content.split(":", 1)[1].strip()
            if rest:
                notes.append(f"Ported from {rest}")
            mode = "note"
            continue

        if low.startswith("description:"):
            mode = "description"
            rest = content.split(":", 1)[1].strip()
            if rest:
                description_lines.append(rest)
            continue
        if low.startswith("parameters:"):
            mode = "parameters"
            continue
        if low.startswith(("inputs:", "outputs:", "ports:")):
            mode = "ports"
            continue
        # Interfaces: documented as part of details (structured prose)
        if low.startswith("interfaces:"):
            mode = "description"
            description_lines.append("")
            description_lines.append("Interfaces:")
            continue
        if any(low.startswith(k) for k in BANNER_KEYS):
            mode = None
            if content.strip():
                banner.append(content.strip())
            continue

        if content.strip() == "":
            if mode == "description":
                description_lines.append("")
            continue

        if mode == "drop":
            continue
        if mode == "note":
            if content.strip():
                notes.append(content.strip())
            continue
        if mode == "description":
            description_lines.append(content.rstrip())
        elif mode == "parameters":
            m = re.match(r'\s*(\w+)\s*:\s*(.+)', content)
            if m:
                params[m.group(1)] = m.group(2).strip()
        elif mode == "ports":
            pm = PORTDOC_RE.match(content)
            if pm:
                port_docs[pm.group(1)] = pm.group(2).strip()
            elif port_docs:
                last = list(port_docs)[-1]
                port_docs[last] += " " + content.strip()
        else:
            if content.strip():
                banner.append(content.strip())

    desc, prev_blank = [], False
    for l in description_lines:
        blank = (l.strip() == "")
        if blank and prev_blank:
            continue
        desc.append(l)
        prev_blank = blank
    while desc and desc[0].strip() == "":
        desc.pop(0)
    while desc and desc[-1].strip() == "":
        desc.pop()
    return banner, desc, params, port_docs, notes

def build_new_header(unit_kw, unit_name, desc, params_unused, port_docs, notes,
                     sym, author, project, file_name, emit_port_docs):
    B = f"//{sym}"
    out = [
        "///////////////////////////////////////////////////////////////////////////////",
        "// Fermi National Accelerator Laboratory",
        f"// {unit_kw.capitalize()} : {unit_name}",
        f"// Project: {project}",
        "///////////////////////////////////////////////////////////////////////////////",
        f"{B} @file    {file_name}",
        B,
    ]
    if desc:
        out.append(f"{B} @brief   {desc[0]}")
        if len(desc) > 1:
            out.append(B)
            out.append(f"{B} @details")
            out.append(B)
            prev_was_list = False
            for l in desc[1:]:
                s = l.strip()
                is_list = s.startswith("-") or s.startswith("*")
                if is_list and not prev_was_list:
                    out.append(B)
                out.append(B if s == "" else f"{B} {s}")
                prev_was_list = is_list
    else:
        out.append(f"{B} @brief   TODO: one-line description.")
    if emit_port_docs and port_docs:
        out.append(B)
        for name, d in port_docs.items():
            out.append(f"{B} @port {name} {d}")
    for n in notes:
        out.append(B)
        out.append(f"{B} @note    {n}")
    out.append(B)
    out.append(f"{B} @author  {author}")
    out.append(B)
    out.append(f"{B} @version 1.0")
    return [line + "\n" for line in out]

def annotate_parameters(lines, unit_start_idx, params, sym):
    if not params:
        return lines, set()
    param_decl_re = re.compile(r'^\s*parameter\b.*?\b(\w+)\s*(=|\[|,|$)')
    port_re = re.compile(r'^\s*(input|output|inout)\b')
    used, out, in_paramlist = set(), [], False
    for idx in range(unit_start_idx, len(lines)):
        line = lines[idx]
        if re.search(r'#\s*\(', line):
            in_paramlist = True
        if in_paramlist and port_re.match(line):
            in_paramlist = False
        if in_paramlist:
            m = param_decl_re.match(line)
            if m and m.group(1) in params:
                indent = re.match(r'\s*', line).group(0)
                out.append(f"{indent}//{sym} {params[m.group(1)]}\n")
                used.add(m.group(1))
        out.append(line)
    return lines[:unit_start_idx] + out, used


def process_file(path, sym, apply, author, project, stub_missing, emit_port_docs):
    text = path.read_text()
    lines = text.splitlines(keepends=True)
    m = UNIT_RE.search(text)
    if not m:
        print(f"[skip] {path}: no module/interface/package found", file=sys.stderr)
        return
    unit_kw, unit_name = m.group(1), m.group(2)
    unit_line_idx = text[:m.start()].count("\n")
    block = find_header_block(lines, unit_line_idx)

    if block is None:
        if not stub_missing:
            print(f"[skip] {path}: no header before '{unit_kw}' (use --stub-missing)",
                  file=sys.stderr)
            return
        banner, desc, params, port_docs, notes = [], [], {}, {}, []
        start = end = unit_line_idx
    else:
        start, end = block
        banner, desc, params, port_docs, notes = parse_header(lines[start:end])
        if not desc and not params and not port_docs and not banner and not notes:
            print(f"[skip] {path}: empty/unrecognized header", file=sys.stderr)
            return

    new_header = build_new_header(unit_kw, unit_name, desc, params, port_docs, notes,
                                  sym, author, project, path.name, emit_port_docs)
    new_lines = lines[:start] + new_header + lines[end:]
    new_unit_idx = start + len(new_header)
    new_lines, used = annotate_parameters(new_lines, new_unit_idx, params, sym)

    unused = set(params) - used
    if unused:
        print(f"[warn] {path}: params in header not in #( ... ): {sorted(unused)}",
              file=sys.stderr)
    if port_docs and not emit_port_docs:
        print(f"[warn] {path}: {len(port_docs)} port doc(s); rerun with --port-docs",
              file=sys.stderr)

    new_text = "".join(new_lines)
    if new_text == text:
        print(f"[nochange] {path}", file=sys.stderr)
        return
    if apply:
        backup = path.with_suffix(path.suffix + ".bak")
        backup.write_text(text)
        path.write_text(new_text)
        print(f"[applied] {path} (backup: {backup})")
    else:
        diff = difflib.unified_diff(text.splitlines(keepends=True), new_lines,
                                    fromfile=str(path), tofile=str(path) + " (proposed)")
        sys.stdout.writelines(diff)

def main():
    ap = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("files", nargs="+", help=".sv/.v files to process")
    ap.add_argument("--apply", action="store_true",
                    help="write changes in-place (creates .bak)")
    ap.add_argument("--sym", default="!", help="TerosHDL symbol (default '!')")
    ap.add_argument("--author", default="FNAL / QICK", help="@author value")
    ap.add_argument("--project", default="<project name>",
                    help="'Project:' banner value")
    ap.add_argument("--stub-missing", action="store_true",
                    help="insert a stub header for files with no header")
    ap.add_argument("--port-docs", action="store_true",
                    help="emit //! @port lines from Inputs:/Outputs: sections")
    args = ap.parse_args()
    for f in args.files:
        process_file(Path(f), args.sym, args.apply, args.author,
                     args.project, args.stub_missing, args.port_docs)


if __name__ == "__main__":
    main()