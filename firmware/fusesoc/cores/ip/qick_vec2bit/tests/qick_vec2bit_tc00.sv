// ============================================================================
// File: qick_vec2bit_tc00.sv
// Description: SVUnit testbench for qick_vec2bit. The port runs next to the
//              legacy RTL (tests/ref/qick_vec2bit_legacy.v, the original file
//              with only the module renamed) at IN_DW = 16; an IN_DW = 8
//              instance checks that the missing upper bits read 0 (the legacy
//              RTL gives X there). Combinational: inputs set, outputs read #1.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module qick_vec2bit_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "qick_vec2bit_ut";
    svunit_testcase svunit_ut;

    logic [15:0] din = '0;
    logic [15:0] p16, l16, p8;

    qick_vec2bit #(.IN_DW(16), .OUT_QTY(16)) dut16 (.din(din),
        .dout0(p16[0]), .dout1(p16[1]), .dout2(p16[2]), .dout3(p16[3]), .dout4(p16[4]), .dout5(p16[5]),
        .dout6(p16[6]), .dout7(p16[7]), .dout8(p16[8]), .dout9(p16[9]), .dout10(p16[10]), .dout11(p16[11]),
        .dout12(p16[12]), .dout13(p16[13]), .dout14(p16[14]), .dout15(p16[15]));
    qick_vec2bit_legacy #(.IN_DW(16), .OUT_QTY(16)) ref16 (.din(din),
        .dout0(l16[0]), .dout1(l16[1]), .dout2(l16[2]), .dout3(l16[3]), .dout4(l16[4]), .dout5(l16[5]),
        .dout6(l16[6]), .dout7(l16[7]), .dout8(l16[8]), .dout9(l16[9]), .dout10(l16[10]), .dout11(l16[11]),
        .dout12(l16[12]), .dout13(l16[13]), .dout14(l16[14]), .dout15(l16[15]));
    qick_vec2bit #(.IN_DW(8), .OUT_QTY(8)) dut8 (.din(din[7:0]),
        .dout0(p8[0]), .dout1(p8[1]), .dout2(p8[2]), .dout3(p8[3]), .dout4(p8[4]), .dout5(p8[5]),
        .dout6(p8[6]), .dout7(p8[7]), .dout8(p8[8]), .dout9(p8[9]), .dout10(p8[10]), .dout11(p8[11]),
        .dout12(p8[12]), .dout13(p8[13]), .dout14(p8[14]), .dout15(p8[15]));

    function void build(); svunit_ut = new(name); endfunction
    task setup();    svunit_ut.setup();    endtask
    task teardown(); svunit_ut.teardown(); endtask

    `SVUNIT_TESTS_BEGIN
    `include "qick_vec2bit_tests.sv"
    `SVUNIT_TESTS_END
endmodule
