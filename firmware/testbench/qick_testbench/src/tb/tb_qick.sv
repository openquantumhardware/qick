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
   forever # (T_SG_CLK*1.0ns/N_DDS) dac_fs_gen = dac_fs_gen + 'd1;
end
assign dac_fs  = dac_fs_gen[0];
assign sg_clk  = dac_fs_gen[4];

initial begin
   adc_fs_gen = 'd0;
   forever # (T_RO_CLK*1.0ns/8.0) adc_fs_gen = adc_fs_gen + 'd1;
end
assign adc_fs  = adc_fs_gen[0];
assign ro_clk  = adc_fs_gen[3];


//////////////////////////////////////////////////////////////////////////
//  RST Generation
logic rst_ni;
assign s_ps_dma_aresetn  = rst_ni;

wire  s_ps_dma_aresetn;

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

// Signal Generator Path signals
wire [167:0]       tproc_sgcdc_0_axis_tdata ;
wire               tproc_sgcdc_0_axis_tvalid;
logic              tproc_sgcdc_0_axis_tready;

wire [167:0]       sgcdc_sgt_0_axis_tdata ;
wire               sgcdc_sgt_0_axis_tvalid;
logic              sgcdc_sgt_0_axis_tready;

wire [159:0]       sgt_sg_0_axis_tdata ;
wire               sgt_sg_0_axis_tvalid;
logic              sgt_sg_0_axis_tready;

// Readout Path signals
wire [167:0]       tproc_rocdc_0_axis_tdata ;
wire               tproc_rocdc_0_axis_tvalid;
logic              tproc_rocdc_0_axis_tready;

wire [167:0]       rocdc_rot_0_axis_tdata ;
wire               rocdc_rot_0_axis_tvalid;
logic              rocdc_rot_0_axis_tready;

wire [87:0]        rot_ro_0_axis_tdata ;
wire               rot_ro_0_axis_tvalid;
logic              rot_ro_0_axis_tready;

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
   logic                   axis_sg_dac_tready;
   logic                   axis_sg_dac_tvalid;
   logic [N_DDS*16-1:0]    axis_sg_dac_tdata;

   logic                   rf_signal_valid;
   logic [8*16-1:0]        rf_signal_data;

   logic                   axis_adc_ro_tready;
   logic                   axis_adc_ro_tvalid;
   logic [8*16-1:0]        axis_adc_ro_tdata;


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



   //--------------------------------------
   // QICK DUT
   //--------------------------------------

   qick_dut qick_dut (
      // Core, Time and AXI CLK & RST.
      .t_clk_i             ( t_clk              ) ,
      .t_resetn            ( rst_ni             ) ,
      .c_clk_i             ( c_clk              ) ,
      .c_resetn            ( rst_ni             ) ,
      .ps_clk_i            ( s_ps_dma_aclk      ) ,
      .ps_resetn           ( s_ps_dma_aresetn   ) ,
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
      // // AXI-Lite DATA Slave I/F.
      // .s_axi_awaddr         ( s_axi_tproc_awaddr[7:0]   ) ,
      // .s_axi_awprot         ( s_axi_tproc_awprot        ) ,
      // .s_axi_awvalid        ( s_axi_tproc_awvalid       ) ,
      // .s_axi_awready        ( s_axi_tproc_awready       ) ,
      // .s_axi_wdata          ( s_axi_tproc_wdata         ) ,
      // .s_axi_wstrb          ( s_axi_tproc_wstrb         ) ,
      // .s_axi_wvalid         ( s_axi_tproc_wvalid        ) ,
      // .s_axi_wready         ( s_axi_tproc_wready        ) ,
      // .s_axi_bresp          ( s_axi_tproc_bresp         ) ,
      // .s_axi_bvalid         ( s_axi_tproc_bvalid        ) ,
      // .s_axi_bready         ( s_axi_tproc_bready        ) ,
      // .s_axi_araddr         ( s_axi_tproc_araddr[7:0]   ) ,
      // .s_axi_arprot         ( s_axi_tproc_arprot        ) ,
      // .s_axi_arvalid        ( s_axi_tproc_arvalid       ) ,
      // .s_axi_arready        ( s_axi_tproc_arready       ) ,
      // .s_axi_rdata          ( s_axi_tproc_rdata         ) ,
      // .s_axi_rresp          ( s_axi_tproc_rresp         ) ,
      // .s_axi_rvalid         ( s_axi_tproc_rvalid        ) ,
      // .s_axi_rready         ( s_axi_tproc_rready        ) ,
      /// DATA PORT INPUT  
      .s0_axis_tdata        ( port_0_dt_i    ) ,
      .s0_axis_tvalid       ( port_0_vld     ) ,
      .s1_axis_tdata        ( port_1_dt_i    ) ,
      .s1_axis_tvalid       ( s1_axis_tvalid ) ,
      .s2_axis_tdata        ( 64'd2          ) ,
      .s2_axis_tvalid       ( 1'b0           ) ,
      .s3_axis_tdata        ( 64'd3          ) ,
      .s3_axis_tvalid       ( 1'b0           ) ,
      .s4_axis_tdata        ( 64'd4          ) ,
      .s4_axis_tvalid       ( 1'b0           ) ,
      .s5_axis_tdata        ( 64'd5          ) ,
      .s5_axis_tvalid       ( 1'b0           ) ,
      .s6_axis_tdata        ( 64'd6          ) ,
      .s6_axis_tvalid       ( 1'b0           ) ,
      .s7_axis_tdata        ( 64'd7          ) ,
      .s7_axis_tvalid       ( 1'b0           ) ,
      // OUT WAVE PORTS
      .m0_axis_tdata        ( tproc_sgcdc_0_axis_tdata  ) ,
      .m0_axis_tvalid       ( tproc_sgcdc_0_axis_tvalid ) ,
      .m0_axis_tready       ( tproc_sgcdc_0_axis_tready ) ,
      .m1_axis_tdata        ( /*m1_axis_tdata*/       ) ,
      .m1_axis_tvalid       ( /*m1_axis_tvalid*/      ) ,
      .m1_axis_tready       ( m1_axis_tready          ) ,
      .m2_axis_tdata        ( /*m2_axis_tdata*/       ) ,
      .m2_axis_tvalid       ( /*m2_axis_tvalid*/      ) ,
      .m2_axis_tready       ( m2_axis_tready          ) ,
      .m3_axis_tdata        ( /*m3_axis_tdata*/       ) ,
      .m3_axis_tvalid       ( /*m3_axis_tvalid*/      ) ,
      .m3_axis_tready       ( m3_axis_tready          ) ,
      .m4_axis_tdata        ( tproc_rocdc_0_axis_tdata  ) ,
      .m4_axis_tvalid       ( tproc_rocdc_0_axis_tvalid ) ,
      .m4_axis_tready       ( tproc_rocdc_0_axis_tready ) ,
      .m5_axis_tdata        ( /*m5_axis_tdata*/       ) ,
      .m5_axis_tvalid       ( /*m5_axis_tvalid*/      ) ,
      .m5_axis_tready       ( m5_axis_tready          ) ,
      .m6_axis_tdata        ( /*m6_axis_tdata*/       ) ,
      .m6_axis_tvalid       ( /*m6_axis_tvalid*/      ) ,
      .m6_axis_tready       ( m6_axis_tready          ) ,
      .m7_axis_tdata        ( /*m7_axis_tdata*/       ) ,
      .m7_axis_tvalid       ( /*m7_axis_tvalid*/      ) ,
      .m7_axis_tready       ( m7_axis_tready          ) ,
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
      .c_core_do            ( )
   );

   //--------------------------------------
   // SIGNAL GENERATOR
   //--------------------------------------

   wire  [5:0]       s_axi_sg_araddr;
   wire  [2:0]       s_axi_sg_arprot;
   wire              s_axi_sg_arready;
   wire              s_axi_sg_arvalid;
   wire  [5:0]       s_axi_sg_awaddr;
   wire  [2:0]       s_axi_sg_awprot;
   wire              s_axi_sg_awready;
   wire              s_axi_sg_awvalid;
   wire              s_axi_sg_bready;
   wire  [1:0]       s_axi_sg_bresp;
   wire              s_axi_sg_bvalid;
   wire  [31:0]      s_axi_sg_rdata;
   wire              s_axi_sg_rready;
   wire  [1:0]       s_axi_sg_rresp;
   wire              s_axi_sg_rvalid;
   wire  [31:0]      s_axi_sg_wdata;
   wire              s_axi_sg_wready;
   wire  [3:0]       s_axi_sg_wstrb;
   wire              s_axi_sg_wvalid;

   // AXI VIP master address.
   xil_axi_ulong     SG_ADDR_START_ADDR   = 32'h40000000; // 0
   xil_axi_ulong     SG_ADDR_WE           = 32'h40000004; // 1

   xil_axi_prot_t    prot                 = 0;
   reg [31:0]        data_wr              = 32'h12345678;
   reg [31:0]        data;
   xil_axi_resp_t    resp;



   axi_mst_0 u_axi_mst_sg_0 (
      .aclk          (s_ps_dma_aclk    ),
      .aresetn       (s_ps_dma_aresetn ),
      .m_axi_araddr  (s_axi_sg_araddr  ),
      .m_axi_arprot  (s_axi_sg_arprot  ),
      .m_axi_arready (s_axi_sg_arready ),
      .m_axi_arvalid (s_axi_sg_arvalid ),
      .m_axi_awaddr  (s_axi_sg_awaddr  ),
      .m_axi_awprot  (s_axi_sg_awprot  ),
      .m_axi_awready (s_axi_sg_awready ),
      .m_axi_awvalid (s_axi_sg_awvalid ),
      .m_axi_bready  (s_axi_sg_bready  ),
      .m_axi_bresp   (s_axi_sg_bresp   ),
      .m_axi_bvalid  (s_axi_sg_bvalid  ),
      .m_axi_rdata   (s_axi_sg_rdata   ),
      .m_axi_rready  (s_axi_sg_rready  ),
      .m_axi_rresp   (s_axi_sg_rresp   ),
      .m_axi_rvalid  (s_axi_sg_rvalid  ),
      .m_axi_wdata   (s_axi_sg_wdata   ),
      .m_axi_wready  (s_axi_sg_wready  ),
      .m_axi_wstrb   (s_axi_sg_wstrb   ),
      .m_axi_wvalid  (s_axi_sg_wvalid  )
   );

   wire sg_s0_axis_aclk = s_ps_dma_aclk;
   logic   [31:0]       sg_s0_axis_tdata;
   logic                sg_s0_axis_tready;
   logic                sg_s0_axis_tvalid;

   logic tb_load_mem, tb_load_mem_done;


   axis_cdcsync_v1 #(
      .N                         (1),     // Number of inputs/outputs.
      .B                         (168)    // Number of data bits.
   )
   u_axis_sgcdcsync_v1 (
      // S_AXIS for input data.
      .s_axis_aresetn            (rst_ni),
      .s_axis_aclk               (t_clk),
      .s0_axis_tready            (tproc_sgcdc_0_axis_tready),
      .s0_axis_tvalid            (tproc_sgcdc_0_axis_tvalid),
      .s0_axis_tdata             (tproc_sgcdc_0_axis_tdata),
      .s1_axis_tready            (/*s1_axis_tready*/),
      .s1_axis_tvalid            (/*s1_axis_tvalid*/),
      .s1_axis_tdata             (/*s1_axis_tdata*/),
      .s2_axis_tready            (/*s2_axis_tready*/),
      .s2_axis_tvalid            (/*s2_axis_tvalid*/),
      .s2_axis_tdata             (/*s2_axis_tdata*/),
      .s3_axis_tready            (/*s3_axis_tready*/),
      .s3_axis_tvalid            (/*s3_axis_tvalid*/),
      .s3_axis_tdata             (/*s3_axis_tdata*/),
      .s4_axis_tready            (/*s4_axis_tready*/),
      .s4_axis_tvalid            (/*s4_axis_tvalid*/),
      .s4_axis_tdata             (/*s4_axis_tdata*/),
      .s5_axis_tready            (/*s5_axis_tready*/),
      .s5_axis_tvalid            (/*s5_axis_tvalid*/),
      .s5_axis_tdata             (/*s5_axis_tdata*/),
      .s6_axis_tready            (/*s6_axis_tready*/),
      .s6_axis_tvalid            (/*s6_axis_tvalid*/),
      .s6_axis_tdata             (/*s6_axis_tdata*/),
      .s7_axis_tready            (/*s7_axis_tready*/),
      .s7_axis_tvalid            (/*s7_axis_tvalid*/),
      .s7_axis_tdata             (/*s7_axis_tdata*/),
      .s8_axis_tready            (/*s8_axis_tready*/),
      .s8_axis_tvalid            (/*s8_axis_tvalid*/),
      .s8_axis_tdata             (/*s8_axis_tdata*/),
      .s9_axis_tready            (/*s9_axis_tready*/),
      .s9_axis_tvalid            (/*s9_axis_tvalid*/),
      .s9_axis_tdata             (/*s9_axis_tdata*/),
      .s10_axis_tready           (/*s10_axis_tready*/),
      .s10_axis_tvalid           (/*s10_axis_tvalid*/),
      .s10_axis_tdata            (/*s10_axis_tdata*/),
      .s11_axis_tready           (/*s11_axis_tready*/),
      .s11_axis_tvalid           (/*s11_axis_tvalid*/),
      .s11_axis_tdata            (/*s11_axis_tdata*/),
      .s12_axis_tready           (/*s12_axis_tready*/),
      .s12_axis_tvalid           (/*s12_axis_tvalid*/),
      .s12_axis_tdata            (/*s12_axis_tdata*/),
      .s13_axis_tready           (/*s13_axis_tready*/),
      .s13_axis_tvalid           (/*s13_axis_tvalid*/),
      .s13_axis_tdata            (/*s13_axis_tdata*/),
      .s14_axis_tready           (/*s14_axis_tready*/),
      .s14_axis_tvalid           (/*s14_axis_tvalid*/),
      .s14_axis_tdata            (/*s14_axis_tdata*/),
      .s15_axis_tready           (/*s15_axis_tready*/),
      .s15_axis_tvalid           (/*s15_axis_tvalid*/),
      .s15_axis_tdata            (/*s15_axis_tdata*/),
      // M_AXIS for output data.
      .m_axis_aresetn            (rst_ni),
      .m_axis_aclk               (sg_clk),
      .m0_axis_tready            (sgcdc_sgt_0_axis_tready),
      .m0_axis_tvalid            (sgcdc_sgt_0_axis_tvalid),
      .m0_axis_tdata             (sgcdc_sgt_0_axis_tdata),
      .m1_axis_tready            (/*m1_axis_tready*/),
      .m1_axis_tvalid            (/*m1_axis_tvalid*/),
      .m1_axis_tdata             (/*m1_axis_tdata*/),
      .m2_axis_tready            (/*m2_axis_tready*/),
      .m2_axis_tvalid            (/*m2_axis_tvalid*/),
      .m2_axis_tdata             (/*m2_axis_tdata*/),
      .m3_axis_tready            (/*m3_axis_tready*/),
      .m3_axis_tvalid            (/*m3_axis_tvalid*/),
      .m3_axis_tdata             (/*m3_axis_tdata*/),
      .m4_axis_tready            (/*m4_axis_tready*/),
      .m4_axis_tvalid            (/*m4_axis_tvalid*/),
      .m4_axis_tdata             (/*m4_axis_tdata*/),
      .m5_axis_tready            (/*m5_axis_tready*/),
      .m5_axis_tvalid            (/*m5_axis_tvalid*/),
      .m5_axis_tdata             (/*m5_axis_tdata*/),
      .m6_axis_tready            (/*m6_axis_tready*/),
      .m6_axis_tvalid            (/*m6_axis_tvalid*/),
      .m6_axis_tdata             (/*m6_axis_tdata*/),
      .m7_axis_tready            (/*m7_axis_tready*/),
      .m7_axis_tvalid            (/*m7_axis_tvalid*/),
      .m7_axis_tdata             (/*m7_axis_tdata*/),
      .m8_axis_tready            (/*m8_axis_tready*/),
      .m8_axis_tvalid            (/*m8_axis_tvalid*/),
      .m8_axis_tdata             (/*m8_axis_tdata*/),
      .m9_axis_tready            (/*m9_axis_tready*/),
      .m9_axis_tvalid            (/*m9_axis_tvalid*/),
      .m9_axis_tdata             (/*m9_axis_tdata*/),
      .m10_axis_tready           (/*m10_axis_tready*/),
      .m10_axis_tvalid           (/*m10_axis_tvalid*/),
      .m10_axis_tdata            (/*m10_axis_tdata*/),
      .m11_axis_tready           (/*m11_axis_tready*/),
      .m11_axis_tvalid           (/*m11_axis_tvalid*/),
      .m11_axis_tdata            (/*m11_axis_tdata*/),
      .m12_axis_tready           (/*m12_axis_tready*/),
      .m12_axis_tvalid           (/*m12_axis_tvalid*/),
      .m12_axis_tdata            (/*m12_axis_tdata*/),
      .m13_axis_tready           (/*m13_axis_tready*/),
      .m13_axis_tvalid           (/*m13_axis_tvalid*/),
      .m13_axis_tdata            (/*m13_axis_tdata*/),
      .m14_axis_tready           (/*m14_axis_tready*/),
      .m14_axis_tvalid           (/*m14_axis_tvalid*/),
      .m14_axis_tdata            (/*m14_axis_tdata*/),
      .m15_axis_tready           (/*m15_axis_tready*/),
      .m15_axis_tvalid           (/*m15_axis_tvalid*/),
      .m15_axis_tdata            (/*m15_axis_tdata*/)
   );


   sg_translator # (
      .OUT_TYPE               (0) // (0:gen_v6, 1:int4_v1, 2:mux4_v1, 3:readout)
   ) 
   u_sg_translator_0 (
      // Reset and clock.
      .aresetn                (1'bx),  // not used
      .aclk                   (1'bx),  // not used
      // IN WAVE PORT
      .s_axis_tdata           (sgcdc_sgt_0_axis_tdata),
      .s_axis_tvalid          (sgcdc_sgt_0_axis_tvalid),
      .s_axis_tready          (sgcdc_sgt_0_axis_tready),
      // OUT DATA gen_v6 (SEL:0)
      .m_gen_v6_axis_tdata    (sgt_sg_0_axis_tdata),
      .m_gen_v6_axis_tvalid   (sgt_sg_0_axis_tvalid),
      .m_gen_v6_axis_tready   (sgt_sg_0_axis_tready),
      // OUT DATA int4_v1 (SEL:1)
      .m_int4_axis_tdata      (),
      .m_int4_axis_tvalid     (),
      .m_int4_axis_tready     (),
      // OUT DATA mux4_v1 (SEL:2)
      .m_mux4_axis_tdata      (),
      .m_mux4_axis_tvalid     (),
      .m_mux4_axis_tready     (),
      // OUT DATA readout_v3 (SEL:3)
      .m_readout_axis_tdata   (),
      .m_readout_axis_tvalid  (),
      .m_readout_axis_tready  ()
   );

   // axis_signal_gen_v6_0 parameters
   localparam N       = 10;
   localparam N_DDS   = 16;

   axis_signal_gen_v6 #(
      .N                   (N                ),
      .N_DDS               (N_DDS            ),
      .GEN_DDS             ("TRUE"           ),
      // .GEN_DDS             ("FALSE"           ),
      .ENVELOPE_TYPE       ("COMPLEX"        )
   )
   u_axis_signal_gen_v6_0 ( 
      // AXI Slave I/F for configuration.
      .s_axi_aclk          (s_ps_dma_aclk    ),
      .s_axi_aresetn       (s_ps_dma_aresetn ),
      .s_axi_araddr        (s_axi_sg_araddr  ),
      .s_axi_arprot        (s_axi_sg_arprot  ),
      .s_axi_arready       (s_axi_sg_arready ),
      .s_axi_arvalid       (s_axi_sg_arvalid ),
      .s_axi_awaddr        (s_axi_sg_awaddr  ),
      .s_axi_awprot        (s_axi_sg_awprot  ),
      .s_axi_awready       (s_axi_sg_awready ),
      .s_axi_awvalid       (s_axi_sg_awvalid ),
      .s_axi_bready        (s_axi_sg_bready  ),
      .s_axi_bresp         (s_axi_sg_bresp   ),
      .s_axi_bvalid        (s_axi_sg_bvalid  ),
      .s_axi_rdata         (s_axi_sg_rdata   ),
      .s_axi_rready        (s_axi_sg_rready  ),
      .s_axi_rresp         (s_axi_sg_rresp   ),
      .s_axi_rvalid        (s_axi_sg_rvalid  ),
      .s_axi_wdata         (s_axi_sg_wdata   ),
      .s_axi_wready        (s_axi_sg_wready  ),
      .s_axi_wstrb         (s_axi_sg_wstrb   ),
      .s_axi_wvalid        (s_axi_sg_wvalid  ),

      // AXIS Slave to load data into memory.
      .s0_axis_aclk        (s_ps_dma_aclk      ),
      .s0_axis_aresetn     (s_ps_dma_aresetn   ),
      .s0_axis_tdata       (sg_s0_axis_tdata   ),
      .s0_axis_tvalid      (sg_s0_axis_tvalid  ),
      .s0_axis_tready      (sg_s0_axis_tready  ),

      // s1_* and m_* reset/clock.
      .aresetn             (rst_ni           ),
      .aclk                (sg_clk           ),

      // AXIS Slave to queue waveforms - From TPROC
      .s1_axis_tdata       (sgt_sg_0_axis_tdata    ),
      .s1_axis_tvalid      (sgt_sg_0_axis_tvalid   ),
      .s1_axis_tready      (sgt_sg_0_axis_tready   ),

      // AXIS Master for output data.
      .m_axis_tready       (axis_sg_dac_tready      ),
      .m_axis_tvalid       (axis_sg_dac_tvalid      ),
      .m_axis_tdata        (axis_sg_dac_tdata       )
   );


   // For Waveform Debug
   logic signed [15:0] axis_sg_dac_tdata_dbg [0:N_DDS-1];
   always @* begin
      for (int i=0; i<N_DDS; i=i+1) begin
         axis_sg_dac_tdata_dbg[i] = axis_sg_dac_tdata[16*i +: 16];
      end
   end


   //--------------------------------------
   // TODO: RF DATA CONVERTER IP
   //--------------------------------------

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

   assign adc_data = $signed(adc_sample);

   logic [$clog2(N_DDS)-1:0] dac_samp_cnt;
   always @(posedge dac_fs) begin
      if (axis_sg_dac_tvalid) begin
         dac_data       <= axis_sg_dac_tdata[ 16*dac_samp_cnt +: 16];
         dac_samp_cnt   <= dac_samp_cnt + 'd1;
      end
      else begin
         dac_data       <= 'd0;
         dac_samp_cnt   <= 'd0;
      end
   end

   // SG to DAC RF processes 16 samples per clock
   // ADC RF to RO processes 8 samples per clock

   assign axis_sg_dac_tready        = 1'b1;  // DAC always ready to receive samples

   logic [$clog2(N_DDS)-1:0] adc_samp_cnt;
   always @(posedge adc_fs) begin
      if (adc_samp_cnt < 7) begin
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
   reg [8*16-1:0]         rf_signal_data_dly;
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


   localparam N_DDS_RO = 8;

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

   // For Waveform Debug
   logic signed [15:0] axis_adc_ro_tdata_dbg [0:N_DDS_RO-1];
   always @* begin
      for (int i=0; i < N_DDS_RO; i=i+1) begin
         axis_adc_ro_tdata_dbg[i] = axis_adc_ro_tdata[16*i +: 16];
      end
   end

   //--------------------------------------
   // READOUT
   //--------------------------------------

   axis_cdcsync_v1 #(
      .N                         (1),     // Number of inputs/outputs.
      .B                         (168)    // Number of data bits.
   )
   u_axis_cdcsync_v1 (
      // S_AXIS for input data.
      .s_axis_aresetn            (rst_ni),
      .s_axis_aclk               (t_clk),
      .s0_axis_tready            (tproc_rocdc_0_axis_tready),
      .s0_axis_tvalid            (tproc_rocdc_0_axis_tvalid),
      .s0_axis_tdata             (tproc_rocdc_0_axis_tdata),
      .s1_axis_tready            (/*s1_axis_tready*/),
      .s1_axis_tvalid            (/*s1_axis_tvalid*/),
      .s1_axis_tdata             (/*s1_axis_tdata*/),
      .s2_axis_tready            (/*s2_axis_tready*/),
      .s2_axis_tvalid            (/*s2_axis_tvalid*/),
      .s2_axis_tdata             (/*s2_axis_tdata*/),
      .s3_axis_tready            (/*s3_axis_tready*/),
      .s3_axis_tvalid            (/*s3_axis_tvalid*/),
      .s3_axis_tdata             (/*s3_axis_tdata*/),
      .s4_axis_tready            (/*s4_axis_tready*/),
      .s4_axis_tvalid            (/*s4_axis_tvalid*/),
      .s4_axis_tdata             (/*s4_axis_tdata*/),
      .s5_axis_tready            (/*s5_axis_tready*/),
      .s5_axis_tvalid            (/*s5_axis_tvalid*/),
      .s5_axis_tdata             (/*s5_axis_tdata*/),
      .s6_axis_tready            (/*s6_axis_tready*/),
      .s6_axis_tvalid            (/*s6_axis_tvalid*/),
      .s6_axis_tdata             (/*s6_axis_tdata*/),
      .s7_axis_tready            (/*s7_axis_tready*/),
      .s7_axis_tvalid            (/*s7_axis_tvalid*/),
      .s7_axis_tdata             (/*s7_axis_tdata*/),
      .s8_axis_tready            (/*s8_axis_tready*/),
      .s8_axis_tvalid            (/*s8_axis_tvalid*/),
      .s8_axis_tdata             (/*s8_axis_tdata*/),
      .s9_axis_tready            (/*s9_axis_tready*/),
      .s9_axis_tvalid            (/*s9_axis_tvalid*/),
      .s9_axis_tdata             (/*s9_axis_tdata*/),
      .s10_axis_tready           (/*s10_axis_tready*/),
      .s10_axis_tvalid           (/*s10_axis_tvalid*/),
      .s10_axis_tdata            (/*s10_axis_tdata*/),
      .s11_axis_tready           (/*s11_axis_tready*/),
      .s11_axis_tvalid           (/*s11_axis_tvalid*/),
      .s11_axis_tdata            (/*s11_axis_tdata*/),
      .s12_axis_tready           (/*s12_axis_tready*/),
      .s12_axis_tvalid           (/*s12_axis_tvalid*/),
      .s12_axis_tdata            (/*s12_axis_tdata*/),
      .s13_axis_tready           (/*s13_axis_tready*/),
      .s13_axis_tvalid           (/*s13_axis_tvalid*/),
      .s13_axis_tdata            (/*s13_axis_tdata*/),
      .s14_axis_tready           (/*s14_axis_tready*/),
      .s14_axis_tvalid           (/*s14_axis_tvalid*/),
      .s14_axis_tdata            (/*s14_axis_tdata*/),
      .s15_axis_tready           (/*s15_axis_tready*/),
      .s15_axis_tvalid           (/*s15_axis_tvalid*/),
      .s15_axis_tdata            (/*s15_axis_tdata*/),
      // M_AXIS for output data.
      .m_axis_aresetn            (rst_ni),
      .m_axis_aclk               (ro_clk),
      .m0_axis_tready            (rocdc_rot_0_axis_tready),
      .m0_axis_tvalid            (rocdc_rot_0_axis_tvalid),
      .m0_axis_tdata             (rocdc_rot_0_axis_tdata),
      .m1_axis_tready            (/*m1_axis_tready*/),
      .m1_axis_tvalid            (/*m1_axis_tvalid*/),
      .m1_axis_tdata             (/*m1_axis_tdata*/),
      .m2_axis_tready            (/*m2_axis_tready*/),
      .m2_axis_tvalid            (/*m2_axis_tvalid*/),
      .m2_axis_tdata             (/*m2_axis_tdata*/),
      .m3_axis_tready            (/*m3_axis_tready*/),
      .m3_axis_tvalid            (/*m3_axis_tvalid*/),
      .m3_axis_tdata             (/*m3_axis_tdata*/),
      .m4_axis_tready            (/*m4_axis_tready*/),
      .m4_axis_tvalid            (/*m4_axis_tvalid*/),
      .m4_axis_tdata             (/*m4_axis_tdata*/),
      .m5_axis_tready            (/*m5_axis_tready*/),
      .m5_axis_tvalid            (/*m5_axis_tvalid*/),
      .m5_axis_tdata             (/*m5_axis_tdata*/),
      .m6_axis_tready            (/*m6_axis_tready*/),
      .m6_axis_tvalid            (/*m6_axis_tvalid*/),
      .m6_axis_tdata             (/*m6_axis_tdata*/),
      .m7_axis_tready            (/*m7_axis_tready*/),
      .m7_axis_tvalid            (/*m7_axis_tvalid*/),
      .m7_axis_tdata             (/*m7_axis_tdata*/),
      .m8_axis_tready            (/*m8_axis_tready*/),
      .m8_axis_tvalid            (/*m8_axis_tvalid*/),
      .m8_axis_tdata             (/*m8_axis_tdata*/),
      .m9_axis_tready            (/*m9_axis_tready*/),
      .m9_axis_tvalid            (/*m9_axis_tvalid*/),
      .m9_axis_tdata             (/*m9_axis_tdata*/),
      .m10_axis_tready           (/*m10_axis_tready*/),
      .m10_axis_tvalid           (/*m10_axis_tvalid*/),
      .m10_axis_tdata            (/*m10_axis_tdata*/),
      .m11_axis_tready           (/*m11_axis_tready*/),
      .m11_axis_tvalid           (/*m11_axis_tvalid*/),
      .m11_axis_tdata            (/*m11_axis_tdata*/),
      .m12_axis_tready           (/*m12_axis_tready*/),
      .m12_axis_tvalid           (/*m12_axis_tvalid*/),
      .m12_axis_tdata            (/*m12_axis_tdata*/),
      .m13_axis_tready           (/*m13_axis_tready*/),
      .m13_axis_tvalid           (/*m13_axis_tvalid*/),
      .m13_axis_tdata            (/*m13_axis_tdata*/),
      .m14_axis_tready           (/*m14_axis_tready*/),
      .m14_axis_tvalid           (/*m14_axis_tvalid*/),
      .m14_axis_tdata            (/*m14_axis_tdata*/),
      .m15_axis_tready           (/*m15_axis_tready*/),
      .m15_axis_tvalid           (/*m15_axis_tvalid*/),
      .m15_axis_tdata            (/*m15_axis_tdata*/)
   );

   sg_translator # (
      .OUT_TYPE               (3) // (0:gen_v6, 1:int4_v1, 2:mux4_v1, 3:readout)
   ) 
   u_ro_translator_0 (
      // Reset and clock.
      .aresetn                (1'bx),  // not used
      .aclk                   (1'bx),  // not used
      // IN WAVE PORT
      .s_axis_tdata           (rocdc_rot_0_axis_tdata),
      .s_axis_tvalid          (rocdc_rot_0_axis_tvalid),
      .s_axis_tready          (rocdc_rot_0_axis_tready),
      // OUT DATA gen_v6 (SEL:0)
      .m_gen_v6_axis_tready   (),
      .m_gen_v6_axis_tvalid   (),
      .m_gen_v6_axis_tdata    (),
      // OUT DATA int4_v1 (SEL:1)
      .m_int4_axis_tdata      (),
      .m_int4_axis_tvalid     (),
      .m_int4_axis_tready     (),
      // OUT DATA mux4_v1 (SEL:2)
      .m_mux4_axis_tdata      (),
      .m_mux4_axis_tvalid     (),
      .m_mux4_axis_tready     (),
      // OUT DATA readout_v3 (SEL:3)
      .m_readout_axis_tready  (rot_ro_0_axis_tready),
      .m_readout_axis_tvalid  (rot_ro_0_axis_tvalid),
      .m_readout_axis_tdata   (rot_ro_0_axis_tdata)
   );


   wire              axis_ro_avg_tready;
   wire              axis_ro_avg_tvalid;
   wire [31:0]       axis_ro_avg_tdata;

   wire              axis_ro_mrbuf_tvalid;
   wire [8*2*16-1:0] axis_ro_mrbuf_tdata;

   axis_dyn_readout_v1 /*#(
      .N_DDS            (N_DDS)
   )*/
   u_axis_dyn_readout_v1_0 (
      // Reset and clock.
      .aresetn          (s_ps_dma_aresetn),
      .aclk             (ro_clk),

      // s0_axis for pushing waveforms.
      .s0_axis_tready   (rot_ro_0_axis_tready),
      .s0_axis_tvalid   (rot_ro_0_axis_tvalid),
      .s0_axis_tdata    (rot_ro_0_axis_tdata),

      // s1_axis for input data
      .s1_axis_tready   (axis_adc_ro_tready),
      .s1_axis_tvalid   (axis_adc_ro_tvalid),
      .s1_axis_tdata    (axis_adc_ro_tdata),

      // m0_axis to MR_Buffer
      .m0_axis_tready   (1'b1),
      .m0_axis_tvalid   (axis_ro_mrbuf_tvalid),
      .m0_axis_tdata    (axis_ro_mrbuf_tdata),
      
      // m1_axis to avg_buffer
      .m1_axis_tready   (axis_ro_avg_tready),
      .m1_axis_tvalid   (axis_ro_avg_tvalid),
      .m1_axis_tdata    (axis_ro_avg_tdata)
   );

   // For Waveform Debug
   logic signed [15:0] axis_ro_avg_tdata_dbg [0:1];
   logic signed [15:0] axis_ro_mrbuf_tdata_dbg [0:7][0:1];
   always @* begin
      for (int i=0; i<2; i=i+1) begin
         axis_ro_avg_tdata_dbg[i] = axis_ro_avg_tdata[16*i +: 16];
      end
      for (int i=0; i<8; i=i+1) begin
         for (int j=0; j<2; j=j+1) begin
            axis_ro_mrbuf_tdata_dbg[i][j] = axis_ro_mrbuf_tdata[16*(2*i+j) +: 16];
         end
      end
   end

   // For Waveform Debug
   logic signed [32:0] m1_ro_avg_abs_dbg;
   assign m1_ro_avg_abs_dbg = $signed(axis_ro_avg_tdata[15:0])*$signed(axis_ro_avg_tdata[15:0]) + 
                                 $signed(axis_ro_avg_tdata[31:16])*$signed(axis_ro_avg_tdata[31:16]);


   wire  [5:0]       s_axi_avg_araddr;
   wire  [2:0]       s_axi_avg_arprot;
   wire              s_axi_avg_arready;
   wire              s_axi_avg_arvalid;
   wire  [5:0]       s_axi_avg_awaddr;
   wire  [2:0]       s_axi_avg_awprot;
   wire              s_axi_avg_awready;
   wire              s_axi_avg_awvalid;
   wire              s_axi_avg_bready;
   wire  [1:0]       s_axi_avg_bresp;
   wire              s_axi_avg_bvalid;
   wire  [31:0]      s_axi_avg_rdata;
   wire              s_axi_avg_rready;
   wire  [1:0]       s_axi_avg_rresp;
   wire              s_axi_avg_rvalid;
   wire  [31:0]      s_axi_avg_wdata;
   wire              s_axi_avg_wready;
   wire  [3:0]       s_axi_avg_wstrb;
   wire              s_axi_avg_wvalid;
   
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


   axi_mst_0 u_axi_mst_avg_0 (
      .aresetn       (s_ps_dma_aresetn    ),
      .aclk          (s_ps_dma_aclk       ),
      .m_axi_araddr  (s_axi_avg_araddr    ),
      .m_axi_arprot  (s_axi_avg_arprot    ),
      .m_axi_arready (s_axi_avg_arready   ),
      .m_axi_arvalid (s_axi_avg_arvalid   ),
      .m_axi_awaddr  (s_axi_avg_awaddr    ),
      .m_axi_awprot  (s_axi_avg_awprot    ),
      .m_axi_awready (s_axi_avg_awready   ),
      .m_axi_awvalid (s_axi_avg_awvalid   ),
      .m_axi_bready  (s_axi_avg_bready    ),
      .m_axi_bresp   (s_axi_avg_bresp     ),
      .m_axi_bvalid  (s_axi_avg_bvalid    ),
      .m_axi_rdata   (s_axi_avg_rdata     ),
      .m_axi_rready  (s_axi_avg_rready    ),
      .m_axi_rresp   (s_axi_avg_rresp     ),
      .m_axi_rvalid  (s_axi_avg_rvalid    ),
      .m_axi_wdata   (s_axi_avg_wdata     ),
      .m_axi_wready  (s_axi_avg_wready    ),
      .m_axi_wstrb   (s_axi_avg_wstrb     ),
      .m_axi_wvalid  (s_axi_avg_wvalid    )
   );

   wire        m0_axis_buf_avg_tvalid;
   wire [63:0] m0_axis_buf_avg_tdata;

   logic       m1_axis_buf_dec_tready;
   wire        m1_axis_buf_dec_tvalid;
   wire [31:0] m1_axis_buf_dec_tdata;

   axis_avg_buffer #(
      .N_AVG                  (13               ),
      .N_BUF                  (12               ),
      .B                      (16               )
   )
   u_axis_avg_buffer_0 ( 
      // AXI Slave I/F for configuration.
      .s_axi_aclk             (s_ps_dma_aclk       ),
      .s_axi_aresetn          (s_ps_dma_aresetn    ),
      .s_axi_araddr           (s_axi_avg_araddr    ),
      .s_axi_arprot           (s_axi_avg_arprot    ),
      .s_axi_arready          (s_axi_avg_arready   ),
      .s_axi_arvalid          (s_axi_avg_arvalid   ),
      .s_axi_awaddr           (s_axi_avg_awaddr    ),
      .s_axi_awprot           (s_axi_avg_awprot    ),
      .s_axi_awready          (s_axi_avg_awready   ),
      .s_axi_awvalid          (s_axi_avg_awvalid   ),
      .s_axi_bready           (s_axi_avg_bready    ),
      .s_axi_bresp            (s_axi_avg_bresp     ),
      .s_axi_bvalid           (s_axi_avg_bvalid    ),
      .s_axi_rdata            (s_axi_avg_rdata     ),
      .s_axi_rready           (s_axi_avg_rready    ),
      .s_axi_rresp            (s_axi_avg_rresp     ),
      .s_axi_rvalid           (s_axi_avg_rvalid    ),
      .s_axi_wdata            (s_axi_avg_wdata     ),
      .s_axi_wready           (s_axi_avg_wready    ),
      .s_axi_wstrb            (s_axi_avg_wstrb     ),
      .s_axi_wvalid           (s_axi_avg_wvalid    ),

      // Trigger input.
      .trigger                (trigger_0           ),

      // AXIS Slave for input data.
      .s_axis_aresetn         (s_ps_dma_aresetn      ),
      .s_axis_aclk            (ro_clk                ),
      .s_axis_tready          (axis_ro_avg_tready    ),
      .s_axis_tvalid          (axis_ro_avg_tvalid    ),
      .s_axis_tdata           (axis_ro_avg_tdata     ),

      // Reset and clock for m0 and m1.
      .m_axis_aclk            (s_ps_dma_aclk         ),
      .m_axis_aresetn         (s_ps_dma_aresetn      ),

      // AXIS Master for averaged output.
      .m0_axis_tready         (1'b1/*m0_axis_tready*/),
      .m0_axis_tvalid         (m0_axis_buf_avg_tvalid),
      .m0_axis_tdata          (m0_axis_buf_avg_tdata ),
      .m0_axis_tlast          (/*m0_axis_tlast*/     ),

      // AXIS Master for decimated output.
      .m1_axis_tready         (m1_axis_buf_dec_tready),
      .m1_axis_tvalid         (m1_axis_buf_dec_tvalid),
      .m1_axis_tdata          (m1_axis_buf_dec_tdata ),
      .m1_axis_tlast          (/*m1_axis_tlast*/     ),

      // AXIS Master for register output.
      .m2_axis_tready         (1'b1/*m2_axis_tready*/),
      .m2_axis_tvalid         (/*m2_axis_tvalid*/    ),
      .m2_axis_tdata          (/*m2_axis_tdata*/     )
   );

   logic [64:0] buf_avg_abs_dbg;
   always @(posedge s_ps_dma_aclk) begin
      if (m0_axis_buf_avg_tvalid) begin
         buf_avg_abs_dbg = $signed(m0_axis_buf_avg_tdata[31:0]) * $signed(m0_axis_buf_avg_tdata[31:0]) + 
                              $signed(m0_axis_buf_avg_tdata[63:32]) * $signed(m0_axis_buf_avg_tdata[63:32]);
      end
   end

   logic [32:0] buf_dec_abs_dbg;
   always @(posedge s_ps_dma_aclk) begin
      if (m1_axis_buf_dec_tvalid) begin
         buf_dec_abs_dbg = $signed(m1_axis_buf_dec_tdata[15:0]) * $signed(m1_axis_buf_dec_tdata[15:0]) + 
                              $signed(m1_axis_buf_dec_tdata[31:16]) * $signed(m1_axis_buf_dec_tdata[31:16]);
      end
   end


`include "tb_qick_stimuli.svh"


`include "tb_qick_tasks.svh"

endmodule

// DAC-ADC RF frontend model
module model_DAC_ADC #(
   parameter integer DAC_W = 16,
   parameter integer ADC_W = 16,
   parameter integer BUFFER_SIZE = 16
)(
   input wire clk_DAC,
   input wire [DAC_W-1:0] dac_sample,

   input wire clk_ADC,
   output logic [ADC_W-1:0] adc_sample,

   input int mode  // 0 = ZOH, 1 = linear
);

   // Parameters
   real pi = 3.14159265358979;

   // DAC samples Buffer
   real buffer_samples[BUFFER_SIZE];
   real buffer_times[BUFFER_SIZE];
   int wr_ptr = 0;

   // Internal Signals
   real signal_in;
   real sampled_ADC;

   initial begin
      for (int i=0; i<BUFFER_SIZE; i++) begin
         buffer_samples[i] = 0.0;
         buffer_times[i] = 0.0;
      end
   end

   // DAC processing
   always @(posedge clk_DAC) begin
      real t_now = $realtime * 1e-9;
      signal_in = $signed(dac_sample) / 2.0**(DAC_W-1);

      buffer_samples[wr_ptr] = signal_in;
      buffer_times[wr_ptr] = t_now;
      wr_ptr = (wr_ptr + 1) % BUFFER_SIZE;

      // $display("[%0t ns] DAC sample: %f", $time, signal_in);
   end

   // ADC processing
   always @(posedge clk_ADC) begin
      real t_adc = $realtime * 1e-9;
      real val;
      case (mode)
         0: begin
               // ZOH: last value
               int idx_last = (wr_ptr + BUFFER_SIZE - 1) % BUFFER_SIZE;
               val = buffer_samples[idx_last];
         end
         1: begin
               // Linear: use last 2 samples to interpolate
               int idx_curr = (wr_ptr + BUFFER_SIZE - 1) % BUFFER_SIZE;
               int idx_prev = (wr_ptr + BUFFER_SIZE - 2) % BUFFER_SIZE;
               real t1 = buffer_times[idx_prev];
               real t2 = buffer_times[idx_curr];
               real y1 = buffer_samples[idx_prev];
               real y2 = buffer_samples[idx_curr];
               if (t2 != t1)
                  val = y1 + (t_adc - t1) * (y2 - y1)/(t2 - t1);
               else
                  val = y2;
         end
         default: val = 0.0;
      endcase

      if (val > 1.0)          sampled_ADC = 1.0;
      else if (val < -1.0)    sampled_ADC = -1.0;
      else                    sampled_ADC = val;
      adc_sample = sampled_ADC * $signed(2**(ADC_W-1)-1);

      // $display("[%0t ns] ADC sample (mode %0d): %f", $time, mode, sampled_ADC);
   end

endmodule
