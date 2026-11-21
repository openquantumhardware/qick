// ============================================================================
// File: fir_decim8_dynro_tc00.sv
// Description: SVUnit testbench top-level for fir_decim8_dynro.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module fir_decim8_dynro_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "fir_decim8_dynro_ut";
    svunit_testcase svunit_ut;

    localparam real CLOCK_FREQUENCY = 200e6;
    localparam int  N_DDS   = 8;
    localparam int  LATENCY = 8;

    logic tb_clk = 1'b0;

    clk_gen #(.FREQ (CLOCK_FREQUENCY)) u_clk (.i_enable(1'b1), .o_clk(tb_clk));

    logic                  tb_s_tvalid;
    logic                  tb_s_tready;
    logic [N_DDS*32-1:0]   tb_s_tdata;
    logic                  tb_m_tvalid;
    logic [31:0]           tb_m_tdata;

    initial begin
        $dumpfile("fir_decim8_dynro.vcd");
        $dumpvars();
    end

    fir_decim8_dynro #(
        .N_DDS   (N_DDS),
        .LATENCY (LATENCY)
    ) dut (
        .aclk               (tb_clk),
        .s_axis_data_tvalid (tb_s_tvalid),
        .s_axis_data_tready (tb_s_tready),
        .s_axis_data_tdata  (tb_s_tdata),
        .m_axis_data_tvalid (tb_m_tvalid),
        .m_axis_data_tdata  (tb_m_tdata)
    );

    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        tb_s_tvalid = 1'b1;
        tb_s_tdata  = '0;
        // Flush the reset-time X's AND any residual history from a prior
        // test: the 120-tap (15-block) history needs 15 cycles of zero
        // input to fully clear, plus LATENCY more for the output pipe to
        // drain the last nonzero samples (no reset port on this model --
        // matches the real Xilinx IP, so tests must self-isolate).
        repeat(15 + LATENCY + 10) @(posedge tb_clk);
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    // Drives one 8-lane block, all lanes set to the same {imag,real} pair.
    task automatic drive_const_block(input logic [15:0] real_v, input logic [15:0] imag_v);
        int i;
        @(negedge tb_clk);
        for (i = 0; i < N_DDS; i++)
            tb_s_tdata[i*32+:32] = {imag_v, real_v};
        @(posedge tb_clk);
    endtask

    task automatic drive_zero_block();
        drive_const_block(16'h0000, 16'h0000);
    endtask

    `SVUNIT_TESTS_BEGIN
    `include "fir_decim8_dynro_tests.sv"
    `SVUNIT_TESTS_END

endmodule
