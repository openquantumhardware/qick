set_property PACKAGE_PIN C17      	[get_ports "PMOD0_0_LS"];
set_property IOSTANDARD  LVCMOS12  	[get_ports "PMOD0_0_LS"];
set_property PACKAGE_PIN M18      	[get_ports "PMOD0_1_LS"];
set_property IOSTANDARD  LVCMOS12 	[get_ports "PMOD0_1_LS"];
set_property PACKAGE_PIN H16      	[get_ports "PMOD0_2_LS"];
set_property IOSTANDARD  LVCMOS12 	[get_ports "PMOD0_2_LS"];
set_property PACKAGE_PIN H17      	[get_ports "PMOD0_3_LS"];
set_property IOSTANDARD  LVCMOS12 	[get_ports "PMOD0_3_LS"];
set_property PACKAGE_PIN J16      	[get_ports "PMOD0_4_LS"];
set_property IOSTANDARD  LVCMOS12 	[get_ports "PMOD0_4_LS"];
set_property PACKAGE_PIN K16      	[get_ports "PMOD0_5_LS"];
set_property IOSTANDARD  LVCMOS12 	[get_ports "PMOD0_5_LS"];
set_property PACKAGE_PIN H15      	[get_ports "PMOD0_6_LS"];
set_property IOSTANDARD  LVCMOS12 	[get_ports "PMOD0_6_LS"];
set_property PACKAGE_PIN J15      	[get_ports "PMOD0_7_LS"];
set_property IOSTANDARD  LVCMOS12 	[get_ports "PMOD0_7_LS"];

set_property PACKAGE_PIN L14      	[get_ports "PMOD1_0_LS"];
set_property IOSTANDARD  LVCMOS12 	[get_ports "PMOD1_0_LS"];
#set_property PACKAGE_PIN L15      	[get_ports "PMOD1_1_LS"];
#set_property IOSTANDARD  LVCMOS12 	[get_ports "PMOD1_1_LS"];
#set_property PACKAGE_PIN M13      	[get_ports "PMOD1_2_LS"];
#set_property IOSTANDARD  LVCMOS12 	[get_ports "PMOD1_2_LS"];
#set_property PACKAGE_PIN N13      	[get_ports "PMOD1_3_LS"];
#set_property IOSTANDARD  LVCMOS12 	[get_ports "PMOD1_3_LS"];
#set_property PACKAGE_PIN M15      	[get_ports "PMOD1_4_LS"];
#set_property IOSTANDARD  LVCMOS12 	[get_ports "PMOD1_4_LS"];
#set_property PACKAGE_PIN N15      	[get_ports "PMOD1_5_LS"];
#set_property IOSTANDARD  LVCMOS12 	[get_ports "PMOD1_5_LS"];
#set_property PACKAGE_PIN M14      	[get_ports "PMOD1_6_LS"];
#set_property IOSTANDARD  LVCMOS12 	[get_ports "PMOD1_6_LS"];
#set_property PACKAGE_PIN N14      	[get_ports "PMOD1_7_LS"];
#set_property IOSTANDARD  LVCMOS12 	[get_ports "PMOD1_7_LS"];

# ATTN_SPI
set_property PACKAGE_PIN A9       [get_ports "ATTN_CLK"] ;   # Bank  87 VCCO - VCC1V8 - DACIO_00 - IO_L12N_AD8N_87
set_property IOSTANDARD  LVCMOS18 [get_ports "ATTN_CLK"] ;   # Bank  87 VCCO - VCC1V8 - DACIO_00 - IO_L12N_AD8N_87
set_property PACKAGE_PIN A10      [get_ports "ATTN_SI"] ;    # Bank  87 VCCO - VCC1V8 - DACIO_01 - IO_L12P_AD8P_87
set_property IOSTANDARD  LVCMOS18 [get_ports "ATTN_SI"] ;    # Bank  87 VCCO - VCC1V8 - DACIO_01 - IO_L12P_AD8P_87
set_property PACKAGE_PIN A6       [get_ports "ATTN_LE[0]"] ; # Bank  87 VCCO - VCC1V8 - DACIO_02 - IO_L11N_AD9N_87
set_property IOSTANDARD  LVCMOS18 [get_ports "ATTN_LE[0]"] ; # Bank  87 VCCO - VCC1V8 - DACIO_02 - IO_L11N_AD9N_87
set_property PACKAGE_PIN A7       [get_ports "ATTN_LE[1]"] ; # Bank  87 VCCO - VCC1V8 - DACIO_03 - IO_L11P_AD9P_87
set_property IOSTANDARD  LVCMOS18 [get_ports "ATTN_LE[1]"] ; # Bank  87 VCCO - VCC1V8 - DACIO_03 - IO_L11P_AD9P_87
set_property PACKAGE_PIN A5       [get_ports "ATTN_LE[2]"] ; # Bank  87 VCCO - VCC1V8 - DACIO_04 - IO_L10N_AD10N_87
set_property IOSTANDARD  LVCMOS18 [get_ports "ATTN_LE[2]"] ; # Bank  87 VCCO - VCC1V8 - DACIO_04 - IO_L10N_AD10N_87

# PSF_SPI
set_property PACKAGE_PIN B5       [get_ports "SCLK"] ;       # Bank  87 VCCO - VCC1V8 - DACIO_05 - IO_L10P_AD10P_87
set_property IOSTANDARD  LVCMOS18 [get_ports "SCLK"] ;       # Bank  87 VCCO - VCC1V8 - DACIO_05 - IO_L10P_AD10P_87
set_property PACKAGE_PIN C6       [get_ports "SDI"] ;        # Bank  87 VCCO - VCC1V8 - DACIO_07 - IO_L9P_AD11P_87
set_property IOSTANDARD  LVCMOS18 [get_ports "SDI"] ;        # Bank  87 VCCO - VCC1V8 - DACIO_07 - IO_L9P_AD11P_87
set_property PACKAGE_PIN B9       [get_ports "SDO"] ;        # Bank  87 VCCO - VCC1V8 - DACIO_08 - IO_L8N_HDGC_87
set_property IOSTANDARD  LVCMOS18 [get_ports "SDO"] ;        # Bank  87 VCCO - VCC1V8 - DACIO_08 - IO_L8N_HDGC_87
set_property PACKAGE_PIN D10      [get_ports "S[0]"] ;       # Bank  87 VCCO - VCC1V8 - DACIO_17 - IO_L4P_AD12P_87
set_property IOSTANDARD  LVCMOS18 [get_ports "S[0]"] ;       # Bank  87 VCCO - VCC1V8 - DACIO_17 - IO_L4P_AD12P_87
set_property PACKAGE_PIN D6       [get_ports "S[1]"] ;       # Bank  87 VCCO - VCC1V8 - DACIO_18 - IO_L3N_AD13N_87
set_property IOSTANDARD  LVCMOS18 [get_ports "S[1]"] ;       # Bank  87 VCCO - VCC1V8 - DACIO_18 - IO_L3N_AD13N_87
set_property PACKAGE_PIN E7       [get_ports "S[2]"] ;       # Bank  87 VCCO - VCC1V8 - DACIO_19- IO_L3P_AD13P_87
set_property IOSTANDARD  LVCMOS18 [get_ports "S[2]"] ;       # Bank  87 VCCO - VCC1V8 - DACIO_19 - IO_L3P_AD13P_87
set_property PACKAGE_PIN C5       [get_ports "S[3]"] ;       # Bank  87 VCCO - VCC1V8 - DACIO_06 - IO_L9N_AD11N_87
set_property IOSTANDARD  LVCMOS18 [get_ports "S[3]"] ;       # Bank  87 VCCO - VCC1V8 - DACIO_06 - IO_L9N_AD11N_87

# LO_SPI
set_property PACKAGE_PIN B7       [get_ports "LO_SCLK"] ;    # Bank  87 VCCO - VCC1V8 - DACIO_10 - IO_L7N_HDGC_87
set_property IOSTANDARD  LVCMOS18 [get_ports "LO_SCLK"] ;    # Bank  87 VCCO - VCC1V8 - DACIO_10 - IO_L7N_HDGC_87
set_property PACKAGE_PIN D9       [get_ports "LO_MISO0"] ;   # Bank  87 VCCO - VCC1V8 - DACIO_13 - IO_L6P_HDGC_87
set_property IOSTANDARD  LVCMOS18 [get_ports "LO_MISO0"] ;   # Bank  87 VCCO - VCC1V8 - DACIO_13 - IO_L6P_HDGC_87
set_property PACKAGE_PIN C7       [get_ports "LO_MISO1"] ;   # Bank  87 VCCO - VCC1V8 - DACIO_14 - IO_L5N_HDGC_87
set_property IOSTANDARD  LVCMOS18 [get_ports "LO_MISO1"] ;   # Bank  87 VCCO - VCC1V8 - DACIO_14 - IO_L5N_HDGC_87
set_property PACKAGE_PIN AV7      [get_ports "LO_MISO2"] ;   # Bank  84 VCCO - VCC1V8 - ADCIO_04 - IO_L10N_AD2N_84
set_property IOSTANDARD  LVCMOS18 [get_ports "LO_MISO2"] ;   # Bank  84 VCCO - VCC1V8 - ADCIO_04 - IO_L10N_AD2N_84
set_property PACKAGE_PIN D8       [get_ports "LO_MOSI"] ;    # Bank  87 VCCO - VCC1V8 - DACIO_12 - IO_L6N_HDGC_87
set_property IOSTANDARD  LVCMOS18 [get_ports "LO_MOSI"] ;    # Bank  87 VCCO - VCC1V8 - DACIO_12 - IO_L6N_HDGC_87
set_property PACKAGE_PIN B8       [get_ports "LO_CS0"] ;     # Bank  87 VCCO - VCC1V8 - DACIO_11 - IO_L7P_HDGC_87
set_property IOSTANDARD  LVCMOS18 [get_ports "LO_CS0"] ;     # Bank  87 VCCO - VCC1V8 - DACIO_11 - IO_L7P_HDGC_87
set_property PACKAGE_PIN C8       [get_ports "LO_CS1"] ;     # Bank  87 VCCO - VCC1V8 - DACIO_15 - IO_L5P_HDGC_87
set_property IOSTANDARD  LVCMOS18 [get_ports "LO_CS1"] ;     # Bank  87 VCCO - VCC1V8 - DACIO_15 - IO_L5P_HDGC_87
set_property PACKAGE_PIN AV3      [get_ports "LO_CS2"] ;     # Bank  84 VCCO - VCC1V8 - ADCIO_19 - IO_L3P_AD9P_84
set_property IOSTANDARD  LVCMOS18 [get_ports "LO_CS2"] ;     # Bank  84 VCCO - VCC1V8 - ADCIO_19 - IO_L3P_AD9P_84
set_property PACKAGE_PIN AU7      [get_ports "LO_SYNC"] ;    # Bank  84 VCCO - VCC1V8 - ADCIO_05 - IO_L10P_AD2P_84
set_property IOSTANDARD  LVCMOS18 [get_ports "LO_SYNC"] ;    # Bank  84 VCCO - VCC1V8 - ADCIO_05 - IO_L10P_AD2P_84

# BIAS_SPI
set_property PACKAGE_PIN AU2      [get_ports "BIAS_SCLK"] ;  # Bank  84 VCCO - VCC1V8 - ADCIO_17 - IO_L4P_AD8P_84
set_property IOSTANDARD  LVCMOS18 [get_ports "BIAS_SCLK"] ;  # Bank  84 VCCO - VCC1V8 - ADCIO_17 - IO_L4P_AD8P_84
set_property PACKAGE_PIN AU8      [get_ports "BIAS_SDI"] ;   # Bank  84 VCCO - VCC1V8 - ADCIO_07 - IO_L9P_AD3P_84
set_property IOSTANDARD  LVCMOS18 [get_ports "BIAS_SDI"] ;   # Bank  84 VCCO - VCC1V8 - ADCIO_07 - IO_L9P_AD3P_84
set_property PACKAGE_PIN AP5      [get_ports "BIAS_SDO"] ;   # Bank  84 VCCO - VCC1V8 - ADCIO_00 - IO_L12N_AD0N_84
set_property IOSTANDARD  LVCMOS18 [get_ports "BIAS_SDO"] ;   # Bank  84 VCCO - VCC1V8 - ADCIO_00 - IO_L12N_AD0N_84
set_property PACKAGE_PIN AU5      [get_ports "BIAS_S[0]"] ;  # Bank  84 VCCO - VCC1V8 - ADCIO_10 - IO_L7N_HDGC_AD5N_84
set_property IOSTANDARD  LVCMOS18 [get_ports "BIAS_S[0]"] ;  # Bank  84 VCCO - VCC1V8 - ADCIO_10 - IO_L7N_HDGC_AD5N_84
set_property PACKAGE_PIN AU3      [get_ports "BIAS_S[1]"] ;  # Bank  84 VCCO - VCC1V8 - ADCIO_12 - IO_L6N_HDGC_AD6N_84
set_property IOSTANDARD  LVCMOS18 [get_ports "BIAS_S[1]"] ;  # Bank  84 VCCO - VCC1V8 - ADCIO_12 - IO_L6N_HDGC_AD6N_84
set_property PACKAGE_PIN AV2      [get_ports "BIAS_S[2]"] ;  # Bank  84 VCCO - VCC1V8 - ADCIO_18 - IO_L3N_AD9N_84
set_property IOSTANDARD  LVCMOS18 [get_ports "BIAS_S[2]"] ;  # Bank  84 VCCO - VCC1V8 - ADCIO_18 - IO_L3N_AD9N_84
set_property PACKAGE_PIN AV6      [get_ports "BIAS_S[3]"] ;  # Bank  84 VCCO - VCC1V8 - ADCIO_15 - IO_L5P_HDGC_AD7P_84
set_property IOSTANDARD  LVCMOS18 [get_ports "BIAS_S[3]"] ;  # Bank  84 VCCO - VCC1V8 - ADCIO_15 - IO_L5P_HDGC_AD7P_84
set_property PACKAGE_PIN AR6      [get_ports "BIAS_CLR"] ;   # Bank  84 VCCO - VCC1V8 - ADCIO_02 - IO_L11N_AD1N_84
set_property IOSTANDARD  LVCMOS18 [get_ports "BIAS_CLR"] ;   # Bank  84 VCCO - VCC1V8 - ADCIO_02 - IO_L11N_AD1N_84

# PWR_SYNC
set_property PACKAGE_PIN C10      [get_ports "PWR_SYNC[0]"] ;# Bank  87 VCCO - VCC1V8 - DACIO_16 - IO_L4N_AD12N_87
set_property IOSTANDARD  LVCMOS18 [get_ports "PWR_SYNC[0]"] ;# Bank  87 VCCO - VCC1V8 - DACIO_16 - IO_L4N_AD12N_87

# SPARE IO
#set_property PACKAGE_PIN B10      [get_ports "SPARE0"] ;     # Bank  87 VCCO - VCC1V8 - DACIO_09 - IO_L8P_HDGC_87
#set_property IOSTANDARD  LVCMOS18 [get_ports "SPARE0"] ;     # Bank  87 VCCO - VCC1V8 - DACIO_09 - IO_L8P_HDGC_87
#set_property PACKAGE_PIN AT6      [get_ports "SPARE1"] ;    # Bank  84 VCCO - VCC1V8 - ADCIO_08 - IO_L8N_HDGC_AD4N_84
#set_property IOSTANDARD  LVCMOS18 [get_ports "SPARE1"] ;    # Bank  84 VCCO - VCC1V8 - ADCIO_08 - IO_L8N_HDGC_AD4N_84

#
# RF Output Switches
#set_property PACKAGE_PIN AP6      [get_ports "OSW_CTL_CH[0]"] ;# Bank  84 VCCO - VCC1V8 - ADCIO_01 - IO_L12P_AD0P_84
#set_property IOSTANDARD  LVCMOS18 [get_ports "OSW_CTL_CH[0]"] ;# Bank  84 VCCO - VCC1V8 - ADCIO_01 - IO_L12P_AD0P_84
#set_property PACKAGE_PIN AR7      [get_ports "OSW_CTL_CH[1]"] ;# Bank  84 VCCO - VCC1V8 - ADCIO_03 - IO_L11P_AD1P_84
#set_property IOSTANDARD  LVCMOS18 [get_ports "OSW_CTL_CH[1]"] ;# Bank  84 VCCO - VCC1V8 - ADCIO_03 - IO_L11P_AD1P_84
#set_property PACKAGE_PIN AV8      [get_ports "OSW_CTL_CH[2]"] ;# Bank  84 VCCO - VCC1V8 - ADCIO_06 - IO_L9N_AD3N_84
#set_property IOSTANDARD  LVCMOS18 [get_ports "OSW_CTL_CH[2]"] ;# Bank  84 VCCO - VCC1V8 - ADCIO_06 - IO_L9N_AD3N_84
#set_property PACKAGE_PIN AT7      [get_ports "OSW_CTL_CH[3]"] ;# Bank  84 VCCO - VCC1V8 - ADCIO_09 - IO_L8P_HDGC_AD4P_84
#set_property IOSTANDARD  LVCMOS18 [get_ports "OSW_CTL_CH[3]"] ;# Bank  84 VCCO - VCC1V8 - ADCIO_09 - IO_L8P_HDGC_AD4P_84
#set_property PACKAGE_PIN AT5      [get_ports "OSW_CTL_CH[4]"] ;# Bank  84 VCCO - VCC1V8 - ADCIO_11 - IO_L7P_HDGC_AD5P_84
#set_property IOSTANDARD  LVCMOS18 [get_ports "OSW_CTL_CH[4]"] ;# Bank  84 VCCO - VCC1V8 - ADCIO_11 - IO_L7P_HDGC_AD5P_84
#set_property PACKAGE_PIN AU4      [get_ports "OSW_CTL_CH[5]"] ;# Bank  84 VCCO - VCC1V8 - ADCIO_13 - IO_L6P_HDGC_AD6P_84
#set_property IOSTANDARD  LVCMOS18 [get_ports "OSW_CTL_CH[5]"] ;# Bank  84 VCCO - VCC1V8 - ADCIO_13 - IO_L6P_HDGC_AD6P_84
#set_property PACKAGE_PIN AV5      [get_ports "OSW_CTL_CH[6]"] ;# Bank  84 VCCO - VCC1V8 - ADCIO_14 - IO_L5N_HDGC_AD7N_84
#set_property IOSTANDARD  LVCMOS18 [get_ports "OSW_CTL_CH[6]"] ;# Bank  84 VCCO - VCC1V8 - ADCIO_14 - IO_L5N_HDGC_AD7N_84
#set_property PACKAGE_PIN AU1      [get_ports "OSW_CTL_CH[7]"] ;# Bank  84 VCCO - VCC1V8 - ADCIO_16 - IO_L4N_AD8N_84
#set_property IOSTANDARD  LVCMOS18 [get_ports "OSW_CTL_CH[7]"] ;# Bank  84 VCCO - VCC1V8 - ADCIO_16 - IO_L4N_AD8N_84
