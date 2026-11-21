###############################################################################
# axis_constant_iq — clock domain crossing constraints (scoped to the IP)
#
# Two asynchronous clock domains: s_axi_aclk (AXI-Lite), m_axis_aclk (AXIS).
# All CDC paths use synchronizers (cdc_gray_sync for we_reg).
# Declaring the clock groups asynchronous covers every cross-domain path.
###############################################################################

set_clock_groups -asynchronous \
    -group [get_clocks -of_objects [get_ports s_axi_aclk]] \
    -group [get_clocks -of_objects [get_ports m_axis_aclk]]
