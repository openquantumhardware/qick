# qick_time_tagger_ooc.xdc
#
# Out-of-context synthesis clock definitions for qick_time_tagger.
#
# NOT validated against a real Vivado OOC synthesis run in this environment
# (the legacy IP had no synth XDC at all). Three clock domains: ps_clk (AXI4-Lite
# config + DMA read), c_clk (tProc command interface), adc_clk (ADC sampling +
# the whole time-tagging datapath).

create_clock -period 10.000 -name ps_clk  [get_ports ps_clk]
create_clock -period 4.072  -name c_clk   [get_ports c_clk]
create_clock -period 3.333  -name adc_clk [get_ports adc_clk]
