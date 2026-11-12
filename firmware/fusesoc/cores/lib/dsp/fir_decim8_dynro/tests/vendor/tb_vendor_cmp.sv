// ============================================================================
// fir_decim8_dynro model (renamed fir_model by run_vendor_check.sh) against the real FIR Compiler 7.2 simulation
// model generated from fir_decim8_dynro.xci. Every clock: m_axis_data_tvalid, and m_axis_data_tdata when valid, must
// be equal. Scenarios: zero, DC, impulses, random full scale, random small, rounding ties, a tone, and the same
// with gaps in s_axis_data_tvalid.
// ============================================================================
`timescale 1ns/1ps
module tb_vendor_cmp;
  logic clk = 0; always #1.667 clk = ~clk;
  logic [255:0] din = 0; logic dv = 0;
  wire r_sr, m_sr, r_mv, m_mv; wire [31:0] r_md, m_md;
  fir_decim8_dynro real_i (.aclk(clk), .s_axis_data_tvalid(dv), .s_axis_data_tready(r_sr), .s_axis_data_tdata(din),
                           .m_axis_data_tvalid(r_mv), .m_axis_data_tdata(r_md));
  fir_model model_i (.aclk(clk), .s_axis_data_tvalid(dv), .s_axis_data_tready(m_sr), .s_axis_data_tdata(din),
                     .m_axis_data_tvalid(m_mv), .m_axis_data_tdata(m_md));
  string scen = "init";
  int err [string]; int nval = 0, shown = 0, cyc = 0;
  always @(posedge clk) cyc++;
  always @(negedge clk) begin
    if (r_mv !== m_mv) begin
      if (!err.exists(scen)) err[scen] = 0;
      err[scen]++;
      if (shown < 20) begin shown++; $display("MISMATCH %s cyc=%0d valid real=%b model=%b", scen, cyc, r_mv, m_mv); end
    end else if (r_mv && r_md !== m_md) begin
      if (!err.exists(scen)) err[scen] = 0;
      err[scen]++;
      if (shown < 20) begin shown++; $display("MISMATCH %s cyc=%0d real I=%0d Q=%0d model I=%0d Q=%0d", scen, cyc,
                                              $signed(r_md[15:0]), $signed(r_md[31:16]), $signed(m_md[15:0]), $signed(m_md[31:16])); end
    end
    if (r_mv) nval++;
    if (r_sr !== m_sr) begin if (!err.exists("ready")) err["ready"] = 0; err["ready"]++; end
  end
  logic [31:0] x = 32'hC0FFEE11;
  function automatic logic [31:0] rnd();
    x ^= x << 13; x ^= x >> 17; x ^= x << 5; return x;
  endfunction
  // one block: lane l = {imag, real}
  task automatic blk(input int mode, input int amp, input int gap);
    @(negedge clk);
    dv = (gap != 0 && (rnd() % 100) < gap) ? 1'b0 : 1'b1;
    for (int l = 0; l < 8; l++) begin
      int re, im;
      case (mode)
        0: begin re = 0; im = 0; end
        1: begin re = amp; im = -amp / 2; end                                               // DC
        2: begin re = (rnd() % (2 * amp + 1)) - amp; im = (rnd() % (2 * amp + 1)) - amp; end // random +-amp
        3: begin re = (rnd() % 2) ? 32767 : -32768; im = (rnd() % 2) ? 32767 : -32768; end   // full scale
        4: begin re = (rnd() % 3) - 1; im = (rnd() % 3) - 1; end                             // tiny: rounding ties
        5: begin re = amp * $cos(0.0 + 0.37 * (cyc * 8 + l)); im = amp * $sin(0.37 * (cyc * 8 + l)); end  // tone
        default: begin re = 0; im = 0; end
      endcase
      din[32*l +: 32] = {16'(im), 16'(re)};
    end
  endtask
  task automatic phase(input string name, input int n, input int mode, input int amp, input int gap);
    scen = name;
    repeat (n) blk(mode, amp, gap);
  endtask

  // ---- exact rounding ties -------------------------------------------------------------------------------------------
  // The coefficients of fir_decim8_dynro.coe, to build input windows whose dot product is EXACTLY an odd multiple of
  // 2^18, i.e. x.5 after the division by 2^19, where "round to zero" and "round half away" differ. Random inputs
  // almost never hit a tie. A window is built greedily (largest taps first, then a small fix with the taps of 13 and
  // -4) and checked here with the same integer arithmetic.
  localparam int H [120] = '{
    -56, -4, 13, 47, 97, 166, 252, 353, 463, 573,
    674, 754, 801, 804, 753, 643, 473, 249, -20, -314,
    -611, -885, -1107, -1248, -1285, -1201, -989, -651, -206, 318,
    878, 1425, 1903, 2254, 2428, 2383, 2094, 1556, 786, -172,
    -1251, -2364, -3408, -4271, -4839, -5010, -4696, -3838, -2410, -422,
    2076, 4993, 8205, 11560, 14889, 18012, 20758, 22971, 24523, 25322,
    25322, 24523, 22971, 20758, 18012, 14889, 11560, 8205, 4993, 2076,
    -422, -2410, -3838, -4696, -5010, -4839, -4271, -3408, -2364, -1251,
    -172, 786, 1556, 2094, 2383, 2428, 2254, 1903, 1425, 878,
    318, -206, -651, -989, -1201, -1285, -1248, -1107, -885, -611,
    -314, -20, 249, 473, 643, 753, 804, 801, 754, 674,
    573, 463, 353, 252, 166, 97, 47, 13, -4, -56
  };
  task automatic make_window(input longint target, output int xs [120]);
    longint r = target;
    int order [120];
    for (int k = 0; k < 120; k++) begin xs[k] = 0; order[k] = k; end
    for (int a = 0; a < 120; a++)           // selection sort by |H| descending
      for (int b = a + 1; b < 120; b++)
        if ((H[order[b]] < 0 ? -H[order[b]] : H[order[b]]) > (H[order[a]] < 0 ? -H[order[a]] : H[order[a]])) begin
          int t = order[a]; order[a] = order[b]; order[b] = t;
        end
    for (int i = 0; i < 120; i++) begin
      int k = order[i];
      longint q = r / longint'(H[k]);
      xs[k] += int'(q);
      r -= q * longint'(H[k]);
    end
    if (r != 0) begin                       // |r| < 4: 13 a - 4 b = r with the taps 2 (13) and 1 (-4)
      bit done = 0;
      for (int a = -8; a <= 8 && !done; a++)
        for (int b = -40; b <= 40 && !done; b++)
          if (13 * a - 4 * b == int'(r)) begin xs[2] += a; xs[1] += b; r = 0; done = 1; end
    end
    begin
      longint acc = 0;
      for (int k = 0; k < 120; k++) acc += longint'(H[k]) * longint'(xs[k]);
      if (acc != target) $fatal(1, "tie window not exact: %0d != %0d", acc, target);
    end
  endtask
  // stream the windows (I and Q targets) as 15 blocks, then zeros so that the next outputs see only this window
  task automatic tie_pair(input longint ti, input longint tq);
    int xi [120], xq [120];
    make_window(ti, xi); make_window(tq, xq);
    for (int b = 0; b < 15; b++) begin
      @(negedge clk); dv = 1;
      for (int l = 0; l < 8; l++) begin
        int k = 119 - (8 * b + l);          // sample 8b+l is tap 119-(8b+l) of the window that ends at the last block
        din[32*l +: 32] = {16'(xq[k]), 16'(xi[k])};
      end
    end
    repeat (20) begin @(negedge clk); dv = 1; din = 0; end
  endtask

  localparam int TIE_M [6] = '{0, 1, 2, 5, 17, 31};   // ties at 0.5, 1.5, 2.5, 5.5, 17.5, 31.5 of the output
  initial begin
    phase("zero", 40, 0, 0, 0);
    phase("dc", 200, 1, 8000, 0);
    phase("dc_neg_full", 200, 1, 32000, 0);
    phase("zero2", 150, 0, 0, 0);
    // impulses: one block with a single lane set, the rest zero
    for (int l = 0; l < 8; l++) begin
      scen = "impulse";
      @(negedge clk); dv = 1; din = 0; din[32*l +: 32] = {16'(-7000), 16'(9000)};
      repeat (140) begin @(negedge clk); dv = 1; din = 0; end
    end
    phase("rand_small", 400, 2, 300, 0);
    phase("rand_mid", 400, 2, 8000, 0);
    phase("rand_full", 400, 3, 0, 0);
    phase("ties", 600, 4, 0, 0);
    scen = "exact_ties";
    foreach (TIE_M[i]) begin
      tie_pair( (2 * TIE_M[i] + 1) * 262144,  (2 * TIE_M[i] + 1) * 262144);
      tie_pair(-(2 * TIE_M[i] + 1) * 262144,  (2 * TIE_M[i] + 1) * 262144);
      tie_pair( (2 * TIE_M[i] + 1) * 262144, -(2 * TIE_M[i] + 1) * 262144);
      tie_pair(-(2 * TIE_M[i] + 1) * 262144, -(2 * TIE_M[i] + 1) * 262144);
    end
    phase("tone", 400, 5, 20000, 0);
    phase("gaps_rand", 600, 2, 8000, 30);
    phase("gaps_dc", 300, 1, 5000, 50);
    phase("flush", 200, 0, 0, 0);
    $display("DONE nval=%0d", nval);
    foreach (err[k]) $display("ERRORS %s %0d", k, err[k]);
    if (err.size() == 0) $display("RESULT ERRCOUNT=0"); else $display("RESULT ERRCOUNT=%0d", err.size());
    $finish;
  end
endmodule
