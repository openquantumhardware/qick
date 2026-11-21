#!/bin/bash
set -e

# Builds the single project-wide venv at <repository>/.venv (shared with the
# Sphinx docs build, see docs/Makefile). Run from firmware/fusesoc/, so the
# venv ends up two levels up.
VENV_DIR="../../.venv"

# Verificamos si el intérprete de Python puede cargar el módulo venv
if ! python3 -c "import venv" &> /dev/null; then
    echo "ERROR: Python 3 'venv' module is missing."
    echo "Please install the appropriate package for your distribution:"
    echo "  - Debian/Ubuntu: sudo apt install python3-venv"
    echo "  - RHEL/AlmaLinux: sudo dnf install python3-virtualenv (or python3-devel)"
    exit 1
fi

if [ -d "$VENV_DIR" ]; then
    echo "Virtual environment already exists at $VENV_DIR, reusing it..."
else
    echo "Creating virtual environment at $VENV_DIR..."
    python3 -m venv "$VENV_DIR"
fi

source "$VENV_DIR/bin/activate"
echo "Upgrading pip..."
pip install --upgrade pip

if [ -f "requirements.txt" ]; then
    echo "Installing FuseSoC requirements..."
    pip install -r requirements.txt
else
    echo "Warning: requirements.txt not found, skipping FuseSoC install."
fi

if [ -f "../../docs/requirements.txt" ]; then
    echo "Installing docs requirements (same venv builds the Sphinx docs)..."
    pip install -r ../../docs/requirements.txt
else
    echo "Warning: ../../docs/requirements.txt not found, skipping docs install."
fi

echo "! Virtual environment ready at $VENV_DIR"
