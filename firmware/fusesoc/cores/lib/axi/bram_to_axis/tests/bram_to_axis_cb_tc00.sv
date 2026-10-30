// ============================================================================
// File: bram_to_axis_tc00.sv
// Description: SVUnit testbench top-level for the bram_to_axis module.
//              Version with clocking block 
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
    ) axis_if_i (
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
        bram_if_i.dout      <= bram_if_i.din; // Write-First behavior, similar to bram_tdp
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
      .m_axis_tready (axis_if_i.master.tready),
      .m_axis_tvalid (axis_if_i.master.tvalid),
      .m_axis_tdata  (axis_if_i.master.tdata),
      .m_axis_tlast  (axis_if_i.master.tlast),
      .start_reg(tb_start_reg),
      .addr_reg (tb_addr_reg),
      .len_reg  (tb_len_reg)
  );

  // =========================================================================
  // CLOCKING BLOCK
  // =========================================================================
  default clocking tb_cb @(posedge tb_clk);
    default input #1step output #2;

    // Outputs (testbench drives these)
    output tb_rstn;
    output tb_start_reg;
    output tb_addr_reg;
    output tb_len_reg;
  endclocking

  // =========================================================================
  // Helper Tasks
  // =========================================================================

  task automatic reset_dut();
    tb_cb.tb_rstn <= 1'b0;
    repeat (3) @(tb_cb);
    tb_cb.tb_rstn <= 1'b1;
    repeat (5) @(tb_cb);
  endtask

  task automatic start_reader(input logic [N-1:0] addr, input logic [N:0] len);
    @(tb_cb);
    tb_cb.tb_addr_reg <= addr;
    tb_cb.tb_len_reg  <= len;
    @(tb_cb);
    tb_cb.tb_start_reg <= 1'b1;
    @(tb_cb);
    tb_cb.tb_start_reg <= 1'b0;
  endtask

  // Read multiple data - use clocking block for synchronization
  task automatic read_all_data(input int expected_count, output logic [B-1:0] data[]);
    int   count;
    logic last;
    data = new[expected_count];

    // Asignment through the clocking block
    axis_if_i.s_cb.tready <= 1'b1;

    for (count = 0; count < expected_count; count++) begin
      // Wait tvalid protected by s_cb
      do @(axis_if_i.s_cb); while (!axis_if_i.s_cb.tvalid);

      // Capture data protected
      data[count] = axis_if_i.s_cb.tdata;
      last = axis_if_i.s_cb.tlast;

      $display("[READ] data[%0d] = 0x%0h, last=%b", count, data[count], last);

      // Verify last
      if (count == expected_count - 1) begin
        if (last !== 1'b1) begin
          $display("ERROR: last not asserted on final beat %0d", count);
          `FAIL_IF(1);
        end
      end else begin
        if (last !== 1'b0) begin
          $display("ERROR: last asserted early on beat %0d", count);
          `FAIL_IF(1);
        end
      end
    end

    // Deactivate tready
    axis_if_i.s_cb.tready <= 1'b0;
    @(axis_if_i.s_cb);
  endtask

  // Read with backpressure - stall before reading
  task automatic read_with_backpressure(output logic [B-1:0] data, output logic last,
                                        input int stall_cycles);
    // Stall: tready = 0 via s_cb
    axis_if_i.s_cb.tready <= 1'b0;
    repeat (stall_cycles) @(axis_if_i.s_cb);

    // Activate ready
    axis_if_i.s_cb.tready <= 1'b1;

    // Handshake: tvalid via s_cb, tready crude!
    do @(axis_if_i.s_cb); while (!(axis_if_i.s_cb.tvalid && axis_if_i.tready));

    // Capture data protected by s_cb
    data = axis_if_i.s_cb.tdata;
    last = axis_if_i.s_cb.tlast;
    $display("[READ] data = 0x%0h, last=%b", data, last);
  endtask

  task automatic verify_data(input logic [B-1:0] expected[], input logic [B-1:0] actual[],
                             input string test_name);
    for (int i = 0; i < expected.size(); i++) begin
      if (expected[i] !== actual[i]) begin
        $display("MISMATCH %s [%0d]: expected 0x%0h got 0x%0h", test_name, i, expected[i],
                 actual[i]);
        `FAIL_IF(1);
      end
    end
  endtask

  task automatic write_bram(input logic [N-1:0] addr, input logic [B-1:0] data);
    bram_if_i.write_data(addr, data);
  endtask

  // =========================================================================
  // SVUnit
  // =========================================================================
  function void build();
    svunit_ut = new(name);
  endfunction

  task setup();
    svunit_ut.setup();

    // Inicializar usando clocking block
    tb_cb.tb_start_reg <= 1'b0;
    tb_cb.tb_addr_reg <= '0;
    tb_cb.tb_len_reg <= '0;
    axis_if_i.s_cb.tready <= 1'b0;

    @(tb_cb);
    reset_dut();
  endtask

  task teardown();
    svunit_ut.teardown();
  endtask

  `SVUNIT_TESTS_BEGIN
  `include "tests_cb.sv"
`SVUNIT_TESTS_END

endmodule
