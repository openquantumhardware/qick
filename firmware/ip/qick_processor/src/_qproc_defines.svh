///////////////////////////////////////////////////////////////////////////////
//  FERMI RESEARCH LAB
///////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////
// GENERAL
`ifndef DEFINES
   `define DEFINES
   // Data Comming from the AXI Stream
   `define AXIS_IN_DW      32 // 14 - 30
   `define AXI_WDATA_WIDTH 32
   `define AXI_RDATA_WIDTH 32
   `define AXI_WSTRB_WIDTH 4 

   parameter CFG         = 3'b000;
   parameter BRANCH      = 3'b001;
   parameter INT_CTRL    = 3'b010;
   parameter EXT_CTRL    = 3'b011;
   parameter REG_WR      = 3'b100;
   parameter MEM_WR      = 3'b101;
   parameter PORT_WR     = 3'b110;

   typedef struct packed {
      bit         we    ;
      bit         r_wave_we ;
      bit [6:0]   addr  ;
      bit [1:0]   src  ;
      bit         port_re ;
      } CTRL_REG;

   typedef struct packed {
      reg       cfg_addr_imm  ;
      reg       cfg_dt_imm    ;
      reg       cfg_port_src  ;
      reg       cfg_port_type ;
      reg       cfg_port_time ;
      reg [3:0] cfg_cond      ;
      reg       cfg_alu_src   ;
      reg [3:0] cfg_alu_op    ;
      reg [8:0] usr_ctrl ;
      reg       flag_we ;
      reg       dmem_we ;
      reg       wmem_we ;
      reg       port_we ;
   } CTRL_FLOW;

   typedef struct packed {
      logic [31:0]   p_time ;
      logic          p_type ; // 00-WAVE 01-DATA 10-
      logic [3:0]    p_addr ;
      logic [167:0]  p_data ;
   } PORT_DT;
   
   typedef struct packed {
      logic  [47:0]   qtp_time    ;
      logic  [7 :0]   qtp_version ;
      logic  [7 :0]   qtp_cfg     ;
      logic  [7 :0]   qtp_ctrl    ;
      logic  [7 :0]   qtp_dst     ;
      logic  [15:0]   qtp_len     ;
    } QTP_CTRL;

// AXI-Lite DATA Slave I/F.   
interface TYPE_IF_AXI_REG #( );
   logic  [5:0]        axi_awaddr  ;
   logic  [2:0]        axi_awprot  ;
   logic               axi_awvalid ;
   logic               axi_awready ;
   logic  [31:0]       axi_wdata   ;
   logic  [3:0]        axi_wstrb   ;
   logic               axi_wvalid  ;
   logic               axi_wready  ;
   logic  [1:0]        axi_bresp   ;
   logic               axi_bvalid  ;
   logic               axi_bready  ;
   logic  [5:0]        axi_araddr  ;
   logic  [2:0]        axi_arprot  ;
   logic               axi_arvalid ;
   logic               axi_arready ;
   logic  [31:0]       axi_rdata   ;
   logic  [1:0]        axi_rresp   ;
   logic               axi_rvalid  ;
   logic               axi_rready  ;
   
   modport master ( output axi_awaddr,axi_awprot, axi_awvalid,axi_wdata,axi_wstrb,axi_wvalid,axi_bready,axi_araddr,axi_arprot,axi_arvalid,axi_rready,
                    input  axi_awready,axi_wready,axi_bresp,axi_bvalid,axi_arready,axi_rdata,axi_rresp,axi_rvalid );
   modport slave ( input  axi_awaddr,axi_awprot, axi_awvalid,axi_wdata,axi_wstrb,axi_wvalid,axi_bready,axi_araddr,axi_arprot,axi_arvalid,axi_rready,
                    output  axi_awready,axi_wready,axi_bresp,axi_bvalid,axi_arready,axi_rdata,axi_rresp,axi_rvalid );

endinterface

interface TYPE_IF_MEM #( 
    parameter DW = 32,
    parameter AW = 8
);
  logic               dmem_en ;
  logic               dmem_we ;
  logic [ AW-1 : 0 ]  dmem_addr;
  logic [ DW-1 : 0 ]  dmem_w_dt;
  logic [ DW-1 : 0 ]  dmem_r_dt;
//   modport slave  ( input dmem_en, dmem_we, dmem_addr, dmem_w_dt, output dmem_r_dt);
//   modport master ( input dmem_en, dmem_we, dmem_addr, dmem_w_dt, output dmem_r_dt);
endinterface
   
`endif

