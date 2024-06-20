///////////////////////////////////////////////////////////////////////////////
//  FERMI RESEARCH LAB
///////////////////////////////////////////////////////////////////////////////
//  Author         : Martin Di Federico
//  Date           : 2024_6_20
//  Version        : 2
///////////////////////////////////////////////////////////////////////////////
//  QICK PROCESSOR :  Board Communication Peripheral
//////////////////////////////////////////////////////////////////////////////

module axi_qick_com # (
   parameter SYNC            = 0 ,
   parameter DEBUG           = 0
)(
// Core and AXI CLK & RST
   input  wire             c_clk          ,
   input  wire             c_aresetn      ,
   input  wire             t_clk          ,
   input  wire             t_aresetn      ,
   input  wire             ps_clk         ,
   input  wire             ps_aresetn     ,
// QCOM INTERFACE (c_clk)
   input  wire             qcom_en_i      ,
   input  wire  [4:0]      qcom_op_i      ,
   input  wire  [31:0]     qcom_dt1_i     ,
   output reg              qcom_rdy_o     ,
   output reg   [31:0]     qcom_dt1_o     ,
   output reg   [31:0]     qcom_dt2_o     ,
   output reg              qcom_vld_o     ,
   output reg              qcom_flag_o    ,
// TPROC CONTROL (t_clk)
   input  wire             sync_i         ,
   output reg              qproc_start_o  ,
// PMOD COM (c_clk)
   input  wire  [ 3:0]     pmod_i         ,
   output reg   [ 3:0]     pmod_o         ,
// AXI-Lite DATA Slave I/F (ps_clk)
   input  wire [5:0]       s_axi_awaddr   ,
   input  wire [2:0]       s_axi_awprot   ,
   input  wire             s_axi_awvalid  ,
   output wire             s_axi_awready  ,
   input  wire [31:0]      s_axi_wdata    ,
   input  wire [ 3:0]      s_axi_wstrb    ,
   input  wire             s_axi_wvalid   ,
   output wire             s_axi_wready   ,
   output wire [ 1:0]      s_axi_bresp    ,
   output wire             s_axi_bvalid   ,
   input  wire             s_axi_bready   ,
   input  wire [ 5:0]      s_axi_araddr   ,
   input  wire [ 2:0]      s_axi_arprot   ,
   input  wire             s_axi_arvalid  ,
   output wire             s_axi_arready  ,
   output wire [31:0]      s_axi_rdata    ,
   output wire [ 1:0]      s_axi_rresp    ,
   output wire             s_axi_rvalid   ,
   input  wire             s_axi_rready   ,
///// DEBUG   
   output wire [31:0]      qcom_do        
);

// Signal Declaration 
///////////////////////////////////////////////////////////////////////////////

wire [31:0] qcom_flag, qcom_dt_1, qcom_dt_2 ; // QCOM Outputs
wire [31:0] qcom_tx_dt_ds, qcom_rx_dt_ds, qcom_status_ds, qcom_ds;
wire [15:0] qcom_debug_ds ;

wire [31:0] xreg_tx_dt, xreg_rx_dt  ;
wire [23:0] xreg_debug ;

// QCOM Control (From Python and tProc)
wire [ 3:0] cmd_op ;
wire [31:0] cmd_dt ;
wire [ 7:0] cmd_cnt ;

wire [ 7:0] QCOM_CTRL ;
wire [ 3:0] QCOM_CFG ;
wire [31:0] RAXI_DT1 ;

wire             sync_s        ;
reg              qproc_start_s ;


qick_cmd #(
   .OP_DW  ( 4 ),
   .DT_QTY ( 1 )
) CMD (
   .clk_i      ( c_clk           ),
   .rst_ni     ( c_aresetn       ),
   .ps_clk_i   ( ps_clk          ),
   .ps_rst_ni  ( ps_aresetn      ),
   .c_en_i     ( qcom_en_i       ),
   .c_op_i     ( qcom_op_i       ),
   .c_dt_i     ( '{qcom_dt1_i}   ),
   .p_ctrl_i   ( QCOM_CTRL[4:0]  ),
   .p_dt_i     ( '{RAXI_DT1}     ),
   .cmd_req_o  ( cmd_req         ),
   .cmd_ack_i  ( cmd_ack         ),
   .cmd_op_o   ( cmd_op          ),
   .cmd_dt_o   ( '{cmd_dt}       ),
   .cmd_cnt_do ( cmd_cnt         ));
   
qick_com QCOM (
   .c_clk_i        ( c_clk          ),
   .c_rst_ni       ( c_aresetn      ),
   .t_clk_i        ( t_clk          ),
   .t_rst_ni       ( t_aresetn      ),
   .qcom_cfg_i     ( QCOM_CFG[3:0]  ),
   .pulse_i        ( sync_s         ),
   .cmd_req_i      ( cmd_req        ),
   .cmd_ack_o      ( cmd_ack        ),
   .cmd_op_i       ( cmd_op         ),
   .cmd_dt_i       ( cmd_dt         ),
   .qcom_rdy_o     ( qcom_rdy_o     ),
   .qcom_dt1_o     ( qcom_dt1_o     ),
   .qcom_dt2_o     ( qcom_dt2_o     ),
   .qcom_vld_o     ( qcom_vld_o     ),
   .qcom_flag_o    ( qcom_flag_o    ),
   .qproc_start_o  ( qproc_start_s  ),
   .pmod_i         ( pmod_i         ),
   .pmod_o         ( pmod_o         ),
   .qcom_tx_dt_do  ( qcom_tx_dt_ds  ),
   .qcom_rx_dt_do  ( qcom_rx_dt_ds  ),
   .qcom_status_do ( qcom_status_ds ),
   .qcom_debug_do  ( qcom_debug_ds  ),
   .qcom_do        ( qcom_ds        ));


   
///////////////////////////////////////////////////////////////////////////////
// AXI Registers
///////////////////////////////////////////////////////////////////////////////
axi_slv_qcom QCOM_xREG (
   .aclk        ( ps_clk             ) , 
   .aresetn     ( ps_aresetn         ) , 
   .awaddr      ( s_axi_awaddr [5:0] ) , 
   .awprot      ( s_axi_awprot       ) , 
   .awvalid     ( s_axi_awvalid      ) , 
   .awready     ( s_axi_awready      ) , 
   .wdata       ( s_axi_wdata        ) , 
   .wstrb       ( s_axi_wstrb        ) , 
   .wvalid      ( s_axi_wvalid       ) , 
   .wready      ( s_axi_wready       ) , 
   .bresp       ( s_axi_bresp        ) , 
   .bvalid      ( s_axi_bvalid       ) , 
   .bready      ( s_axi_bready       ) , 
   .araddr      ( s_axi_araddr       ) , 
   .arprot      ( s_axi_arprot       ) , 
   .arvalid     ( s_axi_arvalid      ) , 
   .arready     ( s_axi_arready      ) , 
   .rdata       ( s_axi_rdata        ) , 
   .rresp       ( s_axi_rresp        ) , 
   .rvalid      ( s_axi_rvalid       ) , 
   .rready      ( s_axi_rready       ) , 
   .QCOM_CTRL   ( QCOM_CTRL          ) ,
   .QCOM_CFG    ( QCOM_CFG           ) ,
   .RAXI_DT1    ( RAXI_DT1           ) ,
   .QCOM_FLAG   ( qcom_flag_o        ) ,
   .QCOM_DT_1   ( qcom_dt1_o         ) ,
   .QCOM_DT_2   ( qcom_dt2_o         ) ,
   .QCOM_STATUS ( qcom_status_ds     ) ,
   .QCOM_TX_DT  ( xreg_tx_dt         ) ,
   .QCOM_RX_DT  ( xreg_rx_dt         ) ,
   .QCOM_DEBUG  ( xreg_debug         ) );



///////////////////////////////////////////////////////////////////////////////
// SYNC OPTION
///////////////////////////////////////////////////////////////////////////////
generate
   if (SYNC == 0) begin : SYNC_NO
      assign sync_s        = 0 ;
      assign qproc_start_o = 0 ;
   end else if   (SYNC == 1) begin : SYNC_YES
      assign sync_s        = sync_i ;
      assign qproc_start_o = qproc_start_s ;
   end
endgenerate
///////////////////////////////////////////////////////////////////////////////
// DEBUG
///////////////////////////////////////////////////////////////////////////////
   
generate
   if (DEBUG == 0) begin : DEBUG_NO
      assign xreg_tx_dt  = '{default:'0} ;
      assign xreg_rx_dt  = '{default:'0} ;
      assign xreg_debug  = '{default:'0} ;
   end else if   (DEBUG == 1) begin : DEBUG_YES
      assign xreg_tx_dt  = qcom_tx_dt_ds;
      assign xreg_rx_dt  = qcom_rx_dt_ds;
      assign xreg_debug  = {qcom_debug_ds, cmd_cnt};
   end
endgenerate

endmodule
