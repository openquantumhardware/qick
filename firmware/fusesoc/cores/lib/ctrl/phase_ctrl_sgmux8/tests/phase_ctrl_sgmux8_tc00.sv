// ============================================================================
// File: phase_ctrl_sgmux8_tc00.sv
// Description: SVUnit testbench top-level for phase_ctrl_sgmux8.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module phase_ctrl_sgmux8_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "phase_ctrl_sgmux8_ut";
    svunit_testcase svunit_ut;

    localparam real CLOCK_FREQUENCY = 200e6;
    localparam int  N_DDS           = 2;

    logic tb_clk  = 1'b0;
    logic tb_rstn = 1'b1;

    clk_gen #(.FREQ (CLOCK_FREQUENCY)) u_clk (.i_enable(1'b1), .o_clk(tb_clk));

    logic [N_DDS*72-1:0] tb_dds_ctrl_o;
    logic [31:0]         tb_pinc_reg;
    logic [31:0]         tb_poff_reg;
    logic                tb_we_reg;

    initial begin
        $dumpfile("phase_ctrl_sgmux8.vcd");
        $dumpvars();
    end

    phase_ctrl_sgmux8 #(
        .N_DDS (N_DDS)
    ) dut (
        .rstn       (tb_rstn),
        .clk        (tb_clk),
        .dds_ctrl_o (tb_dds_ctrl_o),
        .pinc_reg   (tb_pinc_reg),
        .poff_reg   (tb_poff_reg),
        .we_reg     (tb_we_reg)
    );

    // Per-lane field extraction.
    function automatic logic [7:0] lane_opcode(int lane);
        return tb_dds_ctrl_o[lane*72+64+:8];
    endfunction
    function automatic logic [31:0] lane_phase(int lane);
        return tb_dds_ctrl_o[lane*72+32+:32];
    endfunction
    function automatic logic [31:0] lane_pinc_n(int lane);
        return tb_dds_ctrl_o[lane*72+:32];
    endfunction

    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        tb_pinc_reg = '0;
        tb_poff_reg = '0;
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
        // mult_32x32 has no reset of its own (matches the legacy IP): its
        // internal pipeline registers only become defined once the phase
        // registers driving them have flushed through, which needs the
        // full 6-cycle mult latency plus a couple of settle cycles.
        repeat(12) @(posedge tb_clk);
    endtask

    // Pulses we_reg long enough to clear the cdc_bit_sync resync latency
    // (2 stages) plus latch it on a clk edge.
    task automatic write_regs(input logic [31:0] pinc, input logic [31:0] poff);
        @(negedge tb_clk);
        tb_pinc_reg = pinc;
        tb_poff_reg = poff;
        tb_we_reg   = 1'b1;
        repeat(4) @(posedge tb_clk);
        @(negedge tb_clk);
        tb_we_reg = 1'b0;
        // Let the mult_32x32 pipeline (6 cycles) and phase pipeline settle.
        repeat(10) @(posedge tb_clk);
        @(negedge tb_clk);
    endtask

    `SVUNIT_TESTS_BEGIN
    `include "phase_ctrl_sgmux8_tests.sv"
    `SVUNIT_TESTS_END

endmodule
