//////4/////////////////////////////////////////////////////////////////////////
//  FERMI RESEARCH LAB
///////////////////////////////////////////////////////////////////////////////
//  Author         : mdife
///////////////////////////////////////////////////////////////////////////////

`timescale 1ns/10ps

`define HP_CLK         3   // Half Clock Period for Simulation
`define HP_CCLK        2   // Half Clock Period for Simulation

localparam DEBUG    =     1;  // Debugging

module tb_fifo_dma();

// Signals
///////////////////////////////////////////////////////////////////////////////
reg wr_clk_i, rd_clk_i, ready;
reg rst_ni;

//  CLK Generation
//////////////////////////////////////////////////////////////////////////
initial begin
  wr_clk_i = 1'b0;
  forever # (`HP_CCLK) wr_clk_i = ~wr_clk_i;
end
initial begin
  rd_clk_i = 1'b0;
  forever # (`HP_CCLK) rd_clk_i = ~rd_clk_i;
end
initial begin
   ready = 1'b0;
   forever begin
      #(1)
      //#(16)
      //#(24)
      //#(34)
      //#(37)
      @ (posedge rd_clk_i); #0.4;
      ready = ~ready;
   end
end


parameter DW = 32 ;
parameter AW = 16 ;

reg rst_ni;


wire [2:0] trig_inter;
reg  [DW-1:0] data_i;
wire [DW-1:0] data_0;
wire [20:0] dma_qty_o, rd_qty_o;
/*
FIFO_SC_DMA # (
   .FIFO_DW ( DW ) , 
   .FIFO_AW ( AW  )  
) fifo_dma ( 
   .clk_i         ( wr_clk_i         ) , 
   .rst_ni        ( rst_ni        ) , 
   .push_i        ( push_i        ) , 
   .data_i        ( data_i        ) , 
   .rd_pop_i      ( rd_pop_i      ) , 
   .rd_pop_o      ( rd_pop_o      ) , 
   .rd_qty_o      ( rd_qty_o      ) , 
   .rd_empty_o    (  ) , 
   .dma_pop_i     ( dma_pop_i     ) , 
   .dma_pop_o     ( dma_pop_o     ) , 
   .dma_qty_o     ( dma_qty_o     ) , 
   .dma_empty_o   ( async_empty_o ) , 
   .dt_o          (      ) , 
   .full_o        ( async_full_o  ) );
*/

reg push_i, rd_pop_i, dma_pop_i;
reg flush_i;
/*
FIFO_DC_DMA # (
   .DMA_BLOCK ( 1 ) , 
   .RD_BLOCK ( 1 ) , 
   .FIFO_DW ( DW ) , 
   .FIFO_AW ( AW  )  
) fifo_dc_dma ( 
   .wr_clk_i      ( wr_clk_i        ) , 
   .wr_rst_ni     ( rst_ni       ) , 
   .rd_clk_i      ( rd_clk_i      ) , 
   .rd_rst_ni     ( rst_ni       ) , 
   .flush_i       ( flush_i      ) ,
   .push_i        ( push_i        ) , 
   .data_i        ( data_i        ) , 
   .rd_pop_i      ( rd_pop_i      ) , 
   .rd_pop_o      (   ) , 
   .rd_qty_o      (   ) , 
   .rd_empty_o    (   ) , 
   .dma_pop_i     ( fifo_pop_o     ) , 
   .dma_pop_o     ( fifo_pop_i  ) , 
   .dma_qty_o     (   ) , 
   .dma_empty_o   (   ) , 
   .dt_o          ( fifo_dt_o  ) , 
   .full_o        (   ) );

FIFO_DC_DMA_2 # (
   .DMA_BLOCK ( 1 ) , 
   .RD_BLOCK ( 1 ) , 
   .FIFO_DW ( DW ) , 
   .FIFO_AW ( AW  )  
) fifo_dc_dma_2 ( 
   .wr_clk_i      ( wr_clk_i        ) , 
   .wr_rst_ni     ( rst_ni       ) , 
   .rd_clk_i      ( rd_clk_i      ) , 
   .rd_rst_ni     ( rst_ni       ) , 
   .flush_i       ( flush_i      ) ,
   .push_i        ( push_i        ) , 
   .data_i        ( data_i        ) , 
   .proc_pop_i    ( rd_pop_i      ) , 
   .proc_pop_o      (   ) , 
   .proc_qty_o      (   ) , 
   .proc_empty_o    (   ) , 
   .dma_pop_i     ( fifo_pop_o ) , 
   .dma_pop_o     ( ) , 
   .dma_qty_o     (   ) , 
   .dma_empty_o   (   ) , 
   .dt_o          ( ) , 
   .full_o        (   ) );
*/
TAG_FIFO_TC # (
   .DMA_BLOCK ( 1 ) , 
   .RD_BLOCK  ( 1 ) , 
   .FIFO_DW ( 32 ) , 
   .FIFO_AW ( AW  )  
) tag_mem ( 
   .dma_clk_i     ( rd_clk_i      ) , 
   .dma_rst_ni    ( rst_ni     ) , 
   .c_clk_i       ( rd_clk_i      ) , 
   .c_rst_ni      ( rst_ni     ) , 
   .adc_clk_i     ( wr_clk_i    ) , 
   .adc_rst_ni    ( rst_ni   ) , 
   .flush_i       ( flush_i    ) ,
   .adc_push_i    ( push_i       ) , 
   .adc_data_i    ( data_i       ) , 
   .c_pop_i    ( rd_pop_i  ) , 
   .c_pop_o    (   ) , 
   .c_qty_o    (   ) , 
   .c_empty_o  (   ) , 
   .dma_pop_i     ( dma_pop_i   ) , 
   .dma_pop_o     ( dma_pop_o   ) , 
   .dma_qty_o     (   ) , 
   .dma_empty_o   (   ) , 
   .dt_o          ( fifo_dt_o  ) , 
   .full_o        (   ) );
      
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
   .fifo_pop_o       ( dma_pop_i       ) ,
   .fifo_pop_i       ( dma_pop_o       ) ,
   .fifo_dt_i        ( fifo_dt_o        ) ,
   .m_axis_tready_i  ( ready  ) ,
   .m_axis_tdata_o   ( m_axis_tdata_o   ) ,
   .m_axis_tvalid_o  ( m_axis_tvalid_o  ) ,
   .m_axis_tlast_o   ( m_axis_tlast_o   ) );
   

initial begin
   START_SIMULATION();
   FIFO_PUSH(); // Write 20
   #50;
   FIFO_RD();   //Read 5
   #50;
   FIFO_DMA(); //Read 10
   #50;
   FIFO_BOTH(); //Read 10 and 10
   #50;
   FIFO_PUSH();  // Write 20
   #50;
   FIFO_BOTH();  //Read 10 and 10
   #50;
   FIFO_RD_BOTH_WR(); //Read 10 and 10writes 10
end


task START_SIMULATION (); begin
   $display("START SIMULATION");
   rst_ni    = 1'b0;
flush_i = 1'b0;
   push_i    = 0;
   data_i    = 5;
   rd_pop_i  = 1'b0;
   dma_pop_i = 1'b0;
   dma_req_i = 0;
   dma_len_i = 10;
   #10;
   @ (posedge rd_clk_i); #0.1;
   rst_ni    = 1'b1;
   @ (posedge rd_clk_i); #0.1;
   end
endtask



integer t;


task FIFO_PUSH(); begin
   $display("PUSH DATA");
   for (t=0; t<32; t=t+1) begin
      data_i = t;
      push_i = 1'b1;
      @ (posedge wr_clk_i); #0.1;
      push_i = 1'b0;
      @ (posedge wr_clk_i); #0.1;
   end
   push_i = 1'b0;
end
endtask

task FIFO_RD(); begin
   $display("RD DATA");
   for (t=0; t<5; t=t+1) begin
      #10;
      @ (posedge rd_clk_i); #0.1;
      rd_pop_i = 1'b1;
      @ (posedge rd_clk_i); #0.1;
      rd_pop_i = 1'b0;
   end
   #10;
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

task FIFO_BOTH(); begin
   $display("RD and DMA DATA");
   @ (posedge rd_clk_i); #0.1;
   dma_req_i = 1'b1;
   wait ( dma_ack_o == 1'b1);
   dma_req_i = 1'b0;

   for (t=0; t<10; t=t+1) begin
      #10;
      @ (posedge rd_clk_i); #0.1;
      rd_pop_i = 1'b1;
      @ (posedge rd_clk_i); #0.1;
      rd_pop_i = 1'b0;
   end
   #10;
   wait ( dma_ack_o == 1'b0);
   #10;
   #10;
end
endtask

task FIFO_RD_BOTH_WR(); begin
   $display("RD and DMA DATA and PUSH");
   @ (posedge rd_clk_i); #0.1;
   dma_req_i = 1'b1;
   wait ( dma_ack_o == 1'b1);
   dma_req_i = 1'b0;

   for (t=0; t<10; t=t+1) begin
      #10;
      @ (posedge rd_clk_i); #0.1;
      rd_pop_i = 1'b1;
      @ (posedge rd_clk_i); #0.1;
      rd_pop_i = 1'b0;
      
      #10;
      @ (posedge wr_clk_i); #0.1;
      data_i = t;
      push_i = 1'b1;
      @ (posedge wr_clk_i); #0.1;
      push_i = 1'b0;

   end
   #10;

   wait ( dma_ack_o == 1'b0);
   #10;
   #10;
end
endtask
endmodule




