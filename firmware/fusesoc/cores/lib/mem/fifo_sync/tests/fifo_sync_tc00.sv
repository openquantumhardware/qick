`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module fifo_sync_unit_test;
  import svunit_pkg::svunit_testcase;

  string name = "fifo_sync_ut";
  svunit_testcase svunit_ut;

  localparam int B = 16;
  localparam int N = 16;

  // Clock and Reset signals
  logic clk = 0;
  always #2 clk = ~clk; // 4 time-unit clock period
  logic rstn = 0;

  // FIFO Interfaces
  logic         wr_en, rd_en;
  logic [B-1:0] din, dout;
  logic         full, empty;

  // Reference model queue
  logic [B-1:0] model_q[$];

  // ============================================================
  // GTKWAVE CONFIGURATION (VCD Waveform Dump)
  // ============================================================
  initial begin
    $dumpfile("fifo_sync_waveform.vcd"); // Target VCD filename
    $dumpvars();    // Dumps all signals in this module and sub-modules
  end

  // ============================================================
  // Unit Under Test (DUT)
  // ============================================================
  fifo_sync #(
    .B(B), 
    .N(N), 
    .USE_ADV_FEATURES("1707"), 
    .ENABLE_COUNTERS(1)
  ) dut (
    .clk(clk),
    .rstn(rstn),
    .wr_en(wr_en),
    .din(din),
    .rd_en(rd_en),
    .dout(dout),
    .full(full),
    .empty(empty)
  );

  // ============================================================
  // SystemVerilog Concurrent Assertions (SVA)
  // ============================================================
  property p_no_overflow;
    @(posedge clk) disable iff (!rstn) full |-> !wr_en;
  endproperty
  assert property(p_no_overflow);

  property p_no_underflow;
    @(posedge clk) disable iff (!rstn) empty |-> !rd_en;
  endproperty
  assert property(p_no_underflow);

  // ============================================================
  // SVUnit Functions and Tasks
  // ============================================================
  function void build();
    svunit_ut = new(name);
  endfunction

  task setup();
    svunit_ut.setup();
    rstn  = 0;    // Assert reset
    wr_en = 0;
    rd_en = 0;
    
    repeat(5) @(posedge clk);
    @(negedge clk);
    rstn = 1;     // De-assert reset on a falling edge to prevent race conditions
    
    // Allow the Xilinx XPM macro to complete its internal reset sequence
    repeat(20) @(posedge clk);
  endtask

  task teardown();
    svunit_ut.teardown();
  endtask

  // ============================================================
  // Test Execution Block
  // ============================================================
  `SVUNIT_TESTS_BEGIN
  `include "tests.sv"
  `SVUNIT_TESTS_END

endmodule
