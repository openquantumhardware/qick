# AXIS KID Simulator (axis_kidsim_v3)

A simulator of a **kinetic inductance detector (KID)** readout: a stream of complex samples goes in, the block reproduces
what a resonator would do to it, and the modified stream comes out. Each of `L` parallel lanes demodulates its input by a
DDS carrier (optionally chirped), filters it with a one-pole, one-zero IIR (the resonator response) and remodulates it, so
a firmware can be tested against a resonator with known, controllable parameters without cryogenic hardware.

- Project: QICK, `qick:ip:axis_kidsim_v3:1.0.0` (module `axis_kidsim_v3`, `L = 8`)
- Driver: `AxisKidsimV3` in `cores/ip/axis_kidsim_v3/driver/axis_kidsim_v3.py`.
  - A standalone `SocIP`, since kidsim is not a QICK channel type (`firmware/docs/user/IP_INTEGRATION.md`).
  - `bindto = ['qick:ip:axis_kidsim_v3:1.0']`.
  - Not installed in `qick_lib/qick/drivers/` yet: `make driver IP=axis_kidsim_v3` does it locally.
  - Methods: `config_lane()` / `config_all()`, `q15()` / `from_q15()`; `.regs` for the registers.
- Hardware bring-up: RFSoC4x2, a debug bench; the first board run found
  the latency bug of U2, the re-run on the fixed bitstream passes every check (2026-09-22, U8)

**How to read this file.** Part I is for someone who wants to use the IP. Part II is the reference.

---

# Part I -- Using the IP

## U1. What it does

```
 s_axis (32*L bits: L lanes of {Q,I}, tlast = end of frame)
      |
   puncturing: the simulator acts on one sample position per frame (PUNCT_ID)
      |
   per lane:  x e^{-jwt}  --> IIR (C0, C1, G) --> x e^{+jwt}      w(t) = DDS_FREQ plus an optional chirp ramp
      |
   OUTSEL: 0 processed signal | 1 DDS carrier | 2 input bypass | 3 zero
      |
 m_axis (32*L bits) ; trigger[L-1:0] starts a frequency modulation per lane
```

The carrier `w(t)` is set by `DDS_FREQ_REG` and can be **chirped**: a ramp starts at `DDS_BVAL`, changes by `DDS_SLOPE` per step
for `DDS_STEPS` steps, waiting `DDS_WAIT` processed samples per step, and is started by the lane's `trigger` bit. The IIR models the
resonator: `C0` (the zero) and `C1` (the pole) are Q15 coefficients and `G` is the output gain (`0x7FFF` is about 1.0).

## U2. Rules that are not obvious

- **Per-lane configuration goes through one address/enable pair.** A write with `WE_REG = 1` lands on the lane numbered
  `ADDR_REG` (RTL header): write the parameters, set `ADDR_REG` to the target lane and pulse `WE_REG`. To configure `L` lanes,
  repeat the sequence for each lane.
- **`WE_REG` crosses into the datapath clock** inside the lane logic; the trigger of each lane is resynchronised too.
- **Puncturing.** A *frame* is a burst of valid samples ending with `tlast`; `PUNCT_ID_REG` selects one sample index within the
  frame, and only that sample is processed by the simulator (frame example: with `PUNCT_ID = 2`, sample 2 of every frame). Set it to
  the resonator slot you want to act on. The other samples of the frame leave through the bypass, unchanged.
- **The resonator advances once per processed sample, not per clock.** The DDS, the IIR and the chirp ramp all move only on the
  selected sample of each frame, whatever the gap between frames. So every rate is per processed sample: the DDS phase step is
  `DDS_FREQ` per sample, the pole decays as `C1` per sample, and `DDS_WAIT` counts samples. In a firmware where `punct` picks one
  slot of each frame of `N` samples, that is one step every `N` clocks.
- **Output select.** `0` is the full demodulate / filter / remodulate result, `1` the DDS carrier alone (to look at the chirp), `2`
  a bypass of the input, `3` zeros. All paths are delay-balanced to the same latency.
- **Latency: 16 clocks from `s_axis` to `m_axis`** (puncturing 2, then the main path of 14: DDS control 2, first product 4, IIR 4,
  second product 4), and the bypass paths are balanced to it. The DDS IP adds **0 clocks**: its output valid comes out in the same
  clock as its input valid, carrying the carrier of the transaction 8 samples earlier (its `Latency = 8` is 8 transactions, not
  8 clocks). An earlier port counted it as 8 clocks (main path 22, total 24); on the board the output mux then never saw the
  processed sample and every sample left through the bypass (found 2026-09-22 on the RFSoC4x2, fixed; Part II, Latency).
- **Numerical fidelity.** With `C0 = 0`, `C1 = 0` and `G = 32767` the demodulate/remodulate chain recovers the input to within about
  3 LSB across a whole chirp sweep for an input of about 8000 (measured in simulation); the residual comes from `G` being
  32767/32768, the IIR truncation, two round-half-up complex multipliers and the sine/cosine quantisation.
- **Signed Q15 fields** (`BVAL`, `SLOPE`, `C0`, `C1`, `G`) use the lower 16 bits of their register.
- **`STEPS = N`, `WAIT = W`:** `W = 0` gives one chirp step per processed sample, `W` gives one step every `W + 1` samples.

## U3. Data formats

- `s_axis_tdata`, `m_axis_tdata`: `32 * L` bits, lane `i` in bits `[32*i +: 32]` as `{Q[15:0], I[15:0]}`.
- Registers: 16-bit fields in 32-bit registers (list in Part II); `OUTSEL` is 2 bits.
- `trigger`: one bit per lane, asynchronous (resynchronised inside).

## U4. Memories, throughput and limits

No memory beyond pipeline registers. The stream runs at one sample per lane per clock (`L` lanes, default 8), with no `tready`
on either side; the resonator of each lane advances on one sample per frame (U2).

## U5. Python quick start

```python
from qick import QickSoc
soc = QickSoc(bitfile, no_tproc=True, no_rf=True)   # a debug bench: no tProc, no RFDC; a full firmware needs neither flag
k = soc.axis_kidsim_v3_0                     # AxisKidsimV3, bound by QickSoc; k['lanes'] is the IP's L

# lane 3: processed signal, carrier 0x0400 per processed sample, pole 0.99, unity gain, act on sample 2 of each frame
k.config_lane(3, outsel=k.OUT_SIGNAL, freq=0x0400, c1=k.q15(0.99), g=k.G_UNITY, punct=2)
k.config_all(outsel=k.OUT_BYPASS)            # every lane back to bypass
```

`config_lane()` always writes every field, then `ADDR_REG` and a `WE_REG` pulse. The staging registers are shared by
all lanes, so writing only the fields that changed would give the new lane the leftovers of the previous one
(U2). Values are register words: use `q15()` for the Q15 fields (`c0`, `c1`, `g`, `bval`, `slope`).
`model/kidsim_resonator.py` converts physical resonator parameters to these words (`coeffs_from_resonator`).

## U6. Using it in a block design

- `s_axis` <- a stream of `L` packed complex lanes with `tlast` marking frames; `m_axis` -> the consumer; `aclk` / `aresetn`: the
  datapath clock. `s_axi` -> the PS interconnect (`s_axi_aclk`, a separate domain, 8-bit address). `trigger[L-1:0]` <- the
  logic that starts the chirp of each lane.
- Parameter `L` (default 8).
- Debug bench: RFSoC4x2, DMA loopback, no RFDC.

## U7. Gotchas

| Gotcha | What happens | What to do |
|---|---|---|
| Setting the lane parameters but not `WE_REG` | Nothing reaches the lane | Address the lane and pulse `WE_REG` |
| Forgetting to select the lane (`ADDR_REG`) | The write goes to the previous lane | Set `ADDR_REG` before each `WE_REG` |
| `PUNCT_ID` outside the frame | No sample is processed | Keep it below the frame length |
| Comparing input and output time-aligned | 16 clocks of latency | Account for it |
| Scaling rates by the clock | The resonator moves one step per processed sample, not per clock | Use the rate of the selected samples (U2) |
| Expecting the processed path right after configuration | The DDS gives no output for its first 8 processed samples; those leave through the bypass | Send 8 samples through the slot first |
| Expecting the modulation to run without a `trigger` | The per-lane modulation trigger is what starts it (RTL header) | Pulse the lane's trigger bit |

## U8. Validation status

- **Simulation**: `axis_kidsim_v3` 8/8, `kidsim_top` 6/6, `kidsim` 4/4 SVUnit tests: per-lane data routing, write-enable
  addressing of a lane, output valid on lane 0, DC and RF pass-through, the carrier, the ring-down of the pole, the field held
  across a frequency jump, `punct` zeroing exactly one sample of a frame, and sparse one-sample frames stepping the carrier by
  `DDS_FREQ` each. The DDS is simulated with a model checked against the Xilinx IP's own simulation model (Part II, Latency).
- **Hardware, first run (RFSoC4x2, debug bench, 2026-09-22)**: build met timing; register read-back and the bulk bypass
  (8 lanes, 4096 beats, bit-exact) passed, but the resonator path never reached the output (the output was always the input,
  `OUTSEL = 3` zeroed nothing, the carrier did not turn). Cause and fix in Part II, Latency.
- **Hardware, re-run on the fixed bitstream (same day)**: all 8 checks of the validation notebook pass, with
  the resonator stepped once per DMA transfer: register read-back; bulk bypass bit-exact on 8 lanes (4096 beats); `punct`
  replaces exactly beat `PUNCT_ID` of the addressed lane; carrier amplitude and phase step per sample equal to `DDS_FREQ` on
  every lane; IIR step response equal to H(z) and ringdown tau equal to 1/(-ln C1) samples; Lorentzian |H| against
  detuning, and a notch programmed from (kappa_i, kappa_c) with `kidsim_resonator.coeffs_from_resonator` fitted back to the
  programmed kappa and kappa_c; chirp on one lane's trigger bit following `FREQ - (B - nM)` with the other lanes still; a
  mid-stream `FREQ` jump with the carrier phase continuous and the output following the model. The DDS must see 8 processed
  samples first (U7).
- Not verified: the resonator at a real firmware's rate (a PFB channel stream with `punct` picking one slot per frame), the
  chirp or jump triggered by a tProc at a precise time, and the CDC of `WE` / `trigger` (one clock in the debug bench).

---

# Part II -- Reference

## Ports

| Port | Dir | Notes |
|---|---|---|
| `s_axi_*` | | AXI4-Lite slave, 8-bit address |
| `aclk`, `aresetn` | in | datapath clock and reset |
| `trigger[L-1:0]` | in | per-lane modulation trigger |
| `s_axis_tdata[32*L-1:0]`, `tvalid`, `tlast` | in | input frames |
| `m_axis_tdata[32*L-1:0]`, `tvalid`, `tlast` | out | output |

## Registers

| Addr | Register | Bits | Description |
|---|---|---|---|
| 0x00 | `DDS_BVAL_REG` | [15:0] | chirp ramp start B (signed Q15) |
| 0x04 | `DDS_SLOPE_REG` | [15:0] | chirp ramp slope M per step (signed Q15) |
| 0x08 | `DDS_STEPS_REG` | [15:0] | number of chirp ramp steps N |
| 0x0C | `DDS_WAIT_REG` | [15:0] | wait cycles W per step (0: one step per cycle) |
| 0x10 | `DDS_FREQ_REG` | [15:0] | DDS base phase increment |
| 0x14 | `IIR_C0_REG` | [15:0] | IIR feed-forward (zero) coefficient, Q15 |
| 0x18 | `IIR_C1_REG` | [15:0] | IIR feed-back (pole) coefficient, Q15 |
| 0x1C | `IIR_G_REG` | [15:0] | IIR gain, Q15 (0x7FFF ~ 1.0) |
| 0x20 | `OUTSEL_REG` | [1:0] | 0 signal, 1 DDS, 2 bypass, 3 zero |
| 0x24 | `PUNCT_ID_REG` | [15:0] | puncturing sample index within a frame |
| 0x28 | `ADDR_REG` | [ADDR_W-1:0] | target lane for a configuration write |
| 0x2C | `WE_REG` | [0] | write enable: 1 (with `ADDR_REG` set) latches the configuration into the lane |

Source: `rdl/axis_kidsim_v3_regmap.rdl`.

## Verification

`tests/axis_kidsim_v3_tests.sv` (8 tests, U8). `make sim IP=axis_kidsim_v3`; the lane is tested in `kidsim_top` (6 tests) and
`kidsim` (4 tests). Board validation: a notebook on the RFSoC4x2 debug bench.

## Latency

| Path | Clocks | Source |
|---|---|---|
| puncturing (`punct`) | 2 | valid/last pipeline |
| DDS control (`dds_phase_ctrl`) | 2 | `DDS_LATENCY = 2` |
| DDS IP (`dds_phasegen_sincos_ow16_lat8`) | **0** | output valid = input valid, word of 8 transactions earlier |
| first product (demodulation) | 4 | `cmult` |
| IIR | 4 | `iir_iq` |
| second product (remodulation) | 4 | `cmult` |
| `kidsim` main path | 14 | `KIDSIM_LAT = 14` |
| `kidsim_top`, `s_axis` to `m_axis` | 16 | valid, bypass and processed data all at 16 |

The DDS IP (Phase_Increment `Streaming`, no `TREADY`) moves its pipeline only on its input valid. Run from its own xsim model
(`dds_compiler_v6_0_28`), its output valid comes out in the same clock as the input valid and carries the output of the
transaction 8 valids earlier; the first 8 transactions after power-up give no output valid. So its `Latency = 8` is a delay
of 8 processed samples, not 8 clocks. With a CW carrier that is a constant phase; with a chirp the input is demodulated by the
frequency commanded 8 samples earlier. Remodulation reuses the same carrier word, so the carrier still cancels exactly.

History: the port first used `DDS_LATENCY = 10` and `KIDSIM_LAT = 22` (the DDS counted as 8 clocks), matching a behavioural
DDS model that ran every clock with its valid tied to 1. With the real IP the processed sample's valid reached `kidsim_top`'s
output mux 8 clocks early, so the mux always chose the bypass; that is what the first board run showed. The legacy IP
(`openquantumhardware/qick` `firmware/ip/axis_kidsim_v3`) has 2 and 14. The model now reproduces the IP (`dds_compiler_model`,
`PHASE_GATED = 1`, checked side by side with the Xilinx model), and the tests fail on the old values.

## Files

```
cores/ip/axis_kidsim_v3/
  README.md
  axis_kidsim_v3.core                # VLNV qick:ip:axis_kidsim_v3:1.0.0
  hdl/axis_kidsim_v3.sv -> rtl_lib/ip/axis_kidsim_v3.sv
  rdl/axis_kidsim_v3_regmap.rdl
  driver/axis_kidsim_v3.py           # AxisKidsimV3 (symlinked from qick_lib/qick/drivers/)
  driver/tests/                      # register-layer (4) and behaviour (7) pytest
  tests/
```

Datapath: `rtl_lib/ctrl/kidsim.sv`, `kidsim_top.sv`, `punct.sv`, and the DDS/phase control blocks.

## Open items

- Driver: done 2026-09-25 (`config_lane`/`config_all`, installed, 11 pytest). The 4x2 notebook now goes through it:
  re-run it on the board to close D6 of IP_INTEGRATION.md.
- A validation in a firmware that uses it at rate (PFB + tProc), e.g. the QCE2024 resonator lab on the ported IP.
