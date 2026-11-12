// ============================================================================
// File: gcc_tc00.sv
// Description: SVUnit testbench top-level for gcc (gray code counter).
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module gcc_unit_test;
   import svunit_pkg::svunit_testcase;

   string name = "gcc_ut";
   svunit_testcase svunit_ut;

   localparam real CLOCK_FREQUENCY = 200e6;
   localparam int  DW = 4;

   logic             tb_clk         = 1'b0;
   logic             tb_rstn        = 1'b1;
   logic             tb_async_clear = 1'b0;
   logic             tb_cnt_en      = 1'b0;
   logic             tb_clear_o;
   logic [DW-1:0]    tb_bin_o;
   logic [DW-1:0]    tb_gray_o;
   logic [DW-1:0]    tb_bin_p1_o;
   logic [DW-1:0]    tb_gray_p1_o;

   clk_gen #(.FREQ (CLOCK_FREQUENCY)) u_clk (.i_enable(1'b1), .o_clk(tb_clk));

   default clocking cb @(posedge tb_clk);
      output tb_rstn;
      output tb_async_clear;
      output tb_cnt_en;
      input  tb_clear_o;
      input  tb_bin_o;
      input  tb_gray_o;
      input  tb_bin_p1_o;
      input  tb_gray_p1_o;
   endclocking

   initial begin
      $dumpfile("gcc.vcd");
      $dumpvars();
   end

   gcc #(
      .DW ( DW )
   ) dut (
      .clk_i            ( tb_clk         ),
      .rst_ni           ( tb_rstn        ),
      .async_clear_i    ( tb_async_clear ),
      .clear_o          ( tb_clear_o     ),
      .cnt_en_i         ( tb_cnt_en      ),
      .count_bin_o      ( tb_bin_o       ),
      .count_gray_o     ( tb_gray_o      ),
      .count_bin_p1_o   ( tb_bin_p1_o    ),
      .count_gray_p1_o  ( tb_gray_p1_o   )
   );

   // Reference: standard binary-reflected gray code, same formula as the DUT.
   function automatic logic [DW-1:0] bin2gray(logic [DW-1:0] b);
      return b ^ (b >> 1);
   endfunction

   // Pulse cnt_en_i for exactly one cycle.
   task automatic pulse_cnt_en();
      cb.tb_cnt_en <= 1'b1;
      @(cb);
      cb.tb_cnt_en <= 1'b0;
   endtask

   function void build();
      svunit_ut = new(name);
   endfunction

   task setup();
      svunit_ut.setup();
      cb.tb_async_clear <= 1'b0;
      cb.tb_cnt_en      <= 1'b0;
      @(cb);
      cb.tb_rstn <= 1'b0;
      repeat(2) @(cb);
      cb.tb_rstn <= 1'b1;
      repeat(3) @(cb);
   endtask

   task teardown();
      svunit_ut.teardown();
   endtask

   `SVUNIT_TESTS_BEGIN
   `include "gcc_tests.sv"
   `SVUNIT_TESTS_END

endmodule
