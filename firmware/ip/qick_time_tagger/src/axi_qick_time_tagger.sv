///////////////////////////////////////////////////////////////////////////////
//  FERMI RESEARCH LAB
///////////////////////////////////////////////////////////////////////////////
//  Author         : Martin Di Federico
//  Date           : 2024_4_17
//  Version        : 2
///////////////////////////////////////////////////////////////////////////////
//  QICK PROCESSOR :  Time Tagger
//////////////////////////////////////////////////////////////////////////////

   
module axi_qick_time_tagger # (
   parameter DMA_RD       = 1  , // TAG FIFO Read from DMA
   parameter PROC_RD      = 1  , // TAG FIFO Read from tProcessor
   parameter CMP_SLOPE    = 1  , // Compare with SLOPE
   parameter CMP_INTER    = 4  , // Interpolate SAMPLES
   parameter TAG_FIFO_AW  = 19 , // Size of TAG FIFO Memory
   parameter SMP_DW       = 16 , // Samples WIDTH
   parameter SMP_CK       = 8  , // Samples per Clock
   parameter SMP_STORE    = 0  , // Store Samples Value
   parameter SMP_FIFO_AW  = 10 , // Size of SAMPLES FIFO Memory
   parameter DEBUG        = 1  
) (
// Core and AXI CLK & RST
   input  wire                      c_clk          ,
   input  wire                      c_aresetn      ,
   input  wire                      adc_clk        ,
   input  wire                      adc_aresetn    ,
   input  wire                      ps_clk         ,
   input  wire                      ps_aresetn     ,
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
   input  wire                     adc_s_axis_tvalid_i ,
   input  wire [SMP_CK*SMP_DW-1:0] adc_s_axis_tdata_i  ,
   output wire                     adc_s_axis_tready_o ,
///// DATA DMA
   input  wire                      dma_m_axis_tready_i ,
   output wire                      dma_m_axis_tvalid_o ,
   output wire [31:0]               dma_m_axis_tdata_o  ,
   output wire                      dma_m_axis_tlast_o  ,
///// DEBUG   
   output wire [31:0]               qtt_do
   );

///////////////////////////////////////////////////////////////////////////////
// PERIPHERAL
///////////////////////////////////////////////////////////////////////////////
wire [31:0] qtt_reg_debug_s, qtt_debug_s;

wire [ 7:0] r_qtt_ctrl, r_qtt_cfg;
wire [19:0] r_qtt_addr, r_qtt_len;
wire [31:0] r_axi_dt1, r_axi_dt2, r_axi_dt3, r_axi_dt4;
wire [31:0] r_qtt_dt1 , r_qtt_dt2, r_qtt_dt3, r_qtt_dt4;

wire [SMP_DW-1:0] qtt_cmp_th;
wire[7:0] qtt_cmp_inh;
wire [15:0]qtt_reg_status_s;

qick_time_tagger # (
   .DMA_RD        ( DMA_RD ) ,
   .PROC_RD       ( PROC_RD ) ,
   .CMP_SLOPE     ( CMP_SLOPE ) ,
   .CMP_INTER     ( CMP_INTER ) ,
   .TAG_FIFO_AW   ( TAG_FIFO_AW ) ,
   .SMP_DW        ( SMP_DW      ) ,
   .SMP_CK        ( SMP_CK      ) ,
   .SMP_STORE     ( SMP_STORE   ) ,
   .SMP_FIFO_AW   ( SMP_FIFO_AW ) ,
   .DEBUG         ( DEBUG       )    
) QTT (
   .ps_clk_i            ( ps_clk ) ,
   .ps_rst_ni           ( ps_aresetn ) ,
   .c_clk_i             ( c_clk ) ,
   .c_rst_ni            ( c_aresetn ) ,
   .adc_clk_i           ( adc_clk      ) ,
   .adc_rst_ni          ( adc_aresetn  ) ,
   .qtt_pop_req_i       ( qtt_pop_req    ) ,
   .tag_vld_o           ( qtt_tag_vld  ) ,
   .qtt_rst_req_i       ( qtt_rst_req    ) ,
   .qtt_rst_ack_o       ( qtt_rst_ack    ) ,
   .cfg_filter_i        ( cfg_filter   ),
   .cfg_slope_i         ( cfg_slope    ),
   .cfg_inter_i         ( cfg_inter    ),
   .arm_i               ( qtt_arm ) , // Arm Trigger (ONE works)
   .cmp_th_i            ( qtt_cmp_th ) , // Threhold Data
   .cmp_inh_i           ( qtt_cmp_inh ) , // Inhibit Clock Pulses
   .adc_dt_i            ( adc_s_axis_tdata_i ) ,
   .dma_req_i           ( dma_tag_rd ) ,
   .dma_ack_o           (  ) ,
   .dma_len_i           ( r_qtt_len[TAG_FIFO_AW-1:0] ) , 
   .dma_m_axis_tready_i ( dma_m_axis_tready_i ) ,
   .dma_m_axis_tvalid_o ( dma_m_axis_tvalid_o ) ,
   .dma_m_axis_tdata_o  ( dma_m_axis_tdata_o ) ,
   .dma_m_axis_tlast_o  ( dma_m_axis_tlast_o ) ,
   .tag_dt_o            ( tag_dt )  ,
   .dma_qty_o           ( dma_qty )  ,
   .proc_qty_o          ( proc_qty  )  ,   
   .qtt_debug_o         ( qtt_debug_s ) ,
   .qtt_reg_status_o    ( qtt_reg_status_s ) ,
   .qtt_reg_debug_o     ( qtt_reg_debug_s ) );

wire[7:0]   cmd_cnt_do;
qtt_cmd CMD (
   .clk_i         ( c_clk           ) ,
   .rst_ni        ( c_aresetn       ) ,
   .c_en_i        ( qtag_en_i       ) ,
   .c_op_i        ( qtag_op_i       ) ,
   .c_dt_i        ( qtag_dt1_i      ) ,
   .p_en_i        ( qtt_cmd_en      ) ,
   .p_op_i        ( qtt_op          ) ,
   .p_dt_i        ( r_axi_dt1       ) ,
   .pop_req_o     ( qtt_pop_req     ) ,
//   .pop_ack_i     ( qtt_pop_ack     ) ,
   .rst_req_o     ( qtt_rst_req     ) ,
   .rst_ack_i     ( qtt_rst_ack     ) ,
   .qtt_arm_o     ( qtt_arm         ) ,
   .qtt_cmp_th_o  ( qtt_cmp_th      ) ,
   .qtt_cmp_inh_o ( qtt_cmp_inh     ) ,
   .cmd_cnt_do    ( cmd_cnt_do      ) );

localparam zf_th = 16-SMP_DW;
localparam zf_aw = 19-TAG_FIFO_AW;


wire [2:0] cfg_inter;
wire [4:0] qtt_op;
assign qtt_cmd_en = r_qtt_ctrl[0];
assign qtt_reset  = r_qtt_ctrl[1];
assign dma_tag_rd = r_qtt_ctrl[2];
assign dma_smp_rd = r_qtt_ctrl[3];

assign qtt_op     = {2'b00,r_qtt_cfg[2:0]};
assign cfg_filter = r_qtt_cfg[3];
assign cfg_slope  = r_qtt_cfg[4];
assign cfg_inter  = r_qtt_cfg[7:5];

assign r_qtt_dt1 = tag_dt;
assign r_qtt_dt2 = { 13'd0, {zf_aw{1'b0}}, proc_qty};
assign r_qtt_dt3 = { 13'd0, {zf_aw{1'b0}}, dma_qty };
assign r_qtt_dt4 = { cmd_cnt_do, qtt_cmp_inh, {zf_th{1'b0}}, qtt_cmp_th };

///// DATA PROC
wire                      proc_ack ;
wire [31:0]               tag_dt  ;
wire [TAG_FIFO_AW-1:0]    dma_qty, proc_qty ;

///////////////////////////////////////////////////////////////////////////////
// AXI Registers
///////////////////////////////////////////////////////////////////////////////
axi_slv_qtt AXI_REG (
   .aclk       ( ps_clk             ) , 
   .aresetn    ( ps_aresetn         ) , 
   .awaddr     ( s_axi_awaddr[5:0]  ) , 
   .awprot     ( s_axi_awprot       ) , 
   .awvalid    ( s_axi_awvalid      ) , 
   .awready    ( s_axi_awready      ) , 
   .wdata      ( s_axi_wdata        ) , 
   .wstrb      ( s_axi_wstrb        ) , 
   .wvalid     ( s_axi_wvalid       ) , 
   .wready     ( s_axi_wready       ) , 
   .bresp      ( s_axi_bresp        ) , 
   .bvalid     ( s_axi_bvalid       ) , 
   .bready     ( s_axi_bready       ) , 
   .araddr     ( s_axi_araddr       ) , 
   .arprot     ( s_axi_arprot       ) , 
   .arvalid    ( s_axi_arvalid      ) , 
   .arready    ( s_axi_arready      ) , 
   .rdata      ( s_axi_rdata        ) , 
   .rresp      ( s_axi_rresp        ) , 
   .rvalid     ( s_axi_rvalid       ) , 
   .rready     ( s_axi_rready       ) , 
// Registers
   .QTT_CTRL   ( r_qtt_ctrl    ) ,
   .QTT_CFG    ( r_qtt_cfg     ) ,
   .QTT_ADDR   ( r_qtt_addr    ) ,
   .QTT_LEN    ( r_qtt_len     ) ,
   .AXI_DT1    ( r_axi_dt1     ) ,
   .AXI_DT2    ( r_axi_dt2     ) ,
   .AXI_DT3    ( r_axi_dt3     ) ,
   .AXI_DT4    ( r_axi_dt4     ) ,
   .QTT_DT1    ( r_qtt_dt1     ) ,
   .QTT_DT2    ( r_qtt_dt2     ) ,
   .QTT_DT3    ( r_qtt_dt3     ) ,
   .QTT_DT4    ( r_qtt_dt4     ) ,
   .QTT_STATUS ( qtt_reg_status_s  ) ,
   .QTT_DEBUG  ( r_qtt_debug   ) );



///////////////////////////////////////////////////////////////////////////////
// OUT SIGNALS
///////////////////////////////////////////////////////////////////////////////
assign adc_s_axis_tready_o = 1'b1;

assign qtag_rdy_o   = 1;
assign qtag_dt1_o   = tag_dt;
assign qtag_dt2_o   = r_qtt_dt2;
assign qtag_vld_o   = qtt_tag_vld;
assign qtag_flag_o  = 0;



wire [31:0] r_qtt_debug;
// DEBUG
///////////////////////////////////////////////////////////////////////////////
generate
   if             (DEBUG == 0 )  begin: DEBUG_NO
      assign r_qtt_debug    = 0;
      assign qtt_do         = 0;
   end else if    (DEBUG == 1)   begin: DEBUG_REG
      assign r_qtt_debug   = qtt_reg_debug_s;
      assign qtt_do             = 0;
   end else if    (DEBUG == 2)   begin: DEBUG_OUT
      assign r_qtt_debug        = qtt_reg_debug_s;
      assign qtt_do             = qtt_debug_s;
   end
endgenerate

   
endmodule
