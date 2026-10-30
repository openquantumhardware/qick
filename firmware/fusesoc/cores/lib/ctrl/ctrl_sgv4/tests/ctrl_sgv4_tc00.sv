// ============================================================================
// File: ctrl_sgv4_tc00.sv
// Description: SVUnit testbench top-level for ctrl_sgv4 (signal gen v4 control).
//
//   Verifies the FIFO-descriptor decode, the READ/CNT FSM, the FIFO read
//   handshake, and the pipeline timing of the control outputs (gain, src,
//   stdy, addr, en, iqsel). Pipeline latencies are NOT assumed: they are
//   measured at runtime by driving a known descriptor and counting cycles until
//   each field appears on the output.
//
//   Waveform descriptor (160 bits) - v4 format:
//     [149] iqsel | [148] phrst | [147] stdysel | [146] mode |
//     [145:144] outsel | [143:128] nsamp | [111:96] gain |
//     [79:64] addr | [63:32] phase | [31:0] freq
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module ctrl_sgv4_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "ctrl_sgv4_ut";
    svunit_testcase svunit_ut;

    // =========================================================================
    // Parameters
    // =========================================================================
    localparam real CLOCK_FREQUENCY = 200e6;
    localparam int  N     = 16;
    localparam int  N_DDS = 8;          // v4 has 8 lanes
    localparam int  MAXV  = 2**15 - 2;   // 32766, from the driver

    // =========================================================================
    // Clock & Reset
    // =========================================================================
    logic tb_clk  = 1'b0;
    logic tb_rstn = 1'b1;

    clk_gen #(.FREQ (CLOCK_FREQUENCY)) u_clk (.i_enable(1'b1), .o_clk(tb_clk));

    // =========================================================================
    // DUT signals
    // =========================================================================
    logic                 tb_fifo_rd_en;
    logic                 tb_fifo_empty = 1'b1;
    logic [159:0]         tb_fifo_dout  = '0;
    logic [N_DDS*72-1:0]  tb_dds_ctrl;
    logic [N-1:0]         tb_mem_addr;
    logic [15:0]          tb_gain;
    logic [1:0]           tb_src;
    logic                 tb_stdy;
    logic                 tb_en;
    logic                 tb_iqsel;      // v4 specific

    // =========================================================================
    // Clocking block
    // =========================================================================
    default clocking tb_cb @(posedge tb_clk);
        default input #1step output #2;
        output tb_rstn;
        output tb_fifo_empty;
        output tb_fifo_dout;
        input  tb_fifo_rd_en;
        input  tb_mem_addr;
        input  tb_gain;
        input  tb_src;
        input  tb_stdy;
        input  tb_en;
        input  tb_iqsel;        // v4 specific
    endclocking

    // =========================================================================
    // Dump
    // =========================================================================
    initial begin
        $dumpfile("ctrl_sgv4.vcd");
        $dumpvars();
    end

    // =========================================================================
    // DUT
    // =========================================================================
    ctrl_sgv4 #(
        .N     (N),
        .N_DDS (N_DDS)
    ) dut (
        .i_rstn       (tb_rstn),
        .i_clk        (tb_clk),
        .o_fifo_rd_en (tb_fifo_rd_en),
        .i_fifo_empty (tb_fifo_empty),
        .i_fifo_dout  (tb_fifo_dout),
        .o_dds_ctrl   (tb_dds_ctrl),
        .o_mem_addr   (tb_mem_addr),
        .o_gain       (tb_gain),
        .o_src        (tb_src),
        .o_stdy       (tb_stdy),
        .o_en         (tb_en),
        .o_iqsel      (tb_iqsel)     // v4 specific
    );

    // =========================================================================
    // Helper: build a 160-bit waveform descriptor (v4 format).
    // =========================================================================
    function automatic logic [159:0] build_descr(
        input logic [31:0] freq,
        input logic [31:0] phase,
        input logic [15:0] addr,
        input logic [15:0] gain,
        input logic [15:0] nsamp,
        input logic [1:0]  outsel,
        input logic        mode,
        input logic        stdysel,
        input logic        phrst,
        input logic        iqsel     // v4 specific
    );
        logic [159:0] d;
        d = '0;
        d[31:0]    = freq;
        d[63:32]   = phase;
        d[79:64]   = addr;
        d[111:96]  = gain;
        d[143:128] = nsamp;
        d[145:144] = outsel;
        d[146]     = mode;
        d[147]     = stdysel;
        d[148]     = phrst;
        d[149]     = iqsel;     // v4 specific
        return d;
    endfunction

    // =========================================================================
    // FIFO model: present one descriptor, drop empty, honor rd_en.
    // =========================================================================
    task automatic push_descriptor(input logic [159:0] descr);
        tb_cb.tb_fifo_dout  <= descr;
        tb_cb.tb_fifo_empty <= 1'b0;
        @(tb_cb);
        while (!tb_fifo_rd_en) @(tb_cb);
        tb_cb.tb_fifo_empty <= 1'b1;
        @(tb_cb);
    endtask

    // Keep the FIFO continuously non-empty with a given descriptor.
    task automatic hold_descriptor(input logic [159:0] descr);
        tb_cb.tb_fifo_dout  <= descr;
        tb_cb.tb_fifo_empty <= 1'b0;
    endtask

    // =========================================================================
    // Measure pipeline latencies.
    // =========================================================================
    task automatic measure_gain_latency(
        input  logic [159:0] descr,
        input  logic [15:0]  exp_gain,
        output int           latency,
        input  int           timeout = 64
    );
        int t = 0;
        latency = -1;
        hold_descriptor(descr);
        @(tb_cb);
        while (!tb_fifo_rd_en && t < timeout) begin @(tb_cb); t++; end
        t = 0;
        while (tb_gain !== exp_gain && t < timeout) begin
            @(tb_cb);
            t++;
        end
        if (tb_gain === exp_gain) latency = t;
    endtask

    task automatic measure_iqsel_latency(
        input  logic [159:0] descr,
        input  logic         exp_iqsel,
        output int           latency,
        input  int           timeout = 64
    );
        int t = 0;
        latency = -1;
        hold_descriptor(descr);
        @(tb_cb);
        while (!tb_fifo_rd_en && t < timeout) begin @(tb_cb); t++; end
        t = 0;
        while (tb_iqsel !== exp_iqsel && t < timeout) begin
            @(tb_cb);
            t++;
        end
        if (tb_iqsel === exp_iqsel) latency = t;
    endtask

    // =========================================================================
    // SVUnit
    // =========================================================================
    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        tb_cb.tb_rstn       <= 1'b0;
        tb_cb.tb_fifo_empty <= 1'b1;
        tb_cb.tb_fifo_dout  <= '0;
        repeat(10) @(tb_cb);
        tb_cb.tb_rstn <= 1'b1;
        repeat(5) @(tb_cb);
    endtask

    task teardown();
        svunit_ut.teardown();
        tb_cb.tb_fifo_empty <= 1'b1;
        repeat(5) @(tb_cb);
    endtask

    // Global timeout
    initial begin
        #50_000_000;
        $display("INFO: Global timeout reached");
        $finish;
    end


    // =========================================================================
    // Descriptor lengths: a second controller fed by a model of the read side of fifo_sync
    // with HOLD_DOUT = 1, the descriptor FIFO of sg_int4_top: during a read (rd_en & ~empty) dout is the
    // head word, afterwards it holds the word just read.
    // =========================================================================
    localparam int LQ_W = 160;
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

    ctrl_sgv4 #(.N (N), .N_DDS (N_DDS)) dut_len (
        .i_rstn (lq_rstn), .i_clk (tb_clk),
        .o_fifo_rd_en (lq_rd_en), .i_fifo_empty (lq_empty), .i_fifo_dout (lq_dout),
        .o_dds_ctrl (), .o_mem_addr (), .o_gain (), .o_src (), .o_stdy (), .o_en (), .o_iqsel ()
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
    `include "ctrl_sgv4_tests.sv"
    `SVUNIT_TESTS_END

endmodule
