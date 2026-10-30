///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : qproc_inport_reg
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    qproc_inport_reg.sv
//!
//! @brief   Registers the tProcessor v2 input ports and flags new-data arrival.
//!
//! @details
//!
//!
//! For each of the PORT_QTY input ports, the incoming 64-bit word is latched
//! whenever port_tvalid_i is asserted, and the corresponding bit of
//! port_tnew_o is set. The new-data flag for a given port is cleared on
//! c_clear (typically once the consumer has read the port), unless a new
//! valid word arrives on the same cycle, which takes priority.
//!
//! @author  QICK Development Team
//!
//! @version 1.0

module qproc_inport_reg #(
    parameter int PORT_QTY = 2
)(
    // Clock & reset
    input  logic         c_clk_i,
    input  logic         c_rst_ni,
    input  logic         c_clear,

    // Data input interface
    input  logic         port_tvalid_i [PORT_QTY],
    input  logic [63:0]  port_tdata_i  [PORT_QTY],

    // Data output interface
    output logic [15:0]  port_tnew_o,
    output logic [63:0]  port_tdata_o  [PORT_QTY]
);

    localparam int ZFP = 16 - PORT_QTY; // Zero-fill width for port_tnew_o.

    logic [63:0]        port_dt_r   [PORT_QTY];
    logic [PORT_QTY-1:0] port_dt_new;

    generate
        for (genvar ind = 0; ind < PORT_QTY; ind = ind + 1) begin : g_port_reg
            always_ff @(posedge c_clk_i) begin
                if (!c_rst_ni) begin
                    port_dt_r[ind]   <= '0;
                    port_dt_new[ind] <= 1'b0;
                end else begin
                    if (port_tvalid_i[ind]) begin
                        port_dt_r[ind]   <= port_tdata_i[ind];
                        port_dt_new[ind] <= 1'b1;
                    end else if (c_clear) begin
                        port_dt_new[ind] <= 1'b0;
                    end
                end
            end
        end
    endgenerate

    assign port_tnew_o  = {{ZFP{1'b0}}, port_dt_new};
    assign port_tdata_o = port_dt_r;

endmodule
