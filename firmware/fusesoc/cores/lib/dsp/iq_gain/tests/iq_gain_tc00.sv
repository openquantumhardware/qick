// ============================================================================
// File: iq_gain_unit_test.sv
// Description: SVUnit testbench top-level for iq_gain.
//   Verifies the I/Q amplification and saturation logic.
//   Includes a bit-true software reference model for multiplication and clamping.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module iq_gain_unit_test;
    import svunit_pkg::svunit_testcase;
    string name = "iq_gain_ut";
    svunit_testcase svunit_ut;

    // =========================================================================
    // Parameters
    // =========================================================================
    localparam real CLOCK_FREQUENCY = 250e6;
    localparam int  DW = 16;
    localparam int  GW = 16;
    localparam int  LATENCY = 3; // 3 stages of registers

    // Constants for the limits and unity gain (Q-format)
    localparam signed [DW-1:0] MAXV = (1 << (DW-1)) - 1;
    localparam signed [DW-1:0] MINV = -(1 << (DW-1));
    localparam signed [GW-1:0] GAIN_UNITY = (1 << (GW-1)) - 1; // 0x7FFF (~1.0)

    // =========================================================================
    // Clock & Reset
    // =========================================================================
    logic tb_aclk    = 1'b0;
    logic tb_aresetn = 1'b0;
    
    clk_gen #(.FREQ (CLOCK_FREQUENCY)) u_clk (.i_enable(1'b1), .o_clk(tb_aclk));

    // =========================================================================
    // DUT signals
    // =========================================================================
    logic signed [DW-1:0] tb_i_in = '0;
    logic signed [DW-1:0] tb_q_in = '0;
    logic        [GW-1:0] tb_gain_i = '0;
    logic        [GW-1:0] tb_gain_q = '0;
    logic signed [DW-1:0] tb_i_out;
    logic signed [DW-1:0] tb_q_out;
    // Second instance, integer-gain mode (GAIN_SHIFT = GW-1: SHIFT_AMT = 0)
    logic signed [DW-1:0] tb_i_out_int;
    logic signed [DW-1:0] tb_q_out_int;

    // =========================================================================
    // Clocking block
    // =========================================================================
    default clocking tb_cb @(posedge tb_aclk);
        default input #1step output #2;
        output tb_aresetn;
        output tb_i_in;
        output tb_q_in;
        output tb_gain_i;
        output tb_gain_q;
        input  tb_i_out;
        input  tb_q_out;
        input  tb_i_out_int;
        input  tb_q_out_int;
    endclocking

    // =========================================================================
    // DUT
    // =========================================================================
    iq_gain #(
        .DW (DW),
        .GW (GW)
    ) dut (
        .aclk    (tb_aclk),
        .aresetn (tb_aresetn),
        .i_in    (tb_i_in),
        .q_in    (tb_q_in),
        .gain_i  (tb_gain_i),
        .gain_q  (tb_gain_q),
        .i_out   (tb_i_out),
        .q_out   (tb_q_out)
    );

    // Integer-gain mode: GAIN_SHIFT = GW-1 makes SHIFT_AMT = 0, so the gain is a plain
    // signed integer (no fractional bits, no rounding term) and the product can
    // saturate in both directions. This is the only configuration in which the
    // negative clamp (scaled < MINV) and the SHIFT_AMT <= 0 branch are reachable:
    // with Q1.15 gains in [-1, 1) the product never leaves int16 on the low side.
    iq_gain #(
        .DW         (DW),
        .GW         (GW),
        .GAIN_SHIFT (GW-1)
    ) dut_int (
        .aclk    (tb_aclk),
        .aresetn (tb_aresetn),
        .i_in    (tb_i_in),
        .q_in    (tb_q_in),
        .gain_i  (tb_gain_i),
        .gain_q  (tb_gain_q),
        .i_out   (tb_i_out_int),
        .q_out   (tb_q_out_int)
    );

    // =========================================================================
    // Dump
    // =========================================================================
    initial begin
        $dumpfile("iq_gain.vcd");
        $dumpvars();
    end

    // =========================================================================
    // Golden Model (Bit-True con el DUT)
    // =========================================================================
    typedef struct {
        logic signed [DW-1:0] i;
        logic signed [DW-1:0] q;
    } iq_t;

    function automatic iq_t golden_model(
        input logic signed [DW-1:0] i_in,
        input logic signed [DW-1:0] q_in,
        input logic signed [GW-1:0] gain_i,
        input logic signed [GW-1:0] gain_q
    );
        logic signed [DW+GW-1:0] i_mult, q_mult;
        logic signed [DW+GW-1:0] i_round, q_round;
        logic signed [DW+GW-1:0] i_scale, q_scale;
        iq_t out;

        // 1. Multiplication
        i_mult = i_in * gain_i;
        q_mult = q_in * gain_q;

        // 2. Rounding: add (1 << (GW-2))
        i_round = i_mult + (1 << (GW-2));
        q_round = q_mult + (1 << (GW-2));

        // 3. Scaling: Arithmetic Shift (>>> GW-1)
        i_scale = i_round >>> (GW-1);
        q_scale = q_round >>> (GW-1);

        // 4. Parametric Saturación
        out.i = (i_scale > MAXV) ? MAXV : ((i_scale < MINV) ? MINV : i_scale[DW-1:0]);
        out.q = (q_scale > MAXV) ? MAXV : ((q_scale < MINV) ? MINV : q_scale[DW-1:0]);

        return out;
    endfunction

    // Integer-gain model: out = clamp(in * gain), no shift, no rounding.
    function automatic iq_t golden_model_int(
        input logic signed [DW-1:0] i_in,
        input logic signed [DW-1:0] q_in,
        input logic signed [GW-1:0] gain_i,
        input logic signed [GW-1:0] gain_q
    );
        longint i_p = longint'(i_in) * longint'(gain_i);
        longint q_p = longint'(q_in) * longint'(gain_q);
        iq_t out;
        out.i = (i_p > MAXV) ? MAXV : ((i_p < MINV) ? MINV : i_p[DW-1:0]);
        out.q = (q_p > MAXV) ? MAXV : ((q_p < MINV) ? MINV : q_p[DW-1:0]);
        return out;
    endfunction

    // =========================================================================
    // Helpers
    // =========================================================================
    task automatic reset_dut();
        tb_cb.tb_aresetn <= 1'b0;
        tb_cb.tb_i_in    <= '0;
        tb_cb.tb_q_in    <= '0;
        tb_cb.tb_gain_i  <= '0;
        tb_cb.tb_gain_q  <= '0;
        repeat(5) @(tb_cb);
        tb_cb.tb_aresetn <= 1'b1;
        repeat(2) @(tb_cb);
    endtask

    task automatic test_stream(input int count);
        iq_t expected_q[$];

        fork
            // Driver thread
            begin
                for (int n = 0; n < count; n++) begin
                    logic signed [DW-1:0] rnd_i = $urandom;
                    logic signed [DW-1:0] rnd_q = $urandom;
                    logic        [2*GW-1:0] rnd_g = $urandom;

                    tb_cb.tb_i_in   <= rnd_i;
                    tb_cb.tb_q_in   <= rnd_q;
                    tb_cb.tb_gain_i <= rnd_g[GW-1:0];
                    tb_cb.tb_gain_q <= rnd_g[2*GW-1:GW];

                    expected_q.push_back(golden_model(rnd_i, rnd_q, rnd_g[GW-1:0], rnd_g[2*GW-1:GW]));
                    @(tb_cb);
                end
                tb_cb.tb_i_in   <= '0;
                tb_cb.tb_q_in   <= '0;
                tb_cb.tb_gain_i <= '0;
                tb_cb.tb_gain_q <= '0;
            end

            // Monitor thread
            begin
                repeat(LATENCY + 1) @(tb_cb); 
                for (int n = 0; n < count; n++) begin
                    iq_t exp = expected_q.pop_front();
                    if (tb_cb.tb_i_out !== exp.i || tb_cb.tb_q_out !== exp.q) begin
                        $display("STREAM MISMATCH n=%0d: exp(%0d,%0d) got(%0d,%0d)",
                                n, exp.i, exp.q, signed'(tb_cb.tb_i_out), signed'(tb_cb.tb_q_out));
                        `FAIL_IF(1);
                    end
                    @(tb_cb);
                end
            end
        join
    endtask

    // Same as test_stream, against the integer-gain instance. Gains are kept small
    // so that products land both inside int16 and well beyond it on both sides.
    task automatic test_stream_int(input int count);
        iq_t expected_q[$];

        fork
            begin
                for (int n = 0; n < count; n++) begin
                    logic signed [DW-1:0] rnd_i = $urandom;
                    logic signed [DW-1:0] rnd_q = $urandom;
                    logic signed [GW-1:0] rnd_gi = $urandom_range(0, 255) - 128;
                    logic signed [GW-1:0] rnd_gq = $urandom_range(0, 255) - 128;

                    tb_cb.tb_i_in   <= rnd_i;
                    tb_cb.tb_q_in   <= rnd_q;
                    tb_cb.tb_gain_i <= rnd_gi;
                    tb_cb.tb_gain_q <= rnd_gq;
                    expected_q.push_back(golden_model_int(rnd_i, rnd_q, rnd_gi, rnd_gq));
                    @(tb_cb);
                end
                tb_cb.tb_i_in   <= '0;
                tb_cb.tb_q_in   <= '0;
                tb_cb.tb_gain_i <= '0;
                tb_cb.tb_gain_q <= '0;
            end

            begin
                repeat(LATENCY + 1) @(tb_cb);
                for (int n = 0; n < count; n++) begin
                    iq_t exp = expected_q.pop_front();
                    if (tb_cb.tb_i_out_int !== exp.i || tb_cb.tb_q_out_int !== exp.q) begin
                        $display("INT STREAM MISMATCH n=%0d: exp(%0d,%0d) got(%0d,%0d)",
                                n, exp.i, exp.q, signed'(tb_cb.tb_i_out_int), signed'(tb_cb.tb_q_out_int));
                        `FAIL_IF(1);
                    end
                    @(tb_cb);
                end
            end
        join
    endtask

    // =========================================================================
    // SVUnit
    // =========================================================================
    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        reset_dut();
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    `SVUNIT_TESTS_BEGIN
    `include "iq_gain_tests.sv"
    `SVUNIT_TESTS_END

endmodule