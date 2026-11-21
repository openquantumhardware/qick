// ============================================================================
// File: tb_vendor_cmp.sv
// Description: one fir_pfb_ro_<i> wrapper (fir_pfb_ro_model with that FIR's
//              coefficients) against the real FIR Compiler 7.2 simulation
//              model generated from its .xci (run_vendor_check.sh).
//   Every clock: m_axis tvalid, tlast and tdata (when valid), the four event
//   outputs and both treadys must be equal. Scenarios: no config (set 0),
//   config, misaligned tlast, random input gaps, reconfig, malformed config
//   packets (mid-vector, with gaps), rounding ties and full-scale inputs.
//   FIRMOD (the real core) and WRAPMOD (the wrapper, renamed so both can
//   coexist) are defines; the script passes them.
// ============================================================================
`timescale 1ns/1ps
module tb_vendor_cmp;
  logic clk = 0; always #1.667 clk = ~clk;
  logic s_valid = 0, s_last = 0; logic [31:0] s_data = 0;
  logic c_valid = 0, c_last = 0; logic [7:0] c_data = 0;
  logic r_mv, r_ml, r_miss, r_unexp, r_cmiss, r_cunexp, r_sr, r_cr; logic [31:0] r_md;
  logic m_mv, m_ml, m_miss, m_unexp, m_cmiss, m_cunexp, m_sr, m_cr; logic [31:0] m_md;
  `FIRMOD real_i (.aclk(clk),
    .s_axis_data_tvalid(s_valid), .s_axis_data_tready(r_sr), .s_axis_data_tlast(s_last), .s_axis_data_tdata(s_data),
    .s_axis_config_tvalid(c_valid), .s_axis_config_tready(r_cr), .s_axis_config_tlast(c_last), .s_axis_config_tdata(c_data),
    .m_axis_data_tvalid(r_mv), .m_axis_data_tlast(r_ml), .m_axis_data_tdata(r_md),
    .event_s_data_tlast_missing(r_miss), .event_s_data_tlast_unexpected(r_unexp),
    .event_s_config_tlast_missing(r_cmiss), .event_s_config_tlast_unexpected(r_cunexp));
  `WRAPMOD model_i (.aclk(clk),
    .s_axis_data_tvalid(s_valid), .s_axis_data_tready(m_sr), .s_axis_data_tlast(s_last), .s_axis_data_tdata(s_data),
    .s_axis_config_tvalid(c_valid), .s_axis_config_tready(m_cr), .s_axis_config_tlast(c_last), .s_axis_config_tdata(c_data),
    .m_axis_data_tvalid(m_mv), .m_axis_data_tlast(m_ml), .m_axis_data_tdata(m_md),
    .event_s_data_tlast_missing(m_miss), .event_s_data_tlast_unexpected(m_unexp),
    .event_s_config_tlast_missing(m_cmiss), .event_s_config_tlast_unexpected(m_cunexp));
  int cyc = 0; always @(posedge clk) cyc++;
  string scen = "init";
  int err [string]; int nval = 0; int shown = 0;
  task automatic bad(string what);
    if (!err.exists(scen)) err[scen] = 0;
    err[scen]++;
    if (shown < 40) begin shown++; $display("MISMATCH %s cyc=%0d %s real(v%0d l%0d I%0d Q%0d miss%0d unexp%0d sr%0d) model(v%0d l%0d I%0d Q%0d miss%0d unexp%0d sr%0d)", scen, cyc, what,
      r_mv, r_ml, $signed(r_md[15:0]), $signed(r_md[31:16]), r_miss, r_unexp, r_sr, m_mv, m_ml, $signed(m_md[15:0]), $signed(m_md[31:16]), m_miss, m_unexp, m_sr); end
  endtask
  always @(negedge clk) begin
    if (r_mv !== m_mv) bad("valid");
    else if (r_mv && (r_ml !== m_ml || r_md !== m_md)) bad("data/last");
    if (r_miss !== m_miss || r_unexp !== m_unexp) bad("event");
    if (r_cmiss !== m_cmiss || r_cunexp !== m_cunexp) bad("cfg_event");
    if (r_sr !== m_sr || r_cr !== m_cr) bad("ready");
    if (r_mv) nval++;
  end
  int ph = 0;   // tb's own channel phase for tlast
  task automatic word(input bit v, input int tlast_mode);  // 0 aligned (ch7), 1 none, 2 random
    @(posedge clk);
    s_valid <= v; s_data <= {$urandom} ;
    if (v) begin
      s_last <= (tlast_mode == 0) ? (ph == 7) : (tlast_mode == 2) ? ($urandom_range(7) == 0) : 1'b0;
      ph = (ph + 1) % 8;
    end else s_last <= $urandom_range(1);
  endtask
  task automatic config_pkt(input int base, input int bad_last = -1);
    for (int c = 0; c < 8; c++) begin @(posedge clk); c_valid <= 1; c_data <= (base + c) % 8; c_last <= (bad_last < 0) ? (c == 7) : (c == bad_last); end
    @(posedge clk); c_valid <= 0; c_last <= 0;
  endtask
  initial begin
    repeat (5) @(posedge clk);
    scen = "S4_noconfig"; for (int n = 0; n < 200; n++) word(1, 0);
    scen = "S1_config_aligned"; fork config_pkt(0); join_none
    for (int n = 0; n < 2000; n++) word(1, 0);
    scen = "S2_tlast_misaligned"; for (int n = 0; n < 1000; n++) word(1, 2);
    ph = (ph + 3) % 8; for (int n = 0; n < 500; n++) word(1, 0);
    scen = "S3_gaps"; for (int n = 0; n < 2000; n++) word($urandom_range(3) != 0, 0);
    scen = "S4_reconfig"; fork config_pkt(3); join_none for (int n = 0; n < 500; n++) word(1, 0);
    scen = "S5_bad_cfg_last"; fork config_pkt(0, 5); join_none for (int n = 0; n < 300; n++) word(1, 0);
    scen = "S5b_bad_cfg_midvector"; for (int n = 0; n < 3; n++) word(1, 0); fork config_pkt(0, 2); join_none for (int n = 0; n < 300; n++) word(1, 0);
    scen = "S5c_bad_cfg_gaps"; fork config_pkt(0, 6); join_none for (int n = 0; n < 300; n++) word($urandom_range(2) != 0, 0);
    scen = "S7_ties_extremes";
    for (int n = 0; n < 1600; n++) begin
      @(posedge clk); s_valid <= 1; s_last <= (ph == 7); ph = (ph + 1) % 8;
      case ($urandom_range(5))
        0: s_data <= {16'h7fff, 16'h8000};
        1: s_data <= {16'h8000, 16'h7fff};
        2: s_data <= {16'($urandom_range(3) * 16'h4000), 16'(-$urandom_range(3) * 16'h4000)};
        3: s_data <= {16'h0001 << $urandom_range(15), 16'hffff << $urandom_range(15)};
        default: s_data <= 32'h0;
      endcase
    end
    scen = "S6_tail"; @(posedge clk); s_valid <= 0; repeat (60) @(posedge clk);
    $display("DONE nval=%0d", nval);
    foreach (err[k]) $display("ERRCOUNT %s %0d", k, err[k]);
    $finish;
  end
endmodule
