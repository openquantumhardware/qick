module mux2_tb;

 //inputs
 reg a, b, select;
 //outputs
 wire y;

 mux2 u0_DUT#(
   .WIDTH(1'b1)
   )(
  .d0(a),
  .d1(b),
  .s(select),
  .y(y)
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
