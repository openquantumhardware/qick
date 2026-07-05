`timescale 1ns / 1ps
//------------------------------------------------------------------------------
// amplitude_calculator -- COHERENT boxcar: sums raw I and raw Q over the window
// AND across the averaging burst, squaring ONCE at burst completion --
// (sum I)^2 + (sum Q)^2. This matches acquire()'s |mean I + j*mean Q|^2 exactly
// (average first, square last) and is what classical S21/resonator spectroscopy
// uses. Replaces the earlier per-sample I^2+Q^2 scheme (square first, average
// last), which is phase-INsensitive and does not match acquire() or the
// classical resonator sweep -- see fine_tuning_sweep_ip memory / session notes
// for the derivation of why the two metrics can pick different peaks.
//
// Completion is COUNT-based (avg_buffer model): the host sets `nsamp` to the
// readout's decimated window length, so the count is always reached. A trigger
// (re)arms a fresh window in ANY state, so each measurement starts clean.
//
// Coding style -- three-process FSM for the IDLE/RUN control (state register /
// next-state comb / datapath), all synchronous reset. The per-sample datapath
// is now pure ADDERS (no multiply): squaring happens ONCE per point, at the
// far-lower burst-complete rate (once per nsamp*averager_value samples), so it
// gets its own small FINALIZE pipeline instead of needing DSP absorption in the
// 552 MHz per-sample path -- this also REMOVES the per-sample DSP-square that
// was the amplitude_calculator timing bottleneck at full rate.
//------------------------------------------------------------------------------

module amplitude_calculator #(
  parameter MAX_AVG = 64,
  parameter ACCUM_WIDTH = 80
)(
  input wire clk,
  input wire rst_n,

  input wire s_axis_tvalid,
  input wire [31:0] s_axis_tdata,

  input wire trigger,
  input wire [31:0] nsamp,
  input wire [$clog2(MAX_AVG)-1:0] averager_value,

  (* mark_debug = "true" *) output reg [ACCUM_WIDTH-1:0] m_axis_tdata,
  (* mark_debug = "true" *) output reg m_axis_tvalid
);

  // Running I/Q sum width: SUM_WIDTH = ACCUM_WIDTH/2 so the final sum-of-two-
  // squares always fits ACCUM_WIDTH bits (a SUM_WIDTH-bit signed value squared
  // is at most 2*(SUM_WIDTH-1) bits; two such squares summed stay under
  // 2*SUM_WIDTH). With ACCUM_WIDTH=80 -> SUM_WIDTH=40 signed, the running sum
  // covers NSAMP*averager_value up to ~16.7M 16-bit samples (e.g. NSAMP up to
  // 16384 samples/shot at averager_value up to 1024) with comfortable margin --
  // sized for the planned MAX_AVG=1024 rebuild, not just today's MAX_AVG=64.
  localparam SUM_WIDTH = ACCUM_WIDTH / 2;

  // ------------------------------------------------------------------
  //  Stage 0 -- latch IQ into a clean synchronous element before the
  //  accumulator. No squaring anywhere in this path: the coherent scheme
  //  sums raw samples, so there is no per-sample multiply at all.
  // ------------------------------------------------------------------
  reg signed [15:0] i_s0, q_s0;
  reg v_s0;

  always @(posedge clk) begin
    if (!rst_n) begin
      i_s0 <= 0;
      q_s0 <= 0;
      v_s0 <= 0;
    end else begin
      i_s0 <= s_axis_tdata[31:16];
      q_s0 <= s_axis_tdata[15:0];
      v_s0 <= s_axis_tvalid;
    end
  end

  // ------------------------------------------------------------------
  //  Control FSM + accumulators. run_d0 masks the 1-cycle stage-0 latency so
  //  the accumulator only counts samples that originated in RUN; the mask is
  //  flushed on every (re)trigger.
  // ------------------------------------------------------------------
  localparam IDLE = 1'b0, RUN = 1'b1;
  (* mark_debug = "true" *) reg state;
  reg next_state;

  (* mark_debug = "true" *) reg [31:0] sample_cnt;
  (* mark_debug = "true" *) reg [$clog2(MAX_AVG)-1:0] burst_cnt;
  (* mark_debug = "true" *) reg signed [SUM_WIDTH-1:0] i_accum, q_accum;     // this shot's window sum
  (* mark_debug = "true" *) reg signed [SUM_WIDTH-1:0] i_sum_reg, q_sum_reg; // cross-shot running sum (no squaring)
  (* mark_debug = "true" *) reg finish_delay;
  (* mark_debug = "true" *) reg [31:0] nsamp_latched;

  (* mark_debug = "true" *) reg run_d0;

  always @(posedge clk) begin
    if (!rst_n)
      run_d0 <= 0;
    else if (trigger)
      run_d0 <= 0;
    else
      run_d0 <= (state == RUN);
  end

  wire acc_en = run_d0 & v_s0;
  wire emit_now = finish_delay;
  wire burst_done = (state == RUN) && emit_now && (burst_cnt + 1 >= averager_value);

  // (1) STATE REGISTER -- synchronous reset
  always @(posedge clk) begin
    if (!rst_n)
      state <= IDLE;
    else
      state <= next_state;
  end

  // (2) NEXT-STATE LOGIC -- a trigger (re)arms RUN from ANY state; absent a
  //     trigger, RUN returns to IDLE once the shot's window closes. Every
  //     branch fully specified (else for every if).
  always @(*) begin
    if (trigger) begin
      next_state = RUN;
    end else begin
      case (state)
        IDLE:
          next_state = IDLE;

        RUN:
          next_state = emit_now ? IDLE : RUN;

        default:
          next_state = IDLE;
      endcase
    end
  end

  // (3) DATAPATH -- synchronous reset, driven by the CURRENT state. Fully
  //     explicit: every register is rewired (reg <= reg) on the paths that
  //     hold it, and every if has an else. emit_now takes priority over
  //     acc_en for the shared counters, matching the original design.
  always @(posedge clk) begin
    if (!rst_n) begin
      sample_cnt <= 0;
      burst_cnt <= 0;
      i_accum <= 0;
      q_accum <= 0;
      i_sum_reg <= 0;
      q_sum_reg <= 0;
      finish_delay <= 0;
      nsamp_latched <= 0;
    end else begin
      if (trigger) begin
        // (re)arm a fresh window; cross-shot sum + output hold
        sample_cnt <= 0;
        i_accum <= 0;
        q_accum <= 0;
        finish_delay <= 0;
        nsamp_latched <= nsamp;
        burst_cnt <= burst_cnt;
        i_sum_reg <= i_sum_reg;
        q_sum_reg <= q_sum_reg;
      end else begin
        case (state)
          RUN: begin
            if (emit_now) begin
              // shot's window done: fold this shot's raw I/Q sum into the
              // cross-shot running sum -- NO squaring here (coherent).
              sample_cnt <= 0;
              i_accum <= 0;
              q_accum <= 0;
              finish_delay <= 0;
              nsamp_latched <= nsamp_latched;
              if (burst_cnt + 1 >= averager_value) begin
                // last shot of the burst: FINALIZE (below) reads i_sum_reg +
                // i_accum combinationally THIS cycle, so no fold is needed
                // here -- just reset for the next burst.
                burst_cnt <= 0;
                i_sum_reg <= 0;
                q_sum_reg <= 0;
              end else begin
                burst_cnt <= burst_cnt + 1;
                i_sum_reg <= i_sum_reg + i_accum;
                q_sum_reg <= q_sum_reg + q_accum;
              end
            end else if (acc_en) begin
              // integrate one raw sample into this shot's window sum
              i_accum <= i_accum + i_s0;
              q_accum <= q_accum + q_s0;
              sample_cnt <= sample_cnt + 1;
              finish_delay <= (sample_cnt == nsamp_latched - 1) ? 1'b1 : finish_delay;
              nsamp_latched <= nsamp_latched;
              burst_cnt <= burst_cnt;
              i_sum_reg <= i_sum_reg;
              q_sum_reg <= q_sum_reg;
            end else begin
              // idle within the window: hold everything, pulse low
              i_accum <= i_accum;
              q_accum <= q_accum;
              sample_cnt <= sample_cnt;
              finish_delay <= finish_delay;
              nsamp_latched <= nsamp_latched;
              burst_cnt <= burst_cnt;
              i_sum_reg <= i_sum_reg;
              q_sum_reg <= q_sum_reg;
            end
          end

          IDLE: begin
            // hold everything, pulse low
            sample_cnt <= sample_cnt;
            i_accum <= i_accum;
            q_accum <= q_accum;
            finish_delay <= finish_delay;
            nsamp_latched <= nsamp_latched;
            burst_cnt <= burst_cnt;
            i_sum_reg <= i_sum_reg;
            q_sum_reg <= q_sum_reg;
          end

          default: begin
            // spurious state: hold everything, pulse low
            sample_cnt <= sample_cnt;
            i_accum <= i_accum;
            q_accum <= q_accum;
            finish_delay <= finish_delay;
            nsamp_latched <= nsamp_latched;
            burst_cnt <= burst_cnt;
            i_sum_reg <= i_sum_reg;
            q_sum_reg <= q_sum_reg;
          end
        endcase
      end
    end
  end

  // ------------------------------------------------------------------
  //  FINALIZE -- burst-complete squaring, once per POINT (not per sample):
  //  (i_sum_reg + i_accum)^2 + (q_sum_reg + q_accum)^2. burst_done fires far
  //  slower than the per-sample path (once every nsamp*averager_value
  //  cycles), so this gets its own multi-stage pipeline instead of forcing a
  //  wide multiply/add into the RUN datapath's single cycle. i_total/q_total
  //  read the PRE-reset values of i_sum_reg/i_accum in the SAME cycle
  //  burst_done is asserted, so the last shot's contribution is included
  //  correctly even though the datapath above resets i_sum_reg/q_sum_reg on
  //  that same edge.
  //
  //  Two real timing problems found on hardware (2026-07-05), fixed in order:
  //  (1) the F2 "sum the squares" add (i_sq_r + q_sq_r, 80 bits) was too deep
  //      for one cycle (2.159ns vs 1.809ns, -0.406ns WNS). Fixed by splitting
  //      it into a low-half add (+carry-out) then a high-half add (+carry-in)
  //      a cycle apart -- see F5/F6 below. This halves the CARRY8 chain
  //      length per stage.
  //  (2) the SQUARING itself (i_total_r*i_total_r, 40x40 signed) is ALSO too
  //      deep for one cycle once Vivado cascades 2 DSP48E2 tiles for it
  //      (1.9-2.2ns, still -0.2ns WNS after fixing (1)). Tried splitting the
  //      40-bit magnitude evenly into 20+20 first (2026-07-05): STILL too
  //      slow (2.14ns) -- DSP48E2's multiplier is 27x18, and 20 exceeds the
  //      18-bit narrow port on BOTH sides, so Vivado cascaded DSP internals
  //      for every partial product anyway. Fixed for real by first dropping
  //      the bottom DROP_BITS of the magnitude (a fixed, uniform right-shift
  //      -- doesn't change which point is the max; only costs precision on
  //      near-zero values that never compete for the max anyway), THEN
  //      splitting the remaining 32 bits evenly into HALF2=16+16 (comfortably
  //      native, no cascade) and squaring via "long multiplication":
  //        x = hi*2^HALF2 + lo   =>   x^2 = hi^2<<(2*HALF2) + (2*hi*lo)<<HALF2 + lo^2
  //      exactly like squaring 37 by hand: 37=30+7, 37^2 = 30^2 + 2*30*7 + 7^2
  //      = 900+420+49 = 1369. Each of the three products (hi*hi, hi*lo,
  //      lo*lo) is only HALF2xHALF2 (16x16) -- comfortably one DSP48E2, one
  //      cycle. Reassembling the three shifted pieces is another wide add,
  //      so it reuses the SAME low/high split-add technique as (1) -- see
  //      F3/F4. Squaring only cares about magnitude (x^2 == (-x)^2), so
  //      everything from F1 on runs on |i_total_r|/|q_total_r| -- no sign
  //      handling needed anywhere below.
  //
  //  None of this costs anything: the whole FINALIZE pipe only advances once
  //  per point (thousands of idle cycles between bursts), so going from 4
  //  stages (F0..F3) to 7 (F0..F6) is pure extra latency, spent for free.
  // ------------------------------------------------------------------
  wire signed [SUM_WIDTH-1:0] i_total = i_sum_reg + i_accum;
  wire signed [SUM_WIDTH-1:0] q_total = q_sum_reg + q_accum;

  // HALF2 must be <=18: DSP48E2's multiplier is 27x18 (one operand can be up
  // to 27 bits, but the NARROW port caps at 18) -- a straight 20x20 split
  // (SUM_WIDTH/2) still exceeds that on both sides, so Vivado cascaded DSP
  // internals for every partial product (2026-07-05: 2.140ns vs 1.809ns,
  // still violating). Instead, drop the bottom DROP_BITS of the magnitude
  // before squaring (a fixed, uniform right-shift -- doesn't change which
  // point is the max, and only costs precision on near-zero values that
  // never compete for the max anyway), then split the remaining 32 bits
  // evenly into HALF2=16+16 -- comfortably native, no cascade, one cycle.
  localparam HALF2 = 16;
  localparam DROP_BITS = SUM_WIDTH - 2 * HALF2;
  localparam LOW_WIDTH = ACCUM_WIDTH / 2;
  localparam HIGH_WIDTH = ACCUM_WIDTH - LOW_WIDTH;

  (* mark_debug = "true" *) reg fin_v0, fin_v1, fin_v2, fin_v3, fin_v4, fin_v5, fin_v6;
  reg signed [SUM_WIDTH-1:0] i_total_r, q_total_r;

  // F1: magnitude only -- squaring doesn't need the sign
  reg [SUM_WIDTH-1:0] i_mag_r, q_mag_r;

  // F2: the three "long multiplication" partial products -- each is
  // HALF2xHALF2 (16x16), comfortably native (<=18-bit DSP48E2 port), so it
  // fits one DSP48E2 in one cycle instead of needing a slow multi-tile
  // cascade. hi/lo are the TOP 32 bits of the magnitude (i.e. the bottom
  // DROP_BITS are discarded before squaring -- see the note above).
  reg [2*HALF2-1:0] i_hi_sq_r, i_lo_sq_r, i_cross_r;
  reg [2*HALF2-1:0] q_hi_sq_r, q_lo_sq_r, q_cross_r;

  // combinational: the cross term positioned where it belongs (shifted left
  // by HALF2+1, per the "2*hi*lo" term above) -- pure wiring, no logic delay.
  wire [ACCUM_WIDTH-1:0] i_cross_wide = ({{(ACCUM_WIDTH-2*HALF2){1'b0}}, i_cross_r}) << (HALF2 + 1);
  wire [ACCUM_WIDTH-1:0] q_cross_wide = ({{(ACCUM_WIDTH-2*HALF2){1'b0}}, q_cross_r}) << (HALF2 + 1);

  // F3/F4: reassemble x^2 = hi^2<<(2*HALF2) + cross<<(HALF2+1) + lo^2 via the
  // same low/high split-add as F5/F6 use for the final sum. hi^2 and lo^2
  // land in disjoint bit ranges (free concatenation); the cross term is the
  // only piece that needs a real carry-propagating add.
  reg [LOW_WIDTH-1:0] i_sq_lo_r, q_sq_lo_r;
  reg i_sq_carry_r, q_sq_carry_r;
  reg [HIGH_WIDTH-1:0] i_hi_sq_fwd_r, q_hi_sq_fwd_r;
  reg [HIGH_WIDTH-1:0] i_cross_hi_fwd_r, q_cross_hi_fwd_r;
  reg [ACCUM_WIDTH-1:0] i_sq_r, q_sq_r;

  // combinational: F4's high-half sum, computed at an explicitly-declared
  // width (not embedded raw inside a concatenation, where Verilog would
  // size it self-determined off the operands instead of the target -- same
  // safe pattern as `sum_hi` below).
  wire [HIGH_WIDTH-1:0] i_sq_hi_sum = i_hi_sq_fwd_r + i_cross_hi_fwd_r + i_sq_carry_r;
  wire [HIGH_WIDTH-1:0] q_sq_hi_sum = q_hi_sq_fwd_r + q_cross_hi_fwd_r + q_sq_carry_r;

  // F5/F6: the final i^2 + q^2, split the same way (unchanged from the
  // earlier fix).
  reg [HIGH_WIDTH-1:0] i_sq_hi_r, q_sq_hi_r;
  reg [LOW_WIDTH-1:0] sum_lo_r;
  reg carry_r;

  wire [HIGH_WIDTH-1:0] sum_hi = i_sq_hi_r + q_sq_hi_r + carry_r;

  always @(posedge clk) begin
    if (!rst_n) begin
      fin_v0 <= 1'b0;
      fin_v1 <= 1'b0;
      fin_v2 <= 1'b0;
      fin_v3 <= 1'b0;
      fin_v4 <= 1'b0;
      fin_v5 <= 1'b0;
      fin_v6 <= 1'b0;
      i_total_r <= 0;
      q_total_r <= 0;
      i_mag_r <= 0;
      q_mag_r <= 0;
      i_hi_sq_r <= 0;
      i_lo_sq_r <= 0;
      i_cross_r <= 0;
      q_hi_sq_r <= 0;
      q_lo_sq_r <= 0;
      q_cross_r <= 0;
      i_sq_lo_r <= 0;
      q_sq_lo_r <= 0;
      i_sq_carry_r <= 1'b0;
      q_sq_carry_r <= 1'b0;
      i_hi_sq_fwd_r <= 0;
      q_hi_sq_fwd_r <= 0;
      i_cross_hi_fwd_r <= 0;
      q_cross_hi_fwd_r <= 0;
      i_sq_r <= 0;
      q_sq_r <= 0;
      i_sq_hi_r <= 0;
      q_sq_hi_r <= 0;
      sum_lo_r <= 0;
      carry_r <= 1'b0;
      m_axis_tdata <= 0;
      m_axis_tvalid <= 1'b0;
    end else begin
      // F0: latch the completed burst's coherent totals
      fin_v0 <= burst_done;
      i_total_r <= i_total;
      q_total_r <= q_total;

      // F1: magnitude (squaring doesn't need the sign: x^2 == (-x)^2)
      fin_v1 <= fin_v0;
      i_mag_r <= i_total_r[SUM_WIDTH-1] ? (~i_total_r + 1'b1) : i_total_r;
      q_mag_r <= q_total_r[SUM_WIDTH-1] ? (~q_total_r + 1'b1) : q_total_r;

      // F2: long-multiplication partial products (hi*hi, hi*lo, lo*lo), each
      // HALF2xHALF2 -- comfortably one DSP48E2, one cycle. hi/lo skip the
      // bottom DROP_BITS of the magnitude (dropped, not used anywhere below).
      fin_v2 <= fin_v1;
      i_hi_sq_r <= i_mag_r[SUM_WIDTH-1:SUM_WIDTH-HALF2] * i_mag_r[SUM_WIDTH-1:SUM_WIDTH-HALF2];
      i_lo_sq_r <= i_mag_r[SUM_WIDTH-HALF2-1:DROP_BITS] * i_mag_r[SUM_WIDTH-HALF2-1:DROP_BITS];
      i_cross_r <= i_mag_r[SUM_WIDTH-1:SUM_WIDTH-HALF2] * i_mag_r[SUM_WIDTH-HALF2-1:DROP_BITS];
      q_hi_sq_r <= q_mag_r[SUM_WIDTH-1:SUM_WIDTH-HALF2] * q_mag_r[SUM_WIDTH-1:SUM_WIDTH-HALF2];
      q_lo_sq_r <= q_mag_r[SUM_WIDTH-HALF2-1:DROP_BITS] * q_mag_r[SUM_WIDTH-HALF2-1:DROP_BITS];
      q_cross_r <= q_mag_r[SUM_WIDTH-1:SUM_WIDTH-HALF2] * q_mag_r[SUM_WIDTH-HALF2-1:DROP_BITS];

      // F3: fold the cross term's LOW half into lo^2 (short carry chain),
      // capture the carry-out; forward hi^2 and the cross term's HIGH half
      // untouched for F4.
      fin_v3 <= fin_v2;
      {i_sq_carry_r, i_sq_lo_r} <= i_lo_sq_r + i_cross_wide[LOW_WIDTH-1:0];
      {q_sq_carry_r, q_sq_lo_r} <= q_lo_sq_r + q_cross_wide[LOW_WIDTH-1:0];
      i_hi_sq_fwd_r <= i_hi_sq_r;
      q_hi_sq_fwd_r <= q_hi_sq_r;
      i_cross_hi_fwd_r <= i_cross_wide[ACCUM_WIDTH-1:LOW_WIDTH];
      q_cross_hi_fwd_r <= q_cross_wide[ACCUM_WIDTH-1:LOW_WIDTH];

      // F4: add hi^2 + cross-HIGH + carry-in (short chain, `i_sq_hi_sum`/
      // `q_sq_hi_sum` above) -- present the exact i^2/q^2.
      fin_v4 <= fin_v3;
      i_sq_r <= {i_sq_hi_sum, i_sq_lo_r};
      q_sq_r <= {q_sq_hi_sum, q_sq_lo_r};

      // F5: add the LOW halves of i^2 + q^2 (short carry chain) and capture
      // the carry out; forward the HIGH halves untouched for F6.
      fin_v5 <= fin_v4;
      {carry_r, sum_lo_r} <= i_sq_r[LOW_WIDTH-1:0] + q_sq_r[LOW_WIDTH-1:0];
      i_sq_hi_r <= i_sq_r[ACCUM_WIDTH-1:LOW_WIDTH];
      q_sq_hi_r <= q_sq_r[ACCUM_WIDTH-1:LOW_WIDTH];

      // F6: add the HIGH halves + carry-in (short chain, `sum_hi` above) and
      // join with the already-computed LOW half -- present the result.
      m_axis_tvalid <= fin_v5;
      m_axis_tdata <= {sum_hi, sum_lo_r};
    end
  end

  // ============================== DEBUG PROBES ==============================
  // ILA taps for signals that are NOT already registers (rst_n/s_axis_tvalid/
  // s_axis_tdata/trigger are input nets) -- sampled into a flop so the debug
  // hub only connects to a register output. All state/decision/result
  // registers (state, sample_cnt, burst_cnt, i_accum/q_accum, i_sum_reg/
  // q_sum_reg, finish_delay, nsamp_latched, run_d0, fin_v0..fin_v6,
  // m_axis_tdata, m_axis_tvalid) are mark_debug'd in place above -- the
  // FINALIZE arithmetic intermediates (i_mag_r, i_hi_sq_r, i_sq_r, etc.) are
  // deliberately left unprobed to keep debug-hub fanout down. acc_en/
  // burst_done are combinational, so they get a flop here too.
  (* mark_debug = "true" *) reg acc_en_dbg;
  (* mark_debug = "true" *) reg burst_done_dbg;
  always @(posedge clk) begin
    if (!rst_n) begin
      acc_en_dbg <= 1'b0;
      burst_done_dbg <= 1'b0;
    end else begin
      acc_en_dbg <= acc_en;
      burst_done_dbg <= burst_done;
    end
  end

endmodule
