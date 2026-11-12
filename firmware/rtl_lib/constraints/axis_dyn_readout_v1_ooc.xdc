# axis_dyn_readout_v1_ooc.xdc
#
# Out-of-context synthesis clock definition for axis_dyn_readout_v1.
#
# Single clock domain (aclk) -- no AXI-Lite, no separate envelope/config
# write-side clock, unlike the signal generators. NOT validated against a
# real Vivado OOC synthesis run in this environment.

create_clock -period 1.600 -name aclk [get_ports aclk]
