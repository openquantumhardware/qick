// ============================================================================
// File: dds_compiler_dyn_readout_lat9_tc00.sv
// Description: SVUnit testbench top-level for dds_compiler_dyn_readout_lat9:
//              the latency-9 wrapper next to the latency-8 one, same input.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module dds_compiler_dyn_readout_lat9_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "dds_compiler_dyn_readout_lat9_ut";
    svunit_testcase svunit_ut;

    localparam real CLOCK_FREQUENCY = 200e6;

    logic tb_clk = 1'b0;

    clk_gen #(.FREQ (CLOCK_FREQUENCY)) u_clk (.i_enable(1'b1), .o_clk(tb_clk));

    logic        tb_tvalid = 1'b0;
    logic [71:0] tb_tdata  = '0;
    logic        tb_v8, tb_v9;
    logic [31:0] tb_d8, tb_d9;

    initial begin
        $dumpfile("dds_compiler_dyn_readout_lat9.vcd");
        $dumpvars();
    end

    dds_compiler_dyn_readout_lat9 dut (
        .aclk                (tb_clk),
        .s_axis_phase_tvalid (tb_tvalid),
        .s_axis_phase_tdata  (tb_tdata),
        .m_axis_data_tvalid  (tb_v9),
        .m_axis_data_tdata   (tb_d9)
    );

    // Reference: the latency-8 variant the dyn readout used before.
    dds_compiler_dyn_readout ref_i (
        .aclk                (tb_clk),
        .s_axis_phase_tvalid (tb_tvalid),
        .s_axis_phase_tdata  (tb_tdata),
        .m_axis_data_tvalid  (tb_v8),
        .m_axis_data_tdata   (tb_d8)
    );

    // tdata = {7'b0, resync, poff[31:0], pinc[31:0]}
    task automatic drive(input logic valid, input logic resync, input logic [31:0] poff, input logic [31:0] pinc);
        @(negedge tb_clk);
        tb_tvalid = valid;
        tb_tdata  = {7'b0, resync, poff, pinc};
    endtask

    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    `SVUNIT_TESTS_BEGIN
    `include "dds_compiler_dyn_readout_lat9_tests.sv"
    `SVUNIT_TESTS_END

endmodule
