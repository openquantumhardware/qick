///////////////////////////////////////////////////////////////////////////////
//  FERMI RESEARCH LAB
///////////////////////////////////////////////////////////////////////////////
//  Author         : Martin Di Federico
//  Date           : 2024_5_31
///////////////////////////////////////////////////////////////////////////////


module qtt_cmd (
   input  wire             clk_i         ,  // ADC clock
   input  wire             rst_ni        ,  // reset on ADC clock
   input  wire             c_clk_i       ,  // tProc core clock
   input  wire             c_rst_ni      ,  // reset on tProc core clock
   input  wire             ext_arm_i     ,  // external arm signal (typ. on ADC clock)
   input  wire             c_en_i        ,  // command enable, from tProc core (core clock is assumed to be slower than ADC clock)
   input  wire  [4:0]      c_op_i        ,  // command opcode, from tProc core
   input  wire  [31:0]     c_dt_i        ,  // command data, from tProc core
   input  wire             p_en_i        ,  // command enable, from AXI registers
   input  wire  [4:0]      p_op_i        ,  // command opcode, from AXI registers
   input  wire  [31:0]     p_dt_i        ,  // command data, from AXI registers
   output  wire            pop_req_o     ,  // pop, to time tagger
   output  wire            rst_req_o     ,  // reset, to time tagger
   input  wire             rst_ack_i     ,  // reset acknowledge, from time tagger
   output  wire            peek_o        ,  // peek (data-valid), to tProc core
   output  wire            qtt_arm_o     ,  // arm signal, to time tagger and AXI register
   output  wire [15:0]     qtt_cmp_th_o  ,  // threshold, to time tagger and AXI register
   output  wire [7 :0]     qtt_cmp_inh_o ,  // deadtime, to time tagger and AXI register
   output  wire [7 :0]     cmd_cnt_do    ); // command count, to AXI register


// Sincronization
///////////////////////////////////////////////////////////////////////////////
wire        p_en_r, p_en_r_t01;
wire        ext_arm_r, ext_arm_t01, ext_arm_t10;
wire [4:0]  p_op_r;
reg         ext_arm_2r, p_en_2r;

sync_reg # (
   .DW ( 7 )
) sync_cmd (
   .dt_i      ( {ext_arm_i, p_en_i, p_op_i} ) ,
   .clk_i     ( clk_i ) ,
   .rst_ni    ( rst_ni ) ,
   .dt_o      ( {ext_arm_r, p_en_r, p_op_r} ) );

reg         c_en_r;
reg [4:0]   c_op_r;
reg [31:0]  c_dt_r;
wire        cdc_ack;

always_ff @(posedge c_clk_i)
   if (!c_rst_ni) begin
      c_en_r     <= 0;
      c_op_r     <= 5'd0;
      c_dt_r     <= 32'd0;
   end else begin
      c_op_r     <= c_op_i;
      c_dt_r     <= c_dt_i;
      if (cdc_ack) begin
          c_en_r     <= 0;
      end else if (c_en_i) begin
          c_en_r     <= c_en_i;
      end
   end
wire        c_en_2r;
wire [4:0]  c_op_2r;
wire [31:0] c_dt_2r;

xpm_cdc_handshake #(
  .DEST_EXT_HSK(0),   // DECIMAL; 0=internal handshake, 1=external handshake
  .DEST_SYNC_FF(2),   // DECIMAL; range: 2-10
  .INIT_SYNC_FF(0),   // DECIMAL; 0=disable simulation init values, 1=enable simulation init values
  .SIM_ASSERT_CHK(0), // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
  .SRC_SYNC_FF(2),    // DECIMAL; range: 2-10
  .WIDTH(37)           // DECIMAL; range: 1-1024
)
xpm_cdc_handshake_core (
  .dest_out({c_op_2r, c_dt_2r}), // WIDTH-bit output: Input bus (src_in) synchronized to destination clock domain.
  .dest_req(c_en_2r), // When DEST_EXT_HSK = 0, this signal asserts for one clock period when dest_out bus is valid. This output is registered.
  .src_rcv(cdc_ack),   // 1-bit output: Acknowledgement from destination logic that src_in has been received.
  .dest_ack(), // 1-bit input: optional; required when DEST_EXT_HSK = 1
  .dest_clk(clk_i), // 1-bit input: Destination clock.
  .src_clk(c_clk_i),   // 1-bit input: Source clock.
  .src_in({c_op_r, c_dt_r}),     // WIDTH-bit input: Input bus that will be synchronized to the destination clock domain.
  .src_send(c_en_r)  // 1-bit input: Assertion of this signal allows the src_in bus to be synchronized to the destination clock domain.
);

assign p_en_r_t01  =  !p_en_2r & p_en_r;
assign ext_arm_t01 =  !ext_arm_2r &  ext_arm_r;   
assign ext_arm_t10 =   ext_arm_2r & !ext_arm_r;   

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
      p_en_2r    <= p_en_r;
      ext_arm_2r <= ext_arm_r;
      // Python Command
      if (p_en_r_t01) begin
         cmd_req     <= 1'b1;
         cmd_op      <= p_op_r ;
         cmd_dt      <= p_dt_i ;
         p_cmd_cnt   <= p_cmd_cnt + 1'b1;
      // Processor Command
      end else if (c_en_2r) begin
         cmd_req     <= 1'b1;
         cmd_op      <= c_op_2r ;
         cmd_dt      <= c_dt_2r ;
         c_cmd_cnt   <= c_cmd_cnt + 1'b1;
      //External ARM
      end else if (ext_arm_t01) begin
         cmd_req     <= 1'b1;
         cmd_op      <= 5'b00001 ;
         cmd_dt      <= 0 ;
         c_cmd_cnt   <= c_cmd_cnt + 1'b1;
      //External DISARM
      end else if (ext_arm_t10) begin
         cmd_req     <= 1'b1;
         cmd_op      <= 5'b00000 ;
         cmd_dt      <= 0 ;
         c_cmd_cnt   <= c_cmd_cnt + 1'b1;

      end else
      if ( cmd_req ) cmd_req  <= 1'b0;
   end

// Command Decoding 
///////////////////////////////////////////////////////////////////////////////

assign ext_arm_t01 =  !ext_arm_2r & ext_arm_r;   
assign ext_arm_t10 =  ext_arm_2r & !ext_arm_r;

assign    cmd_disarm   = cmd_req & ( cmd_op==5'b00000 );
assign    cmd_arm      = cmd_req & ( cmd_op==5'b00001 );
assign    cmd_pop      = cmd_req & ( cmd_op==5'b00010 );
assign    cmd_peek     = cmd_req & ( cmd_op==5'b00011 );
assign    cmd_set_th   = cmd_req & ( cmd_op==5'b00100 );
assign    cmd_set_inh  = cmd_req & ( cmd_op==5'b00101 );

assign    cmd_reset    = cmd_req & ( cmd_op==5'b00111 );



// Command Processing 
///////////////////////////////////////////////////////////////////////////////
reg         qtt_arm, qtt_rst, qtt_pop;
reg[15:0]   qtt_cmp_th;
reg[ 7:0]   qtt_cmp_inh;
reg         core_peek;

always_ff @ (posedge clk_i, negedge rst_ni) begin
   if ( !rst_ni ) begin
      qtt_arm     <= 0;
      qtt_cmp_th  <= 0;
      qtt_cmp_inh <= 0;
      qtt_rst     <= 0;
      qtt_pop     <= 0;
      core_peek   <= 0;
      
   end 
      else if ( cmd_arm       ) qtt_arm     <= 1'b1;
      else if ( cmd_disarm    ) qtt_arm     <= 1'b0;
      else if ( cmd_reset     ) qtt_rst     <= 1'b1;
      else if ( rst_ack_i     ) qtt_rst     <= 1'b0;
      else if ( cmd_pop       ) qtt_pop     <= 1'b1;
      else if ( qtt_pop       ) qtt_pop     <= 1'b0;
      else if ( cmd_peek      ) core_peek   <= 1'b1;
      else if ( core_peek     ) core_peek   <= 1'b0;

      else if ( cmd_set_th  ) qtt_cmp_th   <= cmd_dt[15:0];
      else if ( cmd_set_inh ) qtt_cmp_inh  <= cmd_dt[7:0];
end

/*
pulse_cdc peek_sync (
   .clk_a_i   ( clk_i    ) ,
   .rst_a_ni  ( rst_ni   ) ,
   .pulse_a_i ( core_peek) ,
   .rdy_a_o   (          ) ,
   .clk_b_i   ( c_clk_i  ) ,
   .rst_b_ni  ( c_rst_ni ) ,
   .pulse_b_o ( peek_o   )
);
*/

sync_pulse # (
   .QUEUE_AW ( 8 ) ,
   .BLOCK    ( 0  )
) peek_sync (
   .a_clk_i    ( clk_i   ) ,
   .a_rst_ni   ( rst_ni  ) ,
   .a_pulse_i  ( core_peek   ) ,
   .b_clk_i    ( c_clk_i ) ,
   .b_rst_ni   ( c_rst_ni) ,
   .b_pulse_o  ( peek_o   ) ,
   .b_en_i     ( 1'b1 ) ,
   .pulse_full (  ) );

// OUTPUTS
///////////////////////////////////////////////////////////////////////////////
assign pop_req_o     = qtt_pop ;
assign rst_req_o     = qtt_rst;
assign qtt_arm_o     = qtt_arm     ;
assign qtt_cmp_th_o  = qtt_cmp_th  ;
assign qtt_cmp_inh_o = qtt_cmp_inh ;

// DEBUG
///////////////////////////////////////////////////////////////////////////////
assign cmd_cnt_do ={ c_cmd_cnt, p_cmd_cnt };  

endmodule
