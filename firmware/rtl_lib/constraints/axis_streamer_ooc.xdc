###############################################################################
# Out-of-context clock definitions for standalone IP synthesis (axis_streamer).
#
#   s_axi_aclk  : AXI4-Lite configuration clock      100 MHz placeholder
#   s_axis_aclk : capture datapath clock             307.20 MHz (zcu216 real:
#                 xrfclk lmk=245.76, lmx=491.52 -> period 3.255 ns)
#   m_axis_aclk : drain datapath clock               100 MHz placeholder,
#                 matched to the DMA / HP port
#
# Placeholders for OOC synthesis only; the real frequencies come from the BD.
# s_axis_aclk is the one that must be right — it is the full-rate capture side
# and sets Fmax for the write path and the FIFO.
###############################################################################
create_clock -period 10.000 -name s_axi_aclk  -waveform {0.000 5.000} [get_ports s_axi_aclk]
create_clock -period 3.255  -name s_axis_aclk -waveform {0.000 1.627} [get_ports s_axis_aclk]
create_clock -period 10.000 -name m_axis_aclk -waveform {0.000 5.000} [get_ports m_axis_aclk]
