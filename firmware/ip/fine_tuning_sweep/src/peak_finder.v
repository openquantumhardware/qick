`timescale 1ns / 1ps
//------------------------------------------------------------------------------
// peak_finder -- autonomous single-pass sweep controller + argmax.
//
//   The IP owns the frequency grid. On OP1 (start) it walks
//       cur_freq = start_freq, start_freq+step, start_freq+2*step, ...
//   announcing each point to the tProc via (freq_word, freq_valid). The tProc
//   retunes the generator + readout DDC to freq_word and fires `averager_value`
//   triggers; amplitude_calculator integrates each trigger and accumulates the
//   bursts, emitting ONE averaged power (amp_valid) per point. peak_finder
//   compares that averaged power, keeps the running argmax, then advances.
//
//   Termination is a pure point counter (point_idx + 1 >= n_points), matching
//   the fixed number of averaged triggers the host fires per pass.
//   On termination it parks freq_word = freq_at_max and pulses `finish`.
//
//   This block does ONE pass per OP1 -- no internal coarse->fine transition.
//   freq_valid / finish are 1-cycle pulses; the wrapper makes them sticky.
//
//   Coding style -- classic three-process academic FSM:
//     (1) STATE REGISTER  : state <= next_state          (synchronous reset)
//     (2) NEXT-STATE LOGIC : next_state = f(state, regs)  (combinational)
//     (3) DATAPATH/OUTPUT  : registers from the CURRENT state (sync reset)
//
//   HARDWARE-HARDENED ADVANCE (2026-06-26). On board the WAIT_MEAS advance never
//   fired even though a counter on the SAME amp_valid net (amp_seen) caught every
//   pulse -- a hardware-only capture/timing failure invisible to sim. Two defences:
//     * PULSE -> LEVEL: the 1-cycle amp_valid is latched into a STICKY level
//       (meas_pending) + its data held (amp_data_held). The FSM advances on the
//       stable LEVEL, never on a 1-cycle pulse, so it cannot "miss" it. The level
//       persists until consumed, so a pulse that arrived at any cycle is honoured.
//     * REGISTERED last_point: the advance ENABLE is now purely flop outputs
//       (meas_pending, state, last_point_r) -- no 32-bit add/compare in the
//       advance cone. The point-count compare is moved to its own flop-to-flop
//       path (last_point_r), so point_idx/state can't lose timing either.
//   The 52-bit argmax compare stays independent: it only feeds max_amplitude /
//   freq_at_max and NEVER gates the advance, so its (longest) path can't freeze
//   the sweep regardless of its timing.
//------------------------------------------------------------------------------

module peak_finder #(
    parameter ACCUM_WIDTH = 52
)(
    input  wire                   clk,
    input  wire                   rstn,

    // OP1: latch config + begin the sweep
    input  wire                   start,
    input  wire [31:0]            start_freq,   // freq_word (pinc) of point 0
    input  wire [31:0]            stop_freq,    // end-frequency clamp (now unused)
    input  wire [31:0]            step,         // per-point increment
    input  wire [31:0]            n_points,     // point-count budget

    // OP3: clear running max while idle (optional; OP1 also clears)
    input  wire                   reset_max,

    // averaged power for the current point (from amplitude_calculator via CDC)
    input  wire                   amp_valid,
    input  wire [ACCUM_WIDTH-1:0] amp_data,

    // handshake to the tProc (wrapper latches these into sticky flags)
    (* mark_debug = "true" *) output reg  [31:0] freq_word,
    (* mark_debug = "true" *) output reg         freq_valid,
    (* mark_debug = "true" *) output reg         finish,

    // result (read back on OP2 via freq_word; max kept for the comparison)
    output reg  [ACCUM_WIDTH-1:0] max_amplitude,
    (* mark_debug = "true" *) output reg  [31:0] freq_at_max,

    // ---- diagnostic taps (clk domain; surfaced via wrapper QP2 OP5) ----
    (* mark_debug = "true" *) output wire [1:0]  dbg_state,
    (* mark_debug = "true" *) output wire [31:0] dbg_point_idx,
    (* mark_debug = "true" *) output wire [31:0] dbg_n_pts,
    (* mark_debug = "true" *) output wire [31:0] dbg_cur_step,
    // counts EVERY amp_valid this block's input sees, regardless of FSM state
    (* mark_debug = "true" *) output wire [31:0] dbg_amp_seen,
    // sticky "measurement pending" LEVEL the FSM advances on (1 = a captured
    // measurement is waiting; if this is 1 while point_idx stays 0 the advance
    // LOGIC itself is the fault, not the pulse capture)
    (* mark_debug = "true" *) output wire        dbg_meas_pending,
    // registered last-point flag (the advance/finish selector)
    (* mark_debug = "true" *) output wire        dbg_last_point
);

    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] SEND_FREQ = 2'd1;
    localparam [1:0] WAIT_MEAS = 2'd2;

    (* mark_debug = "true" *) reg [1:0]  state;
    reg [1:0]  next_state;

    (* mark_debug = "true" *) reg [31:0] cur_freq;
    reg [31:0] cur_step;
    reg [31:0] n_pts;
    (* mark_debug = "true" *) reg [31:0] point_idx;

    // ---- pulse -> level capture (hardware-hardened, see header) ----
    // Latch the 1-cycle amp_valid into a STICKY level + hold its data, so the
    // FSM advances on a stable level (the same trivial flop class as amp_seen,
    // which catches every pulse on board) rather than catching a 1-cycle pulse.
    (* mark_debug = "true" *) reg                    meas_pending;
    reg [ACCUM_WIDTH-1:0]                            amp_data_held;

    // ---- REGISTERED last-point flag ----
    // last_point_r holds (point_idx + 1 >= n_pts) for the CURRENT point_idx, so
    // the advance enable uses only flop outputs (no add/compare in the advance
    // cone). It is re-evaluated for the NEXT point each time point_idx advances.
    (* mark_debug = "true" *) reg                    last_point_r;

    // the FSM consumes the pending measurement the cycle it acts on it in WAIT_MEAS
    wire meas_consumed = (state == WAIT_MEAS) & meas_pending;

    // ------------------------------------------------------------------
    // pulse -> level capture + data hold (trivial path == amp_seen's):
    //   set on amp_valid, hold amp_data, clear when the FSM consumes it;
    //   a new sweep (start) discards any stale pending measurement.
    // ------------------------------------------------------------------
    always @(posedge clk) begin
        if (!rstn) begin
            meas_pending  <= 1'b0;
            amp_data_held <= {ACCUM_WIDTH{1'b0}};
        end else if (start) begin
            meas_pending  <= 1'b0;            // discard stale measurement on new sweep
        end else if (amp_valid) begin
            meas_pending  <= 1'b1;            // sticky set (set wins over consume)
            amp_data_held <= amp_data;
        end else if (meas_consumed) begin
            meas_pending  <= 1'b0;
        end
    end

    // ------------------------------------------------------------------
    // (1) STATE REGISTER -- synchronous reset
    // ------------------------------------------------------------------
    always @(posedge clk) begin
        if (!rstn) state <= IDLE;
        else       state <= next_state;
    end

    // ------------------------------------------------------------------
    // (2) NEXT-STATE LOGIC -- combinational, gated ONLY by flop outputs
    //     (meas_pending, last_point_r) -- no add/compare in this cone.
    // ------------------------------------------------------------------
    always @(*) begin
        next_state = state;
        case (state)
            IDLE:      if (start)        next_state = SEND_FREQ;
            SEND_FREQ:                   next_state = WAIT_MEAS;
            WAIT_MEAS: if (meas_pending) next_state = last_point_r ? IDLE : SEND_FREQ;
            default:                     next_state = IDLE;
        endcase
    end

    // ------------------------------------------------------------------
    // (3) DATAPATH + REGISTERED OUTPUTS -- synchronous reset, CURRENT state.
    // ------------------------------------------------------------------
    always @(posedge clk) begin
        if (!rstn) begin
            freq_word     <= 32'd0;
            freq_valid    <= 1'b0;
            finish        <= 1'b0;
            max_amplitude <= {ACCUM_WIDTH{1'b0}};
            freq_at_max   <= 32'd0;
            cur_freq      <= 32'd0;
            cur_step      <= 32'd0;
            n_pts         <= 32'd0;
            point_idx     <= 32'd0;
            last_point_r  <= 1'b0;
        end else begin
            // defaults: freq_valid / finish are 1-cycle pulses
            freq_valid <= 1'b0;
            finish     <= 1'b0;

            // standalone max clear -- only meaningful between passes (IDLE)
            if (reset_max && state == IDLE) begin
                max_amplitude <= {ACCUM_WIDTH{1'b0}};
                freq_at_max   <= 32'd0;
            end

            case (state)
            IDLE: begin
                if (start) begin
                    cur_freq      <= start_freq;
                    cur_step      <= step;          // stop_freq unused (counter terminates)
                    n_pts         <= n_points;
                    point_idx     <= 32'd0;
                    last_point_r  <= (32'd1 >= n_points);  // last-point flag for point 0
                    max_amplitude <= {ACCUM_WIDTH{1'b0}};
                    freq_at_max   <= 32'd0;
                end
            end

            // announce the current point to the tProc
            SEND_FREQ: begin
                freq_word  <= cur_freq;
                freq_valid <= 1'b1;
            end

            // act on the STABLE pending level: argmax, then advance or finish.
            // Advance updates (point_idx/cur_freq/state) are gated on flop
            // outputs only; the 52-bit argmax compare is independent and never
            // gates the advance.
            WAIT_MEAS: begin
                if (meas_pending) begin
                    // --- argmax (independent; longest path, advance-irrelevant) ---
                    if (amp_data_held > max_amplitude) begin
                        max_amplitude <= amp_data_held;
                        freq_at_max   <= cur_freq;
                    end

                    if (last_point_r) begin
                        // park the winning freq for the OP2 read (account for a
                        // last-point win, since freq_at_max updates this cycle)
                        freq_word <= (amp_data_held > max_amplitude) ? cur_freq
                                                                    : freq_at_max;
                        finish    <= 1'b1;
                    end else begin
                        cur_freq     <= cur_freq + cur_step;
                        point_idx    <= point_idx + 32'd1;
                        // re-evaluate the last-point flag for the NEXT point_idx
                        last_point_r <= (point_idx + 32'd2 >= n_pts);
                    end
                end
            end

            default: ;
            endcase
        end
    end

    // diagnostic taps
    assign dbg_state        = state;
    assign dbg_point_idx    = point_idx;
    assign dbg_n_pts        = n_pts;
    assign dbg_cur_step     = cur_step;
    assign dbg_meas_pending = meas_pending;
    assign dbg_last_point   = last_point_r;

    // DECISIVE PROBE: count EVERY amp_valid this block's input sees, regardless
    // of FSM state (the cross-check that proved the pulse arrives on board).
    reg [31:0] amp_seen_cnt;
    always @(posedge clk) begin
        if (!rstn)          amp_seen_cnt <= 32'd0;
        else if (amp_valid) amp_seen_cnt <= amp_seen_cnt + 32'd1;
    end
    assign dbg_amp_seen = amp_seen_cnt;

endmodule
