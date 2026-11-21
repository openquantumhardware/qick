// Model against the real xpm_fifo_async, same stimulus, outputs compared on every clock of their own domain.
// Both are instantiated with the same parameters; the model is the renamed copy (run_vendor_check.sh).
// Configuration through -d macros: N B ADV SS WP RP (periods in ns, real numbers) WOFF.
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
`ifndef SS
 `define SS 2
`endif
`ifndef WP
 `define WP 10.0
`endif
`ifndef RP
 `define RP 7.3
`endif
`ifndef RUNNS
 `define RUNNS 400000
`endif
`ifndef MEMTYPE
 `define MEMTYPE "block"
`endif
module tb_vendor_cmp;
  localparam int N = `N, B = `B;
  real WP = `WP, RP = `RP;
  logic wclk = 0, rclk = 0;
  initial forever #(WP/2.0) wclk = ~wclk;
  initial forever #(RP/2.0 + 0.0) rclk = ~rclk;
  logic rst = 0, wr_en = 0, rd_en = 0; logic [B-1:0] din = 0;

  wire [B-1:0] dout_r, dout_m;
  wire full_r, empty_r, ovf_r, unf_r, dv_r, wb_r, rb_r;
  wire full_m, empty_m, ovf_m, unf_m, dv_m, wb_m, rb_m;

  `define PARAMS \
    .CDC_SYNC_STAGES(`SS), .DOUT_RESET_VALUE("0"), .ECC_MODE("no_ecc"), .FIFO_MEMORY_TYPE(`MEMTYPE), .FIFO_READ_LATENCY(0), \
    .FIFO_WRITE_DEPTH(N), .FULL_RESET_VALUE(0), .PROG_EMPTY_THRESH(5), .PROG_FULL_THRESH(N-5), .RD_DATA_COUNT_WIDTH($clog2(N)+1), \
    .READ_DATA_WIDTH(B), .READ_MODE("fwft"), .RELATED_CLOCKS(0), .USE_ADV_FEATURES(`ADV), .WAKEUP_TIME(0), .WRITE_DATA_WIDTH(B), \
    .WR_DATA_COUNT_WIDTH($clog2(N)+1)
  `define PORTS(sfx) \
    .sleep(1'b0), .rst(rst), .wr_clk(wclk), .wr_en(wr_en), .din(din), .full(full_``sfx), .prog_full(), .wr_data_count(), \
    .overflow(ovf_``sfx), .wr_rst_busy(wb_``sfx), .almost_full(), .wr_ack(), .rd_clk(rclk), .rd_en(rd_en), .dout(dout_``sfx), \
    .empty(empty_``sfx), .prog_empty(), .rd_data_count(), .underflow(unf_``sfx), .rd_rst_busy(rb_``sfx), .almost_empty(), \
    .data_valid(dv_``sfx), .injectsbiterr(1'b0), .injectdbiterr(1'b0), .sbiterr(), .dbiterr()

  xpm_fifo_async #(`PARAMS) u_real (`PORTS(r));
  emu_xpm_fifo_async #(`PARAMS) u_model (`PORTS(m));

  // Stimulus from local LFSRs (the same in every simulator), changed on the falling edge of each clock. Phases of
  // 400 write clocks change the write and read duty (percent); a reset of 1 to 3 write clocks comes about every
  // 700 write clocks (the reset sequence takes tens of clocks, writes and reads go on during it).
  logic [31:0] lw = 32'hACE1_2468, lr = 32'h1357_9BDF;
  function automatic logic [31:0] step(input logic [31:0] x);
    x ^= x << 13; x ^= x >> 17; x ^= x << 5; return x;
  endfunction
  int wcyc = 0, wduty = 50, rduty = 50, rstlen = 0, rcyc = 0;
  always @(negedge wclk) begin
    wcyc++;
    lw <= step(lw);
    case ((wcyc / 400) % 7)
      0: begin wduty = 50;  rduty = 50;  end
      1: begin wduty = 90;  rduty = 10;  end
      2: begin wduty = 10;  rduty = 90;  end
      3: begin wduty = 100; rduty = 0;   end
      4: begin wduty = 0;   rduty = 100; end
      5: begin wduty = 100; rduty = 100; end
      6: begin wduty = 70;  rduty = 70;  end
    endcase
    wr_en <= (lw[7:0] % 100) < wduty;
    din   <= B'({lw[31:0], lw[15:0] ^ 16'hA5A5, 8'(wcyc)});
    if (rstlen > 0) begin rstlen = rstlen - 1; rst <= 1'b1; end
    else begin
      rst <= 1'b0;
      if (wcyc == 120) begin rstlen = 1; rst <= 1'b1; end
      else if (wcyc > 400 && (lw[27:16] % 700) == 0) begin rstlen = lw[29:28] % 3; rst <= 1'b1; end
    end
  end
  always @(negedge rclk) begin
    rcyc++;
    lr <= step(lr);
    rd_en <= (lr[15:8] % 100) < rduty;
  end

  // glbl.v holds the global set/reset (GSR) for the first 100 ns, which forces the XPM synchronizers to
  // zero: the power-up reset sequence of the macro is stretched by it, and a write accepted before the first
  // reset leaves different data in the two. A reset at write clock 120 puts both in the same state; compare
  // from write clock 400, when that reset sequence is over in every configuration.
  logic cmp_on = 1'b0;
  always @(negedge wclk) if (wcyc == 400) cmp_on <= 1'b1;
  int errs = 0, nchkw = 0, nchkr = 0;
  `define CHK(sig, n) if (sig``_r !== sig``_m) begin errs++; if (errs < 12) $display("MISMATCH t=%0t %s real=%h model=%h", $time, `"sig`", sig``_r, sig``_m); end
  always @(posedge wclk) if (cmp_on) begin nchkw++; `CHK(full, w) `CHK(ovf, w) `CHK(wb, w) end
  always @(posedge rclk) if (cmp_on) begin nchkr++; `CHK(empty, r) `CHK(dout, r) `CHK(dv, r) `CHK(unf, r) `CHK(rb, r) end
  int nrst = 0, nfull = 0, nempty = 0, nwb = 0;
  always @(posedge wclk) begin if (rst) nrst++; if (full_r) nfull++; if (wb_r) nwb++; end
  always @(posedge rclk) if (empty_r) nempty++;

  initial begin
    #`RUNNS;
    $display("DONE nchk=%0d ERRCOUNT=%0d (resets %0d, full clocks %0d, empty clocks %0d, busy clocks %0d)", nchkw + nchkr, errs, nrst, nfull, nempty, nwb);
    $finish;
  end
endmodule
