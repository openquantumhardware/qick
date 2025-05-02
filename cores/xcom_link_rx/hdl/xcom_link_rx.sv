///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
//
// Fermi Fordward Alliance LLC
//
// Module: xcom_link_rx.sv
// Project: QICK 
// Description: Receiver interface for the XCOM block
//
//
// Change history: 09/20/24 - v1 Started by @mdifederico
//                 05/01/25 - Refactored by @lharnaldi
//                          - the sync_n core was removed to sync all signals
//                          in one place (external).
//
///////////////////////////////////////////////////////////////////////////////

module xcom_link_rx (
    input  logic            i_clk          ,
    input  logic            i_rstn         ,
    input  logic [4-1:0]    i_id           ,
    // Command Processing    
    output logic            o_req          ,
    input  logic            i_ack          ,
    output logic  [4-1:0]   o_cmd          ,
    output logic [32-1:0]   o_data         ,
    // Xwire COM
    input  logic            i_xcom_data    ,
    input  logic            i_xcom_clk     ,
    // XCOM RX DEBUG
    output logic  [5-1:0]   o_dbg_state      
);


logic rx_no_dt, rx_last_hd, rx_time_out, rx_last_dt ;

///// RX STATE
///////////////////////////////////////////////////////////////////////////////
logic rx_idle_s, rx_header_s, rx_ok ;

typedef enum logic [3-1:0]{ RX_IDLE   = 3'b000, 
                            RX_HEADER = 3'b001, 
                            RX_DATA   = 3'b010, 
                            RX_REQ    = 3'b011, 
                            RX_ACK    = 3'b100
} state_t;
state_t state_r, state_n;


always_ff @ (posedge i_clk) begin
   if   ( !i_rstn ) state_r  <= RX_IDLE;
   else             state_r  <= state_n;
end

always_comb begin
   state_n     = state_r;
   rx_idle_s   = 1'b0;
   rx_header_s = 1'b0;
   rx_ok       = 1'b0;
   case (state_r)
      RX_IDLE:  begin
         rx_idle_s = 1'b1;
         if ( rx_new_dt ) begin
            rx_header_s = 1'b1;
            state_n = RX_HEADER; // First Transition 0 to 1
         end
      end
      RX_HEADER:  begin
         rx_header_s = 1'b1;
         if ( rx_last_hd )
            if      ( rx_no_dt  ) state_n = RX_REQ  ; // Package has No Data
            else if ( rx_new_dt ) state_n = RX_DATA ; // Package has Data   
         else if ( rx_time_out  ) state_n = RX_IDLE; // TimeOut    
      end
      RX_DATA:  begin 
         if      ( rx_last_dt  ) state_n = RX_REQ; // Last Data Received
         else if ( rx_time_out ) state_n = RX_IDLE;   // TimeOut  
      end
      RX_REQ:  begin
         if ( rx_dst_all | rx_dst_own ) begin
            rx_ok     = 1'b1;
            if (i_ack) state_n = RX_ACK;     
         end else
            state_n = RX_IDLE;
      end
      RX_ACK    :  begin
         if (!i_ack) state_n = RX_IDLE;     
      end
      default: state_n = state_r;
      
   endcase
end

// RX Serial to Paralel
///////////////////////////////////////////////////////////////////////////////
logic         i_xcom_clk2, i_xcom_data2;
logic [ 8-1:0]  rx_hd_sr ;
logic [32-1:0]  rx_dt_sr ;  

assign rx_new_dt   = i_xcom_clk2 ^ i_xcom_clk;

always_ff @ (posedge i_clk, negedge i_rstn) begin
   if (!i_rstn) begin
      i_xcom_clk2    <= 1'b0;
      i_xcom_data2    <= 1'b0;
      rx_dt_sr    <= '{default:'0} ; 
      rx_hd_sr    <= '{default:'0} ; 
   end else begin 
      i_xcom_clk2     <= i_xcom_clk;
      i_xcom_data2     <= i_xcom_data;
      if (rx_new_dt) begin
         if ( rx_header_s ) begin
            rx_hd_sr <= {rx_hd_sr[8-1:0]  , i_xcom_data2}  ;
            rx_dt_sr <= '{default:'0} ;
         end else               
            rx_dt_sr <= {rx_dt_sr[32-1:0] , i_xcom_data2 } ;
      end
   end
end


// RX Length Decoding
///////////////////////////////////////////////////////////////////////////////
logic [6-1:0] rx_pack_size;
always_comb begin
   case ( rx_hd_sr [6:5] )
      2'b00  : rx_pack_size = 6'd8  ; 
      2'b01  : rx_pack_size = 6'd16 ; 
      2'b10  : rx_pack_size = 6'd24 ; 
      2'b11  : rx_pack_size = 6'd40 ; 
      default: rx_pack_size = 6'd8  ;
   endcase
end

///////////////////////////////////////////////////////////////////////////////
// RX Measurment
logic [5-1:0] rx_time_out_cnt; // Timeout
logic [6-1:0] rx_bit_cnt     ; // Received Bit up to 40

always_ff @ (posedge i_clk, negedge i_rstn) begin
   if (!i_rstn) begin
      rx_bit_cnt      <= 8'd1;
      rx_time_out_cnt <= 5'd0;
   end else begin 
      if (rx_new_dt) begin
         rx_bit_cnt       <= rx_bit_cnt + 1'b1 ;
         rx_time_out_cnt  <= 4'd0;
      end else if (rx_idle_s) begin
         rx_bit_cnt       <= 8'd1;
         rx_time_out_cnt  <= 4'd0;
      end else
         rx_time_out_cnt  <= rx_time_out_cnt + 1'b1 ;
   end
end

assign rx_no_dt      = rx_hd_sr [5:4] == 2'b00 ;
assign rx_last_hd    = rx_new_dt & (rx_bit_cnt == 5'd8) ; // Last Header bit
assign rx_last_dt    = rx_new_dt & (rx_bit_cnt == rx_pack_size ) ; // Last Data Received
assign rx_dst_all    = rx_hd_sr[3:0] == 4'd0;
assign rx_dst_own    = rx_hd_sr[3:0] == i_id ;
assign rx_time_out   = &rx_time_out_cnt ; // New Data was not received in time

///////////////////////////////////////////////////////////////////////////////
// OUTPUTS
///////////////////////////////////////////////////////////////////////////////
assign o_dbg_state  = state_r[4:0] ;
assign o_req        = rx_ok;
assign o_cmd        = rx_hd_sr[7:4];
assign o_data       = rx_dt_sr;
   
endmodule
