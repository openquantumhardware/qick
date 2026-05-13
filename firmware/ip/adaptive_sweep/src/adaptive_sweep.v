`timescale 1ns / 1ps
//
// adaptive_sweep.v  --  top wrapper for the adaptive_sweep IP.
//
// Replaces the placeholder 4-entry frequency LUT with the real RTL
// implementation of Section 9 of resonator_sweep.ipynb (KW + Polyak
// averaging + 3 dB bisection).
//
// Hierarchy:
//   adaptive_sweep
//     adaptive_sweep_control      (QP2 opcode FSM, c_clk)
//     readout_capture             (ro_clk -> c_clk CDC FIFO + trigger)
//     polyak_averager (I)         (chunked Polyak average of I)
//     polyak_averager (Q)         (chunked Polyak average of Q)
//     iq_power                    (I_avg^2 + Q_avg^2)
//     kw_steps                    (LUT-driven KW step + clamp)
//     bisect_control              (3 dB edge bisection FSM)
//
// Ports:
//   QP2 slave    : qtag_*           (unchanged from placeholder)
//   AXIS slave   : s_ro_axis_*      (snoop on m1_axis of axis_dyn_readout_v1)
//   trigger_i    : 1-bit, ro_clk async
//

module adaptive_sweep #(
    parameter integer LUT_DEPTH           = 256,
    parameter integer LUT_AW              = 8,
    parameter integer X_WIDTH             = 32,
    parameter integer IQ_WIDTH            = 16,
    parameter integer SUM_WIDTH           = 48,
    parameter integer POW_WIDTH           = 32,
    parameter integer COUNT_WIDTH         = 16,
    parameter integer RO_FIFO_DEPTH_LOG2  = 6,
    parameter [X_WIDTH-1:0] KW_TOL        = 32'h0000_07D0
)(
    input  wire                          clk,        // c_clk
    input  wire                          rst_n,

    // ---- QP2 (tProc-side) ----
    input  wire                          qtag_en_i,
    input  wire [4:0]                    qtag_op_i,
    input  wire [31:0]                   qtag_dt1_i,
    input  wire [31:0]                   qtag_dt2_i,
    input  wire [31:0]                   qtag_dt3_i,
    input  wire [31:0]                   qtag_dt4_i,
    output wire                          qtag_rdy_o,
    output wire [31:0]                   qtag_dt1_o,
    output wire [31:0]                   qtag_dt2_o,
    output wire                          qtag_vld_o,

    // ---- Readout snoop (m1_axis of axis_dyn_readout_v1) ----
    input  wire                          s_ro_axis_aclk,    // ro_clk
    input  wire                          s_ro_axis_aresetn,
    input  wire [2*IQ_WIDTH-1:0]         s_ro_axis_tdata,   // {Q[15:0],I[15:0]}
    input  wire                          s_ro_axis_tvalid,
    output wire                          s_ro_axis_tready,

    // ---- External trigger (ro_clk async, sourced from tProc trig_0_o) ----
    input  wire                          trigger_i
);

    // -------------------------------------------------------------
    // Inter-module wires
    // -------------------------------------------------------------
    // adaptive_sweep_control <-> polyak_averagers
    wire                       pa_soft_reset;
    wire [31:0]                pa_reciprocal;
    wire [3:0]                 pa_chunk_log2;
    wire signed [X_WIDTH-1:0]  pa_i_xbar;
    wire signed [X_WIDTH-1:0]  pa_q_xbar;

    // adaptive_sweep_control <-> iq_power
    wire                       pwr_compute_pulse;
    wire signed [IQ_WIDTH-1:0] pwr_i_in;
    wire signed [IQ_WIDTH-1:0] pwr_q_in;
    wire [POW_WIDTH-1:0]       pwr_value;
    wire                       pwr_valid;

    // adaptive_sweep_control <-> kw_steps
    wire                       kw_lut_we;
    wire [LUT_AW-1:0]          kw_lut_addr;
    wire signed [X_WIDTH-1:0]  kw_lut_din;
    wire                       kw_step_trigger;
    wire signed [X_WIDTH-1:0]  kw_dp_signed;
    wire [LUT_AW-1:0]          kw_k_idx;
    wire signed [X_WIDTH-1:0]  kw_x_in;
    wire signed [X_WIDTH-1:0]  kw_x_min;
    wire signed [X_WIDTH-1:0]  kw_x_max;
    wire signed [X_WIDTH-1:0]  kw_x_out;
    wire                       kw_conv_flag;
    wire                       kw_valid;

    // adaptive_sweep_control <-> bisect_control
    wire                       bs_init;
    wire [X_WIDTH-1:0]         bs_lo_init;
    wire [X_WIDTH-1:0]         bs_hi_init;
    wire                       bs_side_left;
    wire                       bs_polarity_peak;
    wire [X_WIDTH-1:0]         bs_tol_in;
    wire                       bs_step;
    wire [X_WIDTH-1:0]         bs_pow_mid;
    wire [X_WIDTH-1:0]         bs_pow_thr;
    wire [X_WIDTH-1:0]         bs_mid_next;
    wire [X_WIDTH-1:0]         bs_lo_o;
    wire [X_WIDTH-1:0]         bs_hi_o;
    wire                       bs_converged;
    wire                       bs_valid;

    // adaptive_sweep_control <-> readout_capture
    wire                       rc_arm_pulse;
    wire [COUNT_WIDTH-1:0]     rc_n_samples;
    wire                       rc_capture_done;
    wire [COUNT_WIDTH-1:0]     rc_samples_remaining;
    wire signed [IQ_WIDTH-1:0] rc_i_out;
    wire signed [IQ_WIDTH-1:0] rc_q_out;
    wire                       rc_iq_valid;
    wire                       rc_iq_ready;

    // x state visibility (currently unused outside ctrl, but routed for future)
    wire signed [X_WIDTH-1:0]  x_current;
    wire signed [X_WIDTH-1:0]  x_min;
    wire signed [X_WIDTH-1:0]  x_max;
    wire [LUT_AW-1:0]          iter_k;

    // The polyak averagers always consume samples as soon as readout_capture
    // presents them.  iq_ready is therefore tied high.
    assign rc_iq_ready = 1'b1;

    // -------------------------------------------------------------
    // adaptive_sweep_control
    // -------------------------------------------------------------
    adaptive_sweep_control #(
        .X_WIDTH    (X_WIDTH),
        .IQ_WIDTH   (IQ_WIDTH),
        .POW_WIDTH  (POW_WIDTH),
        .COUNT_WIDTH(COUNT_WIDTH),
        .LUT_AW     (LUT_AW)
    ) u_ctrl (
        .clk                  (clk),
        .rst_n                (rst_n),

        .qtag_en_i            (qtag_en_i),
        .qtag_op_i            (qtag_op_i),
        .qtag_dt1_i           (qtag_dt1_i),
        .qtag_dt2_i           (qtag_dt2_i),
        .qtag_dt3_i           (qtag_dt3_i),
        .qtag_dt4_i           (qtag_dt4_i),
        .qtag_rdy_o           (qtag_rdy_o),
        .qtag_dt1_o           (qtag_dt1_o),
        .qtag_dt2_o           (qtag_dt2_o),
        .qtag_vld_o           (qtag_vld_o),

        .pa_soft_reset        (pa_soft_reset),
        .pa_reciprocal        (pa_reciprocal),
        .pa_chunk_log2        (pa_chunk_log2),
        .pa_i_xbar            (pa_i_xbar),
        .pa_q_xbar            (pa_q_xbar),

        .pwr_compute_pulse    (pwr_compute_pulse),
        .pwr_i_in             (pwr_i_in),
        .pwr_q_in             (pwr_q_in),
        .pwr_value            (pwr_value),
        .pwr_valid            (pwr_valid),

        .kw_lut_we            (kw_lut_we),
        .kw_lut_addr          (kw_lut_addr),
        .kw_lut_din           (kw_lut_din),
        .kw_step_trigger      (kw_step_trigger),
        .kw_dp_signed         (kw_dp_signed),
        .kw_k_idx             (kw_k_idx),
        .kw_x_in              (kw_x_in),
        .kw_x_min             (kw_x_min),
        .kw_x_max             (kw_x_max),
        .kw_x_out             (kw_x_out),
        .kw_conv_flag         (kw_conv_flag),
        .kw_valid             (kw_valid),

        .bs_init              (bs_init),
        .bs_lo_init           (bs_lo_init),
        .bs_hi_init           (bs_hi_init),
        .bs_side_left         (bs_side_left),
        .bs_polarity_peak     (bs_polarity_peak),
        .bs_tol_in            (bs_tol_in),
        .bs_step              (bs_step),
        .bs_pow_mid           (bs_pow_mid),
        .bs_pow_thr           (bs_pow_thr),
        .bs_mid_next          (bs_mid_next),
        .bs_lo_o              (bs_lo_o),
        .bs_hi_o              (bs_hi_o),
        .bs_converged         (bs_converged),
        .bs_valid             (bs_valid),

        .rc_arm_pulse         (rc_arm_pulse),
        .rc_n_samples         (rc_n_samples),
        .rc_capture_done      (rc_capture_done),
        .rc_samples_remaining (rc_samples_remaining),

        .x_current_o          (x_current),
        .x_min_o              (x_min),
        .x_max_o              (x_max),
        .iter_k_o             (iter_k)
    );

    // -------------------------------------------------------------
    // readout_capture (ro_clk -> c_clk CDC, trigger gate)
    // -------------------------------------------------------------
    readout_capture #(
        .IQ_WIDTH       (IQ_WIDTH),
        .FIFO_DEPTH_LOG2(RO_FIFO_DEPTH_LOG2),
        .COUNT_WIDTH    (COUNT_WIDTH)
    ) u_rc (
        .clk               (clk),
        .rst_n             (rst_n),
        .arm_pulse         (rc_arm_pulse),
        .n_samples         (rc_n_samples),
        .capture_done_o    (rc_capture_done),
        .i_out             (rc_i_out),
        .q_out             (rc_q_out),
        .iq_valid          (rc_iq_valid),
        .iq_ready          (rc_iq_ready),
        .samples_remaining (rc_samples_remaining),

        .s_ro_axis_aclk    (s_ro_axis_aclk),
        .s_ro_axis_aresetn (s_ro_axis_aresetn),
        .s_ro_axis_tdata   (s_ro_axis_tdata),
        .s_ro_axis_tvalid  (s_ro_axis_tvalid),
        .s_ro_axis_tready  (s_ro_axis_tready),
        .trigger_i         (trigger_i)
    );

    // -------------------------------------------------------------
    // polyak_averager (I)
    // -------------------------------------------------------------
    polyak_averager #(
        .SAMPLE_WIDTH(IQ_WIDTH),
        .SUM_WIDTH   (SUM_WIDTH),
        .AVG_WIDTH   (X_WIDTH),
        .RECIP_WIDTH (32),
        .COUNT_WIDTH (COUNT_WIDTH)
    ) u_pa_i (
        .clk             (clk),
        .rst_n           (rst_n),
        .sample_in       (rc_i_out),
        .sample_valid    (rc_iq_valid),
        .reciprocal_in   (pa_reciprocal),
        .chunk_size_log2 (pa_chunk_log2),
        .soft_reset      (pa_soft_reset),
        .xbar_o          (pa_i_xbar),
        .xbar_delta_o    (),
        .count_o         (),
        .valid_o         ()
    );

    // -------------------------------------------------------------
    // polyak_averager (Q)
    // -------------------------------------------------------------
    polyak_averager #(
        .SAMPLE_WIDTH(IQ_WIDTH),
        .SUM_WIDTH   (SUM_WIDTH),
        .AVG_WIDTH   (X_WIDTH),
        .RECIP_WIDTH (32),
        .COUNT_WIDTH (COUNT_WIDTH)
    ) u_pa_q (
        .clk             (clk),
        .rst_n           (rst_n),
        .sample_in       (rc_q_out),
        .sample_valid    (rc_iq_valid),
        .reciprocal_in   (pa_reciprocal),
        .chunk_size_log2 (pa_chunk_log2),
        .soft_reset      (pa_soft_reset),
        .xbar_o          (pa_q_xbar),
        .xbar_delta_o    (),
        .count_o         (),
        .valid_o         ()
    );

    // -------------------------------------------------------------
    // iq_power : I_avg^2 + Q_avg^2 (one-shot, fired by control)
    // -------------------------------------------------------------
    iq_power #(
        .IQ_WIDTH (IQ_WIDTH),
        .POW_WIDTH(POW_WIDTH)
    ) u_iqp (
        .clk     (clk),
        .rst_n   (rst_n),
        .i_in    (pwr_i_in),
        .q_in    (pwr_q_in),
        .valid_in(pwr_compute_pulse),
        .power_o (pwr_value),
        .valid_o (pwr_valid)
    );

    // -------------------------------------------------------------
    // kw_steps : LUT-driven KW step + clamp
    // -------------------------------------------------------------
    kw_steps #(
        .X_WIDTH  (X_WIDTH),
        .LUT_DEPTH(LUT_DEPTH),
        .LUT_AW   (LUT_AW),
        .KW_TOL   (KW_TOL)
    ) u_kw (
        .clk         (clk),
        .rst_n       (rst_n),
        .lut_we      (kw_lut_we),
        .lut_addr    (kw_lut_addr),
        .lut_din     (kw_lut_din),
        .step_trigger(kw_step_trigger),
        .dp_signed   (kw_dp_signed),
        .k_idx       (kw_k_idx),
        .x_in        (kw_x_in),
        .x_min       (kw_x_min),
        .x_max       (kw_x_max),
        .x_out       (kw_x_out),
        .conv_flag   (kw_conv_flag),
        .valid_o     (kw_valid)
    );

    // -------------------------------------------------------------
    // bisect_control : 3 dB edge bisection
    // -------------------------------------------------------------
    bisect_control #(
        .X_WIDTH(X_WIDTH)
    ) u_bs (
        .clk          (clk),
        .rst_n        (rst_n),
        .init         (bs_init),
        .lo_init      (bs_lo_init),
        .hi_init      (bs_hi_init),
        .side_left    (bs_side_left),
        .polarity_peak(bs_polarity_peak),
        .tol_in       (bs_tol_in),
        .step         (bs_step),
        .pow_mid      (bs_pow_mid),
        .pow_thr      (bs_pow_thr),
        .mid_next     (bs_mid_next),
        .lo_o         (bs_lo_o),
        .hi_o         (bs_hi_o),
        .converged_o  (bs_converged),
        .valid_o      (bs_valid)
    );

endmodule
