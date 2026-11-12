// ============================================================================
// File: fifo_async_gated_tc00.sv
// Description: SVUnit testbench top-level for fifo_async_gated.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module fifo_async_gated_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "fifo_async_gated_ut";
    svunit_testcase svunit_ut;

    localparam real CLK_WR_FREQ = 200e6;
    localparam real CLK_RD_FREQ = 150e6;
    localparam int  FIFO_DW = 16;
    localparam int  FIFO_AW = 4;

    logic wr_clk = 1'b0;
    logic rd_clk = 1'b0;

    clk_gen #(.FREQ(CLK_WR_FREQ)) u_clk_wr (.i_enable(1'b1), .o_clk(wr_clk));
    clk_gen #(.FREQ(CLK_RD_FREQ)) u_clk_rd (.i_enable(1'b1), .o_clk(rd_clk));

    logic wr_rstn = 1'b1;
    logic rd_rstn = 1'b1;
    logic wr_en_i, push_i, rd_en_i, pop_i, flush_i = 1'b1;
    logic [FIFO_DW-1:0] data_i, data_o;
    logic async_empty_o, async_full_o;

    fifo_async_gated #(
        .FIFO_DW (FIFO_DW),
        .FIFO_AW (FIFO_AW)
    ) dut (
        .wr_clk_i      (wr_clk),
        .wr_rst_ni     (wr_rstn),
        .wr_en_i       (wr_en_i),
        .push_i        (push_i),
        .data_i        (data_i),
        .rd_clk_i      (rd_clk),
        .rd_rst_ni     (rd_rstn),
        .rd_en_i       (rd_en_i),
        .pop_i         (pop_i),
        .flush_i       (flush_i),
        .data_o        (data_o),
        .async_empty_o (async_empty_o),
        .async_full_o  (async_full_o)
    );

    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        flush_i = 1'b1;
        repeat (500) @(posedge wr_clk);
        flush_i = 1'b0;
        repeat (100) @(posedge wr_clk);
        {wr_en_i, push_i, rd_en_i, pop_i} = '0;
        data_i = '0;
        #2;
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    `SVUNIT_TESTS_BEGIN
    `include "fifo_async_gated_tests.sv"
    `SVUNIT_TESTS_END

endmodule
