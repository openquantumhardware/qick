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
   parameter NCH          = 2 ,
   parameter SYNC         = 1 ,
   parameter DEBUG        = 1
)(
   input  logic             i_ps_clk           ,
   input  logic             i_ps_rstn          ,  
   input  logic             i_core_clk         ,
   input  logic             i_core_rstn        ,
   input  logic             i_time_clk         ,
   input  logic             i_time_rstn        ,
// QICK PERIPHERAL INTERFACE (i_core_clk)
   input  logic             i_core_en          , 
   input  logic  [5-1:0]    i_core_op          , 
   input  logic  [32-1:0]   i_core_data1       , 
   input  logic  [32-1:0]   i_core_data2       , 
   output logic             o_core_ready       , 
   output logic   [32-1:0]  o_core_data1       , 
   output logic   [32-1:0]  o_core_data2       , 
   output logic             o_core_valid       , 
   output logic             o_core_flag        , 
// Qick CONTROL
   input  logic             i_sync             ,
   output logic             o_proc_start       ,
   output logic             o_proc_stop        ,
   output logic             o_time_rst         ,
   output logic             o_time_update      ,
   output logic  [32-1:0]   o_time_update_data ,
   output logic             o_core_start       ,
   output logic             o_core_stop        ,
// XCOM 
   output logic  [ 4-1:0]   o_xcom_id          ,
// IO XCOM (i_time_clk)
   input  logic  [NCH-1:0]   i_xcom_clk         ,
   input  logic  [NCH-1:0]   i_xcom_data        ,
   output logic             o_xcom_clk         ,
   output logic             o_xcom_data        ,
// AXI-Lite DATA Slave I/F (i_ps_clk)
   input  logic [6-1:0]     s_axi_awaddr       ,
   input  logic [3-1:0]     s_axi_awprot       ,
   input  logic             s_axi_awvalid      ,
   output logic             s_axi_awready      ,
   input  logic [32-1:0]    s_axi_wdata        ,
   input  logic [ 4-1:0]    s_axi_wstrb        ,
   input  logic             s_axi_wvalid       ,
   output logic             s_axi_wready       ,
   output logic [ 2-1:0]    s_axi_bresp        ,
   output logic             s_axi_bvalid       ,
   input  logic             s_axi_bready       ,
   input  logic [ 6-1:0]    s_axi_araddr       ,
   input  logic [ 3-1:0]    s_axi_arprot       ,
   input  logic             s_axi_arvalid      ,
   output logic             s_axi_arready      ,
   output logic [32-1:0]    s_axi_rdata        ,
   output logic [ 2-1:0]    s_axi_rresp        ,
   output logic             s_axi_rvalid       ,
   input  logic             s_axi_rready        
);

// Signal Declaration 
///////////////////////////////////////////////////////////////////////////////
logic [ 8-1:0] s_op ;
logic [32-1:0] s_data;
logic [ 4-1:0] s_data_ctr;

logic [32-1:0] s_xcom_ctrl ;
logic [6-1:0]  s_xcom_ctrl_sync ;
logic [32-1:0] s_xcom_cfg ;
logic [4-1:0]  s_xcom_cfg_sync ;
logic [4-1:0]  xcom_cfg;
logic [32-1:0] s_axi_data1;
logic [32-1:0] s_axi_data1_sync;
logic [32-1:0] s_axi_data2 ;
logic [32-1:0] s_axi_data2_sync;
logic [ 4-1:0] s_axi_addr ;
logic          s_core_en;
logic [ 5-1:0] s_core_op;
logic [2-1:0][32-1:0] s_core_data ; 
logic [2-1:0][32-1:0] s_ps_data   ; 
logic          s_req_loc;
logic          s_ack_loc;
logic          s_req_net;
logic          s_ack_net;

logic          s_core_ready;
logic          s_core_valid;
logic          s_core_flag;
logic          s_xcom_flag_ps;
logic [32-1:0] s_core_data1;
logic [32-1:0] s_core_data1_sync;
logic [32-1:0] s_core_data2;
logic [32-1:0] s_core_data2_sync;
logic [32-1:0] s_core_data1_ps;
logic [32-1:0] s_core_data2_ps;

logic [32-1:0] xcom_mem_data [15];
logic [32-1:0] axi_mem_data;

logic [32-1:0] xreg_debug;
logic [32-1:0] xreg_status;
logic [32-1:0] xreg_status_sync_r;
logic [32-1:0] xreg_status_sync_n;

logic [32-1:0] s_dbg_rx_data      ;
logic [32-1:0] s_dbg_tx_data      ;
logic [21-1:0] s_dbg_status       ;
logic [32-1:0] s_dbg_data         ;
logic [32-1:0] s_dbg_rx_data_ps   ;
logic [32-1:0] s_dbg_tx_data_ps   ;
logic [21-1:0] s_dbg_status_ps    ;
logic [32-1:0] s_dbg_data_ps      ;


///////////////////////////////////////////////////////////////////////////////
// AXI Registers
///////////////////////////////////////////////////////////////////////////////
xcom_axil_slv#(
    .C_S_AXI_ADDR_WIDTH ( 6  ),   
    .C_S_AXI_DATA_WIDTH ( 32 )   
) u_xcom_axil_slv(
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
   .i_board_id     ( s_xcom_id_ps       ),
   .i_xcom_flag    ( s_xcom_flag_ps     ),
   .i_xcom_data1   ( s_core_data1_ps    ),
   .i_xcom_data2   ( s_core_data2_ps    ),
   .i_xcom_mem     ( axi_mem_data       ),
   .i_xcom_rx_data ( s_dbg_rx_data_ps   ),
   .i_xcom_tx_data ( s_dbg_tx_data_ps   ),
   .i_xcom_status  ( xreg_status_sync_r ),//s_dbg_status_ps    ),
   .i_xcom_debug   ( xreg_debug         ) //s_dbg_debug_ps     )
   ); 

assign axi_mem_data = xcom_mem_data[s_axi_addr];

xcom_cdc#(
   .NCH          ( NCH   ),
   .SYNC         ( SYNC  ),
   .DEBUG        ( DEBUG ) 
) u_xcom_cdc(
   .i_ps_clk           ( i_ps_clk         ),
   .i_ps_rstn          ( i_ps_rstn        ),  
   .i_core_clk         ( i_core_clk       ),
   .i_core_rstn        ( i_core_rstn      ), 
   .i_time_clk         ( i_time_clk       ), 
   .i_time_rstn        ( i_time_rstn      ), 
   //core domain - time domain
   .i_core_en          ( i_core_en        ), 
   .i_core_op          ( i_core_op        ),
   .i_core_data1       ( i_core_data1     ), 
   .i_core_data2       ( i_core_data2     ), 
   .o_core_en_sync     ( s_core_en        ), 
   .o_core_op_sync     ( s_core_op        ), 
   .o_core_data1_sync  ( s_core_data1_sync), 
   .o_core_data2_sync  ( s_core_data2_sync), 
   .i_core_ready       ( s_core_ready     ), 
   .i_core_valid       ( s_core_valid     ), 
   .i_core_flag        ( s_core_flag      ), 
   .o_core_ready_sync  ( o_core_ready     ), 
   .o_core_valid_sync  ( o_core_valid     ), 
   .o_core_flag_sync   ( o_core_flag      ), 
   //time domain - PS time domain
   .i_xcom_id          ( s_xcom_id        ),
   .o_xcom_id_sync     ( s_xcom_id_ps     ), 
   .i_xcom_ctrl        ( s_xcom_ctrl      ), 
   .i_xcom_cfg         ( s_xcom_cfg       ),
   .i_axi_data1        ( s_axi_data1      ), 
   .i_axi_data2        ( s_axi_data2      ),
   .o_xcom_ctrl_sync   ( s_xcom_ctrl_sync ), 
   .o_xcom_cfg_sync    ( s_xcom_cfg_sync  ), 
   .o_axi_data1_sync   ( s_axi_data1_sync ), 
   .o_axi_data2_sync   ( s_axi_data2_sync ), 
   .o_xcom_flag_sync   ( s_xcom_flag_ps   ), 
   .o_xcom_data1_sync  ( s_core_data1_ps  ), 
   .o_xcom_data2_sync  ( s_core_data2_ps  ), 
   .i_xcom_rx_data     ( s_dbg_rx_data    ), 
   .i_xcom_tx_data     ( s_dbg_tx_data    ), 
   .i_xcom_status      ( s_dbg_status     ), 
   .i_xcom_debug       ( s_dbg_debug      ),
   .o_xcom_rx_data_sync( s_dbg_rx_data_ps ),
   .o_xcom_tx_data_sync( s_dbg_tx_data_ps ),
   .o_xcom_status_sync ( s_dbg_status_ps  ), 
   .o_xcom_debug_sync  ( s_dbg_debug_ps   )  
);

assign s_core_data  = {s_core_data2_sync, s_core_data1_sync};
assign xcom_cfg     = {s_xcom_cfg_sync[3-1:0]+1'b1, 1'b0};
assign s_ps_data    = {s_axi_data2_sync, s_axi_data1_sync};

xcom_cmd u_xcom_cmd(
   .i_clk           ( i_time_clk       ),
   .i_rstn          ( i_time_rstn      ),
   .i_core_en       ( s_core_en        ),
   .i_core_op       ( s_core_op        ),
   .i_core_data     ( s_core_data      ),
   .i_ps_ctrl       ( s_xcom_ctrl_sync ),
   .i_ps_data       ( s_ps_data        ), 
   .o_req_loc       ( s_req_loc        ),
   .i_ack_loc       ( s_ack_loc        ),
   .o_req_net       ( s_req_net        ),
   .i_ack_net       ( s_ack_net        ),
   .o_op            ( s_op             ),
   .o_data          ( s_data           ),
   .o_data_cntr     ( s_data_cntr      )
   );

xcom_txrx#(
   .NCH  ( NCH  ),
   .SYNC ( 1'b1 )
   ) u_xcom_txrx(
  .i_clk             ( i_time_clk         ),
  .i_rstn            ( i_time_rstn        ),
  .i_sync            ( i_sync             ),
  .i_req_loc         ( s_req_loc          ),
  .i_req_net         ( s_req_net          ),
  .i_header          ( s_op               ),
  .i_data            ( s_data             ), 
  .o_ack_loc         ( s_ack_loc          ),
  .o_ack_net         ( s_ack_net          ),
  .o_qp_ready        ( s_core_ready       ),
  .o_qp_valid        ( s_core_valid       ),
  .o_qp_flag         ( s_core_flag        ),
  .o_qp_data1        ( s_core_data1       ),
  .o_qp_data2        ( s_core_data2       ),
  .o_proc_start      ( o_proc_start       ),
  .o_proc_stop       ( o_proc_stop        ),
  .o_time_rst        ( o_time_rst         ),
  .o_time_update     ( o_time_update      ),
  .o_time_update_data( o_time_update_data ),
  .o_core_start      ( o_core_start       ),
  .o_core_stop       ( o_core_stop        ),
  .i_cfg_tick        ( xcom_cfg           ),
  .o_xcom_id         ( s_xcom_id          ),
  .o_xcom_mem        ( xcom_mem_data      ),//FIXME: review this because here we are crossing clock domains
  .i_xcom_data       ( i_xcom_data        ),
  .i_xcom_clk        ( i_xcom_clk         ),
  .o_xcom_data       ( o_xcom_data        ),
  .o_xcom_clk        ( o_xcom_clk         ),
  .o_dbg_rx_data     ( s_dbg_rx_data      ),
  .o_dbg_tx_data     ( s_dbg_tx_data      ),
  .o_dbg_status      ( s_dbg_status       ),
  .o_dbg_data        ( s_dbg_debug        )                                                               
);

assign o_xcom_id   = s_xcom_id;

//SYNC STAGES
///////////////////////////////////////////////////////////////////////////////
//Time domain -> PS domain
//let's synchronize some status signals coming from the time_clk
narrow_en_signal sync_req_loc(
  .i_clk  ( i_ps_clk       ),
  .i_rstn ( i_ps_rstn      ),
  .i_en   ( s_req_loc      ),
  .o_en   ( s_req_loc_sync )
);

narrow_en_signal sync_req_net(
  .i_clk  ( i_ps_clk       ),
  .i_rstn ( i_ps_rstn      ),
  .i_en   ( s_req_neti     ),
  .o_en   ( s_req_net_sync )
);

assign s_req_cmd = s_req_loc_sync | s_req_net_sync;
//Registers
//now let's catch the counter
always_ff @ (posedge i_ps_clk) begin
   if (!i_ps_rstn) xreg_status_sync_r <= '0;
   else            xreg_status_sync_r <= xreg_status_sync_n;
end

assign xreg_status        = { 8'h00,s_data_cntr, s_dbg_status};
assign xreg_status_sync_n = (s_req_cmd) ? xreg_status : xreg_status_sync_r;

//end of SYNC STAGES
///////////////////////////////////////////////////////////////////////////////
// DEBUG
///////////////////////////////////////////////////////////////////////////////
generate
   if (DEBUG == 0) begin : DEBUG_NO
      assign xreg_debug  = '{default:'0} ;
   end else if   (DEBUG == 1) begin : DEBUG_YES
      assign xreg_debug  = s_dbg_debug_ps;
   end
endgenerate

endmodule
