///////////////////////////////////////////////////////////////////////////////
//  FERMI RESEARCH LAB
///////////////////////////////////////////////////////////////////////////////
//  qtt_cmd
//  Faithful port from qick_time_tagger's qtt_cmd.sv. Cross-domain command
//  dispatch: unifies three command sources - the tProc core (c_clk_i), the
//  AXI/Python registers (clk_i-domain already), and an external ARM/DISARM
//  level input - into a single decoded command stream on clk_i (the ADC
//  clock), which drives the time tagger's arm/threshold/inhibit/pop/reset
//  controls.
//
//  Reuse decisions (see Tier 0 of the qick_time_tagger port):
//    - legacy `sync_reg` -> qick:cdc:cdc_reg_sync (port-for-port match).
//    - legacy raw `xpm_cdc_handshake` -> qick:cdc:cdc_handshake. This also
//      drops the legacy c_en_r/cdc_ack bookkeeping entirely: cdc_handshake
//      registers i_data internally on i_valid and reports o_busy/o_valid on
//      its own, so c_op_i/c_dt_i/c_en_i are wired straight into it instead
//      of through an extra source-side staging register + ack toggle.
//    - `sync_pulse` -> already-ported qick:cdc:sync_pulse (Tier 0), used as-is.
//
//  Also fixes a duplicate `assign` in the legacy source: `ext_arm_t01`/
//  `ext_arm_t10` were assigned twice with identical right-hand sides (once
//  right after the input sync, again under "Command Decoding") - harmless
//  in simulation (both drives always agree) but redundant; kept once.
///////////////////////////////////////////////////////////////////////////////

module qtt_cmd (
   input  wire             clk_i         ,  // ADC clock
   input  wire             rst_ni        ,  // reset on ADC clock
   input  wire             c_clk_i       ,  // tProc core clock
   input  wire             c_rst_ni      ,  // reset on tProc core clock
   input  wire             ext_arm_i     ,  // external arm signal (typ. on ADC clock)
   input  wire             c_en_i        ,  // command enable, from tProc core (assumed slower than ADC clock)
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

cdc_reg_sync # (
   .DW ( 7 )
) sync_cmd (
   .dt_i      ( {ext_arm_i, p_en_i, p_op_i} ) ,
   .clk_i     ( clk_i ) ,
   .rst_ni    ( rst_ni ) ,
   .dt_o      ( {ext_arm_r, p_en_r, p_op_r} ) );

wire        c_en_2r;
wire [4:0]  c_op_2r;
wire [31:0] c_dt_2r;

cdc_handshake #(
   .DW ( 37 ),
   .NS ( 2  )
) cdc_cmd (
   .i_clk    ( c_clk_i               ) ,
   .i_rstn   ( c_rst_ni              ) ,
   .i_data   ( {c_op_i, c_dt_i}      ) ,
   .i_valid  ( c_en_i                ) ,
   .o_busy   (                       ) ,
   .o_clk    ( clk_i                 ) ,
   .o_rstn   ( rst_ni                ) ,
   .o_data   ( {c_op_2r, c_dt_2r}    ) ,
   .o_valid  ( c_en_2r               )
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
wire cmd_disarm, cmd_arm, cmd_pop, cmd_peek, cmd_set_th, cmd_set_inh, cmd_reset;

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
