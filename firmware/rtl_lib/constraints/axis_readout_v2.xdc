# axis_readout_v2.xdc
#
# Timing exceptions for axis_readout_v2.
#
# NOT validated against a real Vivado synthesis run in this environment (no
# Vivado project available here) -- the legacy IP had no packaged-IP-level
# constraints at all.
#
# WE_REG is resynchronized into the aclk domain via cdc_bit_sync
# (ASYNC_REG-tagged internal register) inside readout_top_ro_v2.
set_false_path -to [get_cells -hier -filter {ASYNC_REG == "TRUE"}]

# FREQ/PHASE/NSAMP/OUTSEL/MODE are plain axil_slv registers (s_axi_aclk
# domain) read directly by the aclk-domain descriptor FIFO write data,
# WITHOUT a per-bit synchronizer -- software is expected to hold them
# stable across the WE_REG pulse (quasi-static CDC, same pattern as
# axis_sg_mux8_v1.xdc's PINC/POFF crossing).
set_false_path -from [get_cells -hier -filter {NAME =~ "*axil_slv_i/o_slv_regs_reg*"}] \
                -to   [get_cells -hier -filter {NAME =~ "*readout_top_i/fifo_i/*"}]
