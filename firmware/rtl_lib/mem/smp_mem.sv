///////////////////////////////////////////////////////////////////////////////
//  FERMI RESEARCH LAB
///////////////////////////////////////////////////////////////////////////////
//  smp_mem
//  Faithful port from qick_time_tagger's smp_mem.sv (top-level module).
//  On a trigger (tag_wr_i), captures cfg_smp_wr_qty_i consecutive
//  SMP_CK-wide ADC sample groups (3-cycle pipeline delay to line up with
//  the trigger, matching the legacy source) and hands each group to
//  qick:mem:smp_fifo_dc as one adc_clk-side burst push. dma_dt_o
//  sign-extends smp_fifo_dc's SMP_DW-wide sample to 32 bits.
///////////////////////////////////////////////////////////////////////////////

module smp_mem # (
   parameter int SMP_DW       = 16 , // Samples WIDTH
   parameter int SMP_CK       = 8  , // Samples per Clock
   parameter int SMP_FIFO_AW  = 10   // Size of SAMPLES FIFO Memory
) (
// Core and AXI CLK & RST
   input  wire                      dma_clk_i         ,
   input  wire                      dma_rst_ni        ,
   input  wire                      adc_clk_i         ,
   input  wire                      adc_rst_ni        ,
   input  wire                      qtt_rst_req_i     , //flush_i
   output wire                      qtt_rst_ack_o     , //flush_o
// Configuration
   input  wire [4:0]                cfg_smp_wr_qty_i  ,
///// ADC TRIG
   input  wire                      tag_wr_i          ,
   input  wire [SMP_CK*SMP_DW-1:0]  adc_dt_i          ,
///// DATA DMA
   input  wire                      dma_pop_i         ,
   output wire                      dma_pop_o         ,
   output wire [31:0]               dma_dt_o          ,
   output wire [SMP_FIFO_AW-1:0]    dma_qty_o         ,
   output wire                      smp_empty_o       ,
   output wire                      smp_full_o        ,
///// STATUS & DEBUG
   output wire [7:0]                debug_do
);

//////////////////////////////////////////////////////////////////////////
// SMP STORE
//////////////////////////////////////////////////////////////////////////
wire [SMP_DW-1:0] smp_fifo_dt;

   reg [SMP_CK*SMP_DW-1:0]  smp_wr_dt, smp_wr_dt_r, smp_wr_dt_2r, smp_wr_dt_3r ;
   reg [4:0] smp_wr_cnt ;
   wire[4:0] smp_wr_cnt_p1 ;
      // Control State Machine
      //////////////////////////////////////////////////////////////////////////
      typedef enum { ST_SMP_IDLE, ST_SMP_WR } smp_wr_st_e;
      (* fsm_encoding = "one_hot" *) smp_wr_st_e smp_wr_st;
      smp_wr_st_e smp_wr_st_nxt;

      always_ff @ (posedge adc_clk_i, negedge adc_rst_ni) begin
         if    ( !adc_rst_ni   )  smp_wr_st  <= ST_SMP_IDLE;
         else                 smp_wr_st  <= smp_wr_st_nxt;
      end
      reg smp_wr;
      wire smp_wr_end;
      always_comb begin
         smp_wr_st_nxt  = smp_wr_st;
         smp_wr           = 1'b0;
         unique case (smp_wr_st)
            ST_SMP_IDLE: begin
               if (tag_wr_i) smp_wr_st_nxt = ST_SMP_WR;
            end
            ST_SMP_WR : begin
               smp_wr           = 1'b1;
               if (smp_wr_end) smp_wr_st_nxt = ST_SMP_IDLE;
            end
         endcase
      end
      // Number of Samples to Store
      //////////////////////////////////////////////////////////////////////////
      always_ff @(posedge adc_clk_i) begin
         if    (!adc_rst_ni) smp_wr_cnt <= 0;
         else
            if (smp_wr)  smp_wr_cnt <= smp_wr_cnt_p1;
            else         smp_wr_cnt <= 0;
      end
      assign smp_wr_cnt_p1 = smp_wr_cnt + 1'b1;
      assign smp_wr_end    = ( smp_wr_cnt_p1 == cfg_smp_wr_qty_i ) ;

      always_ff @(posedge adc_clk_i) begin
         if      ( !adc_rst_ni) begin
            smp_wr_dt   <= 0;
            smp_wr_dt_r <= 0;
         end else begin
            smp_wr_dt   <= adc_dt_i;
            smp_wr_dt_r <= smp_wr_dt;
            smp_wr_dt_2r <= smp_wr_dt_r;
            smp_wr_dt_3r <= smp_wr_dt_2r;

         end
      end
      smp_fifo_dc  # (
         .SMP_CK    ( SMP_CK      ), // Number of Samples in adc_data (MAX 16)
         .SMP_DW    ( SMP_DW      ), // Sample Data Width
         .FIFO_AW   ( SMP_FIFO_AW )  // Memory bit address Width
      ) smp_fifo_dc_i (
         .adc_clk_i   ( adc_clk_i ),
         .adc_rst_ni  ( adc_rst_ni ),
         .dma_clk_i   ( dma_clk_i ),
         .dma_rst_ni  ( dma_rst_ni ),
         .flush_i     ( qtt_rst_req_i ),
         .flush_o     ( qtt_rst_ack_o ),
         .adc_push_i  ( smp_wr   ),
         .adc_data_i  ( smp_wr_dt_3r   ),
         .dma_pop_i   ( dma_pop_i ),
         .dma_pop_o   ( dma_pop_o ),
         .dma_qty_o   ( dma_qty_o ),
         .dma_empty_o ( smp_empty_o ),
         .dt_o        ( smp_fifo_dt ),
         .full_o      ( smp_full_o ),
         .debug_do    (  ));


// DEBUG
///////////////////////////////////////////////////////////////////////////////
assign debug_do = 0;


// OUT
///////////////////////////////////////////////////////////////////////////////
localparam int SFP = 32-SMP_DW;
assign  dma_dt_o  = {{ SFP {smp_fifo_dt[SMP_DW-1]}}, smp_fifo_dt};

endmodule
