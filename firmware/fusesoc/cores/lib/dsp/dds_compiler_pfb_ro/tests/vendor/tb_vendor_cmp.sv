// ============================================================================
// File: tb_vendor_cmp.sv
// Description: dds_compiler_pfb_ro (the model wrapper, renamed _sim) against
//              the real DDS Compiler 6.0 generated from its .xci, driven the
//              way the PFB's dds_ctrl drives it: resync=1 on every word with
//              an absolute phase poff + pinc*n, 40 random (pinc, poff)
//              segments, every third one with random valid gaps.
//              Prints valid mismatches and the largest I/Q difference.
// ============================================================================
`timescale 1ns/1ps
module tb_vendor_cmp;
  logic clk = 0; always #1.667 clk = ~clk;
  logic v = 0; logic [71:0] d = 0;
  logic rv, mv; logic [31:0] rd, md;
  dds_compiler_pfb_ro real_i (.aclk(clk), .s_axis_phase_tvalid(v), .s_axis_phase_tdata(d), .m_axis_data_tvalid(rv), .m_axis_data_tdata(rd));
  dds_compiler_pfb_ro_sim model_i (.aclk(clk), .s_axis_phase_tvalid(v), .s_axis_phase_tdata(d), .m_axis_data_tvalid(mv), .m_axis_data_tdata(md));
  int vmis = 0, n = 0, emax = 0;
  always @(negedge clk) begin
    if (rv !== mv) vmis++;
    if (rv && mv) begin
      int ei, eq;
      ei = $signed(rd[15:0]) - $signed(md[15:0]); if (ei < 0) ei = -ei;
      eq = $signed(rd[31:16]) - $signed(md[31:16]); if (eq < 0) eq = -eq;
      if (ei > emax) emax = ei; if (eq > emax) emax = eq; n++;
    end
  end
  // dds_ctrl pattern: {7'b0, resync=1, poff_abs, pinc}, poff_abs = poff + pinc*cnt
  logic [31:0] pinc, poff, cnt = 0;
  initial begin
    repeat (5) @(posedge clk);
    for (int seg = 0; seg < 40; seg++) begin
      pinc = $urandom; poff = $urandom;
      for (int k = 0; k < 300; k++) begin
        @(posedge clk);
        v <= (seg % 3 == 2) ? ($urandom_range(3) != 0) : 1'b1;   // gaps in every third segment
        d <= {7'b0, 1'b1, poff + pinc * cnt, pinc};
        cnt++;
      end
    end
    @(posedge clk); v <= 0; repeat (30) @(posedge clk);
    $display("DDSCHK n=%0d valid_mismatch=%0d max_err=%0d", n, vmis, emax);
    $finish;
  end
endmodule
