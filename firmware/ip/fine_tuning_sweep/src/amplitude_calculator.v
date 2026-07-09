`timescale 1ns / 1ps

module amplitude_calculator #(
  parameter ACC_WIDTH = 64
)(
  input wire clk,
  input wire rst_n,

  input wire s_axis_tvalid,
  input wire s_axis_tready,
  input wire [63:0] s_axis_tdata,

  input wire arm,
  input wire [31:0] averager_value,

  (* mark_debug = "true" *) output reg [2*ACC_WIDTH-1:0] m_axis_tdata,
  (* mark_debug = "true" *) output reg m_axis_tvalid
);

  localparam AMP_WIDTH = 2 * ACC_WIDTH;
  localparam NLIMB = (ACC_WIDTH + 15) / 16;
  localparam MAG_WIDTH = 16 * NLIMB;

  integer pj, pk;
  integer sj, sk;

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
  (* mark_debug = "true" *) reg signed [ACC_WIDTH-1:0] i_acc, q_acc;

  wire signed [ACC_WIDTH-1:0] i_acc_next = i_acc + {{(ACC_WIDTH-32){i_in[31]}}, i_in};
  wire signed [ACC_WIDTH-1:0] q_acc_next = q_acc + {{(ACC_WIDTH-32){q_in[31]}}, q_in};

  wire acc_en = armed & v_in & r_in;
  wire is_last = (shot_cnt == avg_m1);
  wire emit_now = acc_en & is_last;

  (* mark_debug = "true" *) reg signed [ACC_WIDTH-1:0] sq_in_i, sq_in_q;

  always @(posedge clk) begin
    if (!rst_n) begin
      armed <= 1'b0;
      shot_cnt <= 32'd0;
      avg_m1 <= 32'd0;
      i_acc <= 0;
      q_acc <= 0;
      sq_in_i <= 0;
      sq_in_q <= 0;
    end else begin
      if (arm) begin
        armed <= 1'b1;
        shot_cnt <= 32'd0;
        avg_m1 <= (averager_value == 32'd0) ? 32'd0 : averager_value - 32'd1;
        i_acc <= 0;
        q_acc <= 0;
        sq_in_i <= sq_in_i;
        sq_in_q <= sq_in_q;
      end else if (acc_en) begin
        avg_m1 <= avg_m1;
        if (is_last) begin
          armed <= 1'b0;
          shot_cnt <= 32'd0;
          i_acc <= 0;
          q_acc <= 0;
          sq_in_i <= i_acc_next;
          sq_in_q <= q_acc_next;
        end else begin
          armed <= 1'b1;
          shot_cnt <= shot_cnt + 32'd1;
          i_acc <= i_acc_next;
          q_acc <= q_acc_next;
          sq_in_i <= sq_in_i;
          sq_in_q <= sq_in_q;
        end
      end else begin
        armed <= armed;
        shot_cnt <= shot_cnt;
        avg_m1 <= avg_m1;
        i_acc <= i_acc;
        q_acc <= q_acc;
        sq_in_i <= sq_in_i;
        sq_in_q <= sq_in_q;
      end
    end
  end

  (* mark_debug = "true" *) reg fin_v0, fin_v1, fin_v2, fin_v3, fin_v4;

  (* mark_debug = "true" *) reg [ACC_WIDTH-1:0] i_mag, q_mag;

  wire [MAG_WIDTH-1:0] i_mag_ext = i_mag;
  wire [MAG_WIDTH-1:0] q_mag_ext = q_mag;

  reg [31:0] i_diag [0:NLIMB-1];
  reg [31:0] q_diag [0:NLIMB-1];
  reg [31:0] i_prod [0:NLIMB-1][0:NLIMB-1];
  reg [31:0] q_prod [0:NLIMB-1][0:NLIMB-1];

  reg [AMP_WIDTH-1:0] i_squares_r, q_squares_r;
  reg [AMP_WIDTH-1:0] i_cross_r, q_cross_r;

  (* mark_debug = "true" *) reg [AMP_WIDTH-1:0] i_sq, q_sq;

  reg [AMP_WIDTH-1:0] i_squares_c, q_squares_c;
  reg [AMP_WIDTH-1:0] i_cross_c, q_cross_c;

  always @(*) begin
    i_squares_c = {AMP_WIDTH{1'b0}};
    q_squares_c = {AMP_WIDTH{1'b0}};
    i_cross_c = {AMP_WIDTH{1'b0}};
    q_cross_c = {AMP_WIDTH{1'b0}};
    for (sj = 0; sj < NLIMB; sj = sj + 1) begin
      i_squares_c = i_squares_c + ({{(AMP_WIDTH-32){1'b0}}, i_diag[sj]} << (32*sj));
      q_squares_c = q_squares_c + ({{(AMP_WIDTH-32){1'b0}}, q_diag[sj]} << (32*sj));
      for (sk = sj + 1; sk < NLIMB; sk = sk + 1) begin
        i_cross_c = i_cross_c + ({{(AMP_WIDTH-32){1'b0}}, i_prod[sj][sk]} << (16*(sj+sk)+1));
        q_cross_c = q_cross_c + ({{(AMP_WIDTH-32){1'b0}}, q_prod[sj][sk]} << (16*(sj+sk)+1));
      end
    end
  end

  always @(posedge clk) begin
    if (!rst_n) begin
      fin_v0 <= 1'b0;
      fin_v1 <= 1'b0;
      fin_v2 <= 1'b0;
      fin_v3 <= 1'b0;
      fin_v4 <= 1'b0;
      i_mag <= 0;
      q_mag <= 0;
      for (pj = 0; pj < NLIMB; pj = pj + 1) begin
        i_diag[pj] <= 32'd0;
        q_diag[pj] <= 32'd0;
        for (pk = 0; pk < NLIMB; pk = pk + 1) begin
          i_prod[pj][pk] <= 32'd0;
          q_prod[pj][pk] <= 32'd0;
        end
      end
      i_squares_r <= 0;
      q_squares_r <= 0;
      i_cross_r <= 0;
      q_cross_r <= 0;
      i_sq <= 0;
      q_sq <= 0;
      m_axis_tdata <= 0;
      m_axis_tvalid <= 1'b0;
    end else begin
      fin_v0 <= emit_now;
      i_mag <= sq_in_i[ACC_WIDTH-1] ? (~sq_in_i + 1'b1) : sq_in_i;
      q_mag <= sq_in_q[ACC_WIDTH-1] ? (~sq_in_q + 1'b1) : sq_in_q;

      fin_v1 <= fin_v0;
      for (pj = 0; pj < NLIMB; pj = pj + 1) begin
        i_diag[pj] <= i_mag_ext[16*pj +: 16] * i_mag_ext[16*pj +: 16];
        q_diag[pj] <= q_mag_ext[16*pj +: 16] * q_mag_ext[16*pj +: 16];
        for (pk = 0; pk < NLIMB; pk = pk + 1) begin
          if (pk > pj) begin
            i_prod[pj][pk] <= i_mag_ext[16*pj +: 16] * i_mag_ext[16*pk +: 16];
            q_prod[pj][pk] <= q_mag_ext[16*pj +: 16] * q_mag_ext[16*pk +: 16];
          end else begin
            i_prod[pj][pk] <= i_prod[pj][pk];
            q_prod[pj][pk] <= q_prod[pj][pk];
          end
        end
      end

      fin_v2 <= fin_v1;
      i_squares_r <= i_squares_c;
      q_squares_r <= q_squares_c;
      i_cross_r <= i_cross_c;
      q_cross_r <= q_cross_c;

      fin_v3 <= fin_v2;
      i_sq <= i_squares_r + i_cross_r;
      q_sq <= q_squares_r + q_cross_r;

      fin_v4 <= fin_v3;
      m_axis_tvalid <= fin_v4;
      m_axis_tdata <= i_sq + q_sq;
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
