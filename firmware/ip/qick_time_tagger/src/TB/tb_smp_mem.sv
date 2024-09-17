///////////////////////////////////////////////////////////////////////////////
//  FERMI RESEARCH LAB
///////////////////////////////////////////////////////////////////////////////
//  Author         : Martin Di Federico
//  Date           : 2024-5-1
//  Versión        : 1
///////////////////////////////////////////////////////////////////////////////

`timescale 1ns/10ps

`define WR_CLK         3   // Half Clock Period for Simulation
`define RD_CLK         11   // Half Clock Period for Simulation

module tb_smp_mem();

parameter DW        = 16 ;
parameter AW        = 5  ;
parameter PUSH_QTY  = 8  ;

// Signals
///////////////////////////////////////////////////////////////////////////////
reg wr_clk_i, rd_clk_i;
reg rst_ni, ready;

//  CLK
//////////////////////////////////////////////////////////////////////////
initial begin
  wr_clk_i = 1'b0;
  forever # (`WR_CLK) wr_clk_i = ~wr_clk_i;
end
initial begin
  rd_clk_i = 1'b0;
  forever # (`RD_CLK) rd_clk_i = ~rd_clk_i;
end

//  READY
//////////////////////////////////////////////////////////////////////////
initial begin
   ready = 1'b0;
   forever begin
      //#(1)
      #(5*`RD_CLK*2)
      //#(16)
      @ (posedge rd_clk_i); #0.4;
      ready = ~ready;
   end
end

reg  [DW-1:0] data_i;
wire [DW-1:0] data_0;
wire [20:0] dma_qty ;
reg   push_i, dma_pop_i;
reg   flush_i;

reg [PUSH_QTY*DW-1:0] adc_dt ;

SMP_MEM # (
   .PUSH_QTY  ( PUSH_QTY  ), // Number of Samples in adc_data (MAX 16)
   .FIFO_DW   ( DW ), // Sample Data Width
   .FIFO_AW   ( AW )  // Memory bit address Width
) SMP_MEM ( 
   .adc_clk_i   ( wr_clk_i ),
   .adc_rst_ni  ( rst_ni ),
   .dma_clk_i   ( rd_clk_i ),
   .dma_rst_ni  ( rst_ni ),
   .flush_i     ( flush_i ),
   .flush_o     ( flush_o ),
   .adc_push_i  ( push_i ),
   .adc_data_i  ( adc_dt ),
   .dma_pop_i   ( dma_pop_i ),
   .dma_pop_o   ( dma_pop_o ),
   .dma_qty_o   ( dma_qty ),
   .dma_empty_o (  ),
   .dt_o        ( fifo_dt_o ),
   .full_o      (  ),
   .debug_do    (  ));
   
wire [DW-1:0] fifo_dt_o;
reg dma_req_i;
reg [AW-1:0] dma_len_i;
   
dma_fifo_rd # (
   .MEM_AW      ( AW )  ,  // Memory Address Width
   .MEM_DW      ( DW)   ,  // Memory Data Width
   .DMA_DW      ( DW)      // DMA   Data Width
) dma_fifo_rd (
   .clk_i            ( rd_clk_i            ) ,
   .rst_ni           ( rst_ni           ) ,
   .dma_req_i        ( dma_req_i        ) ,
   .dma_ack_o        ( dma_ack_o        ) ,
   .dma_len_i        ( dma_len_i        ) ,
   .pop_req_o       ( dma_pop_i       ) ,
   .pop_ack_i       ( dma_pop_o       ) ,
   .fifo_dt_i        ( fifo_dt_o        ) ,
   .m_axis_tready_i  ( ready  ) ,
   .m_axis_tdata_o   ( m_axis_tdata_o   ) ,
   .m_axis_tvalid_o  ( m_axis_tvalid_o  ) ,
   .m_axis_tlast_o   ( m_axis_tlast_o   ) );
   

initial begin
   START_SIMULATION();
   FIFO_PUSH(); // Write 20
   #50;
   dma_len_i = 22;
   FIFO_DMA();   
   #50;
   dma_len_i = 5;
   FIFO_DMA();   
   #50;
end


task START_SIMULATION (); begin
   $display("START SIMULATION");
   rst_ni    = 1'b0;
flush_i = 1'b0;
   push_i    = 0;
   data_i    = 5;
   dma_pop_i = 1'b0;
   dma_req_i = 0;
   dma_len_i = 0;
   adc_dt    = 0 ;
   #10;
   @ (posedge rd_clk_i); #0.1;
   rst_ni    = 1'b1;
   @ (posedge rd_clk_i); #0.1;
   end
endtask



integer t, x, y;
integer           x0, x1, x2, x3,x4, x5, x6, x7 ;
reg [DW-1:0] y0, y1, y2, y3,y4, y5, y6, y7 ;


task FIFO_PUSH(); begin
   $display("PUSH DATA");
   for (t=0; t<=10; t=t+1) begin
      @ (posedge wr_clk_i); #0.1;
      x0 = ( (8*t)+0 ) ;
      x1 = ( (8*t)+1 ) ;
      x2 = ( (8*t)+2 ) ;
      x3 = ( (8*t)+3 ) ;
      x4 = ( (8*t)+4 ) ;
      x5 = ( (8*t)+5 ) ;
      x6 = ( (8*t)+6 ) ;
      x7 = ( (8*t)+7 ) ;
      y0 = x0 ;
      y1 = x1 ;
      y2 = x2 ;
      y3 = x3 ;
      y4 = x4 ;
      y5 = x5 ;
      y6 = x6 ;
      y7 = x7 ;
      adc_dt = {y7, y6, y5, y4, y3, y2, y1, y0};   
      push_i = 1'b1;
      @ (posedge wr_clk_i); #0.1;
      push_i = 1'b0;
      @ (posedge wr_clk_i); #0.1;
   end
   push_i = 1'b0;
end

endtask



task FIFO_DMA(); begin
   $display("DMA DATA");
   @ (posedge rd_clk_i); #0.1;
   dma_req_i = 1'b1;
   wait ( dma_ack_o == 1'b1);
   dma_req_i = 1'b0;
   wait ( dma_ack_o == 1'b0);
   #10;

end
endtask


endmodule
