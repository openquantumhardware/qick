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

  wire rst = ~rst_n;

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

  (* mark_debug = "true" *) reg [ACC_WIDTH-1:0] sq_in_i, sq_in_q;

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
          sq_in_i <= i_acc_next[ACC_WIDTH-1] ? (~i_acc_next + 1'b1) : i_acc_next;
          sq_in_q <= q_acc_next[ACC_WIDTH-1] ? (~q_acc_next + 1'b1) : q_acc_next;
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

  (* mark_debug = "true" *) reg [ACC_WIDTH-1:0] sq_in_q_d;

  always @(posedge clk) begin
    if (!rst_n)
      sq_in_q_d <= 0;
    else
      sq_in_q_d <= sq_in_q;
  end

  wire [15:0] il [0:3];
  wire [15:0] qld [0:3];

  assign il[0] = sq_in_i[15:0];
  assign il[1] = sq_in_i[31:16];
  assign il[2] = sq_in_i[47:32];
  assign il[3] = sq_in_i[63:48];

  assign qld[0] = sq_in_q_d[15:0];
  assign qld[1] = sq_in_q_d[31:16];
  assign qld[2] = sq_in_q_d[47:32];
  assign qld[3] = sq_in_q_d[63:48];

  wire [15:0] ia [0:9];
  wire [15:0] ib [0:9];
  wire [15:0] qa [0:9];
  wire [15:0] qb [0:9];

  assign ia[0] = il[0]; assign ib[0] = il[0];
  assign ia[1] = il[1]; assign ib[1] = il[1];
  assign ia[2] = il[2]; assign ib[2] = il[2];
  assign ia[3] = il[3]; assign ib[3] = il[3];
  assign ia[4] = il[0]; assign ib[4] = il[1];
  assign ia[5] = il[0]; assign ib[5] = il[2];
  assign ia[6] = il[0]; assign ib[6] = il[3];
  assign ia[7] = il[1]; assign ib[7] = il[2];
  assign ia[8] = il[1]; assign ib[8] = il[3];
  assign ia[9] = il[2]; assign ib[9] = il[3];

  assign qa[0] = qld[0]; assign qb[0] = qld[0];
  assign qa[1] = qld[1]; assign qb[1] = qld[1];
  assign qa[2] = qld[2]; assign qb[2] = qld[2];
  assign qa[3] = qld[3]; assign qb[3] = qld[3];
  assign qa[4] = qld[0]; assign qb[4] = qld[1];
  assign qa[5] = qld[0]; assign qb[5] = qld[2];
  assign qa[6] = qld[0]; assign qb[6] = qld[3];
  assign qa[7] = qld[1]; assign qb[7] = qld[2];
  assign qa[8] = qld[1]; assign qb[8] = qld[3];
  assign qa[9] = qld[2]; assign qb[9] = qld[3];

  wire [47:0] comb [0:9];

  genvar t;
  generate
    for (t = 0; t < 10; t = t + 1) begin : gpair
      wire [47:0] pc;

      DSP48E2 #(
        .A_INPUT("DIRECT"), .B_INPUT("DIRECT"),
        .USE_MULT("MULTIPLY"), .USE_SIMD("ONE48"), .USE_WIDEXOR("FALSE"),
        .XORSIMD("XOR24_48_96"),
        .AUTORESET_PATDET("NO_RESET"), .AUTORESET_PRIORITY("RESET"),
        .MASK(48'h3fffffffffff), .PATTERN(48'h000000000000),
        .SEL_MASK("MASK"), .SEL_PATTERN("PATTERN"), .USE_PATTERN_DETECT("NO_PATDET"),
        .RND(48'h000000000000),
        .AMULTSEL("A"), .BMULTSEL("B"), .PREADDINSEL("A"),
        .ACASCREG(0), .ADREG(0), .ALUMODEREG(1), .AREG(0),
        .BCASCREG(0), .BREG(0), .CARRYINREG(1), .CARRYINSELREG(1),
        .CREG(1), .DREG(0), .INMODEREG(1), .MREG(0), .OPMODEREG(1), .PREG(1),
        .IS_ALUMODE_INVERTED(4'b0000), .IS_CARRYIN_INVERTED(1'b0),
        .IS_CLK_INVERTED(1'b0), .IS_INMODE_INVERTED(5'b00000),
        .IS_OPMODE_INVERTED(9'b000000000), .IS_RSTALLCARRYIN_INVERTED(1'b0),
        .IS_RSTALUMODE_INVERTED(1'b0), .IS_RSTA_INVERTED(1'b0),
        .IS_RSTB_INVERTED(1'b0), .IS_RSTCTRL_INVERTED(1'b0),
        .IS_RSTC_INVERTED(1'b0), .IS_RSTD_INVERTED(1'b0),
        .IS_RSTINMODE_INVERTED(1'b0), .IS_RSTM_INVERTED(1'b0),
        .IS_RSTP_INVERTED(1'b0)
      ) dsp_a (
        .ACOUT(), .BCOUT(), .CARRYCASCOUT(), .MULTSIGNOUT(), .PCOUT(pc),
        .OVERFLOW(), .PATTERNBDETECT(), .PATTERNDETECT(), .UNDERFLOW(),
        .CARRYOUT(), .P(),
        .A({14'b0, ia[t]}), .ACIN(30'b0), .ALUMODE(4'b0000), .B({2'b0, ib[t]}),
        .BCIN(18'b0), .C(48'b0), .CARRYCASCIN(1'b0), .CARRYIN(1'b0),
        .CARRYINSEL(3'b000), .CLK(clk), .D(27'b0),
        .INMODE(5'b00000), .MULTSIGNIN(1'b0), .OPMODE(9'b000000101),
        .PCIN(48'b0),
        .CEA1(1'b1), .CEA2(1'b1), .CEAD(1'b1), .CEALUMODE(1'b1), .CEB1(1'b1),
        .CEB2(1'b1), .CEC(1'b1), .CECARRYIN(1'b1), .CECTRL(1'b1), .CED(1'b1),
        .CEINMODE(1'b1), .CEM(1'b1), .CEP(1'b1),
        .RSTA(rst), .RSTALLCARRYIN(rst), .RSTALUMODE(rst), .RSTB(rst), .RSTC(rst),
        .RSTCTRL(rst), .RSTD(rst), .RSTINMODE(rst), .RSTM(rst), .RSTP(rst)
      );

      DSP48E2 #(
        .A_INPUT("DIRECT"), .B_INPUT("DIRECT"),
        .USE_MULT("MULTIPLY"), .USE_SIMD("ONE48"), .USE_WIDEXOR("FALSE"),
        .XORSIMD("XOR24_48_96"),
        .AUTORESET_PATDET("NO_RESET"), .AUTORESET_PRIORITY("RESET"),
        .MASK(48'h3fffffffffff), .PATTERN(48'h000000000000),
        .SEL_MASK("MASK"), .SEL_PATTERN("PATTERN"), .USE_PATTERN_DETECT("NO_PATDET"),
        .RND(48'h000000000000),
        .AMULTSEL("A"), .BMULTSEL("B"), .PREADDINSEL("A"),
        .ACASCREG(0), .ADREG(0), .ALUMODEREG(1), .AREG(0),
        .BCASCREG(0), .BREG(0), .CARRYINREG(1), .CARRYINSELREG(1),
        .CREG(1), .DREG(0), .INMODEREG(1), .MREG(0), .OPMODEREG(1), .PREG(1),
        .IS_ALUMODE_INVERTED(4'b0000), .IS_CARRYIN_INVERTED(1'b0),
        .IS_CLK_INVERTED(1'b0), .IS_INMODE_INVERTED(5'b00000),
        .IS_OPMODE_INVERTED(9'b000000000), .IS_RSTALLCARRYIN_INVERTED(1'b0),
        .IS_RSTALUMODE_INVERTED(1'b0), .IS_RSTA_INVERTED(1'b0),
        .IS_RSTB_INVERTED(1'b0), .IS_RSTCTRL_INVERTED(1'b0),
        .IS_RSTC_INVERTED(1'b0), .IS_RSTD_INVERTED(1'b0),
        .IS_RSTINMODE_INVERTED(1'b0), .IS_RSTM_INVERTED(1'b0),
        .IS_RSTP_INVERTED(1'b0)
      ) dsp_b (
        .ACOUT(), .BCOUT(), .CARRYCASCOUT(), .MULTSIGNOUT(), .PCOUT(),
        .OVERFLOW(), .PATTERNBDETECT(), .PATTERNDETECT(), .UNDERFLOW(),
        .CARRYOUT(), .P(comb[t]),
        .A({14'b0, qa[t]}), .ACIN(30'b0), .ALUMODE(4'b0000), .B({2'b0, qb[t]}),
        .BCIN(18'b0), .C(48'b0), .CARRYCASCIN(1'b0), .CARRYIN(1'b0),
        .CARRYINSEL(3'b000), .CLK(clk), .D(27'b0),
        .INMODE(5'b00000), .MULTSIGNIN(1'b0), .OPMODE(9'b000010101),
        .PCIN(pc),
        .CEA1(1'b1), .CEA2(1'b1), .CEAD(1'b1), .CEALUMODE(1'b1), .CEB1(1'b1),
        .CEB2(1'b1), .CEC(1'b1), .CECARRYIN(1'b1), .CECTRL(1'b1), .CED(1'b1),
        .CEINMODE(1'b1), .CEM(1'b1), .CEP(1'b1),
        .RSTA(rst), .RSTALLCARRYIN(rst), .RSTALUMODE(rst), .RSTB(rst), .RSTC(rst),
        .RSTCTRL(rst), .RSTD(rst), .RSTINMODE(rst), .RSTM(rst), .RSTP(rst)
      );
    end
  endgenerate

  wire [AMP_WIDTH-1:0] term0 = {{(AMP_WIDTH-48){1'b0}}, comb[0]};
  wire [AMP_WIDTH-1:0] term1 = {{(AMP_WIDTH-48){1'b0}}, comb[1]} << 32;
  wire [AMP_WIDTH-1:0] term2 = {{(AMP_WIDTH-48){1'b0}}, comb[2]} << 64;
  wire [AMP_WIDTH-1:0] term3 = {{(AMP_WIDTH-48){1'b0}}, comb[3]} << 96;
  wire [AMP_WIDTH-1:0] term4 = {{(AMP_WIDTH-48){1'b0}}, comb[4]} << 17;
  wire [AMP_WIDTH-1:0] term5 = {{(AMP_WIDTH-48){1'b0}}, comb[5]} << 33;
  wire [AMP_WIDTH-1:0] term6 = {{(AMP_WIDTH-48){1'b0}}, comb[6]} << 49;
  wire [AMP_WIDTH-1:0] term7 = {{(AMP_WIDTH-48){1'b0}}, comb[7]} << 49;
  wire [AMP_WIDTH-1:0] term8 = {{(AMP_WIDTH-48){1'b0}}, comb[8]} << 65;
  wire [AMP_WIDTH-1:0] term9 = {{(AMP_WIDTH-48){1'b0}}, comb[9]} << 81;

  wire [AMP_WIDTH-1:0] grp0 = term0 + term1 + term2;
  wire [AMP_WIDTH-1:0] grp1 = term3 + term4 + term5;
  wire [AMP_WIDTH-1:0] grp2 = term6 + term7 + term8;
  wire [AMP_WIDTH-1:0] grp3 = term9;
  wire [AMP_WIDTH-1:0] lvl0 = grp0 + grp1 + grp2;
  wire [AMP_WIDTH-1:0] sum128 = lvl0 + grp3;

  (* mark_debug = "true" *) reg fin_v0, fin_v1, fin_v2;

  always @(posedge clk) begin
    if (!rst_n) begin
      fin_v0 <= 1'b0;
      fin_v1 <= 1'b0;
      fin_v2 <= 1'b0;
      m_axis_tdata <= 0;
      m_axis_tvalid <= 1'b0;
    end else begin
      fin_v0 <= emit_now;
      fin_v1 <= fin_v0;
      fin_v2 <= fin_v1;
      m_axis_tvalid <= fin_v2;
      m_axis_tdata <= sum128;
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
