
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
set scripts_vivado_version 2019.1
set current_vivado_version [version -short]

if { [string first $scripts_vivado_version $current_vivado_version] == -1 } {
   puts ""
   catch {common::send_msg_id "BD_TCL-109" "ERROR" "This script was generated using Vivado <$scripts_vivado_version> and is being run in <$current_vivado_version> of Vivado. Please run the script in Vivado <$scripts_vivado_version> then open the design in Vivado <$current_vivado_version>. Upgrade the design by running \"Tools => Report => Report IP Status...\", then run write_bd_tcl to create an updated script."}

   return 1
}

################################################################
# START
################################################################

# To test this script, run the following commands from Vivado Tcl console:
# source d_1_script.tcl


# The design that will be created by this Tcl script contains the following 
# module references:
# vect2bits_4

# Please add the sources of those modules before sourcing this Tcl script.

# If there is no project opened, this script will create a
# project, but make sure you do not have an existing project
# <./myproj/project_1.xpr> in the current working folder.

set list_projs [get_projects -quiet]
if { $list_projs eq "" } {
   create_project project_1 myproj -part xczu28dr-ffvg1517-2-e
   set_property BOARD_PART xilinx.com:zcu111:part0:1.1 [current_project]
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
      common::send_msg_id "BD_TCL-001" "INFO" "Changing value of <design_name> from <$design_name> to <$cur_design> since current design is empty."
      set design_name [get_property NAME $cur_design]
   }
   common::send_msg_id "BD_TCL-002" "INFO" "Constructing design in IPI design <$cur_design>..."

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

   common::send_msg_id "BD_TCL-003" "INFO" "Currently there is no design <$design_name> in project, so creating one..."

   create_bd_design $design_name

   common::send_msg_id "BD_TCL-004" "INFO" "Making design <$design_name> as current_bd_design."
   current_bd_design $design_name

}

common::send_msg_id "BD_TCL-005" "INFO" "Currently the variable <design_name> is equal to \"$design_name\"."

if { $nRet != 0 } {
   catch {common::send_msg_id "BD_TCL-114" "ERROR" $errMsg}
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
xilinx.com:ip:smartconnect:1.0\
user.org:user:axis_avg_buffer:1.0\
xilinx.com:ip:axis_clock_converter:1.1\
user.org:user:axis_constant:1.0\
user.org:user:axis_readout_v2:1.0\
xilinx.com:ip:axis_register_slice:1.1\
user.org:user:axis_set_reg:1.0\
user.org:user:axis_signal_gen_v4:1.0\
xilinx.com:ip:axis_switch:1.1\
user.org:user:axis_terminator:1.0\
user.org:user:axis_tproc64x32_x8:1.0\
xilinx.com:ip:clk_wiz:6.0\
xilinx.com:ip:proc_sys_reset:5.0\
xilinx.com:ip:system_ila:1.1\
xilinx.com:ip:usp_rf_data_converter:2.1\
xilinx.com:ip:xlconstant:1.1\
xilinx.com:ip:zynq_ultra_ps_e:3.3\
"

   set list_ips_missing ""
   common::send_msg_id "BD_TCL-006" "INFO" "Checking if the following IPs exist in the project's IP catalog: $list_check_ips ."

   foreach ip_vlnv $list_check_ips {
      set ip_obj [get_ipdefs -all $ip_vlnv]
      if { $ip_obj eq "" } {
         lappend list_ips_missing $ip_vlnv
      }
   }

   if { $list_ips_missing ne "" } {
      catch {common::send_msg_id "BD_TCL-115" "ERROR" "The following IPs are not found in the IP Catalog:\n  $list_ips_missing\n\nResolution: Please add the repository containing the IP(s) to the project." }
      set bCheckIPsPassed 0
   }

}

##################################################################
# CHECK Modules
##################################################################
set bCheckModules 1
if { $bCheckModules == 1 } {
   set list_check_mods "\ 
vect2bits_4\
"

   set list_mods_missing ""
   common::send_msg_id "BD_TCL-006" "INFO" "Checking if the following modules exist in the project's sources: $list_check_mods ."

   foreach mod_vlnv $list_check_mods {
      if { [can_resolve_reference $mod_vlnv] == 0 } {
         lappend list_mods_missing $mod_vlnv
      }
   }

   if { $list_mods_missing ne "" } {
      catch {common::send_msg_id "BD_TCL-115" "ERROR" "The following module(s) are not found in the project: $list_mods_missing" }
      common::send_msg_id "BD_TCL-008" "INFO" "Please add source files for the missing module(s) above."
      set bCheckIPsPassed 0
   }
}

if { $bCheckIPsPassed != 1 } {
  common::send_msg_id "BD_TCL-1003" "WARNING" "Will not continue with creation of design due to the error(s) above."
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
     catch {common::send_msg_id "BD_TCL-100" "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_msg_id "BD_TCL-101" "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
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
  set PMOD0_0_LS [ create_bd_port -dir O PMOD0_0_LS ]
  set PMOD0_1_LS [ create_bd_port -dir O PMOD0_1_LS ]
  set PMOD0_2_LS [ create_bd_port -dir O PMOD0_2_LS ]
  set PMOD0_3_LS [ create_bd_port -dir O PMOD0_3_LS ]

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
   CONFIG.Memory_Type {True_Dual_Port_RAM} \
   CONFIG.Read_Width_B {64} \
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

  # Create instance: axis_avg_buffer_1, and set properties
  set axis_avg_buffer_1 [ create_bd_cell -type ip -vlnv user.org:user:axis_avg_buffer:1.0 axis_avg_buffer_1 ]

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

  # Create instance: axis_signal_gen_v4_0, and set properties
  set axis_signal_gen_v4_0 [ create_bd_cell -type ip -vlnv user.org:user:axis_signal_gen_v4:1.0 axis_signal_gen_v4_0 ]

  # Create instance: axis_signal_gen_v4_1, and set properties
  set axis_signal_gen_v4_1 [ create_bd_cell -type ip -vlnv user.org:user:axis_signal_gen_v4:1.0 axis_signal_gen_v4_1 ]

  # Create instance: axis_signal_gen_v4_2, and set properties
  set axis_signal_gen_v4_2 [ create_bd_cell -type ip -vlnv user.org:user:axis_signal_gen_v4:1.0 axis_signal_gen_v4_2 ]

  # Create instance: axis_signal_gen_v4_3, and set properties
  set axis_signal_gen_v4_3 [ create_bd_cell -type ip -vlnv user.org:user:axis_signal_gen_v4:1.0 axis_signal_gen_v4_3 ]

  # Create instance: axis_signal_gen_v4_4, and set properties
  set axis_signal_gen_v4_4 [ create_bd_cell -type ip -vlnv user.org:user:axis_signal_gen_v4:1.0 axis_signal_gen_v4_4 ]

  # Create instance: axis_signal_gen_v4_5, and set properties
  set axis_signal_gen_v4_5 [ create_bd_cell -type ip -vlnv user.org:user:axis_signal_gen_v4:1.0 axis_signal_gen_v4_5 ]

  # Create instance: axis_signal_gen_v4_6, and set properties
  set axis_signal_gen_v4_6 [ create_bd_cell -type ip -vlnv user.org:user:axis_signal_gen_v4:1.0 axis_signal_gen_v4_6 ]

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

  # Create instance: clk_adc0_x2, and set properties
  set clk_adc0_x2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_adc0_x2 ]
  set_property -dict [ list \
   CONFIG.CLKOUT1_JITTER {81.938} \
   CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {384} \
   CONFIG.MMCM_CLKOUT0_DIVIDE_F {3.125} \
 ] $clk_adc0_x2

  # Create instance: ps8_0_axi_periph, and set properties
  set ps8_0_axi_periph [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 ps8_0_axi_periph ]
  set_property -dict [ list \
   CONFIG.NUM_MI {21} \
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

  # Create instance: system_ila_0, and set properties
  set system_ila_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:system_ila:1.1 system_ila_0 ]
  set_property -dict [ list \
   CONFIG.C_BRAM_CNT {0.5} \
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
   CONFIG.C_BRAM_CNT {1.5} \
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
  set usp_rf_data_converter_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:usp_rf_data_converter:2.1 usp_rf_data_converter_0 ]
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

  # Create instance: vect2bits_4_0, and set properties
  set block_name vect2bits_4
  set block_cell_name vect2bits_4_0
  if { [catch {set vect2bits_4_0 [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_msg_id "BD_TCL-105" "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $vect2bits_4_0 eq "" } {
     catch {common::send_msg_id "BD_TCL-106" "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
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
   CONFIG.PSU_BANK_0_IO_STANDARD {LVCMOS18} \
   CONFIG.PSU_BANK_1_IO_STANDARD {LVCMOS18} \
   CONFIG.PSU_BANK_2_IO_STANDARD {LVCMOS18} \
   CONFIG.PSU_DDR_RAM_HIGHADDR {0xFFFFFFFF} \
   CONFIG.PSU_DDR_RAM_HIGHADDR_OFFSET {0x800000000} \
   CONFIG.PSU_DDR_RAM_LOWADDR_OFFSET {0x80000000} \
   CONFIG.PSU_DYNAMIC_DDR_CONFIG_EN {0} \
   CONFIG.PSU_MIO_0_DIRECTION {out} \
   CONFIG.PSU_MIO_0_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_0_POLARITY {Default} \
   CONFIG.PSU_MIO_10_DIRECTION {inout} \
   CONFIG.PSU_MIO_10_POLARITY {Default} \
   CONFIG.PSU_MIO_11_DIRECTION {inout} \
   CONFIG.PSU_MIO_11_POLARITY {Default} \
   CONFIG.PSU_MIO_12_DIRECTION {out} \
   CONFIG.PSU_MIO_12_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_12_POLARITY {Default} \
   CONFIG.PSU_MIO_13_DIRECTION {inout} \
   CONFIG.PSU_MIO_13_POLARITY {Default} \
   CONFIG.PSU_MIO_14_DIRECTION {inout} \
   CONFIG.PSU_MIO_14_POLARITY {Default} \
   CONFIG.PSU_MIO_15_DIRECTION {inout} \
   CONFIG.PSU_MIO_15_POLARITY {Default} \
   CONFIG.PSU_MIO_16_DIRECTION {inout} \
   CONFIG.PSU_MIO_16_POLARITY {Default} \
   CONFIG.PSU_MIO_17_DIRECTION {inout} \
   CONFIG.PSU_MIO_17_POLARITY {Default} \
   CONFIG.PSU_MIO_18_DIRECTION {in} \
   CONFIG.PSU_MIO_18_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_18_POLARITY {Default} \
   CONFIG.PSU_MIO_18_SLEW {fast} \
   CONFIG.PSU_MIO_19_DIRECTION {out} \
   CONFIG.PSU_MIO_19_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_19_POLARITY {Default} \
   CONFIG.PSU_MIO_1_DIRECTION {inout} \
   CONFIG.PSU_MIO_1_POLARITY {Default} \
   CONFIG.PSU_MIO_20_DIRECTION {inout} \
   CONFIG.PSU_MIO_20_POLARITY {Default} \
   CONFIG.PSU_MIO_21_DIRECTION {inout} \
   CONFIG.PSU_MIO_21_POLARITY {Default} \
   CONFIG.PSU_MIO_22_DIRECTION {inout} \
   CONFIG.PSU_MIO_22_POLARITY {Default} \
   CONFIG.PSU_MIO_23_DIRECTION {inout} \
   CONFIG.PSU_MIO_23_POLARITY {Default} \
   CONFIG.PSU_MIO_24_DIRECTION {inout} \
   CONFIG.PSU_MIO_24_POLARITY {Default} \
   CONFIG.PSU_MIO_25_DIRECTION {inout} \
   CONFIG.PSU_MIO_25_POLARITY {Default} \
   CONFIG.PSU_MIO_26_DIRECTION {inout} \
   CONFIG.PSU_MIO_26_POLARITY {Default} \
   CONFIG.PSU_MIO_27_DIRECTION {out} \
   CONFIG.PSU_MIO_27_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_27_POLARITY {Default} \
   CONFIG.PSU_MIO_28_DIRECTION {in} \
   CONFIG.PSU_MIO_28_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_28_POLARITY {Default} \
   CONFIG.PSU_MIO_28_SLEW {fast} \
   CONFIG.PSU_MIO_29_DIRECTION {out} \
   CONFIG.PSU_MIO_29_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_29_POLARITY {Default} \
   CONFIG.PSU_MIO_2_DIRECTION {inout} \
   CONFIG.PSU_MIO_2_POLARITY {Default} \
   CONFIG.PSU_MIO_30_DIRECTION {in} \
   CONFIG.PSU_MIO_30_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_30_POLARITY {Default} \
   CONFIG.PSU_MIO_30_SLEW {fast} \
   CONFIG.PSU_MIO_31_DIRECTION {inout} \
   CONFIG.PSU_MIO_31_POLARITY {Default} \
   CONFIG.PSU_MIO_32_DIRECTION {out} \
   CONFIG.PSU_MIO_32_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_32_POLARITY {Default} \
   CONFIG.PSU_MIO_33_DIRECTION {out} \
   CONFIG.PSU_MIO_33_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_33_POLARITY {Default} \
   CONFIG.PSU_MIO_34_DIRECTION {out} \
   CONFIG.PSU_MIO_34_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_34_POLARITY {Default} \
   CONFIG.PSU_MIO_35_DIRECTION {out} \
   CONFIG.PSU_MIO_35_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_35_POLARITY {Default} \
   CONFIG.PSU_MIO_36_DIRECTION {out} \
   CONFIG.PSU_MIO_36_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_36_POLARITY {Default} \
   CONFIG.PSU_MIO_37_DIRECTION {out} \
   CONFIG.PSU_MIO_37_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_37_POLARITY {Default} \
   CONFIG.PSU_MIO_38_DIRECTION {inout} \
   CONFIG.PSU_MIO_38_POLARITY {Default} \
   CONFIG.PSU_MIO_39_DIRECTION {inout} \
   CONFIG.PSU_MIO_39_POLARITY {Default} \
   CONFIG.PSU_MIO_3_DIRECTION {inout} \
   CONFIG.PSU_MIO_3_POLARITY {Default} \
   CONFIG.PSU_MIO_40_DIRECTION {inout} \
   CONFIG.PSU_MIO_40_POLARITY {Default} \
   CONFIG.PSU_MIO_41_DIRECTION {inout} \
   CONFIG.PSU_MIO_41_POLARITY {Default} \
   CONFIG.PSU_MIO_42_DIRECTION {inout} \
   CONFIG.PSU_MIO_42_POLARITY {Default} \
   CONFIG.PSU_MIO_43_DIRECTION {inout} \
   CONFIG.PSU_MIO_43_POLARITY {Default} \
   CONFIG.PSU_MIO_44_DIRECTION {inout} \
   CONFIG.PSU_MIO_44_POLARITY {Default} \
   CONFIG.PSU_MIO_45_DIRECTION {in} \
   CONFIG.PSU_MIO_45_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_45_POLARITY {Default} \
   CONFIG.PSU_MIO_45_SLEW {fast} \
   CONFIG.PSU_MIO_46_DIRECTION {inout} \
   CONFIG.PSU_MIO_46_POLARITY {Default} \
   CONFIG.PSU_MIO_47_DIRECTION {inout} \
   CONFIG.PSU_MIO_47_POLARITY {Default} \
   CONFIG.PSU_MIO_48_DIRECTION {inout} \
   CONFIG.PSU_MIO_48_POLARITY {Default} \
   CONFIG.PSU_MIO_49_DIRECTION {inout} \
   CONFIG.PSU_MIO_49_POLARITY {Default} \
   CONFIG.PSU_MIO_4_DIRECTION {inout} \
   CONFIG.PSU_MIO_4_POLARITY {Default} \
   CONFIG.PSU_MIO_50_DIRECTION {inout} \
   CONFIG.PSU_MIO_50_POLARITY {Default} \
   CONFIG.PSU_MIO_51_DIRECTION {out} \
   CONFIG.PSU_MIO_51_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_51_POLARITY {Default} \
   CONFIG.PSU_MIO_52_DIRECTION {in} \
   CONFIG.PSU_MIO_52_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_52_POLARITY {Default} \
   CONFIG.PSU_MIO_52_SLEW {fast} \
   CONFIG.PSU_MIO_53_DIRECTION {in} \
   CONFIG.PSU_MIO_53_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_53_POLARITY {Default} \
   CONFIG.PSU_MIO_53_SLEW {fast} \
   CONFIG.PSU_MIO_54_DIRECTION {inout} \
   CONFIG.PSU_MIO_54_POLARITY {Default} \
   CONFIG.PSU_MIO_55_DIRECTION {in} \
   CONFIG.PSU_MIO_55_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_55_POLARITY {Default} \
   CONFIG.PSU_MIO_55_SLEW {fast} \
   CONFIG.PSU_MIO_56_DIRECTION {inout} \
   CONFIG.PSU_MIO_56_POLARITY {Default} \
   CONFIG.PSU_MIO_57_DIRECTION {inout} \
   CONFIG.PSU_MIO_57_POLARITY {Default} \
   CONFIG.PSU_MIO_58_DIRECTION {out} \
   CONFIG.PSU_MIO_58_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_58_POLARITY {Default} \
   CONFIG.PSU_MIO_59_DIRECTION {inout} \
   CONFIG.PSU_MIO_59_POLARITY {Default} \
   CONFIG.PSU_MIO_5_DIRECTION {out} \
   CONFIG.PSU_MIO_5_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_5_POLARITY {Default} \
   CONFIG.PSU_MIO_60_DIRECTION {inout} \
   CONFIG.PSU_MIO_60_POLARITY {Default} \
   CONFIG.PSU_MIO_61_DIRECTION {inout} \
   CONFIG.PSU_MIO_61_POLARITY {Default} \
   CONFIG.PSU_MIO_62_DIRECTION {inout} \
   CONFIG.PSU_MIO_62_POLARITY {Default} \
   CONFIG.PSU_MIO_63_DIRECTION {inout} \
   CONFIG.PSU_MIO_63_POLARITY {Default} \
   CONFIG.PSU_MIO_64_DIRECTION {out} \
   CONFIG.PSU_MIO_64_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_64_POLARITY {Default} \
   CONFIG.PSU_MIO_65_DIRECTION {out} \
   CONFIG.PSU_MIO_65_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_65_POLARITY {Default} \
   CONFIG.PSU_MIO_66_DIRECTION {out} \
   CONFIG.PSU_MIO_66_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_66_POLARITY {Default} \
   CONFIG.PSU_MIO_67_DIRECTION {out} \
   CONFIG.PSU_MIO_67_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_67_POLARITY {Default} \
   CONFIG.PSU_MIO_68_DIRECTION {out} \
   CONFIG.PSU_MIO_68_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_68_POLARITY {Default} \
   CONFIG.PSU_MIO_69_DIRECTION {out} \
   CONFIG.PSU_MIO_69_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_69_POLARITY {Default} \
   CONFIG.PSU_MIO_6_DIRECTION {out} \
   CONFIG.PSU_MIO_6_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_6_POLARITY {Default} \
   CONFIG.PSU_MIO_70_DIRECTION {in} \
   CONFIG.PSU_MIO_70_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_70_POLARITY {Default} \
   CONFIG.PSU_MIO_70_SLEW {fast} \
   CONFIG.PSU_MIO_71_DIRECTION {in} \
   CONFIG.PSU_MIO_71_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_71_POLARITY {Default} \
   CONFIG.PSU_MIO_71_SLEW {fast} \
   CONFIG.PSU_MIO_72_DIRECTION {in} \
   CONFIG.PSU_MIO_72_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_72_POLARITY {Default} \
   CONFIG.PSU_MIO_72_SLEW {fast} \
   CONFIG.PSU_MIO_73_DIRECTION {in} \
   CONFIG.PSU_MIO_73_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_73_POLARITY {Default} \
   CONFIG.PSU_MIO_73_SLEW {fast} \
   CONFIG.PSU_MIO_74_DIRECTION {in} \
   CONFIG.PSU_MIO_74_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_74_POLARITY {Default} \
   CONFIG.PSU_MIO_74_SLEW {fast} \
   CONFIG.PSU_MIO_75_DIRECTION {in} \
   CONFIG.PSU_MIO_75_DRIVE_STRENGTH {12} \
   CONFIG.PSU_MIO_75_POLARITY {Default} \
   CONFIG.PSU_MIO_75_SLEW {fast} \
   CONFIG.PSU_MIO_76_DIRECTION {out} \
   CONFIG.PSU_MIO_76_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_76_POLARITY {Default} \
   CONFIG.PSU_MIO_77_DIRECTION {inout} \
   CONFIG.PSU_MIO_77_POLARITY {Default} \
   CONFIG.PSU_MIO_7_DIRECTION {out} \
   CONFIG.PSU_MIO_7_INPUT_TYPE {cmos} \
   CONFIG.PSU_MIO_7_POLARITY {Default} \
   CONFIG.PSU_MIO_8_DIRECTION {inout} \
   CONFIG.PSU_MIO_8_POLARITY {Default} \
   CONFIG.PSU_MIO_9_DIRECTION {inout} \
   CONFIG.PSU_MIO_9_POLARITY {Default} \
   CONFIG.PSU_MIO_TREE_PERIPHERALS {Quad SPI Flash#Quad SPI Flash#Quad SPI Flash#Quad SPI Flash#Quad SPI Flash#Quad SPI Flash#Feedback Clk#Quad SPI Flash#Quad SPI Flash#Quad SPI Flash#Quad SPI Flash#Quad SPI Flash#Quad SPI Flash#GPIO0 MIO#I2C 0#I2C 0#I2C 1#I2C 1#UART 0#UART 0#GPIO0 MIO#GPIO0 MIO#GPIO0 MIO#GPIO0 MIO#GPIO0 MIO#GPIO0 MIO#GPIO1 MIO#DPAUX#DPAUX#DPAUX#DPAUX#GPIO1 MIO#PMU GPO 0#PMU GPO 1#PMU GPO 2#PMU GPO 3#PMU GPO 4#PMU GPO 5#GPIO1 MIO#SD 1#SD 1#SD 1#SD 1#GPIO1 MIO#GPIO1 MIO#SD 1#SD 1#SD 1#SD 1#SD 1#SD 1#SD 1#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#Gem 3#Gem 3#Gem 3#Gem 3#Gem 3#Gem 3#Gem 3#Gem 3#Gem 3#Gem 3#Gem 3#Gem 3#MDIO 3#MDIO 3} \
   CONFIG.PSU_MIO_TREE_SIGNALS {sclk_out#miso_mo1#mo2#mo3#mosi_mi0#n_ss_out#clk_for_lpbk#n_ss_out_upper#mo_upper[0]#mo_upper[1]#mo_upper[2]#mo_upper[3]#sclk_out_upper#gpio0[13]#scl_out#sda_out#scl_out#sda_out#rxd#txd#gpio0[20]#gpio0[21]#gpio0[22]#gpio0[23]#gpio0[24]#gpio0[25]#gpio1[26]#dp_aux_data_out#dp_hot_plug_detect#dp_aux_data_oe#dp_aux_data_in#gpio1[31]#gpo[0]#gpo[1]#gpo[2]#gpo[3]#gpo[4]#gpo[5]#gpio1[38]#sdio1_data_out[4]#sdio1_data_out[5]#sdio1_data_out[6]#sdio1_data_out[7]#gpio1[43]#gpio1[44]#sdio1_cd_n#sdio1_data_out[0]#sdio1_data_out[1]#sdio1_data_out[2]#sdio1_data_out[3]#sdio1_cmd_out#sdio1_clk_out#ulpi_clk_in#ulpi_dir#ulpi_tx_data[2]#ulpi_nxt#ulpi_tx_data[0]#ulpi_tx_data[1]#ulpi_stp#ulpi_tx_data[3]#ulpi_tx_data[4]#ulpi_tx_data[5]#ulpi_tx_data[6]#ulpi_tx_data[7]#rgmii_tx_clk#rgmii_txd[0]#rgmii_txd[1]#rgmii_txd[2]#rgmii_txd[3]#rgmii_tx_ctl#rgmii_rx_clk#rgmii_rxd[0]#rgmii_rxd[1]#rgmii_rxd[2]#rgmii_rxd[3]#rgmii_rx_ctl#gem3_mdc#gem3_mdio_out} \
   CONFIG.PSU_SD1_INTERNAL_BUS_WIDTH {8} \
   CONFIG.PSU_USB3__DUAL_CLOCK_ENABLE {1} \
   CONFIG.PSU__ACT_DDR_FREQ_MHZ {1066.656006} \
   CONFIG.PSU__AFI0_COHERENCY {0} \
   CONFIG.PSU__CAN1__GRP_CLK__ENABLE {0} \
   CONFIG.PSU__CAN1__PERIPHERAL__ENABLE {0} \
   CONFIG.PSU__CRF_APB__ACPU_CTRL__ACT_FREQMHZ {1199.988037} \
   CONFIG.PSU__CRF_APB__ACPU_CTRL__DIVISOR0 {1} \
   CONFIG.PSU__CRF_APB__ACPU_CTRL__FREQMHZ {1200} \
   CONFIG.PSU__CRF_APB__ACPU_CTRL__SRCSEL {APLL} \
   CONFIG.PSU__CRF_APB__APLL_CTRL__DIV2 {1} \
   CONFIG.PSU__CRF_APB__APLL_CTRL__FBDIV {72} \
   CONFIG.PSU__CRF_APB__APLL_CTRL__FRACDATA {0.000000} \
   CONFIG.PSU__CRF_APB__APLL_CTRL__SRCSEL {PSS_REF_CLK} \
   CONFIG.PSU__CRF_APB__APLL_FRAC_CFG__ENABLED {0} \
   CONFIG.PSU__CRF_APB__APLL_TO_LPD_CTRL__DIVISOR0 {3} \
   CONFIG.PSU__CRF_APB__DBG_FPD_CTRL__ACT_FREQMHZ {249.997498} \
   CONFIG.PSU__CRF_APB__DBG_FPD_CTRL__DIVISOR0 {2} \
   CONFIG.PSU__CRF_APB__DBG_FPD_CTRL__FREQMHZ {250} \
   CONFIG.PSU__CRF_APB__DBG_FPD_CTRL__SRCSEL {IOPLL} \
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
   CONFIG.PSU__CRF_APB__DPLL_CTRL__SRCSEL {PSS_REF_CLK} \
   CONFIG.PSU__CRF_APB__DPLL_FRAC_CFG__ENABLED {0} \
   CONFIG.PSU__CRF_APB__DPLL_TO_LPD_CTRL__DIVISOR0 {2} \
   CONFIG.PSU__CRF_APB__DP_AUDIO_REF_CTRL__ACT_FREQMHZ {24.999750} \
   CONFIG.PSU__CRF_APB__DP_AUDIO_REF_CTRL__DIVISOR0 {15} \
   CONFIG.PSU__CRF_APB__DP_AUDIO_REF_CTRL__DIVISOR1 {1} \
   CONFIG.PSU__CRF_APB__DP_AUDIO_REF_CTRL__SRCSEL {RPLL} \
   CONFIG.PSU__CRF_APB__DP_AUDIO__FRAC_ENABLED {0} \
   CONFIG.PSU__CRF_APB__DP_STC_REF_CTRL__ACT_FREQMHZ {26.785446} \
   CONFIG.PSU__CRF_APB__DP_STC_REF_CTRL__DIVISOR0 {14} \
   CONFIG.PSU__CRF_APB__DP_STC_REF_CTRL__DIVISOR1 {1} \
   CONFIG.PSU__CRF_APB__DP_STC_REF_CTRL__SRCSEL {RPLL} \
   CONFIG.PSU__CRF_APB__DP_VIDEO_REF_CTRL__ACT_FREQMHZ {299.997009} \
   CONFIG.PSU__CRF_APB__DP_VIDEO_REF_CTRL__DIVISOR0 {5} \
   CONFIG.PSU__CRF_APB__DP_VIDEO_REF_CTRL__DIVISOR1 {1} \
   CONFIG.PSU__CRF_APB__DP_VIDEO_REF_CTRL__SRCSEL {VPLL} \
   CONFIG.PSU__CRF_APB__DP_VIDEO__FRAC_ENABLED {0} \
   CONFIG.PSU__CRF_APB__GDMA_REF_CTRL__ACT_FREQMHZ {599.994019} \
   CONFIG.PSU__CRF_APB__GDMA_REF_CTRL__DIVISOR0 {2} \
   CONFIG.PSU__CRF_APB__GDMA_REF_CTRL__FREQMHZ {600} \
   CONFIG.PSU__CRF_APB__GDMA_REF_CTRL__SRCSEL {APLL} \
   CONFIG.PSU__CRF_APB__GPU_REF_CTRL__DIVISOR0 {3} \
   CONFIG.PSU__CRF_APB__GPU_REF_CTRL__FREQMHZ {500} \
   CONFIG.PSU__CRF_APB__GPU_REF_CTRL__SRCSEL {IOPLL} \
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
   CONFIG.PSU__CRF_APB__VPLL_CTRL__SRCSEL {PSS_REF_CLK} \
   CONFIG.PSU__CRF_APB__VPLL_FRAC_CFG__ENABLED {0} \
   CONFIG.PSU__CRF_APB__VPLL_TO_LPD_CTRL__DIVISOR0 {3} \
   CONFIG.PSU__CRL_APB__ADMA_REF_CTRL__ACT_FREQMHZ {499.994995} \
   CONFIG.PSU__CRL_APB__ADMA_REF_CTRL__DIVISOR0 {3} \
   CONFIG.PSU__CRL_APB__ADMA_REF_CTRL__FREQMHZ {500} \
   CONFIG.PSU__CRL_APB__ADMA_REF_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRL_APB__AFI6_REF_CTRL__DIVISOR0 {3} \
   CONFIG.PSU__CRL_APB__AMS_REF_CTRL__ACT_FREQMHZ {49.999500} \
   CONFIG.PSU__CRL_APB__AMS_REF_CTRL__DIVISOR0 {30} \
   CONFIG.PSU__CRL_APB__AMS_REF_CTRL__DIVISOR1 {1} \
   CONFIG.PSU__CRL_APB__CAN0_REF_CTRL__DIVISOR0 {15} \
   CONFIG.PSU__CRL_APB__CAN0_REF_CTRL__DIVISOR1 {1} \
   CONFIG.PSU__CRL_APB__CAN1_REF_CTRL__DIVISOR0 {15} \
   CONFIG.PSU__CRL_APB__CAN1_REF_CTRL__DIVISOR1 {1} \
   CONFIG.PSU__CRL_APB__CAN1_REF_CTRL__FREQMHZ {100} \
   CONFIG.PSU__CRL_APB__CAN1_REF_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRL_APB__CPU_R5_CTRL__ACT_FREQMHZ {499.994995} \
   CONFIG.PSU__CRL_APB__CPU_R5_CTRL__DIVISOR0 {3} \
   CONFIG.PSU__CRL_APB__CPU_R5_CTRL__FREQMHZ {500} \
   CONFIG.PSU__CRL_APB__CPU_R5_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRL_APB__DBG_LPD_CTRL__ACT_FREQMHZ {249.997498} \
   CONFIG.PSU__CRL_APB__DBG_LPD_CTRL__DIVISOR0 {6} \
   CONFIG.PSU__CRL_APB__DBG_LPD_CTRL__FREQMHZ {250} \
   CONFIG.PSU__CRL_APB__DBG_LPD_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRL_APB__DLL_REF_CTRL__ACT_FREQMHZ {1499.984985} \
   CONFIG.PSU__CRL_APB__GEM0_REF_CTRL__DIVISOR0 {12} \
   CONFIG.PSU__CRL_APB__GEM0_REF_CTRL__DIVISOR1 {1} \
   CONFIG.PSU__CRL_APB__GEM1_REF_CTRL__DIVISOR0 {12} \
   CONFIG.PSU__CRL_APB__GEM1_REF_CTRL__DIVISOR1 {1} \
   CONFIG.PSU__CRL_APB__GEM2_REF_CTRL__DIVISOR0 {12} \
   CONFIG.PSU__CRL_APB__GEM2_REF_CTRL__DIVISOR1 {1} \
   CONFIG.PSU__CRL_APB__GEM3_REF_CTRL__ACT_FREQMHZ {124.998749} \
   CONFIG.PSU__CRL_APB__GEM3_REF_CTRL__DIVISOR0 {12} \
   CONFIG.PSU__CRL_APB__GEM3_REF_CTRL__DIVISOR1 {1} \
   CONFIG.PSU__CRL_APB__GEM3_REF_CTRL__FREQMHZ {125} \
   CONFIG.PSU__CRL_APB__GEM3_REF_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRL_APB__GEM_TSU_REF_CTRL__ACT_FREQMHZ {249.997498} \
   CONFIG.PSU__CRL_APB__GEM_TSU_REF_CTRL__DIVISOR0 {6} \
   CONFIG.PSU__CRL_APB__GEM_TSU_REF_CTRL__DIVISOR1 {1} \
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
   CONFIG.PSU__CRL_APB__NAND_REF_CTRL__DIVISOR0 {15} \
   CONFIG.PSU__CRL_APB__NAND_REF_CTRL__DIVISOR1 {1} \
   CONFIG.PSU__CRL_APB__PCAP_CTRL__ACT_FREQMHZ {187.498123} \
   CONFIG.PSU__CRL_APB__PCAP_CTRL__DIVISOR0 {8} \
   CONFIG.PSU__CRL_APB__PCAP_CTRL__FREQMHZ {200} \
   CONFIG.PSU__CRL_APB__PCAP_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRL_APB__PL0_REF_CTRL__ACT_FREQMHZ {99.999001} \
   CONFIG.PSU__CRL_APB__PL0_REF_CTRL__DIVISOR0 {15} \
   CONFIG.PSU__CRL_APB__PL0_REF_CTRL__DIVISOR1 {1} \
   CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ {100} \
   CONFIG.PSU__CRL_APB__PL0_REF_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRL_APB__PL1_REF_CTRL__DIVISOR0 {4} \
   CONFIG.PSU__CRL_APB__PL1_REF_CTRL__DIVISOR1 {1} \
   CONFIG.PSU__CRL_APB__PL2_REF_CTRL__DIVISOR0 {4} \
   CONFIG.PSU__CRL_APB__PL2_REF_CTRL__DIVISOR1 {1} \
   CONFIG.PSU__CRL_APB__PL3_REF_CTRL__DIVISOR0 {4} \
   CONFIG.PSU__CRL_APB__PL3_REF_CTRL__DIVISOR1 {1} \
   CONFIG.PSU__CRL_APB__QSPI_REF_CTRL__ACT_FREQMHZ {124.998749} \
   CONFIG.PSU__CRL_APB__QSPI_REF_CTRL__DIVISOR0 {12} \
   CONFIG.PSU__CRL_APB__QSPI_REF_CTRL__DIVISOR1 {1} \
   CONFIG.PSU__CRL_APB__QSPI_REF_CTRL__FREQMHZ {125} \
   CONFIG.PSU__CRL_APB__QSPI_REF_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRL_APB__RPLL_CTRL__DIV2 {1} \
   CONFIG.PSU__CRL_APB__RPLL_CTRL__FBDIV {45} \
   CONFIG.PSU__CRL_APB__RPLL_CTRL__FRACDATA {0.000000} \
   CONFIG.PSU__CRL_APB__RPLL_CTRL__SRCSEL {PSS_REF_CLK} \
   CONFIG.PSU__CRL_APB__RPLL_FRAC_CFG__ENABLED {0} \
   CONFIG.PSU__CRL_APB__RPLL_TO_FPD_CTRL__DIVISOR0 {2} \
   CONFIG.PSU__CRL_APB__SDIO0_REF_CTRL__DIVISOR0 {7} \
   CONFIG.PSU__CRL_APB__SDIO0_REF_CTRL__DIVISOR1 {1} \
   CONFIG.PSU__CRL_APB__SDIO1_REF_CTRL__ACT_FREQMHZ {187.498123} \
   CONFIG.PSU__CRL_APB__SDIO1_REF_CTRL__DIVISOR0 {8} \
   CONFIG.PSU__CRL_APB__SDIO1_REF_CTRL__DIVISOR1 {1} \
   CONFIG.PSU__CRL_APB__SDIO1_REF_CTRL__FREQMHZ {200} \
   CONFIG.PSU__CRL_APB__SDIO1_REF_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRL_APB__SPI0_REF_CTRL__DIVISOR0 {7} \
   CONFIG.PSU__CRL_APB__SPI0_REF_CTRL__DIVISOR1 {1} \
   CONFIG.PSU__CRL_APB__SPI1_REF_CTRL__DIVISOR0 {7} \
   CONFIG.PSU__CRL_APB__SPI1_REF_CTRL__DIVISOR1 {1} \
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
   CONFIG.PSU__CRL_APB__USB1_BUS_REF_CTRL__DIVISOR0 {6} \
   CONFIG.PSU__CRL_APB__USB1_BUS_REF_CTRL__DIVISOR1 {1} \
   CONFIG.PSU__CRL_APB__USB3_DUAL_REF_CTRL__ACT_FREQMHZ {19.999800} \
   CONFIG.PSU__CRL_APB__USB3_DUAL_REF_CTRL__DIVISOR0 {25} \
   CONFIG.PSU__CRL_APB__USB3_DUAL_REF_CTRL__DIVISOR1 {3} \
   CONFIG.PSU__CRL_APB__USB3_DUAL_REF_CTRL__FREQMHZ {20} \
   CONFIG.PSU__CRL_APB__USB3_DUAL_REF_CTRL__SRCSEL {IOPLL} \
   CONFIG.PSU__CRL_APB__USB3__ENABLE {1} \
   CONFIG.PSU__CSUPMU__PERIPHERAL__VALID {1} \
   CONFIG.PSU__DDRC__ADDR_MIRROR {0} \
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
   CONFIG.PSU__DDRC__ENABLE_LP4_HAS_ECC_COMP {0} \
   CONFIG.PSU__DDRC__ENABLE_LP4_SLOWBOOT {0} \
   CONFIG.PSU__DDRC__FGRM {1X} \
   CONFIG.PSU__DDRC__LPDDR3_T_REF_RANGE {NA} \
   CONFIG.PSU__DDRC__LPDDR4_T_REF_RANGE {NA} \
   CONFIG.PSU__DDRC__LP_ASR {manual normal} \
   CONFIG.PSU__DDRC__MEMORY_TYPE {DDR 4} \
   CONFIG.PSU__DDRC__PARITY_ENABLE {0} \
   CONFIG.PSU__DDRC__PER_BANK_REFRESH {0} \
   CONFIG.PSU__DDRC__PHY_DBI_MODE {0} \
   CONFIG.PSU__DDRC__RANK_ADDR_COUNT {0} \
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
   CONFIG.PSU__DDRC__VREF {1} \
   CONFIG.PSU__DDR_HIGH_ADDRESS_GUI_ENABLE {1} \
   CONFIG.PSU__DDR__INTERFACE__FREQMHZ {533.500} \
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
   CONFIG.PSU__ENET3__FIFO__ENABLE {0} \
   CONFIG.PSU__ENET3__GRP_MDIO__ENABLE {1} \
   CONFIG.PSU__ENET3__GRP_MDIO__IO {MIO 76 .. 77} \
   CONFIG.PSU__ENET3__PERIPHERAL__ENABLE {1} \
   CONFIG.PSU__ENET3__PERIPHERAL__IO {MIO 64 .. 75} \
   CONFIG.PSU__ENET3__PTP__ENABLE {0} \
   CONFIG.PSU__ENET3__TSU__ENABLE {0} \
   CONFIG.PSU__FPDMASTERS_COHERENCY {0} \
   CONFIG.PSU__FPD_SLCR__WDT1__ACT_FREQMHZ {99.999001} \
   CONFIG.PSU__FPD_SLCR__WDT1__FREQMHZ {99.999001} \
   CONFIG.PSU__FPD_SLCR__WDT_CLK_SEL__SELECT {APB} \
   CONFIG.PSU__FPGA_PL0_ENABLE {1} \
   CONFIG.PSU__GEM3_COHERENCY {0} \
   CONFIG.PSU__GEM3_ROUTE_THROUGH_FPD {0} \
   CONFIG.PSU__GEM__TSU__ENABLE {0} \
   CONFIG.PSU__GPIO0_MIO__IO {MIO 0 .. 25} \
   CONFIG.PSU__GPIO0_MIO__PERIPHERAL__ENABLE {1} \
   CONFIG.PSU__GPIO1_MIO__IO {MIO 26 .. 51} \
   CONFIG.PSU__GPIO1_MIO__PERIPHERAL__ENABLE {1} \
   CONFIG.PSU__GT__LINK_SPEED {HBR} \
   CONFIG.PSU__GT__PRE_EMPH_LVL_4 {0} \
   CONFIG.PSU__GT__VLT_SWNG_LVL_4 {0} \
   CONFIG.PSU__HIGH_ADDRESS__ENABLE {1} \
   CONFIG.PSU__I2C0__PERIPHERAL__ENABLE {1} \
   CONFIG.PSU__I2C0__PERIPHERAL__IO {MIO 14 .. 15} \
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
   CONFIG.PSU__LPD_SLCR__CSUPMU__ACT_FREQMHZ {100.000000} \
   CONFIG.PSU__LPD_SLCR__CSUPMU__FREQMHZ {100.000000} \
   CONFIG.PSU__MAXIGP0__DATA_WIDTH {128} \
   CONFIG.PSU__MAXIGP1__DATA_WIDTH {128} \
   CONFIG.PSU__MAXIGP2__DATA_WIDTH {32} \
   CONFIG.PSU__OVERRIDE__BASIC_CLOCK {0} \
   CONFIG.PSU__PL_CLK0_BUF {TRUE} \
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
   CONFIG.PSU__PROTECTION__MASTERS {USB1:NonSecure;0|USB0:NonSecure;1|S_AXI_LPD:NA;0|S_AXI_HPC1_FPD:NA;0|S_AXI_HPC0_FPD:NA;1|S_AXI_HP3_FPD:NA;0|S_AXI_HP2_FPD:NA;0|S_AXI_HP1_FPD:NA;0|S_AXI_HP0_FPD:NA;0|S_AXI_ACP:NA;0|S_AXI_ACE:NA;0|SD1:NonSecure;1|SD0:NonSecure;0|SATA1:NonSecure;1|SATA0:NonSecure;1|RPU1:Secure;1|RPU0:Secure;1|QSPI:NonSecure;1|PMU:NA;1|PCIe:NonSecure;0|NAND:NonSecure;0|LDMA:NonSecure;1|GPU:NonSecure;1|GEM3:NonSecure;1|GEM2:NonSecure;0|GEM1:NonSecure;0|GEM0:NonSecure;0|FDMA:NonSecure;1|DP:NonSecure;1|DAP:NA;1|Coresight:NA;1|CSU:NA;1|APU:NA;1} \
   CONFIG.PSU__PROTECTION__SLAVES {LPD;USB3_1_XHCI;FE300000;FE3FFFFF;0|LPD;USB3_1;FF9E0000;FF9EFFFF;0|LPD;USB3_0_XHCI;FE200000;FE2FFFFF;1|LPD;USB3_0;FF9D0000;FF9DFFFF;1|LPD;UART1;FF010000;FF01FFFF;1|LPD;UART0;FF000000;FF00FFFF;1|LPD;TTC3;FF140000;FF14FFFF;1|LPD;TTC2;FF130000;FF13FFFF;1|LPD;TTC1;FF120000;FF12FFFF;1|LPD;TTC0;FF110000;FF11FFFF;1|FPD;SWDT1;FD4D0000;FD4DFFFF;1|LPD;SWDT0;FF150000;FF15FFFF;1|LPD;SPI1;FF050000;FF05FFFF;0|LPD;SPI0;FF040000;FF04FFFF;0|FPD;SMMU_REG;FD5F0000;FD5FFFFF;1|FPD;SMMU;FD800000;FDFFFFFF;1|FPD;SIOU;FD3D0000;FD3DFFFF;1|FPD;SERDES;FD400000;FD47FFFF;1|LPD;SD1;FF170000;FF17FFFF;1|LPD;SD0;FF160000;FF16FFFF;0|FPD;SATA;FD0C0000;FD0CFFFF;1|LPD;RTC;FFA60000;FFA6FFFF;1|LPD;RSA_CORE;FFCE0000;FFCEFFFF;1|LPD;RPU;FF9A0000;FF9AFFFF;1|LPD;R5_TCM_RAM_GLOBAL;FFE00000;FFE3FFFF;1|LPD;R5_1_Instruction_Cache;FFEC0000;FFECFFFF;1|LPD;R5_1_Data_Cache;FFED0000;FFEDFFFF;1|LPD;R5_1_BTCM_GLOBAL;FFEB0000;FFEBFFFF;1|LPD;R5_1_ATCM_GLOBAL;FFE90000;FFE9FFFF;1|LPD;R5_0_Instruction_Cache;FFE40000;FFE4FFFF;1|LPD;R5_0_Data_Cache;FFE50000;FFE5FFFF;1|LPD;R5_0_BTCM_GLOBAL;FFE20000;FFE2FFFF;1|LPD;R5_0_ATCM_GLOBAL;FFE00000;FFE0FFFF;1|LPD;QSPI_Linear_Address;C0000000;DFFFFFFF;1|LPD;QSPI;FF0F0000;FF0FFFFF;1|LPD;PMU_RAM;FFDC0000;FFDDFFFF;1|LPD;PMU_GLOBAL;FFD80000;FFDBFFFF;1|FPD;PCIE_MAIN;FD0E0000;FD0EFFFF;0|FPD;PCIE_LOW;E0000000;EFFFFFFF;0|FPD;PCIE_HIGH2;8000000000;BFFFFFFFFF;0|FPD;PCIE_HIGH1;600000000;7FFFFFFFF;0|FPD;PCIE_DMA;FD0F0000;FD0FFFFF;0|FPD;PCIE_ATTRIB;FD480000;FD48FFFF;0|LPD;OCM_XMPU_CFG;FFA70000;FFA7FFFF;1|LPD;OCM_SLCR;FF960000;FF96FFFF;1|OCM;OCM;FFFC0000;FFFFFFFF;1|LPD;NAND;FF100000;FF10FFFF;0|LPD;MBISTJTAG;FFCF0000;FFCFFFFF;1|LPD;LPD_XPPU_SINK;FF9C0000;FF9CFFFF;1|LPD;LPD_XPPU;FF980000;FF98FFFF;1|LPD;LPD_SLCR_SECURE;FF4B0000;FF4DFFFF;1|LPD;LPD_SLCR;FF410000;FF4AFFFF;1|LPD;LPD_GPV;FE100000;FE1FFFFF;1|LPD;LPD_DMA_7;FFAF0000;FFAFFFFF;1|LPD;LPD_DMA_6;FFAE0000;FFAEFFFF;1|LPD;LPD_DMA_5;FFAD0000;FFADFFFF;1|LPD;LPD_DMA_4;FFAC0000;FFACFFFF;1|LPD;LPD_DMA_3;FFAB0000;FFABFFFF;1|LPD;LPD_DMA_2;FFAA0000;FFAAFFFF;1|LPD;LPD_DMA_1;FFA90000;FFA9FFFF;1|LPD;LPD_DMA_0;FFA80000;FFA8FFFF;1|LPD;IPI_CTRL;FF380000;FF3FFFFF;1|LPD;IOU_SLCR;FF180000;FF23FFFF;1|LPD;IOU_SECURE_SLCR;FF240000;FF24FFFF;1|LPD;IOU_SCNTRS;FF260000;FF26FFFF;1|LPD;IOU_SCNTR;FF250000;FF25FFFF;1|LPD;IOU_GPV;FE000000;FE0FFFFF;1|LPD;I2C1;FF030000;FF03FFFF;1|LPD;I2C0;FF020000;FF02FFFF;1|FPD;GPU;FD4B0000;FD4BFFFF;0|LPD;GPIO;FF0A0000;FF0AFFFF;1|LPD;GEM3;FF0E0000;FF0EFFFF;1|LPD;GEM2;FF0D0000;FF0DFFFF;0|LPD;GEM1;FF0C0000;FF0CFFFF;0|LPD;GEM0;FF0B0000;FF0BFFFF;0|FPD;FPD_XMPU_SINK;FD4F0000;FD4FFFFF;1|FPD;FPD_XMPU_CFG;FD5D0000;FD5DFFFF;1|FPD;FPD_SLCR_SECURE;FD690000;FD6CFFFF;1|FPD;FPD_SLCR;FD610000;FD68FFFF;1|FPD;FPD_GPV;FD700000;FD7FFFFF;1|FPD;FPD_DMA_CH7;FD570000;FD57FFFF;1|FPD;FPD_DMA_CH6;FD560000;FD56FFFF;1|FPD;FPD_DMA_CH5;FD550000;FD55FFFF;1|FPD;FPD_DMA_CH4;FD540000;FD54FFFF;1|FPD;FPD_DMA_CH3;FD530000;FD53FFFF;1|FPD;FPD_DMA_CH2;FD520000;FD52FFFF;1|FPD;FPD_DMA_CH1;FD510000;FD51FFFF;1|FPD;FPD_DMA_CH0;FD500000;FD50FFFF;1|LPD;EFUSE;FFCC0000;FFCCFFFF;1|FPD;Display Port;FD4A0000;FD4AFFFF;1|FPD;DPDMA;FD4C0000;FD4CFFFF;1|FPD;DDR_XMPU5_CFG;FD050000;FD05FFFF;1|FPD;DDR_XMPU4_CFG;FD040000;FD04FFFF;1|FPD;DDR_XMPU3_CFG;FD030000;FD03FFFF;1|FPD;DDR_XMPU2_CFG;FD020000;FD02FFFF;1|FPD;DDR_XMPU1_CFG;FD010000;FD01FFFF;1|FPD;DDR_XMPU0_CFG;FD000000;FD00FFFF;1|FPD;DDR_QOS_CTRL;FD090000;FD09FFFF;1|FPD;DDR_PHY;FD080000;FD08FFFF;1|DDR;DDR_LOW;0;7FFFFFFF;1|DDR;DDR_HIGH;800000000;87FFFFFFF;1|FPD;DDDR_CTRL;FD070000;FD070FFF;1|LPD;Coresight;FE800000;FEFFFFFF;1|LPD;CSU_DMA;FFC80000;FFC9FFFF;1|LPD;CSU;FFCA0000;FFCAFFFF;0|LPD;CRL_APB;FF5E0000;FF85FFFF;1|FPD;CRF_APB;FD1A0000;FD2DFFFF;1|FPD;CCI_REG;FD5E0000;FD5EFFFF;1|FPD;CCI_GPV;FD6E0000;FD6EFFFF;1|LPD;CAN1;FF070000;FF07FFFF;0|LPD;CAN0;FF060000;FF06FFFF;0|FPD;APU;FD5C0000;FD5CFFFF;1|LPD;APM_INTC_IOU;FFA20000;FFA2FFFF;1|LPD;APM_FPD_LPD;FFA30000;FFA3FFFF;1|FPD;APM_5;FD490000;FD49FFFF;1|FPD;APM_0;FD0B0000;FD0BFFFF;1|LPD;APM2;FFA10000;FFA1FFFF;1|LPD;APM1;FFA00000;FFA0FFFF;1|LPD;AMS;FFA50000;FFA5FFFF;1|FPD;AFI_5;FD3B0000;FD3BFFFF;1|FPD;AFI_4;FD3A0000;FD3AFFFF;1|FPD;AFI_3;FD390000;FD39FFFF;1|FPD;AFI_2;FD380000;FD38FFFF;1|FPD;AFI_1;FD370000;FD37FFFF;1|FPD;AFI_0;FD360000;FD36FFFF;1|LPD;AFIFM6;FF9B0000;FF9BFFFF;1|FPD;ACPU_GIC;F9010000;F907FFFF;1} \
   CONFIG.PSU__PSS_REF_CLK__FREQMHZ {33.333} \
   CONFIG.PSU__QSPI_COHERENCY {0} \
   CONFIG.PSU__QSPI_ROUTE_THROUGH_FPD {0} \
   CONFIG.PSU__QSPI__GRP_FBCLK__ENABLE {1} \
   CONFIG.PSU__QSPI__GRP_FBCLK__IO {MIO 6} \
   CONFIG.PSU__QSPI__PERIPHERAL__DATA_MODE {x4} \
   CONFIG.PSU__QSPI__PERIPHERAL__ENABLE {1} \
   CONFIG.PSU__QSPI__PERIPHERAL__IO {MIO 0 .. 12} \
   CONFIG.PSU__QSPI__PERIPHERAL__MODE {Dual Parallel} \
   CONFIG.PSU__SATA__LANE0__ENABLE {0} \
   CONFIG.PSU__SATA__LANE1__ENABLE {1} \
   CONFIG.PSU__SATA__LANE1__IO {GT Lane3} \
   CONFIG.PSU__SATA__PERIPHERAL__ENABLE {1} \
   CONFIG.PSU__SATA__REF_CLK_FREQ {125} \
   CONFIG.PSU__SATA__REF_CLK_SEL {Ref Clk3} \
   CONFIG.PSU__SAXIGP0__DATA_WIDTH {128} \
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
   CONFIG.PSU__SWDT0__CLOCK__ENABLE {0} \
   CONFIG.PSU__SWDT0__PERIPHERAL__ENABLE {1} \
   CONFIG.PSU__SWDT0__RESET__ENABLE {0} \
   CONFIG.PSU__SWDT1__CLOCK__ENABLE {0} \
   CONFIG.PSU__SWDT1__PERIPHERAL__ENABLE {1} \
   CONFIG.PSU__SWDT1__RESET__ENABLE {0} \
   CONFIG.PSU__TSU__BUFG_PORT_PAIR {0} \
   CONFIG.PSU__TTC0__CLOCK__ENABLE {0} \
   CONFIG.PSU__TTC0__PERIPHERAL__ENABLE {1} \
   CONFIG.PSU__TTC0__WAVEOUT__ENABLE {0} \
   CONFIG.PSU__TTC1__CLOCK__ENABLE {0} \
   CONFIG.PSU__TTC1__PERIPHERAL__ENABLE {1} \
   CONFIG.PSU__TTC1__WAVEOUT__ENABLE {0} \
   CONFIG.PSU__TTC2__CLOCK__ENABLE {0} \
   CONFIG.PSU__TTC2__PERIPHERAL__ENABLE {1} \
   CONFIG.PSU__TTC2__WAVEOUT__ENABLE {0} \
   CONFIG.PSU__TTC3__CLOCK__ENABLE {0} \
   CONFIG.PSU__TTC3__PERIPHERAL__ENABLE {1} \
   CONFIG.PSU__TTC3__WAVEOUT__ENABLE {0} \
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
   CONFIG.PSU__USB1__RESET__ENABLE {0} \
   CONFIG.PSU__USB2_0__EMIO__ENABLE {0} \
   CONFIG.PSU__USB3_0__EMIO__ENABLE {0} \
   CONFIG.PSU__USB3_0__PERIPHERAL__ENABLE {1} \
   CONFIG.PSU__USB3_0__PERIPHERAL__IO {GT Lane2} \
   CONFIG.PSU__USB__RESET__MODE {Boot Pin} \
   CONFIG.PSU__USB__RESET__POLARITY {Active Low} \
   CONFIG.PSU__USE__IRQ0 {1} \
   CONFIG.PSU__USE__M_AXI_GP0 {1} \
   CONFIG.PSU__USE__M_AXI_GP1 {0} \
   CONFIG.PSU__USE__M_AXI_GP2 {0} \
   CONFIG.PSU__USE__S_AXI_GP0 {1} \
   CONFIG.SUBPRESET1 {Custom} \
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
  connect_bd_intf_net -intf_net axis_clock_converter_3_M_AXIS [get_bd_intf_pins axis_clk_cnvrt_gen_3/M_AXIS] [get_bd_intf_pins axis_signal_gen_v4_3/s1_axis]
  connect_bd_intf_net -intf_net axis_clock_converter_4_M_AXIS [get_bd_intf_pins axis_clk_cnvrt_gen_4/M_AXIS] [get_bd_intf_pins axis_signal_gen_v4_4/s1_axis]
  connect_bd_intf_net -intf_net axis_clock_converter_5_M_AXIS [get_bd_intf_pins axis_clk_cnvrt_gen_5/M_AXIS] [get_bd_intf_pins axis_signal_gen_v4_5/s1_axis]
  connect_bd_intf_net -intf_net axis_clock_converter_6_M_AXIS [get_bd_intf_pins axis_clk_cnvrt_gen_6/M_AXIS] [get_bd_intf_pins axis_signal_gen_v4_6/s1_axis]
  connect_bd_intf_net -intf_net axis_constant_0_m_axis [get_bd_intf_pins axis_constant_0/m_axis] [get_bd_intf_pins axis_tproc64x32_x8_0/s3_axis]
  connect_bd_intf_net -intf_net axis_constant_1_m_axis [get_bd_intf_pins axis_constant_1/m_axis] [get_bd_intf_pins axis_tproc64x32_x8_0/s4_axis]
  connect_bd_intf_net -intf_net axis_readout_v2_0_m0_axis [get_bd_intf_pins axis_readout_v2_0/m0_axis] [get_bd_intf_pins axis_terminator_0/s_axis]
  connect_bd_intf_net -intf_net axis_readout_v2_0_m1_axis [get_bd_intf_pins axis_avg_buffer_0/s_axis] [get_bd_intf_pins axis_readout_v2_0/m1_axis]
  connect_bd_intf_net -intf_net axis_readout_v2_1_m0_axis [get_bd_intf_pins axis_readout_v2_1/m0_axis] [get_bd_intf_pins axis_terminator_1/s_axis]
  connect_bd_intf_net -intf_net axis_readout_v2_1_m1_axis [get_bd_intf_pins axis_avg_buffer_1/s_axis] [get_bd_intf_pins axis_readout_v2_1/m1_axis]
  connect_bd_intf_net -intf_net axis_register_slice_0_M_AXIS [get_bd_intf_pins axis_readout_v2_0/s_axis] [get_bd_intf_pins axis_register_slice_0/M_AXIS]
  connect_bd_intf_net -intf_net axis_register_slice_1_M_AXIS [get_bd_intf_pins axis_readout_v2_1/s_axis] [get_bd_intf_pins axis_register_slice_1/M_AXIS]
  connect_bd_intf_net -intf_net axis_signal_gen_v4_0_m_axis [get_bd_intf_pins axis_signal_gen_v4_0/m_axis] [get_bd_intf_pins usp_rf_data_converter_0/s00_axis]
  connect_bd_intf_net -intf_net axis_signal_gen_v4_1_m_axis [get_bd_intf_pins axis_signal_gen_v4_1/m_axis] [get_bd_intf_pins usp_rf_data_converter_0/s01_axis]
  connect_bd_intf_net -intf_net axis_signal_gen_v4_2_m_axis [get_bd_intf_pins axis_signal_gen_v4_2/m_axis] [get_bd_intf_pins usp_rf_data_converter_0/s02_axis]
  connect_bd_intf_net -intf_net axis_signal_gen_v4_3_m_axis [get_bd_intf_pins axis_signal_gen_v4_3/m_axis] [get_bd_intf_pins usp_rf_data_converter_0/s10_axis]
  connect_bd_intf_net -intf_net axis_signal_gen_v4_4_m_axis [get_bd_intf_pins axis_signal_gen_v4_4/m_axis] [get_bd_intf_pins usp_rf_data_converter_0/s11_axis]
  connect_bd_intf_net -intf_net axis_signal_gen_v4_5_m_axis [get_bd_intf_pins axis_signal_gen_v4_5/m_axis] [get_bd_intf_pins usp_rf_data_converter_0/s12_axis]
  connect_bd_intf_net -intf_net axis_signal_gen_v4_6_m_axis [get_bd_intf_pins axis_signal_gen_v4_6/m_axis] [get_bd_intf_pins usp_rf_data_converter_0/s13_axis]
  connect_bd_intf_net -intf_net axis_switch_0_M00_AXIS [get_bd_intf_pins axis_signal_gen_v4_0/s0_axis] [get_bd_intf_pins axis_switch_gen/M00_AXIS]
  connect_bd_intf_net -intf_net axis_switch_0_M01_AXIS [get_bd_intf_pins axis_signal_gen_v4_1/s0_axis] [get_bd_intf_pins axis_switch_gen/M01_AXIS]
  connect_bd_intf_net -intf_net axis_switch_0_M02_AXIS [get_bd_intf_pins axis_signal_gen_v4_2/s0_axis] [get_bd_intf_pins axis_switch_gen/M02_AXIS]
  connect_bd_intf_net -intf_net axis_switch_0_M03_AXIS [get_bd_intf_pins axis_signal_gen_v4_3/s0_axis] [get_bd_intf_pins axis_switch_gen/M03_AXIS]
  connect_bd_intf_net -intf_net axis_switch_0_M04_AXIS [get_bd_intf_pins axis_signal_gen_v4_4/s0_axis] [get_bd_intf_pins axis_switch_gen/M04_AXIS]
  connect_bd_intf_net -intf_net axis_switch_0_M05_AXIS [get_bd_intf_pins axis_signal_gen_v4_5/s0_axis] [get_bd_intf_pins axis_switch_gen/M05_AXIS]
  connect_bd_intf_net -intf_net axis_switch_0_M06_AXIS [get_bd_intf_pins axis_signal_gen_v4_6/s0_axis] [get_bd_intf_pins axis_switch_gen/M06_AXIS]
  connect_bd_intf_net -intf_net axis_switch_avg_M00_AXIS [get_bd_intf_pins axi_dma_avg/S_AXIS_S2MM] [get_bd_intf_pins axis_switch_avg/M00_AXIS]
  connect_bd_intf_net -intf_net axis_switch_buf_M00_AXIS [get_bd_intf_pins axi_dma_buf/S_AXIS_S2MM] [get_bd_intf_pins axis_switch_buf/M00_AXIS]
  connect_bd_intf_net -intf_net axis_tproc64x32_x8_0_m0_axis [get_bd_intf_pins axi_dma_tproc/S_AXIS_S2MM] [get_bd_intf_pins axis_tproc64x32_x8_0/m0_axis]
  connect_bd_intf_net -intf_net axis_tproc64x32_x8_0_m1_axis [get_bd_intf_pins axis_set_reg_0/s_axis] [get_bd_intf_pins axis_tproc64x32_x8_0/m1_axis]
  connect_bd_intf_net -intf_net axis_tproc64x32_x8_0_m2_axis [get_bd_intf_pins axis_signal_gen_v4_0/s1_axis] [get_bd_intf_pins axis_tproc64x32_x8_0/m2_axis]
  connect_bd_intf_net -intf_net axis_tproc64x32_x8_0_m3_axis [get_bd_intf_pins axis_signal_gen_v4_1/s1_axis] [get_bd_intf_pins axis_tproc64x32_x8_0/m3_axis]
  connect_bd_intf_net -intf_net axis_tproc64x32_x8_0_m4_axis [get_bd_intf_pins axis_signal_gen_v4_2/s1_axis] [get_bd_intf_pins axis_tproc64x32_x8_0/m4_axis]
  connect_bd_intf_net -intf_net axis_tproc64x32_x8_0_m5_axis [get_bd_intf_pins axis_clk_cnvrt_gen_3/S_AXIS] [get_bd_intf_pins axis_tproc64x32_x8_0/m5_axis]
  connect_bd_intf_net -intf_net axis_tproc64x32_x8_0_m6_axis [get_bd_intf_pins axis_clk_cnvrt_gen_4/S_AXIS] [get_bd_intf_pins axis_tproc64x32_x8_0/m6_axis]
  connect_bd_intf_net -intf_net axis_tproc64x32_x8_0_m7_axis [get_bd_intf_pins axis_clk_cnvrt_gen_5/S_AXIS] [get_bd_intf_pins axis_tproc64x32_x8_0/m7_axis]
  connect_bd_intf_net -intf_net axis_tproc64x32_x8_0_m8_axis [get_bd_intf_pins axis_clk_cnvrt_gen_6/S_AXIS] [get_bd_intf_pins axis_tproc64x32_x8_0/m8_axis]
  connect_bd_intf_net -intf_net dac0_clk_1 [get_bd_intf_ports dac0_clk] [get_bd_intf_pins usp_rf_data_converter_0/dac0_clk]
  connect_bd_intf_net -intf_net dac1_clk_1 [get_bd_intf_ports dac1_clk] [get_bd_intf_pins usp_rf_data_converter_0/dac1_clk]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M00_AXI [get_bd_intf_pins axi_dma_tproc/S_AXI_LITE] [get_bd_intf_pins ps8_0_axi_periph/M00_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M01_AXI [get_bd_intf_pins axis_tproc64x32_x8_0/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M01_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M02_AXI [get_bd_intf_pins axis_signal_gen_v4_0/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M02_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M03_AXI [get_bd_intf_pins axis_signal_gen_v4_1/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M03_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M04_AXI [get_bd_intf_pins axis_signal_gen_v4_2/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M04_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M05_AXI [get_bd_intf_pins axis_signal_gen_v4_3/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M05_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M06_AXI [get_bd_intf_pins axi_dma_gen/S_AXI_LITE] [get_bd_intf_pins ps8_0_axi_periph/M06_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M07_AXI [get_bd_intf_pins axis_switch_gen/S_AXI_CTRL] [get_bd_intf_pins ps8_0_axi_periph/M07_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M08_AXI [get_bd_intf_pins ps8_0_axi_periph/M08_AXI] [get_bd_intf_pins usp_rf_data_converter_0/s_axi]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M09_AXI [get_bd_intf_pins axis_avg_buffer_0/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M09_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M10_AXI [get_bd_intf_pins axis_avg_buffer_1/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M10_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M11_AXI [get_bd_intf_pins axis_signal_gen_v4_4/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M11_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M12_AXI [get_bd_intf_pins axis_signal_gen_v4_5/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M12_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M13_AXI [get_bd_intf_pins axi_bram_ctrl_0/S_AXI] [get_bd_intf_pins ps8_0_axi_periph/M13_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M14_AXI [get_bd_intf_pins axis_signal_gen_v4_6/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M14_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M15_AXI [get_bd_intf_pins axis_readout_v2_0/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M15_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M16_AXI [get_bd_intf_pins axis_readout_v2_1/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M16_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M17_AXI [get_bd_intf_pins axis_switch_avg/S_AXI_CTRL] [get_bd_intf_pins ps8_0_axi_periph/M17_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M18_AXI [get_bd_intf_pins axis_switch_buf/S_AXI_CTRL] [get_bd_intf_pins ps8_0_axi_periph/M18_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M19_AXI [get_bd_intf_pins axi_dma_avg/S_AXI_LITE] [get_bd_intf_pins ps8_0_axi_periph/M19_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M20_AXI [get_bd_intf_pins axi_dma_buf/S_AXI_LITE] [get_bd_intf_pins ps8_0_axi_periph/M20_AXI]
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
  connect_bd_net -net axi_bram_ctrl_0_bram_doutb [get_bd_pins axi_bram_ctrl_0_bram/doutb] [get_bd_pins axis_tproc64x32_x8_0/pmem_do]
  connect_bd_net -net axis_set_reg_0_dout [get_bd_pins axis_set_reg_0/dout] [get_bd_pins vect2bits_4_0/din]
  connect_bd_net -net axis_tproc64x32_x8_0_pmem_addr [get_bd_pins axi_bram_ctrl_0_bram/addrb] [get_bd_pins axis_tproc64x32_x8_0/pmem_addr]
  connect_bd_net -net clk_adc0_x2_clk_out1 [get_bd_pins axis_avg_buffer_0/s_axis_aclk] [get_bd_pins axis_avg_buffer_1/s_axis_aclk] [get_bd_pins axis_readout_v2_0/aclk] [get_bd_pins axis_readout_v2_1/aclk] [get_bd_pins axis_register_slice_0/aclk] [get_bd_pins axis_register_slice_1/aclk] [get_bd_pins axis_terminator_0/s_axis_aclk] [get_bd_pins axis_terminator_1/s_axis_aclk] [get_bd_pins clk_adc0_x2/clk_out1] [get_bd_pins rst_adc0_x2/slowest_sync_clk] [get_bd_pins usp_rf_data_converter_0/m0_axis_aclk]
  connect_bd_net -net clk_adc0_x2_locked [get_bd_pins clk_adc0_x2/locked] [get_bd_pins rst_adc0_x2/dcm_locked]
  connect_bd_net -net rst_adc0_peripheral_reset [get_bd_pins clk_adc0_x2/reset] [get_bd_pins rst_adc0/peripheral_reset]
  connect_bd_net -net rst_adc0_x2_peripheral_aresetn [get_bd_pins axis_avg_buffer_0/s_axis_aresetn] [get_bd_pins axis_avg_buffer_1/s_axis_aresetn] [get_bd_pins axis_readout_v2_0/aresetn] [get_bd_pins axis_readout_v2_1/aresetn] [get_bd_pins axis_register_slice_0/aresetn] [get_bd_pins axis_register_slice_1/aresetn] [get_bd_pins axis_terminator_0/s_axis_aresetn] [get_bd_pins axis_terminator_1/s_axis_aresetn] [get_bd_pins rst_adc0_x2/peripheral_aresetn] [get_bd_pins usp_rf_data_converter_0/m0_axis_aresetn]
  connect_bd_net -net rst_dac0_peripheral_aresetn [get_bd_pins axis_clk_cnvrt_avg_0/m_axis_aresetn] [get_bd_pins axis_clk_cnvrt_avg_1/m_axis_aresetn] [get_bd_pins axis_clk_cnvrt_gen_3/s_axis_aresetn] [get_bd_pins axis_clk_cnvrt_gen_4/s_axis_aresetn] [get_bd_pins axis_clk_cnvrt_gen_5/s_axis_aresetn] [get_bd_pins axis_clk_cnvrt_gen_6/s_axis_aresetn] [get_bd_pins axis_constant_0/m_axis_aresetn] [get_bd_pins axis_constant_1/m_axis_aresetn] [get_bd_pins axis_set_reg_0/s_axis_aresetn] [get_bd_pins axis_signal_gen_v4_0/aresetn] [get_bd_pins axis_signal_gen_v4_1/aresetn] [get_bd_pins axis_signal_gen_v4_2/aresetn] [get_bd_pins axis_tproc64x32_x8_0/aresetn] [get_bd_pins rst_dac0/peripheral_aresetn] [get_bd_pins system_ila_1/resetn] [get_bd_pins usp_rf_data_converter_0/s0_axis_aresetn]
  connect_bd_net -net rst_dac1_peripheral_aresetn [get_bd_pins axis_clk_cnvrt_gen_3/m_axis_aresetn] [get_bd_pins axis_clk_cnvrt_gen_4/m_axis_aresetn] [get_bd_pins axis_clk_cnvrt_gen_5/m_axis_aresetn] [get_bd_pins axis_clk_cnvrt_gen_6/m_axis_aresetn] [get_bd_pins axis_signal_gen_v4_3/aresetn] [get_bd_pins axis_signal_gen_v4_4/aresetn] [get_bd_pins axis_signal_gen_v4_5/aresetn] [get_bd_pins axis_signal_gen_v4_6/aresetn] [get_bd_pins rst_dac1/peripheral_aresetn] [get_bd_pins usp_rf_data_converter_0/s1_axis_aresetn]
  connect_bd_net -net rst_ps8_0_99M_peripheral_aresetn [get_bd_pins axi_bram_ctrl_0/s_axi_aresetn] [get_bd_pins axi_dma_avg/axi_resetn] [get_bd_pins axi_dma_buf/axi_resetn] [get_bd_pins axi_dma_gen/axi_resetn] [get_bd_pins axi_dma_tproc/axi_resetn] [get_bd_pins axi_smc/aresetn] [get_bd_pins axis_avg_buffer_0/m_axis_aresetn] [get_bd_pins axis_avg_buffer_0/s_axi_aresetn] [get_bd_pins axis_avg_buffer_1/m_axis_aresetn] [get_bd_pins axis_avg_buffer_1/s_axi_aresetn] [get_bd_pins axis_clk_cnvrt_avg_0/s_axis_aresetn] [get_bd_pins axis_clk_cnvrt_avg_1/s_axis_aresetn] [get_bd_pins axis_readout_v2_0/s_axi_aresetn] [get_bd_pins axis_readout_v2_1/s_axi_aresetn] [get_bd_pins axis_signal_gen_v4_0/s0_axis_aresetn] [get_bd_pins axis_signal_gen_v4_0/s_axi_aresetn] [get_bd_pins axis_signal_gen_v4_1/s0_axis_aresetn] [get_bd_pins axis_signal_gen_v4_1/s_axi_aresetn] [get_bd_pins axis_signal_gen_v4_2/s0_axis_aresetn] [get_bd_pins axis_signal_gen_v4_2/s_axi_aresetn] [get_bd_pins axis_signal_gen_v4_3/s0_axis_aresetn] [get_bd_pins axis_signal_gen_v4_3/s_axi_aresetn] [get_bd_pins axis_signal_gen_v4_4/s0_axis_aresetn] [get_bd_pins axis_signal_gen_v4_4/s_axi_aresetn] [get_bd_pins axis_signal_gen_v4_5/s0_axis_aresetn] [get_bd_pins axis_signal_gen_v4_5/s_axi_aresetn] [get_bd_pins axis_signal_gen_v4_6/s0_axis_aresetn] [get_bd_pins axis_signal_gen_v4_6/s_axi_aresetn] [get_bd_pins axis_switch_avg/aresetn] [get_bd_pins axis_switch_avg/s_axi_ctrl_aresetn] [get_bd_pins axis_switch_buf/aresetn] [get_bd_pins axis_switch_buf/s_axi_ctrl_aresetn] [get_bd_pins axis_switch_gen/aresetn] [get_bd_pins axis_switch_gen/s_axi_ctrl_aresetn] [get_bd_pins axis_tproc64x32_x8_0/m0_axis_aresetn] [get_bd_pins axis_tproc64x32_x8_0/s0_axis_aresetn] [get_bd_pins axis_tproc64x32_x8_0/s_axi_aresetn] [get_bd_pins ps8_0_axi_periph/ARESETN] [get_bd_pins ps8_0_axi_periph/M00_ARESETN] [get_bd_pins ps8_0_axi_periph/M01_ARESETN] [get_bd_pins ps8_0_axi_periph/M02_ARESETN] [get_bd_pins ps8_0_axi_periph/M03_ARESETN] [get_bd_pins ps8_0_axi_periph/M04_ARESETN] [get_bd_pins ps8_0_axi_periph/M05_ARESETN] [get_bd_pins ps8_0_axi_periph/M06_ARESETN] [get_bd_pins ps8_0_axi_periph/M07_ARESETN] [get_bd_pins ps8_0_axi_periph/M08_ARESETN] [get_bd_pins ps8_0_axi_periph/M09_ARESETN] [get_bd_pins ps8_0_axi_periph/M10_ARESETN] [get_bd_pins ps8_0_axi_periph/M11_ARESETN] [get_bd_pins ps8_0_axi_periph/M12_ARESETN] [get_bd_pins ps8_0_axi_periph/M13_ARESETN] [get_bd_pins ps8_0_axi_periph/M14_ARESETN] [get_bd_pins ps8_0_axi_periph/M15_ARESETN] [get_bd_pins ps8_0_axi_periph/M16_ARESETN] [get_bd_pins ps8_0_axi_periph/M17_ARESETN] [get_bd_pins ps8_0_axi_periph/M18_ARESETN] [get_bd_pins ps8_0_axi_periph/M19_ARESETN] [get_bd_pins ps8_0_axi_periph/M20_ARESETN] [get_bd_pins ps8_0_axi_periph/S00_ARESETN] [get_bd_pins rst_100/peripheral_aresetn] [get_bd_pins system_ila_0/resetn] [get_bd_pins usp_rf_data_converter_0/s_axi_aresetn]
  connect_bd_net -net usp_rf_data_converter_0_clk_adc0 [get_bd_pins clk_adc0_x2/clk_in1] [get_bd_pins rst_adc0/slowest_sync_clk] [get_bd_pins usp_rf_data_converter_0/clk_adc0]
  connect_bd_net -net usp_rf_data_converter_0_clk_dac0 [get_bd_pins axi_bram_ctrl_0_bram/clkb] [get_bd_pins axis_clk_cnvrt_avg_0/m_axis_aclk] [get_bd_pins axis_clk_cnvrt_avg_1/m_axis_aclk] [get_bd_pins axis_clk_cnvrt_gen_3/s_axis_aclk] [get_bd_pins axis_clk_cnvrt_gen_4/s_axis_aclk] [get_bd_pins axis_clk_cnvrt_gen_5/s_axis_aclk] [get_bd_pins axis_clk_cnvrt_gen_6/s_axis_aclk] [get_bd_pins axis_constant_0/m_axis_aclk] [get_bd_pins axis_constant_1/m_axis_aclk] [get_bd_pins axis_set_reg_0/s_axis_aclk] [get_bd_pins axis_signal_gen_v4_0/aclk] [get_bd_pins axis_signal_gen_v4_1/aclk] [get_bd_pins axis_signal_gen_v4_2/aclk] [get_bd_pins axis_tproc64x32_x8_0/aclk] [get_bd_pins rst_dac0/slowest_sync_clk] [get_bd_pins system_ila_1/clk] [get_bd_pins usp_rf_data_converter_0/clk_dac0] [get_bd_pins usp_rf_data_converter_0/s0_axis_aclk]
  connect_bd_net -net usp_rf_data_converter_0_clk_dac1 [get_bd_pins axis_clk_cnvrt_gen_3/m_axis_aclk] [get_bd_pins axis_clk_cnvrt_gen_4/m_axis_aclk] [get_bd_pins axis_clk_cnvrt_gen_5/m_axis_aclk] [get_bd_pins axis_clk_cnvrt_gen_6/m_axis_aclk] [get_bd_pins axis_signal_gen_v4_3/aclk] [get_bd_pins axis_signal_gen_v4_4/aclk] [get_bd_pins axis_signal_gen_v4_5/aclk] [get_bd_pins axis_signal_gen_v4_6/aclk] [get_bd_pins rst_dac1/slowest_sync_clk] [get_bd_pins usp_rf_data_converter_0/clk_dac1] [get_bd_pins usp_rf_data_converter_0/s1_axis_aclk]
  connect_bd_net -net vect2bits_4_0_dout0 [get_bd_ports PMOD0_0_LS] [get_bd_pins vect2bits_4_0/dout0]
  connect_bd_net -net vect2bits_4_0_dout1 [get_bd_ports PMOD0_1_LS] [get_bd_pins vect2bits_4_0/dout1]
  connect_bd_net -net vect2bits_4_0_dout2 [get_bd_ports PMOD0_2_LS] [get_bd_pins vect2bits_4_0/dout2]
  connect_bd_net -net vect2bits_4_0_dout3 [get_bd_ports PMOD0_3_LS] [get_bd_pins vect2bits_4_0/dout3]
  connect_bd_net -net vect2bits_4_0_dout14 [get_bd_pins axis_avg_buffer_0/trigger] [get_bd_pins system_ila_0/probe0] [get_bd_pins system_ila_1/probe0] [get_bd_pins vect2bits_4_0/dout14]
  connect_bd_net -net vect2bits_4_0_dout15 [get_bd_pins axis_avg_buffer_1/trigger] [get_bd_pins vect2bits_4_0/dout15]
  connect_bd_net -net xlconstant_0_dout [get_bd_pins axi_bram_ctrl_0_bram/dinb] [get_bd_pins xlconstant_0/dout]
  connect_bd_net -net xlconstant_1_dout [get_bd_pins axi_bram_ctrl_0_bram/enb] [get_bd_pins xlconstant_1/dout]
  connect_bd_net -net xlconstant_2_dout [get_bd_pins axi_bram_ctrl_0_bram/rstb] [get_bd_pins axis_tproc64x32_x8_0/start] [get_bd_pins xlconstant_2/dout]
  connect_bd_net -net xlconstant_3_dout [get_bd_pins axi_bram_ctrl_0_bram/web] [get_bd_pins xlconstant_3/dout]
  connect_bd_net -net zynq_ultra_ps_e_0_pl_clk0 [get_bd_pins axi_bram_ctrl_0/s_axi_aclk] [get_bd_pins axi_dma_avg/m_axi_s2mm_aclk] [get_bd_pins axi_dma_avg/s_axi_lite_aclk] [get_bd_pins axi_dma_buf/m_axi_s2mm_aclk] [get_bd_pins axi_dma_buf/s_axi_lite_aclk] [get_bd_pins axi_dma_gen/m_axi_mm2s_aclk] [get_bd_pins axi_dma_gen/s_axi_lite_aclk] [get_bd_pins axi_dma_tproc/m_axi_mm2s_aclk] [get_bd_pins axi_dma_tproc/m_axi_s2mm_aclk] [get_bd_pins axi_dma_tproc/s_axi_lite_aclk] [get_bd_pins axi_smc/aclk] [get_bd_pins axis_avg_buffer_0/m_axis_aclk] [get_bd_pins axis_avg_buffer_0/s_axi_aclk] [get_bd_pins axis_avg_buffer_1/m_axis_aclk] [get_bd_pins axis_avg_buffer_1/s_axi_aclk] [get_bd_pins axis_clk_cnvrt_avg_0/s_axis_aclk] [get_bd_pins axis_clk_cnvrt_avg_1/s_axis_aclk] [get_bd_pins axis_readout_v2_0/s_axi_aclk] [get_bd_pins axis_readout_v2_1/s_axi_aclk] [get_bd_pins axis_signal_gen_v4_0/s0_axis_aclk] [get_bd_pins axis_signal_gen_v4_0/s_axi_aclk] [get_bd_pins axis_signal_gen_v4_1/s0_axis_aclk] [get_bd_pins axis_signal_gen_v4_1/s_axi_aclk] [get_bd_pins axis_signal_gen_v4_2/s0_axis_aclk] [get_bd_pins axis_signal_gen_v4_2/s_axi_aclk] [get_bd_pins axis_signal_gen_v4_3/s0_axis_aclk] [get_bd_pins axis_signal_gen_v4_3/s_axi_aclk] [get_bd_pins axis_signal_gen_v4_4/s0_axis_aclk] [get_bd_pins axis_signal_gen_v4_4/s_axi_aclk] [get_bd_pins axis_signal_gen_v4_5/s0_axis_aclk] [get_bd_pins axis_signal_gen_v4_5/s_axi_aclk] [get_bd_pins axis_signal_gen_v4_6/s0_axis_aclk] [get_bd_pins axis_signal_gen_v4_6/s_axi_aclk] [get_bd_pins axis_switch_avg/aclk] [get_bd_pins axis_switch_avg/s_axi_ctrl_aclk] [get_bd_pins axis_switch_buf/aclk] [get_bd_pins axis_switch_buf/s_axi_ctrl_aclk] [get_bd_pins axis_switch_gen/aclk] [get_bd_pins axis_switch_gen/s_axi_ctrl_aclk] [get_bd_pins axis_tproc64x32_x8_0/m0_axis_aclk] [get_bd_pins axis_tproc64x32_x8_0/s0_axis_aclk] [get_bd_pins axis_tproc64x32_x8_0/s_axi_aclk] [get_bd_pins ps8_0_axi_periph/ACLK] [get_bd_pins ps8_0_axi_periph/M00_ACLK] [get_bd_pins ps8_0_axi_periph/M01_ACLK] [get_bd_pins ps8_0_axi_periph/M02_ACLK] [get_bd_pins ps8_0_axi_periph/M03_ACLK] [get_bd_pins ps8_0_axi_periph/M04_ACLK] [get_bd_pins ps8_0_axi_periph/M05_ACLK] [get_bd_pins ps8_0_axi_periph/M06_ACLK] [get_bd_pins ps8_0_axi_periph/M07_ACLK] [get_bd_pins ps8_0_axi_periph/M08_ACLK] [get_bd_pins ps8_0_axi_periph/M09_ACLK] [get_bd_pins ps8_0_axi_periph/M10_ACLK] [get_bd_pins ps8_0_axi_periph/M11_ACLK] [get_bd_pins ps8_0_axi_periph/M12_ACLK] [get_bd_pins ps8_0_axi_periph/M13_ACLK] [get_bd_pins ps8_0_axi_periph/M14_ACLK] [get_bd_pins ps8_0_axi_periph/M15_ACLK] [get_bd_pins ps8_0_axi_periph/M16_ACLK] [get_bd_pins ps8_0_axi_periph/M17_ACLK] [get_bd_pins ps8_0_axi_periph/M18_ACLK] [get_bd_pins ps8_0_axi_periph/M19_ACLK] [get_bd_pins ps8_0_axi_periph/M20_ACLK] [get_bd_pins ps8_0_axi_periph/S00_ACLK] [get_bd_pins rst_100/slowest_sync_clk] [get_bd_pins system_ila_0/clk] [get_bd_pins usp_rf_data_converter_0/s_axi_aclk] [get_bd_pins zynq_ultra_ps_e_0/maxihpm0_fpd_aclk] [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] [get_bd_pins zynq_ultra_ps_e_0/saxihpc0_fpd_aclk]
  connect_bd_net -net zynq_ultra_ps_e_0_pl_resetn0 [get_bd_pins rst_100/ext_reset_in] [get_bd_pins rst_adc0/ext_reset_in] [get_bd_pins rst_adc0_x2/ext_reset_in] [get_bd_pins rst_dac0/ext_reset_in] [get_bd_pins rst_dac1/ext_reset_in] [get_bd_pins zynq_ultra_ps_e_0/pl_resetn0]

  # Create address segments
  create_bd_addr_seg -range 0x80000000 -offset 0x00000000 [get_bd_addr_spaces axi_dma_avg/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_DDR_LOW] SEG_zynq_ultra_ps_e_0_HPC0_DDR_LOW
  create_bd_addr_seg -range 0x20000000 -offset 0xC0000000 [get_bd_addr_spaces axi_dma_avg/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_QSPI] SEG_zynq_ultra_ps_e_0_HPC0_QSPI
  create_bd_addr_seg -range 0x80000000 -offset 0x00000000 [get_bd_addr_spaces axi_dma_buf/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_DDR_LOW] SEG_zynq_ultra_ps_e_0_HPC0_DDR_LOW
  create_bd_addr_seg -range 0x20000000 -offset 0xC0000000 [get_bd_addr_spaces axi_dma_buf/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_QSPI] SEG_zynq_ultra_ps_e_0_HPC0_QSPI
  create_bd_addr_seg -range 0x80000000 -offset 0x00000000 [get_bd_addr_spaces axi_dma_gen/Data_MM2S] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_DDR_LOW] SEG_zynq_ultra_ps_e_0_HPC0_DDR_LOW
  create_bd_addr_seg -range 0x20000000 -offset 0xC0000000 [get_bd_addr_spaces axi_dma_gen/Data_MM2S] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_QSPI] SEG_zynq_ultra_ps_e_0_HPC0_QSPI
  create_bd_addr_seg -range 0x80000000 -offset 0x00000000 [get_bd_addr_spaces axi_dma_tproc/Data_MM2S] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_DDR_LOW] SEG_zynq_ultra_ps_e_0_HPC0_DDR_LOW
  create_bd_addr_seg -range 0x80000000 -offset 0x00000000 [get_bd_addr_spaces axi_dma_tproc/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_DDR_LOW] SEG_zynq_ultra_ps_e_0_HPC0_DDR_LOW
  create_bd_addr_seg -range 0x20000000 -offset 0xC0000000 [get_bd_addr_spaces axi_dma_tproc/Data_MM2S] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_QSPI] SEG_zynq_ultra_ps_e_0_HPC0_QSPI
  create_bd_addr_seg -range 0x20000000 -offset 0xC0000000 [get_bd_addr_spaces axi_dma_tproc/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_QSPI] SEG_zynq_ultra_ps_e_0_HPC0_QSPI
  create_bd_addr_seg -range 0x00010000 -offset 0xA0000000 [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axi_bram_ctrl_0/S_AXI/Mem0] SEG_axi_bram_ctrl_0_Mem0
  create_bd_addr_seg -range 0x00001000 -offset 0xA0040000 [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axi_dma_avg/S_AXI_LITE/Reg] SEG_axi_dma_avg_Reg
  create_bd_addr_seg -range 0x00001000 -offset 0xA0041000 [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axi_dma_buf/S_AXI_LITE/Reg] SEG_axi_dma_buf_Reg
  create_bd_addr_seg -range 0x00001000 -offset 0xA0042000 [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axi_dma_gen/S_AXI_LITE/Reg] SEG_axi_dma_gen_Reg
  create_bd_addr_seg -range 0x00001000 -offset 0xA0043000 [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axi_dma_tproc/S_AXI_LITE/Reg] SEG_axi_dma_tproc_Reg
  create_bd_addr_seg -range 0x00001000 -offset 0xA0044000 [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_avg_buffer_0/s_axi/reg0] SEG_axis_avg_buffer_0_reg0
  create_bd_addr_seg -range 0x00001000 -offset 0xA0045000 [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_avg_buffer_1/s_axi/reg0] SEG_axis_avg_buffer_1_reg0
  create_bd_addr_seg -range 0x00001000 -offset 0xA0046000 [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_readout_v2_0/s_axi/reg0] SEG_axis_readout_v2_0_reg0
  create_bd_addr_seg -range 0x00001000 -offset 0xA0047000 [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_readout_v2_1/s_axi/reg0] SEG_axis_readout_v2_1_reg0
  create_bd_addr_seg -range 0x00001000 -offset 0xA0048000 [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_signal_gen_v4_0/s_axi/reg0] SEG_axis_signal_gen_v4_0_reg0
  create_bd_addr_seg -range 0x00001000 -offset 0xA0049000 [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_signal_gen_v4_1/s_axi/reg0] SEG_axis_signal_gen_v4_1_reg0
  create_bd_addr_seg -range 0x00001000 -offset 0xA004A000 [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_signal_gen_v4_2/s_axi/reg0] SEG_axis_signal_gen_v4_2_reg0
  create_bd_addr_seg -range 0x00001000 -offset 0xA004B000 [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_signal_gen_v4_3/s_axi/reg0] SEG_axis_signal_gen_v4_3_reg0
  create_bd_addr_seg -range 0x00001000 -offset 0xA004C000 [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_signal_gen_v4_4/s_axi/reg0] SEG_axis_signal_gen_v4_4_reg0
  create_bd_addr_seg -range 0x00001000 -offset 0xA004D000 [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_signal_gen_v4_5/s_axi/reg0] SEG_axis_signal_gen_v4_5_reg0
  create_bd_addr_seg -range 0x00001000 -offset 0xA004E000 [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_signal_gen_v4_6/s_axi/reg0] SEG_axis_signal_gen_v4_6_reg0
  create_bd_addr_seg -range 0x00001000 -offset 0xA004F000 [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_switch_avg/S_AXI_CTRL/Reg] SEG_axis_switch_avg_Reg
  create_bd_addr_seg -range 0x00001000 -offset 0xA0050000 [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_switch_buf/S_AXI_CTRL/Reg] SEG_axis_switch_buf_Reg
  create_bd_addr_seg -range 0x00001000 -offset 0xA0051000 [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_switch_gen/S_AXI_CTRL/Reg] SEG_axis_switch_gen_Reg
  create_bd_addr_seg -range 0x000100000000 -offset 0x000400000000 [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_tproc64x32_x8_0/s_axi/reg0] SEG_axis_tproc64x32_x8_0_reg0
  create_bd_addr_seg -range 0x00040000 -offset 0xA0080000 [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs usp_rf_data_converter_0/s_axi/Reg] SEG_usp_rf_data_converter_0_Reg

  # Exclude Address Segments
  create_bd_addr_seg -range 0x01000000 -offset 0xFF000000 [get_bd_addr_spaces axi_dma_avg/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_LPS_OCM] SEG_zynq_ultra_ps_e_0_HPC0_LPS_OCM
  exclude_bd_addr_seg [get_bd_addr_segs axi_dma_avg/Data_S2MM/SEG_zynq_ultra_ps_e_0_HPC0_LPS_OCM]

  create_bd_addr_seg -range 0x01000000 -offset 0xFF000000 [get_bd_addr_spaces axi_dma_buf/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_LPS_OCM] SEG_zynq_ultra_ps_e_0_HPC0_LPS_OCM
  exclude_bd_addr_seg [get_bd_addr_segs axi_dma_buf/Data_S2MM/SEG_zynq_ultra_ps_e_0_HPC0_LPS_OCM]

  create_bd_addr_seg -range 0x01000000 -offset 0xFF000000 [get_bd_addr_spaces axi_dma_gen/Data_MM2S] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_LPS_OCM] SEG_zynq_ultra_ps_e_0_HPC0_LPS_OCM
  exclude_bd_addr_seg [get_bd_addr_segs axi_dma_gen/Data_MM2S/SEG_zynq_ultra_ps_e_0_HPC0_LPS_OCM]

  create_bd_addr_seg -range 0x01000000 -offset 0xFF000000 [get_bd_addr_spaces axi_dma_tproc/Data_MM2S] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_LPS_OCM] SEG_zynq_ultra_ps_e_0_HPC0_LPS_OCM
  exclude_bd_addr_seg [get_bd_addr_segs axi_dma_tproc/Data_MM2S/SEG_zynq_ultra_ps_e_0_HPC0_LPS_OCM]

  create_bd_addr_seg -range 0x01000000 -offset 0xFF000000 [get_bd_addr_spaces axi_dma_tproc/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_LPS_OCM] SEG_zynq_ultra_ps_e_0_HPC0_LPS_OCM
  exclude_bd_addr_seg [get_bd_addr_segs axi_dma_tproc/Data_S2MM/SEG_zynq_ultra_ps_e_0_HPC0_LPS_OCM]


  # Perform GUI Layout
  regenerate_bd_layout -layout_string {
   "ExpandedHierarchyInLayout":"",
   "guistr":"# # String gsaved with Nlview 7.0.19  2019-03-26 bk=1.5019 VDI=41 GEI=35 GUI=JA:9.0 TLS
#  -string -flagsOSRD
preplace port adc0_clk -pg 1 -lvl 9 -x 2750 -y 940 -defaultsOSRD -right
preplace port dac0_clk -pg 1 -lvl 9 -x 2750 -y 980 -defaultsOSRD -right
preplace port dac1_clk -pg 1 -lvl 9 -x 2750 -y 960 -defaultsOSRD -right
preplace port sysref_in -pg 1 -lvl 9 -x 2750 -y 920 -defaultsOSRD -right
preplace port vin0 -pg 1 -lvl 9 -x 2750 -y 840 -defaultsOSRD -right
preplace port vin1 -pg 1 -lvl 9 -x 2750 -y 860 -defaultsOSRD -right
preplace port vout0 -pg 1 -lvl 9 -x 2750 -y 490 -defaultsOSRD
preplace port vout1 -pg 1 -lvl 9 -x 2750 -y 510 -defaultsOSRD
preplace port vout2 -pg 1 -lvl 9 -x 2750 -y 530 -defaultsOSRD
preplace port vout3 -pg 1 -lvl 9 -x 2750 -y 550 -defaultsOSRD
preplace port vout4 -pg 1 -lvl 9 -x 2750 -y 570 -defaultsOSRD
preplace port vout5 -pg 1 -lvl 9 -x 2750 -y 590 -defaultsOSRD
preplace port vout6 -pg 1 -lvl 9 -x 2750 -y 610 -defaultsOSRD
preplace port PMOD0_0_LS -pg 1 -lvl 9 -x 2750 -y 100 -defaultsOSRD
preplace port PMOD0_1_LS -pg 1 -lvl 9 -x 2750 -y 120 -defaultsOSRD
preplace port PMOD0_2_LS -pg 1 -lvl 9 -x 2750 -y 140 -defaultsOSRD
preplace port PMOD0_3_LS -pg 1 -lvl 9 -x 2750 -y 160 -defaultsOSRD
preplace inst axi_bram_ctrl_0 -pg 1 -lvl 1 -x -940 -y 530 -defaultsOSRD
preplace inst axi_bram_ctrl_0_bram -pg 1 -lvl 2 -x -490 -y 850 -defaultsOSRD
preplace inst axi_dma_avg -pg 1 -lvl 2 -x -490 -y -1060 -defaultsOSRD
preplace inst axi_dma_buf -pg 1 -lvl 2 -x -490 -y -840 -defaultsOSRD -resize 320 156
preplace inst axi_dma_gen -pg 1 -lvl 2 -x -490 -y -540 -defaultsOSRD
preplace inst axi_dma_tproc -pg 1 -lvl 2 -x -490 -y -200 -defaultsOSRD
preplace inst axi_smc -pg 1 -lvl 2 -x -490 -y -3260 -defaultsOSRD
preplace inst axis_clk_cnvrt_avg_0 -pg 1 -lvl 7 -x 2120 -y 2870 -defaultsOSRD
preplace inst axis_clk_cnvrt_avg_1 -pg 1 -lvl 7 -x 2120 -y 3750 -defaultsOSRD -resize 220 156
preplace inst axis_clk_cnvrt_gen_3 -pg 1 -lvl 3 -x 160 -y 1220 -defaultsOSRD
preplace inst axis_clk_cnvrt_gen_4 -pg 1 -lvl 3 -x 160 -y 1480 -defaultsOSRD -resize 220 156
preplace inst axis_clk_cnvrt_gen_5 -pg 1 -lvl 3 -x 160 -y 1740 -defaultsOSRD -resize 220 156
preplace inst axis_clk_cnvrt_gen_6 -pg 1 -lvl 3 -x 160 -y 2000 -defaultsOSRD -resize 220 156
preplace inst axis_register_slice_0 -pg 1 -lvl 4 -x 660 -y 2690 -defaultsOSRD
preplace inst axis_register_slice_1 -pg 1 -lvl 4 -x 660 -y 3570 -defaultsOSRD -resize 180 116
preplace inst axis_switch_avg -pg 1 -lvl 7 -x 2120 -y 3100 -defaultsOSRD
preplace inst axis_switch_buf -pg 1 -lvl 7 -x 2120 -y 3320 -defaultsOSRD -resize 240 196
preplace inst axis_switch_gen -pg 1 -lvl 3 -x 160 -y -500 -defaultsOSRD
preplace inst clk_adc0_x2 -pg 1 -lvl 3 -x 160 -y -1580 -defaultsOSRD
preplace inst ps8_0_axi_periph -pg 1 -lvl 5 -x 1170 -y -3230 -defaultsOSRD
preplace inst rst_100 -pg 1 -lvl 3 -x 160 -y -2540 -defaultsOSRD
preplace inst rst_adc0 -pg 1 -lvl 3 -x 160 -y -2360 -defaultsOSRD -resize 320 156
preplace inst rst_adc0_x2 -pg 1 -lvl 3 -x 160 -y -2180 -defaultsOSRD -resize 320 156
preplace inst rst_dac0 -pg 1 -lvl 3 -x 160 -y -2000 -defaultsOSRD -resize 320 156
preplace inst rst_dac1 -pg 1 -lvl 3 -x 160 -y -1820 -defaultsOSRD -resize 320 156
preplace inst usp_rf_data_converter_0 -pg 1 -lvl 8 -x 2550 -y 570 -defaultsOSRD
preplace inst vect2bits_4_0 -pg 1 -lvl 7 -x 2120 -y 150 -defaultsOSRD
preplace inst xlconstant_0 -pg 1 -lvl 1 -x -940 -y 820 -defaultsOSRD
preplace inst xlconstant_1 -pg 1 -lvl 1 -x -940 -y 930 -defaultsOSRD -resize 140 88
preplace inst xlconstant_2 -pg 1 -lvl 1 -x -940 -y 1050 -defaultsOSRD -resize 140 88
preplace inst xlconstant_3 -pg 1 -lvl 1 -x -940 -y 1160 -defaultsOSRD -resize 140 88
preplace inst zynq_ultra_ps_e_0 -pg 1 -lvl 3 -x 160 -y -3090 -defaultsOSRD
preplace inst axis_constant_0 -pg 1 -lvl 1 -x -940 -y 10 -defaultsOSRD
preplace inst axis_constant_1 -pg 1 -lvl 1 -x -940 -y 130 -defaultsOSRD -resize 220 96
preplace inst axis_set_reg_0 -pg 1 -lvl 5 -x 1170 -y 150 -defaultsOSRD
preplace inst axis_terminator_0 -pg 1 -lvl 6 -x 1680 -y 2430 -defaultsOSRD
preplace inst axis_terminator_1 -pg 1 -lvl 6 -x 1680 -y 3570 -defaultsOSRD -resize 160 116
preplace inst axis_tproc64x32_x8_0 -pg 1 -lvl 2 -x -490 -y 200 -defaultsOSRD
preplace inst system_ila_1 -pg 1 -lvl 7 -x 2120 -y 4230 -defaultsOSRD -resize 157 152
preplace inst system_ila_0 -pg 1 -lvl 7 -x 2120 -y 4030 -defaultsOSRD -resize 157 152
preplace inst axis_avg_buffer_0 -pg 1 -lvl 6 -x 1680 -y 2910 -defaultsOSRD
preplace inst axis_avg_buffer_1 -pg 1 -lvl 6 -x 1680 -y 3790 -defaultsOSRD -resize 220 236
preplace inst axis_signal_gen_v4_0 -pg 1 -lvl 5 -x 1170 -y 500 -defaultsOSRD
preplace inst axis_signal_gen_v4_1 -pg 1 -lvl 5 -x 1170 -y 760 -defaultsOSRD -resize 220 236
preplace inst axis_signal_gen_v4_2 -pg 1 -lvl 5 -x 1170 -y 1020 -defaultsOSRD -resize 220 236
preplace inst axis_signal_gen_v4_3 -pg 1 -lvl 5 -x 1170 -y 1280 -defaultsOSRD -resize 220 236
preplace inst axis_signal_gen_v4_4 -pg 1 -lvl 5 -x 1170 -y 1540 -defaultsOSRD -resize 220 236
preplace inst axis_signal_gen_v4_5 -pg 1 -lvl 5 -x 1170 -y 1800 -defaultsOSRD -resize 220 236
preplace inst axis_signal_gen_v4_6 -pg 1 -lvl 5 -x 1170 -y 2060 -defaultsOSRD -resize 220 236
preplace inst axis_readout_v2_0 -pg 1 -lvl 5 -x 1170 -y 2740 -defaultsOSRD
preplace inst axis_readout_v2_1 -pg 1 -lvl 5 -x 1170 -y 3620 -defaultsOSRD
preplace netloc axi_bram_ctrl_0_bram_doutb 1 1 1 -720 350n
preplace netloc axis_set_reg_0_dout 1 5 2 N 150 N
preplace netloc axis_tproc64x32_x8_0_pmem_addr 1 1 2 -710 410 -310
preplace netloc clk_adc0_x2_clk_out1 1 2 6 -170 -1670 510 2600 780 2600 1490 700 N 700 N
preplace netloc clk_adc0_x2_locked 1 2 2 -180 -2650 480
preplace netloc rst_adc0_peripheral_reset 1 2 2 -200 -2640 470
preplace netloc rst_adc0_x2_peripheral_aresetn 1 3 5 520 2610 770 2610 1470 680 NJ 680 NJ
preplace netloc rst_dac0_peripheral_aresetn 1 0 8 -1250 200 -750 -10 -270J -10 500 -10 820 330 NJ 330 1810J 720 N
preplace netloc rst_dac1_peripheral_aresetn 1 2 6 -170 340 490 340 870 340 NJ 340 NJ 340 2310J
preplace netloc rst_ps8_0_99M_peripheral_aresetn 1 0 8 -1250 270 -770 -1690 -230 -2660 520J -2660 790 2890 1340 3070 1880 660 N
preplace netloc usp_rf_data_converter_0_clk_adc0 1 2 7 -190 -1650 NJ -1650 810 -2650 NJ -2650 1880J -640 NJ -640 2730
preplace netloc usp_rf_data_converter_0_clk_dac0 1 0 9 -1260 -60 -780 -40 -250 210 NJ 210 920 350 NJ 350 1830J 350 2340J 290 2720
preplace netloc usp_rf_data_converter_0_clk_dac1 1 2 7 -220 360 NJ 360 860 360 NJ 360 NJ 360 2320J 300 2710
preplace netloc vect2bits_4_0_dout0 1 7 2 N 100 N
preplace netloc vect2bits_4_0_dout1 1 7 2 N 120 N
preplace netloc vect2bits_4_0_dout2 1 7 2 N 140 N
preplace netloc vect2bits_4_0_dout3 1 7 2 N 160 N
preplace netloc vect2bits_4_0_dout14 1 5 3 1510 3060 1840J 2980 2270
preplace netloc vect2bits_4_0_dout15 1 5 3 1500 290 NJ 290 2260
preplace netloc xlconstant_0_dout 1 1 1 -800 820n
preplace netloc xlconstant_1_dout 1 1 1 -770 890n
preplace netloc xlconstant_2_dout 1 1 1 -790 330n
preplace netloc xlconstant_3_dout 1 1 1 -750 930n
preplace netloc zynq_ultra_ps_e_0_pl_clk0 1 0 8 -1260 250 -800 -1700 -240 -3180 480 -3110 880 2870 1460 3080 1870 640 N
preplace netloc zynq_ultra_ps_e_0_pl_resetn0 1 2 2 -210 -2780 470
preplace netloc axis_clock_converter_6_M_AXIS 1 3 2 N 2000 N
preplace netloc usp_rf_data_converter_0_vout11 1 8 1 N 570
preplace netloc axi_smc_M00_AXI 1 2 1 -250 -3260n
preplace netloc axis_avg_buffer_1_m0_axis 1 6 1 1850 3060n
preplace netloc usp_rf_data_converter_0_vout13 1 8 1 N 610
preplace netloc axis_avg_buffer_0_m2_axis 1 6 1 1920 2830n
preplace netloc ps8_0_axi_periph_M18_AXI 1 5 2 NJ -3070 1860
preplace netloc axis_clock_converter_3_M_AXIS 1 3 2 N 1220 N
preplace netloc ps8_0_axi_periph_M10_AXI 1 5 1 1430 -3230n
preplace netloc ps8_0_axi_periph_M12_AXI 1 4 2 980 -2710 1370
preplace netloc axi_dma_0_M_AXI_S2MM 1 1 2 -710 -3380 -280J
preplace netloc axis_avg_buffer_0_m0_axis 1 6 1 1850 2890n
preplace netloc vin0_1 1 7 2 2380J 840 N
preplace netloc axis_constant_0_m_axis 1 1 1 -760 10n
preplace netloc axi_dma_avg_M_AXI_S2MM 1 1 2 -720 -3140 -290
preplace netloc usp_rf_data_converter_0_vout01 1 8 1 N 510
preplace netloc axis_avg_buffer_0_m1_axis 1 6 1 1820 2910n
preplace netloc usp_rf_data_converter_0_vout02 1 8 1 N 530
preplace netloc axis_avg_buffer_1_m2_axis 1 6 1 1910 3710n
preplace netloc zynq_ultra_ps_e_0_M_AXI_HPM0_FPD 1 3 2 NJ -3120 800
preplace netloc axi_dma_1_M_AXI_MM2S 1 1 2 -730 -1710 -310J
preplace netloc dac0_clk_1 1 7 2 2350J 890 2690
preplace netloc axis_clock_converter_4_M_AXIS 1 3 2 N 1480 N
preplace netloc axi_dma_0_M_AXI_MM2S 1 1 2 -770 -3390 -270
preplace netloc ps8_0_axi_periph_M11_AXI 1 4 2 970 -3750 1320
preplace netloc ps8_0_axi_periph_M09_AXI 1 5 1 1450 -3250n
preplace netloc axi_dma_0_M_AXIS_MM2S 1 1 2 -710 -80 -310
preplace netloc axi_dma_1_M_AXIS_MM2S 1 2 1 N -550
preplace netloc ps8_0_axi_periph_M15_AXI 1 4 2 1000 -2690 1350
preplace netloc axis_tproc64x32_x8_0_m3_axis 1 2 3 NJ 170 N 170 780
preplace netloc ps8_0_axi_periph_M05_AXI 1 4 2 960 -3760 1330
preplace netloc axis_constant_1_m_axis 1 1 1 N 130
preplace netloc ps8_0_axi_periph_M02_AXI 1 4 2 930 -3790 1390
preplace netloc dac1_clk_1 1 7 2 2370J 880 2700
preplace netloc axis_switch_0_M00_AXIS 1 3 2 N -560 910
preplace netloc ps8_0_axi_periph_M08_AXI 1 5 3 N -3270 1920 -650 2330J
preplace netloc axis_tproc64x32_x8_0_m7_axis 1 2 1 -290 250n
preplace netloc axis_tproc64x32_x8_0_m4_axis 1 2 3 NJ 190 N 190 800
preplace netloc usp_rf_data_converter_0_vout10 1 8 1 N 550
preplace netloc axis_tproc64x32_x8_0_m5_axis 1 2 1 -260 210n
preplace netloc axis_switch_avg_M00_AXIS 1 1 7 -720 -630 NJ -630 NJ -630 N -630 NJ -630 NJ -630 2300
preplace netloc ps8_0_axi_periph_M06_AXI 1 1 5 -710 -730 N -730 NJ -730 N -730 1400
preplace netloc axis_tproc64x32_x8_0_m6_axis 1 2 1 -280 230n
preplace netloc ps8_0_axi_periph_M03_AXI 1 4 2 940 -3780 1350
preplace netloc axis_signal_gen_v4_4_m_axis 1 5 3 1420 460 N 460 NJ
preplace netloc axis_signal_gen_v4_0_m_axis 1 5 3 1330 380 N 380 NJ
preplace netloc axis_tproc64x32_x8_0_m8_axis 1 2 1 -300 270n
preplace netloc usp_rf_data_converter_0_vout00 1 8 1 N 490
preplace netloc axis_tproc64x32_x8_0_m1_axis 1 2 3 N 130 N 130 N
preplace netloc ps8_0_axi_periph_M00_AXI 1 1 5 -730 -740 N -740 NJ -740 920 -2640 1410J
preplace netloc axis_signal_gen_v4_2_m_axis 1 5 3 1390 420 N 420 NJ
preplace netloc usp_rf_data_converter_0_vout12 1 8 1 N 590
preplace netloc axis_tproc64x32_x8_0_m0_axis 1 1 2 -720 -60 -310
preplace netloc ps8_0_axi_periph_M01_AXI 1 1 5 -720 -50 N -50 NJ -50 N -50 1420
preplace netloc axis_signal_gen_v4_5_m_axis 1 5 3 1440 480 N 480 NJ
preplace netloc axis_switch_0_M05_AXIS 1 3 2 N -460 810
preplace netloc axis_switch_buf_M00_AXIS 1 1 7 -740 -360 NJ -360 NJ -360 N -360 NJ -360 NJ -360 2290
preplace netloc axis_switch_0_M01_AXIS 1 3 2 N -540 900
preplace netloc axis_switch_0_M03_AXIS 1 3 2 N -500 840
preplace netloc axis_signal_gen_v4_6_m_axis 1 5 3 1460 500 N 500 NJ
preplace netloc axis_switch_0_M02_AXIS 1 3 2 N -520 890
preplace netloc axis_switch_0_M04_AXIS 1 3 2 N -480 830
preplace netloc axis_signal_gen_v4_3_m_axis 1 5 3 1410 440 N 440 NJ
preplace netloc ps8_0_axi_periph_M20_AXI 1 1 5 -730 -1660 NJ -1660 NJ -1660 800 -2660 1320
preplace netloc ps8_0_axi_periph_M04_AXI 1 4 2 950 -3770 1340
preplace netloc axis_signal_gen_v4_1_m_axis 1 5 3 1360 400 N 400 NJ
preplace netloc axis_tproc64x32_x8_0_m2_axis 1 2 3 NJ 150 N 150 850
preplace netloc axis_switch_0_M06_AXIS 1 3 2 N -440 770
preplace netloc axis_clk_cnvrt_avg_0_M_AXIS 1 1 7 -730 3050 NJ 3050 NJ 3050 N 3050 NJ 3050 1900J 2970 2260
preplace netloc ps8_0_axi_periph_M07_AXI 1 2 4 -170 -620 NJ -620 N -620 1390
preplace netloc ps8_0_axi_periph_M14_AXI 1 4 2 990 -2700 1360
preplace netloc axis_clock_converter_5_M_AXIS 1 3 2 N 1740 N
preplace netloc ps8_0_axi_periph_M13_AXI 1 0 6 -1270 -70 N -70 NJ -70 NJ -70 N -70 1380
preplace netloc ps8_0_axi_periph_M19_AXI 1 1 5 -740 -1680 NJ -1680 NJ -1680 770 -2670 1330
preplace netloc axi_dma_buf_M_AXI_S2MM 1 1 2 -710 -3130 -300
preplace netloc ps8_0_axi_periph_M17_AXI 1 5 2 NJ -3090 1890
preplace netloc vin1_1 1 7 2 2390J 850 2730
preplace netloc sysref_in_1 1 7 2 2400 860 2720
preplace netloc usp_rf_data_converter_0_m02_axis 1 3 6 540 280 NJ 280 NJ 280 NJ 280 NJ 280 2690
preplace netloc axi_bram_ctrl_0_BRAM_PORTA 1 1 1 -800 530n
preplace netloc axis_clk_cnvrt_avg_1_M_AXIS 1 1 7 -740 -320 NJ -320 NJ -320 N -320 NJ -320 NJ -320 2280
preplace netloc axis_avg_buffer_1_m1_axis 1 6 1 1820 3280n
preplace netloc usp_rf_data_converter_0_m00_axis 1 3 6 530 40 NJ 40 NJ 40 NJ 40 NJ 40 2700
preplace netloc adc0_clk_1 1 7 2 2360J 870 2710
preplace netloc axis_readout_v2_0_m0_axis 1 5 1 1460 2410n
preplace netloc axis_register_slice_0_M_AXIS 1 4 1 N 2690
preplace netloc ps8_0_axi_periph_M16_AXI 1 4 2 1010 -2680 1340
preplace netloc axis_readout_v2_1_m0_axis 1 5 1 1480 3550n
preplace netloc axis_readout_v2_1_m1_axis 1 5 1 1370 3630n
preplace netloc axis_readout_v2_0_m1_axis 1 5 1 1440 2750n
preplace netloc axis_register_slice_1_M_AXIS 1 4 1 N 3570
levelinfo -pg 1 -1290 -940 -490 160 660 1170 1680 2120 2550 2750
pagesize -pg 1 -db -bbox -sgen -1290 -3800 2900 4350
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


