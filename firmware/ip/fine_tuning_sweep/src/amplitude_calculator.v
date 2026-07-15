`timescale 1ns / 1ps

module amplitude_calculator (
  input wire clk,
  input wire rst_n,

  input wire s_axis_tvalid,
  input wire s_axis_tready,
  input wire [63:0] s_axis_tdata,

  input wire arm,
  input wire [31:0] averager_value,
  input wire [31:0] nsamp,

  (* mark_debug = "true" *) output reg [35:0] m_axis_tdata,
  (* mark_debug = "true" *) output reg m_axis_tvalid
);

  function [4:0] flog2;
    input [31:0] v;
    integer k;
    begin
      flog2 = 5'd0;
      for (k = 1; k <= 31; k = k + 1) begin
        if (v[k])
          flog2 = k[4:0];
      end
    end
  endfunction

  (* mark_debug = "true" *) reg signed [31:0] i_in, q_in;
  (* mark_debug = "true" *) reg v_in, r_in;

  always @(posedge clk) begin
    if (!rst_n) begin
      i_in <= 0;
      q_in <= 0;
      v_in <= 0;
      r_in <= 0;
    end else begin
      i_in <= s_axis_tdata[31:0];
      q_in <= s_axis_tdata[63:32];
      v_in <= s_axis_tvalid;
      r_in <= s_axis_tready;
    end
  end

  (* mark_debug = "true" *) reg armed;
  (* mark_debug = "true" *) reg [31:0] shot_cnt;
  (* mark_debug = "true" *) reg [31:0] avg_m1;
  (* mark_debug = "true" *) reg [4:0] s1_r, s2_r;
  (* mark_debug = "true" *) reg signed [45:0] i_acc, q_acc;
  (* mark_debug = "true" *) reg signed [17:0] point_mean_i, point_mean_q;

  wire signed [32:0] i_in_ext = {{1{i_in[31]}}, i_in};
  wire signed [32:0] q_in_ext = {{1{q_in[31]}}, q_in};
  wire signed [32:0] round1 = (s1_r == 5'd0) ? {33{1'b0}} : ({{32{1'b0}}, 1'b1} <<< (s1_r - 5'd1));
  wire signed [32:0] i_shifted1 = (i_in_ext + round1) >>> s1_r;
  wire signed [32:0] q_shifted1 = (q_in_ext + round1) >>> s1_r;
  wire signed [16:0] shot_mean_i = i_shifted1[16:0];
  wire signed [16:0] shot_mean_q = q_shifted1[16:0];

  wire signed [45:0] i_acc_next = i_acc + {{29{shot_mean_i[16]}}, shot_mean_i};
  wire signed [45:0] q_acc_next = q_acc + {{29{shot_mean_q[16]}}, shot_mean_q};

  wire acc_en = armed & v_in & r_in;
  wire is_last = (shot_cnt == avg_m1);
  wire emit_now = acc_en & is_last;

  wire signed [45:0] round2 = (s2_r == 5'd0) ? {46{1'b0}} : ({{45{1'b0}}, 1'b1} <<< (s2_r - 5'd1));
  wire signed [45:0] i_acc_round = i_acc_next + round2;
  wire signed [45:0] q_acc_round = q_acc_next + round2;
  wire signed [45:0] i_acc_shifted = i_acc_round >>> s2_r;
  wire signed [45:0] q_acc_shifted = q_acc_round >>> s2_r;
  wire signed [17:0] point_mean_i_next = i_acc_shifted[17:0];
  wire signed [17:0] point_mean_q_next = q_acc_shifted[17:0];

  always @(posedge clk) begin
    if (!rst_n) begin
      armed <= 1'b0;
      shot_cnt <= 32'd0;
      avg_m1 <= 32'd0;
      s1_r <= 5'd0;
      s2_r <= 5'd0;
      i_acc <= {46{1'b0}};
      q_acc <= {46{1'b0}};
      point_mean_i <= {18{1'b0}};
      point_mean_q <= {18{1'b0}};
    end else begin
      if (arm) begin
        armed <= 1'b1;
        shot_cnt <= 32'd0;
        avg_m1 <= (averager_value == 32'd0) ? 32'd0 : averager_value - 32'd1;
        s1_r <= flog2(nsamp);
        s2_r <= flog2(averager_value);
        i_acc <= {46{1'b0}};
        q_acc <= {46{1'b0}};
        point_mean_i <= point_mean_i;
        point_mean_q <= point_mean_q;
      end else if (acc_en) begin
        avg_m1 <= avg_m1;
        s1_r <= s1_r;
        s2_r <= s2_r;
        if (is_last) begin
          armed <= 1'b0;
          shot_cnt <= 32'd0;
          i_acc <= {46{1'b0}};
          q_acc <= {46{1'b0}};
          point_mean_i <= point_mean_i_next;
          point_mean_q <= point_mean_q_next;
        end else begin
          armed <= 1'b1;
          shot_cnt <= shot_cnt + 32'd1;
          i_acc <= i_acc_next;
          q_acc <= q_acc_next;
          point_mean_i <= point_mean_i;
          point_mean_q <= point_mean_q;
        end
      end else begin
        armed <= armed;
        shot_cnt <= shot_cnt;
        avg_m1 <= avg_m1;
        s1_r <= s1_r;
        s2_r <= s2_r;
        i_acc <= i_acc;
        q_acc <= q_acc;
        point_mean_i <= point_mean_i;
        point_mean_q <= point_mean_q;
      end
    end
  end

  (* mark_debug = "true" *) reg fin_v0, fin_v1, fin_v2;
  reg signed [17:0] sq_operand;
  (* mark_debug = "true" *) reg [35:0] power_acc;

  wire signed [35:0] point_mean_i_sq = point_mean_i * point_mean_i;
  wire signed [35:0] sq_operand_sq = sq_operand * sq_operand;

  always @(posedge clk) begin
    if (!rst_n) begin
      fin_v0 <= 1'b0;
      fin_v1 <= 1'b0;
      fin_v2 <= 1'b0;
      sq_operand <= {18{1'b0}};
      power_acc <= {36{1'b0}};
      m_axis_tdata <= {36{1'b0}};
      m_axis_tvalid <= 1'b0;
    end else begin
      fin_v0 <= emit_now;
      if (fin_v0) begin
        power_acc <= point_mean_i_sq;
        sq_operand <= point_mean_q;
      end else if (fin_v1) begin
        power_acc <= power_acc + sq_operand_sq;
        sq_operand <= sq_operand;
      end else begin
        power_acc <= power_acc;
        sq_operand <= sq_operand;
      end
      fin_v1 <= fin_v0;
      fin_v2 <= fin_v1;
      m_axis_tvalid <= fin_v2;
      m_axis_tdata <= power_acc;
    end
  end

  (* mark_debug = "true" *) reg s_axis_tvalid_dbg;
  (* mark_debug = "true" *) reg [63:0] s_axis_tdata_dbg;
  (* mark_debug = "true" *) reg arm_dbg;
  (* mark_debug = "true" *) reg acc_en_dbg;
  (* mark_debug = "true" *) reg emit_now_dbg;
  always @(posedge clk) begin
    if (!rst_n) begin
      s_axis_tvalid_dbg <= 1'b0;
      s_axis_tdata_dbg <= 64'd0;
      arm_dbg <= 1'b0;
      acc_en_dbg <= 1'b0;
      emit_now_dbg <= 1'b0;
    end else begin
      s_axis_tvalid_dbg <= s_axis_tvalid;
      s_axis_tdata_dbg <= s_axis_tdata;
      arm_dbg <= arm;
      acc_en_dbg <= acc_en;
      emit_now_dbg <= emit_now;
    end
  end

endmodule
