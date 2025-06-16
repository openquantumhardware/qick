set_property PACKAGE_PIN G15 [get_ports PMOD0_0_LS]
set_property IOSTANDARD LVCMOS18 [get_ports PMOD0_0_LS]
set_property PACKAGE_PIN G16 [get_ports PMOD0_1_LS]
set_property IOSTANDARD LVCMOS18 [get_ports PMOD0_1_LS]
set_property PACKAGE_PIN H14 [get_ports PMOD0_2_LS]
set_property IOSTANDARD LVCMOS18 [get_ports PMOD0_2_LS]
set_property PACKAGE_PIN H15 [get_ports PMOD0_3_LS]
set_property IOSTANDARD LVCMOS18 [get_ports PMOD0_3_LS]
set_property PACKAGE_PIN G13 [get_ports PMOD0_4_LS]
set_property IOSTANDARD LVCMOS18 [get_ports PMOD0_4_LS]
set_property PACKAGE_PIN H13 [get_ports PMOD0_5_LS]
set_property IOSTANDARD LVCMOS18 [get_ports PMOD0_5_LS]
set_property PACKAGE_PIN J13 [get_ports PMOD0_6_LS]
set_property IOSTANDARD LVCMOS18 [get_ports PMOD0_6_LS]
set_property PACKAGE_PIN J14 [get_ports PMOD0_7_LS]
set_property IOSTANDARD LVCMOS18 [get_ports PMOD0_7_LS]

#set_property PACKAGE_PIN L17 [get_ports PMOD1_0_LS]
#set_property IOSTANDARD LVCMOS18 [get_ports PMOD1_0_LS]
#set_property PACKAGE_PIN M17 [get_ports PMOD1_1_LS]
#set_property IOSTANDARD LVCMOS18 [get_ports PMOD1_1_LS]
#set_property PACKAGE_PIN M14       [get_ports "PMOD1_2_LS"] ;# Bank  88 VCCO - VCC1V8   - IO_L3N_AD13N_88
#set_property IOSTANDARD  LVCMOS18  [get_ports "PMOD1_2_LS"] ;# Bank  88 VCCO - VCC1V8   - IO_L3N_AD13N_88
set_property PACKAGE_PIN N14       [get_ports "XCOM_ISYNC"]; # Bank  88 VCCO - VCC1V8   - IO_L3P_AD13P_88
set_property IOSTANDARD  LVCMOS18  [get_ports "XCOM_ISYNC"]; # Bank  88 VCCO - VCC1V8   - IO_L3P_AD13P_88
#set_property PACKAGE_PIN M15       [get_ports "PMOD1_4_LS"] ;# Bank  88 VCCO - VCC1V8   - IO_L2N_AD14N_88
#set_property IOSTANDARD  LVCMOS18  [get_ports "PMOD1_4_LS"] ;# Bank  88 VCCO - VCC1V8   - IO_L2N_AD14N_88
#set_property PACKAGE_PIN N15       [get_ports "PMOD1_5_LS"] ;# Bank  88 VCCO - VCC1V8   - IO_L2P_AD14P_88
#set_property IOSTANDARD  LVCMOS18  [get_ports "PMOD1_5_LS"] ;# Bank  88 VCCO - VCC1V8   - IO_L2P_AD14P_88
#set_property PACKAGE_PIN M16       [get_ports "PMOD1_6_LS"] ;# Bank  88 VCCO - VCC1V8   - IO_L1N_AD15N_88
#set_property IOSTANDARD  LVCMOS18  [get_ports "PMOD1_6_LS"] ;# Bank  88 VCCO - VCC1V8   - IO_L1N_AD15N_88
#set_property PACKAGE_PIN N16       [get_ports "PMOD1_7_LS"] ;# Bank  88 VCCO - VCC1V8   - IO_L1P_AD15P_88
#set_property IOSTANDARD  LVCMOS18  [get_ports "PMOD1_7_LS"] ;# Bank  88 VCCO - VCC1V8   - IO_L1P_AD15P_88

set clk_axi [get_clocks -of_objects [get_nets -of_objects [get_pins tprocv2r21_standard_i/usp_rf_data_converter_0/s_axi_aclk]]]

# tProc core
set clk_core [get_clocks -of_objects [get_nets -of_objects [get_pins tprocv2r21_standard_i/clk_core/clk_out1]]]

# ADC/DAC
set clk_adc2  [get_clocks -of_objects [get_nets -of_objects [get_pins tprocv2r21_standard_i/usp_rf_data_converter_0/clk_adc2]]]
#set clk_adc2_x2 [get_clocks -of_objects [get_nets -of_objects [get_pins tprocv2r21_standard_i/clk_adc2_x2/clk_out1]]]

#set clk_dac1 [get_clocks -of_objects [get_nets -of_objects [get_pins tprocv2r21_standard_i/usp_rf_data_converter_0/clk_dac1]]]
set clk_dac0 [get_clocks -of_objects [get_nets -of_objects [get_pins tprocv2r21_standard_i/usp_rf_data_converter_0/clk_dac0]]]
# this is also tProc timing clock
set clk_dac2 [get_clocks -of_objects [get_nets -of_objects [get_pins tprocv2r21_standard_i/usp_rf_data_converter_0/clk_dac2]]]

set clk_ddr4  [get_clocks -of_objects [get_nets -of_objects [get_pins tprocv2r21_standard_i/ddr4/ddr4_0/c0_ddr4_ui_clk]]]

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
#set_false_path -through [get_cells tprocv2r21_standard_i/qick_vec2bit_1]
set_false_path -through [get_pins tprocv2r21_standard_i/qick_processor_0/trig_*_o]

# reset
set_false_path -through [get_pins tprocv2r21_standard_i/rst_dac2/peripheral_aresetn[0]]
set_false_path -through [get_pins tprocv2r21_standard_i/rst_dac0/peripheral_aresetn[0]]

## PMOD outputs
#set_false_path -to [get_ports PMOD0_*]
## PMOD inputs
#set_false_path -from [get_ports PMOD1_*]
## DDR4 reset output
#set_false_path -to [get_ports ddr4_sdram_c0_reset_n]

## GREEN LED
#######################################
set_property PACKAGE_PIN AK24       [get_ports "o_xcom_id_0[0]"] ;# Bank 87 RGB_G_LED_0
set_property PACKAGE_PIN AJ23       [get_ports "o_xcom_id_0[1]"] ;# Bank 87 RGB_G_LED_1
set_property PACKAGE_PIN AJ24       [get_ports "o_xcom_id_0[2]"] ;# Bank 87 RGB_G_LED_2
set_property PACKAGE_PIN AH24       [get_ports "o_xcom_id_0[3]"] ;# Bank 87 RGB_G_LED_3
set_property IOSTANDARD  LVCMOS18  [get_ports "o_xcom_id*"]

## XCOM OUTs
#######################################
set_property PACKAGE_PIN AU23      [get_ports "XCOM_OCLK_clk_p[0]"] ;# Bank 66 - FMCP_HSPC_LA20_P
set_property PACKAGE_PIN AV23      [get_ports "XCOM_OCLK_clk_n[0]"] ;# Bank 66 - FMCP_HSPC_LA20_N
set_property PACKAGE_PIN AL23      [get_ports "XCOM_ODT_clk_p[0]"] ;# Bank 66 - FMCP_HSPC_LA21_P
set_property PACKAGE_PIN AM23      [get_ports "XCOM_ODT_clk_n[0]"] ;# Bank 66 - FMCP_HSPC_LA21_N

#set_property PACKAGE_PIN AM26      [get_ports "XCOM_CKO1_clk_p[0]"] ;# Bank 66 - FMCP_HSPC_LA24_P 
#set_property PACKAGE_PIN AN26      [get_ports "XCOM_CKO1_clk_n[0]"] ;# Bank 66 - FMCP_HSPC_LA24_N 
#set_property PACKAGE_PIN AN24      [get_ports "XCOM_DTO1_clk_p[0]"] ;# Bank 66 - FMCP_HSPC_LA25_P 
#set_property PACKAGE_PIN AN25      [get_ports "XCOM_DTO1_clk_n[0]"] ;# Bank 66 - FMCP_HSPC_LA25_N 

## XCOM INPUTS
#######################################
set_property PACKAGE_PIN A29       [get_ports "XCOM_ICLK_clk_p[0]"] ;# Bank 67 - FMCP_HSPC_LA02_P
set_property PACKAGE_PIN A30       [get_ports "XCOM_ICLK_clk_n[0]"] ;# Bank 67 - FMCP_HSPC_LA02_N
set_property PACKAGE_PIN B30       [get_ports "XCOM_IDT_clk_p[0]"] ;# Bank 67 - FMCP_HSPC_LA03_P
set_property PACKAGE_PIN B31       [get_ports "XCOM_IDT_clk_n[0]"] ;# Bank 67 - FMCP_HSPC_LA03_N
#set_property PACKAGE_PIN B32       [get_ports "XCOM_CK_clk_p[1]"] ;# Bank 67 - FMCP_HSPC_LA04_P
#set_property PACKAGE_PIN A32       [get_ports "XCOM_CK_clk_n[1]"] ;# Bank 67 - FMCP_HSPC_LA04_N
#set_property PACKAGE_PIN F29       [get_ports "XCOM_DT_clk_p[1]"] ;# Bank 67 - FMCP_HSPC_LA05_P
#set_property PACKAGE_PIN E29       [get_ports "XCOM_DT_clk_n[1]"] ;# Bank 67 - FMCP_HSPC_LA05_N
set_property IOSTANDARD  LVDS [get_ports "XCOM_*"] ;
