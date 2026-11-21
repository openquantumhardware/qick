// ============================================================================
// File: axis_to_bram_trig_tc00.sv
// Description: SVUnit testbench top-level for axis_to_bram_trig.
// ============================================================================

`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module axis_to_bram_trig_unit_test;

    import svunit_pkg::svunit_testcase;

    string name = "axis_to_bram_trig_ut";
    svunit_testcase svunit_ut;

    // =========================================================================
    // Parameters
    // =========================================================================
    localparam real CLOCK_FREQUENCY = 200e6;
    localparam int  N     = 4;          // depth = 2**4 = 16
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
        if (bram_if_i.en && bram_if_i.we)
            mem[bram_if_i.addr] <= bram_if_i.din;
    end

    // =========================================================================
    // Clock generator
    // =========================================================================
    clk_gen #(.FREQ (CLOCK_FREQUENCY)) u_clk_gen (
        .i_enable (1'b1),
        .o_clk    (tb_clk)
    );

    // =========================================================================
    // Control signals
    // =========================================================================
    logic tb_trigger     = 1'b0;
    logic tb_capture_reg = 1'b0;
    logic tb_capture_done      ;

    // =========================================================================
    // Clocking block
    // =========================================================================
    default clocking tb_cb @(posedge tb_clk);
        default input #1step output #2;
        output tb_rstn;
        output tb_trigger;
        output tb_capture_reg;
    endclocking

    // =========================================================================
    // Dump file
    // =========================================================================
    initial begin
        $dumpfile("axis_to_bram_trig.vcd");
        $dumpvars();
    end

    // =========================================================================
    // DUT
    // =========================================================================
    axis_to_bram_trig #(
        .N (N),
        .B (B)
    ) u_dut (
        .rstn          (tb_rstn),
        .clk           (tb_clk),
        .trigger       (tb_trigger),
        .s_axis_tready (axis_if.tready),
        .s_axis_tdata  (axis_if.tdata),
        .s_axis_tvalid (axis_if.tvalid),
        .s_axis_tlast  (axis_if.tlast),
        .mem_en        (bram_if_i.en),
        .mem_we        (bram_if_i.we),
        .mem_addr      (bram_if_i.addr),
        .mem_di        (bram_if_i.din),
        .capture_reg   (tb_capture_reg),
        .o_capture_done(tb_capture_done)
    );

    // =========================================================================
    // Helper tasks
    // =========================================================================

    task automatic reset_dut();
        tb_cb.tb_rstn        <= 1'b0;
        tb_cb.tb_capture_reg <= 1'b0;
        tb_cb.tb_trigger     <= 1'b0;
        axis_if.m_cb.tvalid  <= 1'b0;
        axis_if.m_cb.tdata   <= '0;
        axis_if.m_cb.tlast   <= 1'b0;
        repeat(10) @(tb_cb);
        tb_cb.tb_rstn <= 1'b1;
        // Wait for XPM FIFO reset to complete
        repeat(20) @(tb_cb);
    endtask

    // arm: assert capture_reg → FSM goes to TRIGGER_ST
    task automatic arm();
        tb_cb.tb_capture_reg <= 1'b1;
        repeat(3) @(tb_cb);
    endtask

    // disarm: de-assert capture_reg → FSM returns to INIT_ST after FIFO drains
    task automatic disarm();
        tb_cb.tb_capture_reg <= 1'b0;
        repeat(5) @(tb_cb);
    endtask

    // pulse_trigger: one-cycle trigger pulse → FSM TRIGGER_ST → CAPTURE_ST
    task automatic pulse_trigger();
        tb_cb.tb_trigger <= 1'b1;
        @(tb_cb);
        tb_cb.tb_trigger <= 1'b0;
    endtask

    // stream_data: send count samples via AXI4-Stream, incrementing from start_val
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
        // Bajar inmediatamente sin ciclo extra
        axis_if.m_cb.tvalid <= 1'b0;
        axis_if.m_cb.tdata  <= '0;
        axis_if.m_cb.tlast  <= 1'b0;
    endtask 

    // wait_capture_done: wait until FSM reaches END_ST (BRAM fully written)
    task automatic wait_capture_done(input int timeout = 200);
        int t = 0;
        while (u_dut.current_state !== 3 && t < timeout) begin
            @(tb_cb);
            t++;
        end
        if (t >= timeout)
            $display("[WARN] wait_capture_done: timeout waiting for END_ST");
        repeat(5) @(tb_cb);
    endtask

    // read_mem: read back DEPTH words from BRAM model into data[]
    task automatic read_mem(output logic [B-1:0] data[]);
        data = new[DEPTH];
        for (int i = 0; i < DEPTH; i++)
            data[i] = mem[i];
    endtask

    // verify_data: compare expected vs actual arrays
    task automatic verify_data(
        input logic [B-1:0] expected[],
        input logic [B-1:0] actual[],
        input string        test_name
    );
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
        // Clear BRAM model
        for (int i = 0; i < DEPTH; i++) mem[i] = '0;
        reset_dut();
    endtask

    task teardown();
        svunit_ut.teardown();
        disarm();
        repeat(5) @(tb_cb);
    endtask

    // =========================================================================
    // Test cases
    // =========================================================================
    `SVUNIT_TESTS_BEGIN
    `include "axis_to_bram_trig_tests.sv"
    `SVUNIT_TESTS_END

endmodule
