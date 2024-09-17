set clk_axi [get_clocks -of_objects [get_nets -of_objects [get_pins d_1_i/usp_rf_data_converter_0/s_axi_aclk]]]

# tProc core
set clk_core [get_clocks -of_objects [get_nets -of_objects [get_pins d_1_i/clk_core/clk_out1]]]

# ADC/DAC
set clk_adc2  [get_clocks -of_objects [get_nets -of_objects [get_pins d_1_i/usp_rf_data_converter_0/clk_adc2]]]
#set clk_adc2_x2 [get_clocks -of_objects [get_nets -of_objects [get_pins d_1_i/clk_adc2_x2/clk_out1]]]

#set clk_dac1 [get_clocks -of_objects [get_nets -of_objects [get_pins d_1_i/usp_rf_data_converter_0/clk_dac1]]]
set clk_dac0 [get_clocks -of_objects [get_nets -of_objects [get_pins d_1_i/usp_rf_data_converter_0/clk_dac0]]]
# this is also tProc timing clock
set clk_dac2 [get_clocks -of_objects [get_nets -of_objects [get_pins d_1_i/usp_rf_data_converter_0/clk_dac2]]]

set clk_ddr4  [get_clocks -of_objects [get_nets -of_objects [get_pins d_1_i/ddr4_0/c0_ddr4_ui_clk]]]

# AXI clock to data clocks
set_clock_group -name clk_axi_to_adc2 -asynchronous \
    -group [get_clocks $clk_axi] \
    -group [get_clocks $clk_adc2]
    
#set_clock_group -name clk_axi_to_adc2_x2 -asynchronous \
#    -group [get_clocks $clk_axi] \
#    -group [get_clocks $clk_adc2_x2]

#set_clock_group -name clk_axi_to_dac1 -asynchronous \
#    -group [get_clocks $clk_axi] \
#    -group [get_clocks $clk_dac1]

set_clock_group -name clk_axi_to_dac2 -asynchronous \
    -group [get_clocks $clk_axi] \
    -group [get_clocks $clk_dac2]

set_clock_group -name clk_axi_to_dac0 -asynchronous \
    -group [get_clocks $clk_axi] \
    -group [get_clocks $clk_dac0]

# tProc timing clock to generator clocks
#set_clock_group -name clk_tproc_to_dac1 -asynchronous \
#    -group [get_clocks $clk_dac2] \
#    -group [get_clocks $clk_dac1]

set_clock_group -name clk_tproc_to_dac0 -asynchronous \
    -group [get_clocks $clk_dac2] \
    -group [get_clocks $clk_dac0]

set_clock_group -name clk_tproc_to_adc2 -asynchronous \
    -group [get_clocks $clk_dac2] \
    -group [get_clocks $clk_adc2]

#set_clock_group -name clk_tproc_to_adc2_x2 -asynchronous \
#    -group [get_clocks $clk_dac2] \
#    -group [get_clocks $clk_adc2_x2]

set_clock_group -name clk_axi_to_core -asynchronous \
    -group [get_clocks $clk_axi] \
    -group [get_clocks $clk_core]

# tProc core clock and timing clocks 
set_clock_group -name clk_core_to_tproc -asynchronous \
    -group [get_clocks $clk_core] \
    -group [get_clocks $clk_dac2]

# tProc core clock and readout clocks (for readouts that drive tProc inputs)
set_clock_group -name clk_core_to_adc2 -asynchronous \
    -group [get_clocks $clk_core] \
    -group [get_clocks $clk_adc2]

#set_clock_group -name clk_core_to_adc2_x2 -asynchronous \
#    -group [get_clocks $clk_core] \
#    -group [get_clocks $clk_adc2_x2]

# AXI clock and DDR4 clock
set_clock_group -name clk_axi_to_ddr4 -asynchronous \
    -group [get_clocks $clk_axi] \
    -group [get_clocks $clk_ddr4]

# AXI clock and readout data clock
set_clock_group -name clk_ddr4_to_adc2 -asynchronous \
    -group [get_clocks $clk_ddr4] \
    -group [get_clocks $clk_adc2]

#set_clock_group -name clk_adc2_to_adc2_x2 -asynchronous \
#    -group [get_clocks $clk_adc2] \
#    -group [get_clocks $clk_adc2_x2]

# readout triggers
#set_false_path -through [get_cells d_1_i/qick_vec2bit_1]
set_false_path -through [get_pins d_1_i/qick_processor_0/trig_*_o]

# reset
set_false_path -through [get_pins d_1_i/rst_dac2/peripheral_aresetn[0]]
set_false_path -through [get_pins d_1_i/rst_dac0/peripheral_aresetn[0]]

## PMOD outputs
#set_false_path -to [get_ports PMOD0_*]
## PMOD inputs
#set_false_path -from [get_ports PMOD1_*]
## DDR4 reset output
#set_false_path -to [get_ports ddr4_sdram_c0_reset_n]