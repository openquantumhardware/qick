///////////////////////////////////////////////////////////////////////////////
//  FERMI RESEARCH LAB
///////////////////////////////////////////////////////////////////////////////
//  Author         : Martin Di Federico
//  Date           : 2024_5
//  Version        : 1
///////////////////////////////////////////////////////////////////////////////

module xcom_link_rx (
// CLK & RST
   input  wire          x_clk_i     ,
   input  wire          x_rst_ni    ,
   input  wire [ 3:0]   xcom_id_i   ,
// Command Processing  
   output reg           rx_req_o    ,
   input  wire          rx_ack_i    ,
   output reg  [ 3:0]   rx_cmd_o    ,
   output reg  [31:0]   rx_data_o   ,
// Xwire COM
   input  wire          rx_dt_i     ,
   input  wire          rx_ck_i     ,
// XCOM RX DEBUG
   output wire  [4:0]   rx_st_do      
   );


wire rx_no_dt, rx_last_hd, rx_time_out, rx_last_dt ;

// Sync rx_clk and Data with x_clk
///////////////////////////////////////////////////////////////////////////////
sync_reg # (
   .DW ( 2 )
) c_sync_pulse (
   .dt_i      ( {rx_ck_i, rx_dt_i} ) ,
   .clk_i     ( x_clk_i            ) ,
   .rst_ni    ( x_rst_ni           ) ,
   .dt_o      ( {rx_ck_r, rx_dt_r} ) );
   



///// RX STATE
///////////////////////////////////////////////////////////////////////////////
reg rx_idle_s, rx_header_s, rx_ok ;

typedef enum { RX_IDLE, RX_HEADER, RX_DATA, RX_REQ, RX_ACK} TYPE_RX_ST ;
(* fsm_encoding = "one_hot" *) TYPE_RX_ST rx_st;
TYPE_RX_ST rx_st_nxt;


always_ff @ (posedge x_clk_i) begin
   if      ( !x_rst_ni   )  rx_st  <= RX_IDLE;
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
            if (rx_ack_i) rx_st_nxt = RX_ACK;     
         end else
            rx_st_nxt = RX_IDLE;
      end
      RX_ACK    :  begin
         if (!rx_ack_i) rx_st_nxt = RX_IDLE;     
      end
      default: rx_st_nxt = rx_st;
      
   endcase
end

// RX Serial to Paralel
///////////////////////////////////////////////////////////////////////////////
reg         rx_ck_r2, rx_dt_r2;
reg [ 7:0]  rx_hd_sr ;
reg [31:0]  rx_dt_sr ;  

assign rx_new_dt   = rx_ck_r2 ^ rx_ck_r;

always_ff @ (posedge x_clk_i, negedge x_rst_ni) begin
   if (!x_rst_ni) begin
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
            rx_dt_sr <= {rx_dt_sr[31:0] , rx_dt_r2 } ;
      end
   end
end


// RX Length Decoding
///////////////////////////////////////////////////////////////////////////////
reg [5:0] rx_pack_size;
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
reg [4:0] rx_time_out_cnt; // Timeout
reg [5:0] rx_bit_cnt     ; // Received Bit up to 40

always_ff @ (posedge x_clk_i, negedge x_rst_ni) begin
   if (!x_rst_ni) begin
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
assign rx_dst_own    = rx_hd_sr[3:0] == xcom_id_i ;

assign rx_time_out   = &rx_time_out_cnt ; // New Data was not received in time

///////////////////////////////////////////////////////////////////////////////
// OUTPUTS
///////////////////////////////////////////////////////////////////////////////
assign rx_st_do  = rx_st[4:0] ;
assign rx_req_o  = rx_ok;
assign rx_cmd_o  = rx_hd_sr[7:4];
assign rx_data_o = rx_dt_sr;
   
endmodule
