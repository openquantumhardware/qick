#!/usr/bin/env bash
# One-shot environment setup for the QICK emulator notebooks.
#
# Run this from a normal terminal BEFORE opening Jupyter:
#     ./setup_emulator.sh
#
# It will:
#   1. (optional, y/N) build & install Verilator 5.038 from source.
#   2. (optional, y/N) install GTKWave via your package manager.
#   3. create .venv at the repo root and install Python deps + qick (editable).
#   4. register a Jupyter kernel named "qick-venv" (display: "Python (qick)").
#
# Re-running is safe: each step is idempotent and skipped if already satisfied.

set -euo pipefail

REQUIRED_VERILATOR_VERSION="5.038"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$REPO_ROOT/.venv"
REQ_FILE="$REPO_ROOT/emulator/requirements.txt"
KERNEL_NAME="qick-venv"
KERNEL_DISPLAY="Python (qick)"
VERILATOR_BUILD_DIR="$REPO_ROOT/.build/verilator"

if [[ -t 1 ]]; then
    C_INFO=$'\033[36m'; C_OK=$'\033[32m'; C_WARN=$'\033[33m'; C_ERR=$'\033[31m'; C_RST=$'\033[0m'
else
    C_INFO=""; C_OK=""; C_WARN=""; C_ERR=""; C_RST=""
fi

log()  { printf "%s[setup]%s %s\n" "$C_INFO" "$C_RST" "$*"; }
ok()   { printf "%s[ ok ]%s %s\n" "$C_OK"   "$C_RST" "$*"; }
warn() { printf "%s[warn]%s %s\n" "$C_WARN" "$C_RST" "$*"; }
err()  { printf "%s[err ]%s %s\n" "$C_ERR"  "$C_RST" "$*" 1>&2; }

confirm() {
    local prompt="$1" reply
    read -r -p "$prompt [y/N] " reply || reply=""
    [[ "$reply" =~ ^[Yy]$ ]]
}

detect_os() {
    case "$(uname -s)" in
        Linux*)  OS=linux ;;
        Darwin*) OS=macos ;;
        *) err "Unsupported OS: $(uname -s)"; exit 1 ;;
    esac
}

# ---------- verilator ----------

verilator_version() {
    command -v verilator >/dev/null 2>&1 || return 1
    verilator --version 2>/dev/null | awk 'NR==1{print $2}'
}

install_verilator_build_deps() {
    if [[ "$OS" == "linux" ]]; then
        if ! command -v apt-get >/dev/null 2>&1; then
            err "this script's verilator install assumes apt-get; install build deps manually then re-run."
            exit 1
        fi
        log "installing verilator build deps via apt (sudo)"
        sudo apt-get update
        sudo apt-get install -y \
            git help2man perl python3 make autoconf g++ flex bison ccache \
            libgoogle-perftools-dev numactl perl-doc libfl-dev zlib1g-dev
    else
        if ! command -v brew >/dev/null 2>&1; then
            err "Homebrew is required for the macOS verilator build path."
            exit 1
        fi
        log "installing verilator build deps via brew"
        brew install autoconf automake flex bison ccache help2man perl
    fi
}

install_verilator_from_source() {
    install_verilator_build_deps
    mkdir -p "$(dirname "$VERILATOR_BUILD_DIR")"
    if [[ ! -d "$VERILATOR_BUILD_DIR/.git" ]]; then
        log "cloning verilator into $VERILATOR_BUILD_DIR"
        git clone https://github.com/verilator/verilator.git "$VERILATOR_BUILD_DIR"
    fi
    pushd "$VERILATOR_BUILD_DIR" >/dev/null
    log "fetching tag v${REQUIRED_VERILATOR_VERSION}"
    git fetch --tags --quiet
    git checkout "v${REQUIRED_VERILATOR_VERSION}"
    log "configuring..."
    autoconf
    ./configure
    local jobs
    jobs=$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)
    log "building (make -j${jobs}) — this takes a few minutes"
    make -j"$jobs"
    log "installing to /usr/local (sudo make install)"
    sudo make install
    popd >/dev/null
    ok "verilator ${REQUIRED_VERILATOR_VERSION} installed"
}

step_verilator() {
    local current
    if current=$(verilator_version); then
        if [[ "$current" == "$REQUIRED_VERILATOR_VERSION" ]]; then
            ok "verilator ${current} already installed"
            return
        fi
        warn "verilator ${current} found, but ${REQUIRED_VERILATOR_VERSION} is required"
    else
        warn "verilator not found"
    fi
    if confirm "Build & install Verilator ${REQUIRED_VERILATOR_VERSION} from source? (~5 min, requires sudo)"; then
        install_verilator_from_source
    else
        warn "skipping verilator install — emulator TBs will not run until verilator ${REQUIRED_VERILATOR_VERSION} is on PATH"
    fi
}

# ---------- gtkwave ----------

step_gtkwave() {
    if command -v gtkwave >/dev/null 2>&1; then
        ok "gtkwave already installed: $(command -v gtkwave)"
        return
    fi
    warn "gtkwave not found"
    if confirm "Install gtkwave? (waveform viewer; required for 'make wave')"; then
        if [[ "$OS" == "linux" ]]; then
            sudo apt-get install -y gtkwave
        else
            if ! command -v brew >/dev/null 2>&1; then
                err "Homebrew is required to install gtkwave on macOS."
                return
            fi
            brew install --cask gtkwave
        fi
        ok "gtkwave installed"
    else
        warn "skipping gtkwave — 'make wave' will fail until installed"
    fi
}

# ---------- python venv + kernel ----------

step_python() {
    if ! command -v python3 >/dev/null 2>&1; then
        err "python3 not found. Ubuntu: sudo apt install python3 python3-venv python3-pip"
        exit 1
    fi
    if ! python3 -c 'import venv' 2>/dev/null; then
        err "python3 'venv' module missing. Ubuntu: sudo apt install python3-venv"
        exit 1
    fi
    if [[ ! -f "$REQ_FILE" ]]; then
        err "expected requirements file at $REQ_FILE"
        exit 1
    fi

    if [[ -d "$VENV_DIR" ]]; then
        log "reusing venv at $VENV_DIR"
    else
        log "creating venv at $VENV_DIR"
        python3 -m venv "$VENV_DIR"
    fi

    local pip="$VENV_DIR/bin/pip"
    log "upgrading pip"
    "$pip" install --upgrade pip --quiet
    log "installing notebook deps from $REQ_FILE"
    "$pip" install -r "$REQ_FILE" --quiet
    log "installing qick (editable) from $REPO_ROOT"
    "$pip" install -e "$REPO_ROOT" --quiet
    ok "Python deps installed"
}

step_kernel() {
    local py="$VENV_DIR/bin/python"
    log "registering Jupyter kernel '$KERNEL_NAME' (display: '$KERNEL_DISPLAY')"
    "$py" -m ipykernel install --user --name "$KERNEL_NAME" --display-name "$KERNEL_DISPLAY" >/dev/null
    ok "kernel registered — pick '$KERNEL_DISPLAY' in Jupyter (Kernel ▸ Change Kernel)"
}

# ---------- main ----------

main() {
    detect_os
    log "OS:        $OS"
    log "Repo root: $REPO_ROOT"
    echo

    step_verilator
    echo
    step_gtkwave
    echo
    step_python
    echo
    step_kernel
    echo

    cat <<EOF
${C_OK}Setup complete.${C_RST}

Next steps:
  1. Activate the venv (so Jupyter is on PATH):
       source "$VENV_DIR/bin/activate"
  2. Launch Jupyter:
       jupyter notebook emulator/notebooks/00_intro_emu_mirrored.ipynb
  3. In the notebook: Kernel ▸ Change Kernel ▸ "$KERNEL_DISPLAY"

You can re-run this script any time; it skips steps that are already done.
EOF
}

main "$@"
