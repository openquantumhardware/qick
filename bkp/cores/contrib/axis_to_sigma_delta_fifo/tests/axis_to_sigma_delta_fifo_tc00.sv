`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module axis_to_sigma_delta_fifo_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "axis_to_sigma_delta_fifo_ut";
    svunit_testcase svunit_ut;

    localparam integer unsigned CLOCK_FREQUENCY = 100e6; //[Hz]

    localparam integer unsigned NB_DATA        = 32;
    localparam integer unsigned DEPTH          = 64;
    localparam integer unsigned NB_SIGMA_DELTA = 16;

    logic                               tb_clk = 1'b0          ;
    logic                               tb_rst = 1'b0          ;
    logic [NB_SIGMA_DELTA-1:0]          tb_rf_sigma = 1 ;
    logic [NB_SIGMA_DELTA-1:0]          tb_rf_delta = 100 ;

    axi4_stream_if
    #(
        .N_BYTES_TDATA  (NB_DATA/8)
    ) 
    axis_in_if
    (
        .i_clk          (tb_clk),
        .i_rst          (tb_rst)
    );

    data_stream_if
    #(
        .NB_DATA        (NB_DATA)
    )
    data_out_if
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
    
    default clocking cb @(posedge tb_clk);
    endclocking


    //===================================
    // This is the UUT that we're 
    // running the Unit Tests on
    //===================================

    axis_to_sigma_delta_fifo 
    #(
        .DEPTH              ( DEPTH                 ),
        .NB_SIGMA_DELTA     ( NB_SIGMA_DELTA        )
    )
    u_axis_to_sigma_delta_fifo
    (
        .i_clk              ( tb_clk                ),
        .i_rst              ( tb_rst                ),
        .i_rd_enable        ( tb_rd_enable          ),
        .i_rf_sigma         ( tb_rf_sigma           ),
        .i_rf_delta         ( tb_rf_delta           ),
        .i_axis             ( axis_in_if            ),
        .o_stream           ( data_out_if           )
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
        ##10;
        svunit_ut.setup();

        axis_in_if.tvalid = 1'b0;
        axis_in_if.tdata = '0;
        axis_in_if.tlast = 1'b0;
        tb_rst = 1'b1;
        tb_rd_enable = 1'b1;
        ##1;
        tb_rst = 1'b0;
        ##10;
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
