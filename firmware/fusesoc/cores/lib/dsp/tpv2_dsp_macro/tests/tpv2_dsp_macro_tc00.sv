//------------------------------------------------------------------------------
// Testbench: tpv2_dsp_macro_tc00
// Description:
//   Unit tests for the tprocv2 arith DSP macro behavioural model (see
//   rtl_lib/dsp/tpv2_dsp_macro.sv for the instruction table / sourcing).
//------------------------------------------------------------------------------

`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module tpv2_dsp_macro_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "tpv2_dsp_macro_ut";
    svunit_testcase svunit_ut;

    localparam real CLOCK_FREQUENCY = 200e6;

    logic tb_clk = 1'b0;

    logic        [3:0]  tb_sel;
    logic signed [26:0] tb_a;
    logic signed [17:0] tb_b;
    logic signed [31:0] tb_c;
    logic signed [26:0] tb_d;
    logic signed [45:0] tb_p;

    clk_gen #(.FREQ (CLOCK_FREQUENCY)) u_clk (.i_enable(1'b1), .o_clk(tb_clk));

    tpv2_dsp_macro #(
        .LATENCY (1)
    ) dut (
        .clk_i (tb_clk),
        .sel_i (tb_sel),
        .a_i   (tb_a),
        .b_i   (tb_b),
        .c_i   (tb_c),
        .d_i   (tb_d),
        .p_o   (tb_p)
    );

    initial begin
        $dumpfile("tpv2_dsp_macro.vcd");
        $dumpvars();
    end

    // Drives one instruction for one cycle and returns p_o once it has
    // propagated through the (LATENCY=1) output register.
    task automatic check_instr(
        input        [3:0]         sel,
        input signed [26:0]        a,
        input signed [17:0]        b,
        input signed [31:0]        c,
        input signed [26:0]        d,
        input signed [45:0]        expected,
        input string               msg
    );
        tb_sel = sel;
        tb_a   = a;
        tb_b   = b;
        tb_c   = c;
        tb_d   = d;
        @(posedge tb_clk);
        @(posedge tb_clk);
        `FAIL_UNLESS_LOG(tb_p == expected,
            $sformatf("%s: expected %0d, got %0d", msg, expected, tb_p));
    endtask

    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        tb_sel = '0;
        tb_a   = '0;
        tb_b   = '0;
        tb_c   = '0;
        tb_d   = '0;
        repeat(4) @(posedge tb_clk);
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    `SVUNIT_TESTS_BEGIN
    `include "tpv2_dsp_macro_tests.sv"
    `SVUNIT_TESTS_END

endmodule
