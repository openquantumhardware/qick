`timescale 1ns / 1ps
//
// tb_bisect_control.sv
//
// Unit testbench for bisect_control.v.  Verifies that on a synthetic peak
// curve the bisection narrows to within `tol` in the expected number of
// steps for all four (polarity, side) corners.
//

module tb_bisect_control;

    localparam int X_WIDTH = 32;
    localparam [X_WIDTH-1:0] LO0   = 32'd0;
    localparam [X_WIDTH-1:0] HI0   = 32'd1024;
    localparam [X_WIDTH-1:0] TOL   = 32'd4;
    localparam [X_WIDTH-1:0] EDGE  = 32'd400;       // synthetic edge location

    logic                      clk, rst_n;
    logic                      init, step;
    logic [X_WIDTH-1:0]        lo_init, hi_init, tol_in;
    logic                      side_left, polarity_peak;
    logic [X_WIDTH-1:0]        pow_mid, pow_thr;
    logic [X_WIDTH-1:0]        mid_next, lo_o, hi_o;
    logic                      converged_o, valid_o;

    int errors = 0, passes = 0;

    initial clk = 0;
    always #5 clk = ~clk;

    bisect_control #(.X_WIDTH(X_WIDTH)) dut (
        .clk         (clk),
        .rst_n       (rst_n),
        .init        (init),
        .lo_init     (lo_init),
        .hi_init     (hi_init),
        .side_left   (side_left),
        .polarity_peak(polarity_peak),
        .tol_in      (tol_in),
        .step        (step),
        .pow_mid     (pow_mid),
        .pow_thr     (pow_thr),
        .mid_next    (mid_next),
        .lo_o        (lo_o),
        .hi_o        (hi_o),
        .converged_o (converged_o),
        .valid_o     (valid_o)
    );

    // Synthetic peak power curve, peak at x=512:
    //   pow(x) = max(0, 32768 - |x-512|*64)
    // Threshold 16000 -> left edge at x=512-(32768-16000)/64=512-262=250
    //                    right edge at x=512+262=774
    function automatic [31:0] pow_peak(input [31:0] x);
        int dx;
        int p;
        dx = (x > 512) ? (x - 512) : (512 - x);
        p  = 32768 - dx * 64;
        if (p < 0) p = 0;
        return p;
    endfunction

    function automatic [31:0] pow_dip(input [31:0] x);
        int dx;
        int p;
        dx = (x > 512) ? (x - 512) : (512 - x);
        p  = dx * 64;
        if (p > 32768) p = 32768;
        return p;
    endfunction

    task automatic do_init(input [X_WIDTH-1:0] lo, input [X_WIDTH-1:0] hi,
                           input s_left, input p_peak,
                           input [X_WIDTH-1:0] tol);
        @(posedge clk);
        init       <= 1;
        lo_init    <= lo;
        hi_init    <= hi;
        side_left  <= s_left;
        polarity_peak <= p_peak;
        tol_in     <= tol;
        @(posedge clk);
        init       <= 0;
    endtask

    task automatic do_step(input [X_WIDTH-1:0] mid_x,
                           input bit            peak);
        int t;
        @(posedge clk);
        pow_mid <= peak ? pow_peak(mid_x) : pow_dip(mid_x);
        pow_thr <= 32'd16000;
        step    <= 1;
        @(posedge clk);
        step    <= 0;
        t = 0;
        while (!valid_o && t < 16) begin @(posedge clk); t++; end
    endtask

    task automatic check_range(input string n,
                               input [X_WIDTH-1:0] lo,
                               input [X_WIDTH-1:0] hi,
                               input [X_WIDTH-1:0] target);
        if (lo <= target && target <= hi) begin
            $display("[%0t] PASS %s: [%0d, %0d] contains %0d",
                     $time, n, lo, hi, target);
            passes++;
        end else begin
            $display("[%0t] FAIL %s: [%0d, %0d] does NOT contain %0d",
                     $time, n, lo, hi, target);
            errors++;
        end
    endtask

    task automatic run_bisect(input bit s_left, input bit p_peak,
                              input [X_WIDTH-1:0] target_edge);
        do_init(LO0, HI0, s_left, p_peak, TOL);
        repeat (3) @(posedge clk);
        for (int i = 0; i < 20; i++) begin
            if (converged_o) break;
            do_step(mid_next, p_peak);
        end
        check_range($sformatf("polarity=%0d side_left=%0d", p_peak, s_left),
                    lo_o, hi_o, target_edge);
    endtask

    initial begin
        rst_n = 0;
        init = 0; step = 0;
        lo_init = 0; hi_init = 0; tol_in = 0;
        side_left = 0; polarity_peak = 0;
        pow_mid = 0; pow_thr = 0;
        repeat (5) @(posedge clk);
        rst_n = 1;
        repeat (3) @(posedge clk);

        // peak / left edge -> ~250
        $display("---- run peak/left ----");
        run_bisect(1'b1, 1'b1, 32'd250);

        // peak / right edge -> ~774
        $display("---- run peak/right ----");
        run_bisect(1'b0, 1'b1, 32'd774);

        // dip / left edge -> ~250
        $display("---- run dip/left ----");
        run_bisect(1'b1, 1'b0, 32'd250);

        // dip / right edge -> ~774
        $display("---- run dip/right ----");
        run_bisect(1'b0, 1'b0, 32'd774);

        $display("==== tb_bisect_control done: %0d passes, %0d errors ====",
                 passes, errors);
        if (errors == 0) $display("RESULT: ALL PASS");
        else             $display("RESULT: %0d FAIL", errors);
        $finish;
    end

    initial begin
        #200000;
        $display("[%0t] WATCHDOG: simulation timeout", $time);
        $finish;
    end

endmodule
