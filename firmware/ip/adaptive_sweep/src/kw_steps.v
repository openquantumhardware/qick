`timescale 1ns / 1ps
//
// kw_steps.v
//
// LUT-driven Kiefer-Wolfowitz step generator.
//
// The ARM (PS) precomputes a step magnitude schedule -- typically the
// Section 9 _ak_s9(k) function or any other custom decay -- and writes it
// into the on-chip BRAM through {lut_we, lut_addr, lut_din}.
//
// On a step_trigger pulse the module:
//   1. Reads LUT[k_idx]                                (sync BRAM read)
//   2. Determines the step direction from sign(dp_signed):
//        dp > 0 -> step =  +LUT[k_idx]    (move x toward higher response)
//        dp < 0 -> step =  -LUT[k_idx]
//        dp = 0 -> step =  0
//   3. x_sum = x_in + step
//   4. x_out = clamp(x_sum, x_min, x_max)
//   5. conv_flag asserted if |step| < KW_TOL (caller-provided tol param)
//
// 6-stage pipeline.  No multipliers, one BRAM18.  Critical path: 32-bit
// add followed by clamp compare in stage K5; if synthesis flags slack,
// move clamp into a separate stage K6.
//

module kw_steps #(
    parameter integer X_WIDTH      = 32,
    parameter integer LUT_DEPTH    = 256,
    parameter integer LUT_AW       = 8,            // log2(LUT_DEPTH)
    parameter [X_WIDTH-1:0] KW_TOL = 32'h0000_07D0 // ~2000 in fixed-point
)(
    input  wire                    clk,
    input  wire                    rst_n,

    // LUT write port (from adaptive_sweep_control on KW_LUT_WE opcode)
    input  wire                    lut_we,
    input  wire [LUT_AW-1:0]       lut_addr,
    input  wire signed [X_WIDTH-1:0] lut_din,

    // Step request
    input  wire                    step_trigger,
    input  wire signed [X_WIDTH-1:0] dp_signed,    // = y_plus - y_minus
    input  wire [LUT_AW-1:0]       k_idx,
    input  wire signed [X_WIDTH-1:0] x_in,
    input  wire signed [X_WIDTH-1:0] x_min,
    input  wire signed [X_WIDTH-1:0] x_max,

    // Step result
    output reg  signed [X_WIDTH-1:0] x_out,
    output reg                       conv_flag,
    output reg                       valid_o
);

    // -------------------- LUT (256 x 32, BRAM) --------------------
    (* ram_style = "block" *) reg signed [X_WIDTH-1:0] lut [0:LUT_DEPTH-1];
    reg signed [X_WIDTH-1:0] lut_q;

    always @(posedge clk) begin
        if (lut_we)
            lut[lut_addr] <= lut_din;
        // Port B: synchronous read on every step trigger.
        // For Vivado BRAM inference we drive the read every cycle.
        lut_q <= lut[k_idx];
    end

    // -------------------- Pipeline registers --------------------
    // K0 (sample): inputs latched directly into K1 below
    reg                       k1_trig;
    reg                       k1_sign_pos;
    reg                       k1_is_zero;
    reg signed [X_WIDTH-1:0]  k1_x_in;
    reg signed [X_WIDTH-1:0]  k1_x_min, k1_x_max;
    reg [LUT_AW-1:0]          k1_idx;

    // K2: lut_q valid here (BRAM 1-cycle latency)
    reg                       k2_trig;
    reg                       k2_sign_pos;
    reg                       k2_is_zero;
    reg signed [X_WIDTH-1:0]  k2_x_in;
    reg signed [X_WIDTH-1:0]  k2_x_min, k2_x_max;

    // K3: step computed
    reg                       k3_trig;
    reg signed [X_WIDTH-1:0]  k3_step;
    reg signed [X_WIDTH-1:0]  k3_x_in;
    reg signed [X_WIDTH-1:0]  k3_x_min, k3_x_max;

    // K4: x_sum
    reg                       k4_trig;
    reg signed [X_WIDTH-1:0]  k4_x_sum;
    reg signed [X_WIDTH-1:0]  k4_x_min, k4_x_max;
    reg signed [X_WIDTH-1:0]  k4_step;

    // K5: clamp + conv flag (output stage)

    // -------------------- Stages --------------------
    always @(posedge clk) begin
        if (!rst_n) begin
            k1_trig    <= 1'b0;
            k1_sign_pos<= 1'b0;
            k1_is_zero <= 1'b0;
            k1_x_in    <= 0;
            k1_x_min   <= 0;
            k1_x_max   <= 0;
            k1_idx     <= 0;

            k2_trig    <= 1'b0;
            k2_sign_pos<= 1'b0;
            k2_is_zero <= 1'b0;
            k2_x_in    <= 0;
            k2_x_min   <= 0;
            k2_x_max   <= 0;

            k3_trig    <= 1'b0;
            k3_step    <= 0;
            k3_x_in    <= 0;
            k3_x_min   <= 0;
            k3_x_max   <= 0;

            k4_trig    <= 1'b0;
            k4_x_sum   <= 0;
            k4_x_min   <= 0;
            k4_x_max   <= 0;
            k4_step    <= 0;

            x_out      <= 0;
            conv_flag  <= 1'b0;
            valid_o    <= 1'b0;
        end else begin
            // K1: latch inputs and compute sign / is_zero
            k1_trig     <= step_trigger;
            k1_sign_pos <= ~dp_signed[X_WIDTH-1];          // 1 if non-negative
            k1_is_zero  <= (dp_signed == {X_WIDTH{1'b0}});
            k1_x_in     <= x_in;
            k1_x_min    <= x_min;
            k1_x_max    <= x_max;
            k1_idx      <= k_idx;

            // K2: lut_q is now valid (BRAM read completed this cycle)
            k2_trig     <= k1_trig;
            k2_sign_pos <= k1_sign_pos;
            k2_is_zero  <= k1_is_zero;
            k2_x_in     <= k1_x_in;
            k2_x_min    <= k1_x_min;
            k2_x_max    <= k1_x_max;

            // K3: pick signed step or zero
            k3_trig     <= k2_trig;
            k3_x_in     <= k2_x_in;
            k3_x_min    <= k2_x_min;
            k3_x_max    <= k2_x_max;
            if (k2_is_zero)
                k3_step <= 0;
            else if (k2_sign_pos)
                k3_step <= lut_q;
            else
                k3_step <= -lut_q;

            // K4: x_sum = x_in + step
            k4_trig     <= k3_trig;
            k4_x_sum    <= k3_x_in + k3_step;
            k4_x_min    <= k3_x_min;
            k4_x_max    <= k3_x_max;
            k4_step     <= k3_step;

            // K5: clamp + conv flag + output valid
            valid_o     <= k4_trig;
            if (k4_x_sum < k4_x_min)        x_out <= k4_x_min;
            else if (k4_x_sum > k4_x_max)   x_out <= k4_x_max;
            else                            x_out <= k4_x_sum;
            // conv flag uses absolute value of step
            if ((k4_step >= 0 ? k4_step : -k4_step) < KW_TOL)
                conv_flag <= 1'b1;
            else
                conv_flag <= 1'b0;
        end
    end

endmodule
