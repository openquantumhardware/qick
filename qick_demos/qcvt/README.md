# QCVT — QICK Control Visualization Tool

Visualize and export the pulse schedule of a QICK `asm_v2` program **before it is
sent to an RFSoC**. Works online (connected) and fully offline (from a saved
config or a compiled-program pickle).

Originally developed at https://github.com/DRNag2/QCVT and proposed for inclusion
in QICK in https://github.com/openquantumhardware/qick/issues/229.

![Example schedule](example_schedule.png)

## Install

```bash
# from the QICK repo root
pip install -e ".[qcvt]"
# optional: load compiled-program pickles
pip install -e ".[qcvt-pickle]"
```

## Quick start (offline demo)

```bash
python qick_demos/qcvt/run_offline_example.py
python qick_demos/qcvt/walkthrough_demo.py
```

No RFSoC needed — these use the bundled `qick_config.json`.

## In your experiment code

```python
from qcvt import show_schedule, review_schedule, extract_schedule, set_channel_labels

prog = YourProgram(soccfg, reps=1, final_delay=0, cfg=config)
show_schedule(prog, title="My experiment")

# Pre-submit gate
ok = review_schedule(prog, save_dir="qcvt_reviews/my_exp", show=True, confirm=True)
if not ok:
    raise RuntimeError("aborted")

sched = extract_schedule(prog, strict=True)
```

### Channel labels

Lane labels default to generator channel + QICK box port (`gen 6 (DAC 6)` on
a ZCU216).  The two-digit ids in the demos (`"26"`, `"02"`) are RFDC
tile/block names from `print(soccfg)` / `soccfg.get_gen_cfg(ch)['dac']` —
**not** "DAC 4" in the lab sense.

Prefer `gen_ch_labels`, keyed by the same ints you pass to `add_pulse`:

```python
set_channel_labels(gen_ch_labels={0: "sqz pump", 1: "cqr drive", 6: "qubit"})
show_schedule(prog)  # reused for the rest of the session
```

You can also stash labels on the config so they survive `save_soccfg_to_json`:

```python
soccfg["qcvt_gen_ch_labels"] = {6: "qubit drive"}
```

`physical_port_labels` still maps RFDC ids (`"12"` or `12`) if you need that
layer.  Int and string keys both work.

### Insets and loops

Zoom insets are **opt-in** (`insets=True`).  Interactive Qt windows can zoom
without them.  When enabled, pulses that overlap the zoom (for example a CW
pump that started earlier) are drawn, not dropped.

If the program has loops, the title includes `loops (outer → inner): ...`
from `prog.get_loop_dict()`.  Pulses whose start or length is swept are drawn
solid at the sweep start, with a dashed **ghost** at the other extreme (same
width if the pulse only slides; a different width if length changes).  A
burst of ADC windows shares one ghost so the lane is not 75 dashed boxes.

### Offline demos and `sw_version`

The bundled `qick_config.json` is a **compile-time** snapshot, not a live
board.  The demo scripts load it with
`load_soccfg_from_json(..., align_version=True)` so a stale `sw_version` in
the JSON does not warn you to upgrade the RFSoC.

## Tests

```bash
pip install -e ".[qcvt]" pytest
pytest qick_lib/qcvt/tests/ -v
```
