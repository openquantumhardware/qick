// ============================================================================
// File: fir_interp4_sgint_tc00.sv
// Description: SVUnit testbench top-level for fir_interp4_sgint.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module fir_interp4_sgint_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "fir_interp4_sgint_ut";
    svunit_testcase svunit_ut;

    localparam real CLOCK_FREQUENCY = 200e6;
    localparam int  LATENCY         = 12;

    logic tb_clk = 1'b0;

    clk_gen #(.FREQ (CLOCK_FREQUENCY)) u_clk (.i_enable(1'b1), .o_clk(tb_clk));

    logic         tb_s_tvalid;
    logic         tb_s_tready;
    logic [31:0]  tb_s_tdata;
    logic         tb_m_tvalid;
    logic [127:0] tb_m_tdata;

    initial begin
        $dumpfile("fir_interp4_sgint.vcd");
        $dumpvars();
    end

    fir_interp4_sgint #(
        .LATENCY (LATENCY)
    ) dut (
        .aclk               (tb_clk),
        .s_axis_data_tvalid (tb_s_tvalid),
        .s_axis_data_tready (tb_s_tready),
        .s_axis_data_tdata  (tb_s_tdata),
        .m_axis_data_tvalid (tb_m_tvalid),
        .m_axis_data_tdata  (tb_m_tdata)
    );

    function automatic logic [15:0] lane_real(int lane);
        return tb_m_tdata[lane*32+:16];
    endfunction
    function automatic logic [15:0] lane_imag(int lane);
        return tb_m_tdata[lane*32+16+:16];
    endfunction

    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        tb_s_tvalid = 1'b1;
        tb_s_tdata  = '0;
        // Flush the reset-time X's through the input-history/pipe registers
        // (no reset port on this model -- matches the real Xilinx IP, whose
        // pipeline is not resettable either).
        repeat(LATENCY + 10) @(posedge tb_clk);
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    task automatic drive_real_sample(input logic [15:0] real_v, input logic [15:0] imag_v);
        @(negedge tb_clk);
        tb_s_tdata = {imag_v, real_v};
        @(posedge tb_clk);
    endtask

    `SVUNIT_TESTS_BEGIN
    `include "fir_interp4_sgint_tests.sv"
    `SVUNIT_TESTS_END

endmodule
