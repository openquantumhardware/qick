///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : cdc_reg_sync
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    cdc_reg_sync.sv
//!
//! @brief   N-bit multi-register CDC synchronizer for stable signals.
//!
//! @details
//!
//! Replaces the `sync_reg` block originally defined in
//! `firmware/ip/qick_processor/src/_qproc_ips.sv`.
//!
//! This wrapper instantiates one `cdc_bit_sync` per bit. It is intended for
//! signals that are **stable long enough** to be safely captured by the
//! destination clock (typically control/status registers or enables that
//! change infrequently). Do **not** use this module for high-speed,
//! dynamically changing buses; for those cases use a full handshake or
//! Gray-code pointer synchronization.
//!
//! @generic
//! DW : unsigned int – data width in bits (default 1).
//!
//! @author  QICK Development Team
//!
//! @version 1.0
///////////////////////////////////////////////////////////////////////////////

module cdc_reg_sync #(
    parameter int unsigned DW = 1
)(
    input  wire                 clk_i,
    input  wire                 rst_ni,
    input  wire [DW-1:0]        dt_i,
    output wire [DW-1:0]        dt_o
);

    generate
        for (genvar i = 0; i < DW; i++) begin : gen_bit
            cdc_bit_sync #(
                .NSTAGES (2)
            ) u_sync_bit (
                .i_clk    (clk_i),
                .i_rstn   (rst_ni),
                .i_async  (dt_i[i]),
                .o_sync   (dt_o[i])
            );
        end
    endgenerate

endmodule
