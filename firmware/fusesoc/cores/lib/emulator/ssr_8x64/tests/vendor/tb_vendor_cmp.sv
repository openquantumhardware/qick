// Model against the real System Generator FFT (ssr_8x64, qick:dsp:ssr_fft_8x64), same frames on both:
// the latency, the valid pattern, the order of the bins and the size of the difference are measured.
// The real core is the VHDL entity ssr_8x64; the model is the renamed copy emu_ssr_8x64 (run_vendor_check.sh).
// Configuration through -d macros: SCALE (i_scale), GAPS (0: frames back to back, 1: random idle frames between),
// NFR (frames), SEED.
`timescale 1ns/1ps
`ifndef SCALE
 `define SCALE 0
`endif
`ifndef GAPS
 `define GAPS 0
`endif
`ifndef NFR
 `define NFR 120
`endif
`ifndef MAXERR
 `define MAXERR 64
`endif
`ifndef SEED
 `define SEED 32'h1234_5678
`endif
module tb_vendor_cmp;
  localparam real PI = 3.14159265358979323846;
  logic clk = 0; always #5 clk = ~clk;
  logic valid = 0; logic [5:0] scale = `SCALE;
  logic [15:0] re [8], im [8];
  wire [26:0] ore_r [8], oim_r [8], ore_m [8], oim_m [8];
  wire [0:0] ov_r; wire ov_m; wire [5:0] osc_r, osc_m;

  ssr_8x64 u_real (
    .clk(clk), .i_valid(valid), .i_scale(scale),
    .i_re_0(re[0]), .i_re_1(re[1]), .i_re_2(re[2]), .i_re_3(re[3]), .i_re_4(re[4]), .i_re_5(re[5]), .i_re_6(re[6]), .i_re_7(re[7]),
    .i_im_0(im[0]), .i_im_1(im[1]), .i_im_2(im[2]), .i_im_3(im[3]), .i_im_4(im[4]), .i_im_5(im[5]), .i_im_6(im[6]), .i_im_7(im[7]),
    .o_re_0(ore_r[0]), .o_re_1(ore_r[1]), .o_re_2(ore_r[2]), .o_re_3(ore_r[3]), .o_re_4(ore_r[4]), .o_re_5(ore_r[5]), .o_re_6(ore_r[6]), .o_re_7(ore_r[7]),
    .o_im_0(oim_r[0]), .o_im_1(oim_r[1]), .o_im_2(oim_r[2]), .o_im_3(oim_r[3]), .o_im_4(oim_r[4]), .o_im_5(oim_r[5]), .o_im_6(oim_r[6]), .o_im_7(oim_r[7]),
    .o_valid(ov_r), .o_scale(osc_r));
  emu_ssr_8x64 u_model (
    .clk(clk), .i_valid(valid), .i_scale(scale),
    .i_re_0(re[0]), .i_re_1(re[1]), .i_re_2(re[2]), .i_re_3(re[3]), .i_re_4(re[4]), .i_re_5(re[5]), .i_re_6(re[6]), .i_re_7(re[7]),
    .i_im_0(im[0]), .i_im_1(im[1]), .i_im_2(im[2]), .i_im_3(im[3]), .i_im_4(im[4]), .i_im_5(im[5]), .i_im_6(im[6]), .i_im_7(im[7]),
    .o_re_0(ore_m[0]), .o_re_1(ore_m[1]), .o_re_2(ore_m[2]), .o_re_3(ore_m[3]), .o_re_4(ore_m[4]), .o_re_5(ore_m[5]), .o_re_6(ore_m[6]), .o_re_7(ore_m[7]),
    .o_im_0(oim_m[0]), .o_im_1(oim_m[1]), .o_im_2(oim_m[2]), .o_im_3(oim_m[3]), .o_im_4(oim_m[4]), .o_im_5(oim_m[5]), .o_im_6(oim_m[6]), .o_im_7(oim_m[7]),
    .o_valid(ov_m), .o_scale(osc_m));

  int errcount = 0;
  int nv_r = 0, nv_m = 0, vmis = 0, ncmp = 0, n200 = 0, maxerr = 0, maxmag = 0, shown = 0;
  time t_first_r = 0, t_first_m = 0;

  // --- stimulus -------------------------------------------------------------
  logic [31:0] lfsr = `SEED;
  function automatic logic [31:0] step(input logic [31:0] x);
    x ^= x << 13; x ^= x >> 17; x ^= x << 5; return x;
  endfunction
  function automatic int sat16(input real x);
    if (x > 32767.0) return 32767; else if (x < -32768.0) return -32768; else return int'(x);
  endfunction

  real A1, A2, K1, K2; int kind, n0;
  function automatic void sample(input int n, output int sre, output int sim);
    real a, b;
    case (kind)
      0: begin a = A1 * $cos(2.0*PI*K1*n/64.0);  b = A1 * $sin(2.0*PI*K1*n/64.0); end              // tone on a bin or between
      1: begin a = A1 * $cos(2.0*PI*K1*n/64.0) + A2 * $cos(2.0*PI*K2*n/64.0);
               b = A1 * $sin(2.0*PI*K1*n/64.0) + A2 * $sin(2.0*PI*K2*n/64.0); end                    // two tones
      3: begin a = (n == n0) ? A1 : 0.0; b = (n == n0) ? -A1/2.0 : 0.0; end                           // impulse
      4: begin a = A1; b = -A2; end                                                                   // DC
      default: begin a = A1 * ((n % 16) - 8) / 8.0; b = 0.0; end                                      // ramp
    endcase
    sre = sat16(a); sim = sat16(b);
  endfunction

  task automatic send_frame();
    int sr[64], si[64];
    lfsr = step(lfsr); kind = lfsr[2:0] % 6;
    lfsr = step(lfsr); A1 = 500.0 + (lfsr[15:0] % 24000); A2 = 500.0 + (lfsr[31:16] % 8000);
    lfsr = step(lfsr); K1 = (lfsr[5:0] % 64) + ((lfsr[8:6] % 4 == 0) ? 0.37 : 0.0); K2 = lfsr[21:16] % 64;
    lfsr = step(lfsr); n0 = lfsr[5:0];
    for (int n = 0; n < 64; n++) begin
      if (kind == 2) begin lfsr = step(lfsr); sr[n] = int'(lfsr[15:0] % 16001) - 8000; lfsr = step(lfsr); si[n] = int'(lfsr[15:0] % 16001) - 8000; end
      else sample(n, sr[n], si[n]);
    end
    for (int c = 0; c < 8; c++) begin
      @(negedge clk);
      valid = 1'b1;
      for (int l = 0; l < 8; l++) begin re[l] = 16'(sr[c*8+l]); im[l] = 16'(si[c*8+l]); end
    end
  endtask
  task automatic idle(input int clks);
    repeat (clks) begin @(negedge clk); valid = 1'b0; for (int l = 0; l < 8; l++) begin re[l] = 16'h5A5A; im[l] = 16'h7777; end end
  endtask

  initial begin
    for (int l = 0; l < 8; l++) begin re[l] = 0; im[l] = 0; end
    idle(40);
    for (int f = 0; f < `NFR; f++) begin
      send_frame();
      if (`GAPS) begin lfsr = step(lfsr); if (lfsr[2:0] < 3) idle(8 * (1 + lfsr[4:3])); end
    end
    idle(400);
    $display("DONE frames=%0d nvalid_real=%0d nvalid_model=%0d valid_mismatch=%0d first_valid_real=%0t first_valid_model=%0t",
             `NFR, nv_r, nv_m, vmis, t_first_r, t_first_m);
    $display("ERRORS maxerr=%0d maxmag=%0d nsamp=%0d n_over_200=%0d scale=%0d gaps=%0d",
             maxerr, maxmag, ncmp, n200, `SCALE, `GAPS);
    // Pass: the same valid pattern and the same number of outputs, the difference at most MAXERR counts of the
    // 27-bit result (the model is real arithmetic, the core fixed point; 20 was the largest seen, 1.6e6 full scale).
    errcount = vmis + ((nv_r != nv_m) ? 1 : 0) + ((t_first_r != t_first_m) ? 1 : 0) + ((nv_r == 0) ? 1 : 0) + ((maxerr > `MAXERR) ? 1 : 0);
    $display("RESULT ERRCOUNT=%0d", errcount);
    $finish;
  end

  // --- comparison ---------------------------------------------------------------
  always @(posedge clk) begin
    if (ov_r[0]) begin nv_r++; if (t_first_r == 0) t_first_r = $time; end
    if (ov_m)    begin nv_m++; if (t_first_m == 0) t_first_m = $time; end
    if (ov_r[0] !== ov_m) begin vmis++; if (vmis <= 10) $display("VALID MISMATCH t=%0t real=%b model=%b", $time, ov_r, ov_m); end
    if (ov_r[0] && ov_m) begin
      for (int l = 0; l < 8; l++) begin
        int er, ei, d, mag;
        er = int'($signed(ore_r[l])) - int'($signed(ore_m[l]));
        ei = int'($signed(oim_r[l])) - int'($signed(oim_m[l]));
        d = (er < 0 ? -er : er) > (ei < 0 ? -ei : ei) ? (er < 0 ? -er : er) : (ei < 0 ? -ei : ei);
        mag = (int'($signed(ore_r[l])) < 0 ? -int'($signed(ore_r[l])) : int'($signed(ore_r[l])));
        if (maxerr < d) maxerr = d;
        if (maxmag < mag) maxmag = mag;
        ncmp++;
        if (d > 200) n200++;
        if (shown < 12 && d > 200) begin shown++; $display("DIFF t=%0t lane=%0d re real=%0d model=%0d  im real=%0d model=%0d", $time, l, $signed(ore_r[l]), $signed(ore_m[l]), $signed(oim_r[l]), $signed(oim_m[l])); end
      end
    end
  end
endmodule
