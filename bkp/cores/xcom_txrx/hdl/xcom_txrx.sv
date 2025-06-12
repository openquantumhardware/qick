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
// - i_req_loc  local command requirement signal. Signal indicating a new
//              data is available to write locally (in the local board).  
// - i_req_net  transmission requirement signal. Signal indicating a new
//              data transmission starts.  
// - i header   this is the header to be sent to the slaves. 
//              It is used by the tx_cmd instance here. See the 
//              documentation in that core.
// - i_data     the data to be transmitted. It is used by the tx_cmd 
//              instance here and for some LOC commands. 
// - i_cfg_tick this input is connected to the AXI_CFG register and
//              determines the duration of the xcom_clk output signal.
//              It is used by the tx_cmd instance here. See the 
//              documentation in that core.
// - i xcom_data serial data received. This is the general data input of the
//               XCOM block
// - i_xcom_clk  serial clock for reception. This is the general clock input of
//               the XCOM block
//
//Outputs:
// - o_ack_loc  acknowledge signal to LOC commands.
// - o_ack_net  acknowledge signal to NET commands.
//
//QICK interface:
// - o_qp_ready signal indicating the ip is ready to receive new data to
//              transmit
// - o_qp_valid signal indicating the ip has valid data to write into the
//              local board
// - o_qp_flag  signal indicating to write flag into the core
// - o_qp_data1 data1 to core
// - o_qp_data2 data2 to core
//
//TPROC CONTROL INTERFACE
// - o_proc_start       start signal to the tproc
// - o_proc_stop        stop signal to the tproc
// - o_time_rst         reset the time reference in processor
// - o_time_update      update the time in processor
// - o_time_update_data data to update the time in processor
// - o_core_start       start signal to the core in tproc
// - o_core_stop        stop signal to the core in tproc
//
// XCOM CONFIG
// - o xcom_data serial data transmitted. This is the general data output of the
//               XCOM block
// - o_xcom_clk  serial clock for transmission. This is the general clock output of
//               the XCOM block
// - o_xcom_id  board ID. This is a signal to see the board ID into external 
//              LEDs.
// - o_xcom_mem internal 16-word memory port
// - o_dbg_rx_data debug port for monitoring the rx data
// - o_dbg_tx_data debug port for monitoring the tx data
// - o_dbg_state debug port for monitoring the state of the internal FSM
// - o_dbg_data  debug port for monitoring the internal data state
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
logic  [4-1:0] s_cfg_tick;
logic  [5-1:0] s_rx_dbg_state [NCH];
logic  [2-1:0] s_tx_dbg_state;

logic  [6-1:0] s_loc_dbg_status;   
logic [10-1:0] s_net_dbg_status;
logic  [9-1:0] rx_cmd_ds;

logic          rx_no_dt, rx_wflg, rx_wreg, rx_wmem ;
logic          rx_wflg_en, rx_wreg_en, rx_wmem_en;
logic          rx_qsync, rx_qctrl, rx_auto_id, rx_rst; 

logic          s_data_flag;
logic          data_flag, wreg_r ;
logic [32-1:0] reg_dt_s;
logic [ 4-1:0] mem_addr;
logic [32-1:0] reg1_dt, reg2_dt;
logic [32-1:0] mem_data [15];
logic          s_cmd_exec;

logic set_id_flg, wflg_flg, wreg_flg, wmem_flg;
logic s_loc_sid; //local set ID
logic s_wflg, s_wreg, s_wmem, s_rst;
logic [ 4-1:0] loc_cmd_op  ;

logic [ 4-1:0] s_rx_chid, s_rx_op ;
logic [32-1:0] s_rx_data ;

logic         tx_auto_id;
logic         tx_qrst_sync;

//TX related signals
logic         s_nack;
logic         s_lack;
logic         s_tx_ready;
logic         s_req_net;

//RX related signals
logic [4-1:0] board_id_r, board_id_n; 

   typedef enum logic [4-1:0] {IDLE    = 4'b0000, 
                               ST_LOC  = 4'b0001, 
                               ST_NET  = 4'b0010, 
                               ST_SID  = 4'b0011, 
                               ST_WFLG = 4'b0100, 
                               ST_WREG = 4'b0101, 
                               ST_WMEM = 4'b0110, 
                               ST_RST  = 4'b0111, 
                               ST_WNET = 4'b1000, 
                               ST_LACK = 4'b1001,
                               ST_NACK = 4'b1010
    } state_t;
    
    state_t state_r, state_n;
 
    //State register
    always_ff @ (posedge i_clk) begin
        if ( !i_rstn ) state_r <= IDLE;
        else           state_r <= state_n;
    end 
 
    //next state logic
    always_comb begin
        state_n   = state_r; 
        s_loc_sid = 1'b0;
        s_wflg    = 1'b0;
        s_wreg    = 1'b0;
        s_wmem    = 1'b0;
        s_rst     = 1'b0;
        s_lack    = 1'b0;
        s_nack    = 1'b0;
        s_req_net = 1'b0;
        case (state_r)
            IDLE: begin
               if( i_req_loc )  begin
                  state_n = ST_LOC;
               end else if ( i_req_net ) begin
                  state_n = ST_NET;
               end else begin
                  state_n = IDLE;
               end 
            end 
            ST_LOC: begin
               if ( set_id_flg ) begin
                  state_n = ST_SID;
               end else if ( wflg_flg ) begin
                  state_n = ST_WFLG;
               end else if ( wreg_flg ) begin
                  state_n = ST_WREG;
               end else if ( wmem_flg ) begin
                  state_n = ST_WMEM;
               end else if ( rst_flg ) begin
                  state_n = ST_RST;
               end else begin
                  state_n = IDLE;
               end
            end
            ST_SID: begin
               s_loc_sid = 1'b1;
               state_n   = ST_LACK;
            end 
            ST_WFLG: begin
               s_wflg  = 1'b1;
               state_n = ST_LACK;
            end 
            ST_WREG: begin
               s_wreg  = 1'b1;
               state_n = ST_LACK;
            end 
            ST_WMEM: begin
               s_wmem  = 1'b1;
               state_n = ST_LACK;
            end 
            ST_RST: begin
               s_rst   = 1'b1;
               state_n = ST_LACK;
            end 
            ST_NET: begin
               s_req_net = 1'b1;
               if ( !s_tx_ready ) begin
                  state_n = ST_WNET;
               end else begin
                  state_n = ST_NET;
               end
            end
            ST_WNET:  begin 
               if ( s_tx_ready ) begin 
                  state_n = ST_NACK; 
               end else begin
                  state_n = ST_WNET;
               end
            end
            ST_LACK:  begin
               s_lack  = 1'b1;
               state_n = IDLE;  
            end
            ST_NACK:  begin
               s_nack  = 1'b1;
               state_n = IDLE;  
            end
            default: 
                state_n = state_r;
        endcase
    end

// LOC COMMAND
// LOC Decoding
///////////////////////////////////////////////////////////////////////////////
assign loc_cmd_op = i_header[7:4];
assign set_id_flg = (loc_cmd_op == XCOM_SET_ID     );
assign wflg_flg   = (loc_cmd_op == XCOM_WRITE_FLAG );
assign wreg_flg   = (loc_cmd_op == XCOM_WRITE_REG  );
assign wmem_flg   = (loc_cmd_op == XCOM_WRITE_MEM  );
assign rst_flg    = (loc_cmd_op == XCOM_RST        );
assign s_cmd_exec = s_loc_sid | s_wflg | s_wreg | s_wmem | s_rst;

//Transmission
// TRANSMIT NET COMMAND
///////////////////////////////////////////////////////////////////////////////
assign s_cfg_tick = {i_cfg_tick[3-1:0]+1'b1, 1'b0};

tx_cmd u_tx_cmd(
    .i_clk      ( i_clk          ),
    .i_rstn     ( i_rstn         ),
    .i_sync     ( i_sync         ),
    .i_cfg_tick ( s_cfg_tick     ),
    .i_req      ( s_req_net      ),
    .i_header   ( i_header       ),
    .i_data     ( i_data         ),
    .o_ready    ( s_tx_ready     ),
    .o_data     ( o_xcom_data    ),
    .o_clk      ( o_xcom_clk     ),
    .o_dbg_state( s_tx_dbg_state )
);

assign tx_auto_id   = s_req_net & (loc_cmd_op == XCOM_AUTO_ID); 

//logic to take into account the XCOM_QRST_SYNC command for board
//synchronization
assign tx_qrst_sync = s_nack & (loc_cmd_op == XCOM_QRST_SYNC); 

//end Transmission
//
// Reception
// Write ID
///////////////////////////////////////////////////////////////////////////////
always_ff @ (posedge i_clk) begin
   if ( !i_rstn | s_rst | rx_rst ) board_id_r <= '0;
   else                            board_id_r <= board_id_n;
end
//next-state logic
always_comb begin
   if      ( s_loc_sid  ) board_id_n = i_header[4-1:0];
   else if ( rx_auto_id ) board_id_n = s_rx_chid + 1'b1;
   else                   board_id_n = board_id_r;
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
assign rx_wreg    =  !s_rx_op[3] & !rx_no_dt & ~s_rx_op[0]; //001X-010X-011X
assign rx_wmem    =  !s_rx_op[3] & !rx_no_dt & s_rx_op[0]; //000X

assign rx_wflg_en   = s_rx_valid & rx_wflg; 
assign rx_wreg_en   = s_rx_valid & rx_wreg;
assign rx_wmem_en   = s_rx_valid & rx_wmem;

assign rx_auto_id   = s_rx_valid & s_rx_op == XCOM_AUTO_ID;
assign rx_qsync     = (s_rx_valid & s_rx_op == XCOM_QRST_SYNC) | (tx_qrst_sync);
assign rx_qctrl     = s_rx_valid & s_rx_op == XCOM_QCTRL;
assign rx_rst       = s_rx_valid & s_rx_op == XCOM_RST;
//end Reception
//

// EXECUTE COMMANDS
///////////////////////////////////////////////////////////////////////////////
   
// Write Register
///////////////////////////////////////////////////////////////////////////////
assign wflg_en = s_wflg | rx_wflg_en ;
assign wreg_en = s_wreg | rx_wreg_en ;
assign wmem_en = s_wmem | rx_wmem_en ;

assign s_data_flag = s_cmd_exec ? i_header[0]   : s_rx_op[0];
assign reg_dt_s    = s_cmd_exec ? i_data        : s_rx_data;
assign mem_addr    = s_cmd_exec ? i_header[3:0] : s_rx_chid+1'b1 ;

always_ff @ (posedge i_clk) begin
   if (!i_rstn | s_rst | rx_rst ) begin
      data_flag <= 1'b0; 
      reg1_dt   <= '{default:'0} ; 
      reg2_dt   <= '{default:'0} ;
      mem_data  <= '{default:'0} ;
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
         mem_data[mem_addr]  <= reg_dt_s;
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
assign s_loc_dbg_status = {wmem_flg, wreg_flg, wflg_flg, set_id_flg, s_lack, i_req_loc};
assign s_net_dbg_status = {i_header, s_nack, i_req_net};
assign rx_cmd_ds  = {rx_wmem, rx_wreg, rx_wflg, rx_no_dt, tx_auto_id, s_rx_op};

assign o_dbg_rx_data = s_rx_data;
assign o_dbg_tx_data = i_data;

assign o_dbg_status  = {board_id_r, s_tx_ready, 5'b0_0000, s_rx_dbg_state[0], 4'b0000, s_tx_dbg_state};//FIXME: here was cmd_st_ds. Also we are seeing only state[0] here
assign o_dbg_data    = {s_cfg_tick, s_rx_chid, rx_cmd_ds, s_net_dbg_status, s_loc_dbg_status};

// OUT SIGNALS
///////////////////////////////////////////////////////////////////////////////
assign o_qp_ready  = s_tx_ready & ~i_req_loc & ~s_lack;
assign o_qp_flag   = data_flag;
assign o_qp_valid  = wreg_r;
assign o_qp_data1  = reg1_dt;
assign o_qp_data2  = reg2_dt;
assign o_xcom_id   = board_id_r;
assign o_xcom_mem  = mem_data;

assign o_time_update_data = reg1_dt;

assign o_ack_loc = s_lack ;
assign o_ack_net = s_nack;

endmodule
