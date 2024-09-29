set clk_axi  [get_clocks -of_objects [get_nets -of_objects [get_pins d_1_i/zynq_ultra_ps_e_0/pl_clk0]]]
set clk_adc0 [get_clocks -of_objects [get_nets -of_objects [get_pins d_1_i/usp_rf_data_converter_0/clk_adc0]]]
#set clk_dac0 [get_clocks -of_objects [get_nets -of_objects [get_pins d_1_i/usp_rf_data_converter_0/clk_dac0]]]
set clk_dac2 [get_clocks -of_objects [get_nets -of_objects [get_pins d_1_i/usp_rf_data_converter_0/clk_dac2]]]
set clk_adc0_x2 [get_clocks -of_objects [get_nets -of_objects [get_pins d_1_i/clk_adc0_x2/clk_out1]]]

# tProc core
set clk_core [get_clocks -of_objects [get_nets -of_objects [get_pins d_1_i/clk_core/clk_out1]]]

set clk_ddr4  [get_clocks -of_objects [get_nets -of_objects [get_pins d_1_i/ddr4/ddr4_0/c0_ddr4_ui_clk]]]

# AXI to gen/RO fabric
set_clock_group -name clk_axi_to_adc0_x2 -asynchronous \
    -group [get_clocks $clk_axi] \
    -group [get_clocks $clk_adc0_x2]

#set_clock_group -name clk_axi_to_dac0 -asynchronous \
#    -group [get_clocks $clk_axi] \
#    -group [get_clocks $clk_dac0]

set_clock_group -name clk_axi_to_dac2 -asynchronous \
    -group [get_clocks $clk_axi] \
    -group [get_clocks $clk_dac2]

# AXI to tproc
#set_clock_group -name clk_axi_to_tproc -asynchronous \
#    -group [get_clocks $clk_axi] \
#    -group [get_clocks $clk_tproc]

# tproc to gen/RO fabric
#set_clock_group -name clk_tproc_to_dac0 -asynchronous \
#    -group [get_clocks $clk_tproc] \
#    -group [get_clocks $clk_dac0]

#set_clock_group -name clk_tproc_to_dac2 -asynchronous \
#    -group [get_clocks $clk_dac0] \
#    -group [get_clocks $clk_dac2]

set_clock_group -name clk_tproc_to_adc0_x2 -asynchronous \
    -group [get_clocks $clk_dac2] \
    -group [get_clocks $clk_adc0_x2]

set_clock_group -name clk_axi_to_core -asynchronous \
    -group [get_clocks $clk_axi] \
    -group [get_clocks $clk_core]

set_clock_group -name clk_core_to_tproc -asynchronous \
    -group [get_clocks $clk_core] \
    -group [get_clocks $clk_dac2]

set_clock_group -name clk_core_to_adc0_x2 -asynchronous \
    -group [get_clocks $clk_core] \
    -group [get_clocks $clk_adc0_x2]

# axi to DDR4, DDR4 to RO fabric
set_clock_group -name clk_axi_to_ddr4 -asynchronous \
    -group [get_clocks $clk_axi] \
    -group [get_clocks $clk_ddr4]   
    
set_clock_group -name clk_ddr4_to_adc0_x2 -asynchronous \
    -group [get_clocks $clk_ddr4] \
    -group [get_clocks $clk_adc0_x2]

# readout triggers
#set_false_path -through [get_cells d_1_i/qick_vec2bit_1]
set_false_path -through [get_pins d_1_i/qick_processor_0/trig_*_o]

# reset
set_false_path -through [get_pins d_1_i/rst_dac2/peripheral_aresetn[0]]

# from https://github.com/Xilinx/RFSoC-MTS/blob/main/boards/RFSoC4x2/build_mts/mts.xdc
#set_property BLOCK_SYNTH.RETIMING 1 [get_cells d_1_i/ddr4_0]
#set_property BLOCK_SYNTH.STRATEGY {PERFORMANCE_OPTIMIZED} [get_cells d_1_i/ddr4_0]

#set_property BLOCK_SYNTH.RETIMING 1 [get_cells {d_1_i/usp_rf_data_converter_0/*}]
#set_property BLOCK_SYNTH.STRATEGY {PERFORMANCE_OPTIMIZED} [get_cells {d_1_i/usp_rf_data_converter_0/*}]
