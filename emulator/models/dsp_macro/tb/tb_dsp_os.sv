
`timescale 1ns/1ps
module tb_dsp_os; import std::*;

    localparam int WARMUP    = 8;     // ignore first N cycles for pipeline fill
    localparam int RUN_CYC   = 5000;  // number of randomized cycles


    logic clk;
    logic rstn;

    // 100 MHz clock
    always begin
        clk = 1; #5; clk = 0; #5;
    end

    // Reset (your DUTs don't expose reset; we keep rstn for sequencing)
    initial begin
        rstn = 0; #45; rstn = 1;
    end

    // End simulation after RUN_CYC + some slack
    initial begin
        repeat (RUN_CYC + 100) @(posedge clk);
        $display("Simulation finished.");
        $stop;
    end

    // ----------------------------
    // Stimulus
    // ----------------------------
    logic [3:0]             SEL;
    logic signed [26:0]     A;
    logic signed [17:0]     B;
    logic signed [31:0]     C;
    logic signed [26:0]     D;

    logic signed [45:0]     P_os;
    logic signed [45:0]     P_ip;

    int cycle;
    int mismatches;

    // Give both DUTs the *same* inputs
    dsp_macro_0 ip (
        .CLK (clk),
        .SEL (SEL),
        .A   (A),
        .B   (B),
        .C   (C),
        .D   (D),
        .P   (P_ip)
    );

    dsp_macro os (
        .CLK (clk),
        .SEL (SEL),
        .A   (A),
        .B   (B),
        .C   (C),
        .D   (D),
        .P   (P_os)
    );

    // Random input stream generation (mirrors your FIFO style)
    initial begin
        SEL = '0; A = '0; B = '0; C = '0; D = '0;
        cycle = 0; mismatches = 0;

        // wait for reset release / settle
        @(posedge rstn);
        #50;

        forever @(posedge clk) begin
            // randomize all inputs once per cycle
            std::randomize(SEL);
            std::randomize(A);
            std::randomize(B);
            std::randomize(C);
            std::randomize(D);

            cycle++;
        end
    end

    // Check output consistency (mirrors commented block in your FIFO TB)
    always @(negedge clk) begin
        // Skip early cycles during pipeline fill
        if (cycle < WARMUP) begin
            // do nothing
        end else begin
            // If either output is X/Z, skip but warn
            if ((^P_ip === 1'bX) || (^P_os === 1'bX)) begin
                $display("[%0t] WARN: X/Z detected (skipping)  SEL=%0d  A=%0d B=%0d C=%0d D=%0d",
                         $time, SEL, A, B, C, D);
            end else begin
                assert (P_ip === P_os) else begin
                    mismatches++;
                    $error(
                        "ERROR: Data out mismatch @cycle=%0d\n  SEL=%0d\n  A=%0d  B=%0d  C=%0d  D=%0d\n  IP=%0d\n  OS=%0d",
                        cycle, SEL, A, B, C, D, P_ip, P_os
                    );
                end
            end
        end

        // stop after we have done RUN_CYC comparisons post-warmup
        if (cycle >= (WARMUP + RUN_CYC)) begin
            $display("----------------------------------------------");
            $display("Checked %0d cycles (after warmup=%0d).", RUN_CYC, WARMUP);
            $display("Mismatches: %0d", mismatches);
            $display("----------------------------------------------");
            if (mismatches == 0)
                $display("PASS: Outputs matched on all checked cycles.");
            else
                $display("FAIL: See mismatch log above.");
            $stop;
        end
    end

endmodule
