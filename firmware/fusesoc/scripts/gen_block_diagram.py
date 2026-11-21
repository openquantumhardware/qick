#!/usr/bin/env python3
"""Generate a top-level block/schematic diagram (SVG) for an RTL module.

Elaborates the module with Verilator (real SystemVerilog support, so it
reads the actual ../rtl_lib sources directly -- the diagram can never drift
from the code) and extracts, for the top module and its direct-child
instances:

- each block's ports (name + direction), drawn on its left/right side like
  a real functional block diagram (inputs left, outputs right);
- the actual wiring between them: which output pin drives which input
  pin(s), including the top module's own boundary ports.

This is deliberately NOT a gate-level or synthesized-netlist view (that's
what TerosHDL's per-module "block diagram" gives you, and why it's too deep
for general docs) -- it stays at "one box per submodule instance" and just
adds the real port list and real wires to that box, instead of a bare
containment tree.

Two things keep the wiring itself from ballooning into a rat's nest:

- Only the top module's direct-child instances become boxes (deeper
  instances aren't expanded -- there's no --depth here, unlike a pure
  hierarchy-tree view, because full port-level wiring gets dense fast).
- Siblings of the same submodule instantiated from a `generate` loop (e.g.
  16 DDS lanes) are collapsed into one box labeled "name (xN)"; the wiring
  drawn is that of the first instance in the group, as a representative.

SystemVerilog `interface` instances (axi4_stream_if, bram_if, ...) are
dropped -- they're language-level port bundling, not a functional block.

With --ir DIR the same Verilator elaboration is written instead as
DIR/schematic-ir.json, the interactive schematic of the whole hierarchy that
the ossschem VS Code extension opens (make schematic TOP=...; needs Verilator
5.046 or newer and ossschem, both installed by make setup_environment).

A module Verilator cannot find becomes a port-only blackbox, generated at run
time: UNISIM/XPM from the Vivado install, IP cores and block-design wrappers
from the stubs Vivado wrote in the worktree (see StubFinder).

Usage:
    gen_block_diagram.py TOP_MODULE OUTPUT.svg [--rtl-lib DIR] [--stub-dir DIR]
    gen_block_diagram.py TOP_MODULE --ir DIR [--ossschem PATH]
    gen_block_diagram.py --proj GROUP/PROJECT --ir DIR [TOP_MODULE]
"""
import argparse
import glob
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from collections import defaultdict


def find_rtl_dirs(rtl_lib):
    dirs = [rtl_lib]
    for name in sorted(os.listdir(rtl_lib)):
        path = os.path.join(rtl_lib, name)
        if os.path.isdir(path):
            dirs.append(path)
    return dirs


def find_top_file(rtl_lib, top_module):
    for root, _dirs, files in os.walk(rtl_lib):
        if f"{top_module}.sv" in files:
            return os.path.join(root, f"{top_module}.sv")
    # a module in a file of another name (`verilog_lint: waive module-filename`)
    for root, _dirs, files in os.walk(rtl_lib):
        for f in sorted(files):
            if f.endswith((".sv", ".v")) and re.search(r"^\s*module\s+" + re.escape(top_module) + r"\b",
                                                      open(os.path.join(root, f), errors="replace").read(), re.M):
                return os.path.join(root, f)
    raise SystemExit(f"error: no module {top_module} found under {rtl_lib}")


INSTANCE_RE = re.compile(r"^\s*([A-Za-z_]\w*)\s+(?:#\s*\(|[A-Za-z_]\w*\s*\()", re.M)
NOT_MODULES = {"module", "input", "output", "inout", "wire", "reg", "logic", "assign", "parameter",
               "localparam", "function", "task", "always", "initial", "generate", "if", "for", "case"}


def project_sources(firmware_dir, proj, rtl_lib):
    """What a Vivado project of Top/<group>/<project> adds to the elaboration: (top, gen_dir, dirs, ip_dirs).

    top is the project's `set_property top` (post-creation.tcl over proj.tcl; d_1_wrapper when
    neither sets it). dirs are what Vivado generated for each block design: the BD wrapper (hdl/),
    the BD netlist (synth/) and the synth wrapper of every IP whose RTL is ours (it instantiates a
    module of rtl_lib), so the schematic goes from the project top through the BD into our RTL.
    The vendor IPs (and ours when the project was generated from an older version of them) stay
    blackboxes, from this project's own <ip>_stub.v or IP wrapper (Verilog or VHDL).
    """
    top_dir = os.path.join(firmware_dir, "Top", proj)
    if not os.path.isdir(top_dir):
        raise SystemExit(f"error: no project {top_dir}")
    top = None
    for tcl in ("proj.tcl", "post-creation.tcl"):  # post-creation.tcl runs last
        path = os.path.join(top_dir, tcl)
        if os.path.isfile(path):
            for m in re.finditer(r'set_property\s+top\s+"?(\w+)"?', open(path, errors="replace").read()):
                top = m.group(1)
    top = top or "d_1_wrapper"
    group, name = proj.split("/")
    gen_dir = os.path.join(firmware_dir, "Projects", group, name, f"{name}.gen", "sources_1")
    if not os.path.isdir(os.path.join(gen_dir, "bd")):
        raise SystemExit(f"error: {gen_dir}/bd not found: the Vivado project has not been created yet "
                         f"(from firmware/: ./Hog/Do CREATE {proj}, or build it once)")
    ours = set()
    for d, _subdirs, files in os.walk(rtl_lib):
        for f in files:
            if f.endswith((".sv", ".v")):
                ours.update(re.findall(r"^\s*module\s+(\w+)", open(os.path.join(d, f), errors="replace").read(), re.M))
    dirs, ip_dirs = [], []
    for bd in sorted(glob.glob(os.path.join(gen_dir, "bd", "*", ""))):
        dirs += [os.path.join(bd, sub) for sub in ("hdl", "synth") if os.path.isdir(os.path.join(bd, sub))]
        for ip_synth in sorted(glob.glob(os.path.join(bd, "ip", "*", "synth"))):
            for f in glob.glob(os.path.join(ip_synth, "*.v")) + glob.glob(os.path.join(ip_synth, "*.sv")):
                # opened only when every module the wrapper instantiates is ours: a wrapper generated
                # from an older version of the IP (another module name) stays a blackbox
                inst = set(INSTANCE_RE.findall(open(f, errors="replace").read())) - NOT_MODULES
                if inst and inst <= ours:
                    ip_dirs.append(ip_synth)
                    break
    return top, gen_dir, dirs, ip_dirs


# ---------------------------------------------------------------------------
# Blackboxes for modules Verilator cannot find
# ---------------------------------------------------------------------------
# A missing module becomes a port-only stub (no body), generated at run time
# into the work directory and never committed (the Xilinx sources are AMD's):
#   - UNISIM primitives and XPM macros from the Vivado install ($XILINX_VIVADO,
#     set by settings64.sh, or the vivado on PATH);
#   - IP cores and block-design wrappers from the <module>_stub.v / <module>.v
#     files Vivado already wrote in the git worktree (.gen/, Projects/). A BD
#     wrapper exists once per Vivado project, so the one whose ports match the
#     instance's named connections wins.

PIN_ERROR_RE = re.compile(r"%Error-PIN\w+: ([^:\s]+):\d+:\d+:")
MISSING_RE = re.compile(
    r"MODMISSING: ([^:\s]+):(\d+):\d+: Cannot find file containing module: '([^']+)'")


def vivado_root():
    if os.environ.get("XILINX_VIVADO"):
        return os.environ["XILINX_VIVADO"]
    exe = shutil.which("vivado")
    return os.path.dirname(os.path.dirname(os.path.realpath(exe))) if exe else None


def vhdl_port_stub(path, module):
    """A Verilog blackbox with the ports of a VHDL entity (Vivado writes the synth wrapper of some
    IPs, e.g. proc_sys_reset or axi_dma, in VHDL only)."""
    text = re.sub(r"--[^\n]*", " ", open(path, errors="replace").read())
    m = re.search(r"\bentity\s+" + re.escape(module) + r"\s+is\b.*?\bport\s*\((.*?)\)\s*;\s*(?:attribute\b.*?)?end\b",
                  text, re.S | re.I)
    if not m:
        return None
    ports = []
    for decl in m.group(1).split(";"):
        d = re.match(r"\s*([\w\s,]+?)\s*:\s*(in|out|inout|buffer)\s+(.*)", decl, re.S | re.I)
        if not d:
            continue
        rng = re.search(r"\(\s*(\d+)\s+(?:downto|to)\s+(\d+)\s*\)", d.group(3), re.I)
        width = f"[{rng.group(1)}:{rng.group(2)}] " if rng else ""
        direction = {"in": "input", "out": "output", "inout": "inout", "buffer": "output"}[d.group(2).lower()]
        ports += [f"  {direction} {width}{n.strip()}" for n in d.group(1).split(",") if n.strip()]
    return f"module {module} (\n" + ",\n".join(ports) + "\n);\nendmodule\n"


def port_stub(path, module):
    """The module's header and port declarations, without its body."""
    if path.endswith((".vhd", ".vhdl")):
        return vhdl_port_stub(path, module)
    text = open(path, errors="replace").read()
    text = re.sub(r"/\*.*?\*/|//[^\n]*|\(\*.*?\*\)", " ", text, flags=re.S)
    m = re.search(r"\bmodule\s+" + re.escape(module) + r"\b(.*?)\bendmodule\b", text, re.S)
    if not m:
        return None
    head, _, rest = m.group(1).partition(";")
    decls = []
    if "#" not in head:  # non-ANSI (Vivado stubs and wrappers): parameters and ports in the body
        decls = re.findall(r"^\s*(?:parameter|input|output|inout)\b[^;]*;", rest, re.M)
    return f"module {module}{head};\n" + "\n".join(d.strip() for d in decls) + "\nendmodule\n"


def instance_pins(path, line):
    """Named port connections (.pin(...)) of the instance that starts at path:line."""
    text = "".join(open(path, errors="replace").readlines()[int(line) - 1:])
    text = re.sub(r"/\*.*?\*/|//[^\n]*", " ", text, flags=re.S)
    m = re.search(r"\)\s*;", text)  # connections hold no ';', so the first ');' ends the instance
    return set(re.findall(r"\.(\w+)\s*\(", text[: m.end()] if m else text))


class StubFinder:
    def __init__(self, rtl_lib, prefer_dir=None):
        self.vivado = vivado_root()
        self.rtl_lib = rtl_lib
        self.prefer_dir = prefer_dir  # with --proj: that project's generated files win
        self._index = None

    def worktree_index(self):
        if self._index is None:
            self._index = defaultdict(list)
            try:
                root = subprocess.run(["git", "-C", self.rtl_lib, "rev-parse", "--show-toplevel"],
                                      capture_output=True, text=True, check=True).stdout.strip()
            except (subprocess.CalledProcessError, FileNotFoundError):
                root = None
            for d, subdirs, files in os.walk(root) if root else []:
                subdirs[:] = [s for s in subdirs if s not in (".git", ".venv", "node_modules")]
                for f in files:
                    if f.endswith((".v", ".sv", ".vhd")):
                        self._index[f].append(os.path.join(d, f))
        return self._index

    def source(self, module, pins):
        if self.vivado:
            unisim = os.path.join(self.vivado, "data", "verilog", "src", "unisims", f"{module}.v")
            if os.path.isfile(unisim):
                return unisim
            if module.startswith("xpm_"):
                for d, _subdirs, files in os.walk(os.path.join(self.vivado, "data", "ip", "xpm")):
                    for f in files:
                        p = os.path.join(d, f)
                        if f.endswith(".sv") and re.search(r"\bmodule\s+" + module + r"\b",
                                                           open(p, errors="replace").read()):
                            return p
        index = self.worktree_index()
        candidates = [p for name in (f"{module}_stub.v", f"{module}.v", f"{module}.sv", f"{module}.vhd")
                      for p in index.get(name, [])]
        if not candidates:
            return None

        def score(p):
            # The project's own files first (with --proj: each project configures its vendor IPs
            # differently), then every pin of the instance present, then the fewest names the
            # instance does not use (a wrapper of a bigger BD also has all the pins), then the newest.
            ports = set(re.findall(r"\b\w+\b", port_stub(p, module) or ""))
            own = bool(self.prefer_dir) and p.startswith(self.prefer_dir + os.sep)
            return (own, not pins - ports, -len(pins - ports), -len(ports - pins), os.path.getmtime(p))
        return max(candidates, key=score)


def run_verilator(top_module, top_file, rtl_dirs, stub_dir, workdir, rtl_lib, json_meta=False,
                  prefer_dir=None, ip_dirs=()):
    """Run verilator --json-only; returns (tree.json, meta.json). Missing modules get blackboxes."""
    stub_files = []
    if stub_dir and os.path.isdir(stub_dir):
        stub_files = [
            os.path.join(stub_dir, f)
            for f in sorted(os.listdir(stub_dir))
            if f.endswith(".sv")
        ]
    auto_dir = os.path.join(workdir, "blackboxes")
    os.makedirs(auto_dir, exist_ok=True)
    # Verilator writes obj_dir/V<top>.tree.json by itself, but does not create obj_dir/ for an
    # explicit --json-only-output path, so those (with the meta file ossschem needs) go in workdir.
    out_dir = workdir if json_meta else os.path.join(workdir, "obj_dir")
    tree = os.path.join(out_dir, f"V{top_module}.tree.json")
    meta = os.path.join(out_dir, f"V{top_module}.tree.meta.json")
    cmd = [
        "verilator", "--json-only", "--timing", "-Wno-fatal",
        "--top-module", top_module,
    ]
    if json_meta:  # what ossschem reads
        cmd += ["--no-json-edit-nums", "--json-only-output", tree, "--json-only-meta-output", meta]
    # ip_dirs (with --proj: the synth wrappers of our IPs) are dropped one by one when their wrapper does
    # not fit the RTL any more: a project generated from an older version of the IP (other ports).
    ip_dirs = list(ip_dirs)
    dropped = set()

    # -y finds a module only in <module>.sv/.v: a module of rtl_lib in a file of another name (the
    # `verilog_lint: waive module-filename` cases, e.g. axi_qick_time_tagger in qick_time_tagger.sv)
    # is added as its file when it turns up missing.
    declared = {}
    for d in rtl_dirs:
        for f in sorted(glob.glob(os.path.join(d, "*.sv")) + glob.glob(os.path.join(d, "*.v"))):
            for m in re.findall(r"^\s*module\s+(\w+)", open(f, errors="replace").read(), re.M):
                declared.setdefault(m, f)
    rtl_files = []

    finder, stubbed = StubFinder(rtl_lib, prefer_dir), set()
    while True:
        ydirs = [d for d in rtl_dirs + ip_dirs if d not in dropped] + [auto_dir]
        result = subprocess.run(cmd + [a for d in ydirs for a in ("-y", d, f"+incdir+{d}")] + stub_files
                                + rtl_files + [top_file], cwd=workdir, capture_output=True, text=True)
        if os.path.exists(tree):
            break
        stale = {d for f in PIN_ERROR_RE.findall(result.stderr) for d in ip_dirs
                 if d not in dropped and os.path.realpath(os.path.join(workdir, f)).startswith(os.path.realpath(d) + os.sep)}
        if stale:
            for d in sorted(stale):
                dropped.add(d)
                print(f"  {os.path.basename(os.path.dirname(d))}: generated from another version of the IP "
                      "(its ports differ from the RTL): blackbox", file=sys.stderr)
            continue
        missing = {m: (f, ln) for f, ln, m in MISSING_RE.findall(result.stderr) if m not in stubbed}
        if not missing:
            break
        for module, (where, line) in sorted(missing.items()):
            stubbed.add(module)
            if module in declared and declared[module] not in rtl_files + [top_file]:
                rtl_files.append(declared[module])
                print(f"  {module}: RTL from {declared[module]}", file=sys.stderr)
                continue
            path = finder.source(module, instance_pins(os.path.join(workdir, where), line))
            stub = port_stub(path, module) if path else None
            if stub:
                with open(os.path.join(auto_dir, f"{module}.v"), "w") as fh:
                    fh.write(stub)
                print(f"  {module}: blackbox from {path}", file=sys.stderr)
    if not os.path.exists(tree):
        sys.stderr.write(result.stdout)
        sys.stderr.write(result.stderr)
        raise SystemExit(
            f"\nerror: verilator did not produce {tree}.\n"
            "A module in the MODMISSING errors above was found neither in the Vivado install "
            "(source Vivado's settings64.sh for UNISIM/XPM) nor as a <module>_stub.v / <module>.v "
            "in the worktree (an IP or block design: build its Vivado project once), or add a "
            "blackbox stub for it under --stub-dir."
        )
    return tree, meta


# ---------------------------------------------------------------------------
# JSON AST helpers
# ---------------------------------------------------------------------------

def find_all(node, pred, out):
    if isinstance(node, dict):
        if pred(node):
            out.append(node)
        for v in node.values():
            find_all(v, pred, out)
    elif isinstance(node, list):
        for v in node:
            find_all(v, pred, out)


def collect_varrefs(node, out):
    """All signal names a pin expression actually touches (handles plain
    refs, bit-selects, concatenations, ...)."""
    find_all(node, lambda n: n.get("type") == "VARREF", out)


def sanitize(s):
    return re.sub(r"[^A-Za-z0-9_]", "_", s)


class Design:
    def __init__(self, json_path):
        data = json.load(open(json_path))
        self.by_addr = {}          # addr -> node, for every VAR/MODULE we see
        self.modules_by_name = {}  # origName -> module node (first wins)
        for m in data["modulesp"]:
            self.by_addr[m["addr"]] = m
            self.modules_by_name.setdefault(m["origName"], m)
        allvars = []
        find_all(data, lambda n: n.get("type") == "VAR", allvars)
        for v in allvars:
            self.by_addr[v["addr"]] = v

    def ports_of(self, mod_name):
        """[(name, direction)] in declaration order for a module's own I/O."""
        mod = self.modules_by_name.get(mod_name)
        if mod is None:
            return []
        vs = []
        find_all(mod.get("stmtsp"), lambda n: n.get("type") == "VAR", vs)
        return [(v["name"], v.get("direction", "NONE"))
                for v in vs if v.get("varType") == "PORT"]

    def cells_of(self, mod_name):
        mod = self.modules_by_name.get(mod_name)
        if mod is None:
            return []
        cells = []
        find_all(mod.get("stmtsp"), lambda n: n.get("type") == "CELL", cells)
        return cells

    def aliases_of(self, mod_name):
        """[(lhs, rhs)] of the module's plain `assign a = b;` (whole signals).
        Verilator up to 5.042 substituted these aliases into the pin
        expressions of --json-only; 5.052 keeps them as written, so the
        wiring has to follow them here."""
        mod = self.modules_by_name.get(mod_name)
        if mod is None:
            return []
        assigns = []
        find_all(mod.get("stmtsp"), lambda n: n.get("type") == "ASSIGNW", assigns)
        pairs = []
        for a in assigns:
            lhs, rhs = a.get("lhsp") or [], a.get("rhsp") or []
            if (len(lhs) == 1 and len(rhs) == 1
                    and lhs[0].get("type") == "VARREF" and rhs[0].get("type") == "VARREF"):
                pairs.append((lhs[0]["name"], rhs[0]["name"]))
        return pairs

    def child_module_name(self, cell):
        child = self.by_addr.get(cell.get("modp"))
        return child["origName"] if child else str(cell.get("modp"))

    def child_module_type(self, cell):
        child = self.by_addr.get(cell.get("modp"))
        return child.get("type") if child else "MODULE"

    def pin_direction(self, pin):
        var = self.by_addr.get(pin.get("modVarp"))
        return var.get("direction", "NONE") if var else "NONE"


# ---------------------------------------------------------------------------
# Diagram model: blocks with ports, and wires between specific pins
# ---------------------------------------------------------------------------

class Block:
    def __init__(self, block_id, label, inputs, outputs):
        self.id = block_id          # unique graphviz node id
        self.label = label          # display name (may include "(xN)")
        self.inputs = inputs        # [(port_name, pin_id)]
        self.outputs = outputs      # [(port_name, pin_id)]


def build_diagram(design, top_module):
    blocks = {}          # block_id -> Block
    endpoints = defaultdict(list)  # net_name -> [(block_id, pin_id, direction)]

    top_id = "TOP"
    top_ports = design.ports_of(top_module)
    top_inputs = [(n, f"{top_id}_{sanitize(n)}") for n, d in top_ports if d == "INPUT"]
    top_outputs = [(n, f"{top_id}_{sanitize(n)}") for n, d in top_ports if d == "OUTPUT"]
    blocks[top_id] = Block(top_id, top_module, top_inputs, top_outputs)
    for n, pin_id in top_inputs:
        endpoints[n].append((top_id, pin_id, "OUTPUT"))  # a top input *drives* the inside
    for n, pin_id in top_outputs:
        endpoints[n].append((top_id, pin_id, "INPUT"))   # a top output is *driven* from inside

    # Group sibling instances of the same child module together (generate
    # loops); keep the first instance of each group as the wiring example.
    cells = [c for c in design.cells_of(top_module)
             if design.child_module_type(c) != "IFACE"]
    groups = defaultdict(list)
    for c in cells:
        groups[design.child_module_name(c)].append(c)

    for child_mod_name, group in groups.items():
        n = len(group)
        rep = group[0]
        block_id = f"inst_{sanitize(rep['name'])}"
        label = child_mod_name if n == 1 else f"{child_mod_name}  (×{n})"

        pins = []
        find_all(rep.get("pinsp") or [], lambda x: x.get("type") == "PIN", pins)
        ins, outs = [], []
        for pin in pins:
            pin_name = pin["name"]
            direction = design.pin_direction(pin)
            pin_id = f"{block_id}_{sanitize(pin_name)}"
            varrefs = []
            collect_varrefs(pin.get("exprp") or [], varrefs)
            net_names = {v["name"] for v in varrefs} or {f"{block_id}_{pin_name}_unconnected"}
            if direction == "OUTPUT":
                outs.append((pin_name, pin_id))
                for net in net_names:
                    endpoints[net].append((block_id, pin_id, "OUTPUT"))
            else:  # INPUT or INOUT: treat as a load
                ins.append((pin_name, pin_id))
                for net in net_names:
                    endpoints[net].append((block_id, pin_id, "INPUT"))
        blocks[block_id] = Block(block_id, label, ins, outs)

    # A plain `assign a = b;` makes a and b one net.
    parent = {}

    def root(n):
        while parent.get(n, n) != n:
            n = parent[n]
        return n

    for lhs, rhs in design.aliases_of(top_module):
        parent[root(lhs)] = root(rhs)
    nets = defaultdict(list)
    for net, eps in endpoints.items():
        nets[root(net)].extend(eps)

    # Turn shared nets into wires: each OUTPUT endpoint drives every INPUT
    # endpoint on the same net.
    wires = []  # (from_block, from_pin, to_block, to_pin)
    for _net, eps in nets.items():
        drivers = [e for e in eps if e[2] == "OUTPUT"]
        loads = [e for e in eps if e[2] == "INPUT"]
        for d in drivers:
            for l in loads:
                if d[0] == l[0]:
                    continue
                wires.append((d[0], d[1], l[0], l[1]))

    return blocks, wires


def render_dot(blocks, wires, top_module, out_svg):
    lines = [
        "digraph block {",
        '  rankdir=LR; splines=ortho; nodesep=0.4; ranksep=0.6;',
        '  node [shape=record, fontname="Helvetica", fontsize=10];',
        '  edge [fontname="Helvetica", fontsize=8, arrowsize=0.7];',
    ]

    def port_cell(name, _pin_id):
        return f"<{_pin_id}> " + name.replace("{", "(").replace("}", ")").replace("|", "/").replace("<", "").replace(">", "")

    for b in blocks.values():
        if b.id == "TOP":
            continue
        left = " | ".join(port_cell(n, p) for n, p in b.inputs) or " "
        right = " | ".join(port_cell(n, p) for n, p in b.outputs) or " "
        label = f"{{ {{{left}}} | {b.label} | {{{right}}} }}"
        lines.append(f'  {b.id} [label="{label}"];')

    top = blocks.get("TOP")
    if top and top.inputs:
        left = " | ".join(port_cell(n, p) for n, p in top.inputs)
        lines.append(f'  TOP_in [shape=record, style=bold, label="{{ {top_module} in | {{{left}}} }}"];')
    if top and top.outputs:
        right = " | ".join(port_cell(n, p) for n, p in top.outputs)
        lines.append(f'  TOP_out [shape=record, style=bold, label="{{ {{{right}}} | {top_module} out }}"];')

    top_input_pins = {p for _n, p in (top.inputs if top else [])}

    def resolve(block_id, pin_id):
        if block_id == "TOP":
            return f"TOP_in:{pin_id}" if pin_id in top_input_pins else f"TOP_out:{pin_id}"
        return f"{block_id}:{pin_id}"

    seen = set()
    for fb, fp, tb, tp in wires:
        edge = (resolve(fb, fp), resolve(tb, tp))
        if edge in seen:
            continue
        seen.add(edge)
        lines.append(f'  {edge[0]} -> {edge[1]};')

    lines.append("}")
    dot_src = "\n".join(lines)

    result = subprocess.run(
        ["dot", "-Tsvg", "-o", out_svg],
        input=dot_src, capture_output=True, text=True,
    )
    if result.returncode != 0:
        sys.stderr.write(dot_src)
        sys.stderr.write(result.stderr)
        raise SystemExit("error: graphviz 'dot' failed")


OSSSCHEM_MIN_VERILATOR = (5, 46)  # the oldest release ossschem reads (--json-only shape)


def verilator_version():
    out = subprocess.run(["verilator", "--version"], capture_output=True, text=True).stdout
    m = re.search(r"Verilator (\d+)\.(\d+)", out)
    return (int(m.group(1)), int(m.group(2))) if m else None, out.split()[1] if out else "unknown"


def find_ossschem(given):
    for cand in (given, os.environ.get("OSSSCHEM"), shutil.which("ossschem"),
                 os.path.expanduser("~/.local/ossschem/bin/ossschem")):
        if cand and os.path.isfile(cand) and os.access(cand, os.X_OK):
            return cand
    raise SystemExit("error: ossschem not found (make install_ossschem, or --ossschem PATH)")


def write_schematic_ir(top_module, tree, meta, out_dir, ossschem):
    """ossschem dump: Verilator's --json-only output -> schematic-ir.json for the VS Code extension."""
    version, text = verilator_version()
    if version is None or version < OSSSCHEM_MIN_VERILATOR:
        raise SystemExit(f"error: ossschem needs Verilator 5.046 or newer, this is {text} "
                         "(make install_verilator)")
    os.makedirs(out_dir, exist_ok=True)
    out = os.path.join(out_dir, "schematic-ir.json")
    subprocess.run([ossschem, "dump", "--top", top_module, "--verilator-version", text,
                    "--out", out, tree, meta], check=True)
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                  formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("top_module", nargs="?",
                     help="the module to draw (with --proj: the project's top by default)")
    ap.add_argument("output_svg", nargs="?",
                     help="the static block diagram to write (omit with --ir)")
    ap.add_argument("--ir", metavar="DIR",
                     help="instead of the SVG, write DIR/schematic-ir.json: the interactive "
                          "schematic the ossschem VS Code extension opens")
    ap.add_argument("--ossschem", help="ossschem executable (default: PATH, then ~/.local/ossschem)")
    ap.add_argument("--proj", metavar="GROUP/PROJECT",
                     help="a Vivado project of Top/ (e.g. 216/xcom_async_mc3): its top, its block "
                          "designs and our IPs inside them, from what Vivado generated in Projects/")
    ap.add_argument("--rtl-lib", default="../rtl_lib",
                     help="path to rtl_lib (default: ../rtl_lib, i.e. run from firmware/fusesoc/)")
    ap.add_argument("--stub-dir", default="scripts/block_diagram_stubs",
                     help="directory of blackbox .sv stubs for vendor primitives")
    args = ap.parse_args()
    if args.proj and args.top_module and args.top_module.endswith(".svg") and not args.output_svg:
        args.top_module, args.output_svg = None, args.top_module
    if bool(args.output_svg) == bool(args.ir):
        ap.error("give either OUTPUT_SVG or --ir DIR")
    if not args.top_module and not args.proj:
        ap.error("give TOP_MODULE or --proj GROUP/PROJECT")

    rtl_lib = os.path.abspath(args.rtl_lib)
    rtl_dirs = find_rtl_dirs(rtl_lib)
    stub_dir = os.path.abspath(args.stub_dir) if args.stub_dir else None
    prefer_dir, ip_dirs = None, []
    if args.proj:
        proj_top, prefer_dir, proj_dirs, ip_dirs = project_sources(os.path.dirname(rtl_lib), args.proj, rtl_lib)
        args.top_module = args.top_module or proj_top
        rtl_dirs += proj_dirs
        print(f"{args.proj}: top {args.top_module}, {len(proj_dirs)} block-design directories, "
              f"{len(ip_dirs)} of our IPs", file=sys.stderr)
    try:
        top_file = find_top_file(rtl_lib, args.top_module)
    except SystemExit:
        found = [os.path.join(d, f"{args.top_module}{ext}") for d in rtl_dirs for ext in (".sv", ".v")
                 if os.path.isfile(os.path.join(d, f"{args.top_module}{ext}"))]
        if not found:
            raise
        top_file = found[0]

    if args.ir:
        ossschem = find_ossschem(args.ossschem)
        with tempfile.TemporaryDirectory() as workdir:
            tree, meta = run_verilator(args.top_module, top_file, rtl_dirs, stub_dir, workdir,
                                       rtl_lib, json_meta=True, prefer_dir=prefer_dir,
                                       ip_dirs=ip_dirs)
            out = write_schematic_ir(args.top_module, tree, meta, os.path.abspath(args.ir), ossschem)
        print(f"wrote {out}")
        return

    with tempfile.TemporaryDirectory() as workdir:
        json_path, _meta = run_verilator(args.top_module, top_file, rtl_dirs, stub_dir, workdir,
                                         rtl_lib, prefer_dir=prefer_dir, ip_dirs=ip_dirs)
        design = Design(json_path)
        blocks, wires = build_diagram(design, args.top_module)

    os.makedirs(os.path.dirname(os.path.abspath(args.output_svg)) or ".", exist_ok=True)
    render_dot(blocks, wires, args.top_module, args.output_svg)
    print(f"wrote {args.output_svg} ({len(blocks) - 1} blocks, {len(wires)} wires)")


if __name__ == "__main__":
    main()
