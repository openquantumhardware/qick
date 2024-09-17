///////////////////////////////////////////////////////////////////////////////
//  FERMI RESEARCH LAB
///////////////////////////////////////////////////////////////////////////////
//  Author         : Martin Di Federico
//  Date           : 2024_5
//  Version        : 1
///////////////////////////////////////////////////////////////////////////////
// This module receives commands from the Processor and from Python and generates the Request signal
/*
qick_cmd #(
   .OP_DW  ( 5 ),
   .DT_QTY ( 4 )
) CMD_SYNC (
   .clk_i      ( clk_i      ),
   .rst_ni     ( rst_ni     ),
   .c_en_i     ( c_en_i     ),
   .c_op_i     ( c_op_i     ),
   .c_dt_i     ( c_dt_i     ),
   .p_ctrl_i   ( p_ctrl_i   ),
   .p_dt_i     ( p_dt_i     ),
   .cmd_req_o  ( cmd_req_o  ),
   .cmd_ack_i  ( cmd_ack_i  ),
   .cmd_op_o   ( cmd_op_o   ),
   .cmd_dt_o   ( cmd_dt_o   ),
   .cmd_cnt_do ( cmd_cnt_do ));
*/
   
module qick_cmd #(
   parameter OP_DW  = 5 ,
   parameter DT_QTY = 4
)(
   input  wire             clk_i       ,
   input  wire             rst_ni      ,
   input  wire             ps_clk_i    ,
   input  wire             ps_rst_ni   ,
   // Command from tProcessor
   input  wire             c_en_i      ,
   input  wire [4:0]       c_op_i      ,
   input  wire [31:0]      c_dt_i [DT_QTY]  ,
   // Command from Python
   input  wire [OP_DW:0]   p_ctrl_i    ,
   input  wire [31:0]      p_dt_i [DT_QTY]  ,
   // Command Execution
   output wire             cmd_req_o   ,
   input  wire             cmd_ack_i   ,
   output wire [OP_DW-1:0] cmd_op_o    ,
   output wire [31:0]      cmd_dt_o [DT_QTY],
   output wire [7 :0]      cmd_cnt_do  );

// PS to Core Sincronization
///////////////////////////////////////////////////////////////////////////////
// Register the Operation and generates one clock later the Enable.
reg [OP_DW-1:0] p_op_r;
reg p_ctrl_en, p_ctrl_en_r;
always_ff @(posedge ps_clk_i) 
   if (!ps_rst_ni) begin
      p_op_r       <= 0;
      p_ctrl_en    <= 1'b0;
      p_ctrl_en_r  <= 1'b0;
   end else begin 
      if (p_ctrl_i[0]) 
         p_op_r <= p_ctrl_i[OP_DW:1];
      p_ctrl_en <= p_ctrl_i[0];
      p_ctrl_en_r <= p_ctrl_en;
   end
wire              p_en_r, p_en_r_t01;
sync_reg # (
   .DW ( 1 )
) sync_tx_i (
   .dt_i      ( p_ctrl_en_r ) ,
   .clk_i     ( clk_i      ) ,
   .rst_ni    ( rst_ni     ) ,
   .dt_o      ( p_en_r  ) );

reg               p_en_2r;
always_ff @(posedge clk_i) if (!rst_ni) p_en_2r <= 1'b0; else p_en_2r <= p_en_r;

assign p_en_r_t01 =  !p_en_2r & p_en_r;   

// COMMAND OPERATON
reg               cmd_req;
reg [OP_DW-1:0]   cmd_op;
reg [31:0]        cmd_dt [DT_QTY];
// Command Debug
reg [ 3:0]        p_cmd_cnt, c_cmd_cnt;

always_ff @(posedge clk_i) 
   if (!rst_ni) begin
      cmd_req     <= 1'b0;
      cmd_op      <= '{default:'0};
      cmd_dt      <= '{default:'0};
      p_cmd_cnt   <= 3'd0;
      c_cmd_cnt   <= 3'd0;
   end else begin 
      if (p_en_r_t01 & !cmd_ack_i) begin
         cmd_req     <= 1'b1;
         cmd_op      <= p_op_r ;
         cmd_dt      <= p_dt_i ;
         p_cmd_cnt   <= p_cmd_cnt + 1'b1;
      end else if (c_en_i & !cmd_ack_i) begin
         cmd_req     <= 1'b1;
         cmd_op      <= c_op_i ;
         cmd_dt      <= c_dt_i ;
         c_cmd_cnt   <= c_cmd_cnt + 1'b1;
      end else
      if ( cmd_ack_i ) cmd_req  <= 1'b0;
   end

// OUTPUTS
///////////////////////////////////////////////////////////////////////////////
assign cmd_req_o  = cmd_req;
assign cmd_op_o   = cmd_op;
assign cmd_dt_o   = cmd_dt;

// DEBUG
///////////////////////////////////////////////////////////////////////////////
assign cmd_cnt_do ={ c_cmd_cnt, p_cmd_cnt };  

endmodule