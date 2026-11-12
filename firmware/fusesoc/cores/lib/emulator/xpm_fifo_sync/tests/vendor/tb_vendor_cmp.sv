// Model against the real xpm_fifo_sync, same stimulus, every output compared on every clock.
// Both are instantiated with the same parameters; the model is the renamed copy (run_vendor_check.sh).
// Configuration through -d macros: N B ADV PFT PET.
`timescale 1ns/1ps
`ifndef N
 `define N 16
`endif
`ifndef B
 `define B 16
`endif
`ifndef ADV
 `define ADV "1707"
`endif
`ifndef PFT
 `define PFT (`N-5)
`endif
`ifndef PET
 `define PET 5
`endif
module tb_vendor_cmp;
  localparam int N = `N, B = `B, CW = $clog2(N) + 1;
  logic clk = 0; always #5 clk = ~clk;
  logic rst = 0, wr_en = 0, rd_en = 0; logic [B-1:0] din = 0;

  wire [B-1:0] dout_r, dout_m; wire [CW-1:0] wdc_r, rdc_r, wdc_m, rdc_m;
  wire full_r, empty_r, pf_r, pe_r, ovf_r, unf_r, dv_r, wb_r, rb_r;
  wire full_m, empty_m, pf_m, pe_m, ovf_m, unf_m, dv_m, wb_m, rb_m;

  `define PARAMS \
    .DOUT_RESET_VALUE("0"), .ECC_MODE("no_ecc"), .FIFO_MEMORY_TYPE("auto"), .FIFO_READ_LATENCY(0), .FIFO_WRITE_DEPTH(N), \
    .FULL_RESET_VALUE(0), .PROG_EMPTY_THRESH(`PET), .PROG_FULL_THRESH(`PFT), .RD_DATA_COUNT_WIDTH(CW), .READ_DATA_WIDTH(B), \
    .READ_MODE("fwft"), .USE_ADV_FEATURES(`ADV), .WAKEUP_TIME(0), .WRITE_DATA_WIDTH(B), .WR_DATA_COUNT_WIDTH(CW)
  `define PORTS(sfx) \
    .sleep(1'b0), .rst(rst), .wr_clk(clk), .wr_en(wr_en), .din(din), .full(full_``sfx), .prog_full(pf_``sfx), \
    .wr_data_count(wdc_``sfx), .overflow(ovf_``sfx), .wr_rst_busy(wb_``sfx), .almost_full(), .wr_ack(), .rd_en(rd_en), \
    .dout(dout_``sfx), .empty(empty_``sfx), .prog_empty(pe_``sfx), .rd_data_count(rdc_``sfx), .underflow(unf_``sfx), \
    .rd_rst_busy(rb_``sfx), .almost_empty(), .data_valid(dv_``sfx), .injectsbiterr(1'b0), .injectdbiterr(1'b0), \
    .sbiterr(), .dbiterr()

  xpm_fifo_sync #(`PARAMS) u_real (`PORTS(r));
  emu_xpm_fifo_sync #(`PARAMS) u_model (`PORTS(m));

  // Stimulus from a local LFSR (the same in every simulator), changed on the falling edge. Phases of 600 clocks
  // change the write and read duty (percent) so that the FIFO fills, drains and stays in the middle; resets of
  // 1 to 3 clocks come at random, with writes and reads going on during them.
  logic [31:0] l = 32'hACE1_2468;
  function automatic logic [31:0] step(input logic [31:0] x);
    x ^= x << 13; x ^= x >> 17; x ^= x << 5; return x;
  endfunction
  int cyc = 0, wduty = 50, rduty = 50, rstlen = 0;
  always @(negedge clk) begin
    cyc++;
    l <= step(l);
    case ((cyc / 600) % 7)
      0: begin wduty = 50;  rduty = 50;  end
      1: begin wduty = 90;  rduty = 10;  end
      2: begin wduty = 10;  rduty = 90;  end
      3: begin wduty = 100; rduty = 0;   end
      4: begin wduty = 0;   rduty = 100; end
      5: begin wduty = 100; rduty = 100; end
      6: begin wduty = 70;  rduty = 70;  end
    endcase
    wr_en <= (l[7:0]   % 100) < wduty;
    rd_en <= (l[15:8]  % 100) < rduty;
    din   <= B'({l[31:0], l[15:0] ^ 16'hA5A5, 8'(cyc)});
    if (rstlen > 0) begin rstlen = rstlen - 1; rst <= 1'b1; end
    else begin
      rst <= 1'b0;
      if (cyc > 20 && (l[27:16] % 700) == 0) begin rstlen = l[29:28] % 3; rst <= 1'b1; end   // 1..3 clocks
    end
  end

  int errs = 0, nchk = 0;
  `define CHK(sig) if (sig``_r !== sig``_m) begin errs++; if (errs < 12) $display("MISMATCH t=%0t cyc=%0d %s real=%h model=%h", $time, cyc, `"sig`", sig``_r, sig``_m); end
  always @(posedge clk) if (cyc > 3) begin
    nchk++;
    `CHK(full) `CHK(empty) `CHK(dout) `CHK(dv) `CHK(ovf) `CHK(unf) `CHK(wb) `CHK(rb) `CHK(wdc) `CHK(rdc) `CHK(pf) `CHK(pe)
  end
  int nrst = 0, nfull = 0, nempty = 0;
  always @(posedge clk) begin if (rst) nrst++; if (full_r) nfull++; if (empty_r) nempty++; end

  initial begin
    #240000;
    $display("DONE nchk=%0d ERRCOUNT=%0d (resets %0d, full clocks %0d, empty clocks %0d)", nchk, errs, nrst, nfull, nempty);
    $finish;
  end
endmodule
