`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module fifo_unit_test;
import svunit_pkg::svunit_testcase;

  string name = "fifo_ut";
  svunit_testcase svunit_ut;

  localparam CLOCK_FREQUENCY = 250e6; // [Hz]

  localparam int B = 16;  // Data width
  localparam int N = 4;   // FIFO depth
  // Capacity is N-1 words: full when wptr == rptr - 1 (the legacy fifo.vhd
  // this core ports keeps one slot free to tell full from empty).
  localparam int CAP = N - 1;

  logic          tb_clk   = 1'b0;
  logic          tb_rstn  = 1'b1;

  // Write I/F
  logic          tb_wr_en = 1'b0;
  logic [B-1:0]  tb_din   = '0;

  // Read I/F
  logic          tb_rd_en = 1'b0;
  logic [B-1:0]  tb_dout;

  // Flags
  logic          tb_full;
  logic          tb_empty;

  initial begin
    $dumpfile("fifo.vcd");
    $dumpvars();
  end

  // Clock generator
  clk_gen
  #(
    .FREQ       ( CLOCK_FREQUENCY )
  )
  u_clk_gen
  (
    .i_enable   ( 1'b1            ),
    .o_clk      ( tb_clk          )
  );

  default clocking cb @(posedge tb_clk);
    output tb_rstn;
    output tb_wr_en;
    output tb_din;
    output tb_rd_en;
    input  tb_dout;
    input  tb_full;
    input  tb_empty;
  endclocking

  //===================================
  // UUT
  //===================================
  fifo #(
    .B ( B ),
    .N ( N )
  ) u_fifo (
    .rstn  ( tb_rstn  ),
    .clk   ( tb_clk   ),
    .wr_en ( tb_wr_en ),
    .din   ( tb_din   ),
    .rd_en ( tb_rd_en ),
    .dout  ( tb_dout  ),
    .full  ( tb_full  ),
    .empty ( tb_empty )
  );

  //===================================
  // Helper tasks
  //===================================

  // Write a single word — ignored if full
  task automatic write_word(input logic [B-1:0] data);
    cb.tb_din   <= data;
    cb.tb_wr_en <= 1'b1;
    @(cb);
    cb.tb_wr_en <= 1'b0;
    cb.tb_din   <= '0;
  endtask

// Read a single word with correct BRAM latency
// Safe for isolated reads — NOT for back-to-back loops
task automatic read_word(output logic [B-1:0] data);
    cb.tb_rd_en <= 1'b1;
    @(cb);
    cb.tb_rd_en <= 1'b0;
    @(cb); // BRAM latency
    data = tb_dout;
endtask

// Read N words back-to-back with pipelined BRAM latency
// Use this instead of calling read_word in a loop
task automatic read_n_words(
    input  int           count,
    output logic [B-1:0] out_data[$]
);
    out_data = {};
    // Assert rd_en for 'count' cycles while FIFO is not empty
    for (int k = 0; k < count; k++) begin
        if (!tb_empty) begin
            cb.tb_rd_en <= 1'b1;
        end else begin
            cb.tb_rd_en <= 1'b0;
        end
        @(cb);
        // Data valid 1 cycle after rd_en — capture starting from k>=1.
        // cb.tb_dout is sampled just before this edge, i.e. the word the
        // previous rd_en loaded (the raw tb_dout already shows the next one).
        if (k >= 1)
            out_data.push_back(cb.tb_dout);
    end
    cb.tb_rd_en <= 1'b0;
    @(cb); // capture last word
    out_data.push_back(cb.tb_dout);
endtask

  // Offer N words; the last one is refused (capacity CAP = N-1)
  task automatic fill_fifo(input logic [B-1:0] base_val);
    for (int i = 0; i < N; i++) begin
      cb.tb_din   <= base_val + B'(i);
      cb.tb_wr_en <= 1'b1;
      @(cb);
    end
    cb.tb_wr_en <= 1'b0;
    cb.tb_din   <= '0;
    @(cb);
  endtask

  // Drain FIFO completely, collect data into queue
  task automatic drain_fifo(output logic [B-1:0] out_data[$]);
    out_data = {};
    while (!tb_empty) begin
      cb.tb_rd_en <= 1'b1;
      @(cb);
      cb.tb_rd_en <= 1'b0;
      @(cb); // BRAM read latency
      out_data.push_back(tb_dout);
    end
  endtask

  //===================================
  // Build
  //===================================
  function void build();
    svunit_ut = new(name);
  endfunction

  //===================================
  // Setup
  //===================================
  task setup();
    svunit_ut.setup();

    cb.tb_wr_en <= 1'b0;
    cb.tb_rd_en <= 1'b0;
    cb.tb_din   <= '0;

    // Synchronous reset
    @(cb);
    cb.tb_rstn <= 1'b0;
    repeat(2) @(cb);
    cb.tb_rstn <= 1'b1;
    repeat(3) @(cb);
  endtask

  //===================================
  // Teardown
  //===================================
  task teardown();
    svunit_ut.teardown();
  endtask

  //===================================
  // Tests
  //===================================
  `SVUNIT_TESTS_BEGIN
  `include "tests.sv"
  `SVUNIT_TESTS_END

endmodule
