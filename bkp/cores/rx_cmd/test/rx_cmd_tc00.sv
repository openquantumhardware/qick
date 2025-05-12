`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module rx_cmd_unit_test;
import svunit_pkg::svunit_testcase;
import qick_pkg::*;

  string name = "rx_cmd_ut";
  svunit_testcase svunit_ut;

  localparam CLOCK_FREQUENCY     = 250e6; //[Hz]

  localparam NCH                 = 2;
  localparam NB                  = 32;

  logic           tb_clk         = 1'b0;
  logic           tb_rstn        = 1'b1;
  //tx
  logic [ 4-1:0] tb_i_cfg_tick  = '0;
  logic          tb_i_valid  [NCH] = '{default:0};
  logic [ 8-1:0] tb_i_header [NCH] = '{default:0};
  logic [32-1:0] tb_i_data   [NCH] = '{default:0}; 
  logic          tb_o_ready  [NCH]               ;

//rx
  logic  [ 4-1:0] tb_i_id        = '0;
  logic           tb_o_valid     ;
  logic  [ 4-1:0] tb_o_op        ;
  logic  [32-1:0] tb_o_data      ;
  logic  [ 4-1:0] tb_o_chid      ;
  logic   [2-1:0] tb_o_dbg_cmd_state  ;   
  logic   [5-1:0] tb_o_dbg_state [NCH];   

  logic  [8-1:0]  s_header ;
  logic [32-1:0]  s_data   ;

  logic [NCH-1:0] tb_xcom_data = '0;
  logic [NCH-1:0] tb_xcom_clk  = '0;

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
  $dumpfile("rx_cmd.vcd");
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
  output  tb_rstn            ;
  output  tb_i_id            ;
  output  tb_i_cfg_tick    ;
  output  tb_i_valid       ;
  output  tb_i_header      ;
  output  tb_i_data        ;

  input   tb_o_ready         ;
  input   tb_o_valid         ;
  input   tb_o_op            ;
  input   tb_o_data          ;
  input   tb_o_chid          ;
  input   tb_o_dbg_cmd_state ;
  input   tb_o_dbg_state     ;
endclocking

//tx
genvar ind_tx;
generate
for (ind_tx=0; ind_tx < NCH ; ind_tx=ind_tx+1) begin: TX
    xcom_link_tx u_xcom_link_tx(
        .i_clk      (tb_clk        ),
        .i_rstn     (tb_rstn       ),
        .i_cfg_tick (tb_i_cfg_tick ),
        .i_valid    (tb_i_valid  [ind_tx]  ),
        .i_header   (tb_i_header [ind_tx]  ),
        .i_data     (tb_i_data   [ind_tx]  ), 
        .o_ready    (tb_o_ready  [ind_tx]  ),
        .o_data     (tb_xcom_data[ind_tx]  ),
        .o_clk      (tb_xcom_clk [ind_tx]  )
        );
    end
    endgenerate
 

//===================================
// This is the UUT that we're
// running the Unit Tests on
//===================================

rx_cmd#(.NCH(NCH)) u_rx_cmd(
  .i_clk           ( tb_clk             ),
  .i_rstn          ( tb_rstn            ),
  .i_id            ( tb_i_id            ),
  .i_xcom_data     ( tb_xcom_data       ),
  .i_xcom_clk      ( tb_xcom_clk        ),
  .o_valid         ( tb_o_valid         ),
  .o_op            ( tb_o_op            ),
  .o_data          ( tb_o_data          ),
  .o_chid          ( tb_o_chid          ),
  .o_dbg_cmd_state ( tb_o_dbg_cmd_state ),
  .o_dbg_state     ( tb_o_dbg_state     )
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
  $display("Starting simulation...");
//tx
    tb_cb.tb_i_cfg_tick <= '0;   
    tb_cb.tb_i_valid    <= '{default:0};   
    tb_cb.tb_i_header   <= '{default:0};   
    tb_cb.tb_i_data     <= '{default:0};

//rx
    tb_cb.tb_i_id        <= 4'b0010; 

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

task SIM_TX (); begin
   $display("SIM TX");
   tb_cb.tb_i_cfg_tick  <= 2;       //one bit every 2 clock cycles
   @(tb_cb);
   s_header <= {s_op.auto_id[3:0],4'b0010}; //no data, should trigger timeout. cmd=AUTO_ID, addr board=2
   s_data   <= 32'd8;
   repeat(10)@(tb_cb);
   TX_ALL();
   
   repeat(20)@(tb_cb);
   s_header <= {s_op.update_dt8[3:0],4'b0010};//8-bit data. cmd=Update DT8, addr board=2
   s_data   <= 32'd16;
   repeat(10)@(tb_cb);
   TX_ALL();
 
   repeat(20)@(tb_cb);
   s_header <= {s_op.update_dt16[3:0],4'b0001};//16-bit data. cmd=Update DT16, addr board=1
   s_data   <= 32'd24;
   repeat(10)@(tb_cb);
   TX_ALL();
 
   repeat(20)@(tb_cb);
   s_header <= {s_op.update_dt32[3:0],4'b0010};//32-bit data. cmd=Update DT32, addr board=10
   s_data   <= 32'd40;
   repeat(10)@(tb_cb);
   TX_ALL();
 
   repeat(20)@(tb_cb);
   s_header <= {s_op.qrst_sync[3:0],4'b0000};//no data, should trigger timeout. cmd=QRST_SYNC, addr board= broadcast
   s_data   <= 32'd40;
   repeat(10)@(tb_cb);
   TX_ALL();
   repeat(50)@(tb_cb);
 
end
endtask
 
task TX_ALL ; begin
   $display("TX_ALL");
   for (int ind_ch=0; ind_ch < NCH ; ind_ch=ind_ch+1) begin: STX
      tb_cb.tb_i_header[ind_ch] <= s_header;
      tb_cb.tb_i_data[ind_ch]   <= s_data;
      TX_DT(ind_ch);
   end
   repeat(100)@(tb_cb);
end
endtask
 
task TX_DT (input int channel); begin
   $display("TX_DT %d", channel);
   wait (tb_cb.tb_o_ready[channel] == 1'b1);
   @ (tb_cb);
   tb_cb.tb_i_valid[channel]     <= 1;
   wait (tb_cb.tb_o_ready[channel] == 1'b0);
   @ (tb_cb);
   tb_cb.tb_i_valid[channel]     <= 0;
end
endtask

task RX_ACK (input int channel); begin
   $display("RX ACK %d", tb_cb.tb_o_chid);
   wait (tb_cb.tb_o_valid == 1'b1);
   @ (tb_cb);
   tb_cb.tb_i_valid[channel]     <= 1;
   wait (tb_cb.tb_o_ready[channel] == 1'b0);
   @ (tb_cb);
   tb_cb.tb_i_valid[channel]     <= 0;
   $display("Out of RX ACK %d", tb_cb.tb_o_chid);
end
endtask

`SVUNIT_TESTS_BEGIN
`include "tests.sv"
`SVUNIT_TESTS_END 

endmodule
