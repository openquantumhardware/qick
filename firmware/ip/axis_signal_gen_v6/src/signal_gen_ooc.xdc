create_clock -period 10.000 -name s_axi_aclk -waveform {0.000 5.000} [get_ports s_axi_aclk]
create_clock -period 4.000 -name s0_axis_aclk -waveform {0.000 2.000} [get_ports s0_axis_aclk]
create_clock -period 1.600 -name aclk -waveform {0.000 0.800} [get_ports aclk]
