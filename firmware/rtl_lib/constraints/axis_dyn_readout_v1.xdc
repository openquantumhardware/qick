# axis_dyn_readout_v1.xdc
#
# Timing exceptions for axis_dyn_readout_v1.
#
# Single clock domain (aclk), no AXI-Lite, no CDC crossings at all -- the
# legacy IP has no XDC of its own for the same reason. Only the descriptor
# stream input needs a false-path (it is captured into fifo_sync and only
# consumed once popped by ctrl_dyn_ro, same rationale as
# axis_sg_int4_v2.xdc's s1_axis rule).
#
# NOT validated against a real Vivado synthesis run in this environment.

set_false_path -from [get_ports s0_axis_t*]
