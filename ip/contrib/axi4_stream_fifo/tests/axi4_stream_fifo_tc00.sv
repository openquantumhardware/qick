`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module axi4_stream_fifo_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "axi4_stream_fifo_ut";
    svunit_testcase svunit_ut;

    initial begin
        $dumpfile("axi4_stream_fifo.vcd");
        $dumpvars();
    end


    localparam CLOCK_FREQUENCY = 100e6; //[Hz]

    localparam NB_DATA      = 32;
    localparam FIFO_DEPTH   = 16;

    logic tb_clk = 1'b0;
    logic tb_rst = 1'b0;

    logic [NB_DATA-1:0] data_payload = '0;
    logic [NB_DATA-1:0] data_payload_queue [$];

    axi4_stream_if
    #(
        .N_BYTES_TDATA  ($ceil(NB_DATA/8.0))
    ) 
    axis_in_if
    (
        .i_clk          (tb_clk), 
        .i_rst          (tb_rst)
    );

    axi4_stream_if
    #(
        .N_BYTES_TDATA  ($ceil(NB_DATA/8.0))
    ) 
    axis_out_if
    (
        .i_clk          (tb_clk), 
        .i_rst          (tb_rst)
    );

    clk_gen 
    #(
        .FREQ       ( CLOCK_FREQUENCY   )
    )
    u_clk_gen
    (
        .i_enable   ( 1'b1              ),
        .o_clk      ( tb_clk            )
    );

    //===================================
    // This is the UUT that we're 
    // running the Unit Tests on
    //===================================
    axi4_stream_fifo 
    #(
        .DEPTH      ( FIFO_DEPTH        )
    )
    u_axi4_stream_fifo
    (
        .i_clk      ( tb_clk            ),
        .i_rst      ( tb_rst            ),
        .i_axis     ( axis_in_if        ),
        .o_axis     ( axis_out_if       )
    );

    //===================================
    // Build
    //===================================
    function void build();
        svunit_ut = new(name);
    endfunction

    //===================================
    // Setup for running the Unit Tests
    //===================================
    task setup();
        svunit_ut.setup();

        axis_out_if.m_cb.tready  <= 1'b0;
        axis_in_if.s_cb.tlast     <= 1'b0;
        axis_in_if.s_cb.tvalid    <= 1'b0;

        data_payload_queue  = {};

        tb_rst = 1'b1;
        repeat(1)@(axis_out_if.m_cb);
        tb_rst = 1'b0;
        repeat(10)@(axis_out_if.m_cb);
    endtask

    //===================================
    // Here we deconstruct anything we 
    // need after running the Unit Tests
    //===================================
    task teardown();
        svunit_ut.teardown();
    endtask

    //===================================
    // All tests are defined between the
    // SVUNIT_TESTS_BEGIN/END macros
    //
    // Each individual test must be
    // defined between `SVTEST(_NAME_)
    // `SVTEST_END
    //
    // i.e.
    //   `SVTEST(mytest)
    //     <test code>
    //   `SVTEST_END
    //===================================

    `SVUNIT_TESTS_BEGIN
        `include "tests.sv"
    `SVUNIT_TESTS_END

endmodule
