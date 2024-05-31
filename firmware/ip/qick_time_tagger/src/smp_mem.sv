///////////////////////////////////////////////////////////////////////////////
//  FERMI RESEARCH LAB
///////////////////////////////////////////////////////////////////////////////
//  Author         : Martin Di Federico
//  Date           : 2024_5_31
///////////////////////////////////////////////////////////////////////////////

module smp_mem # (
   parameter SMP_DW       = 16 , // Samples WIDTH
   parameter SMP_CK       = 8  , // Samples per Clock
   parameter SMP_FIFO_AW  = 10   // Size of SAMPLES FIFO Memory
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

   reg [SMP_CK*SMP_DW-1:0]  smp_wr_dt, smp_wr_dt_r, smp_wr_dt_2r, smp_wr_dt_3r   ; 
   reg [4:0] smp_wr_cnt ;
   wire[4:0] smp_wr_cnt_p1 ;
      // Control State Machine
      //////////////////////////////////////////////////////////////////////////
      typedef enum { ST_SMP_IDLE, ST_SMP_WR } TYPE_SMP_WR_ST;
      (* fsm_encoding = "one_hot" *) TYPE_SMP_WR_ST smp_wr_st;
      TYPE_SMP_WR_ST smp_wr_st_nxt;

      always_ff @ (posedge adc_clk_i, negedge adc_rst_ni) begin
         if    ( !adc_rst_ni   )  smp_wr_st  <= ST_SMP_IDLE;
         else                 smp_wr_st  <= smp_wr_st_nxt;
      end
      reg smp_wr;
      always_comb begin
         smp_wr_st_nxt  = smp_wr_st;
         smp_wr           = 1'b0;
         case (smp_wr_st)
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
      SMP_FIFO_DC  # (
         .SMP_CK    ( SMP_CK      ), // Number of Samples in adc_data (MAX 16)
         .SMP_DW    ( SMP_DW      ), // Sample Data Width
         .FIFO_AW   ( SMP_FIFO_AW )  // Memory bit address Width
      ) SMP_FIFO_DC ( 
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
localparam sfp = 32-SMP_DW;
assign  dma_dt_o  = {{ sfp {smp_fifo_dt[SMP_DW-1]}}, smp_fifo_dt}; 

endmodule

///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////

module SMP_FIFO_DC # (
   parameter SMP_CK  = 8  , // Number of Samples in adc_data (MAX 16)
   parameter SMP_DW   = 16 , // Sample Data Width
   parameter FIFO_AW   = 10   // Memory bit address Width
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

///////////////////////////////////////////////////////////////////////////////
// Signal Declaration

// The WRITE_POINTER is on the Last Empty Value
// The READ_POINTER is on the Last Value

reg  [FIFO_AW-1:0]         rd_dma_ptr   , wr_ptr;
wire [FIFO_AW-1:0]         rd_dma_ptr_p1, wr_ptr_p1 ;
reg  [FIFO_AW-1:0]         dma_qty;
wire [FIFO_AW-1:0]         addr_b ;
wire                       dma_empty, dma_full;
wire [SMP_DW - 1:0]        data_s, mem_dt;
wire                       do_dma_pop;
reg                        do_dma_pop_r ;
wire [SMP_CK*SMP_DW-1:0]   wr_smp_data ;
reg  [SMP_CK*SMP_DW-1:0]   wr_dt_r ;
wire [SMP_DW-1:0]          wr_dt ;
wire [SMP_DW-1:0]          wr_dt1, wr_dt2, wr_dt3 ;
wire [3:0]                 wr_cnt_p1 ;
reg  [3:0]                 wr_cnt ;
reg                        wr_push;
reg                        wr_smp_pop, wr_smp_push;

///////////////////////////////////////////////////////////////////////////////
// WRITE SAMPLE FIFO
///////////////////////////////////////////////////////////////////////////////
FIFO_DC # (
   .FIFO_DW ( SMP_CK*SMP_DW ),
   .FIFO_AW ( 8 )
) WR_SMP_FIFO ( 
   .wr_clk_i       ( adc_clk_i   ),
   .wr_rst_ni      ( adc_rst_ni  ),
   .wr_en_i        ( 1'b1        ),
   .push_i         ( adc_push_i  ),
   .data_i         ( adc_data_i  ),
   .rd_clk_i       ( dma_clk_i   ),
   .rd_rst_ni      ( dma_rst_ni  ),
   .rd_en_i        ( 1'b1        ),
   .pop_i          ( wr_smp_pop  ),
   .data_o         ( wr_smp_data ),
   .flush_i        ( flush_i     ),
   .async_empty_o  ( wr_smp_empty),
   .async_full_o   ( wr_smp_full )
);



///////////////////////////////////////////////////////////////////////////////
// WRITE Control state
typedef enum { WR_IDLE, WR_PUSH_DT, WR_POP_DT } TYPE_WR_ST ;
(* fsm_encoding = "sequential" *) TYPE_WR_ST smp_wr_st;
TYPE_WR_ST smp_wr_st_nxt;

always_ff @ (posedge dma_clk_i) begin
   if      ( !dma_rst_ni )  smp_wr_st  <= WR_IDLE;
   else                     smp_wr_st  <= smp_wr_st_nxt;
end

always_comb begin
   smp_wr_st_nxt  = smp_wr_st; // Default Current
   wr_smp_pop     = 1'b0;
   wr_smp_push    = 1'b0;
   case (smp_wr_st)
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
         if ( wr_last_dt | flush_i ) begin 
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
      if      ( flush_i     ) wr_push  <= 1'b0;
      else if ( wr_smp_push ) wr_push  <= 1'b1;
      else                    wr_push  <= 1'b0;
   end
end

assign wr_dt      = wr_dt_r[SMP_DW*wr_cnt +: SMP_DW];





///////////////////////////////////////////////////////////////////////////////
// READ
///////////////////////////////////////////////////////////////////////////////
assign do_dma_pop  = (dma_pop_i & !dma_empty ) | (wr_push & dma_full) ; // POP IF FULL
assign dma_empty   = (rd_dma_ptr == wr_ptr) ;   
assign dma_full    = (rd_dma_ptr == wr_ptr_p1) ;

// DMA Data QTY
always_ff @(posedge dma_clk_i) begin
   if      ( !dma_rst_ni )            dma_qty <= 0;
   else if (  wr_push & !do_dma_pop ) dma_qty <= dma_qty + 1'b1 ;
   else if ( !wr_push &  do_dma_pop ) dma_qty <= dma_qty - 1'b1 ;
end


///////////////////////////////////////////////////////////////////////////////
// POINTERS
///////////////////////////////////////////////////////////////////////////////
assign wr_ptr_p1      = wr_ptr      + 1'b1 ;
assign rd_dma_ptr_p1  = rd_dma_ptr  + 1'b1 ;

always_ff @(posedge dma_clk_i, negedge dma_rst_ni) begin
   if (!dma_rst_ni) begin
      wr_ptr      <= 0;
      rd_dma_ptr  <= 0;
   end else if (flush_i) begin
      wr_ptr      <= 0;
      rd_dma_ptr  <= 0;
   end else  begin
      if ( wr_push     ) wr_ptr      <= wr_ptr_p1;
      if ( do_dma_pop  ) rd_dma_ptr  <= rd_dma_ptr_p1;
   end
end

BRAM_SC # ( 
   .MEM_AW  ( FIFO_AW ) , 
   .MEM_DW  ( SMP_DW ) 
) SMP_FIFO ( 
   .clk_i     ( dma_clk_i ),
   .we_a_i    ( wr_push ),
   .addr_a_i  ( wr_ptr ),
   .dt_a_i    ( wr_dt ),
   .addr_b_i  ( rd_dma_ptr ),
   .dt_b_o    ( mem_dt ));
   
// OUT
///////////////////////////////////////////////////////////////////////////////

always_ff @(posedge dma_clk_i) begin
   if (!dma_rst_ni) begin
      do_dma_pop_r   <= 0;      
   end else begin
      do_dma_pop_r   <= do_dma_pop;
   end
end

assign flush_o      =  wr_smp_empty & wr_smp_full ;
assign full_o       =  dma_full;

assign dma_qty_o     = dma_qty;
assign dma_empty_o   = dma_empty; // While RESETTING, Shows EMPTY
assign dma_pop_o     = do_dma_pop_r;
assign dt_o          = mem_dt;

endmodule
