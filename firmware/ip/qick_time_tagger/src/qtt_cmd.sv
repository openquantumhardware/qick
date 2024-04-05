///////////////////////////////////////////////////////////////////////////////
//  FERMI RESEARCH LAB
///////////////////////////////////////////////////////////////////////////////
//  Author         : Martin Di Federico
//  Date           : 1-2024
//  Version        : 1
///////////////////////////////////////////////////////////////////////////////

module qtt_cmd (
   input  wire             clk_i       ,
   input  wire             rst_ni      ,
   input  wire             c_en_i        ,
   input  wire  [4:0]      c_op_i        ,
   input  wire  [31:0]     c_dt_i        ,
   input  wire             p_en_i        ,
   input  wire  [4:0]      p_op_i        ,
   input  wire  [31:0]     p_dt_i        ,
   output  wire            pop_req_o     ,
   output  wire            rst_req_o     ,
   input  wire             rst_ack_i     ,
   output  wire            qtt_arm_o     ,
   output  wire [15:0]     qtt_cmp_th_o  ,
   output  wire [ 7:0]     qtt_cmp_inh_o ,
   output  wire  [8:0]     cmd_cnt_do    );


// Sincronization
///////////////////////////////////////////////////////////////////////////////
wire        p_en_r, p_en_r_t01;
wire [4:0]  p_op_r;
reg         p_en_2r;

sync_reg # (
   .DW (  )
) sync_tx_i (
   .dt_i      ( {p_en_i, p_op_i} ) ,
   .clk_i     ( clk_i ) ,
   .rst_ni    ( rst_ni ) ,
   .dt_o      ( {p_en_r, p_op_r} ) );

assign p_en_r_t01 =  !p_en_2r & p_en_r;   

// COMMAND OPERATON
reg         cmd_req;
reg [ 4:0]  cmd_op;
reg [31:0]  cmd_dt;
reg [ 3:0]  p_cmd_cnt, c_cmd_cnt;
always_ff @(posedge clk_i) 
   if (!rst_ni) begin
      cmd_req     <= 1'b0;
      cmd_op      <= 5'd0;
      cmd_dt      <= 0;
      p_cmd_cnt   <= 3'd0;
      c_cmd_cnt   <= 3'd0;
   end else begin 
      p_en_2r <= p_en_r;
      if (p_en_r_t01) begin
         cmd_req     <= 1'b1;
         cmd_op      <= p_op_r ;
         cmd_dt      <= p_dt_i ;
         p_cmd_cnt   <= p_cmd_cnt + 1'b1;
      end else if (c_en_i) begin
         cmd_req     <= 1'b1;
         cmd_op      <= c_op_i ;
         cmd_dt      <= c_dt_i ;
         c_cmd_cnt   <= c_cmd_cnt + 1'b1;
      end else
      if ( cmd_req ) begin 
         cmd_req  <= 1'b0;
      end
   end

// Command Decoding 
///////////////////////////////////////////////////////////////////////////////
assign    cmd_disarm   = cmd_req & ( cmd_op==5'b00000 );
assign    cmd_arm      = cmd_req & ( cmd_op==5'b00001 );
assign    cmd_pop      = cmd_req & ( cmd_op==5'b00010 );

assign    cmd_set_th   = cmd_req & ( cmd_op==5'b00100 );
assign    cmd_set_inh  = cmd_req & ( cmd_op==5'b00101 );

assign    cmd_reset    = cmd_req & ( cmd_op==5'b00111 );



// Command Processing 
///////////////////////////////////////////////////////////////////////////////
reg         qtt_arm, qtt_rst, qtt_pop;
reg[15:0]   qtt_cmp_th;
reg[ 7:0]   qtt_cmp_inh;

always_ff @ (posedge clk_i, negedge rst_ni) begin
   if ( !rst_ni ) begin
      qtt_arm     <= 0;
      qtt_cmp_th  <= 0;
      qtt_cmp_inh <= 0;
      qtt_rst     <= 0;
      qtt_pop     <= 0;
      
   end 
      else if ( cmd_arm       ) qtt_arm     <= 1'b1;
      else if ( cmd_disarm    ) qtt_arm     <= 1'b0;
      else if ( cmd_reset     ) qtt_rst     <= 1'b1;
      else if ( rst_ack_i     ) qtt_rst     <= 1'b0;
      else if ( cmd_pop       ) qtt_pop     <= 1'b1;
      else if ( qtt_pop     ) qtt_pop     <= 1'b0;

      else if ( cmd_set_th  ) qtt_cmp_th   <= cmd_dt[15:0];
      else if ( cmd_set_inh ) qtt_cmp_inh  <= cmd_dt[7:0];
end




// OUTPUTS
///////////////////////////////////////////////////////////////////////////////
assign pop_req_o = qtt_pop ;
assign rst_req_o = qtt_rst;
assign qtt_arm_o     = qtt_arm     ;
assign qtt_cmp_th_o  = qtt_cmp_th  ;
assign qtt_cmp_inh_o = qtt_cmp_inh ;
assign proc_pop_o    = cmd_pop;
// DEBUG
///////////////////////////////////////////////////////////////////////////////
assign cmd_cnt_do ={ c_cmd_cnt, p_cmd_cnt };  

endmodule



