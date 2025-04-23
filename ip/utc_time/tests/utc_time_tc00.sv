
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"
`include "utc_time_regmap.svh"

module utc_time_tc00_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "utc_time_tc00_ut";
    svunit_testcase svunit_ut;

    localparam                          CLOCK_FREQUENCY = 100e6; //[Hz]
    localparam integer unsigned         NB_TIMEOUT      = 24;
    localparam logic [NB_TIMEOUT-1:0]   TIMEOUT_MAX     = 500;
    localparam integer unsigned         NB_DATA         = 8;
    localparam integer unsigned         DATA_WIDTH      = 32;
    localparam integer unsigned         ADDR_WIDTH      = 32;
    localparam integer unsigned         NB_MAX_COUNT    = 32;


    logic                               tb_clk       = 1'b0;
    logic                               tb_rst       = 1'b0;
    logic                               tb_pps       = 1'b0;
    logic [NB_MAX_COUNT-1   : 0]        tb_pps_count = '0;
    adsb_pkg::time_t                    tb_time_data;
    logic                               tb_time_data_valid;
    logic                               tb_rf_badframe;
    logic                               tb_rf_timeout;
    logic                               tb_rf_checksum_error;
    logic [DATA_WIDTH      -1:0]        tb_error_reg;

    axi4lite_intf #(
        .DATA_WIDTH( DATA_WIDTH ),
        .ADDR_WIDTH( ADDR_WIDTH )
    )
        i_axil_csr
    (
        .i_clk( tb_clk ),
        .i_rst( tb_rst )
    );

    axi4_stream_if
    #(
        .N_BYTES_TDATA  ( NB_DATA/8 )
    ) 
    axis_if
    (
        .i_clk          ( tb_clk    ),
        .i_rst          ( tb_rst    )
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

    utc_time
    #(
        .NB_MAX_COUNT         ( NB_MAX_COUNT ),
        .NB_TIMEOUT           ( NB_TIMEOUT   ),
        .TIMEOUT_MAX          ( TIMEOUT_MAX  )
    ) 
    dut 
    (
        .i_clk                  ( tb_clk                ),
        .i_rst                  ( tb_rst                ),
        .i_pps                  ( tb_pps                ),
        .o_pps_count            ( tb_pps_count          ),
        .s_axil                 ( i_axil_csr            ),
        .i_axis                 ( axis_if               ),
        .o_time_data            ( tb_time_data          ),
        .o_valid                ( tb_time_data_valid    )
    );

    assign tb_rf_badframe       = dut.csr_inputs.status_registers.error.badframe.next;
    assign tb_rf_timeout        = dut.csr_inputs.status_registers.error.timeout.next;
    assign tb_rf_checksum_error = dut.csr_inputs.status_registers.error.checksum_error.next;

    //===================================
    // Build
    //===================================
    initial begin
        $dumpfile("utc_time_test_2.vcd");
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
        axis_if.tvalid  =  1'b0;
        axis_if.tlast   =  1'b0;
        
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

    nmea_pkg::bytequeue nmea_msg_byte_array;
    integer unsigned data_index = 0;
    bit corrupt_checksum = 1'b0;
    bit corrupt_frame = 1'b0;
    bit [1:0] corrupt_frame_options = '0;
    nmea_pkg::nmea_generator nmea_gen;
    integer unsigned elements_deleted = 0;

    initial begin
        nmea_gen = new();
    end

    `SVUNIT_TESTS_BEGIN
        `include "tests.sv"
    `SVUNIT_TESTS_END 

endmodule

