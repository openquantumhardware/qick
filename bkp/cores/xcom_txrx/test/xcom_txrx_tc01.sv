`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module xcom_txrx_unit_test;
import svunit_pkg::svunit_testcase;
import qick_pkg::*;


  string name = "xcom_txrx_cmd_ut";
  svunit_testcase svunit_ut;

  localparam CLOCK_FREQUENCY = 250e6; //[Hz]
  localparam SYNC_PULSE_FREQ = 5e6; //[Hz]

  localparam NB                 = 32;
  localparam NCH                = 2;

  logic          tb_clk         = 1'b0;
  logic          tb_rstn        = 1'b1;
  logic          tb_i_sync      = 1'b0;
  logic          tb_i_req_loc   = 1'b0;
  logic          tb_i_req_net   = 1'b0;
  logic [ 8-1:0] tb_i_header    = '0  ;
  logic [32-1:0] tb_i_data      = '0  ;
  logic          tb_o_ack_loc         ;
  logic          tb_o_ack_net         ;
  logic          tb_o_qp_ready        ;
  logic          tb_o_qp_valid        ;
  logic          tb_o_qp_flag         ;
  logic [32-1:0] tb_o_qp_data1        ;
  logic [32-1:0] tb_o_qp_data2        ;
  logic          tb_o_proc_start      ; 
  logic          tb_o_proc_stop       ; 
  logic          tb_o_time_rst        ; 
  logic          tb_o_time_update      ;
  logic [32-1:0] tb_o_time_update_data ;
  logic          tb_o_core_start      ;
  logic          tb_o_core_stop       ;
  logic [4-1:0]  tb_i_cfg_tick  = 1'b0;
  logic [ 4-1:0] tb_o_xcom_id         ;
  logic [32-1:0] tb_o_xcom_mem [15]   ;
  logic          tb_o_xcom_data       ;
  logic          tb_o_xcom_clk        ;
  logic [32-1:0] tb_o_dbg_rx_data     ;
  logic [32-1:0] tb_o_dbg_tx_data     ;
  logic [21-1:0] tb_o_dbg_status      ;                                                                                                                                                                                              
  logic [32-1:0] tb_o_dbg_data        ;

  //tx
  logic          tb_i_valid_tx  [NCH] = '{default:0};
  logic [ 8-1:0] tb_i_header_tx [NCH] = '{default:0};
  logic [32-1:0] tb_i_data_tx   [NCH] = '{default:0};
  logic          tb_o_ready_tx  [NCH]               ;

  logic  [8-1:0]  s_header ;
  logic [32-1:0]  s_data   ;

  logic [NCH-1:0] tb_xcom_data = '0;
  logic [NCH-1:0] tb_xcom_clk  = '0;

//xcom_cmd
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
  //end xcom_cmd

  logic [5-1:0][5-1:0] loc_op = {16, 17, 18, 19, 31};

initial begin
  $dumpfile("xcom_txrx_cmd.vcd");
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
  output  tb_i_sync        ;
  output  tb_i_req_loc     ;
  output  tb_i_req_net     ;
  output  tb_i_header      ;
  output  tb_i_data        ;
  output  tb_i_cfg_tick    ;
  output  tb_i_valid_tx       ;
  output  tb_i_header_tx      ;
  output  tb_i_data_tx        ;


  input   tb_o_ack_loc         ;
  input   tb_o_ack_net         ;
  input   tb_o_qp_ready        ;
  input   tb_o_qp_valid        ;
  input   tb_o_qp_flag         ;
  input   tb_o_qp_data1        ;
  input   tb_o_qp_data2        ;
  input   tb_o_proc_start      ;
  input   tb_o_proc_stop       ;
  input   tb_o_time_rst        ;
  input   tb_o_time_update     ;
  input   tb_o_time_update_data;
  input   tb_o_core_start      ;
  input   tb_o_core_stop       ;
  input   tb_o_xcom_id         ;
  input   tb_o_xcom_mem        ;
  input   tb_o_xcom_data       ;
  input   tb_o_xcom_clk        ;
  input   tb_o_dbg_rx_data     ;
  input   tb_o_dbg_tx_data     ;
  input   tb_o_dbg_status      ;
  input   tb_o_dbg_data        ;

  input   tb_o_ready_tx         ;

//xcom_cmd
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
  //end xcom_cmd
endclocking

initial begin
  tb_i_sync <= 1'b0;
  forever # (200) tb_i_sync <= ~tb_i_sync;  
end 

xcom_cmd u_xcom_cmd(
  .i_clk           ( tb_clk         ),
  .i_rstn          ( tb_rstn        ),
  .i_core_en       ( tb_i_core_en   ),
  .i_core_op       ( tb_i_core_op   ),
  .i_core_data     ( s_core_data    ),
  .i_ps_ctrl       ( tb_i_ps_ctrl   ),
  .i_ps_data       ( s_ps_data      ), 
  .o_req_loc       ( tb_o_req_loc   ),
  .i_ack_loc       ( tb_o_ack_loc   ),
  .o_req_net       ( tb_o_req_net   ),
  .i_ack_net       ( tb_o_ack_net   ),
  .o_op            ( tb_o_op        ),
  .o_data          ( tb_o_data      ),
  .o_data_cntr     ( tb_o_data_cntr )
  );

assign s_core_data = {tb_i_core_data,tb_i_core_addr};
assign s_ps_data    = {tb_i_ps_data,tb_i_ps_addr};
//===================================
// This is the UUT that we're
// running the Unit Tests on
//===================================

xcom_txrx #(
.NCH(NCH),
.SYNC(1'b1)
)
u_xcom_txrx
(
  .i_clk             ( tb_clk                ),
  .i_rstn            ( tb_rstn               ),
  .i_sync            ( tb_i_sync             ),
  .i_req_loc         ( tb_o_req_loc          ),
  .i_req_net         ( tb_o_req_net          ),
  .i_header          ( tb_o_op               ),
  .i_data            ( tb_o_data             ), 
  .o_ack_loc         ( tb_o_ack_loc          ),
  .o_ack_net         ( tb_o_ack_net          ),
  .o_qp_ready        ( tb_o_qp_ready         ),
  .o_qp_valid        ( tb_o_qp_valid         ),
  .o_qp_flag         ( tb_o_qp_flag          ),
  .o_qp_data1        ( tb_o_qp_data1         ),
  .o_qp_data2        ( tb_o_qp_data2         ),
  .o_proc_start      ( tb_o_proc_start       ),
  .o_proc_stop       ( tb_o_proc_stop        ),
  .o_time_rst        ( tb_o_time_rst         ),
  .o_time_update     ( tb_o_time_update      ),
  .o_time_update_data( tb_o_time_update_data ),
  .o_core_start      ( tb_o_core_start       ),
  .o_core_stop       ( tb_o_core_stop        ),
  .i_cfg_tick        ( tb_i_cfg_tick         ),
  .o_xcom_id         ( tb_o_xcom_id          ),
  .o_xcom_mem        ( tb_o_xcom_mem         ),
  .i_xcom_data       ( tb_xcom_data          ),
  .i_xcom_clk        ( tb_xcom_clk           ),
  .o_xcom_data       ( tb_o_xcom_data        ),
  .o_xcom_clk        ( tb_o_xcom_clk         ),
  .o_dbg_rx_data     ( tb_o_dbg_rx_data      ),
  .o_dbg_tx_data     ( tb_o_dbg_tx_data      ),
  .o_dbg_status      ( tb_o_dbg_status       ),
  .o_dbg_data        ( tb_o_dbg_data         )
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
    //tx
    tb_cb.tb_i_valid_tx    <= '{default:0};
    tb_cb.tb_i_header_tx   <= '{default:0};
    tb_cb.tb_i_data_tx     <= '{default:0};

    tb_cb.tb_i_req_loc  <= 1'b0;
    tb_cb.tb_i_req_net  <= 1'b0;
    tb_cb.tb_i_header   <= '0;
    tb_cb.tb_i_data     <= '0;

//xcom_cmd
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
  //end xcom_cmd
  
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

    tb_cb.tb_i_ps_ctrl[0]   <= 1'b1;
    tb_cb.tb_i_ps_ctrl[5:1] <= in_op;
    tb_cb.tb_i_ps_addr      <= $urandom_range(0,15);
    tb_cb.tb_i_ps_data      <= $urandom();
    repeat($urandom_range(1,100))@(tb_cb);
    //tb_cb.tb_i_ps_ctrl[0]   <= 1'b0;
    if (in_op < 16) begin
        tb_cb.tb_i_ack_net  <= 1'b1;
    end else begin
        tb_cb.tb_i_ack_loc  <= 1'b1;
    end
    repeat($urandom_range(1,10))@(tb_cb);
    if (in_op < 16) begin
        tb_cb.tb_i_ack_net      <= 1'b0;
    end else begin
        tb_cb.tb_i_ack_loc      <= 1'b0;
    end
    repeat($urandom_range(1,5))@(tb_cb);
endtask

task automatic write_core(input logic [NB-1:0] in_data, input logic [5-1:0] in_op);
    if (in_op < 16) begin
        $display("CORE writing NET...");
    end else begin
        $display("CORE writing LOC...");
    end
    tb_cb.tb_i_core_en   <= 1'b1;
    tb_cb.tb_i_core_op   <= in_op;
    tb_cb.tb_i_core_addr <= $urandom_range(0,15);
    tb_cb.tb_i_core_data <= $urandom();
    repeat($urandom_range(1,100))@(tb_cb);
    tb_cb.tb_i_core_en   <= 1'b0;
    if (in_op < 16) begin
        tb_cb.tb_i_ack_net      <= 1'b1;
    end else begin
        tb_cb.tb_i_ack_loc      <= 1'b1;
    end
    repeat($urandom_range(1,10))@(tb_cb);
    if (in_op < 16) begin
        tb_cb.tb_i_ack_net      <= 1'b0;
    end else begin
        tb_cb.tb_i_ack_loc      <= 1'b0;
    end
    repeat($urandom_range(1,5))@(tb_cb);

endtask

`SVUNIT_TESTS_BEGIN
`include "tests_cmd.sv"
`SVUNIT_TESTS_END 

endmodule
