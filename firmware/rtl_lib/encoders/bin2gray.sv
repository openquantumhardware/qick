///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : bin2gray
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    bin2gray.sv
//!
//! @brief   TODO: one-line description.
//!
//! @author  QICK Development Team
//!
//! @version 1.0

`timescale 1ns / 1ps

module bin2gray#(
    parameter int B = 8
)(
    input  logic [B-1:0] din,
    output logic [B-1:0] dout
);

    always_comb begin
        dout[B-1] = din[B-1];
        for (int i = 0; i < B-1; i++) begin
            dout[i] = din[i+1] ^ din[i];
        end
    end

endmodule
