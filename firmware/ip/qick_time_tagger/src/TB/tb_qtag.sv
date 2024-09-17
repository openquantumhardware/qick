///////////////////////////////////////////////////////////////////////////////
//  FERMI RESEARCH LAB
///////////////////////////////////////////////////////////////////////////////
//  Author         : mdife
///////////////////////////////////////////////////////////////////////////////

`timescale 1ns/10ps

import axi_vip_pkg::*;
import axi_mst_0_pkg::*;

`define T_PS_CLK        11  // Half Clock Period for Simulation
`define T_C_CLK         3 // 1.66 // Half Clock Period for Simulation
`define T_ADC_CLK       2 // 1.66 // Half Clock Period for Simulation

`define ADC_QTY       1 
`define DMA_RD        1 
`define PROC_RD       0 
`define CMP_SLOPE     0 
`define CMP_INTER     4 
`define ARM_STORE     1  
`define SMP_STORE     1 
`define TAG_FIFO_AW   19  
`define ARM_FIFO_AW   5
`define SMP_FIFO_AW   15  
`define SMP_DW        16  
`define SMP_CK        8 
`define DEBUG         1  

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
real              x [`SMP_CK];
reg [`SMP_DW-1:0] y [`SMP_CK];
reg [`SMP_DW*`SMP_CK-1:0] adc_dt ;
wire [`SMP_DW*`SMP_CK-1:0] adc0_s_axis_tdata_i, adc1_s_axis_tdata_i, adc2_s_axis_tdata_i, adc3_s_axis_tdata_i ;


assign adc0_s_axis_tdata_i = adc_dt;
assign adc1_s_axis_tdata_i = adc_dt;
assign adc2_s_axis_tdata_i = adc_dt;
assign adc3_s_axis_tdata_i = adc_dt;


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

reg         arm_i;
reg         qtag_en_i ;
reg [4 :0]  qtag_op_i ;
reg [31:0]  qtag_dt1_i, qtag_dt2_i, qtag_dt3_i, qtag_dt4_i ;

wire        qtag_rdy_o, qtag_vld_o, qtag_flag_o ;
wire [31:0] qtag_dt1_o, qtag_dt2_o;

//reg [15:0] threshold;
//wire[31:0]  time_ck_s0 , time_ck_s1 , time_ck_s2 , time_ck_s3 ;
//wire[2:0] time_adc_s0, time_adc_s1, time_adc_s2, time_adc_s3;
//wire[3:0] time_int_s0, time_int_s1, time_int_s2, time_int_s3;


// Register ADDRESS
parameter QTT_CTRL   = 0 * 4 ;
parameter QTT_CFG    = 1 * 4 ;
parameter DMA_CFG    = 2 * 4 ;
parameter AXI_DT1    = 3 * 4 ;
parameter PROC_DT    = 5 * 4 ;
parameter PROC_QTY   = 6 * 4 ;
parameter TAG0_QTY   = 7 * 4 ;
parameter TAG1_QTY   = 8 * 4 ;
parameter TAG2_QTY   = 9 * 4 ;
parameter TAG3_QTY   = 10* 4 ;
parameter SMP_QTY    = 11* 4 ;
parameter ARM_QTY    = 12* 4 ;

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
   .ADC_QTY      ( `ADC_QTY     ) ,
   .DMA_RD       ( `DMA_RD      ) ,
   .PROC_RD      ( `PROC_RD     ) ,
   .CMP_SLOPE    ( `CMP_SLOPE   ) ,
   .CMP_INTER    ( `CMP_INTER   ) ,
   .ARM_STORE    ( `ARM_STORE   ) ,
   .SMP_STORE    ( `SMP_STORE   ) ,
   .TAG_FIFO_AW  ( `TAG_FIFO_AW ) ,
   .ARM_FIFO_AW  ( `ARM_FIFO_AW ) ,
   .SMP_FIFO_AW  ( `SMP_FIFO_AW ) ,
   .SMP_DW       ( `SMP_DW      ) ,
   .SMP_CK       ( `SMP_CK      ) ,
   .DEBUG        ( `DEBUG       ) 
) axi_qick_time_tagger ( 
// Core and AXI CLK & RST
   .c_clk                ( c_clk                )   ,
   .c_aresetn            ( rst_ni               )   ,
   .adc_clk              ( adc_clk              )   ,
   .adc_aresetn          ( rst_ni               )   ,
   .ps_clk               ( ps_clk               )   ,
   .ps_aresetn           ( rst_ni               )   ,
   .arm_i                ( arm_i                )   ,
   .qtag_en_i            ( qtag_en_i            )   ,
   .qtag_op_i            ( qtag_op_i            )   ,
   .qtag_dt1_i           ( qtag_dt1_i           )   ,
   .qtag_dt2_i           ( qtag_dt2_i           )   ,
   .qtag_dt3_i           ( qtag_dt3_i           )   ,
   .qtag_dt4_i           ( qtag_dt4_i           )   ,
   .qtag_rdy_o           ( qtag_rdy_o           )   ,
   .qtag_dt1_o           ( qtag_dt1_o           )   ,
   .qtag_dt2_o           ( qtag_dt2_o           )   ,
   .qtag_vld_o           ( qtag_vld_o           )   ,
   .qtag_flag_o          ( qtag_flag_o          )   ,
   .s_axi_awaddr         ( s_axi_awaddr         )   ,
   .s_axi_awprot         ( s_axi_awprot         )   ,
   .s_axi_awvalid        ( s_axi_awvalid        )   ,
   .s_axi_awready        ( s_axi_awready        )   ,
   .s_axi_wdata          ( s_axi_wdata          )   ,
   .s_axi_wstrb          ( s_axi_wstrb          )   ,
   .s_axi_wvalid         ( s_axi_wvalid         )   ,
   .s_axi_wready         ( s_axi_wready         )   ,
   .s_axi_bresp          ( s_axi_bresp          )   ,
   .s_axi_bvalid         ( s_axi_bvalid         )   ,
   .s_axi_bready         ( s_axi_bready         )   ,
   .s_axi_araddr         ( s_axi_araddr         )   ,
   .s_axi_arprot         ( s_axi_arprot         )   ,
   .s_axi_arvalid        ( s_axi_arvalid        )   ,
   .s_axi_arready        ( s_axi_arready        )   ,
   .s_axi_rdata          ( s_axi_rdata          )   ,
   .s_axi_rresp          ( s_axi_rresp          )   ,
   .s_axi_rvalid         ( s_axi_rvalid         )   ,
   .s_axi_rready         ( s_axi_rready         )   ,
   .adc0_s_axis_tvalid_i ( adc0_s_axis_tvalid_i )   ,
   .adc0_s_axis_tdata_i  ( adc0_s_axis_tdata_i  )   ,
   .adc0_s_axis_tready_o ( adc0_s_axis_tready_o )   ,
   .adc1_s_axis_tvalid_i ( adc1_s_axis_tvalid_i )   ,
   .adc1_s_axis_tdata_i  ( adc1_s_axis_tdata_i  )   ,
   .adc1_s_axis_tready_o ( adc1_s_axis_tready_o )   ,
   .adc2_s_axis_tvalid_i ( adc2_s_axis_tvalid_i )   ,
   .adc2_s_axis_tdata_i  ( adc2_s_axis_tdata_i  )   ,
   .adc2_s_axis_tready_o ( adc2_s_axis_tready_o )   ,
   .adc3_s_axis_tvalid_i ( adc3_s_axis_tvalid_i )   ,
   .adc3_s_axis_tdata_i  ( adc3_s_axis_tdata_i  )   ,
   .adc3_s_axis_tready_o ( adc3_s_axis_tready_o )   ,
   .dma_m_axis_tready_i  ( dma_m_axis_tready_i  )   ,  
   .dma_m_axis_tvalid_o  ( dma_m_axis_tvalid_o  )   ,  
   .dma_m_axis_tdata_o   ( dma_m_axis_tdata_o   )   ,  
   .dma_m_axis_tlast_o   ( dma_m_axis_tlast_o   )   ,  
   .qtt_do               ( qtt_do               )
);

integer FILTER, SLOPE, INTER, SMP_NUM, rand_mult, tmp;
reg p_start;


initial begin
   rand_mult = 0;
   START_SIMULATION();
   arm_i = 1'b1;
   #10000;
   arm_i = 1'b0;
   CMD_DISARM();
   CMD_POP_DT();
   WRITE_AXI( AXI_DT1 ,  3950);
   CMD_SET_THR();
   WRITE_AXI( AXI_DT1 ,  50);
   CMD_SET_DEAD_TIME();

   CMD_RST();
   FILTER   = 1;
   SLOPE    = 0;
   INTER    = 4;
   SMP_NUM  = 6;
   WRITE_AXI( QTT_CFG  , 1* FILTER+ 2* SLOPE + 4*INTER + 32* SMP_NUM); // NO FILTER  

   CMD_ARM();
   AMP = 24;
   SIM_SINE();
   SIM_SINE();
   CMD_DISARM();
   WRITE_AXI( DMA_CFG ,   16*3);
   WRITE_AXI( QTT_CTRL ,  32);
   @ (posedge dma_m_axis_tlast_o);
   WRITE_AXI( DMA_CFG ,   16*2);
   WRITE_AXI( QTT_CTRL ,  32);
   @ (posedge dma_m_axis_tlast_o);
   WRITE_AXI( DMA_CFG ,   16*1);
   WRITE_AXI( QTT_CTRL ,  32);
   @ (posedge dma_m_axis_tlast_o);


   //CMD_DMA_RD();

   CMD_SMP_RD ();
   #10000;
   
   for (INTER=0; INTER<=4; INTER=INTER+1) begin
      CMD_DISARM();
      WRITE_AXI( QTT_CFG  , 1* FILTER+ 2* SLOPE + 4*INTER + 32* SMP_NUM ); // NO FILTER INVERT INPUT  
      CMD_ARM();
      for (AMP=2; AMP<=32; AMP=AMP*2) begin
         SIM_RANDOM();
         SIM_PULSES(); 
      end
      CMD_SMP_RD ();
      #10000;
   end
   SIM_RANDOM();
   CMD_DISARM();
   WRITE_AXI( DMA_CFG ,  0+16*1);
   WRITE_AXI( QTT_CTRL ,  32);
   #10000;
   WRITE_AXI( DMA_CFG ,  0+16*2);
   WRITE_AXI( QTT_CTRL ,  32);
   #10000;
   WRITE_AXI( DMA_CFG ,  0+16*3);
   WRITE_AXI( QTT_CTRL ,  32);
   #10000;

//Micro POP
   @ (posedge c_clk); #0.1;
    qtag_en_i     = 1;   
    qtag_op_i     = 2;   
   @ (posedge c_clk); #0.1;
    qtag_en_i     = 0;   
    qtag_op_i     = 2;   

   @ (posedge c_clk); #0.1;
   CMD_POP_DT();
   CMD_POP_DT();

end
reg    adc0_s_axis_tvalid_i, adc1_s_axis_tvalid_i, adc2_s_axis_tvalid_i, adc3_s_axis_tvalid_i;
reg dma_m_axis_tready_i;

task START_SIMULATION (); begin
    $display("START SIMULATION");
    // Create agents.
    axi_mst_0_agent 	= new("axi_mst_0 VIP Agent",tb_qick_time_tagger.axi_mst_0_i.inst.IF);
    // Set tag for agents.
    axi_mst_0_agent.set_agent_tag	("axi_mst_0 VIP");
    // Start agents.
    axi_mst_0_agent.start_master();
   rst_ni   = 1'b0;
   dma_m_axis_tready_i = 1'b1;
   adc0_s_axis_tvalid_i = 1'b1;
   adc1_s_axis_tvalid_i = 1'b1;
   adc2_s_axis_tvalid_i = 1'b1;
   adc3_s_axis_tvalid_i = 1'b1;

    arm_i = 1'b0;
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

task CMD_DISARM ();
   WRITE_AXI( QTT_CTRL ,  1 + 2 * 0);
endtask
task CMD_ARM ();
   WRITE_AXI( QTT_CTRL ,  1 + 2 * 1);
endtask
task CMD_POP_DT ();
   WRITE_AXI( QTT_CTRL ,  1 + 2 * 2);
endtask
task CMD_SET_THR ();
   WRITE_AXI( QTT_CTRL ,  1 + 2 * 4);
endtask
task CMD_SET_DEAD_TIME ();
   WRITE_AXI( QTT_CTRL ,  1 + 2 * 5);
endtask
task CMD_RST ();
   WRITE_AXI( QTT_CTRL ,  1 + 2 * 7);
endtask

task CMD_DMA_RD ();
   WRITE_AXI( DMA_CFG ,   16*5);
   WRITE_AXI( QTT_CTRL ,  32);
   @ (posedge dma_m_axis_tlast_o);
endtask

task CMD_SMP_RD ();
   WRITE_AXI( DMA_CFG ,  5+16*SMP_NUM*`SMP_CK*4);
   WRITE_AXI( QTT_CTRL ,  32);
   @ (posedge dma_m_axis_tlast_o);

endtask


integer AMP;
integer i;

task SIM_SINE(); begin
//50t per sinewave
   for (t=0; t<84000; t=t+1) begin
      @ (posedge adc_clk); #0.1;
      for (i=0; i<`SMP_CK; i=i+1) begin
         x[i] = ( (`SMP_CK*t) + i ) / (`SMP_CK*100.0) * (44.0 / 7.0);
         y[i] = $sin(x[i])*1000*AMP ;
         adc_dt[i*`SMP_DW +: `SMP_DW ] = y[i];
      end   
   end
      adc_dt = 0;
end
endtask

task SIM_PULSES(); begin
   for (t=0; t<5; t=t+1) begin
      @ (posedge adc_clk); #0.1;
      for (i=0; i<`SMP_CK; i=i+1) begin
         x[i] = ( (`SMP_CK*t)+i ) * (22.0/7.0) / 10/8 ;
         y[i] = $sin(x[i])*1000*AMP+($random %10)*rand_mult;
         adc_dt[i*`SMP_DW +: `SMP_DW ] = y[i];
      end
   end
   for (t=0; t<25; t=t+1) begin
      @ (posedge adc_clk); #0.1;
      for (i=0; i<`SMP_CK; i=i+1) begin
         x[i] = ( (`SMP_CK*t)+i ) * (22.0/7.0) / 50/8 ;
         y[i] = $cos(x[i])*1000*AMP+($random %10);
         adc_dt[i*`SMP_DW +: `SMP_DW ] = y[i];
      end
   end
   for (t=0; t<20; t=t+1) begin
      @ (posedge adc_clk); #0.1;
      for (i=0; i<`SMP_CK; i=i+1) begin
         y[i] = ($random %100);
         adc_dt[i*`SMP_DW +: `SMP_DW ] = y[i];
      end
   end
      adc_dt = 0;
end
endtask


task SIM_RANDOM(); begin
   for (t=0; t<50; t=t+1) begin
      @ (posedge adc_clk); #0.1;
      for (i=0; i<`SMP_CK; i=i+1) begin
         y[i] = ($random %100);
         adc_dt[i*`SMP_DW +: `SMP_DW ] = y[i];
      end
   end
end
endtask

endmodule
