
################################################################
# This is a generated script based on design: d_1
#
# Though there are limitations about the generated script,
# the main purpose of this utility is to make learning
# IP Integrator Tcl commands easier.
################################################################

namespace eval _tcl {
proc get_script_folder {} {
   set script_path [file normalize [info script]]
   set script_folder [file dirname $script_path]
   return $script_folder
}
}
variable script_folder
set script_folder [_tcl::get_script_folder]

################################################################
# Check if script is running in correct Vivado version.
################################################################
set scripts_vivado_version 2020.2
set current_vivado_version [version -short]

if { [string first $scripts_vivado_version $current_vivado_version] == -1 } {
   puts ""
   catch {common::send_gid_msg -ssname BD::TCL -id 2041 -severity "ERROR" "This script was generated using Vivado <$scripts_vivado_version> and is being run in <$current_vivado_version> of Vivado. Please run the script in Vivado <$scripts_vivado_version> then open the design in Vivado <$current_vivado_version>. Upgrade the design by running \"Tools => Report => Report IP Status...\", then run write_bd_tcl to create an updated script."}

   return 1
}

################################################################
# START
################################################################

# To test this script, run the following commands from Vivado Tcl console:
# source d_1_script.tcl


# The design that will be created by this Tcl script contains the following 
# module references:
# lo_spi_mux, vect2bits_16

# Please add the sources of those modules before sourcing this Tcl script.

# If there is no project opened, this script will create a
# project, but make sure you do not have an existing project
# <./myproj/project_1.xpr> in the current working folder.

set list_projs [get_projects -quiet]
if { $list_projs eq "" } {
   create_project project_1 myproj -part xczu28dr-ffvg1517-2-e
   set_property BOARD_PART xilinx.com:zcu111:part0:1.4 [current_project]
}


# CHANGE DESIGN NAME HERE
variable design_name
set design_name d_1

# If you do not already have an existing IP Integrator design open,
# you can create a design using the following command:
#    create_bd_design $design_name

# Creating design if needed
set errMsg ""
set nRet 0

set cur_design [current_bd_design -quiet]
set list_cells [get_bd_cells -quiet]

if { ${design_name} eq "" } {
   # USE CASES:
   #    1) Design_name not set

   set errMsg "Please set the variable <design_name> to a non-empty value."
   set nRet 1

} elseif { ${cur_design} ne "" && ${list_cells} eq "" } {
   # USE CASES:
   #    2): Current design opened AND is empty AND names same.
   #    3): Current design opened AND is empty AND names diff; design_name NOT in project.
   #    4): Current design opened AND is empty AND names diff; design_name exists in project.

   if { $cur_design ne $design_name } {
      common::send_gid_msg -ssname BD::TCL -id 2001 -severity "INFO" "Changing value of <design_name> from <$design_name> to <$cur_design> since current design is empty."
      set design_name [get_property NAME $cur_design]
   }
   common::send_gid_msg -ssname BD::TCL -id 2002 -severity "INFO" "Constructing design in IPI design <$cur_design>..."

} elseif { ${cur_design} ne "" && $list_cells ne "" && $cur_design eq $design_name } {
   # USE CASES:
   #    5) Current design opened AND has components AND same names.

   set errMsg "Design <$design_name> already exists in your project, please set the variable <design_name> to another value."
   set nRet 1
} elseif { [get_files -quiet ${design_name}.bd] ne "" } {
   # USE CASES: 
   #    6) Current opened design, has components, but diff names, design_name exists in project.
   #    7) No opened design, design_name exists in project.

   set errMsg "Design <$design_name> already exists in your project, please set the variable <design_name> to another value."
   set nRet 2

} else {
   # USE CASES:
   #    8) No opened design, design_name not in project.
   #    9) Current opened design, has components, but diff names, design_name not in project.

   common::send_gid_msg -ssname BD::TCL -id 2003 -severity "INFO" "Currently there is no design <$design_name> in project, so creating one..."

   create_bd_design $design_name

   common::send_gid_msg -ssname BD::TCL -id 2004 -severity "INFO" "Making design <$design_name> as current_bd_design."
   current_bd_design $design_name

}

common::send_gid_msg -ssname BD::TCL -id 2005 -severity "INFO" "Currently the variable <design_name> is equal to \"$design_name\"."

if { $nRet != 0 } {
   catch {common::send_gid_msg -ssname BD::TCL -id 2006 -severity "ERROR" $errMsg}
   return $nRet
}

set bCheckIPsPassed 1
##################################################################
# CHECK IPs
##################################################################
set bCheckIPs 1
if { $bCheckIPs == 1 } {
   set list_check_ips "\ 
xilinx.com:ip:axi_quad_spi:3.2\
xilinx.com:ip:axi_bram_ctrl:4.1\
xilinx.com:ip:blk_mem_gen:8.4\
xilinx.com:ip:axi_dma:7.1\
xilinx.com:ip:smartconnect:1.0\
user.org:user:axis_avg_buffer:1.0\
xilinx.com:ip:axis_clock_converter:1.1\
user.org:user:axis_constant:1.0\
user.org:user:axis_readout_v2:1.0\
xilinx.com:ip:axis_register_slice:1.1\
user.org:user:axis_set_reg:1.0\
user.org:user:axis_signal_gen_v6:1.0\
xilinx.com:ip:axis_switch:1.1\
user.org:user:axis_terminator:1.0\
user.org:user:axis_tproc64x32_x8:1.0\
xilinx.com:ip:xlconstant:1.1\
xilinx.com:ip:clk_wiz:6.0\
xilinx.com:ip:proc_sys_reset:5.0\
xilinx.com:ip:system_ila:1.1\
xilinx.com:ip:usp_rf_data_converter:2.4\
xilinx.com:ip:zynq_ultra_ps_e:3.3\
"

   set list_ips_missing ""
   common::send_gid_msg -ssname BD::TCL -id 2011 -severity "INFO" "Checking if the following IPs exist in the project's IP catalog: $list_check_ips ."

   foreach ip_vlnv $list_check_ips {
      set ip_obj [get_ipdefs -all $ip_vlnv]
      if { $ip_obj eq "" } {
         lappend list_ips_missing $ip_vlnv
      }
   }

   if { $list_ips_missing ne "" } {
      catch {common::send_gid_msg -ssname BD::TCL -id 2012 -severity "ERROR" "The following IPs are not found in the IP Catalog:\n  $list_ips_missing\n\nResolution: Please add the repository containing the IP(s) to the project." }
      set bCheckIPsPassed 0
   }

}

##################################################################
# CHECK Modules
##################################################################
set bCheckModules 1
if { $bCheckModules == 1 } {
   set list_check_mods "\ 
lo_spi_mux\
vect2bits_16\
"

   set list_mods_missing ""
   common::send_gid_msg -ssname BD::TCL -id 2020 -severity "INFO" "Checking if the following modules exist in the project's sources: $list_check_mods ."

   foreach mod_vlnv $list_check_mods {
      if { [can_resolve_reference $mod_vlnv] == 0 } {
         lappend list_mods_missing $mod_vlnv
      }
   }

   if { $list_mods_missing ne "" } {
      catch {common::send_gid_msg -ssname BD::TCL -id 2021 -severity "ERROR" "The following module(s) are not found in the project: $list_mods_missing" }
      common::send_gid_msg -ssname BD::TCL -id 2022 -severity "INFO" "Please add source files for the missing module(s) above."
      set bCheckIPsPassed 0
   }
}

if { $bCheckIPsPassed != 1 } {
  common::send_gid_msg -ssname BD::TCL -id 2023 -severity "WARNING" "Will not continue with creation of design due to the error(s) above."
  return 3
}

##################################################################
# DESIGN PROCs
##################################################################



# Procedure to create entire design; Provide argument to make
# procedure reusable. If parentCell is "", will use root.
proc create_root_design { parentCell } {

  variable script_folder
  variable design_name

  if { $parentCell eq "" } {
     set parentCell [get_bd_cells /]
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2090 -severity "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2091 -severity "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj


  # Create interface ports
  set adc0_clk [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 adc0_clk ]

  set dac0_clk [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 dac0_clk ]

  set dac1_clk [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 dac1_clk ]

  set sysref_in [ create_bd_intf_port -mode Slave -vlnv xilinx.com:display_usp_rf_data_converter:diff_pins_rtl:1.0 sysref_in ]

  set vin0 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 vin0 ]

  set vin1 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 vin1 ]

  set vout0 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 vout0 ]

  set vout1 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 vout1 ]

  set vout2 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 vout2 ]

  set vout3 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 vout3 ]

  set vout4 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 vout4 ]

  set vout5 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 vout5 ]

  set vout6 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 vout6 ]


  # Create ports
  set ATTN_CLK [ create_bd_port -dir O ATTN_CLK ]
  set ATTN_LE [ create_bd_port -dir O -from 2 -to 0 ATTN_LE ]
  set ATTN_SI [ create_bd_port -dir O ATTN_SI ]
  set BIAS_CE [ create_bd_port -dir O -from 0 -to 0 BIAS_CE ]
  set BIAS_CLR [ create_bd_port -dir O -from 0 -to 0 BIAS_CLR ]
  set BIAS_RESET [ create_bd_port -dir O -from 0 -to 0 BIAS_RESET ]
  set BIAS_S [ create_bd_port -dir O -from 3 -to 0 BIAS_S ]
  set BIAS_SCLK [ create_bd_port -dir O BIAS_SCLK ]
  set BIAS_SDI [ create_bd_port -dir O BIAS_SDI ]
  set BIAS_SDO [ create_bd_port -dir I BIAS_SDO ]
  set LO_CS0 [ create_bd_port -dir O LO_CS0 ]
  set LO_CS1 [ create_bd_port -dir O LO_CS1 ]
  set LO_MISO0 [ create_bd_port -dir I LO_MISO0 ]
  set LO_MISO1 [ create_bd_port -dir I LO_MISO1 ]
  set LO_MOSI [ create_bd_port -dir O LO_MOSI ]
  set LO_SCLK [ create_bd_port -dir O LO_SCLK ]
  set PMOD0_0_LS [ create_bd_port -dir O PMOD0_0_LS ]
  set PMOD0_1_LS [ create_bd_port -dir O PMOD0_1_LS ]
  set PMOD0_2_LS [ create_bd_port -dir O PMOD0_2_LS ]
  set PMOD0_3_LS [ create_bd_port -dir O PMOD0_3_LS ]
  set PMOD0_4_LS [ create_bd_port -dir O PMOD0_4_LS ]
  set PMOD0_5_LS [ create_bd_port -dir O PMOD0_5_LS ]
  set PMOD0_6_LS [ create_bd_port -dir O PMOD0_6_LS ]
  set PMOD0_7_LS [ create_bd_port -dir O PMOD0_7_LS ]
  set PMOD1_0_LS [ create_bd_port -dir I PMOD1_0_LS ]
  set PWR_SYNC [ create_bd_port -dir O -from 0 -to 0 PWR_SYNC ]
  set RST_5VEN [ create_bd_port -dir O -from 0 -to 0 RST_5VEN ]
  set S [ create_bd_port -dir O -from 3 -to 0 S ]
  set SCLK [ create_bd_port -dir O SCLK ]
  set SDI [ create_bd_port -dir O SDI ]
  set SDO [ create_bd_port -dir I SDO ]

  # Create instance: attn_spi, and set properties
  set attn_spi [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_quad_spi:3.2 attn_spi ]
  set_property -dict [ list \
   CONFIG.C_NUM_SS_BITS {3} \
   CONFIG.C_NUM_TRANSFER_BITS {16} \
 ] $attn_spi

  # Create instance: axi_bram_ctrl_0, and set properties
  set axi_bram_ctrl_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 axi_bram_ctrl_0 ]
  set_property -dict [ list \
   CONFIG.DATA_WIDTH {64} \
   CONFIG.ECC_TYPE {0} \
   CONFIG.SINGLE_PORT_BRAM {1} \
 ] $axi_bram_ctrl_0

  # Create instance: axi_bram_ctrl_0_bram, and set properties
  set axi_bram_ctrl_0_bram [ create_bd_cell -type ip -vlnv xilinx.com:ip:blk_mem_gen:8.4 axi_bram_ctrl_0_bram ]
  set_property -dict [ list \
   CONFIG.EN_SAFETY_CKT {false} \
   CONFIG.Enable_B {Use_ENB_Pin} \
   CONFIG.Memory_Type {True_Dual_Port_RAM} \
   CONFIG.Port_B_Clock {100} \
   CONFIG.Port_B_Enable_Rate {100} \
   CONFIG.Port_B_Write_Rate {50} \
   CONFIG.Read_Width_B {64} \
   CONFIG.Use_RSTB_Pin {true} \
   CONFIG.Write_Width_B {64} \
 ] $axi_bram_ctrl_0_bram

  # Create instance: axi_dma_avg, and set properties
  set axi_dma_avg [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma_avg ]
  set_property -dict [ list \
   CONFIG.c_include_mm2s {0} \
   CONFIG.c_include_sg {0} \
   CONFIG.c_sg_include_stscntrl_strm {0} \
   CONFIG.c_sg_length_width {26} \
 ] $axi_dma_avg

  # Create instance: axi_dma_buf, and set properties
  set axi_dma_buf [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma_buf ]
  set_property -dict [ list \
   CONFIG.c_include_mm2s {0} \
   CONFIG.c_include_sg {0} \
   CONFIG.c_sg_include_stscntrl_strm {0} \
   CONFIG.c_sg_length_width {26} \
 ] $axi_dma_buf

  # Create instance: axi_dma_gen, and set properties
  set axi_dma_gen [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma_gen ]
  set_property -dict [ list \
   CONFIG.c_include_mm2s {1} \
   CONFIG.c_include_s2mm {0} \
   CONFIG.c_include_sg {0} \
   CONFIG.c_sg_include_stscntrl_strm {0} \
   CONFIG.c_sg_length_width {26} \
 ] $axi_dma_gen

  # Create instance: axi_dma_tproc, and set properties
  set axi_dma_tproc [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma_tproc ]
  set_property -dict [ list \
   CONFIG.c_include_sg {0} \
   CONFIG.c_sg_include_stscntrl_strm {0} \
   CONFIG.c_sg_length_width {26} \
 ] $axi_dma_tproc

  # Create instance: axi_smc, and set properties
  set axi_smc [ create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 axi_smc ]
  set_property -dict [ list \
   CONFIG.NUM_SI {5} \
 ] $axi_smc

  # Create instance: axis_avg_buffer_0, and set properties
  set axis_avg_buffer_0 [ create_bd_cell -type ip -vlnv user.org:user:axis_avg_buffer:1.0 axis_avg_buffer_0 ]
  set_property -dict [ list \
   CONFIG.N_AVG {14} \
 ] $axis_avg_buffer_0

  # Create instance: axis_avg_buffer_1, and set properties
  set axis_avg_buffer_1 [ create_bd_cell -type ip -vlnv user.org:user:axis_avg_buffer:1.0 axis_avg_buffer_1 ]
  set_property -dict [ list \
   CONFIG.N_AVG {14} \
 ] $axis_avg_buffer_1

  # Create instance: axis_clk_cnvrt_avg_0, and set properties
  set axis_clk_cnvrt_avg_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_clock_converter:1.1 axis_clk_cnvrt_avg_0 ]

  # Create instance: axis_clk_cnvrt_avg_1, and set properties
  set axis_clk_cnvrt_avg_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_clock_converter:1.1 axis_clk_cnvrt_avg_1 ]

  # Create instance: axis_clk_cnvrt_gen_3, and set properties
  set axis_clk_cnvrt_gen_3 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_clock_converter:1.1 axis_clk_cnvrt_gen_3 ]

  # Create instance: axis_clk_cnvrt_gen_4, and set properties
  set axis_clk_cnvrt_gen_4 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_clock_converter:1.1 axis_clk_cnvrt_gen_4 ]

  # Create instance: axis_clk_cnvrt_gen_5, and set properties
  set axis_clk_cnvrt_gen_5 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_clock_converter:1.1 axis_clk_cnvrt_gen_5 ]

  # Create instance: axis_clk_cnvrt_gen_6, and set properties
  set axis_clk_cnvrt_gen_6 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_clock_converter:1.1 axis_clk_cnvrt_gen_6 ]

  # Create instance: axis_constant_0, and set properties
  set axis_constant_0 [ create_bd_cell -type ip -vlnv user.org:user:axis_constant:1.0 axis_constant_0 ]
  set_property -dict [ list \
   CONFIG.DATA_WIDTH {64} \
 ] $axis_constant_0

  # Create instance: axis_constant_1, and set properties
  set axis_constant_1 [ create_bd_cell -type ip -vlnv user.org:user:axis_constant:1.0 axis_constant_1 ]
  set_property -dict [ list \
   CONFIG.DATA_WIDTH {64} \
 ] $axis_constant_1

  # Create instance: axis_readout_v2_0, and set properties
  set axis_readout_v2_0 [ create_bd_cell -type ip -vlnv user.org:user:axis_readout_v2:1.0 axis_readout_v2_0 ]

  # Create instance: axis_readout_v2_1, and set properties
  set axis_readout_v2_1 [ create_bd_cell -type ip -vlnv user.org:user:axis_readout_v2:1.0 axis_readout_v2_1 ]

  # Create instance: axis_register_slice_0, and set properties
  set axis_register_slice_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_register_slice:1.1 axis_register_slice_0 ]

  # Create instance: axis_register_slice_1, and set properties
  set axis_register_slice_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_register_slice:1.1 axis_register_slice_1 ]

  # Create instance: axis_set_reg_0, and set properties
  set axis_set_reg_0 [ create_bd_cell -type ip -vlnv user.org:user:axis_set_reg:1.0 axis_set_reg_0 ]
  set_property -dict [ list \
   CONFIG.DATA_WIDTH {160} \
 ] $axis_set_reg_0

  # Create instance: axis_signal_gen_v6_0, and set properties
  set axis_signal_gen_v6_0 [ create_bd_cell -type ip -vlnv user.org:user:axis_signal_gen_v6:1.0 axis_signal_gen_v6_0 ]

  # Create instance: axis_signal_gen_v6_1, and set properties
  set axis_signal_gen_v6_1 [ create_bd_cell -type ip -vlnv user.org:user:axis_signal_gen_v6:1.0 axis_signal_gen_v6_1 ]

  # Create instance: axis_signal_gen_v6_2, and set properties
  set axis_signal_gen_v6_2 [ create_bd_cell -type ip -vlnv user.org:user:axis_signal_gen_v6:1.0 axis_signal_gen_v6_2 ]

  # Create instance: axis_signal_gen_v6_3, and set properties
  set axis_signal_gen_v6_3 [ create_bd_cell -type ip -vlnv user.org:user:axis_signal_gen_v6:1.0 axis_signal_gen_v6_3 ]

  # Create instance: axis_signal_gen_v6_4, and set properties
  set axis_signal_gen_v6_4 [ create_bd_cell -type ip -vlnv user.org:user:axis_signal_gen_v6:1.0 axis_signal_gen_v6_4 ]

  # Create instance: axis_signal_gen_v6_5, and set properties
  set axis_signal_gen_v6_5 [ create_bd_cell -type ip -vlnv user.org:user:axis_signal_gen_v6:1.0 axis_signal_gen_v6_5 ]

  # Create instance: axis_signal_gen_v6_6, and set properties
  set axis_signal_gen_v6_6 [ create_bd_cell -type ip -vlnv user.org:user:axis_signal_gen_v6:1.0 axis_signal_gen_v6_6 ]

  # Create instance: axis_switch_avg, and set properties
  set axis_switch_avg [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_switch:1.1 axis_switch_avg ]
  set_property -dict [ list \
   CONFIG.ROUTING_MODE {1} \
 ] $axis_switch_avg

  # Create instance: axis_switch_buf, and set properties
  set axis_switch_buf [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_switch:1.1 axis_switch_buf ]
  set_property -dict [ list \
   CONFIG.ROUTING_MODE {1} \
 ] $axis_switch_buf

  # Create instance: axis_switch_gen, and set properties
  set axis_switch_gen [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_switch:1.1 axis_switch_gen ]
  set_property -dict [ list \
   CONFIG.DECODER_REG {1} \
   CONFIG.NUM_MI {7} \
   CONFIG.NUM_SI {1} \
   CONFIG.ROUTING_MODE {1} \
 ] $axis_switch_gen

  # Create instance: axis_terminator_0, and set properties
  set axis_terminator_0 [ create_bd_cell -type ip -vlnv user.org:user:axis_terminator:1.0 axis_terminator_0 ]
  set_property -dict [ list \
   CONFIG.DATA_WIDTH {256} \
 ] $axis_terminator_0

  # Create instance: axis_terminator_1, and set properties
  set axis_terminator_1 [ create_bd_cell -type ip -vlnv user.org:user:axis_terminator:1.0 axis_terminator_1 ]
  set_property -dict [ list \
   CONFIG.DATA_WIDTH {256} \
 ] $axis_terminator_1

  # Create instance: axis_tproc64x32_x8_0, and set properties
  set axis_tproc64x32_x8_0 [ create_bd_cell -type ip -vlnv user.org:user:axis_tproc64x32_x8:1.0 axis_tproc64x32_x8_0 ]
  set_property -dict [ list \
   CONFIG.DMEM_N {12} \
   CONFIG.PMEM_N {20} \
 ] $axis_tproc64x32_x8_0

  # Create instance: bias_constant_0, and set properties
  set bias_constant_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 bias_constant_0 ]
  set_property -dict [ list \
   CONFIG.CONST_VAL {0} \
 ] $bias_constant_0

  # Create instance: bias_constant_1, and set properties
  set bias_constant_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 bias_constant_1 ]
  set_property -dict [ list \
   CONFIG.CONST_VAL {1} \
 ] $bias_constant_1

  # Create instance: clk_adc0_x2, and set properties
  set clk_adc0_x2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_adc0_x2 ]
  set_property -dict [ list \
   CONFIG.CLKIN1_JITTER_PS {52.08} \
   CONFIG.CLKOUT1_JITTER {81.938} \
   CONFIG.CLKOUT1_PHASE_ERROR {82.655} \
   CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {384} \
   CONFIG.MMCM_CLKFBOUT_MULT_F {6.250} \
   CONFIG.MMCM_CLKIN1_PERIOD {5.208} \
   CONFIG.MMCM_CLKIN2_PERIOD {10.0} \
   CONFIG.MMCM_CLKOUT0_DIVIDE_F {3.125} \
 ] $clk_adc0_x2

  # Create instance: dac_bias_spi, and set properties
  set dac_bias_spi [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_quad_spi:3.2 dac_bias_spi ]
  set_property -dict [ list \
   CONFIG.C_NUM_SS_BITS {4} \
   CONFIG.C_NUM_TRANSFER_BITS {8} \
 ] $dac_bias_spi

  # Create instance: dig_lconstant_1, and set properties
  set dig_lconstant_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 dig_lconstant_1 ]
  set_property -dict [ list \
   CONFIG.CONST_VAL {1} \
 ] $dig_lconstant_1

  # Create instance: lo_spi, and set properties
  set lo_spi [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_quad_spi:3.2 lo_spi ]
  set_property -dict [ list \
   CONFIG.C_NUM_SS_BITS {2} \
   CONFIG.C_NUM_TRANSFER_BITS {8} \
 ] $lo_spi

  # Create instance: lo_spi_mux_0, and set properties
  set block_name lo_spi_mux
  set block_cell_name lo_spi_mux_0
  if { [catch {set lo_spi_mux_0 [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $lo_spi_mux_0 eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
  
  # Create instance: ps8_0_axi_periph, and set properties
  set ps8_0_axi_periph [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 ps8_0_axi_periph ]
  set_property -dict [ list \
   CONFIG.NUM_MI {26} \
 ] $ps8_0_axi_periph

  # Create instance: psf_spi, and set properties
  set psf_spi [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_quad_spi:3.2 psf_spi ]
  set_property -dict [ list \
   CONFIG.C_NUM_SS_BITS {4} \
   CONFIG.C_NUM_TRANSFER_BITS {8} \
 ] $psf_spi

  # Create instance: rst_100, and set properties
  set rst_100 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_100 ]

  # Create instance: rst_adc0, and set properties
  set rst_adc0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_adc0 ]

  # Create instance: rst_adc0_x2, and set properties
  set rst_adc0_x2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_adc0_x2 ]

  # Create instance: rst_dac0, and set properties
  set rst_dac0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_dac0 ]

  # Create instance: rst_dac1, and set properties
  set rst_dac1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_dac1 ]

  # Create instance: system_ila_0, and set properties
  set system_ila_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:system_ila:1.1 system_ila_0 ]
  set_property -dict [ list \
   CONFIG.C_BRAM_CNT {6} \
   CONFIG.C_MON_TYPE {MIX} \
   CONFIG.C_NUM_MONITOR_SLOTS {1} \
   CONFIG.C_SLOT {0} \
   CONFIG.C_SLOT_0_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} \
   CONFIG.C_SLOT_1_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} \
   CONFIG.C_SLOT_2_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} \
   CONFIG.C_SLOT_3_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} \
   CONFIG.C_SLOT_4_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} \
 ] $system_ila_0

  # Create instance: system_ila_1, and set properties
  set system_ila_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:system_ila:1.1 system_ila_1 ]
  set_property -dict [ list \
   CONFIG.C_BRAM_CNT {6} \
   CONFIG.C_MON_TYPE {MIX} \
   CONFIG.C_NUM_MONITOR_SLOTS {1} \
   CONFIG.C_SLOT {0} \
   CONFIG.C_SLOT_0_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} \
   CONFIG.C_SLOT_1_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} \
   CONFIG.C_SLOT_2_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} \
   CONFIG.C_SLOT_3_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} \
   CONFIG.C_SLOT_4_INTF_TYPE {xilinx.com:interface:axis_rtl:1.0} \
 ] $system_ila_1

  # Create instance: usp_rf_data_converter_0, and set properties
  set usp_rf_data_converter_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:usp_rf_data_converter:2.4 usp_rf_data_converter_0 ]
  set_property -dict [ list \
   CONFIG.ADC0_Enable {1} \
   CONFIG.ADC0_Fabric_Freq {384.000} \
   CONFIG.ADC0_Outclk_Freq {192.000} \
   CONFIG.ADC0_PLL_Enable {true} \
   CONFIG.ADC0_Refclk_Freq {204.800} \
   CONFIG.ADC0_Sampling_Rate {3.072} \
   CONFIG.ADC_Decimation_Mode00 {1} \
   CONFIG.ADC_Decimation_Mode01 {1} \
   CONFIG.ADC_Decimation_Mode02 {1} \
   CONFIG.ADC_Decimation_Mode03 {1} \
   CONFIG.ADC_Mixer_Type00 {0} \
   CONFIG.ADC_Mixer_Type01 {0} \
   CONFIG.ADC_Mixer_Type02 {0} \
   CONFIG.ADC_Mixer_Type03 {0} \
   CONFIG.ADC_Slice00_Enable {true} \
   CONFIG.ADC_Slice01_Enable {true} \
   CONFIG.ADC_Slice02_Enable {true} \
   CONFIG.ADC_Slice03_Enable {true} \
   CONFIG.DAC0_Enable {1} \
   CONFIG.DAC0_Fabric_Freq {384.000} \
   CONFIG.DAC0_Outclk_Freq {384.000} \
   CONFIG.DAC0_PLL_Enable {true} \
   CONFIG.DAC0_Refclk_Freq {204.800} \
   CONFIG.DAC0_Sampling_Rate {6.144} \
   CONFIG.DAC1_Enable {1} \
   CONFIG.DAC1_Fabric_Freq {384.000} \
   CONFIG.DAC1_Outclk_Freq {384.000} \
   CONFIG.DAC1_PLL_Enable {true} \
   CONFIG.DAC1_Refclk_Freq {204.800} \
   CONFIG.DAC1_Sampling_Rate {6.144} \
   CONFIG.DAC_Interpolation_Mode00 {1} \
   CONFIG.DAC_Interpolation_Mode01 {1} \
   CONFIG.DAC_Interpolation_Mode02 {1} \
   CONFIG.DAC_Interpolation_Mode10 {1} \
   CONFIG.DAC_Interpolation_Mode11 {1} \
   CONFIG.DAC_Interpolation_Mode12 {1} \
   CONFIG.DAC_Interpolation_Mode13 {1} \
   CONFIG.DAC_Mixer_Type00 {0} \
   CONFIG.DAC_Mixer_Type01 {0} \
   CONFIG.DAC_Mixer_Type02 {0} \
   CONFIG.DAC_Mixer_Type10 {0} \
   CONFIG.DAC_Mixer_Type11 {0} \
   CONFIG.DAC_Mixer_Type12 {0} \
   CONFIG.DAC_Mixer_Type13 {0} \
   CONFIG.DAC_Slice00_Enable {true} \
   CONFIG.DAC_Slice01_Enable {true} \
   CONFIG.DAC_Slice02_Enable {true} \
   CONFIG.DAC_Slice10_Enable {true} \
   CONFIG.DAC_Slice11_Enable {true} \
   CONFIG.DAC_Slice12_Enable {true} \
   CONFIG.DAC_Slice13_Enable {true} \
 ] $usp_rf_data_converter_0

  # Create instance: vect2bits_16_0, and set properties
  set block_name vect2bits_16
  set block_cell_name vect2bits_16_0
  if { [catch {set vect2bits_16_0 [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $vect2bits_16_0 eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
  
  # Create instance: xlconstant_0, and set properties
  set xlconstant_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_0 ]
  set_property -dict [ list \
   CONFIG.CONST_VAL {0} \
   CONFIG.CONST_WIDTH {64} \
 ] $xlconstant_0

  # Create instance: xlconstant_1, and set properties
  set xlconstant_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_1 ]
  set_property -dict [ list \
   CONFIG.CONST_WIDTH {1} \
 ] $xlconstant_1

  # Create instance: xlconstant_2, and set properties
  set xlconstant_2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_2 ]
  set_property -dict [ list \
   CONFIG.CONST_VAL {0} \
   CONFIG.CONST_WIDTH {1} \
 ] $xlconstant_2

  # Create instance: xlconstant_3, and set properties
  set xlconstant_3 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_3 ]
  set_property -dict [ list \
   CONFIG.CONST_VAL {0} \
   CONFIG.CONST_WIDTH {8} \
 ] $xlconstant_3

  # Create instance: zynq_ultra_ps_e_0, and set properties
  set zynq_ultra_ps_e_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e:3.3 zynq_ultra_ps_e_0 ]
  set_property -dict [ list \
   CONFIG.CAN0_BOARD_INTERFACE {custom} \
   CONFIG.CAN1_BOARD_INTERFACE {custom} \
   CONFIG.CSU_BOARD_INTERFACE {custom} \
   CONFIG.DP_BOARD_INTERFACE {custom} \
   CONFIG.GEM0_BOARD_INTERFACE {custom} \
   CONFIG.GEM1_BOARD_INTERFACE {custom} \
   CONFIG.GEM2_BOARD_INTERFACE {custom} \
   CONFIG.GEM3_BOARD_INTERFACE {custom} \
   CONFIG.GPIO_BOARD_INTERFACE {custom} \
   CONFIG.IIC0_BOARD_INTERFACE {custom} \
   CONFIG.IIC1_BOARD_INTERFACE {custom} \
   CONFIG.NAND_BOARD_INTERFACE {custom} \
   CONFIG.PCIE_BOARD_INTERFACE {custom} \
   CONFIG.PJTAG_BOARD_INTERFACE {custom} \
   CONFIG.PMU_BOARD_INTERFACE {custom} \
   CONFIG.PSU_BANK_0_IO_STANDARD {LVCMOS18} \
   CONFIG.PSU_BANK_1_IO_STANDARD {LVCMOS18} \
   CONFIG.PSU_BANK_2_IO_STANDARD {LVCMOS18} \
   CONFIG.PSU_BANK_3_IO_STANDARD {LVCMOS33} \
   CONFIG.PSU_DDR_RAM_HIGHADDR {0xFFFFFFFF} \
   CONFIG.PSU_DDR_RAM_HIGHADDR_OFFSET {0x800000000} \
   CONFIG.PSU_DDR_RAM_LOWADDR_OFFSET {0x80000000} \
   CONFIG.PSU_DYNAMIC_DDR_CONFIG_EN {0} \
   CONFIG.PSU_IMPORT_BOARD_PRESET {} \
   CONFIG.PSU_MIO_0_DIRECTION {out} \
   CONFIG.PSU_MIO_0_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_0_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_0_POLARITY {Default} \
   CONFIG.PSU_MIO_0_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_0_SLEW {fast} \
   CONFIG.PSU_MIO_10_DIRECTION {inout} \
   CONFIG.PSU_MIO_10_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_10_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_10_POLARITY {Default} \
   CONFIG.PSU_MIO_10_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_10_SLEW {fast} \
   CONFIG.PSU_MIO_11_DIRECTION {inout} \
   CONFIG.PSU_MIO_11_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_11_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_11_POLARITY {Default} \
   CONFIG.PSU_MIO_11_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_11_SLEW {fast} \
   CONFIG.PSU_MIO_12_DIRECTION {out} \
   CONFIG.PSU_MIO_12_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_12_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_12_POLARITY {Default} \
   CONFIG.PSU_MIO_12_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_12_SLEW {fast} \
   CONFIG.PSU_MIO_13_DIRECTION {inout} \
   CONFIG.PSU_MIO_13_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_13_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_13_POLARITY {Default} \
   CONFIG.PSU_MIO_13_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_13_SLEW {fast} \
   CONFIG.PSU_MIO_14_DIRECTION {inout} \
   CONFIG.PSU_MIO_14_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_14_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_14_POLARITY {Default} \
   CONFIG.PSU_MIO_14_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_14_SLEW {fast} \
   CONFIG.PSU_MIO_15_DIRECTION {inout} \
   CONFIG.PSU_MIO_15_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_15_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_15_POLARITY {Default} \
   CONFIG.PSU_MIO_15_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_15_SLEW {fast} \
   CONFIG.PSU_MIO_16_DIRECTION {inout} \
   CONFIG.PSU_MIO_16_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_16_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_16_POLARITY {Default} \
   CONFIG.PSU_MIO_16_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_16_SLEW {fast} \
   CONFIG.PSU_MIO_17_DIRECTION {inout} \
   CONFIG.PSU_MIO_17_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_17_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_17_POLARITY {Default} \
   CONFIG.PSU_MIO_17_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_17_SLEW {fast} \
   CONFIG.PSU_MIO_18_DIRECTION {in} \
   CONFIG.PSU_MIO_18_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_18_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_18_POLARITY {Default} \
   CONFIG.PSU_MIO_18_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_18_SLEW {fast} \
   CONFIG.PSU_MIO_19_DIRECTION {out} \
   CONFIG.PSU_MIO_19_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_19_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_19_POLARITY {Default} \
   CONFIG.PSU_MIO_19_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_19_SLEW {fast} \
   CONFIG.PSU_MIO_1_DIRECTION {inout} \
   CONFIG.PSU_MIO_1_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_1_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_1_POLARITY {Default} \
   CONFIG.PSU_MIO_1_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_1_SLEW {fast} \
   CONFIG.PSU_MIO_20_DIRECTION {inout} \
   CONFIG.PSU_MIO_20_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_20_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_20_POLARITY {Default} \
   CONFIG.PSU_MIO_20_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_20_SLEW {fast} \
   CONFIG.PSU_MIO_21_DIRECTION {inout} \
   CONFIG.PSU_MIO_21_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_21_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_21_POLARITY {Default} \
   CONFIG.PSU_MIO_21_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_21_SLEW {fast} \
   CONFIG.PSU_MIO_22_DIRECTION {inout} \
   CONFIG.PSU_MIO_22_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_22_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_22_POLARITY {Default} \
   CONFIG.PSU_MIO_22_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_22_SLEW {fast} \
   CONFIG.PSU_MIO_23_DIRECTION {inout} \
   CONFIG.PSU_MIO_23_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_23_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_23_POLARITY {Default} \
   CONFIG.PSU_MIO_23_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_23_SLEW {fast} \
   CONFIG.PSU_MIO_24_DIRECTION {inout} \
   CONFIG.PSU_MIO_24_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_24_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_24_POLARITY {Default} \
   CONFIG.PSU_MIO_24_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_24_SLEW {fast} \
   CONFIG.PSU_MIO_25_DIRECTION {inout} \
   CONFIG.PSU_MIO_25_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_25_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_25_POLARITY {Default} \
   CONFIG.PSU_MIO_25_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_25_SLEW {fast} \
   CONFIG.PSU_MIO_26_DIRECTION {inout} \
   CONFIG.PSU_MIO_26_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_26_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_26_POLARITY {Default} \
   CONFIG.PSU_MIO_26_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_26_SLEW {fast} \
   CONFIG.PSU_MIO_27_DIRECTION {out} \
   CONFIG.PSU_MIO_27_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_27_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_27_POLARITY {Default} \
   CONFIG.PSU_MIO_27_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_27_SLEW {fast} \
   CONFIG.PSU_MIO_28_DIRECTION {in} \
   CONFIG.PSU_MIO_28_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_28_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_28_POLARITY {Default} \
   CONFIG.PSU_MIO_28_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_28_SLEW {fast} \
   CONFIG.PSU_MIO_29_DIRECTION {out} \
   CONFIG.PSU_MIO_29_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_29_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_29_POLARITY {Default} \
   CONFIG.PSU_MIO_29_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_29_SLEW {fast} \
   CONFIG.PSU_MIO_2_DIRECTION {inout} \
   CONFIG.PSU_MIO_2_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_2_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_2_POLARITY {Default} \
   CONFIG.PSU_MIO_2_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_2_SLEW {fast} \
   CONFIG.PSU_MIO_30_DIRECTION {in} \
   CONFIG.PSU_MIO_30_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_30_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_30_POLARITY {Default} \
   CONFIG.PSU_MIO_30_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_30_SLEW {fast} \
   CONFIG.PSU_MIO_31_DIRECTION {inout} \
   CONFIG.PSU_MIO_31_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_31_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_31_POLARITY {Default} \
   CONFIG.PSU_MIO_31_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_31_SLEW {fast} \
   CONFIG.PSU_MIO_32_DIRECTION {out} \
   CONFIG.PSU_MIO_32_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_32_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_32_POLARITY {Default} \
   CONFIG.PSU_MIO_32_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_32_SLEW {fast} \
   CONFIG.PSU_MIO_33_DIRECTION {out} \
   CONFIG.PSU_MIO_33_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_33_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_33_POLARITY {Default} \
   CONFIG.PSU_MIO_33_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_33_SLEW {fast} \
   CONFIG.PSU_MIO_34_DIRECTION {out} \
   CONFIG.PSU_MIO_34_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_34_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_34_POLARITY {Default} \
   CONFIG.PSU_MIO_34_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_34_SLEW {fast} \
   CONFIG.PSU_MIO_35_DIRECTION {out} \
   CONFIG.PSU_MIO_35_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_35_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_35_POLARITY {Default} \
   CONFIG.PSU_MIO_35_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_35_SLEW {fast} \
   CONFIG.PSU_MIO_36_DIRECTION {out} \
   CONFIG.PSU_MIO_36_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_36_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_36_POLARITY {Default} \
   CONFIG.PSU_MIO_36_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_36_SLEW {fast} \
   CONFIG.PSU_MIO_37_DIRECTION {out} \
   CONFIG.PSU_MIO_37_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_37_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_37_POLARITY {Default} \
   CONFIG.PSU_MIO_37_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_37_SLEW {fast} \
   CONFIG.PSU_MIO_38_DIRECTION {inout} \
   CONFIG.PSU_MIO_38_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_38_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_38_POLARITY {Default} \
   CONFIG.PSU_MIO_38_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_38_SLEW {fast} \
   CONFIG.PSU_MIO_39_DIRECTION {inout} \
   CONFIG.PSU_MIO_39_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_39_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_39_POLARITY {Default} \
   CONFIG.PSU_MIO_39_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_39_SLEW {fast} \
   CONFIG.PSU_MIO_3_DIRECTION {inout} \
   CONFIG.PSU_MIO_3_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_3_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_3_POLARITY {Default} \
   CONFIG.PSU_MIO_3_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_3_SLEW {fast} \
   CONFIG.PSU_MIO_40_DIRECTION {inout} \
   CONFIG.PSU_MIO_40_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_40_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_40_POLARITY {Default} \
   CONFIG.PSU_MIO_40_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_40_SLEW {fast} \
   CONFIG.PSU_MIO_41_DIRECTION {inout} \
   CONFIG.PSU_MIO_41_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_41_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_41_POLARITY {Default} \
   CONFIG.PSU_MIO_41_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_41_SLEW {fast} \
   CONFIG.PSU_MIO_42_DIRECTION {inout} \
   CONFIG.PSU_MIO_42_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_42_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_42_POLARITY {Default} \
   CONFIG.PSU_MIO_42_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_42_SLEW {fast} \
   CONFIG.PSU_MIO_43_DIRECTION {inout} \
   CONFIG.PSU_MIO_43_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_43_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_43_POLARITY {Default} \
   CONFIG.PSU_MIO_43_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_43_SLEW {fast} \
   CONFIG.PSU_MIO_44_DIRECTION {inout} \
   CONFIG.PSU_MIO_44_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_44_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_44_POLARITY {Default} \
   CONFIG.PSU_MIO_44_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_44_SLEW {fast} \
   CONFIG.PSU_MIO_45_DIRECTION {in} \
   CONFIG.PSU_MIO_45_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_45_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_45_POLARITY {Default} \
   CONFIG.PSU_MIO_45_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_45_SLEW {fast} \
   CONFIG.PSU_MIO_46_DIRECTION {inout} \
   CONFIG.PSU_MIO_46_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_46_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_46_POLARITY {Default} \
   CONFIG.PSU_MIO_46_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_46_SLEW {fast} \
   CONFIG.PSU_MIO_47_DIRECTION {inout} \
   CONFIG.PSU_MIO_47_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_47_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_47_POLARITY {Default} \
   CONFIG.PSU_MIO_47_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_47_SLEW {fast} \
   CONFIG.PSU_MIO_48_DIRECTION {inout} \
   CONFIG.PSU_MIO_48_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_48_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_48_POLARITY {Default} \
   CONFIG.PSU_MIO_48_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_48_SLEW {fast} \
   CONFIG.PSU_MIO_49_DIRECTION {inout} \
   CONFIG.PSU_MIO_49_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_49_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_49_POLARITY {Default} \
   CONFIG.PSU_MIO_49_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_49_SLEW {fast} \
   CONFIG.PSU_MIO_4_DIRECTION {inout} \
   CONFIG.PSU_MIO_4_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_4_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_4_POLARITY {Default} \
   CONFIG.PSU_MIO_4_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_4_SLEW {fast} \
   CONFIG.PSU_MIO_50_DIRECTION {inout} \
   CONFIG.PSU_MIO_50_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_50_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_50_POLARITY {Default} \
   CONFIG.PSU_MIO_50_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_50_SLEW {fast} \
   CONFIG.PSU_MIO_51_DIRECTION {out} \
   CONFIG.PSU_MIO_51_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_51_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_51_POLARITY {Default} \
   CONFIG.PSU_MIO_51_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_51_SLEW {fast} \
   CONFIG.PSU_MIO_52_DIRECTION {in} \
   CONFIG.PSU_MIO_52_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_52_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_52_POLARITY {Default} \
   CONFIG.PSU_MIO_52_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_52_SLEW {fast} \
   CONFIG.PSU_MIO_53_DIRECTION {in} \
   CONFIG.PSU_MIO_53_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_53_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_53_POLARITY {Default} \
   CONFIG.PSU_MIO_53_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_53_SLEW {fast} \
   CONFIG.PSU_MIO_54_DIRECTION {inout} \
   CONFIG.PSU_MIO_54_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_54_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_54_POLARITY {Default} \
   CONFIG.PSU_MIO_54_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_54_SLEW {fast} \
   CONFIG.PSU_MIO_55_DIRECTION {in} \
   CONFIG.PSU_MIO_55_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_55_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_55_POLARITY {Default} \
   CONFIG.PSU_MIO_55_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_55_SLEW {fast} \
   CONFIG.PSU_MIO_56_DIRECTION {inout} \
   CONFIG.PSU_MIO_56_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_56_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_56_POLARITY {Default} \
   CONFIG.PSU_MIO_56_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_56_SLEW {fast} \
   CONFIG.PSU_MIO_57_DIRECTION {inout} \
   CONFIG.PSU_MIO_57_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_57_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_57_POLARITY {Default} \
   CONFIG.PSU_MIO_57_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_57_SLEW {fast} \
   CONFIG.PSU_MIO_58_DIRECTION {out} \
   CONFIG.PSU_MIO_58_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_58_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_58_POLARITY {Default} \
   CONFIG.PSU_MIO_58_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_58_SLEW {fast} \
   CONFIG.PSU_MIO_59_DIRECTION {inout} \
   CONFIG.PSU_MIO_59_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_59_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_59_POLARITY {Default} \
   CONFIG.PSU_MIO_59_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_59_SLEW {fast} \
   CONFIG.PSU_MIO_5_DIRECTION {out} \
   CONFIG.PSU_MIO_5_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_5_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_5_POLARITY {Default} \
   CONFIG.PSU_MIO_5_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_5_SLEW {fast} \
   CONFIG.PSU_MIO_60_DIRECTION {inout} \
   CONFIG.PSU_MIO_60_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_60_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_60_POLARITY {Default} \
   CONFIG.PSU_MIO_60_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_60_SLEW {fast} \
   CONFIG.PSU_MIO_61_DIRECTION {inout} \
   CONFIG.PSU_MIO_61_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_61_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_61_POLARITY {Default} \
   CONFIG.PSU_MIO_61_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_61_SLEW {fast} \
   CONFIG.PSU_MIO_62_DIRECTION {inout} \
   CONFIG.PSU_MIO_62_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_62_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_62_POLARITY {Default} \
   CONFIG.PSU_MIO_62_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_62_SLEW {fast} \
   CONFIG.PSU_MIO_63_DIRECTION {inout} \
   CONFIG.PSU_MIO_63_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_63_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_63_POLARITY {Default} \
   CONFIG.PSU_MIO_63_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_63_SLEW {fast} \
   CONFIG.PSU_MIO_64_DIRECTION {out} \
   CONFIG.PSU_MIO_64_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_64_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_64_POLARITY {Default} \
   CONFIG.PSU_MIO_64_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_64_SLEW {fast} \
   CONFIG.PSU_MIO_65_DIRECTION {out} \
   CONFIG.PSU_MIO_65_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_65_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_65_POLARITY {Default} \
   CONFIG.PSU_MIO_65_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_65_SLEW {fast} \
   CONFIG.PSU_MIO_66_DIRECTION {out} \
   CONFIG.PSU_MIO_66_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_66_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_66_POLARITY {Default} \
   CONFIG.PSU_MIO_66_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_66_SLEW {fast} \
   CONFIG.PSU_MIO_67_DIRECTION {out} \
   CONFIG.PSU_MIO_67_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_67_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_67_POLARITY {Default} \
   CONFIG.PSU_MIO_67_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_67_SLEW {fast} \
   CONFIG.PSU_MIO_68_DIRECTION {out} \
   CONFIG.PSU_MIO_68_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_68_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_68_POLARITY {Default} \
   CONFIG.PSU_MIO_68_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_68_SLEW {fast} \
   CONFIG.PSU_MIO_69_DIRECTION {out} \
   CONFIG.PSU_MIO_69_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_69_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_69_POLARITY {Default} \
   CONFIG.PSU_MIO_69_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_69_SLEW {fast} \
   CONFIG.PSU_MIO_6_DIRECTION {out} \
   CONFIG.PSU_MIO_6_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_6_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_6_POLARITY {Default} \
   CONFIG.PSU_MIO_6_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_6_SLEW {fast} \
   CONFIG.PSU_MIO_70_DIRECTION {in} \
   CONFIG.PSU_MIO_70_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_70_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_70_POLARITY {Default} \
   CONFIG.PSU_MIO_70_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_70_SLEW {fast} \
   CONFIG.PSU_MIO_71_DIRECTION {in} \
   CONFIG.PSU_MIO_71_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_71_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_71_POLARITY {Default} \
   CONFIG.PSU_MIO_71_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_71_SLEW {fast} \
   CONFIG.PSU_MIO_72_DIRECTION {in} \
   CONFIG.PSU_MIO_72_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_72_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_72_POLARITY {Default} \
   CONFIG.PSU_MIO_72_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_72_SLEW {fast} \
   CONFIG.PSU_MIO_73_DIRECTION {in} \
   CONFIG.PSU_MIO_73_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_73_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_73_POLARITY {Default} \
   CONFIG.PSU_MIO_73_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_73_SLEW {fast} \
   CONFIG.PSU_MIO_74_DIRECTION {in} \
   CONFIG.PSU_MIO_74_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_74_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_74_POLARITY {Default} \
   CONFIG.PSU_MIO_74_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_74_SLEW {fast} \
   CONFIG.PSU_MIO_75_DIRECTION {in} \
   CONFIG.PSU_MIO_75_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_75_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_75_POLARITY {Default} \
   CONFIG.PSU_MIO_75_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_75_SLEW {fast} \
   CONFIG.PSU_MIO_76_DIRECTION {out} \
   CONFIG.PSU_MIO_76_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_76_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_76_POLARITY {Default} \
   CONFIG.PSU_MIO_76_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_76_SLEW {fast} \
   CONFIG.PSU_MIO_77_DIRECTION {inout} \
   CONFIG.PSU_MIO_77_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_77_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_77_POLARITY {Default} \
   CONFIG.PSU_MIO_77_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_77_SLEW {fast} \
   CONFIG.PSU_MIO_7_DIRECTION {out} \
   CONFIG.PSU_MIO_7_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_7_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_7_POLARITY {Default} \
   CONFIG.PSU_MIO_7_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_7_SLEW {fast} \
   CONFIG.PSU_MIO_8_DIRECTION {inout} \
   CONFIG.PSU_MIO_8_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_8_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_8_POLARITY {Default} \
   CONFIG.PSU_MIO_8_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_8_SLEW {fast} \
   CONFIG.PSU_MIO_9_DIRECTION {inout} \
   CONFIG.PSU_MIO_9_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_9_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_9_POLARITY {Default} \
   CONFIG.PSU_MIO_9_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_9_SLEW {fast} \
   CONFIG.PSU_MIO_TREE_PERIPHERALS {Quad SPI Flash#Quad SPI Flash#Quad SPI Flash#Quad SPI Flash#Quad SPI Flash#Quad SPI Flash#Feedback Clk#Quad SPI Flash#Quad SPI Flash#Quad SPI Flash#Quad SPI Flash#Quad SPI Flash#Quad SPI Flash#GPIO0 MIO#I2C 0#I2C 0#I2C 1#I2C 1#UART 0#UART 0#GPIO0 MIO#GPIO0 MIO#GPIO0 MIO#GPIO0 MIO#GPIO0 MIO#GPIO0 MIO#GPIO1 MIO#DPAUX#DPAUX#DPAUX#DPAUX#GPIO1 MIO#PMU GPO 0#PMU GPO 1#PMU GPO 2#PMU GPO 3#PMU GPO 4#PMU GPO 5#GPIO1 MIO#SD 1#SD 1#SD 1#SD 1#GPIO1 MIO#GPIO1 MIO#SD 1#SD 1#SD 1#SD 1#SD 1#SD 1#SD 1#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#Gem 3#Gem 3#Gem 3#Gem 3#Gem 3#Gem 3#Gem 3#Gem 3#Gem 3#Gem 3#Gem 3#Gem 3#MDIO 3#MDIO 3} \
   CONFIG.PSU_MIO_TREE_SIGNALS {sclk_out#miso_mo1#mo2#mo3#mosi_mi0#n_ss_out#clk_for_lpbk#n_ss_out_upper#mo_upper[0]#mo_upper[1]#mo_upper[2]#mo_upper[3]#sclk_out_upper#gpio0[13]#scl_out#sda_out#scl_out#sda_out#rxd#txd#gpio0[20]#gpio0[21]#gpio0[22]#gpio0[23]#gpio0[24]#gpio0[25]#gpio1[26]#dp_aux_data_out#dp_hot_plug_detect#dp_aux_data_oe#dp_aux_data_in#gpio1[31]#gpo[0]#gpo[1]#gpo[2]#gpo[3]#gpo[4]#gpo[5]#gpio1[38]#sdio1_data_out[4]#sdio1_data_out[5]#sdio1_data_out[6]#sdio1_data_out[7]#gpio1[43]#gpio1[44]#sdio1_cd_n#sdio1_data_out[0]#sdio1_data_out[1]#sdio1_data_out[2]#sdio1_data_out[3]#sdio1_cmd_out#sdio1_clk_out#ulpi_clk_in#ulpi_dir#ulpi_tx_data[2]#ulpi_nxt#ulpi_tx_data[0]#ulpi_tx_data[1]#ulpi_stp#ulpi_tx_data[3]#ulpi_tx_data[4]#ulpi_tx_data[5]#ulpi_tx_data[6]#ulpi_tx_data[7]#rgmii_tx_clk#rgmii_txd[0]#rgmii_txd[1]#rgmii_txd[2]#rgmii_txd[3]#rgmii_tx_ctl#rgmii_rx_clk#rgmii_rxd[0]#rgmii_rxd[1]#rgmii_rxd[2]#rgmii_rxd[3]#rgmii_rx_ctl#gem3_mdc#gem3_mdio_out} \
   CONFIG.PSU_PERIPHERAL_BOARD_PRESET {} \
   CONFIG.PSU_SD0_INTERNAL_BUS_WIDTH {8} \
   CONFIG.PSU_SD1_INTERNAL_BUS_WIDTH {8} \
   CONFIG.PSU_SMC_CYCLE_T0 {NA} \
   CONFIG.PSU_SMC_CYCLE_T1 {NA} \
   CONFIG.PSU_SMC_CYCLE_T2 {NA} \
   CONFIG.PSU_SMC_CYCLE_T3 {NA} \
   CONFIG.PSU_SMC_CYCLE_T4 {NA} \
   CONFIG.PSU_SMC_CYCLE_T5 {NA} \
   CONFIG.PSU_SMC_CYCLE_T6 {NA} \
   CONFIG.PSU_USB3__DUAL_CLOCK_ENABLE {1} \
   CONFIG.PSU_VALUE_SILVERSION {3} \
   CONFIG.PSU__ACPU0__POWER__ON {1} \
   CONFIG.PSU__ACPU1__POWER__ON {1} \
   CONFIG.PSU__ACPU2__POWER__ON {1} \
   CONFIG.PSU__ACPU3__POWER__ON {1} \
   CONFIG.PSU__ACTUAL__IP {1} \
   CONFIG.PSU__ACT_DDR_FREQ_MHZ {1066.656006} \
   CONFIG.PSU__AFI0_COHERENCY {0} \
   CONFIG.PSU__AFI1_COHERENCY {0} \
   CONFIG.PSU__AUX_REF_CLK__FREQMHZ {33.333} \
   CONFIG.PSU__CAN0_LOOP_CAN1__ENABLE {0} \
   CONFIG.PSU__CAN0__GRP_CLK__ENABLE {0} \
   CONFIG.PSU__CAN0__PERIPHERAL__ENABLE {0} \
   CONFIG.PSU__CAN1__GRP_CLK__ENABLE {0} \
   CONFIG.PSU__CAN1__PERIPHERAL__ENABLE {0} \
   CONFIG.PSU__CRF_APB__ACPU_CTRL__ACT_FREQMHZ {1199.988037} \
   CONFIG.PSU__CRF_APB__ACPU_CTRL__DIVISOR0 {1} \
   CONFIG.PSU__CRF_APB__ACPU_CTRL__FREQMHZ {1200} \
   CONFIG.PSU__CRF_APB__ACPU_CTRL__SRCSEL {APLL} \
   CONFIG.PSU__CRF_APB__ACPU__FRAC_ENABLED {0} \
   CONFIG.PSU__CRF_APB__AFI0_REF_CTRL__ACT_FREQMHZ {667} \
   CONFIG.PSU__CRF_APB__AFI0_REF_CTRL__DIVISOR0 {2} \
   CONFIG.PSU__CRF_APB__AFI0_REF_CTRL__FREQMHZ {667} \
   CONFIG.PSU__CRF_APB__AFI0_REF_CTRL__SRCSEL {DPLL} \
   CONFIG.PSU__CRF_APB__AFI0_REF__ENABLE {0} \
   CONFIG.PSU__CRF_APB__AFI1_REF_CTRL__ACT_FREQMHZ {667} \
   CONFIG.PSU__CRF_APB__AFI1_REF_CTRL__DIVISOR0 {2} \
   CONFIG.PSU__CRF_APB__AFI1_REF_CTRL__FREQMHZ {667} \
   CONFIG.PSU__CRF_APB__AFI1_REF_CTRL__SRCSEL {DPLL} \
   CONFIG.PSU__CRF_APB__AFI1_REF__ENABLE {0} \
   CONFIG.PSU__CRF_APB__AFI2_REF_CTRL__ACT_FREQMHZ {667} \
   CONFIG.PSU__CRF_APB__AFI2_REF_CTRL__DIVISOR0 {2} \
   CONFIG.PSU__CRF_APB__AFI2_REF_CTRL__FREQMHZ {667} \
   CONFIG.PSU__CRF_APB__AFI2_REF_CTRL__SRCSEL {DPLL} \
   CONFIG.PSU__CRF_APB__AFI2_REF__ENABLE {0} \
   CONFIG.PSU__CRF_APB__AFI3_REF_CTRL__ACT_FREQMHZ {667} \
   CONFIG.PSU__CRF_APB__AFI3_REF_CTRL__DIVISOR0 {2} \
   CONFIG.PSU__CRF_APB__AFI3_REF_CTRL__FREQMHZ {667} \
   CONFIG.PSU__CRF_APB__AFI3_REF_CTRL__SRCSEL {DPLL} \
   CONFIG.PSU__CRF_APB__AFI3_REF__ENABLE {0} \
   CONFIG.PSU__CRF_APB__AFI4_REF_CTRL__ACT_FREQMHZ {667} \
   CONFIG.PSU__CRF_APB__AFI4_REF_CTRL__DIVISOR0 {2} \
   CONFIG.PSU__CRF_APB__AFI4_REF_CTRL__FREQMHZ {667} \
   CONFIG.PSU__CRF_APB__AFI4_REF_CTRL__SRCSEL {DPLL} \
   CONFIG.PSU__CRF_APB__AFI4_REF__ENABLE {0} \
   CONFIG.PSU__CRF_APB__AFI5_REF_CTRL__ACT_FREQMHZ {667} \
   CONFIG.PSU__CRF_APB__AFI5_REF_CTRL__DIVISOR0 {2} \
   CONFIG.PSU__CRF_APB__AFI5_REF_CTRL__FREQMHZ {667} \
   CONFIG.PSU__CRF_APB__AFI5_REF_CTRL__SRCSEL {DPLL} \
   CONFIG.PSU__CRF_APB__AFI5_REF__ENABLE {0} \
   CONFIG.PSU__CRF_APB__APLL_CTRL__DIV2 {1} \
   CONFIG.PSU__CRF_APB__APLL_CTRL__FBDIV {72} \
   CONFIG.PSU__CRF_APB__APLL_CTRL__FRACDATA {0.000000} \
   CONFIG.PSU__CRF_APB__APLL_CTRL__FRACFREQ {27.138} \
   CONFIG.PSU__CRF_APB__APLL_CTRL__SRCSEL {PSS_REF_CLK} \
   CONFIG.PSU__CRF_APB__APLL_FRAC_CFG__ENABLED {0} \
   CONFIG.PSU__CRF_APB__APLL_TO_LPD_CTRL__DIVISOR0 {3} \
   CONFIG.PSU__CRF_APB__APM_CTRL__ACT_FREQMHZ {1} \
   CONFIG.PSU__CRF_APB__APM_CTRL__DIVISOR0 {1} \
   CONFIG.PSU__CRF_APB__APM_CTRL__FREQMHZ {1} \
   CONFIG.PSU__CRF_APB__DBG_FPD_CTRL__ACT_FREQMHZ {249.997498} \
   CONFIG.PSU__CRF_APB__DBG_FPD_CTRL__DIVISOR0 {2} \
   CONFIG.PSU__CRF_APB__DBG_FPD_CTRL__FREQMHZ {250} \
   CONFIG.PSU__CRF_APB__DBG_FPD_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRF_APB__DBG_TRACE_CTRL__ACT_FREQMHZ {250} \
   CONFIG.PSU__CRF_APB__DBG_TRACE_CTRL__DIVISOR0 {5} \
   CONFIG.PSU__CRF_APB__DBG_TRACE_CTRL__FREQMHZ {250} \
   CONFIG.PSU__CRF_APB__DBG_TRACE_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRF_APB__DBG_TSTMP_CTRL__ACT_FREQMHZ {249.997498} \
   CONFIG.PSU__CRF_APB__DBG_TSTMP_CTRL__DIVISOR0 {2} \
   CONFIG.PSU__CRF_APB__DBG_TSTMP_CTRL__FREQMHZ {250} \
   CONFIG.PSU__CRF_APB__DBG_TSTMP_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRF_APB__DDR_CTRL__ACT_FREQMHZ {533.328003} \
   CONFIG.PSU__CRF_APB__DDR_CTRL__DIVISOR0 {2} \
   CONFIG.PSU__CRF_APB__DDR_CTRL__FREQMHZ {1067} \
   CONFIG.PSU__CRF_APB__DDR_CTRL__SRCSEL {DPLL} \
   CONFIG.PSU__CRF_APB__DPDMA_REF_CTRL__ACT_FREQMHZ {599.994019} \
   CONFIG.PSU__CRF_APB__DPDMA_REF_CTRL__DIVISOR0 {2} \
   CONFIG.PSU__CRF_APB__DPDMA_REF_CTRL__FREQMHZ {600} \
   CONFIG.PSU__CRF_APB__DPDMA_REF_CTRL__SRCSEL {APLL} \
   CONFIG.PSU__CRF_APB__DPLL_CTRL__DIV2 {1} \
   CONFIG.PSU__CRF_APB__DPLL_CTRL__FBDIV {64} \
   CONFIG.PSU__CRF_APB__DPLL_CTRL__FRACDATA {0.000000} \
   CONFIG.PSU__CRF_APB__DPLL_CTRL__FRACFREQ {27.138} \
   CONFIG.PSU__CRF_APB__DPLL_CTRL__SRCSEL {PSS_REF_CLK} \
   CONFIG.PSU__CRF_APB__DPLL_FRAC_CFG__ENABLED {0} \
   CONFIG.PSU__CRF_APB__DPLL_TO_LPD_CTRL__DIVISOR0 {2} \
   CONFIG.PSU__CRF_APB__DP_AUDIO_REF_CTRL__ACT_FREQMHZ {24.999750} \
   CONFIG.PSU__CRF_APB__DP_AUDIO_REF_CTRL__DIVISOR0 {15} \
   CONFIG.PSU__CRF_APB__DP_AUDIO_REF_CTRL__DIVISOR1 {1} \
   CONFIG.PSU__CRF_APB__DP_AUDIO_REF_CTRL__FREQMHZ {25} \
   CONFIG.PSU__CRF_APB__DP_AUDIO_REF_CTRL__SRCSEL {RPLL} \
   CONFIG.PSU__CRF_APB__DP_AUDIO__FRAC_ENABLED {0} \
   CONFIG.PSU__CRF_APB__DP_STC_REF_CTRL__ACT_FREQMHZ {26.785446} \
   CONFIG.PSU__CRF_APB__DP_STC_REF_CTRL__DIVISOR0 {14} \
   CONFIG.PSU__CRF_APB__DP_STC_REF_CTRL__DIVISOR1 {1} \
   CONFIG.PSU__CRF_APB__DP_STC_REF_CTRL__FREQMHZ {27} \
   CONFIG.PSU__CRF_APB__DP_STC_REF_CTRL__SRCSEL {RPLL} \
   CONFIG.PSU__CRF_APB__DP_VIDEO_REF_CTRL__ACT_FREQMHZ {299.997009} \
   CONFIG.PSU__CRF_APB__DP_VIDEO_REF_CTRL__DIVISOR0 {5} \
   CONFIG.PSU__CRF_APB__DP_VIDEO_REF_CTRL__DIVISOR1 {1} \
   CONFIG.PSU__CRF_APB__DP_VIDEO_REF_CTRL__FREQMHZ {300} \
   CONFIG.PSU__CRF_APB__DP_VIDEO_REF_CTRL__SRCSEL {VPLL} \
   CONFIG.PSU__CRF_APB__DP_VIDEO__FRAC_ENABLED {0} \
   CONFIG.PSU__CRF_APB__GDMA_REF_CTRL__ACT_FREQMHZ {599.994019} \
   CONFIG.PSU__CRF_APB__GDMA_REF_CTRL__DIVISOR0 {2} \
   CONFIG.PSU__CRF_APB__GDMA_REF_CTRL__FREQMHZ {600} \
   CONFIG.PSU__CRF_APB__GDMA_REF_CTRL__SRCSEL {APLL} \
   CONFIG.PSU__CRF_APB__GPU_REF_CTRL__ACT_FREQMHZ {0} \
   CONFIG.PSU__CRF_APB__GPU_REF_CTRL__DIVISOR0 {3} \
   CONFIG.PSU__CRF_APB__GPU_REF_CTRL__FREQMHZ {500} \
   CONFIG.PSU__CRF_APB__GPU_REF_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRF_APB__GTGREF0_REF_CTRL__ACT_FREQMHZ {-1} \
   CONFIG.PSU__CRF_APB__GTGREF0_REF_CTRL__DIVISOR0 {-1} \
   CONFIG.PSU__CRF_APB__GTGREF0_REF_CTRL__FREQMHZ {-1} \
   CONFIG.PSU__CRF_APB__GTGREF0_REF_CTRL__SRCSEL {NA} \
   CONFIG.PSU__CRF_APB__GTGREF0__ENABLE {NA} \
   CONFIG.PSU__CRF_APB__PCIE_REF_CTRL__ACT_FREQMHZ {250} \
   CONFIG.PSU__CRF_APB__PCIE_REF_CTRL__DIVISOR0 {6} \
   CONFIG.PSU__CRF_APB__PCIE_REF_CTRL__FREQMHZ {250} \
   CONFIG.PSU__CRF_APB__PCIE_REF_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRF_APB__SATA_REF_CTRL__ACT_FREQMHZ {249.997498} \
   CONFIG.PSU__CRF_APB__SATA_REF_CTRL__DIVISOR0 {2} \
   CONFIG.PSU__CRF_APB__SATA_REF_CTRL__FREQMHZ {250} \
   CONFIG.PSU__CRF_APB__SATA_REF_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRF_APB__TOPSW_LSBUS_CTRL__ACT_FREQMHZ {99.999001} \
   CONFIG.PSU__CRF_APB__TOPSW_LSBUS_CTRL__DIVISOR0 {5} \
   CONFIG.PSU__CRF_APB__TOPSW_LSBUS_CTRL__FREQMHZ {100} \
   CONFIG.PSU__CRF_APB__TOPSW_LSBUS_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRF_APB__TOPSW_MAIN_CTRL__ACT_FREQMHZ {533.328003} \
   CONFIG.PSU__CRF_APB__TOPSW_MAIN_CTRL__DIVISOR0 {2} \
   CONFIG.PSU__CRF_APB__TOPSW_MAIN_CTRL__FREQMHZ {533.33} \
   CONFIG.PSU__CRF_APB__TOPSW_MAIN_CTRL__SRCSEL {DPLL} \
   CONFIG.PSU__CRF_APB__VPLL_CTRL__DIV2 {1} \
   CONFIG.PSU__CRF_APB__VPLL_CTRL__FBDIV {90} \
   CONFIG.PSU__CRF_APB__VPLL_CTRL__FRACDATA {0.000000} \
   CONFIG.PSU__CRF_APB__VPLL_CTRL__FRACFREQ {27.138} \
   CONFIG.PSU__CRF_APB__VPLL_CTRL__SRCSEL {PSS_REF_CLK} \
   CONFIG.PSU__CRF_APB__VPLL_FRAC_CFG__ENABLED {0} \
   CONFIG.PSU__CRF_APB__VPLL_TO_LPD_CTRL__DIVISOR0 {3} \
   CONFIG.PSU__CRL_APB__ADMA_REF_CTRL__ACT_FREQMHZ {499.994995} \
   CONFIG.PSU__CRL_APB__ADMA_REF_CTRL__DIVISOR0 {3} \
   CONFIG.PSU__CRL_APB__ADMA_REF_CTRL__FREQMHZ {500} \
   CONFIG.PSU__CRL_APB__ADMA_REF_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRL_APB__AFI6_REF_CTRL__ACT_FREQMHZ {500} \
   CONFIG.PSU__CRL_APB__AFI6_REF_CTRL__DIVISOR0 {3} \
   CONFIG.PSU__CRL_APB__AFI6_REF_CTRL__FREQMHZ {500} \
   CONFIG.PSU__CRL_APB__AFI6_REF_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRL_APB__AFI6__ENABLE {0} \
   CONFIG.PSU__CRL_APB__AMS_REF_CTRL__ACT_FREQMHZ {49.999500} \
   CONFIG.PSU__CRL_APB__AMS_REF_CTRL__DIVISOR0 {30} \
   CONFIG.PSU__CRL_APB__AMS_REF_CTRL__DIVISOR1 {1} \
   CONFIG.PSU__CRL_APB__AMS_REF_CTRL__FREQMHZ {50} \
   CONFIG.PSU__CRL_APB__AMS_REF_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRL_APB__CAN0_REF_CTRL__ACT_FREQMHZ {100} \
   CONFIG.PSU__CRL_APB__CAN0_REF_CTRL__DIVISOR0 {15} \
   CONFIG.PSU__CRL_APB__CAN0_REF_CTRL__DIVISOR1 {1} \
   CONFIG.PSU__CRL_APB__CAN0_REF_CTRL__FREQMHZ {100} \
   CONFIG.PSU__CRL_APB__CAN0_REF_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRL_APB__CAN1_REF_CTRL__ACT_FREQMHZ {100} \
   CONFIG.PSU__CRL_APB__CAN1_REF_CTRL__DIVISOR0 {15} \
   CONFIG.PSU__CRL_APB__CAN1_REF_CTRL__DIVISOR1 {1} \
   CONFIG.PSU__CRL_APB__CAN1_REF_CTRL__FREQMHZ {100} \
   CONFIG.PSU__CRL_APB__CAN1_REF_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRL_APB__CPU_R5_CTRL__ACT_FREQMHZ {499.994995} \
   CONFIG.PSU__CRL_APB__CPU_R5_CTRL__DIVISOR0 {3} \
   CONFIG.PSU__CRL_APB__CPU_R5_CTRL__FREQMHZ {500} \
   CONFIG.PSU__CRL_APB__CPU_R5_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRL_APB__CSU_PLL_CTRL__ACT_FREQMHZ {180} \
   CONFIG.PSU__CRL_APB__CSU_PLL_CTRL__DIVISOR0 {3} \
   CONFIG.PSU__CRL_APB__CSU_PLL_CTRL__FREQMHZ {180} \
   CONFIG.PSU__CRL_APB__CSU_PLL_CTRL__SRCSEL {SysOsc} \
   CONFIG.PSU__CRL_APB__DBG_LPD_CTRL__ACT_FREQMHZ {249.997498} \
   CONFIG.PSU__CRL_APB__DBG_LPD_CTRL__DIVISOR0 {6} \
   CONFIG.PSU__CRL_APB__DBG_LPD_CTRL__FREQMHZ {250} \
   CONFIG.PSU__CRL_APB__DBG_LPD_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRL_APB__DEBUG_R5_ATCLK_CTRL__ACT_FREQMHZ {1000} \
   CONFIG.PSU__CRL_APB__DEBUG_R5_ATCLK_CTRL__DIVISOR0 {6} \
   CONFIG.PSU__CRL_APB__DEBUG_R5_ATCLK_CTRL__FREQMHZ {1000} \
   CONFIG.PSU__CRL_APB__DEBUG_R5_ATCLK_CTRL__SRCSEL {RPLL} \
   CONFIG.PSU__CRL_APB__DLL_REF_CTRL__ACT_FREQMHZ {1499.984985} \
   CONFIG.PSU__CRL_APB__DLL_REF_CTRL__FREQMHZ {1500} \
   CONFIG.PSU__CRL_APB__DLL_REF_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRL_APB__GEM0_REF_CTRL__ACT_FREQMHZ {125} \
   CONFIG.PSU__CRL_APB__GEM0_REF_CTRL__DIVISOR0 {12} \
   CONFIG.PSU__CRL_APB__GEM0_REF_CTRL__DIVISOR1 {1} \
   CONFIG.PSU__CRL_APB__GEM0_REF_CTRL__FREQMHZ {125} \
   CONFIG.PSU__CRL_APB__GEM0_REF_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRL_APB__GEM1_REF_CTRL__ACT_FREQMHZ {125} \
   CONFIG.PSU__CRL_APB__GEM1_REF_CTRL__DIVISOR0 {12} \
   CONFIG.PSU__CRL_APB__GEM1_REF_CTRL__DIVISOR1 {1} \
   CONFIG.PSU__CRL_APB__GEM1_REF_CTRL__FREQMHZ {125} \
   CONFIG.PSU__CRL_APB__GEM1_REF_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRL_APB__GEM2_REF_CTRL__ACT_FREQMHZ {125} \
   CONFIG.PSU__CRL_APB__GEM2_REF_CTRL__DIVISOR0 {12} \
   CONFIG.PSU__CRL_APB__GEM2_REF_CTRL__DIVISOR1 {1} \
   CONFIG.PSU__CRL_APB__GEM2_REF_CTRL__FREQMHZ {125} \
   CONFIG.PSU__CRL_APB__GEM2_REF_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRL_APB__GEM3_REF_CTRL__ACT_FREQMHZ {124.998749} \
   CONFIG.PSU__CRL_APB__GEM3_REF_CTRL__DIVISOR0 {12} \
   CONFIG.PSU__CRL_APB__GEM3_REF_CTRL__DIVISOR1 {1} \
   CONFIG.PSU__CRL_APB__GEM3_REF_CTRL__FREQMHZ {125} \
   CONFIG.PSU__CRL_APB__GEM3_REF_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRL_APB__GEM_TSU_REF_CTRL__ACT_FREQMHZ {249.997498} \
   CONFIG.PSU__CRL_APB__GEM_TSU_REF_CTRL__DIVISOR0 {6} \
   CONFIG.PSU__CRL_APB__GEM_TSU_REF_CTRL__DIVISOR1 {1} \
   CONFIG.PSU__CRL_APB__GEM_TSU_REF_CTRL__FREQMHZ {250} \
   CONFIG.PSU__CRL_APB__GEM_TSU_REF_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRL_APB__I2C0_REF_CTRL__ACT_FREQMHZ {99.999001} \
   CONFIG.PSU__CRL_APB__I2C0_REF_CTRL__DIVISOR0 {15} \
   CONFIG.PSU__CRL_APB__I2C0_REF_CTRL__DIVISOR1 {1} \
   CONFIG.PSU__CRL_APB__I2C0_REF_CTRL__FREQMHZ {100} \
   CONFIG.PSU__CRL_APB__I2C0_REF_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRL_APB__I2C1_REF_CTRL__ACT_FREQMHZ {99.999001} \
   CONFIG.PSU__CRL_APB__I2C1_REF_CTRL__DIVISOR0 {15} \
   CONFIG.PSU__CRL_APB__I2C1_REF_CTRL__DIVISOR1 {1} \
   CONFIG.PSU__CRL_APB__I2C1_REF_CTRL__FREQMHZ {100} \
   CONFIG.PSU__CRL_APB__I2C1_REF_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRL_APB__IOPLL_CTRL__DIV2 {1} \
   CONFIG.PSU__CRL_APB__IOPLL_CTRL__FBDIV {90} \
   CONFIG.PSU__CRL_APB__IOPLL_CTRL__FRACDATA {0.000000} \
   CONFIG.PSU__CRL_APB__IOPLL_CTRL__FRACFREQ {27.138} \
   CONFIG.PSU__CRL_APB__IOPLL_CTRL__SRCSEL {PSS_REF_CLK} \
   CONFIG.PSU__CRL_APB__IOPLL_FRAC_CFG__ENABLED {0} \
   CONFIG.PSU__CRL_APB__IOPLL_TO_FPD_CTRL__DIVISOR0 {3} \
   CONFIG.PSU__CRL_APB__IOU_SWITCH_CTRL__ACT_FREQMHZ {249.997498} \
   CONFIG.PSU__CRL_APB__IOU_SWITCH_CTRL__DIVISOR0 {6} \
   CONFIG.PSU__CRL_APB__IOU_SWITCH_CTRL__FREQMHZ {250} \
   CONFIG.PSU__CRL_APB__IOU_SWITCH_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRL_APB__LPD_LSBUS_CTRL__ACT_FREQMHZ {99.999001} \
   CONFIG.PSU__CRL_APB__LPD_LSBUS_CTRL__DIVISOR0 {15} \
   CONFIG.PSU__CRL_APB__LPD_LSBUS_CTRL__FREQMHZ {100} \
   CONFIG.PSU__CRL_APB__LPD_LSBUS_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRL_APB__LPD_SWITCH_CTRL__ACT_FREQMHZ {499.994995} \
   CONFIG.PSU__CRL_APB__LPD_SWITCH_CTRL__DIVISOR0 {3} \
   CONFIG.PSU__CRL_APB__LPD_SWITCH_CTRL__FREQMHZ {500} \
   CONFIG.PSU__CRL_APB__LPD_SWITCH_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRL_APB__NAND_REF_CTRL__ACT_FREQMHZ {100} \
   CONFIG.PSU__CRL_APB__NAND_REF_CTRL__DIVISOR0 {15} \
   CONFIG.PSU__CRL_APB__NAND_REF_CTRL__DIVISOR1 {1} \
   CONFIG.PSU__CRL_APB__NAND_REF_CTRL__FREQMHZ {100} \
   CONFIG.PSU__CRL_APB__NAND_REF_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRL_APB__OCM_MAIN_CTRL__ACT_FREQMHZ {500} \
   CONFIG.PSU__CRL_APB__OCM_MAIN_CTRL__DIVISOR0 {3} \
   CONFIG.PSU__CRL_APB__OCM_MAIN_CTRL__FREQMHZ {500} \
   CONFIG.PSU__CRL_APB__OCM_MAIN_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRL_APB__PCAP_CTRL__ACT_FREQMHZ {187.498123} \
   CONFIG.PSU__CRL_APB__PCAP_CTRL__DIVISOR0 {8} \
   CONFIG.PSU__CRL_APB__PCAP_CTRL__FREQMHZ {200} \
   CONFIG.PSU__CRL_APB__PCAP_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRL_APB__PL0_REF_CTRL__ACT_FREQMHZ {99.999001} \
   CONFIG.PSU__CRL_APB__PL0_REF_CTRL__DIVISOR0 {15} \
   CONFIG.PSU__CRL_APB__PL0_REF_CTRL__DIVISOR1 {1} \
   CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ {100} \
   CONFIG.PSU__CRL_APB__PL0_REF_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRL_APB__PL1_REF_CTRL__ACT_FREQMHZ {1.999980} \
   CONFIG.PSU__CRL_APB__PL1_REF_CTRL__DIVISOR0 {50} \
   CONFIG.PSU__CRL_APB__PL1_REF_CTRL__DIVISOR1 {15} \
   CONFIG.PSU__CRL_APB__PL1_REF_CTRL__FREQMHZ {2} \
   CONFIG.PSU__CRL_APB__PL1_REF_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRL_APB__PL2_REF_CTRL__ACT_FREQMHZ {100} \
   CONFIG.PSU__CRL_APB__PL2_REF_CTRL__DIVISOR0 {4} \
   CONFIG.PSU__CRL_APB__PL2_REF_CTRL__DIVISOR1 {1} \
   CONFIG.PSU__CRL_APB__PL2_REF_CTRL__FREQMHZ {100} \
   CONFIG.PSU__CRL_APB__PL2_REF_CTRL__SRCSEL {RPLL} \
   CONFIG.PSU__CRL_APB__PL3_REF_CTRL__ACT_FREQMHZ {100} \
   CONFIG.PSU__CRL_APB__PL3_REF_CTRL__DIVISOR0 {4} \
   CONFIG.PSU__CRL_APB__PL3_REF_CTRL__DIVISOR1 {1} \
   CONFIG.PSU__CRL_APB__PL3_REF_CTRL__FREQMHZ {100} \
   CONFIG.PSU__CRL_APB__PL3_REF_CTRL__SRCSEL {RPLL} \
   CONFIG.PSU__CRL_APB__QSPI_REF_CTRL__ACT_FREQMHZ {124.998749} \
   CONFIG.PSU__CRL_APB__QSPI_REF_CTRL__DIVISOR0 {12} \
   CONFIG.PSU__CRL_APB__QSPI_REF_CTRL__DIVISOR1 {1} \
   CONFIG.PSU__CRL_APB__QSPI_REF_CTRL__FREQMHZ {125} \
   CONFIG.PSU__CRL_APB__QSPI_REF_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRL_APB__RPLL_CTRL__DIV2 {1} \
   CONFIG.PSU__CRL_APB__RPLL_CTRL__FBDIV {45} \
   CONFIG.PSU__CRL_APB__RPLL_CTRL__FRACDATA {0.000000} \
   CONFIG.PSU__CRL_APB__RPLL_CTRL__FRACFREQ {27.138} \
   CONFIG.PSU__CRL_APB__RPLL_CTRL__SRCSEL {PSS_REF_CLK} \
   CONFIG.PSU__CRL_APB__RPLL_FRAC_CFG__ENABLED {0} \
   CONFIG.PSU__CRL_APB__RPLL_TO_FPD_CTRL__DIVISOR0 {2} \
   CONFIG.PSU__CRL_APB__SDIO0_REF_CTRL__ACT_FREQMHZ {200} \
   CONFIG.PSU__CRL_APB__SDIO0_REF_CTRL__DIVISOR0 {7} \
   CONFIG.PSU__CRL_APB__SDIO0_REF_CTRL__DIVISOR1 {1} \
   CONFIG.PSU__CRL_APB__SDIO0_REF_CTRL__FREQMHZ {200} \
   CONFIG.PSU__CRL_APB__SDIO0_REF_CTRL__SRCSEL {RPLL} \
   CONFIG.PSU__CRL_APB__SDIO1_REF_CTRL__ACT_FREQMHZ {187.498123} \
   CONFIG.PSU__CRL_APB__SDIO1_REF_CTRL__DIVISOR0 {8} \
   CONFIG.PSU__CRL_APB__SDIO1_REF_CTRL__DIVISOR1 {1} \
   CONFIG.PSU__CRL_APB__SDIO1_REF_CTRL__FREQMHZ {200} \
   CONFIG.PSU__CRL_APB__SDIO1_REF_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRL_APB__SPI0_REF_CTRL__ACT_FREQMHZ {214} \
   CONFIG.PSU__CRL_APB__SPI0_REF_CTRL__DIVISOR0 {7} \
   CONFIG.PSU__CRL_APB__SPI0_REF_CTRL__DIVISOR1 {1} \
   CONFIG.PSU__CRL_APB__SPI0_REF_CTRL__FREQMHZ {200} \
   CONFIG.PSU__CRL_APB__SPI0_REF_CTRL__SRCSEL {RPLL} \
   CONFIG.PSU__CRL_APB__SPI1_REF_CTRL__ACT_FREQMHZ {214} \
   CONFIG.PSU__CRL_APB__SPI1_REF_CTRL__DIVISOR0 {7} \
   CONFIG.PSU__CRL_APB__SPI1_REF_CTRL__DIVISOR1 {1} \
   CONFIG.PSU__CRL_APB__SPI1_REF_CTRL__FREQMHZ {200} \
   CONFIG.PSU__CRL_APB__SPI1_REF_CTRL__SRCSEL {RPLL} \
   CONFIG.PSU__CRL_APB__TIMESTAMP_REF_CTRL__ACT_FREQMHZ {99.999001} \
   CONFIG.PSU__CRL_APB__TIMESTAMP_REF_CTRL__DIVISOR0 {15} \
   CONFIG.PSU__CRL_APB__TIMESTAMP_REF_CTRL__FREQMHZ {100} \
   CONFIG.PSU__CRL_APB__TIMESTAMP_REF_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRL_APB__UART0_REF_CTRL__ACT_FREQMHZ {99.999001} \
   CONFIG.PSU__CRL_APB__UART0_REF_CTRL__DIVISOR0 {15} \
   CONFIG.PSU__CRL_APB__UART0_REF_CTRL__DIVISOR1 {1} \
   CONFIG.PSU__CRL_APB__UART0_REF_CTRL__FREQMHZ {100} \
   CONFIG.PSU__CRL_APB__UART0_REF_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRL_APB__UART1_REF_CTRL__ACT_FREQMHZ {99.999001} \
   CONFIG.PSU__CRL_APB__UART1_REF_CTRL__DIVISOR0 {15} \
   CONFIG.PSU__CRL_APB__UART1_REF_CTRL__DIVISOR1 {1} \
   CONFIG.PSU__CRL_APB__UART1_REF_CTRL__FREQMHZ {100} \
   CONFIG.PSU__CRL_APB__UART1_REF_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRL_APB__USB0_BUS_REF_CTRL__ACT_FREQMHZ {249.997498} \
   CONFIG.PSU__CRL_APB__USB0_BUS_REF_CTRL__DIVISOR0 {6} \
   CONFIG.PSU__CRL_APB__USB0_BUS_REF_CTRL__DIVISOR1 {1} \
   CONFIG.PSU__CRL_APB__USB0_BUS_REF_CTRL__FREQMHZ {250} \
   CONFIG.PSU__CRL_APB__USB0_BUS_REF_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRL_APB__USB1_BUS_REF_CTRL__ACT_FREQMHZ {250} \
   CONFIG.PSU__CRL_APB__USB1_BUS_REF_CTRL__DIVISOR0 {6} \
   CONFIG.PSU__CRL_APB__USB1_BUS_REF_CTRL__DIVISOR1 {1} \
   CONFIG.PSU__CRL_APB__USB1_BUS_REF_CTRL__FREQMHZ {250} \
   CONFIG.PSU__CRL_APB__USB1_BUS_REF_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRL_APB__USB3_DUAL_REF_CTRL__ACT_FREQMHZ {19.999800} \
   CONFIG.PSU__CRL_APB__USB3_DUAL_REF_CTRL__DIVISOR0 {25} \
   CONFIG.PSU__CRL_APB__USB3_DUAL_REF_CTRL__DIVISOR1 {3} \
   CONFIG.PSU__CRL_APB__USB3_DUAL_REF_CTRL__FREQMHZ {20} \
   CONFIG.PSU__CRL_APB__USB3_DUAL_REF_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRL_APB__USB3__ENABLE {1} \
   CONFIG.PSU__CSUPMU__PERIPHERAL__VALID {1} \
   CONFIG.PSU__CSU_COHERENCY {0} \
   CONFIG.PSU__CSU__CSU_TAMPER_0__ENABLE {0} \
   CONFIG.PSU__CSU__CSU_TAMPER_0__ERASE_BBRAM {0} \
   CONFIG.PSU__CSU__CSU_TAMPER_10__ENABLE {0} \
   CONFIG.PSU__CSU__CSU_TAMPER_10__ERASE_BBRAM {0} \
   CONFIG.PSU__CSU__CSU_TAMPER_11__ENABLE {0} \
   CONFIG.PSU__CSU__CSU_TAMPER_11__ERASE_BBRAM {0} \
   CONFIG.PSU__CSU__CSU_TAMPER_12__ENABLE {0} \
   CONFIG.PSU__CSU__CSU_TAMPER_12__ERASE_BBRAM {0} \
   CONFIG.PSU__CSU__CSU_TAMPER_1__ENABLE {0} \
   CONFIG.PSU__CSU__CSU_TAMPER_1__ERASE_BBRAM {0} \
   CONFIG.PSU__CSU__CSU_TAMPER_2__ENABLE {0} \
   CONFIG.PSU__CSU__CSU_TAMPER_2__ERASE_BBRAM {0} \
   CONFIG.PSU__CSU__CSU_TAMPER_3__ENABLE {0} \
   CONFIG.PSU__CSU__CSU_TAMPER_3__ERASE_BBRAM {0} \
   CONFIG.PSU__CSU__CSU_TAMPER_4__ENABLE {0} \
   CONFIG.PSU__CSU__CSU_TAMPER_4__ERASE_BBRAM {0} \
   CONFIG.PSU__CSU__CSU_TAMPER_5__ENABLE {0} \
   CONFIG.PSU__CSU__CSU_TAMPER_5__ERASE_BBRAM {0} \
   CONFIG.PSU__CSU__CSU_TAMPER_6__ENABLE {0} \
   CONFIG.PSU__CSU__CSU_TAMPER_6__ERASE_BBRAM {0} \
   CONFIG.PSU__CSU__CSU_TAMPER_7__ENABLE {0} \
   CONFIG.PSU__CSU__CSU_TAMPER_7__ERASE_BBRAM {0} \
   CONFIG.PSU__CSU__CSU_TAMPER_8__ENABLE {0} \
   CONFIG.PSU__CSU__CSU_TAMPER_8__ERASE_BBRAM {0} \
   CONFIG.PSU__CSU__CSU_TAMPER_9__ENABLE {0} \
   CONFIG.PSU__CSU__CSU_TAMPER_9__ERASE_BBRAM {0} \
   CONFIG.PSU__CSU__PERIPHERAL__ENABLE {0} \
   CONFIG.PSU__DDRC__ADDR_MIRROR {0} \
   CONFIG.PSU__DDRC__AL {0} \
   CONFIG.PSU__DDRC__BANK_ADDR_COUNT {2} \
   CONFIG.PSU__DDRC__BG_ADDR_COUNT {1} \
   CONFIG.PSU__DDRC__BRC_MAPPING {ROW_BANK_COL} \
   CONFIG.PSU__DDRC__BUS_WIDTH {64 Bit} \
   CONFIG.PSU__DDRC__CL {15} \
   CONFIG.PSU__DDRC__CLOCK_STOP_EN {0} \
   CONFIG.PSU__DDRC__COL_ADDR_COUNT {10} \
   CONFIG.PSU__DDRC__COMPONENTS {UDIMM} \
   CONFIG.PSU__DDRC__CWL {14} \
   CONFIG.PSU__DDRC__DDR3L_T_REF_RANGE {NA} \
   CONFIG.PSU__DDRC__DDR3_T_REF_RANGE {NA} \
   CONFIG.PSU__DDRC__DDR4_ADDR_MAPPING {0} \
   CONFIG.PSU__DDRC__DDR4_CAL_MODE_ENABLE {0} \
   CONFIG.PSU__DDRC__DDR4_CRC_CONTROL {0} \
   CONFIG.PSU__DDRC__DDR4_MAXPWR_SAVING_EN {0} \
   CONFIG.PSU__DDRC__DDR4_T_REF_MODE {0} \
   CONFIG.PSU__DDRC__DDR4_T_REF_RANGE {Normal (0-85)} \
   CONFIG.PSU__DDRC__DEEP_PWR_DOWN_EN {0} \
   CONFIG.PSU__DDRC__DEVICE_CAPACITY {8192 MBits} \
   CONFIG.PSU__DDRC__DIMM_ADDR_MIRROR {0} \
   CONFIG.PSU__DDRC__DM_DBI {DM_NO_DBI} \
   CONFIG.PSU__DDRC__DQMAP_0_3 {0} \
   CONFIG.PSU__DDRC__DQMAP_12_15 {0} \
   CONFIG.PSU__DDRC__DQMAP_16_19 {0} \
   CONFIG.PSU__DDRC__DQMAP_20_23 {0} \
   CONFIG.PSU__DDRC__DQMAP_24_27 {0} \
   CONFIG.PSU__DDRC__DQMAP_28_31 {0} \
   CONFIG.PSU__DDRC__DQMAP_32_35 {0} \
   CONFIG.PSU__DDRC__DQMAP_36_39 {0} \
   CONFIG.PSU__DDRC__DQMAP_40_43 {0} \
   CONFIG.PSU__DDRC__DQMAP_44_47 {0} \
   CONFIG.PSU__DDRC__DQMAP_48_51 {0} \
   CONFIG.PSU__DDRC__DQMAP_4_7 {0} \
   CONFIG.PSU__DDRC__DQMAP_52_55 {0} \
   CONFIG.PSU__DDRC__DQMAP_56_59 {0} \
   CONFIG.PSU__DDRC__DQMAP_60_63 {0} \
   CONFIG.PSU__DDRC__DQMAP_64_67 {0} \
   CONFIG.PSU__DDRC__DQMAP_68_71 {0} \
   CONFIG.PSU__DDRC__DQMAP_8_11 {0} \
   CONFIG.PSU__DDRC__DRAM_WIDTH {16 Bits} \
   CONFIG.PSU__DDRC__ECC {Disabled} \
   CONFIG.PSU__DDRC__ECC_SCRUB {0} \
   CONFIG.PSU__DDRC__ENABLE {1} \
   CONFIG.PSU__DDRC__ENABLE_2T_TIMING {0} \
   CONFIG.PSU__DDRC__ENABLE_DP_SWITCH {0} \
   CONFIG.PSU__DDRC__ENABLE_LP4_HAS_ECC_COMP {0} \
   CONFIG.PSU__DDRC__ENABLE_LP4_SLOWBOOT {0} \
   CONFIG.PSU__DDRC__EN_2ND_CLK {0} \
   CONFIG.PSU__DDRC__FGRM {1X} \
   CONFIG.PSU__DDRC__FREQ_MHZ {1} \
   CONFIG.PSU__DDRC__LPDDR3_DUALRANK_SDP {0} \
   CONFIG.PSU__DDRC__LPDDR3_T_REF_RANGE {NA} \
   CONFIG.PSU__DDRC__LPDDR4_T_REF_RANGE {NA} \
   CONFIG.PSU__DDRC__LP_ASR {manual normal} \
   CONFIG.PSU__DDRC__MEMORY_TYPE {DDR 4} \
   CONFIG.PSU__DDRC__PARITY_ENABLE {0} \
   CONFIG.PSU__DDRC__PER_BANK_REFRESH {0} \
   CONFIG.PSU__DDRC__PHY_DBI_MODE {0} \
   CONFIG.PSU__DDRC__PLL_BYPASS {0} \
   CONFIG.PSU__DDRC__PWR_DOWN_EN {0} \
   CONFIG.PSU__DDRC__RANK_ADDR_COUNT {0} \
   CONFIG.PSU__DDRC__RD_DQS_CENTER {0} \
   CONFIG.PSU__DDRC__ROW_ADDR_COUNT {16} \
   CONFIG.PSU__DDRC__SB_TARGET {15-15-15} \
   CONFIG.PSU__DDRC__SELF_REF_ABORT {0} \
   CONFIG.PSU__DDRC__SPEED_BIN {DDR4_2133P} \
   CONFIG.PSU__DDRC__STATIC_RD_MODE {0} \
   CONFIG.PSU__DDRC__TRAIN_DATA_EYE {1} \
   CONFIG.PSU__DDRC__TRAIN_READ_GATE {1} \
   CONFIG.PSU__DDRC__TRAIN_WRITE_LEVEL {1} \
   CONFIG.PSU__DDRC__T_FAW {30.0} \
   CONFIG.PSU__DDRC__T_RAS_MIN {33} \
   CONFIG.PSU__DDRC__T_RC {47.06} \
   CONFIG.PSU__DDRC__T_RCD {15} \
   CONFIG.PSU__DDRC__T_RP {15} \
   CONFIG.PSU__DDRC__VENDOR_PART {OTHERS} \
   CONFIG.PSU__DDRC__VIDEO_BUFFER_SIZE {0} \
   CONFIG.PSU__DDRC__VREF {1} \
   CONFIG.PSU__DDR_HIGH_ADDRESS_GUI_ENABLE {1} \
   CONFIG.PSU__DDR_QOS_ENABLE {0} \
   CONFIG.PSU__DDR_QOS_FIX_HP0_RDQOS {} \
   CONFIG.PSU__DDR_QOS_FIX_HP0_WRQOS {} \
   CONFIG.PSU__DDR_QOS_FIX_HP1_RDQOS {} \
   CONFIG.PSU__DDR_QOS_FIX_HP1_WRQOS {} \
   CONFIG.PSU__DDR_QOS_FIX_HP2_RDQOS {} \
   CONFIG.PSU__DDR_QOS_FIX_HP2_WRQOS {} \
   CONFIG.PSU__DDR_QOS_FIX_HP3_RDQOS {} \
   CONFIG.PSU__DDR_QOS_FIX_HP3_WRQOS {} \
   CONFIG.PSU__DDR_QOS_HP0_RDQOS {} \
   CONFIG.PSU__DDR_QOS_HP0_WRQOS {} \
   CONFIG.PSU__DDR_QOS_HP1_RDQOS {} \
   CONFIG.PSU__DDR_QOS_HP1_WRQOS {} \
   CONFIG.PSU__DDR_QOS_HP2_RDQOS {} \
   CONFIG.PSU__DDR_QOS_HP2_WRQOS {} \
   CONFIG.PSU__DDR_QOS_HP3_RDQOS {} \
   CONFIG.PSU__DDR_QOS_HP3_WRQOS {} \
   CONFIG.PSU__DDR_QOS_RD_HPR_THRSHLD {} \
   CONFIG.PSU__DDR_QOS_RD_LPR_THRSHLD {} \
   CONFIG.PSU__DDR_QOS_WR_THRSHLD {} \
   CONFIG.PSU__DDR_SW_REFRESH_ENABLED {1} \
   CONFIG.PSU__DDR__INTERFACE__FREQMHZ {533.500} \
   CONFIG.PSU__DEVICE_TYPE {RFSOC} \
   CONFIG.PSU__DISPLAYPORT__LANE0__ENABLE {1} \
   CONFIG.PSU__DISPLAYPORT__LANE0__IO {GT Lane1} \
   CONFIG.PSU__DISPLAYPORT__LANE1__ENABLE {1} \
   CONFIG.PSU__DISPLAYPORT__LANE1__IO {GT Lane0} \
   CONFIG.PSU__DISPLAYPORT__PERIPHERAL__ENABLE {1} \
   CONFIG.PSU__DLL__ISUSED {1} \
   CONFIG.PSU__DPAUX__PERIPHERAL__ENABLE {1} \
   CONFIG.PSU__DPAUX__PERIPHERAL__IO {MIO 27 .. 30} \
   CONFIG.PSU__DP__LANE_SEL {Dual Lower} \
   CONFIG.PSU__DP__REF_CLK_FREQ {27} \
   CONFIG.PSU__DP__REF_CLK_SEL {Ref Clk1} \
   CONFIG.PSU__ENABLE__DDR__REFRESH__SIGNALS {0} \
   CONFIG.PSU__ENET0__FIFO__ENABLE {0} \
   CONFIG.PSU__ENET0__GRP_MDIO__ENABLE {0} \
   CONFIG.PSU__ENET0__PERIPHERAL__ENABLE {0} \
   CONFIG.PSU__ENET0__PTP__ENABLE {0} \
   CONFIG.PSU__ENET0__TSU__ENABLE {0} \
   CONFIG.PSU__ENET1__FIFO__ENABLE {0} \
   CONFIG.PSU__ENET1__GRP_MDIO__ENABLE {0} \
   CONFIG.PSU__ENET1__PERIPHERAL__ENABLE {0} \
   CONFIG.PSU__ENET1__PTP__ENABLE {0} \
   CONFIG.PSU__ENET1__TSU__ENABLE {0} \
   CONFIG.PSU__ENET2__FIFO__ENABLE {0} \
   CONFIG.PSU__ENET2__GRP_MDIO__ENABLE {0} \
   CONFIG.PSU__ENET2__PERIPHERAL__ENABLE {0} \
   CONFIG.PSU__ENET2__PTP__ENABLE {0} \
   CONFIG.PSU__ENET2__TSU__ENABLE {0} \
   CONFIG.PSU__ENET3__FIFO__ENABLE {0} \
   CONFIG.PSU__ENET3__GRP_MDIO__ENABLE {1} \
   CONFIG.PSU__ENET3__GRP_MDIO__IO {MIO 76 .. 77} \
   CONFIG.PSU__ENET3__PERIPHERAL__ENABLE {1} \
   CONFIG.PSU__ENET3__PERIPHERAL__IO {MIO 64 .. 75} \
   CONFIG.PSU__ENET3__PTP__ENABLE {0} \
   CONFIG.PSU__ENET3__TSU__ENABLE {0} \
   CONFIG.PSU__EN_AXI_STATUS_PORTS {0} \
   CONFIG.PSU__EN_EMIO_TRACE {0} \
   CONFIG.PSU__EP__IP {0} \
   CONFIG.PSU__EXPAND__CORESIGHT {0} \
   CONFIG.PSU__EXPAND__FPD_SLAVES {0} \
   CONFIG.PSU__EXPAND__GIC {0} \
   CONFIG.PSU__EXPAND__LOWER_LPS_SLAVES {0} \
   CONFIG.PSU__EXPAND__UPPER_LPS_SLAVES {0} \
   CONFIG.PSU__FPDMASTERS_COHERENCY {0} \
   CONFIG.PSU__FPD_SLCR__WDT1__ACT_FREQMHZ {99.999001} \
   CONFIG.PSU__FPD_SLCR__WDT1__FREQMHZ {99.999001} \
   CONFIG.PSU__FPD_SLCR__WDT_CLK_SEL__SELECT {APB} \
   CONFIG.PSU__FPGA_PL0_ENABLE {1} \
   CONFIG.PSU__FPGA_PL1_ENABLE {1} \
   CONFIG.PSU__FPGA_PL2_ENABLE {0} \
   CONFIG.PSU__FPGA_PL3_ENABLE {0} \
   CONFIG.PSU__FP__POWER__ON {1} \
   CONFIG.PSU__FTM__CTI_IN_0 {0} \
   CONFIG.PSU__FTM__CTI_IN_1 {0} \
   CONFIG.PSU__FTM__CTI_IN_2 {0} \
   CONFIG.PSU__FTM__CTI_IN_3 {0} \
   CONFIG.PSU__FTM__CTI_OUT_0 {0} \
   CONFIG.PSU__FTM__CTI_OUT_1 {0} \
   CONFIG.PSU__FTM__CTI_OUT_2 {0} \
   CONFIG.PSU__FTM__CTI_OUT_3 {0} \
   CONFIG.PSU__FTM__GPI {0} \
   CONFIG.PSU__FTM__GPO {0} \
   CONFIG.PSU__GEM0_COHERENCY {0} \
   CONFIG.PSU__GEM0_ROUTE_THROUGH_FPD {0} \
   CONFIG.PSU__GEM1_COHERENCY {0} \
   CONFIG.PSU__GEM1_ROUTE_THROUGH_FPD {0} \
   CONFIG.PSU__GEM2_COHERENCY {0} \
   CONFIG.PSU__GEM2_ROUTE_THROUGH_FPD {0} \
   CONFIG.PSU__GEM3_COHERENCY {0} \
   CONFIG.PSU__GEM3_ROUTE_THROUGH_FPD {0} \
   CONFIG.PSU__GEM__TSU__ENABLE {0} \
   CONFIG.PSU__GEN_IPI_0__MASTER {APU} \
   CONFIG.PSU__GEN_IPI_10__MASTER {NONE} \
   CONFIG.PSU__GEN_IPI_1__MASTER {RPU0} \
   CONFIG.PSU__GEN_IPI_2__MASTER {RPU1} \
   CONFIG.PSU__GEN_IPI_3__MASTER {PMU} \
   CONFIG.PSU__GEN_IPI_4__MASTER {PMU} \
   CONFIG.PSU__GEN_IPI_5__MASTER {PMU} \
   CONFIG.PSU__GEN_IPI_6__MASTER {PMU} \
   CONFIG.PSU__GEN_IPI_7__MASTER {NONE} \
   CONFIG.PSU__GEN_IPI_8__MASTER {NONE} \
   CONFIG.PSU__GEN_IPI_9__MASTER {NONE} \
   CONFIG.PSU__GPIO0_MIO__IO {MIO 0 .. 25} \
   CONFIG.PSU__GPIO0_MIO__PERIPHERAL__ENABLE {1} \
   CONFIG.PSU__GPIO1_MIO__IO {MIO 26 .. 51} \
   CONFIG.PSU__GPIO1_MIO__PERIPHERAL__ENABLE {1} \
   CONFIG.PSU__GPIO2_MIO__PERIPHERAL__ENABLE {0} \
   CONFIG.PSU__GPIO_EMIO_WIDTH {1} \
   CONFIG.PSU__GPIO_EMIO__PERIPHERAL__ENABLE {0} \
   CONFIG.PSU__GPIO_EMIO__PERIPHERAL__IO {<Select>} \
   CONFIG.PSU__GPIO_EMIO__WIDTH {[94:0]} \
   CONFIG.PSU__GPU_PP0__POWER__ON {0} \
   CONFIG.PSU__GPU_PP1__POWER__ON {0} \
   CONFIG.PSU__GT_REF_CLK__FREQMHZ {33.333} \
   CONFIG.PSU__GT__LINK_SPEED {HBR} \
   CONFIG.PSU__GT__PRE_EMPH_LVL_4 {0} \
   CONFIG.PSU__GT__VLT_SWNG_LVL_4 {0} \
   CONFIG.PSU__HIGH_ADDRESS__ENABLE {1} \
   CONFIG.PSU__HPM0_FPD__NUM_READ_THREADS {4} \
   CONFIG.PSU__HPM0_FPD__NUM_WRITE_THREADS {4} \
   CONFIG.PSU__HPM0_LPD__NUM_READ_THREADS {4} \
   CONFIG.PSU__HPM0_LPD__NUM_WRITE_THREADS {4} \
   CONFIG.PSU__HPM1_FPD__NUM_READ_THREADS {4} \
   CONFIG.PSU__HPM1_FPD__NUM_WRITE_THREADS {4} \
   CONFIG.PSU__I2C0_LOOP_I2C1__ENABLE {0} \
   CONFIG.PSU__I2C0__GRP_INT__ENABLE {0} \
   CONFIG.PSU__I2C0__PERIPHERAL__ENABLE {1} \
   CONFIG.PSU__I2C0__PERIPHERAL__IO {MIO 14 .. 15} \
   CONFIG.PSU__I2C1__GRP_INT__ENABLE {0} \
   CONFIG.PSU__I2C1__PERIPHERAL__ENABLE {1} \
   CONFIG.PSU__I2C1__PERIPHERAL__IO {MIO 16 .. 17} \
   CONFIG.PSU__IOU_SLCR__IOU_TTC_APB_CLK__TTC0_SEL {APB} \
   CONFIG.PSU__IOU_SLCR__IOU_TTC_APB_CLK__TTC1_SEL {APB} \
   CONFIG.PSU__IOU_SLCR__IOU_TTC_APB_CLK__TTC2_SEL {APB} \
   CONFIG.PSU__IOU_SLCR__IOU_TTC_APB_CLK__TTC3_SEL {APB} \
   CONFIG.PSU__IOU_SLCR__TTC0__ACT_FREQMHZ {100.000000} \
   CONFIG.PSU__IOU_SLCR__TTC0__FREQMHZ {100.000000} \
   CONFIG.PSU__IOU_SLCR__TTC1__ACT_FREQMHZ {100.000000} \
   CONFIG.PSU__IOU_SLCR__TTC1__FREQMHZ {100.000000} \
   CONFIG.PSU__IOU_SLCR__TTC2__ACT_FREQMHZ {100.000000} \
   CONFIG.PSU__IOU_SLCR__TTC2__FREQMHZ {100.000000} \
   CONFIG.PSU__IOU_SLCR__TTC3__ACT_FREQMHZ {100.000000} \
   CONFIG.PSU__IOU_SLCR__TTC3__FREQMHZ {100.000000} \
   CONFIG.PSU__IOU_SLCR__WDT0__ACT_FREQMHZ {99.999001} \
   CONFIG.PSU__IOU_SLCR__WDT0__FREQMHZ {99.999001} \
   CONFIG.PSU__IOU_SLCR__WDT_CLK_SEL__SELECT {APB} \
   CONFIG.PSU__IRQ_P2F_ADMA_CHAN__INT {0} \
   CONFIG.PSU__IRQ_P2F_AIB_AXI__INT {0} \
   CONFIG.PSU__IRQ_P2F_AMS__INT {0} \
   CONFIG.PSU__IRQ_P2F_APM_FPD__INT {0} \
   CONFIG.PSU__IRQ_P2F_APU_COMM__INT {0} \
   CONFIG.PSU__IRQ_P2F_APU_CPUMNT__INT {0} \
   CONFIG.PSU__IRQ_P2F_APU_CTI__INT {0} \
   CONFIG.PSU__IRQ_P2F_APU_EXTERR__INT {0} \
   CONFIG.PSU__IRQ_P2F_APU_IPI__INT {0} \
   CONFIG.PSU__IRQ_P2F_APU_L2ERR__INT {0} \
   CONFIG.PSU__IRQ_P2F_APU_PMU__INT {0} \
   CONFIG.PSU__IRQ_P2F_APU_REGS__INT {0} \
   CONFIG.PSU__IRQ_P2F_ATB_LPD__INT {0} \
   CONFIG.PSU__IRQ_P2F_CAN0__INT {0} \
   CONFIG.PSU__IRQ_P2F_CAN1__INT {0} \
   CONFIG.PSU__IRQ_P2F_CLKMON__INT {0} \
   CONFIG.PSU__IRQ_P2F_CSUPMU_WDT__INT {0} \
   CONFIG.PSU__IRQ_P2F_CSU_DMA__INT {0} \
   CONFIG.PSU__IRQ_P2F_CSU__INT {0} \
   CONFIG.PSU__IRQ_P2F_DDR_SS__INT {0} \
   CONFIG.PSU__IRQ_P2F_DPDMA__INT {0} \
   CONFIG.PSU__IRQ_P2F_DPORT__INT {0} \
   CONFIG.PSU__IRQ_P2F_EFUSE__INT {0} \
   CONFIG.PSU__IRQ_P2F_ENT0_WAKEUP__INT {0} \
   CONFIG.PSU__IRQ_P2F_ENT0__INT {0} \
   CONFIG.PSU__IRQ_P2F_ENT1_WAKEUP__INT {0} \
   CONFIG.PSU__IRQ_P2F_ENT1__INT {0} \
   CONFIG.PSU__IRQ_P2F_ENT2_WAKEUP__INT {0} \
   CONFIG.PSU__IRQ_P2F_ENT2__INT {0} \
   CONFIG.PSU__IRQ_P2F_ENT3_WAKEUP__INT {0} \
   CONFIG.PSU__IRQ_P2F_ENT3__INT {0} \
   CONFIG.PSU__IRQ_P2F_FPD_APB__INT {0} \
   CONFIG.PSU__IRQ_P2F_FPD_ATB_ERR__INT {0} \
   CONFIG.PSU__IRQ_P2F_FP_WDT__INT {0} \
   CONFIG.PSU__IRQ_P2F_GDMA_CHAN__INT {0} \
   CONFIG.PSU__IRQ_P2F_GPIO__INT {0} \
   CONFIG.PSU__IRQ_P2F_GPU__INT {0} \
   CONFIG.PSU__IRQ_P2F_I2C0__INT {0} \
   CONFIG.PSU__IRQ_P2F_I2C1__INT {0} \
   CONFIG.PSU__IRQ_P2F_LPD_APB__INT {0} \
   CONFIG.PSU__IRQ_P2F_LPD_APM__INT {0} \
   CONFIG.PSU__IRQ_P2F_LP_WDT__INT {0} \
   CONFIG.PSU__IRQ_P2F_NAND__INT {0} \
   CONFIG.PSU__IRQ_P2F_OCM_ERR__INT {0} \
   CONFIG.PSU__IRQ_P2F_PCIE_DMA__INT {0} \
   CONFIG.PSU__IRQ_P2F_PCIE_LEGACY__INT {0} \
   CONFIG.PSU__IRQ_P2F_PCIE_MSC__INT {0} \
   CONFIG.PSU__IRQ_P2F_PCIE_MSI__INT {0} \
   CONFIG.PSU__IRQ_P2F_PL_IPI__INT {0} \
   CONFIG.PSU__IRQ_P2F_QSPI__INT {0} \
   CONFIG.PSU__IRQ_P2F_R5_CORE0_ECC_ERR__INT {0} \
   CONFIG.PSU__IRQ_P2F_R5_CORE1_ECC_ERR__INT {0} \
   CONFIG.PSU__IRQ_P2F_RPU_IPI__INT {0} \
   CONFIG.PSU__IRQ_P2F_RPU_PERMON__INT {0} \
   CONFIG.PSU__IRQ_P2F_RTC_ALARM__INT {0} \
   CONFIG.PSU__IRQ_P2F_RTC_SECONDS__INT {0} \
   CONFIG.PSU__IRQ_P2F_SATA__INT {0} \
   CONFIG.PSU__IRQ_P2F_SDIO0_WAKE__INT {0} \
   CONFIG.PSU__IRQ_P2F_SDIO0__INT {0} \
   CONFIG.PSU__IRQ_P2F_SDIO1_WAKE__INT {0} \
   CONFIG.PSU__IRQ_P2F_SDIO1__INT {0} \
   CONFIG.PSU__IRQ_P2F_SPI0__INT {0} \
   CONFIG.PSU__IRQ_P2F_SPI1__INT {0} \
   CONFIG.PSU__IRQ_P2F_TTC0__INT0 {0} \
   CONFIG.PSU__IRQ_P2F_TTC0__INT1 {0} \
   CONFIG.PSU__IRQ_P2F_TTC0__INT2 {0} \
   CONFIG.PSU__IRQ_P2F_TTC1__INT0 {0} \
   CONFIG.PSU__IRQ_P2F_TTC1__INT1 {0} \
   CONFIG.PSU__IRQ_P2F_TTC1__INT2 {0} \
   CONFIG.PSU__IRQ_P2F_TTC2__INT0 {0} \
   CONFIG.PSU__IRQ_P2F_TTC2__INT1 {0} \
   CONFIG.PSU__IRQ_P2F_TTC2__INT2 {0} \
   CONFIG.PSU__IRQ_P2F_TTC3__INT0 {0} \
   CONFIG.PSU__IRQ_P2F_TTC3__INT1 {0} \
   CONFIG.PSU__IRQ_P2F_TTC3__INT2 {0} \
   CONFIG.PSU__IRQ_P2F_UART0__INT {0} \
   CONFIG.PSU__IRQ_P2F_UART1__INT {0} \
   CONFIG.PSU__IRQ_P2F_USB3_ENDPOINT__INT0 {0} \
   CONFIG.PSU__IRQ_P2F_USB3_ENDPOINT__INT1 {0} \
   CONFIG.PSU__IRQ_P2F_USB3_OTG__INT0 {0} \
   CONFIG.PSU__IRQ_P2F_USB3_OTG__INT1 {0} \
   CONFIG.PSU__IRQ_P2F_USB3_PMU_WAKEUP__INT {0} \
   CONFIG.PSU__IRQ_P2F_XMPU_FPD__INT {0} \
   CONFIG.PSU__IRQ_P2F_XMPU_LPD__INT {0} \
   CONFIG.PSU__IRQ_P2F__INTF_FPD_SMMU__INT {0} \
   CONFIG.PSU__IRQ_P2F__INTF_PPD_CCI__INT {0} \
   CONFIG.PSU__L2_BANK0__POWER__ON {1} \
   CONFIG.PSU__LPDMA0_COHERENCY {0} \
   CONFIG.PSU__LPDMA1_COHERENCY {0} \
   CONFIG.PSU__LPDMA2_COHERENCY {0} \
   CONFIG.PSU__LPDMA3_COHERENCY {0} \
   CONFIG.PSU__LPDMA4_COHERENCY {0} \
   CONFIG.PSU__LPDMA5_COHERENCY {0} \
   CONFIG.PSU__LPDMA6_COHERENCY {0} \
   CONFIG.PSU__LPDMA7_COHERENCY {0} \
   CONFIG.PSU__LPD_SLCR__CSUPMU_WDT_CLK_SEL__SELECT {APB} \
   CONFIG.PSU__LPD_SLCR__CSUPMU__ACT_FREQMHZ {100.000000} \
   CONFIG.PSU__LPD_SLCR__CSUPMU__FREQMHZ {100.000000} \
   CONFIG.PSU__MAXIGP0__DATA_WIDTH {128} \
   CONFIG.PSU__MAXIGP1__DATA_WIDTH {128} \
   CONFIG.PSU__MAXIGP2__DATA_WIDTH {32} \
   CONFIG.PSU__M_AXI_GP0_SUPPORTS_NARROW_BURST {1} \
   CONFIG.PSU__M_AXI_GP1_SUPPORTS_NARROW_BURST {1} \
   CONFIG.PSU__M_AXI_GP2_SUPPORTS_NARROW_BURST {1} \
   CONFIG.PSU__NAND_COHERENCY {0} \
   CONFIG.PSU__NAND_ROUTE_THROUGH_FPD {0} \
   CONFIG.PSU__NAND__CHIP_ENABLE__ENABLE {0} \
   CONFIG.PSU__NAND__DATA_STROBE__ENABLE {0} \
   CONFIG.PSU__NAND__PERIPHERAL__ENABLE {0} \
   CONFIG.PSU__NAND__READY0_BUSY__ENABLE {0} \
   CONFIG.PSU__NAND__READY1_BUSY__ENABLE {0} \
   CONFIG.PSU__NAND__READY_BUSY__ENABLE {0} \
   CONFIG.PSU__NUM_FABRIC_RESETS {1} \
   CONFIG.PSU__OCM_BANK0__POWER__ON {1} \
   CONFIG.PSU__OCM_BANK1__POWER__ON {1} \
   CONFIG.PSU__OCM_BANK2__POWER__ON {1} \
   CONFIG.PSU__OCM_BANK3__POWER__ON {1} \
   CONFIG.PSU__OVERRIDE_HPX_QOS {0} \
   CONFIG.PSU__OVERRIDE__BASIC_CLOCK {0} \
   CONFIG.PSU__PCIE__ACS_VIOLAION {0} \
   CONFIG.PSU__PCIE__ACS_VIOLATION {0} \
   CONFIG.PSU__PCIE__AER_CAPABILITY {0} \
   CONFIG.PSU__PCIE__ATOMICOP_EGRESS_BLOCKED {0} \
   CONFIG.PSU__PCIE__BAR0_64BIT {0} \
   CONFIG.PSU__PCIE__BAR0_ENABLE {0} \
   CONFIG.PSU__PCIE__BAR0_PREFETCHABLE {0} \
   CONFIG.PSU__PCIE__BAR0_VAL {} \
   CONFIG.PSU__PCIE__BAR1_64BIT {0} \
   CONFIG.PSU__PCIE__BAR1_ENABLE {0} \
   CONFIG.PSU__PCIE__BAR1_PREFETCHABLE {0} \
   CONFIG.PSU__PCIE__BAR1_VAL {} \
   CONFIG.PSU__PCIE__BAR2_64BIT {0} \
   CONFIG.PSU__PCIE__BAR2_ENABLE {0} \
   CONFIG.PSU__PCIE__BAR2_PREFETCHABLE {0} \
   CONFIG.PSU__PCIE__BAR2_VAL {} \
   CONFIG.PSU__PCIE__BAR3_64BIT {0} \
   CONFIG.PSU__PCIE__BAR3_ENABLE {0} \
   CONFIG.PSU__PCIE__BAR3_PREFETCHABLE {0} \
   CONFIG.PSU__PCIE__BAR3_VAL {} \
   CONFIG.PSU__PCIE__BAR4_64BIT {0} \
   CONFIG.PSU__PCIE__BAR4_ENABLE {0} \
   CONFIG.PSU__PCIE__BAR4_PREFETCHABLE {0} \
   CONFIG.PSU__PCIE__BAR4_VAL {} \
   CONFIG.PSU__PCIE__BAR5_64BIT {0} \
   CONFIG.PSU__PCIE__BAR5_ENABLE {0} \
   CONFIG.PSU__PCIE__BAR5_PREFETCHABLE {0} \
   CONFIG.PSU__PCIE__BAR5_VAL {} \
   CONFIG.PSU__PCIE__CLASS_CODE_BASE {} \
   CONFIG.PSU__PCIE__CLASS_CODE_INTERFACE {} \
   CONFIG.PSU__PCIE__CLASS_CODE_SUB {} \
   CONFIG.PSU__PCIE__CLASS_CODE_VALUE {} \
   CONFIG.PSU__PCIE__COMPLETER_ABORT {0} \
   CONFIG.PSU__PCIE__COMPLTION_TIMEOUT {0} \
   CONFIG.PSU__PCIE__CORRECTABLE_INT_ERR {0} \
   CONFIG.PSU__PCIE__CRS_SW_VISIBILITY {0} \
   CONFIG.PSU__PCIE__DEVICE_ID {} \
   CONFIG.PSU__PCIE__ECRC_CHECK {0} \
   CONFIG.PSU__PCIE__ECRC_ERR {0} \
   CONFIG.PSU__PCIE__ECRC_GEN {0} \
   CONFIG.PSU__PCIE__EROM_ENABLE {0} \
   CONFIG.PSU__PCIE__EROM_VAL {} \
   CONFIG.PSU__PCIE__FLOW_CONTROL_ERR {0} \
   CONFIG.PSU__PCIE__FLOW_CONTROL_PROTOCOL_ERR {0} \
   CONFIG.PSU__PCIE__HEADER_LOG_OVERFLOW {0} \
   CONFIG.PSU__PCIE__INTX_GENERATION {0} \
   CONFIG.PSU__PCIE__LANE0__ENABLE {0} \
   CONFIG.PSU__PCIE__LANE1__ENABLE {0} \
   CONFIG.PSU__PCIE__LANE2__ENABLE {0} \
   CONFIG.PSU__PCIE__LANE3__ENABLE {0} \
   CONFIG.PSU__PCIE__MC_BLOCKED_TLP {0} \
   CONFIG.PSU__PCIE__MSIX_BAR_INDICATOR {} \
   CONFIG.PSU__PCIE__MSIX_CAPABILITY {0} \
   CONFIG.PSU__PCIE__MSIX_PBA_BAR_INDICATOR {} \
   CONFIG.PSU__PCIE__MSIX_PBA_OFFSET {0} \
   CONFIG.PSU__PCIE__MSIX_TABLE_OFFSET {0} \
   CONFIG.PSU__PCIE__MSIX_TABLE_SIZE {0} \
   CONFIG.PSU__PCIE__MSI_64BIT_ADDR_CAPABLE {0} \
   CONFIG.PSU__PCIE__MSI_CAPABILITY {0} \
   CONFIG.PSU__PCIE__MULTIHEADER {0} \
   CONFIG.PSU__PCIE__PERIPHERAL__ENABLE {0} \
   CONFIG.PSU__PCIE__PERIPHERAL__ENDPOINT_ENABLE {1} \
   CONFIG.PSU__PCIE__PERIPHERAL__ROOTPORT_ENABLE {0} \
   CONFIG.PSU__PCIE__PERM_ROOT_ERR_UPDATE {0} \
   CONFIG.PSU__PCIE__RECEIVER_ERR {0} \
   CONFIG.PSU__PCIE__RECEIVER_OVERFLOW {0} \
   CONFIG.PSU__PCIE__RESET__POLARITY {Active Low} \
   CONFIG.PSU__PCIE__REVISION_ID {} \
   CONFIG.PSU__PCIE__SUBSYSTEM_ID {} \
   CONFIG.PSU__PCIE__SUBSYSTEM_VENDOR_ID {} \
   CONFIG.PSU__PCIE__SURPRISE_DOWN {0} \
   CONFIG.PSU__PCIE__TLP_PREFIX_BLOCKED {0} \
   CONFIG.PSU__PCIE__UNCORRECTABL_INT_ERR {0} \
   CONFIG.PSU__PCIE__VENDOR_ID {} \
   CONFIG.PSU__PJTAG__PERIPHERAL__ENABLE {0} \
   CONFIG.PSU__PL_CLK0_BUF {TRUE} \
   CONFIG.PSU__PL_CLK1_BUF {TRUE} \
   CONFIG.PSU__PL_CLK2_BUF {FALSE} \
   CONFIG.PSU__PL_CLK3_BUF {FALSE} \
   CONFIG.PSU__PL__POWER__ON {1} \
   CONFIG.PSU__PMU_COHERENCY {0} \
   CONFIG.PSU__PMU__AIBACK__ENABLE {0} \
   CONFIG.PSU__PMU__EMIO_GPI__ENABLE {0} \
   CONFIG.PSU__PMU__EMIO_GPO__ENABLE {0} \
   CONFIG.PSU__PMU__GPI0__ENABLE {0} \
   CONFIG.PSU__PMU__GPI1__ENABLE {0} \
   CONFIG.PSU__PMU__GPI2__ENABLE {0} \
   CONFIG.PSU__PMU__GPI3__ENABLE {0} \
   CONFIG.PSU__PMU__GPI4__ENABLE {0} \
   CONFIG.PSU__PMU__GPI5__ENABLE {0} \
   CONFIG.PSU__PMU__GPO0__ENABLE {1} \
   CONFIG.PSU__PMU__GPO0__IO {MIO 32} \
   CONFIG.PSU__PMU__GPO1__ENABLE {1} \
   CONFIG.PSU__PMU__GPO1__IO {MIO 33} \
   CONFIG.PSU__PMU__GPO2__ENABLE {1} \
   CONFIG.PSU__PMU__GPO2__IO {MIO 34} \
   CONFIG.PSU__PMU__GPO2__POLARITY {low} \
   CONFIG.PSU__PMU__GPO3__ENABLE {1} \
   CONFIG.PSU__PMU__GPO3__IO {MIO 35} \
   CONFIG.PSU__PMU__GPO3__POLARITY {low} \
   CONFIG.PSU__PMU__GPO4__ENABLE {1} \
   CONFIG.PSU__PMU__GPO4__IO {MIO 36} \
   CONFIG.PSU__PMU__GPO4__POLARITY {low} \
   CONFIG.PSU__PMU__GPO5__ENABLE {1} \
   CONFIG.PSU__PMU__GPO5__IO {MIO 37} \
   CONFIG.PSU__PMU__GPO5__POLARITY {low} \
   CONFIG.PSU__PMU__PERIPHERAL__ENABLE {1} \
   CONFIG.PSU__PMU__PLERROR__ENABLE {0} \
   CONFIG.PSU__PRESET_APPLIED {1} \
   CONFIG.PSU__PROTECTION__DDR_SEGMENTS {NONE} \
   CONFIG.PSU__PROTECTION__DEBUG {0} \
   CONFIG.PSU__PROTECTION__ENABLE {0} \
   CONFIG.PSU__PROTECTION__FPD_SEGMENTS {SA:0xFD1A0000; SIZE:1280; UNIT:KB; RegionTZ:Secure; WrAllowed:Read/Write; subsystemId:PMU Firmware |  SA:0xFD000000; SIZE:64; UNIT:KB; RegionTZ:Secure; WrAllowed:Read/Write; subsystemId:PMU Firmware |  SA:0xFD010000; SIZE:64; UNIT:KB; RegionTZ:Secure; WrAllowed:Read/Write; subsystemId:PMU Firmware |  SA:0xFD020000; SIZE:64; UNIT:KB; RegionTZ:Secure; WrAllowed:Read/Write; subsystemId:PMU Firmware |  SA:0xFD030000; SIZE:64; UNIT:KB; RegionTZ:Secure; WrAllowed:Read/Write; subsystemId:PMU Firmware |  SA:0xFD040000; SIZE:64; UNIT:KB; RegionTZ:Secure; WrAllowed:Read/Write; subsystemId:PMU Firmware |  SA:0xFD050000; SIZE:64; UNIT:KB; RegionTZ:Secure; WrAllowed:Read/Write; subsystemId:PMU Firmware |  SA:0xFD610000; SIZE:512; UNIT:KB; RegionTZ:Secure; WrAllowed:Read/Write; subsystemId:PMU Firmware |  SA:0xFD5D0000; SIZE:64; UNIT:KB; RegionTZ:Secure; WrAllowed:Read/Write; subsystemId:PMU Firmware | SA:0xFD1A0000 ; SIZE:1280; UNIT:KB; RegionTZ:Secure ; WrAllowed:Read/Write; subsystemId:Secure Subsystem} \
   CONFIG.PSU__PROTECTION__LOCK_UNUSED_SEGMENTS {0} \
   CONFIG.PSU__PROTECTION__LPD_SEGMENTS {SA:0xFF980000; SIZE:64; UNIT:KB; RegionTZ:Secure; WrAllowed:Read/Write; subsystemId:PMU Firmware| SA:0xFF5E0000; SIZE:2560; UNIT:KB; RegionTZ:Secure; WrAllowed:Read/Write; subsystemId:PMU Firmware| SA:0xFFCC0000; SIZE:64; UNIT:KB; RegionTZ:Secure; WrAllowed:Read/Write; subsystemId:PMU Firmware| SA:0xFF180000; SIZE:768; UNIT:KB; RegionTZ:Secure; WrAllowed:Read/Write; subsystemId:PMU Firmware| SA:0xFF410000; SIZE:640; UNIT:KB; RegionTZ:Secure; WrAllowed:Read/Write; subsystemId:PMU Firmware| SA:0xFFA70000; SIZE:64; UNIT:KB; RegionTZ:Secure; WrAllowed:Read/Write; subsystemId:PMU Firmware| SA:0xFF9A0000; SIZE:64; UNIT:KB; RegionTZ:Secure; WrAllowed:Read/Write; subsystemId:PMU Firmware|SA:0xFF5E0000 ; SIZE:2560; UNIT:KB; RegionTZ:Secure ; WrAllowed:Read/Write; subsystemId:Secure Subsystem|SA:0xFFCC0000 ; SIZE:64; UNIT:KB; RegionTZ:Secure ; WrAllowed:Read/Write; subsystemId:Secure Subsystem|SA:0xFF180000 ; SIZE:768; UNIT:KB; RegionTZ:Secure ; WrAllowed:Read/Write; subsystemId:Secure Subsystem|SA:0xFF9A0000 ; SIZE:64; UNIT:KB; RegionTZ:Secure ; WrAllowed:Read/Write; subsystemId:Secure Subsystem} \
   CONFIG.PSU__PROTECTION__MASTERS {USB1:NonSecure;0|USB0:NonSecure;1|S_AXI_LPD:NA;0|S_AXI_HPC1_FPD:NA;0|S_AXI_HPC0_FPD:NA;1|S_AXI_HP3_FPD:NA;0|S_AXI_HP2_FPD:NA;0|S_AXI_HP1_FPD:NA;0|S_AXI_HP0_FPD:NA;0|S_AXI_ACP:NA;0|S_AXI_ACE:NA;0|SD1:NonSecure;1|SD0:NonSecure;0|SATA1:NonSecure;1|SATA0:NonSecure;1|RPU1:Secure;1|RPU0:Secure;1|QSPI:NonSecure;1|PMU:NA;1|PCIe:NonSecure;0|NAND:NonSecure;0|LDMA:NonSecure;1|GPU:NonSecure;1|GEM3:NonSecure;1|GEM2:NonSecure;0|GEM1:NonSecure;0|GEM0:NonSecure;0|FDMA:NonSecure;1|DP:NonSecure;1|DAP:NA;1|Coresight:NA;1|CSU:NA;1|APU:NA;1} \
   CONFIG.PSU__PROTECTION__MASTERS_TZ {GEM0:NonSecure|SD1:NonSecure|GEM2:NonSecure|GEM1:NonSecure|GEM3:NonSecure|PCIe:NonSecure|DP:NonSecure|NAND:NonSecure|GPU:NonSecure|USB1:NonSecure|USB0:NonSecure|LDMA:NonSecure|FDMA:NonSecure|QSPI:NonSecure|SD0:NonSecure} \
   CONFIG.PSU__PROTECTION__OCM_SEGMENTS {NONE} \
   CONFIG.PSU__PROTECTION__PRESUBSYSTEMS {NONE} \
   CONFIG.PSU__PROTECTION__SLAVES { \
     LPD;USB3_1_XHCI;FE300000;FE3FFFFF;0|LPD;USB3_1;FF9E0000;FF9EFFFF;0|LPD;USB3_0_XHCI;FE200000;FE2FFFFF;1|LPD;USB3_0;FF9D0000;FF9DFFFF;1|LPD;UART1;FF010000;FF01FFFF;1|LPD;UART0;FF000000;FF00FFFF;1|LPD;TTC3;FF140000;FF14FFFF;1|LPD;TTC2;FF130000;FF13FFFF;1|LPD;TTC1;FF120000;FF12FFFF;1|LPD;TTC0;FF110000;FF11FFFF;1|FPD;SWDT1;FD4D0000;FD4DFFFF;1|LPD;SWDT0;FF150000;FF15FFFF;1|LPD;SPI1;FF050000;FF05FFFF;0|LPD;SPI0;FF040000;FF04FFFF;0|FPD;SMMU_REG;FD5F0000;FD5FFFFF;1|FPD;SMMU;FD800000;FDFFFFFF;1|FPD;SIOU;FD3D0000;FD3DFFFF;1|FPD;SERDES;FD400000;FD47FFFF;1|LPD;SD1;FF170000;FF17FFFF;1|LPD;SD0;FF160000;FF16FFFF;0|FPD;SATA;FD0C0000;FD0CFFFF;1|LPD;RTC;FFA60000;FFA6FFFF;1|LPD;RSA_CORE;FFCE0000;FFCEFFFF;1|LPD;RPU;FF9A0000;FF9AFFFF;1|LPD;R5_TCM_RAM_GLOBAL;FFE00000;FFE3FFFF;1|LPD;R5_1_Instruction_Cache;FFEC0000;FFECFFFF;1|LPD;R5_1_Data_Cache;FFED0000;FFEDFFFF;1|LPD;R5_1_BTCM_GLOBAL;FFEB0000;FFEBFFFF;1|LPD;R5_1_ATCM_GLOBAL;FFE90000;FFE9FFFF;1|LPD;R5_0_Instruction_Cache;FFE40000;FFE4FFFF;1|LPD;R5_0_Data_Cache;FFE50000;FFE5FFFF;1|LPD;R5_0_BTCM_GLOBAL;FFE20000;FFE2FFFF;1|LPD;R5_0_ATCM_GLOBAL;FFE00000;FFE0FFFF;1|LPD;QSPI_Linear_Address;C0000000;DFFFFFFF;1|LPD;QSPI;FF0F0000;FF0FFFFF;1|LPD;PMU_RAM;FFDC0000;FFDDFFFF;1|LPD;PMU_GLOBAL;FFD80000;FFDBFFFF;1|FPD;PCIE_MAIN;FD0E0000;FD0EFFFF;0|FPD;PCIE_LOW;E0000000;EFFFFFFF;0|FPD;PCIE_HIGH2;8000000000;BFFFFFFFFF;0|FPD;PCIE_HIGH1;600000000;7FFFFFFFF;0|FPD;PCIE_DMA;FD0F0000;FD0FFFFF;0|FPD;PCIE_ATTRIB;FD480000;FD48FFFF;0|LPD;OCM_XMPU_CFG;FFA70000;FFA7FFFF;1|LPD;OCM_SLCR;FF960000;FF96FFFF;1|OCM;OCM;FFFC0000;FFFFFFFF;1|LPD;NAND;FF100000;FF10FFFF;0|LPD;MBISTJTAG;FFCF0000;FFCFFFFF;1|LPD;LPD_XPPU_SINK;FF9C0000;FF9CFFFF;1|LPD;LPD_XPPU;FF980000;FF98FFFF;1|LPD;LPD_SLCR_SECURE;FF4B0000;FF4DFFFF;1|LPD;LPD_SLCR;FF410000;FF4AFFFF;1|LPD;LPD_GPV;FE100000;FE1FFFFF;1|LPD;LPD_DMA_7;FFAF0000;FFAFFFFF;1|LPD;LPD_DMA_6;FFAE0000;FFAEFFFF;1|LPD;LPD_DMA_5;FFAD0000;FFADFFFF;1|LPD;LPD_DMA_4;FFAC0000;FFACFFFF;1|LPD;LPD_DMA_3;FFAB0000;FFABFFFF;1|LPD;LPD_DMA_2;FFAA0000;FFAAFFFF;1|LPD;LPD_DMA_1;FFA90000;FFA9FFFF;1|LPD;LPD_DMA_0;FFA80000;FFA8FFFF;1|LPD;IPI_CTRL;FF380000;FF3FFFFF;1|LPD;IOU_SLCR;FF180000;FF23FFFF;1|LPD;IOU_SECURE_SLCR;FF240000;FF24FFFF;1|LPD;IOU_SCNTRS;FF260000;FF26FFFF;1|LPD;IOU_SCNTR;FF250000;FF25FFFF;1|LPD;IOU_GPV;FE000000;FE0FFFFF;1|LPD;I2C1;FF030000;FF03FFFF;1|LPD;I2C0;FF020000;FF02FFFF;1|FPD;GPU;FD4B0000;FD4BFFFF;0|LPD;GPIO;FF0A0000;FF0AFFFF;1|LPD;GEM3;FF0E0000;FF0EFFFF;1|LPD;GEM2;FF0D0000;FF0DFFFF;0|LPD;GEM1;FF0C0000;FF0CFFFF;0|LPD;GEM0;FF0B0000;FF0BFFFF;0|FPD;FPD_XMPU_SINK;FD4F0000;FD4FFFFF;1|FPD;FPD_XMPU_CFG;FD5D0000;FD5DFFFF;1|FPD;FPD_SLCR_SECURE;FD690000;FD6CFFFF;1|FPD;FPD_SLCR;FD610000;FD68FFFF;1|FPD;FPD_DMA_CH7;FD570000;FD57FFFF;1|FPD;FPD_DMA_CH6;FD560000;FD56FFFF;1|FPD;FPD_DMA_CH5;FD550000;FD55FFFF;1|FPD;FPD_DMA_CH4;FD540000;FD54FFFF;1|FPD;FPD_DMA_CH3;FD530000;FD53FFFF;1|FPD;FPD_DMA_CH2;FD520000;FD52FFFF;1|FPD;FPD_DMA_CH1;FD510000;FD51FFFF;1|FPD;FPD_DMA_CH0;FD500000;FD50FFFF;1|LPD;EFUSE;FFCC0000;FFCCFFFF;1|FPD;Display Port;FD4A0000;FD4AFFFF;1|FPD;DPDMA;FD4C0000;FD4CFFFF;1|FPD;DDR_XMPU5_CFG;FD050000;FD05FFFF;1|FPD;DDR_XMPU4_CFG;FD040000;FD04FFFF;1|FPD;DDR_XMPU3_CFG;FD030000;FD03FFFF;1|FPD;DDR_XMPU2_CFG;FD020000;FD02FFFF;1|FPD;DDR_XMPU1_CFG;FD010000;FD01FFFF;1|FPD;DDR_XMPU0_CFG;FD000000;FD00FFFF;1|FPD;DDR_QOS_CTRL;FD090000;FD09FFFF;1|FPD;DDR_PHY;FD080000;FD08FFFF;1|DDR;DDR_LOW;0;7FFFFFFF;1|DDR;DDR_HIGH;800000000;87FFFFFFF;1|FPD;DDDR_CTRL;FD070000;FD070FFF;1|LPD;Coresight;FE800000;FEFFFFFF;1|LPD;CSU_DMA;FFC80000;FFC9FFFF;1|LPD;CSU;FFCA0000;FFCAFFFF;1|LPD;CRL_APB;FF5E0000;FF85FFFF;1|FPD;CRF_APB;FD1A0000;FD2DFFFF;1|FPD;CCI_REG;FD5E0000;FD5EFFFF;1|LPD;CAN1;FF070000;FF07FFFF;0|LPD;CAN0;FF060000;FF06FFFF;0|FPD;APU;FD5C0000;FD5CFFFF;1|LPD;APM_INTC_IOU;FFA20000;FFA2FFFF;1|LPD;APM_FPD_LPD;FFA30000;FFA3FFFF;1|FPD;APM_5;FD490000;FD49FFFF;1|FPD;APM_0;FD0B0000;FD0BFFFF;1|LPD;APM2;FFA10000;FFA1FFFF;1|LPD;APM1;FFA00000;FFA0FFFF;1|LPD;AMS;FFA50000;FFA5FFFF;1|FPD;AFI_5;FD3B0000;FD3BFFFF;1|FPD;AFI_4;FD3A0000;FD3AFFFF;1|FPD;AFI_3;FD390000;FD39FFFF;1|FPD;AFI_2;FD380000;FD38FFFF;1|FPD;AFI_1;FD370000;FD37FFFF;1|FPD;AFI_0;FD360000;FD36FFFF;1|LPD;AFIFM6;FF9B0000;FF9BFFFF;1|FPD;ACPU_GIC;F9010000;F907FFFF;1 \
   } \
   CONFIG.PSU__PROTECTION__SUBSYSTEMS {PMU Firmware:PMU|Secure Subsystem:} \
   CONFIG.PSU__PSS_ALT_REF_CLK__ENABLE {0} \
   CONFIG.PSU__PSS_ALT_REF_CLK__FREQMHZ {33.333} \
   CONFIG.PSU__PSS_REF_CLK__FREQMHZ {33.333} \
   CONFIG.PSU__QSPI_COHERENCY {0} \
   CONFIG.PSU__QSPI_ROUTE_THROUGH_FPD {0} \
   CONFIG.PSU__QSPI__GRP_FBCLK__ENABLE {1} \
   CONFIG.PSU__QSPI__GRP_FBCLK__IO {MIO 6} \
   CONFIG.PSU__QSPI__PERIPHERAL__DATA_MODE {x4} \
   CONFIG.PSU__QSPI__PERIPHERAL__ENABLE {1} \
   CONFIG.PSU__QSPI__PERIPHERAL__IO {MIO 0 .. 12} \
   CONFIG.PSU__QSPI__PERIPHERAL__MODE {Dual Parallel} \
   CONFIG.PSU__REPORT__DBGLOG {0} \
   CONFIG.PSU__RPU_COHERENCY {0} \
   CONFIG.PSU__RPU__POWER__ON {1} \
   CONFIG.PSU__SATA__LANE0__ENABLE {0} \
   CONFIG.PSU__SATA__LANE1__ENABLE {1} \
   CONFIG.PSU__SATA__LANE1__IO {GT Lane3} \
   CONFIG.PSU__SATA__PERIPHERAL__ENABLE {1} \
   CONFIG.PSU__SATA__REF_CLK_FREQ {125} \
   CONFIG.PSU__SATA__REF_CLK_SEL {Ref Clk3} \
   CONFIG.PSU__SAXIGP0__DATA_WIDTH {128} \
   CONFIG.PSU__SAXIGP1__DATA_WIDTH {128} \
   CONFIG.PSU__SAXIGP2__DATA_WIDTH {128} \
   CONFIG.PSU__SAXIGP3__DATA_WIDTH {128} \
   CONFIG.PSU__SAXIGP4__DATA_WIDTH {128} \
   CONFIG.PSU__SAXIGP5__DATA_WIDTH {128} \
   CONFIG.PSU__SAXIGP6__DATA_WIDTH {128} \
   CONFIG.PSU__SD0_COHERENCY {0} \
   CONFIG.PSU__SD0_ROUTE_THROUGH_FPD {0} \
   CONFIG.PSU__SD0__GRP_CD__ENABLE {0} \
   CONFIG.PSU__SD0__GRP_POW__ENABLE {0} \
   CONFIG.PSU__SD0__GRP_WP__ENABLE {0} \
   CONFIG.PSU__SD0__PERIPHERAL__ENABLE {0} \
   CONFIG.PSU__SD0__RESET__ENABLE {0} \
   CONFIG.PSU__SD1_COHERENCY {0} \
   CONFIG.PSU__SD1_ROUTE_THROUGH_FPD {0} \
   CONFIG.PSU__SD1__DATA_TRANSFER_MODE {8Bit} \
   CONFIG.PSU__SD1__GRP_CD__ENABLE {1} \
   CONFIG.PSU__SD1__GRP_CD__IO {MIO 45} \
   CONFIG.PSU__SD1__GRP_POW__ENABLE {0} \
   CONFIG.PSU__SD1__GRP_WP__ENABLE {0} \
   CONFIG.PSU__SD1__PERIPHERAL__ENABLE {1} \
   CONFIG.PSU__SD1__PERIPHERAL__IO {MIO 39 .. 51} \
   CONFIG.PSU__SD1__RESET__ENABLE {0} \
   CONFIG.PSU__SD1__SLOT_TYPE {SD 3.0} \
   CONFIG.PSU__SPI0_LOOP_SPI1__ENABLE {0} \
   CONFIG.PSU__SPI0__GRP_SS0__ENABLE {0} \
   CONFIG.PSU__SPI0__GRP_SS1__ENABLE {0} \
   CONFIG.PSU__SPI0__GRP_SS2__ENABLE {0} \
   CONFIG.PSU__SPI0__PERIPHERAL__ENABLE {0} \
   CONFIG.PSU__SPI1__GRP_SS0__ENABLE {0} \
   CONFIG.PSU__SPI1__GRP_SS1__ENABLE {0} \
   CONFIG.PSU__SPI1__GRP_SS2__ENABLE {0} \
   CONFIG.PSU__SPI1__PERIPHERAL__ENABLE {0} \
   CONFIG.PSU__SWDT0__CLOCK__ENABLE {0} \
   CONFIG.PSU__SWDT0__PERIPHERAL__ENABLE {1} \
   CONFIG.PSU__SWDT0__PERIPHERAL__IO {NA} \
   CONFIG.PSU__SWDT0__RESET__ENABLE {0} \
   CONFIG.PSU__SWDT1__CLOCK__ENABLE {0} \
   CONFIG.PSU__SWDT1__PERIPHERAL__ENABLE {1} \
   CONFIG.PSU__SWDT1__PERIPHERAL__IO {NA} \
   CONFIG.PSU__SWDT1__RESET__ENABLE {0} \
   CONFIG.PSU__TCM0A__POWER__ON {1} \
   CONFIG.PSU__TCM0B__POWER__ON {1} \
   CONFIG.PSU__TCM1A__POWER__ON {1} \
   CONFIG.PSU__TCM1B__POWER__ON {1} \
   CONFIG.PSU__TESTSCAN__PERIPHERAL__ENABLE {0} \
   CONFIG.PSU__TRACE_PIPELINE_WIDTH {8} \
   CONFIG.PSU__TRACE__INTERNAL_WIDTH {32} \
   CONFIG.PSU__TRACE__PERIPHERAL__ENABLE {0} \
   CONFIG.PSU__TRISTATE__INVERTED {1} \
   CONFIG.PSU__TSU__BUFG_PORT_PAIR {0} \
   CONFIG.PSU__TTC0__CLOCK__ENABLE {0} \
   CONFIG.PSU__TTC0__PERIPHERAL__ENABLE {1} \
   CONFIG.PSU__TTC0__PERIPHERAL__IO {NA} \
   CONFIG.PSU__TTC0__WAVEOUT__ENABLE {0} \
   CONFIG.PSU__TTC1__CLOCK__ENABLE {0} \
   CONFIG.PSU__TTC1__PERIPHERAL__ENABLE {1} \
   CONFIG.PSU__TTC1__PERIPHERAL__IO {NA} \
   CONFIG.PSU__TTC1__WAVEOUT__ENABLE {0} \
   CONFIG.PSU__TTC2__CLOCK__ENABLE {0} \
   CONFIG.PSU__TTC2__PERIPHERAL__ENABLE {1} \
   CONFIG.PSU__TTC2__PERIPHERAL__IO {NA} \
   CONFIG.PSU__TTC2__WAVEOUT__ENABLE {0} \
   CONFIG.PSU__TTC3__CLOCK__ENABLE {0} \
   CONFIG.PSU__TTC3__PERIPHERAL__ENABLE {1} \
   CONFIG.PSU__TTC3__PERIPHERAL__IO {NA} \
   CONFIG.PSU__TTC3__WAVEOUT__ENABLE {0} \
   CONFIG.PSU__UART0_LOOP_UART1__ENABLE {0} \
   CONFIG.PSU__UART0__BAUD_RATE {115200} \
   CONFIG.PSU__UART0__MODEM__ENABLE {0} \
   CONFIG.PSU__UART0__PERIPHERAL__ENABLE {1} \
   CONFIG.PSU__UART0__PERIPHERAL__IO {MIO 18 .. 19} \
   CONFIG.PSU__UART1__BAUD_RATE {115200} \
   CONFIG.PSU__UART1__MODEM__ENABLE {0} \
   CONFIG.PSU__UART1__PERIPHERAL__ENABLE {1} \
   CONFIG.PSU__UART1__PERIPHERAL__IO {EMIO} \
   CONFIG.PSU__USB0_COHERENCY {0} \
   CONFIG.PSU__USB0__PERIPHERAL__ENABLE {1} \
   CONFIG.PSU__USB0__PERIPHERAL__IO {MIO 52 .. 63} \
   CONFIG.PSU__USB0__REF_CLK_FREQ {26} \
   CONFIG.PSU__USB0__REF_CLK_SEL {Ref Clk2} \
   CONFIG.PSU__USB0__RESET__ENABLE {0} \
   CONFIG.PSU__USB1_COHERENCY {0} \
   CONFIG.PSU__USB1__PERIPHERAL__ENABLE {0} \
   CONFIG.PSU__USB1__RESET__ENABLE {0} \
   CONFIG.PSU__USB2_0__EMIO__ENABLE {0} \
   CONFIG.PSU__USB2_1__EMIO__ENABLE {0} \
   CONFIG.PSU__USB3_0__EMIO__ENABLE {0} \
   CONFIG.PSU__USB3_0__PERIPHERAL__ENABLE {1} \
   CONFIG.PSU__USB3_0__PERIPHERAL__IO {GT Lane2} \
   CONFIG.PSU__USB3_1__EMIO__ENABLE {0} \
   CONFIG.PSU__USB3_1__PERIPHERAL__ENABLE {0} \
   CONFIG.PSU__USB__RESET__MODE {Boot Pin} \
   CONFIG.PSU__USB__RESET__POLARITY {Active Low} \
   CONFIG.PSU__USE_DIFF_RW_CLK_GP0 {0} \
   CONFIG.PSU__USE_DIFF_RW_CLK_GP1 {0} \
   CONFIG.PSU__USE_DIFF_RW_CLK_GP2 {0} \
   CONFIG.PSU__USE_DIFF_RW_CLK_GP3 {0} \
   CONFIG.PSU__USE_DIFF_RW_CLK_GP4 {0} \
   CONFIG.PSU__USE_DIFF_RW_CLK_GP5 {0} \
   CONFIG.PSU__USE_DIFF_RW_CLK_GP6 {0} \
   CONFIG.PSU__USE__ADMA {0} \
   CONFIG.PSU__USE__APU_LEGACY_INTERRUPT {0} \
   CONFIG.PSU__USE__AUDIO {0} \
   CONFIG.PSU__USE__CLK {0} \
   CONFIG.PSU__USE__CLK0 {0} \
   CONFIG.PSU__USE__CLK1 {0} \
   CONFIG.PSU__USE__CLK2 {0} \
   CONFIG.PSU__USE__CLK3 {0} \
   CONFIG.PSU__USE__CROSS_TRIGGER {0} \
   CONFIG.PSU__USE__DDR_INTF_REQUESTED {0} \
   CONFIG.PSU__USE__DEBUG__TEST {0} \
   CONFIG.PSU__USE__EVENT_RPU {0} \
   CONFIG.PSU__USE__FABRIC__RST {1} \
   CONFIG.PSU__USE__FTM {0} \
   CONFIG.PSU__USE__GDMA {0} \
   CONFIG.PSU__USE__IRQ {0} \
   CONFIG.PSU__USE__IRQ0 {1} \
   CONFIG.PSU__USE__IRQ1 {0} \
   CONFIG.PSU__USE__M_AXI_GP0 {1} \
   CONFIG.PSU__USE__M_AXI_GP1 {0} \
   CONFIG.PSU__USE__M_AXI_GP2 {0} \
   CONFIG.PSU__USE__PROC_EVENT_BUS {0} \
   CONFIG.PSU__USE__RPU_LEGACY_INTERRUPT {0} \
   CONFIG.PSU__USE__RST0 {0} \
   CONFIG.PSU__USE__RST1 {0} \
   CONFIG.PSU__USE__RST2 {0} \
   CONFIG.PSU__USE__RST3 {0} \
   CONFIG.PSU__USE__RTC {0} \
   CONFIG.PSU__USE__STM {0} \
   CONFIG.PSU__USE__S_AXI_ACE {0} \
   CONFIG.PSU__USE__S_AXI_ACP {0} \
   CONFIG.PSU__USE__S_AXI_GP0 {1} \
   CONFIG.PSU__USE__S_AXI_GP1 {0} \
   CONFIG.PSU__USE__S_AXI_GP2 {0} \
   CONFIG.PSU__USE__S_AXI_GP3 {0} \
   CONFIG.PSU__USE__S_AXI_GP4 {0} \
   CONFIG.PSU__USE__S_AXI_GP5 {0} \
   CONFIG.PSU__USE__S_AXI_GP6 {0} \
   CONFIG.PSU__USE__USB3_0_HUB {0} \
   CONFIG.PSU__USE__USB3_1_HUB {0} \
   CONFIG.PSU__USE__VIDEO {0} \
   CONFIG.PSU__VIDEO_REF_CLK__ENABLE {0} \
   CONFIG.PSU__VIDEO_REF_CLK__FREQMHZ {33.333} \
   CONFIG.QSPI_BOARD_INTERFACE {custom} \
   CONFIG.SATA_BOARD_INTERFACE {custom} \
   CONFIG.SD0_BOARD_INTERFACE {custom} \
   CONFIG.SD1_BOARD_INTERFACE {custom} \
   CONFIG.SPI0_BOARD_INTERFACE {custom} \
   CONFIG.SPI1_BOARD_INTERFACE {custom} \
   CONFIG.SUBPRESET1 {Custom} \
   CONFIG.SUBPRESET2 {Custom} \
   CONFIG.SWDT0_BOARD_INTERFACE {custom} \
   CONFIG.SWDT1_BOARD_INTERFACE {custom} \
   CONFIG.TRACE_BOARD_INTERFACE {custom} \
   CONFIG.TTC0_BOARD_INTERFACE {custom} \
   CONFIG.TTC1_BOARD_INTERFACE {custom} \
   CONFIG.TTC2_BOARD_INTERFACE {custom} \
   CONFIG.TTC3_BOARD_INTERFACE {custom} \
   CONFIG.UART0_BOARD_INTERFACE {custom} \
   CONFIG.UART1_BOARD_INTERFACE {custom} \
   CONFIG.USB0_BOARD_INTERFACE {custom} \
   CONFIG.USB1_BOARD_INTERFACE {custom} \
 ] $zynq_ultra_ps_e_0

  # Create interface connections
  connect_bd_intf_net -intf_net adc0_clk_1 [get_bd_intf_ports adc0_clk] [get_bd_intf_pins usp_rf_data_converter_0/adc0_clk]
  connect_bd_intf_net -intf_net axi_bram_ctrl_0_BRAM_PORTA [get_bd_intf_pins axi_bram_ctrl_0/BRAM_PORTA] [get_bd_intf_pins axi_bram_ctrl_0_bram/BRAM_PORTA]
  connect_bd_intf_net -intf_net axi_dma_0_M_AXIS_MM2S [get_bd_intf_pins axi_dma_tproc/M_AXIS_MM2S] [get_bd_intf_pins axis_tproc64x32_x8_0/s0_axis]
  connect_bd_intf_net -intf_net axi_dma_0_M_AXI_MM2S [get_bd_intf_pins axi_dma_tproc/M_AXI_MM2S] [get_bd_intf_pins axi_smc/S00_AXI]
  connect_bd_intf_net -intf_net axi_dma_0_M_AXI_S2MM [get_bd_intf_pins axi_dma_tproc/M_AXI_S2MM] [get_bd_intf_pins axi_smc/S01_AXI]
  connect_bd_intf_net -intf_net axi_dma_1_M_AXIS_MM2S [get_bd_intf_pins axi_dma_gen/M_AXIS_MM2S] [get_bd_intf_pins axis_switch_gen/S00_AXIS]
  connect_bd_intf_net -intf_net axi_dma_1_M_AXI_MM2S [get_bd_intf_pins axi_dma_gen/M_AXI_MM2S] [get_bd_intf_pins axi_smc/S02_AXI]
  connect_bd_intf_net -intf_net axi_dma_avg_M_AXI_S2MM [get_bd_intf_pins axi_dma_avg/M_AXI_S2MM] [get_bd_intf_pins axi_smc/S03_AXI]
  connect_bd_intf_net -intf_net axi_dma_buf_M_AXI_S2MM [get_bd_intf_pins axi_dma_buf/M_AXI_S2MM] [get_bd_intf_pins axi_smc/S04_AXI]
  connect_bd_intf_net -intf_net axi_smc_M00_AXI [get_bd_intf_pins axi_smc/M00_AXI] [get_bd_intf_pins zynq_ultra_ps_e_0/S_AXI_HPC0_FPD]
  connect_bd_intf_net -intf_net axis_avg_buffer_0_m0_axis [get_bd_intf_pins axis_avg_buffer_0/m0_axis] [get_bd_intf_pins axis_switch_avg/S00_AXIS]
  connect_bd_intf_net -intf_net axis_avg_buffer_0_m1_axis [get_bd_intf_pins axis_avg_buffer_0/m1_axis] [get_bd_intf_pins axis_switch_buf/S00_AXIS]
  connect_bd_intf_net -intf_net axis_avg_buffer_0_m2_axis [get_bd_intf_pins axis_avg_buffer_0/m2_axis] [get_bd_intf_pins axis_clk_cnvrt_avg_0/S_AXIS]
connect_bd_intf_net -intf_net [get_bd_intf_nets axis_avg_buffer_0_m2_axis] [get_bd_intf_pins axis_clk_cnvrt_avg_0/S_AXIS] [get_bd_intf_pins system_ila_0/SLOT_0_AXIS]
  connect_bd_intf_net -intf_net axis_avg_buffer_1_m0_axis [get_bd_intf_pins axis_avg_buffer_1/m0_axis] [get_bd_intf_pins axis_switch_avg/S01_AXIS]
  connect_bd_intf_net -intf_net axis_avg_buffer_1_m1_axis [get_bd_intf_pins axis_avg_buffer_1/m1_axis] [get_bd_intf_pins axis_switch_buf/S01_AXIS]
  connect_bd_intf_net -intf_net axis_avg_buffer_1_m2_axis [get_bd_intf_pins axis_avg_buffer_1/m2_axis] [get_bd_intf_pins axis_clk_cnvrt_avg_1/S_AXIS]
  connect_bd_intf_net -intf_net axis_clk_cnvrt_avg_0_M_AXIS [get_bd_intf_pins axis_clk_cnvrt_avg_0/M_AXIS] [get_bd_intf_pins axis_tproc64x32_x8_0/s1_axis]
connect_bd_intf_net -intf_net [get_bd_intf_nets axis_clk_cnvrt_avg_0_M_AXIS] [get_bd_intf_pins axis_clk_cnvrt_avg_0/M_AXIS] [get_bd_intf_pins system_ila_1/SLOT_0_AXIS]
  connect_bd_intf_net -intf_net axis_clk_cnvrt_avg_1_M_AXIS [get_bd_intf_pins axis_clk_cnvrt_avg_1/M_AXIS] [get_bd_intf_pins axis_tproc64x32_x8_0/s2_axis]
  connect_bd_intf_net -intf_net axis_clock_converter_3_M_AXIS [get_bd_intf_pins axis_clk_cnvrt_gen_3/M_AXIS] [get_bd_intf_pins axis_signal_gen_v6_3/s1_axis]
  connect_bd_intf_net -intf_net axis_clock_converter_4_M_AXIS [get_bd_intf_pins axis_clk_cnvrt_gen_4/M_AXIS] [get_bd_intf_pins axis_signal_gen_v6_4/s1_axis]
  connect_bd_intf_net -intf_net axis_clock_converter_5_M_AXIS [get_bd_intf_pins axis_clk_cnvrt_gen_5/M_AXIS] [get_bd_intf_pins axis_signal_gen_v6_5/s1_axis]
  connect_bd_intf_net -intf_net axis_clock_converter_6_M_AXIS [get_bd_intf_pins axis_clk_cnvrt_gen_6/M_AXIS] [get_bd_intf_pins axis_signal_gen_v6_6/s1_axis]
  connect_bd_intf_net -intf_net axis_constant_0_m_axis [get_bd_intf_pins axis_constant_0/m_axis] [get_bd_intf_pins axis_tproc64x32_x8_0/s3_axis]
  connect_bd_intf_net -intf_net axis_constant_1_m_axis [get_bd_intf_pins axis_constant_1/m_axis] [get_bd_intf_pins axis_tproc64x32_x8_0/s4_axis]
  connect_bd_intf_net -intf_net axis_readout_v2_0_m0_axis [get_bd_intf_pins axis_readout_v2_0/m0_axis] [get_bd_intf_pins axis_terminator_0/s_axis]
  connect_bd_intf_net -intf_net axis_readout_v2_0_m1_axis [get_bd_intf_pins axis_avg_buffer_0/s_axis] [get_bd_intf_pins axis_readout_v2_0/m1_axis]
  connect_bd_intf_net -intf_net axis_readout_v2_1_m0_axis [get_bd_intf_pins axis_readout_v2_1/m0_axis] [get_bd_intf_pins axis_terminator_1/s_axis]
  connect_bd_intf_net -intf_net axis_readout_v2_1_m1_axis [get_bd_intf_pins axis_avg_buffer_1/s_axis] [get_bd_intf_pins axis_readout_v2_1/m1_axis]
  connect_bd_intf_net -intf_net axis_register_slice_0_M_AXIS [get_bd_intf_pins axis_readout_v2_0/s_axis] [get_bd_intf_pins axis_register_slice_0/M_AXIS]
  connect_bd_intf_net -intf_net axis_register_slice_1_M_AXIS [get_bd_intf_pins axis_readout_v2_1/s_axis] [get_bd_intf_pins axis_register_slice_1/M_AXIS]
  connect_bd_intf_net -intf_net axis_signal_gen_v6_0_m_axis [get_bd_intf_pins axis_signal_gen_v6_0/m_axis] [get_bd_intf_pins usp_rf_data_converter_0/s00_axis]
  connect_bd_intf_net -intf_net axis_signal_gen_v6_1_m_axis [get_bd_intf_pins axis_signal_gen_v6_1/m_axis] [get_bd_intf_pins usp_rf_data_converter_0/s01_axis]
  connect_bd_intf_net -intf_net axis_signal_gen_v6_2_m_axis [get_bd_intf_pins axis_signal_gen_v6_2/m_axis] [get_bd_intf_pins usp_rf_data_converter_0/s02_axis]
  connect_bd_intf_net -intf_net axis_signal_gen_v6_3_m_axis [get_bd_intf_pins axis_signal_gen_v6_3/m_axis] [get_bd_intf_pins usp_rf_data_converter_0/s10_axis]
  connect_bd_intf_net -intf_net axis_signal_gen_v6_4_m_axis [get_bd_intf_pins axis_signal_gen_v6_4/m_axis] [get_bd_intf_pins usp_rf_data_converter_0/s11_axis]
  connect_bd_intf_net -intf_net axis_signal_gen_v6_5_m_axis [get_bd_intf_pins axis_signal_gen_v6_5/m_axis] [get_bd_intf_pins usp_rf_data_converter_0/s12_axis]
  connect_bd_intf_net -intf_net axis_signal_gen_v6_6_m_axis [get_bd_intf_pins axis_signal_gen_v6_6/m_axis] [get_bd_intf_pins usp_rf_data_converter_0/s13_axis]
  connect_bd_intf_net -intf_net axis_switch_0_M00_AXIS [get_bd_intf_pins axis_signal_gen_v6_0/s0_axis] [get_bd_intf_pins axis_switch_gen/M00_AXIS]
  connect_bd_intf_net -intf_net axis_switch_0_M01_AXIS [get_bd_intf_pins axis_signal_gen_v6_1/s0_axis] [get_bd_intf_pins axis_switch_gen/M01_AXIS]
  connect_bd_intf_net -intf_net axis_switch_0_M02_AXIS [get_bd_intf_pins axis_signal_gen_v6_2/s0_axis] [get_bd_intf_pins axis_switch_gen/M02_AXIS]
  connect_bd_intf_net -intf_net axis_switch_0_M03_AXIS [get_bd_intf_pins axis_signal_gen_v6_3/s0_axis] [get_bd_intf_pins axis_switch_gen/M03_AXIS]
  connect_bd_intf_net -intf_net axis_switch_0_M04_AXIS [get_bd_intf_pins axis_signal_gen_v6_4/s0_axis] [get_bd_intf_pins axis_switch_gen/M04_AXIS]
  connect_bd_intf_net -intf_net axis_switch_0_M05_AXIS [get_bd_intf_pins axis_signal_gen_v6_5/s0_axis] [get_bd_intf_pins axis_switch_gen/M05_AXIS]
  connect_bd_intf_net -intf_net axis_switch_0_M06_AXIS [get_bd_intf_pins axis_signal_gen_v6_6/s0_axis] [get_bd_intf_pins axis_switch_gen/M06_AXIS]
  connect_bd_intf_net -intf_net axis_switch_avg_M00_AXIS [get_bd_intf_pins axi_dma_avg/S_AXIS_S2MM] [get_bd_intf_pins axis_switch_avg/M00_AXIS]
  connect_bd_intf_net -intf_net axis_switch_buf_M00_AXIS [get_bd_intf_pins axi_dma_buf/S_AXIS_S2MM] [get_bd_intf_pins axis_switch_buf/M00_AXIS]
  connect_bd_intf_net -intf_net axis_tproc64x32_x8_0_m0_axis [get_bd_intf_pins axi_dma_tproc/S_AXIS_S2MM] [get_bd_intf_pins axis_tproc64x32_x8_0/m0_axis]
  connect_bd_intf_net -intf_net axis_tproc64x32_x8_0_m1_axis [get_bd_intf_pins axis_set_reg_0/s_axis] [get_bd_intf_pins axis_tproc64x32_x8_0/m1_axis]
  connect_bd_intf_net -intf_net axis_tproc64x32_x8_0_m2_axis [get_bd_intf_pins axis_signal_gen_v6_0/s1_axis] [get_bd_intf_pins axis_tproc64x32_x8_0/m2_axis]
  connect_bd_intf_net -intf_net axis_tproc64x32_x8_0_m3_axis [get_bd_intf_pins axis_signal_gen_v6_1/s1_axis] [get_bd_intf_pins axis_tproc64x32_x8_0/m3_axis]
  connect_bd_intf_net -intf_net axis_tproc64x32_x8_0_m4_axis [get_bd_intf_pins axis_signal_gen_v6_2/s1_axis] [get_bd_intf_pins axis_tproc64x32_x8_0/m4_axis]
  connect_bd_intf_net -intf_net axis_tproc64x32_x8_0_m5_axis [get_bd_intf_pins axis_clk_cnvrt_gen_3/S_AXIS] [get_bd_intf_pins axis_tproc64x32_x8_0/m5_axis]
  connect_bd_intf_net -intf_net axis_tproc64x32_x8_0_m6_axis [get_bd_intf_pins axis_clk_cnvrt_gen_4/S_AXIS] [get_bd_intf_pins axis_tproc64x32_x8_0/m6_axis]
  connect_bd_intf_net -intf_net axis_tproc64x32_x8_0_m7_axis [get_bd_intf_pins axis_clk_cnvrt_gen_5/S_AXIS] [get_bd_intf_pins axis_tproc64x32_x8_0/m7_axis]
  connect_bd_intf_net -intf_net axis_tproc64x32_x8_0_m8_axis [get_bd_intf_pins axis_clk_cnvrt_gen_6/S_AXIS] [get_bd_intf_pins axis_tproc64x32_x8_0/m8_axis]
  connect_bd_intf_net -intf_net dac0_clk_1 [get_bd_intf_ports dac0_clk] [get_bd_intf_pins usp_rf_data_converter_0/dac0_clk]
  connect_bd_intf_net -intf_net dac1_clk_1 [get_bd_intf_ports dac1_clk] [get_bd_intf_pins usp_rf_data_converter_0/dac1_clk]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M00_AXI [get_bd_intf_pins axi_dma_tproc/S_AXI_LITE] [get_bd_intf_pins ps8_0_axi_periph/M00_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M01_AXI [get_bd_intf_pins axis_tproc64x32_x8_0/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M01_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M02_AXI [get_bd_intf_pins axis_signal_gen_v6_0/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M02_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M03_AXI [get_bd_intf_pins axis_signal_gen_v6_1/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M03_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M04_AXI [get_bd_intf_pins axis_signal_gen_v6_2/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M04_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M05_AXI [get_bd_intf_pins axis_signal_gen_v6_3/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M05_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M06_AXI [get_bd_intf_pins axi_dma_gen/S_AXI_LITE] [get_bd_intf_pins ps8_0_axi_periph/M06_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M07_AXI [get_bd_intf_pins axis_switch_gen/S_AXI_CTRL] [get_bd_intf_pins ps8_0_axi_periph/M07_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M08_AXI [get_bd_intf_pins ps8_0_axi_periph/M08_AXI] [get_bd_intf_pins usp_rf_data_converter_0/s_axi]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M09_AXI [get_bd_intf_pins axis_avg_buffer_0/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M09_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M10_AXI [get_bd_intf_pins axis_avg_buffer_1/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M10_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M11_AXI [get_bd_intf_pins axis_signal_gen_v6_4/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M11_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M12_AXI [get_bd_intf_pins axis_signal_gen_v6_5/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M12_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M13_AXI [get_bd_intf_pins axi_bram_ctrl_0/S_AXI] [get_bd_intf_pins ps8_0_axi_periph/M13_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M14_AXI [get_bd_intf_pins axis_signal_gen_v6_6/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M14_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M15_AXI [get_bd_intf_pins axis_readout_v2_0/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M15_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M16_AXI [get_bd_intf_pins axis_readout_v2_1/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M16_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M17_AXI [get_bd_intf_pins axis_switch_avg/S_AXI_CTRL] [get_bd_intf_pins ps8_0_axi_periph/M17_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M18_AXI [get_bd_intf_pins axis_switch_buf/S_AXI_CTRL] [get_bd_intf_pins ps8_0_axi_periph/M18_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M19_AXI [get_bd_intf_pins axi_dma_avg/S_AXI_LITE] [get_bd_intf_pins ps8_0_axi_periph/M19_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M20_AXI [get_bd_intf_pins axi_dma_buf/S_AXI_LITE] [get_bd_intf_pins ps8_0_axi_periph/M20_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M21_AXI [get_bd_intf_pins attn_spi/AXI_LITE] [get_bd_intf_pins ps8_0_axi_periph/M21_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M23_AXI [get_bd_intf_pins dac_bias_spi/AXI_LITE] [get_bd_intf_pins ps8_0_axi_periph/M23_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M24_AXI [get_bd_intf_pins lo_spi/AXI_LITE] [get_bd_intf_pins ps8_0_axi_periph/M24_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M25_AXI [get_bd_intf_pins ps8_0_axi_periph/M25_AXI] [get_bd_intf_pins psf_spi/AXI_LITE]
  connect_bd_intf_net -intf_net sysref_in_1 [get_bd_intf_ports sysref_in] [get_bd_intf_pins usp_rf_data_converter_0/sysref_in]
  connect_bd_intf_net -intf_net usp_rf_data_converter_0_m00_axis [get_bd_intf_pins axis_register_slice_0/S_AXIS] [get_bd_intf_pins usp_rf_data_converter_0/m00_axis]
  connect_bd_intf_net -intf_net usp_rf_data_converter_0_m02_axis [get_bd_intf_pins axis_register_slice_1/S_AXIS] [get_bd_intf_pins usp_rf_data_converter_0/m02_axis]
  connect_bd_intf_net -intf_net usp_rf_data_converter_0_vout00 [get_bd_intf_ports vout0] [get_bd_intf_pins usp_rf_data_converter_0/vout00]
  connect_bd_intf_net -intf_net usp_rf_data_converter_0_vout01 [get_bd_intf_ports vout1] [get_bd_intf_pins usp_rf_data_converter_0/vout01]
  connect_bd_intf_net -intf_net usp_rf_data_converter_0_vout02 [get_bd_intf_ports vout2] [get_bd_intf_pins usp_rf_data_converter_0/vout02]
  connect_bd_intf_net -intf_net usp_rf_data_converter_0_vout10 [get_bd_intf_ports vout3] [get_bd_intf_pins usp_rf_data_converter_0/vout10]
  connect_bd_intf_net -intf_net usp_rf_data_converter_0_vout11 [get_bd_intf_ports vout4] [get_bd_intf_pins usp_rf_data_converter_0/vout11]
  connect_bd_intf_net -intf_net usp_rf_data_converter_0_vout12 [get_bd_intf_ports vout5] [get_bd_intf_pins usp_rf_data_converter_0/vout12]
  connect_bd_intf_net -intf_net usp_rf_data_converter_0_vout13 [get_bd_intf_ports vout6] [get_bd_intf_pins usp_rf_data_converter_0/vout13]
  connect_bd_intf_net -intf_net vin0_1 [get_bd_intf_ports vin0] [get_bd_intf_pins usp_rf_data_converter_0/vin0_01]
  connect_bd_intf_net -intf_net vin1_1 [get_bd_intf_ports vin1] [get_bd_intf_pins usp_rf_data_converter_0/vin0_23]
  connect_bd_intf_net -intf_net zynq_ultra_ps_e_0_M_AXI_HPM0_FPD [get_bd_intf_pins ps8_0_axi_periph/S00_AXI] [get_bd_intf_pins zynq_ultra_ps_e_0/M_AXI_HPM0_FPD]

  # Create port connections
  connect_bd_net -net LO_MISO0_1 [get_bd_ports LO_MISO0] [get_bd_pins lo_spi_mux_0/sdo0_in]
  connect_bd_net -net LO_MISO1_1 [get_bd_ports LO_MISO1] [get_bd_pins lo_spi_mux_0/sdo1_in]
  connect_bd_net -net PMOD1_0_LS_1 [get_bd_ports PMOD1_0_LS] [get_bd_pins axis_tproc64x32_x8_0/start]
  connect_bd_net -net axi_bram_ctrl_0_bram_doutb [get_bd_pins axi_bram_ctrl_0_bram/doutb] [get_bd_pins axis_tproc64x32_x8_0/pmem_do]
  connect_bd_net -net axi_quad_spi_0_io0_o [get_bd_ports ATTN_SI] [get_bd_pins attn_spi/io0_o]
  connect_bd_net -net axi_quad_spi_0_sck_o [get_bd_ports ATTN_CLK] [get_bd_pins attn_spi/sck_o]
  connect_bd_net -net axi_quad_spi_0_ss_o [get_bd_ports ATTN_LE] [get_bd_pins attn_spi/ss_o]
  connect_bd_net -net axis_set_reg_0_dout [get_bd_pins axis_set_reg_0/dout] [get_bd_pins vect2bits_16_0/din]
  connect_bd_net -net axis_tproc64x32_x8_0_pmem_addr [get_bd_pins axi_bram_ctrl_0_bram/addrb] [get_bd_pins axis_tproc64x32_x8_0/pmem_addr]
  connect_bd_net -net bias_constant_0_dout [get_bd_ports BIAS_CE] [get_bd_pins bias_constant_0/dout]
  connect_bd_net -net bias_constant_1_dout [get_bd_ports BIAS_CLR] [get_bd_ports BIAS_RESET] [get_bd_pins bias_constant_1/dout]
  connect_bd_net -net clk_adc0_x2_clk_out1 [get_bd_pins axis_avg_buffer_0/s_axis_aclk] [get_bd_pins axis_avg_buffer_1/s_axis_aclk] [get_bd_pins axis_readout_v2_0/aclk] [get_bd_pins axis_readout_v2_1/aclk] [get_bd_pins axis_register_slice_0/aclk] [get_bd_pins axis_register_slice_1/aclk] [get_bd_pins axis_terminator_0/s_axis_aclk] [get_bd_pins axis_terminator_1/s_axis_aclk] [get_bd_pins clk_adc0_x2/clk_out1] [get_bd_pins rst_adc0_x2/slowest_sync_clk] [get_bd_pins usp_rf_data_converter_0/m0_axis_aclk]
  connect_bd_net -net clk_adc0_x2_locked [get_bd_pins clk_adc0_x2/locked] [get_bd_pins rst_adc0_x2/dcm_locked]
  connect_bd_net -net dac_bias_spi_io0_o [get_bd_ports BIAS_SDI] [get_bd_pins dac_bias_spi/io0_o]
  connect_bd_net -net dac_bias_spi_sck_o [get_bd_ports BIAS_SCLK] [get_bd_pins dac_bias_spi/sck_o]
  connect_bd_net -net dac_bias_spi_ss_o [get_bd_ports BIAS_S] [get_bd_pins dac_bias_spi/ss_o]
  connect_bd_net -net dig_lconstant_1_dout [get_bd_ports RST_5VEN] [get_bd_pins dig_lconstant_1/dout]
  connect_bd_net -net io1_i_0_1 [get_bd_ports SDO] [get_bd_pins psf_spi/io1_i]
  connect_bd_net -net io1_i_0_2 [get_bd_ports BIAS_SDO] [get_bd_pins dac_bias_spi/io1_i]
  connect_bd_net -net lo_spi_io0_o [get_bd_ports LO_MOSI] [get_bd_pins lo_spi/io0_o]
  connect_bd_net -net lo_spi_mux_0_sdo_out [get_bd_pins lo_spi/io1_i] [get_bd_pins lo_spi_mux_0/sdo_out]
  connect_bd_net -net lo_spi_mux_0_ss0_out [get_bd_ports LO_CS0] [get_bd_pins lo_spi_mux_0/ss0_out]
  connect_bd_net -net lo_spi_mux_0_ss1_out [get_bd_ports LO_CS1] [get_bd_pins lo_spi_mux_0/ss1_out]
  connect_bd_net -net lo_spi_sck_o [get_bd_ports LO_SCLK] [get_bd_pins lo_spi/sck_o]
  connect_bd_net -net lo_spi_ss_o [get_bd_pins lo_spi/ss_o] [get_bd_pins lo_spi_mux_0/ss_in]
  connect_bd_net -net psf_spi_io0_o [get_bd_ports SDI] [get_bd_pins psf_spi/io0_o]
  connect_bd_net -net psf_spi_sck_o [get_bd_ports SCLK] [get_bd_pins psf_spi/sck_o]
  connect_bd_net -net psf_spi_ss_o [get_bd_ports S] [get_bd_pins psf_spi/ss_o]
  connect_bd_net -net rst_adc0_peripheral_reset [get_bd_pins clk_adc0_x2/reset] [get_bd_pins rst_adc0/peripheral_reset]
  connect_bd_net -net rst_adc0_x2_peripheral_aresetn [get_bd_pins axis_avg_buffer_0/s_axis_aresetn] [get_bd_pins axis_avg_buffer_1/s_axis_aresetn] [get_bd_pins axis_readout_v2_0/aresetn] [get_bd_pins axis_readout_v2_1/aresetn] [get_bd_pins axis_register_slice_0/aresetn] [get_bd_pins axis_register_slice_1/aresetn] [get_bd_pins axis_terminator_0/s_axis_aresetn] [get_bd_pins axis_terminator_1/s_axis_aresetn] [get_bd_pins rst_adc0_x2/peripheral_aresetn] [get_bd_pins usp_rf_data_converter_0/m0_axis_aresetn]
  connect_bd_net -net rst_dac0_peripheral_aresetn [get_bd_pins axis_clk_cnvrt_avg_0/m_axis_aresetn] [get_bd_pins axis_clk_cnvrt_avg_1/m_axis_aresetn] [get_bd_pins axis_clk_cnvrt_gen_3/s_axis_aresetn] [get_bd_pins axis_clk_cnvrt_gen_4/s_axis_aresetn] [get_bd_pins axis_clk_cnvrt_gen_5/s_axis_aresetn] [get_bd_pins axis_clk_cnvrt_gen_6/s_axis_aresetn] [get_bd_pins axis_constant_0/m_axis_aresetn] [get_bd_pins axis_constant_1/m_axis_aresetn] [get_bd_pins axis_set_reg_0/s_axis_aresetn] [get_bd_pins axis_signal_gen_v6_0/aresetn] [get_bd_pins axis_signal_gen_v6_1/aresetn] [get_bd_pins axis_signal_gen_v6_2/aresetn] [get_bd_pins axis_tproc64x32_x8_0/aresetn] [get_bd_pins rst_dac0/peripheral_aresetn] [get_bd_pins system_ila_1/resetn] [get_bd_pins usp_rf_data_converter_0/s0_axis_aresetn]
  connect_bd_net -net rst_dac1_peripheral_aresetn [get_bd_pins axis_clk_cnvrt_gen_3/m_axis_aresetn] [get_bd_pins axis_clk_cnvrt_gen_4/m_axis_aresetn] [get_bd_pins axis_clk_cnvrt_gen_5/m_axis_aresetn] [get_bd_pins axis_clk_cnvrt_gen_6/m_axis_aresetn] [get_bd_pins axis_signal_gen_v6_3/aresetn] [get_bd_pins axis_signal_gen_v6_4/aresetn] [get_bd_pins axis_signal_gen_v6_5/aresetn] [get_bd_pins axis_signal_gen_v6_6/aresetn] [get_bd_pins rst_dac1/peripheral_aresetn] [get_bd_pins usp_rf_data_converter_0/s1_axis_aresetn]
  connect_bd_net -net rst_ps8_0_99M_peripheral_aresetn [get_bd_pins attn_spi/s_axi_aresetn] [get_bd_pins axi_bram_ctrl_0/s_axi_aresetn] [get_bd_pins axi_dma_avg/axi_resetn] [get_bd_pins axi_dma_buf/axi_resetn] [get_bd_pins axi_dma_gen/axi_resetn] [get_bd_pins axi_dma_tproc/axi_resetn] [get_bd_pins axi_smc/aresetn] [get_bd_pins axis_avg_buffer_0/m_axis_aresetn] [get_bd_pins axis_avg_buffer_0/s_axi_aresetn] [get_bd_pins axis_avg_buffer_1/m_axis_aresetn] [get_bd_pins axis_avg_buffer_1/s_axi_aresetn] [get_bd_pins axis_clk_cnvrt_avg_0/s_axis_aresetn] [get_bd_pins axis_clk_cnvrt_avg_1/s_axis_aresetn] [get_bd_pins axis_readout_v2_0/s_axi_aresetn] [get_bd_pins axis_readout_v2_1/s_axi_aresetn] [get_bd_pins axis_signal_gen_v6_0/s0_axis_aresetn] [get_bd_pins axis_signal_gen_v6_0/s_axi_aresetn] [get_bd_pins axis_signal_gen_v6_1/s0_axis_aresetn] [get_bd_pins axis_signal_gen_v6_1/s_axi_aresetn] [get_bd_pins axis_signal_gen_v6_2/s0_axis_aresetn] [get_bd_pins axis_signal_gen_v6_2/s_axi_aresetn] [get_bd_pins axis_signal_gen_v6_3/s0_axis_aresetn] [get_bd_pins axis_signal_gen_v6_3/s_axi_aresetn] [get_bd_pins axis_signal_gen_v6_4/s0_axis_aresetn] [get_bd_pins axis_signal_gen_v6_4/s_axi_aresetn] [get_bd_pins axis_signal_gen_v6_5/s0_axis_aresetn] [get_bd_pins axis_signal_gen_v6_5/s_axi_aresetn] [get_bd_pins axis_signal_gen_v6_6/s0_axis_aresetn] [get_bd_pins axis_signal_gen_v6_6/s_axi_aresetn] [get_bd_pins axis_switch_avg/aresetn] [get_bd_pins axis_switch_avg/s_axi_ctrl_aresetn] [get_bd_pins axis_switch_buf/aresetn] [get_bd_pins axis_switch_buf/s_axi_ctrl_aresetn] [get_bd_pins axis_switch_gen/aresetn] [get_bd_pins axis_switch_gen/s_axi_ctrl_aresetn] [get_bd_pins axis_tproc64x32_x8_0/m0_axis_aresetn] [get_bd_pins axis_tproc64x32_x8_0/s0_axis_aresetn] [get_bd_pins axis_tproc64x32_x8_0/s_axi_aresetn] [get_bd_pins dac_bias_spi/s_axi_aresetn] [get_bd_pins lo_spi/s_axi_aresetn] [get_bd_pins ps8_0_axi_periph/ARESETN] [get_bd_pins ps8_0_axi_periph/M00_ARESETN] [get_bd_pins ps8_0_axi_periph/M01_ARESETN] [get_bd_pins ps8_0_axi_periph/M02_ARESETN] [get_bd_pins ps8_0_axi_periph/M03_ARESETN] [get_bd_pins ps8_0_axi_periph/M04_ARESETN] [get_bd_pins ps8_0_axi_periph/M05_ARESETN] [get_bd_pins ps8_0_axi_periph/M06_ARESETN] [get_bd_pins ps8_0_axi_periph/M07_ARESETN] [get_bd_pins ps8_0_axi_periph/M08_ARESETN] [get_bd_pins ps8_0_axi_periph/M09_ARESETN] [get_bd_pins ps8_0_axi_periph/M10_ARESETN] [get_bd_pins ps8_0_axi_periph/M11_ARESETN] [get_bd_pins ps8_0_axi_periph/M12_ARESETN] [get_bd_pins ps8_0_axi_periph/M13_ARESETN] [get_bd_pins ps8_0_axi_periph/M14_ARESETN] [get_bd_pins ps8_0_axi_periph/M15_ARESETN] [get_bd_pins ps8_0_axi_periph/M16_ARESETN] [get_bd_pins ps8_0_axi_periph/M17_ARESETN] [get_bd_pins ps8_0_axi_periph/M18_ARESETN] [get_bd_pins ps8_0_axi_periph/M19_ARESETN] [get_bd_pins ps8_0_axi_periph/M20_ARESETN] [get_bd_pins ps8_0_axi_periph/M21_ARESETN] [get_bd_pins ps8_0_axi_periph/M22_ARESETN] [get_bd_pins ps8_0_axi_periph/M23_ARESETN] [get_bd_pins ps8_0_axi_periph/M24_ARESETN] [get_bd_pins ps8_0_axi_periph/M25_ARESETN] [get_bd_pins ps8_0_axi_periph/S00_ARESETN] [get_bd_pins psf_spi/s_axi_aresetn] [get_bd_pins rst_100/peripheral_aresetn] [get_bd_pins system_ila_0/resetn] [get_bd_pins usp_rf_data_converter_0/s_axi_aresetn]
  connect_bd_net -net usp_rf_data_converter_0_clk_adc0 [get_bd_pins clk_adc0_x2/clk_in1] [get_bd_pins rst_adc0/slowest_sync_clk] [get_bd_pins usp_rf_data_converter_0/clk_adc0]
  connect_bd_net -net usp_rf_data_converter_0_clk_dac0 [get_bd_pins axi_bram_ctrl_0_bram/clkb] [get_bd_pins axis_clk_cnvrt_avg_0/m_axis_aclk] [get_bd_pins axis_clk_cnvrt_avg_1/m_axis_aclk] [get_bd_pins axis_clk_cnvrt_gen_3/s_axis_aclk] [get_bd_pins axis_clk_cnvrt_gen_4/s_axis_aclk] [get_bd_pins axis_clk_cnvrt_gen_5/s_axis_aclk] [get_bd_pins axis_clk_cnvrt_gen_6/s_axis_aclk] [get_bd_pins axis_constant_0/m_axis_aclk] [get_bd_pins axis_constant_1/m_axis_aclk] [get_bd_pins axis_set_reg_0/s_axis_aclk] [get_bd_pins axis_signal_gen_v6_0/aclk] [get_bd_pins axis_signal_gen_v6_1/aclk] [get_bd_pins axis_signal_gen_v6_2/aclk] [get_bd_pins axis_tproc64x32_x8_0/aclk] [get_bd_pins rst_dac0/slowest_sync_clk] [get_bd_pins system_ila_1/clk] [get_bd_pins usp_rf_data_converter_0/clk_dac0] [get_bd_pins usp_rf_data_converter_0/s0_axis_aclk]
  connect_bd_net -net usp_rf_data_converter_0_clk_dac1 [get_bd_pins axis_clk_cnvrt_gen_3/m_axis_aclk] [get_bd_pins axis_clk_cnvrt_gen_4/m_axis_aclk] [get_bd_pins axis_clk_cnvrt_gen_5/m_axis_aclk] [get_bd_pins axis_clk_cnvrt_gen_6/m_axis_aclk] [get_bd_pins axis_signal_gen_v6_3/aclk] [get_bd_pins axis_signal_gen_v6_4/aclk] [get_bd_pins axis_signal_gen_v6_5/aclk] [get_bd_pins axis_signal_gen_v6_6/aclk] [get_bd_pins rst_dac1/slowest_sync_clk] [get_bd_pins usp_rf_data_converter_0/clk_dac1] [get_bd_pins usp_rf_data_converter_0/s1_axis_aclk]
  connect_bd_net -net vect2bits_16_0_dout0 [get_bd_ports PMOD0_0_LS] [get_bd_pins vect2bits_16_0/dout0]
  connect_bd_net -net vect2bits_16_0_dout1 [get_bd_ports PMOD0_1_LS] [get_bd_pins vect2bits_16_0/dout1]
  connect_bd_net -net vect2bits_16_0_dout2 [get_bd_ports PMOD0_2_LS] [get_bd_pins vect2bits_16_0/dout2]
  connect_bd_net -net vect2bits_16_0_dout3 [get_bd_ports PMOD0_3_LS] [get_bd_pins vect2bits_16_0/dout3]
  connect_bd_net -net vect2bits_16_0_dout4 [get_bd_ports PMOD0_4_LS] [get_bd_pins vect2bits_16_0/dout4]
  connect_bd_net -net vect2bits_16_0_dout5 [get_bd_ports PMOD0_5_LS] [get_bd_pins vect2bits_16_0/dout5]
  connect_bd_net -net vect2bits_16_0_dout6 [get_bd_ports PMOD0_6_LS] [get_bd_pins vect2bits_16_0/dout6]
  connect_bd_net -net vect2bits_16_0_dout7 [get_bd_ports PMOD0_7_LS] [get_bd_pins vect2bits_16_0/dout7]
  connect_bd_net -net vect2bits_16_0_dout14 [get_bd_pins axis_avg_buffer_0/trigger] [get_bd_pins system_ila_0/probe0] [get_bd_pins system_ila_1/probe0] [get_bd_pins vect2bits_16_0/dout14]
  connect_bd_net -net vect2bits_16_0_dout15 [get_bd_pins axis_avg_buffer_1/trigger] [get_bd_pins vect2bits_16_0/dout15]
  connect_bd_net -net xlconstant_0_dout [get_bd_pins axi_bram_ctrl_0_bram/dinb] [get_bd_pins xlconstant_0/dout]
  connect_bd_net -net xlconstant_1_dout [get_bd_pins axi_bram_ctrl_0_bram/enb] [get_bd_pins xlconstant_1/dout]
  connect_bd_net -net xlconstant_2_dout [get_bd_pins axi_bram_ctrl_0_bram/rstb] [get_bd_pins xlconstant_2/dout]
  connect_bd_net -net xlconstant_3_dout [get_bd_pins axi_bram_ctrl_0_bram/web] [get_bd_pins xlconstant_3/dout]
  connect_bd_net -net zynq_ultra_ps_e_0_pl_clk0 [get_bd_pins attn_spi/ext_spi_clk] [get_bd_pins attn_spi/s_axi_aclk] [get_bd_pins axi_bram_ctrl_0/s_axi_aclk] [get_bd_pins axi_dma_avg/m_axi_s2mm_aclk] [get_bd_pins axi_dma_avg/s_axi_lite_aclk] [get_bd_pins axi_dma_buf/m_axi_s2mm_aclk] [get_bd_pins axi_dma_buf/s_axi_lite_aclk] [get_bd_pins axi_dma_gen/m_axi_mm2s_aclk] [get_bd_pins axi_dma_gen/s_axi_lite_aclk] [get_bd_pins axi_dma_tproc/m_axi_mm2s_aclk] [get_bd_pins axi_dma_tproc/m_axi_s2mm_aclk] [get_bd_pins axi_dma_tproc/s_axi_lite_aclk] [get_bd_pins axi_smc/aclk] [get_bd_pins axis_avg_buffer_0/m_axis_aclk] [get_bd_pins axis_avg_buffer_0/s_axi_aclk] [get_bd_pins axis_avg_buffer_1/m_axis_aclk] [get_bd_pins axis_avg_buffer_1/s_axi_aclk] [get_bd_pins axis_clk_cnvrt_avg_0/s_axis_aclk] [get_bd_pins axis_clk_cnvrt_avg_1/s_axis_aclk] [get_bd_pins axis_readout_v2_0/s_axi_aclk] [get_bd_pins axis_readout_v2_1/s_axi_aclk] [get_bd_pins axis_signal_gen_v6_0/s0_axis_aclk] [get_bd_pins axis_signal_gen_v6_0/s_axi_aclk] [get_bd_pins axis_signal_gen_v6_1/s0_axis_aclk] [get_bd_pins axis_signal_gen_v6_1/s_axi_aclk] [get_bd_pins axis_signal_gen_v6_2/s0_axis_aclk] [get_bd_pins axis_signal_gen_v6_2/s_axi_aclk] [get_bd_pins axis_signal_gen_v6_3/s0_axis_aclk] [get_bd_pins axis_signal_gen_v6_3/s_axi_aclk] [get_bd_pins axis_signal_gen_v6_4/s0_axis_aclk] [get_bd_pins axis_signal_gen_v6_4/s_axi_aclk] [get_bd_pins axis_signal_gen_v6_5/s0_axis_aclk] [get_bd_pins axis_signal_gen_v6_5/s_axi_aclk] [get_bd_pins axis_signal_gen_v6_6/s0_axis_aclk] [get_bd_pins axis_signal_gen_v6_6/s_axi_aclk] [get_bd_pins axis_switch_avg/aclk] [get_bd_pins axis_switch_avg/s_axi_ctrl_aclk] [get_bd_pins axis_switch_buf/aclk] [get_bd_pins axis_switch_buf/s_axi_ctrl_aclk] [get_bd_pins axis_switch_gen/aclk] [get_bd_pins axis_switch_gen/s_axi_ctrl_aclk] [get_bd_pins axis_tproc64x32_x8_0/m0_axis_aclk] [get_bd_pins axis_tproc64x32_x8_0/s0_axis_aclk] [get_bd_pins axis_tproc64x32_x8_0/s_axi_aclk] [get_bd_pins dac_bias_spi/ext_spi_clk] [get_bd_pins dac_bias_spi/s_axi_aclk] [get_bd_pins lo_spi/ext_spi_clk] [get_bd_pins lo_spi/s_axi_aclk] [get_bd_pins ps8_0_axi_periph/ACLK] [get_bd_pins ps8_0_axi_periph/M00_ACLK] [get_bd_pins ps8_0_axi_periph/M01_ACLK] [get_bd_pins ps8_0_axi_periph/M02_ACLK] [get_bd_pins ps8_0_axi_periph/M03_ACLK] [get_bd_pins ps8_0_axi_periph/M04_ACLK] [get_bd_pins ps8_0_axi_periph/M05_ACLK] [get_bd_pins ps8_0_axi_periph/M06_ACLK] [get_bd_pins ps8_0_axi_periph/M07_ACLK] [get_bd_pins ps8_0_axi_periph/M08_ACLK] [get_bd_pins ps8_0_axi_periph/M09_ACLK] [get_bd_pins ps8_0_axi_periph/M10_ACLK] [get_bd_pins ps8_0_axi_periph/M11_ACLK] [get_bd_pins ps8_0_axi_periph/M12_ACLK] [get_bd_pins ps8_0_axi_periph/M13_ACLK] [get_bd_pins ps8_0_axi_periph/M14_ACLK] [get_bd_pins ps8_0_axi_periph/M15_ACLK] [get_bd_pins ps8_0_axi_periph/M16_ACLK] [get_bd_pins ps8_0_axi_periph/M17_ACLK] [get_bd_pins ps8_0_axi_periph/M18_ACLK] [get_bd_pins ps8_0_axi_periph/M19_ACLK] [get_bd_pins ps8_0_axi_periph/M20_ACLK] [get_bd_pins ps8_0_axi_periph/M21_ACLK] [get_bd_pins ps8_0_axi_periph/M22_ACLK] [get_bd_pins ps8_0_axi_periph/M23_ACLK] [get_bd_pins ps8_0_axi_periph/M24_ACLK] [get_bd_pins ps8_0_axi_periph/M25_ACLK] [get_bd_pins ps8_0_axi_periph/S00_ACLK] [get_bd_pins psf_spi/ext_spi_clk] [get_bd_pins psf_spi/s_axi_aclk] [get_bd_pins rst_100/slowest_sync_clk] [get_bd_pins system_ila_0/clk] [get_bd_pins usp_rf_data_converter_0/s_axi_aclk] [get_bd_pins zynq_ultra_ps_e_0/maxihpm0_fpd_aclk] [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] [get_bd_pins zynq_ultra_ps_e_0/saxihpc0_fpd_aclk]
  connect_bd_net -net zynq_ultra_ps_e_0_pl_clk1 [get_bd_ports PWR_SYNC] [get_bd_pins zynq_ultra_ps_e_0/pl_clk1]
  connect_bd_net -net zynq_ultra_ps_e_0_pl_resetn0 [get_bd_pins rst_100/ext_reset_in] [get_bd_pins rst_adc0/ext_reset_in] [get_bd_pins rst_adc0_x2/ext_reset_in] [get_bd_pins rst_dac0/ext_reset_in] [get_bd_pins rst_dac1/ext_reset_in] [get_bd_pins zynq_ultra_ps_e_0/pl_resetn0]

  # Create address segments
  assign_bd_address -offset 0x00000000 -range 0x80000000 -target_address_space [get_bd_addr_spaces axi_dma_avg/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_DDR_LOW] -force
  assign_bd_address -offset 0xC0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_dma_avg/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_QSPI] -force
  assign_bd_address -offset 0x00000000 -range 0x80000000 -target_address_space [get_bd_addr_spaces axi_dma_buf/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_DDR_LOW] -force
  assign_bd_address -offset 0xC0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_dma_buf/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_QSPI] -force
  assign_bd_address -offset 0x00000000 -range 0x80000000 -target_address_space [get_bd_addr_spaces axi_dma_gen/Data_MM2S] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_DDR_LOW] -force
  assign_bd_address -offset 0xC0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_dma_gen/Data_MM2S] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_QSPI] -force
  assign_bd_address -offset 0x00000000 -range 0x80000000 -target_address_space [get_bd_addr_spaces axi_dma_tproc/Data_MM2S] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_DDR_LOW] -force
  assign_bd_address -offset 0x00000000 -range 0x80000000 -target_address_space [get_bd_addr_spaces axi_dma_tproc/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_DDR_LOW] -force
  assign_bd_address -offset 0xC0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_dma_tproc/Data_MM2S] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_QSPI] -force
  assign_bd_address -offset 0xC0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_dma_tproc/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_QSPI] -force
  assign_bd_address -offset 0xA0010000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs attn_spi/AXI_LITE/Reg] -force
  assign_bd_address -offset 0xA0000000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axi_bram_ctrl_0/S_AXI/Mem0] -force
  assign_bd_address -offset 0xA0040000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axi_dma_avg/S_AXI_LITE/Reg] -force
  assign_bd_address -offset 0xA0041000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axi_dma_buf/S_AXI_LITE/Reg] -force
  assign_bd_address -offset 0xA0042000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axi_dma_gen/S_AXI_LITE/Reg] -force
  assign_bd_address -offset 0xA0043000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axi_dma_tproc/S_AXI_LITE/Reg] -force
  assign_bd_address -offset 0xA0044000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_avg_buffer_0/s_axi/reg0] -force
  assign_bd_address -offset 0xA0045000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_avg_buffer_1/s_axi/reg0] -force
  assign_bd_address -offset 0xA0046000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_readout_v2_0/s_axi/reg0] -force
  assign_bd_address -offset 0xA0047000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_readout_v2_1/s_axi/reg0] -force
  assign_bd_address -offset 0xA0048000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_signal_gen_v6_0/s_axi/reg0] -force
  assign_bd_address -offset 0xA0049000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_signal_gen_v6_1/s_axi/reg0] -force
  assign_bd_address -offset 0xA004A000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_signal_gen_v6_2/s_axi/reg0] -force
  assign_bd_address -offset 0xA004B000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_signal_gen_v6_3/s_axi/reg0] -force
  assign_bd_address -offset 0xA004C000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_signal_gen_v6_4/s_axi/reg0] -force
  assign_bd_address -offset 0xA004D000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_signal_gen_v6_5/s_axi/reg0] -force
  assign_bd_address -offset 0xA004E000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_signal_gen_v6_6/s_axi/reg0] -force
  assign_bd_address -offset 0xA004F000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_switch_avg/S_AXI_CTRL/Reg] -force
  assign_bd_address -offset 0xA0050000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_switch_buf/S_AXI_CTRL/Reg] -force
  assign_bd_address -offset 0xA0051000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_switch_gen/S_AXI_CTRL/Reg] -force
  assign_bd_address -offset 0x000400000000 -range 0x000100000000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_tproc64x32_x8_0/s_axi/reg0] -force
  assign_bd_address -offset 0xA0030000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs dac_bias_spi/AXI_LITE/Reg] -force
  assign_bd_address -offset 0xA0060000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs lo_spi/AXI_LITE/Reg] -force
  assign_bd_address -offset 0xA0070000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs psf_spi/AXI_LITE/Reg] -force
  assign_bd_address -offset 0xA0080000 -range 0x00040000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs usp_rf_data_converter_0/s_axi/Reg] -force

  # Perform GUI Layout
  regenerate_bd_layout -layout_string {
   "ActiveEmotionalView":"Default View",
   "Default View_ScaleFactor":"0.397519",
   "Default View_TopLeft":"-1892,0",
   "ExpandedHierarchyInLayout":"",
   "guistr":"# # String gsaved with Nlview 7.0r4  2019-12-20 bk=1.5203 VDI=41 GEI=36 GUI=JA:10.0 TLS
#  -string -flagsOSRD
preplace port adc0_clk -pg 1 -lvl 9 -x 4020 -y 2430 -defaultsOSRD -right
preplace port dac0_clk -pg 1 -lvl 9 -x 4020 -y 2470 -defaultsOSRD -right
preplace port dac1_clk -pg 1 -lvl 9 -x 4020 -y 2450 -defaultsOSRD -right
preplace port sysref_in -pg 1 -lvl 9 -x 4020 -y 2410 -defaultsOSRD -right
preplace port vin0 -pg 1 -lvl 9 -x 4020 -y 2370 -defaultsOSRD -right
preplace port vin1 -pg 1 -lvl 9 -x 4020 -y 2390 -defaultsOSRD -right
preplace port vout0 -pg 1 -lvl 9 -x 4020 -y 2050 -defaultsOSRD
preplace port vout1 -pg 1 -lvl 9 -x 4020 -y 2070 -defaultsOSRD
preplace port vout2 -pg 1 -lvl 9 -x 4020 -y 2090 -defaultsOSRD
preplace port vout3 -pg 1 -lvl 9 -x 4020 -y 2110 -defaultsOSRD
preplace port vout4 -pg 1 -lvl 9 -x 4020 -y 2130 -defaultsOSRD
preplace port vout5 -pg 1 -lvl 9 -x 4020 -y 2150 -defaultsOSRD
preplace port vout6 -pg 1 -lvl 9 -x 4020 -y 2170 -defaultsOSRD
preplace port ATTN_CLK -pg 1 -lvl 9 -x 4020 -y 1320 -defaultsOSRD
preplace port ATTN_SI -pg 1 -lvl 9 -x 4020 -y 1300 -defaultsOSRD
preplace port BIAS_SCLK -pg 1 -lvl 9 -x 4020 -y 870 -defaultsOSRD
preplace port BIAS_SDI -pg 1 -lvl 9 -x 4020 -y 830 -defaultsOSRD
preplace port BIAS_SDO -pg 1 -lvl 9 -x 4020 -y 850 -defaultsOSRD -right
preplace port LO_CS0 -pg 1 -lvl 9 -x 4020 -y 1000 -defaultsOSRD
preplace port LO_CS1 -pg 1 -lvl 9 -x 4020 -y 810 -defaultsOSRD
preplace port LO_MISO0 -pg 1 -lvl 9 -x 4020 -y 960 -defaultsOSRD -right
preplace port LO_MISO1 -pg 1 -lvl 9 -x 4020 -y 980 -defaultsOSRD -right
preplace port LO_MOSI -pg 1 -lvl 9 -x 4020 -y 910 -defaultsOSRD
preplace port LO_SCLK -pg 1 -lvl 9 -x 4020 -y 940 -defaultsOSRD
preplace port PMOD0_0_LS -pg 1 -lvl 9 -x 4020 -y 1520 -defaultsOSRD
preplace port PMOD0_1_LS -pg 1 -lvl 9 -x 4020 -y 1540 -defaultsOSRD
preplace port PMOD0_2_LS -pg 1 -lvl 9 -x 4020 -y 1560 -defaultsOSRD
preplace port PMOD0_3_LS -pg 1 -lvl 9 -x 4020 -y 1580 -defaultsOSRD
preplace port PMOD0_4_LS -pg 1 -lvl 9 -x 4020 -y 1600 -defaultsOSRD
preplace port PMOD0_5_LS -pg 1 -lvl 9 -x 4020 -y 1620 -defaultsOSRD
preplace port PMOD0_6_LS -pg 1 -lvl 9 -x 4020 -y 1640 -defaultsOSRD
preplace port PMOD0_7_LS -pg 1 -lvl 9 -x 4020 -y 1660 -defaultsOSRD
preplace port PMOD1_0_LS -pg 1 -lvl 0 -x -30 -y 2030 -defaultsOSRD
preplace port SCLK -pg 1 -lvl 9 -x 4020 -y 1140 -defaultsOSRD
preplace port SDI -pg 1 -lvl 9 -x 4020 -y 1100 -defaultsOSRD
preplace port SDO -pg 1 -lvl 9 -x 4020 -y 1120 -defaultsOSRD -right
preplace portBus ATTN_LE -pg 1 -lvl 9 -x 4020 -y 1340 -defaultsOSRD
preplace portBus BIAS_CE -pg 1 -lvl 9 -x 4020 -y 560 -defaultsOSRD
preplace portBus BIAS_CLR -pg 1 -lvl 9 -x 4020 -y 650 -defaultsOSRD
preplace portBus BIAS_RESET -pg 1 -lvl 9 -x 4020 -y 670 -defaultsOSRD
preplace portBus BIAS_S -pg 1 -lvl 9 -x 4020 -y 890 -defaultsOSRD
preplace portBus PWR_SYNC -pg 1 -lvl 9 -x 4020 -y 1410 -defaultsOSRD
preplace portBus RST_5VEN -pg 1 -lvl 9 -x 4020 -y 450 -defaultsOSRD
preplace portBus S -pg 1 -lvl 9 -x 4020 -y 1160 -defaultsOSRD
preplace inst attn_spi -pg 1 -lvl 6 -x 2910 -y 1320 -defaultsOSRD
preplace inst axi_bram_ctrl_0 -pg 1 -lvl 1 -x 150 -y 2110 -defaultsOSRD
preplace inst axi_bram_ctrl_0_bram -pg 1 -lvl 2 -x 580 -y 2300 -defaultsOSRD
preplace inst axi_dma_avg -pg 1 -lvl 2 -x 580 -y 710 -defaultsOSRD
preplace inst axi_dma_buf -pg 1 -lvl 2 -x 580 -y 890 -defaultsOSRD -resize 320 156
preplace inst axi_dma_gen -pg 1 -lvl 2 -x 580 -y 1060 -defaultsOSRD
preplace inst axi_dma_tproc -pg 1 -lvl 2 -x 580 -y 1250 -defaultsOSRD
preplace inst axi_smc -pg 1 -lvl 2 -x 580 -y 490 -defaultsOSRD
preplace inst axis_avg_buffer_0 -pg 1 -lvl 6 -x 2910 -y 3490 -defaultsOSRD
preplace inst axis_avg_buffer_1 -pg 1 -lvl 6 -x 2910 -y 3890 -defaultsOSRD -resize 220 236
preplace inst axis_clk_cnvrt_avg_0 -pg 1 -lvl 7 -x 3360 -y 2400 -defaultsOSRD
preplace inst axis_clk_cnvrt_avg_1 -pg 1 -lvl 7 -x 3360 -y 3020 -defaultsOSRD -resize 220 156
preplace inst axis_clk_cnvrt_gen_3 -pg 1 -lvl 3 -x 1240 -y 2430 -defaultsOSRD
preplace inst axis_clk_cnvrt_gen_4 -pg 1 -lvl 3 -x 1240 -y 2610 -defaultsOSRD -resize 220 156
preplace inst axis_clk_cnvrt_gen_5 -pg 1 -lvl 3 -x 1240 -y 2790 -defaultsOSRD -resize 220 156
preplace inst axis_clk_cnvrt_gen_6 -pg 1 -lvl 3 -x 1240 -y 2970 -defaultsOSRD -resize 220 156
preplace inst axis_constant_0 -pg 1 -lvl 1 -x 150 -y 1840 -defaultsOSRD
preplace inst axis_constant_1 -pg 1 -lvl 1 -x 150 -y 1960 -defaultsOSRD -resize 220 96
preplace inst axis_readout_v2_0 -pg 1 -lvl 5 -x 2280 -y 3550 -defaultsOSRD
preplace inst axis_readout_v2_1 -pg 1 -lvl 5 -x 2280 -y 3800 -defaultsOSRD
preplace inst axis_register_slice_0 -pg 1 -lvl 4 -x 1780 -y 3500 -defaultsOSRD
preplace inst axis_register_slice_1 -pg 1 -lvl 4 -x 1780 -y 3660 -defaultsOSRD -resize 180 116
preplace inst axis_set_reg_0 -pg 1 -lvl 5 -x 2280 -y 1540 -defaultsOSRD
preplace inst axis_signal_gen_v6_0 -pg 1 -lvl 5 -x 2280 -y 1740 -defaultsOSRD
preplace inst axis_signal_gen_v6_1 -pg 1 -lvl 5 -x 2280 -y 2000 -defaultsOSRD -resize 220 236
preplace inst axis_signal_gen_v6_2 -pg 1 -lvl 5 -x 2280 -y 2260 -defaultsOSRD -resize 220 236
preplace inst axis_signal_gen_v6_3 -pg 1 -lvl 5 -x 2280 -y 2520 -defaultsOSRD -resize 220 236
preplace inst axis_signal_gen_v6_4 -pg 1 -lvl 5 -x 2280 -y 2780 -defaultsOSRD -resize 220 236
preplace inst axis_signal_gen_v6_5 -pg 1 -lvl 5 -x 2280 -y 3040 -defaultsOSRD -resize 220 236
preplace inst axis_signal_gen_v6_6 -pg 1 -lvl 5 -x 2280 -y 3300 -defaultsOSRD -resize 220 236
preplace inst axis_switch_avg -pg 1 -lvl 7 -x 3360 -y 2600 -defaultsOSRD
preplace inst axis_switch_buf -pg 1 -lvl 7 -x 3360 -y 2820 -defaultsOSRD -resize 240 196
preplace inst axis_switch_gen -pg 1 -lvl 3 -x 1240 -y 2200 -defaultsOSRD
preplace inst axis_terminator_0 -pg 1 -lvl 6 -x 2910 -y 3240 -defaultsOSRD
preplace inst axis_terminator_1 -pg 1 -lvl 6 -x 2910 -y 3690 -defaultsOSRD -resize 160 116
preplace inst axis_tproc64x32_x8_0 -pg 1 -lvl 2 -x 580 -y 1970 -defaultsOSRD
preplace inst bias_constant_0 -pg 1 -lvl 8 -x 3780 -y 560 -defaultsOSRD
preplace inst bias_constant_1 -pg 1 -lvl 8 -x 3780 -y 660 -defaultsOSRD
preplace inst clk_adc0_x2 -pg 1 -lvl 3 -x 1240 -y 1870 -defaultsOSRD
preplace inst dac_bias_spi -pg 1 -lvl 6 -x 2910 -y 730 -defaultsOSRD
preplace inst dig_lconstant_1 -pg 1 -lvl 8 -x 3780 -y 450 -defaultsOSRD
preplace inst lo_spi -pg 1 -lvl 6 -x 2910 -y 930 -defaultsOSRD
preplace inst lo_spi_mux_0 -pg 1 -lvl 7 -x 3360 -y 980 -defaultsOSRD
preplace inst ps8_0_axi_periph -pg 1 -lvl 5 -x 2280 -y 620 -defaultsOSRD
preplace inst psf_spi -pg 1 -lvl 6 -x 2910 -y 1130 -defaultsOSRD
preplace inst rst_100 -pg 1 -lvl 3 -x 1240 -y 560 -defaultsOSRD
preplace inst rst_adc0 -pg 1 -lvl 3 -x 1240 -y 740 -defaultsOSRD -resize 320 156
preplace inst rst_adc0_x2 -pg 1 -lvl 3 -x 1240 -y 920 -defaultsOSRD -resize 320 156
preplace inst rst_dac0 -pg 1 -lvl 3 -x 1240 -y 1100 -defaultsOSRD -resize 320 156
preplace inst rst_dac1 -pg 1 -lvl 3 -x 1240 -y 1280 -defaultsOSRD -resize 320 156
preplace inst system_ila_0 -pg 1 -lvl 7 -x 3360 -y 3200 -defaultsOSRD -resize 157 152
preplace inst system_ila_1 -pg 1 -lvl 7 -x 3360 -y 3380 -defaultsOSRD -resize 157 152
preplace inst usp_rf_data_converter_0 -pg 1 -lvl 8 -x 3780 -y 2130 -defaultsOSRD
preplace inst vect2bits_16_0 -pg 1 -lvl 8 -x 3780 -y 1670 -defaultsOSRD
preplace inst xlconstant_0 -pg 1 -lvl 1 -x 150 -y 2230 -defaultsOSRD
preplace inst xlconstant_1 -pg 1 -lvl 1 -x 150 -y 2340 -defaultsOSRD -resize 140 88
preplace inst xlconstant_2 -pg 1 -lvl 1 -x 150 -y 2450 -defaultsOSRD -resize 140 88
preplace inst xlconstant_3 -pg 1 -lvl 1 -x 150 -y 2560 -defaultsOSRD -resize 140 88
preplace inst zynq_ultra_ps_e_0 -pg 1 -lvl 3 -x 1240 -y 360 -defaultsOSRD
preplace netloc PMOD1_0_LS_1 1 0 2 N 2030 320J
preplace netloc LO_MISO0_1 1 6 3 3160J 870 3500 950 3940
preplace netloc LO_MISO1_1 1 6 3 3120J 860 3520 870 3950
preplace netloc axi_bram_ctrl_0_bram_doutb 1 1 1 390 2120n
preplace netloc axi_quad_spi_0_io0_o 1 6 3 NJ 1300 NJ 1300 NJ
preplace netloc axi_quad_spi_0_sck_o 1 6 3 NJ 1320 NJ 1320 NJ
preplace netloc axi_quad_spi_0_ss_o 1 6 3 NJ 1340 NJ 1340 NJ
preplace netloc axis_set_reg_0_dout 1 5 3 NJ 1540 NJ 1540 3620
preplace netloc axis_tproc64x32_x8_0_pmem_addr 1 1 2 400 2440 760
preplace netloc bias_constant_0_dout 1 8 1 NJ 560
preplace netloc bias_constant_1_dout 1 8 1 4000J 650n
preplace netloc clk_adc0_x2_clk_out1 1 2 6 930 1800 1620 3580 1900 3910 2710 2240 N 2240 3570
preplace netloc clk_adc0_x2_locked 1 2 2 920 260 1560
preplace netloc dac_bias_spi_io0_o 1 6 3 3120J 820 NJ 820 4000J
preplace netloc dac_bias_spi_sck_o 1 6 3 3090J 830 NJ 830 3990J
preplace netloc dac_bias_spi_ss_o 1 6 3 3040J 840 NJ 840 3970J
preplace netloc dig_lconstant_1_dout 1 8 1 NJ 450
preplace netloc io1_i_0_1 1 6 3 N 1120 N 1120 N
preplace netloc io1_i_0_2 1 6 3 3080 850 3530 860 3950
preplace netloc lo_spi_io0_o 1 6 3 3040J 880 3630J 910 NJ
preplace netloc lo_spi_mux_0_sdo_out 1 6 2 3060J 900 3520
preplace netloc lo_spi_mux_0_ss0_out 1 7 2 NJ 960 3920J
preplace netloc lo_spi_mux_0_ss1_out 1 7 2 3610J 850 3920J
preplace netloc lo_spi_sck_o 1 6 3 3050J 890 3620J 940 NJ
preplace netloc lo_spi_ss_o 1 6 1 N 960
preplace netloc psf_spi_io0_o 1 6 3 NJ 1100 NJ 1100 NJ
preplace netloc psf_spi_sck_o 1 6 3 NJ 1140 NJ 1140 NJ
preplace netloc psf_spi_ss_o 1 6 3 NJ 1160 NJ 1160 NJ
preplace netloc rst_adc0_peripheral_reset 1 2 2 900 460 1550
preplace netloc rst_adc0_x2_peripheral_aresetn 1 3 5 1630 3740 2020 3920 2750 2250 NJ 2250 3580J
preplace netloc rst_dac0_peripheral_aresetn 1 0 8 0 1760 330 1760 800J 1760 1590 1560 2000 3660 2720J 3340 3160J 2280 N
preplace netloc rst_dac1_peripheral_aresetn 1 2 6 930 2320 1600 2320 1930 3670 2690J 2260 NJ 2260 3560J
preplace netloc rst_ps8_0_99M_peripheral_aresetn 1 0 8 10 2630 310 330 850 230 1580J 330 1980 3930 2660 2270 3040 2220 N
preplace netloc usp_rf_data_converter_0_clk_adc0 1 2 7 910 1460 1650J 1450 N 1450 NJ 1450 NJ 1450 NJ 1450 3950
preplace netloc usp_rf_data_converter_0_clk_dac0 1 0 9 10 1770 340 1750 820 1770 NJ 1770 2040 3680 2730J 3320 3170J 2300 3580J 2440 3930
preplace netloc usp_rf_data_converter_0_clk_dac1 1 2 7 880 2330 NJ 2330 1910 3690 2670J 2280 3050J 2270 3550J 2460 3920
preplace netloc vect2bits_16_0_dout0 1 8 1 N 1520
preplace netloc vect2bits_16_0_dout1 1 8 1 N 1540
preplace netloc vect2bits_16_0_dout2 1 8 1 N 1560
preplace netloc vect2bits_16_0_dout3 1 8 1 N 1580
preplace netloc vect2bits_16_0_dout4 1 8 1 N 1600
preplace netloc vect2bits_16_0_dout5 1 8 1 N 1620
preplace netloc vect2bits_16_0_dout6 1 8 1 N 1640
preplace netloc vect2bits_16_0_dout7 1 8 1 N 1660
preplace netloc vect2bits_16_0_dout14 1 5 4 2780 3330 3200J 3490 N 3490 3970
preplace netloc vect2bits_16_0_dout15 1 5 4 2770 2290 NJ 2290 3540J 2480 3940
preplace netloc xlconstant_0_dout 1 1 1 290 2230n
preplace netloc xlconstant_1_dout 1 1 1 N 2340
preplace netloc xlconstant_2_dout 1 1 1 320 2360n
preplace netloc xlconstant_3_dout 1 1 1 330 2380n
preplace netloc zynq_ultra_ps_e_0_pl_clk0 1 0 8 0 2640 300 320 870 240 1570 340 1950 3940 2650 2200 3120 2200 N
preplace netloc zynq_ultra_ps_e_0_pl_clk1 1 3 6 NJ 400 1920J 1320 2620J 1440 3040J 1410 NJ 1410 NJ
preplace netloc zynq_ultra_ps_e_0_pl_resetn0 1 2 2 890 250 1550
preplace netloc usp_rf_data_converter_0_vout12 1 8 1 N 2150
preplace netloc usp_rf_data_converter_0_vout10 1 8 1 N 2110
preplace netloc ps8_0_axi_periph_M24_AXI 1 5 1 2780 850n
preplace netloc sysref_in_1 1 7 2 3640 2420 4000
preplace netloc ps8_0_axi_periph_M17_AXI 1 5 2 2590J 610 3100
preplace netloc ps8_0_axi_periph_M13_AXI 1 0 6 -10 1470 N 1470 NJ 1470 1640J 1420 N 1420 2570
preplace netloc ps8_0_axi_periph_M09_AXI 1 5 1 2640 550n
preplace netloc ps8_0_axi_periph_M05_AXI 1 4 2 2090 1300 2530
preplace netloc ps8_0_axi_periph_M03_AXI 1 4 2 2070 1250 2450
preplace netloc ps8_0_axi_periph_M07_AXI 1 2 4 920 1480 NJ 1480 2040 1410 2580
preplace netloc ps8_0_axi_periph_M11_AXI 1 4 2 2100 1330 2490
preplace netloc ps8_0_axi_periph_M15_AXI 1 4 2 2120 1360 2470
preplace netloc usp_rf_data_converter_0_vout01 1 8 1 N 2070
preplace netloc usp_rf_data_converter_0_m02_axis 1 3 6 1660 1430 NJ 1430 NJ 1430 NJ 1430 NJ 1430 3960
preplace netloc ps8_0_axi_periph_M21_AXI 1 5 1 2770 790n
preplace netloc ps8_0_axi_periph_M19_AXI 1 1 5 320 1440 NJ 1440 NJ 1440 N 1440 2500
preplace netloc ps8_0_axi_periph_M14_AXI 1 4 2 2130 1370 2510
preplace netloc ps8_0_axi_periph_M18_AXI 1 5 2 2610J 620 3070
preplace netloc ps8_0_axi_periph_M20_AXI 1 1 5 330 1450 NJ 1450 1610J 1370 1910 1280 2430
preplace netloc ps8_0_axi_periph_M23_AXI 1 5 1 2620 700n
preplace netloc usp_rf_data_converter_0_m00_axis 1 3 6 1670 1460 NJ 1460 NJ 1460 NJ 1460 NJ 1460 3920
preplace netloc ps8_0_axi_periph_M12_AXI 1 4 2 2110 1340 2480
preplace netloc ps8_0_axi_periph_M04_AXI 1 4 2 2080 1290 2540
preplace netloc ps8_0_axi_periph_M06_AXI 1 1 5 380 1430 N 1430 1620J 1410 1970 1310 2520
preplace netloc ps8_0_axi_periph_M16_AXI 1 4 2 2050 1350 2440
preplace netloc usp_rf_data_converter_0_vout11 1 8 1 N 2130
preplace netloc usp_rf_data_converter_0_vout00 1 8 1 N 2050
preplace netloc ps8_0_axi_periph_M25_AXI 1 5 1 2750 870n
preplace netloc ps8_0_axi_periph_M10_AXI 1 5 1 2630 570n
preplace netloc ps8_0_axi_periph_M08_AXI 1 5 3 N 530 3160 810 3640J
preplace netloc usp_rf_data_converter_0_vout02 1 8 1 N 2090
preplace netloc usp_rf_data_converter_0_vout13 1 8 1 N 2170
preplace netloc axis_tproc64x32_x8_0_m1_axis 1 2 3 810 1730 1650 1550 2000
preplace netloc axis_signal_gen_v6_5_m_axis 1 5 3 2580 2040 N 2040 NJ
preplace netloc axis_signal_gen_v6_1_m_axis 1 5 3 2440 1960 N 1960 NJ
preplace netloc axis_switch_0_M02_AXIS 1 3 2 N 2180 N
preplace netloc axis_switch_0_M04_AXIS 1 3 2 N 2220 2010
preplace netloc axis_tproc64x32_x8_0_m3_axis 1 2 3 NJ 1940 N 1940 N
preplace netloc axis_tproc64x32_x8_0_m7_axis 1 2 1 780 2020n
preplace netloc axis_switch_buf_M00_AXIS 1 1 7 390 1400 NJ 1400 NJ 1400 N 1400 2600J 1420 NJ 1420 3530
preplace netloc axis_signal_gen_v6_3_m_axis 1 5 3 2510 2000 N 2000 NJ
preplace netloc axis_constant_1_m_axis 1 1 1 290 1900n
preplace netloc axis_readout_v2_0_m1_axis 1 5 1 2740 3410n
preplace netloc axis_readout_v2_1_m1_axis 1 5 1 N 3810
preplace netloc axis_switch_0_M00_AXIS 1 3 2 1640 1780 1970
preplace netloc axis_switch_0_M06_AXIS 1 3 2 N 2260 1970
preplace netloc axis_tproc64x32_x8_0_m5_axis 1 2 1 810 1980n
preplace netloc ps8_0_axi_periph_M02_AXI 1 4 2 2060 1240 2460
preplace netloc ps8_0_axi_periph_M01_AXI 1 1 5 370 1420 N 1420 1580J 1360 1900 1270 2550
preplace netloc axis_register_slice_1_M_AXIS 1 4 1 1890 3660n
preplace netloc dac1_clk_1 1 7 2 3610J 2450 N
preplace netloc axis_tproc64x32_x8_0_m4_axis 1 2 3 NJ 1960 N 1960 2030
preplace netloc axis_switch_0_M05_AXIS 1 3 2 N 2240 1920
preplace netloc axis_switch_0_M01_AXIS 1 3 2 1650 1920 N
preplace netloc axis_signal_gen_v6_4_m_axis 1 5 3 2550 2020 N 2020 NJ
preplace netloc axis_readout_v2_1_m0_axis 1 5 1 2760 3670n
preplace netloc axis_readout_v2_0_m0_axis 1 5 1 2680 3220n
preplace netloc axis_signal_gen_v6_0_m_axis 1 5 3 N 1740 3040 1940 NJ
preplace netloc axis_signal_gen_v6_6_m_axis 1 5 3 2610 2060 N 2060 NJ
preplace netloc axis_switch_0_M03_AXIS 1 3 2 N 2200 2020
preplace netloc axis_tproc64x32_x8_0_m8_axis 1 2 1 770 2040n
preplace netloc axis_tproc64x32_x8_0_m2_axis 1 2 3 830J 1790 N 1790 2030
preplace netloc axis_signal_gen_v6_2_m_axis 1 5 3 2470 1980 N 1980 NJ
preplace netloc axis_register_slice_0_M_AXIS 1 4 1 N 3500
preplace netloc axis_tproc64x32_x8_0_m0_axis 1 1 2 340 1460 760
preplace netloc axis_switch_avg_M00_AXIS 1 1 7 370 1390 NJ 1390 NJ 1390 N 1390 2590J 1480 NJ 1480 3500
preplace netloc axis_tproc64x32_x8_0_m6_axis 1 2 1 790 2000n
preplace netloc axis_avg_buffer_0_m2_axis 1 6 1 3130 2360n
preplace netloc axi_dma_avg_M_AXI_S2MM 1 1 2 320 350 780
preplace netloc axi_dma_1_M_AXIS_MM2S 1 2 1 840 1050n
preplace netloc axi_bram_ctrl_0_BRAM_PORTA 1 1 1 290 2110n
preplace netloc axi_dma_0_M_AXI_MM2S 1 1 2 400 360 790
preplace netloc axis_avg_buffer_0_m1_axis 1 6 1 3140 2760n
preplace netloc axi_dma_0_M_AXI_S2MM 1 1 2 380 340 800J
preplace netloc axis_avg_buffer_1_m1_axis 1 6 1 3180 2780n
preplace netloc axi_dma_0_M_AXIS_MM2S 1 1 2 350 1370 760
preplace netloc axis_avg_buffer_1_m2_axis 1 6 1 3190 2980n
preplace netloc axis_avg_buffer_0_m0_axis 1 6 1 3110 2540n
preplace netloc axis_clk_cnvrt_avg_1_M_AXIS 1 1 7 360 1380 NJ 1380 NJ 1380 N 1380 2610J 1470 NJ 1470 3520
preplace netloc ps8_0_axi_periph_M00_AXI 1 1 5 400 1410 N 1410 1570J 1350 1890 1260 2560J
preplace netloc axi_dma_1_M_AXI_MM2S 1 1 2 390 370 770J
preplace netloc dac0_clk_1 1 7 2 3590J 2470 N
preplace netloc vin1_1 1 7 2 3630J 2410 3990
preplace netloc vin0_1 1 7 2 3620J 2400 3980
preplace netloc zynq_ultra_ps_e_0_M_AXI_HPM0_FPD 1 3 2 NJ 320 1890
preplace netloc axis_clock_converter_5_M_AXIS 1 3 2 N 2790 1940
preplace netloc axis_constant_0_m_axis 1 1 1 320 1840n
preplace netloc axis_clock_converter_6_M_AXIS 1 3 2 N 2970 1920
preplace netloc axis_clock_converter_3_M_AXIS 1 3 2 N 2430 1990
preplace netloc axis_clock_converter_4_M_AXIS 1 3 2 N 2610 1960
preplace netloc axis_clk_cnvrt_avg_0_M_AXIS 1 1 7 350 3420 NJ 3420 NJ 3420 1890 3440 2700J 3350 3060J 3480 3510
preplace netloc adc0_clk_1 1 7 2 3600J 2430 N
preplace netloc axi_smc_M00_AXI 1 2 1 860 330n
preplace netloc axis_avg_buffer_1_m0_axis 1 6 1 3150 2560n
preplace netloc axi_dma_buf_M_AXI_S2MM 1 1 2 400 610 760
levelinfo -pg 1 -30 150 580 1240 1780 2280 2910 3360 3780 4020
pagesize -pg 1 -db -bbox -sgen -180 0 4190 4030
"
}

  # Restore current instance
  current_bd_instance $oldCurInst

  validate_bd_design
  save_bd_design
}
# End of create_root_design()


##################################################################
# MAIN FLOW
##################################################################

create_root_design ""


