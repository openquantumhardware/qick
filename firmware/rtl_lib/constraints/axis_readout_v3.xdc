# axis_readout_v3.xdc
#
# Timing exceptions for axis_readout_v3.
#
# Single clock domain (aclk), no AXI-Lite, no CDC crossings at all -- same
# rationale as axis_dyn_readout_v1.xdc. Only the descriptor stream input
# needs a false-path (it is captured into fifo_sync and only consumed once
# popped by ctrl_dyn_ro).
#
# NOT validated against a real Vivado synthesis run in this environment.

set_false_path -from [get_ports s0_axis_t*]
