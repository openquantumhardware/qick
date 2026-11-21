#!/usr/bin/env bash
# xsim regression over every core with an ip-level tests/ directory.
# Used to confirm that changing common/sim/modules/clk_gen/hdl/clk_gen.sv did
# not alter simulation results. Verilog-only, no python needed.
set -u
cd "$(dirname "$0")/../.." || exit 1
. ../../.venv/bin/activate
ROOT="--cores-root cores --cores-root common --cores-root generators"
pass=0
fail=""
for v in $(fusesoc $ROOT list-cores 2>/dev/null | cut -d: -f1-3 | sort -u); do
  short=${v#qick:}
  short=${short##*:}
  [ -d "cores/ip/$short/tests" ] || continue
  printf '%-28s ' "$v"
  if timeout 600 fusesoc $ROOT run --target test "$v" >"/tmp/kilo/xr_$short.log" 2>&1 \
     && grep -q 'PASSED' "/tmp/kilo/xr_$short.log"; then
    echo PASS
    pass=$((pass+1))
  else
    echo FAIL
    fail="$fail $v"
  fi
done
echo "===="
echo "XSIM REGRESSION pass=$pass"
echo "FAILED:${fail:- none}"