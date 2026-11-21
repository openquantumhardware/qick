///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : qick_processor
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    qick_processor.sv
//!
//! @brief   Top-level QICK tProcessor v2 composition: AXI-Lite register
//!          bank, start/stop/time-base control, one or two qproc_core CPUs,
//!          bulk-memory DMA, the timed output dispatcher, and the internal
//!          arith/divider/flag peripherals, all tied together.
//!
//! @details
//!
//!
//! Peripheral dispatch: `usr_ctrl_o[7:4]` (or `[7:5]` for the external
//! group) from the currently-executing core selects which peripheral an
//! `INT_CTRL`/`EXT_CTRL` instruction targets -- TIME/FLAG/ARITH/DIV
//! internally, NET/COM/P1/P2 externally (network/comm/general-purpose
//! peripheral ports, e.g. XCOM). `sreg_core_r_dt_i`/`READ_SEL` select which
//! peripheral's result is visible as CORE_R_DT / the AXI TPROC_R_DT
//! register.
//!
//! `DUAL_CORE=1` instantiates a second, mostly-debug-only `qproc_core`
//! (CORE_1) sharing the memory-DMA/dispatcher/peripherals with CORE_0.
//! `DEBUG` (0-3) progressively enables the AXI status/debug registers,
//! the CORE_R_DT debug sources, and the raw `*_debug_do` buses.
//!
//! Ported from firmware/ip/qick_processor/src/qick_processor.sv (FSMs/mux
//! structure unchanged; entirely assembled from already-ported lib cores:
//! qproc_ctrl, qproc_core, qproc_dispatcher, qproc_inport_reg,
//! qproc_mem_ctrl, tpv2_arith (`arith`), restoring_divider (`div_r`)).
//! `sync_reg` -> `cdc_reg_sync`; the legacy `TYPE_IF_AXI_REG` interface ->
//! `axi4_lite_if` (matching the already-ported qproc_axi_reg, instantiated
//! here as before). All previously implicit nets were made explicit; the
//! dead `t_core_rst_prev_net` (declared, never used in the legacy tree) was
//! dropped.
//!
//! @author  QICK Development Team
//!
//! @version 1.0

`include "tpv2_pkg.sv"

module tprocv2 #(
    parameter int DEBUG         = 0,
    parameter int DUAL_CORE     = 0,
    parameter int LFSR          = 0,
    parameter int DIVIDER       = 1,
    parameter int ARITH         = 1,
    parameter int TIME_READ     = 1,
    parameter int FIFO_DEPTH    = 8,
    parameter int PMEM_AW       = 8,
    parameter int DMEM_AW       = 8,
    parameter int WMEM_AW       = 8,
    parameter int REG_AW        = 4,
    parameter int IN_PORT_QTY   = 1,
    parameter int OUT_TRIG_QTY  = 1,
    parameter int OUT_DPORT_QTY = 1,
    parameter int OUT_DPORT_DW  = 4,
    parameter int OUT_WPORT_QTY = 1
) (
    // Time, core and AXI clk & rst
    input  logic t_clk_i,
    input  logic t_rst_ni,
    input  logic c_clk_i,
    input  logic c_rst_ni,
    input  logic ps_clk_i,
    input  logic ps_rst_ni,
    // External control
    input  logic         ext_flag_i,
    input  logic         proc_start_i,
    input  logic         proc_stop_i,
    input  logic         core_start_i,
    input  logic         core_stop_i,
    input  logic         time_rst_i,
    input  logic         time_init_i,
    input  logic         time_updt_i,
    input  logic [31:0]  time_updt_dt_i,
    output logic [47:0]  time_abs_o,
    // External peripherals
    output logic [31:0] periph_a_dt_o,
    output logic [31:0] periph_b_dt_o,
    output logic [31:0] periph_c_dt_o,
    output logic [31:0] periph_d_dt_o,
    output logic [4:0]  periph_op_o,
    // Qnet_dt
    output logic         qnet_en_o,
    input  logic         qnet_rdy_i,
    input  logic [31:0]  qnet_dt_i [2],
    input  logic         qnet_vld_i,
    input  logic         qnet_flag_i,
    // Qcom_dt
    output logic         qcom_en_o,
    input  logic         qcom_rdy_i,
    input  logic [31:0]  qcom_dt_i [2],
    input  logic         qcom_vld_i,
    input  logic         qcom_flag_i,
    // Qp1
    output logic         qp1_en_o,
    input  logic         qp1_rdy_i,
    input  logic [31:0]  qp1_dt_i [2],
    input  logic         qp1_vld_i,
    input  logic         qp1_flag_i,
    // Qp2
    output logic         qp2_en_o,
    input  logic         qp2_rdy_i,
    input  logic [31:0]  qp2_dt_i [2],
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
    axi4_lite_if.slave    s_axi,
    // Data input interface
    input  logic          port_tvalid_i [IN_PORT_QTY],
    input  logic [63:0]   port_tdata_i  [IN_PORT_QTY],
    // Triggers
    output logic          port_trig_o [OUT_TRIG_QTY],
    // Data output interface
    output logic                    port_tvalid_o [OUT_DPORT_QTY],
    output logic [OUT_DPORT_DW-1:0] port_tdata_o  [OUT_DPORT_QTY],
    // AXI-Stream master I/F
    output logic [167:0] m_axis_tdata  [OUT_WPORT_QTY],
    output logic          m_axis_tvalid [OUT_WPORT_QTY],
    input  logic          m_axis_tready [OUT_WPORT_QTY],

    // Debug interface
    input  logic [3:0]  dport_di,
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

    // Signals
    ///////////////////////////////////////////////////////////////////////////
    // Signals starting with t_ are in the t_clk domain; c_ in the c_clk domain.

    // Time
    logic [47:0] time_abs;    // Absolute time counter value ("out_abs_time")
    logic [47:0] c_time_ref_dt; // Reference time ("ref_time")
    logic [31:0] c_time_usr;    // User time ("current_user_time")

    // AXI registers
    logic [15:0] xreg_tproc_ctrl, xreg_tproc_cfg;
    logic [15:0] xreg_mem_addr, xreg_mem_len;
    logic [31:0] xreg_mem_dt_i, xreg_mem_dt_o;
    logic [31:0] xreg_tproc_status, xreg_tproc_debug;
    logic [31:0] xreg_tproc_w_dt [2];
    logic [7:0]  xreg_core_cfg;
    logic [7:0]  xreg_read_sel;
    logic [31:0] xreg_tproc_r_dt [2];

    // Axis-input
    logic [63:0] in_port_dt_r [IN_PORT_QTY]; // Data registered from input port, latched when tvalid=1
    logic [15:0] port_dt_new;

    // Ctrl instruction (time, flag, arith, div, net, custom)
    logic [31:0] core_usr_a_dt, core_usr_b_dt, core_usr_c_dt, core_usr_d_dt;
    logic [4:0]  core_usr_operation; // 4 bits for internal, 5 bits for external

    ///// Dual core
    logic [31:0] core0_w_dt [2];
    logic [31:0] core1_w_dt [2];

    // Memory operations
    logic [1:0]   ext_core_sel;
    logic [1:0]   ext_mem_sel;
    logic         ext_mem_we;
    logic [15:0]  ext_mem_addr;
    logic [167:0] ext_mem_w_dt;
    logic [167:0] ext_mem_r_dt, ext_mem_r_0_dt, ext_mem_r_1_dt;

    // Peripherals
    logic         div_rdy, arith_rdy;
    logic [63:0]  arith_result;
    logic [31:0]  div_remainder, div_quotient;
    logic [31:0]  core0_lfsr;
    logic [31:0]  core1_lfsr;

    // Debug signals
    logic [31:0] axi_mem_ds;
    logic [31:0] core_r_d0 [2], core_r_d1 [2], core_r_d2 [2], core_r_d3 [2];
    logic [31:0] core_ds;


    ///////////////////////////////////////////////////////////////////////////////
    // Control signals
    ///////////////////////////////////////////////////////////////////////////////

    logic [2:0] time_st_ds, core_st_ds;
    logic [6:0] ctrl_t_ds, ctrl_c_ds;
    logic       core_rst, core_en, time_rst, time_en;
    logic       all_fifo_full, some_fifo_full;
    logic       int_time_pen;

    qproc_ctrl #(
        .TIME_READ (TIME_READ)
    ) qproc_ctrl_i (
        .t_clk_i         (t_clk_i),
        .t_rst_ni        (t_rst_ni),
        .c_clk_i         (c_clk_i),
        .c_rst_ni        (c_rst_ni),
        .proc_start_i    (proc_start_i),
        .proc_stop_i     (proc_stop_i),
        .core_start_i    (core_start_i),
        .core_stop_i     (core_stop_i),
        .time_rst_i      (time_rst_i),
        .time_updt_i     (time_updt_i),
        .time_updt_dt_i  (time_updt_dt_i),
        .int_time_en     (int_time_pen),
        .int_time_cmd    (core_usr_operation[3:0]),
        .int_time_dt     (core_usr_b_dt),
        .ps_tproc_ctrl_i   (xreg_tproc_ctrl),
        .ps_tproc_cfg_i    (xreg_tproc_cfg[11:9]),
        .xreg_tproc_w_dt_i (xreg_tproc_w_dt[0]),
        .all_fifo_full_i  (all_fifo_full),
        .some_fifo_full_i (some_fifo_full),
        .core_rst_o      (core_rst),
        .core_en_o       (core_en),
        .time_rst_o      (time_rst),
        .time_en_o       (time_en),
        .time_abs_o      (time_abs),
        .c_time_ref_o    (c_time_ref_dt),
        .c_time_usr_o    (c_time_usr),
        .time_st_do      (time_st_ds),
        .core_st_do      (core_st_ds),
        .t_debug_do      (ctrl_t_ds),
        .c_debug_do      (ctrl_c_ds)
    );


    ///////////////////////////////////////////////////////////////////////////////
    // Processor status
    ///////////////////////////////////////////////////////////////////////////////
    logic [3:0] core0_src_dt, core1_src_dt;
    logic       arith_clr, div_clr, qnet_clr, qcom_clr, qp1_clr, qp2_clr, port_clr;
    logic       arith_rdy_r, div_rdy_r, qnet_rdy_r, qcom_rdy_r, qp1_rdy_r, qp2_rdy_r;
    logic       arith_dt_new, div_dt_new, qnet_dt_new, qcom_dt_new, qp1_dt_new, qp2_dt_new;
    logic [31:0] qnet_dt_r [2], qcom_dt_r [2], qp1_dt_r [2], qp2_dt_r [2];

    logic [7:0] core0_cfg, core1_cfg;
    logic [7:0] core0_ctrl, core1_ctrl;

    assign core0_src_dt = core0_cfg[3:0];
    assign core1_src_dt = core1_cfg[3:0];

    assign arith_clr = core0_ctrl[0] | core1_ctrl[0];
    assign div_clr   = core0_ctrl[1] | core1_ctrl[1];
    assign qnet_clr  = core0_ctrl[2] | core1_ctrl[2];
    assign qcom_clr  = core0_ctrl[3] | core1_ctrl[3];
    assign qp1_clr   = core0_ctrl[4] | core1_ctrl[4];
    assign qp2_clr   = core0_ctrl[5] | core1_ctrl[5];
    assign port_clr  = core0_ctrl[6] | core1_ctrl[6];

    logic [31:0] sreg_status;
    assign sreg_status[0]     = arith_rdy;
    assign sreg_status[1]     = arith_dt_new;
    assign sreg_status[2]     = div_rdy;
    assign sreg_status[3]     = div_dt_new;
    assign sreg_status[4]     = qnet_rdy_r;
    assign sreg_status[5]     = qnet_dt_new;
    assign sreg_status[6]     = qcom_rdy_r;
    assign sreg_status[7]     = qcom_dt_new;
    assign sreg_status[8]     = qp1_rdy_r;
    assign sreg_status[9]     = qp1_dt_new;
    assign sreg_status[10]    = qp2_rdy_r;
    assign sreg_status[11]    = qp2_dt_new;
    assign sreg_status[12]    = 1'b0;
    assign sreg_status[13]    = 1'b0;
    assign sreg_status[14]    = some_fifo_full;
    assign sreg_status[15]    = |port_dt_new;
    assign sreg_status[31:16] = port_dt_new;



    // With rising edge of RDY detect new values
    always_ff @(posedge c_clk_i) begin
        if (core_rst) begin
            arith_rdy_r  <= 1'b1;
            div_rdy_r    <= 1'b1;
            qnet_rdy_r   <= 1'b1;
            qcom_rdy_r   <= 1'b1;
            qp1_rdy_r    <= 1'b1;
            qp2_rdy_r    <= 1'b1;
            arith_dt_new <= 1'b0;
            div_dt_new   <= 1'b0;
            qnet_dt_new  <= 1'b0;
            qcom_dt_new  <= 1'b0;
            qp1_dt_new   <= 1'b0;
            qp2_dt_new   <= 1'b0;
            qnet_dt_r    <= '{default: '0};
            qcom_dt_r    <= '{default: '0};
            qp1_dt_r     <= '{default: '0};
            qp2_dt_r     <= '{default: '0};
        end else begin
            arith_rdy_r <= arith_rdy;
            div_rdy_r   <= div_rdy;
            qnet_rdy_r  <= qnet_rdy_i;
            qcom_rdy_r  <= qcom_rdy_i;
            qp1_rdy_r   <= qp1_rdy_i;
            qp2_rdy_r   <= qp2_rdy_i;
            // Arith control
            if      (arith_rdy & ~arith_rdy_r) arith_dt_new <= 1;
            else if (~arith_rdy & arith_rdy_r) arith_dt_new <= 0;
            else if (arith_clr)                arith_dt_new <= 0;
            // Div control
            if      (div_rdy & ~div_rdy_r) div_dt_new <= 1;
            else if (~div_rdy & div_rdy_r) div_dt_new <= 0;
            else if (div_clr)              div_dt_new <= 0;
            // Qnet control
            if (qnet_vld_i) begin
                qnet_dt_new <= 1;
                qnet_dt_r   <= qnet_dt_i;
            end else if (qnet_clr) qnet_dt_new <= 0;
            // Qcom control
            if (qcom_vld_i) begin
                qcom_dt_new <= 1;
                qcom_dt_r   <= qcom_dt_i;
            end else if (qcom_clr) qcom_dt_new <= 0;
            // Q-peripheral 1 control
            if (qp1_vld_i) begin
                qp1_dt_new <= 1;
                qp1_dt_r   <= qp1_dt_i;
            end else if (qp1_clr) qp1_dt_new <= 0;
            // Q-peripheral 2 control
            if (qp2_vld_i) begin
                qp2_dt_new <= 1;
                qp2_dt_r   <= qp2_dt_i;
            end else if (qp2_clr) qp2_dt_new <= 0;   // was qp1_clr

        end
    end


    ///////////////////////////////////////////////////////////////////////////////
    // Flag
    ///////////////////////////////////////////////////////////////////////////////

    // External flag
    ///////////////////////////////////////////////////////////////////////////////
    logic ext_flag_r;
    cdc_reg_sync #(.DW (1)) cdc_flag_ext_c_i (
        .clk_i  (c_clk_i),
        .rst_ni (c_rst_ni),
        .dt_i   (ext_flag_i),
        .dt_o   (ext_flag_r)
    );


    // Internal flag
    ///////////////////////////////////////////////////////////////////////////////
    logic axi_flag_set, axi_flag_clr, int_flag_set, int_flag_clr, int_flag_inv;
    logic int_flag_pen;

    assign axi_flag_set = xreg_tproc_ctrl[13];
    assign axi_flag_clr = xreg_tproc_ctrl[14];
    assign int_flag_set = (int_flag_pen & core_usr_operation[0]);
    assign int_flag_clr = (int_flag_pen & core_usr_operation[1]);
    assign int_flag_inv = (int_flag_pen & core_usr_operation[2]);

    logic axi_flag_r, int_flag_r;
    always_ff @(posedge c_clk_i) begin
        if (core_rst) begin
            axi_flag_r <= 0;
            int_flag_r <= 0;
        end else begin
            if      (axi_flag_set) axi_flag_r <= 1; // Set external flag
            else if (axi_flag_clr) axi_flag_r <= 0; // Clear external flag
            if      (int_flag_set) int_flag_r <= 1;       // Set internal flag
            else if (int_flag_clr) int_flag_r <= 0;       // Clear internal flag
            else if (int_flag_inv) int_flag_r <= ~int_flag_r; // Flip internal flag
        end
    end


    ///////////////////////////////////////////////////////////////////////////////
    // Instances
    ///////////////////////////////////////////////////////////////////////////////

    // In-port data register
    ///////////////////////////////////////////////////////////////////////////////
    qproc_inport_reg #(
        .PORT_QTY (IN_PORT_QTY)
    ) in_port_reg_i (
        .c_clk_i       (c_clk_i),
        .c_rst_ni      (c_rst_ni),
        .c_clear       (port_clr),
        .port_tvalid_i (port_tvalid_i),
        .port_tdata_i  (port_tdata_i),
        .port_tnew_o   (port_dt_new),
        .port_tdata_o  (in_port_dt_r)
    );

    // Mem control
    ///////////////////////////////////////////////////////////////////////////////
    assign ext_mem_r_dt = ext_mem_r_0_dt; // From core0

    qproc_mem_ctrl #(
        .PMEM_AW (PMEM_AW),
        .DMEM_AW (DMEM_AW),
        .WMEM_AW (WMEM_AW)
    ) qmem_ctrl_i (
        .clk              (ps_clk_i),
        .rstn             (ps_rst_ni),
        .ext_core_sel_o   (ext_core_sel),
        .ext_mem_sel_o    (ext_mem_sel),
        .ext_mem_we_o     (ext_mem_we),
        .ext_mem_addr_o   (ext_mem_addr),
        .ext_mem_w_dt_o   (ext_mem_w_dt),
        .ext_mem_r_dt_i   (ext_mem_r_dt),
        .s_axis_tdata_i   (s_dma_axis_tdata_i),
        .s_axis_tlast_i   (s_dma_axis_tlast_i),
        .s_axis_tvalid_i  (s_dma_axis_tvalid_i),
        .s_axis_tready_o  (s_dma_axis_tready_o),
        .m_axis_tdata_o   (m_dma_axis_tdata_o),
        .m_axis_tlast_o   (m_dma_axis_tlast_o),
        .m_axis_tvalid_o  (m_dma_axis_tvalid_o),
        .m_axis_tready_i  (m_dma_axis_tready_i),
        .mem_ctrl (xreg_tproc_cfg[6:0]),
        .mem_addr (xreg_mem_addr),
        .mem_len  (xreg_mem_len),
        .mem_dt_i (xreg_mem_dt_i),
        .mem_dt_o (xreg_mem_dt_o),
        .debug_o  (axi_mem_ds),
        .busy_o       (),
        .end_single_o ()
    );


    // AXI registers
    ///////////////////////////////////////////////////////////////////////////////
    qproc_axi_reg qproc_axi_reg_i (
        .ps_aclk    (ps_clk_i),
        .ps_aresetn (ps_rst_ni),
        .s_axi      (s_axi),
        .tproc_ctrl_o  (xreg_tproc_ctrl),
        .tproc_cfg_o   (xreg_tproc_cfg),
        .mem_addr_o    (xreg_mem_addr),
        .mem_len_o     (xreg_mem_len),
        .mem_dt_i_o    (xreg_mem_dt_i),
        .tproc_w_dt1_o (xreg_tproc_w_dt[0]),
        .tproc_w_dt2_o (xreg_tproc_w_dt[1]),
        .core_cfg_o    (xreg_core_cfg),
        .read_sel_o    (xreg_read_sel),
        .mem_dt_o_i     (xreg_mem_dt_o),
        .tproc_r_dt1_i  (xreg_tproc_r_dt[0]),
        .tproc_r_dt2_i  (xreg_tproc_r_dt[1]),
        .time_usr_i     (c_time_usr),
        .tproc_status_i (xreg_tproc_status),
        .tproc_debug_i  (xreg_tproc_debug)
    );

    // Axi_reg TPROC_R_DT source selection
    ///////////////////////////////////////////////////////////////////////////////
    logic [3:0] tproc_src_dt;
    assign tproc_src_dt = xreg_read_sel[3:0];

    always_ff @(posedge ps_clk_i, negedge ps_rst_ni) begin
        if (!ps_rst_ni) begin
            xreg_tproc_r_dt <= '{default: '0};
        end else begin
            unique case (tproc_src_dt)
                4'd0:    xreg_tproc_r_dt <= xreg_tproc_w_dt;
                4'd1:    xreg_tproc_r_dt <= core0_w_dt;
                4'd2:    xreg_tproc_r_dt <= core1_w_dt;
                4'd3:    xreg_tproc_r_dt <= {div_quotient, div_remainder};
                4'd4:    xreg_tproc_r_dt <= '{arith_result[31:0], arith_result[63:32]};
                4'd5:    xreg_tproc_r_dt <= qnet_dt_r;
                4'd6:    xreg_tproc_r_dt <= qcom_dt_r;
                4'd7:    xreg_tproc_r_dt <= qp1_dt_r;
                4'd8:    xreg_tproc_r_dt <= qp2_dt_r;
                4'd9:    xreg_tproc_r_dt <= '{in_port_dt_r[0][31:0], in_port_dt_r[0][63:32]};
                4'd10:   xreg_tproc_r_dt <= '{core0_lfsr, core1_lfsr};
                default: xreg_tproc_r_dt <= '{default: '0};
            endcase
        end
    end



    ///////////////////////////////////////////////////////////////////////////////
    // Peripherals
    ///////////////////////////////////////////////////////////////////////////////

    logic [7:0] usr_ctrl_s;
    logic       usr_en;
    logic       int_arith_pen, int_div_pen;
    logic       ext_net_pen, ext_com_pen, ext_p1_pen, ext_p2_pen;
    // Internal peripherals enable (MSB=0 - 8 possible peripherals)
    assign int_time_pen  = usr_en & (usr_ctrl_s[7:4] == 4'b0000);
    assign int_flag_pen  = usr_en & (usr_ctrl_s[7:4] == 4'b0001);
    assign int_arith_pen = usr_en & (usr_ctrl_s[7:4] == 4'b0010);
    assign int_div_pen   = usr_en & (usr_ctrl_s[7:4] == 4'b0011);

    // External peripherals enable (MSB=1 - 4 possible peripherals)
    assign ext_net_pen = usr_en & (usr_ctrl_s[7:5] == 3'b100);
    assign ext_com_pen = usr_en & (usr_ctrl_s[7:5] == 3'b101);
    assign ext_p1_pen  = usr_en & (usr_ctrl_s[7:5] == 3'b110);
    assign ext_p2_pen  = usr_en & (usr_ctrl_s[7:5] == 3'b111);

    assign core_usr_operation = usr_ctrl_s[4:0];

    // Divider
    ///////////////////////////////////////////////////////////////////////////////
    generate
        if (DIVIDER == 1) begin : gen_div
            logic [31:0] div_remainder_s, div_quotient_s;
            logic [31:0] div_remainder_r, div_quotient_r;
            restoring_divider #(
                .DW (32)
            ) div_i (
                .clk_i  (c_clk_i),
                .rst_ni (c_rst_ni),
                .start_i (int_div_pen),
                .a_i     (core_usr_d_dt),
                .b_i     (core_usr_b_dt),
                .ready_o (div_rdy),
                .div_remainder_o (div_remainder_s),
                .div_quotient_o  (div_quotient_s)
            );

            always_ff @(posedge c_clk_i, negedge c_rst_ni) begin
                if (!c_rst_ni) begin
                    div_remainder_r <= 0;
                    div_quotient_r  <= 0;
                end else begin
                    div_remainder_r <= div_remainder_s;
                    div_quotient_r  <= div_quotient_s;
                end
            end
            assign div_remainder = div_remainder_r;
            assign div_quotient  = div_quotient_r;
        end else begin : gen_no_div
            assign div_rdy       = 0;
            assign div_remainder = 0;
            assign div_quotient  = 0;
        end
    endgenerate

    // Arith
    ///////////////////////////////////////////////////////////////////////////////
    generate
        if (ARITH == 1) begin : gen_arith
            tpv2_arith arith_i (
                .clk_i    (c_clk_i),
                .rst_ni   (c_rst_ni),
                .start_i  (int_arith_pen),
                .a_i      (core_usr_a_dt),
                .b_i      (core_usr_b_dt),
                .c_i      (core_usr_c_dt),
                .d_i      (core_usr_d_dt),
                .alu_op_i (core_usr_operation[3:0]),
                .ready_o  (arith_rdy),
                .arith_result_o (arith_result)
            );
        end else begin : gen_no_arith
            assign arith_rdy    = 0;
            assign arith_result = 0;
        end
    endgenerate




    ///////////////////////////////////////////////////////////////////////////////
    // T processor core
    logic [1:0] core0_lfsr_cfg;
    assign core0_lfsr_cfg = xreg_core_cfg[1:0];

    // Core0 flag source selection
    ///////////////////////////////////////////////////////////////////////////////
    logic [3:0] core0_src_flg;
    assign core0_src_flg = core0_cfg[7:4];
    logic flag_c0;
    always_comb begin
        unique case (core0_src_flg)
            4'b0000: flag_c0 = int_flag_r;
            4'b0001: flag_c0 = axi_flag_r;
            4'b0010: flag_c0 = ext_flag_r;
            4'b0011: flag_c0 = div_dt_new | arith_dt_new;
            4'b0100: flag_c0 = |port_dt_new;
            4'b0101: flag_c0 = qnet_flag_i;
            4'b0110: flag_c0 = qcom_flag_i;
            4'b0111: flag_c0 = qp1_flag_i;
            4'b1000: flag_c0 = qp2_flag_i;   // flg_qpb (revision 29); codes 0x9..0xF still read 0
            default: flag_c0 = 0;
        endcase
    end

    // Core0 CORE_R_DT sreg(s7) source selection
    ///////////////////////////////////////////////////////////////////////////////
    logic [31:0] core0_r_dt [2];
    always_comb begin
        unique case (core0_src_dt)
            4'b0000: core0_r_dt = xreg_tproc_w_dt;
            4'b0001: core0_r_dt = '{arith_result[31:0], arith_result[63:32]};
            4'b0010: core0_r_dt = qnet_dt_r;
            4'b0011: core0_r_dt = qcom_dt_r;
            4'b0100: core0_r_dt = qp1_dt_r;
            4'b0101: core0_r_dt = qp2_dt_r;
            4'b0110: core0_r_dt = core1_w_dt;
            4'b0111: core0_r_dt = '{in_port_dt_r[0][31:0], in_port_dt_r[0][63:32]};
            // Debug
            4'b1000: core0_r_dt = core_r_d0;
            4'b1001: core0_r_dt = core_r_d1;
            4'b1010: core0_r_dt = core_r_d2;
            4'b1011: core0_r_dt = core_r_d3;
            default: core0_r_dt = xreg_tproc_w_dt;
        endcase
    end

    tpv2_pkg::PORT_DT out_port_data; // Port data from the CPU
    logic port_we;

    qproc_core #(
        .LFSR        (LFSR),
        .IN_PORT_QTY (IN_PORT_QTY),
        .PMEM_AW     (PMEM_AW),
        .DMEM_AW     (DMEM_AW),
        .WMEM_AW     (WMEM_AW),
        .REG_AW      (REG_AW)
    ) core_0_i (
        .c_clk_i   (c_clk_i),
        .c_rst_ni  (c_rst_ni),
        .ps_clk_i  (ps_clk_i),
        .ps_rst_ni (ps_rst_ni),
        .en_i      (core_en),
        .restart_i (core_rst),
        // Core ctrl
        .lfsr_cfg_i    (core0_lfsr_cfg),
        .core_status_o (),
        .core_debug_o  (),
        .lfsr_o        (core0_lfsr),
        .port_dt_i (in_port_dt_r), // All the port values
        .flag_i    (flag_c0),
        .sreg_cfg_o       (core0_cfg),
        .sreg_ctrl_o      (core0_ctrl),
        .sreg_arith_i     (arith_result[31:0]),
        .sreg_div_i       ({div_quotient, div_remainder}),
        .sreg_status_i    (sreg_status),
        .sreg_core_r_dt_i (core0_r_dt),
        .sreg_time_dt_i   (c_time_usr),
        .sreg_core_w_dt_o (core0_w_dt),
        .usr_en_o   (usr_en),
        .usr_ctrl_o (usr_ctrl_s),
        .usr_dt_a_o (core_usr_a_dt),
        .usr_dt_b_o (core_usr_b_dt),
        .usr_dt_c_o (core_usr_c_dt),
        .usr_dt_d_o (core_usr_d_dt),
        .ps_mem_sel_i  (ext_mem_sel),
        .ps_mem_we_i   (ext_mem_we),
        .ps_mem_addr_i (ext_mem_addr),
        .ps_mem_w_dt_i (ext_mem_w_dt),
        .ps_mem_r_dt_o (ext_mem_r_0_dt),
        .port_we_o (port_we),
        .port_o    (out_port_data),
        .core_do   (core_ds)
    );



    ///////////////////////////////////////////////////////////////////////////////
    ///// Dual core
    logic [1:0] core1_lfsr_cfg;
    assign core1_lfsr_cfg = xreg_core_cfg[3:2];

    generate
        if (DUAL_CORE == 1) begin : gen_dual_core
            logic [31:0] core1_r_dt [2];
            always_comb begin
                unique case (core1_src_dt)
                    4'b0000: core1_r_dt = xreg_tproc_w_dt;
                    4'b0001: core1_r_dt = '{arith_result[31:0], arith_result[63:32]};
                    4'b0010: core1_r_dt = qnet_dt_r;
                    4'b0011: core1_r_dt = qcom_dt_r;
                    4'b0100: core1_r_dt = qp1_dt_r;
                    4'b0101: core1_r_dt = qp2_dt_r;
                    4'b0110: core1_r_dt = core1_w_dt;
                    4'b0111: core1_r_dt = '{in_port_dt_r[0][31:0], in_port_dt_r[0][63:32]};
                    default: core1_r_dt = '{default: '0};
                endcase
            end
            qproc_core #(
                .LFSR        (LFSR),
                .IN_PORT_QTY (IN_PORT_QTY),
                .PMEM_AW     (PMEM_AW),
                .DMEM_AW     (DMEM_AW),
                .WMEM_AW     (WMEM_AW),
                .REG_AW      (REG_AW)
            ) core_1_i (
                .c_clk_i   (c_clk_i),
                .c_rst_ni  (c_rst_ni),
                .ps_clk_i  (ps_clk_i),
                .ps_rst_ni (ps_rst_ni),
                .en_i      (core_en),
                .restart_i (core_rst),
                .lfsr_cfg_i    (core1_lfsr_cfg),
                .core_status_o (),
                .core_debug_o  (),
                .lfsr_o        (core1_lfsr),
                .port_dt_i (in_port_dt_r),
                .flag_i    (1'b0),
                .sreg_arith_i     (arith_result[31:0]),
                .sreg_div_i       ({div_quotient, div_remainder}),
                .sreg_status_i    (sreg_status),
                .sreg_core_r_dt_i (core1_r_dt),
                .sreg_core_w_dt_o (core1_w_dt),
                .sreg_time_dt_i   (c_time_usr),
                .sreg_cfg_o       (core1_cfg),
                .sreg_ctrl_o      (core1_ctrl),
                .usr_en_o   (),
                .usr_dt_a_o (),
                .usr_dt_b_o (),
                .usr_dt_c_o (),
                .usr_dt_d_o (),
                .usr_ctrl_o (),
                .ps_mem_sel_i  ('0),
                .ps_mem_we_i   (1'b0),
                .ps_mem_addr_i ('0),
                .ps_mem_w_dt_i ('0),
                .ps_mem_r_dt_o (ext_mem_r_1_dt),
                .port_we_o (),
                .port_o    (),
                .core_do   ()
            );
        end else begin : gen_no_dual_core
            assign core1_lfsr     = '{default: '0};
            assign core1_w_dt     = '{default: '0};
            assign core1_cfg      = '{default: '0};
            assign core1_ctrl     = '{default: '0};
            assign ext_mem_r_1_dt = '{default: '0};
        end
    endgenerate




    logic [31:0] fifo_dt_ds, axi_fifo_ds;
    logic [15:0] c_fifo_ds, t_fifo_ds;

    qproc_dispatcher #(
        .FIFO_DEPTH    (FIFO_DEPTH),
        .IN_PORT_QTY   (IN_PORT_QTY),
        .OUT_TRIG_QTY  (OUT_TRIG_QTY),
        .OUT_DPORT_QTY (OUT_DPORT_QTY),
        .OUT_DPORT_DW  (OUT_DPORT_DW),
        .OUT_WPORT_QTY (OUT_WPORT_QTY)
    ) dispatcher_i (
        .c_clk_i  (c_clk_i),
        .c_rst_ni (c_rst_ni),
        .t_clk_i  (t_clk_i),
        .t_rst_ni (t_rst_ni),
        // Port
        .core_en  (core_en),
        .core_rst (core_rst),
        .time_en  (time_en),
        .time_rst (time_rst),
        .c_time_ref_dt (c_time_ref_dt),
        .time_abs_i    (time_abs),
        .all_fifo_full  (all_fifo_full),
        .some_fifo_full (some_fifo_full),
        .port_we       (port_we),
        .out_port_data (out_port_data),
        // Triggers
        .port_trig_o (port_trig_o),
        // Data output interface
        .port_tvalid_o (port_tvalid_o),
        .port_tdata_o  (port_tdata_o),
        // Wave output interface
        .m_axis_tdata  (m_axis_tdata),
        .m_axis_tvalid (m_axis_tvalid),
        .m_axis_tready (m_axis_tready),
        // Debug outputs
        .fifo_dt_do  (fifo_dt_ds),
        .axi_fifo_do (axi_fifo_ds),
        .c_fifo_do   (c_fifo_ds),
        .t_fifo_do   (t_fifo_ds)
    );


    ///////////////////////////////////////////////////////////////////////////////
    // Outputs
    ///////////////////////////////////////////////////////////////////////////////


    ///////////////////////////////////////////////////////////////////////////////
    // Out peripherals (qnet, qcom, p1 and p2)
    assign qnet_en_o = ext_net_pen;
    assign qcom_en_o = ext_com_pen;
    assign qp1_en_o  = ext_p1_pen;
    assign qp2_en_o  = ext_p2_pen;

    assign periph_a_dt_o = core_usr_a_dt;
    assign periph_b_dt_o = core_usr_b_dt;
    assign periph_c_dt_o = core_usr_c_dt;
    assign periph_d_dt_o = core_usr_d_dt;
    assign periph_op_o   = core_usr_operation;


    ///////////////////////////////////////////////////////////////////////////////
    ///// External control
    assign time_abs_o = time_abs;



    ///////////////////////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////////
    // Debug
    ///////////////////////////////////////////////////////////////////////////////

    localparam int DEBUG_AXI = (DEBUG > 0) ? 1 : 0;
    localparam int DEBUG_REG = (DEBUG > 1) ? 1 : 0;
    localparam int DEBUG_OUT = (DEBUG > 2) ? 1 : 0;


    generate

        ///// Debug axi_reg
        ///////////////////////////////////////////////////////////////////////////////
        if (DEBUG_AXI == 1) begin : gen_axi_db
            logic [31:0] axi_status_ds, axi_port_ds;

            assign axi_status_ds[31:26] = {qp2_rdy_r, qp1_rdy_r, qcom_rdy_r, qnet_rdy_r, arith_rdy_r, div_rdy_r};
            assign axi_status_ds[25:20] = {qp2_dt_new, qp1_dt_new, qcom_dt_new, qnet_dt_new, div_dt_new, |port_dt_new};
            assign axi_status_ds[19:16] = {flag_c0, qp1_flag_i, qcom_flag_i, qnet_flag_i};
            assign axi_status_ds[15:13] = {ext_flag_r, axi_flag_r, int_flag_r};
            assign axi_status_ds[12:8]  = {core0_src_flg[2:0], core0_src_dt[1:0]};
            assign axi_status_ds[7:4]   = {time_en, time_st_ds[2:0]};
            assign axi_status_ds[3:0]   = {core_en, core_st_ds[2:0]};

            assign axi_port_ds[31:28] = dport_di;
            assign axi_port_ds[27]    = port_trig_o[0];
            assign axi_port_ds[26:24] = port_dt_new[2:0];
            assign axi_port_ds[23:0]  = in_port_dt_r[0][23:0];

            always_ff @(posedge ps_clk_i, negedge ps_rst_ni) begin
                if (!ps_rst_ni) begin
                    xreg_tproc_status <= '{default: '0};
                    xreg_tproc_debug  <= '{default: '0};
                end else begin
                    xreg_tproc_status <= axi_status_ds;
                    unique case (tproc_src_dt[1:0])
                        2'd0: xreg_tproc_debug <= axi_fifo_ds;
                        2'd1: xreg_tproc_debug <= axi_mem_ds;
                        2'd2: xreg_tproc_debug <= c_time_ref_dt;
                        2'd3: xreg_tproc_debug <= axi_port_ds;
                    endcase
                end
            end
        end else begin : gen_no_axi_db
            // No debug axi_reg
            assign xreg_tproc_status = 0;
            assign xreg_tproc_debug  = 0;
        end

        ///// Debug CORE_R_DT
        ///////////////////////////////////////////////////////////////////////////////
        if (DEBUG_REG == 1) begin : gen_reg_db
            assign core_r_d0 = core0_w_dt;
            assign core_r_d1 = '{in_port_dt_r[0], {15'd0, port_trig_o[0], 12'd0, dport_di}};
            assign core_r_d2 = '{c_time_ref_dt[31:0], 32'd0};
            assign core_r_d3 = '{default: '0};
        end else begin : gen_no_reg_db
            // No debug CORE_R_DT
            assign core_r_d0 = '{default: '0};
            assign core_r_d1 = '{default: '0};
            assign core_r_d2 = '{default: '0};
            assign core_r_d3 = '{default: '0};
        end


        ///// Debug out signals
        ///////////////////////////////////////////////////////////////////////////////
        if (DEBUG_OUT == 1) begin : gen_out_db
            logic time_ref_set, time_ref_inc;

            ///// Ps_clock debug signals
            assign ps_debug_do[31:28] = {s_axi.arready, s_axi.rready, s_axi.awready, s_axi.wready};
            assign ps_debug_do[27:24] = {s_axi.arvalid, s_axi.rvalid, s_axi.awvalid, s_axi.wvalid};
            assign ps_debug_do[23:12] = {s_axi.araddr[5:0], s_axi.awaddr[5:0]};
            assign ps_debug_do[11:0]  = {s_axi.rdata[5:0], s_axi.wdata[5:0]};

            ///// T_clock debug signals
            assign t_debug_do[31:16] = t_fifo_ds;
            assign t_debug_do[15:12] = 4'd0;
            assign t_debug_do[11:10] = {time_rst, time_en};
            assign t_debug_do[9:3]   = ctrl_t_ds;
            assign t_debug_do[2:0]   = {time_st_ds[2:0]};

            assign t_fifo_do = fifo_dt_ds;

            ///// C_clock debug signals
            assign c_time_usr_do = c_time_usr;

            assign c_debug_do[31:16] = c_fifo_ds;
            assign c_debug_do[15:14] = {some_fifo_full, all_fifo_full};
            assign c_debug_do[13:12] = {2'd0};
            assign c_debug_do[11:10] = {core_rst, core_en};
            assign c_debug_do[9:3]   = ctrl_c_ds;
            assign c_debug_do[2:0]   = {core_st_ds[2:0]};

            assign c_time_ref_do = c_time_ref_dt;

            assign c_port_do[31:28] = out_port_data.p_addr[3:0];
            assign c_port_do[27:16] = out_port_data.p_data[11:0];
            assign c_port_do[15:0]  = out_port_data.p_time[15:0];

            assign c_proc_do[31:30] = {flag_c0, |port_dt_new};
            assign c_proc_do[29:18] = sreg_status[11:0];
            assign c_proc_do[17:11] = core0_ctrl[6:0];
            assign c_proc_do[10:8]  = core0_src_dt[2:0];
            assign c_proc_do[7:2]   = {int_flag_r, axi_flag_r, int_flag_clr, int_flag_set, axi_flag_clr, axi_flag_set};
            assign c_proc_do[1:0]   = {time_ref_inc, time_ref_set};

            assign c_core_do = core_ds;

            assign time_ref_set = (int_time_pen & core_usr_operation[2]);
            assign time_ref_inc = (int_time_pen & core_usr_operation[3]);

        end else begin : gen_no_out_db
            // No debug out
            assign ps_debug_do   = 0;
            assign t_debug_do    = 0;
            assign t_fifo_do     = 0;
            assign c_time_usr_do = 0;
            assign c_debug_do    = 0;
            assign c_time_ref_do = 0;
            assign c_port_do     = 0;
            assign c_proc_do     = 0;
            assign c_core_do     = 0;
        end
    endgenerate


endmodule
