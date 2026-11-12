###############################################################################
# axis_kidsim_v3 — clock domain crossing constraints (scoped to the IP)
#
# Two asynchronous clock domains:
#   s_axi_aclk : AXI4-Lite configuration
#   aclk       : datapath (AXIS in/out, kidsim lanes)
#
# Cross-domain paths are synchronized with cdc_bit_sync (ASYNC_REG):
#   - config registers are gated by WE_REG, resynced in kidsim_top
#   - the per-lane trigger is resynced inside dds_phase_ctrl
# Declaring the clock groups asynchronous covers every cross-domain path; the
# synchronizers guarantee CDC safety.
###############################################################################
set_clock_groups -asynchronous \
    -group [get_clocks -of_objects [get_ports aclk]] \
    -group [get_clocks -of_objects [get_ports s_axi_aclk]]

# The per-lane trigger crosses into the aclk domain through cdc_bit_sync
# (inside dds_phase_ctrl). Its source is asynchronous to aclk, so cut the
# timing path — the 2-FF synchronizer handles metastability.
set_false_path -from [get_ports trigger*]
