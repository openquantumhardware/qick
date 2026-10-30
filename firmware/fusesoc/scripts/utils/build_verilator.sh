#!/bin/bash

# Verilator is the default backend for `make coverage`, so a machine without it
# cannot measure coverage at all. Vivado does not bundle Verilator, so a working
# `which vivado` says nothing about it -- it has to be installed separately.
#
# Deliberately NON-FATAL. Most work on this repo runs under xsim, and a Verilator
# that cannot be provisioned without root must not stop someone from setting up
# the venv, the FuseSoC libraries and the symlinks. Coverage already fails with
# an explicit message (cov_run.py's check_tool) if Verilator is missing when it
# is actually needed.
#
# Run from firmware/fusesoc/.

# The Verilator the repository pins (VERILATOR_VERSION in the Makefile, validated
# when it was pinned), so an older one on PATH is reported. 5.020 cannot parse SVUnit's
# sources; 5.042 was the previous pin; 5.046 to 5.052 need the SVUnit of
# build_fusesocenv.sh (lharnaldi/svunit), which works around their bugs. Kept in step
# with MIN_VERILATOR in scripts/cov/cov_run.py.
MIN_MAJOR=5
MIN_MINOR=52
MIN_TEXT="5.052"   # zero-padded, as Verilator prints it

# Returns 0 if $1 (a verilator executable) is new enough, 1 if too old or
# unparseable.
version_ok() {
    local v major minor
    v=$("$1" --version 2>/dev/null | head -1 | awk '{print $2}')
    [ -n "$v" ] || return 1
    major=${v%%.*}
    minor=${v#*.}
    minor=${minor%%.*}
    case "$major$minor" in *[!0-9]*) return 1 ;; esac
    [ "$major" -gt "$MIN_MAJOR" ] && return 0
    [ "$major" -eq "$MIN_MAJOR" ] && [ "$minor" -ge "$MIN_MINOR" ] && return 0
    return 1
}

report() {
    local exe=$1
    local v
    v=$("$exe" --version 2>/dev/null | head -1)
    if version_ok "$exe"; then
        echo "Verilator: $v at $exe"
    else
        echo "Verilator: TOO OLD -- $v at $exe"
        echo "Verilator: this coverage flow is validated against ${MIN_TEXT}"
        echo "Verilator: or newer; older releases cannot parse SVUnit's sources."
        echo "Verilator: Upgrade it, or use 'make coverage IP=<core> COV_BACKEND=xsim COV=sb'."
    fi
}

# 1. Already usable, in the same order cov_run.py's check_tool() resolves it, so
#    the two can never disagree about whether Verilator is available.
if [ -n "$VERILATOR_ROOT" ] && [ -x "$VERILATOR_ROOT/bin/verilator" ]; then
    report "$VERILATOR_ROOT/bin/verilator"
    exit 0
fi
if command -v verilator > /dev/null 2>&1; then
    report "$(command -v verilator)"
    exit 0
fi

# 1b. The user-level install made by `make install_verilator` (scripts/utils/install_verilator.sh).
#     cov_run.py's check_tool() falls back to the same place, so they still agree.
DEFAULT_VERILATOR="$HOME/.local/verilator/bin/verilator"
if [ -x "$DEFAULT_VERILATOR" ]; then
    report "$DEFAULT_VERILATOR"
    exit 0
fi

# 2. Try the distro package, non-interactively, only if that can work unattended.
#    Quiet unless it succeeds, so a normal run stays quiet.
PKG=""
if command -v dnf > /dev/null 2>&1; then
    PKG="dnf install -y verilator"
elif command -v yum > /dev/null 2>&1; then
    PKG="yum install -y verilator"
elif command -v apt-get > /dev/null 2>&1; then
    PKG="apt-get install -y verilator"
fi

if [ -n "$PKG" ] && command -v sudo > /dev/null 2>&1 && sudo -n true 2>/dev/null; then
    echo "Verilator: not found, installing via '$PKG' ..."
    if sudo -n $PKG > /tmp/verilator_install.$$ 2>&1 && command -v verilator > /dev/null 2>&1; then
        rm -f /tmp/verilator_install.$$
        report "$(command -v verilator)"
        exit 0
    fi
    echo "Verilator: package install failed, see /tmp/verilator_install.$$"
else
    echo "Verilator: not found, and it cannot be installed unattended."
fi

# 3. Tell the user exactly what is needed and how to satisfy it.
cat >&2 <<'EOF'

! Verilator is NOT installed. Everything else in setup_environment is fine, and
  simulation under xsim is unaffected, but `make coverage` needs Verilator --
  it is the default backend.

  Without root, build the validated release into your home (a few minutes, no
  other setup; setup_environment and `make coverage` then find it by themselves):

    make install_verilator

  Or install it however your machine is provisioned, at version 5.042 or newer:

    sudo dnf install verilator        # RHEL / AlmaLinux
    sudo apt-get install verilator    # Debian / Ubuntu
    # or point at an existing install:
    export VERILATOR_ROOT=/path/to/verilator
    # or add its bin/ to PATH

  A distro package older than 5.042 will not do: it cannot parse SVUnit's
  sources and fails with a syntax error inside svunit_base. If `dnf` gives you
  an old one, install a newer release by hand and set VERILATOR_ROOT.

  Until then, coverage still works through the xsim backend, which needs only
  Vivado:

    make coverage IP=<core> COV_BACKEND=xsim COV=sb

EOF
exit 0
