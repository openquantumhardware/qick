create_clock -period 5.000 -name s_axis_aclk -waveform {0.000 2.500} [get_ports s_axis_aclk]
create_clock -period 2.000 -name m_axis_aclk -waveform {0.000 1.000} [get_ports m_axis_aclk]
