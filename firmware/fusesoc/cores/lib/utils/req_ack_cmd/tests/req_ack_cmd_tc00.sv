`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module req_ack_cmd_unit_test;
  import svunit_pkg::svunit_testcase;

  string name = "req_ack_cmd_ut";
  svunit_testcase svunit_ut;

  localparam CLOCK_FREQUENCY = 250e6; //[Hz]

  localparam NB               = 32;

  logic          tb_clk         = 1'b0;
  logic          tb_rstn        = 1'b1;
  logic          tb_i_valid     = 1'b0;
  logic  [5-1:0] tb_i_op        = '0; 
  logic  [4-1:0] tb_i_addr      = '0; 
  logic [NB-1:0] tb_i_data      = '0; 
  logic          tb_i_ack       = 1'b0;
  logic          tb_o_req_loc   ;
  logic          tb_o_req_net   ;
  logic  [8-1:0] tb_o_op        ;
  logic [NB-1:0] tb_o_data      ;
  logic  [4-1:0] tb_o_cmd_cntr ;

  logic [NB-1:0] random_data;

  initial begin
    $dumpfile("req_ack_cmd.vcd");
    $dumpvars();
  end

  clk_gen#(
    .FREQ       ( CLOCK_FREQUENCY   )
  )u_clk_gen(
    .i_enable   ( 1'b1              ),
    .o_clk      ( tb_clk            )
  );

  clocking cb @(posedge tb_clk);
    default input #1step output #2;
    output  tb_rstn          ;
    output  tb_i_valid       ;
    output  tb_i_op          ;
    output  tb_i_addr        ;
    output  tb_i_data        ;
    output  tb_i_ack         ;

    input   tb_o_req_loc     ;
    input   tb_o_req_net     ;
    input   tb_o_op          ;
    input   tb_o_data        ;
    input   tb_o_cmd_cntr   ;
  endclocking

  //===================================
  // This is the UUT that we're
  // running the Unit Tests on
  //===================================

  req_ack_cmd u_req_ack_cmd(
    .i_clk      (tb_clk        ),
    .i_rstn     (tb_rstn       ),
    .i_valid    (tb_i_valid    ),
    .i_op       (tb_i_op       ),
    .i_addr     (tb_i_addr     ), 
    .i_data     (tb_i_data     ), 
    .i_ack      (tb_i_ack      ),
    .o_req_loc  (tb_o_req_loc  ),
    .o_req_net  (tb_o_req_net  ),
    .o_op       (tb_o_op       ),
    .o_data     (tb_o_data     ),
    .o_cmd_cntr (tb_o_cmd_cntr )
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
    random_data = $urandom();
    cb.tb_i_valid <= 1'b0;   
    cb.tb_i_op    <= '0;   
    cb.tb_i_addr  <= '0;   
    cb.tb_i_data  <= '0;
    cb.tb_i_ack   <= 1'b0; 

    @(cb);
    cb.tb_rstn    <= 1'b0;
    repeat(2) @(cb);
    cb.tb_rstn    <= 1'b1;
    repeat(5) @(cb);

  endtask

  //===================================
  // Here we deconstruct anything we 
  // need after running the Unit Tests
  //===================================
  task teardown();
    svunit_ut.teardown();
  endtask

  //===================================
  // All tests are defined between the
  // SVUNIT_TESTS_BEGIN/END macros
  //
  // Each individual test must be
  // defined between `SVTEST(_NAME_)
  // `SVTEST_END
  //
  // i.e.
  //   `SVTEST(mytest)
  //     <test code>
  //   `SVTEST_END
  //===================================

  task automatic write_loc(input logic [NB-1:0] in_data, input logic [5-1:0] in_op);
    logic [NB-1:0] data_value;
    logic [3:0] addr_value;

    $display("=== Starting write_loc: base_data=%0d, op=%0d ===", in_data, in_op);

    for (int i = 0; i < 10; i = i + 1) begin
      data_value = in_data + i;
      addr_value = $urandom_range(0,15);

      // Assignments
      cb.tb_i_valid <= 1'b1;
      cb.tb_i_op    <= in_op;
      cb.tb_i_addr  <= addr_value;
      cb.tb_i_data  <= data_value;

      // Display with calculated values
      $display("[%0t] Iteration %0d: data=%0d, op=%0d, addr=%0d",
        $time, i, data_value, in_op, addr_value);

      @(cb);
      cb.tb_i_valid <= 1'b0;
      // Esperar a que alguna de las señales de request se active
      wait(cb.tb_o_req_net || cb.tb_o_req_loc);
      $display("Request detected!");
      //@(cb);
      cb.tb_i_ack   <= 1'b1;
      @(cb);
      cb.tb_i_ack   <= 1'b0;
      repeat($urandom_range(1,5)) @(cb);
    end

    $display("=== Completed write_loc ===\n");
  endtask

  `SVUNIT_TESTS_BEGIN
  `include "tests.sv"
  `SVUNIT_TESTS_END 

endmodule
