`include "_qproc_defines.svh"

// TPROC REG
/////////////////////////////////////////////////
module qproc_axi_reg(
   input wire            ps_aclk      ,    
   input wire            ps_aresetn   ,
   input wire            c_clk_i      ,    
   input wire            c_rst_ni     ,
   TYPE_IF_AXI_REG.slave       IF_s_axireg  ,
   output wire  [31:0]   TPROC_CTRL   ,    
   output reg   [31:0]   TPROC_CFG    ,
   output reg   [15:0]   MEM_ADDR     ,    
   output reg   [15:0]   MEM_LEN      ,    
   output reg   [31:0]   MEM_DT_I     ,    
   output reg   [31:0]   TPROC_W_DT1  ,    
   output reg   [31:0]   TPROC_W_DT2  ,    
   output reg   [7:0]    CORE_CFG   ,    
   output reg   [7:0]    READ_SEL   ,    
   input  reg   [31:0]   MEM_DT_O     ,    
   input  reg   [31:0]   TPROC_R_DT1  ,    
   input  reg   [31:0]   TPROC_R_DT2  ,    
   input  reg   [31:0]   TIME_USR     ,    
   input  reg   [31:0]   TPROC_STATUS ,    
   input  reg   [31:0]   TPROC_DEBUG     
   );


wire [31:0] PS_TPROC_CTRL, PS_TPROC_CFG;

// AXI Slave.
axi_slv_qproc QPROC_xREG (
   .aclk          ( ps_aclk           ) , 
   .aresetn       ( ps_aresetn        ) , 
   .awaddr        ( IF_s_axireg.axi_awaddr [5:0] ) , 
   .awprot        ( IF_s_axireg.axi_awprot       ) , 
   .awvalid       ( IF_s_axireg.axi_awvalid      ) , 
   .awready       ( IF_s_axireg.axi_awready      ) , 
   .wdata         ( IF_s_axireg.axi_wdata        ) , 
   .wstrb         ( IF_s_axireg.axi_wstrb        ) , 
   .wvalid        ( IF_s_axireg.axi_wvalid       ) , 
   .wready        ( IF_s_axireg.axi_wready       ) , 
   .bresp         ( IF_s_axireg.axi_bresp        ) , 
   .bvalid        ( IF_s_axireg.axi_bvalid       ) , 
   .bready        ( IF_s_axireg.axi_bready       ) , 
   .araddr        ( IF_s_axireg.axi_araddr       ) , 
   .arprot        ( IF_s_axireg.axi_arprot       ) , 
   .arvalid       ( IF_s_axireg.axi_arvalid      ) , 
   .arready       ( IF_s_axireg.axi_arready      ) , 
   .rdata         ( IF_s_axireg.axi_rdata        ) , 
   .rresp         ( IF_s_axireg.axi_rresp        ) , 
   .rvalid        ( IF_s_axireg.axi_rvalid       ) , 
   .rready        ( IF_s_axireg.axi_rready       ) , 
   .TPROC_CTRL    ( PS_TPROC_CTRL                ) ,
   .TPROC_CFG     ( PS_TPROC_CFG                 ) ,
   .MEM_ADDR      ( MEM_ADDR                  ) ,
   .MEM_LEN       ( MEM_LEN                   ) ,
   .MEM_DT_I      ( MEM_DT_I                  ) ,
   .TPROC_W_DT1   ( TPROC_W_DT1               ) ,
   .TPROC_W_DT2   ( TPROC_W_DT2               ) ,
   .CORE_CFG      ( CORE_CFG                  ) ,
   .READ_SEL      ( READ_SEL                  ) ,
   .MEM_DT_O      ( MEM_DT_O                  ) ,
   .TPROC_R_DT1   ( TPROC_R_DT1               ) ,
   .TPROC_R_DT2   ( TPROC_R_DT2               ) ,
   .TIME_USR      ( TIME_USR                  ) ,
   .TPROC_STATUS  ( TPROC_STATUS           ) ,
   .TPROC_DEBUG   ( TPROC_DEBUG            ) );

 
reg [31:0] tproc_ctrl_rcd, tproc_ctrl_r, tproc_ctrl_2r;
reg [31:0] tproc_cfg_rcd;

// From PS_CLK to C_CLK
always_ff @(posedge c_clk_i) 
   if (!c_rst_ni) begin
      tproc_ctrl_rcd  <= 0 ;
      tproc_ctrl_r    <= 0 ;
      tproc_ctrl_2r   <= 0 ;
      tproc_cfg_rcd   <= 0 ;
   end else begin 
      tproc_ctrl_rcd  <= PS_TPROC_CTRL    ;
      tproc_ctrl_r    <= tproc_ctrl_rcd  ;
      tproc_ctrl_2r   <= tproc_ctrl_r  ;
      tproc_cfg_rcd   <= PS_TPROC_CFG     ;
      TPROC_CFG     <= tproc_cfg_rcd ;
   end

// The C_TPROC_CTRL is only ONE clock.
assign TPROC_CTRL       = tproc_ctrl_r & ~tproc_ctrl_2r ;

endmodule
