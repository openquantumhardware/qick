// ============================================================================
// File: axis_to_bram_sg_nt_tc00.sv
// Description: SVUnit testbench top-level for axis_to_bram_sg_nt.
// ============================================================================

`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module axis_to_bram_sg_nt_unit_test;

    import svunit_pkg::svunit_testcase;

    string name = "axis_to_bram_sg_nt_ut";
    svunit_testcase svunit_ut;

    // =========================================================================
    // Parameters
    // =========================================================================
    localparam real CLOCK_FREQUENCY = 200e6;
    localparam int  NT      = 4;
    localparam int  N       = 8;
    localparam int  B       = 16;
    localparam int  BYTES   = B / 8;
    localparam int  NT_LOG2 = $clog2(NT);
    localparam int  DEPTH   = 2**N;   // per-table depth

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
    // NT-bank BRAM model
    // =========================================================================
    logic [NT-1:0] tb_mem_en;
    logic [B-1:0]  mem [NT][DEPTH];

    always_ff @(posedge tb_clk) begin
        if (bram_if_i.we) begin
            for (int b = 0; b < NT; b++) begin
                if (tb_mem_en[b])
                    mem[b][bram_if_i.addr] <= bram_if_i.din;
            end
        end
    end

    // =========================================================================
    // Clock generator & waveform
    // =========================================================================
    initial begin
        $dumpfile("axis_to_bram_sg_nt.vcd");
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
        input  tb_mem_en;
    endclocking

    // =========================================================================
    // DUT
    // =========================================================================
    axis_to_bram_sg_nt #(
        .NT (NT),
        .N  (N),
        .B  (B)
    ) u_dut (
        .rstn           (tb_rstn),
        .clk            (tb_clk),
        .axis           (axis_if.slave),
        .bram           (bram_if_i.master),
        .mem_en         (tb_mem_en),
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

    task automatic enable_writer(input logic [31:0] start_addr);
        tb_cb.tb_start_addr_reg <= start_addr;
        tb_cb.tb_capture_reg    <= 1'b1;
        repeat(6) @(tb_cb);
    endtask

    task automatic disable_writer();
        tb_cb.tb_capture_reg <= 1'b0;
        repeat(6) @(tb_cb);
    endtask

    task automatic stream_data(
        input int           count,
        input logic [B-1:0] start_val
    );
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

    task automatic wait_pipeline();
        repeat(15) @(tb_cb);
    endtask

    // Decode flat address into bank and local address
    // bank       = flat_addr % NT  (low NT_LOG2 bits)
    // local_addr = flat_addr / NT  (high N bits)
    task automatic verify_flat(
        input int            flat_addr,
        input logic [B-1:0]  expected,
        input string         test_name
    );
        int bank       = flat_addr % NT;
        int local_addr = flat_addr / NT;
        if (mem[bank][local_addr] !== expected) begin
            $display("MISMATCH %s [flat=%0d bank=%0d addr=%0d]: expected 0x%0h got 0x%0h",
                     test_name, flat_addr, bank, local_addr, expected, mem[bank][local_addr]);
            `FAIL_IF(1);
        end
    endtask

    task automatic verify_block(
        input int            start_flat,
        input int            count,
        input logic [B-1:0]  start_val,
        input string         test_name
    );
        for (int i = 0; i < count; i++)
            verify_flat(start_flat + i, start_val + B'(i), test_name);
    endtask

    // =========================================================================
    // SVUnit build / setup / teardown
    // =========================================================================
    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        for (int b = 0; b < NT; b++)
            for (int a = 0; a < DEPTH; a++)
                mem[b][a] = '0;
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
    `include "axis_to_bram_sg_nt_tests.sv"
    `SVUNIT_TESTS_END

endmodule
