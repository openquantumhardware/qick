// ============================================================================
// File: qick_periph_loopback_tc00.sv
// Description: SVUnit testbench top-level for qick_periph_loopback: DELAY = 3 (default) and DELAY = 1 side by side,
//   same stimulus.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module qick_periph_loopback_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "qick_periph_loopback_ut";
    svunit_testcase svunit_ut;

    localparam real CLOCK_FREQUENCY = 200e6;

    logic tb_clk  = 1'b0;
    logic tb_rstn = 1'b1;
    clk_gen #(.FREQ (CLOCK_FREQUENCY)) u_clk (.i_enable(1'b1), .o_clk(tb_clk));

    logic        en = 1'b0;
    logic [4:0]  op = '0;
    logic [31:0] a = '0, b = '0, c = '0, d = '0;

    logic        rdy3, vld3, flag3, rdy1, vld1, flag1;
    logic [31:0] dt1_3, dt2_3, cmd3, drop3, dt1_1, dt2_1, cmd1, drop1;

    qick_periph_loopback #(.DELAY(3)) u3 (.clk_i(tb_clk), .rst_ni(tb_rstn), .en_i(en), .op_i(op), .a_i(a), .b_i(b), .c_i(c), .d_i(d),
        .rdy_o(rdy3), .dt1_o(dt1_3), .dt2_o(dt2_3), .vld_o(vld3), .flag_o(flag3), .cmd_cnt_o(cmd3), .drop_cnt_o(drop3));
    qick_periph_loopback #(.DELAY(1)) u1 (.clk_i(tb_clk), .rst_ni(tb_rstn), .en_i(en), .op_i(op), .a_i(a), .b_i(b), .c_i(c), .d_i(d),
        .rdy_o(rdy1), .dt1_o(dt1_1), .dt2_o(dt2_1), .vld_o(vld1), .flag_o(flag1), .cmd_cnt_o(cmd1), .drop_cnt_o(drop1));

    default clocking tb_cb @(posedge tb_clk);
        default input #1step output #2;
        output tb_rstn;
    endclocking

    task automatic reset_dut();
        en = 1'b0;
        tb_cb.tb_rstn <= 1'b0;
        repeat (5) @(tb_cb);
        tb_cb.tb_rstn <= 1'b1;
        repeat (2) @(tb_cb);
        #1;
    endtask

    // one clock with `en` high and the given operands; inputs change 1 ns after an edge, outputs are read 1 ns after the next
    task automatic cmd(input logic [4:0] o, input logic [31:0] va, vb, vc, vd);
        en = 1'b1; op = o; a = va; b = vb; c = vc; d = vd;
        @(posedge tb_clk); #1;
        en = 1'b0;
    endtask

    task automatic idle(input int n);
        repeat (n) begin @(posedge tb_clk); #1; end
    endtask

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
    `include "qick_periph_loopback_tests.sv"
    `SVUNIT_TESTS_END
endmodule
