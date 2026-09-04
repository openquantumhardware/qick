`timescale 1ns / 1ps

module tb_fir_compare;

    localparam int CLK_PERIOD = 10;
    localparam int LATENCY = 16;
    localparam int PATTERN_COUNT = 4;
    localparam int SAMPLES_PER_PATTERN = 32;
    localparam int SAMPLES_PER_VECTOR = 8;
    localparam int TOTAL_SAMPLES = PATTERN_COUNT * SAMPLES_PER_PATTERN;
    localparam int WATCHDOG_CYCLES = 2000;
    localparam int ABS_TOLERANCE = 2;
    localparam real REL_TOLERANCE = 0.01;

    logic clk;
    logic aresetn;
    logic s_axis_data_tvalid;
    logic s_axis_data_tlast;
    logic [31:0] s_axis_data_tdata;
    logic s_axis_config_tvalid;
    logic s_axis_config_tlast;
    logic [7:0] s_axis_config_tdata;

    wire ip_data_ready;
    wire ip_config_ready;
    wire ip_data_valid;
    wire ip_data_last;
    wire [31:0] ip_data;
    wire ip_event_data_last_missing;
    wire ip_event_data_last_unexpected;
    wire ip_event_config_last_missing;
    wire ip_event_config_last_unexpected;

    wire model_data_ready;
    wire model_config_ready;
    wire model_data_valid;
    wire model_data_last;
    wire [31:0] model_data;
    wire model_event_data_last_missing;
    wire model_event_data_last_unexpected;
    wire model_event_config_last_missing;
    wire model_event_config_last_unexpected;

    int cycle_count;
    int input_count;
    int output_count;
    int mismatch_count;
    int valid_mismatch_count;
    int last_mismatch_count;
    int data_check_count;
    int total_abs_error;
    int max_abs_error;
    int watchdog_count;

    function automatic bit within_tolerance(
        input logic signed [15:0] ip_value,
        input logic signed [15:0] model_value
    );
        int abs_error;
        int max_value;
        begin
            abs_error = (ip_value >= model_value) ?
                        (ip_value - model_value) : (model_value - ip_value);
            max_value = (ip_value >= 0 ? ip_value : -ip_value);
            if ((model_value >= 0 ? model_value : -model_value) > max_value)
                max_value = (model_value >= 0 ? model_value : -model_value);
            within_tolerance = (abs_error <= ABS_TOLERANCE) ||
                               ((max_value > 0) &&
                                (real'(abs_error) / real'(max_value) <= REL_TOLERANCE));
        end
    endfunction

    initial begin
        $dumpfile("tb_fir_compare.vcd");
        $dumpvars(0, tb_fir_compare);
    end

    always #(CLK_PERIOD / 2) clk = ~clk;

    always @(posedge clk) begin
        cycle_count <= cycle_count + 1;
        if (cycle_count < 80 && (s_axis_config_tvalid ||
                     (s_axis_data_tvalid && model_dut.u_model.data_channel == 0)))
            $display("FIR TRACE cycle=%0d cfg_valid=%b cfg_data=%0d data_valid=%b model_channel=%0d active_phase=%0d cfg_count=%0d",
                     cycle_count, s_axis_config_tvalid, s_axis_config_tdata,
                     s_axis_data_tvalid, model_dut.u_model.data_channel,
                 model_dut.u_model.config_phase[0], model_dut.u_model.config_index);
        if (ip_event_config_last_missing || ip_event_config_last_unexpected ||
            model_event_config_last_missing || model_event_config_last_unexpected)
            $display("CONFIG EVENT cycle=%0d ip_missing=%b ip_unexpected=%b model_missing=%b model_unexpected=%b",
                     cycle_count, ip_event_config_last_missing, ip_event_config_last_unexpected,
                     model_event_config_last_missing, model_event_config_last_unexpected);
        if (ip_data_valid || model_data_valid) begin
            output_count = output_count + 1;

            if (ip_data_valid !== model_data_valid) begin
                valid_mismatch_count = valid_mismatch_count + 1;
                $display("VALID MISMATCH cycle=%0d: ip=%b model=%b",
                         cycle_count, ip_data_valid, model_data_valid);
            end

            if (ip_data_last !== model_data_last) begin
                last_mismatch_count = last_mismatch_count + 1;
                $display("TLAST MISMATCH cycle=%0d: ip=%b model=%b",
                         cycle_count, ip_data_last, model_data_last);
            end

            if (ip_data_valid && model_data_valid) begin
                data_check_count = data_check_count + 2;
                total_abs_error = total_abs_error +
                    (($signed(ip_data[15:0]) >= $signed(model_data[15:0])) ?
                     ($signed(ip_data[15:0]) - $signed(model_data[15:0])) :
                     ($signed(model_data[15:0]) - $signed(ip_data[15:0])));
                total_abs_error = total_abs_error +
                    (($signed(ip_data[31:16]) >= $signed(model_data[31:16])) ?
                     ($signed(ip_data[31:16]) - $signed(model_data[31:16])) :
                     ($signed(model_data[31:16]) - $signed(ip_data[31:16])));
                if (output_count < 40)
                    $display("OUTPUT index=%0d cycle=%0d ip=(%0d,%0d) model=(%0d,%0d) ip_last=%b model_last=%b",
                             output_count, cycle_count,
                             $signed(ip_data[15:0]), $signed(ip_data[31:16]),
                             $signed(model_data[15:0]), $signed(model_data[31:16]),
                             ip_data_last, model_data_last);
                if (!within_tolerance($signed(ip_data[15:0]), $signed(model_data[15:0])) ||
                    !within_tolerance($signed(ip_data[31:16]), $signed(model_data[31:16]))) begin
                    mismatch_count = mismatch_count + 1;
                    $display("DATA MISMATCH cycle=%0d output=%0d: ip=(%0d,%0d) model=(%0d,%0d)",
                             cycle_count, output_count,
                             $signed(ip_data[15:0]), $signed(ip_data[31:16]),
                             $signed(model_data[15:0]), $signed(model_data[31:16]));
                end
            end
        end

    end

    fir_0 ip_dut (
        .aclk                           (clk),
        .s_axis_data_tvalid             (s_axis_data_tvalid),
        .s_axis_data_tready             (ip_data_ready),
        .s_axis_data_tlast              (s_axis_data_tlast),
        .s_axis_data_tdata              (s_axis_data_tdata),
        .s_axis_config_tvalid           (s_axis_config_tvalid),
        .s_axis_config_tready           (ip_config_ready),
        .s_axis_config_tlast            (s_axis_config_tlast),
        .s_axis_config_tdata            (s_axis_config_tdata),
        .m_axis_data_tvalid             (ip_data_valid),
        .m_axis_data_tlast              (ip_data_last),
        .m_axis_data_tdata              (ip_data),
        .event_s_data_tlast_missing     (ip_event_data_last_missing),
        .event_s_data_tlast_unexpected  (ip_event_data_last_unexpected),
        .event_s_config_tlast_missing   (ip_event_config_last_missing),
        .event_s_config_tlast_unexpected(ip_event_config_last_unexpected)
    );

    fir_0_sv model_dut (
        .aclk                           (clk),
        .aresetn                        (aresetn),
        .s_axis_data_tvalid             (s_axis_data_tvalid),
        .s_axis_data_tready             (model_data_ready),
        .s_axis_data_tlast              (s_axis_data_tlast),
        .s_axis_data_tdata              (s_axis_data_tdata),
        .s_axis_config_tvalid           (s_axis_config_tvalid),
        .s_axis_config_tready           (model_config_ready),
        .s_axis_config_tlast            (s_axis_config_tlast),
        .s_axis_config_tdata            (s_axis_config_tdata),
        .m_axis_data_tvalid             (model_data_valid),
        .m_axis_data_tlast              (model_data_last),
        .m_axis_data_tdata              (model_data),
        .event_s_data_tlast_missing     (model_event_data_last_missing),
        .event_s_data_tlast_unexpected  (model_event_data_last_unexpected),
        .event_s_config_tlast_missing   (model_event_config_last_missing),
        .event_s_config_tlast_unexpected(model_event_config_last_unexpected)
    );

    task automatic configure_phase(input int phase);
        begin
            for (int channel = 0; channel < SAMPLES_PER_VECTOR; channel = channel + 1) begin
                @(negedge clk);
                s_axis_data_tvalid = 1'b0;
                s_axis_data_tlast = 1'b0;
                s_axis_config_tvalid = 1'b1;
                s_axis_config_tlast = (channel == SAMPLES_PER_VECTOR - 1);
                s_axis_config_tdata = phase[7:0];
            end
            @(negedge clk);
            s_axis_config_tvalid = 1'b0;
            s_axis_config_tlast = 1'b0;
            s_axis_config_tdata = '0;
        end
    endtask

    task automatic drive_sample(input int pattern_id, input int sample_index);
        logic signed [15:0] sample_i;
        logic signed [15:0] sample_q;
        int pattern_sample;
        begin
            pattern_sample = sample_index % SAMPLES_PER_PATTERN;
            case (pattern_id)
                0: begin
                    sample_i = (pattern_sample == 0) ? 16'sd1024 : 16'sd0;
                    sample_q = 16'sd0;
                end
                1: begin
                    sample_i = 16'sd256;
                    sample_q = -16'sd128;
                end
                2: begin
                    sample_i = -16'sd512 + pattern_sample * 16'sd17;
                    sample_q = 16'sd300 - pattern_sample * 16'sd11;
                end
                default: begin
                    sample_i = ((pattern_sample % 2) == 0) ? 16'sd700 : -16'sd700;
                    sample_q = ((pattern_sample % 2) == 0) ? -16'sd300 : 16'sd300;
                end
            endcase
            s_axis_data_tdata = {sample_q, sample_i};
            s_axis_data_tlast = ((sample_index % SAMPLES_PER_VECTOR) == (SAMPLES_PER_VECTOR - 1));
        end
    endtask

    initial begin
        clk = 1'b0;
        aresetn = 1'b0;
        cycle_count = 0;
        input_count = 0;
        output_count = 0;
        mismatch_count = 0;
        valid_mismatch_count = 0;
        last_mismatch_count = 0;
        data_check_count = 0;
        total_abs_error = 0;
        max_abs_error = 0;
        watchdog_count = 0;
        s_axis_data_tvalid = 1'b0;
        s_axis_data_tlast = 1'b0;
        s_axis_data_tdata = '0;
        s_axis_config_tvalid = 1'b0;
        s_axis_config_tlast = 1'b0;
        s_axis_config_tdata = '0;

        repeat (2) @(negedge clk);
        aresetn = 1'b1;
        $display("tb_fir_compare: starting %0d samples", TOTAL_SAMPLES);

        for (int sample = 0; sample < TOTAL_SAMPLES; sample = sample + 1) begin
            if ((sample % SAMPLES_PER_VECTOR) == 0)
                configure_phase((sample / SAMPLES_PER_VECTOR) % 4);
            @(negedge clk);
            s_axis_data_tvalid = 1'b1;
            drive_sample(sample / SAMPLES_PER_PATTERN, sample);
            input_count = input_count + 1;
        end

        @(negedge clk);
        s_axis_data_tvalid = 1'b0;
        s_axis_data_tlast = 1'b0;
        s_axis_data_tdata = '0;

        $display("tb_fir_compare: input complete, waiting for %0d-cycle pipeline drain", LATENCY);
        repeat (LATENCY + 80) @(posedge clk);

        $display("RESULT: %s", (mismatch_count == 0 && valid_mismatch_count == 0 && last_mismatch_count == 0) ? "PASS" : "FAIL");
        $display("inputs=%0d outputs=%0d data_checks=%0d data_mismatches=%0d valid_mismatches=%0d tlast_mismatches=%0d",
             input_count, output_count, data_check_count, mismatch_count, valid_mismatch_count, last_mismatch_count);
        $display("tolerance abs=%0d rel=%.3f total_abs_error=%0d", ABS_TOLERANCE, REL_TOLERANCE, total_abs_error);
        if (mismatch_count != 0 || valid_mismatch_count != 0 || last_mismatch_count != 0)
            $fatal(1, "FIR IP/model comparison failed");
        $finish;
    end

    always @(posedge clk) begin
        watchdog_count = watchdog_count + 1;
        if (watchdog_count > WATCHDOG_CYCLES)
            $fatal(1, "FIR comparison watchdog expired");
    end

endmodule
