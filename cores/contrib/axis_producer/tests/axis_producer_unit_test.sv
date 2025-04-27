`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module axis_producer_unit_test;

    import svunit_pkg::svunit_testcase;
    
    initial begin
        $dumpfile("test.vcd");
        $dumpvars;
    end

    localparam integer unsigned          MEM_NB_DATA       = 32;
    localparam integer unsigned          MEM_NB_ADDR       = 4;
    localparam string                    MEM_BIN_FILE      = "";
    localparam integer unsigned          NB_DATA           = 32;
    localparam logic   [MEM_NB_ADDR-1:0] START_ADDR_OFFSET = '0;
    localparam logic   [MEM_NB_ADDR-1:0] END_ADDR          = '1;

    string name = "axis_producer_ut";
    svunit_testcase svunit_ut;

    logic               tb_i_clk;
    logic               tb_i_rst;

    logic               tb_i_maxi_ready;
    logic               tb_o_maxi_valid;
    logic [NB_DATA-1:0] tb_o_maxi_data;

    logic               tb_o_event_last_addr;

    clk_gen#(.FREQ(100e6)) u_clk_gen(
        .i_enable(1'b1),
        .o_clk   (tb_i_clk)
    );
    default clocking cb @(posedge tb_i_clk);
    endclocking


    //===================================
    // This is the UUT that we're 
    // running the Unit Tests on
    //===================================
    axis_producer#(
        .MEM_NB_DATA      (MEM_NB_DATA      ),
        .MEM_NB_ADDR      (MEM_NB_ADDR      ),
        .MEM_BIN_FILE     (MEM_BIN_FILE     ),
        .NB_DATA          (NB_DATA          ),
        .START_ADDR_OFFSET(START_ADDR_OFFSET),
        .END_ADDR         (END_ADDR         )
    ) dut(
        .i_clk            (tb_i_clk            ),
        .i_rst            (tb_i_rst            ),
        .i_maxi_ready     (tb_i_maxi_ready     ),
        .o_maxi_valid     (tb_o_maxi_valid     ),
        .o_maxi_data      (tb_o_maxi_data      ),
        .o_event_last_addr(tb_o_event_last_addr)
    );

    bit [MEM_NB_ADDR-1:0] pos;


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
        load_rand_memory();

        tb_i_maxi_ready = 1'b0;
        ##1 tb_i_rst = 1'b1;
        pos = 0;
        ##1;
        tb_i_rst = 1'b0;
        ##5;
    endtask


    //===================================
    // Here we deconstruct anything we 
    // need after running the Unit Tests
    //===================================
    task teardown();
        svunit_ut.teardown();
    endtask

    task load_rand_memory();
        for(int i=0; i < (1 << 4); i++) begin
            dut.u_bram.bram_data[i] = $urandom();
        end
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
    //     `SVTEST(mytest)
    //         <test code>
    //     `SVTEST_END
    //===================================
    logic [MEM_NB_DATA-1:0] mem_data [1 << MEM_NB_ADDR];
    assign mem_data = dut.u_bram.bram_data;

    bit transaction;
    assign transaction = tb_i_maxi_ready & tb_o_maxi_valid;


    // Checks the output follows the memory in order
    property valid_output;
        @(posedge tb_i_clk) (transaction, pos++) |-> mem_data[pos] == tb_o_maxi_data;
    endproperty
    `ASSERT_CONCURRENT_LOG(valid_output, $sformatf("Expected: %h - Obtained: %h", mem_data[pos], tb_o_maxi_data));

    // Checks the address is incremented on each transaction
    property addr_inc;
        @(posedge tb_i_clk) transaction |=> ($past(dut.mem_rd_addr) + 1)%(1<<MEM_NB_ADDR) == dut.mem_rd_addr;
    endproperty `ASSERT_CONCURRENT_LOG(addr_inc, $sformatf("Expected address increment after transaction"));

    // Checks address wrapping after reaching end of address space
    property addr_wrap;
        @(posedge tb_i_clk) transaction & (dut.mem_rd_addr == END_ADDR) |=> dut.mem_rd_addr == START_ADDR_OFFSET;
    endproperty `ASSERT_CONCURRENT_LOG(addr_wrap, $sformatf("Invalid address wrapping"));

    // Checks last_addr event when reaching end of address space
    property last_event;
        @(posedge tb_i_clk) tb_o_maxi_data == mem_data[END_ADDR] |-> tb_o_event_last_addr;
    endproperty `ASSERT_CONCURRENT_LOG(last_event, $sformatf("Expected event last_addr"));

    // Checks last_addr event is not set when not at the end
    property unexpected_last_event;
        @(posedge tb_i_clk) tb_o_maxi_data != mem_data[END_ADDR] |-> ~tb_o_event_last_addr;
    endproperty `ASSERT_CONCURRENT_LOG(unexpected_last_event, $sformatf("Unexpected event last_addr"));

    // Checks valid is not set while in reset
    property not_valid_reset;
        @(posedge tb_i_clk) tb_i_rst |=> ~tb_o_maxi_valid;
    endproperty `ASSERT_CONCURRENT_LOG(not_valid_reset, $sformatf("Valid shouldn't be set while in reset"));

    `SVUNIT_TESTS_BEGIN
        `SVTEST(full_througput_test)
            tb_i_maxi_ready = 1'b1;
            for (int i = 0; i < 100; i++) begin
                ##1;
            end
        `SVTEST_END

        `SVTEST(random_valid_test)
            for (int i = 0; i < 100; i++) begin
                tb_i_maxi_ready = $urandom() & 1'b1;
                ##1;
            end
        `SVTEST_END
    `SVUNIT_TESTS_END

endmodule
