// -----------------------------------------------------------------------------
// pimod_pfb_sv : SystemVerilog behavioural translation of pimod_pfb.vhd
// -----------------------------------------------------------------------------
// Spectral PI shift at the output of the SSR FFT in the PFB. A PI frequency
// shift = multiply by the alternating sequence (+1,-1); here it is applied to
// odd FFT bins only, and toggled every T = NFFT/L output transactions (sel).
//
// Structure (matches VHDL):
//   * fifo_axi_sv buffers {tlast, tdata} (NBITS+1 wide).
//   * 2-stage pipeline: d_r  <- fifo_dout, d_rr <- d_mux.
//   * Per-lane I/Q sliced as signed; odd lanes negated (with MIN_N saturation).
//   * d_mux selects raw data while sel==0, else the +/- modulated data.
//   * cnt counts 0..T-1 while reading & not empty; sel increments each wrap.
//
// Guided translation: VHDL signed / to_signed(MAX_P,MIN_N) saturation ->
// SV signed arithmetic with explicit MIN_N overflow guard.
// -----------------------------------------------------------------------------
`timescale 1ns / 1ps

module pimod_pfb_sv #(
    // FFT size.
    parameter int NFFT = 16,
    // Number of bits.
    parameter int B    = 16,
    // Number of Lanes.
    parameter int L    = 4
)(
    // Reset and clock.
    input  logic                aresetn,
    input  logic                aclk,

    // S_AXIS for input.
    input  logic [2*B*L-1:0]    s_axis_tdata,
    input  logic                s_axis_tlast,
    input  logic                s_axis_tvalid,
    output logic                s_axis_tready,

    // M_AXIS for output.
    output logic [2*B*L-1:0]    m_axis_tdata,
    output logic                m_axis_tlast,
    output logic                m_axis_tvalid,
    input  logic                m_axis_tready
);

    // Number of bits.
    localparam int NBITS = 2*B*L;

    // MIN,MAX values.
    localparam logic signed [B-1:0] MAX_P = (1 <<< (B-1)) - 1;   //  2^(B-1)-1
    localparam logic signed [B-1:0] MIN_N = -(1 <<< (B-1));      // -2^(B-1)

    // Period for +1 -1.
    localparam int T      = NFFT/L;
    localparam int T_LOG2 = (T > 1) ? $clog2(T) : 1;

    // FIFO signals (data + tlast).
    logic [NBITS:0]     fifo_din;
    logic [NBITS:0]     fifo_dout;
    logic               fifo_full;
    logic               fifo_empty;

    // Input data/tlast.
    logic [NBITS-1:0]   d_i;
    logic               last_i;

    // Pipeline registers.
    logic [NBITS-1:0]   d_r;
    logic [NBITS-1:0]   d_rr;
    logic               empty_r;
    logic               empty_rr;
    logic               last_r;
    logic               last_rr;

    // Vector signals for pm operation.
    logic signed [B-1:0] dv_i    [0:L-1];
    logic signed [B-1:0] dv_i_pm [0:L-1];
    logic signed [B-1:0] dv_q    [0:L-1];
    logic signed [B-1:0] dv_q_pm [0:L-1];

    // Signals combined after pm.
    logic [NBITS-1:0]   d_pm;

    // Muxed signal for alternating pm operation.
    logic [NBITS-1:0]   d_mux;

    // Selection register.
    logic [T_LOG2-1:0]  cnt;
    logic [0:0]         sel;

    // ------------------------------------------------------------------
    // FIFO (NBITS+1 bits: data + tlast).
    // ------------------------------------------------------------------
    fifo_axi_sv #(
        .B (NBITS+1),
        .N (4)
    ) fifo (
        .rstn  (aresetn),
        .clk   (aclk),
        .wr_en (s_axis_tvalid),
        .din   (fifo_din),
        .rd_en (m_axis_tready),
        .dout  (fifo_dout),
        .full  (fifo_full),
        .empty (fifo_empty)
    );

    // Fifo connections.
    assign fifo_din      = {s_axis_tlast, s_axis_tdata};
    assign s_axis_tready = ~fifo_full;

    // ------------------------------------------------------------------
    // Registers.
    // ------------------------------------------------------------------
    always_ff @(posedge aclk) begin
        if (aresetn == 1'b0) begin
            d_r      <= '0;
            d_rr     <= '0;
            empty_r  <= 1'b1;
            empty_rr <= 1'b1;
            last_r   <= 1'b0;
            last_rr  <= 1'b0;

            cnt      <= '0;
            sel      <= '0;
        end else begin
            // Pipeline registers.
            d_r      <= d_i;
            d_rr     <= d_mux;
            empty_r  <= fifo_empty;
            empty_rr <= empty_r;
            last_r   <= last_i;
            last_rr  <= last_r;

            // sel register: if reading and not empty, count.
            if (m_axis_tready == 1'b1 && empty_r == 1'b0) begin
                if (cnt < T_LOG2'(T-1)) begin
                    cnt <= cnt + 1'b1;
                end else begin
                    cnt <= '0;
                    sel <= sel + 1'b1;
                end
            end
        end
    end

    // Input data/tlast.
    assign d_i    = fifo_dout[NBITS-1:0];
    assign last_i = fifo_dout[NBITS];

    // ------------------------------------------------------------------
    // Slice input (per-lane I/Q as signed).
    // ------------------------------------------------------------------
    genvar gi;
    generate
        for (gi = 0; gi < L; gi = gi + 1) begin : GEN_SLICE_IN
            assign dv_i[gi] = $signed(d_r[    2*gi*B  +: B]);
            assign dv_q[gi] = $signed(d_r[(2*gi+1)*B  +: B]);
        end
    endgenerate

    // ------------------------------------------------------------------
    // Multiply by -1 only odd samples (with MIN_N overflow saturation).
    // ------------------------------------------------------------------
    generate
        for (gi = 0; gi < L/2; gi = gi + 1) begin : GEN_PM
            // Even samples: multiply always by 1.
            assign dv_i_pm[2*gi]   = dv_i[2*gi];
            // Odd samples: multiply by -1. Check maximum negative number.
            assign dv_i_pm[2*gi+1] = (dv_i[2*gi+1] == MIN_N) ? MAX_P : -dv_i[2*gi+1];

            // Even samples: multiply always by 1.
            assign dv_q_pm[2*gi]   = dv_q[2*gi];
            // Odd samples: multiply by -1. Check maximum negative number.
            assign dv_q_pm[2*gi+1] = (dv_q[2*gi+1] == MIN_N) ? MAX_P : -dv_q[2*gi+1];
        end
    endgenerate

    // ------------------------------------------------------------------
    // Combine signals back.
    // ------------------------------------------------------------------
    generate
        for (gi = 0; gi < L; gi = gi + 1) begin : GEN_COMBINE_PM
            assign d_pm[    2*gi*B  +: B] = dv_i_pm[gi];
            assign d_pm[(2*gi+1)*B  +: B] = dv_q_pm[gi];
        end
    endgenerate

    // Data mux.
    assign d_mux = (sel == 1'b0) ? d_r : d_pm;

    // Assign outputs.
    assign m_axis_tdata  = d_rr;
    assign m_axis_tlast  = last_rr;
    assign m_axis_tvalid = ~empty_rr;

endmodule
