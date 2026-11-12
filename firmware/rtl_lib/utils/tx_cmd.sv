///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
//
// Fermi National Accelerator Laboratory
//
// Module: tx_cmd.sv
// Project: QICK
// Description:
// Transmitter interface wrapper for the XCOM block. Synchronizes the
// xcom_link_tx block through the external i_sync signal.
//
//Inputs:
// - i_clk      clock signal
// - i_rstn     active low reset signal
// - i_sync     synchronization signal. Lets the XCOM synchronize with an
//              external signal. Actuates in coordination with the
//              QRST_SYNC command.
// - i_cfg_tick this input is connected to the AXI_CFG register and
//              determines the duration of the xcom_clk output signal.
//              xcom_clk will be either in state 1 or 0 for CFG_AXI clock
//              cycles (i_clk). Possible values ranges from 0 to 7 with
//              0 equal to two clock cycles and 7 equal to 15 clock
//              cycles. As an example, if i_cfg_tick = 2 and
//              i_clk = 500 MHz, then xcom_clk would be ~125 MHz.
// - i_req      transmission requirement signal. Signal indicating a new
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
// Change history: 09/20/24 - v1 Started by @mdifederico
//                 05/06/25 - Refactored by @lharnaldi
//                          - the sync_n core was removed to sync all signals
//                            in one place (external).
//
///////////////////////////////////////////////////////////////////////////////

module tx_cmd(
   input  logic          i_clk      ,
   input  logic          i_rstn     ,
   input  logic          i_ps_clk   ,
   input  logic          i_ps_rstn  ,
   input  logic          i_sync     ,
   // Config
   input  logic [4-1:0]  i_cfg_tick ,
   input  logic          i_cfg_clk_pol,
   input  logic          i_cfg_sync_dis,
   input  logic [32-1:0] i_xcom_tx_rx_ddr,
   // Transmission
   input  logic          i_req      ,
   input  logic [8-1:0]  i_header   ,
   input  logic [32-1:0] i_data     ,
   output logic          o_ready    ,
   // XCOM CNX
   output logic [1:0]    o_data     ,
   output logic [1:0]    o_clk      ,
   // XCOM TX DEBUG
   output logic  [2-1:0] o_dbg_state
   );

logic s_ready;
logic sync_dly_r, sync_dly_n;
logic s_tx_valid;
logic s_xcmd_sync;
logic s_sync;

logic [8:0] s_oddr_dly_value;
logic       s_cfg_clk_boost;
logic       s_cfg_bist_en;
logic [3:0] bist_cnt_r;
logic [3:0] bist_cnt_en_r;

typedef enum logic [2-1:0]{ IDLE  = 2'b00,
                            BIST  = 2'b01,
                            WSYNC = 2'b10,
                            WRDY  = 2'b11
} state_t;
state_t state_r, state_n;


// PULSE SYNC
///////////////////////////////////////////////////////////////////////////////
assign s_xcmd_sync  = ( i_header[7:4] == 4'b1000 ); // Sync Command

always_ff@(posedge i_clk) begin
    if (!i_rstn) sync_dly_r <= 1'b0;
    else         sync_dly_r <= sync_dly_n;
end

assign sync_dly_n = i_sync;
// Pulse on rising edge of i_sync
assign s_sync = (!sync_dly_r & i_sync) || i_cfg_sync_dis ;


// TX Control state
///////////////////////////////////////////////////////////////////////////////
always_ff @ (posedge i_clk) begin
   if ( !i_rstn ) state_r <= IDLE;
   else           state_r <= state_n;
end

always_comb begin
   state_n = state_r;
   s_tx_valid  = 1'b0;
   case (state_r)
      IDLE:  begin
         if ( s_cfg_bist_en ) begin
            state_n = BIST;
         end
         if ( i_req ) begin
            if ( s_xcmd_sync ) begin
               state_n = WSYNC;
            end else begin
               s_tx_valid = 1'b1;
               state_n    = WRDY;
               //state_n    = WVLD;
            end
         end
      end
      WSYNC:  begin
         if ( s_sync ) begin
            s_tx_valid = 1'b1;
            state_n    = WRDY;
         end
      end
      WRDY:  begin
         if ( !i_req & s_ready ) state_n = IDLE;
      end
      BIST: begin
         if ( !s_cfg_bist_en ) state_n = IDLE;
         s_tx_valid = s_ready & (bist_cnt_en_r == 0);
      end
      default: state_n = state_r;
   endcase
end

assign s_oddr_dly_value = i_xcom_tx_rx_ddr[0+:9];
assign s_cfg_clk_boost  = i_xcom_tx_rx_ddr[11];
assign s_cfg_bist_en    = i_xcom_tx_rx_ddr[15];

xcom_link_tx u_xcom_link_tx(
   .i_clk               ( i_clk           ),
   .i_rstn              ( i_rstn          ),
   .i_ps_clk            ( i_ps_clk        ),
   .i_ps_rstn           ( i_ps_rstn       ),
   .i_cfg_tick          ( i_cfg_tick      ),
   .i_cfg_clk_pol       ( i_cfg_clk_pol   ),
   .i_cfg_clk_boost     ( s_cfg_clk_boost ),
   .i_oddr_dly_value    ( s_oddr_dly_value ),
   .i_valid             ( s_tx_valid      ),
   .i_header            ( ~s_cfg_bist_en ? i_header : 8'hA0 ),
   .i_data              ( ~s_cfg_bist_en ? i_data : {~bist_cnt_r, bist_cnt_r} ),
   .o_ready             ( s_ready         ),
   .o_data              ( o_data          ),
   .o_clk               ( o_clk           )
);

always_ff @(posedge i_clk) begin
   if ( !i_rstn ) begin
      bist_cnt_r <= 0;
      bist_cnt_en_r <= 0;
   end else begin
      if (s_cfg_bist_en) begin
         if (o_ready & s_tx_valid) begin
            bist_cnt_r <= bist_cnt_r + 1;
         end
      end else begin
         bist_cnt_r <= 0;
      end
      if (s_cfg_bist_en) begin
         if (o_ready) begin
            bist_cnt_en_r <= bist_cnt_en_r + 1;
         end
      end
      else begin
         bist_cnt_en_r <= 0;
      end
   end

end



// OUTPUTS
assign o_ready     = s_ready;
assign o_dbg_state = state_r;

endmodule

