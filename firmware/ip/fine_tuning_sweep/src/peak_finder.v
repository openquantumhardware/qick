`timescale 1ns / 1ps

module peak_finder #(
  parameter ACCUM_WIDTH = 52
)(
  input wire clk,
  input wire rstn,

  // OP1: latch config + begin the sweep
  input wire start,
  input wire [31:0] start_freq,   // freq_word (pinc) of point 0
  input wire [31:0] step,         // per-point increment
  input wire [31:0] n_points,     // point-count budget

  // OP3: clear running max while idle (optional; OP1 also clears)
  input wire reset_max,

  // averaged power for the current point (from amplitude_calculator via CDC)
  input wire amp_valid,
  input wire [ACCUM_WIDTH-1:0] amp_data,

  // handshake to the tProc (wrapper latches these into sticky flags)
  output reg [31:0] freq_word,
  output reg freq_valid,
  output reg finish,

  // result (read back on OP2 via freq_word; max kept for the comparison)
  output reg [ACCUM_WIDTH-1:0] max_amplitude,
  output reg [31:0] freq_at_max
);

  localparam [1:0] IDLE = 2'd0, SEND_FREQ = 2'd1, WAIT_MEAS = 2'd2;

  (* mark_debug = "true" *) reg [1:0] state;
  reg [1:0] next_state;
  reg [31:0] cur_freq, cur_step, n_pts, point_idx;

  // registered last-point flag -- keeps the advance enable to flop outputs only
  reg last_point_r;

  // (1) STATE REGISTER -- synchronous reset
  always @(posedge clk) begin
    if (!rstn) 
      state <= IDLE;
    else
      state <= next_state;
  end

  // (2) NEXT-STATE LOGIC -- gated only by amp_valid and the flop output last_point_r.
  //     Every branch fully specified (else for every if).
  always @(*) begin
    case (state)
      IDLE:      
        next_state = start ? SEND_FREQ : IDLE;
      
      SEND_FREQ: 
        next_state = WAIT_MEAS;
      
      WAIT_MEAS: begin
        if (amp_valid) 
          next_state = last_point_r ? IDLE : SEND_FREQ;
        else
          next_state = WAIT_MEAS;
      end
      
      default:  
        next_state = IDLE;
    endcase
  end

  // (3) DATAPATH + REGISTERED OUTPUTS -- synchronous reset, CURRENT state.
  //     Fully explicit: every register is rewired (reg <= reg) on the paths
  //     that hold it, and every if has an else. The reset_max-while-IDLE clear
  //     is folded into the IDLE arm (start has priority, matching the original
  //     where the IDLE case-block ran after the pre-case clear -- both write 0).
  always @(posedge clk) begin
    if (!rstn) begin
      freq_word <= 32'd0;
      freq_valid <= 1'b0;
      finish <= 1'b0;
      max_amplitude <= {ACCUM_WIDTH{1'b0}};
      freq_at_max <= 32'd0;
      cur_freq <= 32'd0;
      cur_step <= 32'd0;
      n_pts <= 32'd0;
      point_idx <= 32'd0;
      last_point_r <= 1'b0;
    end else begin
      case (state)
      IDLE: begin
        freq_word <= freq_word;
        freq_valid <= 1'b0;
        finish <= 1'b0;
        if (start) begin
          cur_freq <= start_freq;
          cur_step <= step;
          n_pts <= n_points;
          point_idx <= 32'd0;
          last_point_r <= (32'd1 >= n_points);
          max_amplitude <= {ACCUM_WIDTH{1'b0}};
          freq_at_max <= 32'd0;
        end else if (reset_max) begin
          cur_freq <= cur_freq;
          cur_step <= cur_step;
          n_pts <= n_pts;
          point_idx <= point_idx;
          last_point_r <= last_point_r;
          max_amplitude <= {ACCUM_WIDTH{1'b0}};
          freq_at_max <= 32'd0;
        end else begin
          cur_freq <= cur_freq;
          cur_step <= cur_step;
          n_pts <= n_pts;
          point_idx <= point_idx;
          last_point_r <= last_point_r;
          max_amplitude <= max_amplitude;
          freq_at_max <= freq_at_max;
        end
      end

      SEND_FREQ: begin
        freq_word <= cur_freq;
        freq_valid <= 1'b1;
        finish <= 1'b0;
        max_amplitude <= max_amplitude;
        freq_at_max <= freq_at_max;
        cur_freq <= cur_freq;
        cur_step <= cur_step;
        n_pts <= n_pts;
        point_idx <= point_idx;
        last_point_r <= last_point_r;
      end

      WAIT_MEAS: begin
        freq_valid <= 1'b0;
        cur_step <= cur_step;
        n_pts <= n_pts;
        if (amp_valid) begin
          if (amp_data > max_amplitude) begin
            max_amplitude <= amp_data;
            freq_at_max <= cur_freq;
          end else begin
            max_amplitude <= max_amplitude;
            freq_at_max <= freq_at_max;
          end

          if (last_point_r) begin
            freq_word <= (amp_data > max_amplitude) ? cur_freq : freq_at_max;
            finish <= 1'b1;
            cur_freq <= cur_freq;
            point_idx <= point_idx;
            last_point_r <= last_point_r;
          end else begin
            freq_word <= freq_word;
            finish <= 1'b0;
            cur_freq <= cur_freq + cur_step;
            point_idx <= point_idx + 32'd1;
            last_point_r <= (point_idx + 32'd2 >= n_pts);
          end
        end else begin
          freq_word <= freq_word;
          finish <= 1'b0;
          max_amplitude <= max_amplitude;
          freq_at_max <= freq_at_max;
          cur_freq <= cur_freq;
          point_idx <= point_idx;
          last_point_r <= last_point_r;
        end
      end

      default: begin
        freq_word <= freq_word;
        freq_valid <= 1'b0;
        finish <= 1'b0;
        max_amplitude <= max_amplitude;
        freq_at_max <= freq_at_max;
        cur_freq <= cur_freq;
        cur_step <= cur_step;
        n_pts <= n_pts;
        point_idx <= point_idx;
        last_point_r <= last_point_r;
      end
      endcase
    end
  end

  // ============================== DEBUG PROBES ==============================
  // ILA taps for signals that are NOT already registers (rstn and amp_valid are
  // input nets) -- sampled into a flop so the debug hub only connects to a
  // register output. (state is already a register, mark_debug'd in place.)
  (* mark_debug = "true" *) reg rstn_dbg;
  (* mark_debug = "true" *) reg amp_valid_dbg;
  always @(posedge clk) begin
    if (!rstn) begin
      rstn_dbg <= 1'b0;
      amp_valid_dbg <= 1'b0;
    end else begin
      rstn_dbg <= rstn;
      amp_valid_dbg <= amp_valid;
    end
  end

endmodule
