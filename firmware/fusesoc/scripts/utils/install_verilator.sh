#!/bin/bash
# ============================================================================
# install_verilator.sh -- build Verilator from source into a user directory.
#
# Why this exists: `make coverage` defaults to the Verilator backend and needs
# Verilator >= 5.042 (older releases cannot parse SVUnit's sources). Vivado does
# not bundle it, a distro package is usually older than that, and installing one
# needs root. This builds the exact release the coverage flow is validated
# against under $HOME, with no root, in a few minutes.
#
# Run from firmware/fusesoc/ (or through `make install_verilator`).
#
#   VERILATOR_VERSION  release to build           (default: 5.052; the Makefile passes its VERILATOR_VERSION)
#   VERILATOR_PREFIX   where to install           (default: $HOME/.local/verilator-<version>)
#   JOBS               parallel build jobs        (default: all cores)
#
# After a successful install $HOME/.local/verilator points at the new version.
# build_verilator.sh and scripts/cov/cov_run.py look there when neither
# VERILATOR_ROOT nor PATH provides a Verilator, so nothing needs to be exported.
# Idempotent: it does nothing if that version is already installed.
# ============================================================================
set -euo pipefail

VERSION="${VERILATOR_VERSION:-5.052}"
PREFIX="${VERILATOR_PREFIX:-$HOME/.local/verilator-$VERSION}"
JOBS="${JOBS:-$(nproc 2>/dev/null || echo 4)}"
LINK="$HOME/.local/verilator"
REPO_URL="https://github.com/verilator/verilator.git"

installed_version() {
    "$1" --version 2>/dev/null | head -1 | awk '{print $2}'
}

if [ -x "$PREFIX/bin/verilator" ] && [ "$(installed_version "$PREFIX/bin/verilator")" = "$VERSION" ]; then
    echo "Verilator $VERSION already installed at $PREFIX"
    if [ "$PREFIX" = "$HOME/.local/verilator-$VERSION" ]; then
        mkdir -p "$HOME/.local"
        ln -sfn "$PREFIX" "$LINK"
    fi
    exit 0
fi

# --- build dependencies -----------------------------------------------------
missing=""
for tool in git gcc g++ make flex bison autoconf perl python3 help2man; do
    command -v "$tool" > /dev/null 2>&1 || missing="$missing $tool"
done
[ -f /usr/include/FlexLexer.h ] || missing="$missing FlexLexer.h(flex-devel)"
if [ -n "$missing" ]; then
    echo "ERROR: missing build dependencies:$missing" >&2
    echo "  On EL9: sudo dnf install git gcc-c++ make flex bison autoconf perl python3 help2man" >&2
    echo "  Or ask for a Verilator >= 5.042 package, and set VERILATOR_ROOT / PATH." >&2
    exit 1
fi

# Verilator's own build must not see an existing install.
unset VERILATOR_ROOT

WORK="$(mktemp -d "${TMPDIR:-/tmp}/verilator-build.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

echo "Verilator $VERSION: building from source into $PREFIX (jobs: $JOBS) ..."
git -c advice.detachedHead=false clone --quiet --depth 1 --branch "v$VERSION" "$REPO_URL" "$WORK/src" 2>/dev/null
cd "$WORK/src"
autoconf
./configure --prefix="$PREFIX" > "$WORK/configure.log" 2>&1 || { tail -20 "$WORK/configure.log" >&2; exit 1; }
make -j"$JOBS" > "$WORK/make.log" 2>&1 || { tail -30 "$WORK/make.log" >&2; exit 1; }
make install > "$WORK/install.log" 2>&1 || { tail -20 "$WORK/install.log" >&2; exit 1; }

got="$(installed_version "$PREFIX/bin/verilator")"
if [ "$got" != "$VERSION" ]; then
    echo "ERROR: installed Verilator reports '$got', expected '$VERSION'" >&2
    exit 1
fi

if [ "$PREFIX" = "$HOME/.local/verilator-$VERSION" ]; then
    mkdir -p "$HOME/.local"
    ln -sfn "$PREFIX" "$LINK"
    echo "Verilator $VERSION installed at $PREFIX ($LINK -> it)."
    echo "Nothing to export: setup_environment and 'make coverage' look in $LINK."
else
    echo "Verilator $VERSION installed at $PREFIX."
    echo "Custom prefix: put $PREFIX/bin on PATH (not VERILATOR_ROOT: that variable expects a"
    echo "source tree layout, an installed prefix is found through PATH)."
fi
