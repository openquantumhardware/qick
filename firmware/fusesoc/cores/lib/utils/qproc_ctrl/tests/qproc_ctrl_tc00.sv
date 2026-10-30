// ============================================================================
// File: qproc_ctrl_tc00.sv
// Description: SVUnit testbench top-level for qproc_ctrl.
//
// Single clock drives both the t_clk_i and c_clk_i domains -- the CDC
// synchronizers still add their fixed 2-flop latency regardless of the
// clock relationship, so this is a valid (if pessimistic) way to exercise
// the cross-domain handshakes.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module qproc_ctrl_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "qproc_ctrl_ut";
    svunit_testcase svunit_ut;

    // Core/time FSM encodings (mirrors the enums in qproc_ctrl.sv).
    localparam logic [2:0] C_RST_STOP = 3'd0, C_RST_STOP_WAIT = 3'd1, C_RST_RUN = 3'd2, C_RST_RUN_WAIT = 3'd3,
                            C_STOP = 3'd4, C_RUN = 3'd5, C_STEP = 3'd6, C_END_STEP = 3'd7;
    localparam logic [2:0] T_RST_STOP = 3'd0, T_RST_RUN = 3'd1, T_UPDT = 3'd2, T_RUN = 3'd3, T_STOP = 3'd4,
                            T_STEP = 3'd5;

    // =========================================================================
    // Parameters
    // =========================================================================
    localparam real CLOCK_FREQUENCY = 200e6;

    // =========================================================================
    // Clock & reset
    // =========================================================================
    logic tb_clk  = 1'b0;
    logic tb_rstn = 1'b1;

    clk_gen #(.FREQ (CLOCK_FREQUENCY)) u_clk_gen (
        .i_enable (1'b1),
        .o_clk    (tb_clk)
    );

    // =========================================================================
    // DUT signals
    // =========================================================================
    logic tb_proc_start_i   = 1'b0;
    logic tb_proc_stop_i    = 1'b0;
    logic tb_core_start_i   = 1'b0;
    logic tb_core_stop_i    = 1'b0;
    logic tb_time_rst_i     = 1'b0;
    logic tb_time_updt_i    = 1'b0;
    logic [31:0] tb_time_updt_dt_i = '0;

    logic        tb_int_time_en  = 1'b0;
    logic [3:0]  tb_int_time_cmd = '0;
    logic [31:0] tb_int_time_dt  = '0;

    logic [15:0] tb_ps_tproc_ctrl_i = '0;
    logic [11:9] tb_ps_tproc_cfg_i  = '0;
    logic [31:0] tb_xreg_tproc_w_dt_i = '0;

    logic tb_all_fifo_full_i  = 1'b0;
    logic tb_some_fifo_full_i = 1'b0;

    logic tb_core_rst_o, tb_core_en_o;
    logic tb_time_rst_o, tb_time_en_o;
    logic [47:0] tb_time_abs_o;
    logic [47:0] tb_c_time_ref_o;
    logic [31:0] tb_c_time_usr_o;

    logic [2:0] tb_time_st_do, tb_core_st_do;
    logic [6:0] tb_t_debug_do, tb_c_debug_do;

    initial begin
        $dumpfile("qproc_ctrl.vcd");
        $dumpvars();
    end

    // =========================================================================
    // DUT
    // =========================================================================
    qproc_ctrl #(
        .TIME_READ (1)
    ) u_dut (
        .t_clk_i  (tb_clk),
        .t_rst_ni (tb_rstn),
        .c_clk_i  (tb_clk),
        .c_rst_ni (tb_rstn),
        .proc_start_i (tb_proc_start_i),
        .proc_stop_i  (tb_proc_stop_i),
        .core_start_i (tb_core_start_i),
        .core_stop_i  (tb_core_stop_i),
        .time_rst_i   (tb_time_rst_i),
        .time_updt_i  (tb_time_updt_i),
        .time_updt_dt_i (tb_time_updt_dt_i),
        .int_time_en  (tb_int_time_en),
        .int_time_cmd (tb_int_time_cmd),
        .int_time_dt  (tb_int_time_dt),
        .ps_tproc_ctrl_i   (tb_ps_tproc_ctrl_i),
        .ps_tproc_cfg_i    (tb_ps_tproc_cfg_i),
        .xreg_tproc_w_dt_i (tb_xreg_tproc_w_dt_i),
        .all_fifo_full_i  (tb_all_fifo_full_i),
        .some_fifo_full_i (tb_some_fifo_full_i),
        .core_rst_o (tb_core_rst_o),
        .core_en_o  (tb_core_en_o),
        .time_rst_o (tb_time_rst_o),
        .time_en_o  (tb_time_en_o),
        .time_abs_o (tb_time_abs_o),
        .c_time_ref_o (tb_c_time_ref_o),
        .c_time_usr_o (tb_c_time_usr_o),
        .time_st_do (tb_time_st_do),
        .core_st_do (tb_core_st_do),
        .t_debug_do (tb_t_debug_do),
        .c_debug_do (tb_c_debug_do)
    );

    // =========================================================================
    // Helper tasks
    // =========================================================================
    task automatic reset_dut();
        tb_proc_start_i   = 1'b0;
        tb_proc_stop_i    = 1'b0;
        tb_core_start_i   = 1'b0;
        tb_core_stop_i    = 1'b0;
        tb_time_rst_i     = 1'b0;
        tb_time_updt_i    = 1'b0;
        tb_time_updt_dt_i = '0;
        tb_int_time_en    = 1'b0;
        tb_int_time_cmd   = '0;
        tb_int_time_dt    = '0;
        tb_ps_tproc_ctrl_i = '0;
        tb_ps_tproc_cfg_i  = '0;
        tb_xreg_tproc_w_dt_i = '0;
        tb_all_fifo_full_i  = 1'b0;
        tb_some_fifo_full_i = 1'b0;
        tb_rstn = 1'b0;
        repeat(5) @(posedge tb_clk);
        tb_rstn = 1'b1;
        repeat(2) @(posedge tb_clk);
    endtask

    task automatic wait_for_core_st(input logic [2:0] target, output bit reached, input int max_cycles = 40);
        reached = 1'b0;
        for (int n = 0; n < max_cycles; n++) begin
            @(posedge tb_clk);
            if (tb_core_st_do == target) begin
                reached = 1'b1;
                return;
            end
        end
    endtask

    task automatic wait_for_time_st(input logic [2:0] target, output bit reached, input int max_cycles = 40);
        reached = 1'b0;
        for (int n = 0; n < max_cycles; n++) begin
            @(posedge tb_clk);
            if (tb_time_st_do == target) begin
                reached = 1'b1;
                return;
            end
        end
    endtask

    // Brings the core to C_RUN: the core FSM only leaves reset through the all_fifo_full handshake. START also runs time.
    task automatic run_core(output bit reached);
        tb_all_fifo_full_i = 1'b1;
        tb_ps_tproc_ctrl_i[2] = 1'b1;
        wait_for_core_st(C_RST_RUN_WAIT, reached);
        if (!reached) return;
        tb_all_fifo_full_i = 1'b0;
        wait_for_core_st(C_RUN, reached);
    endtask

    // One-clock time command from the core (int_time_cmd bit 2 set_ref, bit 3 inc_ref) with its 32-bit operand.
    task automatic time_cmd(input logic [3:0] cmd, input logic [31:0] dt);
        @(negedge tb_clk);
        tb_int_time_cmd = cmd;
        tb_int_time_dt  = dt;
        tb_int_time_en  = 1'b1;
        @(negedge tb_clk);
        tb_int_time_en  = 1'b0;
        tb_int_time_cmd = '0;
        repeat (2) @(posedge tb_clk);
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
    endtask

    // =========================================================================
    // Test cases
    // =========================================================================
    `SVUNIT_TESTS_BEGIN
    `include "qproc_ctrl_tests.sv"
    `SVUNIT_TESTS_END

endmodule
