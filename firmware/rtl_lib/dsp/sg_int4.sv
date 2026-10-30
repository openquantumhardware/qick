`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : sg_int4
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    sg_int4.sv
//!
//! @brief   Arbitrary signal generator datapath for axis_sg_int4_v2
//!          (single-word envelope memory, interpolated x4 by a FIR).
//!
//! @details
//! Faithful port of the legacy signal_gen.v: unlike sgv4/sgv6 (N_DDS
//! parallel envelope banks read directly), int4 stores ONE envelope sample
//! per address and reconstructs N_DDS=4 interpolated samples per cycle via
//! fir_interp4_sgint. ctrl_sgv4 is reused UNCHANGED -- it is already a
//! faithful port of this exact IP's ctrl.sv (confirmed by its phrst_int/
//! 7-stage sync_reg pipeline, which only int4's ctrl.sv has), so every
//! delay_line length below is carried over unchanged from the legacy
//! src_latency_reg/gain_latency_reg/stdy_latency_reg/en_latency_reg depths.
//!
//! NOTE (deviation tracking): sgv4/sgv6 received a documented fix in an
//! earlier pass (product quantized at [30:15] instead of [31:16], plus
//! +/-MAXV saturation). That fix has NOT been applied here -- this port
//! preserves int4_v2's original (legacy, unfixed) [31:16] quantization and
//! has no saturation logic, matching the real deployed firmware exactly.
//! Applying the same family-wide fix to int4 is a candidate follow-up, not
//! done here since it wasn't part of what this port needed to be faithful.
//!
//! Output source select (src, from ctrl_sgv4.o_src): 0=DDS x envelope
//! product, 1=DDS only, 2=envelope only, 3=zero.
//!
//! @author  QICK Development Team
//!
//! @version 1.0
///////////////////////////////////////////////////////////////////////////////
module sg_int4 #(
    parameter int N     = 16,  //! Envelope-memory address width (depth 2**N).
    parameter int N_DDS = 4    //! Number of interpolated lanes (fixed by the FIR: x4).
)(
    // Reset and clock.
    input  logic          rstn,
    input  logic          clk,

    // Fifo interface.
    output logic          fifo_rd_en_o,
    input  logic          fifo_empty_i,
    input  logic [159:0]  fifo_dout_i,

    // Memory interface (single word per address).
    output logic [N-1:0]  mem_addr_o,
    input  logic [15:0]   mem_dout_real_i,
    input  logic [15:0]   mem_dout_imag_i,

    // M_AXIS for output.
    input  logic                 m_axis_tready_i,
    output logic                 m_axis_tvalid_o,
    output logic [N_DDS*32-1:0]  m_axis_tdata_o
);

    // Memory address.
    logic [N-1:0] mem_addr_int;
    logic [N-1:0] mem_addr_int_r;

    // DDS input control.
    logic                dds_tvalid_r;
    logic [N_DDS*72-1:0] dds_ctrl_int;
    logic [N_DDS*72-1:0] dds_ctrl_int_r;

    // DDS output.
    logic [31:0] dds_dout        [N_DDS];
    logic [31:0] dds_dout_r1     [N_DDS];
    logic [31:0] dds_dout_la     [N_DDS];
    logic [31:0] dds_dout_la_mux [N_DDS];

    // Memory data.
    logic [15:0]  mem_real_r1;
    logic [15:0]  mem_imag_r1;
    logic [31:0]  env_din;

    // Interpolated memory data: FIR outputs 4 I/Q samples in parallel.
    logic         env_valid;
    logic [127:0] env_dout;
    logic [15:0]  env_real_v [N_DDS];
    logic [15:0]  env_imag_v [N_DDS];
    logic [15:0]  env_real_r1 [N_DDS];
    logic [15:0]  env_imag_r1 [N_DDS];
    logic [15:0]  env_real_la [N_DDS];
    logic [15:0]  env_imag_la [N_DDS];

    // Product.
    logic signed [15:0] prod_a_real           [N_DDS];
    logic signed [15:0] prod_a_imag           [N_DDS];
    logic signed [15:0] prod_b_real           [N_DDS];
    logic signed [15:0] prod_b_imag           [N_DDS];
    logic signed [31:0] prod_y_full_real_a    [N_DDS];
    logic signed [31:0] prod_y_full_real_b    [N_DDS];
    logic signed [31:0] prod_y_full_real_a_r  [N_DDS];
    logic signed [31:0] prod_y_full_real_b_r  [N_DDS];
    logic signed [31:0] prod_y_full_imag_a    [N_DDS];
    logic signed [31:0] prod_y_full_imag_b    [N_DDS];
    logic signed [31:0] prod_y_full_imag_a_r  [N_DDS];
    logic signed [31:0] prod_y_full_imag_b_r  [N_DDS];
    logic signed [31:0] prod_y_full_real      [N_DDS];
    logic signed [31:0] prod_y_full_imag      [N_DDS];
    logic        [15:0] prod_y_real           [N_DDS];
    logic        [15:0] prod_y_imag           [N_DDS];
    logic        [31:0] prod_y                [N_DDS];
    logic        [31:0] prod_y_r1             [N_DDS];

    // Muxed output.
    logic [31:0] dout_mux    [N_DDS];
    logic [31:0] dout_mux_r1 [N_DDS];

    // Product with gain.
    logic        [15:0] gain_int;
    logic signed [15:0] gain_la;
    logic signed [15:0] prodg_a_real        [N_DDS];
    logic signed [15:0] prodg_a_imag        [N_DDS];
    logic signed [31:0] prodg_y_full_real   [N_DDS];
    logic signed [31:0] prodg_y_full_imag   [N_DDS];
    logic signed [31:0] prodg_y_full_real_r [N_DDS];
    logic signed [31:0] prodg_y_full_imag_r [N_DDS];

    // Rounding.
    logic [15:0] round_real [N_DDS];
    logic [15:0] round_imag [N_DDS];
    logic [31:0] round      [N_DDS];
    logic [31:0] round_r    [N_DDS];

    // Last sample register.
    logic [31:0] last_r [N_DDS];

    // Output source selection.
    logic [1:0] src_int;
    logic [1:0] src_fir;
    logic [1:0] src_la;

    // Steady value selection.
    logic stdy_int;
    logic stdy_la;

    // Output enable.
    logic en_int;
    logic en_la;
    logic en_la_r;

    // --------------------------------------------------------------------------
    // Control block (shared with axis_signal_gen_v4: ctrl_sgv4 is already a
    // faithful port of THIS IP's ctrl.sv -- phrst/7-stage sync_reg pipeline).
    // --------------------------------------------------------------------------
    ctrl_sgv4 #(
        .N     (N),
        .N_DDS (N_DDS)
    ) ctrl_i (
        .i_rstn       (rstn),
        .i_clk        (clk),
        .o_fifo_rd_en (fifo_rd_en_o),
        .i_fifo_empty (fifo_empty_i),
        .i_fifo_dout  (fifo_dout_i),
        .o_dds_ctrl   (dds_ctrl_int),
        .o_mem_addr   (mem_addr_int),
        .o_gain       (gain_int),
        .o_src        (src_int),
        .o_stdy       (stdy_int),
        .o_en         (en_int),
        .o_iqsel      ()
    );

    // --------------------------------------------------------------------------
    // Interpolation (FIR x4).
    // --------------------------------------------------------------------------
    fir_interp4_sgint fir_i (
        .aclk               (clk),
        .s_axis_data_tvalid (1'b1),
        .s_axis_data_tready (),
        .s_axis_data_tdata  (env_din),
        .m_axis_data_tvalid (env_valid),
        .m_axis_data_tdata  (env_dout)
    );

    for (genvar i = 0; i < N_DDS; i = i + 1) begin : g_dds
        // DDS. Latency: 8 (behavioural model; legacy comment says 10).
        dds_compiler_dyn_readout dds_i (
            .aclk                (clk),
            .s_axis_phase_tvalid (dds_tvalid_r),
            .s_axis_phase_tdata  (dds_ctrl_int_r[i*72+:72]),
            .m_axis_data_tvalid  (),
            .m_axis_data_tdata   (dds_dout[i])
        );

        // Latency for dds_dout (product).
        delay_line #(.N(4), .M(32)) dds_dout_delay_i (
            .i_clk  (clk), .i_rstn (rstn), .i_data (dds_dout_r1[i]), .o_data (dds_dout_la[i])
        );

        // Latency for dds_dout (mux).
        delay_line #(.N(2), .M(32)) dds_dout_mux_delay_i (
            .i_clk  (clk), .i_rstn (rstn), .i_data (dds_dout_la[i]), .o_data (dds_dout_la_mux[i])
        );

        // Latency for real envelope (mux).
        delay_line #(.N(2), .M(16)) env_real_delay_i (
            .i_clk  (clk), .i_rstn (rstn), .i_data (env_real_r1[i]), .o_data (env_real_la[i])
        );

        // Latency for imag envelope (mux).
        delay_line #(.N(2), .M(16)) env_imag_delay_i (
            .i_clk  (clk), .i_rstn (rstn), .i_data (env_imag_r1[i]), .o_data (env_imag_la[i])
        );

        always_ff @(posedge clk) begin
            if (!rstn) begin
                dds_dout_r1[i]           <= '0;
                env_real_r1[i]           <= '0;
                env_imag_r1[i]           <= '0;
                prod_y_full_real_a_r[i]  <= '0;
                prod_y_full_real_b_r[i]  <= '0;
                prod_y_full_imag_a_r[i]  <= '0;
                prod_y_full_imag_b_r[i]  <= '0;
                prod_y_r1[i]             <= '0;
                dout_mux_r1[i]           <= '0;
                prodg_y_full_real_r[i]   <= '0;
                prodg_y_full_imag_r[i]   <= '0;
                round_r[i]               <= '0;
                last_r[i]                <= '0;
            end else begin
                // DDS output.
                dds_dout_r1[i] <= dds_dout[i];

                // Interpolated memory data (legacy: drop the FIR's sign bit,
                // shift the remaining 15 bits left by 1 -- see fir_interp4_sgint's
                // header for the normalization this compensates).
                env_real_r1[i] <= {env_real_v[i][14:0], 1'b0};
                env_imag_r1[i] <= {env_imag_v[i][14:0], 1'b0};

                // Product.
                prod_y_full_real_a_r[i] <= {prod_y_full_real_a[i][30], prod_y_full_real_a[i][30-:31]};
                prod_y_full_real_b_r[i] <= {prod_y_full_real_b[i][30], prod_y_full_real_b[i][30-:31]};
                prod_y_full_imag_a_r[i] <= {prod_y_full_imag_a[i][30], prod_y_full_imag_a[i][30-:31]};
                prod_y_full_imag_b_r[i] <= {prod_y_full_imag_b[i][30], prod_y_full_imag_b[i][30-:31]};
                prod_y_r1[i] <= prod_y[i];

                // Muxed output.
                dout_mux_r1[i] <= dout_mux[i];

                // Product with gain.
                prodg_y_full_real_r[i] <= prodg_y_full_real[i];
                prodg_y_full_imag_r[i] <= prodg_y_full_imag[i];

                // Rounding.
                round_r[i] <= round[i];

                // Last sample register.
                if (en_la)
                    last_r[i] <= round[N_DDS-1];
            end
        end

        // Interpolated memory data.
        assign env_real_v[i] = env_dout[i*32+:16];
        assign env_imag_v[i] = env_dout[i*32+16+:16];

        // Product.
        assign prod_a_real[i] = dds_dout_la[i][15:0];
        assign prod_a_imag[i] = dds_dout_la[i][31:16];
        assign prod_b_real[i] = env_real_r1[i];
        assign prod_b_imag[i] = env_imag_r1[i];

        // Partial products.
        assign prod_y_full_real_a[i] = prod_a_real[i] * prod_b_real[i];
        assign prod_y_full_real_b[i] = prod_a_imag[i] * prod_b_imag[i];
        assign prod_y_full_imag_a[i] = prod_a_real[i] * prod_b_imag[i];
        assign prod_y_full_imag_b[i] = prod_a_imag[i] * prod_b_real[i];

        // Complex product: (I_dds*I_env - Q_dds*Q_env) + j(I_dds*Q_env + Q_dds*I_env)
        assign prod_y_full_real[i] = prod_y_full_real_a_r[i] - prod_y_full_real_b_r[i];
        assign prod_y_full_imag[i] = prod_y_full_imag_a_r[i] + prod_y_full_imag_b_r[i];

        // Quantization (legacy, unfixed: [31:16]).
        assign prod_y_real[i] = prod_y_full_real[i][31:16];
        assign prod_y_imag[i] = prod_y_full_imag[i][31:16];
        assign prod_y[i]      = {prod_y_imag[i], prod_y_real[i]};

        // Muxed output.
        assign dout_mux[i] = (src_la == 2'd0) ? prod_y_r1[i] :
                              (src_la == 2'd1) ? dds_dout_la_mux[i] :
                              (src_la == 2'd2) ? {env_imag_la[i], env_real_la[i]} :
                              32'h0000_0000;

        // Product with gain.
        assign prodg_a_real[i]      = dout_mux_r1[i][15:0];
        assign prodg_a_imag[i]      = dout_mux_r1[i][31:16];
        assign prodg_y_full_real[i] = prodg_a_real[i] * gain_la;
        assign prodg_y_full_imag[i] = prodg_a_imag[i] * gain_la;

        // Rounding.
        assign round_real[i] = prodg_y_full_real_r[i][30-:16];
        assign round_imag[i] = prodg_y_full_imag_r[i][30-:16];
        assign round[i]       = {round_imag[i], round_real[i]};

        // Outputs.
        assign m_axis_tdata_o[i*32+:32] = (en_la_r == 1'b1) ? round_r[i] :
                                           (stdy_la == 1'b0) ? last_r[i] :
                                           32'h0000_0000;
    end

    // Latency for source selection (FIR-enable variant).
    delay_line #(.N(2), .M(2)) src_fir_delay_i (
        .i_clk (clk), .i_rstn (rstn), .i_data (src_int), .o_data (src_fir)
    );

    // Output mux.
    delay_line #(.N(18), .M(2)) src_delay_i (
        .i_clk (clk), .i_rstn (rstn), .i_data (src_int), .o_data (src_la)
    );

    // Latency for steady value selection.
    delay_line #(.N(21), .M(1)) stdy_delay_i (
        .i_clk (clk), .i_rstn (rstn), .i_data (stdy_int), .o_data (stdy_la)
    );

    // Latency for gain.
    delay_line #(.N(19), .M(16)) gain_delay_i (
        .i_clk (clk), .i_rstn (rstn), .i_data (gain_int), .o_data (gain_la)
    );

    // Latency for output enable.
    delay_line #(.N(20), .M(1)) en_delay_i (
        .i_clk (clk), .i_rstn (rstn), .i_data (en_int), .o_data (en_la)
    );

    always_ff @(posedge clk) begin
        if (!rstn) begin
            mem_addr_int_r <= '0;
            dds_tvalid_r   <= '0;
            dds_ctrl_int_r <= '0;
            mem_real_r1    <= '0;
            mem_imag_r1    <= '0;
            en_la_r        <= '0;
        end else begin
            mem_addr_int_r <= mem_addr_int;

            dds_tvalid_r   <= 1'b1;
            dds_ctrl_int_r <= dds_ctrl_int;

            // Memory data: frozen while src_fir selects DDS-only output
            // (matches legacy -- avoids needless memory reads).
            if (src_fir != 2'b01) begin
                mem_real_r1 <= mem_dout_real_i;
                mem_imag_r1 <= mem_dout_imag_i;
            end

            en_la_r <= en_la;
        end
    end

    // Memory data (packed for the FIR: [31:16]=imag, [15:0]=real).
    assign env_din = {mem_imag_r1, mem_real_r1};

    // Outputs.
    assign mem_addr_o    = mem_addr_int_r;
    assign m_axis_tvalid_o = en_la_r;

endmodule
