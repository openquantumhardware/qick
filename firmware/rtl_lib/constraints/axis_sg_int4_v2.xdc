###############################################################################
# axis_sg_int4_v2 — clock domain crossing constraints (scoped to the IP)
#
# Three asynchronous clock domains: s_axi_aclk, s0_axis_aclk, aclk.
# All CDC paths use ASYNC_REG synchronizers (cdc_gray_sync, inside
# axis_to_bram_sg) or the dual-clock BRAM (bram_tdp). Declaring the clock
# groups asynchronous covers every cross-domain path; the synchronizers
# guarantee CDC safety. Mirrors axis_signal_gen_v4.xdc unchanged -- same
# three-clock-domain boundary and CDC scheme, only the datapath differs.
#
# NOT validated against a real Vivado synthesis run in this environment.
###############################################################################

set_clock_groups -asynchronous \
    -group [get_clocks -of_objects [get_ports aclk]] \
    -group [get_clocks -of_objects [get_ports s0_axis_aclk]] \
    -group [get_clocks -of_objects [get_ports s_axi_aclk]]

# Descriptor input (captured by the FIFO) — false path.
set_false_path -from [get_ports s1_axis_t*]
