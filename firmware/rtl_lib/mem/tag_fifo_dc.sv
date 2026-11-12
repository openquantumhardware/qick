///////////////////////////////////////////////////////////////////////////////
//  FERMI RESEARCH LAB
///////////////////////////////////////////////////////////////////////////////
//  tag_fifo_dc
//  Faithful port from qick_time_tagger's tag_mem.sv (module TAG_FIFO_DC).
//  Two-stage tag buffer: an async FIFO moves 32-bit tag words from adc_clk
//  to dma_clk, then a small dma_clk-only synchronous ring buffer
//  (qick:mem:bram_simple_dp, in place of the legacy BRAM_SC) holds them for
//  the DMA reader. The ring buffer is overwrite-on-full: a push while full
//  forces a pop first (drops the oldest entry) rather than blocking,
//  matching the legacy do_pop/do_push priority exactly.
//
//  The legacy async FIFO here was a hand-rolled gray-counter design
//  (_qtt_mem.sv's FIFO_DC, faithfully ported once as qick:mem:fifo_dc) with
//  a real characteristic: an isolated push, with no follow-up push soon
//  after, does not become visible on the read side at all. That is fine
//  for this IP's actual traffic (bursty ADC tag events), but makes the
//  block fragile to compose/test on its own. Reused qick:mem:fifo_async
//  (xpm_fifo_async, READ_MODE="fwft") instead, following the same
//  flush-folded-into-wr_rstn pattern already established for
//  qick:utils:qproc_dispatcher (fifo_async has no flush_i of its own).
///////////////////////////////////////////////////////////////////////////////

module tag_fifo_dc # (
   parameter int FIFO_AW   = 10
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

reg  [FIFO_AW-1:0] rd_ptr   , wr_ptr ;
wire [FIFO_AW-1:0] rd_ptr_p1, wr_ptr_p1 ;
reg  [FIFO_AW-1:0] tag_qty ;
wire [31:0] data_s, mem_dt ;
wire do_pop ;
reg  do_pop_r ;
wire tag_full, tag_empty ;
wire push_empty, push_full ;
wire do_push ;
wire push_wr_rstn ;

// fifo_async has no flush_i: pulsing the write-side reset reproduces the
// legacy `rst = ~wr_rst_ni | flush_i` (same technique qproc_dispatcher
// uses). The read side's reset is left unpulsed, matching that precedent.
assign push_wr_rstn = adc_rst_ni & ~flush_i;

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
   .B          ( 32     ),
   .N          ( 256    ),
   .READ_MODE  ( "fwft" )
) fifo_push (
   .wr_rstn     ( push_wr_rstn ),
   .wr_clk      ( adc_clk_i    ),
   .wr_en       ( adc_push_i   ),
   .din         ( adc_data_i   ),
   .full        ( push_full    ),
   .wr_err      (              ),
   .rd_rstn     ( dma_rst_ni   ),
   .rd_clk      ( dma_clk_i    ),
   .rd_en       ( do_push      ),
   .dout        ( data_s       ),
   .empty       ( push_empty   ),
   .data_valid  (              ));

// fwft: whenever the inner FIFO isn't empty, its front word is already
// valid on data_s - move it into the ring buffer every cycle it can,
// without waiting for a request/acknowledge round trip.
assign do_push = !push_empty ;

assign do_pop      = (dma_pop_i & !tag_empty ) | (do_push & tag_full) ; // POP IF FULL

assign wr_ptr_p1  = wr_ptr  + 1'b1 ;
assign rd_ptr_p1  = rd_ptr  + 1'b1 ;

always_ff @(posedge dma_clk_i, negedge dma_rst_ni) begin
   if (!dma_rst_ni) begin
      wr_ptr  <= 0;
      rd_ptr  <= 0;
   end else if (flush_dma) begin
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
   if      ( !dma_rst_ni |  flush_dma   ) tag_qty <= 0;
   else if (  do_push    & !do_pop    ) tag_qty <= tag_qty + 1'b1 ;
   else if ( !do_push    &  do_pop    ) tag_qty <= tag_qty - 1'b1 ;
end


bram_simple_dp # (
   .B  ( 32      ) ,
   .N  ( FIFO_AW )
) fifo_tag (
   .clk     ( dma_clk_i ),
   .ena     ( 1'b1      ),
   .enb     ( 1'b1      ),
   .wea     ( do_push   ),
   .addra   ( wr_ptr    ),
   .dia     ( data_s    ),
   .addrb   ( rd_ptr    ),
   .dob     ( mem_dt    ));

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

// Not consumed by any legacy caller (tag_mem.sv leaves TAG_FIFO_DC's
// flush_o unconnected for every instance) - kept only for debug_do parity.
assign flush_o    = flush_i ;
assign full_o     = tag_full ;
assign empty_o    = tag_empty ;

assign dma_qty_o  = tag_qty;
assign dma_pop_o  = do_pop_r;
assign dma_dt_o   = mem_dt;

endmodule
