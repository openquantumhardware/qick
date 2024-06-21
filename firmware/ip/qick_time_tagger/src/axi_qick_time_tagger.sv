///////////////////////////////////////////////////////////////////////////////
//  FERMI RESEARCH LAB
///////////////////////////////////////////////////////////////////////////////
//  Author         : Martin Di Federico
//  Date           : 2024_6_21
//  Version        : 3
///////////////////////////////////////////////////////////////////////////////
//  QICK PROCESSOR :  Time Tagger
//////////////////////////////////////////////////////////////////////////////

module axi_qick_time_tagger # (
   parameter EXT_ARM      = 0  , // External ARM Control
   parameter ADC_QTY      = 1  , // Number of ADC Inputs
   parameter CMP_INTER    = 4  , // Max Number of Interpolation bits
   parameter ARM_STORE    = 1  , // Store NUmber of Triggers on each ARM
   parameter SMP_STORE    = 0  , // Store Sample Values
   parameter TAG_FIFO_AW  = 16 , // Size of TAG FIFO Memory
   parameter ARM_FIFO_AW  = 10 , // Size of ARM FIFO Memory
   parameter SMP_FIFO_AW  = 18 , // Size of SAMPLE FIFO Memory
   parameter CMP_SLOPE    = 0  , // Compare with SLOPE Option
   parameter SMP_DW       = 16 , // Samples WIDTH
   parameter SMP_CK       = 8  , // Samples per Clock
   parameter DEBUG        = 1  
) (
// Core and AXI CLK & RST
   input  wire                      c_clk          ,
   input  wire                      c_aresetn      ,
   input  wire                      adc_clk        ,
   input  wire                      adc_aresetn    ,
   input  wire                      ps_clk         ,
   input  wire                      ps_aresetn     ,
// EXTERNAL INTERFACE
   input  wire                      arm_i          ,
   output wire                      trig_o         ,
// PROCESSOR INTERFACE
   input  wire                      qtag_en_i      ,
   input  wire  [ 4:0]              qtag_op_i      ,
   input  wire  [31:0]              qtag_dt1_i     ,
   input  wire  [31:0]              qtag_dt2_i     ,
   input  wire  [31:0]              qtag_dt3_i     ,
   input  wire  [31:0]              qtag_dt4_i     ,
   output reg                       qtag_rdy_o     ,
   output reg   [31:0]              qtag_dt1_o     ,
   output reg   [31:0]              qtag_dt2_o     ,
   output reg                       qtag_vld_o     ,
   output reg                       qtag_flag_o    ,
// AXI INTERFACE
   input  wire [5:0]                s_axi_awaddr   ,
   input  wire [2:0]                s_axi_awprot   ,
   input  wire                      s_axi_awvalid  ,
   output wire                      s_axi_awready  ,
   input  wire [31:0]               s_axi_wdata    ,
   input  wire [ 3:0]               s_axi_wstrb    ,
   input  wire                      s_axi_wvalid   ,
   output wire                      s_axi_wready   ,
   output wire [ 1:0]               s_axi_bresp    ,
   output wire                      s_axi_bvalid   ,
   input  wire                      s_axi_bready   ,
   input  wire [ 5:0]               s_axi_araddr   ,
   input  wire [ 2:0]               s_axi_arprot   ,
   input  wire                      s_axi_arvalid  ,
   output wire                      s_axi_arready  ,
   output wire [31:0]               s_axi_rdata    ,
   output wire [ 1:0]               s_axi_rresp    ,
   output wire                      s_axi_rvalid   ,
   input  wire                      s_axi_rready   ,
///// ADC DATA
   input  wire                     adc0_s_axis_tvalid_i ,
   input  wire [SMP_CK*SMP_DW-1:0] adc0_s_axis_tdata_i  ,
   output wire                     adc0_s_axis_tready_o ,
   input  wire                     adc1_s_axis_tvalid_i ,
   input  wire [SMP_CK*SMP_DW-1:0] adc1_s_axis_tdata_i  ,
   output wire                     adc1_s_axis_tready_o ,
   input  wire                     adc2_s_axis_tvalid_i ,
   input  wire [SMP_CK*SMP_DW-1:0] adc2_s_axis_tdata_i  ,
   output wire                     adc2_s_axis_tready_o ,
   input  wire                     adc3_s_axis_tvalid_i ,
   input  wire [SMP_CK*SMP_DW-1:0] adc3_s_axis_tdata_i  ,
   output wire                     adc3_s_axis_tready_o ,
///// DATA DMA
   input  wire                      dma_m_axis_tready_i ,
   output wire                      dma_m_axis_tvalid_o ,
   output wire [31:0]               dma_m_axis_tdata_o  ,
   output wire                      dma_m_axis_tlast_o  ,
///// DEBUG   
   output wire [31:0]               qtt_do
   );

// Signal Declaration
//////////////////////////////////////////////////////////////////////////


wire [31:0]            tag_dt  ;
wire [TAG_FIFO_AW-1:0] dma_qty [4] ;
wire [TAG_FIFO_AW-1:0] proc_qty ;
wire [SMP_FIFO_AW-1:0] smp_qty ;
wire [ARM_FIFO_AW-1:0] arm_qty ;


wire [2:0] cfg_inter;
wire [4:0] qtt_op;

wire [ 2:0] dma_mem_sel;
wire [19:0] dma_len;
wire [4:0]          cfg_smp_wr_qty;

// PERIPHERAL
///////////////////////////////////////////////////////////////////////////////
wire [31:0] qtt_reg_debug_s, qtt_debug_s;

wire [ 7:0] axi_reg_CTRL;
wire [10:0] axi_reg_CFG;
wire [23:0] axi_reg_DMA_CFG ;
wire [31:0] axi_reg_AXI_DT1 ;
wire [31:0] axi_reg_PROC_DT ;
wire [19:0] axi_reg_PROC_QTY, axi_reg_TAG0_QTY ;
wire [19:0] axi_reg_TAG1_QTY, axi_reg_TAG2_QTY, axi_reg_TAG3_QTY ;
wire [19:0] axi_reg_SMP_QTY, axi_reg_ARM_QTY ;
wire [31:0] axi_reg_THR_INH , axi_reg_QTT_STATUS, axi_reg_QTT_DEBUG;

wire [SMP_DW-1:0] qtt_cmp_th;
wire[7:0] qtt_cmp_inh;
wire [23:0]qtt_reg_status_s;

wire [SMP_CK*SMP_DW-1:0] adc_dt [ADC_QTY];

generate
   if             (ADC_QTY == 1 )  begin: ONE_ADC
      assign adc_dt = '{adc0_s_axis_tdata_i};
   end else if    (ADC_QTY == 2)   begin: TWO_ADC
      assign adc_dt = '{adc0_s_axis_tdata_i, adc1_s_axis_tdata_i};
   end else if    (ADC_QTY == 3)   begin: TWO_ADC
      assign adc_dt = '{adc0_s_axis_tdata_i, adc1_s_axis_tdata_i, adc2_s_axis_tdata_i};
   end else if    (ADC_QTY == 4)   begin: TWO_ADC
      assign adc_dt = '{adc0_s_axis_tdata_i, adc1_s_axis_tdata_i, adc2_s_axis_tdata_i, adc3_s_axis_tdata_i};
   end
endgenerate
generate

endgenerate

qick_time_tagger # (
   .ADC_QTY       ( ADC_QTY     ) ,
   .CMP_SLOPE     ( CMP_SLOPE   ) ,
   .CMP_INTER     ( CMP_INTER   ) ,
   .ARM_STORE     ( ARM_STORE   ) ,
   .SMP_STORE     ( SMP_STORE   ) ,
   .TAG_FIFO_AW   ( TAG_FIFO_AW ) ,
   .ARM_FIFO_AW   ( ARM_FIFO_AW ) ,
   .SMP_FIFO_AW   ( SMP_FIFO_AW ) ,
   .SMP_DW        ( SMP_DW      ) ,
   .SMP_CK        ( SMP_CK      ) ,
   .DEBUG         ( DEBUG       )    
) QTT (
   .ps_clk_i            ( ps_clk ) ,
   .ps_rst_ni           ( ps_aresetn ) ,
   .c_clk_i             ( c_clk ) ,
   .c_rst_ni            ( c_aresetn ) ,
   .adc_clk_i           ( adc_clk      ) ,
   .adc_rst_ni          ( adc_aresetn  ) ,
   .qtt_pop_req_i       ( qtt_pop_req    ) ,
   .qtt_rst_req_i       ( qtt_rst_req    ) ,
   .qtt_rst_ack_o       ( qtt_rst_ack    ) ,
   .cfg_invert_i        ( cfg_invert   ),
   .cfg_filter_i        ( cfg_filter   ),
   .cfg_slope_i         ( cfg_slope    ),
   .cfg_inter_i         ( cfg_inter     ),
   .cfg_smp_wr_qty_i    ( cfg_smp_wr_qty ) ,
   .arm_i               ( qtt_arm ) , // Arm Trigger (ONE works)
   .cmp_th_i            ( qtt_cmp_th ) , // Threhold Data
   .cmp_inh_i           ( qtt_cmp_inh ) , // Inhibit Clock Pulses
   .adc_dt_i            ( adc_dt ) ,
// DMA
   .dma_req_i           ( dma_rd ) ,
   .dma_mem_sel_i       ( dma_mem_sel ) ,
   .dma_len_i           ( dma_len     ) , 
   .dma_ack_o           (  ) ,
   .dma_m_axis_tready_i ( dma_m_axis_tready_i ) ,
   .dma_m_axis_tvalid_o ( dma_m_axis_tvalid_o ) ,
   .dma_m_axis_tdata_o  ( dma_m_axis_tdata_o ) ,
   .dma_m_axis_tlast_o  ( dma_m_axis_tlast_o ) ,
//PROC
   .tag_dt_o            ( tag_dt )  ,
   .tag_vld_o           ( qtt_tag_vld  ) ,
   .trig_o              ( trig_o  ) ,
//DATA
   .proc_qty_o          ( proc_qty  )  ,   
   .dma_qty_o           ( dma_qty )  ,
   .smp_qty_o           ( smp_qty )  ,
   .arm_qty_o           ( arm_qty )  ,
   .qtt_debug_o         ( qtt_debug_s ) ,
   .qtt_reg_status_o    ( qtt_reg_status_s ) ,
   .qtt_reg_debug_o     ( qtt_reg_debug_s ) );

wire[7:0]   cmd_cnt_do;
qtt_cmd CMD (
   .clk_i         ( c_clk           ) ,
   .rst_ni        ( c_aresetn       ) ,
   .ext_arm_i     ( arm_i           ) ,
   .c_en_i        ( qtag_en_i       ) ,
   .c_op_i        ( qtag_op_i       ) ,
   .c_dt_i        ( qtag_dt1_i      ) ,
   .p_en_i        ( qtt_cmd_en      ) ,
   .p_op_i        ( qtt_op          ) ,
   .p_dt_i        ( axi_reg_AXI_DT1 ) ,
   .pop_req_o     ( qtt_pop_req     ) ,
//   .pop_ack_i     ( qtt_pop_ack     ) ,
   .rst_req_o     ( qtt_rst_req     ) ,
   .rst_ack_i     ( qtt_rst_ack     ) ,
   .qtt_arm_o     ( qtt_arm         ) ,
   .qtt_cmp_th_o  ( qtt_cmp_th      ) ,
   .qtt_cmp_inh_o ( qtt_cmp_inh     ) ,
   .cmd_cnt_do    ( cmd_cnt_do      ) );



assign qtt_cmd_en = axi_reg_CTRL[0];
assign qtt_op     = {1'b0,axi_reg_CTRL[4:1]};
assign dma_rd     = axi_reg_CTRL[5];

assign cfg_filter      = axi_reg_CFG[0];
assign cfg_slope       = axi_reg_CFG[1];
assign cfg_inter       = axi_reg_CFG[4:2];
assign cfg_smp_wr_qty  = axi_reg_CFG[9:5];
assign cfg_invert      = axi_reg_CFG[10];

assign dma_mem_sel = axi_reg_DMA_CFG[ 2:0];
assign dma_len     = axi_reg_DMA_CFG[23:4];

// AXI REGISTER ASSIGNMENT
///////////////////////////////////////////////////////////////////////////////
localparam zf_taw = 20-TAG_FIFO_AW;
localparam zf_saw = 20-SMP_FIFO_AW;
localparam zf_aaw = 20-ARM_FIFO_AW;
localparam zf_th  = 16-SMP_DW;

assign axi_reg_PROC_DT     = tag_dt;
assign axi_reg_PROC_QTY    = { 12'd0, {zf_taw{1'b0}}, proc_qty   };
assign axi_reg_TAG0_QTY    = { 12'd0, {zf_taw{1'b0}}, dma_qty[0] };
assign axi_reg_TAG1_QTY    = { 12'd0, {zf_taw{1'b0}}, dma_qty[1] };
assign axi_reg_TAG2_QTY    = { 12'd0, {zf_taw{1'b0}}, dma_qty[2] };
assign axi_reg_TAG3_QTY    = { 12'd0, {zf_taw{1'b0}}, dma_qty[3] };
assign axi_reg_SMP_QTY     = { 12'd0, {zf_saw{1'b0}}, smp_qty };
assign axi_reg_ARM_QTY     = { 12'd0, {zf_aaw{1'b0}}, arm_qty };
assign axi_reg_THR_INH     = {  8'd0, qtt_cmp_inh, {zf_th{1'b0}}, qtt_cmp_th };
assign axi_reg_QTT_STATUS  = { qtt_reg_status_s , cmd_cnt_do } ;

///// DATA PROC

///////////////////////////////////////////////////////////////////////////////
// AXI Registers
///////////////////////////////////////////////////////////////////////////////
axi_slv_qtt AXI_REG (
   .aclk       ( ps_clk             ), 
   .aresetn    ( ps_aresetn         ), 
   .awaddr     ( s_axi_awaddr[5:0]  ), 
   .awprot     ( s_axi_awprot       ), 
   .awvalid    ( s_axi_awvalid      ), 
   .awready    ( s_axi_awready      ), 
   .wdata      ( s_axi_wdata        ), 
   .wstrb      ( s_axi_wstrb        ), 
   .wvalid     ( s_axi_wvalid       ), 
   .wready     ( s_axi_wready       ), 
   .bresp      ( s_axi_bresp        ), 
   .bvalid     ( s_axi_bvalid       ), 
   .bready     ( s_axi_bready       ), 
   .araddr     ( s_axi_araddr       ), 
   .arprot     ( s_axi_arprot       ), 
   .arvalid    ( s_axi_arvalid      ), 
   .arready    ( s_axi_arready      ), 
   .rdata      ( s_axi_rdata        ), 
   .rresp      ( s_axi_rresp        ), 
   .rvalid     ( s_axi_rvalid       ), 
   .rready     ( s_axi_rready       ), 
// Registers
   .CTRL       (axi_reg_CTRL        ),
   .CFG        (axi_reg_CFG         ),
   .DMA_CFG    (axi_reg_DMA_CFG     ),
   .AXI_DT1    (axi_reg_AXI_DT1     ),
   .PROC_DT    (axi_reg_PROC_DT     ),
   .PROC_QTY   (axi_reg_PROC_QTY    ),
   .TAG0_QTY   (axi_reg_TAG0_QTY    ),
   .TAG1_QTY   (axi_reg_TAG1_QTY    ),
   .TAG2_QTY   (axi_reg_TAG2_QTY    ),
   .TAG3_QTY   (axi_reg_TAG3_QTY    ),
   .SMP_QTY    (axi_reg_SMP_QTY     ),
   .ARM_QTY    (axi_reg_ARM_QTY     ),
   .THR_INH    (axi_reg_THR_INH     ),
   .QTT_STATUS (axi_reg_QTT_STATUS  ),
   .QTT_DEBUG  (axi_reg_QTT_DEBUG   )
);



///////////////////////////////////////////////////////////////////////////////
// OUT SIGNALS
///////////////////////////////////////////////////////////////////////////////
assign adc0_s_axis_tready_o = 1'b1;
assign adc1_s_axis_tready_o = 1'b1;
assign adc2_s_axis_tready_o = 1'b1;
assign adc3_s_axis_tready_o = 1'b1;

assign qtag_rdy_o   = 1;
assign qtag_dt1_o   = tag_dt;
assign qtag_dt2_o   = axi_reg_TAG0_QTY;
assign qtag_vld_o   = qtt_tag_vld;
assign qtag_flag_o  = 0;



// DEBUG
///////////////////////////////////////////////////////////////////////////////
generate
   if             (DEBUG == 0 )  begin: DEBUG_NO
      assign axi_reg_QTT_DEBUG    = 0;
      assign qtt_do         = 0;
   end else if    (DEBUG == 1)   begin: DEBUG_REG
      assign axi_reg_QTT_DEBUG   = qtt_reg_debug_s;
      assign qtt_do              = 0;
   end else if    (DEBUG == 2)   begin: DEBUG_OUT
      assign axi_reg_QTT_DEBUG   = qtt_reg_debug_s;
      assign qtt_do              = qtt_debug_s;
   end
endgenerate

   
endmodule
