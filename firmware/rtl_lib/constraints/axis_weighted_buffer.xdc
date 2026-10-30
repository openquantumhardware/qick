# axis_weighted_buffer.xdc
#
# Timing exceptions for axis_weighted_buffer.
#
# NOT validated against a real Vivado synthesis run in this environment (no
# Vivado project available here) -- the legacy IP had no packaged-IP-level
# constraints at all. Three fully independent clock domains (s_axi_aclk,
# s_axis_aclk, m_axis_aclk); every cross-domain path goes through either a
# cdc_bit_sync/cdc_gray_sync synchronizer (ASYNC_REG-tagged) inside
# weighted_buffer/matched_filter/avg_top/buffer_top, or the true-dual-port
# bram_tdp used to bridge clock domains -- same pattern documented for
# axis_avg_buffer and mr_buffer_et.

set_clock_groups -asynchronous \
    -group [get_clocks -of_objects [get_ports s_axi_aclk]] \
    -group [get_clocks -of_objects [get_ports s_axis_aclk]] \
    -group [get_clocks -of_objects [get_ports m_axis_aclk]]

# External hardware trigger is asynchronous by construction; handled
# entirely by weighted_buffer's own cdc_bit_sync.
set_false_path -from [get_ports trigger]
