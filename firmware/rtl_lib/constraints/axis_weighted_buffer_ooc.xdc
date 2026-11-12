# axis_weighted_buffer_ooc.xdc
#
# Out-of-context synthesis clock definitions for axis_weighted_buffer.
#
# NOT validated against a real Vivado OOC synthesis run in this environment
# (the legacy IP had no synth XDC at all). Three clock domains: s_axi_aclk
# (AXI-Lite config + weight-programming DMA write clock), s_axis_aclk
# (capture/write side), m_axis_aclk (readout/read side).

create_clock -period 4.000 -name s_axi_aclk  [get_ports s_axi_aclk]
create_clock -period 1.600 -name s_axis_aclk [get_ports s_axis_aclk]
create_clock -period 1.600 -name m_axis_aclk [get_ports m_axis_aclk]
