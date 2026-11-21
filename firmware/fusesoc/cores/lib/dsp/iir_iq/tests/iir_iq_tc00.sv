`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"
///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
//
// Module : iir_iq_unit_test
// Project: axis_kidsim_v3
///////////////////////////////////////////////////////////////////////////////
/**
 * @file    iir_iq_tc00.sv
 * @brief   SVUnit testbench top for iir_iq (complex I/Q first-order IIR).
 *
 * @details Drives the packed complex DUT and compares against TWO independent
 *          golden fixed-point models (one for I, one for Q) that are bit-exact
 *          with iir_1p1z. Verifies channel independence, { Q, I } packing, the
 *          latency (=4), and bubble tolerance.
 *
 * @author  AD Firmware / Fermilab
 * @version 1.0
 *
 * @note    Reset convention: SYNCHRONOUS active-low.
 */
module iir_iq_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "iir_iq_ut";
    svunit_testcase svunit_ut;

    //-------------------------------------------------------------------------
    localparam int  B   = 16;
    localparam int  BA  = 20;
    localparam int  BP  = BA + B;
    localparam int  LAT = 4;
    localparam real CLOCK_FREQUENCY = 200e6;

    //-------------------------------------------------------------------------
    logic tb_clk  = 1'b0;
    logic tb_rstn = 1'b1;
    clk_gen #(.FREQ(CLOCK_FREQUENCY)) u_clk (.i_enable(1'b1), .o_clk(tb_clk));

    //-------------------------------------------------------------------------
    // DUT signals
    //-------------------------------------------------------------------------
    logic                  i_valid;
    logic [2*B-1:0]        i_data;
    logic                  o_valid;
    logic [2*B-1:0]        o_data;
    logic signed [B-1:0]   i_c0, i_c1, i_g;
    // =========================================================================
    // Dump
    // =========================================================================
    initial begin
        $dumpfile("iir_iq.vcd");
        $dumpvars();
    end
    //-------------------------------------------------------------------------
    // DUT instantiation
    //-------------------------------------------------------------------------

    iir_iq #(.B(B), .BA(BA)) dut (
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
    // Two independent golden models (bit-exact with iir_1p1z), one per channel.
    //-------------------------------------------------------------------------
    logic signed [BA-1:0] ref_y1  [2];   // [0]=I, [1]=Q
    logic signed [BA-1:0] ref_xm1 [2];

    function automatic logic signed [B-1:0] ref_step(input int ch,
                                                     input logic signed [B-1:0] x);
        logic signed [BA-1:0] xn;
        logic signed [BP-1:0] p0, p1, yg;
        logic signed [BA-1:0] p0_q, p1_q, y0, y1;
        logic signed [B-1:0]  yg_q;
        begin
            xn   = BA'(x);
            p0   = i_c0 * ref_xm1[ch];
            p0_q = p0[BP-2 -: BA];
            y0   = xn - p0_q;
            p1   = i_c1 * ref_y1[ch];
            p1_q = p1[BP-2 -: BA];
            y1   = y0 + p1_q;
            yg   = i_g * y1;
            yg_q = yg[2*B-2 -: B];
            ref_xm1[ch] = xn;
            ref_y1[ch]  = y1;
            return yg_q;
        end
    endfunction

    task automatic ref_reset();
        ref_y1  = '{default:'0};
        ref_xm1 = '{default:'0};
    endtask

    // Pack/unpack helpers ({ Q, I }).
    function automatic logic [2*B-1:0] pack_iq(input logic signed [B-1:0] i_c,
                                               input logic signed [B-1:0] q_c);
        return {q_c, i_c};
    endfunction
    function automatic logic signed [B-1:0] unpack_i(input logic [2*B-1:0] w);
        return w[0 +: B];
    endfunction
    function automatic logic signed [B-1:0] unpack_q(input logic [2*B-1:0] w);
        return w[B +: B];
    endfunction

    //-------------------------------------------------------------------------
    // Driver helpers
    //-------------------------------------------------------------------------
    task automatic do_reset();
        i_valid = 1'b0;
        i_data  = '0;
        tb_rstn = 1'b0;
        repeat (4) @(posedge tb_clk);
        tb_rstn = 1'b1;
        @(posedge tb_clk);
        ref_reset();
    endtask

    task automatic bubble(input int n);
        i_valid <= 1'b0;
        repeat (n) @(posedge tb_clk);
    endtask

    //-------------------------------------------------------------------------
    function void build(); svunit_ut = new(name); endfunction
    task setup();
        svunit_ut.setup();
        i_valid = 1'b0; i_data = '0;
        i_c0 = '0; i_c1 = '0; i_g = '0;
    endtask
    task teardown(); svunit_ut.teardown(); endtask

    `SVUNIT_TESTS_BEGIN
    `include "iir_iq_tests.sv"
    `SVUNIT_TESTS_END

endmodule