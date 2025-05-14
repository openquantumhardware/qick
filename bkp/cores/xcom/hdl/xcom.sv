///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
//
// Fermi Fordward Alliance LLC
//
// Module: xcom.sv
// Project: QICK 
// Description: 
// Transmitter and Receiver interface for the XCOM block. 
// 
//Inputs:
// - i_clk      clock signal
// - i_rstn     active low reset signal
// - i_sync     synchronization signal. Lets the XCOM synchronize with an
//              external signal. Actuates in coordination with the 
//              XCOM_QRST_SYNC command.
// - i_cfg_tick this input is connected to the AXI_CFG register and 
//              determines the duration of the xcom_clk output signal.
//              xcom_clk will be either in state 1 or 0 for CFG_AXI clock 
//              cycles (i_clk). Possible values ranges from 0 to 7 with 
//              0 equal to two clock cycles and 7 equal to 15 clock 
//              cycles. As an example, if i_cfg_tick = 2 and 
//              i_clk = 500 MHz, then xcom_clk would be ~125 MHz.
// - i_req_net      transmission requirement signal. Signal indicating a new
//              data transmission starts.  
// - i header   this is the header to be sent to the slaves. 
//              bit 7      is sometimes used to indicate a 
//                         synchronization in other places in the 
//                         XCOM hierarchy
//              bits [6:5] determines the data length to transmit:
//                         00 no data
//                         01 8-bit data
//                         10 16-bit data
//                         11 32-bit data
//              bit 4      not used in this block
//              bits [3:0] not used in this block. Sometimes used 
//                         as mem_id and sometimes used as board 
//                         ID in the XCOM hierarchy 
// - i_data     the data to be transmitted 
//Outputs:
// - o_ready    signal indicating the ip is ready to receive new data to
//              transmit
// - o_data     serial data transmitted. This is the general output of the
//              XCOM block
// - o_clk      serial clock for transmission. This is the general output of
//              the XCOM block
// - o_dbg_state debug port for monitoring the state of the internal FSM
//
// Change history: 10/20/24 - v2 Started by @mdifederico
//                 05/13/25 - Refactored by @lharnaldi
//                          - the sync_n core was removed to sync all signals
//                            in one place (external).
//
///////////////////////////////////////////////////////////////////////////////
module xcom import qick_pkg::*;
# (
   parameter CH           = 2 ,
   parameter SYNC         = 1 ,
   parameter DEBUG        = 1
)(
   input  logic             i_ps_clk        ,
   input  logic             i_ps_rstn    ,
   input  logic             i_core_clk         ,
   input  logic             i_core_rstn     ,
   input  logic             i_time_clk         ,
   input  logic             i_time_rstn     ,
// QICK PERIPHERAL INTERFACE (i_core_clk)
   input  logic             i_qp_en       , 
   input  logic  [5-1:0]    i_qp_op       , 
   input  logic  [32-1:0]   i_qp_data1      , 
   input  logic  [32-1:0]   i_qp_data2      , 
   output logic             o_qp_ready      , 
   output logic   [32-1:0]  o_qp_data1      , 
   output logic   [32-1:0]  o_qp_data2      , 
   output logic             o_qp_valid      , 
   output logic             o_qp_flag     , 
// Qick CONTROL
   input  logic             i_sync  ,
   output logic             o_proc_start  ,
   output logic             o_proc_stop   ,
   output logic             o_time_rst    ,
   output logic             o_time_update   ,
   output logic  [32-1:0]   o_time_update_data,
   output logic             o_core_start  ,
   output logic             o_core_stop   ,
// XCOM 
   output logic  [ 4-1:0]   o_xcom_id     ,
// IO XCOM (i_time_clk)
   input  logic  [CH-1:0]   i_xcom_clk     ,
   input  logic  [CH-1:0]   i_xcom_data     ,
   output logic             o_xcom_clk     ,
   output logic             o_xcom_data     ,
// AXI-Lite DATA Slave I/F (i_ps_clk)
   input  logic [6-1:0]     s_axi_awaddr  ,
   input  logic [3-1:0]     s_axi_awprot  ,
   input  logic             s_axi_awvalid ,
   output logic             s_axi_awready ,
   input  logic [32-1:0]    s_axi_wdata   ,
   input  logic [ 4-1:0]    s_axi_wstrb   ,
   input  logic             s_axi_wvalid  ,
   output logic             s_axi_wready  ,
   output logic [ 2-1:0]    s_axi_bresp   ,
   output logic             s_axi_bvalid  ,
   input  logic             s_axi_bready  ,
   input  logic [ 6-1:0]    s_axi_araddr  ,
   input  logic [ 3-1:0]    s_axi_arprot  ,
   input  logic             s_axi_arvalid ,
   output logic             s_axi_arready ,
   output logic [32-1:0]    s_axi_rdata   ,
   output logic [ 2-1:0]    s_axi_rresp   ,
   output logic             s_axi_rvalid  ,
   input  logic             s_axi_rready        
);

// Signal Declaration 
///////////////////////////////////////////////////////////////////////////////

// XCOM Control (From Python and tProc)
logic [ 8-1:0] cmd_op ;
logic [32-1:0] cmd_dt ;
logic [ 8-1:0] cmd_cnt_ds ;

logic [32-1:0] s_xcom_ctrl ;//6
logic [6-1:0]  s_xcom_ctrl_sync ;//6
logic [32-1:0] s_xcom_cfg ;
logic [4-1:0]  s_xcom_cfg_sync ;
logic [4-1:0]  xcom_cfg;
logic [32-1:0] s_axi_data1;
logic [32-1:0] s_axi_data1_sync;
logic [32-1:0] s_axi_data2 ;
logic [32-1:0] s_axi_data2_sync;
logic [ 4-1:0] s_axi_addr ;

logic [ 6-1:0] p_ctrl  ; 
logic [32-1:0] p_dt [2]; 
logic [32-1:0] c_dt [2]; 

logic [32-1:0] xcom_mem_data [15];
logic [32-1:0] axi_mem_dt;

logic [32-1:0] xreg_debug;
logic [29-1:0] xreg_status;
logic [32-1:0] xcom_rx_ds ;
logic [32-1:0] xcom_tx_ds ;
logic [21-1:0] xcom_status_ds ;
logic [32-1:0] xcom_debug_ds  ;

assign p_ctrl = s_xcom_ctrl;
assign c_dt   = '{i_qp_data1, i_qp_data2};

qick_xcom_cmd QICK_CMD(
   .ps_clk_i      ( i_ps_clk      ),
   .ps_rst_ni     ( i_ps_rstn  ),
   .c_clk_i       ( i_core_clk       ),
   .c_rst_ni      ( i_core_rstn   ),
   .x_clk_i       ( i_time_clk       ),
   .x_rst_ni      ( i_time_rstn   ),
   .c_en_i        ( i_qp_en     ),
   .c_op_i        ( i_qp_op     ),
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

xcom_cmd u_xcom_cmd(
   .i_clk            ( i_time_clk         ),
   .i_rstn           ( i_time_rstn        ),
   .i_tproc_en       ( tb_i_tproc_en  ),
   .i_tproc_op       ( tb_i_tproc_op  ),
   .i_tproc_data     ( s_tproc_data   ),
   .i_ps_ctrl        ( tb_i_ps_ctrl   ),
   .i_ps_data        ( s_ps_data      ), 
   .o_req_loc        ( tb_o_req_loc   ),
   .i_ack_loc        ( tb_i_ack_loc   ),
   .o_req_net        ( tb_o_req_net   ),
   .i_ack_net        ( tb_i_ack_net   ),
   .o_op             ( tb_o_op        ),
   .o_data           ( tb_o_data      ),
   .o_data_cntr      ( tb_o_data_cntr )
   );


qick_xcom # (
   .CH    ( CH   ),
   .SYNC  ( SYNC )
) XCOM (
   .cmd_loc_req_i  ( cmd_loc_req    ),
   .cmd_loc_ack_o  ( cmd_loc_ack    ),
   .cmd_net_req_i  ( cmd_net_req    ),
   .cmd_net_ack_o  ( cmd_net_ack    ),
   .cmd_op_i       ( cmd_op         ),
   .cmd_dt_i       ( cmd_dt         ),
   .qp_rdy_o       ( o_qp_ready       ),
   .qp_vld_o       ( o_qp_valid       ),
   .qp_flag_o      ( o_qp_flag      ),
   .qp_dt1_o       ( o_qp_data1       ),
   .qp_dt2_o       ( o_qp_data2       ),
   .p_start_o      ( o_proc_start   ),
   .p_stop_o       ( o_proc_stop    ),
   .t_rst_o        ( o_time_rst     ),
   .t_updt_o       ( o_time_update    ),
   .t_updt_dt_o    ( o_time_update_data ),
   .c_start_o      ( o_core_start   ),
   .c_stop_o       ( o_core_stop    ),
   .rx_dt_i        ( i_xcom_data      ),
   .rx_ck_i        ( i_xcom_clk      ),
   .tx_dt_o        ( tx_dt_s        ),
   .tx_ck_o        ( tx_ck_s        ),
   .xcom_rx_do     ( xcom_rx_ds     ),
   .xcom_tx_do     ( xcom_tx_ds     ),
   .xcom_status_do ( xcom_status_ds ),
   .xcom_debug_do  ( xcom_debug_ds  )
);   

xcom_txrx #(
.NCH(NCH),
.SYNC(1'b1)
)
u_xcom_txrx
(
  .i_clk             ( tb_clk                ),
  .i_rstn            ( tb_rstn               ),
  .i_sync            ( i_sync             ),
  .i_req_loc         ( tb_i_req_loc          ),
  .i_req_net         ( tb_i_req_net          ),
  .i_header          ( tb_i_header           ),
  .i_data            ( tb_i_data             ), 
  .o_ack_loc         ( tb_o_ack_loc          ),
  .o_ack_net         ( tb_o_ack_net          ),
  .o_qp_ready        ( o_qp_ready         ),
  .o_qp_valid        ( o_qp_valid         ),
  .o_qp_flag         ( o_qp_flag          ),
  .o_qp_data1        ( o_qp_data1         ),
  .o_qp_data2        ( o_qp_data2         ),
  .o_proc_start      ( o_proc_start       ),
  .o_proc_stop       ( o_proc_stop        ),
  .o_time_rst        ( o_time_rst         ),
  .o_time_update     ( o_time_update      ),
  .o_time_update_data( o_time_update_data ),
  .o_core_start      ( o_core_start       ),
  .o_core_stop       ( o_core_stop        ),
  .i_cfg_tick        ( xcom_cfg           ),
  .o_xcom_id         ( o_xcom_id          ),//FIXME: cdc here, check
  .o_xcom_mem        ( xcom_mem_data        ),//FIXME: review this because here we are crossing clock domains
  .i_xcom_data       ( i_xcom_data          ),
  .i_xcom_clk        ( i_xcom_clk           ),
  .o_xcom_data       ( tb_o_xcom_data        ),
  .o_xcom_clk        ( tb_o_xcom_clk         ),
  .o_dbg_rx_data     ( tb_o_dbg_rx_data      ),
  .o_dbg_tx_data     ( tb_o_dbg_tx_data      ),
  .o_dbg_status      ( tb_o_dbg_status       ),
  .o_dbg_data        ( tb_o_dbg_data         )                                                               
);


///////////////////////////////////////////////////////////////////////////////
// AXI Registers
///////////////////////////////////////////////////////////////////////////////
xcom_axil_slv #(
    .C_S_AXI_ADDR_WIDTH = 6,               // Address width.  Adjust as needed.
    .C_S_AXI_DATA_WIDTH = 32               // Data width (32 or 64).
) u_axi_slv_xcom(
   .clk            ( i_ps_clk           ), 
   .reset_n        ( i_ps_rstn          ), 
   .s_axi_awaddr   ( s_axi_awaddr [6-1:0] ), 
   .s_axi_awvalid  ( s_axi_awvalid      ),
   .s_axi_awready  ( s_axi_awready      ), 
   .s_axi_wdata    ( s_axi_wdata        ), 
   .s_axi_wstrb    ( s_axi_wstrb        ), 
   .s_axi_wvalid   ( s_axi_wvalid       ), 
   .s_axi_wready   ( s_axi_wready       ), 
   .s_axi_bresp    ( s_axi_bresp        ), 
   .s_axi_bvalid   ( s_axi_bvalid       ), 
   .s_axi_bready   ( s_axi_bready       ), 
   .s_axi_araddr   ( s_axi_araddr       ), 
   .s_axi_arvalid  ( s_axi_arvalid      ),
   .s_axi_arready  ( s_axi_arready      ), 
   .s_axi_rdata    ( s_axi_rdata        ), 
   .s_axi_rresp    ( s_axi_rresp        ), 
   .s_axi_rvalid   ( s_axi_rvalid       ), 
   .s_axi_rready   ( s_axi_rready       ), 
   .o_xcom_ctrl    ( s_xcom_ctrl        ), 
   .o_xcom_cfg     ( s_xcom_cfg         ), 
   .o_axi_data1    ( s_axi_data1        ),
   .o_axi_data2    ( s_axi_data2        ),
   .o_axi_addr     ( s_axi_addr         ),
   .i_board_id     ( o_xcom_id          ),
   .i_xcom_flag    ( o_qp_flag          ),
   .i_xcom_data1   ( o_qp_data1         ),
   .i_xcom_data2   ( o_qp_data2         ),
   .i_xcom_mem     ( axi_mem_dt         ),
   .i_xcom_rx_data ( xcom_rx_ds         ),
   .i_xcom_tx_data ( xcom_tx_ds         ),
   .i_xcom_status  ( xreg_status        ),
   .i_xcom_debug   ( xreg_debug         )
   ); 

//SYNC STAGES
///////////////////////////////////////////////////////////////////////////////
synchronizer#(
   .NB(6)
   ) sync_xcom_ctrl(
  .i_clk      ( i_time_clk        ),
  .i_rstn     ( i_time_rstn       ),
  .i_async    ( s_xcom_ctrl[6-1:0]),
  .o_sync     ( s_xcom_ctrl_sync  )
);

synchronizer#(
   .NB(4)
   ) sync_xcom_cfg(
  .i_clk      ( i_time_clk        ),
  .i_rstn     ( i_time_rstn       ),
  .i_async    ( s_xcom_cfg[4-1:0] ),
  .o_sync     ( s_xcom_cfg_sync   )
);
assign   xcom_cfg = {s_xcom_cfg_sync[3-1:0]+1'b1, 1'b0};

synchronizer#(
   .NB(32)
   ) sync_axi_data1(
  .i_clk      ( i_time_clk        ),
  .i_rstn     ( i_time_rstn       ),
  .i_async    ( s_axi_data1       ),
  .o_sync     ( s_axi_data1_sync  )
);

synchronizer#(
   .NB(32)
   ) sync_axi_data2(
  .i_clk      ( i_time_clk        ),
  .i_rstn     ( i_time_rstn       ),
  .i_async    ( s_axi_data2       ),
  .o_sync     ( s_axi_data2_sync  )
);
assign p_dt   = '{s_axi_data1_sync, s_axi_data2_sync};
//end of SYNC STAGES
///////////////////////////////////////////////////////////////////////////////
// OUTPUTS
///////////////////////////////////////////////////////////////////////////////
assign o_xcom_data = tx_dt_s;
assign o_xcom_clk = tx_ck_s;
assign axi_mem_dt = xcom_mem_data[s_axi_addr];

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
