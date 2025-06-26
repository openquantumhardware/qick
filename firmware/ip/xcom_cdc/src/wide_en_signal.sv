///////////////////////////////////////////////////////////////////////////////                                                                                                               
// vim:set shiftwidth=3 softtabstop=3 expandtab:
//
// Fermi Fordward Alliance LLC
//
// Module: wide_en_signal.sv
// Project: UTILS
// Description: Enable pulse generator for a wide enable signal.
//              It serves as clock domain crossing (CDC) logic.
//              This version is scalable with the DWIDTH parameter.
//
// Change history: 05/15/25 - Created by @lharnaldi
//                 06/26/25 - @lharnaldi Modified to be programmable with DWIDTH
//
///////////////////////////////////////////////////////////////////////////////
module wide_en_signal #(
    parameter DWIDTH = 1               // The width of the enable bus
) (
    input  logic              i_clk,
    input  logic              i_rstn,
    input  logic [DWIDTH-1:0] i_en,    
    output logic [DWIDTH-1:0] o_en    
);
 
    logic [DWIDTH-1:0] en_strobe;
 
    genvar i;
    generate
        for (i = 0; i < DWIDTH; i = i + 1) begin : gen_sync_and_edge_detect
 
            synchronizer #(
                .NB(1) 
            ) u_sync (
                .i_clk      (i_clk),
                .i_rstn     (i_rstn),
                .i_async    (i_en[i]),    
                .o_sync     (en_strobe[i])  
            );
 
            rising_edge_det u_edge_detect (
                .i_clk      (i_clk),
                .i_rstn     (i_rstn),
                .i_strobe   (en_strobe[i]), 
                .o_pulse    (o_en[i])    
            );
 
        end
    endgenerate
 
endmodule

