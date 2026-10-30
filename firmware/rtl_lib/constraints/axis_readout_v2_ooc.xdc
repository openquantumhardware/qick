# axis_readout_v2_ooc.xdc
#
# Out-of-context synthesis clock definitions for axis_readout_v2.
#
# NOT validated against a real Vivado OOC synthesis run in this environment
# (the legacy IP had no synth XDC at all). Two clock domains: s_axi_aclk
# (AXI-Lite config) and aclk (ADC/demod/decimation/output).

create_clock -period 4.000 -name s_axi_aclk [get_ports s_axi_aclk]
create_clock -period 1.600 -name aclk       [get_ports aclk]
