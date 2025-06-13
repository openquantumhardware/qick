///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
//
// Fermi Fordward Alliance LLC
//
// Module: wide_en_signal.sv
// Project: UTILS
// Description: Enable pulse generator for a wide enable signal. 
//              It serves as clock domain crossing (CDC) logic. 
//
// Change history: 05/15/25 - Created by @lharnaldi
//
///////////////////////////////////////////////////////////////////////////////
module wide_en_signal(
    input logic  i_clk    ,
    input logic  i_rstn   ,
    input logic  i_en     ,
    output logic o_en 
);

 logic en_strobe;

    synchronizer#(
       .NB(1)
       ) u_sync(
          .i_clk      ( i_clk        ),
          .i_rstn     ( i_rstn       ),
          .i_async    ( i_en         ),
          .o_sync     ( en_strobe    )
          );
          
    rising_edge_det u_edge_detect(
       .i_clk      ( i_clk        ),
       .i_rstn     ( i_rstn       ),
       .i_strobe   ( en_strobe    ),
       .o_pulse    ( o_en         )
       );

endmodule
