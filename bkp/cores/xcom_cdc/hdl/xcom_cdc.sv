///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
//
// Fermi Fordward Alliance LLC
//
// Module: xcom_cdc.sv
// Project: QICK 
// Description: 
// XCOM clock domain crossing synchronizer. 
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
// Change history: 05/15/25 - Started by @lharnaldi
//
///////////////////////////////////////////////////////////////////////////////
module xcom_cdc
# (
   parameter CH           = 2 ,
   parameter SYNC         = 1 ,
   parameter DEBUG        = 1
)(
   input  logic           i_ps_clk           ,
   input  logic           i_ps_rstn          ,  
   input  logic           i_core_clk         ,
   input  logic           i_core_rstn        ,
   input  logic           i_time_clk         ,
   input  logic           i_time_rstn        ,
// QICK PERIPHERAL INTERFACE (i_core_clk)
   input  logic           i_core_en          , 
   input  logic  [5-1:0]  i_core_op          , 
   input  logic [32-1:0]  i_core_data1       , 
   input  logic [32-1:0]  i_core_data2       , 
   output logic           o_core_en_sync     , 
   output logic  [5-1:0]  o_core_op_sync     , 
   output logic [32-1:0]  o_core_data1_sync  , 
   output logic [32-1:0]  o_core_data2_sync  , 
   input  logic           i_core_ready       , 
   input  logic           i_core_valid       , 
   input  logic           i_core_flag        , 
   output logic           o_core_ready_sync  , 
   output logic           o_core_valid_sync  , 
   output logic           o_core_flag_sync   , 
// XCOM 
   input  logic           i_ack_loc          , 
   input  logic           i_ack_net          , 
   input  logic [ 4-1:0]  i_xcom_id          ,
   output logic [ 4-1:0]  o_xcom_id_sync     ,
// AXI-Lite DATA Slave I/F (i_ps_clk)
   input  logic [32-1:0]  i_xcom_ctrl        ,
   input  logic [32-1:0]  i_xcom_cfg         ,
   input  logic [32-1:0]  i_axi_data1        ,
   input  logic [32-1:0]  i_axi_data2        ,
   output logic [32-1:0]  o_xcom_ctrl_sync   ,
   output logic [32-1:0]  o_xcom_cfg_sync    ,
   output logic [32-1:0]  o_axi_data1_sync   ,
   output logic [32-1:0]  o_axi_data2_sync   ,

   output logic [32-1:0]  o_xcom_flag_sync   ,
   output logic [32-1:0]  o_xcom_data1_sync  ,
   output logic [32-1:0]  o_xcom_data2_sync  ,

   input  logic [32-1:0]   i_xcom_rx_data    , 
   input  logic [32-1:0]   i_xcom_tx_data    , 
   input  logic [32-1:0]   i_xcom_status     , 
   input  logic [32-1:0]   i_xcom_debug      ,
   output logic [32-1:0]   o_xcom_rx_data_sync, 
   output logic [32-1:0]   o_xcom_tx_data_sync, 
   output logic [32-1:0]   o_xcom_status_sync , 
   output logic [32-1:0]   o_xcom_debug_sync  
); 

// Signal Declaration 
///////////////////////////////////////////////////////////////////////////////
logic          s_ack_loc_ps;
logic          s_ack_net_ps;
logic [ 4-1:0] s_id_r; 
logic [ 4-1:0] s_id_n;
logic          s_core_valid_sync;
logic [32-1:0] core_data1_sync_r;
logic [32-1:0] core_data1_sync_n;
logic [32-1:0] core_data2_sync_r;
logic [32-1:0] core_data2_sync_n;

logic [32-1:0] core_data1_ps_r;
logic [32-1:0] core_data1_ps_n;
logic [32-1:0] core_data2_ps_r;
logic [32-1:0] core_data2_ps_n;

logic [32-1:0] s_xcom_rx_data_r;
logic [32-1:0] s_xcom_rx_data_n;
logic [32-1:0] s_xcom_tx_data_r;
logic [32-1:0] s_xcom_tx_data_n;
logic [32-1:0] s_xcom_status_r;
logic [32-1:0] s_xcom_status_n;
logic [32-1:0] s_xcom_debug_r;
logic [32-1:0] s_xcom_debug_n;

//SYNC STAGES
///////////////////////////////////////////////////////////////////////////////
//Time domain -> PS domain
//let's synchronize some status signals coming from the time_clk
narrow_en_signal sync_ack_loc(
  .i_clk  ( i_ps_clk     ),
  .i_rstn ( i_ps_rstn    ),
  .i_en   ( i_ack_loc    ),
  .o_en   ( s_ack_loc_ps )
);

narrow_en_signal sync_ack_net(
  .i_clk  ( i_ps_clk     ),
  .i_rstn ( i_ps_rstn    ),
  .i_en   ( i_ack_net    ),
  .o_en   ( s_ack_net_ps )
);
assign s_ack = s_ack_loc_ps | s_ack_net_ps;
//Registers
//now let's catch the counter
always_ff @ (posedge i_ps_clk) begin
    if (!i_ps_rstn) begin
        s_id_r <= '0;
        s_xcom_rx_data_r <= '0;
        s_xcom_tx_data_r <= '0;
        s_xcom_status_r <= '0;
        s_xcom_debug_r <= '0;
    end else begin
        s_id_r <= s_id_n;
        s_xcom_rx_data_r <= s_xcom_rx_data_n;
        s_xcom_tx_data_r <= s_xcom_tx_data_n;
        s_xcom_status_r  <= s_xcom_status_n;
        s_xcom_debug_r   <= s_xcom_debug_n;
    end
end
assign s_id_n           = (s_ack) ? i_xcom_id : s_id_r;
assign s_xcom_rx_data_n = (s_ack) ? i_xcom_rx_data : s_xcom_rx_data_r;
assign s_xcom_tx_data_n = (s_ack) ? i_xcom_tx_data : s_xcom_tx_data_r;
assign s_xcom_status_n  = (s_ack) ? i_xcom_status  : s_xcom_status_r;
assign s_xcom_debug_n   = (s_ack) ? i_xcom_debug   : s_xcom_debug_r;

assign o_xcom_id_sync = s_id_r;
assign o_xcom_rx_data_sync = s_xcom_rx_data_r;
assign o_xcom_tx_data_sync = s_xcom_tx_data_r;
assign o_xcom_status_sync  = s_xcom_status_r;
assign o_xcom_debug_sync   = s_xcom_debug_r;

narrow_en_signal xcom_flag(
  .i_clk  ( i_ps_clk     ),
  .i_rstn ( i_ps_rstn    ),
  .i_en   ( i_core_flag  ),
  .o_en   ( o_xcom_flag_sync )
);

narrow_en_signal sync_core_valid_ps(
  .i_clk  ( i_ps_clk   ),
  .i_rstn ( i_ps_rstn  ),
  .i_en   ( i_core_valid ),
  .o_en   ( s_core_valid_ps )
);

always_ff @ (posedge i_ps_clk) begin
   if (!i_ps_rstn) begin
      core_data1_ps_r <= '0;
      core_data2_ps_r <= '0;
   end else begin
      core_data1_ps_r <= core_data1_ps_n;
      core_data2_ps_r <= core_data2_ps_n;
   end
end

assign core_data1_ps_n = (s_core_valid_ps) ? i_core_data1 : core_data1_ps_r;
assign core_data2_ps_n = (s_core_valid_ps) ? i_core_data2 : core_data2_ps_r;

//output
assign o_xcom_data1_sync = core_data1_ps_r;
assign o_xcom_data2_sync = core_data2_ps_r;

///////////////////////////////////////////////////////////////////////////////
//PS domain -> Time domain
synchronizer#(
   .NB(6)
   ) sync_xcom_ctrl(
  .i_clk      ( i_time_clk        ),
  .i_rstn     ( i_time_rstn       ),
  .i_async    ( i_xcom_ctrl[6-1:0]),
  .o_sync     ( o_xcom_ctrl_sync  )
);

synchronizer#(
   .NB(4)
   ) sync_xcom_cfg(
  .i_clk      ( i_time_clk        ),
  .i_rstn     ( i_time_rstn       ),
  .i_async    ( i_xcom_cfg[4-1:0] ),
  .o_sync     ( o_xcom_cfg_sync   )
);
//assign   xcom_cfg = {s_xcom_cfg_sync[3-1:0]+1'b1, 1'b0}; FIXME: check if
//this signal is in xcom

synchronizer#(
   .NB(32)
   ) sync_axi_data1(
  .i_clk      ( i_time_clk        ),
  .i_rstn     ( i_time_rstn       ),
  .i_async    ( i_axi_data1       ),
  .o_sync     ( o_axi_data1_sync  )
);

synchronizer#(
   .NB(32)
   ) sync_axi_data2(
  .i_clk      ( i_time_clk        ),
  .i_rstn     ( i_time_rstn       ),
  .i_async    ( i_axi_data2       ),
  .o_sync     ( o_axi_data2_sync  )
);


///////////////////////////////////////////////////////////////////////////////
//Core domain -> Time domain
synchronizer#(
   .NB(1)
   ) sync_core_en(
  .i_clk      ( i_time_clk        ),
  .i_rstn     ( i_time_rstn       ),
  .i_async    ( i_core_en         ),
  .o_sync     ( o_core_en_sync    )
);

synchronizer#(
   .NB(5)
   ) sync_core_op(
  .i_clk      ( i_time_clk        ),
  .i_rstn     ( i_time_rstn       ),
  .i_async    ( i_core_op         ),
  .o_sync     ( o_core_op_sync    )
);

synchronizer#(
   .NB(32)
   ) sync_core_data1(
  .i_clk      ( i_time_clk        ),
  .i_rstn     ( i_time_rstn       ),
  .i_async    ( i_core_data1      ),
  .o_sync     ( o_core_data1_sync )
);

synchronizer#(
   .NB(32)
   ) sync_core_data2(
  .i_clk      ( i_time_clk        ),
  .i_rstn     ( i_time_rstn       ),
  .i_async    ( i_core_data2      ),
  .o_sync     ( o_core_data2_sync )
);

///////////////////////////////////////////////////////////////////////////////
//Time domain -> Core domain
narrow_en_signal sync_core_ready(
  .i_clk  ( i_core_clk        ),
  .i_rstn ( i_core_rstn       ),
  .i_en   ( i_core_ready      ),
  .o_en   ( o_core_ready_sync )
);

narrow_en_signal sync_core_valid(
  .i_clk  ( i_core_clk   ),
  .i_rstn ( i_core_rstn  ),
  .i_en   ( i_core_valid ),
  .o_en   ( s_core_valid_sync )
);
assign o_core_valid_sync = s_core_valid_sync;

narrow_en_signal sync_core_flag(
  .i_clk  ( i_core_clk   ),
  .i_rstn ( i_core_rstn  ),
  .i_en   ( i_core_flag  ),
  .o_en   ( o_core_flag_sync  )
);

//Registers
//now let's catch the data
always_ff @ (posedge i_core_clk) begin
   if (!i_core_rstn) begin
      core_data1_sync_r <= '0;
      core_data2_sync_r <= '0;
   end else begin
      core_data1_sync_r <= core_data1_sync_n;
      core_data2_sync_r <= core_data2_sync_n;
   end
end

assign core_data1_sync_n = (s_core_valid_sync) ? i_core_data1 : core_data1_sync_r;
assign core_data2_sync_n = (s_core_valid_sync) ? i_core_data2 : core_data2_sync_r;

//end of SYNC STAGES
///////////////////////////////////////////////////////////////////////////////

endmodule
