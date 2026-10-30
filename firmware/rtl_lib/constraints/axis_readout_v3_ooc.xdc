# axis_readout_v3_ooc.xdc
#
# Out-of-context synthesis clock definition for axis_readout_v3.
#
# Single clock domain (aclk) -- no AXI-Lite, no separate config write-side
# clock, same as axis_dyn_readout_v1. NOT validated against a real Vivado
# OOC synthesis run in this environment.

create_clock -period 1.600 -name aclk [get_ports aclk]
