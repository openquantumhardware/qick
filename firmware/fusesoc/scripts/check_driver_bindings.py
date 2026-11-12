#!/usr/bin/env python3
"""Fail if a VLNV is bound by more than one driver class (firmware/docs/user/IP_INTEGRATION.md, rule 1), or if a packaged IP
with a register map has no driver at all (rule 4).

PYNQ keeps the LAST class it imported for a VLNV. The standalone drivers in qick_lib/qick/drivers/ are imported
after the monolithic modules, so a duplicate silently takes the IP away from the class QickSoc expects.

Scans, statically (no import, no pynq needed):
  - qick_lib/qick/drivers/*.py, with symlinks resolved and each file counted once;
  - cores/ip/*/driver/*.py regular files: standalone drivers, including ones not installed yet, so a latent
    duplicate is caught before `make driver` installs it.

Rule 4 check: every cores/ip/<ip> whose RTL (hdl/*.sv) has an AXI-Lite slave (an s_axi_awaddr port), so that
software drives it, must be bound as qick:ip:<ip>:<MAJOR.MINOR>, with the version taken from the `name:` of
cores/ip/<ip>/<ip>.core. IPs without one (readout_v3, dyn_readout_v1, the glue IPs) are skipped; the driver of whatever
consumes them handles them. An rdl/ directory is not the criterion: some register-less IPs keep a placeholder one.

Usage: check_driver_bindings.py [--list]
"""
import re
import ast
import sys
from collections import defaultdict
from pathlib import Path

FUSESOC = Path(__file__).resolve().parents[1]
REPO = FUSESOC.parents[1]

#: Packaged IPs known to have no driver yet (rule 4), with the reason. They are reported, not failed. Remove an
#: entry when its driver binds the qick:ip VLNV: the check then fails if the entry is left behind.
PENDING = {'xcom': 'in no project of firmware/Top yet; its driver comes with the xcom update'}


def bindings(path):
    """Yield (class name, vlnv) for every `bindto = [...]` in a class body."""
    tree = ast.parse(path.read_text(), filename=str(path))
    for node in ast.walk(tree):
        if not isinstance(node, ast.ClassDef):
            continue
        for stmt in node.body:
            if (isinstance(stmt, ast.Assign) and any(isinstance(t, ast.Name) and t.id == 'bindto'
                                                     for t in stmt.targets)
                    and isinstance(stmt.value, (ast.List, ast.Tuple))):
                for elt in stmt.value.elts:
                    if isinstance(elt, ast.Constant) and isinstance(elt.value, str):
                        yield node.name, elt.value


def driver_files():
    seen = set()
    for f in sorted((REPO / 'qick_lib/qick/drivers').glob('*.py')):
        if f.exists():
            real = f.resolve()
            if real not in seen:
                seen.add(real)
                yield real
    for f in sorted((FUSESOC / 'cores/ip').glob('*/driver/*.py')):
        if not f.is_symlink():
            real = f.resolve()
            if real not in seen:
                seen.add(real)
                yield real


def expected_vlnvs():
    """qick:ip:<ip>:<MAJOR.MINOR> for every packaged IP with an AXI-Lite slave."""
    for core in sorted((FUSESOC / 'cores/ip').glob('*/*.core')):
        ip = core.parent.name
        if core.stem != ip:
            continue
        hdl = [f for f in (core.parent / 'hdl').glob('*.sv') if f.exists()]
        if not any(re.search(r'\bs_axi_awaddr\b', f.read_text(errors='replace')) for f in hdl):
            continue
        m = re.search(r'^name:\s*qick:ip:(\w+):(\d+)\.(\d+)', core.read_text(), re.M)
        if m:
            yield ip, f"qick:ip:{m.group(1)}:{m.group(2)}.{m.group(3)}"


def main():
    owners = defaultdict(list)
    for f in driver_files():
        for cls, vlnv in bindings(f):
            owners[vlnv].append((cls, f.relative_to(REPO)))
    if '--list' in sys.argv:
        for vlnv in sorted(owners):
            print(vlnv, ' '.join(f"{c} ({p})" for c, p in owners[vlnv]))
    dups = {v: o for v, o in owners.items() if len(o) > 1}
    for vlnv, o in sorted(dups.items()):
        print(f"DUPLICATE {vlnv}:")
        for cls, path in o:
            print(f"    {cls:28s} {path}")
    expected = list(expected_vlnvs())
    missing = [(ip, v) for ip, v in expected if v not in owners and ip not in PENDING]
    for ip, vlnv in missing:
        print(f"UNBOUND  {vlnv}: cores/ip/{ip} has an AXI-Lite slave but no driver class binds it")
    for ip, vlnv in expected:
        if ip in PENDING and vlnv not in owners:
            print(f"pending  {vlnv}: {PENDING[ip]}")
    stale = [ip for ip, v in expected if ip in PENDING and v in owners]
    for ip in stale:
        print(f"STALE    PENDING['{ip}']: its VLNV is bound now, remove the entry")
    if dups:
        print(f"{len(dups)} VLNV(s) bound by more than one class (firmware/docs/user/IP_INTEGRATION.md, rule 1)")
    if missing:
        print(f"{len(missing)} packaged IP(s) with an AXI-Lite slave and no driver (firmware/docs/user/IP_INTEGRATION.md, rule 4)")
    if dups or missing or stale:
        return 1
    print(f"driver bindings OK: {len(owners)} VLNVs, each bound by one class; "
          f"{len(expected) - len(PENDING)} of {len(expected)} packaged IPs with an AXI-Lite slave bound, "
          f"{len(PENDING)} pending")
    return 0


if __name__ == '__main__':
    sys.exit(main())
