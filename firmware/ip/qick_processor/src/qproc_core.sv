///////////////////////////////////////////////////////////////////////////////
//  FERMI RESEARCH LAB
///////////////////////////////////////////////////////////////////////////////
//  Author         : Martin Di Federico
//  Date           : 10-2023
//  Version        : 2
///////////////////////////////////////////////////////////////////////////////
//  QICK PROCESSOR :  tProc_v2
/* Description: 

*/
//////////////////////////////////////////////////////////////////////////////

`include "_qproc_defines.svh"
   
module qproc_core # (
   parameter LFSR        = 1,
   parameter IN_PORT_QTY = 1,
   parameter PMEM_AW     = 8,
   parameter DMEM_AW     = 8,
   parameter WMEM_AW     = 8,
   parameter REG_AW      = 4
)(
   input wire              c_clk_i         ,
   input wire              c_rst_ni        ,
   input wire              ps_clk_i        ,
   input wire              ps_rst_ni       ,
   input wire              en_i            ,
   input wire              restart_i       ,
// CORE CTRL
   input wire [1:0]        lfsr_cfg_i       ,
   output wire [31:0]      core_status_o    ,
   output wire [31:0]      core_debug_o     ,
   output wire [31:0]      lfsr_o           ,
// AXI Registers
   input  wire [63:0]      port_dt_i   [ IN_PORT_QTY ] ,
   input wire              flag_i       ,
// Special Function Registers
   output wire [7 :0]     sreg_cfg_o           ,
   output wire [7 :0]     sreg_ctrl_o           ,
   input  wire [31:0]      sreg_arith_i         ,
   input  wire [31:0]      sreg_div_i[2]        ,
   input  wire [31:0]      sreg_status_i        ,
   input  wire [31:0]      sreg_core_r_dt_i[2]  ,
   input  wire [31:0]      sreg_time_dt_i       , 
   output wire [31:0]      sreg_core_w_dt_o[2]  ,
// Peripherals
   output wire             usr_en_o        ,
   output wire [7:0]       usr_ctrl_o      ,
   output wire [31:0]      usr_dt_a_o      ,
   output wire [31:0]      usr_dt_b_o      ,
   output wire [31:0]      usr_dt_c_o      ,
   output wire [31:0]      usr_dt_d_o      ,
   
// Memory   
   input  wire [ 1:0]      ps_mem_sel_i    ,
   input  wire             ps_mem_we_i     ,
   input  wire [ 15:0]     ps_mem_addr_i   ,
   input  wire [167:0]     ps_mem_w_dt_i   ,
   output wire [167:0]     ps_mem_r_dt_o   ,
//Port
   output wire             port_we_o       ,
   output PORT_DT          port_o          ,
//Debug
   output wire [31:0]      core_do         );


wire [PMEM_AW-1:0]    pmem_addr         ;
wire                  pmem_en           ;
wire [71:0]           pmem_dt           ;
wire                  dmem_we           ;
wire [DMEM_AW-1:0]    dmem_addr         ;
wire [31:0]           dmem_w_dt         ;
wire [31:0]           dmem_r_dt         ;
wire                  wmem_we           ;
wire [WMEM_AW-1:0]    wmem_addr         ;
wire [167:0]          wmem_w_dt         ;
wire [167:0]          wmem_r_dt         ;

wire port_re;




qcore_cpu # (
   .LFSR                ( LFSR    ) ,
   .PMEM_AW             ( PMEM_AW ) ,
   .DMEM_AW             ( DMEM_AW ) ,
   .WMEM_AW             ( WMEM_AW ) ,
   .REG_AW              ( REG_AW  ) 
) CORE_CPU (
   .clk_i               ( c_clk_i                  ) ,
   .rst_ni              ( c_rst_ni                 ) ,
   .restart_i           ( restart_i                ) ,
   .en_i                ( en_i                     ) ,
   .lfsr_cfg_i          ( lfsr_cfg_i               ) , 
   .lfsr_o              ( lfsr_o                   ) , 
   .flag_i              ( flag_i                   ) , // External Condition
   .sreg_cfg_o          ( sreg_cfg_o               ) ,
   .sreg_ctrl_o         ( sreg_ctrl_o              ) ,
   .sreg_arith_i        ( sreg_arith_i             ) , // Arith Input
   .sreg_div_i          ( sreg_div_i               ) , // Div Input
   .sreg_status_i       ( sreg_status_i            ) ,
   .sreg_core_r_dt_i    ( sreg_core_r_dt_i         ) ,
   .sreg_port_dt_i      ( {in_port_dt_r[31:0], in_port_dt_r[63:32] } ) ,
   .sreg_time_dt_i      ( sreg_time_dt_i           ) ,
   .sreg_core_w_dt_o    ( sreg_core_w_dt_o         ) ,
   .usr_ctrl_o          ( usr_ctrl_o               ) ,
   .usr_en_o            ( usr_en_o                 ) ,
   .usr_dt_a_o          ( usr_dt_a_o               ) ,
   .usr_dt_b_o          ( usr_dt_b_o               ) ,
   .usr_dt_c_o          ( usr_dt_c_o               ) ,
   .usr_dt_d_o          ( usr_dt_d_o               ) ,
   .pmem_addr_o         ( pmem_addr                ) ,
   .pmem_en_o           ( pmem_en                  ) ,
   .pmem_dt_i           ( pmem_dt                  ) ,
   .dmem_we_o           ( dmem_we                  ) ,
   .dmem_addr_o         ( dmem_addr                ) ,
   .dmem_w_dt_o         ( dmem_w_dt                ) ,
   .dmem_r_dt_i         ( dmem_r_dt                ) ,
   .wmem_we_o           ( wmem_we                  ) ,
   .wmem_addr_o         ( wmem_addr                ) ,
   .wmem_w_dt_o         ( wmem_w_dt                ) ,
   .wmem_r_dt_i         ( wmem_r_dt                ) ,
   .port_we_o           ( port_we_o                ) ,
   .port_re_o           ( port_re                  ) ,  
   .port_o              ( port_o                   ) ,
   .core_do             ( core_do                  ) );


reg [63:0 ] in_port_dt_r;
// PORT READ
///////////////////////////////////////////////////////////////////////////////
always_ff @(posedge c_clk_i) begin
   if      ( restart_i )    in_port_dt_r  <= 0 ;
   else if ( port_re   )    in_port_dt_r  <= port_dt_i[port_o.p_addr];
end

 
qcore_mem # (
    .PMEM_AW         ( PMEM_AW      ) ,
    .DMEM_AW         ( DMEM_AW      ) ,
    .WMEM_AW         ( WMEM_AW      )
) CORE_MEM (
    .c_clk_i         ( c_clk_i       ) ,
    .c_rst_ni        ( c_rst_ni      ) ,
    .ps_clk_i        ( ps_clk_i      ) ,
    .ps_rst_ni       ( ps_rst_ni     ) ,
    .ps_sel_i        ( ps_mem_sel_i      ) ,
    .ps_we_i         ( ps_mem_we_i       ) ,
    .ps_addr_i       ( ps_mem_addr_i     ) ,
    .ps_w_dt_i       ( ps_mem_w_dt_i     ) ,
    .ps_r_dt_o       ( ps_mem_r_dt_o     ) ,
    .c_pmem_en_i     ( pmem_en   ) ,
    .c_pmem_addr_i   ( pmem_addr ) ,
    .c_pmem_r_dt_o   ( pmem_dt ) ,
    .c_dmem_we_i     ( dmem_we   ) ,
    .c_dmem_addr_i   ( dmem_addr ) ,
    .c_dmem_w_dt_i   ( dmem_w_dt ) ,
    .c_dmem_r_dt_o   ( dmem_r_dt ) ,
    .c_wmem_we_i     ( wmem_we   ) ,
    .c_wmem_addr_i   ( wmem_addr ) ,
    .c_wmem_w_dt_i   ( wmem_w_dt ) ,
    .c_wmem_r_dt_o   ( wmem_r_dt ) );

assign core_status_o = 0; 
assign core_debug_o  =0;

endmodule