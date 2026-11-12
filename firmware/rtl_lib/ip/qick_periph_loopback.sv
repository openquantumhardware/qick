///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : qick_periph_loopback
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    qick_periph_loopback.sv
//!
//! @brief     Test peripheral for the QP1 / QP2 ports of the tProc v2: it answers a PA / PB command with a
//!            function of its operands, after a fixed delay.
//!
//! @details
//!
//! Protocol (tProc side: qp*_en_o, qp*_op_o, qp*_a/b/c/d_dt_o, qp*_rdy_i, qp*_dt1_i, qp*_dt2_i, qp*_vld_i, qp*_flag_i):
//!
//!   - rdy_o is high when the peripheral can take a command and low while it is working.
//!   - A command is taken on a clock with en_i high and rdy_o high. en_i with rdy_o low is DROPPED, and counted in
//!     drop_cnt_o (the tProc does not stall on rdy; what it does with a PA issued while not ready is what this core exists to show).
//!   - DELAY clocks after the command, vld_o pulses for one clock and the results are valid on it:
//!       dt1_o = a + b          (32 bits, wraps)
//!       dt2_o = c ^ d ^ op     (op zero-extended)
//!     rdy_o goes high again on that clock.
//!   - flag_o follows bit 0 of operand a of the last command (the tProc can branch on it with the QP1 flag source).
//!   - cmd_cnt_o counts the commands taken, op_o the last op code and arg_o the last four operands, for observation.
//!
//! @author  QICK Development Team
//!
//! @version 1.0
module qick_periph_loopback #(
   //! clocks from the command to vld_o (>= 1)
   parameter int DELAY = 3
)(
   input  logic        clk_i      ,
   input  logic        rst_ni     ,
   input  logic        en_i       ,
   input  logic [4:0]  op_i       ,
   input  logic [31:0] a_i        ,
   input  logic [31:0] b_i        ,
   input  logic [31:0] c_i        ,
   input  logic [31:0] d_i        ,
   output logic        rdy_o      ,
   output logic [31:0] dt1_o      ,
   output logic [31:0] dt2_o      ,
   output logic        vld_o      ,
   output logic        flag_o     ,
   output logic [31:0] cmd_cnt_o  ,
   output logic [31:0] drop_cnt_o
);

   localparam int CW = (DELAY > 1) ? $clog2(DELAY + 1) : 1;

   logic [CW-1:0] cnt;
   logic          busy;
   logic [4:0]    op_q;
   logic [31:0]   a_q, b_q, c_q, d_q;

   always_ff @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni) begin
         busy       <= 1'b0;
         cnt        <= '0;
         vld_o      <= 1'b0;
         dt1_o      <= '0;
         dt2_o      <= '0;
         flag_o     <= 1'b0;
         cmd_cnt_o  <= '0;
         drop_cnt_o <= '0;
         op_q       <= '0;
         {a_q, b_q, c_q, d_q} <= '0;
      end else begin
         vld_o <= 1'b0;
         if (busy) begin
            if (en_i) drop_cnt_o <= drop_cnt_o + 32'd1;
            if (cnt == CW'(1)) begin
               busy  <= 1'b0;
               vld_o <= 1'b1;
               dt1_o <= a_q + b_q;
               dt2_o <= c_q ^ d_q ^ {27'd0, op_q};
            end
            cnt <= cnt - CW'(1);
         end else if (en_i) begin
            busy      <= 1'b1;
            cnt       <= CW'(DELAY);
            op_q      <= op_i;
            {a_q, b_q, c_q, d_q} <= {a_i, b_i, c_i, d_i};
            flag_o    <= a_i[0];
            cmd_cnt_o <= cmd_cnt_o + 32'd1;
         end
      end
   end

   assign rdy_o = ~busy;

endmodule
