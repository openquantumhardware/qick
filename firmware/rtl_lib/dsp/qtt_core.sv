///////////////////////////////////////////////////////////////////////////////
//  FERMI RESEARCH LAB
///////////////////////////////////////////////////////////////////////////////
//  qtt_core
//  Faithful port from qick_time_tagger's qick_time_tagger.sv (top-level
//  non-AXI composition, Tier 2). Control FSM + time counter + wiring for
//  qick:dsp:tag_gen + qick:mem:tag_mem + qick:mem:dma_fifo_rd +
//  qick:mem:smp_mem (generate-guarded by SMP_STORE) + qick:mem:tag_fifo_dc
//  (generate-guarded ARM_MEM, by ARM_STORE).
//
//  Named `qtt_core` (fusesoc core qick:dsp:qtt_core), not `qick_time_tagger`
//  like the legacy source: the packaged IP (Tier 3, qick:ip:qick_time_tagger)
//  already owns that exact name, and fusesoc VLNVs must be unique -- module,
//  file, and core name are kept in sync here rather than adding a lint
//  waiver (see the module/file-naming convention in this repo).
//
//  Reuse decisions: `sync_reg` -> qick:cdc:cdc_reg_sync (as in Tier 1).
//  `pulse_cdc` -> qick:cdc:cdc_handshake with a dummy 1-bit payload
//  (DW=1): this is a **correction** to the Tier 0 conclusion that
//  `pulse_cdc` was dead code -- that was true everywhere it was checked
//  (_qtt_mem.sv's commented-out alternates) except here, where
//  `tag_vld_sync` is a real, live instance. cdc_handshake's `i_valid`/
//  `o_valid` give the same single-pulse CDC semantics as `pulse_cdc`'s
//  `pulse_a_i`/`pulse_b_o` (its `rdy_a_o` == cdc_handshake's `!o_busy`,
//  unused by the original caller here either way).
///////////////////////////////////////////////////////////////////////////////

module qtt_core # (
   parameter int ADC_QTY      = 4  , // Number of ADC Inputs
   parameter int CMP_SLOPE    = 1  , // Compare with SLOPE
   parameter int CMP_INTER    = 4  , // Max Number of Interpolation bits
   parameter int ARM_STORE    = 1  , // Store NUmber of Triggers on each ARM
   parameter int SMP_STORE    = 1  , // Store Sample Values
   parameter int TAG_FIFO_AW  = 19 , // Size of TAG FIFO Memory
   parameter int ARM_FIFO_AW  = 10 , // Size of ARM FIFO Memory
   parameter int SMP_FIFO_AW  = 10 , // Size of SAMPLE FIFO Memory
   parameter int SMP_DW       = 19 , // Samples WIDTH
   parameter int SMP_CK       = 8  , // Samples per Clock
   parameter int DEBUG        = 1
) (
// Core and AXI CLK & RST
   input  wire                      ps_clk_i             ,
   input  wire                      ps_rst_ni            ,
   input  wire                      c_clk_i              ,
   input  wire                      c_rst_ni             ,
   input  wire                      adc_clk_i            ,
   input  wire                      adc_rst_ni           ,
   input  wire                      qtt_pop_req_i        ,
   input  wire                      qtt_rst_req_i        , // reset from qtt_cmd, on ADC clock
   output wire                      qtt_rst_ack_o        ,
   input  wire                      cfg_invert_i         ,
   input  wire                      cfg_filter_i         ,
   input  wire                      cfg_slope_i          ,
   input  wire [2:0]                cfg_inter_i          ,
   input  wire [4:0]                cfg_smp_wr_qty_i     ,
   input  wire                      arm_i                , // Arm Trigger (ONE works)
   input  wire [SMP_DW-1:0]         cmp_th_i             , // Threhold Data
   input  wire [7:0]                cmp_inh_i            , // Inhibit Clock Pulses
   input  wire [SMP_CK*SMP_DW-1:0]  adc_dt_i[ADC_QTY]    ,
///// DATA DMA
   input  wire                      dma_req_i            ,
   input  wire [2:0]                dma_mem_sel_i        ,
   input  wire [19:0]               dma_len_i            ,
   output wire                      dma_ack_o            ,
   input  wire                      dma_m_axis_tready_i  ,
   output wire                      dma_m_axis_tvalid_o  ,
   output wire [31:0]               dma_m_axis_tdata_o   ,
   output wire                      dma_m_axis_tlast_o   ,
///// DATA PROC
   output wire [31:0]               tag_dt_o             ,
   output wire                      tag_vld_o            ,
   output wire                      trig_o               ,
   output wire                      cmp_o                ,

///// DATA OUT
   output wire [TAG_FIFO_AW-1:0]    proc_qty_o           ,
   output wire [TAG_FIFO_AW-1:0]    dma_qty_o   [4]      ,
   output wire [SMP_FIFO_AW-1:0]    smp_qty_o            ,
   output wire [ARM_FIFO_AW-1:0]    arm_qty_o            ,
///// STATUS & DEBUG
   output wire [31:0]               qtt_debug_o          ,
   output wire [23:0]               qtt_reg_status_o     ,
   output wire [31:0]               qtt_reg_debug_o
   );

// Signal Declaration
//////////////////////////////////////////////////////////////////////////
wire [15:0]    dma_ds;
wire [25:0]    dma_reg_ds;

wire [31:0]    tag_fifo_dt, arm_fifo_dt, smp_fifo_dt;
wire           tag_dma_pop_req, tag_dma_pop_ack ;
wire           arm_dma_pop_req, arm_dma_pop_ack ;
wire           smp_dma_pop_req, smp_dma_pop_ack ;

wire [ADC_QTY-1:0]   tag_vld_s ;
wire [31:0]          tag_dt_s [ADC_QTY];

wire trig_event;
wire [TAG_FIFO_AW-1:0] dma_qty_s [4];

wire arm_s ;
wire tag_mem_sel, arm_mem_sel, smp_mem_sel ;
wire dma_pop_req, dma_pop_ack ;
wire cmp_s ;
wire qtt_pop_ack ;
wire tadg_vld ;
wire tag_empty_o, tag_full_o ;
wire [31:0] tag_debug_o ;
wire smp_empty, smp_full ;
wire [7:0] smp_debug ;
wire arm_empty, arm_full ;

// Synchronize Input Signals
//////////////////////////////////////////////////////////////////////////

cdc_reg_sync # (
   .DW ( 1 )
) sync_arm (
   .dt_i      ( arm_i      ),
   .clk_i     ( adc_clk_i  ),
   .rst_ni    ( adc_rst_ni ),
   .dt_o      ( arm_s      )
);

// Control State Machine
//////////////////////////////////////////////////////////////////////////
typedef enum { ST_RST, ST_IDLE, ST_ARMED } trig_st_e;
(* fsm_encoding = "one_hot" *) trig_st_e time_trig_st;
trig_st_e time_trig_st_nxt;

always_ff @ (posedge adc_clk_i, negedge adc_rst_ni) begin
   if    ( !adc_rst_ni   )  time_trig_st  <= ST_IDLE;
   else                 time_trig_st  <= time_trig_st_nxt;
end

// Reset sequence. A reset request (from qtt_cmd, held until it is acknowledged) is honoured from IDLE and from
// ARMED (legacy: only from IDLE, so a reset issued while armed was never acknowledged and the memories stayed
// in flush, dropping every tag until the tagger was disarmed). In ST_RST the memories are flushed for
// RST_FLUSH_CK ADC clocks (a level long enough for the flush to be synchronised into the slower DMA clock and
// for the async FIFOs to complete their reset; legacy: the raw request, about 3 clocks, sampled unsynchronised
// by the DMA clock, which could miss it), then left alone for RST_SETTLE_CK clocks while the DMA-side flush
// deasserts, and only then acknowledged. The tagger is not tagging in ST_RST; if it was armed it re-arms
// by itself when the reset is over.
localparam int RST_FLUSH_CK  = 32;
localparam int RST_SETTLE_CK = 32;
localparam int RST_TOTAL_CK  = RST_FLUSH_CK + RST_SETTLE_CK;

reg tag_gen_en, qtt_rst, qtt_flush;
reg [7:0] rst_cnt;
always_ff @(posedge adc_clk_i) begin
   if      ( !adc_rst_ni || time_trig_st != ST_RST ) rst_cnt <= 0;
   else if ( rst_cnt != RST_TOTAL_CK )               rst_cnt <= rst_cnt + 1'b1;
end

always_comb begin
   time_trig_st_nxt  = time_trig_st;
   tag_gen_en        = 1'b0;
   qtt_rst           = 1'b0;
   qtt_flush         = 1'b0;
   unique case (time_trig_st)
      ST_RST: begin
         qtt_flush = ( rst_cnt <  RST_FLUSH_CK );
         qtt_rst   = ( rst_cnt == RST_TOTAL_CK );
         if ( !qtt_rst_req_i ) time_trig_st_nxt = ST_IDLE;
      end
      ST_IDLE: begin
         if      ( qtt_rst_req_i )  time_trig_st_nxt = ST_RST;
         else if ( arm_s )          time_trig_st_nxt = ST_ARMED;
      end
      ST_ARMED: begin
         tag_gen_en        = 1'b1;
         if      ( qtt_rst_req_i ) time_trig_st_nxt = ST_RST;
         else if (!arm_s)          time_trig_st_nxt = ST_IDLE;
      end
   endcase
end

// Time Counter
//////////////////////////////////////////////////////////////////////////
reg [28:0] time_cnt;
always_ff @(posedge adc_clk_i) begin
   if    (!adc_rst_ni) time_cnt <= 0;
   else
      if (tag_gen_en) time_cnt <= time_cnt + 1'b1;
      else            time_cnt <= 0;
end

assign tag_mem_sel = (dma_mem_sel_i[2] == 1'b0);
assign arm_mem_sel = (dma_mem_sel_i    == 3'b100);
assign smp_mem_sel = (dma_mem_sel_i    == 3'b101);

assign tag_dma_pop_req = dma_pop_req & tag_mem_sel ;
assign arm_dma_pop_req = dma_pop_req & arm_mem_sel ;
assign smp_dma_pop_req = dma_pop_req & smp_mem_sel ;

assign dma_pop_ack = tag_mem_sel & tag_dma_pop_ack | arm_mem_sel & arm_dma_pop_ack | smp_mem_sel & smp_dma_pop_ack ;

reg [31:0] dma_fifo_dt ;
always_comb
   unique case (dma_mem_sel_i)
      3'b000:  dma_fifo_dt = tag_fifo_dt; // tag0_dt
      3'b001:  dma_fifo_dt = tag_fifo_dt; // tag1_dt
      3'b010:  dma_fifo_dt = tag_fifo_dt; // tag2_dt
      3'b011:  dma_fifo_dt = tag_fifo_dt; // tag3_dt
      3'b100:  dma_fifo_dt = arm_fifo_dt;
      3'b101:  dma_fifo_dt = smp_fifo_dt;
      default: dma_fifo_dt = tag_fifo_dt;
   endcase

// Instances
//////////////////////////////////////////////////////////////////////////
tag_gen  #(
   .ADC_QTY          ( ADC_QTY         ),
   .CMP_SLOPE        ( CMP_SLOPE       ),
   .CMP_INTER        ( CMP_INTER       ),
   .SMP_DW           ( SMP_DW          ),
   .SMP_CK           ( SMP_CK          )
) tag_gen_i (
   .clk_i            ( adc_clk_i       ),
   .rst_ni           ( adc_rst_ni      ),
   .cfg_invert_i     ( cfg_invert_i    ),
   .cfg_filter_i     ( cfg_filter_i    ),
   .cfg_slope_i      ( cfg_slope_i     ),
   .cfg_inter_i      ( cfg_inter_i     ),
   .time_ck_i        ( time_cnt        ),
   .cmp_th_i         ( cmp_th_i        ),
   .cmp_inh_i        ( cmp_inh_i       ),
   .en_i             ( tag_gen_en      ),
   .adc_dt_i         ( adc_dt_i        ),
   .trig_o           ( trig_event      ),
   .cmp_o            ( cmp_s ) ,
   .tag_vld_o        ( tag_vld_s       ),
   .tag_dt_o         ( tag_dt_s        )
);

tag_mem # (
   .MEM_QTY        ( ADC_QTY           ), // Amount of Memories
   .TAG_FIFO_AW    ( TAG_FIFO_AW       ), // Size of TAG FIFO Memory
   .DEBUG          ( DEBUG             )
) tag_mem_i (
   .dma_clk_i      ( ps_clk_i          ),
   .dma_rst_ni     ( ps_rst_ni         ),
   .c_clk_i        ( c_clk_i           ),
   .c_rst_ni       ( c_rst_ni          ),
   .adc_clk_i      ( adc_clk_i         ),
   .adc_rst_ni     ( adc_rst_ni        ),
   .qtt_pop_req_i  ( qtt_pop_req_i     ),
   .qtt_pop_ack_o  ( qtt_pop_ack       ),
   .qtt_rst_req_i  ( qtt_flush         ),
   .qtt_rst_ack_o  (      ),
   .tag_wr_i       ( tag_vld_s         ),
   .tag_dt_i       ( tag_dt_s          ),
   .dma_qty_o      ( dma_qty_o         ),
   .proc_qty_o     ( proc_qty_o        ),
   .empty_o        ( tag_empty_o       ),
   .full_o         ( tag_full_o        ),
   .dma_sel_i      ( dma_mem_sel_i[1:0]),
   .dma_pop_i      ( tag_dma_pop_req   ),
   .dma_pop_o      ( tag_dma_pop_ack   ),
   .dma_dt_o       ( tag_fifo_dt       ),
   .debug_do       ( tag_debug_o       )
);

dma_fifo_rd # (
   .MEM_AW           ( 20 ),  // Memory Address Width
   .MEM_DW           ( 32          ),  // Memory Data Width
   .DMA_DW           ( 32          )   // DMA   Data Width
) dma_i (
   .clk_i            ( ps_clk_i              ),
   .rst_ni           ( ps_rst_ni             ),
   .dma_req_i        ( dma_req_i             ),
   .dma_ack_o        ( dma_ack_o             ),
   .dma_len_i        ( dma_len_i             ),
   .pop_req_o        ( dma_pop_req           ),
   .pop_ack_i        ( dma_pop_ack           ),
   .fifo_dt_i        ( dma_fifo_dt           ),
   .m_axis_tready_i  ( dma_m_axis_tready_i   ),
   .m_axis_tdata_o   ( dma_m_axis_tdata_o    ),
   .m_axis_tvalid_o  ( dma_m_axis_tvalid_o   ),
   .m_axis_tlast_o   ( dma_m_axis_tlast_o    ),
   .dma_do           ( dma_ds                ),
   .dma_reg_do       ( dma_reg_ds            )
);

generate
   if (SMP_STORE == 1 )  begin: gen_smp
      smp_mem # (
         .SMP_DW            ( SMP_DW   ) , // Samples WIDTH
         .SMP_CK            ( SMP_CK   ) , // Samples per Clock
         .SMP_FIFO_AW       ( SMP_FIFO_AW )   // Size of SAMPLES FIFO Memory
      ) smp_mem_i (
      // Core and AXI CLK & RST
         .dma_clk_i         ( ps_clk_i          ) ,
         .dma_rst_ni        ( ps_rst_ni         ) ,
         .adc_clk_i         ( adc_clk_i         ) ,
         .adc_rst_ni        ( adc_rst_ni        ) ,
         .qtt_rst_req_i     ( qtt_flush         ) ,
         .qtt_rst_ack_o     (                   ) ,
         .cfg_smp_wr_qty_i  ( cfg_smp_wr_qty_i  ) ,
         .tag_wr_i          ( trig_event        ) ,
         .adc_dt_i          ( adc_dt_i[0]       ) ,
         .dma_pop_i         ( smp_dma_pop_req   ) ,
         .dma_pop_o         ( smp_dma_pop_ack   ) ,
         .dma_dt_o          ( smp_fifo_dt       ) ,
         .dma_qty_o         ( smp_qty_o         ) ,
         .smp_empty_o       ( smp_empty         ) ,
         .smp_full_o        ( smp_full          ) ,
         .debug_do          ( smp_debug         )
      );
   end else begin : gen_no_smp
      assign smp_dma_pop_ack  = 0;
      assign smp_fifo_dt      = 0;
      assign smp_qty_o        = 0;
      assign smp_empty        = 1;
      assign smp_full         = 0;
      assign smp_debug        = 0;
   end

   if (ARM_STORE ==1 )  begin: gen_arm
      wire arm_t10;
      reg arm_r;
      // ARM signal
      //////////////////////////////////////////////////////////////////////////
      always_ff @(posedge adc_clk_i) begin
         if    (!adc_rst_ni) arm_r <= 0;
         else                arm_r <= arm_s;
      end

      assign arm_t10 = arm_r & !arm_s ;

      // Trig Counter
      //////////////////////////////////////////////////////////////////////////
      reg [31:0] trig_cnt;
      always_ff @(posedge adc_clk_i) begin
         if      ( !adc_rst_ni ) trig_cnt <= 0;
         else if ( !tag_gen_en ) trig_cnt <= 0;
         else if ( trig_event  ) trig_cnt <= trig_cnt + 1'b1;
      end

      tag_fifo_dc # (
         .FIFO_AW     ( ARM_FIFO_AW )
      ) arm_mem_i (
         .dma_clk_i   ( ps_clk_i        ),
         .dma_rst_ni  ( ps_rst_ni       ),
         .adc_clk_i   ( adc_clk_i       ),
         .adc_rst_ni  ( adc_rst_ni      ),
         .flush_i     ( qtt_flush       ),
         .flush_o     (                 ),
         .adc_push_i  ( arm_t10         ),
         .adc_data_i  ( trig_cnt        ),
         .dma_pop_i   ( arm_dma_pop_req ),
         .dma_pop_o   ( arm_dma_pop_ack ),
         .dma_qty_o   ( arm_qty_o       ),
         .dma_dt_o    ( arm_fifo_dt     ),
         .empty_o     ( arm_empty       ),
         .full_o      ( arm_full        ),
         .debug_do    (   )
      );
   end else begin : gen_no_arm
        assign arm_dma_pop_ack  = 0;
        assign arm_fifo_dt      = 0;
        assign arm_qty_o        = 0;
        assign arm_empty        = 1;
        assign arm_full         = 0;
    end
endgenerate


// STATUS
///////////////////////////////////////////////////////////////////////////////
assign qtt_reg_status_o[7:0]   = time_trig_st[7:0];
assign qtt_reg_status_o[9:8]   = dma_reg_ds[25:24];
assign qtt_reg_status_o[23:10] = 0;

// DEBUG
///////////////////////////////////////////////////////////////////////////////

assign qtt_debug_o[31:16]   = dma_ds;
assign qtt_reg_debug_o[5:4] = 2'b00;
assign qtt_reg_debug_o[31:6] = dma_reg_ds;


///////////////////////////////////////////////////////////////////////////////
// OUT SIGNALS
///////////////////////////////////////////////////////////////////////////////
cdc_handshake # (
   .DW ( 1 ),
   .NS ( 2 )
) tag_vld_sync (
   .i_clk   ( ps_clk_i    ) ,
   .i_rstn  ( ps_rst_ni   ) ,
   .i_data  ( 1'b0        ) ,
   .i_valid ( qtt_pop_ack ) ,
   .o_busy  (             ) ,
   .o_clk   ( c_clk_i     ) ,
   .o_rstn  ( c_rst_ni    ) ,
   .o_data  (             ) ,
   .o_valid ( tadg_vld    )
);

reg [31:0] tag_dt_r;
always_ff @(posedge c_clk_i) begin
   if      ( !c_rst_ni  )    tag_dt_r <= 0;
   else if ( qtt_pop_ack )    tag_dt_r <= tag_fifo_dt;
end

assign    qtt_rst_ack_o = qtt_rst;


assign tag_dt_o  = tag_dt_r;
assign tag_vld_o = tadg_vld;
assign trig_o    = trig_event;
assign cmp_o     = cmp_s;

endmodule
