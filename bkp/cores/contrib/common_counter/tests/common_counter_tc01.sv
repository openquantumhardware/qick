`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module common_counter_01_generator_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "common_counter_01_ut";
    svunit_testcase svunit_ut;

    localparam integer unsigned CLOCK_FREQUENCY         = 100e6 ; //[Hz]
    localparam integer unsigned NB_MAX_COUNT            = 6;
    localparam integer unsigned REGISTER_START_COUNT    = 1;

    logic                        tb_clk                 = 1'b0;
    logic                        tb_rst                 = 1'b0;
    logic                        tb_start_count_i       = 1'b0;
    logic                        tb_enable_i            = 1'b0;
    logic [NB_MAX_COUNT-1   : 0] tb_rf_max_count_i      = '0;
    logic [NB_MAX_COUNT-1   : 0] tb_counter_o;
    logic                        tb_count_done_o;
    logic                        tb_count_in_process_o;
    

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

    common_counter
    #(
        .NB_MAX_COUNT           ( NB_MAX_COUNT          ),
        .REGISTER_START_COUNT   ( REGISTER_START_COUNT  )
    )
    u_common_counter
    ( 
        .i_clk                  ( tb_clk                ),
        .i_rst                  ( tb_rst                ),
        .i_start_count          ( tb_start_count_i      ),
        .i_enable               ( tb_enable_i           ),
        .i_rf_max_count         ( tb_rf_max_count_i     ),
        .o_counter              ( tb_counter_o          ),
        .o_count_done           ( tb_count_done_o       ),
        .o_count_in_process     ( tb_count_in_process_o )
    );

    //===================================
    // Build
    //===================================
    initial begin
        $dumpfile("common_counter_test.vcd");
        $dumpvars();
    end

    function void build();
        svunit_ut = new(name);
    endfunction

    //===================================
    // Setup for running the Unit Tests
    //===================================
    task setup();
        svunit_ut.setup();

        @(negedge tb_clk);

        tb_start_count_i <= 1'b0;
        tb_enable_i <= 1'b0;
        tb_rf_max_count_i <= '0;

        tb_rst <= 1'b1;

        @(negedge tb_clk);

        tb_rst <= 1'b0;

        @(negedge tb_clk);
        repeat(10)@(negedge tb_clk);

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

    logic [NB_MAX_COUNT -1: 0] value = '0;

    `SVUNIT_TESTS_BEGIN
        `include "tests_tc01.sv"
    `SVUNIT_TESTS_END 

endmodule
