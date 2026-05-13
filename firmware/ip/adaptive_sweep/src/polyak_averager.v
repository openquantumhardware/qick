`timescale 1ns / 1ps
//
// polyak_averager.v
//
// Chunked Polyak / running averager built around a single reciprocal-multiply
// "divider".  The ARM precomputes RECIPROCAL = ceil(2^32 / n_avg) and writes
// it through reciprocal_in.  Every 2^chunk_size_log2 valid samples the module
// fires:  xbar = (sum * reciprocal) >>> 32.
//
// One instance is used per channel (e.g. one for I and one for Q).  When
// chunk_size_log2 is chosen so that 2^chunk_size_log2 == n_avg the module
// behaves as a one-shot averager (drop a soft_reset between measurements);
// when chunks are smaller than the total measurement length it behaves as a
// running chunked Polyak average and exposes xbar_delta_o for convergence
// detection.
//
// Datapath / timing  (target c_clk = 200 MHz on RFSoC 4x2 ZU48DR)
//   H0  sample_in  -> sign-extended sample_ext              (1 LUT level)
//   H1  sum       <= sum + sample_ext                       (48-bit add)
//   C0  on chunk close: latch sum_chunk, reciprocal         (DSP A reg)
//   C1  mul_p1   <= sum_chunk * reciprocal                  (DSP M reg)
//   C2  mul_p2   <= mul_p1                                  (DSP P reg)
//   C3  xbar_next = mul_p2 >>> 32                           (wire)
//   C4  xbar_o, xbar_delta_o, valid_o                       (output regs)
//
// Synchronous active-low reset only (project policy commit b4f6bcc9).
//

module polyak_averager #(
    parameter integer SAMPLE_WIDTH = 16,   // signed input width
    parameter integer SUM_WIDTH    = 48,   // signed accumulator
    parameter integer AVG_WIDTH    = 32,   // signed average output
    parameter integer RECIP_WIDTH  = 32,   // unsigned reciprocal
    parameter integer COUNT_WIDTH  = 16    // total sample counter
)(
    input  wire                          clk,
    input  wire                          rst_n,

    // Sample input
    input  wire signed [SAMPLE_WIDTH-1:0] sample_in,
    input  wire                           sample_valid,

    // Configuration
    input  wire        [RECIP_WIDTH-1:0]  reciprocal_in,
    input  wire        [3:0]              chunk_size_log2,  // 1..8

    // Control
    input  wire                           soft_reset,       // clear sum/count/xbar

    // Outputs
    output reg  signed [AVG_WIDTH-1:0]    xbar_o,
    output reg         [AVG_WIDTH-1:0]    xbar_delta_o,
    output reg         [COUNT_WIDTH-1:0]  count_o,
    output reg                            valid_o           // pulses 1 cycle on chunk close
);

    // -----------------------------------------------------------
    // Hot path: accumulate samples and detect chunk close
    // -----------------------------------------------------------
    reg signed [SUM_WIDTH-1:0]   sum;
    reg signed [SUM_WIDTH-1:0]   sum_chunk;        // snapshot of sum at chunk close
    reg        [COUNT_WIDTH-1:0] in_chunk_count;   // counts 0..(2^k - 1)
    reg                          chunk_close_r;
    reg        [RECIP_WIDTH-1:0] reciprocal_r;

    wire signed [SUM_WIDTH-1:0] sample_ext =
        {{(SUM_WIDTH-SAMPLE_WIDTH){sample_in[SAMPLE_WIDTH-1]}}, sample_in};

    // chunk_size_log2 acts as a comparator threshold against in_chunk_count.
    // 1..8 supported -> chunk lengths 2..256.
    wire [COUNT_WIDTH-1:0] chunk_len_minus1 =
        ({{(COUNT_WIDTH-1){1'b0}}, 1'b1} << chunk_size_log2) - 1'b1;

    always @(posedge clk) begin
        if (!rst_n || soft_reset) begin
            sum            <= {SUM_WIDTH{1'b0}};
            sum_chunk      <= {SUM_WIDTH{1'b0}};
            in_chunk_count <= {COUNT_WIDTH{1'b0}};
            count_o        <= {COUNT_WIDTH{1'b0}};
            chunk_close_r  <= 1'b0;
            reciprocal_r   <= {RECIP_WIDTH{1'b0}};
        end else begin
            chunk_close_r  <= 1'b0;
            // reciprocal latches every cycle so the ARM can update it between chunks
            reciprocal_r   <= reciprocal_in;

            if (sample_valid) begin
                sum     <= sum + sample_ext;
                count_o <= count_o + 1'b1;

                if (in_chunk_count == chunk_len_minus1) begin
                    // This is the last sample of the chunk: snapshot the
                    // running sum (including this sample) and pulse chunk_close.
                    in_chunk_count <= {COUNT_WIDTH{1'b0}};
                    sum_chunk      <= sum + sample_ext;
                    chunk_close_r  <= 1'b1;
                end else begin
                    in_chunk_count <= in_chunk_count + 1'b1;
                end
            end
        end
    end

    // -----------------------------------------------------------
    // Cold path: sum_chunk * reciprocal -> xbar (multi-cycle)
    // 4-stage DSP pipeline; result valid 4 cycles after chunk_close_r.
    // -----------------------------------------------------------
    reg signed [SUM_WIDTH-1:0]    mul_a_r;
    reg signed [RECIP_WIDTH:0]    mul_b_r;       // sign-extend unsigned to keep signed mul
    (* use_dsp = "yes" *)
    reg signed [SUM_WIDTH+RECIP_WIDTH:0] mul_p1; // 1st stage of DSP
    reg signed [SUM_WIDTH+RECIP_WIDTH:0] mul_p2; // 2nd stage of DSP
    reg signed [AVG_WIDTH-1:0]    xbar_next;
    reg signed [AVG_WIDTH-1:0]    xbar_prev;
    reg [3:0]                     pipe_valid;    // shift register tracking valid

    always @(posedge clk) begin
        if (!rst_n || soft_reset) begin
            mul_a_r      <= {SUM_WIDTH{1'b0}};
            mul_b_r      <= {(RECIP_WIDTH+1){1'b0}};
            mul_p1       <= {(SUM_WIDTH+RECIP_WIDTH+1){1'b0}};
            mul_p2       <= {(SUM_WIDTH+RECIP_WIDTH+1){1'b0}};
            xbar_next    <= {AVG_WIDTH{1'b0}};
            xbar_prev    <= {AVG_WIDTH{1'b0}};
            xbar_o       <= {AVG_WIDTH{1'b0}};
            xbar_delta_o <= {AVG_WIDTH{1'b0}};
            valid_o      <= 1'b0;
            pipe_valid   <= 4'b0;
        end else begin
            // Stage 0 -> 1
            mul_a_r    <= sum_chunk;
            mul_b_r    <= {1'b0, reciprocal_r};            // unsigned -> 33b signed positive
            // Stage 1 -> 2
            mul_p1     <= $signed(mul_a_r) * $signed(mul_b_r);
            // Stage 2 -> 3
            mul_p2     <= mul_p1;
            // Stage 3 -> 4: arithmetic right-shift by 32 then truncate to AVG_WIDTH.
            //   product = sum_chunk * reciprocal  (signed, SUM_WIDTH+RECIP_WIDTH+1 bits)
            //   xbar    = product >>> 32          (lower AVG_WIDTH bits of that = product[31+AVG_WIDTH:32])
            xbar_next  <= mul_p2[32 +: AVG_WIDTH];
            // Stage 4: register xbar, compute |delta|
            if (pipe_valid[3]) begin
                xbar_o       <= xbar_next;
                xbar_prev    <= xbar_next;
                xbar_delta_o <= (xbar_next >= xbar_prev) ?
                                 (xbar_next - xbar_prev) :
                                 (xbar_prev - xbar_next);
                valid_o      <= 1'b1;
            end else begin
                valid_o      <= 1'b0;
            end

            // Pipeline valid shift register
            pipe_valid <= {pipe_valid[2:0], chunk_close_r};
        end
    end

endmodule
