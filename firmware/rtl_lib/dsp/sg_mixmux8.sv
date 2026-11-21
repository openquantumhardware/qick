`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : sg_mixmux8
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    sg_mixmux8.sv
//!
//! @brief   axis_sg_mixmux8_v1 datapath: 8 independently masked, summed
//!          complex (I/Q) DDS output waves.
//!
//! @details
//! Identical structure to sg_mux8, but each wave carries an independent I
//! and Q sample (dds_top_mixmux8 instead of dds_top_sgmux8) and the 3-stage
//! binary adder tree / popcount quantization is duplicated for both real
//! and imaginary channels. ctrl_sgmux8 (descriptor sequencer) and
//! fifo_sync (descriptor queue) are reused unchanged -- the legacy ctrl.sv
//! is byte-for-byte identical between mux8 and mixmux8, only the
//! DDS/adder-tree width doubles.
//!
//! Pipeline latency: same as sg_mux8 (4 cycles, mask FIFO pop ->
//! m_axis_tdata_o).
//!
//! @author  QICK Development Team
//!
//! @version 1.0
///////////////////////////////////////////////////////////////////////////////
module sg_mixmux8 #(
    parameter int N_DDS = 2  //! Number of interleaved parallel DDS lanes per wave.
)(
    // Reset and clock.
    input  logic                aresetn,
    input  logic                aclk,

    // S_AXIS to queue waveforms.
    output logic                 s_axis_tready_o,
    input  logic                 s_axis_tvalid_i,
    input  logic [39:0]          s_axis_tdata_i,

    // M_AXIS for output.
    input  logic                 m_axis_tready_i,
    output logic                 m_axis_tvalid_o,
    output logic [N_DDS*32-1:0]  m_axis_tdata_o,

    // Registers.
    input  logic [31:0] pinc0_reg,
    input  logic [31:0] pinc1_reg,
    input  logic [31:0] pinc2_reg,
    input  logic [31:0] pinc3_reg,
    input  logic [31:0] pinc4_reg,
    input  logic [31:0] pinc5_reg,
    input  logic [31:0] pinc6_reg,
    input  logic [31:0] pinc7_reg,
    input  logic [31:0] poff0_reg,
    input  logic [31:0] poff1_reg,
    input  logic [31:0] poff2_reg,
    input  logic [31:0] poff3_reg,
    input  logic [31:0] poff4_reg,
    input  logic [31:0] poff5_reg,
    input  logic [31:0] poff6_reg,
    input  logic [31:0] poff7_reg,
    input  logic [15:0] gain0_reg,
    input  logic [15:0] gain1_reg,
    input  logic [15:0] gain2_reg,
    input  logic [15:0] gain3_reg,
    input  logic [15:0] gain4_reg,
    input  logic [15:0] gain5_reg,
    input  logic [15:0] gain6_reg,
    input  logic [15:0] gain7_reg,
    input  logic         we_reg
);

    // Number of output waves.
    localparam int N_OUT = 8;

    // Fifo.
    logic        fifo_wr_en;
    logic [39:0] fifo_din;
    logic        fifo_rd_en;
    logic [39:0] fifo_dout;
    logic        fifo_full;
    logic        fifo_empty;

    // PINC/POFF/GAIN registers vector.
    logic [31:0] pinc_reg_v [N_OUT];
    logic [31:0] poff_reg_v [N_OUT];
    logic [15:0] gain_reg_v [N_OUT];

    // DDS output (dual I/Q per lane).
    logic [N_DDS*32-1:0] dds_dout    [N_OUT];
    logic [N_DDS*32-1:0] dds_dout_la [N_OUT];

    // Muxed DDS output.
    logic [N_DDS*32-1:0] dds_mux    [N_OUT];
    logic [31:0]         dds_mux_v  [N_OUT][N_DDS];
    logic [15:0]         dds_real_v [N_OUT][N_DDS];
    logic [15:0]         dds_imag_v [N_OUT][N_DDS];

    // Addition vectors (real).
    logic signed [15:0] add0_real [N_DDS];
    logic signed [15:0] add1_real [N_DDS];
    logic signed [15:0] add2_real [N_DDS];
    logic signed [15:0] add3_real [N_DDS];
    logic signed [15:0] add4_real [N_DDS];
    logic signed [15:0] add5_real [N_DDS];
    logic signed [15:0] add6_real [N_DDS];
    logic signed [15:0] add7_real [N_DDS];
    logic signed [18:0] add0_real_r [N_DDS];
    logic signed [18:0] add1_real_r [N_DDS];
    logic signed [18:0] add2_real_r [N_DDS];
    logic signed [18:0] add3_real_r [N_DDS];
    logic signed [18:0] add4_real_r [N_DDS];
    logic signed [18:0] add5_real_r [N_DDS];
    logic signed [18:0] add6_real_r [N_DDS];
    logic signed [18:0] add7_real_r [N_DDS];

    // Addition vectors (imag).
    logic signed [15:0] add0_imag [N_DDS];
    logic signed [15:0] add1_imag [N_DDS];
    logic signed [15:0] add2_imag [N_DDS];
    logic signed [15:0] add3_imag [N_DDS];
    logic signed [15:0] add4_imag [N_DDS];
    logic signed [15:0] add5_imag [N_DDS];
    logic signed [15:0] add6_imag [N_DDS];
    logic signed [15:0] add7_imag [N_DDS];
    logic signed [18:0] add0_imag_r [N_DDS];
    logic signed [18:0] add1_imag_r [N_DDS];
    logic signed [18:0] add2_imag_r [N_DDS];
    logic signed [18:0] add3_imag_r [N_DDS];
    logic signed [18:0] add4_imag_r [N_DDS];
    logic signed [18:0] add5_imag_r [N_DDS];
    logic signed [18:0] add6_imag_r [N_DDS];
    logic signed [18:0] add7_imag_r [N_DDS];

    // Addition results (real).
    logic signed [18:0] sum0_real [N_DDS];
    logic signed [18:0] sum1_real [N_DDS];
    logic signed [18:0] sum2_real [N_DDS];
    logic signed [18:0] sum3_real [N_DDS];
    logic signed [18:0] sum4_real [N_DDS];
    logic signed [18:0] sum5_real [N_DDS];
    logic signed [18:0] sum6_real [N_DDS];
    logic signed [18:0] sum0_real_r [N_DDS];
    logic signed [18:0] sum1_real_r [N_DDS];
    logic signed [18:0] sum2_real_r [N_DDS];
    logic signed [18:0] sum3_real_r [N_DDS];
    logic signed [18:0] sum4_real_r [N_DDS];
    logic signed [18:0] sum5_real_r [N_DDS];
    logic signed [18:0] sum6_real_r [N_DDS];

    // Addition results (imag).
    logic signed [18:0] sum0_imag [N_DDS];
    logic signed [18:0] sum1_imag [N_DDS];
    logic signed [18:0] sum2_imag [N_DDS];
    logic signed [18:0] sum3_imag [N_DDS];
    logic signed [18:0] sum4_imag [N_DDS];
    logic signed [18:0] sum5_imag [N_DDS];
    logic signed [18:0] sum6_imag [N_DDS];
    logic signed [18:0] sum0_imag_r [N_DDS];
    logic signed [18:0] sum1_imag_r [N_DDS];
    logic signed [18:0] sum2_imag_r [N_DDS];
    logic signed [18:0] sum3_imag_r [N_DDS];
    logic signed [18:0] sum4_imag_r [N_DDS];
    logic signed [18:0] sum5_imag_r [N_DDS];
    logic signed [18:0] sum6_imag_r [N_DDS];

    // Quantized output.
    logic [15:0] dout_real [N_DDS];
    logic [15:0] dout_imag [N_DDS];

    // Mask.
    logic [7:0] mask_int;

    // Output enable.
    logic en_int;
    logic en_int_la;

    // Output selection quantization.
    // NOTE (legacy): change this if N_OUT changes.
    logic [3:0] qsel;
    logic [3:0] qsel_la;

    // PINC/POFF/GAIN registers vectors.
    assign pinc_reg_v[0] = pinc0_reg;
    assign pinc_reg_v[1] = pinc1_reg;
    assign pinc_reg_v[2] = pinc2_reg;
    assign pinc_reg_v[3] = pinc3_reg;
    assign pinc_reg_v[4] = pinc4_reg;
    assign pinc_reg_v[5] = pinc5_reg;
    assign pinc_reg_v[6] = pinc6_reg;
    assign pinc_reg_v[7] = pinc7_reg;
    assign poff_reg_v[0] = poff0_reg;
    assign poff_reg_v[1] = poff1_reg;
    assign poff_reg_v[2] = poff2_reg;
    assign poff_reg_v[3] = poff3_reg;
    assign poff_reg_v[4] = poff4_reg;
    assign poff_reg_v[5] = poff5_reg;
    assign poff_reg_v[6] = poff6_reg;
    assign poff_reg_v[7] = poff7_reg;
    assign gain_reg_v[0] = gain0_reg;
    assign gain_reg_v[1] = gain1_reg;
    assign gain_reg_v[2] = gain2_reg;
    assign gain_reg_v[3] = gain3_reg;
    assign gain_reg_v[4] = gain4_reg;
    assign gain_reg_v[5] = gain5_reg;
    assign gain_reg_v[6] = gain6_reg;
    assign gain_reg_v[7] = gain7_reg;

    // Fifo.
    fifo_sync #(
        .B         (40),
        .N         (16),
        // legacy FIFO semantics: the ctrl latches the descriptor one cycle
        // after rd_en (see fifo_sync header)
        .HOLD_DOUT (1'b1)
    ) fifo_i (
        .rstn (aresetn),
        .clk  (aclk),

        .wr_en (fifo_wr_en),
        .din   (fifo_din),

        .rd_en (fifo_rd_en),
        .dout  (fifo_dout),

        .full  (fifo_full),
        .empty (fifo_empty),

        .wr_data_count (),
        .rd_data_count (),
        .prog_full     (),
        .prog_empty    ()
    );

    assign fifo_wr_en = s_axis_tvalid_i;
    assign fifo_din   = s_axis_tdata_i;

    for (genvar i = 0; i < N_OUT; i = i + 1) begin : g_out
        // DDS (dual I/Q).
        dds_top_mixmux8 #(
            .N_DDS (N_DDS)
        ) dds_top_i (
            .rstn       (aresetn),
            .clk        (aclk),
            .dds_dout_o (dds_dout[i]),
            .pinc_reg   (pinc_reg_v[i]),
            .poff_reg   (poff_reg_v[i]),
            .gain_reg   (gain_reg_v[i]),
            .we_reg     (we_reg)
        );

        // Latency for dds_dout.
        delay_line #(
            .N (4),
            .M (N_DDS*32)
        ) dds_dout_delay_i (
            .i_clk  (aclk),
            .i_rstn (aresetn),
            .i_data (dds_dout[i]),
            .o_data (dds_dout_la[i])
        );

        // Muxed DDS output.
        assign dds_mux[i] = (mask_int[i] == 1'b1) ? dds_dout_la[i] : '0;

        for (genvar j = 0; j < N_DDS; j = j + 1) begin : g_out_dds
            assign dds_mux_v[i][j]  = dds_mux[i][32*j+:32];
            assign dds_real_v[i][j] = dds_mux_v[i][j][15:0];
            assign dds_imag_v[i][j] = dds_mux_v[i][j][31:16];
        end
    end

    for (genvar i = 0; i < N_DDS; i = i + 1) begin : g_add
        always_ff @(posedge aclk) begin
            if (!aresetn) begin
                add0_real_r[i] <= '0;
                add1_real_r[i] <= '0;
                add2_real_r[i] <= '0;
                add3_real_r[i] <= '0;
                add4_real_r[i] <= '0;
                add5_real_r[i] <= '0;
                add6_real_r[i] <= '0;
                add7_real_r[i] <= '0;
                sum0_real_r[i] <= '0;
                sum1_real_r[i] <= '0;
                sum2_real_r[i] <= '0;
                sum3_real_r[i] <= '0;
                sum4_real_r[i] <= '0;
                sum5_real_r[i] <= '0;
                sum6_real_r[i] <= '0;
                add0_imag_r[i] <= '0;
                add1_imag_r[i] <= '0;
                add2_imag_r[i] <= '0;
                add3_imag_r[i] <= '0;
                add4_imag_r[i] <= '0;
                add5_imag_r[i] <= '0;
                add6_imag_r[i] <= '0;
                add7_imag_r[i] <= '0;
                sum0_imag_r[i] <= '0;
                sum1_imag_r[i] <= '0;
                sum2_imag_r[i] <= '0;
                sum3_imag_r[i] <= '0;
                sum4_imag_r[i] <= '0;
                sum5_imag_r[i] <= '0;
                sum6_imag_r[i] <= '0;
            end else begin
                // Addition vectors (real).
                add0_real_r[i] <= {{3{add0_real[i][15]}}, add0_real[i]};
                add1_real_r[i] <= {{3{add1_real[i][15]}}, add1_real[i]};
                add2_real_r[i] <= {{3{add2_real[i][15]}}, add2_real[i]};
                add3_real_r[i] <= {{3{add3_real[i][15]}}, add3_real[i]};
                add4_real_r[i] <= {{3{add4_real[i][15]}}, add4_real[i]};
                add5_real_r[i] <= {{3{add5_real[i][15]}}, add5_real[i]};
                add6_real_r[i] <= {{3{add6_real[i][15]}}, add6_real[i]};
                add7_real_r[i] <= {{3{add7_real[i][15]}}, add7_real[i]};

                // Addition results (real).
                sum0_real_r[i] <= sum0_real[i];
                sum1_real_r[i] <= sum1_real[i];
                sum2_real_r[i] <= sum2_real[i];
                sum3_real_r[i] <= sum3_real[i];
                sum4_real_r[i] <= sum4_real[i];
                sum5_real_r[i] <= sum5_real[i];
                sum6_real_r[i] <= sum6_real[i];

                // Addition vectors (imag).
                add0_imag_r[i] <= {{3{add0_imag[i][15]}}, add0_imag[i]};
                add1_imag_r[i] <= {{3{add1_imag[i][15]}}, add1_imag[i]};
                add2_imag_r[i] <= {{3{add2_imag[i][15]}}, add2_imag[i]};
                add3_imag_r[i] <= {{3{add3_imag[i][15]}}, add3_imag[i]};
                add4_imag_r[i] <= {{3{add4_imag[i][15]}}, add4_imag[i]};
                add5_imag_r[i] <= {{3{add5_imag[i][15]}}, add5_imag[i]};
                add6_imag_r[i] <= {{3{add6_imag[i][15]}}, add6_imag[i]};
                add7_imag_r[i] <= {{3{add7_imag[i][15]}}, add7_imag[i]};

                // Addition results (imag).
                sum0_imag_r[i] <= sum0_imag[i];
                sum1_imag_r[i] <= sum1_imag[i];
                sum2_imag_r[i] <= sum2_imag[i];
                sum3_imag_r[i] <= sum3_imag[i];
                sum4_imag_r[i] <= sum4_imag[i];
                sum5_imag_r[i] <= sum5_imag[i];
                sum6_imag_r[i] <= sum6_imag[i];
            end
        end

        // Addition vectors (real).
        assign add0_real[i] = dds_real_v[0][i];
        assign add1_real[i] = dds_real_v[1][i];
        assign add2_real[i] = dds_real_v[2][i];
        assign add3_real[i] = dds_real_v[3][i];
        assign add4_real[i] = dds_real_v[4][i];
        assign add5_real[i] = dds_real_v[5][i];
        assign add6_real[i] = dds_real_v[6][i];
        assign add7_real[i] = dds_real_v[7][i];

        // Addition results (real).
        assign sum0_real[i] = add0_real_r[i] + add1_real_r[i];
        assign sum1_real[i] = add2_real_r[i] + add3_real_r[i];
        assign sum2_real[i] = add4_real_r[i] + add5_real_r[i];
        assign sum3_real[i] = add6_real_r[i] + add7_real_r[i];
        assign sum4_real[i] = sum0_real_r[i] + sum1_real_r[i];
        assign sum5_real[i] = sum2_real_r[i] + sum3_real_r[i];
        assign sum6_real[i] = sum4_real_r[i] + sum5_real_r[i];

        // Addition vectors (imag).
        assign add0_imag[i] = dds_imag_v[0][i];
        assign add1_imag[i] = dds_imag_v[1][i];
        assign add2_imag[i] = dds_imag_v[2][i];
        assign add3_imag[i] = dds_imag_v[3][i];
        assign add4_imag[i] = dds_imag_v[4][i];
        assign add5_imag[i] = dds_imag_v[5][i];
        assign add6_imag[i] = dds_imag_v[6][i];
        assign add7_imag[i] = dds_imag_v[7][i];

        // Addition results (imag).
        assign sum0_imag[i] = add0_imag_r[i] + add1_imag_r[i];
        assign sum1_imag[i] = add2_imag_r[i] + add3_imag_r[i];
        assign sum2_imag[i] = add4_imag_r[i] + add5_imag_r[i];
        assign sum3_imag[i] = add6_imag_r[i] + add7_imag_r[i];
        assign sum4_imag[i] = sum0_imag_r[i] + sum1_imag_r[i];
        assign sum5_imag[i] = sum2_imag_r[i] + sum3_imag_r[i];
        assign sum6_imag[i] = sum4_imag_r[i] + sum5_imag_r[i];

        // Quantized output: 0, 5, 6, 7 and 8 have the same quantization.
        assign dout_real[i] = (qsel_la == 1) ? sum6_real_r[i][15:0] :
                               (qsel_la == 2) ? sum6_real_r[i][16:1] :
                               (qsel_la == 3) ? sum6_real_r[i][17:2] :
                               (qsel_la == 4) ? sum6_real_r[i][17:2] :
                               sum6_real_r[i][18:3];

        assign dout_imag[i] = (qsel_la == 1) ? sum6_imag_r[i][15:0] :
                               (qsel_la == 2) ? sum6_imag_r[i][16:1] :
                               (qsel_la == 3) ? sum6_imag_r[i][17:2] :
                               (qsel_la == 4) ? sum6_imag_r[i][17:2] :
                               sum6_imag_r[i][18:3];

        // Outputs.
        assign m_axis_tdata_o[i*32+:32] = (en_int_la == 1'b1) ? {dout_imag[i], dout_real[i]} : 32'h0000_0000;
    end

    // Control block (identical to sg_mux8's -- legacy ctrl.sv is
    // byte-for-byte identical between mux8 and mixmux8).
    ctrl_sgmux8 ctrl_i (
        .rstn         (aresetn),
        .clk          (aclk),

        .fifo_rd_en_o (fifo_rd_en),
        .fifo_empty_i (fifo_empty),
        .fifo_dout_i  (fifo_dout),

        .mask_o (mask_int),
        .en_o   (en_int)
    );

    // Latency en_int.
    delay_line #(
        .N (4),
        .M (1)
    ) en_int_delay_i (
        .i_clk  (aclk),
        .i_rstn (aresetn),
        .i_data (en_int),
        .o_data (en_int_la)
    );

    // Latency qsel.
    delay_line #(
        .N (4),
        .M (4)
    ) qsel_delay_i (
        .i_clk  (aclk),
        .i_rstn (aresetn),
        .i_data (qsel),
        .o_data (qsel_la)
    );

    // Output selection quantization.
    assign qsel = 4'(mask_int[0]) + 4'(mask_int[1]) + 4'(mask_int[2]) + 4'(mask_int[3]) +
                  4'(mask_int[4]) + 4'(mask_int[5]) + 4'(mask_int[6]) + 4'(mask_int[7]);

    // Assign outputs.
    assign s_axis_tready_o = ~fifo_full;
    assign m_axis_tvalid_o = en_int_la;

endmodule
