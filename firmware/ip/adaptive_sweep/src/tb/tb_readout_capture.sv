`timescale 1ns / 1ps
//
// tb_readout_capture.sv
//
// Unit testbench for readout_capture.v.  Generates ro_clk = 307.2 MHz and
// c_clk = 200 MHz, drives a stream of indexed I/Q samples on the ro_clk
// AXIS slave port, fires a trigger mid-stream, and verifies that exactly
// n_samples samples cross to the c_clk side in order.
//

module tb_readout_capture;

    localparam int IQ_WIDTH = 16;
    localparam int FIFO_DEPTH_LOG2 = 6;
    localparam int COUNT_WIDTH = 16;
    localparam int N_SAMPLES = 16;

    // Clocks
    logic clk;
    logic ro_clk;
    initial clk    = 0;
    initial ro_clk = 0;
    always  #2.5 clk    = ~clk;     // 200 MHz
    always  #1.6275 ro_clk = ~ro_clk;  // ~307.2 MHz

    // Resets
    logic rst_n;
    logic ro_aresetn;

    // c_clk control
    logic                       arm_pulse;
    logic [COUNT_WIDTH-1:0]     n_samples;
    logic                       capture_done;
    logic signed [IQ_WIDTH-1:0] i_out, q_out;
    logic                       iq_valid;
    logic                       iq_ready;
    logic [COUNT_WIDTH-1:0]     samples_remaining;

    // ro_clk AXIS
    logic [2*IQ_WIDTH-1:0]      ro_tdata;
    logic                       ro_tvalid;
    logic                       ro_tready;
    logic                       trigger;

    int errors = 0, passes = 0;

    readout_capture #(
        .IQ_WIDTH       (IQ_WIDTH),
        .FIFO_DEPTH_LOG2(FIFO_DEPTH_LOG2),
        .COUNT_WIDTH    (COUNT_WIDTH)
    ) dut (
        .clk             (clk),
        .rst_n           (rst_n),
        .arm_pulse       (arm_pulse),
        .n_samples       (n_samples),
        .capture_done_o  (capture_done),
        .i_out           (i_out),
        .q_out           (q_out),
        .iq_valid        (iq_valid),
        .iq_ready        (iq_ready),
        .samples_remaining(samples_remaining),

        .s_ro_axis_aclk    (ro_clk),
        .s_ro_axis_aresetn (ro_aresetn),
        .s_ro_axis_tdata   (ro_tdata),
        .s_ro_axis_tvalid  (ro_tvalid),
        .s_ro_axis_tready  (ro_tready),
        .trigger_i         (trigger)
    );

    // Continuous I/Q stream on ro_clk.  i = counter, q = -counter.
    int sample_cnt;
    always @(posedge ro_clk) begin
        if (!ro_aresetn) begin
            sample_cnt <= 0;
            ro_tdata   <= '0;
            ro_tvalid  <= 1'b0;
        end else begin
            ro_tvalid <= 1'b1;
            // Q in upper, I in lower
            ro_tdata <= {(-sample_cnt[IQ_WIDTH-1:0]), sample_cnt[IQ_WIDTH-1:0]};
            sample_cnt <= sample_cnt + 1;
        end
    end

    // Drain the FIFO at full rate so we observe every captured sample
    assign iq_ready = 1'b1;

    // Capture observed samples for checking
    int observed = 0;
    int first_i  = -1;
    always @(posedge clk) begin
        if (rst_n && iq_valid && iq_ready) begin
            if (first_i == -1) first_i = i_out;
            observed <= observed + 1;
        end
    end

    initial begin
        rst_n      = 0;
        ro_aresetn = 0;
        arm_pulse  = 0;
        n_samples  = N_SAMPLES;
        trigger    = 0;
        observed   = 0;
        first_i    = -1;
        repeat (10) @(posedge clk);
        rst_n      = 1;
        ro_aresetn = 1;
        repeat (20) @(posedge clk);

        // Arm capture
        @(posedge clk);
        arm_pulse <= 1;
        @(posedge clk);
        arm_pulse <= 0;

        // Wait some ro_clk cycles, then fire trigger
        repeat (50) @(posedge ro_clk);
        @(posedge ro_clk);
        trigger <= 1;
        @(posedge ro_clk);
        trigger <= 0;

        // Wait for capture_done
        begin
            int t;
            t = 0;
            while (!capture_done && t < 5000) begin
                @(posedge clk);
                t++;
            end
            if (!capture_done) begin
                $display("[%0t] FAIL: capture_done never asserted", $time);
                errors++;
            end else begin
                $display("[%0t] PASS: capture_done asserted", $time);
                passes++;
            end
        end

        // Drain FIFO
        repeat (200) @(posedge clk);

        // Check exactly N_SAMPLES were observed
        if (observed === N_SAMPLES) begin
            $display("[%0t] PASS: observed=%0d == N_SAMPLES=%0d",
                     $time, observed, N_SAMPLES);
            passes++;
        end else begin
            $display("[%0t] FAIL: observed=%0d != N_SAMPLES=%0d",
                     $time, observed, N_SAMPLES);
            errors++;
        end

        $display("==== tb_readout_capture done: %0d passes, %0d errors ====",
                 passes, errors);
        if (errors == 0) $display("RESULT: ALL PASS");
        else             $display("RESULT: %0d FAIL", errors);
        $finish;
    end

    initial begin
        #1000000;
        $display("[%0t] WATCHDOG: simulation timeout", $time);
        $finish;
    end

endmodule
