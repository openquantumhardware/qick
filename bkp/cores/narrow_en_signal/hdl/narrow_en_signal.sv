///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
//
// Fermi Fordward Alliance LLC
//
// Module: narrow_en_signal.sv
// Project: UTILS
// Description: Enable pulse generator for a narrow enable signal. 
//              It serves as clock domain crossing (CDC) logic. 
//
// Change history: 05/15/25 - Created by @lharnaldi
//
///////////////////////////////////////////////////////////////////////////////
module narrow_en_signal(
    input logic  i_clk    ,
    input logic  i_rstn   ,
    input logic  i_en     ,
    output logic o_en 
);

    logic en_strobe;
    logic en_q;
    
    //ad-hoc stretcher
    always_ff @ (posedge i_en, posedge en_strobe) begin
     if( en_strobe ) begin
       en_q <= 1'b0;
     end else begin
       en_q <= 1'b1;
     end
    end

    //slow enable pulse generator
    synchronizer#(
       .NB(32)
       ) u_sync(
          .i_clk      ( i_clk        ),
          .i_rstn     ( i_rstn       ),
          .i_async    ( en_q         ),
          .o_sync     ( en_strobe    )
          );
          
    rising_edge_det u_edge_detect(
       .i_clk      ( i_clk        ),
       .i_rstn     ( i_rstn       ),
       .i_strobe   ( en_strobe    ),
       .o_pulse    ( o_en         )
       );

endmodule
