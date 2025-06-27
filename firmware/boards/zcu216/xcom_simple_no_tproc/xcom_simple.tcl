
################################################################
# This is a generated script based on design: xcom_simple
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
# source xcom_simple_script.tcl

# If there is no project opened, this script will create a
# project, but make sure you do not have an existing project
# <./myproj/project_1.xpr> in the current working folder.

set overlay_name xcom_simple
set list_projs [get_projects -quiet]
if { $list_projs eq "" } {
   create_project  ${overlay_name} ${overlay_name} -part xczu49dr-ffvf1760-2-e
   set_property BOARD_PART xilinx.com:zcu216:part0:2.0 [current_project]
}

set_property ip_repo_paths ../../../ip [current_project]
update_ip_catalog

# CHANGE DESIGN NAME HERE
variable design_name
set design_name xcom_simple

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
xilinx.com:ip:xlconcat:2.1\
xilinx.com:ip:clk_wiz:6.0\
xilinx.com:ip:proc_sys_reset:5.0\
xilinx.com:ip:zynq_ultra_ps_e:3.5\
xilinx.com:ip:util_ds_buf:2.2\
xilinx.com:ip:xlconstant:1.1\
xilinx.com:ip:system_ila:1.1\
user.org:user:xcom_cdc:1.0\
fnal:qick:xcom:1.0\
user.org:user:xcom_cmd:1.0\
user.org:user:xcom_txrx:1.0\
user.org:user:xcom_axil_slv:1.0\
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
  set XCOM_CK [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 XCOM_CK ]

  set XCOM_DT [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 XCOM_DT ]

  set XCOM_CKO [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:diff_clock_rtl:1.0 XCOM_CKO ]

  set XCOM_DTO [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:diff_clock_rtl:1.0 XCOM_DTO ]

  set XCOM_CKO1 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:diff_clock_rtl:1.0 XCOM_CKO1 ]

  set XCOM_DTO1 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:diff_clock_rtl:1.0 XCOM_DTO1 ]


  # Create ports
  set PMOD0_0 [ create_bd_port -dir O PMOD0_0 ]
  set PMOD0_1 [ create_bd_port -dir O PMOD0_1 ]
  set xcom_id_o_0 [ create_bd_port -dir O -from 3 -to 0 xcom_id_o_0 ]

  # Create instance: cat_dt, and set properties
  set cat_dt [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 cat_dt ]
  set_property -dict [list \
    CONFIG.IN0_WIDTH {1} \
    CONFIG.NUM_PORTS {2} \
  ] $cat_dt


  # Create instance: clk_c_clk, and set properties
  set clk_c_clk [ create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_c_clk ]
  set_property -dict [list \
    CONFIG.CLKIN1_JITTER_PS {100.0} \
    CONFIG.CLKOUT1_JITTER {102.086} \
    CONFIG.CLKOUT1_PHASE_ERROR {87.180} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {200} \
    CONFIG.MMCM_CLKFBOUT_MULT_F {12.000} \
    CONFIG.MMCM_CLKIN1_PERIOD {10.000} \
    CONFIG.MMCM_CLKIN2_PERIOD {10.000} \
    CONFIG.MMCM_CLKOUT0_DIVIDE_F {6.000} \
    CONFIG.MMCM_DIVCLK_DIVIDE {1} \
    CONFIG.RESET_PORT {resetn} \
    CONFIG.RESET_TYPE {ACTIVE_LOW} \
  ] $clk_c_clk


  # Create instance: clk_t_clk, and set properties
  set clk_t_clk [ create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_t_clk ]
  set_property -dict [list \
    CONFIG.CLKIN1_JITTER_PS {100.0} \
    CONFIG.CLKOUT1_JITTER {98.427} \
    CONFIG.CLKOUT1_PHASE_ERROR {87.466} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {250} \
    CONFIG.MMCM_CLKFBOUT_MULT_F {11.875} \
    CONFIG.MMCM_CLKIN1_PERIOD {10.000} \
    CONFIG.MMCM_CLKIN2_PERIOD {10.000} \
    CONFIG.MMCM_CLKOUT0_DIVIDE_F {4.750} \
    CONFIG.MMCM_DIVCLK_DIVIDE {1} \
    CONFIG.RESET_PORT {resetn} \
    CONFIG.RESET_TYPE {ACTIVE_LOW} \
  ] $clk_t_clk


  # Create instance: ps8_0_axi_periph, and set properties
  set ps8_0_axi_periph [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 ps8_0_axi_periph ]
  set_property CONFIG.NUM_MI {3} $ps8_0_axi_periph


  # Create instance: rst_100, and set properties
  set rst_100 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_100 ]

  # Create instance: rst_adc2_x2, and set properties
  set rst_adc2_x2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_adc2_x2 ]

  # Create instance: rst_tproc, and set properties
  set rst_tproc [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_tproc ]

  # Create instance: cat_ck, and set properties
  set cat_ck [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 cat_ck ]
  set_property -dict [list \
    CONFIG.IN0_WIDTH {1} \
    CONFIG.NUM_PORTS {2} \
  ] $cat_ck


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
    CONFIG.PSU_BANK_0_IO_STANDARD {LVCMOS33} \
    CONFIG.PSU_BANK_1_IO_STANDARD {LVCMOS18} \
    CONFIG.PSU_BANK_2_IO_STANDARD {LVCMOS18} \
    CONFIG.PSU_BANK_3_IO_STANDARD {LVCMOS18} \
    CONFIG.PSU_DDR_RAM_HIGHADDR {0xFFFFFFFF} \
    CONFIG.PSU_DDR_RAM_HIGHADDR_OFFSET {0x800000000} \
    CONFIG.PSU_DDR_RAM_LOWADDR_OFFSET {0x80000000} \
    CONFIG.PSU_IMPORT_BOARD_PRESET {} \
    CONFIG.PSU_MIO_0_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_0_INPUT_TYPE {cmos} \
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
    CONFIG.PSU_MIO_12_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_12_POLARITY {Default} \
    CONFIG.PSU_MIO_12_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_12_SLEW {fast} \
    CONFIG.PSU_MIO_13_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_13_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_13_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_13_SLEW {fast} \
    CONFIG.PSU_MIO_14_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_14_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_14_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_14_SLEW {fast} \
    CONFIG.PSU_MIO_15_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_15_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_15_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_15_SLEW {fast} \
    CONFIG.PSU_MIO_16_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_16_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_16_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_16_SLEW {fast} \
    CONFIG.PSU_MIO_17_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_17_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_17_POLARITY {Default} \
    CONFIG.PSU_MIO_17_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_17_SLEW {fast} \
    CONFIG.PSU_MIO_18_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_18_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_18_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_18_SLEW {fast} \
    CONFIG.PSU_MIO_19_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_19_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_19_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_19_SLEW {fast} \
    CONFIG.PSU_MIO_1_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_1_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_1_SLEW {fast} \
    CONFIG.PSU_MIO_20_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_20_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_20_POLARITY {Default} \
    CONFIG.PSU_MIO_20_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_20_SLEW {fast} \
    CONFIG.PSU_MIO_21_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_21_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_21_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_21_SLEW {fast} \
    CONFIG.PSU_MIO_22_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_22_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_22_SLEW {fast} \
    CONFIG.PSU_MIO_23_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_23_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_23_POLARITY {Default} \
    CONFIG.PSU_MIO_23_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_23_SLEW {fast} \
    CONFIG.PSU_MIO_24_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_24_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_25_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_25_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_26_DIRECTION {inout} \
    CONFIG.PSU_MIO_26_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_26_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_26_POLARITY {Default} \
    CONFIG.PSU_MIO_26_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_26_SLEW {fast} \
    CONFIG.PSU_MIO_27_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_27_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_27_SLEW {fast} \
    CONFIG.PSU_MIO_28_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_28_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_29_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_29_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_29_SLEW {fast} \
    CONFIG.PSU_MIO_2_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_2_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_2_SLEW {fast} \
    CONFIG.PSU_MIO_30_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_30_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_31_DIRECTION {inout} \
    CONFIG.PSU_MIO_31_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_31_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_31_POLARITY {Default} \
    CONFIG.PSU_MIO_31_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_31_SLEW {fast} \
    CONFIG.PSU_MIO_32_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_32_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_32_SLEW {fast} \
    CONFIG.PSU_MIO_33_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_33_PULLUPDOWN {pullup} \
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
    CONFIG.PSU_MIO_36_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_36_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_36_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_36_SLEW {fast} \
    CONFIG.PSU_MIO_37_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_37_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_37_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_37_SLEW {fast} \
    CONFIG.PSU_MIO_38_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_38_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_38_SLEW {fast} \
    CONFIG.PSU_MIO_39_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_39_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_39_SLEW {fast} \
    CONFIG.PSU_MIO_3_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_3_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_3_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_3_SLEW {fast} \
    CONFIG.PSU_MIO_40_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_40_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_40_SLEW {fast} \
    CONFIG.PSU_MIO_41_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_41_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_41_SLEW {fast} \
    CONFIG.PSU_MIO_42_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_42_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_42_SLEW {fast} \
    CONFIG.PSU_MIO_43_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_43_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_43_SLEW {fast} \
    CONFIG.PSU_MIO_44_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_44_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_45_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_45_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_46_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_46_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_47_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_47_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_48_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_48_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_49_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_49_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_4_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_4_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_4_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_4_SLEW {fast} \
    CONFIG.PSU_MIO_50_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_50_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_50_SLEW {fast} \
    CONFIG.PSU_MIO_51_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_51_INPUT_TYPE {cmos} \
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
    CONFIG.PSU_MIO_5_INPUT_TYPE {cmos} \
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
    CONFIG.PSU_MIO_64_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_64_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_65_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_65_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_66_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_66_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_66_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_66_SLEW {fast} \
    CONFIG.PSU_MIO_67_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_67_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_68_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_68_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_68_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_68_SLEW {fast} \
    CONFIG.PSU_MIO_69_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_69_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_69_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_69_SLEW {fast} \
    CONFIG.PSU_MIO_6_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_6_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_6_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_6_SLEW {fast} \
    CONFIG.PSU_MIO_70_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_70_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_70_SLEW {fast} \
    CONFIG.PSU_MIO_71_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_71_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_71_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_71_SLEW {fast} \
    CONFIG.PSU_MIO_72_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_72_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_72_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_72_SLEW {fast} \
    CONFIG.PSU_MIO_73_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_73_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_73_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_73_SLEW {fast} \
    CONFIG.PSU_MIO_74_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_74_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_74_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_74_SLEW {fast} \
    CONFIG.PSU_MIO_75_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_75_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_75_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_75_SLEW {fast} \
    CONFIG.PSU_MIO_76_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_76_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_76_POLARITY {Default} \
    CONFIG.PSU_MIO_76_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_76_SLEW {fast} \
    CONFIG.PSU_MIO_77_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_77_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_77_POLARITY {Default} \
    CONFIG.PSU_MIO_77_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_77_SLEW {fast} \
    CONFIG.PSU_MIO_7_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_7_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_7_POLARITY {Default} \
    CONFIG.PSU_MIO_7_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_7_SLEW {fast} \
    CONFIG.PSU_MIO_8_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_8_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_8_POLARITY {Default} \
    CONFIG.PSU_MIO_8_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_8_SLEW {fast} \
    CONFIG.PSU_MIO_9_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_9_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_9_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_9_SLEW {fast} \
    CONFIG.PSU_MIO_TREE_PERIPHERALS {SPI 0#SPI 0#SPI 0#SPI 0#SPI 0#SPI 0#SPI 1###SPI 1#SPI 1#SPI 1##SD 0#SD 0#SD 0#SD 0##I2C 0#I2C 0##SD 0#SD 0##SD 0#SD 0##DPAUX#DPAUX#DPAUX#DPAUX##UART 1#UART 1###I2C\
1#I2C 1#Gem 1#Gem 1#Gem 1#Gem 1#Gem 1#Gem 1#Gem 1#Gem 1#Gem 1#Gem 1#Gem 1#Gem 1#MDIO 1#MDIO 1#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 1#USB 1#USB 1#USB 1#USB 1#USB 1#USB\
1#USB 1#USB 1#USB 1#USB 1#USB 1##} \
    CONFIG.PSU_MIO_TREE_SIGNALS {sclk_out#n_ss_out[2]#n_ss_out[1]#n_ss_out[0]#miso#mosi#sclk_out###n_ss_out[0]#miso#mosi##sdio0_data_out[0]#sdio0_data_out[1]#sdio0_data_out[2]#sdio0_data_out[3]##scl_out#sda_out##sdio0_cmd_out#sdio0_clk_out##sdio0_cd_n#sdio0_wp##dp_aux_data_out#dp_hot_plug_detect#dp_aux_data_oe#dp_aux_data_in##txd#rxd###scl_out#sda_out#rgmii_tx_clk#rgmii_txd[0]#rgmii_txd[1]#rgmii_txd[2]#rgmii_txd[3]#rgmii_tx_ctl#rgmii_rx_clk#rgmii_rxd[0]#rgmii_rxd[1]#rgmii_rxd[2]#rgmii_rxd[3]#rgmii_rx_ctl#gem1_mdc#gem1_mdio_out#ulpi_clk_in#ulpi_dir#ulpi_tx_data[2]#ulpi_nxt#ulpi_tx_data[0]#ulpi_tx_data[1]#ulpi_stp#ulpi_tx_data[3]#ulpi_tx_data[4]#ulpi_tx_data[5]#ulpi_tx_data[6]#ulpi_tx_data[7]#ulpi_clk_in#ulpi_dir#ulpi_tx_data[2]#ulpi_nxt#ulpi_tx_data[0]#ulpi_tx_data[1]#ulpi_stp#ulpi_tx_data[3]#ulpi_tx_data[4]#ulpi_tx_data[5]#ulpi_tx_data[6]#ulpi_tx_data[7]##}\
\
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
    CONFIG.PSU__AUX_REF_CLK__FREQMHZ {33.333} \
    CONFIG.PSU__CAN0_LOOP_CAN1__ENABLE {0} \
    CONFIG.PSU__CAN0__PERIPHERAL__ENABLE {0} \
    CONFIG.PSU__CAN1__PERIPHERAL__ENABLE {0} \
    CONFIG.PSU__CRF_APB__ACPU_CTRL__ACT_FREQMHZ {1199.999756} \
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
    CONFIG.PSU__CRF_APB__DBG_FPD_CTRL__ACT_FREQMHZ {249.999954} \
    CONFIG.PSU__CRF_APB__DBG_FPD_CTRL__FREQMHZ {250} \
    CONFIG.PSU__CRF_APB__DBG_FPD_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRF_APB__DBG_TRACE_CTRL__ACT_FREQMHZ {250} \
    CONFIG.PSU__CRF_APB__DBG_TRACE_CTRL__FREQMHZ {250} \
    CONFIG.PSU__CRF_APB__DBG_TRACE_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRF_APB__DBG_TSTMP_CTRL__ACT_FREQMHZ {249.999954} \
    CONFIG.PSU__CRF_APB__DBG_TSTMP_CTRL__FREQMHZ {250} \
    CONFIG.PSU__CRF_APB__DBG_TSTMP_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRF_APB__DDR_CTRL__ACT_FREQMHZ {599.999878} \
    CONFIG.PSU__CRF_APB__DDR_CTRL__FREQMHZ {1200} \
    CONFIG.PSU__CRF_APB__DDR_CTRL__SRCSEL {DPLL} \
    CONFIG.PSU__CRF_APB__DPDMA_REF_CTRL__ACT_FREQMHZ {599.999878} \
    CONFIG.PSU__CRF_APB__DPDMA_REF_CTRL__FREQMHZ {600} \
    CONFIG.PSU__CRF_APB__DPDMA_REF_CTRL__SRCSEL {DPLL} \
    CONFIG.PSU__CRF_APB__DPLL_CTRL__FRACFREQ {27.138} \
    CONFIG.PSU__CRF_APB__DPLL_CTRL__SRCSEL {PSS_REF_CLK} \
    CONFIG.PSU__CRF_APB__DP_AUDIO_REF_CTRL__ACT_FREQMHZ {24.999996} \
    CONFIG.PSU__CRF_APB__DP_AUDIO_REF_CTRL__FREQMHZ {25} \
    CONFIG.PSU__CRF_APB__DP_AUDIO_REF_CTRL__SRCSEL {RPLL} \
    CONFIG.PSU__CRF_APB__DP_AUDIO__FRAC_ENABLED {0} \
    CONFIG.PSU__CRF_APB__DP_STC_REF_CTRL__ACT_FREQMHZ {26.249996} \
    CONFIG.PSU__CRF_APB__DP_STC_REF_CTRL__FREQMHZ {27} \
    CONFIG.PSU__CRF_APB__DP_STC_REF_CTRL__SRCSEL {RPLL} \
    CONFIG.PSU__CRF_APB__DP_VIDEO_REF_CTRL__ACT_FREQMHZ {299.999939} \
    CONFIG.PSU__CRF_APB__DP_VIDEO_REF_CTRL__FREQMHZ {300} \
    CONFIG.PSU__CRF_APB__DP_VIDEO_REF_CTRL__SRCSEL {VPLL} \
    CONFIG.PSU__CRF_APB__DP_VIDEO__FRAC_ENABLED {0} \
    CONFIG.PSU__CRF_APB__GDMA_REF_CTRL__ACT_FREQMHZ {599.999878} \
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
    CONFIG.PSU__CRF_APB__SATA_REF_CTRL__ACT_FREQMHZ {250} \
    CONFIG.PSU__CRF_APB__TOPSW_LSBUS_CTRL__ACT_FREQMHZ {99.999985} \
    CONFIG.PSU__CRF_APB__TOPSW_LSBUS_CTRL__FREQMHZ {100} \
    CONFIG.PSU__CRF_APB__TOPSW_LSBUS_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRF_APB__TOPSW_MAIN_CTRL__ACT_FREQMHZ {399.999908} \
    CONFIG.PSU__CRF_APB__TOPSW_MAIN_CTRL__FREQMHZ {533.33} \
    CONFIG.PSU__CRF_APB__TOPSW_MAIN_CTRL__SRCSEL {DPLL} \
    CONFIG.PSU__CRF_APB__VPLL_CTRL__FRACFREQ {27.138} \
    CONFIG.PSU__CRF_APB__VPLL_CTRL__SRCSEL {PSS_REF_CLK} \
    CONFIG.PSU__CRL_APB__ADMA_REF_CTRL__ACT_FREQMHZ {524.999939} \
    CONFIG.PSU__CRL_APB__ADMA_REF_CTRL__FREQMHZ {533.333} \
    CONFIG.PSU__CRL_APB__ADMA_REF_CTRL__SRCSEL {RPLL} \
    CONFIG.PSU__CRL_APB__AFI6_REF_CTRL__ACT_FREQMHZ {500} \
    CONFIG.PSU__CRL_APB__AFI6_REF_CTRL__FREQMHZ {500} \
    CONFIG.PSU__CRL_APB__AFI6_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__AFI6__ENABLE {0} \
    CONFIG.PSU__CRL_APB__AMS_REF_CTRL__ACT_FREQMHZ {49.999992} \
    CONFIG.PSU__CRL_APB__AMS_REF_CTRL__FREQMHZ {50} \
    CONFIG.PSU__CRL_APB__AMS_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__CAN0_REF_CTRL__ACT_FREQMHZ {100} \
    CONFIG.PSU__CRL_APB__CAN0_REF_CTRL__FREQMHZ {100} \
    CONFIG.PSU__CRL_APB__CAN0_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__CAN1_REF_CTRL__ACT_FREQMHZ {100} \
    CONFIG.PSU__CRL_APB__CAN1_REF_CTRL__FREQMHZ {100} \
    CONFIG.PSU__CRL_APB__CAN1_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__CPU_R5_CTRL__ACT_FREQMHZ {499.999908} \
    CONFIG.PSU__CRL_APB__CPU_R5_CTRL__FREQMHZ {500} \
    CONFIG.PSU__CRL_APB__CPU_R5_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__CSU_PLL_CTRL__ACT_FREQMHZ {180} \
    CONFIG.PSU__CRL_APB__CSU_PLL_CTRL__DIVISOR0 {3} \
    CONFIG.PSU__CRL_APB__CSU_PLL_CTRL__SRCSEL {SysOsc} \
    CONFIG.PSU__CRL_APB__DBG_LPD_CTRL__ACT_FREQMHZ {249.999954} \
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
    CONFIG.PSU__CRL_APB__GEM0_REF_CTRL__FREQMHZ {125} \
    CONFIG.PSU__CRL_APB__GEM0_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__GEM1_REF_CTRL__ACT_FREQMHZ {124.999977} \
    CONFIG.PSU__CRL_APB__GEM1_REF_CTRL__FREQMHZ {125} \
    CONFIG.PSU__CRL_APB__GEM1_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__GEM2_REF_CTRL__ACT_FREQMHZ {125} \
    CONFIG.PSU__CRL_APB__GEM2_REF_CTRL__FREQMHZ {125} \
    CONFIG.PSU__CRL_APB__GEM2_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__GEM3_REF_CTRL__ACT_FREQMHZ {125} \
    CONFIG.PSU__CRL_APB__GEM3_REF_CTRL__FREQMHZ {125} \
    CONFIG.PSU__CRL_APB__GEM3_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__GEM_TSU_REF_CTRL__ACT_FREQMHZ {249.999954} \
    CONFIG.PSU__CRL_APB__GEM_TSU_REF_CTRL__FREQMHZ {250} \
    CONFIG.PSU__CRL_APB__GEM_TSU_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__I2C0_REF_CTRL__ACT_FREQMHZ {99.999985} \
    CONFIG.PSU__CRL_APB__I2C0_REF_CTRL__FREQMHZ {100} \
    CONFIG.PSU__CRL_APB__I2C0_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__I2C1_REF_CTRL__ACT_FREQMHZ {99.999985} \
    CONFIG.PSU__CRL_APB__I2C1_REF_CTRL__FREQMHZ {100} \
    CONFIG.PSU__CRL_APB__I2C1_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__IOPLL_CTRL__FRACFREQ {27.138} \
    CONFIG.PSU__CRL_APB__IOPLL_CTRL__SRCSEL {PSS_REF_CLK} \
    CONFIG.PSU__CRL_APB__IOU_SWITCH_CTRL__ACT_FREQMHZ {262.499969} \
    CONFIG.PSU__CRL_APB__IOU_SWITCH_CTRL__FREQMHZ {267} \
    CONFIG.PSU__CRL_APB__IOU_SWITCH_CTRL__SRCSEL {RPLL} \
    CONFIG.PSU__CRL_APB__LPD_LSBUS_CTRL__ACT_FREQMHZ {99.999985} \
    CONFIG.PSU__CRL_APB__LPD_LSBUS_CTRL__FREQMHZ {100} \
    CONFIG.PSU__CRL_APB__LPD_LSBUS_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__LPD_SWITCH_CTRL__ACT_FREQMHZ {524.999939} \
    CONFIG.PSU__CRL_APB__LPD_SWITCH_CTRL__FREQMHZ {533.333} \
    CONFIG.PSU__CRL_APB__LPD_SWITCH_CTRL__SRCSEL {RPLL} \
    CONFIG.PSU__CRL_APB__NAND_REF_CTRL__ACT_FREQMHZ {100} \
    CONFIG.PSU__CRL_APB__NAND_REF_CTRL__FREQMHZ {100} \
    CONFIG.PSU__CRL_APB__NAND_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__OCM_MAIN_CTRL__ACT_FREQMHZ {500} \
    CONFIG.PSU__CRL_APB__OCM_MAIN_CTRL__DIVISOR0 {3} \
    CONFIG.PSU__CRL_APB__OCM_MAIN_CTRL__FREQMHZ {500} \
    CONFIG.PSU__CRL_APB__OCM_MAIN_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__PCAP_CTRL__ACT_FREQMHZ {187.499969} \
    CONFIG.PSU__CRL_APB__PCAP_CTRL__FREQMHZ {200} \
    CONFIG.PSU__CRL_APB__PCAP_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__PL0_REF_CTRL__ACT_FREQMHZ {99.999985} \
    CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ {100} \
    CONFIG.PSU__CRL_APB__PL0_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__PL1_REF_CTRL__ACT_FREQMHZ {100} \
    CONFIG.PSU__CRL_APB__PL2_REF_CTRL__ACT_FREQMHZ {100} \
    CONFIG.PSU__CRL_APB__PL3_REF_CTRL__ACT_FREQMHZ {100} \
    CONFIG.PSU__CRL_APB__QSPI_REF_CTRL__ACT_FREQMHZ {300} \
    CONFIG.PSU__CRL_APB__QSPI_REF_CTRL__FREQMHZ {125} \
    CONFIG.PSU__CRL_APB__QSPI_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__RPLL_CTRL__FRACFREQ {27.138} \
    CONFIG.PSU__CRL_APB__RPLL_CTRL__SRCSEL {PSS_REF_CLK} \
    CONFIG.PSU__CRL_APB__SDIO0_REF_CTRL__ACT_FREQMHZ {187.499969} \
    CONFIG.PSU__CRL_APB__SDIO0_REF_CTRL__FREQMHZ {200} \
    CONFIG.PSU__CRL_APB__SDIO0_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__SDIO1_REF_CTRL__ACT_FREQMHZ {200} \
    CONFIG.PSU__CRL_APB__SDIO1_REF_CTRL__FREQMHZ {200} \
    CONFIG.PSU__CRL_APB__SDIO1_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__SPI0_REF_CTRL__ACT_FREQMHZ {187.499969} \
    CONFIG.PSU__CRL_APB__SPI0_REF_CTRL__FREQMHZ {200} \
    CONFIG.PSU__CRL_APB__SPI0_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__SPI1_REF_CTRL__ACT_FREQMHZ {187.499969} \
    CONFIG.PSU__CRL_APB__SPI1_REF_CTRL__FREQMHZ {200} \
    CONFIG.PSU__CRL_APB__SPI1_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__TIMESTAMP_REF_CTRL__ACT_FREQMHZ {33.333328} \
    CONFIG.PSU__CRL_APB__TIMESTAMP_REF_CTRL__FREQMHZ {100} \
    CONFIG.PSU__CRL_APB__TIMESTAMP_REF_CTRL__SRCSEL {PSS_REF_CLK} \
    CONFIG.PSU__CRL_APB__UART0_REF_CTRL__ACT_FREQMHZ {100} \
    CONFIG.PSU__CRL_APB__UART0_REF_CTRL__FREQMHZ {100} \
    CONFIG.PSU__CRL_APB__UART0_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__UART1_REF_CTRL__ACT_FREQMHZ {99.999985} \
    CONFIG.PSU__CRL_APB__UART1_REF_CTRL__FREQMHZ {100} \
    CONFIG.PSU__CRL_APB__UART1_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__USB0_BUS_REF_CTRL__ACT_FREQMHZ {249.999954} \
    CONFIG.PSU__CRL_APB__USB0_BUS_REF_CTRL__FREQMHZ {250} \
    CONFIG.PSU__CRL_APB__USB0_BUS_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__USB1_BUS_REF_CTRL__ACT_FREQMHZ {249.999954} \
    CONFIG.PSU__CRL_APB__USB1_BUS_REF_CTRL__FREQMHZ {250} \
    CONFIG.PSU__CRL_APB__USB1_BUS_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__USB3_DUAL_REF_CTRL__ACT_FREQMHZ {19.999996} \
    CONFIG.PSU__CRL_APB__USB3_DUAL_REF_CTRL__FREQMHZ {20} \
    CONFIG.PSU__CRL_APB__USB3_DUAL_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__USB3__ENABLE {1} \
    CONFIG.PSU__CSUPMU__PERIPHERAL__VALID {0} \
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
    CONFIG.PSU__DDRC__CL {16} \
    CONFIG.PSU__DDRC__CLOCK_STOP_EN {0} \
    CONFIG.PSU__DDRC__COMPONENTS {Components} \
    CONFIG.PSU__DDRC__CWL {12} \
    CONFIG.PSU__DDRC__DDR4_ADDR_MAPPING {1} \
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
    CONFIG.PSU__ENET0__PERIPHERAL__ENABLE {0} \
    CONFIG.PSU__ENET1__FIFO__ENABLE {0} \
    CONFIG.PSU__ENET1__GRP_MDIO__ENABLE {1} \
    CONFIG.PSU__ENET1__GRP_MDIO__IO {MIO 50 .. 51} \
    CONFIG.PSU__ENET1__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__ENET1__PERIPHERAL__IO {MIO 38 .. 49} \
    CONFIG.PSU__ENET1__PTP__ENABLE {0} \
    CONFIG.PSU__ENET1__TSU__ENABLE {0} \
    CONFIG.PSU__ENET2__PERIPHERAL__ENABLE {0} \
    CONFIG.PSU__ENET3__PERIPHERAL__ENABLE {0} \
    CONFIG.PSU__EN_AXI_STATUS_PORTS {0} \
    CONFIG.PSU__EN_EMIO_TRACE {0} \
    CONFIG.PSU__EP__IP {0} \
    CONFIG.PSU__EXPAND__CORESIGHT {0} \
    CONFIG.PSU__EXPAND__FPD_SLAVES {0} \
    CONFIG.PSU__EXPAND__GIC {0} \
    CONFIG.PSU__EXPAND__LOWER_LPS_SLAVES {0} \
    CONFIG.PSU__EXPAND__UPPER_LPS_SLAVES {0} \
    CONFIG.PSU__FPD_SLCR__WDT1__ACT_FREQMHZ {100} \
    CONFIG.PSU__FPD_SLCR__WDT1__FREQMHZ {100} \
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
    CONFIG.PSU__GEM1_COHERENCY {0} \
    CONFIG.PSU__GEM1_ROUTE_THROUGH_FPD {0} \
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
    CONFIG.PSU__GPIO0_MIO__PERIPHERAL__ENABLE {0} \
    CONFIG.PSU__GPIO1_MIO__PERIPHERAL__ENABLE {0} \
    CONFIG.PSU__GPIO2_MIO__PERIPHERAL__ENABLE {0} \
    CONFIG.PSU__GPIO_EMIO_WIDTH {95} \
    CONFIG.PSU__GPIO_EMIO__PERIPHERAL__ENABLE {0} \
    CONFIG.PSU__GPIO_EMIO__WIDTH {[94:0]} \
    CONFIG.PSU__GPU_PP0__POWER__ON {0} \
    CONFIG.PSU__GPU_PP1__POWER__ON {0} \
    CONFIG.PSU__GT_REF_CLK__FREQMHZ {33.333} \
    CONFIG.PSU__GT__LINK_SPEED {HBR} \
    CONFIG.PSU__GT__PRE_EMPH_LVL_4 {0} \
    CONFIG.PSU__GT__VLT_SWNG_LVL_4 {0} \
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
    CONFIG.PSU__IRQ_P2F_DDR_SS__INT {0} \
    CONFIG.PSU__IRQ_P2F_DPDMA__INT {0} \
    CONFIG.PSU__IRQ_P2F_DPORT__INT {0} \
    CONFIG.PSU__IRQ_P2F_EFUSE__INT {0} \
    CONFIG.PSU__IRQ_P2F_ENT1_WAKEUP__INT {0} \
    CONFIG.PSU__IRQ_P2F_ENT1__INT {0} \
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
    CONFIG.PSU__IRQ_P2F_OCM_ERR__INT {0} \
    CONFIG.PSU__IRQ_P2F_PCIE_DMA__INT {0} \
    CONFIG.PSU__IRQ_P2F_PCIE_LEGACY__INT {0} \
    CONFIG.PSU__IRQ_P2F_PCIE_MSC__INT {0} \
    CONFIG.PSU__IRQ_P2F_PCIE_MSI__INT {0} \
    CONFIG.PSU__IRQ_P2F_PL_IPI__INT {0} \
    CONFIG.PSU__IRQ_P2F_R5_CORE0_ECC_ERR__INT {0} \
    CONFIG.PSU__IRQ_P2F_R5_CORE1_ECC_ERR__INT {0} \
    CONFIG.PSU__IRQ_P2F_RPU_IPI__INT {0} \
    CONFIG.PSU__IRQ_P2F_RPU_PERMON__INT {0} \
    CONFIG.PSU__IRQ_P2F_RTC_ALARM__INT {0} \
    CONFIG.PSU__IRQ_P2F_RTC_SECONDS__INT {0} \
    CONFIG.PSU__IRQ_P2F_SATA__INT {0} \
    CONFIG.PSU__IRQ_P2F_SDIO0_WAKE__INT {0} \
    CONFIG.PSU__IRQ_P2F_SDIO0__INT {0} \
    CONFIG.PSU__IRQ_P2F_SPI0__INT {0} \
    CONFIG.PSU__IRQ_P2F_SPI1__INT {0} \
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
    CONFIG.PSU__PL__POWER__ON {1} \
    CONFIG.PSU__PMU__PERIPHERAL__ENABLE {0} \
    CONFIG.PSU__PRESET_APPLIED {1} \
    CONFIG.PSU__PROTECTION__DDR_SEGMENTS {NONE} \
    CONFIG.PSU__PROTECTION__ENABLE {0} \
    CONFIG.PSU__PROTECTION__FPD_SEGMENTS {SA:0xFD1A0000; SIZE:1280; UNIT:KB; RegionTZ:Secure; WrAllowed:Read/Write; subsystemId:PMU Firmware     |      SA:0xFD000000; SIZE:64; UNIT:KB; RegionTZ:Secure;\
WrAllowed:Read/Write; subsystemId:PMU Firmware     |      SA:0xFD010000; SIZE:64; UNIT:KB; RegionTZ:Secure; WrAllowed:Read/Write; subsystemId:PMU Firmware     |      SA:0xFD020000; SIZE:64; UNIT:KB; RegionTZ:Secure;\
WrAllowed:Read/Write; subsystemId:PMU Firmware     |      SA:0xFD030000; SIZE:64; UNIT:KB; RegionTZ:Secure; WrAllowed:Read/Write; subsystemId:PMU Firmware     |      SA:0xFD040000; SIZE:64; UNIT:KB; RegionTZ:Secure;\
WrAllowed:Read/Write; subsystemId:PMU Firmware     |      SA:0xFD050000; SIZE:64; UNIT:KB; RegionTZ:Secure; WrAllowed:Read/Write; subsystemId:PMU Firmware     |      SA:0xFD610000; SIZE:512; UNIT:KB; RegionTZ:Secure;\
WrAllowed:Read/Write; subsystemId:PMU Firmware     |      SA:0xFD5D0000; SIZE:64; UNIT:KB; RegionTZ:Secure; WrAllowed:Read/Write; subsystemId:PMU Firmware     |     SA:0xFD1A0000 ; SIZE:1280; UNIT:KB;\
RegionTZ:Secure ; WrAllowed:Read/Write; subsystemId:Secure Subsystem} \
    CONFIG.PSU__PROTECTION__LPD_SEGMENTS {SA:0xFF980000; SIZE:64; UNIT:KB; RegionTZ:Secure; WrAllowed:Read/Write; subsystemId:PMU Firmware| SA:0xFF5E0000; SIZE:2560; UNIT:KB; RegionTZ:Secure; WrAllowed:Read/Write;\
subsystemId:PMU Firmware| SA:0xFFCC0000; SIZE:64; UNIT:KB; RegionTZ:Secure; WrAllowed:Read/Write; subsystemId:PMU Firmware| SA:0xFF180000; SIZE:768; UNIT:KB; RegionTZ:Secure; WrAllowed:Read/Write; subsystemId:PMU\
Firmware| SA:0xFF410000; SIZE:640; UNIT:KB; RegionTZ:Secure; WrAllowed:Read/Write; subsystemId:PMU Firmware| SA:0xFFA70000; SIZE:64; UNIT:KB; RegionTZ:Secure; WrAllowed:Read/Write; subsystemId:PMU Firmware|\
SA:0xFF9A0000; SIZE:64; UNIT:KB; RegionTZ:Secure; WrAllowed:Read/Write; subsystemId:PMU Firmware|SA:0xFF5E0000 ; SIZE:2560; UNIT:KB; RegionTZ:Secure ; WrAllowed:Read/Write; subsystemId:Secure Subsystem|SA:0xFFCC0000\
; SIZE:64; UNIT:KB; RegionTZ:Secure ; WrAllowed:Read/Write; subsystemId:Secure Subsystem|SA:0xFF180000 ; SIZE:768; UNIT:KB; RegionTZ:Secure ; WrAllowed:Read/Write; subsystemId:Secure Subsystem|SA:0xFF9A0000\
; SIZE:64; UNIT:KB; RegionTZ:Secure ; WrAllowed:Read/Write; subsystemId:Secure Subsystem} \
    CONFIG.PSU__PROTECTION__MASTERS {USB1:NonSecure;1|USB0:NonSecure;1|S_AXI_LPD:NA;0|S_AXI_HPC1_FPD:NA;0|S_AXI_HPC0_FPD:NA;0|S_AXI_HP3_FPD:NA;0|S_AXI_HP2_FPD:NA;0|S_AXI_HP1_FPD:NA;0|S_AXI_HP0_FPD:NA;0|S_AXI_ACP:NA;0|S_AXI_ACE:NA;0|SD1:NonSecure;0|SD0:NonSecure;1|SATA1:NonSecure;0|SATA0:NonSecure;0|RPU1:Secure;1|RPU0:Secure;1|QSPI:NonSecure;0|PMU:NA;1|PCIe:NonSecure;0|NAND:NonSecure;0|LDMA:NonSecure;1|GPU:NonSecure;1|GEM3:NonSecure;0|GEM2:NonSecure;0|GEM1:NonSecure;1|GEM0:NonSecure;0|FDMA:NonSecure;1|DP:NonSecure;1|DAP:NA;1|Coresight:NA;1|CSU:NA;1|APU:NA;1}\
\
    CONFIG.PSU__PROTECTION__MASTERS_TZ {GEM0:NonSecure|SD1:NonSecure|GEM2:NonSecure|GEM1:NonSecure|GEM3:NonSecure|PCIe:NonSecure|DP:NonSecure|NAND:NonSecure|GPU:NonSecure|USB1:NonSecure|USB0:NonSecure|LDMA:NonSecure|FDMA:NonSecure|QSPI:NonSecure|SD0:NonSecure}\
\
    CONFIG.PSU__PROTECTION__OCM_SEGMENTS {NONE} \
    CONFIG.PSU__PROTECTION__PRESUBSYSTEMS {NONE} \
    CONFIG.PSU__PROTECTION__SLAVES {LPD;USB3_1_XHCI;FE300000;FE3FFFFF;1|LPD;USB3_1;FF9E0000;FF9EFFFF;1|LPD;USB3_0_XHCI;FE200000;FE2FFFFF;1|LPD;USB3_0;FF9D0000;FF9DFFFF;1|LPD;UART1;FF010000;FF01FFFF;1|LPD;UART0;FF000000;FF00FFFF;0|LPD;TTC3;FF140000;FF14FFFF;0|LPD;TTC2;FF130000;FF13FFFF;0|LPD;TTC1;FF120000;FF12FFFF;0|LPD;TTC0;FF110000;FF11FFFF;0|FPD;SWDT1;FD4D0000;FD4DFFFF;0|LPD;SWDT0;FF150000;FF15FFFF;0|LPD;SPI1;FF050000;FF05FFFF;1|LPD;SPI0;FF040000;FF04FFFF;1|FPD;SMMU_REG;FD5F0000;FD5FFFFF;1|FPD;SMMU;FD800000;FDFFFFFF;1|FPD;SIOU;FD3D0000;FD3DFFFF;1|FPD;SERDES;FD400000;FD47FFFF;1|LPD;SD1;FF170000;FF17FFFF;0|LPD;SD0;FF160000;FF16FFFF;1|FPD;SATA;FD0C0000;FD0CFFFF;0|LPD;RTC;FFA60000;FFA6FFFF;1|LPD;RSA_CORE;FFCE0000;FFCEFFFF;1|LPD;RPU;FF9A0000;FF9AFFFF;1|LPD;R5_TCM_RAM_GLOBAL;FFE00000;FFE3FFFF;1|LPD;R5_1_Instruction_Cache;FFEC0000;FFECFFFF;1|LPD;R5_1_Data_Cache;FFED0000;FFEDFFFF;1|LPD;R5_1_BTCM_GLOBAL;FFEB0000;FFEBFFFF;1|LPD;R5_1_ATCM_GLOBAL;FFE90000;FFE9FFFF;1|LPD;R5_0_Instruction_Cache;FFE40000;FFE4FFFF;1|LPD;R5_0_Data_Cache;FFE50000;FFE5FFFF;1|LPD;R5_0_BTCM_GLOBAL;FFE20000;FFE2FFFF;1|LPD;R5_0_ATCM_GLOBAL;FFE00000;FFE0FFFF;1|LPD;QSPI_Linear_Address;C0000000;DFFFFFFF;1|LPD;QSPI;FF0F0000;FF0FFFFF;0|LPD;PMU_RAM;FFDC0000;FFDDFFFF;1|LPD;PMU_GLOBAL;FFD80000;FFDBFFFF;1|FPD;PCIE_MAIN;FD0E0000;FD0EFFFF;0|FPD;PCIE_LOW;E0000000;EFFFFFFF;0|FPD;PCIE_HIGH2;8000000000;BFFFFFFFFF;0|FPD;PCIE_HIGH1;600000000;7FFFFFFFF;0|FPD;PCIE_DMA;FD0F0000;FD0FFFFF;0|FPD;PCIE_ATTRIB;FD480000;FD48FFFF;0|LPD;OCM_XMPU_CFG;FFA70000;FFA7FFFF;1|LPD;OCM_SLCR;FF960000;FF96FFFF;1|OCM;OCM;FFFC0000;FFFFFFFF;1|LPD;NAND;FF100000;FF10FFFF;0|LPD;MBISTJTAG;FFCF0000;FFCFFFFF;1|LPD;LPD_XPPU_SINK;FF9C0000;FF9CFFFF;1|LPD;LPD_XPPU;FF980000;FF98FFFF;1|LPD;LPD_SLCR_SECURE;FF4B0000;FF4DFFFF;1|LPD;LPD_SLCR;FF410000;FF4AFFFF;1|LPD;LPD_GPV;FE100000;FE1FFFFF;1|LPD;LPD_DMA_7;FFAF0000;FFAFFFFF;1|LPD;LPD_DMA_6;FFAE0000;FFAEFFFF;1|LPD;LPD_DMA_5;FFAD0000;FFADFFFF;1|LPD;LPD_DMA_4;FFAC0000;FFACFFFF;1|LPD;LPD_DMA_3;FFAB0000;FFABFFFF;1|LPD;LPD_DMA_2;FFAA0000;FFAAFFFF;1|LPD;LPD_DMA_1;FFA90000;FFA9FFFF;1|LPD;LPD_DMA_0;FFA80000;FFA8FFFF;1|LPD;IPI_CTRL;FF380000;FF3FFFFF;1|LPD;IOU_SLCR;FF180000;FF23FFFF;1|LPD;IOU_SECURE_SLCR;FF240000;FF24FFFF;1|LPD;IOU_SCNTRS;FF260000;FF26FFFF;1|LPD;IOU_SCNTR;FF250000;FF25FFFF;1|LPD;IOU_GPV;FE000000;FE0FFFFF;1|LPD;I2C1;FF030000;FF03FFFF;1|LPD;I2C0;FF020000;FF02FFFF;1|FPD;GPU;FD4B0000;FD4BFFFF;0|LPD;GPIO;FF0A0000;FF0AFFFF;1|LPD;GEM3;FF0E0000;FF0EFFFF;0|LPD;GEM2;FF0D0000;FF0DFFFF;0|LPD;GEM1;FF0C0000;FF0CFFFF;1|LPD;GEM0;FF0B0000;FF0BFFFF;0|FPD;FPD_XMPU_SINK;FD4F0000;FD4FFFFF;1|FPD;FPD_XMPU_CFG;FD5D0000;FD5DFFFF;1|FPD;FPD_SLCR_SECURE;FD690000;FD6CFFFF;1|FPD;FPD_SLCR;FD610000;FD68FFFF;1|FPD;FPD_DMA_CH7;FD570000;FD57FFFF;1|FPD;FPD_DMA_CH6;FD560000;FD56FFFF;1|FPD;FPD_DMA_CH5;FD550000;FD55FFFF;1|FPD;FPD_DMA_CH4;FD540000;FD54FFFF;1|FPD;FPD_DMA_CH3;FD530000;FD53FFFF;1|FPD;FPD_DMA_CH2;FD520000;FD52FFFF;1|FPD;FPD_DMA_CH1;FD510000;FD51FFFF;1|FPD;FPD_DMA_CH0;FD500000;FD50FFFF;1|LPD;EFUSE;FFCC0000;FFCCFFFF;1|FPD;Display\
Port;FD4A0000;FD4AFFFF;1|FPD;DPDMA;FD4C0000;FD4CFFFF;1|FPD;DDR_XMPU5_CFG;FD050000;FD05FFFF;1|FPD;DDR_XMPU4_CFG;FD040000;FD04FFFF;1|FPD;DDR_XMPU3_CFG;FD030000;FD03FFFF;1|FPD;DDR_XMPU2_CFG;FD020000;FD02FFFF;1|FPD;DDR_XMPU1_CFG;FD010000;FD01FFFF;1|FPD;DDR_XMPU0_CFG;FD000000;FD00FFFF;1|FPD;DDR_QOS_CTRL;FD090000;FD09FFFF;1|FPD;DDR_PHY;FD080000;FD08FFFF;1|DDR;DDR_LOW;0;7FFFFFFF;1|DDR;DDR_HIGH;800000000;87FFFFFFF;1|FPD;DDDR_CTRL;FD070000;FD070FFF;1|LPD;Coresight;FE800000;FEFFFFFF;1|LPD;CSU_DMA;FFC80000;FFC9FFFF;1|LPD;CSU;FFCA0000;FFCAFFFF;1|LPD;CRL_APB;FF5E0000;FF85FFFF;1|FPD;CRF_APB;FD1A0000;FD2DFFFF;1|FPD;CCI_REG;FD5E0000;FD5EFFFF;1|LPD;CAN1;FF070000;FF07FFFF;0|LPD;CAN0;FF060000;FF06FFFF;0|FPD;APU;FD5C0000;FD5CFFFF;1|LPD;APM_INTC_IOU;FFA20000;FFA2FFFF;1|LPD;APM_FPD_LPD;FFA30000;FFA3FFFF;1|FPD;APM_5;FD490000;FD49FFFF;1|FPD;APM_0;FD0B0000;FD0BFFFF;1|LPD;APM2;FFA10000;FFA1FFFF;1|LPD;APM1;FFA00000;FFA0FFFF;1|LPD;AMS;FFA50000;FFA5FFFF;1|FPD;AFI_5;FD3B0000;FD3BFFFF;1|FPD;AFI_4;FD3A0000;FD3AFFFF;1|FPD;AFI_3;FD390000;FD39FFFF;1|FPD;AFI_2;FD380000;FD38FFFF;1|FPD;AFI_1;FD370000;FD37FFFF;1|FPD;AFI_0;FD360000;FD36FFFF;1|LPD;AFIFM6;FF9B0000;FF9BFFFF;1|FPD;ACPU_GIC;F9010000;F907FFFF;1}\
\
    CONFIG.PSU__PROTECTION__SUBSYSTEMS {PMU Firmware:PMU|Secure Subsystem:} \
    CONFIG.PSU__PSS_ALT_REF_CLK__ENABLE {0} \
    CONFIG.PSU__PSS_ALT_REF_CLK__FREQMHZ {33.333} \
    CONFIG.PSU__PSS_REF_CLK__FREQMHZ {33.33333} \
    CONFIG.PSU__QSPI__PERIPHERAL__ENABLE {0} \
    CONFIG.PSU__REPORT__DBGLOG {0} \
    CONFIG.PSU__RPU_COHERENCY {0} \
    CONFIG.PSU__RPU__POWER__ON {1} \
    CONFIG.PSU__SATA__PERIPHERAL__ENABLE {0} \
    CONFIG.PSU__SD0_COHERENCY {0} \
    CONFIG.PSU__SD0_ROUTE_THROUGH_FPD {0} \
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
    CONFIG.PSU__SD0__SLOT_TYPE {SD 2.0} \
    CONFIG.PSU__SD1__CLK_100_SDR_OTAP_DLY {0x3} \
    CONFIG.PSU__SD1__CLK_200_SDR_OTAP_DLY {0x3} \
    CONFIG.PSU__SD1__CLK_50_DDR_ITAP_DLY {0x3D} \
    CONFIG.PSU__SD1__CLK_50_DDR_OTAP_DLY {0x4} \
    CONFIG.PSU__SD1__CLK_50_SDR_ITAP_DLY {0x15} \
    CONFIG.PSU__SD1__CLK_50_SDR_OTAP_DLY {0x5} \
    CONFIG.PSU__SD1__PERIPHERAL__ENABLE {0} \
    CONFIG.PSU__SD1__RESET__ENABLE {0} \
    CONFIG.PSU__SPI0_LOOP_SPI1__ENABLE {0} \
    CONFIG.PSU__SPI0__GRP_SS0__IO {MIO 3} \
    CONFIG.PSU__SPI0__GRP_SS1__ENABLE {1} \
    CONFIG.PSU__SPI0__GRP_SS1__IO {MIO 2} \
    CONFIG.PSU__SPI0__GRP_SS2__ENABLE {1} \
    CONFIG.PSU__SPI0__GRP_SS2__IO {MIO 1} \
    CONFIG.PSU__SPI0__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__SPI0__PERIPHERAL__IO {MIO 0 .. 5} \
    CONFIG.PSU__SPI1__GRP_SS0__IO {MIO 9} \
    CONFIG.PSU__SPI1__GRP_SS1__ENABLE {0} \
    CONFIG.PSU__SPI1__GRP_SS2__ENABLE {0} \
    CONFIG.PSU__SPI1__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__SPI1__PERIPHERAL__IO {MIO 6 .. 11} \
    CONFIG.PSU__SWDT0__PERIPHERAL__ENABLE {0} \
    CONFIG.PSU__SWDT0__PERIPHERAL__IO {NA} \
    CONFIG.PSU__SWDT1__PERIPHERAL__ENABLE {0} \
    CONFIG.PSU__SWDT1__PERIPHERAL__IO {NA} \
    CONFIG.PSU__TCM0A__POWER__ON {1} \
    CONFIG.PSU__TCM0B__POWER__ON {1} \
    CONFIG.PSU__TCM1A__POWER__ON {1} \
    CONFIG.PSU__TCM1B__POWER__ON {1} \
    CONFIG.PSU__TESTSCAN__PERIPHERAL__ENABLE {0} \
    CONFIG.PSU__TRACE__INTERNAL_WIDTH {32} \
    CONFIG.PSU__TRACE__PERIPHERAL__ENABLE {0} \
    CONFIG.PSU__TRISTATE__INVERTED {1} \
    CONFIG.PSU__TSU__BUFG_PORT_PAIR {0} \
    CONFIG.PSU__TTC0__PERIPHERAL__ENABLE {0} \
    CONFIG.PSU__TTC0__PERIPHERAL__IO {NA} \
    CONFIG.PSU__TTC1__PERIPHERAL__ENABLE {0} \
    CONFIG.PSU__TTC1__PERIPHERAL__IO {NA} \
    CONFIG.PSU__TTC2__PERIPHERAL__ENABLE {0} \
    CONFIG.PSU__TTC2__PERIPHERAL__IO {NA} \
    CONFIG.PSU__TTC3__PERIPHERAL__ENABLE {0} \
    CONFIG.PSU__TTC3__PERIPHERAL__IO {NA} \
    CONFIG.PSU__UART0_LOOP_UART1__ENABLE {0} \
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
    CONFIG.PSU__USB1_COHERENCY {0} \
    CONFIG.PSU__USB1__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__USB1__PERIPHERAL__IO {MIO 64 .. 75} \
    CONFIG.PSU__USB1__REF_CLK_FREQ {100} \
    CONFIG.PSU__USB1__REF_CLK_SEL {Ref Clk1} \
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
    CONFIG.PSU__USE__S_AXI_GP0 {0} \
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


  # Create instance: xcom_cko_buf, and set properties
  set xcom_cko_buf [ create_bd_cell -type ip -vlnv xilinx.com:ip:util_ds_buf:2.2 xcom_cko_buf ]
  set_property -dict [list \
    CONFIG.C_BUF_TYPE {OBUFDS} \
    CONFIG.C_SIZE {1} \
  ] $xcom_cko_buf


  # Create instance: xcom_dto_buf, and set properties
  set xcom_dto_buf [ create_bd_cell -type ip -vlnv xilinx.com:ip:util_ds_buf:2.2 xcom_dto_buf ]
  set_property -dict [list \
    CONFIG.C_BUF_TYPE {OBUFDS} \
    CONFIG.C_SIZE {1} \
  ] $xcom_dto_buf


  # Create instance: xcom_cki_buf, and set properties
  set xcom_cki_buf [ create_bd_cell -type ip -vlnv xilinx.com:ip:util_ds_buf:2.2 xcom_cki_buf ]
  set_property -dict [list \
    CONFIG.C_BUF_TYPE {IBUFDS} \
    CONFIG.C_SIZE {1} \
  ] $xcom_cki_buf


  # Create instance: xcom_dti_buf, and set properties
  set xcom_dti_buf [ create_bd_cell -type ip -vlnv xilinx.com:ip:util_ds_buf:2.2 xcom_dti_buf ]
  set_property -dict [list \
    CONFIG.C_BUF_TYPE {IBUFDS} \
    CONFIG.C_SIZE {1} \
  ] $xcom_dti_buf


  # Create instance: xcom_cko_buf1, and set properties
  set xcom_cko_buf1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:util_ds_buf:2.2 xcom_cko_buf1 ]
  set_property -dict [list \
    CONFIG.C_BUF_TYPE {OBUFDS} \
    CONFIG.C_SIZE {1} \
  ] $xcom_cko_buf1


  # Create instance: xcom_dto_buf1, and set properties
  set xcom_dto_buf1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:util_ds_buf:2.2 xcom_dto_buf1 ]
  set_property -dict [list \
    CONFIG.C_BUF_TYPE {OBUFDS} \
    CONFIG.C_SIZE {1} \
  ] $xcom_dto_buf1


  # Create instance: xlconcat_0, and set properties
  set xlconcat_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 xlconcat_0 ]

  # Create instance: xlconcat_1, and set properties
  set xlconcat_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 xlconcat_1 ]

  # Create instance: xlconstant_0, and set properties
  set xlconstant_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_0 ]
  set_property -dict [list \
    CONFIG.CONST_VAL {0} \
    CONFIG.CONST_WIDTH {32} \
  ] $xlconstant_0


  # Create instance: system_ila_0, and set properties
  set system_ila_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:system_ila:1.1 system_ila_0 ]
  set_property -dict [list \
    CONFIG.C_ADV_TRIGGER {true} \
    CONFIG.C_EN_STRG_QUAL {1} \
    CONFIG.C_MON_TYPE {NATIVE} \
    CONFIG.C_NUM_OF_PROBES {17} \
  ] $system_ila_0


  # Create instance: xlconstant_1, and set properties
  set xlconstant_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_1 ]
  set_property CONFIG.CONST_VAL {0} $xlconstant_1


  # Create instance: system_ila_1, and set properties
  set system_ila_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:system_ila:1.1 system_ila_1 ]
  set_property -dict [list \
    CONFIG.C_ADV_TRIGGER {true} \
    CONFIG.C_EN_STRG_QUAL {1} \
    CONFIG.C_MON_TYPE {NATIVE} \
    CONFIG.C_NUM_OF_PROBES {24} \
  ] $system_ila_1


  # Create instance: xcom_cdc_0, and set properties
  set xcom_cdc_0 [ create_bd_cell -type ip -vlnv user.org:user:xcom_cdc:1.0 xcom_cdc_0 ]

  # Create instance: xcom_1, and set properties
  set xcom_1 [ create_bd_cell -type ip -vlnv fnal:qick:xcom:1.0 xcom_1 ]
  set_property -dict [list \
    CONFIG.DEBUG {0} \
    CONFIG.NCH {2} \
    CONFIG.SYNC {0} \
  ] $xcom_1


  # Create instance: xcom_cmd_0, and set properties
  set xcom_cmd_0 [ create_bd_cell -type ip -vlnv user.org:user:xcom_cmd:1.0 xcom_cmd_0 ]

  # Create instance: xcom_txrx_0, and set properties
  set xcom_txrx_0 [ create_bd_cell -type ip -vlnv user.org:user:xcom_txrx:1.0 xcom_txrx_0 ]
  set_property CONFIG.NCH {2} $xcom_txrx_0


  # Create instance: xcom_axil_slv_0, and set properties
  set xcom_axil_slv_0 [ create_bd_cell -type ip -vlnv user.org:user:xcom_axil_slv:1.0 xcom_axil_slv_0 ]

  # Create instance: system_ila_2, and set properties
  set system_ila_2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:system_ila:1.1 system_ila_2 ]
  set_property -dict [list \
    CONFIG.C_MON_TYPE {NATIVE} \
    CONFIG.C_NUM_OF_PROBES {10} \
  ] $system_ila_2


  # Create instance: xlconstant_2, and set properties
  set xlconstant_2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_2 ]
  set_property CONFIG.CONST_VAL {0} $xlconstant_2


  # Create instance: xlconstant_3, and set properties
  set xlconstant_3 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_3 ]
  set_property CONFIG.CONST_VAL {0} $xlconstant_3


  # Create interface connections
  connect_bd_intf_net -intf_net CLK_IN_D_0_1 [get_bd_intf_ports XCOM_CK] [get_bd_intf_pins xcom_cki_buf/CLK_IN_D]
  connect_bd_intf_net -intf_net CLK_IN_D_1_1 [get_bd_intf_ports XCOM_DT] [get_bd_intf_pins xcom_dti_buf/CLK_IN_D]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M00_AXI [get_bd_intf_pins ps8_0_axi_periph/M00_AXI] [get_bd_intf_pins xcom_1/s_axi]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M02_AXI [get_bd_intf_pins ps8_0_axi_periph/M02_AXI] [get_bd_intf_pins xcom_axil_slv_0/s_axi]
  connect_bd_intf_net -intf_net xcom_cko_buf1_CLK_OUT_D3 [get_bd_intf_ports XCOM_CKO1] [get_bd_intf_pins xcom_cko_buf1/CLK_OUT_D3]
  connect_bd_intf_net -intf_net xcom_cko_buf_CLK_OUT_D3 [get_bd_intf_ports XCOM_CKO] [get_bd_intf_pins xcom_cko_buf/CLK_OUT_D3]
  connect_bd_intf_net -intf_net xcom_dto_buf1_CLK_OUT_D3 [get_bd_intf_ports XCOM_DTO1] [get_bd_intf_pins xcom_dto_buf1/CLK_OUT_D3]
  connect_bd_intf_net -intf_net xcom_dto_buf_CLK_OUT_D3 [get_bd_intf_ports XCOM_DTO] [get_bd_intf_pins xcom_dto_buf/CLK_OUT_D3]
  connect_bd_intf_net -intf_net zynq_ultra_ps_e_0_M_AXI_HPM0_FPD [get_bd_intf_pins zynq_ultra_ps_e_0/M_AXI_HPM0_FPD] [get_bd_intf_pins ps8_0_axi_periph/S00_AXI]

  # Create port connections
  connect_bd_net -net Net [get_bd_pins cat_dt/dout] [get_bd_pins xcom_1/i_xcom_data] [get_bd_pins xcom_txrx_0/i_xcom_data] [get_bd_pins system_ila_1/probe5]
  connect_bd_net -net Net1 [get_bd_pins rst_tproc/peripheral_aresetn] [get_bd_pins xcom_cdc_0/i_core_rstn] [get_bd_pins xcom_1/i_core_rstn]
  connect_bd_net -net cat_ck_dout [get_bd_pins cat_ck/dout] [get_bd_pins xcom_1/i_xcom_clk] [get_bd_pins xcom_txrx_0/i_xcom_clk] [get_bd_pins system_ila_1/probe6]
  connect_bd_net -net clk_adc2_x2_locked [get_bd_pins clk_t_clk/locked] [get_bd_pins rst_adc2_x2/dcm_locked]
  connect_bd_net -net clk_c_clk_locked [get_bd_pins clk_c_clk/locked] [get_bd_pins rst_tproc/dcm_locked]
  connect_bd_net -net clk_t_clk [get_bd_pins clk_t_clk/clk_out1] [get_bd_pins rst_adc2_x2/slowest_sync_clk] [get_bd_pins system_ila_0/clk] [get_bd_pins system_ila_1/clk] [get_bd_pins xcom_cdc_0/i_time_clk] [get_bd_pins xcom_1/i_time_clk] [get_bd_pins xcom_cmd_0/i_clk] [get_bd_pins xcom_txrx_0/i_clk] [get_bd_pins system_ila_2/clk]
  connect_bd_net -net rst_adc2_x2_peripheral_aresetn [get_bd_pins rst_adc2_x2/peripheral_aresetn] [get_bd_pins xcom_cdc_0/i_time_rstn] [get_bd_pins xcom_1/i_time_rstn] [get_bd_pins xcom_cmd_0/i_rstn] [get_bd_pins xcom_txrx_0/i_rstn]
  connect_bd_net -net rst_ps8_0_99M_peripheral_aresetn [get_bd_pins rst_100/peripheral_aresetn] [get_bd_pins ps8_0_axi_periph/ARESETN] [get_bd_pins ps8_0_axi_periph/S00_ARESETN] [get_bd_pins ps8_0_axi_periph/M00_ARESETN] [get_bd_pins ps8_0_axi_periph/M01_ARESETN] [get_bd_pins ps8_0_axi_periph/M02_ARESETN] [get_bd_pins xcom_cdc_0/i_ps_rstn] [get_bd_pins xcom_1/i_ps_rstn] [get_bd_pins xcom_axil_slv_0/reset_n]
  connect_bd_net -net usp_rf_data_converter_0_clk_adc0 [get_bd_pins clk_c_clk/clk_out1] [get_bd_pins rst_tproc/slowest_sync_clk] [get_bd_pins xcom_cdc_0/i_core_clk] [get_bd_pins xcom_1/i_core_clk]
  connect_bd_net -net xcom_1_o_xcom_id [get_bd_pins xcom_1/o_xcom_id] [get_bd_pins system_ila_2/probe9]
  connect_bd_net -net xcom_2_o_xcom_clk [get_bd_pins xcom_1/o_xcom_clk] [get_bd_pins cat_ck/In1]
  connect_bd_net -net xcom_2_o_xcom_data [get_bd_pins xcom_1/o_xcom_data] [get_bd_pins cat_dt/In1]
  connect_bd_net -net xcom_axil_slv_0_o_axi_data1 [get_bd_pins xcom_axil_slv_0/o_xcom_axi_data1] [get_bd_pins system_ila_0/probe2] [get_bd_pins xcom_cdc_0/i_axi_data1]
  connect_bd_net -net xcom_axil_slv_0_o_axi_data2 [get_bd_pins xcom_axil_slv_0/o_xcom_axi_data2] [get_bd_pins system_ila_0/probe3] [get_bd_pins xcom_cdc_0/i_axi_data2]
  connect_bd_net -net xcom_axil_slv_0_o_xcom_axi_addr [get_bd_pins xcom_axil_slv_0/o_xcom_axi_addr] [get_bd_pins system_ila_0/probe16]
  connect_bd_net -net xcom_axil_slv_0_o_xcom_cfg [get_bd_pins xcom_axil_slv_0/o_xcom_cfg] [get_bd_pins system_ila_0/probe1] [get_bd_pins xcom_cdc_0/i_xcom_cfg]
  connect_bd_net -net xcom_axil_slv_0_o_xcom_ctrl [get_bd_pins xcom_axil_slv_0/o_xcom_ctrl] [get_bd_pins system_ila_0/probe0] [get_bd_pins xcom_cdc_0/i_xcom_ctrl]
  connect_bd_net -net xcom_cdc_0_o_axi_data1_sync [get_bd_pins xcom_cdc_0/o_axi_data1_sync] [get_bd_pins xlconcat_1/In0] [get_bd_pins system_ila_0/probe7]
  connect_bd_net -net xcom_cdc_0_o_axi_data2_sync [get_bd_pins xcom_cdc_0/o_axi_data2_sync] [get_bd_pins xlconcat_1/In1] [get_bd_pins system_ila_0/probe8]
  connect_bd_net -net xcom_cdc_0_o_core_data1_sync [get_bd_pins xcom_cdc_0/o_core_data1_sync] [get_bd_pins xlconcat_0/In0]
  connect_bd_net -net xcom_cdc_0_o_core_data2_sync [get_bd_pins xcom_cdc_0/o_core_data2_sync] [get_bd_pins xlconcat_0/In1]
  connect_bd_net -net xcom_cdc_0_o_core_en_sync [get_bd_pins xcom_cdc_0/o_core_en_sync] [get_bd_pins xcom_cmd_0/i_core_en]
  connect_bd_net -net xcom_cdc_0_o_core_op_sync [get_bd_pins xcom_cdc_0/o_core_op_sync] [get_bd_pins xcom_cmd_0/i_core_op]
  connect_bd_net -net xcom_cdc_0_o_xcom_cfg_sync [get_bd_pins xcom_cdc_0/o_xcom_cfg_sync] [get_bd_pins xcom_txrx_0/i_cfg_tick] [get_bd_pins system_ila_0/probe6] [get_bd_pins system_ila_1/probe4]
  connect_bd_net -net xcom_cdc_0_o_xcom_ctrl_sync [get_bd_pins xcom_cdc_0/o_xcom_ctrl_sync] [get_bd_pins xcom_cmd_0/i_ps_ctrl] [get_bd_pins system_ila_0/probe5] [get_bd_pins system_ila_2/probe0]
  connect_bd_net -net xcom_cdc_0_o_xcom_data1_sync [get_bd_pins xcom_cdc_0/o_xcom_data1_sync] [get_bd_pins xcom_axil_slv_0/i_xcom_data1] [get_bd_pins system_ila_0/probe10]
  connect_bd_net -net xcom_cdc_0_o_xcom_data2_sync [get_bd_pins xcom_cdc_0/o_xcom_data2_sync] [get_bd_pins xcom_axil_slv_0/i_xcom_data2] [get_bd_pins system_ila_0/probe11]
  connect_bd_net -net xcom_cdc_0_o_xcom_debug_sync [get_bd_pins xcom_cdc_0/o_xcom_debug_sync] [get_bd_pins xcom_axil_slv_0/i_xcom_debug] [get_bd_pins system_ila_0/probe15]
  connect_bd_net -net xcom_cdc_0_o_xcom_flag_sync [get_bd_pins xcom_cdc_0/o_xcom_flag_sync] [get_bd_pins xcom_axil_slv_0/i_xcom_flag] [get_bd_pins system_ila_0/probe9]
  connect_bd_net -net xcom_cdc_0_o_xcom_id_sync [get_bd_pins xcom_cdc_0/o_xcom_id_sync] [get_bd_pins system_ila_0/probe4] [get_bd_pins xcom_axil_slv_0/i_board_id]
  connect_bd_net -net xcom_cdc_0_o_xcom_rx_data_sync [get_bd_pins xcom_cdc_0/o_xcom_rx_data_sync] [get_bd_pins xcom_axil_slv_0/i_xcom_rx_data] [get_bd_pins system_ila_0/probe12]
  connect_bd_net -net xcom_cdc_0_o_xcom_status_sync [get_bd_pins xcom_cdc_0/o_xcom_status_sync] [get_bd_pins xcom_axil_slv_0/i_xcom_status] [get_bd_pins system_ila_0/probe14]
  connect_bd_net -net xcom_cdc_0_o_xcom_tx_data_sync [get_bd_pins xcom_cdc_0/o_xcom_tx_data_sync] [get_bd_pins xcom_axil_slv_0/i_xcom_tx_data] [get_bd_pins system_ila_0/probe13]
  connect_bd_net -net xcom_cki_buf_IBUF_OUT [get_bd_pins xcom_cki_buf/IBUF_OUT] [get_bd_pins cat_ck/In0]
  connect_bd_net -net xcom_cmd_0_o_data [get_bd_pins xcom_cmd_0/o_data] [get_bd_pins xcom_txrx_0/i_data] [get_bd_pins system_ila_2/probe7] [get_bd_pins system_ila_1/probe3]
  connect_bd_net -net xcom_cmd_0_o_data_cntr [get_bd_pins xcom_cmd_0/o_data_cntr] [get_bd_pins system_ila_2/probe8]
  connect_bd_net -net xcom_cmd_0_o_op [get_bd_pins xcom_cmd_0/o_op] [get_bd_pins xcom_txrx_0/i_header] [get_bd_pins system_ila_2/probe6] [get_bd_pins system_ila_1/probe2]
  connect_bd_net -net xcom_cmd_0_o_req_loc [get_bd_pins xcom_cmd_0/o_req_loc] [get_bd_pins xcom_txrx_0/i_req_loc] [get_bd_pins system_ila_2/probe4] [get_bd_pins system_ila_1/probe0]
  connect_bd_net -net xcom_cmd_0_o_req_net [get_bd_pins xcom_cmd_0/o_req_net] [get_bd_pins xcom_txrx_0/i_req_net] [get_bd_pins system_ila_2/probe5] [get_bd_pins system_ila_1/probe1]
  connect_bd_net -net xcom_dti_buf_IBUF_OUT [get_bd_pins xcom_dti_buf/IBUF_OUT] [get_bd_pins cat_dt/In0]
  connect_bd_net -net xcom_txrx_0_o_ack_loc [get_bd_pins xcom_txrx_0/o_ack_loc] [get_bd_pins xcom_cmd_0/i_ack_loc] [get_bd_pins system_ila_2/probe2] [get_bd_pins system_ila_1/probe7]
  connect_bd_net -net xcom_txrx_0_o_ack_net [get_bd_pins xcom_txrx_0/o_ack_net] [get_bd_pins xcom_cmd_0/i_ack_net] [get_bd_pins system_ila_2/probe3] [get_bd_pins system_ila_1/probe8]
  connect_bd_net -net xcom_txrx_0_o_core_start [get_bd_pins xcom_txrx_0/o_core_start] [get_bd_pins system_ila_1/probe14]
  connect_bd_net -net xcom_txrx_0_o_core_stop [get_bd_pins xcom_txrx_0/o_core_stop] [get_bd_pins system_ila_1/probe15]
  connect_bd_net -net xcom_txrx_0_o_dbg_data [get_bd_pins xcom_txrx_0/o_dbg_data] [get_bd_pins xcom_cdc_0/i_xcom_debug] [get_bd_pins system_ila_1/probe22]
  connect_bd_net -net xcom_txrx_0_o_dbg_rx_data [get_bd_pins xcom_txrx_0/o_dbg_rx_data] [get_bd_pins xcom_cdc_0/i_xcom_rx_data] [get_bd_pins system_ila_1/probe19]
  connect_bd_net -net xcom_txrx_0_o_dbg_status [get_bd_pins xcom_txrx_0/o_dbg_status] [get_bd_pins xcom_cdc_0/i_xcom_status] [get_bd_pins system_ila_1/probe21]
  connect_bd_net -net xcom_txrx_0_o_dbg_tx_data [get_bd_pins xcom_txrx_0/o_dbg_tx_data] [get_bd_pins xcom_cdc_0/i_xcom_tx_data] [get_bd_pins system_ila_1/probe20]
  connect_bd_net -net xcom_txrx_0_o_proc_start [get_bd_pins xcom_txrx_0/o_proc_start] [get_bd_pins system_ila_1/probe9]
  connect_bd_net -net xcom_txrx_0_o_proc_stop [get_bd_pins xcom_txrx_0/o_proc_stop] [get_bd_pins system_ila_1/probe10]
  connect_bd_net -net xcom_txrx_0_o_qp_data1 [get_bd_pins xcom_txrx_0/o_qp_data1] [get_bd_pins xcom_cdc_0/i_core_data1] [get_bd_pins system_ila_1/probe23]
  connect_bd_net -net xcom_txrx_0_o_qp_data2 [get_bd_pins xcom_txrx_0/o_qp_data2] [get_bd_pins xcom_cdc_0/i_core_data2]
  connect_bd_net -net xcom_txrx_0_o_qp_flag [get_bd_pins xcom_txrx_0/o_qp_flag] [get_bd_pins xcom_cdc_0/i_core_flag]
  connect_bd_net -net xcom_txrx_0_o_qp_ready [get_bd_pins xcom_txrx_0/o_qp_ready] [get_bd_pins xcom_cdc_0/i_core_ready]
  connect_bd_net -net xcom_txrx_0_o_qp_valid [get_bd_pins xcom_txrx_0/o_qp_valid] [get_bd_pins xcom_cdc_0/i_core_valid]
  connect_bd_net -net xcom_txrx_0_o_time_rst [get_bd_pins xcom_txrx_0/o_time_rst] [get_bd_pins system_ila_1/probe11]
  connect_bd_net -net xcom_txrx_0_o_time_update [get_bd_pins xcom_txrx_0/o_time_update] [get_bd_pins system_ila_1/probe12]
  connect_bd_net -net xcom_txrx_0_o_time_update_data [get_bd_pins xcom_txrx_0/o_time_update_data] [get_bd_pins system_ila_1/probe13]
  connect_bd_net -net xcom_txrx_0_o_xcom_clk [get_bd_pins xcom_txrx_0/o_xcom_clk] [get_bd_pins xcom_cko_buf1/OBUF_IN] [get_bd_pins xcom_cko_buf/OBUF_IN] [get_bd_pins system_ila_1/probe18]
  connect_bd_net -net xcom_txrx_0_o_xcom_data [get_bd_pins xcom_txrx_0/o_xcom_data] [get_bd_pins xcom_dto_buf/OBUF_IN] [get_bd_pins xcom_dto_buf1/OBUF_IN] [get_bd_pins system_ila_1/probe17]
  connect_bd_net -net xcom_txrx_0_o_xcom_id [get_bd_pins xcom_txrx_0/o_xcom_id] [get_bd_ports xcom_id_o_0] [get_bd_pins xcom_cdc_0/i_xcom_id] [get_bd_pins system_ila_1/probe16]
  connect_bd_net -net xlconcat_0_dout [get_bd_pins xlconcat_0/dout] [get_bd_pins xcom_cmd_0/i_core_data]
  connect_bd_net -net xlconcat_1_dout [get_bd_pins xlconcat_1/dout] [get_bd_pins xcom_cmd_0/i_ps_data] [get_bd_pins system_ila_2/probe1]
  connect_bd_net -net xlconstant_0_dout [get_bd_pins xlconstant_0/dout] [get_bd_pins xcom_axil_slv_0/i_xcom_mem]
  connect_bd_net -net xlconstant_1_dout [get_bd_pins xlconstant_1/dout] [get_bd_pins xcom_txrx_0/i_sync]
  connect_bd_net -net xlconstant_2_dout [get_bd_pins xlconstant_2/dout] [get_bd_pins xcom_cdc_0/i_core_en]
  connect_bd_net -net xlconstant_3_dout [get_bd_pins xlconstant_3/dout] [get_bd_pins xcom_cdc_0/i_core_op]
  connect_bd_net -net zynq_ultra_ps_e_0_pl_clk0 [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] [get_bd_pins clk_c_clk/clk_in1] [get_bd_pins clk_t_clk/clk_in1] [get_bd_pins ps8_0_axi_periph/ACLK] [get_bd_pins ps8_0_axi_periph/S00_ACLK] [get_bd_pins ps8_0_axi_periph/M00_ACLK] [get_bd_pins ps8_0_axi_periph/M01_ACLK] [get_bd_pins ps8_0_axi_periph/M02_ACLK] [get_bd_pins rst_100/slowest_sync_clk] [get_bd_pins zynq_ultra_ps_e_0/maxihpm0_fpd_aclk] [get_bd_pins xcom_cdc_0/i_ps_clk] [get_bd_pins xcom_1/i_ps_clk] [get_bd_pins xcom_axil_slv_0/clk]
  connect_bd_net -net zynq_ultra_ps_e_0_pl_resetn0 [get_bd_pins zynq_ultra_ps_e_0/pl_resetn0] [get_bd_pins clk_c_clk/resetn] [get_bd_pins clk_t_clk/resetn] [get_bd_pins rst_100/ext_reset_in] [get_bd_pins rst_adc2_x2/ext_reset_in] [get_bd_pins rst_tproc/ext_reset_in]

  # Create address segments
  assign_bd_address -offset 0xA0001000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs xcom_1/s_axi/reg0] -force
  assign_bd_address -offset 0xA0000000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs xcom_axil_slv_0/s_axi/reg0] -force

  # Perform GUI Layout
  regenerate_bd_layout -layout_string {
   "ActiveEmotionalView":"Color Coded",
   "Color Coded_ExpandedHierarchyInLayout":"",
   "Color Coded_Layout":"# # String gsaved with Nlview 7.5.8 2022-09-21 7111 VDI=41 GEI=38 GUI=JA:10.0 TLS
#  -string -flagsOSRD
preplace port XCOM_CK -pg 1 -lvl 0 -x 0 -y 280 -defaultsOSRD
preplace port XCOM_DT -pg 1 -lvl 0 -x 0 -y 160 -defaultsOSRD
preplace port XCOM_CKO -pg 1 -lvl 9 -x 3990 -y 1670 -defaultsOSRD
preplace port XCOM_DTO -pg 1 -lvl 9 -x 3990 -y 1370 -defaultsOSRD
preplace port XCOM_CKO1 -pg 1 -lvl 9 -x 3990 -y 1570 -defaultsOSRD
preplace port XCOM_DTO1 -pg 1 -lvl 9 -x 3990 -y 1470 -defaultsOSRD
preplace port port-id_PMOD0_0 -pg 1 -lvl 9 -x 3990 -y 20 -defaultsOSRD
preplace port port-id_PMOD0_1 -pg 1 -lvl 9 -x 3990 -y 40 -defaultsOSRD
preplace portBus xcom_id_o_0 -pg 1 -lvl 9 -x 3990 -y 1310 -defaultsOSRD
preplace inst cat_dt -pg 1 -lvl 2 -x 900 -y 170 -defaultsOSRD
preplace inst clk_c_clk -pg 1 -lvl 1 -x 340 -y 530 -defaultsOSRD
preplace inst clk_t_clk -pg 1 -lvl 1 -x 340 -y 410 -defaultsOSRD
preplace inst ps8_0_axi_periph -pg 1 -lvl 2 -x 900 -y 940 -defaultsOSRD
preplace inst rst_100 -pg 1 -lvl 1 -x 340 -y 680 -defaultsOSRD
preplace inst rst_adc2_x2 -pg 1 -lvl 2 -x 900 -y 470 -defaultsOSRD
preplace inst rst_tproc -pg 1 -lvl 2 -x 900 -y 650 -defaultsOSRD
preplace inst cat_ck -pg 1 -lvl 2 -x 900 -y 290 -defaultsOSRD
preplace inst zynq_ultra_ps_e_0 -pg 1 -lvl 1 -x 340 -y 860 -defaultsOSRD
preplace inst xcom_cko_buf -pg 1 -lvl 8 -x 3830 -y 1670 -defaultsOSRD
preplace inst xcom_dto_buf -pg 1 -lvl 8 -x 3830 -y 1370 -defaultsOSRD
preplace inst xcom_cki_buf -pg 1 -lvl 1 -x 340 -y 280 -defaultsOSRD
preplace inst xcom_dti_buf -pg 1 -lvl 1 -x 340 -y 160 -defaultsOSRD
preplace inst xcom_cko_buf1 -pg 1 -lvl 8 -x 3830 -y 1570 -defaultsOSRD
preplace inst xcom_dto_buf1 -pg 1 -lvl 8 -x 3830 -y 1470 -defaultsOSRD
preplace inst xlconcat_0 -pg 1 -lvl 5 -x 2470 -y 760 -defaultsOSRD
preplace inst xlconcat_1 -pg 1 -lvl 5 -x 2470 -y 1270 -defaultsOSRD
preplace inst xlconstant_0 -pg 1 -lvl 2 -x 900 -y 60 -defaultsOSRD
preplace inst system_ila_0 -pg 1 -lvl 7 -x 3310 -y 450 -defaultsOSRD
preplace inst xlconstant_1 -pg 1 -lvl 6 -x 2810 -y 900 -defaultsOSRD
preplace inst system_ila_1 -pg 1 -lvl 8 -x 3830 -y 1010 -defaultsOSRD
preplace inst xcom_cdc_0 -pg 1 -lvl 4 -x 2030 -y 890 -defaultsOSRD
preplace inst xcom_1 -pg 1 -lvl 3 -x 1460 -y 1010 -defaultsOSRD
preplace inst xcom_cmd_0 -pg 1 -lvl 6 -x 2810 -y 1100 -defaultsOSRD
preplace inst xcom_txrx_0 -pg 1 -lvl 7 -x 3310 -y 1040 -defaultsOSRD
preplace inst xcom_axil_slv_0 -pg 1 -lvl 3 -x 1460 -y 340 -defaultsOSRD
preplace inst system_ila_2 -pg 1 -lvl 7 -x 3310 -y 1560 -defaultsOSRD
preplace inst xlconstant_2 -pg 1 -lvl 3 -x 1460 -y 700 -defaultsOSRD
preplace inst xlconstant_3 -pg 1 -lvl 3 -x 1460 -y 800 -defaultsOSRD
preplace netloc Net 1 2 6 1160 580 NJ 580 2300J 610 NJ 610 3070 760 3620
preplace netloc Net1 1 2 2 1100 1180 1740
preplace netloc cat_ck_dout 1 2 6 1150 600 NJ 600 2240J 830 NJ 830 3130 770 3610
preplace netloc clk_adc2_x2_locked 1 1 1 690 420n
preplace netloc clk_c_clk_locked 1 1 1 660 540n
preplace netloc clk_t_clk 1 1 7 700 370 1140 860 1660 610 2280J 840 2580 390 3020 690 3690
preplace netloc rst_adc2_x2_peripheral_aresetn 1 2 5 1120 1170 1750 1160 2240J 1150 2590 960 3050
preplace netloc rst_ps8_0_99M_peripheral_aresetn 1 1 3 680 360 1190 640 1720J
preplace netloc usp_rf_data_converter_0_clk_adc0 1 1 3 670 750 1110 1160 1690
preplace netloc xcom_2_o_xcom_clk 1 1 3 720 760 1090J 1190 1660
preplace netloc xcom_2_o_xcom_data 1 1 3 710 770 1080J 1200 1650
preplace netloc xcom_axil_slv_0_o_axi_data1 1 3 4 1710 340 NJ 340 NJ 340 N
preplace netloc xcom_axil_slv_0_o_axi_data2 1 3 4 1680 360 NJ 360 NJ 360 N
preplace netloc xcom_axil_slv_0_o_xcom_cfg 1 3 4 1730 320 NJ 320 NJ 320 N
preplace netloc xcom_axil_slv_0_o_xcom_ctrl 1 3 4 1760 300 NJ 300 NJ 300 N
preplace netloc xcom_cdc_0_o_axi_data1_sync 1 4 3 2260 1160 2640J 1240 3000
preplace netloc xcom_cdc_0_o_axi_data2_sync 1 4 3 2230 1180 2620J 1260 3010
preplace netloc xcom_cdc_0_o_core_data1_sync 1 4 1 N 750
preplace netloc xcom_cdc_0_o_core_data2_sync 1 4 1 N 770
preplace netloc xcom_cdc_0_o_core_en_sync 1 4 2 2260J 670 2660
preplace netloc xcom_cdc_0_o_core_op_sync 1 4 2 2320J 680 2630
preplace netloc xcom_cdc_0_o_xcom_cfg_sync 1 4 4 2350J 880 2590J 840 3120 680 3670
preplace netloc xcom_cdc_0_o_xcom_ctrl_sync 1 4 3 NJ 870 2640 470 3030
preplace netloc xcom_cdc_0_o_xcom_data1_sync 1 2 5 1270 510 NJ 510 2270 500 NJ 500 NJ
preplace netloc xcom_cdc_0_o_xcom_data2_sync 1 2 5 1240 540 NJ 540 2330 520 NJ 520 NJ
preplace netloc xcom_cdc_0_o_xcom_debug_sync 1 2 5 1210 570 NJ 570 2290 600 NJ 600 NJ
preplace netloc xcom_cdc_0_o_xcom_flag_sync 1 2 5 1260 520 NJ 520 2250 480 NJ 480 NJ
preplace netloc xcom_cdc_0_o_xcom_id_sync 1 2 5 1250 530 NJ 530 2230 400 NJ 400 3010J
preplace netloc xcom_cdc_0_o_xcom_rx_data_sync 1 2 5 1230 550 NJ 550 2340 540 NJ 540 NJ
preplace netloc xcom_cdc_0_o_xcom_status_sync 1 2 5 1220 560 NJ 560 2310 580 NJ 580 NJ
preplace netloc xcom_cdc_0_o_xcom_tx_data_sync 1 2 5 1200 620 NJ 620 2360 560 NJ 560 NJ
preplace netloc xcom_cki_buf_IBUF_OUT 1 1 1 NJ 280
preplace netloc xcom_cmd_0_o_data 1 6 2 3040 740 3650
preplace netloc xcom_cmd_0_o_data_cntr 1 6 1 2960 1140n
preplace netloc xcom_cmd_0_o_op 1 6 2 3110 750 3640
preplace netloc xcom_cmd_0_o_req_loc 1 6 2 3090 720 3680
preplace netloc xcom_cmd_0_o_req_net 1 6 2 3100 730 3660
preplace netloc xcom_dti_buf_IBUF_OUT 1 1 1 NJ 160
preplace netloc xcom_txrx_0_o_ack_loc 1 5 3 2660 1290 2970 1400 3600
preplace netloc xcom_txrx_0_o_ack_net 1 5 3 2650 1300 3080 710 3630
preplace netloc xcom_txrx_0_o_dbg_data 1 3 5 1790 1350 NJ 1350 NJ 1350 NJ 1350 3580
preplace netloc xcom_txrx_0_o_dbg_rx_data 1 3 5 1820 1170 NJ 1170 2630J 1250 3000J 1310 3550
preplace netloc xcom_txrx_0_o_dbg_status 1 3 5 1810 1200 NJ 1200 2580J 1280 2980J 1330 3570
preplace netloc xcom_txrx_0_o_dbg_tx_data 1 3 5 1830 1190 NJ 1190 2610J 1270 2990J 1320 3560
preplace netloc xcom_txrx_0_o_qp_flag 1 3 5 1780 1360 NJ 1360 NJ 1360 NJ 1360 3490
preplace netloc xcom_txrx_0_o_qp_ready 1 3 5 1770 1370 NJ 1370 NJ 1370 NJ 1370 3520
preplace netloc xcom_txrx_0_o_qp_valid 1 3 5 1720 1380 NJ 1380 NJ 1380 NJ 1380 3510
preplace netloc xcom_txrx_0_o_xcom_clk 1 7 1 3540 1150n
preplace netloc xcom_txrx_0_o_xcom_data 1 7 1 3530 1130n
preplace netloc xcom_txrx_0_o_xcom_id 1 3 6 1700 1390 NJ 1390 NJ 1390 NJ 1390 3690 1310 NJ
preplace netloc xlconcat_0_dout 1 5 1 2600 760n
preplace netloc xlconcat_1_dout 1 5 2 2600 1500 NJ
preplace netloc xlconstant_0_dout 1 2 1 1170 60n
preplace netloc xlconstant_1_dout 1 6 1 3060J 900n
preplace netloc zynq_ultra_ps_e_0_pl_clk0 1 0 4 30 950 660 780 1180 630 1750J
preplace netloc zynq_ultra_ps_e_0_pl_resetn0 1 0 2 20 340 650
preplace netloc xcom_axil_slv_0_o_xcom_axi_addr 1 3 4 NJ 380 NJ 380 NJ 380 2960
preplace netloc xlconstant_2_dout 1 3 1 1700J 700n
preplace netloc xlconstant_3_dout 1 3 1 1670J 800n
preplace netloc xcom_txrx_0_o_proc_start 1 7 1 N 970
preplace netloc xcom_txrx_0_o_proc_stop 1 7 1 N 990
preplace netloc xcom_txrx_0_o_time_rst 1 7 1 N 1010
preplace netloc xcom_txrx_0_o_time_update 1 7 1 N 1030
preplace netloc xcom_txrx_0_o_time_update_data 1 7 1 N 1050
preplace netloc xcom_txrx_0_o_core_start 1 7 1 N 1070
preplace netloc xcom_txrx_0_o_core_stop 1 7 1 N 1090
preplace netloc xcom_txrx_0_o_qp_data1 1 3 5 1800 1340 NJ 1340 NJ 1340 NJ 1340 3590
preplace netloc xcom_txrx_0_o_qp_data2 1 3 5 1830 590 2350J 690 NJ 690 2960J 700 3500
preplace netloc xcom_1_o_xcom_id 1 3 4 1670 1660 NJ 1660 NJ 1660 NJ
preplace netloc CLK_IN_D_0_1 1 0 1 NJ 280
preplace netloc CLK_IN_D_1_1 1 0 1 NJ 160
preplace netloc ps8_0_axi_periph_M00_AXI 1 2 1 N 920
preplace netloc xcom_cko_buf1_CLK_OUT_D3 1 8 1 NJ 1570
preplace netloc xcom_cko_buf_CLK_OUT_D3 1 8 1 NJ 1670
preplace netloc xcom_dto_buf1_CLK_OUT_D3 1 8 1 NJ 1470
preplace netloc xcom_dto_buf_CLK_OUT_D3 1 8 1 NJ 1370
preplace netloc zynq_ultra_ps_e_0_M_AXI_HPM0_FPD 1 1 1 N 840
preplace netloc ps8_0_axi_periph_M02_AXI 1 2 1 1130 230n
levelinfo -pg 1 0 340 900 1460 2030 2470 2810 3310 3830 3990
pagesize -pg 1 -db -bbox -sgen -120 0 4170 1730
",
   "Color Coded_ScaleFactor":"0.286458",
   "Color Coded_TopLeft":"-342,3",
   "Default View_ScaleFactor":"1.01479",
   "Default View_TopLeft":"2805,1290",
   "ExpandedHierarchyInLayout":"",
   "guistr":"# # String gsaved with Nlview 7.5.8 2022-09-21 7111 VDI=41 GEI=38 GUI=JA:10.0 TLS
#  -string -flagsOSRD
preplace port XCOM_CK -pg 1 -lvl 0 -x -10 -y 2080 -defaultsOSRD
preplace port XCOM_DT -pg 1 -lvl 0 -x -10 -y 2200 -defaultsOSRD
preplace port XCOM_CKO -pg 1 -lvl 11 -x 4680 -y 1850 -defaultsOSRD
preplace port XCOM_DTO -pg 1 -lvl 11 -x 4680 -y 2050 -defaultsOSRD
preplace port XCOM_CKO1 -pg 1 -lvl 11 -x 4680 -y 1950 -defaultsOSRD
preplace port XCOM_DTO1 -pg 1 -lvl 11 -x 4680 -y 2150 -defaultsOSRD
preplace port port-id_PMOD0_0 -pg 1 -lvl 11 -x 4680 -y 2200 -defaultsOSRD
preplace port port-id_PMOD0_1 -pg 1 -lvl 11 -x 4680 -y 2220 -defaultsOSRD
preplace portBus xcom_id_o_0 -pg 1 -lvl 11 -x 4680 -y 1790 -defaultsOSRD
preplace inst axi_dma_tproc -pg 1 -lvl 6 -x 2780 -y 1220 -defaultsOSRD
preplace inst axi_smc -pg 1 -lvl 2 -x 550 -y 1800 -defaultsOSRD
preplace inst axis_constant_0 -pg 1 -lvl 4 -x 1550 -y 1420 -defaultsOSRD
preplace inst cat_dt -pg 1 -lvl 5 -x 2090 -y 2210 -defaultsOSRD
preplace inst clk_c_clk -pg 1 -lvl 4 -x 1550 -y 1920 -defaultsOSRD
preplace inst clk_t_clk -pg 1 -lvl 3 -x 1020 -y 1950 -defaultsOSRD
preplace inst ps8_0_axi_periph -pg 1 -lvl 4 -x 1550 -y 1170 -defaultsOSRD
preplace inst rst_100 -pg 1 -lvl 1 -x 200 -y 1840 -defaultsOSRD
preplace inst rst_adc2_x2 -pg 1 -lvl 4 -x 1550 -y 1770 -defaultsOSRD
preplace inst rst_tproc -pg 1 -lvl 5 -x 2090 -y 1910 -defaultsOSRD
preplace inst cat_ck -pg 1 -lvl 5 -x 2090 -y 2090 -defaultsOSRD
preplace inst zynq_ultra_ps_e_0 -pg 1 -lvl 3 -x 1020 -y 1770 -defaultsOSRD
preplace inst xcom_cko_buf -pg 1 -lvl 10 -x 4520 -y 1850 -defaultsOSRD
preplace inst xcom_dto_buf -pg 1 -lvl 10 -x 4520 -y 2050 -defaultsOSRD
preplace inst xcom_cki_buf -pg 1 -lvl 4 -x 1550 -y 2080 -defaultsOSRD
preplace inst xcom_dti_buf -pg 1 -lvl 4 -x 1550 -y 2200 -defaultsOSRD
preplace inst xcom_cko_buf1 -pg 1 -lvl 10 -x 4520 -y 1950 -defaultsOSRD
preplace inst xcom_dto_buf1 -pg 1 -lvl 10 -x 4520 -y 2150 -defaultsOSRD
preplace inst qick_processor_0 -pg 1 -lvl 5 -x 2090 -y 1320 -defaultsOSRD
preplace inst xlconcat_0 -pg 1 -lvl 7 -x 3240 -y 770 -defaultsOSRD
preplace inst xlconcat_1 -pg 1 -lvl 7 -x 3240 -y 890 -defaultsOSRD
preplace inst xlconstant_0 -pg 1 -lvl 4 -x 1550 -y 880 -defaultsOSRD
preplace inst system_ila_0 -pg 1 -lvl 6 -x 2780 -y 200 -defaultsOSRD
preplace inst xlconstant_1 -pg 1 -lvl 8 -x 3560 -y 1260 -defaultsOSRD
preplace inst system_ila_1 -pg 1 -lvl 10 -x 4520 -y 1570 -defaultsOSRD
preplace inst xcom_cdc_0 -pg 1 -lvl 6 -x 2780 -y 800 -defaultsOSRD
preplace inst xcom_1 -pg 1 -lvl 6 -x 2780 -y 1820 -defaultsOSRD
preplace inst xcom_cmd_0 -pg 1 -lvl 8 -x 3560 -y 840 -defaultsOSRD
preplace inst xcom_txrx_0 -pg 1 -lvl 9 -x 3990 -y 1270 -defaultsOSRD
preplace inst xcom_axil_slv_0 -pg 1 -lvl 5 -x 2090 -y 850 -defaultsOSRD
preplace netloc Net 1 5 5 2290 2030 NJ 2030 NJ 2030 3790 1700 4350J
preplace netloc Net1 1 3 3 1370 1490 1820 1600 2390
preplace netloc cat_ck_dout 1 5 5 2460 2000 3110J 1960 NJ 1960 3800 1720 4360J
preplace netloc clk_adc2_x2_locked 1 3 1 1360 1810n
preplace netloc clk_c_clk_locked 1 4 1 1730 1930n
preplace netloc clk_t_clk 1 3 7 1340 1630 1780 1630 2350 1380 3110J 1350 3370 1190 3810 1540 4310J
preplace netloc qick_processor_0_qp1_a_dt_o 1 5 1 2400 750n
preplace netloc qick_processor_0_qp1_b_dt_o 1 5 1 2410 770n
preplace netloc qick_processor_0_qp1_en_o 1 5 1 2380 710n
preplace netloc qick_processor_0_qp1_op_o 1 5 1 2280 730n
preplace netloc qick_processor_0_trig_0_o 1 5 6 2310J 2210 NJ 2210 NJ 2210 NJ 2210 NJ 2210 4660J
preplace netloc qick_processor_0_trig_1_o 1 5 6 2320J 1550 NJ 1550 NJ 1550 3710J 2220 NJ 2220 NJ
preplace netloc rst_adc2_x2_peripheral_aresetn 1 4 5 1770 1680 2490 1360 NJ 1360 3390 1200 NJ
preplace netloc rst_ps8_0_99M_peripheral_aresetn 1 1 5 390 1290 NJ 1290 1340 990 1810 670 2330
preplace netloc usp_rf_data_converter_0_clk_adc0 1 3 3 1360 1500 1790 1650 2480
preplace netloc xcom_2_o_xcom_clk 1 4 3 1880 2010 NJ 2010 3040
preplace netloc xcom_2_o_xcom_data 1 4 3 1900 2020 NJ 2020 2980
preplace netloc xcom_axil_slv_0_o_axi_data1 1 5 1 2450 130n
preplace netloc xcom_axil_slv_0_o_axi_data2 1 5 1 2420 150n
preplace netloc xcom_axil_slv_0_o_xcom_cfg 1 5 1 2440 110n
preplace netloc xcom_axil_slv_0_o_xcom_ctrl 1 5 1 2430 90n
preplace netloc xcom_cdc_0_o_axi_data1_sync 1 6 1 3110 820n
preplace netloc xcom_cdc_0_o_axi_data2_sync 1 6 1 3090 840n
preplace netloc xcom_cdc_0_o_core_data1_sync 1 6 1 3110 660n
preplace netloc xcom_cdc_0_o_core_data2_sync 1 6 1 3100 680n
preplace netloc xcom_cdc_0_o_core_en_sync 1 6 2 NJ 620 3410
preplace netloc xcom_cdc_0_o_core_flag_sync 1 5 2 2300 1350 3000
preplace netloc xcom_cdc_0_o_core_op_sync 1 6 2 NJ 640 3380
preplace netloc xcom_cdc_0_o_core_ready_sync 1 5 2 2370 1340 3020
preplace netloc xcom_cdc_0_o_core_valid_sync 1 5 2 NJ 1390 3010
preplace netloc xcom_cdc_0_o_xcom_cfg_sync 1 6 4 3080J 690 NJ 690 3770 1650 NJ
preplace netloc xcom_cdc_0_o_xcom_ctrl_sync 1 6 2 3090J 700 3360
preplace netloc xcom_cdc_0_o_xcom_data1_sync 1 4 3 1750 480 2390 480 2980
preplace netloc xcom_cdc_0_o_xcom_data2_sync 1 4 3 1740 500 2280 490 3070
preplace netloc xcom_cdc_0_o_xcom_debug_sync 1 4 3 1840 510 2300 500 3050
preplace netloc xcom_cdc_0_o_xcom_flag_sync 1 4 3 1850 520 2310 510 3060
preplace netloc xcom_cdc_0_o_xcom_id_sync 1 4 3 1890 680 2460 1070 2990
preplace netloc xcom_cdc_0_o_xcom_rx_data_sync 1 4 3 1890 1020 2500 1080 2980
preplace netloc xcom_cdc_0_o_xcom_status_sync 1 4 3 1860 530 2320 520 3040
preplace netloc xcom_cdc_0_o_xcom_tx_data_sync 1 4 3 1880 540 2330 530 3030
preplace netloc xcom_cki_buf_IBUF_OUT 1 4 1 NJ 2080
preplace netloc xcom_cmd_0_o_data 1 8 1 3800 860n
preplace netloc xcom_cmd_0_o_data_cntr 1 8 2 3790 960 4370J
preplace netloc xcom_cmd_0_o_op 1 8 2 3730 1710 NJ
preplace netloc xcom_cmd_0_o_req_loc 1 8 2 3780 1600 4300J
preplace netloc xcom_cmd_0_o_req_net 1 8 2 3760 1630 NJ
preplace netloc xcom_dti_buf_IBUF_OUT 1 4 1 NJ 2200
preplace netloc xcom_txrx_0_o_ack_loc 1 7 3 3410 990 NJ 990 4380
preplace netloc xcom_txrx_0_o_ack_net 1 7 3 3400 1000 NJ 1000 4350
preplace netloc xcom_txrx_0_o_core_start 1 4 6 1870 1640 NJ 1640 3110J 1670 NJ 1670 NJ 1670 4180
preplace netloc xcom_txrx_0_o_core_stop 1 4 6 1830 1810 2280J 1990 NJ 1990 NJ 1990 NJ 1990 4230
preplace netloc xcom_txrx_0_o_dbg_data 1 5 5 2550 1650 3080J 1680 NJ 1680 NJ 1680 4270
preplace netloc xcom_txrx_0_o_dbg_rx_data 1 5 5 2560 1630 NJ 1630 NJ 1630 3720J 1640 4290
preplace netloc xcom_txrx_0_o_dbg_status 1 5 5 2580 1540 NJ 1540 NJ 1540 3720J 1570 4300
preplace netloc xcom_txrx_0_o_dbg_tx_data 1 5 5 2570 1560 3110J 1580 NJ 1580 NJ 1580 4280
preplace netloc xcom_txrx_0_o_proc_start 1 4 6 1850 1670 NJ 1670 3030J 1690 NJ 1690 NJ 1690 4200
preplace netloc xcom_txrx_0_o_proc_stop 1 4 6 1840 1800 2300J 1980 NJ 1980 NJ 1980 NJ 1980 4250
preplace netloc xcom_txrx_0_o_qp_data1 1 5 5 NJ 1370 NJ 1370 NJ 1370 3750J 1550 4240
preplace netloc xcom_txrx_0_o_qp_data2 1 5 5 2360J 1400 NJ 1400 NJ 1400 3740J 1560 4190
preplace netloc xcom_txrx_0_o_qp_flag 1 5 5 2520 1600 3110J 1590 NJ 1590 NJ 1590 4260
preplace netloc xcom_txrx_0_o_qp_ready 1 5 5 2510 1100 NJ 1100 3410J 1010 3740J 980 4190
preplace netloc xcom_txrx_0_o_qp_valid 1 5 5 2540 1090 NJ 1090 3380J 980 3720J 970 4240
preplace netloc xcom_txrx_0_o_time_rst 1 4 6 1900 1610 NJ 1610 NJ 1610 NJ 1610 NJ 1610 4210
preplace netloc xcom_txrx_0_o_time_update 1 4 6 1860 1660 NJ 1660 NJ 1660 NJ 1660 NJ 1660 4220
preplace netloc xcom_txrx_0_o_time_update_data 1 4 6 1880 1620 NJ 1620 NJ 1620 NJ 1620 NJ 1620 4170
preplace netloc xcom_txrx_0_o_xcom_clk 1 9 1 4330 1400n
preplace netloc xcom_txrx_0_o_xcom_data 1 9 1 4340 1380n
preplace netloc xcom_txrx_0_o_xcom_id 1 5 6 2530 1970 NJ 1970 NJ 1970 NJ 1970 4320 1790 NJ
preplace netloc xlconcat_0_dout 1 7 1 3350 770n
preplace netloc xlconcat_1_dout 1 7 1 3350 880n
preplace netloc xlconstant_0_dout 1 4 1 N 880
preplace netloc xlconstant_1_dout 1 8 1 3740J 1220n
preplace netloc zynq_ultra_ps_e_0_pl_clk0 1 0 6 10 1950 410 1930 700 1870 1350 980 1800 660 2470
preplace netloc zynq_ultra_ps_e_0_pl_resetn0 1 0 5 20 1940 NJ 1940 710 1880 1370 1990 1890J
preplace netloc xcom_axil_slv_0_o_xcom_axi_addr 1 5 1 2340 330n
preplace netloc CLK_IN_D_0_1 1 0 4 NJ 2080 NJ 2080 NJ 2080 NJ
preplace netloc CLK_IN_D_1_1 1 0 4 NJ 2200 NJ 2200 NJ 2200 NJ
preplace netloc axi_dma_0_M_AXI_MM2S 1 1 6 410 1590 NJ 1590 NJ 1590 NJ 1590 NJ 1590 3060
preplace netloc axi_dma_0_M_AXI_S2MM 1 1 6 400 1580 NJ 1580 NJ 1580 NJ 1580 NJ 1580 2990
preplace netloc axi_dma_tproc_M_AXIS_MM2S 1 4 3 1890 1570 NJ 1570 2980
preplace netloc axi_smc_M00_AXI 1 2 1 690 1730n
preplace netloc axis_constant_0_m_axis 1 4 1 1750 1140n
preplace netloc ps8_0_axi_periph_M00_AXI 1 4 2 1740 1730 NJ
preplace netloc ps8_0_axi_periph_M01_AXI 1 4 2 1760 1560 2440J
preplace netloc ps8_0_axi_periph_M02_AXI 1 4 1 N 1180
preplace netloc ps8_0_axi_periph_M03_AXI 1 4 1 1730 740n
preplace netloc qick_processor_0_QPeriphB 1 5 1 2340 1410n
preplace netloc qick_processor_0_m_dma_axis_o 1 5 1 N 1190
preplace netloc xcom_cko_buf1_CLK_OUT_D3 1 10 1 NJ 1950
preplace netloc xcom_cko_buf_CLK_OUT_D3 1 10 1 NJ 1850
preplace netloc xcom_dto_buf1_CLK_OUT_D3 1 10 1 NJ 2150
preplace netloc xcom_dto_buf_CLK_OUT_D3 1 10 1 NJ 2050
preplace netloc zynq_ultra_ps_e_0_M_AXI_HPM0_FPD 1 3 1 1330 1050n
levelinfo -pg 1 -10 200 550 1020 1550 2090 2780 3240 3560 3990 4520 4680
pagesize -pg 1 -db -bbox -sgen -130 0 4860 2280
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

# Add top wrapper and xdc files
make_wrapper -files [get_files ./${overlay_name}/${overlay_name}.srcs/sources_1/bd/${design_name}/${design_name}.bd] -top
add_files -norecurse ./${overlay_name}/${overlay_name}.srcs/sources_1/bd/${design_name}/hdl/${design_name}_wrapper.v
set_property top ${design_name}_wrapper [current_fileset]
import_files -fileset constrs_1 -norecurse ./vivado/constraints/${overlay_name}.xdc
update_compile_order -fileset sources_1


