`timescale 1ns / 1ps

module ssrfft_8x64_sync_sv #(
    parameter int NFFT = 16,
    parameter int SSR  = 8,
    parameter int B    = 16
)(
    input  logic                  aresetn,
    input  logic                  aclk,

    input  logic [2*SSR*B-1:0]    s_axis_tdata,
    input  logic                  s_axis_tlast,
    input  logic                  s_axis_tvalid,

    output logic [2*SSR*B-1:0]    m_axis_tdata,
    output logic                  m_axis_tlast,
    output logic                  m_axis_tvalid,

    input  logic [31:0]           SCALE_REG,
    input  logic [31:0]           QOUT_REG
);

    localparam int FFT_OUT_W = 27;

    logic [2*SSR*B-1:0] framing_tdata;
    logic               framing_tvalid;

    logic [5:0] scale_reg_i;
    logic [3:0] qout_reg_i;
    logic [4:0] qout_idx;

    logic [0:0] fft_i_valid;
    logic [0:0] fft_o_valid;
    logic [5:0] fft_o_scale;

    logic signed [B-1:0] lane_re [0:7];
    logic signed [B-1:0] lane_im [0:7];

    logic signed [FFT_OUT_W-1:0] fft_re [0:7];
    logic signed [FFT_OUT_W-1:0] fft_im [0:7];

    genvar gi;

    // Guardrail: this wrapper is only defined for 8x64 FFT.
    initial begin
        if (SSR != 8) begin
            $error("ssrfft_8x64_sync_sv requires SSR=8, got %0d", SSR);
        end
    end

    assign scale_reg_i = SCALE_REG[5:0];

    always_comb begin
        if (QOUT_REG[31:0] > 32'd11) begin
            qout_reg_i = 4'd0;
        end else begin
            qout_reg_i = QOUT_REG[3:0];
        end
    end

    assign qout_idx = {1'b0, qout_reg_i};

    framing_sv #(
        .NFFT (NFFT),
        .SSR  (SSR),
        .B    (B)
    ) framing_i (
        .aresetn      (aresetn),
        .aclk         (aclk),
        .s_axis_tdata (s_axis_tdata),
        .s_axis_tlast (s_axis_tlast),
        .s_axis_tvalid(s_axis_tvalid),
        .tdata        (framing_tdata),
        .tvalid       (framing_tvalid)
    );

    assign fft_i_valid[0] = framing_tvalid;

    generate
        for (gi = 0; gi < SSR; gi = gi + 1) begin : GEN_INPACK
            always_comb begin
                lane_re[gi] = framing_tdata[gi*2*B +: B];
                lane_im[gi] = framing_tdata[gi*2*B + B +: B];
            end
        end
    endgenerate

    tlast_gen_sv #(
        .NFFT (NFFT),
        .SSR  (SSR)
    ) tlast_gen_i (
        .rstn    (aresetn),
        .clk     (aclk),
        .en      (fft_o_valid[0]),
        .o_tlast (m_axis_tlast)
    );

    ssr_8x64_sv #(
        .FFT_LATENCY(32),
        .INPUT_DELAY(4),
        .OUTPUT_DELAY(6),
        .LANE_MAP('{0,1,2,3,4,5,6,7})
    ) ssr_8x64_i (
        .clk     (aclk),
        .i_valid (fft_i_valid),
        .i_scale (scale_reg_i),

        .i_re_0 (lane_re[0]), .i_re_1 (lane_re[1]), .i_re_2 (lane_re[2]), .i_re_3 (lane_re[3]),
        .i_re_4 (lane_re[4]), .i_re_5 (lane_re[5]), .i_re_6 (lane_re[6]), .i_re_7 (lane_re[7]),

        .i_im_0 (lane_im[0]), .i_im_1 (lane_im[1]), .i_im_2 (lane_im[2]), .i_im_3 (lane_im[3]),
        .i_im_4 (lane_im[4]), .i_im_5 (lane_im[5]), .i_im_6 (lane_im[6]), .i_im_7 (lane_im[7]),

        .o_re_0 (fft_re[0]), .o_re_1 (fft_re[1]), .o_re_2 (fft_re[2]), .o_re_3 (fft_re[3]),
        .o_re_4 (fft_re[4]), .o_re_5 (fft_re[5]), .o_re_6 (fft_re[6]), .o_re_7 (fft_re[7]),

        .o_im_0 (fft_im[0]), .o_im_1 (fft_im[1]), .o_im_2 (fft_im[2]), .o_im_3 (fft_im[3]),
        .o_im_4 (fft_im[4]), .o_im_5 (fft_im[5]), .o_im_6 (fft_im[6]), .o_im_7 (fft_im[7]),

        .o_valid (fft_o_valid),
        .o_scale (fft_o_scale)
    );

    // Assign outputs.
    assign m_axis_tvalid = fft_o_valid[0];

    generate
        for (gi = 0; gi < SSR; gi = gi + 1) begin : GEN_OUTPACK
            always_comb begin
                m_axis_tdata[gi*2*B +: B]     = fft_re[gi][qout_idx +: B];
                m_axis_tdata[gi*2*B + B +: B] = fft_im[gi][qout_idx +: B];
            end
        end
    endgenerate

endmodule
