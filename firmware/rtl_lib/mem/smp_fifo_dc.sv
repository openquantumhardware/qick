///////////////////////////////////////////////////////////////////////////////
//  FERMI RESEARCH LAB
///////////////////////////////////////////////////////////////////////////////
//  smp_fifo_dc
//  Faithful port from qick_time_tagger's smp_mem.sv (module SMP_FIFO_DC).
//  Moves SMP_CK*SMP_DW-wide sample bursts from adc_clk to dma_clk via an
//  async FIFO, then a dma_clk-only unpacking FSM writes them into a
//  dma_clk-only overwrite-on-full ring buffer one SMP_DW-wide sample at a
//  time (WR_IDLE -> pop one burst -> WR_PUSH_DT unpacks SMP_CK samples).
//
//  Async FIFO stage uses qick:mem:fifo_async (xpm_fifo_async,
//  READ_MODE="fwft") in place of the legacy hand-rolled FIFO_DC, same
//  substitution as tag_fifo_dc/tag_fifo_tc; storage ring buffer uses
//  qick:mem:bram_simple_dp in place of the legacy BRAM_SC.
///////////////////////////////////////////////////////////////////////////////

module smp_fifo_dc # (
   parameter int SMP_CK   = 8  ,
   parameter int SMP_DW   = 16 ,
   parameter int FIFO_AW  = 10
) (
   input  wire                         adc_clk_i   ,
   input  wire                         adc_rst_ni  ,
   input  wire                         dma_clk_i   ,
   input  wire                         dma_rst_ni  ,
   input  wire                         flush_i     ,
   output wire                         flush_o     ,
   input  wire                         adc_push_i  ,
   input  wire [SMP_CK*SMP_DW-1:0]     adc_data_i  ,
   input  wire                         dma_pop_i   ,
   output wire                         dma_pop_o   ,
   output wire [FIFO_AW-1:0]           dma_qty_o   ,
   output wire                         dma_empty_o ,
   output wire [SMP_DW - 1:0]          dt_o        ,
   output wire                         full_o      ,
   output wire [15:0]                  debug_do
   );

reg  [FIFO_AW-1:0]         rd_dma_ptr   , wr_ptr;
wire [FIFO_AW-1:0]         rd_dma_ptr_p1, wr_ptr_p1 ;
reg  [FIFO_AW-1:0]         dma_qty;
wire                       dma_empty, dma_full;
wire [SMP_DW - 1:0]        mem_dt;
wire                       do_dma_pop;
reg                        do_dma_pop_r ;
wire [SMP_CK*SMP_DW-1:0]   wr_smp_data ;
reg  [SMP_CK*SMP_DW-1:0]   wr_dt_r ;
wire [SMP_DW-1:0]          wr_dt ;
wire [3:0]                 wr_cnt_p1 ;
reg  [3:0]                 wr_cnt ;
reg                        wr_push;
reg                        wr_smp_pop, wr_smp_push;
wire                       wr_smp_empty, wr_smp_full ;
wire                       wr_last_dt ;
wire                       push_wr_rstn ;

// fifo_async has no flush_i: pulsing the write-side reset reproduces the
// legacy `rst = ~wr_rst_ni | flush_i` (same technique tag_fifo_dc uses).
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
   .B          ( SMP_CK*SMP_DW ),
   .N          ( 256           ),
   .READ_MODE  ( "fwft"        )
) wr_smp_fifo (
   .wr_rstn     ( push_wr_rstn ),
   .wr_clk      ( adc_clk_i    ),
   .wr_en       ( adc_push_i   ),
   .din         ( adc_data_i   ),
   .full        ( wr_smp_full  ),
   .wr_err      (              ),
   .rd_rstn     ( dma_rst_ni   ),
   .rd_clk      ( dma_clk_i    ),
   .rd_en       ( wr_smp_pop   ),
   .dout        ( wr_smp_data  ),
   .empty       ( wr_smp_empty ),
   .data_valid  (              ));

typedef enum { WR_IDLE, WR_PUSH_DT, WR_POP_DT } wr_st_e ;
(* fsm_encoding = "sequential" *) wr_st_e smp_wr_st;
wr_st_e smp_wr_st_nxt;

always_ff @ (posedge dma_clk_i) begin
   if      ( !dma_rst_ni )  smp_wr_st  <= WR_IDLE;
   else                     smp_wr_st  <= smp_wr_st_nxt;
end

always_comb begin
   smp_wr_st_nxt  = smp_wr_st;
   wr_smp_pop     = 1'b0;
   wr_smp_push    = 1'b0;
   unique case (smp_wr_st)
      WR_IDLE   :  begin
         if ( !wr_smp_empty )
               smp_wr_st_nxt = WR_POP_DT;
      end
      WR_POP_DT   :  begin
         wr_smp_pop = 1'b1;
         smp_wr_st_nxt = WR_PUSH_DT;
      end
      WR_PUSH_DT   :  begin
         wr_smp_push = 1'b1;
         if ( wr_last_dt | flush_dma ) begin
            wr_smp_push = 1'b0;
            smp_wr_st_nxt = WR_IDLE;
         end
      end
   endcase
end

assign wr_cnt_p1  = wr_cnt + 1'b1;
assign wr_last_dt = (wr_cnt_p1 == SMP_CK) ;


always_ff @(posedge dma_clk_i, negedge dma_rst_ni) begin
   if (!dma_rst_ni ) begin
      wr_push      <= 1'b0;
      wr_dt_r      <= 0;
      wr_cnt       <= 0;
   end else  begin
      // Register DT
      if      ( wr_smp_pop  ) wr_dt_r  <= wr_smp_data;
      // Increment Counter
      if      ( wr_push     ) wr_cnt   <= wr_cnt_p1;
      else                    wr_cnt   <= 0;
      // Push to OUT FIFO
      if      ( flush_dma     ) wr_push  <= 1'b0;
      else if ( wr_smp_push ) wr_push  <= 1'b1;
      else                    wr_push  <= 1'b0;
   end
end

assign wr_dt      = wr_dt_r[SMP_DW*wr_cnt +: SMP_DW];


///////////////////////////////////////////////////////////////////////////
// READ
///////////////////////////////////////////////////////////////////////////
assign do_dma_pop  = (dma_pop_i & !dma_empty ) | (wr_push & dma_full) ; // POP IF FULL
assign dma_empty   = (rd_dma_ptr == wr_ptr) ;
assign dma_full    = (rd_dma_ptr == wr_ptr_p1) ;

// DMA Data QTY
always_ff @(posedge dma_clk_i) begin
   if      ( !dma_rst_ni |  flush_dma    ) dma_qty <= 0;
   else if (  wr_push    & !do_dma_pop ) dma_qty <= dma_qty + 1'b1 ;
   else if ( !wr_push    &  do_dma_pop ) dma_qty <= dma_qty - 1'b1 ;
end


///////////////////////////////////////////////////////////////////////////
// POINTERS
///////////////////////////////////////////////////////////////////////////
assign wr_ptr_p1      = wr_ptr      + 1'b1 ;
assign rd_dma_ptr_p1  = rd_dma_ptr  + 1'b1 ;

always_ff @(posedge dma_clk_i, negedge dma_rst_ni) begin
   if (!dma_rst_ni) begin
      wr_ptr      <= 0;
      rd_dma_ptr  <= 0;
   end else if (flush_dma) begin
      wr_ptr      <= 0;
      rd_dma_ptr  <= 0;
   end else  begin
      if ( wr_push     ) wr_ptr      <= wr_ptr_p1;
      if ( do_dma_pop  ) rd_dma_ptr  <= rd_dma_ptr_p1;
   end
end

bram_simple_dp # (
   .B  ( SMP_DW  ) ,
   .N  ( FIFO_AW )
) smp_fifo (
   .clk     ( dma_clk_i  ),
   .ena     ( 1'b1       ),
   .enb     ( 1'b1       ),
   .wea     ( wr_push    ),
   .addra   ( wr_ptr     ),
   .dia     ( wr_dt      ),
   .addrb   ( rd_dma_ptr ),
   .dob     ( mem_dt     ));

// OUT
///////////////////////////////////////////////////////////////////////////
always_ff @(posedge dma_clk_i) begin
   if (!dma_rst_ni) begin
      do_dma_pop_r   <= 0;
   end else begin
      do_dma_pop_r   <= do_dma_pop;
   end
end

// Not consumed by any legacy caller (see tag_fifo_dc) - kept for parity.
assign flush_o      =  flush_i ;
assign full_o       =  dma_full;

assign dma_qty_o     = dma_qty;
assign dma_empty_o   = dma_empty; // While RESETTING, Shows EMPTY
assign dma_pop_o     = do_dma_pop_r;
assign dt_o          = mem_dt;

// DEBUG
///////////////////////////////////////////////////////////////////////////
assign debug_do = 0;

endmodule
