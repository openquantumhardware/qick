set clk_axi [get_clocks -of_objects [get_nets -of_objects [get_pins d_1_i/axis_signal_gen_v4_0/s_axi_aclk]]]

# ADC/DAC
set clk_adc2  [get_clocks -of_objects [get_nets -of_objects [get_pins d_1_i/usp_rf_data_converter_0/clk_adc2]]]
set clk_adc3  [get_clocks -of_objects [get_nets -of_objects [get_pins d_1_i/usp_rf_data_converter_0/clk_adc3]]]
set clk_dac2 [get_clocks -of_objects [get_nets -of_objects [get_pins d_1_i/axis_signal_gen_v4_0/aclk]]]
set clk_dac3 [get_clocks -of_objects [get_nets -of_objects [get_pins d_1_i/axis_signal_gen_v4_4/aclk]]]
    
set_clock_group -name clk_axi_to_dac2 -asynchronous \
    -group [get_clocks $clk_axi] \
    -group [get_clocks $clk_dac2]
    
set_clock_group -name clk_axi_to_dac3 -asynchronous \
    -group [get_clocks $clk_axi] \
    -group [get_clocks $clk_dac3]    
    
set_clock_group -name clk_axi_to_adc2 -asynchronous \
    -group [get_clocks $clk_axi] \
    -group [get_clocks $clk_adc2]  
    
set_clock_group -name clk_dac2_to_adc2 -asynchronous \
    -group [get_clocks $clk_dac2] \
    -group [get_clocks $clk_adc2]       
    
set_clock_group -name clk_dac3_to_adc2 -asynchronous \
    -group [get_clocks $clk_dac3] \
    -group [get_clocks $clk_adc2]    
    
set_clock_group -name clk_dac2_to_dac3 -asynchronous \
    -group [get_clocks $clk_dac2] \
    -group [get_clocks $clk_dac3]

set_clock_group -name clk_axi_to_adc3 -asynchronous \
    -group [get_clocks $clk_axi] \
    -group [get_clocks $clk_adc3]  
    
set_clock_group -name clk_dac2_to_adc3 -asynchronous \
    -group [get_clocks $clk_dac2] \
    -group [get_clocks $clk_adc3]       
    
set_clock_group -name clk_dac3_to_adc3 -asynchronous \
    -group [get_clocks $clk_dac3] \
    -group [get_clocks $clk_adc3]    
                        