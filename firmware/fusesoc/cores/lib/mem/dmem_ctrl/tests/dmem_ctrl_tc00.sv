// ============================================================================
// File: dmem_ctrl_tc00.sv
// Description: SVUnit testbench top-level for dmem_ctrl.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module dmem_ctrl_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "dmem_ctrl_ut";
    svunit_testcase svunit_ut;

    // =========================================================================
    // Parameters
    // =========================================================================
    localparam real CLOCK_FREQUENCY = 200e6;
    localparam int  N = 16;

    // FSM state encodings (mirror of DUT state_t)
    localparam int  INIT_ST           = 0;
    localparam int  AXIS_READ_ST      = 1;
    localparam int  AXIS_READ_ACK_ST  = 2;
    localparam int  AXIS_WRITE_ST     = 3;
    localparam int  AXIS_WRITE_ACK_ST = 4;
    localparam int  END_ST            = 6;

    // sel_o encodings
    localparam logic [1:0] SEL_SINGLE = 2'd0;
    localparam logic [1:0] SEL_READ   = 2'd1;
    localparam logic [1:0] SEL_WRITE  = 2'd2;

    // =========================================================================
    // Clock & Reset
    // =========================================================================
    logic tb_clk  = 1'b0;
    logic tb_rstn = 1'b1;

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
    logic [1:0] tb_sel_o;
    logic       tb_ar_exec_o;
    logic       tb_ar_exec_ack_i = 1'b0;
    logic       tb_aw_exec_o;
    logic       tb_aw_exec_ack_i = 1'b0;
    logic       tb_busy_o;
    logic       tb_mode_reg      = 1'b0;
    logic       tb_start_reg     = 1'b0;

    // =========================================================================
    // Clocking block
    // =========================================================================
    default clocking tb_cb @(posedge tb_clk);
        default input #1step output #2;
        output tb_rstn;
        output tb_ar_exec_ack_i;
        output tb_aw_exec_ack_i;
        output tb_mode_reg;
        output tb_start_reg;
        input  tb_sel_o;
        input  tb_ar_exec_o;
        input  tb_aw_exec_o;
        input  tb_busy_o;
    endclocking

    // =========================================================================
    // Dump file
    // =========================================================================
    initial begin
        $dumpfile("dmem_ctrl.vcd");
        $dumpvars();
    end

    // =========================================================================
    // DUT
    // =========================================================================
    dmem_ctrl #(
        .N (N)
    ) u_dut (
        .clk           (tb_clk),
        .rstn          (tb_rstn),
        .sel_o         (tb_sel_o),
        .ar_exec_o     (tb_ar_exec_o),
        .ar_exec_ack_i (tb_ar_exec_ack_i),
        .aw_exec_o     (tb_aw_exec_o),
        .aw_exec_ack_i (tb_aw_exec_ack_i),
        .busy_o        (tb_busy_o),
        .mode_reg      (tb_mode_reg),
        .start_reg     (tb_start_reg)
    );

    // =========================================================================
    // Helper tasks
    // =========================================================================
    task automatic reset_dut();
        tb_cb.tb_rstn         <= 1'b0;
        tb_cb.tb_mode_reg     <= 1'b0;
        tb_cb.tb_start_reg    <= 1'b0;
        tb_cb.tb_ar_exec_ack_i <= 1'b0;
        tb_cb.tb_aw_exec_ack_i <= 1'b0;
        repeat(10) @(tb_cb);
        tb_cb.tb_rstn <= 1'b1;
        repeat(5) @(tb_cb);
    endtask

    // start_axis: drive mode_reg and pulse start_reg high (held until cleared)
    //   mode = 0 -> AXIS read, mode = 1 -> AXIS write
    task automatic start_axis(input logic mode);
        tb_cb.tb_mode_reg  <= mode;
        tb_cb.tb_start_reg <= 1'b1;
    endtask

    // stop_axis: deassert start_reg (allows END_ST -> INIT_ST)
    task automatic stop_axis();
        tb_cb.tb_start_reg <= 1'b0;
    endtask

    // ack_reader: assert ar_exec_ack for one cycle
    task automatic ack_reader();
        tb_cb.tb_ar_exec_ack_i <= 1'b1;
        @(tb_cb);
        tb_cb.tb_ar_exec_ack_i <= 1'b0;
    endtask

    // ack_writer: assert aw_exec_ack for one cycle
    task automatic ack_writer();
        tb_cb.tb_aw_exec_ack_i <= 1'b1;
        @(tb_cb);
        tb_cb.tb_aw_exec_ack_i <= 1'b0;
    endtask

    // wait_state: wait until FSM reaches target state (with timeout)
    task automatic wait_state(input int target, input int timeout = 50);
        int t = 0;
        while (u_dut.state !== target && t < timeout) begin
            @(tb_cb);
            t++;
        end
        if (t >= timeout)
            $display("[WARN] wait_state: timeout waiting for state %0d", target);
    endtask

    // =========================================================================
    // SVUnit build / setup / teardown
    // =========================================================================
    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        reset_dut();
    endtask

    task teardown();
        svunit_ut.teardown();
        // Make sure FSM returns to idle between tests
        tb_cb.tb_start_reg     <= 1'b0;
        tb_cb.tb_ar_exec_ack_i <= 1'b0;
        tb_cb.tb_aw_exec_ack_i <= 1'b0;
        repeat(5) @(tb_cb);
    endtask

    // =========================================================================
    // Test cases
    // =========================================================================
    `SVUNIT_TESTS_BEGIN
    `include "dmem_ctrl_tests.sv"
    `SVUNIT_TESTS_END

endmodule