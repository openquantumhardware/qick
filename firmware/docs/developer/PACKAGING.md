# Packaging an IP for Vivado, and port naming

How a core becomes a `qick:ip:` component, and the port names the packager needs to infer the interfaces and clock domains correctly.
Commands run from `firmware/fusesoc/` (see [the environment README](../../fusesoc/README.md)); the target reference is
[MAKEFILE_DOC.md](MAKEFILE_DOC.md).

---

## Packaging

Once the RTL is tested:

```bash
make package IP=my_new_ip
make package-all
```

This generates the Vivado IP packaging artifacts. After packaging, recreate the
HOG project as usual.

### Xilinx sub-IP (`.xci`) and Vivado versions

The `.xci` files in `rtl_lib/xci/` are shared by every project, and the packager copies them as they are into
`ip/<ip>/`. A project is built with one Vivado version (its `bd_<version>.tcl`), but these files are not
per version, so **they are kept in the format of the oldest Vivado we support, 2023.1**. A newer Vivado
upgrades them when it opens them (`upgrade_ip`); an older one cannot read what a newer one saved: a `.xci`
saved by Vivado 2024+ has a top-level `"checksum"` that 2023.1 rejects (`IP_Flow 19-8166`), and the block
design fails to generate (`BD 41-1030`, "Failed to create IP subcores").

- `scripts/hog/gen_qick_ip_lists.py` (run by pre-creation, `make hog-lists`) refuses the build while a packaged
  `.xci` has that `"checksum"`, in a project with a `bd_2023*.tcl`. A project with only newer BD scripts
  (`bd_2025.2.tcl`) is built with a newer Vivado and is not checked.
- To add or change a `.xci`, create it with **Vivado 2023.1** (`create_ip`, set the parameters, take the `.xci`
  and its `.coe` from the IP directory; the `.coe` is referenced by its bare file name). Do not copy one saved by
  2025.2 even if it works there.
- `gen_directory` and `OUTPUTDIR` of a `.xci` are `"."`, as Vivado writes them for an IP created outside a project.
  A `.xci` copied from another project keeps a relative path into that project's tree
  (`../../../../projects/<their project>/...gen/sources_1/ip/...`), which resolves to a directory that does not
  exist here: Vivado warns that the file "has been moved" and writes its outputs there, and `upgrade_ip` fails.
- Parameters that exist only in newer versions of the IP (e.g. `DataCoefficientType`, `Reset_Coeff_Vector` of the
  FIR Compiler, `Output_Type` of the DDS Compiler) are absent from the 2023.1 file; 2025.2 adds them with their
  defaults when it upgrades the IP. Checked on the PFB v4 `.xci` (2026-10-27): after the 2025.2 upgrade the
  parameters are identical to the ones saved by 2025.2, and 2025.2 reports
  `Reset_Coeff_Vector 'false' to 'true' has been ignored` (disabled parameter), which is harmless.

---

## Port naming conventions for AXI auto-inference

Vivado's `ipx::infer_bus_interfaces` recognizes ports by prefix:

| Interface type     | Port prefix                 |
|--------------------|-----------------------------|
| AXI4-Lite slave    | `s_axi_*`                   |
| AXI4-Stream slave  | `s_axis_*` or `s0_axis_*`   |
| AXI4-Stream master | `m_axis_*` or `m0_axis_*`   |
| Clock              | `*_clk*` or `*_aclk*`       |
| Reset              | `*_aresetn*` or `*_resetn*` |

### Clock / reset domains (MANDATORY for multi-clock cores)

QICK cores typically use **two clock domains**: a slow AXI-Lite
configuration domain and a fast AXI-Stream datapath domain. Use these
**exact** port names on the top-level module:

| Domain            | Clock port    | Reset port       | Associated interfaces        |
|-------------------|---------------|------------------|------------------------------|
| Config (AXI-Lite) | `s_axi_aclk`  | `s_axi_aresetn`  | `s_axi`                      |
| Datapath (AXIS)   | `aclk`        | `aresetn`        | all `*_axis` (`s_axis`, `m_axis`, `m_axis_*`) |

Rules:
- The AXI-Lite interface **must** be named `s_axi` (clock `s_axi_aclk`,
  reset `s_axi_aresetn`).
- All AXI-Stream interfaces share the single datapath clock `aclk` /
  reset `aresetn`.
- Internal helper clocks/resets (e.g. `i_clk` / `i_rstn` inside
  `cdc/` blocks or pipelines) are **internal signals**, wired to `aclk` /
  `aresetn` inside the core. Do **not** expose them as top-level ports.

> ⚠️ **Why this matters — auto-inference is not enough.**
> `ipx::infer_bus_interfaces` guesses which clock drives which interface
> by heuristics. For a core with **two** clock domains it frequently
> attaches the AXI-Lite `s_axi` interface to `aclk` (the datapath clock)
> instead of `s_axi_aclk`. In the block design this surfaces as:
>
> ```
> CRITICAL WARNING [BD 41-1363] ... M0x_ACLK and <core>/aclk must be the same source
> ERROR [BD 41-237] FREQ_HZ / CLK_DOMAIN does not match between <core>/s_axi and .../M0x_AXI
> ```
>
> because Vivado now believes `s_axi` runs at the datapath frequency
> (e.g. 307.2 MHz) while the AXI interconnect master runs at the PS clock
> (e.g. 100 MHz).

### How the packager enforces this

`make package` (`scripts/ip_packager.py` + `package_ip.tcl.j2`) does **not**
rely on auto-inference for clock association. After
`ipx::infer_bus_interfaces` it explicitly re-associates, per the table above:

- `s_axi_aclk` → `ASSOCIATED_BUSIF = s_axi`, `ASSOCIATED_RESET = s_axi_aresetn`
- `aclk`       → `ASSOCIATED_BUSIF = <all AXI-Stream ifaces>`, `ASSOCIATED_RESET = aresetn`

It scans `BUS_TYPE_VLNV` for `*:axis:*` to collect every stream interface
automatically, and **overwrites** (not adds) `ACLK.ASSOCIATED_BUSIF` to
strip any `s_axi` the inferencer may have attached. This is generic: any
new core that follows the naming table above packages correctly with no
per-core configuration.

### Other clock names: `<ip>.clock_domains.yaml`

The generic rule above covers only `s_axi_aclk` and `aclk`. A core whose clocks have any other name (the processor's
`ps_clk_i` / `t_clk_i` / `c_clk_i`, the average buffer's `s_axis_aclk` / `m_axis_aclk`) is not recognised by
`ipx::infer_bus_interfaces`: its buses are packaged with no associated clock, and validating a block design that
uses it fails with `[BD 41-237] FREQ_HZ ... does not match` (seen on `axis_avg_buffer`, 2026-09-24). Declare the
domains in a sidecar next to the `.core`, read only by `ip_packager.py` (FuseSoC ignores it):

```yaml
# cores/ip/axis_avg_buffer/axis_avg_buffer.clock_domains.yaml
clock_domains:
  - name: s_axis_aclk              # the clock port
    interfaces: [s_axis]           # every bus it drives
    reset: s_axis_aresetn
  - name: m_axis_aclk
    interfaces: [m0_axis, m1_axis, m2_axis]
    reset: m_axis_aresetn
```

The packager (`package_ip.tcl.j2`) associates clocks in this order: (1) the domains of the YAML file; (2) the naming
convention per stream interface, `s0_axis*` to `s0_axis_aclk`, `m0_axis*` to `m0_axis_aclk`; (3) every stream interface
still unassigned to `aclk`. Custom QICK buses (`QPeriphA`, `q_peripheral`, `CORE_CTRL`, ...) are declared the same way, with their port maps,
in `<ip>.bus_interfaces.yaml` (see `cores/ip/xcom/xcom.bus_interfaces.yaml`). Today 9 IPs have a
`clock_domains.yaml` and 3 a `bus_interfaces.yaml`. Fix the packaging here and run `make package` again; never edit
`firmware/ip/`.

Verify a packaged core with:

```bash
grep -A1 "ACLK.ASSOCIATED_BUSIF\|S_AXI_ACLK.ASSOCIATED_BUSIF" ip/<name>/component.xml
# expected:
#   ACLK.ASSOCIATED_BUSIF        -> m_axis:s_axis   (NO s_axi)
#   S_AXI_ACLK.ASSOCIATED_BUSIF  -> s_axi
```

### Single-clock cores

If a core genuinely uses one clock for everything, name it aclk /
aresetn and let all interfaces (including s_axi) associate to it. The
packager handles this too (no s_axi_aclk present → only the aclk
association runs).
