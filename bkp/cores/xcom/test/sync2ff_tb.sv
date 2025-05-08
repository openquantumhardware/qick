module sync2ff_tb;

 //inputs
 logic a, b, select;
 //outputs
 logic y;

 sync2ff #(.NB(1'b1))
 DUT(
  .i_d0(a),
  .i_d1(b),
  .i_s(select),
  .o_y(y)
 );

 //initialize inputs

 initial begin
//simulation files dumped to the test_2_1mux file
  $dumpfile("test_2_1mux.vcd");
  $dumpvars(0,mux2_tb);
  a=1'b0;b=1'b0; select=1'b0;
  #5 a=1'b1; 
  #5 select = 1'b1;
  #5 b=1'b1;
  #5 a=1'b0;
  #5 $finish;
 end
endmodule
