`timescale 1ns / 1ps
//
// tb_iq_power.sv
//
// Unit testbench for iq_power.v.  Streams a small set of (I, Q) corner
// vectors and checks power_o == I*I + Q*Q for each, with the documented
// 3-cycle latency.
//

module tb_iq_power;

    localparam int IQ_WIDTH  = 16;
    localparam int POW_WIDTH = 32;
    localparam int LAT       = 3;            // pipeline latency in cycles

    logic                          clk;
    logic                          rst_n;
    logic signed [IQ_WIDTH-1:0]    i_in, q_in;
    logic                          valid_in;
    logic        [POW_WIDTH-1:0]   power_o;
    logic                          valid_o;

    // Reference shift register so we can compare delayed input to current output
    logic signed [IQ_WIDTH-1:0]    i_pipe [0:LAT-1];
    logic signed [IQ_WIDTH-1:0]    q_pipe [0:LAT-1];
    logic                          v_pipe [0:LAT-1];

    int errors = 0;
    int passes = 0;

    initial clk = 0;
    always #5 clk = ~clk;

    iq_power #(
        .IQ_WIDTH (IQ_WIDTH),
        .POW_WIDTH(POW_WIDTH)
    ) dut (
        .clk     (clk),
        .rst_n   (rst_n),
        .i_in    (i_in),
        .q_in    (q_in),
        .valid_in(valid_in),
        .power_o (power_o),
        .valid_o (valid_o)
    );

    // shift the pipeline every cycle
    always @(posedge clk) begin
        if (!rst_n) begin
            for (int k = 0; k < LAT; k++) begin
                i_pipe[k] <= '0;
                q_pipe[k] <= '0;
                v_pipe[k] <= 1'b0;
            end
        end else begin
            i_pipe[0] <= i_in;
            q_pipe[0] <= q_in;
            v_pipe[0] <= valid_in;
            for (int k = 1; k < LAT; k++) begin
                i_pipe[k] <= i_pipe[k-1];
                q_pipe[k] <= q_pipe[k-1];
                v_pipe[k] <= v_pipe[k-1];
            end
        end
    end

    // Continuous self-check: when valid_o goes high, power_o must equal
    // (i_pipe[LAT-1])^2 + (q_pipe[LAT-1])^2
    always @(posedge clk) begin
        if (rst_n && valid_o) begin
            automatic logic [POW_WIDTH-1:0] expected =
                $signed(i_pipe[LAT-1]) * $signed(i_pipe[LAT-1]) +
                $signed(q_pipe[LAT-1]) * $signed(q_pipe[LAT-1]);
            if (power_o === expected) begin
                passes++;
            end else begin
                $display("[%0t] FAIL: I=%0d Q=%0d -> got=%0d exp=%0d",
                         $time, i_pipe[LAT-1], q_pipe[LAT-1],
                         power_o, expected);
                errors++;
            end
        end
    end

    task automatic drive(input signed [IQ_WIDTH-1:0] iv,
                         input signed [IQ_WIDTH-1:0] qv);
        @(posedge clk);
        i_in     <= iv;
        q_in     <= qv;
        valid_in <= 1'b1;
        @(posedge clk);
        valid_in <= 1'b0;
        i_in     <= '0;
        q_in     <= '0;
    endtask

    initial begin
        rst_n    = 0;
        i_in     = 0;
        q_in     = 0;
        valid_in = 0;
        repeat (5) @(posedge clk);
        rst_n = 1;
        repeat (3) @(posedge clk);

        // Corner cases
        drive( 0,            0);
        drive( 16'sh7FFF,    0);                 // max positive I
        drive( 0,            16'sh7FFF);         // max positive Q
        drive(-16'sh8000,    0);                 // max negative I
        drive( 0,           -16'sh8000);         // max negative Q
        drive( 16'sh7FFF,    16'sh7FFF);         // both max positive
        drive(-16'sh8000,   -16'sh8000);         // both max negative
        drive( 16'sd100,     16'sd200);          // small values
        drive(-16'sd100,     16'sd200);          // mixed signs
        drive( 16'sd1234,   -16'sd5678);

        // Random walk
        for (int n = 0; n < 64; n++) begin
            drive($random, $random);
        end

        // Drain pipeline
        repeat (LAT + 5) @(posedge clk);

        $display("==== tb_iq_power done: %0d passes, %0d errors ====",
                 passes, errors);
        if (errors == 0) $display("RESULT: ALL PASS");
        else             $display("RESULT: %0d FAIL", errors);
        $finish;
    end

    initial begin
        #20000;
        $display("[%0t] WATCHDOG: simulation timeout", $time);
        $finish;
    end

endmodule
