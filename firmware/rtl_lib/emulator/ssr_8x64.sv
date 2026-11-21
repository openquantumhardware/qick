`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : ssr_8x64
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    ssr_8x64.sv
//!
//! @brief   Behavioural model of the System Generator FFT ssr_8x64 (64 points, 8 samples per clock), for the Verilator emulator.
//!
//! @details
//! Same module name and ports as the System Generator entity (qick:dsp:ssr_fft_8x64), which Verilator
//! cannot read (VHDL). Taken from ssr_8x64_sv.sv of the HRL / Harvey Mudd clinic emulator (Diego Martin,
//! openquantumhardware/qick branch merge-hrl-main at 07887032): a plain DFT with real arithmetic
//! ($cos/$sin), collected frame by frame and delayed to the latency of the core. It is NOT bit-exact:
//! see tests/vendor for how far it is from the real core, and for the latency and bin order it was
//! tuned to. Not synthesizable.
//!
//! @author  QICK Development Team (model: Diego Martin, HRL clinic)
//!
//! 1.0.1: the output ports lost their `= '0` initial values. They are driven by continuous assignments
//! (from the output delay line, or straight from the *_int registers), and IEEE 1800 does not allow an
//! initial value on a variable that is continuously assigned: Verilator 5.052 rejects it (CONTASSINIT),
//! 5.042 accepted it. The power-up value still comes from the registers that drive the ports (the
//! initial block of the delay line, and the *_int initial values). The *_int power-up values moved from the
//! initial block to their declarations: the always_ff writes them too, which Verilator 5.052 lint reports as
//! MULTIDRIVEN (a variable of an always_ff written by another process, IEEE 1800 9.2.2.4).
//!
//! @version 1.0.1
// The model keeps the structure of the HRL original: blocking assignments in the clocked block that fills the frame,
// and power-up values declared with the variables.
/* verilator lint_off BLKSEQ */
/* verilator lint_off PROCASSINIT */
/* verilator lint_off UNUSEDSIGNAL */
module ssr_8x64 #(
    parameter int FFT_LATENCY    = 32,
    parameter int INPUT_DELAY    = 4,
    parameter int OUTPUT_DELAY   = 6,
    parameter int LANE_MAP [8] = '{0,1,2,3,4,5,6,7}
)(
    input  logic                    clk,
    input  logic                    i_valid,
    input  logic [5:0]              i_scale,

    input  logic signed [15:0]      i_re_0,
    input  logic signed [15:0]      i_re_1,
    input  logic signed [15:0]      i_re_2,
    input  logic signed [15:0]      i_re_3,
    input  logic signed [15:0]      i_re_4,
    input  logic signed [15:0]      i_re_5,
    input  logic signed [15:0]      i_re_6,
    input  logic signed [15:0]      i_re_7,

    input  logic signed [15:0]      i_im_0,
    input  logic signed [15:0]      i_im_1,
    input  logic signed [15:0]      i_im_2,
    input  logic signed [15:0]      i_im_3,
    input  logic signed [15:0]      i_im_4,
    input  logic signed [15:0]      i_im_5,
    input  logic signed [15:0]      i_im_6,
    input  logic signed [15:0]      i_im_7,

    output logic signed [26:0]      o_re_0,
    output logic signed [26:0]      o_re_1,
    output logic signed [26:0]      o_re_2,
    output logic signed [26:0]      o_re_3,
    output logic signed [26:0]      o_re_4,
    output logic signed [26:0]      o_re_5,
    output logic signed [26:0]      o_re_6,
    output logic signed [26:0]      o_re_7,

    output logic signed [26:0]      o_im_0,
    output logic signed [26:0]      o_im_1,
    output logic signed [26:0]      o_im_2,
    output logic signed [26:0]      o_im_3,
    output logic signed [26:0]      o_im_4,
    output logic signed [26:0]      o_im_5,
    output logic signed [26:0]      o_im_6,
    output logic signed [26:0]      o_im_7,

    output logic                    o_valid,
    output logic [5:0]              o_scale
);

    localparam int NFFT  = 64;
    localparam int LANES = 8;
    localparam real PI   = 3.14159265358979323846;

    logic signed [15:0] in_re_lanes [LANES];
    logic signed [15:0] in_im_lanes [LANES];
    logic signed [15:0] in_re_lanes_d [LANES];
    logic signed [15:0] in_im_lanes_d [LANES];

    // Output frame queue for continuous streaming.
    localparam int PIPELINE_FRAMES = 32;
    logic signed [26:0] out_re_frame_buf [PIPELINE_FRAMES][NFFT];
    logic signed [26:0] out_im_frame_buf [PIPELINE_FRAMES][NFFT];
    logic [5:0]         out_scale_frame_buf [PIPELINE_FRAMES];
    logic               frame_pending [PIPELINE_FRAMES];
    int                 frame_latency_ctr [PIPELINE_FRAMES];
    int                 write_frame_ptr = 0;
    int                 read_frame_ptr  = 0;
    int                 active_frame_ptr = 0;

    logic signed [15:0] frame_re [NFFT];
    logic signed [15:0] frame_im [NFFT];

    int in_cycle_idx      = 0;
    int out_cycle_idx     = 0;

    logic       out_stream_active = 1'b0;

    logic        i_valid_d;
    logic [5:0]  i_scale_d;

    // Power-up values in the declarations, not in the initial block: the always_ff below writes these, and a
    // variable of an always_ff written by another process is MULTIDRIVEN (IEEE 1800 9.2.2.4, Verilator 5.052).
    logic        o_valid_int = 1'b0;
    logic [5:0]  o_scale_int = '0;
    logic signed [26:0] o_re_0_int = '0, o_re_1_int = '0, o_re_2_int = '0, o_re_3_int = '0;
    logic signed [26:0] o_re_4_int = '0, o_re_5_int = '0, o_re_6_int = '0, o_re_7_int = '0;
    logic signed [26:0] o_im_0_int = '0, o_im_1_int = '0, o_im_2_int = '0, o_im_3_int = '0;
    logic signed [26:0] o_im_4_int = '0, o_im_5_int = '0, o_im_6_int = '0, o_im_7_int = '0;

    // Permuted output staging (SSR lane mapping)
    logic signed [26:0] o_re_perm  [LANES];
    logic signed [26:0] o_im_perm  [LANES];

    function automatic logic signed [26:0] sat27(input real x);
        real maxv;
        real minv;
        int  xi;
        begin
            maxv =  67108863.0;
            minv = -67108864.0;
            if (x > maxv) begin
                xi =  67108863;
            end else if (x < minv) begin
                xi = -67108864;
            end else begin
                xi = $rtoi(x);
            end
            sat27 = xi[26:0];
        end
    endfunction

    initial begin
        for (int f = 0; f < PIPELINE_FRAMES; f++) begin
            frame_pending[f] = 1'b0;
            frame_latency_ctr[f] = 0;
            out_scale_frame_buf[f] = '0;
        end
    end

    task automatic compute_fft_and_store(
        input logic [5:0] scale_s,
        input int frame_slot
    );
        real xr;
        real xi;
        real wr;
        real wi;
        real ar;
        real ai;
        real sum_r;
        real sum_i;
        real scale_div;
        int  k;
        int  n;
        begin
            // i_scale is a mask of the six stages of the core: every bit set halves the result once.
            scale_div = 1.0;
            for (n = 0; n < 6; n = n + 1) begin
                if (scale_s[n]) scale_div = scale_div * 2.0;
            end

            for (k = 0; k < NFFT; k = k + 1) begin
                sum_r = 0.0;
                sum_i = 0.0;
                for (n = 0; n < NFFT; n = n + 1) begin
                    xr = frame_re[n];
                    xi = frame_im[n];
                    wr = $cos((2.0*PI*k*n)/NFFT);
                    wi = -$sin((2.0*PI*k*n)/NFFT);

                    ar = xr*wr - xi*wi;
                    ai = xr*wi + xi*wr;

                    sum_r = sum_r + ar;
                    sum_i = sum_i + ai;
                end

                sum_r = sum_r / scale_div;
                sum_i = sum_i / scale_div;

                out_re_frame_buf[frame_slot][k] = sat27(sum_r);
                out_im_frame_buf[frame_slot][k] = sat27(sum_i);
            end
        end
    endtask

    always_comb begin
        in_re_lanes[0] = i_re_0;
        in_re_lanes[1] = i_re_1;
        in_re_lanes[2] = i_re_2;
        in_re_lanes[3] = i_re_3;
        in_re_lanes[4] = i_re_4;
        in_re_lanes[5] = i_re_5;
        in_re_lanes[6] = i_re_6;
        in_re_lanes[7] = i_re_7;

        in_im_lanes[0] = i_im_0;
        in_im_lanes[1] = i_im_1;
        in_im_lanes[2] = i_im_2;
        in_im_lanes[3] = i_im_3;
        in_im_lanes[4] = i_im_4;
        in_im_lanes[5] = i_im_5;
        in_im_lanes[6] = i_im_6;
        in_im_lanes[7] = i_im_7;
    end

    // Input delay stage
    if (INPUT_DELAY > 0) begin : gen_in_delay
        reg               id_valid  [INPUT_DELAY];
        reg [5:0]         id_scale  [INPUT_DELAY];
        reg signed [15:0] id_re     [INPUT_DELAY][LANES];
        reg signed [15:0] id_im     [INPUT_DELAY][LANES];
        integer i;
        integer lane;

        initial begin
            for (int d = 0; d < INPUT_DELAY; d++) begin
                id_valid[d] = 1'b0;
                id_scale[d] = '0;
                for (int ln = 0; ln < LANES; ln++) begin id_re[d][ln] = '0; id_im[d][ln] = '0; end
            end
        end

        always_ff @(posedge clk) begin
            id_valid[0] <= i_valid;
            id_scale[0] <= i_scale;
            for (lane = 0; lane < LANES; lane = lane + 1) begin
                id_re[0][lane] <= in_re_lanes[lane];
                id_im[0][lane] <= in_im_lanes[lane];
            end

            for (i = 1; i < INPUT_DELAY; i = i + 1) begin
                id_valid[i] <= id_valid[i-1];
                id_scale[i] <= id_scale[i-1];
                for (lane = 0; lane < LANES; lane = lane + 1) begin
                    id_re[i][lane] <= id_re[i-1][lane];
                    id_im[i][lane] <= id_im[i-1][lane];
                end
            end
        end

        assign i_valid_d = id_valid[INPUT_DELAY-1];
        assign i_scale_d = id_scale[INPUT_DELAY-1];

        always_comb begin
            for (int lane_idx = 0; lane_idx < LANES; lane_idx = lane_idx + 1) begin
                in_re_lanes_d[lane_idx] = id_re[INPUT_DELAY-1][lane_idx];
                in_im_lanes_d[lane_idx] = id_im[INPUT_DELAY-1][lane_idx];
            end
        end
    end else begin : gen_no_in_delay
        assign i_valid_d = i_valid;
        assign i_scale_d = i_scale;

        always_comb begin
            for (int lane_idx = 0; lane_idx < LANES; lane_idx = lane_idx + 1) begin
                in_re_lanes_d[lane_idx] = in_re_lanes[lane_idx];
                in_im_lanes_d[lane_idx] = in_im_lanes[lane_idx];
            end
        end
    end

    // Pipeline FFT processing - continuous streaming
    always_ff @(posedge clk) begin
        bit emit_this_cycle;
        int emit_frame_ptr;
        int emit_beat_idx;
        int next_frame_ptr;

        // Default low; assert only while a frame is actively being emitted.
        o_valid_int <= 1'b0;

        // Accept new input frame every cycle and compute FFT immediately
        if (i_valid_d) begin
            for (int lane = 0; lane < LANES; lane = lane + 1) begin
                // verilog_lint: waive always-ff-non-blocking
                frame_re[in_cycle_idx*LANES + lane] = in_re_lanes_d[lane];
                // verilog_lint: waive always-ff-non-blocking
                frame_im[in_cycle_idx*LANES + lane] = in_im_lanes_d[lane];
            end

            if (in_cycle_idx == (NFFT/LANES - 1)) begin
                in_cycle_idx <= 0;

                if (frame_pending[write_frame_ptr]) begin
                    $error("ssr_8x64_sv frame queue overflow at slot %0d", write_frame_ptr);
                end

                compute_fft_and_store(i_scale_d, write_frame_ptr);
                out_scale_frame_buf[write_frame_ptr] <= i_scale_d;
                frame_pending[write_frame_ptr] <= 1'b1;
                frame_latency_ctr[write_frame_ptr] <= FFT_LATENCY - 1;

                if (write_frame_ptr == (PIPELINE_FRAMES - 1)) begin
                    write_frame_ptr <= 0;
                end else begin
                    write_frame_ptr <= write_frame_ptr + 1;
                end
            end else begin
                in_cycle_idx <= in_cycle_idx + 1;
            end
        end

        for (int frame_idx = 0; frame_idx < PIPELINE_FRAMES; frame_idx = frame_idx + 1) begin
            if (frame_pending[frame_idx] && (frame_latency_ctr[frame_idx] > 0)) begin
                frame_latency_ctr[frame_idx] <= frame_latency_ctr[frame_idx] - 1;
            end
        end

        // verilog_lint: waive always-ff-non-blocking
        emit_this_cycle = out_stream_active ||
                          (frame_pending[read_frame_ptr] && (frame_latency_ctr[read_frame_ptr] == 0));
        // verilog_lint: waive always-ff-non-blocking
        emit_frame_ptr  = out_stream_active ? active_frame_ptr : read_frame_ptr;
        // verilog_lint: waive always-ff-non-blocking
        emit_beat_idx   = out_stream_active ? out_cycle_idx : 0;
        // verilog_lint: waive always-ff-non-blocking
        next_frame_ptr  = (emit_frame_ptr == (PIPELINE_FRAMES - 1)) ? 0 : (emit_frame_ptr + 1);

        if (!emit_this_cycle) begin
            out_stream_active <= 1'b0;
        end

        if (emit_this_cycle) begin
            o_valid_int <= 1'b1;
            o_scale_int <= out_scale_frame_buf[emit_frame_ptr];

            o_re_0_int <= out_re_frame_buf[emit_frame_ptr][emit_beat_idx*LANES + 0];
            o_re_1_int <= out_re_frame_buf[emit_frame_ptr][emit_beat_idx*LANES + 1];
            o_re_2_int <= out_re_frame_buf[emit_frame_ptr][emit_beat_idx*LANES + 2];
            o_re_3_int <= out_re_frame_buf[emit_frame_ptr][emit_beat_idx*LANES + 3];
            o_re_4_int <= out_re_frame_buf[emit_frame_ptr][emit_beat_idx*LANES + 4];
            o_re_5_int <= out_re_frame_buf[emit_frame_ptr][emit_beat_idx*LANES + 5];
            o_re_6_int <= out_re_frame_buf[emit_frame_ptr][emit_beat_idx*LANES + 6];
            o_re_7_int <= out_re_frame_buf[emit_frame_ptr][emit_beat_idx*LANES + 7];

            o_im_0_int <= out_im_frame_buf[emit_frame_ptr][emit_beat_idx*LANES + 0];
            o_im_1_int <= out_im_frame_buf[emit_frame_ptr][emit_beat_idx*LANES + 1];
            o_im_2_int <= out_im_frame_buf[emit_frame_ptr][emit_beat_idx*LANES + 2];
            o_im_3_int <= out_im_frame_buf[emit_frame_ptr][emit_beat_idx*LANES + 3];
            o_im_4_int <= out_im_frame_buf[emit_frame_ptr][emit_beat_idx*LANES + 4];
            o_im_5_int <= out_im_frame_buf[emit_frame_ptr][emit_beat_idx*LANES + 5];
            o_im_6_int <= out_im_frame_buf[emit_frame_ptr][emit_beat_idx*LANES + 6];
            o_im_7_int <= out_im_frame_buf[emit_frame_ptr][emit_beat_idx*LANES + 7];

            if (emit_beat_idx == (NFFT/LANES - 1)) begin
                out_cycle_idx     <= 0;
                frame_pending[emit_frame_ptr] <= 1'b0;
                read_frame_ptr <= next_frame_ptr;

                if (frame_pending[next_frame_ptr] && (frame_latency_ctr[next_frame_ptr] == 0)) begin
                    out_stream_active <= 1'b1;
                    active_frame_ptr <= next_frame_ptr;
                end else begin
                    out_stream_active <= 1'b0;
                end
            end else begin
                out_stream_active <= 1'b1;
                active_frame_ptr <= emit_frame_ptr;
                out_cycle_idx <= emit_beat_idx + 1;
            end
        end
    end

    // SSR lane permutation
    always_comb begin
        o_re_perm[LANE_MAP[0]] = o_re_0_int;
        o_re_perm[LANE_MAP[1]] = o_re_1_int;
        o_re_perm[LANE_MAP[2]] = o_re_2_int;
        o_re_perm[LANE_MAP[3]] = o_re_3_int;
        o_re_perm[LANE_MAP[4]] = o_re_4_int;
        o_re_perm[LANE_MAP[5]] = o_re_5_int;
        o_re_perm[LANE_MAP[6]] = o_re_6_int;
        o_re_perm[LANE_MAP[7]] = o_re_7_int;

        o_im_perm[LANE_MAP[0]] = o_im_0_int;
        o_im_perm[LANE_MAP[1]] = o_im_1_int;
        o_im_perm[LANE_MAP[2]] = o_im_2_int;
        o_im_perm[LANE_MAP[3]] = o_im_3_int;
        o_im_perm[LANE_MAP[4]] = o_im_4_int;
        o_im_perm[LANE_MAP[5]] = o_im_5_int;
        o_im_perm[LANE_MAP[6]] = o_im_6_int;
        o_im_perm[LANE_MAP[7]] = o_im_7_int;
    end

    // Output delay stage
    generate
        if (OUTPUT_DELAY > 0) begin : gen_out_delay
            localparam int MAX_DELAY = 16;
            reg        od_valid  [MAX_DELAY];
            reg [5:0]  od_scale  [MAX_DELAY];
            reg signed [26:0] od_re_0  [MAX_DELAY];
            reg signed [26:0] od_re_1  [MAX_DELAY];
            reg signed [26:0] od_re_2  [MAX_DELAY];
            reg signed [26:0] od_re_3  [MAX_DELAY];
            reg signed [26:0] od_re_4  [MAX_DELAY];
            reg signed [26:0] od_re_5  [MAX_DELAY];
            reg signed [26:0] od_re_6  [MAX_DELAY];
            reg signed [26:0] od_re_7  [MAX_DELAY];
            reg signed [26:0] od_im_0  [MAX_DELAY];
            reg signed [26:0] od_im_1  [MAX_DELAY];
            reg signed [26:0] od_im_2  [MAX_DELAY];
            reg signed [26:0] od_im_3  [MAX_DELAY];
            reg signed [26:0] od_im_4  [MAX_DELAY];
            reg signed [26:0] od_im_5  [MAX_DELAY];
            reg signed [26:0] od_im_6  [MAX_DELAY];
            reg signed [26:0] od_im_7  [MAX_DELAY];
            integer i;

            initial begin
                for (int d = 0; d < MAX_DELAY; d++) begin
                    od_valid[d] = 1'b0;
                    od_scale[d] = '0;
                    od_re_0[d] = '0; od_re_1[d] = '0; od_re_2[d] = '0; od_re_3[d] = '0;
                    od_re_4[d] = '0; od_re_5[d] = '0; od_re_6[d] = '0; od_re_7[d] = '0;
                    od_im_0[d] = '0; od_im_1[d] = '0; od_im_2[d] = '0; od_im_3[d] = '0;
                    od_im_4[d] = '0; od_im_5[d] = '0; od_im_6[d] = '0; od_im_7[d] = '0;
                end
            end

            always_ff @(posedge clk) begin
                od_valid[0] <= o_valid_int;
                od_scale[0] <= o_scale_int;
                od_re_0[0]  <= o_re_perm[0];  od_im_0[0] <= o_im_perm[0];
                od_re_1[0]  <= o_re_perm[1];  od_im_1[0] <= o_im_perm[1];
                od_re_2[0]  <= o_re_perm[2];  od_im_2[0] <= o_im_perm[2];
                od_re_3[0]  <= o_re_perm[3];  od_im_3[0] <= o_im_perm[3];
                od_re_4[0]  <= o_re_perm[4];  od_im_4[0] <= o_im_perm[4];
                od_re_5[0]  <= o_re_perm[5];  od_im_5[0] <= o_im_perm[5];
                od_re_6[0]  <= o_re_perm[6];  od_im_6[0] <= o_im_perm[6];
                od_re_7[0]  <= o_re_perm[7];  od_im_7[0] <= o_im_perm[7];
                for (i = 1; i < OUTPUT_DELAY; i = i + 1) begin
                    od_valid[i] <= od_valid[i-1];
                    od_scale[i] <= od_scale[i-1];
                    od_re_0[i]  <= od_re_0[i-1];   od_im_0[i] <= od_im_0[i-1];
                    od_re_1[i]  <= od_re_1[i-1];   od_im_1[i] <= od_im_1[i-1];
                    od_re_2[i]  <= od_re_2[i-1];   od_im_2[i] <= od_im_2[i-1];
                    od_re_3[i]  <= od_re_3[i-1];   od_im_3[i] <= od_im_3[i-1];
                    od_re_4[i]  <= od_re_4[i-1];   od_im_4[i] <= od_im_4[i-1];
                    od_re_5[i]  <= od_re_5[i-1];   od_im_5[i] <= od_im_5[i-1];
                    od_re_6[i]  <= od_re_6[i-1];   od_im_6[i] <= od_im_6[i-1];
                    od_re_7[i]  <= od_re_7[i-1];   od_im_7[i] <= od_im_7[i-1];
                end
            end

            assign o_valid = od_valid[OUTPUT_DELAY-1];
            assign o_scale = od_scale[OUTPUT_DELAY-1];
            assign o_re_0  = od_re_0[OUTPUT_DELAY-1];   assign o_im_0 = od_im_0[OUTPUT_DELAY-1];
            assign o_re_1  = od_re_1[OUTPUT_DELAY-1];   assign o_im_1 = od_im_1[OUTPUT_DELAY-1];
            assign o_re_2  = od_re_2[OUTPUT_DELAY-1];   assign o_im_2 = od_im_2[OUTPUT_DELAY-1];
            assign o_re_3  = od_re_3[OUTPUT_DELAY-1];   assign o_im_3 = od_im_3[OUTPUT_DELAY-1];
            assign o_re_4  = od_re_4[OUTPUT_DELAY-1];   assign o_im_4 = od_im_4[OUTPUT_DELAY-1];
            assign o_re_5  = od_re_5[OUTPUT_DELAY-1];   assign o_im_5 = od_im_5[OUTPUT_DELAY-1];
            assign o_re_6  = od_re_6[OUTPUT_DELAY-1];   assign o_im_6 = od_im_6[OUTPUT_DELAY-1];
            assign o_re_7  = od_re_7[OUTPUT_DELAY-1];   assign o_im_7 = od_im_7[OUTPUT_DELAY-1];
        end else begin : gen_no_out_delay
            assign o_valid = o_valid_int;
            assign o_scale = o_scale_int;
            assign o_re_0  = o_re_0_int;  assign o_im_0 = o_im_0_int;
            assign o_re_1  = o_re_1_int;  assign o_im_1 = o_im_1_int;
            assign o_re_2  = o_re_2_int;  assign o_im_2 = o_im_2_int;
            assign o_re_3  = o_re_3_int;  assign o_im_3 = o_im_3_int;
            assign o_re_4  = o_re_4_int;  assign o_im_4 = o_im_4_int;
            assign o_re_5  = o_re_5_int;  assign o_im_5 = o_im_5_int;
            assign o_re_6  = o_re_6_int;  assign o_im_6 = o_im_6_int;
            assign o_re_7  = o_re_7_int;  assign o_im_7 = o_im_7_int;
        end
    endgenerate

endmodule
/* verilator lint_on UNUSEDSIGNAL */
/* verilator lint_on PROCASSINIT */
/* verilator lint_on BLKSEQ */
