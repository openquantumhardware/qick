# Copyright (C) 2025 FNAL
# SPDX-License-Identifier: BSD-3-Clause

## Constraints file for ZCU216 base overlay Vivado project


## PL ddr4
#set_property PACKAGE_PIN AR20			[get_ports "default_sysclk_c0_300mhz_p"]
#set_property IOSTANDARD DIFF_SSTL12		[get_ports "default_sysclk_c0_300mhz_p"]
#create_clock -period 3.333 -name default_sysclk_c0_300mhz	[get_ports "default_sysclk_c0_300mhz_p"]
#set_property PACKAGE_PIN AR19			[get_ports "default_sysclk_c0_300mhz_n"]
#set_property IOSTANDARD DIFF_SSTL12		[get_ports "default_sysclk_c0_300mhz_n"]
#create_clock -period 3.333 -name default_sysclk_c0_300mhz	[get_ports "default_sysclk_c0_300mhz_n"]
#
##PL104 sysref
#set_property PACKAGE_PIN D11       [get_ports "sysref_in_n"] ;# Bank  89 VCCO - VCC1V8   - IO_L8N_HDGC_AD4N_89
#set_property IOSTANDARD  LVDS_25   [get_ports "sysref_in_n"] ;# Bank  89 VCCO - VCC1V8   - IO_L8N_HDGC_AD4N_89
#set_property PACKAGE_PIN E11       [get_ports "sysref_in_p"] ;# Bank  89 VCCO - VCC1V8   - IO_L8P_HDGC_AD4P_89
#set_property IOSTANDARD  LVDS_25   [get_ports "sysref_in_p"] ;# Bank  89 VCCO - VCC1V8   - IO_L8P_HDGC_AD4P_89


#set_property PACKAGE_PIN B13			[get_ports "ddr4_sdram_c0_adr[0]"]
#set_property PACKAGE_PIN G6			[get_ports "ddr4_sdram_c0_adr[1]"]
#set_property PACKAGE_PIN A14			[get_ports "ddr4_sdram_c0_adr[2]"]
#set_property PACKAGE_PIN F10			[get_ports "ddr4_sdram_c0_adr[3]"]
#set_property PACKAGE_PIN D14			[get_ports "ddr4_sdram_c0_adr[4]"]
#set_property PACKAGE_PIN F11			[get_ports "ddr4_sdram_c0_adr[5]"]
#set_property PACKAGE_PIN J7			[get_ports "ddr4_sdram_c0_adr[6]"]
#set_property PACKAGE_PIN H13			[get_ports "ddr4_sdram_c0_adr[7]"]
#set_property PACKAGE_PIN A11			[get_ports "ddr4_sdram_c0_adr[8]"]
#set_property PACKAGE_PIN H6			[get_ports "ddr4_sdram_c0_adr[9]"]
#set_property PACKAGE_PIN C15			[get_ports "ddr4_sdram_c0_adr[10]"]
#set_property PACKAGE_PIN G7			[get_ports "ddr4_sdram_c0_adr[11]"]
#set_property PACKAGE_PIN D13			[get_ports "ddr4_sdram_c0_adr[12]"]
#set_property PACKAGE_PIN H11			[get_ports "ddr4_sdram_c0_adr[13]"]
#set_property PACKAGE_PIN K13			[get_ports "ddr4_sdram_c0_adr[14]"]
#set_property PACKAGE_PIN F14			[get_ports "ddr4_sdram_c0_adr[15]"]
#set_property PACKAGE_PIN E13			[get_ports "ddr4_sdram_c0_adr[16]"]
#set_property IOSTANDARD SSTL12_DCI		[get_ports {ddr4_sdram_c0_adr[?]}]
#
#set_property PACKAGE_PIN B14			[get_ports {ddr4_sdram_c0_act_n}]
#set_property IOSTANDARD SSTL12_DCI		[get_ports {ddr4_sdram_c0_act_n}]
#
#set_property PACKAGE_PIN A12			[get_ports "ddr4_sdram_c0_ba[0]"]
#set_property PACKAGE_PIN H10			[get_ports "ddr4_sdram_c0_ba[1]"]
#set_property IOSTANDARD SSTL12_DCI		[get_ports {ddr4_sdram_c0_ba[?]}]
#set_property PACKAGE_PIN B20 			[get_ports "ddr4_sdram_c0_bg[0]"]
#set_property IOSTANDARD SSTL12_DCI		[get_ports "ddr4_sdram_c0_bg[0]"]
#
#set_property PACKAGE_PIN J10			[get_ports "ddr4_sdram_c0_ck_c[0]"]
#set_property IOSTANDARD DIFF_SSTL12_DCI		[get_ports "ddr4_sdram_c0_ck_c[0]"]
#set_property PACKAGE_PIN J11			[get_ports "ddr4_sdram_c0_ck_t[0]"]
#set_property IOSTANDARD DIFF_SSTL12_DCI		[get_ports "ddr4_sdram_c0_ck_t[0]"]
#
#set_property PACKAGE_PIN A18			[get_ports "ddr4_sdram_c0_cke[0]"]
#set_property IOSTANDARD SSTL12_DCI		[get_ports "ddr4_sdram_c0_cke[0]"]
#
#set_property PACKAGE_PIN E11			[get_ports "ddr4_sdram_c0_cs_n[0]"]
#set_property IOSTANDARD SSTL12_DCI		[get_ports "ddr4_sdram_c0_cs_n[0]"]
#
#set_property PACKAGE_PIN J15			[get_ports "ddr4_sdram_c0_dm_n[0]"]
#set_property PACKAGE_PIN N14			[get_ports "ddr4_sdram_c0_dm_n[1]"]
#set_property PACKAGE_PIN D18			[get_ports "ddr4_sdram_c0_dm_n[2]"]
#set_property PACKAGE_PIN G17			[get_ports "ddr4_sdram_c0_dm_n[3]"]
#set_property PACKAGE_PIN F21			[get_ports "ddr4_sdram_c0_dm_n[4]"]
#set_property PACKAGE_PIN J23			[get_ports "ddr4_sdram_c0_dm_n[5]"]
#set_property PACKAGE_PIN C23			[get_ports "ddr4_sdram_c0_dm_n[6]"]
#set_property PACKAGE_PIN N20			[get_ports "ddr4_sdram_c0_dm_n[7]"]
#set_property IOSTANDARD POD12_DCI		[get_ports {ddr4_sdram_c0_dm_n[?]}]
#
#set_property PACKAGE_PIN K17			[get_ports "ddr4_sdram_c0_dq[0]"]
#set_property PACKAGE_PIN J16			[get_ports "ddr4_sdram_c0_dq[1]"]
#set_property PACKAGE_PIN H17			[get_ports "ddr4_sdram_c0_dq[2]"]
#set_property PACKAGE_PIN H16			[get_ports "ddr4_sdram_c0_dq[3]"]
#set_property PACKAGE_PIN J18			[get_ports "ddr4_sdram_c0_dq[4]"]
#set_property PACKAGE_PIN K16			[get_ports "ddr4_sdram_c0_dq[5]"]
#set_property PACKAGE_PIN J19			[get_ports "ddr4_sdram_c0_dq[6]"]
#set_property PACKAGE_PIN L17			[get_ports "ddr4_sdram_c0_dq[7]"]
#
#set_property PACKAGE_PIN N17			[get_ports "ddr4_sdram_c0_dq[8]"]
#set_property PACKAGE_PIN N13			[get_ports "ddr4_sdram_c0_dq[9]"]
#set_property PACKAGE_PIN N15			[get_ports "ddr4_sdram_c0_dq[10]"]
#set_property PACKAGE_PIN L12			[get_ports "ddr4_sdram_c0_dq[11]"]
#set_property PACKAGE_PIN M17			[get_ports "ddr4_sdram_c0_dq[12]"]
#set_property PACKAGE_PIN M13			[get_ports "ddr4_sdram_c0_dq[13]"]
#set_property PACKAGE_PIN M15			[get_ports "ddr4_sdram_c0_dq[14]"]
#set_property PACKAGE_PIN M12			[get_ports "ddr4_sdram_c0_dq[15]"]
#
#set_property PACKAGE_PIN D16			[get_ports "ddr4_sdram_c0_dq[16]"]
#set_property PACKAGE_PIN A17			[get_ports "ddr4_sdram_c0_dq[17]"]
#set_property PACKAGE_PIN C17			[get_ports "ddr4_sdram_c0_dq[18]"]
#set_property PACKAGE_PIN A19			[get_ports "ddr4_sdram_c0_dq[19]"]
#set_property PACKAGE_PIN D15			[get_ports "ddr4_sdram_c0_dq[20]"]
#set_property PACKAGE_PIN C16			[get_ports "ddr4_sdram_c0_dq[21]"]
#set_property PACKAGE_PIN B19			[get_ports "ddr4_sdram_c0_dq[22]"]
#set_property PACKAGE_PIN A16			[get_ports "ddr4_sdram_c0_dq[23]"]
#
#set_property PACKAGE_PIN G18			[get_ports "ddr4_sdram_c0_dq[24]"]
#set_property PACKAGE_PIN E16			[get_ports "ddr4_sdram_c0_dq[25]"]
#set_property PACKAGE_PIN F16			[get_ports "ddr4_sdram_c0_dq[26]"]
#set_property PACKAGE_PIN G15			[get_ports "ddr4_sdram_c0_dq[27]"]
#set_property PACKAGE_PIN H18			[get_ports "ddr4_sdram_c0_dq[28]"]
#set_property PACKAGE_PIN E17			[get_ports "ddr4_sdram_c0_dq[29]"]
#set_property PACKAGE_PIN E18			[get_ports "ddr4_sdram_c0_dq[30]"]
#set_property PACKAGE_PIN F15			[get_ports "ddr4_sdram_c0_dq[31]"]
#
#set_property PACKAGE_PIN E24			[get_ports "ddr4_sdram_c0_dq[32]"]
#set_property PACKAGE_PIN D21			[get_ports "ddr4_sdram_c0_dq[33]"]
#set_property PACKAGE_PIN E22			[get_ports "ddr4_sdram_c0_dq[34]"]
#set_property PACKAGE_PIN E21			[get_ports "ddr4_sdram_c0_dq[35]"]
#set_property PACKAGE_PIN E23			[get_ports "ddr4_sdram_c0_dq[36]"]
#set_property PACKAGE_PIN F20			[get_ports "ddr4_sdram_c0_dq[37]"]
#set_property PACKAGE_PIN F24			[get_ports "ddr4_sdram_c0_dq[38]"]
#set_property PACKAGE_PIN G20			[get_ports "ddr4_sdram_c0_dq[39]"]
#
#set_property PACKAGE_PIN J21			[get_ports "ddr4_sdram_c0_dq[40]"]
#set_property PACKAGE_PIN G22			[get_ports "ddr4_sdram_c0_dq[41]"]
#set_property PACKAGE_PIN K24			[get_ports "ddr4_sdram_c0_dq[42]"]
#set_property PACKAGE_PIN G23			[get_ports "ddr4_sdram_c0_dq[43]"]
#set_property PACKAGE_PIN L24			[get_ports "ddr4_sdram_c0_dq[44]"]
#set_property PACKAGE_PIN H22			[get_ports "ddr4_sdram_c0_dq[45]"]
#set_property PACKAGE_PIN H23			[get_ports "ddr4_sdram_c0_dq[46]"]
#set_property PACKAGE_PIN H21			[get_ports "ddr4_sdram_c0_dq[47]"]
#
#set_property PACKAGE_PIN C21			[get_ports "ddr4_sdram_c0_dq[48]"]
#set_property PACKAGE_PIN A24			[get_ports "ddr4_sdram_c0_dq[49]"]
#set_property PACKAGE_PIN B24			[get_ports "ddr4_sdram_c0_dq[50]"]
#set_property PACKAGE_PIN A20			[get_ports "ddr4_sdram_c0_dq[51]"]
#set_property PACKAGE_PIN C22			[get_ports "ddr4_sdram_c0_dq[52]"]
#set_property PACKAGE_PIN A21			[get_ports "ddr4_sdram_c0_dq[53]"]
#set_property PACKAGE_PIN C20			[get_ports "ddr4_sdram_c0_dq[54]"]
#set_property PACKAGE_PIN B20			[get_ports "ddr4_sdram_c0_dq[55]"]
#
#set_property PACKAGE_PIN M20			[get_ports "ddr4_sdram_c0_dq[56]"]
#set_property PACKAGE_PIN L20			[get_ports "ddr4_sdram_c0_dq[57]"]
#set_property PACKAGE_PIN L22			[get_ports "ddr4_sdram_c0_dq[58]"]
#set_property PACKAGE_PIN L21			[get_ports "ddr4_sdram_c0_dq[59]"]
#set_property PACKAGE_PIN N19			[get_ports "ddr4_sdram_c0_dq[60]"]
#set_property PACKAGE_PIN M19			[get_ports "ddr4_sdram_c0_dq[61]"]
#set_property PACKAGE_PIN L23			[get_ports "ddr4_sdram_c0_dq[62]"]
#set_property PACKAGE_PIN L19			[get_ports "ddr4_sdram_c0_dq[63]"]
#
#set_property IOSTANDARD POD12_DCI		[get_ports {ddr4_sdram_c0_dq[?]}]
#
#set_property PACKAGE_PIN K18			[get_ports "ddr4_sdram_c0_dqs_c[0]"]
#set_property PACKAGE_PIN L14			[get_ports "ddr4_sdram_c0_dqs_c[1]"]
#set_property PACKAGE_PIN B17			[get_ports "ddr4_sdram_c0_dqs_c[2]"]
#set_property PACKAGE_PIN F19			[get_ports "ddr4_sdram_c0_dqs_c[3]"]
#set_property PACKAGE_PIN D24			[get_ports "ddr4_sdram_c0_dqs_c[4]"]
#set_property PACKAGE_PIN H20			[get_ports "ddr4_sdram_c0_dqs_c[5]"]
#set_property PACKAGE_PIN A22			[get_ports "ddr4_sdram_c0_dqs_c[6]"]
#set_property PACKAGE_PIN K22			[get_ports "ddr4_sdram_c0_dqs_c[7]"]
#
#set_property IOSTANDARD DIFF_POD12_DCI		[get_ports {ddr4_sdram_c0_dqs_c[?]}]
#
#set_property PACKAGE_PIN K19			[get_ports "ddr4_sdram_c0_dqs_t[0]"]
#set_property PACKAGE_PIN L15			[get_ports "ddr4_sdram_c0_dqs_t[1]"]
#set_property PACKAGE_PIN B18			[get_ports "ddr4_sdram_c0_dqs_t[2]"]
#set_property PACKAGE_PIN G19			[get_ports "ddr4_sdram_c0_dqs_t[3]"]
#set_property PACKAGE_PIN D23			[get_ports "ddr4_sdram_c0_dqs_t[4]"]
#set_property PACKAGE_PIN J20			[get_ports "ddr4_sdram_c0_dqs_t[5]"]
#set_property PACKAGE_PIN B22			[get_ports "ddr4_sdram_c0_dqs_t[6]"]
#set_property PACKAGE_PIN K21			[get_ports "ddr4_sdram_c0_dqs_t[7]"]
#
#set_property IOSTANDARD DIFF_POD12_DCI		[get_ports {ddr4_sdram_c0_dqs_t[?]}]
#
#set_property PACKAGE_PIN A15			[get_ports "ddr4_sdram_c0_odt[0]"]
#set_property IOSTANDARD SSTL12_DCI		[get_ports {ddr4_sdram_c0_odt[?]}]
#set_property PACKAGE_PIN B18			[get_ports "ddr4_sdram_c0_reset_n"]
#set_property IOSTANDARD LVCMOS12		[get_ports {ddr4_sdram_c0_reset_n}]

## rgbleds
#set_property PACKAGE_PIN AN14			[get_ports {led_r_8bits[0]}]; 
#set_property PACKAGE_PIN AP16			[get_ports {led_r_8bits[1]}]; 
#set_property PACKAGE_PIN AP14			[get_ports {led_r_8bits[2]}]; 
#set_property PACKAGE_PIN AU16			[get_ports {led_r_8bits[3]}]; 
#set_property PACKAGE_PIN AW12			[get_ports {led_r_8bits[4]}]; 
#set_property PACKAGE_PIN AY16			[get_ports {led_r_8bits[5]}]; 
#set_property PACKAGE_PIN BB12			[get_ports {led_r_8bits[6]}]; 
#set_property PACKAGE_PIN E25			[get_ports {led_r_8bits[7]}]; 
#set_property IOSTANDARD LVCMOS12		[get_ports {led_r_8bits[?]}];
#
#set_property PACKAGE_PIN C13			[get_ports {led_g_8bits[0]}]; 
#set_property IOSTANDARD LVCMOS18		[get_ports {led_g_8bits[0]}];
#set_property PACKAGE_PIN D14			[get_ports {led_g_8bits[1]}]; 
#set_property IOSTANDARD LVCMOS18		[get_ports {led_g_8bits[1]}];
#set_property PACKAGE_PIN D12			[get_ports {led_g_8bits[2]}]; 
#set_property IOSTANDARD LVCMOS18		[get_ports {led_g_8bits[2]}];
#set_property PACKAGE_PIN D13			[get_ports {led_g_8bits[3]}]; 
#set_property IOSTANDARD LVCMOS18		[get_ports {led_g_8bits[3]}];
#set_property PACKAGE_PIN AW18   		[get_ports {led_g_8bits[4]}]; 
#set_property IOSTANDARD LVCMOS12		[get_ports {led_g_8bits[4]}];
#set_property PACKAGE_PIN AV18   		[get_ports {led_g_8bits[5]}]; 
#set_property IOSTANDARD LVCMOS12		[get_ports {led_g_8bits[5]}];
#set_property PACKAGE_PIN BA19   		[get_ports {led_g_8bits[6]}]; 
#set_property IOSTANDARD LVCMOS12		[get_ports {led_g_8bits[6]}];
#set_property PACKAGE_PIN AP21   		[get_ports {led_g_8bits[7]}]; 
#set_property IOSTANDARD LVCMOS12		[get_ports {led_g_8bits[7]}];
#																														 
#set_property PACKAGE_PIN B26			[get_ports {led_b_8bits[0]}]; 
#set_property PACKAGE_PIN E24			[get_ports {led_b_8bits[1]}]; 
#set_property PACKAGE_PIN G26			[get_ports {led_b_8bits[2]}]; 
#set_property PACKAGE_PIN J23			[get_ports {led_b_8bits[3]}]; 
#set_property PACKAGE_PIN L24			[get_ports {led_b_8bits[4]}]; 
#set_property PACKAGE_PIN P21			[get_ports {led_b_8bits[5]}]; 
#set_property PACKAGE_PIN AV21			[get_ports {led_b_8bits[6]}]; 
#set_property PACKAGE_PIN AR21			[get_ports {led_b_8bits[7]}]; 
#set_property IOSTANDARD LVCMOS12		[get_ports {led_b_8bits[?]}];
#
### dip switches
#set_property PACKAGE_PIN AY10			[get_ports {dip_switches_8bits[0]}];
#set_property PACKAGE_PIN AY11			[get_ports {dip_switches_8bits[1]}];
#set_property PACKAGE_PIN BA9 			[get_ports {dip_switches_8bits[2]}];
#set_property PACKAGE_PIN AY9 			[get_ports {dip_switches_8bits[3]}];
#set_property PACKAGE_PIN BB9 			[get_ports {dip_switches_8bits[4]}];
#set_property PACKAGE_PIN BA10			[get_ports {dip_switches_8bits[5]}];
#set_property PACKAGE_PIN BB10			[get_ports {dip_switches_8bits[6]}];
#set_property PACKAGE_PIN BB11			[get_ports {dip_switches_8bits[7]}];
#set_property IOSTANDARD LVCMOS18		[get_ports {dip_switches_8bits[?]}];
#
## push_buttons_5bits
#set_property PACKAGE_PIN H10			[get_ports {push_buttons_5bits[0]}]; # S
#set_property PACKAGE_PIN J11			[get_ports {push_buttons_5bits[1]}]; # N
#set_property PACKAGE_PIN J12			[get_ports {push_buttons_5bits[2]}]; # E
#set_property PACKAGE_PIN K11			[get_ports {push_buttons_5bits[3]}]; # C
#set_property PACKAGE_PIN K12			[get_ports {push_buttons_5bits[4]}]; # W
#set_property IOSTANDARD LVCMOS18		[get_ports {push_buttons_5bits[?]}];
#
### pmod0, pmod1
#set_property PACKAGE_PIN G15			[get_ports {pmod0[0]}]
#set_property PACKAGE_PIN G16			[get_ports {pmod0[1]}]
#set_property PACKAGE_PIN H14			[get_ports {pmod0[2]}]
#set_property PACKAGE_PIN H15			[get_ports {pmod0[3]}]
#set_property PACKAGE_PIN G13			[get_ports {pmod0[4]}]
#set_property PACKAGE_PIN H13			[get_ports {pmod0[5]}]
#set_property PACKAGE_PIN J13			[get_ports {pmod0[6]}]
#set_property PACKAGE_PIN J14			[get_ports {pmod0[7]}]
#set_property IOSTANDARD LVCMOS18		[get_ports {pmod0[?]}]
#set_property PULLUP true			    [get_ports {pmod0[2]}]
#set_property PULLUP true			    [get_ports {pmod0[3]}]
#set_property PULLUP true			    [get_ports {pmod0[6]}]
#set_property PULLUP true			    [get_ports {pmod0[7]}]
#
#set_property PACKAGE_PIN L17			[get_ports {pmod1[0]}]
#set_property PACKAGE_PIN M17			[get_ports {pmod1[1]}]
#set_property PACKAGE_PIN M14			[get_ports {pmod1[2]}]
#set_property PACKAGE_PIN N14			[get_ports {pmod1[3]}]
#set_property PACKAGE_PIN M15			[get_ports {pmod1[4]}]
#set_property PACKAGE_PIN N15			[get_ports {pmod1[5]}]
#set_property PACKAGE_PIN M16			[get_ports {pmod1[6]}]
#set_property PACKAGE_PIN N16			[get_ports {pmod1[7]}]
#set_property IOSTANDARD LVCMOS18		[get_ports {pmod1[?]}]
#set_property PULLUP true			    [get_ports {pmod1[2]}]
#set_property PULLUP true			    [get_ports {pmod1[3]}]
#set_property PULLUP true			    [get_ports {pmod1[6]}]
#set_property PULLUP true			    [get_ports {pmod1[7]}]
#
#
#
#
#set_property BITSTREAM.GENERAL.COMPRESS TRUE [get_designs impl_1]
#set_property BITSTREAM.CONFIG.OVERTEMPSHUTDOWN ENABLE [get_designs impl_1]
