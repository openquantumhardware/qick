//////4/////////////////////////////////////////////////////////////////////////
//  FERMI RESEARCH LAB
///////////////////////////////////////////////////////////////////////////////
//  Author         : mdife
///////////////////////////////////////////////////////////////////////////////

`timescale 1ns/10ps

`define HP_CLK         2   // Half Clock Period for Simulation

module tb_qtt();

// Signals
///////////////////////////////////////////////////////////////////////////////
reg clk_i;
reg rst_ni;

//  CLK Generation
//////////////////////////////////////////////////////////////////////////
initial begin
  clk_i = 1'b0;
  forever # (`HP_CLK) clk_i = ~clk_i;
end



   
parameter EFF_DW = 14 ; //Effective DAta Width
parameter SMP_DW = 16 ;
parameter SMP_CK = 8 ;

wire        trig_vld;
wire [2:0]  trig_inter;
wire [28:0] trig_time;
wire [31:0] trig_time_tag;

integer t;
real           x, y;
real           x0, x1, x2, x3,x4, x5, x6, x7 ;
reg [SMP_DW-1:0] y0, y1, y2, y3,y4, y5, y6, y7 ;
reg [SMP_DW*SMP_CK-1:0] adc_dt ;

reg  [15:0] yd;
wire [17:0] A, D;
reg  [17:0] B;
wire [47:0] C;
wire [47:0] P1, P2;
integer AMP;
assign trig_time_tag = { trig_time, trig_inter };

reg[15:0] THR;

initial begin
   THR=0;
   #10;
   wait (r == 1'b1) ;
   for (THR=100; THR<356; THR=THR+1) begin
      @ (posedge clk_i); #0.1;
      wait (r == 1'b1) ;
   end
end


x_inter #(
   .DW  ( 16 ) ,
   .IW  ( 4 )
) x_inter (
   .clk_i      ( clk_i ) ,
   .rst_ni     ( rst_ni ) ,
   .start_i    ( r ) ,
   .thr_i      ( THR ) ,
   .curr_i     ( 355 ) ,
   .prev_i     ( 100 ) ,
   .ready_o    ( r ) ,
   .x_int_o    ( x_inter_s ) );

wire[15:0] x_inter_s;
   
SmSRmC V2 (
  .CLK(clk_i),  // input wire CLK
  .A(A),      // input wire [17 : 0] A
  .C(C2),      // input wire [47 : 0] C
  .D(D),      // input wire [17 : 0] D
  .P(P2)      // output wire [47 : 0] P
);
wire [47:0] C1, C2;
assign A = {yd[15],yd, 1'b0};
assign D = {yd[15],yd, 1'b0};
assign C1 = { {32{yd[15]}}, yd};
assign C2 = { {31{1'b0}}, B, 1'b0};


initial begin
   START_SIMULATION();
   @ (posedge clk_i); #0.1;
   yd <= 0;
   @ (posedge clk_i); #0.1;
   yd <= 1;
   @ (posedge clk_i); #0.1;
   yd <= 2;
   @ (posedge clk_i); #0.1;
   yd <= 3;
   @ (posedge clk_i); #0.1;
   yd <= 4;
   @ (posedge clk_i); #0.1;
   yd <= 5;
   @ (posedge clk_i); #0.1;
   yd <= 6;
   @ (posedge clk_i); #0.1;
   yd <= 7;
   @ (posedge clk_i); #0.1;
   yd <= 8;
   @ (posedge clk_i); #0.1;
   yd <= 8;
   @ (posedge clk_i); #0.1;
   yd <= 0;
   @ (posedge clk_i); #0.1;

   for (B=100; B<200; B=B+10) begin
      @ (posedge clk_i); #0.1;
      for (AMP=1; AMP<8; AMP=AMP*2) begin
         SIM_QTT();
      for (t=1; t<10; t=t+1) begin
         @ (posedge clk_i); #0.1;
         yd <= ($random %100);
      end
      end
      for (t=1; t<100; t=t+1) begin
         @ (posedge clk_i); #0.1;
         yd <= ($random %100);
      end
   end
   
end

wire tu, td;


reg [SMP_DW:0] cmp_th_i;
reg [7:0] cmp_inh_i;
reg rst_ni;

assign T1 = P1[47];
assign T2 = ~P2[47];


task START_SIMULATION (); begin
   $display("START SIMULATION");
   rst_ni    = 1'b0;
   yd=0;
   AMP = 0;
   B = 1;

   @ (posedge clk_i); #0.1;
   rst_ni    = 1'b1;
   end
endtask

task SIM_QTT(); begin
   $display("SIM TAGGER");
   for (t=0; t<50; t=t+1) begin
      @ (posedge clk_i); #0.1;
      x = (t)* (22.0/7.0)/20;
      y = $sin(x) ;
      yd = y *1000*AMP+($random %100);
   end
   for (t=0; t<50; t=t+1) begin
      @ (posedge clk_i); #0.1;
      x = (t)* (22.0/7.0)/100;
      y = $cos(x);
      yd = y *1000*AMP+($random %100);
   end
      yd = 0;
end
endtask



endmodule




