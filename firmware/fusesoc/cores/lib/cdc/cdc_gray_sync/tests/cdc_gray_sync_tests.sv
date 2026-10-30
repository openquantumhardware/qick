`SVTEST(test00_reset)

     `ASSERT_IMMEDIATE(tb_i_data  == '0);     
     @(cb);
     for (integer k = 0; k < 10; k = k + 1) begin
     cb.tb_rstn <= 1'b0;

     @(cb);

     cb.tb_rstn <= 1'b1;

     @(cb);

     `ASSERT_IMMEDIATE(cb.tb_o_data  == '0);     
     @(cb);
    end
     
`SVTEST_END
//-------------------------------------------------------------------------------------------------//
`SVTEST(test01_1bit_data)

    cb.tb_i_data  <= 1'b0;     
    @(cb);
    for (integer k = 0; k < 10; k = k + 1) begin
        cb.tb_i_data <= k;
        repeat(N)@(cb);
        `ASSERT_IMMEDIATE(tb_o_data  == k);     
    end
    repeat(5) @(cb);
     
`SVTEST_END
//-------------------------------------------------------------------------------------------------//
`SVTEST(test02_32bit_data)

    cb.tb_i_data  <= 32'h000A000B;     
    @(cb);
    for (integer k = 0; k < 10; k = k + 1) begin
        cb.tb_i_data <= k;
        repeat(N)@(cb);
        `ASSERT_IMMEDIATE(tb_o_data  == k);     
    end
    repeat(5) @(cb);

`SVTEST_END
//-------------------------------------------------------------------------------------------------//
// =========================================================================
// test03_32bit_data
// =========================================================================
`SVTEST(test03_32bit_data)
  logic [M-1:0] history[$];
  logic [M-1:0] expected;

  for (int k = 0; k < 20; k++) begin
    @(cb);           // clock edge first
    cb.tb_i_data <= k + 32'hA000;   // apply input after edge (sampled next posedge)
    history.push_back(k + 32'hA000);

    // Output at posedge corresponds to input from N cycles ago
    if (history.size() > N) begin
      expected = history.pop_front();
      //$display("expected=%0d tb_o_data=%0d", expected, tb_o_data);
      `FAIL_UNLESS_EQUAL(tb_o_data, expected);
    end
  end

  // Drain the pipeline
  repeat(N) begin
    @(cb);
    if (history.size() > 0) begin
      expected = history.pop_front();
      `FAIL_UNLESS_EQUAL(tb_o_data, expected);
    end
  end
`SVTEST_END
