// ============================================================================
// File: dds_compiler_dyn_readout_tc00.sv
// Description: SVUnit testbench top-level for dds_compiler_dyn_readout.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module dds_compiler_dyn_readout_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "dds_compiler_dyn_readout_ut";
    svunit_testcase svunit_ut;

    localparam real CLOCK_FREQUENCY = 200e6;

    logic tb_clk  = 1'b0;
    logic tb_rstn = 1'b1;

    clk_gen #(.FREQ (CLOCK_FREQUENCY)) u_clk (.i_enable(1'b1), .o_clk(tb_clk));

    // TODO: declare DUT signals

    initial begin
        $dumpfile("dds_compiler_dyn_readout.vcd");
        $dumpvars();
    end

    // TODO: instantiate the DUT
    // dds_compiler_dyn_readout dut ( ... );

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
    `include "dds_compiler_dyn_readout_tests.sv"
    `SVUNIT_TESTS_END

endmodule
