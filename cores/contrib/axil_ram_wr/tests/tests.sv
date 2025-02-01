`SVTEST(test00_reset_test)
repeat(2) @(negedge tb_clk);
tb_rst = 1'b1;
@(negedge tb_clk);
tb_rst = 1'b0;
repeat(2) @(negedge tb_clk);

  for (integer j = 0; j < 10; j = j + 1) begin
    axi4_lite_in_if.WDATA = $urandom();
    @(negedge tb_clk);
  end
  repeat(5) @(negedge tb_clk);
`SVTEST_END
//-------------------------------------------------------------------------------------------------//
`SVTEST(test01_single_transaction)
repeat(2) @(negedge tb_clk);
tb_rst = 1'b1;
@(negedge tb_clk);
tb_rst = 1'b0;
repeat(2) @(negedge tb_clk);

axi4_lite_in_if.AWVALID = 1'b1;
axi4_lite_in_if.AWADDR  = 32'h00000004;
axi4_lite_in_if.WVALID  = 1'b1;
axi4_lite_in_if.BREADY  = 1'b1;
axi4_lite_in_if.WDATA = 32'hFFFFCCFF;

for (integer k = 0; k < 4; k = k + 1) begin
  axi4_lite_in_if.WSTRB   = 1<<k;
  @(negedge tb_clk);
end

axi4_lite_in_if.AWVALID = 1'b0;
axi4_lite_in_if.WVALID  = 1'b0;
axi4_lite_in_if.BREADY  = 1'b0;
repeat(50) @(negedge tb_clk);

`SVTEST_END
//-------------------------------------------------------------------------------------------------//
`SVTEST(test02_aw_channel)

repeat(2) @(negedge tb_clk);
tb_rst = 1'b1;
@(negedge tb_clk);
tb_rst = 1'b0;
repeat(2) @(negedge tb_clk);

axi4_lite_in_if.AWVALID = 1'b1;
axi4_lite_in_if.WVALID  = 1'b1;
axi4_lite_in_if.WSTRB   = '1;
axi4_lite_in_if.BREADY  = 1'b1;
axi4_lite_in_if.WDATA = 32'hFF00CCAA;
for (integer k = 0; k < 10; k = k + 1) begin
  axi4_lite_in_if.AWADDR = 4*k;
  axi4_lite_in_if.WDATA = $urandom;

for (integer r = 0; r < 4; r = r + 1) begin
  axi4_lite_in_if.WSTRB   = 1<<r;
  @(negedge tb_clk);
end
end
axi4_lite_in_if.AWVALID = 1'b0;
axi4_lite_in_if.WVALID  = 1'b0;
axi4_lite_in_if.BREADY  = 1'b0;
repeat(50) @(negedge tb_clk);

`SVTEST_END
//-------------------------------------------------------------------------------------------------//

