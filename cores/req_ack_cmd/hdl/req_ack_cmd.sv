///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
//
// Fermi Fordward Alliance LLC
//
// Module: req_ack_cmd.sv
// Project: QICK 
// Description: Board communication peripheral
//
//
// Change history: 10/20/24 - v2 Started by mdifederico
//                 04/27/25 - Refactored by @lharnaldi
//
///////////////////////////////////////////////////////////////////////////////
module req_ack_cmd (
   input  logic             src_clk_i   ,
   input  logic             src_rst_ni  ,
   // Command Input
   input  logic             src_vld_i   ,
   input  logic [ 4:0]      src_op_i    ,
   input  logic [ 3:0]      src_dst_i   ,
   input  logic [31:0]      src_dt_i    ,
   // Command Execution
   output logic              loc_req_o   ,
   output logic              net_req_o   ,
   input  logic             async_ack_i ,
   input  logic             sync_ack_i  ,
   output logic [ 7:0]      cmd_op_o    ,
   output logic [31:0]      cmd_dt_o    ,
   output logic  [3:0]       cmd_cnt_do
);

sync_reg #(.DW(1)) sync_ack (
   .dt_i      ( async_ack_i ),
   .clk_i     ( src_clk_i   ),
   .rst_ni    ( src_rst_ni  ),
   .dt_o      ( async_ack_s  ));

assign ack_s = sync_ack_i | async_ack_s ;
   
typedef enum { IDLE, LOC_REQ, NET_REQ, ACK} TYPE_CMD_ST ;
(* fsm_encoding = "one_hot" *) TYPE_CMD_ST cmd_st;
TYPE_CMD_ST cmd_st_nxt;

always_ff @ (posedge src_clk_i) begin
   if      ( !src_rst_ni ) cmd_st <= IDLE;
   else                    cmd_st <= cmd_st_nxt;
end

always_comb begin
   cmd_st_nxt  = cmd_st; // Default Current
   loc_req_o   = 1'b0;
   net_req_o   = 1'b0;
   case (cmd_st)
      IDLE   :  begin
         if ( src_vld_i ) 
            if (src_op_i[4]) begin
                cmd_st_nxt  = LOC_REQ;
                loc_req_o   =  1'b1;
            end else begin
                cmd_st_nxt  = NET_REQ;
                net_req_o   = 1'b1;
         end
      end
      LOC_REQ  :  begin
         loc_req_o       = 1'b1;
         if ( ack_s ) cmd_st_nxt = ACK;     
      end
      NET_REQ  :  begin
         net_req_o       = 1'b1;
         if ( ack_s ) cmd_st_nxt = ACK;     
      end
      ACK  :  begin
         if ( !ack_s ) cmd_st_nxt = IDLE;     
      end
      default: cmd_st_nxt = cmd_st;
   endcase
end

// assign req = loc_req_o | net_req_o ;

 
logic  [ 7:0]   cmd_op_r;
logic  [31:0]   cmd_dt_r;
logic  [ 3:0]   cmd_cnt;
logic [ 7:0]   cmd_op_s;
assign cmd_op_s = {src_op_i[3:0], src_dst_i};

always_ff @(posedge src_clk_i) 
   if (!src_rst_ni) begin
      cmd_op_r   <= '{default:'0};
      cmd_dt_r   <= '{default:'0};
      cmd_cnt    <= 4'd0;
   end else if ( src_vld_i ) begin
      cmd_op_r   <= cmd_op_s ;
      cmd_dt_r   <= src_dt_i ;
      cmd_cnt    <= cmd_cnt + 1'b1;
   end
   
   
// OUTPUTS
///////////////////////////////////////////////////////////////////////////////
assign cmd_op_o   = src_vld_i ? cmd_op_s : cmd_op_r;
assign cmd_dt_o   = src_vld_i ? src_dt_i : cmd_dt_r;

// DEBUG
///////////////////////////////////////////////////////////////////////////////
assign cmd_cnt_do = cmd_cnt; 

endmodule

