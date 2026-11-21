// ============================================================================
// File: ctrl_sgmux8_tc00.sv
// Description: SVUnit testbench top-level for ctrl_sgmux8.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module ctrl_sgmux8_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "ctrl_sgmux8_ut";
    svunit_testcase svunit_ut;

    localparam real CLOCK_FREQUENCY = 200e6;

    logic tb_clk  = 1'b0;
    logic tb_rstn = 1'b1;

    clk_gen #(.FREQ (CLOCK_FREQUENCY)) u_clk (.i_enable(1'b1), .o_clk(tb_clk));

    logic        tb_fifo_rd_en_o;
    logic        tb_fifo_empty_i;
    logic [39:0] tb_fifo_dout_i;
    logic [7:0]  tb_mask_o;
    logic        tb_en_o;

    initial begin
        $dumpfile("ctrl_sgmux8.vcd");
        $dumpvars();
    end

    ctrl_sgmux8 dut (
        .rstn         (tb_rstn),
        .clk          (tb_clk),
        .fifo_rd_en_o (tb_fifo_rd_en_o),
        .fifo_empty_i (tb_fifo_empty_i),
        .fifo_dout_i  (tb_fifo_dout_i),
        .mask_o       (tb_mask_o),
        .en_o         (tb_en_o)
    );

    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        tb_fifo_empty_i = 1'b1;
        tb_fifo_dout_i  = '0;
        reset_dut();
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    task automatic reset_dut();
        tb_rstn = 1'b0;
        repeat(4) @(posedge tb_clk);
        tb_rstn = 1'b1;
        repeat(4) @(posedge tb_clk);
    endtask

    // Presents one descriptor {mask, nsamp} on the fifo interface for
    // exactly one cycle: the DUT is expected to sample it via fifo_rd_en_o
    // while empty is low, same as a real single-entry fifo pop.
    task automatic push_descriptor(input logic [7:0] mask, input logic [31:0] nsamp);
        @(negedge tb_clk);
        tb_fifo_dout_i  = {mask, nsamp};
        tb_fifo_empty_i = 1'b0;
        // Wait for the DUT to actually pop (fifo_rd_en_o high) in READ_ST.
        wait (tb_fifo_rd_en_o === 1'b1);
        @(posedge tb_clk);
        @(negedge tb_clk);
        tb_fifo_empty_i = 1'b1;
    endtask

    // Bounded-poll helper: waits up to max_cycles for en_o to reach `value`.
    task automatic wait_for_en(input logic value, input int max_cycles, output bit reached);
        int n;
        reached = 1'b0;
        for (n = 0; n < max_cycles; n++) begin
            if (tb_en_o === value) begin
                reached = 1'b1;
                break;
            end
            @(posedge tb_clk);
        end
    endtask

    // Bounded-poll helper: waits up to max_cycles for fifo_rd_en_o to reach
    // `value` (used to confirm the FSM is back in READ_ST).
    task automatic wait_for_rd_en(input logic value, input int max_cycles, output bit reached);
        int n;
        reached = 1'b0;
        for (n = 0; n < max_cycles; n++) begin
            if (tb_fifo_rd_en_o === value) begin
                reached = 1'b1;
                break;
            end
            @(posedge tb_clk);
        end
    endtask


    // =========================================================================
    // Descriptor lengths: a second controller fed by a model of the read side of fifo_sync
    // with HOLD_DOUT = 1, the descriptor FIFO of sg_mux8 and sg_mixmux8: during a read (rd_en & ~empty) dout is the
    // head word, afterwards it holds the word just read.
    // =========================================================================
    localparam int LQ_W = 40;
    logic            lq_rstn = 1'b0;
    logic [LQ_W-1:0] lq_mem [64];
    int              lq_rd = 0, lq_wr = 0;
    logic [LQ_W-1:0] lq_hold = '0;
    logic            lq_rd_en, lq_empty, lq_pop;
    logic [LQ_W-1:0] lq_dout;
    assign lq_empty = (lq_rd == lq_wr);
    assign lq_pop   = lq_rstn && lq_rd_en && !lq_empty;
    assign lq_dout  = lq_pop ? lq_mem[lq_rd % 64] : lq_hold;
    always @(posedge tb_clk)
        if (lq_pop) begin
            lq_hold <= lq_mem[lq_rd % 64];
            lq_rd   <= lq_rd + 1;
        end

    ctrl_sgmux8 dut_len (
        .rstn (lq_rstn), .clk (tb_clk),
        .fifo_rd_en_o (lq_rd_en), .fifo_empty_i (lq_empty), .fifo_dout_i (lq_dout),
        .mask_o (), .en_o ()
    );

    // Plays the descriptors back to back from reset and returns the clocks between consecutive
    // pops, the length of every descriptor but the last; -1 when no pop came for timeout clocks.
    task automatic play_descriptors(input logic [LQ_W-1:0] descr[$], input int timeout, output int len[$]);
        int cycle = 0, last = 0, idle = 0, pops = 0;
        len = {};
        @(negedge tb_clk);
        lq_rstn = 1'b0;
        lq_rd   = 0;
        lq_hold = '0;
        foreach (descr[i]) lq_mem[i] = descr[i];
        lq_wr = descr.size();
        repeat (4) @(negedge tb_clk);
        lq_rstn = 1'b1;
        forever begin
            @(posedge tb_clk);
            cycle++;
            if (lq_pop) begin
                if (last > 0) len.push_back(cycle - last);
                last = cycle;
                idle = 0;
                if (++pops == descr.size()) break;
            end else if (++idle > timeout) begin
                len.push_back(-1);
                break;
            end
        end
        @(negedge tb_clk);
        lq_rstn = 1'b0;
    endtask

    `SVUNIT_TESTS_BEGIN
    `include "ctrl_sgmux8_tests.sv"
    `SVUNIT_TESTS_END

endmodule
