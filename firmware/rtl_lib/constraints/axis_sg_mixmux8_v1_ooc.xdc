# axis_sg_mixmux8_v1_ooc.xdc
#
# Out-of-context synthesis clock definitions for axis_sg_mixmux8_v1.
#
# NOT validated against a real Vivado OOC synthesis run in this environment
# (no Vivado project available here) -- the legacy IP
# (firmware/ip/axis_sg_mixmux8_v1) had no synth XDC of its own at all.
# Mirrors axis_sg_mux8_v1_ooc.xdc's two-clock boundary (same s_axi_aclk/
# aclk domains, register map, and CDC scheme -- only the datapath width
# differs) -- review before relying on it for real timing closure.

create_clock -period 4.000 -name s_axi_aclk [get_ports s_axi_aclk]
create_clock -period 1.000 -name aclk       [get_ports aclk]
