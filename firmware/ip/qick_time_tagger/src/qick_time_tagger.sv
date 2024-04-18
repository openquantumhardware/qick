///////////////////////////////////////////////////////////////////////////////
//  FERMI RESEARCH LAB
///////////////////////////////////////////////////////////////////////////////
//  Author         : Martin Di Federico
//  Date           : 1-2024
//  Version        : 1
///////////////////////////////////////////////////////////////////////////////
//  QICK PROCESSOR :  Custom Peripheral Template
/* Description: 
    Top Level of the Peripheral Template. It includes two modules
    1) The axi_qick_peripheral core processing unit
    2) The Axi Register, used to read and write from Python.
*/
//////////////////////////////////////////////////////////////////////////////

module qick_time_tagger # (
   parameter DMA_RD       = 1  , // TAG FIFO Read from DMA
   parameter PROC_RD      = 0  , // TAG FIFO Read from tProcessor
   parameter CMP_SLOPE    = 1  , // Compare with SLOPE
   parameter CMP_INTER    = 1  , // Interpolate SAMPLES
   parameter TAG_FIFO_AW  = 20 , // Size of TAG FIFO Memory
   parameter SMP_DW       = 16 , // Samples WIDTH
   parameter SMP_CK       = 8  , // Samples per Clock
   parameter SMP_STORE    = 0  , // Store Samples Value
   parameter SMP_FIFO_AW  = 10 , // Size of SAMPLES FIFO Memory
   parameter DEBUG        = 0  
) (
// Core and AXI CLK & RST
   input  wire                      ps_clk_i   ,
   input  wire                      ps_rst_ni  ,
   input  wire                      c_clk_i   ,
   input  wire                      c_rst_ni  ,
   input  wire                      adc_clk_i ,
   input  wire                      adc_rst_ni ,
   input  wire                      qtt_pop_req_i ,
   input  wire                      qtt_rst_req_i ,
   output wire                      qtt_rst_ack_o ,
   input  wire                      cfg_filter_i      ,
   input  wire                      cfg_slope_i      ,
   input  wire [2:0]                cfg_inter_i      ,
   input  wire                      arm_i       , // Arm Trigger (ONE works)
   input  wire [SMP_DW-1:0]         cmp_th_i    , // Threhold Data
   input  wire [7:0]                cmp_inh_i   , // Inhibit Clock Pulses
   input  wire [SMP_CK*SMP_DW-1:0]  adc_dt_i      ,
///// DATA DMA
   input  wire                      dma_req_i ,
   input  wire [TAG_FIFO_AW-1:0]    dma_len_i ,
   output wire                      dma_ack_o ,
   input  wire                      dma_m_axis_tready_i ,
   output wire                      dma_m_axis_tvalid_o ,
   output wire [31:0]               dma_m_axis_tdata_o  ,
   output wire                      dma_m_axis_tlast_o  ,
///// DATA PROC
   output wire [31:0]               tag_dt_o   ,
   output wire                      tag_vld_o   ,
///// DATA OUT   
   output wire [TAG_FIFO_AW-1:0]    dma_qty_o   ,
   output wire [TAG_FIFO_AW-1:0]    proc_qty_o   ,
///// STATUS & DEBUG   
   output wire [31:0]               qtt_debug_o ,
   output wire [15:0]               qtt_reg_status_o ,
   output wire [31:0]               qtt_reg_debug_o
   );

wire[31:0] tag_fifo_dt;

wire [28:0] time_ck_s;
wire [2:0] time_adc_s;
wire [6:0] time_int_s;

// Syncronice Input Signals

sync_reg # (
   .DW ( 1 )
) sync_arm (
   .dt_i      ( arm_i ) ,
   .clk_i     ( adc_clk_i ) ,
   .rst_ni    ( adc_rst_ni ) ,
   .dt_o      ( arm_s ) );

// Control State Machine
//////////////////////////////////////////////////////////////////////////
typedef enum { ST_IDLE, ST_ARMED, ST_TRIGGER, ST_INTER, ST_INHIBIT } TYPE_TRIG_ST;
(* fsm_encoding = "one_hot" *) TYPE_TRIG_ST time_trig_st;
TYPE_TRIG_ST time_trig_st_nxt;

always_ff @ (posedge adc_clk_i, negedge adc_rst_ni) begin
   if    ( !adc_rst_ni   )  time_trig_st  <= ST_IDLE;
   else                 time_trig_st  <= time_trig_st_nxt;
end
reg tag_wr, inhibit, working, cmp_en;

always_comb begin
   time_trig_st_nxt  = time_trig_st;
   tag_wr           = 1'b0;
   inhibit           = 1'b0;
   working           = 1'b1;
   cmp_en            = 1'b0;
   case (time_trig_st)
      ST_IDLE: begin
         working           = 1'b0;
         if (arm_s) time_trig_st_nxt = ST_ARMED;
      end
      ST_ARMED: begin
         cmp_en            = 1'b1;
         if      (!arm_s)
            time_trig_st_nxt = ST_IDLE;
         else if (trig_event) begin 
            if (|cfg_inter_i )    
               time_trig_st_nxt = ST_INTER;
            else 
               time_trig_st_nxt = ST_TRIGGER;
         end
      end
      ST_INTER: begin
         inhibit           = 1'b1;
         if      (trig_inter_end)  time_trig_st_nxt = ST_TRIGGER; // IF INHIBIT IS SHORTER, TAKES MORE TIME
      end
      ST_TRIGGER: begin
         tag_wr          = 1'b1;
         if (inhibit_zero)    time_trig_st_nxt = ST_ARMED;
         else                 time_trig_st_nxt = ST_INHIBIT;
      end
      ST_INHIBIT : begin
         inhibit           = 1'b1;
         if (inhibit_end) time_trig_st_nxt = ST_ARMED;
      end
   endcase
end

// Time Counter 
//////////////////////////////////////////////////////////////////////////
reg [28:0] time_cnt;
always_ff @(posedge adc_clk_i) begin
   if    (!adc_rst_ni) time_cnt <= 0;
   else
      if (working) time_cnt <= time_cnt + 1'b1;
      else         time_cnt <= 0;
end

// Inhibit Counter 
//////////////////////////////////////////////////////////////////////////
reg [7:0] inhibit_cnt, inhibit_cnt_p1 ;
assign inhibit_cnt_p1 = inhibit_cnt + 1'b1;

always_ff @(posedge adc_clk_i) begin
   if    (!adc_rst_ni) inhibit_cnt <= 0;
   else
      if (inhibit) inhibit_cnt <= inhibit_cnt_p1;
      else         inhibit_cnt <= 0;
end

// RESET FIFOS 
//////////////////////////////////////////////////////////////////////////
assign inhibit_end  = ( inhibit_cnt_p1 == cmp_inh_i ) ;
assign inhibit_zero = ~|cmp_inh_i;


thr_cmp  #( 
   .CMP_SLOPE  ( CMP_SLOPE ) ,
   .CMP_INTER  ( CMP_INTER ) ,
   .SMP_DW     (16) ,
   .SMP_CK     (8) 
) CMP (
   .clk_i         ( adc_clk_i ) ,
   .rst_ni        ( adc_rst_ni ) ,
   .en_i          ( cmp_en ) ,
   .cfg_filter_i  ( cfg_filter_i ) ,
   .cfg_slope_i   ( cfg_slope_i ) ,
   .cfg_inter_i   ( cfg_inter_i ), 
   .time_ck_i     ( time_cnt ),
   .th_i          ( cmp_th_i ) ,
   .dt_i          ( adc_dt_i ) ,
   .trig_inter_end_o ( trig_inter_end ) ,
   .trig_time_ck_o   ( time_ck_s) ,
   .trig_time_adc_o  ( time_adc_s) ,
   .trig_time_int_o  ( time_int_s) ,
   .trig_vld_o       ( trig_event ) );

wire[31:0] tag_dt;
assign tag_dt =   ( cfg_inter_i ) == 3'b000 ?  { time_ck_s[28:0], time_adc_s }                        : // No Interpolation
                  ( cfg_inter_i ) == 3'b001 ?  { time_ck_s[27:0], time_adc_s, time_int_s[0] }   : // Interpolation of 1 bit
                  ( cfg_inter_i ) == 3'b010 ?  { time_ck_s[26:0], time_adc_s, time_int_s[1:0] } : // Interpolation of 2 bit
                  ( cfg_inter_i ) == 3'b011 ?  { time_ck_s[25:0], time_adc_s, time_int_s[2:0] } : // Interpolation of 3 bit
                  ( cfg_inter_i ) == 3'b100 ?  { time_ck_s[24:0], time_adc_s, time_int_s[3:0] } : // Interpolation of 4 bit
                  ( cfg_inter_i ) == 3'b101 ?  { time_ck_s[23:0], time_adc_s, time_int_s[4:0] } : // Interpolation of 5 bit
                  ( cfg_inter_i ) == 3'b110 ?  { time_ck_s[22:0], time_adc_s, time_int_s[5:0] } : // Interpolation of 6 bit
                                               { time_ck_s[21:0], time_adc_s, time_int_s[6:0] } ; // Interpolation of 7 bit
wire [15:0] tag_mem_ds;
TAG_FIFO_TC # (
   .DMA_BLOCK ( DMA_RD ) , 
   .RD_BLOCK  ( PROC_RD ) , 
   .FIFO_DW ( 32 ) , 
   .FIFO_AW ( TAG_FIFO_AW  )  
) tag_mem ( 
   .dma_clk_i     ( ps_clk_i      ) , 
   .dma_rst_ni    ( ps_rst_ni     ) , 
   .c_clk_i       ( c_clk_i      ) , 
   .c_rst_ni      ( c_rst_ni     ) , 
   .adc_clk_i     ( adc_clk_i    ) , 
   .adc_rst_ni    ( adc_rst_ni   ) , 
   .flush_i       ( qtt_rst_req_i    ) ,
   .flush_o       ( qtt_rst_ack_o    ) ,
   .adc_push_i    ( tag_wr       ) , 
   .adc_data_i    ( tag_dt       ) , 
   .c_pop_i       ( qtt_pop_req_i  ) , 
   .c_pop_o       ( qtt_pop_ack    ) , 
   .c_qty_o       ( proc_qty_o  ) , 
   .c_empty_o  (   ) , 
   .dma_pop_i     ( dma_pop_req   ) , 
   .dma_pop_o     ( dma_pop_ack   ) , 
   .dma_qty_o     ( dma_qty_o  ) , 
   .dma_empty_o   (   ) , 
   .dt_o          ( tag_fifo_dt  ) , 
   .full_o        (   ) ,
   .debug_do      ( tag_mem_ds ));


wire [15:0 ]dma_ds;
wire [25:0 ]dma_reg_ds;
dma_fifo_rd # (
   .MEM_AW      ( TAG_FIFO_AW )  ,  // Memory Address Width
   .MEM_DW      ( 32 )   ,  // Memory Data Width
   .DMA_DW      ( 32 )      // DMA   Data Width
) dma_rd (
   .clk_i            ( ps_clk_i          ) ,
   .rst_ni           ( ps_rst_ni         ) ,
   .dma_req_i        ( dma_req_i        ) ,
   .dma_ack_o        ( dma_ack_o        ) ,
   .dma_len_i        ( dma_len_i        ) ,
   .pop_req_o        ( dma_pop_req       ) ,
   .pop_ack_i        ( dma_pop_ack       ) ,
   .fifo_dt_i        ( tag_fifo_dt           ) ,
   .m_axis_tready_i  ( dma_m_axis_tready_i   ) ,
   .m_axis_tdata_o   ( dma_m_axis_tdata_o    ) ,
   .m_axis_tvalid_o  ( dma_m_axis_tvalid_o   ) ,
   .m_axis_tlast_o   ( dma_m_axis_tlast_o    ) ,
   .dma_do           ( dma_ds                ) ,  
   .dma_reg_do       ( dma_reg_ds            ));   

wire [31:0] smp_fifo_dt;
generate
   if (SMP_STORE ==1 )  begin: SMP
      TAG_FIFO_TC # (
         .DMA_BLOCK ( 1 ) , 
         .RD_BLOCK  ( 0 ) , 
         .FIFO_DW ( 32 ) , 
         .FIFO_AW ( SMP_FIFO_AW  )  
      ) smp_mem ( 
         .dma_clk_i     ( ps_clk_i      ) , 
         .dma_rst_ni    ( ps_rst_ni     ) , 
         .c_clk_i       ( c_clk_i      ) , 
         .c_rst_ni      ( c_rst_ni     ) , 
         .adc_clk_i     ( adc_clk_i    ) , 
         .adc_rst_ni    ( adc_rst_ni   ) , 
         .flush_i       ( qtt_rst    ) ,
         .adc_push_i    ( smp_wr       ) , 
         .adc_data_i    ( smp_dt       ) , 
         .c_pop_i       (   ) , 
         .c_pop_o       (   ) , 
         .c_qty_o       (   ) , 
         .c_empty_o     (   ) , 
         .dma_pop_i     ( smp_fifo_pop_o   ) , 
         .dma_pop_o     ( smp_fifo_pop_i   ) , 
         .dma_qty_o     (   ) , 
         .dma_empty_o   (   ) , 
         .dt_o          ( smp_fifo_dt  ) , 
         .full_o        (   ) ,
         .debug_do      ( smp_mem_ds ));
    end else begin
        assign smp_fifo_dt        = 0;
        assign smp_m_axis_tdata_o = 0;
        assign smp_m_axis_tvalid_o = 0;
        assign smp_m_axis_tlast_o = 0;
    end
endgenerate


///////////////////////////////////////////////////////////////////////////////
// OUT SIGNALS
///////////////////////////////////////////////////////////////////////////////
pulse_cdc pulse_cdc_inst (
   .clk_a_i   ( ps_clk_i ) ,
   .rst_a_ni  ( ps_rst_ni ) ,
   .pulse_a_i ( qtt_pop_ack ) ,
   .rdy_a_o   (  ) ,
   .clk_b_i   ( c_clk_i ) ,
   .rst_b_ni  ( c_rst_ni ) ,
   .pulse_b_o ( tadg_vld ) );

reg [31:0] tag_dt_r;
always_ff @(posedge ps_clk_i) begin
   if (!ps_rst_ni)
      tag_dt_r <= 0;
   else if (qtt_pop_ack)
      tag_dt_r <= tag_fifo_dt;
end

assign tag_dt_o  = tag_dt_r;
assign tag_vld_o = tadg_vld;

// STATUS
///////////////////////////////////////////////////////////////////////////////
assign qtt_reg_status_o[7:0]   = time_trig_st[7:0];
assign qtt_reg_status_o[9:8]   = dma_reg_ds[25:24];
assign qtt_reg_status_o[15:10] = 0;

// DEBUG 
///////////////////////////////////////////////////////////////////////////////
assign qtt_debug_o[15:0]    = tag_mem_ds;
assign qtt_debug_o[31:16]   = dma_ds;

assign qtt_reg_debug_o[3:0] = tag_mem_ds[3:0];
assign qtt_reg_debug_o[5:4] = 2'b00;
assign qtt_reg_debug_o[31:6] = dma_reg_ds;



endmodule
