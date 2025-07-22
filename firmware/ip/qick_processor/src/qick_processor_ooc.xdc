create_clock -period 10.000 -name ps_clk_i -waveform {0.000 5.000} [get_ports ps_clk_i]
create_clock -period 1.620 -name t_clk_i -waveform {0.000 0.810} [get_ports t_clk_i]
create_clock -period 5.000 -name c_clk_i -waveform {0.000 2.500} [get_ports c_clk_i]
set_clock_groups -asynchronous -group [get_clocks c_clk_i] -group [get_clocks t_clk_i] -group [get_clocks ps_clk_i]

