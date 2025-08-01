
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
QICK:QICK:axis_cdcsync_v1:1.0\
QICK:QICK:axis_register_slice_nb:1.0\
QICK:QICK:axis_sg_mixmux8_v1:1.0\
QICK:QICK:axis_signal_gen_v6:1.0\
QICK:QICK:axis_tmux_v1:1.0\
xilinx.com:ip:proc_sys_reset:5.0\
QICK:QICK:sg_translator:1.0\
xilinx.com:ip:xlconcat:2.1\
xilinx.com:ip:axi_dma:7.1\
xilinx.com:ip:smartconnect:1.0\
xilinx.com:ip:axis_broadcaster:1.1\
xilinx.com:ip:axis_clock_converter:1.1\
QICK:QICK:axis_dyn_readout_v1:1.0\
QICK:QICK:axis_pfb_readout_v4:1.0\
xilinx.com:ip:axis_register_slice:1.1\
QICK:QICK:axis_sg_int4_v2:1.0\
xilinx.com:ip:axis_switch:1.1\
xilinx.com:ip:clk_wiz:6.0\
xilinx.com:ip:usp_rf_data_converter:2.6\
xilinx.com:ip:zynq_ultra_ps_e:3.5\
xilinx.com:ip:axi_gpio:2.0\
QICK:QICK:qick_vec2bit:1.0\
QICK:QICK:axis_avg_buffer:1.2\
QICK:QICK:mr_buffer_et:1.1\
QICK:QICK:qick_processor:2.0\
QICK:QICK:axis_buffer_ddr_v1:1.0\
xilinx.com:ip:axis_dwidth_converter:1.1\
xilinx.com:ip:ddr4:2.2\
xilinx.com:ip:axi_quad_spi:3.2\
xilinx.com:ip:xlconstant:1.1\
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


# Hierarchical cell: rfb_control
proc create_hier_cell_rfb_control { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_rfb_control() - Empty argument(s)!"}
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
  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 AXI_GPIO_BRDSEL

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 AXI_SPI_FILTER

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 AXI_SPI_BIAS

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 AXI_GPIO_BIAS

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 AXI_SPI_ATTN


  # Create pins
  create_bd_pin -dir I -type clk s_axi_aclk
  create_bd_pin -dir I -type rst s_axi_aresetn
  create_bd_pin -dir O DB_1V8_SDI
  create_bd_pin -dir I DB_1V8_SDO
  create_bd_pin -dir O DB_1V8_SER_CLK
  create_bd_pin -dir O DAC_1V8_BIAS_S0
  create_bd_pin -dir O DAC_1V8_BIAS_S1
  create_bd_pin -dir O DAC_1V8_BIAS_S2
  create_bd_pin -dir O DAC_1V8_BIAS_SYNCn
  create_bd_pin -dir O -from 0 -to 0 DAC_1V8_BIAS_CLRn
  create_bd_pin -dir O DB_1V8_BRD_SEL_SEL0
  create_bd_pin -dir O DB_1V8_BRD_SEL_SEL1
  create_bd_pin -dir O DB_1V8_BRD_SEL_SEL2
  create_bd_pin -dir O DB_1V8_BRD_SEL
  create_bd_pin -dir O DAC_1V8_BIAS_SDIN
  create_bd_pin -dir I DAC_1V8_BIAS_SDO
  create_bd_pin -dir O DAC_1V8_BIAS_SCLK
  create_bd_pin -dir O -from 0 -to 0 DAC_1V8_BIAS_SWEN
  create_bd_pin -dir O DB_1V8_PE_SI
  create_bd_pin -dir O DB_1V8_PE_CLK
  create_bd_pin -dir O -from 0 -to 0 DB_1V8_PE_LE
  create_bd_pin -dir O DB_1V8_SEL0
  create_bd_pin -dir O DB_1V8_SEL1
  create_bd_pin -dir O DB_1V8_SEL2
  create_bd_pin -dir O DB_1V8_CSn

  # Create instance: brd_sel_gpio, and set properties
  set brd_sel_gpio [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 brd_sel_gpio ]
  set_property -dict [list \
    CONFIG.C_ALL_OUTPUTS {1} \
    CONFIG.C_GPIO_WIDTH {4} \
  ] $brd_sel_gpio


  # Create instance: filter_spi, and set properties
  set filter_spi [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_quad_spi:3.2 filter_spi ]
  set_property CONFIG.C_NUM_SS_BITS {4} $filter_spi


  # Create instance: xlconstant_0, and set properties
  set xlconstant_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_0 ]

  # Create instance: bias_spi, and set properties
  set bias_spi [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_quad_spi:3.2 bias_spi ]
  set_property -dict [list \
    CONFIG.C_NUM_SS_BITS {4} \
    CONFIG.C_NUM_TRANSFER_BITS {32} \
  ] $bias_spi


  # Create instance: bias_gpio, and set properties
  set bias_gpio [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 bias_gpio ]
  set_property -dict [list \
    CONFIG.C_ALL_OUTPUTS {1} \
    CONFIG.C_GPIO_WIDTH {1} \
  ] $bias_gpio


  # Create instance: attn_spi, and set properties
  set attn_spi [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_quad_spi:3.2 attn_spi ]
  set_property -dict [list \
    CONFIG.C_NUM_SS_BITS {1} \
    CONFIG.C_NUM_TRANSFER_BITS {16} \
  ] $attn_spi


  # Create instance: bias_spi_bits, and set properties
  set bias_spi_bits [ create_bd_cell -type ip -vlnv QICK:QICK:qick_vec2bit:1.0 bias_spi_bits ]
  set_property CONFIG.IN_DW {4} $bias_spi_bits


  # Create instance: brd_sel_bits, and set properties
  set brd_sel_bits [ create_bd_cell -type ip -vlnv QICK:QICK:qick_vec2bit:1.0 brd_sel_bits ]
  set_property CONFIG.IN_DW {4} $brd_sel_bits


  # Create instance: filter_spi_bits, and set properties
  set filter_spi_bits [ create_bd_cell -type ip -vlnv QICK:QICK:qick_vec2bit:1.0 filter_spi_bits ]
  set_property CONFIG.IN_DW {4} $filter_spi_bits


  # Create interface connections
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M28_AXI [get_bd_intf_pins AXI_SPI_ATTN] [get_bd_intf_pins attn_spi/AXI_LITE]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M29_AXI [get_bd_intf_pins AXI_GPIO_BIAS] [get_bd_intf_pins bias_gpio/S_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M30_AXI [get_bd_intf_pins AXI_SPI_BIAS] [get_bd_intf_pins bias_spi/AXI_LITE]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M31_AXI [get_bd_intf_pins AXI_GPIO_BRDSEL] [get_bd_intf_pins brd_sel_gpio/S_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M33_AXI [get_bd_intf_pins AXI_SPI_FILTER] [get_bd_intf_pins filter_spi/AXI_LITE]

  # Create port connections
  connect_bd_net -net DAC_1V8_BIAS_SDO_1 [get_bd_pins DAC_1V8_BIAS_SDO] [get_bd_pins bias_spi/io1_i]
  connect_bd_net -net DB_1V8_SDO_1 [get_bd_pins DB_1V8_SDO] [get_bd_pins filter_spi/io1_i]
  connect_bd_net -net attn_spi_io0_o [get_bd_pins attn_spi/io0_o] [get_bd_pins DB_1V8_PE_SI]
  connect_bd_net -net attn_spi_sck_o [get_bd_pins attn_spi/sck_o] [get_bd_pins DB_1V8_PE_CLK]
  connect_bd_net -net attn_spi_ss_o [get_bd_pins attn_spi/ss_o] [get_bd_pins DB_1V8_PE_LE]
  connect_bd_net -net bias_gpio_gpio_io_o [get_bd_pins bias_gpio/gpio_io_o] [get_bd_pins DAC_1V8_BIAS_SWEN]
  connect_bd_net -net bias_spi_bits_dout0 [get_bd_pins bias_spi_bits/dout0] [get_bd_pins DAC_1V8_BIAS_S0]
  connect_bd_net -net bias_spi_bits_dout1 [get_bd_pins bias_spi_bits/dout1] [get_bd_pins DAC_1V8_BIAS_S1]
  connect_bd_net -net bias_spi_bits_dout2 [get_bd_pins bias_spi_bits/dout2] [get_bd_pins DAC_1V8_BIAS_S2]
  connect_bd_net -net bias_spi_bits_dout3 [get_bd_pins bias_spi_bits/dout3] [get_bd_pins DAC_1V8_BIAS_SYNCn]
  connect_bd_net -net bias_spi_io0_o [get_bd_pins bias_spi/io0_o] [get_bd_pins DAC_1V8_BIAS_SDIN]
  connect_bd_net -net bias_spi_sck_o [get_bd_pins bias_spi/sck_o] [get_bd_pins DAC_1V8_BIAS_SCLK]
  connect_bd_net -net bias_spi_ss_o [get_bd_pins bias_spi/ss_o] [get_bd_pins bias_spi_bits/din]
  connect_bd_net -net brd_sel_bits_dout0 [get_bd_pins brd_sel_bits/dout0] [get_bd_pins DB_1V8_BRD_SEL_SEL0]
  connect_bd_net -net brd_sel_bits_dout1 [get_bd_pins brd_sel_bits/dout1] [get_bd_pins DB_1V8_BRD_SEL_SEL1]
  connect_bd_net -net brd_sel_bits_dout2 [get_bd_pins brd_sel_bits/dout2] [get_bd_pins DB_1V8_BRD_SEL_SEL2]
  connect_bd_net -net brd_sel_bits_dout3 [get_bd_pins brd_sel_bits/dout3] [get_bd_pins DB_1V8_BRD_SEL]
  connect_bd_net -net brd_sel_gpio_gpio_io_o [get_bd_pins brd_sel_gpio/gpio_io_o] [get_bd_pins brd_sel_bits/din]
  connect_bd_net -net filter_spi_bits_dout0 [get_bd_pins filter_spi_bits/dout0] [get_bd_pins DB_1V8_SEL0]
  connect_bd_net -net filter_spi_bits_dout1 [get_bd_pins filter_spi_bits/dout1] [get_bd_pins DB_1V8_SEL1]
  connect_bd_net -net filter_spi_bits_dout2 [get_bd_pins filter_spi_bits/dout2] [get_bd_pins DB_1V8_SEL2]
  connect_bd_net -net filter_spi_bits_dout3 [get_bd_pins filter_spi_bits/dout3] [get_bd_pins DB_1V8_CSn]
  connect_bd_net -net filter_spi_io0_o [get_bd_pins filter_spi/io0_o] [get_bd_pins DB_1V8_SDI]
  connect_bd_net -net filter_spi_sck_o [get_bd_pins filter_spi/sck_o] [get_bd_pins DB_1V8_SER_CLK]
  connect_bd_net -net filter_spi_ss_o [get_bd_pins filter_spi/ss_o] [get_bd_pins filter_spi_bits/din]
  connect_bd_net -net rst_ps8_0_99M_peripheral_aresetn [get_bd_pins s_axi_aresetn] [get_bd_pins attn_spi/s_axi_aresetn] [get_bd_pins bias_gpio/s_axi_aresetn] [get_bd_pins bias_spi/s_axi_aresetn] [get_bd_pins filter_spi/s_axi_aresetn] [get_bd_pins brd_sel_gpio/s_axi_aresetn]
  connect_bd_net -net xlconstant_0_dout [get_bd_pins xlconstant_0/dout] [get_bd_pins DAC_1V8_BIAS_CLRn]
  connect_bd_net -net zynq_ultra_ps_e_0_pl_clk0 [get_bd_pins s_axi_aclk] [get_bd_pins attn_spi/ext_spi_clk] [get_bd_pins attn_spi/s_axi_aclk] [get_bd_pins bias_gpio/s_axi_aclk] [get_bd_pins bias_spi/ext_spi_clk] [get_bd_pins bias_spi/s_axi_aclk] [get_bd_pins filter_spi/ext_spi_clk] [get_bd_pins filter_spi/s_axi_aclk] [get_bd_pins brd_sel_gpio/s_axi_aclk]

  # Restore current instance
  current_bd_instance $oldCurInst
}

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
  connect_bd_net -net qick_processor_0_trig_9_o [get_bd_pins trigger] [get_bd_pins axis_buffer_ddr_v1_0/trigger]
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

  set vin10_0 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 vin10_0 ]

  set vin20_0 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 vin20_0 ]

  set vin21_0 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 vin21_0 ]

  set vin22_0 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 vin22_0 ]

  set vout0 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 vout0 ]

  set vout1 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 vout1 ]

  set vout2 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 vout2 ]

  set vout3 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 vout3 ]

  set vout4 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 vout4 ]

  set vout5 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 vout5 ]

  set vout6 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 vout6 ]

  set vout7 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 vout7 ]

  set vout8 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 vout8 ]

  set vout9 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 vout9 ]

  set vout10 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 vout10 ]

  set vout11 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 vout11 ]

  set vout12 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 vout12 ]

  set vout13 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 vout13 ]

  set vout14 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 vout14 ]

  set vout15 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 vout15 ]


  # Create ports
  set DAC_1V8_BIAS_CLRn [ create_bd_port -dir O -from 0 -to 0 DAC_1V8_BIAS_CLRn ]
  set DAC_1V8_BIAS_S0 [ create_bd_port -dir O DAC_1V8_BIAS_S0 ]
  set DAC_1V8_BIAS_S1 [ create_bd_port -dir O DAC_1V8_BIAS_S1 ]
  set DAC_1V8_BIAS_S2 [ create_bd_port -dir O DAC_1V8_BIAS_S2 ]
  set DAC_1V8_BIAS_SCLK [ create_bd_port -dir O DAC_1V8_BIAS_SCLK ]
  set DAC_1V8_BIAS_SDIN [ create_bd_port -dir O DAC_1V8_BIAS_SDIN ]
  set DAC_1V8_BIAS_SDO [ create_bd_port -dir I DAC_1V8_BIAS_SDO ]
  set DAC_1V8_BIAS_SWEN [ create_bd_port -dir O -from 0 -to 0 DAC_1V8_BIAS_SWEN ]
  set DAC_1V8_BIAS_SYNCn [ create_bd_port -dir O DAC_1V8_BIAS_SYNCn ]
  set DB_1V8_BRD_SEL [ create_bd_port -dir O DB_1V8_BRD_SEL ]
  set DB_1V8_BRD_SEL_SEL0 [ create_bd_port -dir O DB_1V8_BRD_SEL_SEL0 ]
  set DB_1V8_BRD_SEL_SEL1 [ create_bd_port -dir O DB_1V8_BRD_SEL_SEL1 ]
  set DB_1V8_BRD_SEL_SEL2 [ create_bd_port -dir O DB_1V8_BRD_SEL_SEL2 ]
  set DB_1V8_CSn [ create_bd_port -dir O DB_1V8_CSn ]
  set DB_1V8_PE_CLK [ create_bd_port -dir O DB_1V8_PE_CLK ]
  set DB_1V8_PE_LE [ create_bd_port -dir O -from 0 -to 0 DB_1V8_PE_LE ]
  set DB_1V8_PE_SI [ create_bd_port -dir O DB_1V8_PE_SI ]
  set DB_1V8_SDI [ create_bd_port -dir O DB_1V8_SDI ]
  set DB_1V8_SDO [ create_bd_port -dir I DB_1V8_SDO ]
  set DB_1V8_SEL0 [ create_bd_port -dir O DB_1V8_SEL0 ]
  set DB_1V8_SEL1 [ create_bd_port -dir O DB_1V8_SEL1 ]
  set DB_1V8_SEL2 [ create_bd_port -dir O DB_1V8_SEL2 ]
  set DB_1V8_SER_CLK [ create_bd_port -dir O DB_1V8_SER_CLK ]
  set PMOD_IO_0 [ create_bd_port -dir O PMOD_IO_0 ]
  set PMOD_IO_1 [ create_bd_port -dir O PMOD_IO_1 ]
  set PMOD_IO_2 [ create_bd_port -dir O PMOD_IO_2 ]
  set PMOD_IO_3 [ create_bd_port -dir O PMOD_IO_3 ]
  set PMOD_IO_4 [ create_bd_port -dir O PMOD_IO_4 ]
  set PMOD_IO_5 [ create_bd_port -dir O PMOD_IO_5 ]
  set PMOD_IO_6 [ create_bd_port -dir O PMOD_IO_6 ]
  set PMOD_IO_7 [ create_bd_port -dir O PMOD_IO_7 ]
  set PMOD_LED0 [ create_bd_port -dir O PMOD_LED0 ]
  set PMOD_LED1 [ create_bd_port -dir O PMOD_LED1 ]
  set PMOD_LED2 [ create_bd_port -dir O PMOD_LED2 ]
  set PMOD_LED3 [ create_bd_port -dir O PMOD_LED3 ]
  set PMOD_LED4 [ create_bd_port -dir O PMOD_LED4 ]
  set PMOD_LED5 [ create_bd_port -dir O PMOD_LED5 ]
  set PMOD_LED6 [ create_bd_port -dir O PMOD_LED6 ]
  set PMOD_LED7 [ create_bd_port -dir O PMOD_LED7 ]
  set SPARE0_1V8 [ create_bd_port -dir O SPARE0_1V8 ]
  set SPARE1_1V8 [ create_bd_port -dir O SPARE1_1V8 ]
  set SPARE2_1V8 [ create_bd_port -dir O SPARE2_1V8 ]
  set SPARE3_1V8 [ create_bd_port -dir O SPARE3_1V8 ]
  set TWOMHZ_1V8_PWR_SYNC [ create_bd_port -dir O -type clk TWOMHZ_1V8_PWR_SYNC ]
  set SPARE4_1V8 [ create_bd_port -dir O SPARE4_1V8 ]
  set SPARE5_1V8 [ create_bd_port -dir O SPARE5_1V8 ]
  set CLK104_CLK_SPI_MUX_SEL_LS [ create_bd_port -dir O -from 1 -to 0 CLK104_CLK_SPI_MUX_SEL_LS ]

  # Create instance: axi_intc_0, and set properties
  set axi_intc_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_intc:4.1 axi_intc_0 ]
  set_property CONFIG.C_IRQ_CONNECTION {1} $axi_intc_0


  # Create instance: axis_cdcsync_v1_0, and set properties
  set axis_cdcsync_v1_0 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_cdcsync_v1:1.0 axis_cdcsync_v1_0 ]
  set_property -dict [list \
    CONFIG.B {168} \
    CONFIG.N {4} \
  ] $axis_cdcsync_v1_0


  # Create instance: axis_cdcsync_v1_2, and set properties
  set axis_cdcsync_v1_2 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_cdcsync_v1:1.0 axis_cdcsync_v1_2 ]
  set_property -dict [list \
    CONFIG.B {168} \
    CONFIG.N {3} \
  ] $axis_cdcsync_v1_2


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


  # Create instance: axis_register_slice_2, and set properties
  set axis_register_slice_2 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_register_slice_nb:1.0 axis_register_slice_2 ]
  set_property -dict [list \
    CONFIG.B {256} \
    CONFIG.N {6} \
  ] $axis_register_slice_2


  # Create instance: axis_register_slice_3, and set properties
  set axis_register_slice_3 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_register_slice_nb:1.0 axis_register_slice_3 ]
  set_property -dict [list \
    CONFIG.B {256} \
    CONFIG.N {6} \
  ] $axis_register_slice_3


  # Create instance: axis_sg_mixmux8_v1_0, and set properties
  set axis_sg_mixmux8_v1_0 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_sg_mixmux8_v1:1.0 axis_sg_mixmux8_v1_0 ]
  set_property CONFIG.N_DDS {4} $axis_sg_mixmux8_v1_0


  # Create instance: axis_signal_gen_v6_0, and set properties
  set axis_signal_gen_v6_0 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_signal_gen_v6:1.0 axis_signal_gen_v6_0 ]
  set_property CONFIG.N {12} $axis_signal_gen_v6_0


  # Create instance: axis_signal_gen_v6_1, and set properties
  set axis_signal_gen_v6_1 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_signal_gen_v6:1.0 axis_signal_gen_v6_1 ]
  set_property CONFIG.N {10} $axis_signal_gen_v6_1


  # Create instance: axis_signal_gen_v6_2, and set properties
  set axis_signal_gen_v6_2 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_signal_gen_v6:1.0 axis_signal_gen_v6_2 ]
  set_property CONFIG.N {11} $axis_signal_gen_v6_2


  # Create instance: axis_signal_gen_v6_3, and set properties
  set axis_signal_gen_v6_3 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_signal_gen_v6:1.0 axis_signal_gen_v6_3 ]
  set_property CONFIG.N {10} $axis_signal_gen_v6_3


  # Create instance: axis_tmux_v1_0, and set properties
  set axis_tmux_v1_0 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_tmux_v1:1.0 axis_tmux_v1_0 ]
  set_property -dict [list \
    CONFIG.B {168} \
    CONFIG.N {4} \
  ] $axis_tmux_v1_0


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


  # Create instance: rst_dac0, and set properties
  set rst_dac0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_dac0 ]
  set_property -dict [list \
    CONFIG.RESET_BOARD_INTERFACE {Custom} \
    CONFIG.USE_BOARD_FLOW {true} \
  ] $rst_dac0


  # Create instance: rst_dac2, and set properties
  set rst_dac2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_dac2 ]
  set_property -dict [list \
    CONFIG.RESET_BOARD_INTERFACE {Custom} \
    CONFIG.USE_BOARD_FLOW {true} \
  ] $rst_dac2


  # Create instance: sg_translator_0, and set properties
  set sg_translator_0 [ create_bd_cell -type ip -vlnv QICK:QICK:sg_translator:1.0 sg_translator_0 ]

  # Create instance: sg_translator_1, and set properties
  set sg_translator_1 [ create_bd_cell -type ip -vlnv QICK:QICK:sg_translator:1.0 sg_translator_1 ]

  # Create instance: sg_translator_2, and set properties
  set sg_translator_2 [ create_bd_cell -type ip -vlnv QICK:QICK:sg_translator:1.0 sg_translator_2 ]

  # Create instance: sg_translator_3, and set properties
  set sg_translator_3 [ create_bd_cell -type ip -vlnv QICK:QICK:sg_translator:1.0 sg_translator_3 ]
  set_property CONFIG.OUT_TYPE {0} $sg_translator_3


  # Create instance: sg_translator_5, and set properties
  set sg_translator_5 [ create_bd_cell -type ip -vlnv QICK:QICK:sg_translator:1.0 sg_translator_5 ]
  set_property CONFIG.OUT_TYPE {0} $sg_translator_5


  # Create instance: sg_translator_6, and set properties
  set sg_translator_6 [ create_bd_cell -type ip -vlnv QICK:QICK:sg_translator:1.0 sg_translator_6 ]
  set_property CONFIG.OUT_TYPE {0} $sg_translator_6


  # Create instance: sg_translator_7, and set properties
  set sg_translator_7 [ create_bd_cell -type ip -vlnv QICK:QICK:sg_translator:1.0 sg_translator_7 ]
  set_property CONFIG.OUT_TYPE {0} $sg_translator_7


  # Create instance: sg_translator_8, and set properties
  set sg_translator_8 [ create_bd_cell -type ip -vlnv QICK:QICK:sg_translator:1.0 sg_translator_8 ]
  set_property CONFIG.OUT_TYPE {0} $sg_translator_8


  # Create instance: sg_translator_9, and set properties
  set sg_translator_9 [ create_bd_cell -type ip -vlnv QICK:QICK:sg_translator:1.0 sg_translator_9 ]
  set_property CONFIG.OUT_TYPE {0} $sg_translator_9


  # Create instance: sg_translator_10, and set properties
  set sg_translator_10 [ create_bd_cell -type ip -vlnv QICK:QICK:sg_translator:1.0 sg_translator_10 ]
  set_property CONFIG.OUT_TYPE {0} $sg_translator_10


  # Create instance: sg_translator_11, and set properties
  set sg_translator_11 [ create_bd_cell -type ip -vlnv QICK:QICK:sg_translator:1.0 sg_translator_11 ]
  set_property CONFIG.OUT_TYPE {0} $sg_translator_11


  # Create instance: sg_translator_12, and set properties
  set sg_translator_12 [ create_bd_cell -type ip -vlnv QICK:QICK:sg_translator:1.0 sg_translator_12 ]
  set_property CONFIG.OUT_TYPE {0} $sg_translator_12


  # Create instance: sg_translator_4, and set properties
  set sg_translator_4 [ create_bd_cell -type ip -vlnv QICK:QICK:sg_translator:1.0 sg_translator_4 ]
  set_property CONFIG.OUT_TYPE {2} $sg_translator_4


  # Create instance: sg_translator_13, and set properties
  set sg_translator_13 [ create_bd_cell -type ip -vlnv QICK:QICK:sg_translator:1.0 sg_translator_13 ]
  set_property CONFIG.OUT_TYPE {0} $sg_translator_13


  # Create instance: sg_translator_14, and set properties
  set sg_translator_14 [ create_bd_cell -type ip -vlnv QICK:QICK:sg_translator:1.0 sg_translator_14 ]
  set_property CONFIG.OUT_TYPE {0} $sg_translator_14


  # Create instance: sg_translator_15, and set properties
  set sg_translator_15 [ create_bd_cell -type ip -vlnv QICK:QICK:sg_translator:1.0 sg_translator_15 ]
  set_property CONFIG.OUT_TYPE {0} $sg_translator_15


  # Create instance: sg_translator_16, and set properties
  set sg_translator_16 [ create_bd_cell -type ip -vlnv QICK:QICK:sg_translator:1.0 sg_translator_16 ]
  set_property CONFIG.OUT_TYPE {3} $sg_translator_16


  # Create instance: sg_translator_17, and set properties
  set sg_translator_17 [ create_bd_cell -type ip -vlnv QICK:QICK:sg_translator:1.0 sg_translator_17 ]
  set_property CONFIG.OUT_TYPE {3} $sg_translator_17


  # Create instance: xlconcat_intc, and set properties
  set xlconcat_intc [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 xlconcat_intc ]
  set_property CONFIG.NUM_PORTS {7} $xlconcat_intc


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


  # Create instance: axis_broadcaster_6, and set properties
  set axis_broadcaster_6 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_broadcaster:1.1 axis_broadcaster_6 ]
  set_property CONFIG.HAS_TREADY {0} $axis_broadcaster_6


  # Create instance: axis_broadcaster_7, and set properties
  set axis_broadcaster_7 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_broadcaster:1.1 axis_broadcaster_7 ]
  set_property CONFIG.HAS_TREADY {0} $axis_broadcaster_7


  # Create instance: axis_broadcaster_8, and set properties
  set axis_broadcaster_8 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_broadcaster:1.1 axis_broadcaster_8 ]
  set_property CONFIG.HAS_TREADY {0} $axis_broadcaster_8


  # Create instance: axis_broadcaster_9, and set properties
  set axis_broadcaster_9 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_broadcaster:1.1 axis_broadcaster_9 ]
  set_property CONFIG.HAS_TREADY {0} $axis_broadcaster_9


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

  # Create instance: axis_clk_cnvrt_avg_7, and set properties
  set axis_clk_cnvrt_avg_7 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_clock_converter:1.1 axis_clk_cnvrt_avg_7 ]

  # Create instance: axis_clk_cnvrt_avg_8, and set properties
  set axis_clk_cnvrt_avg_8 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_clock_converter:1.1 axis_clk_cnvrt_avg_8 ]

  # Create instance: axis_clk_cnvrt_avg_9, and set properties
  set axis_clk_cnvrt_avg_9 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_clock_converter:1.1 axis_clk_cnvrt_avg_9 ]

  # Create instance: axis_dyn_readout_v1_0, and set properties
  set axis_dyn_readout_v1_0 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_dyn_readout_v1:1.0 axis_dyn_readout_v1_0 ]

  # Create instance: axis_dyn_readout_v1_1, and set properties
  set axis_dyn_readout_v1_1 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_dyn_readout_v1:1.0 axis_dyn_readout_v1_1 ]

  # Create instance: axis_pfb_readout_v4_0, and set properties
  set axis_pfb_readout_v4_0 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_pfb_readout_v4:1.0 axis_pfb_readout_v4_0 ]

  # Create instance: axis_register_slice_4, and set properties
  set axis_register_slice_4 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_register_slice:1.1 axis_register_slice_4 ]
  set_property CONFIG.REG_CONFIG {8} $axis_register_slice_4


  # Create instance: axis_register_slice_5, and set properties
  set axis_register_slice_5 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_register_slice:1.1 axis_register_slice_5 ]
  set_property CONFIG.REG_CONFIG {8} $axis_register_slice_5


  # Create instance: axis_register_slice_6, and set properties
  set axis_register_slice_6 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_register_slice:1.1 axis_register_slice_6 ]
  set_property CONFIG.REG_CONFIG {8} $axis_register_slice_6


  # Create instance: axis_register_slice_7, and set properties
  set axis_register_slice_7 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_register_slice:1.1 axis_register_slice_7 ]
  set_property CONFIG.REG_CONFIG {8} $axis_register_slice_7


  # Create instance: axis_sg_int4_v2_0, and set properties
  set axis_sg_int4_v2_0 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_sg_int4_v2:1.0 axis_sg_int4_v2_0 ]
  set_property CONFIG.N {14} $axis_sg_int4_v2_0


  # Create instance: axis_sg_int4_v2_10, and set properties
  set axis_sg_int4_v2_10 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_sg_int4_v2:1.0 axis_sg_int4_v2_10 ]
  set_property CONFIG.N {13} $axis_sg_int4_v2_10


  # Create instance: axis_sg_int4_v2_1, and set properties
  set axis_sg_int4_v2_1 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_sg_int4_v2:1.0 axis_sg_int4_v2_1 ]
  set_property CONFIG.N {13} $axis_sg_int4_v2_1


  # Create instance: axis_sg_int4_v2_2, and set properties
  set axis_sg_int4_v2_2 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_sg_int4_v2:1.0 axis_sg_int4_v2_2 ]
  set_property CONFIG.N {14} $axis_sg_int4_v2_2


  # Create instance: axis_sg_int4_v2_3, and set properties
  set axis_sg_int4_v2_3 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_sg_int4_v2:1.0 axis_sg_int4_v2_3 ]
  set_property CONFIG.N {13} $axis_sg_int4_v2_3


  # Create instance: axis_sg_int4_v2_4, and set properties
  set axis_sg_int4_v2_4 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_sg_int4_v2:1.0 axis_sg_int4_v2_4 ]
  set_property CONFIG.N {13} $axis_sg_int4_v2_4


  # Create instance: axis_sg_int4_v2_5, and set properties
  set axis_sg_int4_v2_5 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_sg_int4_v2:1.0 axis_sg_int4_v2_5 ]
  set_property CONFIG.N {13} $axis_sg_int4_v2_5


  # Create instance: axis_sg_int4_v2_6, and set properties
  set axis_sg_int4_v2_6 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_sg_int4_v2:1.0 axis_sg_int4_v2_6 ]
  set_property CONFIG.N {13} $axis_sg_int4_v2_6


  # Create instance: axis_sg_int4_v2_7, and set properties
  set axis_sg_int4_v2_7 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_sg_int4_v2:1.0 axis_sg_int4_v2_7 ]
  set_property CONFIG.N {13} $axis_sg_int4_v2_7


  # Create instance: axis_sg_int4_v2_8, and set properties
  set axis_sg_int4_v2_8 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_sg_int4_v2:1.0 axis_sg_int4_v2_8 ]
  set_property CONFIG.N {13} $axis_sg_int4_v2_8


  # Create instance: axis_sg_int4_v2_9, and set properties
  set axis_sg_int4_v2_9 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_sg_int4_v2:1.0 axis_sg_int4_v2_9 ]
  set_property CONFIG.N {13} $axis_sg_int4_v2_9


  # Create instance: axis_switch_avg, and set properties
  set axis_switch_avg [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_switch:1.1 axis_switch_avg ]
  set_property -dict [list \
    CONFIG.NUM_SI {11} \
    CONFIG.ROUTING_MODE {1} \
  ] $axis_switch_avg


  # Create instance: axis_switch_buf, and set properties
  set axis_switch_buf [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_switch:1.1 axis_switch_buf ]
  set_property -dict [list \
    CONFIG.NUM_SI {11} \
    CONFIG.ROUTING_MODE {1} \
  ] $axis_switch_buf


  # Create instance: axis_switch_ddr, and set properties
  set axis_switch_ddr [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_switch:1.1 axis_switch_ddr ]
  set_property -dict [list \
    CONFIG.NUM_SI {11} \
    CONFIG.ROUTING_MODE {1} \
  ] $axis_switch_ddr


  # Create instance: axis_switch_gen, and set properties
  set axis_switch_gen [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_switch:1.1 axis_switch_gen ]
  set_property -dict [list \
    CONFIG.DECODER_REG {1} \
    CONFIG.NUM_MI {15} \
    CONFIG.NUM_SI {1} \
    CONFIG.ROUTING_MODE {1} \
  ] $axis_switch_gen


  # Create instance: axis_switch_mr, and set properties
  set axis_switch_mr [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_switch:1.1 axis_switch_mr ]
  set_property -dict [list \
    CONFIG.NUM_SI {3} \
    CONFIG.ROUTING_MODE {1} \
  ] $axis_switch_mr


  # Create instance: clk_core, and set properties
  set clk_core [ create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_core ]
  set_property -dict [list \
    CONFIG.CLKOUT1_JITTER {89.358} \
    CONFIG.CLKOUT1_PHASE_ERROR {80.483} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {215.04} \
    CONFIG.MMCM_CLKFBOUT_MULT_F {5.625} \
    CONFIG.MMCM_CLKOUT0_DIVIDE_F {5.625} \
    CONFIG.MMCM_DIVCLK_DIVIDE {2} \
    CONFIG.OPTIMIZE_CLOCKING_STRUCTURE_EN {true} \
    CONFIG.PRIM_SOURCE {Global_buffer} \
    CONFIG.RESET_PORT {reset} \
    CONFIG.RESET_TYPE {ACTIVE_HIGH} \
  ] $clk_core


  # Create instance: ps8_0_axi_periph, and set properties
  set ps8_0_axi_periph [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 ps8_0_axi_periph ]
  set_property CONFIG.NUM_MI {51} $ps8_0_axi_periph


  # Create instance: usp_rf_data_converter_0, and set properties
  set usp_rf_data_converter_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:usp_rf_data_converter:2.6 usp_rf_data_converter_0 ]
  set_property -dict [list \
    CONFIG.ADC1_Clock_Source {2} \
    CONFIG.ADC1_Link_Coupling {1} \
    CONFIG.ADC1_PLL_Enable {true} \
    CONFIG.ADC1_Refclk_Freq {245.760} \
    CONFIG.ADC1_Sampling_Rate {2.4576} \
    CONFIG.ADC2_Clock_Dist {1} \
    CONFIG.ADC2_Outclk_Freq {307.200} \
    CONFIG.ADC2_PLL_Enable {true} \
    CONFIG.ADC2_Refclk_Freq {245.760} \
    CONFIG.ADC2_Sampling_Rate {2.4576} \
    CONFIG.ADC_Coarse_Mixer_Freq20 {3} \
    CONFIG.ADC_Coarse_Mixer_Freq21 {2} \
    CONFIG.ADC_Coarse_Mixer_Freq22 {3} \
    CONFIG.ADC_Data_Type21 {1} \
    CONFIG.ADC_Data_Type22 {0} \
    CONFIG.ADC_Data_Width20 {8} \
    CONFIG.ADC_Data_Width21 {8} \
    CONFIG.ADC_Data_Width22 {8} \
    CONFIG.ADC_Decimation_Mode20 {1} \
    CONFIG.ADC_Decimation_Mode21 {2} \
    CONFIG.ADC_Decimation_Mode22 {1} \
    CONFIG.ADC_Mixer_Mode21 {0} \
    CONFIG.ADC_Mixer_Mode22 {2} \
    CONFIG.ADC_Mixer_Type20 {1} \
    CONFIG.ADC_Mixer_Type21 {1} \
    CONFIG.ADC_Mixer_Type22 {1} \
    CONFIG.ADC_OBS22 {false} \
    CONFIG.ADC_Slice00_Enable {false} \
    CONFIG.ADC_Slice10_Enable {true} \
    CONFIG.ADC_Slice20_Enable {true} \
    CONFIG.ADC_Slice21_Enable {true} \
    CONFIG.ADC_Slice22_Enable {true} \
    CONFIG.ADC_Slice23_Enable {false} \
    CONFIG.ADC_Slice30_Enable {false} \
    CONFIG.DAC0_Clock_Source {6} \
    CONFIG.DAC0_Outclk_Freq {599.040} \
    CONFIG.DAC0_PLL_Enable {true} \
    CONFIG.DAC0_Refclk_Freq {245.760} \
    CONFIG.DAC0_Sampling_Rate {9.58464} \
    CONFIG.DAC1_Clock_Source {6} \
    CONFIG.DAC1_Outclk_Freq {430.080} \
    CONFIG.DAC1_PLL_Enable {true} \
    CONFIG.DAC1_Refclk_Freq {245.760} \
    CONFIG.DAC1_Sampling_Rate {6.88128} \
    CONFIG.DAC2_Clock_Dist {1} \
    CONFIG.DAC2_Outclk_Freq {430.080} \
    CONFIG.DAC2_PLL_Enable {true} \
    CONFIG.DAC2_Refclk_Freq {245.760} \
    CONFIG.DAC2_Sampling_Rate {6.88128} \
    CONFIG.DAC3_Clock_Source {6} \
    CONFIG.DAC3_Outclk_Freq {430.080} \
    CONFIG.DAC3_PLL_Enable {true} \
    CONFIG.DAC3_Refclk_Freq {245.760} \
    CONFIG.DAC3_Sampling_Rate {6.88128} \
    CONFIG.DAC_Coarse_Mixer_Freq00 {3} \
    CONFIG.DAC_Coarse_Mixer_Freq01 {3} \
    CONFIG.DAC_Coarse_Mixer_Freq02 {3} \
    CONFIG.DAC_Coarse_Mixer_Freq03 {3} \
    CONFIG.DAC_Data_Type00 {0} \
    CONFIG.DAC_Data_Width00 {16} \
    CONFIG.DAC_Data_Width01 {16} \
    CONFIG.DAC_Data_Width02 {16} \
    CONFIG.DAC_Data_Width03 {16} \
    CONFIG.DAC_Data_Width10 {8} \
    CONFIG.DAC_Data_Width11 {8} \
    CONFIG.DAC_Data_Width12 {8} \
    CONFIG.DAC_Data_Width13 {8} \
    CONFIG.DAC_Data_Width20 {8} \
    CONFIG.DAC_Data_Width21 {8} \
    CONFIG.DAC_Data_Width22 {8} \
    CONFIG.DAC_Data_Width23 {8} \
    CONFIG.DAC_Data_Width30 {8} \
    CONFIG.DAC_Data_Width31 {8} \
    CONFIG.DAC_Data_Width32 {8} \
    CONFIG.DAC_Data_Width33 {8} \
    CONFIG.DAC_Interpolation_Mode00 {1} \
    CONFIG.DAC_Interpolation_Mode01 {1} \
    CONFIG.DAC_Interpolation_Mode02 {1} \
    CONFIG.DAC_Interpolation_Mode03 {1} \
    CONFIG.DAC_Interpolation_Mode10 {4} \
    CONFIG.DAC_Interpolation_Mode11 {4} \
    CONFIG.DAC_Interpolation_Mode12 {4} \
    CONFIG.DAC_Interpolation_Mode13 {4} \
    CONFIG.DAC_Interpolation_Mode20 {4} \
    CONFIG.DAC_Interpolation_Mode21 {4} \
    CONFIG.DAC_Interpolation_Mode22 {4} \
    CONFIG.DAC_Interpolation_Mode23 {4} \
    CONFIG.DAC_Interpolation_Mode30 {4} \
    CONFIG.DAC_Interpolation_Mode31 {4} \
    CONFIG.DAC_Interpolation_Mode32 {4} \
    CONFIG.DAC_Interpolation_Mode33 {4} \
    CONFIG.DAC_Mixer_Mode00 {2} \
    CONFIG.DAC_Mixer_Mode01 {2} \
    CONFIG.DAC_Mixer_Mode02 {2} \
    CONFIG.DAC_Mixer_Mode03 {2} \
    CONFIG.DAC_Mixer_Mode10 {0} \
    CONFIG.DAC_Mixer_Mode11 {0} \
    CONFIG.DAC_Mixer_Mode12 {0} \
    CONFIG.DAC_Mixer_Mode13 {0} \
    CONFIG.DAC_Mixer_Mode30 {0} \
    CONFIG.DAC_Mixer_Mode31 {0} \
    CONFIG.DAC_Mixer_Mode32 {0} \
    CONFIG.DAC_Mixer_Mode33 {0} \
    CONFIG.DAC_Mixer_Type00 {1} \
    CONFIG.DAC_Mixer_Type01 {1} \
    CONFIG.DAC_Mixer_Type02 {1} \
    CONFIG.DAC_Mixer_Type03 {1} \
    CONFIG.DAC_Mixer_Type10 {2} \
    CONFIG.DAC_Mixer_Type11 {2} \
    CONFIG.DAC_Mixer_Type12 {2} \
    CONFIG.DAC_Mixer_Type13 {2} \
    CONFIG.DAC_Mixer_Type20 {2} \
    CONFIG.DAC_Mixer_Type21 {2} \
    CONFIG.DAC_Mixer_Type22 {2} \
    CONFIG.DAC_Mixer_Type23 {2} \
    CONFIG.DAC_Mixer_Type30 {2} \
    CONFIG.DAC_Mixer_Type31 {2} \
    CONFIG.DAC_Mixer_Type32 {2} \
    CONFIG.DAC_Mixer_Type33 {2} \
    CONFIG.DAC_Mode00 {3} \
    CONFIG.DAC_Mode01 {3} \
    CONFIG.DAC_Mode02 {3} \
    CONFIG.DAC_Mode03 {3} \
    CONFIG.DAC_Mode10 {0} \
    CONFIG.DAC_Mode12 {0} \
    CONFIG.DAC_Mode20 {0} \
    CONFIG.DAC_Mode21 {0} \
    CONFIG.DAC_Mode22 {0} \
    CONFIG.DAC_Mode23 {0} \
    CONFIG.DAC_Mode30 {0} \
    CONFIG.DAC_Mode31 {0} \
    CONFIG.DAC_Mode32 {0} \
    CONFIG.DAC_Slice00_Enable {true} \
    CONFIG.DAC_Slice01_Enable {true} \
    CONFIG.DAC_Slice02_Enable {true} \
    CONFIG.DAC_Slice03_Enable {true} \
    CONFIG.DAC_Slice10_Enable {true} \
    CONFIG.DAC_Slice11_Enable {true} \
    CONFIG.DAC_Slice12_Enable {true} \
    CONFIG.DAC_Slice13_Enable {true} \
    CONFIG.DAC_Slice20_Enable {true} \
    CONFIG.DAC_Slice21_Enable {true} \
    CONFIG.DAC_Slice22_Enable {true} \
    CONFIG.DAC_Slice23_Enable {true} \
    CONFIG.DAC_Slice30_Enable {true} \
    CONFIG.DAC_Slice31_Enable {true} \
    CONFIG.DAC_Slice32_Enable {true} \
    CONFIG.DAC_Slice33_Enable {true} \
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
    CONFIG.PSU__CRL_APB__PL1_REF_CTRL__ACT_FREQMHZ {2.000000} \
    CONFIG.PSU__CRL_APB__PL1_REF_CTRL__FREQMHZ {2} \
    CONFIG.PSU__CRL_APB__PL1_REF_CTRL__SRCSEL {RPLL} \
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
    CONFIG.PSU__PL_CLK1_BUF {TRUE} \
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

  # Create instance: rfb_control
  create_hier_cell_rfb_control [current_bd_instance .] rfb_control

  # Create instance: pmod_bits_gpio, and set properties
  set pmod_bits_gpio [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 pmod_bits_gpio ]
  set_property -dict [list \
    CONFIG.C_ALL_OUTPUTS {1} \
    CONFIG.C_GPIO_WIDTH {8} \
  ] $pmod_bits_gpio


  # Create instance: pmod_led_gpio, and set properties
  set pmod_led_gpio [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 pmod_led_gpio ]
  set_property -dict [list \
    CONFIG.C_ALL_OUTPUTS {1} \
    CONFIG.C_GPIO_WIDTH {8} \
  ] $pmod_led_gpio


  # Create instance: qick_vec2bit_led, and set properties
  set qick_vec2bit_led [ create_bd_cell -type ip -vlnv QICK:QICK:qick_vec2bit:1.0 qick_vec2bit_led ]
  set_property -dict [list \
    CONFIG.IN_DW {8} \
    CONFIG.OUT_QTY {8} \
  ] $qick_vec2bit_led


  # Create instance: qick_vec2bit_gpio, and set properties
  set qick_vec2bit_gpio [ create_bd_cell -type ip -vlnv QICK:QICK:qick_vec2bit:1.0 qick_vec2bit_gpio ]
  set_property -dict [list \
    CONFIG.IN_DW {8} \
    CONFIG.OUT_QTY {8} \
  ] $qick_vec2bit_gpio


  # Create instance: clk104_gpio, and set properties
  set clk104_gpio [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 clk104_gpio ]
  set_property -dict [list \
    CONFIG.C_ALL_OUTPUTS {1} \
    CONFIG.C_GPIO_WIDTH {2} \
  ] $clk104_gpio


  # Create instance: axis_broadcaster_10, and set properties
  set axis_broadcaster_10 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_broadcaster:1.1 axis_broadcaster_10 ]
  set_property CONFIG.HAS_TREADY {0} $axis_broadcaster_10


  # Create instance: axis_clk_cnvrt_avg_10, and set properties
  set axis_clk_cnvrt_avg_10 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_clock_converter:1.1 axis_clk_cnvrt_avg_10 ]

  # Create instance: axis_dyn_readout_v1_2, and set properties
  set axis_dyn_readout_v1_2 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_dyn_readout_v1:1.0 axis_dyn_readout_v1_2 ]

  # Create instance: sg_translator_18, and set properties
  set sg_translator_18 [ create_bd_cell -type ip -vlnv QICK:QICK:sg_translator:1.0 sg_translator_18 ]
  set_property CONFIG.OUT_TYPE {3} $sg_translator_18


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


  # Create instance: axis_avg_buffer_10, and set properties
  set axis_avg_buffer_10 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_avg_buffer:1.2 axis_avg_buffer_10 ]
  set_property -dict [list \
    CONFIG.N_AVG {13} \
    CONFIG.N_BUF {12} \
  ] $axis_avg_buffer_10


  # Create instance: axis_avg_buffer_2, and set properties
  set axis_avg_buffer_2 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_avg_buffer:1.2 axis_avg_buffer_2 ]
  set_property -dict [list \
    CONFIG.N_AVG {13} \
    CONFIG.N_BUF {10} \
  ] $axis_avg_buffer_2


  # Create instance: axis_avg_buffer_3, and set properties
  set axis_avg_buffer_3 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_avg_buffer:1.2 axis_avg_buffer_3 ]
  set_property -dict [list \
    CONFIG.N_AVG {13} \
    CONFIG.N_BUF {10} \
  ] $axis_avg_buffer_3


  # Create instance: axis_avg_buffer_4, and set properties
  set axis_avg_buffer_4 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_avg_buffer:1.2 axis_avg_buffer_4 ]
  set_property -dict [list \
    CONFIG.N_AVG {13} \
    CONFIG.N_BUF {10} \
  ] $axis_avg_buffer_4


  # Create instance: axis_avg_buffer_5, and set properties
  set axis_avg_buffer_5 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_avg_buffer:1.2 axis_avg_buffer_5 ]
  set_property -dict [list \
    CONFIG.N_AVG {13} \
    CONFIG.N_BUF {10} \
  ] $axis_avg_buffer_5


  # Create instance: axis_avg_buffer_6, and set properties
  set axis_avg_buffer_6 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_avg_buffer:1.2 axis_avg_buffer_6 ]
  set_property CONFIG.N_AVG {13} $axis_avg_buffer_6


  # Create instance: axis_avg_buffer_7, and set properties
  set axis_avg_buffer_7 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_avg_buffer:1.2 axis_avg_buffer_7 ]
  set_property CONFIG.N_AVG {13} $axis_avg_buffer_7


  # Create instance: axis_avg_buffer_8, and set properties
  set axis_avg_buffer_8 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_avg_buffer:1.2 axis_avg_buffer_8 ]
  set_property CONFIG.N_AVG {13} $axis_avg_buffer_8


  # Create instance: axis_avg_buffer_9, and set properties
  set axis_avg_buffer_9 [ create_bd_cell -type ip -vlnv QICK:QICK:axis_avg_buffer:1.2 axis_avg_buffer_9 ]
  set_property CONFIG.N_AVG {13} $axis_avg_buffer_9


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
    CONFIG.DEBUG {0} \
    CONFIG.DIVIDER {1} \
    CONFIG.DMEM_AW {14} \
    CONFIG.EXT_FLAG {0} \
    CONFIG.GEN_SYNC {0} \
    CONFIG.IN_PORT_QTY {8} \
    CONFIG.IO_CTRL {1} \
    CONFIG.LFSR {1} \
    CONFIG.OUT_DPORT_DW {8} \
    CONFIG.OUT_DPORT_QTY {1} \
    CONFIG.OUT_TRIG_QTY {19} \
    CONFIG.OUT_WPORT_QTY {16} \
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
  connect_bd_intf_net -intf_net axis_avg_buffer_10_m0_axis [get_bd_intf_pins axis_avg_buffer_10/m0_axis] [get_bd_intf_pins axis_switch_avg/S10_AXIS]
  connect_bd_intf_net -intf_net axis_avg_buffer_10_m1_axis [get_bd_intf_pins axis_avg_buffer_10/m1_axis] [get_bd_intf_pins axis_switch_buf/S10_AXIS]
  connect_bd_intf_net -intf_net axis_avg_buffer_10_m2_axis [get_bd_intf_pins axis_clk_cnvrt_avg_10/S_AXIS] [get_bd_intf_pins axis_avg_buffer_10/m2_axis]
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
  connect_bd_intf_net -intf_net axis_avg_buffer_7_m0_axis [get_bd_intf_pins axis_avg_buffer_7/m0_axis] [get_bd_intf_pins axis_switch_avg/S07_AXIS]
  connect_bd_intf_net -intf_net axis_avg_buffer_7_m1_axis [get_bd_intf_pins axis_avg_buffer_7/m1_axis] [get_bd_intf_pins axis_switch_buf/S07_AXIS]
  connect_bd_intf_net -intf_net axis_avg_buffer_7_m2_axis [get_bd_intf_pins axis_avg_buffer_7/m2_axis] [get_bd_intf_pins axis_clk_cnvrt_avg_7/S_AXIS]
  connect_bd_intf_net -intf_net axis_avg_buffer_8_m0_axis [get_bd_intf_pins axis_avg_buffer_8/m0_axis] [get_bd_intf_pins axis_switch_avg/S08_AXIS]
  connect_bd_intf_net -intf_net axis_avg_buffer_8_m1_axis [get_bd_intf_pins axis_avg_buffer_8/m1_axis] [get_bd_intf_pins axis_switch_buf/S08_AXIS]
  connect_bd_intf_net -intf_net axis_avg_buffer_8_m2_axis [get_bd_intf_pins axis_avg_buffer_8/m2_axis] [get_bd_intf_pins axis_clk_cnvrt_avg_8/S_AXIS]
  connect_bd_intf_net -intf_net axis_avg_buffer_9_m0_axis [get_bd_intf_pins axis_avg_buffer_9/m0_axis] [get_bd_intf_pins axis_switch_avg/S09_AXIS]
  connect_bd_intf_net -intf_net axis_avg_buffer_9_m1_axis [get_bd_intf_pins axis_avg_buffer_9/m1_axis] [get_bd_intf_pins axis_switch_buf/S09_AXIS]
  connect_bd_intf_net -intf_net axis_avg_buffer_9_m2_axis [get_bd_intf_pins axis_avg_buffer_9/m2_axis] [get_bd_intf_pins axis_clk_cnvrt_avg_9/S_AXIS]
  connect_bd_intf_net -intf_net axis_broadcaster_0_M00_AXIS [get_bd_intf_pins axis_avg_buffer_0/s_axis] [get_bd_intf_pins axis_broadcaster_0/M00_AXIS]
  connect_bd_intf_net -intf_net axis_broadcaster_0_M01_AXIS [get_bd_intf_pins axis_broadcaster_0/M01_AXIS] [get_bd_intf_pins axis_switch_ddr/S00_AXIS]
  connect_bd_intf_net -intf_net axis_broadcaster_10_M00_AXIS [get_bd_intf_pins axis_broadcaster_10/M00_AXIS] [get_bd_intf_pins axis_avg_buffer_10/s_axis]
  connect_bd_intf_net -intf_net axis_broadcaster_10_M01_AXIS [get_bd_intf_pins axis_broadcaster_10/M01_AXIS] [get_bd_intf_pins axis_switch_ddr/S10_AXIS]
  connect_bd_intf_net -intf_net axis_broadcaster_1_M00_AXIS [get_bd_intf_pins axis_avg_buffer_1/s_axis] [get_bd_intf_pins axis_broadcaster_1/M00_AXIS]
  connect_bd_intf_net -intf_net axis_broadcaster_1_M01_AXIS [get_bd_intf_pins axis_broadcaster_1/M01_AXIS] [get_bd_intf_pins axis_switch_ddr/S01_AXIS]
  connect_bd_intf_net -intf_net axis_broadcaster_2_M00_AXIS [get_bd_intf_pins axis_avg_buffer_2/s_axis] [get_bd_intf_pins axis_broadcaster_2/M00_AXIS]
  connect_bd_intf_net -intf_net axis_broadcaster_2_M01_AXIS [get_bd_intf_pins axis_broadcaster_2/M01_AXIS] [get_bd_intf_pins axis_switch_ddr/S02_AXIS]
  connect_bd_intf_net -intf_net axis_broadcaster_3_M00_AXIS [get_bd_intf_pins axis_avg_buffer_3/s_axis] [get_bd_intf_pins axis_broadcaster_3/M00_AXIS]
  connect_bd_intf_net -intf_net axis_broadcaster_3_M01_AXIS [get_bd_intf_pins axis_broadcaster_3/M01_AXIS] [get_bd_intf_pins axis_switch_ddr/S03_AXIS]
  connect_bd_intf_net -intf_net axis_broadcaster_4_M00_AXIS [get_bd_intf_pins axis_avg_buffer_4/s_axis] [get_bd_intf_pins axis_broadcaster_4/M00_AXIS]
  connect_bd_intf_net -intf_net axis_broadcaster_4_M01_AXIS [get_bd_intf_pins axis_broadcaster_4/M01_AXIS] [get_bd_intf_pins axis_switch_ddr/S04_AXIS]
  connect_bd_intf_net -intf_net axis_broadcaster_5_M00_AXIS [get_bd_intf_pins axis_avg_buffer_5/s_axis] [get_bd_intf_pins axis_broadcaster_5/M00_AXIS]
  connect_bd_intf_net -intf_net axis_broadcaster_5_M01_AXIS [get_bd_intf_pins axis_broadcaster_5/M01_AXIS] [get_bd_intf_pins axis_switch_ddr/S05_AXIS]
  connect_bd_intf_net -intf_net axis_broadcaster_6_M00_AXIS [get_bd_intf_pins axis_avg_buffer_6/s_axis] [get_bd_intf_pins axis_broadcaster_6/M00_AXIS]
  connect_bd_intf_net -intf_net axis_broadcaster_6_M01_AXIS [get_bd_intf_pins axis_broadcaster_6/M01_AXIS] [get_bd_intf_pins axis_switch_ddr/S06_AXIS]
  connect_bd_intf_net -intf_net axis_broadcaster_7_M00_AXIS [get_bd_intf_pins axis_avg_buffer_7/s_axis] [get_bd_intf_pins axis_broadcaster_7/M00_AXIS]
  connect_bd_intf_net -intf_net axis_broadcaster_7_M01_AXIS [get_bd_intf_pins axis_broadcaster_7/M01_AXIS] [get_bd_intf_pins axis_switch_ddr/S07_AXIS]
  connect_bd_intf_net -intf_net axis_broadcaster_8_M00_AXIS [get_bd_intf_pins axis_avg_buffer_8/s_axis] [get_bd_intf_pins axis_broadcaster_8/M00_AXIS]
  connect_bd_intf_net -intf_net axis_broadcaster_8_M01_AXIS [get_bd_intf_pins axis_broadcaster_8/M01_AXIS] [get_bd_intf_pins axis_switch_ddr/S08_AXIS]
  connect_bd_intf_net -intf_net axis_broadcaster_9_M00_AXIS [get_bd_intf_pins axis_avg_buffer_9/s_axis] [get_bd_intf_pins axis_broadcaster_9/M00_AXIS]
  connect_bd_intf_net -intf_net axis_broadcaster_9_M01_AXIS [get_bd_intf_pins axis_broadcaster_9/M01_AXIS] [get_bd_intf_pins axis_switch_ddr/S09_AXIS]
  connect_bd_intf_net -intf_net axis_cdcsync_v1_0_m0_axis [get_bd_intf_pins axis_cdcsync_v1_0/m0_axis] [get_bd_intf_pins sg_translator_0/s_tproc_axis]
  connect_bd_intf_net -intf_net axis_cdcsync_v1_0_m1_axis [get_bd_intf_pins axis_cdcsync_v1_0/m1_axis] [get_bd_intf_pins sg_translator_1/s_tproc_axis]
  connect_bd_intf_net -intf_net axis_cdcsync_v1_0_m2_axis [get_bd_intf_pins axis_cdcsync_v1_0/m2_axis] [get_bd_intf_pins sg_translator_2/s_tproc_axis]
  connect_bd_intf_net -intf_net axis_cdcsync_v1_0_m3_axis [get_bd_intf_pins axis_cdcsync_v1_0/m3_axis] [get_bd_intf_pins sg_translator_3/s_tproc_axis]
  connect_bd_intf_net -intf_net axis_cdcsync_v1_2_m0_axis [get_bd_intf_pins axis_cdcsync_v1_2/m0_axis] [get_bd_intf_pins sg_translator_16/s_tproc_axis]
  connect_bd_intf_net -intf_net axis_cdcsync_v1_2_m1_axis [get_bd_intf_pins axis_cdcsync_v1_2/m1_axis] [get_bd_intf_pins sg_translator_17/s_tproc_axis]
  connect_bd_intf_net -intf_net axis_cdcsync_v1_2_m2_axis [get_bd_intf_pins sg_translator_18/s_tproc_axis] [get_bd_intf_pins axis_cdcsync_v1_2/m2_axis]
  connect_bd_intf_net -intf_net axis_clk_cnvrt_avg_0_M_AXIS [get_bd_intf_pins axis_clk_cnvrt_avg_0/M_AXIS] [get_bd_intf_pins qick_processor_0/s0_axis]
  connect_bd_intf_net -intf_net axis_clk_cnvrt_avg_1_M_AXIS [get_bd_intf_pins axis_clk_cnvrt_avg_1/M_AXIS] [get_bd_intf_pins qick_processor_0/s1_axis]
  connect_bd_intf_net -intf_net axis_clk_cnvrt_avg_2_M_AXIS [get_bd_intf_pins axis_clk_cnvrt_avg_2/M_AXIS] [get_bd_intf_pins qick_processor_0/s2_axis]
  connect_bd_intf_net -intf_net axis_clk_cnvrt_avg_3_M_AXIS [get_bd_intf_pins axis_clk_cnvrt_avg_3/M_AXIS] [get_bd_intf_pins qick_processor_0/s3_axis]
  connect_bd_intf_net -intf_net axis_clk_cnvrt_avg_4_M_AXIS [get_bd_intf_pins axis_clk_cnvrt_avg_4/M_AXIS] [get_bd_intf_pins qick_processor_0/s4_axis]
  connect_bd_intf_net -intf_net axis_clk_cnvrt_avg_5_M_AXIS [get_bd_intf_pins axis_clk_cnvrt_avg_5/M_AXIS] [get_bd_intf_pins qick_processor_0/s5_axis]
  connect_bd_intf_net -intf_net axis_clk_cnvrt_avg_6_M_AXIS [get_bd_intf_pins axis_clk_cnvrt_avg_6/M_AXIS] [get_bd_intf_pins qick_processor_0/s6_axis]
  connect_bd_intf_net -intf_net axis_clk_cnvrt_avg_7_M_AXIS [get_bd_intf_pins axis_clk_cnvrt_avg_7/M_AXIS] [get_bd_intf_pins qick_processor_0/s7_axis]
  connect_bd_intf_net -intf_net axis_dyn_readout_v1_0_m0_axis [get_bd_intf_pins axis_dyn_readout_v1_0/m0_axis] [get_bd_intf_pins axis_switch_mr/S00_AXIS]
  connect_bd_intf_net -intf_net axis_dyn_readout_v1_0_m1_axis [get_bd_intf_pins axis_broadcaster_0/S_AXIS] [get_bd_intf_pins axis_dyn_readout_v1_0/m1_axis]
  connect_bd_intf_net -intf_net axis_dyn_readout_v1_1_m0_axis [get_bd_intf_pins axis_dyn_readout_v1_1/m0_axis] [get_bd_intf_pins axis_switch_mr/S01_AXIS]
  connect_bd_intf_net -intf_net axis_dyn_readout_v1_1_m1_axis [get_bd_intf_pins axis_broadcaster_1/S_AXIS] [get_bd_intf_pins axis_dyn_readout_v1_1/m1_axis]
  connect_bd_intf_net -intf_net axis_dyn_readout_v1_2_m0_axis [get_bd_intf_pins axis_dyn_readout_v1_2/m0_axis] [get_bd_intf_pins axis_switch_mr/S02_AXIS]
  connect_bd_intf_net -intf_net axis_dyn_readout_v1_2_m1_axis [get_bd_intf_pins axis_dyn_readout_v1_2/m1_axis] [get_bd_intf_pins axis_broadcaster_10/S_AXIS]
  connect_bd_intf_net -intf_net axis_pfb_readout_v4_0_m0_axis [get_bd_intf_pins axis_broadcaster_2/S_AXIS] [get_bd_intf_pins axis_pfb_readout_v4_0/m0_axis]
  connect_bd_intf_net -intf_net axis_pfb_readout_v4_0_m1_axis [get_bd_intf_pins axis_broadcaster_3/S_AXIS] [get_bd_intf_pins axis_pfb_readout_v4_0/m1_axis]
  connect_bd_intf_net -intf_net axis_pfb_readout_v4_0_m2_axis [get_bd_intf_pins axis_broadcaster_4/S_AXIS] [get_bd_intf_pins axis_pfb_readout_v4_0/m2_axis]
  connect_bd_intf_net -intf_net axis_pfb_readout_v4_0_m3_axis [get_bd_intf_pins axis_broadcaster_5/S_AXIS] [get_bd_intf_pins axis_pfb_readout_v4_0/m3_axis]
  connect_bd_intf_net -intf_net axis_pfb_readout_v4_0_m4_axis [get_bd_intf_pins axis_broadcaster_6/S_AXIS] [get_bd_intf_pins axis_pfb_readout_v4_0/m4_axis]
  connect_bd_intf_net -intf_net axis_pfb_readout_v4_0_m5_axis [get_bd_intf_pins axis_broadcaster_7/S_AXIS] [get_bd_intf_pins axis_pfb_readout_v4_0/m5_axis]
  connect_bd_intf_net -intf_net axis_pfb_readout_v4_0_m6_axis [get_bd_intf_pins axis_broadcaster_8/S_AXIS] [get_bd_intf_pins axis_pfb_readout_v4_0/m6_axis]
  connect_bd_intf_net -intf_net axis_pfb_readout_v4_0_m7_axis [get_bd_intf_pins axis_broadcaster_9/S_AXIS] [get_bd_intf_pins axis_pfb_readout_v4_0/m7_axis]
  connect_bd_intf_net -intf_net axis_register_slice_0_m_axis [get_bd_intf_pins axis_register_slice_0/m_axis] [get_bd_intf_pins usp_rf_data_converter_0/s00_axis]
  connect_bd_intf_net -intf_net axis_register_slice_1_m_axis [get_bd_intf_pins axis_register_slice_1/m_axis] [get_bd_intf_pins usp_rf_data_converter_0/s01_axis]
  connect_bd_intf_net -intf_net axis_register_slice_2_m_axis [get_bd_intf_pins axis_register_slice_2/m_axis] [get_bd_intf_pins usp_rf_data_converter_0/s02_axis]
  connect_bd_intf_net -intf_net axis_register_slice_3_m_axis [get_bd_intf_pins axis_register_slice_3/m_axis] [get_bd_intf_pins usp_rf_data_converter_0/s03_axis]
  connect_bd_intf_net -intf_net axis_register_slice_4_M_AXIS [get_bd_intf_pins axis_register_slice_4/M_AXIS] [get_bd_intf_pins axis_signal_gen_v6_0/s1_axis]
  connect_bd_intf_net -intf_net axis_register_slice_5_M_AXIS [get_bd_intf_pins axis_register_slice_5/M_AXIS] [get_bd_intf_pins axis_signal_gen_v6_1/s1_axis]
  connect_bd_intf_net -intf_net axis_register_slice_6_M_AXIS [get_bd_intf_pins axis_register_slice_6/M_AXIS] [get_bd_intf_pins axis_signal_gen_v6_2/s1_axis]
  connect_bd_intf_net -intf_net axis_register_slice_7_M_AXIS [get_bd_intf_pins axis_register_slice_7/M_AXIS] [get_bd_intf_pins axis_signal_gen_v6_3/s1_axis]
  connect_bd_intf_net -intf_net axis_sg_int4_v2_0_m_axis [get_bd_intf_pins usp_rf_data_converter_0/s11_axis] [get_bd_intf_pins axis_sg_int4_v2_0/m_axis]
  connect_bd_intf_net -intf_net axis_sg_int4_v2_10_m_axis [get_bd_intf_pins axis_sg_int4_v2_10/m_axis] [get_bd_intf_pins usp_rf_data_converter_0/s33_axis]
  connect_bd_intf_net -intf_net axis_sg_int4_v2_1_m_axis [get_bd_intf_pins axis_sg_int4_v2_1/m_axis] [get_bd_intf_pins usp_rf_data_converter_0/s12_axis]
  connect_bd_intf_net -intf_net axis_sg_int4_v2_2_m_axis [get_bd_intf_pins usp_rf_data_converter_0/s13_axis] [get_bd_intf_pins axis_sg_int4_v2_2/m_axis]
  connect_bd_intf_net -intf_net axis_sg_int4_v2_3_m_axis [get_bd_intf_pins axis_sg_int4_v2_3/m_axis] [get_bd_intf_pins usp_rf_data_converter_0/s20_axis]
  connect_bd_intf_net -intf_net axis_sg_int4_v2_4_m_axis [get_bd_intf_pins usp_rf_data_converter_0/s21_axis] [get_bd_intf_pins axis_sg_int4_v2_4/m_axis]
  connect_bd_intf_net -intf_net axis_sg_int4_v2_5_m_axis [get_bd_intf_pins axis_sg_int4_v2_5/m_axis] [get_bd_intf_pins usp_rf_data_converter_0/s22_axis]
  connect_bd_intf_net -intf_net axis_sg_int4_v2_6_m_axis [get_bd_intf_pins usp_rf_data_converter_0/s23_axis] [get_bd_intf_pins axis_sg_int4_v2_6/m_axis]
  connect_bd_intf_net -intf_net axis_sg_int4_v2_7_m_axis [get_bd_intf_pins axis_sg_int4_v2_7/m_axis] [get_bd_intf_pins usp_rf_data_converter_0/s30_axis]
  connect_bd_intf_net -intf_net axis_sg_int4_v2_8_m_axis [get_bd_intf_pins axis_sg_int4_v2_8/m_axis] [get_bd_intf_pins usp_rf_data_converter_0/s31_axis]
  connect_bd_intf_net -intf_net axis_sg_int4_v2_9_m_axis [get_bd_intf_pins axis_sg_int4_v2_9/m_axis] [get_bd_intf_pins usp_rf_data_converter_0/s32_axis]
  connect_bd_intf_net -intf_net axis_sg_mixmux8_v1_0_m_axis [get_bd_intf_pins axis_sg_mixmux8_v1_0/m_axis] [get_bd_intf_pins usp_rf_data_converter_0/s10_axis]
  connect_bd_intf_net -intf_net axis_signal_gen_v6_0_m_axis [get_bd_intf_pins axis_register_slice_0/s_axis] [get_bd_intf_pins axis_signal_gen_v6_0/m_axis]
  connect_bd_intf_net -intf_net axis_signal_gen_v6_1_m_axis [get_bd_intf_pins axis_register_slice_1/s_axis] [get_bd_intf_pins axis_signal_gen_v6_1/m_axis]
  connect_bd_intf_net -intf_net axis_signal_gen_v6_2_m_axis [get_bd_intf_pins axis_register_slice_2/s_axis] [get_bd_intf_pins axis_signal_gen_v6_2/m_axis]
  connect_bd_intf_net -intf_net axis_signal_gen_v6_3_m_axis [get_bd_intf_pins axis_register_slice_3/s_axis] [get_bd_intf_pins axis_signal_gen_v6_3/m_axis]
  connect_bd_intf_net -intf_net axis_switch_0_M00_AXIS [get_bd_intf_pins axis_signal_gen_v6_0/s0_axis] [get_bd_intf_pins axis_switch_gen/M00_AXIS]
  connect_bd_intf_net -intf_net axis_switch_avg_M00_AXIS [get_bd_intf_pins axi_dma_avg/S_AXIS_S2MM] [get_bd_intf_pins axis_switch_avg/M00_AXIS]
  connect_bd_intf_net -intf_net axis_switch_buf_M00_AXIS [get_bd_intf_pins axi_dma_buf/S_AXIS_S2MM] [get_bd_intf_pins axis_switch_buf/M00_AXIS]
  connect_bd_intf_net -intf_net axis_switch_ddr_M00_AXIS [get_bd_intf_pins ddr4/S_AXIS] [get_bd_intf_pins axis_switch_ddr/M00_AXIS]
  connect_bd_intf_net -intf_net axis_switch_gen_M01_AXIS [get_bd_intf_pins axis_signal_gen_v6_1/s0_axis] [get_bd_intf_pins axis_switch_gen/M01_AXIS]
  connect_bd_intf_net -intf_net axis_switch_gen_M02_AXIS [get_bd_intf_pins axis_signal_gen_v6_2/s0_axis] [get_bd_intf_pins axis_switch_gen/M02_AXIS]
  connect_bd_intf_net -intf_net axis_switch_gen_M03_AXIS [get_bd_intf_pins axis_signal_gen_v6_3/s0_axis] [get_bd_intf_pins axis_switch_gen/M03_AXIS]
  connect_bd_intf_net -intf_net axis_switch_gen_M04_AXIS [get_bd_intf_pins axis_sg_int4_v2_0/s0_axis] [get_bd_intf_pins axis_switch_gen/M04_AXIS]
  connect_bd_intf_net -intf_net axis_switch_gen_M05_AXIS [get_bd_intf_pins axis_sg_int4_v2_1/s0_axis] [get_bd_intf_pins axis_switch_gen/M05_AXIS]
  connect_bd_intf_net -intf_net axis_switch_gen_M06_AXIS [get_bd_intf_pins axis_sg_int4_v2_2/s0_axis] [get_bd_intf_pins axis_switch_gen/M06_AXIS]
  connect_bd_intf_net -intf_net axis_switch_gen_M07_AXIS [get_bd_intf_pins axis_sg_int4_v2_3/s0_axis] [get_bd_intf_pins axis_switch_gen/M07_AXIS]
  connect_bd_intf_net -intf_net axis_switch_gen_M08_AXIS [get_bd_intf_pins axis_sg_int4_v2_4/s0_axis] [get_bd_intf_pins axis_switch_gen/M08_AXIS]
  connect_bd_intf_net -intf_net axis_switch_gen_M09_AXIS [get_bd_intf_pins axis_sg_int4_v2_5/s0_axis] [get_bd_intf_pins axis_switch_gen/M09_AXIS]
  connect_bd_intf_net -intf_net axis_switch_gen_M10_AXIS [get_bd_intf_pins axis_sg_int4_v2_6/s0_axis] [get_bd_intf_pins axis_switch_gen/M10_AXIS]
  connect_bd_intf_net -intf_net axis_switch_gen_M11_AXIS [get_bd_intf_pins axis_sg_int4_v2_7/s0_axis] [get_bd_intf_pins axis_switch_gen/M11_AXIS]
  connect_bd_intf_net -intf_net axis_switch_gen_M12_AXIS [get_bd_intf_pins axis_sg_int4_v2_8/s0_axis] [get_bd_intf_pins axis_switch_gen/M12_AXIS]
  connect_bd_intf_net -intf_net axis_switch_gen_M13_AXIS [get_bd_intf_pins axis_sg_int4_v2_9/s0_axis] [get_bd_intf_pins axis_switch_gen/M13_AXIS]
  connect_bd_intf_net -intf_net axis_switch_gen_M14_AXIS [get_bd_intf_pins axis_sg_int4_v2_10/s0_axis] [get_bd_intf_pins axis_switch_gen/M14_AXIS]
  connect_bd_intf_net -intf_net axis_switch_mr_M00_AXIS [get_bd_intf_pins axis_switch_mr/M00_AXIS] [get_bd_intf_pins mr_buffer_et_0/s00_axis]
  connect_bd_intf_net -intf_net axis_tmux_v1_0_m0_axis [get_bd_intf_pins axis_tmux_v1_0/m0_axis] [get_bd_intf_pins sg_translator_4/s_tproc_axis]
  connect_bd_intf_net -intf_net axis_tmux_v1_0_m1_axis [get_bd_intf_pins axis_cdcsync_v1_2/s0_axis] [get_bd_intf_pins axis_tmux_v1_0/m1_axis]
  connect_bd_intf_net -intf_net axis_tmux_v1_0_m2_axis [get_bd_intf_pins axis_cdcsync_v1_2/s1_axis] [get_bd_intf_pins axis_tmux_v1_0/m2_axis]
  connect_bd_intf_net -intf_net axis_tmux_v1_0_m3_axis [get_bd_intf_pins axis_cdcsync_v1_2/s2_axis] [get_bd_intf_pins axis_tmux_v1_0/m3_axis]
  connect_bd_intf_net -intf_net dac2_clk_0_1 [get_bd_intf_ports dac2_clk_0] [get_bd_intf_pins usp_rf_data_converter_0/dac2_clk]
  connect_bd_intf_net -intf_net ddr4_0_C0_DDR4 [get_bd_intf_ports ddr4_sdram_c0] [get_bd_intf_pins ddr4/ddr4_sdram_c0]
  connect_bd_intf_net -intf_net default_sysclk_c0_300mhz_1 [get_bd_intf_ports default_sysclk_c0_300mhz] [get_bd_intf_pins ddr4/default_sysclk_c0_300mhz]
  connect_bd_intf_net -intf_net mr_buffer_et_0_m00_axis [get_bd_intf_pins axi_dma_mr/S_AXIS_S2MM] [get_bd_intf_pins mr_buffer_et_0/m00_axis]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M01_AXI [get_bd_intf_pins axis_avg_buffer_2/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M01_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M02_AXI [get_bd_intf_pins axis_signal_gen_v6_0/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M02_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M03_AXI [get_bd_intf_pins axis_avg_buffer_7/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M03_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M04_AXI [get_bd_intf_pins axis_sg_mixmux8_v1_0/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M04_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M05_AXI [get_bd_intf_pins axis_switch_mr/S_AXI_CTRL] [get_bd_intf_pins ps8_0_axi_periph/M05_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M06_AXI [get_bd_intf_pins axi_dma_gen/S_AXI_LITE] [get_bd_intf_pins ps8_0_axi_periph/M06_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M07_AXI [get_bd_intf_pins axis_switch_gen/S_AXI_CTRL] [get_bd_intf_pins ps8_0_axi_periph/M07_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M09_AXI [get_bd_intf_pins axis_avg_buffer_0/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M09_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M10_AXI [get_bd_intf_pins axis_avg_buffer_1/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M10_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M11_AXI [get_bd_intf_pins axis_avg_buffer_3/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M11_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M12_AXI [get_bd_intf_pins axis_avg_buffer_4/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M12_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M13_AXI [get_bd_intf_pins axis_avg_buffer_5/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M13_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M14_AXI [get_bd_intf_pins axis_avg_buffer_8/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M14_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M15_AXI [get_bd_intf_pins axis_avg_buffer_9/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M15_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M16_AXI [get_bd_intf_pins axis_avg_buffer_6/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M16_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M17_AXI [get_bd_intf_pins axis_switch_avg/S_AXI_CTRL] [get_bd_intf_pins ps8_0_axi_periph/M17_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M18_AXI [get_bd_intf_pins axis_switch_buf/S_AXI_CTRL] [get_bd_intf_pins ps8_0_axi_periph/M18_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M19_AXI [get_bd_intf_pins axi_dma_avg/S_AXI_LITE] [get_bd_intf_pins ps8_0_axi_periph/M19_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M20_AXI [get_bd_intf_pins axi_dma_buf/S_AXI_LITE] [get_bd_intf_pins ps8_0_axi_periph/M20_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M21_AXI [get_bd_intf_pins axi_dma_mr/S_AXI_LITE] [get_bd_intf_pins ps8_0_axi_periph/M21_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M22_AXI [get_bd_intf_pins ddr4/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M22_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M23_AXI [get_bd_intf_pins axis_switch_ddr/S_AXI_CTRL] [get_bd_intf_pins ps8_0_axi_periph/M23_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M24_AXI [get_bd_intf_pins axis_sg_int4_v2_0/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M24_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M25_AXI [get_bd_intf_pins mr_buffer_et_0/s00_axi] [get_bd_intf_pins ps8_0_axi_periph/M25_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M26_AXI [get_bd_intf_pins axi_intc_0/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M26_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M27_AXI [get_bd_intf_pins axis_sg_int4_v2_1/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M27_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M28_AXI [get_bd_intf_pins axis_pfb_readout_v4_0/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M28_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M29_AXI [get_bd_intf_pins axis_sg_int4_v2_2/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M29_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M30_AXI [get_bd_intf_pins axis_sg_int4_v2_3/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M30_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M31_AXI [get_bd_intf_pins axis_sg_int4_v2_4/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M31_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M32_AXI [get_bd_intf_pins ps8_0_axi_periph/M32_AXI] [get_bd_intf_pins qick_processor_0/s_axi]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M33_AXI [get_bd_intf_pins axis_sg_int4_v2_5/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M33_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M34_AXI [get_bd_intf_pins axis_sg_int4_v2_6/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M34_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M35_AXI [get_bd_intf_pins axis_sg_int4_v2_7/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M35_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M36_AXI [get_bd_intf_pins axis_sg_int4_v2_8/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M36_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M37_AXI [get_bd_intf_pins axis_sg_int4_v2_9/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M37_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M38_AXI [get_bd_intf_pins axis_sg_int4_v2_10/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M38_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M39_AXI [get_bd_intf_pins axis_signal_gen_v6_1/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M39_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M40_AXI [get_bd_intf_pins axis_signal_gen_v6_2/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M40_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M41_AXI [get_bd_intf_pins axis_signal_gen_v6_3/s_axi] [get_bd_intf_pins ps8_0_axi_periph/M41_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M42_AXI [get_bd_intf_pins ps8_0_axi_periph/M42_AXI] [get_bd_intf_pins pmod_bits_gpio/S_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M43_AXI [get_bd_intf_pins ps8_0_axi_periph/M43_AXI] [get_bd_intf_pins pmod_led_gpio/S_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M44_AXI [get_bd_intf_pins ps8_0_axi_periph/M44_AXI] [get_bd_intf_pins rfb_control/AXI_SPI_ATTN]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M45_AXI [get_bd_intf_pins ps8_0_axi_periph/M45_AXI] [get_bd_intf_pins rfb_control/AXI_GPIO_BIAS]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M46_AXI [get_bd_intf_pins ps8_0_axi_periph/M46_AXI] [get_bd_intf_pins rfb_control/AXI_SPI_BIAS]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M47_AXI [get_bd_intf_pins ps8_0_axi_periph/M47_AXI] [get_bd_intf_pins rfb_control/AXI_GPIO_BRDSEL]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M48_AXI [get_bd_intf_pins ps8_0_axi_periph/M48_AXI] [get_bd_intf_pins rfb_control/AXI_SPI_FILTER]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M49_AXI [get_bd_intf_pins ps8_0_axi_periph/M49_AXI] [get_bd_intf_pins clk104_gpio/S_AXI]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M50_AXI [get_bd_intf_pins ps8_0_axi_periph/M50_AXI] [get_bd_intf_pins axis_avg_buffer_10/s_axi]
  connect_bd_intf_net -intf_net qick_processor_0_m0_axis [get_bd_intf_pins axis_cdcsync_v1_0/s0_axis] [get_bd_intf_pins qick_processor_0/m0_axis]
  connect_bd_intf_net -intf_net qick_processor_0_m10_axis [get_bd_intf_pins qick_processor_0/m10_axis] [get_bd_intf_pins sg_translator_10/s_tproc_axis]
  connect_bd_intf_net -intf_net qick_processor_0_m11_axis [get_bd_intf_pins sg_translator_11/s_tproc_axis] [get_bd_intf_pins qick_processor_0/m11_axis]
  connect_bd_intf_net -intf_net qick_processor_0_m12_axis [get_bd_intf_pins qick_processor_0/m12_axis] [get_bd_intf_pins sg_translator_12/s_tproc_axis]
  connect_bd_intf_net -intf_net qick_processor_0_m13_axis [get_bd_intf_pins sg_translator_13/s_tproc_axis] [get_bd_intf_pins qick_processor_0/m13_axis]
  connect_bd_intf_net -intf_net qick_processor_0_m14_axis [get_bd_intf_pins sg_translator_14/s_tproc_axis] [get_bd_intf_pins qick_processor_0/m14_axis]
  connect_bd_intf_net -intf_net qick_processor_0_m15_axis [get_bd_intf_pins sg_translator_15/s_tproc_axis] [get_bd_intf_pins qick_processor_0/m15_axis]
  connect_bd_intf_net -intf_net qick_processor_0_m1_axis [get_bd_intf_pins axis_cdcsync_v1_0/s1_axis] [get_bd_intf_pins qick_processor_0/m1_axis]
  connect_bd_intf_net -intf_net qick_processor_0_m2_axis [get_bd_intf_pins axis_cdcsync_v1_0/s2_axis] [get_bd_intf_pins qick_processor_0/m2_axis]
  connect_bd_intf_net -intf_net qick_processor_0_m3_axis [get_bd_intf_pins axis_cdcsync_v1_0/s3_axis] [get_bd_intf_pins qick_processor_0/m3_axis]
  connect_bd_intf_net -intf_net qick_processor_0_m4_axis [get_bd_intf_pins axis_tmux_v1_0/s_axis] [get_bd_intf_pins qick_processor_0/m4_axis]
  connect_bd_intf_net -intf_net qick_processor_0_m5_axis [get_bd_intf_pins qick_processor_0/m5_axis] [get_bd_intf_pins sg_translator_5/s_tproc_axis]
  connect_bd_intf_net -intf_net qick_processor_0_m6_axis [get_bd_intf_pins sg_translator_6/s_tproc_axis] [get_bd_intf_pins qick_processor_0/m6_axis]
  connect_bd_intf_net -intf_net qick_processor_0_m7_axis [get_bd_intf_pins qick_processor_0/m7_axis] [get_bd_intf_pins sg_translator_7/s_tproc_axis]
  connect_bd_intf_net -intf_net qick_processor_0_m8_axis [get_bd_intf_pins qick_processor_0/m8_axis] [get_bd_intf_pins sg_translator_8/s_tproc_axis]
  connect_bd_intf_net -intf_net qick_processor_0_m9_axis [get_bd_intf_pins sg_translator_9/s_tproc_axis] [get_bd_intf_pins qick_processor_0/m9_axis]
  connect_bd_intf_net -intf_net qick_processor_0_m_dma_axis_o [get_bd_intf_pins axi_dma_tproc/S_AXIS_S2MM] [get_bd_intf_pins qick_processor_0/m_dma_axis_o]
  connect_bd_intf_net -intf_net sg_translator_0_m_gen_v6_axis [get_bd_intf_pins sg_translator_0/m_gen_v6_axis] [get_bd_intf_pins axis_register_slice_4/S_AXIS]
  connect_bd_intf_net -intf_net sg_translator_10_m_gen_v6_axis [get_bd_intf_pins axis_sg_int4_v2_6/s1_axis] [get_bd_intf_pins sg_translator_11/m_gen_v6_axis]
  connect_bd_intf_net -intf_net sg_translator_11_m_gen_v6_axis [get_bd_intf_pins axis_sg_int4_v2_7/s1_axis] [get_bd_intf_pins sg_translator_12/m_gen_v6_axis]
  connect_bd_intf_net -intf_net sg_translator_12_m_mux4_axis [get_bd_intf_pins axis_sg_mixmux8_v1_0/s_axis] [get_bd_intf_pins sg_translator_4/m_mux4_axis]
  connect_bd_intf_net -intf_net sg_translator_13_m_gen_v6_axis [get_bd_intf_pins axis_sg_int4_v2_8/s1_axis] [get_bd_intf_pins sg_translator_13/m_gen_v6_axis]
  connect_bd_intf_net -intf_net sg_translator_14_m_gen_v6_axis [get_bd_intf_pins axis_sg_int4_v2_9/s1_axis] [get_bd_intf_pins sg_translator_14/m_gen_v6_axis]
  connect_bd_intf_net -intf_net sg_translator_15_m_gen_v6_axis [get_bd_intf_pins axis_sg_int4_v2_10/s1_axis] [get_bd_intf_pins sg_translator_15/m_gen_v6_axis]
  connect_bd_intf_net -intf_net sg_translator_18_m_readout_v3_axis [get_bd_intf_pins axis_dyn_readout_v1_2/s0_axis] [get_bd_intf_pins sg_translator_18/m_readout_v3_axis]
  connect_bd_intf_net -intf_net sg_translator_1_m_gen_v6_axis [get_bd_intf_pins sg_translator_1/m_gen_v6_axis] [get_bd_intf_pins axis_register_slice_5/S_AXIS]
  connect_bd_intf_net -intf_net sg_translator_2_m_gen_v6_axis [get_bd_intf_pins sg_translator_2/m_gen_v6_axis] [get_bd_intf_pins axis_register_slice_6/S_AXIS]
  connect_bd_intf_net -intf_net sg_translator_3_m_gen_v6_axis [get_bd_intf_pins sg_translator_3/m_gen_v6_axis] [get_bd_intf_pins axis_register_slice_7/S_AXIS]
  connect_bd_intf_net -intf_net sg_translator_4_m_gen_v6_axis [get_bd_intf_pins axis_sg_int4_v2_0/s1_axis] [get_bd_intf_pins sg_translator_5/m_gen_v6_axis]
  connect_bd_intf_net -intf_net sg_translator_5_m_gen_v6_axis [get_bd_intf_pins axis_sg_int4_v2_1/s1_axis] [get_bd_intf_pins sg_translator_6/m_gen_v6_axis]
  connect_bd_intf_net -intf_net sg_translator_6_m_gen_v6_axis [get_bd_intf_pins axis_sg_int4_v2_2/s1_axis] [get_bd_intf_pins sg_translator_7/m_gen_v6_axis]
  connect_bd_intf_net -intf_net sg_translator_6_m_readout_v3_axis [get_bd_intf_pins axis_dyn_readout_v1_0/s0_axis] [get_bd_intf_pins sg_translator_16/m_readout_v3_axis]
  connect_bd_intf_net -intf_net sg_translator_7_m_gen_v6_axis [get_bd_intf_pins axis_sg_int4_v2_3/s1_axis] [get_bd_intf_pins sg_translator_8/m_gen_v6_axis]
  connect_bd_intf_net -intf_net sg_translator_7_m_readout_v3_axis [get_bd_intf_pins axis_dyn_readout_v1_1/s0_axis] [get_bd_intf_pins sg_translator_17/m_readout_v3_axis]
  connect_bd_intf_net -intf_net sg_translator_8_m_gen_v6_axis [get_bd_intf_pins axis_sg_int4_v2_4/s1_axis] [get_bd_intf_pins sg_translator_9/m_gen_v6_axis]
  connect_bd_intf_net -intf_net sg_translator_9_m_gen_v6_axis [get_bd_intf_pins axis_sg_int4_v2_5/s1_axis] [get_bd_intf_pins sg_translator_10/m_gen_v6_axis]
  connect_bd_intf_net -intf_net smartconnect_0_M00_AXI [get_bd_intf_pins axi_smc/M00_AXI] [get_bd_intf_pins zynq_ultra_ps_e_0/S_AXI_HPC0_FPD]
  connect_bd_intf_net -intf_net sysref_in_0_1 [get_bd_intf_ports sysref_in_0] [get_bd_intf_pins usp_rf_data_converter_0/sysref_in]
  connect_bd_intf_net -intf_net usp_rf_data_converter_0_m10_axis [get_bd_intf_pins axis_dyn_readout_v1_2/s1_axis] [get_bd_intf_pins usp_rf_data_converter_0/m10_axis]
  connect_bd_intf_net -intf_net usp_rf_data_converter_0_m20_axis [get_bd_intf_pins axis_dyn_readout_v1_0/s1_axis] [get_bd_intf_pins usp_rf_data_converter_0/m20_axis]
  connect_bd_intf_net -intf_net usp_rf_data_converter_0_m21_axis [get_bd_intf_pins axis_pfb_readout_v4_0/s_axis] [get_bd_intf_pins usp_rf_data_converter_0/m21_axis]
  connect_bd_intf_net -intf_net usp_rf_data_converter_0_m22_axis [get_bd_intf_pins axis_dyn_readout_v1_1/s1_axis] [get_bd_intf_pins usp_rf_data_converter_0/m22_axis]
  connect_bd_intf_net -intf_net usp_rf_data_converter_0_vout00 [get_bd_intf_ports vout0] [get_bd_intf_pins usp_rf_data_converter_0/vout00]
  connect_bd_intf_net -intf_net usp_rf_data_converter_0_vout01 [get_bd_intf_ports vout1] [get_bd_intf_pins usp_rf_data_converter_0/vout01]
  connect_bd_intf_net -intf_net usp_rf_data_converter_0_vout02 [get_bd_intf_ports vout2] [get_bd_intf_pins usp_rf_data_converter_0/vout02]
  connect_bd_intf_net -intf_net usp_rf_data_converter_0_vout03 [get_bd_intf_ports vout3] [get_bd_intf_pins usp_rf_data_converter_0/vout03]
  connect_bd_intf_net -intf_net usp_rf_data_converter_0_vout10 [get_bd_intf_ports vout4] [get_bd_intf_pins usp_rf_data_converter_0/vout10]
  connect_bd_intf_net -intf_net usp_rf_data_converter_0_vout11 [get_bd_intf_ports vout5] [get_bd_intf_pins usp_rf_data_converter_0/vout11]
  connect_bd_intf_net -intf_net usp_rf_data_converter_0_vout12 [get_bd_intf_ports vout6] [get_bd_intf_pins usp_rf_data_converter_0/vout12]
  connect_bd_intf_net -intf_net usp_rf_data_converter_0_vout13 [get_bd_intf_ports vout7] [get_bd_intf_pins usp_rf_data_converter_0/vout13]
  connect_bd_intf_net -intf_net usp_rf_data_converter_0_vout20 [get_bd_intf_ports vout8] [get_bd_intf_pins usp_rf_data_converter_0/vout20]
  connect_bd_intf_net -intf_net usp_rf_data_converter_0_vout21 [get_bd_intf_ports vout9] [get_bd_intf_pins usp_rf_data_converter_0/vout21]
  connect_bd_intf_net -intf_net usp_rf_data_converter_0_vout22 [get_bd_intf_ports vout10] [get_bd_intf_pins usp_rf_data_converter_0/vout22]
  connect_bd_intf_net -intf_net usp_rf_data_converter_0_vout23 [get_bd_intf_ports vout11] [get_bd_intf_pins usp_rf_data_converter_0/vout23]
  connect_bd_intf_net -intf_net usp_rf_data_converter_0_vout30 [get_bd_intf_ports vout12] [get_bd_intf_pins usp_rf_data_converter_0/vout30]
  connect_bd_intf_net -intf_net usp_rf_data_converter_0_vout31 [get_bd_intf_ports vout13] [get_bd_intf_pins usp_rf_data_converter_0/vout31]
  connect_bd_intf_net -intf_net usp_rf_data_converter_0_vout32 [get_bd_intf_ports vout14] [get_bd_intf_pins usp_rf_data_converter_0/vout32]
  connect_bd_intf_net -intf_net usp_rf_data_converter_0_vout33 [get_bd_intf_ports vout15] [get_bd_intf_pins usp_rf_data_converter_0/vout33]
  connect_bd_intf_net -intf_net vin10_0_1 [get_bd_intf_ports vin10_0] [get_bd_intf_pins usp_rf_data_converter_0/vin10]
  connect_bd_intf_net -intf_net vin20_0_1 [get_bd_intf_ports vin20_0] [get_bd_intf_pins usp_rf_data_converter_0/vin20]
  connect_bd_intf_net -intf_net vin21_0_1 [get_bd_intf_ports vin21_0] [get_bd_intf_pins usp_rf_data_converter_0/vin21]
  connect_bd_intf_net -intf_net vin22_0_1 [get_bd_intf_ports vin22_0] [get_bd_intf_pins usp_rf_data_converter_0/vin22]
  connect_bd_intf_net -intf_net zynq_ultra_ps_e_0_M_AXI_HPM0_FPD [get_bd_intf_pins ps8_0_axi_periph/S00_AXI] [get_bd_intf_pins zynq_ultra_ps_e_0/M_AXI_HPM0_FPD]
  connect_bd_intf_net -intf_net zynq_ultra_ps_e_0_M_AXI_HPM1_FPD [get_bd_intf_pins ddr4/S00_AXI] [get_bd_intf_pins zynq_ultra_ps_e_0/M_AXI_HPM1_FPD]

  # Create port connections
  connect_bd_net -net DAC_1V8_BIAS_SDO_1 [get_bd_ports DAC_1V8_BIAS_SDO] [get_bd_pins rfb_control/DAC_1V8_BIAS_SDO]
  connect_bd_net -net DB_1V8_SDO_1 [get_bd_ports DB_1V8_SDO] [get_bd_pins rfb_control/DB_1V8_SDO]
  connect_bd_net -net axi_dma_avg_s2mm_introut [get_bd_pins axi_dma_avg/s2mm_introut] [get_bd_pins xlconcat_intc/In0]
  connect_bd_net -net axi_dma_buf_s2mm_introut [get_bd_pins axi_dma_buf/s2mm_introut] [get_bd_pins xlconcat_intc/In1]
  connect_bd_net -net axi_dma_gen_mm2s_introut [get_bd_pins axi_dma_gen/mm2s_introut] [get_bd_pins xlconcat_intc/In3]
  connect_bd_net -net axi_dma_mr_s2mm_introut [get_bd_pins axi_dma_mr/s2mm_introut] [get_bd_pins xlconcat_intc/In2]
  connect_bd_net -net axi_dma_tproc_mm2s_introut [get_bd_pins axi_dma_tproc/mm2s_introut] [get_bd_pins xlconcat_intc/In4]
  connect_bd_net -net axi_dma_tproc_s2mm_introut [get_bd_pins axi_dma_tproc/s2mm_introut] [get_bd_pins xlconcat_intc/In5]
  connect_bd_net -net axi_gpio_0_gpio_io_o [get_bd_pins clk104_gpio/gpio_io_o] [get_bd_ports CLK104_CLK_SPI_MUX_SEL_LS]
  connect_bd_net -net axi_intc_0_irq [get_bd_pins axi_intc_0/irq] [get_bd_pins zynq_ultra_ps_e_0/pl_ps_irq0]
  connect_bd_net -net clk_core_clk_out1 [get_bd_pins clk_core/clk_out1] [get_bd_pins rst_core/slowest_sync_clk] [get_bd_pins axis_clk_cnvrt_avg_0/m_axis_aclk] [get_bd_pins axis_clk_cnvrt_avg_1/m_axis_aclk] [get_bd_pins axis_clk_cnvrt_avg_2/m_axis_aclk] [get_bd_pins axis_clk_cnvrt_avg_3/m_axis_aclk] [get_bd_pins axis_clk_cnvrt_avg_4/m_axis_aclk] [get_bd_pins axis_clk_cnvrt_avg_5/m_axis_aclk] [get_bd_pins axis_clk_cnvrt_avg_6/m_axis_aclk] [get_bd_pins axis_clk_cnvrt_avg_7/m_axis_aclk] [get_bd_pins axis_clk_cnvrt_avg_8/m_axis_aclk] [get_bd_pins axis_clk_cnvrt_avg_9/m_axis_aclk] [get_bd_pins axis_clk_cnvrt_avg_10/m_axis_aclk] [get_bd_pins qick_processor_0/c_clk_i]
  connect_bd_net -net clk_core_locked [get_bd_pins clk_core/locked] [get_bd_pins rst_core/dcm_locked]
  connect_bd_net -net ddr4_0_c0_ddr4_ui_clk [get_bd_pins ddr4/c0_ddr4_ui_clk] [get_bd_pins zynq_ultra_ps_e_0/maxihpm1_fpd_aclk]
  connect_bd_net -net pmod_bits_gpio_gpio_io_o [get_bd_pins pmod_bits_gpio/gpio_io_o] [get_bd_pins qick_vec2bit_gpio/din]
  connect_bd_net -net pmod_led_gpio_gpio_io_o [get_bd_pins pmod_led_gpio/gpio_io_o] [get_bd_pins qick_vec2bit_led/din]
  connect_bd_net -net qick_processor_0_trig_0_o [get_bd_pins qick_processor_0/trig_0_o] [get_bd_ports SPARE0_1V8]
  connect_bd_net -net qick_processor_0_trig_10_o [get_bd_pins qick_processor_0/trig_10_o] [get_bd_pins axis_avg_buffer_0/trigger]
  connect_bd_net -net qick_processor_0_trig_11_o [get_bd_pins qick_processor_0/trig_11_o] [get_bd_pins axis_avg_buffer_1/trigger]
  connect_bd_net -net qick_processor_0_trig_12_o [get_bd_pins qick_processor_0/trig_12_o] [get_bd_pins axis_avg_buffer_2/trigger]
  connect_bd_net -net qick_processor_0_trig_13_o [get_bd_pins qick_processor_0/trig_13_o] [get_bd_pins axis_avg_buffer_3/trigger]
  connect_bd_net -net qick_processor_0_trig_14_o [get_bd_pins qick_processor_0/trig_14_o] [get_bd_pins axis_avg_buffer_4/trigger]
  connect_bd_net -net qick_processor_0_trig_15_o [get_bd_pins qick_processor_0/trig_15_o] [get_bd_pins axis_avg_buffer_5/trigger]
  connect_bd_net -net qick_processor_0_trig_16_o [get_bd_pins qick_processor_0/trig_16_o] [get_bd_pins axis_avg_buffer_6/trigger]
  connect_bd_net -net qick_processor_0_trig_17_o [get_bd_pins qick_processor_0/trig_17_o] [get_bd_pins axis_avg_buffer_7/trigger]
  connect_bd_net -net qick_processor_0_trig_18_o [get_bd_pins qick_processor_0/trig_18_o] [get_bd_pins axis_avg_buffer_10/trigger]
  connect_bd_net -net qick_processor_0_trig_1_o [get_bd_pins qick_processor_0/trig_1_o] [get_bd_ports SPARE1_1V8]
  connect_bd_net -net qick_processor_0_trig_2_o [get_bd_pins qick_processor_0/trig_2_o] [get_bd_ports SPARE2_1V8]
  connect_bd_net -net qick_processor_0_trig_3_o [get_bd_pins qick_processor_0/trig_3_o] [get_bd_ports SPARE3_1V8]
  connect_bd_net -net qick_processor_0_trig_4_o [get_bd_pins qick_processor_0/trig_4_o] [get_bd_ports SPARE4_1V8]
  connect_bd_net -net qick_processor_0_trig_5_o [get_bd_pins qick_processor_0/trig_5_o] [get_bd_ports SPARE5_1V8]
  connect_bd_net -net qick_processor_0_trig_6_o [get_bd_pins qick_processor_0/trig_6_o] [get_bd_pins axis_avg_buffer_8/trigger]
  connect_bd_net -net qick_processor_0_trig_7_o [get_bd_pins qick_processor_0/trig_7_o] [get_bd_pins axis_avg_buffer_9/trigger]
  connect_bd_net -net qick_processor_0_trig_8_o [get_bd_pins qick_processor_0/trig_8_o] [get_bd_pins mr_buffer_et_0/trigger]
  connect_bd_net -net qick_processor_0_trig_9_o [get_bd_pins qick_processor_0/trig_9_o] [get_bd_pins ddr4/trigger]
  connect_bd_net -net qick_vec2bit_gpio_dout0 [get_bd_pins qick_vec2bit_gpio/dout0] [get_bd_ports PMOD_IO_0]
  connect_bd_net -net qick_vec2bit_gpio_dout1 [get_bd_pins qick_vec2bit_gpio/dout1] [get_bd_ports PMOD_IO_1]
  connect_bd_net -net qick_vec2bit_gpio_dout2 [get_bd_pins qick_vec2bit_gpio/dout2] [get_bd_ports PMOD_IO_2]
  connect_bd_net -net qick_vec2bit_gpio_dout3 [get_bd_pins qick_vec2bit_gpio/dout3] [get_bd_ports PMOD_IO_3]
  connect_bd_net -net qick_vec2bit_gpio_dout4 [get_bd_pins qick_vec2bit_gpio/dout4] [get_bd_ports PMOD_IO_4]
  connect_bd_net -net qick_vec2bit_gpio_dout5 [get_bd_pins qick_vec2bit_gpio/dout5] [get_bd_ports PMOD_IO_5]
  connect_bd_net -net qick_vec2bit_gpio_dout6 [get_bd_pins qick_vec2bit_gpio/dout6] [get_bd_ports PMOD_IO_6]
  connect_bd_net -net qick_vec2bit_gpio_dout7 [get_bd_pins qick_vec2bit_gpio/dout7] [get_bd_ports PMOD_IO_7]
  connect_bd_net -net qick_vec2bit_led_dout0 [get_bd_pins qick_vec2bit_led/dout0] [get_bd_ports PMOD_LED0]
  connect_bd_net -net qick_vec2bit_led_dout1 [get_bd_pins qick_vec2bit_led/dout1] [get_bd_ports PMOD_LED1]
  connect_bd_net -net qick_vec2bit_led_dout2 [get_bd_pins qick_vec2bit_led/dout2] [get_bd_ports PMOD_LED2]
  connect_bd_net -net qick_vec2bit_led_dout3 [get_bd_pins qick_vec2bit_led/dout3] [get_bd_ports PMOD_LED3]
  connect_bd_net -net qick_vec2bit_led_dout4 [get_bd_pins qick_vec2bit_led/dout4] [get_bd_ports PMOD_LED4]
  connect_bd_net -net qick_vec2bit_led_dout5 [get_bd_pins qick_vec2bit_led/dout5] [get_bd_ports PMOD_LED5]
  connect_bd_net -net qick_vec2bit_led_dout6 [get_bd_pins qick_vec2bit_led/dout6] [get_bd_ports PMOD_LED6]
  connect_bd_net -net qick_vec2bit_led_dout7 [get_bd_pins qick_vec2bit_led/dout7] [get_bd_ports PMOD_LED7]
  connect_bd_net -net rfb_control_DAC_1V8_BIAS_CLRn [get_bd_pins rfb_control/DAC_1V8_BIAS_CLRn] [get_bd_ports DAC_1V8_BIAS_CLRn]
  connect_bd_net -net rfb_control_DAC_1V8_BIAS_S0 [get_bd_pins rfb_control/DAC_1V8_BIAS_S0] [get_bd_ports DAC_1V8_BIAS_S0]
  connect_bd_net -net rfb_control_DAC_1V8_BIAS_S1 [get_bd_pins rfb_control/DAC_1V8_BIAS_S1] [get_bd_ports DAC_1V8_BIAS_S1]
  connect_bd_net -net rfb_control_DAC_1V8_BIAS_S2 [get_bd_pins rfb_control/DAC_1V8_BIAS_S2] [get_bd_ports DAC_1V8_BIAS_S2]
  connect_bd_net -net rfb_control_DAC_1V8_BIAS_SCLK [get_bd_pins rfb_control/DAC_1V8_BIAS_SCLK] [get_bd_ports DAC_1V8_BIAS_SCLK]
  connect_bd_net -net rfb_control_DAC_1V8_BIAS_SDIN [get_bd_pins rfb_control/DAC_1V8_BIAS_SDIN] [get_bd_ports DAC_1V8_BIAS_SDIN]
  connect_bd_net -net rfb_control_DAC_1V8_BIAS_SWEN [get_bd_pins rfb_control/DAC_1V8_BIAS_SWEN] [get_bd_ports DAC_1V8_BIAS_SWEN]
  connect_bd_net -net rfb_control_DAC_1V8_BIAS_SYNCn [get_bd_pins rfb_control/DAC_1V8_BIAS_SYNCn] [get_bd_ports DAC_1V8_BIAS_SYNCn]
  connect_bd_net -net rfb_control_DB_1V8_BRD_SEL [get_bd_pins rfb_control/DB_1V8_BRD_SEL] [get_bd_ports DB_1V8_BRD_SEL]
  connect_bd_net -net rfb_control_DB_1V8_BRD_SEL_SEL0 [get_bd_pins rfb_control/DB_1V8_BRD_SEL_SEL0] [get_bd_ports DB_1V8_BRD_SEL_SEL0]
  connect_bd_net -net rfb_control_DB_1V8_BRD_SEL_SEL1 [get_bd_pins rfb_control/DB_1V8_BRD_SEL_SEL1] [get_bd_ports DB_1V8_BRD_SEL_SEL1]
  connect_bd_net -net rfb_control_DB_1V8_BRD_SEL_SEL2 [get_bd_pins rfb_control/DB_1V8_BRD_SEL_SEL2] [get_bd_ports DB_1V8_BRD_SEL_SEL2]
  connect_bd_net -net rfb_control_DB_1V8_CSn [get_bd_pins rfb_control/DB_1V8_CSn] [get_bd_ports DB_1V8_CSn]
  connect_bd_net -net rfb_control_DB_1V8_PE_CLK [get_bd_pins rfb_control/DB_1V8_PE_CLK] [get_bd_ports DB_1V8_PE_CLK]
  connect_bd_net -net rfb_control_DB_1V8_PE_LE [get_bd_pins rfb_control/DB_1V8_PE_LE] [get_bd_ports DB_1V8_PE_LE]
  connect_bd_net -net rfb_control_DB_1V8_PE_SI [get_bd_pins rfb_control/DB_1V8_PE_SI] [get_bd_ports DB_1V8_PE_SI]
  connect_bd_net -net rfb_control_DB_1V8_SDI [get_bd_pins rfb_control/DB_1V8_SDI] [get_bd_ports DB_1V8_SDI]
  connect_bd_net -net rfb_control_DB_1V8_SEL0 [get_bd_pins rfb_control/DB_1V8_SEL0] [get_bd_ports DB_1V8_SEL0]
  connect_bd_net -net rfb_control_DB_1V8_SEL1 [get_bd_pins rfb_control/DB_1V8_SEL1] [get_bd_ports DB_1V8_SEL1]
  connect_bd_net -net rfb_control_DB_1V8_SEL2 [get_bd_pins rfb_control/DB_1V8_SEL2] [get_bd_ports DB_1V8_SEL2]
  connect_bd_net -net rfb_control_DB_1V8_SER_CLK [get_bd_pins rfb_control/DB_1V8_SER_CLK] [get_bd_ports DB_1V8_SER_CLK]
  connect_bd_net -net rst_100_bus_struct_reset [get_bd_pins rst_100/bus_struct_reset] [get_bd_pins ddr4/sys_rst]
  connect_bd_net -net rst_100_peripheral_reset [get_bd_pins rst_100/peripheral_reset] [get_bd_pins rst_core/ext_reset_in]
  connect_bd_net -net rst_adc_peripheral_aresetn [get_bd_pins rst_adc2/peripheral_aresetn] [get_bd_pins axis_cdcsync_v1_2/m_axis_aresetn] [get_bd_pins sg_translator_16/aresetn] [get_bd_pins sg_translator_17/aresetn] [get_bd_pins axis_broadcaster_0/aresetn] [get_bd_pins axis_broadcaster_1/aresetn] [get_bd_pins axis_broadcaster_2/aresetn] [get_bd_pins axis_broadcaster_3/aresetn] [get_bd_pins axis_broadcaster_4/aresetn] [get_bd_pins axis_broadcaster_5/aresetn] [get_bd_pins axis_broadcaster_6/aresetn] [get_bd_pins axis_broadcaster_7/aresetn] [get_bd_pins axis_broadcaster_8/aresetn] [get_bd_pins axis_broadcaster_9/aresetn] [get_bd_pins axis_dyn_readout_v1_0/aresetn] [get_bd_pins axis_dyn_readout_v1_1/aresetn] [get_bd_pins axis_pfb_readout_v4_0/aresetn] [get_bd_pins axis_switch_ddr/aresetn] [get_bd_pins axis_switch_mr/aresetn] [get_bd_pins usp_rf_data_converter_0/m2_axis_aresetn] [get_bd_pins ddr4/aresetn] [get_bd_pins usp_rf_data_converter_0/m1_axis_aresetn] [get_bd_pins axis_dyn_readout_v1_2/aresetn] [get_bd_pins sg_translator_18/aresetn] [get_bd_pins axis_broadcaster_10/aresetn] [get_bd_pins axis_avg_buffer_0/s_axis_aresetn] [get_bd_pins axis_avg_buffer_1/s_axis_aresetn] [get_bd_pins axis_avg_buffer_10/s_axis_aresetn] [get_bd_pins axis_avg_buffer_2/s_axis_aresetn] [get_bd_pins axis_avg_buffer_3/s_axis_aresetn] [get_bd_pins axis_avg_buffer_4/s_axis_aresetn] [get_bd_pins axis_avg_buffer_5/s_axis_aresetn] [get_bd_pins axis_avg_buffer_6/s_axis_aresetn] [get_bd_pins axis_avg_buffer_7/s_axis_aresetn] [get_bd_pins axis_avg_buffer_8/s_axis_aresetn] [get_bd_pins axis_avg_buffer_9/s_axis_aresetn] [get_bd_pins mr_buffer_et_0/s00_axis_aresetn]
  connect_bd_net -net rst_core_peripheral_aresetn [get_bd_pins rst_core/peripheral_aresetn] [get_bd_pins axis_clk_cnvrt_avg_0/m_axis_aresetn] [get_bd_pins axis_clk_cnvrt_avg_1/m_axis_aresetn] [get_bd_pins axis_clk_cnvrt_avg_2/m_axis_aresetn] [get_bd_pins axis_clk_cnvrt_avg_3/m_axis_aresetn] [get_bd_pins axis_clk_cnvrt_avg_4/m_axis_aresetn] [get_bd_pins axis_clk_cnvrt_avg_5/m_axis_aresetn] [get_bd_pins axis_clk_cnvrt_avg_6/m_axis_aresetn] [get_bd_pins axis_clk_cnvrt_avg_7/m_axis_aresetn] [get_bd_pins axis_clk_cnvrt_avg_8/m_axis_aresetn] [get_bd_pins axis_clk_cnvrt_avg_9/m_axis_aresetn] [get_bd_pins axis_clk_cnvrt_avg_10/m_axis_aresetn] [get_bd_pins qick_processor_0/c_resetn]
  connect_bd_net -net rst_dac2_peripheral_aresetn [get_bd_pins rst_dac0/peripheral_aresetn] [get_bd_pins axis_cdcsync_v1_0/m_axis_aresetn] [get_bd_pins axis_register_slice_0/aresetn] [get_bd_pins axis_register_slice_1/aresetn] [get_bd_pins axis_register_slice_2/aresetn] [get_bd_pins axis_register_slice_3/aresetn] [get_bd_pins axis_signal_gen_v6_0/aresetn] [get_bd_pins axis_signal_gen_v6_1/aresetn] [get_bd_pins axis_signal_gen_v6_2/aresetn] [get_bd_pins axis_signal_gen_v6_3/aresetn] [get_bd_pins sg_translator_0/aresetn] [get_bd_pins sg_translator_1/aresetn] [get_bd_pins sg_translator_2/aresetn] [get_bd_pins sg_translator_3/aresetn] [get_bd_pins axis_register_slice_4/aresetn] [get_bd_pins axis_register_slice_5/aresetn] [get_bd_pins axis_register_slice_6/aresetn] [get_bd_pins axis_register_slice_7/aresetn] [get_bd_pins usp_rf_data_converter_0/s0_axis_aresetn]
  connect_bd_net -net rst_dac2_peripheral_reset [get_bd_pins rst_dac2/peripheral_reset] [get_bd_pins clk_core/reset]
  connect_bd_net -net rst_dac3_peripheral_aresetn [get_bd_pins rst_dac2/peripheral_aresetn] [get_bd_pins axis_sg_mixmux8_v1_0/aresetn] [get_bd_pins sg_translator_11/aresetn] [get_bd_pins sg_translator_12/aresetn] [get_bd_pins sg_translator_4/aresetn] [get_bd_pins sg_translator_13/aresetn] [get_bd_pins sg_translator_14/aresetn] [get_bd_pins sg_translator_15/aresetn] [get_bd_pins sg_translator_5/aresetn] [get_bd_pins sg_translator_6/aresetn] [get_bd_pins sg_translator_7/aresetn] [get_bd_pins sg_translator_8/aresetn] [get_bd_pins sg_translator_9/aresetn] [get_bd_pins sg_translator_10/aresetn] [get_bd_pins axis_cdcsync_v1_0/s_axis_aresetn] [get_bd_pins axis_cdcsync_v1_2/s_axis_aresetn] [get_bd_pins axis_tmux_v1_0/aresetn] [get_bd_pins axis_sg_int4_v2_0/aresetn] [get_bd_pins axis_sg_int4_v2_10/aresetn] [get_bd_pins axis_sg_int4_v2_1/aresetn] [get_bd_pins axis_sg_int4_v2_2/aresetn] [get_bd_pins axis_sg_int4_v2_3/aresetn] [get_bd_pins axis_sg_int4_v2_4/aresetn] [get_bd_pins axis_sg_int4_v2_5/aresetn] [get_bd_pins axis_sg_int4_v2_6/aresetn] [get_bd_pins axis_sg_int4_v2_7/aresetn] [get_bd_pins axis_sg_int4_v2_8/aresetn] [get_bd_pins axis_sg_int4_v2_9/aresetn] [get_bd_pins usp_rf_data_converter_0/s1_axis_aresetn] [get_bd_pins usp_rf_data_converter_0/s3_axis_aresetn] [get_bd_pins usp_rf_data_converter_0/s2_axis_aresetn] [get_bd_pins qick_processor_0/t_resetn]
  connect_bd_net -net rst_ps8_0_99M_peripheral_aresetn [get_bd_pins rst_100/peripheral_aresetn] [get_bd_pins axi_intc_0/s_axi_aresetn] [get_bd_pins axis_sg_mixmux8_v1_0/s_axi_aresetn] [get_bd_pins axis_signal_gen_v6_0/s0_axis_aresetn] [get_bd_pins axis_signal_gen_v6_0/s_axi_aresetn] [get_bd_pins axis_signal_gen_v6_1/s0_axis_aresetn] [get_bd_pins axis_signal_gen_v6_1/s_axi_aresetn] [get_bd_pins axis_signal_gen_v6_2/s0_axis_aresetn] [get_bd_pins axis_signal_gen_v6_2/s_axi_aresetn] [get_bd_pins axis_signal_gen_v6_3/s0_axis_aresetn] [get_bd_pins axis_signal_gen_v6_3/s_axi_aresetn] [get_bd_pins axi_dma_avg/axi_resetn] [get_bd_pins axi_dma_buf/axi_resetn] [get_bd_pins axi_dma_gen/axi_resetn] [get_bd_pins axi_dma_mr/axi_resetn] [get_bd_pins axi_dma_tproc/axi_resetn] [get_bd_pins axi_smc/aresetn] [get_bd_pins axis_clk_cnvrt_avg_0/s_axis_aresetn] [get_bd_pins axis_clk_cnvrt_avg_1/s_axis_aresetn] [get_bd_pins axis_clk_cnvrt_avg_2/s_axis_aresetn] [get_bd_pins axis_clk_cnvrt_avg_3/s_axis_aresetn] [get_bd_pins axis_clk_cnvrt_avg_4/s_axis_aresetn] [get_bd_pins axis_clk_cnvrt_avg_5/s_axis_aresetn] [get_bd_pins axis_clk_cnvrt_avg_6/s_axis_aresetn] [get_bd_pins axis_clk_cnvrt_avg_7/s_axis_aresetn] [get_bd_pins axis_clk_cnvrt_avg_8/s_axis_aresetn] [get_bd_pins axis_clk_cnvrt_avg_9/s_axis_aresetn] [get_bd_pins axis_pfb_readout_v4_0/s_axi_aresetn] [get_bd_pins axis_sg_int4_v2_0/s_axi_aresetn] [get_bd_pins axis_sg_int4_v2_0/s0_axis_aresetn] [get_bd_pins axis_sg_int4_v2_10/s_axi_aresetn] [get_bd_pins axis_sg_int4_v2_10/s0_axis_aresetn] [get_bd_pins axis_sg_int4_v2_1/s_axi_aresetn] [get_bd_pins axis_sg_int4_v2_1/s0_axis_aresetn] [get_bd_pins axis_sg_int4_v2_2/s_axi_aresetn] [get_bd_pins axis_sg_int4_v2_2/s0_axis_aresetn] [get_bd_pins axis_sg_int4_v2_3/s_axi_aresetn] [get_bd_pins axis_sg_int4_v2_3/s0_axis_aresetn] [get_bd_pins axis_sg_int4_v2_4/s_axi_aresetn] [get_bd_pins axis_sg_int4_v2_4/s0_axis_aresetn] [get_bd_pins axis_sg_int4_v2_5/s_axi_aresetn] [get_bd_pins axis_sg_int4_v2_5/s0_axis_aresetn] [get_bd_pins axis_sg_int4_v2_6/s_axi_aresetn] [get_bd_pins axis_sg_int4_v2_6/s0_axis_aresetn] [get_bd_pins axis_sg_int4_v2_7/s_axi_aresetn] [get_bd_pins axis_sg_int4_v2_7/s0_axis_aresetn] [get_bd_pins axis_sg_int4_v2_8/s_axi_aresetn] [get_bd_pins axis_sg_int4_v2_8/s0_axis_aresetn] [get_bd_pins axis_sg_int4_v2_9/s_axi_aresetn] [get_bd_pins axis_sg_int4_v2_9/s0_axis_aresetn] [get_bd_pins axis_switch_avg/aresetn] [get_bd_pins axis_switch_avg/s_axi_ctrl_aresetn] [get_bd_pins axis_switch_buf/aresetn] [get_bd_pins axis_switch_buf/s_axi_ctrl_aresetn] [get_bd_pins axis_switch_ddr/s_axi_ctrl_aresetn] [get_bd_pins axis_switch_gen/aresetn] [get_bd_pins axis_switch_gen/s_axi_ctrl_aresetn] [get_bd_pins axis_switch_mr/s_axi_ctrl_aresetn] [get_bd_pins ps8_0_axi_periph/ARESETN] [get_bd_pins ps8_0_axi_periph/S00_ARESETN] [get_bd_pins ps8_0_axi_periph/M00_ARESETN] [get_bd_pins ps8_0_axi_periph/M01_ARESETN] [get_bd_pins ps8_0_axi_periph/M02_ARESETN] [get_bd_pins ps8_0_axi_periph/M03_ARESETN] [get_bd_pins ps8_0_axi_periph/M04_ARESETN] [get_bd_pins ps8_0_axi_periph/M05_ARESETN] [get_bd_pins ps8_0_axi_periph/M06_ARESETN] [get_bd_pins ps8_0_axi_periph/M07_ARESETN] [get_bd_pins ps8_0_axi_periph/M08_ARESETN] [get_bd_pins ps8_0_axi_periph/M09_ARESETN] [get_bd_pins ps8_0_axi_periph/M10_ARESETN] [get_bd_pins ps8_0_axi_periph/M11_ARESETN] [get_bd_pins ps8_0_axi_periph/M12_ARESETN] [get_bd_pins ps8_0_axi_periph/M13_ARESETN] [get_bd_pins ps8_0_axi_periph/M14_ARESETN] [get_bd_pins ps8_0_axi_periph/M15_ARESETN] [get_bd_pins ps8_0_axi_periph/M16_ARESETN] [get_bd_pins ps8_0_axi_periph/M17_ARESETN] [get_bd_pins ps8_0_axi_periph/M18_ARESETN] [get_bd_pins ps8_0_axi_periph/M19_ARESETN] [get_bd_pins ps8_0_axi_periph/M20_ARESETN] [get_bd_pins ps8_0_axi_periph/M21_ARESETN] [get_bd_pins ps8_0_axi_periph/M22_ARESETN] [get_bd_pins ps8_0_axi_periph/M23_ARESETN] [get_bd_pins ps8_0_axi_periph/M24_ARESETN] [get_bd_pins ps8_0_axi_periph/M25_ARESETN] [get_bd_pins ps8_0_axi_periph/M26_ARESETN] [get_bd_pins ps8_0_axi_periph/M27_ARESETN] [get_bd_pins ps8_0_axi_periph/M28_ARESETN] [get_bd_pins ps8_0_axi_periph/M29_ARESETN] [get_bd_pins ps8_0_axi_periph/M30_ARESETN] [get_bd_pins ps8_0_axi_periph/M31_ARESETN] [get_bd_pins ps8_0_axi_periph/M32_ARESETN] [get_bd_pins ps8_0_axi_periph/M33_ARESETN] [get_bd_pins ps8_0_axi_periph/M34_ARESETN] [get_bd_pins ps8_0_axi_periph/M35_ARESETN] [get_bd_pins ps8_0_axi_periph/M36_ARESETN] [get_bd_pins ps8_0_axi_periph/M37_ARESETN] [get_bd_pins ps8_0_axi_periph/M38_ARESETN] [get_bd_pins ps8_0_axi_periph/M39_ARESETN] [get_bd_pins ps8_0_axi_periph/M40_ARESETN] [get_bd_pins ps8_0_axi_periph/M41_ARESETN] [get_bd_pins usp_rf_data_converter_0/s_axi_aresetn] [get_bd_pins ddr4/s_axi_aresetn] [get_bd_pins rfb_control/s_axi_aresetn] [get_bd_pins pmod_led_gpio/s_axi_aresetn] [get_bd_pins pmod_bits_gpio/s_axi_aresetn] [get_bd_pins ps8_0_axi_periph/M42_ARESETN] [get_bd_pins ps8_0_axi_periph/M43_ARESETN] [get_bd_pins ps8_0_axi_periph/M44_ARESETN] [get_bd_pins ps8_0_axi_periph/M45_ARESETN] [get_bd_pins ps8_0_axi_periph/M46_ARESETN] [get_bd_pins ps8_0_axi_periph/M47_ARESETN] [get_bd_pins ps8_0_axi_periph/M48_ARESETN] [get_bd_pins clk104_gpio/s_axi_aresetn] [get_bd_pins ps8_0_axi_periph/M49_ARESETN] [get_bd_pins axis_clk_cnvrt_avg_10/s_axis_aresetn] [get_bd_pins ps8_0_axi_periph/M50_ARESETN] [get_bd_pins axis_avg_buffer_0/s_axi_aresetn] [get_bd_pins axis_avg_buffer_0/m_axis_aresetn] [get_bd_pins axis_avg_buffer_1/s_axi_aresetn] [get_bd_pins axis_avg_buffer_1/m_axis_aresetn] [get_bd_pins axis_avg_buffer_10/s_axi_aresetn] [get_bd_pins axis_avg_buffer_10/m_axis_aresetn] [get_bd_pins axis_avg_buffer_2/s_axi_aresetn] [get_bd_pins axis_avg_buffer_2/m_axis_aresetn] [get_bd_pins axis_avg_buffer_3/s_axi_aresetn] [get_bd_pins axis_avg_buffer_3/m_axis_aresetn] [get_bd_pins axis_avg_buffer_4/s_axi_aresetn] [get_bd_pins axis_avg_buffer_4/m_axis_aresetn] [get_bd_pins axis_avg_buffer_5/s_axi_aresetn] [get_bd_pins axis_avg_buffer_5/m_axis_aresetn] [get_bd_pins axis_avg_buffer_6/s_axi_aresetn] [get_bd_pins axis_avg_buffer_6/m_axis_aresetn] [get_bd_pins axis_avg_buffer_7/s_axi_aresetn] [get_bd_pins axis_avg_buffer_7/m_axis_aresetn] [get_bd_pins axis_avg_buffer_8/s_axi_aresetn] [get_bd_pins axis_avg_buffer_8/m_axis_aresetn] [get_bd_pins axis_avg_buffer_9/s_axi_aresetn] [get_bd_pins axis_avg_buffer_9/m_axis_aresetn] [get_bd_pins mr_buffer_et_0/s00_axi_aresetn] [get_bd_pins mr_buffer_et_0/m00_axis_aresetn] [get_bd_pins qick_processor_0/ps_resetn]
  connect_bd_net -net usp_rf_data_converter_0_clk_adc2 [get_bd_pins usp_rf_data_converter_0/clk_adc2] [get_bd_pins axis_cdcsync_v1_2/m_axis_aclk] [get_bd_pins rst_adc2/slowest_sync_clk] [get_bd_pins sg_translator_16/aclk] [get_bd_pins sg_translator_17/aclk] [get_bd_pins axis_broadcaster_0/aclk] [get_bd_pins axis_broadcaster_1/aclk] [get_bd_pins axis_broadcaster_2/aclk] [get_bd_pins axis_broadcaster_3/aclk] [get_bd_pins axis_broadcaster_4/aclk] [get_bd_pins axis_broadcaster_5/aclk] [get_bd_pins axis_broadcaster_6/aclk] [get_bd_pins axis_broadcaster_7/aclk] [get_bd_pins axis_broadcaster_8/aclk] [get_bd_pins axis_broadcaster_9/aclk] [get_bd_pins axis_dyn_readout_v1_0/aclk] [get_bd_pins axis_dyn_readout_v1_1/aclk] [get_bd_pins axis_pfb_readout_v4_0/aclk] [get_bd_pins axis_switch_ddr/aclk] [get_bd_pins axis_switch_mr/aclk] [get_bd_pins usp_rf_data_converter_0/m2_axis_aclk] [get_bd_pins ddr4/aclk] [get_bd_pins usp_rf_data_converter_0/m1_axis_aclk] [get_bd_pins sg_translator_18/aclk] [get_bd_pins axis_dyn_readout_v1_2/aclk] [get_bd_pins axis_broadcaster_10/aclk] [get_bd_pins axis_avg_buffer_0/s_axis_aclk] [get_bd_pins axis_avg_buffer_1/s_axis_aclk] [get_bd_pins axis_avg_buffer_10/s_axis_aclk] [get_bd_pins axis_avg_buffer_2/s_axis_aclk] [get_bd_pins axis_avg_buffer_3/s_axis_aclk] [get_bd_pins axis_avg_buffer_4/s_axis_aclk] [get_bd_pins axis_avg_buffer_5/s_axis_aclk] [get_bd_pins axis_avg_buffer_6/s_axis_aclk] [get_bd_pins axis_avg_buffer_7/s_axis_aclk] [get_bd_pins axis_avg_buffer_8/s_axis_aclk] [get_bd_pins axis_avg_buffer_9/s_axis_aclk] [get_bd_pins mr_buffer_et_0/s00_axis_aclk]
  connect_bd_net -net usp_rf_data_converter_0_clk_dac2 [get_bd_pins usp_rf_data_converter_0/clk_dac0] [get_bd_pins axis_cdcsync_v1_0/m_axis_aclk] [get_bd_pins axis_register_slice_0/aclk] [get_bd_pins axis_register_slice_1/aclk] [get_bd_pins axis_register_slice_2/aclk] [get_bd_pins axis_register_slice_3/aclk] [get_bd_pins axis_signal_gen_v6_0/aclk] [get_bd_pins axis_signal_gen_v6_1/aclk] [get_bd_pins axis_signal_gen_v6_2/aclk] [get_bd_pins axis_signal_gen_v6_3/aclk] [get_bd_pins rst_dac0/slowest_sync_clk] [get_bd_pins sg_translator_0/aclk] [get_bd_pins sg_translator_1/aclk] [get_bd_pins sg_translator_2/aclk] [get_bd_pins sg_translator_3/aclk] [get_bd_pins axis_register_slice_4/aclk] [get_bd_pins axis_register_slice_5/aclk] [get_bd_pins axis_register_slice_6/aclk] [get_bd_pins axis_register_slice_7/aclk] [get_bd_pins usp_rf_data_converter_0/s0_axis_aclk]
  connect_bd_net -net usp_rf_data_converter_0_clk_dac4 [get_bd_pins usp_rf_data_converter_0/clk_dac2] [get_bd_pins usp_rf_data_converter_0/s2_axis_aclk] [get_bd_pins axis_sg_mixmux8_v1_0/aclk] [get_bd_pins rst_dac2/slowest_sync_clk] [get_bd_pins sg_translator_11/aclk] [get_bd_pins sg_translator_12/aclk] [get_bd_pins sg_translator_4/aclk] [get_bd_pins sg_translator_13/aclk] [get_bd_pins sg_translator_14/aclk] [get_bd_pins sg_translator_15/aclk] [get_bd_pins sg_translator_5/aclk] [get_bd_pins sg_translator_6/aclk] [get_bd_pins sg_translator_7/aclk] [get_bd_pins sg_translator_8/aclk] [get_bd_pins sg_translator_9/aclk] [get_bd_pins sg_translator_10/aclk] [get_bd_pins axis_cdcsync_v1_0/s_axis_aclk] [get_bd_pins axis_cdcsync_v1_2/s_axis_aclk] [get_bd_pins axis_tmux_v1_0/aclk] [get_bd_pins axis_sg_int4_v2_0/aclk] [get_bd_pins axis_sg_int4_v2_10/aclk] [get_bd_pins axis_sg_int4_v2_1/aclk] [get_bd_pins axis_sg_int4_v2_2/aclk] [get_bd_pins axis_sg_int4_v2_3/aclk] [get_bd_pins axis_sg_int4_v2_4/aclk] [get_bd_pins axis_sg_int4_v2_5/aclk] [get_bd_pins axis_sg_int4_v2_6/aclk] [get_bd_pins axis_sg_int4_v2_7/aclk] [get_bd_pins axis_sg_int4_v2_8/aclk] [get_bd_pins axis_sg_int4_v2_9/aclk] [get_bd_pins usp_rf_data_converter_0/s1_axis_aclk] [get_bd_pins usp_rf_data_converter_0/s3_axis_aclk] [get_bd_pins qick_processor_0/t_clk_i] [get_bd_pins clk_core/clk_in1]
  connect_bd_net -net usp_rf_data_converter_0_irq [get_bd_pins usp_rf_data_converter_0/irq] [get_bd_pins xlconcat_intc/In6]
  connect_bd_net -net xlconcat_1_dout [get_bd_pins xlconcat_intc/dout] [get_bd_pins axi_intc_0/intr]
  connect_bd_net -net zynq_ultra_ps_e_0_pl_clk0 [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] [get_bd_pins axi_intc_0/s_axi_aclk] [get_bd_pins axis_sg_mixmux8_v1_0/s_axi_aclk] [get_bd_pins axis_signal_gen_v6_0/s0_axis_aclk] [get_bd_pins axis_signal_gen_v6_0/s_axi_aclk] [get_bd_pins axis_signal_gen_v6_1/s0_axis_aclk] [get_bd_pins axis_signal_gen_v6_1/s_axi_aclk] [get_bd_pins axis_signal_gen_v6_2/s0_axis_aclk] [get_bd_pins axis_signal_gen_v6_2/s_axi_aclk] [get_bd_pins axis_signal_gen_v6_3/s0_axis_aclk] [get_bd_pins axis_signal_gen_v6_3/s_axi_aclk] [get_bd_pins rst_100/slowest_sync_clk] [get_bd_pins axi_dma_avg/s_axi_lite_aclk] [get_bd_pins axi_dma_avg/m_axi_s2mm_aclk] [get_bd_pins axi_dma_buf/s_axi_lite_aclk] [get_bd_pins axi_dma_buf/m_axi_s2mm_aclk] [get_bd_pins axi_dma_gen/s_axi_lite_aclk] [get_bd_pins axi_dma_gen/m_axi_mm2s_aclk] [get_bd_pins axi_dma_mr/s_axi_lite_aclk] [get_bd_pins axi_dma_mr/m_axi_s2mm_aclk] [get_bd_pins axi_dma_tproc/s_axi_lite_aclk] [get_bd_pins axi_dma_tproc/m_axi_mm2s_aclk] [get_bd_pins axi_dma_tproc/m_axi_s2mm_aclk] [get_bd_pins axi_smc/aclk] [get_bd_pins axis_clk_cnvrt_avg_0/s_axis_aclk] [get_bd_pins axis_clk_cnvrt_avg_1/s_axis_aclk] [get_bd_pins axis_clk_cnvrt_avg_2/s_axis_aclk] [get_bd_pins axis_clk_cnvrt_avg_3/s_axis_aclk] [get_bd_pins axis_clk_cnvrt_avg_4/s_axis_aclk] [get_bd_pins axis_clk_cnvrt_avg_5/s_axis_aclk] [get_bd_pins axis_clk_cnvrt_avg_6/s_axis_aclk] [get_bd_pins axis_clk_cnvrt_avg_7/s_axis_aclk] [get_bd_pins axis_clk_cnvrt_avg_8/s_axis_aclk] [get_bd_pins axis_clk_cnvrt_avg_9/s_axis_aclk] [get_bd_pins axis_pfb_readout_v4_0/s_axi_aclk] [get_bd_pins axis_sg_int4_v2_0/s_axi_aclk] [get_bd_pins axis_sg_int4_v2_0/s0_axis_aclk] [get_bd_pins axis_sg_int4_v2_10/s_axi_aclk] [get_bd_pins axis_sg_int4_v2_10/s0_axis_aclk] [get_bd_pins axis_sg_int4_v2_1/s_axi_aclk] [get_bd_pins axis_sg_int4_v2_1/s0_axis_aclk] [get_bd_pins axis_sg_int4_v2_2/s_axi_aclk] [get_bd_pins axis_sg_int4_v2_2/s0_axis_aclk] [get_bd_pins axis_sg_int4_v2_3/s_axi_aclk] [get_bd_pins axis_sg_int4_v2_3/s0_axis_aclk] [get_bd_pins axis_sg_int4_v2_4/s_axi_aclk] [get_bd_pins axis_sg_int4_v2_4/s0_axis_aclk] [get_bd_pins axis_sg_int4_v2_5/s_axi_aclk] [get_bd_pins axis_sg_int4_v2_5/s0_axis_aclk] [get_bd_pins axis_sg_int4_v2_6/s_axi_aclk] [get_bd_pins axis_sg_int4_v2_6/s0_axis_aclk] [get_bd_pins axis_sg_int4_v2_7/s_axi_aclk] [get_bd_pins axis_sg_int4_v2_7/s0_axis_aclk] [get_bd_pins axis_sg_int4_v2_8/s_axi_aclk] [get_bd_pins axis_sg_int4_v2_8/s0_axis_aclk] [get_bd_pins axis_sg_int4_v2_9/s_axi_aclk] [get_bd_pins axis_sg_int4_v2_9/s0_axis_aclk] [get_bd_pins axis_switch_avg/aclk] [get_bd_pins axis_switch_avg/s_axi_ctrl_aclk] [get_bd_pins axis_switch_buf/aclk] [get_bd_pins axis_switch_buf/s_axi_ctrl_aclk] [get_bd_pins axis_switch_ddr/s_axi_ctrl_aclk] [get_bd_pins axis_switch_gen/aclk] [get_bd_pins axis_switch_gen/s_axi_ctrl_aclk] [get_bd_pins axis_switch_mr/s_axi_ctrl_aclk] [get_bd_pins ps8_0_axi_periph/ACLK] [get_bd_pins ps8_0_axi_periph/S00_ACLK] [get_bd_pins ps8_0_axi_periph/M00_ACLK] [get_bd_pins ps8_0_axi_periph/M01_ACLK] [get_bd_pins ps8_0_axi_periph/M02_ACLK] [get_bd_pins ps8_0_axi_periph/M03_ACLK] [get_bd_pins ps8_0_axi_periph/M04_ACLK] [get_bd_pins ps8_0_axi_periph/M05_ACLK] [get_bd_pins ps8_0_axi_periph/M06_ACLK] [get_bd_pins ps8_0_axi_periph/M07_ACLK] [get_bd_pins ps8_0_axi_periph/M08_ACLK] [get_bd_pins ps8_0_axi_periph/M09_ACLK] [get_bd_pins ps8_0_axi_periph/M10_ACLK] [get_bd_pins ps8_0_axi_periph/M11_ACLK] [get_bd_pins ps8_0_axi_periph/M12_ACLK] [get_bd_pins ps8_0_axi_periph/M13_ACLK] [get_bd_pins ps8_0_axi_periph/M14_ACLK] [get_bd_pins ps8_0_axi_periph/M15_ACLK] [get_bd_pins ps8_0_axi_periph/M16_ACLK] [get_bd_pins ps8_0_axi_periph/M17_ACLK] [get_bd_pins ps8_0_axi_periph/M18_ACLK] [get_bd_pins ps8_0_axi_periph/M19_ACLK] [get_bd_pins ps8_0_axi_periph/M20_ACLK] [get_bd_pins ps8_0_axi_periph/M21_ACLK] [get_bd_pins ps8_0_axi_periph/M22_ACLK] [get_bd_pins ps8_0_axi_periph/M23_ACLK] [get_bd_pins ps8_0_axi_periph/M24_ACLK] [get_bd_pins ps8_0_axi_periph/M25_ACLK] [get_bd_pins ps8_0_axi_periph/M26_ACLK] [get_bd_pins ps8_0_axi_periph/M27_ACLK] [get_bd_pins ps8_0_axi_periph/M28_ACLK] [get_bd_pins ps8_0_axi_periph/M29_ACLK] [get_bd_pins ps8_0_axi_periph/M30_ACLK] [get_bd_pins ps8_0_axi_periph/M31_ACLK] [get_bd_pins ps8_0_axi_periph/M32_ACLK] [get_bd_pins ps8_0_axi_periph/M33_ACLK] [get_bd_pins ps8_0_axi_periph/M34_ACLK] [get_bd_pins ps8_0_axi_periph/M35_ACLK] [get_bd_pins ps8_0_axi_periph/M36_ACLK] [get_bd_pins ps8_0_axi_periph/M37_ACLK] [get_bd_pins ps8_0_axi_periph/M38_ACLK] [get_bd_pins ps8_0_axi_periph/M39_ACLK] [get_bd_pins ps8_0_axi_periph/M40_ACLK] [get_bd_pins ps8_0_axi_periph/M41_ACLK] [get_bd_pins usp_rf_data_converter_0/s_axi_aclk] [get_bd_pins zynq_ultra_ps_e_0/maxihpm0_fpd_aclk] [get_bd_pins zynq_ultra_ps_e_0/saxihpc0_fpd_aclk] [get_bd_pins ddr4/s_axi_aclk] [get_bd_pins rfb_control/s_axi_aclk] [get_bd_pins pmod_led_gpio/s_axi_aclk] [get_bd_pins pmod_bits_gpio/s_axi_aclk] [get_bd_pins ps8_0_axi_periph/M42_ACLK] [get_bd_pins ps8_0_axi_periph/M43_ACLK] [get_bd_pins ps8_0_axi_periph/M44_ACLK] [get_bd_pins ps8_0_axi_periph/M45_ACLK] [get_bd_pins ps8_0_axi_periph/M46_ACLK] [get_bd_pins ps8_0_axi_periph/M47_ACLK] [get_bd_pins ps8_0_axi_periph/M48_ACLK] [get_bd_pins clk104_gpio/s_axi_aclk] [get_bd_pins ps8_0_axi_periph/M49_ACLK] [get_bd_pins axis_clk_cnvrt_avg_10/s_axis_aclk] [get_bd_pins ps8_0_axi_periph/M50_ACLK] [get_bd_pins axis_avg_buffer_0/s_axi_aclk] [get_bd_pins axis_avg_buffer_0/m_axis_aclk] [get_bd_pins axis_avg_buffer_1/s_axi_aclk] [get_bd_pins axis_avg_buffer_1/m_axis_aclk] [get_bd_pins axis_avg_buffer_10/s_axi_aclk] [get_bd_pins axis_avg_buffer_10/m_axis_aclk] [get_bd_pins axis_avg_buffer_2/s_axi_aclk] [get_bd_pins axis_avg_buffer_2/m_axis_aclk] [get_bd_pins axis_avg_buffer_3/s_axi_aclk] [get_bd_pins axis_avg_buffer_3/m_axis_aclk] [get_bd_pins axis_avg_buffer_4/s_axi_aclk] [get_bd_pins axis_avg_buffer_4/m_axis_aclk] [get_bd_pins axis_avg_buffer_5/s_axi_aclk] [get_bd_pins axis_avg_buffer_5/m_axis_aclk] [get_bd_pins axis_avg_buffer_6/s_axi_aclk] [get_bd_pins axis_avg_buffer_6/m_axis_aclk] [get_bd_pins axis_avg_buffer_7/s_axi_aclk] [get_bd_pins axis_avg_buffer_7/m_axis_aclk] [get_bd_pins axis_avg_buffer_8/s_axi_aclk] [get_bd_pins axis_avg_buffer_8/m_axis_aclk] [get_bd_pins axis_avg_buffer_9/s_axi_aclk] [get_bd_pins axis_avg_buffer_9/m_axis_aclk] [get_bd_pins mr_buffer_et_0/s00_axi_aclk] [get_bd_pins mr_buffer_et_0/m00_axis_aclk] [get_bd_pins qick_processor_0/ps_clk_i]
  connect_bd_net -net zynq_ultra_ps_e_0_pl_clk1 [get_bd_pins zynq_ultra_ps_e_0/pl_clk1] [get_bd_ports TWOMHZ_1V8_PWR_SYNC]
  connect_bd_net -net zynq_ultra_ps_e_0_pl_resetn0 [get_bd_pins zynq_ultra_ps_e_0/pl_resetn0] [get_bd_pins rst_100/ext_reset_in] [get_bd_pins rst_adc2/ext_reset_in] [get_bd_pins rst_dac0/ext_reset_in] [get_bd_pins rst_dac2/ext_reset_in]

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
  assign_bd_address -offset 0x000400320000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs rfb_control/attn_spi/AXI_LITE/Reg] -force
  assign_bd_address -offset 0x000400000000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axi_dma_avg/S_AXI_LITE/Reg] -force
  assign_bd_address -offset 0x000400010000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axi_dma_buf/S_AXI_LITE/Reg] -force
  assign_bd_address -offset 0x000400020000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axi_dma_gen/S_AXI_LITE/Reg] -force
  assign_bd_address -offset 0x000400030000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axi_dma_mr/S_AXI_LITE/Reg] -force
  assign_bd_address -offset 0x000400040000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axi_dma_tproc/S_AXI_LITE/Reg] -force
  assign_bd_address -offset 0x000400270000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs clk104_gpio/S_AXI/Reg] -force
  assign_bd_address -offset 0x000400050000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axi_intc_0/S_AXI/Reg] -force
  assign_bd_address -offset 0x000400060000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_avg_buffer_0/s_axi/reg0] -force
  assign_bd_address -offset 0x000400370000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_avg_buffer_10/s_axi/reg0] -force
  assign_bd_address -offset 0x000400070000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_avg_buffer_1/s_axi/reg0] -force
  assign_bd_address -offset 0x000400080000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_avg_buffer_2/s_axi/reg0] -force
  assign_bd_address -offset 0x000400090000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_avg_buffer_3/s_axi/reg0] -force
  assign_bd_address -offset 0x0004000A0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_avg_buffer_4/s_axi/reg0] -force
  assign_bd_address -offset 0x0004000B0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_avg_buffer_5/s_axi/reg0] -force
  assign_bd_address -offset 0x0004000C0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_avg_buffer_6/s_axi/reg0] -force
  assign_bd_address -offset 0x0004000D0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_avg_buffer_7/s_axi/reg0] -force
  assign_bd_address -offset 0x0004000E0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_avg_buffer_8/s_axi/reg0] -force
  assign_bd_address -offset 0x0004000F0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_avg_buffer_9/s_axi/reg0] -force
  assign_bd_address -offset 0x000400100000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs ddr4/axis_buffer_ddr_v1_0/s_axi/reg0] -force
  assign_bd_address -offset 0x000400101000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_pfb_readout_v4_0/s_axi/reg0] -force
  assign_bd_address -offset 0x000400110000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_sg_int4_v2_0/s_axi/reg0] -force
  assign_bd_address -offset 0x000400130000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_sg_int4_v2_10/s_axi/reg0] -force
  assign_bd_address -offset 0x000400120000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_sg_int4_v2_1/s_axi/reg0] -force
  assign_bd_address -offset 0x000400140000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_sg_int4_v2_2/s_axi/reg0] -force
  assign_bd_address -offset 0x000400150000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_sg_int4_v2_3/s_axi/reg0] -force
  assign_bd_address -offset 0x000400160000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_sg_int4_v2_4/s_axi/reg0] -force
  assign_bd_address -offset 0x000400170000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_sg_int4_v2_5/s_axi/reg0] -force
  assign_bd_address -offset 0x000400180000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_sg_int4_v2_6/s_axi/reg0] -force
  assign_bd_address -offset 0x000400190000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_sg_int4_v2_7/s_axi/reg0] -force
  assign_bd_address -offset 0x0004001A0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_sg_int4_v2_8/s_axi/reg0] -force
  assign_bd_address -offset 0x0004001B0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_sg_int4_v2_9/s_axi/reg0] -force
  assign_bd_address -offset 0x000400102000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_sg_mixmux8_v1_0/s_axi/reg0] -force
  assign_bd_address -offset 0x0004001C0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_signal_gen_v6_0/s_axi/reg0] -force
  assign_bd_address -offset 0x0004001D0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_signal_gen_v6_1/s_axi/reg0] -force
  assign_bd_address -offset 0x0004001E0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_signal_gen_v6_2/s_axi/reg0] -force
  assign_bd_address -offset 0x0004001F0000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_signal_gen_v6_3/s_axi/reg0] -force
  assign_bd_address -offset 0x000400200000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_switch_avg/S_AXI_CTRL/Reg] -force
  assign_bd_address -offset 0x000400210000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_switch_buf/S_AXI_CTRL/Reg] -force
  assign_bd_address -offset 0x000400220000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_switch_ddr/S_AXI_CTRL/Reg] -force
  assign_bd_address -offset 0x000400230000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_switch_gen/S_AXI_CTRL/Reg] -force
  assign_bd_address -offset 0x000400240000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axis_switch_mr/S_AXI_CTRL/Reg] -force
  assign_bd_address -offset 0x000400330000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs rfb_control/bias_gpio/S_AXI/Reg] -force
  assign_bd_address -offset 0x000400340000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs rfb_control/bias_spi/AXI_LITE/Reg] -force
  assign_bd_address -offset 0x000400350000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs rfb_control/brd_sel_gpio/S_AXI/Reg] -force
  assign_bd_address -offset 0x000500000000 -range 0x000100000000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs ddr4/ddr4_0/C0_DDR4_MEMORY_MAP/C0_DDR4_ADDRESS_BLOCK] -force
  assign_bd_address -offset 0x000400360000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs rfb_control/filter_spi/AXI_LITE/Reg] -force
  assign_bd_address -offset 0x000400250000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs mr_buffer_et_0/s00_axi/reg0] -force
  assign_bd_address -offset 0x000400300000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs pmod_bits_gpio/S_AXI/Reg] -force
  assign_bd_address -offset 0x000400310000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs pmod_led_gpio/S_AXI/Reg] -force
  assign_bd_address -offset 0x000400260000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs qick_processor_0/s_axi/reg0] -force
  assign_bd_address -offset 0x000400280000 -range 0x00040000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs usp_rf_data_converter_0/s_axi/Reg] -force
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
   "Default View_ScaleFactor":"0.162891",
   "Default View_TopLeft":"-3512,-700",
   "ExpandedHierarchyInLayout":"",
   "guistr":"# # String gsaved with Nlview 7.5.8 2022-09-21 7111 VDI=41 GEI=38 GUI=JA:10.0 TLS
#  -string -flagsOSRD
preplace port adc2_clk_0 -pg 1 -lvl 11 -x 6180 -y 2270 -defaultsOSRD -right
preplace port dac2_clk_0 -pg 1 -lvl 11 -x 6180 -y 2290 -defaultsOSRD -right
preplace port ddr4_sdram_c0 -pg 1 -lvl 11 -x 6180 -y 3720 -defaultsOSRD
preplace port default_sysclk_c0_300mhz -pg 1 -lvl 11 -x 6180 -y 3650 -defaultsOSRD -right
preplace port sysref_in_0 -pg 1 -lvl 11 -x 6180 -y 2390 -defaultsOSRD -right
preplace port vin10_0 -pg 1 -lvl 11 -x 6180 -y 2370 -defaultsOSRD -right
preplace port vin20_0 -pg 1 -lvl 11 -x 6180 -y 2310 -defaultsOSRD -right
preplace port vin21_0 -pg 1 -lvl 11 -x 6180 -y 2330 -defaultsOSRD -right
preplace port vin22_0 -pg 1 -lvl 11 -x 6180 -y 2350 -defaultsOSRD -right
preplace port vout0 -pg 1 -lvl 11 -x 6180 -y 1870 -defaultsOSRD
preplace port vout1 -pg 1 -lvl 11 -x 6180 -y 1890 -defaultsOSRD
preplace port vout2 -pg 1 -lvl 11 -x 6180 -y 1910 -defaultsOSRD
preplace port vout3 -pg 1 -lvl 11 -x 6180 -y 1930 -defaultsOSRD
preplace port vout4 -pg 1 -lvl 11 -x 6180 -y 1950 -defaultsOSRD
preplace port vout5 -pg 1 -lvl 11 -x 6180 -y 1970 -defaultsOSRD
preplace port vout6 -pg 1 -lvl 11 -x 6180 -y 1990 -defaultsOSRD
preplace port vout7 -pg 1 -lvl 11 -x 6180 -y 2010 -defaultsOSRD
preplace port vout8 -pg 1 -lvl 11 -x 6180 -y 2030 -defaultsOSRD
preplace port vout9 -pg 1 -lvl 11 -x 6180 -y 2050 -defaultsOSRD
preplace port vout10 -pg 1 -lvl 11 -x 6180 -y 2070 -defaultsOSRD
preplace port vout11 -pg 1 -lvl 11 -x 6180 -y 2090 -defaultsOSRD
preplace port vout12 -pg 1 -lvl 11 -x 6180 -y 2110 -defaultsOSRD
preplace port vout13 -pg 1 -lvl 11 -x 6180 -y 2130 -defaultsOSRD
preplace port vout14 -pg 1 -lvl 11 -x 6180 -y 2150 -defaultsOSRD
preplace port vout15 -pg 1 -lvl 11 -x 6180 -y 2170 -defaultsOSRD
preplace port port-id_DAC_1V8_BIAS_S0 -pg 1 -lvl 11 -x 6180 -y -390 -defaultsOSRD
preplace port port-id_DAC_1V8_BIAS_S1 -pg 1 -lvl 11 -x 6180 -y -370 -defaultsOSRD
preplace port port-id_DAC_1V8_BIAS_S2 -pg 1 -lvl 11 -x 6180 -y -350 -defaultsOSRD
preplace port port-id_DAC_1V8_BIAS_SCLK -pg 1 -lvl 11 -x 6180 -y -190 -defaultsOSRD
preplace port port-id_DAC_1V8_BIAS_SDIN -pg 1 -lvl 11 -x 6180 -y -210 -defaultsOSRD
preplace port port-id_DAC_1V8_BIAS_SDO -pg 1 -lvl 11 -x 6180 -y 40 -defaultsOSRD -right
preplace port port-id_DAC_1V8_BIAS_SYNCn -pg 1 -lvl 11 -x 6180 -y -330 -defaultsOSRD
preplace port port-id_DB_1V8_BRD_SEL -pg 1 -lvl 11 -x 6180 -y -230 -defaultsOSRD
preplace port port-id_DB_1V8_BRD_SEL_SEL0 -pg 1 -lvl 11 -x 6180 -y -290 -defaultsOSRD
preplace port port-id_DB_1V8_BRD_SEL_SEL1 -pg 1 -lvl 11 -x 6180 -y -270 -defaultsOSRD
preplace port port-id_DB_1V8_BRD_SEL_SEL2 -pg 1 -lvl 11 -x 6180 -y -250 -defaultsOSRD
preplace port port-id_DB_1V8_CSn -pg 1 -lvl 11 -x 6180 -y -30 -defaultsOSRD
preplace port port-id_DB_1V8_PE_CLK -pg 1 -lvl 11 -x 6180 -y -130 -defaultsOSRD
preplace port port-id_DB_1V8_PE_SI -pg 1 -lvl 11 -x 6180 -y -150 -defaultsOSRD
preplace port port-id_DB_1V8_SDI -pg 1 -lvl 11 -x 6180 -y -430 -defaultsOSRD
preplace port port-id_DB_1V8_SDO -pg 1 -lvl 11 -x 6180 -y 60 -defaultsOSRD -right
preplace port port-id_DB_1V8_SEL0 -pg 1 -lvl 11 -x 6180 -y -90 -defaultsOSRD
preplace port port-id_DB_1V8_SEL1 -pg 1 -lvl 11 -x 6180 -y -70 -defaultsOSRD
preplace port port-id_DB_1V8_SEL2 -pg 1 -lvl 11 -x 6180 -y -50 -defaultsOSRD
preplace port port-id_DB_1V8_SER_CLK -pg 1 -lvl 11 -x 6180 -y -410 -defaultsOSRD
preplace port port-id_PMOD_IO_0 -pg 1 -lvl 11 -x 6180 -y 400 -defaultsOSRD
preplace port port-id_PMOD_IO_1 -pg 1 -lvl 11 -x 6180 -y 420 -defaultsOSRD
preplace port port-id_PMOD_IO_2 -pg 1 -lvl 11 -x 6180 -y 440 -defaultsOSRD
preplace port port-id_PMOD_IO_3 -pg 1 -lvl 11 -x 6180 -y 460 -defaultsOSRD
preplace port port-id_PMOD_IO_4 -pg 1 -lvl 11 -x 6180 -y 480 -defaultsOSRD
preplace port port-id_PMOD_IO_5 -pg 1 -lvl 11 -x 6180 -y 500 -defaultsOSRD
preplace port port-id_PMOD_IO_6 -pg 1 -lvl 11 -x 6180 -y 520 -defaultsOSRD
preplace port port-id_PMOD_IO_7 -pg 1 -lvl 11 -x 6180 -y 540 -defaultsOSRD
preplace port port-id_PMOD_LED0 -pg 1 -lvl 11 -x 6180 -y 720 -defaultsOSRD
preplace port port-id_PMOD_LED1 -pg 1 -lvl 11 -x 6180 -y 740 -defaultsOSRD
preplace port port-id_PMOD_LED2 -pg 1 -lvl 11 -x 6180 -y 760 -defaultsOSRD
preplace port port-id_PMOD_LED3 -pg 1 -lvl 11 -x 6180 -y 780 -defaultsOSRD
preplace port port-id_PMOD_LED4 -pg 1 -lvl 11 -x 6180 -y 800 -defaultsOSRD
preplace port port-id_PMOD_LED5 -pg 1 -lvl 11 -x 6180 -y 820 -defaultsOSRD
preplace port port-id_PMOD_LED6 -pg 1 -lvl 11 -x 6180 -y 840 -defaultsOSRD
preplace port port-id_PMOD_LED7 -pg 1 -lvl 11 -x 6180 -y 860 -defaultsOSRD
preplace port port-id_SPARE0_1V8 -pg 1 -lvl 11 -x 6180 -y 1200 -defaultsOSRD
preplace port port-id_SPARE1_1V8 -pg 1 -lvl 11 -x 6180 -y 1220 -defaultsOSRD
preplace port port-id_SPARE2_1V8 -pg 1 -lvl 11 -x 6180 -y 1240 -defaultsOSRD
preplace port port-id_SPARE3_1V8 -pg 1 -lvl 11 -x 6180 -y 1260 -defaultsOSRD
preplace port port-id_TWOMHZ_1V8_PWR_SYNC -pg 1 -lvl 11 -x 6180 -y -500 -defaultsOSRD
preplace port port-id_SPARE4_1V8 -pg 1 -lvl 11 -x 6180 -y 1280 -defaultsOSRD
preplace port port-id_SPARE5_1V8 -pg 1 -lvl 11 -x 6180 -y 1300 -defaultsOSRD
preplace portBus DAC_1V8_BIAS_CLRn -pg 1 -lvl 11 -x 6180 -y -310 -defaultsOSRD
preplace portBus DAC_1V8_BIAS_SWEN -pg 1 -lvl 11 -x 6180 -y -170 -defaultsOSRD
preplace portBus DB_1V8_PE_LE -pg 1 -lvl 11 -x 6180 -y -110 -defaultsOSRD
preplace portBus CLK104_CLK_SPI_MUX_SEL_LS -pg 1 -lvl 11 -x 6180 -y 160 -defaultsOSRD
preplace inst axi_intc_0 -pg 1 -lvl 5 -x 2020 -y 310 -defaultsOSRD
preplace inst axis_cdcsync_v1_0 -pg 1 -lvl 5 -x 2020 -y 1090 -defaultsOSRD
preplace inst axis_cdcsync_v1_2 -pg 1 -lvl 2 -x -930 -y 970 -defaultsOSRD
preplace inst axis_register_slice_0 -pg 1 -lvl 8 -x 4570 -y 140 -defaultsOSRD
preplace inst axis_register_slice_1 -pg 1 -lvl 8 -x 4570 -y 540 -defaultsOSRD
preplace inst axis_register_slice_2 -pg 1 -lvl 8 -x 4570 -y 960 -defaultsOSRD
preplace inst axis_register_slice_3 -pg 1 -lvl 8 -x 4570 -y 1360 -defaultsOSRD
preplace inst axis_sg_mixmux8_v1_0 -pg 1 -lvl 7 -x 3950 -y 1380 -defaultsOSRD
preplace inst axis_signal_gen_v6_0 -pg 1 -lvl 8 -x 4570 -y -90 -defaultsOSRD
preplace inst axis_signal_gen_v6_1 -pg 1 -lvl 8 -x 4570 -y 340 -defaultsOSRD
preplace inst axis_signal_gen_v6_2 -pg 1 -lvl 8 -x 4570 -y 760 -defaultsOSRD
preplace inst axis_signal_gen_v6_3 -pg 1 -lvl 8 -x 4570 -y 1160 -defaultsOSRD
preplace inst axis_tmux_v1_0 -pg 1 -lvl 4 -x 800 -y 2020 -defaultsOSRD
preplace inst rst_100 -pg 1 -lvl 6 -x 3000 -y 200 -defaultsOSRD
preplace inst rst_adc2 -pg 1 -lvl 6 -x 3000 -y 380 -defaultsOSRD
preplace inst rst_core -pg 1 -lvl 6 -x 3000 -y 1390 -defaultsOSRD
preplace inst rst_dac0 -pg 1 -lvl 6 -x 3000 -y 640 -defaultsOSRD
preplace inst rst_dac2 -pg 1 -lvl 6 -x 3000 -y 910 -defaultsOSRD
preplace inst sg_translator_0 -pg 1 -lvl 6 -x 3000 -y 1640 -defaultsOSRD
preplace inst sg_translator_1 -pg 1 -lvl 6 -x 3000 -y 1800 -defaultsOSRD
preplace inst sg_translator_2 -pg 1 -lvl 6 -x 3000 -y 1980 -defaultsOSRD
preplace inst sg_translator_3 -pg 1 -lvl 6 -x 3000 -y 2120 -defaultsOSRD
preplace inst sg_translator_5 -pg 1 -lvl 6 -x 3000 -y 2400 -defaultsOSRD
preplace inst sg_translator_6 -pg 1 -lvl 6 -x 3000 -y 2560 -defaultsOSRD
preplace inst sg_translator_7 -pg 1 -lvl 6 -x 3000 -y 2700 -defaultsOSRD
preplace inst sg_translator_8 -pg 1 -lvl 6 -x 3000 -y 2840 -defaultsOSRD
preplace inst sg_translator_9 -pg 1 -lvl 6 -x 3000 -y 2980 -defaultsOSRD
preplace inst sg_translator_10 -pg 1 -lvl 6 -x 3000 -y 3120 -defaultsOSRD
preplace inst sg_translator_11 -pg 1 -lvl 6 -x 3000 -y 3260 -defaultsOSRD
preplace inst sg_translator_12 -pg 1 -lvl 6 -x 3000 -y 3400 -defaultsOSRD
preplace inst sg_translator_4 -pg 1 -lvl 6 -x 3000 -y 2260 -defaultsOSRD
preplace inst sg_translator_13 -pg 1 -lvl 6 -x 3000 -y 3670 -defaultsOSRD
preplace inst sg_translator_14 -pg 1 -lvl 6 -x 3000 -y 3810 -defaultsOSRD
preplace inst sg_translator_15 -pg 1 -lvl 6 -x 3000 -y 3950 -defaultsOSRD
preplace inst sg_translator_16 -pg 1 -lvl 2 -x -930 -y 1260 -defaultsOSRD
preplace inst sg_translator_17 -pg 1 -lvl 2 -x -930 -y 1830 -defaultsOSRD
preplace inst xlconcat_intc -pg 1 -lvl 5 -x 2020 -y 120 -defaultsOSRD
preplace inst axi_dma_avg -pg 1 -lvl 4 -x 800 -y 30 -defaultsOSRD
preplace inst axi_dma_buf -pg 1 -lvl 4 -x 800 -y 210 -defaultsOSRD
preplace inst axi_dma_gen -pg 1 -lvl 4 -x 800 -y 560 -defaultsOSRD
preplace inst axi_dma_mr -pg 1 -lvl 4 -x 800 -y 390 -defaultsOSRD
preplace inst axi_dma_tproc -pg 1 -lvl 4 -x 800 -y 750 -defaultsOSRD
preplace inst axi_smc -pg 1 -lvl 5 -x 2020 -y 510 -defaultsOSRD
preplace inst axis_broadcaster_0 -pg 1 -lvl 2 -x -930 -y 1600 -defaultsOSRD
preplace inst axis_broadcaster_1 -pg 1 -lvl 2 -x -930 -y 2170 -defaultsOSRD
preplace inst axis_broadcaster_2 -pg 1 -lvl 2 -x -930 -y 2970 -defaultsOSRD
preplace inst axis_broadcaster_3 -pg 1 -lvl 2 -x -930 -y 2690 -defaultsOSRD
preplace inst axis_broadcaster_4 -pg 1 -lvl 2 -x -930 -y 2830 -defaultsOSRD
preplace inst axis_broadcaster_5 -pg 1 -lvl 2 -x -930 -y 3110 -defaultsOSRD
preplace inst axis_broadcaster_6 -pg 1 -lvl 2 -x -930 -y 3250 -defaultsOSRD
preplace inst axis_broadcaster_7 -pg 1 -lvl 2 -x -930 -y 3390 -defaultsOSRD
preplace inst axis_broadcaster_8 -pg 1 -lvl 2 -x -930 -y 3530 -defaultsOSRD
preplace inst axis_broadcaster_9 -pg 1 -lvl 2 -x -930 -y 3670 -defaultsOSRD
preplace inst axis_clk_cnvrt_avg_0 -pg 1 -lvl 4 -x 800 -y 2250 -defaultsOSRD
preplace inst axis_clk_cnvrt_avg_1 -pg 1 -lvl 4 -x 800 -y 2430 -defaultsOSRD
preplace inst axis_clk_cnvrt_avg_2 -pg 1 -lvl 4 -x 800 -y 2640 -defaultsOSRD
preplace inst axis_clk_cnvrt_avg_3 -pg 1 -lvl 4 -x 800 -y 2820 -defaultsOSRD
preplace inst axis_clk_cnvrt_avg_4 -pg 1 -lvl 4 -x 800 -y 3000 -defaultsOSRD
preplace inst axis_clk_cnvrt_avg_5 -pg 1 -lvl 4 -x 800 -y 3240 -defaultsOSRD
preplace inst axis_clk_cnvrt_avg_6 -pg 1 -lvl 4 -x 800 -y 3470 -defaultsOSRD
preplace inst axis_clk_cnvrt_avg_7 -pg 1 -lvl 4 -x 800 -y 3670 -defaultsOSRD
preplace inst axis_clk_cnvrt_avg_8 -pg 1 -lvl 4 -x 800 -y 3920 -defaultsOSRD
preplace inst axis_clk_cnvrt_avg_9 -pg 1 -lvl 4 -x 800 -y 4100 -defaultsOSRD
preplace inst axis_dyn_readout_v1_0 -pg 1 -lvl 2 -x -930 -y 1430 -defaultsOSRD
preplace inst axis_dyn_readout_v1_1 -pg 1 -lvl 2 -x -930 -y 2020 -defaultsOSRD
preplace inst axis_pfb_readout_v4_0 -pg 1 -lvl 2 -x -930 -y 2500 -defaultsOSRD
preplace inst axis_register_slice_4 -pg 1 -lvl 7 -x 3950 -y 540 -defaultsOSRD
preplace inst axis_register_slice_5 -pg 1 -lvl 7 -x 3950 -y 730 -defaultsOSRD
preplace inst axis_register_slice_6 -pg 1 -lvl 7 -x 3950 -y 890 -defaultsOSRD
preplace inst axis_register_slice_7 -pg 1 -lvl 7 -x 3950 -y 1080 -defaultsOSRD
preplace inst axis_sg_int4_v2_0 -pg 1 -lvl 7 -x 3950 -y 1650 -defaultsOSRD
preplace inst axis_sg_int4_v2_10 -pg 1 -lvl 7 -x 3950 -y 3500 -defaultsOSRD
preplace inst axis_sg_int4_v2_1 -pg 1 -lvl 7 -x 3950 -y 1910 -defaultsOSRD
preplace inst axis_sg_int4_v2_2 -pg 1 -lvl 7 -x 3950 -y 2210 -defaultsOSRD
preplace inst axis_sg_int4_v2_3 -pg 1 -lvl 8 -x 4570 -y 2250 -defaultsOSRD
preplace inst axis_sg_int4_v2_4 -pg 1 -lvl 8 -x 4570 -y 2510 -defaultsOSRD
preplace inst axis_sg_int4_v2_5 -pg 1 -lvl 8 -x 4570 -y 2770 -defaultsOSRD
preplace inst axis_sg_int4_v2_6 -pg 1 -lvl 8 -x 4570 -y 3030 -defaultsOSRD
preplace inst axis_sg_int4_v2_7 -pg 1 -lvl 7 -x 3950 -y 2690 -defaultsOSRD
preplace inst axis_sg_int4_v2_8 -pg 1 -lvl 7 -x 3950 -y 2980 -defaultsOSRD
preplace inst axis_sg_int4_v2_9 -pg 1 -lvl 7 -x 3950 -y 3240 -defaultsOSRD
preplace inst axis_switch_avg -pg 1 -lvl 5 -x 2020 -y 2870 -defaultsOSRD
preplace inst axis_switch_buf -pg 1 -lvl 5 -x 2020 -y 3270 -defaultsOSRD
preplace inst axis_switch_ddr -pg 1 -lvl 5 -x 2020 -y 3950 -defaultsOSRD
preplace inst axis_switch_gen -pg 1 -lvl 5 -x 2020 -y 2480 -defaultsOSRD
preplace inst axis_switch_mr -pg 1 -lvl 5 -x 2020 -y 3590 -defaultsOSRD
preplace inst clk_core -pg 1 -lvl 5 -x 2020 -y 700 -defaultsOSRD
preplace inst ps8_0_axi_periph -pg 1 -lvl 1 -x -2090 -y 940 -defaultsOSRD
preplace inst usp_rf_data_converter_0 -pg 1 -lvl 9 -x 5230 -y 1880 -defaultsOSRD
preplace inst zynq_ultra_ps_e_0 -pg 1 -lvl 6 -x 3000 -y 20 -defaultsOSRD
preplace inst ddr4 -pg 1 -lvl 10 -x 5810 -y 3520 -defaultsOSRD
preplace inst rfb_control -pg 1 -lvl 10 -x 5810 -y -230 -defaultsOSRD
preplace inst pmod_bits_gpio -pg 1 -lvl 9 -x 5230 -y 490 -defaultsOSRD
preplace inst pmod_led_gpio -pg 1 -lvl 9 -x 5230 -y 750 -defaultsOSRD
preplace inst qick_vec2bit_led -pg 1 -lvl 10 -x 5810 -y 790 -defaultsOSRD
preplace inst qick_vec2bit_gpio -pg 1 -lvl 10 -x 5810 -y 470 -defaultsOSRD
preplace inst clk104_gpio -pg 1 -lvl 10 -x 5810 -y 170 -defaultsOSRD
preplace inst axis_broadcaster_10 -pg 1 -lvl 2 -x -930 -y 4140 -defaultsOSRD
preplace inst axis_clk_cnvrt_avg_10 -pg 1 -lvl 4 -x 800 -y 4280 -defaultsOSRD
preplace inst axis_dyn_readout_v1_2 -pg 1 -lvl 2 -x -930 -y 3990 -defaultsOSRD
preplace inst sg_translator_18 -pg 1 -lvl 2 -x -930 -y 3840 -defaultsOSRD
preplace inst axis_avg_buffer_0 -pg 1 -lvl 3 -x -210 -y 1220 -defaultsOSRD
preplace inst axis_avg_buffer_1 -pg 1 -lvl 3 -x -210 -y 1480 -defaultsOSRD
preplace inst axis_avg_buffer_10 -pg 1 -lvl 3 -x -210 -y 3990 -defaultsOSRD
preplace inst axis_avg_buffer_2 -pg 1 -lvl 3 -x -210 -y 1740 -defaultsOSRD
preplace inst axis_avg_buffer_3 -pg 1 -lvl 3 -x -210 -y 2000 -defaultsOSRD
preplace inst axis_avg_buffer_4 -pg 1 -lvl 3 -x -210 -y 2260 -defaultsOSRD
preplace inst axis_avg_buffer_5 -pg 1 -lvl 3 -x -210 -y 2550 -defaultsOSRD
preplace inst axis_avg_buffer_6 -pg 1 -lvl 3 -x -210 -y 2810 -defaultsOSRD
preplace inst axis_avg_buffer_7 -pg 1 -lvl 3 -x -210 -y 3090 -defaultsOSRD
preplace inst axis_avg_buffer_8 -pg 1 -lvl 3 -x -210 -y 3370 -defaultsOSRD
preplace inst axis_avg_buffer_9 -pg 1 -lvl 3 -x -210 -y 3630 -defaultsOSRD
preplace inst mr_buffer_et_0 -pg 1 -lvl 7 -x 3950 -y 3880 -defaultsOSRD
preplace inst qick_processor_0 -pg 1 -lvl 4 -x 800 -y 1300 -defaultsOSRD
preplace netloc DAC_1V8_BIAS_SDO_1 1 9 2 5620 40 NJ
preplace netloc DB_1V8_SDO_1 1 9 2 5610 60 NJ
preplace netloc axi_dma_avg_s2mm_introut 1 4 1 1840 50n
preplace netloc axi_dma_buf_s2mm_introut 1 4 1 1170 80n
preplace netloc axi_dma_gen_mm2s_introut 1 4 1 1190 120n
preplace netloc axi_dma_mr_s2mm_introut 1 4 1 1180 100n
preplace netloc axi_dma_tproc_mm2s_introut 1 4 1 1230 140n
preplace netloc axi_dma_tproc_s2mm_introut 1 4 1 1320 160n
preplace netloc axi_gpio_0_gpio_io_o 1 10 1 6160 160n
preplace netloc axi_intc_0_irq 1 5 1 2250 60n
preplace netloc clk_core_clk_out1 1 3 3 510 -660 N -660 2550
preplace netloc clk_core_locked 1 5 1 2540 710n
preplace netloc ddr4_0_c0_ddr4_ui_clk 1 5 6 2670 -280 N -280 N -280 5070 -270 5570J 20 6000
preplace netloc pmod_bits_gpio_gpio_io_o 1 9 1 5460 470n
preplace netloc pmod_led_gpio_gpio_io_o 1 9 1 5460 760n
preplace netloc qick_processor_0_trig_0_o 1 4 7 NJ 1280 2310J 1260 NJ 1260 4280J 1460 4720J 1390 NJ 1390 6110
preplace netloc qick_processor_0_trig_10_o 1 2 3 -340 -420 NJ -420 1140
preplace netloc qick_processor_0_trig_11_o 1 2 3 -360 -450 NJ -450 990
preplace netloc qick_processor_0_trig_12_o 1 2 3 -350 -430 NJ -430 1150
preplace netloc qick_processor_0_trig_13_o 1 2 3 -400 -690 NJ -690 1110
preplace netloc qick_processor_0_trig_14_o 1 2 3 -380 -680 NJ -680 1160
preplace netloc qick_processor_0_trig_15_o 1 2 3 -370 -240 NJ -240 1090
preplace netloc qick_processor_0_trig_16_o 1 2 3 -340 4130 340J 1730 1090
preplace netloc qick_processor_0_trig_17_o 1 2 3 -380 4160 410J 1800 1120
preplace netloc qick_processor_0_trig_18_o 1 2 3 -350 4140 380J 1810 1060
preplace netloc qick_processor_0_trig_1_o 1 4 7 NJ 1300 2370J 1270 NJ 1270 4260J 1470 4730J 1400 NJ 1400 6120
preplace netloc qick_processor_0_trig_2_o 1 4 7 1650 1490 NJ 1490 NJ 1490 4130J 1500 4740J 1410 NJ 1410 6130J
preplace netloc qick_processor_0_trig_3_o 1 4 7 1600J 1330 2410J 1280 3570J 1250 4270J 1490 4750J 1420 NJ 1420 6140
preplace netloc qick_processor_0_trig_4_o 1 4 7 NJ 1360 2430J 1500 NJ 1500 4110J 1520 4770J 1430 NJ 1430 6150
preplace netloc qick_processor_0_trig_5_o 1 4 7 NJ 1380 2420J 1290 3740J 1510 4100J 1530 4940J 1440 NJ 1440 6160
preplace netloc qick_processor_0_trig_6_o 1 2 3 -390 -550 NJ -550 1000
preplace netloc qick_processor_0_trig_7_o 1 2 3 -410 -460 NJ -460 1070
preplace netloc qick_processor_0_trig_8_o 1 4 3 N 1440 2410J 1520 3520
preplace netloc qick_processor_0_trig_9_o 1 4 6 1640 1450 2390J 1250 3550J 1240 4290J 1480 4760 1450 5430
preplace netloc qick_vec2bit_gpio_dout0 1 10 1 N 400
preplace netloc qick_vec2bit_gpio_dout1 1 10 1 N 420
preplace netloc qick_vec2bit_gpio_dout2 1 10 1 N 440
preplace netloc qick_vec2bit_gpio_dout3 1 10 1 N 460
preplace netloc qick_vec2bit_gpio_dout4 1 10 1 N 480
preplace netloc qick_vec2bit_gpio_dout5 1 10 1 N 500
preplace netloc qick_vec2bit_gpio_dout6 1 10 1 N 520
preplace netloc qick_vec2bit_gpio_dout7 1 10 1 N 540
preplace netloc qick_vec2bit_led_dout0 1 10 1 N 720
preplace netloc qick_vec2bit_led_dout1 1 10 1 N 740
preplace netloc qick_vec2bit_led_dout2 1 10 1 N 760
preplace netloc qick_vec2bit_led_dout3 1 10 1 N 780
preplace netloc qick_vec2bit_led_dout4 1 10 1 N 800
preplace netloc qick_vec2bit_led_dout5 1 10 1 N 820
preplace netloc qick_vec2bit_led_dout6 1 10 1 N 840
preplace netloc qick_vec2bit_led_dout7 1 10 1 N 860
preplace netloc rfb_control_DAC_1V8_BIAS_CLRn 1 10 1 N -310
preplace netloc rfb_control_DAC_1V8_BIAS_S0 1 10 1 N -390
preplace netloc rfb_control_DAC_1V8_BIAS_S1 1 10 1 N -370
preplace netloc rfb_control_DAC_1V8_BIAS_S2 1 10 1 N -350
preplace netloc rfb_control_DAC_1V8_BIAS_SCLK 1 10 1 N -190
preplace netloc rfb_control_DAC_1V8_BIAS_SDIN 1 10 1 N -210
preplace netloc rfb_control_DAC_1V8_BIAS_SWEN 1 10 1 N -170
preplace netloc rfb_control_DAC_1V8_BIAS_SYNCn 1 10 1 N -330
preplace netloc rfb_control_DB_1V8_BRD_SEL 1 10 1 N -230
preplace netloc rfb_control_DB_1V8_BRD_SEL_SEL0 1 10 1 N -290
preplace netloc rfb_control_DB_1V8_BRD_SEL_SEL1 1 10 1 N -270
preplace netloc rfb_control_DB_1V8_BRD_SEL_SEL2 1 10 1 N -250
preplace netloc rfb_control_DB_1V8_CSn 1 10 1 N -30
preplace netloc rfb_control_DB_1V8_PE_CLK 1 10 1 N -130
preplace netloc rfb_control_DB_1V8_PE_LE 1 10 1 N -110
preplace netloc rfb_control_DB_1V8_PE_SI 1 10 1 N -150
preplace netloc rfb_control_DB_1V8_SDI 1 10 1 N -430
preplace netloc rfb_control_DB_1V8_SEL0 1 10 1 N -90
preplace netloc rfb_control_DB_1V8_SEL1 1 10 1 N -70
preplace netloc rfb_control_DB_1V8_SEL2 1 10 1 N -50
preplace netloc rfb_control_DB_1V8_SER_CLK 1 10 1 N -410
preplace netloc rst_100_bus_struct_reset 1 6 4 3360J -230 NJ -230 NJ -230 5440
preplace netloc rst_100_peripheral_reset 1 5 2 2690 -80 3330
preplace netloc rst_adc_peripheral_aresetn 1 1 9 -1220 1160 -550 -260 N -260 1570 1510 N 1510 3530 3680 NJ 3680 5030 3510 N
preplace netloc rst_core_peripheral_aresetn 1 3 4 530 -230 NJ -230 NJ -230 3340
preplace netloc rst_dac2_peripheral_aresetn 1 4 5 1860 1270 2290J 1240 3490 460 4420 1610 4890
preplace netloc rst_dac3_peripheral_aresetn 1 1 8 -1100 1100 -690 1060 480 -220 1780 1540 2350 1540 3600J 2350 4410 2110 4870
preplace netloc rst_ps8_0_99M_peripheral_aresetn 1 0 10 -2250 2070 -1270 1920 -620 1040 420 1820 1620 790 N 790 3610 240 4340 1620 4990 570 5560
preplace netloc usp_rf_data_converter_0_clk_adc2 1 1 9 -1200 1170 -630 4170 440 1860 1580 1860 2500 3520 3470 2050 N 2050 4940 2380 5420
preplace netloc usp_rf_data_converter_0_clk_dac2 1 4 6 1880 1290 2170 540 3810 450 4390 1630 4880 2360 5410
preplace netloc usp_rf_data_converter_0_clk_dac4 1 1 9 -1120 830 N 830 490 -210 1820 870 2360 3550 3800 2060 4190 2100 4860 2370 5370
preplace netloc usp_rf_data_converter_0_irq 1 4 6 1880 -330 NJ -330 NJ -330 4110J -340 NJ -340 5380
preplace netloc xlconcat_1_dout 1 4 2 1860 0 2170
preplace netloc zynq_ultra_ps_e_0_pl_clk0 1 0 10 -2240 2060 -1300 1910 -470 1050 320 -200 1550 -100 2660 -100 3650 -100 4330 1640 4980 580 5550
preplace netloc zynq_ultra_ps_e_0_pl_clk1 1 6 5 3350J -490 NJ -490 NJ -490 NJ -490 6000
preplace netloc zynq_ultra_ps_e_0_pl_resetn0 1 5 2 2680 -90 3320
preplace netloc rst_dac2_peripheral_reset 1 4 3 1880 780 NJ 780 3310
preplace netloc adc2_clk_0_1 1 8 3 5090 2310 5460 2270 N
preplace netloc axi_dma_0_M_AXIS_MM2S1 1 4 1 1730 550n
preplace netloc axi_dma_0_M_AXI_MM2S 1 4 1 1260 440n
preplace netloc axi_dma_0_M_AXI_MM2S1 1 4 1 1270 480n
preplace netloc axi_dma_0_M_AXI_S2MM 1 4 1 1350 460n
preplace netloc axi_dma_avg_M_AXI_S2MM 1 4 1 1830 10n
preplace netloc axi_dma_buf_M_AXI_S2MM 1 4 1 1800 190n
preplace netloc axi_dma_mr_M_AXI_S2MM 1 4 1 1790 370n
preplace netloc axi_dma_tproc_M_AXIS_MM2S 1 3 2 550 -190 1060
preplace netloc axi_interconnect_0_M00_AXI 1 1 3 N 440 N 440 500
preplace netloc axi_interconnect_0_M08_AXI 1 1 8 N 600 N 600 470 870 1560 810 N 810 N 810 4300 1510 N
preplace netloc axis_avg_buffer_0_m0_axis 1 3 2 10 -180 1770
preplace netloc axis_avg_buffer_0_m1_axis 1 3 2 20 -170 1700
preplace netloc axis_avg_buffer_0_m2_axis 1 3 1 90 1240n
preplace netloc axis_avg_buffer_10_m0_axis 1 3 2 480 3130 1650J
preplace netloc axis_avg_buffer_10_m1_axis 1 3 2 500 3360 1090J
preplace netloc axis_avg_buffer_10_m2_axis 1 3 1 -80 4010n
preplace netloc axis_avg_buffer_1_m0_axis 1 3 2 50 -160 1740
preplace netloc axis_avg_buffer_1_m1_axis 1 3 2 70 -150 1660
preplace netloc axis_avg_buffer_1_m2_axis 1 3 1 70 1500n
preplace netloc axis_avg_buffer_2_m0_axis 1 3 2 N 1720 1610
preplace netloc axis_avg_buffer_2_m1_axis 1 3 2 N 1740 1560
preplace netloc axis_avg_buffer_2_m2_axis 1 3 1 50 1760n
preplace netloc axis_avg_buffer_3_m0_axis 1 3 2 -20 1910 1370
preplace netloc axis_avg_buffer_3_m1_axis 1 3 2 40 1920 1310
preplace netloc axis_avg_buffer_3_m2_axis 1 3 1 20 2020n
preplace netloc axis_avg_buffer_4_m0_axis 1 3 2 60 1930 1360
preplace netloc axis_avg_buffer_4_m1_axis 1 3 2 80 2110 1280
preplace netloc axis_avg_buffer_4_m2_axis 1 3 1 10 2280n
preplace netloc axis_avg_buffer_5_m0_axis 1 3 2 N 2530 1300
preplace netloc axis_avg_buffer_5_m1_axis 1 3 2 400 2540 1240
preplace netloc axis_avg_buffer_5_m2_axis 1 3 1 0 2570n
preplace netloc axis_avg_buffer_6_m0_axis 1 3 2 360 2120 1340
preplace netloc axis_avg_buffer_6_m1_axis 1 3 2 370 2130 1250
preplace netloc axis_avg_buffer_6_m2_axis 1 3 1 -20 2830n
preplace netloc axis_avg_buffer_7_m0_axis 1 3 2 430 2150 1290
preplace netloc axis_avg_buffer_7_m1_axis 1 3 2 -10 3100 1220
preplace netloc axis_avg_buffer_7_m2_axis 1 3 1 -50 3110n
preplace netloc axis_avg_buffer_8_m0_axis 1 3 2 -40 3110 1630
preplace netloc axis_avg_buffer_8_m1_axis 1 3 2 N 3370 1880
preplace netloc axis_avg_buffer_8_m2_axis 1 3 1 -60 3390n
preplace netloc axis_avg_buffer_9_m0_axis 1 3 2 460 3120 1640
preplace netloc axis_avg_buffer_9_m1_axis 1 3 2 -70 3340 1110
preplace netloc axis_avg_buffer_9_m2_axis 1 3 1 -70 3650n
preplace netloc axis_broadcaster_0_M00_AXIS 1 2 1 -610 1140n
preplace netloc axis_broadcaster_0_M01_AXIS 1 2 3 -450 3230 -30 3350 1180
preplace netloc axis_broadcaster_10_M00_AXIS 1 2 1 -410 3910n
preplace netloc axis_broadcaster_10_M01_AXIS 1 2 3 N 4150 450J 1890 1190J
preplace netloc axis_broadcaster_1_M00_AXIS 1 2 1 -600 1400n
preplace netloc axis_broadcaster_1_M01_AXIS 1 2 3 -600 2400 330 2140 1200
preplace netloc axis_broadcaster_2_M00_AXIS 1 2 1 -540 1660n
preplace netloc axis_broadcaster_2_M01_AXIS 1 2 3 -670 3770 N 3770 1170
preplace netloc axis_broadcaster_3_M00_AXIS 1 2 1 -570 1920n
preplace netloc axis_broadcaster_3_M01_AXIS 1 2 3 -510 2410 30 1870 1260
preplace netloc axis_broadcaster_4_M00_AXIS 1 2 1 -520 2180n
preplace netloc axis_broadcaster_4_M01_AXIS 1 2 3 -660 3780 N 3780 1160
preplace netloc axis_broadcaster_5_M00_AXIS 1 2 1 -460 2470n
preplace netloc axis_broadcaster_5_M01_AXIS 1 2 3 -680 3790 N 3790 1150
preplace netloc axis_broadcaster_6_M00_AXIS 1 2 1 -440 2730n
preplace netloc axis_broadcaster_6_M01_AXIS 1 2 3 -700 3800 N 3800 1140
preplace netloc axis_broadcaster_7_M00_AXIS 1 2 1 -430 3010n
preplace netloc axis_broadcaster_7_M01_AXIS 1 2 3 -710 3810 N 3810 1120
preplace netloc axis_broadcaster_8_M00_AXIS 1 2 1 -420 3290n
preplace netloc axis_broadcaster_8_M01_AXIS 1 2 3 -720 3820 N 3820 1110
preplace netloc axis_broadcaster_9_M00_AXIS 1 2 1 -430 3550n
preplace netloc axis_broadcaster_9_M01_AXIS 1 2 3 -730 3830 350 1880 1210
preplace netloc axis_cdcsync_v1_0_m0_axis 1 5 1 2530 1060n
preplace netloc axis_cdcsync_v1_0_m1_axis 1 5 1 2520 1080n
preplace netloc axis_cdcsync_v1_0_m2_axis 1 5 1 2510 1100n
preplace netloc axis_cdcsync_v1_0_m3_axis 1 5 1 2460 1120n
preplace netloc axis_cdcsync_v1_2_m0_axis 1 1 2 -1120 1140 -750
preplace netloc axis_cdcsync_v1_2_m1_axis 1 1 2 -1180 1690 -730
preplace netloc axis_cdcsync_v1_2_m2_axis 1 1 2 -1170 1700 -740
preplace netloc axis_clk_cnvrt_avg_0_M_AXIS 1 3 2 560 -140 1010
preplace netloc axis_clk_cnvrt_avg_1_M_AXIS 1 3 2 570 -130 1030
preplace netloc axis_clk_cnvrt_avg_2_M_AXIS 1 3 2 580 -120 1050
preplace netloc axis_clk_cnvrt_avg_3_M_AXIS 1 3 2 590 -110 1130
preplace netloc axis_clk_cnvrt_avg_4_M_AXIS 1 3 2 620 1750 1070
preplace netloc axis_clk_cnvrt_avg_5_M_AXIS 1 3 2 600 -100 1080
preplace netloc axis_clk_cnvrt_avg_6_M_AXIS 1 3 2 600 1760 990
preplace netloc axis_clk_cnvrt_avg_7_M_AXIS 1 3 2 590 1770 1140
preplace netloc axis_dyn_readout_v1_0_m0_axis 1 2 3 -660 1070 410 1780 1350
preplace netloc axis_dyn_readout_v1_0_m1_axis 1 1 2 -1120 1340 -750
preplace netloc axis_dyn_readout_v1_1_m0_axis 1 2 3 -480 2950 100 1900 1270
preplace netloc axis_dyn_readout_v1_1_m1_axis 1 1 2 -1120 1930 -770
preplace netloc axis_dyn_readout_v1_2_m0_axis 1 2 3 -430 3850 490J 3570 1860J
preplace netloc axis_dyn_readout_v1_2_m1_axis 1 1 2 -1110 3750 -740
preplace netloc axis_pfb_readout_v4_0_m0_axis 1 1 2 -1130 2310 -750
preplace netloc axis_pfb_readout_v4_0_m1_axis 1 1 2 -1110 2320 -740
preplace netloc axis_pfb_readout_v4_0_m2_axis 1 1 2 -1100 2330 -730
preplace netloc axis_pfb_readout_v4_0_m3_axis 1 1 2 -1140 2340 -720
preplace netloc axis_pfb_readout_v4_0_m4_axis 1 1 2 -1120 2350 -710
preplace netloc axis_pfb_readout_v4_0_m5_axis 1 1 2 -1150 2300 -700
preplace netloc axis_pfb_readout_v4_0_m6_axis 1 1 2 -1160 2360 -770
preplace netloc axis_pfb_readout_v4_0_m7_axis 1 1 2 -1090 2370 -760
preplace netloc axis_register_slice_0_m_axis 1 8 1 4970 140n
preplace netloc axis_register_slice_1_m_axis 1 8 1 4960 540n
preplace netloc axis_register_slice_2_m_axis 1 8 1 4950 960n
preplace netloc axis_register_slice_3_m_axis 1 8 1 4930 1360n
preplace netloc axis_register_slice_4_M_AXIS 1 7 1 4100 -150n
preplace netloc axis_register_slice_5_M_AXIS 1 7 1 4110 280n
preplace netloc axis_register_slice_6_M_AXIS 1 7 1 4120 700n
preplace netloc axis_register_slice_7_M_AXIS 1 7 1 4370 1080n
preplace netloc axis_sg_int4_v2_0_m_axis 1 7 2 NJ 1650 4920
preplace netloc axis_sg_int4_v2_10_m_axis 1 7 2 4400 1830 N
preplace netloc axis_sg_int4_v2_1_m_axis 1 7 2 4110 1660 4950J
preplace netloc axis_sg_int4_v2_2_m_axis 1 7 2 4230 1670 NJ
preplace netloc axis_sg_int4_v2_3_m_axis 1 8 1 4700 1690n
preplace netloc axis_sg_int4_v2_4_m_axis 1 8 1 5000 1710n
preplace netloc axis_sg_int4_v2_5_m_axis 1 8 1 5010 1730n
preplace netloc axis_sg_int4_v2_6_m_axis 1 8 1 5020 1750n
preplace netloc axis_sg_int4_v2_7_m_axis 1 7 2 4100 1770 NJ
preplace netloc axis_sg_int4_v2_8_m_axis 1 7 2 4350 1790 N
preplace netloc axis_sg_int4_v2_9_m_axis 1 7 2 4380 1810 N
preplace netloc axis_sg_mixmux8_v1_0_m_axis 1 7 2 4120J 1540 4910
preplace netloc axis_signal_gen_v6_0_m_axis 1 7 2 4440 60 4700
preplace netloc axis_signal_gen_v6_1_m_axis 1 7 2 4440 620 4700
preplace netloc axis_signal_gen_v6_2_m_axis 1 7 2 4440 1440 4710
preplace netloc axis_signal_gen_v6_3_m_axis 1 7 2 4430 1450 4700
preplace netloc axis_switch_0_M00_AXIS 1 5 3 2300 -160 N -160 4110
preplace netloc axis_switch_avg_M00_AXIS 1 3 3 420 -670 NJ -670 2160
preplace netloc axis_switch_buf_M00_AXIS 1 3 3 520 -530 NJ -530 2180
preplace netloc axis_switch_ddr_M00_AXIS 1 5 5 2170 4030 N 4030 4440 3450 N 3450 N
preplace netloc axis_switch_gen_M01_AXIS 1 5 3 2220 3570 3480 3640 4250
preplace netloc axis_switch_gen_M02_AXIS 1 5 3 2230 3530 3510 3650 4320
preplace netloc axis_switch_gen_M03_AXIS 1 5 3 2200 1010 3520 1000 4380
preplace netloc axis_switch_gen_M04_AXIS 1 5 2 2260 1560 3740
preplace netloc axis_switch_gen_M05_AXIS 1 5 2 2450 1720 3710
preplace netloc axis_switch_gen_M06_AXIS 1 5 2 2480 1880 3680
preplace netloc axis_switch_gen_M07_AXIS 1 5 3 2260 3480 3330 2070 4200
preplace netloc axis_switch_gen_M08_AXIS 1 5 3 2560 1890 3630 2430 N
preplace netloc axis_switch_gen_M09_AXIS 1 5 3 2570 1900 3590 2550 4200
preplace netloc axis_switch_gen_M10_AXIS 1 5 3 2200 3540 3330 3660 4420
preplace netloc axis_switch_gen_M11_AXIS 1 5 2 2300 2480 3550
preplace netloc axis_switch_gen_M12_AXIS 1 5 2 2240 3490 3770
preplace netloc axis_switch_gen_M13_AXIS 1 5 2 2210 3500 3480
preplace netloc axis_switch_gen_M14_AXIS 1 5 2 2190 3510 3780
preplace netloc axis_switch_mr_M00_AXIS 1 5 2 N 3590 3310
preplace netloc axis_tmux_v1_0_m0_axis 1 4 2 N 1990 2330
preplace netloc axis_tmux_v1_0_m1_axis 1 1 4 -1200 -500 N -500 N -500 1020
preplace netloc axis_tmux_v1_0_m2_axis 1 1 4 -1100 -490 N -490 N -490 1040
preplace netloc axis_tmux_v1_0_m3_axis 1 1 4 -1220 -380 NJ -380 NJ -380 1100
preplace netloc dac2_clk_0_1 1 8 3 5070 2330 5570 2290 N
preplace netloc ddr4_0_C0_DDR4 1 10 1 6060 3510n
preplace netloc default_sysclk_c0_300mhz_1 1 9 2 5620J 3660 6160
preplace netloc mr_buffer_et_0_m00_axis 1 3 5 620 -400 N -400 N -400 N -400 4090
preplace netloc ps8_0_axi_periph_M01_AXI 1 1 2 -1630 1680 N
preplace netloc ps8_0_axi_periph_M02_AXI 1 1 7 -1890 -350 N -350 N -350 N -350 N -350 N -350 4420
preplace netloc ps8_0_axi_periph_M03_AXI 1 1 2 -1660 2250 -530
preplace netloc ps8_0_axi_periph_M04_AXI 1 1 6 -1920 -550 -430 -640 490 -650 N -650 2180 -640 3800
preplace netloc ps8_0_axi_periph_M05_AXI 1 1 4 N 540 N 540 460 1830 1320
preplace netloc ps8_0_axi_periph_M06_AXI 1 1 3 -1750 530 N 530 N
preplace netloc ps8_0_axi_periph_M07_AXI 1 1 4 N 580 N 580 440 1840 1590
preplace netloc ps8_0_axi_periph_M09_AXI 1 1 2 N 620 -440
preplace netloc ps8_0_axi_periph_M10_AXI 1 1 2 -1640 1120 -450
preplace netloc ps8_0_axi_periph_M11_AXI 1 1 2 -1670 1720 -750
preplace netloc ps8_0_axi_periph_M12_AXI 1 1 2 -1680 1710 -440
preplace netloc ps8_0_axi_periph_M13_AXI 1 1 2 -1720 2270 -500
preplace netloc ps8_0_axi_periph_M14_AXI 1 1 2 -1710 1730 -490
preplace netloc ps8_0_axi_periph_M15_AXI 1 1 2 -1750 2260 -580
preplace netloc ps8_0_axi_periph_M16_AXI 1 1 2 -1810 2290 -560
preplace netloc ps8_0_axi_periph_M17_AXI 1 1 4 -1820 2280 -690 3840 470 3140 1060
preplace netloc ps8_0_axi_periph_M18_AXI 1 1 4 N 800 N 800 390 1850 1330
preplace netloc ps8_0_axi_periph_M19_AXI 1 1 3 -1780 -10 N -10 N
preplace netloc ps8_0_axi_periph_M20_AXI 1 1 3 -1760 170 N 170 N
preplace netloc ps8_0_axi_periph_M21_AXI 1 1 3 -1730 350 N 350 N
preplace netloc ps8_0_axi_periph_M22_AXI 1 1 9 -1940 -650 N -650 480 -640 N -640 2300 -650 N -650 N -650 N -650 5590
preplace netloc ps8_0_axi_periph_M23_AXI 1 1 4 -1690 840 N 840 430 1790 1230
preplace netloc ps8_0_axi_periph_M24_AXI 1 1 6 -1930 -630 N -630 N -630 N -630 N -630 3790
preplace netloc ps8_0_axi_periph_M25_AXI 1 1 6 -1910 -620 N -620 N -620 N -620 N -620 3640
preplace netloc ps8_0_axi_periph_M26_AXI 1 1 4 -1790 -340 N -340 N -340 1850
preplace netloc ps8_0_axi_periph_M27_AXI 1 1 6 -1900 -610 N -610 N -610 N -610 N -610 3770
preplace netloc ps8_0_axi_periph_M28_AXI 1 1 1 -1850 1000n
preplace netloc ps8_0_axi_periph_M29_AXI 1 1 6 -1880 -600 NJ -600 NJ -600 NJ -600 NJ -600 3750
preplace netloc ps8_0_axi_periph_M30_AXI 1 1 7 -1870 -580 NJ -580 NJ -580 NJ -580 NJ -580 N -580 4360
preplace netloc ps8_0_axi_periph_M31_AXI 1 1 7 -1860 -570 NJ -570 NJ -570 NJ -570 NJ -570 NJ -570 4310
preplace netloc ps8_0_axi_periph_M32_AXI 1 1 3 -1690 1090 -670 1080 400
preplace netloc ps8_0_axi_periph_M33_AXI 1 1 7 -1840 -560 NJ -560 NJ -560 NJ -560 NJ -560 NJ -560 4240
preplace netloc ps8_0_axi_periph_M34_AXI 1 1 7 -1800 -540 NJ -540 NJ -540 NJ -540 NJ -540 NJ -540 4220
preplace netloc ps8_0_axi_periph_M35_AXI 1 1 6 -1770 -520 NJ -520 NJ -520 NJ -520 NJ -520 3730J
preplace netloc ps8_0_axi_periph_M36_AXI 1 1 6 -1740 -510 NJ -510 NJ -510 NJ -510 NJ -510 3700
preplace netloc ps8_0_axi_periph_M37_AXI 1 1 6 -1830 -590 NJ -590 NJ -590 NJ -590 NJ -590 3720
preplace netloc ps8_0_axi_periph_M38_AXI 1 1 6 -1700 -480 NJ -480 NJ -480 NJ -480 NJ -480 3660
preplace netloc ps8_0_axi_periph_M39_AXI 1 1 7 -1580 850 NJ 850 450J 880 NJ 880 2200J 530 3350 300 N
preplace netloc ps8_0_axi_periph_M40_AXI 1 1 7 -1560 1110 -710J 1020 30J -90 1810J 770 NJ 770 3500 650 4380
preplace netloc ps8_0_axi_periph_M41_AXI 1 1 7 -1650 -470 NJ -470 NJ -470 NJ -470 NJ -470 N -470 4400
preplace netloc ps8_0_axi_periph_M42_AXI 1 1 8 -1540 1130 -720J 940 -20J -310 NJ -310 NJ -310 NJ -310 NJ -310 5080
preplace netloc ps8_0_axi_periph_M43_AXI 1 1 8 -1530 1150 -700J 950 0J -270 NJ -270 NJ -270 NJ -270 NJ -270 5060
preplace netloc ps8_0_axi_periph_M44_AXI 1 1 9 -1620 -330 N -330 NJ -330 1870J -340 NJ -340 NJ -340 4100J -330 NJ -330 5610J
preplace netloc ps8_0_axi_periph_M45_AXI 1 1 9 -1600 -290 NJ -290 NJ -290 1780J -260 NJ -260 NJ -260 NJ -260 NJ -260 5580
preplace netloc ps8_0_axi_periph_M46_AXI 1 1 9 -1610 -300 NJ -300 NJ -300 NJ -300 NJ -300 NJ -300 NJ -300 NJ -300 5600
preplace netloc ps8_0_axi_periph_M47_AXI 1 1 9 -1570 -280 N -280 NJ -280 1820J -290 NJ -290 NJ -290 NJ -290 5090J -310 NJ
preplace netloc ps8_0_axi_periph_M48_AXI 1 1 9 -1590 -320 NJ -320 NJ -320 NJ -320 NJ -320 NJ -320 NJ -320 NJ -320 5620
preplace netloc ps8_0_axi_periph_M49_AXI 1 1 9 -1550 -250 NJ -250 NJ -250 NJ -250 NJ -250 NJ -250 NJ -250 NJ -250 5460
preplace netloc ps8_0_axi_periph_M50_AXI 1 1 2 -1740J 1520 -590
preplace netloc qick_processor_0_m0_axis 1 4 1 1170 940n
preplace netloc qick_processor_0_m10_axis 1 4 2 1710J 1230 2400
preplace netloc qick_processor_0_m11_axis 1 4 2 1680J 1320 2310
preplace netloc qick_processor_0_m12_axis 1 4 2 1670J 1310 2320
preplace netloc qick_processor_0_m13_axis 1 4 2 N 1220 2280
preplace netloc qick_processor_0_m14_axis 1 4 2 N 1240 2270
preplace netloc qick_processor_0_m15_axis 1 4 2 N 1260 2250
preplace netloc qick_processor_0_m1_axis 1 4 1 1600 960n
preplace netloc qick_processor_0_m2_axis 1 4 1 1760 980n
preplace netloc qick_processor_0_m3_axis 1 4 1 1750 1000n
preplace netloc qick_processor_0_m4_axis 1 3 2 540 -80 980
preplace netloc qick_processor_0_m5_axis 1 4 2 1590J 950 2490
preplace netloc qick_processor_0_m6_axis 1 4 2 1690J 1340 2340
preplace netloc qick_processor_0_m7_axis 1 4 2 1580J 940 2470
preplace netloc qick_processor_0_m8_axis 1 4 2 1610J 960 2440
preplace netloc qick_processor_0_m9_axis 1 4 2 1720J 1250 2380
preplace netloc qick_processor_0_m_dma_axis_o 1 3 2 610 -70 1120
preplace netloc sg_translator_0_m_gen_v6_axis 1 6 1 3510 520n
preplace netloc sg_translator_10_m_gen_v6_axis 1 6 2 3500 3670 4430
preplace netloc sg_translator_11_m_gen_v6_axis 1 6 1 3750 2630n
preplace netloc sg_translator_12_m_mux4_axis 1 6 1 3620 1330n
preplace netloc sg_translator_13_m_gen_v6_axis 1 6 1 3490 2920n
preplace netloc sg_translator_14_m_gen_v6_axis 1 6 1 3790 3180n
preplace netloc sg_translator_15_m_gen_v6_axis 1 6 1 3810 3440n
preplace netloc sg_translator_18_m_readout_v3_axis 1 1 2 -1090 3760 -750
preplace netloc sg_translator_1_m_gen_v6_axis 1 6 1 3540 710n
preplace netloc sg_translator_2_m_gen_v6_axis 1 6 1 3560 870n
preplace netloc sg_translator_3_m_gen_v6_axis 1 6 1 3580 1060n
preplace netloc sg_translator_4_m_gen_v6_axis 1 6 1 3670 1590n
preplace netloc sg_translator_5_m_gen_v6_axis 1 6 1 3690 1850n
preplace netloc sg_translator_6_m_gen_v6_axis 1 6 1 3740 2150n
preplace netloc sg_translator_6_m_readout_v3_axis 1 1 2 -1100 1180 -750
preplace netloc sg_translator_7_m_gen_v6_axis 1 6 2 N 2840 4390
preplace netloc sg_translator_7_m_readout_v3_axis 1 1 2 -1100 1750 -770
preplace netloc sg_translator_8_m_gen_v6_axis 1 6 2 3320 2450 N
preplace netloc sg_translator_9_m_gen_v6_axis 1 6 2 3760 2830 4100
preplace netloc smartconnect_0_M00_AXI 1 5 1 2200 -20n
preplace netloc sysref_in_0_1 1 8 3 5040 2390 N 2390 N
preplace netloc usp_rf_data_converter_0_m10_axis 1 1 9 -1240 -410 NJ -410 NJ -410 NJ -410 NJ -410 NJ -410 NJ -410 NJ -410 5370
preplace netloc usp_rf_data_converter_0_m20_axis 1 1 9 -1230 -390 N -390 N -390 N -390 N -390 N -390 N -390 N -390 5400
preplace netloc usp_rf_data_converter_0_m21_axis 1 1 9 -1210 -370 N -370 N -370 N -370 N -370 N -370 N -370 N -370 5390
preplace netloc usp_rf_data_converter_0_m22_axis 1 1 9 -1190 -360 N -360 N -360 N -360 N -360 N -360 N -360 N -360 5410
preplace netloc usp_rf_data_converter_0_vout00 1 9 2 N 1700 6160
preplace netloc usp_rf_data_converter_0_vout01 1 9 2 N 1720 6150
preplace netloc usp_rf_data_converter_0_vout02 1 9 2 N 1740 6140
preplace netloc usp_rf_data_converter_0_vout03 1 9 2 N 1760 6130
preplace netloc usp_rf_data_converter_0_vout10 1 9 2 N 1780 6120
preplace netloc usp_rf_data_converter_0_vout11 1 9 2 N 1800 6110
preplace netloc usp_rf_data_converter_0_vout12 1 9 2 N 1820 6100
preplace netloc usp_rf_data_converter_0_vout13 1 9 2 N 1840 6090
preplace netloc usp_rf_data_converter_0_vout20 1 9 2 N 1860 6080
preplace netloc usp_rf_data_converter_0_vout21 1 9 2 N 1880 6070
preplace netloc usp_rf_data_converter_0_vout22 1 9 2 N 1900 6060
preplace netloc usp_rf_data_converter_0_vout23 1 9 2 N 1920 6050
preplace netloc usp_rf_data_converter_0_vout30 1 9 2 N 1940 6040
preplace netloc usp_rf_data_converter_0_vout31 1 9 2 N 1960 6030
preplace netloc usp_rf_data_converter_0_vout32 1 9 2 N 1980 6020
preplace netloc usp_rf_data_converter_0_vout33 1 9 2 N 2000 6010
preplace netloc vin20_0_1 1 8 3 5080 2320 N 2320 6160
preplace netloc vin21_0_1 1 8 3 5060 2340 5580 2330 N
preplace netloc vin22_0_1 1 8 3 5050 2350 N 2350 N
preplace netloc zynq_ultra_ps_e_0_M_AXI_HPM0_FPD 1 0 7 -2240 -440 N -440 N -440 N -440 N -440 N -440 3310
preplace netloc zynq_ultra_ps_e_0_M_AXI_HPM1_FPD 1 6 4 N 0 4410 50 N 50 5450
levelinfo -pg 1 -2270 -2090 -930 -210 800 2020 3000 3950 4570 5230 5810 6180
pagesize -pg 1 -db -bbox -sgen -2270 -1000 6480 9360
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


