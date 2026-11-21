# QICK Firmware

This directory contains the FPGA firmware for the
[QICK (Quantum Instrumentation Control Kit)](https://github.com/openquantumhardware/qick) project.

For a full description of the firmware architecture see the
[QICK documentation](https://qick-docs.readthedocs.io/latest/firmware/index.html).

**Documentation index: [docs/README.md](docs/README.md)** (what to read for each task).

---

## Repository structure

```
firmware/
├── Hog/              HOG submodule — build system
├── Top/              HOG project definitions (source of truth for each project)
│   ├── 111/          ZCU111 projects
│   ├── 2x4/          RFSoC 2x4 projects
│   ├── 216/          ZCU216 projects
│   └── 4x2/          RFSoC4x2 projects
├── rtl_lib/          Source of truth for shared RTL modules
│   ├── axi/          AXI4/AXI4-Lite/AXI4-Stream utilities
│   ├── cdc/          Clock domain crossing modules
│   ├── constraints/  Shared XDC constraint files
│   ├── ctrl/         Control-plane blocks (streamer, ramp/DDS control, etc.)
│   ├── dsp/          DSP datapath blocks (signal gen, IQ correction, etc.)
│   ├── encoders/     Link-layer / 8b10b / framing blocks
│   ├── interfaces/   SystemVerilog interfaces (AXI, BRAM, etc.)
│   ├── ip/           Top-level packaged-IP RTL (axis_tprocv1.sv, etc.)
│   ├── math/         ALUs and other math blocks
│   ├── mem/          Memories, FIFOs, register files
│   ├── misc/         Miscellaneous shared blocks
│   ├── pkg/          Shared packages (qick_pkg.sv, tproc_pkg.sv, alu_pkg.sv, ...)
│   ├── processors/   tProcessor cores (tprocv1.sv, ...)
│   ├── utils/        Utility modules (FIFOs, buffers, command handlers)
│   └── xci/          Xilinx-IP (.xci) sources used by dsp/ behavioural pairs
├── ip/               Custom QICK IP cores (use modules from rtl_lib)
├── docs/             Documentation: user/, developer/, process/ (start at docs/README.md)
├── Projects/         Vivado generated projects — gitignored, recreated with HOG
├── bin/              Bitfile outputs (.bit + .hwh named by Git SHA) — gitignored
└── fusesoc/          IP development and simulation environment
```

---

## Quick start — build a standard bitfile

### Prerequisites

- Vivado 2023.1 installed and licensed for your board.
- Git with submodule support.
- Python 3.8+ with venv (for FuseSoC simulation).

### 1. Clone the repo

```bash
git clone --recursive <url_of_the_repository>
cd <repository>/firmware
```

The `--recursive` flag is required to initialize the HOG submodule.
If you already cloned without it:

```bash
git submodule update --init --recursive
```

### 2. Set up the Python environment (for FuseSoC simulation, optional)

```bash
cd fusesoc
make setup_environment
cd ..
```

### 3. Pick your project

**`Top/<board>/<project>/` is the only place where a firmware project lives**, for development and for a release alike. There is no
separate `projects/` directory: the names `Top` (the project definitions) and `Projects` (what Vivado generates from them, ignored by git) are
Hog's and cannot be changed. A project directory holds the block design (`bd_<vivado version>.tcl`), the constraints, `hog.conf` (part, board
part, IP repository, strategies), `list/` and `proj.tcl`. Two ways to build the same directory:

- **With Hog** (development; the fusesoc tools package the IPs in `pre-creation.tcl`): `./Hog/Do CREATEWORKFLOW <board>/<project>`.
- **Without Hog** (a release: the packaged IPs are in `ip/`, nothing else is needed): from `firmware/`,
  `vivado -source Top/<board>/<project>/proj.tcl`. With no open project, `proj.tcl` creates it in `Projects/<board>/<project>` from `hog.conf`
  and `list/constraints.con`, so the part and the constraints have one source for both ways. Then run synthesis and implementation.

Projects are organized by board type in `Top/`:

| Board | Project path | Vivado version |
|-------|-------------|----------------|
| ZCU216 | `Top/216/tpv2_std` | 2023.1 |
| ZCU216 (demo) | `Top/216/tpv2_demo` | 2023.1 |
| ZCU111 | `Top/111/tpv2_std` | 2023.1 |
| RFSoC4x2 | `Top/4x2/tpv2_std` | 2023.1 |
| ZCU111 (RFBv1) | `Top/111/tpv1_rfbv1_std` | 2023.1 |
| ZCU111 (RFBv2) | `Top/111/tpv1_rfbv2_std` | 2023.1 |
| RFSoC 2x4 | `Top/2x4/tpv2_std`, `Top/2x4/tpv1_std` | 2023.1 |

The names of the old `firmware/projects/` directory of the public repository map to these paths:

| Old `projects/` name | `Top/` path |
|---|---|
| `qick_tprocv1_111_standard` | `Top/111/tpv1_std` |
| `qick_tprocv1_111_rfbv1_standard` | `Top/111/tpv1_rfbv1_std` |
| `qick_tprocv1_111_rfbv2_standard` | `Top/111/tpv1_rfbv2_std` |
| `qick_tprocv1_216_standard` | `Top/216/tpv1_std` |
| `qick_tprocv1_4x2_standard` | `Top/4x2/tpv1_std` |
| `qick_tprocv2_111_standard` | `Top/111/tpv2_std` |
| `qick_tprocv2_216_standard` | `Top/216/tpv2_std` |
| `qick_tprocv2_216_rfbv2_standard` | `Top/216/tpv2_std_rfbv2` |
| `qick_tprocv2_216_demo` | `Top/216/tpv2_demo` |
| `qick_tprocv2_4x2_standard` | `Top/4x2/tpv2_std` |
| `qick_tprocv1_2x4_standard` | `Top/2x4/tpv1_std` |
| `qick_tprocv2_2x4_standard` | `Top/2x4/tpv2_std` |

### 4. Recreate the Vivado project

```bash
./Hog/Do CREATE 216/tpv2_std
```

This recreates the project from scratch in `firmware/Projects/`.
Open it in Vivado to inspect the design:

```bash
vivado Projects/tpv2_std/tpv2_std.xpr
```

### 5. Build the bitfile

```bash
./Hog/Do W 216/tpv2_std
```

The bitfile appears in `firmware/bin/`.

---

## Saving changes to the block design

After modifying the block design in Vivado, export the TCL script before closing:

```
File → Export → Export Block Design → save to Top/<project_path>/bd_2023-1.tcl
```

For example:
```
File → Export → Export Block Design → save to Top/216/tpv2_std/bd_2023-1.tcl
```

Then commit it:

```bash
git add Top/216/tpv2_std/bd_2023-1.tcl
git commit -m "Update BD with <description of change>"
```

> **IMPORTANT**: HOG only processes committed files. Always commit before running `./Hog/Do W`.

---

## HOG commands

| Command | Description |
|---------|-------------|
| `./Hog/Do CREATE <project_path>` | Recreate Vivado project from scratch |
| `./Hog/Do W <project_path>` | Full build: synthesis + implementation + bitstream |
| `./Hog/Do S <project_path>` | Synthesis only |
| `./Hog/Do I <project_path>` | Implementation only |
| `./Hog/Do B <project_path>` | Bitstream only |

**Note:** `<project_path>` is relative to `firmware/Top/`. Examples:
- `216/tpv2_std`
- `111/tpv2_std`
- `4x2/tpv2_std`

---

## IP development and simulation with FuseSoC

The `fusesoc/` directory provides a [FuseSoC](https://fusesoc.readthedocs.io)-based
environment for developing and simulating individual IP cores.

RTL sources are organized as:
- `rtl_lib/` — Shared modules (AXI, CDC, interfaces, utilities)
- `ip/` — QICK IP cores that use modules from `rtl_lib`

> **In progress**: `qick:ip:qick_processor` (tProcessor v2) is being ported
> from `firmware/ip/qick_processor/src/` into `rtl_lib/` bottom-up, the same
> way `axis_tprocv1` was. Its `.core` file describes the target layout but
> `hdl/` is not populated yet, so `make sim IP=qick_processor` does not work
> until that port is further along.

### Available Makefile commands in `fusesoc/`

| Command | Description |
|---------|-------------|
| `make setup_environment` | Initialize submodules, create venv, install dependencies, check Verilator (needed for `make coverage`) |
| `make sim IP=<ip_name>` | Run simulation for a specific IP |
| `make sim_svunit` | `make sim` on every core with a test target (JUnit reports in `report_svunit/`) |
| `make coverage IP=<ip_name>` | DUT line+toggle coverage via Verilator (see [docs/developer/COVERAGE.md](docs/developer/COVERAGE.md)) |
| `make lint IP=<ip_name>` | Run linter on an IP |
| `make list-cores` | List all available cores |
| `make core-info CORE=<core_name>` | Show detailed core information |
| `make deps IP=<ip_name>` | Show dependencies of an IP |
| `make package IP=<ip_name>` | Package an IP for Vivado Block Design |

**Examples:**
```bash
cd firmware/fusesoc
source venv/bin/activate

# Simulate an IP
make sim IP=tpv2_alu

# Run all tests
make sim_svunit

# Package an IP for Vivado
make package IP=xcom RESOLVE_DEPS=1
```

For detailed FuseSoC documentation, see `fusesoc/README.md`.

---

## Two workflows: HOG vs FuseSoC

| Task | Tool | Command |
|------|------|---------|
| Full bitstream build | HOG | `./Hog/Do W 216/tpv2_std` |
| Single IP simulation | FuseSoC | `cd fusesoc && make sim IP=tpv2_alu` |
| Unit tests | FuseSoC | `cd fusesoc && make sim_svunit` |
| IP packaging | FuseSoC | `cd fusesoc && make package IP=xcom` |

The RTL sources are shared:
- `rtl_lib/` → common modules used by both HOG and FuseSoC
- `ip/` → QICK IP cores

---

## Troubleshooting

**"Git working directory not clean" critical warning**
HOG cannot embed a valid SHA if there are uncommitted changes. Commit all
files under `Top/<project>/` before running `./Hog/Do W`.

**"Invalid Top Module" dialog when opening in Vivado**
Verify that `post-creation.tcl` exists and is committed. It should contain:
```tcl
set_property top "d_1_wrapper" [get_filesets sources_1]
```

**VHDL modules not found in Block Design**
Make sure VHDL files are listed in `list/src.src` with the library name:
```
../../hdl/lo_spi_mux_v2.vhd work
```

**HOG ignores my files**
HOG only processes committed files. Run `git status` and commit any untracked
files in `Top/<project>/` before running HOG commands.

---
