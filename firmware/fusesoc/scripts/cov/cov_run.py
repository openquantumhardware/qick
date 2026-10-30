"""Code-coverage driver for the FuseSoC test flow, on Verilator or xsim.

Two backends, one report format.

Verilator (default)
    Verifies SVUnit suites natively: ``fusesoc run --target test --tool
    verilator --setup`` elaborates the whole SVUnit testrunner and
    ``make binary`` links a self-contained executable that prints the same
    ``[testrunner]: PASSED`` marker xsim does. Runtime is milliseconds and the
    only coverage flag that survives codegen is ``--coverage-toggle``; see
    ``firmware/docs/developer/COVERAGE.md`` for why ``--coverage-line`` is not offered.

    The practical win over xsim is instrumentation reach: toggle coverage
    reaches purely combinational RTL (``assign``-only modules such as
    ``vec2bit.sv`` or ``bin2gray.sv``) that xsim reports as 0 statements.

xsim
    Kept for statement coverage, which Verilator's toggle mode does not
    reproduce on all lines. xsim instruments at elaboration time, so coverage
    cannot be bolted onto an existing ``fusesoc run``: ``xelab`` has to be
    re-invoked with ``--cc_type``. Reports come from ``xcrg``, the code
    coverage generator shipped with Vivado (there is no ``xsimcov`` in
    Vivado 2025.2).

Both backends avoid editing the 186 ``.core`` files. FuseSoC does not merge
``tools:`` sections across cores (``fusesoc/capi2/core.py::get_tool_options``
reads only the target's own section) and edalize reads its options straight out
of ``config.mk``, so each driver exports the design with ``--setup`` and then
calls the generated Makefile with the relevant variable overridden on the
command line. Make command-line variables beat the ``include config.mk``
assignment, which is what makes the zero-.core-edit approach work.
"""

import argparse
import html
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from cov_lcov import (  # noqa: E402
    DUT_CORE_DIR_RE,
    INFRA_PATTERNS,
    parse_lcov,
    to_entries,
)

CORES_ROOTS = ["cores", "projects", "common", "generators"]
TEST_TARGET = "test"
XSIM_SUFFIX = "test-xsim"
VERILATOR_SUFFIX = "test-verilator"
CODE_COV_DB_DIRNAME = "xsim.codeCov"
PASS_MARKER = "[testrunner]: PASSED"

# Verilator flags every coverage run needs. --timing is required because
# SVUnit's runner uses #delay, fork and disable fork; -Wno-fatal because the
# SVUnit sources and the testbenches trip width/lint warnings that would
# otherwise abort elaboration before the run starts.
#
# --build-jobs matters more than it looks: --binary generates ~70 C++
# translation units for a typical core and compiles them one at a time without
# it, so a sweep of ~186 cores leaves the host's other cores idle for the whole
# run. Verilator takes the job count as a separate argument ("-j N"), not as
# "--build-jobs=N"; the latter is rejected as an invalid option.
# Overridable for constrained build hosts.
VERILATOR_BASE_FLAGS = [
    "--timing",
    "-Wno-fatal",
    "-j",
    os.environ.get("COV_BUILD_JOBS") or str(os.cpu_count() or 1),
]

# --coverage-line is deliberately absent. Verilator 5.042 miscompiles an
# SVUnit testcase under it: emitting __ctor_var_reset for the class resolves
# svunit_testcase::new()'s `name` formal argument as a data member, so the
# generated C++ reads "no match for call to (std::string) ()". Toggle
# coverage codegens cleanly and is the metric that matters for finding dead
# RTL, so it is the one we gate on. See firmware/docs/developer/COVERAGE.md.


class CoverageError(RuntimeError):
    pass


def run(cmd, cwd, log=None, timeout=None):
    try:
        proc = subprocess.run(
            cmd,
            cwd=cwd,
            shell=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=timeout,
        )
    except subprocess.TimeoutExpired as exc:
        if log is not None:
            log.write_text((exc.output or b"").decode(errors="replace"))
        raise CoverageError(
            f"command exceeded {timeout}s and was killed: {cmd}\n"
            f"partial output in {log}"
        )
    out = proc.stdout.decode(errors="replace")
    if log is not None:
        log.write_text(out)
    if proc.returncode != 0:
        tail = "\n".join(out.splitlines()[-40:])
        raise CoverageError(f"command failed ({proc.returncode}): {cmd}\n{tail}")
    return out


BACKEND_SUFFIX = {"xsim": XSIM_SUFFIX, "verilator": VERILATOR_SUFFIX}
BACKEND_TOOL = {"xsim": "xsim", "verilator": "verilator"}


# The Verilator the repository pins (VERILATOR_VERSION in the Makefile, validated
# when it was pinned) -- anything older is reported as unsupported instead of being
# allowed to fail later with an unrelated-looking error. 5.020 cannot parse SVUnit's
# sources (svunit_filter.svh:154); 5.042 was the previous pin; 5.046 to 5.052 need
# the SVUnit of build_fusesocenv.sh (lharnaldi/svunit), which works around their
# toggle-coverage and scheduling bugs. SVUnit is cloned from master unpinned, so
# this floor can need revisiting if SVUnit starts using newer SystemVerilog.
MIN_VERILATOR = (5, 52)
MIN_VERILATOR_TEXT = "5.052"  # zero-padded as Verilator prints it


def parse_verilator_version(exe):
    """Return ((major, minor), raw) from ``verilator --version``, or None.

    Handles both "Verilator 5.042 2025-11-02 rev v5.042" and the distro build
    "Verilator 5.020 2024-01-01 rev (Debian 5.020-1)".

    The raw string is returned alongside because Verilator zero-pads the minor
    to three digits, so int("042") == 42 would print as "5.42" and name a
    version that does not exist. Only the tuple is for comparison.
    """
    try:
        out = subprocess.run(
            [exe, "--version"], capture_output=True, timeout=30
        ).stdout.decode(errors="replace")
    except (OSError, subprocess.SubprocessError):
        return None
    parts = out.split()
    if len(parts) < 2 or "erilator" not in parts[0]:
        return None
    raw = parts[1]
    bits = raw.split(".")
    if len(bits) < 2 or not all(b.isdigit() for b in bits[:2]):
        return None
    return (int(bits[0]), int(bits[1])), raw


def check_tool(backend):
    """Fail early and legibly when the simulator is missing or too old.

    Without this the failure surfaces from the generated Makefile as
    ``verilator: No such file or directory``, or -- worse -- as a syntax error
    inside SVUnit's own sources when the installed Verilator is too old to parse
    them. Neither reads like the real problem. edalize's Makefile resolves
    ``VERILATOR ?= verilator`` unless VERILATOR_ROOT is set, so PATH is the whole
    contract.

    Runs before any fusesoc setup work, so a missing tool costs nothing.
    """
    tool = BACKEND_TOOL[backend]
    root = os.environ.get("VERILATOR_ROOT") if backend == "verilator" else None
    if backend == "verilator" and root:
        candidate = Path(root) / "bin" / tool
        if not (candidate.is_file() and os.access(candidate, os.X_OK)):
            raise CoverageError(
                f"VERILATOR_ROOT={root} is set but {candidate} is not an "
                f"executable file. Unset VERILATOR_ROOT, or point it at a "
                f"Verilator install."
            )
        exe = str(candidate)
    else:
        exe = shutil.which(tool)
        if not exe and backend == "verilator":
            # the user-level install made by `make install_verilator`
            fallback = Path.home() / ".local" / "verilator" / "bin" / tool
            if fallback.is_file() and os.access(fallback, os.X_OK):
                exe = str(fallback)
                # edalize's generated Makefile resolves plain `verilator` from PATH
                os.environ["PATH"] = f"{fallback.parent}{os.pathsep}{os.environ.get('PATH', '')}"
        if not exe:
            if backend == "xsim":
                raise CoverageError(
                    "xsim is not on PATH. It ships with Vivado, so source the "
                    "Vivado settings64.sh (or add its bin/ to PATH) before "
                    "running coverage, or use the Verilator backend: "
                    "make coverage IP=<core>"
                )
            raise CoverageError(
                "verilator is not on PATH, so the Verilator backend cannot "
                "run.\nInstall Verilator, or point VERILATOR_ROOT at an "
                "existing install, or use the xsim backend instead:\n"
                "    make coverage IP=<core> COV_BACKEND=xsim COV=sb\n"
                "Note Vivado does not bundle Verilator, so a working "
                "'which vivado' does not imply Verilator is available."
            )

    if backend != "verilator":
        return
    parsed = parse_verilator_version(exe)
    if parsed is None:
        # An unparseable version is not worth refusing on; the build itself
        # will fail loudly if it is genuinely unusable.
        return
    version, got = parsed
    if version < MIN_VERILATOR:
        want = MIN_VERILATOR_TEXT
        raise CoverageError(
            f"Verilator {got} at {exe} is older than the {want} this flow is "
            f"validated against.\n"
            f"Older Verilators cannot parse SVUnit's sources and fail with a "
            f"syntax error inside svunit_base, which reads like a problem with "
            f"your design rather than with Verilator.\n"
            f"  upgrade Verilator to {want} or newer, or\n"
            f"  use the xsim backend: "
            f"make coverage IP=<core> COV_BACKEND=xsim COV=sb"
        )


def resolve_vlnv(fusesoc_root, given):
    """Expand a user-supplied core name into a full VLNV.

    ``make coverage IP=axis_constant`` is the natural thing to type, and the
    documented examples use it. But the build directory is named after the
    *escaped VLNV* (qick:ip:axis_constant -> qick_ip_axis_constant), so deriving
    the build-dir pattern from the raw string finds nothing and the run dies with
    a misleading "no build dir matches 'axis_constant'".

    Accepted forms, in precedence order:
      qick:ip:axis_constant:1.0.0   exact VLNV with version
      qick:ip:axis_constant         VLNV without version
      qick:ip:axis                  any version of that VLNV, if unique
      axis_constant                 the core name, if unique across the tree

    Ambiguity is an error with the candidates listed, never a silent pick.
    """
    cmd = f"fusesoc {' '.join(f'--cores-root {r}' for r in CORES_ROOTS)} list-cores"
    try:
        out = subprocess.run(
            cmd.split(), cwd=fusesoc_root, capture_output=True, timeout=300
        ).stdout.decode(errors="replace")
    except (OSError, subprocess.SubprocessError):
        return given  # cannot check; let fusesoc itself produce the real error

    # list-cores prints "VLNV : sync-type : library : description", so the VLNV
    # is only the first whitespace-delimited token of the line.
    cores = sorted(
        {
            ln.split()[0]
            for ln in out.splitlines()
            if ln.split() and ln.split()[0].count(":") >= 2
        }
    )
    if not cores:
        return given
    if given in cores:
        return given

    without_version = [c for c in cores if c.rsplit(":", 1)[0] == given]
    if len(without_version) == 1:
        return without_version[0]
    if len(without_version) > 1:
        matches = without_version
    else:
        matches = []
        for c in cores:
            fields = c.split(":")
            # Guard the index: fusesoc's list-cores can emit lines with fewer
            # fields than the canonical four, and a short name still has to
            # match them rather than raise.
            if fields[-1] == given or (len(fields) > 2 and fields[2] == given):
                matches.append(c)
    if len(matches) == 1:
        return matches[0]
    if not matches:
        return given  # let fusesoc report the unknown core properly
    raise CoverageError(
        f"'{given}' is ambiguous; it matches {len(matches)} cores. Use the full "
        f"VLNV:\n"
        + "".join(f"    {c}\n" for c in matches)
    )


def match_build_dirs(fusesoc_root, vlnv, backend):
    """Build dirs belonging to exactly ``vlnv``.

    edalize escapes a VLNV into a directory name by replacing ':' with '_' and
    appending the version: qick:ip:axis_constant:1.0.0 becomes
    qick_ip_axis_constant_1.0.0.

    A plain startswith() on the first three fields is NOT enough. The escape has
    no delimiter before the version, so the prefix for qick:ip:axis_constant
    also matches qick_ip_axis_constant_iq_1.0.0 -- and the newest one by mtime
    would silently win, reporting one core's testbench and RTL under another
    core's name. Match the exact escaped VLNV instead, with the version as the
    only optional suffix.
    """
    suffix = BACKEND_SUFFIX[backend]
    escaped = vlnv.replace(":", "_")
    pattern = re.compile(rf"^{re.escape(escaped)}(_\d[^_]*)?$")
    return [
        d
        for d in (fusesoc_root / "build").glob(f"*/{suffix}")
        if (d / "config.mk").is_file() and pattern.match(d.parent.name)
    ]


def resolve_build_dir(fusesoc_root, vlnv, extra_args, backend):
    suffix = BACKEND_SUFFIX[backend]
    before = {p for p in (fusesoc_root / "build").glob(f"*/{suffix}")}
    cmd = (
        f"fusesoc {' '.join(f'--cores-root {r}' for r in CORES_ROOTS)} "
        f"run --target {TEST_TARGET} --setup --tool {BACKEND_TOOL[backend]} "
        f"{vlnv} {extra_args}"
    ).strip()
    run(cmd, cwd=fusesoc_root, log=fusesoc_root / "cov_setup.log")
    candidates = match_build_dirs(fusesoc_root, vlnv, backend)
    if not candidates:
        after = {p for p in (fusesoc_root / "build").glob(f"*/{suffix}")}
        candidates = [
            d
            for d in (after - before)
            if (d / "config.mk").is_file() and vlnv.replace(":", "_") in d.parent.name
        ]
    if not candidates:
        raise CoverageError(
            f"no build dir under build/ matches '{vlnv}' after --setup; "
            f"is it a valid core with a '{TEST_TARGET}' target?"
        )
    return max(candidates, key=lambda d: (d / "config.mk").stat().st_mtime)


def xsim_timescale(fusesoc_root, vlnv):
    """The -timescale the core's test target gives xelab, or None.

    The Verilator run must use the time units of the official xsim run. Without
    them a source with no `timescale gets Verilator's default instead, delays
    such as qtt_cmd's 1.5 ns routing skew are rounded, and whether the test
    passes depends on the Verilator release. Verilator's
    --timescale, like xelab's -timescale, is only the default for files without
    a `timescale directive.
    """
    import yaml  # fusesoc depends on PyYAML, so the venv has it

    cmd = f"fusesoc {' '.join(f'--cores-root {r}' for r in CORES_ROOTS)} core-info {vlnv}"
    try:
        out = subprocess.run(
            cmd.split(), cwd=fusesoc_root, capture_output=True, timeout=300
        ).stdout.decode(errors="replace")
    except (OSError, subprocess.SubprocessError):
        return None
    info = dict(
        (k.strip(), v.strip())
        for k, v in (ln.split(":", 1) for ln in out.splitlines() if ":" in ln)
    )
    if "Core root" not in info or "Core file" not in info:
        return None
    core_file = fusesoc_root / info["Core root"] / info["Core file"]
    try:
        core = yaml.safe_load(core_file.read_text())
        xelab = core["targets"][TEST_TARGET]["tools"]["xsim"]["xelab_options"]
    except (OSError, yaml.YAMLError, KeyError, TypeError):
        return None
    m = re.search(r"-timescale[= ](\S+)", " ".join(map(str, xelab)))
    return m.group(1) if m else None


def read_makefile_opts(build_dir):
    opts = {}
    config = build_dir / "config.mk"
    if not config.is_file():
        raise CoverageError(f"missing {config}")
    for line in config.read_text().splitlines():
        m = re.match(r"^(XELAB_OPTIONS|XSIM_OPTIONS)\s*=\s*(.*)$", line)
        if m:
            opts[m.group(1)] = m.group(2).strip()
    for key in ("XELAB_OPTIONS", "XSIM_OPTIONS"):
        opts.setdefault(key, "")
    return opts["XELAB_OPTIONS"], opts["XSIM_OPTIONS"]


def read_top_module(build_dir):
    config = build_dir / "config.mk"
    if not config.is_file():
        raise CoverageError(f"missing {config}")
    for line in config.read_text().splitlines():
        m = re.match(r"^TOP_MODULE\s*:?=\s*(\S+)", line.strip())
        if m:
            return m.group(1)
    raise CoverageError(f"could not read TOP_MODULE from {config}")


def simulate_verilator(build_dir, cov_dir, label, timeout, cov_flags, defines):
    """Compile an SVUnit suite with Verilator, run it, and harvest coverage.dat.

    ``make binary`` (not the default target) is required: the default
    ``V<top>`` target runs ``verilator -f`` without ``--binary`` and therefore
    emits no C++ main(), which fails at link time with an undefined ``main``.
    """
    cov_dir = Path(cov_dir).resolve()
    opts = list(VERILATOR_BASE_FLAGS) + list(cov_flags) + list(defines)
    cmd = f'make binary VERILATOR_OPTIONS="{" ".join(opts)}"'
    try:
        run(cmd, cwd=build_dir, log=build_dir / "cov_make.log", timeout=timeout)
    except CoverageError as exc:
        log = build_dir / "cov_make.log"
        text = log.read_text(errors="replace") if log.is_file() else ""
        if re.search(r"[Cc]an(?:not|'t) find file containing module", text):
            missing = sorted(set(re.findall(r"module: '([^']+)'", text)))
            raise CoverageError(
                f"[{label}] the DUT uses Xilinx primitives Verilator has no "
                f"library for ({', '.join(missing)}). This core needs "
                f"--backend xsim; see firmware/docs/developer/COVERAGE.md."
            ) from None
        if "Can't find definition of" in text or re.search(
            r"Known scopes under '\w+': <no instances found>", text
        ):
            tasks = sorted(set(re.findall(r"Can't find definition of '(\w+)'", text)))
            raise CoverageError(
                f"[{label}] the testbench calls interface driver tasks "
                f"({', '.join(tasks) or 'unknown'}) that axi4_stream_if.sv "
                f"excludes under `ifndef VERILATOR`. This core needs "
                f"--backend xsim; see firmware/docs/developer/COVERAGE.md."
            ) from None
        if "exceeded" in str(exc):
            raise CoverageError(
                f"[{label}] {exc}\n"
                f"A Verilator elaboration that does not terminate is usually a "
                f"combinational loop or an unsatisfiable parameterization, not "
                f"a coverage problem."
            ) from None
        raise

    top = read_top_module(build_dir)
    exe = build_dir / f"V{top}"
    if not exe.is_file():
        raise CoverageError(
            f"[{label}] Verilator produced no V{top} executable; see "
            f"{build_dir / 'cov_make.log'}"
        )
    # SVUnit reads its filter from a plusarg; without it SVUnit warns and then
    # runs everything, which is what we want, but the warning is noise.
    out = run(
        f"./V{top} +SVUNIT_FILTER='*'",
        cwd=build_dir,
        log=build_dir / "vsim.log",
        timeout=timeout,
    )
    if PASS_MARKER not in out:
        raise CoverageError(
            f"[{label}] simulation did not report '{PASS_MARKER}'; "
            f"see {build_dir / 'vsim.log'}"
        )

    dat = build_dir / "coverage.dat"
    if not dat.is_file():
        raise CoverageError(
            f"[{label}] Verilator wrote no coverage.dat; is "
            f"--coverage-toggle missing from the run? (see cov_make.log)"
        )
    dest = cov_dir / "coverage.dat"
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.move(str(dat), str(dest))
    return dest, build_dir


def generate_report_verilator(dat_files, build_dirs, report_dir, exclude, keep_all):
    """Merge every configuration's coverage.dat into one lcov + annotated source.

    ``verilator_coverage`` records source paths relative to the directory it ran
    in, so ``--annotate`` has to run from a build directory or it cannot find
    the .sv files to mark up.
    """
    report_dir.mkdir(parents=True, exist_ok=True)
    info = report_dir / "coverage.info"
    dat_args = " ".join(str(d) for d in dat_files)
    cmd = f"verilator_coverage --write-info {info} {dat_args}"
    try:
        run(cmd, cwd=build_dirs[0], log=report_dir / "verilator_coverage.log")
    except CoverageError as exc:
        raise CoverageError(
            f"verilator_coverage failed on the collected coverage.dat files: {exc}"
        ) from None
    if not info.is_file():
        raise CoverageError(f"verilator_coverage produced no {info}")
    entries = to_entries(
        parse_lcov(info.read_text(errors="replace")),
        exclude=exclude,
        keep_all=keep_all,
    )
    annotate = report_dir / "annotate"
    annotate.mkdir(parents=True, exist_ok=True)
    try:
        run(
            f"verilator_coverage --annotate {annotate} {dat_args}",
            cwd=build_dirs[0],
            log=report_dir / "verilator_annotate.log",
        )
    except CoverageError as exc:
        # Annotation is a convenience; the numbers already came from the lcov
        # file, so a failure here must not lose an otherwise valid report.
        print(f"  note: source annotation unavailable ({exc})", file=sys.stderr)
    if not entries:
        raise CoverageError(
            "no DUT files matched the coverage filter. Re-run with --keep-all to "
            "see the raw report; if every file is a testbench, the core's RTL may "
            "not be reached through the 'test' target."
        )
    return entries


def simulate_xsim(build_dir, cov_dir, cc_type, label, timeout):
    xelab_opts, xsim_opts = read_makefile_opts(build_dir)
    cov_dir = Path(cov_dir).resolve()
    xelab_opts = f"{xelab_opts} --cc_type {cc_type} --cov_db_dir {cov_dir}".strip()
    cmd = f'make run XELAB_OPTIONS="{xelab_opts}" XSIM_OPTIONS="{xsim_opts}"'
    try:
        run(cmd, cwd=build_dir, log=build_dir / "cov_make.log", timeout=timeout)
    except CoverageError as exc:
        if "exceeded" in str(exc):
            raise CoverageError(
                f"[{label}] {exc}\n"
                f"A testbench that does not terminate is worth investigating on "
                f"its own: re-run it without coverage to see whether it is "
                f"coverage-specific."
            ) from None
        raise
    sim_log = build_dir / "xsim.log"
    if not sim_log.is_file() or PASS_MARKER not in sim_log.read_text(
        errors="replace"
    ):
        raise CoverageError(
            f"[{label}] simulation did not report '{PASS_MARKER}'; "
            f"see {sim_log if sim_log.is_file() else build_dir / 'cov_make.log'}"
        )
    db_root = cov_dir / CODE_COV_DB_DIRNAME
    dbs = [d for d in db_root.iterdir()] if db_root.is_dir() else []
    if not dbs:
        raise CoverageError(f"[{label}] no coverage database under {db_root}")
    return dbs


def generate_report_xsim(dbs, report_dir, exclude, keep_all=False):
    report_dir.mkdir(parents=True, exist_ok=True)
    parts = []
    for db in dbs:
        parts += [
            f"-cov_db_dir {db.parent.parent}",
            f"-cov_db_name {db.name}",
        ]
    cmd = f"xcrg {' '.join(parts)} -report_dir {report_dir} -report_format html"
    run(cmd, cwd=report_dir, log=report_dir / "xcrg.log")
    files_html = report_dir / "codeCoverageReport" / "files.html"
    if not files_html.is_file():
        raise CoverageError(f"xcrg produced no files.html under {report_dir}")
    return parse_files_html(files_html, exclude, keep_all)


COL_PATH = "File Path"
COL_LINES = "Lines Count"
COL_STMTS = "Statements Count"
SCORE_COLS = {
    "stmt": "Statement Coverage Score",
    "branch": "Branch Coverage Score",
    "condition": "Condition Coverage Score",
    "toggle": "Toggle Coverage Score",
}


def _cells(raw):
    cells = [
        html.unescape(re.sub(r"<[^>]+>", "", c)).strip()
        for c in re.findall(r"<t[dh].*?</t[dh]>", raw, re.S)
    ]
    return [c for c in cells if c]


def parse_files_html(files_html, exclude, keep_all):
    text = files_html.read_text(errors="replace")
    marker = text.find("File Specific Information")
    if marker < 0:
        raise CoverageError(f"{files_html} has no per-file table")
    segment = text[marker:]
    rows = [_cells(r) for r in re.findall(r"<tr.*?</tr>", segment, re.S)]
    header = next((r for r in rows if COL_PATH in r), None)
    if header is None:
        raise CoverageError(f"could not read the column header from {files_html}")
    col = {name: i for i, name in enumerate(header)}
    if COL_LINES not in col or COL_STMTS not in col:
        raise CoverageError(
            f"{files_html} lacks {COL_LINES}/{COL_STMTS} columns; xcrg output "
            f"changed shape. Header was: {header}"
        )

    user_exclude = re.compile(exclude) if exclude else None
    entries = []
    for cells in rows:
        if len(cells) != len(header) or not re.fullmatch(r"\d+", cells[0]):
            continue
        path = cells[col[COL_PATH]]
        if user_exclude and user_exclude.search(path):
            continue
        is_dut = bool(DUT_CORE_DIR_RE.search(path)) and not any(
            re.search(p, path) for p in INFRA_PATTERNS
        )
        if not keep_all and not is_dut:
            continue
        entry = {
            "path": path,
            "dut": is_dut,
            "lines_total": int(cells[col[COL_LINES]]),
            "stmt_total": int(cells[col[COL_STMTS]]),
            "stmt_pct": float(cells[col[SCORE_COLS["stmt"]]]),
        }
        for key, name in SCORE_COLS.items():
            if key != "stmt" and name in col:
                entry[f"{key}_pct"] = float(cells[col[name]])
        entries.append(entry)
    if not entries:
        raise CoverageError(
            "no DUT files matched the coverage filter; the design may be "
            "fileless under hdl/. Re-run with --keep-all to inspect the raw report."
        )
    return entries


def warn_silent_zeros(entries, backend="xsim"):
    empty = [Path(e["path"]).name for e in entries if e["stmt_total"] == 0]
    if not empty:
        return
    print(
        f"  WARNING: {backend} reported 0 coverage points for "
        + ", ".join(sorted(empty))
        + "\n           Treat this as NO DATA, not 0% -- see firmware/docs/developer/COVERAGE.md.",
        file=sys.stderr,
    )


def summarize(entries):
    # --keep-all appends testbench and vendor files with dut=False. They must
    # never reach a total or a gate: a 500-statement testbench next to a
    # 3-statement DUT is exactly what the DUT filter exists to exclude.
    dut = [e for e in entries if e.get("dut", True)]
    stmt_total = sum(e["stmt_total"] for e in dut)
    stmt_cov = sum(e["stmt_total"] * e["stmt_pct"] / 100.0 for e in dut)
    line_total = sum(e["lines_total"] for e in dut)
    line_cov = sum(e["lines_total"] * e["stmt_pct"] / 100.0 for e in dut)
    summary = {
        "files": len(dut),
        "files_total": len(entries),
        "statements": stmt_total,
        "statements_covered": round(stmt_cov, 1),
        "statement_pct": round(100.0 * stmt_cov / stmt_total, 2) if stmt_total else 0.0,
        "lines": line_total,
        "lines_covered": round(line_cov, 1),
        "line_pct": round(100.0 * line_cov / line_total, 2) if line_total else 0.0,
        # Distinguishes "measured nothing" from "measured 0%". Without this the
        # gate compares a real threshold against a fabricated 0.0 and reports an
        # unmeasurable DUT as a failed measurement.
        "measured": stmt_total > 0,
    }
    # Weight each sub-metric by the number of points it actually measured, not
    # by statements: a file with 4 toggle points should not move the total as
    # much as one with 400. branch and condition come from the xcrg HTML, which
    # reports no per-file point counts, so they fall back to statement weight;
    # toggle carries its own point count from the lcov records.
    weights = {
        "branch": "branch_total",
        "condition": "stmt_total",
        "toggle": "toggle_total",
    }
    for key, weight_key in weights.items():
        vals = [
            e for e in dut if isinstance(e.get(f"{key}_pct"), (int, float))
        ]
        if not vals:
            continue
        wsum = sum(e.get(weight_key, e["stmt_total"]) for e in vals)
        if not wsum:
            continue
        summary[f"{key}_pct"] = round(
            sum(
                e[f"{key}_pct"] * e.get(weight_key, e["stmt_total"]) for e in vals
            )
            / wsum,
            2,
        )
    return summary


def print_table(entries, summary, backend="xsim"):
    has_toggle = any("toggle_pct" in e for e in entries)
    print("")
    print(f"  DUT coverage  [{backend}]  (testbench/vendor files excluded)")
    print("  " + "-" * 72)
    for e in sorted(entries, key=lambda x: x["stmt_pct"]):
        tg = f"{e['toggle_pct']:6.2f}% tg" if has_toggle else ""
        print(
            f"  {e['stmt_pct']:6.2f}%  {e['stmt_total']:5d} stmt  {tg}  "
            f"{Path(e['path']).name}"
        )
    print("  " + "-" * 72)
    tail = " ".join(
        f"{k} {summary[f'{k}_pct']:.2f}%"
        for k in ("branch", "toggle")
        if f"{k}_pct" in summary
    )
    print(
        f"  {summary['statement_pct']:6.2f}%  {summary['statements']:5d} stmt  "
        f"TOTAL over {summary['files']} DUT file(s)  "
        f"({tail + ' point-weighted' if tail else ''})"
    )
    # No separate "line coverage" row. line_pct is the statement percentage
    # re-weighted by line count, not a count of covered lines, and printing it
    # beside statement_pct invites reading the two as independent measurements.
    if backend == "verilator":
        print(
            "  note: 'stmt' under --coverage-toggle counts lines that carried at "
            "least one coverage point, not xsim statements."
        )
    print("")


def normalize_flag_values(argv):
    """Rewrite ``--config --TB_N=64`` into ``--config=--TB_N=64``.

    A sim configuration always looks like a fusesoc flag, so argparse would
    otherwise read it as the next option rather than as --config's value. Both
    --config and --configs are covered. The Makefile quotes the value (a config
    is a list of flags and may contain spaces); this turns that single token
    back into the ``=`` form so it survives argparse. Hand-written invocations
    that already use ``=`` pass through untouched.
    """
    raw = list(sys.argv[1:] if argv is None else argv)
    out = []
    i = 0
    while i < len(raw):
        if (
            raw[i] in ("--config", "--configs")
            and i + 1 < len(raw)
            and raw[i + 1].startswith("-")
        ):
            out.append(f"{raw[i]}={raw[i + 1]}")
            i += 2
        else:
            out.append(raw[i])
            i += 1
    return out


def main(argv=None):
    ap = argparse.ArgumentParser(
        description="Run SVUnit tests under Verilator or xsim and report DUT "
        "code coverage."
    )
    ap.add_argument("--core", required=True, help="core VLNV, e.g. qick:mem:fifo_async")
    ap.add_argument(
        "--backend",
        default="verilator",
        choices=["verilator", "xsim"],
        help="simulator to instrument and run with (default: verilator). Verilator "
        "runs the SVUnit suite natively in milliseconds and is the only backend "
        "that reaches purely combinational RTL; xsim is kept for statement "
        "coverage.",
    )
    ap.add_argument(
        "--config",
        action="append",
        default=[],
        metavar="ARGS",
        help="one sim configuration as fusesoc args; repeatable. Each becomes a "
        "separate run whose database is merged into the same report.",
    )
    ap.add_argument(
        "--configs",
        default=None,
        metavar="A|B|C",
        help="pipe-separated sim configurations, split here rather than in the "
        "Makefile because a configuration contains spaces",
    )
    ap.add_argument(
        "--cc-type",
        default="sb",
        help="xelab --cc_type (xsim backend only): any of s,b,c,t (default: sb). "
        "Toggle coverage (t) is the most useful for FSM-heavy IP but is slow and "
        "memory hungry.",
    )
    ap.add_argument(
        "--verilator-cov",
        default="t",
        help="Verilator coverage flags as letters (verilator backend only): "
        "t toggles (default). 'l' for lines is rejected: Verilator 5.042 "
        "miscompiles SVUnit testcases under --coverage-line. See firmware/docs/developer/COVERAGE.md.",
    )
    ap.add_argument(
        "--define",
        action="append",
        default=None,
        metavar="NAME",
        help="verilog define to compile with, e.g. --define SVUNIT (repeatable). "
        "verilator backend only.",
    )
    ap.add_argument("--out", default="report_cov", help="output directory")
    ap.add_argument("--exclude", default=None, help="regex; drop matching files")
    ap.add_argument(
        "--keep-all",
        action="store_true",
        help="report every file including TB/vendor, instead of DUT only",
    )
    ap.add_argument(
        "--min-line",
        type=float,
        default=None,
        help="fail if DUT line coverage is below this percentage",
    )
    ap.add_argument(
        "--min-toggle",
        type=float,
        default=None,
        help="fail if DUT toggle coverage is below this percentage",
    )
    ap.add_argument(
        "--timeout",
        type=int,
        default=1800,
        help="per-run wall-clock limit in seconds for elaborate+simulate. A "
        "testbench that never terminates would otherwise block a whole "
        "coverage-all sweep (default: 1800)",
    )
    args = ap.parse_args(normalize_flag_values(argv))

    check_tool(args.backend)

    fusesoc_root = Path(__file__).resolve().parents[2]
    core = resolve_vlnv(fusesoc_root, args.core)
    if core != args.core:
        print(f"==> '{args.core}' resolves to {core}", flush=True)
    args.core = core

    out_root = Path(args.out)
    if not out_root.is_absolute():
        out_root = fusesoc_root / out_root
    out_root.mkdir(parents=True, exist_ok=True)
    configs = list(args.config)
    if args.configs:
        configs += [c.strip() for c in args.configs.split("|") if c.strip()]
    configs = configs or [""]

    verilator = args.backend == "verilator"
    cov_flags = []
    if verilator:
        if "l" in args.verilator_cov.lower():
            raise CoverageError(
                "--verilator-cov=l is not supported: Verilator 5.042 emits C++ that "
                "does not compile for an SVUnit testcase under --coverage-line "
                "(svunit_testcase::new()'s 'name' formal argument is resolved as a "
                "data member in __ctor_var_reset). Toggle coverage works and is "
                "what this backend gates on; use --backend xsim for statement "
                "coverage."
            )
        if "t" in args.verilator_cov.lower():
            cov_flags.append("--coverage-toggle")
        timescale = xsim_timescale(fusesoc_root, args.core)
        if timescale:
            print(f"==> --timescale {timescale} (from the xsim test target)", flush=True)
            cov_flags += ["--timescale", timescale]
    defines = [f"-D{d}" for d in (args.define or [])]

    tag = re.sub(r"[^A-Za-z0-9_.-]", "_", args.core.replace(":", "_"))
    db_root = out_root / tag / "db"
    db_root.mkdir(parents=True, exist_ok=True)
    dbs = []
    build_dirs = []
    for idx, extra in enumerate(configs):
        label = extra.strip() or "default"
        build_dir = resolve_build_dir(fusesoc_root, args.core, extra, args.backend)
        cov_dir = db_root / f"cfg{idx}"
        if cov_dir.exists():
            shutil.rmtree(cov_dir)
        print(f"==> [{idx + 1}/{len(configs)}] {args.core}  ({label})", flush=True)
        if verilator:
            dat, bdir = simulate_verilator(
                build_dir,
                cov_dir,
                label,
                args.timeout,
                cov_flags,
                defines,
            )
            dbs.append(dat)
            build_dirs.append(bdir)
        else:
            dbs += simulate_xsim(
                build_dir, cov_dir, args.cc_type, label, args.timeout
            )

    report_dir = out_root / tag / "html"
    if verilator:
        entries = generate_report_verilator(
            dbs, build_dirs, report_dir, args.exclude, args.keep_all
        )
    else:
        entries = generate_report_xsim(dbs, report_dir, args.exclude, args.keep_all)
    summary = summarize(entries)
    summary["core"] = args.core
    summary["backend"] = args.backend
    summary["configs"] = [c.strip() or "default" for c in configs]
    if verilator:
        summary["verilator_cov"] = args.verilator_cov
        summary["defines"] = [d.lstrip("-D") for d in defines]
    else:
        summary["cc_type"] = args.cc_type
    summary["files_detail"] = entries

    (out_root / tag / "summary.json").write_text(json.dumps(summary, indent=2))
    print_table(entries, summary, args.backend)
    warn_silent_zeros(entries, args.backend)
    report_link = (
        report_dir / "annotate"
        if verilator
        else report_dir / "codeCoverageReport"
    )
    print(f"  Annotated   : {report_link}")
    print(f"  JSON summary: {out_root / tag / 'summary.json'}")
    print("")

    failures = []
    if not summary.get("measured", True):
        print(
            "COVERAGE UNUSABLE: no DUT file reported a single coverage point, "
            "so there is nothing to compare a gate against. This is NO DATA, "
            "not 0%; see firmware/docs/developer/COVERAGE.md.",
            file=sys.stderr,
        )
        failures.append("measured")

    thresholds = [("line_pct", args.min_line), ("toggle_pct", args.min_toggle)]
    for metric, threshold in thresholds:
        if threshold is None:
            continue
        got = summary.get(metric)
        if not isinstance(got, (int, float)):
            # A gate that is silently skipped exits 0, which reads as "coverage
            # is fine". Refusing the gate is the only safe answer: the caller
            # asked for a number this backend could not produce.
            print(
                f"COVERAGE GATE FAILED: {metric} was not measured by the "
                f"{args.backend} backend, so the requested {threshold:.2f}% "
                f"threshold cannot be evaluated.",
                file=sys.stderr,
            )
            failures.append(metric)
            continue
        if got < threshold:
            print(
                f"COVERAGE GATE FAILED: {metric} {got:.2f}% < {threshold:.2f}%",
                file=sys.stderr,
            )
            failures.append(metric)
    return 1 if failures else 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except CoverageError as exc:
        print(f"error: {exc}", file=sys.stderr)
        sys.exit(2)
