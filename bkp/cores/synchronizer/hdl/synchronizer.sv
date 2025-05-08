///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
//
// Fermi Fordward Alliance LLC
//
// Module: sync_n.sv
// Project: QICK
// Description: 2 FF, 1-bit data synchronizer. 
//              It serves as clock domain crossing (CDC) logic. 
//
// Change history: 04/29/25 - Created by @lharnaldi
//
///////////////////////////////////////////////////////////////////////////////
module synchronizer #(
   //number of bits in data
   parameter NB = 1
)(
    input logic           i_clk ,
    input logic           i_rstn,
    input logic  [NB-1:0] i_async,
    output logic [NB-1:0] o_sync
);

    logic [NB-1:0] meta_r, meta_n;
    logic [NB-1:0] sync_r, sync_n;

    //two D FFs
    always_ff @ (posedge i_clk) begin
     if(!i_rstn) begin
       meta_r <= '0;
       sync_r <= '0;
     end else begin
       meta_r <= meta_n;
       sync_r <= sync_n;
     end
    end

    //next-state logic
    assign meta_n = i_async;
    assign sync_n = meta_r;
    
    //output logic
    assign o_sync = sync_r;

endmodule

