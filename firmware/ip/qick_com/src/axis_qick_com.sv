module axis_qick_com # (
   parameter DEBUG           = 0
)(
// Core and AXI CLK & RST
   input  wire             c_clk          ,
   input  wire             c_aresetn      ,
   input  wire             ps_clk         ,
   input  wire             ps_aresetn     ,
   input  wire             sync_i         ,
// QCOM INTERFACE
   input  wire             qcom_en_i      ,
   input  wire  [4:0]      qcom_op_i      ,
   input  wire  [31:0]     qcom_dt1_i     ,
   output reg              qcom_rdy_o     ,
   output reg   [31:0]     qcom_dt1_o     ,
   output reg   [31:0]     qcom_dt2_o     ,
   output reg              qcom_vld_o     ,
   output reg              qcom_flag_o    ,
// TPROC CONTROL
   output reg              qproc_start_o   ,
// PMOD COM
   input  wire  [ 3:0]     pmod_i         ,
   output reg   [ 3:0]     pmod_o         ,
// AXI-Lite DATA Slave I/F.   
   input  wire [5:0]       s_axi_awaddr   ,
   input  wire [2:0]       s_axi_awprot   ,
   input  wire             s_axi_awvalid  ,
   output wire             s_axi_awready  ,
   input  wire [31:0]      s_axi_wdata    ,
   input  wire [ 3:0]      s_axi_wstrb    ,
   input  wire             s_axi_wvalid   ,
   output wire             s_axi_wready   ,
   output wire [ 1:0]      s_axi_bresp    ,
   output wire             s_axi_bvalid   ,
   input  wire             s_axi_bready   ,
   input  wire [ 5:0]      s_axi_araddr   ,
   input  wire [ 2:0]      s_axi_arprot   ,
   input  wire             s_axi_arvalid  ,
   output wire             s_axi_arready  ,
   output wire [31:0]      s_axi_rdata    ,
   output wire [ 1:0]      s_axi_rresp    ,
   output wire             s_axi_rvalid   ,
   input  wire             s_axi_rready   ,
///// DEBUG   
   output wire [31:0]      qcom_do        
   );

qick_com # (
   .DEBUG         ( DEBUG )
) QICK_COM (
   .c_clk_i       ( c_clk       ) ,
   .c_rst_ni      ( c_aresetn      ) ,
   .ps_clk_i      ( ps_clk      ) ,
   .ps_rst_ni     ( ps_aresetn     ) ,
   .sync_i        ( sync_i        ) ,
   .qcom_en_i     ( qcom_en_i     ) ,
   .qcom_op_i     ( qcom_op_i     ) ,
   .qcom_dt1_i    ( qcom_dt1_i    ) ,
   .qcom_rdy_o    ( qcom_rdy_o    ) ,
   .qcom_dt1_o    ( qcom_dt1_o    ) ,
   .qcom_dt2_o    ( qcom_dt2_o    ) ,
   .qcom_vld_o    ( qcom_vld_o    ) ,
   .qcom_flag_o   ( qcom_flag_o   ) ,
   .qproc_start_o ( qproc_start_o ) ,
   .pmod_i        ( pmod_i        ) ,
   .pmod_o        ( pmod_o        ) ,
   .s_axi_awaddr  ( s_axi_awaddr  ) ,
   .s_axi_awprot  ( s_axi_awprot  ) ,
   .s_axi_awvalid ( s_axi_awvalid ) ,
   .s_axi_awready ( s_axi_awready ) ,
   .s_axi_wdata   ( s_axi_wdata   ) ,
   .s_axi_wstrb   ( s_axi_wstrb   ) ,
   .s_axi_wvalid  ( s_axi_wvalid  ) ,
   .s_axi_wready  ( s_axi_wready  ) ,
   .s_axi_bresp   ( s_axi_bresp   ) ,
   .s_axi_bvalid  ( s_axi_bvalid  ) ,
   .s_axi_bready  ( s_axi_bready  ) ,
   .s_axi_araddr  ( s_axi_araddr  ) ,
   .s_axi_arprot  ( s_axi_arprot  ) ,
   .s_axi_arvalid ( s_axi_arvalid ) ,
   .s_axi_arready ( s_axi_arready ) ,
   .s_axi_rdata   ( s_axi_rdata   ) ,
   .s_axi_rresp   ( s_axi_rresp   ) ,
   .s_axi_rvalid  ( s_axi_rvalid  ) ,
   .s_axi_rready  ( s_axi_rready  ) ,         
   .qcom_do       ( qcom_do       ) 
);

endmodule

