#!/usr/bin/env python3
"""
gen_docs.py — Generate Markdown documentation for SystemVerilog/Verilog modules.

Parses module header doc blocks (both //! and /** ... */ styles), parameters,
and ports (with adjacent //! comments), emitting one Markdown file per module —
mirroring the TerosHDL "Module documentation" tables (Generics + Ports).

Handles multiple modules per file. Skips interfaces/packages cleanly.

Usage:
    python3 gen_docs.py --input ../rtl_lib --outdir ../docs/rtl-md --index
    python3 gen_docs.py --input ../rtl_lib/dsp/sgv6_top.sv --outdir ../docs/rtl-md
"""
import argparse
import os
import re
import sys
import fnmatch

# Built-in defaults (always applied, even without a .docsignore).
DEFAULT_EXCLUDES = ['*_entity_declarations.sv']
# A doc comment line: //! text   or   /// text  (but NOT a banner of only '/').
RE_DOC_LINE   = re.compile(r'^\s*//[!/]\s?(?P<txt>.*)$')
# Banner / decoration line: only slashes (and maybe spaces). Not documentation.
RE_BANNER     = re.compile(r'^\s*/{2,}\s*$|^\s*/{5,}.*$')
# Module declaration.
RE_MODULE = re.compile(r'^\s*(?:module|interface|package)\s+(\w+)')
# End of a module port list.
RE_PORTLIST_END = re.compile(r'^\s*\)\s*;')

RE_PARAM = re.compile(
    r'^\s*parameter\s+'
    r'(?:(?P<ptype>int|integer|bit|logic|real|string|type)\s+)?'
    r'(?:\[[^\]]*\]\s*)?'
    r'(?P<name>\w+)\s*'
    r'=\s*(?P<value>[^,/]+?)\s*'
    r',?\s*'
    r'(?://!<?\s?(?P<desc>[^\n]*)|//[^\n]*)?\s*$'   # //! -> desc ; // -> ignored
)

RE_PORT = re.compile(
    r'^\s*(?P<dir>input|output|inout)\s+'
    r'(?:(?P<vtype>wire|reg|logic|bit)\s+)?'
    r'(?:(?P<sign>signed|unsigned)\s+)?'
    r'(?P<width>\[[^\]]*\]\s*)?'
    r'(?P<name>\w+)\s*'
    r'(?:\[[^\]]*\]\s*)?'
    r',?\s*'
    r'(?://!<?\s?(?P<desc>[^\n]*)|//[^\n]*)?\s*$'   # //! -> desc ; // -> ignored
)

def extract_port_docs(doc_lines):
    """Parse '@port <name> <desc>' and '@param <name> <desc>' from a header block.
    Returns two dicts: {port_name: desc}, {param_name: desc}.
    Used as a fallback when a port/param has no adjacent //! comment.
    """
    port_docs, param_docs = {}, {}
    for ln in doc_lines:
        m = re.match(r'^\s*@port\s+(\w+)\s+(.*)$', ln)
        if m:
            port_docs[m.group(1)] = m.group(2).strip()
            continue
        m = re.match(r'^\s*@param\s+(\w+)\s+(.*)$', ln)
        if m:
            param_docs[m.group(1)] = m.group(2).strip()
    return port_docs, param_docs

def clean_desc(d):
    if not d:
        return ""
    return d.strip().lstrip('<').strip()

def is_doc_line(line):
    """True if line is a //! or /// doc line, but not a pure banner."""
    if RE_BANNER.match(line):
        return None            # banner -> ignore
    m = RE_DOC_LINE.match(line)
    return m.group('txt') if m else False

def collect_doc_block_above(lines, module_idx):
    """
    Collect the doc block immediately above a module.
    Supports both //! / /// lines and /** ... */ blocks.
    Returns a list of text lines (comment markers stripped).
    """
    i = module_idx - 1
    # Skip blank lines AND compiler directives just above.
    while i >= 0 and (lines[i].strip() == ''
                      or lines[i].strip().startswith('`')):
        i -= 1
    if i < 0:
        return []

    # Case A: /** ... */ block ending just above the module.
    if '*/' in lines[i]:
        block = []
        # Walk upward until the /** opener.
        j = i
        buf = []
        while j >= 0:
            buf.append(lines[j])
            if '/**' in lines[j] or '/*!' in lines[j]:
                break
            j -= 1
        buf.reverse()
        for ln in buf:
            t = ln
            t = re.sub(r'/\*\*?!?', '', t)   # strip /** /*! openers
            t = re.sub(r'\*/', '', t)         # strip */ closer
            t = re.sub(r'^\s*\*\s?', '', t)   # strip leading * on each line
            block.append(t.rstrip())
        # drop leading/trailing empties
        while block and block[0].strip() == '':
            block.pop(0)
        while block and block[-1].strip() == '':
            block.pop()
        return block

    # Case B: contiguous //! or /// lines (ignoring banners).
    block = []
    k = i
    while k >= 0:
        res = is_doc_line(lines[k])
        if res is None:            # banner -> stop the block here
            break
        if res is False:           # not a doc line -> stop
            break
        block.append(res)
        k -= 1
    block.reverse()
    return block

def extract_tag(doc_lines, tag):
    out, capturing = [], False
    for ln in doc_lines:
        m = re.match(r'^\s*@(\w+)\s*(.*)$', ln)
        if m:
            capturing = (m.group(1) == tag)
            if capturing and m.group(2).strip():
                out.append(m.group(2).strip())
        elif capturing:
            if ln.strip():
                out.append(ln.strip())
            else:
                capturing = False
    return ' '.join(out) if out else None

def first_prose_line(doc_lines):
    """First non-empty, non-@tag, non-banner line -> used as brief fallback."""
    for ln in doc_lines:
        s = ln.strip()
        if not s or s.startswith('@') or RE_BANNER.match(ln) or set(s) <= set('/*-= '):
            continue
        return s
    return None

def parse_ports_params(lines, module_idx):
    params, ports = [], []
    in_params = False
    i = module_idx
    while i < len(lines):
        ln = lines[i]
        if '#(' in ln:
            in_params = True
        if in_params and 'parameter' in ln:
            pm = RE_PARAM.match(ln)
            if pm:
                params.append((
                    pm.group('name'),
                    (pm.group('ptype') or '').strip(),
                    pm.group('value').strip(),
                    clean_desc(pm.group('desc')),
                ))
        if in_params and re.search(r'\)\s*\(', ln):
            in_params = False
        po = RE_PORT.match(ln)
        if po and not in_params:
            pnames = {p[0] for p in params}
            if po.group('name') not in pnames:
                ports.append((
                    po.group('name'),
                    po.group('dir'),
                    (po.group('width') or '').strip(),
                    clean_desc(po.group('desc')),
                ))
        if RE_PORTLIST_END.match(ln) and i > module_idx:
            break
        i += 1
    return params, ports

def parse_file(path):
    """Return a list of module dicts (a file may hold several modules)."""
    with open(path, 'r', errors='replace') as f:
        lines = f.read().splitlines()

    mods = []
    for idx, ln in enumerate(lines):
        m = RE_MODULE.match(ln)
        if not m:
            continue
        name = m.group(1)

        # Header doc block (supports //! and /** ... */).
        header = collect_doc_block_above(lines, idx)

        # Tag-based description fields.
        brief   = extract_tag(header, 'brief') or first_prose_line(header)
        details = extract_tag(header, 'details') or extract_tag(header, 'description')
        author  = extract_tag(header, 'author')
        version = extract_tag(header, 'version')
        note    = extract_tag(header, 'note')

        # Legacy @port / @param descriptions (fallback for old-style headers).
        port_docs, param_docs = extract_port_docs(header)
        if name == 'ctrl_sgv4':
            print(f"PORT_DOCS = {port_docs}", file=sys.stderr)
            print(f"PARAM_DOCS = {param_docs}", file=sys.stderr)

        # Parse the module's parameters and ports from the declaration.
        params, ports = parse_ports_params(lines, idx)

        # Apply @param / @port fallbacks where adjacent //! was empty.
        params = [(n, t, v, d or param_docs.get(n, "")) for (n, t, v, d) in params]
        ports  = [(n, dr, w, d or port_docs.get(n, "")) for (n, dr, w, d) in ports]

        mods.append({
            'name': name, 'file': os.path.basename(path), 'path': path,
            'brief': brief, 'details': details, 'author': author,
            'version': version, 'note': note,
            'params': params, 'ports': ports,
        })
    return mods

def to_markdown(mod):
    L = [f"# {mod['name']}\n"]
    if mod['brief']:
        L.append(f"**{mod['brief']}**\n")

    # Source line (clickable link when available).
    src  = mod.get('src_rel') or mod['file']
    link = mod.get('src_link')
    if link:
        L.append(f"*Source: [`{src}`]({link})*\n")
    else:
        L.append(f"*Source: `{src}`*\n")

    if mod['details']:
        L.append("## Description\n")
        L.append(mod['details'] + "\n")
    if mod['note']:
        L.append(f"> **Note:** {mod['note']}\n")
    if mod['params']:
        L.append("## Generics\n")
        L.append("| Generic | Type | Value | Description |")
        L.append("|---------|------|-------|-------------|")
        for n, t, v, d in mod['params']:
            L.append(f"| {n} | {t} | {v} | {d} |")
        L.append("")
    if mod['ports']:
        L.append("## Ports\n")
        L.append("| Port | Direction | Type | Description |")
        L.append("|------|-----------|------|-------------|")
        for n, dirn, w, d in mod['ports']:
            L.append(f"| {n} | {dirn} | {w} | {d} |")
        L.append("")
    if mod['author'] or mod['version']:
        L.append("---")
        meta = []
        if mod['author']:
            meta.append(f"**Author:** {mod['author']}")
        if mod['version']:
            meta.append(f"**Version:** {mod['version']}")
        L.append(' · '.join(meta))
    return '\n'.join(L) + '\n'

def load_docsignore(input_path):
    """Look for a .docsignore next to (or inside) the input root."""
    patterns = []
    # If input is a dir, look inside it; if a file, look in its dir.
    root = input_path if os.path.isdir(input_path) else os.path.dirname(input_path)
    candidate = os.path.join(root, '.docsignore')
    if os.path.isfile(candidate):
        with open(candidate) as f:
            for line in f:
                s = line.strip()
                if s and not s.startswith('#'):
                    patterns.append(s)
        print(f"  (loaded {len(patterns)} pattern(s) from {candidate})")
    return patterns

def collect_files(inp, excludes):
    out = []
    for root, _, files in os.walk(inp):
        for fn in files:
            if not fn.endswith(('.sv', '.v')):
                continue
            if any(fnmatch.fnmatch(fn, pat) for pat in excludes):
                continue
            out.append(os.path.join(root, fn))
    return sorted(out)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--input', required=True)
    ap.add_argument('--outdir', required=True)
    ap.add_argument('--index', action='store_true')
    ap.add_argument('--exclude', action='append', default=[],
                    help='Extra glob pattern to exclude (repeatable).')
    ap.add_argument('--no-docsignore', action='store_true',
                    help='Ignore any .docsignore file.')
    args = ap.parse_args()

    os.makedirs(args.outdir, exist_ok=True)

    excludes = list(DEFAULT_EXCLUDES) + list(args.exclude)
    if not args.no_docsignore:
        excludes += load_docsignore(args.input)

    files = collect_files(args.input, excludes)
    # Anchor 'base' at the rtl_lib root so single-file output mirrors the
    # full-tree layout (avoids writing to docs/rtl-md/<file>.md vs .../dsp/<file>.md).
    if os.path.isdir(args.input):
        base = args.input
    else:
        base = os.path.dirname(args.input)
        parts = os.path.abspath(args.input).split(os.sep)
        if 'rtl_lib' in parts:
            ridx = len(parts) - 1 - parts[::-1].index('rtl_lib')
            base = os.sep.join(parts[:ridx + 1])

    documented, skipped = [], []
    for path in files:
        try:
            mods = parse_file(path)
        except Exception as e:
            print(f"  [err]  {path}: {e}", file=sys.stderr)
            skipped.append((path, 'parse error'))
            continue
        if not mods:
            skipped.append((path, 'no module (interface/package)'))
            continue
        rel = os.path.relpath(path, base)
        for mod in mods:
            stem = os.path.splitext(rel)[0]
            out_rel = (f"{stem}.md" if len(mods) == 1
                       else f"{stem}__{mod['name']}.md")
            out_path = os.path.join(args.outdir, out_rel)
            os.makedirs(os.path.dirname(out_path), exist_ok=True)
            # link from the .md back to the source .sv, relative to the .md file
            src_link = os.path.relpath(path, os.path.dirname(out_path))
            mod['src_link'] = src_link
            mod['src_rel']  = rel          # e.g. math/alu.sv
            with open(out_path, 'w') as f:
                f.write(to_markdown(mod))
            documented.append((mod['name'], out_rel, mod['brief'] or '',
                               len(mod['ports'])))

    if args.index:
        # Sort: undocumented (no brief) and no-ports flagged for easy triage.
        idx = ["# RTL Library — Module Index\n",
               f"_{len(documented)} modules documented, {len(skipped)} files skipped._\n",
               "| Module | Doc | Ports | Brief |",
               "|--------|-----|-------|-------|"]
        for name, rel, brief, nports in sorted(documented):
            flag = "" if nports else " ⚠️"
            idx.append(f"| {name} | [{rel}]({rel}) | {nports}{flag} | {brief} |")
        idx.append("\n## Skipped files\n")
        for p, why in sorted(skipped):
            idx.append(f"- `{p}` — {why}")
        with open(os.path.join(args.outdir, 'README.md'), 'w') as f:
            f.write('\n'.join(idx) + '\n')

    print(f"✓ Documented {len(documented)} modules -> {args.outdir}")
    if skipped:
        print(f"  ({len(skipped)} files skipped)")

if __name__ == '__main__':
    main()
