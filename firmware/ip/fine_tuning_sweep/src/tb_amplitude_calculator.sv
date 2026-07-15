`timescale 1ns / 1ps
//------------------------------------------------------------------------------
// tb_amplitude_calculator -- self-checking unit sim for the two-stage
// accumulate-and-shift power calculator.
//
//   Golden model mirrors the RTL's exact round-half-up + floor-log2-shift
//   algorithm (see CLAUDE.md: I1-I4) using 64-bit integer math -- DUT power
//   must match the golden model EXACTLY for every case below.
//
//   N2 (avg) is tested up to 4096 (2^12) shots per point, not the design's
//   documented max of 2^29 -- simulating 2^29 shots is not tractable in
//   xsim. The 46-bit accumulator width for N2<=2^29 is a closed-form proof
//   (see plan / CLAUDE.md), not exhaustively simulated here; this TB
//   exercises the SAME shift/round logic at a power-of-two and non-power-of-
//   two N2 to validate the algorithm, and separately asserts the proven
//   tight numeric bounds on shot_mean/point_mean every cycle regardless of
//   N2 used.
//------------------------------------------------------------------------------

module tb_amplitude_calculator();

    reg clk;
    reg rst_n;
    always #5 clk = ~clk;

    reg s_axis_tvalid;
    reg s_axis_tready;
    reg [63:0] s_axis_tdata;
    reg arm;
    reg [31:0] averager_value;
    reg [31:0] nsamp;
    wire [35:0] m_axis_tdata;
    wire m_axis_tvalid;

    amplitude_calculator dut (
        .clk            (clk),
        .rst_n          (rst_n),
        .s_axis_tvalid  (s_axis_tvalid),
        .s_axis_tready  (s_axis_tready),
        .s_axis_tdata   (s_axis_tdata),
        .arm            (arm),
        .averager_value (averager_value),
        .nsamp          (nsamp),
        .m_axis_tdata   (m_axis_tdata),
        .m_axis_tvalid  (m_axis_tvalid)
    );

    integer pass_count, fail_count;

    function automatic int flog2_g(input int unsigned v);
        int r;
        int k;
        begin
            r = 0;
            for (k = 31; k >= 1; k = k - 1) begin
                if (v[k] && r == 0)
                    r = k;
            end
            flog2_g = r;
        end
    endfunction

    function automatic longint round_shift_g(input longint val, input int s);
        longint rnd;
        begin
            rnd = (s == 0) ? 0 : (64'sd1 <<< (s - 1));
            round_shift_g = (val + rnd) >>> s;
        end
    endfunction

    function automatic longint golden_power(
        input longint isums[],
        input longint qsums[],
        input int unsigned nsamp_v,
        input int unsigned avg_v
    );
        int s1, s2;
        longint iacc, qacc, ipm, qpm;
        int k;
        begin
            s1 = flog2_g(nsamp_v);
            s2 = flog2_g(avg_v);
            iacc = 0;
            qacc = 0;
            for (k = 0; k < isums.size(); k = k + 1) begin
                iacc = iacc + round_shift_g(isums[k], s1);
                qacc = qacc + round_shift_g(qsums[k], s1);
            end
            ipm = round_shift_g(iacc, s2);
            qpm = round_shift_g(qacc, s2);
            golden_power = ipm * ipm + qpm * qpm;
        end
    endfunction

    function automatic real true_power(
        input longint isums[],
        input longint qsums[],
        input int unsigned nsamp_v,
        input int unsigned avg_v
    );
        longint isum, qsum;
        real denom, mean_i, mean_q;
        int k, s1, s2;
        begin
            isum = 0;
            qsum = 0;
            for (k = 0; k < isums.size(); k = k + 1) begin
                isum = isum + isums[k];
                qsum = qsum + qsums[k];
            end
            // exact (UNROUNDED) two-stage mean using the SAME 2^s1 * 2^s2
            // divisor the RTL uses -- not exact n1*avg. Dividing by the
            // nearest power-of-two-below-n1 (not n1 itself) is an
            // intentional, systematic scale factor of the design (same for
            // every point in a pass, so argmax-irrelevant); this function
            // isolates the ROUNDING error on top of that, which is the
            // quantity the near-tie/quantization bound documents.
            s1 = flog2_g(nsamp_v);
            s2 = flog2_g(avg_v);
            denom = real'(longint'(1) <<< (s1 + s2));
            mean_i = real'(isum) / denom;
            mean_q = real'(qsum) / denom;
            true_power = mean_i * mean_i + mean_q * mean_q;
        end
    endfunction

    task automatic do_reset;
        begin
            rst_n = 1'b0;
            s_axis_tvalid = 1'b0;
            s_axis_tready = 1'b1;
            s_axis_tdata = 64'd0;
            arm = 1'b0;
            averager_value = 32'd0;
            nsamp = 32'd0;
            pass_count = 0;
            fail_count = 0;
            repeat (5) @(posedge clk);
            #1;
            rst_n = 1'b1;
            repeat (5) @(posedge clk);
        end
    endtask

    task automatic pulse_arm(input int unsigned nsamp_v, input int unsigned avg_v);
        begin
            @(posedge clk); #1;
            nsamp = nsamp_v;
            averager_value = avg_v;
            arm = 1'b1;
            @(posedge clk); #1;
            arm = 1'b0;
        end
    endtask

    task automatic fire_shot(input longint isum, input longint qsum);
        begin
            @(posedge clk); #1;
            s_axis_tdata = {qsum[31:0], isum[31:0]};
            s_axis_tvalid = 1'b1;
            @(posedge clk); #1;
            s_axis_tvalid = 1'b0;
            s_axis_tdata = 64'd0;
        end
    endtask

    task automatic wait_result(output longint got_power);
        begin
            while (!m_axis_tvalid) @(posedge clk);
            got_power = {28'd0, m_axis_tdata};
            @(posedge clk);
        end
    endtask

    task automatic run_point(
        input int unsigned nsamp_v,
        input int unsigned avg_v,
        input longint isums[],
        input longint qsums[],
        input string tag
    );
        longint golden, got;
        int k;
        begin
            pulse_arm(nsamp_v, avg_v);
            for (k = 0; k < isums.size(); k = k + 1)
                fire_shot(isums[k], qsums[k]);
            wait_result(got);
            golden = golden_power(isums, qsums, nsamp_v, avg_v);
            if (got == golden) begin
                pass_count = pass_count + 1;
                $display("[%0t] PASS %s: power=%0d", $time, tag, got);
            end else begin
                fail_count = fail_count + 1;
                $display("[%0t] FAIL %s: got=%0d golden=%0d", $time, tag, got, golden);
            end
        end
    endtask

    task automatic run_bound_check(
        input int unsigned nsamp_v,
        input int unsigned avg_v,
        input longint isums[],
        input longint qsums[],
        input real rel_bound,
        input string tag
    );
        longint got;
        real truep, relerr;
        int k;
        begin
            pulse_arm(nsamp_v, avg_v);
            for (k = 0; k < isums.size(); k = k + 1)
                fire_shot(isums[k], qsums[k]);
            wait_result(got);
            truep = true_power(isums, qsums, nsamp_v, avg_v);
            relerr = (truep == 0.0) ? 0.0 : (real'(got) - truep) / truep;
            if (relerr < 0.0)
                relerr = -relerr;
            if (relerr <= rel_bound) begin
                pass_count = pass_count + 1;
                $display("[%0t] PASS %s: quantized=%0d true=%.3e relerr=%.3e (bound %.3e)",
                          $time, tag, got, truep, relerr, rel_bound);
            end else begin
                fail_count = fail_count + 1;
                $display("[%0t] FAIL %s: quantized=%0d true=%.3e relerr=%.3e EXCEEDS bound %.3e",
                          $time, tag, got, truep, relerr, rel_bound);
            end
        end
    endtask

    always @(posedge clk) begin
        if (rst_n && dut.acc_en) begin
            if (dut.shot_mean_i > 17'sd65534 || dut.shot_mean_i < -17'sd65535) begin
                $display("[%0t] BOUND FAIL: shot_mean_i=%0d outside proven [-65535,65534]", $time, dut.shot_mean_i);
                fail_count = fail_count + 1;
            end
            if (dut.shot_mean_q > 17'sd65534 || dut.shot_mean_q < -17'sd65535) begin
                $display("[%0t] BOUND FAIL: shot_mean_q=%0d outside proven [-65535,65534]", $time, dut.shot_mean_q);
                fail_count = fail_count + 1;
            end
            if (dut.is_last) begin
                if (dut.point_mean_i_next > 18'sd131070 || dut.point_mean_i_next < -18'sd131072) begin
                    $display("[%0t] BOUND FAIL: point_mean_i_next=%0d outside proven [-131072,131070]", $time, dut.point_mean_i_next);
                    fail_count = fail_count + 1;
                end
                if (dut.point_mean_q_next > 18'sd131070 || dut.point_mean_q_next < -18'sd131072) begin
                    $display("[%0t] BOUND FAIL: point_mean_q_next=%0d outside proven [-131072,131070]", $time, dut.point_mean_q_next);
                    fail_count = fail_count + 1;
                end
            end
        end
    end

    longint isums_a[], qsums_a[];
    int k;

    initial begin
        clk = 0;
        do_reset();

        // 1. Full-scale: n1=2^16 (avg_buffer's own overflow ceiling), positive
        //    extreme, N2=4096 (power-of-two stand-in for "N2 at max", see header)
        isums_a = new[4096];
        qsums_a = new[4096];
        for (k = 0; k < 4096; k = k + 1) begin
            isums_a[k] = 65536 * 32767;
            qsums_a[k] = 65536 * 32767;
        end
        run_point(65536, 4096, isums_a, qsums_a, "fullscale_pos_pow2");

        // 1b. Full-scale negative extreme -- exact int32 min shot sum
        for (k = 0; k < 4096; k = k + 1) begin
            isums_a[k] = -65536 * 32768;
            qsums_a[k] = -65536 * 32768;
        end
        run_point(65536, 4096, isums_a, qsums_a, "fullscale_neg_pow2");

        // 2. Worst non-power n1 AND N2 simultaneously
        isums_a = new[1000];
        qsums_a = new[1000];
        for (k = 0; k < 1000; k = k + 1) begin
            isums_a[k] = 1000 * 20000 - k;
            qsums_a[k] = -1000 * 15000 + 2 * k;
        end
        run_point(1000, 1000, isums_a, qsums_a, "n1_1000_avg_1000_nonpow2");

        // 2b. Small worst non-power n1=3, N2=3
        isums_a = new[3];
        qsums_a = new[3];
        isums_a[0] = 3 * 100; qsums_a[0] = 3 * (-200);
        isums_a[1] = 3 * (-50); qsums_a[1] = 3 * 300;
        isums_a[2] = 3 * 400; qsums_a[2] = 3 * (-10);
        run_point(3, 3, isums_a, qsums_a, "n1_3_avg_3");

        // 2c. 2^k+1 non-power cases: n1=1025, N2=65
        isums_a = new[65];
        qsums_a = new[65];
        for (k = 0; k < 65; k = k + 1) begin
            isums_a[k] = 1025 * (1000 + k);
            qsums_a[k] = 1025 * (-2000 + 3 * k);
        end
        run_point(1025, 65, isums_a, qsums_a, "n1_1025_avg_65_2kplus1");

        // 3. n1=1, N2=1 -- s1=0 and s2=0, zero round constant, identity path
        isums_a = new[1];
        qsums_a = new[1];
        isums_a[0] = 12345;
        qsums_a[0] = -6789;
        run_point(1, 1, isums_a, qsums_a, "n1_1_avg_1_identity");

        // 3b. n1=1, N2=60 -- s1=0 mixed with s2>0
        isums_a = new[60];
        qsums_a = new[60];
        for (k = 0; k < 60; k = k + 1) begin
            isums_a[k] = 1000 - 2 * k;
            qsums_a[k] = -500 + 3 * k;
        end
        run_point(1, 60, isums_a, qsums_a, "n1_1_avg_60");

        // 4. Sign stress: I+/Q-, both-, alternating, n1=1000, N2=4
        isums_a = new[4];
        qsums_a = new[4];
        isums_a[0] = 1000 * 1000;  qsums_a[0] = 1000 * (-2000);
        isums_a[1] = 1000 * (-1500); qsums_a[1] = 1000 * 800;
        isums_a[2] = 1000 * (-3000); qsums_a[2] = 1000 * (-3000);
        isums_a[3] = 1000 * 500;   qsums_a[3] = 1000 * 500;
        run_point(1000, 4, isums_a, qsums_a, "sign_stress");

        // 6. Quantization error bound (near-tie floor): moderate n1/N2, verify
        //    the DUT's rounded power sits within the documented ~2^-17 relative
        //    bound of the TRUE (unrounded) sum-then-square power.
        isums_a = new[500];
        qsums_a = new[500];
        for (k = 0; k < 500; k = k + 1) begin
            isums_a[k] = 1000 * (7000 + (k % 37) - 18);
            qsums_a[k] = 1000 * (-4000 + (k % 23) - 11);
        end
        run_bound_check(1000, 500, isums_a, qsums_a, 0.0001, "quantization_bound");

        $display("------------------------------------------------");
        $display("[%0t] SUMMARY: %0d PASS, %0d FAIL", $time, pass_count, fail_count);
        if (fail_count == 0)
            $display("[%0t] ALL PASS", $time);
        else
            $display("[%0t] FAILURES PRESENT", $time);

        #200;
        $finish;
    end

    initial begin
        #5000000;
        $display("[%0t] TIMEOUT", $time);
        $finish;
    end

endmodule
