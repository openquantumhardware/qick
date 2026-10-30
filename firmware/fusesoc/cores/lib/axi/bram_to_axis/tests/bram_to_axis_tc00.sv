// ============================================================================
// File: bram_to_axis_tc00.sv
// Description: SVUnit testbench top-level for the bram_to_axis module.
// ============================================================================

`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module bram_to_axis_unit_test;

  import svunit_pkg::svunit_testcase;

  string name = "bram_to_axis_ut";
  svunit_testcase svunit_ut;

  localparam real CLOCK_FREQUENCY = 200e6;
  localparam int N = 8;
  localparam int B = 16;
  localparam int BYTES = B / 8;

  logic tb_clk = 1'b0;
  logic tb_rstn = 1'b1;

  // Interfaces
  bram_if #(
      .NB_DATA(B),
      .NB_ADDR(N)
  ) bram_if_i (
      .i_clk(tb_clk),
      .i_rst(tb_rstn)
  );

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

  // Mock memory
  logic [B-1:0] mem[0:2**N-1];

  initial begin
    for (int i = 0; i < 2 ** N; i++) mem[i] = B'(i);
  end

  always_ff @(posedge tb_clk) begin
    if (bram_if_i.en) begin
      if (bram_if_i.we) begin
        mem[bram_if_i.addr] <= bram_if_i.din;
        bram_if_i.dout      <= bram_if_i.din;
      end else begin
        bram_if_i.dout <= mem[bram_if_i.addr];
      end
    end
  end

  initial begin
    $dumpfile("bram_to_axis.vcd");
    $dumpvars();
  end

  clk_gen #(
      .FREQ(CLOCK_FREQUENCY)
  ) u_clk_gen (
      .i_enable(1'b1),
      .o_clk   (tb_clk)
  );

  // Control signals
  logic         tb_start_reg;
  logic [N-1:0] tb_addr_reg;
  logic [  N:0] tb_len_reg;

  // DUT
  bram_to_axis #(
      .BRAM_ADDR_WIDTH(N),
      .BRAM_DATA_WIDTH(B)
  ) u_bram_to_axis (
      .rstn     (tb_rstn),
      .clk      (tb_clk),
      .mem_en    (bram_if_i.master.en),
      .mem_we    (bram_if_i.master.we),
      .mem_addr  (bram_if_i.master.addr),
      .mem_dout  (bram_if_i.master.dout),
      .mem_din   (bram_if_i.master.din),
      .m_axis_tready (axis_if.master.tready),
      .m_axis_tvalid (axis_if.master.tvalid),
      .m_axis_tdata  (axis_if.master.tdata),
      .m_axis_tlast  (axis_if.master.tlast),
      .start_reg(tb_start_reg),
      .addr_reg (tb_addr_reg),
      .len_reg  (tb_len_reg)
  );

  // =========================================================================
  // Helper Tasks 
  // =========================================================================

   task automatic reset_dut();
    // Ensure start_reg is deasserted before reset
    tb_start_reg <= 1'b0;
    @(posedge tb_clk);
    
    // Apply reset
    tb_rstn = 1'b0;
    repeat(3) @(posedge tb_clk);
    tb_rstn = 1'b1;
    
    // Clear control registers after reset
    tb_addr_reg  <= '0;
    tb_len_reg   <= '0;
    
    // Wait for DUT to stabilize
    repeat(5) @(posedge tb_clk);
  endtask

  // Start a transfer - asserts start_reg and keeps it high
  task automatic start_reader(
    input logic [N-1:0] addr,
    input logic [N:0]   len
  );
    @(posedge tb_clk);
    tb_addr_reg  <= addr;
    tb_len_reg   <= len;
    @(posedge tb_clk);
    tb_start_reg <= 1'b1;
  endtask

  // Stop the reader - deasserts start_reg
  task automatic stop_reader();
    @(posedge tb_clk);
    tb_start_reg <= 1'b0;
    repeat(2) @(posedge tb_clk);
  endtask

  task automatic set_tready(input logic value);
    axis_if.tready = value;
  endtask

  // Read all data - returns when all words have been read
  task automatic read_all_data(
    input  int           expected_count,
    output logic [B-1:0] data[]
  );
    int count;
    logic last;
    data = new[expected_count];

    set_tready(1'b1);

    for (count = 0; count < expected_count; count++) begin
      @(posedge tb_clk);
      while (!(axis_if.tvalid && axis_if.tready)) begin
        @(posedge tb_clk);
      end
      data[count] = axis_if.tdata;
      last = axis_if.tlast;
      $display("[READ] data[%0d] = 0x%0h, last=%b", count, data[count], last);
    end

    set_tready(1'b0);
    @(posedge tb_clk);
  endtask

  // Complete transfer: start, read data, and stop
  task automatic do_transfer(
    input logic [N-1:0] addr,
    input logic [N:0]   len,
    output logic [B-1:0] data[]
  );
    start_reader(addr, len);
    read_all_data(len, data);
    stop_reader();
  endtask

  task automatic read_with_backpressure(
    output logic [B-1:0] data,
    output logic last,
    input int stall_cycles
  );
    // Stall - deactivate ready
    set_tready(1'b0);
    repeat(stall_cycles) @(posedge tb_clk);

    // Ready to receive
    set_tready(1'b1);

    // Wait for handshake
    @(posedge tb_clk);
    while (!(axis_if.tvalid && axis_if.tready)) begin
      @(posedge tb_clk);
    end

    // Sample data
    data = axis_if.tdata;
    last = axis_if.tlast;
    $display("[READ] data = 0x%0h, last=%b", data, last);
  endtask

  task automatic verify_data(
    input logic [B-1:0] expected[],
    input logic [B-1:0] actual[],
    input string        test_name
  );
    for (int i = 0; i < expected.size(); i++) begin
      if (expected[i] !== actual[i]) begin
        $display("MISMATCH %s [%0d]: expected 0x%0h got 0x%0h", test_name, i, expected[i], actual[i]);
        `FAIL_IF(1);
      end
    end
  endtask

    task automatic write_bram(
    input logic [N-1:0] addr,
    input logic [B-1:0] data
  );
    // Use the BRAM interface to write
    bram_if_i.write_data(addr, data);
    // Wait for the write to complete
    @(posedge tb_clk);
    // Debug print
    $display("[WRITE] addr=0x%0h, data=0x%0h, mem[addr]=0x%0h", addr, data, mem[addr]);
  endtask

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
    tb_addr_reg  <= '0;
    tb_len_reg   <= '0;
    @(posedge tb_clk);
    reset_dut();
  endtask

  task teardown();
    svunit_ut.teardown();
  endtask

  `SVUNIT_TESTS_BEGIN
  `include "tests.sv"
  `SVUNIT_TESTS_END

endmodule