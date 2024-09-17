///////////////////////////////////////////////////////////////////////////////
//  FERMI RESEARCH LAB
///////////////////////////////////////////////////////////////////////////////
//  Author         : Martin Di Federico
//  Date           : 2024_5
//  Version        : 1
///////////////////////////////////////////////////////////////////////////////

module qcom_link (
// Core and AXI CLK & RST
   input  wire          c_clk_i        ,
   input  wire          c_rst_ni       ,
// Config 
   input  wire [ 3:0]   tick_cfg       , // Pulse Duration of PMOD measured in c_clk
// Transmittion 
   input  wire          tx_vld_i       ,
   output reg           tx_ready_o     ,
   input  wire [ 3:0]   tx_header_i    ,
   input  wire [31:0]   tx_data_i      ,
// Command Processing  
   output reg           rx_vld_o       ,
   output reg  [ 2:0]   rx_header_o    ,
   output reg  [32:0]   rx_data_o      ,
// PMOD COM
   input  wire [ 3:0]   pmod_i         ,
   output reg  [ 3:0]   pmod_o         ,
///// DEBUG   
   output wire [31:0]   qcom_link_do        
   );

///////////////////////////////////////////////////////////////////////////////
// ######   #     # 
// #     #   #   #  
// #     #    # #   
// ######      #    
// #   #      # #   
// #    #    #   #  
// #     #  #     # 
///////////////////////////////////////////////////////////////////////////////
reg rx_idle_s, rx_header_s, rx_end_s, rx_fault_s ;


///////////////////////////////////////////////////////////////////////////////
// Sync Input and PMOD[3] edge detection
reg [3:0] pmod_r, pmod_r2;
(* ASYNC_REG = "TRUE" *) reg [3:0] pmod_cdc ;
always_ff @ (posedge c_clk_i, negedge c_rst_ni) begin
   if (!c_rst_ni) begin
      pmod_cdc    <= 4'd0;
      pmod_r      <= 4'd0;
      pmod_r2     <= 4'd0;
   end else begin 
      pmod_cdc    <= pmod_i;
      pmod_r      <= pmod_cdc;
      pmod_r2     <= pmod_r;
   end
end
assign rx_new_dt   = pmod_r2[3] ^ pmod_r[3];

///////////////////////////////////////////////////////////////////////////////
// RX Store Data
reg [32:0] rx_dt;
reg [2:0] rx_header_r ;
always_ff @ (posedge c_clk_i, negedge c_rst_ni) begin
   if (!c_rst_ni) begin
      rx_dt        <= '{default:'0} ; 
      rx_header_r  <= '{default:'0} ; 
   end else begin 
      if (rx_new_dt) begin
         if ( rx_idle_s ) rx_header_r <= { pmod_r[2], pmod_r[1], pmod_r[0] } ;
         else             rx_dt       <= { rx_dt[29:0], pmod_r[2], pmod_r[1], pmod_r[0] } ;
      end else if (rx_end_s | rx_fault_s) begin
         rx_dt <= '{default:'0} ; 
      end
   end
end

///////////////////////////////////////////////////////////////////////////////
// RX Decoding
reg [3:0] rx_pack_size;
always_comb begin
   case ( rx_header_r )
      3'b000  : rx_pack_size = 4'd1 ; // CLEAR FLAG (1)
      3'b001  : rx_pack_size = 4'd1 ; // SET FLAG (1)
      3'b010  : rx_pack_size = 4'd4 ; // Receive 8 Bits (4)
      3'b011  : rx_pack_size = 4'd4 ; // Receive SYNC Command
      3'b100  : rx_pack_size = 4'd7 ; // Receive 16 Bits (7)
      3'b110  : rx_pack_size = 4'd12; // Receive 32 Bits (12)
      default : rx_pack_size = 4'd0;
   endcase
end

///////////////////////////////////////////////////////////////////////////////
// RX Measurment
reg [4:0] rx_time_out_cnt, rx_tick_cnt ;
reg [3:0] rx_pack_cnt ; 

always_ff @ (posedge c_clk_i, negedge c_rst_ni) begin
   if (!c_rst_ni) begin
      rx_tick_cnt     <= 5'd1;
      rx_time_out_cnt <= 5'd0;
      rx_pack_cnt     <= 8'd1;
   end else begin 
      if (rx_new_dt) begin
         rx_pack_cnt      <= rx_pack_cnt + 1'b1 ;
         rx_time_out_cnt  <= 4'd0;
      end else begin
      if      (rx_header_s) rx_tick_cnt <= rx_tick_cnt + 1'b1;
      else if ( rx_idle_s ) rx_tick_cnt <= 5'd1;
      if (rx_idle_s) begin
         rx_pack_cnt      <= 8'd1;
         rx_time_out_cnt  <= 4'd0;
      end else
         rx_time_out_cnt <= rx_time_out_cnt + 1'b1 ;
      end
   end
end

wire rx_time_out, rx_last_dt, rx_single_dt;
assign rx_last_dt    = rx_new_dt & (rx_pack_size == rx_pack_cnt) ; // Last Data Received
assign rx_single_dt  = rx_new_dt & (rx_pack_size == 4'd1) ; // Package has only Header
assign rx_time_out   = rx_time_out_cnt > rx_tick_cnt ; // New Data was not received in time

///////////////////////////////////////////////////////////////////////////////
///// RX STATE
typedef enum { RX_IDLE, RX_HEADER, RX_DATA, RX_END, RX_FAULT, RX_CHECK, RX_RTZ } TYPE_RX_ST ;
(* fsm_encoding = "one_hot" *) TYPE_RX_ST rx_st;
TYPE_RX_ST rx_st_nxt;


always_ff @ (posedge c_clk_i) begin
   if      ( !c_rst_ni   )  rx_st  <= RX_IDLE;
   else                     rx_st  <= rx_st_nxt;
end
always_comb begin
   rx_st_nxt   = rx_st; // Default Current
   rx_idle_s   = 1'b0;
   rx_header_s = 1'b0;
   rx_end_s    = 1'b0;
   rx_fault_s  = 1'b0;
   case (rx_st)
      RX_IDLE   :  begin
         rx_idle_s = 1'b1;
         if ( rx_new_dt ) begin
            if (pmod_r[3])     rx_st_nxt = RX_HEADER; // First Transition 0 to 1
            else               rx_st_nxt = RX_RTZ;    // Tx is returning to Zero
         end
      end
      RX_HEADER :  begin
         rx_header_s = 1'b1;
         if      ( rx_single_dt ) rx_st_nxt = RX_END;    // Package has only Header     
         else if ( rx_new_dt    ) rx_st_nxt = RX_DATA;   // New Data Received  
         else if ( rx_time_out  ) rx_st_nxt = RX_FAULT;     
      end
      RX_DATA :  begin
         if      ( rx_last_dt  ) rx_st_nxt = RX_END;     // Last Data Received  
         else if ( rx_time_out ) rx_st_nxt = RX_FAULT;   // No Data Received  
      end
      RX_END    :  begin
         rx_end_s  = 1'b1;
         rx_st_nxt = RX_CHECK;     
      end
      RX_CHECK    :  begin
         if ( rx_new_dt ) begin
            if   ( pmod_r[3] )      rx_st_nxt = RX_FAULT;  // Extra Data Received   
            else                    rx_st_nxt = RX_RTZ;    // Tx is returning to Zero
         end else if (rx_time_out)  rx_st_nxt = RX_IDLE;   // No more Data is received
      end
      RX_FAULT  :  begin
         rx_fault_s  = 1'b1;
         rx_st_nxt = RX_IDLE;     
      end
      RX_RTZ  :  begin
         rx_st_nxt = RX_IDLE;     
      end
   endcase
end



///////////////////////////////////////////////////////////////////////////////
// #######  #     # 
//    #      #   #  
//    #       # #   
//    #        #    
//    #       # #   
//    #      #   #  
//    #     #     # 
///////////////////////////////////////////////////////////////////////////////
reg   tx_idle_s, tx_header_s, tx_data_s, tx_end_s;
reg   tick_clk ; //Clock (PMOD[3})should be updated
reg   tick_dt ; //Data  (PMOD[2:0})should be updated
reg   tick_en ; // Enable tick Generation

 
///////////////////////////////////////////////////////////////////////////////
// TX Encode Header and Check Command 
reg [ 3:0] tx_pack_size, tx_pack_size_r;
reg [35:0] tx_dt ;
reg tx_ok;

always_comb begin
   tx_pack_size = 4'd0;
   tx_dt        = 33'd0 ;
   tx_ok        = 1'b0;
   case ( tx_header_i[3:1] )
      3'b000 : begin // CLEAR FLAG (1)
         tx_pack_size = 4'd1;
         tx_dt        = {tx_header_i, 32'd0}; 
         tx_ok        = 1'b1;
      end
      3'b001 : begin // SET FLAG (1)
         tx_pack_size = 4'd1;
         tx_dt        = {tx_header_i, 32'd0}; 
         tx_ok        = 1'b1;
      end
      3'b010 : begin // Send 8 Bits (4)
         tx_pack_size = 4'd4;
         tx_dt        = {tx_header_i, tx_data_i[7:0], 24'd0}; 
         tx_ok        = 1'b1;
      end
      3'b011 : begin // Send SYNC COMMAND
         tx_pack_size = 4'd4;
         tx_dt        = {tx_header_i, 32'd0}; 
         tx_ok        = 1'b1;
      end
      3'b100 : begin // Send 16 Bits (7)
         tx_pack_size = 4'd7;
         tx_dt        = {tx_header_i, 1'b0, tx_data_i[15:0], 15'd0}; 
         tx_ok        = 1'b1;
      end
      3'b110 : begin // Send 32 Bits (12)
         tx_pack_size = 4'd12;
         tx_dt        = {tx_header_i, tx_data_i[31:0]}; 
         tx_ok        = 1'b1;
      end
      default : begin
         tx_pack_size = 4'd0;
         tx_dt        = 33'd0 ;
         tx_ok        = 1'b0;
      end
   endcase
end

///////////////////////////////////////////////////////////////////////////////
// TX Registers

reg [ 3:0] tx_pmod ; // PMOD values for OUTPUT [3]Clk [2:0]Data
reg [35:0] tx_buff ; //Shift Register For Par 2 Ser. (Data encoded on tx_dt)
reg [ 3:0] tx_pack_cnt; //Number of Packages transmited  (Total Defined in tx_pack_size)

always_ff @ (posedge c_clk_i, negedge c_rst_ni) begin
   if (!c_rst_ni) begin
      tx_pmod        <= '{default:'0} ; 
      tx_buff        <= '{default:'0} ; 
      tx_pack_cnt    <= 4'd0;
      tx_pack_size_r <= 4'd0;
   end else begin 
      if (tx_vld_i) begin
         tx_buff           <= tx_dt;
         tx_pack_cnt       <= 8'd0;
         tx_pack_size_r    <= tx_pack_size;
      end else if ( tx_idle_s ) begin
         tx_pmod[3] <= 1'b0;
      end else if ( tick_clk )
         tx_pmod[3] <= ~tx_pmod[3];
      if (tick_dt) begin 
         tx_pack_cnt <= tx_pack_cnt + 1'b1 ;
         tx_buff     <= tx_buff << 3;
         tx_pmod[2]  <= tx_buff[35] ;
         tx_pmod[1]  <= tx_buff[34] ;
         tx_pmod[0]  <= tx_buff[33] ;
      end
   end
end

assign tx_last_dt  = (tx_pack_cnt == tx_pack_size_r) ;


///////////////////////////////////////////////////////////////////////////////
// TICK GENERATOR

reg  [ 3:0] tx_tick_cnt ; // NUmber of c_clk in current PMOD Pulse

always_ff @ (posedge c_clk_i, negedge c_rst_ni) begin
   if (!c_rst_ni) begin
      tx_tick_cnt <= 1'b0;
      tick_clk    <= 1'b0;
      tick_dt     <= 1'b0;
   end else begin 
      if (tick_en) begin
         if (tx_tick_cnt == tick_cfg) begin
            tick_clk    <= 1'b1;
            tx_tick_cnt <= 4'd1;
         end else begin 
            tick_clk    <= 1'b0;
            tx_tick_cnt <= tx_tick_cnt + 1'b1 ;
         end
         if (tx_tick_cnt == tick_cfg>>1) tick_dt <= 1'b1;
         else                            tick_dt <= 1'b0;
      end else begin 
         tx_tick_cnt <= tick_cfg>>1 ;
         tick_dt     <= 1'b0;
         tick_clk    <= 1'b0;
      end
   end
end

///////////////////////////////////////////////////////////////////////////////
///// TX STATE
typedef enum { TX_IDLE, TX_DT, TX_CLK, TX_END, TX_RTZ, TX_WAIT } TYPE_TX_ST ;
(* fsm_encoding = "one_hot" *) TYPE_TX_ST tx_st;
TYPE_TX_ST tx_st_nxt;


always_ff @ (posedge c_clk_i) begin
   if      ( !c_rst_ni   )  tx_st  <= TX_IDLE;
   else                     tx_st  <= tx_st_nxt;
end
always_comb begin
   tx_st_nxt   = tx_st; // Default Current
   tick_en     = 1'b0;
   tx_idle_s   = 1'b0;
   case (tx_st)
      TX_IDLE   :  begin
         tx_idle_s = 1'b1;
         if      ( tx_vld_i & tx_ok ) tx_st_nxt = TX_DT;     
      end
      TX_DT :  begin
         tick_en     = 1'b1;
         tx_data_s   = 1'b1;
         if ( tick_clk   ) tx_st_nxt = TX_CLK;
      end
      TX_CLK :  begin
         tick_en     = 1'b1;
         tx_header_s = 1'b1;
         if ( tick_dt ) begin
            if ( tx_last_dt ) tx_st_nxt = TX_END;
            else              tx_st_nxt = TX_DT;
         end
      end
      TX_END    :  begin
         tick_en   = 1'b1;
         tx_end_s  = 1'b1;
         if  (tx_pmod[3])  tx_st_nxt = TX_RTZ;     
         else              tx_st_nxt = TX_WAIT;     
      end
      TX_RTZ    :  begin
         tick_en   = 1'b1;
         if ( tick_clk   ) tx_st_nxt = TX_WAIT;
      end
      TX_WAIT    :  begin
         tick_en   = 1'b1;
         if ( tick_dt   ) tx_st_nxt = TX_IDLE;
      end
      
   endcase
end

///////////////////////////////////////////////////////////////////////////////
// OUTPUTS
///////////////////////////////////////////////////////////////////////////////

assign tx_ready_o   = tx_idle_s;
assign rx_vld_o     = rx_end_s;
assign rx_header_o  = rx_header_r;
assign rx_data_o    = rx_dt;
assign pmod_o       = tx_pmod;
assign qcom_link_do = 0;
   
endmodule

