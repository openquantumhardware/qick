# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

This is the **QICK emulator fork** of the [QICK (Quantum Instrumentation Control Kit)](https://github.com/openquantumhardware/qick) project. The main focus here is building a Verilator-based hardware emulator that lets QICK programs run without a physical RFSoC board (ZCU111/ZCU216/RFSoC4x2). The `feature/qick-emulator-pr` branch is where active emulator development occurs.

## Key Tools Required

- **Verilator** (≥5.x) — RTL simulation compiler. Installed via Homebrew: `/opt/homebrew/bin/verilator`
- **GTKWave** — Waveform viewer for `.vcd` files
- **Python** (`qick` package) — `pip install -e .` from repo root installs the QICK library from `qick_lib/`
- **cocotb** — For the cocotb-based testbench in `emulator/software/cocotb/`

## Common Commands

### Signal Generator Testbench (primary active testbench)

```bash
cd emulator/models/axis_signal_gen_v6

# Compile (default top module: tb_siggen_dynamic_routed)
make verilate

# Run simulation
make sim

# View waveform
make wave

# Switch top module
make verilate TOP_MODULE=tb_verilator
make sim TOP_MODULE=tb_verilator
```

### Firmware IP Testbench (axis_signal_gen_v6)

```bash
cd firmware/ip/axis_signal_gen_v6/tb
make verilate
make sim
make wave
```

### cocotb Testbench (DAC model)

```bash
cd emulator/software/cocotb
make SIM=verilator
make SIM=verilator WAVES=1   # enable FST wave dump
```

### Python Package

```bash
pip install -e .    # installs qick from qick_lib/
```

### Init Git Submodules

```bash
git submodule update --init --recursive
```

## Architecture Overview

### Emulator Flow (Python side)

The emulator uses a two-phase approach:

1. **Prepare phase** — Run a QICK Python program against a mock SoC to capture all hardware interactions:
   - `QickEmu` (in `emulator/software/source/qick_emu.py`) loads a board config JSON (e.g. `emulator/notebooks/qick_config_216.json`)
   - `SocEmu` acts as a drop-in mock for `QickSoc`, intercepting register writes and memory exports
   - `AxiRecorder` logs all AXI-Lite transactions to `axi_replay.jsonl`
   - Memory files are written: `pmem.mem`, `dmem.mem`, `wmem.mem`, `sgmem_ch{N}.mem`
   - `AddrMap` handles IP base address assignment and register offset lookup

2. **Simulate phase** — Feed those files into a Verilator-compiled testbench:
   - Testbench reads memories via `$readmemh` and replays AXI transactions
   - Outputs CSV with analog sample data, which `QickEmu.plot_tb_csv()` can plot

Typical notebook usage (see `emulator/notebooks/EmulatorDemo.ipynb`):

```python
from qick_emu import QickEmu
emu = QickEmu("qick_config_216.json")
soc = emu.make_soc(memdir="emulator/")
prep = emu.prepare(prog, soc, memdir="emulator/")
csv = emu.run_verilated_mem_tb(mem_file=..., verilog_dir=..., ...)
emu.plot_tb_csv(csv)
```

### RTL Model Hierarchy

The Verilator simulation substitutes Xilinx-proprietary IPs with open behavioral models:

| Xilinx IP | Behavioral model |
|-----------|-----------------|
| `dds_compiler_0` | `emulator/models/sig_gen_dds/src/dds_behavioral_model.sv` |
| Block RAM (dual-port) | `emulator/models/bram_dp/bram_dp_behav.sv`, `bram_simple_dp_behav.sv` |
| FIFO | `emulator/models/fifo/fifo_behav.sv` |
| DAC output | `emulator/models/dac_model/model_dac.sv` |

The `EMULATOR` parameter in `firmware/ip/axis_signal_gen_v6/src/signal_gen.v` (line 36) gates between `dds_compiler` (hardware) and `dds_behavioral_model` (simulation).

### AXI Infrastructure

Testbenches use the [pulp-platform/axi](https://github.com/pulp-platform/axi) library (submoduled under both `emulator/submodules/pulp_platform/` and `firmware/pulp_platform/`) for AXI-Lite VIP master and interconnect.

The `axi_lite_interconnect_wrapper.sv` in `emulator/models/axis_signal_gen_v6/` wraps the pulp-platform AXI-Lite crossbar to route transactions to the signal generator DUT.

### Directory Map

```
emulator/
  models/
    axis_signal_gen_v6/   # Main SigGen testbench (Makefile here)
    dac_model/            # DAC behavioral model + testbench
    bram_dp/              # BRAM behavioral models
    fifo/                 # FIFO behavioral model
    sig_gen_dds/          # DDS behavioral model (replaces Xilinx dds_compiler_0)
    sby/                  # Formal verification (SymbiYosys)
  software/
    source/               # qick_emu.py (primary), emulator.py (older)
    cocotb/               # cocotb Makefile + test_dac_python.py
    emu_nb_interface/     # Phase 0 dev notebooks for soccfg/mem generation
  notebooks/              # EmulatorDemo.ipynb, AxiDemo.ipynb, HMC demos
  submodules/pulp_platform/  # Git submodules: axi, common_verification
firmware/
  ip/                     # QICK RTL IP sources (signal generators, readouts, tproc, etc.)
  pulp_platform/          # AXI + common_cells + common_verification submodules
  hdl/                    # Common HDL primitives (BRAM, FIFO XPM wrappers)
qick_lib/qick/            # The QICK Python package source
emulator/notebooks/qick_config_216.json  # Reference board config for ZCU216
```

### Key Python Classes (`emulator/software/source/qick_emu.py`)

- **`QickEmu`** — Entry point: loads board JSON, builds `AddrMap`, exposes `make_soc()` and `prepare()`
- **`SocEmu`** — Mock `QickSoc`; shims `set_nyquist`, `set_mixer_freq`, `config_avg`, `start_tproc`, `config_mux_readout`, etc.
- **`MockTProc`** — Mock tProc driver; supports `set_lfsr_cfg(mode, core=0)` (LFSR modes: 0=disabled, 1=free running, 2=step on s1 read, 3=step on s0 write)
- **`MockPFBReadout`** — Mock PFB readout driver; supports `set_out`, `set_freq_int`, `HAS_OUTSEL` (v2=True, v3/v4=False)
- **`AxiRecorder`** — Collects `AxiTxn` records; serializes to JSONL via `save_jsonl()`
- **`AddrMap`** — Maps `(fullpath, regname) → absolute address`; built from `qick_config.json` or loaded from file
- **`RegDef`** — Dataclass with `offset` and `width` for a single register

`emulator.py` in the same directory is an older/alternate implementation of `QickEmu` with some overlapping functionality. Prefer `qick_emu.py`.

### AddrMap Register Offsets (key entries in `default_addrmap_skeleton`)

| IP type | Register | Offset |
|---------|----------|--------|
| `axis_tproc_v2` / `qick_processor` | CTRL | 0x00 |
| | CFG | 0x04 |
| | CORE_CFG (LFSR) | 0x1C |
| `axis_pfb_readout_v4` | PFB_CH | 0x10 |
| | OUTSEL | 0x14 |
| | NCO_FREQ | 0x18 |
| | NCO_PHASE | 0x1C |

### `QickEmu.prepare()` — Memory Export Behaviour

- **`pmem.mem`** — compiled program binary (`print_pmem2hex`)
- **`wmem.mem`** — waveform parameter table (freq, gain, phase, length, conf per pulse)
- **`sgmem_ch{N}.mem`** — SG envelope table; only written for channels in `prog.gen_chs` (declared via `declare_gen`) that have `maxlen > 0` in the config, and only if the channel actually has envelope data (empty for `style="const"` pulses)
- **`axi_replay.jsonl`** — ordered AXI-Lite transactions to replay in the Verilator TB

`print_sg_mem` takes no file path argument — signature is `(sg_idx, gen_file)`. Always call with `gen_file=False` and capture stdout; never pass a path as a positional argument.

### tprocv2 Assembler Gotchas (`qick.tprocv2_assembler`)

`Assembler.str_asm2list(pstr)` is **fully isolated** — each call has its own `label_dict` pre-seeded with only `{'s15': 's15'}`. Consequences:
- Branch targets (`JUMP label`, `CALL label`) must be resolvable within the same string or injected as dicts via `prog.asm_inst({'CMD': 'JUMP'/'CALL', 'LABEL': label})` (resolved at link time by `list2asm`)
- `prog.label(label)` registers a label for link-time resolution; only call it when `addr != label` in the returned labels dict (pre-defined symbols have `key == value`)
- `style="const"` pulses produce no envelope data; `style="gauss"`/`"drag"`/`"arb"` pulses do

### Typical Notebook Setup Pattern (with LFSR)

```python
import importlib, qick_emu; importlib.reload(qick_emu)  # force reload after edits
from qick_emu import QickEmu

emu = QickEmu("qick_config_216.json")
soccfg = emu.soccfg

prog = MyProgram(soccfg, reps=1, cfg=config)
soc_emu = emu.make_soc(memdir="emulator/")
soc_emu.tproc.set_lfsr_cfg(2)   # if program uses LFSR random numbers
prep = emu.prepare(prog, soc_emu, memdir="emulator/")
```
