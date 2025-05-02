///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
//
// Fermi Fordward Alliance LLC
//
// Module: req_ack_cmd.sv
// Project: QICK 
// Description: Board communication peripheral
//
//
// Change history: 09/20/24 - v1 Started by @mdifederico
//                 05/01/25 - Refactored by @lharnaldi
//                          - the sync_n core was removed to sync all signals
//                          in one place (external).
//
///////////////////////////////////////////////////////////////////////////////

module xcom_link_rx (
    input  logic          i_clk     ,
    input  logic          i_rstn    ,
    input  logic [ 4-1:0] i_id      ,
    // Command Processing  
    output logic            o_req    ,
    input  logic          i_ack    ,
    output logic   [ 4-1:0] o_cmd    ,
    output logic   [32-1:0] o_data   ,
    // Xwire COM
    input  logic          i_xcom_data     ,
    input  logic          i_xcom_clk     ,
    // XCOM RX DEBUG
    output logic  [5-1:0] o_dbg_state      
);


logic rx_no_dt, rx_last_hd, rx_time_out, rx_last_dt ;

// Sync rx_clk and Data with x_clk
///////////////////////////////////////////////////////////////////////////////
sync_reg # (
   .DW ( 2 )
) c_sync_pulse (
   .dt_i      ( {i_xcom_clk, i_xcom_data} ) ,
   .clk_i     ( i_clk            ) ,
   .rst_ni    ( i_rstn           ) ,
   .dt_o      ( {rx_ck_r, rx_dt_r} ) );
   


///// RX STATE
///////////////////////////////////////////////////////////////////////////////
logic rx_idle_s, rx_header_s, rx_ok ;

typedef enum { RX_IDLE, RX_HEADER, RX_DATA, RX_REQ, RX_ACK} TYPE_RX_ST ;
(* fsm_encoding = "one_hot" *) TYPE_RX_ST rx_st;
TYPE_RX_ST rx_st_nxt;


always_ff @ (posedge i_clk) begin
   if      ( !i_rstn   )  rx_st  <= RX_IDLE;
   else                     rx_st  <= rx_st_nxt;
end
always_comb begin
   rx_st_nxt   = rx_st; // Default Current
   rx_idle_s   = 1'b0;
   rx_header_s = 1'b0;
   rx_ok       = 1'b0;
   case (rx_st)
      RX_IDLE   :  begin
         rx_idle_s = 1'b1;
         if ( rx_new_dt ) begin
            rx_header_s = 1'b1;
            rx_st_nxt = RX_HEADER; // First Transition 0 to 1
         end
      end
      RX_HEADER :  begin
         rx_header_s = 1'b1;
         if ( rx_last_hd )
            if      ( rx_no_dt  ) rx_st_nxt = RX_REQ  ; // Package has No Data
            else if ( rx_new_dt ) rx_st_nxt = RX_DATA ; // Package has Data   
         else if ( rx_time_out  ) rx_st_nxt = RX_IDLE; // TimeOut    
      end
      RX_DATA :  begin 
         if      ( rx_last_dt  ) rx_st_nxt = RX_REQ; // Last Data Received
         else if ( rx_time_out ) rx_st_nxt = RX_IDLE;   // TimeOut  
      end
      RX_REQ    :  begin
         if ( rx_dst_all | rx_dst_own ) begin
            rx_ok     = 1'b1;
            if (i_ack) rx_st_nxt = RX_ACK;     
         end else
            rx_st_nxt = RX_IDLE;
      end
      RX_ACK    :  begin
         if (!i_ack) rx_st_nxt = RX_IDLE;     
      end
      default: rx_st_nxt = rx_st;
      
   endcase
end

// RX Serial to Paralel
///////////////////////////////////////////////////////////////////////////////
logic         rx_ck_r2, rx_dt_r2;
logic [ 7:0]  rx_hd_sr ;
logic [32-1:0]  rx_dt_sr ;  

assign rx_new_dt   = rx_ck_r2 ^ rx_ck_r;

always_ff @ (posedge i_clk, negedge i_rstn) begin
   if (!i_rstn) begin
      rx_ck_r2    <= 1'b0;
      rx_dt_r2    <= 1'b0;
      rx_dt_sr    <= '{default:'0} ; 
      rx_hd_sr    <= '{default:'0} ; 
   end else begin 
      rx_ck_r2     <= rx_ck_r;
      rx_dt_r2     <= rx_dt_r;
      if (rx_new_dt) begin
         if ( rx_header_s ) begin
            rx_hd_sr <= {rx_hd_sr[7:0]  , rx_dt_r2}  ;
            rx_dt_sr <= '{default:'0} ;
         end else               
            rx_dt_sr <= {rx_dt_sr[32-1:0] , rx_dt_r2 } ;
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
assign o_dbg_state  = rx_st[4:0] ;
assign o_req        = rx_ok;
assign o_cmd        = rx_hd_sr[7:4];
assign o_data       = rx_dt_sr;
   
endmodule
