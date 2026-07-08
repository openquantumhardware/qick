`timescale 1ns / 1ps
//------------------------------------------------------------------------------
// fine_tuning_sweep -- single-clock autonomous sweep controller.
//
//   s_axis carries the avg_buffer m2 accumulated stream (one 64-bit {Q,I} word
//   per shot), brought into the core clock by an external axis_clock_converter,
//   so there is no internal CDC. amplitude_calculator sums averager_value shots
//   and squares (Karatsuba I^2+Q^2); peak_finder runs the sweep FSM + argmax.
//   Everything runs on clk.
//
// QP2 opcode map:
//   OP 0: dt1=start_freq dt3=step                  -- sweep config
//   OP 4: dt1=n_points   dt2=averager_value        -- sweep config (shots/point)
//   OP 1: (no data)                                -- start the sweep
//   OP 2: IP-> dt1=freq_word dt2={30'd0,freq_valid,finish}
//   OP 3: (no data)                                -- reset_max pulse
//------------------------------------------------------------------------------

module fine_tuning_sweep #(
  parameter ACC_WIDTH = 64
)(
  input wire clk,
  input wire rst_n,

  input wire qtag_en_i,
  input wire [4:0] qtag_op_i,
  input wire [31:0] qtag_dt1_i,
  input wire [31:0] qtag_dt2_i,
  input wire [31:0] qtag_dt3_i,
  input wire [31:0] qtag_dt4_i,
  output reg qtag_rdy_o,
  output reg [31:0] qtag_dt1_o,
  output reg [31:0] qtag_dt2_o,
  output reg qtag_vld_o,

  input wire trigger,

  input wire s_axis_aclk,
  input wire s_axis_aresetn,
  input wire s_axis_tvalid,
  input wire [63:0] s_axis_tdata
);

  localparam AMP_WIDTH = 2 * ACC_WIDTH;

  reg en_d;
  wire en_rise = qtag_en_i & ~en_d;

  always @(posedge clk) begin
    if (!rst_n)
      en_d <= 1'b0;
    else
      en_d <= qtag_en_i;
  end

  wire start_now = en_rise & (qtag_op_i == 5'd1);
  wire reset_max_now = en_rise & (qtag_op_i == 5'd3);
  wire op2_read = en_rise & (qtag_op_i == 5'd2);

  (* mark_debug = "true" *) reg [31:0] reg_start;
  (* mark_debug = "true" *) reg [31:0] reg_step;
  (* mark_debug = "true" *) reg [31:0] reg_npoints;
  (* mark_debug = "true" *) reg [31:0] reg_avg;

  wire [31:0] pf_freq_word;
  wire pf_freq_valid;
  wire pf_finish;
  wire [AMP_WIDTH-1:0] max_amplitude;
  wire [31:0] freq_at_max;

  (* mark_debug = "true" *) reg sticky_freq_valid;
  (* mark_debug = "true" *) reg sticky_finish;

  always @(posedge clk) begin
    if (!rst_n) begin
      qtag_vld_o <= 1'b0;
      qtag_dt1_o <= 32'd0;
      qtag_dt2_o <= 32'd0;
      reg_start <= 32'd0;
      reg_step <= 32'd0;
      reg_npoints <= 32'd0;
      reg_avg <= 32'd0;
    end else begin
      if (en_rise) begin
        case (qtag_op_i)
          5'd0: begin
            reg_start <= qtag_dt1_i;
            reg_step <= qtag_dt3_i;
            reg_npoints <= reg_npoints;
            reg_avg <= reg_avg;
            qtag_dt1_o <= qtag_dt1_o;
            qtag_dt2_o <= qtag_dt2_o;
            qtag_vld_o <= 1'b0;
          end

          5'd4: begin
            reg_start <= reg_start;
            reg_step <= reg_step;
            reg_npoints <= qtag_dt1_i;
            reg_avg <= qtag_dt2_i;
            qtag_dt1_o <= qtag_dt1_o;
            qtag_dt2_o <= qtag_dt2_o;
            qtag_vld_o <= 1'b0;
          end

          5'd1: begin
            reg_start <= reg_start;
            reg_step <= reg_step;
            reg_npoints <= reg_npoints;
            reg_avg <= reg_avg;
            qtag_dt1_o <= qtag_dt1_o;
            qtag_dt2_o <= qtag_dt2_o;
            qtag_vld_o <= 1'b0;
          end

          5'd2: begin
            reg_start <= reg_start;
            reg_step <= reg_step;
            reg_npoints <= reg_npoints;
            reg_avg <= reg_avg;
            qtag_dt1_o <= pf_freq_word;
            qtag_dt2_o <= {30'd0, sticky_freq_valid, sticky_finish};
            qtag_vld_o <= 1'b1;
          end

          5'd3: begin
            reg_start <= reg_start;
            reg_step <= reg_step;
            reg_npoints <= reg_npoints;
            reg_avg <= reg_avg;
            qtag_dt1_o <= qtag_dt1_o;
            qtag_dt2_o <= qtag_dt2_o;
            qtag_vld_o <= 1'b0;
          end

          default: begin
            reg_start <= reg_start;
            reg_step <= reg_step;
            reg_npoints <= reg_npoints;
            reg_avg <= reg_avg;
            qtag_dt1_o <= qtag_dt1_o;
            qtag_dt2_o <= qtag_dt2_o;
            qtag_vld_o <= 1'b0;
          end
        endcase
      end else begin
        reg_start <= reg_start;
        reg_step <= reg_step;
        reg_npoints <= reg_npoints;
        reg_avg <= reg_avg;
        qtag_dt1_o <= qtag_dt1_o;
        qtag_dt2_o <= qtag_dt2_o;
        qtag_vld_o <= 1'b0;
      end
    end
  end

  always @(posedge clk) begin
    if (!rst_n)
      sticky_freq_valid <= 1'b0;
    else if (pf_freq_valid)
      sticky_freq_valid <= 1'b1;
    else if (op2_read)
      sticky_freq_valid <= 1'b0;
    else
      sticky_freq_valid <= sticky_freq_valid;
  end

  always @(posedge clk) begin
    if (!rst_n)
      sticky_finish <= 1'b0;
    else if (pf_finish)
      sticky_finish <= 1'b1;
    else if (start_now)
      sticky_finish <= 1'b0;
    else
      sticky_finish <= sticky_finish;
  end

  always @(posedge clk) begin
    if (!rst_n)
      qtag_rdy_o <= 1'b1;
    else if (start_now)
      qtag_rdy_o <= 1'b0;
    else if (pf_finish)
      qtag_rdy_o <= 1'b1;
    else
      qtag_rdy_o <= qtag_rdy_o;
  end

  wire point_arm = start_now | pf_freq_valid;

  wire [AMP_WIDTH-1:0] amp_data_c;
  wire amp_valid_c;

  amplitude_calculator #(
    .ACC_WIDTH (ACC_WIDTH)
  ) u_amplitude_calculator (
    .clk            (clk),
    .rst_n          (rst_n),
    .s_axis_tvalid  (s_axis_tvalid),
    .s_axis_tdata   (s_axis_tdata),
    .arm            (point_arm),
    .averager_value (reg_avg),
    .m_axis_tdata   (amp_data_c),
    .m_axis_tvalid  (amp_valid_c)
  );

  peak_finder #(
    .ACCUM_WIDTH (AMP_WIDTH)
  ) u_peak_finder_v2 (
    .clk           (clk),
    .rstn          (rst_n),
    .start         (start_now),
    .start_freq    (reg_start),
    .step          (reg_step),
    .n_points      (reg_npoints),
    .reset_max     (reset_max_now),
    .amp_valid     (amp_valid_c),
    .amp_data      (amp_data_c),
    .freq_word     (pf_freq_word),
    .freq_valid    (pf_freq_valid),
    .finish        (pf_finish),
    .max_amplitude (max_amplitude),
    .freq_at_max   (freq_at_max)
  );

  (* mark_debug = "true" *) reg s_axis_tvalid_dbg;
  (* mark_debug = "true" *) reg [63:0] s_axis_tdata_dbg;
  (* mark_debug = "true" *) reg trigger_dbg;
  (* mark_debug = "true" *) reg amp_valid_c_dbg;
  (* mark_debug = "true" *) reg [AMP_WIDTH-1:0] amp_data_c_dbg;
  always @(posedge clk) begin
    if (!rst_n) begin
      s_axis_tvalid_dbg <= 1'b0;
      s_axis_tdata_dbg <= 64'd0;
      trigger_dbg <= 1'b0;
      amp_valid_c_dbg <= 1'b0;
      amp_data_c_dbg <= {AMP_WIDTH{1'b0}};
    end else begin
      s_axis_tvalid_dbg <= s_axis_tvalid;
      s_axis_tdata_dbg <= s_axis_tdata;
      trigger_dbg <= trigger;
      amp_valid_c_dbg <= amp_valid_c;
      amp_data_c_dbg <= amp_data_c;
    end
  end

endmodule
