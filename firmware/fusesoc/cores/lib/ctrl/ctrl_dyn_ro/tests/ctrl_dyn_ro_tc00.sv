// ============================================================================
// File: ctrl_dyn_ro_tc00.sv
// Description: SVUnit testbench top-level for ctrl_dyn_ro.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module ctrl_dyn_ro_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "ctrl_dyn_ro_ut";
    svunit_testcase svunit_ut;

    localparam real CLOCK_FREQUENCY = 200e6;
    localparam int  N = 8;

    logic tb_clk    = 1'b0;
    logic tb_aresetn = 1'b1;

    clk_gen #(.FREQ (CLOCK_FREQUENCY)) u_clk (.i_enable(1'b1), .o_clk(tb_clk));

    logic          tb_fifo_rd_en;
    logic          tb_fifo_empty;
    logic [87:0]   tb_fifo_dout;
    logic [N*72-1:0] tb_dds_ctrl;
    logic [1:0]    tb_outsel;

    initial begin
        $dumpfile("ctrl_dyn_ro.vcd");
        $dumpvars();
    end

    ctrl_dyn_ro #(
        .N (N)
    ) dut (
        .aresetn    (tb_aresetn),
        .aclk       (tb_clk),
        .fifo_rd_en (tb_fifo_rd_en),
        .fifo_empty (tb_fifo_empty),
        .fifo_dout  (tb_fifo_dout),
        .dds_ctrl   (tb_dds_ctrl),
        .outsel     (tb_outsel)
    );

    function automatic logic [31:0] lane_phase(int lane);
        return tb_dds_ctrl[lane*72+32+:32];
    endfunction
    function automatic logic [31:0] lane_pinc_n(int lane);
        return tb_dds_ctrl[lane*72+:32];
    endfunction

    function automatic logic [87:0] build_descr(
        input logic [31:0] freq, input logic [31:0] phase,
        input logic [15:0] nsamp, input logic [1:0] outsel,
        input logic mode, input logic phrst
    );
        logic [87:0] d = '0;
        d[31:0]  = freq;
        d[63:32] = phase;
        d[79:64] = nsamp;
        d[81:80] = outsel;
        d[82]    = mode;
        d[83]    = phrst;
        return d;
    endfunction

    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        tb_fifo_empty = 1'b1;
        tb_fifo_dout  = '0;
        reset_dut();
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    task automatic reset_dut();
        tb_aresetn = 1'b0;
        repeat(4) @(posedge tb_clk);
        tb_aresetn = 1'b1;
        repeat(4) @(posedge tb_clk);
    endtask

    // Presents one descriptor for exactly one cycle: the DUT is expected to
    // pop it via fifo_rd_en while empty is low.
    task automatic push_descriptor(input logic [87:0] descr);
        @(negedge tb_clk);
        tb_fifo_dout  = descr;
        tb_fifo_empty = 1'b0;
        wait (tb_fifo_rd_en === 1'b1);
        @(posedge tb_clk);
        @(negedge tb_clk);
        tb_fifo_empty = 1'b1;
        // Let the pinc multiply + phase pipeline settle (mirrors
        // phase_ctrl_sgmux8's settle margin).
        repeat(15) @(posedge tb_clk);
        @(negedge tb_clk);
    endtask

    // =========================================================================
    // Descriptor lengths: a second controller fed by a model of the read side of fifo_sync
    // with HOLD_DOUT = 1, the descriptor FIFO of axis_dyn_readout_v1 and axis_readout_v3: during a read (rd_en & ~empty) dout is the
    // head word, afterwards it holds the word just read.
    // =========================================================================
    localparam int LQ_W = 88;
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

    ctrl_dyn_ro #(.N (N)) dut_len (
        .aresetn (lq_rstn), .aclk (tb_clk),
        .fifo_rd_en (lq_rd_en), .fifo_empty (lq_empty), .fifo_dout (lq_dout),
        .dds_ctrl (), .outsel ()
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
    `include "ctrl_dyn_ro_tests.sv"
    `SVUNIT_TESTS_END

endmodule
