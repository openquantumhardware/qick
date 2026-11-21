// ============================================================================
// File: qcore_cpu_tests.sv
// Description: SVUnit test cases for qcore_cpu. Included by qcore_cpu_tc00.sv.
// ============================================================================

`SVTEST(tc_reset_pc_zero)
    `FAIL_UNLESS(tb_pmem_addr_o === '0);
`SVTEST_END

`SVTEST(tc_halted_freezes_fetch)
    tb_en_i = 1'b0;
    repeat(10) @(posedge tb_clk);
    `FAIL_UNLESS(tb_pmem_addr_o === '0);
    `FAIL_IF(tb_pmem_en_o);
`SVTEST_END

`SVTEST(tc_pc_increments_with_nop_stream)
    logic [PMEM_AW-1:0] prev;

    tb_en_i = 1'b1;
    @(posedge tb_clk);
    prev = tb_pmem_addr_o;
    repeat(5) begin
        @(posedge tb_clk);
        `FAIL_UNLESS(tb_pmem_addr_o === prev + 1'b1);
        prev = tb_pmem_addr_o;
    end
`SVTEST_END

`SVTEST(tc_restart_resets_pc_while_running)
    tb_en_i = 1'b1;
    repeat(5) @(posedge tb_clk);
    `FAIL_IF(tb_pmem_addr_o === '0);

    @(negedge tb_clk);
    tb_restart_i = 1'b1;
    @(negedge tb_clk);
    tb_restart_i = 1'b0;
    `FAIL_UNLESS(tb_pmem_addr_o === '0);
`SVTEST_END

`SVTEST(tc_store_immediate_to_dmem_addr0)
    logic [DMEM_AW-1:0] addr;
    logic [31:0] data;

    pmem_rom[0] = mk_store_imm(1'b0, 11'h055); // ai=0 -> addr = rs_a[0]+rs_a[1] = 0
    tb_en_i = 1'b1;

    wait_for_dmem_we(addr, data);
    `FAIL_IF(addr === 'x); // timed out waiting for dmem_we_o
    `FAIL_UNLESS(addr === '0);
    `FAIL_UNLESS(data === 32'h0000_0055);

    // Single-cycle pulse: should not still be asserted on the next edge.
    @(posedge tb_clk);
    `FAIL_IF(tb_dmem_we_o);
`SVTEST_END

`SVTEST(tc_store_immediate_address_follows_ai)
    logic [DMEM_AW-1:0] addr;
    logic [31:0] data;

    // ai=1 -> address is the same DF=00 immediate field as the data, so
    // address == data for this encoding.
    pmem_rom[0] = mk_store_imm(1'b1, 11'h07A);
    tb_en_i = 1'b1;

    wait_for_dmem_we(addr, data);
    `FAIL_IF(addr === 'x);
    `FAIL_UNLESS(addr === 8'h7A);
    `FAIL_UNLESS(data === 32'h0000_007A);
`SVTEST_END

`SVTEST(tc_branch_immediate_jumps_pc)
    bit reached;

    pmem_rom[0] = mk_branch_imm(11'h030);
    tb_en_i = 1'b1;

    wait_for_pc(8'h30, reached);
    `FAIL_UNLESS(reached);
`SVTEST_END
