///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
//
// Fermi National Accelerator Laboratory
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
//                 10/29/26 - o_dbg_data is 32 bits: the cfg tick (33rd bit,
//                            truncated) is out, bits [31:29] are 0.
//
///////////////////////////////////////////////////////////////////////////////
`include "qick_pkg.sv"
module xcom_txrx import qick_pkg::*;
#(
   parameter int NCH        = 2 ,
   parameter int LOOPBACK   = 0,
   parameter int SYNC       = 1
)(
   input  logic             i_clk              ,
   input  logic             i_rstn             ,
   input  logic             i_ps_clk           ,
   input  logic             i_ps_rstn          ,
   input  logic             i_sync             ,
// COMMAND INTERFACE
   input  logic             i_req_loc          ,
   input  logic             i_req_net          ,
   input  logic [ 8-1:0]    i_header           ,
   input  logic [32-1:0]    i_data             ,
   input  logic [ 4-1:0]    i_cmd_cntr         ,
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
   input  logic             i_cfg_clk_pol      ,
   input  logic             i_cfg_clk_pha      ,
   input  logic             i_cfg_auto_pha     ,
   input  logic             i_cfg_loopback     ,
   input  logic             i_cfg_sync_dis     ,
   input  logic [32-1:0]    i_xcom_tx_rx_ddr   ,
   output logic [ 4-1:0]    o_xcom_id          ,
   output logic [32-1:0]    o_xcom_mem[16]     ,
// Xlogic COM
   input  logic [NCH-1:0]   i_xcom_data        ,
   input  logic [NCH-1:0]   i_xcom_clk         ,
   output logic [1:0]       o_xcom_data        ,
   output logic [1:0]       o_xcom_clk         ,
// DEBUG1:0
   output logic [32-1:0]    o_dbg_rx_data      ,
   output logic [32-1:0]    o_dbg_tx_data      ,
   output logic [32-1:0]    o_dbg_status       ,
   output logic [32-1:0]    o_dbg_data
);

// SIGNAL DECLARATION
///////////////////////////////////////////////////////////////////////////////
logic  [5-1:0] s_rx_dbg_state [NCH];
logic  [2-1:0] s_tx_dbg_state;

logic  [6-1:0] s_loc_dbg_status;
logic [10-1:0] s_net_dbg_status;
logic  [9-1:0] rx_cmd_ds;

logic          rx_no_dt, rx_wflg, rx_wreg, rx_wmem ;
logic          rx_wflg_en, rx_wreg_en, rx_wmem_en;
logic          rx_qsync, rx_qctrl, rx_auto_id, rx_rst;

logic          s_data_flag, rst_flg, s_rx_valid, wflg_en;
logic          data_flag, wreg_en_r, wreg_en, wmem_en;
logic [32-1:0] reg_dt_s;
logic [ 4-1:0] mem_addr;
logic [32-1:0] reg1_dt, reg2_dt;
logic [32-1:0] mem_data [16];
logic          s_cmd_exec;

logic          wmem_en_r;
logic [4-1:0]  mem_addr_r;
logic [32-1:0] reg_dt_r;

logic          set_id_flg, wflg_flg, wreg_flg, wmem_flg;
logic          s_loc_sid; //local set ID
logic          s_wflg, s_wreg, s_wmem, s_rst;
logic [ 4-1:0] loc_cmd_op  ;

logic [ 4-1:0] s_rx_chid, s_rx_op ;
logic [32-1:0] s_rx_data ;

logic          tx_auto_id;
logic          tx_qrst_sync;

//TX related signals
logic         s_ack_net;
logic         s_ack_loc;
logic         s_tx_ready;
logic         s_req_net;

//RX related signals
logic [4-1:0] board_id_r;

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
        s_ack_loc = 1'b0;
        s_ack_net = 1'b0;
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
               s_ack_loc  = 1'b1;
               state_n = IDLE;
            end
            ST_NACK:  begin
               s_ack_net  = 1'b1;
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

tx_cmd u_tx_cmd(
   .i_clk            ( i_clk              ),
   .i_rstn           ( i_rstn             ),
   .i_ps_clk         ( i_ps_clk           ),
   .i_ps_rstn        ( i_ps_rstn          ),
   // Inputs
   .i_sync           ( i_sync             ),
   .i_cfg_tick       ( i_cfg_tick         ),
   .i_cfg_clk_pol    ( i_cfg_clk_pol      ),
   .i_cfg_sync_dis   ( i_cfg_sync_dis     ),
   .i_xcom_tx_rx_ddr ( i_xcom_tx_rx_ddr   ),
   .i_req            ( s_req_net          ),
   .i_header         ( i_header           ),
   .i_data           ( i_data             ),
   // Outputs
   .o_ready          ( s_tx_ready         ),
   .o_data           ( o_xcom_data        ),
   .o_clk            ( o_xcom_clk         ),
   .o_dbg_state      ( s_tx_dbg_state     )
);

assign tx_auto_id   = s_req_net & (loc_cmd_op == XCOM_AUTO_ID);

//logic to take into account the XCOM_QRST_SYNC command for board
//synchronization
assign tx_qrst_sync = s_ack_net & (loc_cmd_op == XCOM_QRST_SYNC);

//end Transmission
//

// Reception

// Write ID
///////////////////////////////////////////////////////////////////////////////
logic set_id_en ;
always_ff @ (posedge i_clk) begin
   if ( !i_rstn | s_rst | rx_rst ) begin
      board_id_r  <= 0;
      set_id_en   <= 0;
   end else if ( s_loc_sid )
      board_id_r  <= i_header[3:0];
   else if (tx_auto_id)
      set_id_en <= 1'b1;
   else if (rx_auto_id & set_id_en) begin
      set_id_en   <= 1'b0;
      board_id_r  <= s_rx_chid + 1'b1;
  end
end

// RX COMMAND
///////////////////////////////////////////////////////////////////////////////
rx_cmd #(
   .NCH              (NCH),
   .LOOPBACK         (LOOPBACK)
) u_rx_cmd (
   .i_clk            ( i_clk             ),
   .i_rstn           ( i_rstn            ),
   .i_ps_clk         ( i_ps_clk          ),
   .i_ps_rstn        ( i_ps_rstn         ),
   .i_id             ( board_id_r        ),
   .i_cfg_clk_pha    ( i_cfg_clk_pha     ),
   .i_cfg_auto_pha   ( i_cfg_auto_pha    ),
   .i_cfg_loopback   ( i_cfg_loopback    ),
   .i_xcom_tx_rx_ddr ( i_xcom_tx_rx_ddr  ),
   .i_xcom_data      ( i_xcom_data       ),
   .i_xcom_clk       ( i_xcom_clk        ),
   .o_valid          ( s_rx_valid        ),
   .o_op             ( s_rx_op           ),
   .o_data           ( s_rx_data         ),
   .o_chid           ( s_rx_chid         ),
   .o_dbg_state      ( s_rx_dbg_state    )
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
      wreg_en_r <= 1'b0;
      wmem_en_r <= 1'b0;
      mem_addr_r<= 4'd0;
      reg_dt_r  <= 32'd0;
   end else begin
      wreg_en_r <= wreg_en ;
      if ( wflg_en )
         data_flag <= s_data_flag; // FLAG
      if ( wreg_en )
         unique case ( s_data_flag )
            1'b0 : reg1_dt <= reg_dt_s;      // Reg_dt1
            1'b1 : reg2_dt <= reg_dt_s;      // Reg_dt2
         endcase
      wmem_en_r  <= wmem_en ;
      mem_addr_r <= mem_addr ;
      reg_dt_r   <= reg_dt_s ;
      if ( wmem_en_r )
         mem_data[mem_addr_r]  <= reg_dt_r;
   end
end

///////////////////////////////////////////////////////////////////////////////
// SYNC OPTION
///////////////////////////////////////////////////////////////////////////////

generate
   if (SYNC == 0) begin : gen_sync_no
      // If no SYNC, processor control feature is disabled
      assign o_proc_start  = 1'b0;
      assign o_proc_stop   = 1'b0;
      assign o_time_rst    = 1'b0;
      assign o_time_update = 1'b0;
      assign o_core_start  = 1'b0;
      assign o_core_stop   = 1'b0;
   end
   else if   (SYNC == 1) begin : gen_sync_yes
      xcom_qctrl u_xcom_qctrl (
         .i_clk            ( i_clk          ),
         .i_rstn           ( i_rstn         ),
         .i_sync           ( i_sync         ),
         .i_cfg_sync_dis   ( i_cfg_sync_dis ),
         .i_ctrl_req       ( rx_qctrl       ),
         .i_ctrl_data      ( s_rx_data[2:0] ),
         .i_sync_req       ( rx_qsync       ),
         .o_proc_start     ( o_proc_start   ),
         .o_proc_stop      ( o_proc_stop    ),
         .o_time_rst       ( o_time_rst     ),
         .o_time_update    ( o_time_update  ),
         .o_core_start     ( o_core_start   ),
         .o_core_stop      ( o_core_stop    )
      );
   end
endgenerate

// DEBUG
///////////////////////////////////////////////////////////////////////////////
assign o_dbg_rx_data = s_rx_data;
assign o_dbg_tx_data = i_data;

assign o_dbg_status  = {7'd0, i_cmd_cntr, board_id_r, s_tx_ready, 5'd0, s_rx_dbg_state[0], 2'b00,
                         s_rx_valid, rx_qctrl, s_tx_dbg_state};
// 7 + 4 + 4 + 1 + 5 + 5 + 2 + 1 + 1 + 2 = 32 bits


assign s_loc_dbg_status = {wmem_flg, wreg_flg, wflg_flg, set_id_flg, s_ack_loc, i_req_loc};
assign s_net_dbg_status = {i_header, s_ack_net, i_req_net};
assign rx_cmd_ds  = {rx_wmem, rx_wreg, rx_wflg, rx_no_dt, tx_auto_id, s_rx_op};

// The tick was here too (33 bits, its MSB truncated): it is CFG_REG[3:0], readable directly.
assign o_dbg_data    = {3'd0, s_rx_chid, rx_cmd_ds, s_net_dbg_status, s_loc_dbg_status};
// 3 + 4 + 9 + 10 + 6 = 32 bits


// OUT SIGNALS
///////////////////////////////////////////////////////////////////////////////
always_ff @ (posedge i_clk) begin
   if ( !i_rstn ) o_qp_ready <= 1'b0;
   else o_qp_ready  <= s_tx_ready & ~i_req_loc & ~s_ack_loc;
end
assign o_qp_flag   = data_flag;
assign o_qp_valid  = wreg_en_r;
assign o_qp_data1  = reg1_dt;
assign o_qp_data2  = reg2_dt;
assign o_xcom_id   = board_id_r;
assign o_xcom_mem  = mem_data;

assign o_time_update_data = reg1_dt;

assign o_ack_loc = s_ack_loc ;
assign o_ack_net = s_ack_net;

endmodule
