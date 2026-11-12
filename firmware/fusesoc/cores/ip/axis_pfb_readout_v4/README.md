# PFB readout, 8 outputs (axis_pfb_readout_v4)

Splits the ADC stream into 64 frequency channels with a polyphase filter bank (50 % overlap), picks 8 of them, and
down-converts each with its own phase-coherent DDS. Used where many resonators share one ADC: every output is a
readout channel that the tProc-side buffers (avg_buffer) consume.

- VLNV: `qick:ip:axis_pfb_readout_v4:1.0.0` (module `axis_pfb_readout_v4`)
- Replaces: the legacy `QICK:QICK:axis_pfb_readout_v4:1.0` (openquantumhardware/qick `firmware/ip/axis_pfb_readout_v4`), with the
  same ports, parameter, register map and behaviour
- Driver: `readout.AxisPFBReadoutV4` (`qick_lib/qick/drivers/readout.py`), bound to the `qick:ip` VLNV;
  `driver/axis_pfb_readout_v4.py` is an alias of that module
- Used in: 216 `tpv2_std`, `tpv2_std_rfbv2`
- Built from: `qick:dsp:pfb_readout` (`pfb` = `pfb_firs` + `pfb_switch` + `ssrfft_8x64_sync` + `pimod_pfb`,
  `pfb_chsel`, `pfb_ddsprod`) and `qick:axi:axil_slv`. The FIRs (`fir_pfb_ro_0..7`), the FFT (`ssr_fft_8x64`, System
  Generator) and the DDS (`dds_compiler_pfb_ro`) are the legacy vendor blocks.

**How to read this file.** Part I is for someone who wants to use the IP. Part II is the reference.

---

# Part I -- Using the IP

## U1. What it does

```
 s_axis (4 samples/clk) --> PFB: 8 FIRs -> reorder -> 64-pt FFT -> pi-mod
                             | frame: 8 clocks x 8 words = 64 channels, one frame per 32 input samples
                             +--> chsel(ID0) -> x DDS0 (FREQ0, PHASE0) --> m0_axis
                             +--> chsel(ID1) -> x DDS1                  --> m1_axis
                             ...                                            (8 outputs)
```

With `fs` the input sample rate (4 per `aclk`): channel `k` (0..63) is centred on `k * fs / 64` (channels above 32 are
the negative frequencies), and every output gives one sample per 32 input samples (`fs / 32`, one per 8 `aclk`).

## U2. The rules that are not obvious

- **Channel k is `ID = (k % 8) << 8 | (k / 8)`.** The low byte is the clock within the PFB frame, the high byte the
  word within that clock. The driver computes it (`set_freq_int`: `packet = ch / 8`, `index = ch % 8`).
- **The DDS runs at the output rate.** `FREQ` is the phase step per output sample (`2^32` = one cycle per output
  sample). A tone at `(k + d) * fs / 64` comes out of channel `k` at `d / 2` cycles per output sample, so
  `FREQ = (d / 2) * 2^32` brings it to DC (checked in simulation, A within 1 %). The DDS is exp(-j phase).
- **Registers are read as they are.** ID/FREQ/PHASE cross from `s_axi_aclk` into `aclk` with no synchronizer (as in
  the legacy IP). Change them while the output is not being used.
- **All `m<i>_axis_tvalid` are the same strobe**, one clock every 8 `aclk`. There is no `tready` anywhere.
- **Output gain.** An in-channel tone of amplitude A comes out with magnitude ~A (1.007 A measured at channel 10,
  offset 0.2).
- **A reset in the middle of the stream can move the channels.** The filter bank's FIRs and FFT have no reset (as in
  the legacy IP). In simulation, a short `aresetn` pulse while samples are flowing moved channel 37 to another clock
  of the frame (the word stayed), so ID 37 then selected another channel; a later 300-clock reset did not
  always put it back. The legacy RTL behaves identically (co-simulated clock by clock through resets). From a fresh
  start (the FIRs and the FFT empty) the mapping above holds.

## U3. Data formats

`s_axis_tdata[32i +: 32]` = `{Q, I}` of input sample `i` (i = 0..3, oldest first), 16 bits each, signed.
`m<i>_axis_tdata` = `{Q, I}`, 16 bits each, signed.

```python
def decode(word):
    i = word & 0xffff;          i -= (i >> 15) << 16
    q = (word >> 16) & 0xffff;  q -= (q >> 15) << 16
    return complex(i, q)
```

## U4. Throughput and limits

One output sample per 8 `aclk` on each of the 8 outputs. The filter bank is fixed at 64 channels and 4 input samples
per clock (the FIRs and the FFT are built for them).

## U5. Python quick start

```python
soc = QickSoc(bitfile)
ro = soc.avg_bufs[0]            # the readout behind it is found by QickSoc
# through QickProgram: declare the readout with its frequency; the driver sets ID/FREQ/PHASE
```

## U6. Using it in a block design

| Parameter | Default | Standard BDs |
|---|---|---|
| `N` | 64 | 64 (only value built) |

| Clock / reset | Interfaces |
|---|---|
| `s_axi_aclk` / `s_axi_aresetn` | `s_axi` |
| `aclk` / `aresetn` | `s_axis` (the ADC), `m0_axis` .. `m7_axis` |

`constraints/axis_pfb_readout_v4.xdc` false-paths the register crossing.

## U7. Gotchas

| Symptom | Cause | What to do |
|---|---|---|
| A readout shows another channel's tone | ID has packet and index swapped, or a reset hit the stream (U2) | ID = `(k % 8) << 8 \| (k / 8)`; reset only from a stopped stream / power-up |
| The demodulated signal rotates | FREQ does not match the tone's offset inside the channel | FREQ = offset / (fs / 32) * 2^32 |
| A glitch when retuning | Registers cross without a synchronizer | Retune while the output is idle |

## U8. Validation status

| What | Where | Result |
|---|---|---|
| Legacy RTL, same behaviour | 216 tpv2_std | In production |
| Sub-blocks against the legacy RTL | each `qick:dsp` core's SVUnit (co-simulation) | all equal on every clock |
| Vendor models (FIRs, DDS) against the real cores | `fir_pfb_ro_model`, `dds_compiler_pfb_ro` `tests/vendor` | FIRs bit-exact; DDS within 19 counts |
| This IP | SVUnit (Part II) | 3/3 |
| This IP in the Top BDs | `validate_bd_design`, Vivado 2025.2 | See the CHANGELOG entry |
| This IP on hardware | A debug bench (RFSoC4x2, `axis_tone4` in place of the ADC, 12 outputs captured by a DMA) | 6/6 PASS (2026-11-04, `.bit` md5 `e8fd73ed`...): tone of channel 37 (offset 0.3) on every output at 0.9914 of its amplitude, -77 to -84 dBc on a channel without it, 14 channels from 0 to 63 at 1.0069 (offset 0.2), PHASE 2^30 = -90.4 deg, FREQ error 0.01 = -0.01000 cycles |

---

# Part II -- Reference

## Ports

| Port | Dir | Width | Notes |
|---|---|---|---|
| `s_axi_*` | | | AXI4-Lite, 8-bit address, `s_axi_aclk` |
| `aclk`, `aresetn` | in | 1 | datapath clock and reset |
| `s_axis_tvalid/tdata` | in | 1/128 | 4 samples per clock; no `tready` |
| `m<i>_axis_tvalid/tdata`, i = 0..7 | out | 1/32 | same `tvalid` on all; no `tready` |

## Registers

The driver class `AxisPFBReadoutV4` keeps a hand-written dictionary of this map, with the attribute names the software uses (`id<i>_reg`, `freq<i>_reg`, `phase<i>_reg`). The indexes are those of the legacy `axi_slv.v` (ID 0 to 7, then frequency and phase in pairs from word 8). `AxisPFBReadoutV3` (four outputs, `qick:ip:axis_pfb_readout_v3`) keeps its own dictionary: ID 0 to 3, then frequency and phase in pairs from word 4.

64 x 32-bit read/write registers (axil_slv; byte strobes honoured), reset 0. Used:

| Offset | Name (driver) | RTL name | Meaning |
|---|---|---|---|
| `0x00 + 4i` | `id<i>_reg` | `ID<i>_REG` | [7:0] clock in frame, [15:8] word (channel k = `{k%8, k/8}`) |
| `0x20 + 8i` | `freq<i>_reg` | `PINC<i>_REG` | DDS phase step per output sample |
| `0x24 + 8i` | `phase<i>_reg` | `POFF<i>_REG` | DDS phase offset |

`0x60..0xFC` are plain storage (as in the legacy slave). `rdl/axis_pfb_readout_v4_regmap.rdl` is the source for the
register-layer tests (`make driver IP=axis_pfb_readout_v4`, 4 passed).

## Verification

`make sim IP=axis_pfb_readout_v4`:

- `tc_registers_match_the_legacy_slave`: the legacy `axi_slv` on the same bus; 3000 random writes (random byte
  strobes) and reads over all 64 registers; every AXI output and every ID/FREQ/PHASE value equal on every clock, and
  reads equal to a byte-lane model
- `tc_register_map_reaches_the_datapath`: IDi/FREQi/PHASEi reach output i's selector and DDS
- `tc_tone_configured_over_axi_comes_out_as_dc`: output 5 on channel 37, FREQ5 on the tone's offset: constant
  output of magnitude A within 2 %, mean deviation < 2 LSB

The datapath below the registers is checked in `qick:dsp:pfb_readout` (wiring against the legacy v3 and v4 files,
tones end to end) and each of its cores against its legacy RTL.

`tests/vendor/run_vendor_check.sh` (needs Vivado and fusesoc): the IP as the QICK emulator has it (the behavioural FFT model
`qick:emulator:ssr_8x64`, the FIR and DDS models) against the same IP with the real System Generator FFT, the eight FIR
Compilers and the DDS Compiler generated from the .xci; two tones, eight outputs configured over AXI-Lite, 3000 clocks
recorded: at most 2 counts of difference on outputs of up to 2980, the same valid pattern (limit 4 counts). Three mutations
of the FFT model (latency, lane order, twiddle sign) are caught.

## Files

```
cores/ip/axis_pfb_readout_v4/
  README.md
  axis_pfb_readout_v4.core
  axis_pfb_readout_v4.clock_domains.yaml
  constraints/axis_pfb_readout_v4.xdc
  driver/axis_pfb_readout_v4.py -> qick_lib/qick/drivers/readout.py
  driver/tests/                            # register-layer pytest (make driver)
  hdl/axis_pfb_readout_v4.sv -> ../../../../../rtl_lib/ip/axis_pfb_readout_v4.sv
  rdl/                                     # regmap (docs, driver tests)
  tests/axis_pfb_readout_v4_tc00.sv, axis_pfb_readout_v4_tests.sv
  tests/ref/axi_slv_pfb_v4_legacy.v        # legacy register slave (golden model)
```

## Open items

- Package, switch the 216 BDs, synthesize (Vivado project) and run on the board (D5/D6 of firmware/docs/user/IP_INTEGRATION.md).
- Understand the frame shift after a mid-stream reset (U2): legacy behaviour, kept.
