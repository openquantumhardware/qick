///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : qick_time_tagger (packaged IP top)
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    qick_time_tagger.sv
//!
//! @brief   AXI4-Lite/AXI4-Stream wrapper for the QICK time tagger.
//!
//! @details
//!
//! Faithful port of legacy `axi_qick_time_tagger.sv`: ADC-channel muxing
//! (1-4 channels), instantiates `qick:dsp:qtt_core` (Tier 2 composition,
//! named `qtt_core` rather than `qick_time_tagger` since this packaged IP
//! already owns that VLNV) and `qick:processors:qtt_cmd`, and replaces the legacy
//! hand-written `axi_slv_qtt.vhd` AXI slave with the shared
//! `qick:axi:axil_slv` register bank -- the same substitution every other
//! ported IP in this repo uses, per Tier 3 of the qick_time_tagger port.
//!
//! Register map (axil_slv, byte-addressed, regwidth = 32) -- matches
//! QICK_Time_Tagger.REGISTERS (qick_lib/qick/drivers/peripherals.py)
//! exactly, confirmed against the legacy axi_slv_qtt.vhd register table:
//!
//! 0x00 ctrl_reg      (r/w, [5:0]) - self-clears to 0 one cycle after any
//!                                   nonzero write (one-shot command
//!                                   register: bit0=strobe, bits[3:1]=op,
//!                                   bit5=dma_rd; matches AUTO_CLEAR_BIT0).
//! 0x04 cfg_reg       (r/w, [10:0]) - bit0=filter, bit1=slope,
//!                                    bits[4:2]=interp, bits[9:5]=smp_wr_qty,
//!                                    bit10=invert.
//! 0x08 dma_cfg_reg   (r/w, [23:0]) - bits[3:0]=mem_sel, bits[23:4]=len.
//! 0x0C axi_dt1_reg   (r/w, [31:0]) - staging value for the next ctrl_reg
//!                                    command (threshold/dead-time/...).
//! 0x10 (unused)      (r/w) - present in the legacy VHDL register file but
//!                             never wired to anything; kept as a plain
//!                             scratch register for address-map parity.
//! 0x14 proc_dt_reg   (r/o, [31:0])
//! 0x18 proc_qty_reg  (r/o, [31:0])
//! 0x1C tag0_qty_reg  (r/o, [31:0])
//! 0x20 tag1_qty_reg  (r/o, [31:0])
//! 0x24 tag2_qty_reg  (r/o, [31:0])
//! 0x28 tag3_qty_reg  (r/o, [31:0])
//! 0x2C smp_qty_reg   (r/o, [31:0])
//! 0x30 arm_qty_reg   (r/o, [31:0])
//! 0x34 thr_inh_reg   (r/o, [31:0]) - bits[7:0]=cmd_cnt, bits[23:8]=inh,
//!                                    bits[15:0]=thr (legacy bit-packing
//!                                    preserved exactly, see below).
//! 0x38 qtt_status_reg(r/o, [31:0])
//! 0x3C qtt_debug_reg (r/o, [31:0])
//!
//! Reuse decisions (Tier 0-3 of the qick_time_tagger bottom-up port):
//! `sync_reg` -> `qick:cdc:cdc_reg_sync`; the legacy `axi_slv_qtt.vhd` AXI
//! FSM -> `qick:axi:axil_slv` with `AUTO_CLEAR_BIT0=1` (ctrl_reg is
//! register index 0, matching the legacy self-clear exactly).
//!
//! @author  QICK Development Team
//!
//! @version 1.0
///////////////////////////////////////////////////////////////////////////////

// Named `axi_qick_time_tagger` (not `qick_time_tagger`) to match the
// legacy source's own inner/outer split: `qick:dsp:qtt_core` (Tier 2,
// instantiated below as qtt_i) is the non-AXI core, this is the
// AXI-wrapped top. The packaged fusesoc IP is still VLNV
// `qick:ip:qick_time_tagger` (dropping the axi_ prefix, matching every
// other ported IP's naming), with `toplevel: axi_qick_time_tagger` in
// its .core file.
module axi_qick_time_tagger # ( // verilog_lint: waive module-filename
   parameter int EXT_ARM      = 0  , // Unused - present in the legacy source, never referenced there either
   parameter int ADC_QTY      = 1  , // Number of ADC Inputs
   parameter int CMP_INTER    = 4  , // Max Number of Interpolation bits
   parameter int ARM_STORE    = 1  , // Store Number of Triggers on each ARM
   parameter int SMP_STORE    = 0  , // Store Sample Values
   parameter int TAG_FIFO_AW  = 16 , // Size of TAG FIFO Memory
   parameter int ARM_FIFO_AW  = 10 , // Size of ARM FIFO Memory
   parameter int SMP_FIFO_AW  = 18 , // Size of SAMPLE FIFO Memory
   parameter int CMP_SLOPE    = 0  , // Compare with SLOPE Option
   parameter int SMP_DW       = 16 , // Samples WIDTH
   parameter int SMP_CK       = 8  , // Samples per Clock
   parameter int DEBUG        = 1
) (
// Core and AXI CLK & RST
   input  wire                      c_clk          ,
   input  wire                      c_aresetn      ,
   input  wire                      s0_axis_aclk   ,
   input  wire                      s0_axis_aresetn,
   input  wire                      s_axi_aclk     ,
   input  wire                      s_axi_aresetn  ,
// EXTERNAL INTERFACE
   input  wire                      arm_i          ,
   output wire                      trig_o         ,
   output wire                      cmp_o          ,
// PROCESSOR INTERFACE
   input  wire                      qtag_en_i      ,
   input  wire  [ 4:0]              qtag_op_i      ,
   input  wire  [31:0]              qtag_dt1_i     ,
   input  wire  [31:0]              qtag_dt2_i     ,
   input  wire  [31:0]              qtag_dt3_i     ,
   input  wire  [31:0]              qtag_dt4_i     ,
   output wire                      qtag_rdy_o     ,
   output wire  [31:0]              qtag_dt1_o     ,
   output wire  [31:0]              qtag_dt2_o     ,
   output wire                      qtag_vld_o     ,
   output wire                      qtag_flag_o    ,
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
   input  wire                     s0_axis_adc0_tvalid ,
   input  wire [SMP_CK*SMP_DW-1:0] s0_axis_adc0_tdata  ,
   output wire                     s0_axis_adc0_tready ,
   input  wire                     s0_axis_adc1_tvalid ,
   input  wire [SMP_CK*SMP_DW-1:0] s0_axis_adc1_tdata  ,
   output wire                     s0_axis_adc1_tready ,
   input  wire                     s0_axis_adc2_tvalid ,
   input  wire [SMP_CK*SMP_DW-1:0] s0_axis_adc2_tdata  ,
   output wire                     s0_axis_adc2_tready ,
   input  wire                     s0_axis_adc3_tvalid ,
   input  wire [SMP_CK*SMP_DW-1:0] s0_axis_adc3_tdata  ,
   output wire                     s0_axis_adc3_tready ,
///// DATA DMA
   input  wire                      m0_axis_dma_tready ,
   output wire                      m0_axis_dma_tvalid ,
   output wire [31:0]               m0_axis_dma_tdata  ,
   output wire                      m0_axis_dma_tlast  ,
///// DEBUG
   output wire [31:0]               qtt_do
   );

// Register map indices.
///////////////////////////////////////////////////////////////////////////////
localparam int NUM_REGS      = 16;
localparam int AXI_AW        = 6;
localparam int R_CTRL        = 0;
localparam int R_CFG         = 1;
localparam int R_DMA_CFG     = 2;
localparam int R_AXI_DT1     = 3;
// index 4 reserved/unused (matches the legacy axi_slv_qtt.vhd dead register)
localparam int R_PROC_DT     = 5;
localparam int R_PROC_QTY    = 6;
localparam int R_TAG0_QTY    = 7;
localparam int R_TAG1_QTY    = 8;
localparam int R_TAG2_QTY    = 9;
localparam int R_TAG3_QTY    = 10;
localparam int R_SMP_QTY     = 11;
localparam int R_ARM_QTY     = 12;
localparam int R_THR_INH     = 13;
localparam int R_QTT_STATUS  = 14;
localparam int R_QTT_DEBUG   = 15;

// Registers 0-4 are read/write (from the AXI master); 5-15 are read-only
// (status/counters driven by the time tagger core).
localparam logic [NUM_REGS-1:0] REG_IS_READONLY = {11'b111_1111_1111, 5'b0_0000};

logic [31:0] o_slv_regs [NUM_REGS];
logic [31:0] i_slv_regs [NUM_REGS];
wire  [31:0] qtt_reg_debug_s_masked;

// Signal Declaration
///////////////////////////////////////////////////////////////////////////////
wire [31:0]            tag_dt  ;
wire [TAG_FIFO_AW-1:0] dma_qty [4] ;
wire [TAG_FIFO_AW-1:0] proc_qty ;
wire [SMP_FIFO_AW-1:0] smp_qty ;
wire [ARM_FIFO_AW-1:0] arm_qty ;

wire [2:0] cfg_inter;
wire [4:0] qtt_op;

wire [ 2:0] dma_mem_sel;
wire [19:0] dma_len;
wire [4:0]  cfg_smp_wr_qty;

wire [31:0] qtt_reg_debug_s, qtt_debug_s;
wire        qtt_cmd_en, dma_rd;
wire        cfg_filter, cfg_slope, cfg_invert;

wire [SMP_DW-1:0] qtt_cmp_th;
wire [7:0]        qtt_cmp_inh;
wire [23:0]       qtt_reg_status_s;

wire qtt_pop_req, qtt_pop_ack, qtt_rst_req, qtt_rst_ack;
wire qtt_arm, qtt_tag_vld, cmd_peek;
wire [7:0] cmd_cnt_do;

wire [SMP_CK*SMP_DW-1:0] adc_dt [ADC_QTY];

generate
   if             (ADC_QTY == 1 )  begin: gen_adc1
      assign adc_dt = '{s0_axis_adc0_tdata};
   end else if    (ADC_QTY == 2)   begin: gen_adc2
      assign adc_dt = '{s0_axis_adc0_tdata, s0_axis_adc1_tdata};
   end else if    (ADC_QTY == 3)   begin: gen_adc3
      assign adc_dt = '{s0_axis_adc0_tdata, s0_axis_adc1_tdata, s0_axis_adc2_tdata};
   end else if    (ADC_QTY == 4)   begin: gen_adc4
      assign adc_dt = '{s0_axis_adc0_tdata, s0_axis_adc1_tdata, s0_axis_adc2_tdata, s0_axis_adc3_tdata};
   end
endgenerate

qtt_core # (
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
) qtt_i (
   .ps_clk_i            ( s_axi_aclk ) ,
   .ps_rst_ni           ( s_axi_aresetn ) ,
   .c_clk_i             ( c_clk ) ,
   .c_rst_ni            ( c_aresetn ) ,
   .adc_clk_i           ( s0_axis_aclk      ) ,
   .adc_rst_ni          ( s0_axis_aresetn  ) ,
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
   .dma_m_axis_tready_i ( m0_axis_dma_tready ) ,
   .dma_m_axis_tvalid_o ( m0_axis_dma_tvalid ) ,
   .dma_m_axis_tdata_o  ( m0_axis_dma_tdata ) ,
   .dma_m_axis_tlast_o  ( m0_axis_dma_tlast ) ,
//PROC
   .tag_dt_o            ( tag_dt )  ,
   .tag_vld_o           ( qtt_tag_vld  ) ,
   .trig_o              ( trig_o  ) ,
   .cmp_o               ( cmp_o  ) ,
//DATA
   .proc_qty_o          ( proc_qty  )  ,
   .dma_qty_o           ( dma_qty )  ,
   .smp_qty_o           ( smp_qty )  ,
   .arm_qty_o           ( arm_qty )  ,
   .qtt_debug_o         ( qtt_debug_s ) ,
   .qtt_reg_status_o    ( qtt_reg_status_s ) ,
   .qtt_reg_debug_o     ( qtt_reg_debug_s ) );

qtt_cmd cmd_i (
   .clk_i         ( s0_axis_aclk         ) ,
   .rst_ni        ( s0_axis_aresetn     ) ,
   .c_clk_i       ( c_clk         ) ,
   .c_rst_ni      ( c_aresetn     ) ,
   .ext_arm_i     ( arm_i           ) ,
   .c_en_i        ( qtag_en_i       ) ,
   .c_op_i        ( qtag_op_i       ) ,
   .c_dt_i        ( qtag_dt1_i      ) ,
   .p_en_i        ( qtt_cmd_en      ) ,
   .p_op_i        ( qtt_op          ) ,
   .p_dt_i        ( o_slv_regs[R_AXI_DT1] ) ,
   .pop_req_o     ( qtt_pop_req     ) ,
   .rst_req_o     ( qtt_rst_req     ) ,
   .rst_ack_i     ( qtt_rst_ack     ) ,
   .peek_o        ( cmd_peek        ) ,
   .qtt_arm_o     ( qtt_arm         ) ,
   .qtt_cmp_th_o  ( qtt_cmp_th      ) ,
   .qtt_cmp_inh_o ( qtt_cmp_inh     ) ,
   .cmd_cnt_do    ( cmd_cnt_do      ) );

// The CTRL command is a one-clock pulse; qtt_cmd samples it in the ADC clock domain, so it is held (op first, then
// en) to make the crossing safe against routing skew between the bits. See qtt_cmd_hold.
qtt_cmd_hold # (
   .HOLD ( 6 )
) cmd_hold_i (
   .clk_i     ( s_axi_aclk                       ) ,
   .rst_ni    ( s_axi_aresetn                    ) ,
   .strobe_i  ( o_slv_regs[R_CTRL][0]            ) ,
   .op_i      ( {1'b0, o_slv_regs[R_CTRL][4:1]}  ) ,
   .en_o      ( qtt_cmd_en                       ) ,
   .op_o      ( qtt_op                           ) );
assign dma_rd     = o_slv_regs[R_CTRL][5];

assign cfg_filter      = o_slv_regs[R_CFG][0];
assign cfg_slope       = o_slv_regs[R_CFG][1];
assign cfg_inter       = o_slv_regs[R_CFG][4:2];
assign cfg_smp_wr_qty  = o_slv_regs[R_CFG][9:5];
assign cfg_invert      = o_slv_regs[R_CFG][10];

assign dma_mem_sel = o_slv_regs[R_DMA_CFG][2:0];
assign dma_len     = o_slv_regs[R_DMA_CFG][23:4];

// AXI REGISTER ASSIGNMENT
///////////////////////////////////////////////////////////////////////////////
localparam int ZfTaw = 20-TAG_FIFO_AW;
localparam int ZfSaw = 20-SMP_FIFO_AW;
localparam int ZfAaw = 20-ARM_FIFO_AW;
localparam int ZfTh  = 16-SMP_DW;

assign i_slv_regs[R_CTRL]    = '0; // writable region, axil_slv reads o_slv_regs instead
assign i_slv_regs[R_CFG]     = '0;
assign i_slv_regs[R_DMA_CFG] = '0;
assign i_slv_regs[R_AXI_DT1] = '0;
assign i_slv_regs[4]         = '0; // reserved/unused

assign i_slv_regs[R_PROC_DT]   = tag_dt;
assign i_slv_regs[R_PROC_QTY]  = { 12'd0, {ZfTaw{1'b0}}, proc_qty   };
assign i_slv_regs[R_TAG0_QTY]  = { 12'd0, {ZfTaw{1'b0}}, dma_qty[0] };
assign i_slv_regs[R_TAG1_QTY]  = { 12'd0, {ZfTaw{1'b0}}, dma_qty[1] };
assign i_slv_regs[R_TAG2_QTY]  = { 12'd0, {ZfTaw{1'b0}}, dma_qty[2] };
assign i_slv_regs[R_TAG3_QTY]  = { 12'd0, {ZfTaw{1'b0}}, dma_qty[3] };
assign i_slv_regs[R_SMP_QTY]   = { 12'd0, {ZfSaw{1'b0}}, smp_qty };
assign i_slv_regs[R_ARM_QTY]   = { 12'd0, {ZfAaw{1'b0}}, arm_qty };
assign i_slv_regs[R_THR_INH]   = {  8'd0, qtt_cmp_inh, {ZfTh{1'b0}}, qtt_cmp_th };
assign i_slv_regs[R_QTT_STATUS]= { qtt_reg_status_s , cmd_cnt_do } ;
assign i_slv_regs[R_QTT_DEBUG] = qtt_reg_debug_s_masked;

///////////////////////////////////////////////////////////////////////////////
// AXI Registers
///////////////////////////////////////////////////////////////////////////////
axil_slv # (
   .AXI_DW          ( 32 ),
   .AXI_AW          ( AXI_AW ),
   .NUM_REGS        ( NUM_REGS ),
   .AUTO_CLEAR_BIT0 ( 1'b1 )
) axil_slv_i (
   .s_axi_aclk         ( s_axi_aclk             ),
   .s_axi_aresetn      ( s_axi_aresetn         ),
   .s_axi_awaddr       ( s_axi_awaddr       ),
   .s_axi_awprot       ( s_axi_awprot       ),
   .s_axi_awvalid      ( s_axi_awvalid      ),
   .s_axi_awready      ( s_axi_awready      ),
   .s_axi_wdata        ( s_axi_wdata        ),
   .s_axi_wstrb        ( s_axi_wstrb        ),
   .s_axi_wvalid       ( s_axi_wvalid       ),
   .s_axi_wready       ( s_axi_wready       ),
   .s_axi_bresp        ( s_axi_bresp        ),
   .s_axi_bvalid       ( s_axi_bvalid       ),
   .s_axi_bready       ( s_axi_bready       ),
   .s_axi_araddr       ( s_axi_araddr       ),
   .s_axi_arprot       ( s_axi_arprot       ),
   .s_axi_arvalid      ( s_axi_arvalid      ),
   .s_axi_arready      ( s_axi_arready      ),
   .s_axi_rdata        ( s_axi_rdata        ),
   .s_axi_rresp        ( s_axi_rresp        ),
   .s_axi_rvalid       ( s_axi_rvalid       ),
   .s_axi_rready       ( s_axi_rready       ),
   .o_slv_regs         ( o_slv_regs         ),
   .i_slv_regs         ( i_slv_regs         ),
   .i_reg_is_readonly  ( REG_IS_READONLY    )
);

///////////////////////////////////////////////////////////////////////////////
// OUT SIGNALS
///////////////////////////////////////////////////////////////////////////////
assign s0_axis_adc0_tready = 1'b1;
assign s0_axis_adc1_tready = 1'b1;
assign s0_axis_adc2_tready = 1'b1;
assign s0_axis_adc3_tready = 1'b1;

assign qtag_rdy_o   = 1'b1;
assign qtag_dt1_o   = tag_dt;
assign qtag_vld_o   = qtt_tag_vld | cmd_peek;
assign qtag_flag_o  = 1'b0;

cdc_reg_sync # (
   .DW ( 32 )
) sync_dt2 (
   .dt_i      ( i_slv_regs[R_PROC_QTY] ) ,
   .clk_i     ( c_clk ) ,
   .rst_ni    ( c_aresetn ) ,
   .dt_o      ( qtag_dt2_o ) );

// DEBUG
///////////////////////////////////////////////////////////////////////////////
generate
   if             (DEBUG == 0 )  begin: gen_debug_no
      assign qtt_reg_debug_s_masked = 32'd0;
      assign qtt_do                 = 32'd0;
   end else if    (DEBUG == 1)   begin: gen_debug_reg
      assign qtt_reg_debug_s_masked = qtt_reg_debug_s;
      assign qtt_do                 = 32'd0;
   end else if    (DEBUG == 2)   begin: gen_debug_out
      assign qtt_reg_debug_s_masked = qtt_reg_debug_s;
      assign qtt_do                 = qtt_debug_s;
   end
endgenerate

endmodule
