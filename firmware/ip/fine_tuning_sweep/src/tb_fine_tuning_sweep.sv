`timescale 1ns / 1ps
//------------------------------------------------------------------------------
// tb_fine_tuning_sweep -- self-checking sim for the single-clock sweep FSM.
//
//   Models the tProc + DUT loop against the new avg_buffer-m2 front end:
//     * OP0/OP4 load the sweep config (start/step/n_points/avg)
//     * OP1 starts the sweep
//     * poll OP2: on freq_valid -> "retune" the synthetic readout to freq_word
//       and present AVG accumulated m2 words (one 64-bit {Q,I} per shot); on
//       finish -> read freq_at_max
//   The synthetic readout presents a triangular peak centred on PEAK_FREQ, so
//   freq_at_max must land on the grid point nearest PEAK_FREQ. Single clock: the
//   real BD ties s_axis_aclk to the core clock via axis_clock_converter.
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

    reg        trigger;

    reg [63:0] s_axis_tdata;
    reg        s_axis_tvalid;

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
        .trigger       (trigger),
        .s_axis_aclk   (clk),
        .s_axis_aresetn(rst_n),
        .s_axis_tvalid (s_axis_tvalid),
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

    // present one avg_buffer m2 word: {Q,I} accumulated for this shot. The
    // magnitude tracks adc_amp so bigger amplitude -> bigger (sum I)^2+(sum Q)^2.
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
    reg        rd_fvalid, rd_fin;
    integer    step_i, a;
    integer    expected_peak;

    initial begin
        clk = 0; rst_n = 0;
        qtag_en_i = 0; qtag_op_i = 0;
        qtag_dt1_i = 0; qtag_dt2_i = 0; qtag_dt3_i = 0; qtag_dt4_i = 0;
        trigger = 0; tuned_freq = 0;
        s_axis_tvalid = 1'b0; s_axis_tdata = 64'd0;

        #100; rst_n = 1; #100;
        $display("[%0t] RESET DONE", $time);

        qp2_send(5'd0, START_FREQ, 32'd0, STEP, 32'd0);
        qp2_send(5'd4, NPOINTS, AVG, 32'd0, 32'd0);
        qp2_send(5'd3, 0, 0, 0, 0);
        $display("[%0t] CONFIG: start=%0d step=%0d N=%0d avg=%0d",
                 $time, START_FREQ, STEP, NPOINTS, AVG);

        qp2_send(5'd1, 0, 0, 0, 0);
        $display("[%0t] SWEEP STARTED (target peak @ %0d)", $time, PEAK_FREQ);

        step_i = 0;
        rd_fin = 1'b0;
        while (!rd_fin) begin
            qp2_read_op2(rd_freq, rd_fvalid, rd_fin);
            if (rd_fin) begin
                $display("------------------------------------------------");
                $display("[%0t] FINISH. freq_at_max = %0d Hz", $time, rd_freq);
            end else if (rd_fvalid) begin
                step_i = step_i + 1;
                tuned_freq = rd_freq;
                #1;
                $display("[%0t] pt %0d | freq=%0d | adc_amp=%0d",
                         $time, step_i, rd_freq, adc_amp);
                for (a = 0; a < AVG; a = a + 1) fire_shot;
            end
        end

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
