///////////////////////////////////////////////////////////////////////////////
//  FERMI RESEARCH LAB
///////////////////////////////////////////////////////////////////////////////
//  tag_mem
//  Faithful port from qick_time_tagger's tag_mem.sv (top-level module).
//  Composes one qick:mem:tag_fifo_tc for tag channel 0 (the only channel
//  the tProc can pop from directly) and up to three qick:mem:tag_fifo_dc
//  for channels 1-3 (DMA-only), all sharing one dma_sel_i-driven DMA read
//  mux. Channels at or beyond MEM_QTY are tied off.
///////////////////////////////////////////////////////////////////////////////

module tag_mem # (
   parameter int MEM_QTY      = 1  , // Amount of Memories
   parameter int TAG_FIFO_AW  = 20 , // Size of TAG FIFO Memory
   parameter int DEBUG        = 0
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
wire  [31:0] mem_dt [MEM_QTY];
wire  [MEM_QTY-1:0] empty, full;

assign dma_pop_req[0] = dma_pop_i & (dma_sel_i == 2'b00);
tag_fifo_tc # (
   .TAG_DW        ( 32           ) ,
   .FIFO_AW       ( TAG_FIFO_AW  )
) mem0 (
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
   .tag_pop_i     ( qtt_pop_req_i   ) ,
   .c_pop_o       ( qtt_pop_ack_o   ) ,
   .c_qty_o       ( proc_qty_o      ) ,
   .c_empty_o     (                 ) ,
   .dma_pop_i     ( dma_pop_req [0] ) ,
   .dma_pop_o     ( dma_pop_ack [0] ) ,
   .dma_qty_o     ( dma_qty_o   [0] ) ,
   .dt_o          ( mem_dt      [0] ) ,
   .dma_empty_o   ( empty [0]       ) ,
   .full_o        ( full [0]        ) ,
   .debug_do      (                 )
);

generate
   for (genvar ind=1; ind<4; ind++) begin: gen_tag
      if (ind < MEM_QTY ) begin : gen_mem_used
         assign dma_pop_req[ind] = dma_pop_i & (dma_sel_i == ind[1:0]);
         tag_fifo_dc # (
            .FIFO_AW     ( TAG_FIFO_AW )
         ) mem (
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
      end else begin : gen_mem_unused
         assign dma_qty_o[ind] = 0;
      end
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
