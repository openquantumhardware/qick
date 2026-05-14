// qick_dut: wrapper module that exposes AXIS_QPROC ports and keeps the AXI link internal
module qick_dut #(
   // QickEmu Parameters
   parameter EMULATOR         = 0, // Set to 1 to enable QickEmu simulation
   // General Settings
   parameter N_DDS_SG         = 16,
   parameter N_DDS_RO         = 8,
   // PROCESSOR PARAMETERS
   parameter GEN_SYNC         = 1,
   parameter DUAL_CORE        = 0,
   parameter IO_CTRL          = 1,
   parameter DEBUG            = 3,
   parameter TNET             = 0,
   parameter QCOM             = 0,
   parameter CUSTOM_PERIPH    = 2,
   parameter LFSR             = 1,
   parameter DIVIDER          = 1,
   parameter ARITH            = 1,
   parameter TIME_READ        = 1,
   parameter FIFO_DEPTH       = 8,
   parameter PMEM_AW          = 12,
   parameter DMEM_AW          = 14,
   parameter WMEM_AW          = 11,
   parameter REG_AW           = 4,
   parameter IN_PORT_QTY      = 1,
   parameter OUT_TRIG_QTY     = 1,
   parameter OUT_DPORT_QTY    = 1,
   parameter OUT_DPORT_DW     = 8,
   parameter OUT_WPORT_QTY    = 5
)(
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
   // AXIS DATA in
   input  logic       [63:0]   s0_axis_tdata,
   input  logic                s0_axis_tvalid,
   output logic                s0_axis_tready,
   input  logic       [63:0]   s1_axis_tdata,
   input  logic                s1_axis_tvalid,
   output logic                s1_axis_tready,
   ///// TRIGGERS
   output logic                trig_0_o,
   // OUT DATA PORTS
   output logic       [OUT_DPORT_DW-1:0]    port_0_dt_o,
   output logic       [OUT_DPORT_DW-1:0]    port_1_dt_o,
   output logic       [OUT_DPORT_DW-1:0]    port_2_dt_o,
   output logic       [OUT_DPORT_DW-1:0]    port_3_dt_o,
   // Debug Signals
   output logic       [31:0]        ps_debug_do,
   output logic       [31:0]        t_debug_do,
   output logic       [31:0]        t_fifo_do,
   output logic       [31:0]        c_time_usr_do,
   output logic       [31:0]        c_debug_do,
   output logic       [31:0]        c_time_ref_do,
   output logic       [31:0]        c_proc_do,
   output logic       [31:0]        c_port_do,
   output logic       [31:0]        c_core_do,

   input logic                      sg_s0_axis_aclk,
   input logic                      sg_s0_axis_aresetn,
   input logic        [31:0]        sg_s0_axis_tdata,
   input logic                      sg_s0_axis_tvalid,
   output logic                     sg_s0_axis_tready,

   // AXIS DAC Signal Generator
   input logic                      axis_sg_dac_tready,
   output logic                     axis_sg_dac_tvalid,
   output logic [N_DDS_SG*16-1:0]   axis_sg_dac_tdata,

   // AXIS ADC Readout
   output logic                     axis_adc_ro_tready,
   input logic                      axis_adc_ro_tvalid,
   input logic [N_DDS_RO*16-1:0]    axis_adc_ro_tdata,

   output logic                     axis_ro_mrbuf_tvalid,
   output logic [N_DDS_RO*2*16-1:0] axis_ro_mrbuf_tdata,

   // Readout Averaged Buffer AXIS
   input logic                      m0_axis_buf_avg_tready,
   output logic                     m0_axis_buf_avg_tvalid,
   output logic [63:0]              m0_axis_buf_avg_tdata,
   output logic                     m0_axis_buf_avg_tlast,

   // Readout Decimated Buffer AXIS
   input logic                      m1_axis_buf_dec_tready,
   output logic                     m1_axis_buf_dec_tvalid,
   output logic [31:0]              m1_axis_buf_dec_tdata,
   output logic                     m1_axis_buf_dec_tlast,

   // Readout Buffer Reg AXIS
   input logic                      m2_axis_buf_reg_tready,
   output logic                     m2_axis_buf_reg_tvalid,
   output logic [63:0]              m2_axis_buf_reg_tdata
);

   // AXI VIP master address.
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


   // Internal AXI-Lite wires (kept inside qick_dut)
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

   // Instantiate Axi Master for tproc (connect to internal s_axi_tproc_* wires)
   generate
      if (EMULATOR == 0) begin: gen_axi_tproc_vip
         // <<<<<<<<<<<< XILINX AXI VIP
         axi_mst_0 u_axi_mst_tproc_0 (
            .aclk          (ps_clk              ),
            .aresetn       (ps_resetn           ),
            .m_axi_araddr  (s_axi_tproc_araddr  ),
            .m_axi_arprot  (s_axi_tproc_arprot  ),
            .m_axi_arready (s_axi_tproc_arready ),
            .m_axi_arvalid (s_axi_tproc_arvalid ),
            .m_axi_awaddr  (s_axi_tproc_awaddr  ),
            .m_axi_awprot  (s_axi_tproc_awprot  ),
            .m_axi_awready (s_axi_tproc_awready ),
            .m_axi_awvalid (s_axi_tproc_awvalid ),
            .m_axi_bready  (s_axi_tproc_bready  ),
            .m_axi_bresp   (s_axi_tproc_bresp   ),
            .m_axi_bvalid  (s_axi_tproc_bvalid  ),
            .m_axi_rdata   (s_axi_tproc_rdata   ),
            .m_axi_rready  (s_axi_tproc_rready  ),
            .m_axi_rresp   (s_axi_tproc_rresp   ),
            .m_axi_rvalid  (s_axi_tproc_rvalid  ),
            .m_axi_wdata   (s_axi_tproc_wdata   ),
            .m_axi_wready  (s_axi_tproc_wready  ),
            .m_axi_wstrb   (s_axi_tproc_wstrb   ),
            .m_axi_wvalid  (s_axi_tproc_wvalid  )
         );
      end
      else begin: gen_axi_tproc_emu
         // <<<<<<<<<<<< PULP PLATFORM AXI VIP
         AXI_LITE #(
            .AXI_ADDR_WIDTH ( 8      ),
            .AXI_DATA_WIDTH ( 32     )
         ) axi_mst_tproc_IF ();
         AXI_LITE_DV #(
            .AXI_ADDR_WIDTH ( 8       ),
            .AXI_DATA_WIDTH ( 32      )
         ) axi_mst_tproc_dv_IF (ps_clk);
         `ifdef VERILATOR
         `AXI_LITE_ASSIGN(axi_mst_tproc_IF, axi_mst_tproc_dv_IF)
         `endif

         assign s_axi_tproc_araddr        = axi_mst_tproc_IF.ar_addr  ; /* TPROC  input */
         assign s_axi_tproc_arprot        = axi_mst_tproc_IF.ar_prot  ; /* TPROC  input */
         assign s_axi_tproc_arvalid       = axi_mst_tproc_IF.ar_valid ; /* TPROC  input */
         assign axi_mst_tproc_IF.ar_ready = s_axi_tproc_arready       ; /* TPROC output */

         assign s_axi_tproc_awaddr        = axi_mst_tproc_IF.aw_addr  ; /* TPROC  input */
         assign s_axi_tproc_awprot        = axi_mst_tproc_IF.aw_prot  ; /* TPROC  input */
         assign s_axi_tproc_awvalid       = axi_mst_tproc_IF.aw_valid ; /* TPROC  input */
         assign axi_mst_tproc_IF.aw_ready = s_axi_tproc_awready       ; /* TPROC output */

         assign axi_mst_tproc_IF.b_resp   = s_axi_tproc_bresp         ; /* TPROC output */
         assign axi_mst_tproc_IF.b_valid  = s_axi_tproc_bvalid        ; /* TPROC output */
         assign s_axi_tproc_bready        = axi_mst_tproc_IF.b_ready  ; /* TPROC  input */

         assign axi_mst_tproc_IF.r_resp   = s_axi_tproc_rresp         ; /* TPROC output */
         assign axi_mst_tproc_IF.r_valid  = s_axi_tproc_rvalid        ; /* TPROC output */
         assign axi_mst_tproc_IF.r_data   = s_axi_tproc_rdata         ; /* TPROC output */
         assign s_axi_tproc_rready        = axi_mst_tproc_IF.r_ready  ; /* TPROC  input */

         assign s_axi_tproc_wdata         = axi_mst_tproc_IF.w_data   ; /* TPROC  input */
         assign s_axi_tproc_wstrb         = axi_mst_tproc_IF.w_strb   ; /* TPROC  input */
         assign s_axi_tproc_wvalid        = axi_mst_tproc_IF.w_valid  ; /* TPROC  input */
         assign axi_mst_tproc_IF.w_ready  = s_axi_tproc_wready        ; /* TPROC output */
      end
   endgenerate

   // Instantiate Axis Qick Processor and connect AXI ports to internal wires
   axis_qick_processor #(
      .DUAL_CORE           ( DUAL_CORE            ) ,
      .GEN_SYNC            ( GEN_SYNC             ) ,
      .IO_CTRL             ( IO_CTRL              ) ,
      .DEBUG               ( DEBUG                ) ,
      // .TNET                ( TNET                 ) ,
      .QCOM                ( QCOM                 ) ,
      .CUSTOM_PERIPH       ( CUSTOM_PERIPH        ) ,
      .LFSR                ( LFSR                 ) ,
      .DIVIDER             ( DIVIDER              ) ,
      .ARITH               ( ARITH                ) ,
      .TIME_READ           ( TIME_READ            ) ,
      .FIFO_DEPTH          ( FIFO_DEPTH           ) ,
      .PMEM_AW             ( PMEM_AW              ) ,
      .DMEM_AW             ( DMEM_AW              ) ,
      .WMEM_AW             ( WMEM_AW              ) ,
      .REG_AW              ( REG_AW               ) ,
      .IN_PORT_QTY         ( IN_PORT_QTY          ) ,
      .OUT_TRIG_QTY        ( OUT_TRIG_QTY         ) ,
      .OUT_DPORT_QTY       ( OUT_DPORT_QTY        ) ,
      .OUT_DPORT_DW        ( OUT_DPORT_DW         ) , 
      .OUT_WPORT_QTY       ( OUT_WPORT_QTY        ) ,
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
      .s0_axis_tdata        ( s0_axis_tdata        ),
      .s0_axis_tvalid       ( s0_axis_tvalid       ),
      .s0_axis_tready       ( s0_axis_tready       ),
      .s1_axis_tdata        ( s1_axis_tdata        ),
      .s1_axis_tvalid       ( s1_axis_tvalid       ),
      .s1_axis_tready       ( s1_axis_tready       ),
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
      .m0_axis_tdata        ( tproc_sgcdc_0_axis_tdata        ),
      .m0_axis_tvalid       ( tproc_sgcdc_0_axis_tvalid       ),
      .m0_axis_tready       ( tproc_sgcdc_0_axis_tready       ),
      .m1_axis_tdata        ( /*m1_axis_tdata*/        ),
      .m1_axis_tvalid       ( /*m1_axis_tvalid*/       ),
      .m1_axis_tready       ( 1'b0 /*m1_axis_tready*/       ),
      .m2_axis_tdata        ( /*m2_axis_tdata*/        ),
      .m2_axis_tvalid       ( /*m2_axis_tvalid*/       ),
      .m2_axis_tready       ( 1'b0 /*m2_axis_tready*/       ),
      .m3_axis_tdata        ( /*m3_axis_tdata*/        ),
      .m3_axis_tvalid       ( /*m3_axis_tvalid*/       ),
      .m3_axis_tready       ( 1'b0 /*m3_axis_tready*/       ),
      .m4_axis_tdata        ( tproc_rocdc_0_axis_tdata        ),
      .m4_axis_tvalid       ( tproc_rocdc_0_axis_tvalid       ),
      .m4_axis_tready       ( tproc_rocdc_0_axis_tready       ),
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
      .trig_0_o             ( trig_0_o             ),
      .trig_1_o             ( /*trig_1_o*/             ),
      .trig_2_o             ( /*trig_2_o*/             ),
      .trig_3_o             ( /*trig_3_o*/             ),
      .trig_4_o             ( /*trig_4_o*/             ),
      .trig_5_o             ( /*trig_5_o*/             ),
      .trig_6_o             ( /*trig_6_o*/             ),
      .trig_7_o             ( /*trig_7_o*/             ),
      .trig_8_o             ( /*trig_8_o*/             ),
      .trig_9_o             ( /*trig_9_o*/             ),
      .trig_10_o            ( /*trig_10_o*/            ),
      .trig_11_o            ( /*trig_11_o*/            ),
      .trig_12_o            ( /*trig_12_o*/            ),
      .trig_13_o            ( /*trig_13_o*/            ),
      .trig_14_o            ( /*trig_14_o*/            ),
      .trig_15_o            ( /*trig_15_o*/            ),
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

// <<<<<<<<<<<< XILINX AXI VIP
   // xil_axi_ulong     SG_ADDR_START_ADDR   = 32'h40000000; // 0
   // xil_axi_ulong     SG_ADDR_WE           = 32'h40000004; // 1
// ============
   // logic [5:0] SG_ADDR_START_ADDR = 6'h00;
   // logic [5:0] SG_ADDR_WE         = 6'h04;
// >>>>>>>>>>>> PULP PLATFORM AXI VIP

   generate;
      if (EMULATOR == 0) begin: gen_axi_sg_vip
         // <<<<<<<<<<<< XILINX AXI VIP
         axi_mst_0 u_axi_mst_sg_0 (
            .aclk          (ps_clk           ),
            .aresetn       (ps_resetn        ),
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
      end
      else begin: gen_axi_sg_emu
         // <<<<<<<<<<<< PULP PLATFORM AXI VIP
         AXI_LITE #(
            .AXI_ADDR_WIDTH ( 6      ),
            .AXI_DATA_WIDTH ( 32     )
         ) axi_mst_sg_IF ();
         AXI_LITE_DV #(
            .AXI_ADDR_WIDTH ( 6       ),
            .AXI_DATA_WIDTH ( 32      )
         ) axi_mst_sg_dv_IF (ps_clk);
         `ifdef VERILATOR
         `AXI_LITE_ASSIGN(axi_mst_sg_IF, axi_mst_sg_dv_IF)
         `endif
         assign s_axi_sg_araddr        = axi_mst_sg_IF.ar_addr  ; /* SG  input */
         assign s_axi_sg_arprot        = axi_mst_sg_IF.ar_prot  ; /* SG  input */
         assign s_axi_sg_arvalid       = axi_mst_sg_IF.ar_valid ; /* SG  input */
         assign axi_mst_sg_IF.ar_ready = s_axi_sg_arready       ; /* SG output */

         assign s_axi_sg_awaddr        = axi_mst_sg_IF.aw_addr  ; /* SG  input */
         assign s_axi_sg_awprot        = axi_mst_sg_IF.aw_prot  ; /* SG  input */
         assign s_axi_sg_awvalid       = axi_mst_sg_IF.aw_valid ; /* SG  input */
         assign axi_mst_sg_IF.aw_ready = s_axi_sg_awready       ; /* SG output */

         assign axi_mst_sg_IF.b_resp   = s_axi_sg_bresp         ; /* SG output */
         assign axi_mst_sg_IF.b_valid  = s_axi_sg_bvalid        ; /* SG output */
         assign s_axi_sg_bready        = axi_mst_sg_IF.b_ready  ; /* SG  input */

         assign axi_mst_sg_IF.r_resp   = s_axi_sg_rresp         ; /* SG output */
         assign axi_mst_sg_IF.r_valid  = s_axi_sg_rvalid        ; /* SG output */
         assign axi_mst_sg_IF.r_data   = s_axi_sg_rdata         ; /* SG output */
         assign s_axi_sg_rready        = axi_mst_sg_IF.r_ready  ; /* SG  input */

         assign s_axi_sg_wdata         = axi_mst_sg_IF.w_data   ; /* SG  input */
         assign s_axi_sg_wstrb         = axi_mst_sg_IF.w_strb   ; /* SG  input */
         assign s_axi_sg_wvalid        = axi_mst_sg_IF.w_valid  ; /* SG  input */
         assign axi_mst_sg_IF.w_ready  = s_axi_sg_wready        ; /* SG output */
      end
   endgenerate

   // CDC for signal generator
   axis_cdcsync_v1 #(
      .N                         (1),     // Number of inputs/outputs.
      .B                         (168),   // Number of data bits.
      // ++++++++++++ ADD EMULATOR PARAMETER
      .EMULATOR                  (EMULATOR)
      // ++++++++++++
   )
   u_axis_sgcdcsync_v1 (
      // S_AXIS for input data.
      .s_axis_aresetn            (t_resetn),
      .s_axis_aclk               (t_clk),
      .s0_axis_tready            (tproc_sgcdc_0_axis_tready),
      .s0_axis_tvalid            (tproc_sgcdc_0_axis_tvalid),
      .s0_axis_tdata             (tproc_sgcdc_0_axis_tdata),
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
      .m_axis_aresetn            (sg_resetn),
      .m_axis_aclk               (sg_clk),
      .m0_axis_tready            (sgcdc_sgt_0_axis_tready),
      .m0_axis_tvalid            (sgcdc_sgt_0_axis_tvalid),
      .m0_axis_tdata             (sgcdc_sgt_0_axis_tdata),
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

   axis_signal_gen_v6 #(
      .N                   (N                ),
      .N_DDS               (N_DDS_SG         ),
      .GEN_DDS             ("TRUE"           ),
      .ENVELOPE_TYPE       ("COMPLEX"        ),
      // +++++++++++++ ADD EMULATOR PARAM
      .EMULATOR            (EMULATOR        )
      // +++++++++++++
   )
   u_axis_signal_gen_v6_0 ( 
      // AXI Slave I/F for configuration.
      .s_axi_aclk          (ps_clk    ),
      .s_axi_aresetn       (ps_resetn   ),
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
      .s0_axis_aclk        (sg_s0_axis_aclk        ),
      .s0_axis_aresetn     (sg_s0_axis_aresetn     ),
      .s0_axis_tdata       (sg_s0_axis_tdata       ),
      .s0_axis_tvalid      (sg_s0_axis_tvalid      ),
      .s0_axis_tready      (sg_s0_axis_tready      ),

      // s1_* and m_* reset/clock.
      .aresetn             (sg_resetn              ),
      .aclk                (sg_clk                 ),

      // AXIS Slave to queue waveforms - From TPROC
      .s1_axis_tdata       (sgt_sg_0_axis_tdata    ),
      .s1_axis_tvalid      (sgt_sg_0_axis_tvalid   ),
      .s1_axis_tready      (sgt_sg_0_axis_tready   ),

      // AXIS Master for output data.
      .m_axis_tready       (axis_sg_dac_tready     ),
      .m_axis_tvalid       (axis_sg_dac_tvalid     ),
      .m_axis_tdata        (axis_sg_dac_tdata      )
   );


   // For Waveform Debug
   logic signed [15:0] axis_sg_dac_tdata_dbg [0:N_DDS_SG-1];
   always @* begin
      for (int i=0; i<N_DDS_SG; i=i+1) begin
         axis_sg_dac_tdata_dbg[i] = axis_sg_dac_tdata[16*i +: 16];
      end
   end


   // For Waveform Debug
   logic signed [15:0] axis_adc_ro_tdata_dbg [0:N_DDS_RO-1];
   always @* begin
      for (int i=0; i < N_DDS_RO; i=i+1) begin
         axis_adc_ro_tdata_dbg[i] = axis_adc_ro_tdata[16*i +: 16];
      end
   end


   // Readout Components
   // CDC for readout
   axis_cdcsync_v1 #(
      .N                         (1),     // Number of inputs/outputs.
      .B                         (168),   // Number of data bits.
      // ++++++++++++ ADD EMULATOR PARAMETER
      .EMULATOR                  (EMULATOR)
      // ++++++++++++
   )
   u_axis_cdcsync_v1 (
      // S_AXIS for input data.
      .s_axis_aresetn            (t_resetn),
      .s_axis_aclk               (t_clk),
      .s0_axis_tready            (tproc_rocdc_0_axis_tready),
      .s0_axis_tvalid            (tproc_rocdc_0_axis_tvalid),
      .s0_axis_tdata             (tproc_rocdc_0_axis_tdata),
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
      .m0_axis_tready            (rocdc_rot_0_axis_tready),
      .m0_axis_tvalid            (rocdc_rot_0_axis_tvalid),
      .m0_axis_tdata             (rocdc_rot_0_axis_tdata),
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


   // // Raw readout m1 outputs — padded below to compensate for missing pipeline
   // // latency (Xilinx RFDC + DDS_compiler + FIR_compiler) vs. our behavioral chain.
   // wire              axis_ro_avg_raw_tready;
   // wire              axis_ro_avg_raw_tvalid;
   // wire [31:0]       axis_ro_avg_raw_tdata;

   axis_dyn_readout_v1 #(
      // .N_DDS            (N_DDS_RO)
      // +++++++++++++ ADD EMULATOR PARAM
      .EMULATOR            (EMULATOR        )
      // +++++++++++++
   )
   u_axis_dyn_readout_v1_0 (
      // Reset and clock.
      .aresetn          (ro_resetn),
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


   // -----------------------------------------------------------------------------
   // Pipeline-latency padding for readout m1 path.
   //
   // The reference Xilinx implementation (RFDC + DDS_compiler + FIR_compiler) has
   // ~178 dec-rate samples more latency than our behavioral DAC/ADC + DDS + FIR
   // chain. Without padding, decimated I/Q samples arrive ~1.78 µs earlier than
   // the avg_buffer trigger expects, causing the leading edge of the first pulse
   // to be cut off in the captured dec_out.csv.
   //
   // We pad with a ro_clk shift register on the {tvalid, tdata} bus so the
   // avg_buffer sees samples at the "Xilinx-equivalent" arrival time. tready is
   // passed through directly (the raw readout output is always-ready in practice).
   // -----------------------------------------------------------------------------
   // localparam int RO_LATENCY_PAD = 30;
   // logic [32:0]     ro_pad_pipe [RO_LATENCY_PAD];
   // always_ff @(posedge ro_clk) begin
   //    if (!ro_resetn) begin
   //       for (int i = 0; i < RO_LATENCY_PAD; i++) ro_pad_pipe[i] <= '0;
   //    end
   //    else begin
   //       ro_pad_pipe[0] <= {axis_ro_avg_raw_tvalid, axis_ro_avg_raw_tdata};
   //       for (int i = 1; i < RO_LATENCY_PAD; i++)
   //          ro_pad_pipe[i] <= ro_pad_pipe[i-1];
   //    end
   // end
   // assign axis_ro_avg_tvalid     = ro_pad_pipe[RO_LATENCY_PAD-1][32];
   // assign axis_ro_avg_tdata      = ro_pad_pipe[RO_LATENCY_PAD-1][31:0];
   // assign axis_ro_avg_raw_tready = axis_ro_avg_tready;


   // For Waveform Debug
   logic signed [15:0] axis_ro_avg_tdata_dbg [0:1];
   logic signed [15:0] axis_ro_mrbuf_tdata_dbg [0:7][0:1];
   always @* begin
      for (int i=0; i<2; i=i+1) begin
         axis_ro_avg_tdata_dbg[i] = axis_ro_avg_tdata[16*i +: 16];
      end
      for (int i=0; i<N_DDS_RO; i=i+1) begin
         for (int j=0; j<2; j=j+1) begin
            axis_ro_mrbuf_tdata_dbg[i][j] = axis_ro_mrbuf_tdata[16*(2*i+j) +: 16];
         end
      end
   end

   // For Waveform Debug
   logic signed [32:0] m1_ro_avg_abs_dbg;
   assign m1_ro_avg_abs_dbg = $signed(axis_ro_avg_tdata[15:0])*$signed(axis_ro_avg_tdata[15:0]) + 
                                 $signed(axis_ro_avg_tdata[31:16])*$signed(axis_ro_avg_tdata[31:16]);


   // AXI VIP master address.
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

// <<<<<<<<<<<< XILINX AXI VIP
   // xil_axi_ulong   AVG_START_REG       = 4 * 0;
   // xil_axi_ulong   AVG_ADDR_REG        = 4 * 1;
   // xil_axi_ulong   AVG_LEN_REG         = 4 * 2;
   // xil_axi_ulong   AVG_DR_START_REG    = 4 * 3;
   // xil_axi_ulong   AVG_DR_ADDR_REG     = 4 * 4;
   // xil_axi_ulong   AVG_DR_LEN_REG      = 4 * 5;
   // xil_axi_ulong   BUF_START_REG       = 4 * 6;
   // xil_axi_ulong   BUF_ADDR_REG        = 4 * 7;
   // xil_axi_ulong   BUF_LEN_REG         = 4 * 8;
   // xil_axi_ulong   BUF_DR_START_REG    = 4 * 9;
   // xil_axi_ulong   BUF_DR_ADDR_REG     = 4 * 10;
   // xil_axi_ulong   BUF_DR_LEN_REG      = 4 * 11;
// ============
   // logic [5:0] AVG_START_REG       = 4 * 0;
   // logic [5:0] AVG_ADDR_REG        = 4 * 1;
   // logic [5:0] AVG_LEN_REG         = 4 * 2;
   // logic [5:0] AVG_DR_START_REG    = 4 * 3;
   // logic [5:0] AVG_DR_ADDR_REG     = 4 * 4;
   // logic [5:0] AVG_DR_LEN_REG      = 4 * 5;
   // logic [5:0] BUF_START_REG       = 4 * 6;
   // logic [5:0] BUF_ADDR_REG        = 4 * 7;
   // logic [5:0] BUF_LEN_REG         = 4 * 8;
   // logic [5:0] BUF_DR_START_REG    = 4 * 9;
   // logic [5:0] BUF_DR_ADDR_REG     = 4 * 10;
   // logic [5:0] BUF_DR_LEN_REG      = 4 * 11;
// >>>>>>>>>>>> PULP PLATFORM AXI VIP

   generate
      if (EMULATOR == 0) begin: gen_axi_avg_vip
         // <<<<<<<<<<<< XILINX AXI VIP
         axi_mst_0 u_axi_mst_avg_0 (
            .aresetn       (ps_resetn           ),
            .aclk          (ps_clk              ),
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
      end
      else begin: gen_axi_avg_emu
         // PULP PLATFORM AXI VIP
         AXI_LITE #(
            .AXI_ADDR_WIDTH ( 6      ),
            .AXI_DATA_WIDTH ( 32     )
         ) axi_mst_avg_IF ();
         AXI_LITE_DV #(
            .AXI_ADDR_WIDTH ( 6       ),
            .AXI_DATA_WIDTH ( 32      )
         ) axi_mst_avg_dv_IF (ps_clk);
         `ifdef VERILATOR
         `AXI_LITE_ASSIGN(axi_mst_avg_IF, axi_mst_avg_dv_IF)
         `endif
         assign s_axi_avg_araddr        = axi_mst_avg_IF.ar_addr  ; /* AVG  input */
         assign s_axi_avg_arprot        = axi_mst_avg_IF.ar_prot  ; /* AVG  input */
         assign s_axi_avg_arvalid       = axi_mst_avg_IF.ar_valid ; /* AVG  input */
         assign axi_mst_avg_IF.ar_ready = s_axi_avg_arready       ; /* AVG output */

         assign s_axi_avg_awaddr        = axi_mst_avg_IF.aw_addr  ; /* AVG  input */
         assign s_axi_avg_awprot        = axi_mst_avg_IF.aw_prot  ; /* AVG  input */
         assign s_axi_avg_awvalid       = axi_mst_avg_IF.aw_valid ; /* AVG  input */
         assign axi_mst_avg_IF.aw_ready = s_axi_avg_awready       ; /* AVG output */

         assign axi_mst_avg_IF.b_resp   = s_axi_avg_bresp         ; /* AVG output */
         assign axi_mst_avg_IF.b_valid  = s_axi_avg_bvalid        ; /* AVG output */
         assign s_axi_avg_bready        = axi_mst_avg_IF.b_ready  ; /* AVG  input */

         assign axi_mst_avg_IF.r_resp   = s_axi_avg_rresp         ; /* AVG output */
         assign axi_mst_avg_IF.r_valid  = s_axi_avg_rvalid        ; /* AVG output */
         assign axi_mst_avg_IF.r_data   = s_axi_avg_rdata         ; /* AVG output */
         assign s_axi_avg_rready        = axi_mst_avg_IF.r_ready  ; /* AVG  input */

         assign s_axi_avg_wdata         = axi_mst_avg_IF.w_data   ; /* AVG  input */
         assign s_axi_avg_wstrb         = axi_mst_avg_IF.w_strb   ; /* AVG  input */
         assign s_axi_avg_wvalid        = axi_mst_avg_IF.w_valid  ; /* AVG  input */
         assign axi_mst_avg_IF.w_ready  = s_axi_avg_wready        ; /* AVG output */
      end
   endgenerate

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
      .trigger                (trig_0_o           ),

      // AXIS Slave for input data.
      .s_axis_aresetn         (ro_resetn             ),
      .s_axis_aclk            (ro_clk                ),
      .s_axis_tready          (axis_ro_avg_tready    ),
      .s_axis_tvalid          (axis_ro_avg_tvalid    ),
      .s_axis_tdata           (axis_ro_avg_tdata     ),

      // Reset and clock for m0 and m1.
      .m_axis_aclk            (ps_clk         ),
      .m_axis_aresetn         (ps_resetn      ),

      // AXIS Master for averaged output.
      .m0_axis_tready         (m0_axis_buf_avg_tready),
      .m0_axis_tvalid         (m0_axis_buf_avg_tvalid),
      .m0_axis_tdata          (m0_axis_buf_avg_tdata ),
      .m0_axis_tlast          (m0_axis_buf_avg_tlast ),

      // AXIS Master for decimated output.
      .m1_axis_tready         (m1_axis_buf_dec_tready),
      .m1_axis_tvalid         (m1_axis_buf_dec_tvalid),
      .m1_axis_tdata          (m1_axis_buf_dec_tdata ),
      .m1_axis_tlast          (m1_axis_buf_dec_tlast ),

      // AXIS Master for register output.
      .m2_axis_tready         (m2_axis_buf_reg_tready),
      .m2_axis_tvalid         (m2_axis_buf_reg_tvalid),
      .m2_axis_tdata          (m2_axis_buf_reg_tdata )
   );

   logic [64:0] buf_avg_abs_dbg;
   always @(posedge ps_clk) begin
      if (m0_axis_buf_avg_tvalid) begin
         buf_avg_abs_dbg = $signed(m0_axis_buf_avg_tdata[31:0]) * $signed(m0_axis_buf_avg_tdata[31:0]) + 
                              $signed(m0_axis_buf_avg_tdata[63:32]) * $signed(m0_axis_buf_avg_tdata[63:32]);
      end
   end

   logic [32:0] buf_dec_abs_dbg;
   always @(posedge ps_clk) begin
      if (m1_axis_buf_dec_tvalid) begin
         buf_dec_abs_dbg = $signed(m1_axis_buf_dec_tdata[15:0]) * $signed(m1_axis_buf_dec_tdata[15:0]) + 
                              $signed(m1_axis_buf_dec_tdata[31:16]) * $signed(m1_axis_buf_dec_tdata[31:16]);
      end
   end

   // Diagnostic: monitor readout config path.
   always @(posedge t_clk) begin
      if (tproc_rocdc_0_axis_tvalid && tproc_rocdc_0_axis_tready)
         $display("### %0t - TPROC m4_axis -> rocdc: tdata=%h ###", $realtime, tproc_rocdc_0_axis_tdata);
   end
   always @(posedge ro_clk) begin
      if (rot_ro_0_axis_tvalid && rot_ro_0_axis_tready)
         $display("### %0t - sg_translator -> readout s0_axis: tdata=%h ###", $realtime, rot_ro_0_axis_tdata);
   end

endmodule
