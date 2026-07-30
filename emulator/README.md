# QICK Emulator Software

## Overview

The QICK Emulator provides a software-based simulation environment for testing QICK (Quantum Instrument Control Kit) programs without requiring physical hardware. It uses Verilator to simulate the RFSoC (RF System-on-Chip) design, enabling development, testing, and debugging of quantum control sequences.

## Architecture

### Core Components

| Component | Description |
|-----------|-------------|
| `qick_emu.py` | Main emulator interface and orchestration entry point |
| `AxiRecorder` | Captures AXI-Lite transactions for replay in simulation |
| `AddrMap` | Maps IP register names to absolute AXI-Lite addresses |
| `MockIpDriver` | Mock drivers for QICK IP blocks (avg buffer, signal gen, tProc, etc.) |
| `QickEmu` | Drop-in replacement for `QickSoc` that records transactions |

### Emulation Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                        QICK Program                                  │
│  (asm_v2.py - AveragerProgramV2, AcquireProgramV2)                  │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      QickEmu (qick_emu.py)                          │
│  - QickConfig loading                                               │
│  - AddrMap construction                                             │
│  - Mock IP drivers                                                  │
│  - AxiRecorder tracking                                             │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    Testbench (Verilator)                            │
│  - AXI transaction replay (axi_replay.jsonl)                        │
│  - Memory files (pmem.mem, dmem.mem, wmem.mem)                      │
│  - Signal generator memory (sgmem_ch*.mem)                          │
│  - Output CSV files (dac_out.csv, avg_out.csv, dec_out.csv)         │
└─────────────────────────────────────────────────────────────────────┘
```

## Quick Start

### Basic Usage

```python
import sys
import pathlib
sys.path.insert(0, str(pathlib.Path.cwd().parent / 'qick_lib'))
sys.path.insert(0, str(pathlib.Path.cwd().parent / 'emulator' / 'software'))

from qick_emu import QickEmu
from qick.asm_v2 import AveragerProgramV2

# Load board configuration
CFG_PATH = pathlib.Path('config/qick_emu_config.json')
soc = QickEmu(str(CFG_PATH))

# Prepare emulator with output directory
OUT = pathlib.Path('artifacts/my_experiment')
OUT.mkdir(parents=True, exist_ok=True)
soc = soc.prepare_emu(memdir=OUT)

# Run your QICK program
iq_list = prog.acquire_decimated(soc, rounds=10)
```

### Complete Workflow

1. **Initialize Emulator**: Create a `QickEmu` instance with your board config JSON
2. **Prepare Emulator**: Call `prepare_emu(memdir=...)` to set up the output directory
3. **Run Program**: Execute your QICK program using `prog.acquire()` or `prog.acquire_decimated()`
4. **View Results**: Load DAC and readout data from CSV files in the output directory

## Configuration Files

### qick_emu_config.json

Board-specific configuration file that defines:
- IP instances and their base addresses
- Signal generator channels
- Readout channels
- tProcessor configuration

## Examples

See the following notebooks for usage examples:
- `emulator/notebooks/00_intro_emu.ipynb` - Basic emulator introduction
- `emulator/notebooks/RB_tProc_v2_emu.ipynb` - Randomized benchmarking with emulator

## License

Same as the main QICK project.