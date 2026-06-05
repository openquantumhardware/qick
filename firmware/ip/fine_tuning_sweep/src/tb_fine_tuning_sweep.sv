`timescale 1ns / 1ps
//------------------------------------------------------------------------------
// tb_fine_tuning_sweep -- self-checking sim for the autonomous sweep FSM.
//
//   Models the tProc + DUT loop:
//     * OP0/OP4 load the sweep config (start/stop/step/nsamp/n_points/avg)
//     * OP1 starts the sweep
//     * poll OP2: on freq_valid -> "retune" the synthetic ADC to freq_word and
//       fire `AVG` triggers (one averaged point); on finish -> read freq_at_max
//   The synthetic ADC presents a triangular peak centred on PEAK_FREQ, so the
//   FSM's freq_at_max must land on the grid point nearest PEAK_FREQ.
//
//   c_clk and s_axis_aclk are tied together here (single 100 MHz clock); the
//   real BD ties s_axis_aclk = ro_clk and the synchronizer.v CDC handles it.
//------------------------------------------------------------------------------

module tb_fine_tuning_sweep();

    // ---- clock / reset ----
    reg clk;
    reg rst_n;
    always #5 clk = ~clk;        // 100 MHz

    // ---- QP2 / control ----
    reg        qtag_en_i;
    reg  [4:0] qtag_op_i;
    reg [31:0] qtag_dt1_i, qtag_dt2_i, qtag_dt3_i, qtag_dt4_i;
    wire       qtag_rdy_o;
    wire [31:0] qtag_dt1_o, qtag_dt2_o;
    wire       qtag_vld_o;

    reg        trigger;

    // ---- s_axis (synthetic ADC stream) ----
    reg  [31:0] s_axis_tdata;
    reg         s_axis_tvalid;

    // ==========================================
    // DUT
    // ==========================================
    fine_tuning_sweep #(.MAX_AVG(64)) uut (
        .clk           (clk),
        .rst_n         (rst_n),
        .qtag_en_i     (qtag_en_i),
        .qtag_op_i     (qtag_op_i),
        .qtag_dt1_i    (qtag_dt1_i),
        .qtag_dt2_i    (qtag_dt2_i),
        .qtag_dt3_i    (qtag_dt3_i),
        .qtag_dt4_i    (qtag_dt4_i),
        .qtag_rdy_o    (qtag_rdy_o),
        .qtag_dt1_o    (qtag_dt1_o),
        .qtag_dt2_o    (qtag_dt2_o),
        .qtag_vld_o    (qtag_vld_o),
        .trigger       (trigger),
        .s_axis_aclk   (clk),
        .s_axis_aresetn(rst_n),
        .s_axis_tvalid (s_axis_tvalid),
        .s_axis_tdata  (s_axis_tdata)
    );

    // ==========================================
    // sweep parameters (all in opaque "freq_word" units = Hz here)
    // ==========================================
    localparam [31:0] START_FREQ = 32'd6000000;    // 6 MHz
    localparam [31:0] STOP_FREQ  = 32'd30000000;   // 30 MHz (end clamp)
    localparam [31:0] STEP       = 32'd1000000;    // 1 MHz
    localparam [31:0] NPOINTS    = 32'd100;        // large -> stop clamp governs
    localparam [31:0] AVG        = 32'd3;          // 3 bursts averaged / point
    localparam [31:0] NSAMP      = 32'd8;          // samples integrated / burst

    localparam [31:0] PEAK_FREQ  = 32'd18000000;   // synthetic resonance
    localparam [31:0] PEAK_WIDTH = 32'd4000000;    // +/- slope half-width

    // ==========================================
    // synthetic ADC: triangular peak vs the "tuned" frequency
    // ==========================================
    reg [31:0] tuned_freq;       // what the "tProc" last retuned the ADC to
    reg [15:0] adc_amp;
    reg        toggle_sign;

    always @(*) begin : amp_model
        integer diff;
        diff = tuned_freq - PEAK_FREQ;
        if (diff < 0) diff = -diff;
        if (diff < PEAK_WIDTH)
            adc_amp = 16'd30000 - ((diff * 29000) / PEAK_WIDTH);
        else
            adc_amp = 16'd1000;  // noise floor
    end

    always @(posedge clk) begin
        if (!rst_n) toggle_sign <= 1'b0;
        else        toggle_sign <= ~toggle_sign;
    end

    wire signed [15:0] i_samp = toggle_sign ?  $signed(adc_amp) : -$signed(adc_amp);
    wire signed [15:0] q_samp = toggle_sign ? -$signed(adc_amp) :  $signed(adc_amp);
    always @(*) s_axis_tdata = {i_samp, q_samp};

    // ==========================================
    // QP2 bus helpers
    // ==========================================
    task qp2_send(input [4:0] op,
                  input [31:0] d1, input [31:0] d2,
                  input [31:0] d3, input [31:0] d4);
        begin
            @(posedge clk); #1;
            qtag_en_i  = 1'b1; qtag_op_i = op;
            qtag_dt1_i = d1; qtag_dt2_i = d2; qtag_dt3_i = d3; qtag_dt4_i = d4;
            @(posedge clk); #1;
            qtag_en_i = 1'b0;               // falling edge so the next op re-triggers
            @(posedge clk);                 // (acts like the mandatory inter-PB gap)
        end
    endtask

    task qp2_read_op2(output [31:0] freq, output reg fvalid, output reg fin);
        begin
            @(posedge clk); #1;
            qtag_en_i = 1'b1; qtag_op_i = 5'd2;
            @(posedge clk); #1;
            qtag_en_i = 1'b0;
            while (!qtag_vld_o) @(posedge clk);
            #1;
            freq   = qtag_dt1_o;
            fin    = qtag_dt2_o[0];
            fvalid = qtag_dt2_o[1];
            @(posedge clk);
        end
    endtask

    // fire one burst: nsamp valid samples are streaming continuously, so a
    // single trigger + a wait long enough to accumulate nsamp samples completes
    // one burst.
    task fire_burst;
        begin
            @(posedge clk); #1; trigger = 1'b1;
            @(posedge clk); #1; trigger = 1'b0;
            repeat (NSAMP + 12) @(posedge clk);   // let the burst integrate + emit
        end
    endtask

    // ==========================================
    // main test sequence
    // ==========================================
    reg [31:0] rd_freq;
    reg        rd_fvalid, rd_fin;
    integer    step_i, a;
    integer    expected_peak;

    initial begin
        clk = 0; rst_n = 0;
        qtag_en_i = 0; qtag_op_i = 0;
        qtag_dt1_i = 0; qtag_dt2_i = 0; qtag_dt3_i = 0; qtag_dt4_i = 0;
        trigger = 0; tuned_freq = 0;
        s_axis_tvalid = 1'b1;

        #100; rst_n = 1; #100;
        $display("[%0t] RESET DONE", $time);

        // ---- config ----
        qp2_send(5'd0, START_FREQ, STOP_FREQ, STEP, NSAMP);     // OP0
        qp2_send(5'd4, NPOINTS, AVG, 32'd0, 32'd0);             // OP4
        qp2_send(5'd3, 0, 0, 0, 0);                             // OP3 reset_max
        $display("[%0t] CONFIG: start=%0d stop=%0d step=%0d N=%0d avg=%0d nsamp=%0d",
                 $time, START_FREQ, STOP_FREQ, STEP, NPOINTS, AVG, NSAMP);

        // ---- start ----
        qp2_send(5'd1, 0, 0, 0, 0);                             // OP1 start
        $display("[%0t] SWEEP STARTED (target peak @ %0d)", $time, PEAK_FREQ);

        // ---- handshake loop ----
        step_i = 0;
        rd_fin = 1'b0;
        while (!rd_fin) begin
            qp2_read_op2(rd_freq, rd_fvalid, rd_fin);
            if (rd_fin) begin
                $display("------------------------------------------------");
                $display("[%0t] FINISH. freq_at_max = %0d Hz", $time, rd_freq);
            end else if (rd_fvalid) begin
                step_i = step_i + 1;
                tuned_freq = rd_freq;             // "retune the generator"
                #1;                               // let amp_model settle
                $display("[%0t] pt %0d | freq=%0d | adc_amp=%0d",
                         $time, step_i, rd_freq, adc_amp);
                for (a = 0; a < AVG; a = a + 1) fire_burst;  // averager_value bursts
            end
            // else: IP hasn't advanced yet -> keep polling
        end

        // ---- check ----
        expected_peak = PEAK_FREQ;   // grid hits 18 MHz exactly (6 MHz + 12*1 MHz)
        if (rd_freq == expected_peak)
            $display("[%0t] PASS: freq_at_max (%0d) == expected (%0d)",
                     $time, rd_freq, expected_peak);
        else
            $display("[%0t] FAIL: freq_at_max (%0d) != expected (%0d)",
                     $time, rd_freq, expected_peak);

        #500;
        $display("[%0t] SIM COMPLETE (%0d points swept)", $time, step_i);
        $finish;
    end

    // global watchdog so a wiring bug can't hang the sim forever
    initial begin
        #5000000;
        $display("[%0t] TIMEOUT -- sweep never finished", $time);
        $finish;
    end

endmodule
