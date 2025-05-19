`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module xcom_cmd_unit_test;
import svunit_pkg::svunit_testcase;
import qick_pkg::*;

  string name = "xcom_cmd_ut";
  svunit_testcase svunit_ut;

    localparam T_FREQ          = 440.08e6; //[Hz]
    localparam CORE_FREQ       = 200e6;    //200e6 [Hz]
    localparam PS_FREQ         = 100e6;    //100e6 [Hz]
    localparam CORE_PERIOD     = 5;        //200e6 [Hz]
    localparam PS_PERIOD       = 10;       //100e6 [Hz]
    localparam SYNC_PERIOD     = 200;      //5e6 [Hz]

  localparam NB                         = 32;

  logic          tb_time_clk            = 1'b0;
  logic          tb_time_rstn           = 1'b1;
  logic          tb_core_clk            = 1'b0;
  logic          tb_core_rstn           = 1'b1;
  logic          tb_ps_clk              = 1'b0;
  logic          tb_ps_rstn             = 1'b1;

  logic          tb_i_sync              = 1'b0;

  logic          tb_i_core_en           = 1'b0;
  logic [ 5-1:0] tb_i_core_op           = '0;
  logic [NB-1:0] tb_i_core_data1        = '0;
  logic [NB-1:0] tb_i_core_data2        = '0;
  logic          tb_o_core_en_sync          ;
  logic [ 5-1:0] tb_o_core_op_sync          ;
  logic [NB-1:0] tb_o_core_data1_sync       ;
  logic [NB-1:0] tb_o_core_data2_sync       ;
  logic          tb_i_core_ready        = 1'b0;
  logic          tb_i_core_valid        = 1'b0;
  logic          tb_i_core_flag         = 1'b0;
  logic          tb_o_core_ready_sync       ;
  logic          tb_o_core_valid_sync       ;
  logic          tb_o_core_flag_sync        ;
  logic          tb_i_ack_loc           = 1'b0;
  logic          tb_i_ack_net           = 1'b0;
  logic  [4-1:0] tb_i_xcom_id           = '0;
  logic  [4-1:0] tb_o_xcom_id_sync          ;
  logic [NB-1:0] tb_i_xcom_ctrl         = '0;
  logic [NB-1:0] tb_i_xcom_cfg          = '0;
  logic [NB-1:0] tb_i_axi_data1         = '0;
  logic [NB-1:0] tb_i_axi_data2         = '0;
  logic [NB-1:0] tb_o_xcom_ctrl_sync        ;
  logic [NB-1:0] tb_o_xcom_cfg_sync         ;
  logic [NB-1:0] tb_o_axi_data1_sync        ;
  logic [NB-1:0] tb_o_axi_data2_sync        ;
  logic [NB-1:0] tb_o_xcom_flag_sync        ;
  logic [NB-1:0] tb_o_xcom_data1_sync       ;
  logic [NB-1:0] tb_o_xcom_data2_sync       ;
  logic [NB-1:0] tb_i_xcom_rx_data      = '0;
  logic [NB-1:0] tb_i_xcom_tx_data      = '0;
  logic [NB-1:0] tb_i_xcom_status       = '0;
  logic [NB-1:0] tb_i_xcom_debug        = '0;
  logic [NB-1:0] tb_o_xcom_rx_data_sync     ;
  logic [NB-1:0] tb_o_xcom_tx_data_sync     ;
  logic [NB-1:0] tb_o_xcom_status_sync      ;
  logic [NB-1:0] tb_o_xcom_debug_sync       ;
  logic [NB-1:0] tb_i_core_addr         = '0;
  logic [NB-1:0] tb_i_ps_ctrl           = '0;
  logic [NB-1:0] tb_i_ps_data           = '0;
  logic [NB-1:0] tb_i_ps_addr           = '0;
  logic          tb_o_req_loc           ; 
  logic          tb_o_req_net           ;
  logic  [8-1:0] tb_o_op                ; 
  logic [NB-1:0] tb_o_data              ;
  logic  [4-1:0] tb_o_data_cntr         ;

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

initial begin
  tb_i_sync <= 1'b0;
  forever # (SYNC_PERIOD/2) tb_i_sync <= ~tb_i_sync;
end

clk_gen
#(
  .FREQ       ( T_FREQ   )
)
u_clk_gen
(
  .i_enable   ( 1'b1              ),
  .o_clk      ( tb_time_clk       )
);

clk_gen
#(
  .FREQ       ( CORE_FREQ   )
)
u_clk_gen_core
(
  .i_enable   ( 1'b1              ),
  .o_clk      ( tb_core_clk       )
);

clk_gen
#(
  .FREQ       ( PS_FREQ   )
)
u_clk_gen_ps
(
  .i_enable   ( 1'b1              ),
  .o_clk      ( tb_ps_clk         )
);

clocking cb @(posedge tb_time_clk);
  default input #1step output #2;
  output  tb_time_rstn     ;
  output  tb_i_core_valid  ;
  output  tb_i_core_ready  ;
endclocking

clocking cb_core @(posedge tb_core_clk);
  default input #1step output #2;
  output  tb_core_rstn     ;
  output  tb_i_core_en     ;
  output  tb_i_core_op     ;
  output  tb_i_core_data1  ;
  output  tb_i_core_data2  ;
endclocking

clocking cb_ps @(posedge tb_ps_clk);
  default input #1step output #2;
  output  tb_ps_rstn     ;
endclocking

assign s_core_data = {tb_i_core_data1,tb_i_core_addr};
assign s_ps_data    = {tb_i_ps_data,tb_i_ps_addr};

//===================================
// This is the UUT that we're
// running the Unit Tests on
//===================================

xcom_cdc#(
   .NCH          ( 2 ),
   .SYNC         ( 1 ),
   .DEBUG        ( 1 )
) u_xcom_cdc(
   .i_ps_clk           ( tb_ps_clk             ),
   .i_ps_rstn          ( tb_ps_rstn            ),
   .i_core_clk         ( tb_core_clk           ),
   .i_core_rstn        ( tb_core_rstn          ),
   .i_time_clk         ( tb_time_clk           ),
   .i_time_rstn        ( tb_time_rstn          ),
   .i_core_en          ( tb_i_core_en          ),
   .i_core_op          ( tb_i_core_op          ),
   .i_core_data1       ( tb_i_core_data1       ),
   .i_core_data2       ( tb_i_core_data2       ),
   .o_core_en_sync     ( tb_o_core_en_sync     ),
   .o_core_op_sync     ( tb_o_core_op_sync     ),
   .o_core_data1_sync  ( tb_o_core_data1_sync  ),
   .o_core_data2_sync  ( tb_o_core_data2_sync  ),
   .i_core_ready       ( tb_i_core_ready       ),
   .i_core_valid       ( tb_i_core_valid       ),
   .i_core_flag        ( tb_i_core_flag        ),
   .o_core_ready_sync  ( tb_o_core_ready_sync  ),
   .o_core_valid_sync  ( tb_o_core_valid_sync  ),
   .o_core_flag_sync   ( tb_o_core_flag_sync   ),
   .i_xcom_id          ( tb_i_xcom_id          ),
   .o_xcom_id_sync     ( tb_o_xcom_id_sync     ),
   .i_xcom_ctrl        ( tb_i_xcom_ctrl        ),
   .i_xcom_cfg         ( tb_i_xcom_cfg         ),
   .i_axi_data1        ( tb_i_axi_data1        ),
   .i_axi_data2        ( tb_i_axi_data2        ),
   .o_xcom_ctrl_sync   ( tb_o_xcom_ctrl_sync   ),
   .o_xcom_cfg_sync    ( tb_o_xcom_cfg_sync    ),
   .o_axi_data1_sync   ( tb_o_axi_data1_sync   ),
   .o_axi_data2_sync   ( tb_o_axi_data2_sync   ),
   .o_xcom_flag_sync   ( tb_o_xcom_flag_sync   ),
   .o_xcom_data1_sync  ( tb_o_xcom_data1_sync  ),
   .o_xcom_data2_sync  ( tb_o_xcom_data2_sync  ),
   .i_xcom_rx_data     ( tb_i_xcom_rx_data     ),
   .i_xcom_tx_data     ( tb_i_xcom_tx_data     ),
   .i_xcom_status      ( tb_i_xcom_status      ),
   .i_xcom_debug       ( tb_i_xcom_debug       ),
   .o_xcom_rx_data_sync( tb_o_xcom_rx_data_sync),
   .o_xcom_tx_data_sync( tb_o_xcom_tx_data_sync),
   .o_xcom_status_sync ( tb_o_xcom_status_sync ),
   .o_xcom_debug_sync  ( tb_o_xcom_debug_sync  )
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
  tb_i_core_en    <= 1'b0;
  tb_i_core_op    <= '0;   
  tb_i_core_data1 <= '0;   
  tb_i_core_data2 <= '0;   
  tb_i_core_valid <= 1'b0;
  tb_i_core_ready <= 1'b0;
  tb_i_core_flag  <= '0;   
  tb_i_xcom_id    <= '0;   

  @(cb_core);
  tb_core_rstn    <= 1'b0;
  repeat(2) @(cb_core);
  tb_core_rstn    <= 1'b1;
  repeat(5) @(cb_core);

  @(cb_ps);
  tb_ps_rstn      <= 1'b0;
  repeat(2) @(cb_ps);
  tb_ps_rstn      <= 1'b1;
  repeat(5) @(cb_ps);

  @(cb);
  tb_time_rstn    <= 1'b0;
  repeat(2) @(cb);
  tb_time_rstn    <= 1'b1;
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

task automatic write_ps(input logic [NB-1:0] in_data, input logic [5-1:0] in_op);
    if (in_op < 16) begin
        $display("PS writing NET...");
    end else begin
        $display("PS writing LOC...");
    end

    for ( int i = 0 ; i < 10 ; i = i + 1 ) begin
        tb_i_ps_ctrl[0]   <= 1'b1;
        tb_i_ps_ctrl[5:1] <= in_op;
        tb_i_ps_addr      <= 32'd2;//$urandom_range(0,15);
        tb_i_ps_data      <= in_data + i;
        @(cb);
        tb_i_ps_ctrl[0]   <= 1'b0;
        tb_i_ack_loc      <= 1'b1;
        @(cb);
        tb_i_ack_loc      <= 1'b0;
        repeat($urandom_range(1,5))@(cb);
    end   
endtask   

task automatic write_core(input logic [NB-1:0] in_data, input logic [5-1:0] in_op);
   $display("PS writing LOC...");
    for ( int i = 0 ; i < 10 ; i = i + 1 ) begin
        tb_i_core_en   <= 1'b1;
        tb_i_core_op   <= in_op;
        tb_i_core_addr <= 32'd2;//$urandom_range(0,15);
        tb_i_core_data1 <= in_data + i;
        @(cb);
        tb_i_core_en   <= 1'b0;
        tb_i_ack_net    <= 1'b1;
        @(cb);
        tb_i_ack_net    <= 1'b0;
        repeat($urandom_range(1,5))@(cb);
    end   
endtask   

`SVUNIT_TESTS_BEGIN
`include "tests.sv"
`SVUNIT_TESTS_END 

endmodule
