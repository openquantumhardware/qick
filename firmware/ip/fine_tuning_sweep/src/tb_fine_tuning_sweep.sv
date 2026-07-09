`timescale 1ns / 1ps
//------------------------------------------------------------------------------
// tb_fine_tuning_sweep -- self-checking sim for the single-clock sweep FSM.
//
//   Models the tProc + DUT loop against the avg_buffer-m2 front end, with NO
//   read opcode: the IP presents freq_word on qtag_dt1_o + raises qtag_vld_o /
//   qtag_rdy_o on finish, and the tProc reads the result directly.
//     * OP0 loads the sweep config (start/step/n_points/avg)
//     * OP1 starts the sweep; the tProc then waits for qtag_rdy_o to drop (WSTART)
//     * per point: while armed, "retune" the synthetic readout to cur_freq and
//       present AVG accumulated m2 words (one 64-bit {Q,I} per shot) as tready/
//       tvalid beats; the accumulator disarms when it has its AVG shots
//     * finish: qtag_rdy_o rises (WDONE) -> read freq_at_max from qtag_dt1_o
//   The synthetic readout is a triangular peak centred on PEAK_FREQ, so
//   freq_at_max must land on the grid point nearest PEAK_FREQ. Single clock: the
//   real BD brings s_axis into the core clock via axis_clock_converter.
//------------------------------------------------------------------------------

module tb_fine_tuning_sweep();

    reg clk;
    reg rst_n;
    always #5 clk = ~clk;

    reg        qtag_en_i;
    reg  [4:0] qtag_op_i;
    reg [31:0] qtag_dt1_i, qtag_dt2_i, qtag_dt3_i, qtag_dt4_i;
    wire       qtag_rdy_o;
    wire [31:0] qtag_dt1_o, qtag_dt2_o;
    wire       qtag_vld_o;

    reg [63:0] s_axis_tdata;
    reg        s_axis_tvalid;
    wire       s_axis_tready;

    fine_tuning_sweep #(.ACC_WIDTH(64)) uut (
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
        .s_axis_tvalid (s_axis_tvalid),
        .s_axis_tready (s_axis_tready),
        .s_axis_tdata  (s_axis_tdata)
    );

    localparam [31:0] START_FREQ = 32'd6000000;
    localparam [31:0] STEP       = 32'd1000000;
    localparam [31:0] NPOINTS    = 32'd100;
    localparam [31:0] AVG        = 32'd3;

    localparam [31:0] PEAK_FREQ  = 32'd18000000;
    localparam [31:0] PEAK_WIDTH = 32'd4000000;

    reg [31:0] tuned_freq;
    reg [15:0] adc_amp;

    always @(*) begin : amp_model
        integer diff;
        diff = tuned_freq - PEAK_FREQ;
        if (diff < 0) diff = -diff;
        if (diff < PEAK_WIDTH)
            adc_amp = 16'd30000 - ((diff * 29000) / PEAK_WIDTH);
        else
            adc_amp = 16'd1000;
    end

    task qp2_send(input [4:0] op,
                  input [31:0] d1, input [31:0] d2,
                  input [31:0] d3, input [31:0] d4);
        begin
            @(posedge clk); #1;
            qtag_en_i  = 1'b1; qtag_op_i = op;
            qtag_dt1_i = d1; qtag_dt2_i = d2; qtag_dt3_i = d3; qtag_dt4_i = d4;
            @(posedge clk); #1;
            qtag_en_i = 1'b0;
            @(posedge clk);
        end
    endtask

    // present one avg_buffer m2 word: {Q,I} accumulated for this shot, as a
    // single tvalid/tready beat. The magnitude tracks adc_amp so bigger
    // amplitude -> bigger (sum I)^2+(sum Q)^2.
    task fire_shot;
        begin
            @(posedge clk); #1;
            s_axis_tvalid = 1'b1;
            s_axis_tdata  = {{16'd0, adc_amp}, {16'd0, adc_amp}};
            @(posedge clk); #1;
            s_axis_tvalid = 1'b0;
            s_axis_tdata  = 64'd0;
            @(posedge clk);
        end
    endtask

    reg [31:0] rd_freq;
    integer    step_i, a;
    integer    expected_peak;

    initial begin
        clk = 0; rst_n = 0;
        qtag_en_i = 0; qtag_op_i = 0;
        qtag_dt1_i = 0; qtag_dt2_i = 0; qtag_dt3_i = 0; qtag_dt4_i = 0;
        tuned_freq = 0;
        s_axis_tvalid = 1'b0; s_axis_tdata = 64'd0;

        #100; rst_n = 1; #100;
        $display("[%0t] RESET DONE", $time);

        qp2_send(5'd0, START_FREQ, STEP, NPOINTS, AVG);
        $display("[%0t] CONFIG: start=%0d step=%0d N=%0d avg=%0d",
                 $time, START_FREQ, STEP, NPOINTS, AVG);

        qp2_send(5'd1, 0, 0, 0, 0);
        while (qtag_rdy_o) @(posedge clk);
        $display("[%0t] SWEEP STARTED (target peak @ %0d)", $time, PEAK_FREQ);

        step_i = 0;
        while (!qtag_rdy_o) begin
            @(posedge clk); #1;
            if (uut.u_amplitude_calculator.armed) begin
                tuned_freq = uut.u_peak_finder_v2.cur_freq;
                #1;
                step_i = step_i + 1;
                $display("[%0t] pt %0d | freq=%0d | adc_amp=%0d",
                         $time, step_i, tuned_freq, adc_amp);
                for (a = 0; a < AVG; a = a + 1) fire_shot;
                while (uut.u_amplitude_calculator.armed) @(posedge clk);
            end
        end

        rd_freq = qtag_dt1_o;
        $display("------------------------------------------------");
        $display("[%0t] FINISH. freq_at_max = %0d Hz (vld=%0b)",
                 $time, rd_freq, qtag_vld_o);

        expected_peak = PEAK_FREQ;
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

    initial begin
        #5000000;
        $display("[%0t] TIMEOUT -- sweep never finished", $time);
        $finish;
    end

endmodule
