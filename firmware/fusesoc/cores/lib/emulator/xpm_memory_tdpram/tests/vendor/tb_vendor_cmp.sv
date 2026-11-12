// Model against the real xpm_memory_tdpram, same stimulus, outputs compared on every clock of both
// ports. Both are instantiated with the same parameters; the model is the renamed copy
// (run_vendor_check.sh). Configuration through -d macros: LAT_A LAT_B WM_A WM_B COLS INIT REGCE_RAND.
`timescale 1ns/1ps
`ifndef LAT_A
 `define LAT_A 2
`endif
`ifndef LAT_B
 `define LAT_B 2
`endif
`ifndef WM_A
 `define WM_A "write_first"
`endif
`ifndef WM_B
 `define WM_B "write_first"
`endif
`ifndef COLS
 `define COLS 1
`endif
`ifndef INIT
 `define INIT "none"
`endif
`ifndef REGCE_RAND
 `define REGCE_RAND 0
`endif
module tb_vendor_cmp;
  localparam int BW = 8;                       // bits per column
  localparam int W = BW * `COLS;
  localparam int AW = 5;
  localparam int DEPTH = 1 << AW;

  logic clka = 0, clkb = 0;
  always #5.0  clka = ~clka;                   // 100 MHz
  always #3.65 clkb = ~clkb;                   // 137 MHz, edges never coincide with clka

  logic rsta = 0, ena = 0, regcea = 0, rstb = 0, enb = 0, regceb = 0;
  logic [`COLS-1:0] wea = 0, web = 0;
  logic [AW-1:0] addra = 0, addrb = 0;
  logic [W-1:0] dina = 0, dinb = 0;
  wire [W-1:0] douta_r, doutb_r, douta_m, doutb_m;

  `define PARAMS \
    .MEMORY_SIZE(DEPTH*W), .CLOCKING_MODE("independent_clock"), .MEMORY_INIT_FILE(`INIT), .MEMORY_INIT_PARAM("0"), \
    .MEMORY_PRIMITIVE("block"), .WRITE_DATA_WIDTH_A(W), .READ_DATA_WIDTH_A(W), .BYTE_WRITE_WIDTH_A(BW), .ADDR_WIDTH_A(AW), \
    .READ_LATENCY_A(`LAT_A), .WRITE_MODE_A(`WM_A), .RST_MODE_A("SYNC"), .WRITE_DATA_WIDTH_B(W), .READ_DATA_WIDTH_B(W), \
    .BYTE_WRITE_WIDTH_B(BW), .ADDR_WIDTH_B(AW), .READ_LATENCY_B(`LAT_B), .WRITE_MODE_B(`WM_B), .RST_MODE_B("SYNC"), \
    .READ_RESET_VALUE_A("0"), .READ_RESET_VALUE_B("0"), .USE_MEM_INIT(1), .SIM_ASSERT_CHK(0), .MESSAGE_CONTROL(0)
  `define PORTS(sfx) \
    .sleep(1'b0), .clka(clka), .rsta(rsta), .ena(ena), .regcea(regcea), .wea(wea), .addra(addra), .dina(dina), \
    .douta(douta_``sfx), .injectsbiterra(1'b0), .injectdbiterra(1'b0), .sbiterra(), .dbiterra(), \
    .clkb(clkb), .rstb(rstb), .enb(enb), .regceb(regceb), .web(web), .addrb(addrb), .dinb(dinb), \
    .doutb(doutb_``sfx), .injectsbiterrb(1'b0), .injectdbiterrb(1'b0), .sbiterrb(), .dbiterrb()

  xpm_memory_tdpram #(`PARAMS) u_real (`PORTS(r));
  emu_xpm_memory_tdpram #(`PARAMS) u_model (`PORTS(m));

  // Pseudo-random stimulus from a local LFSR (the same in every simulator), changed on the falling edge.
  // The macro reports X when the two ports touch the same address within the same window, so the
  // stimulus never does: in 1 us phases only one port works (phase 0: A, 1: B, 3: B again), or in
  // phase 2 both work, A on even and B on odd addresses; every phase has guard gaps at both ends.
  // The data written in one phase is read through the other port in the next one.
  logic [31:0] la = 32'hACE1_2468, lb = 32'h1357_9BDF;
  function automatic logic [31:0] step(input logic [31:0] x);
    x ^= x << 13; x ^= x >> 17; x ^= x << 5; return x;
  endfunction
  int ta, tb_, pha, phb;
  logic on_a, on_b;
  // Port A: sparse resets, enable mostly on, writes about 1/3 of the time. regce follows ena like in the
  // QICK cores unless REGCE_RAND (a random regce, never asserted together with rst: illegal in the macro).
  always @(negedge clka) begin
    ta = int'($time) % 1000; pha = (int'($time) / 1000) % 4;
    on_a = (ta >= 100 && ta < 900) && (pha == 0 || pha == 2);
    la <= step(la);
    rsta   <= (la[7:0] < 6);
    ena    <= on_a && (la[15:8] < 230);
    wea    <= (la[23:16] < 85) ? la[24 +: `COLS] : '0;
    addra  <= (pha == 2) ? {la[12:9] ^ la[19:16], 1'b0} : (la[12:8] ^ la[20:16]);
    dina   <= la[W-1:0];
    regcea <= `REGCE_RAND ? (la[27:24] < 12 && !(la[7:0] < 6)) : (on_a && la[15:8] < 230);
  end
  always @(negedge clkb) begin
    tb_ = int'($time) % 1000; phb = (int'($time) / 1000) % 4;
    on_b = (tb_ >= 100 && tb_ < 900) && (phb == 1 || phb == 2 || phb == 3);
    lb <= step(lb);
    rstb   <= (lb[7:0] < 6);
    enb    <= on_b && (lb[15:8] < 230);
    web    <= (lb[23:16] < 85) ? lb[24 +: `COLS] : '0;
    addrb  <= (phb == 2) ? {lb[12:9] ^ lb[19:16], 1'b1} : (lb[12:8] ^ lb[20:16]);
    dinb   <= lb[W-1:0] ^ 32'h5A5A_5A5A;
    regceb <= `REGCE_RAND ? (lb[27:24] < 12 && !(lb[7:0] < 6)) : (on_b && lb[15:8] < 230);
  end

  int errs = 0, nchk = 0;
  always @(posedge clka) if ($time > 30) begin   // compare just before every edge (the outputs are settled)
    nchk++;
    if (douta_r !== douta_m) begin errs++; if (errs < 10) $display("MISMATCH A t=%0t real=%h model=%h", $time, douta_r, douta_m); end
  end
  always @(posedge clkb) if ($time > 30) begin
    nchk++;
    if (doutb_r !== doutb_m) begin errs++; if (errs < 10) $display("MISMATCH B t=%0t real=%h model=%h", $time, doutb_r, doutb_m); end
  end

  initial begin
    #200000;
    $display("DONE nchk=%0d ERRCOUNT=%0d", nchk, errs);
    $finish;
  end
endmodule
