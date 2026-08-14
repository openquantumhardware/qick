`timescale 1ns / 1ps

module tb_firs_compare;

    localparam int CLK_PERIOD = 10;
    // Must match production instantiation (axis_pfb_readout_v3.v: N=64, L=4)
    // so that pfb_ctrl's channel count (N/(2*L)=8) matches the Number_Channels=8
    // the generated fir_0 IP was actually built with.
    localparam int N = 64;
    localparam int L = 4;
    localparam int INPUT_W = L * 32;
    localparam int OUTPUT_W = 2 * L * 32;
    localparam int OUTPUT_WORDS = 2 * L;
    localparam int DISTINCT_PATTERNS = 4;
    localparam int PATTERN_COUNT = 64;
    localparam int SAMPLES_PER_PATTERN = 32;
    localparam int TOTAL_SAMPLES = PATTERN_COUNT * SAMPLES_PER_PATTERN;
    localparam int SAMPLES_PER_FRAME = N / (2 * L);
    localparam int DRAIN_CYCLES = 120;
    localparam int WATCHDOG_CYCLES = TOTAL_SAMPLES + DRAIN_CYCLES + 500;
    localparam int ABS_TOLERANCE = 2;
    localparam real REL_TOLERANCE = 0.01;

    logic clk;
    logic aresetn;
    logic s_axis_tvalid;
    logic [INPUT_W-1:0] s_axis_tdata;

    wire ip_tvalid;
    wire ip_tlast;
    wire [OUTPUT_W-1:0] ip_tdata;
    wire emu_tvalid;
    wire emu_tlast;
    wire [OUTPUT_W-1:0] emu_tdata;

    int cycle_count;
    int input_count;
    int output_count;
    int data_check_count;
    int mismatch_count;
    int valid_mismatch_count;
    int last_mismatch_count;
    int total_abs_error;
    int watchdog_count;

    function automatic bit within_tolerance(
        input logic signed [15:0] ip_value,
        input logic signed [15:0] emu_value
    );
        int abs_error;
        int max_value;
        begin
            abs_error = (ip_value >= emu_value) ?
                        (ip_value - emu_value) : (emu_value - ip_value);
            max_value = (ip_value >= 0) ? ip_value : -ip_value;
            if (((emu_value >= 0) ? emu_value : -emu_value) > max_value)
                max_value = (emu_value >= 0) ? emu_value : -emu_value;
            within_tolerance = (abs_error <= ABS_TOLERANCE) ||
                               ((max_value > 0) &&
                                (real'(abs_error) / real'(max_value) <= REL_TOLERANCE));
        end
    endfunction

    initial begin
        $dumpfile("tb_firs_compare.vcd");
        $dumpvars(0, tb_firs_compare);
    end

    always #(CLK_PERIOD / 2) clk = ~clk;

    firs #(
        .N(N),
        .L(L),
        .EMULATOR(0)
    ) ip_dut (
        .aresetn       (aresetn),
        .aclk          (clk),
        .s_axis_tvalid (s_axis_tvalid),
        .s_axis_tdata  (s_axis_tdata),
        .m_axis_tvalid (ip_tvalid),
        .m_axis_tlast  (ip_tlast),
        .m_axis_tdata  (ip_tdata)
    );

    firs #(
        .N(N),
        .L(L),
        .EMULATOR(1)
    ) emu_dut (
        .aresetn       (aresetn),
        .aclk          (clk),
        .s_axis_tvalid (s_axis_tvalid),
        .s_axis_tdata  (s_axis_tdata),
        .m_axis_tvalid (emu_tvalid),
        .m_axis_tlast  (emu_tlast),
        .m_axis_tdata  (emu_tdata)
    );

    task automatic drive_sample(input int pattern_id, input int sample_index);
        logic signed [15:0] sample_i;
        logic signed [15:0] sample_q;
        int pattern_sample;
        begin
            pattern_sample = sample_index % SAMPLES_PER_PATTERN;
            s_axis_tdata = '0;
            for (int lane = 0; lane < L; lane = lane + 1) begin
                case (pattern_id % DISTINCT_PATTERNS)
                    0: begin
                        sample_i = (pattern_sample == 0) ? (16'sd1024 + lane * 16'sd17) : 16'sd0;
                        sample_q = 16'sd0;
                    end
                    1: begin
                        sample_i = 16'sd256 + lane * 16'sd23;
                        sample_q = -16'sd128 + lane * 16'sd11;
                    end
                    2: begin
                        sample_i = -16'sd512 + pattern_sample * 16'sd17 + lane * 16'sd7;
                        sample_q = 16'sd300 - pattern_sample * 16'sd11 - lane * 16'sd5;
                    end
                    default: begin
                        sample_i = ((pattern_sample % 2) == 0) ?
                                   (16'sd700 + lane * 16'sd13) :
                                   -(16'sd700 + lane * 16'sd13);
                        sample_q = ((pattern_sample % 2) == 0) ?
                                   -(16'sd300 + lane * 16'sd9) :
                                   (16'sd300 + lane * 16'sd9);
                    end
                endcase
                s_axis_tdata[lane*32 +: 32] = {sample_q, sample_i};
            end
        end
    endtask

    always @(posedge clk) begin
        cycle_count = cycle_count + 1;

        if ((cycle_count < 80 || (cycle_count >= 330 && cycle_count <= 370)) &&
            (ip_dut.config_tvalid || emu_dut.config_tvalid ||
             ip_dut.fr_sync || emu_dut.fr_sync || ip_tlast || emu_tlast)) begin
            $display("SYNC cycle=%0d cfg_ip=%b/%b/%0d cfg_emu=%b/%b/%0d frsync_ip=%b emu=%b frout_ip=%b emu=%b tlast_ip=%b emu=%b",
                     cycle_count,
                     ip_dut.config_tvalid, ip_dut.config_tlast, ip_dut.config_tdata,
                     emu_dut.config_tvalid, emu_dut.config_tlast, emu_dut.config_tdata,
                     ip_dut.fr_sync, emu_dut.fr_sync,
                     ip_dut.fr_out, emu_dut.fr_out,
                     ip_tlast, emu_tlast);
        end

        if (ip_tvalid || emu_tvalid) begin
            output_count = output_count + 1;

            if (ip_tvalid !== emu_tvalid) begin
                valid_mismatch_count = valid_mismatch_count + 1;
                $display("VALID MISMATCH cycle=%0d: ip=%b emu=%b",
                         cycle_count, ip_tvalid, emu_tvalid);
            end

            if (ip_tlast !== emu_tlast) begin
                last_mismatch_count = last_mismatch_count + 1;
                $display("TLAST MISMATCH cycle=%0d: ip=%b emu=%b",
                         cycle_count, ip_tlast, emu_tlast);
            end

            if (ip_tvalid && emu_tvalid) begin
                for (int lane = 0; lane < OUTPUT_WORDS; lane = lane + 1) begin
                    logic signed [15:0] ip_i;
                    logic signed [15:0] ip_q;
                    logic signed [15:0] emu_i;
                    logic signed [15:0] emu_q;
                    ip_i = $signed(ip_tdata[lane*32 +: 16]);
                    ip_q = $signed(ip_tdata[lane*32 + 16 +: 16]);
                    emu_i = $signed(emu_tdata[lane*32 +: 16]);
                    emu_q = $signed(emu_tdata[lane*32 + 16 +: 16]);
                    data_check_count = data_check_count + 2;
                    total_abs_error = total_abs_error +
                        ((ip_i >= emu_i) ? (ip_i - emu_i) : (emu_i - ip_i));
                    total_abs_error = total_abs_error +
                        ((ip_q >= emu_q) ? (ip_q - emu_q) : (emu_q - ip_q));
                    if (!within_tolerance(ip_i, emu_i) || !within_tolerance(ip_q, emu_q)) begin
                        mismatch_count = mismatch_count + 1;
                        $display("DATA MISMATCH cycle=%0d output=%0d lane=%0d: ip=(%0d,%0d) emu=(%0d,%0d)",
                                 cycle_count, output_count, lane,
                                 ip_i, ip_q, emu_i, emu_q);
                    end
                end
            end
        end
    end

    initial begin
        clk = 1'b0;
        aresetn = 1'b0;
        s_axis_tvalid = 1'b0;
        s_axis_tdata = '0;
        cycle_count = 0;
        input_count = 0;
        output_count = 0;
        data_check_count = 0;
        mismatch_count = 0;
        valid_mismatch_count = 0;
        last_mismatch_count = 0;
        total_abs_error = 0;
        watchdog_count = 0;

        repeat (4) @(negedge clk);
        aresetn = 1'b1;
        $display("tb_firs_compare: starting %0d samples, frame size=%0d",
                 TOTAL_SAMPLES, SAMPLES_PER_FRAME);

        for (int sample = 0; sample < TOTAL_SAMPLES; sample = sample + 1) begin
            @(negedge clk);
            s_axis_tvalid = 1'b1;
            drive_sample(sample / SAMPLES_PER_PATTERN, sample);
            input_count = input_count + 1;
        end

        @(negedge clk);
        s_axis_tvalid = 1'b0;
        s_axis_tdata = '0;

        repeat (DRAIN_CYCLES) @(posedge clk);

        $display("RESULT: %s", (mismatch_count == 0 && valid_mismatch_count == 0 && last_mismatch_count == 0) ? "PASS" : "FAIL");
        $display("inputs=%0d outputs=%0d data_checks=%0d data_mismatches=%0d valid_mismatches=%0d tlast_mismatches=%0d",
                 input_count, output_count, data_check_count, mismatch_count,
                 valid_mismatch_count, last_mismatch_count);
        $display("tolerance abs=%0d rel=%.3f total_abs_error=%0d",
                 ABS_TOLERANCE, REL_TOLERANCE, total_abs_error);
        if (mismatch_count != 0 || valid_mismatch_count != 0 || last_mismatch_count != 0)
            $fatal(1, "FIRs IP/EMULATOR comparison failed");
        $finish;
    end

    always @(posedge clk) begin
        watchdog_count = watchdog_count + 1;
        if (watchdog_count > WATCHDOG_CYCLES)
            $fatal(1, "FIRs comparison watchdog expired");
    end

endmodule
