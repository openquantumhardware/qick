// ============================================================================
// File: fifo_axi_tc00.sv
// Description: SVUnit testbench for fifo_axi.
//
//   The port next to the legacy VHDL (tests/ref), B = 100, N = 8, on random
//   traffic. An always-on checker compares dout, full and empty with !== on
//   every falling edge (mism).
//
//   Inputs are driven with a non-blocking assignment right after a rising
//   edge; outputs are sampled on the falling edge.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module fifo_axi_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "fifo_axi_ut";
    svunit_testcase svunit_ut;

    localparam real CLOCK_FREQUENCY = 300e6;
    localparam int  B = 100, N = 8;

    logic clk = 1'b0;
    logic rstn = 1'b1;
    clk_gen #(.FREQ(CLOCK_FREQUENCY)) u_clk (.i_enable(1'b1), .o_clk(clk));

    logic         wr_en = 1'b0, rd_en = 1'b0;
    logic [B-1:0] din = '0;
    logic [B-1:0] p_dout, l_dout;
    logic         p_full, l_full, p_empty, l_empty;

    fifo_axi #(.B(B), .N(N)) dut (
        .rstn(rstn), .clk(clk), .wr_en(wr_en), .din(din), .rd_en(rd_en),
        .dout(p_dout), .full(p_full), .empty(p_empty));

    fifo_axi_legacy #(.B(B), .N(N)) ref_i (
        .rstn(rstn), .clk(clk), .wr_en(wr_en), .din(din), .rd_en(rd_en),
        .dout(l_dout), .full(l_full), .empty(l_empty));

    bit cmp_en = 1'b0;
    int mism = 0, n_full = 0, n_empty_after = 0, n_pop = 0;

    always @(negedge clk) if (cmp_en) begin
        if (p_dout !== l_dout || p_full !== l_full || p_empty !== l_empty) mism++;
        if (l_full) n_full++;
        if (rd_en && !l_empty) n_pop++;
    end

    // Words read out, to check the order.
    logic [B-1:0] o_data [$];
    always @(negedge clk) if (cmp_en && rd_en && !p_empty) o_data.push_back(p_dout);

    task automatic step(input logic w, input logic r, input logic [B-1:0] d);
        @(posedge clk);
        wr_en <= w;
        rd_en <= r;
        din   <= d;
    endtask

    function automatic logic [B-1:0] rand_word();
        logic [B-1:0] x;
        for (int i = 0; i < (B + 31) / 32; i++) x[i*32 +: 32] = $urandom;
        return x;
    endfunction

    task automatic reset_dut();
        @(posedge clk);
        rstn <= 1'b0;
        repeat (3) @(posedge clk);
        rstn <= 1'b1;
    endtask

    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        cmp_en = 1'b1;
        wr_en = 1'b0; rd_en = 1'b0; din = '0;
        reset_dut();
        mism = 0; n_full = 0; n_pop = 0;
        o_data.delete();
    endtask

    task teardown();
        svunit_ut.teardown();
        cmp_en = 1'b0;
    endtask

    `SVUNIT_TESTS_BEGIN
    `include "fifo_axi_tests.sv"
    `SVUNIT_TESTS_END
endmodule
