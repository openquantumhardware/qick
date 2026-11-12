// ============================================================================
// File: dds_top_mixmux8_tc00.sv
// Description: SVUnit testbench top-level for dds_top_mixmux8.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module dds_top_mixmux8_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "dds_top_mixmux8_ut";
    svunit_testcase svunit_ut;

    localparam real CLOCK_FREQUENCY = 200e6;
    localparam int  N_DDS           = 2;

    logic tb_clk  = 1'b0;
    logic tb_rstn = 1'b1;

    clk_gen #(.FREQ (CLOCK_FREQUENCY)) u_clk (.i_enable(1'b1), .o_clk(tb_clk));

    logic [N_DDS*32-1:0] tb_dds_dout_o;
    logic [31:0]         tb_pinc_reg;
    logic [31:0]         tb_poff_reg;
    logic [15:0]         tb_gain_reg;
    logic                tb_we_reg;

    initial begin
        $dumpfile("dds_top_mixmux8.vcd");
        $dumpvars();
    end

    dds_top_mixmux8 #(
        .N_DDS (N_DDS)
    ) dut (
        .rstn       (tb_rstn),
        .clk        (tb_clk),
        .dds_dout_o (tb_dds_dout_o),
        .pinc_reg   (tb_pinc_reg),
        .poff_reg   (tb_poff_reg),
        .gain_reg   (tb_gain_reg),
        .we_reg     (tb_we_reg)
    );

    function automatic logic [15:0] lane_i(int lane);
        return tb_dds_dout_o[lane*32+:16];
    endfunction
    function automatic logic [15:0] lane_q(int lane);
        return tb_dds_dout_o[lane*32+16+:16];
    endfunction

    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        tb_pinc_reg = '0;
        tb_poff_reg = '0;
        tb_gain_reg = '0;
        tb_we_reg   = 1'b0;
        reset_dut();
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    task automatic reset_dut();
        tb_rstn = 1'b0;
        repeat(4) @(posedge tb_clk);
        tb_rstn = 1'b1;
        repeat(20) @(posedge tb_clk);
    endtask

    task automatic write_regs(input logic [31:0] pinc, input logic [31:0] poff, input logic [15:0] gain);
        @(negedge tb_clk);
        tb_pinc_reg = pinc;
        tb_poff_reg = poff;
        tb_gain_reg = gain;
        tb_we_reg   = 1'b1;
        repeat(4) @(posedge tb_clk);
        @(negedge tb_clk);
        tb_we_reg = 1'b0;
    endtask

    // Bounded-poll helper: waits up to max_cycles for either I or Q of lane
    // 0 to become nonzero (liveness -- exact waveform is dds_compiler_model's
    // responsibility, already covered by axis_signal_gen_v6's tests).
    task automatic wait_for_nonzero_output(input int max_cycles, output bit reached);
        int n;
        reached = 1'b0;
        for (n = 0; n < max_cycles; n++) begin
            if (lane_i(0) !== 16'h0000 || lane_q(0) !== 16'h0000) begin
                reached = 1'b1;
                break;
            end
            @(posedge tb_clk);
        end
    endtask

    `SVUNIT_TESTS_BEGIN
    `include "dds_top_mixmux8_tests.sv"
    `SVUNIT_TESTS_END

endmodule
