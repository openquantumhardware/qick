`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module pps_gen_tc00_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "pps_gen_tc00_ut";
    svunit_testcase svunit_ut;

    localparam                          CLOCK_FREQUENCY = 125e6; //[Hz]


    logic              tb_clk = 1'b0;
    logic              tb_rst = 1'b0;
    logic              tb_pps = 1'b0;
    logic              tb_en  = 1'b0;
    logic [26-1   : 0] tb_pps_count = '0;
    logic              tb_false_pps_led;

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

    pps_gen dut (
        .i_clk            ( tb_clk                ),
        .i_rst            ( tb_rst                ),
        .i_pps            ( tb_pps                ),
        .i_en             (),
        .o_pps            (), 
        .o_clk_cnt_pps    ( tb_pps_count          ),
        .o_false_pps_led  ()
    );

    //===================================
    // Build
    //===================================
    initial begin
        $dumpfile("pps_gen_test.vcd");
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

        tb_rst          = 1'b1;
        repeat(2)@(negedge tb_clk);
        tb_rst          = 1'b0;
        repeat(10)@(negedge tb_clk);

    endtask

    //===================================
    // Here we deconstruct anything we 
    // need after running the Unit Tests
    //===================================
    task teardown();
      svunit_ut.teardown();
    endtask


    `SVUNIT_TESTS_BEGIN
        `include "tests.sv"
    `SVUNIT_TESTS_END 

endmodule

