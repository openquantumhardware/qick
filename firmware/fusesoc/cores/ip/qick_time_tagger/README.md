# QICK Time Tagger (qick_time_tagger)

Timestamps the moments an ADC signal goes above a threshold, with sub-sample resolution (25 ps per
LSB on a 2.4576 GS/s ADC with 4 interpolation bits), on up to 4 ADC channels at once. Tags are stored in
per-channel ring buffers and read back by DMA (or, for channel 0, by the tProcessor). It can also keep
raw-sample snapshots around each tag and a per-arm-session trigger count.

- Project: QICK (fusesoc port of the legacy QICK `qick_time_tagger` IP)
- VLNV: wrapper `qick:ip:qick_time_tagger:1.0.0` (module `axi_qick_time_tagger`) over core
  `qick:dsp:qtt_core:1.0.0`
- Driver: `QICK_Time_Tagger` in `qick_lib/qick/drivers/peripherals.py` (also binds the legacy VLNVs)
- Hardware bring-up: RFSoC4x2, a debug bench (status in U8)

**How to read this file.** Part I is for someone who wants to use the IP: what it measures, how it decides
to tag, how to read the result, what its limits are. Part II (sections 1 to 5) is the implementation reference:
architecture, ports, register map, verification, files.

---

# Part I -- Using the time tagger

## U1. What it does

Every clock the tagger receives 8 consecutive 16-bit ADC samples per channel (`s0_axis_adcN`). While it is
**armed**, each channel watches for a sample above the **threshold**; when it sees one it records a 32-bit
**tag** (a timestamp, see U3) and goes deaf for the **dead time** (see U2). Tags accumulate in one ring buffer
per channel (`TAG0` to `TAG3`). You read them with `tt.read_mem('TAG0')` and convert them to seconds.

Typical uses: timestamping pulses (photon-like events) and measuring the phase or period of a periodic signal
from where it crosses the threshold.

```
ADC samples --> [filter] --> sample > threshold ? --> TAG --> dead time --> re-arm
 (8 per clock)   (optional)     (level comparator)     |
                                                       +--> tag word --> TAGn ring buffer --> DMA --> Python
                                                       +--> (optional) raw-sample snapshot --> SMP memory
```

## U2. How it decides to tag (read this before choosing the dead time)

**The comparator is a level detector, not an edge detector.** With the default build (`CMP_SLOPE = 0`) it tests
`sample > threshold`. The rule, from `qtt_tag_calc.sv`:

1. While armed, if any of the 8 samples of the current clock is above the threshold, produce a tag.
2. Wait for the dead time (`set_dead_time`, in clocks of the ADC-side clock). On hardware, with the dead time at its
   minimum of 5 and 4 interpolation bits, the spacing between consecutive tags was exactly **7 clocks** (about
   `dead time + 2`). That was before the interpolator operands were pipelined (`qtt_tag_calc` 1.0.1, 552.96 MHz timing): the
   interpolator now starts two clocks later, so the spacing is expected to be about **9 clocks**; not yet measured on hardware.
3. Re-arm. **If the signal is still above the threshold, tag again immediately.**

It was designed for pulses: one tag per pulse works only if the dead time is longer than the time the pulse
stays above the threshold. For a **periodic signal** the consequence is:

> Choose the dead time **longer than the time the signal spends above the threshold (about half a period) and
> shorter than the period**. Then the tagger is re-armed while the signal is low, and the next tag is the next
> rising crossing. A good value is about 3/4 of a period, minus the 2 clocks of re-arm.

If the dead time is too short you get several tags per period, all but the first at meaningless times. On
hardware, a 10 MHz tone with the dead time at 5 gave exactly 3 tags per period (tags at 0, 7 and 14 clocks of the
15.4 clocks the tone is high) while a 40 MHz tone (high for 3.8 clocks) gave 1. Tags per period, when the dead
time is too short, is about `1 + floor(time above threshold / (dead time + 2))`.

Tone frequencies at a 307.2 MHz tagger clock (the RFSoC4x2 ADC fabric clock), threshold at the signal's midpoint:

| tone | period (clocks) | dead time to use | tags per period with dead time 5 |
|---|---|---|---|
| 40 MHz | 7.7 | 5 (the minimum) | 1 (measured) |
| 20 MHz | 15.4 | 10 | 2 (predicted) |
| 10 MHz | 30.7 | 21 | 3 (measured) |
| 5 MHz | 61.4 | 44 | 5 (predicted) |

**The dead time is one register shared by every ADC channel.** Channels carrying tones of very different
frequency cannot be captured at the same time; capture them one after the other (as the demo notebook does).

**Dead time and interpolation.** The inhibit counter also runs while the interpolator works. Up to `qtt_tag_calc` 1.0.0 it
compared with `==`, so a dead time shorter than the interpolation time (about `interp + 1` clocks) made the re-arm wait for
the 8-bit counter to wrap (up to about 256 clocks). From 1.0.1 it compares with `>=` (the interpolator also starts two
clocks later, about `interp + 3` clocks, which would have broken the driver's minimum of 5 for 4 interpolation bits): a dead
time shorter than the interpolation re-arms as soon as the interpolation ends (regression test
`tc_dead_time_shorter_than_interpolation_rearms`).

**What the interpolation bits compute.** With `interp = k > 0` the tagger interpolates linearly between two
samples of the signal being compared: the last one that was not above the threshold (the "previous sample", the
sample index stored in the tag) and the first one above it. The fraction is
`floor(2^k * (threshold - previous) / (first_above - previous))`, in units of 1/2^k sample, and it is 0 when the
previous sample is already at or above the threshold (armed while the signal is high: there is no crossing). With
`filt = 1` the samples are the filtered ones (sum of two consecutive samples, threshold doubled to match), with
`invert = 1` the negated ones. It works for any signal, not only pulses from a zero baseline: a sinusoid crossing
its threshold gets a real sub-sample time (checked in simulation: a step 0 to 500 with threshold 100 gives 3/16
= 0.2 sample, a ramp -100 to 100 with threshold 0 gives 8/16, also when the two samples are in different clocks).
Tags one clock apart are still separate: interpolation refines the time within the sample interval, not the
count.

History (bitstreams built before 2026-09-21 do not do this): the legacy interpolator was fed the previous sample
as 0 when `CMP_SLOPE = 0`, the threshold at half the scale of the samples, and the samples of the clock *after*
the crossing (the operands were read one clock late), so it only gave a plausible fraction for a pulse from a zero
baseline that stayed high for two clocks, and with a single-clock pulse it returned 15 of 16 whatever the
threshold. With a threshold of 0 on a sinusoid the fraction was always 0.

**Threshold.** `set_threshold(value)`, signed ADC counts. The comparison uses the (optionally filtered) sample,
so the threshold acts on the ADC value including its DC offset: an ADC with a -400 count offset and a threshold
of 0 tags when the signal is 400 counts above its mean, not at the zero crossing of the AC component. Pick the
threshold at the level whose crossing you want to time.

**Options (`set_config`).**

| argument | effect |
|---|---|
| `filt` | 1: compare the average of two consecutive samples (a 2-tap low-pass, uncorrelated noise drops by about 1.4x) against the threshold instead of the sample |
| `invert` | 1: negate the samples (detect the signal going *below* a level) |
| `slope` | 1: compare `sample - previous sample` against the threshold (rising-edge steepness instead of level). Needs a build with `CMP_SLOPE = 1`; the default build has 0 and `set_config` raises `ValueError` |
| `interp` | number of interpolation bits, 0 to `CMP_INTER` (U3) |
| `wr_smp` | groups of 8 samples stored per trigger by the sample store (U4), 1 to 32 |

## U3. The tag word and how to turn it into time

The 32-bit tag, for `interp = k` interpolation bits (`k` = 0 to 4):

```
[ coarse clock count : 29-k bits ][ sample index : 3 bits ][ fraction : k bits ]
```

- **coarse**: number of ADC-side clocks since the tagger was armed (the counter is reset whenever it is
  disarmed).
- **sample index**: which of the 8 samples of that clock. With `k = 0` it is the first sample above the threshold;
  with `k > 0` it is the sample just *before* the crossing.
- **fraction**: where between that sample and the next one the threshold was crossed, in units of 1/2^k sample.
  How it is computed, and what changed on 2026-09-21, is in U2.

```python
def decode_tags(words, interp, f_clk_hz, smp_ck=8):
    w = np.asarray(words).astype(np.uint32)            # read_mem returns int32: reinterpret as unsigned
    frac    = w & ((1 << interp) - 1)
    rest    = w >> interp
    smp_idx = rest & 0x7
    coarse  = rest >> 3
    samples = coarse.astype(np.float64) * smp_ck + smp_idx + frac / (1 << interp)
    return samples / (smp_ck * f_clk_hz)                # seconds since arming
```

`f_clk_hz` is the frequency of `s0_axis_aclk`: `tt['f_fabric'] * 1e6` (the driver stores it **in MHz**).

- **Resolution**: one LSB is `1 / (8 * f_clk * 2^k)`: 406.9 ps for `k = 0` and 25.4 ps for `k = 4` at 307.2 MHz.
- **Range**: the coarse field has `29 - k` bits, so the counter wraps after `2^(29-k)` clocks: 1.75 s for
  `k = 0` and **109 ms for `k = 4`** at 307.2 MHz. Arm for less than that or unwrap the timestamps.
- **The interpolation assumes the tagger was armed while the signal was below the threshold**, so that the
  sample before the crossing is below it. A tag produced on re-arm while the signal is already high (dead time
  too short) has a meaningless fraction.

## U4. Memories and readback

| memory | what it holds | notes |
|---|---|---|
| `TAG0` .. `TAG3` | tag words of ADC channel 0..3 | ring buffer of `2^TAG_FIFO_AW` words (default 65536): when full, **the oldest tag is overwritten**, so a long capture keeps the newest 65535. `read_mem` logs a warning when a memory is at capacity. Channel 0 can also be popped by the tProc |
| `ARM` | one word per arm-to-disarm session: the number of tags **channel 0** produced in it | needs `ARM_STORE = 1` (default). It counts channel 0 only (`tag_gen`'s `trig_o` is channel 0's), whatever the number of channels |
| `SMP` | raw-sample snapshots (channel 0 only) | needs `SMP_STORE = 1` (default 0). See below |

`tt.read_mem(name)` DMA-reads everything pending in that memory and returns an `int32` array; `flush_mems()`
empties them (call it before arming). Read after `disarm()` to get a consistent set.

**`reset()` clears every memory in one command** (the DMA-read ones and the tProc queue) **and restarts the
counters, without changing the configuration.** It can be issued idle or armed: if the tagger was armed it
stays armed and tags again as soon as the reset ends (about 64 ADC clocks, 0.2 us at 307 MHz, of which the
tagger does not tag), with the time counter restarted, so the tags after a reset are timed from the reset. A
reset issued during a DMA read would strand the reader; do not. On a bitstream built before 2026-09-21
`reset()` is unreliable (below); use `flush_mems()`, which works on every build.

**The sample store is not a continuous capture.** On every tag it stores a window of `8 * wr_smp` consecutive
samples (256 for `wr_smp = 32`). Those 8-sample words go through a small 256-word FIFO on the ADC clock side and
are drained on the `s_axi_aclk` (100 MHz) side at **one word every ~11 clocks** (about 33 ADC clocks). A signal
that triggers on every period (any continuous tone) therefore fills the FIFO after about 8 windows and from then
on nearly every word is dropped, leaving a sparse, aliased sampling. Use it for sparse triggers (pulses), or arm
for about 1 ms and analyse only the first windows. A model reproduces this behaviour to three decimals.

**Maximum tag rate**: one tag per `dead time + 2` clocks and channel, at least 7 clocks (43.9 MHz at 307.2 MHz).

## U5. Python quick start

```python
from qick import QickSoc
soc = QickSoc(bitfile=BIT, no_tproc=True)          # no_tproc for firmwares without a tProcessor
tt = soc.qick_time_tagger_0                         # instance name depends on the block design
f_clk = tt['f_fabric'] * 1e6                        # Hz (the driver keeps MHz)

tt.set_config(filt=0, slope=0, interp=tt['cmp_inter'], wr_smp=8, invert=0)
tt.set_threshold(0)                                 # signed ADC counts, includes the ADC's DC offset
tt.set_dead_time(21)                                # clocks, 5..255, shared by all channels (see U2)
tt.flush_mems()
tt.arm()
time.sleep(0.005)                                   # collect tags
tt.disarm()

words = tt.read_mem('TAG0', warn_full=False)
t = np.sort(decode_tags(words, tt['cmp_inter'], f_clk))      # seconds since arming
period_estimate = np.median(np.diff(t))
```

The validation notebook is the full hardware test: two DAC tones looped back into two ADCs,
per-tone dead time, a check that the tags follow the tone, inter-arrival histograms and an interpolation-bit
sweep.

## U6. Using it in a block design

- **`s0_axis_adcN`** (N = 0..`ADC_QTY-1`): 128-bit AXI4-Stream, 8 samples x 16 bit per clock, from the RFDC
  ADC. `s0_axis_aclk` / `s0_axis_aresetn` must be **the clock of the RFDC tile's AXI-stream interface, i.e. its
  fabric clock**. On the RFSoC4x2 the ADC tile has `out_div = 2` (its output clock `clk_adc0` is half the fabric
  clock), so the tagger and `m0_axis_aclk` must run from a clock doubled from `clk_adc0` with a `clk_wiz`
  (`clk_adc0_x2`), as the official 4x2 block design does. Running them directly on `clk_adc0` runs the stream at
  half the required rate.
- **`m0_axis_dma`**: 32-bit AXI4-Stream to an `axi_dma` S2MM channel (readback), on `s_axi_aclk`.
- **`s_axi`**: AXI4-Lite registers, on `s_axi_aclk` (16 registers, Part II 3.3).
- **`arm_i`**: external arm input; tie it to 0 if you arm from software.
- **`c_clk` / `qtag_*`**: tProcessor interface (arm, pop a tag from channel 0); leave unconnected without a tProc.
- **Parameters** (packaged IP; wrapper defaults): `ADC_QTY` 1, `CMP_INTER` 4, `ARM_STORE` 1, `SMP_STORE` 0,
  `TAG_FIFO_AW` 16, `ARM_FIFO_AW` 10, `SMP_FIFO_AW` 18, `CMP_SLOPE` 0, `SMP_DW` 16, `SMP_CK` 8. Set them with
  `set_property CONFIG.<NAME> {value}` in the block design (there is no GUI dropdown yet).
- Timing: the tagger's ADC domain must close timing at the fabric clock (307.2 MHz on the RFSoC4x2, met with a
  positive slack in the debug bench).

## U7. Limits and gotchas

| Gotcha | What happens | What to do |
|---|---|---|
| Dead time too short for a periodic signal | Several tags per period, at meaningless times | U2: longer than half a period, shorter than a period |
| One dead time for all channels | A channel whose tone needs a different value gets the wrong count | Capture channels separately |
| `tt['f_fabric']` is in MHz | Timestamps off by 1e6 | Multiply by 1e6 |
| `read_mem` returns `int32` | Tags with the top bit set look negative | `astype(np.uint32)` |
| Timestamps wrap | 109 ms at `interp = 4`, 307.2 MHz | Arm for less, or unwrap |
| Tag memory full | Oldest tags are lost silently (only a log warning) | Read sooner or shorten the capture |
| Sample store with a continuous signal | Only the first ~8 windows are intact | U4 |
| `CMP_SLOPE = 0` (default) | `slope=1` raises `ValueError` | Build with `CMP_SLOPE = 1` |
| Stream clock at `clk_adc0` instead of the fabric clock | RFDC and tagger out of rate | U6 |
| `reset()` on a bitstream built before 2026-09-21 | Two failures. Issued while idle it can leave the tag memory unchanged: the flush was the raw 3-clock request, sampled without synchronisation by the 100 MHz DMA clock, which can miss it. Issued while armed the request is never acknowledged (the control FSM only looked at it in IDLE) so the memories stay in flush and every tag is dropped until you disarm | Use `flush_mems()`, or rebuild with the fixed IP (reset paragraph in U4) |
| Even `interp` (2, 4, 6) with a bitstream built before 2026-09-21 | Crossings that fall on sample 0 of a clock are tagged one clock (3.26 ns) late; the spread of a tone's tags jumps (1.6 ns vs 0.2 ns on the board) and the spacings show pairs of outliers at about +-3.3 ns | Rebuild with the fixed `qtt_tag_calc` (its condition `cfg_inter_i & enc_zero` was a 3-bit AND with a 1-bit value, true only for odd `interp`) |
| Interpolated tag times step by one sample (spread of a 40 MHz tone's spacings 375 ps instead of about 10 ps) on a bitstream built before 2026-09-21 | Each tag carried the interpolation fraction of the **previous** tag: the tag FIFO samples `tag_dt_o` in the cycle `tag_vld_o` pulses, and the fraction register was loaded at the end of that same cycle. With a tone whose period is not a whole number of samples the error is a fixed -0.44 or +0.56 samples (40 MHz: consecutive crossings move by 0.44 sample), i.e. two residual levels one sample apart with the switch at fraction 9. Demo Step 6b shows it | Rebuild with the 2026-09-21 IP (`tag_vld_o` delayed one clock in `qtt_tag_calc`) |
| Commands lost (a dead time or threshold that did not change, a capture that never armed) on a bitstream built before 2026-09-21 | About 6 % of `set_dead_time` / `set_threshold` writes did not take effect (19 of 300 pairs on an RFSoC4x2). The CTRL command is a one-clock pulse; `qtt_cmd` samples `en` and the opcode bits in the ADC clock through per-bit synchronisers, and with a few hundred ps of routing skew it sees the new `en` with the old opcode (0 = `disarm`). Typical symptoms: a 10 MHz tone with dead time 21 tagged every 258 clocks (the inhibit counter wraps at 256) or a capture with 0 tags | Rebuild with the 2026-09-21 IP (`qtt_cmd_hold`, Part II 2.3). The driver now reads `THR_INH` back and retries `set_threshold` / `set_dead_time`; `arm`, `disarm` and `reset` cannot be read back, so on an old bitstream check that a capture returned tags |
| Fraction bits always 0 (or wrong) on a bitstream built before the 2026-09-21 interpolator fix | `interp > 0` adds nothing to the time of a sinusoid at threshold 0; single-clock pulses get a fraction of 15 | Rebuild with the fixed `qtt_tag_calc`; U2 explains the old behaviour |
| `slope = 1` (build with `CMP_SLOPE = 1`) with `interp > 0` | The fraction is the level interpolation of U2, not an interpolation of the slope crossing | Not validated; use `slope = 0` for timing |
| `soc.tt_config(...)` with the default `wr_smp = 32` on a build without the sample store, driver older than 2026-09-21 | Sets `invert` (32 << 5 is bit 10 of the config word): every crossing is detected on the falling side | Pull the driver fix (the field is 5 bits and 32 encodes as 0); check with `get_config()` |

## U8. Validation status

**RFSoC4x2, debug bench** (PS + RFDC + this IP with `ADC_QTY = 2` + two `axis_constant_iq` loopback tone
generators, DAC0 10 MHz into TAG0 and DAC2 40 MHz into TAG1; block design builds, timing met at 307.2 MHz, the
driver binds, the NCOs are programmed at runtime). Measured on 2026-09-21 with a bitstream built from the IP as of
that day, by the validation notebook:

| check (notebook step) | result |
|---|---|
| tags per tone period, dead time chosen per tone (4b) | 1.0000 on both channels (10 MHz: dead time 21; 40 MHz: dead time 5); spacings equal the tone's period |
| each channel sees only its own DAC (4c) | swapping the tones moves the result with the frequency |
| interpolation sweep on the 40 MHz tone, spread of the spacings (6) | 202 ps at `interp` 0, 66, 43, 25 and **12.5 ps at `interp` 4** (LSB 25 ps); 0 spacings off by a clock at any depth |
| residual of each tag against the tone period, per fraction bin (6b) | 0.022 samples (9 ps) overall, flat across the 16 fractions (step -0.00 samples) |
| ARM memory (7) | one word per arm window, equal to the TAG0 count (e.g. 11067, 21221, 40975 tags in windows of about 1.1, 2.1, 4.1 ms) |
| `soc.tt_config` / `tt_arm` / `tt_readmem` (7) | work; `get_config()` after `tt_config` with the default `wr_smp = 32` reads `invert = 0` |
| `reset()` idle (7b) | TAG0/ARM (28780, 1) before, (0, 0) after |
| `reset()` armed (7b) | 27684 tags before, 1874 right after, still tagging 2 ms later (26445) |
| raw command stress, 300 (set dead time, set threshold) pairs (7c) | 0 lost |

**Problems found on hardware during this bring-up, all fixed (details in U7 and Part II 2.3).** The comparator is a level detector (dead time per tone); even
`interp` tagged sample-0 crossings a clock late; the interpolation fraction was always 0 on a sinusoid (previous
sample tied to 0, threshold at the wrong scale, operands one clock late); `reset()` did not work armed and could
miss the flush idle; about 6 % of the CTRL commands were lost in the clock crossing (19 of 300 pairs before the
fix); each tag carried the interpolation fraction of the previous one; `soc.tt_config`'s default `wr_smp = 32`
set `invert`. The spread of 12.5 ps at `interp = 4` is about the 8.8 ps (40 MHz) that Andrin Doll (PSI) reports for
his own fix of the same interpolator.

**Simulation**: `qtt_tag_calc` 12/12, `qtt_cmd_hold` 4/4, `qtt_cmd` 8/8, top-level 8/8, `qtt_core` 5/5, the memories,
`tag_mem`, `smp_mem`, driver register tests 4/4, lint clean (see Part II). Two things simulation could not show:
the synchroniser on the flush (with a long flush and no synchroniser the reset tests also pass in RTL simulation;
it is there because the crossing needs it, and the hardware reset test passed with it) and routing skew on the
command path (emulated with delays, and confirmed by the 300-pair stress test before and after).

**Not verified**:
- the interpolation on real baseband pulses (the RFSoC4x2 loopback only provides sinusoids; the operands were
  checked in simulation with step, ramp and filtered inputs);
- the sample store with sparse triggers (this build has `SMP_STORE = 0`);
- `arm`, `disarm` and `reset` under stress (only `set_dead_time` / `set_threshold` can be read back; the demo shows
  that captures arm and reset works, but not a count of lost `arm` commands);
- the reset issued during a DMA read (the reader is not protected; do not).

**Not migrated yet**: the RFSoC 216 `tpv2_std` / `tpv2_std_rfbv2` projects still use the legacy
`QICK:QICK:qick_time_tagger:1.0` IP, which has the same defects.

---

# Part II -- Implementation reference

*Sections keep the numbering they had; sections 4 and 5 of the previous version moved into Part I (U5, U8).*

## 1. Overview

```
                                  ┌─────────────────────────────┐
s0_axis_adc0..3 (s0_axis_aclk) ─►│  tag_gen  (per-channel        │
  (raw ADC stream, filtered,      │  qtt_tag_calc: filter+cmp+    │
   threshold-compared)            │  x_inter sub-sample interp)   │
                                  └──────────┬────────────────────┘
                                             │ tag_dt / tag_vld (per channel)
                                  ┌──────────▼────────────────────┐
                                  │  tag_mem                       │
                                  │   ch0: tag_fifo_tc (tri-port,  │
                                  │        tProc pop + DMA pop)    │
                                  │   ch1-3: tag_fifo_dc (DMA pop  │
                                  │        only, if ADC_QTY > 1)   │
                                  └──────────┬────────────────────┘
                                             │
      arm_i / qtag_* (tProc) ──► control FSM │  smp_mem (SMP_STORE) ──┐
      (ST_RST/ST_IDLE/ST_ARMED)              │  tag_fifo_dc (ARM_STORE)┤
                                             ▼                        ▼
                                  ┌─────────────────────────────────────┐
                                  │  dma_fifo_rd  (length-counted        │
                                  │  FIFO-pop → AXI4-Stream reader,      │
                                  │  selected by DMA_CFG_REG.mem_sel)    │
                                  └──────────────┬────────────────────┘
                                                 ▼
                                   m0_axis_dma (s_axi_aclk domain)

  s_axi (s_axi_aclk) ──► axil_slv (16 regs, AUTO_CLEAR_BIT0 for CTRL_REG)
                     ──► qtt_cmd (cross-domain command dispatch:
                          tProc `qtag_*` / AXI `CTRL_REG` / external
                          `arm_i` level input → one decoded command
                          stream on s0_axis_aclk)
```

Typical use (arm → threshold crossing → tag capture → DMA readback):
1. SW writes `AXI_DT1_REG` = threshold, then `CTRL_REG` op=`set_threshold`
   (strobe) → `qtt_cmd` dispatches it onto `s0_axis_aclk`.
2. SW writes `CTRL_REG` op=`arm` → control FSM moves `ST_IDLE`→`ST_ARMED`.
3. A sample above the threshold on an armed channel (a level comparator, see
   U2) → `qtt_tag_calc` captures a 32-bit tag word (coarse ADC-clock count +
   in-clock sample index + optional sub-sample interpolation bits, see U3 and
   §2.3) into that channel's `tag_mem` ring buffer.
4. SW writes `DMA_CFG_REG` (mem_sel + length), then `CTRL_REG` bit5
   (`dma_rd`, no strobe of its own) → `dma_fifo_rd` pops the selected
   memory and streams it out `m0_axis_dma` (`tlast` on the final word).

**Three clock domains**, all independent:
- `s_axi_aclk` / `s_axi_aresetn` — AXI4-Lite config + DMA readback
  (`m0_axis_dma` shares this same clock/reset, see §3.1)
- `s0_axis_aclk` / `s0_axis_aresetn` — ADC-side datapath (filter/compare/
  tag capture), all four ADC inputs
- `c_clk` / `c_aresetn` — tProc-facing `qtag_*` interface (not an inferred
  AXI bus, see §3.1)

---

## 2. Core: `qtt_core`

### 2.1 Parameters
| Param | Default | Meaning |
|-------|---------|---------|
| `ADC_QTY` | 4 | Number of ADC channels wired up (1-4) |
| `CMP_SLOPE` | 1 | Enable slope-compensated comparison (subtract a filtered "previous sample" term before comparing) |
| `CMP_INTER` | 4 | Max sub-sample interpolation bits (`x_inter`'s `IW`) |
| `ARM_STORE` | 1 | Instantiate the arm-session trigger-count store (`tag_fifo_dc`) |
| `SMP_STORE` | 1 | Instantiate the per-trigger raw-sample snapshot store (`smp_mem`) |
| `TAG_FIFO_AW` | 19 | Tag ring-buffer address width (depth `2**TAG_FIFO_AW`) |
| `ARM_FIFO_AW` | 10 | Arm-store ring-buffer address width |
| `SMP_FIFO_AW` | 10 | Sample-store ring-buffer address width |
| `SMP_DW` | 19 | Sample data width (bits/sample) |
| `SMP_CK` | 8 | Samples per clock (fabric parallelism) |
| `DEBUG` | 1 | 0=no debug bus, 1=internal debug register, 2=also drive it out live |

These are the `qtt_core` defaults. The packaged wrapper `axi_qick_time_tagger` has different ones (`ADC_QTY` 1,
`CMP_SLOPE` 0, `SMP_STORE` 0, `TAG_FIFO_AW` 16, `SMP_FIFO_AW` 18), listed in U6.

### 2.2 Ports
```
ps_clk_i, ps_rst_ni                       // AXI/control domain (renamed s_axi_aclk/aresetn in the wrapper)
c_clk_i, c_rst_ni                         // tProc domain
adc_clk_i, adc_rst_ni                     // ADC datapath domain (renamed s0_axis_aclk/aresetn in the wrapper)

qtt_pop_req_i, qtt_rst_req_i, qtt_rst_ack_o   // qtt_cmd <-> core handshakes
cfg_invert_i, cfg_filter_i, cfg_slope_i, cfg_inter_i[2:0], cfg_smp_wr_qty_i[4:0]
arm_i                                      // level-sensitive arm (ONE armed channel works)
cmp_th_i[SMP_DW-1:0], cmp_inh_i[7:0]       // threshold, dead-time/inhibit count
adc_dt_i[ADC_QTY][SMP_CK*SMP_DW-1:0]       // per-channel raw ADC stream

dma_req_i, dma_mem_sel_i[2:0], dma_len_i[19:0], dma_ack_o
dma_m_axis_tready_i / tvalid_o / tdata_o[31:0] / tlast_o

tag_dt_o[31:0], tag_vld_o, trig_o, cmp_o    // tProc-facing pop result + raw trigger/compare probes

proc_qty_o, dma_qty_o[4], smp_qty_o, arm_qty_o   // per-memory pending counts
qtt_debug_o[31:0], qtt_reg_status_o[23:0], qtt_reg_debug_o[31:0]
```

### 2.3 Internal architecture
- **Control FSM** (`ST_RST`/`ST_IDLE`/`ST_ARMED`, one-hot): `arm_i` moves
  `ST_IDLE`→`ST_ARMED`; `qtt_rst_req_i` moves `ST_IDLE` **and `ST_ARMED`** to `ST_RST` (legacy: only from
  `ST_IDLE`). In `ST_RST` the memories are flushed for `RST_FLUSH_CK = 32` ADC clocks, then left alone for
  `RST_SETTLE_CK = 32` more while the flush deasserts on the DMA side, and only then is the request
  acknowledged (`qtt_rst_ack_o`), which lets `qtt_cmd` drop it; the FSM returns to `ST_IDLE` and, if `arm_i` is
  still set, to `ST_ARMED`. The memories (`tag_fifo_dc`, `tag_fifo_tc`, `smp_fifo_dc`) synchronise the flush into
  the DMA clock with `cdc_bit_sync` before using it there.
  `tag_gen_en` (enables tagging) is high only in `ST_ARMED`. Also drives a
  free-running `time_cnt` (29-bit ADC-clock counter, resets whenever
  `tag_gen_en` is low) that feeds every channel's coarse timestamp.
- **Command path** (`qtt_cmd_hold` -> `qtt_cmd`): the CTRL register is a one-clock pulse (`AUTO_CLEAR_BIT0`).
  `qtt_cmd_hold` (on `s_axi_aclk`) latches the opcode, raises `en` two clocks later and holds both for `HOLD = 6`
  clocks, so the ADC-side synchronisers see a stable opcode when `en` rises (legacy: the raw pulse, whose skewed bits
  lost about 6 % of the commands). A second strobe arriving while a command is held is remembered and issued
  after it; only one is remembered. Verified in `qtt_cmd`'s bench with 1.5 ns of emulated skew on the opcode:
  the raw pulse loses commands, the held one loses none. The `dma_rd` bit (CTRL bit 5) is not part of this path.
- **`tag_gen`**: one `qtt_tag_calc` instance per ADC channel. Each
  filters `SMP_CK` samples/clock (optionally slope-compensated), compares
  against `cmp_th_i` (a level test, see U2), uses a `priority_encoder` to find the first sample
  (of the `SMP_CK`-wide word) that is above it, and — if `cfg_inter_i > 0` —
  refines the crossing time with an `x_inter` bit-serial restoring
  divider. Tag word format (32 bits, always): `{coarse ADC-clock count
  (shrinks by 1 bit per interpolation bit), 3-bit in-clock sample index,
  cfg_inter_i interpolation bits}`.
- **`tag_mem`**: channel 0 uses `tag_fifo_tc` (tri-port: tProc pop via
  `sync_pulse` + DMA pop, tProc has priority on a shared read port);
  channels 1-3 (if `ADC_QTY>1`) use plain `tag_fifo_dc` (DMA pop only).
  `empty_o = |empty` (OR across channels -- a legacy asymmetry vs.
  `full_o = &full`, preserved as-is).
- **`dma_fifo_rd`**: single-clock-domain, length-counted FIFO-pop → AXI4-
  Stream reader. `dma_mem_sel_i` (0-3=tag channels, 4=arm store, 5=sample
  store) muxes which ring buffer's pop interface it drives.
- **`smp_mem`** (if `SMP_STORE=1`): trigger-driven capture through a
  4-deep value-preserving pipeline of channel 0's raw samples, feeding a
  `smp_fifo_dc` ring buffer; `cfg_smp_wr_qty_i` sets how many `SMP_CK`-wide
  groups get captured per trigger.
- **`tag_fifo_dc` (ARM_STORE)**: if `ARM_STORE=1`, a second `tag_fifo_dc`
  instance records the running trigger count (`trig_cnt`, reset whenever
  disarmed) once per arm→disarm transition (`arm_t10`).
- **Output CDC**: `qtt_pop_ack` (tProc pop acknowledgment, `s_axi_aclk`
  domain) is carried to `c_clk` via `cdc_handshake` (dummy 1-bit payload)
  -- a correction from an earlier assumption that this path (legacy
  `pulse_cdc`) was dead code; it has one real, live instance here
  (`tag_vld_sync`).

### 2.4 Sub-cores referenced
- `qtt_tag_calc` (`qick:dsp:qtt_tag_calc`) -- per-channel filter/compare/tag.
  Its `priority_encoder` instantiation uses `OUT="NO_REG"` (combinational);
  a legacy typo (`"TNO_REG"`) here was a real pipeline-misalignment bug,
  independently found and fixed on mainline QICK hardware -- see
  `firmware/fusesoc/CHANGELOG.md`'s 2026-09-18 correction entry.
  It also carries two more fixes over the legacy source: the coarse-count selection for interpolated crossings on
  sample 0 used `cfg_inter_i & enc_zero` (true only for odd `interp`; now `(|cfg_inter_i) & enc_zero`), and the
  interpolator operands (previous sample, threshold scale, alignment with `cmp_s`; see U2), and the tag-valid
  strobe, delayed one clock (`x_inter_end_r`) so that the tag FIFO, which samples `tag_dt_o` in the cycle the strobe
  pulses, sees the fraction of the tag being written and not that of the previous one. The latter registers
  a numerator and a denominator per lane (2 x 17 bits x `SMP_CK` flip-flops per channel) and removes the
  `CMP_SLOPE = 0` tie of the previous sample to 0.
- `priority_encoder` (`qick:encoders:priority_encoder`), `x_inter`
  (`qick:dsp:x_inter`) -- one-hot-to-binary encoder and sub-sample
  interpolator, both used by `qtt_tag_calc`.
- `tag_gen` (`qick:dsp:tag_gen`) -- per-channel `qtt_tag_calc` array.
- `tag_fifo_tc`/`tag_fifo_dc` (`qick:mem:*`) -- ring buffers built on
  `qick:mem:fifo_async` (XPM async FIFO) + `qick:mem:bram_simple_dp`.
- `tag_mem` (`qick:mem:tag_mem`) -- composes the above per `ADC_QTY`.
- `dma_fifo_rd` (`qick:mem:dma_fifo_rd`) -- length-counted FIFO→AXIS reader.
- `smp_fifo_dc`/`smp_mem` (`qick:mem:*`) -- sample-snapshot path.
- `sync_pulse` (`qick:cdc:sync_pulse`), `cdc_handshake` (`qick:cdc:cdc_handshake`),
  `cdc_reg_sync` (`qick:cdc:cdc_reg_sync`) -- CDC primitives.

### 2.5 Verification (core -- 5/5 SVUnit, lint-clean)
Run: `make lint IP=qick:dsp:qtt_core` · `make sim IP=qick:dsp:qtt_core`.

| Test | What | Result |
|------|------|--------|
| `tc_arm_and_trigger` | real end-to-end: arm → genuine threshold crossing → tag capture → DMA readback verifying the captured sample index | PASS |
| `tc_disarmed_never_triggers` | no tag capture while disarmed | PASS |
| `tc_dma_tag_readback` | DMA-side pop path, tag channel 0 | PASS |
| `tc_qtt_rst_flush` | `qtt_rst_req_i` flush handshake | PASS |
| `tc_smp_and_arm_readback` | sample-store and arm-store DMA mux channels | PASS |

---

## 3. Wrapper: `axi_qick_time_tagger`

AXI4-Lite/AXI4-Stream wrapper around `qtt_core` + `qtt_cmd`, replacing the
legacy hand-written `axi_slv_qtt.vhd` AXI slave with the shared
`qick:axi:axil_slv` register bank -- the same substitution every other
ported IP in this repo uses. Named `axi_qick_time_tagger` (not
`qick_time_tagger`) to match the legacy source's own inner/outer file
split; the packaged VLNV is still `qick:ip:qick_time_tagger` (a
`module-filename` lint waiver documents why the module name differs from
the core/file name).

### 3.1 Port-naming convention (2026-09-18 correction)
Ports were originally named `ps_clk`/`adc_clk`/`adc<N>_s_axis_..._i/_o`/
`dma_m_axis_..._i/_o` (matching the legacy VHDL's own naming), which
**broke real hardware bring-up**: Vivado's `ipx::infer_bus_interfaces`
groups an AXI4-Stream bundle's ports by shared prefix *and* direction, and
`dma_m_axis_tready_i` (an input) broke that pattern for the
otherwise-all-output `dma_m_axis_o` bundle -- TREADY silently never got
connected via `connect_bd_intf_net` in any project using this IP, and
needed a hand-wired pin-level workaround every time.

Renamed to match this repo's own packaging convention (confirmed against
`axis_signal_gen_v6`, a working reference: no `_i`/`_o` suffixes at all;
`s0_axis*`/`m0_axis*` prefixes auto-detected by `package_ip.tcl.j2`):

| Old | New |
|-----|-----|
| `ps_clk` / `ps_aresetn` | `s_axi_aclk` / `s_axi_aresetn` |
| `adc_clk` / `adc_aresetn` | `s0_axis_aclk` / `s0_axis_aresetn` |
| `adc<N>_s_axis_tvalid_i` / `tdata_i` / `tready_o` | `s0_axis_adc<N>_tvalid` / `tdata` / `tready` |
| `dma_m_axis_tready_i` / `tvalid_o` / `tdata_o` / `tlast_o` | `m0_axis_dma_tready` / `tvalid` / `tdata` / `tlast` |

`c_clk`/`c_aresetn`/`qtag_*`/`arm_i`/`trig_o`/`cmp_o`/`qtt_do` are
unchanged -- none of them are part of any AXI bus `infer_bus_interfaces`
recognizes, so the naming convention doesn't apply to them.
`qick:dsp:qtt_core` (Tier 2) keeps its own, different port names
(`ps_clk_i`/`adc_clk_i`/`dma_m_axis_..._i/_o`, see §2.2) -- this rename is
Tier 3-only.

`qick_time_tagger.clock_domains.yaml` (read by `ip_packager.py`) still
needs one explicit entry the naming convention can't cover on its own:
`s_axi_aclk -> [s_axi, m0_axis_dma]` -- `m0_axis_dma` genuinely shares
`s_axi`'s own clock port rather than a separate literal `m0_axis_aclk`
(there's no real scenario where the DMA readback and the register
interface run on different clocks). All four `s0_axis_adc0-3` interfaces
and `s_axi` itself are picked up automatically by prefix, no yaml entry
needed for those.

### 3.2 CDC (`s_axi_aclk` control domain ↔ `s0_axis_aclk`/`c_clk` datapath domains)
- `qtt_cmd` dispatches AXI (`CTRL_REG`), tProc (`qtag_*`), and external
  (`arm_i`, level-sensed) commands into one decoded stream on
  `s0_axis_aclk`, using `cdc_reg_sync` (replaces legacy `sync_reg`) and
  `cdc_handshake` (replaces raw `xpm_cdc_handshake`, and also drops the
  legacy `c_en_r`/`cdc_ack` staging entirely -- the lib core owns that
  internally).
- `qtag_dt2_o` (tProc-side readback of `PROC_QTY_REG`) is CDC'd
  `s_axi_aclk`→`c_clk` via a dedicated `cdc_reg_sync #(.DW(32))`.
- `qtt_core`'s own internal CDC (tProc pop-ack → `c_clk`, `tag_vld_sync`)
  is covered in §2.3.

### 3.3 Register map (16 registers, `AXI_AW=6` → `0x00`-`0x3C`, `axil_slv`
with `AUTO_CLEAR_BIT0=1` for `CTRL_REG`; confirmed against
`rdl/qick_time_tagger_regmap.rdl` and the RTL's own `assign i_slv_regs[...]`
statements -- see the 2026-09-18 correction below)

| Addr | Reg | R/W | Notes |
|------|-----|-----|-------|
| 0x00 | `CTRL_REG` | RW, self-clears | bit0=strobe, bits[4:1]=op (0=disarm,1=arm,2=pop_dt,4=set_threshold,5=set_dead_time,7=reset), bit5=dma_rd (no strobe of its own) |
| 0x04 | `CFG_REG` | RW, plain | bit0=filter, bit1=slope, bits[4:2]=interp, bits[9:5]=smp_wr_qty, bit10=invert |
| 0x08 | `DMA_CFG_REG` | RW, plain | bits[2:0]=mem_sel (0-3=tag ch0-3, 4=arm store, 5=sample store), bits[23:4]=length (words) |
| 0x0C | `AXI_DT1_REG` | RW, plain | staging data for the next `CTRL_REG` command |
| 0x10 | (reserved) | RW, plain | present for address-map parity with the legacy VHDL; never wired to anything |
| 0x14 | `PROC_DT_REG` | RO | last tag word popped for the tProc (`CTRL_REG` op=pop_dt) |
| 0x18 | `PROC_QTY_REG` | RO | tProc-side pending count, tag channel 0 only |
| 0x1C-0x28 | `TAG0-3_QTY_REG` | RO | DMA-side pending count per tag channel |
| 0x2C | `SMP_QTY_REG` | RO | sample-store pending count |
| 0x30 | `ARM_QTY_REG` | RO | arm-store pending count |
| 0x34 | `THR_INH_REG` | RO | bits[15:0]=threshold, bits[23:16]=dead-time/inhibit, bits[31:24]=0 |
| 0x38 | `QTT_STATUS_REG` | RO | bits[7:0]=`qtt_cmd` command counter (tProc/ext-arm in [7:4], AXI/Python in [3:0]), bits[15:8]=trigger FSM state, bits[17:16]=DMA FSM state, bits[31:18]=0 |
| 0x3C | `QTT_DEBUG_REG` | RO | debug bus, `DEBUG` parameter dependent |

> **Correction (2026-09-18):** `THR_INH_REG`/`QTT_STATUS_REG`'s bit
> positions above were re-derived directly from the RTL's own `assign`
> statements (`{8'd0, qtt_cmp_inh, ..., qtt_cmp_th}` and
> `{qtt_reg_status_s, cmd_cnt_do}`) after finding the RDL doc's previous
> description didn't match: it claimed a command counter in
> `THR_INH_REG` bits[31:24] (there isn't one -- those bits are hardwired
> zero) and put the trigger/DMA FSM fields at bits[17:10]/[9:8] in
> `QTT_STATUS_REG` (they're actually at [15:8]/[17:16], shifted up by 8
> once `cmd_cnt_do` occupies the low byte). Fixed in
> `rdl/qick_time_tagger_regmap.rdl` to match.

### 3.4 Verification (wrapper -- 4/4 SVUnit, lint-clean)
Run: `make lint IP=qick:ip:qick_time_tagger` · `make sim IP=qick:ip:qick_time_tagger`.

| Test | What | Result |
|------|------|--------|
| `tc_ctrl_self_clears` | `CTRL_REG` reads back 0 one cycle after a nonzero write (`AUTO_CLEAR_BIT0`) | PASS |
| `tc_cfg_register_is_plain_rw` | `CFG_REG` write/read round trip, no self-clear | PASS |
| `tc_ro_register_ignores_writes` | writing garbage to `PROC_DT_REG` doesn't stick (`i_reg_is_readonly`) | PASS |
| `tc_axi_arm_trigger_dma_readback` | full path: set threshold → arm → genuine ADC crossing → AXI-driven DMA readback | PASS |

### 3.5 Driver (`qick_lib/qick/drivers/peripherals.py::QICK_Time_Tagger`)
Hand-written `SocIP` subclass, with the attribute names the software uses (`qtt_ctrl`, `tag0_qty`, ...); the indexes are the read
decode of the legacy `axi_slv_qtt.vhd`. `RESERVED_REG` (word 4) has no attribute. `bindto` includes
the legacy Vivado VLNVs (`Fermi:user:qick_time_tagger:1.0`, `QICK:QICK:qick_time_tagger:1.0`) plus this port's
`qick:ip:qick_time_tagger:1.0`.

Key methods: `arm()`/`disarm()`/`pop_dt()`, `set_threshold(value)`,
`set_dead_time(value)`, `set_config(filt, slope, interp, wr_smp, invert)`/
`get_config()`, `read_mem(mem_sel, length=None, warn_full=True)` (DMA-read
`'TAG0'..'TAG3'`/`'ARM'`/`'SMP'`), `flush_mems()`, `reset()` (works on the fixed IP; unreliable on bitstreams
built before 2026-09-21, where `flush_mems()` is the safe call),
`print_status()`/`print_debug()`/`print_axi_regs()`.

Register-layer pytest (auto-generated by `scripts/gen_driver_tests.py`
from the RDL, `make driver IP=qick_time_tagger`):

| Test | Result |
|------|--------|
| `test_reset_values` | PASS |
| `test_register_offsets` | PASS |
| `test_field_roundtrip` | PASS |
| `test_register_independence` | PASS |

### 3.6 XDC (3 async domains + false path)
`constraints/qick_time_tagger.xdc` declares `s_axi_aclk`/`c_clk`/
`s0_axis_aclk` as three separate async clock groups, plus
`set_false_path -from [get_ports arm_i]` (a genuinely asynchronous
external level input). `constraints/qick_time_tagger_ooc.xdc` provides OOC
placeholder clocks. Neither has been validated against real Vivado
synthesis yet (no synthesis run for this IP standalone -- see the
debug bench instead, U8).

---

## 4. Files
```
cores/dsp/qtt_core/                          # Tier 2 (non-AXI composition)
  hdl/qtt_core.sv -> ../../../../rtl_lib/dsp/qtt_core.sv
  qtt_core.core                               # VLNV qick:dsp:qtt_core:1.0.0
  tests/qtt_core_tc00.sv, qtt_core_tests.sv   # 5/5 SVUnit
cores/ip/qick_time_tagger/
  README.md                                   # this file (Part I: usage, Part II: implementation)
  hdl/qick_time_tagger.sv -> ../../../../rtl_lib/ip/qick_time_tagger.sv
  qick_time_tagger.core                       # VLNV qick:ip:qick_time_tagger:1.0.0
  qick_time_tagger.clock_domains.yaml         # packaging clock-association overrides (§3.1)
  tests/qick_time_tagger_tc00.sv, qick_time_tagger_tests.sv   # 4/4 SVUnit
  rdl/qick_time_tagger_regmap.rdl             # 16 regs, docs/driver-test only (no RTL gen)
  driver/qick_time_tagger.py -> qick_lib/qick/drivers/peripherals.py
  driver/tests/test_qick_time_tagger_regs.py  # 4/4 pytest
  constraints/qick_time_tagger.xdc, qick_time_tagger_ooc.xdc
```

## 5. Open items
- [ ] Interpolation-bit sweep on hardware with a dead time chosen per tone (jitter versus `interp`, towards the
      25 ps LSB): the notebook does it, results pending
- [ ] Optional RTL change: an edge comparator (previous sample below the threshold, current above) so that one
      tag per crossing does not depend on tuning the shared dead time; today the comparator is a level detector
      (U2), which is the legacy behaviour this port preserves
- [ ] Sample store: decide whether its slow drain (one 8-sample word every ~11 clocks, U4) should be widened;
      it makes the store unusable for continuous signals
- [ ] Migrate the RFSoC 216 `tpv2_std`/`tpv2_std_rfbv2` projects from the legacy `QICK:QICK:qick_time_tagger:1.0`
      IP to this port
- [ ] Expose `ADC_QTY` (and the other parameters) as proper Vivado GUI parameters (xgui customization) instead of
      raw `CONFIG.*` overrides
- [ ] Package `qick_peripheral` as a real, named custom bus interface (bundling `qtag_*`) so `qick_processor`'s
      `QPeriphA`/`QPeriphB` can connect the same way the legacy IP's `qick_peripheral` interface already does in
      production (`tpv2_std_rfbv2`)
- [ ] `component.xml`/`xgui` packaging polish (logo present; GUI parameter grouping/widgets not yet reviewed)
