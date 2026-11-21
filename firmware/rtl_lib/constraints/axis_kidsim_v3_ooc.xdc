###############################################################################
# Out-of-context clock definitions for standalone IP synthesis (axis_kidsim_v3).
#
#   s_axi_aclk : AXI4-Lite configuration clock
#   aclk       : datapath clock (AXIS in/out, L kidsim lanes)
#
# These periods are placeholders for OOC synthesis only; the real clock
# frequencies are set by the block design. Adjust to the target board (zcu216).
###############################################################################
create_clock -period 10.000 -name s_axi_aclk -waveform {0.000 5.000} [get_ports s_axi_aclk]
create_clock -period 2.000  -name aclk       -waveform {0.000 1.000} [get_ports aclk]
