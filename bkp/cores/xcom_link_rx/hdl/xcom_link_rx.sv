///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
//
// Fermi Fordward Alliance LLC
//
// Module: xcom_link_rx.sv
// Project: QICK 
// Description: Receiver interface for the XCOM block
//
//Inputs:
// - i_clk       clock signal
// - i_rstn      active low reset signal
// - i_id        this input configures the ID of the board in the network. It
//               can be configured manually or automatically. 
// - i_ack       it is a one clock duration signal indicating an
//               acknowledgement from the tproc/pynq side. This means the
//               tproc/pynq side can receive and process the data arriving in
//               the XCOM link  
// - i xcom_data serial data received. This is the general data input of the
//               XCOM block
// - i_xcom_clk  serial clock for reception. This is the general clock input of
//               the XCOM block
//Outputs:
// - o_req       signal indicating valid data arrived. This signal is to
//               indicate to the tproc/pynq side there are new valid data to
//               process.
// - o_cmd       command to be executed by the tproc/pynq
// - o_data      data received, to be processed by the tproc/pynq
// - o_dbg_state debug port for monitoring the state of the internal FSM
//
// Change history: 09/20/24 - v1 Started by @mdifederico
//                 05/01/25 - Refactored by @lharnaldi
//                          - the sync_n core was removed to sync all signals
//                            in one place (external).
//
///////////////////////////////////////////////////////////////////////////////

module xcom_link_rx (
    input  logic            i_clk          ,
    input  logic            i_rstn         ,
    input  logic  [4-1:0]   i_id           ,
    // Command Processing    
    input  logic            i_ack          ,
    output logic            o_req          ,
    output logic  [4-1:0]   o_cmd          ,
    output logic [32-1:0]   o_data         ,
    // Xwire COM
    input  logic            i_xcom_data    ,
    input  logic            i_xcom_clk     ,
    // XCOM RX DEBUG
    output logic  [5-1:0]   o_dbg_state      
);


logic          s_no_data, s_header_last, s_timeout, s_data_last ;
logic          s_broadcast, s_local_id;

logic          s_xcom_clk_dly, s_xcom_data_dly;
logic [ 8-1:0] s_header_shreg ;
logic [32-1:0] s_data_shreg ;  
logic          s_new_data;

logic          s_rx_idle, s_rx_header, s_rx_req ;

typedef enum logic [3-1:0]{ IDLE   = 3'b000, 
                            HEADER = 3'b001, 
                            DATA   = 3'b010, 
                            REQ    = 3'b011, 
                            ACK    = 3'b100
} state_t;
state_t state_r, state_n;

logic [6-1:0] s_rx_pack_size;

// Timeout counter, up to 32 clock cycles. This gives roughly 64 ns with
// a t_clk = 500 MHz
logic [5-1:0] timeout_cntr_r, timeout_cntr_n; 
logic [6-1:0] bit_cntr_r, bit_cntr_n        ; // Receive up to 40 bits

// RX Serial to Paralel
///////////////////////////////////////////////////////////////////////////////
assign s_new_data   = s_xcom_clk_dly ^ i_xcom_clk;

always_ff @ (posedge i_clk) begin
   if (!i_rstn) begin
      s_xcom_clk_dly  <= 1'b0;
      s_xcom_data_dly <= 1'b0;
      s_data_shreg    <= '0; 
      s_header_shreg  <= '0; 
   end else begin 
      s_xcom_clk_dly  <= i_xcom_clk;
      s_xcom_data_dly <= i_xcom_data;
      if (s_new_data) begin
         if ( s_rx_header ) begin
            s_header_shreg <= {s_header_shreg[8-2:0], s_xcom_data_dly};
            s_data_shreg <= '0;
         end else               
            s_data_shreg <= {s_data_shreg[32-2:0], s_xcom_data_dly};
      end
   end
end

///// RX STATE
///////////////////////////////////////////////////////////////////////////////
always_ff @ (posedge i_clk) begin
   if   ( !i_rstn ) state_r  <= IDLE;
   else             state_r  <= state_n;
end

always_comb begin
   state_n     = state_r;
   s_rx_idle   = 1'b0;
   s_rx_header = 1'b0;
   s_rx_req    = 1'b0;
   case (state_r)
      IDLE:  begin
         s_rx_idle = 1'b1;
         if ( s_new_data ) begin //detects first 0 to 1 transition
            s_rx_header = 1'b1;
            state_n     = HEADER; 
         end
      end
      HEADER:  begin
         s_rx_header = 1'b1;
         if ( s_header_last )
            if      ( s_no_data  ) state_n = REQ  ; // Package has No Data
            else if ( s_new_data ) state_n = DATA ; // Package has Data   
            else if ( s_timeout  ) state_n = IDLE;  // TimeOut    
      end
      DATA:  begin 
         if      ( s_data_last ) state_n = REQ;  // Last Data Received
         else if ( s_timeout   ) state_n = IDLE; // TimeOut  
      end
      REQ:  begin
         if ( s_broadcast | s_local_id ) begin
            s_rx_req = 1'b1;
            if (i_ack & !s_timeout) state_n = ACK;
            else if (!i_ack & s_timeout) state_n = IDLE;
         end else
            state_n = IDLE;
      end
      ACK:  begin
         if (!i_ack) state_n = IDLE;     
      end
      default: state_n = state_r;
      
   endcase
end

// RX Length Decoding
///////////////////////////////////////////////////////////////////////////////
always_comb begin
   case ( s_header_shreg [6:5] )
      2'b00  : s_rx_pack_size = 6'd8  ; //8-bit header + no data
      2'b01  : s_rx_pack_size = 6'd16 ; //8-bit header + 8-bit data 
      2'b10  : s_rx_pack_size = 6'd24 ; //8-bit header + 16-bit data
      2'b11  : s_rx_pack_size = 6'd40 ; //8-bit header + 32-bit data
      default: s_rx_pack_size = 6'd8  ; //8-bit header + no data
   endcase
end

///////////////////////////////////////////////////////////////////////////////
// RX Measurment
always_ff @ (posedge i_clk) begin
   if (!i_rstn) begin
      bit_cntr_r     <= 6'b00_0001;
      timeout_cntr_r <= '0;
   end else begin
      bit_cntr_r     <= bit_cntr_n;
      timeout_cntr_r <= timeout_cntr_n;
   end
end

//next-state logic
assign bit_cntr_n     = (s_new_data) ? bit_cntr_r + 1'b1 : (s_rx_idle) ? 6'b00_0001 :  bit_cntr_r; 
assign timeout_cntr_n = (s_new_data) ? '0                : (s_rx_idle) ? '0         :  timeout_cntr_r + 1'b1; 

assign s_no_data     = (s_header_shreg [6:5] == 2'b00) ; //
assign s_header_last = s_new_data & (bit_cntr_r == 5'd8) ; // Last Header bit
assign s_data_last   = s_new_data & (bit_cntr_r == s_rx_pack_size ) ; // Last Data Received
assign s_broadcast   = (s_header_shreg[3:0] == 4'd0); //broadcast
assign s_local_id    = (s_header_shreg[3:0] == i_id) ;
assign s_timeout     = &timeout_cntr_r ; // New Data was not received in time

///////////////////////////////////////////////////////////////////////////////
// OUTPUTS
///////////////////////////////////////////////////////////////////////////////
assign o_dbg_state  = {2'b00,state_r};
assign o_req        = s_rx_req;
assign o_cmd        = s_header_shreg[7:4];
assign o_data       = s_data_shreg;
   
endmodule
