`include "_qcom_defines.svh"

 
// TNET REG
/////////////////////////////////////////////////
module qcom_axi_reg(
   input wire              ps_aclk      ,    
   input wire              ps_aresetn   ,    
   TYPE_IF_AXI_REG         IF_s_axireg  ,
   output wire [ 3:0]      QCOM_CTRL    ,
   output wire [ 3:0]      QCOM_CFG    ,
   output wire [31:0]      RAXI_DT1     ,
   input  wire             QCOM_FLAG    ,
   input  wire [31:0]      QCOM_DT_1    ,
   input  wire [31:0]      QCOM_DT_2    ,
   input  wire             QCOM_STATUS  ,
   input  wire [31:0]      QCOM_TX_DT   ,
   input  wire [31:0]      QCOM_RX_DT   ,
   input  wire [15:0]      QCOM_DEBUG   );

// AXI Slave.
axi_slv_qcom QCOM_xREG (
   .aclk        ( ps_aclk           ) , 
   .aresetn     ( ps_aresetn        ) , 
   .awaddr      ( IF_s_axireg.axi_awaddr [5:0] ) , 
   .awprot      ( IF_s_axireg.axi_awprot       ) , 
   .awvalid     ( IF_s_axireg.axi_awvalid      ) , 
   .awready     ( IF_s_axireg.axi_awready      ) , 
   .wdata       ( IF_s_axireg.axi_wdata        ) , 
   .wstrb       ( IF_s_axireg.axi_wstrb        ) , 
   .wvalid      ( IF_s_axireg.axi_wvalid       ) , 
   .wready      ( IF_s_axireg.axi_wready       ) , 
   .bresp       ( IF_s_axireg.axi_bresp        ) , 
   .bvalid      ( IF_s_axireg.axi_bvalid       ) , 
   .bready      ( IF_s_axireg.axi_bready       ) , 
   .araddr      ( IF_s_axireg.axi_araddr       ) , 
   .arprot      ( IF_s_axireg.axi_arprot       ) , 
   .arvalid     ( IF_s_axireg.axi_arvalid      ) , 
   .arready     ( IF_s_axireg.axi_arready      ) , 
   .rdata       ( IF_s_axireg.axi_rdata        ) , 
   .rresp       ( IF_s_axireg.axi_rresp        ) , 
   .rvalid      ( IF_s_axireg.axi_rvalid       ) , 
   .rready      ( IF_s_axireg.axi_rready       ) , 
   .QCOM_CTRL   ( QCOM_CTRL    ) ,
   .QCOM_CFG    ( QCOM_CFG     ) ,
   .RAXI_DT1    ( RAXI_DT1     ) ,
   .QCOM_FLAG   ( QCOM_FLAG    ) ,
   .QCOM_DT_1   ( QCOM_DT_1    ) ,
   .QCOM_DT_2   ( QCOM_DT_2    ) ,
   .QCOM_STATUS ( QCOM_STATUS  ) ,
   .QCOM_TX_DT  ( QCOM_TX_DT   ) ,
   .QCOM_RX_DT  ( QCOM_RX_DT   ) ,
   .QCOM_DEBUG  ( QCOM_DEBUG   ) );

endmodule
