#!/usr/bin/env bash
# Refuse a commit (or a pushed commit) that carries generated output.
#
#   firmware/scripts/check_staged_files.sh            # what is staged now (run it before EVERY `git commit`)
#   firmware/scripts/check_staged_files.sh <commit>   # the files a commit added/changed (e.g. before a push: `... origin/<branch>..HEAD` style loops, or one SHA)
#
# Exit 1 if any added/changed/renamed file matches a generated-output pattern, or if more than MAX_ADDED (default 60) files are ADDED at once (a directory was
# staged: `git add <dir>` sweeps in every untracked file below it, which is how 88 generated register-doc files got into a commit on 2026-10-07).
# Set ALLOW_MANY=1 only for a deliberate bulk add (a new vendored library), after looking at `git diff --cached --stat`.
# Why: `git add <directory>` swept 88 generated files into a commit once (2026-10-07); stage explicit file paths.
set -u
if [ $# -ge 1 ]; then
  files=$(git show --name-only --diff-filter=ACMR --format= "$1")
  added=$(git show --name-only --diff-filter=A --format= "$1")
  what="commit $1"
else
  files=$(git diff --cached --name-only --diff-filter=ACMR)
  added=$(git diff --cached --name-only --diff-filter=A)
  what="the index"
fi
GENERATED='(^|/)__pycache__/|\.pyc$|\.pytest_cache/|(^|/)report_pytest/|(^|/)report_svunit/|\.fusesoc_libraries|(^|/)build/|\.Xil/|\.srcs/|\.gen/|\.runs/|\.cache/|\.ip_user_files/|\.(bit|hwh|xsa|ltx|dcp|vcd|wdb|jou|pb)$|(^|/)rdl/(content|css|data|fonts|js|search|\.launcher_data)/|(^|/)rdl/(index\.html|favicon\.png|launcher-windows-[a-z]*\.bat)$|^firmware/ip/|\.log$'
bad=$(printf '%s\n' "$files" | grep -E "$GENERATED" || true)
n_added=$(printf '%s\n' "$added" | grep -c . || true)
rc=0
if [ -n "$bad" ]; then
  echo "REFUSED: $what contains generated output ($(printf '%s\n' "$bad" | grep -c .) files):" >&2
  printf '%s\n' "$bad" | sed 's#^#   #' | head -15 >&2
  [ "$(printf '%s\n' "$bad" | grep -c .)" -gt 15 ] && echo "   ..." >&2
  echo "Unstage them (git restore --staged <path>) and stage explicit FILE paths only." >&2
  rc=1
fi
if [ "$n_added" -gt "${MAX_ADDED:-60}" ] && [ "${ALLOW_MANY:-0}" != "1" ]; then
  echo "REFUSED: $what ADDS $n_added files (limit ${MAX_ADDED:-60}); a directory was probably staged. Per directory:" >&2
  printf '%s\n' "$added" | sed 's#/[^/]*$##' | sort | uniq -c | sort -rn | head -8 | sed 's#^#   #' >&2
  echo "Check 'git diff --cached --stat'. A deliberate bulk add: ALLOW_MANY=1 $0" >&2
  rc=1
fi
[ $rc -eq 0 ] && echo "check_staged_files: $what is clean ($(printf '%s\n' "$files" | grep -c .) files, $n_added added)"
exit $rc
