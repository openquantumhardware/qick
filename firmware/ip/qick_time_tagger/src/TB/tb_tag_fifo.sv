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

module tb_tag_mem();


parameter MEM_QTY = 4 ;
parameter DW      = 16 ;
parameter AW      = 8  ;
parameter SMP_CK  = 8  ;

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
      #(15*`RD_CLK*2)
      //#(16)
      @ (posedge rd_clk_i); #0.4;
      ready = ~ready;
   end
end

reg  [DW-1:0] data_i;
reg   push_i, dma_pop_i;
reg   flush_i;

reg              tag_wr_i [MEM_QTY] ;
reg [31:0]       tag_dt_i [MEM_QTY] ; 
reg [AW-1:0]     dma_qty_o[MEM_QTY] ;     
wire [DW-1:0] dma_dt_o;



tag_mem # (
   .MEM_QTY      ( MEM_QTY  ), // Amount of Memories
   .DMA_RD       ( 1  ), // TAG FIFO Read from DMA
   .PROC_RD      ( 0  ), // TAG FIFO Read from tProcessor
   .TAG_FIFO_AW  ( AW ), // Size of TAG FIFO Memory
   .DEBUG        ( 0  )
) TAG_MEM (
   .dma_clk_i      ( rd_clk_i     ),
   .dma_rst_ni     ( rst_ni    ),
   .c_clk_i        ( wr_clk_i       ),
   .c_rst_ni       ( rst_ni      ),
   .adc_clk_i      ( wr_clk_i     ),
   .adc_rst_ni     ( rst_ni    ),
   .qtt_pop_req_i  ( 0 ),
   .qtt_rst_req_i  ( flush_i ),
   .qtt_rst_ack_o  ( qtt_rst_ack_o ),
   .tag_wr_i       ( tag_wr_i     ), 
   .tag_dt_i       ( tag_dt_i     ), 
   .dma_qty_o      ( dma_qty_o    ),
   .proc_qty_o     ( proc_qty_o    ),
   .empty_o        ( tag_empty_o   ),
   .full_o         ( tag_full_o    ),
   .dma_sel_i      ( dma_sel_i     ),
   .dma_pop_i      ( dma_pop_i     ),
   .dma_pop_o      ( dma_pop_o     ),
   .dma_dt_o       ( dma_dt_o      ),
   .debug_do       ( tag_debug_o   )
);

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
   .fifo_dt_i        ( dma_dt_o        ) ,
   .m_axis_tready_i  ( ready  ) ,
   .m_axis_tdata_o   ( m_axis_tdata_o   ) ,
   .m_axis_tvalid_o  ( m_axis_tvalid_o  ) ,
   .m_axis_tlast_o   ( m_axis_tlast_o   ) );
   
reg [3:0] tag_wr_sel;
reg [1:0] dma_sel_i;
initial begin
   START_SIMULATION();
   tag_wr_sel = 4'b0001;
   TAG_WR();
   tag_wr_sel = 4'b0010;
   TAG_WR();
   tag_wr_sel = 4'b0100;
   TAG_WR();
   tag_wr_sel = 4'b1000;
   TAG_WR();
   tag_wr_sel = 4'b1010;
   TAG_WR();
   tag_wr_sel = 4'b0101;
   TAG_WR();
   tag_wr_sel = 4'b1111;
   TAG_WR();

   #2000;
   dma_len_i = 22;
   dma_sel_i = 2'b00;
   FIFO_DMA();   
   #1000;
   dma_len_i = 5;
   dma_sel_i = 2'b01;
   FIFO_DMA();   
   #1000;
   dma_sel_i = 2'b10;
   FIFO_DMA();   
   #1000;
   dma_sel_i = 2'b11;
   FIFO_DMA();   
   #1000;
end


task START_SIMULATION (); begin
   $display("START SIMULATION");
   rst_ni    = 1'b0;
flush_i = 1'b0;
   push_i    = 0;
   data_i    = 5;
   dma_sel_i = 2'b00;
   dma_pop_i = 1'b0;
   dma_req_i = 0;
   dma_len_i = 0;
   tag_wr_i    = '{default:'0} ;
   tag_dt_i    = '{default:'0} ;
   #10;
   @ (posedge rd_clk_i); #0.1;
   rst_ni    = 1'b1;
   @ (posedge rd_clk_i); #0.1;
   end
endtask



integer t, ind;
task TAG_WR(); begin
   $display("PUSH DATA");
   @ (posedge wr_clk_i); #0.1;
   for (t=0; t<=9; t=t+1) begin
      @ (posedge wr_clk_i); #0.1;
      for (ind=0; ind<=MEM_QTY; ind=ind+1) begin
         tag_dt_i[ind] = ((ind+1)*t+ind+1);
         tag_wr_i[ind] = tag_wr_sel[ind];
         @ (posedge wr_clk_i); #0.1;
         tag_wr_i = '{default:'0};
      end
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
