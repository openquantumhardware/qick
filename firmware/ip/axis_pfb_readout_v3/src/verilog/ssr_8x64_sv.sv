`timescale 1ns / 1ps

// Behavioral 8-lane x 64-point complex FFT model.
// Non-synthesizable model intended for simulation/emulation.
module ssr_8x64_sv #(
    parameter int FFT_LATENCY = 18
)(
    input  logic                    clk,
    input  logic [0:0]              i_valid,
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

    output logic signed [26:0]      o_re_0 = '0,
    output logic signed [26:0]      o_re_1 = '0,
    output logic signed [26:0]      o_re_2 = '0,
    output logic signed [26:0]      o_re_3 = '0,
    output logic signed [26:0]      o_re_4 = '0,
    output logic signed [26:0]      o_re_5 = '0,
    output logic signed [26:0]      o_re_6 = '0,
    output logic signed [26:0]      o_re_7 = '0,

    output logic signed [26:0]      o_im_0 = '0,
    output logic signed [26:0]      o_im_1 = '0,
    output logic signed [26:0]      o_im_2 = '0,
    output logic signed [26:0]      o_im_3 = '0,
    output logic signed [26:0]      o_im_4 = '0,
    output logic signed [26:0]      o_im_5 = '0,
    output logic signed [26:0]      o_im_6 = '0,
    output logic signed [26:0]      o_im_7 = '0,

    output logic [0:0]              o_valid = '0,
    output logic [5:0]              o_scale = '0
);

    localparam int NFFT  = 64;
    localparam int LANES = 8;
    localparam real PI   = 3.14159265358979323846;

    logic signed [15:0] in_re_lanes [0:LANES-1];
    logic signed [15:0] in_im_lanes [0:LANES-1];

    logic signed [15:0] frame_re [0:NFFT-1];
    logic signed [15:0] frame_im [0:NFFT-1];

    logic signed [26:0] out_re_mem [0:NFFT-1];
    logic signed [26:0] out_im_mem [0:NFFT-1];

    int in_cycle_idx      = 0;
    int out_cycle_idx     = 0;
    int latency_ctr       = 0;

    logic       out_stream_active = 1'b0;
    logic [5:0] frame_scale       = 6'd0;

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

    task automatic compute_fft_and_store(input logic [5:0] scale_s);
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
            scale_div = 1.0;
            for (n = 0; n < scale_s; n = n + 1) begin
                scale_div = scale_div * 2.0;
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

                out_re_mem[k] = sat27(sum_r);
                out_im_mem[k] = sat27(sum_i);
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

    always_ff @(posedge clk) begin
        int lane;

        o_valid <= 1'b0;

        if (i_valid[0]) begin
            for (lane = 0; lane < LANES; lane = lane + 1) begin
                frame_re[in_cycle_idx*LANES + lane] = in_re_lanes[lane];
                frame_im[in_cycle_idx*LANES + lane] = in_im_lanes[lane];
            end

            if (in_cycle_idx == (NFFT/LANES - 1)) begin
                in_cycle_idx <= 0;
                frame_scale  <= i_scale;
                compute_fft_and_store(i_scale);
                latency_ctr <= FFT_LATENCY - 1;
            end else begin
                in_cycle_idx <= in_cycle_idx + 1;
            end
        end

        if (latency_ctr > 0) begin
            latency_ctr <= latency_ctr - 1;
            if (latency_ctr == 1) begin
                out_stream_active <= 1'b1;
                out_cycle_idx     <= 0;
                o_scale           <= frame_scale;
            end
        end

        if (out_stream_active) begin
            o_valid <= 1'b1;

            o_re_0 <= out_re_mem[out_cycle_idx*LANES + 0];
            o_re_1 <= out_re_mem[out_cycle_idx*LANES + 1];
            o_re_2 <= out_re_mem[out_cycle_idx*LANES + 2];
            o_re_3 <= out_re_mem[out_cycle_idx*LANES + 3];
            o_re_4 <= out_re_mem[out_cycle_idx*LANES + 4];
            o_re_5 <= out_re_mem[out_cycle_idx*LANES + 5];
            o_re_6 <= out_re_mem[out_cycle_idx*LANES + 6];
            o_re_7 <= out_re_mem[out_cycle_idx*LANES + 7];

            o_im_0 <= out_im_mem[out_cycle_idx*LANES + 0];
            o_im_1 <= out_im_mem[out_cycle_idx*LANES + 1];
            o_im_2 <= out_im_mem[out_cycle_idx*LANES + 2];
            o_im_3 <= out_im_mem[out_cycle_idx*LANES + 3];
            o_im_4 <= out_im_mem[out_cycle_idx*LANES + 4];
            o_im_5 <= out_im_mem[out_cycle_idx*LANES + 5];
            o_im_6 <= out_im_mem[out_cycle_idx*LANES + 6];
            o_im_7 <= out_im_mem[out_cycle_idx*LANES + 7];

            if (out_cycle_idx == (NFFT/LANES - 1)) begin
                out_cycle_idx     <= 0;
                out_stream_active <= 1'b0;
            end else begin
                out_cycle_idx <= out_cycle_idx + 1;
            end
        end
    end

endmodule
