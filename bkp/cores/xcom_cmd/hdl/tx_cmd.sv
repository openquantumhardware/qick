///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
//
// Fermi Fordward Alliance LLC
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
   input  logic          i_sync     ,
   // Config 
   input  logic [4-1:0]  i_cfg_tick ,
   // Transmission 
   input  logic          i_req      ,
   input  logic [8-1:0]  i_header   ,
   input  logic [32-1:0] i_data     ,
   output logic          o_ready    ,
   // XCOM CNX
   output logic          o_data     ,
   output logic          o_clk      ,
   // XCOM TX DEBUG
   output logic  [2-1:0] o_dbg_state   
   );

logic s_ready;
logic i_sync_dly_r, i_sync_dly_n;
logic s_tx_valid;
logic s_xcmd_sync;
logic s_sync;

typedef enum logic [2-1:0]{ IDLE  = 2'b00, 
                            WSYNC = 2'b01, 
                            WRDY  = 2'b10 
} state_t;
state_t state_r, state_n;


// PULSE SYNC 
///////////////////////////////////////////////////////////////////////////////
assign s_xcmd_sync  = ( i_header[7:4] == 4'b1000 ); // Sync Command

always_ff@(posedge i_clk) begin
    if (!i_rstn) i_sync_dly_r <= 1'b0;
    else         i_sync_dly_r <= i_sync_dly_n;
end
    
assign i_sync_dly_n = i_sync;
assign s_sync = !i_sync_dly_r & i_sync ;


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
         if ( i_req )
            if ( s_xcmd_sync )
               state_n = WSYNC;     
            else begin
               state_n    = WRDY;     
               s_tx_valid = 1'b1;
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
      default: state_n = state_r;
   endcase
end

xcom_link_tx
u_xcom_link_tx
(
  .i_clk      ( i_clk      ),
  .i_rstn     ( i_rstn     ),
  .i_cfg_tick ( i_cfg_tick ),
  .i_valid    ( s_tx_valid ),
  .i_header   ( i_header   ),
  .i_data     ( i_data     ), 
  .o_ready    ( s_ready    ),
  .o_data     ( o_data     ),
  .o_clk      ( o_clk      )
);

// OUTPUTS
///////////////////////////////////////////////////////////////////////////////
assign o_dbg_state = state_r;
assign o_ready     = s_ready;

endmodule

