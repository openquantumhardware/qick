// ============================================================================
// File: dmem_axis_reader_tc00.sv
// Description: SVUnit testbench top-level for dmem_axis_reader.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module dmem_axis_reader_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "dmem_axis_reader_ut";
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
    localparam int  LOAD0_ST = 1;
    localparam int  LOAD1_ST = 2;
    localparam int  SEND_ST  = 3;
    localparam int  ACK_ST   = 4;
    localparam int  END_ST   = 5;

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
    //   write-first, synchronous reset.  Read latency = 1 cycle.
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
    logic [N-1:0] tb_len_i  = '0;

    // =========================================================================
    // Clocking block
    // =========================================================================
    default clocking tb_cb @(posedge tb_clk);
        default input #1step output #2;
        output tb_rstn;
        output tb_exec_i;
        output tb_addr_i;
        output tb_len_i;
        input  tb_exec_ack_o;
    endclocking

    // =========================================================================
    // Dump file
    // =========================================================================
    initial begin
        $dumpfile("dmem_axis_reader.vcd");
        $dumpvars();
    end

    // =========================================================================
    // DUT
    // =========================================================================
    dmem_axis_reader #(
        .N (N),
        .B (B)
    ) u_dut (
        .clk        (tb_clk),
        .rstn       (tb_rstn),
        .exec_i     (tb_exec_i),
        .exec_ack_o (tb_exec_ack_o),
        .addr_i     (tb_addr_i),
        .len_i      (tb_len_i),
        .bram       (bram_if_i.master),
        .axis       (axis_if.master)
    );

    // =========================================================================
    // Helper tasks
    // =========================================================================
    task automatic reset_dut();
        tb_cb.tb_rstn   <= 1'b0;
        tb_cb.tb_exec_i <= 1'b0;
        tb_cb.tb_addr_i <= '0;
        tb_cb.tb_len_i  <= '0;
        axis_if.s_cb.tready <= 1'b0;
        repeat(10) @(tb_cb);
        tb_cb.tb_rstn <= 1'b1;
        repeat(5) @(tb_cb);
    endtask

    // preload_mem: fill mem[addr..addr+len-1] with start_val++ pattern
    task automatic preload_mem(
        input int           addr,
        input int           len,
        input logic [B-1:0] start_val
    );
        for (int i = 0; i < len; i++)
            mem[addr + i] = start_val + B'(i);
    endtask

    // start_read: assert exec_i with addr/len (held until ACK seen)
    task automatic start_read(
        input logic [N-1:0] addr,
        input logic [N-1:0] len
    );
        tb_cb.tb_addr_i <= addr;
        tb_cb.tb_len_i  <= len;
        tb_cb.tb_exec_i <= 1'b1;
    endtask

    // finish_read: deassert exec_i (END_ST -> INIT_ST)
    task automatic finish_read();
        tb_cb.tb_exec_i <= 1'b0;
    endtask

    // set_tready: control AXIS sink readiness
    task automatic set_tready(input logic v);
        axis_if.s_cb.tready <= v;
    endtask

    // collect_stream: capture 'expected_len' beats from AXIS into data[],
    //   with continuous tready. Records last-beat tlast in saw_tlast.
    task automatic collect_stream(
        input  int            expected_len,
        output logic [B-1:0]  data[],
        output logic          saw_tlast,
        input  int            timeout = 500
    );
        int idx = 0;
        int t   = 0;
        data = new[expected_len];
        saw_tlast = 1'b0;
        axis_if.s_cb.tready <= 1'b1;
        while (idx < expected_len && t < timeout) begin
            @(axis_if.s_cb);
            if (axis_if.s_cb.tvalid && axis_if.tready) begin
                data[idx] = axis_if.s_cb.tdata;
                if (axis_if.s_cb.tlast) saw_tlast = 1'b1;
                idx++;
            end
            t++;
        end
        axis_if.s_cb.tready <= 1'b0;
        if (t >= timeout)
            $display("[WARN] collect_stream: timeout (got %0d of %0d beats)",
                     idx, expected_len);
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

    // verify_data: compare expected vs actual arrays
    task automatic verify_data(
        input logic [B-1:0] expected[],
        input logic [B-1:0] actual[],
        input string        test_name
    );
        if (expected.size() != actual.size()) begin
            $display("SIZE MISMATCH %s: expected %0d got %0d",
                     test_name, expected.size(), actual.size());
            `FAIL_IF(1);
        end
        for (int i = 0; i < expected.size(); i++) begin
            if (expected[i] !== actual[i]) begin
                $display("MISMATCH %s [%0d]: expected 0x%0h got 0x%0h",
                         test_name, i, expected[i], actual[i]);
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
        axis_if.s_cb.tready <= 1'b0;
        repeat(5) @(tb_cb);
    endtask

    // =========================================================================
    // Test cases
    // =========================================================================
    `SVUNIT_TESTS_BEGIN
    `include "dmem_axis_reader_tests.sv"
    `SVUNIT_TESTS_END

endmodule