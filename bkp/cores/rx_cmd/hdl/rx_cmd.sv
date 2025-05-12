///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
//
// Fermi Fordward Alliance LLC
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
// Change history: 09/20/24 - v1.0.0 Started by @mdifederico
//                 05/09/25 - v1.1.0 Refactored by @lharnaldi
//                                   - the sync_n core was removed to sync 
//                                   all signals in one place (external).
//
///////////////////////////////////////////////////////////////////////////////
module rx_cmd # (
   parameter NCH = 2
)( 
   input  logic           i_clk            ,
   input  logic           i_rstn           ,
   // XCOM CFG
   input  logic   [4-1:0] i_id             ,
   // XCOM CNX
   input  logic [NCH-1:0] i_xcom_data      ,
   input  logic [NCH-1:0] i_xcom_clk       ,
   // Command Processing
   output logic           o_valid          ,
   output logic  [ 4-1:0] o_op             ,
   output logic  [32-1:0] o_data           ,
   output logic  [ 4-1:0] o_chid           ,
   // XCOM RX DEBUG
   output logic   [2-1:0] o_dbg_cmd_state  ,   
   output logic   [5-1:0] o_dbg_state [NCH]      
   );

typedef enum logic [2-1:0]{ IDLE = 2'b00, 
                            REQ  = 2'b01, 
                            ACK  = 2'b10 
} state_t;
state_t state_r, state_n;

//Command FSM
typedef enum logic [2-1:0]{ CMD_IDLE = 2'b00, 
                            CMD_EXEC = 2'b01, 
                            CMD_ACK  = 2'b10 
} cmd_state_t;
cmd_state_t cmd_state_r, cmd_state_n;

logic  s_req [NCH] ;
logic  s_ack [NCH] ;
logic           s_valid     ;
logic  [ 4-1:0] s_cmd  [NCH];
logic  [32-1:0] s_data [NCH];
logic  [$clog2(NCH):0] s_channel   ;

logic           s_cmd_req   ;
logic           s_cmd_wrid  ;//command write id
logic  [4-1:0]  s_cmd_chid  ;
logic           s_cmd_ack   ;
logic           s_cmd_valid ;

logic [5-1:0]   s_dbg_state [NCH];
// LINK RECEIVERS 
/////////////////////////////////////////////////////////////////////////////
genvar k;
generate
   for (k=0; k < NCH ; k=k+1) begin: RX
       xcom_link_rx u_xcom_link_rx(
           .i_clk      ( i_clk          ),
           .i_rstn     ( i_rstn         ),
           .i_id       ( i_id           ),
           .o_req      ( s_req[k]       ),
           .i_ack      ( s_ack[k]       ),
           .o_cmd      ( s_cmd[k]       ),
           .o_data     ( s_data[k]      ),
           .i_xcom_data( i_xcom_data[k] ),
           .i_xcom_clk ( i_xcom_clk[k]  ),
           .o_dbg_state( s_dbg_state[k] )
       );
       //debug
       assign o_dbg_state[k]  = s_dbg_state[k];
  end
endgenerate


// RX Command Priority Encoder
/////////////////////////////////////////////////////////////////////////////
//assign s_valid = |s_req;

//assign s_channel = $clog2(s_req + 1'b1);
logic one_hot_vector [NCH];
always_comb begin
   case (s_req)
      default: begin
         s_channel = '0; // Default case for all zeros or non-one-hot
         s_valid   = '0; // Default case for all zeros or non-one-hot
         // Use a loop to generate the one-hot cases
         for (integer i = 0; i < NCH; i++) begin
            one_hot_vector[i] = 1'b1;
            if (s_req[i] == one_hot_vector[i]) begin
               s_channel = i;
               s_valid   = 1'b1;
            end
         end
      end
   endcase
end

//RX FSM
always_ff @ (posedge i_clk) begin
   if ( !i_rstn ) state_r <= IDLE;
   else           state_r <= state_n;
end

always_comb begin
   state_n    = state_r; 
   s_cmd_req  = 1'b0;
   s_cmd_wrid = 1'b0;
   case (state_r)
      IDLE: begin
         if ( s_valid ) begin
            s_cmd_req  = 1'b1;
            s_cmd_wrid = 1'b1;
            state_n    = REQ;
         end
      end
      REQ: begin
         s_cmd_req = 1'b1;
         if ( s_cmd_ack ) state_n = ACK;     
      end
      ACK: begin
         if ( !s_cmd_ack ) state_n = IDLE;     
      end
      default: state_n = state_r;
   endcase
end

// RX Caller ID
/////////////////////////////////////////////////////////////////////////////
always_ff @ (posedge i_clk) begin
   if      ( !i_rstn )      s_cmd_chid  <= 0;
   else if ( s_cmd_wrid ) s_cmd_chid  <= s_channel + 1'b1;
end

// RX Command Decoder ACK
/////////////////////////////////////////////////////////////////////////////
always_comb begin
   for (int ind_ch=0; ind_ch < NCH ; ind_ch=ind_ch+1) begin: RX_DECOX
      if (ind_ch == s_cmd_chid)
         s_ack[ind_ch] = s_cmd_ack;
      else 
         s_ack[ind_ch] = 1'b0;
    end
end

always_ff @ (posedge i_clk) begin
   if ( !i_rstn   ) cmd_state_r <= CMD_IDLE;
   else             cmd_state_r <= cmd_state_n;
end

always_comb begin
   cmd_state_n = cmd_state_r;
   s_cmd_valid = 1'b0;
   s_cmd_ack   = 1'b0;
   case (cmd_state_r)
      CMD_IDLE: begin
         if ( s_cmd_req ) begin
            s_cmd_valid  = 1'b1;
            s_cmd_ack    = 1'b1;
            cmd_state_n  = CMD_EXEC;
         end
      end
      CMD_EXEC: begin
         s_cmd_valid = 1'b1;
         s_cmd_ack   = 1'b1;
         cmd_state_n = CMD_ACK;     
      end
      CMD_ACK: begin
         s_cmd_ack    = 1'b1;
         if ( !s_cmd_req )
            cmd_state_n  = CMD_IDLE; 
      end
      default: cmd_state_n = cmd_state_r;
   endcase
end

// DEBUG
///////////////////////////////////////////////////////////////////////////////
assign o_dbg_cmd_state = cmd_state_r;

// OUTPUTS
///////////////////////////////////////////////////////////////////////////////
assign o_op    = s_cmd[s_cmd_chid];
assign o_data  = s_data[s_cmd_chid];
assign o_chid  = s_cmd_chid ;
assign o_valid = s_cmd_valid;

endmodule
