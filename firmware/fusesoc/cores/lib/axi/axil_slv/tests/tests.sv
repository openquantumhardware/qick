// ============================================================================
// tests.sv
// ============================================================================

`SVTEST(reset_initialization)
  logic [AXI_DW-1:0] read_data;
  
  // Verify all registers are initialized correctly (default '0)
  for (int i = 0; i < NUM_REGS; i++) begin
    s_axi.axi_read(.addr(i * (AXI_DW/8)), .data(read_data));
    `FAIL_IF(read_data !== 32'h0);
  end
`SVTEST_END

`SVTEST(single_read_write)
  logic [AXI_DW-1:0] test_val = 32'hCAFEBABE;
  logic [AXI_DW-1:0] read_data;

  // Write and read from Register 1 (Offset 0x04)
  s_axi.axi_write(.addr(8'h04), .data(test_val)); 
  s_axi.axi_read(.addr(8'h04), .data(read_data));

  `FAIL_IF(read_data !== test_val);
`SVTEST_END

`SVTEST(bulk_read_write_operations)
  logic [AXI_DW-1:0] write_array[] = '{32'h1111_1111, 32'h2222_2222, 32'h3333_3333, 32'h4444_4444};
  logic [AXI_DW-1:0] read_array[];

  // Write 4 consecutive registers starting from Reg 4 (Offset 0x10)
  s_axi.axi_bulk_write(.base_addr(8'h10), .data_array(write_array));
  
  // Read in bulk to verify
  s_axi.axi_bulk_read(.base_addr(8'h10), .data_array(read_array), .num_regs(4));

  foreach(write_array[i]) begin
    `FAIL_IF(read_array[i] !== write_array[i]);
  end
`SVTEST_END

`SVTEST(readonly_register_protection)
  logic [AXI_DW-1:0] read_data;

  tb_i_reg_is_readonly[2] = 1'b1;

  s_axi.axi_write(.addr(8'h08), .data(32'hDEAD_DEAD));
  s_axi.axi_read(.addr(8'h08), .data(read_data));

  `FAIL_IF(read_data === 32'hDEAD_DEAD);
  `FAIL_IF(read_data !== 32'h0);

  tb_i_reg_is_readonly[2] = 1'b0;
`SVTEST_END

`SVTEST(back_to_back_transactions)
  logic [AXI_DW-1:0] read_data;

  // Verify the behavior of your aw_en logic (VHDL compatibility) 
  // ensuring that no data is lost in rapid consecutive writes
  s_axi.axi_write(.addr(8'h0C), .data(32'hAAAA_AAAA));
  s_axi.axi_write(.addr(8'h0C), .data(32'hBBBB_BBBB)); 

  s_axi.axi_read(.addr(8'h0C), .data(read_data));
  `FAIL_IF(read_data !== 32'hBBBB_BBBB);
`SVTEST_END
`SVTEST(byte_strobes_write_only_their_lanes)
  // Each byte lane is written only when its wstrb bit is set.
  logic [AXI_DW-1:0] read_data, expect_val;
  s_axi.axi_write(.addr(8'h08), .data(32'h1122_3344));
  expect_val = 32'h1122_3344;
  for (int s = 0; s < 16; s++) begin
    logic [AXI_DW-1:0] d = 32'hA0B0_C0D0 | s;
    axi_write_strb(8'h08, d, 4'(s));
    for (int b = 0; b < 4; b++) if (s[b]) expect_val[8*b +: 8] = d[8*b +: 8];
    s_axi.axi_read(.addr(8'h08), .data(read_data));
    `FAIL_UNLESS_EQUAL(read_data, expect_val)
  end
`SVTEST_END
