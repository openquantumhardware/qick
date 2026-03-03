
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
QICK:QICK:axis_pfb_readout_v4:1.0\
QICK:QICK:axis_sg_mixmux8_v1:1.0\
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
  set_property CONFIG.M_TDATA_NUM_BYTES {32} $axis_dwidth_converter_0


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
    CONFIG.N {2} \
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


  # Create instance: axis_signal_gen_v6_0, and set properties
  set axis_signal_gen_v6_0 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_signal_gen_v6:1.0 axis_signal_gen_v6_0 ]

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

  # Create instance: axis_register_slice_2, and set properties
  set axis_register_slice_2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_register_slice:1.1 axis_register_slice_2 ]
  set_property CONFIG.REG_CONFIG {8} $axis_register_slice_2


  # Create instance: axis_register_slice_3, and set properties
  set axis_register_slice_3 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_register_slice:1.1 axis_register_slice_3 ]
  set_property CONFIG.REG_CONFIG {8} $axis_register_slice_3


  # Create instance: axis_switch_avg, and set properties
  set axis_switch_avg [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_switch:1.1 axis_switch_avg ]
  set_property -dict [list \
    CONFIG.M00_S01_CONNECTIVITY {1} \
    CONFIG.NUM_SI {10} \
    CONFIG.ROUTING_MODE {1} \
  ] $axis_switch_avg


  # Create instance: axis_switch_buf, and set properties
  set axis_switch_buf [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_switch:1.1 axis_switch_buf ]
  set_property -dict [list \
    CONFIG.NUM_SI {10} \
    CONFIG.ROUTING_MODE {1} \
  ] $axis_switch_buf


  # Create instance: axis_switch_ddr4, and set properties
  set axis_switch_ddr4 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_switch:1.1 axis_switch_ddr4 ]
  set_property -dict [list \
    CONFIG.NUM_SI {10} \
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
    CONFIG.NUM_SI {2} \
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
  set_property CONFIG.NUM_MI {30} $ps8_0_axi_periph


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
    CONFIG.IN_PORT_QTY {10} \
    CONFIG.IO_CTRL {1} \
    CONFIG.LFSR {1} \
    CONFIG.OUT_DPORT_DW {8} \
    CONFIG.OUT_DPORT_QTY {1} \
    CONFIG.OUT_TRIG_QTY {22} \
    CONFIG.OUT_WPORT_QTY {4} \
    CONFIG.PMEM_AW {12} \
    CONFIG.WMEM_AW {10} \
  ] $qick_processor_0


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


  # Create instance: axis_weighted_buffer_0, and set properties
  set axis_weighted_buffer_0 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_weighted_buffer:1.3 axis_weighted_buffer_0 ]
  set_property -dict [list \
    CONFIG.N_AVG {14} \
    CONFIG.N_WGT {12} \
  ] $axis_weighted_buffer_0


  # Create instance: axis_pfb_readout_v4_0, and set properties
  set axis_pfb_readout_v4_0 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_pfb_readout_v4:1.0 axis_pfb_readout_v4_0 ]

  # Create instance: axis_sg_mixmux8_v1_0, and set properties
  set axis_sg_mixmux8_v1_0 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_sg_mixmux8_v1:1.0 axis_sg_mixmux8_v1_0 ]
  set_property CONFIG.N_DDS {8} $axis_sg_mixmux8_v1_0


  # Create instance: axis_broadcaster_3, and set properties
  set axis_broadcaster_3 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_broadcaster:1.1 axis_broadcaster_3 ]

  # Create instance: axis_broadcaster_4, and set properties
  set axis_broadcaster_4 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_broadcaster:1.1 axis_broadcaster_4 ]

  # Create instance: axis_broadcaster_5, and set properties
  set axis_broadcaster_5 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_broadcaster:1.1 axis_broadcaster_5 ]

  # Create instance: axis_broadcaster_6, and set properties
  set axis_broadcaster_6 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_broadcaster:1.1 axis_broadcaster_6 ]

  # Create instance: axis_broadcaster_7, and set properties
  set axis_broadcaster_7 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_broadcaster:1.1 axis_broadcaster_7 ]

  # Create instance: axis_broadcaster_8, and set properties
  set axis_broadcaster_8 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_broadcaster:1.1 axis_broadcaster_8 ]

  # Create instance: axis_broadcaster_9, and set properties
  set axis_broadcaster_9 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_broadcaster:1.1 axis_broadcaster_9 ]

  # Create instance: axis_broadcaster_10, and set properties
  set axis_broadcaster_10 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_broadcaster:1.1 axis_broadcaster_10 ]

  # Create instance: axis_avg_buffer_2, and set properties
  set axis_avg_buffer_2 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_avg_buffer:1.2 axis_avg_buffer_2 ]

  # Create instance: axis_avg_buffer_3, and set properties
  set axis_avg_buffer_3 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_avg_buffer:1.2 axis_avg_buffer_3 ]

  # Create instance: axis_avg_buffer_4, and set properties
  set axis_avg_buffer_4 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_avg_buffer:1.2 axis_avg_buffer_4 ]

  # Create instance: axis_avg_buffer_5, and set properties
  set axis_avg_buffer_5 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_avg_buffer:1.2 axis_avg_buffer_5 ]

  # Create instance: axis_avg_buffer_6, and set properties
  set axis_avg_buffer_6 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_avg_buffer:1.2 axis_avg_buffer_6 ]

  # Create instance: axis_avg_buffer_7, and set properties
  set axis_avg_buffer_7 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_avg_buffer:1.2 axis_avg_buffer_7 ]

  # Create instance: axis_avg_buffer_8, and set properties
  set axis_avg_buffer_8 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_avg_buffer:1.2 axis_avg_buffer_8 ]

  # Create instance: axis_avg_buffer_9, and set properties
  set axis_avg_buffer_9 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_avg_buffer:1.2 axis_avg_buffer_9 ]

  # Create instance: axis_clock_converter_0, and set properties
  set axis_clock_converter_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_clock_converter:1.1 axis_clock_converter_0 ]

  # Create instance: axis_clock_converter_1, and set properties
  set axis_clock_converter_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_clock_converter:1.1 axis_clock_converter_1 ]

  # Create instance: axis_clock_converter_2, and set properties
  set axis_clock_converter_2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_clock_converter:1.1 axis_clock_converter_2 ]

  # Create instance: axis_clock_converter_3, and set properties
  set axis_clock_converter_3 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_clock_converter:1.1 axis_clock_converter_3 ]

  # Create instance: axis_clock_converter_4, and set properties
  set axis_clock_converter_4 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_clock_converter:1.1 axis_clock_converter_4 ]

  # Create instance: axis_clock_converter_5, and set properties
  set axis_clock_converter_5 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_clock_converter:1.1 axis_clock_converter_5 ]

  # Create instance: axis_clock_converter_6, and set properties
  set axis_clock_converter_6 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_clock_converter:1.1 axis_clock_converter_6 ]

  # Create instance: axis_clock_converter_7, and set properties
  set axis_clock_converter_7 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_clock_converter:1.1 axis_clock_converter_7 ]

  # Create instance: sg_translator_1, and set properties
  set sg_translator_1 [ create_bd_cell -type ip -vlnv QICK:QICK:sg_translator:1.0 sg_translator_1 ]
  set_property CONFIG.OUT_TYPE {2} $sg_translator_1


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
  connect_bd_intf_net -intf_net axis_avg_buffer_2_m0_axis [get_bd_intf_pins axis_avg_buffer_2/m0_axis] [get_bd_intf_pins axis_switch_avg/S02_AXIS]
  connect_bd_intf_net -intf_net axis_avg_buffer_2_m1_axis [get_bd_intf_pins axis_avg_buffer_2/m1_axis] [get_bd_intf_pins axis_switch_buf/S02_AXIS]
  connect_bd_intf_net -intf_net axis_avg_buffer_2_m2_axis [get_bd_intf_pins axis_avg_buffer_2/m2_axis] [get_bd_intf_pins axis_clock_converter_0/S_AXIS]
  connect_bd_intf_net -intf_net axis_avg_buffer_3_m0_axis [get_bd_intf_pins axis_avg_buffer_3/m0_axis] [get_bd_intf_pins axis_switch_avg/S03_AXIS]
  connect_bd_intf_net -intf_net axis_avg_buffer_3_m1_axis [get_bd_intf_pins axis_avg_buffer_3/m1_axis] [get_bd_intf_pins axis_switch_buf/S03_AXIS]
  connect_bd_intf_net -intf_net axis_avg_buffer_3_m2_axis [get_bd_intf_pins axis_avg_buffer_3/m2_axis] [get_bd_intf_pins axis_clock_converter_1/S_AXIS]
  connect_bd_intf_net -intf_net axis_avg_buffer_4_m0_axis [get_bd_intf_pins axis_avg_buffer_4/m0_axis] [get_bd_intf_pins axis_switch_avg/S04_AXIS]
  connect_bd_intf_net -intf_net axis_avg_buffer_4_m1_axis [get_bd_intf_pins axis_avg_buffer_4/m1_axis] [get_bd_intf_pins axis_switch_buf/S04_AXIS]
  connect_bd_intf_net -intf_net axis_avg_buffer_4_m2_axis [get_bd_intf_pins axis_avg_buffer_4/m2_axis] [get_bd_intf_pins axis_clock_converter_2/S_AXIS]
  connect_bd_intf_net -intf_net axis_avg_buffer_5_m0_axis [get_bd_intf_pins axis_avg_buffer_5/m0_axis] [get_bd_intf_pins axis_switch_avg/S05_AXIS]
  connect_bd_intf_net -intf_net axis_avg_buffer_5_m1_axis [get_bd_intf_pins axis_avg_buffer_5/m1_axis] [get_bd_intf_pins axis_switch_buf/S05_AXIS]
  connect_bd_intf_net -intf_net axis_avg_buffer_5_m2_axis [get_bd_intf_pins axis_avg_buffer_5/m2_axis] [get_bd_intf_pins axis_clock_converter_3/S_AXIS]
  connect_bd_intf_net -intf_net axis_avg_buffer_6_m0_axis [get_bd_intf_pins axis_avg_buffer_6/m0_axis] [get_bd_intf_pins axis_switch_avg/S06_AXIS]
  connect_bd_intf_net -intf_net axis_avg_buffer_6_m1_axis [get_bd_intf_pins axis_avg_buffer_6/m1_axis] [get_bd_intf_pins axis_switch_buf/S06_AXIS]
  connect_bd_intf_net -intf_net axis_avg_buffer_6_m2_axis [get_bd_intf_pins axis_avg_buffer_6/m2_axis] [get_bd_intf_pins axis_clock_converter_4/S_AXIS]
  connect_bd_intf_net -intf_net axis_avg_buffer_7_m0_axis [get_bd_intf_pins axis_avg_buffer_7/m0_axis] [get_bd_intf_pins axis_switch_avg/S07_AXIS]
  connect_bd_intf_net -intf_net axis_avg_buffer_7_m1_axis [get_bd_intf_pins axis_avg_buffer_7/m1_axis] [get_bd_intf_pins axis_switch_buf/S07_AXIS]
  connect_bd_intf_net -intf_net axis_avg_buffer_7_m2_axis [get_bd_intf_pins axis_avg_buffer_7/m2_axis] [get_bd_intf_pins axis_clock_converter_5/S_AXIS]
  connect_bd_intf_net -intf_net axis_avg_buffer_8_m0_axis [get_bd_intf_pins axis_avg_buffer_8/m0_axis] [get_bd_intf_pins axis_switch_avg/S08_AXIS]
  connect_bd_intf_net -intf_net axis_avg_buffer_8_m1_axis [get_bd_intf_pins axis_avg_buffer_8/m1_axis] [get_bd_intf_pins axis_switch_buf/S08_AXIS]
  connect_bd_intf_net -intf_net axis_avg_buffer_8_m2_axis [get_bd_intf_pins axis_avg_buffer_8/m2_axis] [get_bd_intf_pins axis_clock_converter_6/S_AXIS]
  connect_bd_intf_net -intf_net axis_avg_buffer_9_m0_axis [get_bd_intf_pins axis_avg_buffer_9/m0_axis] [get_bd_intf_pins axis_switch_avg/S09_AXIS]
  connect_bd_intf_net -intf_net axis_avg_buffer_9_m1_axis [get_bd_intf_pins axis_avg_buffer_9/m1_axis] [get_bd_intf_pins axis_switch_buf/S09_AXIS]
  connect_bd_intf_net -intf_net axis_avg_buffer_9_m2_axis [get_bd_intf_pins axis_avg_buffer_9/m2_axis] [get_bd_intf_pins axis_clock_converter_7/S_AXIS]
  connect_bd_intf_net -intf_net axis_broadcaster_0_M00_AXIS [get_bd_intf_pins axis_avg_buffer_0/s_axis] [get_bd_intf_pins axis_broadcaster_0/M00_AXIS]
  connect_bd_intf_net -intf_net axis_broadcaster_0_M01_AXIS [get_bd_intf_pins axis_broadcaster_0/M01_AXIS] [get_bd_intf_pins axis_switch_ddr4/S00_AXIS]
  connect_bd_intf_net -intf_net axis_broadcaster_10_M00_AXIS [get_bd_intf_pins axis_broadcaster_10/M00_AXIS] [get_bd_intf_pins axis_avg_buffer_9/s_axis]
  connect_bd_intf_net -intf_net axis_broadcaster_10_M01_AXIS [get_bd_intf_pins axis_broadcaster_10/M01_AXIS] [get_bd_intf_pins axis_switch_ddr4/S09_AXIS]
  connect_bd_intf_net -intf_net axis_broadcaster_1_M00_AXIS [get_bd_intf_pins axis_broadcaster_1/M00_AXIS] [get_bd_intf_pins axis_weighted_buffer_0/s_axis]
  connect_bd_intf_net -intf_net axis_broadcaster_1_M01_AXIS [get_bd_intf_pins axis_broadcaster_1/M01_AXIS] [get_bd_intf_pins axis_switch_ddr4/S01_AXIS]
  connect_bd_intf_net -intf_net axis_broadcaster_3_M00_AXIS [get_bd_intf_pins axis_broadcaster_3/M00_AXIS] [get_bd_intf_pins axis_avg_buffer_2/s_axis]
  connect_bd_intf_net -intf_net axis_broadcaster_3_M01_AXIS [get_bd_intf_pins axis_broadcaster_3/M01_AXIS] [get_bd_intf_pins axis_switch_ddr4/S02_AXIS]
  connect_bd_intf_net -intf_net axis_broadcaster_4_M00_AXIS [get_bd_intf_pins axis_broadcaster_4/M00_AXIS] [get_bd_intf_pins axis_avg_buffer_3/s_axis]
  connect_bd_intf_net -intf_net axis_broadcaster_4_M01_AXIS [get_bd_intf_pins axis_broadcaster_4/M01_AXIS] [get_bd_intf_pins axis_switch_ddr4/S03_AXIS]
  connect_bd_intf_net -intf_net axis_broadcaster_5_M00_AXIS [get_bd_intf_pins axis_broadcaster_5/M00_AXIS] [get_bd_intf_pins axis_avg_buffer_4/s_axis]
  connect_bd_intf_net -intf_net axis_broadcaster_5_M01_AXIS [get_bd_intf_pins axis_broadcaster_5/M01_AXIS] [get_bd_intf_pins axis_switch_ddr4/S04_AXIS]
  connect_bd_intf_net -intf_net axis_broadcaster_6_M00_AXIS [get_bd_intf_pins axis_broadcaster_6/M00_AXIS] [get_bd_intf_pins axis_avg_buffer_5/s_axis]
  connect_bd_intf_net -intf_net axis_broadcaster_6_M01_AXIS [get_bd_intf_pins axis_broadcaster_6/M01_AXIS] [get_bd_intf_pins axis_switch_ddr4/S05_AXIS]
  connect_bd_intf_net -intf_net axis_broadcaster_7_M00_AXIS [get_bd_intf_pins axis_broadcaster_7/M00_AXIS] [get_bd_intf_pins axis_avg_buffer_6/s_axis]
  connect_bd_intf_net -intf_net axis_broadcaster_7_M01_AXIS [get_bd_intf_pins axis_broadcaster_7/M01_AXIS] [get_bd_intf_pins axis_switch_ddr4/S06_AXIS]
  connect_bd_intf_net -intf_net axis_broadcaster_8_M00_AXIS [get_bd_intf_pins axis_broadcaster_8/M00_AXIS] [get_bd_intf_pins axis_avg_buffer_7/s_axis]
  connect_bd_intf_net -intf_net axis_broadcaster_8_M01_AXIS [get_bd_intf_pins axis_broadcaster_8/M01_AXIS] [get_bd_intf_pins axis_switch_ddr4/S07_AXIS]
  connect_bd_intf_net -intf_net axis_broadcaster_9_M00_AXIS [get_bd_intf_pins axis_broadcaster_9/M00_AXIS] [get_bd_intf_pins axis_avg_buffer_8/s_axis]
  connect_bd_intf_net -intf_net axis_broadcaster_9_M01_AXIS [get_bd_intf_pins axis_broadcaster_9/M01_AXIS] [get_bd_intf_pins axis_switch_ddr4/S08_AXIS]
  connect_bd_intf_net -intf_net axis_cc_avg_0_M_AXIS [get_bd_intf_pins axis_cc_avg_0/M_AXIS] [get_bd_intf_pins qick_processor_0/s0_axis]
  connect_bd_intf_net -intf_net axis_cc_avg_2_M_AXIS [get_bd_intf_pins axis_cc_avg_2/M_AXIS] [get_bd_intf_pins qick_processor_0/s1_axis]
  connect_bd_intf_net -intf_net axis_cdcsync_v1_0_m0_axis [get_bd_intf_pins axis_cdcsync_v1_0/m0_axis] [get_bd_intf_pins sg_translator_2/s_tproc_axis]
  connect_bd_intf_net -intf_net axis_cdcsync_v1_0_m1_axis [get_bd_intf_pins axis_cdcsync_v1_0/m1_axis] [get_bd_intf_pins sg_translator_3/s_tproc_axis]
  connect_bd_intf_net -intf_net axis_clock_converter_0_M_AXIS [get_bd_intf_pins axis_clock_converter_0/M_AXIS] [get_bd_intf_pins qick_processor_0/s2_axis]
  connect_bd_intf_net -intf_net axis_clock_converter_1_M_AXIS [get_bd_intf_pins axis_clock_converter_1/M_AXIS] [get_bd_intf_pins qick_processor_0/s3_axis]
  connect_bd_intf_net -intf_net axis_clock_converter_2_M_AXIS [get_bd_intf_pins axis_clock_converter_2/M_AXIS] [get_bd_intf_pins qick_processor_0/s4_axis]
  connect_bd_intf_net -intf_net axis_clock_converter_3_M_AXIS [get_bd_intf_pins axis_clock_converter_3/M_AXIS] [get_bd_intf_pins qick_processor_0/s5_axis]
  connect_bd_intf_net -intf_net axis_clock_converter_4_M_AXIS [get_bd_intf_pins axis_clock_converter_4/M_AXIS] [get_bd_intf_pins qick_processor_0/s6_axis]
  connect_bd_intf_net -intf_net axis_clock_converter_5_M_AXIS [get_bd_intf_pins axis_clock_converter_5/M_AXIS] [get_bd_intf_pins qick_processor_0/s7_axis]
  connect_bd_intf_net -intf_net axis_clock_converter_6_M_AXIS [get_bd_intf_pins axis_clock_converter_6/M_AXIS] [get_bd_intf_pins qick_processor_0/s8_axis]
  connect_bd_intf_net -intf_net axis_clock_converter_7_M_AXIS [get_bd_intf_pins axis_clock_converter_7/M_AXIS] [get_bd_intf_pins qick_processor_0/s9_axis]
  connect_bd_intf_net -intf_net axis_dyn_readout_v1_0_m0_axis [get_bd_intf_pins axis_dyn_readout_v1_0/m0_axis] [get_bd_intf_pins axis_switch_mr/S00_AXIS]
  connect_bd_intf_net -intf_net axis_dyn_readout_v1_0_m1_axis [get_bd_intf_pins axis_broadcaster_0/S_AXIS] [get_bd_intf_pins axis_dyn_readout_v1_0/m1_axis]
  connect_bd_intf_net -intf_net axis_dyn_readout_v1_1_m0_axis [get_bd_intf_pins axis_dyn_readout_v1_1/m0_axis] [get_bd_intf_pins axis_switch_mr/S01_AXIS]
  connect_bd_intf_net -intf_net axis_dyn_readout_v1_1_m1_axis [get_bd_intf_pins axis_broadcaster_1/S_AXIS] [get_bd_intf_pins axis_dyn_readout_v1_1/m1_axis]
  connect_bd_intf_net -intf_net axis_pfb_readout_v4_0_m0_axis [get_bd_intf_pins axis_pfb_readout_v4_0/m0_axis] [get_bd_intf_pins axis_broadcaster_3/S_AXIS]
  connect_bd_intf_net -intf_net axis_pfb_readout_v4_0_m1_axis [get_bd_intf_pins axis_pfb_readout_v4_0/m1_axis] [get_bd_intf_pins axis_broadcaster_4/S_AXIS]
  connect_bd_intf_net -intf_net axis_pfb_readout_v4_0_m2_axis [get_bd_intf_pins axis_pfb_readout_v4_0/m2_axis] [get_bd_intf_pins axis_broadcaster_5/S_AXIS]
  connect_bd_intf_net -intf_net axis_pfb_readout_v4_0_m3_axis [get_bd_intf_pins axis_pfb_readout_v4_0/m3_axis] [get_bd_intf_pins axis_broadcaster_6/S_AXIS]
  connect_bd_intf_net -intf_net axis_pfb_readout_v4_0_m4_axis [get_bd_intf_pins axis_pfb_readout_v4_0/m4_axis] [get_bd_intf_pins axis_broadcaster_7/S_AXIS]
  connect_bd_intf_net -intf_net axis_pfb_readout_v4_0_m5_axis [get_bd_intf_pins axis_pfb_readout_v4_0/m5_axis] [get_bd_intf_pins axis_broadcaster_8/S_AXIS]
  connect_bd_intf_net -intf_net axis_pfb_readout_v4_0_m6_axis [get_bd_intf_pins axis_pfb_readout_v4_0/m6_axis] [get_bd_intf_pins axis_broadcaster_9/S_AXIS]
  connect_bd_intf_net -intf_net axis_pfb_readout_v4_0_m7_axis [get_bd_intf_pins axis_pfb_readout_v4_0/m7_axis] [get_bd_intf_pins axis_broadcaster_10/S_AXIS]
  connect_bd_intf_net -intf_net axis_register_slice_2_M_AXIS [get_bd_intf_pins axis_dyn_readout_v1_0/s1_axis] [get_bd_intf_pins axis_register_slice_2/M_AXIS]
  connect_bd_intf_net -intf_net axis_register_slice_3_M_AXIS [get_bd_intf_pins axis_dyn_readout_v1_1/s1_axis] [get_bd_intf_pins axis_register_slice_3/M_AXIS]
  connect_bd_intf_net -intf_net axis_register_slice_5_M_AXIS [get_bd_intf_pins axis_register_slice_5/M_AXIS] [get_bd_intf_pins qick_time_tagger_0/s0_axis_adc0]
  connect_bd_intf_net -intf_net axis_register_slice_6_m_axis [get_bd_intf_pins axis_register_slice_0/m_axis] [get_bd_intf_pins usp_rf_data_converter_0/s00_axis]
  connect_bd_intf_net -intf_net axis_sg_mixmux8_v1_0_m_axis [get_bd_intf_pins axis_sg_mixmux8_v1_0/m_axis] [get_bd_intf_pins usp_rf_data_converter_0/s20_axis]
  connect_bd_intf_net -intf_net axis_signal_gen_v6_0_m_axis [get_bd_intf_pins axis_register_slice_0/s_axis] [get_bd_intf_pins axis_signal_gen_v6_0/m_axis]
  connect_bd_intf_net -intf_net axis_switch_0_M00_AXIS [get_bd_intf_pins axis_switch_mr/M00_AXIS] [get_bd_intf_pins mr_buffer_et_0/s00_axis]
  connect_bd_intf_net -intf_net axis_switch_avg_M00_AXIS [get_bd_intf_pins axi_dma_avg/S_AXIS_S2MM] [get_bd_intf_pins axis_switch_avg/M00_AXIS]
  connect_bd_intf_net -intf_net axis_switch_buf_M00_AXIS [get_bd_intf_pins axi_dma_buf/S_AXIS_S2MM] [get_bd_intf_pins axis_switch_buf/M00_AXIS]
  connect_bd_intf_net -intf_net axis_switch_ddr4_M00_AXIS [get_bd_intf_pins ddr4/S_AXIS] [get_bd_intf_pins axis_switch_ddr4/M00_AXIS]
  connect_bd_intf_net -intf_net axis_switch_gen_M00_AXIS [get_bd_intf_pins axis_signal_gen_v6_0/s0_axis] [get_bd_intf_pins axis_switch_gen/M00_AXIS]
  connect_bd_intf_net -intf_net axis_switch_gen_M02_AXIS [get_bd_intf_pins axis_weighted_buffer_0/s1_axis_weights] [get_bd_intf_pins axis_switch_gen/M02_AXIS]
  connect_bd_intf_net -intf_net axis_weighted_buffer_0_m0_axis [get_bd_intf_pins axis_weighted_buffer_0/m0_axis] [get_bd_intf_pins axis_switch_avg/S01_AXIS]
  connect_bd_intf_net -intf_net axis_weighted_buffer_0_m1_axis [get_bd_intf_pins axis_weighted_buffer_0/m1_axis] [get_bd_intf_pins axis_switch_buf/S01_AXIS]
  connect_bd_intf_net -intf_net axis_weighted_buffer_0_m2_axis [get_bd_intf_pins axis_cc_avg_2/S_AXIS] [get_bd_intf_pins axis_weighted_buffer_0/m2_axis]
  connect_bd_intf_net -intf_net dac0_clk_1 [get_bd_intf_ports dac0_clk] [get_bd_intf_pins usp_rf_data_converter_0/dac0_clk]
  connect_bd_intf_net -intf_net dac2_clk_1 [get_bd_intf_ports dac2_clk] [get_bd_intf_pins usp_rf_data_converter_0/dac2_clk]
  connect_bd_intf_net -intf_net ddr4_0_C0_DDR4 [get_bd_intf_ports ddr4_pl] [get_bd_intf_pins ddr4/ddr4_pl]
  connect_bd_intf_net -intf_net mr_buffer_et_0_m00_axis [get_bd_intf_pins axi_dma_mr/S_AXIS_S2MM] [get_bd_intf_pins mr_buffer_et_0/m00_axis]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M00_AXI [get_bd_intf_pins ps8_0_axi_periph/M00_AXI] [get_bd_intf_pins axi_dma_avg/S_AXI_LITE]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M01_AXI [get_bd_intf_pins ps8_0_axi_periph/M01_AXI] [get_bd_intf_pins axi_dma_buf/S_AXI_LITE]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M02_AXI [get_bd_intf_pins ps8_0_axi_periph/M02_AXI] [get_bd_intf_pins axi_dma_gen/S_AXI_LITE]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M03_AXI [get_bd_intf_pins ps8_0_axi_periph/M03_AXI] [get_bd_intf_pins axi_dma_mr/S_AXI_LITE]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M04_AXI [get_bd_intf_pins ps8_0_axi_periph/M04_AXI] [get_bd_intf_pins axi_dma_tproc/S_AXI_LITE]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M05_AXI [get_bd_intf_pins ps8_0_axi_periph/M05_AXI] [get_bd_intf_pins axi_dma_tt/S_AXI_LITE]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M06_AXI [get_bd_intf_pins ps8_0_axi_periph/M06_AXI] [get_bd_intf_pins axi_intc_0/s_axi]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M07_AXI [get_bd_intf_pins ps8_0_axi_periph/M07_AXI] [get_bd_intf_pins axis_avg_buffer_0/s_axi]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M08_AXI [get_bd_intf_pins ps8_0_axi_periph/M08_AXI] [get_bd_intf_pins axis_avg_buffer_2/s_axi]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M09_AXI [get_bd_intf_pins ps8_0_axi_periph/M09_AXI] [get_bd_intf_pins axis_avg_buffer_3/s_axi]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M10_AXI [get_bd_intf_pins ps8_0_axi_periph/M10_AXI] [get_bd_intf_pins axis_avg_buffer_4/s_axi]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M11_AXI [get_bd_intf_pins ps8_0_axi_periph/M11_AXI] [get_bd_intf_pins axis_avg_buffer_5/s_axi]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M12_AXI [get_bd_intf_pins ps8_0_axi_periph/M12_AXI] [get_bd_intf_pins axis_avg_buffer_6/s_axi]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M13_AXI [get_bd_intf_pins ps8_0_axi_periph/M13_AXI] [get_bd_intf_pins axis_avg_buffer_7/s_axi]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M14_AXI [get_bd_intf_pins ps8_0_axi_periph/M14_AXI] [get_bd_intf_pins axis_avg_buffer_8/s_axi]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M15_AXI [get_bd_intf_pins ps8_0_axi_periph/M15_AXI] [get_bd_intf_pins axis_avg_buffer_9/s_axi]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M16_AXI [get_bd_intf_pins ps8_0_axi_periph/M16_AXI] [get_bd_intf_pins axis_pfb_readout_v4_0/s_axi]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M17_AXI [get_bd_intf_pins ps8_0_axi_periph/M17_AXI] [get_bd_intf_pins axis_sg_mixmux8_v1_0/s_axi]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M18_AXI [get_bd_intf_pins ps8_0_axi_periph/M18_AXI] [get_bd_intf_pins axis_signal_gen_v6_0/s_axi]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M19_AXI [get_bd_intf_pins ps8_0_axi_periph/M19_AXI] [get_bd_intf_pins axis_switch_avg/S_AXI_CTRL]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M20_AXI [get_bd_intf_pins ps8_0_axi_periph/M20_AXI] [get_bd_intf_pins axis_switch_buf/S_AXI_CTRL]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M21_AXI [get_bd_intf_pins ps8_0_axi_periph/M21_AXI] [get_bd_intf_pins axis_switch_ddr4/S_AXI_CTRL]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M22_AXI [get_bd_intf_pins ps8_0_axi_periph/M22_AXI] [get_bd_intf_pins axis_switch_gen/S_AXI_CTRL]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M23_AXI [get_bd_intf_pins ps8_0_axi_periph/M23_AXI] [get_bd_intf_pins axis_switch_mr/S_AXI_CTRL]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M24_AXI [get_bd_intf_pins ps8_0_axi_periph/M24_AXI] [get_bd_intf_pins axis_weighted_buffer_0/s_axi]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M25_AXI [get_bd_intf_pins ps8_0_axi_periph/M25_AXI] [get_bd_intf_pins ddr4/s_axi]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M26_AXI [get_bd_intf_pins ps8_0_axi_periph/M26_AXI] [get_bd_intf_pins mr_buffer_et_0/s00_axi]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M27_AXI [get_bd_intf_pins ps8_0_axi_periph/M27_AXI] [get_bd_intf_pins qick_processor_0/s_axi]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M28_AXI [get_bd_intf_pins ps8_0_axi_periph/M28_AXI] [get_bd_intf_pins qick_time_tagger_0/s_axi]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M29_AXI [get_bd_intf_pins ps8_0_axi_periph/M29_AXI] [get_bd_intf_pins usp_rf_data_converter_0/s_axi]
  connect_bd_intf_net -intf_net qick_processor_0_QPeriphA [get_bd_intf_pins qick_time_tagger_0/qick_peripheral] [get_bd_intf_pins qick_processor_0/QPeriphA]
  connect_bd_intf_net -intf_net qick_processor_0_m0_axis [get_bd_intf_pins qick_processor_0/m0_axis] [get_bd_intf_pins sg_translator_0/s_tproc_axis]
  connect_bd_intf_net -intf_net qick_processor_0_m1_axis [get_bd_intf_pins qick_processor_0/m1_axis] [get_bd_intf_pins sg_translator_1/s_tproc_axis]
  connect_bd_intf_net -intf_net qick_processor_0_m2_axis [get_bd_intf_pins axis_cdcsync_v1_0/s0_axis] [get_bd_intf_pins qick_processor_0/m2_axis]
  connect_bd_intf_net -intf_net qick_processor_0_m3_axis [get_bd_intf_pins axis_cdcsync_v1_0/s1_axis] [get_bd_intf_pins qick_processor_0/m3_axis]
  connect_bd_intf_net -intf_net qick_processor_0_m_dma_axis_o [get_bd_intf_pins axi_dma_tproc/S_AXIS_S2MM] [get_bd_intf_pins qick_processor_0/m_dma_axis_o]
  connect_bd_intf_net -intf_net qick_time_tagger_0_m_axis_dma [get_bd_intf_pins qick_time_tagger_0/m_axis_dma] [get_bd_intf_pins axi_dma_tt/S_AXIS_S2MM]
  connect_bd_intf_net -intf_net sg_translator_0_m_gen_v6_axis [get_bd_intf_pins axis_signal_gen_v6_0/s1_axis] [get_bd_intf_pins sg_translator_0/m_gen_v6_axis]
  connect_bd_intf_net -intf_net sg_translator_1_m_mux4_axis [get_bd_intf_pins sg_translator_1/m_mux4_axis] [get_bd_intf_pins axis_sg_mixmux8_v1_0/s_axis]
  connect_bd_intf_net -intf_net sg_translator_2_m_readout_v3_axis [get_bd_intf_pins axis_dyn_readout_v1_0/s0_axis] [get_bd_intf_pins sg_translator_2/m_readout_v3_axis]
  connect_bd_intf_net -intf_net sg_translator_3_m_readout_v3_axis [get_bd_intf_pins axis_dyn_readout_v1_1/s0_axis] [get_bd_intf_pins sg_translator_3/m_readout_v3_axis]
  connect_bd_intf_net -intf_net sys_clk_ddr4_1 [get_bd_intf_ports sys_clk_ddr4] [get_bd_intf_pins ddr4/sys_clk_ddr4]
  connect_bd_intf_net -intf_net sysref_in_1 [get_bd_intf_ports sysref_in] [get_bd_intf_pins usp_rf_data_converter_0/sysref_in]
  connect_bd_intf_net -intf_net usp_rf_data_converter_0_m00_axis [get_bd_intf_pins axis_register_slice_2/S_AXIS] [get_bd_intf_pins usp_rf_data_converter_0/m00_axis]
  connect_bd_intf_net -intf_net usp_rf_data_converter_0_m02_axis [get_bd_intf_pins axis_register_slice_3/S_AXIS] [get_bd_intf_pins usp_rf_data_converter_0/m02_axis]
  connect_bd_intf_net -intf_net usp_rf_data_converter_0_m20_axis [get_bd_intf_pins usp_rf_data_converter_0/m20_axis] [get_bd_intf_pins axis_pfb_readout_v4_0/s_axis]
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
  connect_bd_net -net clk_adc0_x2_clk_out1 [get_bd_pins clk_adc0_x2/clk_out1] [get_bd_pins axis_cdcsync_v1_0/m_axis_aclk] [get_bd_pins axis_dyn_readout_v1_0/aclk] [get_bd_pins axis_dyn_readout_v1_1/aclk] [get_bd_pins rst_adc0_x2/slowest_sync_clk] [get_bd_pins sg_translator_2/aclk] [get_bd_pins sg_translator_3/aclk] [get_bd_pins ddr4/aclk] [get_bd_pins axis_broadcaster_0/aclk] [get_bd_pins axis_broadcaster_1/aclk] [get_bd_pins axis_register_slice_2/aclk] [get_bd_pins axis_register_slice_3/aclk] [get_bd_pins axis_switch_ddr4/aclk] [get_bd_pins axis_switch_mr/aclk] [get_bd_pins usp_rf_data_converter_0/m0_axis_aclk] [get_bd_pins mr_buffer_et_0/s00_axis_aclk] [get_bd_pins usp_rf_data_converter_0/m2_axis_aclk] [get_bd_pins qick_time_tagger_0/adc_clk] [get_bd_pins axis_register_slice_5/aclk] [get_bd_pins axis_avg_buffer_0/s_axis_aclk] [get_bd_pins axis_weighted_buffer_0/s_axis_aclk] [get_bd_pins axis_pfb_readout_v4_0/aclk] [get_bd_pins axis_broadcaster_3/aclk] [get_bd_pins axis_broadcaster_4/aclk] [get_bd_pins axis_broadcaster_5/aclk] [get_bd_pins axis_broadcaster_6/aclk] [get_bd_pins axis_broadcaster_7/aclk] [get_bd_pins axis_broadcaster_8/aclk] [get_bd_pins axis_broadcaster_9/aclk] [get_bd_pins axis_broadcaster_10/aclk] [get_bd_pins axis_avg_buffer_2/s_axis_aclk] [get_bd_pins axis_avg_buffer_3/s_axis_aclk] [get_bd_pins axis_avg_buffer_4/s_axis_aclk] [get_bd_pins axis_avg_buffer_5/s_axis_aclk] [get_bd_pins axis_avg_buffer_6/s_axis_aclk] [get_bd_pins axis_avg_buffer_7/s_axis_aclk] [get_bd_pins axis_avg_buffer_8/s_axis_aclk] [get_bd_pins axis_avg_buffer_9/s_axis_aclk]
  connect_bd_net -net clk_adc0_x2_locked [get_bd_pins clk_adc0_x2/locked] [get_bd_pins rst_adc0_x2/dcm_locked]
  connect_bd_net -net clk_tproc_clk_out1 [get_bd_pins clk_core/clk_out1] [get_bd_pins rst_core/slowest_sync_clk] [get_bd_pins axis_cc_avg_0/m_axis_aclk] [get_bd_pins qick_processor_0/c_clk_i] [get_bd_pins axis_cc_avg_2/m_axis_aclk] [get_bd_pins qick_time_tagger_0/c_clk] [get_bd_pins axis_clock_converter_0/m_axis_aclk] [get_bd_pins axis_clock_converter_1/m_axis_aclk] [get_bd_pins axis_clock_converter_2/m_axis_aclk] [get_bd_pins axis_clock_converter_3/m_axis_aclk] [get_bd_pins axis_clock_converter_4/m_axis_aclk] [get_bd_pins axis_clock_converter_6/m_axis_aclk] [get_bd_pins axis_clock_converter_5/m_axis_aclk] [get_bd_pins axis_clock_converter_7/m_axis_aclk]
  connect_bd_net -net clk_tproc_locked [get_bd_pins clk_core/locked] [get_bd_pins rst_core/dcm_locked]
  connect_bd_net -net ddr4_0_c0_ddr4_ui_clk [get_bd_pins ddr4/c0_ddr4_ui_clk] [get_bd_pins zynq_ultra_ps_e_0/maxihpm1_fpd_aclk]
  connect_bd_net -net qick_processor_0_trig_0_o [get_bd_pins qick_processor_0/trig_0_o] [get_bd_pins axis_avg_buffer_0/trigger]
  connect_bd_net -net qick_processor_0_trig_10_o [get_bd_pins qick_processor_0/trig_10_o] [get_bd_ports PMOD0_6]
  connect_bd_net -net qick_processor_0_trig_11_o [get_bd_pins qick_processor_0/trig_11_o] [get_bd_ports PMOD0_7]
  connect_bd_net -net qick_processor_0_trig_12_o [get_bd_pins qick_processor_0/trig_12_o] [get_bd_pins axis_weighted_buffer_0/trigger]
  connect_bd_net -net qick_processor_0_trig_13_o [get_bd_pins qick_processor_0/trig_13_o] [get_bd_pins qick_time_tagger_0/arm_i]
  connect_bd_net -net qick_processor_0_trig_14_o [get_bd_pins qick_processor_0/trig_14_o] [get_bd_pins axis_avg_buffer_2/trigger]
  connect_bd_net -net qick_processor_0_trig_15_o [get_bd_pins qick_processor_0/trig_15_o] [get_bd_pins axis_avg_buffer_3/trigger]
  connect_bd_net -net qick_processor_0_trig_16_o [get_bd_pins qick_processor_0/trig_16_o] [get_bd_pins axis_avg_buffer_4/trigger]
  connect_bd_net -net qick_processor_0_trig_17_o [get_bd_pins qick_processor_0/trig_17_o] [get_bd_pins axis_avg_buffer_5/trigger]
  connect_bd_net -net qick_processor_0_trig_18_o [get_bd_pins qick_processor_0/trig_18_o] [get_bd_pins axis_avg_buffer_6/trigger]
  connect_bd_net -net qick_processor_0_trig_19_o [get_bd_pins qick_processor_0/trig_19_o] [get_bd_pins axis_avg_buffer_7/trigger]
  connect_bd_net -net qick_processor_0_trig_20_o [get_bd_pins qick_processor_0/trig_20_o] [get_bd_pins axis_avg_buffer_8/trigger]
  connect_bd_net -net qick_processor_0_trig_21_o [get_bd_pins qick_processor_0/trig_21_o] [get_bd_pins axis_avg_buffer_9/trigger]
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
  connect_bd_net -net rst_adc0_x2_peripheral_aresetn [get_bd_pins rst_adc0_x2/peripheral_aresetn] [get_bd_pins axis_cdcsync_v1_0/m_axis_aresetn] [get_bd_pins axis_dyn_readout_v1_0/aresetn] [get_bd_pins axis_dyn_readout_v1_1/aresetn] [get_bd_pins sg_translator_2/aresetn] [get_bd_pins sg_translator_3/aresetn] [get_bd_pins ddr4/aresetn] [get_bd_pins axis_broadcaster_0/aresetn] [get_bd_pins axis_broadcaster_1/aresetn] [get_bd_pins axis_register_slice_2/aresetn] [get_bd_pins axis_register_slice_3/aresetn] [get_bd_pins axis_switch_ddr4/aresetn] [get_bd_pins axis_switch_mr/aresetn] [get_bd_pins usp_rf_data_converter_0/m0_axis_aresetn] [get_bd_pins mr_buffer_et_0/s00_axis_aresetn] [get_bd_pins usp_rf_data_converter_0/m2_axis_aresetn] [get_bd_pins qick_time_tagger_0/adc_aresetn] [get_bd_pins axis_register_slice_5/aresetn] [get_bd_pins axis_avg_buffer_0/s_axis_aresetn] [get_bd_pins axis_weighted_buffer_0/s_axis_aresetn] [get_bd_pins axis_pfb_readout_v4_0/aresetn] [get_bd_pins axis_broadcaster_10/aresetn] [get_bd_pins axis_broadcaster_9/aresetn] [get_bd_pins axis_broadcaster_8/aresetn] [get_bd_pins axis_broadcaster_7/aresetn] [get_bd_pins axis_broadcaster_6/aresetn] [get_bd_pins axis_broadcaster_5/aresetn] [get_bd_pins axis_broadcaster_4/aresetn] [get_bd_pins axis_broadcaster_3/aresetn] [get_bd_pins axis_avg_buffer_2/s_axis_aresetn] [get_bd_pins axis_avg_buffer_3/s_axis_aresetn] [get_bd_pins axis_avg_buffer_4/s_axis_aresetn] [get_bd_pins axis_avg_buffer_5/s_axis_aresetn] [get_bd_pins axis_avg_buffer_6/s_axis_aresetn] [get_bd_pins axis_avg_buffer_7/s_axis_aresetn] [get_bd_pins axis_avg_buffer_8/s_axis_aresetn] [get_bd_pins axis_avg_buffer_9/s_axis_aresetn]
  connect_bd_net -net rst_dac1_peripheral_aresetn [get_bd_pins rst_dac2/peripheral_aresetn] [get_bd_pins axis_cdcsync_v1_0/s_axis_aresetn] [get_bd_pins axis_register_slice_0/aresetn] [get_bd_pins axis_signal_gen_v6_0/aresetn] [get_bd_pins sg_translator_0/aresetn] [get_bd_pins usp_rf_data_converter_0/s0_axis_aresetn] [get_bd_pins usp_rf_data_converter_0/s2_axis_aresetn] [get_bd_pins qick_processor_0/t_resetn] [get_bd_pins clk_core/resetn] [get_bd_pins sg_translator_1/aresetn]
  connect_bd_net -net rst_dac2_interconnect_aresetn [get_bd_pins rst_dac2/interconnect_aresetn] [get_bd_pins axis_sg_mixmux8_v1_0/aresetn]
  connect_bd_net -net rst_ps8_0_99M_peripheral_aresetn [get_bd_pins rst_100/peripheral_aresetn] [get_bd_pins axi_intc_0/s_axi_aresetn] [get_bd_pins axis_signal_gen_v6_0/s0_axis_aresetn] [get_bd_pins axis_signal_gen_v6_0/s_axi_aresetn] [get_bd_pins ddr4/s_axi_aresetn] [get_bd_pins axi_dma_avg/axi_resetn] [get_bd_pins axi_dma_buf/axi_resetn] [get_bd_pins axi_dma_gen/axi_resetn] [get_bd_pins axi_dma_mr/axi_resetn] [get_bd_pins axi_dma_tproc/axi_resetn] [get_bd_pins axi_smc/aresetn] [get_bd_pins axis_cc_avg_0/s_axis_aresetn] [get_bd_pins axis_switch_avg/aresetn] [get_bd_pins axis_switch_avg/s_axi_ctrl_aresetn] [get_bd_pins axis_switch_buf/aresetn] [get_bd_pins axis_switch_buf/s_axi_ctrl_aresetn] [get_bd_pins axis_switch_ddr4/s_axi_ctrl_aresetn] [get_bd_pins axis_switch_gen/aresetn] [get_bd_pins axis_switch_gen/s_axi_ctrl_aresetn] [get_bd_pins axis_switch_mr/s_axi_ctrl_aresetn] [get_bd_pins ps8_0_axi_periph/ARESETN] [get_bd_pins ps8_0_axi_periph/S00_ARESETN] [get_bd_pins ps8_0_axi_periph/M00_ARESETN] [get_bd_pins ps8_0_axi_periph/M01_ARESETN] [get_bd_pins ps8_0_axi_periph/M02_ARESETN] [get_bd_pins ps8_0_axi_periph/M03_ARESETN] [get_bd_pins ps8_0_axi_periph/M04_ARESETN] [get_bd_pins ps8_0_axi_periph/M05_ARESETN] [get_bd_pins ps8_0_axi_periph/M06_ARESETN] [get_bd_pins ps8_0_axi_periph/M07_ARESETN] [get_bd_pins ps8_0_axi_periph/M08_ARESETN] [get_bd_pins ps8_0_axi_periph/M09_ARESETN] [get_bd_pins ps8_0_axi_periph/M10_ARESETN] [get_bd_pins ps8_0_axi_periph/M11_ARESETN] [get_bd_pins ps8_0_axi_periph/M12_ARESETN] [get_bd_pins ps8_0_axi_periph/M13_ARESETN] [get_bd_pins ps8_0_axi_periph/M14_ARESETN] [get_bd_pins ps8_0_axi_periph/M15_ARESETN] [get_bd_pins ps8_0_axi_periph/M16_ARESETN] [get_bd_pins ps8_0_axi_periph/M17_ARESETN] [get_bd_pins ps8_0_axi_periph/M18_ARESETN] [get_bd_pins ps8_0_axi_periph/M19_ARESETN] [get_bd_pins ps8_0_axi_periph/M20_ARESETN] [get_bd_pins usp_rf_data_converter_0/s_axi_aresetn] [get_bd_pins mr_buffer_et_0/s00_axi_aresetn] [get_bd_pins mr_buffer_et_0/m00_axis_aresetn] [get_bd_pins qick_processor_0/ps_resetn] [get_bd_pins axis_cc_avg_2/s_axis_aresetn] [get_bd_pins qick_time_tagger_0/ps_aresetn] [get_bd_pins axi_dma_tt/axi_resetn] [get_bd_pins ps8_0_axi_periph/M21_ARESETN] [get_bd_pins axis_avg_buffer_0/s_axi_aresetn] [get_bd_pins axis_avg_buffer_0/m_axis_aresetn] [get_bd_pins axis_weighted_buffer_0/s_axi_aresetn] [get_bd_pins axis_weighted_buffer_0/m_axis_aresetn] [get_bd_pins axis_sg_mixmux8_v1_0/s_axi_aresetn] [get_bd_pins axis_pfb_readout_v4_0/s_axi_aresetn] [get_bd_pins axis_avg_buffer_2/s_axi_aresetn] [get_bd_pins axis_avg_buffer_2/m_axis_aresetn] [get_bd_pins axis_avg_buffer_3/s_axi_aresetn] [get_bd_pins axis_avg_buffer_3/m_axis_aresetn] [get_bd_pins axis_avg_buffer_4/s_axi_aresetn] [get_bd_pins axis_avg_buffer_4/m_axis_aresetn] [get_bd_pins axis_avg_buffer_5/s_axi_aresetn] [get_bd_pins axis_avg_buffer_5/m_axis_aresetn] [get_bd_pins axis_avg_buffer_6/s_axi_aresetn] [get_bd_pins axis_avg_buffer_6/m_axis_aresetn] [get_bd_pins axis_avg_buffer_7/s_axi_aresetn] [get_bd_pins axis_avg_buffer_7/m_axis_aresetn] [get_bd_pins axis_avg_buffer_8/s_axi_aresetn] [get_bd_pins axis_avg_buffer_8/m_axis_aresetn] [get_bd_pins axis_avg_buffer_9/s_axi_aresetn] [get_bd_pins axis_avg_buffer_9/m_axis_aresetn] [get_bd_pins axis_clock_converter_0/s_axis_aresetn] [get_bd_pins axis_clock_converter_1/s_axis_aresetn] [get_bd_pins axis_clock_converter_2/s_axis_aresetn] [get_bd_pins axis_clock_converter_3/s_axis_aresetn] [get_bd_pins axis_clock_converter_4/s_axis_aresetn] [get_bd_pins axis_clock_converter_5/s_axis_aresetn] [get_bd_pins axis_clock_converter_6/s_axis_aresetn] [get_bd_pins axis_clock_converter_7/s_axis_aresetn] [get_bd_pins ps8_0_axi_periph/M22_ARESETN] [get_bd_pins ps8_0_axi_periph/M23_ARESETN] [get_bd_pins ps8_0_axi_periph/M24_ARESETN] [get_bd_pins ps8_0_axi_periph/M25_ARESETN] [get_bd_pins ps8_0_axi_periph/M26_ARESETN] [get_bd_pins ps8_0_axi_periph/M27_ARESETN] [get_bd_pins ps8_0_axi_periph/M28_ARESETN] [get_bd_pins ps8_0_axi_periph/M29_ARESETN]
  connect_bd_net -net rst_tproc_peripheral_aresetn [get_bd_pins rst_core/peripheral_aresetn] [get_bd_pins axis_cc_avg_0/m_axis_aresetn] [get_bd_pins qick_processor_0/c_resetn] [get_bd_pins axis_cc_avg_2/m_axis_aresetn] [get_bd_pins qick_time_tagger_0/c_aresetn] [get_bd_pins axis_clock_converter_0/m_axis_aresetn] [get_bd_pins axis_clock_converter_1/m_axis_aresetn] [get_bd_pins axis_clock_converter_2/m_axis_aresetn] [get_bd_pins axis_clock_converter_3/m_axis_aresetn] [get_bd_pins axis_clock_converter_4/m_axis_aresetn] [get_bd_pins axis_clock_converter_5/m_axis_aresetn] [get_bd_pins axis_clock_converter_6/m_axis_aresetn] [get_bd_pins axis_clock_converter_7/m_axis_aresetn]
  connect_bd_net -net usp_rf_data_converter_0_clk_adc0 [get_bd_pins usp_rf_data_converter_0/clk_adc0] [get_bd_pins rst_adc0/slowest_sync_clk] [get_bd_pins clk_adc0_x2/clk_in1]
  connect_bd_net -net usp_rf_data_converter_0_clk_dac2 [get_bd_pins usp_rf_data_converter_0/clk_dac2] [get_bd_pins axis_cdcsync_v1_0/s_axis_aclk] [get_bd_pins axis_register_slice_0/aclk] [get_bd_pins axis_signal_gen_v6_0/aclk] [get_bd_pins rst_dac2/slowest_sync_clk] [get_bd_pins sg_translator_0/aclk] [get_bd_pins usp_rf_data_converter_0/s0_axis_aclk] [get_bd_pins usp_rf_data_converter_0/s2_axis_aclk] [get_bd_pins qick_processor_0/t_clk_i] [get_bd_pins clk_core/clk_in1] [get_bd_pins axis_sg_mixmux8_v1_0/aclk] [get_bd_pins sg_translator_1/aclk]
  connect_bd_net -net usp_rf_data_converter_0_irq [get_bd_pins usp_rf_data_converter_0/irq] [get_bd_pins xlconcat_intc/In6]
  connect_bd_net -net xlconcat_0_dout [get_bd_pins xlconcat_intc/dout] [get_bd_pins axi_intc_0/intr]
  connect_bd_net -net zynq_ultra_ps_e_0_pl_clk0 [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] [get_bd_pins axi_intc_0/s_axi_aclk] [get_bd_pins axis_signal_gen_v6_0/s0_axis_aclk] [get_bd_pins axis_signal_gen_v6_0/s_axi_aclk] [get_bd_pins rst_100/slowest_sync_clk] [get_bd_pins ddr4/s_axi_aclk] [get_bd_pins axi_dma_avg/s_axi_lite_aclk] [get_bd_pins axi_dma_avg/m_axi_s2mm_aclk] [get_bd_pins axi_dma_buf/s_axi_lite_aclk] [get_bd_pins axi_dma_buf/m_axi_s2mm_aclk] [get_bd_pins axi_dma_gen/s_axi_lite_aclk] [get_bd_pins axi_dma_gen/m_axi_mm2s_aclk] [get_bd_pins axi_dma_mr/s_axi_lite_aclk] [get_bd_pins axi_dma_mr/m_axi_s2mm_aclk] [get_bd_pins axi_dma_tproc/s_axi_lite_aclk] [get_bd_pins axi_dma_tproc/m_axi_mm2s_aclk] [get_bd_pins axi_dma_tproc/m_axi_s2mm_aclk] [get_bd_pins axi_smc/aclk] [get_bd_pins axis_cc_avg_0/s_axis_aclk] [get_bd_pins axis_switch_avg/aclk] [get_bd_pins axis_switch_avg/s_axi_ctrl_aclk] [get_bd_pins axis_switch_buf/aclk] [get_bd_pins axis_switch_buf/s_axi_ctrl_aclk] [get_bd_pins axis_switch_ddr4/s_axi_ctrl_aclk] [get_bd_pins axis_switch_gen/aclk] [get_bd_pins axis_switch_gen/s_axi_ctrl_aclk] [get_bd_pins axis_switch_mr/s_axi_ctrl_aclk] [get_bd_pins ps8_0_axi_periph/ACLK] [get_bd_pins ps8_0_axi_periph/S00_ACLK] [get_bd_pins ps8_0_axi_periph/M00_ACLK] [get_bd_pins ps8_0_axi_periph/M01_ACLK] [get_bd_pins ps8_0_axi_periph/M02_ACLK] [get_bd_pins ps8_0_axi_periph/M03_ACLK] [get_bd_pins ps8_0_axi_periph/M04_ACLK] [get_bd_pins ps8_0_axi_periph/M05_ACLK] [get_bd_pins ps8_0_axi_periph/M06_ACLK] [get_bd_pins ps8_0_axi_periph/M07_ACLK] [get_bd_pins ps8_0_axi_periph/M08_ACLK] [get_bd_pins ps8_0_axi_periph/M09_ACLK] [get_bd_pins ps8_0_axi_periph/M10_ACLK] [get_bd_pins ps8_0_axi_periph/M11_ACLK] [get_bd_pins ps8_0_axi_periph/M12_ACLK] [get_bd_pins ps8_0_axi_periph/M13_ACLK] [get_bd_pins ps8_0_axi_periph/M14_ACLK] [get_bd_pins ps8_0_axi_periph/M15_ACLK] [get_bd_pins ps8_0_axi_periph/M16_ACLK] [get_bd_pins ps8_0_axi_periph/M17_ACLK] [get_bd_pins ps8_0_axi_periph/M18_ACLK] [get_bd_pins ps8_0_axi_periph/M19_ACLK] [get_bd_pins ps8_0_axi_periph/M20_ACLK] [get_bd_pins usp_rf_data_converter_0/s_axi_aclk] [get_bd_pins zynq_ultra_ps_e_0/maxihpm0_fpd_aclk] [get_bd_pins zynq_ultra_ps_e_0/saxihpc0_fpd_aclk] [get_bd_pins mr_buffer_et_0/s00_axi_aclk] [get_bd_pins mr_buffer_et_0/m00_axis_aclk] [get_bd_pins qick_processor_0/ps_clk_i] [get_bd_pins axis_cc_avg_2/s_axis_aclk] [get_bd_pins qick_time_tagger_0/ps_clk] [get_bd_pins axi_dma_tt/s_axi_lite_aclk] [get_bd_pins axi_dma_tt/m_axi_s2mm_aclk] [get_bd_pins ps8_0_axi_periph/M21_ACLK] [get_bd_pins axis_avg_buffer_0/s_axi_aclk] [get_bd_pins axis_avg_buffer_0/m_axis_aclk] [get_bd_pins axis_weighted_buffer_0/s_axi_aclk] [get_bd_pins axis_weighted_buffer_0/m_axis_aclk] [get_bd_pins axis_sg_mixmux8_v1_0/s_axi_aclk] [get_bd_pins axis_pfb_readout_v4_0/s_axi_aclk] [get_bd_pins axis_avg_buffer_2/s_axi_aclk] [get_bd_pins axis_avg_buffer_2/m_axis_aclk] [get_bd_pins axis_avg_buffer_3/s_axi_aclk] [get_bd_pins axis_avg_buffer_3/m_axis_aclk] [get_bd_pins axis_avg_buffer_4/s_axi_aclk] [get_bd_pins axis_avg_buffer_4/m_axis_aclk] [get_bd_pins axis_avg_buffer_5/s_axi_aclk] [get_bd_pins axis_avg_buffer_5/m_axis_aclk] [get_bd_pins axis_avg_buffer_6/s_axi_aclk] [get_bd_pins axis_avg_buffer_6/m_axis_aclk] [get_bd_pins axis_avg_buffer_7/s_axi_aclk] [get_bd_pins axis_avg_buffer_7/m_axis_aclk] [get_bd_pins axis_avg_buffer_8/s_axi_aclk] [get_bd_pins axis_avg_buffer_8/m_axis_aclk] [get_bd_pins axis_avg_buffer_9/s_axi_aclk] [get_bd_pins axis_avg_buffer_9/m_axis_aclk] [get_bd_pins axis_clock_converter_0/s_axis_aclk] [get_bd_pins axis_clock_converter_1/s_axis_aclk] [get_bd_pins axis_clock_converter_2/s_axis_aclk] [get_bd_pins axis_clock_converter_3/s_axis_aclk] [get_bd_pins axis_clock_converter_4/s_axis_aclk] [get_bd_pins axis_clock_converter_5/s_axis_aclk] [get_bd_pins axis_clock_converter_6/s_axis_aclk] [get_bd_pins axis_clock_converter_7/s_axis_aclk] [get_bd_pins ps8_0_axi_periph/M22_ACLK] [get_bd_pins ps8_0_axi_periph/M23_ACLK] [get_bd_pins ps8_0_axi_periph/M24_ACLK] [get_bd_pins ps8_0_axi_periph/M25_ACLK] [get_bd_pins ps8_0_axi_periph/M26_ACLK] [get_bd_pins ps8_0_axi_periph/M27_ACLK] [get_bd_pins ps8_0_axi_periph/M28_ACLK] [get_bd_pins ps8_0_axi_periph/M29_ACLK]
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
  assign_bd_address -offset 0x000400219000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axi_dma_tt/S_AXI_LITE/Reg] -force
  assign_bd_address -offset 0x000400205000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axi_intc_0/S_AXI/Reg] -force
  assign_bd_address -offset 0x000400206000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_avg_buffer_0/s_axi/reg0] -force
  assign_bd_address -offset 0x000400207000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_avg_buffer_2/s_axi/reg0] -force
  assign_bd_address -offset 0x000400208000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_avg_buffer_3/s_axi/reg0] -force
  assign_bd_address -offset 0x000400209000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_avg_buffer_4/s_axi/reg0] -force
  assign_bd_address -offset 0x00040020A000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_avg_buffer_5/s_axi/reg0] -force
  assign_bd_address -offset 0x00040020B000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_avg_buffer_6/s_axi/reg0] -force
  assign_bd_address -offset 0x00040020C000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_avg_buffer_7/s_axi/reg0] -force
  assign_bd_address -offset 0x00040020D000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_avg_buffer_8/s_axi/reg0] -force
  assign_bd_address -offset 0x00040020E000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_avg_buffer_9/s_axi/reg0] -force
  assign_bd_address -offset 0x000400210000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs ddr4/axis_buffer_ddr_0/s_axi/reg0] -force
  assign_bd_address -offset 0x00040020F000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_pfb_readout_v4_0/s_axi/reg0] -force
  assign_bd_address -offset 0x000400211000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_sg_mixmux8_v1_0/s_axi/reg0] -force
  assign_bd_address -offset 0x000400212000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_signal_gen_v6_0/s_axi/reg0] -force
  assign_bd_address -offset 0x000400213000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_switch_avg/S_AXI_CTRL/Reg] -force
  assign_bd_address -offset 0x000400214000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_switch_buf/S_AXI_CTRL/Reg] -force
  assign_bd_address -offset 0x000400215000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_switch_ddr4/S_AXI_CTRL/Reg] -force
  assign_bd_address -offset 0x000400216000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_switch_gen/S_AXI_CTRL/Reg] -force
  assign_bd_address -offset 0x000400217000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_switch_mr/S_AXI_CTRL/Reg] -force
  assign_bd_address -offset 0x00040021A000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_weighted_buffer_0/s_axi/reg0] -force
  assign_bd_address -offset 0x000500000000 -range 0x000100000000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs ddr4/ddr4_0/C0_DDR4_MEMORY_MAP/C0_DDR4_ADDRESS_BLOCK] -force
  assign_bd_address -offset 0x000400218000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs mr_buffer_et_0/s00_axi/reg0] -force
  assign_bd_address -offset 0x000400010000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs qick_processor_0/s_axi/reg0] -force
  assign_bd_address -offset 0x00040021B000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs qick_time_tagger_0/s_axi/reg0] -force
  assign_bd_address -offset 0x000400240000 -range 0x00040000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs usp_rf_data_converter_0/s_axi/Reg] -force
  assign_bd_address -offset 0x00000000 -range 0x80000000 -target_address_space [get_bd_addr_spaces axi_dma_tt/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_DDR_LOW] -force
  assign_bd_address -offset 0x00000000 -range 0x000100000000 -target_address_space [get_bd_addr_spaces ddr4/axis_buffer_ddr_0/m_axi] [get_bd_addr_segs ddr4/ddr4_0/C0_DDR4_MEMORY_MAP/C0_DDR4_ADDRESS_BLOCK] -force

  # Exclude Address Segments
  exclude_bd_addr_seg -target_address_space [get_bd_addr_spaces axi_dma_avg/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_DDR_HIGH]
  exclude_bd_addr_seg -offset 0xFF000000 -range 0x01000000 -target_address_space [get_bd_addr_spaces axi_dma_avg/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_LPS_OCM]
  exclude_bd_addr_seg -target_address_space [get_bd_addr_spaces axi_dma_buf/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_DDR_HIGH]
  exclude_bd_addr_seg -offset 0xFF000000 -range 0x01000000 -target_address_space [get_bd_addr_spaces axi_dma_buf/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_LPS_OCM]
  exclude_bd_addr_seg -target_address_space [get_bd_addr_spaces axi_dma_gen/Data_MM2S] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_DDR_HIGH]
  exclude_bd_addr_seg -offset 0xFF000000 -range 0x01000000 -target_address_space [get_bd_addr_spaces axi_dma_gen/Data_MM2S] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_LPS_OCM]
  exclude_bd_addr_seg -target_address_space [get_bd_addr_spaces axi_dma_mr/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_DDR_HIGH]
  exclude_bd_addr_seg -offset 0xFF000000 -range 0x01000000 -target_address_space [get_bd_addr_spaces axi_dma_mr/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_LPS_OCM]
  exclude_bd_addr_seg -target_address_space [get_bd_addr_spaces axi_dma_tproc/Data_MM2S] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_DDR_HIGH]
  exclude_bd_addr_seg -offset 0xFF000000 -range 0x01000000 -target_address_space [get_bd_addr_spaces axi_dma_tproc/Data_MM2S] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_LPS_OCM]
  exclude_bd_addr_seg -target_address_space [get_bd_addr_spaces axi_dma_tproc/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_DDR_HIGH]
  exclude_bd_addr_seg -offset 0xFF000000 -range 0x01000000 -target_address_space [get_bd_addr_spaces axi_dma_tproc/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_LPS_OCM]
  exclude_bd_addr_seg -target_address_space [get_bd_addr_spaces axi_dma_tt/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_DDR_HIGH]
  exclude_bd_addr_seg -offset 0xFF000000 -range 0x01000000 -target_address_space [get_bd_addr_spaces axi_dma_tt/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_LPS_OCM]

  # Perform GUI Layout
  regenerate_bd_layout -layout_string {
   "ActiveEmotionalView":"Default View",
   "Default View_ScaleFactor":"0.198261",
   "Default View_TopLeft":"2386,0",
   "Display-IntfAXI4Lite":"true",
   "Display-IntfAXIStream":"true",
   "Display-IntfOthers":"true",
   "Display-IntfTypeAXIMM":"true",
   "ExpandedHierarchyInLayout":"",
   "guistr":"# # String gsaved with Nlview 7.5.8 2022-09-21 7111 VDI=41 GEI=38 GUI=JA:10.0
#  -string -flagsOSRD
preplace port adc0_clk -pg 1 -lvl 0 -x -10 -y 3120 -defaultsOSRD
preplace port dac0_clk -pg 1 -lvl 0 -x -10 -y 3180 -defaultsOSRD
preplace port dac2_clk -pg 1 -lvl 0 -x -10 -y 3210 -defaultsOSRD
preplace port ddr4_pl -pg 1 -lvl 24 -x 11050 -y 2610 -defaultsOSRD
preplace port sys_clk_ddr4 -pg 1 -lvl 24 -x 11050 -y 2470 -defaultsOSRD -right
preplace port sysref_in -pg 1 -lvl 0 -x -10 -y 3520 -defaultsOSRD
preplace port vin0_01 -pg 1 -lvl 0 -x -10 -y 3240 -defaultsOSRD
preplace port vin0_23 -pg 1 -lvl 0 -x -10 -y 3270 -defaultsOSRD
preplace port vout00 -pg 1 -lvl 24 -x 11050 -y 3280 -defaultsOSRD
preplace port vout20 -pg 1 -lvl 24 -x 11050 -y 3310 -defaultsOSRD
preplace port adc2_clk -pg 1 -lvl 0 -x -10 -y 3150 -defaultsOSRD
preplace port vin2_01 -pg 1 -lvl 0 -x -10 -y 3300 -defaultsOSRD
preplace port vin2_23 -pg 1 -lvl 0 -x -10 -y 3330 -defaultsOSRD
preplace port port-id_PMOD0_0 -pg 1 -lvl 0 -x -10 -y 4040 -defaultsOSRD -left
preplace port port-id_PMOD0_1 -pg 1 -lvl 0 -x -10 -y 4070 -defaultsOSRD -left
preplace port port-id_PMOD0_2 -pg 1 -lvl 0 -x -10 -y 4100 -defaultsOSRD -left
preplace port port-id_PMOD0_3 -pg 1 -lvl 0 -x -10 -y 4130 -defaultsOSRD -left
preplace port port-id_PMOD0_4 -pg 1 -lvl 0 -x -10 -y 4160 -defaultsOSRD -left
preplace port port-id_PMOD0_5 -pg 1 -lvl 0 -x -10 -y 4280 -defaultsOSRD -left
preplace port port-id_PMOD0_6 -pg 1 -lvl 0 -x -10 -y 4220 -defaultsOSRD -left
preplace port port-id_PMOD0_7 -pg 1 -lvl 0 -x -10 -y 4250 -defaultsOSRD -left
preplace port port-id_PMOD1_0 -pg 1 -lvl 0 -x -10 -y 4190 -defaultsOSRD
preplace inst axi_intc_0 -pg 1 -lvl 3 -x 1080 -y 1820 -defaultsOSRD
preplace inst axis_cdcsync_v1_0 -pg 1 -lvl 14 -x 6800 -y 3820 -defaultsOSRD
preplace inst axis_dyn_readout_v1_0 -pg 1 -lvl 16 -x 7630 -y 3590 -defaultsOSRD
preplace inst axis_dyn_readout_v1_1 -pg 1 -lvl 9 -x 3780 -y 3490 -defaultsOSRD
preplace inst axis_register_slice_0 -pg 1 -lvl 6 -x 2480 -y 3720 -defaultsOSRD
preplace inst axis_signal_gen_v6_0 -pg 1 -lvl 5 -x 2020 -y 3510 -defaultsOSRD
preplace inst rst_100 -pg 1 -lvl 1 -x 210 -y 3410 -defaultsOSRD
preplace inst rst_adc0 -pg 1 -lvl 4 -x 1560 -y 3710 -defaultsOSRD
preplace inst rst_adc0_x2 -pg 1 -lvl 6 -x 2480 -y 3930 -defaultsOSRD -resize 320 156
preplace inst rst_core -pg 1 -lvl 11 -x 4890 -y 3970 -defaultsOSRD -resize 320 156
preplace inst rst_dac2 -pg 1 -lvl 3 -x 1080 -y 3790 -defaultsOSRD -resize 320 156
preplace inst sg_translator_0 -pg 1 -lvl 4 -x 1560 -y 3930 -defaultsOSRD
preplace inst sg_translator_2 -pg 1 -lvl 15 -x 7230 -y 3560 -defaultsOSRD
preplace inst sg_translator_3 -pg 1 -lvl 8 -x 3310 -y 3690 -defaultsOSRD
preplace inst xlconcat_intc -pg 1 -lvl 2 -x 570 -y 1100 -defaultsOSRD
preplace inst ddr4 -pg 1 -lvl 23 -x 10900 -y 2620 -defaultsOSRD
preplace inst axi_dma_avg -pg 1 -lvl 20 -x 9500 -y 1110 -defaultsOSRD
preplace inst axi_dma_buf -pg 1 -lvl 20 -x 9500 -y 1490 -defaultsOSRD -resize 320 156
preplace inst axi_dma_gen -pg 1 -lvl 3 -x 1080 -y 1640 -defaultsOSRD
preplace inst axi_dma_mr -pg 1 -lvl 20 -x 9500 -y 1310 -defaultsOSRD -resize 320 156
preplace inst axi_dma_tproc -pg 1 -lvl 12 -x 5670 -y 820 -defaultsOSRD
preplace inst axi_smc -pg 1 -lvl 21 -x 9890 -y 1530 -defaultsOSRD
preplace inst axis_broadcaster_0 -pg 1 -lvl 17 -x 7980 -y 3490 -defaultsOSRD
preplace inst axis_broadcaster_1 -pg 1 -lvl 10 -x 4220 -y 2470 -defaultsOSRD
preplace inst axis_cc_avg_0 -pg 1 -lvl 12 -x 5670 -y 3430 -defaultsOSRD
preplace inst axis_register_slice_2 -pg 1 -lvl 15 -x 7230 -y 3790 -defaultsOSRD -resize 180 116
preplace inst axis_register_slice_3 -pg 1 -lvl 8 -x 3310 -y 3480 -defaultsOSRD -resize 180 116
preplace inst axis_switch_avg -pg 1 -lvl 19 -x 9030 -y 1320 -defaultsOSRD -resize 240 196
preplace inst axis_switch_buf -pg 1 -lvl 19 -x 9030 -y 1540 -defaultsOSRD -resize 240 196
preplace inst axis_switch_ddr4 -pg 1 -lvl 22 -x 10410 -y 1870 -defaultsOSRD
preplace inst axis_switch_gen -pg 1 -lvl 4 -x 1560 -y 2530 -defaultsOSRD
preplace inst axis_switch_mr -pg 1 -lvl 18 -x 8410 -y 3720 -defaultsOSRD
preplace inst clk_adc0_x2 -pg 1 -lvl 5 -x 2020 -y 3760 -defaultsOSRD
preplace inst clk_core -pg 1 -lvl 10 -x 4220 -y 3940 -defaultsOSRD -resize 160 96
preplace inst ps8_0_axi_periph -pg 1 -lvl 2 -x 570 -y 2010 -defaultsOSRD
preplace inst usp_rf_data_converter_0 -pg 1 -lvl 7 -x 2870 -y 3310 -defaultsOSRD
preplace inst zynq_ultra_ps_e_0 -pg 1 -lvl 22 -x 10410 -y 2440 -defaultsOSRD
preplace inst mr_buffer_et_0 -pg 1 -lvl 19 -x 9030 -y 3060 -defaultsOSRD
preplace inst qick_processor_0 -pg 1 -lvl 13 -x 6240 -y 2900 -defaultsOSRD
preplace inst axis_cc_avg_2 -pg 1 -lvl 12 -x 5670 -y 2930 -defaultsOSRD -resize 220 156
preplace inst qick_time_tagger_0 -pg 1 -lvl 19 -x 9030 -y 3470 -defaultsOSRD
preplace inst axi_dma_tt -pg 1 -lvl 20 -x 9500 -y 1670 -defaultsOSRD -resize 320 156
preplace inst axis_register_slice_5 -pg 1 -lvl 18 -x 8410 -y 3520 -defaultsOSRD
preplace inst axis_avg_buffer_0 -pg 1 -lvl 18 -x 8410 -y 2860 -defaultsOSRD
preplace inst axis_weighted_buffer_0 -pg 1 -lvl 11 -x 4890 -y 2550 -defaultsOSRD
preplace inst axis_pfb_readout_v4_0 -pg 1 -lvl 9 -x 3780 -y 2070 -defaultsOSRD
preplace inst axis_sg_mixmux8_v1_0 -pg 1 -lvl 6 -x 2480 -y 3440 -defaultsOSRD
preplace inst axis_broadcaster_3 -pg 1 -lvl 10 -x 4220 -y 840 -defaultsOSRD
preplace inst axis_broadcaster_4 -pg 1 -lvl 10 -x 4220 -y 700 -defaultsOSRD
preplace inst axis_broadcaster_5 -pg 1 -lvl 10 -x 4220 -y 2000 -defaultsOSRD
preplace inst axis_broadcaster_6 -pg 1 -lvl 10 -x 4220 -y 1860 -defaultsOSRD
preplace inst axis_broadcaster_7 -pg 1 -lvl 10 -x 4220 -y 2140 -defaultsOSRD
preplace inst axis_broadcaster_8 -pg 1 -lvl 10 -x 4220 -y 2280 -defaultsOSRD
preplace inst axis_broadcaster_9 -pg 1 -lvl 10 -x 4220 -y 330 -defaultsOSRD
preplace inst axis_broadcaster_10 -pg 1 -lvl 10 -x 4220 -y 2630 -defaultsOSRD
preplace inst axis_avg_buffer_2 -pg 1 -lvl 11 -x 4890 -y 700 -defaultsOSRD
preplace inst axis_avg_buffer_3 -pg 1 -lvl 11 -x 4890 -y 140 -defaultsOSRD
preplace inst axis_avg_buffer_4 -pg 1 -lvl 11 -x 4890 -y 1920 -defaultsOSRD
preplace inst axis_avg_buffer_5 -pg 1 -lvl 11 -x 4890 -y 1020 -defaultsOSRD
preplace inst axis_avg_buffer_6 -pg 1 -lvl 11 -x 4890 -y 1340 -defaultsOSRD
preplace inst axis_avg_buffer_7 -pg 1 -lvl 11 -x 4890 -y 1600 -defaultsOSRD
preplace inst axis_avg_buffer_8 -pg 1 -lvl 11 -x 4890 -y 400 -defaultsOSRD
preplace inst axis_avg_buffer_9 -pg 1 -lvl 11 -x 4890 -y 3000 -defaultsOSRD
preplace inst axis_clock_converter_0 -pg 1 -lvl 12 -x 5670 -y 3130 -defaultsOSRD
preplace inst axis_clock_converter_1 -pg 1 -lvl 12 -x 5670 -y 1640 -defaultsOSRD
preplace inst axis_clock_converter_2 -pg 1 -lvl 12 -x 5670 -y 2360 -defaultsOSRD
preplace inst axis_clock_converter_3 -pg 1 -lvl 12 -x 5670 -y 2540 -defaultsOSRD
preplace inst axis_clock_converter_4 -pg 1 -lvl 12 -x 5670 -y 1950 -defaultsOSRD
preplace inst axis_clock_converter_5 -pg 1 -lvl 12 -x 5670 -y 2150 -defaultsOSRD
preplace inst axis_clock_converter_6 -pg 1 -lvl 12 -x 5670 -y 2720 -defaultsOSRD
preplace inst axis_clock_converter_7 -pg 1 -lvl 12 -x 5670 -y 3630 -defaultsOSRD
preplace inst sg_translator_1 -pg 1 -lvl 5 -x 2020 -y 3990 -defaultsOSRD
preplace netloc PMOD1_0_1 1 0 13 NJ 4190 NJ 4190 NJ 4190 NJ 4190 NJ 4190 NJ 4190 NJ 4190 NJ 4190 NJ 4190 NJ 4190 NJ 4190 NJ 4190 5990J
preplace netloc axi_dma_avg_s2mm_introut 1 1 20 390 1270 NJ 1270 NJ 1270 NJ 1270 NJ 1270 NJ 1270 NJ 1270 NJ 1270 NJ 1270 4570J 2120 5380J 1810 NJ 1810 NJ 1810 NJ 1810 NJ 1810 NJ 1810 NJ 1810 NJ 1810 NJ 1810 9700
preplace netloc axi_dma_buf_s2mm_introut 1 1 20 430 1230 740J 1170 NJ 1170 NJ 1170 NJ 1170 NJ 1170 NJ 1170 NJ 1170 NJ 1170 NJ 1170 5360J 1190 NJ 1190 NJ 1190 NJ 1190 NJ 1190 NJ 1190 NJ 1190 NJ 1190 9300J 1210 9680
preplace netloc axi_dma_gen_mm2s_introut 1 1 3 380 1290 NJ 1290 1260
preplace netloc axi_dma_readout_s2mm_introut 1 1 20 420 1240 730J 1160 NJ 1160 NJ 1160 NJ 1160 NJ 1160 NJ 1160 NJ 1160 NJ 1160 NJ 1160 NJ 1160 6040J 1750 NJ 1750 NJ 1750 NJ 1750 NJ 1750 NJ 1750 NJ 1750 9280J 1780 9690
preplace netloc axi_dma_tproc_mm2s_introut 1 1 12 430 940 NJ 940 NJ 940 NJ 940 NJ 940 NJ 940 NJ 940 NJ 940 NJ 940 4400J 870 5180J 940 5910
preplace netloc axi_dma_tproc_s2mm_introut 1 1 12 420 920 NJ 920 NJ 920 NJ 920 NJ 920 NJ 920 NJ 920 NJ 920 NJ 920 4390J 850 5260J 950 5840
preplace netloc axi_dma_tt_s2mm_introut 1 1 20 410 1250 760J 1180 NJ 1180 NJ 1180 NJ 1180 NJ 1180 NJ 1180 NJ 1180 NJ 1180 NJ 1180 5180J 1200 6030J 1770 NJ 1770 NJ 1770 NJ 1770 NJ 1770 NJ 1770 NJ 1770 9240J 1800 9680
preplace netloc axi_intc_0_irq 1 3 19 1290J 4090 NJ 4090 NJ 4090 NJ 4090 NJ 4090 NJ 4090 NJ 4090 NJ 4090 NJ 4090 5920J 2520 NJ 2520 NJ 2520 NJ 2520 NJ 2520 NJ 2520 NJ 2520 NJ 2520 NJ 2520 10090
preplace netloc clk_adc0_x2_clk_out1 1 5 18 2300 3620 2730 3620 3060 3400 3600 1910 4050 420 4540 3240 5110J 3850 NJ 3850 6610 3940 7010 3670 7460 3710 7820 3590 8220 2690 8830 2630 NJ 2630 NJ 2630 10100 2630 NJ
preplace netloc clk_adc0_x2_locked 1 5 1 2220 3770n
preplace netloc clk_tproc_clk_out1 1 10 9 4370 3670 5480 3280 6010 3280 NJ 3280 NJ 3280 NJ 3280 NJ 3280 8180J 3290 8610J
preplace netloc clk_tproc_locked 1 10 1 4370 3950n
preplace netloc ddr4_0_c0_ddr4_ui_clk 1 21 3 10120 2560 10740J 2460 11030
preplace netloc qick_processor_0_trig_0_o 1 13 5 NJ 2740 NJ 2740 NJ 2740 NJ 2740 8200
preplace netloc qick_processor_0_trig_10_o 1 0 14 NJ 4220 NJ 4220 NJ 4220 NJ 4220 NJ 4220 NJ 4220 NJ 4220 NJ 4220 NJ 4220 NJ 4220 NJ 4220 NJ 4220 NJ 4220 6480
preplace netloc qick_processor_0_trig_11_o 1 0 14 NJ 4250 NJ 4250 NJ 4250 NJ 4250 NJ 4250 NJ 4250 NJ 4250 NJ 4250 NJ 4250 NJ 4250 NJ 4250 NJ 4250 NJ 4250 6590
preplace netloc qick_processor_0_trig_12_o 1 10 4 4700 3270 NJ 3270 NJ 3270 6470
preplace netloc qick_processor_0_trig_13_o 1 13 6 NJ 3000 NJ 3000 NJ 3000 NJ 3000 NJ 3000 8590
preplace netloc qick_processor_0_trig_14_o 1 10 4 4690 3290 NJ 3290 NJ 3290 6460
preplace netloc qick_processor_0_trig_15_o 1 10 4 4680 3750 NJ 3750 NJ 3750 6580
preplace netloc qick_processor_0_trig_16_o 1 10 4 4670 3760 NJ 3760 NJ 3760 6570
preplace netloc qick_processor_0_trig_17_o 1 10 4 4660 3770 NJ 3770 NJ 3770 6560
preplace netloc qick_processor_0_trig_18_o 1 10 4 4650 3780 NJ 3780 NJ 3780 6540
preplace netloc qick_processor_0_trig_19_o 1 10 4 4640 3790 NJ 3790 NJ 3790 6520
preplace netloc qick_processor_0_trig_20_o 1 10 4 4630 3800 NJ 3800 NJ 3800 6450
preplace netloc qick_processor_0_trig_21_o 1 10 4 4620 3820 NJ 3820 NJ 3820 6440
preplace netloc qick_processor_0_trig_2_o 1 13 6 6600 2700 NJ 2700 NJ 2700 NJ 2700 NJ 2700 8640J
preplace netloc qick_processor_0_trig_3_o 1 13 10 6590 2650 NJ 2650 NJ 2650 NJ 2650 NJ 2650 NJ 2650 NJ 2650 NJ 2650 NJ 2650 NJ
preplace netloc qick_processor_0_trig_4_o 1 0 14 NJ 4040 NJ 4040 NJ 4040 NJ 4040 1820J 4100 NJ 4100 NJ 4100 NJ 4100 NJ 4100 NJ 4100 NJ 4100 NJ 4100 NJ 4100 6510
preplace netloc qick_processor_0_trig_5_o 1 0 14 NJ 4070 NJ 4070 NJ 4070 NJ 4070 1810J 4120 NJ 4120 NJ 4120 NJ 4120 NJ 4120 NJ 4120 NJ 4120 NJ 4120 NJ 4120 6550
preplace netloc qick_processor_0_trig_6_o 1 0 14 NJ 4100 NJ 4100 NJ 4100 NJ 4100 1780J 4130 NJ 4130 NJ 4130 NJ 4130 NJ 4130 NJ 4130 NJ 4130 NJ 4130 NJ 4130 6530
preplace netloc qick_processor_0_trig_7_o 1 0 14 NJ 4130 NJ 4130 NJ 4130 NJ 4130 1760J 4140 NJ 4140 NJ 4140 NJ 4140 NJ 4140 NJ 4140 NJ 4140 NJ 4140 NJ 4140 6500
preplace netloc qick_processor_0_trig_8_o 1 0 14 NJ 4160 NJ 4160 NJ 4160 NJ 4160 NJ 4160 NJ 4160 NJ 4160 NJ 4160 NJ 4160 NJ 4160 NJ 4160 NJ 4160 NJ 4160 6490
preplace netloc qick_processor_0_trig_9_o 1 0 14 NJ 4280 NJ 4280 NJ 4280 NJ 4280 NJ 4280 NJ 4280 NJ 4280 NJ 4280 NJ 4280 NJ 4280 NJ 4280 NJ 4280 NJ 4280 6600
preplace netloc rst_100_bus_struct_reset 1 1 22 430J 3290 NJ 3290 NJ 3290 NJ 3290 NJ 3290 2680J 3610 3070J 3570 3550J 3590 4070J 3530 NJ 3530 NJ 3530 5870J 2530 NJ 2530 NJ 2530 NJ 2530 NJ 2530 NJ 2530 NJ 2530 NJ 2530 NJ 2530 10020J 2640 10710
preplace netloc rst_adc0_peripheral_aresetn 1 4 1 N 3750
preplace netloc rst_adc0_x2_peripheral_aresetn 1 6 17 2720 3630 3090 3560 3570 1940 4060 430 4550 3250 5100J 3840 NJ 3840 6620 3950 7000 3660 7440 3490 7810 3570 8230 2710 8820 2610 NJ 2610 NJ 2610 10110 2610 NJ
preplace netloc rst_dac1_peripheral_aresetn 1 3 11 1330 3820 1800 3670 2280 3600 2740 3600 3080J 3580 3530J 3600 3960 3810 NJ 3810 NJ 3810 6030 3810 NJ
preplace netloc rst_dac2_interconnect_aresetn 1 3 3 1310J 3610 1770J 3660 2240
preplace netloc rst_ps8_0_99M_peripheral_aresetn 1 1 22 380 1300 870 1950 1320 2640 1780 3270 2300 3250 2730 2390 NJ 2390 3590 2390 3990J 2380 4530 2230 5350 3230 5880 2550 NJ 2550 NJ 2550 NJ 2550 NJ 2550 8170 2550 8750 1670 9270 1860 9750 1860 10070 2330 10730J
preplace netloc rst_tproc_peripheral_aresetn 1 11 8 5460 3300 6040 3300 NJ 3300 NJ 3300 NJ 3300 NJ 3300 NJ 3300 8600J
preplace netloc usp_rf_data_converter_0_clk_adc0 1 3 5 1360 3810 1810 3830 NJ 3830 NJ 3830 3000
preplace netloc usp_rf_data_converter_0_clk_dac2 1 2 12 900 3890 1340 3830 1790 3690 2270 3330 2660 3580 3020 3390 NJ 3390 4010 3830 NJ 3830 NJ 3830 6020 3830 NJ
preplace netloc usp_rf_data_converter_0_irq 1 1 7 400 2810 NJ 2810 NJ 2810 NJ 2810 NJ 2810 NJ 2810 3010
preplace netloc xlconcat_0_dout 1 2 1 900 1100n
preplace netloc zynq_ultra_ps_e_0_pl_clk0 1 0 23 40 2630 390 1310 850 1960 1300 2650 1770 3320 2290 3320 2670 2710 NJ 2710 3580 2710 NJ 2710 4520 2240 5320 3030 5980 2560 NJ 2560 NJ 2560 NJ 2560 NJ 2560 8160 2560 8710 1200 9290 1870 9740 1870 10040 2570 10720
preplace netloc zynq_ultra_ps_e_0_pl_resetn0 1 0 23 40 3770 NJ 3770 710 3900 1320 4110 NJ 4110 2300 4030 NJ 4030 NJ 4030 NJ 4030 NJ 4030 4700 4070 NJ 4070 NJ 4070 NJ 4070 NJ 4070 NJ 4070 NJ 4070 NJ 4070 NJ 4070 NJ 4070 NJ 4070 NJ 4070 10700
preplace netloc adc0_clk_1 1 0 7 NJ 3120 NJ 3120 NJ 3120 NJ 3120 NJ 3120 NJ 3120 2680J
preplace netloc adc2_clk_1 1 0 7 NJ 3150 NJ 3150 NJ 3150 NJ 3150 NJ 3150 NJ 3150 2740J
preplace netloc axi_dma_avg_M_AXI_S2MM 1 20 1 9750 1090n
preplace netloc axi_dma_buf_M_AXI_S2MM 1 20 1 N 1470
preplace netloc axi_dma_gen_M_AXIS_MM2S 1 3 1 1340 1630n
preplace netloc axi_dma_gen_M_AXI_MM2S 1 3 18 NJ 1610 NJ 1610 NJ 1610 NJ 1610 NJ 1610 NJ 1610 NJ 1610 4610J 1740 NJ 1740 NJ 1740 NJ 1740 NJ 1740 NJ 1740 NJ 1740 NJ 1740 8680J 1760 9260J 1770 9710
preplace netloc axi_dma_readout_M_AXI_S2MM 1 20 1 9710 1290n
preplace netloc axi_dma_tproc_M_AXIS_MM2S 1 12 1 5950 800n
preplace netloc axi_dma_tproc_M_AXI_MM2S 1 12 9 NJ 760 NJ 760 NJ 760 NJ 760 NJ 760 NJ 760 NJ 760 NJ 760 9760
preplace netloc axi_dma_tproc_M_AXI_S2MM 1 12 9 NJ 780 NJ 780 NJ 780 NJ 780 NJ 780 NJ 780 NJ 780 NJ 780 9740
preplace netloc axi_dma_tt_M_AXI_S2MM 1 20 1 9720 1570n
preplace netloc axi_smc_M00_AXI 1 21 1 10090 1530n
preplace netloc axis_avg_buffer_0_m0_axis 1 18 1 8660 1261n
preplace netloc axis_avg_buffer_0_m1_axis 1 18 1 8740 1481n
preplace netloc axis_avg_buffer_0_m2_axis 1 11 8 5510 1510 NJ 1510 NJ 1510 NJ 1510 NJ 1510 NJ 1510 NJ 1510 8590
preplace netloc axis_avg_buffer_2_m0_axis 1 11 8 5440 690 NJ 690 NJ 690 NJ 690 NJ 690 NJ 690 NJ 690 8820J
preplace netloc axis_avg_buffer_2_m1_axis 1 11 8 N 700 NJ 700 NJ 700 NJ 700 NJ 700 NJ 700 NJ 700 8780J
preplace netloc axis_avg_buffer_2_m2_axis 1 11 1 5290 720n
preplace netloc axis_avg_buffer_3_m0_axis 1 11 8 5510 630 NJ 630 NJ 630 NJ 630 NJ 630 NJ 630 NJ 630 8830J
preplace netloc axis_avg_buffer_3_m1_axis 1 11 8 5500 640 NJ 640 NJ 640 NJ 640 NJ 640 NJ 640 NJ 640 8800J
preplace netloc axis_avg_buffer_3_m2_axis 1 11 1 5430 160n
preplace netloc axis_avg_buffer_4_m0_axis 1 11 8 5190J 1310 NJ 1310 NJ 1310 NJ 1310 NJ 1310 NJ 1310 NJ 1310 8590
preplace netloc axis_avg_buffer_4_m1_axis 1 11 8 5270J 1780 NJ 1780 NJ 1780 NJ 1780 NJ 1780 NJ 1780 NJ 1780 8730
preplace netloc axis_avg_buffer_4_m2_axis 1 11 1 5190 1940n
preplace netloc axis_avg_buffer_5_m0_axis 1 11 8 5400 1010 NJ 1010 NJ 1010 NJ 1010 NJ 1010 NJ 1010 NJ 1010 8790J
preplace netloc axis_avg_buffer_5_m1_axis 1 11 8 NJ 1020 NJ 1020 NJ 1020 NJ 1020 NJ 1020 NJ 1020 NJ 1020 8760
preplace netloc axis_avg_buffer_5_m2_axis 1 11 1 5260 1040n
preplace netloc axis_avg_buffer_6_m0_axis 1 11 8 NJ 1320 NJ 1320 NJ 1320 NJ 1320 NJ 1320 NJ 1320 NJ 1320 8630
preplace netloc axis_avg_buffer_6_m1_axis 1 11 8 5280J 1350 NJ 1350 NJ 1350 NJ 1350 NJ 1350 NJ 1350 NJ 1350 8690
preplace netloc axis_avg_buffer_6_m2_axis 1 11 1 5240 1360n
preplace netloc axis_avg_buffer_7_m0_axis 1 11 8 5180J 1330 NJ 1330 NJ 1330 NJ 1330 NJ 1330 NJ 1330 NJ 1330 8650
preplace netloc axis_avg_buffer_7_m1_axis 1 11 8 5210 1530 NJ 1530 NJ 1530 NJ 1530 NJ 1530 NJ 1530 NJ 1530 8680J
preplace netloc axis_avg_buffer_7_m2_axis 1 11 1 5210 1620n
preplace netloc axis_avg_buffer_8_m0_axis 1 11 8 5490 650 NJ 650 NJ 650 NJ 650 NJ 650 NJ 650 NJ 650 8810J
preplace netloc axis_avg_buffer_8_m1_axis 1 11 8 5480 660 NJ 660 NJ 660 NJ 660 NJ 660 NJ 660 NJ 660 8770J
preplace netloc axis_avg_buffer_8_m2_axis 1 11 1 5390 420n
preplace netloc axis_avg_buffer_9_m0_axis 1 11 8 5300 1340 NJ 1340 NJ 1340 NJ 1340 NJ 1340 NJ 1340 NJ 1340 8690J
preplace netloc axis_avg_buffer_9_m1_axis 1 11 8 5360 1520 NJ 1520 NJ 1520 NJ 1520 NJ 1520 NJ 1520 NJ 1520 8720J
preplace netloc axis_avg_buffer_9_m2_axis 1 11 1 5140 3020n
preplace netloc axis_broadcaster_0_M00_AXIS 1 17 1 8190 2780n
preplace netloc axis_broadcaster_0_M01_AXIS 1 17 5 8140 1790 NJ 1790 NJ 1790 9730J 1730 NJ
preplace netloc axis_broadcaster_10_M00_AXIS 1 10 1 4380 2620n
preplace netloc axis_broadcaster_10_M01_AXIS 1 10 12 4370 2140 5500J 2050 5840J 1910 NJ 1910 NJ 1910 NJ 1910 NJ 1910 NJ 1910 NJ 1910 NJ 1910 NJ 1910 NJ
preplace netloc axis_broadcaster_1_M00_AXIS 1 10 1 N 2460
preplace netloc axis_broadcaster_1_M01_AXIS 1 10 12 4380 2400 5150J 3250 NJ 3250 NJ 3250 NJ 3250 NJ 3250 NJ 3250 NJ 3250 NJ 3250 NJ 3250 NJ 3250 10060J
preplace netloc axis_broadcaster_3_M00_AXIS 1 10 1 4410 620n
preplace netloc axis_broadcaster_3_M01_AXIS 1 10 12 4370J 860 5420J 960 NJ 960 NJ 960 NJ 960 NJ 960 NJ 960 NJ 960 NJ 960 NJ 960 NJ 960 10110
preplace netloc axis_broadcaster_4_M00_AXIS 1 10 1 4390 60n
preplace netloc axis_broadcaster_4_M01_AXIS 1 10 12 4400J 550 5460J 680 NJ 680 NJ 680 NJ 680 NJ 680 NJ 680 NJ 680 NJ 680 NJ 680 NJ 680 10120
preplace netloc axis_broadcaster_5_M00_AXIS 1 10 1 4510 1840n
preplace netloc axis_broadcaster_5_M01_AXIS 1 10 12 4440 2060 5310J 1820 NJ 1820 NJ 1820 NJ 1820 NJ 1820 NJ 1820 NJ 1820 NJ 1820 NJ 1820 NJ 1820 10040J
preplace netloc axis_broadcaster_6_M00_AXIS 1 10 1 4410 940n
preplace netloc axis_broadcaster_6_M01_AXIS 1 10 12 4480 1770 NJ 1770 5960J 1840 NJ 1840 NJ 1840 NJ 1840 NJ 1840 NJ 1840 NJ 1840 NJ 1840 9760J 1830 NJ
preplace netloc axis_broadcaster_7_M00_AXIS 1 10 1 4470 1260n
preplace netloc axis_broadcaster_7_M01_AXIS 1 10 12 4390 2220 5180J 3240 NJ 3240 NJ 3240 NJ 3240 NJ 3240 NJ 3240 NJ 3240 NJ 3240 NJ 3240 NJ 3240 10080J
preplace netloc axis_broadcaster_8_M00_AXIS 1 10 1 4500 1520n
preplace netloc axis_broadcaster_8_M01_AXIS 1 10 12 4600 2130 5150J 1840 5910J 1850 NJ 1850 NJ 1850 NJ 1850 NJ 1850 NJ 1850 NJ 1850 NJ 1850 NJ 1850 10050J
preplace netloc axis_broadcaster_9_M00_AXIS 1 10 1 N 320
preplace netloc axis_broadcaster_9_M01_AXIS 1 10 12 4370J 540 5470J 670 NJ 670 NJ 670 NJ 670 NJ 670 NJ 670 NJ 670 NJ 670 NJ 670 NJ 670 10100
preplace netloc axis_cc_avg_0_M_AXIS 1 12 1 5930 2710n
preplace netloc axis_cdcsync_v1_0_m0_axis 1 14 1 6990 3540n
preplace netloc axis_cdcsync_v1_0_m1_axis 1 7 8 3100 1190 NJ 1190 NJ 1190 NJ 1190 5300J 1210 NJ 1210 NJ 1210 6980
preplace netloc axis_dyn_readout_v1_0_m0_axis 1 16 2 NJ 3580 8130
preplace netloc axis_dyn_readout_v1_0_m1_axis 1 16 1 7800 3470n
preplace netloc axis_dyn_readout_v1_1_m0_axis 1 9 9 4050 3740 NJ 3740 NJ 3740 6000J 3690 NJ 3690 NJ 3690 NJ 3690 7830J 3680 NJ
preplace netloc axis_dyn_readout_v1_1_m1_axis 1 9 1 4070 2450n
preplace netloc axis_pfb_readout_v4_0_m0_axis 1 9 1 3990 820n
preplace netloc axis_pfb_readout_v4_0_m1_axis 1 9 1 3980 680n
preplace netloc axis_pfb_readout_v4_0_m2_axis 1 9 1 4040 1980n
preplace netloc axis_pfb_readout_v4_0_m3_axis 1 9 1 4030 1840n
preplace netloc axis_pfb_readout_v4_0_m4_axis 1 9 1 4070 2080n
preplace netloc axis_pfb_readout_v4_0_m5_axis 1 9 1 4040 2100n
preplace netloc axis_pfb_readout_v4_0_m6_axis 1 9 1 3960 310n
preplace netloc axis_pfb_readout_v4_0_m7_axis 1 9 1 4020 2140n
preplace netloc axis_register_slice_2_M_AXIS 1 15 1 7450 3580n
preplace netloc axis_register_slice_3_M_AXIS 1 8 1 N 3480
preplace netloc axis_register_slice_5_M_AXIS 1 18 1 8620 3420n
preplace netloc axis_register_slice_6_m_axis 1 6 1 2700 3120n
preplace netloc axis_sg_mixmux8_v1_0_m_axis 1 6 1 2710 3140n
preplace netloc axis_signal_gen_v6_0_m_axis 1 5 1 2260 3510n
preplace netloc axis_switch_0_M00_AXIS 1 18 1 8810 2980n
preplace netloc axis_switch_avg_M00_AXIS 1 19 1 9240 1090n
preplace netloc axis_switch_buf_M00_AXIS 1 19 1 9260 1470n
preplace netloc axis_switch_ddr4_M00_AXIS 1 22 1 10760 1870n
preplace netloc axis_switch_gen_M00_AXIS 1 4 1 1800 2510n
preplace netloc axis_switch_gen_M02_AXIS 1 4 7 N 2550 NJ 2550 NJ 2550 NJ 2550 NJ 2550 NJ 2550 4610J
preplace netloc axis_weighted_buffer_0_m0_axis 1 11 8 5250 1269 NJ 1269 NJ 1269 NJ 1269 NJ 1269 NJ 1269 NJ 1269 NJ
preplace netloc axis_weighted_buffer_0_m1_axis 1 11 8 5330 1489 NJ 1489 NJ 1489 NJ 1489 NJ 1489 NJ 1489 NJ 1489 NJ
preplace netloc axis_weighted_buffer_0_m2_axis 1 11 1 5170 2570n
preplace netloc dac0_clk_1 1 0 7 NJ 3180 NJ 3180 NJ 3180 NJ 3180 NJ 3180 NJ 3180 2720J
preplace netloc dac2_clk_1 1 0 7 NJ 3210 NJ 3210 NJ 3210 NJ 3210 NJ 3210 NJ 3210 2720J
preplace netloc ddr4_0_C0_DDR4 1 23 1 NJ 2610
preplace netloc mr_buffer_et_0_m00_axis 1 19 1 9300 1290n
preplace netloc ps8_0_axi_periph_M00_AXI 1 2 18 720 930 NJ 930 NJ 930 NJ 930 NJ 930 NJ 930 NJ 930 NJ 930 4410J 880 5410J 1070 NJ 1070 NJ 1070 NJ 1070 NJ 1070 NJ 1070 NJ 1070 NJ 1070 NJ
preplace netloc ps8_0_axi_periph_M01_AXI 1 2 18 890 1920 NJ 1920 NJ 1920 NJ 1920 NJ 1920 NJ 1920 NJ 1920 4000J 1760 4430J 2110 5200J 1180 NJ 1180 NJ 1180 NJ 1180 NJ 1180 NJ 1180 NJ 1180 NJ 1180 9320J
preplace netloc ps8_0_axi_periph_M02_AXI 1 2 1 800 1610n
preplace netloc ps8_0_axi_periph_M03_AXI 1 2 18 880 1910 1260J 1680 NJ 1680 NJ 1680 NJ 1680 NJ 1680 NJ 1680 NJ 1680 4370J 2080 5370J 1850 5840J 1860 NJ 1860 NJ 1860 NJ 1860 NJ 1860 NJ 1860 NJ 1860 9250J
preplace netloc ps8_0_axi_periph_M04_AXI 1 2 10 710 560 NJ 560 NJ 560 NJ 560 NJ 560 NJ 560 NJ 560 NJ 560 NJ 560 5450J
preplace netloc ps8_0_axi_periph_M05_AXI 1 2 18 810 1730 NJ 1730 NJ 1730 NJ 1730 NJ 1730 NJ 1730 NJ 1730 NJ 1730 4490J 2090 5340J 1790 5840J 1660 NJ 1660 NJ 1660 NJ 1660 NJ 1660 NJ 1660 NJ 1660 9310J
preplace netloc ps8_0_axi_periph_M06_AXI 1 2 1 840 1790n
preplace netloc ps8_0_axi_periph_M07_AXI 1 2 16 840J 1940 1270J 1690 NJ 1690 NJ 1690 NJ 1690 NJ 1690 NJ 1690 NJ 1690 4460J 2260 NJ 2260 NJ 2260 NJ 2260 NJ 2260 NJ 2260 NJ 2260 8210
preplace netloc ps8_0_axi_periph_M08_AXI 1 2 9 770 620 NJ 620 NJ 620 NJ 620 NJ 620 NJ 620 NJ 620 NJ 620 4370J
preplace netloc ps8_0_axi_periph_M09_AXI 1 2 9 750 80 NJ 80 NJ 80 NJ 80 NJ 80 NJ 80 NJ 80 NJ 80 NJ
preplace netloc ps8_0_axi_periph_M10_AXI 1 2 9 830J 1930 1280J 1710 NJ 1710 NJ 1710 NJ 1710 NJ 1710 NJ 1710 NJ 1710 4590
preplace netloc ps8_0_axi_periph_M11_AXI 1 2 9 790J 1150 NJ 1150 NJ 1150 NJ 1150 NJ 1150 NJ 1150 NJ 1150 NJ 1150 4470
preplace netloc ps8_0_axi_periph_M12_AXI 1 2 9 820 1280 NJ 1280 NJ 1280 NJ 1280 NJ 1280 NJ 1280 NJ 1280 NJ 1280 NJ
preplace netloc ps8_0_axi_periph_M13_AXI 1 2 9 860 1540 NJ 1540 NJ 1540 NJ 1540 NJ 1540 NJ 1540 NJ 1540 NJ 1540 NJ
preplace netloc ps8_0_axi_periph_M14_AXI 1 2 9 780 410 NJ 410 NJ 410 NJ 410 NJ 410 NJ 410 NJ 410 NJ 410 4400J
preplace netloc ps8_0_axi_periph_M15_AXI 1 2 9 900 1970 1310J 1720 NJ 1720 NJ 1720 NJ 1720 NJ 1720 NJ 1720 NJ 1720 4400J
preplace netloc ps8_0_axi_periph_M16_AXI 1 2 7 NJ 2040 NJ 2040 NJ 2040 NJ 2040 NJ 2040 NJ 2040 N
preplace netloc ps8_0_axi_periph_M17_AXI 1 2 4 900 2080 NJ 2080 NJ 2080 2280J
preplace netloc ps8_0_axi_periph_M18_AXI 1 2 3 710 2090 NJ 2090 1810J
preplace netloc ps8_0_axi_periph_M19_AXI 1 2 17 NJ 2100 NJ 2100 NJ 2100 NJ 2100 NJ 2100 NJ 2100 3520J 1880 4020J 1780 4450J 2070 5220J 1469 NJ 1469 NJ 1469 NJ 1469 NJ 1469 NJ 1469 NJ 1469 8700
preplace netloc ps8_0_axi_periph_M20_AXI 1 2 17 NJ 2120 NJ 2120 NJ 2120 NJ 2120 NJ 2120 NJ 2120 3530J 1890 4010J 1770 4420J 2100 5280J 1540 NJ 1540 NJ 1540 NJ 1540 NJ 1540 NJ 1540 NJ 1540 8670
preplace netloc ps8_0_axi_periph_M21_AXI 1 2 20 NJ 2140 1330J 1750 NJ 1750 NJ 1750 NJ 1750 NJ 1750 NJ 1750 NJ 1750 4560J 1760 NJ 1760 5980J 1790 NJ 1790 NJ 1790 NJ 1790 NJ 1790 8130J 1800 NJ 1800 9230J 1920 NJ 1920 10050
preplace netloc ps8_0_axi_periph_M22_AXI 1 2 2 900 2330 1310J
preplace netloc ps8_0_axi_periph_M23_AXI 1 2 16 790 3600 NJ 3600 1780J 3650 2250J 3590 NJ 3590 NJ 3590 3520J 3730 NJ 3730 NJ 3730 NJ 3730 6010J 3700 NJ 3700 NJ 3700 NJ 3700 NJ 3700 NJ
preplace netloc ps8_0_axi_periph_M24_AXI 1 2 9 880 2340 NJ 2340 NJ 2340 NJ 2340 NJ 2340 NJ 2340 NJ 2340 4000J 2390 4390J
preplace netloc ps8_0_axi_periph_M25_AXI 1 2 21 840 2350 NJ 2350 NJ 2350 NJ 2350 NJ 2350 NJ 2350 NJ 2350 3970J 2820 NJ 2820 NJ 2820 5850J 2540 NJ 2540 NJ 2540 NJ 2540 NJ 2540 NJ 2540 NJ 2540 NJ 2540 NJ 2540 10030J 2550 NJ
preplace netloc ps8_0_axi_periph_M26_AXI 1 2 17 810 2360 NJ 2360 NJ 2360 NJ 2360 NJ 2360 NJ 2360 NJ 2360 NJ 2360 4610J 2250 NJ 2250 NJ 2250 NJ 2250 NJ 2250 NJ 2250 NJ 2250 NJ 2250 8650J
preplace netloc ps8_0_axi_periph_M27_AXI 1 2 11 770 2370 NJ 2370 NJ 2370 NJ 2370 NJ 2370 NJ 2370 NJ 2370 3960J 2830 NJ 2830 NJ 2830 5830J
preplace netloc ps8_0_axi_periph_M28_AXI 1 2 17 740 2380 NJ 2380 NJ 2380 NJ 2380 NJ 2380 NJ 2380 NJ 2380 3980J 2370 NJ 2370 5160J 3260 NJ 3260 NJ 3260 NJ 3260 NJ 3260 NJ 3260 NJ 3260 8620J
preplace netloc ps8_0_axi_periph_M29_AXI 1 2 5 710 2420 NJ 2420 NJ 2420 NJ 2420 2740J
preplace netloc qick_processor_0_QPeriphA 1 13 6 NJ 2720 NJ 2720 NJ 2720 NJ 2720 NJ 2720 8630
preplace netloc qick_processor_0_m0_axis 1 3 11 1350 1700 NJ 1700 NJ 1700 NJ 1700 NJ 1700 NJ 1700 NJ 1700 4600J 1780 5230J 1800 NJ 1800 6450
preplace netloc qick_processor_0_m1_axis 1 4 10 1820 1740 NJ 1740 NJ 1740 NJ 1740 NJ 1740 NJ 1740 4580J 1750 NJ 1750 6020J 1760 6520
preplace netloc qick_processor_0_m2_axis 1 13 1 6620 2660n
preplace netloc qick_processor_0_m3_axis 1 13 1 6610 2680n
preplace netloc qick_processor_0_m_dma_axis_o 1 11 3 5510 1479 NJ 1479 6540
preplace netloc qick_time_tagger_0_m_axis_dma 1 19 1 9320 1650n
preplace netloc sg_translator_0_m_gen_v6_axis 1 4 1 1760 3450n
preplace netloc sg_translator_1_m_mux4_axis 1 5 1 2230 3390n
preplace netloc sg_translator_2_m_readout_v3_axis 1 15 1 N 3560
preplace netloc sg_translator_3_m_readout_v3_axis 1 8 1 3590 3460n
preplace netloc sys_clk_ddr4_1 1 22 2 10770 2470 NJ
preplace netloc sysref_in_1 1 0 7 30J 3310 NJ 3310 NJ 3310 NJ 3310 NJ 3310 NJ 3310 2690J
preplace netloc usp_rf_data_converter_0_m00_axis 1 7 8 NJ 3210 NJ 3210 NJ 3210 4370J 3260 5080J 3930 NJ 3930 NJ 3930 7020
preplace netloc usp_rf_data_converter_0_m02_axis 1 7 1 3030 3230n
preplace netloc usp_rf_data_converter_0_m20_axis 1 7 2 3020J 2030 3540
preplace netloc usp_rf_data_converter_0_m22_axis 1 7 11 NJ 3270 NJ 3270 NJ 3270 4370J 3280 5130J 3310 NJ 3310 NJ 3310 NJ 3310 NJ 3310 NJ 3310 8150
preplace netloc usp_rf_data_converter_0_vout00 1 7 17 NJ 3290 NJ 3290 NJ 3290 4370J 3300 5120J 3320 NJ 3320 NJ 3320 NJ 3320 NJ 3320 NJ 3320 8210J 3280 NJ 3280 NJ 3280 NJ 3280 NJ 3280 NJ 3280 NJ
preplace netloc usp_rf_data_converter_0_vout20 1 7 17 NJ 3310 NJ 3310 NJ 3310 NJ 3310 5090J 3330 NJ 3330 NJ 3330 NJ 3330 NJ 3330 NJ 3330 NJ 3330 8800J 3310 NJ 3310 NJ 3310 NJ 3310 NJ 3310 NJ
preplace netloc vin0_01_1 1 0 7 NJ 3240 NJ 3240 NJ 3240 NJ 3240 NJ 3240 NJ 3240 NJ
preplace netloc vin0_23_1 1 0 7 10J 3260 NJ 3260 NJ 3260 NJ 3260 NJ 3260 NJ 3260 NJ
preplace netloc vin2_01_1 1 0 7 10J 3280 NJ 3280 NJ 3280 NJ 3280 NJ 3280 NJ 3280 NJ
preplace netloc vin2_23_1 1 0 7 20J 3300 NJ 3300 NJ 3300 NJ 3300 NJ 3300 NJ 3300 NJ
preplace netloc zynq_ultra_ps_e_0_M_AXI_HPM0_FPD 1 1 22 430 1260 NJ 1260 NJ 1260 NJ 1260 NJ 1260 NJ 1260 3020J 1200 NJ 1200 NJ 1200 NJ 1200 5150J 1830 NJ 1830 NJ 1830 NJ 1830 NJ 1830 NJ 1830 NJ 1830 NJ 1830 NJ 1830 9720J 1670 NJ 1670 10700
preplace netloc zynq_ultra_ps_e_0_M_AXI_HPM1_FPD 1 22 1 10750 2420n
preplace netloc axis_cc_avg_2_M_AXIS 1 12 1 5890 2730n
preplace netloc axis_clock_converter_0_M_AXIS 1 12 1 5940 2750n
preplace netloc axis_clock_converter_1_M_AXIS 1 12 1 5970 1640n
preplace netloc axis_clock_converter_2_M_AXIS 1 12 1 5900 2360n
preplace netloc axis_clock_converter_3_M_AXIS 1 12 1 5830 2540n
preplace netloc axis_clock_converter_4_M_AXIS 1 12 1 5910 1950n
preplace netloc axis_clock_converter_5_M_AXIS 1 12 1 5860 2150n
preplace netloc axis_clock_converter_6_M_AXIS 1 12 1 5840 2720n
preplace netloc axis_clock_converter_7_M_AXIS 1 12 1 5960 2930n
levelinfo -pg 1 -10 210 570 1080 1560 2020 2480 2870 3310 3780 4220 4890 5670 6240 6800 7230 7630 7980 8410 9030 9500 9890 10410 10900 11050
pagesize -pg 1 -db -bbox -sgen -130 0 11180 4300
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


