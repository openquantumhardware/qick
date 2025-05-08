
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"
`include "leds_status_regmap.svh"

module leds_status_tc00_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "leds_status_tc00_ut";
    svunit_testcase svunit_ut;

    localparam                          CLOCK_FREQUENCY = 100e6; //[Hz]
    localparam integer unsigned         N_LED           = 3;
    localparam integer unsigned         NB_CNTR         = 32;
    localparam integer unsigned         NB_DATA         = 8;
    localparam integer unsigned         DATA_WIDTH      = 32;
    localparam integer unsigned         ADDR_WIDTH      = 32;
    localparam integer unsigned         NB_MAX_COUNT    = 32;


    logic                               tb_clk       = 1'b0;
    logic                               tb_rst       = 1'b0;
    logic [N_LED-1   : 0]               tb_o_led_mode;
    logic [N_LED-1   : 0]               tb_o_led_status;
    logic [N_LED-1   : 0]               tb_o_led_gnss;
    logic [N_LED-1   : 0]               tb_o_led_track;

    axi4lite_intf #(
        .DATA_WIDTH( DATA_WIDTH ),
        .ADDR_WIDTH( ADDR_WIDTH )
    )
        i_axil_csr
    (
        .i_clk( tb_clk ),
        .i_rst( tb_rst )
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

    leds_status
    #(
        .N_LED                ( N_LED           ),
        .IP_FREQ              ( CLOCK_FREQUENCY ), 
        .NB_CNTR              ( NB_CNTR         )
    ) 
    dut 
    (
        .i_clk                  ( tb_clk                ),
        .i_rst                  ( tb_rst                ),
        .s_axil                 ( i_axil_csr            ),
        .o_led_mode             ( tb_o_led_mode         ),
        .o_led_status           ( tb_o_led_status       ),
        .o_led_gnss             ( tb_o_led_gnss         ),
        .o_led_track            ( tb_o_led_track        )
    );


    //===================================
    // Build
    //===================================
    initial begin
        $dumpfile("leds_status_test.vcd");
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
        
        i_axil_csr.AWVALID  <= 1'b0;
        i_axil_csr.AWADDR   <=   '0;
        i_axil_csr.AWPROT   <=   '0;

        i_axil_csr.WVALID   <= 1'b0;
        i_axil_csr.WDATA    <=   '0;
        i_axil_csr.WSTRB    <=   '0;
        i_axil_csr.BREADY   <= 1'b0;

        i_axil_csr.ARVALID  <= 1'b0;
        i_axil_csr.ARADDR   <=   '0;
        i_axil_csr.ARPROT   <=   '0;
        i_axil_csr.RREADY   <= 1'b0;

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

