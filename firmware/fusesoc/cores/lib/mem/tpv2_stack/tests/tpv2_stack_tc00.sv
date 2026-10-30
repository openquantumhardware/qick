//------------------------------------------------------------------------------
// Testbench: tpv2_stack_tc00
// Description:
//   Unit tests for the tProcessor v2 CALL/RET PC stack (tpv2_stack, ported
//   from LIFO in firmware/ip/qick_processor/src/_qproc_ips.sv).
//------------------------------------------------------------------------------

`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module tpv2_stack_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "tpv2_stack_ut";
    svunit_testcase svunit_ut;

    localparam real CLOCK_FREQUENCY = 200e6;
    localparam int  WIDTH = 8;   // mirrors qcore_cpu's PMEM_AW default
    localparam int  DEPTH = 8;   // the only value ever instantiated in tprocv2

    logic             tb_clk  = 1'b0;
    logic             tb_rstn = 1'b1;
    logic [WIDTH-1:0] tb_data_i;
    logic             tb_push;
    logic             tb_pop;
    logic [WIDTH-1:0] tb_data_o;
    logic             tb_full;

    clk_gen #(.FREQ (CLOCK_FREQUENCY)) u_clk (.i_enable(1'b1), .o_clk(tb_clk));

    default clocking cb @(posedge tb_clk);
        default input #1step output #2;
        output tb_data_i;
        output tb_push;
        output tb_pop;
        input  tb_data_o;
        input  tb_full;
    endclocking

    tpv2_stack #(
        .WIDTH (WIDTH),
        .DEPTH (DEPTH)
    ) dut (
        .clk_i  (tb_clk),
        .rst_ni (tb_rstn),
        .data_i (tb_data_i),
        .push   (tb_push),
        .pop    (tb_pop),
        .data_o (tb_data_o),
        .full_o (tb_full)
    );

    initial begin
        $dumpfile("tpv2_stack.vcd");
        $dumpvars();
    end

    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        tb_rstn    = 1'b0;
        tb_data_i  = '0;
        tb_push    = 1'b0;
        tb_pop     = 1'b0;
        repeat(4) @(cb);
        tb_rstn = 1'b1;
        repeat(4) @(cb);
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    `SVUNIT_TESTS_BEGIN
    `include "tpv2_stack_tests.sv"
    `SVUNIT_TESTS_END

endmodule
