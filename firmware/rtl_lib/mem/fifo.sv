module fifo #(
  parameter int B = 16,
  parameter int N = 4
)(
  input  logic             rstn,
  input  logic             clk,

  input  logic             wr_en,
  input  logic [B-1:0]     din,

  input  logic             rd_en,
  output logic [B-1:0]     dout,

  output logic             full,
  output logic             empty
);

  localparam int N_LOG2 = $clog2(N);

  logic [N_LOG2-1:0] wptr, rptr;

  logic              mem_wea;
  logic [B-1:0]      mem_dob;

  logic full_i, empty_i;

  // BRAM
  bram_simple_dp #(
    .N(N_LOG2),
    .B(B)
  ) mem_i (
    .clk   (clk),
    .ena   (1'b1),
    .enb   (rd_en),
    .wea   (mem_wea),
    .addra (wptr),
    .addrb (rptr),
    .dia   (din),
    .dob   (mem_dob)
  );

  // write enable
  assign mem_wea = wr_en & ~full_i;

  // flags
  assign full_i  = (wptr == (rptr - 1'b1));
  assign empty_i = (wptr == rptr);

  // pointers
  always_ff @(posedge clk) begin
    if (!rstn) begin
      wptr <= '0;
      rptr <= '0;
    end else begin
      if (wr_en && !full_i)
        wptr <= wptr + 1'b1;

      if (rd_en && !empty_i)
        rptr <= rptr + 1'b1;
    end
  end

  assign dout  = mem_dob;
  assign full  = full_i;
  assign empty = empty_i;

endmodule
