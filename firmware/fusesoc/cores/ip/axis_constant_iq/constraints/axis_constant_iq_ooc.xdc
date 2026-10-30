###############################################################################
# axis_constant_iq — OOC synthesis constraints
###############################################################################

# Two asynchronous clock domains
set_clock_groups -asynchronous \
    -group [get_clocks -of_objects [get_ports s_axi_aclk]] \
    -group [get_clocks -of_objects [get_ports m_axis_aclk]]
