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


module qcore_mem # (
   parameter PMEM_AW = 16 ,
   parameter DMEM_AW = 16 ,
   parameter WMEM_AW = 16 
)(
   // CLK & RST.
   input  wire                c_clk_i        ,
   input  wire                c_rst_ni       ,
   input  wire                ps_clk_i       ,
   input  wire                ps_rst_ni      ,
   input  wire [1: 0]         ps_sel_i       ,
   input  wire                ps_we_i        ,
   input  wire [15: 0]        ps_addr_i      ,
   input  wire [167:0]        ps_w_dt_i      ,
   output wire [167:0]        ps_r_dt_o      ,
// PROGRAM MEMORY
   input  wire                c_pmem_en_i    ,
   input  wire [PMEM_AW-1:0]  c_pmem_addr_i  ,
   output wire [71:0]         c_pmem_r_dt_o  ,
// DATA MEMORY
   input  wire                c_dmem_we_i    ,
   input  wire [DMEM_AW-1:0]  c_dmem_addr_i  ,
   input  wire [31:0]         c_dmem_w_dt_i  ,
   output wire [31:0]         c_dmem_r_dt_o  ,
// WAVE MEMORY
   input  wire                c_wmem_we_i    ,
   input  wire [WMEM_AW-1:0]  c_wmem_addr_i  ,
   input  wire [167:0]        c_wmem_w_dt_i  ,
   output wire [167:0]        c_wmem_r_dt_o  );


wire [71 :0] ps_P_r_dt;
wire [31 :0] ps_D_r_dt;
wire [167:0] ps_W_r_dt;

// Memory Control
wire ext_P_mem_en, ext_D_mem_en, ext_W_mem_en;
wire ext_P_mem_we, ext_D_mem_we, ext_W_mem_we;

assign ext_P_mem_en = (ps_sel_i== 2'b01) ;
assign ext_D_mem_en = (ps_sel_i== 2'b10) ;
assign ext_W_mem_en = (ps_sel_i== 2'b11) ;

assign ext_P_mem_we = ext_P_mem_en & ps_we_i ;
assign ext_D_mem_we = ext_D_mem_en & ps_we_i ;
assign ext_W_mem_we = ext_W_mem_en & ps_we_i ;

assign ps_r_dt_o  =  (ps_sel_i == 2'b01)? ps_P_r_dt : 
                     (ps_sel_i == 2'b10)? ps_D_r_dt :
                     (ps_sel_i == 2'b11)? { 80'd0, ps_W_r_dt[167:88],8'd0, ps_W_r_dt[87:0]}	 :
                     0;

// PROGRAM MEMORY
///////////////////////////////////////////////////////////////////////////////
bram_dual_port_dc # (
   .MEM_AW     ( PMEM_AW ), 
   .MEM_DW     ( 72 ),
   .RAM_OUT    ("NO_REGISTERED" )
) P_MEM ( 
   .clk_a_i  ( c_clk_i         ) ,
   .en_a_i   ( c_pmem_en_i     ) ,
   .we_a_i   ( 1'b0            ) ,
   .addr_a_i ( c_pmem_addr_i   ) ,
   .dt_a_i   ( 72'd0           ) ,
   .dt_a_o   ( c_pmem_r_dt_o   ) ,
   .clk_b_i  ( ps_clk_i        ) ,
   .en_b_i   ( ext_P_mem_en    ) ,
   .we_b_i   ( ext_P_mem_we    ) ,
   .addr_b_i ( ps_addr_i[PMEM_AW-1:0]  ) ,
   .dt_b_i   ( ps_w_dt_i[71:0]  ) ,
   .dt_b_o   ( ps_P_r_dt ) );
// DATA MEMORY
///////////////////////////////////////////////////////////////////////////////
bram_dual_port_dc # (
   .MEM_AW     ( DMEM_AW ), 
   .MEM_DW     ( 32 ),
   .RAM_OUT    ("NO_REGISTERED" )
) D_MEM ( 
   .clk_a_i  ( c_clk_i         ) ,
   .en_a_i   ( 1'b1            ) ,
   .we_a_i   ( c_dmem_we_i     ) ,
   .addr_a_i ( c_dmem_addr_i   ) ,
   .dt_a_i   ( c_dmem_w_dt_i   ) ,
   .dt_a_o   ( c_dmem_r_dt_o   ) ,
   .clk_b_i  ( ps_clk_i        ) ,
   .en_b_i   ( ext_D_mem_en    ) ,
   .we_b_i   ( ext_D_mem_we    ) ,
   .addr_b_i ( ps_addr_i[DMEM_AW-1:0]  ) ,
   .dt_b_i   ( ps_w_dt_i[31:0]  ) ,
   .dt_b_o   ( ps_D_r_dt  ) );
// WAVE MEMORY 
/////////////////////////////////////////////////
bram_dual_port_dc # (
   .MEM_AW     ( WMEM_AW ), 
   .MEM_DW     ( 168 ),
   .RAM_OUT    ("NO_REGISTERED" )
) W_MEM ( 
   .clk_a_i  ( c_clk_i          ) ,
   .en_a_i   ( 1'b1            ) ,
   .we_a_i   ( c_wmem_we_i     ) ,
   .addr_a_i ( c_wmem_addr_i   ) ,
   .dt_a_i   ( c_wmem_w_dt_i   ) ,
   .dt_a_o   ( c_wmem_r_dt_o   ) ,
   .clk_b_i  ( ps_clk_i        ) ,
   .en_b_i   ( ext_W_mem_en    ) ,
   .we_b_i   ( ext_W_mem_we    ) ,
   .addr_b_i ( ps_addr_i[WMEM_AW-1:0]  ) ,
   .dt_b_i   ( ps_w_dt_i       ) ,
   .dt_b_o   ( ps_W_r_dt  ) );


endmodule
