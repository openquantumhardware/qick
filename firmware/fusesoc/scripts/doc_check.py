#!/usr/bin/env python3
"""Check that the documentation under firmware/ is complete and consistent (`make doc-check`).

Fails (exit 1) on:
  1. an IP (cores/ip/<ip>) without README.md, or whose README lacks a required section of IP_README_TEMPLATE.md
     (the sections every IP has; U2 and U4 are left out: the glue IPs have nothing to say there). Part I sections are
     "## U<n>." headings; Part II ones (Ports, Registers, Verification, Files, Open items) may be numbered and nested;
  2. a Hog project (Top/<board>/<project>, the ones with a hog.conf) without README.md;
  3. a library core (cores/lib/<category>/...) that its category README.md does not list, or a listed core that
     no longer exists;
  4. a relative Markdown link, in any README or document under firmware/ and in CLAUDE.md, that points nowhere;
  5. a tracked text file that names the home directory of the user running the check: paths must be generic.

Warns (does not fail) about a library core whose .core has no description or only a placeholder one, and about a tracked
CLAUDE.md, TODO.md or PLAN_*.md: those are private files and live outside the repository.

Run from firmware/fusesoc/: python3 scripts/doc_check.py
"""
import os
import re
import subprocess
import sys
from pathlib import Path

FUSESOC = Path(__file__).resolve().parents[1]
FIRMWARE = FUSESOC.parent
REPO = FIRMWARE.parent

# Part I sections must be "## U<n>." headings. The reference sections of Part II may sit at any heading level and
# carry a number (qick_time_tagger has "### 2.2 Ports", "### 3.3 Register map", "## 4. Files", "## 5. Open items").
IP_PART1 = ["U1.", "U3.", "U5.", "U6.", "U7.", "U8."]
IP_PART2 = {"Ports": r"Ports?", "Registers": r"Register", "Verification": r"Verification", "Files": r"Files",
            "Open items": r"Open items"}
SKIP_DIRS = {"Hog", "ip", "build", "rdl", "rdl_pkgs", ".venv", ".git", "Projects", "bin", "node_modules", "report_pytest", "report_svunit",
             "report_cov", ".fusesoc_libraries", "tests"}


def tracked(*pathspecs):
    """Paths (absolute) git tracks under the given pathspecs, relative to the repository root.

    Only what is in the index is checked: a directory left behind by another branch (untracked files that a checkout
    does not remove) is not part of this branch's documentation. Outside a git checkout, falls back to the file system.
    """
    try:
        out = subprocess.run(["git", "ls-files", "--", *pathspecs], cwd=REPO, capture_output=True, text=True, check=True).stdout
        return [REPO / l for l in out.splitlines() if (REPO / l).exists()]
    except (OSError, subprocess.CalledProcessError):
        found = []
        for spec in pathspecs:
            found += list(REPO.glob(spec.replace(":(glob)", "")))  # same pattern, same meaning for pathlib
        return found


#: IPs whose README has its own, compact format and is not held to the template. Each entry says why; it is reported
#: as a warning so that the exception stays visible. Keep this list short: write the README to the template instead.
IP_README_EXEMPT = {
    "qick_periph_loopback": "test peripheral for the tProc QP1/QP2 ports: a compact README (behaviour, ports, verification) with no registers",
}


def core_name(core_file):
    m = re.search(r"^name\s*:\s*(\S+)", core_file.read_text(), re.M)
    return m.group(1).split(":")[2] if m else core_file.stem


def check_ips(errors, warnings):
    ip_dirs = sorted({f.parent for f in tracked(":(glob)firmware/fusesoc/cores/ip/*/*.core")})
    for d in ip_dirs:
        readme = d / "README.md"
        if not readme.exists():
            errors.append(f"{d.relative_to(FIRMWARE)}: no README.md (template: docs/developer/IP_README_TEMPLATE.md)")
            continue
        lines = readme.read_text(encoding="utf-8").splitlines()
        if d.name in IP_README_EXEMPT:
            warnings.append(f"{d.name}: README not checked against the template ({IP_README_EXEMPT[d.name]})")
            continue
        heads = [l.strip() for l in lines if l.startswith("#")]
        missing = [u for u in IP_PART1 if not any(h.startswith("## " + u) for h in heads)]
        for name, pat in IP_PART2.items():
            if not any(re.match(r"#{2,4}\s+(\d+(\.\d+)*\.?\s+)?" + pat, h) for h in heads):
                missing.append(name)
        if missing:
            errors.append(f"{readme.relative_to(FIRMWARE)}: missing sections of the template: " + ", ".join(m.rstrip(".") for m in missing))


def check_tops(errors):
    for conf in sorted(tracked(":(glob)firmware/Top/*/*/hog.conf")):
        if not (conf.parent / "README.md").exists():
            errors.append(f"{conf.parent.relative_to(FIRMWARE)}: no README.md")


def check_libs(errors, warnings):
    lib = FUSESOC / "cores" / "lib"
    for cat in sorted(p for p in lib.iterdir() if p.is_dir() and tracked(f":(glob)firmware/fusesoc/cores/lib/{p.name}/*/*.core")):
        cores = {}
        for cf in tracked(f":(glob)firmware/fusesoc/cores/lib/{cat.name}/*/*.core"):
            txt = cf.read_text()
            m = re.search(r"^description:\s*(.*)$", txt, re.M)
            desc = m.group(1).strip().strip("\"'") if m else ""
            cores[core_name(cf)] = desc
        readme = cat / "README.md"
        if not readme.exists():
            errors.append(f"{cat.relative_to(FIRMWARE)}: no README.md")
            continue
        listed = set(re.findall(r"^\| \[`([^`]+)`\]", readme.read_text(encoding="utf-8"), re.M))
        for n in sorted(set(cores) - listed):
            errors.append(f"{readme.relative_to(FIRMWARE)}: core '{n}' is not in the table")
        for n in sorted(listed - set(cores)):
            errors.append(f"{readme.relative_to(FIRMWARE)}: '{n}' is in the table but there is no such core")
        for n, desc in sorted(cores.items()):
            if not desc or re.fullmatch(re.escape(n) + r" \(.*\)", desc):
                warnings.append(f"{cat.name}/{n}: the .core description is missing or a placeholder ('{desc}')")


def md_files():
    files = [REPO / "CLAUDE.md"] if (REPO / "CLAUDE.md").exists() else []
    for p in tracked(":(glob)firmware/**/*.md"):
        if SKIP_DIRS & set(p.relative_to(FIRMWARE).parts[:-1]):
            continue
        files.append(p)
    return files


def check_links(errors):
    for f in md_files():
        text = f.read_text(encoding="utf-8")
        text = re.sub(r"```.*?```", "", text, flags=re.S)  # not the links inside code blocks
        for m in re.finditer(r"\]\(([^)\s]+)\)", text):
            target = m.group(1)
            if re.match(r"[a-z]+:|mailto:|#", target):
                continue
            path = target.split("#")[0]
            if path and not (f.parent / path).exists():
                errors.append(f"{f.relative_to(REPO)}: broken link ({target})")


# The home directory of whoever runs the check: the paths of other people (/home/xilinx of the PYNQ images, /home/username of a
# tutorial) are not ours to judge, and the check names nobody.
HOME_PATH = re.compile(re.escape("/home/" + os.environ.get("USER", "nobody")) + r"/")
TEXT_SUFFIXES = {".md", ".rst", ".py", ".sh", ".tcl", ".sv", ".svh", ".v", ".vhd", ".core", ".yaml", ".yml", ".xdc", ".txt",
                 ".conf", ".con", ".src", ".gtkw", ".ipynb", ".json", ".cfg", ".toml", ".mk", ""}


def check_home_paths(errors):
    for f in tracked(":(glob)**"):
        rel = f.relative_to(REPO)
        if rel.parts[:2] == ("firmware", "Hog") or rel.parts[:2] == ("firmware", "ip") or "rdl_pkgs" in rel.parts:
            continue
        if f.suffix.lower() not in TEXT_SUFFIXES or f.is_symlink() or not f.is_file():
            continue
        try:
            text = f.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            continue
        hits = HOME_PATH.findall(text)
        if hits:
            errors.append(f"{rel}: {len(hits)} path(s) with a home directory, e.g. {hits[0]}...")


def check_private_files(warnings):
    for f in tracked(":(glob)**"):
        if f.name in ("CLAUDE.md", "TODO.md") or (f.name.startswith("PLAN_") and f.suffix == ".md"):
            warnings.append(f"{f.relative_to(REPO)} is tracked: private files live outside the repository")


def main():
    errors, warnings = [], []
    check_ips(errors, warnings)
    check_tops(errors)
    check_libs(errors, warnings)
    check_links(errors)
    check_home_paths(errors)
    check_private_files(warnings)
    for w in warnings:
        print("warning:", w)
    for e in errors:
        print("ERROR:", e)
    if errors:
        print(f"doc-check FAILED: {len(errors)} problem(s), {len(warnings)} warning(s)")
        return 1
    print(f"doc-check OK ({len(warnings)} warning(s))")
    return 0


if __name__ == "__main__":
    sys.exit(main())
