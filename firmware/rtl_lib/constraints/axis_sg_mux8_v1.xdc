# axis_sg_mux8_v1.xdc
#
# Timing exceptions for axis_sg_mux8_v1.
#
# NOT validated against a real Vivado synthesis run in this environment (no
# Vivado project available here) -- the legacy IP (firmware/ip/axis_sg_mux8_v1)
# had no packaged-IP-level constraints of its own (its only synth XDC
# constrained the bare sg_mux8 sub-block directly, with a blanket
# `set_false_path -to [all_outputs]`, appropriate only for a standalone
# datapath timing check, not a real integration). These rules are re-derived
# for the actual AXI-Lite-wrapped IP boundary and its known CDC crossings --
# review before relying on it for real timing closure.

# WE_REG is resynchronized into the aclk domain via cdc_bit_sync
# (ASYNC_REG-tagged internal register) inside phase_ctrl_sgmux8, one
# instance per output channel (8x) -- generic ASYNC_REG-based rule, matches
# the upgraded (name-independent) approach used by qick_processor.xdc.
set_false_path -to [get_cells -hier -filter {ASYNC_REG == "TRUE"}]

# PINC/POFF/GAIN are plain axil_slv registers (s_axi_aclk domain) read
# directly by the aclk-domain datapath (phase_ctrl_sgmux8/dds_top_sgmux8),
# WITHOUT a per-bit synchronizer -- software is expected to hold them
# stable across the WE_REG pulse (quasi-static CDC, inherited from the
# legacy design, not a defect introduced by this port). Treat the crossing
# as false-path since only WE_REG's own edge (already covered above) gates
# when the value is sampled.
set_false_path -from [get_cells -hier -filter {NAME =~ "*axil_slv_i/o_slv_regs_reg*"}] \
                -to   [get_cells -hier -filter {NAME =~ "*phase_ctrl_i/pinc_reg_r_reg*" || NAME =~ "*phase_ctrl_i/poff_reg_r_reg*"}]
