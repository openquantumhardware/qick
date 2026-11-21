# axis_avg_buffer.xdc
#
# Timing exceptions for axis_avg_buffer.
#
# NOT validated against a real Vivado synthesis run in this environment (no
# Vivado project available here) -- the legacy IP had no packaged-IP-level
# constraints at all. Three fully independent clock domains (s_axi_aclk,
# s_axis_aclk, m_axis_aclk); every cross-domain path goes through either a
# cdc_gray_sync/cdc_bit_sync synchronizer (ASYNC_REG-tagged) inside
# avg_top/buffer_top/avg_buffer, or the true-dual-port bram_tdp used by
# avg_top/buffer_top to bridge s_axis_aclk<->m_axis_aclk -- same pattern
# documented for mr_buffer_et (a related, independently-built buffer IP
# sharing bram_tdp/bram_to_axis/cdc_gray_sync).

set_clock_groups -asynchronous \
    -group [get_clocks -of_objects [get_ports s_axi_aclk]] \
    -group [get_clocks -of_objects [get_ports s_axis_aclk]] \
    -group [get_clocks -of_objects [get_ports m_axis_aclk]]

# External hardware trigger is asynchronous by construction; handled
# entirely by avg_buffer's own cdc_bit_sync.
set_false_path -from [get_ports trigger]
