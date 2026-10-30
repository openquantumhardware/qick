#!/usr/bin/env python3
"""Hog list files for the RTL of a project's qick:ip IPs, so the build's version and SHA follow it.

Hog names a build (bin/<group>/<project>-v<version>-<SHA>/, versions.txt, the GLOBAL_SHA generics)
after the newest commit among the files it follows: the project's conf files, its hooks and the files
in its list/ files. The qick:ip IPs of a block design are packaged by pre-creation
(scripts/hog/package_bd_ips.tcl) from firmware/rtl_lib and firmware/fusesoc/cores, outside those
lists: a commit that only changes their RTL did not move the SHA, and checking out the SHA in a
build's name could give older RTL than the one in the bitstream.

The IPs of a project are DECLARED in Top/<group>/<project>/qick_ips.txt (one qick:ip name per
line, '#' comments): that file is the single source, for this script and for package_bd_ips.tcl.
The BD script(s) (bd_*.tcl) are only checked against it: a qick:ip the BD instantiates and the
file does not declare is an error (the packager would not build it), and so is a BD that picks a
qick:ip with `newest_ipdef` instead of writing the VLNV.

This script writes, for one project, the exact files the packager takes for each declared IP:

    Top/<group>/<project>/list/qick_ip_rtl.src   HDL, "nosynth noimpl nosim" ("nosynth nosim" for VHDL, which has no
                                                 USED_IN_IMPLEMENTATION): in the project, disabled
    Top/<group>/<project>/list/qick_ip_xdc.con   IP XDC, "nosynth noimpl": in constrs_1, disabled

Hog follows them like any listed file (in versions.txt the Verilog/SystemVerilog shows up under OTHERS,
the VHDL under QICK_IP_RTL; the global SHA follows both).
Inputs that cannot be listed are folded into an "inputs" hash in the header, so changing them also
changes the list file: the IPs' .core files, the packager itself, and the packaged non-HDL files --
Xilinx sub-IP .xci (Hog would instantiate any listed .xci in the top project) and memory images.

    gen_qick_ip_lists.py Top/216/phase_ctrl_sys_dma           # (re)write the two list files
    gen_qick_ip_lists.py --check Top/216/phase_ctrl_sys_dma   # exit 1 if they are missing or stale
    gen_qick_ip_lists.py --init  Top/216/new_project          # write qick_ips.txt from the BD (once)

pre-creation runs --check after packaging, so a build cannot start with stale lists.
Run from anywhere; paths are relative to firmware/ (Hog's repository root here).
"""
import argparse
import contextlib
import hashlib
import io
import json
import re
import sys
from pathlib import Path

FW = Path(__file__).resolve().parents[2]                     # firmware/
sys.path.insert(0, str(FW / "fusesoc" / "generators" / "ip_gen"))
import ip_packager  # noqa: E402  (collect_all_rtl_sources: what `make package` copies into ip/<ip>/src)

CORES = FW / "fusesoc" / "cores"
RTL_LIB = FW / "rtl_lib"
SRC_LIST, CON_LIST = "qick_ip_rtl.src", "qick_ip_xdc.con"
# A VHDL file has no USED_IN_IMPLEMENTATION in Vivado ("The object 'file' does not have a property",
# Common 17-54: Hog's CREATE stops), so "noimpl" is only written for Verilog/SystemVerilog.
HDL_PROPS = {".sv": "nosynth noimpl nosim", ".v": "nosynth noimpl nosim",
             ".vhd": "nosynth nosim", ".vhdl": "nosynth nosim"}
HEADERS = {".svh", ".vh"}                                     # Hog allows no props on these; harmless
# packaging inputs that cannot go in a Hog list file: hashed into the header instead
PACKAGER_FILES = ["fusesoc/generators/ip_gen/ip_packager.py",
                  "fusesoc/generators/ip_gen/package_ip.tcl.j2",
                  "scripts/hog/package_bd_ips.tcl"]


def bd_scripts(proj_dir: Path, bd_dir: Path):
    """The BD scripts proj.tcl sources: each bd_*.tcl it names, with the directory it gives
    (a variant project sources its parent's, ../<parent>/bd_<parent>.tcl), looked up from the
    project and from bd_dir; all bd_*.tcl of bd_dir if it names none."""
    text = (proj_dir / "proj.tcl").read_text()
    bds = []
    for ref in sorted(set(re.findall(r"(?:[A-Za-z0-9_.-]+/)*bd_[A-Za-z0-9_.-]+\.tcl", text))):
        parts = ref.split("/")          # "$origin_dir/bd_x.tcl" gives "origin_dir/bd_x.tcl": drop leading
        for i in range(len(parts)):     # components until the rest names a file ("../parent/bd_x.tcl")
            f = next((c for c in ((base / "/".join(parts[i:])).resolve() for base in (proj_dir, bd_dir))
                      if c.is_file()), None)
            if f is not None:
                if f not in bds:
                    bds.append(f)
                break
    return bds or sorted(bd_dir.glob("bd_*.tcl"))


def qick_bd_dir(proj_dir: Path):
    """The directory the project's pre-creation.tcl packages the BD IPs from: a variant project sets
    `set qick_bd_dir [file normalize "$qick_top_dir/<rel>"]` to its parent's; otherwise the project's own."""
    pre = proj_dir / "pre-creation.tcl"
    m = re.search(r'set\s+qick_bd_dir\s+\[file normalize\s+"\$qick_top_dir/([^"]+)"\]', pre.read_text()) if pre.exists() else None
    return (proj_dir / m.group(1)).resolve() if m else proj_dir


DECL = "qick_ips.txt"


def declared_ips(proj_dir: Path):
    """The qick:ip names the project declares in qick_ips.txt (None if the file is missing)."""
    f = proj_dir / DECL
    if not f.is_file():
        return None
    ips = {line.split("#")[0].strip() for line in f.read_text().splitlines()}
    return sorted(i for i in ips if i)


def bd_ips(bds):
    """qick:ip names the BD scripts instantiate by their literal VLNV (qick:ip:<name>:<version>)."""
    ips = set()
    for bd in bds:
        ips.update(m.split(":")[2] for m in re.findall(r"qick:ip:[a-z0-9_]+:", bd.read_text()))
    return sorted(ips)


def bd_vlnv_versions(bds):
    """{(name, version)} of the literal qick:ip VLNVs the BD scripts use."""
    return {(m[0], m[1]) for bd in bds
            for m in re.findall(r"qick:ip:([a-z0-9_]+):(\d+\.\d+)\b", bd.read_text())}


def core_version(ip):
    """major.minor the packager gives the IP (its .core's `name: qick:ip:<ip>:X.Y.Z`), None if unknown."""
    core = ip_packager.find_core_file(f"qick:ip:{ip}", CORES)
    if core is None:
        return None
    m = re.search(rf"^name:\s*qick:ip:{ip}:(\d+)\.(\d+)\.\d+", core.read_text(), re.M)
    return f"{m.group(1)}.{m.group(2)}" if m else None


def bd_picked_ips(bds):
    """qick:ip names a BD resolves with `newest_ipdef <name> qick:ip` instead of a VLNV (not allowed)."""
    ips = set()
    for bd in bds:
        ips.update(re.findall(r"newest_ipdef\s+([a-z0-9_]+)\s+qick:ip", bd.read_text()))
    return sorted(ips)


def ip_inputs(ip):
    """(source files, .core files) the packager uses for one IP, as paths relative to firmware/."""
    with contextlib.redirect_stdout(io.StringIO()):          # the packager is chatty
        groups = ip_packager.collect_all_rtl_sources(f"qick:ip:{ip}", CORES, RTL_LIB)
    srcs = {Path(p).resolve().relative_to(FW).as_posix() for g in groups for p in g}
    cores = set()
    deps = ip_packager.read_core_dependencies_recursive(f"qick:ip:{ip}", CORES) | {f"qick:ip:{ip}"}
    for dep in deps:
        core = ip_packager.find_core_file(dep, CORES)
        if core is not None:
            cores.add(core.resolve().relative_to(FW).as_posix())
    return srcs, cores


def newer_xci(srcs):
    """Packaged .xci saved by a Vivado newer than the oldest one we support.

    The .xci shared by all projects (rtl_lib/xci) are kept in the format of the oldest supported
    Vivado (2023.1): a newer Vivado upgrades them when it opens the project, but an older one cannot
    read what a newer one saved. Vivado 2024+ writes a top-level "checksum" that the 2023.1 schema
    rejects (IP_Flow 19-8166), which is what this looks for."""
    bad = []
    for rel in sorted(srcs):
        if Path(rel).suffix != ".xci":
            continue
        try:
            doc = json.loads((FW / rel).read_text())
        except ValueError:
            continue                                         # not a JSON .xci: nothing to say
        if isinstance(doc, dict) and "checksum" in doc:
            bad.append(rel)
    return bad


def render(proj_rel, ips, bds, srcs, cores):
    listed = [r for r in sorted(srcs) if Path(r).suffix in HDL_PROPS or Path(r).suffix in HEADERS
              or Path(r).suffix == ".xdc"]
    hashed = sorted(set(srcs) - set(listed))                  # .xci, .coe, .mem ...
    h = hashlib.sha256()
    for rel in sorted(cores) + PACKAGER_FILES + hashed:
        h.update(rel.encode() + b"\0" + (FW / rel).read_bytes() + b"\0")
    head = [f"# GENERATED by scripts/hog/gen_qick_ip_lists.py -- do not edit.",
            f"# Regenerate: make -C fusesoc hog-lists PROJ={proj_rel}   (pre-creation fails while stale)",
            f"# BD: {', '.join(b.name for b in bds)}",
            f"# qick:ip IPs: {' '.join(ips)}",
            f"# inputs sha256 (IP .core files, packager, files below): {h.hexdigest()[:16]}",
            *[f"#   hashed, not listed: {r}" for r in hashed],
            ""]
    src = list(head)
    con = list(head)
    for rel in listed:
        ext = Path(rel).suffix
        if ext == ".xdc":
            con.append(f"{rel} nosynth noimpl")
        elif ext in HDL_PROPS:
            src.append(f"{rel} {HDL_PROPS[ext]}")
        else:
            src.append(rel)
    return "\n".join(src) + "\n", "\n".join(con) + "\n"


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("project", help="Top/<group>/<project> (relative to firmware/) or <group>/<project>")
    ap.add_argument("--bd-dir", default=None, help="directory of the BD scripts, if not the project's")
    ap.add_argument("--check", action="store_true", help="do not write; exit 1 if the lists are stale")
    ap.add_argument("--init", action="store_true",
                    help="write qick_ips.txt from the BD's literal VLNVs (new projects; refuses to overwrite)")
    a = ap.parse_args()

    proj = Path(a.project)
    proj_dir = (proj if proj.is_absolute() else FW / (proj if proj.parts[0] == "Top" else Path("Top") / proj)).resolve()
    proj_rel = proj_dir.relative_to(FW / "Top").as_posix()
    bd_dir = Path(a.bd_dir).resolve() if a.bd_dir else qick_bd_dir(proj_dir)
    bds = bd_scripts(proj_dir, bd_dir)
    used = bd_ips(bds)
    if a.init:
        if (proj_dir / DECL).exists():
            print(f"ERROR: {proj_rel}/{DECL} exists; edit it instead", file=sys.stderr)
            return 1
        (proj_dir / DECL).write_text(
            f"# qick:ip IPs this project packages in pre-creation (scripts/hog/package_bd_ips.tcl), one per line.\n"
            f"# Checked against the BD by scripts/hog/gen_qick_ip_lists.py.\n" + "".join(f"{i}\n" for i in used))
        print(f"{proj_rel}: wrote {DECL} ({len(used)} IPs from {', '.join(b.name for b in bds)})")
        return 0
    ips = declared_ips(proj_dir)
    if ips is None:
        print(f"ERROR: {proj_rel}: {DECL} missing -- declare the qick:ip IPs the project uses, one per line "
              f"(gen_qick_ip_lists.py --init {proj_rel} writes it from the BD).", file=sys.stderr)
        return 1
    problems = []
    if bd_picked_ips(bds):
        problems.append(f"{', '.join(b.name for b in bds)} picks {', '.join(bd_picked_ips(bds))} with newest_ipdef: "
                        f"write the qick:ip:<name>:<version> VLNV (the packager's version is the commit's)")
    if sorted(set(used) - set(ips)):
        problems.append(f"the BD instantiates {', '.join(sorted(set(used) - set(ips)))}, not declared in {DECL}")
    wrong = [f"{n}:{v} (the core packages {core_version(n)})" for n, v in sorted(bd_vlnv_versions(bds))
             if core_version(n) not in (None, v)]
    if wrong:
        problems.append(f"VLNV version differs from the one the .core packages: {', '.join(wrong)}")
    if problems:
        print(f"ERROR: {proj_rel}: " + "; ".join(problems) + ".", file=sys.stderr)
        return 1
    if sorted(set(ips) - set(used)):
        print(f"warning: {proj_rel}: {DECL} declares {', '.join(sorted(set(ips) - set(used)))} that no BD "
              f"names by VLNV", file=sys.stderr)
    srcs, cores = set(), set()
    for ip in ips:
        s, c = ip_inputs(ip)
        srcs |= s
        cores |= c
    # The guard protects the projects built with Vivado 2023.1 (a bd_2023*.tcl): a project with only
    # newer BD scripts (bd_2025.2.tcl) is built with a newer Vivado, which opens any older .xci.
    bad_xci = newer_xci(srcs) if any("2023" in bd.name for bd in bds) else []
    if bad_xci:
        print(f"ERROR: {proj_rel}: {len(bad_xci)} .xci saved by a Vivado newer than 2023.1 (top-level "
              f"\"checksum\"), which 2023.1 cannot open: {', '.join(bad_xci)}. Recreate them with Vivado "
              f"2023.1 (docs/developer/PACKAGING.md).", file=sys.stderr)
        return 1
    want = dict(zip((SRC_LIST, CON_LIST), render(proj_rel, ips, bds, srcs, cores)))

    stale = [n for n, txt in want.items()
             if not (proj_dir / "list" / n).is_file() or (proj_dir / "list" / n).read_text() != txt]
    if a.check:
        if stale:
            print(f"ERROR: {proj_rel}: {', '.join('list/' + n for n in stale)} missing or stale -- the BD's "
                  f"qick:ip RTL changed. Run: make -C fusesoc hog-lists PROJ={proj_rel} and commit.",
                  file=sys.stderr)
            return 1
        print(f"{proj_rel}: qick:ip lists up to date ({len(ips)} IPs, {len(srcs)} files)")
        return 0
    for n in stale:
        (proj_dir / "list" / n).write_text(want[n])
    print(f"{proj_rel}: {len(ips)} IPs, {len(srcs)} files -> "
          f"{', '.join('list/' + n for n in stale) or 'unchanged'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
