# axis_pfb_readout_v3.xdc
#
# Timing exceptions for axis_pfb_readout_v3.
#
# ID/PINC/POFF are plain axil_slv registers (s_axi_aclk domain) read directly
# by the aclk-domain datapath, WITHOUT a synchronizer, as in the legacy IP:
# software writes them while the output is not in use (quasi-static CDC, same
# pattern as axis_readout_v2.xdc / axis_sg_mux8_v1.xdc).
set_false_path -from [get_cells -hier -filter {NAME =~ "*axil_slv_i/o_slv_regs_reg*"}] \
               -to   [get_cells -hier -filter {NAME =~ "*pfb_readout_i/*"}]
