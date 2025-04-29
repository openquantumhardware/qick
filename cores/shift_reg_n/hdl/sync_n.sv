///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
//
// Fermi Fordward Alliance LLC
//
// Module: sync_n.sv
// Project: QICK
// Description: Synchronization registers. It serves as clock 
//              domain crossing logic. Minimum value of N=2.
//              It is a parametrizable shift register. 
//              Basic CDC can be accomplished setting N=2
//
//
// Change history: 04/27/25 - Created by @lharnaldi
//
///////////////////////////////////////////////////////////////////////////////
module sync_n #(
    parameter N = 8 //number of stages
)(
    input logic  i_clk ,
    input logic  i_rstn,
    input logic  i_data,
    output logic o_data
);

    logic [N-1:0] d_r;
    logic [N-1:0] d_n;

    always_ff @ (posedge i_clk) begin
     if(!i_rstn) begin
       d_r <= '0;
     end else begin
       d_r <= d_n;
     end
    end

    assign d_n    = {d_r[N-2:0],i_data};
    assign o_data = d_r[N-1];

endmodule

