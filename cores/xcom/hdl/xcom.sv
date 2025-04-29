///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
//
// Fermi Fordward Alliance LLC
//
// Module: xcom.sv
// Project: QICK 
// Description: Board communication peripheral
//
//
// Change history: 10/20/24 - v2 Started by mdifederico
//                 10/29/04 - Made the RESET signal last longer than
//                 a single clock
//                 01/08/05 - dma_rd_mac is now an input as round-robin
//                 lookup is used
//                 01/13/05 - split dma_intr into read and write sigs
//
///////////////////////////////////////////////////////////////////////////////

module xcom # (
   parameter CH           = 2 ,
   parameter SYNC         = 1 ,
   parameter DEBUG        = 1
)(
// CLK & RST
   input  logic             ps_clk        ,
   input  logic             ps_aresetn    ,
   input  logic             c_clk         ,
   input  logic             c_aresetn     ,
   input  logic             t_clk         ,
   input  logic             t_aresetn     ,
   input  logic             x_clk         ,
   input  logic             x_aresetn     ,
// QICK PERIPHERAL INTERFACE (c_clk)
   input  logic             qp_en_i       , 
   input  logic  [4:0]      qp_op_i       , 
   input  logic  [31:0]     qp_dt1_i      , 
   input  logic  [31:0]     qp_dt2_i      , 
   output logic              qp_rdy_o      , 
   output logic   [31:0]     qp_dt1_o      , 
   output logic   [31:0]     qp_dt2_o      , 
   output logic              qp_vld_o      , 
   output logic              qp_flag_o     , 
// Qick CONTROL
   input  logic             pulse_sync_i  ,
   output logic             proc_start_o  ,
   output logic             proc_stop_o   ,
   output logic             time_rst_o    ,
   output logic             time_updt_o   ,
   output logic  [31:0]     time_updt_dt_o,
   output logic             core_start_o  ,
   output logic             core_stop_o   ,
// XCOM 
   output logic  [ 3:0]     xcom_id_o     ,
// IO XCOM (x_clk)
   input  logic  [CH-1:0]   xcom_ck_i     ,
   input  logic  [CH-1:0]   xcom_dt_i     ,
   output logic             xcom_ck_o     ,
   output logic             xcom_dt_o     ,
// AXI-Lite DATA Slave I/F (ps_clk)
   input  logic [5:0]       s_axi_awaddr  ,
   input  logic [2:0]       s_axi_awprot  ,
   input  logic             s_axi_awvalid ,
   output logic             s_axi_awready ,
   input  logic [31:0]      s_axi_wdata   ,
   input  logic [ 3:0]      s_axi_wstrb   ,
   input  logic             s_axi_wvalid  ,
   output logic             s_axi_wready  ,
   output logic [ 1:0]      s_axi_bresp   ,
   output logic             s_axi_bvalid  ,
   input  logic             s_axi_bready  ,
   input  logic [ 5:0]      s_axi_araddr  ,
   input  logic [ 2:0]      s_axi_arprot  ,
   input  logic             s_axi_arvalid ,
   output logic             s_axi_arready ,
   output logic [31:0]      s_axi_rdata   ,
   output logic [ 1:0]      s_axi_rresp   ,
   output logic             s_axi_rvalid  ,
   input  logic             s_axi_rready        
);

// Signal Declaration 
///////////////////////////////////////////////////////////////////////////////

// XCOM Control (From Python and tProc)
logic [ 7:0] cmd_op ;
logic [31:0] cmd_dt ;
logic [ 7:0] cmd_cnt_ds ;

logic [ 5:0] XCOM_CTRL ;
logic [ 2:0] XCOM_CFG ;
logic [31:0] AXI_DT1, AXI_DT2 ;
logic [ 3:0] AXI_ADDR ;



logic [ 5:0] p_ctrl  ; 
logic [31:0] p_dt [2]; 
logic [31:0] c_dt [2]; 

logic [31:0] xcom_mem_dt [15];
logic [31:0] axi_mem_dt;

logic [31:0] xreg_debug;
logic [28:0] xreg_status;
logic [31:0]      xcom_rx_ds ;
logic [31:0]      xcom_tx_ds ;
logic [20:0]      xcom_status_ds ;
logic [31:0]      xcom_debug_ds  ;

assign p_ctrl = XCOM_CTRL;
assign c_dt   = '{qp_dt1_i, qp_dt2_i};
assign p_dt   = '{AXI_DT1  , AXI_DT2};

qick_xcom_cmd QICK_CMD(
   .ps_clk_i      ( ps_clk      ),
   .ps_rst_ni     ( ps_aresetn  ),
   .c_clk_i       ( c_clk       ),
   .c_rst_ni      ( c_aresetn   ),
   .x_clk_i       ( x_clk       ),
   .x_rst_ni      ( x_aresetn   ),
   .c_en_i        ( qp_en_i     ),
   .c_op_i        ( qp_op_i     ),
   .c_dt_i        ( c_dt        ),
   .p_ctrl_i      ( p_ctrl      ),
   .p_dt_i        ( p_dt        ),
   .cmd_loc_req_o ( cmd_loc_req ),
   .cmd_loc_ack_i ( cmd_loc_ack ),
   .cmd_net_req_o ( cmd_net_req ),
   .cmd_net_ack_i ( cmd_net_ack ),
   .cmd_op_o      ( cmd_op      ),
   .cmd_dt_o      ( cmd_dt      ),
   .cmd_cnt_do    ( cmd_cnt_ds     ));

logic [3:0] xcom_cfg;
assign   xcom_cfg = {XCOM_CFG[2:0]+1'b1, 1'b0};

qick_xcom # (
   .CH    ( CH   ),
   .SYNC  ( SYNC )
) XCOM (
   .c_clk_i        ( c_clk          ),
   .c_rst_ni       ( c_aresetn      ),
   .t_clk_i        ( t_clk          ),
   .t_rst_ni       ( t_aresetn      ),
   .x_clk_i        ( x_clk          ),
   .x_rst_ni       ( x_aresetn      ),
   .pulse_sync_i   ( pulse_sync_i   ),
   .cmd_loc_req_i  ( cmd_loc_req    ),
   .cmd_loc_ack_o  ( cmd_loc_ack    ),
   .cmd_net_req_i  ( cmd_net_req    ),
   .cmd_net_ack_o  ( cmd_net_ack    ),
   .cmd_op_i       ( cmd_op         ),
   .cmd_dt_i       ( cmd_dt         ),
   .qp_rdy_o       ( qp_rdy_o       ),
   .qp_vld_o       ( qp_vld_o       ),
   .qp_flag_o      ( qp_flag_o      ),
   .qp_dt1_o       ( qp_dt1_o       ),
   .qp_dt2_o       ( qp_dt2_o       ),
   .p_start_o      ( proc_start_o   ),
   .p_stop_o       ( proc_stop_o    ),
   .t_rst_o        ( time_rst_o     ),
   .t_updt_o       ( time_updt_o    ),
   .t_updt_dt_o    ( time_updt_dt_o ),

   .c_start_o      ( core_start_o   ),
   .c_stop_o       ( core_stop_o    ),
   .xcom_cfg_i     ( xcom_cfg       ),
   .xcom_id_o      ( xcom_id_o      ),
   .xcom_mem_o     ( xcom_mem_dt    ),
   .rx_dt_i        ( xcom_dt_i      ),
   .rx_ck_i        ( xcom_ck_i      ),
   .tx_dt_o        ( tx_dt_s        ),
   .tx_ck_o        ( tx_ck_s        ),
   .xcom_rx_do     ( xcom_rx_ds     ),
   .xcom_tx_do     ( xcom_tx_ds     ),
   .xcom_status_do ( xcom_status_ds ),
   .xcom_debug_do  ( xcom_debug_ds  )
);   





///////////////////////////////////////////////////////////////////////////////
// AXI Registers
///////////////////////////////////////////////////////////////////////////////
axi_slv_xcom XCOM_xREG (
   .aclk        ( ps_clk             ), 
   .aresetn     ( ps_aresetn         ), 
   .awaddr      ( s_axi_awaddr [5:0] ), 
   .awprot      ( s_axi_awprot       ), 
   .awvalid     ( s_axi_awvalid      ), 
   .awready     ( s_axi_awready      ), 
   .wdata       ( s_axi_wdata        ), 
   .wstrb       ( s_axi_wstrb        ), 
   .wvalid      ( s_axi_wvalid       ), 
   .wready      ( s_axi_wready       ), 
   .bresp       ( s_axi_bresp        ), 
   .bvalid      ( s_axi_bvalid       ), 
   .bready      ( s_axi_bready       ), 
   .araddr      ( s_axi_araddr       ), 
   .arprot      ( s_axi_arprot       ), 
   .arvalid     ( s_axi_arvalid      ), 
   .arready     ( s_axi_arready      ), 
   .rdata       ( s_axi_rdata        ), 
   .rresp       ( s_axi_rresp        ), 
   .rvalid      ( s_axi_rvalid       ), 
   .rready      ( s_axi_rready       ), 
   .XCOM_CTRL   ( XCOM_CTRL          ),
   .XCOM_CFG    ( XCOM_CFG           ),
   .AXI_DT1     ( AXI_DT1            ),
   .AXI_DT2     ( AXI_DT2            ),
   .AXI_ADDR    ( AXI_ADDR           ),
   .BOARD_ID    ( xcom_id_o          ),
   .XCOM_FLAG   ( qp_flag_o          ),
   .XCOM_DT_1   ( qp_dt1_o           ),
   .XCOM_DT_2   ( qp_dt2_o           ),
   .XCOM_MEM    ( axi_mem_dt         ),
   .XCOM_RX_DT  ( xcom_rx_ds         ),
   .XCOM_TX_DT  ( xcom_tx_ds         ),
   .XCOM_STATUS ( xreg_status        ),
   .XCOM_DEBUG  ( xreg_debug         ));


// OUTPUTS
///////////////////////////////////////////////////////////////////////////////
assign xcom_dt_o = tx_dt_s;
assign xcom_ck_o = tx_ck_s;
assign axi_mem_dt = xcom_mem_dt[AXI_ADDR];

///////////////////////////////////////////////////////////////////////////////
// DEBUG
///////////////////////////////////////////////////////////////////////////////
assign xreg_status = { cmd_cnt_ds, xcom_status_ds};

generate
   if (DEBUG == 0) begin : DEBUG_NO
      assign xreg_debug  = '{default:'0} ;
   end else if   (DEBUG == 1) begin : DEBUG_YES
      assign xreg_debug  = xcom_debug_ds;
   end
endgenerate

endmodule
