# axis_sg_mux8_v1_ooc.xdc
#
# Out-of-context synthesis clock definitions for axis_sg_mux8_v1.
#
# NOT validated against a real Vivado OOC synthesis run in this environment
# (no Vivado project available here) -- ported from the legacy standalone
# sg_mux8 datapath constraints (firmware/ip/axis_sg_mux8_v1/src/synth/xdcs/
# top_sg_mux8.xdc, which constrained the bare sg_mux8 sub-block, not the
# packaged AXI-Lite IP). Re-derived for the actual two-clock IP boundary
# (s_axi_aclk, aclk) -- review before relying on it for real timing closure.

create_clock -period 4.000 -name s_axi_aclk [get_ports s_axi_aclk]
create_clock -period 1.000 -name aclk       [get_ports aclk]
