///////////////////////////////////////////////////////////////////////////////
//  FERMI RESEARCH LAB
///////////////////////////////////////////////////////////////////////////////
//  Author         : Martin Di Federico
//  Date           : 2024_5_31
///////////////////////////////////////////////////////////////////////////////

module tag_mem # (
   parameter MEM_QTY      = 1  , // Amount of Memories
   parameter TAG_FIFO_AW  = 20 , // Size of TAG FIFO Memory
   parameter DEBUG        = 0  
) (
// Core and AXI CLK & RST
   input  wire                      dma_clk_i          ,
   input  wire                      dma_rst_ni         ,
   input  wire                      c_clk_i            ,
   input  wire                      c_rst_ni           ,
   input  wire                      adc_clk_i          ,
   input  wire                      adc_rst_ni         ,
   input  wire                      qtt_pop_req_i      ,
   output wire                      qtt_pop_ack_o      ,
   input  wire                      qtt_rst_req_i      ,
   output wire                      qtt_rst_ack_o      ,
///// Memory
   input  wire [MEM_QTY-1:0]        tag_wr_i  , 
   input  wire [31:0]               tag_dt_i [MEM_QTY] , 
   output wire [TAG_FIFO_AW-1:0]    dma_qty_o[4] ,
   output wire [TAG_FIFO_AW-1:0]    proc_qty_o           ,
   output wire                      empty_o           ,
   output wire                      full_o            ,
///// DATA DMA
   input  wire [1:0]                dma_sel_i          ,
   input  wire                      dma_pop_i          ,
   output wire                      dma_pop_o          ,
   output wire [31:0]               dma_dt_o           ,
///// STATUS & DEBUG   
   output wire [31:0]               debug_do
   );


wire  [MEM_QTY-1:0] dma_pop_req, dma_pop_ack;
wire  [31:0] mem_dt [MEM_QTY-1:0];
wire  [MEM_QTY-1:0] empty, full;

assign dma_pop_req[0] = dma_pop_i & (dma_sel_i == 2'b00);
TAG_FIFO_TC # (
   .TAG_DW        ( 32           ) , 
   .FIFO_AW       ( TAG_FIFO_AW  )  
) MEM0 ( 
   .dma_clk_i     ( dma_clk_i       ) , 
   .dma_rst_ni    ( dma_rst_ni      ) , 
   .c_clk_i       ( c_clk_i         ) , 
   .c_rst_ni      ( c_rst_ni        ) , 
   .tag_clk_i     ( adc_clk_i       ) , 
   .tag_rst_ni    ( adc_rst_ni      ) , 
   .tag_push_i    ( tag_wr_i [0]    ) , 
   .tag_data_i    ( tag_dt_i [0]    ) , 
   .flush_i       ( qtt_rst_req_i   ) ,
   .flush_o       ( qtt_rst_ack_o   ) ,
   .c_pop_i       ( qtt_pop_req_i   ) , 
   .c_pop_o       ( qtt_pop_ack_o   ) , 
   .c_qty_o       ( proc_qty_o      ) , 
   .c_empty_o     (                 ) , 
   .dma_pop_i     ( dma_pop_req [0] ) , 
   .dma_pop_o     ( dma_pop_ack [0] ) , 
   .dma_qty_o     ( dma_qty_o   [0] ) , 
   .dt_o          ( mem_dt      [0] ) , 
   .dma_empty_o   ( empty [0]       ) , 
   .full_o        ( full [0]        ) ,
   .debug_do      ( tag_mem_ds      )
);

genvar ind;
generate
   for (ind=1; ind<4; ind++) begin: TAG
      if (ind < MEM_QTY ) begin
         assign dma_pop_req[ind] = dma_pop_i & (dma_sel_i == ind[1:0]);
         TAG_FIFO_DC # (
            .FIFO_AW     ( TAG_FIFO_AW )
         ) MEM ( 
            .dma_clk_i   ( dma_clk_i     ),
            .dma_rst_ni  ( dma_rst_ni    ),
            .adc_clk_i   ( adc_clk_i     ),
            .adc_rst_ni  ( adc_rst_ni    ),
            .flush_i     ( qtt_rst_req_i ),
            .flush_o     (   ),
            .adc_push_i  ( tag_wr_i    [ind] ),
            .adc_data_i  ( tag_dt_i    [ind] ),
            .dma_pop_i   ( dma_pop_req [ind] ),
            .dma_pop_o   ( dma_pop_ack [ind] ),
            .dma_qty_o   ( dma_qty_o   [ind] ),
            .dma_dt_o    ( mem_dt      [ind] ),
            .empty_o     ( empty  [ind]  ),
            .full_o      ( full [ind]  ),
            .debug_do    (   )
         );
      end else
         assign dma_qty_o[ind] = 0;
      end
endgenerate



// DEBUG
///////////////////////////////////////////////////////////////////////////////
assign debug_do = 0;

// OUT
///////////////////////////////////////////////////////////////////////////////

assign empty_o = |empty;
assign full_o  = &full;

assign dma_pop_o   = |dma_pop_ack ;
assign dma_dt_o    = mem_dt[dma_sel_i];

endmodule

///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////

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
   parameter TAG_DW    = 32 , 
   parameter FIFO_AW   = 18 
) ( 
   input  wire                   tag_clk_i   ,
   input  wire                   tag_rst_ni  ,
   input  wire                   c_clk_i     ,
   input  wire                   c_rst_ni    ,
   input  wire                   dma_clk_i   ,
   input  wire                   dma_rst_ni  ,
   input  wire                   flush_i   ,
   output wire                   flush_o   ,
   input  wire                   tag_push_i  ,
   input  wire [TAG_DW - 1:0]    tag_data_i  ,
   input  wire                   c_pop_i     ,
   output wire                   c_pop_o     ,
   output wire [FIFO_AW-1:0]     c_qty_o     ,
   output wire                   c_empty_o   ,
   input  wire                   dma_pop_i   ,
   output wire                   dma_pop_o   ,
   output wire [FIFO_AW-1:0]     dma_qty_o   ,
   output wire                   dma_empty_o ,
   output wire [TAG_DW - 1:0]   dt_o        ,
   output wire                   full_o      ,
   output wire [15:0]            debug_do    );


// The WRITE_POINTER is on the Last Empty Value
// The READ_POINTER is on the Last Value

wire [FIFO_AW-1:0]   wr_ptr_p1 ;
reg  [FIFO_AW-1:0]   rd_dma_ptr, rd_proc_ptr, wr_ptr;
wire [FIFO_AW-1:0]   addr_b ;
wire [TAG_DW-1:0]    data_s, mem_dt;
reg  [FIFO_AW-1:0]   dma_qty, proc_qty;
wire                 dma_full, proc_full;
wire                 dma_empty, proc_empty ;
wire                 do_dma_pop, do_proc_pop;
reg                  do_dma_pop_r, do_proc_pop_r ;


///////////////////////////////////////////////////////////////////////////////
// WRITE
///////////////////////////////////////////////////////////////////////////////
reg do_push;

FIFO_DC # (
   .FIFO_DW ( 32 ),
   .FIFO_AW ( 10 )
) FIFO_PUSH ( 
   .wr_clk_i       ( tag_clk_i   ),
   .wr_rst_ni      ( tag_rst_ni  ),
   .wr_en_i        ( 1'b1        ),
   .push_i         ( tag_push_i  ),
   .data_i         ( tag_data_i  ),
   .rd_clk_i       ( dma_clk_i   ),
   .rd_rst_ni      ( dma_rst_ni  ),
   .rd_en_i        ( 1'b1        ),
   .pop_i          ( do_push     ),
   .data_o         ( data_s      ),
   .flush_i        ( flush_i     ),
   .async_empty_o  ( push_empty  ),
   .async_full_o   ( push_full   )
);

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
// POINTERS
///////////////////////////////////////////////////////////////////////////////
assign wr_ptr_p1 = wr_ptr + 1'b1 ;

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
      if ( do_proc_pop ) rd_proc_ptr <= rd_proc_ptr + 1'b1 ;
      if ( do_dma_pop  ) rd_dma_ptr  <= rd_dma_ptr  + 1'b1 ;
   end
end


///////////////////////////////////////////////////////////////////////////////
// READ (tProc has Priority)
///////////////////////////////////////////////////////////////////////////////
assign do_dma_pop  = (dma_pop_i & !dma_empty & !do_proc_pop) | (do_push & dma_full) ; // POP IF FULL
assign dma_empty   = (rd_dma_ptr == wr_ptr) ;   
assign dma_full    = (rd_dma_ptr == wr_ptr_p1) ;
// DMA Data QTY
always_ff @(posedge dma_clk_i) begin
   if      ( !dma_rst_ni )            dma_qty <= 0;
   else if (  do_push & !do_dma_pop ) dma_qty <= dma_qty + 1'b1 ;
   else if ( !do_push &  do_dma_pop ) dma_qty <= dma_qty - 1'b1 ;
end

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


assign addr_b = do_proc_pop ? rd_proc_ptr : rd_dma_ptr;

BRAM_SC # ( 
   .MEM_AW    ( FIFO_AW ) , 
   .MEM_DW    ( TAG_DW  ) 
) FIFO_TAG ( 
   .clk_i     ( dma_clk_i  ),
   .we_a_i    ( do_push    ),
   .addr_a_i  ( wr_ptr     ),
   .dt_a_i    ( data_s     ),
   .addr_b_i  ( addr_b     ),
   .dt_b_o    ( mem_dt     )
);
   
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

// DEBUG
///////////////////////////////////////////////////////////////////////////////
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


// OUT 
///////////////////////////////////////////////////////////////////////////////

assign flush_o       =  push_empty & push_full ;
assign full_o        = proc_full | dma_full;

assign c_qty_o      = proc_qty;
assign c_empty_o    = proc_empty  ; // While RESETTING, Shows EMPTY
assign c_pop_o      = do_proc_pop_r;

assign dma_qty_o     = dma_qty;
assign dma_empty_o   = dma_empty; // While RESETTING, Shows EMPTY
assign dma_pop_o     = do_dma_pop_r;
assign dt_o          = mem_dt;

endmodule