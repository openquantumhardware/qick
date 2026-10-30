###############################################################################
# Out-of-context clock definitions for standalone IP synthesis (mr_buffer_et).
#
#   s_axi_aclk  : AXI4-Lite configuration clock (~99 MHz placeholder)
#   s_axis_aclk : write/capture datapath clock  (~307.2 MHz placeholder)
#   m_axis_aclk : read/drain datapath clock     (~99 MHz placeholder)
#
# Placeholders for OOC synthesis only; real frequencies come from the BD.
###############################################################
create_clock -period 10.000 -name s_axi_aclk  -waveform {0.000 5.000} [get_ports s_axi_aclk]
create_clock -period 3.255  -name s_axis_aclk -waveform {0.000 1.627} [get_ports s_axis_aclk]
create_clock -period 10.000 -name m_axis_aclk -waveform {0.000 5.000} [get_ports m_axis_aclk]
