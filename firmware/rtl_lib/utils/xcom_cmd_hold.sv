///////////////////////////////////////////////////////////////////////////////
//  FERMI RESEARCH LAB
///////////////////////////////////////////////////////////////////////////////
//  xcom_cmd_hold  (source-clock side of xcom's AXI command path)
//
//  CTRL_REG[0] is the Python/AXI command strobe and CTRL_REG[5:1] the opcode.
//  xcom.sv's axil_slv now has AUTO_CLEAR_BIT0=1 (fixed alongside this core),
//  so CTRL_REG is a genuine one-clock pulse at the register: before that fix
//  it never cleared itself, and xcom_cmd's level-sensitive request/acknowledge
//  FSM (req_ack_cmd) re-issued the same command forever once it saw the valid
//  bit stuck high -- confirmed in simulation (xcom's own bench, driven over
//  its AXI4-Lite port): one write of CTRL_REG executed the command 13 times in
//  300 i_ps_clk cycles and kept going.
//
//  That one-clock pulse still has to reach i_time_clk: xcom_cdc synchronises
//  ONLY bit 0 (cdc_bit_sync) and passes the opcode bits through with no
//  synchroniser at all (`assign o_xcom_ctrl_sync[31:1] = i_xcom_ctrl[31:1]`).
//  This block latches the opcode first and raises a bounded strobe HOLD
//  i_ps_clk cycles later, mirroring qtt_cmd_hold (qick_time_tagger's AXI
//  command path, which needed the same treatment for the same reason). Holding
//  the opcode constant for HOLD cycles around the strobe gives xcom_cdc's
//  unsynchronised opcode passthrough time to settle well before the
//  synchronised strobe bit is seen in i_time_clk, instead of the opcode bits
//  crossing as a bare single-cycle combinational value.
//
//  A strobe that arrives while a command is being held is remembered and
//  issued after it (one strobe is remembered: a second one replaces it; the
//  Python driver never writes CTRL_REG that fast). This block assumes
//  strobe_i is itself a bounded pulse (a handful of clocks at most); it is
//  not a substitute for clearing the source register (see AUTO_CLEAR_BIT0
//  above) -- a strobe held high indefinitely still repeats, once per
//  HOLD+1 clocks.
///////////////////////////////////////////////////////////////////////////////
module xcom_cmd_hold # (
   parameter int HOLD = 6
) (
   input  wire         clk_i    ,
   input  wire         rst_ni   ,
   input  wire         strobe_i ,   // one-clock (or longer) command strobe (CTRL_REG bit 0)
   input  wire  [4:0]  op_i     ,   // command opcode, valid with the strobe (CTRL_REG bits [5:1])
   output reg          en_o     ,   // held command enable
   output reg   [4:0]  op_o     );  // opcode, stable before en_o rises and until it falls

reg [3:0] cnt;              // 0: idle; HOLD+1 .. 1: a command is being held
reg       pend;
reg [4:0] op_pend;

always_ff @(posedge clk_i) begin
   if (!rst_ni) begin
      cnt     <= 0;
      en_o    <= 1'b0;
      op_o    <= 5'd0;
      pend    <= 1'b0;
      op_pend <= 5'd0;
   end else begin
      en_o <= (cnt != 0) && (cnt <= HOLD);
      if (cnt != 0) begin
         cnt <= cnt - 1'b1;
         if (strobe_i) begin
            pend    <= 1'b1;
            op_pend <= op_i;
         end
      end else if (pend) begin
         pend <= 1'b0;
         op_o <= op_pend;
         cnt  <= HOLD + 1;
      end else if (strobe_i) begin
         op_o <= op_i;
         cnt  <= HOLD + 1;
      end
   end
end

endmodule
