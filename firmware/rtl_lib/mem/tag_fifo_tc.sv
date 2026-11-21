///////////////////////////////////////////////////////////////////////////////
//  FERMI RESEARCH LAB
///////////////////////////////////////////////////////////////////////////////
//  tag_fifo_tc
//  Faithful port from qick_time_tagger's tag_mem.sv (module TAG_FIFO_TC).
//  Tri-port variant of tag_fifo_dc used for tag channel 0: an async FIFO
//  moves 32-bit tag words from tag_clk to dma_clk into a dma_clk-only ring
//  buffer (qick:mem:bram_simple_dp), which is then read by TWO independent
//  consumers sharing the ring buffer's single read port - the tProc
//  ("proc"/c_clk side, popped via a qick:cdc:sync_pulse CDC of tag_pop_i)
//  and the DMA reader (dma_pop_i) - each with its own read pointer/qty and
//  overwrite-on-full behavior. The proc side has priority when both want
//  to read the same cycle.
//
//  Async FIFO stage uses qick:mem:fifo_async (xpm_fifo_async,
//  READ_MODE="fwft") instead of the legacy hand-rolled FIFO_DC, same
//  flush-folded-into-wr_rstn substitution as tag_fifo_dc.
///////////////////////////////////////////////////////////////////////////////

module tag_fifo_tc # (
   parameter int TAG_DW    = 32 ,
   parameter int FIFO_AW   = 18
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
   input  wire                   tag_pop_i     ,
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
wire                 push_empty, push_full ;
wire                 do_push ;
wire                 push_wr_rstn ;
wire                 c_pop_s ;


///////////////////////////////////////////////////////////////////////////////
// WRITE
///////////////////////////////////////////////////////////////////////////////

// fifo_async has no flush_i: pulsing the write-side reset reproduces the
// legacy `rst = ~wr_rst_ni | flush_i` (same technique tag_fifo_dc and
// qick:utils:qproc_dispatcher use).
assign push_wr_rstn = tag_rst_ni & ~flush_i;

// The flush comes from the ADC clock domain; everything below the async FIFO runs on the DMA clock, so it is
// synchronised first (legacy: the raw level was used as a synchronous reset in the DMA domain).
wire flush_dma;
cdc_bit_sync # (
   .NSTAGES ( 2 )
) flush_sync (
   .i_clk   ( dma_clk_i ),
   .i_rstn  ( dma_rst_ni ),
   .i_async ( flush_i   ),
   .o_sync  ( flush_dma )
);

fifo_async # (
   .B          ( TAG_DW ),
   .N          ( 256    ),
   .READ_MODE  ( "fwft" )
) fifo_push (
   .wr_rstn     ( push_wr_rstn ),
   .wr_clk      ( tag_clk_i    ),
   .wr_en       ( tag_push_i   ),
   .din         ( tag_data_i   ),
   .full        ( push_full    ),
   .wr_err      (              ),
   .rd_rstn     ( dma_rst_ni   ),
   .rd_clk      ( dma_clk_i    ),
   .rd_en       ( do_push      ),
   .dout        ( data_s       ),
   .empty       ( push_empty   ),
   .data_valid  (              ));

// fwft: whenever the inner FIFO isn't empty, its front word is already
// valid on data_s - move it into the ring buffer every cycle it can.
assign do_push = !push_empty ;

///////////////////////////////////////////////////////////////////////////////
// POINTERS
///////////////////////////////////////////////////////////////////////////////
assign wr_ptr_p1 = wr_ptr + 1'b1 ;

always_ff @(posedge dma_clk_i, negedge dma_rst_ni) begin
   if (!dma_rst_ni) begin
      wr_ptr      <= 0;
      rd_dma_ptr  <= 0;
      rd_proc_ptr <= 0;
   end else if (flush_dma) begin
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
   if      ( !dma_rst_ni |  flush_dma    ) dma_qty <= 0;
   else if (  do_push    & !do_dma_pop ) dma_qty <= dma_qty + 1'b1 ;
   else if ( !do_push    &  do_dma_pop ) dma_qty <= dma_qty - 1'b1 ;
end

sync_pulse # (
   .QUEUE_AW ( 8 ) ,
   .BLOCK    ( 0  )
) sync_p_i (
   .a_clk_i    ( tag_clk_i   ) ,
   .a_rst_ni   ( tag_rst_ni  ) ,
   .a_pulse_i  ( tag_pop_i   ) ,
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
   if      ( !dma_rst_ni |  flush_dma     ) proc_qty <= 0;
   else if (  do_push    & !do_proc_pop ) proc_qty <= proc_qty + 1'b1 ;
   else if ( !do_push    &  do_proc_pop ) proc_qty <= proc_qty - 1'b1 ;
end


assign addr_b = do_proc_pop ? rd_proc_ptr : rd_dma_ptr;

bram_simple_dp # (
   .B  ( TAG_DW  ) ,
   .N  ( FIFO_AW )
) fifo_tag (
   .clk     ( dma_clk_i  ),
   .ena     ( 1'b1       ),
   .enb     ( 1'b1       ),
   .wea     ( do_push    ),
   .addra   ( wr_ptr     ),
   .dia     ( data_s     ),
   .addrb   ( addr_b     ),
   .dob     ( mem_dt     )
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
assign debug_do[8]    = tag_pop_i;
assign debug_do[9]    = do_proc_pop;
assign debug_do[10]   = c_pop_o;
assign debug_do[11]   = flush_i;
assign debug_do[12]   = flush_o;
assign debug_do[13]   = full_o;
assign debug_do[15:14] = 0;


// OUT
///////////////////////////////////////////////////////////////////////////////

// Not consumed by any legacy caller for this signal shape either (see
// tag_fifo_dc) - kept only for debug_do parity.
assign flush_o       =  flush_i ;
assign full_o        = proc_full | dma_full;

assign c_qty_o      = proc_qty;
assign c_empty_o    = proc_empty  ; // While RESETTING, Shows EMPTY
assign c_pop_o      = do_proc_pop_r;

assign dma_qty_o     = dma_qty;
assign dma_empty_o   = dma_empty; // While RESETTING, Shows EMPTY
assign dma_pop_o     = do_dma_pop_r;
assign dt_o          = mem_dt;

endmodule
