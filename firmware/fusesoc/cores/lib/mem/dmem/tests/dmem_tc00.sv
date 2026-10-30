// ============================================================================
// File: dmem_tc00.sv
// Description: SVUnit testbench top-level for dmem (integration).
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module dmem_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "dmem_ut";
    svunit_testcase svunit_ut;

    // =========================================================================
    // Parameters
    // =========================================================================
    localparam real CLOCK_FREQUENCY = 200e6;
    localparam int  N     = 10;          // smaller depth for faster sim
    localparam int  B     = 32;
    localparam int  DEPTH = 2**N;
    localparam int  BYTES = B / 8;

    // =========================================================================
    // Clock & Reset
    // =========================================================================
    logic tb_clk  = 1'b0;
    logic tb_rstn = 1'b1;

    // =========================================================================
    // AXIS interfaces
    //   s_axis : TB drives (master) -> DUT slave   (AXIS write path)
    //   m_axis : DUT drives (master) -> TB sinks    (AXIS read path)
    // =========================================================================
    axi4_stream_if #(
        .TDATA_WIDTH (BYTES * 8),
        .HAS_TSTRB   (1'b0),
        .HAS_TKEEP   (1'b0),
        .HAS_TID     (1'b0),
        .HAS_TDEST   (1'b0),
        .HAS_TUSER   (1'b0)
    ) s_axis_if (
        .aclk    (tb_clk),
        .aresetn (tb_rstn)
    );

    axi4_stream_if #(
        .TDATA_WIDTH (BYTES * 8),
        .HAS_TSTRB   (1'b0),
        .HAS_TKEEP   (1'b0),
        .HAS_TID     (1'b0),
        .HAS_TDEST   (1'b0),
        .HAS_TUSER   (1'b0)
    ) m_axis_if (
        .aclk    (tb_clk),
        .aresetn (tb_rstn)
    );

    // =========================================================================
    // External BRAM model — faithful to bram_tdp: synchronous registered read,
    //   write-first, synchronous reset. Connected via flat mem_* ports.
    // =========================================================================
    logic [B-1:0] mem [0:DEPTH-1];

    logic         tb_mem_we;
    logic [B-1:0] tb_mem_di;
    logic [B-1:0] tb_mem_do;
    logic [N-1:0] tb_mem_addr;

    always_ff @(posedge tb_clk) begin
        if (~tb_rstn) begin
            tb_mem_do <= '0;
        end else begin
            // BRAM is always enabled (en=1 in real bram_tdp port usage here)
            if (tb_mem_we) begin
                mem[tb_mem_addr] <= tb_mem_di;
                tb_mem_do        <= tb_mem_di;   // write-first
            end else begin
                tb_mem_do        <= mem[tb_mem_addr];
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
    // DUT signals
    // =========================================================================
    logic         tb_busy_o;
    logic         tb_oper_i   = 1'b0;
    logic [N-1:0] tb_addr_i   = '0;
    logic [B-1:0] tb_din_i    = '0;
    logic [B-1:0] tb_dout_o;
    logic         tb_exec_i   = 1'b0;
    logic         tb_exec_ack_o;

    logic         tb_mode_reg  = 1'b0;
    logic         tb_start_reg = 1'b0;
    logic [N-1:0] tb_addr_reg  = '0;
    logic [N-1:0] tb_len_reg   = '0;

    // =========================================================================
    // Clocking block
    // =========================================================================
    default clocking tb_cb @(posedge tb_clk);
        default input #1step output #2;
        output tb_rstn;
        output tb_oper_i;
        output tb_addr_i;
        output tb_din_i;
        output tb_exec_i;
        output tb_mode_reg;
        output tb_start_reg;
        output tb_addr_reg;
        output tb_len_reg;
        input  tb_busy_o;
        input  tb_dout_o;
        input  tb_exec_ack_o;
    endclocking

    // =========================================================================
    // Dump file
    // =========================================================================
    initial begin
        $dumpfile("dmem.vcd");
        $dumpvars();
    end

    // =========================================================================
    // DUT
    // =========================================================================
    dmem #(
        .N (N),
        .B (B)
    ) u_dut (
        .clk        (tb_clk),
        .rstn       (tb_rstn),
        // Single-access
        .busy_o     (tb_busy_o),
        .oper_i     (tb_oper_i),
        .addr_i     (tb_addr_i),
        .din_i      (tb_din_i),
        .dout_o     (tb_dout_o),
        .exec_i     (tb_exec_i),
        .exec_ack_o (tb_exec_ack_o),
        // External BRAM
        .mem_we_o   (tb_mem_we),
        .mem_di_o   (tb_mem_di),
        .mem_do_i   (tb_mem_do),
        .mem_addr_o (tb_mem_addr),
        // AXIS
        .s_axis     (s_axis_if.slave),
        .m_axis     (m_axis_if.master),
        // Control registers
        .mode_reg   (tb_mode_reg),
        .start_reg  (tb_start_reg),
        .addr_reg   (tb_addr_reg),
        .len_reg    (tb_len_reg)
    );

    // =========================================================================
    // Helper tasks
    // =========================================================================
    task automatic reset_dut();
        tb_cb.tb_rstn      <= 1'b0;
        tb_cb.tb_oper_i    <= 1'b0;
        tb_cb.tb_addr_i    <= '0;
        tb_cb.tb_din_i     <= '0;
        tb_cb.tb_exec_i    <= 1'b0;
        tb_cb.tb_mode_reg  <= 1'b0;
        tb_cb.tb_start_reg <= 1'b0;
        tb_cb.tb_addr_reg  <= '0;
        tb_cb.tb_len_reg   <= '0;
        s_axis_if.m_cb.tvalid <= 1'b0;
        s_axis_if.m_cb.tdata  <= '0;
        s_axis_if.m_cb.tlast  <= 1'b0;
        m_axis_if.s_cb.tready <= 1'b0;
        repeat(10) @(tb_cb);
        tb_cb.tb_rstn <= 1'b1;
        repeat(5) @(tb_cb);
    endtask

    // -------------------------------------------------------------------------
    // Single-access read/write (processor path, sel=0, requires !busy)
    // -------------------------------------------------------------------------
    task automatic wait_exec_ack(input int timeout = 32);
        int t = 0;
        while (tb_exec_ack_o !== 1'b1 && t < timeout) begin
            @(tb_cb);
            t++;
        end
        if (t >= timeout)
            $display("[WARN] wait_exec_ack: timeout");
    endtask

    task automatic single_write(input logic [N-1:0] addr, input logic [B-1:0] data);
        @(tb_cb);
        tb_cb.tb_oper_i <= 1'b1;       // write
        tb_cb.tb_addr_i <= addr;
        tb_cb.tb_din_i  <= data;
        tb_cb.tb_exec_i <= 1'b1;
        wait_exec_ack();
        @(tb_cb);
        tb_cb.tb_exec_i <= 1'b0;
        @(tb_cb);
    endtask

    task automatic single_read(input logic [N-1:0] addr, output logic [B-1:0] data);
        @(tb_cb);
        tb_cb.tb_oper_i <= 1'b0;       // read
        tb_cb.tb_addr_i <= addr;
        tb_cb.tb_exec_i <= 1'b1;
        wait_exec_ack();
        data = tb_exec_ack_o ? tb_dout_o : 'x;
        @(tb_cb);
        tb_cb.tb_exec_i <= 1'b0;
        @(tb_cb);
    endtask

    // -------------------------------------------------------------------------
    // AXIS write transaction: stream 'len' beats into mem starting at addr
    // -------------------------------------------------------------------------
    task automatic axis_write(
        input logic [N-1:0] addr,
        input int           len,
        input logic [B-1:0] start_val
    );
        // Configure registers and start (MODE=1 write)
        tb_cb.tb_mode_reg  <= 1'b1;
        tb_cb.tb_addr_reg  <= addr;
        tb_cb.tb_start_reg <= 1'b1;
        // Wait for busy (transaction accepted)
        do @(tb_cb); while (!tb_busy_o);
        // Stream the burst (writer asserts tready in WRITE_ST)
        for (int i = 0; i < len; i++) begin
            s_axis_if.m_cb.tdata  <= start_val + B'(i);
            s_axis_if.m_cb.tlast  <= (i == len-1) ? 1'b1 : 1'b0;
            s_axis_if.m_cb.tvalid <= 1'b1;
            do @(s_axis_if.m_cb); while (!s_axis_if.m_cb.tready);
        end
        s_axis_if.m_cb.tvalid <= 1'b0;
        s_axis_if.m_cb.tdata  <= '0;
        s_axis_if.m_cb.tlast  <= 1'b0;
        // Wait for transaction to finish (busy deasserts) then clear START
        do @(tb_cb); while (tb_busy_o);
        tb_cb.tb_start_reg <= 1'b0;
        repeat(3) @(tb_cb);
    endtask

    // -------------------------------------------------------------------------
    // AXIS read transaction: stream 'len' beats out of mem starting at addr
    //   captures the stream into data[], records tlast.
    // -------------------------------------------------------------------------
    task automatic axis_read(
        input  logic [N-1:0] addr,
        input  int           len,
        output logic [B-1:0] data[],
        output logic         saw_tlast,
        input  int           timeout = 500
    );
        int idx = 0;
        int t   = 0;
        data = new[len];
        saw_tlast = 1'b0;
        // Configure registers and start (MODE=0 read)
        tb_cb.tb_mode_reg  <= 1'b0;
        tb_cb.tb_addr_reg  <= addr;
        tb_cb.tb_len_reg   <= N'(len);
        tb_cb.tb_start_reg <= 1'b1;
        m_axis_if.s_cb.tready <= 1'b1;
        // Capture beats
        while (idx < len && t < timeout) begin
            @(m_axis_if.s_cb);
            if (m_axis_if.s_cb.tvalid && m_axis_if.tready) begin
                data[idx] = m_axis_if.s_cb.tdata;
                if (m_axis_if.s_cb.tlast) saw_tlast = 1'b1;
                idx++;
            end
            t++;
        end
        m_axis_if.s_cb.tready <= 1'b0;
        if (t >= timeout)
            $display("[WARN] axis_read: timeout (got %0d of %0d)", idx, len);
        // Finish: wait busy low, clear START
        do @(tb_cb); while (tb_busy_o);
        tb_cb.tb_start_reg <= 1'b0;
        repeat(3) @(tb_cb);
    endtask

    // verify_mem: compare BRAM model vs incrementing pattern
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

    // verify_data: compare two arrays
    task automatic verify_data(
        input logic [B-1:0] expected[],
        input logic [B-1:0] actual[],
        input string        test_name
    );
        if (expected.size() != actual.size()) begin
            $display("SIZE MISMATCH %s: exp %0d got %0d",
                     test_name, expected.size(), actual.size());
            `FAIL_IF(1);
        end
        for (int i = 0; i < expected.size(); i++) begin
            if (expected[i] !== actual[i]) begin
                $display("MISMATCH %s [%0d]: exp 0x%0h got 0x%0h",
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
        tb_cb.tb_exec_i    <= 1'b0;
        tb_cb.tb_start_reg <= 1'b0;
        s_axis_if.m_cb.tvalid <= 1'b0;
        m_axis_if.s_cb.tready <= 1'b0;
        repeat(5) @(tb_cb);
    endtask

    // =========================================================================
    // Test cases
    // =========================================================================
    `SVUNIT_TESTS_BEGIN
    `include "dmem_tests.sv"
    `SVUNIT_TESTS_END

endmodule