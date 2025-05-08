
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module axis_tlast_generator_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "axis_tlast_generator_ut";
    svunit_testcase svunit_ut;

    localparam CLOCK_FREQUENCY = 100e6; //[Hz]

    localparam NB_DATA        = 32;
    localparam NB_PACKET_SIZE = 32;

    logic                      tb_clk = 1'b0          ;
    logic                      tb_rst = 1'b0          ;
    logic [NB_PACKET_SIZE-1:0] tb_packet_size = '0 ;

    logic [NB_PACKET_SIZE  :0] word_counter    = '0   ;
    logic [NB_PACKET_SIZE  :0] past_packet_size = '0  ;

    axi4_stream_if
    #(
        .N_BYTES_TDATA ($ceil(NB_DATA/8.0))
    ) 
    axis_in_if
    (
        .i_clk (tb_clk),
        .i_rst (tb_rst)
    );

    axi4_stream_if
    #(
        .N_BYTES_TDATA ($ceil(NB_DATA/8.0))
    ) 
    axis_out_if
    (
        .i_clk (tb_clk),
        .i_rst (tb_rst)
    );

    clk_gen 
    #(
        .FREQ ( CLOCK_FREQUENCY )
    )
    u_clk_gen
    (
        .i_enable ( 1'b1 ),
        .o_clk ( tb_clk )
    );
    
    default clocking cb @(posedge tb_clk);
    endclocking


    //===================================
    // This is the UUT that we're 
    // running the Unit Tests on
    //===================================

    axis_tlast_generator 
    #(
        .NB_PACKET_SIZE ( NB_PACKET_SIZE )
    )
    u_axis_tlast_generator
    (
        .i_clk ( tb_clk ),
        .i_rst ( tb_rst ),
        .i_packet_size ( tb_packet_size ),
        .i_axis ( axis_in_if ),
        .o_axis ( axis_out_if )
    );

    //===================================
    // Build
    //===================================
    initial begin
        $dumpfile("axis_tlast_generator_test.vcd");
        $dumpvars();
    end

    function void build();
        svunit_ut = new(name);
    endfunction

    //===================================
    // Setup for running the Unit Tests
    //===================================
    task setup();
        ##10;
        svunit_ut.setup();

        axis_out_if.tdata    =  '0 ;
        axis_out_if.tready   = 1'b0;
        axis_in_if.tdata     =  '0 ;
        axis_in_if.tvalid    = 1'b0;
        axis_in_if.tlast     = 1'b0;

        word_counter         = '0;
        tb_packet_size       = 32'd256;

        tb_rst               = 1'b1;
        ##1;
        tb_rst               = 1'b0;
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
