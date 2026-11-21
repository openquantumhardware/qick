# QICK Emulator

## Overview

The QICK Emulator lets you develop and test [QICK](https://github.com/openquantumhardware/qick) programs **without a physical RFSoC board**. It runs the same firmware IP (signal generators, readouts, tProcessor, etc.) as a cycle-accurate [Verilator](https://www.veripool.org/verilator/) simulation, and exposes it to Python behind a drop-in replacement for `QickSoc`. This means existing QICK programs work almost unchanged: `prog.acquire()` and `prog.acquire_decimated()` automatically detect whether `soc` is real hardware or the emulator.

It is meant for:

- Learning QICK / writing and debugging programs with no hardware on hand.
- Regression-testing firmware or software changes in CI.
- Demos, tutorials, and workshops (e.g. Google Colab).

### Architecture

| Component | Description |
|-----------|-------------|
| `qick_emu.py` | Main emulator interface and orchestration entry point |
| `AxiRecorder` | Captures AXI-Lite transactions for replay in simulation |
| `AddrMap` | Maps IP register names to absolute AXI-Lite addresses |
| `MockIpDriver` | Mock drivers for QICK IP blocks (avg buffer, signal gen, tProc, etc.) |
| `QickEmu` | Drop-in replacement for `QickSoc` that records transactions |

### Emulation flow

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
│  - AXI transaction replay (axi_replay.jsonl, hex format)              │
│  - Memory files (pmem.mem, dmem.mem, wmem.mem)                      │
│  - Signal generator memory (sgmem_ch*.mem)                          │
│  - Output CSV files (dac_out.csv, avg_out.csv, dec_out.csv)         │
└─────────────────────────────────────────────────────────────────────┘
```

Each time a program calls `acquire()` / `acquire_decimated()` against the emulator, `qick_emu.py` writes out the recorded AXI transactions and memory contents, invokes `make verilate` / the compiled testbench (`emulator/testbench/`) via Verilator (the design is built from the fusesoc cores, see [How the design is built](#how-the-design-is-built)), and parses the resulting CSVs back into the same data shape a real board would return.

## How the design is built

`make verilate` (in `emulator/testbench/`) runs `fusesoc ... run --target verilate --setup qick:emulator:qickemu_harness` and then Verilator on the file list it writes, in `emulator/testbench/build/` (ignored by git).

- `qick:emulator:qickemu_harness` -> `qick:emulator:qick_dut` -> the `qick:ip` cores of the ported IPs (tProc v2, signal generators, readouts, PFB v4, buffers). Same RTL as the board builds.
- The vendor blocks that Verilator cannot read are replaced by behavioural models of the same name, as the `.xci` are in the simulation of the cores: `qick:emulator:xpm_memory_tdpram`, `xpm_fifo_sync`, `xpm_fifo_async` (checked against the XPM macros clock by clock) and `ssr_8x64` (the FFT of the PFB; a real-arithmetic model, within 20 counts of the System Generator core). The DDS and FIR models of the cores were checked against the real IPs; see the READMEs of the cores and `regression/README.md`.
- `regression/` holds the programs that were run through the emulator and the md5 of their results: compare with `baseline_fusesoc_md5.txt` after a change.
- `models/` is the set of behavioural models that the HRL emulator used before; the build does not use them any more.

## Running in Google Colab (no install)

Every notebook here (and in [`tutorial/`](tutorial/)) can be opened directly in Google Colab — nothing to install on your machine. Click the notebook's **"Open in Colab"** badge, then run its first cell, **"Colab Setup"**. That cell:

1. Clones this repo (`openquantumhardware/qick`, branch `merge-hrl-main`) into the Colab runtime.
2. Installs Verilator 5.042 — from a prebuilt binary in a few seconds if available, falling back to a ~10-15 minute source build otherwise.
3. Installs the Python dependencies needed to run `QickEmu`.

Everything after that cell is a normal QICK notebook — `prog.acquire_decimated(soc)` and friends work exactly as described below. Locally (i.e. with the `qick-venv` kernel from the setup below), that same cell detects it isn't running in Colab and does nothing.

Colab assigns a fresh VM per runtime, so the first cell's setup cost is paid once per session, not once per notebook — reopening another notebook in the *same* connected runtime reuses what's already installed and just updates the repo checkout.

**Want to run locally instead?** Read on.

## Requirements

Running the emulator means **compiling a Verilog testbench with Verilator**, not just installing Python packages. Most first-run failures come from the C++/Verilator toolchain, not from `qick` itself. Requirements below are grouped so you can tell which ones matter for which failure.

### 1. fusesoc

The sources of the design are not in this directory: `emulator/testbench/Makefile` asks [fusesoc](https://fusesoc.readthedocs.io) for the core `qick:emulator:qickemu_harness` (cores in `firmware/fusesoc/cores/`), which resolves the harness, the device under test and the `qick:ip` cores of the ported IPs, and writes the file list for Verilator. `fusesoc` is in `requirements.txt` (`pip install fusesoc`); `setup_emulator.sh` installs it with the rest. There are no git submodules to fetch any more (the PULP AXI library is not used: the AXI-Lite master is the testbench master of `axi4_lite_if`).

### 2. Verilator — the repository's version, built from source

The testbench (`emulator/testbench/Makefile`) is compiled with `--binary --timing` with the Verilator the whole
repository uses: `VERILATOR_VERSION` of `firmware/fusesoc/Makefile` (5.052; the regression gives
the same md5 with 5.042, 5.046 and 5.052). Older releases may fail on the SystemVerilog the cores use.

**The Verilator that ships in apt/brew is almost always too old and will fail.** For example, Debian/Ubuntu's packaged `verilator` (as of this writing, 5.020) errors out with:

```
%Error: Unknown warning specified: -Wno-BADVLTPRAGMA... Suggested alternative: '-Wno-BADSTDPRAGMA'
%Error: Exiting due to too many errors encountered; --error-limit=1
make: *** [Makefile:146: verilate] Error 1
```

`make -C firmware/fusesoc install_verilator` (or `make setup_environment` there, or `../setup_emulator.sh`, see
below) builds it into `~/.local/verilator-5.052` without root (~5 minutes), and `emulator/testbench/Makefile` puts
it first on `PATH` when it is there. Verify with:

```bash
~/.local/verilator-5.052/bin/verilator --version   # "Verilator 5.052 ..."
```

Build dependencies on Debian/Ubuntu: `git help2man perl python3 make autoconf g++ flex bison ccache libgoogle-perftools-dev numactl perl-doc libfl-dev zlib1g-dev`.

### 3. Python 3.8+

A virtual environment with:

- the packages in `requirements.txt` (`numpy`, `scipy`, `matplotlib`, `ipykernel`, `jupyter`, `tqdm`)
- `qick` itself, installed editable from the repo root (`pip install -e .`)

### 4. GTKWave (optional)

Only needed for `make wave` (viewing `.vcd` waveform dumps). Not required to run notebooks.

### One-shot setup

From the repo root:

```bash
./emulator/setup_emulator.sh
```

This will (each step is idempotent/skippable, re-run anytime):

1. Offer to build & install the repository's Verilator from source into `~/.local` (no `sudo`).
2. Offer to install GTKWave.
3. Create a `.venv` at the repo root, install `requirements.txt` + `qick` (editable).
4. Register a Jupyter kernel named `qick-venv` (display name "Python (qick)").

After it finishes, select the **"Python (qick)"** kernel in your notebook (VS Code: "Select Kernel" → pick the `.venv` interpreter; classic Jupyter: `Kernel ▸ Change Kernel`). Using a different/system Python environment is the other common source of failures, since it likely won't have `qick` installed or will pick up a stray `verilator` from `PATH`.

## Quick start

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

### Complete workflow

1. **Initialize Emulator**: Create a `QickEmu` instance with your board config JSON
2. **Prepare Emulator**: Call `prepare_emu(memdir=...)` to set up the output directory
3. **Run Program**: Execute your QICK program using `prog.acquire()` or `prog.acquire_decimated()`
4. **View Results**: Load DAC and readout data from CSV files in the output directory

The first `acquire()`/`acquire_decimated()` call triggers a Verilator build (`make verilate`) of the testbench, which takes a minute or two; subsequent runs reuse the compiled binary.

## Configuration files

`qick_emu_config.json` is the board-specific configuration file that defines IP instances and base addresses, signal generator channels, readout channels, and tProcessor configuration.

You may see a warning like:

```
QICK library version mismatch: 0.2.366 remote (the board), 0.2.88 local (the PC)
    This may cause errors, usually KeyError in QickConfig initialization.
```

This compares the firmware config's recorded `qick` version against your installed `qick` version. It's informational, not fatal, on its own — but if you do hit a `KeyError` during `QickConfig` init, it's the first thing to check.

### How `qick_emu_config.json` is built (and why there's no generator script)

**This subsection is entirely optional and only matters if you want to *change* what the emulator models.** QICK is designed around the ZCU216 board with the QICK box analog front-end — that's the reference hardware, and `qick_emu_config.json` already models (a reduced subset of) exactly that. For normal use — the tutorials, testing your own programs, CI — there is nothing to configure here; skip this subsection.

It's included for the rare case where you specifically want the emulator to represent *different* hardware.

`qick_emu_config.json` is **hand-written**, not derived automatically from a board's bitstream. Its own `_comment` field says as much: it was manually adapted from a real ZCU216 `soc.get_cfg()` dump, then trimmed down to only the IP blocks the Verilator testbench (`emulator/testbench/QICKEmu_harness.sv`, plus the fixed source list in `emulator/testbench/Makefile`) actually instantiates:

- **3 signal generators**: two `axis_signal_gen_v6` (full-speed) and one `axis_sg_mux8_v1` (8-tone mux). There is no interpolated (`axis_sg_int4_v2`) or mixer-mux (`axis_sg_mixmux8_v1`) generator in this testbench.
- **6 readout instances**: `axis_dyn_readout_v1`, `axis_readout_v2`, and four `axis_pfb_readout_v4` (the PFB has 8 outputs; the testbench wires 4). There is no `axis_readout_v3` "fast dynamic" readout.
- **No DDR4 buffer** (see the DDR4 note in `00_intro_emu.ipynb`).
- **Only readout indices 0–3 have working avg/dec CSV capture.** The harness only wires up `avg0..avg3_csv_fd` / `dec0..dec3_csv_fd` (see `QICKEmu_harness.sv`); PFB readouts 4 and 5 are addressable over AXI but `acquire()` / `acquire_decimated()` will raise `FileNotFoundError: No dec_out CSV for ro_ch=...` if you use them. In practice this means only 2 of the 4 PFB channels are usable per run — see `MUXRO_CH = [2, 3]` in `01_gens-and-readouts.ipynb` and `07_Advanced_Generators_And_Readouts_emu.ipynb`.

**What this means if you have different hardware (e.g. an RFSoC4x2) and want the emulator to model it:** you can't just point the emulator at a different config JSON the way you'd point `QickSoc` at a different `.bit` file. The config has to describe *exactly* what's wired up in the SystemVerilog testbench, and the testbench models one fixed, hand-built topology (loosely based on a subset of ZCU216). Getting the emulator to represent a different board's channel layout is a real firmware/testbench engineering task, not a config change:

1. Extend `QICKEmu_harness.sv` (and the `VERILOG_SOURCES` list in `emulator/testbench/Makefile`) to instantiate the target board's actual generator/readout IP blocks and wire them into `axi_router_lite`.
2. Hand-write a new config JSON (same schema as `qick_emu_config.json`) describing that topology — base addresses, IP types, register layouts — matching what you just wired up in step 1.

There's no tooling in this repo to automate either step today.

## Notebooks

- `00_intro_emu.ipynb` — 1:1 port of the standard `00_intro.ipynb`, running against the emulator. Start here.
- `00_intro_emu_2sg.ipynb` — same idea, using 2 signal generator outputs.
- `01_gens-and-readouts.ipynb` — exercises all current generator and readout types.
- `HMC_clinic_feedback_emu.ipynb` — real-time feedback demo (arithmetic/branching logic, parametric pulses, LFSR-based random numbers).
- `loopback_latency.ipynb` — the DAC -> ADC latency (decimated readout and multi-rate buffer) measured with one program that runs on the emulator or, with `ON_BOARD = True`, on a board, to compare them.

### `tutorial/` — emulator port of the on-hardware QICK tutorial series

`tutorial/` mirrors the numbered tutorial notebooks in [`docs/source/tutorials/`](docs/source/tutorials/) (`00_Getting_Started.ipynb` through `07_Advanced_Generators_And_Readouts.ipynb`), adapted to run against `QickEmu` instead of a physical board. Each notebook says in its intro cell exactly what was adapted or skipped and why — the two recurring reasons are:

- **`qick_emu_config.json` models a reduced, fixed set of IP blocks** — no interpolated generator, no mixer-mux generator, no fast-dynamic readout, no DDR4 buffer, and only 2 of the 4 PFB mux readout channels have working CSV capture (readout indices 4/5 exist on the AXI bus but `acquire()`/`acquire_decimated()` can't read them back — see [Configuration files](#configuration-files) above).
- **`get_raw()` always returns `None`** against `QickEmu` — it isn't wired to the CSV-based capture pipeline, only to real hardware's raw-buffer reads. Sections built around per-shot raw data (IQ-offset histograms, shot-to-shot phase tracking) are adapted or skipped accordingly.
- **Large sweeps are shrunk.** Verilator simulates at roughly 10–15us of device time per wall-clock second, so `reps`/`steps` values that are cheap on real hardware (e.g. a 1001-point x 100-rep calibration sweep) can take on the order of an hour here. Every sweep is shrunk to keep the notebook tractable, with a note where it happens. The simulation is also fully deterministic given fixed inputs, so extra `rounds`/`reps` don't average down noise the way they do on hardware.

Chapters 8+ of the on-hardware series (DDR4/MR hardware buffers, multi-board sync, streaming, custom firmware, XCOM) aren't ported — they need features this emulator config doesn't model or physical multi-board hardware.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `make verilate failed` with Verilator errors on `--binary`/`--timing` or on the SystemVerilog | System-packaged Verilator is too old | `make -C firmware/fusesoc install_verilator` — see [Requirements](#2-verilator--the-repositorys-version-built-from-source) |
| `make verilate` fails with `fusesoc: command not found` or `Could not find core ...` | fusesoc not installed in the active environment | `pip install -r emulator/requirements.txt` (fusesoc), or `make verilate FUSESOC=/path/to/fusesoc` |
| Notebook kernel can't `import qick` / `qick_emu` | Wrong Python environment selected | Select the `qick-venv` kernel created by `setup_emulator.sh`, not the system Python |
| `QICK library version mismatch` warning | Firmware config was generated with a different `qick` version than what's installed locally | Usually harmless; if you get a `KeyError` in `QickConfig` init, sync versions |

More platform-specific notes (including a full WSL walkthrough) are in [`docs/README_WSL.md`](docs/README_WSL.md).

## License

Same as the main QICK project.
