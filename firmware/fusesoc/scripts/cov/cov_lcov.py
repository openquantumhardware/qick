"""Parse Verilator's lcov-style coverage into per-file DUT numbers.

``verilator_coverage --write-info`` emits the standard lcov record set, which is
far easier to consume than the raw ``coverage.dat``:

    SF:<file>          source file the following records belong to
    DA:<line>,<count>  a coverage point on that line (count > 0 means reached)
    BRDA:<line>,<blk>,<br>,<count>   a branch or toggle point
    BRF:<n>            branch/toggle points found in the file
    BRH:<n>            branch/toggle points hit at least once
    LF/LH              line found/hit (only emitted with --coverage-line)

Which meaning ``BRDA`` carries depends on how Verilator was invoked: under
``--coverage-toggle`` the points are per-bit transitions (0->1 and 1->0 of
every toggleable bit), under ``--coverage-line`` they are if/else arms. This
module only ever sees the toggle form -- cov_run.py refuses ``--verilator-cov=l``
-- so ``to_entries`` reports every BRDA point as a toggle bit.

Verilator has no notion of xsim's "statements" or "conditions": every coverage
point it records is a line, so ``stmt_total`` mirrors ``lines_total``. There is
also no separate testbench/DUT weighting -- the DUT filter in cov_run.py does
that, by excluding testbench, clock generator and vendor files.
"""

import re

# Files that are part of the simulation harness rather than the design under
# test. A testbench usually outweighs the DUT it exercises by a wide margin, so
# leaving them in makes the total measure the bench instead of the RTL.
INFRA_PATTERNS = [
    r"/tests/",
    r"/generated/",
    r"/lib/",
    r"svunit",
    r"clk_gen",
    r"glbl",
    r"testrunner",
    r"unisim",
    r"xpm_",
]

# Verilator reports paths relative to the build directory, where every core's
# sources are unpacked under src/<escaped_vlnv>/<fileset>/.
DUT_CORE_DIR_RE = re.compile(r"(?:^|/)src/(?P<core>qick_[^/]+)/(?P<sub>hdl|rtl|src)/")


def is_dut(path):
    return bool(DUT_CORE_DIR_RE.search(path)) and not any(
        re.search(p, path) for p in INFRA_PATTERNS
    )


def parse_lcov(text):
    """Yield ``{path, line_found, line_hit, br_found, br_hit, da_total, da_hit}``.

    ``BRF``/``BRH`` are trusted when present because they are the authoritative
    totals; when absent they are derived from the individual ``BRDA`` records,
    which is what happens for a file whose branch points all live on one line.
    """
    out = []
    cur = None
    for raw in text.splitlines():
        line = raw.strip()
        if line.startswith("SF:"):
            cur = {
                "path": line[3:].strip(),
                "da_total": 0,
                "da_hit": 0,
                "brda_total": 0,
                "brda_hit": 0,
                "br_found": None,
                "br_hit": None,
            }
            continue
        if cur is None:
            continue
        if line.startswith("DA:"):
            _, count = line[3:].split(",")[:2]
            cur["da_total"] += 1
            if int(count) > 0:
                cur["da_hit"] += 1
        elif line.startswith("BRDA:"):
            parts = line[5:].split(",")
            if len(parts) >= 4:
                # A trailing '-' means the point was found but never executed:
                # it belongs in the denominator only. Dropping it from both
                # sides would shrink the denominator and over-report coverage.
                cur["brda_total"] += 1
                if parts[3] != "-" and int(parts[3]) > 0:
                    cur["brda_hit"] += 1
        elif line.startswith("BRF:"):
            cur["br_found"] = int(line[4:])
        elif line.startswith("BRH:"):
            cur["br_hit"] = int(line[4:])
        elif line == "end_of_record":
            out.append(cur)
            cur = None
    if cur is not None:
        out.append(cur)
    return out


def to_entries(records, exclude=None, keep_all=False):
    """Filter ``records`` down to DUT files and shape them like the xsim entries.

    Keeping the same field names as the xsim backend means cov_summary.py and
    the gate logic do not need to know which simulator produced a report.

    lcov's BRDA/BRF are toggle points here, never branches: this backend only
    ever builds with ``--coverage-toggle`` (see the ``--verilator-cov=l``
    rejection in cov_run.py), so a BRDA line always means a toggle bit.
    """
    user_exclude = re.compile(exclude) if exclude else None
    entries = []
    for rec in records:
        path = rec["path"]
        if user_exclude and user_exclude.search(path):
            continue
        dut = is_dut(path)
        if not keep_all and not dut:
            continue

        total = rec["da_total"]
        entry = {
            "path": path,
            "dut": dut,
            "lines_total": total,
            "stmt_total": total,
            "stmt_pct": round(100.0 * rec["da_hit"] / total, 2) if total else 0.0,
            # No xsim "condition" metric exists here; recorded explicitly so a
            # report never shows a blank cell that reads like a missed check.
            "condition_pct": None,
        }
        found = rec["br_found"] if rec["br_found"] is not None else rec["brda_total"]
        hit = rec["br_hit"] if rec["br_hit"] is not None else rec["brda_hit"]
        if found:
            entry["toggle_pct"] = round(100.0 * hit / found, 2)
            entry["toggle_total"] = found
        entries.append(entry)
    return entries