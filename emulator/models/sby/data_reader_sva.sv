module data_reader_equiv #(
  parameter int N = 8,
  parameter int B = 16
) (
  input  logic             clk,
  input  logic             rstn,
  input  logic             START_REG,
  input  logic [N-1:0]     ADDR_REG,
  input  logic [N-1:0]     LEN_REG,
  input  logic             dready
);

  logic             mem_en_vhdl, mem_we_vhdl;
  logic [N-1:0]     mem_addr_vhdl;
  logic [B-1:0]     mem_dout_vhdl;

  logic             mem_en_sv, mem_we_sv;
  logic [N-1:0]     mem_addr_sv;
  logic [B-1:0]     mem_dout_sv;

  logic [B-1:0]     dout_vhdl, dout_sv;
  logic             dvalid_vhdl, dvalid_sv;
  logic             dlast_vhdl, dlast_sv;

  data_reader vhdl_dut (
    .rstn     (rstn),
    .clk      (clk),
    .mem_en   (mem_en_vhdl),
    .mem_we   (mem_we_vhdl),
    .mem_addr (mem_addr_vhdl),
    .mem_dout (mem_dout_vhdl),
    .dout     (dout_vhdl),
    .dready   (dready),
    .dvalid   (dvalid_vhdl),
    .dlast    (dlast_vhdl),
    .START_REG(START_REG),
    .ADDR_REG (ADDR_REG),
    .LEN_REG  (LEN_REG)
  );

  data_reader_sv #(
    .N(N),
    .B(B)
  ) sv_dut (
    .rstn     (rstn),
    .clk      (clk),
    .mem_en   (mem_en_sv),
    .mem_we   (mem_we_sv),
    .mem_addr (mem_addr_sv),
    .mem_dout (mem_dout_sv),
    .dout     (dout_sv),
    .dready   (dready),
    .dvalid   (dvalid_sv),
    .dlast    (dlast_sv),
    .START_REG(START_REG),
    .ADDR_REG (ADDR_REG),
    .LEN_REG  (LEN_REG)
  );

  logic past_valid;
  initial past_valid = 1'b0;
  always_ff @(posedge clk) past_valid <= 1'b1;

  always_comb assume(!rstn == $initstate);

  always_ff @(posedge clk) begin
    if (!rstn) begin
      assume(!START_REG);
      assume(dready == 1'b0);
      assume(ADDR_REG == '0);
      assume(LEN_REG  == '0);
    end
  end

  always_ff @(posedge clk) if (rstn) begin
    assume(dready);
    if (START_REG) begin
      assume($stable(ADDR_REG));
      assume($stable(LEN_REG));
      assume(LEN_REG != '0);
    end
  end

  (* anyseq *) logic [B-1:0] mem_seed;

  always_comb begin
    mem_dout_vhdl = rstn ? (mem_seed ^ {{(B-N){1'b0}}, mem_addr_vhdl}) : '0;
    mem_dout_sv   = rstn ? (mem_seed ^ {{(B-N){1'b0}}, mem_addr_sv  }) : '0;
  end

  logic start_q;
  always_ff @(posedge clk) begin
    if (!rstn) start_q <= 1'b0;
    else      start_q <= START_REG;
  end

  wire done_both = dvalid_vhdl && dvalid_sv && dready && dlast_vhdl && dlast_sv;

  logic done_q;
  always_ff @(posedge clk) begin
    if (!rstn) done_q <= 1'b0;
    else      done_q <= done_both;
  end

  always_ff @(posedge clk) if (rstn && past_valid) begin
    if (start_q && !START_REG) begin
      assume($past(done_both));
    end
    if (done_both) begin
      assume(!START_REG);
    end
    if (done_q) begin
      assume(!START_REG);
    end
  end

  always_ff @(posedge clk) begin
    if (past_valid && rstn) begin
      assert(dout_vhdl   === dout_sv);
      assert(dvalid_vhdl === dvalid_sv);
      assert(dlast_vhdl  === dlast_sv);

      assert(mem_en_vhdl   === mem_en_sv);
      assert(mem_we_vhdl   === mem_we_sv);
      assert(mem_addr_vhdl === mem_addr_sv);
    end
  end

endmodule