//------------------------------------------------------------------------------
// Testbench: tpv1_stack_tc00
// Description:
//   Unit tests for the stack module.
//   Tests: reset state, push, pop, empty/full flags, overflow/underflow.
//------------------------------------------------------------------------------

`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module tpv1_stack_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "tpv1_stack_ut";
    svunit_testcase svunit_ut;

    //--------------------------------------------------------------------------
    // Testbench parameters
    //--------------------------------------------------------------------------
  localparam CLK_FREQ = 100e6; //[Hz]
    localparam int B = 16;
    localparam int N = 8;
    localparam int MAX = 255;

    //--------------------------------------------------------------------------
    // DUT signals
    //--------------------------------------------------------------------------
    logic         tb_clk;
    logic         tb_rstn;
    logic         tb_en;
    logic         tb_op;
    logic [B-1:0] tb_din;
    logic [B-1:0] tb_dout;
    logic         tb_empty;
    logic         tb_full;

  initial begin
    $dumpfile("tpv1_stack.vcd");
    $dumpvars();
  end

    //--------------------------------------------------------------------------
    // Clock generation
    //--------------------------------------------------------------------------
  // Clock generator
  clk_gen #(
    .FREQ      ( CLK_FREQ   )
  ) u_clk_a_gen (
    .i_enable  ( 1'b1              ),
    .o_clk     ( tb_clk            )
  );

    default clocking cb @(posedge tb_clk);
      default input #1step output #2;
      output tb_rstn   ;
      output tb_en ;
      output tb_op ;
      output tb_din ;
      input  tb_dout ;
      input  tb_empty ;
      input  tb_full ;
    endclocking
    //--------------------------------------------------------------------------
    // DUT instantiation
    //--------------------------------------------------------------------------
    tpv1_stack #(
        .B(B)
    ) u_stack (
        .clk   (tb_clk),
        .rstn  (tb_rstn),
        .en    (tb_en),
        .op    (tb_op),
        .din   (tb_din),
        .dout  (tb_dout),
        .empty (tb_empty),
        .full  (tb_full)
    );


  //===================================
  // Build
  //===================================
  function void build();
    svunit_ut = new(name);
  endfunction

  //===================================
  // Setup for running the Unit Tests
  //===================================
  task setup();
      svunit_ut.setup();
      cb.tb_rstn <= 0;
      cb.tb_en   <= 0;
      cb.tb_op   <= 0;
      cb.tb_din  <= '0;
      repeat(4) @(cb);
      cb.tb_rstn <= 1;
      repeat(4) @(cb);
  endtask

  //===================================
  // Teardown
  //===================================
  task teardown();
    svunit_ut.teardown();
    tb_rstn <= 0;
    tb_en   <= 0;
  endtask

  //===================================
  // SVUNIT Tests
  //===================================
  `SVUNIT_TESTS_BEGIN
    `include "tpv1_stack_tests.sv"
  `SVUNIT_TESTS_END 

endmodule
