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

create_bd_design "system"
update_compile_order -fileset sources_1
startgroup
create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 processing_system7_0
endgroup
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 -config {make_external "FIXED_IO, DDR" apply_board_preset "1" Master "Disable" Slave "Disable" }  [get_bd_cells processing_system7_0]
startgroup
set_property -dict [list CONFIG.PCW_USE_M_AXI_GP0 {0} CONFIG.PCW_EN_CLK0_PORT {0} CONFIG.PCW_EN_RST0_PORT {0} CONFIG.PCW_QSPI_PERIPHERAL_ENABLE {0} CONFIG.PCW_QSPI_GRP_SINGLE_SS_ENABLE {1} CONFIG.PCW_ENET0_PERIPHERAL_ENABLE {0} CONFIG.PCW_SD0_PERIPHERAL_ENABLE {0} CONFIG.PCW_UART0_PERIPHERAL_ENABLE {0} CONFIG.PCW_UART1_PERIPHERAL_ENABLE {0} CONFIG.PCW_TTC0_PERIPHERAL_ENABLE {0} CONFIG.PCW_USB0_PERIPHERAL_ENABLE {0} CONFIG.PCW_USB_RESET_ENABLE {0} CONFIG.PCW_I2C_RESET_ENABLE {0} CONFIG.PCW_GPIO_MIO_GPIO_ENABLE {1} CONFIG.PCW_GPIO_MIO_GPIO_IO {MIO} CONFIG.PCW_GPIO_EMIO_GPIO_ENABLE {1} CONFIG.PCW_GPIO_EMIO_GPIO_IO {1}] [get_bd_cells processing_system7_0]
endgroup
startgroup
create_bd_port -dir O -from 0 -to 0 GPIO_O
connect_bd_net [get_bd_pins /processing_system7_0/GPIO_O] [get_bd_ports GPIO_O]
endgroup
regenerate_bd_layout
validate_bd_design
generate_target all [get_files  ./lab2.srcs/sources_1/bd/system/system.bd]
export_ip_user_files -of_objects [get_files ./lab2.srcs/sources_1/bd/system/system.bd] -no_script -force -quiet
export_simulation -of_objects [get_files ./lab2.srcs/sources_1/bd/system/system.bd] -directory ./lab2.ip_user_files/sim_scripts -force -quiet
make_wrapper -files [get_files ./lab2.srcs/sources_1/bd/system/system.bd] -top
add_files -norecurse ./lab2.gen/sources_1/bd/system/hdl/system_wrapper.v
update_compile_order -fileset sources_1 