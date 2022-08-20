set clk_axi [get_clocks -of_objects [get_nets -of_objects [get_pins d_1_i/axis_signal_gen_v4_0/s_axi_aclk]]]

# ADC/DAC
set clk_adc0  [get_clocks -of_objects [get_nets -of_objects [get_pins d_1_i/usp_rf_data_converter_0/clk_adc0]]]
set clk_adc0_x2  [get_clocks -of_objects [get_nets -of_objects [get_pins d_1_i/axis_readout_v2_0/aclk]]]
set clk_dac0 [get_clocks -of_objects [get_nets -of_objects [get_pins d_1_i/axis_signal_gen_v4_0/aclk]]]
set clk_dac1 [get_clocks -of_objects [get_nets -of_objects [get_pins d_1_i/axis_signal_gen_v4_3/aclk]]]
    
set_clock_group -name clk_axi_to_dac0 -asynchronous \
    -group [get_clocks $clk_axi] \
    -group [get_clocks $clk_dac0]
    
set_clock_group -name clk_axi_to_dac1 -asynchronous \
    -group [get_clocks $clk_axi] \
    -group [get_clocks $clk_dac1]    
    
set_clock_group -name clk_axi_to_adc -asynchronous \
    -group [get_clocks $clk_axi] \
    -group [get_clocks $clk_adc0_x2]  
    
set_clock_group -name clk_dac0_to_adc -asynchronous \
    -group [get_clocks $clk_dac0] \
    -group [get_clocks $clk_adc0_x2]       
    
set_clock_group -name clk_dac1_to_adc -asynchronous \
    -group [get_clocks $clk_dac1] \
    -group [get_clocks $clk_adc0_x2]    
    
set_clock_group -name clk_dac0_to_dac1 -asynchronous \
    -group [get_clocks $clk_dac0] \
    -group [get_clocks $clk_dac1]
    
set_clock_group -name clk_adc_to_adc_x2 -asynchronous \
    -group [get_clocks $clk_adc0] \
    -group [get_clocks $clk_adc0_x2]
                    