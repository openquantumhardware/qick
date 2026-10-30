# AXIS Weighted Average + Buffer (axis_weighted_buffer)

`axis_avg_buffer` with a matched filter in front: before the samples reach the averager and the raw buffer they are
multiplied, sample by sample, by a **complex weight envelope** that software loads through a DMA stream. Instead of a plain
boxcar sum over the readout window, the result is a time-weighted integration, which is the optimal way to discriminate two
states whose signal trajectories differ in time.

- Project: QICK, `qick:ip:axis_weighted_buffer:1.3.0` (module `axis_weighted_buffer`, `N_AVG = N_BUF = N_WGT = 10`, `B = 16`)
- Driver: class `AxisWeightedBufferV1pt3` (base `AxisWeightedBuffer`, which derives from `AxisAvgBufferV1pt1`) in
  `qick_lib/qick/drivers/readout.py`. Its `bindto` **already lists `qick:ip:axis_weighted_buffer:1.3`**. Symlinked from
  `driver/axis_weighted_buffer.py`; register-layer test in `driver/tests/`
- Sibling and shared concepts (arm/trigger, averaged vs raw memory, the data readers, photon mode): `axis_avg_buffer`
- Hardware bring-up: none of this fusesoc version (see U8)

**How to read this file.** Part I is for someone who wants to use the IP. Part II is the reference.

---

# Part I -- Using the IP

## U1. What it does

```
 weights (DMA) --s1_axis_weights (complex, {Q,I})--> weight memory 2^N_WGT --+
                                                                              v
 readout --s_axis (I/Q, B bits each)--> complex multiply by the envelope --> averager (2^N_AVG)  --> m0_axis
              trigger ------------------ (delayed to match the multiplier) --> raw/filtered buffer (2^N_BUF) --> m1_axis
                                                                          --> m2_axis: each averaged result, to a tProc register
 AXI4-Lite registers: arm, address, length, data readers (averaged, buffer, weights)
```

The multiply is complex: `out_I = I*wI - Q*wQ`, `out_Q = I*wQ + Q*wI`, each partial product a signed 16x16 multiply
**truncated** (not rounded, no saturation) to a B-bit window of the 32-bit product, selected by `wgt_trunc_reg`.
It resets to `B` (16), which reproduces the original fixed upper-16-bits truncation exactly. The
trigger is resynchronised and delayed inside the IP so that the capture window starts when the filtered data are
available.

## U2. Rules that are not obvious

Everything in `axis_avg_buffer`'s U2 applies (levels, arm then trigger, lengths below the memory size, even transfers,
photon mode). What is different here:

- **The register map is not the avg buffer's.** `AVG_START_REG` and `BUF_START_REG` are bits 0 and 1 of one register,
  `start_reg`; the three data readers are bits 0, 1 and 2 of `dr_start_reg` (averaged, buffer, weights). The driver's
  `enable(avg, buf)` ORs the bits, `disable()` clears `start_reg`, and only one reader is used at a time. Do not use the
  avg-buffer register names on this block.
- **Load the weights before the capture.** `load_weights(data, addr)` sets `wgt_dw_addr_reg`, enables the weight data
  stream (`dr_start_reg = 4`), sends the (n, 2) int16 array through the weights DMA and stops it. The maximum is
  `2**N_WGT` samples. The envelope has to cover the readout window: `avg_len_reg` is also the window length of the matched
  filter.
- **Weights are complex** (`{Q[31:16], I[15:0]}`, int16 each). A weight envelope of 1.0 (32767) is not unity gain, because
  the product is truncated (right-shifted by `wgt_trunc_reg`, default `B`): the output is `in * weight / 2**wgt_trunc_reg`
  in raw counts. The driver's `set_trunc(shift)` changes it; `set_trunc()` (no argument) restores the default.
- **The raw buffer holds filtered data** (`m1_axis` is the filtered stream, not the raw ADC samples).
- **The weight write uses `s_axi_aclk`.** The DMA that writes the weight memory is clocked by the AXI clock (as in the legacy
  IP), while the capture runs on `s_axis_aclk` and the readout on `m_axis_aclk`.
- **First-output-sample bug** fixed in this revision (>= 1.3); `AxisWeightedBufferV1pt3` skips the software workaround that
  older classes apply (the same story as `axis_avg_buffer` 1.2).

## U3. Data formats

- Input `s_axis_tdata`: `{Q, I}`, `B` = 16 bits each. Weights: 32-bit words `{Q, I}` int16.
- Averaged memory: pairs of 32-bit accumulated I, Q (a **sum**); raw/filtered memory: `{Q, I}` int16 per 32-bit word; `m2_axis`:
  each averaged result as it is computed (as in `axis_avg_buffer`).
- Internally the multiplier uses I in the upper half and Q in the lower and repacks on output; the outside convention is
  the avg buffer's (I low, Q high).

## U4. Memories, throughput and limits

- Averaged memory `2**N_AVG`, raw/filtered memory `2**N_BUF`, weight memory `2**N_WGT` (1024 each by default). The driver
  reads them from the block design (`avg_maxlen`, `buf_maxlen`, `wgt_maxlen`).
- Throughput: one sample per clock at the readout's decimated rate.
- Latency: a fixed pipeline for the multiplier (about 4 + 3 clocks in the legacy design); the trigger is delayed to match.

## U5. Python quick start

```python
buf = soc.axis_weighted_buffer_0
buf.load_weights(np.stack([w_i, w_q], axis=1).astype(np.int16), addr=0)   # once per weight set
buf.config_avg(address=0, length=100)                                     # window = weights length
buf.enable(avg=True, buf=True)                                            # armed; the tProc trigger starts it
iq = buf.transfer_avg(address=0, length=100)                              # after the program ran
```

In practice `AveragerProgramV2` uses it (weights are configured through the program's readout setup).

## U6. Using it in a block design

- `s_axis` <- a readout's decimated output; the weight stream (RTL ports `s1_axis_*`) <- an AXI DMA (through a switch if shared).
  **The driver traces the interface by the name `s1_axis_weights`** (the name the legacy package gave it); check that the
  packaged block from this core exposes that name (if the packager infers `s1_axis` from the port prefix, `configure_connections`
  cannot find the weights DMA). Not verified: it needs a `make package` and a look at the block design. `m0_axis`, `m1_axis` -> AXI DMAs; `m2_axis` -> a tProc input (optional); `trigger` <- the tProc.
- Parameters: `N_AVG`, `N_BUF`, `N_WGT`, `B`.
- Clocks: `s_axi_aclk` (registers and weight write), `s_axis_aclk` (capture), `m_axis_aclk` (readout).

## U7. Gotchas

| Gotcha | What happens | What to do |
|---|---|---|
| Capturing before loading the weights | Whatever the weight memory holds multiplies the data | Load the weights first |
| Expecting unity gain from weight 1.0 | The product is truncated to the upper half: gain `weight / 2**16` | Scale the weights and the result together |
| Using the avg-buffer register names | They do not exist here | Use `start_reg` / `dr_start_reg` through the driver |
| Weight envelope shorter than the window | The rest of the window is multiplied by whatever the weight memory holds | Load a full window |
| Reading `m1_axis` as raw ADC | It is the filtered stream | Use a plain `axis_avg_buffer` for raw data |

## U8. Validation status

- **Simulation**: 3 SVUnit tests: reset state, register read-back, and a capture with weights loaded and read back through
  the buffer (`test_weighted_buf_readback`).
- **Hardware**: this fusesoc packaging has not been built into a bitstream or run on a board. The datapath is a port of the
  legacy 1.3 IP. The software support for the weighted buffer exists (`qick` PR #335, with a demo notebook and test firmwares);
  none of that was re-run against this packaging.
- Not verified: the numerical output of the matched filter against a reference, the latency in clocks, the photon mode and the
  averager with weights over many shots.

---

# Part II -- Reference

## Ports

| Port | Dir | Notes |
|---|---|---|
| `s_axi_*`, `s_axi_aclk`, `s_axi_aresetn` | | AXI4-Lite slave; also the weight-write clock |
| `s_axis_aclk`, `s_axis_aresetn`, `s_axis_tdata[2*B-1:0]`, `tvalid`, `tready` | | I/Q input |
| `s1_axis_tdata[2*B-1:0]`, `s1_axis_tvalid`, `s1_axis_tready` | | weight stream (the legacy package names this interface `s1_axis_weights`) |
| `m_axis_aclk`, `m_axis_aresetn` | in | read-side clock and reset |
| `m0_axis_*`, `m1_axis_*`, `m2_axis_*` | out | averaged, filtered-buffer, averaged-live |
| `trigger` | in | asynchronous capture trigger |

## Registers

The driver takes the word index of each register from this map: `AxisWeightedBufferV1pt3` (the class that binds `qick:ip:axis_weighted_buffer:1.3`) reads `axis_weighted_buffer_regmap_pkg` (generated from `rdl/axis_weighted_buffer_regmap.rdl`, installed in `qick_lib/qick/rdl_pkgs/` by `make driver IP=axis_weighted_buffer`; `make driver-check` fails if the committed copy no longer matches the RDL) and keeps the attribute names the software uses; `regs` is the register model for field access. Two names differ from the RDL: `avg_h_threshold_reg` / `avg_l_threshold_reg` are `AVG_H_THRSH_REG` / `AVG_L_THRSH_REG`. The indexes are the ones the driver has always used and the legacy `axi_slv.vhd` wires (`START_REG` word 0 and `DR_START_REG` word 3 pack the AVG, BUF and weight-write start bits of one word each); a test pins the old dictionary. `WGT_TRUNC_REG` (word 14) is not wired in the public legacy `axis_weighted_buffer`: on legacy firmware a write to `wgt_trunc_reg` goes to a register that nothing reads. `AxisWeightedBuffer` (1.2) exists only as legacy firmware: no RDL, no `regs`, same map as before.

| Addr | Register | Description |
|---|---|---|
| 0x00 | `start_reg` | bit 0 averager enable, bit 1 buffer enable (levels) |
| 0x04 | `avg_addr_reg` | averager write start address |
| 0x08 | `avg_len_reg` | averager sample count; also the matched-filter window length |
| 0x0C | `dr_start_reg` | bit 0 averaged reader, bit 1 buffer reader, bit 2 weight data stream |
| 0x10 | `avg_dr_addr_reg` | averaged reader start address |
| 0x14 | `avg_dr_len_reg` | averaged reader sample count |
| 0x18 | `buf_addr_reg` | buffer write start address |
| 0x1C | `buf_len_reg` | buffer sample count |
| 0x20 | `buf_dr_addr_reg` | buffer reader start address |
| 0x24 | `buf_dr_len_reg` | buffer reader sample count |
| 0x28 | `avg_photon_mode_reg` | averager mode (bit 0: 0 accumulate, 1 edge counter) |
| 0x2C | `avg_h_threshold_reg` | photon mode high threshold |
| 0x30 | `avg_l_threshold_reg` | photon mode low threshold |
| 0x34 | `wgt_dw_addr_reg` | weight memory DMA write start address |
| 0x38 | `wgt_trunc_reg` | matched-filter output right-shift; resets to `B` |

Source: `rdl/axis_weighted_buffer_regmap.rdl`; matches `AxisWeightedBuffer.REGISTERS` in the driver.

## Verification

`tests/axis_weighted_buffer_tests.sv`: `test_reset_idle`, `test_register_readback`, `test_weighted_buf_readback`,
`test_configurable_truncation`. `make sim IP=axis_weighted_buffer`.

## Files

```
cores/ip/axis_weighted_buffer/
  README.md
  axis_weighted_buffer.core          # VLNV qick:ip:axis_weighted_buffer:1.3.0
  hdl/axis_weighted_buffer.sv        # AXI-Lite wrapper + weighted_buffer (rtl_lib/math)
  rdl/axis_weighted_buffer_regmap.rdl
  driver/axis_weighted_buffer.py -> qick_lib/qick/drivers/readout.py ; driver/tests/
  tests/
```

Datapath: `rtl_lib/math/weighted_buffer.sv`, `rtl_lib/dsp/matched_filter.sv`, `avg_top.sv`, `buffer_top.sv`.

## Open items

- Driver: the VLNV is already in `bindto`; what is left of the `qick_time_tagger` flow is the per-IP driver file and a
  board validation.
- The interface name of the weight stream in the packaged IP (`s1_axis_weights` in the legacy package; the driver depends on it).
- A numerical test of the complex multiply and the truncation against a software model.
