`timescale 1ns / 1ps
//
// tb_adaptive_sweep.sv
//
// Top-level integration testbench for the adaptive_sweep IP.  Emulates a
// tProc on the QP2 (qtag_*) interface and a readout on the AXIS snoop
// interface, walks through a representative opcode sequence, and checks
// the major datapaths.
//
// Sequence:
//   1. Reset, configure (SET_NAVG, SET_CHUNK_LOG2, SET_BOUNDS, SET_X)
//   2. Load a small KW LUT (8 entries used for this test)
//   3. ARM_CAPTURE(16), then drive 16 synthetic I/Q samples on ro_clk
//      and pulse the trigger; wait for capture_done
//   4. GET_IQ_AVG -> compare to expected mean
//   5. GET_POWER  -> compare to I_avg^2 + Q_avg^2
//   6. KW_STEP with dp>0 -> verify x increases by LUT[k_idx]
//   7. BISECT_INIT + BISECT_STEP loop on a synthetic peak curve
//

module tb_adaptive_sweep;

    // ---------------- Parameters ----------------
    localparam int IQ_WIDTH    = 16;
    localparam int X_WIDTH     = 32;
    localparam int LUT_AW      = 8;
    localparam int COUNT_WIDTH = 16;
    localparam int N_AVG       = 16;
    localparam int CHUNK_LOG2  = 4;
    // ceil(2^32 / 16) = 268_435_456
    localparam logic [31:0] RECIP_16 = 32'd268435456;

    // ---------------- Clocks ----------------
    logic clk;       // c_clk = 200 MHz
    logic ro_clk;    // ro_clk = 307.2 MHz
    initial clk    = 0;
    initial ro_clk = 0;
    always  #2.5    clk    = ~clk;
    always  #1.6275 ro_clk = ~ro_clk;

    // ---------------- Resets ----------------
    logic rst_n;
    logic ro_aresetn;

    // ---------------- DUT ports ----------------
    logic                       qtag_en;
    logic [4:0]                 qtag_op;
    logic [31:0]                qtag_dt1, qtag_dt2, qtag_dt3, qtag_dt4;
    logic                       qtag_rdy;
    logic [31:0]                qtag_dt1_o, qtag_dt2_o;
    logic                       qtag_vld;

    logic [2*IQ_WIDTH-1:0]      ro_tdata;
    logic                       ro_tvalid;
    logic                       ro_tready;
    logic                       trigger;

    int errors = 0, passes = 0;

    // ---------------- DUT ----------------
    adaptive_sweep #(
        .LUT_DEPTH         (256),
        .LUT_AW            (LUT_AW),
        .X_WIDTH           (X_WIDTH),
        .IQ_WIDTH          (IQ_WIDTH),
        .SUM_WIDTH         (48),
        .POW_WIDTH         (32),
        .COUNT_WIDTH       (COUNT_WIDTH),
        .RO_FIFO_DEPTH_LOG2(6),
        .KW_TOL            (32'h0000_07D0)
    ) dut (
        .clk               (clk),
        .rst_n             (rst_n),
        .qtag_en_i         (qtag_en),
        .qtag_op_i         (qtag_op),
        .qtag_dt1_i        (qtag_dt1),
        .qtag_dt2_i        (qtag_dt2),
        .qtag_dt3_i        (qtag_dt3),
        .qtag_dt4_i        (qtag_dt4),
        .qtag_rdy_o        (qtag_rdy),
        .qtag_dt1_o        (qtag_dt1_o),
        .qtag_dt2_o        (qtag_dt2_o),
        .qtag_vld_o        (qtag_vld),
        .s_ro_axis_aclk    (ro_clk),
        .s_ro_axis_aresetn (ro_aresetn),
        .s_ro_axis_tdata   (ro_tdata),
        .s_ro_axis_tvalid  (ro_tvalid),
        .s_ro_axis_tready  (ro_tready),
        .trigger_i         (trigger)
    );

    // ---------------- QP2 driver ----------------
    task automatic qp2_op(input [4:0] op,
                          input [31:0] d1, input [31:0] d2,
                          input [31:0] d3, input [31:0] d4,
                          output [31:0] r1, output [31:0] r2);
        int t;
        @(posedge clk);
        qtag_op  <= op;
        qtag_dt1 <= d1;
        qtag_dt2 <= d2;
        qtag_dt3 <= d3;
        qtag_dt4 <= d4;
        qtag_en  <= 1'b1;
        @(posedge clk);
        qtag_en  <= 1'b0;
        // wait for qtag_vld
        t = 0;
        while (!qtag_vld && t < 200) begin @(posedge clk); t++; end
        if (!qtag_vld) begin
            $display("[%0t] ERROR: qp2_op(0x%02h) timeout", $time, op);
            errors++;
            r1 = 0; r2 = 0;
        end else begin
            r1 = qtag_dt1_o;
            r2 = qtag_dt2_o;
        end
    endtask

    task automatic check_int(input string n, input int got, input int exp,
                             input int tol = 1);
        int diff;
        diff = (got > exp) ? (got - exp) : (exp - got);
        if (diff <= tol) begin
            $display("[%0t] PASS %s: got=%0d exp=%0d", $time, n, got, exp);
            passes++;
        end else begin
            $display("[%0t] FAIL %s: got=%0d exp=%0d (tol=%0d)",
                     $time, n, got, exp, tol);
            errors++;
        end
    endtask

    // ---------------- ro_clk stream feeder ----------------
    // Sends `n` samples with constant (i_val, q_val) on ro_clk after `wait_cycles`.
    task automatic ro_stream_constant(input int n,
                                      input signed [IQ_WIDTH-1:0] i_val,
                                      input signed [IQ_WIDTH-1:0] q_val,
                                      input int wait_cycles);
        int sent;
        @(posedge ro_clk);
        repeat (wait_cycles) @(posedge ro_clk);
        sent = 0;
        ro_tvalid <= 1'b1;
        while (sent < n) begin
            ro_tdata <= {q_val, i_val};
            @(posedge ro_clk);
            sent++;
        end
        ro_tvalid <= 1'b0;
    endtask

    // Trigger pulse on ro_clk
    task automatic ro_trigger();
        @(posedge ro_clk);
        trigger <= 1;
        @(posedge ro_clk);
        trigger <= 0;
    endtask

    // ---------------- Stimulus ----------------
    logic [31:0] r1, r2;

    initial begin
        // Init
        rst_n      = 0;
        ro_aresetn = 0;
        qtag_en    = 0;
        qtag_op    = 0;
        qtag_dt1   = 0;
        qtag_dt2   = 0;
        qtag_dt3   = 0;
        qtag_dt4   = 0;
        ro_tdata   = 0;
        ro_tvalid  = 0;
        trigger    = 0;
        repeat (20) @(posedge clk);
        rst_n      = 1;
        ro_aresetn = 1;
        repeat (20) @(posedge clk);

        // 1. Configure
        $display("---- 1. Configure ----");
        qp2_op(5'h01, 0, 0, 0, 0, r1, r2);                          // RESET_ALL
        qp2_op(5'h02, N_AVG, RECIP_16, 0, 0, r1, r2);               // SET_NAVG
        qp2_op(5'h03, CHUNK_LOG2, 0, 0, 0, r1, r2);                 // SET_CHUNK_LOG2
        qp2_op(5'h05, 32'h0, 32'h0010_0000, 0, 0, r1, r2);          // SET_BOUNDS [0, 1M]
        qp2_op(5'h04, 32'h0001_0000, 0, 0, 0, r1, r2);              // SET_X = 65536

        // 2. Load a small KW LUT (k=0..7 -> 1000)
        $display("---- 2. Load KW LUT ----");
        for (int k = 0; k < 8; k++) begin
            qp2_op(5'h09, k, 32'sd5000, 0, 0, r1, r2);              // KW_LUT_WE
        end

        // 3. ARM and stream constant samples 100/200
        $display("---- 3. ARM_CAPTURE + stream ----");
        qp2_op(5'h06, N_AVG, 0, 0, 0, r1, r2);                      // ARM_CAPTURE(16)
        // start ro stream a few cycles after arm + trigger
        fork
            ro_stream_constant(N_AVG, 16'sd100, 16'sd200, 4);
            begin
                repeat (8) @(posedge ro_clk);
                ro_trigger();
            end
        join

        // Poll GET_STATUS until capture_done
        begin
            int t;
            t = 0;
            while (t < 100) begin
                qp2_op(5'h10, 0, 0, 0, 0, r1, r2);
                if (r2[1]) begin
                    $display("[%0t] capture_done observed (samples_remaining=%0d)",
                             $time, r1);
                    break;
                end
                t++;
            end
            if (t >= 100) begin
                $display("[%0t] FAIL: capture_done never observed", $time);
                errors++;
            end
        end

        // 4. GET_IQ_AVG -> expect (100, 200)
        $display("---- 4. GET_IQ_AVG ----");
        qp2_op(5'h07, 0, 0, 0, 0, r1, r2);
        check_int("I_avg", $signed(r1), 32'sd100, 1);
        check_int("Q_avg", $signed(r2), 32'sd200, 1);

        // 5. GET_POWER -> expect 100^2 + 200^2 = 50000
        $display("---- 5. GET_POWER ----");
        qp2_op(5'h08, 0, 0, 0, 0, r1, r2);
        check_int("power", r1, 50000, 2);

        // 6. KW_STEP with dp>0, k=0 -> x: 65536 -> 70536 (step=+5000)
        $display("---- 6. KW_STEP (dp>0) ----");
        qp2_op(5'h0A, 32'sd1000, 32'd0, 0, 0, r1, r2);
        check_int("x_new", $signed(r1), 32'sd70536, 1);

        // 6b. GET_X
        qp2_op(5'h0B, 0, 0, 0, 0, r1, r2);
        check_int("x_after_step", $signed(r1), 32'sd70536, 1);

        // 7. BISECT_INIT + BISECT_STEP loop: peak / left at edge=400
        $display("---- 7. BISECT (peak/left, edge~400) ----");
        // dt4: bit0=side_left=1, bit1=polarity_peak=1 -> dt4=2'b11
        qp2_op(5'h0D, 32'd0, 32'd1024, 32'd4, 32'd3, r1, r2);   // BISECT_INIT
        for (int it = 0; it < 16; it++) begin
            int x_mid;
            int dx;
            int p;
            // Read mid_next
            qp2_op(5'h0F, 0, 0, 0, 0, r1, r2);                  // GET_BISECT
            x_mid = (r1 + r2) >> 1;
            dx    = (x_mid > 512) ? (x_mid - 512) : (512 - x_mid);
            p     = 32768 - dx*64; if (p < 0) p = 0;
            qp2_op(5'h0E, p, 32'd16000, 0, 0, r1, r2);          // BISECT_STEP
            if (r2[0]) begin
                $display("[%0t] bisect converged at iter %0d", $time, it);
                break;
            end
        end
        qp2_op(5'h0F, 0, 0, 0, 0, r1, r2);
        if (r1 <= 32'd400 && 32'd400 <= r2) begin
            $display("[%0t] PASS bisect.range: [%0d, %0d] contains 400",
                     $time, r1, r2);
            passes++;
        end else begin
            $display("[%0t] FAIL bisect.range: [%0d, %0d] does not contain 400",
                     $time, r1, r2);
            errors++;
        end

        $display("==== tb_adaptive_sweep done: %0d passes, %0d errors ====",
                 passes, errors);
        if (errors == 0) $display("RESULT: ALL PASS");
        else             $display("RESULT: %0d FAIL", errors);
        $finish;
    end

    initial begin
        #2000000;
        $display("[%0t] WATCHDOG: simulation timeout", $time);
        $finish;
    end

endmodule
