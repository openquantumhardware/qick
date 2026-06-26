`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// amplitude_calculator -- integrates |IQ|^2 over one measurement window and
// emits the accumulated power once per `averager_value` triggers.
//
// Completion is COUNT-based -- the same fixed-count model QICK's avg_buffer uses
// (it captures a programmed `length` of decimated samples). The host sets
// `nsamp` to the readout's decimated window length, so the count is always
// reached. There is NO watchdog: a hard-coded timeout is the wrong primitive --
// it can't fire before the next host trigger re-arms (the inter-trigger time is
// far shorter than any safe timeout), and it isn't flexible. A trigger (re)arms
// a FRESH window in ANY state, so each measurement starts clean.
//
//   completion: sample_cnt reaches nsamp   (host sets nsamp <= delivered beats)
//
// Coding style -- classic three-process academic FSM for the IDLE/RUN control:
//     (1) STATE REGISTER  : state <= next_state           (synchronous reset)
//     (2) NEXT-STATE LOGIC : next_state = f(state, inputs)  (combinational)
//     (3) DATAPATH/OUTPUT  : accumulator/counters/m_axis updated from the
//                            CURRENT state (synchronous reset)
// The IQ->square->sum pipeline (stages 0-2) is left intact: it is DATAPATH, not
// a state machine, and its exact register placement is what lets Vivado pack the
// squares into the DSP MREG and close 552 MHz (see the warning at stage 1).
//------------------------------------------------------------------------------

module amplitude_calculator #(
    parameter MAX_AVG     = 64,
    parameter ACCUM_WIDTH = 52
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

    // ---- diagnostic counters (adc clk; cumulative since rst_n). Surfaced via
    //      QP2 OP5 and mark_debug'd so SW -- or an ILA on the clk_core-crossed
    //      copies -- can split the data-path failure: trigger? stream? counted
    //      in-window? emitted? ----
    (* mark_debug = "true" *) output reg [31:0] dbg_trig_cnt,
    (* mark_debug = "true" *) output reg [31:0] dbg_tvalid_cnt,
    (* mark_debug = "true" *) output reg [31:0] dbg_acc_cnt,
    (* mark_debug = "true" *) output reg [31:0] dbg_emit_cnt
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
    (* use_dsp = "yes" *) reg [31:0] ii_s1, qq_s1; 
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
    //  Stage 2 i*i + q*q  (32-bit add, one CARRY8 chain)
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
    reg next_state;

    (* mark_debug = "true" *) reg [31:0]                  sample_cnt;
    (* mark_debug = "true" *) reg [$clog2(MAX_AVG)-1:0]   burst_cnt;
    (* mark_debug = "true" *) reg [ACCUM_WIDTH-1:0]       accumulator;
    (* mark_debug = "true" *) reg [ACCUM_WIDTH-1:0]       sum_reg;
    (* mark_debug = "true" *) reg                         finish_delay;
    (* mark_debug = "true" *) reg [31:0]                  nsamp_latched;

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
    // Complete on the sample COUNT only. finish_delay is set the cycle after the
    // nsamp-th sample is accumulated, so `accumulator` already holds the full
    // nsamp-sample sum here. nsamp is set by the host to the readout's decimated
    // window length, so the count is always reached -- no timeout fallback.
    (* mark_debug = "true" *) wire emit_now = finish_delay;

    // ------------------------------------------------------------------
    //  (1) STATE REGISTER -- synchronous reset
    // ------------------------------------------------------------------
    always @(posedge clk) begin
        if (!rst_n) state <= IDLE;
        else        state <= next_state;
    end

    // ------------------------------------------------------------------
    //  (2) NEXT-STATE LOGIC -- combinational. A trigger (re)arms RUN from ANY
    //  state; absent a trigger, RUN returns to IDLE once the burst emits.
    // ------------------------------------------------------------------
    always @(*) begin
        next_state = state;
        if (trigger) next_state = RUN;
        else case (state)
            IDLE:                next_state = IDLE;
            RUN: if (emit_now)   next_state = IDLE;
            default:             next_state = IDLE;
        endcase
    end

    // ------------------------------------------------------------------
    //  (3) DATAPATH + REGISTERED OUTPUT -- synchronous reset, driven by the
    //  CURRENT state. A trigger (re)arms a fresh window (highest priority);
    //  otherwise the RUN state accumulates and emits.
    // ------------------------------------------------------------------
    always @(posedge clk) begin
        if (!rst_n) begin
            sample_cnt     <= 0;
            burst_cnt      <= 0;
            accumulator    <= 0;
            sum_reg        <= 0;
            m_axis_tvalid  <= 0;
            m_axis_tdata   <= 0;
            finish_delay   <= 0;
            nsamp_latched  <= 0;
        end else begin
            m_axis_tvalid  <= 0;   // default: 1-cycle emit pulse

            if (trigger) begin
                // (Re)arm a fresh window on ANY trigger -- never wedges. A burst
                // still in flight from a previous (under-delivered) shot is
                // simply abandoned here.
                sample_cnt    <= 0;
                accumulator   <= 0;
                finish_delay  <= 0;
                nsamp_latched <= nsamp;
            end else begin
                case (state)
                    IDLE: ; // wait for trigger

                    RUN: begin
                        if (acc_en) begin
                            accumulator <= accumulator + power_s2;
                            sample_cnt  <= sample_cnt + 1;
                            if (sample_cnt == nsamp_latched - 1)
                                finish_delay <= 1;
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
                        end
                    end

                    default: ;
                endcase
            end
        end
    end

    // ------------------------------------------------------------------
    //  Diagnostic counters (adc clk). Cumulative since rst_n; read at
    //  quiescence (after the sweep loop stops firing triggers) via QP2 OP5.
    //  They split the data-path failure cleanly:
    //    dbg_trig_cnt   : trigger pulses seen        (0 -> trigger never crosses)
    //    dbg_tvalid_cnt : s_axis_tvalid beats        (0 -> stream never reaches us)
    //    dbg_acc_cnt    : samples accumulated in RUN  (0 -> stream/trigger misaligned)
    //    dbg_emit_cnt   : bursts emitted (m_axis_tvalid)
    //  (the wrapper counts amp_valid AFTER the back-handshake: emit>0 but that
    //   one 0 -> the CDC handshake is wedging.)
    // ------------------------------------------------------------------
    always @(posedge clk) begin
        if (!rst_n) begin
            dbg_trig_cnt   <= 0;
            dbg_tvalid_cnt <= 0;
            dbg_acc_cnt    <= 0;
            dbg_emit_cnt   <= 0;
        end else begin
            if (trigger)       dbg_trig_cnt   <= dbg_trig_cnt   + 1;
            if (s_axis_tvalid) dbg_tvalid_cnt <= dbg_tvalid_cnt + 1;
            if (acc_en)        dbg_acc_cnt    <= dbg_acc_cnt    + 1;
            if (m_axis_tvalid) dbg_emit_cnt   <= dbg_emit_cnt   + 1;
        end
    end

endmodule
