
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
set scripts_vivado_version 2022.1
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
# vect2bits_16

# Please add the sources of those modules before sourcing this Tcl script.

# If there is no project opened, this script will create a
# project, but make sure you do not have an existing project
# <./myproj/project_1.xpr> in the current working folder.

set list_projs [get_projects -quiet]
if { $list_projs eq "" } {
   create_project project_1 myproj -part xczu48dr-ffvg1517-2-e
   set_property BOARD_PART realdigital.org:rfsoc4x2:part0:1.0 [current_project]
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
xilinx.com:ip:axi_bram_ctrl:4.1\
xilinx.com:ip:blk_mem_gen:8.4\
xilinx.com:ip:axi_dma:7.1\
xilinx.com:ip:axi_intc:4.1\
xilinx.com:ip:smartconnect:1.0\
user.org:user:axis_avg_buffer:1.0\
xilinx.com:ip:axis_broadcaster:1.1\
user.org:user:axis_buffer_ddr_v1:1.0\
xilinx.com:ip:axis_clock_converter:1.1\
xilinx.com:ip:axis_dwidth_converter:1.1\
user.org:user:axis_readout_v2:1.0\
user.org:user:axis_register_slice_nb:1.0\
xilinx.com:ip:axis_register_slice:1.1\
user.org:user:axis_set_reg:1.0\
user.org:user:axis_signal_gen_v6:1.0\
xilinx.com:ip:axis_switch:1.1\
user.org:user:axis_tproc64x32_x8:1.0\
xilinx.com:ip:clk_wiz:6.0\
xilinx.com:ip:ddr4:2.2\
user.org:user:mr_buffer_et:1.0\
xilinx.com:ip:proc_sys_reset:5.0\
xilinx.com:ip:usp_rf_data_converter:2.6\
xilinx.com:ip:xlconcat:2.1\
xilinx.com:ip:xlconstant:1.1\
xilinx.com:ip:zynq_ultra_ps_e:3.4\
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

  set dac2_clk [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 dac2_clk ]

  set ddr4_pl [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:ddr4_rtl:1.0 ddr4_pl ]

  set sys_clk_ddr4 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 sys_clk_ddr4 ]
  set_property -dict [ list \
   CONFIG.FREQ_HZ {200000000} \
   ] $sys_clk_ddr4

  set sysref_in [ create_bd_intf_port -mode Slave -vlnv xilinx.com:display_usp_rf_data_converter:diff_pins_rtl:1.0 sysref_in ]

  set vin0_01 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 vin0_01 ]

  set vin0_23 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 vin0_23 ]

  set vout00 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 vout00 ]

  set vout20 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 vout20 ]


  # Create ports
  set PMOD0_0 [ create_bd_port -dir O PMOD0_0 ]
  set PMOD0_1 [ create_bd_port -dir O PMOD0_1 ]
  set PMOD0_2 [ create_bd_port -dir O PMOD0_2 ]
  set PMOD0_3 [ create_bd_port -dir O PMOD0_3 ]
  set PMOD0_4 [ create_bd_port -dir O PMOD0_4 ]
  set PMOD0_5 [ create_bd_port -dir O PMOD0_5 ]
  set PMOD0_6 [ create_bd_port -dir O PMOD0_6 ]
  set PMOD0_7 [ create_bd_port -dir O PMOD0_7 ]
  set PMOD1_0 [ create_bd_port -dir I PMOD1_0 ]

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
   CONFIG.Byte_Size {8} \
   CONFIG.EN_SAFETY_CKT {false} \
   CONFIG.Enable_32bit_Address {true} \
   CONFIG.Enable_B {Use_ENB_Pin} \
   CONFIG.Memory_Type {True_Dual_Port_RAM} \
   CONFIG.Port_B_Clock {100} \
   CONFIG.Port_B_Enable_Rate {100} \
   CONFIG.Port_B_Write_Rate {50} \
   CONFIG.Read_Width_B {64} \
   CONFIG.Register_PortA_Output_of_Memory_Primitives {false} \
   CONFIG.Register_PortB_Output_of_Memory_Primitives {false} \
   CONFIG.Use_Byte_Write_Enable {true} \
   CONFIG.Use_RSTA_Pin {true} \
   CONFIG.Use_RSTB_Pin {true} \
   CONFIG.Write_Width_B {64} \
   CONFIG.use_bram_block {BRAM_Controller} \
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
   CONFIG.c_include_s2mm {0} \
   CONFIG.c_include_sg {0} \
   CONFIG.c_sg_include_stscntrl_strm {0} \
   CONFIG.c_sg_length_width {26} \
 ] $axi_dma_gen

  # Create instance: axi_dma_mr, and set properties
  set axi_dma_mr [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma_mr ]
  set_property -dict [ list \
   CONFIG.c_include_mm2s {0} \
   CONFIG.c_include_sg {0} \
   CONFIG.c_sg_include_stscntrl_strm {0} \
   CONFIG.c_sg_length_width {26} \
 ] $axi_dma_mr

  # Create instance: axi_dma_tproc, and set properties
  set axi_dma_tproc [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma_tproc ]
  set_property -dict [ list \
   CONFIG.c_include_sg {0} \
   CONFIG.c_sg_include_stscntrl_strm {0} \
 ] $axi_dma_tproc

  # Create instance: axi_intc_0, and set properties
  set axi_intc_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_intc:4.1 axi_intc_0 ]
  set_property -dict [ list \
   CONFIG.C_IRQ_CONNECTION {1} \
 ] $axi_intc_0

  # Create instance: axi_smc, and set properties
  set axi_smc [ create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 axi_smc ]
  set_property -dict [ list \
   CONFIG.NUM_SI {6} \
 ] $axi_smc

  # Create instance: axis_avg_buffer_0, and set properties
  set axis_avg_buffer_0 [ create_bd_cell -type ip -vlnv user.org:user:axis_avg_buffer:1.0 axis_avg_buffer_0 ]
  set_property -dict [ list \
   CONFIG.N_AVG {14} \
   CONFIG.N_BUF {10} \
 ] $axis_avg_buffer_0

  # Create instance: axis_avg_buffer_1, and set properties
  set axis_avg_buffer_1 [ create_bd_cell -type ip -vlnv user.org:user:axis_avg_buffer:1.0 axis_avg_buffer_1 ]
  set_property -dict [ list \
   CONFIG.N_AVG {14} \
   CONFIG.N_BUF {10} \
 ] $axis_avg_buffer_1

  # Create instance: axis_broadcaster_0, and set properties
  set axis_broadcaster_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_broadcaster:1.1 axis_broadcaster_0 ]
  set_property -dict [ list \
   CONFIG.HAS_TREADY {0} \
 ] $axis_broadcaster_0

  # Create instance: axis_broadcaster_1, and set properties
  set axis_broadcaster_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_broadcaster:1.1 axis_broadcaster_1 ]
  set_property -dict [ list \
   CONFIG.HAS_TREADY {0} \
 ] $axis_broadcaster_1

  # Create instance: axis_buffer_ddr_v1_0, and set properties
  set axis_buffer_ddr_v1_0 [ create_bd_cell -type ip -vlnv user.org:user:axis_buffer_ddr_v1:1.0 axis_buffer_ddr_v1_0 ]
  set_property -dict [ list \
   CONFIG.TARGET_SLAVE_BASE_ADDR {0x00000000} \
 ] $axis_buffer_ddr_v1_0

  # Create instance: axis_cc_avg_0, and set properties
  set axis_cc_avg_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_clock_converter:1.1 axis_cc_avg_0 ]

  # Create instance: axis_cc_avg_1, and set properties
  set axis_cc_avg_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_clock_converter:1.1 axis_cc_avg_1 ]

  # Create instance: axis_cc_sg_0, and set properties
  set axis_cc_sg_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_clock_converter:1.1 axis_cc_sg_0 ]
  set_property -dict [ list \
   CONFIG.SYNCHRONIZATION_STAGES {4} \
 ] $axis_cc_sg_0

  # Create instance: axis_cc_sg_1, and set properties
  set axis_cc_sg_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_clock_converter:1.1 axis_cc_sg_1 ]
  set_property -dict [ list \
   CONFIG.SYNCHRONIZATION_STAGES {4} \
 ] $axis_cc_sg_1

  # Create instance: axis_clock_converter_0, and set properties
  set axis_clock_converter_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_clock_converter:1.1 axis_clock_converter_0 ]

  # Create instance: axis_dwidth_converter_0, and set properties
  set axis_dwidth_converter_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_dwidth_converter:1.1 axis_dwidth_converter_0 ]
  set_property -dict [ list \
   CONFIG.M_TDATA_NUM_BYTES {64} \
 ] $axis_dwidth_converter_0

  # Create instance: axis_readout_v2_0, and set properties
  set axis_readout_v2_0 [ create_bd_cell -type ip -vlnv user.org:user:axis_readout_v2:1.0 axis_readout_v2_0 ]

  # Create instance: axis_readout_v2_1, and set properties
  set axis_readout_v2_1 [ create_bd_cell -type ip -vlnv user.org:user:axis_readout_v2:1.0 axis_readout_v2_1 ]

  # Create instance: axis_register_slice_0, and set properties
  set axis_register_slice_0 [ create_bd_cell -type ip -vlnv user.org:user:axis_register_slice_nb:1.0 axis_register_slice_0 ]
  set_property -dict [ list \
   CONFIG.B {256} \
   CONFIG.N {4} \
 ] $axis_register_slice_0

  # Create instance: axis_register_slice_1, and set properties
  set axis_register_slice_1 [ create_bd_cell -type ip -vlnv user.org:user:axis_register_slice_nb:1.0 axis_register_slice_1 ]
  set_property -dict [ list \
   CONFIG.B {256} \
   CONFIG.N {4} \
 ] $axis_register_slice_1

  # Create instance: axis_register_slice_2, and set properties
  set axis_register_slice_2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_register_slice:1.1 axis_register_slice_2 ]
  set_property -dict [ list \
   CONFIG.REG_CONFIG {16} \
 ] $axis_register_slice_2

  # Create instance: axis_register_slice_3, and set properties
  set axis_register_slice_3 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_register_slice:1.1 axis_register_slice_3 ]
  set_property -dict [ list \
   CONFIG.REG_CONFIG {16} \
 ] $axis_register_slice_3

  # Create instance: axis_set_reg_0, and set properties
  set axis_set_reg_0 [ create_bd_cell -type ip -vlnv user.org:user:axis_set_reg:1.0 axis_set_reg_0 ]
  set_property -dict [ list \
   CONFIG.DATA_WIDTH {160} \
 ] $axis_set_reg_0

  # Create instance: axis_signal_gen_v6_0, and set properties
  set axis_signal_gen_v6_0 [ create_bd_cell -type ip -vlnv user.org:user:axis_signal_gen_v6:1.0 axis_signal_gen_v6_0 ]

  # Create instance: axis_signal_gen_v6_1, and set properties
  set axis_signal_gen_v6_1 [ create_bd_cell -type ip -vlnv user.org:user:axis_signal_gen_v6:1.0 axis_signal_gen_v6_1 ]

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

  # Create instance: axis_switch_ddr4, and set properties
  set axis_switch_ddr4 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_switch:1.1 axis_switch_ddr4 ]
  set_property -dict [ list \
   CONFIG.ROUTING_MODE {1} \
 ] $axis_switch_ddr4

  # Create instance: axis_switch_gen, and set properties
  set axis_switch_gen [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_switch:1.1 axis_switch_gen ]
  set_property -dict [ list \
   CONFIG.DECODER_REG {1} \
   CONFIG.NUM_MI {2} \
   CONFIG.NUM_SI {1} \
   CONFIG.ROUTING_MODE {1} \
 ] $axis_switch_gen

  # Create instance: axis_switch_mr, and set properties
  set axis_switch_mr [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_switch:1.1 axis_switch_mr ]
  set_property -dict [ list \
   CONFIG.ROUTING_MODE {1} \
 ] $axis_switch_mr

  # Create instance: axis_tproc64x32_x8_0, and set properties
  set axis_tproc64x32_x8_0 [ create_bd_cell -type ip -vlnv user.org:user:axis_tproc64x32_x8:1.0 axis_tproc64x32_x8_0 ]

  # Create instance: clk_adc0_x2, and set properties
  set clk_adc0_x2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_adc0_x2 ]
  set_property -dict [ list \
   CONFIG.CLKIN1_JITTER_PS {36.160000000000004} \
   CONFIG.CLKOUT1_JITTER {73.083} \
   CONFIG.CLKOUT1_PHASE_ERROR {78.704} \
   CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {552.96} \
   CONFIG.MMCM_CLKFBOUT_MULT_F {4.250} \
   CONFIG.MMCM_CLKIN1_PERIOD {3.617} \
   CONFIG.MMCM_CLKIN2_PERIOD {10.0} \
   CONFIG.MMCM_CLKOUT0_DIVIDE_F {2.125} \
   CONFIG.MMCM_DIVCLK_DIVIDE {1} \
   CONFIG.OPTIMIZE_CLOCKING_STRUCTURE_EN {true} \
   CONFIG.RESET_PORT {resetn} \
   CONFIG.RESET_TYPE {ACTIVE_LOW} \
   CONFIG.PRIM_SOURCE {Global_buffer} \
 ] $clk_adc0_x2

  # Create instance: clk_tproc, and set properties
  set clk_tproc [ create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_tproc ]
  set_property -dict [ list \
   CONFIG.CLKIN1_JITTER_PS {16.279999999999998} \
   CONFIG.CLKOUT1_JITTER {79.602} \
   CONFIG.CLKOUT1_PHASE_ERROR {81.720} \
   CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {409.6} \
   CONFIG.MMCM_CLKFBOUT_MULT_F {5.750} \
   CONFIG.MMCM_CLKIN1_PERIOD {1.628} \
   CONFIG.MMCM_CLKIN2_PERIOD {10.0} \
   CONFIG.MMCM_CLKOUT0_DIVIDE_F {2.875} \
   CONFIG.MMCM_DIVCLK_DIVIDE {3} \
   CONFIG.RESET_PORT {resetn} \
   CONFIG.RESET_TYPE {ACTIVE_LOW} \
   CONFIG.PRIM_SOURCE {Global_buffer} \
 ] $clk_tproc

  # Create instance: ddr4_0, and set properties
  set ddr4_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:ddr4:2.2 ddr4_0 ]
  set_property -dict [ list \
   CONFIG.C0.BANK_GROUP_WIDTH {1} \
   CONFIG.C0.DDR4_AxiAddressWidth {32} \
   CONFIG.C0.DDR4_AxiDataWidth {512} \
   CONFIG.C0.DDR4_CLKOUT0_DIVIDE {5} \
   CONFIG.C0.DDR4_CasLatency {16} \
   CONFIG.C0.DDR4_CasWriteLatency {12} \
   CONFIG.C0.DDR4_DataWidth {64} \
   CONFIG.C0.DDR4_InputClockPeriod {4998} \
   CONFIG.C0.DDR4_MemoryPart {MT40A512M16HA-083E} \
   CONFIG.C0.DDR4_TimePeriod {833} \
   CONFIG.System_Clock {Differential} \
 ] $ddr4_0

  # Create instance: mr_buffer_et_0, and set properties
  set mr_buffer_et_0 [ create_bd_cell -type ip -vlnv user.org:user:mr_buffer_et:1.0 mr_buffer_et_0 ]
  set_property -dict [ list \
   CONFIG.B {32} \
   CONFIG.N {10} \
 ] $mr_buffer_et_0

  # Create instance: ps8_0_axi_periph, and set properties
  set ps8_0_axi_periph [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 ps8_0_axi_periph ]
  set_property -dict [ list \
   CONFIG.NUM_MI {22} \
 ] $ps8_0_axi_periph

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

  # Create instance: rst_ddr4, and set properties
  set rst_ddr4 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_ddr4 ]

  # Create instance: rst_tproc, and set properties
  set rst_tproc [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_tproc ]

  # Create instance: smartconnect_0, and set properties
  set smartconnect_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 smartconnect_0 ]

  # Create instance: usp_rf_data_converter_0, and set properties
  set usp_rf_data_converter_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:usp_rf_data_converter:2.6 usp_rf_data_converter_0 ]
  set_property -dict [ list \
   CONFIG.ADC0_Fabric_Freq {552.960} \
   CONFIG.ADC0_Outclk_Freq {276.480} \
   CONFIG.ADC0_PLL_Enable {true} \
   CONFIG.ADC0_Refclk_Freq {491.520} \
   CONFIG.ADC0_Sampling_Rate {4.42368} \
   CONFIG.ADC_Coarse_Mixer_Freq02 {3} \
   CONFIG.ADC_Coarse_Mixer_Freq03 {3} \
   CONFIG.ADC_Data_Width00 {8} \
   CONFIG.ADC_Data_Width01 {8} \
   CONFIG.ADC_Data_Width02 {8} \
   CONFIG.ADC_Data_Width03 {8} \
   CONFIG.ADC_Decimation_Mode02 {1} \
   CONFIG.ADC_Decimation_Mode03 {1} \
   CONFIG.ADC_Mixer_Type02 {1} \
   CONFIG.ADC_Mixer_Type03 {1} \
   CONFIG.ADC_RESERVED_1_00 {false} \
   CONFIG.ADC_RESERVED_1_02 {false} \
   CONFIG.ADC_Slice02_Enable {true} \
   CONFIG.ADC_Slice03_Enable {true} \
   CONFIG.DAC0_Enable {1} \
   CONFIG.DAC0_Fabric_Freq {614.400} \
   CONFIG.DAC0_Outclk_Freq {614.400} \
   CONFIG.DAC0_PLL_Enable {true} \
   CONFIG.DAC0_Refclk_Freq {491.520} \
   CONFIG.DAC0_Sampling_Rate {9.8304} \
   CONFIG.DAC2_Enable {1} \
   CONFIG.DAC2_Fabric_Freq {614.400} \
   CONFIG.DAC2_Outclk_Freq {614.400} \
   CONFIG.DAC2_PLL_Enable {true} \
   CONFIG.DAC2_Refclk_Freq {491.520} \
   CONFIG.DAC2_Sampling_Rate {9.8304} \
   CONFIG.DAC_Coarse_Mixer_Freq00 {3} \
   CONFIG.DAC_Coarse_Mixer_Freq20 {3} \
   CONFIG.DAC_Interpolation_Mode00 {1} \
   CONFIG.DAC_Interpolation_Mode20 {1} \
   CONFIG.DAC_Mixer_Type00 {1} \
   CONFIG.DAC_Mixer_Type20 {1} \
   CONFIG.DAC_Mode00 {3} \
   CONFIG.DAC_Mode20 {3} \
   CONFIG.DAC_RESERVED_1_00 {false} \
   CONFIG.DAC_RESERVED_1_01 {false} \
   CONFIG.DAC_RESERVED_1_02 {false} \
   CONFIG.DAC_RESERVED_1_03 {false} \
   CONFIG.DAC_RESERVED_1_20 {false} \
   CONFIG.DAC_RESERVED_1_21 {false} \
   CONFIG.DAC_RESERVED_1_22 {false} \
   CONFIG.DAC_RESERVED_1_23 {false} \
   CONFIG.DAC_Slice00_Enable {true} \
   CONFIG.DAC_Slice20_Enable {true} \
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
  
  # Create instance: xlconcat_0, and set properties
  set xlconcat_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 xlconcat_0 ]
  set_property -dict [ list \
   CONFIG.NUM_PORTS {6} \
 ] $xlconcat_0

  # Create instance: xlconstant_0, and set properties
  set xlconstant_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_0 ]
  set_property -dict [ list \
   CONFIG.CONST_VAL {0} \
   CONFIG.CONST_WIDTH {64} \
 ] $xlconstant_0

  # Create instance: xlconstant_1, and set properties
  set xlconstant_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_1 ]
  set_property -dict [ list \
   CONFIG.CONST_VAL {1} \
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
  set zynq_ultra_ps_e_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e:3.4 zynq_ultra_ps_e_0 ]
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
   CONFIG.PSU_BANK_0_IO_STANDARD {LVCMOS33} \
   CONFIG.PSU_BANK_1_IO_STANDARD {LVCMOS18} \
   CONFIG.PSU_BANK_2_IO_STANDARD {LVCMOS18} \
   CONFIG.PSU_BANK_3_IO_STANDARD {LVCMOS18} \
   CONFIG.PSU_DDR_RAM_HIGHADDR {0xFFFFFFFF} \
   CONFIG.PSU_DDR_RAM_HIGHADDR_OFFSET {0x800000000} \
   CONFIG.PSU_DDR_RAM_LOWADDR_OFFSET {0x80000000} \
   CONFIG.PSU_DYNAMIC_DDR_CONFIG_EN {0} \
   CONFIG.PSU_IMPORT_BOARD_PRESET {} \
   CONFIG.PSU_MIO_0_DIRECTION {inout} \
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
   CONFIG.PSU_MIO_12_DIRECTION {inout} \
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
   CONFIG.PSU_MIO_18_DIRECTION {inout} \
   CONFIG.PSU_MIO_18_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_18_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_18_POLARITY {Default} \
   CONFIG.PSU_MIO_18_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_18_SLEW {fast} \
   CONFIG.PSU_MIO_19_DIRECTION {inout} \
   CONFIG.PSU_MIO_19_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_19_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_19_POLARITY {Default} \
   CONFIG.PSU_MIO_19_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_19_SLEW {fast} \
   CONFIG.PSU_MIO_1_DIRECTION {out} \
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
   CONFIG.PSU_MIO_22_DIRECTION {out} \
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
   CONFIG.PSU_MIO_24_DIRECTION {in} \
   CONFIG.PSU_MIO_24_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_24_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_24_POLARITY {Default} \
   CONFIG.PSU_MIO_24_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_24_SLEW {fast} \
   CONFIG.PSU_MIO_25_DIRECTION {in} \
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
   CONFIG.PSU_MIO_2_DIRECTION {out} \
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
   CONFIG.PSU_MIO_33_DIRECTION {in} \
   CONFIG.PSU_MIO_33_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_33_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_33_POLARITY {Default} \
   CONFIG.PSU_MIO_33_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_33_SLEW {fast} \
   CONFIG.PSU_MIO_34_DIRECTION {inout} \
   CONFIG.PSU_MIO_34_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_34_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_34_POLARITY {Default} \
   CONFIG.PSU_MIO_34_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_34_SLEW {fast} \
   CONFIG.PSU_MIO_35_DIRECTION {inout} \
   CONFIG.PSU_MIO_35_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_35_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_35_POLARITY {Default} \
   CONFIG.PSU_MIO_35_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_35_SLEW {fast} \
   CONFIG.PSU_MIO_36_DIRECTION {inout} \
   CONFIG.PSU_MIO_36_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_36_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_36_POLARITY {Default} \
   CONFIG.PSU_MIO_36_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_36_SLEW {fast} \
   CONFIG.PSU_MIO_37_DIRECTION {inout} \
   CONFIG.PSU_MIO_37_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_37_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_37_POLARITY {Default} \
   CONFIG.PSU_MIO_37_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_37_SLEW {fast} \
   CONFIG.PSU_MIO_38_DIRECTION {out} \
   CONFIG.PSU_MIO_38_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_38_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_38_POLARITY {Default} \
   CONFIG.PSU_MIO_38_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_38_SLEW {fast} \
   CONFIG.PSU_MIO_39_DIRECTION {out} \
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
   CONFIG.PSU_MIO_40_DIRECTION {out} \
   CONFIG.PSU_MIO_40_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_40_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_40_POLARITY {Default} \
   CONFIG.PSU_MIO_40_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_40_SLEW {fast} \
   CONFIG.PSU_MIO_41_DIRECTION {out} \
   CONFIG.PSU_MIO_41_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_41_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_41_POLARITY {Default} \
   CONFIG.PSU_MIO_41_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_41_SLEW {fast} \
   CONFIG.PSU_MIO_42_DIRECTION {out} \
   CONFIG.PSU_MIO_42_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_42_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_42_POLARITY {Default} \
   CONFIG.PSU_MIO_42_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_42_SLEW {fast} \
   CONFIG.PSU_MIO_43_DIRECTION {out} \
   CONFIG.PSU_MIO_43_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_43_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_43_POLARITY {Default} \
   CONFIG.PSU_MIO_43_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_43_SLEW {fast} \
   CONFIG.PSU_MIO_44_DIRECTION {in} \
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
   CONFIG.PSU_MIO_46_DIRECTION {in} \
   CONFIG.PSU_MIO_46_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_46_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_46_POLARITY {Default} \
   CONFIG.PSU_MIO_46_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_46_SLEW {fast} \
   CONFIG.PSU_MIO_47_DIRECTION {in} \
   CONFIG.PSU_MIO_47_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_47_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_47_POLARITY {Default} \
   CONFIG.PSU_MIO_47_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_47_SLEW {fast} \
   CONFIG.PSU_MIO_48_DIRECTION {in} \
   CONFIG.PSU_MIO_48_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_48_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_48_POLARITY {Default} \
   CONFIG.PSU_MIO_48_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_48_SLEW {fast} \
   CONFIG.PSU_MIO_49_DIRECTION {in} \
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
   CONFIG.PSU_MIO_50_DIRECTION {out} \
   CONFIG.PSU_MIO_50_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_50_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_50_POLARITY {Default} \
   CONFIG.PSU_MIO_50_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_50_SLEW {fast} \
   CONFIG.PSU_MIO_51_DIRECTION {inout} \
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
   CONFIG.PSU_MIO_5_DIRECTION {inout} \
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
   CONFIG.PSU_MIO_64_DIRECTION {in} \
   CONFIG.PSU_MIO_64_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_64_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_64_POLARITY {Default} \
   CONFIG.PSU_MIO_64_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_64_SLEW {fast} \
   CONFIG.PSU_MIO_65_DIRECTION {in} \
   CONFIG.PSU_MIO_65_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_65_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_65_POLARITY {Default} \
   CONFIG.PSU_MIO_65_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_65_SLEW {fast} \
   CONFIG.PSU_MIO_66_DIRECTION {inout} \
   CONFIG.PSU_MIO_66_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_66_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_66_POLARITY {Default} \
   CONFIG.PSU_MIO_66_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_66_SLEW {fast} \
   CONFIG.PSU_MIO_67_DIRECTION {in} \
   CONFIG.PSU_MIO_67_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_67_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_67_POLARITY {Default} \
   CONFIG.PSU_MIO_67_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_67_SLEW {fast} \
   CONFIG.PSU_MIO_68_DIRECTION {inout} \
   CONFIG.PSU_MIO_68_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_68_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_68_POLARITY {Default} \
   CONFIG.PSU_MIO_68_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_68_SLEW {fast} \
   CONFIG.PSU_MIO_69_DIRECTION {inout} \
   CONFIG.PSU_MIO_69_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_69_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_69_POLARITY {Default} \
   CONFIG.PSU_MIO_69_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_69_SLEW {fast} \
   CONFIG.PSU_MIO_6_DIRECTION {inout} \
   CONFIG.PSU_MIO_6_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_6_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_6_POLARITY {Default} \
   CONFIG.PSU_MIO_6_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_6_SLEW {fast} \
   CONFIG.PSU_MIO_70_DIRECTION {out} \
   CONFIG.PSU_MIO_70_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_70_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_70_POLARITY {Default} \
   CONFIG.PSU_MIO_70_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_70_SLEW {fast} \
   CONFIG.PSU_MIO_71_DIRECTION {inout} \
   CONFIG.PSU_MIO_71_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_71_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_71_POLARITY {Default} \
   CONFIG.PSU_MIO_71_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_71_SLEW {fast} \
   CONFIG.PSU_MIO_72_DIRECTION {inout} \
   CONFIG.PSU_MIO_72_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_72_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_72_POLARITY {Default} \
   CONFIG.PSU_MIO_72_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_72_SLEW {fast} \
   CONFIG.PSU_MIO_73_DIRECTION {inout} \
   CONFIG.PSU_MIO_73_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_73_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_73_POLARITY {Default} \
   CONFIG.PSU_MIO_73_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_73_SLEW {fast} \
   CONFIG.PSU_MIO_74_DIRECTION {inout} \
   CONFIG.PSU_MIO_74_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_74_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_74_POLARITY {Default} \
   CONFIG.PSU_MIO_74_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_74_SLEW {fast} \
   CONFIG.PSU_MIO_75_DIRECTION {inout} \
   CONFIG.PSU_MIO_75_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_75_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_75_POLARITY {Default} \
   CONFIG.PSU_MIO_75_PULLUPDOWN {pullup} \
   CONFIG.PSU_MIO_75_SLEW {fast} \
   CONFIG.PSU_MIO_76_DIRECTION {inout} \
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
   CONFIG.PSU_MIO_7_DIRECTION {inout} \
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
   CONFIG.PSU_MIO_TREE_PERIPHERALS {\
SPI 0#SPI 0#SPI 0#SPI 0#SPI 0#SPI 0#SPI 1#GPIO0 MIO#GPIO0 MIO#SPI 1#SPI 1#SPI\
1#GPIO0 MIO#SD 0#SD 0#SD 0#SD 0#GPIO0 MIO#I2C 0#I2C 0#GPIO0 MIO#SD 0#SD 0#GPIO0\
MIO#SD 0#SD 0#GPIO1 MIO#DPAUX#DPAUX#DPAUX#DPAUX#GPIO1 MIO#UART 1#UART 1#GPIO1\
MIO#GPIO1 MIO#I2C 1#I2C 1#Gem 1#Gem 1#Gem 1#Gem 1#Gem 1#Gem 1#Gem 1#Gem 1#Gem\
1#Gem 1#Gem 1#Gem 1#MDIO 1#MDIO 1#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB\
0#USB 0#USB 0#USB 0#USB 0#USB 1#USB 1#USB 1#USB 1#USB 1#USB 1#USB 1#USB 1#USB\
1#USB 1#USB 1#USB 1#GPIO2 MIO#GPIO2 MIO} \
   CONFIG.PSU_MIO_TREE_SIGNALS {\
sclk_out#n_ss_out[2]#n_ss_out[1]#n_ss_out[0]#miso#mosi#sclk_out#gpio0[7]#gpio0[8]#n_ss_out[0]#miso#mosi#gpio0[12]#sdio0_data_out[0]#sdio0_data_out[1]#sdio0_data_out[2]#sdio0_data_out[3]#gpio0[17]#scl_out#sda_out#gpio0[20]#sdio0_cmd_out#sdio0_clk_out#gpio0[23]#sdio0_cd_n#sdio0_wp#gpio1[26]#dp_aux_data_out#dp_hot_plug_detect#dp_aux_data_oe#dp_aux_data_in#gpio1[31]#txd#rxd#gpio1[34]#gpio1[35]#scl_out#sda_out#rgmii_tx_clk#rgmii_txd[0]#rgmii_txd[1]#rgmii_txd[2]#rgmii_txd[3]#rgmii_tx_ctl#rgmii_rx_clk#rgmii_rxd[0]#rgmii_rxd[1]#rgmii_rxd[2]#rgmii_rxd[3]#rgmii_rx_ctl#gem1_mdc#gem1_mdio_out#ulpi_clk_in#ulpi_dir#ulpi_tx_data[2]#ulpi_nxt#ulpi_tx_data[0]#ulpi_tx_data[1]#ulpi_stp#ulpi_tx_data[3]#ulpi_tx_data[4]#ulpi_tx_data[5]#ulpi_tx_data[6]#ulpi_tx_data[7]#ulpi_clk_in#ulpi_dir#ulpi_tx_data[2]#ulpi_nxt#ulpi_tx_data[0]#ulpi_tx_data[1]#ulpi_stp#ulpi_tx_data[3]#ulpi_tx_data[4]#ulpi_tx_data[5]#ulpi_tx_data[6]#ulpi_tx_data[7]#gpio2[76]#gpio2[77]} \
   CONFIG.PSU_PERIPHERAL_BOARD_PRESET {} \
   CONFIG.PSU_SD0_INTERNAL_BUS_WIDTH {4} \
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
   CONFIG.PSU__ACT_DDR_FREQ_MHZ {1199.999756} \
   CONFIG.PSU__AFI0_COHERENCY {0} \
   CONFIG.PSU__AFI1_COHERENCY {0} \
   CONFIG.PSU__AUX_REF_CLK__FREQMHZ {33.333} \
   CONFIG.PSU__CAN0_LOOP_CAN1__ENABLE {0} \
   CONFIG.PSU__CAN0__GRP_CLK__ENABLE {0} \
   CONFIG.PSU__CAN0__PERIPHERAL__ENABLE {0} \
   CONFIG.PSU__CAN1__GRP_CLK__ENABLE {0} \
   CONFIG.PSU__CAN1__PERIPHERAL__ENABLE {0} \
   CONFIG.PSU__CRF_APB__ACPU_CTRL__ACT_FREQMHZ {1199.999756} \
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
   CONFIG.PSU__CRF_APB__DBG_FPD_CTRL__ACT_FREQMHZ {249.999954} \
   CONFIG.PSU__CRF_APB__DBG_FPD_CTRL__DIVISOR0 {2} \
   CONFIG.PSU__CRF_APB__DBG_FPD_CTRL__FREQMHZ {250} \
   CONFIG.PSU__CRF_APB__DBG_FPD_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRF_APB__DBG_TRACE_CTRL__ACT_FREQMHZ {250} \
   CONFIG.PSU__CRF_APB__DBG_TRACE_CTRL__DIVISOR0 {5} \
   CONFIG.PSU__CRF_APB__DBG_TRACE_CTRL__FREQMHZ {250} \
   CONFIG.PSU__CRF_APB__DBG_TRACE_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRF_APB__DBG_TSTMP_CTRL__ACT_FREQMHZ {249.999954} \
   CONFIG.PSU__CRF_APB__DBG_TSTMP_CTRL__DIVISOR0 {2} \
   CONFIG.PSU__CRF_APB__DBG_TSTMP_CTRL__FREQMHZ {250} \
   CONFIG.PSU__CRF_APB__DBG_TSTMP_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRF_APB__DDR_CTRL__ACT_FREQMHZ {599.999878} \
   CONFIG.PSU__CRF_APB__DDR_CTRL__DIVISOR0 {2} \
   CONFIG.PSU__CRF_APB__DDR_CTRL__FREQMHZ {1200} \
   CONFIG.PSU__CRF_APB__DDR_CTRL__SRCSEL {DPLL} \
   CONFIG.PSU__CRF_APB__DPDMA_REF_CTRL__ACT_FREQMHZ {599.999878} \
   CONFIG.PSU__CRF_APB__DPDMA_REF_CTRL__DIVISOR0 {2} \
   CONFIG.PSU__CRF_APB__DPDMA_REF_CTRL__FREQMHZ {600} \
   CONFIG.PSU__CRF_APB__DPDMA_REF_CTRL__SRCSEL {DPLL} \
   CONFIG.PSU__CRF_APB__DPLL_CTRL__DIV2 {1} \
   CONFIG.PSU__CRF_APB__DPLL_CTRL__FBDIV {72} \
   CONFIG.PSU__CRF_APB__DPLL_CTRL__FRACDATA {0.000000} \
   CONFIG.PSU__CRF_APB__DPLL_CTRL__FRACFREQ {27.138} \
   CONFIG.PSU__CRF_APB__DPLL_CTRL__SRCSEL {PSS_REF_CLK} \
   CONFIG.PSU__CRF_APB__DPLL_FRAC_CFG__ENABLED {0} \
   CONFIG.PSU__CRF_APB__DPLL_TO_LPD_CTRL__DIVISOR0 {3} \
   CONFIG.PSU__CRF_APB__DP_AUDIO_REF_CTRL__ACT_FREQMHZ {24.999996} \
   CONFIG.PSU__CRF_APB__DP_AUDIO_REF_CTRL__DIVISOR0 {21} \
   CONFIG.PSU__CRF_APB__DP_AUDIO_REF_CTRL__DIVISOR1 {1} \
   CONFIG.PSU__CRF_APB__DP_AUDIO_REF_CTRL__FREQMHZ {25} \
   CONFIG.PSU__CRF_APB__DP_AUDIO_REF_CTRL__SRCSEL {RPLL} \
   CONFIG.PSU__CRF_APB__DP_AUDIO__FRAC_ENABLED {0} \
   CONFIG.PSU__CRF_APB__DP_STC_REF_CTRL__ACT_FREQMHZ {26.249996} \
   CONFIG.PSU__CRF_APB__DP_STC_REF_CTRL__DIVISOR0 {20} \
   CONFIG.PSU__CRF_APB__DP_STC_REF_CTRL__DIVISOR1 {1} \
   CONFIG.PSU__CRF_APB__DP_STC_REF_CTRL__FREQMHZ {27} \
   CONFIG.PSU__CRF_APB__DP_STC_REF_CTRL__SRCSEL {RPLL} \
   CONFIG.PSU__CRF_APB__DP_VIDEO_REF_CTRL__ACT_FREQMHZ {299.999939} \
   CONFIG.PSU__CRF_APB__DP_VIDEO_REF_CTRL__DIVISOR0 {4} \
   CONFIG.PSU__CRF_APB__DP_VIDEO_REF_CTRL__DIVISOR1 {1} \
   CONFIG.PSU__CRF_APB__DP_VIDEO_REF_CTRL__FREQMHZ {300} \
   CONFIG.PSU__CRF_APB__DP_VIDEO_REF_CTRL__SRCSEL {DPLL} \
   CONFIG.PSU__CRF_APB__DP_VIDEO__FRAC_ENABLED {0} \
   CONFIG.PSU__CRF_APB__GDMA_REF_CTRL__ACT_FREQMHZ {599.999878} \
   CONFIG.PSU__CRF_APB__GDMA_REF_CTRL__DIVISOR0 {2} \
   CONFIG.PSU__CRF_APB__GDMA_REF_CTRL__FREQMHZ {600} \
   CONFIG.PSU__CRF_APB__GDMA_REF_CTRL__SRCSEL {DPLL} \
   CONFIG.PSU__CRF_APB__GPU_REF_CTRL__ACT_FREQMHZ {0} \
   CONFIG.PSU__CRF_APB__GPU_REF_CTRL__DIVISOR0 {3} \
   CONFIG.PSU__CRF_APB__GPU_REF_CTRL__FREQMHZ {600} \
   CONFIG.PSU__CRF_APB__GPU_REF_CTRL__SRCSEL {DPLL} \
   CONFIG.PSU__CRF_APB__GTGREF0_REF_CTRL__ACT_FREQMHZ {-1} \
   CONFIG.PSU__CRF_APB__GTGREF0_REF_CTRL__DIVISOR0 {-1} \
   CONFIG.PSU__CRF_APB__GTGREF0_REF_CTRL__FREQMHZ {-1} \
   CONFIG.PSU__CRF_APB__GTGREF0_REF_CTRL__SRCSEL {NA} \
   CONFIG.PSU__CRF_APB__GTGREF0__ENABLE {NA} \
   CONFIG.PSU__CRF_APB__PCIE_REF_CTRL__ACT_FREQMHZ {250} \
   CONFIG.PSU__CRF_APB__PCIE_REF_CTRL__DIVISOR0 {6} \
   CONFIG.PSU__CRF_APB__PCIE_REF_CTRL__FREQMHZ {250} \
   CONFIG.PSU__CRF_APB__PCIE_REF_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRF_APB__SATA_REF_CTRL__ACT_FREQMHZ {250} \
   CONFIG.PSU__CRF_APB__SATA_REF_CTRL__DIVISOR0 {5} \
   CONFIG.PSU__CRF_APB__SATA_REF_CTRL__FREQMHZ {250} \
   CONFIG.PSU__CRF_APB__SATA_REF_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRF_APB__TOPSW_LSBUS_CTRL__ACT_FREQMHZ {99.999985} \
   CONFIG.PSU__CRF_APB__TOPSW_LSBUS_CTRL__DIVISOR0 {5} \
   CONFIG.PSU__CRF_APB__TOPSW_LSBUS_CTRL__FREQMHZ {100} \
   CONFIG.PSU__CRF_APB__TOPSW_LSBUS_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRF_APB__TOPSW_MAIN_CTRL__ACT_FREQMHZ {399.999908} \
   CONFIG.PSU__CRF_APB__TOPSW_MAIN_CTRL__DIVISOR0 {3} \
   CONFIG.PSU__CRF_APB__TOPSW_MAIN_CTRL__FREQMHZ {533.33} \
   CONFIG.PSU__CRF_APB__TOPSW_MAIN_CTRL__SRCSEL {DPLL} \
   CONFIG.PSU__CRF_APB__VPLL_CTRL__DIV2 {1} \
   CONFIG.PSU__CRF_APB__VPLL_CTRL__FBDIV {90} \
   CONFIG.PSU__CRF_APB__VPLL_CTRL__FRACDATA {0.000000} \
   CONFIG.PSU__CRF_APB__VPLL_CTRL__FRACFREQ {27.138} \
   CONFIG.PSU__CRF_APB__VPLL_CTRL__SRCSEL {PSS_REF_CLK} \
   CONFIG.PSU__CRF_APB__VPLL_FRAC_CFG__ENABLED {0} \
   CONFIG.PSU__CRF_APB__VPLL_TO_LPD_CTRL__DIVISOR0 {4} \
   CONFIG.PSU__CRL_APB__ADMA_REF_CTRL__ACT_FREQMHZ {524.999939} \
   CONFIG.PSU__CRL_APB__ADMA_REF_CTRL__DIVISOR0 {2} \
   CONFIG.PSU__CRL_APB__ADMA_REF_CTRL__FREQMHZ {533.333} \
   CONFIG.PSU__CRL_APB__ADMA_REF_CTRL__SRCSEL {RPLL} \
   CONFIG.PSU__CRL_APB__AFI6_REF_CTRL__ACT_FREQMHZ {500} \
   CONFIG.PSU__CRL_APB__AFI6_REF_CTRL__DIVISOR0 {3} \
   CONFIG.PSU__CRL_APB__AFI6_REF_CTRL__FREQMHZ {500} \
   CONFIG.PSU__CRL_APB__AFI6_REF_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRL_APB__AFI6__ENABLE {0} \
   CONFIG.PSU__CRL_APB__AMS_REF_CTRL__ACT_FREQMHZ {49.999992} \
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
   CONFIG.PSU__CRL_APB__CPU_R5_CTRL__ACT_FREQMHZ {499.999908} \
   CONFIG.PSU__CRL_APB__CPU_R5_CTRL__DIVISOR0 {3} \
   CONFIG.PSU__CRL_APB__CPU_R5_CTRL__FREQMHZ {500} \
   CONFIG.PSU__CRL_APB__CPU_R5_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRL_APB__CSU_PLL_CTRL__ACT_FREQMHZ {180} \
   CONFIG.PSU__CRL_APB__CSU_PLL_CTRL__DIVISOR0 {3} \
   CONFIG.PSU__CRL_APB__CSU_PLL_CTRL__FREQMHZ {180} \
   CONFIG.PSU__CRL_APB__CSU_PLL_CTRL__SRCSEL {SysOsc} \
   CONFIG.PSU__CRL_APB__DBG_LPD_CTRL__ACT_FREQMHZ {249.999954} \
   CONFIG.PSU__CRL_APB__DBG_LPD_CTRL__DIVISOR0 {6} \
   CONFIG.PSU__CRL_APB__DBG_LPD_CTRL__FREQMHZ {250} \
   CONFIG.PSU__CRL_APB__DBG_LPD_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRL_APB__DEBUG_R5_ATCLK_CTRL__ACT_FREQMHZ {1000} \
   CONFIG.PSU__CRL_APB__DEBUG_R5_ATCLK_CTRL__DIVISOR0 {6} \
   CONFIG.PSU__CRL_APB__DEBUG_R5_ATCLK_CTRL__FREQMHZ {1000} \
   CONFIG.PSU__CRL_APB__DEBUG_R5_ATCLK_CTRL__SRCSEL {RPLL} \
   CONFIG.PSU__CRL_APB__DLL_REF_CTRL__ACT_FREQMHZ {1499.999756} \
   CONFIG.PSU__CRL_APB__DLL_REF_CTRL__FREQMHZ {1500} \
   CONFIG.PSU__CRL_APB__DLL_REF_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRL_APB__GEM0_REF_CTRL__ACT_FREQMHZ {125} \
   CONFIG.PSU__CRL_APB__GEM0_REF_CTRL__DIVISOR0 {12} \
   CONFIG.PSU__CRL_APB__GEM0_REF_CTRL__DIVISOR1 {1} \
   CONFIG.PSU__CRL_APB__GEM0_REF_CTRL__FREQMHZ {125} \
   CONFIG.PSU__CRL_APB__GEM0_REF_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRL_APB__GEM1_REF_CTRL__ACT_FREQMHZ {124.999977} \
   CONFIG.PSU__CRL_APB__GEM1_REF_CTRL__DIVISOR0 {12} \
   CONFIG.PSU__CRL_APB__GEM1_REF_CTRL__DIVISOR1 {1} \
   CONFIG.PSU__CRL_APB__GEM1_REF_CTRL__FREQMHZ {125} \
   CONFIG.PSU__CRL_APB__GEM1_REF_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRL_APB__GEM2_REF_CTRL__ACT_FREQMHZ {125} \
   CONFIG.PSU__CRL_APB__GEM2_REF_CTRL__DIVISOR0 {12} \
   CONFIG.PSU__CRL_APB__GEM2_REF_CTRL__DIVISOR1 {1} \
   CONFIG.PSU__CRL_APB__GEM2_REF_CTRL__FREQMHZ {125} \
   CONFIG.PSU__CRL_APB__GEM2_REF_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRL_APB__GEM3_REF_CTRL__ACT_FREQMHZ {125} \
   CONFIG.PSU__CRL_APB__GEM3_REF_CTRL__DIVISOR0 {12} \
   CONFIG.PSU__CRL_APB__GEM3_REF_CTRL__DIVISOR1 {1} \
   CONFIG.PSU__CRL_APB__GEM3_REF_CTRL__FREQMHZ {125} \
   CONFIG.PSU__CRL_APB__GEM3_REF_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRL_APB__GEM_TSU_REF_CTRL__ACT_FREQMHZ {249.999954} \
   CONFIG.PSU__CRL_APB__GEM_TSU_REF_CTRL__DIVISOR0 {6} \
   CONFIG.PSU__CRL_APB__GEM_TSU_REF_CTRL__DIVISOR1 {1} \
   CONFIG.PSU__CRL_APB__GEM_TSU_REF_CTRL__FREQMHZ {250} \
   CONFIG.PSU__CRL_APB__GEM_TSU_REF_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRL_APB__I2C0_REF_CTRL__ACT_FREQMHZ {99.999985} \
   CONFIG.PSU__CRL_APB__I2C0_REF_CTRL__DIVISOR0 {15} \
   CONFIG.PSU__CRL_APB__I2C0_REF_CTRL__DIVISOR1 {1} \
   CONFIG.PSU__CRL_APB__I2C0_REF_CTRL__FREQMHZ {100} \
   CONFIG.PSU__CRL_APB__I2C0_REF_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRL_APB__I2C1_REF_CTRL__ACT_FREQMHZ {99.999985} \
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
   CONFIG.PSU__CRL_APB__IOU_SWITCH_CTRL__ACT_FREQMHZ {262.499969} \
   CONFIG.PSU__CRL_APB__IOU_SWITCH_CTRL__DIVISOR0 {4} \
   CONFIG.PSU__CRL_APB__IOU_SWITCH_CTRL__FREQMHZ {267} \
   CONFIG.PSU__CRL_APB__IOU_SWITCH_CTRL__SRCSEL {RPLL} \
   CONFIG.PSU__CRL_APB__LPD_LSBUS_CTRL__ACT_FREQMHZ {99.999985} \
   CONFIG.PSU__CRL_APB__LPD_LSBUS_CTRL__DIVISOR0 {15} \
   CONFIG.PSU__CRL_APB__LPD_LSBUS_CTRL__FREQMHZ {100} \
   CONFIG.PSU__CRL_APB__LPD_LSBUS_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRL_APB__LPD_SWITCH_CTRL__ACT_FREQMHZ {524.999939} \
   CONFIG.PSU__CRL_APB__LPD_SWITCH_CTRL__DIVISOR0 {2} \
   CONFIG.PSU__CRL_APB__LPD_SWITCH_CTRL__FREQMHZ {533.333} \
   CONFIG.PSU__CRL_APB__LPD_SWITCH_CTRL__SRCSEL {RPLL} \
   CONFIG.PSU__CRL_APB__NAND_REF_CTRL__ACT_FREQMHZ {100} \
   CONFIG.PSU__CRL_APB__NAND_REF_CTRL__DIVISOR0 {15} \
   CONFIG.PSU__CRL_APB__NAND_REF_CTRL__DIVISOR1 {1} \
   CONFIG.PSU__CRL_APB__NAND_REF_CTRL__FREQMHZ {100} \
   CONFIG.PSU__CRL_APB__NAND_REF_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRL_APB__OCM_MAIN_CTRL__ACT_FREQMHZ {500} \
   CONFIG.PSU__CRL_APB__OCM_MAIN_CTRL__DIVISOR0 {3} \
   CONFIG.PSU__CRL_APB__OCM_MAIN_CTRL__FREQMHZ {500} \
   CONFIG.PSU__CRL_APB__OCM_MAIN_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRL_APB__PCAP_CTRL__ACT_FREQMHZ {187.499969} \
   CONFIG.PSU__CRL_APB__PCAP_CTRL__DIVISOR0 {8} \
   CONFIG.PSU__CRL_APB__PCAP_CTRL__FREQMHZ {200} \
   CONFIG.PSU__CRL_APB__PCAP_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRL_APB__PL0_REF_CTRL__ACT_FREQMHZ {99.999985} \
   CONFIG.PSU__CRL_APB__PL0_REF_CTRL__DIVISOR0 {15} \
   CONFIG.PSU__CRL_APB__PL0_REF_CTRL__DIVISOR1 {1} \
   CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ {100} \
   CONFIG.PSU__CRL_APB__PL0_REF_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRL_APB__PL1_REF_CTRL__ACT_FREQMHZ {100} \
   CONFIG.PSU__CRL_APB__PL1_REF_CTRL__DIVISOR0 {4} \
   CONFIG.PSU__CRL_APB__PL1_REF_CTRL__DIVISOR1 {1} \
   CONFIG.PSU__CRL_APB__PL1_REF_CTRL__FREQMHZ {100} \
   CONFIG.PSU__CRL_APB__PL1_REF_CTRL__SRCSEL {RPLL} \
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
   CONFIG.PSU__CRL_APB__QSPI_REF_CTRL__ACT_FREQMHZ {300} \
   CONFIG.PSU__CRL_APB__QSPI_REF_CTRL__DIVISOR0 {5} \
   CONFIG.PSU__CRL_APB__QSPI_REF_CTRL__DIVISOR1 {1} \
   CONFIG.PSU__CRL_APB__QSPI_REF_CTRL__FREQMHZ {125} \
   CONFIG.PSU__CRL_APB__QSPI_REF_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRL_APB__RPLL_CTRL__DIV2 {1} \
   CONFIG.PSU__CRL_APB__RPLL_CTRL__FBDIV {63} \
   CONFIG.PSU__CRL_APB__RPLL_CTRL__FRACDATA {0.000000} \
   CONFIG.PSU__CRL_APB__RPLL_CTRL__FRACFREQ {27.138} \
   CONFIG.PSU__CRL_APB__RPLL_CTRL__SRCSEL {PSS_REF_CLK} \
   CONFIG.PSU__CRL_APB__RPLL_FRAC_CFG__ENABLED {0} \
   CONFIG.PSU__CRL_APB__RPLL_TO_FPD_CTRL__DIVISOR0 {2} \
   CONFIG.PSU__CRL_APB__SDIO0_REF_CTRL__ACT_FREQMHZ {187.499969} \
   CONFIG.PSU__CRL_APB__SDIO0_REF_CTRL__DIVISOR0 {8} \
   CONFIG.PSU__CRL_APB__SDIO0_REF_CTRL__DIVISOR1 {1} \
   CONFIG.PSU__CRL_APB__SDIO0_REF_CTRL__FREQMHZ {200} \
   CONFIG.PSU__CRL_APB__SDIO0_REF_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRL_APB__SDIO1_REF_CTRL__ACT_FREQMHZ {200} \
   CONFIG.PSU__CRL_APB__SDIO1_REF_CTRL__DIVISOR0 {7} \
   CONFIG.PSU__CRL_APB__SDIO1_REF_CTRL__DIVISOR1 {1} \
   CONFIG.PSU__CRL_APB__SDIO1_REF_CTRL__FREQMHZ {200} \
   CONFIG.PSU__CRL_APB__SDIO1_REF_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRL_APB__SPI0_REF_CTRL__ACT_FREQMHZ {187.499969} \
   CONFIG.PSU__CRL_APB__SPI0_REF_CTRL__DIVISOR0 {8} \
   CONFIG.PSU__CRL_APB__SPI0_REF_CTRL__DIVISOR1 {1} \
   CONFIG.PSU__CRL_APB__SPI0_REF_CTRL__FREQMHZ {200} \
   CONFIG.PSU__CRL_APB__SPI0_REF_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRL_APB__SPI1_REF_CTRL__ACT_FREQMHZ {187.499969} \
   CONFIG.PSU__CRL_APB__SPI1_REF_CTRL__DIVISOR0 {8} \
   CONFIG.PSU__CRL_APB__SPI1_REF_CTRL__DIVISOR1 {1} \
   CONFIG.PSU__CRL_APB__SPI1_REF_CTRL__FREQMHZ {200} \
   CONFIG.PSU__CRL_APB__SPI1_REF_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRL_APB__TIMESTAMP_REF_CTRL__ACT_FREQMHZ {33.333328} \
   CONFIG.PSU__CRL_APB__TIMESTAMP_REF_CTRL__DIVISOR0 {1} \
   CONFIG.PSU__CRL_APB__TIMESTAMP_REF_CTRL__FREQMHZ {100} \
   CONFIG.PSU__CRL_APB__TIMESTAMP_REF_CTRL__SRCSEL {PSS_REF_CLK} \
   CONFIG.PSU__CRL_APB__UART0_REF_CTRL__ACT_FREQMHZ {100} \
   CONFIG.PSU__CRL_APB__UART0_REF_CTRL__DIVISOR0 {15} \
   CONFIG.PSU__CRL_APB__UART0_REF_CTRL__DIVISOR1 {1} \
   CONFIG.PSU__CRL_APB__UART0_REF_CTRL__FREQMHZ {100} \
   CONFIG.PSU__CRL_APB__UART0_REF_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRL_APB__UART1_REF_CTRL__ACT_FREQMHZ {99.999985} \
   CONFIG.PSU__CRL_APB__UART1_REF_CTRL__DIVISOR0 {15} \
   CONFIG.PSU__CRL_APB__UART1_REF_CTRL__DIVISOR1 {1} \
   CONFIG.PSU__CRL_APB__UART1_REF_CTRL__FREQMHZ {100} \
   CONFIG.PSU__CRL_APB__UART1_REF_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRL_APB__USB0_BUS_REF_CTRL__ACT_FREQMHZ {249.999954} \
   CONFIG.PSU__CRL_APB__USB0_BUS_REF_CTRL__DIVISOR0 {6} \
   CONFIG.PSU__CRL_APB__USB0_BUS_REF_CTRL__DIVISOR1 {1} \
   CONFIG.PSU__CRL_APB__USB0_BUS_REF_CTRL__FREQMHZ {250} \
   CONFIG.PSU__CRL_APB__USB0_BUS_REF_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRL_APB__USB1_BUS_REF_CTRL__ACT_FREQMHZ {249.999954} \
   CONFIG.PSU__CRL_APB__USB1_BUS_REF_CTRL__DIVISOR0 {6} \
   CONFIG.PSU__CRL_APB__USB1_BUS_REF_CTRL__DIVISOR1 {1} \
   CONFIG.PSU__CRL_APB__USB1_BUS_REF_CTRL__FREQMHZ {250} \
   CONFIG.PSU__CRL_APB__USB1_BUS_REF_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRL_APB__USB3_DUAL_REF_CTRL__ACT_FREQMHZ {19.999996} \
   CONFIG.PSU__CRL_APB__USB3_DUAL_REF_CTRL__DIVISOR0 {25} \
   CONFIG.PSU__CRL_APB__USB3_DUAL_REF_CTRL__DIVISOR1 {3} \
   CONFIG.PSU__CRL_APB__USB3_DUAL_REF_CTRL__FREQMHZ {20} \
   CONFIG.PSU__CRL_APB__USB3_DUAL_REF_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRL_APB__USB3__ENABLE {1} \
   CONFIG.PSU__CSUPMU__PERIPHERAL__VALID {0} \
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
   CONFIG.PSU__DDRC__CL {16} \
   CONFIG.PSU__DDRC__CLOCK_STOP_EN {0} \
   CONFIG.PSU__DDRC__COL_ADDR_COUNT {10} \
   CONFIG.PSU__DDRC__COMPONENTS {Components} \
   CONFIG.PSU__DDRC__CWL {12} \
   CONFIG.PSU__DDRC__DDR3L_T_REF_RANGE {NA} \
   CONFIG.PSU__DDRC__DDR3_T_REF_RANGE {NA} \
   CONFIG.PSU__DDRC__DDR4_ADDR_MAPPING {1} \
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
   CONFIG.PSU__DDRC__SB_TARGET {16-16-16} \
   CONFIG.PSU__DDRC__SELF_REF_ABORT {0} \
   CONFIG.PSU__DDRC__SPEED_BIN {DDR4_2400R} \
   CONFIG.PSU__DDRC__STATIC_RD_MODE {0} \
   CONFIG.PSU__DDRC__TRAIN_DATA_EYE {1} \
   CONFIG.PSU__DDRC__TRAIN_READ_GATE {1} \
   CONFIG.PSU__DDRC__TRAIN_WRITE_LEVEL {1} \
   CONFIG.PSU__DDRC__T_FAW {30.0} \
   CONFIG.PSU__DDRC__T_RAS_MIN {32.0} \
   CONFIG.PSU__DDRC__T_RC {45.32} \
   CONFIG.PSU__DDRC__T_RCD {16} \
   CONFIG.PSU__DDRC__T_RP {16} \
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
   CONFIG.PSU__DDR__INTERFACE__FREQMHZ {600.000} \
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
   CONFIG.PSU__DP__REF_CLK_SEL {Ref Clk0} \
   CONFIG.PSU__ENABLE__DDR__REFRESH__SIGNALS {0} \
   CONFIG.PSU__ENET0__FIFO__ENABLE {0} \
   CONFIG.PSU__ENET0__GRP_MDIO__ENABLE {0} \
   CONFIG.PSU__ENET0__PERIPHERAL__ENABLE {0} \
   CONFIG.PSU__ENET0__PTP__ENABLE {0} \
   CONFIG.PSU__ENET0__TSU__ENABLE {0} \
   CONFIG.PSU__ENET1__FIFO__ENABLE {0} \
   CONFIG.PSU__ENET1__GRP_MDIO__ENABLE {1} \
   CONFIG.PSU__ENET1__GRP_MDIO__IO {MIO 50 .. 51} \
   CONFIG.PSU__ENET1__PERIPHERAL__ENABLE {1} \
   CONFIG.PSU__ENET1__PERIPHERAL__IO {MIO 38 .. 49} \
   CONFIG.PSU__ENET1__PTP__ENABLE {0} \
   CONFIG.PSU__ENET1__TSU__ENABLE {0} \
   CONFIG.PSU__ENET2__FIFO__ENABLE {0} \
   CONFIG.PSU__ENET2__GRP_MDIO__ENABLE {0} \
   CONFIG.PSU__ENET2__PERIPHERAL__ENABLE {0} \
   CONFIG.PSU__ENET2__PTP__ENABLE {0} \
   CONFIG.PSU__ENET2__TSU__ENABLE {0} \
   CONFIG.PSU__ENET3__FIFO__ENABLE {0} \
   CONFIG.PSU__ENET3__GRP_MDIO__ENABLE {0} \
   CONFIG.PSU__ENET3__PERIPHERAL__ENABLE {0} \
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
   CONFIG.PSU__FPD_SLCR__WDT1__ACT_FREQMHZ {100} \
   CONFIG.PSU__FPD_SLCR__WDT1__FREQMHZ {100} \
   CONFIG.PSU__FPD_SLCR__WDT_CLK_SEL__SELECT {APB} \
   CONFIG.PSU__FPGA_PL0_ENABLE {1} \
   CONFIG.PSU__FPGA_PL1_ENABLE {0} \
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
   CONFIG.PSU__GPIO2_MIO__IO {MIO 52 .. 77} \
   CONFIG.PSU__GPIO2_MIO__PERIPHERAL__ENABLE {1} \
   CONFIG.PSU__GPIO_EMIO_WIDTH {95} \
   CONFIG.PSU__GPIO_EMIO__PERIPHERAL__ENABLE {1} \
   CONFIG.PSU__GPIO_EMIO__PERIPHERAL__IO {95} \
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
   CONFIG.PSU__I2C0__PERIPHERAL__IO {MIO 18 .. 19} \
   CONFIG.PSU__I2C1__GRP_INT__ENABLE {0} \
   CONFIG.PSU__I2C1__PERIPHERAL__ENABLE {1} \
   CONFIG.PSU__I2C1__PERIPHERAL__IO {MIO 36 .. 37} \
   CONFIG.PSU__IOU_SLCR__IOU_TTC_APB_CLK__TTC0_SEL {APB} \
   CONFIG.PSU__IOU_SLCR__IOU_TTC_APB_CLK__TTC1_SEL {APB} \
   CONFIG.PSU__IOU_SLCR__IOU_TTC_APB_CLK__TTC2_SEL {APB} \
   CONFIG.PSU__IOU_SLCR__IOU_TTC_APB_CLK__TTC3_SEL {APB} \
   CONFIG.PSU__IOU_SLCR__TTC0__ACT_FREQMHZ {100} \
   CONFIG.PSU__IOU_SLCR__TTC0__FREQMHZ {100} \
   CONFIG.PSU__IOU_SLCR__TTC1__ACT_FREQMHZ {100} \
   CONFIG.PSU__IOU_SLCR__TTC1__FREQMHZ {100} \
   CONFIG.PSU__IOU_SLCR__TTC2__ACT_FREQMHZ {100} \
   CONFIG.PSU__IOU_SLCR__TTC2__FREQMHZ {100} \
   CONFIG.PSU__IOU_SLCR__TTC3__ACT_FREQMHZ {100} \
   CONFIG.PSU__IOU_SLCR__TTC3__FREQMHZ {100} \
   CONFIG.PSU__IOU_SLCR__WDT0__ACT_FREQMHZ {100} \
   CONFIG.PSU__IOU_SLCR__WDT0__FREQMHZ {100} \
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
   CONFIG.PSU__LPD_SLCR__CSUPMU__ACT_FREQMHZ {100} \
   CONFIG.PSU__LPD_SLCR__CSUPMU__FREQMHZ {100} \
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
   CONFIG.PSU__PL_CLK1_BUF {FALSE} \
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
   CONFIG.PSU__PMU__GPO0__ENABLE {0} \
   CONFIG.PSU__PMU__GPO1__ENABLE {0} \
   CONFIG.PSU__PMU__GPO2__ENABLE {0} \
   CONFIG.PSU__PMU__GPO3__ENABLE {0} \
   CONFIG.PSU__PMU__GPO4__ENABLE {0} \
   CONFIG.PSU__PMU__GPO5__ENABLE {0} \
   CONFIG.PSU__PMU__PERIPHERAL__ENABLE {0} \
   CONFIG.PSU__PMU__PLERROR__ENABLE {0} \
   CONFIG.PSU__PRESET_APPLIED {1} \
   CONFIG.PSU__PROTECTION__DDR_SEGMENTS {NONE} \
   CONFIG.PSU__PROTECTION__DEBUG {0} \
   CONFIG.PSU__PROTECTION__ENABLE {0} \
   CONFIG.PSU__PROTECTION__FPD_SEGMENTS {\
SA:0xFD1A0000; SIZE:1280; UNIT:KB; RegionTZ:Secure; WrAllowed:Read/Write;\
subsystemId:PMU Firmware |  SA:0xFD000000; SIZE:64; UNIT:KB; RegionTZ:Secure;\
WrAllowed:Read/Write; subsystemId:PMU Firmware |  SA:0xFD010000; SIZE:64;\
UNIT:KB; RegionTZ:Secure; WrAllowed:Read/Write; subsystemId:PMU Firmware | \
SA:0xFD020000; SIZE:64; UNIT:KB; RegionTZ:Secure; WrAllowed:Read/Write;\
subsystemId:PMU Firmware |  SA:0xFD030000; SIZE:64; UNIT:KB; RegionTZ:Secure;\
WrAllowed:Read/Write; subsystemId:PMU Firmware |  SA:0xFD040000; SIZE:64;\
UNIT:KB; RegionTZ:Secure; WrAllowed:Read/Write; subsystemId:PMU Firmware | \
SA:0xFD050000; SIZE:64; UNIT:KB; RegionTZ:Secure; WrAllowed:Read/Write;\
subsystemId:PMU Firmware |  SA:0xFD610000; SIZE:512; UNIT:KB; RegionTZ:Secure;\
WrAllowed:Read/Write; subsystemId:PMU Firmware |  SA:0xFD5D0000; SIZE:64;\
UNIT:KB; RegionTZ:Secure; WrAllowed:Read/Write; subsystemId:PMU Firmware |\
SA:0xFD1A0000 ; SIZE:1280; UNIT:KB; RegionTZ:Secure ; WrAllowed:Read/Write;\
subsystemId:Secure Subsystem} \
   CONFIG.PSU__PROTECTION__LOCK_UNUSED_SEGMENTS {0} \
   CONFIG.PSU__PROTECTION__LPD_SEGMENTS {\
SA:0xFF980000; SIZE:64; UNIT:KB; RegionTZ:Secure; WrAllowed:Read/Write;\
subsystemId:PMU Firmware| SA:0xFF5E0000; SIZE:2560; UNIT:KB; RegionTZ:Secure;\
WrAllowed:Read/Write; subsystemId:PMU Firmware| SA:0xFFCC0000; SIZE:64;\
UNIT:KB; RegionTZ:Secure; WrAllowed:Read/Write; subsystemId:PMU Firmware|\
SA:0xFF180000; SIZE:768; UNIT:KB; RegionTZ:Secure; WrAllowed:Read/Write;\
subsystemId:PMU Firmware| SA:0xFF410000; SIZE:640; UNIT:KB; RegionTZ:Secure;\
WrAllowed:Read/Write; subsystemId:PMU Firmware| SA:0xFFA70000; SIZE:64;\
UNIT:KB; RegionTZ:Secure; WrAllowed:Read/Write; subsystemId:PMU Firmware|\
SA:0xFF9A0000; SIZE:64; UNIT:KB; RegionTZ:Secure; WrAllowed:Read/Write;\
subsystemId:PMU Firmware|SA:0xFF5E0000 ; SIZE:2560; UNIT:KB; RegionTZ:Secure ;\
WrAllowed:Read/Write; subsystemId:Secure Subsystem|SA:0xFFCC0000 ; SIZE:64;\
UNIT:KB; RegionTZ:Secure ; WrAllowed:Read/Write; subsystemId:Secure\
Subsystem|SA:0xFF180000 ; SIZE:768; UNIT:KB; RegionTZ:Secure ;\
WrAllowed:Read/Write; subsystemId:Secure Subsystem|SA:0xFF9A0000 ; SIZE:64;\
UNIT:KB; RegionTZ:Secure ; WrAllowed:Read/Write; subsystemId:Secure Subsystem} \
   CONFIG.PSU__PROTECTION__MASTERS {\
USB1:NonSecure;1|USB0:NonSecure;1|S_AXI_LPD:NA;0|S_AXI_HPC1_FPD:NA;0|S_AXI_HPC0_FPD:NA;1|S_AXI_HP3_FPD:NA;0|S_AXI_HP2_FPD:NA;0|S_AXI_HP1_FPD:NA;0|S_AXI_HP0_FPD:NA;0|S_AXI_ACP:NA;0|S_AXI_ACE:NA;0|SD1:NonSecure;0|SD0:NonSecure;1|SATA1:NonSecure;0|SATA0:NonSecure;0|RPU1:Secure;1|RPU0:Secure;1|QSPI:NonSecure;0|PMU:NA;1|PCIe:NonSecure;0|NAND:NonSecure;0|LDMA:NonSecure;1|GPU:NonSecure;1|GEM3:NonSecure;0|GEM2:NonSecure;0|GEM1:NonSecure;1|GEM0:NonSecure;0|FDMA:NonSecure;1|DP:NonSecure;1|DAP:NA;1|Coresight:NA;1|CSU:NA;1|APU:NA;1} \
   CONFIG.PSU__PROTECTION__MASTERS_TZ {\
GEM0:NonSecure|SD1:NonSecure|GEM2:NonSecure|GEM1:NonSecure|GEM3:NonSecure|PCIe:NonSecure|DP:NonSecure|NAND:NonSecure|GPU:NonSecure|USB1:NonSecure|USB0:NonSecure|LDMA:NonSecure|FDMA:NonSecure|QSPI:NonSecure|SD0:NonSecure} \
   CONFIG.PSU__PROTECTION__OCM_SEGMENTS {NONE} \
   CONFIG.PSU__PROTECTION__PRESUBSYSTEMS {NONE} \
   CONFIG.PSU__PROTECTION__SLAVES {\
LPD;USB3_1_XHCI;FE300000;FE3FFFFF;1|LPD;USB3_1;FF9E0000;FF9EFFFF;1|LPD;USB3_0_XHCI;FE200000;FE2FFFFF;1|LPD;USB3_0;FF9D0000;FF9DFFFF;1|LPD;UART1;FF010000;FF01FFFF;1|LPD;UART0;FF000000;FF00FFFF;0|LPD;TTC3;FF140000;FF14FFFF;0|LPD;TTC2;FF130000;FF13FFFF;0|LPD;TTC1;FF120000;FF12FFFF;0|LPD;TTC0;FF110000;FF11FFFF;0|FPD;SWDT1;FD4D0000;FD4DFFFF;0|LPD;SWDT0;FF150000;FF15FFFF;0|LPD;SPI1;FF050000;FF05FFFF;1|LPD;SPI0;FF040000;FF04FFFF;1|FPD;SMMU_REG;FD5F0000;FD5FFFFF;1|FPD;SMMU;FD800000;FDFFFFFF;1|FPD;SIOU;FD3D0000;FD3DFFFF;1|FPD;SERDES;FD400000;FD47FFFF;1|LPD;SD1;FF170000;FF17FFFF;0|LPD;SD0;FF160000;FF16FFFF;1|FPD;SATA;FD0C0000;FD0CFFFF;0|LPD;RTC;FFA60000;FFA6FFFF;1|LPD;RSA_CORE;FFCE0000;FFCEFFFF;1|LPD;RPU;FF9A0000;FF9AFFFF;1|LPD;R5_TCM_RAM_GLOBAL;FFE00000;FFE3FFFF;1|LPD;R5_1_Instruction_Cache;FFEC0000;FFECFFFF;1|LPD;R5_1_Data_Cache;FFED0000;FFEDFFFF;1|LPD;R5_1_BTCM_GLOBAL;FFEB0000;FFEBFFFF;1|LPD;R5_1_ATCM_GLOBAL;FFE90000;FFE9FFFF;1|LPD;R5_0_Instruction_Cache;FFE40000;FFE4FFFF;1|LPD;R5_0_Data_Cache;FFE50000;FFE5FFFF;1|LPD;R5_0_BTCM_GLOBAL;FFE20000;FFE2FFFF;1|LPD;R5_0_ATCM_GLOBAL;FFE00000;FFE0FFFF;1|LPD;QSPI_Linear_Address;C0000000;DFFFFFFF;1|LPD;QSPI;FF0F0000;FF0FFFFF;0|LPD;PMU_RAM;FFDC0000;FFDDFFFF;1|LPD;PMU_GLOBAL;FFD80000;FFDBFFFF;1|FPD;PCIE_MAIN;FD0E0000;FD0EFFFF;0|FPD;PCIE_LOW;E0000000;EFFFFFFF;0|FPD;PCIE_HIGH2;8000000000;BFFFFFFFFF;0|FPD;PCIE_HIGH1;600000000;7FFFFFFFF;0|FPD;PCIE_DMA;FD0F0000;FD0FFFFF;0|FPD;PCIE_ATTRIB;FD480000;FD48FFFF;0|LPD;OCM_XMPU_CFG;FFA70000;FFA7FFFF;1|LPD;OCM_SLCR;FF960000;FF96FFFF;1|OCM;OCM;FFFC0000;FFFFFFFF;1|LPD;NAND;FF100000;FF10FFFF;0|LPD;MBISTJTAG;FFCF0000;FFCFFFFF;1|LPD;LPD_XPPU_SINK;FF9C0000;FF9CFFFF;1|LPD;LPD_XPPU;FF980000;FF98FFFF;1|LPD;LPD_SLCR_SECURE;FF4B0000;FF4DFFFF;1|LPD;LPD_SLCR;FF410000;FF4AFFFF;1|LPD;LPD_GPV;FE100000;FE1FFFFF;1|LPD;LPD_DMA_7;FFAF0000;FFAFFFFF;1|LPD;LPD_DMA_6;FFAE0000;FFAEFFFF;1|LPD;LPD_DMA_5;FFAD0000;FFADFFFF;1|LPD;LPD_DMA_4;FFAC0000;FFACFFFF;1|LPD;LPD_DMA_3;FFAB0000;FFABFFFF;1|LPD;LPD_DMA_2;FFAA0000;FFAAFFFF;1|LPD;LPD_DMA_1;FFA90000;FFA9FFFF;1|LPD;LPD_DMA_0;FFA80000;FFA8FFFF;1|LPD;IPI_CTRL;FF380000;FF3FFFFF;1|LPD;IOU_SLCR;FF180000;FF23FFFF;1|LPD;IOU_SECURE_SLCR;FF240000;FF24FFFF;1|LPD;IOU_SCNTRS;FF260000;FF26FFFF;1|LPD;IOU_SCNTR;FF250000;FF25FFFF;1|LPD;IOU_GPV;FE000000;FE0FFFFF;1|LPD;I2C1;FF030000;FF03FFFF;1|LPD;I2C0;FF020000;FF02FFFF;1|FPD;GPU;FD4B0000;FD4BFFFF;0|LPD;GPIO;FF0A0000;FF0AFFFF;1|LPD;GEM3;FF0E0000;FF0EFFFF;0|LPD;GEM2;FF0D0000;FF0DFFFF;0|LPD;GEM1;FF0C0000;FF0CFFFF;1|LPD;GEM0;FF0B0000;FF0BFFFF;0|FPD;FPD_XMPU_SINK;FD4F0000;FD4FFFFF;1|FPD;FPD_XMPU_CFG;FD5D0000;FD5DFFFF;1|FPD;FPD_SLCR_SECURE;FD690000;FD6CFFFF;1|FPD;FPD_SLCR;FD610000;FD68FFFF;1|FPD;FPD_DMA_CH7;FD570000;FD57FFFF;1|FPD;FPD_DMA_CH6;FD560000;FD56FFFF;1|FPD;FPD_DMA_CH5;FD550000;FD55FFFF;1|FPD;FPD_DMA_CH4;FD540000;FD54FFFF;1|FPD;FPD_DMA_CH3;FD530000;FD53FFFF;1|FPD;FPD_DMA_CH2;FD520000;FD52FFFF;1|FPD;FPD_DMA_CH1;FD510000;FD51FFFF;1|FPD;FPD_DMA_CH0;FD500000;FD50FFFF;1|LPD;EFUSE;FFCC0000;FFCCFFFF;1|FPD;Display\
Port;FD4A0000;FD4AFFFF;1|FPD;DPDMA;FD4C0000;FD4CFFFF;1|FPD;DDR_XMPU5_CFG;FD050000;FD05FFFF;1|FPD;DDR_XMPU4_CFG;FD040000;FD04FFFF;1|FPD;DDR_XMPU3_CFG;FD030000;FD03FFFF;1|FPD;DDR_XMPU2_CFG;FD020000;FD02FFFF;1|FPD;DDR_XMPU1_CFG;FD010000;FD01FFFF;1|FPD;DDR_XMPU0_CFG;FD000000;FD00FFFF;1|FPD;DDR_QOS_CTRL;FD090000;FD09FFFF;1|FPD;DDR_PHY;FD080000;FD08FFFF;1|DDR;DDR_LOW;0;7FFFFFFF;1|DDR;DDR_HIGH;800000000;87FFFFFFF;1|FPD;DDDR_CTRL;FD070000;FD070FFF;1|LPD;Coresight;FE800000;FEFFFFFF;1|LPD;CSU_DMA;FFC80000;FFC9FFFF;1|LPD;CSU;FFCA0000;FFCAFFFF;1|LPD;CRL_APB;FF5E0000;FF85FFFF;1|FPD;CRF_APB;FD1A0000;FD2DFFFF;1|FPD;CCI_REG;FD5E0000;FD5EFFFF;1|LPD;CAN1;FF070000;FF07FFFF;0|LPD;CAN0;FF060000;FF06FFFF;0|FPD;APU;FD5C0000;FD5CFFFF;1|LPD;APM_INTC_IOU;FFA20000;FFA2FFFF;1|LPD;APM_FPD_LPD;FFA30000;FFA3FFFF;1|FPD;APM_5;FD490000;FD49FFFF;1|FPD;APM_0;FD0B0000;FD0BFFFF;1|LPD;APM2;FFA10000;FFA1FFFF;1|LPD;APM1;FFA00000;FFA0FFFF;1|LPD;AMS;FFA50000;FFA5FFFF;1|FPD;AFI_5;FD3B0000;FD3BFFFF;1|FPD;AFI_4;FD3A0000;FD3AFFFF;1|FPD;AFI_3;FD390000;FD39FFFF;1|FPD;AFI_2;FD380000;FD38FFFF;1|FPD;AFI_1;FD370000;FD37FFFF;1|FPD;AFI_0;FD360000;FD36FFFF;1|LPD;AFIFM6;FF9B0000;FF9BFFFF;1|FPD;ACPU_GIC;F9010000;F907FFFF;1} \
   CONFIG.PSU__PROTECTION__SUBSYSTEMS {PMU Firmware:PMU|Secure Subsystem:} \
   CONFIG.PSU__PSS_ALT_REF_CLK__ENABLE {0} \
   CONFIG.PSU__PSS_ALT_REF_CLK__FREQMHZ {33.333} \
   CONFIG.PSU__PSS_REF_CLK__FREQMHZ {33.33333} \
   CONFIG.PSU__QSPI_COHERENCY {0} \
   CONFIG.PSU__QSPI_ROUTE_THROUGH_FPD {0} \
   CONFIG.PSU__QSPI__GRP_FBCLK__ENABLE {0} \
   CONFIG.PSU__QSPI__PERIPHERAL__ENABLE {0} \
   CONFIG.PSU__REPORT__DBGLOG {0} \
   CONFIG.PSU__RPU_COHERENCY {0} \
   CONFIG.PSU__RPU__POWER__ON {1} \
   CONFIG.PSU__SATA__LANE0__ENABLE {0} \
   CONFIG.PSU__SATA__LANE1__ENABLE {0} \
   CONFIG.PSU__SATA__PERIPHERAL__ENABLE {0} \
   CONFIG.PSU__SAXIGP0__DATA_WIDTH {128} \
   CONFIG.PSU__SAXIGP1__DATA_WIDTH {128} \
   CONFIG.PSU__SAXIGP2__DATA_WIDTH {128} \
   CONFIG.PSU__SAXIGP3__DATA_WIDTH {128} \
   CONFIG.PSU__SAXIGP4__DATA_WIDTH {128} \
   CONFIG.PSU__SAXIGP5__DATA_WIDTH {128} \
   CONFIG.PSU__SAXIGP6__DATA_WIDTH {128} \
   CONFIG.PSU__SD0_COHERENCY {0} \
   CONFIG.PSU__SD0_ROUTE_THROUGH_FPD {0} \
   CONFIG.PSU__SD0__CLK_100_SDR_OTAP_DLY {0x0} \
   CONFIG.PSU__SD0__CLK_200_SDR_OTAP_DLY {0x0} \
   CONFIG.PSU__SD0__CLK_50_DDR_ITAP_DLY {0x0} \
   CONFIG.PSU__SD0__CLK_50_DDR_OTAP_DLY {0x0} \
   CONFIG.PSU__SD0__CLK_50_SDR_ITAP_DLY {0x15} \
   CONFIG.PSU__SD0__CLK_50_SDR_OTAP_DLY {0x5} \
   CONFIG.PSU__SD0__DATA_TRANSFER_MODE {4Bit} \
   CONFIG.PSU__SD0__GRP_CD__ENABLE {1} \
   CONFIG.PSU__SD0__GRP_CD__IO {MIO 24} \
   CONFIG.PSU__SD0__GRP_POW__ENABLE {0} \
   CONFIG.PSU__SD0__GRP_WP__ENABLE {1} \
   CONFIG.PSU__SD0__GRP_WP__IO {MIO 25} \
   CONFIG.PSU__SD0__PERIPHERAL__ENABLE {1} \
   CONFIG.PSU__SD0__PERIPHERAL__IO {MIO 13 .. 16 21 22} \
   CONFIG.PSU__SD0__RESET__ENABLE {0} \
   CONFIG.PSU__SD0__SLOT_TYPE {SD 2.0} \
   CONFIG.PSU__SD1_COHERENCY {0} \
   CONFIG.PSU__SD1_ROUTE_THROUGH_FPD {0} \
   CONFIG.PSU__SD1__GRP_CD__ENABLE {0} \
   CONFIG.PSU__SD1__GRP_POW__ENABLE {0} \
   CONFIG.PSU__SD1__GRP_WP__ENABLE {0} \
   CONFIG.PSU__SD1__PERIPHERAL__ENABLE {0} \
   CONFIG.PSU__SD1__RESET__ENABLE {0} \
   CONFIG.PSU__SPI0_LOOP_SPI1__ENABLE {0} \
   CONFIG.PSU__SPI0__GRP_SS0__ENABLE {1} \
   CONFIG.PSU__SPI0__GRP_SS0__IO {MIO 3} \
   CONFIG.PSU__SPI0__GRP_SS1__ENABLE {1} \
   CONFIG.PSU__SPI0__GRP_SS1__IO {MIO 2} \
   CONFIG.PSU__SPI0__GRP_SS2__ENABLE {1} \
   CONFIG.PSU__SPI0__GRP_SS2__IO {MIO 1} \
   CONFIG.PSU__SPI0__PERIPHERAL__ENABLE {1} \
   CONFIG.PSU__SPI0__PERIPHERAL__IO {MIO 0 .. 5} \
   CONFIG.PSU__SPI1__GRP_SS0__ENABLE {1} \
   CONFIG.PSU__SPI1__GRP_SS0__IO {MIO 9} \
   CONFIG.PSU__SPI1__GRP_SS1__ENABLE {0} \
   CONFIG.PSU__SPI1__GRP_SS2__ENABLE {0} \
   CONFIG.PSU__SPI1__PERIPHERAL__ENABLE {1} \
   CONFIG.PSU__SPI1__PERIPHERAL__IO {MIO 6 .. 11} \
   CONFIG.PSU__SWDT0__CLOCK__ENABLE {0} \
   CONFIG.PSU__SWDT0__PERIPHERAL__ENABLE {0} \
   CONFIG.PSU__SWDT0__PERIPHERAL__IO {NA} \
   CONFIG.PSU__SWDT0__RESET__ENABLE {0} \
   CONFIG.PSU__SWDT1__CLOCK__ENABLE {0} \
   CONFIG.PSU__SWDT1__PERIPHERAL__ENABLE {0} \
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
   CONFIG.PSU__TTC0__PERIPHERAL__ENABLE {0} \
   CONFIG.PSU__TTC0__PERIPHERAL__IO {NA} \
   CONFIG.PSU__TTC0__WAVEOUT__ENABLE {0} \
   CONFIG.PSU__TTC1__CLOCK__ENABLE {0} \
   CONFIG.PSU__TTC1__PERIPHERAL__ENABLE {0} \
   CONFIG.PSU__TTC1__PERIPHERAL__IO {NA} \
   CONFIG.PSU__TTC1__WAVEOUT__ENABLE {0} \
   CONFIG.PSU__TTC2__CLOCK__ENABLE {0} \
   CONFIG.PSU__TTC2__PERIPHERAL__ENABLE {0} \
   CONFIG.PSU__TTC2__PERIPHERAL__IO {NA} \
   CONFIG.PSU__TTC2__WAVEOUT__ENABLE {0} \
   CONFIG.PSU__TTC3__CLOCK__ENABLE {0} \
   CONFIG.PSU__TTC3__PERIPHERAL__ENABLE {0} \
   CONFIG.PSU__TTC3__PERIPHERAL__IO {NA} \
   CONFIG.PSU__TTC3__WAVEOUT__ENABLE {0} \
   CONFIG.PSU__UART0_LOOP_UART1__ENABLE {0} \
   CONFIG.PSU__UART0__MODEM__ENABLE {0} \
   CONFIG.PSU__UART0__PERIPHERAL__ENABLE {0} \
   CONFIG.PSU__UART1__BAUD_RATE {115200} \
   CONFIG.PSU__UART1__MODEM__ENABLE {0} \
   CONFIG.PSU__UART1__PERIPHERAL__ENABLE {1} \
   CONFIG.PSU__UART1__PERIPHERAL__IO {MIO 32 .. 33} \
   CONFIG.PSU__USB0_COHERENCY {0} \
   CONFIG.PSU__USB0__PERIPHERAL__ENABLE {1} \
   CONFIG.PSU__USB0__PERIPHERAL__IO {MIO 52 .. 63} \
   CONFIG.PSU__USB0__REF_CLK_FREQ {100} \
   CONFIG.PSU__USB0__REF_CLK_SEL {Ref Clk1} \
   CONFIG.PSU__USB0__RESET__ENABLE {0} \
   CONFIG.PSU__USB1_COHERENCY {0} \
   CONFIG.PSU__USB1__PERIPHERAL__ENABLE {1} \
   CONFIG.PSU__USB1__PERIPHERAL__IO {MIO 64 .. 75} \
   CONFIG.PSU__USB1__REF_CLK_FREQ {100} \
   CONFIG.PSU__USB1__REF_CLK_SEL {Ref Clk1} \
   CONFIG.PSU__USB1__RESET__ENABLE {0} \
   CONFIG.PSU__USB2_0__EMIO__ENABLE {0} \
   CONFIG.PSU__USB2_1__EMIO__ENABLE {0} \
   CONFIG.PSU__USB3_0__EMIO__ENABLE {0} \
   CONFIG.PSU__USB3_0__PERIPHERAL__ENABLE {1} \
   CONFIG.PSU__USB3_0__PERIPHERAL__IO {GT Lane2} \
   CONFIG.PSU__USB3_1__EMIO__ENABLE {0} \
   CONFIG.PSU__USB3_1__PERIPHERAL__ENABLE {1} \
   CONFIG.PSU__USB3_1__PERIPHERAL__IO {GT Lane3} \
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
   CONFIG.PSU__USE__IRQ1 {1} \
   CONFIG.PSU__USE__M_AXI_GP0 {1} \
   CONFIG.PSU__USE__M_AXI_GP1 {1} \
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
  connect_bd_intf_net -intf_net axi_dma_avg_M_AXI_S2MM [get_bd_intf_pins axi_dma_avg/M_AXI_S2MM] [get_bd_intf_pins axi_smc/S00_AXI]
  connect_bd_intf_net -intf_net axi_dma_buf_M_AXI_S2MM [get_bd_intf_pins axi_dma_buf/M_AXI_S2MM] [get_bd_intf_pins axi_smc/S01_AXI]
  connect_bd_intf_net -intf_net axi_dma_gen_M_AXIS_MM2S [get_bd_intf_pins axi_dma_gen/M_AXIS_MM2S] [get_bd_intf_pins axis_switch_gen/S00_AXIS]
  connect_bd_intf_net -intf_net axi_dma_gen_M_AXI_MM2S [get_bd_intf_pins axi_dma_gen/M_AXI_MM2S] [get_bd_intf_pins axi_smc/S03_AXI]
  connect_bd_intf_net -intf_net axi_dma_readout_M_AXI_S2MM [get_bd_intf_pins axi_dma_mr/M_AXI_S2MM] [get_bd_intf_pins axi_smc/S02_AXI]
  connect_bd_intf_net -intf_net axi_dma_tproc_M_AXIS_MM2S [get_bd_intf_pins axi_dma_tproc/M_AXIS_MM2S] [get_bd_intf_pins axis_tproc64x32_x8_0/s0_axis]
  connect_bd_intf_net -intf_net axi_dma_tproc_M_AXI_MM2S [get_bd_intf_pins axi_dma_tproc/M_AXI_MM2S] [get_bd_intf_pins axi_smc/S04_AXI]
  connect_bd_intf_net -intf_net axi_dma_tproc_M_AXI_S2MM [get_bd_intf_pins axi_dma_tproc/M_AXI_S2MM] [get_bd_intf_pins axi_smc/S05_AXI]
  connect_bd_intf_net -intf_net axi_smc_M00_AXI [get_bd_intf_pins axi_smc/M00_AXI] [get_bd_intf_pins zynq_ultra_ps_e_0/S_AXI_HPC0_FPD]
  connect_bd_intf_net -intf_net axis_avg_buffer_0_m0_axis [get_bd_intf_pins axis_avg_buffer_0/m0_axis] [get_bd_intf_pins axis_switch_avg/S00_AXIS]
  connect_bd_intf_net -intf_net axis_avg_buffer_0_m1_axis [get_bd_intf_pins axis_avg_buffer_0/m1_axis] [get_bd_intf_pins axis_switch_buf/S00_AXIS]
  connect_bd_intf_net -intf_net axis_avg_buffer_0_m2_axis [get_bd_intf_pins axis_avg_buffer_0/m2_axis] [get_bd_intf_pins axis_cc_avg_0/S_AXIS]
  connect_bd_intf_net -intf_net axis_avg_buffer_1_m0_axis [get_bd_intf_pins axis_avg_buffer_1/m0_axis] [get_bd_intf_pins axis_switch_avg/S01_AXIS]
  connect_bd_intf_net -intf_net axis_avg_buffer_1_m1_axis [get_bd_intf_pins axis_avg_buffer_1/m1_axis] [get_bd_intf_pins axis_switch_buf/S01_AXIS]
  connect_bd_intf_net -intf_net axis_avg_buffer_1_m2_axis [get_bd_intf_pins axis_avg_buffer_1/m2_axis] [get_bd_intf_pins axis_cc_avg_1/S_AXIS]
  connect_bd_intf_net -intf_net axis_broadcaster_0_M00_AXIS [get_bd_intf_pins axis_avg_buffer_0/s_axis] [get_bd_intf_pins axis_broadcaster_0/M00_AXIS]
  connect_bd_intf_net -intf_net axis_broadcaster_0_M01_AXIS [get_bd_intf_pins axis_broadcaster_0/M01_AXIS] [get_bd_intf_pins axis_switch_ddr4/S00_AXIS]
  connect_bd_intf_net -intf_net axis_broadcaster_1_M00_AXIS [get_bd_intf_pins axis_avg_buffer_1/s_axis] [get_bd_intf_pins axis_broadcaster_1/M00_AXIS]
  connect_bd_intf_net -intf_net axis_broadcaster_1_M01_AXIS [get_bd_intf_pins axis_broadcaster_1/M01_AXIS] [get_bd_intf_pins axis_switch_ddr4/S01_AXIS]
  connect_bd_intf_net -intf_net axis_buffer_ddr_v1_0_m_axi [get_bd_intf_pins axis_buffer_ddr_v1_0/m_axi] [get_bd_intf_pins smartconnect_0/S01_AXI]
  connect_bd_intf_net -intf_net axis_cc_avg_0_M_AXIS [get_bd_intf_pins axis_cc_avg_0/M_AXIS] [get_bd_intf_pins axis_tproc64x32_x8_0/s1_axis]
  connect_bd_intf_net -intf_net axis_cc_avg_1_M_AXIS [get_bd_intf_pins axis_cc_avg_1/M_AXIS] [get_bd_intf_pins axis_tproc64x32_x8_0/s2_axis]
  connect_bd_intf_net -intf_net axis_cc_sg_0_M_AXIS [get_bd_intf_pins axis_cc_sg_0/M_AXIS] [get_bd_intf_pins axis_signal_gen_v6_0/s1_axis]
  connect_bd_intf_net -intf_net axis_cc_sg_1_M_AXIS [get_bd_intf_pins axis_cc_sg_1/M_AXIS] [get_bd_intf_pins axis_signal_gen_v6_1/s1_axis]
  connect_bd_intf_net -intf_net axis_clock_converter_0_M_AXIS [get_bd_intf_pins axis_buffer_ddr_v1_0/s_axis] [get_bd_intf_pins axis_clock_converter_0/M_AXIS]
  connect_bd_intf_net -intf_net axis_dwidth_converter_0_M_AXIS [get_bd_intf_pins axis_clock_converter_0/S_AXIS] [get_bd_intf_pins axis_dwidth_converter_0/M_AXIS]
  connect_bd_intf_net -intf_net axis_readout_v2_0_m0_axis [get_bd_intf_pins axis_readout_v2_0/m0_axis] [get_bd_intf_pins axis_switch_mr/S00_AXIS]
  connect_bd_intf_net -intf_net axis_readout_v2_0_m1_axis [get_bd_intf_pins axis_broadcaster_0/S_AXIS] [get_bd_intf_pins axis_readout_v2_0/m1_axis]
  connect_bd_intf_net -intf_net axis_readout_v2_1_m0_axis [get_bd_intf_pins axis_readout_v2_1/m0_axis] [get_bd_intf_pins axis_switch_mr/S01_AXIS]
  connect_bd_intf_net -intf_net axis_readout_v2_1_m1_axis [get_bd_intf_pins axis_broadcaster_1/S_AXIS] [get_bd_intf_pins axis_readout_v2_1/m1_axis]
  connect_bd_intf_net -intf_net axis_register_slice_2_M_AXIS [get_bd_intf_pins axis_readout_v2_0/s_axis] [get_bd_intf_pins axis_register_slice_2/M_AXIS]
  connect_bd_intf_net -intf_net axis_register_slice_3_M_AXIS [get_bd_intf_pins axis_readout_v2_1/s_axis] [get_bd_intf_pins axis_register_slice_3/M_AXIS]
  connect_bd_intf_net -intf_net axis_register_slice_4_m_axis [get_bd_intf_pins axis_register_slice_1/m_axis] [get_bd_intf_pins usp_rf_data_converter_0/s20_axis]
  connect_bd_intf_net -intf_net axis_register_slice_6_m_axis [get_bd_intf_pins axis_register_slice_0/m_axis] [get_bd_intf_pins usp_rf_data_converter_0/s00_axis]
  connect_bd_intf_net -intf_net axis_signal_gen_v6_0_m_axis [get_bd_intf_pins axis_register_slice_0/s_axis] [get_bd_intf_pins axis_signal_gen_v6_0/m_axis]
  connect_bd_intf_net -intf_net axis_signal_gen_v6_1_m_axis [get_bd_intf_pins axis_register_slice_1/s_axis] [get_bd_intf_pins axis_signal_gen_v6_1/m_axis]
  connect_bd_intf_net -intf_net axis_switch_0_M00_AXIS [get_bd_intf_pins axis_switch_mr/M00_AXIS] [get_bd_intf_pins mr_buffer_et_0/s00_axis]
  connect_bd_intf_net -intf_net axis_switch_avg_M00_AXIS [get_bd_intf_pins axi_dma_avg/S_AXIS_S2MM] [get_bd_intf_pins axis_switch_avg/M00_AXIS]
  connect_bd_intf_net -intf_net axis_switch_buf_M00_AXIS [get_bd_intf_pins axi_dma_buf/S_AXIS_S2MM] [get_bd_intf_pins axis_switch_buf/M00_AXIS]
  connect_bd_intf_net -intf_net axis_switch_ddr4_M00_AXIS [get_bd_intf_pins axis_dwidth_converter_0/S_AXIS] [get_bd_intf_pins axis_switch_ddr4/M00_AXIS]
  connect_bd_intf_net -intf_net axis_switch_gen_M00_AXIS [get_bd_intf_pins axis_signal_gen_v6_0/s0_axis] [get_bd_intf_pins axis_switch_gen/M00_AXIS]
  connect_bd_intf_net -intf_net axis_switch_gen_M01_AXIS [get_bd_intf_pins axis_signal_gen_v6_1/s0_axis] [get_bd_intf_pins axis_switch_gen/M01_AXIS]
  connect_bd_intf_net -intf_net axis_tproc64x32_x8_0_m0_axis [get_bd_intf_pins axi_dma_tproc/S_AXIS_S2MM] [get_bd_intf_pins axis_tproc64x32_x8_0/m0_axis]
  connect_bd_intf_net -intf_net axis_tproc64x32_x8_0_m1_axis [get_bd_intf_pins axis_cc_sg_0/S_AXIS] [get_bd_intf_pins axis_tproc64x32_x8_0/m1_axis]
  connect_bd_intf_net -intf_net axis_tproc64x32_x8_0_m2_axis [get_bd_intf_pins axis_cc_sg_1/S_AXIS] [get_bd_intf_pins axis_tproc64x32_x8_0/m2_axis]
  connect_bd_intf_net -intf_net axis_tproc64x32_x8_0_m8_axis [get_bd_intf_pins axis_set_reg_0/s_axis] [get_bd_intf_pins axis_tproc64x32_x8_0/m8_axis]
  connect_bd_intf_net -intf_net dac0_clk_1 [get_bd_intf_ports dac0_clk] [get_bd_intf_pins usp_rf_data_converter_0/dac0_clk]
  connect_bd_intf_net -intf_net dac2_clk_1 [get_bd_intf_ports dac2_clk] [get_bd_intf_pins usp_rf_data_converter_0/dac2_clk]
  connect_bd_intf_net -intf_net ddr4_0_C0_DDR4 [get_bd_intf_ports ddr4_pl] [get_bd_intf_pins ddr4_0/C0_DDR4]
  connect_bd_intf_net -intf_net mr_buffer_et_0_m00_axis [get_bd_intf_pins axi_dma_mr/S_AXIS_S2MM] [get_bd_intf_pins mr_buffer_et_0/m00_axis]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M00_AXI [get_bd_intf_pins axi_dma_avg/S_AXI_LITE] [get_bd_intf_pins ps8_0_axi_periph/M00_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M01_AXI [get_bd_intf_pins axi_dma_buf/S_AXI_LITE] [get_bd_intf_pins ps8_0_axi_periph/M01_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M02_AXI [get_bd_intf_pins axi_dma_mr/S_AXI_LITE] [get_bd_intf_pins ps8_0_axi_periph/M02_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M03_AXI [get_bd_intf_pins axis_avg_buffer_1/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M03_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M04_AXI [get_bd_intf_pins axis_readout_v2_0/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M04_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M05_AXI [get_bd_intf_pins axis_readout_v2_1/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M05_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M06_AXI [get_bd_intf_pins axis_switch_avg/S_AXI_CTRL] [get_bd_intf_pins ps8_0_axi_periph/M06_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M07_AXI [get_bd_intf_pins axis_switch_buf/S_AXI_CTRL] [get_bd_intf_pins ps8_0_axi_periph/M07_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M08_AXI [get_bd_intf_pins axis_switch_mr/S_AXI_CTRL] [get_bd_intf_pins ps8_0_axi_periph/M08_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M09_AXI [get_bd_intf_pins axis_tproc64x32_x8_0/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M09_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M10_AXI [get_bd_intf_pins mr_buffer_et_0/s00_axi] [get_bd_intf_pins ps8_0_axi_periph/M10_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M11_AXI [get_bd_intf_pins ps8_0_axi_periph/M11_AXI] [get_bd_intf_pins usp_rf_data_converter_0/s_axi]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M12_AXI [get_bd_intf_pins axis_avg_buffer_0/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M12_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M13_AXI [get_bd_intf_pins axis_signal_gen_v6_0/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M13_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M14_AXI [get_bd_intf_pins axis_signal_gen_v6_1/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M14_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M15_AXI [get_bd_intf_pins axi_dma_gen/S_AXI_LITE] [get_bd_intf_pins ps8_0_axi_periph/M15_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M16_AXI [get_bd_intf_pins axis_switch_gen/S_AXI_CTRL] [get_bd_intf_pins ps8_0_axi_periph/M16_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M17_AXI [get_bd_intf_pins axi_dma_tproc/S_AXI_LITE] [get_bd_intf_pins ps8_0_axi_periph/M17_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M18_AXI [get_bd_intf_pins axi_bram_ctrl_0/S_AXI] [get_bd_intf_pins ps8_0_axi_periph/M18_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M19_AXI [get_bd_intf_pins axi_intc_0/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M19_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M20_AXI [get_bd_intf_pins axis_buffer_ddr_v1_0/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M20_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M21_AXI [get_bd_intf_pins axis_switch_ddr4/S_AXI_CTRL] [get_bd_intf_pins ps8_0_axi_periph/M21_AXI]
  connect_bd_intf_net -intf_net smartconnect_0_M00_AXI [get_bd_intf_pins ddr4_0/C0_DDR4_S_AXI] [get_bd_intf_pins smartconnect_0/M00_AXI]
  connect_bd_intf_net -intf_net sys_clk_ddr4_1 [get_bd_intf_ports sys_clk_ddr4] [get_bd_intf_pins ddr4_0/C0_SYS_CLK]
  connect_bd_intf_net -intf_net sysref_in_1 [get_bd_intf_ports sysref_in] [get_bd_intf_pins usp_rf_data_converter_0/sysref_in]
  connect_bd_intf_net -intf_net usp_rf_data_converter_0_m00_axis [get_bd_intf_pins axis_register_slice_2/S_AXIS] [get_bd_intf_pins usp_rf_data_converter_0/m00_axis]
  connect_bd_intf_net -intf_net usp_rf_data_converter_0_m02_axis [get_bd_intf_pins axis_register_slice_3/S_AXIS] [get_bd_intf_pins usp_rf_data_converter_0/m02_axis]
  connect_bd_intf_net -intf_net usp_rf_data_converter_0_vout00 [get_bd_intf_ports vout00] [get_bd_intf_pins usp_rf_data_converter_0/vout00]
  connect_bd_intf_net -intf_net usp_rf_data_converter_0_vout20 [get_bd_intf_ports vout20] [get_bd_intf_pins usp_rf_data_converter_0/vout20]
  connect_bd_intf_net -intf_net vin0_01_1 [get_bd_intf_ports vin0_01] [get_bd_intf_pins usp_rf_data_converter_0/vin0_01]
  connect_bd_intf_net -intf_net vin0_23_1 [get_bd_intf_ports vin0_23] [get_bd_intf_pins usp_rf_data_converter_0/vin0_23]
  connect_bd_intf_net -intf_net zynq_ultra_ps_e_0_M_AXI_HPM0_FPD [get_bd_intf_pins ps8_0_axi_periph/S00_AXI] [get_bd_intf_pins zynq_ultra_ps_e_0/M_AXI_HPM0_FPD]
  connect_bd_intf_net -intf_net zynq_ultra_ps_e_0_M_AXI_HPM1_FPD [get_bd_intf_pins smartconnect_0/S00_AXI] [get_bd_intf_pins zynq_ultra_ps_e_0/M_AXI_HPM1_FPD]

  # Create port connections
  connect_bd_net -net PMOD1_0_1 [get_bd_ports PMOD1_0] [get_bd_pins axis_tproc64x32_x8_0/start]
  connect_bd_net -net axi_bram_ctrl_0_bram_doutb [get_bd_pins axi_bram_ctrl_0_bram/doutb] [get_bd_pins axis_tproc64x32_x8_0/pmem_do]
  connect_bd_net -net axi_dma_avg_s2mm_introut [get_bd_pins axi_dma_avg/s2mm_introut] [get_bd_pins xlconcat_0/In3]
  connect_bd_net -net axi_dma_buf_s2mm_introut [get_bd_pins axi_dma_buf/s2mm_introut] [get_bd_pins xlconcat_0/In4]
  connect_bd_net -net axi_dma_gen_mm2s_introut [get_bd_pins axi_dma_gen/mm2s_introut] [get_bd_pins xlconcat_0/In0]
  connect_bd_net -net axi_dma_readout_s2mm_introut [get_bd_pins axi_dma_mr/s2mm_introut] [get_bd_pins xlconcat_0/In5]
  connect_bd_net -net axi_dma_tproc_mm2s_introut [get_bd_pins axi_dma_tproc/mm2s_introut] [get_bd_pins xlconcat_0/In1]
  connect_bd_net -net axi_dma_tproc_s2mm_introut [get_bd_pins axi_dma_tproc/s2mm_introut] [get_bd_pins xlconcat_0/In2]
  connect_bd_net -net axi_intc_0_irq [get_bd_pins axi_intc_0/irq] [get_bd_pins zynq_ultra_ps_e_0/pl_ps_irq0]
  connect_bd_net -net axis_set_reg_0_dout [get_bd_pins axis_set_reg_0/dout] [get_bd_pins vect2bits_16_0/din]
  connect_bd_net -net axis_tproc64x32_x8_0_pmem_addr [get_bd_pins axi_bram_ctrl_0_bram/addrb] [get_bd_pins axis_tproc64x32_x8_0/pmem_addr]
  connect_bd_net -net clk_adc0_x2_clk_out1 [get_bd_pins axis_avg_buffer_0/s_axis_aclk] [get_bd_pins axis_avg_buffer_1/s_axis_aclk] [get_bd_pins axis_broadcaster_0/aclk] [get_bd_pins axis_broadcaster_1/aclk] [get_bd_pins axis_clock_converter_0/s_axis_aclk] [get_bd_pins axis_dwidth_converter_0/aclk] [get_bd_pins axis_readout_v2_0/aclk] [get_bd_pins axis_readout_v2_1/aclk] [get_bd_pins axis_register_slice_2/aclk] [get_bd_pins axis_register_slice_3/aclk] [get_bd_pins axis_switch_ddr4/aclk] [get_bd_pins axis_switch_mr/aclk] [get_bd_pins clk_adc0_x2/clk_out1] [get_bd_pins mr_buffer_et_0/s00_axis_aclk] [get_bd_pins rst_adc0_x2/slowest_sync_clk] [get_bd_pins usp_rf_data_converter_0/m0_axis_aclk]
  connect_bd_net -net clk_adc0_x2_locked [get_bd_pins clk_adc0_x2/locked] [get_bd_pins rst_adc0_x2/dcm_locked]
  connect_bd_net -net clk_tproc_clk_out1 [get_bd_pins axi_bram_ctrl_0_bram/clkb] [get_bd_pins axis_cc_avg_0/m_axis_aclk] [get_bd_pins axis_cc_avg_1/m_axis_aclk] [get_bd_pins axis_cc_sg_0/s_axis_aclk] [get_bd_pins axis_cc_sg_1/s_axis_aclk] [get_bd_pins axis_set_reg_0/s_axis_aclk] [get_bd_pins axis_tproc64x32_x8_0/aclk] [get_bd_pins clk_tproc/clk_out1] [get_bd_pins rst_tproc/slowest_sync_clk]
  connect_bd_net -net clk_tproc_locked [get_bd_pins clk_tproc/locked] [get_bd_pins rst_tproc/dcm_locked]
  connect_bd_net -net ddr4_0_c0_ddr4_ui_clk [get_bd_pins axis_buffer_ddr_v1_0/aclk] [get_bd_pins axis_clock_converter_0/m_axis_aclk] [get_bd_pins ddr4_0/c0_ddr4_ui_clk] [get_bd_pins rst_ddr4/slowest_sync_clk] [get_bd_pins smartconnect_0/aclk] [get_bd_pins zynq_ultra_ps_e_0/maxihpm1_fpd_aclk]
  connect_bd_net -net ddr4_0_c0_ddr4_ui_clk_sync_rst [get_bd_pins ddr4_0/c0_ddr4_ui_clk_sync_rst] [get_bd_pins rst_ddr4/ext_reset_in]
  connect_bd_net -net proc_sys_reset_0_peripheral_aresetn [get_bd_pins axis_buffer_ddr_v1_0/aresetn] [get_bd_pins axis_clock_converter_0/m_axis_aresetn] [get_bd_pins ddr4_0/c0_ddr4_aresetn] [get_bd_pins rst_ddr4/peripheral_aresetn] [get_bd_pins smartconnect_0/aresetn]
  connect_bd_net -net rst_100_bus_struct_reset [get_bd_pins ddr4_0/sys_rst] [get_bd_pins rst_100/bus_struct_reset]
  connect_bd_net -net rst_adc0_peripheral_aresetn [get_bd_pins clk_adc0_x2/resetn] [get_bd_pins rst_adc0/peripheral_aresetn]
  connect_bd_net -net rst_adc0_x2_peripheral_aresetn [get_bd_pins axis_avg_buffer_0/s_axis_aresetn] [get_bd_pins axis_avg_buffer_1/s_axis_aresetn] [get_bd_pins axis_broadcaster_0/aresetn] [get_bd_pins axis_broadcaster_1/aresetn] [get_bd_pins axis_clock_converter_0/s_axis_aresetn] [get_bd_pins axis_dwidth_converter_0/aresetn] [get_bd_pins axis_readout_v2_0/aresetn] [get_bd_pins axis_readout_v2_1/aresetn] [get_bd_pins axis_register_slice_2/aresetn] [get_bd_pins axis_register_slice_3/aresetn] [get_bd_pins axis_switch_ddr4/aresetn] [get_bd_pins axis_switch_mr/aresetn] [get_bd_pins mr_buffer_et_0/s00_axis_aresetn] [get_bd_pins rst_adc0_x2/peripheral_aresetn] [get_bd_pins usp_rf_data_converter_0/m0_axis_aresetn]
  connect_bd_net -net rst_dac0_peripheral_aresetn [get_bd_pins axis_cc_sg_0/m_axis_aresetn] [get_bd_pins axis_register_slice_0/aresetn] [get_bd_pins axis_signal_gen_v6_0/aresetn] [get_bd_pins clk_tproc/resetn] [get_bd_pins rst_dac0/peripheral_aresetn] [get_bd_pins usp_rf_data_converter_0/s0_axis_aresetn]
  connect_bd_net -net rst_dac1_peripheral_aresetn [get_bd_pins axis_cc_sg_1/m_axis_aresetn] [get_bd_pins axis_register_slice_1/aresetn] [get_bd_pins axis_signal_gen_v6_1/aresetn] [get_bd_pins rst_dac1/peripheral_aresetn] [get_bd_pins usp_rf_data_converter_0/s2_axis_aresetn]
  connect_bd_net -net rst_ps8_0_99M_peripheral_aresetn [get_bd_pins axi_bram_ctrl_0/s_axi_aresetn] [get_bd_pins axi_dma_avg/axi_resetn] [get_bd_pins axi_dma_buf/axi_resetn] [get_bd_pins axi_dma_gen/axi_resetn] [get_bd_pins axi_dma_mr/axi_resetn] [get_bd_pins axi_dma_tproc/axi_resetn] [get_bd_pins axi_intc_0/s_axi_aresetn] [get_bd_pins axi_smc/aresetn] [get_bd_pins axis_avg_buffer_0/m_axis_aresetn] [get_bd_pins axis_avg_buffer_0/s_axi_aresetn] [get_bd_pins axis_avg_buffer_1/m_axis_aresetn] [get_bd_pins axis_avg_buffer_1/s_axi_aresetn] [get_bd_pins axis_buffer_ddr_v1_0/s_axi_aresetn] [get_bd_pins axis_cc_avg_0/s_axis_aresetn] [get_bd_pins axis_cc_avg_1/s_axis_aresetn] [get_bd_pins axis_readout_v2_0/s_axi_aresetn] [get_bd_pins axis_readout_v2_1/s_axi_aresetn] [get_bd_pins axis_signal_gen_v6_0/s0_axis_aresetn] [get_bd_pins axis_signal_gen_v6_0/s_axi_aresetn] [get_bd_pins axis_signal_gen_v6_1/s0_axis_aresetn] [get_bd_pins axis_signal_gen_v6_1/s_axi_aresetn] [get_bd_pins axis_switch_avg/aresetn] [get_bd_pins axis_switch_avg/s_axi_ctrl_aresetn] [get_bd_pins axis_switch_buf/aresetn] [get_bd_pins axis_switch_buf/s_axi_ctrl_aresetn] [get_bd_pins axis_switch_ddr4/s_axi_ctrl_aresetn] [get_bd_pins axis_switch_gen/aresetn] [get_bd_pins axis_switch_gen/s_axi_ctrl_aresetn] [get_bd_pins axis_switch_mr/s_axi_ctrl_aresetn] [get_bd_pins axis_tproc64x32_x8_0/m0_axis_aresetn] [get_bd_pins axis_tproc64x32_x8_0/s0_axis_aresetn] [get_bd_pins axis_tproc64x32_x8_0/s_axi_aresetn] [get_bd_pins mr_buffer_et_0/m00_axis_aresetn] [get_bd_pins mr_buffer_et_0/s00_axi_aresetn] [get_bd_pins ps8_0_axi_periph/ARESETN] [get_bd_pins ps8_0_axi_periph/M00_ARESETN] [get_bd_pins ps8_0_axi_periph/M01_ARESETN] [get_bd_pins ps8_0_axi_periph/M02_ARESETN] [get_bd_pins ps8_0_axi_periph/M03_ARESETN] [get_bd_pins ps8_0_axi_periph/M04_ARESETN] [get_bd_pins ps8_0_axi_periph/M05_ARESETN] [get_bd_pins ps8_0_axi_periph/M06_ARESETN] [get_bd_pins ps8_0_axi_periph/M07_ARESETN] [get_bd_pins ps8_0_axi_periph/M08_ARESETN] [get_bd_pins ps8_0_axi_periph/M09_ARESETN] [get_bd_pins ps8_0_axi_periph/M10_ARESETN] [get_bd_pins ps8_0_axi_periph/M11_ARESETN] [get_bd_pins ps8_0_axi_periph/M12_ARESETN] [get_bd_pins ps8_0_axi_periph/M13_ARESETN] [get_bd_pins ps8_0_axi_periph/M14_ARESETN] [get_bd_pins ps8_0_axi_periph/M15_ARESETN] [get_bd_pins ps8_0_axi_periph/M16_ARESETN] [get_bd_pins ps8_0_axi_periph/M17_ARESETN] [get_bd_pins ps8_0_axi_periph/M18_ARESETN] [get_bd_pins ps8_0_axi_periph/M19_ARESETN] [get_bd_pins ps8_0_axi_periph/M20_ARESETN] [get_bd_pins ps8_0_axi_periph/M21_ARESETN] [get_bd_pins ps8_0_axi_periph/S00_ARESETN] [get_bd_pins rst_100/peripheral_aresetn] [get_bd_pins usp_rf_data_converter_0/s_axi_aresetn]
  connect_bd_net -net rst_tproc_peripheral_aresetn [get_bd_pins axis_cc_avg_0/m_axis_aresetn] [get_bd_pins axis_cc_avg_1/m_axis_aresetn] [get_bd_pins axis_cc_sg_0/s_axis_aresetn] [get_bd_pins axis_cc_sg_1/s_axis_aresetn] [get_bd_pins axis_set_reg_0/s_axis_aresetn] [get_bd_pins axis_tproc64x32_x8_0/aresetn] [get_bd_pins rst_tproc/peripheral_aresetn]
  connect_bd_net -net usp_rf_data_converter_0_clk_adc0 [get_bd_pins clk_adc0_x2/clk_in1] [get_bd_pins rst_adc0/slowest_sync_clk] [get_bd_pins usp_rf_data_converter_0/clk_adc0]
  connect_bd_net -net usp_rf_data_converter_0_clk_dac0 [get_bd_pins axis_cc_sg_0/m_axis_aclk] [get_bd_pins axis_register_slice_0/aclk] [get_bd_pins axis_signal_gen_v6_0/aclk] [get_bd_pins clk_tproc/clk_in1] [get_bd_pins rst_dac0/slowest_sync_clk] [get_bd_pins usp_rf_data_converter_0/clk_dac0] [get_bd_pins usp_rf_data_converter_0/s0_axis_aclk]
  connect_bd_net -net usp_rf_data_converter_0_clk_dac2 [get_bd_pins axis_cc_sg_1/m_axis_aclk] [get_bd_pins axis_register_slice_1/aclk] [get_bd_pins axis_signal_gen_v6_1/aclk] [get_bd_pins rst_dac1/slowest_sync_clk] [get_bd_pins usp_rf_data_converter_0/clk_dac2] [get_bd_pins usp_rf_data_converter_0/s2_axis_aclk]
  connect_bd_net -net vect2bits_16_0_dout0 [get_bd_ports PMOD0_0] [get_bd_pins vect2bits_16_0/dout0]
  connect_bd_net -net vect2bits_16_0_dout1 [get_bd_ports PMOD0_1] [get_bd_pins vect2bits_16_0/dout1]
  connect_bd_net -net vect2bits_16_0_dout2 [get_bd_ports PMOD0_2] [get_bd_pins vect2bits_16_0/dout2]
  connect_bd_net -net vect2bits_16_0_dout3 [get_bd_ports PMOD0_3] [get_bd_pins vect2bits_16_0/dout3]
  connect_bd_net -net vect2bits_16_0_dout4 [get_bd_ports PMOD0_4] [get_bd_pins vect2bits_16_0/dout4]
  connect_bd_net -net vect2bits_16_0_dout5 [get_bd_ports PMOD0_5] [get_bd_pins vect2bits_16_0/dout5]
  connect_bd_net -net vect2bits_16_0_dout6 [get_bd_ports PMOD0_6] [get_bd_pins vect2bits_16_0/dout6]
  connect_bd_net -net vect2bits_16_0_dout7 [get_bd_ports PMOD0_7] [get_bd_pins vect2bits_16_0/dout7]
  connect_bd_net -net vect2bits_16_0_dout12 [get_bd_pins mr_buffer_et_0/trigger] [get_bd_pins vect2bits_16_0/dout12]
  connect_bd_net -net vect2bits_16_0_dout13 [get_bd_pins axis_buffer_ddr_v1_0/trigger] [get_bd_pins vect2bits_16_0/dout13]
  connect_bd_net -net vect2bits_16_0_dout14 [get_bd_pins axis_avg_buffer_0/trigger] [get_bd_pins vect2bits_16_0/dout14]
  connect_bd_net -net vect2bits_16_0_dout15 [get_bd_pins axis_avg_buffer_1/trigger] [get_bd_pins vect2bits_16_0/dout15]
  connect_bd_net -net xlconcat_0_dout [get_bd_pins axi_intc_0/intr] [get_bd_pins xlconcat_0/dout]
  connect_bd_net -net xlconstant_0_dout [get_bd_pins axi_bram_ctrl_0_bram/dinb] [get_bd_pins xlconstant_0/dout]
  connect_bd_net -net xlconstant_1_dout [get_bd_pins axi_bram_ctrl_0_bram/enb] [get_bd_pins xlconstant_1/dout]
  connect_bd_net -net xlconstant_2_dout [get_bd_pins axi_bram_ctrl_0_bram/rstb] [get_bd_pins xlconstant_2/dout]
  connect_bd_net -net xlconstant_3_dout [get_bd_pins axi_bram_ctrl_0_bram/web] [get_bd_pins xlconstant_3/dout]
  connect_bd_net -net zynq_ultra_ps_e_0_pl_clk0 [get_bd_pins axi_bram_ctrl_0/s_axi_aclk] [get_bd_pins axi_dma_avg/m_axi_s2mm_aclk] [get_bd_pins axi_dma_avg/s_axi_lite_aclk] [get_bd_pins axi_dma_buf/m_axi_s2mm_aclk] [get_bd_pins axi_dma_buf/s_axi_lite_aclk] [get_bd_pins axi_dma_gen/m_axi_mm2s_aclk] [get_bd_pins axi_dma_gen/s_axi_lite_aclk] [get_bd_pins axi_dma_mr/m_axi_s2mm_aclk] [get_bd_pins axi_dma_mr/s_axi_lite_aclk] [get_bd_pins axi_dma_tproc/m_axi_mm2s_aclk] [get_bd_pins axi_dma_tproc/m_axi_s2mm_aclk] [get_bd_pins axi_dma_tproc/s_axi_lite_aclk] [get_bd_pins axi_intc_0/s_axi_aclk] [get_bd_pins axi_smc/aclk] [get_bd_pins axis_avg_buffer_0/m_axis_aclk] [get_bd_pins axis_avg_buffer_0/s_axi_aclk] [get_bd_pins axis_avg_buffer_1/m_axis_aclk] [get_bd_pins axis_avg_buffer_1/s_axi_aclk] [get_bd_pins axis_buffer_ddr_v1_0/s_axi_aclk] [get_bd_pins axis_cc_avg_0/s_axis_aclk] [get_bd_pins axis_cc_avg_1/s_axis_aclk] [get_bd_pins axis_readout_v2_0/s_axi_aclk] [get_bd_pins axis_readout_v2_1/s_axi_aclk] [get_bd_pins axis_signal_gen_v6_0/s0_axis_aclk] [get_bd_pins axis_signal_gen_v6_0/s_axi_aclk] [get_bd_pins axis_signal_gen_v6_1/s0_axis_aclk] [get_bd_pins axis_signal_gen_v6_1/s_axi_aclk] [get_bd_pins axis_switch_avg/aclk] [get_bd_pins axis_switch_avg/s_axi_ctrl_aclk] [get_bd_pins axis_switch_buf/aclk] [get_bd_pins axis_switch_buf/s_axi_ctrl_aclk] [get_bd_pins axis_switch_ddr4/s_axi_ctrl_aclk] [get_bd_pins axis_switch_gen/aclk] [get_bd_pins axis_switch_gen/s_axi_ctrl_aclk] [get_bd_pins axis_switch_mr/s_axi_ctrl_aclk] [get_bd_pins axis_tproc64x32_x8_0/m0_axis_aclk] [get_bd_pins axis_tproc64x32_x8_0/s0_axis_aclk] [get_bd_pins axis_tproc64x32_x8_0/s_axi_aclk] [get_bd_pins mr_buffer_et_0/m00_axis_aclk] [get_bd_pins mr_buffer_et_0/s00_axi_aclk] [get_bd_pins ps8_0_axi_periph/ACLK] [get_bd_pins ps8_0_axi_periph/M00_ACLK] [get_bd_pins ps8_0_axi_periph/M01_ACLK] [get_bd_pins ps8_0_axi_periph/M02_ACLK] [get_bd_pins ps8_0_axi_periph/M03_ACLK] [get_bd_pins ps8_0_axi_periph/M04_ACLK] [get_bd_pins ps8_0_axi_periph/M05_ACLK] [get_bd_pins ps8_0_axi_periph/M06_ACLK] [get_bd_pins ps8_0_axi_periph/M07_ACLK] [get_bd_pins ps8_0_axi_periph/M08_ACLK] [get_bd_pins ps8_0_axi_periph/M09_ACLK] [get_bd_pins ps8_0_axi_periph/M10_ACLK] [get_bd_pins ps8_0_axi_periph/M11_ACLK] [get_bd_pins ps8_0_axi_periph/M12_ACLK] [get_bd_pins ps8_0_axi_periph/M13_ACLK] [get_bd_pins ps8_0_axi_periph/M14_ACLK] [get_bd_pins ps8_0_axi_periph/M15_ACLK] [get_bd_pins ps8_0_axi_periph/M16_ACLK] [get_bd_pins ps8_0_axi_periph/M17_ACLK] [get_bd_pins ps8_0_axi_periph/M18_ACLK] [get_bd_pins ps8_0_axi_periph/M19_ACLK] [get_bd_pins ps8_0_axi_periph/M20_ACLK] [get_bd_pins ps8_0_axi_periph/M21_ACLK] [get_bd_pins ps8_0_axi_periph/S00_ACLK] [get_bd_pins rst_100/slowest_sync_clk] [get_bd_pins usp_rf_data_converter_0/s_axi_aclk] [get_bd_pins zynq_ultra_ps_e_0/maxihpm0_fpd_aclk] [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] [get_bd_pins zynq_ultra_ps_e_0/saxihpc0_fpd_aclk]
  connect_bd_net -net zynq_ultra_ps_e_0_pl_resetn0 [get_bd_pins rst_100/ext_reset_in] [get_bd_pins rst_adc0/ext_reset_in] [get_bd_pins rst_adc0_x2/ext_reset_in] [get_bd_pins rst_dac0/ext_reset_in] [get_bd_pins rst_dac1/ext_reset_in] [get_bd_pins rst_tproc/ext_reset_in] [get_bd_pins zynq_ultra_ps_e_0/pl_resetn0]

  # Create address segments
  assign_bd_address -offset 0x00000000 -range 0x80000000 -target_address_space [get_bd_addr_spaces axi_dma_avg/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_DDR_LOW] -force
  assign_bd_address -offset 0x00000000 -range 0x80000000 -target_address_space [get_bd_addr_spaces axi_dma_buf/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_DDR_LOW] -force
  assign_bd_address -offset 0x00000000 -range 0x80000000 -target_address_space [get_bd_addr_spaces axi_dma_gen/Data_MM2S] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_DDR_LOW] -force
  assign_bd_address -offset 0x00000000 -range 0x80000000 -target_address_space [get_bd_addr_spaces axi_dma_mr/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_DDR_LOW] -force
  assign_bd_address -offset 0x00000000 -range 0x80000000 -target_address_space [get_bd_addr_spaces axi_dma_tproc/Data_MM2S] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_DDR_LOW] -force
  assign_bd_address -offset 0x00000000 -range 0x80000000 -target_address_space [get_bd_addr_spaces axi_dma_tproc/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_DDR_LOW] -force
  assign_bd_address -offset 0x00000000 -range 0x000100000000 -target_address_space [get_bd_addr_spaces axis_buffer_ddr_v1_0/m_axi] [get_bd_addr_segs ddr4_0/C0_DDR4_MEMORY_MAP/C0_DDR4_ADDRESS_BLOCK] -force
  assign_bd_address -offset 0xA0140000 -range 0x00002000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axi_bram_ctrl_0/S_AXI/Mem0] -force
  assign_bd_address -offset 0xA0200000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axi_dma_avg/S_AXI_LITE/Reg] -force
  assign_bd_address -offset 0xA0201000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axi_dma_buf/S_AXI_LITE/Reg] -force
  assign_bd_address -offset 0xA0202000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axi_dma_gen/S_AXI_LITE/Reg] -force
  assign_bd_address -offset 0xA0203000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axi_dma_mr/S_AXI_LITE/Reg] -force
  assign_bd_address -offset 0xA0204000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axi_dma_tproc/S_AXI_LITE/Reg] -force
  assign_bd_address -offset 0xA0205000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axi_intc_0/S_AXI/Reg] -force
  assign_bd_address -offset 0xA0206000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_avg_buffer_0/s_axi/reg0] -force
  assign_bd_address -offset 0xA0207000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_avg_buffer_1/s_axi/reg0] -force
  assign_bd_address -offset 0xA0208000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_buffer_ddr_v1_0/s_axi/reg0] -force
  assign_bd_address -offset 0xA0209000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_readout_v2_0/s_axi/reg0] -force
  assign_bd_address -offset 0xA020A000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_readout_v2_1/s_axi/reg0] -force
  assign_bd_address -offset 0xA020B000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_signal_gen_v6_0/s_axi/reg0] -force
  assign_bd_address -offset 0xA020C000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_signal_gen_v6_1/s_axi/reg0] -force
  assign_bd_address -offset 0xA020D000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_switch_avg/S_AXI_CTRL/Reg] -force
  assign_bd_address -offset 0xA020E000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_switch_buf/S_AXI_CTRL/Reg] -force
  assign_bd_address -offset 0xA020F000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_switch_ddr4/S_AXI_CTRL/Reg] -force
  assign_bd_address -offset 0xA0210000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_switch_gen/S_AXI_CTRL/Reg] -force
  assign_bd_address -offset 0xA0211000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_switch_mr/S_AXI_CTRL/Reg] -force
  assign_bd_address -offset 0x000400000000 -range 0x000100000000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_tproc64x32_x8_0/s_axi/reg0] -force
  assign_bd_address -offset 0x004800000000 -range 0x000100000000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs ddr4_0/C0_DDR4_MEMORY_MAP/C0_DDR4_ADDRESS_BLOCK] -force
  assign_bd_address -offset 0xA0212000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs mr_buffer_et_0/s00_axi/reg0] -force
  assign_bd_address -offset 0xA0240000 -range 0x00040000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs usp_rf_data_converter_0/s_axi/Reg] -force

  # Exclude Address Segments
  exclude_bd_addr_seg -offset 0x000800000000 -range 0x000100000000 -target_address_space [get_bd_addr_spaces axi_dma_avg/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_DDR_HIGH]
  exclude_bd_addr_seg -offset 0xFF000000 -range 0x01000000 -target_address_space [get_bd_addr_spaces axi_dma_avg/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_LPS_OCM]
  exclude_bd_addr_seg -offset 0x000800000000 -range 0x000100000000 -target_address_space [get_bd_addr_spaces axi_dma_buf/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_DDR_HIGH]
  exclude_bd_addr_seg -offset 0xFF000000 -range 0x01000000 -target_address_space [get_bd_addr_spaces axi_dma_buf/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_LPS_OCM]
  exclude_bd_addr_seg -offset 0x000800000000 -range 0x000100000000 -target_address_space [get_bd_addr_spaces axi_dma_gen/Data_MM2S] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_DDR_HIGH]
  exclude_bd_addr_seg -offset 0xFF000000 -range 0x01000000 -target_address_space [get_bd_addr_spaces axi_dma_gen/Data_MM2S] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_LPS_OCM]
  exclude_bd_addr_seg -offset 0x000800000000 -range 0x000100000000 -target_address_space [get_bd_addr_spaces axi_dma_mr/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_DDR_HIGH]
  exclude_bd_addr_seg -offset 0xFF000000 -range 0x01000000 -target_address_space [get_bd_addr_spaces axi_dma_mr/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_LPS_OCM]
  exclude_bd_addr_seg -offset 0x000800000000 -range 0x000100000000 -target_address_space [get_bd_addr_spaces axi_dma_tproc/Data_MM2S] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_DDR_HIGH]
  exclude_bd_addr_seg -offset 0xFF000000 -range 0x01000000 -target_address_space [get_bd_addr_spaces axi_dma_tproc/Data_MM2S] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_LPS_OCM]
  exclude_bd_addr_seg -offset 0x000800000000 -range 0x000100000000 -target_address_space [get_bd_addr_spaces axi_dma_tproc/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_DDR_HIGH]
  exclude_bd_addr_seg -offset 0xFF000000 -range 0x01000000 -target_address_space [get_bd_addr_spaces axi_dma_tproc/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_LPS_OCM]

  # Perform GUI Layout
  regenerate_bd_layout -layout_string {
   "ActiveEmotionalView":"Default View",
   "Default View_ScaleFactor":"0.478209",
   "Default View_TopLeft":"-609,-100",
   "ExpandedHierarchyInLayout":"",
   "guistr":"# # String gsaved with Nlview 7.0r4  2019-12-20 bk=1.5203 VDI=41 GEI=36 GUI=JA:10.0 TLS
#  -string -flagsOSRD
preplace port adc0_clk -pg 1 -lvl 0 -x -50 -y 2600 -defaultsOSRD
preplace port dac0_clk -pg 1 -lvl 0 -x -50 -y 2620 -defaultsOSRD
preplace port dac2_clk -pg 1 -lvl 0 -x -50 -y 2640 -defaultsOSRD
preplace port ddr4_pl -pg 1 -lvl 12 -x 5320 -y 2450 -defaultsOSRD
preplace port sys_clk_ddr4 -pg 1 -lvl 12 -x 5320 -y 2380 -defaultsOSRD -right
preplace port sysref_in -pg 1 -lvl 0 -x -50 -y 2700 -defaultsOSRD
preplace port vin0_01 -pg 1 -lvl 0 -x -50 -y 2660 -defaultsOSRD
preplace port vin0_23 -pg 1 -lvl 0 -x -50 -y 2680 -defaultsOSRD
preplace port vout00 -pg 1 -lvl 12 -x 5320 -y 2670 -defaultsOSRD
preplace port vout20 -pg 1 -lvl 12 -x 5320 -y 2690 -defaultsOSRD
preplace port port-id_PMOD0_0 -pg 1 -lvl 12 -x 5320 -y 2890 -defaultsOSRD
preplace port port-id_PMOD0_1 -pg 1 -lvl 12 -x 5320 -y 2910 -defaultsOSRD
preplace port port-id_PMOD0_2 -pg 1 -lvl 12 -x 5320 -y 2930 -defaultsOSRD
preplace port port-id_PMOD0_3 -pg 1 -lvl 12 -x 5320 -y 2950 -defaultsOSRD
preplace port port-id_PMOD0_4 -pg 1 -lvl 12 -x 5320 -y 2970 -defaultsOSRD
preplace port port-id_PMOD0_5 -pg 1 -lvl 12 -x 5320 -y 2990 -defaultsOSRD
preplace port port-id_PMOD0_6 -pg 1 -lvl 12 -x 5320 -y 3010 -defaultsOSRD
preplace port port-id_PMOD0_7 -pg 1 -lvl 12 -x 5320 -y 3030 -defaultsOSRD
preplace port port-id_PMOD1_0 -pg 1 -lvl 0 -x -50 -y 1880 -defaultsOSRD
preplace inst axi_bram_ctrl_0 -pg 1 -lvl 1 -x 140 -y 2010 -defaultsOSRD
preplace inst axi_bram_ctrl_0_bram -pg 1 -lvl 2 -x 570 -y 2400 -defaultsOSRD
preplace inst axi_dma_avg -pg 1 -lvl 10 -x 4640 -y 880 -defaultsOSRD
preplace inst axi_dma_buf -pg 1 -lvl 10 -x 4640 -y 1100 -defaultsOSRD -resize 320 156
preplace inst axi_dma_gen -pg 1 -lvl 2 -x 570 -y 1290 -defaultsOSRD
preplace inst axi_dma_mr -pg 1 -lvl 10 -x 4640 -y 1970 -defaultsOSRD -resize 320 156
preplace inst axi_dma_tproc -pg 1 -lvl 2 -x 570 -y 1520 -defaultsOSRD
preplace inst axi_intc_0 -pg 1 -lvl 5 -x 1720 -y 130 -defaultsOSRD
preplace inst axi_smc -pg 1 -lvl 5 -x 1720 -y 1040 -defaultsOSRD
preplace inst axis_avg_buffer_0 -pg 1 -lvl 8 -x 3700 -y 1300 -defaultsOSRD
preplace inst axis_avg_buffer_1 -pg 1 -lvl 8 -x 3700 -y 1560 -defaultsOSRD -resize 220 236
preplace inst axis_broadcaster_0 -pg 1 -lvl 7 -x 3050 -y 1850 -defaultsOSRD
preplace inst axis_broadcaster_1 -pg 1 -lvl 7 -x 3050 -y 2190 -defaultsOSRD
preplace inst axis_buffer_ddr_v1_0 -pg 1 -lvl 9 -x 4220 -y 2470 -defaultsOSRD
preplace inst axis_cc_avg_0 -pg 1 -lvl 9 -x 4220 -y 1360 -defaultsOSRD
preplace inst axis_cc_avg_1 -pg 1 -lvl 9 -x 4220 -y 1620 -defaultsOSRD -resize 220 156
preplace inst axis_cc_sg_0 -pg 1 -lvl 3 -x 1000 -y 2040 -defaultsOSRD
preplace inst axis_cc_sg_1 -pg 1 -lvl 3 -x 1000 -y 2330 -defaultsOSRD -resize 220 156
preplace inst axis_clock_converter_0 -pg 1 -lvl 9 -x 4220 -y 2230 -defaultsOSRD
preplace inst axis_dwidth_converter_0 -pg 1 -lvl 8 -x 3700 -y 2340 -defaultsOSRD
preplace inst axis_readout_v2_0 -pg 1 -lvl 7 -x 3050 -y 1680 -defaultsOSRD
preplace inst axis_readout_v2_1 -pg 1 -lvl 7 -x 3050 -y 2020 -defaultsOSRD -resize 200 176
preplace inst axis_register_slice_0 -pg 1 -lvl 5 -x 1720 -y 2120 -defaultsOSRD
preplace inst axis_register_slice_1 -pg 1 -lvl 5 -x 1720 -y 2410 -defaultsOSRD
preplace inst axis_register_slice_2 -pg 1 -lvl 6 -x 2400 -y 2070 -defaultsOSRD -resize 180 116
preplace inst axis_register_slice_3 -pg 1 -lvl 6 -x 2400 -y 2220 -defaultsOSRD -resize 180 116
preplace inst axis_set_reg_0 -pg 1 -lvl 6 -x 2400 -y 3040 -defaultsOSRD
preplace inst axis_signal_gen_v6_0 -pg 1 -lvl 4 -x 1400 -y 2100 -defaultsOSRD
preplace inst axis_signal_gen_v6_1 -pg 1 -lvl 4 -x 1400 -y 2390 -defaultsOSRD -resize 220 236
preplace inst axis_switch_avg -pg 1 -lvl 9 -x 4220 -y 860 -defaultsOSRD -resize 240 196
preplace inst axis_switch_buf -pg 1 -lvl 9 -x 4220 -y 1080 -defaultsOSRD -resize 240 196
preplace inst axis_switch_ddr4 -pg 1 -lvl 8 -x 3700 -y 2080 -defaultsOSRD
preplace inst axis_switch_gen -pg 1 -lvl 3 -x 1000 -y 1330 -defaultsOSRD
preplace inst axis_switch_mr -pg 1 -lvl 8 -x 3700 -y 1860 -defaultsOSRD
preplace inst axis_tproc64x32_x8_0 -pg 1 -lvl 2 -x 570 -y 1880 -defaultsOSRD
preplace inst clk_adc0_x2 -pg 1 -lvl 6 -x 2400 -y 690 -defaultsOSRD
preplace inst clk_tproc -pg 1 -lvl 6 -x 2400 -y 1410 -defaultsOSRD -resize 160 96
preplace inst ddr4_0 -pg 1 -lvl 11 -x 5080 -y 2500 -defaultsOSRD
preplace inst mr_buffer_et_0 -pg 1 -lvl 9 -x 4220 -y 1940 -defaultsOSRD
preplace inst ps8_0_axi_periph -pg 1 -lvl 7 -x 3050 -y 560 -defaultsOSRD
preplace inst rst_100 -pg 1 -lvl 6 -x 2400 -y 300 -defaultsOSRD
preplace inst rst_adc0 -pg 1 -lvl 6 -x 2400 -y 490 -defaultsOSRD
preplace inst rst_adc0_x2 -pg 1 -lvl 6 -x 2400 -y 840 -defaultsOSRD -resize 320 156
preplace inst rst_dac0 -pg 1 -lvl 6 -x 2400 -y 1060 -defaultsOSRD -resize 320 156
preplace inst rst_dac1 -pg 1 -lvl 6 -x 2400 -y 1240 -defaultsOSRD -resize 320 156
preplace inst rst_ddr4 -pg 1 -lvl 6 -x 2400 -y 1770 -defaultsOSRD
preplace inst rst_tproc -pg 1 -lvl 6 -x 2400 -y 1560 -defaultsOSRD -resize 320 156
preplace inst smartconnect_0 -pg 1 -lvl 10 -x 4640 -y 2490 -defaultsOSRD
preplace inst usp_rf_data_converter_0 -pg 1 -lvl 6 -x 2400 -y 2700 -defaultsOSRD
preplace inst vect2bits_16_0 -pg 1 -lvl 7 -x 3050 -y 3040 -defaultsOSRD
preplace inst xlconcat_0 -pg 1 -lvl 4 -x 1400 -y 160 -defaultsOSRD
preplace inst xlconstant_0 -pg 1 -lvl 1 -x 140 -y 2130 -defaultsOSRD
preplace inst xlconstant_1 -pg 1 -lvl 1 -x 140 -y 2240 -defaultsOSRD -resize 140 88
preplace inst xlconstant_2 -pg 1 -lvl 1 -x 140 -y 2350 -defaultsOSRD -resize 140 88
preplace inst xlconstant_3 -pg 1 -lvl 1 -x 140 -y 2480 -defaultsOSRD -resize 140 88
preplace inst zynq_ultra_ps_e_0 -pg 1 -lvl 6 -x 2400 -y 110 -defaultsOSRD
preplace netloc PMOD1_0_1 1 0 2 NJ 1880 320
preplace netloc axi_bram_ctrl_0_bram_doutb 1 1 1 370 2030n
preplace netloc axi_dma_avg_s2mm_introut 1 3 8 1240 890 NJ 890 1980J 940 2810J 1120 NJ 1120 3920J 1200 NJ 1200 4830
preplace netloc axi_dma_buf_s2mm_introut 1 3 8 1250 1660 NJ 1660 NJ 1660 2780J 1550 3340J 1720 NJ 1720 NJ 1720 4820
preplace netloc axi_dma_gen_mm2s_introut 1 2 2 750 110 NJ
preplace netloc axi_dma_readout_s2mm_introut 1 3 8 1230 2250 NJ 2250 1900J 2300 NJ 2300 3480J 2250 3870J 2330 NJ 2330 4820
preplace netloc axi_dma_tproc_mm2s_introut 1 2 2 770 130 NJ
preplace netloc axi_dma_tproc_s2mm_introut 1 2 2 790 150 NJ
preplace netloc axi_intc_0_irq 1 5 1 1990 130n
preplace netloc axis_set_reg_0_dout 1 6 1 N 3040
preplace netloc axis_tproc64x32_x8_0_pmem_addr 1 1 2 380 2100 750
preplace netloc clk_adc0_x2_clk_out1 1 5 4 1990 1910 2790 1320 3400 2230 3970
preplace netloc clk_adc0_x2_locked 1 5 2 2040 620 2740
preplace netloc clk_tproc_clk_out1 1 1 8 360 2110 790 1930 N 1930 N 1930 1940 1670 2760 1540 3360 1700 3920
preplace netloc clk_tproc_locked 1 5 2 2040 1340 2710
preplace netloc ddr4_0_c0_ddr4_ui_clk 1 5 7 2000 1900 2750 2290 3490J 2260 3860J 2600 4380J 2600 4850 2610 5270
preplace netloc ddr4_0_c0_ddr4_ui_clk_sync_rst 1 5 7 2020 2470 NJ 2470 NJ 2470 3850J 2620 NJ 2620 NJ 2620 5260
preplace netloc proc_sys_reset_0_peripheral_aresetn 1 6 5 2760 2280 3460 2240 3980 2590 4410 2580 4830
preplace netloc rst_100_bus_struct_reset 1 6 5 2830J 1130 NJ 1130 3910J 1210 NJ 1210 4870
preplace netloc rst_adc0_peripheral_aresetn 1 5 2 2030 610 2740
preplace netloc rst_adc0_x2_peripheral_aresetn 1 5 4 2010 1980 2770 1340 3390 2200 3980
preplace netloc rst_dac0_peripheral_aresetn 1 2 5 810 2150 1200 1950 1570J 1950 1970J 1870 2740
preplace netloc rst_dac1_peripheral_aresetn 1 2 5 810 2470 1150 2530 1570J 2490 1980J 2480 2730
preplace netloc rst_ps8_0_99M_peripheral_aresetn 1 0 10 -30 1920 330 1390 820 1450 1160 1450 1540 1450 1890 1920 2840 1160 3420 1160 3950J 1220 4420
preplace netloc rst_tproc_peripheral_aresetn 1 1 8 380 2090 800 1940 N 1940 NJ 1940 1880 1940 2830 1560 3330J 1710 3910
preplace netloc usp_rf_data_converter_0_clk_adc0 1 5 2 2010 1930 2740
preplace netloc usp_rf_data_converter_0_clk_dac0 1 2 5 820 2160 1180 1960 1540 1960 1920 2920 2720
preplace netloc usp_rf_data_converter_0_clk_dac2 1 2 5 820 2450 1220 2540 1540 2500 1930 2930 2710
preplace netloc vect2bits_16_0_dout0 1 7 5 N 2890 NJ 2890 NJ 2890 NJ 2890 N
preplace netloc vect2bits_16_0_dout1 1 7 5 N 2910 NJ 2910 NJ 2910 NJ 2910 N
preplace netloc vect2bits_16_0_dout2 1 7 5 N 2930 NJ 2930 NJ 2930 NJ 2930 N
preplace netloc vect2bits_16_0_dout3 1 7 5 N 2950 NJ 2950 NJ 2950 NJ 2950 N
preplace netloc vect2bits_16_0_dout4 1 7 5 N 2970 NJ 2970 NJ 2970 NJ 2970 N
preplace netloc vect2bits_16_0_dout5 1 7 5 N 2990 NJ 2990 NJ 2990 NJ 2990 N
preplace netloc vect2bits_16_0_dout6 1 7 5 N 3010 NJ 3010 NJ 3010 NJ 3010 N
preplace netloc vect2bits_16_0_dout7 1 7 5 N 3030 NJ 3030 NJ 3030 NJ 3030 N
preplace netloc vect2bits_16_0_dout12 1 7 2 3430 1730 3920J
preplace netloc vect2bits_16_0_dout13 1 7 2 3500 2480 3970J
preplace netloc vect2bits_16_0_dout14 1 7 1 3410 1300n
preplace netloc vect2bits_16_0_dout15 1 7 1 3470 1560n
preplace netloc xlconcat_0_dout 1 4 1 N 160
preplace netloc xlconstant_0_dout 1 1 1 300 2130n
preplace netloc xlconstant_1_dout 1 1 1 290 2240n
preplace netloc xlconstant_2_dout 1 1 1 280 2350n
preplace netloc xlconstant_3_dout 1 1 1 N 2480
preplace netloc zynq_ultra_ps_e_0_pl_clk0 1 0 10 -10 1930 310 1380 810 1440 1190 1090 1530 40 1950 1970 2850 1170 3440 1150 3940J 1230 4410
preplace netloc zynq_ultra_ps_e_0_pl_resetn0 1 5 2 2020 600 2770
preplace netloc adc0_clk_1 1 0 6 N 2600 N 2600 N 2600 N 2600 N 2600 N
preplace netloc axi_bram_ctrl_0_BRAM_PORTA 1 1 1 310 2010n
preplace netloc axi_dma_avg_M_AXI_S2MM 1 4 7 1550 -90 N -90 N -90 N -90 N -90 N -90 4850
preplace netloc axi_dma_buf_M_AXI_S2MM 1 4 7 1560J -80 N -80 NJ -80 NJ -80 NJ -80 NJ -80 4840
preplace netloc axi_dma_gen_M_AXIS_MM2S 1 2 1 N 1280
preplace netloc axi_dma_gen_M_AXI_MM2S 1 2 3 760 1030 N 1030 N
preplace netloc axi_dma_readout_M_AXI_S2MM 1 4 7 1570J -70 N -70 NJ -70 NJ -70 NJ -70 NJ -70 4860
preplace netloc axi_dma_tproc_M_AXIS_MM2S 1 1 2 380 1640 750
preplace netloc axi_dma_tproc_M_AXI_MM2S 1 2 3 780 1050 NJ 1050 N
preplace netloc axi_dma_tproc_M_AXI_S2MM 1 2 3 800 1070 NJ 1070 N
preplace netloc axi_smc_M00_AXI 1 5 1 1890 60n
preplace netloc axis_avg_buffer_0_m0_axis 1 8 1 3840 800n
preplace netloc axis_avg_buffer_0_m1_axis 1 8 1 3880 1020n
preplace netloc axis_avg_buffer_0_m2_axis 1 8 1 N 1320
preplace netloc axis_avg_buffer_1_m0_axis 1 8 1 3870 820n
preplace netloc axis_avg_buffer_1_m1_axis 1 8 1 3900 1040n
preplace netloc axis_avg_buffer_1_m2_axis 1 8 1 N 1580
preplace netloc axis_broadcaster_0_M00_AXIS 1 7 1 3320 1220n
preplace netloc axis_broadcaster_0_M01_AXIS 1 7 1 3300 1860n
preplace netloc axis_broadcaster_1_M00_AXIS 1 7 1 3350 1480n
preplace netloc axis_broadcaster_1_M01_AXIS 1 7 1 3220 2040n
preplace netloc axis_buffer_ddr_v1_0_m_axi 1 9 1 N 2480
preplace netloc axis_cc_avg_0_M_AXIS 1 1 9 340 -60 N -60 N -60 NJ -60 N -60 NJ -60 NJ -60 NJ -60 4370
preplace netloc axis_cc_avg_1_M_AXIS 1 1 9 350 -50 N -50 N -50 NJ -50 N -50 NJ -50 NJ -50 NJ -50 4360
preplace netloc axis_cc_sg_0_M_AXIS 1 3 1 N 2040
preplace netloc axis_cc_sg_1_M_AXIS 1 3 1 N 2330
preplace netloc axis_clock_converter_0_M_AXIS 1 8 2 3990 2340 4370
preplace netloc axis_dwidth_converter_0_M_AXIS 1 8 1 3960 2190n
preplace netloc axis_readout_v2_0_m0_axis 1 7 1 3300 1670n
preplace netloc axis_readout_v2_0_m1_axis 1 6 2 2890 1570 3210
preplace netloc axis_readout_v2_1_m0_axis 1 7 1 3380 1820n
preplace netloc axis_readout_v2_1_m1_axis 1 6 2 2890 2270 3210
preplace netloc axis_register_slice_2_M_AXIS 1 6 1 2710 1630n
preplace netloc axis_register_slice_3_M_AXIS 1 6 1 2860 1970n
preplace netloc axis_register_slice_4_m_axis 1 5 1 1870J 2410n
preplace netloc axis_register_slice_6_m_axis 1 5 1 1910 2120n
preplace netloc axis_signal_gen_v6_0_m_axis 1 4 1 N 2100
preplace netloc axis_signal_gen_v6_1_m_axis 1 4 1 N 2390
preplace netloc axis_switch_0_M00_AXIS 1 8 1 N 1860
preplace netloc axis_switch_avg_M00_AXIS 1 9 1 N 860
preplace netloc axis_switch_buf_M00_AXIS 1 9 1 N 1080
preplace netloc axis_switch_ddr4_M00_AXIS 1 7 2 3500 1740 3860
preplace netloc axis_switch_gen_M00_AXIS 1 3 1 1170 1320n
preplace netloc axis_switch_gen_M01_AXIS 1 3 1 1140 1340n
preplace netloc axis_tproc64x32_x8_0_m0_axis 1 1 2 380 1400 760
preplace netloc axis_tproc64x32_x8_0_m1_axis 1 2 1 780 1810n
preplace netloc axis_tproc64x32_x8_0_m2_axis 1 2 1 770 1830n
preplace netloc axis_tproc64x32_x8_0_m8_axis 1 2 4 760J 2140 1150J 1920 NJ 1920 1860
preplace netloc dac0_clk_1 1 0 6 N 2620 N 2620 N 2620 N 2620 N 2620 N
preplace netloc dac2_clk_1 1 0 6 N 2640 N 2640 N 2640 N 2640 N 2640 N
preplace netloc ddr4_0_C0_DDR4 1 11 1 N 2450
preplace netloc mr_buffer_et_0_m00_axis 1 9 1 4360 1940n
preplace netloc ps8_0_axi_periph_M00_AXI 1 7 3 3500 710 3850 720 4420J
preplace netloc ps8_0_axi_periph_M01_AXI 1 7 3 3490 730 N 730 4400J
preplace netloc ps8_0_axi_periph_M02_AXI 1 7 3 3480 740 N 740 4390J
preplace netloc ps8_0_axi_periph_M03_AXI 1 7 1 3450 410n
preplace netloc ps8_0_axi_periph_M04_AXI 1 6 2 2880 1150 3280J
preplace netloc ps8_0_axi_periph_M05_AXI 1 6 2 2870 1140 3250J
preplace netloc ps8_0_axi_periph_M06_AXI 1 7 2 3470 820 3860
preplace netloc ps8_0_axi_periph_M07_AXI 1 7 2 3460 840 3850
preplace netloc ps8_0_axi_periph_M08_AXI 1 7 1 3370 510n
preplace netloc ps8_0_axi_periph_M09_AXI 1 1 7 360 -40 N -40 N -40 NJ -40 N -40 NJ -40 3240J
preplace netloc ps8_0_axi_periph_M10_AXI 1 7 2 3440 900 3930
preplace netloc ps8_0_axi_periph_M11_AXI 1 5 3 2030 2310 NJ 2310 3290J
preplace netloc ps8_0_axi_periph_M12_AXI 1 7 1 3410 590n
preplace netloc ps8_0_axi_periph_M13_AXI 1 3 5 1220 -30 NJ -30 NJ -30 NJ -30 3230
preplace netloc ps8_0_axi_periph_M14_AXI 1 3 5 1210 -20 NJ -20 NJ -20 NJ -20 3220
preplace netloc ps8_0_axi_periph_M15_AXI 1 1 7 380 590 N 590 N 590 NJ 590 NJ 590 2790J 20 3210
preplace netloc ps8_0_axi_periph_M16_AXI 1 2 6 810 910 N 910 N 910 1960J 950 2820J 1100 3220
preplace netloc ps8_0_axi_periph_M17_AXI 1 1 7 370 -10 NJ -10 NJ -10 NJ -10 NJ -10 NJ -10 3270
preplace netloc ps8_0_axi_periph_M18_AXI 1 0 8 -20 0 NJ 0 NJ 0 NJ 0 NJ 0 NJ 0 NJ 0 3260
preplace netloc ps8_0_axi_periph_M19_AXI 1 4 4 1580 900 1970 960 2800 1110 3210
preplace netloc ps8_0_axi_periph_M20_AXI 1 7 2 3400 1100 3890
preplace netloc ps8_0_axi_periph_M21_AXI 1 7 1 3310 770n
preplace netloc smartconnect_0_M00_AXI 1 10 1 N 2490
preplace netloc sys_clk_ddr4_1 1 10 2 4880 2380 NJ
preplace netloc sysref_in_1 1 0 6 NJ 2700 NJ 2700 NJ 2700 NJ 2700 NJ 2700 N
preplace netloc usp_rf_data_converter_0_m00_axis 1 5 2 2040 1990 2720
preplace netloc usp_rf_data_converter_0_m02_axis 1 5 2 2040 2320 2710
preplace netloc usp_rf_data_converter_0_vout00 1 6 6 N 2670 N 2670 N 2670 N 2670 N 2670 N
preplace netloc usp_rf_data_converter_0_vout20 1 6 6 N 2690 N 2690 N 2690 N 2690 N 2690 N
preplace netloc vin0_01_1 1 0 6 N 2660 N 2660 N 2660 N 2660 N 2660 N
preplace netloc vin0_23_1 1 0 6 N 2680 N 2680 N 2680 N 2680 N 2680 N
preplace netloc zynq_ultra_ps_e_0_M_AXI_HPM0_FPD 1 6 1 2850J 70n
preplace netloc zynq_ultra_ps_e_0_M_AXI_HPM1_FPD 1 6 4 2740 10 N 10 N 10 4380
levelinfo -pg 1 -50 140 570 1000 1400 1720 2400 3050 3700 4220 4640 5080 5320
pagesize -pg 1 -db -bbox -sgen -170 -100 5460 3560
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


