`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"
///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
//
// Module : iir_1p1z_unit_test
// Project: axis_kidsim_v3
///////////////////////////////////////////////////////////////////////////////
/**
 * @file    iir_1p1z_tc00.sv
 * @brief   SVUnit testbench top for iir_1p1z (1-pole/1-zero fixed-point IIR).
 *
 * @details Drives the DUT with a golden fixed-point reference model that
 *          replicates the exact re-quantization the RTL uses
 *          (drop-sign-bit part-selects). Provides helper tasks to push samples
 *          either back-to-back or with valid bubbles, so tests can prove the
 *          filter tolerates non-continuous i_valid (the original begin/end bug).
 *
 * @author  AD Firmware / Fermilab
 * @version 1.0
 *
 * @note    Reset convention: SYNCHRONOUS active-low.
 */
module iir_1p1z_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "iir_1p1z_ut";
    svunit_testcase svunit_ut;

    //-------------------------------------------------------------------------
    // Parameters
    //-------------------------------------------------------------------------
    localparam int  B  = 16;
    localparam int  BA = 20;
    localparam int  BP = BA + B;
    localparam int  LAT = 4;                 // valid latency (cycles)
    localparam real CLOCK_FREQUENCY = 200e6;

    //-------------------------------------------------------------------------
    // Clock / reset
    //-------------------------------------------------------------------------
    logic tb_clk  = 1'b0;
    logic tb_rstn = 1'b1;

    clk_gen #(.FREQ(CLOCK_FREQUENCY)) u_clk (.i_enable(1'b1), .o_clk(tb_clk));

    //-------------------------------------------------------------------------
    // DUT signals
    //-------------------------------------------------------------------------
    logic                 i_valid;
    logic signed [B-1:0]  i_data;
    logic                 o_valid;
    logic signed [B-1:0]  o_data;
    logic signed [B-1:0]  i_c0, i_c1, i_g;

    // =========================================================================
    // Dump
    // =========================================================================
    initial begin
        $dumpfile("iir_1p1z.vcd");
        $dumpvars();
    end

    //-------------------------------------------------------------------------
    // DUT
    //-------------------------------------------------------------------------
    iir_1p1z #(.B(B), .BA(BA)) dut (
        .i_clk   (tb_clk),
        .i_rstn  (tb_rstn),
        .i_valid (i_valid),
        .i_data  (i_data),
        .o_valid (o_valid),
        .o_data  (o_data),
        .i_c0    (i_c0),
        .i_c1    (i_c1),
        .i_g     (i_g)
    );

    //-------------------------------------------------------------------------
    // Golden fixed-point reference model (bit-exact with the RTL datapath).
    //   Only advances internal state on a valid sample, just like the DUT.
    //   Applies the SAME part-selects as the RTL:
    //     p_q = p[BP-2 -: BA]     (drop duplicated sign bit)
    //     yg_q = yg[2*B-2 -: B]
    //-------------------------------------------------------------------------
    // Persistent model state (the single feedback register y1).
    logic signed [BA-1:0] ref_y1;      // y[n-1] pole state (BA-domain)
    logic signed [BA-1:0] ref_xnm1;    // x[n-1] (BA-domain, sign-extended)

    function automatic logic signed [B-1:0] ref_step(input logic signed [B-1:0] x);
        logic signed [BA-1:0] xn;
        logic signed [BP-1:0] p0, p1, yg;
        logic signed [BA-1:0] p0_q, p1_q, y0, y1;
        logic signed [B-1:0]  yg_q;
        begin
            xn   = BA'(x);                 // sign-extend
            // feed-forward: y0 = xn - (c0*x[n-1])
            p0   = i_c0 * ref_xnm1;
            p0_q = p0[BP-2 -: BA];
            y0   = xn - p0_q;
            // feed-back: y1 = y0 + (c1*y[n-1])
            p1   = i_c1 * ref_y1;
            p1_q = p1[BP-2 -: BA];
            y1   = y0 + p1_q;
            // output gain
            yg   = i_g * y1;
            yg_q = yg[2*B-2 -: B];
            // update persistent state
            ref_xnm1 = xn;
            ref_y1   = y1;
            return yg_q;
        end
    endfunction

    task automatic ref_reset();
        ref_y1   = '0;
        ref_xnm1 = '0;
    endtask

    // Persistent state for the SATURATED reference model.
    logic signed [BA-1:0] refs_y1;
    logic signed [BA-1:0] refs_xnm1;

    // Saturated reference: same as ref_step but y1 is clamped to BA bits.
    function automatic logic signed [B-1:0] ref_step_sat(input logic signed [B-1:0] x);
        logic signed [BA-1:0] xn;
        logic signed [BP-1:0] p0, p1, yg;
        logic signed [BA-1:0] p0_q, p1_q, y0, y1;
        logic signed [BA:0]   y1_ext;
        logic signed [B-1:0]  yg_q;
        localparam logic signed [BA-1:0] SMAX = {1'b0, {(BA-1){1'b1}}};
        localparam logic signed [BA-1:0] SMIN = {1'b1, {(BA-1){1'b0}}};
        begin
            xn   = BA'(x);
            p0   = i_c0 * refs_xnm1;
            p0_q = p0[BP-2 -: BA];
            y0   = xn - p0_q;
            p1   = i_c1 * refs_y1;
            p1_q = p1[BP-2 -: BA];
            // saturating feedback sum
            y1_ext = $signed({y0[BA-1], y0}) + $signed({p1_q[BA-1], p1_q});
            y1     = (y1_ext > $signed(SMAX)) ? SMAX :
                     (y1_ext < $signed(SMIN)) ? SMIN :
                     y1_ext[BA-1:0];
            yg   = i_g * y1;
            begin
                logic signed [BP-B:0] yg_sr;
                logic signed [B-1:0]  SMAXB, SMINB;
                SMAXB = {1'b0, {(B-1){1'b1}}};
                SMINB = {1'b1, {(B-1){1'b0}}};
                yg_sr = yg >>> (B-1);
                yg_q  = (yg_sr > $signed(SMAXB)) ? SMAXB :
                        (yg_sr < $signed(SMINB)) ? SMINB :
                        yg_sr[B-1:0];
            end
            refs_xnm1 = xn;
            refs_y1   = y1;
            return yg_q;
        end
    endfunction

    task automatic ref_reset_sat();
        refs_y1   = '0;
        refs_xnm1 = '0;
    endtask

    //-------------------------------------------------------------------------
    // Driver helpers
    //-------------------------------------------------------------------------
    // Apply synchronous reset for a few cycles and clear model state.
    task automatic do_reset();
        i_valid = 1'b0;
        i_data  = '0;
        tb_rstn = 1'b0;
        repeat (4) @(posedge tb_clk);
        tb_rstn = 1'b1;
        @(posedge tb_clk);
        ref_reset();
    endtask

    // Push ONE valid sample (single cycle high).
    task automatic push(input logic signed [B-1:0] x);
        @(posedge tb_clk);
        i_data  <= x;
        i_valid <= 1'b1;
        @(posedge tb_clk);
        i_valid <= 1'b0;
    endtask

    // Insert 'n' idle (bubble) cycles with i_valid low.
    task automatic bubble(input int n);
        i_valid <= 1'b0;
        repeat (n) @(posedge tb_clk);
    endtask

    //-------------------------------------------------------------------------
    // SVUnit boilerplate
    //-------------------------------------------------------------------------
    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        // Safe defaults before each test.
        i_valid = 1'b0;
        i_data  = '0;
        i_c0    = '0;
        i_c1    = '0;
        i_g     = '0;
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    `SVUNIT_TESTS_BEGIN
    `include "iir_1p1z_tests.sv"
    `SVUNIT_TESTS_END

endmodule