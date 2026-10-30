// ============================================================================
// File: bram_to_axis_nt_tc00.sv
// Description: SVUnit testbench top-level for the bram_to_axis_nt module.
//              Tests NT-channel BRAM reader that outputs all channels sequentially.
// ============================================================================

`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module bram_to_axis_nt_unit_test;

  import svunit_pkg::svunit_testcase;

  string name = "bram_to_axis_nt_ut";
  svunit_testcase svunit_ut;

  // =========================================================================
  // Parameters
  // =========================================================================
  localparam real CLOCK_FREQUENCY = 200e6;
  localparam int NT = 4;            // Number of tables/channels (must be power of 2)
  localparam int N  = 4;            // Address width (depth = 2^N = 16)
  localparam int B  = 16;           // Data width per channel
  localparam int BRAM_WIDTH = NT * B;  // Total BRAM read width = 64 bits

  // =========================================================================
  // Signals
  // =========================================================================
  logic tb_clk = 1'b0;
  logic tb_rstn = 1'b1;

  // BRAM Interface
  logic               tb_mem_en;
  logic               tb_mem_we;
  logic [N-1:0]       tb_mem_addr;
  logic [BRAM_WIDTH-1:0] tb_mem_dout;
  logic [BRAM_WIDTH-1:0] tb_mem_din;

  // AXI4-Stream Interface
  logic               tb_m_axis_tready;
  logic [B-1:0]       tb_m_axis_tdata;
  logic               tb_m_axis_tvalid;
  logic               tb_m_axis_tlast;

  // Control register
  logic               tb_start_reg;

  // Mock BRAM memory (depth = 2^N, width = BRAM_WIDTH)
  logic [BRAM_WIDTH-1:0] mem[0:2**N-1];

  initial begin
    $dumpfile("bram_to_axis_nt.vcd");
    $dumpvars();
  end


  // =========================================================================
  // Clock Generation
  // =========================================================================
  clk_gen #(
      .FREQ(CLOCK_FREQUENCY)
  ) u_clk_gen (
      .i_enable(1'b1),
      .o_clk   (tb_clk)
  );

  // =========================================================================
  // DUT Instantiation
  // =========================================================================
  bram_to_axis_nt #(
      .NT (NT),
      .N  (N),
      .B  (B)
  ) u_bram_to_axis_nt (
      .rstn            (tb_rstn),
      .clk             (tb_clk),
      .mem_en          (tb_mem_en),
      .mem_we          (tb_mem_we),
      .mem_addr        (tb_mem_addr),
      .mem_dout        (tb_mem_dout),
      .mem_din         (tb_mem_din),
      .m_axis_tready   (tb_m_axis_tready),
      .m_axis_tdata    (tb_m_axis_tdata),
      .m_axis_tvalid   (tb_m_axis_tvalid),
      .m_axis_tlast    (tb_m_axis_tlast),
      .start_reg       (tb_start_reg)
  );

  // =========================================================================
  // Mock BRAM Behavior
  // =========================================================================
  initial begin
    // Initialize memory with known pattern
    for (int i = 0; i < 2**N; i++) begin
      for (int ch = 0; ch < NT; ch++) begin
        mem[i][(ch+1)*B-1 -: B] = (i * NT + ch) & 16'hFFFF;
      end
    end
  end

  always_ff @(posedge tb_clk) begin
    if (tb_mem_en && !tb_mem_we) begin
      tb_mem_dout <= mem[tb_mem_addr];
    end
  end

  // =========================================================================
  // Helper Tasks
  // =========================================================================

    // Reset DUT and also reset BRAM read position (by reinitializing memory pointer)
  task automatic reset_dut();
    // First, stop any ongoing transaction
    tb_start_reg <= 1'b0;
    @(posedge tb_clk);
    
    // Apply reset to DUT
    tb_rstn = 1'b0;
    repeat(3) @(posedge tb_clk);
    tb_rstn = 1'b1;
    
    // Reset BRAM read position (reinitialize memory with same data but reset address counter)
    // Note: We don't actually need to reinitialize memory, just wait for DUT to reset
    repeat(5) @(posedge tb_clk);
  endtask

  // Start reader - assert start_reg and HOLD it
  task automatic start_reader();
    @(posedge tb_clk);
    tb_start_reg <= 1'b1;
    repeat(2) @(posedge tb_clk);  // Wait for CDC/sync
  endtask

  // Stop reader - deassert start_reg
  task automatic stop_reader();
    @(posedge tb_clk);
    tb_start_reg <= 1'b0;
    repeat(2) @(posedge tb_clk);
  endtask

  // Set AXI tready
  task automatic set_tready(input logic value);
    tb_m_axis_tready = value;
  endtask

  // Wait for read completion (tlast asserted)
  task automatic wait_for_read_complete(input int timeout_cycles = 10000);
    int cycles = 0;
    @(posedge tb_clk);
    while (!(tb_m_axis_tvalid && tb_m_axis_tready && tb_m_axis_tlast)) begin
      @(posedge tb_clk);
      cycles++;
      if (cycles > timeout_cycles) begin
        $display("ERROR: Timeout waiting for tlast");
        break;
      end
    end
    @(posedge tb_clk);  // Extra cycle for END_ST
  endtask

  // Read all data from AXI output
  task automatic read_all_data(
    input  int           expected_count,
    output logic [B-1:0] data[]
  );
    int count;
    data = new[expected_count];

    set_tready(1'b1);

    for (count = 0; count < expected_count; count++) begin
      @(posedge tb_clk);
      while (!(tb_m_axis_tvalid && tb_m_axis_tready)) begin
        @(posedge tb_clk);
      end
      data[count] = tb_m_axis_tdata;
      $display("[READ] data[%0d] = 0x%0h, tlast=%b", count, data[count], tb_m_axis_tlast);
    end

    set_tready(1'b0);
    @(posedge tb_clk);
  endtask

  // Complete transfer: start, read, stop (does NOT call wait_for_read_complete)
  task automatic do_transfer(
    input  int           num_words,
    output logic [B-1:0] data[],
    input  int           timeout_cycles = 100000
  );
    start_reader();
    read_all_data(num_words, data);
    // No need to wait - read_all_data already consumed all data
    stop_reader();
  endtask

  // Verify data matches expected pattern
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

  // Write specific value to BRAM (for test setup)
  task automatic write_bram(
    input logic [N-1:0] addr,
    input int           channel,
    input logic [B-1:0] data
  );
    mem[addr][(channel+1)*B-1 -: B] = data;
  endtask

  // Get expected data pattern for sequential read
  function automatic logic [B-1:0] get_expected_data(
    input int word_index
  );
    int addr = word_index / NT;
    int ch   = word_index % NT;
    return mem[addr][(ch+1)*B-1 -: B];
  endfunction

  // =========================================================================
  // SVUnit
  // =========================================================================
  function void build();
    svunit_ut = new(name);
  endfunction

  task setup();
    svunit_ut.setup();
    set_tready(1'b0);
    tb_start_reg <= 1'b0;
    reset_dut();
  endtask

  task teardown();
    svunit_ut.teardown();
  endtask

    // Global timeout as safety net (increased for longer tests)
  initial begin
    #10000000;  // 10ms timeout (more than enough for all tests)
    $display("INFO: Global timeout reached - simulation ending");
    $finish;
  end

  `SVUNIT_TESTS_BEGIN
  `include "bram_to_axis_nt_tests.sv"
  `SVUNIT_TESTS_END

endmodule
