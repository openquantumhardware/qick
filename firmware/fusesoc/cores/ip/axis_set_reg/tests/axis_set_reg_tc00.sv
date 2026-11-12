// ============================================================================
// File: axis_set_reg_tc00.sv
// Description: SVUnit testbench top-level for the axis_set_reg module.
// ============================================================================

`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module axis_set_reg_unit_test;

  import svunit_pkg::svunit_testcase;

  string name = "axis_set_reg_ut";
  svunit_testcase svunit_ut;

  // =========================================================================
  // Parameters
  // =========================================================================
  localparam real CLOCK_FREQUENCY = 200e6;  // 200 MHz
  localparam int B = 16;  // Default word width

  // -------------------------------------------------------------------------
  // Clock & Reset
  // -------------------------------------------------------------------------
  logic tb_clk = 1'b0;
  logic tb_rstn = 1'b1;

  // -------------------------------------------------------------------------
  // UUT interfaces
  // -------------------------------------------------------------------------
  axi4_stream_if #(
      .TDATA_WIDTH(B),
      .HAS_TSTRB  (1'b1),
      .HAS_TKEEP  (1'b0),
      .HAS_TID    (1'b0),
      .HAS_TDEST  (1'b0),
      .HAS_TUSER  (1'b0)
  ) axis_if (
      .aclk   (tb_clk),
      .aresetn(tb_rstn)
  );

  // Crude output of the register
  logic [B-1:0] tb_dout;

  // -------------------------------------------------------------------------
  // Waveform dump
  // -------------------------------------------------------------------------
  initial begin
    $dumpfile("axis_set_reg.vcd");
    $dumpvars();
  end

  // -------------------------------------------------------------------------
  // Clock generator
  // -------------------------------------------------------------------------
  clk_gen #(
      .FREQ(CLOCK_FREQUENCY)
  ) u_clk_gen (
      .i_enable(1'b1),
      .o_clk   (tb_clk)
  );

  // -------------------------------------------------------------------------
  // Clocking block 
  // -------------------------------------------------------------------------
  default clocking cb @(posedge tb_clk);
    default input #1step output #2;
    output tb_rstn;
    input tb_dout;
  endclocking

  // -------------------------------------------------------------------------
  // Unit Under Test
  // -------------------------------------------------------------------------
  axis_set_reg #(
      .DATA_WIDTH(B)
  ) u_dut (
      .s_axis_aclk      (tb_clk),
      .s_axis_aresetn   (tb_rstn),
      .s_axis_tready    (axis_if.slave.tready),
      .s_axis_tdata     (axis_if.slave.tdata),
      .s_axis_tstrb     (axis_if.slave.tstrb),
      .s_axis_tlast     (axis_if.slave.tlast),
      .s_axis_tvalid    (axis_if.slave.tvalid),
      .dout  (tb_dout)
  );

  // =========================================================================
  // SVUnit build / setup / teardown
  // =========================================================================
  function void build();
    svunit_ut = new(name);
  endfunction

  task setup();
    svunit_ut.setup();

    // Use the interface task to leave everything clean for the test cases. 
    // This will ensure that the AXI-Stream interface is in a known idle 
    // state before each test.
    axis_if.idle();

    // Global reset handling
    cb.tb_rstn <= 1'b0;
    repeat (2) @(cb);
    cb.tb_rstn <= 1'b1;
    repeat (3) @(cb);
  endtask

  task teardown();
    svunit_ut.teardown();
  endtask

  // =========================================================================
  // Test cases
  // =========================================================================
  `SVUNIT_TESTS_BEGIN
  `include "axis_set_reg_tests.sv"
`SVUNIT_TESTS_END

endmodule
