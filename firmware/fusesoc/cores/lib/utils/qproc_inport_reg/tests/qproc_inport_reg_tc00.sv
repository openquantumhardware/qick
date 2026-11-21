// ============================================================================
// File: qproc_inport_reg_tc00.sv
// Description: SVUnit testbench top-level for qproc_inport_reg.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module qproc_inport_reg_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "qproc_inport_reg_ut";
    svunit_testcase svunit_ut;

    // =========================================================================
    // Parameters
    // =========================================================================
    localparam real CLOCK_FREQUENCY = 200e6;
    localparam int  PORT_QTY = 2;

    // =========================================================================
    // Clock & Reset
    // =========================================================================
    logic tb_clk  = 1'b0;
    logic tb_rstn = 1'b1;

    clk_gen #(.FREQ (CLOCK_FREQUENCY)) u_clk_gen (
        .i_enable (1'b1),
        .o_clk    (tb_clk)
    );

    // =========================================================================
    // DUT signals
    // =========================================================================
    logic        tb_clear = 1'b0;
    logic        tb_port_tvalid_i [PORT_QTY];
    logic [63:0] tb_port_tdata_i  [PORT_QTY];
    logic [15:0] tb_port_tnew_o;
    logic [63:0] tb_port_tdata_o  [PORT_QTY];

    initial begin
        $dumpfile("qproc_inport_reg.vcd");
        $dumpvars();
    end

    // =========================================================================
    // DUT
    // =========================================================================
    qproc_inport_reg #(
        .PORT_QTY (PORT_QTY)
    ) u_dut (
        .c_clk_i      (tb_clk),
        .c_rst_ni     (tb_rstn),
        .c_clear      (tb_clear),
        .port_tvalid_i(tb_port_tvalid_i),
        .port_tdata_i (tb_port_tdata_i),
        .port_tnew_o  (tb_port_tnew_o),
        .port_tdata_o (tb_port_tdata_o)
    );

    // =========================================================================
    // Helper tasks
    // =========================================================================
    task automatic reset_dut();
        tb_rstn = 1'b0;
        tb_clear = 1'b0;
        for (int i = 0; i < PORT_QTY; i++) begin
            tb_port_tvalid_i[i] = 1'b0;
            tb_port_tdata_i[i]  = '0;
        end
        repeat(10) @(posedge tb_clk);
        tb_rstn = 1'b1;
        repeat(5) @(posedge tb_clk);
    endtask

    // Drive a single-cycle valid pulse with data on port `idx`.
    task automatic push_data(input int idx, input logic [63:0] data);
        @(negedge tb_clk);
        tb_port_tvalid_i[idx] = 1'b1;
        tb_port_tdata_i[idx]  = data;
        @(negedge tb_clk);
        tb_port_tvalid_i[idx] = 1'b0;
    endtask

    // Pulse c_clear for a single cycle.
    task automatic pulse_clear();
        @(negedge tb_clk);
        tb_clear = 1'b1;
        @(negedge tb_clk);
        tb_clear = 1'b0;
    endtask

    // =========================================================================
    // SVUnit build / setup / teardown
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

    // =========================================================================
    // Test cases
    // =========================================================================
    `SVUNIT_TESTS_BEGIN
    `include "qproc_inport_reg_tests.sv"
    `SVUNIT_TESTS_END

endmodule
