///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
//
// Fermi National Accelerator Laboratory
//
// Module: xcom_cdc.sv
// Project: QICK
// Description:
// XCOM clock domain crossing synchronizer. Assumption here is that
// time_clk > core_clk > ps_clk
//
//Inputs:
// - i_ps_clk    clock signal synchronous to the PS
// - i_ps_rstn   active low reset signal synchronous to the PS
// - i_core_clk  clock signal synchronous to the core
// - i_core_rstn active low reset signal synchronous to the core
// - i_time_clk  clock signal synchronous to the time clock domain
// - i_time_rstn active low reset signal synchronous to the time clock domain
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
(
   input  logic           i_ps_clk           ,
   input  logic           i_ps_rstn          ,
   input  logic           i_core_clk         ,
   input  logic           i_core_rstn        ,
   input  logic           i_time_clk         ,
   input  logic           i_time_rstn        ,
   // ASYNC SIGNALS
   input  logic           i_sync             ,
   output logic           s_sync             ,
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
   input  logic [32-1:0]  i_core_data1_core  ,
   input  logic [32-1:0]  i_core_data2_core  ,
   input  logic           i_core_start       ,
   input  logic           i_core_stop        ,
   output logic           o_core_ready_sync  ,
   output logic           o_core_valid_sync  ,
   output logic           o_core_flag_sync   ,
   output logic [32-1:0]  o_core_data1_core  ,
   output logic [32-1:0]  o_core_data2_core  ,
   output logic           o_core_start_sync  ,
   output logic           o_core_stop_sync   ,
   // XCOM
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

   output logic           o_xcom_flag_sync   ,
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

//SYNC STAGES
///////////////////////////////////////////////////////////////////////////////

// ASYNC domain signals

cdc_bit_sync u_sync_xcom_sync (
   .i_clk      ( i_time_clk       ),
   .i_rstn     ( i_time_rstn      ),
   .i_async    ( i_sync           ),
   .o_sync     ( s_sync           )
);


///////////////////////////////////////////////////////////////////////////////
//Time domain -> PS domain

//------------------------------------------------------
// NOTE: no synchronizers are needed for data buses!!!
//       synchronization is done with the core_en

// synchronizer #(
//    .NB(4)
//    ) sync_id_ps(
//   .i_clk      ( i_ps_clk        ),
//   .i_rstn     ( i_ps_rstn       ),
//   .i_async    ( i_xcom_id       ),
//   .o_sync     ( o_xcom_id_sync  )
// );
assign o_xcom_id_sync = i_xcom_id;

// synchronizer #(
//    .NB(32)
//    ) sync_rx_data_ps(
//   .i_clk      ( i_ps_clk            ),
//   .i_rstn     ( i_ps_rstn           ),
//   .i_async    ( i_xcom_rx_data      ),
//   .o_sync     ( o_xcom_rx_data_sync )
// );
assign o_xcom_rx_data_sync = i_xcom_rx_data;

// synchronizer #(
//    .NB(32)
//    ) sync_tx_data_ps(
//   .i_clk      ( i_ps_clk            ),
//   .i_rstn     ( i_ps_rstn           ),
//   .i_async    ( i_xcom_tx_data      ),
//   .o_sync     ( o_xcom_tx_data_sync )
// );
assign o_xcom_tx_data_sync = i_xcom_tx_data;

// synchronizer #(
//    .NB(32)
//    ) sync_status_ps(
//   .i_clk      ( i_ps_clk           ),
//   .i_rstn     ( i_ps_rstn          ),
//   .i_async    ( i_xcom_status      ),
//   .o_sync     ( o_xcom_status_sync )
// );
assign o_xcom_status_sync = i_xcom_status;

// synchronizer #(
//    .NB(32)
//    ) sync_debug_ps(
//   .i_clk      ( i_ps_clk          ),
//   .i_rstn     ( i_ps_rstn         ),
//   .i_async    ( i_xcom_debug      ),
//   .o_sync     ( o_xcom_debug_sync )
// );
assign o_xcom_debug_sync = i_xcom_debug;

///////////////////////////////////////////////////////////////////////////////
//Core domain -> PS domain
cdc_bit_sync xcom_flag(
  .i_clk      ( i_ps_clk            ),
  .i_rstn     ( i_ps_rstn           ),
  .i_async    ( i_core_flag         ),
  .o_sync     ( o_xcom_flag_sync    )
);

//------------------------------------------------------
// NOTE: no synchronizers are needed for data buses!!!
//       synchronization is done with the core_en

// synchronizer #(
//    .NB(32)
//    ) sync_data1_ps(
//   .i_clk      ( i_ps_clk          ),
//   .i_rstn     ( i_ps_rstn         ),
//   .i_async    ( i_core_data1_core ),
//   .o_sync     ( o_xcom_data1_sync )
// );
assign o_xcom_data1_sync = i_core_data1_core;

// synchronizer #(
//    .NB(32)
//    ) sync_data2_ps(
//   .i_clk      ( i_ps_clk          ),
//   .i_rstn     ( i_ps_rstn         ),
//   .i_async    ( i_core_data2_core ),
//   .o_sync     ( o_xcom_data2_sync )
// );
assign o_xcom_data2_sync = i_core_data2_core;

///////////////////////////////////////////////////////////////////////////////
//PS domain -> Time domain
// synchronizer #(
//    .NB(6)
//    ) sync_xcom_ctrl(
//   .i_clk      ( i_time_clk       ),
//   .i_rstn     ( i_time_rstn      ),
//   .i_async    ( i_xcom_ctrl[6-1:0]      ),
//   .o_sync     ( o_xcom_ctrl_sync[6-1:0] )
// );
// assign o_xcom_ctrl_sync[32-1:6] = '0;

//------------------------------------------------------
// NOTE: only bit 0 needs synchronization
cdc_bit_sync sync_xcom_ctrl (
  .i_clk      ( i_time_clk       ),
  .i_rstn     ( i_time_rstn      ),
  .i_async    ( i_xcom_ctrl[0]      ),
  .o_sync     ( o_xcom_ctrl_sync[0] )
);
assign o_xcom_ctrl_sync[31:1] = i_xcom_ctrl[31:1];

//------------------------------------------------------
// NOTE: no synchronizers are needed for data buses!!!
//       synchronization is done with the core_en


// synchronizer #(
//    .NB(4)
//    ) sync_xcom_cfg(
//   .i_clk      ( i_time_clk       ),
//   .i_rstn     ( i_time_rstn      ),
//   .i_async    ( i_xcom_cfg[4-1:0]      ),
//   .o_sync     ( o_xcom_cfg_sync[4-1:0] )
// );
// assign o_xcom_cfg_sync[32-1:4] = '0;
assign o_xcom_cfg_sync = i_xcom_cfg;

// synchronizer #(
//    .NB(32)
//    ) sync_axi_data1(
//   .i_clk      ( i_time_clk       ),
//   .i_rstn     ( i_time_rstn      ),
//   .i_async    ( i_axi_data1      ),
//   .o_sync     ( o_axi_data1_sync )
// );
assign o_axi_data1_sync = i_axi_data1;

// synchronizer #(
//    .NB(32)
//    ) sync_axi_data2(
//   .i_clk      ( i_time_clk       ),
//   .i_rstn     ( i_time_rstn      ),
//   .i_async    ( i_axi_data2      ),
//   .o_sync     ( o_axi_data2_sync )
// );
assign o_axi_data2_sync = i_axi_data2;

///////////////////////////////////////////////////////////////////////////////
//Core domain -> Time domain

logic          core_en_req;
logic          core_en_req_sync;
logic          core_en_ack;
logic          core_en_ack_sync;

wide_en_signal sync_core_en(
   .i_clk  ( i_time_clk     ),
   .i_rstn ( i_time_rstn    ),
   .i_en   ( core_en_req    ),
   .o_en   ( o_core_en_sync )
);

//------------------------------------------------------
// NOTE: no synchronizers are needed for data buses!!!
//       synchronization is done with the core_en_req

logic [ 4:0]   o_core_op_reg;
logic [31:0]   o_core_data1_reg;
logic [31:0]   o_core_data2_reg;

always_ff @(posedge i_core_clk, negedge i_core_rstn) begin
   if (~i_core_rstn)
      core_en_req <= 1'b0;
   else
      if (i_core_en & o_core_ready_sync)
         core_en_req <= 1'b1;
      else if (core_en_req & core_en_ack_sync)
         core_en_req <= 1'b0;
end

cdc_bit_sync sync_core_en_req (
  .i_clk      ( i_time_clk       ),
  .i_rstn     ( i_time_rstn      ),
  .i_async    ( core_en_req      ),
  .o_sync     ( core_en_req_sync )
);

// synchronizer #(
//    .NB(5)
//    ) sync_core_op(
//   .i_clk      ( i_time_clk       ),
//   .i_rstn     ( i_time_rstn      ),
//   .i_async    ( i_core_op        ),
//   .o_sync     ( o_core_op_sync   )
// );
always_ff @(posedge i_core_clk) begin
   if (i_core_en)
      o_core_op_reg <= i_core_op;
end
assign o_core_op_sync = core_en_req ? o_core_op_reg : i_core_op;

// synchronizer #(
//    .NB(32)
//    ) sync_core_data1(
//   .i_clk      ( i_time_clk       ),
//   .i_rstn     ( i_time_rstn      ),
//   .i_async    ( i_core_data1      ),
//   .o_sync     ( o_core_data1_sync )
// );
always_ff @(posedge i_core_clk) begin
   if (i_core_en)
      o_core_data1_reg <= i_core_data1;
end
assign o_core_data1_sync = core_en_req ? o_core_data1_reg : i_core_data1;

// synchronizer #(
//    .NB(32)
//    ) sync_core_data2(
//   .i_clk      ( i_time_clk        ),
//   .i_rstn     ( i_time_rstn       ),
//   .i_async    ( i_core_data2      ),
//   .o_sync     ( o_core_data2_sync )
// );
always_ff @(posedge i_core_clk) begin
   if (i_core_en)
      o_core_data2_reg <= i_core_data2;
end
assign o_core_data2_sync = core_en_req ? o_core_data2_reg : i_core_data2;

///////////////////////////////////////////////////////////////////////////////
//Time domain -> Core domain
cdc_bit_sync sync_core_ready(
  .i_clk      ( i_core_clk        ),
  .i_rstn     ( i_core_rstn       ),
  .i_async    ( i_core_ready      ),
  .o_sync     ( o_core_ready_sync )
);

cdc_bit_sync sync_core_flag(
  .i_clk      ( i_core_clk       ),
  .i_rstn     ( i_core_rstn      ),
  .i_async    ( i_core_flag      ),
  .o_sync     ( o_core_flag_sync )
);

// Valid is a pulse
// NOTE: time domain clock is faster than core domain clock, need to stretch pulses!!!
// (a plain synchronizer can miss a fast-domain pulse entirely; cdc_handshake's
// toggle+req/ack protocol holds the request until the destination has seen it)
cdc_handshake #(.DW(1)) sync_core_valid (
  .i_clk   ( i_time_clk        ),
  .i_rstn  ( i_time_rstn       ),
  .i_data  ( 1'b0              ),
  .i_valid ( i_core_valid      ),
  .o_busy  (                   ),
  .o_clk   ( i_core_clk        ),
  .o_rstn  ( i_core_rstn       ),
  .o_data  (                   ),
  .o_valid ( o_core_valid_sync )
);

assign core_en_ack = core_en_req_sync;

cdc_bit_sync sync_core_en_ack (
  .i_clk      ( i_core_clk       ),
  .i_rstn     ( i_core_rstn      ),
  .i_async    ( core_en_ack      ),
  .o_sync     ( core_en_ack_sync )
);

cdc_bit_sync sync_core_start (
  .i_clk      ( i_core_clk        ),
  .i_rstn     ( i_core_rstn       ),
  .i_async    ( i_core_start      ),
  .o_sync     ( o_core_start_sync )
);

cdc_bit_sync sync_core_stop (
  .i_clk      ( i_core_clk        ),
  .i_rstn     ( i_core_rstn       ),
  .i_async    ( i_core_stop       ),
  .o_sync     ( o_core_stop_sync  )
);

//------------------------------------------------------
// NOTE: no synchronizers are needed for data buses!!!
//       synchronization is done with the core_valid

// synchronizer #(
//    .NB(32)
//    ) sync_data1_core(
//   .i_clk      ( i_core_clk        ),
//   .i_rstn     ( i_core_rstn       ),
//   .i_async    ( i_core_data1_core ),
//   .o_sync     ( o_core_data1_core )
// );
assign o_core_data1_core = i_core_data1_core;

// synchronizer #(
//    .NB(32)
//    ) sync_data2_core(
//   .i_clk      ( i_core_clk        ),
//   .i_rstn     ( i_core_rstn       ),
//   .i_async    ( i_core_data2_core ),
//   .o_sync     ( o_core_data2_core )
// );
assign o_core_data2_core = i_core_data2_core;
//------------------------------------------------------

//end of SYNC STAGES
///////////////////////////////////////////////////////////////////////////////

endmodule
