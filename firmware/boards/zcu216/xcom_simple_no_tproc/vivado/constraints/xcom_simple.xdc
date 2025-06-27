#######################################
## QICK DESIGN 216

# clk_axi  = 100 Mhz
# c_clk    = 200 Mhz 
# t_clk    = 250 Mhz 


## Generated Clocks
set clk_axi  [get_clocks -of_objects [get_nets -of_objects [get_pins xcom_simple_i/zynq_ultra_ps_e_0/pl_clk0] ] ]
set c_clk    [get_clocks -of_objects [get_nets -of_objects [get_pins xcom_simple_i/qick_processor_0/c_clk_i]  ] ]
set t_clk    [get_clocks -of_objects [get_nets -of_objects [get_pins xcom_simple_i/qick_processor_0/t_clk_i]  ] ]

set_clock_groups -name async_clks -asynchronous \
-group [get_clocks [get_clocks $clk_axi ]] \
-group [get_clocks [get_clocks $c_clk   ]] \
-group [get_clocks [get_clocks $t_clk   ]] 

## PMOD_0
set_property PACKAGE_PIN G15       [get_ports "PMOD0_0"] ;# Bank 88 PMOD0_0
set_property PACKAGE_PIN G16       [get_ports "PMOD0_1"] ;# Bank 88 PMOD0_1
#set_property PACKAGE_PIN H14       [get_ports "PMOD0_2"] ;# Bank 88 PMOD0_2
#set_property PACKAGE_PIN H15       [get_ports "PMOD0_3"] ;# Bank 88 PMOD0_3
#set_property PACKAGE_PIN G13       [get_ports "PMOD0_4"] ;# Bank 88 PMOD0_4
#set_property PACKAGE_PIN H13       [get_ports "PMOD0_5"] ;# Bank 88 PMOD0_5
#set_property PACKAGE_PIN J13       [get_ports "PMOD0_6"] ;# Bank 88 PMOD0_6
#set_property PACKAGE_PIN J14       [get_ports "PMOD0_7"] ;# Bank 88 PMOD0_7
set_property IOSTANDARD LVCMOS18   [get_ports "PMOD0*"]

## GREEN LED
#######################################
#set_property PACKAGE_PIN C13       [get_ports "xcom_id_o_0[0]"] ;# Bank 87 RGB_G_LED_0
#set_property PACKAGE_PIN D14       [get_ports "xcom_id_o_0[1]"] ;# Bank 87 RGB_G_LED_1
#set_property PACKAGE_PIN D12       [get_ports "xcom_id_o_0[2]"] ;# Bank 87 RGB_G_LED_2
#set_property PACKAGE_PIN D13       [get_ports "xcom_id_o_0[3]"] ;# Bank 87 RGB_G_LED_3
#set_property IOSTANDARD  LVCMOS18  [get_ports "xcom_id_o*"]
set_property PACKAGE_PIN AK24       [get_ports "xcom_id_o_0[0]"] ;# Bank 87 RGB_G_LED_0
set_property PACKAGE_PIN AJ23       [get_ports "xcom_id_o_0[1]"] ;# Bank 87 RGB_G_LED_1
set_property PACKAGE_PIN AJ24       [get_ports "xcom_id_o_0[2]"] ;# Bank 87 RGB_G_LED_2
set_property PACKAGE_PIN AH24       [get_ports "xcom_id_o_0[3]"] ;# Bank 87 RGB_G_LED_3
set_property IOSTANDARD  LVCMOS18  [get_ports "xcom_id_o*"]

## XCOM OUTs
#######################################
set_property PACKAGE_PIN AU23      [get_ports "XCOM_CKO_clk_p[0]"] ;# Bank 66 - FMCP_HSPC_LA20_P
set_property PACKAGE_PIN AV23      [get_ports "XCOM_CKO_clk_n[0]"] ;# Bank 66 - FMCP_HSPC_LA20_N
set_property PACKAGE_PIN AL23      [get_ports "XCOM_DTO_clk_p[0]"] ;# Bank 66 - FMCP_HSPC_LA21_P
set_property PACKAGE_PIN AM23      [get_ports "XCOM_DTO_clk_n[0]"] ;# Bank 66 - FMCP_HSPC_LA21_N

set_property PACKAGE_PIN AM26      [get_ports "XCOM_CKO1_clk_p[0]"] ;# Bank 66 - FMCP_HSPC_LA24_P 
set_property PACKAGE_PIN AN26      [get_ports "XCOM_CKO1_clk_n[0]"] ;# Bank 66 - FMCP_HSPC_LA24_N 
set_property PACKAGE_PIN AN24      [get_ports "XCOM_DTO1_clk_p[0]"] ;# Bank 66 - FMCP_HSPC_LA25_P 
set_property PACKAGE_PIN AN25      [get_ports "XCOM_DTO1_clk_n[0]"] ;# Bank 66 - FMCP_HSPC_LA25_N 

## XCOM INPUTS
#######################################
set_property PACKAGE_PIN A29       [get_ports "XCOM_CK_clk_p[0]"] ;# Bank 67 - FMCP_HSPC_LA02_P
set_property PACKAGE_PIN A30       [get_ports "XCOM_CK_clk_n[0]"] ;# Bank 67 - FMCP_HSPC_LA02_N
set_property PACKAGE_PIN B30       [get_ports "XCOM_DT_clk_p[0]"] ;# Bank 67 - FMCP_HSPC_LA03_P
set_property PACKAGE_PIN B31       [get_ports "XCOM_DT_clk_n[0]"] ;# Bank 67 - FMCP_HSPC_LA03_N
set_property PACKAGE_PIN B32       [get_ports "XCOM_CK_clk_p[1]"] ;# Bank 67 - FMCP_HSPC_LA04_P
set_property PACKAGE_PIN A32       [get_ports "XCOM_CK_clk_n[1]"] ;# Bank 67 - FMCP_HSPC_LA04_N
set_property PACKAGE_PIN F29       [get_ports "XCOM_DT_clk_p[1]"] ;# Bank 67 - FMCP_HSPC_LA05_P
set_property PACKAGE_PIN E29       [get_ports "XCOM_DT_clk_n[1]"] ;# Bank 67 - FMCP_HSPC_LA05_N
set_property IOSTANDARD  LVDS [get_ports "XCOM_*"] ;


#######################################
set_property BITSTREAM.CONFIG.UNUSEDPIN PULLUP [current_design]
set_property BITSTREAM.CONFIG.OVERTEMPSHUTDOWN ENABLE [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]


