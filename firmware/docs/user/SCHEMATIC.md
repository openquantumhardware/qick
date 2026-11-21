# Interactive RTL schematic in VS Code (`make schematic`)

`make schematic TOP=<module>` shows the elaborated design of any module of `firmware/rtl_lib/` as a schematic
you can expand and trace inside VS Code: the whole hierarchy, instances opened in place, buses (and unpacked
arrays) as single nets, a signal followed forward to its loads or backward to its drivers. It is what Vivado's
*Open Elaborated Design* shows, without opening Vivado.

It uses [ossschem](https://github.com/markusdd/ossschem) (MIT): Verilator elaborates the RTL
(`verilator --json-only`), `firmware/fusesoc/scripts/gen_block_diagram.py --ir` turns that into
`schematic-ir.json`, and the ossschem VS Code extension opens it. For a static picture to put in a document,
`make block-diagram` (an SVG of one level) or the hand-drawn diagrams of [../block-diagrams/](../block-diagrams/)
are the tools.

## Setup

`make setup_environment` (in `firmware/fusesoc/`) installs everything, once:

- Verilator `VERILATOR_VERSION` of the Makefile (5.052) into `~/.local/verilator-5.052`; ossschem needs 5.046 or
  newer;
- ossschem `OSSSCHEM_VERSION` (0.7.0) into `~/.local/ossschem-0.7.0`, checked against its sha256;
- the VS Code extension `markusdd.ossschem@0.7.0`, when `code` is on `PATH` (otherwise install it from VS Code).

`make install_verilator` and `make install_ossschem` do one of them alone, for example after the version in the
Makefile changes. Both do nothing when that version is already installed, and neither needs root.

## Open a schematic

```bash
cd firmware/fusesoc
make schematic TOP=axis_avg_buffer
```

This writes `build/schematic/axis_avg_buffer/schematic-ir.json` and opens it in VS Code (a second run replaces
it). Any `schematic-ir.json` opens from the VS Code explorer as well: the extension is its editor. `build/` is
ignored by git.

`TOP` is a module name, looked up as `<TOP>.sv` under `firmware/rtl_lib/` (the file name of a module is its core
name, see [../developer/CONVENTIONS.md](../developer/CONVENTIONS.md)), or in the file that declares it when the names
differ (`axi_qick_time_tagger` in `qick_time_tagger.sv`).

## A whole Vivado project

```bash
make schematic PROJ=216/xcom_async_mc3
```

draws a project of `firmware/Top/<group>/<project>/` from its top down: the project's top (its `set_property top`,
here `xcom_async_mc_dbg_top`; `d_1_wrapper` for the standard projects), the block design opened from the netlist
Vivado generated (Zynq, DMA, interconnect, every IP and how they connect), and inside it **our IPs down to their RTL**
(`xcom_async_mc` -> `link_rx` -> ...). AMD's IPs stay boxes with their ports. The result goes to
`build/schematic/216_xcom_async_mc3/`; `TOP=<module>` together with `PROJ=` starts from another module of it.

It reads what Vivado generated in `firmware/Projects/<group>/<project>/<project>.gen/` (the BD netlist, the IP
wrappers and stubs), so the project must have been created once (`./Hog/Do CREATE <group>/<project>` from
`firmware/`, or a build), and it shows the BD as Vivado last generated it: after changing the BD or an IP version,
create the project again. An IP of ours whose wrapper was generated from an older version of it (another module name)
stays a box.

A VS Code task makes it one keystroke for the file in the editor. In the user `tasks.json`
(*Tasks: Open User Tasks*):

```json
{
    "label": "schematic of the current file",
    "type": "shell",
    "command": "make",
    "args": ["-C", "${workspaceFolder}/firmware/fusesoc", "schematic", "TOP=${fileBasenameNoExtension}"],
    "problemMatcher": []
}
```

## Modules Verilator cannot find

A module with no source in `rtl_lib/` becomes a box with its ports only (a blackbox), generated at run time and
never committed:

| Module | Taken from | What it needs |
|---|---|---|
| UNISIM primitives (`IBUFDS`, `BUFG`, `MMCME4_ADV`, ...) and XPM macros | the Vivado install | Vivado's `settings64.sh` sourced (or `vivado` on `PATH`) |
| IP cores (`.xci`) | the `<ip>_stub.v` Vivado wrote under `.gen/` | the IP generated once (its Vivado project built) |
| Block-design wrappers (`d_1_wrapper`) | `Projects/<board>/<project>/...gen/.../d_1_wrapper.v` | the Vivado project built once; with several projects, the wrapper whose ports match the instance is used |
| With `PROJ=`: the vendor IPs of the block design | that project's own `<ip>_stub.v`, or the IP wrapper Vivado wrote (Verilog, or VHDL for e.g. `proc_sys_reset`) | the project created once |

The run prints one line per blackbox (`IBUFDS: blackbox from .../unisims/IBUFDS.v`). When a module is found
nowhere, Verilator's `MODMISSING` error names it.

## Using the viewer

The **Help** button or `H` lists every shortcut. The ones used most:

| Do | How |
|---|---|
| Zoom / pan / see everything | mouse wheel / middle-drag, `Alt`-drag or `Space`-drag / **Fit** |
| Zoom into an area | left-drag on empty canvas (`Escape` cancels) |
| Open an instance or process in place | double-click, or `E`; `L` also opens its logic (assigns, always blocks) |
| Go into an instance / back to the parent | `Enter` / `Backspace` |
| Close what is selected | `C` |
| Show only the selection / show everything again | `I` (Isolate) / **Show all** |
| Follow a signal to its loads / to its drivers | select a wire or pin, `F` / `B`; press again to advance one step (registers are crossed, clocks and resets are followed only when selected) |
| Where is this signal declared, who drives it, who reads it | the source pane below the schematic: declaration, **Drivers**, **Loads**, **Reveal** |
| Hide nets with many loads | **Hide fanout ≥** in the toolbar (default 8; clocks and resets are drawn as stubs until traced) |
| Navigate a large design | **World map** in the toolbar |

The sidebar shows the module tree; its **Expand structure** and **Expand logic** buttons open a whole subtree.
Buses are drawn thicker with their width (`32`).

With the [vaporview](https://marketplace.visualstudio.com/items?itemName=lramseyer.vaporview) extension and a
waveform dump open, `W` adds the selected signal to the waveform, **Reveal in schematic** (right-click on a
waveform signal) goes the other way, and **Values** labels the wires with their value at the cursor.

## Limits

- Verilator elaborates what it can simulate: a module whose RTL Verilator rejects has no schematic (the error
  is Verilator's).
- The blackboxes of IP cores and block designs come from what Vivado last generated: a stale `.gen/` or
  `Projects/` gives stale ports.
- ossschem is a young project (0.7.0); `OSSSCHEM_VERSION` and `OSSSCHEM_SHA256` in `firmware/fusesoc/Makefile`
  pin the release that was tested.
