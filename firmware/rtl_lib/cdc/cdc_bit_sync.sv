///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : cdc_bit_sync
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    cdc_bit_sync.sv
//!
//! @brief   Single-bit CDC synchronizer with configurable number of stages.
//!
//! @details
//!   Synchronizes a single asynchronous bit into the destination clock domain
//!   using a configurable pipeline of flip-flops.
//!
//! @author  QICK Development Team
//!
//! @version 2.0
module cdc_bit_sync #(

    parameter int NSTAGES = 2  //! Number of synchronization stages (minimum recommended: 2)
)(
    input  logic i_clk,
    input  logic i_rstn,
    input  logic i_async,
    output logic o_sync
);

    initial begin
        if (NSTAGES < 2)
            $error("cdc_bit_sync: NSTAGES must be >= 2.");
    end


    (* ASYNC_REG = "TRUE" *) logic [NSTAGES-1:0] sync_r;

    always_ff @(posedge i_clk) begin
        if (!i_rstn) begin
            sync_r <= '0;
        end
        else begin
            sync_r[0] <= i_async;

            for (int i = 1; i < NSTAGES; i++) begin
                sync_r[i] <= sync_r[i-1];
            end
        end
    end

    assign o_sync = sync_r[NSTAGES-1];

endmodule
