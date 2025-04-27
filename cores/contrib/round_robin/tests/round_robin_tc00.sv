`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module round_robin_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "round_robin_ut";
    svunit_testcase svunit_ut;

    localparam CLOCK_FREQUENCY = 100e6; //[Hz]

    localparam N_CHANNELS = 16;
    localparam NB_DATA    = 32;

    logic                               tb_clk = 1'b0       ;
    logic                               tb_rst = 1'b0       ;

    logic [N_CHANNELS-1:0][NB_DATA-1:0] data_queue [$];

    initial begin
        $dumpfile("test.vcd");
        $dumpvars;
    end

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
    axi4_stream_if#(.N_BYTES_TDATA((NB_DATA*N_CHANNELS)/8)) i_axis (
        .i_clk(tb_clk),
        .i_rst(tb_rst)
    );

    axi4_stream_if#(.N_BYTES_TDATA(NB_DATA/8), .HAS_TUSER(1'b1)) o_axis (
        .i_clk( tb_clk ),
        .i_rst( tb_rst )
    );

    round_robin 
    #(
        .ASCENDING  ( 1'b1 )
    )
    dut
    (
        .i_clk  ( tb_clk ) ,
        .i_rst  ( tb_rst ) ,
        .i_axis ( i_axis ) ,
        .o_axis ( o_axis )
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
        data_queue.delete();

        @(o_axis.m_cb);
        tb_rst <= 1'b1;
        o_axis.m_cb.tready <= '0;
        i_axis.s_cb.tvalid <= 1'b0;
        i_axis.s_cb.tlast <= 1'b1;
        @(o_axis.m_cb);
        tb_rst <= 1'b0;
        @(o_axis.m_cb);
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

    logic [N_CHANNELS-1:0][NB_DATA-1:0] data_payload = '0;
    logic [N_CHANNELS-1:0][NB_DATA-1:0] data_payload_delayed = '0;
    logic [$clog2(N_CHANNELS):0] channels_counter = '0;

    `SVUNIT_TESTS_BEGIN
        `include "tests.sv"
    `SVUNIT_TESTS_END

endmodule
