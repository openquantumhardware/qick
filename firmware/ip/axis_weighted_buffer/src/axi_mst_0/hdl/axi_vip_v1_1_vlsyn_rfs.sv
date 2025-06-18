//  (c) Copyright 2016 Xilinx, Inc. All rights reserved.
//
//  This file contains confidential and proprietary information
//  of Xilinx, Inc. and is protected under U.S. and
//  international copyright and other intellectual property
//  laws.
//
//  DISCLAIMER
//  This disclaimer is not a license and does not grant any
//  rights to the materials distributed herewith. Except as
//  otherwise provided in a valid license issued to you by
//  Xilinx, and to the maximum extent permitted by applicable
//  law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
//  WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
//  AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
//  BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
//  INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
//  (2) Xilinx shall not be liable (whether in contract or tort,
//  including negligence, or under any other theory of
//  liability) for any loss or damage of any kind or nature
//  related to, arising under or in connection with these
//  materials, including for any direct, or any indirect,
//  special, incidental, or consequential loss or damage
//  (including loss of data, profits, goodwill, or any type of
//  loss or damage suffered as a result of any action brought
//  by a third party) even if such damage or loss was
//  reasonably foreseeable or Xilinx had been advised of the
//  possibility of the same.
//
//  CRITICAL APPLICATIONS
//  Xilinx products are not designed or intended to be fail-
//  safe, or for use in any application requiring fail-safe
//  performance, such as life-support or safety devices or
//  systems, Class III medical devices, nuclear facilities,
//  applications related to the deployment of airbags, or any
//  other applications that could lead to death, personal
//  injury, or severe property or environmental damage
//  (individually and collectively, "Critical
//  Applications"). Customer assumes the sole risk and
//  liability of any use of Xilinx products in Critical
//  Applications, subject only to applicable laws and
//  regulations governing limitations on product liability.
//
//  THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
//  PART OF THIS FILE AT ALL TIMES. 
//-----------------------------------------------------------------------------
//
// AXI VIP wrapper
//
// Verilog-standard:  Verilog 2001
//--------------------------------------------------------------------------
//
// Structure:
//   axi_vip
//
//--------------------------------------------------------------------------

`timescale 1ps/1ps

(* DowngradeIPIdentifiedWarnings="yes" *) 
module axi_vip_v1_1_14_top #
  (
   parameter C_AXI_PROTOCOL                      = 0,
   parameter C_AXI_INTERFACE_MODE                = 1,  //master, slave and bypass
   parameter integer C_AXI_ADDR_WIDTH            = 32,
   parameter integer C_AXI_WDATA_WIDTH           = 32,
   parameter integer C_AXI_RDATA_WIDTH           = 32,
   parameter integer C_AXI_WID_WIDTH             = 0,
   parameter integer C_AXI_RID_WIDTH             = 0,
   parameter integer C_AXI_AWUSER_WIDTH          = 0,
   parameter integer C_AXI_ARUSER_WIDTH          = 0,
   parameter integer C_AXI_WUSER_WIDTH           = 0,
   parameter integer C_AXI_RUSER_WIDTH           = 0,
   parameter integer C_AXI_BUSER_WIDTH           = 0,
   parameter integer C_AXI_SUPPORTS_NARROW       = 1,
   parameter integer C_AXI_HAS_BURST             = 1,
   parameter integer C_AXI_HAS_LOCK              = 1,
   parameter integer C_AXI_HAS_CACHE             = 1,
   parameter integer C_AXI_HAS_REGION            = 1,
   parameter integer C_AXI_HAS_PROT              = 1,
   parameter integer C_AXI_HAS_QOS               = 1,
   parameter integer C_AXI_HAS_WSTRB             = 1,
   parameter integer C_AXI_HAS_BRESP             = 1,
   parameter integer C_AXI_HAS_RRESP             = 1,
   parameter integer C_AXI_HAS_ARESETN           = 1
   )
  (
   //NOTE:  C_AXI_INTERFACE_MODE =0 means MASTER MODE, 1 means PASS-THROUGH MODE and 2 means SLAVE MODE
   //Please refer xgui tcl and coreinfo.yml
   
   // System Signals
   input wire aclk,
   input wire aclken,
   input wire aresetn,

   // Slave Interface Write Address Ports
   input  wire [C_AXI_WID_WIDTH==0?0:C_AXI_WID_WIDTH-1:0]       s_axi_awid,
   input  wire [C_AXI_ADDR_WIDTH-1:0]                           s_axi_awaddr,
   input  wire [((C_AXI_PROTOCOL == 1) ? 4 : 8)-1:0]            s_axi_awlen,
   input  wire [3-1:0]                                          s_axi_awsize,
   input  wire [2-1:0]                                          s_axi_awburst,
   input  wire [((C_AXI_PROTOCOL == 1) ? 2 : 1)-1:0]            s_axi_awlock,
   input  wire [4-1:0]                                          s_axi_awcache,
   input  wire [3-1:0]                                          s_axi_awprot,
   input  wire [4-1:0]                                          s_axi_awregion,
   input  wire [4-1:0]                                          s_axi_awqos,
   input  wire [C_AXI_AWUSER_WIDTH==0?0:C_AXI_AWUSER_WIDTH-1:0] s_axi_awuser,
   input  wire                                                  s_axi_awvalid,
   output wire                                                  s_axi_awready,

   // Slave Interface Write Data Ports
   input  wire [C_AXI_WID_WIDTH==0?0:C_AXI_WID_WIDTH-1:0]       s_axi_wid,
   input  wire [C_AXI_WDATA_WIDTH-1:0]                          s_axi_wdata,
   input  wire [C_AXI_WDATA_WIDTH/8-1:0]                        s_axi_wstrb,
   input  wire                                                  s_axi_wlast,
   input  wire [C_AXI_WUSER_WIDTH==0?0:C_AXI_WUSER_WIDTH-1:0]   s_axi_wuser,
   input  wire                                                  s_axi_wvalid,
   output wire                                                  s_axi_wready,
 
   // Slave Interface Write Response Ports
   output wire [C_AXI_WID_WIDTH==0?0:C_AXI_WID_WIDTH-1:0]       s_axi_bid,
   output wire [2-1:0]                                          s_axi_bresp,
   output wire [C_AXI_BUSER_WIDTH==0?0:C_AXI_BUSER_WIDTH-1:0]   s_axi_buser,
   output wire                                                  s_axi_bvalid,
   input  wire                                                  s_axi_bready,

   // Slave Interface Read Address Ports
   input  wire [C_AXI_RID_WIDTH==0?0:C_AXI_RID_WIDTH-1:0]       s_axi_arid,
   input  wire [C_AXI_ADDR_WIDTH-1:0]                           s_axi_araddr,
   input  wire [((C_AXI_PROTOCOL == 1) ? 4 : 8)-1:0]            s_axi_arlen,
   input  wire [3-1:0]                                          s_axi_arsize,
   input  wire [2-1:0]                                          s_axi_arburst,
   input  wire [((C_AXI_PROTOCOL == 1) ? 2 : 1)-1:0]            s_axi_arlock,
   input  wire [4-1:0]                                          s_axi_arcache,
   input  wire [3-1:0]                                          s_axi_arprot,
   input  wire [4-1:0]                                          s_axi_arregion,
   input  wire [4-1:0]                                          s_axi_arqos,
   input  wire [C_AXI_ARUSER_WIDTH==0?0:C_AXI_ARUSER_WIDTH-1:0] s_axi_aruser,
   input  wire                                                  s_axi_arvalid,
   output wire                                                  s_axi_arready,

   // Slave Interface Read Data Ports
   output wire [C_AXI_RID_WIDTH==0?0:C_AXI_RID_WIDTH-1:0]       s_axi_rid,
   output wire [C_AXI_RDATA_WIDTH-1:0]                          s_axi_rdata,
   output wire [2-1:0]                                          s_axi_rresp,
   output wire                                                  s_axi_rlast,
   output wire [C_AXI_RUSER_WIDTH==0?0:C_AXI_RUSER_WIDTH-1:0]   s_axi_ruser,
   output wire                                                  s_axi_rvalid,
   input  wire                                                  s_axi_rready,
    
   // Master Interface Write Address Port
   output wire [C_AXI_WID_WIDTH==0?0:C_AXI_WID_WIDTH-1:0]       m_axi_awid,
   output wire [C_AXI_ADDR_WIDTH-1:0]                           m_axi_awaddr,
   output wire [((C_AXI_PROTOCOL == 1) ? 4 : 8)-1:0]            m_axi_awlen,
   output wire [3-1:0]                                          m_axi_awsize,
   output wire [2-1:0]                                          m_axi_awburst,
   output wire [((C_AXI_PROTOCOL == 1) ? 2 : 1)-1:0]            m_axi_awlock,
   output wire [4-1:0]                                          m_axi_awcache,
   output wire [3-1:0]                                          m_axi_awprot,
   output wire [4-1:0]                                          m_axi_awregion,
   output wire [4-1:0]                                          m_axi_awqos,
   output wire [C_AXI_AWUSER_WIDTH==0?0:C_AXI_AWUSER_WIDTH-1:0] m_axi_awuser,
   output wire                                                  m_axi_awvalid,
   input  wire                                                  m_axi_awready,
   
   // Master Interface Write Data Ports
   output wire [C_AXI_WID_WIDTH==0?0:C_AXI_WID_WIDTH-1:0]       m_axi_wid,
   output wire [C_AXI_WDATA_WIDTH-1:0]                          m_axi_wdata,
   output wire [C_AXI_WDATA_WIDTH/8-1:0]                        m_axi_wstrb,
   output wire                                                  m_axi_wlast,
   output wire [C_AXI_WUSER_WIDTH==0?0:C_AXI_WUSER_WIDTH-1:0]   m_axi_wuser,
   output wire                                                  m_axi_wvalid,
   input  wire                                                  m_axi_wready,
   
   // Master Interface Write Response Ports
   input  wire [C_AXI_WID_WIDTH==0?0:C_AXI_WID_WIDTH-1:0]       m_axi_bid,
   input  wire [2-1:0]                                          m_axi_bresp,
   input  wire [C_AXI_BUSER_WIDTH==0?0:C_AXI_BUSER_WIDTH-1:0]   m_axi_buser,
   input  wire                                                  m_axi_bvalid,
   output wire                                                  m_axi_bready,
   
   // Master Interface Read Address Port
   output wire [C_AXI_RID_WIDTH==0?0:C_AXI_RID_WIDTH-1:0]       m_axi_arid,
   output wire [C_AXI_ADDR_WIDTH-1:0]                           m_axi_araddr,
   output wire [((C_AXI_PROTOCOL == 1) ? 4 : 8)-1:0]            m_axi_arlen,
   output wire [3-1:0]                                          m_axi_arsize,
   output wire [2-1:0]                                          m_axi_arburst,
   output wire [((C_AXI_PROTOCOL == 1) ? 2 : 1)-1:0]            m_axi_arlock,
   output wire [4-1:0]                                          m_axi_arcache,
   output wire [3-1:0]                                          m_axi_arprot,
   output wire [4-1:0]                                          m_axi_arregion,
   output wire [4-1:0]                                          m_axi_arqos,
   output wire [C_AXI_ARUSER_WIDTH==0?0:C_AXI_ARUSER_WIDTH-1:0] m_axi_aruser,
   output wire                                                  m_axi_arvalid,
   input  wire                                                  m_axi_arready,
   
   // Master Interface Read Data Ports
   input  wire [C_AXI_RID_WIDTH==0?0:C_AXI_RID_WIDTH-1:0]       m_axi_rid,
   input  wire [C_AXI_RDATA_WIDTH-1:0]                          m_axi_rdata,
   input  wire [2-1:0]                                          m_axi_rresp,
   input  wire                                                  m_axi_rlast,
   input  wire [C_AXI_RUSER_WIDTH==0?0:C_AXI_RUSER_WIDTH-1:0]   m_axi_ruser,
   input  wire                                                  m_axi_rvalid,
   output wire                                                  m_axi_rready
  );
   
  assign s_axi_awready = (C_AXI_INTERFACE_MODE != 1) ? 1'b0 :m_axi_awready ;
  assign s_axi_wready  = (C_AXI_INTERFACE_MODE != 1) ? 1'b0 :m_axi_wready;
  assign s_axi_bid  = (C_AXI_INTERFACE_MODE != 1) ?{C_AXI_WID_WIDTH==0?1:C_AXI_WID_WIDTH {1'b0}}:m_axi_bid;
  assign s_axi_bresp  = (C_AXI_INTERFACE_MODE != 1) ? 1'b0 :m_axi_bresp;
  assign s_axi_buser  = (C_AXI_INTERFACE_MODE != 1) ?{C_AXI_BUSER_WIDTH==0?1:C_AXI_BUSER_WIDTH {1'b0}} :m_axi_buser;
  assign s_axi_bvalid  = (C_AXI_INTERFACE_MODE != 1) ? 1'b0 :m_axi_bvalid;
  assign s_axi_arready = (C_AXI_INTERFACE_MODE != 1) ? 1'b0 :m_axi_arready;
  assign s_axi_rid  = (C_AXI_INTERFACE_MODE != 1) ? {C_AXI_WID_WIDTH==0?1:C_AXI_WID_WIDTH {1'b0}}:m_axi_rid;
  assign s_axi_rdata  = (C_AXI_INTERFACE_MODE != 1) ? {C_AXI_RDATA_WIDTH==0?1:C_AXI_RDATA_WIDTH {1'b0}} :m_axi_rdata;
  assign s_axi_rresp  = (C_AXI_INTERFACE_MODE != 1) ? 1'b0 :m_axi_rresp;
  assign s_axi_rlast  = (C_AXI_INTERFACE_MODE != 1) ? 1'b0 :m_axi_rlast ;
  assign s_axi_ruser  = (C_AXI_INTERFACE_MODE != 1) ? {C_AXI_RUSER_WIDTH==0?1:C_AXI_RUSER_WIDTH {1'b0}} :m_axi_ruser;
  assign s_axi_rvalid  = (C_AXI_INTERFACE_MODE != 1) ? 1'b0 :m_axi_rvalid ;

  assign m_axi_awid  = (C_AXI_INTERFACE_MODE != 1) ? {C_AXI_WID_WIDTH==0?1:C_AXI_WID_WIDTH {1'b0}} :s_axi_awid;
  assign m_axi_awaddr  = (C_AXI_INTERFACE_MODE != 1) ?{C_AXI_ADDR_WIDTH==0?1:C_AXI_ADDR_WIDTH {1'b0}}  :s_axi_awaddr ;
  assign m_axi_awlen  = (C_AXI_INTERFACE_MODE != 1) ? {((C_AXI_PROTOCOL == 1) ? 4 : 8) {1'b0}} :s_axi_awlen;
  assign m_axi_awsize  = (C_AXI_INTERFACE_MODE != 1) ? 3'b0 :s_axi_awsize;
  assign m_axi_awburst  = (C_AXI_INTERFACE_MODE != 1) ? 2'b0 :s_axi_awburst;
  assign m_axi_awlock  = (C_AXI_INTERFACE_MODE != 1) ? {((C_AXI_PROTOCOL == 1) ? 2 : 1) {1'b0}} :s_axi_awlock;
  assign m_axi_awcache  = (C_AXI_INTERFACE_MODE != 1) ? 4'b0 :s_axi_awcache;
  assign m_axi_awprot  = (C_AXI_INTERFACE_MODE != 1) ? 3'b0 :s_axi_awprot;
  assign m_axi_awregion  = (C_AXI_INTERFACE_MODE != 1) ? 4'b0 :s_axi_awregion;
  assign m_axi_awqos  = (C_AXI_INTERFACE_MODE != 1) ? 4'b0 :s_axi_awqos ;
  assign m_axi_awuser  = (C_AXI_INTERFACE_MODE != 1) ?{C_AXI_AWUSER_WIDTH==0?1:C_AXI_AWUSER_WIDTH {1'b0}} :s_axi_awuser;
  assign m_axi_awvalid  = (C_AXI_INTERFACE_MODE != 1) ? 1'b0 :s_axi_awvalid;
  assign m_axi_wid  = (C_AXI_INTERFACE_MODE != 1) ? {C_AXI_WID_WIDTH==0?1:C_AXI_WID_WIDTH {1'b0}} :s_axi_wid ;
  assign m_axi_wdata  = (C_AXI_INTERFACE_MODE != 1) ? {C_AXI_WDATA_WIDTH==0?1:C_AXI_WDATA_WIDTH {1'b0}} :s_axi_wdata;
  assign m_axi_wstrb  = (C_AXI_INTERFACE_MODE != 1) ?  {C_AXI_WDATA_WIDTH==0?1:C_AXI_WDATA_WIDTH/8 {1'b0}} :s_axi_wstrb;
  assign m_axi_wlast  = (C_AXI_INTERFACE_MODE != 1) ? 1'b0 :s_axi_wlast;
  assign m_axi_wuser  = (C_AXI_INTERFACE_MODE != 1) ? {C_AXI_WUSER_WIDTH==0?1:C_AXI_WUSER_WIDTH {1'b0}} :s_axi_wuser;
  assign m_axi_wvalid  = (C_AXI_INTERFACE_MODE != 1) ? 1'b0 :s_axi_wvalid;
  assign m_axi_bready  = (C_AXI_INTERFACE_MODE != 1) ? 1'b0 :s_axi_bready ;
  assign m_axi_arid  = (C_AXI_INTERFACE_MODE != 1) ?  {C_AXI_RID_WIDTH==0?1:C_AXI_RID_WIDTH {1'b0}} :s_axi_arid;
  assign m_axi_araddr  = (C_AXI_INTERFACE_MODE != 1) ? {C_AXI_ADDR_WIDTH==0?1:C_AXI_ADDR_WIDTH {1'b0}} :s_axi_araddr;
  assign m_axi_arlen  = (C_AXI_INTERFACE_MODE != 1) ? {((C_AXI_PROTOCOL == 1) ? 4 : 8) {1'b0}} :s_axi_arlen;
  assign m_axi_arsize  = (C_AXI_INTERFACE_MODE != 1) ? 3'b0 :s_axi_arsize;
  assign m_axi_arburst  = (C_AXI_INTERFACE_MODE != 1) ? 2'b0 :s_axi_arburst;
  assign m_axi_arlock  = (C_AXI_INTERFACE_MODE != 1) ? {((C_AXI_PROTOCOL == 1) ? 1 : 1) {1'b0}}  :s_axi_arlock;
  assign m_axi_arcache  = (C_AXI_INTERFACE_MODE != 1) ? 4'b0 :s_axi_arcache;
  assign m_axi_arprot  = (C_AXI_INTERFACE_MODE != 1) ? 3'b0 :s_axi_arprot;
  assign m_axi_arregion  = (C_AXI_INTERFACE_MODE != 1) ? 4'b0 :s_axi_arregion;
  assign m_axi_arqos  = (C_AXI_INTERFACE_MODE != 1) ? 4'b0 :s_axi_arqos;
  assign m_axi_aruser  = (C_AXI_INTERFACE_MODE != 1) ? {C_AXI_ARUSER_WIDTH==0?1:C_AXI_ARUSER_WIDTH {1'b0}} : s_axi_aruser;
  assign m_axi_arvalid  = (C_AXI_INTERFACE_MODE != 1) ? 1'b0 :s_axi_arvalid ;
  assign m_axi_rready = (C_AXI_INTERFACE_MODE != 1) ? 1'b0 :s_axi_rready;


endmodule // axi_vip_v1_1_14_top


