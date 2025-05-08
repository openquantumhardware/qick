///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
//
// Fermi Fordward Alliance LLC
//
// Module: xcom_cmd.sv
// Project: QICK 
// Description: 
// Wrapper and synchronizer block for the XCOM core.
// 
//Inputs:
// - i_clk      clock signal
// - i_rstn     active low reset signal
// - i_sync     synchronization signal. Lets the XCOM synchronize with an
//              external signal. Actuates in coordination with the 
//              QRST_SYNC command.
// - i_cfg_tick this input is connected to the AXI_CFG register and 
//              determines the duration of the xcom_clk output signal.
//              xcom_clk will be either in state 1 or 0 for CFG_AXI clock 
//              cycles (i_clk). Possible values ranges from 0 to 7 with 
//              0 equal to two clock cycles and 7 equal to 15 clock 
//              cycles. As an example, if i_cfg_tick = 2 and 
//              i_clk = 500 MHz, then xcom_clk would be ~125 MHz.
// - i_req      transmission requirement signal. Signal indicating a new
//              data transmission starts.  
// - i header   this is the header to be sent to the slaves. 
//              bit 7      is sometimes used to indicate a 
//                         synchronization in other places in the 
//                         XCOM hierarchy
//              bits [6:5] determines the data length to transmit:
//                         00 no data
//                         01 8-bit data
//                         10 16-bit data
//                         11 32-bit data
//              bit 4      not used in this block
//              bits [3:0] not used in this block. Sometimes used 
//                         as mem_id and sometimes used as board 
//                         ID in the XCOM hierarchy 
// - i_data     the data to be transmitted 
//Outputs:
// - o_ready    signal indicating the ip is ready to receive new data to
//              transmit
// - o_data     serial data transmitted. This is the general output of the
//              XCOM block
// - o_clk      serial clock for transmission. This is the general output of
//              the XCOM block
// - o_dbg_state debug port for monitoring the state of the internal FSM
//
// Change history: 09/20/24 - v1 Started by @mdifederico
//                 05/06/25 - Refactored by @lharnaldi
//                          - the sync_n core was removed to sync all signals
//                            in one place (external).
//
///////////////////////////////////////////////////////////////////////////////
module xcom_cmd (
   input  logic          i_clk            ,
   input  logic          i_rstn           ,
   // Command from tProcessor
   input  logic          i_tproc_en       ,
   input  logic [ 5-1:0] i_tproc_op       ,
   input  logic [32-1:0] i_tproc_data [2] ,
   // Command from Python
   input  logic [ 6-1:0] i_ps_ctrl        ,
   input  logic [32-1:0] i_ps_data [2]    ,
   // Command Execution
   output logic          o_req_loc        ,
   input  logic          i_loc_ack        ,
   output logic          cmd_net_req_o    ,
   input  logic          i_net_ack        ,
   output logic [ 8-1:0] o_op             ,
   output logic [32-1:0] o_data           ,
   output logic [ 8-1:0] o_data_cntr    
);

logic          s_valid; 
logic  [4-1:0] s_op; 
logic  [4-1:0] s_addr; 
logic [32-1:0] s_data; 

    //I/O selection
    assign s_valid = i_ps_ctrl[0]      | i_tproc_en;
    assign s_op    = i_ps_ctrl[5:1]    | i_tproc_op;
    assign s_addr  = i_ps_data[0][3:0] | i_tproc_data[0][3:0];
    assign s_data  = i_ps_data[1]      | i_tproc_data[1];

    assign s_ack   = i_loc_ack         | i_net_ack;

// Command Request 
///////////////////////////////////////////////////////////////////////////////
req_ack_cmd u_req_ack_cmd(
  .i_clk      ( i_clk       ),
  .i_rstn     ( i_rstn      ),
  .i_valid    ( s_valid     ),
  .i_op       ( s_op        ),
  .i_addr     ( s_addr      ), 
  .i_data     ( s_data      ), 
  .i_ack      ( s_ack       ),
  .o_req_loc  ( o_req_loc   ),
  .o_req_net  ( o_req_net   ),
  .o_op       ( o_op        ),
  .o_data     ( o_data      ),
  .o_data_cntr( o_data_cntr )
);                        

endmodule
