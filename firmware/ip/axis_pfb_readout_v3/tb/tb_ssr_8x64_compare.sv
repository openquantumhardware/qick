`timescale 1ns / 1ps

module tb_ssr_8x64_compare;

    localparam CLK_PERIOD = 10;
    localparam TOTAL_CYCLES = 200;
    localparam WATCHDOG_TIMEOUT = 100_000;

    logic clk;
    int   cycle_count;
    logic        i_valid;
    logic [5:0]  i_scale;
    logic signed [15:0] i_re_0;
    logic signed [15:0] i_re_1;
    logic signed [15:0] i_re_2;
    logic signed [15:0] i_re_3;
    logic signed [15:0] i_re_4;
    logic signed [15:0] i_re_5;
    logic signed [15:0] i_re_6;
    logic signed [15:0] i_re_7;
    logic signed [15:0] i_im_0;
    logic signed [15:0] i_im_1;
    logic signed [15:0] i_im_2;
    logic signed [15:0] i_im_3;
    logic signed [15:0] i_im_4;
    logic signed [15:0] i_im_5;
    logic signed [15:0] i_im_6;
    logic signed [15:0] i_im_7;

    logic [26:0] vhd_o_re_0;
    logic [26:0] vhd_o_im_0;
    logic [26:0] vhd_o_re_1;
    logic [26:0] vhd_o_im_1;
    logic [26:0] vhd_o_re_2;
    logic [26:0] vhd_o_im_2;
    logic [26:0] vhd_o_re_3;
    logic [26:0] vhd_o_im_3;
    logic [26:0] vhd_o_re_4;
    logic [26:0] vhd_o_im_4;
    logic [26:0] vhd_o_re_5;
    logic [26:0] vhd_o_im_5;
    logic [26:0] vhd_o_re_6;
    logic [26:0] vhd_o_im_6;
    logic [26:0] vhd_o_re_7;
    logic [26:0] vhd_o_im_7;
    logic        vhd_o_valid;
    logic [5:0]  vhd_o_scale;

    // Verilog DUT outputs
    logic signed [26:0] sv_o_re_0;
    logic signed [26:0] sv_o_im_0;
    logic signed [26:0] sv_o_re_1;
    logic signed [26:0] sv_o_im_1;
    logic signed [26:0] sv_o_re_2;
    logic signed [26:0] sv_o_im_2;
    logic signed [26:0] sv_o_re_3;
    logic signed [26:0] sv_o_im_3;
    logic signed [26:0] sv_o_re_4;
    logic signed [26:0] sv_o_im_4;
    logic signed [26:0] sv_o_re_5;
    logic signed [26:0] sv_o_im_5;
    logic signed [26:0] sv_o_re_6;
    logic signed [26:0] sv_o_im_6;
    logic signed [26:0] sv_o_re_7;
    logic signed [26:0] sv_o_im_7;
    logic        sv_o_valid;
    logic [5:0]  sv_o_scale;

    // Comparison tracking
    int mismatch_count;
    int match_count;
    int total_checks;

    // ----------------------------------------------------------------
    // VCD dump
    // ----------------------------------------------------------------
    initial begin
        $dumpfile("tb_ssr_8x64_compare.vcd");
        $dumpvars(0, tb_ssr_8x64_compare);
    end

    // ----------------------------------------------------------------
    // Clock + cycle counter
    // ----------------------------------------------------------------
    always #(CLK_PERIOD / 2) clk = ~clk;
    initial begin
        clk = 0;
        cycle_count = 0;
        forever @(posedge clk) cycle_count <= cycle_count + 1;
    end

    // ----------------------------------------------------------------
    // VHDL DUT (golden reference)
    // ----------------------------------------------------------------
    ssr_8x64 vhd_dut (
        .i_scale   (i_scale),
        .i_valid   (i_valid),
        .i_im_0    (i_im_0),
        .i_im_1    (i_im_1),
        .i_im_2    (i_im_2),
        .i_im_3    (i_im_3),
        .i_im_4    (i_im_4),
        .i_im_5    (i_im_5),
        .i_im_6    (i_im_6),
        .i_im_7    (i_im_7),
        .i_re_0    (i_re_0),
        .i_re_1    (i_re_1),
        .i_re_2    (i_re_2),
        .i_re_3    (i_re_3),
        .i_re_4    (i_re_4),
        .i_re_5    (i_re_5),
        .i_re_6    (i_re_6),
        .i_re_7    (i_re_7),
        .clk       (clk),
        .o_scale   (vhd_o_scale),
        .o_valid   (vhd_o_valid),
        .o_im_0    (vhd_o_im_0),
        .o_im_1    (vhd_o_im_1),
        .o_im_2    (vhd_o_im_2),
        .o_im_3    (vhd_o_im_3),
        .o_im_4    (vhd_o_im_4),
        .o_im_5    (vhd_o_im_5),
        .o_im_6    (vhd_o_im_6),
        .o_im_7    (vhd_o_im_7),
        .o_re_0    (vhd_o_re_0),
        .o_re_1    (vhd_o_re_1),
        .o_re_2    (vhd_o_re_2),
        .o_re_3    (vhd_o_re_3),
        .o_re_4    (vhd_o_re_4),
        .o_re_5    (vhd_o_re_5),
        .o_re_6    (vhd_o_re_6),
        .o_re_7    (vhd_o_re_7)
    );

    // ----------------------------------------------------------------
    // Verilog DUT (model under test)
    // ----------------------------------------------------------------
    ssr_8x64_sv #(
        .FFT_LATENCY(18),
        .INPUT_DELAY(4),
        .OUTPUT_DELAY(4)
    ) sv_dut (
        .clk       (clk),
        .i_valid   (i_valid),
        .i_scale   (i_scale),
        .i_re_0    (i_re_0),
        .i_re_1    (i_re_1),
        .i_re_2    (i_re_2),
        .i_re_3    (i_re_3),
        .i_re_4    (i_re_4),
        .i_re_5    (i_re_5),
        .i_re_6    (i_re_6),
        .i_re_7    (i_re_7),
        .i_im_0    (i_im_0),
        .i_im_1    (i_im_1),
        .i_im_2    (i_im_2),
        .i_im_3    (i_im_3),
        .i_im_4    (i_im_4),
        .i_im_5    (i_im_5),
        .i_im_6    (i_im_6),
        .i_im_7    (i_im_7),
        .o_re_0    (sv_o_re_0),
        .o_re_1    (sv_o_re_1),
        .o_re_2    (sv_o_re_2),
        .o_re_3    (sv_o_re_3),
        .o_re_4    (sv_o_re_4),
        .o_re_5    (sv_o_re_5),
        .o_re_6    (sv_o_re_6),
        .o_re_7    (sv_o_re_7),
        .o_im_0    (sv_o_im_0),
        .o_im_1    (sv_o_im_1),
        .o_im_2    (sv_o_im_2),
        .o_im_3    (sv_o_im_3),
        .o_im_4    (sv_o_im_4),
        .o_im_5    (sv_o_im_5),
        .o_im_6    (sv_o_im_6),
        .o_im_7    (sv_o_im_7),
        .o_valid   (sv_o_valid),
        .o_scale   (sv_o_scale)
    );

    // ----------------------------------------------------------------
    // Watchdog: stop simulation if halted
    // ----------------------------------------------------------------
    initial begin
        #(WATCHDOG_TIMEOUT * CLK_PERIOD);
        $display("WATCHDOG TIMEOUT at t=%0t cycle=%0d: Simulation stalled, finishing", $time, cycle_count);
        $finish;
    end

    // ----------------------------------------------------------------
    // Cycle-by-cycle comparison
    // ----------------------------------------------------------------
    always @(posedge clk) begin
        if (vhd_o_valid || sv_o_valid) begin
            $display("t=%0t cycle=%0d: VALID vhd=%0d sv=%0d",
                     $time, cycle_count, vhd_o_valid, sv_o_valid);
        end

        if (vhd_o_valid && sv_o_valid) begin
            for (int lane = 0; lane < 8; lane = lane + 1) begin
                logic [26:0] vhd_re, vhd_im, sv_re, sv_im;
                total_checks = total_checks + 1;

                case (lane)
                    0: begin
                        vhd_re = vhd_o_re_0; vhd_im = vhd_o_im_0;
                        sv_re  = sv_o_re_0;  sv_im  = sv_o_im_0;
                    end
                    1: begin
                        vhd_re = vhd_o_re_1; vhd_im = vhd_o_im_1;
                        sv_re  = sv_o_re_1;  sv_im  = sv_o_im_1;
                    end
                    2: begin
                        vhd_re = vhd_o_re_2; vhd_im = vhd_o_im_2;
                        sv_re  = sv_o_re_2;  sv_im  = sv_o_im_2;
                    end
                    3: begin
                        vhd_re = vhd_o_re_3; vhd_im = vhd_o_im_3;
                        sv_re  = sv_o_re_3;  sv_im  = sv_o_im_3;
                    end
                    4: begin
                        vhd_re = vhd_o_re_4; vhd_im = vhd_o_im_4;
                        sv_re  = sv_o_re_4;  sv_im  = sv_o_im_4;
                    end
                    5: begin
                        vhd_re = vhd_o_re_5; vhd_im = vhd_o_im_5;
                        sv_re  = sv_o_re_5;  sv_im  = sv_o_im_5;
                    end
                    6: begin
                        vhd_re = vhd_o_re_6; vhd_im = vhd_o_im_6;
                        sv_re  = sv_o_re_6;  sv_im  = sv_o_im_6;
                    end
                    7: begin
                        vhd_re = vhd_o_re_7; vhd_im = vhd_o_im_7;
                        sv_re  = sv_o_re_7;  sv_im  = sv_o_im_7;
                    end
                endcase

                if (vhd_re !== sv_re || vhd_im !== sv_im || vhd_o_scale !== sv_o_scale) begin
                    mismatch_count = mismatch_count + 1;
                    $display("MISMATCH cycle=%0d lane=%0d: VHDL(re=%0d, im=%0d, scale=%0d) vs SV(re=%0d, im=%0d, scale=%0d)",
                             cycle_count, lane,
                             $signed(vhd_re), $signed(vhd_im), vhd_o_scale,
                             $signed(sv_re),  $signed(sv_im),  sv_o_scale);
                end else begin
                    match_count = match_count + 1;
                end
            end
        end
    end

    // ----------------------------------------------------------------
    // Continuous stimulus + 500-cycle termination
    // ----------------------------------------------------------------
    initial begin
        int sample_count;
        bit   stream_done;

        mismatch_count = 0;
        match_count    = 0;
        total_checks   = 0;
        sample_count   = 0;
        stream_done    = 0;

        $display("========================================");
        $display("tb_ssr_8x64_compare starting");
        $display("CLK_PERIOD=%0d ns, TOTAL_CYCLES=%0d", CLK_PERIOD, TOTAL_CYCLES);
        $display("========================================");

        // --- Initialize ---
        i_valid = 0;
        i_scale = 0;
        i_re_0 = 0; i_im_0 = 0;
        i_re_1 = 0; i_im_1 = 0;
        i_re_2 = 0; i_im_2 = 0;
        i_re_3 = 0; i_im_3 = 0;
        i_re_4 = 0; i_im_4 = 0;
        i_re_5 = 0; i_im_5 = 0;
        i_re_6 = 0; i_im_6 = 0;
        i_re_7 = 0; i_im_7 = 0;
        $display("t=%0t cycle=%0d: Reset deasserted, inputs cleared", $time, cycle_count);
        #(CLK_PERIOD * 2);

        // --- Continuous input stream (incrementing counter, im=0) ---
        i_valid = 1;
        $display("t=%0t cycle=%0d: Starting continuous input stream for %0d cycles",
                 $time, cycle_count, TOTAL_CYCLES);

        while (!stream_done) begin
            @(posedge clk);
            if (cycle_count >= TOTAL_CYCLES) begin
                i_valid = 0;
                stream_done = 1;
                $display("t=%0t cycle=%0d: Input stream complete, i_valid=0", $time, cycle_count);
            end else begin
                i_re_0 = sample_count[15:0];
                i_im_0 = 16'd0;
                i_re_1 = sample_count[15:0] + 16'd1;
                i_im_1 = 16'd0;
                i_re_2 = sample_count[15:0] + 16'd2;
                i_im_2 = 16'd0;
                i_re_3 = sample_count[15:0] + 16'd3;
                i_im_3 = 16'd0;
                i_re_4 = sample_count[15:0] + 16'd4;
                i_im_4 = 16'd0;
                i_re_5 = sample_count[15:0] + 16'd5;
                i_im_5 = 16'd0;
                i_re_6 = sample_count[15:0] + 16'd6;
                i_im_6 = 16'd0;
                i_re_7 = sample_count[15:0] + 16'd7;
                i_im_7 = 16'd0;

                sample_count = sample_count + 8;

                if (cycle_count % 100 == 0) begin
                    $display("t=%0t cycle=%0d: input sample_count=%0d re_0=%0d im_0=%0d",
                             $time, cycle_count, sample_count, i_re_0, i_im_0);
                end
            end
        end

        // --- Wait for outputs to complete ---
        $display("t=%0t cycle=%0d: Waiting for outputs...", $time, cycle_count);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);

        $display("========================================");
        $display("t=%0t cycle=%0d: Comparison complete.", $time, cycle_count);
        $display("Total checks : %0d", total_checks);
        $display("Matches      : %0d", match_count);
        $display("Mismatches   : %0d", mismatch_count);
        if (mismatch_count == 0) begin
            $display("RESULT: PASS - Both implementations match");
        end else begin
            $display("RESULT: FAIL - %0d mismatches found", mismatch_count);
        end
        $display("========================================");

        $finish;
    end

endmodule
