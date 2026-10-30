# Working with drivers on an RFSoC board

> **In this repository** the drivers in `qick_lib` keep hand-written register maps. They do not import the generated
> `<ip>_regmap_pkg`, `qick/rdl_regs.py` does not exist yet and `qick_lib/qick/rdl_pkgs/` is local output that is not committed,
> so `make driver-check` has nothing to check. What this document says about drivers that read the package, and about the
> drivers of `axis_streamer`, `axis_kidsim_v3` and `xcom`, applies when that work is merged.

How an IP developed in `firmware/fusesoc/cores/ip/<ip>/` gets from the workstation to a running
`QickSoc` on an RFSoC board, and what to check when it does not. The register/driver generation
itself is described in [DRIVER.md](../developer/DRIVER.md); the Makefile targets in
[MAKEFILE_DOC.md](../developer/MAKEFILE_DOC.md).

**Status.** The flow below was exercised on an RFSoC4x2 with `axis_constant_iq` and
`qick_time_tagger` (September 2026): the board ran a clone of a development branch, `QickSoc`
bound the standalone `AxisConstantIq` driver, its generated register model worked, and the validation notebook
passed. Not exercised yet: the other standalone drivers
(`mr_buffer_et`, `axis_kidsim_v3`, `axis_streamer`, `axis_signal_gen_v6`), and a hand-over to the
official `openquantumhardware/qick` repository.

## 1. The model

- Every IP owns its driver: `cores/ip/<ip>/driver/<ip>.py`. Legacy drivers still live inside the five
  monolithic modules of `qick_lib/qick/drivers/` (`generator`, `readout`, `tproc`, `peripherals`,
  `xcom`); their `driver/<ip>.py` is a symlink *into* those modules.
- A standalone driver is made visible to `QickSoc` by a symlink `qick_lib/qick/drivers/<ip>.py`
  pointing back at it. `QickSoc` imports every module it finds there.
- The generated register package the driver needs is committed under
  `qick_lib/qick/rdl_pkgs/<ip>_regmap_pkg/` (runtime part only), because the board has no PeakRDL.
- The board runs a **plain clone of this repository**, checked out on the branch under test, as
  `~/jupyter_notebooks/qick`. There is no separate install step: `import qick` resolves to that
  directory (`qick.__file__` shows `.../qick/qick_lib/qick/__init__.py`).

## 2. On the workstation

What goes into git for an IP that runs on a board:

| Item | Committed? | Notes |
|---|---|---|
| `cores/ip/<ip>/driver/<ip>.py` and `rdl/<ip>_regmap.rdl` | yes | hand-written: the sources |
| `cores/ip/<ip>/README.md` | yes | the user guide of the IP: behaviour, formats, rules, integration, validation status ([NEW_CORE.md](../developer/NEW_CORE.md), section 6). Update it when the bring-up teaches something; the bring-up project's README is only the log |
| `qick_lib/qick/drivers/<ip>.py` (symlink) | yes | standalone drivers only; this is what makes `QickSoc` import the driver |
| `qick_lib/qick/rdl_pkgs/<ip>_regmap_pkg/` (runtime part) | yes | *generated* by `make driver`; needed by every driver that reads it (`grep -E "RDL_IP|_regmap_pkg"` in `qick_lib/qick/drivers/`) |
| PeakRDL's `tests/` and `lib_test/`, the HTML docs, `cores/ip/<ip>/rdl/<ip>_regmap_pkg/` | no | ignored |

A driver that does not import a generated package (for example `QICK_Time_Tagger`, which lives in
`peripherals.py` and uses fixed register offsets) needs nothing extra. A standalone driver that does
need one has to be committed together with its symlink and its package: the symlink activates the driver,
and without the package it fails to import (`QickSoc` then logs a warning and skips it). Today only
`axis_constant_iq` is committed this way; run `make driver IP=<ip>` and commit both the first time
another standalone driver is used on a board.

For a new or changed standalone driver:

```bash
cd firmware/fusesoc
make driver IP=<ip>          # generate the package, symlink the driver, copy the package, run reg tests
make driver-check IP=<ip>    # OK if the committed package matches the RDL
git add cores/ip/<ip> ../../qick_lib/qick/drivers/<ip>.py ../../qick_lib/qick/rdl_pkgs/<ip>_regmap_pkg
```

Before pushing, prove the commit is self-contained. A package that imports in your working tree can
still be missing files in the commit (the root `.gitignore` has `_*`, which drops `__init__.py`). Commit first: a clone only sees committed work.

```bash
git clone --branch <branch> "$(git rev-parse --show-toplevel)" /tmp/qick_check && cd /tmp/qick_check
python3 -c "import sys; sys.path.insert(0, 'qick_lib/qick/rdl_pkgs'); \
from <ip>_regmap_pkg.reg_model import RegModel; from <ip>_regmap_pkg.lib import NormalCallbackSet; print('ok')"
```

## 3. On the board, once

```bash
cd ~/jupyter_notebooks
mv qick qick_official_bak                    # keep whatever was there
git clone -b <branch> <repository-url> qick  # no --recursive: the Hog submodule is not needed
```

- The repository is private, so the board needs credentials. A read-only **deploy key** for the
  repository (GitHub, Settings, Deploy keys) is cleaner than putting a personal key on the board.
  This is the standard GitHub mechanism; it has not been walked through on the board in this project.
- If you plan to switch branches, do not use `--depth 1`, or fetch the branch explicitly
  (`git fetch origin <branch>`) before checking it out.

## 4. On the board, every iteration

```bash
cd ~/jupyter_notebooks/qick && git fetch && git checkout <branch> && git pull
```

Then **restart the notebook kernel**: modules already imported stay cached in the running process, so
a `git pull` alone changes nothing. Check what you are running:

```python
import qick; print(qick.__file__)
soc = QickSoc(bitfile=BITFILE, no_tproc=True)        # no_tproc for firmwares without a tProcessor
print(type(soc.<instance_name>))                       # the driver class, not DefaultIP
```

`QickSoc` also logs `IP <name> (qick:ip:...) has no QICK driver bound` for any IP of this repository
that PYNQ bound to the generic `DefaultIP`.

## 5. Firmware files

- The `.bit` and the matching `.hwh` go in one directory with the **same base name**
  (`~/jupyter_notebooks/fw/<project>/<project>.bit` / `.hwh`). PYNQ reads the IP list and the clock
  frequencies from the `.hwh`; a stale one gives wrong clocks in every diagnostic.
- Hog writes the bitstream (and an `.xsa`) under `firmware/bin/<board>/<project>-<version>/`. The
  `.hwh` normally travels inside the `.xsa` (a zip) and Vivado also writes it under the project's
  `hw_handoff` directory; check the path for your Vivado version.
- The bring-up notebooks start with `BITFILE = ...`: edit it to the directory above.
- **A rebuilt `.bit`/`.hwh` copied over the old pair is NOT re-read by PYNQ 3.0.x.**
  - `pynq/pl_server/` keeps the parsed `.hwh` of the last download in `_current_metadata.pkl`. It reuses that
    parse when `global_pl_state.json` "matches" the bitstream.
  - The match is a SHA1 of the `.bit` that `GlobalState.__init__` recomputes from **whatever file is at the stored
    path now**. After an in-place overwrite it always matches, and so does a renamed copy of the same content.
  - So the new bitstream is downloaded, but every driver keeps seeing the old `.hwh` (parameters, COREREVISION),
    until another bitstream is loaded.
  - Seen with a core in development, 0.2.1 read as 0.2.0, 2026-09-29.
  - Fix: delete `_current_metadata.pkl` and `global_pl_state.json` from `os.path.dirname(pynq.pl_server.__file__)`
    before `QickSoc(...)`:

    ```python
    import os, pynq.pl_server
    for f in ("_current_metadata.pkl", "global_pl_state.json"):
        p = os.path.join(os.path.dirname(pynq.pl_server.__file__), f)
        if os.path.exists(p):
            os.remove(p)
    ```

    Put it in the setup cell of any bench notebook that is rebuilt and reloaded under the same name.

## 6. Things that went wrong in the first bring-up

| Symptom | Cause | What to do |
|---|---|---|
| `'DefaultIP' object has no attribute 'regs'` | The driver module was never imported, so PYNQ found no `bindto` | `make driver IP=<ip>`, commit the symlink; see the warning `QickSoc` prints |
| `ZeroDivisionError` in `RFDC._read_freqs` | A tile's `Fabric_Freq` is smaller than its `Outclk_Freq` in the `.hwh` (there: a DAC `Mixer_Mode` left unset, which halved the fabric clock) | Read the `C_<ADC\|DAC><n>_Fabric_Freq` / `_Outclk_Freq` parameters from the `.hwh` |
| `KeyError: '<ip>/adc_clk'` in `configure_connections` | The driver looks ports up by name and the fusesoc port renamed them | Pick names by VLNV (done for `QICK_Time_Tagger`) |
| Output never changes when registers are written | A strobe register (`WE`) left high; the RTL wants a rising edge | Pulse it (`update()` in the driver) |
| Spectral peaks of a captured tone do not follow the tone | Not the ADC path: the time tagger's SMP store drains one 8-sample word every ~11 clocks of 100 MHz, so a continuous trigger overflows its FIFO after ~8 windows | Arm for about 1 ms and analyse only the first windows |
| Timestamps or frequencies off by 1e6 | `tt['f_fabric']` and `get_fclk` are in **MHz** | Convert explicitly |
| `set_mixer_freq` raises "mixer is not enabled" | The DAC mixer is COARSE. Vivado's `DAC_Mixer_Type` matches xrfdc: 1 COARSE, 2 FINE, 3 OFF | Build with `DAC_Mixer_Type {2}` |
| ADC tile has `out_div = 2` | Normal for this ADC (the official design has it too): `clk_adc0` is half of the fabric clock and the AXI-stream side needs the fabric clock | Double it with a `clk_wiz` (`clk_adc0_x2`) and clock `m0_axis_aclk` and the consumer from it |
| A rebuilt bitstream behaves new, but drivers report the old revision/parameters | PYNQ 3.0.x served its cached `.hwh` parse (section 5) | Delete `_current_metadata.pkl` and `global_pl_state.json` in `pynq/pl_server/`, then reload |
| Warning about `DAC_AVTT` and VOP mode on start-up | The RFSoC4x2/2x4 hard-wires `DAC_AVTT` at 2.5 V; the RFDC asks for 3.0 V in VOP mode | Expected on this board; not a bug |

## 7. Not done yet

- A `make export-qick` target that dereferences the symlinks and copies the runtime register packages,
  for handing an IP over to the official repository (symlinks out of the package tree do not survive a
  wheel build).
- Driver-side registration of standalone IPs as QICK channels (`soc.gens`, `soc.iqs`, ...): `QickSoc`
  builds those lists by driver class, so an IP that must appear there has to subclass the matching
  `Abs*` class.
- `make driver` plus a commit of `rdl_pkgs/<ip>_regmap_pkg` for each remaining standalone driver, the first
  time it is used on a board.
- User-guide READMEs for the IPs that do not have one yet (only `axis_signal_gen_v6`, `mr_buffer_et`,
  `qick_time_tagger` and `axis_constant_iq` do).
