// ============================================================================
// File: dmem_axis_writer_tc00.sv
// Description: SVUnit testbench top-level for dmem_axis_writer.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module dmem_axis_writer_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "dmem_axis_writer_ut";
    svunit_testcase svunit_ut;

    // =========================================================================
    // Parameters
    // =========================================================================
    localparam real CLOCK_FREQUENCY = 200e6;
    localparam int  N     = 10;
    localparam int  B     = 16;
    localparam int  DEPTH = 2**N;
    localparam int  BYTES = B / 8;

    // FSM state encodings (mirror of DUT state_t)
    localparam int  INIT_ST  = 0;
    localparam int  WRITE_ST = 1;
    localparam int  ACK_ST   = 2;
    localparam int  END_ST   = 3;

    // =========================================================================
    // Clock & Reset
    // =========================================================================
    logic tb_clk  = 1'b0;
    logic tb_rstn = 1'b1;

    // =========================================================================
    // Interfaces
    // =========================================================================
    bram_if #(
        .NB_DATA (B),
        .NB_ADDR (N)
    ) bram_if_i (
        .i_clk (tb_clk),
        .i_rst (~tb_rstn)
    );

    axi4_stream_if #(
        .TDATA_WIDTH (BYTES * 8),
        .HAS_TSTRB   (1'b0),
        .HAS_TKEEP   (1'b0),
        .HAS_TID     (1'b0),
        .HAS_TDEST   (1'b0),
        .HAS_TUSER   (1'b0)
    ) axis_if (
        .aclk    (tb_clk),
        .aresetn (tb_rstn)
    );

    // =========================================================================
    // BRAM model — faithful to bram_tdp: synchronous registered read,
    //   write-first, synchronous reset.
    // =========================================================================
    logic [B-1:0] mem [0:DEPTH-1];

    always_ff @(posedge tb_clk) begin
        if (~tb_rstn) begin
            bram_if_i.dout <= '0;
        end else if (bram_if_i.en) begin
            if (bram_if_i.we) begin
                mem[bram_if_i.addr] <= bram_if_i.din;
                bram_if_i.dout      <= bram_if_i.din;   // write-first
            end else begin
                bram_if_i.dout      <= mem[bram_if_i.addr];
            end
        end
    end

    // =========================================================================
    // Clock generator
    // =========================================================================
    clk_gen #(.FREQ (CLOCK_FREQUENCY)) u_clk_gen (
        .i_enable (1'b1),
        .o_clk    (tb_clk)
    );

    // =========================================================================
    // DUT control signals
    // =========================================================================
    logic         tb_exec_i = 1'b0;
    logic         tb_exec_ack_o;
    logic [N-1:0] tb_addr_i = '0;

    // =========================================================================
    // Clocking block
    // =========================================================================
    default clocking tb_cb @(posedge tb_clk);
        default input #1step output #2;
        output tb_rstn;
        output tb_exec_i;
        output tb_addr_i;
        input  tb_exec_ack_o;
    endclocking

    // =========================================================================
    // Dump file
    // =========================================================================
    initial begin
        $dumpfile("dmem_axis_writer.vcd");
        $dumpvars();
    end

    // =========================================================================
    // DUT
    // =========================================================================
    dmem_axis_writer #(
        .N (N),
        .B (B)
    ) u_dut (
        .clk        (tb_clk),
        .rstn       (tb_rstn),
        .exec_i     (tb_exec_i),
        .exec_ack_o (tb_exec_ack_o),
        .addr_i     (tb_addr_i),
        .bram       (bram_if_i.master),
        .axis       (axis_if.slave)
    );

    // =========================================================================
    // Helper tasks
    // =========================================================================
    task automatic reset_dut();
        tb_cb.tb_rstn   <= 1'b0;
        tb_cb.tb_exec_i <= 1'b0;
        tb_cb.tb_addr_i <= '0;
        axis_if.m_cb.tvalid <= 1'b0;
        axis_if.m_cb.tdata  <= '0;
        axis_if.m_cb.tlast  <= 1'b0;
        repeat(10) @(tb_cb);
        tb_cb.tb_rstn <= 1'b1;
        repeat(5) @(tb_cb);
    endtask

    // start_write: assert exec_i with start address (held until ACK)
    task automatic start_write(input logic [N-1:0] addr);
        tb_cb.tb_addr_i <= addr;
        tb_cb.tb_exec_i <= 1'b1;
    endtask

    // finish_write: deassert exec_i (END_ST -> INIT_ST)
    task automatic finish_write();
        tb_cb.tb_exec_i <= 1'b0;
    endtask

    // wait_state: wait until FSM reaches target (with timeout)
    task automatic wait_state(input int target, input int timeout = 500);
        int t = 0;
        while (u_dut.state !== target && t < timeout) begin
            @(tb_cb);
            t++;
        end
        if (t >= timeout)
            $display("[WARN] wait_state: timeout waiting for state %0d", target);
    endtask

    // stream_burst: send 'len' beats incrementing from start_val, honoring
    //   tready backpressure. Asserts tlast on the final beat.
    task automatic stream_burst(
        input int           len,
        input logic [B-1:0] start_val
    );
        for (int i = 0; i < len; i++) begin
            axis_if.m_cb.tdata  <= start_val + B'(i);
            axis_if.m_cb.tlast  <= (i == len-1) ? 1'b1 : 1'b0;
            axis_if.m_cb.tvalid <= 1'b1;
            do @(axis_if.m_cb); while (!axis_if.m_cb.tready);
        end
        axis_if.m_cb.tvalid <= 1'b0;
        axis_if.m_cb.tdata  <= '0;
        axis_if.m_cb.tlast  <= 1'b0;
    endtask

    // stream_burst_gapped: like stream_burst but inserts 'gap' idle cycles
    //   (tvalid low) between beats to exercise the pipeline.
    task automatic stream_burst_gapped(
        input int           len,
        input logic [B-1:0] start_val,
        input int           gap
    );
        for (int i = 0; i < len; i++) begin
            axis_if.m_cb.tdata  <= start_val + B'(i);
            axis_if.m_cb.tlast  <= (i == len-1) ? 1'b1 : 1'b0;
            axis_if.m_cb.tvalid <= 1'b1;
            do @(axis_if.m_cb); while (!axis_if.m_cb.tready);
            // idle gap
            axis_if.m_cb.tvalid <= 1'b0;
            axis_if.m_cb.tlast  <= 1'b0;
            repeat(gap) @(axis_if.m_cb);
        end
        axis_if.m_cb.tvalid <= 1'b0;
        axis_if.m_cb.tdata  <= '0;
        axis_if.m_cb.tlast  <= 1'b0;
    endtask

    // verify_mem: compare BRAM contents at [addr..addr+len-1] vs expected pattern
    task automatic verify_mem(
        input int           addr,
        input int           len,
        input logic [B-1:0] start_val,
        input string        test_name
    );
        for (int i = 0; i < len; i++) begin
            logic [B-1:0] exp = start_val + B'(i);
            if (mem[addr + i] !== exp) begin
                $display("MISMATCH %s [addr=0x%0h]: expected 0x%0h got 0x%0h",
                         test_name, addr + i, exp, mem[addr + i]);
                `FAIL_IF(1);
            end
        end
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
        tb_cb.tb_exec_i <= 1'b0;
        axis_if.m_cb.tvalid <= 1'b0;
        repeat(5) @(tb_cb);
    endtask

    // =========================================================================
    // Test cases
    // =========================================================================
    `SVUNIT_TESTS_BEGIN
    `include "dmem_axis_writer_tests.sv"
    `SVUNIT_TESTS_END

endmodule