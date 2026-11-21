# QICKEmu regression

Two references: `baseline_legacy_md5.txt` (the emulator as HRL shipped it, legacy sources) and
`baseline_fusesoc_md5.txt` (the DUT built from the fusesoc cores, this branch). **They differ, on purpose**: see
"Legacy against fusesoc" at the end. The one to compare with after a change is the fusesoc one.

`emu_baseline.py` runs the programs of `notebooks/00_intro_emu.ipynb` (multi_pulse and simple_sweep, decimated and averaged), the muxed
generator with two PFB readouts, and the standard readout (`axis_readout_v2`, driven by generator 1: the harness loops DAC 1 into ADC 1) through
`QickEmu` and writes an md5 per returned array. `baseline_legacy_md5.txt` has the first five arrays only; the two of the standard readout exist only for the fusesoc DUT.
`baseline_legacy_md5.txt` was produced
with the **unmodified upstream** emulator (openquantumhardware/qick `merge-hrl-main` at
07887032, legacy `firmware/ip` sources, `EMULATOR` parameter), Verilator 5.042, one core.

```
cd emulator/testbench && make verilate          # once
python emulator/regression/emu_baseline.py <repo_root> /tmp/run
diff /tmp/run/md5.txt emulator/regression/baseline_legacy_md5.txt
```

Use a Python with numpy, scipy, matplotlib and tqdm (`requirements.txt`).

## Conditions the md5 depend on

- `PRE_RUN_DELAY_NS=0`. `qick_emu.run_verilator_tb` draws the start-up delay (0..100 ns) at
  random for each run on purpose; the driver pins it. Another delay gives other md5
  (checked with 37 ns): the baseline holds for delay 0 only.
- Averaged runs need a long enough simulation (`TEST_RUN_NS_AVG`, 50000 ns here). With the
  default `TEST_RUN_TIME` the averaged buffers come back as zeros, because the drain starts
  before the averager has finished (also the case of `artifacts/test_sim`).
- The ADC model adds noise from a fixed seed, so a run is repeatable for a given delay.

Reproducibility: two complete runs gave identical md5 for the four arrays.

## Legacy against fusesoc

(Since 2026-10-19 the fusesoc reference uses `RF_DELAY_TIME_NS` = 110 ns in the harness, the value that reproduces the ZCU216 loopback latency, instead of the 100 ns of HRL; the `mux_pfb` array does not change because DAC 2 has no transport delay. The numbers of the table below are those of the 110 ns reference.)

The same four programs, the same `pmem`/`wmem`, `PRE_RUN_DELAY_NS=0`; the fusesoc results are identical in three
runs. They do not reproduce the legacy ones:

| Result | legacy (HRL models) | fusesoc cores |
|---|---|---|
| multi_pulse, decimated, max abs | 3880 | 4338 |
| simple_sweep, decimated, max abs | 1752 | 3994 |
| simple_sweep, averaged, max abs | 500 | 837.5 |
| multi_pulse, averaged, max abs | 548 | 910.6 |
| simple_sweep, peak of the DAC pulses (gains 0.25, 0.5, 0.75, 1.0) | 4095, 8190, 12285, 16380 | 8187, 16267, 24562, 32651 |
| start of the first DAC pulse | 25.9 us | 24.5 us |

What was measured (it is the reason for not keeping the legacy numbers as the reference):

- The DAC pulses with an envelope (gaussian, flat_top) of the fusesoc DUT are twice those of the legacy emulator for the
  same program and gain, and gain 1.0 gives 32651 (full scale 32767). Documented, and validated on hardware: the legacy
  `sgv6` took bits [31:16] of the envelope x DDS product (a factor 0.5), the fusesoc `sgv6` takes [30:15] (full Q15
  scale) -- see the header of `firmware/rtl_lib/dsp/sgv6.sv` and U2 "Amplitude" and U8 of
  `firmware/fusesoc/cores/ip/axis_signal_gen_v6/README.md`. Constant pulses never had the factor, which is why
  `artifacts/test_sim` agrees (32766 in both). The DDS models of the generator and of the readouts were checked against
  the real DDS Compiler (at most 19 counts, `dds_compiler_*.sv`).
- `fir_decim8_dynro` (the decimating FIR of the dynamic readout) was wrong in the fusesoc cores: 16 times the gain and a
  latency of 10 instead of 67. It is fixed (1.0.1) and compared with the real FIR Compiler on every clock. The first
  fusesoc run of the emulator clipped at +-32768 because of it.
- With the fix, `readout_top_dynro` built with the models gives the same product as the one built with the real DDS
  and FIR Compiler IP (generated from the .xci in Vivado) within 3 counts, and the same decimated data within 1 count
  once running (`firmware/fusesoc/cores/lib/dsp/readout_top_dynro/tests/vendor/run_vendor_check.sh`).
- The legacy models of the FIR (HRL) are within 2 counts of the real IP, as they said.

The fifth program (muxed generator `axis_sg_mux8_v1` with two PFB readouts, from the tutorial notebook 07) is the
PFB v4 path (config `ro_type` axis_pfb_readout_v4, register map in `qick_emu.py` as the v4 driver: `id`/`freq`/`phase`
of 8 outputs). Plateaus of the two readouts: 2447 and 1375 (fusesoc), 2464 and 1374 (legacy, PFB v3 with HRL's models),
pulse length within one sample; the rise is steeper in the fusesoc one. The FFT in both is a real-arithmetic model
(the fusesoc one is HRL's). Against the real blocks: `firmware/fusesoc/cores/ip/axis_pfb_readout_v4/tests/vendor/run_vendor_check.sh`
simulates the IP with the models of the emulator (FFT model, FIR and DDS models) and with the real System Generator
FFT, the eight FIR Compilers and the DDS Compiler (generated from the .xci), with two tones, eight outputs configured
over AXI-Lite and 3000 clocks recorded: at most 2 counts of difference on outputs of up to 2980, the same valid pattern.
Mutations of the FFT model (latency, lane order, twiddle sign) are caught. It uses the qout of the IP (5) and scale 0,
as the emulator does.

Timing of the capture. Two measurements, not the same thing: on `artifacts/test_sim` the time from the first non-zero DAC
sample to the first non-zero decimated sample is 494 ns in the fusesoc DUT and 1083 ns in the legacy one (the first
non-zero sample depends on the pulse amplitude, which differs by the factor 2 above); on the constant pulse of
`multi_pulse`, whose amplitude does not depend on that, the fusesoc capture sees it 3 to 4 decimated samples (about
100 ns) earlier than the legacy one (segments above half of its peak: samples 252-312 against 255-316). A candidate
(hypothesis, not tested) is the FIFOs of `axis_cdcsync_v1`: the XPM FIFO model of the cores against the simplified
one of the legacy `EMULATOR` switch. Not analysed further.

Not covered: the standard readout (`axis_readout_v2`) in a program, the interpolated and mixer-mux generators (not in the DUT).
