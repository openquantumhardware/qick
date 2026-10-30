// ============================================================================
// File: dmem_single_rw_tc00.sv
// Description: SVUnit testbench top-level for dmem_single_rw.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module dmem_single_rw_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "dmem_single_rw_ut";
    svunit_testcase svunit_ut;

    // =========================================================================
    // Parameters
    // =========================================================================
    localparam real CLOCK_FREQUENCY = 200e6;
    localparam int  N     = 10;          // address width
    localparam int  B     = 16;          // data width
    localparam int  DEPTH = 2**N;

    // FSM state encodings (mirror of DUT state_t)
    localparam int  INIT_ST  = 0;
    localparam int  READ0_ST = 1;
    localparam int  READ1_ST = 2;
    localparam int  WRITE_ST = 3;
    localparam int  ACK_ST   = 4;

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

    // =========================================================================
    // BRAM model — similar to bram_tdp: registered read (1 cycle), write-first
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
    // DUT control / data signals
    // =========================================================================
    logic         tb_rw_i       = 1'b0;
    logic         tb_exec_i     = 1'b0;
    logic         tb_exec_ack_o;
    logic [N-1:0] tb_addr_i     = '0;
    logic [B-1:0] tb_din_i      = '0;
    logic [B-1:0] tb_do_o;

    // =========================================================================
    // Clocking block
    // =========================================================================
    default clocking tb_cb @(posedge tb_clk);
        default input #1step output #2;
        output tb_rstn;
        output tb_rw_i;
        output tb_exec_i;
        output tb_addr_i;
        output tb_din_i;
        input  tb_exec_ack_o;
        input  tb_do_o;
    endclocking

    // =========================================================================
    // Dump file
    // =========================================================================
    initial begin
        $dumpfile("dmem_single_rw.vcd");
        $dumpvars();
    end

    // =========================================================================
    // DUT
    // =========================================================================
    dmem_single_rw #(
        .N (N),
        .B (B)
    ) u_dut (
        .clk        (tb_clk),
        .rstn       (tb_rstn),
        .rw_i       (tb_rw_i),
        .exec_i     (tb_exec_i),
        .exec_ack_o (tb_exec_ack_o),
        .addr_i     (tb_addr_i),
        .din_i      (tb_din_i),
        .do_o       (tb_do_o),
        .bram       (bram_if_i.master)
    );

    // =========================================================================
    // Helper tasks
    // =========================================================================
    task automatic reset_dut();
        tb_cb.tb_rstn   <= 1'b0;
        tb_cb.tb_rw_i   <= 1'b0;
        tb_cb.tb_exec_i <= 1'b0;
        tb_cb.tb_addr_i <= '0;
        tb_cb.tb_din_i  <= '0;
        repeat(10) @(tb_cb);
        tb_cb.tb_rstn <= 1'b1;
        repeat(5) @(tb_cb);
    endtask

    // wait_ack: wait until exec_ack_o asserts (with timeout)
    task automatic wait_ack(input int timeout = 32);
        int t = 0;
        while (tb_exec_ack_o !== 1'b1 && t < timeout) begin
            @(tb_cb);
            t++;
        end
        if (t >= timeout)
            $display("[WARN] wait_ack: timeout waiting for exec_ack_o");
    endtask

    // do_write: single WRITE transaction (INIT → WRITE → ACK)
    task automatic do_write(
        input logic [N-1:0] addr,
        input logic [B-1:0] data
    );
        @(tb_cb);
        tb_cb.tb_rw_i   <= 1'b1;     // write
        tb_cb.tb_addr_i <= addr;
        tb_cb.tb_din_i  <= data;
        tb_cb.tb_exec_i <= 1'b1;     // start
        wait_ack();
        @(tb_cb);
        tb_cb.tb_exec_i <= 1'b0;     // return to idle
        @(tb_cb);
    endtask

    // do_read: single READ transaction (INIT → READ0 → READ1 → ACK)
    task automatic do_read(
        input  logic [N-1:0] addr,
        output logic [B-1:0] data
    );
        @(tb_cb);
        tb_cb.tb_rw_i   <= 1'b0;     // read
        tb_cb.tb_addr_i <= addr;
        tb_cb.tb_exec_i <= 1'b1;     // start
        wait_ack();
        data = tb_exec_ack_o ? tb_do_o : 'x; // capture data at ack
        @(tb_cb);
        tb_cb.tb_exec_i <= 1'b0;     // return to idle
        @(tb_cb);
    endtask

    // verify_word: compare expected vs actual single word
    task automatic verify_word(
        input logic [B-1:0] expected,
        input logic [B-1:0] actual,
        input string        test_name
    );
        if (expected !== actual) begin
            $display("MISMATCH %s: expected 0x%0h got 0x%0h",
                     test_name, expected, actual);
            `FAIL_IF(1);
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
        // Clear BRAM model
        for (int i = 0; i < DEPTH; i++) mem[i] = '0;
        reset_dut();
    endtask

    task teardown();
        svunit_ut.teardown();
        tb_cb.tb_exec_i <= 1'b0;
        repeat(5) @(tb_cb);
    endtask

    // =========================================================================
    // Test cases
    // =========================================================================
    `SVUNIT_TESTS_BEGIN
    `include "dmem_single_rw_tests.sv"
    `SVUNIT_TESTS_END

endmodule