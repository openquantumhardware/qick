
################################################################
# This is a generated script based on design: base
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
set scripts_vivado_version 2023.1
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
# source base_script.tcl

# If there is no project opened, this script will create a
# project, but make sure you do not have an existing project
# <./myproj/project_1.xpr> in the current working folder.

set overlay_name base
set list_projs [get_projects -quiet]
if { $list_projs eq "" } {
   create_project  ${overlay_name} ${overlay_name} -part xczu49dr-ffvf1760-2-e
   set_property BOARD_PART xilinx.com:zcu216:part0:2.0 [current_project]
}

set_property ip_repo_paths ../../../ip [current_project]
update_ip_catalog

# CHANGE DESIGN NAME HERE
variable design_name
set design_name base

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
xilinx.com:ip:axi_intc:4.1\
xilinx.com:ip:axi_gpio:2.0\
xilinx.com:ip:clk_wiz:6.0\
xilinx.com:ip:proc_sys_reset:5.0\
xilinx.com:ip:system_management_wiz:1.3\
xilinx.com:ip:xlconcat:2.1\
xilinx.com:ip:xpm_cdc_gen:1.0\
xilinx.com:ip:zynq_ultra_ps_e:3.5\
xilinx.com:ip:ddr4:2.2\
xilinx.com:ip:util_ds_buf:2.2\
xilinx.com:ip:usp_rf_data_converter:2.6\
xilinx.com:ip:axi_dma:7.1\
xilinx.com:ip:axis_clock_converter:1.1\
xilinx.com:ip:packet_generator:1.0\
xilinx.com:ip:amplitude_controller:1.0\
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

if { $bCheckIPsPassed != 1 } {
  common::send_gid_msg -ssname BD::TCL -id 2023 -severity "WARNING" "Will not continue with creation of design due to the error(s) above."
  return 3
}

##################################################################
# DESIGN PROCs
##################################################################


# Hierarchical cell: channel_30
proc create_hier_cell_channel_30_1 { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_channel_30_1() - Empty argument(s)!"}
     return
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

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins
  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 M_AXIS

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 S_AXI


  # Create pins
  create_bd_pin -dir I -type clk aclk
  create_bd_pin -dir I -type rst aresetn

  # Create instance: amplitude_controller, and set properties
  set amplitude_controller [ create_bd_cell -type ip -vlnv xilinx.com:ip:amplitude_controller:1.0 amplitude_controller ]
  set_property CONFIG.C_M_AXIS_DATA_WIDTH {256} $amplitude_controller


  # Create interface connections
  connect_bd_intf_net -intf_net S_AXI_1 [get_bd_intf_pins S_AXI] [get_bd_intf_pins amplitude_controller/S_AXI]
  connect_bd_intf_net -intf_net amplitude_controller_M_AXIS [get_bd_intf_pins M_AXIS] [get_bd_intf_pins amplitude_controller/M_AXIS]

  # Create port connections
  connect_bd_net -net aclk_1 [get_bd_pins aclk] [get_bd_pins amplitude_controller/aclk]
  connect_bd_net -net aresetn_1 [get_bd_pins aresetn] [get_bd_pins amplitude_controller/aresetn]

  # Restore current instance
  current_bd_instance $oldCurInst
}

# Hierarchical cell: channel_20
proc create_hier_cell_channel_20_1 { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_channel_20_1() - Empty argument(s)!"}
     return
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

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins
  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 M_AXIS

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 S_AXI


  # Create pins
  create_bd_pin -dir I -type clk aclk
  create_bd_pin -dir I -type rst aresetn

  # Create instance: amplitude_controller, and set properties
  set amplitude_controller [ create_bd_cell -type ip -vlnv xilinx.com:ip:amplitude_controller:1.0 amplitude_controller ]
  set_property CONFIG.C_M_AXIS_DATA_WIDTH {256} $amplitude_controller


  # Create interface connections
  connect_bd_intf_net -intf_net S_AXI_1 [get_bd_intf_pins S_AXI] [get_bd_intf_pins amplitude_controller/S_AXI]
  connect_bd_intf_net -intf_net amplitude_controller_M_AXIS [get_bd_intf_pins M_AXIS] [get_bd_intf_pins amplitude_controller/M_AXIS]

  # Create port connections
  connect_bd_net -net aclk_1 [get_bd_pins aclk] [get_bd_pins amplitude_controller/aclk]
  connect_bd_net -net aresetn_1 [get_bd_pins aresetn] [get_bd_pins amplitude_controller/aresetn]

  # Restore current instance
  current_bd_instance $oldCurInst
}

# Hierarchical cell: channel_10
proc create_hier_cell_channel_10_1 { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_channel_10_1() - Empty argument(s)!"}
     return
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

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins
  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 M_AXIS

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 S_AXI


  # Create pins
  create_bd_pin -dir I -type clk aclk
  create_bd_pin -dir I -type rst aresetn

  # Create instance: amplitude_controller, and set properties
  set amplitude_controller [ create_bd_cell -type ip -vlnv xilinx.com:ip:amplitude_controller:1.0 amplitude_controller ]
  set_property CONFIG.C_M_AXIS_DATA_WIDTH {256} $amplitude_controller


  # Create interface connections
  connect_bd_intf_net -intf_net S_AXI_1 [get_bd_intf_pins S_AXI] [get_bd_intf_pins amplitude_controller/S_AXI]
  connect_bd_intf_net -intf_net amplitude_controller_M_AXIS [get_bd_intf_pins M_AXIS] [get_bd_intf_pins amplitude_controller/M_AXIS]

  # Create port connections
  connect_bd_net -net aclk_1 [get_bd_pins aclk] [get_bd_pins amplitude_controller/aclk]
  connect_bd_net -net aresetn_1 [get_bd_pins aresetn] [get_bd_pins amplitude_controller/aresetn]

  # Restore current instance
  current_bd_instance $oldCurInst
}

# Hierarchical cell: channel_00
proc create_hier_cell_channel_00_1 { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_channel_00_1() - Empty argument(s)!"}
     return
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

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins
  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 M_AXIS

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 S_AXI


  # Create pins
  create_bd_pin -dir I -type clk aclk
  create_bd_pin -dir I -type rst aresetn

  # Create instance: amplitude_controller, and set properties
  set amplitude_controller [ create_bd_cell -type ip -vlnv xilinx.com:ip:amplitude_controller:1.0 amplitude_controller ]
  set_property CONFIG.C_M_AXIS_DATA_WIDTH {256} $amplitude_controller


  # Create interface connections
  connect_bd_intf_net -intf_net S_AXI_1 [get_bd_intf_pins S_AXI] [get_bd_intf_pins amplitude_controller/S_AXI]
  connect_bd_intf_net -intf_net amplitude_controller_M_AXIS [get_bd_intf_pins M_AXIS] [get_bd_intf_pins amplitude_controller/M_AXIS]

  # Create port connections
  connect_bd_net -net aclk_1 [get_bd_pins aclk] [get_bd_pins amplitude_controller/aclk]
  connect_bd_net -net aresetn_1 [get_bd_pins aresetn] [get_bd_pins amplitude_controller/aresetn]

  # Restore current instance
  current_bd_instance $oldCurInst
}

# Hierarchical cell: channel_30
proc create_hier_cell_channel_30 { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_channel_30() - Empty argument(s)!"}
     return
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

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins
  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 M_AXI

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 S_AXI

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 S_AXIS_IM

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 S_AXIS_RE


  # Create pins
  create_bd_pin -dir O -from 1 -to 0 irq
  create_bd_pin -dir I -type clk m_axis_aclk
  create_bd_pin -dir I -type rst m_axis_aresetn
  create_bd_pin -dir I -type clk s_axi_aclk
  create_bd_pin -dir I -type rst s_axi_aresetn
  create_bd_pin -dir I -type clk s_axis_aclk
  create_bd_pin -dir I -type rst s_axis_aresetn

  # Create instance: axi_dma_imag, and set properties
  set axi_dma_imag [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma_imag ]
  set_property -dict [list \
    CONFIG.c_addr_width {64} \
    CONFIG.c_include_mm2s {0} \
    CONFIG.c_include_sg {0} \
    CONFIG.c_s2mm_burst_size {256} \
    CONFIG.c_sg_length_width {26} \
  ] $axi_dma_imag


  # Create instance: axi_dma_real, and set properties
  set axi_dma_real [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma_real ]
  set_property -dict [list \
    CONFIG.c_addr_width {64} \
    CONFIG.c_include_mm2s {0} \
    CONFIG.c_include_sg {0} \
    CONFIG.c_s2mm_burst_size {256} \
    CONFIG.c_sg_length_width {26} \
  ] $axi_dma_real


  # Create instance: axi_interconnect_hpm, and set properties
  set axi_interconnect_hpm [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect_hpm ]
  set_property CONFIG.NUM_MI {3} $axi_interconnect_hpm


  # Create instance: axi_interconnect_hps, and set properties
  set axi_interconnect_hps [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect_hps ]
  set_property -dict [list \
    CONFIG.M00_HAS_DATA_FIFO {0} \
    CONFIG.NUM_MI {1} \
    CONFIG.NUM_SI {2} \
    CONFIG.S00_HAS_DATA_FIFO {1} \
    CONFIG.S01_HAS_DATA_FIFO {1} \
    CONFIG.STRATEGY {0} \
  ] $axi_interconnect_hps


  # Create instance: axis_clock_converter_im, and set properties
  set axis_clock_converter_im [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_clock_converter:1.1 axis_clock_converter_im ]
  set_property CONFIG.SYNCHRONIZATION_STAGES {5} $axis_clock_converter_im


  # Create instance: axis_clock_converter_re, and set properties
  set axis_clock_converter_re [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_clock_converter:1.1 axis_clock_converter_re ]
  set_property CONFIG.SYNCHRONIZATION_STAGES {5} $axis_clock_converter_re


  # Create instance: concat_irq, and set properties
  set concat_irq [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 concat_irq ]

  # Create instance: packet_generator, and set properties
  set packet_generator [ create_bd_cell -type ip -vlnv xilinx.com:ip:packet_generator:1.0 packet_generator ]
  set_property CONFIG.C_S_AXIS_DATA_WIDTH {128} $packet_generator


  # Create interface connections
  connect_bd_intf_net -intf_net S00_AXI_4 [get_bd_intf_pins axi_dma_real/M_AXI_S2MM] [get_bd_intf_pins axi_interconnect_hps/S00_AXI]
  connect_bd_intf_net -intf_net S01_AXI_1 [get_bd_intf_pins axi_dma_imag/M_AXI_S2MM] [get_bd_intf_pins axi_interconnect_hps/S01_AXI]
  connect_bd_intf_net -intf_net S_AXIS_IM_1 [get_bd_intf_pins S_AXIS_IM] [get_bd_intf_pins packet_generator/S_AXIS_IM]
  connect_bd_intf_net -intf_net S_AXIS_RE_1 [get_bd_intf_pins S_AXIS_RE] [get_bd_intf_pins packet_generator/S_AXIS_RE]
  connect_bd_intf_net -intf_net axi_interconnect_1_M00_AXI [get_bd_intf_pins S_AXI] [get_bd_intf_pins axi_interconnect_hpm/S00_AXI]
  connect_bd_intf_net -intf_net axi_interconnect_M00_AXI [get_bd_intf_pins axi_dma_real/S_AXI_LITE] [get_bd_intf_pins axi_interconnect_hpm/M00_AXI]
  connect_bd_intf_net -intf_net axi_interconnect_M01_AXI [get_bd_intf_pins axi_dma_imag/S_AXI_LITE] [get_bd_intf_pins axi_interconnect_hpm/M01_AXI]
  connect_bd_intf_net -intf_net axi_interconnect_hpm_M02_AXI [get_bd_intf_pins axi_interconnect_hpm/M02_AXI] [get_bd_intf_pins packet_generator/S_AXI]
  connect_bd_intf_net -intf_net axi_interconnect_hps_M00_AXI [get_bd_intf_pins M_AXI] [get_bd_intf_pins axi_interconnect_hps/M00_AXI]
  connect_bd_intf_net -intf_net axis_clock_converter_im_M_AXIS [get_bd_intf_pins axi_dma_imag/S_AXIS_S2MM] [get_bd_intf_pins axis_clock_converter_im/M_AXIS]
  connect_bd_intf_net -intf_net axis_clock_converter_re_M_AXIS [get_bd_intf_pins axi_dma_real/S_AXIS_S2MM] [get_bd_intf_pins axis_clock_converter_re/M_AXIS]
  connect_bd_intf_net -intf_net packet_generator_0_M_AXIS_IM [get_bd_intf_pins axis_clock_converter_im/S_AXIS] [get_bd_intf_pins packet_generator/M_AXIS_IM]
  connect_bd_intf_net -intf_net packet_generator_0_M_AXIS_RE [get_bd_intf_pins axis_clock_converter_re/S_AXIS] [get_bd_intf_pins packet_generator/M_AXIS_RE]

  # Create port connections
  connect_bd_net -net axi_dma_imag_s2mm_introut [get_bd_pins axi_dma_imag/s2mm_introut] [get_bd_pins concat_irq/In1]
  connect_bd_net -net axi_dma_real_s2mm_introut [get_bd_pins axi_dma_real/s2mm_introut] [get_bd_pins concat_irq/In0]
  connect_bd_net -net concat_irq_dout [get_bd_pins concat_irq/dout] [get_bd_pins irq]
  connect_bd_net -net proc_sys_reset_1_peripheral_aresetn [get_bd_pins m_axis_aresetn] [get_bd_pins axi_dma_imag/axi_resetn] [get_bd_pins axi_dma_real/axi_resetn] [get_bd_pins axi_interconnect_hpm/M00_ARESETN] [get_bd_pins axi_interconnect_hpm/M01_ARESETN] [get_bd_pins axi_interconnect_hps/ARESETN] [get_bd_pins axi_interconnect_hps/S00_ARESETN] [get_bd_pins axi_interconnect_hps/S01_ARESETN] [get_bd_pins axi_interconnect_hps/M00_ARESETN] [get_bd_pins axis_clock_converter_im/m_axis_aresetn] [get_bd_pins axis_clock_converter_re/m_axis_aresetn]
  connect_bd_net -net proc_sys_reset_adc0_peripheral_aresetn [get_bd_pins s_axis_aresetn] [get_bd_pins axi_interconnect_hpm/M02_ARESETN] [get_bd_pins axis_clock_converter_im/s_axis_aresetn] [get_bd_pins axis_clock_converter_re/s_axis_aresetn] [get_bd_pins packet_generator/aresetn]
  connect_bd_net -net rfdc_clk_adc0 [get_bd_pins s_axis_aclk] [get_bd_pins axi_interconnect_hpm/M02_ACLK] [get_bd_pins axis_clock_converter_im/s_axis_aclk] [get_bd_pins axis_clock_converter_re/s_axis_aclk] [get_bd_pins packet_generator/aclk]
  connect_bd_net -net rst_ps8_0_99M_peripheral_aresetn [get_bd_pins s_axi_aresetn] [get_bd_pins axi_interconnect_hpm/ARESETN] [get_bd_pins axi_interconnect_hpm/S00_ARESETN]
  connect_bd_net -net zynq_ultra_ps_e_0_pl_clk0 [get_bd_pins s_axi_aclk] [get_bd_pins axi_interconnect_hpm/ACLK] [get_bd_pins axi_interconnect_hpm/S00_ACLK]
  connect_bd_net -net zynq_ultra_ps_e_0_pl_clk1 [get_bd_pins m_axis_aclk] [get_bd_pins axi_dma_imag/s_axi_lite_aclk] [get_bd_pins axi_dma_imag/m_axi_s2mm_aclk] [get_bd_pins axi_dma_real/s_axi_lite_aclk] [get_bd_pins axi_dma_real/m_axi_s2mm_aclk] [get_bd_pins axi_interconnect_hpm/M00_ACLK] [get_bd_pins axi_interconnect_hpm/M01_ACLK] [get_bd_pins axi_interconnect_hps/ACLK] [get_bd_pins axi_interconnect_hps/S00_ACLK] [get_bd_pins axi_interconnect_hps/S01_ACLK] [get_bd_pins axi_interconnect_hps/M00_ACLK] [get_bd_pins axis_clock_converter_im/m_axis_aclk] [get_bd_pins axis_clock_converter_re/m_axis_aclk]

  # Restore current instance
  current_bd_instance $oldCurInst
}

# Hierarchical cell: channel_20
proc create_hier_cell_channel_20 { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_channel_20() - Empty argument(s)!"}
     return
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

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins
  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 M_AXI

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 S_AXI

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 S_AXIS_IM

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 S_AXIS_RE


  # Create pins
  create_bd_pin -dir O -from 1 -to 0 irq
  create_bd_pin -dir I -type clk m_axis_aclk
  create_bd_pin -dir I -type rst m_axis_aresetn
  create_bd_pin -dir I -type clk s_axi_aclk
  create_bd_pin -dir I -type rst s_axi_aresetn
  create_bd_pin -dir I -type clk s_axis_aclk
  create_bd_pin -dir I -type rst s_axis_aresetn

  # Create instance: axi_dma_imag, and set properties
  set axi_dma_imag [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma_imag ]
  set_property -dict [list \
    CONFIG.c_addr_width {64} \
    CONFIG.c_include_mm2s {0} \
    CONFIG.c_include_sg {0} \
    CONFIG.c_s2mm_burst_size {256} \
    CONFIG.c_sg_length_width {26} \
  ] $axi_dma_imag


  # Create instance: axi_dma_real, and set properties
  set axi_dma_real [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma_real ]
  set_property -dict [list \
    CONFIG.c_addr_width {64} \
    CONFIG.c_include_mm2s {0} \
    CONFIG.c_include_sg {0} \
    CONFIG.c_s2mm_burst_size {256} \
    CONFIG.c_sg_length_width {26} \
  ] $axi_dma_real


  # Create instance: axi_interconnect_hpm, and set properties
  set axi_interconnect_hpm [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect_hpm ]
  set_property CONFIG.NUM_MI {3} $axi_interconnect_hpm


  # Create instance: axi_interconnect_hps, and set properties
  set axi_interconnect_hps [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect_hps ]
  set_property -dict [list \
    CONFIG.M00_HAS_DATA_FIFO {0} \
    CONFIG.NUM_MI {1} \
    CONFIG.NUM_SI {2} \
    CONFIG.S00_HAS_DATA_FIFO {1} \
    CONFIG.S01_HAS_DATA_FIFO {1} \
    CONFIG.STRATEGY {0} \
  ] $axi_interconnect_hps


  # Create instance: axis_clock_converter_im, and set properties
  set axis_clock_converter_im [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_clock_converter:1.1 axis_clock_converter_im ]
  set_property CONFIG.SYNCHRONIZATION_STAGES {5} $axis_clock_converter_im


  # Create instance: axis_clock_converter_re, and set properties
  set axis_clock_converter_re [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_clock_converter:1.1 axis_clock_converter_re ]
  set_property CONFIG.SYNCHRONIZATION_STAGES {5} $axis_clock_converter_re


  # Create instance: concat_irq, and set properties
  set concat_irq [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 concat_irq ]

  # Create instance: packet_generator, and set properties
  set packet_generator [ create_bd_cell -type ip -vlnv xilinx.com:ip:packet_generator:1.0 packet_generator ]
  set_property CONFIG.C_S_AXIS_DATA_WIDTH {128} $packet_generator


  # Create interface connections
  connect_bd_intf_net -intf_net S00_AXI_4 [get_bd_intf_pins axi_dma_real/M_AXI_S2MM] [get_bd_intf_pins axi_interconnect_hps/S00_AXI]
  connect_bd_intf_net -intf_net S01_AXI_1 [get_bd_intf_pins axi_dma_imag/M_AXI_S2MM] [get_bd_intf_pins axi_interconnect_hps/S01_AXI]
  connect_bd_intf_net -intf_net S_AXIS_IM_1 [get_bd_intf_pins S_AXIS_IM] [get_bd_intf_pins packet_generator/S_AXIS_IM]
  connect_bd_intf_net -intf_net S_AXIS_RE_1 [get_bd_intf_pins S_AXIS_RE] [get_bd_intf_pins packet_generator/S_AXIS_RE]
  connect_bd_intf_net -intf_net axi_interconnect_1_M00_AXI [get_bd_intf_pins S_AXI] [get_bd_intf_pins axi_interconnect_hpm/S00_AXI]
  connect_bd_intf_net -intf_net axi_interconnect_M00_AXI [get_bd_intf_pins axi_dma_real/S_AXI_LITE] [get_bd_intf_pins axi_interconnect_hpm/M00_AXI]
  connect_bd_intf_net -intf_net axi_interconnect_M01_AXI [get_bd_intf_pins axi_dma_imag/S_AXI_LITE] [get_bd_intf_pins axi_interconnect_hpm/M01_AXI]
  connect_bd_intf_net -intf_net axi_interconnect_hpm_M02_AXI [get_bd_intf_pins axi_interconnect_hpm/M02_AXI] [get_bd_intf_pins packet_generator/S_AXI]
  connect_bd_intf_net -intf_net axi_interconnect_hps_M00_AXI [get_bd_intf_pins M_AXI] [get_bd_intf_pins axi_interconnect_hps/M00_AXI]
  connect_bd_intf_net -intf_net axis_clock_converter_im_M_AXIS [get_bd_intf_pins axi_dma_imag/S_AXIS_S2MM] [get_bd_intf_pins axis_clock_converter_im/M_AXIS]
  connect_bd_intf_net -intf_net axis_clock_converter_re_M_AXIS [get_bd_intf_pins axi_dma_real/S_AXIS_S2MM] [get_bd_intf_pins axis_clock_converter_re/M_AXIS]
  connect_bd_intf_net -intf_net packet_generator_0_M_AXIS_IM [get_bd_intf_pins axis_clock_converter_im/S_AXIS] [get_bd_intf_pins packet_generator/M_AXIS_IM]
  connect_bd_intf_net -intf_net packet_generator_0_M_AXIS_RE [get_bd_intf_pins axis_clock_converter_re/S_AXIS] [get_bd_intf_pins packet_generator/M_AXIS_RE]

  # Create port connections
  connect_bd_net -net axi_dma_imag_s2mm_introut [get_bd_pins axi_dma_imag/s2mm_introut] [get_bd_pins concat_irq/In1]
  connect_bd_net -net axi_dma_real_s2mm_introut [get_bd_pins axi_dma_real/s2mm_introut] [get_bd_pins concat_irq/In0]
  connect_bd_net -net concat_irq_dout [get_bd_pins concat_irq/dout] [get_bd_pins irq]
  connect_bd_net -net proc_sys_reset_1_peripheral_aresetn [get_bd_pins m_axis_aresetn] [get_bd_pins axi_dma_imag/axi_resetn] [get_bd_pins axi_dma_real/axi_resetn] [get_bd_pins axi_interconnect_hpm/M00_ARESETN] [get_bd_pins axi_interconnect_hpm/M01_ARESETN] [get_bd_pins axi_interconnect_hps/ARESETN] [get_bd_pins axi_interconnect_hps/S00_ARESETN] [get_bd_pins axi_interconnect_hps/S01_ARESETN] [get_bd_pins axi_interconnect_hps/M00_ARESETN] [get_bd_pins axis_clock_converter_im/m_axis_aresetn] [get_bd_pins axis_clock_converter_re/m_axis_aresetn]
  connect_bd_net -net proc_sys_reset_adc0_peripheral_aresetn [get_bd_pins s_axis_aresetn] [get_bd_pins axi_interconnect_hpm/M02_ARESETN] [get_bd_pins axis_clock_converter_im/s_axis_aresetn] [get_bd_pins axis_clock_converter_re/s_axis_aresetn] [get_bd_pins packet_generator/aresetn]
  connect_bd_net -net rfdc_clk_adc0 [get_bd_pins s_axis_aclk] [get_bd_pins axi_interconnect_hpm/M02_ACLK] [get_bd_pins axis_clock_converter_im/s_axis_aclk] [get_bd_pins axis_clock_converter_re/s_axis_aclk] [get_bd_pins packet_generator/aclk]
  connect_bd_net -net rst_ps8_0_99M_peripheral_aresetn [get_bd_pins s_axi_aresetn] [get_bd_pins axi_interconnect_hpm/ARESETN] [get_bd_pins axi_interconnect_hpm/S00_ARESETN]
  connect_bd_net -net zynq_ultra_ps_e_0_pl_clk0 [get_bd_pins s_axi_aclk] [get_bd_pins axi_interconnect_hpm/ACLK] [get_bd_pins axi_interconnect_hpm/S00_ACLK]
  connect_bd_net -net zynq_ultra_ps_e_0_pl_clk1 [get_bd_pins m_axis_aclk] [get_bd_pins axi_dma_imag/s_axi_lite_aclk] [get_bd_pins axi_dma_imag/m_axi_s2mm_aclk] [get_bd_pins axi_dma_real/s_axi_lite_aclk] [get_bd_pins axi_dma_real/m_axi_s2mm_aclk] [get_bd_pins axi_interconnect_hpm/M00_ACLK] [get_bd_pins axi_interconnect_hpm/M01_ACLK] [get_bd_pins axi_interconnect_hps/ACLK] [get_bd_pins axi_interconnect_hps/S00_ACLK] [get_bd_pins axi_interconnect_hps/S01_ACLK] [get_bd_pins axi_interconnect_hps/M00_ACLK] [get_bd_pins axis_clock_converter_im/m_axis_aclk] [get_bd_pins axis_clock_converter_re/m_axis_aclk]

  # Restore current instance
  current_bd_instance $oldCurInst
}

# Hierarchical cell: channel_10
proc create_hier_cell_channel_10 { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_channel_10() - Empty argument(s)!"}
     return
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

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins
  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 M_AXI

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 S_AXI

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 S_AXIS_IM

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 S_AXIS_RE


  # Create pins
  create_bd_pin -dir O -from 1 -to 0 irq
  create_bd_pin -dir I -type clk m_axis_aclk
  create_bd_pin -dir I -type rst m_axis_aresetn
  create_bd_pin -dir I -type clk s_axi_aclk
  create_bd_pin -dir I -type rst s_axi_aresetn
  create_bd_pin -dir I -type clk s_axis_aclk
  create_bd_pin -dir I -type rst s_axis_aresetn

  # Create instance: axi_dma_imag, and set properties
  set axi_dma_imag [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma_imag ]
  set_property -dict [list \
    CONFIG.c_addr_width {64} \
    CONFIG.c_include_mm2s {0} \
    CONFIG.c_include_sg {0} \
    CONFIG.c_s2mm_burst_size {256} \
    CONFIG.c_sg_length_width {26} \
  ] $axi_dma_imag


  # Create instance: axi_dma_real, and set properties
  set axi_dma_real [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma_real ]
  set_property -dict [list \
    CONFIG.c_addr_width {64} \
    CONFIG.c_include_mm2s {0} \
    CONFIG.c_include_sg {0} \
    CONFIG.c_s2mm_burst_size {256} \
    CONFIG.c_sg_length_width {26} \
  ] $axi_dma_real


  # Create instance: axi_interconnect_hpm, and set properties
  set axi_interconnect_hpm [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect_hpm ]
  set_property CONFIG.NUM_MI {3} $axi_interconnect_hpm


  # Create instance: axi_interconnect_hps, and set properties
  set axi_interconnect_hps [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect_hps ]
  set_property -dict [list \
    CONFIG.M00_HAS_DATA_FIFO {0} \
    CONFIG.NUM_MI {1} \
    CONFIG.NUM_SI {2} \
    CONFIG.S00_HAS_DATA_FIFO {1} \
    CONFIG.S01_HAS_DATA_FIFO {1} \
    CONFIG.STRATEGY {0} \
  ] $axi_interconnect_hps


  # Create instance: axis_clock_converter_im, and set properties
  set axis_clock_converter_im [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_clock_converter:1.1 axis_clock_converter_im ]
  set_property CONFIG.SYNCHRONIZATION_STAGES {5} $axis_clock_converter_im


  # Create instance: axis_clock_converter_re, and set properties
  set axis_clock_converter_re [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_clock_converter:1.1 axis_clock_converter_re ]
  set_property CONFIG.SYNCHRONIZATION_STAGES {5} $axis_clock_converter_re


  # Create instance: concat_irq, and set properties
  set concat_irq [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 concat_irq ]

  # Create instance: packet_generator, and set properties
  set packet_generator [ create_bd_cell -type ip -vlnv xilinx.com:ip:packet_generator:1.0 packet_generator ]
  set_property CONFIG.C_S_AXIS_DATA_WIDTH {128} $packet_generator


  # Create interface connections
  connect_bd_intf_net -intf_net S00_AXI_4 [get_bd_intf_pins axi_dma_real/M_AXI_S2MM] [get_bd_intf_pins axi_interconnect_hps/S00_AXI]
  connect_bd_intf_net -intf_net S01_AXI_1 [get_bd_intf_pins axi_dma_imag/M_AXI_S2MM] [get_bd_intf_pins axi_interconnect_hps/S01_AXI]
  connect_bd_intf_net -intf_net S_AXIS_IM_1 [get_bd_intf_pins S_AXIS_IM] [get_bd_intf_pins packet_generator/S_AXIS_IM]
  connect_bd_intf_net -intf_net S_AXIS_RE_1 [get_bd_intf_pins S_AXIS_RE] [get_bd_intf_pins packet_generator/S_AXIS_RE]
  connect_bd_intf_net -intf_net axi_interconnect_1_M00_AXI [get_bd_intf_pins S_AXI] [get_bd_intf_pins axi_interconnect_hpm/S00_AXI]
  connect_bd_intf_net -intf_net axi_interconnect_M00_AXI [get_bd_intf_pins axi_dma_real/S_AXI_LITE] [get_bd_intf_pins axi_interconnect_hpm/M00_AXI]
  connect_bd_intf_net -intf_net axi_interconnect_M01_AXI [get_bd_intf_pins axi_dma_imag/S_AXI_LITE] [get_bd_intf_pins axi_interconnect_hpm/M01_AXI]
  connect_bd_intf_net -intf_net axi_interconnect_hpm_M02_AXI [get_bd_intf_pins axi_interconnect_hpm/M02_AXI] [get_bd_intf_pins packet_generator/S_AXI]
  connect_bd_intf_net -intf_net axi_interconnect_hps_M00_AXI [get_bd_intf_pins M_AXI] [get_bd_intf_pins axi_interconnect_hps/M00_AXI]
  connect_bd_intf_net -intf_net axis_clock_converter_im_M_AXIS [get_bd_intf_pins axi_dma_imag/S_AXIS_S2MM] [get_bd_intf_pins axis_clock_converter_im/M_AXIS]
  connect_bd_intf_net -intf_net axis_clock_converter_re_M_AXIS [get_bd_intf_pins axi_dma_real/S_AXIS_S2MM] [get_bd_intf_pins axis_clock_converter_re/M_AXIS]
  connect_bd_intf_net -intf_net packet_generator_0_M_AXIS_IM [get_bd_intf_pins axis_clock_converter_im/S_AXIS] [get_bd_intf_pins packet_generator/M_AXIS_IM]
  connect_bd_intf_net -intf_net packet_generator_0_M_AXIS_RE [get_bd_intf_pins axis_clock_converter_re/S_AXIS] [get_bd_intf_pins packet_generator/M_AXIS_RE]

  # Create port connections
  connect_bd_net -net axi_dma_imag_s2mm_introut [get_bd_pins axi_dma_imag/s2mm_introut] [get_bd_pins concat_irq/In1]
  connect_bd_net -net axi_dma_real_s2mm_introut [get_bd_pins axi_dma_real/s2mm_introut] [get_bd_pins concat_irq/In0]
  connect_bd_net -net concat_irq_dout [get_bd_pins concat_irq/dout] [get_bd_pins irq]
  connect_bd_net -net proc_sys_reset_1_peripheral_aresetn [get_bd_pins m_axis_aresetn] [get_bd_pins axi_dma_imag/axi_resetn] [get_bd_pins axi_dma_real/axi_resetn] [get_bd_pins axi_interconnect_hpm/M00_ARESETN] [get_bd_pins axi_interconnect_hpm/M01_ARESETN] [get_bd_pins axi_interconnect_hps/ARESETN] [get_bd_pins axi_interconnect_hps/S00_ARESETN] [get_bd_pins axi_interconnect_hps/S01_ARESETN] [get_bd_pins axi_interconnect_hps/M00_ARESETN] [get_bd_pins axis_clock_converter_im/m_axis_aresetn] [get_bd_pins axis_clock_converter_re/m_axis_aresetn]
  connect_bd_net -net proc_sys_reset_adc0_peripheral_aresetn [get_bd_pins s_axis_aresetn] [get_bd_pins axi_interconnect_hpm/M02_ARESETN] [get_bd_pins axis_clock_converter_im/s_axis_aresetn] [get_bd_pins axis_clock_converter_re/s_axis_aresetn] [get_bd_pins packet_generator/aresetn]
  connect_bd_net -net rfdc_clk_adc0 [get_bd_pins s_axis_aclk] [get_bd_pins axi_interconnect_hpm/M02_ACLK] [get_bd_pins axis_clock_converter_im/s_axis_aclk] [get_bd_pins axis_clock_converter_re/s_axis_aclk] [get_bd_pins packet_generator/aclk]
  connect_bd_net -net rst_ps8_0_99M_peripheral_aresetn [get_bd_pins s_axi_aresetn] [get_bd_pins axi_interconnect_hpm/ARESETN] [get_bd_pins axi_interconnect_hpm/S00_ARESETN]
  connect_bd_net -net zynq_ultra_ps_e_0_pl_clk0 [get_bd_pins s_axi_aclk] [get_bd_pins axi_interconnect_hpm/ACLK] [get_bd_pins axi_interconnect_hpm/S00_ACLK]
  connect_bd_net -net zynq_ultra_ps_e_0_pl_clk1 [get_bd_pins m_axis_aclk] [get_bd_pins axi_dma_imag/s_axi_lite_aclk] [get_bd_pins axi_dma_imag/m_axi_s2mm_aclk] [get_bd_pins axi_dma_real/s_axi_lite_aclk] [get_bd_pins axi_dma_real/m_axi_s2mm_aclk] [get_bd_pins axi_interconnect_hpm/M00_ACLK] [get_bd_pins axi_interconnect_hpm/M01_ACLK] [get_bd_pins axi_interconnect_hps/ACLK] [get_bd_pins axi_interconnect_hps/S00_ACLK] [get_bd_pins axi_interconnect_hps/S01_ACLK] [get_bd_pins axi_interconnect_hps/M00_ACLK] [get_bd_pins axis_clock_converter_im/m_axis_aclk] [get_bd_pins axis_clock_converter_re/m_axis_aclk]

  # Restore current instance
  current_bd_instance $oldCurInst
}

# Hierarchical cell: channel_00
proc create_hier_cell_channel_00 { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_channel_00() - Empty argument(s)!"}
     return
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

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins
  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 M_AXI

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 S_AXI

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 S_AXIS_IM

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 S_AXIS_RE


  # Create pins
  create_bd_pin -dir O -from 1 -to 0 irq
  create_bd_pin -dir I -type clk m_axis_aclk
  create_bd_pin -dir I -type rst m_axis_aresetn
  create_bd_pin -dir I -type clk s_axi_aclk
  create_bd_pin -dir I -type rst s_axi_aresetn
  create_bd_pin -dir I -type clk s_axis_aclk
  create_bd_pin -dir I -type rst s_axis_aresetn

  # Create instance: axi_dma_imag, and set properties
  set axi_dma_imag [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma_imag ]
  set_property -dict [list \
    CONFIG.c_addr_width {64} \
    CONFIG.c_include_mm2s {0} \
    CONFIG.c_include_sg {0} \
    CONFIG.c_s2mm_burst_size {256} \
    CONFIG.c_sg_length_width {26} \
  ] $axi_dma_imag


  # Create instance: axi_dma_real, and set properties
  set axi_dma_real [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma_real ]
  set_property -dict [list \
    CONFIG.c_addr_width {64} \
    CONFIG.c_include_mm2s {0} \
    CONFIG.c_include_sg {0} \
    CONFIG.c_s2mm_burst_size {256} \
    CONFIG.c_sg_length_width {26} \
  ] $axi_dma_real


  # Create instance: axi_interconnect_hpm, and set properties
  set axi_interconnect_hpm [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect_hpm ]
  set_property -dict [list \
    CONFIG.NUM_MI {3} \
    CONFIG.STRATEGY {1} \
  ] $axi_interconnect_hpm


  # Create instance: axi_interconnect_hps, and set properties
  set axi_interconnect_hps [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect_hps ]
  set_property -dict [list \
    CONFIG.M00_HAS_DATA_FIFO {0} \
    CONFIG.NUM_MI {1} \
    CONFIG.NUM_SI {2} \
    CONFIG.S00_HAS_DATA_FIFO {1} \
    CONFIG.S01_HAS_DATA_FIFO {1} \
    CONFIG.STRATEGY {0} \
  ] $axi_interconnect_hps


  # Create instance: axis_clock_converter_im, and set properties
  set axis_clock_converter_im [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_clock_converter:1.1 axis_clock_converter_im ]
  set_property CONFIG.SYNCHRONIZATION_STAGES {5} $axis_clock_converter_im


  # Create instance: axis_clock_converter_re, and set properties
  set axis_clock_converter_re [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_clock_converter:1.1 axis_clock_converter_re ]
  set_property CONFIG.SYNCHRONIZATION_STAGES {5} $axis_clock_converter_re


  # Create instance: concat_irq, and set properties
  set concat_irq [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 concat_irq ]

  # Create instance: packet_generator, and set properties
  set packet_generator [ create_bd_cell -type ip -vlnv xilinx.com:ip:packet_generator:1.0 packet_generator ]
  set_property CONFIG.C_S_AXIS_DATA_WIDTH {128} $packet_generator


  # Create interface connections
  connect_bd_intf_net -intf_net S00_AXI_4 [get_bd_intf_pins axi_dma_real/M_AXI_S2MM] [get_bd_intf_pins axi_interconnect_hps/S00_AXI]
  connect_bd_intf_net -intf_net S01_AXI_1 [get_bd_intf_pins axi_dma_imag/M_AXI_S2MM] [get_bd_intf_pins axi_interconnect_hps/S01_AXI]
  connect_bd_intf_net -intf_net S_AXIS_IM_1 [get_bd_intf_pins S_AXIS_IM] [get_bd_intf_pins packet_generator/S_AXIS_IM]
  connect_bd_intf_net -intf_net S_AXIS_RE_1 [get_bd_intf_pins S_AXIS_RE] [get_bd_intf_pins packet_generator/S_AXIS_RE]
  connect_bd_intf_net -intf_net axi_interconnect_1_M00_AXI [get_bd_intf_pins S_AXI] [get_bd_intf_pins axi_interconnect_hpm/S00_AXI]
  connect_bd_intf_net -intf_net axi_interconnect_M00_AXI [get_bd_intf_pins axi_dma_real/S_AXI_LITE] [get_bd_intf_pins axi_interconnect_hpm/M00_AXI]
  connect_bd_intf_net -intf_net axi_interconnect_M01_AXI [get_bd_intf_pins axi_dma_imag/S_AXI_LITE] [get_bd_intf_pins axi_interconnect_hpm/M01_AXI]
  connect_bd_intf_net -intf_net axi_interconnect_hpm_M02_AXI [get_bd_intf_pins axi_interconnect_hpm/M02_AXI] [get_bd_intf_pins packet_generator/S_AXI]
  connect_bd_intf_net -intf_net axi_interconnect_hps_M00_AXI [get_bd_intf_pins M_AXI] [get_bd_intf_pins axi_interconnect_hps/M00_AXI]
  connect_bd_intf_net -intf_net axis_clock_converter_im_M_AXIS [get_bd_intf_pins axi_dma_imag/S_AXIS_S2MM] [get_bd_intf_pins axis_clock_converter_im/M_AXIS]
  connect_bd_intf_net -intf_net axis_clock_converter_re_M_AXIS [get_bd_intf_pins axi_dma_real/S_AXIS_S2MM] [get_bd_intf_pins axis_clock_converter_re/M_AXIS]
  connect_bd_intf_net -intf_net packet_generator_0_M_AXIS_IM [get_bd_intf_pins axis_clock_converter_im/S_AXIS] [get_bd_intf_pins packet_generator/M_AXIS_IM]
  connect_bd_intf_net -intf_net packet_generator_0_M_AXIS_RE [get_bd_intf_pins axis_clock_converter_re/S_AXIS] [get_bd_intf_pins packet_generator/M_AXIS_RE]

  # Create port connections
  connect_bd_net -net axi_dma_imag_s2mm_introut [get_bd_pins axi_dma_imag/s2mm_introut] [get_bd_pins concat_irq/In1]
  connect_bd_net -net axi_dma_real_s2mm_introut [get_bd_pins axi_dma_real/s2mm_introut] [get_bd_pins concat_irq/In0]
  connect_bd_net -net concat_irq_dout [get_bd_pins concat_irq/dout] [get_bd_pins irq]
  connect_bd_net -net proc_sys_reset_1_peripheral_aresetn [get_bd_pins m_axis_aresetn] [get_bd_pins axi_dma_imag/axi_resetn] [get_bd_pins axi_dma_real/axi_resetn] [get_bd_pins axi_interconnect_hpm/M00_ARESETN] [get_bd_pins axi_interconnect_hpm/M01_ARESETN] [get_bd_pins axi_interconnect_hps/ARESETN] [get_bd_pins axi_interconnect_hps/S00_ARESETN] [get_bd_pins axi_interconnect_hps/S01_ARESETN] [get_bd_pins axi_interconnect_hps/M00_ARESETN] [get_bd_pins axis_clock_converter_im/m_axis_aresetn] [get_bd_pins axis_clock_converter_re/m_axis_aresetn]
  connect_bd_net -net proc_sys_reset_adc0_peripheral_aresetn [get_bd_pins s_axis_aresetn] [get_bd_pins axi_interconnect_hpm/M02_ARESETN] [get_bd_pins axis_clock_converter_im/s_axis_aresetn] [get_bd_pins axis_clock_converter_re/s_axis_aresetn] [get_bd_pins packet_generator/aresetn]
  connect_bd_net -net rfdc_clk_adc0 [get_bd_pins s_axis_aclk] [get_bd_pins axi_interconnect_hpm/M02_ACLK] [get_bd_pins axis_clock_converter_im/s_axis_aclk] [get_bd_pins axis_clock_converter_re/s_axis_aclk] [get_bd_pins packet_generator/aclk]
  connect_bd_net -net rst_ps8_0_99M_peripheral_aresetn [get_bd_pins s_axi_aresetn] [get_bd_pins axi_interconnect_hpm/ARESETN] [get_bd_pins axi_interconnect_hpm/S00_ARESETN]
  connect_bd_net -net zynq_ultra_ps_e_0_pl_clk0 [get_bd_pins s_axi_aclk] [get_bd_pins axi_interconnect_hpm/ACLK] [get_bd_pins axi_interconnect_hpm/S00_ACLK]
  connect_bd_net -net zynq_ultra_ps_e_0_pl_clk1 [get_bd_pins m_axis_aclk] [get_bd_pins axi_dma_imag/s_axi_lite_aclk] [get_bd_pins axi_dma_imag/m_axi_s2mm_aclk] [get_bd_pins axi_dma_real/s_axi_lite_aclk] [get_bd_pins axi_dma_real/m_axi_s2mm_aclk] [get_bd_pins axi_interconnect_hpm/M00_ACLK] [get_bd_pins axi_interconnect_hpm/M01_ACLK] [get_bd_pins axi_interconnect_hps/ACLK] [get_bd_pins axi_interconnect_hps/S00_ACLK] [get_bd_pins axi_interconnect_hps/S01_ACLK] [get_bd_pins axi_interconnect_hps/M00_ACLK] [get_bd_pins axis_clock_converter_im/m_axis_aclk] [get_bd_pins axis_clock_converter_re/m_axis_aclk]

  # Restore current instance
  current_bd_instance $oldCurInst
}

# Hierarchical cell: transmitter
proc create_hier_cell_transmitter { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_transmitter() - Empty argument(s)!"}
     return
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

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins
  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 M_AXIS_DAC_00

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 M_AXIS_DAC_10

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 M_AXIS_DAC_20

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 M_AXIS_DAC_30

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 S_AXI


  # Create pins
  create_bd_pin -dir O -from 0 -to 0 -type rst aresetn_dac0
  create_bd_pin -dir O -from 0 -to 0 -type rst aresetn_dac1
  create_bd_pin -dir O -from 0 -to 0 -type rst aresetn_dac2
  create_bd_pin -dir O -from 0 -to 0 -type rst aresetn_dac3
  create_bd_pin -dir I -type clk clk_dac0
  create_bd_pin -dir I -type clk clk_dac1
  create_bd_pin -dir I -type clk clk_dac2
  create_bd_pin -dir I -type clk clk_dac3
  create_bd_pin -dir I -type rst ext_reset
  create_bd_pin -dir I -type clk s_axi_aclk
  create_bd_pin -dir I -type rst s_axi_aresetn

  # Create instance: channel_00
  create_hier_cell_channel_00_1 $hier_obj channel_00

  # Create instance: channel_10
  create_hier_cell_channel_10_1 $hier_obj channel_10

  # Create instance: channel_20
  create_hier_cell_channel_20_1 $hier_obj channel_20

  # Create instance: channel_30
  create_hier_cell_channel_30_1 $hier_obj channel_30

  # Create instance: axi_interconnect, and set properties
  set axi_interconnect [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect ]
  set_property -dict [list \
    CONFIG.NUM_MI {4} \
    CONFIG.STRATEGY {1} \
  ] $axi_interconnect


  # Create instance: proc_sys_reset_dac0, and set properties
  set proc_sys_reset_dac0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_dac0 ]

  # Create instance: proc_sys_reset_dac1, and set properties
  set proc_sys_reset_dac1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_dac1 ]

  # Create instance: proc_sys_reset_dac2, and set properties
  set proc_sys_reset_dac2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_dac2 ]

  # Create instance: proc_sys_reset_dac3, and set properties
  set proc_sys_reset_dac3 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_dac3 ]

  # Create interface connections
  connect_bd_intf_net -intf_net Conn1 [get_bd_intf_pins M_AXIS_DAC_30] [get_bd_intf_pins channel_30/M_AXIS]
  connect_bd_intf_net -intf_net Conn2 [get_bd_intf_pins M_AXIS_DAC_00] [get_bd_intf_pins channel_00/M_AXIS]
  connect_bd_intf_net -intf_net Conn3 [get_bd_intf_pins M_AXIS_DAC_20] [get_bd_intf_pins channel_20/M_AXIS]
  connect_bd_intf_net -intf_net Conn4 [get_bd_intf_pins M_AXIS_DAC_10] [get_bd_intf_pins channel_10/M_AXIS]
  connect_bd_intf_net -intf_net S00_AXI_1 [get_bd_intf_pins S_AXI] [get_bd_intf_pins axi_interconnect/S00_AXI]
  connect_bd_intf_net -intf_net axi_interconnect_M00_AXI [get_bd_intf_pins axi_interconnect/M00_AXI] [get_bd_intf_pins channel_00/S_AXI]
  connect_bd_intf_net -intf_net axi_interconnect_M01_AXI [get_bd_intf_pins axi_interconnect/M01_AXI] [get_bd_intf_pins channel_10/S_AXI]
  connect_bd_intf_net -intf_net axi_interconnect_M02_AXI [get_bd_intf_pins axi_interconnect/M02_AXI] [get_bd_intf_pins channel_20/S_AXI]
  connect_bd_intf_net -intf_net axi_interconnect_M03_AXI [get_bd_intf_pins axi_interconnect/M03_AXI] [get_bd_intf_pins channel_30/S_AXI]

  # Create port connections
  connect_bd_net -net aclk_1 [get_bd_pins clk_dac2] [get_bd_pins channel_20/aclk] [get_bd_pins axi_interconnect/M02_ACLK] [get_bd_pins proc_sys_reset_dac2/slowest_sync_clk]
  connect_bd_net -net aclk_2 [get_bd_pins clk_dac3] [get_bd_pins channel_30/aclk] [get_bd_pins axi_interconnect/M03_ACLK] [get_bd_pins proc_sys_reset_dac3/slowest_sync_clk]
  connect_bd_net -net aclk_3 [get_bd_pins clk_dac0] [get_bd_pins channel_00/aclk] [get_bd_pins axi_interconnect/M00_ACLK] [get_bd_pins proc_sys_reset_dac0/slowest_sync_clk]
  connect_bd_net -net aclk_5 [get_bd_pins clk_dac1] [get_bd_pins channel_10/aclk] [get_bd_pins axi_interconnect/M01_ACLK] [get_bd_pins proc_sys_reset_dac1/slowest_sync_clk]
  connect_bd_net -net aresetn_1 [get_bd_pins proc_sys_reset_dac3/peripheral_aresetn] [get_bd_pins aresetn_dac3] [get_bd_pins channel_30/aresetn] [get_bd_pins axi_interconnect/M03_ARESETN]
  connect_bd_net -net proc_sys_reset_dac0_peripheral_aresetn [get_bd_pins proc_sys_reset_dac0/peripheral_aresetn] [get_bd_pins aresetn_dac0] [get_bd_pins channel_00/aresetn] [get_bd_pins axi_interconnect/M00_ARESETN]
  connect_bd_net -net proc_sys_reset_dac1_peripheral_aresetn [get_bd_pins proc_sys_reset_dac1/peripheral_aresetn] [get_bd_pins aresetn_dac1] [get_bd_pins channel_10/aresetn] [get_bd_pins axi_interconnect/M01_ARESETN]
  connect_bd_net -net proc_sys_reset_dac2_peripheral_aresetn [get_bd_pins proc_sys_reset_dac2/peripheral_aresetn] [get_bd_pins aresetn_dac2] [get_bd_pins channel_20/aresetn] [get_bd_pins axi_interconnect/M02_ARESETN]
  connect_bd_net -net rst_ps8_0_99M_peripheral_aresetn [get_bd_pins s_axi_aresetn] [get_bd_pins axi_interconnect/ARESETN] [get_bd_pins axi_interconnect/S00_ARESETN]
  connect_bd_net -net zynq_ultra_ps_e_0_pl_clk0 [get_bd_pins s_axi_aclk] [get_bd_pins axi_interconnect/ACLK] [get_bd_pins axi_interconnect/S00_ACLK]
  connect_bd_net -net zynq_ultra_ps_e_0_pl_resetn0 [get_bd_pins ext_reset] [get_bd_pins proc_sys_reset_dac0/ext_reset_in] [get_bd_pins proc_sys_reset_dac1/ext_reset_in] [get_bd_pins proc_sys_reset_dac2/ext_reset_in] [get_bd_pins proc_sys_reset_dac3/ext_reset_in]

  # Restore current instance
  current_bd_instance $oldCurInst
}

# Hierarchical cell: receiver
proc create_hier_cell_receiver { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_receiver() - Empty argument(s)!"}
     return
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

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins
  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 M_AXI

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 S_AXI

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 S_AXIS_ADC_00_IM

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 S_AXIS_ADC_00_RE

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 S_AXIS_ADC_10_IM

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 S_AXIS_ADC_10_RE

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 S_AXIS_ADC_20_IM

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 S_AXIS_ADC_20_RE

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 S_AXIS_ADC_30_IM

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 S_AXIS_ADC_30_RE


  # Create pins
  create_bd_pin -dir O -from 0 -to 0 -type rst aresetn_adc0
  create_bd_pin -dir O -from 0 -to 0 -type rst aresetn_adc1
  create_bd_pin -dir O -from 0 -to 0 -type rst aresetn_adc2
  create_bd_pin -dir O -from 0 -to 0 -type rst aresetn_adc3
  create_bd_pin -dir I -type clk clk_adc0
  create_bd_pin -dir I -type clk clk_adc1
  create_bd_pin -dir I -type clk clk_adc2
  create_bd_pin -dir I -type clk clk_adc3
  create_bd_pin -dir I -type rst ext_reset
  create_bd_pin -dir O -from 7 -to 0 irq
  create_bd_pin -dir I -type clk m_axis_aclk
  create_bd_pin -dir I -type rst m_axis_aresetn
  create_bd_pin -dir I -type clk s_axi_aclk
  create_bd_pin -dir I -type rst s_axi_aresetn

  # Create instance: channel_00
  create_hier_cell_channel_00 $hier_obj channel_00

  # Create instance: channel_10
  create_hier_cell_channel_10 $hier_obj channel_10

  # Create instance: channel_20
  create_hier_cell_channel_20 $hier_obj channel_20

  # Create instance: channel_30
  create_hier_cell_channel_30 $hier_obj channel_30

  # Create instance: axi_interconnect_hpm, and set properties
  set axi_interconnect_hpm [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect_hpm ]
  set_property -dict [list \
    CONFIG.NUM_MI {4} \
    CONFIG.STRATEGY {1} \
  ] $axi_interconnect_hpm


  # Create instance: axi_interconnect_hps, and set properties
  set axi_interconnect_hps [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect_hps ]
  set_property -dict [list \
    CONFIG.M00_HAS_DATA_FIFO {1} \
    CONFIG.NUM_MI {1} \
    CONFIG.NUM_SI {4} \
    CONFIG.S00_HAS_DATA_FIFO {0} \
    CONFIG.S01_HAS_DATA_FIFO {0} \
    CONFIG.S02_HAS_DATA_FIFO {0} \
    CONFIG.S03_HAS_DATA_FIFO {0} \
    CONFIG.STRATEGY {0} \
  ] $axi_interconnect_hps


  # Create instance: concat_irq, and set properties
  set concat_irq [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 concat_irq ]
  set_property CONFIG.NUM_PORTS {4} $concat_irq


  # Create instance: proc_sys_reset_adc0, and set properties
  set proc_sys_reset_adc0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_adc0 ]

  # Create instance: proc_sys_reset_adc1, and set properties
  set proc_sys_reset_adc1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_adc1 ]

  # Create instance: proc_sys_reset_adc2, and set properties
  set proc_sys_reset_adc2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_adc2 ]

  # Create instance: proc_sys_reset_adc3, and set properties
  set proc_sys_reset_adc3 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_adc3 ]

  # Create interface connections
  connect_bd_intf_net -intf_net Conn1 [get_bd_intf_pins S_AXIS_ADC_20_IM] [get_bd_intf_pins channel_20/S_AXIS_IM]
  connect_bd_intf_net -intf_net Conn2 [get_bd_intf_pins S_AXIS_ADC_20_RE] [get_bd_intf_pins channel_20/S_AXIS_RE]
  connect_bd_intf_net -intf_net Conn3 [get_bd_intf_pins S_AXIS_ADC_30_IM] [get_bd_intf_pins channel_30/S_AXIS_IM]
  connect_bd_intf_net -intf_net Conn4 [get_bd_intf_pins S_AXIS_ADC_30_RE] [get_bd_intf_pins channel_30/S_AXIS_RE]
  connect_bd_intf_net -intf_net S00_AXI_3 [get_bd_intf_pins S_AXI] [get_bd_intf_pins axi_interconnect_hpm/S00_AXI]
  connect_bd_intf_net -intf_net S_AXIS_ADC_10_IM_1 [get_bd_intf_pins S_AXIS_ADC_10_IM] [get_bd_intf_pins channel_10/S_AXIS_IM]
  connect_bd_intf_net -intf_net S_AXIS_ADC_10_RE_1 [get_bd_intf_pins S_AXIS_ADC_10_RE] [get_bd_intf_pins channel_10/S_AXIS_RE]
  connect_bd_intf_net -intf_net S_AXI_1 [get_bd_intf_pins axi_interconnect_hpm/M01_AXI] [get_bd_intf_pins channel_10/S_AXI]
  connect_bd_intf_net -intf_net axi_interconnect_1_M00_AXI [get_bd_intf_pins axi_interconnect_hpm/M00_AXI] [get_bd_intf_pins channel_00/S_AXI]
  connect_bd_intf_net -intf_net axi_interconnect_hpm_M02_AXI [get_bd_intf_pins axi_interconnect_hpm/M02_AXI] [get_bd_intf_pins channel_20/S_AXI]
  connect_bd_intf_net -intf_net axi_interconnect_hpm_M03_AXI [get_bd_intf_pins axi_interconnect_hpm/M03_AXI] [get_bd_intf_pins channel_30/S_AXI]
  connect_bd_intf_net -intf_net axi_interconnect_hps1_M00_AXI [get_bd_intf_pins M_AXI] [get_bd_intf_pins axi_interconnect_hps/M00_AXI]
  connect_bd_intf_net -intf_net axi_interconnect_hps_M00_AXI [get_bd_intf_pins axi_interconnect_hps/S00_AXI] [get_bd_intf_pins channel_00/M_AXI]
  connect_bd_intf_net -intf_net channel_10_M_AXI [get_bd_intf_pins axi_interconnect_hps/S01_AXI] [get_bd_intf_pins channel_10/M_AXI]
  connect_bd_intf_net -intf_net channel_226_M_AXI [get_bd_intf_pins axi_interconnect_hps/S02_AXI] [get_bd_intf_pins channel_20/M_AXI]
  connect_bd_intf_net -intf_net channel_227_M_AXI [get_bd_intf_pins axi_interconnect_hps/S03_AXI] [get_bd_intf_pins channel_30/M_AXI]
  connect_bd_intf_net -intf_net rfdc_m00_axis [get_bd_intf_pins S_AXIS_ADC_00_RE] [get_bd_intf_pins channel_00/S_AXIS_RE]
  connect_bd_intf_net -intf_net rfdc_m01_axis [get_bd_intf_pins S_AXIS_ADC_00_IM] [get_bd_intf_pins channel_00/S_AXIS_IM]

  # Create port connections
  connect_bd_net -net channel_10_irq [get_bd_pins channel_10/irq] [get_bd_pins concat_irq/In1]
  connect_bd_net -net channel_226_irq [get_bd_pins channel_20/irq] [get_bd_pins concat_irq/In2]
  connect_bd_net -net channel_227_irq [get_bd_pins channel_30/irq] [get_bd_pins concat_irq/In3]
  connect_bd_net -net concat_irq1_dout [get_bd_pins concat_irq/dout] [get_bd_pins irq]
  connect_bd_net -net concat_irq_dout [get_bd_pins channel_00/irq] [get_bd_pins concat_irq/In0]
  connect_bd_net -net proc_sys_reset_1_peripheral_aresetn [get_bd_pins m_axis_aresetn] [get_bd_pins channel_00/m_axis_aresetn] [get_bd_pins channel_10/m_axis_aresetn] [get_bd_pins channel_20/m_axis_aresetn] [get_bd_pins channel_30/m_axis_aresetn] [get_bd_pins axi_interconnect_hps/ARESETN] [get_bd_pins axi_interconnect_hps/S00_ARESETN] [get_bd_pins axi_interconnect_hps/S01_ARESETN] [get_bd_pins axi_interconnect_hps/S02_ARESETN] [get_bd_pins axi_interconnect_hps/S03_ARESETN] [get_bd_pins axi_interconnect_hps/M00_ARESETN]
  connect_bd_net -net proc_sys_reset_adc0_peripheral_aresetn [get_bd_pins proc_sys_reset_adc0/peripheral_aresetn] [get_bd_pins aresetn_adc0] [get_bd_pins channel_00/s_axis_aresetn]
  connect_bd_net -net proc_sys_reset_adc2_peripheral_aresetn [get_bd_pins proc_sys_reset_adc1/peripheral_aresetn] [get_bd_pins aresetn_adc1] [get_bd_pins channel_10/s_axis_aresetn]
  connect_bd_net -net proc_sys_reset_adc2_peripheral_aresetn1 [get_bd_pins proc_sys_reset_adc2/peripheral_aresetn] [get_bd_pins aresetn_adc2] [get_bd_pins channel_20/s_axis_aresetn]
  connect_bd_net -net proc_sys_reset_adc3_peripheral_aresetn [get_bd_pins proc_sys_reset_adc3/peripheral_aresetn] [get_bd_pins aresetn_adc3] [get_bd_pins channel_30/s_axis_aresetn]
  connect_bd_net -net rfdc_clk_adc0 [get_bd_pins clk_adc0] [get_bd_pins channel_00/s_axis_aclk] [get_bd_pins proc_sys_reset_adc0/slowest_sync_clk]
  connect_bd_net -net rfdc_clk_adc2 [get_bd_pins clk_adc1] [get_bd_pins channel_10/s_axis_aclk] [get_bd_pins proc_sys_reset_adc1/slowest_sync_clk]
  connect_bd_net -net rst_ps8_0_99M_peripheral_aresetn [get_bd_pins s_axi_aresetn] [get_bd_pins channel_00/s_axi_aresetn] [get_bd_pins channel_10/s_axi_aresetn] [get_bd_pins channel_20/s_axi_aresetn] [get_bd_pins channel_30/s_axi_aresetn] [get_bd_pins axi_interconnect_hpm/ARESETN] [get_bd_pins axi_interconnect_hpm/S00_ARESETN] [get_bd_pins axi_interconnect_hpm/M00_ARESETN] [get_bd_pins axi_interconnect_hpm/M01_ARESETN] [get_bd_pins axi_interconnect_hpm/M02_ARESETN] [get_bd_pins axi_interconnect_hpm/M03_ARESETN]
  connect_bd_net -net s_axis_aclk_1 [get_bd_pins clk_adc2] [get_bd_pins channel_20/s_axis_aclk] [get_bd_pins proc_sys_reset_adc2/slowest_sync_clk]
  connect_bd_net -net s_axis_aclk_3 [get_bd_pins clk_adc3] [get_bd_pins channel_30/s_axis_aclk] [get_bd_pins proc_sys_reset_adc3/slowest_sync_clk]
  connect_bd_net -net zynq_ultra_ps_e_0_pl_clk0 [get_bd_pins s_axi_aclk] [get_bd_pins channel_00/s_axi_aclk] [get_bd_pins channel_10/s_axi_aclk] [get_bd_pins channel_20/s_axi_aclk] [get_bd_pins channel_30/s_axi_aclk] [get_bd_pins axi_interconnect_hpm/ACLK] [get_bd_pins axi_interconnect_hpm/S00_ACLK] [get_bd_pins axi_interconnect_hpm/M00_ACLK] [get_bd_pins axi_interconnect_hpm/M01_ACLK] [get_bd_pins axi_interconnect_hpm/M02_ACLK] [get_bd_pins axi_interconnect_hpm/M03_ACLK]
  connect_bd_net -net zynq_ultra_ps_e_0_pl_clk1 [get_bd_pins m_axis_aclk] [get_bd_pins channel_00/m_axis_aclk] [get_bd_pins channel_10/m_axis_aclk] [get_bd_pins channel_20/m_axis_aclk] [get_bd_pins channel_30/m_axis_aclk] [get_bd_pins axi_interconnect_hps/ACLK] [get_bd_pins axi_interconnect_hps/S00_ACLK] [get_bd_pins axi_interconnect_hps/S01_ACLK] [get_bd_pins axi_interconnect_hps/S02_ACLK] [get_bd_pins axi_interconnect_hps/S03_ACLK] [get_bd_pins axi_interconnect_hps/M00_ACLK]
  connect_bd_net -net zynq_ultra_ps_e_0_pl_resetn0 [get_bd_pins ext_reset] [get_bd_pins proc_sys_reset_adc0/ext_reset_in] [get_bd_pins proc_sys_reset_adc1/ext_reset_in] [get_bd_pins proc_sys_reset_adc2/ext_reset_in] [get_bd_pins proc_sys_reset_adc3/ext_reset_in]

  # Restore current instance
  current_bd_instance $oldCurInst
}

# Hierarchical cell: radio
proc create_hier_cell_radio { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_radio() - Empty argument(s)!"}
     return
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

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins
  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 M03_AXI

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 M_AXI

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 S_AXI

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 adc2_clk

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 dac2_clk

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:display_usp_rf_data_converter:diff_pins_rtl:1.0 sysref_in

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 vout00

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 vout10

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 vout20

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 vout30

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 vin00

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 vin01

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 vin10

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 vin11

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 vin20

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 vin21

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 vin30

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 vin31


  # Create pins
  create_bd_pin -dir O -from 8 -to 0 dout
  create_bd_pin -dir I -type rst ext_reset
  create_bd_pin -dir I -type clk m_axi_aclk
  create_bd_pin -dir I -type rst m_axi_aresetn
  create_bd_pin -dir I -type clk s_axi_aclk
  create_bd_pin -dir I -type rst s_axi_aresetn

  # Create instance: receiver
  create_hier_cell_receiver $hier_obj receiver

  # Create instance: transmitter
  create_hier_cell_transmitter $hier_obj transmitter

  # Create instance: axi_interconnect_ps, and set properties
  set axi_interconnect_ps [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect_ps ]
  set_property -dict [list \
    CONFIG.NUM_MI {4} \
    CONFIG.STRATEGY {1} \
  ] $axi_interconnect_ps


  # Create instance: rfdc, and set properties
  set rfdc [ create_bd_cell -type ip -vlnv xilinx.com:ip:usp_rf_data_converter:2.6 rfdc ]
  set_property -dict [list \
    CONFIG.ADC0_Clock_Dist {0} \
    CONFIG.ADC0_Clock_Source {2} \
    CONFIG.ADC0_Multi_Tile_Sync {true} \
    CONFIG.ADC0_Outclk_Freq {307.200} \
    CONFIG.ADC0_PLL_Enable {true} \
    CONFIG.ADC0_Refclk_Freq {245.760} \
    CONFIG.ADC0_Sampling_Rate {2.4576} \
    CONFIG.ADC1_Clock_Dist {0} \
    CONFIG.ADC1_Clock_Source {2} \
    CONFIG.ADC1_Multi_Tile_Sync {true} \
    CONFIG.ADC1_Outclk_Freq {307.200} \
    CONFIG.ADC1_PLL_Enable {true} \
    CONFIG.ADC1_Refclk_Freq {245.760} \
    CONFIG.ADC1_Sampling_Rate {2.4576} \
    CONFIG.ADC2_Clock_Dist {1} \
    CONFIG.ADC2_Clock_Source {2} \
    CONFIG.ADC2_Multi_Tile_Sync {true} \
    CONFIG.ADC2_Outclk_Freq {307.200} \
    CONFIG.ADC2_PLL_Enable {true} \
    CONFIG.ADC2_Refclk_Div {1} \
    CONFIG.ADC2_Refclk_Freq {245.760} \
    CONFIG.ADC2_Sampling_Rate {2.4576} \
    CONFIG.ADC3_Clock_Dist {0} \
    CONFIG.ADC3_Clock_Source {2} \
    CONFIG.ADC3_Multi_Tile_Sync {true} \
    CONFIG.ADC3_Outclk_Freq {307.200} \
    CONFIG.ADC3_PLL_Enable {true} \
    CONFIG.ADC3_Refclk_Freq {245.760} \
    CONFIG.ADC3_Sampling_Rate {2.4576} \
    CONFIG.ADC_Data_Type00 {1} \
    CONFIG.ADC_Data_Type01 {1} \
    CONFIG.ADC_Data_Type10 {1} \
    CONFIG.ADC_Data_Type11 {1} \
    CONFIG.ADC_Data_Type20 {1} \
    CONFIG.ADC_Data_Type21 {1} \
    CONFIG.ADC_Data_Type30 {1} \
    CONFIG.ADC_Data_Type31 {1} \
    CONFIG.ADC_Data_Width00 {8} \
    CONFIG.ADC_Data_Width01 {8} \
    CONFIG.ADC_Data_Width10 {8} \
    CONFIG.ADC_Data_Width11 {8} \
    CONFIG.ADC_Data_Width20 {8} \
    CONFIG.ADC_Data_Width21 {8} \
    CONFIG.ADC_Data_Width30 {8} \
    CONFIG.ADC_Data_Width31 {8} \
    CONFIG.ADC_Decimation_Mode00 {2} \
    CONFIG.ADC_Decimation_Mode01 {2} \
    CONFIG.ADC_Decimation_Mode10 {2} \
    CONFIG.ADC_Decimation_Mode11 {2} \
    CONFIG.ADC_Decimation_Mode20 {2} \
    CONFIG.ADC_Decimation_Mode21 {2} \
    CONFIG.ADC_Decimation_Mode30 {2} \
    CONFIG.ADC_Decimation_Mode31 {2} \
    CONFIG.ADC_Mixer_Mode00 {0} \
    CONFIG.ADC_Mixer_Mode01 {0} \
    CONFIG.ADC_Mixer_Mode10 {0} \
    CONFIG.ADC_Mixer_Mode11 {0} \
    CONFIG.ADC_Mixer_Mode20 {0} \
    CONFIG.ADC_Mixer_Mode21 {0} \
    CONFIG.ADC_Mixer_Mode30 {0} \
    CONFIG.ADC_Mixer_Mode31 {0} \
    CONFIG.ADC_Mixer_Type00 {2} \
    CONFIG.ADC_Mixer_Type01 {2} \
    CONFIG.ADC_Mixer_Type10 {2} \
    CONFIG.ADC_Mixer_Type11 {2} \
    CONFIG.ADC_Mixer_Type20 {2} \
    CONFIG.ADC_Mixer_Type21 {2} \
    CONFIG.ADC_Mixer_Type30 {2} \
    CONFIG.ADC_Mixer_Type31 {2} \
    CONFIG.ADC_Slice01_Enable {true} \
    CONFIG.ADC_Slice02_Enable {false} \
    CONFIG.ADC_Slice03_Enable {false} \
    CONFIG.ADC_Slice10_Enable {true} \
    CONFIG.ADC_Slice11_Enable {true} \
    CONFIG.ADC_Slice12_Enable {false} \
    CONFIG.ADC_Slice13_Enable {false} \
    CONFIG.ADC_Slice20_Enable {true} \
    CONFIG.ADC_Slice21_Enable {true} \
    CONFIG.ADC_Slice22_Enable {false} \
    CONFIG.ADC_Slice23_Enable {false} \
    CONFIG.ADC_Slice30_Enable {true} \
    CONFIG.ADC_Slice31_Enable {true} \
    CONFIG.ADC_Slice32_Enable {false} \
    CONFIG.ADC_Slice33_Enable {false} \
    CONFIG.DAC0_Clock_Dist {0} \
    CONFIG.DAC0_Clock_Source {6} \
    CONFIG.DAC0_Multi_Tile_Sync {true} \
    CONFIG.DAC0_Outclk_Freq {307.200} \
    CONFIG.DAC0_PLL_Enable {true} \
    CONFIG.DAC0_Refclk_Freq {245.760} \
    CONFIG.DAC0_Sampling_Rate {4.9152} \
    CONFIG.DAC1_Clock_Source {6} \
    CONFIG.DAC1_Multi_Tile_Sync {true} \
    CONFIG.DAC1_Outclk_Freq {307.200} \
    CONFIG.DAC1_PLL_Enable {true} \
    CONFIG.DAC1_Refclk_Freq {245.760} \
    CONFIG.DAC1_Sampling_Rate {4.9152} \
    CONFIG.DAC2_Clock_Dist {1} \
    CONFIG.DAC2_Clock_Source {6} \
    CONFIG.DAC2_Multi_Tile_Sync {true} \
    CONFIG.DAC2_Outclk_Freq {307.200} \
    CONFIG.DAC2_PLL_Enable {true} \
    CONFIG.DAC2_Refclk_Freq {245.760} \
    CONFIG.DAC2_Sampling_Rate {4.9152} \
    CONFIG.DAC3_Clock_Source {6} \
    CONFIG.DAC3_Multi_Tile_Sync {true} \
    CONFIG.DAC3_Outclk_Freq {307.200} \
    CONFIG.DAC3_PLL_Enable {true} \
    CONFIG.DAC3_Refclk_Freq {245.760} \
    CONFIG.DAC3_Sampling_Rate {4.9152} \
    CONFIG.DAC_Data_Type20 {0} \
    CONFIG.DAC_Interpolation_Mode00 {2} \
    CONFIG.DAC_Interpolation_Mode10 {2} \
    CONFIG.DAC_Interpolation_Mode20 {2} \
    CONFIG.DAC_Interpolation_Mode30 {2} \
    CONFIG.DAC_Mixer_Mode00 {0} \
    CONFIG.DAC_Mixer_Mode10 {0} \
    CONFIG.DAC_Mixer_Mode20 {0} \
    CONFIG.DAC_Mixer_Mode30 {0} \
    CONFIG.DAC_Mixer_Type00 {2} \
    CONFIG.DAC_Mixer_Type10 {2} \
    CONFIG.DAC_Mixer_Type20 {2} \
    CONFIG.DAC_Mixer_Type30 {2} \
    CONFIG.DAC_Slice00_Enable {true} \
    CONFIG.DAC_Slice02_Enable {false} \
    CONFIG.DAC_Slice10_Enable {true} \
    CONFIG.DAC_Slice12_Enable {false} \
    CONFIG.DAC_Slice20_Enable {true} \
    CONFIG.DAC_Slice22_Enable {false} \
    CONFIG.DAC_Slice30_Enable {true} \
  ] $rfdc


  # Create instance: xlconcat_2, and set properties
  set xlconcat_2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 xlconcat_2 ]

  # Create interface connections
  connect_bd_intf_net -intf_net Conn1 [get_bd_intf_pins vout30] [get_bd_intf_pins rfdc/vout30]
  connect_bd_intf_net -intf_net Conn2 [get_bd_intf_pins vout00] [get_bd_intf_pins rfdc/vout00]
  connect_bd_intf_net -intf_net Conn3 [get_bd_intf_pins rfdc/adc2_clk] [get_bd_intf_pins adc2_clk]
  connect_bd_intf_net -intf_net Conn4 [get_bd_intf_pins vout10] [get_bd_intf_pins rfdc/vout10]
  connect_bd_intf_net -intf_net Conn6 [get_bd_intf_pins dac2_clk] [get_bd_intf_pins rfdc/dac2_clk]
  connect_bd_intf_net -intf_net Conn9 [get_bd_intf_pins vout20] [get_bd_intf_pins rfdc/vout20]
  connect_bd_intf_net -intf_net Conn10 [get_bd_intf_pins M03_AXI] [get_bd_intf_pins axi_interconnect_ps/M03_AXI]
  connect_bd_intf_net -intf_net Conn11 [get_bd_intf_pins rfdc/vin00] [get_bd_intf_pins vin00]
  connect_bd_intf_net -intf_net Conn12 [get_bd_intf_pins rfdc/vin01] [get_bd_intf_pins vin01]
  connect_bd_intf_net -intf_net Conn13 [get_bd_intf_pins rfdc/vin10] [get_bd_intf_pins vin10]
  connect_bd_intf_net -intf_net Conn14 [get_bd_intf_pins rfdc/vin11] [get_bd_intf_pins vin11]
  connect_bd_intf_net -intf_net Conn15 [get_bd_intf_pins rfdc/vin20] [get_bd_intf_pins vin20]
  connect_bd_intf_net -intf_net Conn16 [get_bd_intf_pins rfdc/vin21] [get_bd_intf_pins vin21]
  connect_bd_intf_net -intf_net Conn17 [get_bd_intf_pins rfdc/vin30] [get_bd_intf_pins vin30]
  connect_bd_intf_net -intf_net Conn18 [get_bd_intf_pins rfdc/vin31] [get_bd_intf_pins vin31]
  connect_bd_intf_net -intf_net S00_AXI_1 [get_bd_intf_pins axi_interconnect_ps/M00_AXI] [get_bd_intf_pins transmitter/S_AXI]
  connect_bd_intf_net -intf_net S00_AXI_3 [get_bd_intf_pins axi_interconnect_ps/M01_AXI] [get_bd_intf_pins receiver/S_AXI]
  connect_bd_intf_net -intf_net S_AXIS_ADC_00_IM_1 [get_bd_intf_pins receiver/S_AXIS_ADC_00_IM] [get_bd_intf_pins rfdc/m01_axis]
  connect_bd_intf_net -intf_net S_AXIS_ADC_00_RE_1 [get_bd_intf_pins receiver/S_AXIS_ADC_00_RE] [get_bd_intf_pins rfdc/m00_axis]
  connect_bd_intf_net -intf_net S_AXIS_ADC_20_IM_1 [get_bd_intf_pins receiver/S_AXIS_ADC_20_IM] [get_bd_intf_pins rfdc/m21_axis]
  connect_bd_intf_net -intf_net S_AXIS_ADC_30_IM_1 [get_bd_intf_pins receiver/S_AXIS_ADC_30_IM] [get_bd_intf_pins rfdc/m31_axis]
  connect_bd_intf_net -intf_net axi_hpm1_fpd_M02_AXI [get_bd_intf_pins S_AXI] [get_bd_intf_pins axi_interconnect_ps/S00_AXI]
  connect_bd_intf_net -intf_net axi_interconnect_hps1_M00_AXI [get_bd_intf_pins M_AXI] [get_bd_intf_pins receiver/M_AXI]
  connect_bd_intf_net -intf_net axi_interconnect_ps_M02_AXI [get_bd_intf_pins axi_interconnect_ps/M02_AXI] [get_bd_intf_pins rfdc/s_axi]
  connect_bd_intf_net -intf_net rfdc_m20_axis [get_bd_intf_pins receiver/S_AXIS_ADC_20_RE] [get_bd_intf_pins rfdc/m20_axis]
  connect_bd_intf_net -intf_net rfdc_m30_axis [get_bd_intf_pins receiver/S_AXIS_ADC_30_RE] [get_bd_intf_pins rfdc/m30_axis]
  connect_bd_intf_net -intf_net sysref_in_1 [get_bd_intf_pins sysref_in] [get_bd_intf_pins rfdc/sysref_in]
  connect_bd_intf_net -intf_net transmitter_M_AXIS [get_bd_intf_pins rfdc/s30_axis] [get_bd_intf_pins transmitter/M_AXIS_DAC_30]
  connect_bd_intf_net -intf_net transmitter_M_AXIS2 [get_bd_intf_pins rfdc/s20_axis] [get_bd_intf_pins transmitter/M_AXIS_DAC_20]
  connect_bd_intf_net -intf_net transmitter_M_AXIS_DAC_00 [get_bd_intf_pins rfdc/s00_axis] [get_bd_intf_pins transmitter/M_AXIS_DAC_00]
  connect_bd_intf_net -intf_net transmitter_M_AXIS_DAC_10 [get_bd_intf_pins rfdc/s10_axis] [get_bd_intf_pins transmitter/M_AXIS_DAC_10]
  connect_bd_intf_net -intf_net usp_rf_data_converter_0_m10_axis [get_bd_intf_pins receiver/S_AXIS_ADC_10_RE] [get_bd_intf_pins rfdc/m10_axis]
  connect_bd_intf_net -intf_net usp_rf_data_converter_0_m11_axis [get_bd_intf_pins receiver/S_AXIS_ADC_10_IM] [get_bd_intf_pins rfdc/m11_axis]

  # Create port connections
  connect_bd_net -net clk_adc2_1 [get_bd_pins rfdc/clk_adc2] [get_bd_pins receiver/clk_adc2] [get_bd_pins rfdc/m2_axis_aclk]
  connect_bd_net -net clk_adc3_1 [get_bd_pins rfdc/clk_adc3] [get_bd_pins receiver/clk_adc3] [get_bd_pins rfdc/m3_axis_aclk]
  connect_bd_net -net proc_sys_reset_1_peripheral_aresetn [get_bd_pins m_axi_aresetn] [get_bd_pins receiver/m_axis_aresetn]
  connect_bd_net -net receiver_aresetn_adc0 [get_bd_pins receiver/aresetn_adc0] [get_bd_pins rfdc/m0_axis_aresetn]
  connect_bd_net -net receiver_aresetn_adc2 [get_bd_pins receiver/aresetn_adc1] [get_bd_pins rfdc/m1_axis_aresetn]
  connect_bd_net -net receiver_aresetn_adc3 [get_bd_pins receiver/aresetn_adc2] [get_bd_pins rfdc/m2_axis_aresetn]
  connect_bd_net -net receiver_aresetn_adc4 [get_bd_pins receiver/aresetn_adc3] [get_bd_pins rfdc/m3_axis_aresetn]
  connect_bd_net -net receiver_irq [get_bd_pins receiver/irq] [get_bd_pins xlconcat_2/In1]
  connect_bd_net -net rfdc_clk_dac0 [get_bd_pins rfdc/clk_dac0] [get_bd_pins transmitter/clk_dac0] [get_bd_pins rfdc/s0_axis_aclk]
  connect_bd_net -net rfdc_clk_dac1 [get_bd_pins rfdc/clk_dac1] [get_bd_pins transmitter/clk_dac1] [get_bd_pins rfdc/s1_axis_aclk]
  connect_bd_net -net rfdc_clk_dac2 [get_bd_pins rfdc/clk_dac2] [get_bd_pins transmitter/clk_dac2] [get_bd_pins rfdc/s2_axis_aclk]
  connect_bd_net -net rfdc_clk_dac3 [get_bd_pins rfdc/clk_dac3] [get_bd_pins transmitter/clk_dac3] [get_bd_pins rfdc/s3_axis_aclk]
  connect_bd_net -net rfdc_irq [get_bd_pins rfdc/irq] [get_bd_pins xlconcat_2/In0]
  connect_bd_net -net rst_ps8_0_99M_peripheral_aresetn [get_bd_pins s_axi_aresetn] [get_bd_pins receiver/s_axi_aresetn] [get_bd_pins transmitter/s_axi_aresetn] [get_bd_pins axi_interconnect_ps/ARESETN] [get_bd_pins axi_interconnect_ps/S00_ARESETN] [get_bd_pins axi_interconnect_ps/M00_ARESETN] [get_bd_pins axi_interconnect_ps/M01_ARESETN] [get_bd_pins axi_interconnect_ps/M02_ARESETN] [get_bd_pins axi_interconnect_ps/M03_ARESETN] [get_bd_pins rfdc/s_axi_aresetn]
  connect_bd_net -net transmitter_aresetn_dac0 [get_bd_pins transmitter/aresetn_dac0] [get_bd_pins rfdc/s0_axis_aresetn]
  connect_bd_net -net transmitter_aresetn_dac1 [get_bd_pins transmitter/aresetn_dac1] [get_bd_pins rfdc/s1_axis_aresetn]
  connect_bd_net -net transmitter_peripheral_aresetn [get_bd_pins transmitter/aresetn_dac2] [get_bd_pins rfdc/s2_axis_aresetn]
  connect_bd_net -net transmitter_peripheral_aresetn1 [get_bd_pins transmitter/aresetn_dac3] [get_bd_pins rfdc/s3_axis_aresetn]
  connect_bd_net -net usp_rf_data_converter_0_clk_adc0 [get_bd_pins rfdc/clk_adc0] [get_bd_pins receiver/clk_adc0] [get_bd_pins rfdc/m0_axis_aclk]
  connect_bd_net -net usp_rf_data_converter_0_clk_adc1 [get_bd_pins rfdc/clk_adc1] [get_bd_pins receiver/clk_adc1] [get_bd_pins rfdc/m1_axis_aclk]
  connect_bd_net -net xlconcat_2_dout [get_bd_pins xlconcat_2/dout] [get_bd_pins dout]
  connect_bd_net -net zynq_ultra_ps_e_0_pl_clk0 [get_bd_pins s_axi_aclk] [get_bd_pins receiver/s_axi_aclk] [get_bd_pins transmitter/s_axi_aclk] [get_bd_pins axi_interconnect_ps/ACLK] [get_bd_pins axi_interconnect_ps/S00_ACLK] [get_bd_pins axi_interconnect_ps/M00_ACLK] [get_bd_pins axi_interconnect_ps/M01_ACLK] [get_bd_pins axi_interconnect_ps/M02_ACLK] [get_bd_pins axi_interconnect_ps/M03_ACLK] [get_bd_pins rfdc/s_axi_aclk]
  connect_bd_net -net zynq_ultra_ps_e_0_pl_clk1 [get_bd_pins m_axi_aclk] [get_bd_pins receiver/m_axis_aclk]
  connect_bd_net -net zynq_ultra_ps_e_0_pl_resetn0 [get_bd_pins ext_reset] [get_bd_pins receiver/ext_reset] [get_bd_pins transmitter/ext_reset]

  # Perform GUI Layout
  regenerate_bd_layout -hierarchy [get_bd_cells /radio] -layout_string {
   "ActiveEmotionalView":"Default View",
   "Default View_ScaleFactor":"0.512114",
   "Default View_TopLeft":"-309,4",
   "ExpandedHierarchyInLayout":"",
   "guistr":"# # String gsaved with Nlview 7.5.8 2022-09-21 7111 VDI=41 GEI=38 GUI=JA:10.0 TLS
#  -string -flagsOSRD
preplace port M03_AXI -pg 1 -lvl 5 -x 1750 -y 210 -defaultsOSRD
preplace port M_AXI -pg 1 -lvl 5 -x 1750 -y 550 -defaultsOSRD
preplace port S_AXI -pg 1 -lvl 0 -x 0 -y 60 -defaultsOSRD
preplace port adc2_clk -pg 1 -lvl 0 -x 0 -y 420 -defaultsOSRD
preplace port dac2_clk -pg 1 -lvl 0 -x 0 -y 440 -defaultsOSRD
preplace port sysref_in -pg 1 -lvl 0 -x 0 -y 620 -defaultsOSRD
preplace port vout00 -pg 1 -lvl 5 -x 1750 -y 370 -defaultsOSRD
preplace port vout10 -pg 1 -lvl 5 -x 1750 -y 810 -defaultsOSRD
preplace port vout20 -pg 1 -lvl 5 -x 1750 -y 830 -defaultsOSRD
preplace port vout30 -pg 1 -lvl 5 -x 1750 -y 850 -defaultsOSRD
preplace port vin00 -pg 1 -lvl 0 -x 0 -y 460 -defaultsOSRD
preplace port vin01 -pg 1 -lvl 0 -x 0 -y 480 -defaultsOSRD
preplace port vin10 -pg 1 -lvl 0 -x 0 -y 500 -defaultsOSRD
preplace port vin11 -pg 1 -lvl 0 -x 0 -y 520 -defaultsOSRD
preplace port vin20 -pg 1 -lvl 0 -x 0 -y 540 -defaultsOSRD
preplace port vin21 -pg 1 -lvl 0 -x 0 -y 560 -defaultsOSRD
preplace port vin30 -pg 1 -lvl 0 -x 0 -y 580 -defaultsOSRD
preplace port vin31 -pg 1 -lvl 0 -x 0 -y 600 -defaultsOSRD
preplace port port-id_ext_reset -pg 1 -lvl 0 -x 0 -y 640 -defaultsOSRD
preplace port port-id_m_axi_aclk -pg 1 -lvl 0 -x 0 -y 360 -defaultsOSRD
preplace port port-id_m_axi_aresetn -pg 1 -lvl 0 -x 0 -y 380 -defaultsOSRD
preplace port port-id_s_axi_aclk -pg 1 -lvl 0 -x 0 -y 80 -defaultsOSRD
preplace port port-id_s_axi_aresetn -pg 1 -lvl 0 -x 0 -y 100 -defaultsOSRD
preplace portBus dout -pg 1 -lvl 5 -x 1750 -y 290 -defaultsOSRD
preplace inst receiver -pg 1 -lvl 4 -x 1510 -y 600 -defaultsOSRD
preplace inst transmitter -pg 1 -lvl 2 -x 550 -y 800 -defaultsOSRD
preplace inst axi_interconnect_ps -pg 1 -lvl 1 -x 180 -y 180 -defaultsOSRD
preplace inst rfdc -pg 1 -lvl 3 -x 1000 -y 670 -defaultsOSRD
preplace inst xlconcat_2 -pg 1 -lvl 4 -x 1510 -y 290 -defaultsOSRD
preplace netloc clk_adc2_1 1 2 2 860 1080 1220
preplace netloc clk_adc3_1 1 2 2 850 1090 1260
preplace netloc proc_sys_reset_1_peripheral_aresetn 1 0 4 20J 1190 NJ 1190 NJ 1190 1290J
preplace netloc receiver_aresetn_adc0 1 2 3 860 160 NJ 160 1720
preplace netloc receiver_aresetn_adc2 1 2 3 830 190 NJ 190 1700
preplace netloc receiver_aresetn_adc3 1 2 3 840 200 NJ 200 1710
preplace netloc receiver_aresetn_adc4 1 2 3 810 220 NJ 220 1690
preplace netloc receiver_irq 1 3 2 1340 360 1680
preplace netloc rfdc_clk_dac0 1 1 3 370 920 730 1100 1170
preplace netloc rfdc_clk_dac1 1 1 3 380 940 800 1120 1160
preplace netloc rfdc_clk_dac2 1 1 3 390 980 790 1110 1140
preplace netloc rfdc_clk_dac3 1 1 3 400 1020 740 1130 1150
preplace netloc rfdc_irq 1 3 1 1180 280n
preplace netloc rst_ps8_0_99M_peripheral_aresetn 1 0 4 20 370 360 660 780 1140 1280J
preplace netloc transmitter_aresetn_dac0 1 2 1 800 810n
preplace netloc transmitter_aresetn_dac1 1 2 1 770 830n
preplace netloc transmitter_peripheral_aresetn 1 2 1 750 850n
preplace netloc transmitter_peripheral_aresetn1 1 2 1 740 870n
preplace netloc usp_rf_data_converter_0_clk_adc0 1 2 2 820 1160 1230
preplace netloc usp_rf_data_converter_0_clk_adc1 1 2 2 830 1150 1250
preplace netloc xlconcat_2_dout 1 4 1 NJ 290
preplace netloc zynq_ultra_ps_e_0_pl_clk0 1 0 4 30 590 350 640 760 1180 1300J
preplace netloc zynq_ultra_ps_e_0_pl_clk1 1 0 4 NJ 360 NJ 360 700J 260 1240J
preplace netloc zynq_ultra_ps_e_0_pl_resetn0 1 0 4 NJ 640 340 670 700J 1170 1270J
preplace netloc Conn1 1 3 2 1190J 850 NJ
preplace netloc Conn2 1 3 2 1190J 370 NJ
preplace netloc Conn3 1 0 3 NJ 420 NJ 420 NJ
preplace netloc Conn4 1 3 2 1210J 820 1720J
preplace netloc Conn6 1 0 3 NJ 440 NJ 440 NJ
preplace netloc Conn9 1 3 2 1200J 830 NJ
preplace netloc Conn10 1 1 4 NJ 210 NJ 210 NJ 210 NJ
preplace netloc Conn11 1 0 3 NJ 460 NJ 460 NJ
preplace netloc Conn12 1 0 3 NJ 480 NJ 480 NJ
preplace netloc Conn13 1 0 3 NJ 500 NJ 500 NJ
preplace netloc Conn14 1 0 3 NJ 520 NJ 520 NJ
preplace netloc Conn15 1 0 3 NJ 540 NJ 540 NJ
preplace netloc Conn16 1 0 3 NJ 560 NJ 560 NJ
preplace netloc Conn17 1 0 3 NJ 580 NJ 580 NJ
preplace netloc Conn18 1 0 3 NJ 600 NJ 600 NJ
preplace netloc S00_AXI_1 1 1 1 370 150n
preplace netloc S00_AXI_3 1 1 3 NJ 170 NJ 170 1250
preplace netloc S_AXIS_ADC_00_IM_1 1 3 1 1160 450n
preplace netloc S_AXIS_ADC_00_RE_1 1 3 1 N 470
preplace netloc S_AXIS_ADC_20_IM_1 1 3 1 1200 530n
preplace netloc S_AXIS_ADC_30_IM_1 1 3 1 1210 570n
preplace netloc axi_hpm1_fpd_M02_AXI 1 0 1 NJ 60
preplace netloc axi_interconnect_hps1_M00_AXI 1 4 1 NJ 550
preplace netloc axi_interconnect_ps_M02_AXI 1 1 2 NJ 190 750
preplace netloc rfdc_m20_axis 1 3 1 N 550
preplace netloc rfdc_m30_axis 1 3 1 N 590
preplace netloc sysref_in_1 1 0 3 NJ 620 NJ 620 NJ
preplace netloc transmitter_M_AXIS 1 2 1 800 400n
preplace netloc transmitter_M_AXIS2 1 2 1 790 380n
preplace netloc transmitter_M_AXIS_DAC_00 1 2 1 730 340n
preplace netloc transmitter_M_AXIS_DAC_10 1 2 1 770 360n
preplace netloc usp_rf_data_converter_0_m10_axis 1 3 1 N 510
preplace netloc usp_rf_data_converter_0_m11_axis 1 3 1 1170 490n
levelinfo -pg 1 0 180 550 1000 1510 1750
pagesize -pg 1 -db -bbox -sgen -160 0 1870 1200
"
}

  # Restore current instance
  current_bd_instance $oldCurInst
}

# Hierarchical cell: DSPmemory
proc create_hier_cell_DSPmemory { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_DSPmemory() - Empty argument(s)!"}
     return
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

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins
  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 C0_DDR4_S_AXI

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:ddr4_rtl:1.0 ddr4_sdram_c0

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 default_sysclk_c0_300mhz


  # Create pins
  create_bd_pin -dir O -type clk c0_ddr4_ui_clk
  create_bd_pin -dir O -from 94 -to 0 dout
  create_bd_pin -dir O -from 0 -to 0 -type rst peripheral_aresetn
  create_bd_pin -dir I src_rst

  # Create instance: DSPddr4, and set properties
  set DSPddr4 [ create_bd_cell -type ip -vlnv xilinx.com:ip:ddr4:2.2 DSPddr4 ]
  set_property -dict [list \
    CONFIG.ADDN_UI_CLKOUT1_FREQ_HZ {100} \
    CONFIG.C0.BANK_GROUP_WIDTH {2} \
    CONFIG.C0.CS_WIDTH {2} \
    CONFIG.C0.DDR4_AxiAddressWidth {32} \
    CONFIG.C0.DDR4_Clamshell {true} \
    CONFIG.C0_DDR4_BOARD_INTERFACE {ddr4_sdram_c0} \
    CONFIG.System_Clock {No_Buffer} \
  ] $DSPddr4


  # Create instance: ddr4_0_sys_reset, and set properties
  set ddr4_0_sys_reset [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 ddr4_0_sys_reset ]

  # Create instance: util_ds_buf_0, and set properties
  set util_ds_buf_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:util_ds_buf:2.2 util_ds_buf_0 ]
  set_property -dict [list \
    CONFIG.DIFF_CLK_IN_BOARD_INTERFACE {default_sysclk_c0_300mhz} \
    CONFIG.USE_BOARD_FLOW {true} \
  ] $util_ds_buf_0


  # Create instance: util_ds_buf_1, and set properties
  set util_ds_buf_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:util_ds_buf:2.2 util_ds_buf_1 ]
  set_property CONFIG.C_BUF_TYPE {BUFG} $util_ds_buf_1


  # Create instance: xlconcat_1, and set properties
  set xlconcat_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 xlconcat_1 ]
  set_property -dict [list \
    CONFIG.IN0_WIDTH {1} \
    CONFIG.IN1_WIDTH {94} \
  ] $xlconcat_1


  # Create instance: xpm_cdc_gen_1, and set properties
  set xpm_cdc_gen_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xpm_cdc_gen:1.0 xpm_cdc_gen_1 ]
  set_property -dict [list \
    CONFIG.CDC_TYPE {xpm_cdc_sync_rst} \
    CONFIG.DEST_SYNC_FF {10} \
    CONFIG.INIT_SYNC_FF {true} \
    CONFIG.REG_OUTPUT {true} \
  ] $xpm_cdc_gen_1


  # Create interface connections
  connect_bd_intf_net -intf_net axi_interconnect_0_M00_AXI1 [get_bd_intf_pins C0_DDR4_S_AXI] [get_bd_intf_pins DSPddr4/C0_DDR4_S_AXI]
  connect_bd_intf_net -intf_net ddr4_0_C0_DDR4 [get_bd_intf_pins ddr4_sdram_c0] [get_bd_intf_pins DSPddr4/C0_DDR4]
  connect_bd_intf_net -intf_net default_sysclk_c0_300mhz_1 [get_bd_intf_pins default_sysclk_c0_300mhz] [get_bd_intf_pins util_ds_buf_0/CLK_IN_D]

  # Create port connections
  connect_bd_net -net DSPddr4_c0_ddr4_ui_clk_sync_rst [get_bd_pins DSPddr4/c0_ddr4_ui_clk_sync_rst] [get_bd_pins ddr4_0_sys_reset/ext_reset_in]
  connect_bd_net -net DSPddr4_c0_init_calib_complete [get_bd_pins DSPddr4/c0_init_calib_complete] [get_bd_pins xlconcat_1/In0]
  connect_bd_net -net clk_buf_0_clk_bufg [get_bd_pins util_ds_buf_1/BUFG_O] [get_bd_pins DSPddr4/c0_sys_clk_i] [get_bd_pins xpm_cdc_gen_1/dest_clk]
  connect_bd_net -net ddr4_0_c0_ddr4_ui_clk [get_bd_pins DSPddr4/c0_ddr4_ui_clk] [get_bd_pins c0_ddr4_ui_clk] [get_bd_pins ddr4_0_sys_reset/slowest_sync_clk]
  connect_bd_net -net ddr4_0_sys_reset_peripheral_aresetn [get_bd_pins ddr4_0_sys_reset/peripheral_aresetn] [get_bd_pins peripheral_aresetn] [get_bd_pins DSPddr4/c0_ddr4_aresetn]
  connect_bd_net -net proc_sys_reset_0_bus_struct_reset [get_bd_pins src_rst] [get_bd_pins xpm_cdc_gen_1/src_rst]
  connect_bd_net -net util_ds_buf_0_IBUF_OUT [get_bd_pins util_ds_buf_0/IBUF_OUT] [get_bd_pins util_ds_buf_1/BUFG_I]
  connect_bd_net -net xlconcat_1_dout [get_bd_pins xlconcat_1/dout] [get_bd_pins dout]
  connect_bd_net -net xpm_cdc_gen_1_dest_rst_out [get_bd_pins xpm_cdc_gen_1/dest_rst_out] [get_bd_pins DSPddr4/sys_rst]

  # Restore current instance
  current_bd_instance $oldCurInst
}


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
  set Vp_Vn [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 Vp_Vn ]

  set dac2_clk [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 dac2_clk ]
  set_property -dict [ list \
   CONFIG.FREQ_HZ {409600000.0} \
   ] $dac2_clk

  set ddr4_sdram_c0 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:ddr4_rtl:1.0 ddr4_sdram_c0 ]

  set default_sysclk_c0_300mhz [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 default_sysclk_c0_300mhz ]
  set_property -dict [ list \
   CONFIG.FREQ_HZ {300000000} \
   ] $default_sysclk_c0_300mhz

  set dip_switches_8bits [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:gpio_rtl:1.0 dip_switches_8bits ]

  set push_buttons_5bits [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:gpio_rtl:1.0 push_buttons_5bits ]

  set sysref_in [ create_bd_intf_port -mode Slave -vlnv xilinx.com:display_usp_rf_data_converter:diff_pins_rtl:1.0 sysref_in ]

  set vout00 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 vout00 ]

  set vout10 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 vout10 ]

  set vout20 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 vout20 ]

  set vout30 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 vout30 ]

  set vin00 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 vin00 ]

  set vin01 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 vin01 ]

  set vin10 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 vin10 ]

  set vin11 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 vin11 ]

  set vin20 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 vin20 ]

  set vin21 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 vin21 ]

  set vin30 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 vin30 ]

  set vin31 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 vin31 ]

  set led_r_8bits [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:gpio_rtl:1.0 led_r_8bits ]

  set led_g_8bits [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:gpio_rtl:1.0 led_g_8bits ]

  set led_b_8bits [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:gpio_rtl:1.0 led_b_8bits ]

  set adc2_clk [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 adc2_clk ]
  set_property -dict [ list \
   CONFIG.FREQ_HZ {307200000.0} \
   ] $adc2_clk


  # Create ports

  # Create instance: DSPmemory
  create_hier_cell_DSPmemory [current_bd_instance .] DSPmemory

  # Create instance: radio
  create_hier_cell_radio [current_bd_instance .] radio

  # Create instance: DSPinterconnect, and set properties
  set DSPinterconnect [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 DSPinterconnect ]
  set_property -dict [list \
    CONFIG.M00_HAS_DATA_FIFO {1} \
    CONFIG.M01_HAS_DATA_FIFO {1} \
    CONFIG.NUM_MI {2} \
    CONFIG.NUM_SI {2} \
    CONFIG.S00_HAS_DATA_FIFO {1} \
    CONFIG.S01_HAS_DATA_FIFO {1} \
  ] $DSPinterconnect


  # Create instance: axi_hpm0_lpd, and set properties
  set axi_hpm0_lpd [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_hpm0_lpd ]
  set_property -dict [list \
    CONFIG.NUM_MI {7} \
    CONFIG.STRATEGY {1} \
  ] $axi_hpm0_lpd


  # Create instance: axi_intc_0, and set properties
  set axi_intc_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_intc:4.1 axi_intc_0 ]
  set_property CONFIG.C_IRQ_CONNECTION {1} $axi_intc_0


  # Create instance: btns_gpio, and set properties
  set btns_gpio [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 btns_gpio ]
  set_property -dict [list \
    CONFIG.C_INTERRUPT_PRESENT {1} \
    CONFIG.GPIO_BOARD_INTERFACE {push_buttons_5bits} \
    CONFIG.USE_BOARD_FLOW {true} \
  ] $btns_gpio


  # Create instance: clk_wiz_310MHz, and set properties
  set clk_wiz_310MHz [ create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_wiz_310MHz ]
  set_property -dict [list \
    CONFIG.CLKIN1_JITTER_PS {33.330000000000005} \
    CONFIG.CLKOUT1_JITTER {177.750} \
    CONFIG.CLKOUT1_PHASE_ERROR {352.538} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {310} \
    CONFIG.MMCM_CLKFBOUT_MULT_F {120.125} \
    CONFIG.MMCM_CLKIN1_PERIOD {3.333} \
    CONFIG.MMCM_CLKIN2_PERIOD {10.0} \
    CONFIG.MMCM_CLKOUT0_DIVIDE_F {3.875} \
    CONFIG.MMCM_DIVCLK_DIVIDE {30} \
    CONFIG.RESET_PORT {resetn} \
    CONFIG.RESET_TYPE {ACTIVE_LOW} \
  ] $clk_wiz_310MHz


  # Create instance: leds_r, and set properties
  set leds_r [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 leds_r ]
  set_property -dict [list \
    CONFIG.GPIO_BOARD_INTERFACE {led_r_8bits} \
    CONFIG.USE_BOARD_FLOW {true} \
  ] $leds_r


  # Create instance: leds_g, and set properties
  set leds_g [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 leds_g ]
  set_property -dict [list \
    CONFIG.GPIO_BOARD_INTERFACE {led_g_8bits} \
    CONFIG.USE_BOARD_FLOW {true} \
  ] $leds_g


  # Create instance: leds_b, and set properties
  set leds_b [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 leds_b ]
  set_property -dict [list \
    CONFIG.GPIO_BOARD_INTERFACE {led_b_8bits} \
    CONFIG.USE_BOARD_FLOW {true} \
  ] $leds_b


  # Create instance: proc_sys_reset_0, and set properties
  set proc_sys_reset_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_0 ]

  # Create instance: proc_sys_reset_1, and set properties
  set proc_sys_reset_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_1 ]

  # Create instance: proc_sys_reset_2, and set properties
  set proc_sys_reset_2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_2 ]

  # Create instance: sws_gpio, and set properties
  set sws_gpio [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 sws_gpio ]
  set_property -dict [list \
    CONFIG.C_INTERRUPT_PRESENT {1} \
    CONFIG.GPIO_BOARD_INTERFACE {dip_switches_8bits} \
    CONFIG.USE_BOARD_FLOW {true} \
  ] $sws_gpio


  # Create instance: system_management_wiz_0, and set properties
  set system_management_wiz_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:system_management_wiz:1.3 system_management_wiz_0 ]
  set_property -dict [list \
    CONFIG.I2C_SCLK_LOC {AG12} \
    CONFIG.I2C_SDA_LOC {AH13} \
    CONFIG.INTERFACE_SELECTION {Enable_AXI} \
    CONFIG.VAUXN0_LOC {D30} \
    CONFIG.VAUXN10_LOC {AH15} \
    CONFIG.VAUXN11_LOC {AJ15} \
    CONFIG.VAUXN12_LOC {AR14} \
    CONFIG.VAUXN13_LOC {AR13} \
    CONFIG.VAUXN14_LOC {AT15} \
    CONFIG.VAUXN15_LOC {AV13} \
    CONFIG.VAUXN1_LOC {E31} \
    CONFIG.VAUXN2_LOC {AF16} \
    CONFIG.VAUXN3_LOC {AH17} \
    CONFIG.VAUXN4_LOC {AN16} \
    CONFIG.VAUXN5_LOC {AR16} \
    CONFIG.VAUXN6_LOC {AU14} \
    CONFIG.VAUXN7_LOC {AW16} \
    CONFIG.VAUXN8_LOC {C28} \
    CONFIG.VAUXN9_LOC {A30} \
    CONFIG.VAUXP0_LOC {D29} \
    CONFIG.VAUXP10_LOC {AH16} \
    CONFIG.VAUXP11_LOC {AJ16} \
    CONFIG.VAUXP12_LOC {AP14} \
    CONFIG.VAUXP13_LOC {AP13} \
    CONFIG.VAUXP14_LOC {AT16} \
    CONFIG.VAUXP15_LOC {AU13} \
    CONFIG.VAUXP1_LOC {E30} \
    CONFIG.VAUXP2_LOC {AF17} \
    CONFIG.VAUXP3_LOC {AG17} \
    CONFIG.VAUXP4_LOC {AN17} \
    CONFIG.VAUXP5_LOC {AP16} \
    CONFIG.VAUXP6_LOC {AU15} \
    CONFIG.VAUXP7_LOC {AV16} \
    CONFIG.VAUXP8_LOC {D28} \
    CONFIG.VAUXP9_LOC {B30} \
  ] $system_management_wiz_0


  # Create instance: xlconcat_0, and set properties
  set xlconcat_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 xlconcat_0 ]
  set_property CONFIG.NUM_PORTS {4} $xlconcat_0


  # Create instance: xpm_cdc_gen_0, and set properties
  set xpm_cdc_gen_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xpm_cdc_gen:1.0 xpm_cdc_gen_0 ]
  set_property CONFIG.CDC_TYPE {xpm_cdc_sync_rst} $xpm_cdc_gen_0


  # Create instance: zynq_ultra_ps_e_0, and set properties
  set zynq_ultra_ps_e_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e:3.5 zynq_ultra_ps_e_0 ]
  set_property -dict [list \
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
    CONFIG.PSU_MIO_0_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_0_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_0_SLEW {fast} \
    CONFIG.PSU_MIO_10_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_10_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_10_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_10_SLEW {fast} \
    CONFIG.PSU_MIO_11_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_11_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_11_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_11_SLEW {fast} \
    CONFIG.PSU_MIO_12_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_12_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_12_SLEW {fast} \
    CONFIG.PSU_MIO_13_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_13_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_13_POLARITY {Default} \
    CONFIG.PSU_MIO_13_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_13_SLEW {fast} \
    CONFIG.PSU_MIO_14_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_14_INPUT_TYPE {schmitt} \
    CONFIG.PSU_MIO_14_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_14_SLEW {slow} \
    CONFIG.PSU_MIO_15_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_15_INPUT_TYPE {schmitt} \
    CONFIG.PSU_MIO_15_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_15_SLEW {slow} \
    CONFIG.PSU_MIO_16_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_16_INPUT_TYPE {schmitt} \
    CONFIG.PSU_MIO_16_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_16_SLEW {slow} \
    CONFIG.PSU_MIO_17_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_17_INPUT_TYPE {schmitt} \
    CONFIG.PSU_MIO_17_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_17_SLEW {slow} \
    CONFIG.PSU_MIO_18_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_18_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_19_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_19_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_19_SLEW {fast} \
    CONFIG.PSU_MIO_1_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_1_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_1_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_1_SLEW {fast} \
    CONFIG.PSU_MIO_20_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_20_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_20_POLARITY {Default} \
    CONFIG.PSU_MIO_20_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_20_SLEW {fast} \
    CONFIG.PSU_MIO_21_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_21_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_21_POLARITY {Default} \
    CONFIG.PSU_MIO_21_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_21_SLEW {fast} \
    CONFIG.PSU_MIO_22_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_22_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_22_POLARITY {Default} \
    CONFIG.PSU_MIO_22_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_22_SLEW {fast} \
    CONFIG.PSU_MIO_23_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_23_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_23_POLARITY {Default} \
    CONFIG.PSU_MIO_23_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_23_SLEW {fast} \
    CONFIG.PSU_MIO_24_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_24_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_24_POLARITY {Default} \
    CONFIG.PSU_MIO_24_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_24_SLEW {fast} \
    CONFIG.PSU_MIO_25_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_25_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_25_POLARITY {Default} \
    CONFIG.PSU_MIO_25_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_25_SLEW {fast} \
    CONFIG.PSU_MIO_26_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_26_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_26_POLARITY {Default} \
    CONFIG.PSU_MIO_26_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_26_SLEW {fast} \
    CONFIG.PSU_MIO_27_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_27_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_27_POLARITY {Default} \
    CONFIG.PSU_MIO_27_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_27_SLEW {fast} \
    CONFIG.PSU_MIO_28_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_28_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_28_POLARITY {Default} \
    CONFIG.PSU_MIO_28_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_28_SLEW {fast} \
    CONFIG.PSU_MIO_29_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_29_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_29_POLARITY {Default} \
    CONFIG.PSU_MIO_29_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_29_SLEW {fast} \
    CONFIG.PSU_MIO_2_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_2_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_2_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_2_SLEW {fast} \
    CONFIG.PSU_MIO_30_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_30_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_30_POLARITY {Default} \
    CONFIG.PSU_MIO_30_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_30_SLEW {fast} \
    CONFIG.PSU_MIO_31_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_31_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_31_POLARITY {Default} \
    CONFIG.PSU_MIO_31_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_31_SLEW {fast} \
    CONFIG.PSU_MIO_32_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_32_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_32_SLEW {fast} \
    CONFIG.PSU_MIO_33_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_33_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_33_SLEW {fast} \
    CONFIG.PSU_MIO_34_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_34_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_34_SLEW {fast} \
    CONFIG.PSU_MIO_35_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_35_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_35_SLEW {fast} \
    CONFIG.PSU_MIO_36_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_36_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_36_SLEW {fast} \
    CONFIG.PSU_MIO_37_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_37_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_37_SLEW {fast} \
    CONFIG.PSU_MIO_38_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_38_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_38_POLARITY {Default} \
    CONFIG.PSU_MIO_38_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_38_SLEW {fast} \
    CONFIG.PSU_MIO_39_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_39_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_39_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_39_SLEW {fast} \
    CONFIG.PSU_MIO_3_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_3_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_3_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_3_SLEW {fast} \
    CONFIG.PSU_MIO_40_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_40_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_40_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_40_SLEW {fast} \
    CONFIG.PSU_MIO_41_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_41_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_41_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_41_SLEW {fast} \
    CONFIG.PSU_MIO_42_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_42_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_42_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_42_SLEW {fast} \
    CONFIG.PSU_MIO_43_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_43_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_43_POLARITY {Default} \
    CONFIG.PSU_MIO_43_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_43_SLEW {fast} \
    CONFIG.PSU_MIO_44_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_44_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_44_POLARITY {Default} \
    CONFIG.PSU_MIO_44_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_44_SLEW {fast} \
    CONFIG.PSU_MIO_45_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_45_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_46_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_46_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_46_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_46_SLEW {fast} \
    CONFIG.PSU_MIO_47_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_47_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_47_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_47_SLEW {fast} \
    CONFIG.PSU_MIO_48_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_48_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_48_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_48_SLEW {fast} \
    CONFIG.PSU_MIO_49_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_49_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_49_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_49_SLEW {fast} \
    CONFIG.PSU_MIO_4_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_4_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_4_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_4_SLEW {fast} \
    CONFIG.PSU_MIO_50_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_50_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_50_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_50_SLEW {fast} \
    CONFIG.PSU_MIO_51_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_51_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_51_SLEW {fast} \
    CONFIG.PSU_MIO_52_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_52_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_53_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_53_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_54_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_54_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_54_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_54_SLEW {fast} \
    CONFIG.PSU_MIO_55_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_55_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_56_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_56_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_56_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_56_SLEW {fast} \
    CONFIG.PSU_MIO_57_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_57_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_57_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_57_SLEW {fast} \
    CONFIG.PSU_MIO_58_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_58_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_58_SLEW {fast} \
    CONFIG.PSU_MIO_59_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_59_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_59_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_59_SLEW {fast} \
    CONFIG.PSU_MIO_5_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_5_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_5_SLEW {fast} \
    CONFIG.PSU_MIO_60_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_60_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_60_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_60_SLEW {fast} \
    CONFIG.PSU_MIO_61_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_61_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_61_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_61_SLEW {fast} \
    CONFIG.PSU_MIO_62_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_62_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_62_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_62_SLEW {fast} \
    CONFIG.PSU_MIO_63_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_63_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_63_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_63_SLEW {fast} \
    CONFIG.PSU_MIO_64_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_64_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_64_SLEW {fast} \
    CONFIG.PSU_MIO_65_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_65_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_65_SLEW {fast} \
    CONFIG.PSU_MIO_66_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_66_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_66_SLEW {fast} \
    CONFIG.PSU_MIO_67_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_67_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_67_SLEW {fast} \
    CONFIG.PSU_MIO_68_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_68_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_68_SLEW {fast} \
    CONFIG.PSU_MIO_69_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_69_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_69_SLEW {fast} \
    CONFIG.PSU_MIO_6_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_6_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_6_SLEW {fast} \
    CONFIG.PSU_MIO_70_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_70_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_71_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_71_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_72_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_72_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_73_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_73_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_74_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_74_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_75_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_75_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_76_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_76_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_76_SLEW {fast} \
    CONFIG.PSU_MIO_77_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_77_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_77_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_77_SLEW {fast} \
    CONFIG.PSU_MIO_7_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_7_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_7_SLEW {fast} \
    CONFIG.PSU_MIO_8_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_8_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_8_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_8_SLEW {fast} \
    CONFIG.PSU_MIO_9_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_9_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_9_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_9_SLEW {fast} \
    CONFIG.PSU_MIO_TREE_PERIPHERALS {Quad SPI Flash#Quad SPI Flash#Quad SPI Flash#Quad SPI Flash#Quad SPI Flash#Quad SPI Flash#Feedback Clk#Quad SPI Flash#Quad SPI Flash#Quad SPI Flash#Quad SPI Flash#Quad\
SPI Flash#Quad SPI Flash#GPIO0 MIO#I2C 0#I2C 0#I2C 1#I2C 1#UART 0#UART 0#GPIO0 MIO#GPIO0 MIO#GPIO0 MIO#GPIO0 MIO#GPIO0 MIO#GPIO0 MIO#GPIO1 MIO#GPIO1 MIO#GPIO1 MIO#GPIO1 MIO#GPIO1 MIO#GPIO1 MIO#PMU GPO\
0#PMU GPO 1#PMU GPO 2#PMU GPO 3#PMU GPO 4#PMU GPO 5#GPIO1 MIO#SD 1#SD 1#SD 1#SD 1#GPIO1 MIO#GPIO1 MIO#SD 1#SD 1#SD 1#SD 1#SD 1#SD 1#SD 1#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB\
0#USB 0#Gem 3#Gem 3#Gem 3#Gem 3#Gem 3#Gem 3#Gem 3#Gem 3#Gem 3#Gem 3#Gem 3#Gem 3#MDIO 3#MDIO 3} \
    CONFIG.PSU_MIO_TREE_SIGNALS {sclk_out#miso_mo1#mo2#mo3#mosi_mi0#n_ss_out#clk_for_lpbk#n_ss_out_upper#mo_upper[0]#mo_upper[1]#mo_upper[2]#mo_upper[3]#sclk_out_upper#gpio0[13]#scl_out#sda_out#scl_out#sda_out#rxd#txd#gpio0[20]#gpio0[21]#gpio0[22]#gpio0[23]#gpio0[24]#gpio0[25]#gpio1[26]#gpio1[27]#gpio1[28]#gpio1[29]#gpio1[30]#gpio1[31]#gpo[0]#gpo[1]#gpo[2]#gpo[3]#gpo[4]#gpo[5]#gpio1[38]#sdio1_data_out[4]#sdio1_data_out[5]#sdio1_data_out[6]#sdio1_data_out[7]#gpio1[43]#gpio1[44]#sdio1_cd_n#sdio1_data_out[0]#sdio1_data_out[1]#sdio1_data_out[2]#sdio1_data_out[3]#sdio1_cmd_out#sdio1_clk_out#ulpi_clk_in#ulpi_dir#ulpi_tx_data[2]#ulpi_nxt#ulpi_tx_data[0]#ulpi_tx_data[1]#ulpi_stp#ulpi_tx_data[3]#ulpi_tx_data[4]#ulpi_tx_data[5]#ulpi_tx_data[6]#ulpi_tx_data[7]#rgmii_tx_clk#rgmii_txd[0]#rgmii_txd[1]#rgmii_txd[2]#rgmii_txd[3]#rgmii_tx_ctl#rgmii_rx_clk#rgmii_rxd[0]#rgmii_rxd[1]#rgmii_rxd[2]#rgmii_rxd[3]#rgmii_rx_ctl#gem3_mdc#gem3_mdio_out}\
\
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
    CONFIG.PSU__ACT_DDR_FREQ_MHZ {1050.000000} \
    CONFIG.PSU__AUX_REF_CLK__FREQMHZ {33.333} \
    CONFIG.PSU__CAN0_LOOP_CAN1__ENABLE {0} \
    CONFIG.PSU__CAN0__PERIPHERAL__ENABLE {0} \
    CONFIG.PSU__CAN1__PERIPHERAL__ENABLE {0} \
    CONFIG.PSU__CRF_APB__ACPU_CTRL__ACT_FREQMHZ {1200.000000} \
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
    CONFIG.PSU__CRF_APB__APLL_CTRL__FRACFREQ {27.138} \
    CONFIG.PSU__CRF_APB__APLL_CTRL__SRCSEL {PSS_REF_CLK} \
    CONFIG.PSU__CRF_APB__APM_CTRL__ACT_FREQMHZ {1} \
    CONFIG.PSU__CRF_APB__APM_CTRL__DIVISOR0 {1} \
    CONFIG.PSU__CRF_APB__APM_CTRL__FREQMHZ {1} \
    CONFIG.PSU__CRF_APB__DBG_FPD_CTRL__ACT_FREQMHZ {250.000000} \
    CONFIG.PSU__CRF_APB__DBG_FPD_CTRL__FREQMHZ {250} \
    CONFIG.PSU__CRF_APB__DBG_FPD_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRF_APB__DBG_TRACE_CTRL__ACT_FREQMHZ {250} \
    CONFIG.PSU__CRF_APB__DBG_TRACE_CTRL__FREQMHZ {250} \
    CONFIG.PSU__CRF_APB__DBG_TRACE_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRF_APB__DBG_TSTMP_CTRL__ACT_FREQMHZ {250.000000} \
    CONFIG.PSU__CRF_APB__DBG_TSTMP_CTRL__FREQMHZ {250} \
    CONFIG.PSU__CRF_APB__DBG_TSTMP_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRF_APB__DDR_CTRL__ACT_FREQMHZ {525.000000} \
    CONFIG.PSU__CRF_APB__DDR_CTRL__FREQMHZ {1066} \
    CONFIG.PSU__CRF_APB__DDR_CTRL__SRCSEL {DPLL} \
    CONFIG.PSU__CRF_APB__DPDMA_REF_CTRL__ACT_FREQMHZ {525.000000} \
    CONFIG.PSU__CRF_APB__DPDMA_REF_CTRL__FREQMHZ {600} \
    CONFIG.PSU__CRF_APB__DPDMA_REF_CTRL__SRCSEL {DPLL} \
    CONFIG.PSU__CRF_APB__DPLL_CTRL__FRACFREQ {27.138} \
    CONFIG.PSU__CRF_APB__DPLL_CTRL__SRCSEL {PSS_REF_CLK} \
    CONFIG.PSU__CRF_APB__DP_AUDIO_REF_CTRL__ACT_FREQMHZ {25} \
    CONFIG.PSU__CRF_APB__DP_AUDIO_REF_CTRL__FREQMHZ {25} \
    CONFIG.PSU__CRF_APB__DP_AUDIO_REF_CTRL__SRCSEL {RPLL} \
    CONFIG.PSU__CRF_APB__DP_STC_REF_CTRL__ACT_FREQMHZ {27} \
    CONFIG.PSU__CRF_APB__DP_STC_REF_CTRL__FREQMHZ {27} \
    CONFIG.PSU__CRF_APB__DP_STC_REF_CTRL__SRCSEL {RPLL} \
    CONFIG.PSU__CRF_APB__DP_VIDEO_REF_CTRL__ACT_FREQMHZ {320} \
    CONFIG.PSU__CRF_APB__DP_VIDEO_REF_CTRL__FREQMHZ {300} \
    CONFIG.PSU__CRF_APB__DP_VIDEO_REF_CTRL__SRCSEL {VPLL} \
    CONFIG.PSU__CRF_APB__GDMA_REF_CTRL__ACT_FREQMHZ {525.000000} \
    CONFIG.PSU__CRF_APB__GDMA_REF_CTRL__FREQMHZ {600} \
    CONFIG.PSU__CRF_APB__GDMA_REF_CTRL__SRCSEL {DPLL} \
    CONFIG.PSU__CRF_APB__GPU_REF_CTRL__ACT_FREQMHZ {0} \
    CONFIG.PSU__CRF_APB__GPU_REF_CTRL__FREQMHZ {500} \
    CONFIG.PSU__CRF_APB__GPU_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRF_APB__GTGREF0_REF_CTRL__ACT_FREQMHZ {-1} \
    CONFIG.PSU__CRF_APB__GTGREF0_REF_CTRL__DIVISOR0 {-1} \
    CONFIG.PSU__CRF_APB__GTGREF0_REF_CTRL__FREQMHZ {-1} \
    CONFIG.PSU__CRF_APB__GTGREF0_REF_CTRL__SRCSEL {NA} \
    CONFIG.PSU__CRF_APB__GTGREF0__ENABLE {NA} \
    CONFIG.PSU__CRF_APB__PCIE_REF_CTRL__ACT_FREQMHZ {250} \
    CONFIG.PSU__CRF_APB__SATA_REF_CTRL__ACT_FREQMHZ {250.000000} \
    CONFIG.PSU__CRF_APB__SATA_REF_CTRL__FREQMHZ {250} \
    CONFIG.PSU__CRF_APB__SATA_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRF_APB__TOPSW_LSBUS_CTRL__ACT_FREQMHZ {100.000000} \
    CONFIG.PSU__CRF_APB__TOPSW_LSBUS_CTRL__FREQMHZ {100} \
    CONFIG.PSU__CRF_APB__TOPSW_LSBUS_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRF_APB__TOPSW_MAIN_CTRL__ACT_FREQMHZ {525.000000} \
    CONFIG.PSU__CRF_APB__TOPSW_MAIN_CTRL__FREQMHZ {533.33} \
    CONFIG.PSU__CRF_APB__TOPSW_MAIN_CTRL__SRCSEL {DPLL} \
    CONFIG.PSU__CRF_APB__VPLL_CTRL__FRACFREQ {27.138} \
    CONFIG.PSU__CRF_APB__VPLL_CTRL__SRCSEL {PSS_REF_CLK} \
    CONFIG.PSU__CRL_APB__ADMA_REF_CTRL__ACT_FREQMHZ {499.999969} \
    CONFIG.PSU__CRL_APB__ADMA_REF_CTRL__FREQMHZ {533.33} \
    CONFIG.PSU__CRL_APB__ADMA_REF_CTRL__SRCSEL {RPLL} \
    CONFIG.PSU__CRL_APB__AFI6_REF_CTRL__ACT_FREQMHZ {500} \
    CONFIG.PSU__CRL_APB__AFI6_REF_CTRL__FREQMHZ {500} \
    CONFIG.PSU__CRL_APB__AFI6_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__AFI6__ENABLE {0} \
    CONFIG.PSU__CRL_APB__AMS_REF_CTRL__ACT_FREQMHZ {50.000000} \
    CONFIG.PSU__CRL_APB__AMS_REF_CTRL__FREQMHZ {50} \
    CONFIG.PSU__CRL_APB__AMS_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__CAN0_REF_CTRL__ACT_FREQMHZ {100} \
    CONFIG.PSU__CRL_APB__CAN0_REF_CTRL__FREQMHZ {100} \
    CONFIG.PSU__CRL_APB__CAN0_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__CAN1_REF_CTRL__ACT_FREQMHZ {100} \
    CONFIG.PSU__CRL_APB__CAN1_REF_CTRL__FREQMHZ {100} \
    CONFIG.PSU__CRL_APB__CAN1_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__CPU_R5_CTRL__ACT_FREQMHZ {500.000000} \
    CONFIG.PSU__CRL_APB__CPU_R5_CTRL__FREQMHZ {500} \
    CONFIG.PSU__CRL_APB__CPU_R5_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__CSU_PLL_CTRL__ACT_FREQMHZ {180} \
    CONFIG.PSU__CRL_APB__CSU_PLL_CTRL__DIVISOR0 {3} \
    CONFIG.PSU__CRL_APB__CSU_PLL_CTRL__SRCSEL {SysOsc} \
    CONFIG.PSU__CRL_APB__DBG_LPD_CTRL__ACT_FREQMHZ {250.000000} \
    CONFIG.PSU__CRL_APB__DBG_LPD_CTRL__FREQMHZ {250} \
    CONFIG.PSU__CRL_APB__DBG_LPD_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__DEBUG_R5_ATCLK_CTRL__ACT_FREQMHZ {1000} \
    CONFIG.PSU__CRL_APB__DEBUG_R5_ATCLK_CTRL__DIVISOR0 {6} \
    CONFIG.PSU__CRL_APB__DEBUG_R5_ATCLK_CTRL__FREQMHZ {1000} \
    CONFIG.PSU__CRL_APB__DEBUG_R5_ATCLK_CTRL__SRCSEL {RPLL} \
    CONFIG.PSU__CRL_APB__DLL_REF_CTRL__ACT_FREQMHZ {1500.000000} \
    CONFIG.PSU__CRL_APB__DLL_REF_CTRL__FREQMHZ {1500} \
    CONFIG.PSU__CRL_APB__DLL_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__GEM0_REF_CTRL__ACT_FREQMHZ {125} \
    CONFIG.PSU__CRL_APB__GEM0_REF_CTRL__FREQMHZ {125} \
    CONFIG.PSU__CRL_APB__GEM0_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__GEM1_REF_CTRL__ACT_FREQMHZ {125} \
    CONFIG.PSU__CRL_APB__GEM1_REF_CTRL__FREQMHZ {125} \
    CONFIG.PSU__CRL_APB__GEM1_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__GEM2_REF_CTRL__ACT_FREQMHZ {125} \
    CONFIG.PSU__CRL_APB__GEM2_REF_CTRL__FREQMHZ {125} \
    CONFIG.PSU__CRL_APB__GEM2_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__GEM3_REF_CTRL__ACT_FREQMHZ {125.000000} \
    CONFIG.PSU__CRL_APB__GEM3_REF_CTRL__FREQMHZ {125} \
    CONFIG.PSU__CRL_APB__GEM3_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__GEM_TSU_REF_CTRL__ACT_FREQMHZ {250.000000} \
    CONFIG.PSU__CRL_APB__GEM_TSU_REF_CTRL__FREQMHZ {250} \
    CONFIG.PSU__CRL_APB__GEM_TSU_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__I2C0_REF_CTRL__ACT_FREQMHZ {100.000000} \
    CONFIG.PSU__CRL_APB__I2C0_REF_CTRL__FREQMHZ {100} \
    CONFIG.PSU__CRL_APB__I2C0_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__I2C1_REF_CTRL__ACT_FREQMHZ {100.000000} \
    CONFIG.PSU__CRL_APB__I2C1_REF_CTRL__FREQMHZ {100} \
    CONFIG.PSU__CRL_APB__I2C1_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__IOPLL_CTRL__FRACFREQ {27.138} \
    CONFIG.PSU__CRL_APB__IOPLL_CTRL__SRCSEL {PSS_REF_CLK} \
    CONFIG.PSU__CRL_APB__IOU_SWITCH_CTRL__ACT_FREQMHZ {249.999985} \
    CONFIG.PSU__CRL_APB__IOU_SWITCH_CTRL__FREQMHZ {267} \
    CONFIG.PSU__CRL_APB__IOU_SWITCH_CTRL__SRCSEL {RPLL} \
    CONFIG.PSU__CRL_APB__LPD_LSBUS_CTRL__ACT_FREQMHZ {100.000000} \
    CONFIG.PSU__CRL_APB__LPD_LSBUS_CTRL__FREQMHZ {100} \
    CONFIG.PSU__CRL_APB__LPD_LSBUS_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__LPD_SWITCH_CTRL__ACT_FREQMHZ {499.999969} \
    CONFIG.PSU__CRL_APB__LPD_SWITCH_CTRL__FREQMHZ {533.333} \
    CONFIG.PSU__CRL_APB__LPD_SWITCH_CTRL__SRCSEL {RPLL} \
    CONFIG.PSU__CRL_APB__NAND_REF_CTRL__ACT_FREQMHZ {100} \
    CONFIG.PSU__CRL_APB__NAND_REF_CTRL__FREQMHZ {100} \
    CONFIG.PSU__CRL_APB__NAND_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__OCM_MAIN_CTRL__ACT_FREQMHZ {500} \
    CONFIG.PSU__CRL_APB__OCM_MAIN_CTRL__DIVISOR0 {3} \
    CONFIG.PSU__CRL_APB__OCM_MAIN_CTRL__FREQMHZ {500} \
    CONFIG.PSU__CRL_APB__OCM_MAIN_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__PCAP_CTRL__ACT_FREQMHZ {187.500000} \
    CONFIG.PSU__CRL_APB__PCAP_CTRL__FREQMHZ {200} \
    CONFIG.PSU__CRL_APB__PCAP_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__PL0_REF_CTRL__ACT_FREQMHZ {100.000000} \
    CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ {100} \
    CONFIG.PSU__CRL_APB__PL0_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__PL1_REF_CTRL__ACT_FREQMHZ {300.000000} \
    CONFIG.PSU__CRL_APB__PL1_REF_CTRL__FREQMHZ {300} \
    CONFIG.PSU__CRL_APB__PL1_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__PL2_REF_CTRL__ACT_FREQMHZ {333.333313} \
    CONFIG.PSU__CRL_APB__PL2_REF_CTRL__FREQMHZ {333.333333333333333333333} \
    CONFIG.PSU__CRL_APB__PL2_REF_CTRL__SRCSEL {RPLL} \
    CONFIG.PSU__CRL_APB__PL3_REF_CTRL__ACT_FREQMHZ {100} \
    CONFIG.PSU__CRL_APB__QSPI_REF_CTRL__ACT_FREQMHZ {125.000000} \
    CONFIG.PSU__CRL_APB__QSPI_REF_CTRL__FREQMHZ {125} \
    CONFIG.PSU__CRL_APB__QSPI_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__RPLL_CTRL__FRACFREQ {27.138} \
    CONFIG.PSU__CRL_APB__RPLL_CTRL__SRCSEL {PSS_REF_CLK} \
    CONFIG.PSU__CRL_APB__SDIO0_REF_CTRL__ACT_FREQMHZ {200} \
    CONFIG.PSU__CRL_APB__SDIO0_REF_CTRL__FREQMHZ {200} \
    CONFIG.PSU__CRL_APB__SDIO0_REF_CTRL__SRCSEL {RPLL} \
    CONFIG.PSU__CRL_APB__SDIO1_REF_CTRL__ACT_FREQMHZ {187.500000} \
    CONFIG.PSU__CRL_APB__SDIO1_REF_CTRL__FREQMHZ {200} \
    CONFIG.PSU__CRL_APB__SDIO1_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__SPI0_REF_CTRL__ACT_FREQMHZ {214} \
    CONFIG.PSU__CRL_APB__SPI0_REF_CTRL__FREQMHZ {200} \
    CONFIG.PSU__CRL_APB__SPI0_REF_CTRL__SRCSEL {RPLL} \
    CONFIG.PSU__CRL_APB__SPI1_REF_CTRL__ACT_FREQMHZ {214} \
    CONFIG.PSU__CRL_APB__SPI1_REF_CTRL__FREQMHZ {200} \
    CONFIG.PSU__CRL_APB__SPI1_REF_CTRL__SRCSEL {RPLL} \
    CONFIG.PSU__CRL_APB__TIMESTAMP_REF_CTRL__ACT_FREQMHZ {33.333332} \
    CONFIG.PSU__CRL_APB__TIMESTAMP_REF_CTRL__FREQMHZ {100} \
    CONFIG.PSU__CRL_APB__TIMESTAMP_REF_CTRL__SRCSEL {PSS_REF_CLK} \
    CONFIG.PSU__CRL_APB__UART0_REF_CTRL__ACT_FREQMHZ {100.000000} \
    CONFIG.PSU__CRL_APB__UART0_REF_CTRL__FREQMHZ {100} \
    CONFIG.PSU__CRL_APB__UART0_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__UART1_REF_CTRL__ACT_FREQMHZ {100} \
    CONFIG.PSU__CRL_APB__UART1_REF_CTRL__FREQMHZ {100} \
    CONFIG.PSU__CRL_APB__UART1_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__USB0_BUS_REF_CTRL__ACT_FREQMHZ {250.000000} \
    CONFIG.PSU__CRL_APB__USB0_BUS_REF_CTRL__FREQMHZ {250} \
    CONFIG.PSU__CRL_APB__USB0_BUS_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__USB1_BUS_REF_CTRL__ACT_FREQMHZ {250} \
    CONFIG.PSU__CRL_APB__USB1_BUS_REF_CTRL__FREQMHZ {250} \
    CONFIG.PSU__CRL_APB__USB1_BUS_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__USB3_DUAL_REF_CTRL__ACT_FREQMHZ {20.000000} \
    CONFIG.PSU__CRL_APB__USB3_DUAL_REF_CTRL__FREQMHZ {20} \
    CONFIG.PSU__CRL_APB__USB3_DUAL_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__USB3__ENABLE {1} \
    CONFIG.PSU__CSUPMU__PERIPHERAL__VALID {1} \
    CONFIG.PSU__CSU__CSU_TAMPER_0__ENABLE {0} \
    CONFIG.PSU__CSU__CSU_TAMPER_10__ENABLE {0} \
    CONFIG.PSU__CSU__CSU_TAMPER_11__ENABLE {0} \
    CONFIG.PSU__CSU__CSU_TAMPER_12__ENABLE {0} \
    CONFIG.PSU__CSU__CSU_TAMPER_1__ENABLE {0} \
    CONFIG.PSU__CSU__CSU_TAMPER_2__ENABLE {0} \
    CONFIG.PSU__CSU__CSU_TAMPER_3__ENABLE {0} \
    CONFIG.PSU__CSU__CSU_TAMPER_4__ENABLE {0} \
    CONFIG.PSU__CSU__CSU_TAMPER_5__ENABLE {0} \
    CONFIG.PSU__CSU__CSU_TAMPER_6__ENABLE {0} \
    CONFIG.PSU__CSU__CSU_TAMPER_7__ENABLE {0} \
    CONFIG.PSU__CSU__CSU_TAMPER_8__ENABLE {0} \
    CONFIG.PSU__CSU__CSU_TAMPER_9__ENABLE {0} \
    CONFIG.PSU__CSU__PERIPHERAL__ENABLE {0} \
    CONFIG.PSU__DDRC__AL {0} \
    CONFIG.PSU__DDRC__BG_ADDR_COUNT {1} \
    CONFIG.PSU__DDRC__BRC_MAPPING {ROW_BANK_COL} \
    CONFIG.PSU__DDRC__BUS_WIDTH {64 Bit} \
    CONFIG.PSU__DDRC__CL {15} \
    CONFIG.PSU__DDRC__CLOCK_STOP_EN {0} \
    CONFIG.PSU__DDRC__COMPONENTS {UDIMM} \
    CONFIG.PSU__DDRC__CWL {11} \
    CONFIG.PSU__DDRC__DDR4_ADDR_MAPPING {0} \
    CONFIG.PSU__DDRC__DDR4_CAL_MODE_ENABLE {0} \
    CONFIG.PSU__DDRC__DDR4_CRC_CONTROL {0} \
    CONFIG.PSU__DDRC__DDR4_MAXPWR_SAVING_EN {0} \
    CONFIG.PSU__DDRC__DDR4_T_REF_MODE {0} \
    CONFIG.PSU__DDRC__DDR4_T_REF_RANGE {Normal (0-85)} \
    CONFIG.PSU__DDRC__DEVICE_CAPACITY {8192 MBits} \
    CONFIG.PSU__DDRC__DM_DBI {DM_NO_DBI} \
    CONFIG.PSU__DDRC__DRAM_WIDTH {16 Bits} \
    CONFIG.PSU__DDRC__ECC {Disabled} \
    CONFIG.PSU__DDRC__ECC_SCRUB {0} \
    CONFIG.PSU__DDRC__ENABLE {1} \
    CONFIG.PSU__DDRC__ENABLE_2T_TIMING {0} \
    CONFIG.PSU__DDRC__ENABLE_DP_SWITCH {0} \
    CONFIG.PSU__DDRC__EN_2ND_CLK {0} \
    CONFIG.PSU__DDRC__FGRM {1X} \
    CONFIG.PSU__DDRC__FREQ_MHZ {1} \
    CONFIG.PSU__DDRC__LPDDR3_DUALRANK_SDP {0} \
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
    CONFIG.PSU__DDRC__SELF_REF_ABORT {0} \
    CONFIG.PSU__DDRC__SPEED_BIN {DDR4_2133P} \
    CONFIG.PSU__DDRC__STATIC_RD_MODE {0} \
    CONFIG.PSU__DDRC__TRAIN_DATA_EYE {1} \
    CONFIG.PSU__DDRC__TRAIN_READ_GATE {1} \
    CONFIG.PSU__DDRC__TRAIN_WRITE_LEVEL {1} \
    CONFIG.PSU__DDRC__T_FAW {30.0} \
    CONFIG.PSU__DDRC__T_RAS_MIN {33} \
    CONFIG.PSU__DDRC__T_RC {46.5} \
    CONFIG.PSU__DDRC__T_RCD {15} \
    CONFIG.PSU__DDRC__T_RP {15} \
    CONFIG.PSU__DDRC__VIDEO_BUFFER_SIZE {0} \
    CONFIG.PSU__DDRC__VREF {1} \
    CONFIG.PSU__DDR_HIGH_ADDRESS_GUI_ENABLE {1} \
    CONFIG.PSU__DDR_QOS_ENABLE {0} \
    CONFIG.PSU__DDR_QOS_HP0_RDQOS {} \
    CONFIG.PSU__DDR_QOS_HP0_WRQOS {} \
    CONFIG.PSU__DDR_QOS_HP1_RDQOS {} \
    CONFIG.PSU__DDR_QOS_HP1_WRQOS {} \
    CONFIG.PSU__DDR_QOS_HP2_RDQOS {} \
    CONFIG.PSU__DDR_QOS_HP2_WRQOS {} \
    CONFIG.PSU__DDR_QOS_HP3_RDQOS {} \
    CONFIG.PSU__DDR_QOS_HP3_WRQOS {} \
    CONFIG.PSU__DDR_SW_REFRESH_ENABLED {1} \
    CONFIG.PSU__DDR__INTERFACE__FREQMHZ {533.000} \
    CONFIG.PSU__DEVICE_TYPE {RFSOC} \
    CONFIG.PSU__DISPLAYPORT__PERIPHERAL__ENABLE {0} \
    CONFIG.PSU__DLL__ISUSED {1} \
    CONFIG.PSU__ENABLE__DDR__REFRESH__SIGNALS {0} \
    CONFIG.PSU__ENET0__PERIPHERAL__ENABLE {0} \
    CONFIG.PSU__ENET1__PERIPHERAL__ENABLE {0} \
    CONFIG.PSU__ENET2__PERIPHERAL__ENABLE {0} \
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
    CONFIG.PSU__FPD_SLCR__WDT1__ACT_FREQMHZ {100.000000} \
    CONFIG.PSU__FPGA_PL0_ENABLE {1} \
    CONFIG.PSU__FPGA_PL1_ENABLE {1} \
    CONFIG.PSU__FPGA_PL2_ENABLE {1} \
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
    CONFIG.PSU__IOU_SLCR__TTC1__ACT_FREQMHZ {100.000000} \
    CONFIG.PSU__IOU_SLCR__TTC2__ACT_FREQMHZ {100.000000} \
    CONFIG.PSU__IOU_SLCR__TTC3__ACT_FREQMHZ {100.000000} \
    CONFIG.PSU__IOU_SLCR__WDT0__ACT_FREQMHZ {100.000000} \
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
    CONFIG.PSU__IRQ_P2F_CLKMON__INT {0} \
    CONFIG.PSU__IRQ_P2F_CSUPMU_WDT__INT {0} \
    CONFIG.PSU__IRQ_P2F_DDR_SS__INT {0} \
    CONFIG.PSU__IRQ_P2F_DPDMA__INT {0} \
    CONFIG.PSU__IRQ_P2F_EFUSE__INT {0} \
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
    CONFIG.PSU__IRQ_P2F_LP_WDT__INT {1} \
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
    CONFIG.PSU__IRQ_P2F_SDIO1_WAKE__INT {0} \
    CONFIG.PSU__IRQ_P2F_SDIO1__INT {0} \
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
    CONFIG.PSU__MAXIGP0__DATA_WIDTH {128} \
    CONFIG.PSU__MAXIGP2__DATA_WIDTH {32} \
    CONFIG.PSU__M_AXI_GP0_SUPPORTS_NARROW_BURST {1} \
    CONFIG.PSU__M_AXI_GP1_SUPPORTS_NARROW_BURST {1} \
    CONFIG.PSU__M_AXI_GP2_SUPPORTS_NARROW_BURST {1} \
    CONFIG.PSU__NAND__PERIPHERAL__ENABLE {0} \
    CONFIG.PSU__NAND__READY_BUSY__ENABLE {0} \
    CONFIG.PSU__NUM_FABRIC_RESETS {1} \
    CONFIG.PSU__OCM_BANK0__POWER__ON {1} \
    CONFIG.PSU__OCM_BANK1__POWER__ON {1} \
    CONFIG.PSU__OCM_BANK2__POWER__ON {1} \
    CONFIG.PSU__OCM_BANK3__POWER__ON {1} \
    CONFIG.PSU__OVERRIDE_HPX_QOS {0} \
    CONFIG.PSU__OVERRIDE__BASIC_CLOCK {0} \
    CONFIG.PSU__PCIE__ACS_VIOLAION {0} \
    CONFIG.PSU__PCIE__AER_CAPABILITY {0} \
    CONFIG.PSU__PCIE__CLASS_CODE_BASE {} \
    CONFIG.PSU__PCIE__CLASS_CODE_INTERFACE {} \
    CONFIG.PSU__PCIE__CLASS_CODE_SUB {} \
    CONFIG.PSU__PCIE__DEVICE_ID {} \
    CONFIG.PSU__PCIE__INTX_GENERATION {0} \
    CONFIG.PSU__PCIE__MSIX_CAPABILITY {0} \
    CONFIG.PSU__PCIE__MSI_CAPABILITY {0} \
    CONFIG.PSU__PCIE__PERIPHERAL__ENABLE {0} \
    CONFIG.PSU__PCIE__PERIPHERAL__ENDPOINT_ENABLE {1} \
    CONFIG.PSU__PCIE__PERIPHERAL__ROOTPORT_ENABLE {0} \
    CONFIG.PSU__PCIE__RESET__POLARITY {Active Low} \
    CONFIG.PSU__PCIE__REVISION_ID {} \
    CONFIG.PSU__PCIE__SUBSYSTEM_ID {} \
    CONFIG.PSU__PCIE__SUBSYSTEM_VENDOR_ID {} \
    CONFIG.PSU__PCIE__VENDOR_ID {} \
    CONFIG.PSU__PJTAG__PERIPHERAL__ENABLE {0} \
    CONFIG.PSU__PL_CLK0_BUF {TRUE} \
    CONFIG.PSU__PL_CLK1_BUF {TRUE} \
    CONFIG.PSU__PL_CLK2_BUF {TRUE} \
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
    CONFIG.PSU__PROTECTION__ENABLE {0} \
    CONFIG.PSU__PROTECTION__FPD_SEGMENTS {SA:0xFD1A0000; SIZE:1280; UNIT:KB; RegionTZ:Secure; WrAllowed:Read/Write; subsystemId:PMU Firmware   |    SA:0xFD000000; SIZE:64; UNIT:KB; RegionTZ:Secure; WrAllowed:Read/Write;\
subsystemId:PMU Firmware   |    SA:0xFD010000; SIZE:64; UNIT:KB; RegionTZ:Secure; WrAllowed:Read/Write; subsystemId:PMU Firmware   |    SA:0xFD020000; SIZE:64; UNIT:KB; RegionTZ:Secure; WrAllowed:Read/Write;\
subsystemId:PMU Firmware   |    SA:0xFD030000; SIZE:64; UNIT:KB; RegionTZ:Secure; WrAllowed:Read/Write; subsystemId:PMU Firmware   |    SA:0xFD040000; SIZE:64; UNIT:KB; RegionTZ:Secure; WrAllowed:Read/Write;\
subsystemId:PMU Firmware   |    SA:0xFD050000; SIZE:64; UNIT:KB; RegionTZ:Secure; WrAllowed:Read/Write; subsystemId:PMU Firmware   |    SA:0xFD610000; SIZE:512; UNIT:KB; RegionTZ:Secure; WrAllowed:Read/Write;\
subsystemId:PMU Firmware   |    SA:0xFD5D0000; SIZE:64; UNIT:KB; RegionTZ:Secure; WrAllowed:Read/Write; subsystemId:PMU Firmware   |   SA:0xFD1A0000 ; SIZE:1280; UNIT:KB; RegionTZ:Secure ; WrAllowed:Read/Write;\
subsystemId:Secure Subsystem} \
    CONFIG.PSU__PROTECTION__LPD_SEGMENTS {SA:0xFF980000; SIZE:64; UNIT:KB; RegionTZ:Secure; WrAllowed:Read/Write; subsystemId:PMU Firmware| SA:0xFF5E0000; SIZE:2560; UNIT:KB; RegionTZ:Secure; WrAllowed:Read/Write;\
subsystemId:PMU Firmware| SA:0xFFCC0000; SIZE:64; UNIT:KB; RegionTZ:Secure; WrAllowed:Read/Write; subsystemId:PMU Firmware| SA:0xFF180000; SIZE:768; UNIT:KB; RegionTZ:Secure; WrAllowed:Read/Write; subsystemId:PMU\
Firmware| SA:0xFF410000; SIZE:640; UNIT:KB; RegionTZ:Secure; WrAllowed:Read/Write; subsystemId:PMU Firmware| SA:0xFFA70000; SIZE:64; UNIT:KB; RegionTZ:Secure; WrAllowed:Read/Write; subsystemId:PMU Firmware|\
SA:0xFF9A0000; SIZE:64; UNIT:KB; RegionTZ:Secure; WrAllowed:Read/Write; subsystemId:PMU Firmware|SA:0xFF5E0000 ; SIZE:2560; UNIT:KB; RegionTZ:Secure ; WrAllowed:Read/Write; subsystemId:Secure Subsystem|SA:0xFFCC0000\
; SIZE:64; UNIT:KB; RegionTZ:Secure ; WrAllowed:Read/Write; subsystemId:Secure Subsystem|SA:0xFF180000 ; SIZE:768; UNIT:KB; RegionTZ:Secure ; WrAllowed:Read/Write; subsystemId:Secure Subsystem|SA:0xFF9A0000\
; SIZE:64; UNIT:KB; RegionTZ:Secure ; WrAllowed:Read/Write; subsystemId:Secure Subsystem} \
    CONFIG.PSU__PROTECTION__MASTERS {USB1:NonSecure;0|USB0:NonSecure;1|S_AXI_LPD:NA;0|S_AXI_HPC1_FPD:NA;0|S_AXI_HPC0_FPD:NA;0|S_AXI_HP3_FPD:NA;0|S_AXI_HP2_FPD:NA;0|S_AXI_HP1_FPD:NA;0|S_AXI_HP0_FPD:NA;1|S_AXI_ACP:NA;0|S_AXI_ACE:NA;0|SD1:NonSecure;1|SD0:NonSecure;0|SATA1:NonSecure;1|SATA0:NonSecure;1|RPU1:Secure;1|RPU0:Secure;1|QSPI:NonSecure;1|PMU:NA;1|PCIe:NonSecure;0|NAND:NonSecure;0|LDMA:NonSecure;1|GPU:NonSecure;1|GEM3:NonSecure;1|GEM2:NonSecure;0|GEM1:NonSecure;0|GEM0:NonSecure;0|FDMA:NonSecure;1|DP:NonSecure;0|DAP:NA;1|Coresight:NA;1|CSU:NA;1|APU:NA;1}\
\
    CONFIG.PSU__PROTECTION__MASTERS_TZ {GEM0:NonSecure|SD1:NonSecure|GEM2:NonSecure|GEM1:NonSecure|GEM3:NonSecure|PCIe:NonSecure|DP:NonSecure|NAND:NonSecure|GPU:NonSecure|USB1:NonSecure|USB0:NonSecure|LDMA:NonSecure|FDMA:NonSecure|QSPI:NonSecure|SD0:NonSecure}\
\
    CONFIG.PSU__PROTECTION__OCM_SEGMENTS {NONE} \
    CONFIG.PSU__PROTECTION__PRESUBSYSTEMS {NONE} \
    CONFIG.PSU__PROTECTION__SLAVES {LPD;USB3_1_XHCI;FE300000;FE3FFFFF;0|LPD;USB3_1;FF9E0000;FF9EFFFF;0|LPD;USB3_0_XHCI;FE200000;FE2FFFFF;1|LPD;USB3_0;FF9D0000;FF9DFFFF;1|LPD;UART1;FF010000;FF01FFFF;0|LPD;UART0;FF000000;FF00FFFF;1|LPD;TTC3;FF140000;FF14FFFF;1|LPD;TTC2;FF130000;FF13FFFF;1|LPD;TTC1;FF120000;FF12FFFF;1|LPD;TTC0;FF110000;FF11FFFF;1|FPD;SWDT1;FD4D0000;FD4DFFFF;1|LPD;SWDT0;FF150000;FF15FFFF;1|LPD;SPI1;FF050000;FF05FFFF;0|LPD;SPI0;FF040000;FF04FFFF;0|FPD;SMMU_REG;FD5F0000;FD5FFFFF;1|FPD;SMMU;FD800000;FDFFFFFF;1|FPD;SIOU;FD3D0000;FD3DFFFF;1|FPD;SERDES;FD400000;FD47FFFF;1|LPD;SD1;FF170000;FF17FFFF;1|LPD;SD0;FF160000;FF16FFFF;0|FPD;SATA;FD0C0000;FD0CFFFF;1|LPD;RTC;FFA60000;FFA6FFFF;1|LPD;RSA_CORE;FFCE0000;FFCEFFFF;1|LPD;RPU;FF9A0000;FF9AFFFF;1|LPD;R5_TCM_RAM_GLOBAL;FFE00000;FFE3FFFF;1|LPD;R5_1_Instruction_Cache;FFEC0000;FFECFFFF;1|LPD;R5_1_Data_Cache;FFED0000;FFEDFFFF;1|LPD;R5_1_BTCM_GLOBAL;FFEB0000;FFEBFFFF;1|LPD;R5_1_ATCM_GLOBAL;FFE90000;FFE9FFFF;1|LPD;R5_0_Instruction_Cache;FFE40000;FFE4FFFF;1|LPD;R5_0_Data_Cache;FFE50000;FFE5FFFF;1|LPD;R5_0_BTCM_GLOBAL;FFE20000;FFE2FFFF;1|LPD;R5_0_ATCM_GLOBAL;FFE00000;FFE0FFFF;1|LPD;QSPI_Linear_Address;C0000000;DFFFFFFF;1|LPD;QSPI;FF0F0000;FF0FFFFF;1|LPD;PMU_RAM;FFDC0000;FFDDFFFF;1|LPD;PMU_GLOBAL;FFD80000;FFDBFFFF;1|FPD;PCIE_MAIN;FD0E0000;FD0EFFFF;0|FPD;PCIE_LOW;E0000000;EFFFFFFF;0|FPD;PCIE_HIGH2;8000000000;BFFFFFFFFF;0|FPD;PCIE_HIGH1;600000000;7FFFFFFFF;0|FPD;PCIE_DMA;FD0F0000;FD0FFFFF;0|FPD;PCIE_ATTRIB;FD480000;FD48FFFF;0|LPD;OCM_XMPU_CFG;FFA70000;FFA7FFFF;1|LPD;OCM_SLCR;FF960000;FF96FFFF;1|OCM;OCM;FFFC0000;FFFFFFFF;1|LPD;NAND;FF100000;FF10FFFF;0|LPD;MBISTJTAG;FFCF0000;FFCFFFFF;1|LPD;LPD_XPPU_SINK;FF9C0000;FF9CFFFF;1|LPD;LPD_XPPU;FF980000;FF98FFFF;1|LPD;LPD_SLCR_SECURE;FF4B0000;FF4DFFFF;1|LPD;LPD_SLCR;FF410000;FF4AFFFF;1|LPD;LPD_GPV;FE100000;FE1FFFFF;1|LPD;LPD_DMA_7;FFAF0000;FFAFFFFF;1|LPD;LPD_DMA_6;FFAE0000;FFAEFFFF;1|LPD;LPD_DMA_5;FFAD0000;FFADFFFF;1|LPD;LPD_DMA_4;FFAC0000;FFACFFFF;1|LPD;LPD_DMA_3;FFAB0000;FFABFFFF;1|LPD;LPD_DMA_2;FFAA0000;FFAAFFFF;1|LPD;LPD_DMA_1;FFA90000;FFA9FFFF;1|LPD;LPD_DMA_0;FFA80000;FFA8FFFF;1|LPD;IPI_CTRL;FF380000;FF3FFFFF;1|LPD;IOU_SLCR;FF180000;FF23FFFF;1|LPD;IOU_SECURE_SLCR;FF240000;FF24FFFF;1|LPD;IOU_SCNTRS;FF260000;FF26FFFF;1|LPD;IOU_SCNTR;FF250000;FF25FFFF;1|LPD;IOU_GPV;FE000000;FE0FFFFF;1|LPD;I2C1;FF030000;FF03FFFF;1|LPD;I2C0;FF020000;FF02FFFF;1|FPD;GPU;FD4B0000;FD4BFFFF;0|LPD;GPIO;FF0A0000;FF0AFFFF;1|LPD;GEM3;FF0E0000;FF0EFFFF;1|LPD;GEM2;FF0D0000;FF0DFFFF;0|LPD;GEM1;FF0C0000;FF0CFFFF;0|LPD;GEM0;FF0B0000;FF0BFFFF;0|FPD;FPD_XMPU_SINK;FD4F0000;FD4FFFFF;1|FPD;FPD_XMPU_CFG;FD5D0000;FD5DFFFF;1|FPD;FPD_SLCR_SECURE;FD690000;FD6CFFFF;1|FPD;FPD_SLCR;FD610000;FD68FFFF;1|FPD;FPD_DMA_CH7;FD570000;FD57FFFF;1|FPD;FPD_DMA_CH6;FD560000;FD56FFFF;1|FPD;FPD_DMA_CH5;FD550000;FD55FFFF;1|FPD;FPD_DMA_CH4;FD540000;FD54FFFF;1|FPD;FPD_DMA_CH3;FD530000;FD53FFFF;1|FPD;FPD_DMA_CH2;FD520000;FD52FFFF;1|FPD;FPD_DMA_CH1;FD510000;FD51FFFF;1|FPD;FPD_DMA_CH0;FD500000;FD50FFFF;1|LPD;EFUSE;FFCC0000;FFCCFFFF;1|FPD;Display\
Port;FD4A0000;FD4AFFFF;0|FPD;DPDMA;FD4C0000;FD4CFFFF;0|FPD;DDR_XMPU5_CFG;FD050000;FD05FFFF;1|FPD;DDR_XMPU4_CFG;FD040000;FD04FFFF;1|FPD;DDR_XMPU3_CFG;FD030000;FD03FFFF;1|FPD;DDR_XMPU2_CFG;FD020000;FD02FFFF;1|FPD;DDR_XMPU1_CFG;FD010000;FD01FFFF;1|FPD;DDR_XMPU0_CFG;FD000000;FD00FFFF;1|FPD;DDR_QOS_CTRL;FD090000;FD09FFFF;1|FPD;DDR_PHY;FD080000;FD08FFFF;1|DDR;DDR_LOW;0;7FFFFFFF;1|DDR;DDR_HIGH;800000000;87FFFFFFF;1|FPD;DDDR_CTRL;FD070000;FD070FFF;1|LPD;Coresight;FE800000;FEFFFFFF;1|LPD;CSU_DMA;FFC80000;FFC9FFFF;1|LPD;CSU;FFCA0000;FFCAFFFF;1|LPD;CRL_APB;FF5E0000;FF85FFFF;1|FPD;CRF_APB;FD1A0000;FD2DFFFF;1|FPD;CCI_REG;FD5E0000;FD5EFFFF;1|LPD;CAN1;FF070000;FF07FFFF;0|LPD;CAN0;FF060000;FF06FFFF;0|FPD;APU;FD5C0000;FD5CFFFF;1|LPD;APM_INTC_IOU;FFA20000;FFA2FFFF;1|LPD;APM_FPD_LPD;FFA30000;FFA3FFFF;1|FPD;APM_5;FD490000;FD49FFFF;1|FPD;APM_0;FD0B0000;FD0BFFFF;1|LPD;APM2;FFA10000;FFA1FFFF;1|LPD;APM1;FFA00000;FFA0FFFF;1|LPD;AMS;FFA50000;FFA5FFFF;1|FPD;AFI_5;FD3B0000;FD3BFFFF;1|FPD;AFI_4;FD3A0000;FD3AFFFF;1|FPD;AFI_3;FD390000;FD39FFFF;1|FPD;AFI_2;FD380000;FD38FFFF;1|FPD;AFI_1;FD370000;FD37FFFF;1|FPD;AFI_0;FD360000;FD36FFFF;1|LPD;AFIFM6;FF9B0000;FF9BFFFF;1|FPD;ACPU_GIC;F9010000;F907FFFF;1}\
\
    CONFIG.PSU__PROTECTION__SUBSYSTEMS {PMU Firmware:PMU|Secure Subsystem:} \
    CONFIG.PSU__PSS_ALT_REF_CLK__ENABLE {0} \
    CONFIG.PSU__PSS_ALT_REF_CLK__FREQMHZ {33.333} \
    CONFIG.PSU__PSS_REF_CLK__FREQMHZ {33.333333333333333333333333333333333333333333333333333333} \
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
    CONFIG.PSU__SATA__LANE1__IO {GT Lane3} \
    CONFIG.PSU__SATA__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__SATA__REF_CLK_FREQ {125} \
    CONFIG.PSU__SATA__REF_CLK_SEL {Ref Clk3} \
    CONFIG.PSU__SAXIGP2__DATA_WIDTH {128} \
    CONFIG.PSU__SD0__CLK_100_SDR_OTAP_DLY {0x3} \
    CONFIG.PSU__SD0__CLK_200_SDR_OTAP_DLY {0x3} \
    CONFIG.PSU__SD0__CLK_50_DDR_ITAP_DLY {0x3D} \
    CONFIG.PSU__SD0__CLK_50_DDR_OTAP_DLY {0x4} \
    CONFIG.PSU__SD0__CLK_50_SDR_ITAP_DLY {0x15} \
    CONFIG.PSU__SD0__CLK_50_SDR_OTAP_DLY {0x5} \
    CONFIG.PSU__SD0__PERIPHERAL__ENABLE {0} \
    CONFIG.PSU__SD0__RESET__ENABLE {0} \
    CONFIG.PSU__SD1_COHERENCY {0} \
    CONFIG.PSU__SD1_ROUTE_THROUGH_FPD {0} \
    CONFIG.PSU__SD1__CLK_100_SDR_OTAP_DLY {0x3} \
    CONFIG.PSU__SD1__CLK_200_SDR_OTAP_DLY {0x3} \
    CONFIG.PSU__SD1__CLK_50_DDR_ITAP_DLY {0x3D} \
    CONFIG.PSU__SD1__CLK_50_DDR_OTAP_DLY {0x4} \
    CONFIG.PSU__SD1__CLK_50_SDR_ITAP_DLY {0x15} \
    CONFIG.PSU__SD1__CLK_50_SDR_OTAP_DLY {0x5} \
    CONFIG.PSU__SD1__DATA_TRANSFER_MODE {8Bit} \
    CONFIG.PSU__SD1__GRP_CD__ENABLE {1} \
    CONFIG.PSU__SD1__GRP_CD__IO {MIO 45} \
    CONFIG.PSU__SD1__GRP_POW__ENABLE {0} \
    CONFIG.PSU__SD1__GRP_WP__ENABLE {0} \
    CONFIG.PSU__SD1__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__SD1__PERIPHERAL__IO {MIO 39 .. 51} \
    CONFIG.PSU__SD1__SLOT_TYPE {SD 3.0} \
    CONFIG.PSU__SPI0_LOOP_SPI1__ENABLE {0} \
    CONFIG.PSU__SPI0__PERIPHERAL__ENABLE {0} \
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
    CONFIG.PSU__UART1__PERIPHERAL__ENABLE {0} \
    CONFIG.PSU__USB0_COHERENCY {0} \
    CONFIG.PSU__USB0__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__USB0__PERIPHERAL__IO {MIO 52 .. 63} \
    CONFIG.PSU__USB0__REF_CLK_FREQ {26} \
    CONFIG.PSU__USB0__REF_CLK_SEL {Ref Clk2} \
    CONFIG.PSU__USB1__PERIPHERAL__ENABLE {0} \
    CONFIG.PSU__USB2_0__EMIO__ENABLE {0} \
    CONFIG.PSU__USB3_0__EMIO__ENABLE {0} \
    CONFIG.PSU__USB3_0__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__USB3_0__PERIPHERAL__IO {GT Lane2} \
    CONFIG.PSU__USB__RESET__MODE {Boot Pin} \
    CONFIG.PSU__USB__RESET__POLARITY {Active Low} \
    CONFIG.PSU__USE_DIFF_RW_CLK_GP2 {0} \
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
    CONFIG.PSU__USE__M_AXI_GP2 {1} \
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
    CONFIG.PSU__USE__S_AXI_GP0 {0} \
    CONFIG.PSU__USE__S_AXI_GP1 {0} \
    CONFIG.PSU__USE__S_AXI_GP2 {1} \
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
  connect_bd_intf_net -intf_net DSPinterconnect_M01_AXI [get_bd_intf_pins DSPinterconnect/M01_AXI] [get_bd_intf_pins zynq_ultra_ps_e_0/S_AXI_HP0_FPD]
  connect_bd_intf_net -intf_net S00_AXI_2 [get_bd_intf_pins axi_hpm0_lpd/S00_AXI] [get_bd_intf_pins zynq_ultra_ps_e_0/M_AXI_HPM0_LPD]
  connect_bd_intf_net -intf_net Vp_Vn_1 [get_bd_intf_ports Vp_Vn] [get_bd_intf_pins system_management_wiz_0/Vp_Vn]
  connect_bd_intf_net -intf_net adc2_clk_1 [get_bd_intf_ports adc2_clk] [get_bd_intf_pins radio/adc2_clk]
  connect_bd_intf_net -intf_net axi_hpm0_lpd_M00_AXI [get_bd_intf_pins axi_hpm0_lpd/M00_AXI] [get_bd_intf_pins radio/S_AXI]
  connect_bd_intf_net -intf_net axi_hpm0_lpd_M01_AXI [get_bd_intf_pins axi_hpm0_lpd/M01_AXI] [get_bd_intf_pins sws_gpio/S_AXI]
  connect_bd_intf_net -intf_net axi_hpm0_lpd_M02_AXI [get_bd_intf_pins axi_hpm0_lpd/M02_AXI] [get_bd_intf_pins leds_r/S_AXI]
  connect_bd_intf_net -intf_net axi_hpm0_lpd_M03_AXI [get_bd_intf_pins axi_hpm0_lpd/M03_AXI] [get_bd_intf_pins btns_gpio/S_AXI]
  connect_bd_intf_net -intf_net axi_hpm0_lpd_M04_AXI [get_bd_intf_pins axi_hpm0_lpd/M04_AXI] [get_bd_intf_pins system_management_wiz_0/S_AXI_LITE]
  connect_bd_intf_net -intf_net axi_hpm0_lpd_M05_AXI [get_bd_intf_pins axi_hpm0_lpd/M05_AXI] [get_bd_intf_pins leds_g/S_AXI]
  connect_bd_intf_net -intf_net axi_hpm0_lpd_M06_AXI [get_bd_intf_pins axi_hpm0_lpd/M06_AXI] [get_bd_intf_pins leds_b/S_AXI]
  connect_bd_intf_net -intf_net axi_interconnect_0_M00_AXI1 [get_bd_intf_pins DSPinterconnect/M00_AXI] [get_bd_intf_pins DSPmemory/C0_DDR4_S_AXI]
  connect_bd_intf_net -intf_net btns_gpio_GPIO [get_bd_intf_ports push_buttons_5bits] [get_bd_intf_pins btns_gpio/GPIO]
  connect_bd_intf_net -intf_net dac2_clk_0_1 [get_bd_intf_ports dac2_clk] [get_bd_intf_pins radio/dac2_clk]
  connect_bd_intf_net -intf_net ddr4_0_C0_DDR4 [get_bd_intf_ports ddr4_sdram_c0] [get_bd_intf_pins DSPmemory/ddr4_sdram_c0]
  connect_bd_intf_net -intf_net default_sysclk_c0_300mhz_1 [get_bd_intf_ports default_sysclk_c0_300mhz] [get_bd_intf_pins DSPmemory/default_sysclk_c0_300mhz]
  connect_bd_intf_net -intf_net leds_b_GPIO [get_bd_intf_ports led_b_8bits] [get_bd_intf_pins leds_b/GPIO]
  connect_bd_intf_net -intf_net leds_g_GPIO [get_bd_intf_ports led_g_8bits] [get_bd_intf_pins leds_g/GPIO]
  connect_bd_intf_net -intf_net leds_gpio_GPIO [get_bd_intf_ports led_r_8bits] [get_bd_intf_pins leds_r/GPIO]
  connect_bd_intf_net -intf_net radio_M03_AXI [get_bd_intf_pins axi_intc_0/s_axi] [get_bd_intf_pins radio/M03_AXI]
  connect_bd_intf_net -intf_net radio_M_AXI [get_bd_intf_pins DSPinterconnect/S00_AXI] [get_bd_intf_pins radio/M_AXI]
  connect_bd_intf_net -intf_net radio_vout00_0 [get_bd_intf_ports vout00] [get_bd_intf_pins radio/vout00]
  connect_bd_intf_net -intf_net radio_vout10_0 [get_bd_intf_ports vout10] [get_bd_intf_pins radio/vout10]
  connect_bd_intf_net -intf_net radio_vout20_0 [get_bd_intf_ports vout20] [get_bd_intf_pins radio/vout20]
  connect_bd_intf_net -intf_net radio_vout30_0 [get_bd_intf_ports vout30] [get_bd_intf_pins radio/vout30]
  connect_bd_intf_net -intf_net sws_gpio_GPIO [get_bd_intf_ports dip_switches_8bits] [get_bd_intf_pins sws_gpio/GPIO]
  connect_bd_intf_net -intf_net sysref_in_1 [get_bd_intf_ports sysref_in] [get_bd_intf_pins radio/sysref_in]
  connect_bd_intf_net -intf_net vin00_0_1 [get_bd_intf_ports vin00] [get_bd_intf_pins radio/vin00]
  connect_bd_intf_net -intf_net vin01_0_1 [get_bd_intf_ports vin01] [get_bd_intf_pins radio/vin01]
  connect_bd_intf_net -intf_net vin10_0_1 [get_bd_intf_ports vin10] [get_bd_intf_pins radio/vin10]
  connect_bd_intf_net -intf_net vin11_0_1 [get_bd_intf_ports vin11] [get_bd_intf_pins radio/vin11]
  connect_bd_intf_net -intf_net vin20_0_1 [get_bd_intf_ports vin20] [get_bd_intf_pins radio/vin20]
  connect_bd_intf_net -intf_net vin21_0_1 [get_bd_intf_ports vin21] [get_bd_intf_pins radio/vin21]
  connect_bd_intf_net -intf_net vin30_0_1 [get_bd_intf_ports vin30] [get_bd_intf_pins radio/vin30]
  connect_bd_intf_net -intf_net vin31_0_1 [get_bd_intf_ports vin31] [get_bd_intf_pins radio/vin31]
  connect_bd_intf_net -intf_net zynq_ultra_ps_e_0_M_AXI_HPM0_FPD [get_bd_intf_pins DSPinterconnect/S01_AXI] [get_bd_intf_pins zynq_ultra_ps_e_0/M_AXI_HPM0_FPD]

  # Create port connections
  connect_bd_net -net axi_intc_0_irq [get_bd_pins axi_intc_0/irq] [get_bd_pins xlconcat_0/In0]
  connect_bd_net -net btns_gpio_ip2intc_irpt [get_bd_pins btns_gpio/ip2intc_irpt] [get_bd_pins xlconcat_0/In2]
  connect_bd_net -net clk_wiz_0_clk_out1 [get_bd_pins clk_wiz_310MHz/clk_out1] [get_bd_pins radio/m_axi_aclk] [get_bd_pins DSPinterconnect/S00_ACLK] [get_bd_pins DSPinterconnect/M01_ACLK] [get_bd_pins proc_sys_reset_2/slowest_sync_clk] [get_bd_pins zynq_ultra_ps_e_0/saxihp0_fpd_aclk]
  connect_bd_net -net ddr4_0_c0_ddr4_ui_clk [get_bd_pins DSPmemory/c0_ddr4_ui_clk] [get_bd_pins DSPinterconnect/M00_ACLK]
  connect_bd_net -net m_axi_aresetn_1 [get_bd_pins proc_sys_reset_2/peripheral_aresetn] [get_bd_pins radio/m_axi_aresetn] [get_bd_pins DSPinterconnect/S00_ARESETN] [get_bd_pins DSPinterconnect/M01_ARESETN]
  connect_bd_net -net primary_reset [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] [get_bd_pins radio/s_axi_aclk] [get_bd_pins axi_hpm0_lpd/ACLK] [get_bd_pins axi_hpm0_lpd/S00_ACLK] [get_bd_pins axi_hpm0_lpd/M00_ACLK] [get_bd_pins axi_hpm0_lpd/M01_ACLK] [get_bd_pins axi_hpm0_lpd/M02_ACLK] [get_bd_pins axi_hpm0_lpd/M03_ACLK] [get_bd_pins axi_hpm0_lpd/M04_ACLK] [get_bd_pins axi_intc_0/s_axi_aclk] [get_bd_pins btns_gpio/s_axi_aclk] [get_bd_pins leds_r/s_axi_aclk] [get_bd_pins proc_sys_reset_0/slowest_sync_clk] [get_bd_pins sws_gpio/s_axi_aclk] [get_bd_pins system_management_wiz_0/s_axi_aclk] [get_bd_pins zynq_ultra_ps_e_0/maxihpm0_lpd_aclk] [get_bd_pins leds_g/s_axi_aclk] [get_bd_pins axi_hpm0_lpd/M05_ACLK] [get_bd_pins leds_b/s_axi_aclk] [get_bd_pins axi_hpm0_lpd/M06_ACLK]
  connect_bd_net -net proc_sys_reset_0_bus_struct_reset [get_bd_pins proc_sys_reset_0/bus_struct_reset] [get_bd_pins DSPmemory/src_rst]
  connect_bd_net -net proc_sys_reset_0_peripheral_aresetn [get_bd_pins DSPmemory/peripheral_aresetn] [get_bd_pins DSPinterconnect/M00_ARESETN]
  connect_bd_net -net proc_sys_reset_1_interconnect_aresetn [get_bd_pins proc_sys_reset_0/interconnect_aresetn] [get_bd_pins axi_hpm0_lpd/ARESETN]
  connect_bd_net -net proc_sys_reset_1_peripheral_aresetn [get_bd_pins proc_sys_reset_1/peripheral_aresetn] [get_bd_pins clk_wiz_310MHz/resetn]
  connect_bd_net -net radio_dout [get_bd_pins radio/dout] [get_bd_pins axi_intc_0/intr]
  connect_bd_net -net rst_ps8_0_99M_peripheral_aresetn [get_bd_pins proc_sys_reset_0/peripheral_aresetn] [get_bd_pins radio/s_axi_aresetn] [get_bd_pins axi_hpm0_lpd/S00_ARESETN] [get_bd_pins axi_hpm0_lpd/M00_ARESETN] [get_bd_pins axi_hpm0_lpd/M01_ARESETN] [get_bd_pins axi_hpm0_lpd/M02_ARESETN] [get_bd_pins axi_hpm0_lpd/M03_ARESETN] [get_bd_pins axi_hpm0_lpd/M04_ARESETN] [get_bd_pins axi_intc_0/s_axi_aresetn] [get_bd_pins btns_gpio/s_axi_aresetn] [get_bd_pins leds_r/s_axi_aresetn] [get_bd_pins sws_gpio/s_axi_aresetn] [get_bd_pins system_management_wiz_0/s_axi_aresetn] [get_bd_pins leds_g/s_axi_aresetn] [get_bd_pins axi_hpm0_lpd/M05_ARESETN] [get_bd_pins leds_b/s_axi_aresetn] [get_bd_pins axi_hpm0_lpd/M06_ARESETN]
  connect_bd_net -net sws_gpio_ip2intc_irpt [get_bd_pins sws_gpio/ip2intc_irpt] [get_bd_pins xlconcat_0/In3]
  connect_bd_net -net system_management_wiz_0_ip2intc_irpt [get_bd_pins system_management_wiz_0/ip2intc_irpt] [get_bd_pins xlconcat_0/In1]
  connect_bd_net -net xlconcat_0_dout [get_bd_pins xlconcat_0/dout] [get_bd_pins zynq_ultra_ps_e_0/pl_ps_irq0]
  connect_bd_net -net xlconcat_1_dout [get_bd_pins DSPmemory/dout] [get_bd_pins zynq_ultra_ps_e_0/emio_gpio_i]
  connect_bd_net -net xpm_cdc_gen_0_dest_rst_out [get_bd_pins xpm_cdc_gen_0/dest_rst_out] [get_bd_pins DSPinterconnect/ARESETN] [get_bd_pins DSPinterconnect/S01_ARESETN]
  connect_bd_net -net zynq_ultra_ps_e_0_pl_clk1 [get_bd_pins zynq_ultra_ps_e_0/pl_clk1] [get_bd_pins clk_wiz_310MHz/clk_in1] [get_bd_pins proc_sys_reset_1/slowest_sync_clk]
  connect_bd_net -net zynq_ultra_ps_e_0_pl_clk2 [get_bd_pins zynq_ultra_ps_e_0/pl_clk2] [get_bd_pins DSPinterconnect/ACLK] [get_bd_pins DSPinterconnect/S01_ACLK] [get_bd_pins xpm_cdc_gen_0/dest_clk] [get_bd_pins zynq_ultra_ps_e_0/maxihpm0_fpd_aclk]
  connect_bd_net -net zynq_ultra_ps_e_0_pl_resetn0 [get_bd_pins zynq_ultra_ps_e_0/pl_resetn0] [get_bd_pins radio/ext_reset] [get_bd_pins proc_sys_reset_0/ext_reset_in] [get_bd_pins proc_sys_reset_1/ext_reset_in] [get_bd_pins proc_sys_reset_2/ext_reset_in] [get_bd_pins xpm_cdc_gen_0/src_rst]

  # Create address segments
  assign_bd_address -offset 0x000400000000 -range 0x000100000000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs DSPmemory/DSPddr4/C0_DDR4_MEMORY_MAP/C0_DDR4_ADDRESS_BLOCK] -force
  assign_bd_address -offset 0x80130000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs radio/transmitter/channel_00/amplitude_controller/S_AXI/S_AXI_reg] -force
  assign_bd_address -offset 0x80180000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs radio/transmitter/channel_10/amplitude_controller/S_AXI/S_AXI_reg] -force
  assign_bd_address -offset 0x80190000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs radio/transmitter/channel_20/amplitude_controller/S_AXI/S_AXI_reg] -force
  assign_bd_address -offset 0x801A0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs radio/transmitter/channel_30/amplitude_controller/S_AXI/S_AXI_reg] -force
  assign_bd_address -offset 0x80070000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs radio/receiver/channel_00/axi_dma_imag/S_AXI_LITE/Reg] -force
  assign_bd_address -offset 0x800A0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs radio/receiver/channel_10/axi_dma_imag/S_AXI_LITE/Reg] -force
  assign_bd_address -offset 0x800D0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs radio/receiver/channel_20/axi_dma_imag/S_AXI_LITE/Reg] -force
  assign_bd_address -offset 0x80100000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs radio/receiver/channel_30/axi_dma_imag/S_AXI_LITE/Reg] -force
  assign_bd_address -offset 0x80080000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs radio/receiver/channel_00/axi_dma_real/S_AXI_LITE/Reg] -force
  assign_bd_address -offset 0x800B0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs radio/receiver/channel_10/axi_dma_real/S_AXI_LITE/Reg] -force
  assign_bd_address -offset 0x800E0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs radio/receiver/channel_20/axi_dma_real/S_AXI_LITE/Reg] -force
  assign_bd_address -offset 0x80110000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs radio/receiver/channel_30/axi_dma_real/S_AXI_LITE/Reg] -force
  assign_bd_address -offset 0x80060000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axi_intc_0/S_AXI/Reg] -force
  assign_bd_address -offset 0x80020000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs btns_gpio/S_AXI/Reg] -force
  assign_bd_address -offset 0x80000000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs leds_b/S_AXI/Reg] -force
  assign_bd_address -offset 0x80010000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs leds_g/S_AXI/Reg] -force
  assign_bd_address -offset 0x80030000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs leds_r/S_AXI/Reg] -force
  assign_bd_address -offset 0x80090000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs radio/receiver/channel_00/packet_generator/S_AXI/S_AXI_reg] -force
  assign_bd_address -offset 0x800C0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs radio/receiver/channel_10/packet_generator/S_AXI/S_AXI_reg] -force
  assign_bd_address -offset 0x800F0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs radio/receiver/channel_20/packet_generator/S_AXI/S_AXI_reg] -force
  assign_bd_address -offset 0x80120000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs radio/receiver/channel_30/packet_generator/S_AXI/S_AXI_reg] -force
  assign_bd_address -offset 0x80140000 -range 0x00040000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs radio/rfdc/s_axi/Reg] -force
  assign_bd_address -offset 0x80040000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs sws_gpio/S_AXI/Reg] -force
  assign_bd_address -offset 0x80050000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs system_management_wiz_0/S_AXI_LITE/Reg] -force
  assign_bd_address -offset 0x80000000 -range 0x40000000 -target_address_space [get_bd_addr_spaces radio/receiver/channel_00/axi_dma_imag/Data_S2MM] [get_bd_addr_segs DSPmemory/DSPddr4/C0_DDR4_MEMORY_MAP/C0_DDR4_ADDRESS_BLOCK] -force
  assign_bd_address -offset 0x000800000000 -range 0x000800000000 -target_address_space [get_bd_addr_spaces radio/receiver/channel_00/axi_dma_imag/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP2/HP0_DDR_HIGH] -force
  assign_bd_address -offset 0x00000000 -range 0x80000000 -target_address_space [get_bd_addr_spaces radio/receiver/channel_00/axi_dma_imag/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP2/HP0_DDR_LOW] -force
  assign_bd_address -offset 0x80000000 -range 0x40000000 -target_address_space [get_bd_addr_spaces radio/receiver/channel_00/axi_dma_real/Data_S2MM] [get_bd_addr_segs DSPmemory/DSPddr4/C0_DDR4_MEMORY_MAP/C0_DDR4_ADDRESS_BLOCK] -force
  assign_bd_address -offset 0x000800000000 -range 0x000800000000 -target_address_space [get_bd_addr_spaces radio/receiver/channel_00/axi_dma_real/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP2/HP0_DDR_HIGH] -force
  assign_bd_address -offset 0x00000000 -range 0x80000000 -target_address_space [get_bd_addr_spaces radio/receiver/channel_00/axi_dma_real/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP2/HP0_DDR_LOW] -force
  assign_bd_address -offset 0x80000000 -range 0x40000000 -target_address_space [get_bd_addr_spaces radio/receiver/channel_10/axi_dma_imag/Data_S2MM] [get_bd_addr_segs DSPmemory/DSPddr4/C0_DDR4_MEMORY_MAP/C0_DDR4_ADDRESS_BLOCK] -force
  assign_bd_address -offset 0x000800000000 -range 0x000800000000 -target_address_space [get_bd_addr_spaces radio/receiver/channel_10/axi_dma_imag/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP2/HP0_DDR_HIGH] -force
  assign_bd_address -offset 0x00000000 -range 0x80000000 -target_address_space [get_bd_addr_spaces radio/receiver/channel_10/axi_dma_imag/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP2/HP0_DDR_LOW] -force
  assign_bd_address -offset 0x80000000 -range 0x40000000 -target_address_space [get_bd_addr_spaces radio/receiver/channel_10/axi_dma_real/Data_S2MM] [get_bd_addr_segs DSPmemory/DSPddr4/C0_DDR4_MEMORY_MAP/C0_DDR4_ADDRESS_BLOCK] -force
  assign_bd_address -offset 0x000800000000 -range 0x000800000000 -target_address_space [get_bd_addr_spaces radio/receiver/channel_10/axi_dma_real/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP2/HP0_DDR_HIGH] -force
  assign_bd_address -offset 0x00000000 -range 0x80000000 -target_address_space [get_bd_addr_spaces radio/receiver/channel_10/axi_dma_real/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP2/HP0_DDR_LOW] -force
  assign_bd_address -offset 0x80000000 -range 0x40000000 -target_address_space [get_bd_addr_spaces radio/receiver/channel_20/axi_dma_imag/Data_S2MM] [get_bd_addr_segs DSPmemory/DSPddr4/C0_DDR4_MEMORY_MAP/C0_DDR4_ADDRESS_BLOCK] -force
  assign_bd_address -offset 0x000800000000 -range 0x000800000000 -target_address_space [get_bd_addr_spaces radio/receiver/channel_20/axi_dma_imag/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP2/HP0_DDR_HIGH] -force
  assign_bd_address -offset 0x00000000 -range 0x80000000 -target_address_space [get_bd_addr_spaces radio/receiver/channel_20/axi_dma_imag/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP2/HP0_DDR_LOW] -force
  assign_bd_address -offset 0x80000000 -range 0x40000000 -target_address_space [get_bd_addr_spaces radio/receiver/channel_20/axi_dma_real/Data_S2MM] [get_bd_addr_segs DSPmemory/DSPddr4/C0_DDR4_MEMORY_MAP/C0_DDR4_ADDRESS_BLOCK] -force
  assign_bd_address -offset 0x000800000000 -range 0x000800000000 -target_address_space [get_bd_addr_spaces radio/receiver/channel_20/axi_dma_real/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP2/HP0_DDR_HIGH] -force
  assign_bd_address -offset 0x00000000 -range 0x80000000 -target_address_space [get_bd_addr_spaces radio/receiver/channel_20/axi_dma_real/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP2/HP0_DDR_LOW] -force
  assign_bd_address -offset 0x80000000 -range 0x40000000 -target_address_space [get_bd_addr_spaces radio/receiver/channel_30/axi_dma_imag/Data_S2MM] [get_bd_addr_segs DSPmemory/DSPddr4/C0_DDR4_MEMORY_MAP/C0_DDR4_ADDRESS_BLOCK] -force
  assign_bd_address -offset 0x000800000000 -range 0x000800000000 -target_address_space [get_bd_addr_spaces radio/receiver/channel_30/axi_dma_imag/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP2/HP0_DDR_HIGH] -force
  assign_bd_address -offset 0x00000000 -range 0x80000000 -target_address_space [get_bd_addr_spaces radio/receiver/channel_30/axi_dma_imag/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP2/HP0_DDR_LOW] -force
  assign_bd_address -offset 0x80000000 -range 0x40000000 -target_address_space [get_bd_addr_spaces radio/receiver/channel_30/axi_dma_real/Data_S2MM] [get_bd_addr_segs DSPmemory/DSPddr4/C0_DDR4_MEMORY_MAP/C0_DDR4_ADDRESS_BLOCK] -force
  assign_bd_address -offset 0x000800000000 -range 0x000800000000 -target_address_space [get_bd_addr_spaces radio/receiver/channel_30/axi_dma_real/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP2/HP0_DDR_HIGH] -force
  assign_bd_address -offset 0x00000000 -range 0x80000000 -target_address_space [get_bd_addr_spaces radio/receiver/channel_30/axi_dma_real/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP2/HP0_DDR_LOW] -force

  # Exclude Address Segments
  exclude_bd_addr_seg -offset 0xFF000000 -range 0x01000000 -target_address_space [get_bd_addr_spaces radio/receiver/channel_00/axi_dma_imag/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP2/HP0_LPS_OCM]
  exclude_bd_addr_seg -offset 0xC0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces radio/receiver/channel_00/axi_dma_imag/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP2/HP0_QSPI]
  exclude_bd_addr_seg -offset 0xFF000000 -range 0x01000000 -target_address_space [get_bd_addr_spaces radio/receiver/channel_00/axi_dma_real/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP2/HP0_LPS_OCM]
  exclude_bd_addr_seg -offset 0xC0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces radio/receiver/channel_00/axi_dma_real/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP2/HP0_QSPI]
  exclude_bd_addr_seg -offset 0xFF000000 -range 0x01000000 -target_address_space [get_bd_addr_spaces radio/receiver/channel_10/axi_dma_imag/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP2/HP0_LPS_OCM]
  exclude_bd_addr_seg -offset 0xC0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces radio/receiver/channel_10/axi_dma_imag/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP2/HP0_QSPI]
  exclude_bd_addr_seg -offset 0xFF000000 -range 0x01000000 -target_address_space [get_bd_addr_spaces radio/receiver/channel_10/axi_dma_real/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP2/HP0_LPS_OCM]
  exclude_bd_addr_seg -offset 0xC0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces radio/receiver/channel_10/axi_dma_real/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP2/HP0_QSPI]
  exclude_bd_addr_seg -offset 0xFF000000 -range 0x01000000 -target_address_space [get_bd_addr_spaces radio/receiver/channel_20/axi_dma_imag/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP2/HP0_LPS_OCM]
  exclude_bd_addr_seg -offset 0xC0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces radio/receiver/channel_20/axi_dma_imag/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP2/HP0_QSPI]
  exclude_bd_addr_seg -offset 0xFF000000 -range 0x01000000 -target_address_space [get_bd_addr_spaces radio/receiver/channel_20/axi_dma_real/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP2/HP0_LPS_OCM]
  exclude_bd_addr_seg -offset 0xC0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces radio/receiver/channel_20/axi_dma_real/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP2/HP0_QSPI]
  exclude_bd_addr_seg -offset 0xFF000000 -range 0x01000000 -target_address_space [get_bd_addr_spaces radio/receiver/channel_30/axi_dma_imag/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP2/HP0_LPS_OCM]
  exclude_bd_addr_seg -offset 0xC0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces radio/receiver/channel_30/axi_dma_imag/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP2/HP0_QSPI]
  exclude_bd_addr_seg -offset 0xFF000000 -range 0x01000000 -target_address_space [get_bd_addr_spaces radio/receiver/channel_30/axi_dma_real/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP2/HP0_LPS_OCM]
  exclude_bd_addr_seg -offset 0xC0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces radio/receiver/channel_30/axi_dma_real/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP2/HP0_QSPI]
  exclude_bd_addr_seg -offset 0x000800000000 -range 0x000800000000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP2/HP0_DDR_HIGH]
  exclude_bd_addr_seg -offset 0x00000000 -range 0x80000000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP2/HP0_DDR_LOW]
  exclude_bd_addr_seg -offset 0xFF000000 -range 0x01000000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP2/HP0_LPS_OCM]
  exclude_bd_addr_seg -offset 0xC0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP2/HP0_QSPI]

  # Perform GUI Layout
  regenerate_bd_layout -layout_string {
   "ActiveEmotionalView":"Default View",
   "Default View_ScaleFactor":"0.71864",
   "Default View_TopLeft":"2260,756",
   "ExpandedHierarchyInLayout":"",
   "guistr":"# # String gsaved with Nlview 7.5.8 2022-09-21 7111 VDI=41 GEI=38 GUI=JA:10.0 TLS
#  -string -flagsOSRD
preplace port Vp_Vn -pg 1 -lvl 0 -x -10 -y 220 -defaultsOSRD
preplace port dac2_clk -pg 1 -lvl 0 -x -10 -y 1260 -defaultsOSRD
preplace port ddr4_sdram_c0 -pg 1 -lvl 10 -x 3710 -y 870 -defaultsOSRD
preplace port default_sysclk_c0_300mhz -pg 1 -lvl 0 -x -10 -y 1010 -defaultsOSRD
preplace port dip_switches_8bits -pg 1 -lvl 10 -x 3710 -y 700 -defaultsOSRD
preplace port push_buttons_5bits -pg 1 -lvl 10 -x 3710 -y 1030 -defaultsOSRD
preplace port sysref_in -pg 1 -lvl 0 -x -10 -y 1280 -defaultsOSRD
preplace port vout00 -pg 1 -lvl 10 -x 3710 -y 1360 -defaultsOSRD
preplace port vout10 -pg 1 -lvl 10 -x 3710 -y 1380 -defaultsOSRD
preplace port vout20 -pg 1 -lvl 10 -x 3710 -y 1400 -defaultsOSRD
preplace port vout30 -pg 1 -lvl 10 -x 3710 -y 1420 -defaultsOSRD
preplace port vin00 -pg 1 -lvl 0 -x -10 -y 1300 -defaultsOSRD
preplace port vin01 -pg 1 -lvl 0 -x -10 -y 1320 -defaultsOSRD
preplace port vin10 -pg 1 -lvl 0 -x -10 -y 1340 -defaultsOSRD
preplace port vin11 -pg 1 -lvl 0 -x -10 -y 1360 -defaultsOSRD
preplace port vin20 -pg 1 -lvl 0 -x -10 -y 1380 -defaultsOSRD
preplace port vin21 -pg 1 -lvl 0 -x -10 -y 1400 -defaultsOSRD
preplace port vin30 -pg 1 -lvl 0 -x -10 -y 1420 -defaultsOSRD
preplace port vin31 -pg 1 -lvl 0 -x -10 -y 1440 -defaultsOSRD
preplace port led_r_8bits -pg 1 -lvl 10 -x 3710 -y 70 -defaultsOSRD
preplace port led_g_8bits -pg 1 -lvl 10 -x 3710 -y 410 -defaultsOSRD
preplace port led_b_8bits -pg 1 -lvl 10 -x 3710 -y 550 -defaultsOSRD
preplace port adc2_clk -pg 1 -lvl 0 -x -10 -y 1240 -defaultsOSRD
preplace inst DSPmemory -pg 1 -lvl 8 -x 3190 -y 900 -defaultsOSRD
preplace inst radio -pg 1 -lvl 8 -x 3190 -y 1380 -defaultsOSRD
preplace inst DSPinterconnect -pg 1 -lvl 4 -x 1190 -y 770 -defaultsOSRD
preplace inst axi_hpm0_lpd -pg 1 -lvl 6 -x 2250 -y 460 -defaultsOSRD
preplace inst axi_intc_0 -pg 1 -lvl 9 -x 3583 -y 1270 -defaultsOSRD
preplace inst btns_gpio -pg 1 -lvl 8 -x 3190 -y 1040 -defaultsOSRD
preplace inst clk_wiz_310MHz -pg 1 -lvl 2 -x 490 -y 1110 -defaultsOSRD
preplace inst leds_r -pg 1 -lvl 8 -x 3190 -y 70 -defaultsOSRD
preplace inst leds_g -pg 1 -lvl 8 -x 3190 -y 410 -defaultsOSRD
preplace inst leds_b -pg 1 -lvl 8 -x 3190 -y 550 -defaultsOSRD
preplace inst proc_sys_reset_0 -pg 1 -lvl 5 -x 1700 -y 550 -defaultsOSRD
preplace inst proc_sys_reset_1 -pg 1 -lvl 1 -x 200 -y 1130 -defaultsOSRD
preplace inst proc_sys_reset_2 -pg 1 -lvl 3 -x 780 -y 1140 -defaultsOSRD
preplace inst sws_gpio -pg 1 -lvl 8 -x 3190 -y 710 -defaultsOSRD
preplace inst system_management_wiz_0 -pg 1 -lvl 7 -x 2630 -y 230 -defaultsOSRD
preplace inst xlconcat_0 -pg 1 -lvl 4 -x 1190 -y 510 -defaultsOSRD
preplace inst xpm_cdc_gen_0 -pg 1 -lvl 3 -x 780 -y 880 -defaultsOSRD
preplace inst zynq_ultra_ps_e_0 -pg 1 -lvl 5 -x 1700 -y 820 -defaultsOSRD
preplace netloc axi_intc_0_irq 1 3 7 970 0 NJ 0 NJ 0 NJ 0 2980J 150 NJ 150 3690
preplace netloc btns_gpio_ip2intc_irpt 1 3 6 980 10 NJ 10 NJ 10 NJ 10 2970J 160 3430
preplace netloc clk_wiz_0_clk_out1 1 2 6 590 950 990 950 1360 660 2050J 710 NJ 710 2810
preplace netloc ddr4_0_c0_ddr4_ui_clk 1 3 6 1040 1120 NJ 1120 NJ 1120 NJ 1120 NJ 1120 3410
preplace netloc m_axi_aresetn_1 1 3 5 1000 1230 NJ 1230 NJ 1230 NJ 1230 2790J
preplace netloc primary_reset 1 4 5 1390 450 2070 200 2440 40 2940 1160 3430J
preplace netloc proc_sys_reset_0_bus_struct_reset 1 5 3 2030J 210 2450J 470 2960
preplace netloc proc_sys_reset_0_peripheral_aresetn 1 3 6 1020 1130 NJ 1130 NJ 1130 NJ 1130 NJ 1130 3400
preplace netloc proc_sys_reset_1_interconnect_aresetn 1 5 1 2090 320n
preplace netloc proc_sys_reset_1_peripheral_aresetn 1 1 1 380 1100n
preplace netloc radio_dout 1 8 1 3430 1300n
preplace netloc rst_ps8_0_99M_peripheral_aresetn 1 5 4 2100 190 2470 50 2930 1590 3420J
preplace netloc sws_gpio_ip2intc_irpt 1 3 6 1020 20 NJ 20 NJ 20 NJ 20 2960J 170 3400
preplace netloc system_management_wiz_0_ip2intc_irpt 1 3 5 1040 30 NJ 30 NJ 30 NJ 30 2810
preplace netloc xlconcat_0_dout 1 4 1 1340 510n
preplace netloc xlconcat_1_dout 1 5 4 NJ 800 NJ 800 NJ 800 3400
preplace netloc xpm_cdc_gen_0_dest_rst_out 1 3 1 970 720n
preplace netloc zynq_ultra_ps_e_0_pl_clk1 1 0 6 20 1230 390 1230 600J 1250 NJ 1250 NJ 1250 2010
preplace netloc zynq_ultra_ps_e_0_pl_clk2 1 2 4 600 810 980 940 1370 670 2030
preplace netloc zynq_ultra_ps_e_0_pl_resetn0 1 0 8 10 1000 NJ 1000 600 970 NJ 970 1350 650 2060 1000 NJ 1000 2800
preplace netloc DSPinterconnect_M01_AXI 1 4 1 N 780
preplace netloc S00_AXI_2 1 5 1 2080 280n
preplace netloc Vp_Vn_1 1 0 7 NJ 220 NJ 220 NJ 220 NJ 220 NJ 220 NJ 220 NJ
preplace netloc adc2_clk_1 1 0 8 NJ 1240 NJ 1240 NJ 1240 NJ 1240 NJ 1240 NJ 1240 NJ 1240 NJ
preplace netloc axi_hpm0_lpd_M00_AXI 1 6 2 2400J 410 2820
preplace netloc axi_hpm0_lpd_M01_AXI 1 6 2 N 420 2980J
preplace netloc axi_hpm0_lpd_M02_AXI 1 6 2 N 440 2950J
preplace netloc axi_hpm0_lpd_M03_AXI 1 6 2 NJ 460 2970
preplace netloc axi_hpm0_lpd_M04_AXI 1 6 1 2460 200n
preplace netloc axi_hpm0_lpd_M05_AXI 1 6 2 2470J 430 2810
preplace netloc axi_hpm0_lpd_M06_AXI 1 6 2 2400 530 NJ
preplace netloc axi_interconnect_0_M00_AXI1 1 4 4 1380J 680 2040J 700 NJ 700 2950
preplace netloc btns_gpio_GPIO 1 8 2 NJ 1030 NJ
preplace netloc dac2_clk_0_1 1 0 8 NJ 1260 NJ 1260 NJ 1260 NJ 1260 NJ 1260 NJ 1260 NJ 1260 NJ
preplace netloc ddr4_0_C0_DDR4 1 8 2 NJ 870 NJ
preplace netloc default_sysclk_c0_300mhz_1 1 0 8 NJ 1010 NJ 1010 NJ 1010 NJ 1010 NJ 1010 NJ 1010 NJ 1010 2980J
preplace netloc leds_b_GPIO 1 8 2 NJ 550 NJ
preplace netloc leds_g_GPIO 1 8 2 NJ 410 NJ
preplace netloc leds_gpio_GPIO 1 8 2 NJ 70 NJ
preplace netloc radio_M03_AXI 1 8 1 3410 1240n
preplace netloc radio_M_AXI 1 3 6 1010 1140 NJ 1140 NJ 1140 NJ 1140 NJ 1140 3400
preplace netloc radio_vout00_0 1 8 2 NJ 1360 NJ
preplace netloc radio_vout10_0 1 8 2 NJ 1380 NJ
preplace netloc radio_vout20_0 1 8 2 NJ 1400 NJ
preplace netloc radio_vout30_0 1 8 2 NJ 1420 NJ
preplace netloc sws_gpio_GPIO 1 8 2 NJ 700 NJ
preplace netloc sysref_in_1 1 0 8 NJ 1280 NJ 1280 NJ 1280 NJ 1280 NJ 1280 NJ 1280 NJ 1280 NJ
preplace netloc vin00_0_1 1 0 8 NJ 1300 NJ 1300 NJ 1300 NJ 1300 NJ 1300 NJ 1300 NJ 1300 NJ
preplace netloc vin01_0_1 1 0 8 NJ 1320 NJ 1320 NJ 1320 NJ 1320 NJ 1320 NJ 1320 NJ 1320 NJ
preplace netloc vin10_0_1 1 0 8 NJ 1340 NJ 1340 NJ 1340 NJ 1340 NJ 1340 NJ 1340 NJ 1340 NJ
preplace netloc vin11_0_1 1 0 8 NJ 1360 NJ 1360 NJ 1360 NJ 1360 NJ 1360 NJ 1360 NJ 1360 NJ
preplace netloc vin20_0_1 1 0 8 NJ 1380 NJ 1380 NJ 1380 NJ 1380 NJ 1380 NJ 1380 NJ 1380 NJ
preplace netloc vin21_0_1 1 0 8 NJ 1400 NJ 1400 NJ 1400 NJ 1400 NJ 1400 NJ 1400 NJ 1400 NJ
preplace netloc vin30_0_1 1 0 8 NJ 1420 NJ 1420 NJ 1420 NJ 1420 NJ 1420 NJ 1420 NJ 1420 NJ
preplace netloc vin31_0_1 1 0 8 NJ 1440 NJ 1440 NJ 1440 NJ 1440 NJ 1440 NJ 1440 NJ 1440 NJ
preplace netloc zynq_ultra_ps_e_0_M_AXI_HPM0_FPD 1 3 3 1030 960 NJ 960 2020
levelinfo -pg 1 -10 200 490 780 1190 1700 2250 2630 3190 3583 3710
pagesize -pg 1 -db -bbox -sgen -250 -10 5590 2560
"
}

  # Restore current instance
  current_bd_instance $oldCurInst

  # Create PFM attributes
  set_property PFM_NAME {xilinx.com:xd:${overlay_name}:1.0} [get_files [current_bd_design].bd]
  set_property PFM.IRQ {In1 {  } In2 {  } In3 {  } } [get_bd_cells /xlconcat_0]
  set_property PFM.CLOCK {  pl_clk0 {id "0" is_default "true"  proc_sys_reset "proc_sys_reset_0" status "fixed"}  } [get_bd_cells /zynq_ultra_ps_e_0]


  validate_bd_design
  save_bd_design
}
# End of create_root_design()


##################################################################
# MAIN FLOW
##################################################################

create_root_design ""


common::send_gid_msg -ssname BD::TCL -id 2053 -severity "WARNING" "This Tcl script was generated from a block design that has not been validated. It is possible that design <$design_name> may result in errors during validation."

