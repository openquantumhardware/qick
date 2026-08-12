# QICK Emulator with WSL - Complete Setup Guide

This guide explains how to set up and use the QICK Emulator in a Windows Subsystem for Linux (WSL) environment.

## Table of Contents
- [Overview](#overview)
- [System Requirements](#system-requirements)
- [Installation Steps](#installation-steps)
- [Configuration](#configuration)
- [Usage](#usage)
- [Troubleshooting](#troubleshooting)
- [Tips and Best Practices](#tips-and-best-practices)

## Overview

The QICK Emulator allows you to develop and test QICK programs without requiring physical hardware. When running in WSL, you get:

- Full Linux environment on Windows
- Access to Verilator for hardware simulation
- Compatibility with QICK Python libraries
- Ability to use Jupyter notebooks for interactive development
- Seamless Windows-WSL file system integration

## System Requirements

- WSL 2 (not WSL 1)
- Ubuntu 20.04 LTS or newer (other Debian-based distros supported)
- Python 3.8 or higher
- Verilator 5.042

## Installation Steps

### Step 0: Install WSL 2 (from Windows)

**Important:** Before proceeding, WSL must be installed from Windows. Open **Windows Command Prompt or PowerShell** (as Administrator) and run:

```powershell
# Install WSL with Ubuntu
wsl --install -d Ubuntu

# Set WSL 2 as default
wsl --set-default-version 2

# Verify installation (should show WSL installed with Ubuntu)
wsl --list --verbose
```

After installation completes, **close PowerShell/CMD and open WSL** (search for "Ubuntu" in Start Menu or run `wsl` in any command prompt).


### WSL-Specific File System Access

WSL provides seamless access to Windows files:

| Path | Description |
|------|-------------|
| `/mnt/c/` | Windows C: drive |
| `/mnt/d/` | Windows D: drive |
| `/home/username/` | WSL Linux home directory |

**Recommendation:** Keep your QICK repository in the WSL file system for better performance:

```bash
# Good: In WSL file system
/home/username/projects/qick

# OK but slower: In Windows file system
/mnt/c/projects/qick
```

---

### Step 1: Verify and Optionally Update WSL (from within WSL)

Now that you're in the WSL terminal (Ubuntu), verify the installation and update the system:

```bash
# Check your Linux distribution
lsb_release -a

# Update package lists and upgrade existing packages
sudo apt update && sudo apt upgrade -y

# Install essential build tools
sudo apt install -y build-essential git wget curl
```

### Step 2: Clone the QICK Repository

Now that WSL is set up and updated, clone the QICK repository:

```bash
# Create a projects directory (or use any location you prefer)
mkdir -p ~/projects
cd ~/projects

# Clone the QICK repository from openquantumhardware
git clone https://github.com/openquantumhardware/qick.git

# Navigate to the repository
cd qick

# Checkout the Qick Emulator Branch
git checkout qick_emu_v1.1.0

# Verify the repository structure
ls -la
# You should see: qick_lib/, qick_demos/, emulator/, etc.
```

**Note:** Keep the repository in the WSL file system (`/home/username/projects/qick`) rather than `/mnt/c/` for better performance.

### Step 3: Install Build Dependencies and Python Dependencies

```bash
# Install build dependencies for Verilator (required for compiling emulator)
sudo apt install -y git help2man perl python3 make autoconf g++ flex bison ccache \
    libgoogle-perftools-dev numactl perl-doc libfl-dev zlib1g-dev liblzma-dev libpng-dev

# Install Python dependencies
sudo apt install -y python3 python3-pip python3-venv

# Verify Python installation
python3 --version
# Should show Python 3.8+

# Verify pip installation
pip3 --version
```

### Step 4: Compile QICK Emulator Submodules (includes Verilator)

The QICK repository includes Verilator as a submodule for building the emulator. First, initialize and update the submodules, then compile Verilator:

```bash
# Navigate to your QICK repository
cd ~/projects/qick

# Initialize and update submodules (includes Verilator)
git submodule update --init --recursive

# Verify submodules are initialized
ls -la emulator/submodules/
# You should see verilator and other submodules

# Compile Verilator from the submodule
cd emulator/submodules/verilator
autoconf
./configure
make -j$(nproc)

# Add Verilator to your PATH (add this to your ~/.bashrc for persistent access)
export VERILATOR_ROOT="$HOME/projects/qick/emulator/submodules/verilator"
export PATH="$VERILATOR_ROOT/bin:$PATH"

# Verify installation
verilator --version
# Should show: Verilator 5.042
```

**Note:** The QICK emulator uses Verilator from the `emulator/submodules/verilator` directory. You'll need to compile it first before running the emulator.

To make the Verilator PATH permanent, add it to your `~/.bashrc`:

```bash
# Add these lines to ~/.bashrc for persistent Verilator access
echo 'export VERILATOR_ROOT="$HOME/projects/qick/emulator/submodules/verilator"' >> ~/.bashrc
echo 'export PATH="$VERILATOR_ROOT/bin:$PATH"' >> ~/.bashrc

# Reload bashrc to apply changes
source ~/.bashrc
```

### Step 5: Install GTKWave (Waveform Viewer - Optional but Recommended)

```bash
# Install GTKWave for viewing simulation waveforms
sudo apt install -y gtkwave

# Or use the setup script which will offer to install it
```

### Step 6: Setup QICK Environment Using the Included Script

```bash
# Navigate to your QICK repository
cd ~/projects/qick

# Run the emulator setup script
./emulator/setup_emulator.sh
```

This script will:
- Create a Python virtual environment at `.venv` in the repo root
- Install all required Python packages (numpy, scipy, matplotlib, ipykernel, jupyter, tqdm)
- Install QICK in editable mode
- Register a Jupyter kernel named "qick-venv" (display: "Python (qick)")

After running the script, reload your shell or activate the virtual environment:
```bash
# Activate the virtual environment
source ~/projects/qick/.venv/bin/activate
```

## Usage

### Quick Start with Jupyter Notebook

The easiest way to get started is with the `00_intro_emu` notebook, which is a 1:1 port of the standard intro notebook that runs against the Verilator emulator:

```bash
# Activate the virtual environment
cd ~/projects/qick
source .venv/bin/activate

# Launch the notebook
jupyter notebook emulator/notebooks/00_intro_emu.ipynb
```

**Note:** The emulator notebook automatically detects whether you're running against hardware or the emulator based on the `soc` object type. Just use `prog.acquire()` or `prog.acquire_decimated(soc)` - they work seamlessly with both.

### Using Jupyter Notebooks

#### Method 1: VS Code with Remote - WSL Extension

1. Install the "Remote - WSL" extension in VS Code
2. Open your QICK repository in WSL (`~/projects/qick`)
3. Open `emulator/notebooks/00_intro_emu.ipynb`
4. Select the kernel: "Python (qick)" from the kernel picker

#### Method 2: Jupyter Notebook Server

```bash
# Activate virtual environment
cd ~/projects/qick
source .venv/bin/activate

# Start Jupyter server
jupyter notebook --no-browser --ip=0.0.0.0 --port=8888

# Access from Windows browser:
# http://localhost:8888
```

#### Method 3: Launch from WSL Terminal

```bash
cd ~/projects/qick
source .venv/bin/activate
jupyter notebook emulator/notebooks/
```

Available notebooks in `emulator/notebooks/`:
- `00_intro_emu.ipynb` - Emulator introduction (recommended for first-time users)
- `00_intro_emu_2sg.ipynb` - Example using 2 signal generators
- `HMC_clinic_feedback_emu.ipynb` - Demo notebook developed by HMC students


## Additional Resources

- [QICK Documentation](https://docs.qick.dev/)
- [QICK GitHub Repository](https://github.com/openquantumhardware/qick)
- [Verilator Documentation](https://verilator.org/guide/latest/)
- [WSL Documentation](https://docs.microsoft.com/en-us/windows/wsl/)

## License

Same as the main QICK project.