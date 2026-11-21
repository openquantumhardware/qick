// ============================================================================
// File: axis_to_bram_sg_tc00.sv
// Description: SVUnit testbench top-level for axis_to_bram_sg.
// ============================================================================

`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module axis_to_bram_sg_unit_test;

    import svunit_pkg::svunit_testcase;

    string name = "axis_to_bram_sg_ut";
    svunit_testcase svunit_ut;

    // =========================================================================
    // Parameters
    // =========================================================================
    localparam real CLOCK_FREQUENCY = 200e6;
    localparam int  N     = 8;
    localparam int  B     = 16;
    localparam int  DEPTH = 2**N;
    localparam int  BYTES = B / 8;

    // =========================================================================
    // Clock & Reset
    // =========================================================================
    logic tb_clk  = 1'b0;
    logic tb_rstn = 1'b1;

    // =========================================================================
    // Interfaces
    // =========================================================================
  axi4_stream_if #(
      .TDATA_WIDTH   (BYTES * 8),
      .HAS_TSTRB     (1'b0),
      .HAS_TKEEP     (1'b0),
      .HAS_TID       (1'b0),
      .HAS_TDEST     (1'b0),
      .HAS_TUSER     (1'b0)
    ) axis_if (
      .aclk    (tb_clk),
      .aresetn (tb_rstn)
    );

    bram_if #(
        .NB_DATA (B),
        .NB_ADDR (N)
    ) bram_if_i (
        .i_clk (tb_clk),
        .i_rst (~tb_rstn)
    );

    // =========================================================================
    // BRAM model
    // =========================================================================
    logic [B-1:0] mem [0:DEPTH-1];

    always_ff @(posedge tb_clk) begin
        if (bram_if_i.en && bram_if_i.we) begin
            $display("[BRAM] write addr=%0h data=%0h", bram_if_i.addr, bram_if_i.din);
            mem[bram_if_i.addr] <= bram_if_i.din;
        end
    end

    // =========================================================================
    // Clock generator & waveform
    // =========================================================================
    initial begin
        $dumpfile("axis_to_bram_sg.vcd");
        $dumpvars();
    end

    clk_gen #(.FREQ (CLOCK_FREQUENCY)) u_clk_gen (
        .i_enable (1'b1),
        .o_clk    (tb_clk)
    );

    // =========================================================================
    // Control signals
    // =========================================================================
    logic [31:0] tb_start_addr_reg = '0;
    logic        tb_capture_reg    = 1'b0;

    // =========================================================================
    // Clocking block
    // =========================================================================
    default clocking tb_cb @(posedge tb_clk);
        default input #1step output #2;
        output tb_rstn;
        output tb_start_addr_reg;
        output tb_capture_reg;
    endclocking

    // =========================================================================
    // DUT
    // =========================================================================
    axis_to_bram_sg #(
        .N (N),
        .B (B)
    ) u_dut (
        .rstn           (tb_rstn),
        .clk            (tb_clk),
        .axis           (axis_if.slave),
        .bram           (bram_if_i.master),
        .start_addr_reg (tb_start_addr_reg),
        .capture_reg    (tb_capture_reg)
    );

    // =========================================================================
    // Helper tasks
    // =========================================================================

    task automatic reset_dut();
        tb_cb.tb_rstn           <= 1'b0;
        tb_cb.tb_capture_reg    <= 1'b0;
        tb_cb.tb_start_addr_reg <= '0;
        axis_if.m_cb.tvalid     <= 1'b0;
        axis_if.m_cb.tdata      <= '0;
        axis_if.m_cb.tlast      <= 1'b0;
        repeat(10) @(tb_cb);
        tb_cb.tb_rstn <= 1'b1;
        repeat(5) @(tb_cb);
    endtask

    // enable: assert capture_reg and latch start_addr, wait for CDC + FSM
    // to reach WAIT_TVALID_ST (2 CDC cycles + READ_START_ADDR_ST cycle)
    task automatic enable_writer(input logic [31:0] start_addr);
        tb_cb.tb_start_addr_reg <= start_addr;
        tb_cb.tb_capture_reg    <= 1'b1;
        repeat(6) @(tb_cb);
    endtask

    // disable: de-assert capture_reg, FSM returns to INIT_ST
    task automatic disable_writer();
        tb_cb.tb_capture_reg <= 1'b0;
        repeat(6) @(tb_cb);
    endtask

    // stream_data: send count samples via AXI4-Stream, incrementing from start_val
    task automatic stream_data(
        input int           count,
        input logic [B-1:0] start_val
    );
        //lineup wait
        @(axis_if.m_cb);
        for (int i = 0; i < count; i++) begin
            axis_if.m_cb.tdata  <= start_val + B'(i);
            axis_if.m_cb.tlast  <= (i == count-1) ? 1'b1 : 1'b0;
            axis_if.m_cb.tvalid <= 1'b1;

            do @(axis_if.m_cb); while (!axis_if.m_cb.tready);
        end
        axis_if.m_cb.tvalid <= 1'b0;
        axis_if.m_cb.tdata  <= '0;
        axis_if.m_cb.tlast  <= 1'b0;
    endtask

    // wait_pipeline: wait enough cycles for 3-stage pipeline to flush
    task automatic wait_pipeline();
        repeat(8) @(tb_cb);
    endtask

    // verify_mem: check BRAM model at a flat address, decoding bank/row
    task automatic verify_mem(
        input int            flat_addr,
        input logic [B-1:0]  expected_data,
        input string         test_name
    );
        if (mem[flat_addr] !== expected_data) begin
            $display("MISMATCH %s [addr=%0d]: expected 0x%0h got 0x%0h",
                     test_name, flat_addr, expected_data, mem[flat_addr]);
            `FAIL_IF(1);
        end
    endtask

    // verify_block: check a contiguous block starting at start_addr
    task automatic verify_block(
        input int            start_addr,
        input int            count,
        input logic [B-1:0]  start_val,
        input string         test_name
    );
        for (int i = 0; i < count; i++)
            verify_mem(start_addr + i, start_val + B'(i), test_name);
    endtask

    // =========================================================================
    // SVUnit build / setup / teardown
    // =========================================================================
    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        for (int i = 0; i < DEPTH; i++) mem[i] = '0;
        reset_dut();
    endtask

    task teardown();
        svunit_ut.teardown();
        disable_writer();
        repeat(5) @(tb_cb);
    endtask

    // =========================================================================
    // Test cases
    // =========================================================================
    `SVUNIT_TESTS_BEGIN
    `include "axis_to_bram_sg_tests.sv"
    `SVUNIT_TESTS_END

endmodule
