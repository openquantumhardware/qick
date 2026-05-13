`timescale 1ns / 1ps
//
// bisect_control.v
//
// 3 dB edge bisection (Section 9 Phase 3.5).  Maintains a closed interval
// [lo, hi] in normalized x-space and on every `step` pulse evaluates the
// caller-supplied (pow_mid, pow_thr) pair to halve the interval toward the
// edge.
//
// 4-way decision (peak vs dip, left vs right), as described in
// Section 9 §1.7:
//   peak / left :  pow_mid <  pow_thr -> lo<=mid    else hi<=mid
//   peak / right:  pow_mid >  pow_thr -> lo<=mid    else hi<=mid
//   dip  / left :  pow_mid >  pow_thr -> lo<=mid    else hi<=mid
//   dip  / right:  pow_mid <  pow_thr -> lo<=mid    else hi<=mid
//
// Convergence: (hi - lo) < tol_in.  No DSP / no BRAM, only adders +
// comparators + muxes.  2-cycle latency from `step` to mid_next/converged.
//

module bisect_control #(
    parameter integer X_WIDTH = 32
)(
    input  wire                    clk,
    input  wire                    rst_n,

    // Initialization
    input  wire                    init,
    input  wire [X_WIDTH-1:0]      lo_init,
    input  wire [X_WIDTH-1:0]      hi_init,
    input  wire                    side_left,        // 1=left edge, 0=right edge
    input  wire                    polarity_peak,    // 1=peak, 0=dip
    input  wire [X_WIDTH-1:0]      tol_in,

    // Step request
    input  wire                    step,
    input  wire [X_WIDTH-1:0]      pow_mid,
    input  wire [X_WIDTH-1:0]      pow_thr,

    // Outputs
    output reg  [X_WIDTH-1:0]      mid_next,
    output reg  [X_WIDTH-1:0]      lo_o,
    output reg  [X_WIDTH-1:0]      hi_o,
    output reg                     converged_o,
    output reg                     valid_o            // pulses 1 cycle on step completion
);

    // Latched configuration
    reg                          side_left_r;
    reg                          polarity_peak_r;
    reg [X_WIDTH-1:0]            tol_r;

    // Stage 1 registers (for `step`)
    reg                          s1_step;
    reg                          s1_cmp_gt;       // pow_mid > pow_thr
    reg [X_WIDTH-1:0]            s1_mid;
    reg [X_WIDTH-1:0]            s1_lo, s1_hi;
    reg                          s1_converged;

    // The "raise lo" decision summary table:
    //   raise_lo = polarity_peak ?
    //              (side_left ? !cmp_gt : cmp_gt)         // peak
    //            :
    //              (side_left ?  cmp_gt : !cmp_gt);       // dip
    // raise_lo == 1 -> lo<=mid; else hi<=mid.

    always @(posedge clk) begin
        if (!rst_n) begin
            lo_o            <= 0;
            hi_o            <= 0;
            mid_next        <= 0;
            converged_o     <= 1'b0;
            valid_o         <= 1'b0;
            side_left_r     <= 1'b0;
            polarity_peak_r <= 1'b0;
            tol_r           <= 0;
            s1_step         <= 1'b0;
            s1_cmp_gt       <= 1'b0;
            s1_mid          <= 0;
            s1_lo           <= 0;
            s1_hi           <= 0;
            s1_converged    <= 1'b0;
        end else begin
            valid_o   <= 1'b0;
            s1_step   <= 1'b0;

            // Init takes precedence: arms the controller with the initial
            // interval and resets convergence.  No "step" should arrive on
            // the same cycle as init.
            if (init) begin
                lo_o            <= lo_init;
                hi_o            <= hi_init;
                mid_next        <= (lo_init + hi_init) >> 1;
                converged_o     <= 1'b0;
                side_left_r     <= side_left;
                polarity_peak_r <= polarity_peak;
                tol_r           <= tol_in;
            end
            else if (step && !converged_o) begin
                // Stage 1: compute mid, compare, snapshot interval
                s1_step      <= 1'b1;
                s1_cmp_gt    <= (pow_mid > pow_thr);
                s1_mid       <= mid_next;       // current midpoint that was probed
                s1_lo        <= lo_o;
                s1_hi        <= hi_o;
                s1_converged <= ((hi_o - lo_o) < tol_r);
            end

            // Stage 2: apply decision
            if (s1_step) begin
                automatic logic raise_lo;
                raise_lo = polarity_peak_r
                           ? (side_left_r ? ~s1_cmp_gt :  s1_cmp_gt)
                           : (side_left_r ?  s1_cmp_gt : ~s1_cmp_gt);
                if (raise_lo) begin
                    lo_o     <= s1_mid;
                    mid_next <= (s1_mid + s1_hi) >> 1;
                end else begin
                    hi_o     <= s1_mid;
                    mid_next <= (s1_lo + s1_mid) >> 1;
                end
                converged_o <= s1_converged;
                valid_o     <= 1'b1;
            end
        end
    end

endmodule
