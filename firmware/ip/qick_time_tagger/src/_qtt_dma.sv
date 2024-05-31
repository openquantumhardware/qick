///////////////////////////////////////////////////////////////////////////////
//  FERMI RESEARCH LAB
///////////////////////////////////////////////////////////////////////////////
//  Author         : Martin Di Federico
//  Date           : 2024_5_31
///////////////////////////////////////////////////////////////////////////////

module dma_fifo_rd # (
   parameter   MEM_AW      = 16  ,  // Memory Address Width
   parameter   MEM_DW      = 8   ,  // Memory Data Width
   parameter   DMA_DW      = 8      // DMA   Data Width
) (
   input    wire                 clk_i             ,
   input    wire                 rst_ni            ,
   input    wire                 dma_req_i         ,
   output   wire                 dma_ack_o         ,
   input    wire  [MEM_AW-1:0]   dma_len_i         ,
   output   wire                 pop_req_o , //fifo_pop_o        ,
   input    wire                 pop_ack_i , //fifo_pop_i        ,
   input    wire  [MEM_DW-1:0]   fifo_dt_i         ,
   input    wire                 m_axis_tready_i   ,
   output   wire  [DMA_DW-1:0]   m_axis_tdata_o    ,
   output   wire                 m_axis_tvalid_o   ,
   output   wire                 m_axis_tlast_o    ,
   output   wire  [15:0]         dma_do            ,
   output   wire  [25:0]         dma_reg_do            
   );

///// Signals
///////////////////////////////////////////////////////////////////////////////
reg  [MEM_AW-1:0] len_cnt        ;
wire [MEM_AW-1:0] len_cnt_p1     ;
reg               len_cnt_rst, dma_rd_ack     ;
reg fifo_rd ; // Reading FIFO for streaming
reg dt_bf   ; // Data received when not Ready. Should Buffer
reg dt_vld  ; // Data Valid on input.
reg dt_last ; // Last Data of Stream
reg dt_tx   ; // Transmitting Data
reg dt_w    ; // Data Buffered is is waiting for rdy

reg  [3:0] lp_cnt    ; // Last FIFO REQ Pulse 
wire [3:0] lp_cnt_p1 ; // Last FIFO REQ Pulse
reg lp_cnt_en        ; // Last FIFO REQ Pulse


assign len_cnt_last  = (len_cnt_p1 == dma_len_i)  ;
assign last_rd_addr  =  len_cnt_last & m_axis_tvalid_o ;

///// DMA STATE
///////////////////////////////////////////////////////////////////////////////
typedef enum { ST_IDLE, ST_TXING, ST_LAST, ST_END } TYPE_DMA_RD_ST;
(* fsm_encoding = "sequential" *) TYPE_DMA_RD_ST dma_rd_st;
TYPE_DMA_RD_ST dma_rd_st_nxt;

always_ff @ (posedge clk_i, negedge rst_ni) begin
   if    ( !rst_ni   )  dma_rd_st  <= ST_IDLE;
   else                 dma_rd_st  <= dma_rd_st_nxt;
end

always_comb begin
   dma_rd_st_nxt     = dma_rd_st;
   dma_rd_ack        = 1'b1;
   len_cnt_rst       = 1'b0; 
   fifo_rd           = 1'b0;
   dt_bf             = 1'b0;
   dt_vld            = 1'b0;
   dt_last           = 1'b0;
   dt_tx             = 1'b0;
   lp_cnt_en         = 1'b0;
   case (dma_rd_st)
      ST_IDLE: begin
         dma_rd_ack     = 1'b0;
         len_cnt_rst   = 1'b1; 
         if (dma_req_i) dma_rd_st_nxt = ST_TXING;
      end
      ST_TXING : begin
         dt_bf    = pop_ack_i & !m_axis_tready_i ;
         fifo_rd  = ~dt_bf; // Read From FIFO if no data is waiting for READY
         dt_tx    = 1'b1;
         dt_vld   = pop_ack_i ;
         //if (len_cnt_last & len_cnt_en)
         if (len_cnt_last & m_axis_tvalid_o) 
            dma_rd_st_nxt = ST_LAST;
      end
      ST_LAST : begin
         lp_cnt_en     = m_axis_tready_i;
         fifo_rd  = &lp_cnt; //Read from FIFO, every 8 READY (IN CASE TPROC has read )
         dt_bf    = pop_ack_i & !m_axis_tready_i ;
         dt_vld   = pop_ack_i ;
         dt_last  = 1'b1;
         dt_tx    = 1'b1;
         if ( m_axis_tvalid_o & m_axis_tready_i) dma_rd_st_nxt = ST_END;
      end
      ST_END : begin
         if (!dma_req_i & m_axis_tready_i)   dma_rd_st_nxt = ST_IDLE;
      end
   endcase
end

// Len Count
assign len_cnt_p1 = len_cnt + 1'b1;

always_ff @ (posedge clk_i, negedge rst_ni) begin
   if      ( !rst_ni     ) 
      len_cnt  <= 0;
   else begin 
      if ( len_cnt_rst ) 
         len_cnt  <= 1;
      //else if ( len_cnt_en  ) 
      else if ( m_axis_tvalid_o  )
         len_cnt  <= len_cnt_p1;
   end
end

// Last Pulse Count
assign lp_cnt_p1 = lp_cnt + 1'b1;
always_ff @ (posedge clk_i, negedge rst_ni) begin
   if      ( !rst_ni    ) lp_cnt  <= 0;
   else if ( lp_cnt_en  ) lp_cnt  <= lp_cnt_p1;
   else  lp_cnt  <= 0;
end


// OUT Buffer
reg  [MEM_DW-1:0] dt_r ;
always_ff @ (posedge clk_i, negedge rst_ni) begin
   if ( !rst_ni ) begin
      dt_r   <= 0;
      dt_w   <= 0;
   end else if ( dt_bf ) begin
         dt_w  <= 1'b1;
         dt_r  <= fifo_dt_i;
   end else if ( dt_w & m_axis_tready_i) begin
         dt_w  <= 1'b0;
   end
end


// Assign outputs.
reg [3:0] cnt_fifo_rd, cnt_vld;

always_ff @ (posedge clk_i, negedge rst_ni) begin
   if ( !rst_ni ) begin
      cnt_fifo_rd   <= 0;
      cnt_vld       <= 0;
   end else begin
      if      ( dt_vld  )           cnt_fifo_rd <= cnt_fifo_rd + 1'b1; 
      else if ( m_axis_tvalid_o )   cnt_vld     <= cnt_vld + 1'b1; 
   end
end

// ILA Debug 16 Bits  
assign  dma_do[0]  = dma_req_i  ;
assign  dma_do[1]  = dma_rd_ack ;
assign  dma_do[2]  = pop_req_o  ;
assign  dma_do[3]  = pop_ack_i  ;
assign  dma_do[4]  = fifo_rd    ;
assign  dma_do[5]  = dt_tx      ;
assign  dma_do[6]  = dt_w       ;
assign  dma_do[7]  = dt_vld     ;
assign  dma_do[8]  = dt_bf      ;
assign  dma_do[9]  = lp_cnt_en  ;
assign  dma_do[11:10]  = len_cnt[1:0];
assign  dma_do[13:12]  = cnt_fifo_rd[1:0];
assign  dma_do[15:14]  = cnt_vld[1:0];

// Register Debug 24 Bits
assign  dma_reg_do[9:0]    = dma_do[9:0];
assign  dma_reg_do[15:10]  = len_cnt[5:0];
assign  dma_reg_do[19:16]  = cnt_fifo_rd;
assign  dma_reg_do[23:20]  = cnt_vld ;
assign  dma_reg_do[25:24]  = dma_rd_st[1:0] ;

assign pop_req_o       = fifo_rd & m_axis_tready_i ;
assign m_axis_tvalid_o  = dt_tx & (dt_w | dt_vld) & m_axis_tready_i ;
assign m_axis_tdata_o   = dt_w ? dt_r : fifo_dt_i    ;
assign m_axis_tlast_o   = dt_last & m_axis_tvalid_o;;
assign dma_ack_o        = dma_rd_ack   ;

endmodule


