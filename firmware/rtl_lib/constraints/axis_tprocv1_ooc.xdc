###############################################################################
# Out-of-context clock definitions for axis_tprocv1 IP synthesis.
#
# This XDC applies ONLY to standalone OOC synthesis of the IP (used_in
# out_of_context). When the IP is instantiated inside a block design, the
# top-level design constraints drive timing instead, so I/O delays here would
# be meaningless (the IP ports are internal to the BD, not device pins).
#
# We therefore constrain only what matters for OOC: the real clocks and the
# asynchronous relationship between the two clock domains. CDC safety is
# guaranteed by the design (cdc_gray_sync synchronizers + dual-clock BRAM).
#
# Two real clock domains:
#   s_axi_aclk : 100 MHz  (AXI-Lite config, DMEM port A, dmem arbiter)
#   aclk       : 250 MHz  (tProcessor core, DMEM port B, AXIS 1..8 / 1..4)
#
# s0_axis_aclk / m0_axis_aclk are interface-only ports (not used as real clocks
# in the RTL); they are left unconstrained here.
###############################################################################

create_clock -period 10.000 -name s_axi_aclk [get_ports s_axi_aclk]
create_clock -period 4.000  -name aclk       [get_ports aclk]

set_clock_groups -asynchronous \
    -group [get_clocks -of_objects [get_ports s_axi_aclk]] \
    -group [get_clocks -of_objects [get_ports aclk]]
