# N-channel AXIS clock-domain crossing (axis_cdcsync_v1)

Carries up to 16 AXI4-Stream channels from one clock domain to another, all together, through a single shared
dual-clock FIFO. In the QICK firmwares it moves the tProc's wave ports (the generator and readout descriptors) from
the tProc timing clock to the clock of the generators or readouts they drive.

- VLNV: `qick:ip:axis_cdcsync_v1:1.0.0` (module `axis_cdcsync_v1`)
- Replaces: the legacy `QICK:QICK:axis_cdcsync_v1:1.0` (openquantumhardware/qick `firmware/ip/axis_cdcsync_v1`), with the same
  ports, parameters and behaviour (wrapper and `cdcsync` merged into one module). Its FIFO is now
  `qick:mem:fifo_async`, the same `xpm_fifo_async` underneath.
- Driver: none (no registers). QickSoc recognises it by type name when tracing a generator or readout back to the
  tProc (`qick_lib/qick/ip.py`, `trace_back`): output `m<i>_axis` is followed to input `s<i>_axis`.
- Used in: 111 `tpv1_rfbv2_std`, `tpv2_std`; 216 `tpv2_std`, `tpv2_std_rfbv2`, `tpv2_demo`;
  4x2 `tpv1_std`, `tpv2_std` (`B = 160` or 168, `N = 1` to 4)

**How to read this file.** Part I is for someone who wants to use the IP. Part II is the reference.

---

# Part I -- Using the IP

## U1. What it does

```
 s_axis_aclk                                     m_axis_aclk
 s0_axis --+                                +--> m0_axis   tvalid = valid_0 of the head word
 s1_axis --+--> { valid_i, data_i }  FIFO --+--> m1_axis
  ...      |    one word, N channels  16    |    ...
 s<N-1> ---+    written if any tvalid deep  +--> m<N-1>_axis
                                            popped when every m<i>_axis_tready is high
```

## U2. The rules that are not obvious

- **The channels travel together.** One FIFO word holds every channel's `{tvalid, tdata}`. A word is written on any
  `s_axis_aclk` edge where at least one channel has `tvalid`; the channels without `tvalid` are carried with valid 0
  and come out with `tvalid` low.
- **One output can stall them all.** The head word is popped only when every `m<i>_axis_tready` (`i < N`) is high.
  While one output holds `tready` low, the others keep seeing the same word with `tvalid` high, and a consumer that
  keeps `tready` high sees (and accepts) it again on every clock. The QICK consumers (`sg_translator`, readout
  descriptor inputs) accept on every clock, so this does not happen in the standard firmwares.
- **Backpressure is shared too.** Every `s<i>_axis_tready` is `~full`: when the FIFO is full, all channels wait.
- **Out of reset, `tready` is low for a while.** `s_axis_aresetn` resets the FIFO; `xpm_fifo_async` then keeps
  dropping writes for a number of clocks (`wr_rst_busy`), and the IP holds `tready` low for that window. The legacy
  IP showed `tready` high there and lost the words. `m_axis_aresetn` is not used (as in the legacy IP).
- **Latency** is the FIFO's: a few clocks of each domain (2 synchronizer stages, first-word fall-through).

## U3. Data formats

Each channel's `tdata` is carried unchanged, `B` bits. In the tProc v2 BDs (`B = 168`) it is a wave-port word;
in the tProc v1 BDs (`B = 160`) a tProc v1 wave word.

## U4. Throughput and limits

One word per `s_axis_aclk` clock while the reader keeps up: with every output ready, the read side pops one word per
`m_axis_aclk` clock, so a reader clock at least as fast as the writer's never fills the FIFO. `N` from 1 to 16; the
FIFO word is `N * (B + 1)` bits wide, 16 deep.

## U5. Python quick start

Nothing to do on the IP. QickSoc crosses it when it traces a generator or readout back to its tProc port.

## U6. Using it in a block design

| Parameter | Default | Standard BDs |
|---|---|---|
| `N` (channels) | 2 | 1 to 4 |
| `B` (bits) | 8 | 168 (tProc v2), 160 (tProc v1) |

All sixteen `s<i>_axis` and `m<i>_axis` are always present, whatever `N`; only the first `N` carry data. Channels
`i >= N` have `s<i>_axis_tready = 1`, `m<i>_axis_tvalid = 0`, `m<i>_axis_tdata = 0`.

| Clock / reset | Interfaces |
|---|---|
| `s_axis_aclk` / `s_axis_aresetn` | `s0_axis` .. `s15_axis` (the tProc timing clock, `t_clk_i`) |
| `m_axis_aclk` / `m_axis_aresetn` | `m0_axis` .. `m15_axis` (the consumers' clock) |

## U7. Gotchas

| Symptom | Cause | What to do |
|---|---|---|
| A generator repeats a pulse, or gets a descriptor late | One of the other outputs of the same IP holds `tready` low | Give every output a consumer that is always ready, or split the channels over two IPs |
| The first descriptors after a reset never arrive | The source ignored `tready` while the FIFO left reset | Wait for `tready` (the tProc dispatcher does) |
| A channel never gets anything | Its index is `>= N` | Raise `N` |

## U8. Validation status

| What | Where | Result |
|---|---|---|
| Legacy RTL, same behaviour | every standard QICK firmware with a tProc | In production |
| This SystemVerilog port | SVUnit against the legacy RTL (Part II) | 6/6, cycle-exact outside the reset window |
| This port in the Top BDs | `validate_bd_design`, Vivado 2025.2 | See the CHANGELOG entry |
| This port on hardware | -- | Not yet |

---

# Part II -- Reference

## Ports

| Port | Dir | Width | Notes |
|---|---|---|---|
| `s_axis_aclk`, `s_axis_aresetn` | in | 1 | write side; the reset clears the FIFO |
| `s<i>_axis_tdata/tvalid/tready`, i = 0..15 | in/in/out | B/1/1 | used for `i < N`; `tready = ~full` |
| `m_axis_aclk`, `m_axis_aresetn` | in | 1 | read side; the reset is not used |
| `m<i>_axis_tdata/tvalid/tready`, i = 0..15 | out/out/in | B/1/1 | used for `i < N` |

## Registers

None.

## Verification

`make sim IP=axis_cdcsync_v1`, six configurations, each next to the legacy RTL (`tests/ref/axis_cdcsync_v1_legacy.sv`,
the original files with only the module names changed): N=4/2/1 at B=168, N=4 at B=160, N=16 at B=8 on a
307.2 -> 614.4 MHz crossing, and N=4 at B=168 on a 430.08 -> 153.6 MHz crossing (the reader is slower, the FIFO
fills). Always-on checkers compare every used channel's `tvalid`/`tdata`/`tready` with the legacy RTL, check every
accepted word comes out whole and in order, and check the channels past `N`.

- `tc_random_traffic_matches_legacy`: random `tvalid` and `tready` on every channel, 4000 write clocks, both pairs
- `tc_back_to_back_words_are_all_delivered`: 500 consecutive words, `tready` never drops with a faster reader
- `tc_full_fifo_holds_tready_low`: with no output ready the FIFO takes 15 to 18 words, `tready` drops, nothing is
  lost once the outputs open
- `tc_one_stalled_output_holds_the_word`: one output not ready keeps the word at the head, the others see it for
  as long as that lasts
- `tc_partial_word_raises_only_its_channels`: only the valid channel's `tvalid` rises; a channel `>= N` writes
  nothing
- `tc_tready_low_while_the_fifo_leaves_reset`: the one intended difference from the legacy IP

Checked to fail when the read waits for any output instead of all of them, and when the channels' valid bit is
taken from the wrong position.

## Files

```
cores/ip/axis_cdcsync_v1/
  README.md
  axis_cdcsync_v1.core
  axis_cdcsync_v1.clock_domains.yaml      # s<i>_axis on s_axis_aclk, m<i>_axis on m_axis_aclk
  hdl/axis_cdcsync_v1.sv -> ../../../../../rtl_lib/ip/axis_cdcsync_v1.sv
  tests/axis_cdcsync_v1_tc00.sv, axis_cdcsync_v1_tests.sv
  tests/ref/axis_cdcsync_v1_legacy.sv     # golden model (legacy RTL + its XPM FIFO wrapper)
```

## Open items

- First hardware run with the ported IP.
