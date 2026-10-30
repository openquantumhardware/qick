#!/bin/bash
set -e
source ../../.venv/bin/activate
# SVUnit with FuseSoC support: ivanvig/svunit (FuseSoC core, testrunner generator, xsim fixes) forked to
# lharnaldi/svunit, which adds the fixes our flows need with Verilator 5.046 and newer.
SVUNIT_URI=https://github.com/lharnaldi/svunit.git
SVUNIT_DIR=.fusesoc_libraries/svunit_lib
if grep -q '^\[library.svunit_lib\]' fusesoc.conf 2>/dev/null; then
    # A checkout set up before the move still follows ivanvig/svunit: fusesoc has no
    # "library remove", so point its fusesoc.conf entry and its clone at the fork.
    if ! grep -q "^sync-uri = $SVUNIT_URI\$" fusesoc.conf; then
        sed -i "/^\[library.svunit_lib\]/,/^\[/ s#^sync-uri = .*#sync-uri = $SVUNIT_URI#" fusesoc.conf
        git -C "$SVUNIT_DIR" remote set-url origin "$SVUNIT_URI"
        echo "svunit_lib now follows $SVUNIT_URI"
    fi
    fusesoc library update svunit_lib
else
    fusesoc library add \
        --location "$SVUNIT_DIR" \
        svunit_lib \
        "$SVUNIT_URI"
fi
