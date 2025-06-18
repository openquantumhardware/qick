set_property PACKAGE_PIN C17 [get_ports PMOD0_0_LS]
set_property IOSTANDARD LVCMOS12 [get_ports PMOD0_0_LS]
set_property PACKAGE_PIN M18 [get_ports PMOD0_1_LS]
set_property IOSTANDARD LVCMOS12 [get_ports PMOD0_1_LS]
set_property PACKAGE_PIN H16 [get_ports PMOD0_2_LS]
set_property IOSTANDARD LVCMOS12 [get_ports PMOD0_2_LS]
set_property PACKAGE_PIN H17 [get_ports PMOD0_3_LS]
set_property IOSTANDARD LVCMOS12 [get_ports PMOD0_3_LS]
set_property PACKAGE_PIN J16 [get_ports PMOD0_4_LS]
set_property IOSTANDARD LVCMOS12 [get_ports PMOD0_4_LS]
set_property PACKAGE_PIN K16 [get_ports PMOD0_5_LS]
set_property IOSTANDARD LVCMOS12 [get_ports PMOD0_5_LS]
set_property PACKAGE_PIN H15 [get_ports PMOD0_6_LS]
set_property IOSTANDARD LVCMOS12 [get_ports PMOD0_6_LS]
set_property PACKAGE_PIN J15 [get_ports PMOD0_7_LS]
set_property IOSTANDARD LVCMOS12 [get_ports PMOD0_7_LS]

set_property PACKAGE_PIN L14 [get_ports PMOD1_0_LS]
set_property IOSTANDARD LVCMOS12 [get_ports PMOD1_0_LS]
set_property PACKAGE_PIN L15 [get_ports PMOD1_1_LS]
set_property IOSTANDARD LVCMOS12 [get_ports PMOD1_1_LS]
#set_property PACKAGE_PIN M13      	[get_ports "PMOD1_2_LS"];
#set_property IOSTANDARD  LVCMOS12 	[get_ports "PMOD1_2_LS"];
#set_property PACKAGE_PIN N13      	[get_ports "PMOD1_3_LS"];
#set_property IOSTANDARD  LVCMOS12 	[get_ports "PMOD1_3_LS"];
#set_property PACKAGE_PIN M15      	[get_ports "PMOD1_4_LS"];
#set_property IOSTANDARD  LVCMOS12 	[get_ports "PMOD1_4_LS"];
#set_property PACKAGE_PIN N15      	[get_ports "PMOD1_5_LS"];
#set_property IOSTANDARD  LVCMOS12 	[get_ports "PMOD1_5_LS"];
#set_property PACKAGE_PIN M14      	[get_ports "PMOD1_6_LS"];
#set_property IOSTANDARD  LVCMOS12 	[get_ports "PMOD1_6_LS"];
#set_property PACKAGE_PIN N14      	[get_ports "PMOD1_7_LS"];
#set_property IOSTANDARD  LVCMOS12 	[get_ports "PMOD1_7_LS"];

create_debug_core u_ila_0 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_DATA_DEPTH 1024 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property port_width 1 [get_debug_ports u_ila_0/clk]
connect_debug_port u_ila_0/clk [get_nets [list d_1_i/clk_rst_wrapper/clk_adc0_x2/inst/clk_out1]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
set_property port_width 32 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {d_1_i/readout_wrapper/axis_streamer_v1_0/inst/streamer_i/LOST_REG[0]} {d_1_i/readout_wrapper/axis_streamer_v1_0/inst/streamer_i/LOST_REG[1]} {d_1_i/readout_wrapper/axis_streamer_v1_0/inst/streamer_i/LOST_REG[2]} {d_1_i/readout_wrapper/axis_streamer_v1_0/inst/streamer_i/LOST_REG[3]} {d_1_i/readout_wrapper/axis_streamer_v1_0/inst/streamer_i/LOST_REG[4]} {d_1_i/readout_wrapper/axis_streamer_v1_0/inst/streamer_i/LOST_REG[5]} {d_1_i/readout_wrapper/axis_streamer_v1_0/inst/streamer_i/LOST_REG[6]} {d_1_i/readout_wrapper/axis_streamer_v1_0/inst/streamer_i/LOST_REG[7]} {d_1_i/readout_wrapper/axis_streamer_v1_0/inst/streamer_i/LOST_REG[8]} {d_1_i/readout_wrapper/axis_streamer_v1_0/inst/streamer_i/LOST_REG[9]} {d_1_i/readout_wrapper/axis_streamer_v1_0/inst/streamer_i/LOST_REG[10]} {d_1_i/readout_wrapper/axis_streamer_v1_0/inst/streamer_i/LOST_REG[11]} {d_1_i/readout_wrapper/axis_streamer_v1_0/inst/streamer_i/LOST_REG[12]} {d_1_i/readout_wrapper/axis_streamer_v1_0/inst/streamer_i/LOST_REG[13]} {d_1_i/readout_wrapper/axis_streamer_v1_0/inst/streamer_i/LOST_REG[14]} {d_1_i/readout_wrapper/axis_streamer_v1_0/inst/streamer_i/LOST_REG[15]} {d_1_i/readout_wrapper/axis_streamer_v1_0/inst/streamer_i/LOST_REG[16]} {d_1_i/readout_wrapper/axis_streamer_v1_0/inst/streamer_i/LOST_REG[17]} {d_1_i/readout_wrapper/axis_streamer_v1_0/inst/streamer_i/LOST_REG[18]} {d_1_i/readout_wrapper/axis_streamer_v1_0/inst/streamer_i/LOST_REG[19]} {d_1_i/readout_wrapper/axis_streamer_v1_0/inst/streamer_i/LOST_REG[20]} {d_1_i/readout_wrapper/axis_streamer_v1_0/inst/streamer_i/LOST_REG[21]} {d_1_i/readout_wrapper/axis_streamer_v1_0/inst/streamer_i/LOST_REG[22]} {d_1_i/readout_wrapper/axis_streamer_v1_0/inst/streamer_i/LOST_REG[23]} {d_1_i/readout_wrapper/axis_streamer_v1_0/inst/streamer_i/LOST_REG[24]} {d_1_i/readout_wrapper/axis_streamer_v1_0/inst/streamer_i/LOST_REG[25]} {d_1_i/readout_wrapper/axis_streamer_v1_0/inst/streamer_i/LOST_REG[26]} {d_1_i/readout_wrapper/axis_streamer_v1_0/inst/streamer_i/LOST_REG[27]} {d_1_i/readout_wrapper/axis_streamer_v1_0/inst/streamer_i/LOST_REG[28]} {d_1_i/readout_wrapper/axis_streamer_v1_0/inst/streamer_i/LOST_REG[29]} {d_1_i/readout_wrapper/axis_streamer_v1_0/inst/streamer_i/LOST_REG[30]} {d_1_i/readout_wrapper/axis_streamer_v1_0/inst/streamer_i/LOST_REG[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
set_property port_width 1 [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list d_1_i/readout_wrapper/axis_streamer_v1_0/inst/streamer_i/run_state]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
set_property port_width 1 [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list d_1_i/readout_wrapper/axis_streamer_v1_0/inst/streamer_i/wait_end_state]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
set_property port_width 1 [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list d_1_i/readout_wrapper/axis_streamer_v1_0/inst/streamer_i/s_axis_tvalid]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
set_property port_width 1 [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list d_1_i/readout_wrapper/axis_streamer_v1_0/inst/streamer_i/s_axis_tready]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe5]
set_property port_width 1 [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list d_1_i/readout_wrapper/axis_streamer_v1_0/inst/streamer_i/m_axis_tlast]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe6]
set_property port_width 1 [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [get_nets [list d_1_i/readout_wrapper/axis_streamer_v1_0/inst/streamer_i/m_axis_tready]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe7]
set_property port_width 1 [get_debug_ports u_ila_0/probe7]
connect_debug_port u_ila_0/probe7 [get_nets [list d_1_i/readout_wrapper/axis_streamer_v1_0/inst/streamer_i/fifo_wr_en]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe8]
set_property port_width 1 [get_debug_ports u_ila_0/probe8]
connect_debug_port u_ila_0/probe8 [get_nets [list d_1_i/readout_wrapper/axis_streamer_v1_0/inst/streamer_i/fifo_i/rd_en_i]]
create_debug_core u_ila_1 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_1]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_1]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_1]
set_property C_DATA_DEPTH 1024 [get_debug_cores u_ila_1]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_1]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_1]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_1]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_1]
set_property port_width 1 [get_debug_ports u_ila_1/clk]
connect_debug_port u_ila_1/clk [get_nets [list d_1_i/zynq_ultra_ps_e_0/inst/pl_clk0]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe0]
set_property port_width 32 [get_debug_ports u_ila_1/probe0]
connect_debug_port u_ila_1/probe0 [get_nets [list {d_1_i/readout_wrapper/axis_streamer_v1_0/inst/streamer_i/NSAMP_REG[0]} {d_1_i/readout_wrapper/axis_streamer_v1_0/inst/streamer_i/NSAMP_REG[1]} {d_1_i/readout_wrapper/axis_streamer_v1_0/inst/streamer_i/NSAMP_REG[2]} {d_1_i/readout_wrapper/axis_streamer_v1_0/inst/streamer_i/NSAMP_REG[3]} {d_1_i/readout_wrapper/axis_streamer_v1_0/inst/streamer_i/NSAMP_REG[4]} {d_1_i/readout_wrapper/axis_streamer_v1_0/inst/streamer_i/NSAMP_REG[5]} {d_1_i/readout_wrapper/axis_streamer_v1_0/inst/streamer_i/NSAMP_REG[6]} {d_1_i/readout_wrapper/axis_streamer_v1_0/inst/streamer_i/NSAMP_REG[7]} {d_1_i/readout_wrapper/axis_streamer_v1_0/inst/streamer_i/NSAMP_REG[8]} {d_1_i/readout_wrapper/axis_streamer_v1_0/inst/streamer_i/NSAMP_REG[9]} {d_1_i/readout_wrapper/axis_streamer_v1_0/inst/streamer_i/NSAMP_REG[10]} {d_1_i/readout_wrapper/axis_streamer_v1_0/inst/streamer_i/NSAMP_REG[11]} {d_1_i/readout_wrapper/axis_streamer_v1_0/inst/streamer_i/NSAMP_REG[12]} {d_1_i/readout_wrapper/axis_streamer_v1_0/inst/streamer_i/NSAMP_REG[13]} {d_1_i/readout_wrapper/axis_streamer_v1_0/inst/streamer_i/NSAMP_REG[14]} {d_1_i/readout_wrapper/axis_streamer_v1_0/inst/streamer_i/NSAMP_REG[15]} {d_1_i/readout_wrapper/axis_streamer_v1_0/inst/streamer_i/NSAMP_REG[16]} {d_1_i/readout_wrapper/axis_streamer_v1_0/inst/streamer_i/NSAMP_REG[17]} {d_1_i/readout_wrapper/axis_streamer_v1_0/inst/streamer_i/NSAMP_REG[18]} {d_1_i/readout_wrapper/axis_streamer_v1_0/inst/streamer_i/NSAMP_REG[19]} {d_1_i/readout_wrapper/axis_streamer_v1_0/inst/streamer_i/NSAMP_REG[20]} {d_1_i/readout_wrapper/axis_streamer_v1_0/inst/streamer_i/NSAMP_REG[21]} {d_1_i/readout_wrapper/axis_streamer_v1_0/inst/streamer_i/NSAMP_REG[22]} {d_1_i/readout_wrapper/axis_streamer_v1_0/inst/streamer_i/NSAMP_REG[23]} {d_1_i/readout_wrapper/axis_streamer_v1_0/inst/streamer_i/NSAMP_REG[24]} {d_1_i/readout_wrapper/axis_streamer_v1_0/inst/streamer_i/NSAMP_REG[25]} {d_1_i/readout_wrapper/axis_streamer_v1_0/inst/streamer_i/NSAMP_REG[26]} {d_1_i/readout_wrapper/axis_streamer_v1_0/inst/streamer_i/NSAMP_REG[27]} {d_1_i/readout_wrapper/axis_streamer_v1_0/inst/streamer_i/NSAMP_REG[28]} {d_1_i/readout_wrapper/axis_streamer_v1_0/inst/streamer_i/NSAMP_REG[29]} {d_1_i/readout_wrapper/axis_streamer_v1_0/inst/streamer_i/NSAMP_REG[30]} {d_1_i/readout_wrapper/axis_streamer_v1_0/inst/streamer_i/NSAMP_REG[31]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe1]
set_property port_width 1 [get_debug_ports u_ila_1/probe1]
connect_debug_port u_ila_1/probe1 [get_nets [list d_1_i/readout_wrapper/axis_streamer_v1_0/inst/streamer_i/START_REG]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe2]
set_property port_width 1 [get_debug_ports u_ila_1/probe2]
connect_debug_port u_ila_1/probe2 [get_nets [list d_1_i/readout_wrapper/axis_streamer_v1_0/inst/streamer_i/MODE_REG]]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets clk]
