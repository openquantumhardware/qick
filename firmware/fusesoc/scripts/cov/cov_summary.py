"""Consolidate the per-core coverage summaries written by cov_run.py.

``make coverage`` leaves one ``report_cov/<core>/summary.json`` per core. This
walks them into a single table plus a combined JSON, which is what you want
before deciding whether to gate: a gate needs a baseline, and a per-core
percentage on its own is not one.

    python3 scripts/cov/cov_summary.py --root report_cov
    python3 scripts/cov/cov_summary.py --root report_cov --sort line_pct
    python3 scripts/cov/cov_summary.py --root report_cov --min-toggle 80 --sort toggle_pct

Backends do not produce the same metrics: xsim reports statement/branch/
condition/toggle, Verilator reports line and toggle only. A cell is left blank
when the backend did not measure it, and ``--metric`` picks which column the
gate reads so a sweep mixing backends still has one comparable number.
"""

import argparse
import json
import sys
from pathlib import Path

COLUMNS = [
    ("line_pct", "line"),
    ("toggle_pct", "toggle"),
    ("branch_pct", "branch"),
    ("condition_pct", "cond"),
    ("statements", "stmts"),
    ("files", "files"),
]

# Metrics a core can actually be gated on. line_pct is offered for both
# backends but means something slightly different under Verilator (see
# firmware/docs/developer/COVERAGE.md), which is why toggle_pct is the safer default.
GATE_METRICS = {
    "line_pct": "line",
    "toggle_pct": "toggle",
}


def load(root):
    entries = []
    for path in sorted(root.glob("*/summary.json")):
        try:
            data = json.loads(path.read_text())
        except json.JSONDecodeError:
            continue
        detail = data.get("files_detail", [])
        is_verilator = data.get("backend") == "verilator"
        entries.append(
            {
                "core": data.get("core", path.parent.name),
                "backend": data.get("backend", "xsim"),
                "line_pct": data.get("line_pct"),
                "toggle_pct": data.get("toggle_pct"),
                "branch_pct": data.get("branch_pct"),
                "condition_pct": data.get("condition_pct"),
                "statements": data.get("statements"),
                "files": data.get("files"),
                "zero_statement_files": [
                    f.get("path", "").rsplit("/", 1)[-1]
                    for f in detail
                    if f.get("stmt_total") == 0
                ],
                "report": str(
                    path.parent
                    / "html"
                    / ("annotate" if is_verilator else "codeCoverageReport")
                ),
            }
        )
    return entries


def print_table(entries, sort_key, metric):
    def key(e):
        v = e.get(sort_key)
        return v if isinstance(v, (int, float)) else -1

    entries = sorted(entries, key=key)
    head = (
        f"  {'core':<34}"
        f"{'backend':>9}"
        + "".join(f"{label:>8}" for _, label in COLUMNS)
    )
    print("")
    print(head)
    print("  " + "-" * (len(head) - 2))
    for e in entries:
        row = f"  {e['core']:<34}{e['backend']:>9}"
        for field, _ in COLUMNS:
            v = e.get(field)
            row += f"{v:>8}" if isinstance(v, (int, float)) else f"{'-':>8}"
        if e["zero_statement_files"]:
            row += "   !" + ",".join(e["zero_statement_files"])
        print(row)
    print("  " + "-" * (len(head) - 2))
    scored = [e for e in entries if isinstance(e.get(metric), (int, float))]
    if scored:
        mean = sum(e[metric] for e in scored) / len(scored)
        print(
            f"  {len(scored)} core(s) with a {GATE_METRICS.get(metric, metric)} "
            f"score; mean {mean:.2f}%"
        )
    missing = [e for e in entries if not isinstance(e.get(metric), (int, float))]
    if missing:
        print(
            f"  {len(missing)} core(s) without a {GATE_METRICS.get(metric, metric)} "
            "score (excluded from the mean, not counted as 0%)"
        )
    print("")


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--root", default="report_cov", help="report root")
    ap.add_argument(
        "--sort",
        default="line_pct",
        choices=[c[0] for c in COLUMNS],
        help="column to sort by (ascending, so the worst comes first)",
    )
    ap.add_argument(
        "--metric",
        default="toggle_pct",
        choices=sorted(GATE_METRICS),
        help="column the --min-* gate reads (default: toggle_pct, the only "
        "metric both backends measure)",
    )
    ap.add_argument("--out", default=None, help="write the combined JSON here")
    ap.add_argument(
        "--min-line",
        type=float,
        default=None,
        help="exit 1 if any core is below this line coverage",
    )
    ap.add_argument(
        "--min-toggle",
        type=float,
        default=None,
        help="exit 1 if any core is below this toggle coverage",
    )
    ap.add_argument(
        "--ignore-zero-statements",
        action="store_true",
        help="do not fail cores whose DUT reported 0 coverage points",
    )
    args = ap.parse_args(argv)

    root = Path(args.root)
    if not root.is_absolute():
        root = Path(__file__).resolve().parents[2] / root
    if not root.is_dir():
        print(f"error: no such report root: {root}", file=sys.stderr)
        return 2

    entries = load(root)
    if not entries:
        print(f"error: no */summary.json under {root}", file=sys.stderr)
        return 2

    print_table(entries, args.sort, args.metric)
    if args.out:
        out = Path(args.out)
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps(entries, indent=2))
        print(f"  combined JSON: {out}")

    gates = [("line_pct", args.min_line), ("toggle_pct", args.min_toggle)]
    below = [
        (e, metric, threshold)
        for e in entries
        for metric, threshold in gates
        if threshold is not None
        and isinstance(e.get(metric), (int, float))
        and e[metric] < threshold
    ]
    # A core that never produced the gated metric must not pass the gate by
    # being absent from it. In a mixed sweep (xsim cores run with COV=sb have
    # no toggle column) skipping them silently would let --min-toggle report
    # success while never evaluating those cores at all.
    unmeasured = [
        (e, metric, threshold)
        for e in entries
        for metric, threshold in gates
        if threshold is not None and not isinstance(e.get(metric), (int, float))
    ]
    undersized = (
        []
        if args.ignore_zero_statements
        else [e for e in entries if e["zero_statement_files"]]
    )
    for e, metric, threshold in below:
        print(
            f"COVERAGE GATE FAILED: {e['core']} {metric} {e[metric]:.2f}% "
            f"< {threshold:.2f}%",
            file=sys.stderr,
        )
    for e, metric, threshold in unmeasured:
        print(
            f"COVERAGE GATE FAILED: {e['core']} has no {metric} score "
            f"({e['backend']} backend), so the requested {threshold:.2f}% "
            f"threshold cannot be evaluated for it",
            file=sys.stderr,
        )
    for e in undersized:
        print(
            f"COVERAGE UNUSABLE: {e['core']} reported 0 coverage points for "
            f"{', '.join(e['zero_statement_files'])}",
            file=sys.stderr,
        )
    return 1 if (below or unmeasured or undersized) else 0


if __name__ == "__main__":
    sys.exit(main())