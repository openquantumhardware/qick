# MIT License
#
# Copyright (c) 2022 Advanced Micro Devices, Inc. All rights reserved.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE# SOFTWARE.

## This file is a general .xdc for the Add-on board developed for PYNQ-Z2
## To use it in a project:
## - uncomment the lines corresponding to used pins
## - rename the used ports (in each line, after get_ports) according to the top level signal names in the project

## Clock signal from ENET Controller pin
# set_property PACKAGE_PIN H16 [get_ports clk125]							
# set_property IOSTANDARD LVCMOS33 [get_ports clk125]
# create_clock -add -name clk125_pin -period 8.00 -waveform {0 4} [get_ports clk125]

## Clock signal from Adapter's board 12 MHz via RPIO_21_R, connected to Pin 40, FPGA Signal name RP_IO15
# set_property PACKAGE_PIN Y9 [get_ports clk12]							
# set_property IOSTANDARD LVCMOS33 [get_ports clk12]
# create_clock -add -name clk12_pin -period 83.333 -waveform {0 41.667} [get_ports clk12]
 
## Switches maps to SWA (sw[0]) to SWH (sw[7])
# set_property PACKAGE_PIN V6 [get_ports {sw[0]}];	#RPIO_14_R, connector Pin 8, FPGA Signal name RP_IO02				
# 	set_property IOSTANDARD LVCMOS33 [get_ports {sw[0]}]
# set_property PACKAGE_PIN Y6 [get_ports {sw[1]}];	#RPIO_15_R, connector Pin 10, FPGA Signal name RP_IO10					
# 	set_property IOSTANDARD LVCMOS33 [get_ports {sw[1]}]
# set_property PACKAGE_PIN B19 [get_ports {sw[2]}];	#RPIO_16_R, connector Pin 36, FPGA Signal name RP_IO20					
# 	set_property IOSTANDARD LVCMOS33 [get_ports {sw[2]}]
# set_property PACKAGE_PIN U7 [get_ports {sw[3]}];	#RPIO_17_R, connector Pin 11, FPGA Signal name RP_IO03					
# 	set_property IOSTANDARD LVCMOS33 [get_ports {sw[3]}]
# set_property PACKAGE_PIN C20 [get_ports {sw[4]}];	#RPIO_18_R, connector Pin 12, FPGA Signal name RP_IO18					
# 	set_property IOSTANDARD LVCMOS33 [get_ports {sw[4]}]
# set_property PACKAGE_PIN Y8 [get_ports {sw[5]}];	#RPIO_19_R, connector Pin 35, FPGA Signal name RP_IO13					
# 	set_property IOSTANDARD LVCMOS33 [get_ports {sw[5]}]
# set_property PACKAGE_PIN A20 [get_ports {sw[6]}];	#RPIO_20_R, connector Pin 38, FPGA Signal name RP_IO21					
# 	set_property IOSTANDARD LVCMOS33 [get_ports {sw[6]}]
# set_property PACKAGE_PIN W9 [get_ports {sw[7]}];	#RPIO_26_R, connector Pin 37, FPGA Signal name RP_IO14					
# 	set_property IOSTANDARD LVCMOS33 [get_ports {sw[7]}]

# set_property PACKAGE_PIN M20 [get_ports {enable}];   #Board SW0					
# 	set_property IOSTANDARD LVCMOS33 [get_ports {enable}]
 

## LEDs maps to LDA (led[0]) to LDF (led[5]), led6 to LD2 and led7 to LD3
set_property PACKAGE_PIN B20 [get_ports {led[0]}];	#RPIO_12_R, connector Pin 32, FPGA Signal name RP_IO19					
	set_property IOSTANDARD LVCMOS33 [get_ports {led[0]}]
set_property PACKAGE_PIN W8 [get_ports {led[1]}];	#RPIO_13_R, connector Pin 33, FPGA Signal name RP_IO12					
	set_property IOSTANDARD LVCMOS33 [get_ports {led[1]}]
set_property PACKAGE_PIN U8 [get_ports {led[2]}];	#RPIO_22_R, connector Pin 15, FPGA Signal name RP_IO05					
	set_property IOSTANDARD LVCMOS33 [get_ports {led[2]}]
set_property PACKAGE_PIN W6 [get_ports {led[3]}];	#RPIO_23_R, connector Pin 16, FPGA Signal name RP_IO09					
	set_property IOSTANDARD LVCMOS33 [get_ports {led[3]}]
set_property PACKAGE_PIN Y7 [get_ports {led[4]}];	#RPIO_24_R, connector Pin 18, FPGA Signal name RP_IO11					
	set_property IOSTANDARD LVCMOS33 [get_ports {led[4]}]
set_property PACKAGE_PIN F20 [get_ports {led[5]}];	#RPIO_25_R, connector Pin 22, FPGA Signal name RP_IO17					
	set_property IOSTANDARD LVCMOS33 [get_ports {led[5]}]
set_property PACKAGE_PIN N16 [get_ports {led[6]}];	LD2					
	set_property IOSTANDARD LVCMOS33 [get_ports {led[6]}]
set_property PACKAGE_PIN M14 [get_ports {led[7]}];	LD3					
	set_property IOSTANDARD LVCMOS33 [get_ports {led[7]}]
	
##7 segment display
# set_property PACKAGE_PIN Y16 [get_ports {seg[0]}];	#CA-RPIO_SD_R, connector Pin 27, FPGA Signal name JA2_P					
# 	set_property IOSTANDARD LVCMOS33 [get_ports {seg[0]}]
# set_property PACKAGE_PIN Y17 [get_ports {seg[1]}];	#CB-RPIO_SC_R, connector Pin 28, FPGA Signal name JA2_N					
# 	set_property IOSTANDARD LVCMOS33 [get_ports {seg[1]}]
# set_property PACKAGE_PIN W18 [get_ports {seg[2]}];	#CC-RPIO_02_R, connector Pin 3, FPGA Signal name JA4_P					
# 	set_property IOSTANDARD LVCMOS33 [get_ports {seg[2]}]
# set_property PACKAGE_PIN W19 [get_ports {seg[3]}];	#CD-RPIO_03_R, connector Pin 5, FPGA Signal name JA4_N					
# 	set_property IOSTANDARD LVCMOS33 [get_ports {seg[3]}]
# set_property PACKAGE_PIN Y18 [get_ports {seg[4]}];	#CE-RPIO_04_R, connector Pin 7, FPGA Signal name JA1_P					
# 	set_property IOSTANDARD LVCMOS33 [get_ports {seg[4]}]
# set_property PACKAGE_PIN Y19 [get_ports {seg[5]}];	#CF-RPIO_05_R, connector Pin 29, FPGA Signal name JA1_N					
# 	set_property IOSTANDARD LVCMOS33 [get_ports {seg[5]}]
# set_property PACKAGE_PIN U18 [get_ports {seg[6]}];	#CG-RPIO_06_R, connector Pin 31, FPGA Signal name JA3_P					
# 	set_property IOSTANDARD LVCMOS33 [get_ports {seg[6]}]
# set_property PACKAGE_PIN U19 [get_ports seg[7]];	#DP-RPIO_07_R, connector Pin 26, FPGA Signal name JA3_N							
# 	set_property IOSTANDARD LVCMOS33 [get_ports seg[7]]

# set_property PACKAGE_PIN W10 [get_ports {an[3]}];	#CA-RPIO_11_R, connector Pin 23, FPGA Signal name RP_IO08					
# 	set_property IOSTANDARD LVCMOS33 [get_ports {an[3]}]
# set_property PACKAGE_PIN V8 [get_ports {an[2]}];	#CA-RPIO_10_R, connector Pin 19, FPGA Signal name RP_IO06					
# 	set_property IOSTANDARD LVCMOS33 [get_ports {an[2]}]
# set_property PACKAGE_PIN V10 [get_ports {an[1]}];	#CA-RPIO_09_R, connector Pin 21, FPGA Signal name RP_IO07					
# 	set_property IOSTANDARD LVCMOS33 [get_ports {an[1]}]
# set_property PACKAGE_PIN F19 [get_ports {an[0]}];	#CA-RPIO_08_R, connector Pin 24, FPGA Signal name RP_IO16					
# 	set_property IOSTANDARD LVCMOS33 [get_ports {an[0]}]


# PYNQ-Z2 board Button
# set_property PACKAGE_PIN D19 [get_ports reset];	# BTN0 of the board					
# 	set_property IOSTANDARD LVCMOS33 [get_ports reset]
# Adapter card's button
# set_property PACKAGE_PIN V7 [get_ports clkSel];	#RPIO_27_R, connector Pin 13, FPGA Signal name RP_IO04						
# 	set_property IOSTANDARD LVCMOS33 [get_ports clkSel]
