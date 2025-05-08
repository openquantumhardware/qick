`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module memory_data_dispatcher_00_generator_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "memory_data_dispatcher_00_ut";
    svunit_testcase svunit_ut;

    ////////////////////////////////////////////////////////
    // El test esta harcodeaodo para funcionar con N_MEM = 2
    ////////////////////////////////////////////////////////
    localparam integer unsigned CLOCK_FREQUENCY = 100e6; //[Hz]

    localparam integer unsigned NB_LEN          = 4 ;
    localparam integer unsigned NB_BASE_ADDRESS = 4 ;
    localparam integer unsigned MEM_NB_DATA     = 32;
    localparam string           MEM_BIN_FILE    = "";
    localparam integer unsigned NB_DEPTH        = 6 ;
    localparam integer unsigned N_MEM           = 2 ;
    localparam integer unsigned NB_DATA = NB_LEN + NB_BASE_ADDRESS;

    localparam integer unsigned AXI_DWIDTH  = MEM_NB_DATA;
    localparam integer unsigned ADDR_LSB = $clog2(AXI_DWIDTH/8);
    localparam integer unsigned AXI_AWIDTH  = NB_DEPTH + ADDR_LSB;

    logic tb_clk;
    logic tb_rst = 1'b0;
    logic tb_enable_i = '0;
    logic tb_axil_rd_en_i = 1'b0;
    logic tb_axil_wr_en_i = 1'b0;
    logic [NB_LEN      -1:0] tb_counter_value_o;

    bram_if #(
        .NB_DATA ( MEM_NB_DATA ),
        .NB_ADDR ( NB_DEPTH )
    )
    i_bram_if
    (
      .i_clk ( tb_clk ),
      .i_rst ( tb_rst )
    );

    axi4lite_intf #(
        .DATA_WIDTH ( AXI_DWIDTH ),
        .ADDR_WIDTH ( AXI_AWIDTH )
    ) 
    axi4_lite_in_if
    (
        .i_clk ( tb_clk ),
        .i_rst ( tb_rst )
    );

    axi4_stream_if
    #(
        .N_BYTES_TDATA ($ceil(NB_DATA)/8.0)
    ) 
    s_axis_if
    (
        .i_clk (tb_clk), 
        .i_rst (tb_rst)
    );
    
    data_stream_if
    #(
        .NB_DATA ( MEM_NB_DATA*N_MEM )
    )
    m_datas_if
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

    //===================================
    // This is the UUT that we're
    // running the Unit Tests on
    //===================================

    memory_data_dispatcher
    #(
        .NB_LEN ( NB_LEN ),
        .NB_BASE_ADDRESS ( NB_BASE_ADDRESS ),
        .MEM_BIN_FILE ( MEM_BIN_FILE ),
        .N_MEM ( N_MEM )
    )
    u_memory_data_dispatcher
    (
        .i_clk ( tb_clk ),
        .i_rst ( tb_rst ),
        .i_enable ( tb_enable_i ),
        .i_bram_if (i_bram_if),
        .i_axis ( s_axis_if ),
        .i_axil ( axi4_lite_in_if ),
        .i_rf_axil_rd_en ( tb_axil_rd_en_i ),
        .i_rf_axil_wr_en ( tb_axil_wr_en_i ),
        .o_counter_value ( tb_counter_value_o ),
        .o_datas ( m_datas_if )
    );

    //===================================
    // Build
    //===================================
    initial begin
        $dumpfile("memory_data_dispatcher_test.vcd");
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

        tb_axil_rd_en_i <= 1'b0;
        tb_axil_wr_en_i <= 1'b0;

        tb_enable_i <= 1'b1;

        s_axis_if.tdata <= '0;
        s_axis_if.tvalid <= 1'b0;
        s_axis_if.tlast <= 1'b0;
        s_axis_if.tuser <= 1'b0;

        i_bram_if.addr <= '0;
        i_bram_if.data <= '0;
        i_bram_if.we <= '0;

        axi4_lite_in_if.AWVALID<= 1'b0;
        axi4_lite_in_if.AWADDR <=   '0;
        axi4_lite_in_if.AWPROT <=   '0;
        axi4_lite_in_if.WVALID <= 1'b0;
        axi4_lite_in_if.WDATA  <=   '0;
        axi4_lite_in_if.WSTRB  <=   '0;
        axi4_lite_in_if.BREADY <= 1'b0;
        axi4_lite_in_if.ARVALID<= 1'b0;
        axi4_lite_in_if.ARADDR <=   '0;
        axi4_lite_in_if.ARPROT <=   '0;
        axi4_lite_in_if.RREADY <= 1'b0;

        tb_rst <= 1'b1;

        @(negedge tb_clk);

        tb_rst <= 1'b0;

        @(negedge tb_clk);
        repeat(10)@(negedge tb_clk);

        load_memory();

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

    typedef struct packed {
        logic [NB_LEN -1:0] tb_len;
        logic [NB_BASE_ADDRESS -1:0] tb_base_address;
    } tb_cam_t;
    tb_cam_t tb_data [10] = {'h55,'h65,'h23,'h45,'h67,'h85,'h43,'h34,'h62,'h73};
    tb_cam_t tb_data_1;

    logic [NB_LEN -1:0] tb_count = '0;
    logic [3:0] value = 'h0;
    logic [MEM_NB_DATA * (2**NB_DEPTH)/N_MEM -1:0] tb_bram_data_full_lsb;
    logic [MEM_NB_DATA * (2**NB_DEPTH)/N_MEM -1:0] tb_bram_data_full_msb;
    logic [MEM_NB_DATA*N_MEM -1 : 0] data_out_concat;
    logic [MEM_NB_DATA -1 : 0] data_out;


    task load_memory();
        value = 'h0;
        i_bram_if.we <= '1;

        for (int i = 0 ; i < (1 << NB_DEPTH) ; i++) begin
            i_bram_if.data <= {MEM_NB_DATA{value}};
            i_bram_if.addr <= i;

            @(negedge tb_clk);

            value = value + 1'b1;
        end
        i_bram_if.we <= '0;
        tb_bram_data_full_lsb <= {<<MEM_NB_DATA{u_memory_data_dispatcher.u_bram_linked.g_brams[0].u_bram.bram_data}};
        tb_bram_data_full_msb <= {<<MEM_NB_DATA{u_memory_data_dispatcher.u_bram_linked.g_brams[1].u_bram.bram_data}};
        repeat(10)@(negedge tb_clk);
    endtask

    task axis_transaction();
        s_axis_if.tvalid <= 1'b1;

        while (s_axis_if.tready == 1'b0) begin
            @(negedge tb_clk);
        end
        @(posedge tb_clk);
        `ASSERT_IMMEDIATE(s_axis_if.tready & s_axis_if.tvalid);

        @(negedge tb_clk);

        s_axis_if.tvalid <= 1'b0;
        `ASSERT_IMMEDIATE(m_datas_if.valid == 1'b0);
        `ASSERT_IMMEDIATE(m_datas_if.last == 1'b0);
    endtask

    `SVUNIT_TESTS_BEGIN
        `include "tests_00.sv"
    `SVUNIT_TESTS_END 

endmodule
