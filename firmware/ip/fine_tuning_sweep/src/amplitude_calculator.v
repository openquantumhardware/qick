`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// amplitude_calculator -- integrates |IQ|^2 over one measurement window and
// emits the accumulated power once per trigger.
//
// Robustness contract (so the IP can never wedge on hardware):
//   * A trigger (re)arms a FRESH window in ANY state. A burst that under-
//     delivered samples is therefore abandoned on the next trigger instead of
//     sticking in RUN forever.
//   * A watchdog force-completes the window if the sample stream ends before
//     `nsamp` valid beats arrive (e.g. nsamp set larger than the readout
//     delivers). It emits whatever was accumulated -- consistent across points
//     since every shot streams the same sample count -- so the downstream
//     argmax stays correct. This removes the hard dependency on nsamp exactly
//     matching the per-shot decimated-sample count.
//
// Completion therefore happens on whichever fires first:
//   (a) sample_cnt reaches nsamp  (clean, exact integral; nsamp <= delivered)
//   (b) WDOG_LIMIT cycles elapse with no new sample (stream ended / starved)
//------------------------------------------------------------------------------

module amplitude_calculator #(
    parameter MAX_AVG     = 64,
    parameter ACCUM_WIDTH = 52,
    // RUN cycles with no newly-accepted sample before the window is force-
    // completed. Must be >> the largest inter-sample gap on s_axis (so it never
    // fires mid-stream) and << the host inter-trigger time. 65536 @ 552.96 MHz
    // ~= 118 us: far above any decimated-readout gap, far below a host round-trip.
    parameter WDOG_LIMIT  = 32'd65536
)(
    input                            clk,
    input                            rst_n,

    input                            s_axis_tvalid,
    input  [31:0]                    s_axis_tdata,

    input                            trigger,
    input  [31:0]                    nsamp,
    input  [$clog2(MAX_AVG)-1:0]     averager_value,

    output reg [ACCUM_WIDTH-1:0]     m_axis_tdata,
    output reg                       m_axis_tvalid,
    output reg                       one_burst_done
);

    // ------------------------------------------------------------------
    //  Stage 0 – latch IQ so the DSP A/B input regs see stable data
    // ------------------------------------------------------------------
    (* mark_debug = "true" *) reg signed [15:0] i_s0, q_s0;
    (* mark_debug = "true" *) reg               v_s0;

    always @(posedge clk) begin
        if (!rst_n) begin
            i_s0 <= 0; q_s0 <= 0; v_s0 <= 0;
        end else begin
            i_s0 <= s_axis_tdata[31:16];
            q_s0 <= s_axis_tdata[15:0];
            v_s0 <= s_axis_tvalid;
        end
    end

    // ------------------------------------------------------------------
    //  Stage 1 – i*i and q*q.
    //
    //  Split into TWO register layers (product + output) so each square
    //  maps to a FULLY pipelined DSP48E2: i_s0/q_s0 -> A/B input reg,
    //  ii_m/qq_m -> M reg (the multiplier-output register), ii_s1/qq_s1
    //  -> P reg. The M reg is what closes timing on the 552 MHz
    //  clk_adc0_x2 domain. With only ONE register layer the synthesiser
    //  leaves the 16x16 multiply combinational (no MREG) and the
    //  i_s0 -> DSP -> ii_s1 path fails setup by ~0.46 ns. The extra
    //  pipeline cycle is absorbed by the v_s*/run_d* valid pipeline below
    //  and does not change the accumulated value.
    // ------------------------------------------------------------------
    (* mark_debug = "true" *) (* use_dsp = "yes" *) reg [31:0] ii_m,  qq_m;   // DSP M-reg (product)
    (* mark_debug = "true" *) (* use_dsp = "yes" *) reg [31:0] ii_s1, qq_s1;  // DSP P-reg (output)
    (* mark_debug = "true" *) reg                              v_s0b, v_s1;

    always @(posedge clk) begin
        if (!rst_n) begin
            ii_m  <= 0; qq_m  <= 0; v_s0b <= 0;
            ii_s1 <= 0; qq_s1 <= 0; v_s1  <= 0;
        end else begin
            // multiplier output -> MREG
            ii_m  <= i_s0 * i_s0;
            qq_m  <= q_s0 * q_s0;
            v_s0b <= v_s0;
            // MREG -> PREG
            ii_s1 <= ii_m;
            qq_s1 <= qq_m;
            v_s1  <= v_s0b;
        end
    end

    // ------------------------------------------------------------------
    //  Stage 2 – i*i + q*q  (32-bit add, one CARRY8 chain)
    // ------------------------------------------------------------------
    (* mark_debug = "true" *) reg [32:0] power_s2;
    (* mark_debug = "true" *) reg        v_s2;

    always @(posedge clk) begin
        if (!rst_n) begin
            power_s2 <= 0; v_s2 <= 0;
        end else begin
            power_s2 <= {1'b0, ii_s1} + {1'b0, qq_s1};
            v_s2     <= v_s1;
        end
    end

    // ------------------------------------------------------------------
    //  Control FSM + accumulator
    //
    //  "run" state is pipelined 4 cycles (run_d3) so the accumulator only
    //  counts power_s2 samples that originated in state==RUN. The pipeline is
    //  flushed on every (re)trigger so a fresh window always re-applies the
    //  4-cycle startup mask. (4 = i_s0 -> ii_m -> ii_s1 -> power_s2.)
    // ------------------------------------------------------------------
    localparam IDLE = 1'b0;
    localparam RUN  = 1'b1;
    (* mark_debug = "true" *) reg state;

    (* mark_debug = "true" *) reg [31:0]                  sample_cnt;
    (* mark_debug = "true" *) reg [$clog2(MAX_AVG)-1:0]   burst_cnt;
    (* mark_debug = "true" *) reg [ACCUM_WIDTH-1:0]       accumulator;
    (* mark_debug = "true" *) reg [ACCUM_WIDTH-1:0]       sum_reg;
    (* mark_debug = "true" *) reg                         finish_delay;
    (* mark_debug = "true" *) reg [31:0]                  nsamp_latched;
    (* mark_debug = "true" *) reg [31:0]                  wdog;          // cycles in RUN with no accepted sample

    (* mark_debug = "true" *) reg run_d0, run_d1, run_d2, run_d3;

    always @(posedge clk) begin
        if (!rst_n) begin
            run_d0 <= 0; run_d1 <= 0; run_d2 <= 0; run_d3 <= 0;
        end else if (trigger) begin
            // flush the startup mask so every (re)armed window discards its
            // first 4 pipeline cycles, exactly like a fresh IDLE->RUN entry.
            run_d0 <= 0; run_d1 <= 0; run_d2 <= 0; run_d3 <= 0;
        end else begin
            run_d0 <= (state == RUN);
            run_d1 <= run_d0;
            run_d2 <= run_d1;
            run_d3 <= run_d2;
        end
    end

    (* mark_debug = "true" *) wire acc_en   = run_d3 & v_s2;
    // Complete as soon as the sample count is reached -- do NOT wait for
    // s_axis_tvalid to drop. The real readout can hold tvalid high for the
    // whole window; the old `&& !acc_en` wait (plus the watchdog, which resets
    // on every accepted sample) would then never fire. finish_delay is set the
    // cycle after the nsamp-th sample is accumulated, so `accumulator` already
    // holds the full nsamp-sample sum here. The watchdog still covers a stream
    // that STARVES before nsamp samples arrive.
    (* mark_debug = "true" *) wire emit_now = finish_delay ||
                    (state == RUN && wdog >= WDOG_LIMIT);

    always @(posedge clk) begin
        if (!rst_n) begin
            state          <= IDLE;
            sample_cnt     <= 0;
            burst_cnt      <= 0;
            accumulator    <= 0;
            sum_reg        <= 0;
            m_axis_tvalid  <= 0;
            m_axis_tdata   <= 0;
            one_burst_done <= 0;
            finish_delay   <= 0;
            nsamp_latched  <= 0;
            wdog           <= 0;
        end else begin
            m_axis_tvalid  <= 0;
            one_burst_done <= 0;

            if (trigger) begin
                // (Re)arm a fresh window on ANY trigger -- never wedges. A burst
                // still in flight from a previous (under-delivered) shot is
                // simply abandoned here.
                state         <= RUN;
                sample_cnt    <= 0;
                accumulator   <= 0;
                finish_delay  <= 0;
                nsamp_latched <= nsamp;
                wdog          <= 0;
            end else begin
                case (state)
                    IDLE: ; // wait for trigger

                    RUN: begin
                        if (acc_en) begin
                            accumulator <= accumulator + power_s2;
                            sample_cnt  <= sample_cnt + 1;
                            wdog        <= 0;                  // progress -> reset watchdog
                            if (sample_cnt == nsamp_latched - 1)
                                finish_delay <= 1;
                        end else begin
                            wdog <= wdog + 1'b1;               // idle cycle -> age watchdog
                        end

                        if (emit_now) begin
                            one_burst_done <= 1;

                            sum_reg   <= sum_reg + accumulator;
                            burst_cnt <= burst_cnt + 1;

                            if (burst_cnt + 1 >= averager_value) begin
                                m_axis_tdata  <= sum_reg + accumulator;
                                m_axis_tvalid <= 1;
                                burst_cnt     <= 0;
                                sum_reg       <= 0;
                            end

                            accumulator  <= 0;
                            sample_cnt   <= 0;
                            finish_delay <= 0;
                            wdog         <= 0;
                            state        <= IDLE;
                        end
                    end
                endcase
            end
        end
    end

endmodule
