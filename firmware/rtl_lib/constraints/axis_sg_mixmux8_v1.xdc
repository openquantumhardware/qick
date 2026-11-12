# axis_sg_mixmux8_v1.xdc
#
# Timing exceptions for axis_sg_mixmux8_v1.
#
# NOT validated against a real Vivado synthesis run in this environment (no
# Vivado project available here) -- the legacy IP had no packaged-IP-level
# constraints at all. Mirrors axis_sg_mux8_v1.xdc's CDC rules (identical
# phase_ctrl_sgmux8/cdc_bit_sync scheme, reused unchanged for this IP) --
# review before relying on it for real timing closure.

# WE_REG is resynchronized into the aclk domain via cdc_bit_sync
# (ASYNC_REG-tagged internal register) inside phase_ctrl_sgmux8, one
# instance per output channel (8x).
set_false_path -to [get_cells -hier -filter {ASYNC_REG == "TRUE"}]

# PINC/POFF are plain axil_slv registers (s_axi_aclk domain) read directly
# by the aclk-domain datapath (phase_ctrl_sgmux8/dds_top_mixmux8), WITHOUT
# a per-bit synchronizer -- software is expected to hold them stable across
# the WE_REG pulse (quasi-static CDC, inherited from the legacy design).
set_false_path -from [get_cells -hier -filter {NAME =~ "*axil_slv_i/o_slv_regs_reg*"}] \
                -to   [get_cells -hier -filter {NAME =~ "*phase_ctrl_i/pinc_reg_r_reg*" || NAME =~ "*phase_ctrl_i/poff_reg_r_reg*"}]
