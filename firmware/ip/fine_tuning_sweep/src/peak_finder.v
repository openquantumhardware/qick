`timescale 1ns / 1ps

module peak_finder (
  input wire clk,
  input wire rstn,

  input wire start,
  input wire [31:0] start_freq,
  input wire [31:0] step,
  input wire [31:0] n_points,
  input wire mode,

  input wire amp_valid,
  input wire [35:0] amp_data,

  (* mark_debug = "true" *) output reg [31:0] freq_word,
  (* mark_debug = "true" *) output reg freq_valid,
  (* mark_debug = "true" *) output reg finish,

  (* mark_debug = "true" *) output reg [35:0] max_amplitude,
  (* mark_debug = "true" *) output reg [31:0] freq_at_max
);

  localparam [1:0] IDLE = 2'd0, SEND_FREQ = 2'd1, WAIT_MEAS = 2'd2;

  (* mark_debug = "true" *) reg [1:0] state;
  reg [1:0] next_state;
  (* mark_debug = "true" *) reg [31:0] cur_freq, cur_step, n_pts, point_idx;

  (* mark_debug = "true" *) reg last_point_r;
  (* mark_debug = "true" *) reg mode_r;

  wire is_better = mode_r ? (amp_data < max_amplitude) : (amp_data > max_amplitude);


  always @(posedge clk) begin
    if (!rstn) 
      state <= IDLE;
    else
      state <= next_state;
  end

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

  always @(posedge clk) begin
    if (!rstn) begin
      freq_word <= 32'd0;
      freq_valid <= 1'b0;
      finish <= 1'b0;
      max_amplitude <= {36{1'b0}};
      freq_at_max <= 32'd0;
      cur_freq <= 32'd0;
      cur_step <= 32'd0;
      n_pts <= 32'd0;
      point_idx <= 32'd0;
      last_point_r <= 1'b0;
      mode_r <= 1'b0;
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
          mode_r <= mode;
          max_amplitude <= mode ? {36{1'b1}} : {36{1'b0}};
          freq_at_max <= 32'd0;
        end else begin
          cur_freq <= cur_freq;
          cur_step <= cur_step;
          n_pts <= n_pts;
          point_idx <= point_idx;
          last_point_r <= last_point_r;
          mode_r <= mode_r;
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
        mode_r <= mode_r;
      end

      WAIT_MEAS: begin
        freq_valid <= 1'b0;
        cur_step <= cur_step;
        n_pts <= n_pts;
        mode_r <= mode_r;
        if (amp_valid) begin
          if (is_better) begin
            max_amplitude <= amp_data;
            freq_at_max <= cur_freq;
          end else begin
            max_amplitude <= max_amplitude;
            freq_at_max <= freq_at_max;
          end

          if (last_point_r) begin
            freq_word <= is_better ? cur_freq : freq_at_max;
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
        mode_r <= mode_r;
      end
      endcase
    end
  end

  (* mark_debug = "true" *) reg rstn_dbg;
  (* mark_debug = "true" *) reg start_dbg;
  always @(posedge clk) begin
    if (!rstn) begin
      rstn_dbg <= 1'b0;
      start_dbg <= 1'b0;
    end else begin
      rstn_dbg <= rstn;
      start_dbg <= start;
    end
  end

endmodule
