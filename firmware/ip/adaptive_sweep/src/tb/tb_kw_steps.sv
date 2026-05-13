`timescale 1ns / 1ps
//
// tb_kw_steps.sv
//
// Unit testbench for kw_steps.v.  Exercises:
//   T1: load LUT with halve-every-16 schedule (AK0=1000)
//   T2: dp_signed > 0 -> x increases by LUT[k]
//   T3: dp_signed < 0 -> x decreases by LUT[k]
//   T4: dp_signed = 0 -> x unchanged, conv_flag=1
//   T5: x_sum below x_min -> clamp to x_min
//   T6: x_sum above x_max -> clamp to x_max
//   T7: conv_flag asserts when |LUT[k]| < KW_TOL
//

module tb_kw_steps;

    localparam int X_WIDTH   = 32;
    localparam int LUT_DEPTH = 256;
    localparam int LUT_AW    = 8;
    localparam [X_WIDTH-1:0] KW_TOL = 32'h0000_07D0;   // 2000

    localparam int LAT = 5;     // step_trigger -> valid_o latency

    logic                       clk;
    logic                       rst_n;
    logic                       lut_we;
    logic [LUT_AW-1:0]          lut_addr;
    logic signed [X_WIDTH-1:0]  lut_din;
    logic                       step_trigger;
    logic signed [X_WIDTH-1:0]  dp_signed;
    logic [LUT_AW-1:0]          k_idx;
    logic signed [X_WIDTH-1:0]  x_in, x_min, x_max;
    logic signed [X_WIDTH-1:0]  x_out;
    logic                       conv_flag;
    logic                       valid_o;

    int errors = 0, passes = 0;

    initial clk = 0;
    always #5 clk = ~clk;

    kw_steps #(
        .X_WIDTH  (X_WIDTH),
        .LUT_DEPTH(LUT_DEPTH),
        .LUT_AW   (LUT_AW),
        .KW_TOL   (KW_TOL)
    ) dut (
        .clk         (clk),
        .rst_n       (rst_n),
        .lut_we      (lut_we),
        .lut_addr    (lut_addr),
        .lut_din     (lut_din),
        .step_trigger(step_trigger),
        .dp_signed   (dp_signed),
        .k_idx       (k_idx),
        .x_in        (x_in),
        .x_min       (x_min),
        .x_max       (x_max),
        .x_out       (x_out),
        .conv_flag   (conv_flag),
        .valid_o     (valid_o)
    );

    // ---------------- Helpers ----------------
    task automatic load_lut(input [LUT_AW-1:0] addr,
                            input signed [X_WIDTH-1:0] val);
        @(posedge clk);
        lut_we   <= 1'b1;
        lut_addr <= addr;
        lut_din  <= val;
        @(posedge clk);
        lut_we   <= 1'b0;
    endtask

    task automatic do_step(input signed [X_WIDTH-1:0] dp,
                           input [LUT_AW-1:0]         kk,
                           input signed [X_WIDTH-1:0] xi,
                           input signed [X_WIDTH-1:0] xmn,
                           input signed [X_WIDTH-1:0] xmx,
                           output signed [X_WIDTH-1:0] xo,
                           output                      cf);
        int t;
        @(posedge clk);
        dp_signed    <= dp;
        k_idx        <= kk;
        x_in         <= xi;
        x_min        <= xmn;
        x_max        <= xmx;
        step_trigger <= 1'b1;
        @(posedge clk);
        step_trigger <= 1'b0;
        // wait for valid_o
        t = 0;
        while (!valid_o && t < 32) begin
            @(posedge clk);
            t++;
        end
        if (!valid_o) begin
            $display("[%0t] ERROR: timeout waiting for valid_o", $time);
            errors++;
            xo = 0; cf = 0;
        end else begin
            xo = x_out;
            cf = conv_flag;
        end
    endtask

    task automatic check_int(input string n,
                             input signed [X_WIDTH-1:0] got,
                             input signed [X_WIDTH-1:0] exp);
        if (got === exp) begin
            $display("[%0t] PASS %s: %0d", $time, n, got);
            passes++;
        end else begin
            $display("[%0t] FAIL %s: got=%0d exp=%0d", $time, n, got, exp);
            errors++;
        end
    endtask

    task automatic check_bit(input string n, input got, input exp);
        if (got === exp) begin
            $display("[%0t] PASS %s: %0b", $time, n, got);
            passes++;
        end else begin
            $display("[%0t] FAIL %s: got=%0b exp=%0b", $time, n, got, exp);
            errors++;
        end
    endtask

    // ---------------- Stimulus ----------------
    signed [X_WIDTH-1:0] xo;
    bit                  cf;

    initial begin
        rst_n        = 0;
        lut_we       = 0;
        lut_addr     = 0;
        lut_din      = 0;
        step_trigger = 0;
        dp_signed    = 0;
        k_idx        = 0;
        x_in         = 0;
        x_min        = 0;
        x_max        = 0;
        repeat (5) @(posedge clk);
        rst_n = 1;
        repeat (3) @(posedge clk);

        // T1: load LUT with halve-every-16 schedule (AK0=1000)
        $display("---- T1: load LUT ----");
        for (int k = 0; k < 256; k++) begin
            int sh;
            sh = k / 16;          // halve every 16
            load_lut(k[LUT_AW-1:0], 32'sd1000 >>> sh);
        end

        // T2: dp > 0, k=0 -> step = +1000, x: 5000 -> 6000.
        // |step|=1000 < KW_TOL=2000 -> conv=1.
        $display("---- T2: dp>0 ----");
        do_step(32'sd100, 8'd0, 32'sd5000, -32'sd1000000, 32'sd1000000, xo, cf);
        check_int("T2.x_out", xo, 32'sd6000);
        check_bit("T2.conv_flag", cf, 1'b1);

        // T3: dp<0, k=0 -> step = -1000, x: 5000 -> 4000
        $display("---- T3: dp<0 ----");
        do_step(-32'sd100, 8'd0, 32'sd5000, -32'sd1000000, 32'sd1000000, xo, cf);
        check_int("T3.x_out", xo, 32'sd4000);

        // T4: dp=0 -> step=0, x unchanged, conv=1
        $display("---- T4: dp=0 ----");
        do_step(32'sd0, 8'd0, 32'sd5000, -32'sd1000000, 32'sd1000000, xo, cf);
        check_int("T4.x_out", xo, 32'sd5000);
        check_bit("T4.conv_flag", cf, 1'b1);

        // T5: clamp to x_min
        $display("---- T5: clamp to x_min ----");
        do_step(-32'sd1, 8'd0, 32'sd100, 32'sd0, 32'sd1000000, xo, cf);
        // step = -1000, x_in = 100, x_sum = -900, clamp to x_min=0
        check_int("T5.x_out", xo, 32'sd0);

        // T6: clamp to x_max
        $display("---- T6: clamp to x_max ----");
        do_step(32'sd1, 8'd0, 32'sd999900, 32'sd0, 32'sd1000000, xo, cf);
        // step = +1000, x_in = 999900, x_sum = 1000900, clamp to x_max=1000000
        check_int("T6.x_out", xo, 32'sd1000000);

        // T7: conv flag for |step|<KW_TOL (k=80 -> sh=5 -> step=1000>>5=31, conv=1)
        $display("---- T7: conv_flag asserts ----");
        do_step(32'sd1, 8'd80, 32'sd5000, -32'sd1000000, 32'sd1000000, xo, cf);
        check_bit("T7.conv_flag", cf, 1'b1);

        // Conv flag does NOT assert for k=0 since 1000<2000? actually 1000<2000 IS true,
        // so conv=1 at k=0 too.  Use a smaller tol or larger LUT entries to test the
        // "not converged" branch:
        load_lut(8'd5, 32'sd5000);   // bigger than KW_TOL=2000
        $display("---- T7b: conv_flag negates ----");
        do_step(32'sd1, 8'd5, 32'sd5000, -32'sd1000000, 32'sd1000000, xo, cf);
        check_int("T7b.x_out", xo, 32'sd10000);
        check_bit("T7b.conv_flag", cf, 1'b0);  // |5000|>=2000 -> not converged

        $display("==== tb_kw_steps done: %0d passes, %0d errors ====",
                 passes, errors);
        if (errors == 0) $display("RESULT: ALL PASS");
        else             $display("RESULT: %0d FAIL", errors);
        $finish;
    end

    initial begin
        #100000;
        $display("[%0t] WATCHDOG: simulation timeout", $time);
        $finish;
    end

endmodule
