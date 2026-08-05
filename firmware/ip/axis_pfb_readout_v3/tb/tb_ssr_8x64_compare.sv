`timescale 1ns / 1ps

module tb_ssr_8x64_compare;

    localparam CLK_PERIOD = 10;
    localparam N_INPUT_CYCLES = 4;
    localparam N_OUTPUT_WAIT = 4;
    localparam WATCHDOG_TIMEOUT = 100_000;

    logic clk;
    int   cycle_count;
    logic [0:0]  i_valid;
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
    logic [0:0]  vhd_o_valid;
    logic [5:0]  vhd_o_scale;

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
    // VHDL DUT (top-level ssr_8x64)
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
    // Watchdog: stop simulation if halted
    // ----------------------------------------------------------------
    initial begin
        #(WATCHDOG_TIMEOUT * CLK_PERIOD);
        $display("WATCHDOG TIMEOUT at t=%0t cycle=%0d: Simulation stalled, finishing", $time, cycle_count);
        $finish;
    end

    // ----------------------------------------------------------------
    // Basic stimulus + telemetry
    // ----------------------------------------------------------------
    initial begin
        int cycle;
        int out_count;
        int last_out_count;

        $display("========================================");
        $display("tb_ssr_8x64_compare starting");
        $display("CLK_PERIOD=%0d ns, WATCHDOG=%0d cycles", CLK_PERIOD, WATCHDOG_TIMEOUT);
        $display("========================================");

        // --- Initialize ---
        i_valid = 0;
        i_scale = 0;
        for (cycle = 0; cycle < 8; cycle = cycle + 1) begin
            i_re_0 = 0; i_im_0 = 0;
            i_re_1 = 0; i_im_1 = 0;
            i_re_2 = 0; i_im_2 = 0;
            i_re_3 = 0; i_im_3 = 0;
            i_re_4 = 0; i_im_4 = 0;
            i_re_5 = 0; i_im_5 = 0;
            i_re_6 = 0; i_im_6 = 0;
            i_re_7 = 0; i_im_7 = 0;
        end
        $display("t=%0t cycle=%0d: Reset deasserted, inputs cleared", $time, cycle_count);
        #(CLK_PERIOD * 2);

        // --- Send input stimulus ---
        i_valid = 1;
        $display("t=%0t cycle=%0d: Starting input stimulus (%0d cycles)", $time, cycle_count, N_INPUT_CYCLES);
        for (cycle = 0; cycle < N_INPUT_CYCLES; cycle = cycle + 1) begin
            i_re_0 = (cycle == 0) ? 16'd1 : 16'd0;
            i_im_0 = 16'd0;
            i_re_1 = 16'd0; i_im_1 = 16'd0;
            i_re_2 = 16'd0; i_im_2 = 16'd0;
            i_re_3 = 16'd0; i_im_3 = 16'd0;
            i_re_4 = 16'd0; i_im_4 = 16'd0;
            i_re_5 = 16'd0; i_im_5 = 16'd0;
            i_re_6 = 16'd0; i_im_6 = 16'd0;
            i_re_7 = 16'd0; i_im_7 = 16'd0;
            @(posedge clk);
            $display("t=%0t cycle=%0d: input cycle=%0d re_0=%0d im_0=%0d",
                     $time, cycle_count, cycle, i_re_0, i_im_0);
        end
        i_valid = 0;
        $display("t=%0t cycle=%0d: Input stimulus complete, i_valid=0", $time, cycle_count);

        // --- Wait for and monitor outputs ---
        $display("t=%0t cycle=%0d: Waiting for outputs (max %0d cycles)...", $time, cycle_count, WATCHDOG_TIMEOUT);
        out_count = 0;
        last_out_count = 0;
        while (out_count < N_OUTPUT_WAIT) begin
            @(posedge clk);
            if (vhd_o_valid[0]) begin
                out_count = out_count + 1;
                $display("t=%0t cycle=%0d: OUTPUT out_cycle=%0d re_0=%0d im_0=%0d scale=%0d",
                         $time, cycle_count, out_count,
                         $signed(vhd_o_re_0), $signed(vhd_o_im_0), vhd_o_scale);
                last_out_count = cycle_count;
            end else if (cycle_count - last_out_count >= 50_000) begin
                $display("t=%0t cycle=%0d: Still waiting... outputs_so_far=%0d",
                         $time, cycle_count, out_count);
                last_out_count = cycle_count;
            end
        end

        $display("========================================");
        $display("t=%0t cycle=%0d: Basic functionality check complete.", $time, cycle_count);
        $display("Observed %0d output cycles.", out_count);
        $display("========================================");
        $finish;
    end

endmodule
