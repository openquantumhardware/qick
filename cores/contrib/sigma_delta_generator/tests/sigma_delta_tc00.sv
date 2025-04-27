`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module sigma_delta_00_unit_test;
    import svunit_pkg::svunit_testcase;


    string name = "sigma_delta_00_ut";
    svunit_testcase svunit_ut;

    localparam                      CLOCK_FREQUENCY = 250e6; //[Hz]

    localparam                      NB_SIGMA_DELTA  = 8;

    logic                           tb_clk          = 1'b0;
    logic                           tb_rst          = 1'b0;

    logic                           tb_rd_enable;
    logic [NB_SIGMA_DELTA  -1:0]    tb_delta;
    logic [NB_SIGMA_DELTA  -1:0]    tb_sigma;
    logic                           tb_enable;

    initial begin
        $dumpfile("sigma_delta.vcd");
        $dumpvars();
    end
// Clock gen
//-----------------------------------------------------------------------------
    clk_gen
    #(
        .FREQ       ( CLOCK_FREQUENCY )
    )
    u_clk_gen
    (
        .i_enable   ( 1'b1 ),
        .o_clk      ( tb_clk )
    );
//-----------------------------------------------------------------------------
    //===================================
    // This is the UUT that we're
    // running the Unit Tests on
    //===================================

    sigma_delta_generator
    #(
    .NB_SIGMA_DELTA (NB_SIGMA_DELTA)
    )
    u_sigma_delta_generator
    (
        .i_clk      (tb_clk),
        .i_rst      (tb_rst),
    
        .i_enable   (tb_rd_enable),
        .i_delta    (tb_delta),
        .i_sigma    (tb_sigma),

        .o_enable   (tb_enable)
    );
    
    //===================================
    // Build
    //===================================

    function void build();
        svunit_ut = new(name);
    endfunction

    task clock_nedge(input int n);
       repeat(n) @(negedge tb_clk);
    endtask

    task clock_pedge(input int n);
      repeat(n) @(posedge tb_clk);
    endtask

    //===================================
    // Setup for running the Unit Tests
    //===================================
    task setup();
        svunit_ut.setup();
    
        tb_rd_enable    <= 1'b0;
        tb_delta        <=  '0;
        tb_sigma        <=  '0;


        tb_rst           <=   1'b1;
        clock_nedge(3);
        tb_rst           <=   1'b0;
        clock_nedge(3);

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

    int t1 = 0, t2 = 0;
    int count_iter = 0;
    int count_time = 0;

    real rate_ideal = 0;
    real rate_real = 0;


    `SVUNIT_TESTS_BEGIN
        `include "tests.sv"
    `SVUNIT_TESTS_END 
endmodule
