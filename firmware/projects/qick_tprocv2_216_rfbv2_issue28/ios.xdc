#######################
### Board Selection ###
#######################
set_property PACKAGE_PIN AW9       [get_ports "DB_1V8_BRD_SEL_SEL0"] ;# G47 ADCIO_12 Bank  84 VCCO - VCC1V8   - IO_L6N_HDGC_AD6N_84
set_property IOSTANDARD  LVCMOS18  [get_ports "DB_1V8_BRD_SEL_SEL0"] ;# G47 ADCIO_12 Bank  84 VCCO - VCC1V8   - IO_L6N_HDGC_AD6N_84
set_property PACKAGE_PIN AV9       [get_ports "DB_1V8_BRD_SEL_SEL1"] ;# G49 ADCIO_13 Bank  84 VCCO - VCC1V8   - IO_L6P_HDGC_AD6P_84
set_property IOSTANDARD  LVCMOS18  [get_ports "DB_1V8_BRD_SEL_SEL1"] ;# G49 ADCIO_13 Bank  84 VCCO - VCC1V8   - IO_L6P_HDGC_AD6P_84
set_property PACKAGE_PIN AW11      [get_ports "DB_1V8_BRD_SEL_SEL2"] ;# H46 ADCIO_14 Bank  84 VCCO - VCC1V8   - IO_L5N_HDGC_AD7N_84
set_property IOSTANDARD  LVCMOS18  [get_ports "DB_1V8_BRD_SEL_SEL2"] ;# H46 ADCIO_14 Bank  84 VCCO - VCC1V8   - IO_L5N_HDGC_AD7N_84
set_property PACKAGE_PIN AU10      [get_ports "DB_1V8_BRD_SEL"]		;# F48 ADCIO_11 Bank  84 VCCO - VCC1V8   - IO_L7P_HDGC_AD5P_84
set_property IOSTANDARD  LVCMOS18  [get_ports "DB_1V8_BRD_SEL"]		;# F48 ADCIO_11 Bank  84 VCCO - VCC1V8   - IO_L7P_HDGC_AD5P_84

##########################
### SPI for Attenuator ###
##########################
set_property PACKAGE_PIN AR12      [get_ports "DB_1V8_PE_SI"]		;# D48 ADCIO_07 Bank  84 VCCO - VCC1V8   - IO_L9P_AD3P_84
set_property IOSTANDARD  LVCMOS18  [get_ports "DB_1V8_PE_SI"]		;# D48 ADCIO_07 Bank  84 VCCO - VCC1V8   - IO_L9P_AD3P_84
set_property PACKAGE_PIN AV10      [get_ports "DB_1V8_PE_CLK"]		;# F46 ADCIO_10 Bank  84 VCCO - VCC1V8   - IO_L7N_HDGC_AD5N_84
set_property IOSTANDARD  LVCMOS18  [get_ports "DB_1V8_PE_CLK"]		;# F46 ADCIO_10 Bank  84 VCCO - VCC1V8   - IO_L7N_HDGC_AD5N_84
set_property PACKAGE_PIN AT12      [get_ports "DB_1V8_PE_LE"]		;# D46 ADCIO_06 Bank  84 VCCO - VCC1V8   - IO_L9N_AD3N_84
set_property IOSTANDARD  LVCMOS18  [get_ports "DB_1V8_PE_LE"]		;# D46 ADCIO_06 Bank  84 VCCO - VCC1V8   - IO_L9N_AD3N_84


######################
### SPI for Filter ###
######################
set_property PACKAGE_PIN AP11      [get_ports "DB_1V8_SDI"]			;# A49 ADCIO_01 Bank  84 VCCO - VCC1V8   - IO_L12P_AD0P_84
set_property IOSTANDARD  LVCMOS18  [get_ports "DB_1V8_SDI"]			;# A49 ADCIO_01 Bank  84 VCCO - VCC1V8   - IO_L12P_AD0P_84
set_property PACKAGE_PIN AR11      [get_ports "DB_1V8_SDO"]			;# B46 ADCIO_02 Bank  84 VCCO - VCC1V8   - IO_L11N_AD1N_84
set_property IOSTANDARD  LVCMOS18  [get_ports "DB_1V8_SDO"]			;# B46 ADCIO_02 Bank  84 VCCO - VCC1V8   - IO_L11N_AD1N_84
set_property PACKAGE_PIN AP10      [get_ports "DB_1V8_SER_CLK"]		;# A47 ADCIO_00 Bank  84 VCCO - VCC1V8   - IO_L12N_AD0N_84
set_property IOSTANDARD  LVCMOS18  [get_ports "DB_1V8_SER_CLK"]		;# A47 ADCIO_00 Bank  84 VCCO - VCC1V8   - IO_L12N_AD0N_84
set_property PACKAGE_PIN AP12      [get_ports "DB_1V8_CSn"]			;# B48 ADCIO_03 Bank  84 VCCO - VCC1V8   - IO_L11P_AD1P_84
set_property IOSTANDARD  LVCMOS18  [get_ports "DB_1V8_CSn"]			;# B48 ADCIO_03 Bank  84 VCCO - VCC1V8   - IO_L11P_AD1P_84


set_property PACKAGE_PIN B15       [get_ports "DB_1V8_SEL0"]		;# E2 DACIO_08 Bank  87 VCCO - VCC1V8   - IO_L8N_HDGC_87
set_property IOSTANDARD  LVCMOS18  [get_ports "DB_1V8_SEL0"]		;# E2 DACIO_08 Bank  87 VCCO - VCC1V8   - IO_L8N_HDGC_87
set_property PACKAGE_PIN B16       [get_ports "DB_1V8_SEL1"]		;# E4 DACIO_09 Bank  87 VCCO - VCC1V8   - IO_L8P_HDGC_87
set_property IOSTANDARD  LVCMOS18  [get_ports "DB_1V8_SEL1"]		;# E4 DACIO_09 Bank  87 VCCO - VCC1V8   - IO_L8P_HDGC_87
set_property PACKAGE_PIN C14       [get_ports "DB_1V8_SEL2"]		;# F3 DACIO_10 Bank  87 VCCO - VCC1V8   - IO_L7N_HDGC_87
set_property IOSTANDARD  LVCMOS18  [get_ports "DB_1V8_SEL2"]		;# F3 DACIO_10 Bank  87 VCCO - VCC1V8   - IO_L7N_HDGC_87

################
### BIAS DAC ###
################
set_property PACKAGE_PIN F13       [get_ports "DAC_1V8_BIAS_SCLK"]	;# A2 DACIO_00 Bank  87 VCCO - VCC1V8   - IO_L12N_AD8N_87 
set_property IOSTANDARD  LVCMOS18  [get_ports "DAC_1V8_BIAS_SCLK"]	;# A2 DACIO_00 Bank  87 VCCO - VCC1V8   - IO_L12N_AD8N_87
set_property PACKAGE_PIN F14       [get_ports "DAC_1V8_BIAS_SDIN"]	;# A4 DACIO_01 Bank  87 VCCO - VCC1V8   - IO_L12P_AD8P_87
set_property IOSTANDARD  LVCMOS18  [get_ports "DAC_1V8_BIAS_SDIN"]	;# A4 DACIO_01 Bank  87 VCCO - VCC1V8   - IO_L12P_AD8P_87
set_property PACKAGE_PIN A14       [get_ports "DAC_1V8_BIAS_SDO"]	;# B3 DACIO_02 Bank  87 VCCO - VCC1V8   - IO_L11N_AD9N_87
set_property IOSTANDARD  LVCMOS18  [get_ports "DAC_1V8_BIAS_SDO"]	;# B3 DACIO_02 Bank  87 VCCO - VCC1V8   - IO_L11N_AD9N_87
set_property PACKAGE_PIN A15       [get_ports "DAC_1V8_BIAS_CLRn"]	;# B5 DACIO_03 Bank  87 VCCO - VCC1V8   - IO_L11P_AD9P_87
set_property IOSTANDARD  LVCMOS18  [get_ports "DAC_1V8_BIAS_CLRn"]	;# B5 DACIO_03 Bank  87 VCCO - VCC1V8   - IO_L11P_AD9P_87
set_property PACKAGE_PIN C16       [get_ports "DAC_1V8_BIAS_SYNCn"]	;# C2 DACIO_04 Bank  87 VCCO - VCC1V8   - IO_L10N_AD10N_87
set_property IOSTANDARD  LVCMOS18  [get_ports "DAC_1V8_BIAS_SYNCn"]	;# C2 DACIO_04 Bank  87 VCCO - VCC1V8   - IO_L10N_AD10N_87

set_property PACKAGE_PIN D16       [get_ports "DAC_1V8_BIAS_S0"]	;# C4 DACIO_05 Bank  87 VCCO - VCC1V8   - IO_L10P_AD10P_87
set_property IOSTANDARD  LVCMOS18  [get_ports "DAC_1V8_BIAS_S0"]	;# C4 DACIO_05 Bank  87 VCCO - VCC1V8   - IO_L10P_AD10P_87
set_property PACKAGE_PIN E15       [get_ports "DAC_1V8_BIAS_S1"]	;# D3 DACIO_06 Bank  87 VCCO - VCC1V8   - IO_L9N_AD11N_87
set_property IOSTANDARD  LVCMOS18  [get_ports "DAC_1V8_BIAS_S1"]	;# D3 DACIO_06 Bank  87 VCCO - VCC1V8   - IO_L9N_AD11N_87
set_property PACKAGE_PIN E16       [get_ports "DAC_1V8_BIAS_S2"]	;# D5 DACIO_07 Bank  87 VCCO - VCC1V8   - IO_L9P_AD11P_87
set_property IOSTANDARD  LVCMOS18  [get_ports "DAC_1V8_BIAS_S2"]	;# D5 DACIO_07 Bank  87 VCCO - VCC1V8   - IO_L9P_AD11P_87

set_property PACKAGE_PIN AV11      [get_ports "DAC_1V8_BIAS_SWEN"]	;# H48 ADCIO_15 Bank  84 VCCO - VCC1V8   - IO_L5P_HDGC_AD7P_84
set_property IOSTANDARD  LVCMOS18  [get_ports "DAC_1V8_BIAS_SWEN"]	;# H48 ADCIO_15 Bank  84 VCCO - VCC1V8   - IO_L5P_HDGC_AD7P_84


####################################
### 2MHz reference for switchers ###
####################################
set_property PACKAGE_PIN AU12      [get_ports "TWOMHZ_1V8_PWR_SYNC"] ;# E49 ADCIO_09 Bank  84 VCCO - VCC1V8   - IO_L8P_HDGC_AD4P_84
set_property IOSTANDARD  LVCMOS18  [get_ports "TWOMHZ_1V8_PWR_SYNC"] ;# E49 ADCIO_09 Bank  84 VCCO - VCC1V8   - IO_L8P_HDGC_AD4P_84

##############################
### SPARE (DMA) Connectors ###
##############################
set_property PACKAGE_PIN E14       [get_ports "SPARE0_1V8"]			;# G2 DACIO_12 Bank  87 VCCO - VCC1V8   - IO_L6N_HDGC_87
set_property IOSTANDARD  LVCMOS18  [get_ports "SPARE0_1V8"]			;# G2 DACIO_12 Bank  87 VCCO - VCC1V8   - IO_L6N_HDGC_87
set_property PACKAGE_PIN F15       [get_ports "SPARE1_1V8"]			;# G4 DACIO_13 Bank  87 VCCO - VCC1V8   - IO_L6P_HDGC_87
set_property IOSTANDARD  LVCMOS18  [get_ports "SPARE1_1V8"]			;# G4 DACIO_13 Bank  87 VCCO - VCC1V8   - IO_L6P_HDGC_87
set_property PACKAGE_PIN B12       [get_ports "SPARE3_1V8"]			;# spare2 and 3 switched on v1 H3 DACIO_14 Bank  87 VCCO - VCC1V8   - IO_L4N_AD12N_87
set_property IOSTANDARD  LVCMOS18  [get_ports "SPARE3_1V8"]			;# H3 DACIO_14 Bank  87 VCCO - VCC1V8   - IO_L4N_AD12N_87
set_property PACKAGE_PIN B13       [get_ports "SPARE2_1V8"]			;# spare2 and 3 switched on v1 H5 DACIO_15 Bank  87 VCCO - VCC1V8   - IO_L4P_AD12P_87
set_property IOSTANDARD  LVCMOS18  [get_ports "SPARE2_1V8"]			;# H5 DACIO_15 Bank  87 VCCO - VCC1V8   - IO_L4P_AD12P_87
set_property PACKAGE_PIN AU11      [get_ports "SPARE4_1V8"]			;# E47 ADCIO_08 Bank  84 VCCO - VCC1V8   - IO_L8N_HDGC_AD4N_84
set_property IOSTANDARD  LVCMOS18  [get_ports "SPARE4_1V8"]			;# E47 ADCIO_08 Bank  84 VCCO - VCC1V8   - IO_L8N_HDGC_AD4N_84
set_property PACKAGE_PIN C15       [get_ports "SPARE5_1V8"]			;# F5 DACIO_11 Bank  87 VCCO - VCC1V8   - IO_L7P_HDGC_87
set_property IOSTANDARD  LVCMOS18  [get_ports "SPARE5_1V8"]			;# F5 DACIO_11 Bank  87 VCCO - VCC1V8   - IO_L7P_HDGC_87

########################
### PMOD Connections ###
########################
set_property PACKAGE_PIN G13       [get_ports "PMOD_LED0"] ;# PMOD0_4_LS Bank  88 VCCO - VCC1V8   - IO_L10N_AD10N_88
set_property IOSTANDARD  LVCMOS18  [get_ports "PMOD_LED0"] ;# PMOD0_4_LS Bank  88 VCCO - VCC1V8   - IO_L10N_AD10N_88
set_property PACKAGE_PIN G15       [get_ports "PMOD_LED1"] ;# PMOD0_0_LS Bank  88 VCCO - VCC1V8   - IO_L12N_AD8N_88
set_property IOSTANDARD  LVCMOS18  [get_ports "PMOD_LED1"] ;# PMOD0_0_LS Bank  88 VCCO - VCC1V8   - IO_L12N_AD8N_88
set_property PACKAGE_PIN H13       [get_ports "PMOD_LED2"] ;# PMOD0_5_LS Bank  88 VCCO - VCC1V8   - IO_L10P_AD10P_88
set_property IOSTANDARD  LVCMOS18  [get_ports "PMOD_LED2"] ;# PMOD0_5_LS Bank  88 VCCO - VCC1V8   - IO_L10P_AD10P_88
set_property PACKAGE_PIN G16       [get_ports "PMOD_LED3"] ;# PMOD0_1_LS Bank  88 VCCO - VCC1V8   - IO_L12P_AD8P_88
set_property IOSTANDARD  LVCMOS18  [get_ports "PMOD_LED3"] ;# PMOD0_1_LS Bank  88 VCCO - VCC1V8   - IO_L12P_AD8P_88
set_property PACKAGE_PIN J13       [get_ports "PMOD_LED4"] ;# PMOD0_6_LS Bank  88 VCCO - VCC1V8   - IO_L9N_AD11N_88
set_property IOSTANDARD  LVCMOS18  [get_ports "PMOD_LED4"] ;# PMOD0_6_LS Bank  88 VCCO - VCC1V8   - IO_L9N_AD11N_88
set_property PACKAGE_PIN H14       [get_ports "PMOD_LED5"] ;# PMOD0_2_LS Bank  88 VCCO - VCC1V8   - IO_L11N_AD9N_88
set_property IOSTANDARD  LVCMOS18  [get_ports "PMOD_LED5"] ;# PMOD0_2_LS Bank  88 VCCO - VCC1V8   - IO_L11N_AD9N_88
set_property PACKAGE_PIN J14       [get_ports "PMOD_LED6"] ;# PMOD0_7_LS Bank  88 VCCO - VCC1V8   - IO_L9P_AD11P_88
set_property IOSTANDARD  LVCMOS18  [get_ports "PMOD_LED6"] ;# PMOD0_7_LS Bank  88 VCCO - VCC1V8   - IO_L9P_AD11P_88
set_property PACKAGE_PIN H15       [get_ports "PMOD_LED7"] ;# PMOD0_3_LS Bank  88 VCCO - VCC1V8   - IO_L11P_AD9P_88
set_property IOSTANDARD  LVCMOS18  [get_ports "PMOD_LED7"] ;# PMOD0_3_LS Bank  88 VCCO - VCC1V8   - IO_L11P_AD9P_88

set_property PACKAGE_PIN M15       [get_ports "PMOD_IO_0"] ;# PMOD1_4_LS Bank  88 VCCO - VCC1V8   - IO_L2N_AD14N_88
set_property IOSTANDARD  LVCMOS18  [get_ports "PMOD_IO_0"] ;# PMOD1_4_LS Bank  88 VCCO - VCC1V8   - IO_L2N_AD14N_88
set_property PACKAGE_PIN L17       [get_ports "PMOD_IO_1"] ;# PMOD1_0_LS Bank  88 VCCO - VCC1V8   - IO_L4N_AD12N_88
set_property IOSTANDARD  LVCMOS18  [get_ports "PMOD_IO_1"] ;# PMOD1_0_LS Bank  88 VCCO - VCC1V8   - IO_L4N_AD12N_88
set_property PACKAGE_PIN N15       [get_ports "PMOD_IO_2"] ;# PMOD1_5_LS Bank  88 VCCO - VCC1V8   - IO_L2P_AD14P_88
set_property IOSTANDARD  LVCMOS18  [get_ports "PMOD_IO_2"] ;# PMOD1_5_LS Bank  88 VCCO - VCC1V8   - IO_L2P_AD14P_88
set_property PACKAGE_PIN M17       [get_ports "PMOD_IO_3"] ;# PMOD1_1_LS Bank  88 VCCO - VCC1V8   - IO_L4P_AD12P_88
set_property IOSTANDARD  LVCMOS18  [get_ports "PMOD_IO_3"] ;# PMOD1_1_LS Bank  88 VCCO - VCC1V8   - IO_L4P_AD12P_88
set_property PACKAGE_PIN M16       [get_ports "PMOD_IO_4"] ;# PMOD1_6_LS Bank  88 VCCO - VCC1V8   - IO_L1N_AD15N_88
set_property IOSTANDARD  LVCMOS18  [get_ports "PMOD_IO_4"] ;# PMOD1_6_LS Bank  88 VCCO - VCC1V8   - IO_L1N_AD15N_88
set_property PACKAGE_PIN M14       [get_ports "PMOD_IO_5"] ;# PMOD1_2_LS Bank  88 VCCO - VCC1V8   - IO_L3N_AD13N_88
set_property IOSTANDARD  LVCMOS18  [get_ports "PMOD_IO_5"] ;# PMOD1_2_LS Bank  88 VCCO - VCC1V8   - IO_L3N_AD13N_88
set_property PACKAGE_PIN N16       [get_ports "PMOD_IO_6"] ;# PMOD1_7_LS Bank  88 VCCO - VCC1V8   - IO_L1P_AD15P_88
set_property IOSTANDARD  LVCMOS18  [get_ports "PMOD_IO_6"] ;# PMOD1_7_LS Bank  88 VCCO - VCC1V8   - IO_L1P_AD15P_88
set_property PACKAGE_PIN N14       [get_ports "PMOD_IO_7"] ;# PMOD1_3_LS Bank  88 VCCO - VCC1V8   - IO_L3P_AD13P_88
set_property IOSTANDARD  LVCMOS18  [get_ports "PMOD_IO_7"] ;# PMOD1_3_LS Bank  88 VCCO - VCC1V8   - IO_L3P_AD13P_88

# CLK104 readback
set_property PACKAGE_PIN G10       [get_ports CLK104_CLK_SPI_MUX_SEL_LS[0]] ;# Bank  89 VCCO - VCC1V8   - IO_L4N_AD8N_89
set_property IOSTANDARD  LVCMOS18  [get_ports CLK104_CLK_SPI_MUX_SEL_LS[0]] ;# Bank  89 VCCO - VCC1V8   - IO_L4N_AD8N_89
set_property PACKAGE_PIN H11       [get_ports CLK104_CLK_SPI_MUX_SEL_LS[1]] ;# Bank  89 VCCO - VCC1V8   - IO_L4P_AD8P_89
set_property IOSTANDARD  LVCMOS18  [get_ports CLK104_CLK_SPI_MUX_SEL_LS[1]] ;# Bank  89 VCCO - VCC1V8   - IO_L4P_AD8P_89