///////////////////////////////////////////////////////////////////////////////
//  FERMI RESEARCH LAB
///////////////////////////////////////////////////////////////////////////////
//  Author         : Martin Di Federico
//  Date           : 2024_5
//  Version        : 1
///////////////////////////////////////////////////////////////////////////////

module qick_com (
// Core and AXI CLK & RST
   input  wire             c_clk_i        ,
   input  wire             c_rst_ni       ,
   input  wire             t_clk_i        ,
   input  wire             t_rst_ni       ,
// QCOM INTERFACE
   input  wire             pulse_i        ,
   input  wire  [3:0]      qcom_cfg_i     ,
// QCOM INTERFACE
   input  wire             cmd_req_i      ,
   output wire             cmd_ack_o      ,
   input  wire  [3:0]      cmd_op_i       ,
   input  wire  [31:0]     cmd_dt_i       ,
   output reg              qcom_rdy_o     ,
   output reg   [31:0]     qcom_dt1_o     ,
   output reg   [31:0]     qcom_dt2_o     ,
   output reg              qcom_vld_o     ,
   output reg              qcom_flag_o    ,
// TPROC CONTROL
   output reg              qproc_start_o  ,
// PMOD COM
   input  wire [ 3:0]      pmod_i         ,
   output wire [ 3:0]      pmod_o         ,
// DEBUG
   output wire [31:0]      qcom_tx_dt_do  ,
   output wire [31:0]      qcom_rx_dt_do  ,
   output wire [31:0]      qcom_status_do ,
   output wire [15:0]      qcom_debug_do  ,
   output wire [31:0]      qcom_do        );

// Signal Declaration 
///////////////////////////////////////////////////////////////////////////////
reg t_start_ack;
reg cmd_end, start_req;

// Register Inputs
///////////////////////////////////////////////////////////////////////////////
wire [31:0] qcom_dt ;
wire [ 3:0] qcom_header ;
wire [ 1:0] qcom_dt_size ;

assign qcom_type     = cmd_op_i[3];
assign qcom_dt_size  = cmd_op_i[2:1] ;
assign qcom_dt_dst   = cmd_op_i[0];

assign qcom_header   = { qcom_dt_size, qcom_type, qcom_dt_dst};
assign qcom_dt       = cmd_dt_i;
assign qcom_sync     = ( cmd_op_i[3:0] == 4'b1010 );



///////////////////////////////////////////////////////////////////////////////
// C CLOCK SYNC 
reg c_sync_r2 ;
sync_reg # (
   .DW ( 1 )
) c_sync_pulse (
   .dt_i      ( pulse_i     ) ,
   .clk_i     ( c_clk_i     ) ,
   .rst_ni    ( c_rst_ni    ) ,
   .dt_o      ( c_sync_r    ) );
always_ff @ (posedge c_clk_i, negedge c_rst_ni) begin
   if (!c_rst_ni)   c_sync_r2   <= 1'b0; 
   else              c_sync_r2   <= c_sync_r;
end
assign c_sync_t01 = !c_sync_r2 & c_sync_r ;


///////////////////////////////////////////////////////////////////////////////
// #######  #     # 
//    #      #   #  
//    #       # #   
//    #        #    
//    #       # #   
//    #      #   #  
//    #     #     # 
///////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////
// TX Control state
typedef enum { TX_IDLE, TX_SEND, TX_WSYNC, TX_WRDY, TX_WCMD } TYPE_TX_ST ;
(* fsm_encoding = "sequential" *) TYPE_TX_ST qcom_tx_st;
TYPE_TX_ST qcom_tx_st_nxt;

reg         tx_sync ;

always_ff @ (posedge c_clk_i) begin
   if      ( !c_rst_ni   )  qcom_tx_st  <= TX_IDLE;
   else                     qcom_tx_st  <= qcom_tx_st_nxt;
end
reg        tx_vld, qready;

always_comb begin
   qcom_tx_st_nxt = qcom_tx_st; // Default Current
   tx_vld         = 1'b0;
   qready         = 1'b0;
   tx_sync        = 1'b0;
   case (qcom_tx_st)
      TX_IDLE   :  begin
         qready   = 1'b1;
         if ( cmd_req_i )
            if ( qcom_sync )
               qcom_tx_st_nxt = TX_WSYNC;     
            else begin
               qcom_tx_st_nxt = TX_SEND;     
               tx_vld         = 1'b1;
            end
      end
      TX_WSYNC   :  begin
         if ( c_sync_t01 ) begin 
            tx_vld         = 1'b1;
            qcom_tx_st_nxt = TX_SEND;     
         end
      end
      TX_SEND :  begin
         if   ( qcom_sync ) qcom_tx_st_nxt = TX_WCMD;     
         else               qcom_tx_st_nxt = TX_WRDY;     
      end
      TX_WRDY   :  begin
         if ( tx_ready ) qcom_tx_st_nxt = TX_IDLE;     
      end
      TX_WCMD   :  begin
      tx_sync  = 1'b1;
         if ( cmd_end ) qcom_tx_st_nxt = TX_IDLE;     
      end
   endcase
end


///////////////////////////////////////////////////////////////////////////////
// ######   #     # 
// #     #   #   #  
// #     #    # #   
// ######      #    
// #   #      # #   
// #    #    #   #  
// #     #  #     # 
///////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////
// RX Decoding
wire [32:0] rx_data;       // Data Received
wire [ 2:0] rx_header;     // Header Received
reg  reg_sel ;      // Write Register Selection
reg  [31:0] new_dt ;       // New Data to Register reg_sel
wire [ 1:0] reg_wr_size;   // Write Size 1, 8, 16, or 32 Bits
reg rx_wreg, rx_wflg, rx_sync;

assign reg_wr_size = rx_header[2:1];

always_comb begin
   reg_sel  = rx_data[32];
   new_dt   = rx_data[31:0];
   rx_sync  = 1'b0;
   rx_wreg  = 1'b0;
   rx_wflg  = 1'b0;
   case ( reg_wr_size )
      2'b00 : begin // 1 BIT 
            rx_wflg   = 1'b1;
      end
      2'b01 : begin // 8 BITS | SYNC
         if ( rx_header[0] ) 
            rx_sync = 1'b1 ;
         else begin
            rx_wreg     = 1'b1;
            reg_sel     = rx_data[8];
            new_dt      = {24'd0, rx_data[7:0]};           
         end
      end
      2'b10 : begin // 16 BITS
         rx_wreg     = 1'b1;
         reg_sel     = rx_data[17];
         new_dt      = {16'd0, rx_data[15:0]};
      end
      2'b11 : begin // 32 BIT
         rx_wreg     = 1'b1;
         reg_sel     = rx_data[32];
         new_dt      = rx_data[31:0];
      end
      default : begin // :P
         rx_wreg     = 1'b1;
         reg_sel     = rx_data[32];
         new_dt      = rx_data[31:0];
      end
   endcase
end

assign rx_wreg_en = rx_vld & rx_wreg;
assign rx_wflg_en = rx_vld & rx_wflg;

///////////////////////////////////////////////////////////////////////////////
// Register Update
reg        qflag_dt, rx_wreg_r ;
reg [31:0] qreg1_dt, qreg2_dt;
always_ff @ (posedge c_clk_i, negedge c_rst_ni) begin
   if (!c_rst_ni) begin
      qflag_dt    <= 1'b0; 
      qreg1_dt    <= '{default:'0} ; 
      qreg2_dt    <= '{default:'0} ; 
      rx_wreg_r   <= 1'b0; 
   end else begin 
      rx_wreg_r <= rx_wreg_en ;
      if ( rx_wreg_en )
         case ( reg_sel )
            1'b0 : qreg1_dt <= new_dt;      // Reg_dt1
            1'b1 : qreg2_dt <= new_dt;      // Reg_dt2
         endcase
      else if ( rx_wflg_en )
         qflag_dt <= rx_header[0]; // FLAG


   end

end


///////////////////////////////////////////////////////////////////////////////
// RX
typedef enum { RX_IDLE, RX_CMD } TYPE_RX_ST ;
   (* fsm_encoding = "sequential" *) TYPE_RX_ST qcom_rx_st;
   TYPE_RX_ST qcom_rx_st_nxt;

always_ff @ (posedge c_clk_i) begin
   if      ( !c_rst_ni   )  qcom_rx_st  <= RX_IDLE;
   else                     qcom_rx_st  <= qcom_rx_st_nxt;
end

always_comb begin
   qcom_rx_st_nxt   = qcom_rx_st; // Default Current
   case (qcom_rx_st)
      RX_IDLE  : 
         if ( rx_vld ) qcom_rx_st_nxt = RX_CMD;     
      RX_CMD   : begin
         qcom_rx_st_nxt = RX_IDLE;     
      end
   endcase
end





///////////////////////////////////////////////////////////////////////////////
// QICK PROCESSOR RESTART
assign qctrl_sync = tx_sync | rx_sync;

// PULSE SYNC 
///////////////////////////////////////////////////////////////////////////////
// T CLOCK SYNC 
reg t_sync_r2 ;
sync_reg # (
   .DW ( 1 )
) t_sync_pulse (
   .dt_i      ( pulse_i     ) ,
   .clk_i     ( t_clk_i     ) ,
   .rst_ni    ( t_rst_ni    ) ,
   .dt_o      ( t_sync_r    ) );

always_ff @ (posedge t_clk_i, negedge t_rst_ni) begin
   if (!t_rst_ni)   t_sync_r2   <= 1'b0; 
   else             t_sync_r2   <= t_sync_r;
end
assign t_sync_t01 = !t_sync_r2 & t_sync_r ;




///////////////////////////////////////////////////////////////////////////////
typedef enum { QRST_IDLE, QRST_REQ, QRST_WSYNC, QRST_CMD } TYPE_QCTRL_ST ;
   (* fsm_encoding = "sequential" *) TYPE_QCTRL_ST qctrl_st;
   TYPE_QCTRL_ST qctrl_st_nxt;

always_ff @ (posedge c_clk_i) begin
   if      ( !c_rst_ni   )  qctrl_st  <= QRST_IDLE;
   else                     qctrl_st  <= qctrl_st_nxt;
end

always_comb begin
   qctrl_st_nxt   = qctrl_st; // Default Current
   cmd_end        = 1'b0;
   start_req      = 1'b0;
   case (qctrl_st)
      QRST_IDLE  : 
         if ( qctrl_sync ) qctrl_st_nxt = QRST_REQ;     
      QRST_REQ : begin
         start_req   = 1'b1;
         if ( start_ack  ) qctrl_st_nxt = QRST_WSYNC;     
      end
      QRST_WSYNC : begin
         if ( c_sync_t01  ) qctrl_st_nxt = QRST_CMD;     
      end
      QRST_CMD   : begin
         cmd_end     = 1'b1;
         if ( !start_ack  )  qctrl_st_nxt = QRST_IDLE;     
      end
   endcase
end

///////////////////////////////////////////////////////////////////////////////
// REQ - ACK SYNC 
sync_reg # (.DW(1)) t_sync_start_req (
   .dt_i      ( start_req   ) ,
   .clk_i     ( t_clk_i     ) ,
   .rst_ni    ( t_rst_ni    ) ,
   .dt_o      ( t_start_req ) );
 
sync_reg # (.DW(1)) c_sync_start_ack (
   .dt_i      ( t_start_ack ) ,
   .clk_i     ( c_clk_i     ) ,
   .rst_ni    ( c_rst_ni    ) ,
   .dt_o      ( start_ack   ) );

reg [2:0] t_start_cnt;
reg t_start_r;

always_ff @ (posedge t_clk_i, negedge t_rst_ni) begin
   if (!t_rst_ni)   begin
      t_start_cnt   <= 0; 
      t_start_ack   <= 1'b0; 
      t_start_r     <= 1'b0; 
   end else begin
      if      ( t_start_req ) t_start_ack  <= 1'b1;
      else if ( qproc_hit   ) t_start_ack  <= 1'b0; 

      if      ( qproc_hit        )  t_start_r   <= 1'b1;
      else if ( t_start_cnt==3'd7 )  t_start_r   <= 1'b0;

      if ( t_start_r ) t_start_cnt <= t_start_cnt+1'b1;
      else             t_start_cnt <= 0;
   end
end

assign qproc_hit = t_start_ack & t_sync_t01;


///////////////////////////////////////////////////////////////////////////////
// INSTANCES 
///////////////////////////////////////////////////////////////////////////////

   
///////////////////////////////////////////////////////////////////////////////
wire [3:0] tick_cfg ;
assign tick_cfg = qcom_cfg_i[3:0];

qcom_link QCOM_LINK (
   .c_clk_i      ( c_clk_i       ) ,
   .c_rst_ni     ( c_rst_ni      ) ,
   .tick_cfg     ( tick_cfg      ) ,
   .tx_vld_i     ( tx_vld        ) ,
   .tx_ready_o   ( tx_ready      ) ,
   .tx_header_i  ( qcom_header   ) ,
   .tx_data_i    ( qcom_dt       ) ,
   .rx_vld_o     ( rx_vld        ) ,
   .rx_header_o  ( rx_header     ) ,
   .rx_data_o    ( rx_data       ) ,
   .pmod_i       ( pmod_i        ) ,
   .pmod_o       ( pmod_o        ) ,
   .qcom_link_do (   ) 
);

///////////////////////////////////////////////////////////////////////////////
// DEBUG
reg [3:0] sync_cnt;
always_ff @ (posedge c_clk_i, negedge c_rst_ni) begin
   if (!c_rst_ni)   begin
      sync_cnt   <= 0; 
   end else begin
      if ( c_sync_t01 ) sync_cnt <= sync_cnt + 1'b1;
   end
end

assign qcom_tx_dt_do   = qcom_dt;
assign qcom_rx_dt_do   = rx_data;
assign qcom_status_do  = {tx_ready, qctrl_st[1:0],  qcom_tx_st[2:0], qcom_rx_st[1:0] };
assign qcom_debug_do   = {pulse_i, tx_ready, reg_wr_size[1:0], reg_sel, qcom_header[2:0], rx_header[2:0], sync_cnt[3:0] };
assign qcom_do         = 0;

///////////////////////////////////////////////////////////////////////////////
// OUTPUTS
///////////////////////////////////////////////////////////////////////////////

// OUT SIGNALS
assign qcom_rdy_o    = qready;
assign qcom_dt1_o    = qreg1_dt;
assign qcom_dt2_o    = qreg2_dt;
assign qcom_vld_o    = rx_wreg_r;
assign qcom_flag_o   = qflag_dt;
assign qcom_do       = 0;
assign qproc_start_o = t_start_r;
assign cmd_ack_o     = ~qready;





endmodule


