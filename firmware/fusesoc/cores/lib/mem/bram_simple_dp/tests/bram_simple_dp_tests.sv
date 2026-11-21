// ============================================================================
// File: bram_simple_dp_tests.sv
// Description: SVUnit test cases for bram_simple_dp. Included by
//              bram_simple_dp_tc00.sv.
// ============================================================================

`SVTEST(tc_write_then_read)
    write(4'd5, 8'h42);
    read(4'd5);
    `FAIL_UNLESS(tb_dob === 8'h42);
`SVTEST_END

`SVTEST(tc_write_read_second_address)
    write(4'd10, 8'hAB);
    read(4'd10);
    `FAIL_UNLESS(tb_dob === 8'hAB);
`SVTEST_END

`SVTEST(tc_addresses_are_independent)
    write(4'd1, 8'h11);
    write(4'd2, 8'h22);
    read(4'd1);
    `FAIL_UNLESS(tb_dob === 8'h11);
    read(4'd2);
    `FAIL_UNLESS(tb_dob === 8'h22);
`SVTEST_END

`SVTEST(tc_write_without_wea_is_ignored)
    write(4'd3, 8'hFF); // Establish a known baseline value.
    @(negedge tb_clk);
    tb_ena   = 1'b1;
    tb_wea   = 1'b0; // Write enable deasserted: dia must not land.
    tb_addra = 4'd3;
    tb_dia   = 8'h00;
    @(negedge tb_clk);
    tb_ena   = 1'b0;
    read(4'd3);
    `FAIL_UNLESS(tb_dob === 8'hFF);
`SVTEST_END

`SVTEST(tc_read_without_enb_holds_output)
    write(4'd6, 8'h55);
    read(4'd6);
    `FAIL_UNLESS(tb_dob === 8'h55);
    // A read to a different, never-written address with enb deasserted
    // must not disturb the held output.
    @(negedge tb_clk);
    tb_addrb = 4'd7;
    @(negedge tb_clk);
    `FAIL_UNLESS(tb_dob === 8'h55);
`SVTEST_END
