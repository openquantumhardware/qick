///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
//
// Fermi Fordward Alliance LLC
//
// Module: xcom_txrx.sv
// Project: QICK 
// Description: 
// Transmitter and Receiver interface wrapper for the XCOM block. 
// 
//Inputs:
// - i_clk      clock signal
// - i_rstn     active low reset signal
// - i_sync     synchronization signal. Lets the XCOM synchronize with an
//              external signal. Actuates in coordination with the 
//              XCOM_QRST_SYNC command.
// - i_cfg_tick this input is connected to the AXI_CFG register and 
//              determines the duration of the xcom_clk output signal.
//              xcom_clk will be either in state 1 or 0 for CFG_AXI clock 
//              cycles (i_clk). Possible values ranges from 0 to 7 with 
//              0 equal to two clock cycles and 7 equal to 15 clock 
//              cycles. As an example, if i_cfg_tick = 2 and 
//              i_clk = 500 MHz, then xcom_clk would be ~125 MHz.
// - i_req_net      transmission requirement signal. Signal indicating a new
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
//QICK interface:
// - o_qp_ready signal indicating the ip is ready to receive new data to
//              transmit
// - o_qp_valid signal indicating the ip has valid data to write into the
//              local board
// - o_qp_flag  signal indicating to write flag into the core
// - o_qp_data1 data1 to core
// - o_qp_data2 data2 to core
// - o_clk      serial clock for transmission. This is the general output of
//              the XCOM block
// - o_dbg_state debug port for monitoring the state of the internal FSM
//
// Change history: 09/20/24 - v1 Started by @mdifederico
//                 05/13/25 - Refactored by @lharnaldi
//                          - the sync_n core was removed to sync all signals
//                            in one place (external).
//
///////////////////////////////////////////////////////////////////////////////
module xcom_txrx import qick_pkg::*;
#(
   parameter NCH  = 2 ,
   parameter SYNC = 1 
)(
   input  logic             i_clk              ,
   input  logic             i_rstn             ,
   input  logic             i_sync             ,
// COMMAND INTERFACE
   input  logic             i_req_loc          ,
   input  logic             i_req_net          ,
   input  logic [ 8-1:0]    i_header           ,
   input  logic [32-1:0]    i_data             ,
   output logic             o_ack_loc          ,
   output logic             o_ack_net          ,
// QICK INTERFACE
   output logic             o_qp_ready         ,
   output logic             o_qp_valid         ,
   output logic             o_qp_flag          ,
   output logic [32-1:0]    o_qp_data1         ,
   output logic [32-1:0]    o_qp_data2         ,
// QICK PROCESSOR CONTROL
   output logic             o_proc_start       ,
   output logic             o_proc_stop        ,
   output logic             o_time_rst         ,
   output logic             o_time_update      ,
   output logic [32-1:0]    o_time_update_data ,
   output logic             o_core_start       ,
   output logic             o_core_stop        ,
// XCOM CFG
   input  logic [4-1:0]     i_cfg_tick         ,
   output logic [ 4-1:0]    o_xcom_id          ,
   output logic [32-1:0]    o_xcom_mem[15]     ,
// Xlogic COM
   input  logic [NCH-1:0]   i_xcom_data        ,
   input  logic [NCH-1:0]   i_xcom_clk         ,
   output logic             o_xcom_data        ,
   output logic             o_xcom_clk         ,
// DEBUG
   output logic [32-1:0]    o_dbg_rx_data      ,
   output logic [32-1:0]    o_dbg_tx_data      ,
   output logic [21-1:0]    o_dbg_status       ,
   output logic [32-1:0]    o_dbg_data 
);

// SIGNAL DECLARATION
///////////////////////////////////////////////////////////////////////////////
logic  [5-1:0] s_rx_dbg_state [NCH];
logic  [2-1:0] s_tx_dbg_state;

logic  [6-1:0] loc_cmd_ds;   
logic [10-1:0] net_cmd_ds;
logic  [9-1:0] rx_cmd_ds;

logic          rx_no_dt, rx_wflg, rx_wreg, rx_wmem ;
logic          rx_wflg_en, rx_wreg_en, rx_wmem_en;
logic          rx_qsync, rx_qctrl, rx_auto_id; 

logic          s_data_flag;
logic          data_flag, wreg_r ;
logic [32-1:0] reg_dt_s;
logic [ 4-1:0] mem_addr;
logic [32-1:0] reg1_dt, reg2_dt;
logic [32-1:0] mem_dt [15];

logic loc_set_id, loc_wflg, loc_wreg, loc_wmem;
logic loc_id_en, loc_wflg_en, loc_wreg_en, loc_wmem_en, cmd_execute;
logic [ 4-1:0] loc_cmd_op  ;

logic [ 4-1:0] s_rx_chid, s_rx_op ;
logic [32-1:0] s_rx_data ;

logic [NCH-1:0][5-1:0] s_rx_dbg;

//TX related signals
logic s_ack_net;
logic s_ack_loc;
logic          s_tx_ready;

//RX related signals
logic [4-1:0] board_id_r; 
logic         set_id_en ;

//Transmission
// TRANSMIT NET COMMAND
///////////////////////////////////////////////////////////////////////////////
always_ff @(posedge i_clk) begin
   if      ( !i_rstn )                            s_ack_net <= 1'b0;
   else if ( i_req_net & !s_ack_net & s_tx_ready) s_ack_net <= 1'b1;
   else if ( !i_req_net & s_ack_net & s_tx_ready) s_ack_net <= 1'b0;
end

tx_cmd u_tx_cmd(
    .i_clk      ( i_clk          ),
    .i_rstn     ( i_rstn         ),
    .i_sync     ( i_sync         ),
    .i_cfg_tick ( i_cfg_tick     ),
    .i_req      ( i_req_net      ),
    .i_header   ( i_header       ),
    .i_data     ( i_data         ),
    .o_ready    ( s_tx_ready     ),
    .o_data     ( o_xcom_data    ),
    .o_clk      ( o_xcom_clk     ),
    .o_dbg_state( s_tx_dbg_state )
);

assign tx_auto_id = i_req_net & (i_header[7:4] == XCOM_AUTO_ID); 

//end Transmission
//
// Reception
// Write ID
///////////////////////////////////////////////////////////////////////////////
always_ff @ (posedge i_clk) begin
   if ( !i_rstn ) begin  
      board_id_r  <= 0;
      set_id_en   <= 0;
   end else if ( loc_id_en )
      board_id_r  <= i_header[3:0];
   else if (tx_auto_id)
      set_id_en <= 1'b1;
   else if ( rx_auto_id & set_id_en) begin
      set_id_en   <= 1'b0;
      board_id_r  <= s_rx_chid+1'b1;
  end
end

// RX COMMAND
///////////////////////////////////////////////////////////////////////////////
rx_cmd#(.NCH(NCH)) u_rx_cmd(
  .i_clk           ( i_clk             ),
  .i_rstn          ( i_rstn            ),
  .i_id            ( board_id_r        ),
  .i_xcom_data     ( i_xcom_data       ),
  .i_xcom_clk      ( i_xcom_clk        ),
  .o_valid         ( s_rx_valid        ),
  .o_op            ( s_rx_op           ),
  .o_data          ( s_rx_data         ),
  .o_chid          ( s_rx_chid         ),
  .o_dbg_state     ( s_rx_dbg_state    )
);

// RX Decoding
///////////////////////////////////////////////////////////////////////////////
assign rx_no_dt   = ~|s_rx_op[2:1];
assign rx_wflg    =  !s_rx_op[3] & rx_no_dt ; //000X
assign rx_wreg    =  !s_rx_op[3] & !rx_no_dt; //001X-010X-011X
assign rx_wmem    =   s_rx_op[3] & !rx_no_dt & ~s_rx_op[0]; //000X

assign rx_wflg_en   = s_rx_valid & rx_wflg; 
assign rx_wreg_en   = s_rx_valid & rx_wreg;
assign rx_wmem_en   = s_rx_valid & rx_wmem;

assign rx_auto_id   = s_rx_valid & s_rx_op == XCOM_AUTO_ID;//4'b1001 ;

assign rx_qsync     = s_rx_valid & s_rx_op == XCOM_QRST_SYNC;//4'b1000 ;
assign rx_qctrl     = s_rx_valid & s_rx_op == XCOM_QCTRL;//4'b1011 ;
         
//end Reception
//
// LOC COMMAND
///////////////////////////////////////////////////////////////////////////////
always_ff @(posedge i_clk) begin
   if      ( !i_rstn )               s_ack_loc <= 1'b0;
   else if ( i_req_loc & !s_ack_loc) s_ack_loc <= 1'b1;
   else if ( !i_req_loc & s_ack_loc) s_ack_loc <= 1'b0;
end

// LOC Decoding
///////////////////////////////////////////////////////////////////////////////
assign loc_cmd_op  = i_header[7:4];
assign loc_set_id  = loc_cmd_op == XCOM_SET_ID;//4'b0000 ; 
assign loc_wflg    = loc_cmd_op == XCOM_WRITE_FLAG;//4'b0001 ;
assign loc_wreg    = loc_cmd_op == XCOM_WRITE_REG;//4'b0010 ;
assign loc_wmem    = loc_cmd_op == XCOM_WRITE_MEM;//4'b0011 ;

assign cmd_execute = i_req_loc & !s_ack_loc;

assign loc_id_en   = cmd_execute & loc_set_id;
assign loc_wflg_en = cmd_execute & loc_wflg; 
assign loc_wreg_en = cmd_execute & loc_wreg;
assign loc_wmem_en = cmd_execute & loc_wmem;


// EXECUTE COMMANDS
///////////////////////////////////////////////////////////////////////////////
   
// Write Register
///////////////////////////////////////////////////////////////////////////////
assign wflg_en = loc_wflg_en | rx_wflg_en ;
assign wreg_en = loc_wreg_en | rx_wreg_en ;
assign wmem_en = loc_wmem_en | rx_wmem_en ;

assign s_data_flag = cmd_execute ? i_header[0]   : s_rx_op[0];
assign reg_dt_s    = cmd_execute ? i_data        : s_rx_data;
assign mem_addr    = cmd_execute ? i_header[3:0] : s_rx_chid+1'b1 ;

always_ff @ (posedge i_clk) begin
   if (!i_rstn) begin
      data_flag <= 1'b0; 
      reg1_dt   <= '{default:'0} ; 
      reg2_dt   <= '{default:'0} ;
      mem_dt    <= '{default:'0} ;
      wreg_r    <= 1'b0; 
   end else begin 
      wreg_r    <= wreg_en ;
      if ( wflg_en )
         data_flag <= s_data_flag; // FLAG
      else if ( wreg_en )
         case ( s_data_flag )
            1'b0 : reg1_dt <= reg_dt_s;      // Reg_dt1
            1'b1 : reg2_dt <= reg_dt_s;      // Reg_dt2
         endcase
      else if ( wmem_en )
         mem_dt[mem_addr]  <= reg_dt_s;
   end
end

///////////////////////////////////////////////////////////////////////////////
// SYNC OPTION
///////////////////////////////////////////////////////////////////////////////

generate
   if (SYNC == 0) begin : SYNC_NO
      
   end else if   (SYNC == 1) begin : SYNC_YES
      xcom_qctrl u_xcom_qctrl(
         .i_clk        ( i_clk          ),
         .i_rstn       ( i_rstn         ),
         .i_sync       ( i_sync         ),
         .i_ctrl_req   ( rx_qctrl       ),
         .i_ctrl_data  ( s_rx_data[2:0] ),
         .i_sync_req   ( rx_qsync       ),
         .o_proc_start ( o_proc_start   ),
         .o_proc_stop  ( o_proc_stop    ),
         .o_time_rst   ( o_time_rst     ),
         .o_time_update( o_time_update  ),
         .o_core_start ( o_core_start   ),
         .o_core_stop  ( o_core_stop    )
      );
   end
endgenerate

// DEBUG
///////////////////////////////////////////////////////////////////////////////
assign loc_cmd_ds = {loc_wmem, loc_wreg, loc_wflg, loc_set_id, s_ack_loc, i_req_loc};
assign net_cmd_ds = {i_header, s_ack_net, i_req_net};
assign rx_cmd_ds  = {rx_wmem, rx_wreg, rx_wflg, rx_no_dt, tx_auto_id, s_rx_op};

assign o_dbg_rx_data = s_rx_data;
assign o_dbg_tx_data = i_data;

assign o_dbg_status  = {board_id_r, s_tx_ready, s_rx_dbg_state[0], 4'b0000, s_tx_dbg_state};//FIXME: here was cmd_st_ds. Also we are seeing only state[0] here
assign o_dbg_data    = {i_cfg_tick, s_rx_chid, rx_cmd_ds, net_cmd_ds, loc_cmd_ds};

// OUT SIGNALS
///////////////////////////////////////////////////////////////////////////////
assign o_qp_ready  = s_tx_ready & ~i_req_loc & ~s_ack_loc;
assign o_qp_flag   = data_flag;
assign o_qp_valid  = wreg_r;
assign o_qp_data1  = reg1_dt;
assign o_qp_data2  = reg2_dt;
assign o_xcom_id   = board_id_r;
assign o_xcom_mem  = mem_dt;

assign o_time_update_data = reg1_dt;

assign o_ack_loc = s_ack_loc ;
assign o_ack_net = s_ack_net;

endmodule
