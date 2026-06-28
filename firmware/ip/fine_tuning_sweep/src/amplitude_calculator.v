`timescale 1ns / 1ps
//------------------------------------------------------------------------------
// amplitude_calculator -- integrates |IQ|^2 over one measurement window and
// emits the accumulated power once per `averager_value` triggers.
//
// Completion is COUNT-based (avg_buffer model): the host sets `nsamp` to the
// readout's decimated window length, so the count is always reached. A trigger
// (re)arms a FRESH window in ANY state, so each measurement starts clean.
//
// Coding style -- three-process FSM for the IDLE/RUN control (state register /
// next-state comb / datapath), all synchronous reset. The IQ->square->sum
// pipeline (stages 0-2) is datapath: its exact register placement lets Vivado
// pack the squares into the DSP MREG and close 552 MHz.
//------------------------------------------------------------------------------

module amplitude_calculator #(
  parameter MAX_AVG = 64,
  parameter ACCUM_WIDTH = 52
)(
  input wire clk,
  input wire rst_n,

  input wire s_axis_tvalid,
  input wire [31:0] s_axis_tdata,

  input wire trigger,
  input wire [31:0] nsamp,
  input wire [$clog2(MAX_AVG)-1:0] averager_value,

  output reg [ACCUM_WIDTH-1:0] m_axis_tdata,
  output reg m_axis_tvalid
);

  // ------------------------------------------------------------------
  //  Stage 0 -- latch IQ so the DSP A/B input regs see stable data
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
  //  Stage 1 -- i*i and q*q. The single registered multiply puts ii_s1/qq_s1
  //  in the DSP MREG, so the 16x16 multiply is not combinational and the
  //  552 MHz clk_adc0_x2 domain closes. Do NOT pin ii_s1/qq_s1 in fabric --
  //  that forbids MREG absorption and forces multiply+ALU combinational.
  // ------------------------------------------------------------------
  (* use_dsp = "yes" *) reg [31:0] ii_s1, qq_s1;
  reg v_s1;

  always @(posedge clk) begin
    if (!rst_n) begin
      ii_s1 <= 0;
      qq_s1 <= 0;
      v_s1 <= 0;
    end else begin
      ii_s1 <= i_s0 * i_s0;
      qq_s1 <= q_s0 * q_s0;
      v_s1 <= v_s0;
    end
  end

  // ------------------------------------------------------------------
  //  Stage 2 -- i*i + q*q  (32-bit add, one CARRY8 chain)
  // ------------------------------------------------------------------
  reg [32:0] power_s2;
  reg v_s2;

  always @(posedge clk) begin
    if (!rst_n) begin
      power_s2 <= 0;
      v_s2 <= 0;
    end else begin
      power_s2 <= {1'b0, ii_s1} + {1'b0, qq_s1};
      v_s2 <= v_s1;
    end
  end

  // ------------------------------------------------------------------
  //  Control FSM + accumulator. run_d2 masks the 3-cycle pipeline warm-up so
  //  the accumulator only counts power_s2 samples that originated in RUN; the
  //  mask is flushed on every (re)trigger. (3 = i_s0 -> ii_s1 -> power_s2.)
  // ------------------------------------------------------------------
  localparam IDLE = 1'b0, RUN = 1'b1;
  (* mark_debug = "true" *) reg state;
  reg next_state;

  (* mark_debug = "true" *) reg [31:0] sample_cnt;
  reg [$clog2(MAX_AVG)-1:0] burst_cnt;
  reg [ACCUM_WIDTH-1:0] accumulator;
  reg [ACCUM_WIDTH-1:0] sum_reg;
  reg finish_delay;
  reg [31:0] nsamp_latched;

  reg run_d0, run_d1, run_d2;

  always @(posedge clk) begin
    if (!rst_n) begin
      run_d0 <= 0;
      run_d1 <= 0;
      run_d2 <= 0;
    end else if (trigger) begin
      run_d0 <= 0;
      run_d1 <= 0;
      run_d2 <= 0;
    end else begin
      run_d0 <= (state == RUN);
      run_d1 <= run_d0;
      run_d2 <= run_d1;
    end
  end

  wire acc_en = run_d2 & v_s2;
  wire emit_now = finish_delay;

  // (1) STATE REGISTER -- synchronous reset
  always @(posedge clk) begin
    if (!rst_n)
      state <= IDLE;
    else
      state <= next_state;
  end

  // (2) NEXT-STATE LOGIC -- a trigger (re)arms RUN from ANY state; absent a
  //     trigger, RUN returns to IDLE once the burst emits. Every branch is
  //     fully specified (else for every if) -- no reliance on a fall-through.
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

  // (3) DATAPATH + OUTPUT -- synchronous reset, driven by the CURRENT state.
  //     Fully explicit: every register is rewired (reg <= reg) on the paths
  //     that hold it, and every if has an else. The two original sequential
  //     ifs (acc_en then emit_now) are folded into an emit_now > acc_en
  //     priority chain -- emit_now's writes overrode acc_en's for the shared
  //     counters in the original, so the priority form is identical.
  always @(posedge clk) begin
    if (!rst_n) begin
      sample_cnt <= 0;
      burst_cnt <= 0;
      accumulator <= 0;
      sum_reg <= 0;
      m_axis_tvalid <= 0;
      m_axis_tdata <= 0;
      finish_delay <= 0;
      nsamp_latched <= 0;
    end else begin
      if (trigger) begin
        // (re)arm a fresh window; burst accumulator + output hold
        sample_cnt <= 0;
        accumulator <= 0;
        finish_delay <= 0;
        nsamp_latched <= nsamp;
        burst_cnt <= burst_cnt;
        sum_reg <= sum_reg;
        m_axis_tdata <= m_axis_tdata;
        m_axis_tvalid <= 0;
      end else begin
        case (state)
          RUN: begin
            if (emit_now) begin
              // window done: fold accumulator into sum, advance burst
              sample_cnt <= 0;
              accumulator <= 0;
              finish_delay <= 0;
              nsamp_latched <= nsamp_latched;
              if (burst_cnt + 1 >= averager_value) begin
                burst_cnt <= 0;
                sum_reg <= 0;
                m_axis_tdata <= sum_reg + accumulator;
                m_axis_tvalid <= 1;
              end else begin
                burst_cnt <= burst_cnt + 1;
                sum_reg <= sum_reg + accumulator;
                m_axis_tdata <= m_axis_tdata;
                m_axis_tvalid <= 0;
              end
            end else if (acc_en) begin
              // integrate one power sample into the window
              accumulator <= accumulator + power_s2;
              sample_cnt <= sample_cnt + 1;
              finish_delay <= (sample_cnt == nsamp_latched - 1) ? 1'b1 : finish_delay;
              nsamp_latched <= nsamp_latched;
              burst_cnt <= burst_cnt;
              sum_reg <= sum_reg;
              m_axis_tdata <= m_axis_tdata;
              m_axis_tvalid <= 0;
            end else begin
              // idle within the window: hold everything, pulse low
              accumulator <= accumulator;
              sample_cnt <= sample_cnt;
              finish_delay <= finish_delay;
              nsamp_latched <= nsamp_latched;
              burst_cnt <= burst_cnt;
              sum_reg <= sum_reg;
              m_axis_tdata <= m_axis_tdata;
              m_axis_tvalid <= 0;
            end
          end

          IDLE: begin
            // hold everything, pulse low
            sample_cnt <= sample_cnt;
            accumulator <= accumulator;
            finish_delay <= finish_delay;
            nsamp_latched <= nsamp_latched;
            burst_cnt <= burst_cnt;
            sum_reg <= sum_reg;
            m_axis_tdata <= m_axis_tdata;
            m_axis_tvalid <= 0;
          end

          default: begin
            // spurious state: hold everything, pulse low
            sample_cnt <= sample_cnt;
            accumulator <= accumulator;
            finish_delay <= finish_delay;
            nsamp_latched <= nsamp_latched;
            burst_cnt <= burst_cnt;
            sum_reg <= sum_reg;
            m_axis_tdata <= m_axis_tdata;
            m_axis_tvalid <= 0;
          end
        endcase
      end
    end
  end

endmodule
