// (c) Copyright 1995-2021 Xilinx, Inc. All rights reserved.
// 
// This file contains confidential and proprietary information
// of Xilinx, Inc. and is protected under U.S. and
// international copyright and other intellectual property
// laws.
// 
// DISCLAIMER
// This disclaimer is not a license and does not grant any
// rights to the materials distributed herewith. Except as
// otherwise provided in a valid license issued to you by
// Xilinx, and to the maximum extent permitted by applicable
// law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
// WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
// AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
// BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
// INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
// (2) Xilinx shall not be liable (whether in contract or tort,
// including negligence, or under any other theory of
// liability) for any loss or damage of any kind or nature
// related to, arising under or in connection with these
// materials, including for any direct, or any indirect,
// special, incidental, or consequential loss or damage
// (including loss of data, profits, goodwill, or any type of
// loss or damage suffered as a result of any action brought
// by a third party) even if such damage or loss was
// reasonably foreseeable or Xilinx had been advised of the
// possibility of the same.
// 
// CRITICAL APPLICATIONS
// Xilinx products are not designed or intended to be fail-
// safe, or for use in any application requiring fail-safe
// performance, such as life-support or safety devices or
// systems, Class III medical devices, nuclear facilities,
// applications related to the deployment of airbags, or any
// other applications that could lead to death, personal
// injury, or severe property or environmental damage
// (individually and collectively, "Critical
// Applications"). Customer assumes the sole risk and
// liability of any use of Xilinx products in Critical
// Applications, subject only to applicable laws and
// regulations governing limitations on product liability.
// 
// THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
// PART OF THIS FILE AT ALL TIMES.
// 
// DO NOT MODIFY THIS FILE.

//-----------------------------------------------------------------------------
// Filename:    axi_mst_0_stub.sv
// Description: This HDL file is intended to be used with Xilinx Vivado Simulator (XSIM) only.
//-----------------------------------------------------------------------------
`ifdef XILINX_SIMULATOR

`ifndef XILINX_SIMULATOR_BITASBOOL
`define XILINX_SIMULATOR_BITASBOOL
typedef bit bit_as_bool;
`endif

(* SC_MODULE_EXPORT *)
module axi_mst_0 (
  input bit_as_bool aclk,
  input bit_as_bool aresetn,
  output bit [31 : 0] m_axi_awaddr,
  output bit [2 : 0] m_axi_awprot,
  output bit_as_bool m_axi_awvalid,
  input bit_as_bool m_axi_awready,
  output bit [31 : 0] m_axi_wdata,
  output bit [3 : 0] m_axi_wstrb,
  output bit_as_bool m_axi_wvalid,
  input bit_as_bool m_axi_wready,
  input bit [1 : 0] m_axi_bresp,
  input bit_as_bool m_axi_bvalid,
  output bit_as_bool m_axi_bready,
  output bit [31 : 0] m_axi_araddr,
  output bit [2 : 0] m_axi_arprot,
  output bit_as_bool m_axi_arvalid,
  input bit_as_bool m_axi_arready,
  input bit [31 : 0] m_axi_rdata,
  input bit [1 : 0] m_axi_rresp,
  input bit_as_bool m_axi_rvalid,
  output bit_as_bool m_axi_rready
);
endmodule
`endif
