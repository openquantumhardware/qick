`timescale 1ns / 1ps
//------------------------------------------------------------------------------
// tb_fine_tuning_sweep_cdc -- DUAL-CLOCK CDC verification.
//
//   c_clk  ~245.76 MHz : QP2 opcode FSM + peak_finder      (wrapper .clk)
//   ro_clk ~552.96 MHz : amplitude_calculator + s_axis     (wrapper .s_axis_aclk)
//
//   The two clocks are asynchronous (ratio ~2.25), so this exercises every CDC
//   the single-clock tb could not:
//       synchronizer_n          trigger                  (fpga -> ro, 1-bit)
//       synchronizer            nsamp / averager_value   (fpga -> ro, quasi-static)
//       synchronizer_handshake  accumulated |IQ|^2 + vld (ro -> fpga, req/ack)
//   Separate resets per domain. Self-checks the argmax lands on the synthetic
//   peak -- a wrong/missing CDC transfer shows up as a wrong freq_at_max or a
//   hang (caught by the global timeout).
//------------------------------------------------------------------------------
module tb_fine_tuning_sweep_cdc();

    // ---- two asynchronous clocks ----
    reg c_clk  = 1'b0;
    reg ro_clk = 1'b0;
    always #2.035 c_clk  = ~c_clk;    // ~245.76 MHz  (period 4.070 ns)
    always #0.904 ro_clk = ~ro_clk;   // ~552.96 MHz  (period 1.808 ns)

    reg c_rst_n, ro_rst_n;

    // ---- QP2 / trigger (c_clk domain) ----
    reg        qtag_en_i;
    reg  [4:0] qtag_op_i;
    reg [31:0] qtag_dt1_i, qtag_dt2_i, qtag_dt3_i, qtag_dt4_i;
    wire       qtag_rdy_o;
    wire [31:0] qtag_dt1_o, qtag_dt2_o;
    wire       qtag_vld_o;
    reg        trigger;

    // ---- s_axis stream (ro_clk domain) ----
    reg [31:0] s_axis_tdata;
    reg        s_axis_tvalid;

    fine_tuning_sweep #(.MAX_AVG(64)) uut (
        .clk           (c_clk),
        .rst_n         (c_rst_n),
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
        .s_axis_aclk   (ro_clk),
        .s_axis_aresetn(ro_rst_n),
        .s_axis_tvalid (s_axis_tvalid),
        .s_axis_tdata  (s_axis_tdata)
    );

    // ---- sweep config (Hz used as opaque freq_word) ----
    localparam [31:0] START_FREQ = 32'd6000000;
    localparam [31:0] STOP_FREQ  = 32'd30000000;
    localparam [31:0] STEP       = 32'd1000000;
    localparam [31:0] NPOINTS    = 32'd100;        // large -> stop clamp governs
    localparam [31:0] AVG        = 32'd3;          // bursts averaged per point
    localparam [31:0] NSAMP      = 32'd8;          // samples integrated per burst
    localparam [31:0] PEAK_FREQ  = 32'd18000000;
    localparam [31:0] PEAK_WIDTH = 32'd4000000;

    // ---- synthetic IQ on ro_clk; amplitude from the host-tuned frequency ----
    //  tuned_freq is written by the "host" on c_clk and read here on ro_clk; it
    //  changes only once per point, so it is a benign tb-side crossing.
    reg [31:0] tuned_freq;
    reg [15:0] adc_amp;
    always @(*) begin : amp_model
        integer d;
        d = tuned_freq - PEAK_FREQ;
        if (d < 0) d = -d;
        if (d < PEAK_WIDTH) adc_amp = 16'd30000 - ((d * 29000) / PEAK_WIDTH);
        else                adc_amp = 16'd1000;
    end

    always @(posedge ro_clk) begin
        if (!ro_rst_n) s_axis_tdata <= 32'd0;
        else           s_axis_tdata <= {adc_amp, adc_amp};   // i = q = amp
    end

    // ==========================================================
    //  QP2 bus tasks (c_clk)
    // ==========================================================
    task qp2_send(input [4:0] op,
                  input [31:0] d1, input [31:0] d2,
                  input [31:0] d3, input [31:0] d4);
        begin
            @(posedge c_clk); #0.1;
            qtag_en_i  = 1'b1; qtag_op_i = op;
            qtag_dt1_i = d1; qtag_dt2_i = d2; qtag_dt3_i = d3; qtag_dt4_i = d4;
            @(posedge c_clk); #0.1;
            qtag_en_i = 1'b0;          // falling edge -> next op re-triggers en_rise
            @(posedge c_clk);
        end
    endtask

    task qp2_read_op2(output [31:0] freq, output reg fvalid, output reg fin);
        begin
            @(posedge c_clk); #0.1;
            qtag_en_i = 1'b1; qtag_op_i = 5'd2;
            @(posedge c_clk); #0.1;
            qtag_en_i = 1'b0;
            while (!qtag_vld_o) @(posedge c_clk);
            #0.1;
            freq   = qtag_dt1_o;
            fin    = qtag_dt2_o[0];
            fvalid = qtag_dt2_o[1];
            @(posedge c_clk);
        end
    endtask

    // Fire one burst: a WIDE (~20 ns) c_clk trigger -- modelling the real
    // trig_0_o level, which the avg_buffer-style level sync requires. (A
    // 1-cycle pulse can be missed crossing into the faster ro clock; the real
    // trig_0_o is a ~20 ns level, so the s_axis edge-detect still gives exactly
    // one burst.) Then wait long enough for the trigger to cross to ro,
    // integrate NSAMP samples, complete, and (on the AVG-th burst) cross the
    // averaged result back to c.
    task fire_burst;
        begin
            @(posedge c_clk); #0.1; trigger = 1'b1;
            repeat (5) @(posedge c_clk); #0.1; trigger = 1'b0;  // ~20 ns level
            repeat (40) @(posedge c_clk);   // >> NSAMP ro-cycles + CDC latency
        end
    endtask

    // ==========================================================
    //  main sequence
    // ==========================================================
    reg [31:0] rd_freq;
    reg        rd_fvalid, rd_fin;
    integer    step_i, a;

    initial begin
        c_rst_n = 0; ro_rst_n = 0;
        qtag_en_i = 0; qtag_op_i = 0;
        qtag_dt1_i = 0; qtag_dt2_i = 0; qtag_dt3_i = 0; qtag_dt4_i = 0;
        trigger = 0; tuned_freq = 0; s_axis_tvalid = 0;

        #100;
        c_rst_n = 1; ro_rst_n = 1; s_axis_tvalid = 1;
        #100;
        $display("[%0t] RESET DONE  (c_clk 245.76 MHz, ro_clk 552.96 MHz, async)", $time);

        qp2_send(5'd0, START_FREQ, STOP_FREQ, STEP, NSAMP);   // OP0
        qp2_send(5'd4, NPOINTS, AVG, 32'd0, 32'd0);           // OP4
        qp2_send(5'd3, 0, 0, 0, 0);                           // OP3 reset_max
        qp2_send(5'd1, 0, 0, 0, 0);                           // OP1 start
        $display("[%0t] SWEEP STARTED (target peak @ %0d)", $time, PEAK_FREQ);

        step_i = 0; rd_fin = 1'b0;
        while (!rd_fin) begin
            qp2_read_op2(rd_freq, rd_fvalid, rd_fin);
            if (rd_fin) begin
                $display("[%0t] FINISH. freq_at_max = %0d", $time, rd_freq);
            end else if (rd_fvalid) begin
                step_i = step_i + 1;
                tuned_freq = rd_freq; #0.2;
                $display("[%0t] pt %0d | freq=%0d | amp=%0d",
                         $time, step_i, rd_freq, adc_amp);
                for (a = 0; a < AVG; a = a + 1) fire_burst;
            end
            // else: IP not advanced yet -> poll again
        end

        if (rd_freq == PEAK_FREQ)
            $display("[%0t] PASS: freq_at_max (%0d) == expected (%0d)",
                     $time, rd_freq, PEAK_FREQ);
        else
            $display("[%0t] FAIL: freq_at_max (%0d) != expected (%0d)",
                     $time, rd_freq, PEAK_FREQ);

        #500;
        $display("[%0t] SIM COMPLETE (%0d points swept)", $time, step_i);
        $finish;
    end

    // global watchdog -- a dropped CDC transfer would hang the handshake
    initial begin
        #20000000;
        $display("[%0t] TIMEOUT -- sweep never finished (CDC transfer lost?)", $time);
        $finish;
    end

endmodule
