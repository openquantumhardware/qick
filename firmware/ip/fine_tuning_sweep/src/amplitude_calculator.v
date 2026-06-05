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
    output reg                       m_axis_tvalid
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
    //  Stage 1 – i*i and q*q (each maps to ONE DSP48E2 with its M-register
    //  active). The single registered multiply below is enough: Vivado
    //  puts ii_s1/qq_s1 in the DSP MREG, so the 16x16 multiply is no longer
    //  combinational and the 552 MHz clk_adc0_x2 domain closes.
    //
    //  DO NOT put (* mark_debug *) on ii_s1/qq_s1. Marking a register for
    //  debug pins it in fabric, which forbids absorption into the DSP's
    //  internal MREG and forces the whole multiply+ALU+output combinational
    //  (~2.2 ns -> fails setup by ~0.46 ns). The IQ input (i_s0/q_s0) and
    //  the power output (power_s2) keep their probes; the intermediate
    //  squares are internal to the DSP and need no debug net.
    // ------------------------------------------------------------------
    (* use_dsp = "yes" *) reg [31:0] ii_s1, qq_s1;   // -> DSP MREG (do NOT mark_debug)
    (* mark_debug = "true" *) reg    v_s1;

    always @(posedge clk) begin
        if (!rst_n) begin
            ii_s1 <= 0; qq_s1 <= 0; v_s1 <= 0;
        end else begin
            ii_s1 <= i_s0 * i_s0;
            qq_s1 <= q_s0 * q_s0;
            v_s1  <= v_s0;
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
    //  "run" state is pipelined 3 cycles (run_d2) so the accumulator only
    //  counts power_s2 samples that originated in state==RUN. The pipeline is
    //  flushed on every (re)trigger so a fresh window always re-applies the
    //  3-cycle startup mask. (3 = i_s0 -> ii_s1 -> power_s2.)
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

    (* mark_debug = "true" *) reg run_d0, run_d1, run_d2;

    always @(posedge clk) begin
        if (!rst_n) begin
            run_d0 <= 0; run_d1 <= 0; run_d2 <= 0;
        end else if (trigger) begin
            // flush the startup mask so every (re)armed window discards its
            // first 3 pipeline cycles, exactly like a fresh IDLE->RUN entry.
            run_d0 <= 0; run_d1 <= 0; run_d2 <= 0;
        end else begin
            run_d0 <= (state == RUN);
            run_d1 <= run_d0;
            run_d2 <= run_d1;
        end
    end

    (* mark_debug = "true" *) wire acc_en   = run_d2 & v_s2;
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
            finish_delay   <= 0;
            nsamp_latched  <= 0;
            wdog           <= 0;
        end else begin
            m_axis_tvalid  <= 0;

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
