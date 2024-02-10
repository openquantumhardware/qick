///////////////////////////////////////////////////////////////////////////////
//  FERMI RESEARCH LAB
///////////////////////////////////////////////////////////////////////////////
//  Author         : Martin Di Federico
//  Date           : 10-2023
//  Version        : 2
///////////////////////////////////////////////////////////////////////////////
//  QICK PROCESSOR :  tProc_v2
/* Description: 
Test Bench for Qick Processor Testing
*/
//////////////////////////////////////////////////////////////////////////////

`include "_qproc_defines.svh"

import axi_vip_pkg::*;
import axi_mst_0_pkg::*;



//`define T_TCLK         1.953125  // Half Clock Period for Simulation
`define T_TCLK         1.162574  // Half Clock Period for Simulation
`define T_CCLK         1.66 // Half Clock Period for Simulation
`define T_SCLK         3  // Half Clock Period for Simulation


`define DUAL_CORE        0
`define IO_CTRL          0
`define DEBUG            0
`define TNET             0
`define QCOM             0
`define CUSTOM_PERIPH    1
`define LFSR             1
`define DIVIDER          1
`define ARITH            1
`define TIME_READ        1
`define FIFO_DEPTH       3
`define PMEM_AW          8 
`define DMEM_AW          4 
`define WMEM_AW          4 
`define REG_AW           4 
`define IN_PORT_QTY      1
`define OUT_TRIG_QTY     4
`define OUT_DPORT_QTY    2
`define OUT_DPORT_DW     10
`define OUT_WPORT_QTY    3 


module tb_axis_qick_processor ();

///////////////////////////////////////////////////////////////////////////////

  
   
//wire [31:0] port_data_o [`OUT_WPORT_QTY] ;
//wire m_axis_tvalid [`OUT_WPORT_QTY] ;
//wire m_axis_tdata [`OUT_WPORT_QTY] ;


// VIP Agent
axi_mst_0_mst_t 	axi_mst_0_agent;
xil_axi_prot_t  prot        = 0;
reg[31:0]       data_wr     = 32'h12345678;
xil_axi_resp_t  resp;
//AXI-LITE
//wire                   s_axi_aclk       ;
wire                   s_ps_dma_aresetn    ;
wire [7:0]             s_axi_awaddr     ;
wire [2:0]             s_axi_awprot     ;
wire                   s_axi_awvalid    ;
wire                   s_axi_awready    ;
wire [31:0]            s_axi_wdata      ;
wire [3:0]             s_axi_wstrb      ;
wire [3:0]             s_axi_wstrb      ;
wire                   s_axi_wvalid     ;
wire                   s_axi_wready     ;
wire  [1:0]            s_axi_bresp      ;
wire                   s_axi_bvalid     ;
wire                   s_axi_bready     ;
wire [7:0]             s_axi_araddr     ;
wire [2:0]             s_axi_arprot     ;
wire                   s_axi_arvalid    ;
wire                   s_axi_arready    ;
wire  [31:0]           s_axi_rdata      ;
wire  [1:0]            s_axi_rresp      ;
wire                   s_axi_rvalid     ;
wire                   s_axi_rready     ;

//////////////////////////////////////////////////////////////////////////
//  CLK Generation
reg   t_clk, s_ps_dma_aclk, rst_ni;
wire   c_clk ;

initial begin
  t_clk = 1'b0;
  forever # (`T_TCLK) t_clk = ~t_clk;
end

/*
initial begin
  c_clk = 1'b0;
  forever # (`T_CCLK) c_clk = ~c_clk;
end
*/
assign c_clk = t_clk;
initial begin
  s_ps_dma_aclk = 1'b0;
  #0.5
  forever # (`T_SCLK) s_ps_dma_aclk = ~s_ps_dma_aclk;
end

  assign s_ps_dma_aresetn  = rst_ni;


reg [255:0] max_value ;
reg axis_dma_start  ;

   

  
reg [255 :0]       s_dma_axis_tdata_i   ;
reg                s_dma_axis_tlast_i   ;
reg                s_dma_axis_tvalid_i  ;
reg                m_dma_axis_tready_i  ;
wire [63 :0]        port_0_dt_i          ;
reg [63 :0]        port_1_dt_i          ;
reg                s_axi_aclk           ;
reg                s_axi_aresetn        ;



reg                axis_aclk            ;
reg                axis_aresetn         ;
reg                m0_axis_tready   =0    ;
reg                m1_axis_tready   =0    ;
reg                m2_axis_tready   =0    ;
reg                m3_axis_tready   =0    ;
reg                m4_axis_tready   =0    ;
reg                m5_axis_tready   =0    ;
reg                m6_axis_tready   =0    ;
reg                m7_axis_tready   =0    ;

wire               s_dma_axis_tready_o  ;
wire [255 :0]      m_dma_axis_tdata_o   ;
wire               m_dma_axis_tlast_o   ;
wire               m_dma_axis_tvalid_o  ;

wire [167:0]       m0_axis_tdata        ;
wire               m0_axis_tvalid       ;
wire [167:0]       m1_axis_tdata        ;
wire               m1_axis_tvalid       ;
wire [167:0]       m2_axis_tdata        ;
wire               m2_axis_tvalid       ;
wire [167:0]       m3_axis_tdata        ;
wire               m3_axis_tvalid       ;
wire [167:0]       m4_axis_tdata        ;
wire               m4_axis_tvalid       ;
wire [167:0]       m5_axis_tdata        ;
wire               m5_axis_tvalid       ;
wire [167:0]       m6_axis_tdata        ;
wire               m6_axis_tvalid       ;
wire [167:0]       m7_axis_tdata        ;
wire               m7_axis_tvalid       ;
wire [`OUT_DPORT_DW-1:0]         port_0_dt_o, port_1_dt_o, port_2_dt_o, port_3_dt_o         ;

wire                qnet_en_o   ;
wire  [4 :0]        qnet_op_o   ;
wire  [31:0]        qnet_a_dt_o ;
wire  [31:0]        qnet_b_dt_o ;
wire  [31:0]        qnet_c_dt_o ;
wire  [31:0]        qnet_d_dt_o ;
reg                 qnet_rdy_i      ;
reg  [31 :0]        qnet_dt_i [2]   ;
reg  [31 :0]        qcom_dt_i [2]   ;
reg  [31 :0]        qp1_dt_i [2]   ;
reg  [31 :0]        qp2_dt_i [2]   ;

wire                periph_en_o   ;
wire  [4 :0]        periph_op_o   ;
wire  [31:0]        periph_a_dt_o ;
wire  [31:0]        periph_b_dt_o ;
wire  [31:0]        periph_c_dt_o ;
wire  [31:0]        periph_d_dt_o ;
reg                periph_rdy_i    ;
reg  [31 :0]       periph_dt_i [2] ;


reg    s0_axis_tvalid ,    s1_axis_tvalid ;
reg [15:0] waves, wtime;
reg [31:0] axi_dt;


int val_A, val_B, val_C, val_D, result ;
reg [31:0] result_r, result_2r, result_3r ;

always_ff @ (posedge c_clk) begin 
   result_r        <= result;
   result_2r       <= result_r;
   result_3r       <= result_2r;
end

// Register ADDRESS
parameter REG_TPROC_CTRL      = 0  * 4 ;
parameter REG_TPROC_CFG       = 1  * 4 ;
parameter REG_MEM_ADDR        = 2  * 4 ;
parameter REG_MEM_LEN         = 3  * 4 ;
parameter REG_MEM_DT_I        = 4  * 4 ;
parameter REG_TPROC_W_DT1     = 5  * 4 ;
parameter REG_TPROC_W_DT2     = 6  * 4 ;
parameter REG_CORE_CFG        = 7 * 4 ;
parameter REG_READ_SEL        = 8 * 4 ;
parameter REG_MEM_DT_O        = 10  * 4 ;
parameter REG_TPROC_R_DT1     = 11  * 4 ;
parameter REG_TPROC_R_DT2     = 12  * 4 ;
parameter REG_TIME_USR        = 13  * 4 ;
parameter REG_TPROC_STATUS    = 14  * 4 ;
parameter REG_TPROC_DEBUG     = 15  * 4 ;



axi_mst_0 axi_mst_0_i
	(
		.aclk			   (s_ps_dma_aclk		),
		.aresetn		   (s_ps_dma_aresetn	),
		.m_axi_araddr	(s_axi_araddr	),
		.m_axi_arprot	(s_axi_arprot	),
		.m_axi_arready	(s_axi_arready	),
		.m_axi_arvalid	(s_axi_arvalid	),
		.m_axi_awaddr	(s_axi_awaddr	),
		.m_axi_awprot	(s_axi_awprot	),
		.m_axi_awready	(s_axi_awready	),
		.m_axi_awvalid	(s_axi_awvalid	),
		.m_axi_bready	(s_axi_bready	),
		.m_axi_bresp	(s_axi_bresp	),
		.m_axi_bvalid	(s_axi_bvalid	),
		.m_axi_rdata	(s_axi_rdata	),
		.m_axi_rready	(s_axi_rready	),
		.m_axi_rresp	(s_axi_rresp	),
		.m_axi_rvalid	(s_axi_rvalid	),
		.m_axi_wdata	(s_axi_wdata	),
		.m_axi_wready	(s_axi_wready	),
		.m_axi_wstrb	(s_axi_wstrb	),
		.m_axi_wvalid	(s_axi_wvalid	)
	);
   

reg proc_start_i, proc_stop_i ;
reg core_start_i, core_stop_i ;
reg time_rst_i, time_init_i, time_updt_i;

reg  [47:0] offset_dt_i ;
wire [47:0] t_time_abs_o ;
reg time_updt_i;

wire [31:0] ps_debug_do;

reg qp1_en_r;
reg [31:0] qp1_a_dt_r, qp1_b_dt_r;
wire [31:0] qp1_a_dt_o, qp1_b_dt_o, qp1_c_dt_o, qp1_d_dt_o;
always_ff @ (posedge c_clk) begin 
   qp1_en_r     <= qp1_en_o;
   qp1_a_dt_r   <=  qp1_a_dt_o;
   qp1_b_dt_r   <=  qp1_b_dt_o;
end
  
assign qp1_rdy_i     = ~qp1_en_r;
assign qp1_dt_i[0]   = qp1_a_dt_r;
assign qp1_dt_i[1]   = qp1_b_dt_r;
assign qp1_vld_i     = qp1_en_r  ;

   
axis_qick_processor # (
   .DUAL_CORE      (  `DUAL_CORE   ) ,
   .IO_CTRL        (  `IO_CTRL   ) ,
   .DEBUG          (  `DEBUG     ) ,
   .TNET           (  `TNET      ) ,
   .QCOM           (  `QCOM      ) ,
   .CUSTOM_PERIPH  (  `CUSTOM_PERIPH ) ,
   .LFSR           (  `LFSR ) ,
   .DIVIDER        (  `DIVIDER ) ,
   .ARITH          (  `ARITH ) ,
   .TIME_READ      (  `TIME_READ ) ,
   .FIFO_DEPTH     (  `FIFO_DEPTH ) ,
   .PMEM_AW        (  `PMEM_AW ) ,
   .DMEM_AW        (  `DMEM_AW ) ,
   .WMEM_AW        (  `WMEM_AW ) ,
   .REG_AW         (  `REG_AW ) ,
   .IN_PORT_QTY    (  `IN_PORT_QTY ) ,
   .OUT_TRIG_QTY   (  `OUT_TRIG_QTY ) ,
   .OUT_DPORT_QTY  (  `OUT_DPORT_QTY ) ,
   .OUT_DPORT_DW   (  `OUT_DPORT_DW ) ,   
   .OUT_WPORT_QTY  (  `OUT_WPORT_QTY ) 
) AXIS_QPROC (
   .t_clk_i             ( t_clk              ) ,
   .t_resetn            ( rst_ni              ) ,
   .c_clk_i             ( c_clk              ) ,
   .c_resetn            ( rst_ni              ) ,
   .ps_clk_i            ( s_ps_dma_aclk       ) ,
   .ps_resetn           ( s_ps_dma_aresetn    ) ,
   .ext_flag_i          ( ext_flag_i            ) ,
   .proc_start_i        ( proc_start_i               ) ,
   .proc_stop_i         ( proc_stop_i                ) ,
   .core_start_i        ( core_start_i               ) ,
   .core_stop_i         ( core_stop_i                ) ,
   .time_rst_i          ( time_rst_i               ) ,
   .time_init_i         ( time_init_i               ) ,
   .time_updt_i         ( time_updt_i                ) ,
   .time_dt_i           ( offset_dt_i                ) ,
   .t_time_abs_o        ( t_time_abs_o                ) ,
   .ps_debug_do         ( ps_debug_do            ) , 

   .qnet_en_o           ( qnet_en_o          ) ,
   .qnet_op_o           ( qnet_op_o          ) ,
   .qnet_a_dt_o         ( qnet_a_dt_o        ) ,
   .qnet_b_dt_o         ( qnet_b_dt_o        ) ,
   .qnet_c_dt_o         ( qnet_c_dt_o        ) ,
   .qnet_rdy_i          ( qnet_rdy_i         ) ,
   .qnet_dt1_i          ( qnet_dt_i[0]       ) ,
   .qnet_dt2_i          ( qnet_dt_i[1]       ) ,
   .qnet_vld_i          ( qnet_vld_i         ) ,
   .qnet_flag_i         ( qnet_flag_i        ) ,

   .qcom_en_o           ( qcom_en_o          ) ,
   .qcom_op_o           ( qcom_op_o          ) ,
   .qcom_dt_o           ( qcom_dt_o          ) ,
   .qcom_rdy_i          ( qcom_rdy_i         ) ,
   .qcom_dt1_i          ( qcom_dt_i[0]       ) ,
   .qcom_dt2_i          ( qcom_dt_i[1]       ) ,
   .qcom_vld_i          ( qcom_vld_i         ) ,
   .qcom_flag_i         ( qcom_flag_i        ) ,

   .qp1_en_o           ( qp1_en_o          ) ,
   .qp1_op_o           ( qp1_op_o          ) ,
   .qp1_a_dt_o         ( qp1_a_dt_o        ) ,
   .qp1_b_dt_o         ( qp1_b_dt_o        ) ,
   .qp1_c_dt_o         ( qp1_c_dt_o        ) ,
   .qp1_d_dt_o         ( qp1_d_dt_o        ) ,
   .qp1_rdy_i          ( qp1_rdy_i         ) ,
   .qp1_dt1_i          ( qp1_dt_i[0]       ) ,
   .qp1_dt2_i          ( qp1_dt_i[1]       ) ,
   .qp1_vld_i          ( qp1_vld_i         ) ,
   .qp1_flag_i         ( qp1_flag_i        ) ,

   .qp2_en_o           ( qp2_en_o          ) ,
   .qp2_op_o           ( qp2_op_o          ) ,
   .qp2_a_dt_o         ( qp2_a_dt_o        ) ,
   .qp2_b_dt_o         ( qp2_b_dt_o        ) ,
   .qp2_c_dt_o         ( qp2_c_dt_o        ) ,
   .qp2_d_dt_o         ( qp2_d_dt_o        ) ,
   .qp2_rdy_i          ( qpb_rdy_i         ) ,
   .qp2_dt1_i          ( qp2_dt_i[0]       ) ,
   .qp2_dt2_i          ( qp2_dt_i[1]       ) ,
   .qp2_vld_i          ( qp2_vld_i         ) ,

   .s_dma_axis_tdata_i   ( s_dma_axis_tdata_i  ) ,
   .s_dma_axis_tlast_i   ( s_dma_axis_tlast_i  ) ,
   .s_dma_axis_tvalid_i  ( s_dma_axis_tvalid_i ) ,
   .s_dma_axis_tready_o  ( s_dma_axis_tready_o ) ,
   .m_dma_axis_tdata_o   ( m_dma_axis_tdata_o  ) ,
   .m_dma_axis_tlast_o   ( m_dma_axis_tlast_o  ) ,
   .m_dma_axis_tvalid_o  ( m_dma_axis_tvalid_o ) ,
   .m_dma_axis_tready_i  ( m_dma_axis_tready_i ) ,
   .s0_axis_tdata        ( port_0_dt_i    ) ,
   .s0_axis_tvalid       ( port_0_vld ) ,
   .s1_axis_tdata        ( port_1_dt_i    ) ,
   .s1_axis_tvalid       ( s1_axis_tvalid ) ,
   .s2_axis_tdata        ( 64'd2          ) ,
   .s2_axis_tvalid       ( 1'b0 ) ,
   .s3_axis_tdata        ( 64'd3          ) ,
   .s3_axis_tvalid       ( 1'b0 ) ,
   .s4_axis_tdata        ( 64'd4          ) ,
   .s4_axis_tvalid       ( 1'b0 ) ,
   .s5_axis_tdata        ( 64'd5          ) ,
   .s5_axis_tvalid       ( 1'b0 ) ,
   .s6_axis_tdata        ( 64'd6          ) ,
   .s6_axis_tvalid       ( 1'b0 ) ,
   .s7_axis_tdata        ( 64'd7          ) ,
   .s7_axis_tvalid       ( 1'b0 ) , 
   .s_axi_awaddr         ( s_axi_awaddr[7:0]        ) ,
   .s_axi_awprot         ( s_axi_awprot        ) ,
   .s_axi_awvalid        ( s_axi_awvalid       ) ,
   .s_axi_awready        ( s_axi_awready       ) ,
   .s_axi_wdata          ( s_axi_wdata         ) ,
   .s_axi_wstrb          ( s_axi_wstrb         ) ,
   .s_axi_wvalid         ( s_axi_wvalid        ) ,
   .s_axi_wready         ( s_axi_wready        ) ,
   .s_axi_bresp          ( s_axi_bresp         ) ,
   .s_axi_bvalid         ( s_axi_bvalid        ) ,
   .s_axi_bready         ( s_axi_bready        ) ,
   .s_axi_araddr         ( s_axi_araddr[7:0]   ) ,
   .s_axi_arprot         ( s_axi_arprot        ) ,
   .s_axi_arvalid        ( s_axi_arvalid       ) ,
   .s_axi_arready        ( s_axi_arready       ) ,
   .s_axi_rdata          ( s_axi_rdata         ) ,
   .s_axi_rresp          ( s_axi_rresp         ) ,
   .s_axi_rvalid         ( s_axi_rvalid        ) ,
   .s_axi_rready         ( s_axi_rready        ) ,
   .m0_axis_tdata        ( m0_axis_tdata       ) ,
   .m0_axis_tvalid       ( m0_axis_tvalid      ) ,
   .m0_axis_tready       ( m0_axis_tready      ) ,
   .m1_axis_tdata        ( m1_axis_tdata       ) ,
   .m1_axis_tvalid       ( m1_axis_tvalid      ) ,
   .m1_axis_tready       ( m1_axis_tready      ) ,
   .m2_axis_tdata        ( m2_axis_tdata       ) ,
   .m2_axis_tvalid       ( m2_axis_tvalid      ) ,
   .m2_axis_tready       ( m2_axis_tready      ) ,
   .m3_axis_tdata        ( m3_axis_tdata       ) ,
   .m3_axis_tvalid       ( m3_axis_tvalid      ) ,
   .m3_axis_tready       ( m3_axis_tready      ) ,
   .m4_axis_tdata        ( m4_axis_tdata       ) ,
   .m4_axis_tvalid       ( m4_axis_tvalid      ) ,
   .m4_axis_tready       ( m4_axis_tready      ) ,
   .m5_axis_tdata        ( m5_axis_tdata       ) ,
   .m5_axis_tvalid       ( m5_axis_tvalid      ) ,
   .m5_axis_tready       ( m5_axis_tready      ) ,
   .m6_axis_tdata        ( m6_axis_tdata       ) ,
   .m6_axis_tvalid       ( m6_axis_tvalid      ) ,
   .m6_axis_tready       ( m6_axis_tready      ) ,
   .m7_axis_tdata        ( m7_axis_tdata       ) ,
   .m7_axis_tvalid       ( m7_axis_tvalid      ) ,
   .m7_axis_tready       ( m7_axis_tready      ) ,
   .port_0_dt_o          ( port_0_dt_o         ) ,
   .port_1_dt_o          ( port_1_dt_o         ) ,
   .port_2_dt_o          ( port_2_dt_o         ) ,
   .port_3_dt_o          ( port_3_dt_o         ) );

wire port_0_vld, qnet_vld_i, qnet_flag_i, periph_flag_i, ext_flag_i;
assign   port_0_dt_i     = port_0_dt_o;
assign   port_0_vld      = t_time_abs_o[3]&t_time_abs_o[2]&t_time_abs_o[1] ;
assign   qnet_vld_i      = t_time_abs_o[3]&t_time_abs_o[2]&t_time_abs_o[1] ;
assign qnet_flag_i       = ~t_time_abs_o[5] & ~t_time_abs_o[4] & t_time_abs_o[3] ;
assign periph_flag_i     = ~t_time_abs_o[5] &  t_time_abs_o[4] & t_time_abs_o[3] ;
assign ext_flag_i        =  t_time_abs_o[5] &  t_time_abs_o[4] & t_time_abs_o[3] ;

reg  periph_vld_i  ;
reg qcom_rdy_i, qpb_rdy_i;

initial begin

   $display("AXI_WDATA_WIDTH %d",  `AXI_WDATA_WIDTH);

   $display("LFSR %d",  `LFSR);
   $display("DIVIDER %d",  `DIVIDER);
   $display("ARITH %d",  `ARITH);
   $display("TIME_READ %d",  `TIME_READ);

   $display("DMEM_AW %d",  `DMEM_AW);
   $display("WMEM_AW %d",  `WMEM_AW);
   $display("REG_AW %d",  `REG_AW);
   $display("IN_PORT_QTY %d",  `IN_PORT_QTY);
   $display("OUT_DPORT_QTY %d",  `OUT_DPORT_QTY);
   $display("OUT_WPORT_QTY %d",  `OUT_WPORT_QTY);
   
  
   AXIS_QPROC.QPROC.CORE_0.CORE_MEM.D_MEM.RAM = '{default:'0} ;
   AXIS_QPROC.QPROC.CORE_0.CORE_MEM.W_MEM.RAM = '{default:'0} ;
   AXIS_QPROC.QPROC.DISPATCHER.TRIG_FIFO[0].trig_fifo_inst.fifo_mem.RAM = '{default:'0} ;
   AXIS_QPROC.QPROC.DISPATCHER.DATA_FIFO[0].data_fifo_inst.fifo_mem.RAM = '{default:'0} ;
   AXIS_QPROC.QPROC.DISPATCHER.WAVE_FIFO[0].wave_fifo_inst.fifo_mem.RAM = '{default:'0} ;

   //AXIS_QPROC.QPROC.TRIG_FIFO[0].trig_fifo_inst.fifo_mem.RAM = '{default:'0} ;
   //AXIS_QPROC.QPROC.DATA_FIFO[0].data_fifo_inst.fifo_mem.RAM = '{default:'0} ;
   //AXIS_QPROC.QPROC.WAVE_FIFO[0].wave_fifo_inst.fifo_mem.RAM = '{default:'0} ;

   //AXIS_QPROC.QPROC.WAVE_FIFO[1].wave_fifo_inst.fifo_mem.RAM = '{default:'0} ;
   //AXIS_QPROC.QPROC.WAVE_FIFO[2].wave_fifo_inst.fifo_mem.RAM = '{default:'0} ;
   //AXIS_QPROC.QPROC.WAVE_FIFO[3].wave_fifo_inst.fifo_mem.RAM = '{default:'0} ;
   //AXIS_QPROC.QPROC.WAVE_FIFO[4].wave_fifo_inst.fifo_mem.RAM = '{default:'0} ;
   //AXIS_QPROC.QPROC.DATA_FIFO[1].data_fifo_inst.fifo_mem.RAM = '{default:'0} ;
   
   
   $readmemb("/home/mdifeder/repos/qick-spin/firmware/ip/qick_processor/src/TB/prog.bin", AXIS_QPROC.QPROC.CORE_0.CORE_MEM.P_MEM.RAM);
   $readmemb("/home/mdifeder/repos/qick-spin/firmware/ip/qick_processor/src/TB/wave.bin", AXIS_QPROC.QPROC.CORE_0.CORE_MEM.W_MEM.RAM);
   
  	// Create agents.
	axi_mst_0_agent 	= new("axi_mst_0 VIP Agent",tb_axis_qick_processor.axi_mst_0_i.inst.IF);
	// Set tag for agents.
	axi_mst_0_agent.set_agent_tag	("axi_mst_0 VIP");
	// Start agents.
	axi_mst_0_agent.start_master();


// INITIAL VALUES

   qnet_dt_i = '{default:'0} ;
   rst_ni          = 1'b0;
   axi_dt          = 0 ;
   axis_dma_start  = 1'b0;
   s1_axis_tvalid  = 1'b0 ;
   port_1_dt_i     = 0;
   qcom_rdy_i    = 0 ;
   qpb_rdy_i    = 0 ;
   periph_dt_i     = {0,0} ;
   qnet_rdy_i      = 0 ;
   qnet_dt_i [2]   = {0,0} ;
   proc_start_i   = 1'b0;
   proc_stop_i    = 1'b0;
   core_start_i   = 1'b0;
   core_stop_i    = 1'b0;
   time_rst_i     = 1'b0;
   time_init_i    = 1'b0;
   time_updt_i    = 1'b0;
   offset_dt_i    = 0 ;
   periph_vld_i   = 1'b0;


   m_dma_axis_tready_i = 1'b1; 
   max_value   = 0;
   #10;
   @ (posedge s_ps_dma_aclk); #0.1;
	rst_ni = 1'b1;
   #10;

   //TEST_AXI ();
   //TEST_SINGLE_READ_AXI();
   //TEST_DMA_AXI ();
   //TEST_SINGLE_READ_AXI();

   // WRITE_AXI( REG_TPROC_CFG , 512); //DISABLE NET CTRL NOTHING HAPPENS
   // TEST_STATES();
   // 
   // WRITE_AXI( REG_TPROC_CFG , 0); //DISABLE NET CTRL ONLY NET COMMANDS
   // TEST_STATES();
   // 
   // WRITE_AXI( REG_TPROC_CFG , 1536); //ENABLE IO ONLY IO COMMANDS
   // TEST_STATES();
   // 
   // WRITE_AXI( REG_TPROC_CFG , 1024); //ENABLE IO ENABLE NET
   // TEST_STATES();


   WRITE_AXI( REG_TPROC_CFG, 1024); //ENABLE EXTERNAL CONTROL

   #100;
   @ (posedge c_clk); #0.1;
   proc_start_i   = 1'b1;
   @ (posedge c_clk); #0.1;
   proc_start_i   = 1'b0;

   #10000;


/*
// CONFIGURE LFSR
   @ (posedge s_ps_dma_aclk); #0.1;
   WRITE_AXI( REG_TPROC_W_DT1 , 4); //
   WRITE_AXI( REG_TPROC_W_DT2 , 10); //
   WRITE_AXI( REG_CORE_CFG, 1); //LFSR FREE RUN
   WRITE_AXI( REG_CORE_CFG, 2); //LFSR LAST
   WRITE_AXI( REG_TPROC_CTRL , 4); //START


   WRITE_AXI( REG_READ_SEL, 0); //SELECT READ
   WRITE_AXI( REG_READ_SEL, 1); //SELECT READ
   WRITE_AXI( REG_READ_SEL, 2); //SELECT READ
   WRITE_AXI( REG_READ_SEL, 3); //SELECT READ
   WRITE_AXI( REG_READ_SEL, 4); //SELECT READ
   WRITE_AXI( REG_READ_SEL, 5); //SELECT READ
   WRITE_AXI( REG_READ_SEL, 6); //SELECT READ
   WRITE_AXI( REG_READ_SEL, 7); //SELECT READ
   WRITE_AXI( REG_READ_SEL, 8); //SELECT READ
   WRITE_AXI( REG_READ_SEL, 1); //SELECT READ

   #1000;
//   WRITE_AXI( REG_TPROC_CTRL , 8); //STOP
   WRITE_AXI( REG_TPROC_CTRL , 4); //START
   #1000;
   WRITE_AXI( REG_TPROC_CTRL , 4); //START
   #1000;
   WRITE_AXI( REG_TPROC_CTRL , 4); //START
   #1000;

   //WRITE_AXI( REG_TPROC_CFG , 6144); //CONTINUE IF FULL
  // PROCESSOR START
   WRITE_AXI( REG_TPROC_W_DT1 , 4); //
   WRITE_AXI( REG_TPROC_W_DT2 , 10); //
   WRITE_AXI( REG_TPROC_CTRL , 8192); //COND_SET
// PORT DATA IN
   @ (posedge c_clk); #0.1;
   s1_axis_tvalid  = 1'b1 ;
   port_1_dt_i     = 13;
   @ (posedge c_clk); #0.1;
   s1_axis_tvalid  = 1'b0 ;
   port_1_dt_i     = 0;
   #25;
*/



end


integer DATA_RD;

/// DMA SIMULATOR
always_ff @(posedge s_ps_dma_aclk) begin
   if (axis_dma_start) begin
      if (s_dma_axis_tdata_i < axis_dma_len ) begin
         s_dma_axis_tdata_i   <= s_dma_axis_tdata_i + 1'b1 ;
         s_dma_axis_tvalid_i  <= 1;
      end else if (s_dma_axis_tdata_i == axis_dma_len ) begin
         s_dma_axis_tdata_i   <= s_dma_axis_tdata_i + 1'b1 ;
         s_dma_axis_tlast_i   <= 1'b1;
         s_dma_axis_tvalid_i  <= 1'b1; 
      end else begin
         s_dma_axis_tdata_i   <= 0 ;
         s_dma_axis_tlast_i   <= 0 ;
         s_dma_axis_tvalid_i  <= 0 ;
      end
   end else begin 
      s_dma_axis_tdata_i   <= 0 ;
      s_dma_axis_tlast_i   <= 0 ;
      s_dma_axis_tvalid_i  <= 0 ;
   end
end


reg [15:0] axis_dma_len;
task TEST_SINGLE_READ_AXI (); begin

   //DATA MEMORY READ
   /////////////////////////////////////////////
   // ADDR
   data_wr   = 0; 
   axi_mst_0_agent.AXI4LITE_WRITE_BURST(REG_MEM_ADDR, prot, data_wr, resp);
   //CONFIGURE TPROC ()
   data_wr = 32'b0000000000000000000000000_00_1_10_0_1; // '00'_CORE0 - '1'_SINGLE - '10'_DMEM - '0'_WRITE - '1'_START
   axi_mst_0_agent.AXI4LITE_WRITE_BURST(REG_TPROC_CFG, prot, data_wr, resp);
   @ (posedge s_ps_dma_aclk); #0.1;
   data_wr = 32'b00000000_00000000_00000000_00000000;
   axi_mst_0_agent.AXI4LITE_WRITE_BURST(REG_TPROC_CFG, prot, data_wr, resp);
   @ (posedge s_ps_dma_aclk); #0.1;
   
   //PROGRAM MEMORY WRITE
   /////////////////////////////////////////////
   // ADDR
   data_wr   = 0; 
   axi_mst_0_agent.AXI4LITE_WRITE_BURST(REG_MEM_ADDR, prot, data_wr, resp);
   // DATA
   data_wr   = 127; 
   axi_mst_0_agent.AXI4LITE_WRITE_BURST(REG_MEM_DT_I, prot, data_wr, resp);
   //CONFIGURE TPROC ()
   data_wr = 32'b0000000000000000000000000_00_1_01_1_1; // '00'_CORE0 - '1'_SINGLE - '01'_PMEM - '1'_WRITE - '1'_START
   axi_mst_0_agent.AXI4LITE_WRITE_BURST(REG_TPROC_CFG, prot, data_wr, resp);
   @ (posedge s_ps_dma_aclk); #0.1;
   data_wr = 32'b00000000_00000000_00000000_00000000;
   axi_mst_0_agent.AXI4LITE_WRITE_BURST(REG_TPROC_CFG, prot, data_wr, resp);
   @ (posedge s_ps_dma_aclk); #0.1;
   //DATA MEMORY WRITE
   /////////////////////////////////////////////
   // ADDR
   data_wr   = 0; 
   axi_mst_0_agent.AXI4LITE_WRITE_BURST(REG_MEM_ADDR, prot, data_wr, resp);
   // DATA
   data_wr   = 255; 
   axi_mst_0_agent.AXI4LITE_WRITE_BURST(REG_MEM_DT_I, prot, data_wr, resp);
   //CONFIGURE TPROC ()
   data_wr = 32'b0000000000000000000000000_00_1_10_1_1; // '00'_CORE0 - '1'_SINGLE - '10'_DMEM - '1'_WRITE - '1'_START
   axi_mst_0_agent.AXI4LITE_WRITE_BURST(REG_TPROC_CFG, prot, data_wr, resp);
   @ (posedge s_ps_dma_aclk); #0.1;
   data_wr = 32'b00000000_00000000_00000000_00000000;
   axi_mst_0_agent.AXI4LITE_WRITE_BURST(REG_TPROC_CFG, prot, data_wr, resp);
   @ (posedge s_ps_dma_aclk); #0.1;


   //DATA MEMORY READ
   /////////////////////////////////////////////
   // ADDR
   data_wr   = 0; 
   axi_mst_0_agent.AXI4LITE_WRITE_BURST(REG_MEM_ADDR, prot, data_wr, resp);
   //CONFIGURE TPROC ()
   data_wr = 32'b0000000000000000000000000_00_1_10_0_1; // '00'_CORE0 - '1'_SINGLE - '10'_DMEM - '0'_WRITE - '1'_START
   axi_mst_0_agent.AXI4LITE_WRITE_BURST(REG_TPROC_CFG, prot, data_wr, resp);
   @ (posedge s_ps_dma_aclk); #0.1;
   data_wr = 32'b00000000_00000000_00000000_00000000;
   axi_mst_0_agent.AXI4LITE_WRITE_BURST(REG_TPROC_CFG, prot, data_wr, resp);
   @ (posedge s_ps_dma_aclk); #0.1;
   
end
endtask

task TEST_DMA_AXI (); begin
   //PROGRAM MEMORY WRITE
   /////////////////////////////////////////////
   // DATA LEN
   axis_dma_len = 50;
   axi_mst_0_agent.AXI4LITE_WRITE_BURST(REG_MEM_LEN, prot, axis_dma_len, resp);
   // START ADDR
   data_wr   = 0; 
   axi_mst_0_agent.AXI4LITE_WRITE_BURST(REG_MEM_ADDR, prot, data_wr, resp);

   //CONFIGURE TPROC ()
   data_wr = 32'b0000000000000000000000000_00_0_01_1_1; // '00'_CORE0 - '0'_AXI - '01'_PMEM - '1'_WRITE - '1'_START
   axi_mst_0_agent.AXI4LITE_WRITE_BURST(REG_TPROC_CFG, prot, data_wr, resp);
   //Start DMA TRANSFER
   @(posedge s_dma_axis_tready_o); 
   axis_dma_start = 1'b1;
   @(posedge s_dma_axis_tlast_i);
   axis_dma_start = 1'b0;
   data_wr = 32'b00000000_00000000_00000000_00000000;
   axi_mst_0_agent.AXI4LITE_WRITE_BURST(REG_TPROC_CFG, prot, data_wr, resp);
   @ (posedge s_ps_dma_aclk); #0.1;
   
   
   //PROGRAM MEMORY READ
   /////////////////////////////////////////////
   // DATA LEN
   axis_dma_len = 25;
   axi_mst_0_agent.AXI4LITE_WRITE_BURST(REG_MEM_LEN, prot, axis_dma_len, resp);
   // START ADDR
   data_wr   = 25;
   axi_mst_0_agent.AXI4LITE_WRITE_BURST(REG_MEM_ADDR, prot, data_wr, resp);
   //CONFIGURE TPROC ()
   data_wr = 32'b0000000000000000000000000_00_0_01_0_1; // '00'_CORE0 - '0'_AXI - '01'_PMEM - '0'_READ - '1'_START
   axi_mst_0_agent.AXI4LITE_WRITE_BURST(REG_TPROC_CFG, prot, data_wr, resp);

   //Wait for READ - DMA TRANSFER
   @(posedge m_dma_axis_tlast_o);
   data_wr = 32'b00000000_0000000_00000000_00000000;
   axi_mst_0_agent.AXI4LITE_WRITE_BURST(REG_TPROC_CFG, prot, data_wr, resp);
   @ (posedge s_ps_dma_aclk); #0.1;
   
   
   //DATA MEMORY WRITE
   /////////////////////////////////////////////
   // DATA LEN
   axis_dma_len = 50;
   axi_mst_0_agent.AXI4LITE_WRITE_BURST(REG_MEM_LEN, prot, axis_dma_len, resp);
   // START ADDR
   data_wr   = 10; 
   axi_mst_0_agent.AXI4LITE_WRITE_BURST(REG_MEM_ADDR, prot, data_wr, resp);
   //CONFIGURE TPROC ()
   data_wr = 32'b0000000000000000000000000_00_0_10_1_1; // '00'_CORE0 - '0'_AXI - '10'_DMEM - '1'_WRITE - '1'_START
   axi_mst_0_agent.AXI4LITE_WRITE_BURST(REG_TPROC_CFG, prot, data_wr, resp);

   //Start DMA TRANSFER
   @(posedge s_dma_axis_tready_o); 
   axis_dma_start = 1'b1;
   @(posedge s_dma_axis_tlast_i);
   axis_dma_start = 1'b0;
   data_wr = 32'b00000000_0000000_00000000_00000000;
   axi_mst_0_agent.AXI4LITE_WRITE_BURST(REG_TPROC_CFG, prot, data_wr, resp);
   @ (posedge s_ps_dma_aclk); #0.1;
   
   
   //DATA MEMORY READ
   /////////////////////////////////////////////
   // DATA LEN
   axis_dma_len = 50;
   axi_mst_0_agent.AXI4LITE_WRITE_BURST(REG_MEM_LEN, prot, axis_dma_len, resp);
   // START ADDR
   data_wr   = 0; 
   axi_mst_0_agent.AXI4LITE_WRITE_BURST(REG_MEM_ADDR, prot, data_wr, resp);
   //CONFIGURE TPROC ()
   data_wr = 32'b0000000000000000000000000_00_0_10_0_1; // '00'_CORE0 - '0'_AXI - '10'_DMEM - '0'_READ - '1'_START
   axi_mst_0_agent.AXI4LITE_WRITE_BURST(REG_TPROC_CFG, prot, data_wr, resp);

   //Wait for READ - DMA TRANSFER
   @(posedge m_dma_axis_tlast_o);
   data_wr = 32'b00000000_0000000_00000000_00000000;
   axi_mst_0_agent.AXI4LITE_WRITE_BURST(REG_TPROC_CFG, prot, data_wr, resp);
   @ (posedge s_ps_dma_aclk); #0.1;
   
   //WAVE MEMORY WRITE
   /////////////////////////////////////////////
   // DATA LEN
   axis_dma_len = 15;
   axi_mst_0_agent.AXI4LITE_WRITE_BURST(REG_MEM_LEN, prot, axis_dma_len, resp);
   // START ADDR
   data_wr   = 0; 
   axi_mst_0_agent.AXI4LITE_WRITE_BURST(REG_MEM_ADDR, prot, data_wr, resp);
   //CONFIGURE TPROC ()
   data_wr = 32'b0000000000000000000000000_00_0_11_1_1; // '00'_CORE0 - '0'_AXI - '11'_WMEM - '1'_WRITE - '1'_START
   axi_mst_0_agent.AXI4LITE_WRITE_BURST(REG_TPROC_CFG, prot, data_wr, resp);

   //Start DMA TRANSFER
   @(posedge s_dma_axis_tready_o); 
   axis_dma_start = 1'b1;
   @(posedge s_dma_axis_tlast_i);
   axis_dma_start = 1'b0;
   data_wr = 32'b00000000_0000000_00000000_00000000;
   axi_mst_0_agent.AXI4LITE_WRITE_BURST(REG_TPROC_CFG, prot, data_wr, resp);
   @ (posedge s_ps_dma_aclk); #0.1;


   //WAVE MEMORY READ
   /////////////////////////////////////////////
   // DATA LEN
   axis_dma_len = 15;
   axi_mst_0_agent.AXI4LITE_WRITE_BURST(REG_MEM_LEN, prot, axis_dma_len, resp);
   // START ADDR
   data_wr   = 0; 
   axi_mst_0_agent.AXI4LITE_WRITE_BURST(REG_MEM_ADDR, prot, data_wr, resp);
   //CONFIGURE TPROC ()
   data_wr = 32'b0000000000000000000000000_00_0_11_0_1; // '00'_CORE0 - '0'_AXI - '11'_WMEM - '0'_READ - '1'_START
   axi_mst_0_agent.AXI4LITE_WRITE_BURST(REG_TPROC_CFG, prot, data_wr, resp);

   //Wait for READ - DMA TRANSFER
   @(posedge m_dma_axis_tlast_o);
   data_wr = 32'b00000000_0000000_00000000_00000000;
   axi_mst_0_agent.AXI4LITE_WRITE_BURST(REG_TPROC_CFG, prot, data_wr, resp);
   @ (posedge s_ps_dma_aclk); #0.1;

   

end
endtask


task WRITE_AXI(integer PORT_AXI, DATA_AXI); begin
   //$display("Write to AXI");
   //$display("PORT %d",  PORT_AXI);
   //$display("DATA %d",  DATA_AXI);
   @ (posedge s_ps_dma_aclk); #0.1;
   axi_mst_0_agent.AXI4LITE_WRITE_BURST(PORT_AXI, prot, DATA_AXI, resp);
   end
endtask

task READ_AXI(integer ADDR_AXI); begin
   @ (posedge s_ps_dma_aclk); #0.1;
   axi_mst_0_agent.AXI4LITE_READ_BURST(ADDR_AXI, 0, DATA_RD, resp);
      $display("READ AXI_DATA %d",  DATA_RD);
   end
endtask

task COND_CLEAR; begin
   $display("COND CLEAR");
   @ (posedge s_ps_dma_aclk); #0.1;
   axi_mst_0_agent.AXI4LITE_WRITE_BURST(REG_TPROC_CTRL, prot, 2048, resp);
   end
endtask

task COND_SET; begin
   $display("COND SET");
   @ (posedge s_ps_dma_aclk); #0.1;
   axi_mst_0_agent.AXI4LITE_WRITE_BURST(REG_TPROC_CTRL, prot, 20481024, resp);
   end
endtask


integer cnt ;
integer axi_addr ;
integer num;

task TEST_STATES; begin
   $display("TEST TPROC STATES");

// PROCESSOR START
   #100;
   @ (posedge c_clk); #0.1;
   proc_start_i   = 1'b1;
   @ (posedge c_clk); #0.1;
   proc_start_i   = 1'b0;
// PROCESSOR STOP
   #100;
   @ (posedge c_clk); #0.1;
   proc_stop_i   = 1'b1;
   @ (posedge c_clk); #0.1;
   proc_stop_i   = 1'b0;
// PROCESSOR START
   #100;
   @ (posedge c_clk); #0.1;
   proc_start_i   = 1'b1;
   @ (posedge c_clk); #0.1;
   proc_start_i   = 1'b0;

// CORE STOP
   #100;
   @ (posedge c_clk); #0.1;
   core_stop_i   = 1'b1;
   @ (posedge c_clk); #0.1;
   core_stop_i   = 1'b0;
// CORE START
   #100;
   @ (posedge c_clk); #0.1;
   core_start_i   = 1'b1;
   @ (posedge c_clk); #0.1;
   core_start_i   = 1'b0;

// PROCESSOR START
   #100;
   @ (posedge c_clk); #0.1;
   proc_start_i   = 1'b1;
   @ (posedge c_clk); #0.1;
   proc_start_i   = 1'b0;

// CORE START
   #100;
   @ (posedge c_clk); #0.1;
   core_start_i   = 1'b1;
   @ (posedge c_clk); #0.1;
   core_start_i   = 1'b0;

// TIME RESET
   #100;
   @ (posedge t_clk); #0.1;
   time_rst_i   = 1'b1;
   @ (posedge t_clk); #0.1;
   time_rst_i   = 1'b0;
// TIME INIT
   #100;
   @ (posedge t_clk); #0.1;
   time_init_i  = 1'b1;
   offset_dt_i   = 100;
   @ (posedge t_clk); #0.1;
   time_init_i   = 1'b0;
// TIME UPDATE
   #100;
   @ (posedge t_clk); #0.1;
   time_updt_i  = 1'b1;
   offset_dt_i   = 50;
   @ (posedge t_clk); #0.1;
   time_updt_i   = 1'b0;
      
   @ (posedge c_clk); #0.1;


   end
endtask


task TEST_AXI (); begin
   $display("-----Writting AXI ");
   WRITE_AXI( REG_TPROC_CTRL , 1); //TIME_RST
   WRITE_AXI( REG_TPROC_CTRL , 2); //TIME_UPDT
   WRITE_AXI( REG_TPROC_CTRL , 4); //PROC_START
   WRITE_AXI( REG_TPROC_CTRL , 8); //PROC_STOP
   WRITE_AXI( REG_TPROC_CTRL , 16); //CORE_START
   WRITE_AXI( REG_TPROC_CTRL , 32); //CORE_STOP
   WRITE_AXI( REG_TPROC_CTRL , 64); //PROC_RST
   WRITE_AXI( REG_TPROC_CTRL , 128); //PROC_RUN
   WRITE_AXI( REG_TPROC_CTRL , 256); //PROC_PAUSE
   WRITE_AXI( REG_TPROC_CTRL , 512); //PROC_FREEZE
   WRITE_AXI( REG_TPROC_CTRL , 8); //PROC_STOP
   WRITE_AXI( REG_TPROC_CTRL , 1024); //PROC_STEP
   WRITE_AXI( REG_TPROC_CTRL , 2048); //CORE_STEP
   WRITE_AXI( REG_TPROC_CTRL , 4096); //TIME_STEP

   #100;
   WRITE_AXI( REG_TPROC_CTRL , 8192); //PROC_START
   WRITE_AXI( REG_TPROC_CTRL , 16384); //PROC_RST
   #100;
   

end
endtask

endmodule




