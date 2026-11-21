This directory provides a [FuseSoC](https://fusesoc.readthedocs.io)-based
environment for developing and simulating QICK IP cores independently of the
full Vivado project.

## How it works

RTL sources live in `../rtl_lib/`, organized by category. FuseSoC cores in
`cores/` are thin wrappers: each core has a `hdl/<name>.sv` symlink pointing to
the real source in `rtl_lib/<category>/`, a `.core` description, and SVUnit
testbenches. Cores depend on `qick:common:sim_base` (which sets up include
paths) and, when needed, on shared packages (`qick:pkg:*`).

```
firmware/
├── rtl_lib/                      ← Shared RTL (SOURCE OF TRUTH), by category
│   ├── axi/
│   ├── cdc/
│   ├── dsp/
│   ├── interfaces/
│   ├── ip/                       ← top-level IP RTL (e.g. axis_signal_gen_v6.sv)
│   ├── math/
│   ├── mem/
│   ├── misc/
│   ├── pkg/                      ← packages (alu_pkg, tproc_pkg, qick_pkg, ...)
│   ├── processors/               ← tprocv1.sv, ...
│   └── utils/
└── fusesoc/
    ├── cores/
    │   ├── ip/                   ← packaged IP cores (with rdl/, driver/)
    │   │   ├── axis_constant_iq/
    │   │   ├── axis_signal_gen_v6/
    │   │   ├── axis_tprocv1/
    │   │   └── ...
    │   ├── lib/                  ← library cores, by category
    │   │   ├── axi/
    │   │   ├── cdc/
    │   │   ├── dsp/
    │   │   ├── interfaces/
    │   │   ├── math/
    │   │   ├── mem/
    │   │   ├── processors/
    │   │   └── utils/
    │   └── pkg/                  ← package cores (alu_pkg, tproc_pkg, ...)
    ├── common/                   ← sim_base, lint rules, xilinx glbl
    ├── generators/               ← FuseSoC generators (systemrdl, svunit)
    ├── scripts/                  ← setup and core-creation scripts
    ├── docs/                     ← documentation (DRIVER.md, NEW_CORE.md, MAKEFILE_DOC.md)
    ├── pyproject.toml            ← pytest config (markers, pythonpath)
    ├── Makefile
    └── requirements.txt
```

A typical library core looks like:

```
cores/lib/<category>/<core>/
├── <core>.core                  ← FuseSoC description
├── data/                        ← aux files (waveforms, vectors)
├── hdl/
│   └── <core>.sv -> ../../../../../../rtl_lib/<category>/<core>.sv
├── lint/                        ← lint config / waivers
└── tests/
    ├── <core>_tc00.sv           ← SVUnit testbench top
    └── <core>_tests.sv          ← SVUnit test cases (included)
```

> Two kinds of cores:
>   - `cores/lib/<category>/<core>/`  — reusable building blocks (RTL + tests).
>   - `cores/ip/<name>/`              — packaged IPs (add `rdl/` + `driver/`).

---

## Prerequisites

- Python 3.8+ (3.10+ recommended)
- Vivado 2023.1 in `$PATH` (required for xsim):

```bash
source /tools/Xilinx/Vivado/2023.1/settings64.sh
export LD_LIBRARY_PATH=/tools/Xilinx/Vivado/2023.1/lib/lnx64.o:$LD_LIBRARY_PATH
```

---

## Setup

Run once after cloning:

```bash
cd firmware/fusesoc
make setup_environment
```

This creates the shared Python virtual environment at `<repository>/.venv`
(also used to build the Sphinx docs), sets up symlinks, clones the SVUnit
library (`lharnaldi/svunit`), and installs into `~/.local`, without root, the
repository's Verilator (`VERILATOR_VERSION`, 5.052) and ossschem with its VS Code
extension. Details: [../docs/developer/MAKEFILE_DOC.md](../docs/developer/MAKEFILE_DOC.md).

---

## Daily usage

Activate the virtual environment:

```bash
cd firmware/fusesoc
source ../../.venv/bin/activate
```

### Simulate a core

Two flows are available (see **docs/MAKEFILE.md** for the full comparison):

```bash
# Single core, direct FuseSoC 'test' target (SVUnit via xsim)
make sim IP=tpv2_alu
make sim IP=lfsr

# make sim on many cores, with JUnit reports (what CI runs)
make sim_svunit IP=axis_signal_gen_v6   # only this core
make sim_svunit                          # every core with a 'test' target
```

`sim_svunit` writes, per core, `report_svunit/<vlnv>.log` and the SVUnit JUnit
report `report_svunit/<vlnv>.xml`, prints `N of M cores passed` and fails if any
core failed.

### Lint a core

```bash
make lint IP=tpv2_alu
```

### List / inspect cores

```bash
make list-cores
make core-info CORE=qick:math:tpv2_alu
make deps IP=tpv2_alu
make verify-core IP=axis_signal_gen_v6
```

### Clean build artifacts

```bash
make clean
```

> `make clean` also removes `.fusesoc_libraries/`, so the next `sim_svunit`
> re-clones the SVUnit library (slower first run). It does not touch `../../.venv/` or
> the source symlinks.


### See a module as a schematic

```bash
make schematic TOP=axis_avg_buffer   # opens build/schematic/axis_avg_buffer/schematic-ir.json in VS Code
```

Guide: [../docs/user/SCHEMATIC.md](../docs/user/SCHEMATIC.md).
---

## Creating new cores

Two helpers automate core creation. See [NEW_CORE.md](../docs/developer/NEW_CORE.md) for details.

- **Library core** (reusable block, RTL already in `rtl_lib/<category>/`):

  ```bash
  ./scripts/new_lib_core.sh <category> <core_name> [pkg_depend]
  # e.g.
  ./scripts/new_lib_core.sh utils lfsr
  ./scripts/new_lib_core.sh math  tpv2_alu  qick:pkg:alu_pkg
  ```

- **Packaged IP** (with register map + driver, PeakRDL flow):

  ```bash
  make new-ip IP=my_new_ip
  ```

---

## PeakRDL: register definition & driver generation

Packaged IPs use [PeakRDL](https://peakrdl.readthedocs.io) for register maps and
driver/doc generation. Full documentation: [DRIVER.md](../docs/developer/DRIVER.md).

Quick reference:

```bash
make driver      IP=axis_constant_iq   # RDL -> Python package + driver symlink + reg tests
make driver-test IP=axis_constant_iq   # run only the register-layer pytest (no regen)
make rdl-docs    IP=axis_constant_iq   # generate HTML register documentation
make new-ip      IP=my_new_ip          # create a new IP from template
```

---

## Packaging, port naming and conventions

These moved to their own documents: [PACKAGING.md](../docs/developer/PACKAGING.md) (`make package`, AXI port and clock/reset naming)
and [CONVENTIONS.md](../docs/developer/CONVENTIONS.md) (RTL naming, file header, license, versions).

---

## Documentation index

Everything is indexed in [../docs/README.md](../docs/README.md) ("I want to..."). The ones used with this environment:

| Document | Purpose |
|---|---|
| README.md (this) | Environment overview, setup, daily usage |
| [../docs/developer/MAKEFILE_DOC.md](../docs/developer/MAKEFILE_DOC.md) | Full Makefile target reference and pitfalls |
| [../docs/developer/NEW_CORE.md](../docs/developer/NEW_CORE.md) | How to create new library cores and IPs |
| [../docs/developer/PACKAGING.md](../docs/developer/PACKAGING.md), [CONVENTIONS.md](../docs/developer/CONVENTIONS.md) | Packaging, AXI port naming, RTL conventions, header and license |
| [../docs/developer/DRIVER.md](../docs/developer/DRIVER.md) | PeakRDL register maps and Python driver generation |
| [../docs/developer/TESTBENCH_PATTERNS.md](../docs/developer/TESTBENCH_PATTERNS.md) | Testbench and xsim pitfalls |
