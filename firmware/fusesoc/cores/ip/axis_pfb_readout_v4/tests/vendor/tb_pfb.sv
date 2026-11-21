// axis_pfb_readout_v4 driven with two tones over AXI-Lite-configured outputs; every output of every clock of the recording
// window goes to trace.txt. run_vendor_check.sh simulates it with the models of the emulator and with the real IPs and compares.
`timescale 1ns/1ps
module tb_pfb;
  localparam real PI = 3.14159265358979323846;
  logic s_axi_aclk = 0, aclk = 0;
  always #5.0   s_axi_aclk = ~s_axi_aclk;      // 100 MHz
  always #1.667 aclk       = ~aclk;            // 300 MHz
  logic s_axi_aresetn = 1, aresetn = 1;

  logic [7:0] awaddr = 0; logic [2:0] awprot = 0; logic awvalid = 0; wire awready;
  logic [31:0] wdata = 0; logic [3:0] wstrb = 0; logic wvalid = 0; wire wready;
  wire [1:0] bresp; wire bvalid; logic bready = 0;
  logic [7:0] araddr = 0; logic [2:0] arprot = 0; logic arvalid = 0; wire arready;
  wire [31:0] rdata; wire [1:0] rresp; wire rvalid; logic rready = 0;

  logic s_tvalid = 0; logic [127:0] s_tdata = 0;
  wire [7:0] m_tvalid; wire [31:0] m_tdata [8];

  axis_pfb_readout_v4 dut (
    .s_axi_aclk(s_axi_aclk), .s_axi_aresetn(s_axi_aresetn),
    .s_axi_awaddr(awaddr), .s_axi_awprot(awprot), .s_axi_awvalid(awvalid), .s_axi_awready(awready),
    .s_axi_wdata(wdata), .s_axi_wstrb(wstrb), .s_axi_wvalid(wvalid), .s_axi_wready(wready),
    .s_axi_bresp(bresp), .s_axi_bvalid(bvalid), .s_axi_bready(bready),
    .s_axi_araddr(araddr), .s_axi_arprot(arprot), .s_axi_arvalid(arvalid), .s_axi_arready(arready),
    .s_axi_rdata(rdata), .s_axi_rresp(rresp), .s_axi_rvalid(rvalid), .s_axi_rready(rready),
    .aresetn(aresetn), .aclk(aclk), .s_axis_tvalid(s_tvalid), .s_axis_tdata(s_tdata),
    .m0_axis_tvalid(m_tvalid[0]), .m0_axis_tdata(m_tdata[0]), .m1_axis_tvalid(m_tvalid[1]), .m1_axis_tdata(m_tdata[1]),
    .m2_axis_tvalid(m_tvalid[2]), .m2_axis_tdata(m_tdata[2]), .m3_axis_tvalid(m_tvalid[3]), .m3_axis_tdata(m_tdata[3]),
    .m4_axis_tvalid(m_tvalid[4]), .m4_axis_tdata(m_tdata[4]), .m5_axis_tvalid(m_tvalid[5]), .m5_axis_tdata(m_tdata[5]),
    .m6_axis_tvalid(m_tvalid[6]), .m6_axis_tdata(m_tdata[6]), .m7_axis_tvalid(m_tvalid[7]), .m7_axis_tdata(m_tdata[7]));

  // AXI-Lite write: driven after a rising edge of s_axi_aclk, ready read on the falling edge.
  task automatic axi_wr(input logic [7:0] addr, input logic [31:0] data);
    bit aw_done = 0, w_done = 0;
    @(posedge s_axi_aclk);
    awaddr <= addr; awprot <= 3'b000; awvalid <= 1'b1; wdata <= data; wstrb <= 4'hf; wvalid <= 1'b1; bready <= 1'b1;
    while (!(aw_done && w_done)) begin
      @(negedge s_axi_aclk);
      if (awready) aw_done = 1; if (wready) w_done = 1;
      @(posedge s_axi_aclk);
      if (aw_done) awvalid <= 1'b0; if (w_done) wvalid <= 1'b0;
    end
    do @(negedge s_axi_aclk); while (!bvalid);
    @(posedge s_axi_aclk);
    bready <= 1'b0;
  endtask

  logic [31:0] lf = 32'hC0FFEE11;
  function automatic int noise();
    lf ^= lf << 13; lf ^= lf >> 17; lf ^= lf << 5;
    return int'(lf[15:0] % 401) - 200;
  endfunction

  // output i: PFB channel k, DDS offset d (fraction of the channel spacing), phase offset
  task automatic cfg_out(input int i, input int k, input real d, input logic [31:0] poff);
    longint pinc = longint'(d / 2.0 * 4294967296.0);
    axi_wr(8'(4 * i),        32'({8'(k % 8), 8'(k / 8)}));
    axi_wr(8'(8'h20 + 8 * i), pinc[31:0]);
    axi_wr(8'(8'h24 + 8 * i), poff);
  endtask

  real ph1 = 0.0, ph2 = 0.0;
  localparam real F1 = (37 + 0.3) / 64.0, F2 = (10 + 0.2) / 64.0;
  task automatic tones(input int nclk);
    for (int t = 0; t < nclk; t++) begin
      @(posedge aclk);
      s_tvalid <= 1'b1;
      for (int i = 0; i < 4; i++) begin
        s_tdata[i*32      +: 16] <= 16'($rtoi(3000.0 * $cos(ph1) + 2000.0 * $cos(ph2)) + noise());
        s_tdata[i*32 + 16 +: 16] <= 16'($rtoi(3000.0 * $sin(ph1) + 2000.0 * $sin(ph2)) + noise());
        ph1 += 2.0 * PI * F1; ph2 += 2.0 * PI * F2;
      end
    end
  endtask

  int fd, rec = 0, cyc = 0;
  initial fd = $fopen("trace.txt", "w");
  always @(negedge aclk) if (rec) begin
    cyc++;
    $fwrite(fd, "%0d", cyc);
    for (int i = 0; i < 8; i++) $fwrite(fd, " %b %0d %0d", m_tvalid[i], $signed(m_tdata[i][15:0]), $signed(m_tdata[i][31:16]));
    $fwrite(fd, "\n");
  end

  initial begin
    // a long reset: the channel mapping of a fresh start (a short one in the middle of a stream can move the channels)
    s_axi_aresetn = 0; aresetn = 0;
    repeat (100) @(posedge s_axi_aclk);
    s_axi_aresetn <= 1; aresetn <= 1;
    repeat (2) @(posedge s_axi_aclk);
    cfg_out(0, 37,  0.3, 32'h0000_0000);
    cfg_out(1, 10,  0.2, 32'h4000_0000);
    cfg_out(2, 37, -0.1, 32'h0000_0000);
    cfg_out(3, 10,  0.0, 32'h0000_0000);
    cfg_out(4,  0,  0.0, 32'h0000_0000);
    cfg_out(5, 37,  0.3, 32'h2000_0000);
    cfg_out(6, 63,  0.4, 32'h0000_0000);
    cfg_out(7, 20,  0.1, 32'h0000_0000);
    tones(1500);                  // settle
    rec = 1;
    tones(3000);
    rec = 0;
    repeat (50) @(posedge aclk);
    $fclose(fd);
    $display("DONE rows=%0d", cyc);
    $finish;
  end
endmodule
