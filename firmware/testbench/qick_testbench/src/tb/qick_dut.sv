// qick_dut: wrapper module that exposes AXIS_QPROC ports and keeps the AXI link internal

module qick_dut #(
   // QickEmu Parameters
   parameter EMULATOR         = 0, // Set to 1 to enable QickEmu simulation
   // General Settings
   parameter N_DDS_SG = 16,
   parameter N_DDS_RO = 8,
   // TPROC Parameters
   parameter GEN_SYNC,
   parameter DUAL_CORE,
   parameter IO_CTRL,
   parameter DEBUG,
   parameter TNET,
   parameter QCOM,
   parameter CUSTOM_PERIPH,
   parameter LFSR,
   parameter DIVIDER,
   parameter ARITH,
   parameter TIME_READ,
   parameter FIFO_DEPTH,
   parameter PMEM_AW,
   parameter DMEM_AW,
   parameter WMEM_AW,
   parameter REG_AW,
   parameter IN_PORT_QTY,
   parameter OUT_TRIG_QTY,
   parameter OUT_DPORT_QTY,
   parameter OUT_DPORT_DW,
   parameter OUT_WPORT_QTY
) (
   // Core, Time and AXI CLK & RST. (match AXIS_QPROC port names)
   input  logic                t_clk,
   input  logic                t_resetn,
   input  logic                c_clk,
   input  logic                c_resetn,
   input  logic                ps_clk,
   input  logic                ps_resetn,
   input  logic                sg_clk,
   input  logic                sg_resetn,
   input  logic                ro_clk,
   input  logic                ro_resetn,
   // External Control
   input  logic                ext_flag_i,
   input  logic                proc_start_i,
   input  logic                proc_stop_i,
   input  logic                core_start_i,
   input  logic                core_stop_i,
   input  logic                time_rst_i,
   input  logic                time_init_i,
   input  logic                time_updt_i,
   input  logic        [31:0]  time_dt_i,
   output logic        [47:0]  t_time_abs_o,
   output logic                pulse_sync_o,
   // QNET
   output logic                qnet_en_o,
   output logic        [4:0]   qnet_op_o,
   output logic       [31:0]   qnet_a_dt_o,
   output logic       [31:0]   qnet_b_dt_o,
   output logic       [31:0]   qnet_c_dt_o,
   input  logic                qnet_rdy_i,
   input  logic       [31:0]   qnet_dt1_i,
   input  logic       [31:0]   qnet_dt2_i,
   input  logic                qnet_vld_i,
   input  logic                qnet_flag_i,
   // QCOM
   output logic                qcom_en_o,
   output logic        [4:0]   qcom_op_o,
   output logic       [31:0]   qcom_dt_o,
   input  logic                qcom_rdy_i,
   input  logic       [31:0]   qcom_dt1_i,
   input  logic       [31:0]   qcom_dt2_i,
   input  logic                qcom_vld_i,
   input  logic                qcom_flag_i,
   // QP1
   output logic                qp1_en_o,
   output logic        [4:0]   qp1_op_o,
   output logic       [31:0]   qp1_a_dt_o,
   output logic       [31:0]   qp1_b_dt_o,
   output logic       [31:0]   qp1_c_dt_o,
   output logic       [31:0]   qp1_d_dt_o,
   input  logic                qp1_rdy_i,
   input  logic       [31:0]   qp1_dt1_i,
   input  logic       [31:0]   qp1_dt2_i,
   input  logic                qp1_vld_i,
   input  logic                qp1_flag_i,
   // QP2
   output logic                qp2_en_o,
   output logic        [4:0]   qp2_op_o,
   output logic       [31:0]   qp2_a_dt_o,
   output logic       [31:0]   qp2_b_dt_o,
   output logic       [31:0]   qp2_c_dt_o,
   output logic       [31:0]   qp2_d_dt_o,
   input  logic                qp2_rdy_i,
   input  logic       [31:0]   qp2_dt1_i,
   input  logic       [31:0]   qp2_dt2_i,
   input  logic                qp2_vld_i,
   // DMA AXIS FOR READ AND WRITE MEMORY
   input  logic       [255:0]  s_dma_axis_tdata_i,
   input  logic                s_dma_axis_tlast_i,
   input  logic                s_dma_axis_tvalid_i,
   output logic                s_dma_axis_tready_o,
   output logic       [255:0]  m_dma_axis_tdata_o,
   output logic                m_dma_axis_tlast_o,
   output logic                m_dma_axis_tvalid_o,
   input  logic                m_dma_axis_tready_i,
   // TRIGGERS
   output logic                trig_0_o,  // to PMODS
   output logic                trig_1_o,  // to PMODS
   output logic                trig_2_o,  // to PMODS
   output logic                trig_3_o,  // to PMODS
   output logic                trig_4_o,  // to PMODS
   output logic                trig_5_o,  // to PMODS
   output logic                trig_6_o,  // to PMODS
   output logic                trig_7_o,  // to PMODS
   // OUT DATA PORTS
   output logic       [3:0]    port_0_dt_o,
   output logic       [3:0]    port_1_dt_o,
   output logic       [3:0]    port_2_dt_o,
   output logic       [3:0]    port_3_dt_o,
   // Debug Signals
   output logic       [31:0]   ps_debug_do,
   output logic       [31:0]   t_debug_do,
   output logic       [31:0]   t_fifo_do,
   output logic       [31:0]   c_time_usr_do,
   output logic       [31:0]   c_debug_do,
   output logic       [31:0]   c_time_ref_do,
   output logic       [31:0]   c_proc_do,
   output logic       [31:0]   c_port_do,
   output logic       [31:0]   c_core_do,

   // AXIS Signal Generator 0 Interface
   input logic                   sg0_s0_axis_aclk,
   input logic                   sg0_s0_axis_aresetn,
   input logic        [31:0]     sg0_s0_axis_tdata,
   input logic                   sg0_s0_axis_tvalid,
   output logic                  sg0_s0_axis_tready,

   // AXIS Signal Generator 1 Interface
   input logic                   sg1_s0_axis_aclk,
   input logic                   sg1_s0_axis_aresetn,
   input logic        [31:0]     sg1_s0_axis_tdata,
   input logic                   sg1_s0_axis_tvalid,
   output logic                  sg1_s0_axis_tready,

   // AXIS DAC Signal Generator

   input logic                      axis_sg0_dac0_tready,
   output logic                     axis_sg0_dac0_tvalid,
   output logic [N_DDS_SG*16-1:0]   axis_sg0_dac0_tdata,

   input logic                      axis_sg1_dac1_tready,
   output logic                     axis_sg1_dac1_tvalid,
   output logic [N_DDS_SG*16-1:0]   axis_sg1_dac1_tdata,

   // ++++++++++++ ADD MUX8 SG2 DAC OUTPUT
   input logic                      axis_sg2_dac2_tready,
   output logic                     axis_sg2_dac2_tvalid,
   output logic [N_DDS_SG*16-1:0]   axis_sg2_dac2_tdata,
   // ++++++++++++
   
   // AXIS ADC0 Readout
   output logic                     axis_adc0_ro0_tready,
   input logic                      axis_adc0_ro0_tvalid,
   input logic [N_DDS_RO*16-1:0]    axis_adc0_ro0_tdata,

    // AXIS ADC1 Readout
    output logic                     axis_adc1_ro1_tready,
    input logic                      axis_adc1_ro1_tvalid,
    input logic [N_DDS_RO*16-1:0]    axis_adc1_ro1_tdata,

    // AXIS ADC2 Readout
    output logic                     axis_adc2_ro2_tready,
    input logic                      axis_adc2_ro2_tvalid,
    input logic [N_DDS_RO*16-1:0]    axis_adc2_ro2_tdata
 );

   // Signal Generator 0 Path signals
   wire [167:0]       tproc_sg0cdc_axis_tdata ;
   wire               tproc_sg0cdc_axis_tvalid;
   logic              tproc_sg0cdc_axis_tready;

   wire [167:0]       sg0cdc_sgt0_axis_tdata ;
   wire               sg0cdc_sgt0_axis_tvalid;
   logic              sg0cdc_sgt0_axis_tready;

   wire [159:0]       sgt0_sg0_axis_tdata ;
   wire               sgt0_sg0_axis_tvalid;
   logic              sgt0_sg0_axis_tready;

   // Signal Generator 1 Path signals
   wire [167:0]       tproc_sg1cdc_axis_tdata ;
   wire               tproc_sg1cdc_axis_tvalid;
   logic              tproc_sg1cdc_axis_tready;

   wire [167:0]       sg1cdc_sgt1_axis_tdata ;
   wire               sg1cdc_sgt1_axis_tvalid;
   logic              sg1cdc_sgt1_axis_tready;

   wire [159:0]       sgt1_sg1_axis_tdata ;
   wire               sgt1_sg1_axis_tvalid;
   logic              sgt1_sg1_axis_tready;

   // ++++++++++++ Signal Generator 2 (mux8) Path signals
   wire [167:0]       tproc_sg2cdc_axis_tdata ;
   wire               tproc_sg2cdc_axis_tvalid;
   logic              tproc_sg2cdc_axis_tready;

   wire [167:0]       sg2cdc_sgt2_axis_tdata ;
   wire               sg2cdc_sgt2_axis_tvalid;
   logic              sg2cdc_sgt2_axis_tready;

   wire [39:0]        sgt2_sg2_axis_tdata ;
   wire               sgt2_sg2_axis_tvalid;
   logic              sgt2_sg2_axis_tready;
   // ++++++++++++

   // Readout Path signals
   wire [167:0]       tproc_ro0cdc_axis_tdata ;
   wire               tproc_ro0cdc_axis_tvalid;
   logic              tproc_ro0cdc_axis_tready;

   wire [167:0]       rocdc_rot0_axis_tdata ;
   wire               rocdc_rot0_axis_tvalid;
   logic              rocdc_rot0_axis_tready;

   wire [87:0]        rot_ro0_axis_tdata ;
   wire               rot_ro0_axis_tvalid;
   logic              rot_ro0_axis_tready;


   // Readout0 Buffer Averaged Data AXIS
   logic                     buf0_m0_axis_avg_tvalid;
   logic [63:0]              buf0_m0_axis_avg_tdata;
   logic                     buf0_m0_axis_avg_tlast;
   // Readout0 Buffer Decimated Data AXIS
   logic                     buf0_m1_axis_dec_tvalid;
   logic [31:0]              buf0_m1_axis_dec_tdata;
   logic                     buf0_m1_axis_dec_tlast;
   // Readout0 Buffer Register Data AXIS
   logic                     buf0_m2_axis_reg_tvalid;
   logic [63:0]              buf0_m2_axis_reg_tdata;
   wire                      buf0_m2_axis_reg_tready;

   // Readout1 Buffer Averaged Data AXIS
   logic                     buf1_m0_axis_avg_tvalid;
   logic [63:0]              buf1_m0_axis_avg_tdata;
   logic                     buf1_m0_axis_avg_tlast;
   // Readout1 Buffer Decimated Data AXIS
   logic                     buf1_m1_axis_dec_tvalid;
   logic [31:0]              buf1_m1_axis_dec_tdata;
   logic                     buf1_m1_axis_dec_tlast;
   // Readout1 Buffer Register Data AXIS
   logic                     buf1_m2_axis_reg_tvalid;
   logic [63:0]              buf1_m2_axis_reg_tdata;
   wire                      buf1_m2_axis_reg_tready;

   // Readout2 Buffer Averaged Data AXIS
   logic                     buf2_m0_axis_avg_tvalid;
   logic [63:0]              buf2_m0_axis_avg_tdata;
   logic                     buf2_m0_axis_avg_tlast;
   // Readout2 Buffer Decimated Data AXIS
   logic                     buf2_m1_axis_dec_tvalid;
   logic [31:0]              buf2_m1_axis_dec_tdata;
   logic                     buf2_m1_axis_dec_tlast;
   // Readout2 Buffer Register Data AXIS
   logic                     buf2_m2_axis_reg_tvalid;
   logic [63:0]              buf2_m2_axis_reg_tdata;
   wire                      buf2_m2_axis_reg_tready;

   // Readout3 Buffer Averaged Data AXIS
   logic                     buf3_m0_axis_avg_tvalid;
   logic [63:0]              buf3_m0_axis_avg_tdata;
   logic                     buf3_m0_axis_avg_tlast;
   // Readout3 Buffer Decimated Data AXIS
   logic                     buf3_m1_axis_dec_tvalid;
   logic [31:0]              buf3_m1_axis_dec_tdata;
   logic                     buf3_m1_axis_dec_tlast;
   // Readout3 Buffer Register Data AXIS
   logic                     buf3_m2_axis_reg_tvalid;
   logic [63:0]              buf3_m2_axis_reg_tdata;
   wire                      buf3_m2_axis_reg_tready;


   wire                       trig_10;
   wire                       trig_11;
   wire                       trig_12;
   wire                       trig_13;
   wire                       trig_14;
   wire                       trig_15;

   // Internal AXI-Lite wires (kept inside qick_dut)
   // Single AXI master with 40-bit address for router
   logic  [39:0]   s_axi_mst_awaddr;
   logic  [2:0]    s_axi_mst_awprot;
   logic           s_axi_mst_awvalid;
   logic           s_axi_mst_awready;
   logic  [31:0]   s_axi_mst_wdata;
   logic  [3:0]    s_axi_mst_wstrb;
   logic           s_axi_mst_wvalid;
   logic           s_axi_mst_wready;
   logic  [1:0]    s_axi_mst_bresp;
   logic           s_axi_mst_bvalid;
   logic           s_axi_mst_bready;
   logic  [39:0]   s_axi_mst_araddr;
   logic  [2:0]    s_axi_mst_arprot;
   logic           s_axi_mst_arvalid;
   logic           s_axi_mst_arready;
   logic  [31:0]   s_axi_mst_rdata;
   logic  [1:0]    s_axi_mst_rresp;
   logic           s_axi_mst_rvalid;
   logic           s_axi_mst_rready;

   // AXI router outputs (decoded to each slave)
   logic  [7:0]    s_axi_tproc_awaddr;
   logic  [2:0]    s_axi_tproc_awprot;
   logic           s_axi_tproc_awvalid;
   logic           s_axi_tproc_awready;
   logic  [31:0]   s_axi_tproc_wdata;
   logic  [3:0]    s_axi_tproc_wstrb;
   logic           s_axi_tproc_wvalid;
   logic           s_axi_tproc_wready;
   logic  [1:0]    s_axi_tproc_bresp;
   logic           s_axi_tproc_bvalid;
   logic           s_axi_tproc_bready;
   logic  [7:0]    s_axi_tproc_araddr;
   logic  [2:0]    s_axi_tproc_arprot;
   logic           s_axi_tproc_arvalid;
   logic           s_axi_tproc_arready;
   logic  [31:0]   s_axi_tproc_rdata;
   logic  [1:0]    s_axi_tproc_rresp;
   logic           s_axi_tproc_rvalid;
   logic           s_axi_tproc_rready;

   logic [5:0]       s_axi_sg0_araddr;
   logic [2:0]       s_axi_sg0_arprot;
   logic             s_axi_sg0_arready;
   logic             s_axi_sg0_arvalid;
   logic [5:0]       s_axi_sg0_awaddr;
   logic [2:0]       s_axi_sg0_awprot;
   logic             s_axi_sg0_awready;
   logic             s_axi_sg0_awvalid;
   logic             s_axi_sg0_bready;
   logic [1:0]       s_axi_sg0_bresp;
   logic             s_axi_sg0_bvalid;
   logic [31:0]      s_axi_sg0_rdata;
   logic             s_axi_sg0_rready;
   logic [1:0]       s_axi_sg0_rresp;
   logic             s_axi_sg0_rvalid;
   logic [31:0]      s_axi_sg0_wdata;
   logic             s_axi_sg0_wready;
   logic [3:0]       s_axi_sg0_wstrb;
   logic             s_axi_sg0_wvalid;

   logic  [5:0]       s_axi_sg1_araddr;
   logic  [2:0]       s_axi_sg1_arprot;
   logic              s_axi_sg1_arready;
   logic              s_axi_sg1_arvalid;
   logic  [5:0]       s_axi_sg1_awaddr;
   logic  [2:0]       s_axi_sg1_awprot;
   logic              s_axi_sg1_awready;
   logic              s_axi_sg1_awvalid;
   logic              s_axi_sg1_bready;
   logic  [1:0]       s_axi_sg1_bresp;
   logic              s_axi_sg1_bvalid;
   logic  [31:0]      s_axi_sg1_rdata;
   logic              s_axi_sg1_rready;
   logic  [1:0]       s_axi_sg1_rresp;
   logic              s_axi_sg1_rvalid;
   logic  [31:0]      s_axi_sg1_wdata;
   logic              s_axi_sg1_wready;
   logic  [3:0]       s_axi_sg1_wstrb;
   logic              s_axi_sg1_wvalid;

   // ++++++++++++ Internal AXI-Lite wires for mux8 SG2 config (kept inside qick_dut)
   logic  [7:0]       s_axi_sg2_awaddr;
   logic  [2:0]       s_axi_sg2_awprot;
   logic              s_axi_sg2_awvalid;
   logic              s_axi_sg2_awready;
   logic  [31:0]      s_axi_sg2_wdata;
   logic  [3:0]       s_axi_sg2_wstrb;
   logic              s_axi_sg2_wvalid;
   logic              s_axi_sg2_wready;
   logic  [1:0]       s_axi_sg2_bresp;
   logic              s_axi_sg2_bvalid;
   logic              s_axi_sg2_bready;
   logic  [7:0]       s_axi_sg2_araddr;
   logic  [2:0]       s_axi_sg2_arprot;
   logic              s_axi_sg2_arvalid;
   logic              s_axi_sg2_arready;
   logic  [31:0]      s_axi_sg2_rdata;
   logic  [1:0]       s_axi_sg2_rresp;
   logic              s_axi_sg2_rvalid;
   logic              s_axi_sg2_rready;
   // ++++++++++++

   // Router output wires for avg1
   wire  [5:0]       s_axi_buf1_araddr;
   wire  [2:0]       s_axi_buf1_arprot;
   wire              s_axi_buf1_arready;
   wire              s_axi_buf1_arvalid;
   wire  [5:0]       s_axi_buf1_awaddr;
   wire  [2:0]       s_axi_buf1_awprot;
   wire              s_axi_buf1_awready;
   wire              s_axi_buf1_awvalid;
   wire              s_axi_buf1_bready;
   wire  [1:0]       s_axi_buf1_bresp;
   wire              s_axi_buf1_bvalid;
   wire  [31:0]      s_axi_buf1_rdata;
   wire              s_axi_buf1_rready;
   wire  [1:0]       s_axi_buf1_rresp;
   wire              s_axi_buf1_rvalid;
   wire  [31:0]      s_axi_buf1_wdata;

   // Router output wires for buf2
   wire  [5:0]       s_axi_buf2_araddr;
   wire  [2:0]       s_axi_buf2_arprot;
   wire              s_axi_buf2_arready;
   wire              s_axi_buf2_arvalid;
   wire  [5:0]       s_axi_buf2_awaddr;
   wire  [2:0]       s_axi_buf2_awprot;
   wire              s_axi_buf2_awready;
   wire              s_axi_buf2_awvalid;
   wire              s_axi_buf2_bready;
   wire  [1:0]       s_axi_buf2_bresp;
   wire              s_axi_buf2_bvalid;
   wire  [31:0]      s_axi_buf2_rdata;
   wire              s_axi_buf2_rready;
   wire  [1:0]       s_axi_buf2_rresp;
   wire              s_axi_buf2_rvalid;
   wire  [31:0]      s_axi_buf2_wdata;

   // Router output wires for buf3
   wire  [5:0]       s_axi_buf3_araddr;
   wire  [2:0]       s_axi_buf3_arprot;
   wire              s_axi_buf3_arready;
   wire              s_axi_buf3_arvalid;
   wire  [5:0]       s_axi_buf3_awaddr;
   wire  [2:0]       s_axi_buf3_awprot;
   wire              s_axi_buf3_awready;
   wire              s_axi_buf3_awvalid;
   wire              s_axi_buf3_bready;
   wire  [1:0]       s_axi_buf3_bresp;
   wire              s_axi_buf3_bvalid;
   wire  [31:0]      s_axi_buf3_rdata;
   wire              s_axi_buf3_rready;
   wire  [1:0]       s_axi_buf3_rresp;
   wire              s_axi_buf3_rvalid;
   wire  [31:0]      s_axi_buf3_wdata;

   // AXI router output signals for PFB Readout
   logic  [7:0]    s_axi_pfb_ro_awaddr;
   logic  [2:0]    s_axi_pfb_ro_awprot;
   logic           s_axi_pfb_ro_awvalid;
   logic           s_axi_pfb_ro_awready;
   logic  [31:0]   s_axi_pfb_ro_wdata;
   logic  [3:0]    s_axi_pfb_ro_wstrb;
   logic           s_axi_pfb_ro_wvalid;
   logic           s_axi_pfb_ro_wready;
   logic  [1:0]    s_axi_pfb_ro_bresp;
   logic           s_axi_pfb_ro_bvalid;
   logic           s_axi_pfb_ro_bready;
   logic  [7:0]    s_axi_pfb_ro_araddr;
   logic  [2:0]    s_axi_pfb_ro_arprot;
   logic           s_axi_pfb_ro_arvalid;
   logic           s_axi_pfb_ro_arready;
   logic  [31:0]   s_axi_pfb_ro_rdata;
   logic  [1:0]    s_axi_pfb_ro_rresp;
   logic           s_axi_pfb_ro_rvalid;
   logic           s_axi_pfb_ro_rready;

   wire              s_axi_buf1_wready;
   wire  [3:0]       s_axi_buf1_wstrb;
   wire              s_axi_buf1_wvalid;

   // AXI router output signals for Readout2 (ROV2)
   logic  [7:0]    s_axi_rov2_awaddr;
   logic  [2:0]    s_axi_rov2_awprot;
   logic           s_axi_rov2_awvalid;
   logic           s_axi_rov2_awready;
   logic  [31:0]   s_axi_rov2_wdata;
   logic  [3:0]    s_axi_rov2_wstrb;
   logic           s_axi_rov2_wvalid;
   logic           s_axi_rov2_wready;
   logic  [1:0]    s_axi_rov2_bresp;
   logic           s_axi_rov2_bvalid;
   logic           s_axi_rov2_bready;
   logic  [7:0]    s_axi_rov2_araddr;
   logic  [2:0]    s_axi_rov2_arprot;
   logic           s_axi_rov2_arvalid;
   logic           s_axi_rov2_arready;
   logic  [31:0]   s_axi_rov2_rdata;
   logic  [1:0]    s_axi_rov2_rresp;
   logic           s_axi_rov2_rvalid;
   logic           s_axi_rov2_rready;

   // Router output enables (one-hot)
   logic           tproc_sel;
   logic           sg0_sel;
   logic           sg1_sel;
   logic           sg2_sel;   // ++++++++++++ mux8 SG2 config select
   logic           buf0_sel;
   logic           buf1_sel;
   logic           buf2_sel;
   logic           buf3_sel;
   logic           rov2_sel;
   logic           pfb_ro_sel;


   // Instantiate AXI Router
   axi_router_lite #(
      .ADDR_WIDTH ( 40 ),
      .DATA_WIDTH ( 32 )
   ) u_axi_router (
      .aclk          (ps_clk              ),
      .aresetn       (ps_resetn           ),
      // Master input
      .m_axi_awaddr  (s_axi_mst_awaddr    ),
      .m_axi_awprot  (s_axi_mst_awprot    ),
      .m_axi_awvalid (s_axi_mst_awvalid   ),
      .m_axi_awready (s_axi_mst_awready   ),
      .m_axi_wdata   (s_axi_mst_wdata     ),
      .m_axi_wstrb   (s_axi_mst_wstrb     ),
      .m_axi_wvalid  (s_axi_mst_wvalid    ),
      .m_axi_wready  (s_axi_mst_wready    ),
      .m_axi_bresp   (s_axi_mst_bresp     ),
      .m_axi_bvalid  (s_axi_mst_bvalid    ),
      .m_axi_bready  (s_axi_mst_bready    ),
      .m_axi_araddr  (s_axi_mst_araddr    ),
      .m_axi_arprot  (s_axi_mst_arprot    ),
      .m_axi_arvalid (s_axi_mst_arvalid   ),
      .m_axi_arready (s_axi_mst_arready   ),
      .m_axi_rdata   (s_axi_mst_rdata     ),
      .m_axi_rresp   (s_axi_mst_rresp     ),
      .m_axi_rvalid  (s_axi_mst_rvalid    ),
      .m_axi_rready  (s_axi_mst_rready    ),
      // Slave outputs (decoded)
      .s_tproc_awaddr  (s_axi_tproc_awaddr  ),
      .s_tproc_awprot  (s_axi_tproc_awprot  ),
      .s_tproc_awvalid (s_axi_tproc_awvalid ),
      .s_tproc_awready (s_axi_tproc_awready ),
      .s_tproc_wdata   (s_axi_tproc_wdata   ),
      .s_tproc_wstrb   (s_axi_tproc_wstrb   ),
      .s_tproc_wvalid  (s_axi_tproc_wvalid  ),
      .s_tproc_wready  (s_axi_tproc_wready  ),
      .s_tproc_bresp   (s_axi_tproc_bresp   ),
      .s_tproc_bvalid  (s_axi_tproc_bvalid  ),
      .s_tproc_bready  (s_axi_tproc_bready  ),
      .s_tproc_araddr  (s_axi_tproc_araddr  ),
      .s_tproc_arprot  (s_axi_tproc_arprot  ),
      .s_tproc_arvalid (s_axi_tproc_arvalid ),
      .s_tproc_arready (s_axi_tproc_arready ),
      .s_tproc_rdata   (s_axi_tproc_rdata   ),
      .s_tproc_rresp   (s_axi_tproc_rresp   ),
      .s_tproc_rvalid  (s_axi_tproc_rvalid  ),
      .s_tproc_rready  (s_axi_tproc_rready  ),
      .s_sg0_awaddr    (s_axi_sg0_awaddr    ),
      .s_sg0_awprot    (s_axi_sg0_awprot    ),
      .s_sg0_awvalid   (s_axi_sg0_awvalid   ),
      .s_sg0_awready   (s_axi_sg0_awready   ),
      .s_sg0_wdata     (s_axi_sg0_wdata     ),
      .s_sg0_wstrb     (s_axi_sg0_wstrb     ),
      .s_sg0_wvalid    (s_axi_sg0_wvalid    ),
      .s_sg0_wready    (s_axi_sg0_wready    ),
      .s_sg0_bresp     (s_axi_sg0_bresp     ),
      .s_sg0_bvalid    (s_axi_sg0_bvalid    ),
      .s_sg0_bready    (s_axi_sg0_bready    ),
      .s_sg0_araddr    (s_axi_sg0_araddr    ),
      .s_sg0_arprot    (s_axi_sg0_arprot    ),
      .s_sg0_arvalid   (s_axi_sg0_arvalid   ),
      .s_sg0_arready   (s_axi_sg0_arready   ),
      .s_sg0_rdata     (s_axi_sg0_rdata     ),
      .s_sg0_rresp     (s_axi_sg0_rresp     ),
      .s_sg0_rvalid    (s_axi_sg0_rvalid    ),
      .s_sg0_rready    (s_axi_sg0_rready    ),
      .s_sg1_awaddr    (s_axi_sg1_awaddr    ),
      .s_sg1_awprot    (s_axi_sg1_awprot    ),
      .s_sg1_awvalid   (s_axi_sg1_awvalid   ),
      .s_sg1_awready   (s_axi_sg1_awready   ),
      .s_sg1_wdata     (s_axi_sg1_wdata     ),
      .s_sg1_wstrb     (s_axi_sg1_wstrb     ),
      .s_sg1_wvalid    (s_axi_sg1_wvalid    ),
      .s_sg1_wready    (s_axi_sg1_wready    ),
      .s_sg1_bresp     (s_axi_sg1_bresp     ),
      .s_sg1_bvalid    (s_axi_sg1_bvalid    ),
      .s_sg1_bready    (s_axi_sg1_bready    ),
      .s_sg1_araddr    (s_axi_sg1_araddr    ),
      .s_sg1_arprot    (s_axi_sg1_arprot    ),
      .s_sg1_arvalid   (s_axi_sg1_arvalid   ),
      .s_sg1_arready   (s_axi_sg1_arready   ),
      .s_sg1_rdata     (s_axi_sg1_rdata     ),
      .s_sg1_rresp     (s_axi_sg1_rresp     ),
      .s_sg1_rvalid    (s_axi_sg1_rvalid    ),
      .s_sg1_rready    (s_axi_sg1_rready    ),
      // ++++++++++++ mux8 SG2 config slave
      .s_sg2_awaddr    (s_axi_sg2_awaddr    ),
      .s_sg2_awprot    (s_axi_sg2_awprot    ),
      .s_sg2_awvalid   (s_axi_sg2_awvalid   ),
      .s_sg2_awready   (s_axi_sg2_awready   ),
      .s_sg2_wdata     (s_axi_sg2_wdata     ),
      .s_sg2_wstrb     (s_axi_sg2_wstrb     ),
      .s_sg2_wvalid    (s_axi_sg2_wvalid    ),
      .s_sg2_wready    (s_axi_sg2_wready    ),
      .s_sg2_bresp     (s_axi_sg2_bresp     ),
      .s_sg2_bvalid    (s_axi_sg2_bvalid    ),
      .s_sg2_bready    (s_axi_sg2_bready    ),
      .s_sg2_araddr    (s_axi_sg2_araddr    ),
      .s_sg2_arprot    (s_axi_sg2_arprot    ),
      .s_sg2_arvalid   (s_axi_sg2_arvalid   ),
      .s_sg2_arready   (s_axi_sg2_arready   ),
      .s_sg2_rdata     (s_axi_sg2_rdata     ),
      .s_sg2_rresp     (s_axi_sg2_rresp     ),
      .s_sg2_rvalid    (s_axi_sg2_rvalid    ),
      .s_sg2_rready    (s_axi_sg2_rready    ),
      // ++++++++++++
      .s_buf0_awaddr   (s_axi_buf0_awaddr   ),
      .s_buf0_awprot   (s_axi_buf0_awprot   ),
      .s_buf0_awvalid  (s_axi_buf0_awvalid  ),
      .s_buf0_awready  (s_axi_buf0_awready  ),
      .s_buf0_wdata    (s_axi_buf0_wdata    ),
      .s_buf0_wstrb    (s_axi_buf0_wstrb    ),
      .s_buf0_wvalid   (s_axi_buf0_wvalid   ),
      .s_buf0_wready   (s_axi_buf0_wready   ),
      .s_buf0_bresp    (s_axi_buf0_bresp    ),
      .s_buf0_bvalid   (s_axi_buf0_bvalid   ),
      .s_buf0_bready   (s_axi_buf0_bready   ),
      .s_buf0_araddr   (s_axi_buf0_araddr   ),
      .s_buf0_arprot   (s_axi_buf0_arprot   ),
      .s_buf0_arvalid  (s_axi_buf0_arvalid  ),
      .s_buf0_arready  (s_axi_buf0_arready  ),
      .s_buf0_rdata    (s_axi_buf0_rdata    ),
      .s_buf0_rresp    (s_axi_buf0_rresp    ),
      .s_buf0_rvalid   (s_axi_buf0_rvalid   ),
      .s_buf0_rready   (s_axi_buf0_rready   ),

      .s_rov2_awaddr   (s_axi_rov2_awaddr   ),
      .s_rov2_awprot   (s_axi_rov2_awprot   ),
      .s_rov2_awvalid  (s_axi_rov2_awvalid  ),
      .s_rov2_awready  (s_axi_rov2_awready  ),
      .s_rov2_wdata    (s_axi_rov2_wdata    ),
      .s_rov2_wstrb    (s_axi_rov2_wstrb    ),
      .s_rov2_wvalid   (s_axi_rov2_wvalid   ),
      .s_rov2_wready   (s_axi_rov2_wready   ),
      .s_rov2_bresp    (s_axi_rov2_bresp    ),
      .s_rov2_bvalid   (s_axi_rov2_bvalid   ),
      .s_rov2_bready   (s_axi_rov2_bready   ),
      .s_rov2_araddr   (s_axi_rov2_araddr   ),
      .s_rov2_arprot   (s_axi_rov2_arprot   ),
      .s_rov2_arvalid  (s_axi_rov2_arvalid  ),
      .s_rov2_arready  (s_axi_rov2_arready  ),
      .s_rov2_rdata    (s_axi_rov2_rdata    ),
      .s_rov2_rresp    (s_axi_rov2_rresp    ),
      .s_rov2_rvalid   (s_axi_rov2_rvalid   ),
      .s_rov2_rready   (s_axi_rov2_rready   ),

      .s_pfb_ro_awaddr (s_axi_pfb_ro_awaddr ),
      .s_pfb_ro_awprot (s_axi_pfb_ro_awprot ),
      .s_pfb_ro_awvalid(s_axi_pfb_ro_awvalid),
      .s_pfb_ro_awready(s_axi_pfb_ro_awready),
      .s_pfb_ro_wdata  (s_axi_pfb_ro_wdata  ),
      .s_pfb_ro_wstrb  (s_axi_pfb_ro_wstrb  ),
      .s_pfb_ro_wvalid (s_axi_pfb_ro_wvalid ),
      .s_pfb_ro_wready (s_axi_pfb_ro_wready ),
      .s_pfb_ro_bresp  (s_axi_pfb_ro_bresp  ),
      .s_pfb_ro_bvalid (s_axi_pfb_ro_bvalid ),
      .s_pfb_ro_bready (s_axi_pfb_ro_bready ),
      .s_pfb_ro_araddr (s_axi_pfb_ro_araddr ),
      .s_pfb_ro_arprot (s_axi_pfb_ro_arprot ),
      .s_pfb_ro_arvalid(s_axi_pfb_ro_arvalid),
      .s_pfb_ro_arready(s_axi_pfb_ro_arready),
      .s_pfb_ro_rdata  (s_axi_pfb_ro_rdata  ),
      .s_pfb_ro_rresp  (s_axi_pfb_ro_rresp  ),
      .s_pfb_ro_rvalid (s_axi_pfb_ro_rvalid ),
      .s_pfb_ro_rready (s_axi_pfb_ro_rready ),

      .s_buf1_awaddr   (s_axi_buf1_awaddr   ),
      .s_buf1_awprot   (s_axi_buf1_awprot   ),
      .s_buf1_awvalid  (s_axi_buf1_awvalid  ),
      .s_buf1_awready  (s_axi_buf1_awready  ),
      .s_buf1_wdata    (s_axi_buf1_wdata    ),
      .s_buf1_wstrb    (s_axi_buf1_wstrb    ),
      .s_buf1_wvalid   (s_axi_buf1_wvalid   ),
      .s_buf1_wready   (s_axi_buf1_wready   ),
      .s_buf1_bresp    (s_axi_buf1_bresp    ),
      .s_buf1_bvalid   (s_axi_buf1_bvalid   ),
      .s_buf1_bready   (s_axi_buf1_bready   ),
      .s_buf1_araddr   (s_axi_buf1_araddr   ),
      .s_buf1_arprot   (s_axi_buf1_arprot   ),
      .s_buf1_arvalid  (s_axi_buf1_arvalid  ),
      .s_buf1_arready  (s_axi_buf1_arready  ),
      .s_buf1_rdata    (s_axi_buf1_rdata    ),
      .s_buf1_rresp    (s_axi_buf1_rresp    ),
      .s_buf1_rvalid   (s_axi_buf1_rvalid   ),
      .s_buf1_rready   (s_axi_buf1_rready   ),

      .s_buf2_awaddr   (s_axi_buf2_awaddr   ),
      .s_buf2_awprot   (s_axi_buf2_awprot   ),
      .s_buf2_awvalid  (s_axi_buf2_awvalid  ),
      .s_buf2_awready  (s_axi_buf2_awready  ),
      .s_buf2_wdata    (s_axi_buf2_wdata    ),
      .s_buf2_wstrb    (s_axi_buf2_wstrb    ),
      .s_buf2_wvalid   (s_axi_buf2_wvalid   ),
      .s_buf2_wready   (s_axi_buf2_wready   ),
      .s_buf2_bresp    (s_axi_buf2_bresp    ),
      .s_buf2_bvalid   (s_axi_buf2_bvalid   ),
      .s_buf2_bready   (s_axi_buf2_bready   ),
      .s_buf2_araddr   (s_axi_buf2_araddr   ),
      .s_buf2_arprot   (s_axi_buf2_arprot   ),
      .s_buf2_arvalid  (s_axi_buf2_arvalid  ),
      .s_buf2_arready  (s_axi_buf2_arready  ),
      .s_buf2_rdata    (s_axi_buf2_rdata    ),
      .s_buf2_rresp    (s_axi_buf2_rresp    ),
      .s_buf2_rvalid   (s_axi_buf2_rvalid   ),
      .s_buf2_rready   (s_axi_buf2_rready   ),

      .s_buf3_awaddr   (s_axi_buf3_awaddr   ),
      .s_buf3_awprot   (s_axi_buf3_awprot   ),
      .s_buf3_awvalid  (s_axi_buf3_awvalid  ),
      .s_buf3_awready  (s_axi_buf3_awready  ),
      .s_buf3_wdata    (s_axi_buf3_wdata    ),
      .s_buf3_wstrb    (s_axi_buf3_wstrb    ),
      .s_buf3_wvalid   (s_axi_buf3_wvalid   ),
      .s_buf3_wready   (s_axi_buf3_wready   ),
      .s_buf3_bresp    (s_axi_buf3_bresp    ),
      .s_buf3_bvalid   (s_axi_buf3_bvalid   ),
      .s_buf3_bready   (s_axi_buf3_bready   ),
      .s_buf3_araddr   (s_axi_buf3_araddr   ),
      .s_buf3_arprot   (s_axi_buf3_arprot   ),
      .s_buf3_arvalid  (s_axi_buf3_arvalid  ),
      .s_buf3_arready  (s_axi_buf3_arready  ),
      .s_buf3_rdata    (s_axi_buf3_rdata    ),
      .s_buf3_rresp    (s_axi_buf3_rresp    ),
      .s_buf3_rvalid   (s_axi_buf3_rvalid   ),
      .s_buf3_rready   (s_axi_buf3_rready   ),

      // Output select signals
      .tproc_sel       (tproc_sel           ),
      .sg0_sel         (sg0_sel             ),
      .sg1_sel         (sg1_sel             ),
      .sg2_sel         (sg2_sel             ),
      .buf0_sel        (buf0_sel            ),
      .rov2_sel        (rov2_sel            ),
      .buf1_sel        (buf1_sel            ),
      .pfb_ro_sel      (pfb_ro_sel          ),
      .buf2_sel        (buf2_sel            ),
      .buf3_sel        (buf3_sel            )
   );

   // Instantiate AXI Master (connected to router)
   `ifndef VERILATOR
      // <<<<<<<<<<<< XILINX AXI VIP
      axi_mst_0 u_axi_mst_0 (
         .aclk          (ps_clk              ),
         .aresetn       (ps_resetn           ),
         .m_axi_araddr  (s_axi_mst_araddr    ),
         .m_axi_arprot  (s_axi_mst_arprot    ),
         .m_axi_arready (s_axi_mst_arready   ),
         .m_axi_arvalid (s_axi_mst_arvalid   ),
         .m_axi_awaddr  (s_axi_mst_awaddr    ),
         .m_axi_awprot  (s_axi_mst_awprot    ),
         .m_axi_awready (s_axi_mst_awready   ),
         .m_axi_awvalid (s_axi_mst_awvalid   ),
         .m_axi_bready  (s_axi_mst_bready    ),
         .m_axi_bresp   (s_axi_mst_bresp     ),
         .m_axi_bvalid  (s_axi_mst_bvalid    ),
         .m_axi_rdata   (s_axi_mst_rdata     ),
         .m_axi_rready  (s_axi_mst_rready    ),
         .m_axi_rresp   (s_axi_mst_rresp     ),
         .m_axi_rvalid  (s_axi_mst_rvalid    ),
         .m_axi_wdata   (s_axi_mst_wdata     ),
         .m_axi_wready  (s_axi_mst_wready    ),
         .m_axi_wstrb   (s_axi_mst_wstrb     ),
         .m_axi_wvalid  (s_axi_mst_wvalid    )
      );
   `else
      // <<<<<<<<<<<< PULP PLATFORM AXI VIP
      AXI_LITE_DV #(
         .AXI_ADDR_WIDTH ( 40      ),
         .AXI_DATA_WIDTH ( 32      )
      ) axi_mst_IF (ps_clk);

      // Register DUT->VIP return channels to avoid zero-delay combinational
      // feedback through the virtual interface under Verilator.
      logic        axi_ar_ready_q;
      logic        axi_aw_ready_q;
      logic        axi_w_ready_q;
      logic [1:0]  axi_b_resp_q;
      logic        axi_b_valid_q;
      logic [1:0]  axi_r_resp_q;
      logic        axi_r_valid_q;
      logic [31:0] axi_r_data_q;

      always_ff @(posedge ps_clk or negedge ps_resetn) begin
         if (!ps_resetn) begin
            axi_ar_ready_q <= 1'b0;
            axi_aw_ready_q <= 1'b0;
            axi_w_ready_q  <= 1'b0;
            axi_b_resp_q   <= '0;
            axi_b_valid_q  <= 1'b0;
            axi_r_resp_q   <= '0;
            axi_r_valid_q  <= 1'b0;
            axi_r_data_q   <= '0;
         end else begin
            axi_ar_ready_q <= s_axi_mst_arready;
            axi_aw_ready_q <= s_axi_mst_awready;
            axi_w_ready_q  <= s_axi_mst_wready;
            axi_b_resp_q   <= s_axi_mst_bresp;
            axi_b_valid_q  <= s_axi_mst_bvalid;
            axi_r_resp_q   <= s_axi_mst_rresp;
            axi_r_valid_q  <= s_axi_mst_rvalid;
            axi_r_data_q   <= s_axi_mst_rdata;
         end
      end

      assign s_axi_mst_araddr        = axi_mst_IF.ar_addr  ; /* MASTER  input */
      assign s_axi_mst_arprot        = axi_mst_IF.ar_prot  ; /* MASTER  input */
      assign s_axi_mst_arvalid       = axi_mst_IF.ar_valid ; /* MASTER  input */
      assign axi_mst_IF.ar_ready     = axi_ar_ready_q      ; /* MASTER output */

      assign s_axi_mst_awaddr        = axi_mst_IF.aw_addr  ; /* MASTER  input */
      assign s_axi_mst_awprot        = axi_mst_IF.aw_prot  ; /* MASTER  input */
      assign s_axi_mst_awvalid       = axi_mst_IF.aw_valid ; /* MASTER  input */
      assign axi_mst_IF.aw_ready     = axi_aw_ready_q      ; /* MASTER output */

      assign axi_mst_IF.b_resp       = axi_b_resp_q        ; /* MASTER output */
      assign axi_mst_IF.b_valid      = axi_b_valid_q       ; /* MASTER output */
      assign s_axi_mst_bready        = axi_mst_IF.b_ready  ; /* MASTER  input */

      assign axi_mst_IF.r_resp       = axi_r_resp_q        ; /* MASTER output */
      assign axi_mst_IF.r_valid      = axi_r_valid_q       ; /* MASTER output */
      assign axi_mst_IF.r_data       = axi_r_data_q        ; /* MASTER output */
      assign s_axi_mst_rready        = axi_mst_IF.r_ready  ; /* MASTER  input */

      assign s_axi_mst_wdata         = axi_mst_IF.w_data   ; /* MASTER  input */
      assign s_axi_mst_wstrb         = axi_mst_IF.w_strb   ; /* MASTER  input */
      assign s_axi_mst_wvalid        = axi_mst_IF.w_valid  ; /* MASTER  input */
      assign axi_mst_IF.w_ready      = axi_w_ready_q       ; /* MASTER output */

   `endif

   // Instantiate Axis Qick Processor and connect AXI ports to internal wires
   axis_qick_processor #(
      .DUAL_CORE           (  DUAL_CORE        ) ,
      .GEN_SYNC            (  GEN_SYNC         ) ,
      .IO_CTRL             (  IO_CTRL          ) ,
      .DEBUG               (  DEBUG            ) ,
      // .TNET                (  TNET             ) ,
      .QCOM                (  QCOM             ) ,
      .CUSTOM_PERIPH       (  CUSTOM_PERIPH    ) ,
      .LFSR                (  LFSR             ) ,
      .DIVIDER             (  DIVIDER          ) ,
      .ARITH               (  ARITH            ) ,
      .TIME_READ           (  TIME_READ        ) ,
      .FIFO_DEPTH          (  FIFO_DEPTH       ) ,
      .PMEM_AW             (  PMEM_AW          ) ,
      .DMEM_AW             (  DMEM_AW          ) ,
      .WMEM_AW             (  WMEM_AW          ) ,
      .REG_AW              (  REG_AW           ) ,
      .IN_PORT_QTY         (  IN_PORT_QTY      ) ,
      .OUT_TRIG_QTY        (  OUT_TRIG_QTY     ) ,
      .OUT_DPORT_QTY       (  OUT_DPORT_QTY    ) ,
      .OUT_DPORT_DW        (  OUT_DPORT_DW     ) , 
      .OUT_WPORT_QTY       (  OUT_WPORT_QTY    ) ,
      // +++++++++++++ ADD EMULATOR PARAM
      .EMULATOR            ( EMULATOR             )
      // +++++++++++++
   ) AXIS_QPROC (
      .t_clk_i             ( t_clk                ),
      .t_resetn            ( t_resetn             ),
      .c_clk_i             ( c_clk                ),
      .c_resetn            ( c_resetn             ),
      .ps_clk_i            ( ps_clk               ),
      .ps_resetn           ( ps_resetn            ),
      // External Control
      .ext_flag_i          ( ext_flag_i           ),
      .proc_start_i        ( proc_start_i         ),
      .proc_stop_i         ( proc_stop_i          ),
      .core_start_i        ( core_start_i         ),
      .core_stop_i         ( core_stop_i          ),
      .time_rst_i          ( time_rst_i           ),
      .time_init_i         ( time_init_i          ),
      .time_updt_i         ( time_updt_i          ),
      .time_dt_i           ( time_dt_i            ),
      .t_time_abs_o        ( t_time_abs_o         ),
      .pulse_sync_o        ( pulse_sync_o         ),
      //QNET
      .qnet_en_o           ( qnet_en_o            ),
      .qnet_op_o           ( qnet_op_o            ),
      .qnet_a_dt_o         ( qnet_a_dt_o          ),
      .qnet_b_dt_o         ( qnet_b_dt_o          ),
      .qnet_c_dt_o         ( qnet_c_dt_o          ),
      .qnet_rdy_i          ( qnet_rdy_i           ),
      .qnet_dt1_i          ( qnet_dt1_i           ),
      .qnet_dt2_i          ( qnet_dt2_i           ),
      .qnet_vld_i          ( qnet_vld_i           ),
      .qnet_flag_i         ( qnet_flag_i          ),
      //QCOM
      .qcom_en_o           ( qcom_en_o            ),
      .qcom_op_o           ( qcom_op_o            ),
      .qcom_dt_o           ( qcom_dt_o            ),
      .qcom_rdy_i          ( qcom_rdy_i           ),
      .qcom_dt1_i          ( qcom_dt1_i           ),
      .qcom_dt2_i          ( qcom_dt2_i           ),
      .qcom_vld_i          ( qcom_vld_i           ),
      .qcom_flag_i         ( qcom_flag_i          ),
      // QP1
      .qp1_en_o            ( qp1_en_o             ),
      .qp1_op_o            ( qp1_op_o             ),
      .qp1_a_dt_o          ( qp1_a_dt_o           ),
      .qp1_b_dt_o          ( qp1_b_dt_o           ),
      .qp1_c_dt_o          ( qp1_c_dt_o           ),
      .qp1_d_dt_o          ( qp1_d_dt_o           ),
      .qp1_rdy_i           ( qp1_rdy_i            ),
      .qp1_dt1_i           ( qp1_dt1_i            ),
      .qp1_dt2_i           ( qp1_dt2_i            ),
      .qp1_vld_i           ( qp1_vld_i            ),
      .qp1_flag_i          ( qp1_flag_i           ),
      // QP2
      .qp2_en_o            ( qp2_en_o             ),
      .qp2_op_o            ( qp2_op_o             ),
      .qp2_a_dt_o          ( qp2_a_dt_o           ),
      .qp2_b_dt_o          ( qp2_b_dt_o           ),
      .qp2_c_dt_o          ( qp2_c_dt_o           ),
      .qp2_d_dt_o          ( qp2_d_dt_o           ),
      .qp2_rdy_i           ( qp2_rdy_i            ),
      .qp2_dt1_i           ( qp2_dt1_i            ),
      .qp2_dt2_i           ( qp2_dt2_i            ),
      .qp2_vld_i           ( qp2_vld_i            ),
      // DMA AXIS FOR READ AND WRITE MEMORY
      .s_dma_axis_tdata_i   ( s_dma_axis_tdata_i   ),
      .s_dma_axis_tlast_i   ( s_dma_axis_tlast_i   ),
      .s_dma_axis_tvalid_i  ( s_dma_axis_tvalid_i  ),
      .s_dma_axis_tready_o  ( s_dma_axis_tready_o  ),
      .m_dma_axis_tdata_o   ( m_dma_axis_tdata_o   ),
      .m_dma_axis_tlast_o   ( m_dma_axis_tlast_o   ),
      .m_dma_axis_tvalid_o  ( m_dma_axis_tvalid_o  ),
      .m_dma_axis_tready_i  ( m_dma_axis_tready_i  ),
      // AXI-Lite DATA Slave I/F (connected internally)
      .s_axi_awaddr         ( s_axi_tproc_awaddr[7:0]    ),
      .s_axi_awprot         ( s_axi_tproc_awprot         ),
      .s_axi_awvalid        ( s_axi_tproc_awvalid        ),
      .s_axi_awready        ( s_axi_tproc_awready        ),
      .s_axi_wdata          ( s_axi_tproc_wdata          ),
      .s_axi_wstrb          ( s_axi_tproc_wstrb          ),
      .s_axi_wvalid         ( s_axi_tproc_wvalid         ),
      .s_axi_wready         ( s_axi_tproc_wready         ),
      .s_axi_bresp          ( s_axi_tproc_bresp          ),
      .s_axi_bvalid         ( s_axi_tproc_bvalid         ),
      .s_axi_bready         ( s_axi_tproc_bready         ),
      .s_axi_araddr         ( s_axi_tproc_araddr[7:0]    ),
      .s_axi_arprot         ( s_axi_tproc_arprot         ),
      .s_axi_arvalid        ( s_axi_tproc_arvalid        ),
      .s_axi_arready        ( s_axi_tproc_arready        ),
      .s_axi_rdata          ( s_axi_tproc_rdata          ),
      .s_axi_rresp          ( s_axi_tproc_rresp          ),
      .s_axi_rvalid         ( s_axi_tproc_rvalid         ),
      .s_axi_rready         ( s_axi_tproc_rready         ),
      // DATA IN PORTS
      .s0_axis_tdata        ( buf0_m2_axis_reg_tdata        ),
      .s0_axis_tvalid       ( buf0_m2_axis_reg_tvalid       ),
      .s0_axis_tready       ( buf0_m2_axis_reg_tready       ),
      .s1_axis_tdata        ( buf1_m2_axis_reg_tdata        ),
      .s1_axis_tvalid       ( buf1_m2_axis_reg_tvalid       ),
      .s1_axis_tready       ( buf1_m2_axis_reg_tready       ),
      .s2_axis_tdata        ( 'd0 /*s2_axis_tdata*/        ),
      .s2_axis_tvalid       ( 1'b0/*s2_axis_tvalid*/       ),
      .s2_axis_tready       ( /*s2_axis_tready*/       ),
      .s3_axis_tdata        ( 'd0 /*s3_axis_tdata*/        ),
      .s3_axis_tvalid       ( 1'b0/*s3_axis_tvalid*/       ),
      .s3_axis_tready       ( /*s3_axis_tready*/       ),
      .s4_axis_tdata        ( 'd0 /*s4_axis_tdata*/        ),
      .s4_axis_tvalid       ( 1'b0/*s4_axis_tvalid*/       ),
      .s4_axis_tready       ( /*s4_axis_tready*/       ),
      .s5_axis_tdata        ( 'd0 /*s5_axis_tdata*/        ),
      .s5_axis_tvalid       ( 1'b0/*s5_axis_tvalid*/       ),
      .s5_axis_tready       ( /*s5_axis_tready*/       ),
      .s6_axis_tdata        ( 'd0 /*s6_axis_tdata*/        ),
      .s6_axis_tvalid       ( 1'b0/*s6_axis_tvalid*/       ),
      .s6_axis_tready       ( /*s6_axis_tready*/       ),
      .s7_axis_tdata        ( 'd0 /*s7_axis_tdata*/        ),
      .s7_axis_tvalid       ( 1'b0/*s7_axis_tvalid*/       ),
      .s7_axis_tready       ( /*s7_axis_tready*/       ),
      .s8_axis_tdata        ( 'd0 /*s8_axis_tdata*/        ),
      .s8_axis_tvalid       ( 1'b0/*s8_axis_tvalid*/       ),
      .s8_axis_tready       ( /*s8_axis_tready*/       ),
      .s9_axis_tdata        ( 'd0 /*s9_axis_tdata*/        ),
      .s9_axis_tvalid       ( 1'b0/*s9_axis_tvalid*/       ),
      .s9_axis_tready       ( /*s9_axis_tready*/       ),
      .s10_axis_tdata       ( 'd0 /*s10_axis_tdata*/       ),
      .s10_axis_tvalid      ( 1'b0/*s10_axis_tvalid*/      ),
      .s10_axis_tready      ( /*s10_axis_tready*/      ),
      .s11_axis_tdata       ( 'd0 /*s11_axis_tdata*/       ),
      .s11_axis_tvalid      ( 1'b0/*s11_axis_tvalid*/      ),
      .s11_axis_tready      ( /*s11_axis_tready*/      ),
      .s12_axis_tdata       ( 'd0 /*s12_axis_tdata*/       ),
      .s12_axis_tvalid      ( 1'b0/*s12_axis_tvalid*/      ),
      .s12_axis_tready      ( /*s12_axis_tready*/      ),
      .s13_axis_tdata       ( 'd0 /*s13_axis_tdata*/       ),
      .s13_axis_tvalid      ( 1'b0/*s13_axis_tvalid*/      ),
      .s13_axis_tready      ( /*s13_axis_tready*/      ),
      .s14_axis_tdata       ( 'd0 /*s14_axis_tdata*/       ),
      .s14_axis_tvalid      ( 1'b0/*s14_axis_tvalid*/      ),
      .s14_axis_tready      ( /*s14_axis_tready*/      ),
      .s15_axis_tdata       ( 'd0 /*s15_axis_tdata*/       ),
      .s15_axis_tvalid      ( 1'b0/*s15_axis_tvalid*/      ),
      .s15_axis_tready      ( /*s15_axis_tready*/      ),
      // OUT WAVE PORTS
      .m0_axis_tdata        ( tproc_sg0cdc_axis_tdata        ),
      .m0_axis_tvalid       ( tproc_sg0cdc_axis_tvalid       ),
      .m0_axis_tready       ( tproc_sg0cdc_axis_tready       ),
      .m1_axis_tdata        ( tproc_sg1cdc_axis_tdata        ),
      .m1_axis_tvalid       ( tproc_sg1cdc_axis_tvalid       ),
      .m1_axis_tready       ( tproc_sg1cdc_axis_tready       ),
      .m2_axis_tdata        ( tproc_sg2cdc_axis_tdata       ),
      .m2_axis_tvalid       ( tproc_sg2cdc_axis_tvalid      ),
      .m2_axis_tready       ( tproc_sg2cdc_axis_tready      ),
      .m3_axis_tdata        ( /*m3_axis_tdata*/        ),
      .m3_axis_tvalid       ( /*m3_axis_tvalid*/       ),
      .m3_axis_tready       ( 1'b0 /*m3_axis_tready*/       ),
      .m4_axis_tdata        ( tproc_ro0cdc_axis_tdata        ),
      .m4_axis_tvalid       ( tproc_ro0cdc_axis_tvalid       ),
      .m4_axis_tready       ( tproc_ro0cdc_axis_tready       ),
      .m5_axis_tdata        ( /*m5_axis_tdata*/        ),
      .m5_axis_tvalid       ( /*m5_axis_tvalid*/       ),
      .m5_axis_tready       ( 1'b0 /*m5_axis_tready*/       ),
      .m6_axis_tdata        ( /*m6_axis_tdata*/        ),
      .m6_axis_tvalid       ( /*m6_axis_tvalid*/       ),
      .m6_axis_tready       ( 1'b0 /*m6_axis_tready*/       ),
      .m7_axis_tdata        ( /*m7_axis_tdata*/        ),
      .m7_axis_tvalid       ( /*m7_axis_tvalid*/       ),
      .m7_axis_tready       ( 1'b0 /*m7_axis_tready*/       ),
      .m8_axis_tdata        ( /*m8_axis_tdata*/        ),
      .m8_axis_tvalid       ( /*m8_axis_tvalid*/       ),
      .m8_axis_tready       ( 1'b0 /*m8_axis_tready*/       ),
      .m9_axis_tdata        ( /*m9_axis_tdata*/        ),
      .m9_axis_tvalid       ( /*m9_axis_tvalid*/       ),
      .m9_axis_tready       ( 1'b0 /*m9_axis_tready*/       ),
      .m10_axis_tdata       ( /*m10_axis_tdata*/       ),
      .m10_axis_tvalid      ( /*m10_axis_tvalid*/      ),
      .m10_axis_tready      ( 1'b0 /*m10_axis_tready*/      ),
      .m11_axis_tdata       ( /*m11_axis_tdata*/       ),
      .m11_axis_tvalid      ( /*m11_axis_tvalid*/      ),
      .m11_axis_tready      ( 1'b0 /*m11_axis_tready*/      ),
      .m12_axis_tdata       ( /*m12_axis_tdata*/       ),
      .m12_axis_tvalid      ( /*m12_axis_tvalid*/      ),
      .m12_axis_tready      ( 1'b0 /*m12_axis_tready*/      ),
      .m13_axis_tdata       ( /*m13_axis_tdata*/       ),
      .m13_axis_tvalid      ( /*m13_axis_tvalid*/      ),
      .m13_axis_tready      ( 1'b0 /*m13_axis_tready*/      ),
      .m14_axis_tdata       ( /*m14_axis_tdata*/       ),
      .m14_axis_tvalid      ( /*m14_axis_tvalid*/      ),
      .m14_axis_tready      ( 1'b0 /*m14_axis_tready*/      ),
      .m15_axis_tdata       ( /*m15_axis_tdata*/       ),
      .m15_axis_tvalid      ( /*m15_axis_tvalid*/      ),
      .m15_axis_tready      ( 1'b0 /*m15_axis_tready*/      ),
      ///// TRIGGERS
      .trig_0_o             ( trig_0_o             ),       // to PMODS
      .trig_1_o             ( trig_1_o             ),       // to PMODS
      .trig_2_o             ( trig_2_o             ),       // to PMODS
      .trig_3_o             ( trig_3_o             ),       // to PMODS
      .trig_4_o             ( trig_4_o             ),       // to PMODS
      .trig_5_o             ( trig_5_o             ),       // to PMODS
      .trig_6_o             ( trig_6_o             ),       // to PMODS
      .trig_7_o             ( trig_7_o             ),       // to PMODS
      .trig_8_o             ( /*trig_8_o*/             ),   // TODO: to MR Buffer
      .trig_9_o             ( /*trig_9_o*/             ),   // TODO: to DDR4
      .trig_10_o            ( trig_10              ),       // to Readouts
      .trig_11_o            ( trig_11              ),       // to Readouts
      .trig_12_o            ( trig_12              ),       // to PFB Readout
      .trig_13_o            ( trig_13              ),       // to PFB Readout
      .trig_14_o            ( trig_14              ),       // to PFB Readout
      .trig_15_o            ( trig_15              ),       // to PFB Readout
      .trig_16_o            ( /*trig_16_o*/            ),
      .trig_17_o            ( /*trig_17_o*/            ),
      .trig_18_o            ( /*trig_18_o*/            ),
      .trig_19_o            ( /*trig_19_o*/            ),
      .trig_20_o            ( /*trig_20_o*/            ),
      .trig_21_o            ( /*trig_21_o*/            ),
      .trig_22_o            ( /*trig_22_o*/            ),
      .trig_23_o            ( /*trig_23_o*/            ),
      .trig_24_o            ( /*trig_24_o*/            ),
      .trig_25_o            ( /*trig_25_o*/            ),
      .trig_26_o            ( /*trig_26_o*/            ),
      .trig_27_o            ( /*trig_27_o*/            ),
      .trig_28_o            ( /*trig_28_o*/            ),
      .trig_29_o            ( /*trig_29_o*/            ),
      .trig_30_o            ( /*trig_30_o*/            ),
      .trig_31_o            ( /*trig_31_o*/            ),
      // OUT DATA
      .port_0_dt_o          ( port_0_dt_o          ),
      .port_1_dt_o          ( port_1_dt_o          ),
      .port_2_dt_o          ( port_2_dt_o          ),
      .port_3_dt_o          ( port_3_dt_o          ),
      // Debug Signals
      .ps_debug_do          ( ps_debug_do          ),
      .t_debug_do           ( t_debug_do           ),
      .t_fifo_do            ( t_fifo_do            ),
      .c_time_usr_do        ( c_time_usr_do        ),
      .c_debug_do           ( c_debug_do           ),
      .c_time_ref_do        ( c_time_ref_do        ),
      .c_proc_do            ( c_proc_do            ),
      .c_port_do            ( c_port_do            ),
      .c_core_do            ( c_core_do            )
   );

   // Signal Generator Components
   // Removed old AXI master instantiation - now using axi_router_lite

   // CDC for signal generator
   axis_cdcsync_v1 #(
      .N                         (3),     // Number of inputs/outputs.
      .B                         (168),   // Number of data bits.
      // ++++++++++++ ADD EMULATOR PARAMETER
      .EMULATOR                  (EMULATOR)
      // ++++++++++++
   )
   u_axis_sgcdcsync_v1 (
      // S_AXIS for input data.
      .s_axis_aresetn            (t_resetn),
      .s_axis_aclk               (t_clk),
      .s0_axis_tready            (tproc_sg0cdc_axis_tready),
      .s0_axis_tvalid            (tproc_sg0cdc_axis_tvalid),
      .s0_axis_tdata             (tproc_sg0cdc_axis_tdata),
      .s1_axis_tready            (tproc_sg1cdc_axis_tready),
      .s1_axis_tvalid            (tproc_sg1cdc_axis_tvalid),
      .s1_axis_tdata             (tproc_sg1cdc_axis_tdata),
      .s2_axis_tready            (tproc_sg2cdc_axis_tready),
      .s2_axis_tvalid            (tproc_sg2cdc_axis_tvalid),
      .s2_axis_tdata             (tproc_sg2cdc_axis_tdata),
      .s3_axis_tready            (/*s3_axis_tready*/),
      .s3_axis_tvalid            (1'b0 /*s3_axis_tvalid*/),
      .s3_axis_tdata             (168'd0 /*s3_axis_tdata*/),
      .s4_axis_tready            (/*s4_axis_tready*/),
      .s4_axis_tvalid            (1'b0 /*s4_axis_tvalid*/),
      .s4_axis_tdata             (168'd0 /*s4_axis_tdata*/),
      .s5_axis_tready            (/*s5_axis_tready*/),
      .s5_axis_tvalid            (1'b0 /*s5_axis_tvalid*/),
      .s5_axis_tdata             (168'd0 /*s5_axis_tdata*/),
      .s6_axis_tready            (/*s6_axis_tready*/),
      .s6_axis_tvalid            (1'b0 /*s6_axis_tvalid*/),
      .s6_axis_tdata             (168'd0 /*s6_axis_tdata*/),
      .s7_axis_tready            (/*s7_axis_tready*/),
      .s7_axis_tvalid            (1'b0 /*s7_axis_tvalid*/),
      .s7_axis_tdata             (168'd0 /*s7_axis_tdata*/),
      .s8_axis_tready            (/*s8_axis_tready*/),
      .s8_axis_tvalid            (1'b0 /*s8_axis_tvalid*/),
      .s8_axis_tdata             (168'd0 /*s8_axis_tdata*/),
      .s9_axis_tready            (/*s9_axis_tready*/),
      .s9_axis_tvalid            (1'b0 /*s9_axis_tvalid*/),
      .s9_axis_tdata             (168'd0 /*s9_axis_tdata*/),
      .s10_axis_tready           (/*s10_axis_tready*/),
      .s10_axis_tvalid           (1'b0 /*s10_axis_tvalid*/),
      .s10_axis_tdata            (168'd0 /*s10_axis_tdata*/),
      .s11_axis_tready           (/*s11_axis_tready*/),
      .s11_axis_tvalid           (1'b0 /*s11_axis_tvalid*/),
      .s11_axis_tdata            (168'd0 /*s11_axis_tdata*/),
      .s12_axis_tready           (/*s12_axis_tready*/),
      .s12_axis_tvalid           (1'b0 /*s12_axis_tvalid*/),
      .s12_axis_tdata            (168'd0 /*s12_axis_tdata*/),
      .s13_axis_tready           (/*s13_axis_tready*/),
      .s13_axis_tvalid           (1'b0 /*s13_axis_tvalid*/),
      .s13_axis_tdata            (168'd0 /*s13_axis_tdata*/),
      .s14_axis_tready           (/*s14_axis_tready*/),
      .s14_axis_tvalid           (1'b0 /*s14_axis_tvalid*/),
      .s14_axis_tdata            (168'd0 /*s14_axis_tdata*/),
      .s15_axis_tready           (/*s15_axis_tready*/),
      .s15_axis_tvalid           (1'b0 /*s15_axis_tvalid*/),
      .s15_axis_tdata            (168'd0 /*s15_axis_tdata*/),
      // M_AXIS for output data.
      .m_axis_aresetn            (sg_resetn),
      .m_axis_aclk               (sg_clk),
      .m0_axis_tready            (sg0cdc_sgt0_axis_tready),
      .m0_axis_tvalid            (sg0cdc_sgt0_axis_tvalid),
      .m0_axis_tdata             (sg0cdc_sgt0_axis_tdata),
      .m1_axis_tready            (sg1cdc_sgt1_axis_tready),
      .m1_axis_tvalid            (sg1cdc_sgt1_axis_tvalid),
      .m1_axis_tdata             (sg1cdc_sgt1_axis_tdata),
      .m2_axis_tready            (sg2cdc_sgt2_axis_tready),
      .m2_axis_tvalid            (sg2cdc_sgt2_axis_tvalid),
      .m2_axis_tdata             (sg2cdc_sgt2_axis_tdata),
      .m3_axis_tready            (1'b1 /*m3_axis_tready*/),
      .m3_axis_tvalid            (/*m3_axis_tvalid*/),
      .m3_axis_tdata             (/*m3_axis_tdata*/),
      .m4_axis_tready            (1'b1 /*m4_axis_tready*/),
      .m4_axis_tvalid            (/*m4_axis_tvalid*/),
      .m4_axis_tdata             (/*m4_axis_tdata*/),
      .m5_axis_tready            (1'b1 /*m5_axis_tready*/),
      .m5_axis_tvalid            (/*m5_axis_tvalid*/),
      .m5_axis_tdata             (/*m5_axis_tdata*/),
      .m6_axis_tready            (1'b1 /*m6_axis_tready*/),
      .m6_axis_tvalid            (/*m6_axis_tvalid*/),
      .m6_axis_tdata             (/*m6_axis_tdata*/),
      .m7_axis_tready            (1'b1 /*m7_axis_tready*/),
      .m7_axis_tvalid            (/*m7_axis_tvalid*/),
      .m7_axis_tdata             (/*m7_axis_tdata*/),
      .m8_axis_tready            (1'b1 /*m8_axis_tready*/),
      .m8_axis_tvalid            (/*m8_axis_tvalid*/),
      .m8_axis_tdata             (/*m8_axis_tdata*/),
      .m9_axis_tready            (1'b1 /*m9_axis_tready*/),
      .m9_axis_tvalid            (/*m9_axis_tvalid*/),
      .m9_axis_tdata             (/*m9_axis_tdata*/),
      .m10_axis_tready           (1'b1 /*m10_axis_tready*/),
      .m10_axis_tvalid           (/*m10_axis_tvalid*/),
      .m10_axis_tdata            (/*m10_axis_tdata*/),
      .m11_axis_tready           (1'b1 /*m11_axis_tready*/),
      .m11_axis_tvalid           (/*m11_axis_tvalid*/),
      .m11_axis_tdata            (/*m11_axis_tdata*/),
      .m12_axis_tready           (1'b1 /*m12_axis_tready*/),
      .m12_axis_tvalid           (/*m12_axis_tvalid*/),
      .m12_axis_tdata            (/*m12_axis_tdata*/),
      .m13_axis_tready           (1'b1 /*m13_axis_tready*/),
      .m13_axis_tvalid           (/*m13_axis_tvalid*/),
      .m13_axis_tdata            (/*m13_axis_tdata*/),
      .m14_axis_tready           (1'b1 /*m14_axis_tready*/),
      .m14_axis_tvalid           (/*m14_axis_tvalid*/),
      .m14_axis_tdata            (/*m14_axis_tdata*/),
      .m15_axis_tready           (1'b1 /*m15_axis_tready*/),
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
      .s_axis_tdata           (sg0cdc_sgt0_axis_tdata),
      .s_axis_tvalid          (sg0cdc_sgt0_axis_tvalid),
      .s_axis_tready          (sg0cdc_sgt0_axis_tready),
      // OUT DATA gen_v6 (SEL:0)
      .m_gen_v6_axis_tdata    (sgt0_sg0_axis_tdata),
      .m_gen_v6_axis_tvalid   (sgt0_sg0_axis_tvalid),
      .m_gen_v6_axis_tready   (sgt0_sg0_axis_tready),
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

   axis_signal_gen_v6 #(
      .N                   (N                ),
      .N_DDS               (N_DDS_SG         ),
      .GEN_DDS             ("TRUE"           ),
      .ENVELOPE_TYPE       ("COMPLEX"        ),
      // +++++++++++++ ADD EMULATOR PARAM
      .EMULATOR            (EMULATOR         )
      // +++++++++++++
   )
   u_axis_signal_gen_v6_0 ( 
      // AXI Slave I/F for configuration.
      .s_axi_aclk          (ps_clk            ),
      .s_axi_aresetn       (ps_resetn         ),

      .s_axi_araddr        (s_axi_sg0_araddr  ),
      .s_axi_arprot        (s_axi_sg0_arprot  ),
      .s_axi_arready       (s_axi_sg0_arready ),
      .s_axi_arvalid       (s_axi_sg0_arvalid ),
      .s_axi_awaddr        (s_axi_sg0_awaddr  ),
      .s_axi_awprot        (s_axi_sg0_awprot  ),
      .s_axi_awready       (s_axi_sg0_awready ),
      .s_axi_awvalid       (s_axi_sg0_awvalid ),
      .s_axi_bready        (s_axi_sg0_bready  ),
      .s_axi_bresp         (s_axi_sg0_bresp   ),
      .s_axi_bvalid        (s_axi_sg0_bvalid  ),
      .s_axi_rdata         (s_axi_sg0_rdata   ),
      .s_axi_rready        (s_axi_sg0_rready  ),
      .s_axi_rresp         (s_axi_sg0_rresp   ),
      .s_axi_rvalid        (s_axi_sg0_rvalid  ),
      .s_axi_wdata         (s_axi_sg0_wdata   ),
      .s_axi_wready        (s_axi_sg0_wready  ),
      .s_axi_wstrb         (s_axi_sg0_wstrb   ),
      .s_axi_wvalid        (s_axi_sg0_wvalid  ),

      // AXIS Slave to load data into memory.
      .s0_axis_aclk        (sg0_s0_axis_aclk        ),
      .s0_axis_aresetn     (sg0_s0_axis_aresetn     ),
      .s0_axis_tdata       (sg0_s0_axis_tdata       ),
      .s0_axis_tvalid      (sg0_s0_axis_tvalid      ),
      .s0_axis_tready      (sg0_s0_axis_tready      ),

      // s1_* and m_* reset/clock.
      .aresetn             (sg_resetn              ),
      .aclk                (sg_clk                 ),

      // AXIS Slave to queue waveforms - From TPROC
      .s1_axis_tdata       (sgt0_sg0_axis_tdata    ),
      .s1_axis_tvalid      (sgt0_sg0_axis_tvalid   ),
      .s1_axis_tready      (sgt0_sg0_axis_tready   ),

      // AXIS Master for output data.
      .m_axis_tready       (axis_sg0_dac0_tready     ),
      .m_axis_tvalid       (axis_sg0_dac0_tvalid     ),
      .m_axis_tdata        (axis_sg0_dac0_tdata      )
   );

`ifdef SIM_DEBUG
   // For Waveform Debug
   logic signed [15:0] axis_sg0_dac0_tdata_dbg [0:N_DDS_SG-1];
   always @* begin
      for (int i=0; i<N_DDS_SG; i=i+1) begin
         axis_sg0_dac0_tdata_dbg[i] = axis_sg0_dac0_tdata[16*i +: 16];
      end
   end
`endif

`define SG_1   // Comment to disable SG_1
`ifndef SG_1
   assign sg1cdc_sgt1_axis_tready = 1'b1;
`else
   sg_translator # (
      .OUT_TYPE               (0) // (0:gen_v6, 1:int4_v1, 2:mux4_v1, 3:readout)
   ) 
   u_sg_translator_1 (
      // Reset and clock.
      .aresetn                (1'bx),  // not used
      .aclk                   (1'bx),  // not used
      // IN WAVE PORT
      .s_axis_tdata           (sg1cdc_sgt1_axis_tdata),
      .s_axis_tvalid          (sg1cdc_sgt1_axis_tvalid),
      .s_axis_tready          (sg1cdc_sgt1_axis_tready),
      // OUT DATA gen_v6 (SEL:0)
      .m_gen_v6_axis_tdata    (sgt1_sg1_axis_tdata),
      .m_gen_v6_axis_tvalid   (sgt1_sg1_axis_tvalid),
      .m_gen_v6_axis_tready   (sgt1_sg1_axis_tready),
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

   // axis_signal_gen_v6_1 parameters
   // localparam N       = 10;

   axis_signal_gen_v6 #(
      .N                   (N                ),
      .N_DDS               (N_DDS_SG         ),
      .GEN_DDS             ("TRUE"           ),
      .ENVELOPE_TYPE       ("COMPLEX"        ),
      // +++++++++++++ ADD EMULATOR PARAM
      .EMULATOR            (EMULATOR         )
      // +++++++++++++
   )
   u_axis_signal_gen_v6_1 ( 
      // AXI Slave I/F for configuration.
      .s_axi_aclk          (ps_clk            ),
      .s_axi_aresetn       (ps_resetn         ),
      .s_axi_araddr        (s_axi_sg1_araddr  ),
      .s_axi_arprot        (s_axi_sg1_arprot  ),
      .s_axi_arready       (s_axi_sg1_arready ),
      .s_axi_arvalid       (s_axi_sg1_arvalid ),
      .s_axi_awaddr        (s_axi_sg1_awaddr  ),
      .s_axi_awprot        (s_axi_sg1_awprot  ),
      .s_axi_awready       (s_axi_sg1_awready ),
      .s_axi_awvalid       (s_axi_sg1_awvalid ),
      .s_axi_bready        (s_axi_sg1_bready  ),
      .s_axi_bresp         (s_axi_sg1_bresp   ),
      .s_axi_bvalid        (s_axi_sg1_bvalid  ),
      .s_axi_rdata         (s_axi_sg1_rdata   ),
      .s_axi_rready        (s_axi_sg1_rready  ),
      .s_axi_rresp         (s_axi_sg1_rresp   ),
      .s_axi_rvalid        (s_axi_sg1_rvalid  ),
      .s_axi_wdata         (s_axi_sg1_wdata   ),
      .s_axi_wready        (s_axi_sg1_wready  ),
      .s_axi_wstrb         (s_axi_sg1_wstrb   ),
      .s_axi_wvalid        (s_axi_sg1_wvalid  ),

      // AXIS Slave to load data into memory.
      .s0_axis_aclk        (sg1_s0_axis_aclk        ),
      .s0_axis_aresetn     (sg1_s0_axis_aresetn     ),
      .s0_axis_tdata       (sg1_s0_axis_tdata       ),
      .s0_axis_tvalid      (sg1_s0_axis_tvalid      ),
      .s0_axis_tready      (sg1_s0_axis_tready      ),

      // s1_* and m_* reset/clock.
      .aresetn             (sg_resetn              ),
      .aclk                (sg_clk                 ),

      // AXIS Slave to queue waveforms - From TPROC
      .s1_axis_tdata       (sgt1_sg1_axis_tdata    ),
      .s1_axis_tvalid      (sgt1_sg1_axis_tvalid   ),
      .s1_axis_tready      (sgt1_sg1_axis_tready   ),

      // AXIS Master for output data.
      .m_axis_tready       (axis_sg1_dac1_tready     ),
      .m_axis_tvalid       (axis_sg1_dac1_tvalid     ),
      .m_axis_tdata        (axis_sg1_dac1_tdata      )
   );
`endif

   //-----------------------------------------
   // ++++++++++++ SIGNAL GENERATOR 2 (axis_sg_mux8_v1)
   //-----------------------------------------
   // SG CDC m2 output -> sg_translator (OUT_TYPE=2, mux4 40-bit word) -> axis_sg_mux8_v1 -> DAC2
   sg_translator # (
      .OUT_TYPE               (2) // (0:gen_v6, 1:int4_v1, 2:mux4_v1, 3:readout)
   )
   u_sg_translator_2 (
      // Reset and clock.
      .aresetn                (1'bx),  // not used
      .aclk                   (1'bx),  // not used
      // IN WAVE PORT
      .s_axis_tdata           (sg2cdc_sgt2_axis_tdata),
      .s_axis_tvalid          (sg2cdc_sgt2_axis_tvalid),
      .s_axis_tready          (sg2cdc_sgt2_axis_tready),
      // OUT DATA gen_v6 (SEL:0)
      .m_gen_v6_axis_tdata    (),
      .m_gen_v6_axis_tvalid   (),
      .m_gen_v6_axis_tready   (),
      // OUT DATA int4_v1 (SEL:1)
      .m_int4_axis_tdata      (),
      .m_int4_axis_tvalid     (),
      .m_int4_axis_tready     (),
      // OUT DATA mux4_v1 (SEL:2)
      .m_mux4_axis_tdata      (sgt2_sg2_axis_tdata),
      .m_mux4_axis_tvalid     (sgt2_sg2_axis_tvalid),
      .m_mux4_axis_tready     (sgt2_sg2_axis_tready),
      // OUT DATA readout_v3 (SEL:3)
      .m_readout_axis_tdata   (),
      .m_readout_axis_tvalid  (),
      .m_readout_axis_tready  ()
   );

   axis_sg_mux8_v1 #(
      .N_DDS               (N_DDS_SG         ),
      // +++++++++++++ ADD EMULATOR PARAM
      .EMULATOR            (EMULATOR)
   )
   u_axis_sg_mux8_v1_0 (
      // AXI Slave I/F for configuration.
      .s_axi_aclk          (ps_clk           ),
      .s_axi_aresetn       (ps_resetn        ),
      .s_axi_awaddr        (s_axi_sg2_awaddr ),
      .s_axi_awprot        (s_axi_sg2_awprot ),
      .s_axi_awvalid       (s_axi_sg2_awvalid),
      .s_axi_awready       (s_axi_sg2_awready),
      .s_axi_wdata         (s_axi_sg2_wdata  ),
      .s_axi_wstrb         (s_axi_sg2_wstrb  ),
      .s_axi_wvalid        (s_axi_sg2_wvalid ),
      .s_axi_wready        (s_axi_sg2_wready ),
      .s_axi_bresp         (s_axi_sg2_bresp  ),
      .s_axi_bvalid        (s_axi_sg2_bvalid ),
      .s_axi_bready        (s_axi_sg2_bready ),
      .s_axi_araddr        (s_axi_sg2_araddr ),
      .s_axi_arprot        (s_axi_sg2_arprot ),
      .s_axi_arvalid       (s_axi_sg2_arvalid),
      .s_axi_arready       (s_axi_sg2_arready),
      .s_axi_rdata         (s_axi_sg2_rdata  ),
      .s_axi_rresp         (s_axi_sg2_rresp  ),
      .s_axi_rvalid        (s_axi_sg2_rvalid ),
      .s_axi_rready        (s_axi_sg2_rready ),

      // s_* and m_* reset/clock.
      .aresetn             (sg_resetn        ),
      .aclk                (sg_clk           ),

      // S_AXIS to queue waveforms (mux4 40-bit word from translator).
      .s_axis_tready       (sgt2_sg2_axis_tready ),
      .s_axis_tvalid       (sgt2_sg2_axis_tvalid ),
      .s_axis_tdata        (sgt2_sg2_axis_tdata  ),

      // AXIS Master for output data -> DAC2.
      .m_axis_tready       (axis_sg2_dac2_tready ),
      .m_axis_tvalid       (axis_sg2_dac2_tvalid ),
      .m_axis_tdata        (axis_sg2_dac2_tdata  )
   );
   // ++++++++++++

   //-----------------------------------------
   // READOUT
   //-----------------------------------------

`ifdef SIM_DEBUG
   // For Waveform Debug
   logic signed [15:0] axis_adc0_ro0_tdata_dbg [0:N_DDS_RO-1];
   always @* begin
      for (int i=0; i < N_DDS_RO; i=i+1) begin
         axis_adc0_ro0_tdata_dbg[i] = axis_adc0_ro0_tdata[16*i +: 16];
      end
   end
`endif

   // CDC for readout
   axis_cdcsync_v1 #(
      .N                         (1),     // Number of inputs/outputs.
      .B                         (168),   // Number of data bits.
      // ++++++++++++ ADD EMULATOR PARAMETER
      .EMULATOR                  (EMULATOR)
      // ++++++++++++
   )
   u_axis_rocdcsync_v1 (
      // S_AXIS for input data.
      .s_axis_aresetn            (t_resetn),
      .s_axis_aclk               (t_clk),
      .s0_axis_tready            (tproc_ro0cdc_axis_tready),
      .s0_axis_tvalid            (tproc_ro0cdc_axis_tvalid),
      .s0_axis_tdata             (tproc_ro0cdc_axis_tdata),
      .s1_axis_tready            (/*s1_axis_tready*/),
      .s1_axis_tvalid            (1'b0 /*s1_axis_tvalid*/),
      .s1_axis_tdata             (168'd0 /*s1_axis_tdata*/),
      .s2_axis_tready            (/*s2_axis_tready*/),
      .s2_axis_tvalid            (1'b0 /*s2_axis_tvalid*/),
      .s2_axis_tdata             (168'd0 /*s2_axis_tdata*/),
      .s3_axis_tready            (/*s3_axis_tready*/),
      .s3_axis_tvalid            (1'b0 /*s3_axis_tvalid*/),
      .s3_axis_tdata             (168'd0 /*s3_axis_tdata*/),
      .s4_axis_tready            (/*s4_axis_tready*/),
      .s4_axis_tvalid            (1'b0 /*s4_axis_tvalid*/),
      .s4_axis_tdata             (168'd0 /*s4_axis_tdata*/),
      .s5_axis_tready            (/*s5_axis_tready*/),
      .s5_axis_tvalid            (1'b0 /*s5_axis_tvalid*/),
      .s5_axis_tdata             (168'd0 /*s5_axis_tdata*/),
      .s6_axis_tready            (/*s6_axis_tready*/),
      .s6_axis_tvalid            (1'b0 /*s6_axis_tvalid*/),
      .s6_axis_tdata             (168'd0 /*s6_axis_tdata*/),
      .s7_axis_tready            (/*s7_axis_tready*/),
      .s7_axis_tvalid            (1'b0 /*s7_axis_tvalid*/),
      .s7_axis_tdata             (168'd0 /*s7_axis_tdata*/),
      .s8_axis_tready            (/*s8_axis_tready*/),
      .s8_axis_tvalid            (1'b0 /*s8_axis_tvalid*/),
      .s8_axis_tdata             (168'd0 /*s8_axis_tdata*/),
      .s9_axis_tready            (/*s9_axis_tready*/),
      .s9_axis_tvalid            (1'b0 /*s9_axis_tvalid*/),
      .s9_axis_tdata             (168'd0 /*s9_axis_tdata*/),
      .s10_axis_tready           (/*s10_axis_tready*/),
      .s10_axis_tvalid           (1'b0 /*s10_axis_tvalid*/),
      .s10_axis_tdata            (168'd0 /*s10_axis_tdata*/),
      .s11_axis_tready           (/*s11_axis_tready*/),
      .s11_axis_tvalid           (1'b0 /*s11_axis_tvalid*/),
      .s11_axis_tdata            (168'd0 /*s11_axis_tdata*/),
      .s12_axis_tready           (/*s12_axis_tready*/),
      .s12_axis_tvalid           (1'b0 /*s12_axis_tvalid*/),
      .s12_axis_tdata            (168'd0 /*s12_axis_tdata*/),
      .s13_axis_tready           (/*s13_axis_tready*/),
      .s13_axis_tvalid           (1'b0 /*s13_axis_tvalid*/),
      .s13_axis_tdata            (168'd0 /*s13_axis_tdata*/),
      .s14_axis_tready           (/*s14_axis_tready*/),
      .s14_axis_tvalid           (1'b0 /*s14_axis_tvalid*/),
      .s14_axis_tdata            (168'd0 /*s14_axis_tdata*/),
      .s15_axis_tready           (/*s15_axis_tready*/),
      .s15_axis_tvalid           (1'b0 /*s15_axis_tvalid*/),
      .s15_axis_tdata            (168'd0 /*s15_axis_tdata*/),
      // M_AXIS for output data.
      .m_axis_aresetn            (ro_resetn),
      .m_axis_aclk               (ro_clk),
      .m0_axis_tready            (rocdc_rot0_axis_tready),
      .m0_axis_tvalid            (rocdc_rot0_axis_tvalid),
      .m0_axis_tdata             (rocdc_rot0_axis_tdata),
      .m1_axis_tready            (1'b1 /*m1_axis_tready*/),
      .m1_axis_tvalid            (/*m1_axis_tvalid*/),
      .m1_axis_tdata             (/*m1_axis_tdata*/),
      .m2_axis_tready            (1'b1 /*m2_axis_tready*/),
      .m2_axis_tvalid            (/*m2_axis_tvalid*/),
      .m2_axis_tdata             (/*m2_axis_tdata*/),
      .m3_axis_tready            (1'b1 /*m3_axis_tready*/),
      .m3_axis_tvalid            (/*m3_axis_tvalid*/),
      .m3_axis_tdata             (/*m3_axis_tdata*/),
      .m4_axis_tready            (1'b1 /*m4_axis_tready*/),
      .m4_axis_tvalid            (/*m4_axis_tvalid*/),
      .m4_axis_tdata             (/*m4_axis_tdata*/),
      .m5_axis_tready            (1'b1 /*m5_axis_tready*/),
      .m5_axis_tvalid            (/*m5_axis_tvalid*/),
      .m5_axis_tdata             (/*m5_axis_tdata*/),
      .m6_axis_tready            (1'b1 /*m6_axis_tready*/),
      .m6_axis_tvalid            (/*m6_axis_tvalid*/),
      .m6_axis_tdata             (/*m6_axis_tdata*/),
      .m7_axis_tready            (1'b1 /*m7_axis_tready*/),
      .m7_axis_tvalid            (/*m7_axis_tvalid*/),
      .m7_axis_tdata             (/*m7_axis_tdata*/),
      .m8_axis_tready            (1'b1 /*m8_axis_tready*/),
      .m8_axis_tvalid            (/*m8_axis_tvalid*/),
      .m8_axis_tdata             (/*m8_axis_tdata*/),
      .m9_axis_tready            (1'b1 /*m9_axis_tready*/),
      .m9_axis_tvalid            (/*m9_axis_tvalid*/),
      .m9_axis_tdata             (/*m9_axis_tdata*/),
      .m10_axis_tready           (1'b1 /*m10_axis_tready*/),
      .m10_axis_tvalid           (/*m10_axis_tvalid*/),
      .m10_axis_tdata            (/*m10_axis_tdata*/),
      .m11_axis_tready           (1'b1 /*m11_axis_tready*/),
      .m11_axis_tvalid           (/*m11_axis_tvalid*/),
      .m11_axis_tdata            (/*m11_axis_tdata*/),
      .m12_axis_tready           (1'b1 /*m12_axis_tready*/),
      .m12_axis_tvalid           (/*m12_axis_tvalid*/),
      .m12_axis_tdata            (/*m12_axis_tdata*/),
      .m13_axis_tready           (1'b1 /*m13_axis_tready*/),
      .m13_axis_tvalid           (/*m13_axis_tvalid*/),
      .m13_axis_tdata            (/*m13_axis_tdata*/),
      .m14_axis_tready           (1'b1 /*m14_axis_tready*/),
      .m14_axis_tvalid           (/*m14_axis_tvalid*/),
      .m14_axis_tdata            (/*m14_axis_tdata*/),
      .m15_axis_tready           (1'b1 /*m15_axis_tready*/),
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
      .s_axis_tdata           (rocdc_rot0_axis_tdata),
      .s_axis_tvalid          (rocdc_rot0_axis_tvalid),
      .s_axis_tready          (rocdc_rot0_axis_tready),
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
      .m_readout_axis_tready  (rot_ro0_axis_tready),
      .m_readout_axis_tvalid  (rot_ro0_axis_tvalid),
      .m_readout_axis_tdata   (rot_ro0_axis_tdata)
   );

   wire              axis_ro0_avg0_tready;
   wire              axis_ro0_avg0_tvalid;
   wire [31:0]       axis_ro0_avg0_tdata;

   wire              axis_ro0_mrbuf_tvalid;
   wire [N_DDS_RO*2*16-1:0] axis_ro0_mrbuf_tdata;

   axis_dyn_readout_v1 #(
      /*.N_DDS            (N_DDS_RO)*/
      // +++++++++++++ ADD EMULATOR PARAM
      .EMULATOR         (EMULATOR         )
      // +++++++++++++
   )
   u_axis_dyn_readout_v1_0 (
      // Reset and clock.
      .aresetn          (ro_resetn),
      .aclk             (ro_clk),

      // s0_axis for pushing waveforms.
      .s0_axis_tready   (rot_ro0_axis_tready),
      .s0_axis_tvalid   (rot_ro0_axis_tvalid),
      .s0_axis_tdata    (rot_ro0_axis_tdata),

      // s1_axis for input data
      .s1_axis_tready   (axis_adc0_ro0_tready),
      .s1_axis_tvalid   (axis_adc0_ro0_tvalid),
      .s1_axis_tdata    (axis_adc0_ro0_tdata),

      // m0_axis to MR_Buffer
      .m0_axis_tready   (1'b1),
      .m0_axis_tvalid   (axis_ro0_mrbuf_tvalid),
      .m0_axis_tdata    (axis_ro0_mrbuf_tdata),
      
      // m1_axis to avg_buffer
      .m1_axis_tready   (axis_ro0_avg0_tready),
      .m1_axis_tvalid   (axis_ro0_avg0_tvalid),
      .m1_axis_tdata    (axis_ro0_avg0_tdata)
  );

`ifdef SIM_DEBUG
   // For Waveform Debug
   logic signed [15:0] axis_ro0_avg0_tdata_dbg [0:1];
   logic signed [15:0] axis_ro0_mrbuf_tdata_dbg [0:N_DDS_RO-1][0:1];
   always @* begin
      for (int i=0; i<2; i=i+1) begin
         axis_ro0_avg0_tdata_dbg[i] = axis_ro0_avg0_tdata[16*i +: 16];
      end
      for (int i=0; i<N_DDS_RO; i=i+1) begin
         for (int j=0; j<2; j=j+1) begin
            axis_ro0_mrbuf_tdata_dbg[i][j] = axis_ro0_mrbuf_tdata[16*(2*i+j) +: 16];
         end
      end
   end

   // For Waveform Debug
   logic signed [32:0] m1_ro0_avg0_abs_dbg;
   assign m1_ro0_avg0_abs_dbg = $signed(axis_ro0_avg0_tdata[15:0])*$signed(axis_ro0_avg0_tdata[15:0]) + 
                                 $signed(axis_ro0_avg0_tdata[31:16])*$signed(axis_ro0_avg0_tdata[31:16]);
`endif

   // Router output wires for avg0
   wire  [5:0]       s_axi_buf0_araddr;
   wire  [2:0]       s_axi_buf0_arprot;
   wire              s_axi_buf0_arready;
   wire              s_axi_buf0_arvalid;
   wire  [5:0]       s_axi_buf0_awaddr;
   wire  [2:0]       s_axi_buf0_awprot;
   wire              s_axi_buf0_awready;
   wire              s_axi_buf0_awvalid;
   wire              s_axi_buf0_bready;
   wire  [1:0]       s_axi_buf0_bresp;
   wire              s_axi_buf0_bvalid;
   wire  [31:0]      s_axi_buf0_rdata;
   wire              s_axi_buf0_rready;
   wire  [1:0]       s_axi_buf0_rresp;
   wire              s_axi_buf0_rvalid;
   wire  [31:0]      s_axi_buf0_wdata;
   wire              s_axi_buf0_wready;
   wire  [3:0]       s_axi_buf0_wstrb;
   wire              s_axi_buf0_wvalid;

   axis_avg_buffer #(
      .N_AVG                  (13               ),
      .N_BUF                  (12               ),
      .B                      (16               ),
      // +++++++++++++ ADD EMULATOR PARAM
      .EMULATOR               (EMULATOR         )
      // +++++++++++++
   )
   u_axis_avg_buffer_0 ( 
      // AXI Slave I/F for configuration.
      .s_axi_aclk             (ps_clk       ),
      .s_axi_aresetn          (ps_resetn    ),
      .s_axi_araddr           (s_axi_buf0_araddr    ),
      .s_axi_arprot           (s_axi_buf0_arprot    ),
      .s_axi_arready          (s_axi_buf0_arready   ),
      .s_axi_arvalid          (s_axi_buf0_arvalid   ),
      .s_axi_awaddr           (s_axi_buf0_awaddr    ),
      .s_axi_awprot           (s_axi_buf0_awprot    ),
      .s_axi_awready          (s_axi_buf0_awready   ),
      .s_axi_awvalid          (s_axi_buf0_awvalid   ),
      .s_axi_bready           (s_axi_buf0_bready    ),
      .s_axi_bresp            (s_axi_buf0_bresp     ),
      .s_axi_bvalid           (s_axi_buf0_bvalid    ),
      .s_axi_rdata            (s_axi_buf0_rdata     ),
      .s_axi_rready           (s_axi_buf0_rready    ),
      .s_axi_rresp            (s_axi_buf0_rresp     ),
      .s_axi_rvalid           (s_axi_buf0_rvalid    ),
      .s_axi_wdata            (s_axi_buf0_wdata     ),
      .s_axi_wready           (s_axi_buf0_wready    ),
      .s_axi_wstrb            (s_axi_buf0_wstrb     ),
      .s_axi_wvalid           (s_axi_buf0_wvalid    ),

      // Trigger input.
      .trigger                (trig_10              ),

      // AXIS Slave for input data.
      .s_axis_aresetn         (ro_resetn             ),
      .s_axis_aclk            (ro_clk                ),
      .s_axis_tready          (axis_ro0_avg0_tready  ),
      .s_axis_tvalid          (axis_ro0_avg0_tvalid  ),
      .s_axis_tdata           (axis_ro0_avg0_tdata   ),

      // Reset and clock for m0 and m1.
      .m_axis_aclk            (ps_clk         ),
      .m_axis_aresetn         (ps_resetn      ),

      // AXIS Master for averaged output.
      .m0_axis_tready         (1'b1 /*buf0_m0_axis_avg_tready*/),
      .m0_axis_tvalid         (buf0_m0_axis_avg_tvalid),
      .m0_axis_tdata          (buf0_m0_axis_avg_tdata ),
      .m0_axis_tlast          (buf0_m0_axis_avg_tlast),

      // AXIS Master for decimated output.
      .m1_axis_tready         (1'b1 /*buf0_m1_axis_dec_tready*/),
      .m1_axis_tvalid         (buf0_m1_axis_dec_tvalid),
      .m1_axis_tdata          (buf0_m1_axis_dec_tdata ),
      .m1_axis_tlast          (buf0_m1_axis_dec_tlast),

      // AXIS Master for register output to TPROC Data In Interface
      .m2_axis_tready         (buf0_m2_axis_reg_tready),
      .m2_axis_tvalid         (buf0_m2_axis_reg_tvalid),
      .m2_axis_tdata          (buf0_m2_axis_reg_tdata )
   );


`ifdef SIM_DEBUG
   // For Waveform Debug
   logic [64:0] buf_avg_abs_dbg;
   always @(posedge ps_clk) begin
      if (buf0_m0_axis_avg_tvalid) begin
         buf_avg_abs_dbg <= $signed(buf0_m0_axis_avg_tdata[31:0]) * $signed(buf0_m0_axis_avg_tdata[31:0]) + 
                              $signed(buf0_m0_axis_avg_tdata[63:32]) * $signed(buf0_m0_axis_avg_tdata[63:32]);
      end
   end

   // For Waveform Debug
   logic [32:0] buf_dec_abs_dbg;
   always @(posedge ps_clk) begin
      if (buf0_m1_axis_dec_tvalid) begin
         buf_dec_abs_dbg <= $signed(buf0_m1_axis_dec_tdata[15:0]) * $signed(buf0_m1_axis_dec_tdata[15:0]) + 
                              $signed(buf0_m1_axis_dec_tdata[31:16]) * $signed(buf0_m1_axis_dec_tdata[31:16]);
      end
   end
`endif



   wire              axis_ro1_avg1_tready;
   wire              axis_ro1_avg1_tvalid;
   wire [31:0]       axis_ro1_avg1_tdata;

   // Readout_v2 PYNQ configured
   axis_readout_v2 #(
      // +++++++++++++ ADD EMULATOR PARAM
      .EMULATOR               (EMULATOR         )
      // +++++++++++++
   )
   u_axis_readout_v2 (
      // AXI Slave I/F for configuration.
      .s_axi_aclk        (ps_clk   ),
      .s_axi_aresetn     (ps_resetn),
      .s_axi_awaddr      (s_axi_rov2_awaddr),
      .s_axi_awprot      (s_axi_rov2_awprot),
      .s_axi_awvalid     (s_axi_rov2_awvalid),
      .s_axi_awready     (s_axi_rov2_awready),
      .s_axi_wdata       (s_axi_rov2_wdata),
      .s_axi_wstrb       (s_axi_rov2_wstrb),
      .s_axi_wvalid      (s_axi_rov2_wvalid),
      .s_axi_wready      (s_axi_rov2_wready),
      .s_axi_bresp       (s_axi_rov2_bresp),
      .s_axi_bvalid      (s_axi_rov2_bvalid),
      .s_axi_bready      (s_axi_rov2_bready),
      .s_axi_araddr      (s_axi_rov2_araddr),
      .s_axi_arprot      (s_axi_rov2_arprot),
      .s_axi_arvalid     (s_axi_rov2_arvalid),
      .s_axi_arready     (s_axi_rov2_arready),
      .s_axi_rdata       (s_axi_rov2_rdata),
      .s_axi_rresp       (s_axi_rov2_rresp),
      .s_axi_rvalid      (s_axi_rov2_rvalid),
      .s_axi_rready      (s_axi_rov2_rready),
      // Reset and clock (s_axis, m0_axis, m1_axis).
      .aresetn           (ro_resetn),
      .aclk              (ro_clk),
      // S_AXIS: for input data (8x samples per clock).
      .s_axis_tdata	    (axis_adc1_ro1_tdata),
      .s_axis_tvalid     (axis_adc1_ro1_tvalid),
      .s_axis_tready     (axis_adc1_ro1_tready),
      // M0_AXIS: for output data (before filter and decimation, 8x samples per clock).
      .m0_axis_tready    (/*m0_axis_tready*/),
      .m0_axis_tvalid    (/*m0_axis_tvalid*/),
      .m0_axis_tdata     (/*m0_axis_tdata*/),
      // M1_AXIS: for output data.
      .m1_axis_tready    (axis_ro1_avg1_tready  ),
      .m1_axis_tvalid    (axis_ro1_avg1_tvalid  ),
      .m1_axis_tdata     (axis_ro1_avg1_tdata   )
   );


   axis_avg_buffer #(
      .N_AVG                  (13               ),
      .N_BUF                  (12               ),
      .B                      (16               ),
      // +++++++++++++ ADD EMULATOR PARAM
      .EMULATOR               (EMULATOR         )
      // +++++++++++++
   )
   u_axis_avg_buffer_1 ( 
      // AXI Slave I/F for configuration.
      .s_axi_aclk             (ps_clk               ),
      .s_axi_aresetn          (ps_resetn            ),
      .s_axi_araddr           (s_axi_buf1_araddr    ),
      .s_axi_arprot           (s_axi_buf1_arprot    ),
      .s_axi_arready          (s_axi_buf1_arready   ),
      .s_axi_arvalid          (s_axi_buf1_arvalid   ),
      .s_axi_awaddr           (s_axi_buf1_awaddr    ),
      .s_axi_awprot           (s_axi_buf1_awprot    ),
      .s_axi_awready          (s_axi_buf1_awready   ),
      .s_axi_awvalid          (s_axi_buf1_awvalid   ),
      .s_axi_bready           (s_axi_buf1_bready    ),
      .s_axi_bresp            (s_axi_buf1_bresp     ),
      .s_axi_bvalid           (s_axi_buf1_bvalid    ),
      .s_axi_rdata            (s_axi_buf1_rdata     ),
      .s_axi_rready           (s_axi_buf1_rready    ),
      .s_axi_rresp            (s_axi_buf1_rresp     ),
      .s_axi_rvalid           (s_axi_buf1_rvalid    ),
      .s_axi_wdata            (s_axi_buf1_wdata     ),
      .s_axi_wready           (s_axi_buf1_wready    ),
      .s_axi_wstrb            (s_axi_buf1_wstrb     ),
      .s_axi_wvalid           (s_axi_buf1_wvalid    ),

      // Trigger input.
      .trigger                (trig_11              ),

      // AXIS Slave for input data.
      .s_axis_aresetn         (ro_resetn             ),
      .s_axis_aclk            (ro_clk                ),
      .s_axis_tready          (axis_ro1_avg1_tready  ),
      .s_axis_tvalid          (axis_ro1_avg1_tvalid  ),
      .s_axis_tdata           (axis_ro1_avg1_tdata   ),

      // Reset and clock for m0 and m1.
      .m_axis_aclk            (ps_clk         ),
      .m_axis_aresetn         (ps_resetn      ),

      // AXIS Master for averaged output.
      .m0_axis_tready         (1'b1 /*buf1_m0_axis_avg_tready*/),
      .m0_axis_tvalid         (buf1_m0_axis_avg_tvalid),
      .m0_axis_tdata          (buf1_m0_axis_avg_tdata ),
      .m0_axis_tlast          (buf1_m0_axis_avg_tlast),

      // AXIS Master for decimated output.
      .m1_axis_tready         (1'b1 /*buf1_m1_axis_dec_tready*/),
      .m1_axis_tvalid         (buf1_m1_axis_dec_tvalid),
      .m1_axis_tdata          (buf1_m1_axis_dec_tdata ),
      .m1_axis_tlast          (buf1_m1_axis_dec_tlast),

      // AXIS Master for register output to TPROC Data In Interface
      .m2_axis_tready         (buf1_m2_axis_reg_tready),
      .m2_axis_tvalid         (buf1_m2_axis_reg_tvalid),
      .m2_axis_tdata          (buf1_m2_axis_reg_tdata )
   );


   // axis_pfb_readout_v3 signals
   logic                     pfb_ro_m0_axis_tvalid;
   logic [31:0]              pfb_ro_m0_axis_tdata;
   logic                     pfb_ro_m1_axis_tvalid;
   logic [31:0]              pfb_ro_m1_axis_tdata;
   logic                     pfb_ro_m2_axis_tvalid;
   logic [31:0]              pfb_ro_m2_axis_tdata;
   logic                     pfb_ro_m3_axis_tvalid;
   logic [31:0]              pfb_ro_m3_axis_tdata;

   assign axis_adc2_ro2_tready = 1'b1;

   // axis_pfb_readout_v3 instance
   axis_pfb_readout_v3 #(
      .EMULATOR               (EMULATOR         )
   )
   u_axis_pfb_readout_v3 (
      // AXI Slave I/F for configuration.
      .s_axi_aclk             (ps_clk               ),
      .s_axi_aresetn          (ps_resetn            ),
      .s_axi_araddr           (s_axi_pfb_ro_araddr  ),
      .s_axi_arprot           (s_axi_pfb_ro_arprot  ),
      .s_axi_arready          (s_axi_pfb_ro_arready ),
      .s_axi_arvalid          (s_axi_pfb_ro_arvalid ),
      .s_axi_awaddr           (s_axi_pfb_ro_awaddr  ),
      .s_axi_awprot           (s_axi_pfb_ro_awprot  ),
      .s_axi_awready          (s_axi_pfb_ro_awready ),
      .s_axi_awvalid          (s_axi_pfb_ro_awvalid ),
      .s_axi_bready           (s_axi_pfb_ro_bready  ),
      .s_axi_bresp            (s_axi_pfb_ro_bresp   ),
      .s_axi_bvalid           (s_axi_pfb_ro_bvalid  ),
      .s_axi_rdata            (s_axi_pfb_ro_rdata   ),
      .s_axi_rready           (s_axi_pfb_ro_rready  ),
      .s_axi_rresp            (s_axi_pfb_ro_rresp   ),
      .s_axi_rvalid           (s_axi_pfb_ro_rvalid  ),
      .s_axi_wdata            (s_axi_pfb_ro_wdata   ),
      .s_axi_wready           (s_axi_pfb_ro_wready  ),
      .s_axi_wstrb            (s_axi_pfb_ro_wstrb   ),
      .s_axi_wvalid           (s_axi_pfb_ro_wvalid  ),

      // Reset and clock.
      .aresetn                (ro_resetn            ),
      .aclk                   (ro_clk               ),

      // S_AXIS for input samples
      .s_axis_tvalid          (axis_adc2_ro2_tvalid ),
      .s_axis_tdata           (axis_adc2_ro2_tdata  ),

      // M_AXIS for CH0-3 output.
      .m0_axis_tvalid         (pfb_ro_m0_axis_tvalid),
      .m0_axis_tdata          (pfb_ro_m0_axis_tdata ),
      .m1_axis_tvalid         (pfb_ro_m1_axis_tvalid),
      .m1_axis_tdata          (pfb_ro_m1_axis_tdata ),
      .m2_axis_tvalid         (pfb_ro_m2_axis_tvalid),
      .m2_axis_tdata          (pfb_ro_m2_axis_tdata ),
      .m3_axis_tvalid         (pfb_ro_m3_axis_tvalid),
      .m3_axis_tdata          (pfb_ro_m3_axis_tdata )
   );


   axis_avg_buffer #(
      .N_AVG                  (13               ),
      .N_BUF                  (12               ),
      .B                      (16               ),
      // +++++++++++++ ADD EMULATOR PARAM
      .EMULATOR               (EMULATOR         )
      // +++++++++++++
   )
   u_axis_avg_buffer_2 ( 
      // AXI Slave I/F for configuration.
      .s_axi_aclk             (ps_clk               ),
      .s_axi_aresetn          (ps_resetn            ),
      .s_axi_araddr           (s_axi_buf2_araddr    ),
      .s_axi_arprot           (s_axi_buf2_arprot    ),
      .s_axi_arready          (s_axi_buf2_arready   ),
      .s_axi_arvalid          (s_axi_buf2_arvalid   ),
      .s_axi_awaddr           (s_axi_buf2_awaddr    ),
      .s_axi_awprot           (s_axi_buf2_awprot    ),
      .s_axi_awready          (s_axi_buf2_awready   ),
      .s_axi_awvalid          (s_axi_buf2_awvalid   ),
      .s_axi_bready           (s_axi_buf2_bready    ),
      .s_axi_bresp            (s_axi_buf2_bresp     ),
      .s_axi_bvalid           (s_axi_buf2_bvalid    ),
      .s_axi_rdata            (s_axi_buf2_rdata     ),
      .s_axi_rready           (s_axi_buf2_rready    ),
      .s_axi_rresp            (s_axi_buf2_rresp     ),
      .s_axi_rvalid           (s_axi_buf2_rvalid    ),
      .s_axi_wdata            (s_axi_buf2_wdata     ),
      .s_axi_wready           (s_axi_buf2_wready    ),
      .s_axi_wstrb            (s_axi_buf2_wstrb     ),
      .s_axi_wvalid           (s_axi_buf2_wvalid    ),

      // Trigger input.
      .trigger                (trig_12              ),

      // AXIS Slave for input data.
      .s_axis_aresetn         (ro_resetn             ),
      .s_axis_aclk            (ro_clk                ),
      .s_axis_tvalid          (pfb_ro_m0_axis_tvalid ),
      .s_axis_tdata           (pfb_ro_m0_axis_tdata  ),

      // Reset and clock for m0 and m1.
      .m_axis_aclk            (ps_clk         ),
      .m_axis_aresetn         (ps_resetn      ),

      // AXIS Master for averaged output.
      .m0_axis_tready         (1'b1 /*buf1_m0_axis_avg_tready*/),
      .m0_axis_tvalid         (buf2_m0_axis_avg_tvalid),
      .m0_axis_tdata          (buf2_m0_axis_avg_tdata ),
      .m0_axis_tlast          (buf2_m0_axis_avg_tlast),

      // AXIS Master for decimated output.
      .m1_axis_tready         (1'b1 /*buf1_m1_axis_dec_tready*/),
      .m1_axis_tvalid         (buf2_m1_axis_dec_tvalid),
      .m1_axis_tdata          (buf2_m1_axis_dec_tdata ),
      .m1_axis_tlast          (buf2_m1_axis_dec_tlast),

      // AXIS Master for register output to TPROC Data In Interface
      .m2_axis_tready         (buf2_m2_axis_reg_tready),
      .m2_axis_tvalid         (buf2_m2_axis_reg_tvalid),
      .m2_axis_tdata          (buf2_m2_axis_reg_tdata )
   );

   axis_avg_buffer #(
      .N_AVG                  (13               ),
      .N_BUF                  (12               ),
      .B                      (16               ),
      // +++++++++++++ ADD EMULATOR PARAM
      .EMULATOR               (EMULATOR         )
      // +++++++++++++
   )
   u_axis_avg_buffer_3 ( 
      // AXI Slave I/F for configuration.
      .s_axi_aclk             (ps_clk               ),
      .s_axi_aresetn          (ps_resetn            ),
      .s_axi_araddr           (s_axi_buf3_araddr    ),
      .s_axi_arprot           (s_axi_buf3_arprot    ),
      .s_axi_arready          (s_axi_buf3_arready   ),
      .s_axi_arvalid          (s_axi_buf3_arvalid   ),
      .s_axi_awaddr           (s_axi_buf3_awaddr    ),
      .s_axi_awprot           (s_axi_buf3_awprot    ),
      .s_axi_awready          (s_axi_buf3_awready   ),
      .s_axi_awvalid          (s_axi_buf3_awvalid   ),
      .s_axi_bready           (s_axi_buf3_bready    ),
      .s_axi_bresp            (s_axi_buf3_bresp     ),
      .s_axi_bvalid           (s_axi_buf3_bvalid    ),
      .s_axi_rdata            (s_axi_buf3_rdata     ),
      .s_axi_rready           (s_axi_buf3_rready    ),
      .s_axi_rresp            (s_axi_buf3_rresp     ),
      .s_axi_rvalid           (s_axi_buf3_rvalid    ),
      .s_axi_wdata            (s_axi_buf3_wdata     ),
      .s_axi_wready           (s_axi_buf3_wready    ),
      .s_axi_wstrb            (s_axi_buf3_wstrb     ),
      .s_axi_wvalid           (s_axi_buf3_wvalid    ),

      // Trigger input.
      .trigger                (trig_13              ),

      // AXIS Slave for input data.
      .s_axis_aresetn         (ro_resetn             ),
      .s_axis_aclk            (ro_clk                ),
      .s_axis_tvalid          (pfb_ro_m1_axis_tvalid ),
      .s_axis_tdata           (pfb_ro_m1_axis_tdata  ),

      // Reset and clock for m0 and m1.
      .m_axis_aclk            (ps_clk         ),
      .m_axis_aresetn         (ps_resetn      ),

      // AXIS Master for averaged output.
      .m0_axis_tready         (1'b1 /*buf3_m0_axis_avg_tready*/),
      .m0_axis_tvalid         (buf3_m0_axis_avg_tvalid),
      .m0_axis_tdata          (buf3_m0_axis_avg_tdata ),
      .m0_axis_tlast          (buf3_m0_axis_avg_tlast),

      // AXIS Master for decimated output.
      .m1_axis_tready         (1'b1 /*buf3_m1_axis_dec_tready*/),
      .m1_axis_tvalid         (buf3_m1_axis_dec_tvalid),
      .m1_axis_tdata          (buf3_m1_axis_dec_tdata ),
      .m1_axis_tlast          (buf3_m1_axis_dec_tlast),

      // AXIS Master for register output to TPROC Data In Interface
      .m2_axis_tready         (buf3_m2_axis_reg_tready),
      .m2_axis_tvalid         (buf3_m2_axis_reg_tvalid),
      .m2_axis_tdata          (buf3_m2_axis_reg_tdata )
   );


endmodule
