
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
   create_project project_1 myproj -part xczu49dr-ffvf1760-2-e
   set_property BOARD_PART xilinx.com:zcu216:part0:2.0 [current_project]
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
QICK:QICK:axis_register_slice_nb:1.0\
QICK:QICK:axis_resampler_2x1_v1:1.0\
QICK:QICK:axis_sg_mux8_v1:1.0\
xilinx.com:ip:proc_sys_reset:5.0\
QICK:QICK:sg_translator:1.0\
xilinx.com:ip:xlconcat:2.1\
QICK:QICK:axis_tmux_v1:1.0\
QICK:QICK:axis_sg_mixmux8_v1:1.0\
QICK:QICK:axis_signal_gen_v6:1.0\
QICK:QICK:axis_cdcsync_v1:1.0\
xilinx.com:ip:axi_dma:7.1\
xilinx.com:ip:smartconnect:1.0\
xilinx.com:ip:axis_broadcaster:1.1\
xilinx.com:ip:axis_clock_converter:1.1\
QICK:QICK:axis_dyn_readout_v1:1.0\
QICK:QICK:axis_pfb_readout_v3:1.0\
QICK:QICK:axis_readout_v2:1.0\
QICK:QICK:axis_readout_v3:1.0\
xilinx.com:ip:axis_register_slice:1.1\
QICK:QICK:axis_sg_int4_v2:1.0\
xilinx.com:ip:axis_switch:1.1\
xilinx.com:ip:clk_wiz:6.0\
xilinx.com:ip:usp_rf_data_converter:2.6\
xilinx.com:ip:zynq_ultra_ps_e:3.5\
xilinx.com:ip:axi_gpio:2.0\
QICK:QICK:axis_avg_buffer:1.2\
QICK:QICK:mr_buffer_et:1.1\
QICK:QICK:qick_processor:2.0\
QICK:QICK:axis_buffer_ddr_v1:1.0\
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
  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 s_axi

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 S_AXIS

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 S00_AXI

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 default_sysclk_c0_300mhz

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:ddr4_rtl:1.0 ddr4_sdram_c0


  # Create pins
  create_bd_pin -dir I -type rst aresetn
  create_bd_pin -dir I -type clk aclk
  create_bd_pin -dir O -type clk c0_ddr4_ui_clk
  create_bd_pin -dir I trigger
  create_bd_pin -dir I -type clk s_axi_aclk
  create_bd_pin -dir I -type rst s_axi_aresetn
  create_bd_pin -dir I -type rst sys_rst

  # Create instance: axis_clock_converter_0, and set properties
  set axis_clock_converter_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_clock_converter:1.1 axis_clock_converter_0 ]

  # Create instance: rst_ddr4, and set properties
  set rst_ddr4 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_ddr4 ]

  # Create instance: axis_buffer_ddr_v1_0, and set properties
  set axis_buffer_ddr_v1_0 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_buffer_ddr_v1:1.0 axis_buffer_ddr_v1_0 ]
  set_property -dict [list \
    CONFIG.DATA_WIDTH {256} \
    CONFIG.TARGET_SLAVE_BASE_ADDR {0x00000000} \
  ] $axis_buffer_ddr_v1_0


  # Create instance: axis_dwidth_converter_0, and set properties
  set axis_dwidth_converter_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_dwidth_converter:1.1 axis_dwidth_converter_0 ]
  set_property CONFIG.M_TDATA_NUM_BYTES {32} $axis_dwidth_converter_0


  # Create instance: axi_smc_1, and set properties
  set axi_smc_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 axi_smc_1 ]

  # Create instance: ddr4_0, and set properties
  set ddr4_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:ddr4:2.2 ddr4_0 ]
  set_property -dict [list \
    CONFIG.ADDN_UI_CLKOUT1_FREQ_HZ {100} \
    CONFIG.C0.CS_WIDTH {2} \
    CONFIG.C0.DDR4_AxiAddressWidth {32} \
    CONFIG.C0.DDR4_Clamshell {true} \
    CONFIG.C0_CLOCK_BOARD_INTERFACE {default_sysclk_c0_300mhz} \
    CONFIG.C0_DDR4_BOARD_INTERFACE {ddr4_sdram_c0} \
  ] $ddr4_0


  # Create interface connections
  connect_bd_intf_net -intf_net axis_buffer_ddr_v1_0_m_axi [get_bd_intf_pins axi_smc_1/S01_AXI] [get_bd_intf_pins axis_buffer_ddr_v1_0/m_axi]
  connect_bd_intf_net -intf_net axis_clock_converter_0_M_AXIS [get_bd_intf_pins axis_buffer_ddr_v1_0/s_axis] [get_bd_intf_pins axis_clock_converter_0/M_AXIS]
  connect_bd_intf_net -intf_net axis_dwidth_converter_0_M_AXIS [get_bd_intf_pins axis_clock_converter_0/S_AXIS] [get_bd_intf_pins axis_dwidth_converter_0/M_AXIS]
  connect_bd_intf_net -intf_net axis_switch_ddr_M00_AXIS [get_bd_intf_pins S_AXIS] [get_bd_intf_pins axis_dwidth_converter_0/S_AXIS]
  connect_bd_intf_net -intf_net ddr4_0_C0_DDR4 [get_bd_intf_pins ddr4_sdram_c0] [get_bd_intf_pins ddr4_0/C0_DDR4]
  connect_bd_intf_net -intf_net default_sysclk_c0_300mhz_1 [get_bd_intf_pins default_sysclk_c0_300mhz] [get_bd_intf_pins ddr4_0/C0_SYS_CLK]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M22_AXI [get_bd_intf_pins s_axi] [get_bd_intf_pins axis_buffer_ddr_v1_0/s_axi]
  connect_bd_intf_net -intf_net smartconnect_0_M00_AXI1 [get_bd_intf_pins axi_smc_1/M00_AXI] [get_bd_intf_pins ddr4_0/C0_DDR4_S_AXI]
  connect_bd_intf_net -intf_net zynq_ultra_ps_e_0_M_AXI_HPM1_FPD [get_bd_intf_pins S00_AXI] [get_bd_intf_pins axi_smc_1/S00_AXI]

  # Create port connections
  connect_bd_net -net Net [get_bd_pins rst_ddr4/peripheral_aresetn] [get_bd_pins axis_buffer_ddr_v1_0/aresetn] [get_bd_pins axi_smc_1/aresetn] [get_bd_pins axis_clock_converter_0/m_axis_aresetn] [get_bd_pins ddr4_0/c0_ddr4_aresetn]
  connect_bd_net -net ddr4_0_c0_ddr4_ui_clk [get_bd_pins ddr4_0/c0_ddr4_ui_clk] [get_bd_pins c0_ddr4_ui_clk] [get_bd_pins axis_buffer_ddr_v1_0/aclk] [get_bd_pins rst_ddr4/slowest_sync_clk] [get_bd_pins axi_smc_1/aclk] [get_bd_pins axis_clock_converter_0/m_axis_aclk]
  connect_bd_net -net ddr4_0_c0_ddr4_ui_clk_sync_rst [get_bd_pins ddr4_0/c0_ddr4_ui_clk_sync_rst] [get_bd_pins rst_ddr4/ext_reset_in]
  connect_bd_net -net qick_processor_0_trig_8_o [get_bd_pins trigger] [get_bd_pins axis_buffer_ddr_v1_0/trigger]
  connect_bd_net -net rst_100_bus_struct_reset [get_bd_pins sys_rst] [get_bd_pins ddr4_0/sys_rst]
  connect_bd_net -net rst_adc_peripheral_aresetn [get_bd_pins aresetn] [get_bd_pins axis_dwidth_converter_0/aresetn] [get_bd_pins axis_clock_converter_0/s_axis_aresetn]
  connect_bd_net -net rst_ps8_0_99M_peripheral_aresetn [get_bd_pins s_axi_aresetn] [get_bd_pins axis_buffer_ddr_v1_0/s_axi_aresetn]
  connect_bd_net -net usp_rf_data_converter_0_clk_adc2 [get_bd_pins aclk] [get_bd_pins axis_dwidth_converter_0/aclk] [get_bd_pins axis_clock_converter_0/s_axis_aclk]
  connect_bd_net -net zynq_ultra_ps_e_0_pl_clk0 [get_bd_pins s_axi_aclk] [get_bd_pins axis_buffer_ddr_v1_0/s_axi_aclk]

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
  set adc2_clk_0 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 adc2_clk_0 ]

  set dac2_clk_0 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 dac2_clk_0 ]

  set ddr4_sdram_c0 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:ddr4_rtl:1.0 ddr4_sdram_c0 ]

  set default_sysclk_c0_300mhz [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 default_sysclk_c0_300mhz ]
  set_property -dict [ list \
   CONFIG.FREQ_HZ {300000000} \
   ] $default_sysclk_c0_300mhz

  set sysref_in_0 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:display_usp_rf_data_converter:diff_pins_rtl:1.0 sysref_in_0 ]

  set vin20_0 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 vin20_0 ]

  set vin21_0 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 vin21_0 ]

  set vin22_0 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 vin22_0 ]

  set vout0 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 vout0 ]

  set vout1 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 vout1 ]

  set vout2 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 vout2 ]

  set vout3 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 vout3 ]

  set vout4 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 vout4 ]

  set vin23_0 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 vin23_0 ]

  set vout5 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 vout5 ]


  # Create ports
  set PMOD0_0_LS [ create_bd_port -dir O PMOD0_0_LS ]
  set PMOD0_1_LS [ create_bd_port -dir O PMOD0_1_LS ]
  set PMOD0_2_LS [ create_bd_port -dir O PMOD0_2_LS ]
  set PMOD0_3_LS [ create_bd_port -dir O PMOD0_3_LS ]
  set PMOD0_4_LS [ create_bd_port -dir O PMOD0_4_LS ]
  set PMOD0_5_LS [ create_bd_port -dir O PMOD0_5_LS ]
  set PMOD0_6_LS [ create_bd_port -dir O PMOD0_6_LS ]
  set PMOD0_7_LS [ create_bd_port -dir O PMOD0_7_LS ]
  set PMOD1_0_LS [ create_bd_port -dir I PMOD1_0_LS ]
  set CLK104_CLK_SPI_MUX_SEL_LS [ create_bd_port -dir O -from 1 -to 0 CLK104_CLK_SPI_MUX_SEL_LS ]

  # Create instance: axi_intc_0, and set properties
  set axi_intc_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_intc:4.1 axi_intc_0 ]
  set_property CONFIG.C_IRQ_CONNECTION {1} $axi_intc_0


  # Create instance: axis_register_slice_0, and set properties
  set axis_register_slice_0 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_register_slice_nb:1.0 axis_register_slice_0 ]
  set_property -dict [list \
    CONFIG.B {256} \
    CONFIG.N {6} \
  ] $axis_register_slice_0


  # Create instance: axis_register_slice_1, and set properties
  set axis_register_slice_1 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_register_slice_nb:1.0 axis_register_slice_1 ]
  set_property -dict [list \
    CONFIG.B {256} \
    CONFIG.N {6} \
  ] $axis_register_slice_1


  # Create instance: axis_resampler_2x1_v1_0, and set properties
  set axis_resampler_2x1_v1_0 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_resampler_2x1_v1:1.0 axis_resampler_2x1_v1_0 ]

  # Create instance: axis_sg_mux8_v1_0, and set properties
  set axis_sg_mux8_v1_0 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_sg_mux8_v1:1.0 axis_sg_mux8_v1_0 ]
  set_property CONFIG.N_DDS {16} $axis_sg_mux8_v1_0


  # Create instance: rst_100, and set properties
  set rst_100 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_100 ]

  # Create instance: rst_adc2, and set properties
  set rst_adc2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_adc2 ]
  set_property -dict [list \
    CONFIG.RESET_BOARD_INTERFACE {Custom} \
    CONFIG.USE_BOARD_FLOW {true} \
  ] $rst_adc2


  # Create instance: rst_core, and set properties
  set rst_core [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_core ]
  set_property -dict [list \
    CONFIG.RESET_BOARD_INTERFACE {Custom} \
    CONFIG.USE_BOARD_FLOW {true} \
  ] $rst_core


  # Create instance: rst_dac2, and set properties
  set rst_dac2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_dac2 ]
  set_property -dict [list \
    CONFIG.RESET_BOARD_INTERFACE {Custom} \
    CONFIG.USE_BOARD_FLOW {true} \
  ] $rst_dac2


  # Create instance: rst_dac3, and set properties
  set rst_dac3 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_dac3 ]
  set_property -dict [list \
    CONFIG.RESET_BOARD_INTERFACE {Custom} \
    CONFIG.USE_BOARD_FLOW {true} \
  ] $rst_dac3


  # Create instance: sg_translator_0, and set properties
  set sg_translator_0 [ create_bd_cell -type ip -vlnv QICK:QICK:sg_translator:1.0 sg_translator_0 ]

  # Create instance: sg_translator_1, and set properties
  set sg_translator_1 [ create_bd_cell -type ip -vlnv QICK:QICK:sg_translator:1.0 sg_translator_1 ]
  set_property CONFIG.OUT_TYPE {2} $sg_translator_1


  # Create instance: sg_translator_3, and set properties
  set sg_translator_3 [ create_bd_cell -type ip -vlnv QICK:QICK:sg_translator:1.0 sg_translator_3 ]
  set_property CONFIG.OUT_TYPE {0} $sg_translator_3


  # Create instance: sg_translator_4, and set properties
  set sg_translator_4 [ create_bd_cell -type ip -vlnv QICK:QICK:sg_translator:1.0 sg_translator_4 ]
  set_property CONFIG.OUT_TYPE {0} $sg_translator_4


  # Create instance: sg_translator_5, and set properties
  set sg_translator_5 [ create_bd_cell -type ip -vlnv QICK:QICK:sg_translator:1.0 sg_translator_5 ]
  set_property CONFIG.OUT_TYPE {2} $sg_translator_5


  # Create instance: sg_translator_6, and set properties
  set sg_translator_6 [ create_bd_cell -type ip -vlnv QICK:QICK:sg_translator:1.0 sg_translator_6 ]
  set_property CONFIG.OUT_TYPE {3} $sg_translator_6


  # Create instance: sg_translator_7, and set properties
  set sg_translator_7 [ create_bd_cell -type ip -vlnv QICK:QICK:sg_translator:1.0 sg_translator_7 ]
  set_property CONFIG.OUT_TYPE {3} $sg_translator_7


  # Create instance: xlconcat_intc, and set properties
  set xlconcat_intc [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 xlconcat_intc ]
  set_property CONFIG.NUM_PORTS {7} $xlconcat_intc


  # Create instance: axis_tmux_v1_0, and set properties
  set axis_tmux_v1_0 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_tmux_v1:1.0 axis_tmux_v1_0 ]
  set_property -dict [list \
    CONFIG.B {168} \
    CONFIG.N {4} \
  ] $axis_tmux_v1_0


  # Create instance: axis_sg_mixmux8_v1_0, and set properties
  set axis_sg_mixmux8_v1_0 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_sg_mixmux8_v1:1.0 axis_sg_mixmux8_v1_0 ]
  set_property CONFIG.N_DDS {4} $axis_sg_mixmux8_v1_0


  # Create instance: axis_signal_gen_v6_0, and set properties
  set axis_signal_gen_v6_0 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_signal_gen_v6:1.0 axis_signal_gen_v6_0 ]
  set_property CONFIG.N {10} $axis_signal_gen_v6_0


  # Create instance: axis_cdcsync_v1_1, and set properties
  set axis_cdcsync_v1_1 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_cdcsync_v1:1.0 axis_cdcsync_v1_1 ]
  set_property -dict [list \
    CONFIG.B {168} \
    CONFIG.N {3} \
  ] $axis_cdcsync_v1_1


  # Create instance: axis_signal_gen_v6_1, and set properties
  set axis_signal_gen_v6_1 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_signal_gen_v6:1.0 axis_signal_gen_v6_1 ]
  set_property CONFIG.N {9} $axis_signal_gen_v6_1


  # Create instance: axis_register_slice_2, and set properties
  set axis_register_slice_2 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_register_slice_nb:1.0 axis_register_slice_2 ]
  set_property -dict [list \
    CONFIG.B {256} \
    CONFIG.N {6} \
  ] $axis_register_slice_2


  # Create instance: sg_translator_2, and set properties
  set sg_translator_2 [ create_bd_cell -type ip -vlnv QICK:QICK:sg_translator:1.0 sg_translator_2 ]

  # Create instance: axi_dma_avg, and set properties
  set axi_dma_avg [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma_avg ]
  set_property -dict [list \
    CONFIG.c_include_mm2s {0} \
    CONFIG.c_include_s2mm {1} \
    CONFIG.c_include_sg {0} \
    CONFIG.c_sg_length_width {26} \
  ] $axi_dma_avg


  # Create instance: axi_dma_buf, and set properties
  set axi_dma_buf [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma_buf ]
  set_property -dict [list \
    CONFIG.c_include_mm2s {0} \
    CONFIG.c_include_s2mm {1} \
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
    CONFIG.c_include_s2mm {1} \
    CONFIG.c_include_sg {0} \
    CONFIG.c_sg_length_width {26} \
  ] $axi_dma_mr


  # Create instance: axi_dma_tproc, and set properties
  set axi_dma_tproc [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma_tproc ]
  set_property -dict [list \
    CONFIG.c_include_s2mm {1} \
    CONFIG.c_include_sg {0} \
    CONFIG.c_m_axi_mm2s_data_width {256} \
    CONFIG.c_m_axis_mm2s_tdata_width {256} \
    CONFIG.c_mm2s_burst_size {2} \
    CONFIG.c_sg_length_width {26} \
  ] $axi_dma_tproc


  # Create instance: axi_smc, and set properties
  set axi_smc [ create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 axi_smc ]
  set_property CONFIG.NUM_SI {6} $axi_smc


  # Create instance: axis_broadcaster_0, and set properties
  set axis_broadcaster_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_broadcaster:1.1 axis_broadcaster_0 ]
  set_property CONFIG.HAS_TREADY {0} $axis_broadcaster_0


  # Create instance: axis_broadcaster_1, and set properties
  set axis_broadcaster_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_broadcaster:1.1 axis_broadcaster_1 ]
  set_property CONFIG.HAS_TREADY {0} $axis_broadcaster_1


  # Create instance: axis_broadcaster_2, and set properties
  set axis_broadcaster_2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_broadcaster:1.1 axis_broadcaster_2 ]
  set_property CONFIG.HAS_TREADY {0} $axis_broadcaster_2


  # Create instance: axis_broadcaster_3, and set properties
  set axis_broadcaster_3 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_broadcaster:1.1 axis_broadcaster_3 ]
  set_property CONFIG.HAS_TREADY {0} $axis_broadcaster_3


  # Create instance: axis_broadcaster_4, and set properties
  set axis_broadcaster_4 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_broadcaster:1.1 axis_broadcaster_4 ]
  set_property CONFIG.HAS_TREADY {0} $axis_broadcaster_4


  # Create instance: axis_broadcaster_5, and set properties
  set axis_broadcaster_5 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_broadcaster:1.1 axis_broadcaster_5 ]
  set_property CONFIG.HAS_TREADY {0} $axis_broadcaster_5


  # Create instance: axis_clk_cnvrt_avg_0, and set properties
  set axis_clk_cnvrt_avg_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_clock_converter:1.1 axis_clk_cnvrt_avg_0 ]

  # Create instance: axis_clk_cnvrt_avg_1, and set properties
  set axis_clk_cnvrt_avg_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_clock_converter:1.1 axis_clk_cnvrt_avg_1 ]

  # Create instance: axis_clk_cnvrt_avg_2, and set properties
  set axis_clk_cnvrt_avg_2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_clock_converter:1.1 axis_clk_cnvrt_avg_2 ]

  # Create instance: axis_clk_cnvrt_avg_3, and set properties
  set axis_clk_cnvrt_avg_3 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_clock_converter:1.1 axis_clk_cnvrt_avg_3 ]

  # Create instance: axis_clk_cnvrt_avg_4, and set properties
  set axis_clk_cnvrt_avg_4 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_clock_converter:1.1 axis_clk_cnvrt_avg_4 ]

  # Create instance: axis_clk_cnvrt_avg_5, and set properties
  set axis_clk_cnvrt_avg_5 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_clock_converter:1.1 axis_clk_cnvrt_avg_5 ]

  # Create instance: axis_clk_cnvrt_avg_6, and set properties
  set axis_clk_cnvrt_avg_6 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_clock_converter:1.1 axis_clk_cnvrt_avg_6 ]

  # Create instance: axis_clock_converter_1, and set properties
  set axis_clock_converter_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_clock_converter:1.1 axis_clock_converter_1 ]

  # Create instance: axis_clock_converter_3, and set properties
  set axis_clock_converter_3 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_clock_converter:1.1 axis_clock_converter_3 ]

  # Create instance: axis_dyn_readout_v1_0, and set properties
  set axis_dyn_readout_v1_0 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_dyn_readout_v1:1.0 axis_dyn_readout_v1_0 ]

  # Create instance: axis_pfb_readout_v3_0, and set properties
  set axis_pfb_readout_v3_0 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_pfb_readout_v3:1.0 axis_pfb_readout_v3_0 ]

  # Create instance: axis_readout_v2_0, and set properties
  set axis_readout_v2_0 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_readout_v2:1.0 axis_readout_v2_0 ]

  # Create instance: axis_readout_v3_0, and set properties
  set axis_readout_v3_0 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_readout_v3:1.0 axis_readout_v3_0 ]

  # Create instance: axis_register_slice_3, and set properties
  set axis_register_slice_3 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_register_slice:1.1 axis_register_slice_3 ]
  set_property CONFIG.REG_CONFIG {8} $axis_register_slice_3


  # Create instance: axis_register_slice_4, and set properties
  set axis_register_slice_4 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_register_slice:1.1 axis_register_slice_4 ]
  set_property CONFIG.REG_CONFIG {8} $axis_register_slice_4


  # Create instance: axis_register_slice_8, and set properties
  set axis_register_slice_8 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_register_slice:1.1 axis_register_slice_8 ]
  set_property CONFIG.REG_CONFIG {8} $axis_register_slice_8


  # Create instance: axis_register_slice_6, and set properties
  set axis_register_slice_6 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_register_slice:1.1 axis_register_slice_6 ]
  set_property CONFIG.REG_CONFIG {8} $axis_register_slice_6


  # Create instance: axis_register_slice_5, and set properties
  set axis_register_slice_5 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_register_slice:1.1 axis_register_slice_5 ]
  set_property CONFIG.REG_CONFIG {8} $axis_register_slice_5


  # Create instance: axis_register_slice_10, and set properties
  set axis_register_slice_10 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_register_slice:1.1 axis_register_slice_10 ]
  set_property CONFIG.REG_CONFIG {8} $axis_register_slice_10


  # Create instance: axis_sg_int4_v2_0, and set properties
  set axis_sg_int4_v2_0 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_sg_int4_v2:1.0 axis_sg_int4_v2_0 ]
  set_property CONFIG.N {12} $axis_sg_int4_v2_0


  # Create instance: axis_sg_int4_v2_1, and set properties
  set axis_sg_int4_v2_1 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_sg_int4_v2:1.0 axis_sg_int4_v2_1 ]
  set_property CONFIG.N {12} $axis_sg_int4_v2_1


  # Create instance: axis_switch_avg, and set properties
  set axis_switch_avg [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_switch:1.1 axis_switch_avg ]
  set_property -dict [list \
    CONFIG.NUM_SI {7} \
    CONFIG.ROUTING_MODE {1} \
  ] $axis_switch_avg


  # Create instance: axis_switch_buf, and set properties
  set axis_switch_buf [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_switch:1.1 axis_switch_buf ]
  set_property -dict [list \
    CONFIG.NUM_SI {7} \
    CONFIG.ROUTING_MODE {1} \
  ] $axis_switch_buf


  # Create instance: axis_switch_ddr, and set properties
  set axis_switch_ddr [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_switch:1.1 axis_switch_ddr ]
  set_property -dict [list \
    CONFIG.NUM_SI {6} \
    CONFIG.ROUTING_MODE {1} \
  ] $axis_switch_ddr


  # Create instance: axis_switch_gen, and set properties
  set axis_switch_gen [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_switch:1.1 axis_switch_gen ]
  set_property -dict [list \
    CONFIG.DECODER_REG {1} \
    CONFIG.NUM_MI {4} \
    CONFIG.NUM_SI {1} \
    CONFIG.ROUTING_MODE {1} \
  ] $axis_switch_gen


  # Create instance: axis_switch_mr, and set properties
  set axis_switch_mr [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_switch:1.1 axis_switch_mr ]
  set_property -dict [list \
    CONFIG.NUM_SI {2} \
    CONFIG.ROUTING_MODE {1} \
  ] $axis_switch_mr


  # Create instance: clk_core, and set properties
  set clk_core [ create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_core ]
  set_property -dict [list \
    CONFIG.CLKOUT1_JITTER {90.348} \
    CONFIG.CLKOUT1_PHASE_ERROR {80.725} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {204.8} \
    CONFIG.MMCM_CLKFBOUT_MULT_F {5.875} \
    CONFIG.MMCM_CLKOUT0_DIVIDE_F {5.875} \
    CONFIG.MMCM_DIVCLK_DIVIDE {3} \
    CONFIG.OPTIMIZE_CLOCKING_STRUCTURE_EN {true} \
    CONFIG.PRIM_SOURCE {Global_buffer} \
    CONFIG.RESET_PORT {reset} \
    CONFIG.RESET_TYPE {ACTIVE_HIGH} \
  ] $clk_core


  # Create instance: ps8_0_axi_periph, and set properties
  set ps8_0_axi_periph [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 ps8_0_axi_periph ]
  set_property CONFIG.NUM_MI {31} $ps8_0_axi_periph


  # Create instance: usp_rf_data_converter_0, and set properties
  set usp_rf_data_converter_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:usp_rf_data_converter:2.6 usp_rf_data_converter_0 ]
  set_property -dict [list \
    CONFIG.ADC2_Clock_Dist {0} \
    CONFIG.ADC2_Outclk_Freq {307.200} \
    CONFIG.ADC2_PLL_Enable {true} \
    CONFIG.ADC2_Refclk_Freq {245.760} \
    CONFIG.ADC2_Sampling_Rate {2.4576} \
    CONFIG.ADC_Coarse_Mixer_Freq20 {3} \
    CONFIG.ADC_Coarse_Mixer_Freq21 {3} \
    CONFIG.ADC_Coarse_Mixer_Freq22 {2} \
    CONFIG.ADC_Coarse_Mixer_Freq23 {3} \
    CONFIG.ADC_Data_Type21 {0} \
    CONFIG.ADC_Data_Type22 {1} \
    CONFIG.ADC_Data_Width20 {8} \
    CONFIG.ADC_Data_Width21 {8} \
    CONFIG.ADC_Data_Width22 {8} \
    CONFIG.ADC_Decimation_Mode20 {1} \
    CONFIG.ADC_Decimation_Mode21 {1} \
    CONFIG.ADC_Decimation_Mode22 {2} \
    CONFIG.ADC_Decimation_Mode23 {1} \
    CONFIG.ADC_Mixer_Mode21 {2} \
    CONFIG.ADC_Mixer_Mode22 {0} \
    CONFIG.ADC_Mixer_Type20 {1} \
    CONFIG.ADC_Mixer_Type21 {1} \
    CONFIG.ADC_Mixer_Type22 {1} \
    CONFIG.ADC_Mixer_Type23 {1} \
    CONFIG.ADC_OBS22 {false} \
    CONFIG.ADC_OBS23 {false} \
    CONFIG.ADC_Slice00_Enable {false} \
    CONFIG.ADC_Slice20_Enable {true} \
    CONFIG.ADC_Slice21_Enable {true} \
    CONFIG.ADC_Slice22_Enable {true} \
    CONFIG.ADC_Slice23_Enable {true} \
    CONFIG.ADC_Slice30_Enable {false} \
    CONFIG.DAC2_Clock_Dist {1} \
    CONFIG.DAC2_Outclk_Freq {614.400} \
    CONFIG.DAC2_PLL_Enable {true} \
    CONFIG.DAC2_Refclk_Freq {245.760} \
    CONFIG.DAC2_Sampling_Rate {9.8304} \
    CONFIG.DAC3_Clock_Source {6} \
    CONFIG.DAC3_Outclk_Freq {430.080} \
    CONFIG.DAC3_PLL_Enable {true} \
    CONFIG.DAC3_Refclk_Freq {245.760} \
    CONFIG.DAC3_Sampling_Rate {6.88128} \
    CONFIG.DAC_Coarse_Mixer_Freq20 {3} \
    CONFIG.DAC_Coarse_Mixer_Freq21 {3} \
    CONFIG.DAC_Coarse_Mixer_Freq22 {3} \
    CONFIG.DAC_Data_Width30 {8} \
    CONFIG.DAC_Data_Width31 {8} \
    CONFIG.DAC_Data_Width32 {8} \
    CONFIG.DAC_Interpolation_Mode20 {1} \
    CONFIG.DAC_Interpolation_Mode21 {1} \
    CONFIG.DAC_Interpolation_Mode22 {1} \
    CONFIG.DAC_Interpolation_Mode30 {4} \
    CONFIG.DAC_Interpolation_Mode31 {4} \
    CONFIG.DAC_Interpolation_Mode32 {4} \
    CONFIG.DAC_Mixer_Mode30 {0} \
    CONFIG.DAC_Mixer_Mode31 {0} \
    CONFIG.DAC_Mixer_Mode32 {0} \
    CONFIG.DAC_Mixer_Type20 {1} \
    CONFIG.DAC_Mixer_Type21 {1} \
    CONFIG.DAC_Mixer_Type22 {1} \
    CONFIG.DAC_Mixer_Type30 {2} \
    CONFIG.DAC_Mixer_Type31 {2} \
    CONFIG.DAC_Mixer_Type32 {2} \
    CONFIG.DAC_Mode20 {3} \
    CONFIG.DAC_Mode21 {3} \
    CONFIG.DAC_Mode22 {3} \
    CONFIG.DAC_Mode30 {0} \
    CONFIG.DAC_Mode31 {0} \
    CONFIG.DAC_Mode32 {0} \
    CONFIG.DAC_Slice00_Enable {false} \
    CONFIG.DAC_Slice10_Enable {false} \
    CONFIG.DAC_Slice12_Enable {false} \
    CONFIG.DAC_Slice20_Enable {true} \
    CONFIG.DAC_Slice21_Enable {true} \
    CONFIG.DAC_Slice22_Enable {true} \
    CONFIG.DAC_Slice23_Enable {false} \
    CONFIG.DAC_Slice30_Enable {true} \
    CONFIG.DAC_Slice31_Enable {true} \
    CONFIG.DAC_Slice32_Enable {true} \
    CONFIG.DAC_Slice33_Enable {false} \
    CONFIG.DAC_VOP_Mode {0} \
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
    CONFIG.PSU_BANK_0_IO_STANDARD {LVCMOS18} \
    CONFIG.PSU_BANK_1_IO_STANDARD {LVCMOS18} \
    CONFIG.PSU_BANK_2_IO_STANDARD {LVCMOS18} \
    CONFIG.PSU_BANK_3_IO_STANDARD {LVCMOS33} \
    CONFIG.PSU_DDR_RAM_HIGHADDR {0xFFFFFFFF} \
    CONFIG.PSU_DDR_RAM_HIGHADDR_OFFSET {0x800000000} \
    CONFIG.PSU_DDR_RAM_LOWADDR_OFFSET {0x80000000} \
    CONFIG.PSU_DYNAMIC_DDR_CONFIG_EN {1} \
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
    CONFIG.PSU_MIO_17_PULLUPDOWN {pullup} \
    CONFIG.PSU_MIO_17_SLEW {fast} \
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
    CONFIG.PSU__ACT_DDR_FREQ_MHZ {1049.999878} \
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
    CONFIG.PSU__CRF_APB__DDR_CTRL__ACT_FREQMHZ {524.999939} \
    CONFIG.PSU__CRF_APB__DDR_CTRL__FREQMHZ {1066} \
    CONFIG.PSU__CRF_APB__DDR_CTRL__SRCSEL {DPLL} \
    CONFIG.PSU__CRF_APB__DPDMA_REF_CTRL__ACT_FREQMHZ {599.999878} \
    CONFIG.PSU__CRF_APB__DPDMA_REF_CTRL__FREQMHZ {600} \
    CONFIG.PSU__CRF_APB__DPDMA_REF_CTRL__SRCSEL {APLL} \
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
    CONFIG.PSU__CRF_APB__GDMA_REF_CTRL__ACT_FREQMHZ {599.999878} \
    CONFIG.PSU__CRF_APB__GDMA_REF_CTRL__FREQMHZ {600} \
    CONFIG.PSU__CRF_APB__GDMA_REF_CTRL__SRCSEL {APLL} \
    CONFIG.PSU__CRF_APB__GPU_REF_CTRL__ACT_FREQMHZ {0} \
    CONFIG.PSU__CRF_APB__GPU_REF_CTRL__FREQMHZ {500} \
    CONFIG.PSU__CRF_APB__GPU_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRF_APB__GTGREF0_REF_CTRL__ACT_FREQMHZ {-1} \
    CONFIG.PSU__CRF_APB__GTGREF0_REF_CTRL__DIVISOR0 {-1} \
    CONFIG.PSU__CRF_APB__GTGREF0_REF_CTRL__FREQMHZ {-1} \
    CONFIG.PSU__CRF_APB__GTGREF0_REF_CTRL__SRCSEL {NA} \
    CONFIG.PSU__CRF_APB__GTGREF0__ENABLE {NA} \
    CONFIG.PSU__CRF_APB__PCIE_REF_CTRL__ACT_FREQMHZ {250} \
    CONFIG.PSU__CRF_APB__SATA_REF_CTRL__ACT_FREQMHZ {249.999954} \
    CONFIG.PSU__CRF_APB__SATA_REF_CTRL__FREQMHZ {250} \
    CONFIG.PSU__CRF_APB__SATA_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRF_APB__TOPSW_LSBUS_CTRL__ACT_FREQMHZ {99.999985} \
    CONFIG.PSU__CRF_APB__TOPSW_LSBUS_CTRL__FREQMHZ {100} \
    CONFIG.PSU__CRF_APB__TOPSW_LSBUS_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRF_APB__TOPSW_MAIN_CTRL__ACT_FREQMHZ {524.999939} \
    CONFIG.PSU__CRF_APB__TOPSW_MAIN_CTRL__FREQMHZ {533.33} \
    CONFIG.PSU__CRF_APB__TOPSW_MAIN_CTRL__SRCSEL {DPLL} \
    CONFIG.PSU__CRF_APB__VPLL_CTRL__FRACFREQ {27.138} \
    CONFIG.PSU__CRF_APB__VPLL_CTRL__SRCSEL {PSS_REF_CLK} \
    CONFIG.PSU__CRL_APB__ADMA_REF_CTRL__ACT_FREQMHZ {499.999908} \
    CONFIG.PSU__CRL_APB__ADMA_REF_CTRL__FREQMHZ {500} \
    CONFIG.PSU__CRL_APB__ADMA_REF_CTRL__SRCSEL {IOPLL} \
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
    CONFIG.PSU__CRL_APB__GEM1_REF_CTRL__ACT_FREQMHZ {125} \
    CONFIG.PSU__CRL_APB__GEM1_REF_CTRL__FREQMHZ {125} \
    CONFIG.PSU__CRL_APB__GEM1_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__GEM2_REF_CTRL__ACT_FREQMHZ {125} \
    CONFIG.PSU__CRL_APB__GEM2_REF_CTRL__FREQMHZ {125} \
    CONFIG.PSU__CRL_APB__GEM2_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__GEM3_REF_CTRL__ACT_FREQMHZ {124.999977} \
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
    CONFIG.PSU__CRL_APB__IOU_SWITCH_CTRL__ACT_FREQMHZ {249.999954} \
    CONFIG.PSU__CRL_APB__IOU_SWITCH_CTRL__FREQMHZ {250} \
    CONFIG.PSU__CRL_APB__IOU_SWITCH_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__LPD_LSBUS_CTRL__ACT_FREQMHZ {99.999985} \
    CONFIG.PSU__CRL_APB__LPD_LSBUS_CTRL__FREQMHZ {100} \
    CONFIG.PSU__CRL_APB__LPD_LSBUS_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__LPD_SWITCH_CTRL__ACT_FREQMHZ {499.999908} \
    CONFIG.PSU__CRL_APB__LPD_SWITCH_CTRL__FREQMHZ {500} \
    CONFIG.PSU__CRL_APB__LPD_SWITCH_CTRL__SRCSEL {IOPLL} \
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
    CONFIG.PSU__CRL_APB__QSPI_REF_CTRL__ACT_FREQMHZ {124.999977} \
    CONFIG.PSU__CRL_APB__QSPI_REF_CTRL__FREQMHZ {125} \
    CONFIG.PSU__CRL_APB__QSPI_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__RPLL_CTRL__FRACFREQ {27.138} \
    CONFIG.PSU__CRL_APB__RPLL_CTRL__SRCSEL {PSS_REF_CLK} \
    CONFIG.PSU__CRL_APB__SDIO0_REF_CTRL__ACT_FREQMHZ {200} \
    CONFIG.PSU__CRL_APB__SDIO0_REF_CTRL__FREQMHZ {200} \
    CONFIG.PSU__CRL_APB__SDIO0_REF_CTRL__SRCSEL {RPLL} \
    CONFIG.PSU__CRL_APB__SDIO1_REF_CTRL__ACT_FREQMHZ {187.499969} \
    CONFIG.PSU__CRL_APB__SDIO1_REF_CTRL__FREQMHZ {200} \
    CONFIG.PSU__CRL_APB__SDIO1_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__SPI0_REF_CTRL__ACT_FREQMHZ {214} \
    CONFIG.PSU__CRL_APB__SPI0_REF_CTRL__FREQMHZ {200} \
    CONFIG.PSU__CRL_APB__SPI0_REF_CTRL__SRCSEL {RPLL} \
    CONFIG.PSU__CRL_APB__SPI1_REF_CTRL__ACT_FREQMHZ {214} \
    CONFIG.PSU__CRL_APB__SPI1_REF_CTRL__FREQMHZ {200} \
    CONFIG.PSU__CRL_APB__SPI1_REF_CTRL__SRCSEL {RPLL} \
    CONFIG.PSU__CRL_APB__TIMESTAMP_REF_CTRL__ACT_FREQMHZ {99.999985} \
    CONFIG.PSU__CRL_APB__TIMESTAMP_REF_CTRL__FREQMHZ {100} \
    CONFIG.PSU__CRL_APB__TIMESTAMP_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__UART0_REF_CTRL__ACT_FREQMHZ {99.999985} \
    CONFIG.PSU__CRL_APB__UART0_REF_CTRL__FREQMHZ {100} \
    CONFIG.PSU__CRL_APB__UART0_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__UART1_REF_CTRL__ACT_FREQMHZ {99.999001} \
    CONFIG.PSU__CRL_APB__UART1_REF_CTRL__FREQMHZ {100} \
    CONFIG.PSU__CRL_APB__UART1_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__USB0_BUS_REF_CTRL__ACT_FREQMHZ {249.999954} \
    CONFIG.PSU__CRL_APB__USB0_BUS_REF_CTRL__FREQMHZ {250} \
    CONFIG.PSU__CRL_APB__USB0_BUS_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__USB1_BUS_REF_CTRL__ACT_FREQMHZ {250} \
    CONFIG.PSU__CRL_APB__USB1_BUS_REF_CTRL__FREQMHZ {250} \
    CONFIG.PSU__CRL_APB__USB1_BUS_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__USB3_DUAL_REF_CTRL__ACT_FREQMHZ {19.999996} \
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
    CONFIG.PSU__FPD_SLCR__WDT1__ACT_FREQMHZ {99.999985} \
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
    CONFIG.PSU__IOU_SLCR__WDT0__ACT_FREQMHZ {99.999985} \
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
    CONFIG.PSU__IRQ_P2F_LP_WDT__INT {0} \
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
    CONFIG.PSU__PROTECTION__MASTERS {USB1:NonSecure;0|USB0:NonSecure;1|S_AXI_LPD:NA;0|S_AXI_HPC1_FPD:NA;0|S_AXI_HPC0_FPD:NA;1|S_AXI_HP3_FPD:NA;0|S_AXI_HP2_FPD:NA;0|S_AXI_HP1_FPD:NA;0|S_AXI_HP0_FPD:NA;0|S_AXI_ACP:NA;0|S_AXI_ACE:NA;0|SD1:NonSecure;1|SD0:NonSecure;0|SATA1:NonSecure;1|SATA0:NonSecure;1|RPU1:Secure;1|RPU0:Secure;1|QSPI:NonSecure;1|PMU:NA;1|PCIe:NonSecure;0|NAND:NonSecure;0|LDMA:NonSecure;1|GPU:NonSecure;1|GEM3:NonSecure;1|GEM2:NonSecure;0|GEM1:NonSecure;0|GEM0:NonSecure;0|FDMA:NonSecure;1|DP:NonSecure;0|DAP:NA;1|Coresight:NA;1|CSU:NA;1|APU:NA;1}\
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
    CONFIG.PSU__PSS_REF_CLK__FREQMHZ {33.33333} \
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
    CONFIG.PSU__SAXIGP0__DATA_WIDTH {128} \
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
    CONFIG.PSU__USE__IRQ1 {0} \
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


  # Create instance: ddr4
  create_hier_cell_ddr4 [current_bd_instance .] ddr4

  # Create instance: clk104_gpio, and set properties
  set clk104_gpio [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 clk104_gpio ]
  set_property -dict [list \
    CONFIG.C_ALL_OUTPUTS {1} \
    CONFIG.C_GPIO_WIDTH {2} \
  ] $clk104_gpio


  # Create instance: axis_avg_buffer_0, and set properties
  set axis_avg_buffer_0 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_avg_buffer:1.2 axis_avg_buffer_0 ]
  set_property -dict [list \
    CONFIG.N_AVG {13} \
    CONFIG.N_BUF {12} \
  ] $axis_avg_buffer_0


  # Create instance: axis_avg_buffer_1, and set properties
  set axis_avg_buffer_1 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_avg_buffer:1.2 axis_avg_buffer_1 ]
  set_property -dict [list \
    CONFIG.N_AVG {13} \
    CONFIG.N_BUF {12} \
  ] $axis_avg_buffer_1


  # Create instance: axis_avg_buffer_2, and set properties
  set axis_avg_buffer_2 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_avg_buffer:1.2 axis_avg_buffer_2 ]
  set_property CONFIG.N_AVG {13} $axis_avg_buffer_2


  # Create instance: axis_avg_buffer_3, and set properties
  set axis_avg_buffer_3 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_avg_buffer:1.2 axis_avg_buffer_3 ]
  set_property CONFIG.N_AVG {13} $axis_avg_buffer_3


  # Create instance: axis_avg_buffer_4, and set properties
  set axis_avg_buffer_4 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_avg_buffer:1.2 axis_avg_buffer_4 ]
  set_property CONFIG.N_AVG {13} $axis_avg_buffer_4


  # Create instance: axis_avg_buffer_5, and set properties
  set axis_avg_buffer_5 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_avg_buffer:1.2 axis_avg_buffer_5 ]
  set_property CONFIG.N_AVG {13} $axis_avg_buffer_5


  # Create instance: axis_avg_buffer_6, and set properties
  set axis_avg_buffer_6 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_avg_buffer:1.2 axis_avg_buffer_6 ]
  set_property -dict [list \
    CONFIG.N_AVG {13} \
    CONFIG.N_BUF {12} \
  ] $axis_avg_buffer_6


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
    CONFIG.DEBUG {1} \
    CONFIG.DIVIDER {1} \
    CONFIG.DMEM_AW {14} \
    CONFIG.EXT_FLAG {0} \
    CONFIG.IN_PORT_QTY {7} \
    CONFIG.IO_CTRL {1} \
    CONFIG.OUT_DPORT_DW {8} \
    CONFIG.OUT_DPORT_QTY {1} \
    CONFIG.OUT_TRIG_QTY {17} \
    CONFIG.OUT_WPORT_QTY {5} \
    CONFIG.PMEM_AW {12} \
    CONFIG.WMEM_AW {10} \
  ] $qick_processor_0


  # Create interface connections
  connect_bd_intf_net -intf_net adc2_clk_0_1 [get_bd_intf_ports adc2_clk_0] [get_bd_intf_pins usp_rf_data_converter_0/adc2_clk]
  connect_bd_intf_net -intf_net axi_dma_0_M_AXIS_MM2S1 [get_bd_intf_pins axi_dma_gen/M_AXIS_MM2S] [get_bd_intf_pins axis_switch_gen/S00_AXIS]
  connect_bd_intf_net -intf_net axi_dma_0_M_AXI_MM2S [get_bd_intf_pins axi_dma_tproc/M_AXI_MM2S] [get_bd_intf_pins axi_smc/S00_AXI]
  connect_bd_intf_net -intf_net axi_dma_0_M_AXI_MM2S1 [get_bd_intf_pins axi_dma_gen/M_AXI_MM2S] [get_bd_intf_pins axi_smc/S02_AXI]
  connect_bd_intf_net -intf_net axi_dma_0_M_AXI_S2MM [get_bd_intf_pins axi_dma_tproc/M_AXI_S2MM] [get_bd_intf_pins axi_smc/S01_AXI]
  connect_bd_intf_net -intf_net axi_dma_avg_M_AXI_S2MM [get_bd_intf_pins axi_dma_avg/M_AXI_S2MM] [get_bd_intf_pins axi_smc/S03_AXI]
  connect_bd_intf_net -intf_net axi_dma_buf_M_AXI_S2MM [get_bd_intf_pins axi_dma_buf/M_AXI_S2MM] [get_bd_intf_pins axi_smc/S04_AXI]
  connect_bd_intf_net -intf_net axi_dma_mr_M_AXI_S2MM [get_bd_intf_pins axi_dma_mr/M_AXI_S2MM] [get_bd_intf_pins axi_smc/S05_AXI]
  connect_bd_intf_net -intf_net axi_dma_tproc_M_AXIS_MM2S [get_bd_intf_pins axi_dma_tproc/M_AXIS_MM2S] [get_bd_intf_pins qick_processor_0/s_dma_axis_i]
  connect_bd_intf_net -intf_net axi_interconnect_0_M00_AXI [get_bd_intf_pins axi_dma_tproc/S_AXI_LITE] [get_bd_intf_pins ps8_0_axi_periph/M00_AXI]
  connect_bd_intf_net -intf_net axi_interconnect_0_M08_AXI [get_bd_intf_pins ps8_0_axi_periph/M08_AXI] [get_bd_intf_pins usp_rf_data_converter_0/s_axi]
  connect_bd_intf_net -intf_net axis_avg_buffer_0_m0_axis [get_bd_intf_pins axis_avg_buffer_0/m0_axis] [get_bd_intf_pins axis_switch_avg/S00_AXIS]
  connect_bd_intf_net -intf_net axis_avg_buffer_0_m1_axis [get_bd_intf_pins axis_avg_buffer_0/m1_axis] [get_bd_intf_pins axis_switch_buf/S00_AXIS]
  connect_bd_intf_net -intf_net axis_avg_buffer_0_m2_axis [get_bd_intf_pins axis_avg_buffer_0/m2_axis] [get_bd_intf_pins axis_clk_cnvrt_avg_0/S_AXIS]
  connect_bd_intf_net -intf_net axis_avg_buffer_1_m0_axis [get_bd_intf_pins axis_avg_buffer_1/m0_axis] [get_bd_intf_pins axis_switch_avg/S01_AXIS]
  connect_bd_intf_net -intf_net axis_avg_buffer_1_m1_axis [get_bd_intf_pins axis_avg_buffer_1/m1_axis] [get_bd_intf_pins axis_switch_buf/S01_AXIS]
  connect_bd_intf_net -intf_net axis_avg_buffer_1_m2_axis [get_bd_intf_pins axis_avg_buffer_1/m2_axis] [get_bd_intf_pins axis_clk_cnvrt_avg_1/S_AXIS]
  connect_bd_intf_net -intf_net axis_avg_buffer_2_m0_axis [get_bd_intf_pins axis_avg_buffer_2/m0_axis] [get_bd_intf_pins axis_switch_avg/S02_AXIS]
  connect_bd_intf_net -intf_net axis_avg_buffer_2_m1_axis [get_bd_intf_pins axis_avg_buffer_2/m1_axis] [get_bd_intf_pins axis_switch_buf/S02_AXIS]
  connect_bd_intf_net -intf_net axis_avg_buffer_2_m2_axis [get_bd_intf_pins axis_avg_buffer_2/m2_axis] [get_bd_intf_pins axis_clk_cnvrt_avg_2/S_AXIS]
  connect_bd_intf_net -intf_net axis_avg_buffer_3_m0_axis [get_bd_intf_pins axis_avg_buffer_3/m0_axis] [get_bd_intf_pins axis_switch_avg/S03_AXIS]
  connect_bd_intf_net -intf_net axis_avg_buffer_3_m1_axis [get_bd_intf_pins axis_avg_buffer_3/m1_axis] [get_bd_intf_pins axis_switch_buf/S03_AXIS]
  connect_bd_intf_net -intf_net axis_avg_buffer_3_m2_axis [get_bd_intf_pins axis_avg_buffer_3/m2_axis] [get_bd_intf_pins axis_clk_cnvrt_avg_3/S_AXIS]
  connect_bd_intf_net -intf_net axis_avg_buffer_4_m0_axis [get_bd_intf_pins axis_avg_buffer_4/m0_axis] [get_bd_intf_pins axis_switch_avg/S04_AXIS]
  connect_bd_intf_net -intf_net axis_avg_buffer_4_m1_axis [get_bd_intf_pins axis_avg_buffer_4/m1_axis] [get_bd_intf_pins axis_switch_buf/S04_AXIS]
  connect_bd_intf_net -intf_net axis_avg_buffer_4_m2_axis [get_bd_intf_pins axis_avg_buffer_4/m2_axis] [get_bd_intf_pins axis_clk_cnvrt_avg_4/S_AXIS]
  connect_bd_intf_net -intf_net axis_avg_buffer_5_m0_axis [get_bd_intf_pins axis_avg_buffer_5/m0_axis] [get_bd_intf_pins axis_switch_avg/S05_AXIS]
  connect_bd_intf_net -intf_net axis_avg_buffer_5_m1_axis [get_bd_intf_pins axis_avg_buffer_5/m1_axis] [get_bd_intf_pins axis_switch_buf/S05_AXIS]
  connect_bd_intf_net -intf_net axis_avg_buffer_5_m2_axis [get_bd_intf_pins axis_avg_buffer_5/m2_axis] [get_bd_intf_pins axis_clk_cnvrt_avg_5/S_AXIS]
  connect_bd_intf_net -intf_net axis_avg_buffer_6_m0_axis [get_bd_intf_pins axis_avg_buffer_6/m0_axis] [get_bd_intf_pins axis_switch_avg/S06_AXIS]
  connect_bd_intf_net -intf_net axis_avg_buffer_6_m1_axis [get_bd_intf_pins axis_avg_buffer_6/m1_axis] [get_bd_intf_pins axis_switch_buf/S06_AXIS]
  connect_bd_intf_net -intf_net axis_avg_buffer_6_m2_axis [get_bd_intf_pins axis_avg_buffer_6/m2_axis] [get_bd_intf_pins axis_clk_cnvrt_avg_6/S_AXIS]
  connect_bd_intf_net -intf_net axis_broadcaster_0_M00_AXIS [get_bd_intf_pins axis_avg_buffer_0/s_axis] [get_bd_intf_pins axis_broadcaster_0/M00_AXIS]
  connect_bd_intf_net -intf_net axis_broadcaster_0_M01_AXIS [get_bd_intf_pins axis_broadcaster_0/M01_AXIS] [get_bd_intf_pins axis_switch_ddr/S00_AXIS]
  connect_bd_intf_net -intf_net axis_broadcaster_1_M00_AXIS [get_bd_intf_pins axis_avg_buffer_6/s_axis] [get_bd_intf_pins axis_broadcaster_1/M00_AXIS]
  connect_bd_intf_net -intf_net axis_broadcaster_1_M01_AXIS [get_bd_intf_pins axis_broadcaster_1/M01_AXIS] [get_bd_intf_pins axis_switch_ddr/S05_AXIS]
  connect_bd_intf_net -intf_net axis_broadcaster_2_M00_AXIS [get_bd_intf_pins axis_avg_buffer_2/s_axis] [get_bd_intf_pins axis_broadcaster_2/M00_AXIS]
  connect_bd_intf_net -intf_net axis_broadcaster_2_M01_AXIS [get_bd_intf_pins axis_broadcaster_2/M01_AXIS] [get_bd_intf_pins axis_switch_ddr/S01_AXIS]
  connect_bd_intf_net -intf_net axis_broadcaster_3_M00_AXIS [get_bd_intf_pins axis_avg_buffer_3/s_axis] [get_bd_intf_pins axis_broadcaster_3/M00_AXIS]
  connect_bd_intf_net -intf_net axis_broadcaster_3_M01_AXIS [get_bd_intf_pins axis_broadcaster_3/M01_AXIS] [get_bd_intf_pins axis_switch_ddr/S02_AXIS]
  connect_bd_intf_net -intf_net axis_broadcaster_4_M00_AXIS [get_bd_intf_pins axis_avg_buffer_4/s_axis] [get_bd_intf_pins axis_broadcaster_4/M00_AXIS]
  connect_bd_intf_net -intf_net axis_broadcaster_4_M01_AXIS [get_bd_intf_pins axis_broadcaster_4/M01_AXIS] [get_bd_intf_pins axis_switch_ddr/S03_AXIS]
  connect_bd_intf_net -intf_net axis_broadcaster_5_M00_AXIS [get_bd_intf_pins axis_avg_buffer_5/s_axis] [get_bd_intf_pins axis_broadcaster_5/M00_AXIS]
  connect_bd_intf_net -intf_net axis_broadcaster_5_M01_AXIS [get_bd_intf_pins axis_broadcaster_5/M01_AXIS] [get_bd_intf_pins axis_switch_ddr/S04_AXIS]
  connect_bd_intf_net -intf_net axis_cdcsync_v1_1_m0_axis [get_bd_intf_pins axis_cdcsync_v1_1/m0_axis] [get_bd_intf_pins sg_translator_3/s_tproc_axis]
  connect_bd_intf_net -intf_net axis_cdcsync_v1_1_m1_axis [get_bd_intf_pins axis_cdcsync_v1_1/m1_axis] [get_bd_intf_pins sg_translator_4/s_tproc_axis]
  connect_bd_intf_net -intf_net axis_cdcsync_v1_1_m2_axis [get_bd_intf_pins axis_cdcsync_v1_1/m2_axis] [get_bd_intf_pins sg_translator_5/s_tproc_axis]
  connect_bd_intf_net -intf_net axis_clk_cnvrt_avg_0_M_AXIS [get_bd_intf_pins axis_clk_cnvrt_avg_0/M_AXIS] [get_bd_intf_pins qick_processor_0/s0_axis]
  connect_bd_intf_net -intf_net axis_clk_cnvrt_avg_1_M_AXIS [get_bd_intf_pins axis_clk_cnvrt_avg_1/M_AXIS] [get_bd_intf_pins qick_processor_0/s1_axis]
  connect_bd_intf_net -intf_net axis_clk_cnvrt_avg_2_M_AXIS [get_bd_intf_pins axis_clk_cnvrt_avg_2/M_AXIS] [get_bd_intf_pins qick_processor_0/s2_axis]
  connect_bd_intf_net -intf_net axis_clk_cnvrt_avg_3_M_AXIS [get_bd_intf_pins axis_clk_cnvrt_avg_3/M_AXIS] [get_bd_intf_pins qick_processor_0/s3_axis]
  connect_bd_intf_net -intf_net axis_clk_cnvrt_avg_4_M_AXIS [get_bd_intf_pins axis_clk_cnvrt_avg_4/M_AXIS] [get_bd_intf_pins qick_processor_0/s4_axis]
  connect_bd_intf_net -intf_net axis_clk_cnvrt_avg_5_M_AXIS [get_bd_intf_pins axis_clk_cnvrt_avg_5/M_AXIS] [get_bd_intf_pins qick_processor_0/s5_axis]
  connect_bd_intf_net -intf_net axis_clk_cnvrt_avg_6_M_AXIS [get_bd_intf_pins axis_clk_cnvrt_avg_6/M_AXIS] [get_bd_intf_pins qick_processor_0/s6_axis]
  connect_bd_intf_net -intf_net axis_clock_converter_1_M_AXIS1 [get_bd_intf_pins axis_clock_converter_1/M_AXIS] [get_bd_intf_pins sg_translator_6/s_tproc_axis]
  connect_bd_intf_net -intf_net axis_clock_converter_2_M_AXIS [get_bd_intf_pins axis_clock_converter_3/M_AXIS] [get_bd_intf_pins axis_resampler_2x1_v1_0/s_axis]
  connect_bd_intf_net -intf_net axis_dyn_readout_v1_0_m0_axis [get_bd_intf_pins axis_dyn_readout_v1_0/m0_axis] [get_bd_intf_pins axis_switch_mr/S00_AXIS]
  connect_bd_intf_net -intf_net axis_dyn_readout_v1_0_m1_axis [get_bd_intf_pins axis_broadcaster_0/S_AXIS] [get_bd_intf_pins axis_dyn_readout_v1_0/m1_axis]
  connect_bd_intf_net -intf_net axis_pfb_readout_v3_0_m0_axis [get_bd_intf_pins axis_broadcaster_2/S_AXIS] [get_bd_intf_pins axis_pfb_readout_v3_0/m0_axis]
  connect_bd_intf_net -intf_net axis_pfb_readout_v3_0_m1_axis [get_bd_intf_pins axis_broadcaster_3/S_AXIS] [get_bd_intf_pins axis_pfb_readout_v3_0/m1_axis]
  connect_bd_intf_net -intf_net axis_pfb_readout_v3_0_m2_axis [get_bd_intf_pins axis_broadcaster_4/S_AXIS] [get_bd_intf_pins axis_pfb_readout_v3_0/m2_axis]
  connect_bd_intf_net -intf_net axis_pfb_readout_v3_0_m3_axis [get_bd_intf_pins axis_broadcaster_5/S_AXIS] [get_bd_intf_pins axis_pfb_readout_v3_0/m3_axis]
  connect_bd_intf_net -intf_net axis_readout_v2_0_m0_axis [get_bd_intf_pins axis_readout_v2_0/m0_axis] [get_bd_intf_pins axis_switch_mr/S01_AXIS]
  connect_bd_intf_net -intf_net axis_readout_v2_0_m1_axis [get_bd_intf_pins axis_broadcaster_1/S_AXIS] [get_bd_intf_pins axis_readout_v2_0/m1_axis]
  connect_bd_intf_net -intf_net axis_readout_v3_0_m_axis [get_bd_intf_pins axis_avg_buffer_1/s_axis] [get_bd_intf_pins axis_readout_v3_0/m_axis]
  connect_bd_intf_net -intf_net axis_register_slice_0_m_axis [get_bd_intf_pins axis_register_slice_0/m_axis] [get_bd_intf_pins usp_rf_data_converter_0/s20_axis]
  connect_bd_intf_net -intf_net axis_register_slice_10_M_AXIS [get_bd_intf_pins axis_register_slice_10/M_AXIS] [get_bd_intf_pins axis_readout_v3_0/s0_axis]
  connect_bd_intf_net -intf_net axis_register_slice_1_m_axis [get_bd_intf_pins axis_register_slice_1/m_axis] [get_bd_intf_pins usp_rf_data_converter_0/s21_axis]
  connect_bd_intf_net -intf_net axis_register_slice_2_m_axis1 [get_bd_intf_pins axis_register_slice_2/m_axis] [get_bd_intf_pins usp_rf_data_converter_0/s22_axis]
  connect_bd_intf_net -intf_net axis_register_slice_3_M_AXIS [get_bd_intf_pins axis_readout_v3_0/s1_axis] [get_bd_intf_pins axis_register_slice_6/M_AXIS]
  connect_bd_intf_net -intf_net axis_register_slice_3_M_AXIS1 [get_bd_intf_pins axis_register_slice_3/M_AXIS] [get_bd_intf_pins axis_signal_gen_v6_0/s1_axis]
  connect_bd_intf_net -intf_net axis_register_slice_4_M_AXIS [get_bd_intf_pins axis_register_slice_4/M_AXIS] [get_bd_intf_pins axis_register_slice_8/S_AXIS]
  connect_bd_intf_net -intf_net axis_register_slice_5_M_AXIS [get_bd_intf_pins axis_register_slice_5/M_AXIS] [get_bd_intf_pins axis_signal_gen_v6_1/s1_axis]
  connect_bd_intf_net -intf_net axis_register_slice_8_M_AXIS [get_bd_intf_pins axis_register_slice_8/M_AXIS] [get_bd_intf_pins axis_sg_mux8_v1_0/s_axis]
  connect_bd_intf_net -intf_net axis_resampler_2x1_v1_0_m_axis [get_bd_intf_pins axis_register_slice_6/S_AXIS] [get_bd_intf_pins axis_resampler_2x1_v1_0/m_axis]
  connect_bd_intf_net -intf_net axis_sg_int4_v2_0_m_axis [get_bd_intf_pins axis_sg_int4_v2_0/m_axis] [get_bd_intf_pins usp_rf_data_converter_0/s30_axis]
  connect_bd_intf_net -intf_net axis_sg_int4_v2_1_m_axis [get_bd_intf_pins usp_rf_data_converter_0/s31_axis] [get_bd_intf_pins axis_sg_int4_v2_1/m_axis]
  connect_bd_intf_net -intf_net axis_sg_mixmux8_v1_0_m_axis [get_bd_intf_pins axis_sg_mixmux8_v1_0/m_axis] [get_bd_intf_pins usp_rf_data_converter_0/s32_axis]
  connect_bd_intf_net -intf_net axis_sg_mux8_v1_0_m_axis [get_bd_intf_pins axis_register_slice_1/s_axis] [get_bd_intf_pins axis_sg_mux8_v1_0/m_axis]
  connect_bd_intf_net -intf_net axis_signal_gen_v6_0_m_axis [get_bd_intf_pins axis_register_slice_0/s_axis] [get_bd_intf_pins axis_signal_gen_v6_0/m_axis]
  connect_bd_intf_net -intf_net axis_signal_gen_v6_1_m_axis [get_bd_intf_pins axis_signal_gen_v6_1/m_axis] [get_bd_intf_pins axis_register_slice_2/s_axis]
  connect_bd_intf_net -intf_net axis_switch_0_M00_AXIS [get_bd_intf_pins axis_signal_gen_v6_0/s0_axis] [get_bd_intf_pins axis_switch_gen/M00_AXIS]
  connect_bd_intf_net -intf_net axis_switch_avg_M00_AXIS [get_bd_intf_pins axi_dma_avg/S_AXIS_S2MM] [get_bd_intf_pins axis_switch_avg/M00_AXIS]
  connect_bd_intf_net -intf_net axis_switch_buf_M00_AXIS [get_bd_intf_pins axi_dma_buf/S_AXIS_S2MM] [get_bd_intf_pins axis_switch_buf/M00_AXIS]
  connect_bd_intf_net -intf_net axis_switch_ddr_M00_AXIS [get_bd_intf_pins ddr4/S_AXIS] [get_bd_intf_pins axis_switch_ddr/M00_AXIS]
  connect_bd_intf_net -intf_net axis_switch_gen_M01_AXIS [get_bd_intf_pins axis_switch_gen/M01_AXIS] [get_bd_intf_pins axis_signal_gen_v6_1/s0_axis]
  connect_bd_intf_net -intf_net axis_switch_gen_M02_AXIS [get_bd_intf_pins axis_switch_gen/M02_AXIS] [get_bd_intf_pins axis_sg_int4_v2_0/s0_axis]
  connect_bd_intf_net -intf_net axis_switch_gen_M03_AXIS [get_bd_intf_pins axis_sg_int4_v2_1/s0_axis] [get_bd_intf_pins axis_switch_gen/M03_AXIS]
  connect_bd_intf_net -intf_net axis_switch_mr_M00_AXIS [get_bd_intf_pins axis_switch_mr/M00_AXIS] [get_bd_intf_pins mr_buffer_et_0/s00_axis]
  connect_bd_intf_net -intf_net axis_tmux_v1_0_m0_axis [get_bd_intf_pins axis_tmux_v1_0/m0_axis] [get_bd_intf_pins sg_translator_2/s_tproc_axis]
  connect_bd_intf_net -intf_net axis_tmux_v1_0_m1_axis [get_bd_intf_pins axis_tmux_v1_0/m1_axis] [get_bd_intf_pins axis_cdcsync_v1_1/s2_axis]
  connect_bd_intf_net -intf_net axis_tmux_v1_0_m2_axis [get_bd_intf_pins axis_tmux_v1_0/m2_axis] [get_bd_intf_pins axis_clock_converter_1/S_AXIS]
  connect_bd_intf_net -intf_net axis_tmux_v1_0_m3_axis [get_bd_intf_pins axis_tmux_v1_0/m3_axis] [get_bd_intf_pins sg_translator_7/s_tproc_axis]
  connect_bd_intf_net -intf_net dac2_clk_0_1 [get_bd_intf_ports dac2_clk_0] [get_bd_intf_pins usp_rf_data_converter_0/dac2_clk]
  connect_bd_intf_net -intf_net ddr4_0_C0_DDR4 [get_bd_intf_ports ddr4_sdram_c0] [get_bd_intf_pins ddr4/ddr4_sdram_c0]
  connect_bd_intf_net -intf_net default_sysclk_c0_300mhz_1 [get_bd_intf_ports default_sysclk_c0_300mhz] [get_bd_intf_pins ddr4/default_sysclk_c0_300mhz]
  connect_bd_intf_net -intf_net mr_buffer_et_0_m00_axis [get_bd_intf_pins axi_dma_mr/S_AXIS_S2MM] [get_bd_intf_pins mr_buffer_et_0/m00_axis]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M01_AXI [get_bd_intf_pins axis_avg_buffer_2/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M01_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M02_AXI [get_bd_intf_pins axis_signal_gen_v6_0/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M02_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M03_AXI [get_bd_intf_pins axis_sg_mux8_v1_0/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M03_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M04_AXI [get_bd_intf_pins ps8_0_axi_periph/M04_AXI] [get_bd_intf_pins axis_sg_mixmux8_v1_0/s_axi]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M05_AXI [get_bd_intf_pins axis_switch_mr/S_AXI_CTRL] [get_bd_intf_pins ps8_0_axi_periph/M05_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M06_AXI [get_bd_intf_pins axi_dma_gen/S_AXI_LITE] [get_bd_intf_pins ps8_0_axi_periph/M06_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M07_AXI [get_bd_intf_pins axis_switch_gen/S_AXI_CTRL] [get_bd_intf_pins ps8_0_axi_periph/M07_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M09_AXI [get_bd_intf_pins axis_avg_buffer_0/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M09_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M10_AXI [get_bd_intf_pins axis_avg_buffer_1/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M10_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M11_AXI [get_bd_intf_pins axis_avg_buffer_3/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M11_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M12_AXI [get_bd_intf_pins axis_avg_buffer_4/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M12_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M13_AXI [get_bd_intf_pins axis_avg_buffer_5/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M13_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M14_AXI [get_bd_intf_pins axis_pfb_readout_v3_0/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M14_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M15_AXI [get_bd_intf_pins axis_readout_v2_0/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M15_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M16_AXI [get_bd_intf_pins axis_avg_buffer_6/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M16_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M17_AXI [get_bd_intf_pins axis_switch_avg/S_AXI_CTRL] [get_bd_intf_pins ps8_0_axi_periph/M17_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M18_AXI [get_bd_intf_pins axis_switch_buf/S_AXI_CTRL] [get_bd_intf_pins ps8_0_axi_periph/M18_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M19_AXI [get_bd_intf_pins axi_dma_avg/S_AXI_LITE] [get_bd_intf_pins ps8_0_axi_periph/M19_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M20_AXI [get_bd_intf_pins axi_dma_buf/S_AXI_LITE] [get_bd_intf_pins ps8_0_axi_periph/M20_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M21_AXI [get_bd_intf_pins axi_dma_mr/S_AXI_LITE] [get_bd_intf_pins ps8_0_axi_periph/M21_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M22_AXI [get_bd_intf_pins ddr4/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M22_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M23_AXI [get_bd_intf_pins axis_switch_ddr/S_AXI_CTRL] [get_bd_intf_pins ps8_0_axi_periph/M23_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M24_AXI [get_bd_intf_pins ps8_0_axi_periph/M24_AXI] [get_bd_intf_pins axis_sg_int4_v2_0/s_axi]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M25_AXI [get_bd_intf_pins mr_buffer_et_0/s00_axi] [get_bd_intf_pins ps8_0_axi_periph/M25_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M26_AXI [get_bd_intf_pins axi_intc_0/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M26_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M27_AXI [get_bd_intf_pins ps8_0_axi_periph/M27_AXI] [get_bd_intf_pins axis_sg_int4_v2_1/s_axi]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M28_AXI [get_bd_intf_pins ps8_0_axi_periph/M28_AXI] [get_bd_intf_pins axis_signal_gen_v6_1/s_axi]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M29_AXI [get_bd_intf_pins qick_processor_0/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M29_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M30_AXI [get_bd_intf_pins ps8_0_axi_periph/M30_AXI] [get_bd_intf_pins clk104_gpio/S_AXI]
  connect_bd_intf_net -intf_net qick_processor_0_m0_axis [get_bd_intf_pins qick_processor_0/m0_axis] [get_bd_intf_pins sg_translator_0/s_tproc_axis]
  connect_bd_intf_net -intf_net qick_processor_0_m1_axis [get_bd_intf_pins qick_processor_0/m1_axis] [get_bd_intf_pins sg_translator_1/s_tproc_axis]
  connect_bd_intf_net -intf_net qick_processor_0_m2_axis [get_bd_intf_pins qick_processor_0/m2_axis] [get_bd_intf_pins axis_cdcsync_v1_1/s0_axis]
  connect_bd_intf_net -intf_net qick_processor_0_m3_axis [get_bd_intf_pins qick_processor_0/m3_axis] [get_bd_intf_pins axis_cdcsync_v1_1/s1_axis]
  connect_bd_intf_net -intf_net qick_processor_0_m4_axis [get_bd_intf_pins axis_tmux_v1_0/s_axis] [get_bd_intf_pins qick_processor_0/m4_axis]
  connect_bd_intf_net -intf_net qick_processor_0_m_dma_axis_o [get_bd_intf_pins axi_dma_tproc/S_AXIS_S2MM] [get_bd_intf_pins qick_processor_0/m_dma_axis_o]
  connect_bd_intf_net -intf_net sg_translator_0_m_gen_v6_axis [get_bd_intf_pins axis_register_slice_3/S_AXIS] [get_bd_intf_pins sg_translator_0/m_gen_v6_axis]
  connect_bd_intf_net -intf_net sg_translator_1_m_mux4_axis [get_bd_intf_pins axis_register_slice_4/S_AXIS] [get_bd_intf_pins sg_translator_1/m_mux4_axis]
  connect_bd_intf_net -intf_net sg_translator_2_m_gen_v6_axis [get_bd_intf_pins sg_translator_2/m_gen_v6_axis] [get_bd_intf_pins axis_register_slice_5/S_AXIS]
  connect_bd_intf_net -intf_net sg_translator_3_m_gen_v6_axis [get_bd_intf_pins sg_translator_3/m_gen_v6_axis] [get_bd_intf_pins axis_sg_int4_v2_0/s1_axis]
  connect_bd_intf_net -intf_net sg_translator_4_m_gen_v6_axis [get_bd_intf_pins sg_translator_4/m_gen_v6_axis] [get_bd_intf_pins axis_sg_int4_v2_1/s1_axis]
  connect_bd_intf_net -intf_net sg_translator_5_m_mux4_axis [get_bd_intf_pins axis_sg_mixmux8_v1_0/s_axis] [get_bd_intf_pins sg_translator_5/m_mux4_axis]
  connect_bd_intf_net -intf_net sg_translator_6_m_readout_v3_axis [get_bd_intf_pins axis_dyn_readout_v1_0/s0_axis] [get_bd_intf_pins sg_translator_6/m_readout_v3_axis]
  connect_bd_intf_net -intf_net sg_translator_7_m_readout_v3_axis [get_bd_intf_pins sg_translator_7/m_readout_v3_axis] [get_bd_intf_pins axis_register_slice_10/S_AXIS]
  connect_bd_intf_net -intf_net smartconnect_0_M00_AXI [get_bd_intf_pins axi_smc/M00_AXI] [get_bd_intf_pins zynq_ultra_ps_e_0/S_AXI_HPC0_FPD]
  connect_bd_intf_net -intf_net sysref_in_0_1 [get_bd_intf_ports sysref_in_0] [get_bd_intf_pins usp_rf_data_converter_0/sysref_in]
  connect_bd_intf_net -intf_net usp_rf_data_converter_0_m20_axis [get_bd_intf_pins axis_dyn_readout_v1_0/s1_axis] [get_bd_intf_pins usp_rf_data_converter_0/m20_axis]
  connect_bd_intf_net -intf_net usp_rf_data_converter_0_m21_axis [get_bd_intf_pins axis_clock_converter_3/S_AXIS] [get_bd_intf_pins usp_rf_data_converter_0/m21_axis]
  connect_bd_intf_net -intf_net usp_rf_data_converter_0_m22_axis [get_bd_intf_pins axis_pfb_readout_v3_0/s_axis] [get_bd_intf_pins usp_rf_data_converter_0/m22_axis]
  connect_bd_intf_net -intf_net usp_rf_data_converter_0_m23_axis [get_bd_intf_pins axis_readout_v2_0/s_axis] [get_bd_intf_pins usp_rf_data_converter_0/m23_axis]
  connect_bd_intf_net -intf_net usp_rf_data_converter_0_vout20 [get_bd_intf_ports vout0] [get_bd_intf_pins usp_rf_data_converter_0/vout20]
  connect_bd_intf_net -intf_net usp_rf_data_converter_0_vout21 [get_bd_intf_ports vout1] [get_bd_intf_pins usp_rf_data_converter_0/vout21]
  connect_bd_intf_net -intf_net usp_rf_data_converter_0_vout22 [get_bd_intf_ports vout2] [get_bd_intf_pins usp_rf_data_converter_0/vout22]
  connect_bd_intf_net -intf_net usp_rf_data_converter_0_vout30 [get_bd_intf_ports vout3] [get_bd_intf_pins usp_rf_data_converter_0/vout30]
  connect_bd_intf_net -intf_net usp_rf_data_converter_0_vout31 [get_bd_intf_ports vout4] [get_bd_intf_pins usp_rf_data_converter_0/vout31]
  connect_bd_intf_net -intf_net usp_rf_data_converter_0_vout32 [get_bd_intf_ports vout5] [get_bd_intf_pins usp_rf_data_converter_0/vout32]
  connect_bd_intf_net -intf_net vin20_0_1 [get_bd_intf_ports vin20_0] [get_bd_intf_pins usp_rf_data_converter_0/vin20]
  connect_bd_intf_net -intf_net vin21_0_1 [get_bd_intf_ports vin21_0] [get_bd_intf_pins usp_rf_data_converter_0/vin21]
  connect_bd_intf_net -intf_net vin22_0_1 [get_bd_intf_ports vin22_0] [get_bd_intf_pins usp_rf_data_converter_0/vin22]
  connect_bd_intf_net -intf_net vin23_0_1 [get_bd_intf_ports vin23_0] [get_bd_intf_pins usp_rf_data_converter_0/vin23]
  connect_bd_intf_net -intf_net zynq_ultra_ps_e_0_M_AXI_HPM0_FPD [get_bd_intf_pins ps8_0_axi_periph/S00_AXI] [get_bd_intf_pins zynq_ultra_ps_e_0/M_AXI_HPM0_FPD]
  connect_bd_intf_net -intf_net zynq_ultra_ps_e_0_M_AXI_HPM1_FPD [get_bd_intf_pins ddr4/S00_AXI] [get_bd_intf_pins zynq_ultra_ps_e_0/M_AXI_HPM1_FPD]

  # Create port connections
  connect_bd_net -net PMOD1_0_LS_1 [get_bd_ports PMOD1_0_LS] [get_bd_pins qick_processor_0/proc_start_i]
  connect_bd_net -net axi_dma_avg_s2mm_introut [get_bd_pins axi_dma_avg/s2mm_introut] [get_bd_pins xlconcat_intc/In0]
  connect_bd_net -net axi_dma_buf_s2mm_introut [get_bd_pins axi_dma_buf/s2mm_introut] [get_bd_pins xlconcat_intc/In1]
  connect_bd_net -net axi_dma_gen_mm2s_introut [get_bd_pins axi_dma_gen/mm2s_introut] [get_bd_pins xlconcat_intc/In3]
  connect_bd_net -net axi_dma_mr_s2mm_introut [get_bd_pins axi_dma_mr/s2mm_introut] [get_bd_pins xlconcat_intc/In2]
  connect_bd_net -net axi_dma_tproc_mm2s_introut [get_bd_pins axi_dma_tproc/mm2s_introut] [get_bd_pins xlconcat_intc/In4]
  connect_bd_net -net axi_dma_tproc_s2mm_introut [get_bd_pins axi_dma_tproc/s2mm_introut] [get_bd_pins xlconcat_intc/In5]
  connect_bd_net -net axi_intc_0_irq [get_bd_pins axi_intc_0/irq] [get_bd_pins zynq_ultra_ps_e_0/pl_ps_irq0]
  connect_bd_net -net clk104_gpio_gpio_io_o [get_bd_pins clk104_gpio/gpio_io_o] [get_bd_ports CLK104_CLK_SPI_MUX_SEL_LS]
  connect_bd_net -net clk_core_clk_out1 [get_bd_pins clk_core/clk_out1] [get_bd_pins rst_core/slowest_sync_clk] [get_bd_pins axis_clk_cnvrt_avg_0/m_axis_aclk] [get_bd_pins axis_clk_cnvrt_avg_1/m_axis_aclk] [get_bd_pins axis_clk_cnvrt_avg_2/m_axis_aclk] [get_bd_pins axis_clk_cnvrt_avg_3/m_axis_aclk] [get_bd_pins axis_clk_cnvrt_avg_4/m_axis_aclk] [get_bd_pins axis_clk_cnvrt_avg_5/m_axis_aclk] [get_bd_pins axis_clk_cnvrt_avg_6/m_axis_aclk] [get_bd_pins qick_processor_0/c_clk_i]
  connect_bd_net -net clk_core_locked [get_bd_pins clk_core/locked] [get_bd_pins rst_core/dcm_locked]
  connect_bd_net -net ddr4_0_c0_ddr4_ui_clk [get_bd_pins ddr4/c0_ddr4_ui_clk] [get_bd_pins zynq_ultra_ps_e_0/maxihpm1_fpd_aclk]
  connect_bd_net -net qick_processor_0_trig_0_o [get_bd_pins qick_processor_0/trig_0_o] [get_bd_ports PMOD0_0_LS]
  connect_bd_net -net qick_processor_0_trig_10_o [get_bd_pins qick_processor_0/trig_10_o] [get_bd_pins axis_avg_buffer_0/trigger]
  connect_bd_net -net qick_processor_0_trig_11_o [get_bd_pins qick_processor_0/trig_11_o] [get_bd_pins axis_avg_buffer_1/trigger]
  connect_bd_net -net qick_processor_0_trig_12_o [get_bd_pins qick_processor_0/trig_12_o] [get_bd_pins axis_avg_buffer_2/trigger]
  connect_bd_net -net qick_processor_0_trig_13_o [get_bd_pins qick_processor_0/trig_13_o] [get_bd_pins axis_avg_buffer_3/trigger]
  connect_bd_net -net qick_processor_0_trig_14_o [get_bd_pins qick_processor_0/trig_14_o] [get_bd_pins axis_avg_buffer_4/trigger]
  connect_bd_net -net qick_processor_0_trig_15_o [get_bd_pins qick_processor_0/trig_15_o] [get_bd_pins axis_avg_buffer_5/trigger]
  connect_bd_net -net qick_processor_0_trig_16_o [get_bd_pins qick_processor_0/trig_16_o] [get_bd_pins axis_avg_buffer_6/trigger]
  connect_bd_net -net qick_processor_0_trig_1_o [get_bd_pins qick_processor_0/trig_1_o] [get_bd_ports PMOD0_1_LS]
  connect_bd_net -net qick_processor_0_trig_2_o [get_bd_pins qick_processor_0/trig_2_o] [get_bd_ports PMOD0_2_LS]
  connect_bd_net -net qick_processor_0_trig_3_o [get_bd_pins qick_processor_0/trig_3_o] [get_bd_ports PMOD0_3_LS]
  connect_bd_net -net qick_processor_0_trig_4_o [get_bd_pins qick_processor_0/trig_4_o] [get_bd_ports PMOD0_4_LS]
  connect_bd_net -net qick_processor_0_trig_5_o [get_bd_pins qick_processor_0/trig_5_o] [get_bd_ports PMOD0_5_LS]
  connect_bd_net -net qick_processor_0_trig_6_o [get_bd_pins qick_processor_0/trig_6_o] [get_bd_ports PMOD0_6_LS]
  connect_bd_net -net qick_processor_0_trig_7_o [get_bd_pins qick_processor_0/trig_7_o] [get_bd_ports PMOD0_7_LS]
  connect_bd_net -net qick_processor_0_trig_8_o [get_bd_pins qick_processor_0/trig_8_o] [get_bd_pins ddr4/trigger]
  connect_bd_net -net qick_processor_0_trig_9_o [get_bd_pins qick_processor_0/trig_9_o] [get_bd_pins mr_buffer_et_0/trigger]
  connect_bd_net -net rst_100_bus_struct_reset [get_bd_pins rst_100/bus_struct_reset] [get_bd_pins ddr4/sys_rst]
  connect_bd_net -net rst_adc_peripheral_aresetn [get_bd_pins rst_adc2/peripheral_aresetn] [get_bd_pins sg_translator_6/aresetn] [get_bd_pins axis_broadcaster_0/aresetn] [get_bd_pins axis_broadcaster_1/aresetn] [get_bd_pins axis_broadcaster_2/aresetn] [get_bd_pins axis_broadcaster_3/aresetn] [get_bd_pins axis_broadcaster_4/aresetn] [get_bd_pins axis_broadcaster_5/aresetn] [get_bd_pins axis_clock_converter_1/m_axis_aresetn] [get_bd_pins axis_clock_converter_3/s_axis_aresetn] [get_bd_pins axis_dyn_readout_v1_0/aresetn] [get_bd_pins axis_pfb_readout_v3_0/aresetn] [get_bd_pins axis_readout_v2_0/aresetn] [get_bd_pins axis_switch_ddr/aresetn] [get_bd_pins axis_switch_mr/aresetn] [get_bd_pins usp_rf_data_converter_0/m2_axis_aresetn] [get_bd_pins ddr4/aresetn] [get_bd_pins axis_avg_buffer_0/s_axis_aresetn] [get_bd_pins axis_avg_buffer_2/s_axis_aresetn] [get_bd_pins axis_avg_buffer_3/s_axis_aresetn] [get_bd_pins axis_avg_buffer_4/s_axis_aresetn] [get_bd_pins axis_avg_buffer_5/s_axis_aresetn] [get_bd_pins axis_avg_buffer_6/s_axis_aresetn] [get_bd_pins mr_buffer_et_0/s00_axis_aresetn]
  connect_bd_net -net rst_core_peripheral_aresetn [get_bd_pins rst_core/peripheral_aresetn] [get_bd_pins axis_clk_cnvrt_avg_0/m_axis_aresetn] [get_bd_pins axis_clk_cnvrt_avg_1/m_axis_aresetn] [get_bd_pins axis_clk_cnvrt_avg_2/m_axis_aresetn] [get_bd_pins axis_clk_cnvrt_avg_3/m_axis_aresetn] [get_bd_pins axis_clk_cnvrt_avg_4/m_axis_aresetn] [get_bd_pins axis_clk_cnvrt_avg_5/m_axis_aresetn] [get_bd_pins axis_clk_cnvrt_avg_6/m_axis_aresetn] [get_bd_pins qick_processor_0/c_resetn]
  connect_bd_net -net rst_dac2_peripheral_aresetn [get_bd_pins rst_dac2/peripheral_aresetn] [get_bd_pins axis_register_slice_0/aresetn] [get_bd_pins axis_register_slice_1/aresetn] [get_bd_pins axis_sg_mux8_v1_0/aresetn] [get_bd_pins sg_translator_0/aresetn] [get_bd_pins sg_translator_1/aresetn] [get_bd_pins axis_resampler_2x1_v1_0/aresetn] [get_bd_pins sg_translator_7/aresetn] [get_bd_pins axis_tmux_v1_0/aresetn] [get_bd_pins axis_signal_gen_v6_0/aresetn] [get_bd_pins axis_cdcsync_v1_1/s_axis_aresetn] [get_bd_pins axis_signal_gen_v6_1/aresetn] [get_bd_pins axis_register_slice_2/aresetn] [get_bd_pins sg_translator_2/aresetn] [get_bd_pins axis_clock_converter_1/s_axis_aresetn] [get_bd_pins axis_clock_converter_3/m_axis_aresetn] [get_bd_pins axis_readout_v3_0/aresetn] [get_bd_pins axis_register_slice_3/aresetn] [get_bd_pins axis_register_slice_4/aresetn] [get_bd_pins axis_register_slice_8/aresetn] [get_bd_pins axis_register_slice_6/aresetn] [get_bd_pins axis_register_slice_5/aresetn] [get_bd_pins axis_register_slice_10/aresetn] [get_bd_pins usp_rf_data_converter_0/s2_axis_aresetn] [get_bd_pins axis_avg_buffer_1/s_axis_aresetn] [get_bd_pins qick_processor_0/t_resetn]
  connect_bd_net -net rst_dac2_peripheral_reset [get_bd_pins rst_dac2/peripheral_reset] [get_bd_pins clk_core/reset]
  connect_bd_net -net rst_dac3_peripheral_aresetn [get_bd_pins rst_dac3/peripheral_aresetn] [get_bd_pins sg_translator_3/aresetn] [get_bd_pins sg_translator_4/aresetn] [get_bd_pins sg_translator_5/aresetn] [get_bd_pins axis_sg_mixmux8_v1_0/aresetn] [get_bd_pins axis_cdcsync_v1_1/m_axis_aresetn] [get_bd_pins axis_sg_int4_v2_0/aresetn] [get_bd_pins axis_sg_int4_v2_1/aresetn] [get_bd_pins usp_rf_data_converter_0/s3_axis_aresetn]
  connect_bd_net -net rst_ps8_0_99M_peripheral_aresetn [get_bd_pins rst_100/peripheral_aresetn] [get_bd_pins axi_intc_0/s_axi_aresetn] [get_bd_pins axis_sg_mux8_v1_0/s_axi_aresetn] [get_bd_pins axis_sg_mixmux8_v1_0/s_axi_aresetn] [get_bd_pins axis_signal_gen_v6_0/s_axi_aresetn] [get_bd_pins axis_signal_gen_v6_0/s0_axis_aresetn] [get_bd_pins axis_signal_gen_v6_1/s0_axis_aresetn] [get_bd_pins axis_signal_gen_v6_1/s_axi_aresetn] [get_bd_pins axi_dma_avg/axi_resetn] [get_bd_pins axi_dma_buf/axi_resetn] [get_bd_pins axi_dma_gen/axi_resetn] [get_bd_pins axi_dma_mr/axi_resetn] [get_bd_pins axi_dma_tproc/axi_resetn] [get_bd_pins axi_smc/aresetn] [get_bd_pins axis_clk_cnvrt_avg_0/s_axis_aresetn] [get_bd_pins axis_clk_cnvrt_avg_1/s_axis_aresetn] [get_bd_pins axis_clk_cnvrt_avg_2/s_axis_aresetn] [get_bd_pins axis_clk_cnvrt_avg_3/s_axis_aresetn] [get_bd_pins axis_clk_cnvrt_avg_4/s_axis_aresetn] [get_bd_pins axis_clk_cnvrt_avg_5/s_axis_aresetn] [get_bd_pins axis_clk_cnvrt_avg_6/s_axis_aresetn] [get_bd_pins axis_pfb_readout_v3_0/s_axi_aresetn] [get_bd_pins axis_readout_v2_0/s_axi_aresetn] [get_bd_pins axis_sg_int4_v2_0/s_axi_aresetn] [get_bd_pins axis_sg_int4_v2_0/s0_axis_aresetn] [get_bd_pins axis_sg_int4_v2_1/s_axi_aresetn] [get_bd_pins axis_sg_int4_v2_1/s0_axis_aresetn] [get_bd_pins axis_switch_avg/aresetn] [get_bd_pins axis_switch_avg/s_axi_ctrl_aresetn] [get_bd_pins axis_switch_buf/aresetn] [get_bd_pins axis_switch_buf/s_axi_ctrl_aresetn] [get_bd_pins axis_switch_ddr/s_axi_ctrl_aresetn] [get_bd_pins axis_switch_gen/aresetn] [get_bd_pins axis_switch_gen/s_axi_ctrl_aresetn] [get_bd_pins axis_switch_mr/s_axi_ctrl_aresetn] [get_bd_pins ps8_0_axi_periph/ARESETN] [get_bd_pins ps8_0_axi_periph/S00_ARESETN] [get_bd_pins ps8_0_axi_periph/M00_ARESETN] [get_bd_pins ps8_0_axi_periph/M01_ARESETN] [get_bd_pins ps8_0_axi_periph/M02_ARESETN] [get_bd_pins ps8_0_axi_periph/M03_ARESETN] [get_bd_pins ps8_0_axi_periph/M04_ARESETN] [get_bd_pins ps8_0_axi_periph/M05_ARESETN] [get_bd_pins ps8_0_axi_periph/M06_ARESETN] [get_bd_pins ps8_0_axi_periph/M07_ARESETN] [get_bd_pins ps8_0_axi_periph/M08_ARESETN] [get_bd_pins ps8_0_axi_periph/M09_ARESETN] [get_bd_pins ps8_0_axi_periph/M10_ARESETN] [get_bd_pins ps8_0_axi_periph/M11_ARESETN] [get_bd_pins ps8_0_axi_periph/M12_ARESETN] [get_bd_pins ps8_0_axi_periph/M13_ARESETN] [get_bd_pins ps8_0_axi_periph/M14_ARESETN] [get_bd_pins ps8_0_axi_periph/M15_ARESETN] [get_bd_pins ps8_0_axi_periph/M16_ARESETN] [get_bd_pins ps8_0_axi_periph/M17_ARESETN] [get_bd_pins ps8_0_axi_periph/M18_ARESETN] [get_bd_pins ps8_0_axi_periph/M19_ARESETN] [get_bd_pins ps8_0_axi_periph/M20_ARESETN] [get_bd_pins ps8_0_axi_periph/M21_ARESETN] [get_bd_pins ps8_0_axi_periph/M22_ARESETN] [get_bd_pins ps8_0_axi_periph/M23_ARESETN] [get_bd_pins ps8_0_axi_periph/M24_ARESETN] [get_bd_pins ps8_0_axi_periph/M25_ARESETN] [get_bd_pins ps8_0_axi_periph/M26_ARESETN] [get_bd_pins ps8_0_axi_periph/M27_ARESETN] [get_bd_pins ps8_0_axi_periph/M28_ARESETN] [get_bd_pins ps8_0_axi_periph/M29_ARESETN] [get_bd_pins usp_rf_data_converter_0/s_axi_aresetn] [get_bd_pins ddr4/s_axi_aresetn] [get_bd_pins clk104_gpio/s_axi_aresetn] [get_bd_pins ps8_0_axi_periph/M30_ARESETN] [get_bd_pins axis_avg_buffer_0/s_axi_aresetn] [get_bd_pins axis_avg_buffer_0/m_axis_aresetn] [get_bd_pins axis_avg_buffer_1/s_axi_aresetn] [get_bd_pins axis_avg_buffer_1/m_axis_aresetn] [get_bd_pins axis_avg_buffer_2/s_axi_aresetn] [get_bd_pins axis_avg_buffer_2/m_axis_aresetn] [get_bd_pins axis_avg_buffer_3/s_axi_aresetn] [get_bd_pins axis_avg_buffer_3/m_axis_aresetn] [get_bd_pins axis_avg_buffer_4/s_axi_aresetn] [get_bd_pins axis_avg_buffer_4/m_axis_aresetn] [get_bd_pins axis_avg_buffer_5/s_axi_aresetn] [get_bd_pins axis_avg_buffer_5/m_axis_aresetn] [get_bd_pins axis_avg_buffer_6/s_axi_aresetn] [get_bd_pins axis_avg_buffer_6/m_axis_aresetn] [get_bd_pins mr_buffer_et_0/s00_axi_aresetn] [get_bd_pins mr_buffer_et_0/m00_axis_aresetn] [get_bd_pins qick_processor_0/ps_resetn]
  connect_bd_net -net usp_rf_data_converter_0_clk_adc2 [get_bd_pins usp_rf_data_converter_0/clk_adc2] [get_bd_pins rst_adc2/slowest_sync_clk] [get_bd_pins sg_translator_6/aclk] [get_bd_pins axis_broadcaster_0/aclk] [get_bd_pins axis_broadcaster_1/aclk] [get_bd_pins axis_broadcaster_2/aclk] [get_bd_pins axis_broadcaster_3/aclk] [get_bd_pins axis_broadcaster_4/aclk] [get_bd_pins axis_broadcaster_5/aclk] [get_bd_pins axis_clock_converter_1/m_axis_aclk] [get_bd_pins axis_clock_converter_3/s_axis_aclk] [get_bd_pins axis_dyn_readout_v1_0/aclk] [get_bd_pins axis_pfb_readout_v3_0/aclk] [get_bd_pins axis_readout_v2_0/aclk] [get_bd_pins axis_switch_ddr/aclk] [get_bd_pins axis_switch_mr/aclk] [get_bd_pins usp_rf_data_converter_0/m2_axis_aclk] [get_bd_pins ddr4/aclk] [get_bd_pins axis_avg_buffer_0/s_axis_aclk] [get_bd_pins axis_avg_buffer_2/s_axis_aclk] [get_bd_pins axis_avg_buffer_3/s_axis_aclk] [get_bd_pins axis_avg_buffer_4/s_axis_aclk] [get_bd_pins axis_avg_buffer_5/s_axis_aclk] [get_bd_pins axis_avg_buffer_6/s_axis_aclk] [get_bd_pins mr_buffer_et_0/s00_axis_aclk]
  connect_bd_net -net usp_rf_data_converter_0_clk_dac2 [get_bd_pins usp_rf_data_converter_0/clk_dac2] [get_bd_pins axis_register_slice_0/aclk] [get_bd_pins axis_register_slice_1/aclk] [get_bd_pins axis_sg_mux8_v1_0/aclk] [get_bd_pins rst_dac2/slowest_sync_clk] [get_bd_pins sg_translator_0/aclk] [get_bd_pins sg_translator_1/aclk] [get_bd_pins axis_resampler_2x1_v1_0/aclk] [get_bd_pins sg_translator_7/aclk] [get_bd_pins axis_tmux_v1_0/aclk] [get_bd_pins axis_signal_gen_v6_0/aclk] [get_bd_pins axis_cdcsync_v1_1/s_axis_aclk] [get_bd_pins axis_signal_gen_v6_1/aclk] [get_bd_pins axis_register_slice_2/aclk] [get_bd_pins sg_translator_2/aclk] [get_bd_pins axis_clock_converter_1/s_axis_aclk] [get_bd_pins axis_clock_converter_3/m_axis_aclk] [get_bd_pins axis_readout_v3_0/aclk] [get_bd_pins axis_register_slice_3/aclk] [get_bd_pins axis_register_slice_4/aclk] [get_bd_pins axis_register_slice_8/aclk] [get_bd_pins axis_register_slice_6/aclk] [get_bd_pins axis_register_slice_5/aclk] [get_bd_pins axis_register_slice_10/aclk] [get_bd_pins usp_rf_data_converter_0/s2_axis_aclk] [get_bd_pins axis_avg_buffer_1/s_axis_aclk] [get_bd_pins qick_processor_0/t_clk_i] [get_bd_pins clk_core/clk_in1]
  connect_bd_net -net usp_rf_data_converter_0_clk_dac3 [get_bd_pins usp_rf_data_converter_0/clk_dac3] [get_bd_pins rst_dac3/slowest_sync_clk] [get_bd_pins sg_translator_3/aclk] [get_bd_pins sg_translator_4/aclk] [get_bd_pins sg_translator_5/aclk] [get_bd_pins axis_sg_mixmux8_v1_0/aclk] [get_bd_pins axis_cdcsync_v1_1/m_axis_aclk] [get_bd_pins axis_sg_int4_v2_0/aclk] [get_bd_pins axis_sg_int4_v2_1/aclk] [get_bd_pins usp_rf_data_converter_0/s3_axis_aclk]
  connect_bd_net -net usp_rf_data_converter_0_irq [get_bd_pins usp_rf_data_converter_0/irq] [get_bd_pins xlconcat_intc/In6]
  connect_bd_net -net xlconcat_1_dout [get_bd_pins xlconcat_intc/dout] [get_bd_pins axi_intc_0/intr]
  connect_bd_net -net zynq_ultra_ps_e_0_pl_clk0 [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] [get_bd_pins axi_intc_0/s_axi_aclk] [get_bd_pins axis_sg_mux8_v1_0/s_axi_aclk] [get_bd_pins rst_100/slowest_sync_clk] [get_bd_pins axis_sg_mixmux8_v1_0/s_axi_aclk] [get_bd_pins axis_signal_gen_v6_0/s_axi_aclk] [get_bd_pins axis_signal_gen_v6_0/s0_axis_aclk] [get_bd_pins axis_signal_gen_v6_1/s0_axis_aclk] [get_bd_pins axis_signal_gen_v6_1/s_axi_aclk] [get_bd_pins axi_dma_avg/s_axi_lite_aclk] [get_bd_pins axi_dma_avg/m_axi_s2mm_aclk] [get_bd_pins axi_dma_buf/s_axi_lite_aclk] [get_bd_pins axi_dma_buf/m_axi_s2mm_aclk] [get_bd_pins axi_dma_gen/s_axi_lite_aclk] [get_bd_pins axi_dma_gen/m_axi_mm2s_aclk] [get_bd_pins axi_dma_mr/s_axi_lite_aclk] [get_bd_pins axi_dma_mr/m_axi_s2mm_aclk] [get_bd_pins axi_dma_tproc/s_axi_lite_aclk] [get_bd_pins axi_dma_tproc/m_axi_mm2s_aclk] [get_bd_pins axi_dma_tproc/m_axi_s2mm_aclk] [get_bd_pins axi_smc/aclk] [get_bd_pins axis_clk_cnvrt_avg_0/s_axis_aclk] [get_bd_pins axis_clk_cnvrt_avg_1/s_axis_aclk] [get_bd_pins axis_clk_cnvrt_avg_2/s_axis_aclk] [get_bd_pins axis_clk_cnvrt_avg_3/s_axis_aclk] [get_bd_pins axis_clk_cnvrt_avg_4/s_axis_aclk] [get_bd_pins axis_clk_cnvrt_avg_5/s_axis_aclk] [get_bd_pins axis_clk_cnvrt_avg_6/s_axis_aclk] [get_bd_pins axis_pfb_readout_v3_0/s_axi_aclk] [get_bd_pins axis_readout_v2_0/s_axi_aclk] [get_bd_pins axis_sg_int4_v2_0/s_axi_aclk] [get_bd_pins axis_sg_int4_v2_0/s0_axis_aclk] [get_bd_pins axis_sg_int4_v2_1/s_axi_aclk] [get_bd_pins axis_sg_int4_v2_1/s0_axis_aclk] [get_bd_pins axis_switch_avg/aclk] [get_bd_pins axis_switch_avg/s_axi_ctrl_aclk] [get_bd_pins axis_switch_buf/aclk] [get_bd_pins axis_switch_buf/s_axi_ctrl_aclk] [get_bd_pins axis_switch_ddr/s_axi_ctrl_aclk] [get_bd_pins axis_switch_gen/aclk] [get_bd_pins axis_switch_gen/s_axi_ctrl_aclk] [get_bd_pins axis_switch_mr/s_axi_ctrl_aclk] [get_bd_pins ps8_0_axi_periph/ACLK] [get_bd_pins ps8_0_axi_periph/S00_ACLK] [get_bd_pins ps8_0_axi_periph/M00_ACLK] [get_bd_pins ps8_0_axi_periph/M01_ACLK] [get_bd_pins ps8_0_axi_periph/M02_ACLK] [get_bd_pins ps8_0_axi_periph/M03_ACLK] [get_bd_pins ps8_0_axi_periph/M04_ACLK] [get_bd_pins ps8_0_axi_periph/M05_ACLK] [get_bd_pins ps8_0_axi_periph/M06_ACLK] [get_bd_pins ps8_0_axi_periph/M07_ACLK] [get_bd_pins ps8_0_axi_periph/M08_ACLK] [get_bd_pins ps8_0_axi_periph/M09_ACLK] [get_bd_pins ps8_0_axi_periph/M10_ACLK] [get_bd_pins ps8_0_axi_periph/M11_ACLK] [get_bd_pins ps8_0_axi_periph/M12_ACLK] [get_bd_pins ps8_0_axi_periph/M13_ACLK] [get_bd_pins ps8_0_axi_periph/M14_ACLK] [get_bd_pins ps8_0_axi_periph/M15_ACLK] [get_bd_pins ps8_0_axi_periph/M16_ACLK] [get_bd_pins ps8_0_axi_periph/M17_ACLK] [get_bd_pins ps8_0_axi_periph/M18_ACLK] [get_bd_pins ps8_0_axi_periph/M19_ACLK] [get_bd_pins ps8_0_axi_periph/M20_ACLK] [get_bd_pins ps8_0_axi_periph/M21_ACLK] [get_bd_pins ps8_0_axi_periph/M22_ACLK] [get_bd_pins ps8_0_axi_periph/M23_ACLK] [get_bd_pins ps8_0_axi_periph/M24_ACLK] [get_bd_pins ps8_0_axi_periph/M25_ACLK] [get_bd_pins ps8_0_axi_periph/M26_ACLK] [get_bd_pins ps8_0_axi_periph/M27_ACLK] [get_bd_pins ps8_0_axi_periph/M28_ACLK] [get_bd_pins ps8_0_axi_periph/M29_ACLK] [get_bd_pins usp_rf_data_converter_0/s_axi_aclk] [get_bd_pins zynq_ultra_ps_e_0/maxihpm0_fpd_aclk] [get_bd_pins zynq_ultra_ps_e_0/saxihpc0_fpd_aclk] [get_bd_pins ddr4/s_axi_aclk] [get_bd_pins clk104_gpio/s_axi_aclk] [get_bd_pins ps8_0_axi_periph/M30_ACLK] [get_bd_pins axis_avg_buffer_0/s_axi_aclk] [get_bd_pins axis_avg_buffer_0/m_axis_aclk] [get_bd_pins axis_avg_buffer_1/s_axi_aclk] [get_bd_pins axis_avg_buffer_1/m_axis_aclk] [get_bd_pins axis_avg_buffer_2/s_axi_aclk] [get_bd_pins axis_avg_buffer_2/m_axis_aclk] [get_bd_pins axis_avg_buffer_3/s_axi_aclk] [get_bd_pins axis_avg_buffer_3/m_axis_aclk] [get_bd_pins axis_avg_buffer_4/s_axi_aclk] [get_bd_pins axis_avg_buffer_4/m_axis_aclk] [get_bd_pins axis_avg_buffer_5/s_axi_aclk] [get_bd_pins axis_avg_buffer_5/m_axis_aclk] [get_bd_pins axis_avg_buffer_6/s_axi_aclk] [get_bd_pins axis_avg_buffer_6/m_axis_aclk] [get_bd_pins mr_buffer_et_0/s00_axi_aclk] [get_bd_pins mr_buffer_et_0/m00_axis_aclk] [get_bd_pins qick_processor_0/ps_clk_i]
  connect_bd_net -net zynq_ultra_ps_e_0_pl_resetn0 [get_bd_pins zynq_ultra_ps_e_0/pl_resetn0] [get_bd_pins rst_100/ext_reset_in] [get_bd_pins rst_adc2/ext_reset_in] [get_bd_pins rst_dac2/ext_reset_in] [get_bd_pins rst_dac3/ext_reset_in] [get_bd_pins rst_core/ext_reset_in]

  # Create address segments
  assign_bd_address -offset 0x00000000 -range 0x80000000 -target_address_space [get_bd_addr_spaces axi_dma_avg/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_DDR_LOW] -force
  assign_bd_address -offset 0xC0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_dma_avg/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_QSPI] -force
  assign_bd_address -offset 0x00000000 -range 0x80000000 -target_address_space [get_bd_addr_spaces axi_dma_buf/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_DDR_LOW] -force
  assign_bd_address -offset 0xC0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_dma_buf/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_QSPI] -force
  assign_bd_address -offset 0x00000000 -range 0x80000000 -target_address_space [get_bd_addr_spaces axi_dma_gen/Data_MM2S] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_DDR_LOW] -force
  assign_bd_address -offset 0xC0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_dma_gen/Data_MM2S] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_QSPI] -force
  assign_bd_address -offset 0x00000000 -range 0x80000000 -target_address_space [get_bd_addr_spaces axi_dma_mr/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_DDR_LOW] -force
  assign_bd_address -offset 0xC0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_dma_mr/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_QSPI] -force
  assign_bd_address -offset 0x00000000 -range 0x80000000 -target_address_space [get_bd_addr_spaces axi_dma_tproc/Data_MM2S] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_DDR_LOW] -force
  assign_bd_address -offset 0xC0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_dma_tproc/Data_MM2S] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_QSPI] -force
  assign_bd_address -offset 0x00000000 -range 0x80000000 -target_address_space [get_bd_addr_spaces axi_dma_tproc/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_DDR_LOW] -force
  assign_bd_address -offset 0xC0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_dma_tproc/Data_S2MM] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP0/HPC0_QSPI] -force
  assign_bd_address -offset 0x000400010000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axi_dma_avg/S_AXI_LITE/Reg] -force
  assign_bd_address -offset 0x000400020000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axi_dma_buf/S_AXI_LITE/Reg] -force
  assign_bd_address -offset 0x000400030000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axi_dma_gen/S_AXI_LITE/Reg] -force
  assign_bd_address -offset 0x000400040000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axi_dma_mr/S_AXI_LITE/Reg] -force
  assign_bd_address -offset 0x000400050000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axi_dma_tproc/S_AXI_LITE/Reg] -force
  assign_bd_address -offset 0x000400060000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axi_intc_0/S_AXI/Reg] -force
  assign_bd_address -offset 0x000400070000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_avg_buffer_0/s_axi/reg0] -force
  assign_bd_address -offset 0x000400080000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_avg_buffer_1/s_axi/reg0] -force
  assign_bd_address -offset 0x000400090000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_avg_buffer_2/s_axi/reg0] -force
  assign_bd_address -offset 0x0004000A0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_avg_buffer_3/s_axi/reg0] -force
  assign_bd_address -offset 0x0004000B0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_avg_buffer_4/s_axi/reg0] -force
  assign_bd_address -offset 0x0004000C0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_avg_buffer_5/s_axi/reg0] -force
  assign_bd_address -offset 0x0004001D0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_avg_buffer_6/s_axi/reg0] -force
  assign_bd_address -offset 0x000400000000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs ddr4/axis_buffer_ddr_v1_0/s_axi/reg0] -force
  assign_bd_address -offset 0x000400001000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_pfb_readout_v3_0/s_axi/reg0] -force
  assign_bd_address -offset 0x0004000D0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_readout_v2_0/s_axi/reg0] -force
  assign_bd_address -offset 0x0004000E0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_sg_int4_v2_0/s_axi/reg0] -force
  assign_bd_address -offset 0x0004000F0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_sg_int4_v2_1/s_axi/reg0] -force
  assign_bd_address -offset 0x000400003000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_sg_mixmux8_v1_0/s_axi/reg0] -force
  assign_bd_address -offset 0x000400002000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_sg_mux8_v1_0/s_axi/reg0] -force
  assign_bd_address -offset 0x000400110000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_signal_gen_v6_0/s_axi/reg0] -force
  assign_bd_address -offset 0x000400100000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_signal_gen_v6_1/s_axi/reg0] -force
  assign_bd_address -offset 0x000400120000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_switch_avg/S_AXI_CTRL/Reg] -force
  assign_bd_address -offset 0x000400130000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_switch_buf/S_AXI_CTRL/Reg] -force
  assign_bd_address -offset 0x000400140000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_switch_ddr/S_AXI_CTRL/Reg] -force
  assign_bd_address -offset 0x000400150000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_switch_gen/S_AXI_CTRL/Reg] -force
  assign_bd_address -offset 0x0004001C0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_switch_mr/S_AXI_CTRL/Reg] -force
  assign_bd_address -offset 0x0004001E0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs clk104_gpio/S_AXI/Reg] -force
  assign_bd_address -offset 0x000500000000 -range 0x000100000000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs ddr4/ddr4_0/C0_DDR4_MEMORY_MAP/C0_DDR4_ADDRESS_BLOCK] -force
  assign_bd_address -offset 0x000400160000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs mr_buffer_et_0/s00_axi/reg0] -force
  assign_bd_address -offset 0x000400170000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs qick_processor_0/s_axi/reg0] -force
  assign_bd_address -offset 0x000400180000 -range 0x00040000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs usp_rf_data_converter_0/s_axi/Reg] -force
  assign_bd_address -offset 0x00000000 -range 0x000100000000 -target_address_space [get_bd_addr_spaces ddr4/axis_buffer_ddr_v1_0/m_axi] [get_bd_addr_segs ddr4/ddr4_0/C0_DDR4_MEMORY_MAP/C0_DDR4_ADDRESS_BLOCK] -force

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
   "Default View_ScaleFactor":"0.324681",
   "Default View_TopLeft":"-2319,-440",
   "ExpandedHierarchyInLayout":"",
   "guistr":"# # String gsaved with Nlview 7.5.8 2022-09-21 7111 VDI=41 GEI=38 GUI=JA:10.0 TLS
#  -string -flagsOSRD
preplace port adc2_clk_0 -pg 1 -lvl 7 -x 4800 -y 2270 -defaultsOSRD -right
preplace port dac2_clk_0 -pg 1 -lvl 7 -x 4800 -y 2290 -defaultsOSRD -right
preplace port ddr4_sdram_c0 -pg 1 -lvl 7 -x 4800 -y 3720 -defaultsOSRD
preplace port default_sysclk_c0_300mhz -pg 1 -lvl 7 -x 4800 -y 3650 -defaultsOSRD -right
preplace port sysref_in_0 -pg 1 -lvl 7 -x 4800 -y 2390 -defaultsOSRD -right
preplace port vin20_0 -pg 1 -lvl 7 -x 4800 -y 2310 -defaultsOSRD -right
preplace port vin21_0 -pg 1 -lvl 7 -x 4800 -y 2330 -defaultsOSRD -right
preplace port vin22_0 -pg 1 -lvl 7 -x 4800 -y 2350 -defaultsOSRD -right
preplace port vout0 -pg 1 -lvl 7 -x 4800 -y 1870 -defaultsOSRD
preplace port vout1 -pg 1 -lvl 7 -x 4800 -y 1890 -defaultsOSRD
preplace port vout2 -pg 1 -lvl 7 -x 4800 -y 1910 -defaultsOSRD
preplace port vout3 -pg 1 -lvl 7 -x 4800 -y 1930 -defaultsOSRD
preplace port vout4 -pg 1 -lvl 7 -x 4800 -y 1950 -defaultsOSRD
preplace port vin23_0 -pg 1 -lvl 7 -x 4800 -y 2370 -defaultsOSRD -right
preplace port vout5 -pg 1 -lvl 7 -x 4800 -y 1970 -defaultsOSRD
preplace port port-id_PMOD0_0_LS -pg 1 -lvl 7 -x 4800 -y 1040 -defaultsOSRD
preplace port port-id_PMOD0_1_LS -pg 1 -lvl 7 -x 4800 -y 1060 -defaultsOSRD
preplace port port-id_PMOD0_2_LS -pg 1 -lvl 7 -x 4800 -y 1080 -defaultsOSRD
preplace port port-id_PMOD0_3_LS -pg 1 -lvl 7 -x 4800 -y 1100 -defaultsOSRD
preplace port port-id_PMOD0_4_LS -pg 1 -lvl 7 -x 4800 -y 1120 -defaultsOSRD
preplace port port-id_PMOD0_5_LS -pg 1 -lvl 7 -x 4800 -y 1140 -defaultsOSRD
preplace port port-id_PMOD0_6_LS -pg 1 -lvl 7 -x 4800 -y 1160 -defaultsOSRD
preplace port port-id_PMOD0_7_LS -pg 1 -lvl 7 -x 4800 -y 1180 -defaultsOSRD
preplace port port-id_PMOD1_0_LS -pg 1 -lvl 0 -x -10 -y 1500 -defaultsOSRD
preplace portBus CLK104_CLK_SPI_MUX_SEL_LS -pg 1 -lvl 7 -x 4800 -y 60 -defaultsOSRD
preplace inst axi_intc_0 -pg 1 -lvl 2 -x 1250 -y 200 -defaultsOSRD
preplace inst axis_register_slice_0 -pg 1 -lvl 5 -x 3870 -y 1280 -defaultsOSRD
preplace inst axis_register_slice_1 -pg 1 -lvl 5 -x 3870 -y 1620 -defaultsOSRD
preplace inst axis_resampler_2x1_v1_0 -pg 1 -lvl 1 -x 490 -y 2660 -defaultsOSRD
preplace inst axis_sg_mux8_v1_0 -pg 1 -lvl 5 -x 3870 -y 1450 -defaultsOSRD
preplace inst rst_100 -pg 1 -lvl 3 -x 2050 -y 260 -defaultsOSRD
preplace inst rst_adc2 -pg 1 -lvl 3 -x 2050 -y 440 -defaultsOSRD
preplace inst rst_core -pg 1 -lvl 3 -x 2050 -y 1180 -defaultsOSRD
preplace inst rst_dac2 -pg 1 -lvl 3 -x 2050 -y 620 -defaultsOSRD
preplace inst rst_dac3 -pg 1 -lvl 3 -x 2050 -y 820 -defaultsOSRD
preplace inst sg_translator_0 -pg 1 -lvl 3 -x 2050 -y 1360 -defaultsOSRD
preplace inst sg_translator_1 -pg 1 -lvl 3 -x 2050 -y 1530 -defaultsOSRD
preplace inst sg_translator_3 -pg 1 -lvl 4 -x 3090 -y 2660 -defaultsOSRD
preplace inst sg_translator_4 -pg 1 -lvl 4 -x 3090 -y 2800 -defaultsOSRD
preplace inst sg_translator_5 -pg 1 -lvl 4 -x 3090 -y 2940 -defaultsOSRD
preplace inst sg_translator_6 -pg 1 -lvl 3 -x 2050 -y 1810 -defaultsOSRD
preplace inst sg_translator_7 -pg 1 -lvl 3 -x 2050 -y 1980 -defaultsOSRD
preplace inst xlconcat_intc -pg 1 -lvl 2 -x 1250 -y 10 -defaultsOSRD
preplace inst axis_tmux_v1_0 -pg 1 -lvl 1 -x 490 -y 1860 -defaultsOSRD
preplace inst axis_sg_mixmux8_v1_0 -pg 1 -lvl 5 -x 3870 -y 2870 -defaultsOSRD
preplace inst axis_signal_gen_v6_0 -pg 1 -lvl 5 -x 3870 -y 1080 -defaultsOSRD
preplace inst axis_cdcsync_v1_1 -pg 1 -lvl 2 -x 1250 -y 1500 -defaultsOSRD
preplace inst axis_signal_gen_v6_1 -pg 1 -lvl 5 -x 3870 -y 1980 -defaultsOSRD
preplace inst axis_register_slice_2 -pg 1 -lvl 5 -x 3870 -y 2180 -defaultsOSRD
preplace inst sg_translator_2 -pg 1 -lvl 3 -x 2050 -y 1670 -defaultsOSRD
preplace inst axi_dma_avg -pg 1 -lvl 1 -x 490 -y 330 -defaultsOSRD
preplace inst axi_dma_buf -pg 1 -lvl 1 -x 490 -y 510 -defaultsOSRD
preplace inst axi_dma_gen -pg 1 -lvl 1 -x 490 -y 910 -defaultsOSRD
preplace inst axi_dma_mr -pg 1 -lvl 1 -x 490 -y 690 -defaultsOSRD
preplace inst axi_dma_tproc -pg 1 -lvl 1 -x 490 -y 1100 -defaultsOSRD
preplace inst axi_smc -pg 1 -lvl 2 -x 1250 -y 400 -defaultsOSRD
preplace inst axis_broadcaster_0 -pg 1 -lvl 1 -x 490 -y 2340 -defaultsOSRD
preplace inst axis_broadcaster_1 -pg 1 -lvl 1 -x 490 -y 4130 -defaultsOSRD
preplace inst axis_broadcaster_2 -pg 1 -lvl 1 -x 490 -y 3330 -defaultsOSRD
preplace inst axis_broadcaster_3 -pg 1 -lvl 1 -x 490 -y 3470 -defaultsOSRD
preplace inst axis_broadcaster_4 -pg 1 -lvl 1 -x 490 -y 3610 -defaultsOSRD
preplace inst axis_broadcaster_5 -pg 1 -lvl 1 -x 490 -y 3750 -defaultsOSRD
preplace inst axis_clk_cnvrt_avg_0 -pg 1 -lvl 3 -x 2050 -y 2460 -defaultsOSRD
preplace inst axis_clk_cnvrt_avg_1 -pg 1 -lvl 3 -x 2050 -y 2640 -defaultsOSRD
preplace inst axis_clk_cnvrt_avg_2 -pg 1 -lvl 3 -x 2050 -y 2820 -defaultsOSRD
preplace inst axis_clk_cnvrt_avg_3 -pg 1 -lvl 3 -x 2050 -y 3000 -defaultsOSRD
preplace inst axis_clk_cnvrt_avg_4 -pg 1 -lvl 3 -x 2050 -y 3180 -defaultsOSRD
preplace inst axis_clk_cnvrt_avg_5 -pg 1 -lvl 3 -x 2050 -y 3380 -defaultsOSRD
preplace inst axis_clk_cnvrt_avg_6 -pg 1 -lvl 3 -x 2050 -y 3650 -defaultsOSRD
preplace inst axis_clock_converter_1 -pg 1 -lvl 2 -x 1250 -y 1700 -defaultsOSRD
preplace inst axis_clock_converter_3 -pg 1 -lvl 1 -x 490 -y 2500 -defaultsOSRD
preplace inst axis_dyn_readout_v1_0 -pg 1 -lvl 1 -x 490 -y 2130 -defaultsOSRD
preplace inst axis_pfb_readout_v3_0 -pg 1 -lvl 1 -x 490 -y 3160 -defaultsOSRD
preplace inst axis_readout_v2_0 -pg 1 -lvl 1 -x 490 -y 3940 -defaultsOSRD
preplace inst axis_readout_v3_0 -pg 1 -lvl 1 -x 490 -y 2960 -defaultsOSRD
preplace inst axis_register_slice_3 -pg 1 -lvl 4 -x 3090 -y 1540 -defaultsOSRD
preplace inst axis_register_slice_4 -pg 1 -lvl 4 -x 3090 -y 1920 -defaultsOSRD
preplace inst axis_register_slice_8 -pg 1 -lvl 4 -x 3090 -y 2070 -defaultsOSRD
preplace inst axis_register_slice_6 -pg 1 -lvl 1 -x 490 -y 2800 -defaultsOSRD
preplace inst axis_register_slice_5 -pg 1 -lvl 4 -x 3090 -y 2210 -defaultsOSRD
preplace inst axis_register_slice_10 -pg 1 -lvl 3 -x 2050 -y 2120 -defaultsOSRD
preplace inst axis_sg_int4_v2_0 -pg 1 -lvl 5 -x 3870 -y 2380 -defaultsOSRD
preplace inst axis_sg_int4_v2_1 -pg 1 -lvl 5 -x 3870 -y 2640 -defaultsOSRD
preplace inst axis_switch_avg -pg 1 -lvl 4 -x 3090 -y 3200 -defaultsOSRD
preplace inst axis_switch_buf -pg 1 -lvl 4 -x 3090 -y 3520 -defaultsOSRD
preplace inst axis_switch_ddr -pg 1 -lvl 3 -x 2050 -y 4180 -defaultsOSRD
preplace inst axis_switch_gen -pg 1 -lvl 2 -x 1250 -y 960 -defaultsOSRD
preplace inst axis_switch_mr -pg 1 -lvl 3 -x 2050 -y 3900 -defaultsOSRD
preplace inst clk_core -pg 1 -lvl 2 -x 1250 -y 760 -defaultsOSRD
preplace inst ps8_0_axi_periph -pg 1 -lvl 4 -x 3090 -y 620 -defaultsOSRD
preplace inst usp_rf_data_converter_0 -pg 1 -lvl 6 -x 4470 -y 1920 -defaultsOSRD
preplace inst zynq_ultra_ps_e_0 -pg 1 -lvl 3 -x 2050 -y 80 -defaultsOSRD
preplace inst ddr4 -pg 1 -lvl 6 -x 4470 -y 3620 -defaultsOSRD
preplace inst clk104_gpio -pg 1 -lvl 5 -x 3870 -y 120 -defaultsOSRD
preplace inst axis_avg_buffer_0 -pg 1 -lvl 2 -x 1250 -y 2150 -defaultsOSRD
preplace inst axis_avg_buffer_1 -pg 1 -lvl 2 -x 1250 -y 2410 -defaultsOSRD
preplace inst axis_avg_buffer_2 -pg 1 -lvl 2 -x 1250 -y 2720 -defaultsOSRD
preplace inst axis_avg_buffer_3 -pg 1 -lvl 2 -x 1250 -y 3000 -defaultsOSRD
preplace inst axis_avg_buffer_4 -pg 1 -lvl 2 -x 1250 -y 3260 -defaultsOSRD
preplace inst axis_avg_buffer_5 -pg 1 -lvl 2 -x 1250 -y 3520 -defaultsOSRD
preplace inst axis_avg_buffer_6 -pg 1 -lvl 2 -x 1250 -y 3840 -defaultsOSRD
preplace inst mr_buffer_et_0 -pg 1 -lvl 4 -x 3090 -y 3810 -defaultsOSRD
preplace inst qick_processor_0 -pg 1 -lvl 1 -x 490 -y 1500 -defaultsOSRD
preplace netloc PMOD1_0_LS_1 1 0 1 50 1500n
preplace netloc axi_dma_avg_s2mm_introut 1 1 1 680 -50n
preplace netloc axi_dma_buf_s2mm_introut 1 1 1 700 -30n
preplace netloc axi_dma_gen_mm2s_introut 1 1 1 720 10n
preplace netloc axi_dma_mr_s2mm_introut 1 1 1 710 -10n
preplace netloc axi_dma_tproc_mm2s_introut 1 1 1 740 30n
preplace netloc axi_dma_tproc_s2mm_introut 1 1 1 750 50n
preplace netloc axi_intc_0_irq 1 2 1 1500 120n
preplace netloc clk104_gpio_gpio_io_o 1 5 2 NJ 130 4780
preplace netloc clk_core_clk_out1 1 0 3 220 790 960 830 1510
preplace netloc clk_core_locked 1 2 1 1630 770n
preplace netloc ddr4_0_c0_ddr4_ui_clk 1 2 5 1730 2270 2760 2290 3490 3030 4100 3470 4660J
preplace netloc qick_processor_0_trig_0_o 1 1 6 850 1300 1460J 1010 2900J 1380 3490J 840 NJ 840 4780J
preplace netloc qick_processor_0_trig_10_o 1 1 1 910 1590n
preplace netloc qick_processor_0_trig_11_o 1 1 1 870 1610n
preplace netloc qick_processor_0_trig_12_o 1 1 1 860 1630n
preplace netloc qick_processor_0_trig_13_o 1 1 1 840 1650n
preplace netloc qick_processor_0_trig_14_o 1 1 1 830 1670n
preplace netloc qick_processor_0_trig_15_o 1 1 1 810 1690n
preplace netloc qick_processor_0_trig_16_o 1 1 1 790 1710n
preplace netloc qick_processor_0_trig_1_o 1 1 6 770 1090 1400J 1020 2550J 1370 3500J 860 NJ 860 4770J
preplace netloc qick_processor_0_trig_2_o 1 1 6 810 1100 1410J 1030 2890J 1400 3520J 870 NJ 870 4760J
preplace netloc qick_processor_0_trig_3_o 1 1 6 830 1110 1390J 1000 2560J 1440 3580J 880 NJ 880 4750J
preplace netloc qick_processor_0_trig_4_o 1 1 6 860 1120 1450J 1040 2570J 1390 3530J 890 NJ 890 4730J
preplace netloc qick_processor_0_trig_5_o 1 1 6 800 850 1570J 940 2590J 1430 3590J 910 NJ 910 4710J
preplace netloc qick_processor_0_trig_6_o 1 1 6 820 1080 1430J 1050 2850J 1410 3570J 900 NJ 900 4720J
preplace netloc qick_processor_0_trig_7_o 1 1 6 870 1130 1490J 1080 2420J 1420 3510J 850 NJ 850 4740J
preplace netloc qick_processor_0_trig_8_o 1 1 5 840J 1070 NJ 1070 2810J 1710 NJ 1710 4090
preplace netloc qick_processor_0_trig_9_o 1 1 3 910J 1140 1470J 1060 2740
preplace netloc rst_100_bus_struct_reset 1 3 3 2550J -350 NJ -350 4110J
preplace netloc rst_adc_peripheral_aresetn 1 0 6 220 2020 980 1810 1570 960 2580 3030 3470J 3040 4210
preplace netloc rst_core_peripheral_aresetn 1 0 4 290 2010 NJ 2010 1470J 2220 2430
preplace netloc rst_dac2_peripheral_aresetn 1 0 6 230 1970 990 1840 1690J 720 2530 1630 3720 2980 4140
preplace netloc rst_dac3_peripheral_aresetn 1 1 5 1110 1150 1440 980 2830J 2460 3640 2990 4190
preplace netloc rst_ps8_0_99M_peripheral_aresetn 1 0 6 170 1980 900 4000 1660 3490 2620 -130 3600 3010 4160
preplace netloc usp_rf_data_converter_0_clk_adc2 1 0 7 200 4210 960 1830 1540 3780 2410 3950 N 3950 4170 2210 4680
preplace netloc usp_rf_data_converter_0_clk_dac2 1 0 7 210 2000 970 1160 1680 2210 2820 1640 3690 3000 4180 2200 4670
preplace netloc usp_rf_data_converter_0_clk_dac3 1 1 6 1080 1800 1670 2260 2750 3020 3700 3020 4200 2190 4660
preplace netloc usp_rf_data_converter_0_irq 1 1 6 1100 -150 1500J -140 2470J -390 NJ -390 NJ -390 4700
preplace netloc xlconcat_1_dout 1 1 2 1110 -140 1390
preplace netloc zynq_ultra_ps_e_0_pl_clk0 1 0 6 30 230 920 530 1520 2250 2840 1650 3660 1830 4070
preplace netloc zynq_ultra_ps_e_0_pl_resetn0 1 2 2 1740 -20 2420
preplace netloc rst_dac2_peripheral_reset 1 1 3 1080 -110 1670J -100 2430
preplace netloc adc2_clk_0_1 1 5 2 4280 2270 N
preplace netloc axi_dma_0_M_AXIS_MM2S1 1 1 1 930 900n
preplace netloc axi_dma_0_M_AXI_MM2S 1 1 1 760 330n
preplace netloc axi_dma_0_M_AXI_MM2S1 1 1 1 770 370n
preplace netloc axi_dma_0_M_AXI_S2MM 1 1 1 790 350n
preplace netloc axi_dma_avg_M_AXI_S2MM 1 1 1 970 310n
preplace netloc axi_dma_buf_M_AXI_S2MM 1 1 1 730 410n
preplace netloc axi_dma_mr_M_AXI_S2MM 1 1 1 780 430n
preplace netloc axi_dma_tproc_M_AXIS_MM2S 1 0 2 310 1950 700
preplace netloc axi_interconnect_0_M00_AXI 1 0 5 40 -430 NJ -430 N -430 NJ -430 3260
preplace netloc axi_interconnect_0_M08_AXI 1 4 2 N 480 4220
preplace netloc axis_avg_buffer_0_m0_axis 1 2 2 1500 2230 2420
preplace netloc axis_avg_buffer_0_m1_axis 1 2 2 1490 2240 2730
preplace netloc axis_avg_buffer_0_m2_axis 1 2 1 1480 2170n
preplace netloc axis_avg_buffer_1_m0_axis 1 2 2 1550 2310 2720
preplace netloc axis_avg_buffer_1_m1_axis 1 2 2 1560 2320 2660
preplace netloc axis_avg_buffer_1_m2_axis 1 2 1 1450 2430n
preplace netloc axis_avg_buffer_2_m0_axis 1 2 2 1580 2330 2690
preplace netloc axis_avg_buffer_2_m1_axis 1 2 2 1610 2340 2650
preplace netloc axis_avg_buffer_2_m2_axis 1 2 1 1450 2740n
preplace netloc axis_avg_buffer_3_m0_axis 1 2 2 1620 2350 2670
preplace netloc axis_avg_buffer_3_m1_axis 1 2 2 1390 2360 2640
preplace netloc axis_avg_buffer_3_m2_axis 1 2 1 1400 2960n
preplace netloc axis_avg_buffer_4_m0_axis 1 2 2 1590 2290 2700
preplace netloc axis_avg_buffer_4_m1_axis 1 2 2 1450 3280 2630
preplace netloc axis_avg_buffer_4_m2_axis 1 2 1 1390 3140n
preplace netloc axis_avg_buffer_5_m0_axis 1 2 2 1600 2280 2710
preplace netloc axis_avg_buffer_5_m1_axis 1 2 2 1650 3510 N
preplace netloc axis_avg_buffer_5_m2_axis 1 2 1 1640 3340n
preplace netloc axis_avg_buffer_6_m0_axis 1 2 2 1630 2300 2680
preplace netloc axis_avg_buffer_6_m1_axis 1 2 2 1670 3530 N
preplace netloc axis_avg_buffer_6_m2_axis 1 2 1 1680 3610n
preplace netloc axis_broadcaster_0_M00_AXIS 1 1 1 680 2070n
preplace netloc axis_broadcaster_0_M01_AXIS 1 1 2 820 2550 1440
preplace netloc axis_broadcaster_1_M00_AXIS 1 1 1 1030 3760n
preplace netloc axis_broadcaster_1_M01_AXIS 1 1 2 N 4140 1390
preplace netloc axis_broadcaster_2_M00_AXIS 1 1 1 800 2640n
preplace netloc axis_broadcaster_2_M01_AXIS 1 1 2 760 3680 1420
preplace netloc axis_broadcaster_3_M00_AXIS 1 1 1 970 2920n
preplace netloc axis_broadcaster_3_M01_AXIS 1 1 2 770 3660 1430
preplace netloc axis_broadcaster_4_M00_AXIS 1 1 1 690 3180n
preplace netloc axis_broadcaster_4_M01_AXIS 1 1 2 750 3670 1410
preplace netloc axis_broadcaster_5_M00_AXIS 1 1 1 990 3440n
preplace netloc axis_broadcaster_5_M01_AXIS 1 1 2 1010 3700 1400
preplace netloc axis_cdcsync_v1_1_m0_axis 1 2 2 1390 1440 2460
preplace netloc axis_cdcsync_v1_1_m1_axis 1 2 2 1400 1450 2780
preplace netloc axis_cdcsync_v1_1_m2_axis 1 2 2 1560 1890 2770
preplace netloc axis_clk_cnvrt_avg_0_M_AXIS 1 0 4 50 -420 N -420 N -420 2360
preplace netloc axis_clk_cnvrt_avg_1_M_AXIS 1 0 4 60 -410 N -410 N -410 2370
preplace netloc axis_clk_cnvrt_avg_2_M_AXIS 1 0 4 80 -400 N -400 N -400 2380
preplace netloc axis_clk_cnvrt_avg_3_M_AXIS 1 0 4 110 -390 N -390 N -390 2390
preplace netloc axis_clk_cnvrt_avg_4_M_AXIS 1 0 4 130 -380 N -380 N -380 2400
preplace netloc axis_clk_cnvrt_avg_5_M_AXIS 1 0 4 140 -370 N -370 N -370 2410
preplace netloc axis_clk_cnvrt_avg_6_M_AXIS 1 0 4 150 -360 N -360 N -360 2450
preplace netloc axis_clock_converter_1_M_AXIS1 1 2 1 1550 1700n
preplace netloc axis_clock_converter_2_M_AXIS 1 0 2 260 2220 720
preplace netloc axis_dyn_readout_v1_0_m0_axis 1 1 2 740 3990 1690
preplace netloc axis_dyn_readout_v1_0_m1_axis 1 0 2 270 2040 670
preplace netloc axis_pfb_readout_v3_0_m0_axis 1 0 2 310 3050 680
preplace netloc axis_pfb_readout_v3_0_m1_axis 1 0 2 290 2240 700
preplace netloc axis_pfb_readout_v3_0_m2_axis 1 0 2 280 2230 710
preplace netloc axis_pfb_readout_v3_0_m3_axis 1 0 2 300 2250 670
preplace netloc axis_readout_v2_0_m0_axis 1 1 2 700 3980 1700
preplace netloc axis_readout_v2_0_m1_axis 1 0 2 270 4050 680
preplace netloc axis_readout_v3_0_m_axis 1 1 1 750 2330n
preplace netloc axis_register_slice_0_m_axis 1 5 1 4140 1280n
preplace netloc axis_register_slice_10_M_AXIS 1 0 4 160 -350 N -350 N -350 2440
preplace netloc axis_register_slice_1_m_axis 1 5 1 4120 1620n
preplace netloc axis_register_slice_2_m_axis1 1 5 1 4020 1770n
preplace netloc axis_register_slice_3_M_AXIS 1 0 2 240 2030 730
preplace netloc axis_register_slice_3_M_AXIS1 1 4 1 3650 1020n
preplace netloc axis_register_slice_4_M_AXIS 1 3 2 2940 1840 3250
preplace netloc axis_register_slice_5_M_AXIS 1 4 1 3680 1920n
preplace netloc axis_register_slice_8_M_AXIS 1 4 1 3670 1400n
preplace netloc axis_resampler_2x1_v1_0_m_axis 1 0 2 310 2260 690
preplace netloc axis_sg_int4_v2_0_m_axis 1 5 1 4030 1790n
preplace netloc axis_sg_int4_v2_1_m_axis 1 5 1 4080 1810n
preplace netloc axis_sg_mixmux8_v1_0_m_axis 1 5 1 4100 1830n
preplace netloc axis_sg_mux8_v1_0_m_axis 1 4 2 3730 1700 4010
preplace netloc axis_signal_gen_v6_0_m_axis 1 4 2 3730 940 4010
preplace netloc axis_signal_gen_v6_1_m_axis 1 4 2 3730 1840 4010
preplace netloc axis_switch_0_M00_AXIS 1 2 3 N 930 2910 1340 3560
preplace netloc axis_switch_avg_M00_AXIS 1 0 5 170 -340 NJ -340 NJ -340 2510J -330 3300
preplace netloc axis_switch_buf_M00_AXIS 1 0 5 190 -330 NJ -330 NJ -330 2490J -320 3360
preplace netloc axis_switch_ddr_M00_AXIS 1 3 3 N 4180 3730 3550 N
preplace netloc axis_switch_gen_M01_AXIS 1 2 3 N 950 2870 1700 3620
preplace netloc axis_switch_gen_M02_AXIS 1 2 3 N 970 2860 1620 3610
preplace netloc axis_switch_gen_M03_AXIS 1 2 3 N 990 2880 1450 3530
preplace netloc axis_switch_mr_M00_AXIS 1 3 1 2810 3730n
preplace netloc axis_tmux_v1_0_m0_axis 1 1 2 950 1820 1390J
preplace netloc axis_tmux_v1_0_m1_axis 1 1 1 930 1480n
preplace netloc axis_tmux_v1_0_m2_axis 1 1 1 940 1660n
preplace netloc axis_tmux_v1_0_m3_axis 1 1 2 NJ 1890 1530
preplace netloc dac2_clk_0_1 1 5 2 4270 2290 N
preplace netloc ddr4_0_C0_DDR4 1 6 1 4700 3610n
preplace netloc default_sysclk_c0_300mhz_1 1 5 2 4280 3760 4780J
preplace netloc mr_buffer_et_0_m00_axis 1 0 5 200 -320 N -320 N -320 2480 -310 3450
preplace netloc ps8_0_axi_periph_M01_AXI 1 1 4 1020 -310 NJ -310 2460J -300 3460
preplace netloc ps8_0_axi_periph_M02_AXI 1 4 1 3720 360n
preplace netloc ps8_0_axi_periph_M03_AXI 1 4 1 3680 380n
preplace netloc ps8_0_axi_periph_M04_AXI 1 4 1 3630 400n
preplace netloc ps8_0_axi_periph_M05_AXI 1 2 3 1720 -280 NJ -280 3330
preplace netloc ps8_0_axi_periph_M06_AXI 1 0 5 180 -300 NJ -300 N -300 2430J -290 3380
preplace netloc ps8_0_axi_periph_M07_AXI 1 1 4 1050 -290 NJ -290 2530J -340 3470
preplace netloc ps8_0_axi_periph_M09_AXI 1 1 4 1030 -270 N -270 NJ -270 3270
preplace netloc ps8_0_axi_periph_M10_AXI 1 1 4 1060 -260 N -260 NJ -260 3320
preplace netloc ps8_0_axi_periph_M11_AXI 1 1 4 1000 -250 NJ -250 NJ -250 3370
preplace netloc ps8_0_axi_periph_M12_AXI 1 1 4 1010 -240 NJ -240 NJ -240 3400
preplace netloc ps8_0_axi_periph_M13_AXI 1 1 4 1040 -230 NJ -230 NJ -230 3410
preplace netloc ps8_0_axi_periph_M14_AXI 1 0 5 100 -220 NJ -220 NJ -220 NJ -220 3420
preplace netloc ps8_0_axi_periph_M15_AXI 1 0 5 70 -280 N -280 1700J -210 NJ -210 3430
preplace netloc ps8_0_axi_periph_M16_AXI 1 1 4 1070 -200 N -200 N -200 3440
preplace netloc ps8_0_axi_periph_M17_AXI 1 3 2 2930 -100 3240
preplace netloc ps8_0_axi_periph_M18_AXI 1 3 2 2920 -120 3310
preplace netloc ps8_0_axi_periph_M19_AXI 1 0 5 310 -210 NJ -210 1680J -190 NJ -190 3280
preplace netloc ps8_0_axi_periph_M20_AXI 1 0 5 210 -190 NJ -190 1670J -180 NJ -180 3340
preplace netloc ps8_0_axi_periph_M21_AXI 1 0 5 220 -180 N -180 1530 -170 N -170 3390
preplace netloc ps8_0_axi_periph_M22_AXI 1 4 2 N 760 4130
preplace netloc ps8_0_axi_periph_M23_AXI 1 2 3 1710 -110 N -110 3250
preplace netloc ps8_0_axi_periph_M24_AXI 1 4 1 3640 800n
preplace netloc ps8_0_axi_periph_M25_AXI 1 3 2 2910 1460 3260
preplace netloc ps8_0_axi_periph_M26_AXI 1 1 4 1090 -160 N -160 N -160 3290
preplace netloc ps8_0_axi_periph_M27_AXI 1 4 1 3470 860n
preplace netloc ps8_0_axi_periph_M28_AXI 1 4 1 3460 880n
preplace netloc ps8_0_axi_periph_M29_AXI 1 0 5 230 -170 NJ -170 1510J -150 NJ -150 3350
preplace netloc ps8_0_axi_periph_M30_AXI 1 4 1 3480 100n
preplace netloc qick_processor_0_m0_axis 1 1 2 NJ 1270 1660
preplace netloc qick_processor_0_m1_axis 1 1 2 NJ 1290 1630
preplace netloc qick_processor_0_m2_axis 1 1 1 950 1310n
preplace netloc qick_processor_0_m3_axis 1 1 1 940 1330n
preplace netloc qick_processor_0_m4_axis 1 0 2 300 1960 670
preplace netloc qick_processor_0_m_dma_axis_o 1 0 2 240 800 680
preplace netloc sg_translator_0_m_gen_v6_axis 1 3 1 2600 1360n
preplace netloc sg_translator_1_m_mux4_axis 1 3 1 2800 1530n
preplace netloc sg_translator_2_m_gen_v6_axis 1 3 1 2790 1670n
preplace netloc sg_translator_3_m_gen_v6_axis 1 4 1 3650 2320n
preplace netloc sg_translator_4_m_gen_v6_axis 1 4 1 3680 2580n
preplace netloc sg_translator_5_m_mux4_axis 1 4 1 3710 2820n
preplace netloc sg_translator_6_m_readout_v3_axis 1 0 4 310 1990 940 1900 N 1900 2420
preplace netloc sg_translator_7_m_readout_v3_axis 1 2 2 1740 2200 2420
preplace netloc smartconnect_0_M00_AXI 1 2 1 1390 40n
preplace netloc sysref_in_0_1 1 5 2 4220 2390 N
preplace netloc usp_rf_data_converter_0_m20_axis 1 0 7 280 820 950 840 1660 920 2600 1350 3550 930 N 930 4660
preplace netloc usp_rf_data_converter_0_m21_axis 1 0 7 250 810 940 1280 N 1280 2610 1360 3540 920 N 920 4670
preplace netloc usp_rf_data_converter_0_m22_axis 1 0 7 120 -120 N -120 N -120 2520 -370 N -370 N -370 4680
preplace netloc usp_rf_data_converter_0_m23_axis 1 0 7 90 -130 N -130 N -130 2500 -380 N -380 N -380 4690
preplace netloc usp_rf_data_converter_0_vout20 1 6 1 N 1870
preplace netloc usp_rf_data_converter_0_vout21 1 6 1 N 1890
preplace netloc usp_rf_data_converter_0_vout22 1 6 1 N 1910
preplace netloc usp_rf_data_converter_0_vout30 1 6 1 N 1930
preplace netloc usp_rf_data_converter_0_vout31 1 6 1 N 1950
preplace netloc usp_rf_data_converter_0_vout32 1 6 1 N 1970
preplace netloc vin20_0_1 1 5 2 4260 2310 N
preplace netloc vin21_0_1 1 5 2 4250 2330 N
preplace netloc vin22_0_1 1 5 2 4240 2350 N
preplace netloc vin23_0_1 1 5 2 4230 2370 N
preplace netloc zynq_ultra_ps_e_0_M_AXI_HPM0_FPD 1 3 1 2560 -40n
preplace netloc zynq_ultra_ps_e_0_M_AXI_HPM1_FPD 1 3 3 2540 -360 N -360 4150
levelinfo -pg 1 -10 490 1250 2050 3090 3870 4470 4800
pagesize -pg 1 -db -bbox -sgen -220 -440 5370 9360
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


