// ============================================================================
// File: qproc_dispatcher_tc00.sv
// Description: SVUnit testbench top-level for qproc_dispatcher.
//
// Single clock drives both c_clk_i/t_clk_i domains (the CDC synchronizers
// still add their fixed latency regardless of the clock relationship).
// Two channels per port kind (OUT_TRIG_QTY=OUT_DPORT_QTY=OUT_WPORT_QTY=2,
// matching the debug buses' hard-coded [1]/[0] indexing -- see the module
// header); tests only ever exercise channel 0. A small FIFO_DEPTH so the
// fill/full tests don't need hundreds of pushes.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module qproc_dispatcher_unit_test;
    import svunit_pkg::svunit_testcase;
    import tpv2_pkg::PORT_DT;

    string name = "qproc_dispatcher_ut";
    svunit_testcase svunit_ut;

    // =========================================================================
    // Parameters
    // =========================================================================
    localparam real CLOCK_FREQUENCY = 200e6;
    localparam int  FIFO_DEPTH = 4; // 16-entry FIFOs (XPM_FIFO's minimum depth)

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
    logic tb_core_en  = 1'b0;
    logic tb_core_rst = 1'b0;
    logic tb_time_en  = 1'b0;
    logic tb_time_rst = 1'b0;
    logic [47:0] tb_c_time_ref_dt = '0;
    logic [47:0] tb_time_abs_i    = '0;
    logic tb_port_we = 1'b0;
    PORT_DT tb_out_port_data;

    logic tb_all_fifo_full, tb_some_fifo_full;

    logic tb_port_trig_o [2];
    logic tb_port_tvalid_o [2];
    logic [3:0] tb_port_tdata_o [2]; // OUT_DPORT_DW=4

    logic [167:0] tb_m_axis_tdata [2];
    logic         tb_m_axis_tvalid [2];
    logic         tb_m_axis_tready [2] = '{default: 1'b0};

    logic [31:0] tb_fifo_dt_do, tb_axi_fifo_do;
    logic [15:0] tb_c_fifo_do, tb_t_fifo_do;

    initial begin
        tb_out_port_data = '{default: '0};
    end

    initial begin
        $dumpfile("qproc_dispatcher.vcd");
        $dumpvars();
    end

    // =========================================================================
    // DUT
    // =========================================================================
    qproc_dispatcher #(
        .FIFO_DEPTH    (FIFO_DEPTH),
        .IN_PORT_QTY   (1),
        .OUT_TRIG_QTY  (2),
        .OUT_DPORT_QTY (2),
        .OUT_DPORT_DW  (4),
        .OUT_WPORT_QTY (2)
    ) u_dut (
        .c_clk_i  (tb_clk),
        .c_rst_ni (tb_rstn),
        .t_clk_i  (tb_clk),
        .t_rst_ni (tb_rstn),
        .core_en  (tb_core_en),
        .core_rst (tb_core_rst),
        .time_en  (tb_time_en),
        .time_rst (tb_time_rst),
        .c_time_ref_dt (tb_c_time_ref_dt),
        .time_abs_i    (tb_time_abs_i),
        .port_we       (tb_port_we),
        .out_port_data (tb_out_port_data),
        .all_fifo_full  (tb_all_fifo_full),
        .some_fifo_full (tb_some_fifo_full),
        .port_trig_o   (tb_port_trig_o),
        .port_tvalid_o (tb_port_tvalid_o),
        .port_tdata_o  (tb_port_tdata_o),
        .m_axis_tdata  (tb_m_axis_tdata),
        .m_axis_tvalid (tb_m_axis_tvalid),
        .m_axis_tready (tb_m_axis_tready),
        .fifo_dt_do  (tb_fifo_dt_do),
        .axi_fifo_do (tb_axi_fifo_do),
        .c_fifo_do   (tb_c_fifo_do),
        .t_fifo_do   (tb_t_fifo_do)
    );

    // =========================================================================
    // Helper tasks
    // =========================================================================
    task automatic reset_dut();
        tb_core_en  = 1'b0;
        tb_core_rst = 1'b0;
        tb_time_en  = 1'b0;
        tb_time_rst = 1'b0;
        tb_c_time_ref_dt = '0;
        tb_time_abs_i    = '0;
        tb_port_we = 1'b0;
        tb_out_port_data = '{default: '0};
        tb_m_axis_tready = '{default: 1'b0};
        tb_rstn = 1'b0;
        repeat(5) @(posedge tb_clk);
        tb_rstn = 1'b1;
        // XPM_FIFO_ASYNC's wr_rst_busy/rd_rst_busy stay high for a good
        // while after rst deasserts (fifo_async forces full/empty during
        // that window) -- give it generous margin to settle.
        repeat(100) @(posedge tb_clk);
    endtask

    // Single-cycle port_we pulse carrying `data`.
    task automatic push_event(input PORT_DT data);
        @(negedge tb_clk);
        tb_port_we = 1'b1;
        tb_out_port_data = data;
        @(negedge tb_clk);
        tb_port_we = 1'b0;
    endtask

    task automatic wait_until(ref logic sig, input int max_cycles = 60);
        for (int n = 0; n < max_cycles; n++) begin
            if (sig) return;
            @(posedge tb_clk);
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
        reset_dut();
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    // =========================================================================
    // Test cases
    // =========================================================================
    `SVUNIT_TESTS_BEGIN
    `include "qproc_dispatcher_tests.sv"
    `SVUNIT_TESTS_END

endmodule
