// ============================================================================
// File: qproc_time_ctrl_tests.sv
// Description: SVUnit test cases for qproc_time_ctrl. Included by
//              qproc_time_ctrl_tc00.sv.
// ============================================================================

`SVTEST(tc_reset_zero)
    // setup() already pulsed time_rst_i (see reset_dut() -- time_abs has no
    // direct tie to t_rst_ni, only an explicit time_rst_i/time_init_i pulse
    // zeroes it, matching the ADDSUB_MACRO-backed hardware).
    `FAIL_UNLESS(tb_time_abs_o === 48'd0);
`SVTEST_END

`SVTEST(tc_free_run_increments_by_one)
    logic [47:0] prev;

    tb_time_en_i = 1'b1;
    // Give the FSM one cycle to leave ST_IDLE and reach ST_INCREMENT.
    repeat(2) @(posedge tb_clk);
    prev = tb_time_abs_o;
    repeat(5) begin
        @(posedge tb_clk);
        `FAIL_UNLESS(tb_time_abs_o === prev + 48'd1);
        prev = tb_time_abs_o;
    end
`SVTEST_END

`SVTEST(tc_time_rst_pulse_returns_to_zero)
    tb_time_en_i = 1'b1;
    repeat(5) @(posedge tb_clk);
    `FAIL_IF(tb_time_abs_o === 48'd0); // sanity: it was running

    pulse(tb_time_rst_i);
    `FAIL_UNLESS(tb_time_abs_o === 48'd0);
`SVTEST_END

`SVTEST(tc_time_updt_adds_signed_offset_plus_carry)
    // ST_UPDATE adds updt_dt_i (sign-extended) with the adder's carry-in
    // tied high (the ADDSUB_MACRO CARRYIN behavior the legacy file's dead,
    // commented-out RTL-inference alternative did not reproduce -- see the
    // module header), and the FSM always takes one more ST_INCREMENT pass
    // (+1) before settling back in ST_IDLE. From a zeroed counter:
    // 0 + 100 + 1(carry) + 1(mandatory increment pass) = 102.
    tb_updt_dt_i = 32'd100;
    pulse(tb_time_updt_i);
    repeat(10) @(posedge tb_clk); // let the FSM settle back to ST_IDLE
    `FAIL_UNLESS(tb_time_abs_o === 48'd102);
`SVTEST_END

`SVTEST(tc_time_init_loads_unsigned_offset)
    // ST_INIT -> ST_LOAD_OFFSET loads updt_dt_i zero-extended (no sign
    // extension, no carry), unlike the time_updt_i path above; the FSM then
    // still takes one mandatory ST_INCREMENT pass (+1) before ST_IDLE.
    tb_updt_dt_i = 32'hFFFF_FFFF; // would sign-extend to a huge value if signed
    pulse(tb_time_init_i);
    repeat(10) @(posedge tb_clk);
    `FAIL_UNLESS(tb_time_abs_o === (48'({16'd0, 32'hFFFF_FFFF}) + 48'd1));
`SVTEST_END

// The counter is 48 bits and updt_dt_i only 32: the upper bits are reached by stepping (time_updt_i) or by free-running. The old
// qick_testbench (test_tproc_basic) forced the adder's result to 2**N - 100 for N = 12..48 to watch the carry go up; here two
// steps bring it to 2**32 - 13, it runs free, and it must go up by exactly 1 per cycle across the carry out of bit 31.
`SVTEST(tc_free_run_carries_across_bit_32)
    logic [47:0] prev;

    tb_updt_dt_i = 32'h7FFF_FFFF;
    pulse(tb_time_updt_i);
    repeat(10) @(posedge tb_clk);
    `FAIL_UNLESS(tb_time_abs_o === 48'h0000_8000_0001);       // 0 + 0x7FFFFFFF + 1 (carry) + 1 (increment pass)
    tb_updt_dt_i = 32'h7FFF_FFF0;
    pulse(tb_time_updt_i);
    repeat(10) @(posedge tb_clk);
    `FAIL_UNLESS(tb_time_abs_o === 48'h0000_FFFF_FFF3);       // 2**32 - 13

    tb_time_en_i = 1'b1;
    repeat(2) @(posedge tb_clk);
    prev = tb_time_abs_o;
    repeat(40) begin
        @(posedge tb_clk);
        `FAIL_UNLESS(tb_time_abs_o === prev + 48'd1);
        prev = tb_time_abs_o;
    end
    `FAIL_UNLESS(tb_time_abs_o > 48'h0000_FFFF_FFFF);         // it did cross
`SVTEST_END
