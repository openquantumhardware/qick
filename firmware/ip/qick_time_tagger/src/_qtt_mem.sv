///////////////////////////////////////////////////////////////////////////////
//  FERMI RESEARCH LAB
///////////////////////////////////////////////////////////////////////////////
//  Author         : mdife
//  Date           : 1-2024
//  Versión        : 2
///////////////////////////////////////////////////////////////////////////////


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
   output   wire                 fifo_pop_o        ,
   input    wire                 fifo_pop_i        ,
   input    wire  [MEM_DW-1:0]   fifo_dt_i         ,
   input    wire                 m_axis_tready_i   ,
   output   wire  [DMA_DW-1:0]   m_axis_tdata_o    ,
   output   wire                 m_axis_tvalid_o   ,
   output   wire                 m_axis_tlast_o    );

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

assign len_cnt_en    = ( dt_vld | dt_w) & m_axis_tready_i ; //fifo_pop_i & !len_cnt_last;
assign len_cnt_last  = (len_cnt_p1 == dma_len_i)  ;
assign last_rd_addr  =  len_cnt_last & m_axis_tvalid_o ;

///// DMA STATE
///////////////////////////////////////////////////////////////////////////////
typedef enum { ST_IDLE, ST_TXING, ST_LAST, ST_END } TYPE_DMA_RD_ST;
(* fsm_encoding = "one_hot" *) TYPE_DMA_RD_ST dma_rd_st;
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
         fifo_rd  = 1'b1;
         dt_tx    = 1'b1;
         dt_bf    = fifo_pop_i & !m_axis_tready_i ;
         dt_vld   = fifo_pop_i ;
         if (len_cnt_last & len_cnt_en) 
            dma_rd_st_nxt = ST_LAST;
      end
      ST_LAST : begin
         lp_cnt_en = 1'b1;
         fifo_rd = &lp_cnt;
         dt_bf    = fifo_pop_i & !m_axis_tready_i ;
         dt_vld   = fifo_pop_i ;
         dt_last  = 1'b1;
         dt_tx    = 1'b1;
         if ( m_axis_tvalid_o ) dma_rd_st_nxt = ST_END;
      end
      ST_END : begin
         if (!dma_req_i)   dma_rd_st_nxt = ST_IDLE;
      end
   endcase
end

// Len Count
assign len_cnt_p1 = len_cnt + 1'b1;

always_ff @ (posedge clk_i, negedge rst_ni) begin
   if      ( !rst_ni     ) len_cnt  <= 1;
   else if ( len_cnt_rst ) len_cnt  <= 1;
   else if ( len_cnt_en  ) len_cnt  <= len_cnt_p1;
end

// Last Pulse Count
reg  [3:0] lp_cnt        ;
wire [3:0] lp_cnt_p1;
reg lp_cnt_en;
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
assign fifo_pop_o       = fifo_rd & m_axis_tready_i ;
assign m_axis_tvalid_o  = dt_tx & (dt_w | dt_vld) & m_axis_tready_i ;
assign m_axis_tdata_o   = dt_w ? dt_r : fifo_dt_i    ;
assign m_axis_tlast_o   = dt_last & m_axis_tvalid_o;
assign dma_ack_o        = dma_rd_ack   ;
endmodule




//////////////////////////////////////////////////////////////////////////////
// BRAM
//////////////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////////////
module BRAM_DP_DC_EN # ( 
   parameter MEM_AW  = 16 , 
   parameter MEM_DW  = 16 ,
   parameter RAM_OUT = "NO_REG" // Select "NO_REG" or "REG" 
) ( 
   input  wire               clk_a_i   ,
   input  wire               en_a_i    ,
   input  wire               we_a_i    ,
   input  wire [MEM_AW-1:0]  addr_a_i  ,
   input  wire [MEM_DW-1:0]  dt_a_i    ,
   output wire [MEM_DW-1:0]  dt_a_o    ,
   input  wire               clk_b_i   ,
   input  wire               en_b_i    ,
   input  wire               we_b_i    ,
   input  wire [MEM_AW-1:0]  addr_b_i  ,
   input  wire [MEM_DW-1:0]  dt_b_i    ,
   output wire [MEM_DW-1:0]  dt_b_o    );

localparam RAM_SIZE = 2**MEM_AW ;
  
reg [MEM_DW-1:0] mem [RAM_SIZE];
reg [MEM_DW-1:0] mem_dt_a = {MEM_DW{1'b0}};
reg [MEM_DW-1:0] mem_dt_b = {MEM_DW{1'b0}};

always @(posedge clk_a_i)
   if (en_a_i) begin
      mem_dt_a <= mem[addr_a_i] ;
      if (we_a_i)
         mem[addr_a_i] <= dt_a_i;
   end
always @(posedge clk_b_i)
   if (en_b_i)
      if (we_b_i)
         mem[addr_b_i] <= dt_b_i;
      else
         mem_dt_b <= mem[addr_b_i] ;

generate
   if (RAM_OUT == "NO_REG") begin: no_output_register // 1 clock cycle read
      assign dt_a_o = mem_dt_a ;
      assign dt_b_o = mem_dt_b ;
   end else begin: output_register // 2 clock cycle read
      reg [MEM_DW-1:0] mem_dt_a_r = {MEM_DW{1'b0}};
      reg [MEM_DW-1:0] mem_dt_b_r = {MEM_DW{1'b0}};
      always @(posedge clk_a_i) if (en_a_i) mem_dt_a_r <= mem_dt_a;
      always @(posedge clk_b_i) if (en_b_i) mem_dt_b_r <= mem_dt_b;
      assign dt_a_o = mem_dt_a_r ;
      assign dt_b_o = mem_dt_b_r ;
   end
endgenerate

endmodule






//GRAY CODE COUNTER
//////////////////////////////////////////////////////////////////////////////
module gcc # (
   parameter DW  = 32
)(
   input  wire          clk_i          ,
   input  wire          rst_ni         ,
   input  wire          async_clear_i  ,
   output wire          clear_o  ,
   input  wire          cnt_en_i       ,
   output wire [DW-1:0] count_bin_o    , 
   output wire [DW-1:0] count_gray_o   ,
   output wire [DW-1:0] count_bin_p1_o , 
   output wire [DW-1:0] count_gray_p1_o);
   
reg [DW-1:0] count_bin  ;    // count turned into binary number
wire [DW-1:0] count_bin_p1; // count_bin+1

reg [DW-1:0] count_bin_r, count_gray_r;

integer ind;
always_comb begin
   count_bin[DW-1] = count_gray_r[DW-1];
   for (ind=DW-2 ; ind>=0; ind=ind-1) begin
      count_bin[ind] = count_bin[ind+1]^count_gray_r[ind];
   end
end

reg clear_rcd, clear_r;
always_ff @(posedge clk_i, negedge rst_ni)
   if(!rst_ni) begin
      clear_rcd       <= 0;
      clear_r         <= 0;
   end else begin
      clear_rcd       <= async_clear_i;
      clear_r         <= clear_rcd;
   end
   
assign count_bin_p1 = count_bin + 1'b1 ; 

reg [DW-1:0] count_bin_2r, count_gray_2r;
always_ff @(posedge clk_i, negedge rst_ni)
   if(!rst_ni) begin
      count_gray_r      <= 1;
      count_bin_r       <= 1;
      count_gray_2r     <= 0;
      count_bin_2r      <= 0;
   end else begin
      if (clear_r) begin
         count_gray_r      <= 1;
         count_bin_r       <= 1;
         count_gray_2r     <= 0;
         count_bin_2r      <= 0;
      end else if (cnt_en_i) begin
         count_gray_r   <= count_bin_p1 ^ {1'b0,count_bin_p1[DW-1:1]};
         count_bin_r    <= count_bin_p1;
         count_gray_2r  <= count_gray_r;
         count_bin_2r   <= count_bin_r;
      
      end
  end

assign clear_o          = clear_r ;
assign count_bin_o      = count_bin_2r ;
assign count_gray_o     = count_gray_2r ;
assign count_bin_p1_o   = count_bin_r ;
assign count_gray_p1_o  = count_gray_r ;

endmodule

//////////////////////////////////////////////////////////////////////////////
module FIFO_DC # (
   parameter FIFO_DW = 16 , 
   parameter FIFO_AW = 8 
) ( 
   input  wire                   wr_clk_i    ,
   input  wire                   wr_rst_ni   ,
   input  wire                   wr_en_i     ,
   input  wire                   push_i      ,
   input  wire [FIFO_DW - 1:0]   data_i      ,
   input  wire                   rd_clk_i    ,
   input  wire                   rd_rst_ni   ,
   input  wire                   rd_en_i     ,
   input  wire                   pop_i       ,
   output wire  [FIFO_DW - 1:0]  data_o      ,
   input  wire                   flush_i     ,
   output wire                   async_empty_o  ,
   output wire                   async_full_o   );

// The WRITE_POINTER is on the Last Empty Value
// The READ_POINTER is on the Last Value
wire [FIFO_AW-1:0] rd_gptr_p1   ;
wire [FIFO_AW-1:0] wr_gptr_p1   ;
wire [FIFO_AW-1:0] rd_ptr, wr_ptr, rd_gptr, wr_gptr  ;
wire clr_wr, clr_rd;

// Sample Pointers
reg [FIFO_AW-1:0] wr_gptr_rcd, wr_gptr_r, wr_gptr_p1_rcd, wr_gptr_p1_r; 
always_ff @(posedge rd_clk_i) begin
   wr_gptr_rcd      <= wr_gptr;
   wr_gptr_r        <= wr_gptr_rcd;
   wr_gptr_p1_rcd   <= wr_gptr_p1;
   wr_gptr_p1_r     <= wr_gptr_p1_rcd;
end

reg [FIFO_AW-1:0] rd_gptr_rcd, rd_gptr_r; 
always_ff @(posedge wr_clk_i) begin
   rd_gptr_rcd      <= rd_gptr;
   rd_gptr_r        <= rd_gptr_rcd;
end


reg clr_fifo_req, clr_fifo_ack;
reg clr_rd_rdc, clr_rd_r;
always_ff @(posedge wr_clk_i, negedge wr_rst_ni) begin
   if (!wr_rst_ni) begin
      clr_fifo_req <= 0 ;
      clr_fifo_ack <= 0 ;
   end else begin
      clr_rd_rdc      <= clr_rd;
      clr_rd_r        <= clr_rd_rdc;
      if      ( flush_i      )      clr_fifo_req <= 1 ;
      else if ( clr_fifo_ack )      clr_fifo_req <= 0 ;
      if      ( clear_all    )      clr_fifo_ack <= 1 ;
      else if ( clr_fifo_ack & clear_none) clr_fifo_ack <= 0 ;
   end
end

assign clear_all  =  clr_rd_r &  clr_wr;
assign clear_none = !clr_rd_r & !clr_wr;

wire busy;
assign busy = clr_fifo_ack | clr_fifo_req ;

wire [FIFO_DW - 1:0] mem_dt;

wire async_empty, async_full;

//SYNC with POP (RD_CLK)
assign async_empty   = (rd_gptr == wr_gptr_r) ;   

//SYNC with PUSH (WR_CLK)
assign async_full    = (rd_gptr_r == wr_gptr_p1) ;

wire do_pop, do_push;
assign do_pop  = pop_i & !async_empty;
assign do_push = push_i & !async_full;

assign async_empty_o = async_empty | busy; // While RESETTING, Shows EMPTY
assign async_full_o  = async_full  | busy;
assign data_o  = mem_dt;

//Gray Code Counters
gcc #(
   .DW	( FIFO_AW )
) gcc_wr_ptr  (
   .clk_i            ( wr_clk_i     ) ,
   .rst_ni           ( wr_rst_ni    ) ,
   .async_clear_i    ( clr_fifo_req ) ,
   .clear_o          ( clr_wr       ) ,
   .cnt_en_i         ( do_push      ) ,
   .count_bin_o      ( wr_ptr       ) ,
   .count_gray_o     ( wr_gptr      ) ,
   .count_bin_p1_o   (     ) ,
   .count_gray_p1_o  ( wr_gptr_p1   ) );

gcc #(
   .DW	( FIFO_AW )
) gcc_rd_ptr (
   .clk_i            ( rd_clk_i     ) ,
   .rst_ni           ( rd_rst_ni    ) ,
   .async_clear_i    ( clr_fifo_req ) ,
   .clear_o          ( clr_rd       ) ,
   .cnt_en_i         ( do_pop       ) ,
   .count_bin_o      ( rd_ptr       ) ,
   .count_gray_o     ( rd_gptr      ) ,
   .count_bin_p1_o   (     ) ,
   .count_gray_p1_o  ( rd_gptr_p1   ) );

// Data
BRAM_DP_DC_EN  # (
   .MEM_AW  ( FIFO_AW     )  , 
   .MEM_DW  ( FIFO_DW     )  ,
   .RAM_OUT ( "NO_REG" ) // Select "NO_REG" or "REG" 
) fifo_mem ( 
   .clk_a_i    ( wr_clk_i  ) ,
   .en_a_i     ( wr_en_i   ) ,
   .we_a_i     ( do_push   ) ,
   .addr_a_i   ( wr_ptr    ) ,
   .dt_a_i     ( data_i    ) ,
   .dt_a_o     ( ) ,
   .clk_b_i    ( rd_clk_i  ) ,
   .en_b_i     ( rd_en_i   ) ,
   .we_b_i     ( 1'b0      ) ,
   .addr_b_i   ( rd_ptr    ) ,
   .dt_b_i     (     ) ,
   .dt_b_o     ( mem_dt    ) );
   
endmodule

//////////////////////////////////////////////////////////////////////////////
module BRAM_SC # ( 
   parameter MEM_AW  = 16 , 
   parameter MEM_DW  = 16 
) ( 
   input  wire               clk_i   ,
   input  wire               we_a_i    ,
   input  wire [MEM_AW-1:0]  addr_a_i  ,
   input  wire [MEM_DW-1:0]  dt_a_i    ,
   input  wire [MEM_AW-1:0]  addr_b_i  ,
   output wire [MEM_DW-1:0]  dt_b_o    );

localparam RAM_SIZE = 2**MEM_AW ;
  
reg [MEM_DW-1:0] mem [RAM_SIZE];
reg [MEM_DW-1:0] mem_dt_b = {MEM_DW{1'b0}};

// Port A WRITE only - Port B READ only
always @(posedge clk_i) begin
   mem_dt_b <= mem[addr_b_i] ;
   if (we_a_i)   mem[addr_a_i] <= dt_a_i;
end

assign dt_b_o = mem_dt_b ;

endmodule

///////////////////////////////////////////////////////////////////////////////
module TAG_FIFO_TC # (
   parameter DMA_BLOCK = 1 , 
   parameter RD_BLOCK  = 0 , 
   parameter FIFO_DW   = 32 , 
   parameter FIFO_AW   = 20 
) ( 
   input  wire                   adc_clk_i   ,
   input  wire                   adc_rst_ni  ,
   input  wire                   c_clk_i     ,
   input  wire                   c_rst_ni    ,
   input  wire                   dma_clk_i   ,
   input  wire                   dma_rst_ni  ,
   input  wire                   flush_i   ,
   output wire                   flush_o   ,
   input  wire                   adc_push_i  ,
   input  wire [FIFO_DW - 1:0]   adc_data_i  ,
   input  wire                   c_pop_i     ,
   output wire                   c_pop_o     ,
   output wire [20:0]            c_qty_o     ,
   output wire                   c_empty_o   ,
   input  wire                   dma_pop_i   ,
   output wire                   dma_pop_o   ,
   output wire [20:0]            dma_qty_o   ,
   output wire                   dma_empty_o ,
   output wire [FIFO_DW - 1:0]   dt_o        ,
   output wire                   full_o      );


// The WRITE_POINTER is on the Last Empty Value
// The READ_POINTER is on the Last Value

reg  [FIFO_AW-1:0] rd_proc_ptr   , rd_dma_ptr   , wr_ptr;
wire [FIFO_AW-1:0] rd_proc_ptr_p1, rd_dma_ptr_p1, wr_ptr_p1 ;

wire dma_full, proc_full;
wire proc_empty, dma_empty ;
wire [FIFO_DW - 1:0] mem_dt;

reg   [FIFO_AW-1:0]  dma_qty, proc_qty;

wire [FIFO_DW - 1:0] data_s;

wire do_dma_pop, do_proc_pop;

wire  [FIFO_AW-1:0] addr_b ;
reg do_proc_pop_r, do_dma_pop_r ;


///////////////////////////////////////////////////////////////////////////////
// WRITE
///////////////////////////////////////////////////////////////////////////////
reg do_push;

FIFO_DC # (
   .FIFO_DW ( 32 ),
   .FIFO_AW ( 8 )
) FIFO_DC ( 
   .wr_clk_i       ( adc_clk_i   ),
   .wr_rst_ni      ( adc_rst_ni  ),
   .wr_en_i        ( 1'b1        ),
   .push_i         ( adc_push_i  ),
   .data_i         ( adc_data_i  ),
   .rd_clk_i       ( dma_clk_i   ),
   .rd_rst_ni      ( dma_rst_ni  ),
   .rd_en_i        ( 1'b1        ),
   .pop_i          ( do_push     ),
   .data_o         ( data_s      ),
   .flush_i        ( flush_i ),
   .async_empty_o  ( push_empty ),
   .async_full_o   ( push_full ));

always_ff @(posedge dma_clk_i, negedge dma_rst_ni) begin
   if (!dma_rst_ni ) begin
      do_push      <= 1'b0;
   end else  begin
      if      ( flush_i     )             do_push      <= 1'b0;
      else if ( !push_empty & !do_push )  do_push      <= 1'b1;
      else if ( do_push     )             do_push      <= 1'b0;
   end
end

///////////////////////////////////////////////////////////////////////////////
// READ (tProc has Priority)
///////////////////////////////////////////////////////////////////////////////
generate
///////////////////////////////////////////////////////////////////////////////
   if ( DMA_BLOCK==1 ) begin: DMA // Read Using DMA
      ///// 
      assign do_dma_pop  = (dma_pop_i & !dma_empty & !do_proc_pop) | (do_push & dma_full) ; // POP IF FULL
      assign dma_empty   = (rd_dma_ptr == wr_ptr) ;   
      assign dma_full    = (rd_dma_ptr == wr_ptr_p1) ;
      // DMA Data QTY
      always_ff @(posedge dma_clk_i) begin
         if      ( !dma_rst_ni )            dma_qty <= 0;
         else if (  do_push & !do_dma_pop ) dma_qty <= dma_qty + 1'b1 ;
         else if ( !do_push &  do_dma_pop ) dma_qty <= dma_qty - 1'b1 ;
      end
   end else begin
      assign do_dma_pop = 1'b0;
      assign dma_empty  = 1'b0;
      assign dma_full   = 1'b0;
      assign dma_qty    = 0;
   end
///////////////////////////////////////////////////////////////////////////////
   if ( RD_BLOCK==1 ) begin: RD // Read Using RD

      sync_pulse # (
         .QUEUE_AW ( 8 ) ,
         .BLOCK    ( 0  ) 
      ) sync_p_i ( 
         .a_clk_i    ( c_clk_i   ) ,
         .a_rst_ni   ( c_rst_ni  ) ,
         .a_pulse_i  ( c_pop_i   ) ,
         .b_clk_i    ( dma_clk_i ) ,
         .b_rst_ni   ( dma_rst_ni) ,
         .b_pulse_o  ( c_pop_s   ) ,
         .b_en_i     ( 1'b1 ) ,
         .pulse_full (  ) );

      assign do_proc_pop   = ( c_pop_s  & !proc_empty) | (do_push & proc_full); // POP IF FULL
      assign proc_empty    = ( rd_proc_ptr == wr_ptr) ;   
      assign proc_full     = ( rd_proc_ptr == wr_ptr_p1) ;
      // PROC_RD Data QTY
      always_ff @(posedge dma_clk_i) begin
         if      ( !dma_rst_ni )              proc_qty <= 0;
         else if (  do_push & !do_proc_pop ) proc_qty <= proc_qty + 1'b1 ;
         else if ( !do_push &  do_proc_pop ) proc_qty <= proc_qty - 1'b1 ;
      end
   end else begin
      assign do_proc_pop   = 1'b0;
      assign proc_empty    = 1'b0;
      assign proc_full     = 1'b0;
      assign proc_qty        = 0;
   end
endgenerate

///////////////////////////////////////////////////////////////////////////////
// POINTERS
///////////////////////////////////////////////////////////////////////////////
assign wr_ptr_p1      = wr_ptr      + 1'b1 ;
assign rd_proc_ptr_p1 = rd_proc_ptr + 1'b1 ;
assign rd_dma_ptr_p1  = rd_dma_ptr  + 1'b1 ;

always_ff @(posedge dma_clk_i, negedge dma_rst_ni) begin
   if (!dma_rst_ni) begin
      wr_ptr      <= 0;
      rd_dma_ptr  <= 0;
      rd_proc_ptr <= 0;
   end else if (flush_i) begin
      wr_ptr      <= 0;
      rd_dma_ptr  <= 0;
      rd_proc_ptr <= 0;
   end else  begin
      if ( do_push     ) wr_ptr      <= wr_ptr_p1;
      if ( do_proc_pop ) rd_proc_ptr <= rd_proc_ptr_p1;
      if ( do_dma_pop  ) rd_dma_ptr  <= rd_dma_ptr_p1;
   end
end


assign addr_b = do_proc_pop ? rd_proc_ptr : rd_dma_ptr;

BRAM_SC # ( 
   .MEM_AW  ( FIFO_AW ) , 
   .MEM_DW  ( FIFO_DW ) 
) BRAM_SC ( 
   .clk_i     ( dma_clk_i ),
   .we_a_i    ( do_push ),
   .addr_a_i  ( wr_ptr ),
   .dt_a_i    ( data_s ),
   .addr_b_i  ( addr_b ),
   .dt_b_o    ( mem_dt ));
   
// OUT
///////////////////////////////////////////////////////////////////////////////

always_ff @(posedge dma_clk_i) begin
   if (!dma_rst_ni) begin
      do_proc_pop_r  <= 0;
      do_dma_pop_r   <= 0;      
   end else begin
      do_proc_pop_r  <= do_proc_pop;
      do_dma_pop_r   <= do_dma_pop;
   end
end

assign flush_o      =  push_empty & push_full ;
assign full_o        = proc_full | dma_full;

assign c_qty_o      = proc_qty;
assign c_empty_o    = proc_empty  ; // While RESETTING, Shows EMPTY
assign c_pop_o      = do_proc_pop_r;

assign dma_qty_o     = dma_qty;
assign dma_empty_o   = dma_empty; // While RESETTING, Shows EMPTY
assign dma_pop_o     = do_dma_pop_r;
assign dt_o          = mem_dt;

endmodule

