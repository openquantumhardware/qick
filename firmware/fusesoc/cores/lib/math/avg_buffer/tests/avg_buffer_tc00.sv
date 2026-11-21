// ============================================================================
// File: avg_buffer_tc00.sv
// Description: SVUnit testbench top-level for avg_buffer.
//
//   avg_top and buffer_top each already have dedicated, thorough
//   testbenches (arm/trigger/capture/readback, aborts, photon mode). This
//   testbench focuses on what's NEW at the avg_buffer composition level:
//   a single external trigger fanning out to BOTH sub-blocks at once, and
//   all three output streams (m0=avg BRAM readback, m1=buf readback,
//   m2=avg live register feed) being reachable through the top module.
// ============================================================================

`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module avg_buffer_unit_test;

    import svunit_pkg::svunit_testcase;

    string name = "avg_buffer_ut";
    svunit_testcase svunit_ut;

    localparam real CLOCK_FREQUENCY = 200e6;
    localparam int  N_AVG = 8;
    localparam int  N_BUF = 8;
    localparam int  B     = 16;

    // -------------------------------------------------------------------------
    // Clock & Reset (single clock domain in this testbench: s_axis and
    // m_axis share the same clock, matching avg_top/buffer_top's own TBs)
    // -------------------------------------------------------------------------
    logic tb_clk  = 1'b0;
    logic tb_rstn = 1'b1;

    // Stimulus is driven (and the streams sampled) TSU after the rising edge, never at it: a blocking drive
    // right after @(posedge) races the DUT's flops, and which way xsim resolves it changed with what
    // $dumpvars records (docs/developer/TESTBENCH_PATTERNS.md section 19, the same fix as axis_avg_buffer).
    localparam time TSU = 1ns;

    clk_gen #(.FREQ (CLOCK_FREQUENCY)) u_clk_gen (.i_enable(1'b1), .o_clk(tb_clk));

    // -------------------------------------------------------------------------
    // Interfaces
    // -------------------------------------------------------------------------
    axi4_stream_if #(.TDATA_WIDTH(4*B)) m0_if (.aclk(tb_clk), .aresetn(tb_rstn));
    axi4_stream_if #(.TDATA_WIDTH(2*B)) m1_if (.aclk(tb_clk), .aresetn(tb_rstn));
    axi4_stream_if #(.TDATA_WIDTH(4*B)) m2_if (.aclk(tb_clk), .aresetn(tb_rstn));

    // m2 is the register-readback stream and carries no tlast by design:
    // avg_buffer exposes no m2_axis_tlast port and leaves avg_top's
    // m1_axis_tlast open (avg_buffer.sv:143), and avg_top declares that output
    // without ever driving it. Undriven it floats to X, so
    // AXI4STREAM_ERRM_TLAST_X fires as soon as a readback beat raises
    // m2_if.tvalid. Nothing consumes framing on m2, so tie it low and leave the
    // rest of the m2 checkers live.
    assign m2_if.tlast = 1'b0;

    // -------------------------------------------------------------------------
    // Discrete signals
    // -------------------------------------------------------------------------
    logic            tb_trigger       = 1'b0;
    logic            tb_s_axis_tvalid = 1'b0;
    logic [2*B-1:0]  tb_s_axis_tdata  = '0;
    logic            tb_s_axis_tready;

    logic               tb_avg_start_reg       = 1'b0;
    logic [N_AVG-1:0]   tb_avg_addr_reg        = '0;
    logic [31:0]        tb_avg_len_reg         = '0;
    logic               tb_avg_photon_mode_reg = 1'b0;
    logic [B-1:0]       tb_avg_h_thrsh_reg     = '0;
    logic [B-1:0]       tb_avg_l_thrsh_reg     = '0;
    logic               tb_avg_dr_start_reg    = 1'b0;
    logic [N_AVG-1:0]   tb_avg_dr_addr_reg     = '0;
    logic [N_AVG:0]     tb_avg_dr_len_reg      = '0;

    logic               tb_buf_start_reg    = 1'b0;
    logic [N_BUF-1:0]   tb_buf_addr_reg     = '0;
    logic [N_BUF-1:0]   tb_buf_len_reg      = '0;
    logic               tb_buf_dr_start_reg = 1'b0;
    logic [N_BUF-1:0]   tb_buf_dr_addr_reg  = '0;
    logic [N_BUF:0]     tb_buf_dr_len_reg   = '0;

    // -------------------------------------------------------------------------
    // Waveform dump
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("avg_buffer.vcd");
        $dumpvars();
    end

    // -------------------------------------------------------------------------
    // Unit Under Test
    // -------------------------------------------------------------------------
    avg_buffer #(
        .N_AVG (N_AVG),
        .N_BUF (N_BUF),
        .B     (B)
    ) dut (
        .s_axis_aclk    (tb_clk),
        .s_axis_aresetn (tb_rstn),

        .trigger (tb_trigger),

        .s_axis_tvalid (tb_s_axis_tvalid),
        .s_axis_tready (tb_s_axis_tready),
        .s_axis_tdata  (tb_s_axis_tdata),

        .m_axis_aclk    (tb_clk),
        .m_axis_aresetn (tb_rstn),

        .m0_axis_tvalid (m0_if.tvalid),
        .m0_axis_tready (m0_if.tready),
        .m0_axis_tdata  (m0_if.tdata),
        .m0_axis_tlast  (m0_if.tlast),

        .m1_axis_tvalid (m1_if.tvalid),
        .m1_axis_tready (m1_if.tready),
        .m1_axis_tdata  (m1_if.tdata),
        .m1_axis_tlast  (m1_if.tlast),

        .m2_axis_tvalid (m2_if.tvalid),
        .m2_axis_tready (m2_if.tready),
        .m2_axis_tdata  (m2_if.tdata),

        .avg_start_reg       (tb_avg_start_reg),
        .avg_addr_reg        (tb_avg_addr_reg),
        .avg_len_reg         (tb_avg_len_reg),
        .avg_photon_mode_reg (tb_avg_photon_mode_reg),
        .avg_h_thrsh_reg     (tb_avg_h_thrsh_reg),
        .avg_l_thrsh_reg     (tb_avg_l_thrsh_reg),
        .avg_dr_start_reg    (tb_avg_dr_start_reg),
        .avg_dr_addr_reg     (tb_avg_dr_addr_reg),
        .avg_dr_len_reg      (tb_avg_dr_len_reg),

        .buf_start_reg    (tb_buf_start_reg),
        .buf_addr_reg     (tb_buf_addr_reg),
        .buf_len_reg      (tb_buf_len_reg),
        .buf_dr_start_reg (tb_buf_dr_start_reg),
        .buf_dr_addr_reg  (tb_buf_dr_addr_reg),
        .buf_dr_len_reg   (tb_buf_dr_len_reg)
    );

    // =========================================================================
    // Helper tasks
    // =========================================================================

    task automatic reset_dut();
        tb_rstn = 1'b0;
        repeat(4) @(posedge tb_clk); #TSU;
        tb_rstn = 1'b1;
        // XPM_FIFO (fifo_async inside avg_top, XPM_FIFO_SYNC inside
        // bram_to_axis) needs a long wr_rst_busy/rd_rst_busy settle window
        // after reset -- matches the established margin used elsewhere in
        // this repo for XPM-backed cores.
        repeat(100) @(posedge tb_clk); #TSU;
    endtask

    // Arms whichever of avg/buf start_reg is passed in, pulses the shared
    // trigger once both are ready, leaves both FSMs capturing.
    task automatic arm_avg(input logic [N_AVG-1:0] addr, input logic [31:0] len);
        tb_avg_addr_reg  = addr;
        tb_avg_len_reg   = len;
        tb_avg_start_reg = 1'b1;
        repeat(4) @(posedge tb_clk); #TSU;
    endtask

    task automatic arm_buf(input logic [N_BUF-1:0] addr, input logic [N_BUF-1:0] len);
        tb_buf_addr_reg  = addr;
        tb_buf_len_reg   = len;
        tb_buf_start_reg = 1'b1;
        repeat(4) @(posedge tb_clk); #TSU;
    endtask

    task automatic pulse_trigger();
        tb_trigger = 1'b1;
        repeat(3) @(posedge tb_clk); #TSU; // cdc_bit_sync settle margin
        tb_trigger = 1'b0;
        repeat(3) @(posedge tb_clk); #TSU;
    endtask

    task automatic inject_data(input int count, input logic [2*B-1:0] start_val);
        int i;
        tb_s_axis_tvalid = 1'b1;
        for (i = 0; i < count; i++) begin
            tb_s_axis_tdata = start_val + i;
            @(posedge tb_clk); #TSU;
        end
        tb_s_axis_tvalid = 1'b0;
        tb_s_axis_tdata  = '0;
        repeat(6) @(posedge tb_clk); #TSU;
    endtask

    // =========================================================================
    // SVUnit build / setup / teardown
    // =========================================================================
    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        tb_trigger             = 1'b0;
        tb_s_axis_tvalid       = 1'b0;
        tb_s_axis_tdata        = '0;
        tb_avg_start_reg       = 1'b0;
        tb_avg_addr_reg        = '0;
        tb_avg_len_reg         = '0;
        tb_avg_photon_mode_reg = 1'b0;
        tb_avg_h_thrsh_reg     = '0;
        tb_avg_l_thrsh_reg     = '0;
        tb_avg_dr_start_reg    = 1'b0;
        tb_avg_dr_addr_reg     = '0;
        tb_avg_dr_len_reg      = '0;
        tb_buf_start_reg       = 1'b0;
        tb_buf_addr_reg        = '0;
        tb_buf_len_reg         = '0;
        tb_buf_dr_start_reg    = 1'b0;
        tb_buf_dr_addr_reg     = '0;
        tb_buf_dr_len_reg      = '0;
        m0_if.tready = 1'b1;
        m1_if.tready = 1'b1;
        m2_if.tready = 1'b1;
        reset_dut();
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    `SVUNIT_TESTS_BEGIN
    `include "avg_buffer_tests.sv"
    `SVUNIT_TESTS_END

endmodule
