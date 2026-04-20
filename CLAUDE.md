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

### Signal Generator Testbench (IP-level)

Focused TB for the signal generator alone; useful for debugging the SG path in
isolation from the full QICK SoC.

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

### Full-QICK Emulator Testbench (Verilator)

This is the end-to-end testbench that runs a QickEmu-captured program plus replay
against the entire QICK SoC (tproc + signal gen + readout + avg_buffer).

```bash
cd firmware/testbench/qick_testbench
make verilate                # compile with TOP_MODULE=tb_qick_emu_verilator
make sim                     # runs with plusargs +EMU_DIR=... etc.
make wave
```

Two testbenches live under `src/tb/`:

- **`tb_qick_emu.sv`** — Vivado-compatible (keeps Xilinx `dds_compiler`, `axi_mst_0`
  VIP, `xpm_*`). Used when you want to compare against Vivado sim.
- **`tb_qick_emu_verilator.sv`** — Verilator version. Swaps Xilinx VIPs for the
  pulp-platform `AXI_LITE_DV` + `axi_test::axi_lite_rand_master`, and engages
  behavioral models via the `EMULATOR=1` param on `axis_signal_gen_v6`,
  `axis_dyn_readout_v1`, and `axis_avg_buffer`.

Plusargs the TB consumes (all optional, have defaults):

| Plusarg | Meaning |
|---------|---------|
| `+EMU_DIR=<path>` | Dir holding `pmem.mem`, `wmem.mem`, `dmem.mem`, `sgmem_ch{N}.mem`, `axi_replay.txt` |
| `+TEST_RUN_NS=<int>` | Run time between replay end and avg/dec buffer readout, in ns |
| `+RO_AVG_LEN=<int>` | Number of averaged I/Q samples to drain |
| `+RO_DEC_LEN=<int>` | Number of decimated I/Q samples to drain |

TB writes three CSVs into `EMU_DIR`:

| File | Columns | Produced per |
|------|---------|-------------|
| `dac_out.csv` | `time_ps, s0, s1, ..., s{N_DDS-1}` | sg_clk posedge when `axis_sg_dac_tvalid` |
| `avg_out.csv` | `time_ps, I, Q` | `m0_axis_buf_avg_tvalid` |
| `dec_out.csv` | `time_ps, I, Q` | `m1_axis_buf_dec_tvalid` |

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
   - `QickEmu.export_vivado_files(memdir)` post-processes `axi_replay.jsonl` into
     the flat `axi_replay.txt` (one `XXXXXXXX YYYYYYYY` hex pair per line) that
     both TBs consume, and prints correct localparam values (TPROC_BASE,
     SG_BASE_LO/HI, AVG_BASE_LO/HI) for the current board config.

2. **Simulate phase** — Feed those files into a Verilator-compiled testbench:
   - Testbench reads memories via `$readmemh`, replays AXI writes through the
     pulp-platform `axi_lite_rand_master`, and streams `sgmem_ch{N}.mem` through
     `sg_s0_axis` into the SG BRAM
   - Outputs CSVs (`dac_out.csv`, `avg_out.csv`, `dec_out.csv`) into `EMU_DIR`

Typical notebook usage (see `emulator/notebooks/EmulatorDemo.ipynb`,
`00_intro_emu.ipynb`):

```python
from qick_emu import QickEmu
emu = QickEmu("qick_config_216.json")
soc = emu.make_soc(memdir="emulator/")
prep = emu.prepare(prog, soc, memdir="emulator/")
emu.export_vivado_files(memdir="emulator/")   # generate axi_replay.txt + localparams

# … run Verilator TB from `firmware/testbench/qick_testbench/` with +EMU_DIR=emulator/ …

dec = emu.load_iq_decimated(emu_dir="emulator/", prog=prog)   # list[np.ndarray] per RO ch
avg = emu.load_iq_averaged (emu_dir="emulator/", prog=prog)   # same
emu.plot_tb_csv("emulator/dac_out.csv")
```

### RTL Model Hierarchy

The Verilator simulation substitutes Xilinx-proprietary IPs with open behavioral models:

| Xilinx IP | Behavioral model |
|-----------|-----------------|
| `dds_compiler_0` | `emulator/models/sig_gen_dds/src/dds_behavioral_model.sv` |
| Block RAM (dual-port) | `emulator/models/bram_dp/bram_dp_behav.sv`, `bram_simple_dp_behav.sv` |
| FIFO | `emulator/models/fifo/fifo_behav.sv` |
| DAC output | `emulator/models/dac_model/model_dac.sv` (also `model_DAC_ADC` defined inline in `tb_qick_emu_verilator.sv` for full-SoC loopback) |

The `EMULATOR` parameter gates between Xilinx IPs and behavioral models in:
- `firmware/ip/axis_signal_gen_v6/src/signal_gen.v:36` — dds_compiler → dds_behavioral_model
- `firmware/ip/axis_avg_buffer/src/*.sv` — xpm_memory → bram behavioral
- `firmware/ip/axis_dyn_readout_v1/src/*.sv` — dds_compiler → dds_behavioral_model

The Verilator TB (`tb_qick_emu_verilator.sv`) also needs a readout-path latency
pad (`RO_LATENCY_PAD` shift register) on the avg_buffer m1 input to compensate
for the ~178-sample latency gap between Xilinx RFDC+DDS+FIR and the behavioral
equivalents; without it the leading edge of the first pulse is clipped in
`dec_out.csv`.

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
  testbench/qick_testbench/
    Makefile              # Verilator build (TOP_MODULE=tb_qick_emu_verilator)
    src/tb/
      tb_qick.sv                # Original Vivado TB
      tb_qick_verilator.sv      # Reference Verilator TB (formatting template)
      tb_qick_emu.sv            # Vivado-compatible emu TB (drives AXI from QickEmu files)
      tb_qick_emu_verilator.sv  # Verilator emu TB (behavioral models + PULP VIP)
qick_lib/qick/            # The QICK Python package source
emulator/notebooks/qick_config_216.json  # Reference board config for ZCU216
```

### Key Python Classes (`emulator/software/source/qick_emu.py`)

- **`QickEmu`** — Entry point: loads board JSON, builds `AddrMap`, exposes:
  - `make_soc(memdir)` — returns a `SocEmu` configured for this board
  - `prepare(prog, soc, memdir)` — captures AXI/mem files for a QICK program
  - `export_vivado_files(memdir)` — JSONL replay → flat `axi_replay.txt` + prints localparams
  - `run_verilated_mem_tb(...)` — one-shot wrapper that compiles & runs the TB
  - `load_iq_decimated(emu_dir, prog, align_to_signal=False)` — parse `dec_out.csv` per channel; reshapes to match `prog.acquire_decimated()` output
  - `load_iq_averaged(emu_dir, prog, length_norm=True)` — parse `avg_out.csv` per channel; reshapes to match `prog.acquire()` output
  - `plot_tb_csv(csv)` — matplotlib plot of DAC samples from `dac_out.csv`
- **`SocEmu`** — Mock `QickSoc`; shims `set_nyquist`, `set_mixer_freq`, `config_avg`, `start_tproc`, `config_mux_readout`, etc.
- **`MockTProc`** — Mock tProc driver; supports `set_lfsr_cfg(mode, core=0)` (LFSR modes: 0=disabled, 1=free running, 2=step on s1 read, 3=step on s0 write)
- **`MockPFBReadout`** — Mock PFB readout driver; supports `set_out`, `set_freq_int`, `HAS_OUTSEL` (v2=True, v3/v4=False)
- **`AxiRecorder`** — Collects `AxiTxn` records; serializes to JSONL via `save_jsonl()`
- **`AddrMap`** — Maps `(fullpath, regname) → absolute address`; built from `qick_config.json` or loaded from file
- **`RegDef`** — Dataclass with `offset` and `width` for a single register

`emulator.py` in the same directory is an older/alternate implementation of `QickEmu` with some overlapping functionality. Prefer `qick_emu.py`.

Docstrings in `qick_emu.py` follow the NumPy style used elsewhere in `qick_lib/`
(Parameters / Returns / Raises sections).

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

### ZCU216 Absolute Address Map

When `AddrMap` is built from `qick_config_216.json`, IP instances land at
sequential 0x10000 blocks starting at 0x40000000. The `tb_qick_emu*.sv`
localparams used by `route_and_write` come from this layout:

| Range | Contents |
|-------|----------|
| 0x40000000–0x4000FFFF | `ddr4_buf` |
| 0x40010000–0x4001FFFF | `mr_buf` |
| 0x40020000–0x4011FFFF | 16 signal-gen IPs (`SG_BASE_LO=0x40020000`, `SG_BASE_HI=0x40120000` exclusive) |
| 0x40120000–0x4012FFFF | first readout IP |
| 0x40130000–0x4025FFFF | 10 avgbuf IPs (`AVG_BASE_LO=0x40130000`, `AVG_BASE_HI=0x40260000` exclusive) |
| 0x40260000–0x4026FFFF | `qick_processor` (`TPROC_BASE=0x40260000`) |

**`AVG_BASE_HI == TPROC_BASE` is intentional**: AVG_BASE_HI is an exclusive upper
bound, so the last avgbuf ends at 0x4025FFFF and tproc starts cleanly at
0x40260000. The `route_and_write` task checks TPROC exact-range first, then SG
range, then AVG range — don't reorder those checks.

### `QickEmu.prepare()` — Memory Export Behaviour

- **`pmem.mem`** — compiled program binary (`print_pmem2hex`)
- **`dmem.mem`** — data memory seed
- **`wmem.mem`** — waveform parameter table (freq, gain, phase, length, conf per pulse)
- **`sgmem_ch{N}.mem`** — SG envelope table; only written for channels in `prog.gen_chs` (declared via `declare_gen`) that have `maxlen > 0` in the config, and only if the channel actually has envelope data (empty for `style="const"` pulses)
- **`axi_replay.jsonl`** — ordered AXI-Lite transactions in JSON-lines
- **`axi_replay.txt`** — flat `AAAAAAAA DDDDDDDD` hex pairs produced by
  `export_vivado_files()`; this is what the SV TB reads (the JSONL is kept for
  Python-side inspection)

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
soc_emu.tproc.set_lfsr_cfg(2)          # only if program uses LFSR random numbers
prep = emu.prepare(prog, soc_emu, memdir="emulator/")
emu.export_vivado_files(memdir="emulator/")  # writes axi_replay.txt, prints localparams
```

Then from a shell, with `EMU_DIR` pointing at the memdir used above:

```bash
cd firmware/testbench/qick_testbench
make verilate
obj_dir/Vtb_qick_emu_verilator \
  +EMU_DIR=<abs-path-to-emulator/> \
  +TEST_RUN_NS=5000 +RO_AVG_LEN=100 +RO_DEC_LEN=200
```

Back in the notebook:

```python
dec = emu.load_iq_decimated("emulator/", prog)
avg = emu.load_iq_averaged ("emulator/", prog)
```
