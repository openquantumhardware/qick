// ============================================================================
// File: dma_fifo_rd_tc00.sv
// Description: SVUnit testbench top-level for dma_fifo_rd. Single clock
//   domain, no XPM primitive involved, so the usual clocking-block style is
//   safe here (unlike the fifo_async-wrapping cores - see
//   TESTBENCH_PATTERNS.md #20).
//
//   Models the pop-based source as a simple FWFT-style mock: whenever
//   pop_req_o is asserted, fifo_dt_i presents WORD[read_idx] combinationally
//   and pop_ack_i mirrors pop_req_o immediately (the source is assumed to
//   always have data ready for the requested dma_len_i, matching how this
//   module is actually used - the caller only requests as many words as it
//   knows are already queued).
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module dma_fifo_rd_unit_test;
   import svunit_pkg::svunit_testcase;

   string name = "dma_fifo_rd_ut";
   svunit_testcase svunit_ut;

   localparam real CLOCK_FREQUENCY = 200e6;
   localparam int  MEM_AW = 8;
   localparam int  MEM_DW = 32;
   localparam int  DMA_DW = 32;

   logic                 tb_clk     = 1'b0;
   logic                 tb_rstn    = 1'b1;
   logic                 tb_req     = 1'b0;
   logic                 tb_ack;
   logic [MEM_AW-1:0]    tb_len     = '0;
   logic                 tb_pop_req;
   logic                 tb_pop_ack;
   logic [MEM_DW-1:0]    tb_fifo_dt;
   logic                 tb_tready  = 1'b1;
   logic [DMA_DW-1:0]    tb_tdata;
   logic                 tb_tvalid;
   logic                 tb_tlast;

   // Mock source: a simple word counter, advances on every acked pop.
   logic [MEM_DW-1:0] read_idx = '0;
   assign tb_pop_ack = tb_pop_req;
   assign tb_fifo_dt = 32'hA000_0000 + read_idx;

   always_ff @(posedge tb_clk, negedge tb_rstn) begin
      if (!tb_rstn) read_idx <= '0;
      else if (tb_pop_req) read_idx <= read_idx + 1'b1;
   end

   clk_gen #(.FREQ (CLOCK_FREQUENCY)) u_clk (.i_enable(1'b1), .o_clk(tb_clk));

   default clocking cb @(posedge tb_clk);
      output tb_rstn, tb_req, tb_len, tb_tready;
      input  tb_ack, tb_pop_req, tb_tdata, tb_tvalid, tb_tlast;
   endclocking

   initial begin
      $dumpfile("dma_fifo_rd.vcd");
      $dumpvars();
   end

   dma_fifo_rd #(
      .MEM_AW ( MEM_AW ),
      .MEM_DW ( MEM_DW ),
      .DMA_DW ( DMA_DW )
   ) dut (
      .clk_i            ( tb_clk     ),
      .rst_ni           ( tb_rstn    ),
      .dma_req_i        ( tb_req     ),
      .dma_ack_o        ( tb_ack     ),
      .dma_len_i        ( tb_len     ),
      .pop_req_o        ( tb_pop_req ),
      .pop_ack_i        ( tb_pop_ack ),
      .fifo_dt_i        ( tb_fifo_dt ),
      .m_axis_tready_i  ( tb_tready  ),
      .m_axis_tdata_o   ( tb_tdata   ),
      .m_axis_tvalid_o  ( tb_tvalid  ),
      .m_axis_tlast_o   ( tb_tlast   ),
      .dma_do           (            ),
      .dma_reg_do       (            )
   );

   // Request a transfer of `len` words, collect every beat (tdata) as it
   // is accepted (tvalid && tready), and return once tlast has been seen
   // or the timeout expires.
   task automatic run_transfer(int len, output int beats[], output bit ok);
      int collected[$];
      int cyc;

      cb.tb_len <= len;
      cb.tb_req <= 1'b1;
      @(cb);

      ok  = 1'b0;
      cyc = 0;
      while (1) begin
         // tb_tready is a clocking-block OUTPUT (driven by this bench), so
         // it must be sampled from the raw signal, not cb.tb_tready - xsim
         // rejects reading a clocking-block output outright (VRFC 10-3226).
         if (cb.tb_tvalid && tb_tready) begin
            collected.push_back(cb.tb_tdata);
            if (cb.tb_tlast) begin
               ok = 1'b1;
               break;
            end
         end
         @(cb);
         cyc++;
         if (cyc > 1000) break;
      end

      cb.tb_req <= 1'b0;
      // Wait for the FSM to actually return to IDLE (needs !dma_req_i &&
      // tready at the same cycle per the RTL).
      cyc = 0;
      while (cb.tb_ack !== 1'b0) begin
         @(cb);
         cyc++;
         if (cyc > 1000) begin
            ok = 1'b0;
            break;
         end
      end
      @(cb);

      beats = collected;
   endtask

   function void build();
      svunit_ut = new(name);
   endfunction

   task setup();
      svunit_ut.setup();
      cb.tb_req    <= 1'b0;
      cb.tb_len    <= '0;
      cb.tb_tready <= 1'b1;
      @(cb);
      cb.tb_rstn <= 1'b0;
      repeat(3) @(cb);
      cb.tb_rstn <= 1'b1;
      repeat(3) @(cb);
   endtask

   task teardown();
      svunit_ut.teardown();
   endtask

   `SVUNIT_TESTS_BEGIN
   `include "dma_fifo_rd_tests.sv"
   `SVUNIT_TESTS_END

endmodule
