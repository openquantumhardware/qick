///////////////////////////////////////////////////////////////////////////////
//  FERMI RESEARCH LAB
///////////////////////////////////////////////////////////////////////////////
//  Author         : mdife
///////////////////////////////////////////////////////////////////////////////

`timescale 1ns/10ps

`define HP_PS_CLK        50  // Half Clock Period for Simulation
`define HP_C_CLK         5   // Half Clock Period for Simulation
`define HP_T_CLK         2   // Half Clock Period for Simulation

localparam DEBUG    =     1;  // Debugging

module tb_enc();

// Signals
///////////////////////////////////////////////////////////////////////////////
reg c_clk, t_clk, ps_clk;
reg rst_n;
reg sync;
//  CLK Generation
//////////////////////////////////////////////////////////////////////////
initial begin
  ps_clk = 1'b0;
  forever # (`HP_PS_CLK) ps_clk = ~ps_clk;
end
initial begin
  c_clk = 1'b0;
  forever # (`HP_C_CLK) c_clk = ~c_clk;
end
initial begin
  t_clk = 1'b0;
  forever # (`HP_T_CLK) t_clk = ~t_clk;
end
//  Other Periodical Signals
//////////////////////////////////////////////////////////////////////////
initial begin
  sync = 1'b0;
  forever # (1000) sync = ~sync;
end



reg [SMP_DW:0] data ;
wire [SMP_DW*SMP_CK-1:0] data_v ;

reg [SMP_DW-1:0] data_0,data_1, data_2, data_3, data_4,data_5, data_6, data_7 ;

assign data_7 = data[SMP_DW-1:0] ;
assign data_6 = data[SMP_DW-1:0] +1;
assign data_5 = data[SMP_DW-1:0] +2;
assign data_4 = data[SMP_DW-1:0] +3;
assign data_3 = data[SMP_DW-1:0] +4;
assign data_2 = data[SMP_DW-1:0] +8;
assign data_1 = data[SMP_DW-1:0] +10;
assign data_0 = data[SMP_DW-1:0] +13;

assign data_v = {data_7, data_6, data_5, data_4,data_3, data_2, data_1, data_0};

parameter EFF_DW = 14 ; //Effective DAta Width
parameter SMP_DW = 16 ;
parameter SMP_CK = 8 ;
parameter DW = $clog2(SMP_CK) ; 



///////////////////////////////////////////////
// DESIGN
//////////////////////////////////////////
assign clk_i = c_clk;
assign rst_ni = rst_n;

/// Time Counter 
//////////////////////////////////////////////////////////////////////////
 // Clk is 300Mhz, Deat ime 100ns > 32  

reg [28:0] time_cnt;
always_ff @(posedge clk_i)
   if(!rst_ni) begin
      time_cnt  <= 0;
   end else begin 
      if (cmp_event & !inhibit)
         inhibit        <= 1'b1;
      else if (inhibit & !dead_time_hit) 
         time_cnt  <= dead_time_cnt+1'b1;
      else if (dead_time_hit) begin
         inhibit        <= 1'b0;
         time_cnt  <= 1'b1;
      end
   end

assign trig = cmp_event & !inhibit ;



wire [SMP_CK-1:0] cmp_unary_dt;

threshold_comparator # (
   .EFF_DW     ( EFF_DW ) ,
   .SMP_DW     ( SMP_DW ) ,
   .SMP_CK     ( SMP_CK )  
 ) DUT_thc (
   .clk_i       ( c_clk       ) ,
   .rst_ni      ( rst_n      ) ,
   .en_i        ( en_i        ) ,
   .concat_dt_i ( data_v  ) ,
   .th_i        (  th_i      ) ,
   .cmp_o       ( cmp_unary_dt       ) , 
   .vld_o       ( cmp_event      ) );

/// Priority Encoder 
//////////////////////////////////////////////////////////////////////////
reg [DW-1:0] cmp_bin_dt ;

priority_encoder  # (
   .DW  (DW)
) DUT (
   .clk_i         ( c_clk    ) ,
   .rst_ni        ( rst_n   ) ,
   .one_hot_dt_i  ( cmp_unary_dt  ) ,
   .bin_dt_o      ( cmp_bin_dt ) ,
   .vld_o         ( vld_o    ) );

/// Dead Time 
//////////////////////////////////////////////////////////////////////////
 // Clk is 300Mhz, Deat ime 100ns > 32  
assign clk_i = c_clk;
assign rst_ni = rst_n;
reg [9:0] dead_time_cnt, dead_time_lenght;
reg inhibit;
assign dead_time_hit = dead_time_cnt == dead_time_lenght;
always_ff @(posedge clk_i)
   if(!rst_ni) begin
      dead_time_cnt  <= 0;
      inhibit        <= 0;
   end else begin 
      if (cmp_event & !inhibit)
         inhibit        <= 1'b1;
      else if (inhibit & !dead_time_hit) 
         dead_time_cnt  <= dead_time_cnt+1'b1;
      else if (dead_time_hit) begin
         inhibit        <= 1'b0;
         dead_time_cnt  <= 1'b1;
      end
   end

assign trig = cmp_event & !inhibit ;





   
initial begin
   START_SIMULATION();
   SIM_ENC();

end
reg [EFF_DW-1:0]th_i;
reg en_i;

integer i;

task SIM_ENC(); begin
   $display("SIM TX");
   # (5 * `HP_C_CLK);

   @ (posedge c_clk); #0.1;
   
   for (i=0;i<=2**EFF_DW;i=i+1) begin
      @ (posedge tt );
      @ (posedge c_clk); #0.1;
      data = i;
   end
end
endtask

assign tt = trig | ps_clk;

task START_SIMULATION (); begin
   $display("START SIMULATION");
// Reset
   rst_n    = 1'b0;
   en_i     = 1'b0;
   th_i   = 15;
   dead_time_lenght = 5;
   data = 0;   
   #100;
   @ (posedge ps_clk); #0.1;
   rst_n    = 1'b1;
   
   en_i = 1'b1;
   
   end
endtask


endmodule




