//-------------------------------------------------------------------------------------------------//
`SVTEST(test00_reset)

    cb.tb_i_data <= 1'b0;

    for (integer k = 0; k < 10; k++) begin
        cb.tb_rstn <= 1'b0;
        @(cb);

        cb.tb_rstn <= 1'b1;

        // La salida debe permanecer a 0 mientras se llena el pipeline
        repeat (NSTAGES) begin
            @(cb);
            `ASSERT_IMMEDIATE(tb_o_data == 1'b0);
        end
    end

`SVTEST_END
//-------------------------------------------------------------------------------------------------//
`SVTEST(test01_bit_sync)

    cb.tb_i_data <= 1'b0;
    repeat (NSTAGES) @(cb);

    for (integer k = 0; k < 10; k++) begin
        cb.tb_i_data <= k[0];

        repeat (NSTAGES) @(cb);

        `ASSERT_IMMEDIATE(tb_o_data == k[0]);
    end

`SVTEST_END
//-------------------------------------------------------------------------------------------------//
    `SVTEST(test02_toggle)

    logic expected;

    expected = 1'b0;
    cb.tb_i_data <= expected;
    repeat (NSTAGES) @(cb);

    repeat (20) begin
        expected = ~expected;
        cb.tb_i_data <= expected;

        repeat (NSTAGES) @(cb);

        `ASSERT_IMMEDIATE(tb_o_data == expected);
    end

`SVTEST_END

//-------------------------------------------------------------------------------------------------//