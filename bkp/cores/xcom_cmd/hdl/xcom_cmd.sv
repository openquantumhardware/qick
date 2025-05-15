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
// - i_clk        clock signal
// - i_rstn       active low reset signal
// - i_core_en    data valid signal coming from the core processor. Indicates
//                a valid data is ready for transmission.
// - i_core_op    opcode from the core. See xcom opcodes in qick_pkg 
// - i_core_data  transmission requirement signal. Signal indicating a new
//                data transmission starts.  
// - i ps_ctrl    port used to send opcode and data valid signal from Python. 
//                bits [5:1] determines the operation to be done. See xcom
//                           opcodes in qick_pkg.
//                bit 0 data valid signal coming from Python. Indicates
//                           a valid data is ready for transmission.
// - i_ps_data    the data to be transmitted, coming from Python 
// - i_ack_loc    acknowledge signal to LOCAL commands. This signal is
//                generated internally in the core xcom_txrx. 
// - i_ack_net    acknowledge signal to NETWORK commands. This signal is
//                generated internally in the core xcom_txrx. 
//
//Outputs:
// - o_req_loc    signal requesting a LOCAL command.
// - o_req_net    signal requesting a NETWORK command.
// - o_op         opcode trasnmitted
// - o_data       data transmittted 
// - o_data_cntr  data counter for debug 
//
// Change history: 09/20/24 - v1 Started by @mdifederico
//                 05/06/25 - Refactored by @lharnaldi
//                          - the sync_n core was removed to sync all signals
//                            in one place (external).
//
///////////////////////////////////////////////////////////////////////////////
module xcom_cmd (
   input  logic                  i_clk            ,
   input  logic                  i_rstn           ,
   // Command from tProcessor
   input  logic                  i_core_en       ,
   input  logic [ 5-1:0]         i_core_op       ,
   input  logic [2-1:0][32-1:0]  i_core_data     ,
   // Command from Python
   input  logic [ 6-1:0]         i_ps_ctrl        ,
   input  logic [2-1:0][32-1:0]  i_ps_data        ,
   // Command Execution
   output logic                  o_req_loc        ,
   input  logic                  i_ack_loc        ,
   output logic                  o_req_net        ,
   input  logic                  i_ack_net        ,
   output logic [ 8-1:0]         o_op             ,
   output logic [32-1:0]         o_data           ,
   output logic [ 4-1:0]         o_data_cntr    
);

logic          s_valid; 
logic  [5-1:0] s_op; 
logic  [4-1:0] s_addr; 
logic [32-1:0] s_data; 

    //I/O selection
    assign s_valid = i_ps_ctrl[0]      | i_core_en;
    assign s_op    = i_ps_ctrl[5:1]    | i_core_op;
    assign s_addr  = i_ps_data[0][3:0] | i_core_data[0][3:0];
    assign s_data  = i_ps_data[1]      | i_core_data[1];

    assign s_ack   = i_ack_loc         | i_ack_net;

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
