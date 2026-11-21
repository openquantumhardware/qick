# qick_time_tagger.xdc
#
# Timing exceptions for qick_time_tagger.
#
# NOT validated against a real Vivado synthesis run in this environment (no
# Vivado project available here) -- the legacy IP had no packaged-IP-level
# constraints at all. Three fully independent clock domains (ps_clk, c_clk,
# adc_clk); every cross-domain path goes through either a cdc_reg_sync/
# cdc_bit_sync synchronizer (ASYNC_REG-tagged, inside qtt_cmd/qick_time_tagger/
# this wrapper), a cdc_handshake req/ack toggle (also ASYNC_REG-tagged
# internally), or an xpm_fifo_async instance (inside qick:mem:fifo_async, used
# by tag_mem/tag_fifo_tc/smp_mem) -- same pattern documented for
# axis_avg_buffer/axis_weighted_buffer/mr_buffer_et.

set_clock_groups -asynchronous \
    -group [get_clocks -of_objects [get_ports ps_clk]] \
    -group [get_clocks -of_objects [get_ports c_clk]] \
    -group [get_clocks -of_objects [get_ports adc_clk]]

# External hardware arm input is asynchronous by construction; handled
# entirely by qick:processors:qick_time_tagger's own cdc_reg_sync (sync_arm).
set_false_path -from [get_ports arm_i]
