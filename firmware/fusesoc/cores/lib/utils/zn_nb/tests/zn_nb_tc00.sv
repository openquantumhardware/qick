///////////////////////////////////////////////////////////////////////////////
// File: zn_nb_tc00.sv
// Description: SVUnit testbench top-level for the zn_nb module.
// Reset: synchronous active-low, matches zn_nb.sv.
///////////////////////////////////////////////////////////////////////////////

`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module zn_nb_unit_test;

    import svunit_pkg::svunit_testcase;

    string name = "zn_nb_ut";
    svunit_testcase svunit_ut;

    // =========================================================================
    // Parameters — must match DUT
    // =========================================================================
    localparam int B = 16;
    localparam int N = 4;

    // =========================================================================
    // Clock & Reset
    // =========================================================================
    logic tb_aclk    = 1'b0;
    logic tb_aresetn = 1'b0;

    // =========================================================================
    // DUT interfaces
    // =========================================================================
    logic          tb_s_axis_tvalid = 1'b0;
    logic [B-1:0]  tb_s_axis_tdata  = '0;
    logic          tb_m_axis_tvalid;
    logic [B-1:0]  tb_m_axis_tdata;

    // =========================================================================
    // Waveform dump
    // =========================================================================
    initial begin
        $dumpfile("zn_nb.vcd");
        $dumpvars();
    end


    // =========================================================================
    // Clock generator: 200 MHz
    // =========================================================================
    always #2.5 tb_aclk = ~tb_aclk;

    // =========================================================================
    // Clocking block
    // =========================================================================
    default clocking cb @(posedge tb_aclk);
        output tb_aresetn;
        output tb_s_axis_tvalid;
        output tb_s_axis_tdata;
        input  tb_m_axis_tvalid;
        input  tb_m_axis_tdata;
    endclocking

    // =========================================================================
    // DUT
    // =========================================================================
    zn_nb #(
        .B (B),
        .N (N)
    ) u_zn_nb (
        .aclk           (tb_aclk),
        .aresetn        (tb_aresetn),
        .s_axis_tvalid  (tb_s_axis_tvalid),
        .s_axis_tdata   (tb_s_axis_tdata),
        .m_axis_tvalid  (tb_m_axis_tvalid),
        .m_axis_tdata   (tb_m_axis_tdata)
    );

    // =========================================================================
    // Helper tasks
    // =========================================================================

    // reset_dut: synchronous active-low reset sequence.
    // aresetn is sampled on posedge aclk, so hold for several cycles.
    task automatic reset_dut();
        cb.tb_aresetn       <= 1'b0;
        cb.tb_s_axis_tvalid <= 1'b0;
        cb.tb_s_axis_tdata  <= '0;
        repeat(5) @(cb);    // hold reset for 5 clock edges
        cb.tb_aresetn <= 1'b1;
        repeat(3) @(cb);    // settling margin
    endtask

    // push_sample: drive one sample for one cycle.
    task automatic push_sample(input logic [B-1:0] data);
        cb.tb_s_axis_tdata  <= data;
        cb.tb_s_axis_tvalid <= 1'b1;
        @(cb);
        cb.tb_s_axis_tvalid <= 1'b0;
        cb.tb_s_axis_tdata  <= '0;
    endtask

    // push_stream: drive count consecutive samples starting at start_val,
    // incrementing by 1 each cycle.
    task automatic push_stream(input int count, input logic [B-1:0] start_val);
        for (int i = 0; i < count; i++) begin
            cb.tb_s_axis_tdata  <= start_val + B'(i);
            cb.tb_s_axis_tvalid <= 1'b1;
            @(cb);
        end
        cb.tb_s_axis_tvalid <= 1'b0;
        cb.tb_s_axis_tdata  <= '0;
    endtask

    // push_const: drive count cycles of the same constant value.
    task automatic push_const(input int count, input logic [B-1:0] data);
        for (int i = 0; i < count; i++) begin
            cb.tb_s_axis_tdata  <= data;
            cb.tb_s_axis_tvalid <= 1'b1;
            @(cb);
        end
        cb.tb_s_axis_tvalid <= 1'b0;
        cb.tb_s_axis_tdata  <= '0;
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
    `include "tests.sv"
    `SVUNIT_TESTS_END

endmodule
