###############################################################################
# Out-of-context clock definitions for standalone IP synthesis.
#   s_axi_aclk   : 100 MHz
#   s0_axis_aclk : 250 MHz
#   aclk         : 625 MHz
#
# Mirrors axis_signal_gen_v4_ooc.xdc's clocks unchanged -- axis_sg_int4_v2
# uses the exact same three-clock-domain boundary. NOT validated against a
# real Vivado OOC synthesis run in this environment.
###############################################################################
create_clock -period 10.000 -name s_axi_aclk   -waveform {0.000 5.000} [get_ports s_axi_aclk]
create_clock -period 4.000  -name s0_axis_aclk -waveform {0.000 2.000} [get_ports s0_axis_aclk]
create_clock -period 1.600  -name aclk         -waveform {0.000 0.800} [get_ports aclk]
