`timescale 1ns/1ps
// readout_top_dynro (with the DDS and FIR models, or with the real DDS Compiler and FIR Compiler IP: run_vendor_check.sh
// simulates it twice) driven with two tones and one demodulation descriptor; the product (m0) and the decimated data (m1)
// of every clock go to trace.txt, which the script compares.
module tb_ro;
  localparam int N_DDS = 8;
  logic clk = 0; always #2.5 clk = ~clk;
  logic aresetn = 0;
  logic fifo_wr_en = 0; wire fifo_full; logic [87:0] fifo_din = 0;
  logic s_tvalid = 1; wire s_tready; logic [N_DDS*16-1:0] s_tdata = 0;
  wire m0_tvalid, m1_tvalid; wire [N_DDS*32-1:0] m0_tdata; wire [31:0] m1_tdata;
  readout_top_dynro #(.N_DDS(N_DDS)) dut (.aresetn(aresetn), .aclk(clk), .fifo_wr_en(fifo_wr_en), .fifo_full(fifo_full), .fifo_din(fifo_din),
    .s_axis_tvalid(s_tvalid), .s_axis_tready(s_tready), .s_axis_tdata(s_tdata),
    .m0_axis_tready(1'b1), .m0_axis_tvalid(m0_tvalid), .m0_axis_tdata(m0_tdata),
    .m1_axis_tready(1'b1), .m1_axis_tvalid(m1_tvalid), .m1_axis_tdata(m1_tdata));
  function automatic logic [87:0] descr(input logic [31:0] freq, input logic [31:0] phase, input logic [15:0] nsamp,
                                        input logic [1:0] outsel, input logic mode, input logic phrst);
    logic [87:0] d = '0; d[31:0] = freq; d[63:32] = phase; d[79:64] = nsamp; d[81:80] = outsel; d[82] = mode; d[83] = phrst; return d;
  endfunction
  int fd, cyc = 0; longint n = 0;
  initial fd = $fopen("trace.txt", "w");
  // input: a tone and a second tone, 8 samples per clock
  always @(negedge clk) begin
    for (int l = 0; l < 8; l++) begin
      real t, v;
      t = real'(n * 8 + l);
      v = 9000.0 * $cos(0.0123 * t) + 3000.0 * $cos(0.31 * t + 1.0);
      s_tdata[l*16 +: 16] = 16'(int'(v));
    end
    n++;
  end
  always @(posedge clk) begin
    cyc++;
    $fwrite(fd, "%0d %b %0d %0d %b", cyc, m1_tvalid, $signed(m1_tdata[15:0]), $signed(m1_tdata[31:16]), m0_tvalid);
    for (int l = 0; l < 8; l++) $fwrite(fd, " %0d %0d", $signed(m0_tdata[l*32 +: 16]), $signed(m0_tdata[l*32+16 +: 16]));
    $fwrite(fd, "\n");
  end
  initial begin
    repeat (10) @(posedge clk); aresetn = 1;
    repeat (80) @(posedge clk);
    @(negedge clk); fifo_din = descr(32'h0123_4567, 32'd0, 16'd3000, 2'd0, 1'b1, 1'b0); fifo_wr_en = 1;
    @(negedge clk); fifo_wr_en = 0;
    // a second descriptor, with another frequency and a phase reset, after the DDS has been accumulating: the DDS restarts
    // its accumulator on the reset flag of the new descriptor
    repeat (500) @(posedge clk);
    @(negedge clk); fifo_din = descr(32'h0765_4321, 32'h4000_0000, 16'd3000, 2'd0, 1'b1, 1'b1); fifo_wr_en = 1;
    @(negedge clk); fifo_wr_en = 0;
    repeat (900) @(posedge clk);
    $fclose(fd); $finish;
  end
endmodule
