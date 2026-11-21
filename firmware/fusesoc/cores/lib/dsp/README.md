# Library cores: dsp

DSP datapath blocks (signal generators, IQ correction, readouts, and similar).

Each core is its own FuseSoC core (`qick:dsp:<name>:<version>`, the version is in the `name:` of its `.core` file); the RTL is in `firmware/rtl_lib/` and `hdl/` links to it.
Simulate one with `make sim IP=<name>`, lint it with `make lint IP=<name>`. How to create a core: [NEW_CORE.md](../../../../docs/developer/NEW_CORE.md).

| Core | What it is | Tests |
|---|---|---|
| [`cmult`](cmult/) | cmult (dsp library core) | yes |
| [`dds_compiler_dyn_readout`](dds_compiler_dyn_readout/) | > | yes |
| [`dds_compiler_dyn_readout_lat9`](dds_compiler_dyn_readout_lat9/) | the `dds_compiler_dyn_readout` DDS with Latency 9 (registered phase accumulator input) | yes |
| [`dds_compiler_model`](dds_compiler_model/) | > | no |
| [`dds_compiler_pfb_ro`](dds_compiler_pfb_ro/) | > | yes |
| [`dds_compiler_readout`](dds_compiler_readout/) | > | no |
| [`dds_compiler_signal_gen`](dds_compiler_signal_gen/) | > | yes |
| [`dds_compiler_signal_gen_int`](dds_compiler_signal_gen_int/) | > | no |
| [`dds_compiler_signal_gen_mixmux`](dds_compiler_signal_gen_mixmux/) | > | no |
| [`dds_compiler_signal_gen_mux`](dds_compiler_signal_gen_mux/) | > | no |
| [`dds_phasegen_sincos_ow16_lat8`](dds_phasegen_sincos_ow16_lat8/) | > | yes |
| [`dds_top_mixmux8`](dds_top_mixmux8/) | dds_top_mixmux8 (dsp library core) | yes |
| [`dds_top_sgmux8`](dds_top_sgmux8/) | dds_top_sgmux8 (dsp library core) | yes |
| [`down_conversion_dynro`](down_conversion_dynro/) | down_conversion_dynro (dsp library core) | yes |
| [`down_conversion_ro_v2`](down_conversion_ro_v2/) | down_conversion_ro_v2 (dsp library core) | yes |
| [`down_conversion_ro_v3`](down_conversion_ro_v3/) | down_conversion_ro_v3 (dsp library core) | yes |
| [`fir_decim4_ro_v3`](fir_decim4_ro_v3/) | > | yes |
| [`fir_decim8_dynro`](fir_decim8_dynro/) | > | yes |
| [`fir_interp4_sgint`](fir_interp4_sgint/) | > | yes |
| [`fir_pfb_ro_0`](fir_pfb_ro_0/) | > | no |
| [`fir_pfb_ro_1`](fir_pfb_ro_1/) | > | no |
| [`fir_pfb_ro_2`](fir_pfb_ro_2/) | > | no |
| [`fir_pfb_ro_3`](fir_pfb_ro_3/) | > | no |
| [`fir_pfb_ro_4`](fir_pfb_ro_4/) | > | no |
| [`fir_pfb_ro_5`](fir_pfb_ro_5/) | > | no |
| [`fir_pfb_ro_6`](fir_pfb_ro_6/) | > | no |
| [`fir_pfb_ro_7`](fir_pfb_ro_7/) | > | no |
| [`fir_pfb_ro_model`](fir_pfb_ro_model/) | > | yes |
| [`iir_1p1z`](iir_1p1z/) | iir_1p1z (dsp library core) | yes |
| [`iir_iq`](iir_iq/) | iir_iq (dsp library core) | yes |
| [`iq_gain`](iq_gain/) | iq_gain (dsp library core) | yes |
| [`matched_filter`](matched_filter/) | matched_filter (dsp library core) | yes |
| [`mult_32x32`](mult_32x32/) | mult_32x32 (dsp library core) | yes |
| [`mult_pipe3`](mult_pipe3/) | mult_pipe3 (dsp library core) | yes |
| [`pfb`](pfb/) | > | yes |
| [`pfb_chsel`](pfb_chsel/) | > | yes |
| [`pfb_ctrl`](pfb_ctrl/) | > | yes |
| [`pfb_ddsprod`](pfb_ddsprod/) | > | yes |
| [`pfb_firs`](pfb_firs/) | > | yes |
| [`pfb_readout`](pfb_readout/) | > | yes |
| [`pfb_switch`](pfb_switch/) | > | yes |
| [`phase_shifter`](phase_shifter/) | phase_shifter (dsp library core) | yes |
| [`pimod_pfb`](pimod_pfb/) | > | yes |
| [`qtt_core`](qtt_core/) | qtt_core (dsp library core). Top non-AXI composition for the | yes |
| [`qtt_tag_calc`](qtt_tag_calc/) | qtt_tag_calc (dsp library core) | yes |
| [`readout_top_dynro`](readout_top_dynro/) | readout_top_dynro (dsp library core) | yes |
| [`readout_top_ro_v2`](readout_top_ro_v2/) | readout_top_ro_v2 (dsp library core) | yes |
| [`readout_top_ro_v3`](readout_top_ro_v3/) | readout_top_ro_v3 (dsp library core) | yes |
| [`sg_int4`](sg_int4/) | sg_int4 (dsp library core) | yes |
| [`sg_int4_top`](sg_int4_top/) | sg_int4_top (dsp library core) | yes |
| [`sg_mixmux8`](sg_mixmux8/) | sg_mixmux8 (dsp library core) | yes |
| [`sg_mux8`](sg_mux8/) | sg_mux8 (dsp library core) | yes |
| [`sgv6`](sgv6/) | Signal generator v6 datapath (envelope x DDS, gain, output) | yes |
| [`sgv6_top`](sgv6_top/) | sgv6_top (dsp library core) | yes |
| [`ssr_fft_8x64`](ssr_fft_8x64/) | > | yes |
| [`ssrfft_8x64_sync`](ssrfft_8x64_sync/) | > | yes |
| [`tag_gen`](tag_gen/) | tag_gen (dsp library core) | yes |
| [`tpv2_dsp_macro`](tpv2_dsp_macro/) | > | yes |
| [`x_inter`](x_inter/) | x_inter (dsp library core) | yes |

58 cores. The list is checked by `make doc-check`: a core added here must be added to this table.
