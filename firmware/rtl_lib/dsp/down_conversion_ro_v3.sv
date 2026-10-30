`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : down_conversion_ro_v3
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    down_conversion_ro_v3.sv
//!
//! @brief   Digital down-conversion (real ADC sample x complex DDS) for
//!          axis_readout_v3.
//!
//! @details
//! Faithful port of axis_readout_v3's down_conversion.sv. Reuses
//! ctrl_dyn_ro UNCHANGED (diffing the legacy ctrl.sv files shows it is
//! byte-for-byte identical to ctrl_dyn_ro_v1.sv apart from an `en` output
//! that -- per this file's own legacy comment "Always on output (not using
//! en like in signal_gen_v6)" -- is computed but never actually consumed
//! anywhere downstream in this IP either, so it is simply left
//! unconnected here, same as ctrl_dyn_ro's existing dyn_readout_v1 caller).
//!
//! Differs from down_conversion_dynro/down_conversion_ro_v2 in real,
//! behavior-relevant ways (not just cosmetics):
//!
//! - Product quantization TRUNCATES (bits [30:15], no +0.5 rounding
//!   constant), where the other two down-conversion variants round to
//!   nearest.
//! - Deeper/different alignment pipeline: input-sample delay is 12 cycles
//!   (not 4), DDS-product delay is 1 cycle, plus separate 2/3-cycle mux
//!   delay stages for the outsel-2 (raw input) and outsel-1 (DDS-only)
//!   paths -- outsel itself is delayed 15 cycles via its own delay_line
//!   (the other variants use outsel/en straight from ctrl_dyn_ro's own
//!   7-stage pipeline with no additional delay_line).
//!
//! No FIFO/decimation here -- feeds into fir_decim4_ro_v3 for the
//! decimated (single) output.
//!
//! s_axis_tready / m_axis_tvalid are both tied high (continuous streaming,
//! no backpressure), matching the legacy exactly.
//!
//! @author  QICK Development Team
//!
//! @version 1.0
///////////////////////////////////////////////////////////////////////////////
module down_conversion_ro_v3 #(
    parameter int N = 4  //! Number of parallel demodulator lanes (fixed by the FIR: 4).
)(
    // Reset and clock.
    input  logic              aresetn,
    input  logic              aclk,

    // Fifo interface.
    output logic               fifo_rd_en,
    input  logic                fifo_empty,
    input  logic [87:0]         fifo_dout,

    // s_axis for input data (N samples per clock).
    output logic               s_axis_tready,
    input  logic                s_axis_tvalid,
    input  logic [N*16-1:0]     s_axis_tdata,

    // m_axis for output data.
    input  logic               m_axis_tready,
    output logic                m_axis_tvalid,
    output logic [N*32-1:0]     m_axis_tdata
);

    // Input data.
    logic [15:0] din_real_r1 [N];
    logic [15:0] din_real_la [N];
    logic [15:0] din_la_mux  [N];

    // DDS input control.
    logic              dds_tvalid_r;
    logic [N*72-1:0]   dds_ctrl_int;
    logic [N*72-1:0]   dds_ctrl_int_r;

    // DDS output.
    logic [31:0] dds_dout    [N];
    logic [31:0] dds_dout_r1 [N];
    logic [31:0] dds_dout_la [N];
    logic [31:0] dds_la_mux  [N];

    // Product.
    logic signed [15:0] prod_a_real       [N];
    logic signed [15:0] prod_b_real       [N];
    logic signed [15:0] prod_b_imag       [N];
    logic signed [31:0] prod_y_real       [N];
    logic signed [31:0] prod_y_imag       [N];
    logic signed [15:0] prod_y_real_round [N];
    logic signed [15:0] prod_y_imag_round [N];
    logic        [31:0] prod_y            [N];
    logic        [31:0] prod_y_r1         [N];
    logic        [31:0] prod_y_r2         [N];

    // Muxed output.
    logic [31:0] dout_mux    [N];
    logic [31:0] dout_mux_r1 [N];

    // Output source selection.
    logic [1:0] outsel_int;
    logic [1:0] outsel_la;

    // Control block (reused unchanged from axis_dyn_readout_v1).
    ctrl_dyn_ro #(
        .N (N)
    ) ctrl_i (
        .aresetn    (aresetn),
        .aclk       (aclk),
        .fifo_rd_en (fifo_rd_en),
        .fifo_empty (fifo_empty),
        .fifo_dout  (fifo_dout),
        .dds_ctrl   (dds_ctrl_int),
        .outsel     (outsel_int)
    );

    for (genvar i = 0; i < N; i = i + 1) begin : g_dds
        // DDS. Latency: 10.
        dds_compiler_dyn_readout dds_i (
            .aclk                (aclk),
            .s_axis_phase_tvalid (dds_tvalid_r),
            .s_axis_phase_tdata  (dds_ctrl_int_r[i*72+:72]),
            .m_axis_data_tvalid  (),
            .m_axis_data_tdata   (dds_dout[i])
        );

        // Latency for input data (product).
        delay_line #(.N(12), .M(16)) din_delay_i (
            .i_clk (aclk), .i_rstn (aresetn), .i_data (din_real_r1[i]), .o_data (din_real_la[i])
        );

        // Latency for dds_dout (product).
        delay_line #(.N(1), .M(32)) dds_dout_delay_i (
            .i_clk (aclk), .i_rstn (aresetn), .i_data (dds_dout_r1[i]), .o_data (dds_dout_la[i])
        );

        // Latency for input data (mux).
        delay_line #(.N(2), .M(16)) din_mux_delay_i (
            .i_clk (aclk), .i_rstn (aresetn), .i_data (din_real_la[i]), .o_data (din_la_mux[i])
        );

        // Latency for dds_dout (mux).
        delay_line #(.N(3), .M(32)) dds_mux_delay_i (
            .i_clk (aclk), .i_rstn (aresetn), .i_data (dds_dout_la[i]), .o_data (dds_la_mux[i])
        );

        always_ff @(posedge aclk) begin
            if (!aresetn) begin
                din_real_r1[i] <= '0;
                dds_dout_r1[i] <= '0;
                prod_y_r1[i]   <= '0;
                prod_y_r2[i]   <= '0;
                dout_mux_r1[i] <= '0;
            end else begin
                // Input data.
                din_real_r1[i] <= s_axis_tdata[i*16+:16];

                // DDS output.
                dds_dout_r1[i] <= dds_dout[i];

                // Product.
                prod_y_r1[i] <= prod_y[i];
                prod_y_r2[i] <= prod_y_r1[i];

                // Muxed output.
                dout_mux_r1[i] <= dout_mux[i];
            end
        end

        // Product (legacy: truncate, no rounding constant).
        assign prod_a_real[i] = din_real_la[i];
        assign prod_b_real[i] = dds_dout_la[i][15:0];
        assign prod_b_imag[i] = dds_dout_la[i][31:16];
        assign prod_y_real[i] = prod_a_real[i] * prod_b_real[i];
        assign prod_y_imag[i] = prod_a_real[i] * prod_b_imag[i];
        assign prod_y_real_round[i] = prod_y_real[i][30-:16];
        assign prod_y_imag_round[i] = prod_y_imag[i][30-:16];
        assign prod_y[i] = {prod_y_imag_round[i], prod_y_real_round[i]};

        // Muxed output.
        assign dout_mux[i] = (outsel_la == 2'd0) ? prod_y_r2[i] :
                              (outsel_la == 2'd1) ? dds_la_mux[i] :
                              (outsel_la == 2'd2) ? din_la_mux[i] :
                              32'h0000_0000;

        // Outputs (always on, not gated by en -- matches legacy comment).
        assign m_axis_tdata[i*32+:32] = dout_mux_r1[i];
    end

    // Latency for source selection.
    delay_line #(.N(15), .M(2)) outsel_delay_i (
        .i_clk (aclk), .i_rstn (aresetn), .i_data (outsel_int), .o_data (outsel_la)
    );

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            dds_tvalid_r   <= 1'b0;
            dds_ctrl_int_r <= '0;
        end else begin
            dds_tvalid_r   <= 1'b1;
            dds_ctrl_int_r <= dds_ctrl_int;
        end
    end

    // Outputs.
    assign s_axis_tready = 1'b1;
    assign m_axis_tvalid = 1'b1;

endmodule
