set clk_axi [get_clocks -of_objects [get_nets -of_objects [get_pins d_1_i/usp_rf_data_converter_0/s_axi_aclk]]]
set clk_adc0_x2  [get_clocks -of_objects [get_nets -of_objects [get_pins d_1_i/clk_adc0_x2/clk_out1]]]
set clk_dac0 [get_clocks -of_objects [get_nets -of_objects [get_pins d_1_i/usp_rf_data_converter_0/clk_dac0]]]
set clk_dac1 [get_clocks -of_objects [get_nets -of_objects [get_pins d_1_i/usp_rf_data_converter_0/clk_dac1]]]
set clk_ddr4  [get_clocks -of_objects [get_nets -of_objects [get_pins d_1_i/ddr4_0/c0_ddr4_ui_clk]]]
    
#set_clock_group -name clk_axi_to_fabric -asynchronous \
#    -group [get_clocks $clk_axi] \
#    -group [get_clocks $clk_dac0] \
#    -group [get_clocks $clk_dac1] \
#    -group [get_clocks $clk_adc0_x2]
    
#set_clock_group -name clk_adc_to_adc_x2 -asynchronous \
#    -group [get_clocks $clk_adc0] \
#    -group [get_clocks $clk_adc0_x2]



set_clock_group -name clk_axi_to_adc0_x2 -asynchronous \
    -group [get_clocks $clk_axi] \
    -group [get_clocks $clk_adc0_x2]
        
set_clock_group -name clk_axi_to_dac0 -asynchronous \
    -group [get_clocks $clk_axi] \
    -group [get_clocks $clk_dac0]
            
set_clock_group -name clk_axi_to_dac1 -asynchronous \
    -group [get_clocks $clk_axi] \
    -group [get_clocks $clk_dac1]
        
set_clock_group -name clk_tproc_to_dac1 -asynchronous \
    -group [get_clocks $clk_dac0] \
    -group [get_clocks $clk_dac1]
    
set_clock_group -name clk_tproc_to_adc0_x2 -asynchronous \
    -group [get_clocks $clk_dac0] \
    -group [get_clocks $clk_adc0_x2]

set_clock_group -name clk_axi_to_ddr4 -asynchronous \
    -group [get_clocks $clk_axi] \
    -group [get_clocks $clk_ddr4]    

set_clock_group -name clk_ddr4_to_adc0_x2 -asynchronous \
    -group [get_clocks $clk_ddr4] \
    -group [get_clocks $clk_adc0_x2]    

set_false_path -from [get_cells d_1_i/axis_set_reg_0/U0/dout_r_reg*]   

