
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module bram_generator_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "bram_ut";
    svunit_testcase svunit_ut;

    localparam CLOCK_FREQUENCY = 100e6; //[Hz]

    localparam int unsigned     NB_DATA         = 32;
    localparam int unsigned     NB_ADDR         =  4;
    localparam string           MEM_BIN_FILE    = "bin_memory_file.mem";

    localparam int unsigned     DEPTH           = 2**NB_ADDR;

    logic                       tb_clk        = 1'b0;
    logic                       tb_wr_enb_in  = 1'b0;
    logic                       tb_rd_enb_in  = 1'b0;
    logic   [NB_ADDR-1 : 0]     tb_wr_addr_in =   '0;
    logic   [NB_ADDR-1 : 0]     tb_rd_addr_in =   '0;
    logic   [NB_DATA-1 : 0]     tb_data_in    =   '0;
    logic   [NB_DATA-1 : 0]     tb_data_out         ;

    clk_gen
    #(
        .FREQ       (CLOCK_FREQUENCY    )
    )
    u_clk_gen
    (
        .i_enable   (1'b1               ),
        .o_clk      (tb_clk             )
    );

    default clocking cb @(posedge tb_clk);
    endclocking

    //===================================
    // This is the UUT that we're
    // running the Unit Tests on
    //===================================

    bram
    #(
        .NB_DATA            (NB_DATA        ),
        .NB_ADDR            (NB_ADDR        ),
        .MEM_BIN_FILE       (MEM_BIN_FILE   )
    )
    u_bram
    (
        .i_clk              (tb_clk         ),
        .i_wr_enb           (tb_wr_enb_in   ),
        .i_rd_enb           (tb_rd_enb_in   ),
        .i_wr_addr          (tb_wr_addr_in  ),
        .i_rd_addr          (tb_rd_addr_in  ),
        .i_data             (tb_data_in     ),
        .o_data             (tb_data_out    )
    );


    property wr_stable;
    @(posedge tb_clk) tb_wr_enb_in == 1'b0 |=> $stable(u_bram.bram_data);
    endproperty `ASSERT_CONCURRENT(wr_stable);

    property rd_stable;
    @(posedge tb_clk) tb_rd_enb_in == 1'b0 |=> $stable(tb_data_out);
    endproperty `ASSERT_CONCURRENT(rd_stable);

    //===================================
    // Build
    //===================================
    function void build();
        svunit_ut = new(name);
    endfunction

    
    //===================================
    // Setup for running the Unit Tests
    //===================================
    initial begin
        $assertoff(0);
        ## 10;
        $asserton(0);
    end

    task setup();
        svunit_ut.setup();
        tb_wr_enb_in  = 1'b0;
        tb_rd_enb_in  = 1'b0;
        tb_wr_addr_in =   '0;
        tb_rd_addr_in =   '0;
        ## 10;

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

    logic [NB_DATA-1:0] tb_bram_data [DEPTH];
    logic [NB_DATA-1:0] bin_memory_queue [$:DEPTH];

    `SVUNIT_TESTS_BEGIN
        `include "tests.sv"
    `SVUNIT_TESTS_END 

endmodule
