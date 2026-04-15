///////////////////////////////////////////////////////////////////////////////
//  Fermilab National Accelerator Laboratory
///////////////////////////////////////////////////////////////////////////////
// Description: 
// Test Bench for Qick Project
//////////////////////////////////////////////////////////////////////////////

`timescale 1ns/1ps

`include "_qproc_defines.svh"

import axi_vip_pkg::*;
import axi_mst_0_pkg::*;

localparam N_DDS_SG = 16;
localparam N_DDS_RO = 8;

// AXI VIP master address.
xil_axi_ulong     SG_ADDR_START_ADDR   = 32'h40000000; // 0
xil_axi_ulong     SG_ADDR_WE           = 32'h40000004; // 1

// AXI VIP master address.
xil_axi_ulong   AVG_START_REG       = 4 * 0;
xil_axi_ulong   AVG_ADDR_REG        = 4 * 1;
xil_axi_ulong   AVG_LEN_REG         = 4 * 2;
xil_axi_ulong   AVG_DR_START_REG    = 4 * 3;
xil_axi_ulong   AVG_DR_ADDR_REG     = 4 * 4;
xil_axi_ulong   AVG_DR_LEN_REG      = 4 * 5;
xil_axi_ulong   BUF_START_REG       = 4 * 6;
xil_axi_ulong   BUF_ADDR_REG        = 4 * 7;
xil_axi_ulong   BUF_LEN_REG         = 4 * 8;
xil_axi_ulong   BUF_DR_START_REG    = 4 * 9;
xil_axi_ulong   BUF_DR_ADDR_REG     = 4 * 10;
xil_axi_ulong   BUF_DR_LEN_REG      = 4 * 11;


// CLOCK PERIODS
real T_TCLK          =  1.162;      // Half Clock Period for tProc Dispatcher (430MHz)
real T_CCLK          =    2.5;      // Half Clock Period for tProc Core (200MHz)
real T_SCLK          =    5.0;      // Half Clock Period for PS & AXI (100MHz)

// real T_SG_CLK     =    0.8;      // Half Clock Period for Signal Gens (625MHz)
real T_SG_CLK        =  0.833;      // Half Clock Period for Signal Gens (600MHz)

// real T_RO_CLK     =   1.66;      // Half Clock Period for Readout (300MHz)
real T_RO_CLK        =  1.627;      // Half Clock Period for Readout (307.2MHz)

// TPROC PARAMETERS
`define GEN_SYNC         1
`define DUAL_CORE        0
`define IO_CTRL          1
`define DEBUG            3
`define TNET             0
`define QCOM             0
`define CUSTOM_PERIPH    2
`define LFSR             1
`define DIVIDER          1
`define ARITH            1
`define TIME_READ        1
`define FIFO_DEPTH       8
`define PMEM_AW          12 
`define DMEM_AW          14 
`define WMEM_AW          11
`define REG_AW           4 
`define IN_PORT_QTY      1
`define OUT_TRIG_QTY     1
`define OUT_DPORT_QTY    1
`define OUT_DPORT_DW     8
`define OUT_WPORT_QTY    5 

module tb_qick ();

//----------------------------------------------------
// Define Test to run
//----------------------------------------------------
string TEST_NAME = "test_basic_pulses";
// string TEST_NAME = "test_fast_short_pulses";
// string TEST_NAME = "test_many_envelopes";
// string TEST_NAME = "test_tproc_basic";
// string TEST_NAME = "test_issue359";
// string TEST_NAME = "test_issue361";
// string TEST_NAME = "test_issue53";
// string TEST_NAME = "test_randomized_benchmarking";
// string TEST_NAME = "test_qubit_emulator";
//----------------------------------------------------

// Default Simulation Settings
time TEST_RUN_TIME         = 6us;   // Time to run tProc execution
time TEST_READ_TIME        = 1us;   // Time to read data from buffers
time REPEAT_EXEC           = 2;     // Number of Times to Repeat tProc Program Execution
string TEST_OUT_CONNECTION = "TEST_OUT_LOOPBACK";     // Connect DAC/ADC in Loopback
// string TEST_OUT_CONNECTION = "TEST_OUT_QEMU";         // Qubit Emulator
//----------------------------------------------------

// VIP Agents
axi_mst_0_mst_t     axi_mst_tproc_agent;
axi_mst_0_mst_t     axi_mst_sg_agent;
axi_mst_0_mst_t     axi_mst_avg_agent;
axi_mst_0_mst_t     axi_mst_qemu_agent;


// AXI Master VIP variables
xil_axi_prot_t  prot        = 0;
reg[31:0]       data_wr     = 32'h12345678;
xil_axi_resp_t  resp;

//////////////////////////////////////////////////////////////////////////
//  CLK Generation
logic          c_clk, t_clk, s_ps_dma_aclk;

logic [4:0]    dac_fs_gen;
logic          dac_fs, sg_clk;

logic [4:0]    adc_fs_gen;
logic          adc_fs, ro_clk;

initial begin
  t_clk = 1'b0;
  forever # (T_TCLK*1.0ns) t_clk = ~t_clk;
end

initial begin
  c_clk = 1'b0;
  forever # (T_CCLK*1.0ns) c_clk = ~c_clk;
end

initial begin
  s_ps_dma_aclk = 1'b0;
  #0.5ns
  forever # (T_SCLK*1.0ns) s_ps_dma_aclk = ~s_ps_dma_aclk;
end

initial begin
   dac_fs_gen = 'd0;
   forever # (T_SG_CLK*1.0ns/N_DDS_SG) dac_fs_gen = dac_fs_gen + 'd1;
end
assign dac_fs  = dac_fs_gen[0];
assign sg_clk  = dac_fs_gen[4];

initial begin
   adc_fs_gen = 'd0;
   forever # (T_RO_CLK*1.0ns/N_DDS_RO) adc_fs_gen = adc_fs_gen + 'd1;
end
assign adc_fs  = adc_fs_gen[0];
assign ro_clk  = adc_fs_gen[3];


//////////////////////////////////////////////////////////////////////////
//  RST Generation
logic rst_ni;
wire  s_ps_dma_aresetn;

assign s_ps_dma_aresetn  = rst_ni;

//////////////////////////////////////////////////////////////////////////

// reg [255:0] max_value ;
// reg axis_dma_start  ;

reg [255 :0]       s_dma_axis_tdata_i   ;
reg                s_dma_axis_tlast_i   ;
reg                s_dma_axis_tvalid_i  ;
reg                m_dma_axis_tready_i  ;
wire [63 :0]       port_0_dt_i          ;
reg [63 :0]        port_1_dt_i          ;


logic              m0_axis_tready;
reg                m1_axis_tready   =0    ;
reg                m2_axis_tready   =0    ;
reg                m3_axis_tready   =0    ;

reg                m5_axis_tready   =0    ;
reg                m6_axis_tready   =0    ;
reg                m7_axis_tready   =0    ;

wire               s_dma_axis_tready_o  ;
wire [255 :0]      m_dma_axis_tdata_o   ;
wire               m_dma_axis_tlast_o   ;
wire               m_dma_axis_tvalid_o  ;

// tProc Interface
wire [167:0]       m1_axis_tdata        ;
wire               m1_axis_tvalid       ;
wire [167:0]       m2_axis_tdata        ;
wire               m2_axis_tvalid       ;
wire [167:0]       m3_axis_tdata        ;
wire               m3_axis_tvalid       ;

wire [167:0]       m5_axis_tdata        ;
wire               m5_axis_tvalid       ;
wire [167:0]       m6_axis_tdata        ;
wire               m6_axis_tvalid       ;
wire [167:0]       m7_axis_tdata        ;
wire               m7_axis_tvalid       ;

wire               trigger_0;

wire [`OUT_DPORT_DW-1:0]         port_0_dt_o, port_1_dt_o, port_2_dt_o, port_3_dt_o;


// QNET Peripheral
wire                qnet_en_o   ;
wire  [4 :0]        qnet_op_o   ;
wire  [31:0]        qnet_a_dt_o ;
wire  [31:0]        qnet_b_dt_o ;
wire  [31:0]        qnet_c_dt_o ;
wire  [31:0]        qnet_d_dt_o ;
reg                 qnet_rdy_i      ;
reg  [31 :0]        qnet_dt_i [2]   ;
reg  [31 :0]        qcom_dt_i [2]   ;

reg  [31 :0]        qp1_dt_i [2]   ;
reg  [31 :0]        qp2_dt_i [2]   ;

wire                periph_en_o   ;
wire  [4 :0]        periph_op_o   ;
wire  [31:0]        periph_a_dt_o ;
wire  [31:0]        periph_b_dt_o ;
wire  [31:0]        periph_c_dt_o ;
wire  [31:0]        periph_d_dt_o ;
reg                periph_rdy_i    ;
reg  [31 :0]       periph_dt_i [2] ;


reg    s0_axis_tvalid ,    s1_axis_tvalid ;
reg [15:0] waves, wtime;
reg [31:0] axi_dt;



reg proc_start_i, proc_stop_i ;
reg core_start_i, core_stop_i ;
reg time_rst_i, time_init_i, time_updt_i;

reg  [47:0] offset_dt_i ;
wire [47:0] t_time_abs_o ;
reg time_updt_i;

wire [31:0] ps_debug_do;

// Q Peripheral A loopback
wire qp1_en_o;
reg qp1_en_r;
reg [31:0] qp1_a_dt_r, qp1_b_dt_r;
wire [31:0] qp1_a_dt_o, qp1_b_dt_o, qp1_c_dt_o, qp1_d_dt_o;
always_ff @ (posedge c_clk) begin 
   qp1_en_r     <= qp1_en_o;
   qp1_a_dt_r   <=  qp1_a_dt_o;
   qp1_b_dt_r   <=  qp1_b_dt_o;
end
  
assign qp1_rdy_i     = ~qp1_en_r;
assign qp1_dt_i[0]   = qp1_a_dt_r;
assign qp1_dt_i[1]   = qp1_b_dt_r;
assign qp1_vld_i     = qp1_en_r  ;

wire port_0_vld, qnet_vld_i, qnet_flag_i, periph_flag_i, ext_flag_i;
assign port_0_dt_i     = port_1_dt_o;
assign port_0_vld      = port_0_dt_o[0];
assign qnet_vld_i      = t_time_abs_o[3]&t_time_abs_o[2]&t_time_abs_o[1] ;
assign qnet_flag_i       = ~t_time_abs_o[5] & ~t_time_abs_o[4] & t_time_abs_o[3] ;
assign periph_flag_i     = ~t_time_abs_o[5] &  t_time_abs_o[4] & t_time_abs_o[3] ;
assign ext_flag_i        =  t_time_abs_o[5] &  t_time_abs_o[4] & t_time_abs_o[3] ;

// reg  periph_vld_i  ;
reg qcom_rdy_i, qp2_rdy_i;


   // DAC-ADC connections
   logic                      axis_sg_dac_tready;
   logic                      axis_sg_dac_tvalid;
   logic [N_DDS_SG*16-1:0]    axis_sg_dac_tdata;

   logic                      rf_signal_valid;
   logic [N_DDS_RO*16-1:0]    rf_signal_data;

   logic                      axis_adc_ro_tready;
   logic                      axis_adc_ro_tvalid;
   logic [N_DDS_RO*16-1:0]    axis_adc_ro_tdata;


   // Register ADDRESS
   parameter REG_TPROC_CTRL      = 0  * 4 ;
   parameter REG_TPROC_CFG       = 1  * 4 ;
   parameter REG_MEM_ADDR        = 2  * 4 ;
   parameter REG_MEM_LEN         = 3  * 4 ;
   parameter REG_MEM_DT_I        = 4  * 4 ;
   parameter REG_AXI_W_DT1       = 5  * 4 ;
   parameter REG_AXI_W_DT2       = 6  * 4 ;
   parameter REG_CORE_CFG        = 7  * 4 ;
   parameter REG_AXI_DT_SRC      = 8  * 4 ;
   parameter REG_MEM_DT_O        = 10  * 4 ;
   parameter REG_AXI_R_DT1       = 11  * 4 ;
   parameter REG_AXI_R_DT2       = 12  * 4 ;
   parameter REG_TIME_USR        = 13  * 4 ;
   parameter REG_TPROC_STATUS    = 14  * 4 ;
   parameter REG_TPROC_DEBUG     = 15  * 4 ;


wire sg_s0_axis_aclk = s_ps_dma_aclk;
logic   [31:0]       sg_s0_axis_tdata;
logic                sg_s0_axis_tready;
logic                sg_s0_axis_tvalid;

   //--------------------------------------
   // QICK DUT
   //--------------------------------------

   qick_dut qick_dut (
      // Core, Time and AXI CLK & RST.
      .t_clk               ( t_clk              ) ,
      .t_resetn            ( rst_ni             ) ,
      .c_clk               ( c_clk              ) ,
      .c_resetn            ( rst_ni             ) ,
      .ps_clk              ( s_ps_dma_aclk      ) ,
      .ps_resetn           ( s_ps_dma_aresetn   ) ,
      .sg_clk              ( sg_clk             ) ,
      .sg_resetn           ( rst_ni             ) ,
      .ro_clk              ( ro_clk             ) ,
      .ro_resetn           ( rst_ni             ) ,
      // External Control
      .ext_flag_i          ( ext_flag_i         ) ,
      .proc_start_i        ( proc_start_i       ) ,
      .proc_stop_i         ( proc_stop_i        ) ,
      .core_start_i        ( core_start_i       ) ,
      .core_stop_i         ( core_stop_i        ) ,
      .time_rst_i          ( time_rst_i         ) ,
      .time_init_i         ( time_init_i        ) ,
      .time_updt_i         ( time_updt_i        ) ,
      .time_dt_i           ( offset_dt_i        ) ,
      .t_time_abs_o        ( t_time_abs_o       ) ,
      //QNET
      .qnet_en_o           ( qnet_en_o          ) ,
      .qnet_op_o           ( qnet_op_o          ) ,
      .qnet_a_dt_o         ( qnet_a_dt_o        ) ,
      .qnet_b_dt_o         ( qnet_b_dt_o        ) ,
      .qnet_c_dt_o         ( qnet_c_dt_o        ) ,
      .qnet_rdy_i          ( qnet_rdy_i         ) ,
      .qnet_dt1_i          ( qnet_dt_i[0]       ) ,
      .qnet_dt2_i          ( qnet_dt_i[1]       ) ,
      .qnet_vld_i          ( qnet_vld_i         ) ,
      .qnet_flag_i         ( qnet_flag_i        ) ,
      //QCOM
      .qcom_en_o           ( qcom_en_o          ) ,
      .qcom_op_o           ( qcom_op_o          ) ,
      .qcom_dt_o           ( qcom_dt_o          ) ,
      .qcom_rdy_i          ( qcom_rdy_i         ) ,
      .qcom_dt1_i          ( qcom_dt_i[0]       ) ,
      .qcom_dt2_i          ( qcom_dt_i[1]       ) ,
      .qcom_vld_i          ( qcom_vld_i         ) ,
      .qcom_flag_i         ( qcom_flag_i        ) ,
      // QP1
      .qp1_en_o           ( qp1_en_o          ) ,
      .qp1_op_o           ( qp1_op_o          ) ,
      .qp1_a_dt_o         ( qp1_a_dt_o        ) ,
      .qp1_b_dt_o         ( qp1_b_dt_o        ) ,
      .qp1_c_dt_o         ( qp1_c_dt_o        ) ,
      .qp1_d_dt_o         ( qp1_d_dt_o        ) ,
      .qp1_rdy_i          ( qp1_rdy_i         ) ,
      .qp1_dt1_i          ( qp1_dt_i[0]       ) ,
      .qp1_dt2_i          ( qp1_dt_i[1]       ) ,
      .qp1_vld_i          ( qp1_vld_i         ) ,
      .qp1_flag_i         ( qp1_flag_i        ) ,
      // QP2
      .qp2_en_o           ( /*qp2_en_o   */   ) ,
      .qp2_op_o           ( /*qp2_op_o   */   ) ,
      .qp2_a_dt_o         ( /*qp2_a_dt_o */   ) ,
      .qp2_b_dt_o         ( /*qp2_b_dt_o */   ) ,
      .qp2_c_dt_o         ( /*qp2_c_dt_o */   ) ,
      .qp2_d_dt_o         ( /*qp2_d_dt_o */   ) ,
      .qp2_rdy_i          ( /*qp2_rdy_i  */   ) ,
      .qp2_dt1_i          ( /*qp2_dt_i[0]*/   ) ,
      .qp2_dt2_i          ( /*qp2_dt_i[1]*/   ) ,
      .qp2_vld_i          ( /*qp2_vld_i  */   ) ,
      // DMA AXIS FOR READ AND WRITE MEMORY
      .s_dma_axis_tdata_i   ( s_dma_axis_tdata_i  ) ,
      .s_dma_axis_tlast_i   ( s_dma_axis_tlast_i  ) ,
      .s_dma_axis_tvalid_i  ( s_dma_axis_tvalid_i ) ,
      .s_dma_axis_tready_o  ( s_dma_axis_tready_o ) ,
      .m_dma_axis_tdata_o   ( m_dma_axis_tdata_o  ) ,
      .m_dma_axis_tlast_o   ( m_dma_axis_tlast_o  ) ,
      .m_dma_axis_tvalid_o  ( m_dma_axis_tvalid_o ) ,
      .m_dma_axis_tready_i  ( m_dma_axis_tready_i ) ,
      /// DATA PORT INPUT  
      .s0_axis_tdata        ( port_0_dt_i    ) ,
      .s0_axis_tvalid       ( port_0_vld     ) ,
      .s1_axis_tdata        ( port_1_dt_i    ) ,
      .s1_axis_tvalid       ( s1_axis_tvalid ) ,
      ///// TRIGGERS
      .trig_0_o             ( trigger_0               ),
      // OUT DATA PORTS
      .port_0_dt_o          ( port_0_dt_o             ) ,
      .port_1_dt_o          ( port_1_dt_o             ) ,
      .port_2_dt_o          ( port_2_dt_o             ) ,
      .port_3_dt_o          ( port_3_dt_o             ) ,
      // Debug Signals
      .ps_debug_do          ( ),
      .t_debug_do           ( ),
      .t_fifo_do            ( ),
      .c_time_usr_do        ( ),
      .c_debug_do           ( ),
      .c_time_ref_do        ( ),
      .c_port_do            ( ),
      .c_core_do            ( ),

      // Signal Generator from tProc interface
      .sg_s0_axis_aclk           (sg_s0_axis_aclk        ),
      .sg_s0_axis_aresetn        (s_ps_dma_aresetn       ),
      .sg_s0_axis_tdata          (sg_s0_axis_tdata       ),
      .sg_s0_axis_tvalid         (sg_s0_axis_tvalid      ),
      .sg_s0_axis_tready         (sg_s0_axis_tready      ),

      // Signal Generator to DAC interface
      .axis_sg_dac_tready        (axis_sg_dac_tready     ),
      .axis_sg_dac_tvalid        (axis_sg_dac_tvalid     ),
      .axis_sg_dac_tdata         (axis_sg_dac_tdata      ),

      // ADC to Readout interface
      .axis_adc_ro_tready        (axis_adc_ro_tready     ),
      .axis_adc_ro_tvalid        (axis_adc_ro_tvalid     ),
      .axis_adc_ro_tdata         (axis_adc_ro_tdata      ),

      // Readout Averaged Buffer AXIS
      .m0_axis_buf_avg_tready    (1'b1                   ),
      .m0_axis_buf_avg_tvalid    (                       ),
      .m0_axis_buf_avg_tdata     (                       ),

      // Readout Decimated Buffer AXIS
      .m1_axis_buf_dec_tready    (m1_axis_buf_dec_tready ),
      .m1_axis_buf_dec_tvalid    (                       ),
      .m1_axis_buf_dec_tdata     (                       )
   );


   //--------------------------------------
   // TODO: RF DATA CONVERTER IP
   //--------------------------------------

   // DAC-ADC RF frontend model

   localparam DAC_W = 16;
   logic signed [DAC_W-1:0] dac_data;
   localparam ADC_W = 14;
   logic signed [ADC_W-1:0] adc_sample;
   logic signed [15:0] adc_data;

   model_DAC_ADC #(
      .DAC_W               (DAC_W),
      .ADC_W               (ADC_W),
      .BUFFER_SIZE         (16)
   ) u_model_DAC_ADC (
      .clk_DAC             (dac_fs),
      .dac_sample          (dac_data),

      .clk_ADC             (adc_fs),
      .adc_sample          (adc_sample),

      .mode                (1)   // 0 = ZOH, 1 = linear
   );

   // SG to DAC RF processes 16 samples per clock

   assign axis_sg_dac_tready        = 1'b1;  // DAC always ready to receive samples

   logic [$clog2(N_DDS_SG)-1:0] dac_samp_cnt;
   always @(posedge dac_fs) begin
      if (axis_sg_dac_tvalid) begin
         dac_data       <= axis_sg_dac_tdata[16*dac_samp_cnt +: 16];
         dac_samp_cnt   <= dac_samp_cnt + 'd1;
      end
      else begin
         dac_data       <= 'd0;
         dac_samp_cnt   <= 'd0;
      end
   end


   // ADC RF to RO processes 8 samples per clock

   assign adc_data = $signed(adc_sample);

   logic [$clog2(N_DDS_RO)-1:0] adc_samp_cnt;
   always @(posedge adc_fs) begin
      if (adc_samp_cnt < N_DDS_RO-1) begin
         adc_samp_cnt      <= adc_samp_cnt + 1;
         rf_signal_valid   <= 0;
      end
      else begin
         adc_samp_cnt      <= 0;
         rf_signal_valid   <= 1;
      end
      rf_signal_data[16*adc_samp_cnt +: 16] <= adc_data;
   end

   // Model Transport delay
   // NOTE: THESE MUST BE REG TO WORK!!!
   reg                    rf_signal_valid_dly;
   reg [N_DDS_RO*16-1:0]  rf_signal_data_dly;
   always @(*) begin
      rf_signal_valid_dly <= #(250ns) rf_signal_valid;
      rf_signal_data_dly  <= #(250ns) rf_signal_data;
   end


   //--------------------------------------
   // WIP: Qubit Emulator
   //--------------------------------------

   wire  [7:0]       s_axi_qemu_araddr;
   wire  [2:0]       s_axi_qemu_arprot;
   wire              s_axi_qemu_arready;
   wire              s_axi_qemu_arvalid;
   wire  [7:0]       s_axi_qemu_awaddr;
   wire  [2:0]       s_axi_qemu_awprot;
   wire              s_axi_qemu_awready;
   wire              s_axi_qemu_awvalid;
   wire              s_axi_qemu_bready;
   wire  [1:0]       s_axi_qemu_bresp;
   wire              s_axi_qemu_bvalid;
   wire  [31:0]      s_axi_qemu_rdata;
   wire              s_axi_qemu_rready;
   wire  [1:0]       s_axi_qemu_rresp;
   wire              s_axi_qemu_rvalid;
   wire  [31:0]      s_axi_qemu_wdata;
   wire              s_axi_qemu_wready;
   wire  [3:0]       s_axi_qemu_wstrb;
   wire              s_axi_qemu_wvalid;
   
   // AXI VIP master address.
   xil_axi_ulong   QEMU_DDS_BVAL_REG     = 4 * 0;
   xil_axi_ulong   QEMU_DDS_SLOPE_REG    = 4 * 1;
   xil_axi_ulong   QEMU_DDS_STEPS_REG    = 4 * 2;
   xil_axi_ulong   QEMU_DDS_WAIT_REG     = 4 * 3;
   xil_axi_ulong   QEMU_DDS_FREQ_REG     = 4 * 4;
   xil_axi_ulong   QEMU_IIR_C0_REG       = 4 * 5;
   xil_axi_ulong   QEMU_IIR_C1_REG       = 4 * 6;
   xil_axi_ulong   QEMU_IIR_G_REG        = 4 * 7;
   xil_axi_ulong   QEMU_OUTSEL_REG       = 4 * 8;
   xil_axi_ulong   QEMU_PUNCT_ID_REG     = 4 * 9;
   xil_axi_ulong   QEMU_ADDR_REG         = 4 * 10;
   xil_axi_ulong   QEMU_WE_REG           = 4 * 11;

   localparam L = 1;
   wire              axis_qemu_ro_tvalid;
   wire [L*2*16-1:0] axis_qemu_ro_tdata;

   axi_mst_0 u_axi_mst_qemu_0 (
      .aclk          (s_ps_dma_aclk       ),
      .aresetn       (s_ps_dma_aresetn    ),
      .m_axi_araddr  (s_axi_qemu_araddr    ),
      .m_axi_arprot  (s_axi_qemu_arprot    ),
      .m_axi_arready (s_axi_qemu_arready   ),
      .m_axi_arvalid (s_axi_qemu_arvalid   ),
      .m_axi_awaddr  (s_axi_qemu_awaddr    ),
      .m_axi_awprot  (s_axi_qemu_awprot    ),
      .m_axi_awready (s_axi_qemu_awready   ),
      .m_axi_awvalid (s_axi_qemu_awvalid   ),
      .m_axi_bready  (s_axi_qemu_bready    ),
      .m_axi_bresp   (s_axi_qemu_bresp     ),
      .m_axi_bvalid  (s_axi_qemu_bvalid    ),
      .m_axi_rdata   (s_axi_qemu_rdata     ),
      .m_axi_rready  (s_axi_qemu_rready    ),
      .m_axi_rresp   (s_axi_qemu_rresp     ),
      .m_axi_rvalid  (s_axi_qemu_rvalid    ),
      .m_axi_wdata   (s_axi_qemu_wdata     ),
      .m_axi_wready  (s_axi_qemu_wready    ),
      .m_axi_wstrb   (s_axi_qemu_wstrb     ),
      .m_axi_wvalid  (s_axi_qemu_wvalid    )
   );

   axis_kidsim_v3 #(
      .L                      (L)   // Number of lanes.
   )
   u_axis_kidsim_v3 (
      // AXI Slave I/F for configuration.
      .s_axi_aclk             (s_ps_dma_aclk       ),
      .s_axi_aresetn          (s_ps_dma_aresetn    ),
      .s_axi_araddr           (s_axi_qemu_araddr   ),
      .s_axi_arprot           (s_axi_qemu_arprot   ),
      .s_axi_arready          (s_axi_qemu_arready  ),
      .s_axi_arvalid          (s_axi_qemu_arvalid  ),
      .s_axi_awaddr           (s_axi_qemu_awaddr   ),
      .s_axi_awprot           (s_axi_qemu_awprot   ),
      .s_axi_awready          (s_axi_qemu_awready  ),
      .s_axi_awvalid          (s_axi_qemu_awvalid  ),
      .s_axi_bready           (s_axi_qemu_bready   ),
      .s_axi_bresp            (s_axi_qemu_bresp    ),
      .s_axi_bvalid           (s_axi_qemu_bvalid   ),
      .s_axi_rdata            (s_axi_qemu_rdata    ),
      .s_axi_rready           (s_axi_qemu_rready   ),
      .s_axi_rresp            (s_axi_qemu_rresp    ),
      .s_axi_rvalid           (s_axi_qemu_rvalid   ),
      .s_axi_wdata            (s_axi_qemu_wdata    ),
      .s_axi_wready           (s_axi_qemu_wready   ),
      .s_axi_wstrb            (s_axi_qemu_wstrb    ),
      .s_axi_wvalid           (s_axi_qemu_wvalid   ),

      // Modulation trigger.
      .trigger                (trigger_0           ),

      // Reset and clock for axis_*.
      .aresetn                (s_ps_dma_aresetn    ),
      .aclk                   (adc_fs             ),

      // s_axis_* for input.
      .s_axis_tvalid          (1'b1),
      // .s_axis_tdata           ({adc_data_imag,adc_data_real}),   // width: 32*L, should be I/Q from input ADC
      .s_axis_tdata           ({16'd0,adc_data}),   // width: 32*L, should be I/Q from input ADC
      .s_axis_tlast           (1'b1),

      // m_axis_* for output.
      .m_axis_tvalid          (axis_qemu_ro_tvalid ),
      .m_axis_tdata           (axis_qemu_ro_tdata  ),   // width: 32*L, should be I/Q to output DAC
      .m_axis_tlast           ()
   );


   // Sample RF signal with ADC/RO clock - 8 real samples per RO clock
   // always_ff @(posedge ro_clk) begin
   //    if (TEST_OUT_CONNECTION == "TEST_OUT_LOOPBACK") begin
   //       axis_adc_ro_tvalid                  <= rf_signal_valid_dly;
   //       axis_adc_ro_tdata[N_DDS_RO*16-1:0]  <= rf_signal_data_dly;
   //    end
   //    else if (TEST_OUT_CONNECTION == "TEST_OUT_QEMU") begin
   //       axis_adc_ro_tvalid                  <= axis_qemu_ro_tvalid;
   //       for (int i=0; i<N_DDS_RO; i=i+1) begin
   //          axis_adc_ro_tdata[i*16 +: 16]  <= axis_qemu_ro_tdata[15:0];
   //       end
   //    end
   // end

   logic [2:0] rf_signal_cnt;
   always_ff @(posedge adc_fs) begin
      if (TEST_OUT_CONNECTION == "TEST_OUT_LOOPBACK") begin
         if (rf_signal_cnt == 0) begin
            axis_adc_ro_tvalid                  <= rf_signal_valid_dly;
            axis_adc_ro_tdata[N_DDS_RO*16-1:0]  <= rf_signal_data_dly;
         end
         else begin
         end
         if (rf_signal_valid_dly || axis_adc_ro_tvalid) begin
            rf_signal_cnt  <= rf_signal_cnt + 1;
         end
         else begin
            rf_signal_cnt  <= 0;
         end
      end
   end



`include "tb_qick_stimuli.svh"


`include "tb_qick_tasks.svh"

endmodule
