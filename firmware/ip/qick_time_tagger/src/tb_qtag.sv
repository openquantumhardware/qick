///////////////////////////////////////////////////////////////////////////////
//  FERMI RESEARCH LAB
///////////////////////////////////////////////////////////////////////////////
//  Author         : mdife
///////////////////////////////////////////////////////////////////////////////

`timescale 1ns/10ps

import axi_vip_pkg::*;
import axi_mst_0_pkg::*;

`define T_C_CLK         2 // 1.66 // Half Clock Period for Simulation
`define T_ADC_CLK       1 // 1.66 // Half Clock Period for Simulation
`define T_PS_CLK        10  // Half Clock Period for Simulation

`define DMA_RD        1 
`define PROC_RD       1 
`define CMP_SLOPE     1 
`define CMP_INTER     4 
`define SMP_DW        16 
`define SMP_CK        8  
`define TAG_FIFO_AW   10 
`define SMP_STORE     0  
`define SMP_FIFO_AW   10 
`define DEBUG         2  
   

module tb_qick_time_tagger();

///////////////////////////////////////////////////////////////////////////////

// VIP Agent
axi_mst_0_mst_t 	axi_mst_0_agent;
xil_axi_prot_t  prot        = 0;
xil_axi_resp_t  resp;

// Signals
reg c_clk, adc_clk, ps_clk;
reg rst_ni;
reg[31:0]       data_wr     = 32'h12345678;

integer t;
real           x0, x1, x2, x3,x4, x5, x6, x7 ;
reg [`SMP_DW-1:0] y0, y1, y2, y3,y4, y5, y6, y7 ;
reg [`SMP_DW*`SMP_CK-1:0] adc_dt, adc_s_axis_tdata_i ;

//AXI-LITE
wire [7:0]             s_axi_awaddr  ;
wire [2:0]             s_axi_awprot  ;
wire                   s_axi_awvalid ;
wire                   s_axi_awready ;
wire [31:0]            s_axi_wdata   ;
wire [3:0]             s_axi_wstrb   ;
wire                   s_axi_wvalid  ;
wire                   s_axi_wready  ;
wire  [1:0]            s_axi_bresp   ;
wire                   s_axi_bvalid  ;
wire                   s_axi_bready  ;
wire [7:0]             s_axi_araddr  ;
wire [2:0]             s_axi_arprot  ;
wire                   s_axi_arvalid ;
wire                   s_axi_arready ;
wire  [31:0]           s_axi_rdata   ;
wire  [1:0]            s_axi_rresp   ;
wire                   s_axi_rvalid  ;
wire                   s_axi_rready  ;


//////////////////////////////////////////////////////////////////////////
//  CLK Generation
initial begin
  c_clk = 1'b0;
  forever # (`T_C_CLK) c_clk = ~c_clk;
end
initial begin
  adc_clk = 1'b0;
  forever # (`T_ADC_CLK) adc_clk = ~adc_clk;
end
initial begin
  ps_clk = 1'b0;
  forever # (`T_PS_CLK) ps_clk = ~ps_clk;
end

reg pulse_f;
reg dma_m_axis_tready_i;


always @ (posedge ps_clk, negedge rst_ni) begin
   if ( !rst_ni  )       
      dma_m_axis_tready_i = 1'b1;
   else  
      if ( dma_m_axis_tvalid_o) begin 
         #0.5;
         dma_m_axis_tready_i = 0;
         #100;
      end else begin
         #0.5;         
         dma_m_axis_tready_i = 1'b1;
      end 
end

always_ff @ (posedge adc_clk, negedge rst_ni) begin
   if ( !rst_ni  )       pulse_f   <= 1'b0;
   else  
      if ( pulse_f2 | rdy_a) pulse_f <= 1'b1; 
      if ( pulse_f ) pulse_f <= 1'b0; 
end


reg         qtag_en_i ;
reg [4 :0]  qtag_op_i ;
reg [31:0]  qtag_dt1_i, qtag_dt2_i, qtag_dt3_i, qtag_dt4_i ;

wire        qtag_rdy_o, qtag_vld_o, qtag_flag_o ;
wire [31:0] qtag_dt1_o, qtag_dt2_o;

// Register ADDRESS
parameter QTT_CTRL     = 0 * 4 ;
parameter QTT_CFG      = 1 * 4 ;
parameter QTT_ADDR     = 2 * 4 ;
parameter QTT_LEN      = 3 * 4 ;
parameter AXI_DT1      = 4 * 4 ;
parameter AXI_DT2      = 5 * 4 ;
parameter AXI_DT3      = 6 * 4 ;
parameter AXI_DT4      = 7 * 4 ;
parameter QTT_DT1      = 9 * 4 ;
parameter QTT_DT2      = 10* 4 ;
parameter QTT_DT3      = 11* 4 ;
parameter QTT_DT4      = 12* 4 ;
parameter QTT_STATUS   = 14* 4 ;
parameter QTT_DEBUG    = 15* 4 ;



pulse_cdc pulse_f2s (
   .clk_a_i   ( adc_clk ) ,
   .rst_a_ni  ( rst_ni ) ,
   .pulse_a_i ( pulse_f ) ,
   .rdy_a_o   ( rdy_a ) ,
   .clk_b_i   ( ps_clk ) ,
   .rst_b_ni  ( rst_ni ) ,
   .pulse_b_o ( pulse_slow ) );

pulse_cdc pulse_s2f (
   .clk_a_i   ( ps_clk ) ,
   .rst_a_ni  ( rst_ni ) ,
   .pulse_a_i ( pulse_slow ) ,
   .rdy_a_o   (  ) ,
   .clk_b_i   ( adc_clk ) ,
   .rst_b_ni  ( rst_ni ) ,
   .pulse_b_o ( pulse_f2 ) );
//////////////////////////////////////////////////////////////////////////
//  AXI AGENT
axi_mst_0 axi_mst_0_i (
   .aclk          ( ps_clk          ),
   .aresetn       ( rst_ni          ),
   .m_axi_araddr  ( s_axi_araddr    ),
   .m_axi_arprot  ( s_axi_arprot    ),
   .m_axi_arready ( s_axi_arready   ),
   .m_axi_arvalid ( s_axi_arvalid   ),
   .m_axi_awaddr  ( s_axi_awaddr    ),
   .m_axi_awprot  ( s_axi_awprot    ),
   .m_axi_awready ( s_axi_awready   ),
   .m_axi_awvalid ( s_axi_awvalid   ),
   .m_axi_bready  ( s_axi_bready    ),
   .m_axi_bresp   ( s_axi_bresp     ),
   .m_axi_bvalid  ( s_axi_bvalid    ),
   .m_axi_rdata   ( s_axi_rdata     ),
   .m_axi_rready  ( s_axi_rready    ),
   .m_axi_rresp   ( s_axi_rresp     ),
   .m_axi_rvalid  ( s_axi_rvalid    ),
   .m_axi_wdata   ( s_axi_wdata     ),
   .m_axi_wready  ( s_axi_wready    ),
   .m_axi_wstrb   ( s_axi_wstrb     ),
   .m_axi_wvalid  ( s_axi_wvalid    ));


axi_qick_time_tagger # (
   .DMA_RD       ( `DMA_RD      ) ,
   .PROC_RD      ( `PROC_RD      ) ,
   .CMP_SLOPE    ( `CMP_SLOPE      ) ,
   .CMP_INTER    ( `CMP_INTER      ) ,
   .TAG_FIFO_AW  ( `TAG_FIFO_AW ) ,
   .SMP_DW       ( `SMP_DW      ) ,
   .SMP_CK       ( `SMP_CK      ) ,
   .SMP_STORE    ( `SMP_STORE   ) ,
   .SMP_FIFO_AW  ( `SMP_FIFO_AW ) ,
   .DEBUG        ( `DEBUG       )  
) axi_qick_time_tagger (
   .c_clk               ( c_clk               ),
   .c_aresetn           ( rst_ni              ),
   .adc_clk             ( adc_clk             ),
   .adc_aresetn         ( rst_ni              ),
   .ps_clk              ( ps_clk              ),
   .ps_aresetn          ( rst_ni              ),
   .qtag_en_i           ( qtag_en_i           ),
   .qtag_op_i           ( qtag_op_i           ),
   .qtag_dt1_i          ( qtag_dt1_i          ),
   .qtag_dt2_i          ( qtag_dt2_i          ),
   .qtag_dt3_i          ( qtag_dt3_i          ),
   .qtag_dt4_i          ( qtag_dt4_i          ),
   .qtag_rdy_o          ( qtag_rdy_o          ),
   .qtag_dt1_o          ( qtag_dt1_o          ),
   .qtag_dt2_o          ( qtag_dt2_o          ),
   .qtag_vld_o          ( qtag_vld_o          ),
   .qtag_flag_o         ( qtag_flag_o         ),
   .s_axi_awaddr        ( s_axi_awaddr        ),
   .s_axi_awprot        ( s_axi_awprot        ),
   .s_axi_awvalid       ( s_axi_awvalid       ),
   .s_axi_awready       ( s_axi_awready       ),
   .s_axi_wdata         ( s_axi_wdata         ),
   .s_axi_wstrb         ( s_axi_wstrb         ),
   .s_axi_wvalid        ( s_axi_wvalid        ),
   .s_axi_wready        ( s_axi_wready        ),
   .s_axi_bresp         ( s_axi_bresp         ),
   .s_axi_bvalid        ( s_axi_bvalid        ),
   .s_axi_bready        ( s_axi_bready        ),
   .s_axi_araddr        ( s_axi_araddr        ),
   .s_axi_arprot        ( s_axi_arprot        ),
   .s_axi_arvalid       ( s_axi_arvalid       ),
   .s_axi_arready       ( s_axi_arready       ),
   .s_axi_rdata         ( s_axi_rdata         ),
   .s_axi_rresp         ( s_axi_rresp         ),
   .s_axi_rvalid        ( s_axi_rvalid        ),
   .s_axi_rready        ( s_axi_rready        ),
   .adc_s_axis_tvalid_i ( adc_s_axis_tvalid_i ),
   .adc_s_axis_tdata_i  ( adc_s_axis_tdata_i  ),
   .adc_s_axis_tready_o ( adc_s_axis_tready_o ),
   .dma_m_axis_tready_i ( dma_m_axis_tready_i ),
   .dma_m_axis_tvalid_o ( dma_m_axis_tvalid_o ),
   .dma_m_axis_tdata_o  ( dma_m_axis_tdata_o  ),
   .dma_m_axis_tlast_o  ( dma_m_axis_tlast_o  ),
   .qtt_do              (                ));
   
reg [15:0] threshold;
wire[31:0]  time_ck_s0 , time_ck_s1 , time_ck_s2 , time_ck_s3 ;
wire[2:0] time_adc_s0, time_adc_s1, time_adc_s2, time_adc_s3;
wire[3:0] time_int_s0, time_int_s1, time_int_s2, time_int_s3;

   
thr_cmp CMP_0 (
   .clk_i         ( adc_clk ) ,
   .rst_ni        ( rst_ni ) ,
   .cfg_filter_i  ( 0 ) ,
   .cfg_slope_i   ( 0 ) ,
   .cfg_inter_i   ( 1 ), 
   .th_i          ( threshold ) ,
   .dt_i          ( adc_dt ) ,
   .trig_time_ck_o     (  time_ck_s0 ) ,
   .trig_time_adc_o    ( time_adc_s0 ) ,
   .trig_time_int_o    ( time_int_s0 ) ,
   .trig_vld_o    ( time_vld_s0 ) );
thr_cmp CMP_1 (
   .clk_i         ( adc_clk ) ,
   .rst_ni        ( rst_ni ) ,
   .cfg_filter_i  ( 0 ) ,
   .cfg_slope_i   ( 1 ) ,
   .cfg_inter_i   ( 0 ), 
   .th_i          ( threshold ) ,
   .dt_i          ( adc_dt ) ,
   .trig_time_ck_o     (  time_ck_s1 ) ,
   .trig_time_adc_o    ( time_adc_s1 ) ,
   .trig_time_int_o    ( time_int_s1 ) ,
   .trig_vld_o    ( time_vld_s1 ) );
thr_cmp CMP_2 (
   .clk_i         ( adc_clk ) ,
   .rst_ni        ( rst_ni ) ,
   .cfg_filter_i  ( 1 ) ,
   .cfg_slope_i   ( 0 ) ,
   .cfg_inter_i   ( 1 ), 
   .th_i          ( threshold ) ,
   .dt_i          ( adc_dt ) ,
   .trig_time_ck_o     (  time_ck_s2 ) ,
   .trig_time_adc_o    ( time_adc_s2 ) ,
   .trig_time_int_o    ( time_int_s2 ) ,
   .trig_vld_o    ( time_vld_s2 ) );
thr_cmp CMP_3 (
   .clk_i         ( adc_clk ) ,
   .rst_ni        ( rst_ni ) ,
   .cfg_filter_i  ( 1 ) ,
   .cfg_slope_i   ( 1 ) ,
   .cfg_inter_i   ( 0 ), 
   .th_i          ( threshold ) ,
   .dt_i          ( adc_dt ) ,
   .trig_time_ck_o     (  time_ck_s3 ) ,
   .trig_time_adc_o    ( time_adc_s3 ) ,
   .trig_time_int_o    ( time_int_s3 ) ,
   .trig_vld_o    ( time_vld_s3 ) );

assign adc_s_axis_tvalid_i = 1'b1;
assign adc_s_axis_tdata_i  = adc_dt;

integer INTER, rand_mult;
reg p_start;

initial begin
   rand_mult = 0;
   START_SIMULATION();
   // TEST_AXI () ;
   // TEST_CMD ();
   WRITE_AXI( QTT_CFG ,  5); // SET DEAD TIME
   WRITE_AXI( AXI_DT1 ,  30);
   WRITE_AXI( QTT_CTRL ,  1);

   WRITE_AXI( QTT_CFG ,  4); // SET THR
   WRITE_AXI( AXI_DT1 ,  3630);
   WRITE_AXI( QTT_CTRL ,  1);

   for (INTER=0; INTER<=7; INTER=INTER+1) begin
      for (AMP=4; AMP<=16; AMP=AMP*2) begin
         WRITE_AXI( QTT_CFG  , INTER*32+1);  
         WRITE_AXI( QTT_CTRL , 1 );
         SIM_RANDOM();
         SIM_PULSES(); 
      end
   WRITE_AXI( QTT_CFG ,  0); // DISARM
   WRITE_AXI( QTT_CTRL ,  1);
   end

//Micro POP
    qtag_en_i     = 1;   
    qtag_op_i     = 2;   
   @ (posedge c_clk); #0.1;
    qtag_en_i     = 0;   
    qtag_op_i     = 2;   

   @ (posedge c_clk); #0.1;
   WRITE_AXI( QTT_LEN  ,  10);
   WRITE_AXI( QTT_CTRL ,  4); // TAG READ
   #5000;
   @ (posedge c_clk); #0.1;
   WRITE_AXI( QTT_LEN  ,  10);
   WRITE_AXI( QTT_CTRL ,  4); // TAG READ

//DMA POP
   WRITE_AXI( QTT_CFG ,  2); // POP
   WRITE_AXI( QTT_CTRL ,  1);
//DMA POP
   WRITE_AXI( QTT_CFG ,  2); // POP
   WRITE_AXI( QTT_CTRL ,  1);
//DMA POP
   WRITE_AXI( QTT_CFG ,  2); // POP
   WRITE_AXI( QTT_CTRL ,  1);

   WRITE_AXI( QTT_CFG ,  1); // ARM
   WRITE_AXI( QTT_CTRL ,  1);

   WRITE_AXI( QTT_CFG ,  7); // RESET
   WRITE_AXI( QTT_CTRL ,  1);

end

task START_SIMULATION (); begin
    $display("START SIMULATION");
    // Create agents.
    axi_mst_0_agent 	= new("axi_mst_0 VIP Agent",tb_qick_time_tagger.axi_mst_0_i.inst.IF);
    // Set tag for agents.
    axi_mst_0_agent.set_agent_tag	("axi_mst_0 VIP");
    // Start agents.
    axi_mst_0_agent.start_master();
   rst_ni   = 1'b0;
    qtag_en_i     = 0;   
    qtag_op_i     = 0;   
    qtag_dt1_i    = 0;   
    qtag_dt2_i    = 0;   
    qtag_dt3_i    = 0;   
    qtag_dt4_i    = 0; 
    p_start   = 0;
    adc_dt = 0;

   @ (posedge ps_clk); #0.1;
   rst_ni            = 1'b1;
   @ (posedge adc_clk); #0.1;
    p_start   = 1;
   @ (posedge adc_clk); #0.1;
    p_start   = 0;

   end
endtask

task WRITE_AXI(integer PORT_AXI, DATA_AXI); begin
   @ (posedge ps_clk); #0.1;
   axi_mst_0_agent.AXI4LITE_WRITE_BURST(PORT_AXI, prot, DATA_AXI, resp);
   end
endtask


task TEST_AXI (); begin
   $display("-----Writting AXI ");
   WRITE_AXI( QTT_CTRL ,  1);
   WRITE_AXI( QTT_CFG  ,  2);
   WRITE_AXI( QTT_ADDR ,  3);
   WRITE_AXI( QTT_LEN  ,  4);
   WRITE_AXI( AXI_DT1  ,  5);
   WRITE_AXI( AXI_DT2  ,  6);
   WRITE_AXI( AXI_DT3  ,  7);
   WRITE_AXI( AXI_DT4  ,  8);
end
endtask

task TEST_CMD (); begin
   $display("-----Writting AXI ");
   WRITE_AXI( QTT_CTRL ,  1); // RST

   WRITE_AXI( QTT_CFG ,  1); // ARM
   WRITE_AXI( QTT_CTRL ,  2); // CMD

   WRITE_AXI( QTT_CFG ,  2); // DISARM
   WRITE_AXI( QTT_CTRL ,  2); // CMD

   WRITE_AXI( QTT_CFG ,  8); // SET_THR
   WRITE_AXI( AXI_DT1 ,  456); 
   WRITE_AXI( QTT_CTRL ,  2); // CMD

   WRITE_AXI( QTT_CFG ,  9); // SET_DEAD_TIME
   WRITE_AXI( AXI_DT1 ,  123); 
   WRITE_AXI( QTT_CTRL ,  2); // CMD

   WRITE_AXI( QTT_ADDR ,  3);
   WRITE_AXI( QTT_LEN  ,  10);
   WRITE_AXI( QTT_CTRL ,  4); // TAG READ
   WRITE_AXI( QTT_CTRL ,  8); // SMP READ
end
endtask

task SIM_QTT(); begin
   $display("SIM TAGGER");
   for (t=0; t<=360; t=t+1) begin
      @ (posedge adc_clk); #0.1;
      x0 = ( (8*t)+0 ) * (22.0/7.0) / 180/4;
      x1 = ( (8*t)+1 ) * (22.0/7.0) / 180/4;
      x2 = ( (8*t)+2 ) * (22.0/7.0) / 180/4;
      x3 = ( (8*t)+3 ) * (22.0/7.0) / 180/4;
      x4 = ( (8*t)+4 ) * (22.0/7.0) / 180/4;
      x5 = ( (8*t)+5 ) * (22.0/7.0) / 180/4;
      x6 = ( (8*t)+6 ) * (22.0/7.0) / 180/4;
      x7 = ( (8*t)+7 ) * (22.0/7.0) / 180/4;
      y0 = 255*$sin(0.5*x0) + 255*$sin(3*x0) + 511*$sin(2*x0);
      y1 = 255*$sin(0.5*x1) + 255*$sin(3*x1) + 511*$sin(2*x1);
      y2 = 255*$sin(0.5*x2) + 255*$sin(3*x2) + 511*$sin(2*x2);
      y3 = 255*$sin(0.5*x3) + 255*$sin(3*x3) + 511*$sin(2*x3);
      y4 = 255*$sin(0.5*x4) + 255*$sin(3*x4) + 511*$sin(2*x4);
      y5 = 255*$sin(0.5*x5) + 255*$sin(3*x5) + 511*$sin(2*x5);
      y6 = 255*$sin(0.5*x6) + 255*$sin(3*x6) + 511*$sin(2*x6);
      y7 = 255*$sin(0.5*x7) + 255*$sin(3*x7) + 511*$sin(2*x7);
      adc_dt = {y7, y6, y5, y4, y3, y2, y1, y0};   
   end
end
endtask

integer AMP;


task SIM_PULSES(); begin
   for (t=0; t<5; t=t+1) begin
      @ (posedge adc_clk); #0.1;
      //x = (t)* (22.0/7.0)/20;
      //y = $sin(x) ;
      //yd = y *1000*AMP+($random %100);
      x0 = ( (8*t)+0 ) * (22.0/7.0) / 10/8;
      x1 = ( (8*t)+1 ) * (22.0/7.0) / 10/8;
      x2 = ( (8*t)+2 ) * (22.0/7.0) / 10/8;
      x3 = ( (8*t)+3 ) * (22.0/7.0) / 10/8;
      x4 = ( (8*t)+4 ) * (22.0/7.0) / 10/8;
      x5 = ( (8*t)+5 ) * (22.0/7.0) / 10/8;
      x6 = ( (8*t)+6 ) * (22.0/7.0) / 10/8;
      x7 = ( (8*t)+7 ) * (22.0/7.0) / 10/8;
      y0 = $sin(x0)*1000*AMP+($random %10)*rand_mult;
      y1 = $sin(x1)*1000*AMP+($random %10)*rand_mult;
      y2 = $sin(x2)*1000*AMP+($random %10)*rand_mult;
      y3 = $sin(x3)*1000*AMP+($random %10)*rand_mult;
      y4 = $sin(x4)*1000*AMP+($random %10)*rand_mult;
      y5 = $sin(x5)*1000*AMP+($random %10)*rand_mult;
      y6 = $sin(x6)*1000*AMP+($random %10)*rand_mult;
      y7 = $sin(x7)*1000*AMP+($random %10)*rand_mult;
      adc_dt = {y7, y6, y5, y4, y3, y2, y1, y0};   

   end
   for (t=0; t<25; t=t+1) begin
      @ (posedge adc_clk); #0.1;
      //x = (t)* (22.0/7.0)/100;
      //y = $cos(x);
      //yd = y *1000*AMP+($random %100);
      x0 = ( (8*t)+0 ) * (22.0/7.0) / 50/8;
      x1 = ( (8*t)+1 ) * (22.0/7.0) / 50/8;
      x2 = ( (8*t)+2 ) * (22.0/7.0) / 50/8;
      x3 = ( (8*t)+3 ) * (22.0/7.0) / 50/8;
      x4 = ( (8*t)+4 ) * (22.0/7.0) / 50/8;
      x5 = ( (8*t)+5 ) * (22.0/7.0) / 50/8;
      x6 = ( (8*t)+6 ) * (22.0/7.0) / 50/8;
      x7 = ( (8*t)+7 ) * (22.0/7.0) / 50/8;
      y0 = $cos(x0)*1000*AMP+($random %10);
      y1 = $cos(x1)*1000*AMP+($random %10);
      y2 = $cos(x2)*1000*AMP+($random %10);
      y3 = $cos(x3)*1000*AMP+($random %10);
      y4 = $cos(x4)*1000*AMP+($random %10);
      y5 = $cos(x5)*1000*AMP+($random %10);
      y6 = $cos(x6)*1000*AMP+($random %10);
      y7 = $cos(x7)*1000*AMP+($random %10);
      adc_dt = {y7, y6, y5, y4, y3, y2, y1, y0};
   end
   for (t=0; t<20; t=t+1) begin
      @ (posedge adc_clk); #0.1;
      y0 = ($random %100);
      y1 = ($random %100);
      y2 = ($random %100);
      y3 = ($random %100);
      y4 = ($random %100);
      y5 = ($random %100);
      y6 = ($random %100);
      y7 = ($random %100);
      adc_dt = {y7, y6, y5, y4, y3, y2, y1, y0};
   end
      adc_dt = 0;
end
endtask


task SIM_RANDOM(); begin
   for (t=0; t<5; t=t+1) begin
      @ (posedge adc_clk); #0.1;
      y0 = ($random %100);
      y1 = ($random %100);
      y2 = ($random %100);
      y3 = ($random %100);
      y4 = ($random %100);
      y5 = ($random %100);
      y6 = ($random %100);
      y7 = ($random %100);
      adc_dt = {y7, y6, y5, y4, y3, y2, y1, y0};
   end
end
endtask

endmodule




