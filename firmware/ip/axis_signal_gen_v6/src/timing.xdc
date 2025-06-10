create_clock -period 10.000 -name s_axi_aclk -waveform {0.000 5.000} [get_ports s_axi_aclk]
create_clock -period 2.000 -name aclk -waveform {0.000 1.000} [get_ports aclk]
create_clock -period 10.000 -name s0_axis_aclk -waveform {0.000 5.000} [get_ports s0_axis_aclk]

set_clock_groups -asynchronous -group [get_clocks aclk] -group [get_clocks s0_axis_aclk] -group [get_clocks s_axi_aclk]



set _xlnx_shared_i0 [get_ports s1_axis_t*]
set_false_path -from $_xlnx_shared_i0
