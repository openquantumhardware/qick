// ============================================================================
// File: ssr_fft_8x64_tc00.sv
// Description: SVUnit sanity testbench for ssr_fft_8x64 (vendor System
//              Generator FFT, 64 points, 8 samples per clock).
//
//   The core is not ours to verify bit by bit; these tests pin down what its
//   users rely on: a frame is 8 consecutive valid clocks, input sample
//   n = 8*t + l sits on lane l at clock t of the frame, a tone lands in
//   exactly one bin with gain 64 (i_scale = 0), and where each bin comes out
//   (lane, clock) so the consumers' reorder logic can be checked against it.
//
//   Inputs are driven with a non-blocking assignment right after a rising
//   edge; outputs are sampled on the falling edge.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module ssr_fft_8x64_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "ssr_fft_8x64_ut";
    svunit_testcase svunit_ut;

    localparam real CLOCK_FREQUENCY = 300e6;
    localparam real PI = 3.14159265358979323846;

    logic clk = 1'b0;
    clk_gen #(.FREQ(CLOCK_FREQUENCY)) u_clk (.i_enable(1'b1), .o_clk(clk));

    logic signed [15:0] i_re [8], i_im [8];
    logic               i_valid = 1'b0;
    logic [5:0]         i_scale = '0;
    logic signed [26:0] o_re [8], o_im [8];
    logic [0:0]         o_valid;
    logic [5:0]         o_scale;

    ssr_8x64 dut (
        .clk     (clk),
        .i_re_0  (i_re[0]), .i_re_1 (i_re[1]), .i_re_2 (i_re[2]), .i_re_3 (i_re[3]),
        .i_re_4  (i_re[4]), .i_re_5 (i_re[5]), .i_re_6 (i_re[6]), .i_re_7 (i_re[7]),
        .i_im_0  (i_im[0]), .i_im_1 (i_im[1]), .i_im_2 (i_im[2]), .i_im_3 (i_im[3]),
        .i_im_4  (i_im[4]), .i_im_5 (i_im[5]), .i_im_6 (i_im[6]), .i_im_7 (i_im[7]),
        .i_valid (i_valid),
        .i_scale (i_scale),
        .o_re_0  (o_re[0]), .o_re_1 (o_re[1]), .o_re_2 (o_re[2]), .o_re_3 (o_re[3]),
        .o_re_4  (o_re[4]), .o_re_5 (o_re[5]), .o_re_6 (o_re[6]), .o_re_7 (o_re[7]),
        .o_im_0  (o_im[0]), .o_im_1 (o_im[1]), .o_im_2 (o_im[2]), .o_im_3 (o_im[3]),
        .o_im_4  (o_im[4]), .o_im_5 (o_im[5]), .o_im_6 (o_im[6]), .o_im_7 (o_im[7]),
        .o_valid (o_valid),
        .o_scale (o_scale)
    );

    // One captured output frame: 8 valid clocks x 8 lanes.
    logic signed [26:0] f_re [8][8], f_im [8][8];

    // Drive `nframes` frames of the complex tone A*exp(j*2*pi*k0*n/64),
    // continuously valid.
    task automatic drive_tone(input int k0, input int amp, input int nframes);
        for (int f = 0; f < nframes; f++)
            for (int t = 0; t < 8; t++) begin
                @(posedge clk);
                i_valid <= 1'b1;
                for (int l = 0; l < 8; l++) begin
                    real ph = 2.0 * PI * k0 * (8 * t + l) / 64.0;
                    i_re[l] <= 16'($rtoi(amp * $cos(ph)));
                    i_im[l] <= 16'($rtoi(amp * $sin(ph)));
                end
            end
        @(posedge clk);
        i_valid <= 1'b0;
    endtask

    // Capture the 8 valid clocks that follow the first `skip` valid clocks
    // (frames are aligned to the first valid clock after idle).
    task automatic capture_frame(input int skip);
        int seen = 0, t = 0, guard = 0;
        while (t < 8 && guard < 2000) begin
            @(negedge clk);
            guard++;
            if (o_valid[0]) begin
                if (seen >= skip) begin
                    for (int l = 0; l < 8; l++) begin
                        f_re[t][l] = o_re[l];
                        f_im[t][l] = o_im[l];
                    end
                    t++;
                end
                seen++;
            end
        end
    endtask

    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        i_valid = 1'b0;
        i_scale = '0;
        for (int l = 0; l < 8; l++) begin i_re[l] = '0; i_im[l] = '0; end
        // Flush whatever the previous test left in the pipeline.
        repeat (200) @(posedge clk);
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    `SVUNIT_TESTS_BEGIN
    `include "ssr_fft_8x64_tests.sv"
    `SVUNIT_TESTS_END
endmodule
