`ifndef FIFO_SV_SV
`define FIFO_SV_SV

module fifo_sv #(
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

  localparam int N_LOG2 = (N <= 1) ? 1 : $clog2(N);

  logic [N_LOG2-1:0] wptr;
  logic [N_LOG2-1:0] rptr;

  logic         mem_wea;
  logic [B-1:0] mem_dob;

  logic full_i;
  logic empty_i;

  bram_simple_dp_sv #(
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

  assign mem_wea = (full_i == 1'b0) ? wr_en : 1'b0;

  assign full_i  = (wptr == (rptr - 1'b1));
  assign empty_i = (wptr == rptr);

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

`endif // FIFO_SV_SV
