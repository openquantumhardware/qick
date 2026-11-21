###############################################################################
# mr_buffer_et — clock domain crossing constraints (scoped to the IP)
#
# THREE asynchronous clock domains:
#   s_axi_aclk  : AXI4-Lite configuration
#   s_axis_aclk : write / capture datapath (full-rate, e.g. 307.2 MHz)
#   m_axis_aclk : read / drain datapath (e.g. 99 MHz to DMA/HP)
#
# Cross-domain paths are synchronized with:
#   - cdc_gray_sync (ASYNC_REG) inside mr_buffer: dw_capture, dr_start, trigger,
#     and the BRAM read/write gray pointers.
#   - cdc_bit_sync  (ASYNC_REG) in the wrapper: capture_done (s_axis -> s_axi).
# Declaring the three clock groups mutually asynchronous covers every
# cross-domain path (incl. the true-dual-port BRAM write<->read); the
# synchronizers guarantee CDC safety.
###############################################################################
set_clock_groups -asynchronous \
    -group [get_clocks -include_generated_clocks -of_objects [get_ports s_axi_aclk]] \
    -group [get_clocks -include_generated_clocks -of_objects [get_ports s_axis_aclk]] \
    -group [get_clocks -include_generated_clocks -of_objects [get_ports m_axis_aclk]]

# The external hardware trigger is asynchronous to s_axis_aclk; it is resynced
# by cdc_gray_sync (sync_trigger). Cut the input path -> the synchronizer
# handles metastability.
# -through, not -from: inside a block design `trigger` is a pin of the IP, not a
# primary input, so it is no valid startpoint and -from was dropped (Vivado 18-513).
set_false_path -through [get_ports trigger*]
