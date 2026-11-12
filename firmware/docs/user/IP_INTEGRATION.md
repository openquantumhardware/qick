# IP ↔ driver integration plan

> **In this repository** the drivers in `qick_lib` keep hand-written register maps. They do not import the generated
> `<ip>_regmap_pkg`, `qick/rdl_regs.py` does not exist yet and `qick_lib/qick/rdl_pkgs/` is local output that is not committed,
> so `make driver-check` has nothing to check. What this document says about drivers that read the package, and about the
> drivers of `axis_streamer`, `axis_kidsim_v3` and `xcom`, applies when that work is merged.

How every IP packaged from this repository (`qick:ip:*`) is used from Python from now on. The goal: when a module
misbehaves on a board, **its driver is the tool to test it**, and that driver is the same one `QickSoc` and
`QickProgram` use in production. There is no separate "debug driver".

Mechanics (RDL package, `make driver`, `rdl_pkgs`, the board clone) are in [DRIVER.md](../developer/DRIVER.md) and
[BOARD_WORKFLOW.md](BOARD_WORKFLOW.md). This file says **which** driver an IP has, **where** it lives, and **what
must exist before a port counts as done**.

---

## 1. Rules

1. **One driver class per VLNV.** Exactly one class in `qick_lib` binds a given `qick:ip:<ip>:<MAJOR.MINOR>`.
   PYNQ keeps the last class it imported for a VLNV. Standalone drivers are imported after the monolithic
   modules, so a duplicate silently takes over. This already happened with `axis_constant_iq`: the standalone
   `AxisConstantIq` displaced `generator.AxisConstantIQ`, so the IP stopped appearing in `soc.iqs`.
   `make driver-bindings` checks this and rule 4 (§5).
2. **The IP's driver is the `QickSoc` driver.** `QickSoc` builds `soc.gens`, `soc.iqs`, `soc.readouts`,
   `soc.avg_bufs`, `soc.mr_buf`, `soc.time_taggers` and the tProc by driver *class*. Every IP that plays one of
   those roles must be bound to the class `QickSoc` expects.
3. **Where the class lives** depends on that role:

   | Kind | Examples | Class lives in | `cores/ip/<ip>/driver/<ip>.py` |
   |---|---|---|---|
   | QICK channel / role known to `QickSoc` | generators, readouts, buffers, mr_buffer, tProc, time tagger, constant IQ | the monolithic `qick_lib` module that has its abstract base (`generator.py`, `readout.py`, `tproc.py`, `peripherals.py`) | **symlink** to that module (an alias; `make driver` does not install it again) |
   | anything else | `axis_streamer`, `axis_kidsim_v3` | the IP itself, standalone | the real file; `make driver` symlinks it into `qick_lib/qick/drivers/` |

   Why keep the channel classes in the monolithic modules:
   - they share base classes (`AbsPulsedSignalGen`, `AbsReadout`, `AxisAvgBuffer`, ...) and `QickSoc`'s wiring;
   - the public qick repository has the same modules, so a fix stays one diff away from upstream;
   - one class keeps serving legacy and ported firmware alike, by listing both VLNVs in `bindto` and
     picking port names by VLNV where the port renamed them (see `MrBufferEt`, `QICK_Time_Tagger`).

   An IP with no AXI-Lite slave (`axis_set_reg`, `sg_translator`, the glue IPs) has no driver. The driver of
   whatever consumes it traces it (e.g. the tProc finds `axis_set_reg`).
4. **`bindto` lists the packaged VLNV** `qick:ip:<ip>:<MAJOR.MINOR>` (the `.core` version without its PATCH),
   plus the legacy VLNVs while legacy firmware is still in use. Every packaged IP with an AXI-Lite slave must be
   bound. `make driver-bindings` fails otherwise; known gaps are listed, with their reason, in the script's
   `PENDING`. 114 went briefly without `qick:ip:axis_constant_iq` in `AxisConstantIQ`: that line had reached 117
   in a Top-BD commit that was never cherry-picked. The duplicates check alone did not see it.
5. **The PATCH (`COREREVISION`) is how drivers gate known bugs.** `configure_connections()` gets it in
   `self['revision']`. A driver warns when the bitstream carries a revision with a known defect (see
   `AxisStreamer`, 2.0.0).
6. **Notebooks and benches use the driver, never raw MMIO.** Register pokes that a validation needs become driver
   methods. The driver is what is being validated, and the next person debugging the IP will use those methods.
   Exception: the register-layer check (`regs` round trips) and hardware that has no driver (DMA register reads
   for diagnosis).
7. **Register offsets match the RDL.** The `REGISTERS` dictionary of a driver is written by hand and must agree with
   `rdl/<ip>_regmap.rdl`; a class for a legacy-only IP has no RDL.

## 2. What "done" means for a ported IP

| # | Item | Where |
|---|---|---|
| D1 | RTL + SVUnit, lint, packaged (`make package`), Top BDs on the `qick:ip` VLNV | core, `firmware/ip/<ip>` (generated) |
| D2 | One bound class per §1, `bindto` with the `qick:ip` VLNV; `make driver-bindings` clean | `qick_lib/qick/drivers/` |
| D3 | Register-layer pytest (RDL model) | `cores/ip/<ip>/driver/tests/test_<ip>_regs.py` |
| D4 | Behaviour pytest of the driver's high-level methods, off the board: pynq stubbed, IP modelled at register level (see `axis_streamer`'s `test_axis_streamer_driver.py`) | `cores/ip/<ip>/driver/tests/test_<ip>_driver.py` |
| D5 | A debug bench and a validation notebook that go through `QickSoc` + the driver | not in this repository |
| D6 | Board run recorded: values in the bench README, status in the IP README's open items | READMEs |

Shared helper for D4: `scripts/driver_testing.py` (pynq stub, `FakeMmio`, `FakeDma`). D4 tests the sequence the driver sends and how it handles errors, so the board run (D5) can concentrate on the
hardware. It is what caught the `AxisStreamer.recover()` ordering bug as a regression, after the board found it.

## 3. Using an IP through its driver

`QickSoc` imports every driver itself: the monolithic modules explicitly, and every standalone module in
`qick_lib/qick/drivers/` through `_import_ip_drivers()`. A notebook never imports a driver. `soc.<instance_name>` is
already the bound driver, and a check on it goes by class name (`type(ip).__name__`).

```python
from qick import QickSoc
soc = QickSoc(bitfile)                       # a debug bench without a tProc: QickSoc(bitfile, no_tproc=True)
ip = soc.<instance_name>                     # e.g. soc.axis_streamer_0: the bound driver
print(type(ip).__name__, ip.cfg)             # class, parameters, version/revision from the HWH
```

- `QickSoc` warns about every `qick:ip:*` IP left on `DefaultIP`: that means no driver was imported for its VLNV.
- Channel IPs are also reachable through their role (`soc.gens[i]`, `soc.avg_bufs[i]`, ...) and from
  `QickProgram`. A bench notebook should use at least the role path once, so that a class mix-up (rule 1) fails
  there.
- With a raw PYNQ `Overlay` the driver binds too, but `configure_connections()` does not run (no DMA traced, no
  revision). Use `QickSoc` unless the firmware cannot be parsed by it.

## 4. Status (2026-09-25)

Legend: ✅ done, ❌ missing, ⚠️ exists but needs work, — not applicable.

| IP | Class (location) | D2 binding | D3 | D4 | D5 bench / notebook | D6 board |
|---|---|---|---|---|---|---|
| axis_streamer | `AxisStreamer` (standalone) | ✅ | ✅ | ✅ | ✅ 4x2 and 216 debug benches, driver | ✅ 4x2 ALL PASS 2026-09-25 (216 bench deferred) |
| axis_signal_gen_v6 | `AxisSignalGen` (generator.py) | ✅ alias (placeholder removed 2026-09-25) | ✅ | ❌ | ⚠️ exercised by the tProc v2 debug bench (QickSoc); no own notebook | ✅ via the tProc v2 debug bench |
| axis_sg_int4_v2 | `AxisSgInt4V2` (generator.py) | ✅ alias | ✅ | ❌ | ✅ 4x2, QickSoc | ✅ 2026-09-24 |
| axis_sg_mux8_v1 | `AxisSgMux8V1` (generator.py) | ✅ alias | ✅ | ❌ | ✅ 4x2, QickSoc | ✅ 2026-09-24 |
| axis_sg_mixmux8_v1 | `AxisSgMixMux8V1` (generator.py) | ✅ alias | ✅ | ❌ | ✅ 4x2, QickSoc | ✅ 2026-09-24 |
| axis_constant_iq | `AxisConstantIQ` (generator.py) | ✅ alias; the standalone `AxisConstantIq` was merged in 2026-09-25 (`get_iq`, clipping) | ✅ | ✅ | ✅ 4x2, QickSoc | ⚠️ passed with the standalone class; re-run with `AxisConstantIQ` (in `soc.iqs`) |
| axis_readout_v2 | `AxisReadoutV2` (readout.py) | ✅ alias | ✅ | ❌ | ✅ used by the buffer/streamer benches | ✅ |
| axis_avg_buffer | `AxisAvgBufferV1pt2` (readout.py) | ✅ alias | ✅ | ❌ | ✅ 4x2, QickSoc | ✅ |
| axis_weighted_buffer | `AxisWeightedBufferV1pt3` (readout.py) | ✅ alias | ✅ | ❌ | ✅ 4x2, QickSoc | ✅ |
| axis_readout_v3, axis_dyn_readout_v1 | register-less, created by the buffer driver | — | — | — | through the buffers | — |
| mr_buffer_et | `MrBufferEt` (readout.py) | ✅ alias (placeholder removed 2026-09-25); STATUS/DEBUG methods added | ✅ | ✅ | ✅ 216 debug bench, driver; no 4x2 bench | ⚠️ 216 passed with raw MMIO; re-run through the driver |
| axis_kidsim_v3 | `AxisKidsimV3` (standalone) | ✅ installed 2026-09-25, `config_lane`/`config_all` | ✅ | ✅ | ✅ 4x2 debug bench, `QickSoc(no_tproc, no_rf)` + driver | ⚠️ 8/8 passed 2026-09-22 with raw MMIO; re-run through the driver |
| qick_processor | `Axis_QICK_Proc` (tproc.py) | ✅ alias | ✅ | ⚠️ status decode only (6) | ✅ 4x2 debug bench, QickSoc | ✅ 2026-09-24 |
| axis_tprocv1 | `AxisTProc64x32_x8` (tproc.py) | ✅ alias (the unused register test model was removed 2026-09-25) | ✅ | ✅ | ❌ no bench | ❌ |
| qick_time_tagger | `QICK_Time_Tagger` (peripherals.py) | ✅ alias | ✅ | ❌ | ✅ 4x2, QickSoc | ✅ |
| axis_set_reg, glue IPs (tier A) | no AXI-Lite slave | — | — | — | set_reg: 4x2, raw `Overlay` | set_reg ✅ |
| xcom | `QICK_Xcom` (xcom.py) | ✅ alias; RDL (`xcom_config`, `tx_ddr_cfg`, `rx_ddr_cfg` of the DDR link) | ✅ | ✅ | ⚠️ two-board notebooks in `cores/ip/xcom/demo`, not run with this driver | ❌ |

## 5. Work plan

In order. Each step goes through the usual commit/cherry-pick flow (117, fusesoc/qick_lib scope also on 114).

1. ✅ **Binding check** (2026-09-25). Add `scripts/check_driver_bindings.py` + `make driver-bindings`. It statically collects every
   `bindto` in `qick_lib/qick/drivers/*.py` (resolved, aliases counted once) and in the standalone
   `cores/ip/*/driver/*.py`, and fails on a VLNV bound twice. It must fail today (constant_iq, sgv6, mr_buffer_et)
   and pass at the end. It also fails on a packaged IP whose RTL has an AXI-Lite slave but whose VLNV no class
   binds (rule 4).
2. ✅ **Remove the duplicates** (2026-09-25), one commit per IP: mr_buffer_et, axis_signal_gen_v6, axis_constant_iq, axis_tprocv1. `driver-bindings` is clean.
   - `mr_buffer_et`, `axis_signal_gen_v6`: the placeholder becomes an alias symlink to `readout.py` /
     `generator.py`. Register tests stay.
   - `axis_constant_iq`: move what the standalone class added (`get_iq()`, clipping in `set_iq()`, `regs`) into
     `generator.AxisConstantIQ`, then alias it. Remove the installed standalone and its `rdl_pkgs` copy (the
     register tests use the core's own package).
   - `axis_tprocv1`: its register test model moves under `driver/tests/`, and `driver/axis_tprocv1.py` becomes
     an alias to `tproc.py`.
3. ✅ (board re-run pending) **mr_buffer_et, D4 + D5**: behaviour tests of `MrBufferEt`; 216 notebook through the driver (`soc.mr_buf` /
   `soc.mr_buffer_et_0`) instead of MMIO. A 4x2 bench only if the 216 one stays unavailable.
4. ✅ (board re-run pending) **axis_kidsim_v3**: real `AxisKidsimV3` methods from its design note (lane configuration, resonator
   parameters), D4, notebook through `QickSoc`.
5. **axis_signal_gen_v6**: D4 for `AxisSignalGen` (envelope load, saturation flags, the `env_full_scale` switch),
   and a notebook step on the tProc v2 debug bench that goes through `soc.gens`.
6. **D4 for the remaining channel classes** (int4, mux8, mixmux8, readout_v2, avg/weighted buffer, tProc, time
   tagger). Their board runs already pass through `QickSoc`, so this is regression cover, lowest priority.
7. **New ports** (tier B/C) are done only with D1–D6.
