`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module xcom_cmd_unit_test;
import svunit_pkg::svunit_testcase;
import qick_pkg::*;

  string name = "xcom_cmd_ut";
  svunit_testcase svunit_ut;

  localparam CLOCK_FREQUENCY = 250e6; //[Hz]
  localparam SYNC_PULSE_FREQ = 5e6; //[Hz]

  localparam NB                  = 32;

  logic          tb_clk          = 1'b0;
  logic          tb_rstn         = 1'b1;
  logic          tb_i_core_en    = 1'b0;
  logic [ 5-1:0] tb_i_core_op    = '0;
  logic [NB-1:0] tb_i_core_data  = '0;
  logic [NB-1:0] tb_i_core_addr  = '0;
  logic [NB-1:0] tb_i_ps_ctrl    = '0;
  logic [NB-1:0] tb_i_ps_data    = '0;
  logic [NB-1:0] tb_i_ps_addr    = '0;
  logic          tb_o_req_loc    ; 
  logic          tb_i_ack_loc    = 1'b0;
  logic          tb_o_req_net    ;
  logic          tb_i_ack_net    = 1'b0;
  logic  [8-1:0] tb_o_op         ; 
  logic [NB-1:0] tb_o_data       ;
  logic  [4-1:0] tb_o_data_cntr  ;

  logic  [2-1:0][NB-1:0] s_core_data    ;
  logic  [2-1:0][NB-1:0] s_ps_data       ;

  logic [NB-1:0] random_data;

  xcom_opcode_t s_op = '{
      rst         : 5'b1_1111  ,//LOC command 
      write_mem   : 5'b1_0011  ,//LOC command  
      write_reg   : 5'b1_0010  ,//LOC command  
      write_flag  : 5'b1_0001  ,//LOC command  
      set_id      : 5'b1_0000  ,//LOC command  
      rfu2        : 5'b0_1111  ,
      rfu1        : 5'b0_1101  ,
      qctrl       : 5'b0_1011  ,
      update_dt32 : 5'b0_1110  ,
      update_dt16 : 5'b0_1100  ,
      update_dt8  : 5'b0_1010  ,
      auto_id     : 5'b0_1001  ,
      qrst_sync   : 5'b0_1000  ,
      send_32bit_2: 5'b0_0111  ,
      send_32bit_1: 5'b0_0110  ,
      send_16bit_2: 5'b0_0101  ,
      send_16bit_1: 5'b0_0100  ,
      send_8bit_2 : 5'b0_0011  ,
      send_8bit_1 : 5'b0_0010  ,
      set_flag    : 5'b0_0001  ,
      clear_flag  : 5'b0_0000  
 };

initial begin
  $dumpfile("xcom_cmd.vcd");
  $dumpvars();
end

clk_gen
#(
  .FREQ       ( CLOCK_FREQUENCY   )
)
u_clk_gen
(
  .i_enable   ( 1'b1              ),
  .o_clk      ( tb_clk            )
);

clocking tb_cb @(posedge tb_clk);
  default input #1step output #2;
  output  tb_rstn          ;
  output  tb_i_core_en     ;
  output  tb_i_core_op     ;
  output  tb_i_core_data   ;
  output  tb_i_core_addr   ;
  output  tb_i_ps_ctrl     ;
  output  tb_i_ps_data     ;
  output  tb_i_ps_addr     ;
  output  tb_i_ack_loc     ;
  output  tb_i_ack_net     ;

  input   tb_o_req_loc     ;
  input   tb_o_req_net     ;
  input   tb_o_op          ;
  input   tb_o_data        ;
  input   tb_o_data_cntr   ;
endclocking

assign s_core_data = {tb_i_core_data,tb_i_core_addr};
assign s_ps_data    = {tb_i_ps_data,tb_i_ps_addr};

//===================================
// This is the UUT that we're
// running the Unit Tests on
//===================================

xcom_cmd u_xcom_cmd(
  .i_clk           ( tb_clk         ),
  .i_rstn          ( tb_rstn        ),
  .i_core_en       ( tb_i_core_en   ),
  .i_core_op       ( tb_i_core_op   ),
  .i_core_data     ( s_core_data    ),
  .i_ps_ctrl       ( tb_i_ps_ctrl   ),
  .i_ps_data       ( s_ps_data      ), 
  .o_req_loc       ( tb_o_req_loc   ),
  .i_ack_loc       ( tb_i_ack_loc   ),
  .o_req_net       ( tb_o_req_net   ),
  .i_ack_net       ( tb_i_ack_net   ),
  .o_op            ( tb_o_op        ),
  .o_data          ( tb_o_data      ),
  .o_data_cntr     ( tb_o_data_cntr )
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
  tb_cb.tb_i_core_en   <= 1'b0;
  tb_cb.tb_i_core_op   <= '0;   
  tb_cb.tb_i_core_data <= '0;   
  tb_cb.tb_i_core_addr <= '0;   
  tb_cb.tb_i_ps_ctrl   <= '0;
  tb_cb.tb_i_ps_data   <= '0;
  tb_cb.tb_i_ps_addr   <= '0;
  tb_cb.tb_i_ack_loc   <= 1'b0;
  tb_cb.tb_i_ack_net   <= 1'b0;

  @(tb_cb);
  tb_cb.tb_rstn    <= 1'b0;
  repeat(2) @(tb_cb);
  tb_cb.tb_rstn    <= 1'b1;
  repeat(5) @(tb_cb);

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

task automatic write_ps(input logic [NB-1:0] in_data, input logic [5-1:0] in_op);
    if (in_op < 16) begin
        $display("PS writing NET...");
    end else begin
        $display("PS writing LOC...");
    end

    for ( int i = 0 ; i < 10 ; i = i + 1 ) begin
        tb_cb.tb_i_ps_ctrl[0]   <= 1'b1;
        tb_cb.tb_i_ps_ctrl[5:1] <= in_op;
        tb_cb.tb_i_ps_addr      <= 32'd2;//$urandom_range(0,15);
        tb_cb.tb_i_ps_data      <= in_data + i;
        @(tb_cb);
        tb_cb.tb_i_ps_ctrl[0]   <= 1'b0;
        tb_cb.tb_i_ack_loc      <= 1'b1;
        @(tb_cb);
        tb_cb.tb_i_ack_loc      <= 1'b0;
        repeat($urandom_range(1,5))@(tb_cb);
    end   
endtask   

task automatic write_core(input logic [NB-1:0] in_data, input logic [5-1:0] in_op);
   $display("PS writing LOC...");
    for ( int i = 0 ; i < 10 ; i = i + 1 ) begin
        tb_cb.tb_i_core_en   <= 1'b1;
        tb_cb.tb_i_core_op   <= in_op;
        tb_cb.tb_i_core_addr <= 32'd2;//$urandom_range(0,15);
        tb_cb.tb_i_core_data <= in_data + i;
        @(tb_cb);
        tb_cb.tb_i_core_en   <= 1'b0;
        tb_cb.tb_i_ack_net    <= 1'b1;
        @(tb_cb);
        tb_cb.tb_i_ack_net    <= 1'b0;
        repeat($urandom_range(1,5))@(tb_cb);
    end   
endtask   

`SVUNIT_TESTS_BEGIN
`include "tests.sv"
`SVUNIT_TESTS_END 

endmodule
