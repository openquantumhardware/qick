///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
//
// Fermi Fordward Alliance LLC
//
// Module: xcom_txrx.sv
// Project: QICK 
// Description: 
// Transmitter interface wrapper for the XCOM block. Synchronizes the
// xcom_link_tx block through the external i_sync signal.
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
module xcom_txrx # (
   parameter CH   = 2 ,
   parameter SYNC = 1 
)(
// CLK & RST & PulseSync
   input  logic             c_clk_i       ,
   input  logic             c_rst_ni      ,
   input  logic             t_clk_i       ,
   input  logic             t_rst_ni      ,
   input  logic             x_clk_i       ,
   input  logic             x_rst_ni      ,
   input  logic             pulse_sync_i  ,
// COMMAND INTERFACE
   input  logic             cmd_loc_req_i ,
   output logic             cmd_loc_ack_o ,
   input  logic             cmd_net_req_i ,
   output logic             cmd_net_ack_o ,
   input  logic  [ 7:0]     cmd_op_i      ,
   input  logic  [31:0]     cmd_dt_i      ,
// QICK INTERFACE
   output logic              qp_rdy_o      ,
   output logic              qp_vld_o      ,
   output logic              qp_flag_o     ,
   output logic   [31:0]     qp_dt1_o      ,
   output logic   [31:0]     qp_dt2_o      ,
// QICK PROCESSOR CONTROL
   output logic             p_start_o     ,
   output logic             p_stop_o      ,
   output logic             t_rst_o       ,
   output logic             t_updt_o      ,
   output logic [31:0]      t_updt_dt_o      ,
   output logic             c_start_o     ,
   output logic             c_stop_o      ,
// XCOM CFG
   input  logic  [3:0]      xcom_cfg_i    ,
   output logic   [ 3:0]     xcom_id_o     ,
   output logic   [31:0]    xcom_mem_o[15],
// Xlogic COM
   input  logic  [CH-1:0]   rx_dt_i       ,
   input  logic  [CH-1:0]   rx_ck_i       ,
   output logic             tx_dt_o       ,
   output logic             tx_ck_o       ,
// DEBUG
   output logic [31:0]      xcom_rx_do    ,
   output logic [31:0]      xcom_tx_do    ,
   output logic [20:0]      xcom_status_do,
   output logic [31:0]      xcom_debug_do 
);

// SIGNAL DECLARATION
///////////////////////////////////////////////////////////////////////////////
logic  [ 3:0] board_id_r; // BOARD ID

// TRANSMIT NET COMMAND
///////////////////////////////////////////////////////////////////////////////
logic cmd_net_ack;
always_ff @(posedge x_clk_i) begin
   if      ( !x_rst_ni)                    cmd_net_ack <= 1'b0;
   else if ( cmd_net_req_i & !cmd_net_ack & tx_rdy) cmd_net_ack <= 1'b1;
   else if ( !cmd_net_req_i & cmd_net_ack & tx_rdy) cmd_net_ack <= 1'b0;
end


tx_cmd # (.CH(CH)) TX_CMD (
   .x_clk_i     ( x_clk_i       ),
   .x_rst_ni    ( x_rst_ni      ),
   .pulse_sync_i( pulse_sync_i  ),
   .tick_cfg_i  ( xcom_cfg_i    ),
   .tx_req_i    ( cmd_net_req_i ),
   .tx_rdy_o    ( tx_rdy        ),
   .tx_hd_i     ( cmd_op_i      ),
   .tx_dt_i     ( cmd_dt_i      ),
   .tx_dt_o     ( tx_dt_o       ),
   .tx_ck_o     ( tx_ck_o       ),
   .tx_st_do    ( tx_st_ds      ));

//FIXME: aca se esta usando el rango 7:4 de cmd_op. Los bits 6:5 se usan para
//determinar la longitud de los datos a transmitir. Hay que revisar si eso no
//entra en conflicto con el uso que se le da aca.n
assign tx_auto_id = cmd_net_req_i & cmd_op_i[7:4] == 4'b1001;

// RX COMMAND
///////////////////////////////////////////////////////////////////////////////
logic [ 3:0] rx_cmd_id, rx_cmd_op ;
logic [31:0] rx_cmd_dt ;

rx_cmd # (.CH(CH)) RX_CMD ( 
   .c_clk_i      ( c_clk_i     ),
   .c_rst_ni     ( c_rst_ni    ),
   .x_clk_i      ( x_clk_i     ),
   .x_rst_ni     ( x_rst_ni    ),
   .port_id_i    ( board_id_r  ),
   .rx_dt_i      ( rx_dt_i     ),
   .rx_ck_i      ( rx_ck_i     ),
   .cmd_vld_o    ( rx_cmd_vld  ),
   .cmd_op_o     ( rx_cmd_op   ),
   .cmd_dt_o     ( rx_cmd_dt   ),
   .cmd_id_o     ( rx_cmd_id   ),
   .cmd_st_do    ( cmd_st_ds   ),
   .rx_st_do     ( rx_st_ds    )
);

// RX Decoding
///////////////////////////////////////////////////////////////////////////////
logic rx_no_dt, rx_wflg, rx_wreg, rx_wmem ;
logic rx_wflg_en, rx_wreg_en, rx_wmem_en;
logic rx_qsync, rx_qctrl, rx_auto_id; 

assign rx_no_dt   = ~|rx_cmd_op[2:1];
assign rx_wflg    =  !rx_cmd_op[3] & rx_no_dt ; //000X
assign rx_wreg    =  !rx_cmd_op[3] & !rx_no_dt; //001X-010X-011X
assign rx_wmem    =   rx_cmd_op[3] & !rx_no_dt & ~rx_cmd_op[0]; //000X

assign rx_wflg_en   = rx_cmd_vld & rx_wflg; 
assign rx_wreg_en   = rx_cmd_vld & rx_wreg;
assign rx_wmem_en   = rx_cmd_vld & rx_wmem;

assign rx_auto_id   = rx_cmd_vld & rx_cmd_op == 4'b1001 ;

assign rx_qsync     = rx_cmd_vld & rx_cmd_op == 4'b1000 ;
assign rx_qctrl     = rx_cmd_vld & rx_cmd_op == 4'b1011 ;
         
// LOC COMMAND
///////////////////////////////////////////////////////////////////////////////
logic cmd_loc_ack;
always_ff @(posedge c_clk_i) begin
   if      ( !c_rst_ni)                    cmd_loc_ack <= 1'b0;
   else if ( cmd_loc_req_i & !cmd_loc_ack) cmd_loc_ack <= 1'b1;
   else if ( !cmd_loc_req_i & cmd_loc_ack) cmd_loc_ack <= 1'b0;
end

// LOC Decoding
///////////////////////////////////////////////////////////////////////////////
logic loc_set_id, loc_wflg, loc_wreg, loc_wmem;
logic loc_id_en, loc_wflg_en, loc_wreg_en, loc_wmem_en, cmd_execute;
logic [ 3:0] loc_cmd_op  ;

assign loc_cmd_op  = cmd_op_i[7:4];
assign loc_set_id  = loc_cmd_op == 4'b0000 ; 
assign loc_wflg    = loc_cmd_op == 4'b0001 ;
assign loc_wreg    = loc_cmd_op == 4'b0010 ;
assign loc_wmem    = loc_cmd_op == 4'b0011 ;

assign cmd_execute = cmd_loc_req_i & !cmd_loc_ack;

assign loc_id_en   = cmd_execute & loc_set_id;
assign loc_wflg_en = cmd_execute & loc_wflg; 
assign loc_wreg_en = cmd_execute & loc_wreg;
assign loc_wmem_en = cmd_execute & loc_wmem;


// EXECUTE COMMANDS
///////////////////////////////////////////////////////////////////////////////
   
// Write Register
///////////////////////////////////////////////////////////////////////////////
logic        flag_dt_s;
logic [31:0] reg_dt_s;
logic [ 3:0] mem_addr;
logic         flag_dt, wreg_r ;
logic  [31:0] reg1_dt, reg2_dt;
logic  [31:0] mem_dt [15];

assign wflg_en = loc_wflg_en | rx_wflg_en ;
assign wreg_en = loc_wreg_en | rx_wreg_en ;
assign wmem_en = loc_wmem_en | rx_wmem_en ;

assign flag_dt_s = cmd_execute ? cmd_op_i[0]   : rx_cmd_op[0];
assign reg_dt_s  = cmd_execute ? cmd_dt_i      : rx_cmd_dt;
assign mem_addr  = cmd_execute ? cmd_op_i[3:0] : rx_cmd_id+1'b1 ;

always_ff @ (posedge c_clk_i, negedge c_rst_ni) begin
   if (!c_rst_ni) begin
      flag_dt    <= 1'b0; 
      reg1_dt    <= '{default:'0} ; 
      reg2_dt    <= '{default:'0} ;
      mem_dt     <= '{default:'0} ;
      wreg_r  <= 1'b0; 
   end else begin 
      wreg_r <= wreg_en ;
      if ( wflg_en )
         flag_dt <= flag_dt_s; // FLAG
      else if ( wreg_en )
         case ( flag_dt_s )
            1'b0 : reg1_dt <= reg_dt_s;      // Reg_dt1
            1'b1 : reg2_dt <= reg_dt_s;      // Reg_dt2
         endcase
      else if ( wmem_en )
         mem_dt[mem_addr]  <= reg_dt_s;
   end
end

// Write ID
///////////////////////////////////////////////////////////////////////////////
logic set_id_en ;

always_ff @ (posedge c_clk_i) begin
   if      ( !c_rst_ni ) begin  
      board_id_r  <= 0;
      set_id_en   <= 0;
   end else if ( loc_id_en )
      board_id_r  <= cmd_op_i[3:0];
   else if (tx_auto_id)
      set_id_en <= 1'b1;
   else if ( rx_auto_id & set_id_en) begin
      set_id_en   <= 1'b0;
      board_id_r  <= rx_cmd_id+1'b1;
  end
end

///////////////////////////////////////////////////////////////////////////////
// SYNC OPTION
///////////////////////////////////////////////////////////////////////////////

generate
   if (SYNC == 0) begin : SYNC_NO
      
   end else if   (SYNC == 1) begin : SYNC_YES
      xcom_qctrl QCTRL (
         .c_clk_i      ( c_clk_i      ),
         .c_rst_ni     ( c_rst_ni     ),
         .t_clk_i      ( t_clk_i      ),
         .t_rst_ni     ( t_rst_ni     ),
         .pulse_sync_i ( pulse_sync_i ),
         .qctrl_req_i  ( rx_qctrl     ),
         .qctrl_dt_i   ( rx_cmd_dt[2:0]),
         .qsync_req_i  ( rx_qsync     ),
         .p_start_o    ( p_start_o    ),
         .p_stop_o     ( p_stop_o     ),
         .t_rst_o      ( t_rst_o      ),
         .t_updt_o     ( t_updt_o     ),
         .c_start_o    ( c_start_o    ),
         .c_stop_o     ( c_stop_o     )
      );
   end
endgenerate

// DEBUG
///////////////////////////////////////////////////////////////////////////////
logic  [3:0]  cmd_st_ds;   
logic  [9:0]  rx_st_ds;
logic  [1:0]  tx_st_ds;

logic  [5:0]  loc_cmd_ds;   
logic  [9:0]  net_cmd_ds;
logic  [8:0]  rx_cmd_ds;

assign loc_cmd_ds = {loc_wmem, loc_wreg, loc_wflg, loc_set_id, cmd_loc_ack, cmd_loc_req_i};
assign net_cmd_ds = {cmd_op_i, cmd_net_ack, cmd_net_req_i};
assign rx_cmd_ds  = {rx_wmem, rx_wreg, rx_wflg, rx_no_dt, tx_auto_id, rx_cmd_op};

assign xcom_rx_do    = rx_cmd_dt;
assign xcom_tx_do    = cmd_dt_i;
assign xcom_status_do = {board_id_r, tx_rdy, rx_st_ds, cmd_st_ds, tx_st_ds};
assign xcom_debug_do  = {xcom_cfg_i, rx_cmd_id, rx_cmd_ds, net_cmd_ds, loc_cmd_ds};

// OUT SIGNALS
///////////////////////////////////////////////////////////////////////////////
assign qp_rdy_o    = tx_rdy & ~cmd_loc_req_i & ~cmd_loc_ack;
assign qp_flag_o   = flag_dt;
assign qp_vld_o    = wreg_r;
assign qp_dt1_o    = reg1_dt;
assign qp_dt2_o    = reg2_dt;
assign xcom_id_o   = board_id_r;
assign xcom_mem_o  = mem_dt;

assign t_updt_dt_o = reg1_dt;

assign cmd_loc_ack_o = cmd_loc_ack ;
assign cmd_net_ack_o = cmd_net_ack;

endmodule
