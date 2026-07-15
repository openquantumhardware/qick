`timescale 1ns / 1ps

module fine_tuning_sweep (
  input wire clk,
  input wire rst_n,

  input wire qtag_en_i,
  input wire [4:0] qtag_op_i,
  input wire [31:0] qtag_dt1_i,
  input wire [31:0] qtag_dt2_i,
  input wire [31:0] qtag_dt3_i,
  input wire [31:0] qtag_dt4_i,
  (* mark_debug = "true" *) output reg qtag_rdy_o,
  (* mark_debug = "true" *) output reg [31:0] qtag_dt1_o,
  output reg [31:0] qtag_dt2_o,
  (* mark_debug = "true" *) output reg qtag_vld_o,

  input wire s_axis_tvalid,
  output wire s_axis_tready,
  input wire [63:0] s_axis_tdata
);

  assign s_axis_tready = 1'b1;

  reg en_d;
  wire en_rise = qtag_en_i & ~en_d;

  always @(posedge clk) begin
    if (!rst_n)
      en_d <= 1'b0;
    else
      en_d <= qtag_en_i;
  end

  wire start_now = en_rise & (qtag_op_i == 5'd1);

  (* mark_debug = "true" *) reg [31:0] reg_start;
  (* mark_debug = "true" *) reg [31:0] reg_step;
  (* mark_debug = "true" *) reg [31:0] reg_npoints;
  (* mark_debug = "true" *) reg [31:0] reg_avg;
  (* mark_debug = "true" *) reg [31:0] reg_nsamp;
  (* mark_debug = "true" *) reg reg_mode;

  wire [31:0] pf_freq_word;
  wire pf_freq_valid;
  wire pf_finish;
  wire [35:0] max_amplitude;
  wire [31:0] freq_at_max;

  always @(posedge clk) begin
    if (!rst_n) begin
      reg_start <= 32'd0;
      reg_step <= 32'd0;
      reg_npoints <= 32'd0;
      reg_avg <= 32'd0;
      reg_nsamp <= 32'd0;
      reg_mode <= 1'b0;
    end else if (en_rise & (qtag_op_i == 5'd0)) begin
      reg_start <= qtag_dt1_i;
      reg_step <= qtag_dt2_i;
      reg_npoints <= qtag_dt3_i;
      reg_avg <= qtag_dt4_i;
      reg_nsamp <= reg_nsamp;
      reg_mode <= reg_mode;
    end else if (en_rise & (qtag_op_i == 5'd2)) begin
      reg_start <= reg_start;
      reg_step <= reg_step;
      reg_npoints <= reg_npoints;
      reg_avg <= reg_avg;
      reg_nsamp <= qtag_dt1_i;
      reg_mode <= qtag_dt2_i[0];
    end else begin
      reg_start <= reg_start;
      reg_step <= reg_step;
      reg_npoints <= reg_npoints;
      reg_avg <= reg_avg;
      reg_nsamp <= reg_nsamp;
      reg_mode <= reg_mode;
    end
  end

  always @(posedge clk) begin
    if (!rst_n) begin
      qtag_dt1_o <= 32'd0;
      qtag_dt2_o <= 32'd0;
      qtag_vld_o <= 1'b0;
    end else if (start_now) begin
      qtag_dt1_o <= 32'd0;
      qtag_dt2_o <= 32'd0;
      qtag_vld_o <= 1'b0;
    end else if (pf_finish) begin
      qtag_dt1_o <= pf_freq_word;
      qtag_dt2_o <= 32'd0;
      qtag_vld_o <= 1'b1;
    end else begin
      qtag_dt1_o <= qtag_dt1_o;
      qtag_dt2_o <= qtag_dt2_o;
      qtag_vld_o <= qtag_vld_o;
    end
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

  wire [35:0] amp_data_c;
  wire amp_valid_c;

  amplitude_calculator u_amplitude_calculator (
    .clk            (clk),
    .rst_n          (rst_n),
    .s_axis_tvalid  (s_axis_tvalid),
    .s_axis_tready  (s_axis_tready),
    .s_axis_tdata   (s_axis_tdata),
    .arm            (point_arm),
    .averager_value (reg_avg),
    .nsamp          (reg_nsamp),
    .m_axis_tdata   (amp_data_c),
    .m_axis_tvalid  (amp_valid_c)
  );

  peak_finder u_peak_finder_v2 (
    .clk           (clk),
    .rstn          (rst_n),
    .start         (start_now),
    .start_freq    (reg_start),
    .step          (reg_step),
    .n_points      (reg_npoints),
    .mode          (reg_mode),
    .amp_valid     (amp_valid_c),
    .amp_data      (amp_data_c),
    .freq_word     (pf_freq_word),
    .freq_valid    (pf_freq_valid),
    .finish        (pf_finish),
    .max_amplitude (max_amplitude),
    .freq_at_max   (freq_at_max)
  );

  (* mark_debug = "true" *) reg s_axis_tvalid_dbg;
  (* mark_debug = "true" *) reg s_axis_tready_dbg;
  (* mark_debug = "true" *) reg [63:0] s_axis_tdata_dbg;
  (* mark_debug = "true" *) reg amp_valid_c_dbg;
  (* mark_debug = "true" *) reg [35:0] amp_data_c_dbg;
  (* mark_debug = "true" *) reg qtag_en_dbg;
  (* mark_debug = "true" *) reg [4:0] qtag_op_dbg;
  always @(posedge clk) begin
    if (!rst_n) begin
      s_axis_tvalid_dbg <= 1'b0;
      s_axis_tready_dbg <= 1'b0;
      s_axis_tdata_dbg <= 64'd0;
      amp_valid_c_dbg <= 1'b0;
      amp_data_c_dbg <= {36{1'b0}};
      qtag_en_dbg <= 1'b0;
      qtag_op_dbg <= 5'd0;
    end else begin
      s_axis_tvalid_dbg <= s_axis_tvalid;
      s_axis_tready_dbg <= s_axis_tready;
      s_axis_tdata_dbg <= s_axis_tdata;
      amp_valid_c_dbg <= amp_valid_c;
      amp_data_c_dbg <= amp_data_c;
      qtag_en_dbg <= qtag_en_i;
      qtag_op_dbg <= qtag_op_i;
    end
  end

endmodule
