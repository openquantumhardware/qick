module mux2 #(
  parameter NB_DATA = 8
)(
  input logic [NB_DATA-1:0] i_d0, i_d1,
  input logic i_s,
  output logic [NB_DATA-1:0] o_y
  );
 
  assign o_y = i_s ? i_d1 : i_d0;
  
endmodule
