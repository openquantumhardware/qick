///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
//
// Fermi National Accelerator Laboratory
//
// Module: rx_cmd.sv
// Project: QICK
// Description:
// Receiver interface wrapper for the XCOM block. Synchronizes the
// xcom_link_rx block through the external i_sync signal.
//
//Parameters:
// - NCH        number of RX channels
//Inputs:
// - i_clk       clock signal
// - i_rstn      active low reset signal
// - i_id        local ID (address) of the board. The range is from 1 to 16.
// - i xcom_data serial data received. This is the general data input of the
//               XCOM block. This port length depends on the number of
//               channels
// - i_xcom_clk  serial clock for reception. This is the general clock input of
//               the XCOM block. This port length depends on the number of
//               channels
//Outputs:
// - o_valid    signal indicating valid data is available
// - o_op       opcode to be excecuted
// - o_data     data receved.
// - o_chid     id of the board sending data
// - o_dbg_state debug port for monitoring the state of the internal FSM
//
// Change history: 09/20/24 - v1.0.0 Started by @mdifederico
//                 05/09/25 - v1.1.0 Refactored by @lharnaldi
//                                   - the sync_n core was removed to sync
//                                   all signals in one place (external).
//
///////////////////////////////////////////////////////////////////////////////
module rx_cmd # (
   parameter int NCH = 2,
   parameter int LOOPBACK = 0
)(
   input  logic           i_clk            ,
   input  logic           i_rstn           ,
   input  logic           i_ps_clk         ,
   input  logic           i_ps_rstn        ,
   // XCOM CFG
   input  logic   [4-1:0] i_id             ,
   input  logic           i_cfg_clk_pha    ,
   input  logic           i_cfg_auto_pha   ,
   input  logic           i_cfg_loopback   ,
   input  logic [32-1:0]  i_xcom_tx_rx_ddr ,
   // XCOM CNX
   input  logic [NCH-1:0] i_xcom_data      ,
   input  logic [NCH-1:0] i_xcom_clk       ,
   // Command Processing
   output logic           o_valid          ,
   output logic  [ 4-1:0] o_op             ,
   output logic  [32-1:0] o_data           ,
   output logic  [ 4-1:0] o_chid           ,
   // XCOM RX DEBUG
   output logic   [5-1:0] o_dbg_state [NCH]
   );

typedef enum logic [2-1:0]{ IDLE = 2'b00,
                            REQ  = 2'b01,
                            ACK  = 2'b10
} state_t;
state_t state_r, state_n;

logic [NCH-1:0]         s_req       ;
logic [NCH-1:0]         s_req_int   ;
logic [NCH-1:0]         s_ack       ;
logic  [ 4-1:0]         s_cmd  [NCH];
logic  [32-1:0]         s_data [NCH];
logic [4-1:0]           s_channel   ;
logic                   s_valid     ;
logic                   s_cmd_req   ;
logic [4-1:0]           s_cmd_chid  ;
logic                   cmd_ack_r   ;
logic                   cmd_ack_n   ;
logic [5-1:0]           s_dbg_state [NCH];

// LINK RECEIVERS
/////////////////////////////////////////////////////////////////////////////
generate
   for (genvar k=0; k < NCH ; k=k+1) begin: gen_rx
      localparam string DELAY_SRC = (LOOPBACK && (k==NCH-1)) ? "DATAIN" : "IDATAIN";
      xcom_link_rx #(
         .DELAY_SRC           (DELAY_SRC)
      )
      u_xcom_link_rx (
         .i_clk               ( i_clk          ),
         .i_rstn              ( i_rstn         ),
         .i_ps_clk            ( i_ps_clk       ),
         .i_ps_rstn           ( i_ps_rstn      ),
         .i_id                ( i_id           ),
         .i_pha               ( i_cfg_clk_pha  ),
         .i_auto_pha          ( i_cfg_auto_pha ),
         .i_xcom_tx_rx_ddr    ( i_xcom_tx_rx_ddr ),
         .o_req               ( s_req[k]       ),
         .i_ack               ( s_ack[k]       ),
         .o_cmd               ( s_cmd[k]       ),
         .o_data              ( s_data[k]      ),
         .i_xcom_data         ( i_xcom_data[k] ),
         .i_xcom_clk          ( i_xcom_clk[k]  ),
         .o_dbg_state         ( s_dbg_state[k] )
      );
      //debug
      assign o_dbg_state[k]  = s_dbg_state[k];
  end
endgenerate


// RX Command Priority Encoder
/////////////////////////////////////////////////////////////////////////////
assign s_valid = |s_req_int;

generate
   if (LOOPBACK == 0) begin : gen_no_loopback
      assign s_req_int  = s_req ;
   end else begin : gen_loopback
      // when loopback is enabled, the req either comes from the real channel if cfg_loopback is 0, or from the loopback channel if cfg_loopback is 1.
      assign s_req_int  = ~i_cfg_loopback ? {1'b0,s_req[NCH-2:0]} : {s_req[NCH-1:1],1'b0};
   end
endgenerate

always_comb begin
   unique case (1'b1)
      s_req_int[0] : s_channel = 0;
      s_req_int[1] : s_channel = 1;
      s_req_int[2] : s_channel = 2;
      s_req_int[3] : s_channel = 3;
      s_req_int[4] : s_channel = 4;
      s_req_int[5] : s_channel = 5;
      s_req_int[6] : s_channel = 6;
      s_req_int[7] : s_channel = 7;
      s_req_int[8] : s_channel = 8;
      s_req_int[9] : s_channel = 9;
      s_req_int[10]: s_channel = 10;
      s_req_int[11]: s_channel = 11;
      s_req_int[12]: s_channel = 12;
      s_req_int[13]: s_channel = 13;
      s_req_int[14]: s_channel = 14;
      s_req_int[15]: s_channel = 15;
      default      : s_channel = 0;
   endcase
   if (s_channel > NCH-1) begin
      s_channel = 0;
   end
end

// RX Caller ID
/////////////////////////////////////////////////////////////////////////////
always_ff @ (posedge i_clk) begin
   if      ( !i_rstn ) s_cmd_chid  <= 0;
   else if ( s_valid ) s_cmd_chid  <= s_channel;
end

// RX Command Decoder ACK
/////////////////////////////////////////////////////////////////////////////
always_comb begin
   for (int ind_ch=0; ind_ch < NCH ; ind_ch=ind_ch+1) begin: RX_DECOX
      if (ind_ch == s_cmd_chid)
         s_ack[ind_ch] = cmd_ack_r;
      else
         s_ack[ind_ch] = 1'b0;
    end
end

//registers
always_ff @ (posedge i_clk) begin
   if ( !i_rstn   ) cmd_ack_r <= 1'b0;
   else             cmd_ack_r <= cmd_ack_n;
end
assign cmd_ack_n = s_cmd_req ? 1'b1 : 1'b0;

//RX FSM
always_ff @ (posedge i_clk) begin
   if ( !i_rstn ) state_r <= IDLE;
   else           state_r <= state_n;
end

always_comb begin
   state_n    = state_r;
   s_cmd_req  = 1'b0;
   case (state_r)
      IDLE: begin
         if ( s_valid ) begin
            s_cmd_req = 1'b1;
            state_n    = REQ;
         end
      end
      REQ: begin
         if ( cmd_ack_r ) state_n = ACK;
      end
      ACK: begin
         if ( !cmd_ack_r ) state_n = IDLE;
      end
      default: state_n = state_r;
   endcase
end

// OUTPUTS
///////////////////////////////////////////////////////////////////////////////
assign o_op    = s_cmd[s_cmd_chid];
assign o_data  = s_data[s_cmd_chid];
assign o_chid  = s_cmd_chid ;
assign o_valid = cmd_ack_r;

endmodule
