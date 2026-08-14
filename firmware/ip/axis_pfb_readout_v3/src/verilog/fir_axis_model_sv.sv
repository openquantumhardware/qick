`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// fir_axis_model_sv : lightweight behavioral replacement for Xilinx FIR IP
// -----------------------------------------------------------------------------
// - AXIS-compatible ports aligned to fir_0..fir_7 wrappers.
// - 7-tap polyphase FIR with 8 coefficient phases.
// - I/Q packed on s_axis_data_tdata = {Q[31:16], I[15:0]}.
// - The Xilinx configuration uses eight channels and zero-packing factor two,
//   so consecutive FIR taps are separated by sixteen input samples.
// - Simple fixed latency pipeline on data/valid/tlast.
// -----------------------------------------------------------------------------
module fir_axis_model_sv #(
    parameter int TAPS = 7,
    parameter int PHASES = 8,
    parameter int DATA_W = 16,
    parameter int ACC_W = 48,
    parameter int COEF_SHIFT = 15,
    parameter int LATENCY = 18,
    parameter int TLAST_LATENCY = 18,
    parameter int SAMPLE_STRIDE = PHASES * 2,
    parameter int CONFIG_CHANNELS = PHASES,
    parameter int DATA_FRAME_LENGTH = PHASES,
    parameter int EVENT_LATENCY = 4,
    parameter int signed COEFFS [0:TAPS*PHASES-1] = '{default: 0}
)(
    input  logic                    aclk,
    input  logic                    aresetn,

    input  logic                    s_axis_data_tvalid,
    output logic                    s_axis_data_tready,
    input  logic                    s_axis_data_tlast,
    input  logic [31:0]             s_axis_data_tdata,

    input  logic                    s_axis_config_tvalid,
    output logic                    s_axis_config_tready,
    input  logic                    s_axis_config_tlast,
    input  logic [7:0]              s_axis_config_tdata,

    output logic                    m_axis_data_tvalid,
    output logic                    m_axis_data_tlast,
    output logic [31:0]             m_axis_data_tdata,

    output logic                    event_s_data_tlast_missing,
    output logic                    event_s_data_tlast_unexpected,
    output logic                    event_s_config_tlast_missing,
    output logic                    event_s_config_tlast_unexpected
);

    localparam int PHASE_W = (PHASES > 1) ? $clog2(PHASES) : 1;

    localparam int DELAY_LENGTH = (TAPS - 1) * SAMPLE_STRIDE;

    logic signed [DATA_W-1:0] sample_delay_i [0:DELAY_LENGTH-1];
    logic signed [DATA_W-1:0] sample_delay_q [0:DELAY_LENGTH-1];

    logic [PHASE_W-1:0] config_phase [0:CONFIG_CHANNELS-1];
    logic [PHASE_W-1:0] pending_phase [0:CONFIG_CHANNELS-1];
    logic [PHASE_W-1:0] phase_for_sample;
    int config_index;
    int data_channel;
    int data_frame_index;

    logic signed [ACC_W-1:0] acc_i;
    logic signed [ACC_W-1:0] acc_q;
    logic signed [DATA_W-1:0] out_i;
    logic signed [DATA_W-1:0] out_q;

    logic [31:0] data_pipe [0:LATENCY-1];
    logic [LATENCY-1:0] valid_pipe;
    logic [TLAST_LATENCY-1:0] last_pipe;
    logic [EVENT_LATENCY-1:0] data_missing_pipe;
    logic [EVENT_LATENCY-1:0] data_unexpected_pipe;
    logic [EVENT_LATENCY-1:0] config_missing_pipe;
    logic [EVENT_LATENCY-1:0] config_unexpected_pipe;
    logic data_missing_now;
    logic data_unexpected_now;
    logic config_missing_now;
    logic config_unexpected_now;

    function automatic logic signed [DATA_W-1:0] sat16(input logic signed [ACC_W-1:0] x);
        logic signed [ACC_W-1:0] maxv;
        logic signed [ACC_W-1:0] minv;
        begin
            maxv = (1 <<< (DATA_W-1)) - 1;
            minv = -(1 <<< (DATA_W-1));
            if (x > maxv) begin
                sat16 = maxv[DATA_W-1:0];
            end else if (x < minv) begin
                sat16 = minv[DATA_W-1:0];
            end else begin
                sat16 = x[DATA_W-1:0];
            end
        end
    endfunction

    always_comb begin
        phase_for_sample = config_phase[data_channel];
        acc_i = '0;
        acc_q = '0;
        for (int k = 0; k < TAPS; k = k + 1) begin
            if (k == 0) begin
                acc_i += $signed(s_axis_data_tdata[15:0]) * COEFFS[phase_for_sample*TAPS + k];
                acc_q += $signed(s_axis_data_tdata[31:16]) * COEFFS[phase_for_sample*TAPS + k];
            end else begin
                acc_i += sample_delay_i[k*SAMPLE_STRIDE-1] * COEFFS[phase_for_sample*TAPS + k];
                acc_q += sample_delay_q[k*SAMPLE_STRIDE-1] * COEFFS[phase_for_sample*TAPS + k];
            end
        end
        out_i = sat16(acc_i >>> COEF_SHIFT);
        out_q = sat16(acc_q >>> COEF_SHIFT);
    end

    // The FIR compiler uses the missing-TLAST event to align the PFB framing
    // counter.  Report the event at the expected frame boundary, before the
    // sequential state update consumes this beat.
    always_comb begin
        data_missing_now =
            s_axis_data_tvalid && s_axis_data_tready &&
            (data_frame_index == DATA_FRAME_LENGTH - 1) &&
            !s_axis_data_tlast;
        data_unexpected_now =
            s_axis_data_tvalid && s_axis_data_tready &&
            s_axis_data_tlast &&
            (data_frame_index != DATA_FRAME_LENGTH - 1);
        config_missing_now = 1'b0;
        config_unexpected_now = 1'b0;
    end

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            config_index <= 0;
            data_channel <= 0;
            data_frame_index <= 0;
            valid_pipe <= '0;
            last_pipe <= '0;
            data_missing_pipe <= '0;
            data_unexpected_pipe <= '0;
            config_missing_pipe <= '0;
            config_unexpected_pipe <= '0;
            for (int i = 0; i < DELAY_LENGTH; i = i + 1) begin
                sample_delay_i[i] <= '0;
                sample_delay_q[i] <= '0;
            end
            for (int i = 0; i < CONFIG_CHANNELS; i = i + 1)
                pending_phase[i] <= '0;
            for (int i = 0; i < CONFIG_CHANNELS; i = i + 1)
                config_phase[i] <= '0;
            for (int i = 0; i < LATENCY; i = i + 1)
                data_pipe[i] <= '0;
        end else begin
            if (s_axis_config_tvalid && s_axis_config_tready) begin
                pending_phase[config_index] <= s_axis_config_tdata[PHASE_W-1:0];
                if (s_axis_config_tlast || config_index == CONFIG_CHANNELS - 1) begin
                    for (int i = 0; i < CONFIG_CHANNELS; i = i + 1) begin
                        if (i == config_index)
                            config_phase[i] <= s_axis_config_tdata[PHASE_W-1:0];
                        else
                            config_phase[i] <= pending_phase[i];
                    end
                    config_index <= 0;
                end else begin
                    config_index <= config_index + 1;
                end
            end

            if (s_axis_data_tvalid && s_axis_data_tready) begin
                for (int i = DELAY_LENGTH-1; i > 0; i = i - 1) begin
                    sample_delay_i[i] <= sample_delay_i[i-1];
                    sample_delay_q[i] <= sample_delay_q[i-1];
                end
                sample_delay_i[0] <= $signed(s_axis_data_tdata[15:0]);
                sample_delay_q[0] <= $signed(s_axis_data_tdata[31:16]);
                if (data_channel == PHASES - 1)
                    data_channel <= 0;
                else
                    data_channel <= data_channel + 1;
                if (data_frame_index == DATA_FRAME_LENGTH - 1)
                    data_frame_index <= 0;
                else
                    data_frame_index <= data_frame_index + 1;
            end

            for (int j = LATENCY-1; j > 0; j = j - 1)
                data_pipe[j] <= data_pipe[j-1];
            data_pipe[0] <= {out_q, out_i};

            valid_pipe <= {valid_pipe[LATENCY-2:0], s_axis_data_tvalid};
            last_pipe  <= {last_pipe[TLAST_LATENCY-2:0], s_axis_data_tlast};
            data_missing_pipe <= {data_missing_pipe[EVENT_LATENCY-2:0], data_missing_now};
            data_unexpected_pipe <= {data_unexpected_pipe[EVENT_LATENCY-2:0], data_unexpected_now};
            config_missing_pipe <= {config_missing_pipe[EVENT_LATENCY-2:0], config_missing_now};
            config_unexpected_pipe <= {config_unexpected_pipe[EVENT_LATENCY-2:0], config_unexpected_now};
        end
    end

    assign s_axis_data_tready = 1'b1;
    assign s_axis_config_tready = 1'b1;

    assign m_axis_data_tvalid = valid_pipe[LATENCY-1];
    assign m_axis_data_tlast = last_pipe[TLAST_LATENCY-1];
    assign m_axis_data_tdata = data_pipe[LATENCY-1];

    assign event_s_data_tlast_missing = data_missing_pipe[EVENT_LATENCY-1];
    assign event_s_data_tlast_unexpected = data_unexpected_pipe[EVENT_LATENCY-1];
    assign event_s_config_tlast_missing = config_missing_pipe[EVENT_LATENCY-1];
    assign event_s_config_tlast_unexpected = config_unexpected_pipe[EVENT_LATENCY-1];

    logic _unused_config_tlast;
    assign _unused_config_tlast = s_axis_config_tlast;

endmodule
