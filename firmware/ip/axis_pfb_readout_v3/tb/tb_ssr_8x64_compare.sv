`timescale 1ns / 1ps

module tb_ssr_8x64_compare;

    localparam CLK_PERIOD = 10;
    localparam FRAME_CYCLES = 8;
    localparam int PATTERN_COUNT = 4;
    localparam int FRAMES_PER_PATTERN = 4;
    localparam int TOTAL_FRAMES = PATTERN_COUNT * FRAMES_PER_PATTERN;
    localparam OUTPUT_IDLE_CYCLES = 32;
    localparam WATCHDOG_TIMEOUT = 100_000;

    localparam int ABS_TOLERANCE = 200;
    localparam real REL_TOLERANCE = 0.05;

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

    int mismatch_count;
    int match_count;
    int total_checks;
    int outlier_count;
    int total_abs_err;
    int max_abs_err;
    int compared_output_beats;
    int output_idle_cycles;
    int valid_mismatch_count;

    logic signed [26:0] vhd_re_arr [0:7];
    logic signed [26:0] vhd_im_arr [0:7];
    logic signed [26:0] sv_re_arr  [0:7];
    logic signed [26:0] sv_im_arr  [0:7];

    initial begin
        $dumpfile("tb_ssr_8x64_compare.vcd");
        $dumpvars(0, tb_ssr_8x64_compare);
    end

    always #(CLK_PERIOD / 2) clk = ~clk;
    initial begin
        clk = 0;
        cycle_count = 0;
        forever @(posedge clk) cycle_count <= cycle_count + 1;
    end

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

    ssr_8x64_sv #(
        .FFT_LATENCY(32),
        .INPUT_DELAY(4),
        .OUTPUT_DELAY(6),
        .LANE_MAP('{0,1,2,3,4,5,6,7})
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

    initial begin
        #(WATCHDOG_TIMEOUT * CLK_PERIOD);
        $display("WATCHDOG TIMEOUT at t=%0t cycle=%0d: Simulation stalled, finishing", $time, cycle_count);
        $finish;
    end

    function automatic bit within_tolerance(
        input logic signed [26:0] vhd_val,
        input logic signed [26:0] sv_val,
        input int abs_tol,
        input real rel_tol
    );
        int abs_diff;
        real max_abs;
        real rel_diff;
        begin
            if (vhd_val > sv_val)
                abs_diff = vhd_val - sv_val;
            else
                abs_diff = sv_val - vhd_val;
            max_abs = (vhd_val > 0 ? vhd_val : -vhd_val) > (sv_val > 0 ? sv_val : -sv_val) ? (vhd_val > 0 ? vhd_val : -vhd_val) : (sv_val > 0 ? sv_val : -sv_val);
            if (max_abs > 0)
                rel_diff = abs_diff / max_abs;
            else
                rel_diff = 0;

            within_tolerance = (abs_diff <= abs_tol) || (rel_diff <= rel_tol);
        end
    endfunction

    task automatic drive_pattern_beat(
        input int pattern_id,
        input int pattern_frame,
        input int beat_idx
    );
        int amplitude;
        begin
            i_im_0 = 16'sd0; i_im_1 = 16'sd0; i_im_2 = 16'sd0; i_im_3 = 16'sd0;
            i_im_4 = 16'sd0; i_im_5 = 16'sd0; i_im_6 = 16'sd0; i_im_7 = 16'sd0;

            case (pattern_id)
                0: begin
                    i_re_0 = pattern_frame * 64 + beat_idx * 8 + 16'sd1;
                    i_re_1 = pattern_frame * 64 + beat_idx * 8 + 16'sd2;
                    i_re_2 = pattern_frame * 64 + beat_idx * 8 + 16'sd3;
                    i_re_3 = pattern_frame * 64 + beat_idx * 8 + 16'sd4;
                    i_re_4 = pattern_frame * 64 + beat_idx * 8 + 16'sd5;
                    i_re_5 = pattern_frame * 64 + beat_idx * 8 + 16'sd6;
                    i_re_6 = pattern_frame * 64 + beat_idx * 8 + 16'sd7;
                    i_re_7 = pattern_frame * 64 + beat_idx * 8 + 16'sd8;
                end

                1: begin
                    amplitude = 16'sd80 + pattern_frame * 16'sd12;
                    i_re_0 = amplitude; i_re_1 = amplitude; i_re_2 = amplitude; i_re_3 = amplitude;
                    i_re_4 = amplitude; i_re_5 = amplitude; i_re_6 = amplitude; i_re_7 = amplitude;
                end

                2: begin
                    amplitude = 16'sd120 + pattern_frame * 16'sd10;
                    i_re_0 = 16'sd0; i_re_1 = 16'sd0; i_re_2 = 16'sd0; i_re_3 = 16'sd0;
                    i_re_4 = 16'sd0; i_re_5 = 16'sd0; i_re_6 = 16'sd0; i_re_7 = 16'sd0;

                    if (beat_idx == 0) begin
                        case (pattern_frame % 8)
                            0: i_re_0 = amplitude;
                            1: i_re_1 = amplitude;
                            2: i_re_2 = amplitude;
                            3: i_re_3 = amplitude;
                            4: i_re_4 = amplitude;
                            5: i_re_5 = amplitude;
                            6: i_re_6 = amplitude;
                            default: i_re_7 = amplitude;
                        endcase
                    end
                end

                default: begin
                    i_re_0 = ((beat_idx + 0) % 2 == 0) ? (16'sd10 + pattern_frame) : -(16'sd10 + pattern_frame);
                    i_re_1 = ((beat_idx + 1) % 2 == 0) ? (16'sd11 + pattern_frame) : -(16'sd11 + pattern_frame);
                    i_re_2 = ((beat_idx + 2) % 2 == 0) ? (16'sd12 + pattern_frame) : -(16'sd12 + pattern_frame);
                    i_re_3 = ((beat_idx + 3) % 2 == 0) ? (16'sd13 + pattern_frame) : -(16'sd13 + pattern_frame);
                    i_re_4 = ((beat_idx + 4) % 2 == 0) ? (16'sd14 + pattern_frame) : -(16'sd14 + pattern_frame);
                    i_re_5 = ((beat_idx + 5) % 2 == 0) ? (16'sd15 + pattern_frame) : -(16'sd15 + pattern_frame);
                    i_re_6 = ((beat_idx + 6) % 2 == 0) ? (16'sd16 + pattern_frame) : -(16'sd16 + pattern_frame);
                    i_re_7 = ((beat_idx + 7) % 2 == 0) ? (16'sd17 + pattern_frame) : -(16'sd17 + pattern_frame);

                    i_im_0 = ((beat_idx + 0) % 2 == 0) ? pattern_frame : -pattern_frame;
                    i_im_1 = ((beat_idx + 1) % 2 == 0) ? pattern_frame : -pattern_frame;
                    i_im_2 = ((beat_idx + 2) % 2 == 0) ? pattern_frame : -pattern_frame;
                    i_im_3 = ((beat_idx + 3) % 2 == 0) ? pattern_frame : -pattern_frame;
                    i_im_4 = ((beat_idx + 4) % 2 == 0) ? pattern_frame : -pattern_frame;
                    i_im_5 = ((beat_idx + 5) % 2 == 0) ? pattern_frame : -pattern_frame;
                    i_im_6 = ((beat_idx + 6) % 2 == 0) ? pattern_frame : -pattern_frame;
                    i_im_7 = ((beat_idx + 7) % 2 == 0) ? pattern_frame : -pattern_frame;
                end
            endcase
        end
    endtask

    always @(posedge clk) begin
        if (vhd_o_valid || sv_o_valid) begin
            $display("t=%0t cycle=%0d: VALID vhd=%0d sv=%0d",
                     $time, cycle_count, vhd_o_valid, sv_o_valid);

            $display("  VHD re=[%0d %0d %0d %0d %0d %0d %0d %0d] im=[%0d %0d %0d %0d %0d %0d %0d %0d] scale=%0d",
                     $signed(vhd_o_re_0), $signed(vhd_o_re_1), $signed(vhd_o_re_2), $signed(vhd_o_re_3),
                     $signed(vhd_o_re_4), $signed(vhd_o_re_5), $signed(vhd_o_re_6), $signed(vhd_o_re_7),
                     $signed(vhd_o_im_0), $signed(vhd_o_im_1), $signed(vhd_o_im_2), $signed(vhd_o_im_3),
                     $signed(vhd_o_im_4), $signed(vhd_o_im_5), $signed(vhd_o_im_6), $signed(vhd_o_im_7),
                     vhd_o_scale);
            $display("  SV  re=[%0d %0d %0d %0d %0d %0d %0d %0d] im=[%0d %0d %0d %0d %0d %0d %0d %0d] scale=%0d",
                     $signed(sv_o_re_0), $signed(sv_o_re_1), $signed(sv_o_re_2), $signed(sv_o_re_3),
                     $signed(sv_o_re_4), $signed(sv_o_re_5), $signed(sv_o_re_6), $signed(sv_o_re_7),
                     $signed(sv_o_im_0), $signed(sv_o_im_1), $signed(sv_o_im_2), $signed(sv_o_im_3),
                     $signed(sv_o_im_4), $signed(sv_o_im_5), $signed(sv_o_im_6), $signed(sv_o_im_7),
                     sv_o_scale);
        end

        if (((vhd_o_valid === 1'b1) && (sv_o_valid === 1'b0)) ||
            ((vhd_o_valid === 1'b0) && (sv_o_valid === 1'b1))) begin
            valid_mismatch_count = valid_mismatch_count + 1;
        end

        if (vhd_o_valid && sv_o_valid) begin
            compared_output_beats = compared_output_beats + 1;

            vhd_re_arr = '{vhd_o_re_0, vhd_o_re_1, vhd_o_re_2, vhd_o_re_3,
                           vhd_o_re_4, vhd_o_re_5, vhd_o_re_6, vhd_o_re_7};
            vhd_im_arr = '{vhd_o_im_0, vhd_o_im_1, vhd_o_im_2, vhd_o_im_3,
                           vhd_o_im_4, vhd_o_im_5, vhd_o_im_6, vhd_o_im_7};
            sv_re_arr  = '{sv_o_re_0,  sv_o_re_1,  sv_o_re_2,  sv_o_re_3,
                           sv_o_re_4,  sv_o_re_5,  sv_o_re_6,  sv_o_re_7};
            sv_im_arr  = '{sv_o_im_0,  sv_o_im_1,  sv_o_im_2,  sv_o_im_3,
                           sv_o_im_4,  sv_o_im_5,  sv_o_im_6,  sv_o_im_7};

            for (int lane = 0; lane < 8; lane = lane + 1) begin
                total_checks = total_checks + 1;

                if (!within_tolerance(vhd_re_arr[lane], sv_re_arr[lane], ABS_TOLERANCE, REL_TOLERANCE) ||
                    !within_tolerance(vhd_im_arr[lane], sv_im_arr[lane], ABS_TOLERANCE, REL_TOLERANCE) ||
                    (vhd_o_scale !== sv_o_scale)) begin
                    mismatch_count = mismatch_count + 1;
                    $display("OUTLIER cycle=%0d lane=%0d: VHDL(re=%0d, im=%0d, scale=%0d) vs SV(re=%0d, im=%0d, scale=%0d)",
                             cycle_count, lane,
                             $signed(vhd_re_arr[lane]), $signed(vhd_im_arr[lane]), vhd_o_scale,
                             $signed(sv_re_arr[lane]),  $signed(sv_im_arr[lane]),  sv_o_scale);
                end else begin
                    match_count = match_count + 1;
                end

                if (vhd_re_arr[lane] > sv_re_arr[lane])
                    total_abs_err = total_abs_err + (vhd_re_arr[lane] - sv_re_arr[lane]);
                else
                    total_abs_err = total_abs_err + (sv_re_arr[lane] - vhd_re_arr[lane]);
                if (vhd_im_arr[lane] > sv_im_arr[lane])
                    total_abs_err = total_abs_err + (vhd_im_arr[lane] - sv_im_arr[lane]);
                else
                    total_abs_err = total_abs_err + (sv_im_arr[lane] - vhd_im_arr[lane]);

                if ((vhd_re_arr[lane] > sv_re_arr[lane] ? vhd_re_arr[lane] - sv_re_arr[lane] : sv_re_arr[lane] - vhd_re_arr[lane]) +
                    (vhd_im_arr[lane] > sv_im_arr[lane] ? vhd_im_arr[lane] - sv_im_arr[lane] : sv_im_arr[lane] - vhd_im_arr[lane]) > max_abs_err)
                    max_abs_err = (vhd_re_arr[lane] > sv_re_arr[lane] ? vhd_re_arr[lane] - sv_re_arr[lane] : sv_re_arr[lane] - vhd_re_arr[lane]) +
                                  (vhd_im_arr[lane] > sv_im_arr[lane] ? vhd_im_arr[lane] - sv_im_arr[lane] : sv_im_arr[lane] - vhd_im_arr[lane]);
            end
        end
    end

    initial begin
        int frame_idx;
        int pattern_id;
        int pattern_frame;
        int beat_idx;

        mismatch_count = 0;
        match_count    = 0;
        total_checks   = 0;
        outlier_count  = 0;
        total_abs_err  = 0;
        max_abs_err    = 0;
        compared_output_beats = 0;
        output_idle_cycles = 0;
        valid_mismatch_count = 0;
        frame_idx      = 0;
        beat_idx       = 0;

        $display("========================================");
        $display("tb_ssr_8x64_compare starting");
        $display("CLK_PERIOD=%0d ns, FRAME_CYCLES=%0d, TOTAL_FRAMES=%0d", CLK_PERIOD, FRAME_CYCLES, TOTAL_FRAMES);
        $display("ABS_TOLERANCE=%0d, REL_TOLERANCE=%.2f", ABS_TOLERANCE, REL_TOLERANCE);
        $display("SSR FFT: 8 lanes, 64-point, radix-8 systolic array");
        $display("Input patterns: ramp, DC, impulse, and checkerboard over longer back-to-back streams");
        $display("========================================");

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

        $display("t=%0t cycle=%0d: Starting %0d back-to-back frames across %0d patterns",
                 $time, cycle_count, TOTAL_FRAMES, PATTERN_COUNT);

        while (frame_idx < TOTAL_FRAMES) begin
            pattern_id = frame_idx / FRAMES_PER_PATTERN;
            pattern_frame = frame_idx % FRAMES_PER_PATTERN;

            @(negedge clk);
            i_valid = 1;
            drive_pattern_beat(pattern_id, pattern_frame, beat_idx);

            if (beat_idx == 0) begin
                $display("t=%0t cycle=%0d: frame=%0d pattern=%0d pattern_frame=%0d",
                         $time, cycle_count, frame_idx, pattern_id, pattern_frame);
            end

            beat_idx = beat_idx + 1;
            if (beat_idx == FRAME_CYCLES) begin
                beat_idx = 0;
                frame_idx = frame_idx + 1;
            end
        end

        @(negedge clk);
        i_valid = 0;
        $display("t=%0t cycle=%0d: Input stream complete, i_valid=0", $time, cycle_count);

        i_re_0 = 0; i_im_0 = 0;
        i_re_1 = 0; i_im_1 = 0;
        i_re_2 = 0; i_im_2 = 0;
        i_re_3 = 0; i_im_3 = 0;
        i_re_4 = 0; i_im_4 = 0;
        i_re_5 = 0; i_im_5 = 0;
        i_re_6 = 0; i_im_6 = 0;
        i_re_7 = 0; i_im_7 = 0;

        $display("t=%0t cycle=%0d: Waiting for outputs to quiesce...", $time, cycle_count);
        while ((compared_output_beats == 0) || (output_idle_cycles < OUTPUT_IDLE_CYCLES)) begin
            @(posedge clk);

            if (vhd_o_valid || sv_o_valid) begin
                output_idle_cycles = 0;
            end else if (compared_output_beats > 0) begin
                output_idle_cycles = output_idle_cycles + 1;
            end
        end

        $display("========================================");
        $display("t=%0t cycle=%0d: Comparison complete.", $time, cycle_count);
        $display("Total checks : %0d", total_checks);
        $display("Matches      : %0d", match_count);
        $display("Outliers     : %0d", mismatch_count);
        $display("Valid mismatches: %0d", valid_mismatch_count);
        $display("Total abs err: %0d", total_abs_err);
        $display("Max abs err  : %0d", max_abs_err);
        if ((mismatch_count == 0) && (valid_mismatch_count == 0)) begin
            $display("RESULT: PASS - All outputs within tolerance");
        end else begin
            $display("RESULT: FAIL - %0d outliers and %0d valid mismatches exceed tolerance (abs=%0d, rel=%.2f)",
                     mismatch_count, valid_mismatch_count, ABS_TOLERANCE, REL_TOLERANCE);
        end
        $display("========================================");

        $finish;
    end

endmodule
