///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
//
// Fermi Fordward Alliance LLC
//
// Module: rx_cmd.sv
// Project: QICK 
// Description: 
// Receiver interface wrapper for the XCOM block. Synchronizes the
// xcom_link_rx block through the external i_sync signal.
// 
//Parameters:
// - NCH        number of channels
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
// Change history: 09/20/24 - v1.0.0 Started by @mdifederico
//                 05/07/25 - v1.1.0 Refactored by @lharnaldi
//                                   - the sync_n core was removed to sync 
//                                   all signals in one place (external).
//
///////////////////////////////////////////////////////////////////////////////
module rx_cmd # (
   parameter NCH = 2
)( 
   input  logic           c_clk_i     ,
   input  logic           c_rst_ni    ,
   input  logic           i_clk     ,
   input  logic           i_rstn    ,
// XCOM CFG
   input  logic   [4-1:0] i_id   ,
// XCOM CNX
   input  logic [NCH-1:0] i_xcom_data     ,
   input  logic [NCH-1:0] i_xcom_clk     ,
// Command Processing
   output logic           cmd_vld_o ,
   output logic  [ 4-1:0] cmd_op_o  ,
   output logic  [32-1:0] cmd_dt_o  ,
   output logic  [ 4-1:0] cmd_id_o  ,
// XCOM RX DEBUG
   output logic   [4-1:0] cmd_st_do ,   
   output logic  [10-1:0] rx_st_do      
   );

logic [NCH-1:0] rx_req_s      ;
logic [NCH-1:0] rx_ack_s      ;
logic           rx_cmd_valid  ;
logic  [ 4-1:0] rx_cmd_s  [NCH];
logic  [32-1:0] rx_data_s [NCH];
logic  [ 4-1:0] rx_cmd_ind    ;

logic           rx_cmd_req, rx_cmd_id_wr;
logic  [4-1:0]| rx_cmd_id ;
logic           rx_cmd_ack;

logic           c_cmd_req ;
logic           c_cmd_ack ;
logic           c_cmd_vld;

logic [5-1:0]   rx_st_ds [NCH];
// LINK RECEIVERS 
/////////////////////////////////////////////////////////////////////////////
genvar k;
generate
   for (k=0; k < NCH ; k=k+1) begin: RX
       xcom_link_rx u_xcom_link_rx(
           .i_clk      ( i_clk        ),
           .i_rstn     ( i_rstn       ),
           .i_id       ( i_id         ),
           .o_req      ( tb_o_req      ),
           .i_ack      ( tb_i_ack      ),
           .o_cmd      ( tb_o_cmd      ),
           .o_data     ( tb_o_data     ),
           .i_xcom_data( i_xcom_data[k] ),
           .i_xcom_clk ( i_xcom_clk[k]   ),
           .o_dbg_state( tb_o_dbg_state)
       );
      xcom_link_rx LINK (
         .i_clk     ( i_clk   ),
         .i_rstn    ( i_rstn  ),
         .xcom_id_i   ( i_id ),
         .rx_req_o    ( rx_req_s [k] ),
         .rx_ack_i    ( rx_ack_s [k] ),
         .rx_cmd_o    ( rx_cmd_s [k] ),
         .rx_data_o   ( rx_data_s[k] ),
         .rx_dt_i     ( i_xcom_data  [k] ),
         .rx_ck_i     ( i_xcom_clk  [k] ),
         .rx_st_do    ( rx_st_ds [k] )
      );

  end
endgenerate


// RX Command Priority Encoder
/////////////////////////////////////////////////////////////////////////////
integer i ;
always_comb begin
  rx_cmd_valid  = 1'b0;
  rx_cmd_ind    = 0;
  for (i = 0 ; i < NCH; i=i+1)
    if (!rx_cmd_valid & rx_req_s[i]) begin
      rx_cmd_valid   = 1'b1;
      rx_cmd_ind     = i;
   end
end

typedef enum logic [2-1:0]{ IDLE = 2'b00, 
                            REQ  = 2'b01, 
                            ACK  = 2'b10 
} state_t;
state_t state_r, state_n;

always_ff @ (posedge i_clk) begin
   if      ( !i_rstn   )  state_r  <= IDLE;
   else                     state_r  <= state_n;
end

always_comb begin
   state_n   = state_r; // Default Current
   rx_cmd_req   = 1'b0;
   rx_cmd_id_wr = 1'b0;
   case (state_r)
      IDLE:  begin
         if ( rx_cmd_valid ) begin
            state_n = REQ;
            rx_cmd_req   = 1'b1;
            rx_cmd_id_wr = 1'b1;
         end
      end
      REQ:  begin
         rx_cmd_req       = 1'b1;
         if ( rx_cmd_ack ) state_n = ACK;     
      end
      ACK:  begin
         if ( !rx_cmd_ack ) state_n = IDLE;     
      end
      default: state_n = state_r;
   endcase
end

// RX Caller ID
/////////////////////////////////////////////////////////////////////////////
always_ff @ (posedge i_clk) begin
   if      ( !i_rstn   )  rx_cmd_id  <= 0;
   else if ( rx_cmd_id_wr ) rx_cmd_id  <= rx_cmd_ind;
end

// RX Command Decoder ACK
/////////////////////////////////////////////////////////////////////////////
integer ind_ch;
always_comb begin
   for (ind_ch=0; ind_ch < NCH ; ind_ch=ind_ch+1) begin: RX_DECOX
      if (ind_ch == rx_cmd_id)
         rx_ack_s[ind_ch] = rx_cmd_ack;
      else 
         rx_ack_s[ind_ch] = 1'b0;
    end
end

// C CLOCK REQ SYNC 
///////////////////////////////////////////////////////////////////////////////
sync_reg #(.DW(1)) rx_req_sync (
   .dt_i      ( rx_cmd_req  ) ,
   .clk_i     ( c_clk_i     ) ,
   .rst_ni    ( c_rst_ni    ) ,
   .dt_o      ( c_cmd_req   ) );


// X CLOCK ACK SYNC 
/////////////////////////////////////////////////////////////////////////////
sync_reg #(.DW(1)) SYNC (
   .dt_i      ( c_cmd_ack   ) ,
   .clk_i     ( i_clk     ) ,
   .rst_ni    ( i_rstn    ) ,
   .dt_o      ( rx_cmd_ack  ) );
   
 
typedef enum { C_IDLE, C_EXEC, C_ACK} TYPE_C_CMD_ST ;
(* fsm_encoding = "one_hot" *) TYPE_C_CMD_ST c_cmd_st;
TYPE_C_CMD_ST c_cmd_st_nxt;

always_ff @ (posedge c_clk_i) begin
   if      ( !c_rst_ni   )  c_cmd_st  <= C_IDLE;
   else                     c_cmd_st  <= c_cmd_st_nxt;
end

always_comb begin
   c_cmd_st_nxt = c_cmd_st; // Default Current
   c_cmd_vld    = 1'b0;
   c_cmd_ack    = 1'b0;
   case (c_cmd_st)
      C_IDLE : begin
         if ( c_cmd_req ) begin
            c_cmd_vld    = 1'b1;
            c_cmd_ack    = 1'b1;
            c_cmd_st_nxt  = C_ACK;
         end
      end
      C_EXEC : begin
         c_cmd_vld    = 1'b1;
         c_cmd_ack    = 1'b1;
         c_cmd_st_nxt = C_ACK;     
      end
      C_ACK : begin
         c_cmd_ack    = 1'b1;
         if ( !c_cmd_req )
            c_cmd_st_nxt  = C_IDLE; 
      end
      default: c_cmd_st_nxt = c_cmd_st;
   endcase
end

logic [ 4-1:0] c_cmd_id, c_cmd_op ;
logic [32-1:0] c_cmd_dt ;

assign c_cmd_op = rx_cmd_s[rx_cmd_id];
assign c_cmd_dt = rx_data_s[rx_cmd_id];
assign c_cmd_id = rx_cmd_id;

  
// DEBUG
///////////////////////////////////////////////////////////////////////////////
assign cmd_st_do = {c_cmd_st[1:0], state_r[1:0]};
assign rx_st_do  = { rx_st_ds[1], rx_st_ds[0] } ;

// OUTPUTS
///////////////////////////////////////////////////////////////////////////////
assign cmd_op_o  = c_cmd_op ;
assign cmd_dt_o  = c_cmd_dt ;
assign cmd_id_o  = c_cmd_id ;
assign cmd_vld_o = c_cmd_vld;

endmodule
