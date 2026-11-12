###############################################################################
# axis_signal_gen_v6 — clock domain crossing constraints (scoped to the IP)
#
# Three asynchronous clock domains: s_axi_aclk, s0_axis_aclk, aclk.
# All CDC paths use ASYNC_REG synchronizers (cdc_gray_sync) or the dual-clock BRAM
# (bram_tdp). Declaring the clock groups asynchronous covers every cross-domain
# path; the synchronizers guarantee CDC safety.
###############################################################################

set_clock_groups -asynchronous \
    -group [get_clocks -of_objects [get_ports aclk]] \
    -group [get_clocks -of_objects [get_ports s0_axis_aclk]] \
    -group [get_clocks -of_objects [get_ports s_axi_aclk]]

# Descriptor input (captured by the FIFO) — false path.
set_false_path -from [get_ports s1_axis_t*]
