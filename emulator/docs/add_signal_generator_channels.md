# User Guide: Adding Signal Generator Channels to QICKEmu

This guide explains how to extend the emulated QICK design when you need more signal generator (SG) channels than the default two-channel emulator setup.

The short version is:

1. A new SG channel must exist in the underlying QICK_DUT design before the emulator can model it.
2. The emulator configuration must describe the new channel.
3. The current SystemVerilog harness must be extended, because it is still wired explicitly for two SG channels.

This is therefore not a config-only change.

## Current State

The baseline emulator notebook, `emulator/notebooks/00_intro_emu_2sg.ipynb`, currently initializes `QickEmu` with `emulator/notebooks/qick_emu_config.json`. That config exposes two SG entries:

- `axis_signal_gen_v6_0` on `tproc_ch = 0`, routed to DAC `00`
- `axis_signal_gen_v6_1` on `tproc_ch = 1`, routed to DAC `01`

The config file itself already states the maintenance rule for this setup:

> It has to be updated if the emulated DUT is modified.

That statement is literal. If you add generators to the DUT, you must update the emulator description to match.

For a larger reference configuration, see `emulator/notebooks/qick_config_216.json`, which shows how a bigger `gens` array is represented in software.

## Architecture Boundary

At the Python layer, SG channels are already modeled as a list of generator descriptions.

- `qick_lib/qick/drivers/generator.py` defines the generator abstractions and channel-to-DAC/tProc discovery.
- `qick_lib/qick/qick_asm.py` and `qick_lib/qick/asm_v1.py` program generators by index in the `gens` list.
- `emulator/software/source/qick_emu.py` builds a software-visible address map from the config and replays register writes into the testbench.

That means the programming model is already prepared for `gens[2]`, `gens[3]`, and so on.

The real bottleneck is below that layer: the current emulator harness only exposes two SG DMA ports, two SG-to-DAC paths, and an envelope-load task that rejects channel indices greater than 1.

## Before You Touch the Emulator

Add the new channel to the DUT design first.

At minimum, the new generator channel must have:

1. An SG IP instance in the hardware design.
2. A unique tProcessor output channel assignment.
3. A unique DAC route.
4. A stable instance name and base address that can be exported into the QICK config.

If the new channel does not exist in the DUT, the emulator cannot create it by itself.

## Step 1: Add more instances of an already supported SG IP

This is the easier path.

Examples:

- another `axis_signal_gen_v6`

`emulator/software/source/qick_emu.py` already defines register layouts for those IP types, so the emulator usually only needs:

- a new config entry
- a unique base address
- harness wiring for the extra channel

## Step 2: Update the Emulator Config

Edit `emulator/notebooks/qick_emu_config.json` and add one `gens` entry per new SG channel.

For each new entry, make sure these fields are correct and unique where applicable:

- `fullpath`
- `type`
- `dac`
- `tproc_ch`
- `fs`
- `f_fabric`
- `fs_mult`
- `fs_div`
- `f_dds`
- `fdds_div`
- `maxlen`
- `samps_per_clk`
- `phys_addr`
- `addr_range`

Use the existing two entries in `qick_emu_config.json` as the template for formatting and required fields. Use `qick_config_216.json` as the template for how larger generator arrays are organized.

### Important checks

- `fullpath` must match the DUT instance name.
- `tproc_ch` must match the actual tProcessor route.
- `dac` must match the actual DAC route.
- `phys_addr` must not collide with another block.

If any of these values are wrong, the emulator may run but the wrong block will be configured.

## Step 3: Check Python-Side Emulator Support

Inspect `emulator/software/source/qick_emu.py` before editing the testbench.

Today it already contains SG register definitions for:

- `axis_signal_gen_v6`

For those types, adding more instances is usually a metadata problem, not a driver-design problem.

You still need to confirm that:

1. The new instance appears in the config.
2. The instance base address is exported into the address map.
3. The replayed AXI writes target the expected `fullpath`.

## Step 4: Extend the Testbench Harness

This is the main implementation step.

The current `emulator/testbench/QICKEmu_harness.sv` is explicitly written for two SG channels. You must generalize or replicate the affected sections for each added channel.

### 4.1 Add new SG waveform-stream ports

The harness currently declares separate waveform-stream signals for only:

- `sg0_s0_axis_*`
- `sg1_s0_axis_*`

To add channel 2, channel 3, or more, add corresponding signal declarations and connect them through the DUT instance.

Minimum required pattern per new channel:

- clock wire for the SG waveform AXIS input
- `tdata`
- `tvalid`
- `tready`

If you are adding several channels, consider converting these signals into arrays instead of repeating one signal group per channel. That reduces future editing.

### 4.2 Add new DUT port hookups

The DUT instantiation currently contains explicit blocks for:

- `sg0_s0_axis_*`
- `sg1_s0_axis_*`
- `axis_sg0_dac0_*`
- `axis_sg1_dac1_*`

You must add matching connections for every new SG port that exists in the DUT wrapper.

If your DUT wrapper is also hard-coded to two SG ports, you must extend that wrapper first.

### 4.3 Add DAC-side modeling for each new SG

The harness currently models two DAC paths with separate sections:

- SG0 to DAC0
- SG1 to DAC1

Each path includes:

- AXIS ready/valid/data wiring
- sample extraction from the wide SG output bus
- `model_DAC`
- `model_ADC` loopback path
- per-channel sample counter and data registers

When you add a new generator channel, decide how it will be observed:

- looped back into a new ADC model
- routed into an existing observation path
- captured only as a DAC CSV stream

The simplest first extension is usually to copy the SG1 pattern into SG2, then decide whether you need a corresponding ADC/readout path or only DAC visibility.

### 4.4 Extend DAC CSV capture if needed

The harness currently writes DAC CSV files for the existing SG outputs. If you want to inspect the new generator output in the same way, add a CSV handle and logging block for the new path.

Without this step, the channel may be active but harder to verify.

### 4.5 Generalize the envelope-loading task

The envelope loader task is the most obvious two-channel guardrail.

In `sg_load_mem_emu`, the harness currently does all of the following with only channels 0 and 1 in mind:

- rejects `sg_ch >= 2`
- clears only `sg0_s0_axis_*` or `sg1_s0_axis_*`
- waits only on `sg0_s0_axis_tready` or `sg1_s0_axis_tready`
- drives only `sg0_s0_axis_tdata` or `sg1_s0_axis_tdata`

You must update this task so it can stream `sgmem_chN.mem` into every supported SG channel.

There are two implementation strategies.

#### Strategy 1: Extend the `if` / `else if` chain

This is quick for adding one extra channel.

Add `sg2`, `sg3`, and so on everywhere the task currently branches on `sg_ch`.

Use this when you want the smallest localized change.

#### Strategy 2: Convert the per-channel SG ports to arrays

This is the better long-term design.

Represent the waveform-stream signals as indexed arrays, then rewrite `sg_load_mem_emu` to index them with `sg_ch`.

Use this when you expect to add channels more than once.

## Step 5: Update Startup Memory Loading

The simulation startup flow currently loads tProc memories and then explicitly loads only `sgmem_ch0.mem`.

If your workload uses envelopes on more than one SG channel, update the startup sequence so it loads every required `sgmem_chN.mem` file before replaying AXI writes and starting the tProcessor.

At minimum, change the startup flow from a one-channel load to a per-channel loop or a list of explicit calls.

If you skip this step, the extra SG channel may exist and be configured correctly but still run with an empty waveform memory.

## Step 6: Validate the Address Map

Before running a full simulation, confirm that the emulator's software view and DUT view still agree.

Check these items:

1. The new SG instance name in the DUT matches the `fullpath` in `qick_emu_config.json`.
2. The configured `phys_addr` is unique.
3. The SG type string matches an emulator-supported register definition.
4. The QICK program targets the expected generator index.

If the channel count changed but the addresses or `fullpath` values did not, the wrong AXI writes may be replayed.

## Step 7: Run a Minimal Validation Program

After the structural edits, validate with the smallest possible test.

Recommended validation sequence:

1. Add the new `gens` entry.
2. Build or rerun the Verilator testbench.
3. Run a minimal QICK program that targets only the new generator channel.
4. Generate or load `sgmem_chN.mem` for that channel if the pulse uses an envelope.
5. Inspect the DAC CSV output for activity on the new SG path.

The most useful first test is a single pulse on the new channel with all other SG channels idle.

That isolates routing errors from program-level timing issues.

## Worked Example: Adding SG Channel 2 as `axis_signal_gen_v6_2`

Use this as the lowest-risk extension path.

### DUT side

1. Instantiate another `axis_signal_gen_v6` in the hardware design.
2. Route it to a free tProcessor output channel.
3. Route it to a free DAC path.
4. Export its instance name and base address.

### Emulator config side

Add a third `gens` entry to `emulator/notebooks/qick_emu_config.json` with fields matching the new instance, for example:

- `fullpath: axis_signal_gen_v6_2`
- `type: axis_signal_gen_v6`
- `tproc_ch: 2`
- `dac: "02"`

Use the real address and clock values from your DUT, not placeholders.

### Harness side

Add:

- `sg2_s0_axis_aclk`
- `sg2_s0_axis_tdata`
- `sg2_s0_axis_tvalid`
- `sg2_s0_axis_tready`
- `axis_sg2_dac2_tready`
- `axis_sg2_dac2_tvalid`
- `axis_sg2_dac2_tdata`

Then update:

- DUT instantiation port map
- DAC extraction and optional CSV logging
- `sg_load_mem_emu`
- startup memory loading sequence

### Software validation side

Run a pulse program that targets generator index 2 and confirm:

- the program exports `sgmem_ch2.mem` when needed
- the harness accepts `sg_ch == 2`
- the SG2 DAC path shows activity in the output artifacts

## Recommended Refactor If You Expect More Growth

If you expect to add SG channels more than once, do not keep scaling the current harness by copy-paste alone.

The best long-term cleanup is:

1. Convert per-channel SG waveform ports into arrays.
2. Convert per-channel DAC paths into arrays where practical.
3. Rewrite `sg_load_mem_emu` to index arrays by `sg_ch`.
4. Replace one-off startup envelope loads with a loop over active channels.

That turns future SG expansion into a mostly config-driven change.

## Files You Will Usually Touch

- `emulator/notebooks/qick_emu_config.json`
- `emulator/software/source/qick_emu.py`
- `emulator/testbench/QICKEmu_harness.sv`
- the QICK DUT wrapper or generated top-level used by the testbench

You may also need to update notebooks or examples if you want the new channel to appear in the standard emulator demos.

## Final Checklist

Before considering the change complete, confirm all of the following:

- the DUT contains the new SG instance
- the new channel has a unique tProcessor route
- the new channel has a unique DAC route
- `qick_emu_config.json` contains the new `gens` entry
- the SG type is supported by `qick_emu.py`
- the harness exposes the new SG waveform port
- the harness exposes the new SG-to-DAC path
- `sg_load_mem_emu` accepts the new channel index
- startup logic loads `sgmem_chN.mem` when required
- the output artifacts show activity on the new SG path

If any item in that list is missing, the channel expansion is only partial.