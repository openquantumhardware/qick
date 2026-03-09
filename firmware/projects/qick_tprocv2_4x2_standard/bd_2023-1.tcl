
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
# source d_1_script.tcl

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
xilinx.com:ip:axi_intc:4.1\
QICK:QICK:axis_cdcsync_v1:1.0\
QICK:QICK:axis_dyn_readout_v1:1.0\
QICK:QICK:axis_register_slice_nb:1.0\
QICK:QICK:axis_signal_gen_v6:1.0\
xilinx.com:ip:proc_sys_reset:5.0\
QICK:QICK:sg_translator:1.0\
xilinx.com:ip:xlconcat:2.1\
xilinx.com:ip:axi_dma:7.1\
xilinx.com:ip:smartconnect:1.0\
xilinx.com:ip:axis_broadcaster:1.1\
xilinx.com:ip:axis_clock_converter:1.1\
xilinx.com:ip:axis_register_slice:1.1\
xilinx.com:ip:axis_switch:1.1\
xilinx.com:ip:clk_wiz:6.0\
xilinx.com:ip:usp_rf_data_converter:2.6\
xilinx.com:ip:zynq_ultra_ps_e:3.5\
QICK:QICK:mr_buffer_et:1.1\
QICK:QICK:qick_processor:2.0\
QICK:QICK:qick_time_tagger:1.0\
QICK:QICK:axis_avg_buffer:1.2\
QICK:QICK:axis_weighted_buffer:1.3\
QICK:QICK:axis_buffer_ddr:1.1\
xilinx.com:ip:axis_dwidth_converter:1.1\
xilinx.com:ip:ddr4:2.2\
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


# Hierarchical cell: ddr4
proc create_hier_cell_ddr4 { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_ddr4() - Empty argument(s)!"}
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
  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 S00_AXI

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 s_axi

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 S_AXIS

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 sys_clk_ddr4

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:ddr4_rtl:1.0 ddr4_pl


  # Create pins
  create_bd_pin -dir O -type clk c0_ddr4_ui_clk
  create_bd_pin -dir I -type rst aresetn
  create_bd_pin -dir I -type clk aclk
  create_bd_pin -dir I trigger
  create_bd_pin -dir I -type clk s_axi_aclk
  create_bd_pin -dir I -type rst s_axi_aresetn
  create_bd_pin -dir I -type rst sys_rst

  # Create instance: rst_ddr4, and set properties
  set rst_ddr4 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_ddr4 ]

  # Create instance: axis_buffer_ddr_0, and set properties
  set axis_buffer_ddr_0 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_buffer_ddr:1.1 axis_buffer_ddr_0 ]
  set_property CONFIG.TARGET_SLAVE_BASE_ADDR {0x00000000} $axis_buffer_ddr_0


  # Create instance: axis_clock_converter_0, and set properties
  set axis_clock_converter_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_clock_converter:1.1 axis_clock_converter_0 ]

  # Create instance: axis_dwidth_converter_0, and set properties
  set axis_dwidth_converter_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_dwidth_converter:1.1 axis_dwidth_converter_0 ]
  set_property CONFIG.M_TDATA_NUM_BYTES {64} $axis_dwidth_converter_0


  # Create instance: ddr4_0, and set properties
  set ddr4_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:ddr4:2.2 ddr4_0 ]
  set_property -dict [list \
    CONFIG.C0.BANK_GROUP_WIDTH {1} \
    CONFIG.C0.DDR4_AxiAddressWidth {32} \
    CONFIG.C0.DDR4_AxiDataWidth {512} \
    CONFIG.C0.DDR4_CasLatency {16} \
    CONFIG.C0.DDR4_CasWriteLatency {12} \
    CONFIG.C0.DDR4_DataWidth {64} \
    CONFIG.C0.DDR4_InputClockPeriod {4998} \
    CONFIG.C0.DDR4_MemoryPart {MT40A512M16HA-083E} \
    CONFIG.C0.DDR4_TimePeriod {833} \
    CONFIG.System_Clock {Differential} \
  ] $ddr4_0


  # Create instance: smartconnect_0, and set properties
  set smartconnect_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 smartconnect_0 ]

  # Create interface connections
  connect_bd_intf_net -intf_net axis_buffer_ddr_0_m_axi [get_bd_intf_pins axis_buffer_ddr_0/m_axi] [get_bd_intf_pins smartconnect_0/S01_AXI]
  connect_bd_intf_net -intf_net axis_clock_converter_0_M_AXIS [get_bd_intf_pins axis_buffer_ddr_0/s_axis] [get_bd_intf_pins axis_clock_converter_0/M_AXIS]
  connect_bd_intf_net -intf_net axis_dwidth_converter_0_M_AXIS [get_bd_intf_pins axis_clock_converter_0/S_AXIS] [get_bd_intf_pins axis_dwidth_converter_0/M_AXIS]
  connect_bd_intf_net -intf_net axis_switch_ddr4_M00_AXIS [get_bd_intf_pins S_AXIS] [get_bd_intf_pins axis_dwidth_converter_0/S_AXIS]
  connect_bd_intf_net -intf_net ddr4_0_C0_DDR4 [get_bd_intf_pins ddr4_pl] [get_bd_intf_pins ddr4_0/C0_DDR4]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M20_AXI [get_bd_intf_pins s_axi] [get_bd_intf_pins axis_buffer_ddr_0/s_axi]
  connect_bd_intf_net -intf_net smartconnect_0_M00_AXI [get_bd_intf_pins ddr4_0/C0_DDR4_S_AXI] [get_bd_intf_pins smartconnect_0/M00_AXI]
  connect_bd_intf_net -intf_net sys_clk_ddr4_1 [get_bd_intf_pins sys_clk_ddr4] [get_bd_intf_pins ddr4_0/C0_SYS_CLK]
  connect_bd_intf_net -intf_net zynq_ultra_ps_e_0_M_AXI_HPM1_FPD [get_bd_intf_pins S00_AXI] [get_bd_intf_pins smartconnect_0/S00_AXI]

  # Create port connections
  connect_bd_net -net clk_adc0_x2_clk_out1 [get_bd_pins aclk] [get_bd_pins axis_clock_converter_0/s_axis_aclk] [get_bd_pins axis_dwidth_converter_0/aclk]
  connect_bd_net -net ddr4_0_c0_ddr4_ui_clk [get_bd_pins ddr4_0/c0_ddr4_ui_clk] [get_bd_pins c0_ddr4_ui_clk] [get_bd_pins axis_buffer_ddr_0/aclk] [get_bd_pins rst_ddr4/slowest_sync_clk] [get_bd_pins axis_clock_converter_0/m_axis_aclk] [get_bd_pins smartconnect_0/aclk]
  connect_bd_net -net ddr4_0_c0_ddr4_ui_clk_sync_rst [get_bd_pins ddr4_0/c0_ddr4_ui_clk_sync_rst] [get_bd_pins rst_ddr4/ext_reset_in]
  connect_bd_net -net proc_sys_reset_0_peripheral_aresetn [get_bd_pins rst_ddr4/peripheral_aresetn] [get_bd_pins axis_buffer_ddr_0/aresetn] [get_bd_pins axis_clock_converter_0/m_axis_aresetn] [get_bd_pins ddr4_0/c0_ddr4_aresetn] [get_bd_pins smartconnect_0/aresetn]
  connect_bd_net -net qick_processor_0_trig_3_o [get_bd_pins trigger] [get_bd_pins axis_buffer_ddr_0/trigger]
  connect_bd_net -net rst_100_bus_struct_reset [get_bd_pins sys_rst] [get_bd_pins ddr4_0/sys_rst]
  connect_bd_net -net rst_adc0_x2_peripheral_aresetn [get_bd_pins aresetn] [get_bd_pins axis_clock_converter_0/s_axis_aresetn] [get_bd_pins axis_dwidth_converter_0/aresetn]
  connect_bd_net -net rst_ps8_0_99M_peripheral_aresetn [get_bd_pins s_axi_aresetn] [get_bd_pins axis_buffer_ddr_0/s_axi_aresetn]
  connect_bd_net -net zynq_ultra_ps_e_0_pl_clk0 [get_bd_pins s_axi_aclk] [get_bd_pins axis_buffer_ddr_0/s_axi_aclk]

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

  set adc2_clk [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 adc2_clk ]

  set vin2_01 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 vin2_01 ]

  set vin2_23 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 vin2_23 ]


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

  # Create instance: axi_intc_0, and set properties
  set axi_intc_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_intc:4.1 axi_intc_0 ]
  set_property CONFIG.C_IRQ_CONNECTION {1} $axi_intc_0


  # Create instance: axis_cdcsync_v1_0, and set properties
  set axis_cdcsync_v1_0 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_cdcsync_v1:1.0 axis_cdcsync_v1_0 ]
  set_property -dict [list \
    CONFIG.B {168} \
    CONFIG.N {3} \
  ] $axis_cdcsync_v1_0


  # Create instance: axis_dyn_readout_v1_0, and set properties
  set axis_dyn_readout_v1_0 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_dyn_readout_v1:1.0 axis_dyn_readout_v1_0 ]

  # Create instance: axis_dyn_readout_v1_1, and set properties
  set axis_dyn_readout_v1_1 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_dyn_readout_v1:1.0 axis_dyn_readout_v1_1 ]

  # Create instance: axis_register_slice_0, and set properties
  set axis_register_slice_0 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_register_slice_nb:1.0 axis_register_slice_0 ]
  set_property -dict [list \
    CONFIG.B {256} \
    CONFIG.N {4} \
  ] $axis_register_slice_0


  # Create instance: axis_register_slice_1, and set properties
  set axis_register_slice_1 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_register_slice_nb:1.0 axis_register_slice_1 ]
  set_property -dict [list \
    CONFIG.B {256} \
    CONFIG.N {4} \
  ] $axis_register_slice_1


  # Create instance: axis_signal_gen_v6_0, and set properties
  set axis_signal_gen_v6_0 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_signal_gen_v6:1.0 axis_signal_gen_v6_0 ]

  # Create instance: axis_signal_gen_v6_1, and set properties
  set axis_signal_gen_v6_1 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_signal_gen_v6:1.0 axis_signal_gen_v6_1 ]

  # Create instance: rst_100, and set properties
  set rst_100 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_100 ]

  # Create instance: rst_adc0, and set properties
  set rst_adc0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_adc0 ]

  # Create instance: rst_adc0_x2, and set properties
  set rst_adc0_x2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_adc0_x2 ]

  # Create instance: rst_core, and set properties
  set rst_core [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_core ]

  # Create instance: rst_dac2, and set properties
  set rst_dac2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_dac2 ]

  # Create instance: sg_translator_0, and set properties
  set sg_translator_0 [ create_bd_cell -type ip -vlnv QICK:QICK:sg_translator:1.0 sg_translator_0 ]

  # Create instance: sg_translator_1, and set properties
  set sg_translator_1 [ create_bd_cell -type ip -vlnv QICK:QICK:sg_translator:1.0 sg_translator_1 ]

  # Create instance: sg_translator_2, and set properties
  set sg_translator_2 [ create_bd_cell -type ip -vlnv QICK:QICK:sg_translator:1.0 sg_translator_2 ]
  set_property CONFIG.OUT_TYPE {3} $sg_translator_2


  # Create instance: sg_translator_3, and set properties
  set sg_translator_3 [ create_bd_cell -type ip -vlnv QICK:QICK:sg_translator:1.0 sg_translator_3 ]
  set_property CONFIG.OUT_TYPE {3} $sg_translator_3


  # Create instance: xlconcat_intc, and set properties
  set xlconcat_intc [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 xlconcat_intc ]
  set_property CONFIG.NUM_PORTS {8} $xlconcat_intc


  # Create instance: ddr4
  create_hier_cell_ddr4 [current_bd_instance .] ddr4

  # Create instance: axi_dma_avg, and set properties
  set axi_dma_avg [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma_avg ]
  set_property -dict [list \
    CONFIG.c_include_mm2s {0} \
    CONFIG.c_include_sg {0} \
    CONFIG.c_sg_length_width {26} \
  ] $axi_dma_avg


  # Create instance: axi_dma_buf, and set properties
  set axi_dma_buf [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma_buf ]
  set_property -dict [list \
    CONFIG.c_include_mm2s {0} \
    CONFIG.c_include_sg {0} \
    CONFIG.c_sg_length_width {26} \
  ] $axi_dma_buf


  # Create instance: axi_dma_gen, and set properties
  set axi_dma_gen [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma_gen ]
  set_property -dict [list \
    CONFIG.c_include_s2mm {0} \
    CONFIG.c_include_sg {0} \
    CONFIG.c_sg_length_width {26} \
  ] $axi_dma_gen


  # Create instance: axi_dma_mr, and set properties
  set axi_dma_mr [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma_mr ]
  set_property -dict [list \
    CONFIG.c_include_mm2s {0} \
    CONFIG.c_include_sg {0} \
    CONFIG.c_sg_length_width {26} \
  ] $axi_dma_mr


  # Create instance: axi_dma_tproc, and set properties
  set axi_dma_tproc [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma_tproc ]
  set_property -dict [list \
    CONFIG.c_include_sg {0} \
    CONFIG.c_m_axi_mm2s_data_width {256} \
    CONFIG.c_m_axis_mm2s_tdata_width {256} \
    CONFIG.c_mm2s_burst_size {2} \
    CONFIG.c_sg_length_width {26} \
  ] $axi_dma_tproc


  # Create instance: axi_smc, and set properties
  set axi_smc [ create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 axi_smc ]
  set_property CONFIG.NUM_SI {7} $axi_smc


  # Create instance: axis_broadcaster_0, and set properties
  set axis_broadcaster_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_broadcaster:1.1 axis_broadcaster_0 ]
  set_property CONFIG.HAS_TREADY {0} $axis_broadcaster_0


  # Create instance: axis_broadcaster_1, and set properties
  set axis_broadcaster_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_broadcaster:1.1 axis_broadcaster_1 ]
  set_property CONFIG.HAS_TREADY {0} $axis_broadcaster_1


  # Create instance: axis_cc_avg_0, and set properties
  set axis_cc_avg_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_clock_converter:1.1 axis_cc_avg_0 ]

  # Create instance: axis_cc_avg_1, and set properties
  set axis_cc_avg_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_clock_converter:1.1 axis_cc_avg_1 ]

  # Create instance: axis_register_slice_2, and set properties
  set axis_register_slice_2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_register_slice:1.1 axis_register_slice_2 ]
  set_property CONFIG.REG_CONFIG {8} $axis_register_slice_2


  # Create instance: axis_register_slice_3, and set properties
  set axis_register_slice_3 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_register_slice:1.1 axis_register_slice_3 ]
  set_property CONFIG.REG_CONFIG {8} $axis_register_slice_3


  # Create instance: axis_switch_avg, and set properties
  set axis_switch_avg [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_switch:1.1 axis_switch_avg ]
  set_property -dict [list \
    CONFIG.NUM_SI {3} \
    CONFIG.ROUTING_MODE {1} \
  ] $axis_switch_avg


  # Create instance: axis_switch_buf, and set properties
  set axis_switch_buf [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_switch:1.1 axis_switch_buf ]
  set_property -dict [list \
    CONFIG.NUM_SI {3} \
    CONFIG.ROUTING_MODE {1} \
  ] $axis_switch_buf


  # Create instance: axis_switch_ddr4, and set properties
  set axis_switch_ddr4 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_switch:1.1 axis_switch_ddr4 ]
  set_property -dict [list \
    CONFIG.NUM_SI {3} \
    CONFIG.ROUTING_MODE {1} \
  ] $axis_switch_ddr4


  # Create instance: axis_switch_gen, and set properties
  set axis_switch_gen [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_switch:1.1 axis_switch_gen ]
  set_property -dict [list \
    CONFIG.DECODER_REG {1} \
    CONFIG.NUM_MI {3} \
    CONFIG.NUM_SI {1} \
    CONFIG.ROUTING_MODE {1} \
  ] $axis_switch_gen


  # Create instance: axis_switch_mr, and set properties
  set axis_switch_mr [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_switch:1.1 axis_switch_mr ]
  set_property -dict [list \
    CONFIG.NUM_SI {3} \
    CONFIG.ROUTING_MODE {1} \
  ] $axis_switch_mr


  # Create instance: clk_adc0_x2, and set properties
  set clk_adc0_x2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_adc0_x2 ]
  set_property -dict [list \
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
    CONFIG.PRIM_SOURCE {Global_buffer} \
    CONFIG.RESET_PORT {resetn} \
    CONFIG.RESET_TYPE {ACTIVE_LOW} \
  ] $clk_adc0_x2


  # Create instance: clk_core, and set properties
  set clk_core [ create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_core ]
  set_property -dict [list \
    CONFIG.CLKIN1_JITTER_PS {20.339999999999996} \
    CONFIG.CLKOUT1_JITTER {85.052} \
    CONFIG.CLKOUT1_PHASE_ERROR {77.902} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {245.76} \
    CONFIG.MMCM_CLKFBOUT_MULT_F {4.875} \
    CONFIG.MMCM_CLKIN1_PERIOD {2.034} \
    CONFIG.MMCM_CLKIN2_PERIOD {10.0} \
    CONFIG.MMCM_CLKOUT0_DIVIDE_F {4.875} \
    CONFIG.MMCM_DIVCLK_DIVIDE {2} \
    CONFIG.OPTIMIZE_CLOCKING_STRUCTURE_EN {true} \
    CONFIG.PRIM_SOURCE {Global_buffer} \
    CONFIG.RESET_PORT {resetn} \
    CONFIG.RESET_TYPE {ACTIVE_LOW} \
  ] $clk_core


  # Create instance: ps8_0_axi_periph, and set properties
  set ps8_0_axi_periph [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 ps8_0_axi_periph ]
  set_property CONFIG.NUM_MI {22} $ps8_0_axi_periph


  # Create instance: usp_rf_data_converter_0, and set properties
  set usp_rf_data_converter_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:usp_rf_data_converter:2.6 usp_rf_data_converter_0 ]
  set_property -dict [list \
    CONFIG.ADC0_Outclk_Freq {276.480} \
    CONFIG.ADC0_PLL_Enable {true} \
    CONFIG.ADC0_Refclk_Freq {491.520} \
    CONFIG.ADC0_Sampling_Rate {4.42368} \
    CONFIG.ADC2_Outclk_Freq {276.480} \
    CONFIG.ADC2_PLL_Enable {true} \
    CONFIG.ADC2_Refclk_Freq {491.520} \
    CONFIG.ADC2_Sampling_Rate {4.42368} \
    CONFIG.ADC_Coarse_Mixer_Freq02 {3} \
    CONFIG.ADC_Data_Width00 {8} \
    CONFIG.ADC_Data_Width02 {8} \
    CONFIG.ADC_Decimation_Mode02 {1} \
    CONFIG.ADC_Mixer_Type02 {1} \
    CONFIG.ADC_Slice02_Enable {true} \
    CONFIG.ADC_Slice20_Enable {true} \
    CONFIG.ADC_Slice22_Enable {true} \
    CONFIG.DAC0_Outclk_Freq {491.520} \
    CONFIG.DAC0_PLL_Enable {true} \
    CONFIG.DAC0_Refclk_Freq {491.520} \
    CONFIG.DAC0_Sampling_Rate {7.86432} \
    CONFIG.DAC2_Outclk_Freq {491.520} \
    CONFIG.DAC2_PLL_Enable {true} \
    CONFIG.DAC2_Refclk_Freq {491.520} \
    CONFIG.DAC2_Sampling_Rate {7.86432} \
    CONFIG.DAC_Coarse_Mixer_Freq00 {3} \
    CONFIG.DAC_Coarse_Mixer_Freq20 {3} \
    CONFIG.DAC_Interpolation_Mode00 {1} \
    CONFIG.DAC_Interpolation_Mode20 {1} \
    CONFIG.DAC_Mixer_Type00 {1} \
    CONFIG.DAC_Mixer_Type20 {1} \
    CONFIG.DAC_Mode00 {3} \
    CONFIG.DAC_Mode20 {3} \
    CONFIG.DAC_Slice00_Enable {true} \
    CONFIG.DAC_Slice20_Enable {true} \
  ] $usp_rf_data_converter_0


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
    CONFIG.PSU_MIO_34_DRIVE_STRENGTH {12} \
    CONFIG.PSU_MIO_34_INPUT_TYPE {cmos} \
    CONFIG.PSU_MIO_34_POLARITY {Default} \
    CONFIG.PSU_MIO_34_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_34_SLEW {fast} \
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
    CONFIG.PSU_MIO_TREE_PERIPHERALS {SPI 0#SPI 0#SPI 0#SPI 0#SPI 0#SPI 0#SPI 1#GPIO0 MIO#GPIO0 MIO#SPI 1#SPI 1#SPI 1#GPIO0 MIO#SD 0#SD 0#SD 0#SD 0#GPIO0 MIO#I2C 0#I2C 0#GPIO0 MIO#SD 0#SD 0#GPIO0 MIO#SD\
0#SD 0#GPIO1 MIO#DPAUX#DPAUX#DPAUX#DPAUX#GPIO1 MIO#UART 1#UART 1#GPIO1 MIO#GPIO1 MIO#I2C 1#I2C 1#Gem 1#Gem 1#Gem 1#Gem 1#Gem 1#Gem 1#Gem 1#Gem 1#Gem 1#Gem 1#Gem 1#Gem 1#MDIO 1#MDIO 1#USB 0#USB 0#USB 0#USB\
0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 1#USB 1#USB 1#USB 1#USB 1#USB 1#USB 1#USB 1#USB 1#USB 1#USB 1#USB 1#GPIO2 MIO#GPIO2 MIO} \
    CONFIG.PSU_MIO_TREE_SIGNALS {sclk_out#n_ss_out[2]#n_ss_out[1]#n_ss_out[0]#miso#mosi#sclk_out#gpio0[7]#gpio0[8]#n_ss_out[0]#miso#mosi#gpio0[12]#sdio0_data_out[0]#sdio0_data_out[1]#sdio0_data_out[2]#sdio0_data_out[3]#gpio0[17]#scl_out#sda_out#gpio0[20]#sdio0_cmd_out#sdio0_clk_out#gpio0[23]#sdio0_cd_n#sdio0_wp#gpio1[26]#dp_aux_data_out#dp_hot_plug_detect#dp_aux_data_oe#dp_aux_data_in#gpio1[31]#txd#rxd#gpio1[34]#gpio1[35]#scl_out#sda_out#rgmii_tx_clk#rgmii_txd[0]#rgmii_txd[1]#rgmii_txd[2]#rgmii_txd[3]#rgmii_tx_ctl#rgmii_rx_clk#rgmii_rxd[0]#rgmii_rxd[1]#rgmii_rxd[2]#rgmii_rxd[3]#rgmii_rx_ctl#gem1_mdc#gem1_mdio_out#ulpi_clk_in#ulpi_dir#ulpi_tx_data[2]#ulpi_nxt#ulpi_tx_data[0]#ulpi_tx_data[1]#ulpi_stp#ulpi_tx_data[3]#ulpi_tx_data[4]#ulpi_tx_data[5]#ulpi_tx_data[6]#ulpi_tx_data[7]#ulpi_clk_in#ulpi_dir#ulpi_tx_data[2]#ulpi_nxt#ulpi_tx_data[0]#ulpi_tx_data[1]#ulpi_stp#ulpi_tx_data[3]#ulpi_tx_data[4]#ulpi_tx_data[5]#ulpi_tx_data[6]#ulpi_tx_data[7]#gpio2[76]#gpio2[77]}\
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
    CONFIG.PSU__AFI0_COHERENCY {0} \
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
    CONFIG.PSU__CRF_APB__DP_VIDEO_REF_CTRL__SRCSEL {DPLL} \
    CONFIG.PSU__CRF_APB__DP_VIDEO__FRAC_ENABLED {0} \
    CONFIG.PSU__CRF_APB__GDMA_REF_CTRL__ACT_FREQMHZ {599.999878} \
    CONFIG.PSU__CRF_APB__GDMA_REF_CTRL__FREQMHZ {600} \
    CONFIG.PSU__CRF_APB__GDMA_REF_CTRL__SRCSEL {DPLL} \
    CONFIG.PSU__CRF_APB__GPU_REF_CTRL__ACT_FREQMHZ {0} \
    CONFIG.PSU__CRF_APB__GPU_REF_CTRL__FREQMHZ {600} \
    CONFIG.PSU__CRF_APB__GPU_REF_CTRL__SRCSEL {DPLL} \
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
    CONFIG.PSU__MAXIGP1__DATA_WIDTH {128} \
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
    CONFIG.PSU__PROTECTION__FPD_SEGMENTS {SA:0xFD1A0000; SIZE:1280; UNIT:KB; RegionTZ:Secure; WrAllowed:Read/Write; subsystemId:PMU Firmware  |   SA:0xFD000000; SIZE:64; UNIT:KB; RegionTZ:Secure; WrAllowed:Read/Write;\
subsystemId:PMU Firmware  |   SA:0xFD010000; SIZE:64; UNIT:KB; RegionTZ:Secure; WrAllowed:Read/Write; subsystemId:PMU Firmware  |   SA:0xFD020000; SIZE:64; UNIT:KB; RegionTZ:Secure; WrAllowed:Read/Write;\
subsystemId:PMU Firmware  |   SA:0xFD030000; SIZE:64; UNIT:KB; RegionTZ:Secure; WrAllowed:Read/Write; subsystemId:PMU Firmware  |   SA:0xFD040000; SIZE:64; UNIT:KB; RegionTZ:Secure; WrAllowed:Read/Write;\
subsystemId:PMU Firmware  |   SA:0xFD050000; SIZE:64; UNIT:KB; RegionTZ:Secure; WrAllowed:Read/Write; subsystemId:PMU Firmware  |   SA:0xFD610000; SIZE:512; UNIT:KB; RegionTZ:Secure; WrAllowed:Read/Write;\
subsystemId:PMU Firmware  |   SA:0xFD5D0000; SIZE:64; UNIT:KB; RegionTZ:Secure; WrAllowed:Read/Write; subsystemId:PMU Firmware  |  SA:0xFD1A0000 ; SIZE:1280; UNIT:KB; RegionTZ:Secure ; WrAllowed:Read/Write;\
subsystemId:Secure Subsystem} \
    CONFIG.PSU__PROTECTION__LPD_SEGMENTS {SA:0xFF980000; SIZE:64; UNIT:KB; RegionTZ:Secure; WrAllowed:Read/Write; subsystemId:PMU Firmware| SA:0xFF5E0000; SIZE:2560; UNIT:KB; RegionTZ:Secure; WrAllowed:Read/Write;\
subsystemId:PMU Firmware| SA:0xFFCC0000; SIZE:64; UNIT:KB; RegionTZ:Secure; WrAllowed:Read/Write; subsystemId:PMU Firmware| SA:0xFF180000; SIZE:768; UNIT:KB; RegionTZ:Secure; WrAllowed:Read/Write; subsystemId:PMU\
Firmware| SA:0xFF410000; SIZE:640; UNIT:KB; RegionTZ:Secure; WrAllowed:Read/Write; subsystemId:PMU Firmware| SA:0xFFA70000; SIZE:64; UNIT:KB; RegionTZ:Secure; WrAllowed:Read/Write; subsystemId:PMU Firmware|\
SA:0xFF9A0000; SIZE:64; UNIT:KB; RegionTZ:Secure; WrAllowed:Read/Write; subsystemId:PMU Firmware|SA:0xFF5E0000 ; SIZE:2560; UNIT:KB; RegionTZ:Secure ; WrAllowed:Read/Write; subsystemId:Secure Subsystem|SA:0xFFCC0000\
; SIZE:64; UNIT:KB; RegionTZ:Secure ; WrAllowed:Read/Write; subsystemId:Secure Subsystem|SA:0xFF180000 ; SIZE:768; UNIT:KB; RegionTZ:Secure ; WrAllowed:Read/Write; subsystemId:Secure Subsystem|SA:0xFF9A0000\
; SIZE:64; UNIT:KB; RegionTZ:Secure ; WrAllowed:Read/Write; subsystemId:Secure Subsystem} \
    CONFIG.PSU__PROTECTION__MASTERS {USB1:NonSecure;1|USB0:NonSecure;1|S_AXI_LPD:NA;0|S_AXI_HPC1_FPD:NA;0|S_AXI_HPC0_FPD:NA;1|S_AXI_HP3_FPD:NA;0|S_AXI_HP2_FPD:NA;0|S_AXI_HP1_FPD:NA;0|S_AXI_HP0_FPD:NA;0|S_AXI_ACP:NA;0|S_AXI_ACE:NA;0|SD1:NonSecure;0|SD0:NonSecure;1|SATA1:NonSecure;0|SATA0:NonSecure;0|RPU1:Secure;1|RPU0:Secure;1|QSPI:NonSecure;0|PMU:NA;1|PCIe:NonSecure;0|NAND:NonSecure;0|LDMA:NonSecure;1|GPU:NonSecure;1|GEM3:NonSecure;0|GEM2:NonSecure;0|GEM1:NonSecure;1|GEM0:NonSecure;0|FDMA:NonSecure;1|DP:NonSecure;1|DAP:NA;1|Coresight:NA;1|CSU:NA;1|APU:NA;1}\
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
    CONFIG.PSU__SAXIGP0__DATA_WIDTH {128} \
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
    CONFIG.PSU__USE_DIFF_RW_CLK_GP0 {0} \
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


  # Create instance: mr_buffer_et_0, and set properties
  set mr_buffer_et_0 [ create_bd_cell -type ip -vlnv QICK:QICK:mr_buffer_et:1.1 mr_buffer_et_0 ]
  set_property -dict [list \
    CONFIG.B {32} \
    CONFIG.N {10} \
  ] $mr_buffer_et_0


  # Create instance: qick_processor_0, and set properties
  set qick_processor_0 [ create_bd_cell -type ip -vlnv QICK:QICK:qick_processor:2.0 qick_processor_0 ]
  set_property -dict [list \
    CONFIG.ARITH {1} \
    CONFIG.CUSTOM_PERIPH {1} \
    CONFIG.DEBUG {0} \
    CONFIG.DIVIDER {1} \
    CONFIG.DMEM_AW {14} \
    CONFIG.EXT_FLAG {0} \
    CONFIG.IN_PORT_QTY {3} \
    CONFIG.IO_CTRL {1} \
    CONFIG.LFSR {1} \
    CONFIG.OUT_DPORT_DW {8} \
    CONFIG.OUT_DPORT_QTY {1} \
    CONFIG.OUT_TRIG_QTY {14} \
    CONFIG.OUT_WPORT_QTY {5} \
    CONFIG.PMEM_AW {12} \
    CONFIG.WMEM_AW {10} \
  ] $qick_processor_0


  # Create instance: axis_register_slice_4, and set properties
  set axis_register_slice_4 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_register_slice:1.1 axis_register_slice_4 ]
  set_property CONFIG.REG_CONFIG {8} $axis_register_slice_4


  # Create instance: axis_dyn_readout_v1_2, and set properties
  set axis_dyn_readout_v1_2 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_dyn_readout_v1:1.0 axis_dyn_readout_v1_2 ]

  # Create instance: axis_broadcaster_2, and set properties
  set axis_broadcaster_2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_broadcaster:1.1 axis_broadcaster_2 ]
  set_property CONFIG.HAS_TREADY {0} $axis_broadcaster_2


  # Create instance: sg_translator_4, and set properties
  set sg_translator_4 [ create_bd_cell -type ip -vlnv QICK:QICK:sg_translator:1.0 sg_translator_4 ]
  set_property CONFIG.OUT_TYPE {3} $sg_translator_4


  # Create instance: axis_cc_avg_2, and set properties
  set axis_cc_avg_2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_clock_converter:1.1 axis_cc_avg_2 ]

  # Create instance: qick_time_tagger_0, and set properties
  set qick_time_tagger_0 [ create_bd_cell -type ip -vlnv QICK:QICK:qick_time_tagger:1.0 qick_time_tagger_0 ]
  set_property -dict [list \
    CONFIG.EXT_ARM {1} \
    CONFIG.SMP_FIFO_AW {14} \
    CONFIG.SMP_STORE {1} \
    CONFIG.TAG_FIFO_AW {12} \
  ] $qick_time_tagger_0


  # Create instance: axi_dma_tt, and set properties
  set axi_dma_tt [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma_tt ]
  set_property -dict [list \
    CONFIG.c_include_mm2s {0} \
    CONFIG.c_include_sg {0} \
    CONFIG.c_sg_length_width {18} \
  ] $axi_dma_tt


  # Create instance: axis_register_slice_5, and set properties
  set axis_register_slice_5 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_register_slice:1.1 axis_register_slice_5 ]
  set_property CONFIG.REG_CONFIG {8} $axis_register_slice_5


  # Create instance: axis_avg_buffer_0, and set properties
  set axis_avg_buffer_0 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_avg_buffer:1.2 axis_avg_buffer_0 ]
  set_property -dict [list \
    CONFIG.N_AVG {14} \
    CONFIG.N_BUF {14} \
  ] $axis_avg_buffer_0


  # Create instance: axis_avg_buffer_1, and set properties
  set axis_avg_buffer_1 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_avg_buffer:1.2 axis_avg_buffer_1 ]
  set_property -dict [list \
    CONFIG.N_AVG {14} \
    CONFIG.N_BUF {14} \
  ] $axis_avg_buffer_1


  # Create instance: axis_weighted_buffer_0, and set properties
  set axis_weighted_buffer_0 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_weighted_buffer:1.3 axis_weighted_buffer_0 ]
  set_property -dict [list \
    CONFIG.N_AVG {14} \
    CONFIG.N_WGT {12} \
  ] $axis_weighted_buffer_0


  # Create interface connections
  connect_bd_intf_net -intf_net adc0_clk_1 [get_bd_intf_ports adc0_clk] [get_bd_intf_pins usp_rf_data_converter_0/adc0_clk]
  connect_bd_intf_net -intf_net adc2_clk_1 [get_bd_intf_ports adc2_clk] [get_bd_intf_pins usp_rf_data_converter_0/adc2_clk]
  connect_bd_intf_net -intf_net axi_dma_avg_M_AXI_S2MM [get_bd_intf_pins axi_dma_avg/M_AXI_S2MM] [get_bd_intf_pins axi_smc/S00_AXI]
  connect_bd_intf_net -intf_net axi_dma_buf_M_AXI_S2MM [get_bd_intf_pins axi_dma_buf/M_AXI_S2MM] [get_bd_intf_pins axi_smc/S01_AXI]
  connect_bd_intf_net -intf_net axi_dma_gen_M_AXIS_MM2S [get_bd_intf_pins axi_dma_gen/M_AXIS_MM2S] [get_bd_intf_pins axis_switch_gen/S00_AXIS]
  connect_bd_intf_net -intf_net axi_dma_gen_M_AXI_MM2S [get_bd_intf_pins axi_dma_gen/M_AXI_MM2S] [get_bd_intf_pins axi_smc/S03_AXI]
  connect_bd_intf_net -intf_net axi_dma_readout_M_AXI_S2MM [get_bd_intf_pins axi_dma_mr/M_AXI_S2MM] [get_bd_intf_pins axi_smc/S02_AXI]
  connect_bd_intf_net -intf_net axi_dma_tproc_M_AXIS_MM2S [get_bd_intf_pins axi_dma_tproc/M_AXIS_MM2S] [get_bd_intf_pins qick_processor_0/s_dma_axis_i]
  connect_bd_intf_net -intf_net axi_dma_tproc_M_AXI_MM2S [get_bd_intf_pins axi_dma_tproc/M_AXI_MM2S] [get_bd_intf_pins axi_smc/S04_AXI]
  connect_bd_intf_net -intf_net axi_dma_tproc_M_AXI_S2MM [get_bd_intf_pins axi_dma_tproc/M_AXI_S2MM] [get_bd_intf_pins axi_smc/S05_AXI]
  connect_bd_intf_net -intf_net axi_dma_tt_M_AXI_S2MM [get_bd_intf_pins axi_dma_tt/M_AXI_S2MM] [get_bd_intf_pins axi_smc/S06_AXI]
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
  connect_bd_intf_net -intf_net axis_broadcaster_2_M00_AXIS [get_bd_intf_pins axis_weighted_buffer_0/s_axis] [get_bd_intf_pins axis_broadcaster_2/M00_AXIS]
  connect_bd_intf_net -intf_net axis_broadcaster_2_M01_AXIS [get_bd_intf_pins axis_switch_ddr4/S02_AXIS] [get_bd_intf_pins axis_broadcaster_2/M01_AXIS]
  connect_bd_intf_net -intf_net axis_cc_avg_0_M_AXIS [get_bd_intf_pins axis_cc_avg_0/M_AXIS] [get_bd_intf_pins qick_processor_0/s0_axis]
  connect_bd_intf_net -intf_net axis_cc_avg_1_M_AXIS [get_bd_intf_pins axis_cc_avg_1/M_AXIS] [get_bd_intf_pins qick_processor_0/s1_axis]
  connect_bd_intf_net -intf_net axis_cc_avg_2_M_AXIS [get_bd_intf_pins axis_cc_avg_2/M_AXIS] [get_bd_intf_pins qick_processor_0/s2_axis]
  connect_bd_intf_net -intf_net axis_cdcsync_v1_0_m0_axis [get_bd_intf_pins axis_cdcsync_v1_0/m0_axis] [get_bd_intf_pins sg_translator_2/s_tproc_axis]
  connect_bd_intf_net -intf_net axis_cdcsync_v1_0_m1_axis [get_bd_intf_pins axis_cdcsync_v1_0/m1_axis] [get_bd_intf_pins sg_translator_3/s_tproc_axis]
  connect_bd_intf_net -intf_net axis_cdcsync_v1_0_m2_axis [get_bd_intf_pins axis_cdcsync_v1_0/m2_axis] [get_bd_intf_pins sg_translator_4/s_tproc_axis]
  connect_bd_intf_net -intf_net axis_dyn_readout_v1_0_m0_axis [get_bd_intf_pins axis_dyn_readout_v1_0/m0_axis] [get_bd_intf_pins axis_switch_mr/S00_AXIS]
  connect_bd_intf_net -intf_net axis_dyn_readout_v1_0_m1_axis [get_bd_intf_pins axis_broadcaster_0/S_AXIS] [get_bd_intf_pins axis_dyn_readout_v1_0/m1_axis]
  connect_bd_intf_net -intf_net axis_dyn_readout_v1_1_m0_axis [get_bd_intf_pins axis_dyn_readout_v1_1/m0_axis] [get_bd_intf_pins axis_switch_mr/S01_AXIS]
  connect_bd_intf_net -intf_net axis_dyn_readout_v1_1_m1_axis [get_bd_intf_pins axis_broadcaster_1/S_AXIS] [get_bd_intf_pins axis_dyn_readout_v1_1/m1_axis]
  connect_bd_intf_net -intf_net axis_dyn_readout_v1_2_m0_axis [get_bd_intf_pins axis_switch_mr/S02_AXIS] [get_bd_intf_pins axis_dyn_readout_v1_2/m0_axis]
  connect_bd_intf_net -intf_net axis_dyn_readout_v1_2_m1_axis [get_bd_intf_pins axis_dyn_readout_v1_2/m1_axis] [get_bd_intf_pins axis_broadcaster_2/S_AXIS]
  connect_bd_intf_net -intf_net axis_register_slice_2_M_AXIS [get_bd_intf_pins axis_dyn_readout_v1_0/s1_axis] [get_bd_intf_pins axis_register_slice_2/M_AXIS]
  connect_bd_intf_net -intf_net axis_register_slice_3_M_AXIS [get_bd_intf_pins axis_dyn_readout_v1_1/s1_axis] [get_bd_intf_pins axis_register_slice_3/M_AXIS]
  connect_bd_intf_net -intf_net axis_register_slice_4_M_AXIS1 [get_bd_intf_pins axis_register_slice_4/M_AXIS] [get_bd_intf_pins axis_dyn_readout_v1_2/s1_axis]
  connect_bd_intf_net -intf_net axis_register_slice_4_m_axis [get_bd_intf_pins axis_register_slice_1/m_axis] [get_bd_intf_pins usp_rf_data_converter_0/s20_axis]
  connect_bd_intf_net -intf_net axis_register_slice_5_M_AXIS [get_bd_intf_pins axis_register_slice_5/M_AXIS] [get_bd_intf_pins qick_time_tagger_0/s0_axis_adc0]
  connect_bd_intf_net -intf_net axis_register_slice_6_m_axis [get_bd_intf_pins axis_register_slice_0/m_axis] [get_bd_intf_pins usp_rf_data_converter_0/s00_axis]
  connect_bd_intf_net -intf_net axis_signal_gen_v6_0_m_axis [get_bd_intf_pins axis_register_slice_0/s_axis] [get_bd_intf_pins axis_signal_gen_v6_0/m_axis]
  connect_bd_intf_net -intf_net axis_signal_gen_v6_1_m_axis [get_bd_intf_pins axis_register_slice_1/s_axis] [get_bd_intf_pins axis_signal_gen_v6_1/m_axis]
  connect_bd_intf_net -intf_net axis_switch_0_M00_AXIS [get_bd_intf_pins axis_switch_mr/M00_AXIS] [get_bd_intf_pins mr_buffer_et_0/s00_axis]
  connect_bd_intf_net -intf_net axis_switch_avg_M00_AXIS [get_bd_intf_pins axi_dma_avg/S_AXIS_S2MM] [get_bd_intf_pins axis_switch_avg/M00_AXIS]
  connect_bd_intf_net -intf_net axis_switch_buf_M00_AXIS [get_bd_intf_pins axi_dma_buf/S_AXIS_S2MM] [get_bd_intf_pins axis_switch_buf/M00_AXIS]
  connect_bd_intf_net -intf_net axis_switch_ddr4_M00_AXIS [get_bd_intf_pins ddr4/S_AXIS] [get_bd_intf_pins axis_switch_ddr4/M00_AXIS]
  connect_bd_intf_net -intf_net axis_switch_gen_M00_AXIS [get_bd_intf_pins axis_signal_gen_v6_0/s0_axis] [get_bd_intf_pins axis_switch_gen/M00_AXIS]
  connect_bd_intf_net -intf_net axis_switch_gen_M01_AXIS [get_bd_intf_pins axis_signal_gen_v6_1/s0_axis] [get_bd_intf_pins axis_switch_gen/M01_AXIS]
  connect_bd_intf_net -intf_net axis_switch_gen_M02_AXIS [get_bd_intf_pins axis_weighted_buffer_0/s1_axis_weights] [get_bd_intf_pins axis_switch_gen/M02_AXIS]
  connect_bd_intf_net -intf_net axis_weighted_buffer_0_m0_axis [get_bd_intf_pins axis_switch_avg/S02_AXIS] [get_bd_intf_pins axis_weighted_buffer_0/m0_axis]
  connect_bd_intf_net -intf_net axis_weighted_buffer_0_m1_axis [get_bd_intf_pins axis_switch_buf/S02_AXIS] [get_bd_intf_pins axis_weighted_buffer_0/m1_axis]
  connect_bd_intf_net -intf_net axis_weighted_buffer_0_m2_axis [get_bd_intf_pins axis_cc_avg_2/S_AXIS] [get_bd_intf_pins axis_weighted_buffer_0/m2_axis]
  connect_bd_intf_net -intf_net dac0_clk_1 [get_bd_intf_ports dac0_clk] [get_bd_intf_pins usp_rf_data_converter_0/dac0_clk]
  connect_bd_intf_net -intf_net dac2_clk_1 [get_bd_intf_ports dac2_clk] [get_bd_intf_pins usp_rf_data_converter_0/dac2_clk]
  connect_bd_intf_net -intf_net ddr4_0_C0_DDR4 [get_bd_intf_ports ddr4_pl] [get_bd_intf_pins ddr4/ddr4_pl]
  connect_bd_intf_net -intf_net mr_buffer_et_0_m00_axis [get_bd_intf_pins axi_dma_mr/S_AXIS_S2MM] [get_bd_intf_pins mr_buffer_et_0/m00_axis]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M00_AXI [get_bd_intf_pins axi_dma_avg/S_AXI_LITE] [get_bd_intf_pins ps8_0_axi_periph/M00_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M01_AXI [get_bd_intf_pins axi_dma_buf/S_AXI_LITE] [get_bd_intf_pins ps8_0_axi_periph/M01_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M02_AXI [get_bd_intf_pins axi_dma_mr/S_AXI_LITE] [get_bd_intf_pins ps8_0_axi_periph/M02_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M03_AXI [get_bd_intf_pins axis_avg_buffer_1/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M03_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M04_AXI [get_bd_intf_pins ps8_0_axi_periph/M04_AXI] [get_bd_intf_pins axi_dma_tt/S_AXI_LITE]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M05_AXI [get_bd_intf_pins ps8_0_axi_periph/M05_AXI] [get_bd_intf_pins axis_weighted_buffer_0/s_axi]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M06_AXI [get_bd_intf_pins axis_switch_avg/S_AXI_CTRL] [get_bd_intf_pins ps8_0_axi_periph/M06_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M07_AXI [get_bd_intf_pins axis_switch_buf/S_AXI_CTRL] [get_bd_intf_pins ps8_0_axi_periph/M07_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M08_AXI [get_bd_intf_pins axis_switch_mr/S_AXI_CTRL] [get_bd_intf_pins ps8_0_axi_periph/M08_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M09_AXI [get_bd_intf_pins ps8_0_axi_periph/M09_AXI] [get_bd_intf_pins qick_processor_0/s_axi]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M10_AXI [get_bd_intf_pins mr_buffer_et_0/s00_axi] [get_bd_intf_pins ps8_0_axi_periph/M10_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M11_AXI [get_bd_intf_pins ps8_0_axi_periph/M11_AXI] [get_bd_intf_pins usp_rf_data_converter_0/s_axi]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M12_AXI [get_bd_intf_pins axis_avg_buffer_0/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M12_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M13_AXI [get_bd_intf_pins axis_signal_gen_v6_0/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M13_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M14_AXI [get_bd_intf_pins axis_signal_gen_v6_1/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M14_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M15_AXI [get_bd_intf_pins axi_dma_gen/S_AXI_LITE] [get_bd_intf_pins ps8_0_axi_periph/M15_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M16_AXI [get_bd_intf_pins axis_switch_gen/S_AXI_CTRL] [get_bd_intf_pins ps8_0_axi_periph/M16_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M17_AXI [get_bd_intf_pins axi_dma_tproc/S_AXI_LITE] [get_bd_intf_pins ps8_0_axi_periph/M17_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M18_AXI [get_bd_intf_pins axis_switch_ddr4/S_AXI_CTRL] [get_bd_intf_pins ps8_0_axi_periph/M18_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M19_AXI [get_bd_intf_pins axi_intc_0/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M19_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M20_AXI [get_bd_intf_pins ddr4/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M20_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M21_AXI [get_bd_intf_pins ps8_0_axi_periph/M21_AXI] [get_bd_intf_pins qick_time_tagger_0/s_axi]
  connect_bd_intf_net -intf_net qick_processor_0_QPeriphA [get_bd_intf_pins qick_time_tagger_0/qick_peripheral] [get_bd_intf_pins qick_processor_0/QPeriphA]
  connect_bd_intf_net -intf_net qick_processor_0_m0_axis [get_bd_intf_pins qick_processor_0/m0_axis] [get_bd_intf_pins sg_translator_0/s_tproc_axis]
  connect_bd_intf_net -intf_net qick_processor_0_m1_axis [get_bd_intf_pins qick_processor_0/m1_axis] [get_bd_intf_pins sg_translator_1/s_tproc_axis]
  connect_bd_intf_net -intf_net qick_processor_0_m2_axis [get_bd_intf_pins axis_cdcsync_v1_0/s0_axis] [get_bd_intf_pins qick_processor_0/m2_axis]
  connect_bd_intf_net -intf_net qick_processor_0_m3_axis [get_bd_intf_pins axis_cdcsync_v1_0/s1_axis] [get_bd_intf_pins qick_processor_0/m3_axis]
  connect_bd_intf_net -intf_net qick_processor_0_m4_axis [get_bd_intf_pins axis_cdcsync_v1_0/s2_axis] [get_bd_intf_pins qick_processor_0/m4_axis]
  connect_bd_intf_net -intf_net qick_processor_0_m_dma_axis_o [get_bd_intf_pins axi_dma_tproc/S_AXIS_S2MM] [get_bd_intf_pins qick_processor_0/m_dma_axis_o]
  connect_bd_intf_net -intf_net qick_time_tagger_0_m_axis_dma [get_bd_intf_pins qick_time_tagger_0/m_axis_dma] [get_bd_intf_pins axi_dma_tt/S_AXIS_S2MM]
  connect_bd_intf_net -intf_net sg_translator_0_m_gen_v6_axis [get_bd_intf_pins axis_signal_gen_v6_0/s1_axis] [get_bd_intf_pins sg_translator_0/m_gen_v6_axis]
  connect_bd_intf_net -intf_net sg_translator_1_m_gen_v6_axis [get_bd_intf_pins axis_signal_gen_v6_1/s1_axis] [get_bd_intf_pins sg_translator_1/m_gen_v6_axis]
  connect_bd_intf_net -intf_net sg_translator_2_m_readout_v3_axis [get_bd_intf_pins axis_dyn_readout_v1_0/s0_axis] [get_bd_intf_pins sg_translator_2/m_readout_v3_axis]
  connect_bd_intf_net -intf_net sg_translator_3_m_readout_v3_axis [get_bd_intf_pins axis_dyn_readout_v1_1/s0_axis] [get_bd_intf_pins sg_translator_3/m_readout_v3_axis]
  connect_bd_intf_net -intf_net sg_translator_4_m_readout_v3_axis [get_bd_intf_pins sg_translator_4/m_readout_v3_axis] [get_bd_intf_pins axis_dyn_readout_v1_2/s0_axis]
  connect_bd_intf_net -intf_net sys_clk_ddr4_1 [get_bd_intf_ports sys_clk_ddr4] [get_bd_intf_pins ddr4/sys_clk_ddr4]
  connect_bd_intf_net -intf_net sysref_in_1 [get_bd_intf_ports sysref_in] [get_bd_intf_pins usp_rf_data_converter_0/sysref_in]
  connect_bd_intf_net -intf_net usp_rf_data_converter_0_m00_axis [get_bd_intf_pins axis_register_slice_2/S_AXIS] [get_bd_intf_pins usp_rf_data_converter_0/m00_axis]
  connect_bd_intf_net -intf_net usp_rf_data_converter_0_m02_axis [get_bd_intf_pins axis_register_slice_3/S_AXIS] [get_bd_intf_pins usp_rf_data_converter_0/m02_axis]
  connect_bd_intf_net -intf_net usp_rf_data_converter_0_m20_axis [get_bd_intf_pins usp_rf_data_converter_0/m20_axis] [get_bd_intf_pins axis_register_slice_4/S_AXIS]
  connect_bd_intf_net -intf_net usp_rf_data_converter_0_m22_axis [get_bd_intf_pins axis_register_slice_5/S_AXIS] [get_bd_intf_pins usp_rf_data_converter_0/m22_axis]
  connect_bd_intf_net -intf_net usp_rf_data_converter_0_vout00 [get_bd_intf_ports vout00] [get_bd_intf_pins usp_rf_data_converter_0/vout00]
  connect_bd_intf_net -intf_net usp_rf_data_converter_0_vout20 [get_bd_intf_ports vout20] [get_bd_intf_pins usp_rf_data_converter_0/vout20]
  connect_bd_intf_net -intf_net vin0_01_1 [get_bd_intf_ports vin0_01] [get_bd_intf_pins usp_rf_data_converter_0/vin0_01]
  connect_bd_intf_net -intf_net vin0_23_1 [get_bd_intf_ports vin0_23] [get_bd_intf_pins usp_rf_data_converter_0/vin0_23]
  connect_bd_intf_net -intf_net vin2_01_1 [get_bd_intf_ports vin2_01] [get_bd_intf_pins usp_rf_data_converter_0/vin2_01]
  connect_bd_intf_net -intf_net vin2_23_1 [get_bd_intf_ports vin2_23] [get_bd_intf_pins usp_rf_data_converter_0/vin2_23]
  connect_bd_intf_net -intf_net zynq_ultra_ps_e_0_M_AXI_HPM0_FPD [get_bd_intf_pins ps8_0_axi_periph/S00_AXI] [get_bd_intf_pins zynq_ultra_ps_e_0/M_AXI_HPM0_FPD]
  connect_bd_intf_net -intf_net zynq_ultra_ps_e_0_M_AXI_HPM1_FPD [get_bd_intf_pins ddr4/S00_AXI] [get_bd_intf_pins zynq_ultra_ps_e_0/M_AXI_HPM1_FPD]

  # Create port connections
  connect_bd_net -net PMOD1_0_1 [get_bd_ports PMOD1_0] [get_bd_pins qick_processor_0/proc_start_i]
  connect_bd_net -net axi_dma_avg_s2mm_introut [get_bd_pins axi_dma_avg/s2mm_introut] [get_bd_pins xlconcat_intc/In3]
  connect_bd_net -net axi_dma_buf_s2mm_introut [get_bd_pins axi_dma_buf/s2mm_introut] [get_bd_pins xlconcat_intc/In4]
  connect_bd_net -net axi_dma_gen_mm2s_introut [get_bd_pins axi_dma_gen/mm2s_introut] [get_bd_pins xlconcat_intc/In0]
  connect_bd_net -net axi_dma_readout_s2mm_introut [get_bd_pins axi_dma_mr/s2mm_introut] [get_bd_pins xlconcat_intc/In5]
  connect_bd_net -net axi_dma_tproc_mm2s_introut [get_bd_pins axi_dma_tproc/mm2s_introut] [get_bd_pins xlconcat_intc/In1]
  connect_bd_net -net axi_dma_tproc_s2mm_introut [get_bd_pins axi_dma_tproc/s2mm_introut] [get_bd_pins xlconcat_intc/In2]
  connect_bd_net -net axi_dma_tt_s2mm_introut [get_bd_pins axi_dma_tt/s2mm_introut] [get_bd_pins xlconcat_intc/In7]
  connect_bd_net -net axi_intc_0_irq [get_bd_pins axi_intc_0/irq] [get_bd_pins zynq_ultra_ps_e_0/pl_ps_irq0]
  connect_bd_net -net clk_adc0_x2_clk_out1 [get_bd_pins clk_adc0_x2/clk_out1] [get_bd_pins axis_cdcsync_v1_0/m_axis_aclk] [get_bd_pins axis_dyn_readout_v1_0/aclk] [get_bd_pins axis_dyn_readout_v1_1/aclk] [get_bd_pins rst_adc0_x2/slowest_sync_clk] [get_bd_pins sg_translator_2/aclk] [get_bd_pins sg_translator_3/aclk] [get_bd_pins ddr4/aclk] [get_bd_pins axis_broadcaster_0/aclk] [get_bd_pins axis_broadcaster_1/aclk] [get_bd_pins axis_register_slice_2/aclk] [get_bd_pins axis_register_slice_3/aclk] [get_bd_pins axis_switch_ddr4/aclk] [get_bd_pins axis_switch_mr/aclk] [get_bd_pins usp_rf_data_converter_0/m0_axis_aclk] [get_bd_pins mr_buffer_et_0/s00_axis_aclk] [get_bd_pins usp_rf_data_converter_0/m2_axis_aclk] [get_bd_pins axis_register_slice_4/aclk] [get_bd_pins axis_dyn_readout_v1_2/aclk] [get_bd_pins axis_broadcaster_2/aclk] [get_bd_pins sg_translator_4/aclk] [get_bd_pins qick_time_tagger_0/adc_clk] [get_bd_pins axis_register_slice_5/aclk] [get_bd_pins axis_avg_buffer_0/s_axis_aclk] [get_bd_pins axis_avg_buffer_1/s_axis_aclk] [get_bd_pins axis_weighted_buffer_0/s_axis_aclk]
  connect_bd_net -net clk_adc0_x2_locked [get_bd_pins clk_adc0_x2/locked] [get_bd_pins rst_adc0_x2/dcm_locked]
  connect_bd_net -net clk_tproc_clk_out1 [get_bd_pins clk_core/clk_out1] [get_bd_pins rst_core/slowest_sync_clk] [get_bd_pins axis_cc_avg_0/m_axis_aclk] [get_bd_pins axis_cc_avg_1/m_axis_aclk] [get_bd_pins qick_processor_0/c_clk_i] [get_bd_pins axis_cc_avg_2/m_axis_aclk] [get_bd_pins qick_time_tagger_0/c_clk]
  connect_bd_net -net clk_tproc_locked [get_bd_pins clk_core/locked] [get_bd_pins rst_core/dcm_locked]
  connect_bd_net -net ddr4_0_c0_ddr4_ui_clk [get_bd_pins ddr4/c0_ddr4_ui_clk] [get_bd_pins zynq_ultra_ps_e_0/maxihpm1_fpd_aclk]
  connect_bd_net -net qick_processor_0_trig_0_o [get_bd_pins qick_processor_0/trig_0_o] [get_bd_pins axis_avg_buffer_0/trigger]
  connect_bd_net -net qick_processor_0_trig_10_o [get_bd_pins qick_processor_0/trig_10_o] [get_bd_ports PMOD0_6]
  connect_bd_net -net qick_processor_0_trig_11_o [get_bd_pins qick_processor_0/trig_11_o] [get_bd_ports PMOD0_7]
  connect_bd_net -net qick_processor_0_trig_12_o [get_bd_pins qick_processor_0/trig_12_o] [get_bd_pins axis_weighted_buffer_0/trigger]
  connect_bd_net -net qick_processor_0_trig_13_o [get_bd_pins qick_processor_0/trig_13_o] [get_bd_pins qick_time_tagger_0/arm_i]
  connect_bd_net -net qick_processor_0_trig_1_o [get_bd_pins qick_processor_0/trig_1_o] [get_bd_pins axis_avg_buffer_1/trigger]
  connect_bd_net -net qick_processor_0_trig_2_o [get_bd_pins qick_processor_0/trig_2_o] [get_bd_pins mr_buffer_et_0/trigger]
  connect_bd_net -net qick_processor_0_trig_3_o [get_bd_pins qick_processor_0/trig_3_o] [get_bd_pins ddr4/trigger]
  connect_bd_net -net qick_processor_0_trig_4_o [get_bd_pins qick_processor_0/trig_4_o] [get_bd_ports PMOD0_0]
  connect_bd_net -net qick_processor_0_trig_5_o [get_bd_pins qick_processor_0/trig_5_o] [get_bd_ports PMOD0_1]
  connect_bd_net -net qick_processor_0_trig_6_o [get_bd_pins qick_processor_0/trig_6_o] [get_bd_ports PMOD0_2]
  connect_bd_net -net qick_processor_0_trig_7_o [get_bd_pins qick_processor_0/trig_7_o] [get_bd_ports PMOD0_3]
  connect_bd_net -net qick_processor_0_trig_8_o [get_bd_pins qick_processor_0/trig_8_o] [get_bd_ports PMOD0_4]
  connect_bd_net -net qick_processor_0_trig_9_o [get_bd_pins qick_processor_0/trig_9_o] [get_bd_ports PMOD0_5]
  connect_bd_net -net rst_100_bus_struct_reset [get_bd_pins rst_100/bus_struct_reset] [get_bd_pins ddr4/sys_rst]
  connect_bd_net -net rst_adc0_peripheral_aresetn [get_bd_pins rst_adc0/peripheral_aresetn] [get_bd_pins clk_adc0_x2/resetn]
  connect_bd_net -net rst_adc0_x2_peripheral_aresetn [get_bd_pins rst_adc0_x2/peripheral_aresetn] [get_bd_pins axis_cdcsync_v1_0/m_axis_aresetn] [get_bd_pins axis_dyn_readout_v1_0/aresetn] [get_bd_pins axis_dyn_readout_v1_1/aresetn] [get_bd_pins sg_translator_2/aresetn] [get_bd_pins sg_translator_3/aresetn] [get_bd_pins ddr4/aresetn] [get_bd_pins axis_broadcaster_0/aresetn] [get_bd_pins axis_broadcaster_1/aresetn] [get_bd_pins axis_register_slice_2/aresetn] [get_bd_pins axis_register_slice_3/aresetn] [get_bd_pins axis_switch_ddr4/aresetn] [get_bd_pins axis_switch_mr/aresetn] [get_bd_pins usp_rf_data_converter_0/m0_axis_aresetn] [get_bd_pins mr_buffer_et_0/s00_axis_aresetn] [get_bd_pins usp_rf_data_converter_0/m2_axis_aresetn] [get_bd_pins axis_register_slice_4/aresetn] [get_bd_pins axis_dyn_readout_v1_2/aresetn] [get_bd_pins axis_broadcaster_2/aresetn] [get_bd_pins sg_translator_4/aresetn] [get_bd_pins qick_time_tagger_0/adc_aresetn] [get_bd_pins axis_register_slice_5/aresetn] [get_bd_pins axis_avg_buffer_0/s_axis_aresetn] [get_bd_pins axis_avg_buffer_1/s_axis_aresetn] [get_bd_pins axis_weighted_buffer_0/s_axis_aresetn]
  connect_bd_net -net rst_dac1_peripheral_aresetn [get_bd_pins rst_dac2/peripheral_aresetn] [get_bd_pins axis_cdcsync_v1_0/s_axis_aresetn] [get_bd_pins axis_register_slice_0/aresetn] [get_bd_pins axis_register_slice_1/aresetn] [get_bd_pins axis_signal_gen_v6_0/aresetn] [get_bd_pins axis_signal_gen_v6_1/aresetn] [get_bd_pins sg_translator_0/aresetn] [get_bd_pins sg_translator_1/aresetn] [get_bd_pins usp_rf_data_converter_0/s0_axis_aresetn] [get_bd_pins usp_rf_data_converter_0/s2_axis_aresetn] [get_bd_pins qick_processor_0/t_resetn] [get_bd_pins clk_core/resetn]
  connect_bd_net -net rst_ps8_0_99M_peripheral_aresetn [get_bd_pins rst_100/peripheral_aresetn] [get_bd_pins axi_intc_0/s_axi_aresetn] [get_bd_pins axis_signal_gen_v6_0/s0_axis_aresetn] [get_bd_pins axis_signal_gen_v6_0/s_axi_aresetn] [get_bd_pins axis_signal_gen_v6_1/s0_axis_aresetn] [get_bd_pins axis_signal_gen_v6_1/s_axi_aresetn] [get_bd_pins ddr4/s_axi_aresetn] [get_bd_pins axi_dma_avg/axi_resetn] [get_bd_pins axi_dma_buf/axi_resetn] [get_bd_pins axi_dma_gen/axi_resetn] [get_bd_pins axi_dma_mr/axi_resetn] [get_bd_pins axi_dma_tproc/axi_resetn] [get_bd_pins axi_smc/aresetn] [get_bd_pins axis_cc_avg_0/s_axis_aresetn] [get_bd_pins axis_cc_avg_1/s_axis_aresetn] [get_bd_pins axis_switch_avg/aresetn] [get_bd_pins axis_switch_avg/s_axi_ctrl_aresetn] [get_bd_pins axis_switch_buf/aresetn] [get_bd_pins axis_switch_buf/s_axi_ctrl_aresetn] [get_bd_pins axis_switch_ddr4/s_axi_ctrl_aresetn] [get_bd_pins axis_switch_gen/aresetn] [get_bd_pins axis_switch_gen/s_axi_ctrl_aresetn] [get_bd_pins axis_switch_mr/s_axi_ctrl_aresetn] [get_bd_pins ps8_0_axi_periph/ARESETN] [get_bd_pins ps8_0_axi_periph/S00_ARESETN] [get_bd_pins ps8_0_axi_periph/M00_ARESETN] [get_bd_pins ps8_0_axi_periph/M01_ARESETN] [get_bd_pins ps8_0_axi_periph/M02_ARESETN] [get_bd_pins ps8_0_axi_periph/M03_ARESETN] [get_bd_pins ps8_0_axi_periph/M04_ARESETN] [get_bd_pins ps8_0_axi_periph/M05_ARESETN] [get_bd_pins ps8_0_axi_periph/M06_ARESETN] [get_bd_pins ps8_0_axi_periph/M07_ARESETN] [get_bd_pins ps8_0_axi_periph/M08_ARESETN] [get_bd_pins ps8_0_axi_periph/M09_ARESETN] [get_bd_pins ps8_0_axi_periph/M10_ARESETN] [get_bd_pins ps8_0_axi_periph/M11_ARESETN] [get_bd_pins ps8_0_axi_periph/M12_ARESETN] [get_bd_pins ps8_0_axi_periph/M13_ARESETN] [get_bd_pins ps8_0_axi_periph/M14_ARESETN] [get_bd_pins ps8_0_axi_periph/M15_ARESETN] [get_bd_pins ps8_0_axi_periph/M16_ARESETN] [get_bd_pins ps8_0_axi_periph/M17_ARESETN] [get_bd_pins ps8_0_axi_periph/M18_ARESETN] [get_bd_pins ps8_0_axi_periph/M19_ARESETN] [get_bd_pins ps8_0_axi_periph/M20_ARESETN] [get_bd_pins usp_rf_data_converter_0/s_axi_aresetn] [get_bd_pins mr_buffer_et_0/s00_axi_aresetn] [get_bd_pins mr_buffer_et_0/m00_axis_aresetn] [get_bd_pins qick_processor_0/ps_resetn] [get_bd_pins axis_cc_avg_2/s_axis_aresetn] [get_bd_pins qick_time_tagger_0/ps_aresetn] [get_bd_pins axi_dma_tt/axi_resetn] [get_bd_pins ps8_0_axi_periph/M21_ARESETN] [get_bd_pins axis_avg_buffer_0/s_axi_aresetn] [get_bd_pins axis_avg_buffer_0/m_axis_aresetn] [get_bd_pins axis_avg_buffer_1/s_axi_aresetn] [get_bd_pins axis_avg_buffer_1/m_axis_aresetn] [get_bd_pins axis_weighted_buffer_0/s_axi_aresetn] [get_bd_pins axis_weighted_buffer_0/m_axis_aresetn]
  connect_bd_net -net rst_tproc_peripheral_aresetn [get_bd_pins rst_core/peripheral_aresetn] [get_bd_pins axis_cc_avg_0/m_axis_aresetn] [get_bd_pins axis_cc_avg_1/m_axis_aresetn] [get_bd_pins qick_processor_0/c_resetn] [get_bd_pins axis_cc_avg_2/m_axis_aresetn] [get_bd_pins qick_time_tagger_0/c_aresetn]
  connect_bd_net -net usp_rf_data_converter_0_clk_adc0 [get_bd_pins usp_rf_data_converter_0/clk_adc0] [get_bd_pins rst_adc0/slowest_sync_clk] [get_bd_pins clk_adc0_x2/clk_in1]
  connect_bd_net -net usp_rf_data_converter_0_clk_dac2 [get_bd_pins usp_rf_data_converter_0/clk_dac2] [get_bd_pins axis_cdcsync_v1_0/s_axis_aclk] [get_bd_pins axis_register_slice_0/aclk] [get_bd_pins axis_register_slice_1/aclk] [get_bd_pins axis_signal_gen_v6_0/aclk] [get_bd_pins axis_signal_gen_v6_1/aclk] [get_bd_pins rst_dac2/slowest_sync_clk] [get_bd_pins sg_translator_0/aclk] [get_bd_pins sg_translator_1/aclk] [get_bd_pins usp_rf_data_converter_0/s0_axis_aclk] [get_bd_pins usp_rf_data_converter_0/s2_axis_aclk] [get_bd_pins qick_processor_0/t_clk_i] [get_bd_pins clk_core/clk_in1]
  connect_bd_net -net usp_rf_data_converter_0_irq [get_bd_pins usp_rf_data_converter_0/irq] [get_bd_pins xlconcat_intc/In6]
  connect_bd_net -net xlconcat_0_dout [get_bd_pins xlconcat_intc/dout] [get_bd_pins axi_intc_0/intr]
  connect_bd_net -net zynq_ultra_ps_e_0_pl_clk0 [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] [get_bd_pins axi_intc_0/s_axi_aclk] [get_bd_pins axis_signal_gen_v6_0/s0_axis_aclk] [get_bd_pins axis_signal_gen_v6_0/s_axi_aclk] [get_bd_pins axis_signal_gen_v6_1/s0_axis_aclk] [get_bd_pins axis_signal_gen_v6_1/s_axi_aclk] [get_bd_pins rst_100/slowest_sync_clk] [get_bd_pins ddr4/s_axi_aclk] [get_bd_pins axi_dma_avg/s_axi_lite_aclk] [get_bd_pins axi_dma_avg/m_axi_s2mm_aclk] [get_bd_pins axi_dma_buf/s_axi_lite_aclk] [get_bd_pins axi_dma_buf/m_axi_s2mm_aclk] [get_bd_pins axi_dma_gen/s_axi_lite_aclk] [get_bd_pins axi_dma_gen/m_axi_mm2s_aclk] [get_bd_pins axi_dma_mr/s_axi_lite_aclk] [get_bd_pins axi_dma_mr/m_axi_s2mm_aclk] [get_bd_pins axi_dma_tproc/s_axi_lite_aclk] [get_bd_pins axi_dma_tproc/m_axi_mm2s_aclk] [get_bd_pins axi_dma_tproc/m_axi_s2mm_aclk] [get_bd_pins axi_smc/aclk] [get_bd_pins axis_cc_avg_0/s_axis_aclk] [get_bd_pins axis_cc_avg_1/s_axis_aclk] [get_bd_pins axis_switch_avg/aclk] [get_bd_pins axis_switch_avg/s_axi_ctrl_aclk] [get_bd_pins axis_switch_buf/aclk] [get_bd_pins axis_switch_buf/s_axi_ctrl_aclk] [get_bd_pins axis_switch_ddr4/s_axi_ctrl_aclk] [get_bd_pins axis_switch_gen/aclk] [get_bd_pins axis_switch_gen/s_axi_ctrl_aclk] [get_bd_pins axis_switch_mr/s_axi_ctrl_aclk] [get_bd_pins ps8_0_axi_periph/ACLK] [get_bd_pins ps8_0_axi_periph/S00_ACLK] [get_bd_pins ps8_0_axi_periph/M00_ACLK] [get_bd_pins ps8_0_axi_periph/M01_ACLK] [get_bd_pins ps8_0_axi_periph/M02_ACLK] [get_bd_pins ps8_0_axi_periph/M03_ACLK] [get_bd_pins ps8_0_axi_periph/M04_ACLK] [get_bd_pins ps8_0_axi_periph/M05_ACLK] [get_bd_pins ps8_0_axi_periph/M06_ACLK] [get_bd_pins ps8_0_axi_periph/M07_ACLK] [get_bd_pins ps8_0_axi_periph/M08_ACLK] [get_bd_pins ps8_0_axi_periph/M09_ACLK] [get_bd_pins ps8_0_axi_periph/M10_ACLK] [get_bd_pins ps8_0_axi_periph/M11_ACLK] [get_bd_pins ps8_0_axi_periph/M12_ACLK] [get_bd_pins ps8_0_axi_periph/M13_ACLK] [get_bd_pins ps8_0_axi_periph/M14_ACLK] [get_bd_pins ps8_0_axi_periph/M15_ACLK] [get_bd_pins ps8_0_axi_periph/M16_ACLK] [get_bd_pins ps8_0_axi_periph/M17_ACLK] [get_bd_pins ps8_0_axi_periph/M18_ACLK] [get_bd_pins ps8_0_axi_periph/M19_ACLK] [get_bd_pins ps8_0_axi_periph/M20_ACLK] [get_bd_pins usp_rf_data_converter_0/s_axi_aclk] [get_bd_pins zynq_ultra_ps_e_0/maxihpm0_fpd_aclk] [get_bd_pins zynq_ultra_ps_e_0/saxihpc0_fpd_aclk] [get_bd_pins mr_buffer_et_0/s00_axi_aclk] [get_bd_pins mr_buffer_et_0/m00_axis_aclk] [get_bd_pins qick_processor_0/ps_clk_i] [get_bd_pins axis_cc_avg_2/s_axis_aclk] [get_bd_pins qick_time_tagger_0/ps_clk] [get_bd_pins axi_dma_tt/s_axi_lite_aclk] [get_bd_pins axi_dma_tt/m_axi_s2mm_aclk] [get_bd_pins ps8_0_axi_periph/M21_ACLK] [get_bd_pins axis_avg_buffer_0/s_axi_aclk] [get_bd_pins axis_avg_buffer_0/m_axis_aclk] [get_bd_pins axis_avg_buffer_1/s_axi_aclk] [get_bd_pins axis_avg_buffer_1/m_axis_aclk] [get_bd_pins axis_weighted_buffer_0/s_axi_aclk] [get_bd_pins axis_weighted_buffer_0/m_axis_aclk]
  connect_bd_net -net zynq_ultra_ps_e_0_pl_resetn0 [get_bd_pins zynq_ultra_ps_e_0/pl_resetn0] [get_bd_pins rst_100/ext_reset_in] [get_bd_pins rst_adc0/ext_reset_in] [get_bd_pins rst_adc0_x2/ext_reset_in] [get_bd_pins rst_core/ext_reset_in] [get_bd_pins rst_dac2/ext_reset_in]

  # Create address segments
  assign_bd_address -offset 0x00000000 -range 0x80000000 -target_address_space [get_bd_addr_spaces axi_dma_avg/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_DDR_LOW] -force
  assign_bd_address -offset 0x00000000 -range 0x80000000 -target_address_space [get_bd_addr_spaces axi_dma_buf/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_DDR_LOW] -force
  assign_bd_address -offset 0x00000000 -range 0x80000000 -target_address_space [get_bd_addr_spaces axi_dma_gen/Data_MM2S] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_DDR_LOW] -force
  assign_bd_address -offset 0x00000000 -range 0x80000000 -target_address_space [get_bd_addr_spaces axi_dma_mr/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_DDR_LOW] -force
  assign_bd_address -offset 0x00000000 -range 0x80000000 -target_address_space [get_bd_addr_spaces axi_dma_tproc/Data_MM2S] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_DDR_LOW] -force
  assign_bd_address -offset 0x00000000 -range 0x80000000 -target_address_space [get_bd_addr_spaces axi_dma_tproc/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_DDR_LOW] -force
  assign_bd_address -offset 0x000400200000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axi_dma_avg/S_AXI_LITE/Reg] -force
  assign_bd_address -offset 0x000400201000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axi_dma_buf/S_AXI_LITE/Reg] -force
  assign_bd_address -offset 0x000400202000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axi_dma_gen/S_AXI_LITE/Reg] -force
  assign_bd_address -offset 0x000400203000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axi_dma_mr/S_AXI_LITE/Reg] -force
  assign_bd_address -offset 0x000400204000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axi_dma_tproc/S_AXI_LITE/Reg] -force
  assign_bd_address -offset 0x000400213000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axi_dma_tt/S_AXI_LITE/Reg] -force
  assign_bd_address -offset 0x000400205000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axi_intc_0/S_AXI/Reg] -force
  assign_bd_address -offset 0x000400206000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_avg_buffer_0/s_axi/reg0] -force
  assign_bd_address -offset 0x000400207000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_avg_buffer_1/s_axi/reg0] -force
  assign_bd_address -offset 0x000400208000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs ddr4/axis_buffer_ddr_0/s_axi/reg0] -force
  assign_bd_address -offset 0x00040020B000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_signal_gen_v6_0/s_axi/reg0] -force
  assign_bd_address -offset 0x00040020C000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_signal_gen_v6_1/s_axi/reg0] -force
  assign_bd_address -offset 0x00040020D000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_switch_avg/S_AXI_CTRL/Reg] -force
  assign_bd_address -offset 0x00040020E000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_switch_buf/S_AXI_CTRL/Reg] -force
  assign_bd_address -offset 0x00040020F000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_switch_ddr4/S_AXI_CTRL/Reg] -force
  assign_bd_address -offset 0x000400210000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_switch_gen/S_AXI_CTRL/Reg] -force
  assign_bd_address -offset 0x000400211000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_switch_mr/S_AXI_CTRL/Reg] -force
  assign_bd_address -offset 0x000400214000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_weighted_buffer_0/s_axi/reg0] -force
  assign_bd_address -offset 0x000500000000 -range 0x000100000000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs ddr4/ddr4_0/C0_DDR4_MEMORY_MAP/C0_DDR4_ADDRESS_BLOCK] -force
  assign_bd_address -offset 0x000400212000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs mr_buffer_et_0/s00_axi/reg0] -force
  assign_bd_address -offset 0x000400010000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs qick_processor_0/s_axi/reg0] -force
  assign_bd_address -offset 0x000400215000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs qick_time_tagger_0/s_axi/reg0] -force
  assign_bd_address -offset 0x000400240000 -range 0x00040000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs usp_rf_data_converter_0/s_axi/Reg] -force
  assign_bd_address -offset 0x00000000 -range 0x80000000 -target_address_space [get_bd_addr_spaces axi_dma_tt/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_DDR_LOW] -force
  assign_bd_address -offset 0x00000000 -range 0x000100000000 -target_address_space [get_bd_addr_spaces ddr4/axis_buffer_ddr_0/m_axi] [get_bd_addr_segs ddr4/ddr4_0/C0_DDR4_MEMORY_MAP/C0_DDR4_ADDRESS_BLOCK] -force

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
  exclude_bd_addr_seg -offset 0x000800000000 -range 0x000100000000 -target_address_space [get_bd_addr_spaces axi_dma_tt/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_DDR_HIGH]
  exclude_bd_addr_seg -offset 0xFF000000 -range 0x01000000 -target_address_space [get_bd_addr_spaces axi_dma_tt/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_LPS_OCM]

  # Perform GUI Layout
  regenerate_bd_layout -layout_string {
   "ActiveEmotionalView":"Default View",
   "Default View_ScaleFactor":"0.254462",
   "Default View_TopLeft":"-428,-263",
   "Display-IntfAXI4Lite":"false",
   "Display-IntfAXIStream":"true",
   "ExpandedHierarchyInLayout":"",
   "guistr":"# # String gsaved with Nlview 7.5.8 2022-09-21 7111 VDI=41 GEI=38 GUI=JA:10.0 TLS
#  -string -flagsOSRD
preplace port adc0_clk -pg 1 -lvl 0 -x -50 -y 2630 -defaultsOSRD
preplace port dac0_clk -pg 1 -lvl 0 -x -50 -y 2670 -defaultsOSRD
preplace port dac2_clk -pg 1 -lvl 0 -x -50 -y 2690 -defaultsOSRD
preplace port ddr4_pl -pg 1 -lvl 10 -x 6370 -y 2870 -defaultsOSRD
preplace port sys_clk_ddr4 -pg 1 -lvl 10 -x 6370 -y 2760 -defaultsOSRD -right
preplace port sysref_in -pg 1 -lvl 0 -x -50 -y 2790 -defaultsOSRD
preplace port vin0_01 -pg 1 -lvl 0 -x -50 -y 2710 -defaultsOSRD
preplace port vin0_23 -pg 1 -lvl 0 -x -50 -y 2730 -defaultsOSRD
preplace port vout00 -pg 1 -lvl 10 -x 6370 -y 2290 -defaultsOSRD
preplace port vout20 -pg 1 -lvl 10 -x 6370 -y 2310 -defaultsOSRD
preplace port adc2_clk -pg 1 -lvl 0 -x -50 -y 2650 -defaultsOSRD
preplace port vin2_01 -pg 1 -lvl 0 -x -50 -y 2750 -defaultsOSRD
preplace port vin2_23 -pg 1 -lvl 0 -x -50 -y 2770 -defaultsOSRD
preplace port port-id_PMOD0_0 -pg 1 -lvl 0 -x -50 -y 2150 -defaultsOSRD -left
preplace port port-id_PMOD0_1 -pg 1 -lvl 0 -x -50 -y 2170 -defaultsOSRD -left
preplace port port-id_PMOD0_2 -pg 1 -lvl 0 -x -50 -y 2190 -defaultsOSRD -left
preplace port port-id_PMOD0_3 -pg 1 -lvl 0 -x -50 -y 2210 -defaultsOSRD -left
preplace port port-id_PMOD0_4 -pg 1 -lvl 0 -x -50 -y 2230 -defaultsOSRD -left
preplace port port-id_PMOD0_5 -pg 1 -lvl 0 -x -50 -y 2250 -defaultsOSRD -left
preplace port port-id_PMOD0_6 -pg 1 -lvl 0 -x -50 -y 2270 -defaultsOSRD -left
preplace port port-id_PMOD0_7 -pg 1 -lvl 0 -x -50 -y 2290 -defaultsOSRD -left
preplace port port-id_PMOD1_0 -pg 1 -lvl 0 -x -50 -y 2090 -defaultsOSRD
preplace inst axi_intc_0 -pg 1 -lvl 4 -x 2300 -y 130 -defaultsOSRD
preplace inst axis_cdcsync_v1_0 -pg 1 -lvl 3 -x 1800 -y 1470 -defaultsOSRD
preplace inst axis_dyn_readout_v1_0 -pg 1 -lvl 6 -x 3950 -y 1250 -defaultsOSRD
preplace inst axis_dyn_readout_v1_1 -pg 1 -lvl 6 -x 3950 -y 1620 -defaultsOSRD
preplace inst axis_register_slice_0 -pg 1 -lvl 4 -x 2300 -y 2120 -defaultsOSRD
preplace inst axis_register_slice_1 -pg 1 -lvl 4 -x 2300 -y 2360 -defaultsOSRD
preplace inst axis_signal_gen_v6_0 -pg 1 -lvl 3 -x 1800 -y 2110 -defaultsOSRD
preplace inst axis_signal_gen_v6_1 -pg 1 -lvl 3 -x 1800 -y 2370 -defaultsOSRD -resize 220 236
preplace inst rst_100 -pg 1 -lvl 5 -x 3110 -y 160 -defaultsOSRD
preplace inst rst_adc0 -pg 1 -lvl 5 -x 3110 -y 340 -defaultsOSRD
preplace inst rst_adc0_x2 -pg 1 -lvl 5 -x 3110 -y 720 -defaultsOSRD -resize 320 156
preplace inst rst_core -pg 1 -lvl 5 -x 3110 -y 1250 -defaultsOSRD -resize 320 156
preplace inst rst_dac2 -pg 1 -lvl 5 -x 3110 -y 920 -defaultsOSRD -resize 320 156
preplace inst sg_translator_0 -pg 1 -lvl 2 -x 1210 -y 2170 -defaultsOSRD
preplace inst sg_translator_1 -pg 1 -lvl 2 -x 1210 -y 2350 -defaultsOSRD
preplace inst sg_translator_2 -pg 1 -lvl 4 -x 2300 -y 1380 -defaultsOSRD
preplace inst sg_translator_3 -pg 1 -lvl 4 -x 2300 -y 1560 -defaultsOSRD
preplace inst xlconcat_intc -pg 1 -lvl 3 -x 1800 -y 160 -defaultsOSRD
preplace inst ddr4 -pg 1 -lvl 9 -x 6080 -y 2790 -defaultsOSRD
preplace inst axi_dma_avg -pg 1 -lvl 9 -x 6080 -y 1090 -defaultsOSRD
preplace inst axi_dma_buf -pg 1 -lvl 9 -x 6080 -y 1270 -defaultsOSRD -resize 320 156
preplace inst axi_dma_gen -pg 1 -lvl 1 -x 550 -y 1290 -defaultsOSRD
preplace inst axi_dma_mr -pg 1 -lvl 9 -x 6080 -y 2510 -defaultsOSRD -resize 320 156
preplace inst axi_dma_tproc -pg 1 -lvl 1 -x 550 -y 1520 -defaultsOSRD
preplace inst axi_smc -pg 1 -lvl 3 -x 1800 -y 470 -defaultsOSRD
preplace inst axis_broadcaster_0 -pg 1 -lvl 6 -x 3950 -y 1430 -defaultsOSRD
preplace inst axis_broadcaster_1 -pg 1 -lvl 6 -x 3950 -y 1780 -defaultsOSRD
preplace inst axis_cc_avg_0 -pg 1 -lvl 8 -x 5570 -y 1520 -defaultsOSRD
preplace inst axis_cc_avg_1 -pg 1 -lvl 8 -x 5570 -y 1700 -defaultsOSRD -resize 220 156
preplace inst axis_register_slice_2 -pg 1 -lvl 5 -x 3110 -y 1810 -defaultsOSRD -resize 180 116
preplace inst axis_register_slice_3 -pg 1 -lvl 5 -x 3110 -y 1970 -defaultsOSRD -resize 180 116
preplace inst axis_switch_avg -pg 1 -lvl 8 -x 5570 -y 1100 -defaultsOSRD -resize 240 196
preplace inst axis_switch_buf -pg 1 -lvl 8 -x 5570 -y 1320 -defaultsOSRD -resize 240 196
preplace inst axis_switch_ddr4 -pg 1 -lvl 7 -x 4710 -y 2820 -defaultsOSRD
preplace inst axis_switch_gen -pg 1 -lvl 2 -x 1210 -y 1320 -defaultsOSRD
preplace inst axis_switch_mr -pg 1 -lvl 7 -x 4710 -y 2560 -defaultsOSRD
preplace inst clk_adc0_x2 -pg 1 -lvl 5 -x 3110 -y 540 -defaultsOSRD
preplace inst clk_core -pg 1 -lvl 5 -x 3110 -y 1100 -defaultsOSRD -resize 160 96
preplace inst ps8_0_axi_periph -pg 1 -lvl 6 -x 3950 -y 560 -defaultsOSRD
preplace inst usp_rf_data_converter_0 -pg 1 -lvl 5 -x 3110 -y 2700 -defaultsOSRD
preplace inst zynq_ultra_ps_e_0 -pg 1 -lvl 5 -x 3110 -y -30 -defaultsOSRD
preplace inst mr_buffer_et_0 -pg 1 -lvl 8 -x 5570 -y 2570 -defaultsOSRD
preplace inst qick_processor_0 -pg 1 -lvl 1 -x 550 -y 2090 -defaultsOSRD
preplace inst axis_register_slice_4 -pg 1 -lvl 5 -x 3110 -y 2110 -defaultsOSRD -resize 180 116
preplace inst axis_dyn_readout_v1_2 -pg 1 -lvl 6 -x 3950 -y 1940 -defaultsOSRD -resize 320 158
preplace inst axis_broadcaster_2 -pg 1 -lvl 6 -x 3950 -y 2100 -defaultsOSRD -resize 280 116
preplace inst sg_translator_4 -pg 1 -lvl 4 -x 2300 -y 1740 -defaultsOSRD -resize 400 158
preplace inst axis_cc_avg_2 -pg 1 -lvl 8 -x 5570 -y 1880 -defaultsOSRD -resize 220 156
preplace inst qick_time_tagger_0 -pg 1 -lvl 6 -x 3950 -y 2580 -defaultsOSRD
preplace inst axi_dma_tt -pg 1 -lvl 6 -x 3950 -y 2840 -defaultsOSRD -resize 320 156
preplace inst axis_register_slice_5 -pg 1 -lvl 5 -x 3110 -y 2300 -defaultsOSRD
preplace inst axis_avg_buffer_0 -pg 1 -lvl 7 -x 4710 -y 1350 -defaultsOSRD
preplace inst axis_avg_buffer_1 -pg 1 -lvl 7 -x 4710 -y 1610 -defaultsOSRD -resize 220 236
preplace inst axis_weighted_buffer_0 -pg 1 -lvl 7 -x 4710 -y 1890 -defaultsOSRD
preplace netloc PMOD1_0_1 1 0 1 30 2080n
preplace netloc axi_dma_avg_s2mm_introut 1 2 8 1550 -250 NJ -250 NJ -250 NJ -250 NJ -250 NJ -250 NJ -250 6280
preplace netloc axi_dma_buf_s2mm_introut 1 2 8 1570 -230 NJ -230 NJ -230 NJ -230 NJ -230 NJ -230 NJ -230 6300
preplace netloc axi_dma_gen_mm2s_introut 1 1 2 760 90 NJ
preplace netloc axi_dma_readout_s2mm_introut 1 2 8 1590 -210 NJ -210 NJ -210 NJ -210 NJ -210 NJ -210 NJ -210 6320
preplace netloc axi_dma_tproc_mm2s_introut 1 1 2 780 110 NJ
preplace netloc axi_dma_tproc_s2mm_introut 1 1 2 800 130 NJ
preplace netloc axi_dma_tt_s2mm_introut 1 2 5 1610 -190 NJ -190 NJ -190 NJ -190 4180
preplace netloc axi_intc_0_irq 1 4 1 2590 0n
preplace netloc clk_adc0_x2_clk_out1 1 2 7 1610 1590 2070 1270 2690 620 3620 1120 4460 2440 5320 2440 5800
preplace netloc clk_adc0_x2_locked 1 4 2 2790 470 3440
preplace netloc clk_tproc_clk_out1 1 0 8 330 1200 NJ 1200 NJ 1200 NJ 1200 2760 1360 3670 1110 NJ 1110 5330
preplace netloc clk_tproc_locked 1 4 2 2800 1030 3440
preplace netloc ddr4_0_c0_ddr4_ui_clk 1 4 6 2800 -140 NJ -140 NJ -140 NJ -140 NJ -140 6260
preplace netloc qick_processor_0_trig_0_o 1 1 6 890 -150 NJ -150 NJ -150 NJ -150 NJ -150 4510J
preplace netloc qick_processor_0_trig_10_o 1 0 2 -20 2430 830J
preplace netloc qick_processor_0_trig_11_o 1 0 2 -30 2420 760J
preplace netloc qick_processor_0_trig_12_o 1 1 6 850J 2660 NJ 2660 NJ 2660 2540J 2420 NJ 2420 4510
preplace netloc qick_processor_0_trig_13_o 1 1 5 840J 2530 NJ 2530 NJ 2530 2530J 2440 3470
preplace netloc qick_processor_0_trig_1_o 1 1 6 960 820 NJ 820 NJ 820 NJ 820 3480J 1100 4500J
preplace netloc qick_processor_0_trig_2_o 1 1 7 990J 1850 NJ 1850 NJ 1850 2550J 1700 3660J 2430 NJ 2430 4910J
preplace netloc qick_processor_0_trig_3_o 1 1 8 1000J 1860 NJ 1860 NJ 1860 2540J 1690 3700J 2410 NJ 2410 NJ 2410 5810
preplace netloc qick_processor_0_trig_4_o 1 0 2 40 2360 820J
preplace netloc qick_processor_0_trig_5_o 1 0 2 30 2370 810J
preplace netloc qick_processor_0_trig_6_o 1 0 2 20 2380 800J
preplace netloc qick_processor_0_trig_7_o 1 0 2 10 2390 790J
preplace netloc qick_processor_0_trig_8_o 1 0 2 0 2400 780J
preplace netloc qick_processor_0_trig_9_o 1 0 2 -10 2410 770J
preplace netloc rst_100_bus_struct_reset 1 5 4 3670J 10 NJ 10 NJ 10 5870
preplace netloc rst_adc0_peripheral_aresetn 1 4 2 2800 450 3440
preplace netloc rst_adc0_x2_peripheral_aresetn 1 2 7 1600 1600 2080 1870 2730 1670 3630 1140 4400 2680 5360 2720 5780
preplace netloc rst_dac1_peripheral_aresetn 1 0 6 340 2440 1000 2450 1560 2520 2080J 2220 2710J 1020 3440
preplace netloc rst_ps8_0_99M_peripheral_aresetn 1 0 9 300 1380 880 1220 1540 1170 2080 1170 2660 1390 3690 20 4440 970 5300J 970 5860
preplace netloc rst_tproc_peripheral_aresetn 1 0 8 320 1820 NJ 1820 1440 1840 NJ 1840 2520 1680 3720 1150 NJ 1150 5320
preplace netloc usp_rf_data_converter_0_clk_adc0 1 4 2 2780 460 3460
preplace netloc usp_rf_data_converter_0_clk_dac2 1 0 6 290 2450 960 2460 1580 2510 2050 2230 2670 2960 3450
preplace netloc usp_rf_data_converter_0_irq 1 2 4 1590 2970 NJ 2970 NJ 2970 3440
preplace netloc xlconcat_0_dout 1 3 1 2010 150n
preplace netloc zynq_ultra_ps_e_0_pl_clk0 1 0 9 310 1190 970 1210 1530 30 2080 30 2700 610 3640 1130 4410 1140 5340J 980 5850
preplace netloc zynq_ultra_ps_e_0_pl_resetn0 1 4 2 2770 440 3460
preplace netloc adc0_clk_1 1 0 5 80 2540 NJ 2540 N 2540 NJ 2540 N
preplace netloc adc2_clk_1 1 0 5 NJ 2650 NJ 2650 NJ 2650 NJ 2650 2680
preplace netloc axi_dma_avg_M_AXI_S2MM 1 2 8 1540 -260 NJ -260 NJ -260 NJ -260 NJ -260 NJ -260 NJ -260 6270
preplace netloc axi_dma_buf_M_AXI_S2MM 1 2 8 1560 -240 NJ -240 NJ -240 NJ -240 NJ -240 NJ -240 NJ -240 6290
preplace netloc axi_dma_gen_M_AXIS_MM2S 1 1 1 N 1280
preplace netloc axi_dma_gen_M_AXI_MM2S 1 1 2 770 450 NJ
preplace netloc axi_dma_readout_M_AXI_S2MM 1 2 8 1580 -220 NJ -220 NJ -220 NJ -220 NJ -220 NJ -220 NJ -220 6310
preplace netloc axi_dma_tproc_M_AXIS_MM2S 1 0 2 340 1640 760
preplace netloc axi_dma_tproc_M_AXI_MM2S 1 1 2 790 470 NJ
preplace netloc axi_dma_tproc_M_AXI_S2MM 1 1 2 810 490 NJ
preplace netloc axi_dma_tt_M_AXI_S2MM 1 2 5 1600 -200 NJ -200 NJ -200 NJ -200 4170
preplace netloc axi_smc_M00_AXI 1 3 2 1990 -80 NJ
preplace netloc axis_avg_buffer_0_m0_axis 1 7 1 4910 1040n
preplace netloc axis_avg_buffer_0_m1_axis 1 7 1 4930 1260n
preplace netloc axis_avg_buffer_0_m2_axis 1 7 1 5360 1370n
preplace netloc axis_avg_buffer_1_m0_axis 1 7 1 4920 1060n
preplace netloc axis_avg_buffer_1_m1_axis 1 7 1 4950 1280n
preplace netloc axis_avg_buffer_1_m2_axis 1 7 1 5310 1640n
preplace netloc axis_broadcaster_0_M00_AXIS 1 6 1 4420 1280n
preplace netloc axis_broadcaster_0_M01_AXIS 1 6 1 4420 1440n
preplace netloc axis_broadcaster_1_M00_AXIS 1 6 1 4450 1530n
preplace netloc axis_broadcaster_1_M01_AXIS 1 6 1 4200 1790n
preplace netloc axis_broadcaster_2_M00_AXIS 1 6 1 4470 1810n
preplace netloc axis_broadcaster_2_M01_AXIS 1 6 1 4190 2110n
preplace netloc axis_cc_avg_0_M_AXIS 1 0 9 270 -180 NJ -180 NJ -180 NJ -180 NJ -180 NJ -180 NJ -180 NJ -180 5780
preplace netloc axis_cc_avg_1_M_AXIS 1 0 9 280 -170 NJ -170 NJ -170 NJ -170 NJ -170 NJ -170 NJ -170 NJ -170 5790
preplace netloc axis_cc_avg_2_M_AXIS 1 0 9 290 -160 NJ -160 NJ -160 NJ -160 NJ -160 NJ -160 NJ -160 NJ -160 5800
preplace netloc axis_cdcsync_v1_0_m0_axis 1 3 1 1990 1360n
preplace netloc axis_cdcsync_v1_0_m1_axis 1 3 1 2000 1470n
preplace netloc axis_cdcsync_v1_0_m2_axis 1 3 1 1990 1490n
preplace netloc axis_dyn_readout_v1_0_m0_axis 1 6 1 4490 1240n
preplace netloc axis_dyn_readout_v1_0_m1_axis 1 5 2 3740 1510 4160
preplace netloc axis_dyn_readout_v1_1_m0_axis 1 6 1 4430 1610n
preplace netloc axis_dyn_readout_v1_1_m1_axis 1 5 2 3740 1520 4160
preplace netloc axis_dyn_readout_v1_2_m0_axis 1 6 1 4210 1930n
preplace netloc axis_dyn_readout_v1_2_m1_axis 1 5 2 3740 2180 4160
preplace netloc axis_register_slice_2_M_AXIS 1 5 1 3650 1240n
preplace netloc axis_register_slice_3_M_AXIS 1 5 1 3480 1610n
preplace netloc axis_register_slice_4_M_AXIS1 1 5 1 3710 1930n
preplace netloc axis_register_slice_4_m_axis 1 4 1 2520J 2360n
preplace netloc axis_register_slice_6_m_axis 1 4 1 2550 2120n
preplace netloc axis_signal_gen_v6_0_m_axis 1 3 1 2020 2100n
preplace netloc axis_signal_gen_v6_1_m_axis 1 3 1 2070 2340n
preplace netloc axis_switch_0_M00_AXIS 1 7 1 4920 2500n
preplace netloc axis_switch_avg_M00_AXIS 1 8 1 5810 1060n
preplace netloc axis_switch_buf_M00_AXIS 1 8 1 5880 1230n
preplace netloc axis_switch_ddr4_M00_AXIS 1 7 2 4910 2730 NJ
preplace netloc axis_switch_gen_M00_AXIS 1 2 1 1550 1300n
preplace netloc axis_switch_gen_M01_AXIS 1 2 1 1430 1320n
preplace netloc axis_switch_gen_M02_AXIS 1 2 5 1420J 1280 NJ 1280 2730J 1350 NJ 1350 4480
preplace netloc axis_weighted_buffer_0_m0_axis 1 7 1 4940 1080n
preplace netloc axis_weighted_buffer_0_m1_axis 1 7 1 5350 1300n
preplace netloc axis_weighted_buffer_0_m2_axis 1 7 1 5360 1840n
preplace netloc dac0_clk_1 1 0 5 N 2670 NJ 2670 NJ 2670 NJ 2670 2720
preplace netloc dac2_clk_1 1 0 5 N 2690 NJ 2690 N 2690 NJ 2690 2740
preplace netloc ddr4_0_C0_DDR4 1 9 1 6330 2780n
preplace netloc mr_buffer_et_0_m00_axis 1 8 1 5880 2470n
preplace netloc ps8_0_axi_periph_M00_AXI 1 6 3 4510 890n 5360 930n 5900J
preplace netloc ps8_0_axi_periph_M01_AXI 1 6 3 4500 910n 5350 940n 5880J
preplace netloc ps8_0_axi_periph_M02_AXI 1 6 3 4490 920n 5340 950n 5870J
preplace netloc ps8_0_axi_periph_M03_AXI 1 6 1 4440 410n
preplace netloc ps8_0_axi_periph_M04_AXI 1 5 2 3720 0n 4200
preplace netloc ps8_0_axi_periph_M05_AXI 1 6 1 4420 450n
preplace netloc ps8_0_axi_periph_M06_AXI 1 6 2 4470 930n 5330
preplace netloc ps8_0_axi_periph_M07_AXI 1 6 2 4450 940n 5320
preplace netloc ps8_0_axi_periph_M08_AXI 1 6 1 4350 510n
preplace netloc ps8_0_axi_periph_M09_AXI 1 0 7 280 -190n N -190n N -190n N -190n N -190n N -190n 4240
preplace netloc ps8_0_axi_periph_M10_AXI 1 6 2 4430 950n 5240
preplace netloc ps8_0_axi_periph_M11_AXI 1 4 3 2770 1420n 3630J 10n 4180J
preplace netloc ps8_0_axi_periph_M12_AXI 1 6 1 4410 590n
preplace netloc ps8_0_axi_periph_M13_AXI 1 2 5 1560 -180n NJ -180n NJ -180n NJ -180n 4230
preplace netloc ps8_0_axi_periph_M14_AXI 1 2 5 1570 330n NJ 330n 2710J 440n 3510J 20n 4170
preplace netloc ps8_0_axi_periph_M15_AXI 1 0 7 300 -170n N -170n N -170n NJ -170n NJ -170n NJ -170n 4220
preplace netloc ps8_0_axi_periph_M16_AXI 1 1 6 1000 -150n N -150n N -150n NJ -150n NJ -150n 4190
preplace netloc ps8_0_axi_periph_M17_AXI 1 0 7 340 -160n NJ -160n NJ -160n NJ -160n NJ -160n NJ -160n 4210
preplace netloc ps8_0_axi_periph_M18_AXI 1 6 1 4320 710n
preplace netloc ps8_0_axi_periph_M19_AXI 1 3 4 2080 -140n N -140n N -140n 4160
preplace netloc ps8_0_axi_periph_M20_AXI 1 6 3 4400J 960n NJ 960n 5840
preplace netloc ps8_0_axi_periph_M21_AXI 1 5 2 3730 1100n 4170
preplace netloc qick_processor_0_QPeriphA 1 1 5 980J 1890 NJ 1890 NJ 1890 NJ 1890 3490
preplace netloc qick_processor_0_m0_axis 1 1 1 940 1880n
preplace netloc qick_processor_0_m1_axis 1 1 1 920 1900n
preplace netloc qick_processor_0_m2_axis 1 1 2 930 1420 1420J
preplace netloc qick_processor_0_m3_axis 1 1 2 950 1430 NJ
preplace netloc qick_processor_0_m4_axis 1 1 2 970 1450 NJ
preplace netloc qick_processor_0_m_dma_axis_o 1 0 2 340 1400 770
preplace netloc qick_time_tagger_0_m_axis_dma 1 5 2 3740 2440 4160
preplace netloc sg_translator_0_m_gen_v6_axis 1 2 1 1570 2060n
preplace netloc sg_translator_1_m_gen_v6_axis 1 2 1 1420 2310n
preplace netloc sg_translator_2_m_readout_v3_axis 1 4 2 NJ 1380 3480
preplace netloc sg_translator_3_m_readout_v3_axis 1 4 2 NJ 1560 3700
preplace netloc sg_translator_4_m_readout_v3_axis 1 4 2 2530J 1710 3680J
preplace netloc sys_clk_ddr4_1 1 8 2 5900 2650 6330
preplace netloc sysref_in_1 1 0 5 NJ 2790 NJ 2790 NJ 2790 NJ 2790 2790
preplace netloc usp_rf_data_converter_0_m00_axis 1 4 2 2780 1720 3440
preplace netloc usp_rf_data_converter_0_m02_axis 1 4 2 2790 1730 3450
preplace netloc usp_rf_data_converter_0_m20_axis 1 4 2 2800 2190 3430
preplace netloc usp_rf_data_converter_0_vout00 1 5 5 3710 2290 NJ 2290 NJ 2290 NJ 2290 NJ
preplace netloc usp_rf_data_converter_0_vout20 1 5 5 3730J 2400 NJ 2400 NJ 2400 NJ 2400 6330
preplace netloc vin0_01_1 1 0 5 NJ 2710 NJ 2710 NJ 2710 NJ 2710 2750
preplace netloc vin0_23_1 1 0 5 NJ 2730 NJ 2730 NJ 2730 NJ 2730 2760
preplace netloc vin2_01_1 1 0 5 NJ 2750 NJ 2750 NJ 2750 NJ 2750 2770
preplace netloc vin2_23_1 1 0 5 NJ 2770 NJ 2770 NJ 2770 NJ 2770 2780
preplace netloc zynq_ultra_ps_e_0_M_AXI_HPM0_FPD 1 5 1 3720J -70n
preplace netloc zynq_ultra_ps_e_0_M_AXI_HPM1_FPD 1 5 4 NJ -50 NJ -50 NJ -50 5890
preplace netloc usp_rf_data_converter_0_m22_axis 1 4 2 2790 2220 3420
preplace netloc axis_register_slice_5_M_AXIS 1 5 1 3480 2300n
levelinfo -pg 1 -50 550 1210 1800 2300 3110 3950 4710 5570 6080 6370
pagesize -pg 1 -db -bbox -sgen -170 -270 6510 3560
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


