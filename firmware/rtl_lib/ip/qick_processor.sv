///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : qick_processor
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    qick_processor.sv
//!
//! @brief   Packaged-IP top level for the QICK tProcessor v2
//!          (qick_processor): flattens its unpacked-array AXI-Stream/
//!          trigger/data-port interfaces into fixed, individually-named
//!          pins (s0..s15_axis, m0..m15_axis, trig_0..31_o, port_0..3_dt_o,
//!          qnet/qcom/qp1/qp2 dt1/dt2 pairs) so Vivado's IP packager can
//!          infer bus interfaces from them, and wraps the raw AXI4-Lite
//!          pins in an `axi4_lite_if` for qick_processor.
//!
//! @details
//!
//!
//! Only the first `IN_PORT_QTY`/`OUT_TRIG_QTY`/`OUT_DPORT_QTY`/
//! `OUT_WPORT_QTY` fixed pins are actually wired to qick_processor; the
//! rest are tied off (unused trigger/data-out pins -> 0, unused AXIS
//! output pins -> 0/not-valid, unused AXIS input pins' tready -> 1).
//!
//! `proc_start_i`/`proc_stop_i` are synchronized into the c_clk_i domain
//! and edge-detected into one-shot pulses before reaching qick_processor
//! (mirrors qproc_ctrl's own `PS_TPROC_CTRL` pulse-from-level handling).
//!
//! Ported from firmware/ip/qick_processor/src/qick_processor.sv
//! (pinout and tie-offs unchanged). The legacy `TYPE_IF_AXI_REG` interface
//! -> `axi4_lite_if` (matching qick_processor/qproc_axi_reg); the
//! proc_start/stop synchronizer's first two stages -> `cdc_reg_sync`
//! (the third stage stays a plain register -- it is not part of the CDC,
//! only of the edge detector, per the same pattern qproc_ctrl.sv uses for
//! `PS_TPROC_CTRL`). Dropped 3 parameters that were declared but never
//! referenced anywhere in the legacy file's body OR by the production
//! driver (`TIME_CTRL`, `CORE_CTRL`, `OUT_TIME`). `QNET`/`QCOM`/
//! `CUSTOM_PERIPH`/`IO_CTRL`/`CALL_DEPTH` are ALSO inert in this RTL but
//! were kept: `Axis_QICK_Proc` (qick_lib/qick/drivers/tproc.py)
//! introspects them via Vivado's IP parameter metadata (`CALL_DEPTH`
//! unconditionally -- dropping it would KeyError at driver load time).
//!
//! @author  QICK Development Team
//!
//! @version 1.0

module qick_processor #(
    parameter int DUAL_CORE     = 0, // 0=single core, 1=dual core
    parameter int GEN_SYNC      = 0, // Generate the pulse_sync_o output
    parameter int DEBUG         = 1, // 0=no debug, 1=AXI ctrl, 2=+registers, 3=+out signals
    parameter int QNET          = 0, // Inert in RTL; read by the driver's metadata introspection
    parameter int QCOM          = 0, // Inert in RTL; read by the driver's metadata introspection
    parameter int CUSTOM_PERIPH = 0, // Inert in RTL; read by the driver's metadata introspection
    parameter int LFSR          = 1,
    parameter int DIVIDER       = 0,
    parameter int ARITH         = 0,
    parameter int EXT_FLAG      = 0, // External flag input: 0=no, 1=yes
    parameter int IO_CTRL       = 0, // Inert in RTL; read by the driver's metadata introspection
    parameter int TIME_READ     = 1,
    parameter int FIFO_DEPTH    = 9,
    parameter int PMEM_AW       = 8,
    parameter int DMEM_AW       = 8,
    parameter int WMEM_AW       = 8,
    parameter int REG_AW        = 4,
    parameter int IN_PORT_QTY   = 1,
    parameter int OUT_TRIG_QTY  = 2,
    parameter int OUT_DPORT_QTY = 1,
    parameter int OUT_DPORT_DW  = 4,
    parameter int OUT_WPORT_QTY = 1,
    parameter int CALL_DEPTH    = 255 // Inert in RTL (stack depth is fixed at 8 in qcore_cpu's
                                       // tpv2_stack instance); required by the driver's metadata
                                       // introspection (unconditional description['parameters'] read)
) (
    // Core, time and AXI clk & rst
    input  logic t_clk_i,
    input  logic t_resetn,
    input  logic c_clk_i,
    input  logic c_resetn,
    input  logic ps_clk_i,
    input  logic ps_resetn,
    // External control
    input  logic         ext_flag_i,
    input  logic         proc_start_i,
    input  logic         proc_stop_i,
    input  logic         core_start_i,
    input  logic         core_stop_i,
    input  logic         time_rst_i,
    input  logic         time_init_i,
    input  logic         time_updt_i,
    input  logic [31:0]  time_dt_i,
    output logic [47:0]  t_time_abs_o,
    output logic         pulse_sync_o,
    // Qnet
    output logic         qnet_en_o,
    output logic [4:0]   qnet_op_o,
    output logic [31:0]  qnet_a_dt_o,
    output logic [31:0]  qnet_b_dt_o,
    output logic [31:0]  qnet_c_dt_o,
    input  logic         qnet_rdy_i,
    input  logic [31:0]  qnet_dt1_i,
    input  logic [31:0]  qnet_dt2_i,
    input  logic         qnet_vld_i,
    input  logic         qnet_flag_i,
    // Qcom
    output logic         qcom_en_o,
    output logic [4:0]   qcom_op_o,
    output logic [31:0]  qcom_dt_o,
    input  logic         qcom_rdy_i,
    input  logic [31:0]  qcom_dt1_i,
    input  logic [31:0]  qcom_dt2_i,
    input  logic         qcom_vld_i,
    input  logic         qcom_flag_i,
    // Qp1
    output logic         qp1_en_o,
    output logic [4:0]   qp1_op_o,
    output logic [31:0]  qp1_a_dt_o,
    output logic [31:0]  qp1_b_dt_o,
    output logic [31:0]  qp1_c_dt_o,
    output logic [31:0]  qp1_d_dt_o,
    input  logic         qp1_rdy_i,
    input  logic [31:0]  qp1_dt1_i,
    input  logic [31:0]  qp1_dt2_i,
    input  logic         qp1_vld_i,
    input  logic         qp1_flag_i,
    // Qp2
    output logic         qp2_en_o,
    output logic [4:0]   qp2_op_o,
    output logic [31:0]  qp2_a_dt_o,
    output logic [31:0]  qp2_b_dt_o,
    output logic [31:0]  qp2_c_dt_o,
    output logic [31:0]  qp2_d_dt_o,
    input  logic         qp2_rdy_i,
    input  logic [31:0]  qp2_dt1_i,
    input  logic [31:0]  qp2_dt2_i,
    input  logic         qp2_vld_i,
    input  logic         qp2_flag_i,

    // DMA AXIS for read and write memory
    input  logic [255:0] s_dma_axis_tdata_i,
    input  logic         s_dma_axis_tlast_i,
    input  logic         s_dma_axis_tvalid_i,
    output logic         s_dma_axis_tready_o,
    output logic [255:0] m_dma_axis_tdata_o,
    output logic         m_dma_axis_tlast_o,
    output logic         m_dma_axis_tvalid_o,
    input  logic         m_dma_axis_tready_i,

    // AXI-Lite data slave I/F
    input  logic [7:0]  s_axi_awaddr,
    input  logic [2:0]  s_axi_awprot,
    input  logic        s_axi_awvalid,
    output logic        s_axi_awready,
    input  logic [31:0] s_axi_wdata,
    input  logic [3:0]  s_axi_wstrb,
    input  logic        s_axi_wvalid,
    output logic        s_axi_wready,
    output logic [1:0]  s_axi_bresp,
    output logic        s_axi_bvalid,
    input  logic        s_axi_bready,
    input  logic [7:0]  s_axi_araddr,
    input  logic [2:0]  s_axi_arprot,
    input  logic        s_axi_arvalid,
    output logic        s_axi_arready,
    output logic [31:0] s_axi_rdata,
    output logic [1:0]  s_axi_rresp,
    output logic        s_axi_rvalid,
    input  logic        s_axi_rready,

    /// Data port input
    input  logic [63:0] s0_axis_tdata,  input logic s0_axis_tvalid,  output logic s0_axis_tready,
    input  logic [63:0] s1_axis_tdata,  input logic s1_axis_tvalid,  output logic s1_axis_tready,
    input  logic [63:0] s2_axis_tdata,  input logic s2_axis_tvalid,  output logic s2_axis_tready,
    input  logic [63:0] s3_axis_tdata,  input logic s3_axis_tvalid,  output logic s3_axis_tready,
    input  logic [63:0] s4_axis_tdata,  input logic s4_axis_tvalid,  output logic s4_axis_tready,
    input  logic [63:0] s5_axis_tdata,  input logic s5_axis_tvalid,  output logic s5_axis_tready,
    input  logic [63:0] s6_axis_tdata,  input logic s6_axis_tvalid,  output logic s6_axis_tready,
    input  logic [63:0] s7_axis_tdata,  input logic s7_axis_tvalid,  output logic s7_axis_tready,
    input  logic [63:0] s8_axis_tdata,  input logic s8_axis_tvalid,  output logic s8_axis_tready,
    input  logic [63:0] s9_axis_tdata,  input logic s9_axis_tvalid,  output logic s9_axis_tready,
    input  logic [63:0] s10_axis_tdata, input logic s10_axis_tvalid, output logic s10_axis_tready,
    input  logic [63:0] s11_axis_tdata, input logic s11_axis_tvalid, output logic s11_axis_tready,
    input  logic [63:0] s12_axis_tdata, input logic s12_axis_tvalid, output logic s12_axis_tready,
    input  logic [63:0] s13_axis_tdata, input logic s13_axis_tvalid, output logic s13_axis_tready,
    input  logic [63:0] s14_axis_tdata, input logic s14_axis_tvalid, output logic s14_axis_tready,
    input  logic [63:0] s15_axis_tdata, input logic s15_axis_tvalid, output logic s15_axis_tready,

    // Out wave ports
    output logic [167:0] m0_axis_tdata,  output logic m0_axis_tvalid,  input logic m0_axis_tready,
    output logic [167:0] m1_axis_tdata,  output logic m1_axis_tvalid,  input logic m1_axis_tready,
    output logic [167:0] m2_axis_tdata,  output logic m2_axis_tvalid,  input logic m2_axis_tready,
    output logic [167:0] m3_axis_tdata,  output logic m3_axis_tvalid,  input logic m3_axis_tready,
    output logic [167:0] m4_axis_tdata,  output logic m4_axis_tvalid,  input logic m4_axis_tready,
    output logic [167:0] m5_axis_tdata,  output logic m5_axis_tvalid,  input logic m5_axis_tready,
    output logic [167:0] m6_axis_tdata,  output logic m6_axis_tvalid,  input logic m6_axis_tready,
    output logic [167:0] m7_axis_tdata,  output logic m7_axis_tvalid,  input logic m7_axis_tready,
    output logic [167:0] m8_axis_tdata,  output logic m8_axis_tvalid,  input logic m8_axis_tready,
    output logic [167:0] m9_axis_tdata,  output logic m9_axis_tvalid,  input logic m9_axis_tready,
    output logic [167:0] m10_axis_tdata, output logic m10_axis_tvalid, input logic m10_axis_tready,
    output logic [167:0] m11_axis_tdata, output logic m11_axis_tvalid, input logic m11_axis_tready,
    output logic [167:0] m12_axis_tdata, output logic m12_axis_tvalid, input logic m12_axis_tready,
    output logic [167:0] m13_axis_tdata, output logic m13_axis_tvalid, input logic m13_axis_tready,
    output logic [167:0] m14_axis_tdata, output logic m14_axis_tvalid, input logic m14_axis_tready,
    output logic [167:0] m15_axis_tdata, output logic m15_axis_tvalid, input logic m15_axis_tready,

    ///// Triggers
    output logic trig_0_o,  output logic trig_1_o,  output logic trig_2_o,  output logic trig_3_o,
    output logic trig_4_o,  output logic trig_5_o,  output logic trig_6_o,  output logic trig_7_o,
    output logic trig_8_o,  output logic trig_9_o,  output logic trig_10_o, output logic trig_11_o,
    output logic trig_12_o, output logic trig_13_o, output logic trig_14_o, output logic trig_15_o,
    output logic trig_16_o, output logic trig_17_o, output logic trig_18_o, output logic trig_19_o,
    output logic trig_20_o, output logic trig_21_o, output logic trig_22_o, output logic trig_23_o,
    output logic trig_24_o, output logic trig_25_o, output logic trig_26_o, output logic trig_27_o,
    output logic trig_28_o, output logic trig_29_o, output logic trig_30_o, output logic trig_31_o,
    // Out data ports
    output logic [OUT_DPORT_DW-1:0] port_0_dt_o,
    output logic [OUT_DPORT_DW-1:0] port_1_dt_o,
    output logic [OUT_DPORT_DW-1:0] port_2_dt_o,
    output logic [OUT_DPORT_DW-1:0] port_3_dt_o,
    // Debug signals
    output logic [31:0] ps_debug_do,
    output logic [31:0] t_debug_do,
    output logic [31:0] t_fifo_do,
    output logic [31:0] c_time_usr_do,
    output logic [31:0] c_debug_do,
    output logic [31:0] c_time_ref_do,
    output logic [31:0] c_proc_do,
    output logic [31:0] c_port_do,
    output logic [31:0] c_core_do
);

    // Data-in interface
    logic        port_tvalid_si [16];
    logic [63:0] port_tdata_si  [16];

    // Trigger interface
    logic port_trig_so [32];

    // Data-out interface
    logic [OUT_DPORT_DW-1:0] port_tdata_so  [4];
    logic                     port_tvalid_so [4];

    logic [167:0] m_axis_tdata_s  [16];
    logic         m_axis_tvalid_s [16];
    logic         m_axis_tready_s [16];

    logic [31:0] periph_a_dt, periph_b_dt, periph_c_dt, periph_d_dt;
    logic [4:0]  periph_op;

    ///// AXI-Lite port /////
    ///////////////////////////////////////////////////////////////////////////////
    axi4_lite_if #(
        .DATA_WIDTH (32),
        .ADDR_WIDTH (8)
    ) s_axi_if (
        .aclk    (ps_clk_i),
        .aresetn (ps_resetn)
    );
    assign s_axi_if.awaddr  = s_axi_awaddr;
    assign s_axi_if.awprot  = s_axi_awprot;
    assign s_axi_if.awvalid = s_axi_awvalid;
    assign s_axi_if.wdata   = s_axi_wdata;
    assign s_axi_if.wstrb   = s_axi_wstrb;
    assign s_axi_if.wvalid  = s_axi_wvalid;
    assign s_axi_if.bready  = s_axi_bready;
    assign s_axi_if.araddr  = s_axi_araddr;
    assign s_axi_if.arprot  = s_axi_arprot;
    assign s_axi_if.arvalid = s_axi_arvalid;
    assign s_axi_if.rready  = s_axi_rready;
    assign s_axi_awready = s_axi_if.awready;
    assign s_axi_wready  = s_axi_if.wready;
    assign s_axi_bresp   = s_axi_if.bresp;
    assign s_axi_bvalid  = s_axi_if.bvalid;
    assign s_axi_arready = s_axi_if.arready;
    assign s_axi_rdata   = s_axi_if.rdata;
    assign s_axi_rresp   = s_axi_if.rresp;
    assign s_axi_rvalid  = s_axi_if.rvalid;


    ///// Data in ports /////
    ///////////////////////////////////////////////////////////////////////////////
    always_comb begin
        port_tdata_si[0]  = s0_axis_tdata;
        port_tdata_si[1]  = s1_axis_tdata;
        port_tdata_si[2]  = s2_axis_tdata;
        port_tdata_si[3]  = s3_axis_tdata;
        port_tdata_si[4]  = s4_axis_tdata;
        port_tdata_si[5]  = s5_axis_tdata;
        port_tdata_si[6]  = s6_axis_tdata;
        port_tdata_si[7]  = s7_axis_tdata;
        port_tdata_si[8]  = s8_axis_tdata;
        port_tdata_si[9]  = s9_axis_tdata;
        port_tdata_si[10] = s10_axis_tdata;
        port_tdata_si[11] = s11_axis_tdata;
        port_tdata_si[12] = s12_axis_tdata;
        port_tdata_si[13] = s13_axis_tdata;
        port_tdata_si[14] = s14_axis_tdata;
        port_tdata_si[15] = s15_axis_tdata;
        port_tvalid_si[0]  = s0_axis_tvalid;
        port_tvalid_si[1]  = s1_axis_tvalid;
        port_tvalid_si[2]  = s2_axis_tvalid;
        port_tvalid_si[3]  = s3_axis_tvalid;
        port_tvalid_si[4]  = s4_axis_tvalid;
        port_tvalid_si[5]  = s5_axis_tvalid;
        port_tvalid_si[6]  = s6_axis_tvalid;
        port_tvalid_si[7]  = s7_axis_tvalid;
        port_tvalid_si[8]  = s8_axis_tvalid;
        port_tvalid_si[9]  = s9_axis_tvalid;
        port_tvalid_si[10] = s10_axis_tvalid;
        port_tvalid_si[11] = s11_axis_tvalid;
        port_tvalid_si[12] = s12_axis_tvalid;
        port_tvalid_si[13] = s13_axis_tvalid;
        port_tvalid_si[14] = s14_axis_tvalid;
        port_tvalid_si[15] = s15_axis_tvalid;
    end


    // proc_start_i/proc_stop_i: synchronize into c_clk_i (cdc_reg_sync),
    // then edge-detect into a one-shot pulse (one extra register beyond the
    // synchronizer -- same pattern as qproc_ctrl.sv's PS_TPROC_CTRL).
    logic proc_start_sync, proc_stop_sync;
    logic proc_start_r2, proc_stop_r2;

    cdc_reg_sync #(.DW (1)) cdc_proc_start_i (
        .clk_i  (c_clk_i),
        .rst_ni (c_resetn),
        .dt_i   (proc_start_i),
        .dt_o   (proc_start_sync)
    );
    cdc_reg_sync #(.DW (1)) cdc_proc_stop_i (
        .clk_i  (c_clk_i),
        .rst_ni (c_resetn),
        .dt_i   (proc_stop_i),
        .dt_o   (proc_stop_sync)
    );

    always_ff @(posedge c_clk_i) begin
        if (!c_resetn) begin
            proc_start_r2 <= 0;
            proc_stop_r2  <= 0;
        end else begin
            proc_start_r2 <= proc_start_sync;
            proc_stop_r2  <= proc_stop_sync;
        end
    end

    // proc_start_t01/proc_stop_t01 are only asserted for ONE c_clk_i cycle.
    logic proc_start_t01, proc_stop_t01;
    assign proc_start_t01 = proc_start_sync & ~proc_start_r2;
    assign proc_stop_t01  = proc_stop_sync  & ~proc_stop_r2;


    tprocv2 #(
        .DEBUG         (DEBUG),
        .DUAL_CORE     (DUAL_CORE),
        .LFSR          (LFSR),
        .DIVIDER       (DIVIDER),
        .ARITH         (ARITH),
        .TIME_READ     (TIME_READ),
        .FIFO_DEPTH    (FIFO_DEPTH),
        .PMEM_AW       (PMEM_AW),
        .DMEM_AW       (DMEM_AW),
        .WMEM_AW       (WMEM_AW),
        .REG_AW        (REG_AW),
        .IN_PORT_QTY   (IN_PORT_QTY),
        .OUT_TRIG_QTY  (OUT_TRIG_QTY),
        .OUT_DPORT_QTY (OUT_DPORT_QTY),
        .OUT_DPORT_DW  (OUT_DPORT_DW),
        .OUT_WPORT_QTY (OUT_WPORT_QTY)
    ) qproc_i (
        .t_clk_i   (t_clk_i),
        .t_rst_ni  (t_resetn),
        .c_clk_i   (c_clk_i),
        .c_rst_ni  (c_resetn),
        .ps_clk_i  (ps_clk_i),
        .ps_rst_ni (ps_resetn),
        // Ctrl
        .ext_flag_i     (ext_flag_i),
        .proc_start_i   (proc_start_t01),
        .proc_stop_i    (proc_stop_t01),
        .core_start_i   (core_start_i),
        .core_stop_i    (core_stop_i),
        .time_rst_i     (time_rst_i),
        .time_init_i    (time_init_i),
        .time_updt_i    (time_updt_i),
        .time_updt_dt_i (time_dt_i),
        .time_abs_o     (t_time_abs_o),
        // Peripherals
        .periph_a_dt_o (periph_a_dt),
        .periph_b_dt_o (periph_b_dt),
        .periph_c_dt_o (periph_c_dt),
        .periph_d_dt_o (periph_d_dt),
        .periph_op_o   (periph_op),
        .qnet_en_o  (qnet_en_o),
        .qnet_rdy_i (qnet_rdy_i),
        .qnet_dt_i  ({qnet_dt1_i, qnet_dt2_i}),
        .qnet_vld_i (qnet_vld_i),
        .qnet_flag_i (qnet_flag_i),
        .qcom_en_o  (qcom_en_o),
        .qcom_rdy_i (qcom_rdy_i),
        .qcom_dt_i  ({qcom_dt1_i, qcom_dt2_i}),
        .qcom_vld_i (qcom_vld_i),
        .qcom_flag_i (qcom_flag_i),
        .qp1_en_o  (qp1_en_o),
        .qp1_rdy_i (qp1_rdy_i),
        .qp1_dt_i  ({qp1_dt1_i, qp1_dt2_i}),
        .qp1_vld_i (qp1_vld_i),
        .qp1_flag_i (qp1_flag_i),
        .qp2_en_o  (qp2_en_o),
        .qp2_rdy_i (qp2_rdy_i),
        .qp2_dt_i  ({qp2_dt1_i, qp2_dt2_i}),
        .qp2_vld_i (qp2_vld_i),
        .qp2_flag_i (qp2_flag_i),
        // PS
        .s_axi (s_axi_if.slave),
        .s_dma_axis_tdata_i  (s_dma_axis_tdata_i),
        .s_dma_axis_tlast_i  (s_dma_axis_tlast_i),
        .s_dma_axis_tvalid_i (s_dma_axis_tvalid_i),
        .s_dma_axis_tready_o (s_dma_axis_tready_o),
        .m_dma_axis_tdata_o  (m_dma_axis_tdata_o),
        .m_dma_axis_tlast_o  (m_dma_axis_tlast_o),
        .m_dma_axis_tvalid_o (m_dma_axis_tvalid_o),
        .m_dma_axis_tready_i (m_dma_axis_tready_i),
        // Ports
        .port_tvalid_i (port_tvalid_si[0:IN_PORT_QTY-1]),
        .port_tdata_i  (port_tdata_si[0:IN_PORT_QTY-1]),
        .port_trig_o   (port_trig_so[0:OUT_TRIG_QTY-1]),
        .port_tvalid_o (port_tvalid_so[0:OUT_DPORT_QTY-1]),
        .port_tdata_o  (port_tdata_so[0:OUT_DPORT_QTY-1]),
        .m_axis_tdata  (m_axis_tdata_s[0:OUT_WPORT_QTY-1]),
        .m_axis_tvalid (m_axis_tvalid_s[0:OUT_WPORT_QTY-1]),
        .m_axis_tready (m_axis_tready_s[0:OUT_WPORT_QTY-1]),
        // Debug
        .dport_di      (port_tdata_so[0][3:0]),
        .ps_debug_do   (ps_debug_do),
        .c_time_usr_do (c_time_usr_do),
        .t_debug_do    (t_debug_do),
        .t_fifo_do     (t_fifo_do),
        .c_debug_do    (c_debug_do),
        .c_time_ref_do (c_time_ref_do),
        .c_proc_do     (c_proc_do),
        .c_port_do     (c_port_do),
        .c_core_do     (c_core_do)
    );



    // Output assignment
    ///////////////////////////////////////////////////////////////////////////////

    ///// Qnet_dt
    assign qnet_op_o   = periph_op;
    assign qnet_a_dt_o = periph_a_dt;
    assign qnet_b_dt_o = periph_b_dt;
    assign qnet_c_dt_o = periph_c_dt;

    ///// Qcom_dt
    assign qcom_op_o = periph_op;
    assign qcom_dt_o = periph_b_dt;

    ///// P1
    assign qp1_op_o   = periph_op;
    assign qp1_a_dt_o = periph_a_dt;
    assign qp1_b_dt_o = periph_b_dt;
    assign qp1_c_dt_o = periph_c_dt;
    assign qp1_d_dt_o = periph_d_dt;

    ///// P2
    assign qp2_op_o   = periph_op;
    assign qp2_a_dt_o = periph_a_dt;
    assign qp2_b_dt_o = periph_b_dt;
    assign qp2_c_dt_o = periph_c_dt;
    assign qp2_d_dt_o = periph_d_dt;

    ///// Trigger ports
    generate
        if (OUT_TRIG_QTY < 31)
            for (genvar ind_t = 31; ind_t >= OUT_TRIG_QTY; ind_t--) begin : gen_trigger_port_not_present
                assign port_trig_so[ind_t] = 0;
            end
    endgenerate

    ///// Triggers
    assign trig_0_o  = port_trig_so[0];
    assign trig_1_o  = port_trig_so[1];
    assign trig_2_o  = port_trig_so[2];
    assign trig_3_o  = port_trig_so[3];
    assign trig_4_o  = port_trig_so[4];
    assign trig_5_o  = port_trig_so[5];
    assign trig_6_o  = port_trig_so[6];
    assign trig_7_o  = port_trig_so[7];
    assign trig_8_o  = port_trig_so[8];
    assign trig_9_o  = port_trig_so[9];
    assign trig_10_o = port_trig_so[10];
    assign trig_11_o = port_trig_so[11];
    assign trig_12_o = port_trig_so[12];
    assign trig_13_o = port_trig_so[13];
    assign trig_14_o = port_trig_so[14];
    assign trig_15_o = port_trig_so[15];
    assign trig_16_o = port_trig_so[16];
    assign trig_17_o = port_trig_so[17];
    assign trig_18_o = port_trig_so[18];
    assign trig_19_o = port_trig_so[19];
    assign trig_20_o = port_trig_so[20];
    assign trig_21_o = port_trig_so[21];
    assign trig_22_o = port_trig_so[22];
    assign trig_23_o = port_trig_so[23];
    assign trig_24_o = port_trig_so[24];
    assign trig_25_o = port_trig_so[25];
    assign trig_26_o = port_trig_so[26];
    assign trig_27_o = port_trig_so[27];
    assign trig_28_o = port_trig_so[28];
    assign trig_29_o = port_trig_so[29];
    assign trig_30_o = port_trig_so[30];
    assign trig_31_o = port_trig_so[31];

    ///// Data out ports
    generate
        if (OUT_DPORT_QTY < 3)
            for (genvar ind_d = 3; ind_d >= OUT_DPORT_QTY; ind_d--) begin : gen_data_port_not_present
                assign port_tdata_so[ind_d]  = '{default: '0};
                assign port_tvalid_so[ind_d] = 0;
            end
    endgenerate

    assign port_0_dt_o = port_tdata_so[0];
    assign port_1_dt_o = port_tdata_so[1];
    assign port_2_dt_o = port_tdata_so[2];
    assign port_3_dt_o = port_tdata_so[3];

    ///// Wave out ports
    generate
        if (OUT_WPORT_QTY < 16)
            for (genvar ind_w = 15; ind_w >= OUT_WPORT_QTY; ind_w--) begin : gen_wave_port_not_present
                assign m_axis_tdata_s[ind_w]  = '{default: '0};
                assign m_axis_tvalid_s[ind_w] = 0;
            end
    endgenerate

    assign s0_axis_tready  = 1'b1;
    assign s1_axis_tready  = 1'b1;
    assign s2_axis_tready  = 1'b1;
    assign s3_axis_tready  = 1'b1;
    assign s4_axis_tready  = 1'b1;
    assign s5_axis_tready  = 1'b1;
    assign s6_axis_tready  = 1'b1;
    assign s7_axis_tready  = 1'b1;
    assign s8_axis_tready  = 1'b1;
    assign s9_axis_tready  = 1'b1;
    assign s10_axis_tready = 1'b1;
    assign s11_axis_tready = 1'b1;
    assign s12_axis_tready = 1'b1;
    assign s13_axis_tready = 1'b1;
    assign s14_axis_tready = 1'b1;
    assign s15_axis_tready = 1'b1;

    assign m_axis_tready_s[0]  = m0_axis_tready;
    assign m_axis_tready_s[1]  = m1_axis_tready;
    assign m_axis_tready_s[2]  = m2_axis_tready;
    assign m_axis_tready_s[3]  = m3_axis_tready;
    assign m_axis_tready_s[4]  = m4_axis_tready;
    assign m_axis_tready_s[5]  = m5_axis_tready;
    assign m_axis_tready_s[6]  = m6_axis_tready;
    assign m_axis_tready_s[7]  = m7_axis_tready;
    assign m_axis_tready_s[8]  = m8_axis_tready;
    assign m_axis_tready_s[9]  = m9_axis_tready;
    assign m_axis_tready_s[10] = m10_axis_tready;
    assign m_axis_tready_s[11] = m11_axis_tready;
    assign m_axis_tready_s[12] = m12_axis_tready;
    assign m_axis_tready_s[13] = m13_axis_tready;
    assign m_axis_tready_s[14] = m14_axis_tready;
    assign m_axis_tready_s[15] = m15_axis_tready;

    assign m0_axis_tdata   = m_axis_tdata_s[0];
    assign m0_axis_tvalid  = m_axis_tvalid_s[0];
    assign m1_axis_tdata   = m_axis_tdata_s[1];
    assign m1_axis_tvalid  = m_axis_tvalid_s[1];
    assign m2_axis_tdata   = m_axis_tdata_s[2];
    assign m2_axis_tvalid  = m_axis_tvalid_s[2];
    assign m3_axis_tdata   = m_axis_tdata_s[3];
    assign m3_axis_tvalid  = m_axis_tvalid_s[3];
    assign m4_axis_tdata   = m_axis_tdata_s[4];
    assign m4_axis_tvalid  = m_axis_tvalid_s[4];
    assign m5_axis_tdata   = m_axis_tdata_s[5];
    assign m5_axis_tvalid  = m_axis_tvalid_s[5];
    assign m6_axis_tdata   = m_axis_tdata_s[6];
    assign m6_axis_tvalid  = m_axis_tvalid_s[6];
    assign m7_axis_tdata   = m_axis_tdata_s[7];
    assign m7_axis_tvalid  = m_axis_tvalid_s[7];
    assign m8_axis_tdata   = m_axis_tdata_s[8];
    assign m8_axis_tvalid  = m_axis_tvalid_s[8];
    assign m9_axis_tdata   = m_axis_tdata_s[9];
    assign m9_axis_tvalid  = m_axis_tvalid_s[9];
    assign m10_axis_tdata  = m_axis_tdata_s[10];
    assign m10_axis_tvalid = m_axis_tvalid_s[10];
    assign m11_axis_tdata  = m_axis_tdata_s[11];
    assign m11_axis_tvalid = m_axis_tvalid_s[11];
    assign m12_axis_tdata  = m_axis_tdata_s[12];
    assign m12_axis_tvalid = m_axis_tvalid_s[12];
    assign m13_axis_tdata  = m_axis_tdata_s[13];
    assign m13_axis_tvalid = m_axis_tvalid_s[13];
    assign m14_axis_tdata  = m_axis_tdata_s[14];
    assign m14_axis_tvalid = m_axis_tvalid_s[14];
    assign m15_axis_tdata  = m_axis_tdata_s[15];
    assign m15_axis_tvalid = m_axis_tvalid_s[15];


    generate
        if (GEN_SYNC == 1) begin : gen_sync_out
            logic net_sync;
            always_ff @(posedge t_clk_i, negedge t_resetn) begin
                if (!t_resetn) net_sync <= 1'b0;
                else           net_sync <= t_time_abs_o[29];
            end
            assign pulse_sync_o = net_sync;
        end else begin : gen_no_sync_out
            assign pulse_sync_o = 0;
        end
    endgenerate

endmodule
