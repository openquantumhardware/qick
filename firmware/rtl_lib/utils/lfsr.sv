///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : lfsr
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    lfsr.sv
//!
//! @brief     Generic, parameterizable Linear Feedback Shift Register (LFSR).
//!
//! @details
//!
//!
//! The register shifts left by one bit each enabled clock; the new LSB is the
//! feedback bit, computed as the (X)NOR reduction of the tapped register bits.
//! A synchronous load port allows seeding the register with an arbitrary value.
//!
//! Feedback (Fibonacci-style, single feedback into the LSB):
//! fb = XNOR ? ~(^(state & TAPS)) : (^(state & TAPS))
//! state <= {state[DW-2:0], fb}
//!
//! The TAPS mask selects which register bits participate in the feedback.
//! A '1' in bit position k of TAPS includes state bit k in the feedback
//! reduction. Choosing TAPS according to a maximal-length polynomial yields a
//! (2^DW - 1)-length pseudo-random sequence.
//!
//! NOTE on the all-zero state:
//! With XNOR feedback the lock-up state is all-ONES; the sequence runs
//! through all values except all-ones. With XOR feedback the lock-up state
//! is all-ZEROS. Use load_we_i to seed away from the lock-up state if needed
//! (the XNOR variant is convenient because it self-starts from reset value 0).
//!
//! @author  QICK Development Team
//!
//! @version 1.0
module lfsr #(
   //! register width in bits (default 32).
   parameter int            DW   = 32,
   parameter logic [31:0]   TAPS = 32'h8020_0003,  // bits {31,21,1,0}
   //! feedback type. 1 = XNOR reduction (lock-up = all ones, self-starts
   parameter bit            XNOR = 1'b1
)(
   input  logic          clk_i      ,
   input  logic          rst_ni     ,
   input  logic          en_i       ,
   input  logic          load_we_i  ,
   input  logic [DW-1:0] load_dt_i  ,
   output logic [DW-1:0] lfsr_dt_o
);

   logic [DW-1:0] reg_lfsr;
   logic          fb;

   // Feedback: (X)NOR reduction of the tapped bits.
   // TAPS is 32-bit in the package/default; slice to DW for the mask.
   assign fb = XNOR ? ~(^(reg_lfsr & TAPS[DW-1:0]))
                    :  (^(reg_lfsr & TAPS[DW-1:0]));

   always_ff @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni)
         reg_lfsr <= '0;
      else if (load_we_i)
         reg_lfsr <= load_dt_i;
      else if (en_i)
         reg_lfsr <= {reg_lfsr[DW-2:0], fb};
   end

   assign lfsr_dt_o = reg_lfsr;

endmodule
