///////////////////////////////////////////////////////////////////////////////
//  FERMI RESEARCH LAB
///////////////////////////////////////////////////////////////////////////////
//  qtt_cmd_hold  (source-clock side of the AXI command path of qick_time_tagger)
//
//  The CTRL register is a one-clock pulse (AUTO_CLEAR_BIT0): `en` and the `op`
//  bits change together for a single s_axi_aclk cycle, and qtt_cmd then samples
//  them in the (faster) ADC clock domain through per-bit synchronisers, taking
//  `op` on the sample where it first sees `en`. With any routing skew between the
//  `en` bit and an `op` bit (a few hundred ps is enough) that sample can see the
//  new `en` with the old `op` (0 = DISARM): the command is lost or turned into
//  another one. Measured on an RFSoC4x2: 19 of 300 set_dead_time/set_threshold
//  pairs did not take effect; a bench with 0.2 ns of skew loses about 6 %.
//
//  This block latches `op` first and raises `en` two source clocks later, then holds
//  both for HOLD clocks, so the ADC side always sees a stable `op` when `en` rises.
//  A strobe that arrives while a command is being held is remembered and issued after it (one
//  strobe is remembered: a second one replaces it; the Python driver never writes CTRL that fast).
///////////////////////////////////////////////////////////////////////////////
module qtt_cmd_hold # (
   parameter int HOLD = 6
) (
   input  wire         clk_i    ,
   input  wire         rst_ni   ,
   input  wire         strobe_i ,   // one-clock command strobe (CTRL bit 0)
   input  wire  [4:0]  op_i     ,   // command opcode, valid with the strobe
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
