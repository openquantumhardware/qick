`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : ramp_gen
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    ramp_gen.sv
//!
//! @brief   Linear ramp generator. On trigger, emits y = -M*n + B for
//!
//! @details
//!
//! n in [0, N_STEPS], one step every WAIT cycles; outputs 0 otherwise.
//!
//! Ramp is built by accumulation:
//! ms_r(n) = n*M                (signed-saturated in DATA_W)
//! y(n)    = B - ms_r(n)        (signed-saturated in DATA_W)
//! Both accumulation and final subtraction are independently saturated so a
//! chirp never wraps around (safe clipping at the DATA_W signed limits).
//!
//! FSM: INIT -> CNT -> (WAIT) -> END -> INIT. Advances only when i_en is high.
//! WAIT=0  => one step per cycle (no WAIT state).
//! Emits N_STEPS+1 samples (n in [0, N_STEPS]); y = 0 while in INIT/END.
//!
//! Alignment: bs_r uses the CURRENT ms value (ms(n)) so the first emitted
//! sample is y(0) = B; the accumulator advances in parallel. Output is held
//! for one extra END cycle (y_valid) so the final sample y(N) = B - N*M is
//! emitted before returning to 0.
//!
//! Note: i_trigger is expected already synchronized to i_clk (see cdc_bit_sync
//! in the parent dds_phase_ctrl).
//!
//! @author  @lharnaldi
//!
//! @version 1.0
module ramp_gen #(
    parameter int DATA_W = 16,  //! Ramp data width (signed): i_b, i_m, o_y.
    parameter int CNT_W  = 16   //! Counter width (unsigned): i_n_steps, i_wait.
) (
    input  logic                     i_clk,       //! Clock.
    input  logic                     i_rstn,      //! Synchronous active-low reset.

    input  logic                     i_trigger,   //! Start trigger (synced to i_clk).
    input  logic                     i_en,        //! Enable (din_valid): gates advance.

    input  logic signed [DATA_W-1:0] i_b,         //! Ramp start value B.
    input  logic signed [DATA_W-1:0] i_m,         //! Ramp slope M (per step).
    input  logic        [CNT_W-1:0]  i_n_steps,   //! Number of steps N.
    input  logic        [CNT_W-1:0]  i_wait,      //! Wait cycles per step W.

    output logic signed [DATA_W-1:0] o_y          //! Ramp output.
);

    //! FSM states.
    typedef enum logic [1:0] {
        INIT_ST,
        CNT_ST,
        WAIT_ST,
        END_ST
    } state_t;

    (* fsm_encoding = "one_hot" *) state_t state;

    //! Latched parameters (captured while in INIT).
    logic signed [DATA_W-1:0] b_r;
    logic signed [DATA_W-1:0] m_r;
    logic        [CNT_W-1:0]  n_r;
    logic        [CNT_W-1:0]  w_r;

    //! Counters.
    logic [CNT_W-1:0] cnt;    //! Step index n.
    logic [CNT_W-1:0] wcnt;   //! Wait counter.

    //! Ramp accumulators.
    logic signed [DATA_W-1:0] ms_r;   //! n*M (saturated).
    logic signed [DATA_W-1:0] bs_r;   //! B - n*M (registered output, saturated).

    //! ms_nxt = sat(ms_r + m_r)  — slope accumulator (advances to next n).
    logic signed [DATA_W:0]   ms_sum_ext;
    logic signed [DATA_W-1:0] ms_nxt_sat;
    //! bs_cur = sat(b_r - ms_r)  — output for the CURRENT n (uses current ms_r).
    logic signed [DATA_W:0]   bs_sub_ext;
    logic signed [DATA_W-1:0] bs_cur_sat;

    //! Output-enable register: keeps the output visible one cycle into END so
    //! the final sample y(N) is emitted before the output returns to 0.
    logic y_valid;

    localparam logic signed [DATA_W-1:0] SAT_MAX = {1'b0, {(DATA_W-1){1'b1}}};
    localparam logic signed [DATA_W-1:0] SAT_MIN = {1'b1, {(DATA_W-1){1'b0}}};

    always_comb begin
        // Slope accumulation ms(n+1) = sat(ms(n) + M).
        ms_sum_ext = $signed({ms_r[DATA_W-1], ms_r}) + $signed({m_r[DATA_W-1], m_r});
        if      (ms_sum_ext > $signed(SAT_MAX)) ms_nxt_sat = SAT_MAX;
        else if (ms_sum_ext < $signed(SAT_MIN)) ms_nxt_sat = SAT_MIN;
        else                                    ms_nxt_sat = ms_sum_ext[DATA_W-1:0];

        // Output for current n: y(n) = sat(B - ms(n)), using the CURRENT ms_r.
        bs_sub_ext = $signed({b_r[DATA_W-1], b_r}) - $signed({ms_r[DATA_W-1], ms_r});
        if      (bs_sub_ext > $signed(SAT_MAX)) bs_cur_sat = SAT_MAX;
        else if (bs_sub_ext < $signed(SAT_MIN)) bs_cur_sat = SAT_MIN;
        else                                    bs_cur_sat = bs_sub_ext[DATA_W-1:0];
    end

    //! FSM and datapath registers.
    always_ff @(posedge i_clk) begin
        if (i_rstn == 1'b0) begin
            state <= INIT_ST;
            b_r   <= '0;
            m_r   <= '0;
            n_r   <= '0;
            w_r   <= '0;
            cnt   <= '0;
            wcnt  <= '0;
            ms_r  <= '0;
            bs_r  <= '0;
            y_valid <= 1'b0;
        end else begin
            //! State transitions.
            unique case (state)
                INIT_ST: begin
                    if (i_trigger == 1'b1) state <= CNT_ST;
                end
                CNT_ST: begin
                    if (i_en == 1'b1) begin
                        if (cnt == n_r)         state <= END_ST;
                        else if (w_r != '0)     state <= WAIT_ST;
                    end
                end
                WAIT_ST: begin
                    if (i_en == 1'b1) begin
                        if (wcnt == w_r - 1'b1) state <= CNT_ST;
                    end
                end
                END_ST: begin
                    if (i_trigger == 1'b0)      state <= INIT_ST;
                end
                default: state <= INIT_ST;
            endcase

            //! Latch parameters while in INIT.
            if (state == INIT_ST) begin
                b_r <= i_b;
                m_r <= i_m;
                n_r <= i_n_steps;
                w_r <= i_wait;
            end

            //! Step counter: cleared in INIT, advances in CNT with enable.
            if (state == INIT_ST) begin
                cnt <= '0;
            end else if (state == CNT_ST && i_en == 1'b1) begin
                cnt <= cnt + 1'b1;
            end

            //! Wait counter: runs only in WAIT, cleared elsewhere.
            if (state == WAIT_ST && i_en == 1'b1) begin
                wcnt <= wcnt + 1'b1;
            end else if (state != WAIT_ST) begin
                wcnt <= '0;
            end

            //! Ramp accumulators.
            if (state == INIT_ST) begin
                ms_r <= '0;
                bs_r <= '0;
            end else if (state == CNT_ST && i_en == 1'b1) begin
                ms_r <= ms_nxt_sat;   //! n*M, saturated
                bs_r <= bs_cur_sat;   //! y(n) = B - ms(n), saturated
            end

            //! Output enable: asserted once the ramp starts (first CNT beat),
            //! held through the final sample, deasserted when we settle in END.
            if (state == INIT_ST) begin
                y_valid <= 1'b0;
            end else if (state == CNT_ST) begin
                y_valid <= 1'b1;          //! ramp is producing samples
            end else if (state == END_ST) begin
                y_valid <= 1'b0;          //! last sample already shown -> drop
            end
        end
    end

    //! Output holds bs_r while the ramp is active (incl. the last sample y(N),
    //! which is shown during the first END cycle via y_valid); 0 otherwise.
    assign o_y = y_valid ? bs_r : '0;

    // ------------------------------------------------------------------------
    // Assertions
    // ------------------------------------------------------------------------
`ifndef SYNTHESIS
    //! wcnt must never reach or exceed w_r while in WAIT.
    property p_wcnt_bound;
        @(posedge i_clk) disable iff (!i_rstn)
        (state == WAIT_ST) |-> (wcnt < w_r);
    endproperty
    a_wcnt_bound : assert property (p_wcnt_bound)
        else $error("[ramp_gen] wcnt out of range: %0d >= w_r %0d", wcnt, w_r);
`endif //SYNTHESIS

endmodule
