`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module xcom_unit_test;
import svunit_pkg::svunit_testcase;

  string name = "xcom_ut";
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
  logic [NB-1:0] tb_o_core_data1       ;
  logic [NB-1:0] tb_o_core_data2       ;
  logic          tb_i_core_ready        = 1'b0;
  logic          tb_i_core_valid        = 1'b0;
  logic          tb_i_core_flag         = 1'b0;
  logic          tb_o_core_ready       ;
  logic          tb_o_core_valid       ;
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

  logic  [2-1:0][NB-1:0] s_core_data    ;
  logic  [2-1:0][NB-1:0] s_ps_data       ;

  logic [NB-1:0] random_data;

  logic [ 4-1:0] tb_i_cfg_tick  = 4'b0000;
  logic          tb_i_req       = 1'b0;
  logic          tb_i_valid     = 1'b0;
  logic [ 8-1:0] tb_i_header    = 8'b0000_0000;
  logic [NB-1:0] tb_i_data      = 32'h00000000; 
  logic          tb_o_ready     ;
  logic          tb_o_data      ;
  logic          tb_o_clk       ;
  logic [2-1:0]  tb_o_dbg_state ; 

initial begin
  $dumpfile("xcom.vcd");
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
  output  tb_i_cfg_tick    ;
  output  tb_i_req         ;
  output  tb_i_valid       ;
  output  tb_i_header      ;
  output  tb_i_data        ;

  input   tb_o_ready       ;
  input   tb_o_data        ;
  input   tb_o_clk         ;
  input   tb_o_dbg_state   ;
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




//===================================
// This is the UUT that we're
// running the Unit Tests on
//===================================

xcom#(
   .NCH          ( 2 ),
   .SYNC         ( 1 ),
   .DEBUG        ( 1 )
) u_xcom(
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
   .o_core_ready       (tb_o_core_ready),   
   .o_core_data1       (tb_o_core_data1),   
   .o_core_data2       (tb_o_core_data2),   
   .o_core_valid       (tb_o_core_valid),   
   .o_core_flag        (),   
   .i_sync             (),   
   .o_proc_start       (),   
   .o_proc_stop        (),   
   .o_time_rst         (),   
   .o_time_update      (),   
   .o_time_update_data (),
   .o_core_start       (),   
   .o_core_stop        (),   
   .o_xcom_id          (),   
   .i_xcom_clk         (),   
   .i_xcom_data        (),   
   .o_xcom_clk         (),   
   .o_xcom_data        (),   
   .s_axi_awaddr       (),   
   .s_axi_awprot       (),   
   .s_axi_awvalid      (),   
   .s_axi_awready      (),   
   .s_axi_wdata        (),   
   .s_axi_wstrb        (),   
   .s_axi_wvalid       (),   
   .s_axi_wready       (),   
   .s_axi_bresp        (),   
   .s_axi_bvalid       (),   
   .s_axi_bready       (),   
   .s_axi_araddr       (),   
   .s_axi_arprot       (),                                                                                                                                                                                             
   .s_axi_arvalid      (),   
   .s_axi_arready      (),   
   .s_axi_rdata        (),
   .s_axi_rresp        (),
   .s_axi_rvalid       (),
   .s_axi_rready       ()
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

`SVUNIT_TESTS_BEGIN
`include "tests.sv"
`SVUNIT_TESTS_END 

endmodule
