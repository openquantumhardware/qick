`timescale 1ns / 1ps
//
// adaptive_sweep_control.v
//
// QICK Custom-Peripheral (QP2 / qtag_*) opcode FSM.  Translates 5-bit
// opcodes from tProc into control / configuration signals for the
// adaptive_sweep sub-modules and returns one or two 32-bit result words.
//
// The handshake follows the existing custom-peripheral protocol used by
// adaptive_sweep.v's placeholder implementation:
//   - tProc asserts qtag_en_i and presents qtag_op_i + qtag_dt{1..4}_i
//   - We detect the rising edge of qtag_en_i (en_rise) and start the op
//   - qtag_rdy_o is driven low while busy
//   - qtag_vld_o pulses high for one cycle when the result is on
//     qtag_dt1_o / qtag_dt2_o.
//
// Opcode map (5 bits):
//   0x00 NOP            ---
//   0x01 RESET_ALL      soft-reset polyak averagers + bisect, clear x_state
//   0x02 SET_NAVG       dt1=n_avg (info), dt2=reciprocal=ceil(2^32/n_avg)
//   0x03 SET_CHUNK_LOG2 dt1[3:0]=chunk_size_log2 (1..8)
//   0x04 SET_X          dt1=x_fixed (current x state)
//   0x05 SET_BOUNDS     dt1=x_min, dt2=x_max
//   0x06 ARM_CAPTURE    dt1=n_samples to collect
//   0x07 GET_IQ_AVG     -> dt1_o=I_avg, dt2_o=Q_avg
//   0x08 GET_POWER      -> dt1_o=power, dt2_o={31'b0, valid}
//   0x09 KW_LUT_WE      dt1[7:0]=index, dt2=value (signed step)
//   0x0A KW_STEP        dt1=dp_signed, dt2[7:0]=k_idx
//                       -> dt1_o=x_new, dt2_o={31'b0, conv_flag}
//   0x0B GET_X          -> dt1_o=x_current, dt2_o=iter_k
//   0x0C GET_XBAR       -> dt1_o=xbar_x, dt2_o=xbar_delta_x  (running x avg)
//   0x0D BISECT_INIT    dt1=lo, dt2=hi, dt3=tol,
//                       dt4[0]=side_left, dt4[1]=polarity_peak
//   0x0E BISECT_STEP    dt1=pow_mid, dt2=pow_thr
//                       -> dt1_o=mid_next, dt2_o={31'b0, converged}
//   0x0F GET_BISECT     -> dt1_o=lo, dt2_o=hi
//   0x10 GET_STATUS     -> dt1_o=samples_remaining, dt2_o=flags
//   others NOP
//

module adaptive_sweep_control #(
    parameter integer X_WIDTH    = 32,
    parameter integer IQ_WIDTH   = 16,
    parameter integer POW_WIDTH  = 32,
    parameter integer COUNT_WIDTH= 16,
    parameter integer LUT_AW     = 8
)(
    input  wire                    clk,
    input  wire                    rst_n,

    // ---- QP2 (tProc-side) ----
    input  wire                    qtag_en_i,
    input  wire [4:0]              qtag_op_i,
    input  wire [31:0]             qtag_dt1_i,
    input  wire [31:0]             qtag_dt2_i,
    input  wire [31:0]             qtag_dt3_i,
    input  wire [31:0]             qtag_dt4_i,
    output reg                     qtag_rdy_o,
    output reg  [31:0]             qtag_dt1_o,
    output reg  [31:0]             qtag_dt2_o,
    output reg                     qtag_vld_o,

    // ---- polyak_averager (I, Q) common ports ----
    output reg                     pa_soft_reset,
    output reg  [31:0]             pa_reciprocal,
    output reg  [3:0]              pa_chunk_log2,
    // I-channel result
    input  wire signed [X_WIDTH-1:0] pa_i_xbar,
    // Q-channel result
    input  wire signed [X_WIDTH-1:0] pa_q_xbar,

    // ---- iq_power result (post-average) ----
    output reg                     pwr_compute_pulse,    // pulses to start compute
    output reg  signed [IQ_WIDTH-1:0] pwr_i_in,
    output reg  signed [IQ_WIDTH-1:0] pwr_q_in,
    input  wire [POW_WIDTH-1:0]    pwr_value,
    input  wire                    pwr_valid,

    // ---- kw_steps ----
    output reg                     kw_lut_we,
    output reg  [LUT_AW-1:0]       kw_lut_addr,
    output reg  signed [X_WIDTH-1:0] kw_lut_din,
    output reg                     kw_step_trigger,
    output reg  signed [X_WIDTH-1:0] kw_dp_signed,
    output reg  [LUT_AW-1:0]       kw_k_idx,
    output reg  signed [X_WIDTH-1:0] kw_x_in,
    output reg  signed [X_WIDTH-1:0] kw_x_min,
    output reg  signed [X_WIDTH-1:0] kw_x_max,
    input  wire signed [X_WIDTH-1:0] kw_x_out,
    input  wire                    kw_conv_flag,
    input  wire                    kw_valid,

    // ---- bisect_control ----
    output reg                     bs_init,
    output reg  [X_WIDTH-1:0]      bs_lo_init,
    output reg  [X_WIDTH-1:0]      bs_hi_init,
    output reg                     bs_side_left,
    output reg                     bs_polarity_peak,
    output reg  [X_WIDTH-1:0]      bs_tol_in,
    output reg                     bs_step,
    output reg  [X_WIDTH-1:0]      bs_pow_mid,
    output reg  [X_WIDTH-1:0]      bs_pow_thr,
    input  wire [X_WIDTH-1:0]      bs_mid_next,
    input  wire [X_WIDTH-1:0]      bs_lo_o,
    input  wire [X_WIDTH-1:0]      bs_hi_o,
    input  wire                    bs_converged,
    input  wire                    bs_valid,

    // ---- readout_capture ----
    output reg                     rc_arm_pulse,
    output reg  [COUNT_WIDTH-1:0]  rc_n_samples,
    input  wire                    rc_capture_done,
    input  wire [COUNT_WIDTH-1:0]  rc_samples_remaining,

    // ---- internal x state visible to adaptive_sweep top ----
    output reg  signed [X_WIDTH-1:0] x_current_o,
    output reg  signed [X_WIDTH-1:0] x_min_o,
    output reg  signed [X_WIDTH-1:0] x_max_o,
    output reg  [LUT_AW-1:0]        iter_k_o          // KW iteration counter
);

    // -------------------- Opcode constants --------------------
    localparam [4:0] OP_NOP            = 5'h00;
    localparam [4:0] OP_RESET_ALL      = 5'h01;
    localparam [4:0] OP_SET_NAVG       = 5'h02;
    localparam [4:0] OP_SET_CHUNK_LOG2 = 5'h03;
    localparam [4:0] OP_SET_X          = 5'h04;
    localparam [4:0] OP_SET_BOUNDS     = 5'h05;
    localparam [4:0] OP_ARM_CAPTURE    = 5'h06;
    localparam [4:0] OP_GET_IQ_AVG     = 5'h07;
    localparam [4:0] OP_GET_POWER      = 5'h08;
    localparam [4:0] OP_KW_LUT_WE      = 5'h09;
    localparam [4:0] OP_KW_STEP        = 5'h0A;
    localparam [4:0] OP_GET_X          = 5'h0B;
    localparam [4:0] OP_GET_XBAR       = 5'h0C;
    localparam [4:0] OP_BISECT_INIT    = 5'h0D;
    localparam [4:0] OP_BISECT_STEP    = 5'h0E;
    localparam [4:0] OP_GET_BISECT     = 5'h0F;
    localparam [4:0] OP_GET_STATUS     = 5'h10;

    // -------------------- en_rise detect --------------------
    reg en_d;
    wire en_rise = qtag_en_i & ~en_d;
    always @(posedge clk) begin
        if (!rst_n) en_d <= 1'b0;
        else        en_d <= qtag_en_i;
    end

    // -------------------- FSM --------------------
    localparam [2:0] S_IDLE       = 3'd0;
    localparam [2:0] S_DISPATCH   = 3'd1;
    localparam [2:0] S_WAIT_KW    = 3'd2;
    localparam [2:0] S_WAIT_BS    = 3'd3;
    localparam [2:0] S_WAIT_PWR   = 3'd4;
    localparam [2:0] S_RESPOND    = 3'd5;

    reg [2:0]  state;
    reg [4:0]  op_r;
    reg [31:0] dt1_r, dt2_r, dt3_r, dt4_r;
    reg [31:0] res1_r, res2_r;

    // -------------------- Sequential FSM --------------------
    always @(posedge clk) begin
        if (!rst_n) begin
            state             <= S_IDLE;
            op_r              <= 5'h0;
            dt1_r             <= 32'h0;
            dt2_r             <= 32'h0;
            dt3_r             <= 32'h0;
            dt4_r             <= 32'h0;
            res1_r            <= 32'h0;
            res2_r            <= 32'h0;

            qtag_rdy_o        <= 1'b1;
            qtag_dt1_o        <= 32'h0;
            qtag_dt2_o        <= 32'h0;
            qtag_vld_o        <= 1'b0;

            pa_soft_reset     <= 1'b0;
            pa_reciprocal     <= 32'h0;
            pa_chunk_log2     <= 4'd4;

            pwr_compute_pulse <= 1'b0;
            pwr_i_in          <= 0;
            pwr_q_in          <= 0;

            kw_lut_we         <= 1'b0;
            kw_lut_addr       <= 0;
            kw_lut_din        <= 0;
            kw_step_trigger   <= 1'b0;
            kw_dp_signed      <= 0;
            kw_k_idx          <= 0;
            kw_x_in           <= 0;
            kw_x_min          <= 0;
            kw_x_max          <= 0;

            bs_init           <= 1'b0;
            bs_lo_init        <= 0;
            bs_hi_init        <= 0;
            bs_side_left      <= 1'b0;
            bs_polarity_peak  <= 1'b0;
            bs_tol_in         <= 0;
            bs_step           <= 1'b0;
            bs_pow_mid        <= 0;
            bs_pow_thr        <= 0;

            rc_arm_pulse      <= 1'b0;
            rc_n_samples      <= 0;

            x_current_o       <= 0;
            x_min_o           <= 32'sh8000_0000;
            x_max_o           <= 32'sh7FFF_FFFF;
            iter_k_o          <= 0;
        end else begin
            // Default: 1-cycle pulses go low
            pa_soft_reset     <= 1'b0;
            pwr_compute_pulse <= 1'b0;
            kw_lut_we         <= 1'b0;
            kw_step_trigger   <= 1'b0;
            bs_init           <= 1'b0;
            bs_step           <= 1'b0;
            rc_arm_pulse      <= 1'b0;
            qtag_vld_o        <= 1'b0;

            case (state)
                // ----------------------------------------------------
                S_IDLE: begin
                    qtag_rdy_o <= 1'b1;
                    if (en_rise) begin
                        op_r       <= qtag_op_i;
                        dt1_r      <= qtag_dt1_i;
                        dt2_r      <= qtag_dt2_i;
                        dt3_r      <= qtag_dt3_i;
                        dt4_r      <= qtag_dt4_i;
                        qtag_rdy_o <= 1'b0;
                        state      <= S_DISPATCH;
                    end
                end

                // ----------------------------------------------------
                S_DISPATCH: begin
                    case (op_r)
                        OP_NOP: begin
                            res1_r <= 32'h0;
                            res2_r <= 32'h0;
                            state  <= S_RESPOND;
                        end

                        OP_RESET_ALL: begin
                            pa_soft_reset <= 1'b1;
                            iter_k_o      <= 0;
                            state         <= S_RESPOND;
                        end

                        OP_SET_NAVG: begin
                            pa_reciprocal <= dt2_r;       // ceil(2^32 / n_avg)
                            state         <= S_RESPOND;
                        end

                        OP_SET_CHUNK_LOG2: begin
                            pa_chunk_log2 <= dt1_r[3:0];
                            state         <= S_RESPOND;
                        end

                        OP_SET_X: begin
                            x_current_o <= $signed(dt1_r);
                            state       <= S_RESPOND;
                        end

                        OP_SET_BOUNDS: begin
                            x_min_o <= $signed(dt1_r);
                            x_max_o <= $signed(dt2_r);
                            state   <= S_RESPOND;
                        end

                        OP_ARM_CAPTURE: begin
                            rc_arm_pulse  <= 1'b1;
                            rc_n_samples  <= dt1_r[COUNT_WIDTH-1:0];
                            // Also clear polyak averagers for a fresh measurement
                            pa_soft_reset <= 1'b1;
                            state         <= S_RESPOND;
                        end

                        OP_GET_IQ_AVG: begin
                            res1_r <= pa_i_xbar;
                            res2_r <= pa_q_xbar;
                            state  <= S_RESPOND;
                        end

                        OP_GET_POWER: begin
                            // Kick off an iq_power compute on the current xbar
                            pwr_i_in          <= pa_i_xbar[IQ_WIDTH-1:0];
                            pwr_q_in          <= pa_q_xbar[IQ_WIDTH-1:0];
                            pwr_compute_pulse <= 1'b1;
                            state             <= S_WAIT_PWR;
                        end

                        OP_KW_LUT_WE: begin
                            kw_lut_we   <= 1'b1;
                            kw_lut_addr <= dt1_r[LUT_AW-1:0];
                            kw_lut_din  <= $signed(dt2_r);
                            state       <= S_RESPOND;
                        end

                        OP_KW_STEP: begin
                            kw_dp_signed    <= $signed(dt1_r);
                            kw_k_idx        <= dt2_r[LUT_AW-1:0];
                            kw_x_in         <= x_current_o;
                            kw_x_min        <= x_min_o;
                            kw_x_max        <= x_max_o;
                            kw_step_trigger <= 1'b1;
                            state           <= S_WAIT_KW;
                        end

                        OP_GET_X: begin
                            res1_r <= x_current_o;
                            res2_r <= {{(32-LUT_AW){1'b0}}, iter_k_o};
                            state  <= S_RESPOND;
                        end

                        OP_GET_XBAR: begin
                            // Reuse pa_i_xbar as the "x running average" channel
                            // (or return current x as a placeholder).
                            res1_r <= x_current_o;
                            res2_r <= 32'h0;
                            state  <= S_RESPOND;
                        end

                        OP_BISECT_INIT: begin
                            bs_init          <= 1'b1;
                            bs_lo_init       <= dt1_r;
                            bs_hi_init       <= dt2_r;
                            bs_tol_in        <= dt3_r;
                            bs_side_left     <= dt4_r[0];
                            bs_polarity_peak <= dt4_r[1];
                            state            <= S_RESPOND;
                        end

                        OP_BISECT_STEP: begin
                            bs_pow_mid <= dt1_r;
                            bs_pow_thr <= dt2_r;
                            bs_step    <= 1'b1;
                            state      <= S_WAIT_BS;
                        end

                        OP_GET_BISECT: begin
                            res1_r <= bs_lo_o;
                            res2_r <= bs_hi_o;
                            state  <= S_RESPOND;
                        end

                        OP_GET_STATUS: begin
                            res1_r <= {{(32-COUNT_WIDTH){1'b0}}, rc_samples_remaining};
                            res2_r <= {30'h0, rc_capture_done, 1'b0};
                            state  <= S_RESPOND;
                        end

                        default: begin
                            res1_r <= 32'h0;
                            res2_r <= 32'h0;
                            state  <= S_RESPOND;
                        end
                    endcase
                end

                // ----------------------------------------------------
                S_WAIT_KW: begin
                    if (kw_valid) begin
                        res1_r      <= kw_x_out;
                        res2_r      <= {31'h0, kw_conv_flag};
                        x_current_o <= kw_x_out;
                        iter_k_o    <= iter_k_o + 1'b1;
                        state       <= S_RESPOND;
                    end
                end

                // ----------------------------------------------------
                S_WAIT_BS: begin
                    if (bs_valid) begin
                        res1_r <= bs_mid_next;
                        res2_r <= {31'h0, bs_converged};
                        state  <= S_RESPOND;
                    end
                end

                // ----------------------------------------------------
                S_WAIT_PWR: begin
                    if (pwr_valid) begin
                        res1_r <= pwr_value;
                        res2_r <= 32'h1;     // valid flag
                        state  <= S_RESPOND;
                    end
                end

                // ----------------------------------------------------
                S_RESPOND: begin
                    qtag_dt1_o <= res1_r;
                    qtag_dt2_o <= res2_r;
                    qtag_vld_o <= 1'b1;
                    qtag_rdy_o <= 1'b1;
                    state      <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
