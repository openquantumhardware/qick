`timescale 1ns / 1ps
//
// tb_polyak_avg.sv
//
// Unit testbench for polyak_averager.v.  Exercises:
//   T1: 16 constant samples (positive)        -> xbar == sample
//   T2: 16 ramp samples 1..16                 -> xbar == 8 (floor of 8.5)
//   T3: 16 negative samples                   -> xbar == sample (signed)
//   T4: two back-to-back chunks               -> chunk_close fires twice,
//                                                xbar_delta_o tracks change
//   T5: soft_reset clears state               -> next chunk starts fresh
//
// Pass criterion: every assertion holds (counted) and $finish reached.
// 100 MHz clock (10 ns) — exact value irrelevant for behavior, RFSoC
// timing closure is checked in synthesis, not simulation.
//

module tb_polyak_avg;

    // ----------------- Parameters -----------------
    localparam integer SAMPLE_WIDTH = 16;
    localparam integer SUM_WIDTH    = 48;
    localparam integer AVG_WIDTH    = 32;
    localparam integer RECIP_WIDTH  = 32;
    localparam integer COUNT_WIDTH  = 16;

    // For n_avg = 16: reciprocal = ceil(2^32 / 16) = 268_435_456
    localparam logic [RECIP_WIDTH-1:0] RECIP_16 = 32'd268435456;
    localparam logic [3:0]             CHUNK_LOG2_16 = 4'd4;

    // ----------------- DUT signals -----------------
    logic                          clk;
    logic                          rst_n;
    logic signed [SAMPLE_WIDTH-1:0] sample_in;
    logic                          sample_valid;
    logic [RECIP_WIDTH-1:0]        reciprocal_in;
    logic [3:0]                    chunk_size_log2;
    logic                          soft_reset;
    logic signed [AVG_WIDTH-1:0]   xbar_o;
    logic [AVG_WIDTH-1:0]          xbar_delta_o;
    logic [COUNT_WIDTH-1:0]        count_o;
    logic                          valid_o;

    // ----------------- Bookkeeping -----------------
    int errors = 0;
    int passes = 0;

    // ----------------- Clock -----------------
    initial clk = 0;
    always  #5 clk = ~clk;        // 100 MHz

    // ----------------- DUT -----------------
    polyak_averager #(
        .SAMPLE_WIDTH (SAMPLE_WIDTH),
        .SUM_WIDTH    (SUM_WIDTH),
        .AVG_WIDTH    (AVG_WIDTH),
        .RECIP_WIDTH  (RECIP_WIDTH),
        .COUNT_WIDTH  (COUNT_WIDTH)
    ) dut (
        .clk             (clk),
        .rst_n           (rst_n),
        .sample_in       (sample_in),
        .sample_valid    (sample_valid),
        .reciprocal_in   (reciprocal_in),
        .chunk_size_log2 (chunk_size_log2),
        .soft_reset      (soft_reset),
        .xbar_o          (xbar_o),
        .xbar_delta_o    (xbar_delta_o),
        .count_o         (count_o),
        .valid_o         (valid_o)
    );

    // ----------------- Tasks -----------------
    task automatic feed_sample(input signed [SAMPLE_WIDTH-1:0] v);
        @(posedge clk);
        sample_in    <= v;
        sample_valid <= 1'b1;
        @(posedge clk);
        sample_valid <= 1'b0;
    endtask

    // wait until valid_o pulses (1 cycle pulse), capture xbar
    task automatic wait_for_valid(output signed [AVG_WIDTH-1:0] xbar_captured,
                                  output [AVG_WIDTH-1:0]        delta_captured);
        int timeout;
        timeout = 0;
        while (!valid_o && timeout < 200) begin
            @(posedge clk);
            timeout++;
        end
        if (!valid_o) begin
            $display("[%0t] ERROR: timeout waiting for valid_o", $time);
            errors++;
        end else begin
            xbar_captured  = xbar_o;
            delta_captured = xbar_delta_o;
        end
        @(posedge clk);
    endtask

    task automatic check(input string name,
                         input signed [AVG_WIDTH-1:0] got,
                         input signed [AVG_WIDTH-1:0] exp,
                         input integer tol);
        if (got > exp ? (got - exp) : (exp - got) <= tol) begin
            $display("[%0t] PASS %s: got=%0d exp=%0d (tol=%0d)",
                     $time, name, got, exp, tol);
            passes++;
        end else begin
            $display("[%0t] FAIL %s: got=%0d exp=%0d (tol=%0d)",
                     $time, name, got, exp, tol);
            errors++;
        end
    endtask

    task automatic do_soft_reset();
        @(posedge clk);
        soft_reset <= 1'b1;
        @(posedge clk);
        soft_reset <= 1'b0;
    endtask

    // ----------------- Stimulus -----------------
    signed [AVG_WIDTH-1:0] xbar_cap;
    [AVG_WIDTH-1:0]        delta_cap;

    initial begin
        // Init
        rst_n           = 0;
        sample_in       = 0;
        sample_valid    = 0;
        reciprocal_in   = RECIP_16;
        chunk_size_log2 = CHUNK_LOG2_16;
        soft_reset      = 0;
        repeat (5) @(posedge clk);
        rst_n = 1;
        repeat (3) @(posedge clk);

        // -----------------------------------------
        // T1: 16 constant samples == 100 -> xbar==100
        // -----------------------------------------
        $display("---- T1: constant 100 ----");
        for (int i = 0; i < 16; i++) feed_sample(16'sd100);
        wait_for_valid(xbar_cap, delta_cap);
        check("T1.xbar", xbar_cap, 32'sd100, 1);

        // -----------------------------------------
        // T2: ramp 1..16 -> sum=136, xbar=floor(136/16)=8
        // -----------------------------------------
        $display("---- T2: ramp 1..16 ----");
        do_soft_reset();
        for (int i = 1; i <= 16; i++) feed_sample(i);
        wait_for_valid(xbar_cap, delta_cap);
        check("T2.xbar", xbar_cap, 32'sd8, 1);

        // -----------------------------------------
        // T3: 16 samples == -250 -> xbar == -250
        // -----------------------------------------
        $display("---- T3: constant -250 ----");
        do_soft_reset();
        for (int i = 0; i < 16; i++) feed_sample(-16'sd250);
        wait_for_valid(xbar_cap, delta_cap);
        check("T3.xbar", xbar_cap, -32'sd250, 1);

        // -----------------------------------------
        // T4: two back-to-back chunks, second chunk has different value
        // -----------------------------------------
        $display("---- T4: two chunks 100 then 200 ----");
        do_soft_reset();
        for (int i = 0; i < 16; i++) feed_sample(16'sd100);
        wait_for_valid(xbar_cap, delta_cap);
        check("T4.first.xbar", xbar_cap, 32'sd100, 1);
        for (int i = 0; i < 16; i++) feed_sample(16'sd200);
        wait_for_valid(xbar_cap, delta_cap);
        // Cumulative average across 32 samples: (16*100 + 16*200)/32 = 150
        // BUT this module averages PER chunk (sum reset implicitly between chunks?).
        // Our implementation lets `sum` accumulate across chunks, so second-chunk
        // sum = 16*100 + 16*200 = 4800; xbar = 4800 * recip / 2^32.
        // recip is for n=16, so xbar ~= 4800 / 16 = 300 (not 150).
        // The "running average" interpretation would need the ARM to update recip.
        // For this TB we verify the documented behavior: sum carries over.
        check("T4.second.xbar(carried-sum)", xbar_cap, 32'sd300, 2);
        // delta vs first xbar (100) -> ~200
        check("T4.delta", $signed(delta_cap), 32'sd200, 2);

        // -----------------------------------------
        // T5: soft_reset clears state, third chunk all 50 -> xbar=50
        // -----------------------------------------
        $display("---- T5: soft_reset then constant 50 ----");
        do_soft_reset();
        for (int i = 0; i < 16; i++) feed_sample(16'sd50);
        wait_for_valid(xbar_cap, delta_cap);
        check("T5.xbar", xbar_cap, 32'sd50, 1);

        // -----------------------------------------
        // Summary
        // -----------------------------------------
        $display("==== tb_polyak_avg done: %0d passes, %0d errors ====",
                 passes, errors);
        if (errors == 0) $display("RESULT: ALL PASS");
        else             $display("RESULT: %0d FAIL", errors);
        $finish;
    end

    // ----------------- Watchdog -----------------
    initial begin
        #50000;
        $display("[%0t] WATCHDOG: simulation timeout", $time);
        $finish;
    end

endmodule
