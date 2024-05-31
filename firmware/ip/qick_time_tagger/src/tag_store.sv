///////////////////////////////////////////////////////////////////////////////
//  FERMI RESEARCH LAB
///////////////////////////////////////////////////////////////////////////////
//  Author         : Martin Di Federico
//  Date           : 1-2024
//  Version        : 1
///////////////////////////////////////////////////////////////////////////////

module tag_mem # (
   parameter MEM_QTY      = 1  , // Amount of Memories
   parameter DMA_RD       = 1  , // TAG FIFO Read from DMA
   parameter PROC_RD      = 0  , // TAG FIFO Read from tProcessor
   parameter TAG_FIFO_AW  = 20 , // Size of TAG FIFO Memory
   parameter DEBUG        = 0  
) (
// Core and AXI CLK & RST
   input  wire                      dma_clk_i      ,
   input  wire                      dma_rst_ni     ,
   input  wire                      c_clk_i        ,
   input  wire                      c_rst_ni       ,
   input  wire                      adc_clk_i      ,
   input  wire                      adc_rst_ni     ,
   input  wire                      qtt_pop_req_i  ,
   input  wire                      qtt_rst_req_i  ,
   output wire                      qtt_rst_ack_o  ,
   input  wire                      tag_wr_i [MEM_QTY]     , 
   input  wire [31:0]               tag_dt_i [MEM_QTY]     , 
///// DATA DMA
   input  wire [1:0]                dma_sel_i      ,
   input  wire                      dma_pop_i      ,
   output wire                      dma_pop_o      ,
   output reg  [31:0]               dma_dt_o       ,
   output wire [TAG_FIFO_AW-1:0]    tag0_qty_o     ,
   output wire [TAG_FIFO_AW-1:0]    tag1_qty_o     ,
   output wire [TAG_FIFO_AW-1:0]    tag2_qty_o     ,
   output wire [TAG_FIFO_AW-1:0]    tag3_qty_o     ,
   output wire                      tag_empty_o    ,
   output wire                      tag_full_o     ,
///// STATUS & DEBUG   
   output wire [31:0]               tag_debug_o
   );


wire tag0_pop_ack, tag1_pop_ack, tag2_pop_ack, tag3_pop_ack;
wire tag0_empty, tag1_empty, tag2_empty, tag3_empty ;
wire tag0_full , tag1_full , tag2_full , tag3_full ;


assign tag0_sel = (dma_sel_i == 2'b00);
assign tag1_sel = (dma_sel_i == 2'b01);
assign tag2_sel = (dma_sel_i == 2'b10);
assign tag3_sel = (dma_sel_i == 2'b11);

assign dma_pop_req0 = dma_pop_i & tag0_sel;
assign dma_pop_req1 = dma_pop_i & tag1_sel;
assign dma_pop_req2 = dma_pop_i & tag2_sel;
assign dma_pop_req3 = dma_pop_i & tag3_sel;

wire [31:0] tag0_dt, tag1_dt, tag2_dt, tag3_dt;


generate
   if             (MEM_QTY > 0 ) begin: TAG_0
      TAG_FIFO_TC # (
         .DMA_BLOCK     ( DMA_RD       ) , 
         .RD_BLOCK      ( PROC_RD      ) , 
         .FIFO_DW       ( 32           ) , 
         .FIFO_AW       ( TAG_FIFO_AW  )  
      ) MEM0 ( 
         .dma_clk_i     ( dma_clk_i     ) , 
         .dma_rst_ni    ( dma_rst_ni    ) , 
         .c_clk_i       ( c_clk_i       ) , 
         .c_rst_ni      ( c_rst_ni      ) , 
         .adc_clk_i     ( adc_clk_i     ) , 
         .adc_rst_ni    ( adc_rst_ni    ) , 
         .flush_i       ( qtt_rst_req_i ) ,
         .flush_o       ( qtt_rst_ack_o ) ,
         .adc_push_i    ( tag_wr_i[0]    ) , 
         .adc_data_i    ( tag_dt_i[0]    ) , 
         .c_pop_i       ( qtt_pop_req_i ) , 
         .c_pop_o       ( qtt_pop_ack   ) , 
         .c_qty_o       ( proc_qty_o    ) , 
         .c_empty_o     (               ) , 
         .dma_pop_i     ( dma_pop_req0   ) , 
         .dma_pop_o     ( tag0_pop_ack  ) , 
         .dma_qty_o     ( tag0_qty_o     ) , 
         .dma_empty_o   ( tag0_empty ) , 
         .dt_o          ( tag0_dt   ) , 
         .full_o        ( tag0_full              ) ,
         .debug_do      ( tag_mem_ds    ));
   end 
   if    (MEM_QTY > 1 ) begin: TAG_1
      TAG_FIFO_DC # (
         .FIFO_AW     ( TAG_FIFO_AW )
      ) MEM1 ( 
         .adc_clk_i   ( adc_clk_i     ),
         .adc_rst_ni  ( adc_rst_ni    ),
         .dma_clk_i   ( dma_clk_i     ),
         .dma_rst_ni  ( dma_rst_ni    ),
         .dma_pop_i   ( dma_pop_req1   ),
         .flush_i     ( qtt_rst_req_i ),
         .flush_o     (   ),
         .adc_push_i  ( tag1_wr_i     ),
         .adc_data_i  ( tag1_dt_i     ),
         .dma_pop_o   ( tag1_pop_ack  ),
         .dma_qty_o   ( tag1_qty_o    ),
         .dma_dt_o    ( tag1_dt     ),
         .empty_o     ( tag1_empty  ),
         .full_o      ( tag1_full   ),
         .debug_do    ( tag1_debug   ));
   end
   if    (MEM_QTY > 2 ) begin: TAG_2
      TAG_FIFO_DC # (
         .FIFO_AW     ( TAG_FIFO_AW )
      ) MEM2 ( 
         .adc_clk_i   ( adc_clk_i     ),
         .adc_rst_ni  ( adc_rst_ni    ),
         .dma_clk_i   ( dma_clk_i     ),
         .dma_rst_ni  ( dma_rst_ni    ),
         .dma_pop_i   ( dma_pop_req2   ),
         .flush_i     ( qtt_rst_req_i ),
         .flush_o     (   ),
         .adc_push_i  ( tag2_wr_i     ),
         .adc_data_i  ( tag2_dt_i     ),
         .dma_pop_o   ( tag2_pop_ack  ),
         .dma_qty_o   ( tag2_qty_o    ),
         .dma_dt_o    ( tag2_dt     ),
         .empty_o     ( tag2_empty  ),
         .full_o      ( tag2_full   ),
         .debug_do    ( tag2_debug   ));
   end
   if    (MEM_QTY > 3 ) begin: TAG_3
      TAG_FIFO_DC # (
         .FIFO_AW     ( TAG_FIFO_AW )
      ) MEM3 ( 
         .adc_clk_i   ( adc_clk_i     ),
         .adc_rst_ni  ( adc_rst_ni    ),
         .dma_clk_i   ( dma_clk_i     ),
         .dma_rst_ni  ( dma_rst_ni    ),
         .dma_pop_i   ( dma_pop_req3   ),
         .flush_i     ( qtt_rst_req_i ),
         .flush_o     (   ),
         .adc_push_i  ( tag3_wr_i     ),
         .adc_data_i  ( tag3_dt_i     ),
         .dma_pop_o   ( tag3_pop_ack  ),
         .dma_qty_o   ( tag3_qty_o    ),
         .dma_dt_o    ( tag3_dt     ),
         .empty_o     ( tag3_empty  ),
         .full_o      ( tag3_full   ),
         .debug_do    ( tag3_debug   ));
   end
   if          ( MEM_QTY < 4  ) begin: TAG_Z3
      assign tag3_pop_ack = 0;
      assign tag3_qty_o   = 0;
      assign tag3_dt      = 0;
      assign tag3_empty_o = 0;
      assign tag3_full_o  = 0;
      assign tag3_debug   = 0;
   end
   if ( MEM_QTY < 3  ) begin: TAG_Z2
      assign tag2_pop_ack = 0;
      assign tag2_qty_o   = 0;
      assign tag2_dt    = 0;
      assign tag2_empty_o = 0;
      assign tag2_full_o  = 0;
      assign tag2_debug   = 0;
   end
   if ( MEM_QTY < 2 )  begin: TAG_Z1
      assign tag1_pop_ack = 0;
      assign tag1_qty_o   = 0;
      assign tag1_dt    = 0;
      assign tag1_empty_o = 0;
      assign tag1_full_o  = 0;
      assign tag1_debug   = 0;
   end
endgenerate


// OUT
///////////////////////////////////////////////////////////////////////////////

assign dma_pop_o     = tag0_pop_ack | tag1_pop_ack | tag2_pop_ack | tag3_pop_ack;

assign tag_empty_o = tag0_empty & tag1_empty & tag2_empty & tag3_empty ;
assign tag_full_o  = tag0_full  & tag1_full  & tag2_full  & tag3_full ;

always_comb
   case (dma_sel_i)
      2'b00: dma_dt_o = tag0_dt;
      2'b01: dma_dt_o = tag1_dt;
      2'b10: dma_dt_o = tag2_dt;
      2'b11: dma_dt_o = tag3_dt;
   endcase
      
assign tag_debug_o = 0;
 

endmodule









module TAG_FIFO_DC # (
   parameter FIFO_AW   = 10 
) ( 
   input  wire                   adc_clk_i   ,
   input  wire                   adc_rst_ni  ,
   input  wire                   dma_clk_i   ,
   input  wire                   dma_rst_ni  ,
   input  wire                   flush_i     ,
   output wire                   flush_o     ,
   input  wire                   adc_push_i  ,
   input  wire [31:0]            adc_data_i  ,
   input  wire                   dma_pop_i   ,
   output wire                   dma_pop_o   ,
   output wire [FIFO_AW-1:0]     dma_qty_o   ,
   output wire [31:0]            dma_dt_o    ,
   output wire                   empty_o     ,
   output wire                   full_o      ,
   output wire [7:0]             debug_do    );

// Signal Declaration
///////////////////////////////////////////////////////////////////////////////
reg  [FIFO_AW-1:0] rd_ptr   , wr_ptr ;
wire [FIFO_AW-1:0] rd_ptr_p1, wr_ptr_p1 ;
reg  [FIFO_AW-1:0] tag_qty ;
wire [31:0] data_s, mem_dt ;
wire do_pop ;
reg  do_pop_r ;
wire tag_full, tag_empty ;

///////////////////////////////////////////////////////////////////////////////
// WRITE FIFO
///////////////////////////////////////////////////////////////////////////////
reg do_push;

FIFO_DC # (
   .FIFO_DW ( 32 ),
   .FIFO_AW ( 8 )
) FIFO_PUSH ( 
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
   .flush_i        ( flush_i     ),
   .async_empty_o  ( push_empty  ),
   .async_full_o   ( push_full   ));

// PUSH AND POP 
///////////////////////////////////////////////////////////////////////////////

always_ff @(posedge dma_clk_i, negedge dma_rst_ni) begin
   if (!dma_rst_ni ) begin
      do_push      <= 1'b0;
   end else  begin
      if      ( flush_i     )             do_push      <= 1'b0;
      else if ( !push_empty & !do_push )  do_push      <= 1'b1;
      else if ( do_push     )             do_push      <= 1'b0;
   end
end

assign do_pop      = (dma_pop_i & !tag_empty ) | (do_push & tag_full) ; // POP IF FULL

// POINTERS
///////////////////////////////////////////////////////////////////////////////
// WRITE_POINTER > Last Empty Value
// READ_POINTER  > Last Value

assign wr_ptr_p1  = wr_ptr  + 1'b1 ;
assign rd_ptr_p1  = rd_ptr  + 1'b1 ;

always_ff @(posedge dma_clk_i, negedge dma_rst_ni) begin
   if (!dma_rst_ni) begin
      wr_ptr  <= 0;
      rd_ptr  <= 0;
   end else if (flush_i) begin
      wr_ptr  <= 0;
      rd_ptr  <= 0;
   end else  begin
      if ( do_push ) wr_ptr  <= wr_ptr_p1;
      if ( do_pop  ) rd_ptr  <= rd_ptr_p1;
   end
end

assign tag_empty   = (rd_ptr == wr_ptr) ;   
assign tag_full    = (rd_ptr == wr_ptr_p1) ;

// TAG QTY
always_ff @(posedge dma_clk_i) begin
   if      ( !dma_rst_ni )        tag_qty <= 0;
   else if (  do_push & !do_pop ) tag_qty <= tag_qty + 1'b1 ;
   else if ( !do_push &  do_pop ) tag_qty <= tag_qty - 1'b1 ;
end


BRAM_SC # ( 
   .MEM_DW  ( 32 ) ,
   .MEM_AW  ( FIFO_AW )  
) FIFO_TAG ( 
   .clk_i     ( dma_clk_i ),
   .we_a_i    ( do_push ),
   .addr_a_i  ( wr_ptr ),
   .dt_a_i    ( data_s ),
   .addr_b_i  ( rd_ptr ),
   .dt_b_o    ( mem_dt ));
   
// DEBUG
///////////////////////////////////////////////////////////////////////////////
assign debug_do[0]   = tag_full ;
assign debug_do[1]   = tag_empty;
assign debug_do[2]   = push_empty;
assign debug_do[3]   = do_push;
assign debug_do[4]   = dma_pop_i ;
assign debug_do[5]   = do_pop ;
assign debug_do[6]   = flush_i;
assign debug_do[7]   = flush_o;

// OUT
///////////////////////////////////////////////////////////////////////////////

always_ff @(posedge dma_clk_i) begin
   if (!dma_rst_ni) begin
      do_pop_r   <= 0;      
   end else begin
      do_pop_r   <= do_pop;
   end
end

assign flush_o    = push_empty & push_full ;
assign full_o     = tag_full ;
assign empty_o    = tag_empty ;

assign dma_qty_o  = tag_qty;
assign dma_pop_o  = do_pop_r;
assign dma_dt_o   = mem_dt;

endmodule









module TAG_FIFO_TC # (
   parameter DMA_BLOCK = 1 , 
   parameter RD_BLOCK  = 0 , 
   parameter FIFO_DW   = 32 , 
   parameter FIFO_AW   = 10 
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
   output wire [FIFO_AW-1:0]     c_qty_o     ,
   output wire                   c_empty_o   ,
   input  wire                   dma_pop_i   ,
   output wire                   dma_pop_o   ,
   output wire [FIFO_AW-1:0]     dma_qty_o   ,
   output wire                   dma_empty_o ,
   output wire [FIFO_DW - 1:0]   dt_o        ,
   output wire                   full_o      ,
   output wire [15:0]            debug_do    );


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
) FIFO_PUSH ( 
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
         if      ( !dma_rst_ni )             proc_qty <= 0;
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
) FIFO_TAG ( 
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

  
assign debug_do[0]    = dma_full ;
assign debug_do[1]    = dma_empty;
assign debug_do[2]    = proc_full;
assign debug_do[3]    = proc_empty;
assign debug_do[4]    = do_push;
assign debug_do[5]    = dma_pop_i ;
assign debug_do[6]    = do_dma_pop ;
assign debug_do[7]    = dma_pop_o;
assign debug_do[8]    = c_pop_i;
assign debug_do[9]    = do_proc_pop;
assign debug_do[10]   = c_pop_o;
assign debug_do[11]   = flush_i;
assign debug_do[12]   = flush_o;
assign debug_do[13]   = full_o;
assign debug_do[15:14] = 0;

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