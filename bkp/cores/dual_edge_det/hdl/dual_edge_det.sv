///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
//
// Fermi Fordward Alliance LLC
//
// Module: sync_n.sv
// Project: UTILS
// Description: Dual edge detection circuit. 
//              It serves as clock domain crossing (CDC) logic. 
//
// Change history: 05/14/25 - Created by @lharnaldi
//
///////////////////////////////////////////////////////////////////////////////
module dual_edge_det(
    input logic  i_clk    ,
    input logic  i_rstn   ,
    input logic  i_strobe ,
    output logic o_pulse
);

    logic delay_r, delay_n;

    always_ff @ (posedge i_clk) begin
     if(!i_rstn) begin
       delay_r <= '0;
     end else begin
       delay_r <= delay_n;
     end
    end

    //next-state logic
    assign delay_n = i_strobe;
    
    //output and decoding logic
    assign o_pulse = delay_r ^ i_strobe;

endmodule
