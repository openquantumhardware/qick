#!/usr/bin/env bash
# Full xsim validation of the two changes that touch simulation behaviour:
#
#   1. common/sim/modules/clk_gen/hdl/clk_gen.sv -- clock no longer depends on
#      the implicit x->1 transition on a constant i_enable.
#   2. -d SVUNIT added to 30 core test targets (scripts/cov/apply_svunit.py),
#      which switches the axi4_stream_if protocol checkers on for those builds.
#
# Any FAIL here must be classified: a core that already failed before these
# changes is a pre-existing breakage and must be reported as such, not as a
# regression. Use --compare to run each failing core again with its .core
# change stashed.
set -u
cd "$(dirname "$0")/../.." || exit 1
. ../../.venv/bin/activate
ROOT="--cores-root cores --cores-root common --cores-root generators"

# The cores apply_svunit.py patched, short names.
SVUNIT_CORES=$(python3 - <<'PY'
import importlib.util, pathlib
spec = importlib.util.spec_from_file_location(
    "a", pathlib.Path("scripts/cov/apply_svunit.py"))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
print(" ".join(sorted({pathlib.Path(d).name for d, _ in m.TARGETS})))
PY
)

IP_CORES=$(ls -d cores/ip/*/ 2>/dev/null | xargs -n1 basename)

run_one() {
  local c="$1" tag="$2"
  printf '%-26s %-4s ' "$c" "$tag"
  if timeout 900 fusesoc $ROOT run --target test "$c" >"/tmp/kilo/val_${tag}_$c.log" 2>&1 \
     && grep -q 'PASSED' "/tmp/kilo/val_${tag}_$c.log"; then
    echo PASS
    return 0
  fi
  echo FAIL
  return 1
}

total_pass=0
total_fail=0
failed_list=""

echo "########## cores/ip/* (regression on clk_gen)"
for c in $IP_CORES; do
  if run_one "$c" new; then total_pass=$((total_pass+1)); else
    total_fail=$((total_fail+1)); failed_list="$failed_list $c"; fi
done

echo
echo "########## -d SVUNIT patched cores (new vs baseline)"
for c in $SVUNIT_CORES; do
  [ -d "cores/ip/$c" ] && continue   # already covered above
  if run_one "$c" new; then
    total_pass=$((total_pass+1))
  else
    total_fail=$((total_fail+1))
    failed_list="$failed_list $c"
    # Classify: re-run with the .core change reverted.
    core_path=$(find cores -name "$c.core" -not -path './build/*' | head -1)
    if [ -n "$core_path" ]; then
      git stash push -q "$core_path" 2>/dev/null
      run_one "$c" base || echo "           -> $c FAILS AT BASELINE TOO (pre-existing)"
      git stash pop -q 2>/dev/null
    fi
  fi
done

echo
echo "===="
echo "pass=$total_pass fail=$total_fail"
echo "FAILED:${failed_list:- none}"