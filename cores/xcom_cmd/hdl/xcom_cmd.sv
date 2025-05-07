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
module qick_xcom_cmd (
   input  wire             i_clk    ,
   input  wire             ps_rst_ni   ,
   input  wire             i_clk     ,
   input  wire             c_rst_ni    ,
   input  wire             x_clk_i     ,
   input  wire             x_rst_ni    ,
   // Command from tProcessor
   input  wire             i_tproc_en      ,
   input  wire [ 4:0]      i_tproc_op      ,
   input  wire [31:0]      i_tproc_data [2]  ,
   // Command from Python
   input  wire [ 5:0]      i_ps_ctrl    ,
   input  wire [31:0]      i_ps_data [2]  ,
   // Command Execution
   output wire             o_req_loc ,
   input  wire             i_loc_ack ,
   output wire             cmd_net_req_o ,
   input  wire             i_net_ack ,
   output wire [ 7:0]      cmd_op_o      ,
   output wire [31:0]      cmd_dt_o      ,
   output wire [ 7:0]      cmd_cnt_do    );

wire          p_loc_req, c_loc_req; 
wire          p_loc_req_s;
wire          p_net_req, c_net_req; 
wire [ 7:0]   p_op , c_op ;  
wire [31:0]   p_dt , c_dt ;
wire [ 3:0]   p_cnt, c_cnt;

// PS Command Request 
///////////////////////////////////////////////////////////////////////////////
req_ack_cmd PS_CMD_SYNC (
   .src_clk_i   ( i_clk            ),
   .src_rst_ni  ( ps_rst_ni        ),
   .src_vld_i   ( i_ps_ctrl[0]     ),
   .src_op_i    ( i_ps_ctrl[5:1]   ),
   .src_dst_i   ( i_ps_data[0][3:0] ),
   .src_dt_i    ( i_ps_data[1]      ),
   .loc_req_o   ( p_loc_req         ),
   .net_req_o   ( p_net_req         ),
   .async_ack_i ( cmd_req           ),
   .sync_ack_i  ( 0                 ),
   .cmd_op_o    ( p_op              ),
   .cmd_dt_o    ( p_dt              ),
   .cmd_cnt_do  ( p_cnt             ));

req_ack_cmd 
u_req_ack_cmd
(
  .i_clk      ( i_clk            ),
  .i_rstn     ( ps_rst_ni        ),
  .i_valid    ( i_ps_ctrl[0]     ),
  .i_op       ( i_ps_ctrl[5:1]   ),
  .i_addr     ( i_ps_data[0][3:0]), 
  .i_data     ( i_ps_data[1]     ), 
  .i_ack      (        ),
  .o_req_loc  ( p_loc_req        ),
  .o_req_net  ( p_net_req        ),
  .o_op       ( p_op             ),
  .o_data     ( p_dt             ),
  .o_data_cntr( p_cnt            )
);                        
                   


// C_CLK Command Request
///////////////////////////////////////////////////////////////////////////////
req_ack_cmd C_CMD_SYNC (
   .src_clk_i   ( i_clk        ),
   .src_rst_ni  ( c_rst_ni       ),
   .src_vld_i   ( i_tproc_en         ),
   .src_op_i    ( i_tproc_op         ),
   .src_dst_i   ( i_tproc_data[0][3:0] ),
   .src_dt_i    ( i_tproc_data[1]      ),
   .loc_req_o   ( c_loc_req      ),
   .net_req_o   ( c_net_req      ),
   .async_ack_i ( 0 ),
   .sync_ack_i  ( cmd_req        ),
   .cmd_op_o    ( c_op           ),
   .cmd_dt_o    ( c_dt           ),
   .cmd_cnt_do  ( c_cnt          ));


// COMMAND OPERATON
reg cmd_net_req, cmd_loc_req;


sync_reg #(.DW(1)) sync_loc_req (
   .dt_i      ( p_loc_req   ),
   .clk_i     ( i_clk   ),
   .rst_ni    ( c_rst_ni  ),
   .dt_o      ( p_loc_req_s ));
   
assign net_req = c_net_req | p_net_req;
assign loc_req = c_loc_req | p_loc_req_s;
assign c_req   = c_loc_req | c_net_req;


sync_reg #(.DW(1)) sync_net_req (
   .dt_i      ( net_req   ),
   .clk_i     ( x_clk_i   ),
   .rst_ni    ( x_rst_ni  ),
   .dt_o      ( net_req_s ));



wire [ 7:0] cmd_op_s;
wire [31:0] cmd_dt_s;
assign cmd_op_s = c_req ? c_op : p_op ;
assign cmd_dt_s = c_req ? c_dt : p_dt ;

// Local Command
always_ff @(posedge i_clk) 
   if      ( !c_rst_ni )                 cmd_loc_req <= 1'b0;
   else if (  loc_req & !i_loc_ack ) cmd_loc_req <= 1'b1;
   else if ( !loc_req &  i_loc_ack ) cmd_loc_req <= 1'b0;

// Net Command
always_ff @(posedge x_clk_i) 
   if      ( !x_rst_ni )                 cmd_net_req <= 1'b0;
   else if ( net_req_s & !i_net_ack) cmd_net_req <= 1'b1;
   else if ( !net_req_s & i_net_ack) cmd_net_req <= 1'b0;


assign cmd_req = cmd_loc_req | cmd_net_req ;

// DEBUG
///////////////////////////////////////////////////////////////////////////////
assign cmd_cnt_do ={ c_cnt, p_cnt };  

// OUTPUTS
///////////////////////////////////////////////////////////////////////////////
assign cmd_net_req_o = cmd_net_req;
assign o_req_loc = cmd_loc_req;
assign cmd_op_o   = cmd_op_s;
assign cmd_dt_o   = cmd_dt_s;

endmodule
