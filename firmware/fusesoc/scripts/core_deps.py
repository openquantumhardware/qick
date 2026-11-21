#!/usr/bin/env python3
"""Print the resolved dependencies of a core, in compile order (`make deps IP=<core>`).

`fusesoc core-info` stopped printing the dependencies (fusesoc 2.4.x), so this asks the core manager itself, the same
one `fusesoc run` uses: it returns every core the target pulls in, the core last.

  core_deps.py [--target default] --cores-root cores [--cores-root common ...] <core>

<core> is a VLNV (qick:ip:xcom, with or without :version) or a bare name (xcom, tpv2_alu) searched in all categories.
Exit 1 if the core is not found or the name is ambiguous.
"""
import argparse
import os
import sys

from fusesoc.config import Config
from fusesoc.coremanager import CoreManager
from fusesoc.librarymanager import Library
from fusesoc.vlnv import Vlnv


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("core", help="VLNV or bare core name")
    ap.add_argument("--cores-root", action="append", default=[], help="repeatable, as for fusesoc")
    ap.add_argument("--target", default="default", help="target whose dependencies are resolved (default: default)")
    args = ap.parse_args()

    cm = CoreManager(Config())
    for root in args.cores_root:
        if os.path.isdir(root):  # fusesoc warns about a missing root; skipping it silently is enough here
            cm.add_library(Library(root, os.path.abspath(root)), [])

    known = [str(c.name) for c in cm.get_cores().values()]
    if args.core.count(":") >= 2:
        want = args.core
    else:
        want = None
        hits = sorted({n for n in known if n.split(":")[2] == args.core})
        if len(hits) == 1:
            want = hits[0]
        else:
            print(("Ambiguous name %r, use the VLNV: " % args.core + ", ".join(hits)) if hits
                  else "Core %r not found in: %s" % (args.core, ", ".join(args.cores_root)), file=sys.stderr)
            return 1

    try:
        deps = cm.get_depends(Vlnv(want), {"is_toplevel": True, "target": args.target})
    except Exception as e:  # unknown core or unsatisfiable dependency: say which
        print("Cannot resolve %s: %s" % (want, e), file=sys.stderr)
        return 1

    print("=== Dependencies of %s (target %s, compile order) ===" % (want, args.target))
    for d in deps[:-1]:
        print("  " + str(d))
    print("  %s   <- the core" % deps[-1])
    print("%d dependencies" % (len(deps) - 1))
    return 0


if __name__ == "__main__":
    sys.exit(main())
