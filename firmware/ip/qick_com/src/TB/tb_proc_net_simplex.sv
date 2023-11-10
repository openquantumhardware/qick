///////////////////////////////////////////////////////////////////////////////
//  FERMI RESEARCH LAB
///////////////////////////////////////////////////////////////////////////////
//  Author         : mdife
///////////////////////////////////////////////////////////////////////////////

`include "_tproc_defines.svh"
`timescale 1ns/10ps

import axi_vip_pkg::*;
import axi_mst_0_pkg::*;

//`define T_TCLK         1.953125  // Half Clock Period for Simulation
`define T_TCLK         2.034  // Half Clock Period for Simulation
`define T_CCLK         2.034 // Half Clock Period for Simulation
`define T_SCLK         5.005  // Half Clock Period for Simulation
`define T_ICLK         10  // Half Clock Period for Simulation
`define T_GTCLK         3.2  // Half Clock Period GT CLK 156.25

// 0 SIM_LEVEL -> NO SIMULATION > SYNTH
// 1 SIM_LEVEL -> SIMULATION NO AURORA
// 2 SIM_LEVEL -> SIMULATION YES AURORA

localparam SIM_LEVEL = 1;


`define DUAL_CORE        0
`define IO_CTRL          0
`define DEBUG            1
`define TNET             0
`define CUSTOM_PERIPH    1
`define LFSR             1
`define DIVIDER          1
`define ARITH            1
`define TIME_READ        1
`define FIFO_DEPTH       3
`define PMEM_AW          8 
`define DMEM_AW          4 
`define WMEM_AW          5 
`define REG_AW           4 
`define IN_PORT_QTY      2
`define OUT_TRIG_QTY     8
`define OUT_DPORT_QTY    4
`define OUT_DPORT_DW     8
`define OUT_WPORT_QTY    2 



module tb_axis_proc_tnet_simplex ();

///////////////////////////////////////////////////////////////////////////////

// VIP Agent
axi_mst_0_mst_t 	axi_mst_0_agent;
xil_axi_prot_t  prot        = 0;


// Signals
reg   t_clk, c_clk, ps_clk, init_clk, gt_clk;
reg rst_ni, rst_ni_2, rst_ni_3;
reg[31:0]       data_wr     = 32'h12345678;
xil_axi_resp_t  resp;

//AXI-LITE
wire [7:0]             s_axi_awaddr , net_s_axi_awaddr , proc_s_axi_awaddr     ;
wire [2:0]             s_axi_awprot , net_s_axi_awprot , proc_s_axi_awprot     ;
wire                   s_axi_awvalid, net_s_axi_awvalid, proc_s_axi_awvalid    ;
wire                   s_axi_awready, net_s_axi_awready, proc_s_axi_awready    ;
wire [31:0]            s_axi_wdata  , net_s_axi_wdata  , proc_s_axi_wdata      ;
wire [3:0]             s_axi_wstrb  , net_s_axi_wstrb  , proc_s_axi_wstrb      ;
wire                   s_axi_wvalid , net_s_axi_wvalid , proc_s_axi_wvalid     ;
wire                   s_axi_wready , net_s_axi_wready , proc_s_axi_wready     ;
wire  [1:0]            s_axi_bresp  , net_s_axi_bresp  , proc_s_axi_bresp      ;
wire                   s_axi_bvalid , net_s_axi_bvalid , proc_s_axi_bvalid     ;
wire                   s_axi_bready , net_s_axi_bready , proc_s_axi_bready     ;
wire [7:0]             s_axi_araddr , net_s_axi_araddr , proc_s_axi_araddr     ;
wire [2:0]             s_axi_arprot , net_s_axi_arprot , proc_s_axi_arprot     ;
wire                   s_axi_arvalid, net_s_axi_arvalid, proc_s_axi_arvalid    ;
wire                   s_axi_arready, net_s_axi_arready, proc_s_axi_arready    ;
wire  [31:0]           s_axi_rdata  , net_s_axi_rdata  , proc_s_axi_rdata      ;
wire  [1:0]            s_axi_rresp  , net_s_axi_rresp  , proc_s_axi_rresp      ;
wire                   s_axi_rvalid , net_s_axi_rvalid , proc_s_axi_rvalid     ;
wire                   s_axi_rready , net_s_axi_rready , proc_s_axi_rready     ;

//////////////////////////////////////////////////////////////////////////
//  CLK Generation
initial begin
  t_clk = 1'b0;
  forever # (`T_TCLK) t_clk = ~t_clk;
end
initial begin
  c_clk = 1'b0;
  forever # (`T_CCLK) c_clk = ~c_clk;
end
initial begin
  ps_clk = 1'b0;
  forever # (`T_SCLK) ps_clk = ~ps_clk;
end
initial begin
  init_clk = 1'b0;
  forever # (`T_ICLK) init_clk = ~init_clk;
end
initial begin
  gt_clk = 1'b0;
  forever # (`T_GTCLK) gt_clk = ~gt_clk;
end

wire gt_refclk1_p, gt_refclk1_n;

assign gt_refclk1_p = gt_clk;
assign gt_refclk1_n = ~gt_clk;

reg ready;
integer cc;


reg sync_pulse;
initial begin
   sync_pulse = 1'b0;
   forever begin
      #100000 ;
      sync_pulse = 1'b1;
      #100 ;
      sync_pulse = 1'b0;
   end
end

initial begin
   cc = 8;
   forever begin
      ready = 1'b1;
      cc = cc+1;
      #500 ;
      if (cc == 10) begin
         ready = 1'b0;
         @ (posedge ps_clk);
         @ (posedge ps_clk);
         @ (posedge ps_clk);
         @ (posedge ps_clk);
         @ (posedge ps_clk);
         @ (posedge ps_clk);
         @ (posedge ps_clk);
         @ (posedge ps_clk);
         #1;
         ready = 1'b1;
         cc = 0;
      end 
      #500 ;
      ready = 1'b0;
      @ (posedge ps_clk);
      @ (posedge ps_clk);
      #1;
      end
end

// PROCESSOR SIGNALS
reg [255 :0]       s_dma_axis_tdata_i   ;
reg                s_dma_axis_tlast_i   ;
reg                s_dma_axis_tvalid_i  ;
reg                m_dma_axis_tready_i  ;
reg [63 :0]        port_0_dt_i          ;
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

wire                periph_en_o   ;
wire  [4 :0]        periph_op_o   ;
wire  [31:0]        periph_a_dt_o ;
wire  [31:0]        periph_b_dt_o ;
wire  [31:0]        periph_c_dt_o ;
wire  [31:0]        periph_d_dt_o ;
reg                periph_rdy_i=0    ;
reg  [31 :0]       periph_dt_i [2] ;

//PROC-NET Conection
wire               tnet_en_o        ;
wire  [4 :0]       tnet_op_o        ;
wire  [31:0]       tnet_a_dt_o      ;
wire  [31:0]       tnet_b_dt_o      ;
wire  [31:0]       tnet_c_dt_o      ;
wire  [31:0]       tnet_d_dt_o      ;
reg                tnet_rdy_i       ;
reg  [31 :0]       tnet_dt_i [2]    ;

reg [31:0] axi_dt;
reg axi_dest;

// QNET > Register ADDRESS
parameter TNET_CTRL     = 0  * 4 ;
parameter TNET_CFG      = 1  * 4 ;
parameter TNET_ADDR     = 2  * 4 ;
parameter TNET_LEN      = 3  * 4 ;
parameter REG_AXI_DT1   = 4  * 4 ;
parameter REG_AXI_DT2   = 5  * 4 ;
parameter REG_AXI_DT3   = 6  * 4 ;
parameter NN            = 7  * 4 ;
parameter ID            = 8  * 4 ;
parameter CD            = 9  * 4 ;
parameter RTD           = 10  * 4 ;
parameter VERSION       = 11 * 4 ;
parameter TNET_W_DT1    = 12 * 4 ;
parameter TNET_W_DT2    = 13 * 4 ;
parameter TNET_STATUS   = 14 * 4 ;
parameter TNET_DEBUG    = 15 * 4 ;
// QPROC > Register ADDRESS
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


reg    s0_axis_tvalid ,    s1_axis_tvalid ;
reg [15:0] waves, wtime;

reg         c_cmd_i  ;
reg [4 :0]  c_op_i;
reg [31:0]  c_dt_1_i, c_dt_2_i, c_dt_3_i ;


reg [47:0] t_time_abs1, t_time_abs2, t_time_abs3, t_time_abs4, t_time_abs5;

reg         proc_start_i, proc_stop_i ;
wire        core_start_1, core_start_2, core_start_3, core_start_4, core_start_5;
wire        core_stop_1 , core_stop_2 , core_stop_3 , core_stop_4 , core_stop_5 ;
wire        time_rst_1  , time_rst_2  , time_rst_3  , time_rst_4  , time_rst_5  ;
wire        time_init_1 , time_init_2 , time_init_3 , time_init_4 , time_init_5 ;
wire        time_updt_1 , time_updt_2 , time_updt_3 , time_updt_4 , time_updt_5 ;
wire [31:0] time_off_dt_1   , time_off_dt_2   , time_off_dt_3   , time_off_dt_4   , time_off_dt_5   ;

wire ready_1;
reg  reset_i, start_i, stop_i, init_i;
reg time_updt_i;
wire [63:0] axi_tx_tdata_A_TX_1, axi_tx_tdata_A_TX_2, axi_tx_tdata_A_TX_3;
wire [63:0] axi_tx_tdata_B_TX_1, axi_tx_tdata_B_TX_2, axi_tx_tdata_B_TX_3;
wire txn_A_1, txn_A_2, txn_A_3;
wire txp_A_1, txp_A_2, txp_A_3;
wire txn_B_1, txn_B_2, txn_B_3;
wire txp_B_1, txp_B_2, txp_B_3;


axi_mst_0 axi_mst_0_i
	(
		.aclk			   (ps_clk		),
		.aresetn		   (rst_ni	),
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


axis_qick_processor # (
   .DUAL_CORE      (  `DUAL_CORE   ) ,
   .IO_CTRL        (  `IO_CTRL   ) ,
   .DEBUG          (  `DEBUG     ) ,
   .TNET           (  `TNET      ) ,
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
   .t_clk_i              ( t_clk               ) ,
   .t_resetn             ( rst_ni              ) ,
   .c_clk_i              ( c_clk               ) ,
   .c_resetn             ( rst_ni              ) ,
   .ps_clk_i             ( ps_clk       ) ,
   .ps_resetn            ( rst_ni    ) ,
   .proc_start_i         ( proc_start_i        ) ,
   .proc_stop_i          ( proc_stop_i         ) ,
   .core_start_i         ( core_start_1        ) ,
   .core_stop_i          ( core_stop_1         ) ,
   .time_rst_i           ( time_rst_1          ) ,
   .time_init_i          ( time_init_1         ) ,
   .time_updt_i          ( time_updt_1         ) ,
   .time_dt_i            ( time_dt_1         ) ,
   .t_time_abs_o         ( t_time_abs1        ) ,
   .ps_debug_do          ( ps_debug_do         ) ,
   .tnet_en_o            ( c_cmd_i           ) ,
   .tnet_op_o            ( c_op_i           ) ,
   .tnet_a_dt_o          ( c_dt_1_i         ) ,
   .tnet_b_dt_o          ( c_dt_2_i         ) ,
   .tnet_c_dt_o          ( c_dt_3_i         ) ,
   .tnet_d_dt_o          (          ) ,
   .tnet_rdy_i           ( ready_1          ) ,
   .tnet_dt1_i           ( tnet_dt1_1          ) ,
   .tnet_dt2_i           ( tnet_dt2_1          ) ,
   .periph_en_o          ( periph_en_o         ) ,
   .periph_op_o          ( periph_op_o         ) ,
   .periph_a_dt_o        ( periph_a_dt_o       ) ,
   .periph_b_dt_o        ( periph_b_dt_o       ) ,
   .periph_c_dt_o        ( periph_c_dt_o       ) ,
   .periph_d_dt_o        ( periph_d_dt_o       ) ,   
   .periph_rdy_i         ( periph_rdy_i        ) ,   
   .periph_dt1_i         ( periph_dt_i[0]      ) ,   
   .periph_dt2_i         ( periph_dt_i[1]      ) ,   
   .s_dma_axis_tdata_i   ( s_dma_axis_tdata_i  ) ,
   .s_dma_axis_tlast_i   ( s_dma_axis_tlast_i  ) ,
   .s_dma_axis_tvalid_i  ( s_dma_axis_tvalid_i ) ,
   .s_dma_axis_tready_o  ( s_dma_axis_tready_o ) ,
   .m_dma_axis_tdata_o   ( m_dma_axis_tdata_o  ) ,
   .m_dma_axis_tlast_o   ( m_dma_axis_tlast_o  ) ,
   .m_dma_axis_tvalid_o  ( m_dma_axis_tvalid_o ) ,
   .m_dma_axis_tready_i  ( m_dma_axis_tready_i ) ,
   .s0_axis_tdata        ( {60'd0 , trig_3, trig_2, trig_1, trig_0 } ) ,
   .s0_axis_tvalid       ( 1'b1      ) ,
   .s1_axis_tdata        ( 64'd2020        ) ,
   .s1_axis_tvalid       ( 1'b1      ) ,
   .s2_axis_tdata        ( 64'd2    ) ,
   .s2_axis_tvalid       ( 1'b1     ) ,
   .s3_axis_tdata        ( 64'd3    ) ,
   .s3_axis_tvalid       ( 1'b1     ) ,
   .s4_axis_tdata        ( 64'd4    ) ,
   .s4_axis_tvalid       ( 1'b1     ) ,
   .s5_axis_tdata        ( 64'd5    ) ,
   .s5_axis_tvalid       ( 1'b0     ) ,
   .s6_axis_tdata        ( 64'd6    ) ,
   .s6_axis_tvalid       ( 1'b0     ) ,
   .s7_axis_tdata        ( 64'd7    ) ,
   .s7_axis_tvalid       ( 1'b0     ) , 
   .s8_axis_tdata        ( 64'd8    ) ,
   .s8_axis_tvalid       ( 1'b0     ) , 
   .s9_axis_tdata        ( 64'd9    ) ,
   .s9_axis_tvalid       ( 1'b0     ) , 
   .s10_axis_tdata       ( 64'd10    ) ,
   .s10_axis_tvalid      ( 1'b0     ) , 
   .s11_axis_tdata       ( 64'd11    ) ,
   .s11_axis_tvalid      ( 1'b0     ) , 
   .s12_axis_tdata       ( 64'd12    ) ,
   .s12_axis_tvalid      ( 1'b0     ) , 
   .s13_axis_tdata       ( 64'd13    ) ,
   .s13_axis_tvalid      ( 1'b0     ) , 
   .s14_axis_tdata       ( 64'd14    ) ,
   .s14_axis_tvalid      ( 1'b0     ) , 
   .s15_axis_tdata       ( 64'd15    ) ,
   .s15_axis_tvalid      ( 1'b0     ) , 
   .s_axi_awaddr         ( proc_s_axi_awaddr[7:0]   ) ,
   .s_axi_awprot         ( proc_s_axi_awprot        ) ,
   .s_axi_awvalid        ( proc_s_axi_awvalid       ) ,
   .s_axi_awready        ( proc_s_axi_awready       ) ,
   .s_axi_wdata          ( proc_s_axi_wdata         ) ,
   .s_axi_wstrb          ( proc_s_axi_wstrb         ) ,
   .s_axi_wvalid         ( proc_s_axi_wvalid        ) ,
   .s_axi_wready         ( proc_s_axi_wready        ) ,
   .s_axi_bresp          ( proc_s_axi_bresp         ) ,
   .s_axi_bvalid         ( proc_s_axi_bvalid        ) ,
   .s_axi_bready         ( proc_s_axi_bready        ) ,
   .s_axi_araddr         ( proc_s_axi_araddr[7:0]   ) ,
   .s_axi_arprot         ( proc_s_axi_arprot        ) ,
   .s_axi_arvalid        ( proc_s_axi_arvalid       ) ,
   .s_axi_arready        ( proc_s_axi_arready       ) ,
   .s_axi_rdata          ( proc_s_axi_rdata         ) ,
   .s_axi_rresp          ( proc_s_axi_rresp         ) ,
   .s_axi_rvalid         ( proc_s_axi_rvalid        ) ,
   .s_axi_rready         ( proc_s_axi_rready        ) ,
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
   .trig_0_o ( trig_0 ) ,
   .trig_1_o ( trig_1 ) ,
   .trig_2_o ( trig_2 ) ,
   .trig_3_o ( trig_3 ) ,
   .trig_4_o ( trig_4 ) ,
   .trig_5_o ( trig_5 ) ,
   .trig_6_o ( trig_6 ) ,
   .trig_7_o ( trig_7 ) ,
   .port_0_dt_o          ( port_0_dt_o         ) ,
   .port_1_dt_o          ( port_1_dt_o         ) ,
   .port_2_dt_o          ( port_2_dt_o         ) ,
   .port_3_dt_o          ( port_3_dt_o         ) );

reg [31:0] offset_t1_t2, offset_t1_t3, offset_t1_t4, offset_t1_t5;

   
//Simulate Core 2 and 3
always_ff @(posedge t_clk) 
   if (!rst_ni) begin
      t_time_abs2 <= ($random %1024)+1023;;
      t_time_abs3 <= ($random %1024)+1023;;
      t_time_abs4 <= ($random %1024)+1023;;
      t_time_abs5 <= ($random %1024)+1023;;
   end else begin 
      offset_t1_t2 = t_time_abs2 - t_time_abs1;
      offset_t1_t3 = t_time_abs3 - t_time_abs1;
      offset_t1_t4 = t_time_abs4 - t_time_abs1;
      offset_t1_t5 = t_time_abs5 - t_time_abs1;
      if       ( time_rst_2 )      t_time_abs2   <= 0;
      else if  ( time_init_2)      t_time_abs2   <= time_off_dt_2;
      else if  ( time_updt_2) t_time_abs2   <= t_time_abs2 + time_off_dt_2;
      else                    t_time_abs2   <= t_time_abs2 + 1'b1;

      if       ( time_rst_3)      t_time_abs3   <= 0;
      else if  ( time_init_3)      t_time_abs3   <= time_off_dt_3;
      else if  ( time_updt_3) t_time_abs3   <= t_time_abs3 + time_off_dt_3;
      else                    t_time_abs3   <= t_time_abs3 + 1'b1;

      if       ( time_rst_4)      t_time_abs4   <= 0;
      else if  ( time_init_4)      t_time_abs4   <= time_off_dt_4;
      else if  ( time_updt_4) t_time_abs4   <= t_time_abs4 + time_off_dt_4;
      else                    t_time_abs4   <= t_time_abs4 + 1'b1;

      if       ( time_rst_5)      t_time_abs5   <= 0;
      else if  ( time_init_5)      t_time_abs5   <= time_off_dt_5;
      else if  ( time_updt_5) t_time_abs5   <= t_time_abs5 + time_off_dt_5;
      else                    t_time_abs5   <= t_time_abs5 + 1'b1;
   end




assign proc_s_axi_awaddr       = axi_dest ? 0 : s_axi_awaddr   ;
assign proc_s_axi_awprot       = axi_dest ? 0 : s_axi_awprot   ;
assign proc_s_axi_awvalid      = axi_dest ? 0 : s_axi_awvalid  ;
assign proc_s_axi_wdata        = axi_dest ? 0 : s_axi_wdata    ;
assign proc_s_axi_wstrb        = axi_dest ? 0 : s_axi_wstrb    ;
assign proc_s_axi_wvalid       = axi_dest ? 0 : s_axi_wvalid   ;
assign proc_s_axi_bready       = axi_dest ? 0 : s_axi_bready   ;
assign proc_s_axi_araddr       = axi_dest ? 0 : s_axi_araddr   ;
assign proc_s_axi_arprot       = axi_dest ? 0 : s_axi_arprot   ;
assign proc_s_axi_arvalid      = axi_dest ? 0 : s_axi_arvalid  ;
assign proc_s_axi_rready       = axi_dest ? 0 : s_axi_rready   ;

assign s_axi_awready           = axi_dest ? net_s_axi_awready : proc_s_axi_awready;
assign s_axi_wready            = axi_dest ? net_s_axi_wready  : proc_s_axi_wready ;
assign s_axi_bresp             = axi_dest ? net_s_axi_bresp   : proc_s_axi_bresp  ;
assign s_axi_bvalid            = axi_dest ? net_s_axi_bvalid  : proc_s_axi_bvalid ;
assign s_axi_arready           = axi_dest ? net_s_axi_arready : proc_s_axi_arready;
assign s_axi_rdata             = axi_dest ? net_s_axi_rdata   : proc_s_axi_rdata  ;
assign s_axi_rresp             = axi_dest ? net_s_axi_rresp   : proc_s_axi_rresp  ;
assign s_axi_rvalid            = axi_dest ? net_s_axi_rvalid  : proc_s_axi_rvalid ;

assign net_s_axi_awaddr        = axi_dest ? s_axi_awaddr  : 0 ;
assign net_s_axi_awprot        = axi_dest ? s_axi_awprot  : 0 ;
assign net_s_axi_awvalid       = axi_dest ? s_axi_awvalid : 0 ;
assign net_s_axi_wdata         = axi_dest ? s_axi_wdata   : 0 ;
assign net_s_axi_wstrb         = axi_dest ? s_axi_wstrb   : 0 ;
assign net_s_axi_wvalid        = axi_dest ? s_axi_wvalid  : 0 ;
assign net_s_axi_bready        = axi_dest ? s_axi_bready  : 0 ;
assign net_s_axi_araddr        = axi_dest ? s_axi_araddr  : 0 ;
assign net_s_axi_arprot        = axi_dest ? s_axi_arprot  : 0 ;
assign net_s_axi_arvalid       = axi_dest ? s_axi_arvalid : 0 ;
assign net_s_axi_rready        = axi_dest ? s_axi_rready  : 0 ;

axis_qick_network # ( 
   .SIMPLEX   ( 1 ) ,
   .SIM_LEVEL ( SIM_LEVEL )
) TNET_1 (
   .gt_refclk1_p        ( gt_refclk1_p         ) ,
   .gt_refclk1_n        ( gt_refclk1_n         ) ,
   .t_clk               ( t_clk              ) ,
   .t_aresetn           ( rst_ni             ) ,
   .c_clk               ( c_clk              ) ,
   .c_aresetn           ( rst_ni             ) ,
   .ps_clk              ( ps_clk             ) ,
   .ps_aresetn          ( rst_ni             ) ,
   .t_time_abs          ( t_time_abs1        ) ,
   .net_sync_i          ( sync_pulse         ) ,
   .net_sync_o          ( sync_out           ) ,
//CONTROL
   .c_cmd_i             ( c_cmd_i              ) ,
   .c_op_i              ( c_op_i               ) ,
   .c_dt1_i             ( c_dt_1_i              ) ,
   .c_dt2_i             ( c_dt_2_i              ) ,
   .c_dt3_i             ( c_dt_3_i              ) ,
   .c_ready_o           ( ready_1            ) ,
   .core_start_o        ( core_start_1         ) ,
   .core_stop_o         ( core_stop_1          ) ,
   .time_rst_o          ( time_rst_1           ) ,
   .time_init_o         ( time_init_1          ) ,
   .time_updt_o         ( time_updt_1          ) ,
   .time_off_dt_o       ( time_off_dt_1        ) ,
   .tnet_dt1_o          ( tnet_dt1_1           ) ,
   .tnet_dt2_o          ( tnet_dt2_1           ) ,
// SIMULATION
   .rxn_A_i              ( txn_B_3              ) ,
   .rxp_A_i              ( txp_B_3              ) ,
   .txn_B_o              ( txn_B_1              ) ,
   .txp_B_o              ( txp_B_1              ) ,
//LINK CHANNEL A
   .axi_rx_tdata_A_RX_i  ( axi_tx_tdata_B_TX_3  ) ,
   .axi_rx_tvalid_A_RX_i ( axi_tx_tvalid_B_TX_3 ) ,
   .axi_rx_tlast_A_RX_i  ( axi_tx_tlast_B_TX_3  ) ,
//LINK CHANNEL B
   .axi_tx_tdata_B_TX_o  ( axi_tx_tdata_B_TX_1  ) ,
   .axi_tx_tvalid_B_TX_o ( axi_tx_tvalid_B_TX_1 ) ,
   .axi_tx_tlast_B_TX_o  ( axi_tx_tlast_B_TX_1  ) ,
   .axi_tx_tready_B_TX_i ( ready ) ,
//AXI   
   .s_axi_awaddr       (  net_s_axi_awaddr        ) ,
   .s_axi_awprot       (  net_s_axi_awprot        ) ,
   .s_axi_awvalid      (  net_s_axi_awvalid       ) ,
   .s_axi_awready      (  net_s_axi_awready       ) ,
   .s_axi_wdata        (  net_s_axi_wdata         ) ,
   .s_axi_wstrb        (  net_s_axi_wstrb         ) ,
   .s_axi_wvalid       (  net_s_axi_wvalid        ) ,
   .s_axi_wready       (  net_s_axi_wready        ) ,
   .s_axi_bresp        (  net_s_axi_bresp         ) ,
   .s_axi_bvalid       (  net_s_axi_bvalid        ) ,
   .s_axi_bready       (  net_s_axi_bready        ) ,
   .s_axi_araddr       (  net_s_axi_araddr        ) ,
   .s_axi_arprot       (  net_s_axi_arprot        ) ,
   .s_axi_arvalid      (  net_s_axi_arvalid       ) ,
   .s_axi_arready      (  net_s_axi_arready       ) ,
   .s_axi_rdata        (  net_s_axi_rdata         ) ,
   .s_axi_rresp        (  net_s_axi_rresp         ) ,
   .s_axi_rvalid       (  net_s_axi_rvalid        ) ,
   .s_axi_rready       (  net_s_axi_rready        ) );


axis_qick_network  # ( 
   .SIMPLEX   ( 1 ) , 
   .SIM_LEVEL ( SIM_LEVEL ) 
) TNET_2 (
   .gt_refclk1_p        ( gt_refclk1_p         ) ,
   .gt_refclk1_n        ( gt_refclk1_n         ) ,
   .t_clk             ( t_clk              ) ,
   .t_aresetn            ( rst_ni_2             ) ,
   .c_clk             ( c_clk              ) ,
   .c_aresetn            ( rst_ni_2             ) ,
   .ps_clk            ( ps_clk             ) ,
   .ps_aresetn           ( rst_ni_2            ) ,
   .t_time_abs          ( t_time_abs2           ) ,
   .net_sync_i          ( sync_pulse         ) ,
   .net_sync_o          (            ) ,
//CONTROL
   .c_cmd_i             ( c_cmd_i              ) ,
   .c_op_i              ( c_op_i               ) ,
   .c_dt1_i             ( c_dt_1_i              ) ,
   .c_dt2_i             ( c_dt_2_i              ) ,
   .c_dt3_i             ( c_dt_3_i              ) ,
   .c_ready_o           ( ready_2            ) ,
   .core_start_o        ( core_start_2         ) ,
   .core_stop_o         ( core_stop_2          ) ,
   .time_rst_o          ( time_rst_2           ) ,
   .time_init_o         ( time_init_2          ) ,
   .time_updt_o         ( time_updt_2          ) ,
   .time_off_dt_o       ( time_off_dt_2        ) ,
   .tnet_dt1_o          ( tnet_dt1_2           ) ,
   .tnet_dt2_o          ( tnet_dt2_2           ) ,
// SIMULATION
   .rxn_A_i              ( txn_B_1              ) ,
   .rxp_A_i              ( txp_B_1              ) ,
   .txn_B_o              ( txn_B_2              ) ,
   .txp_B_o              ( txp_B_2              ) ,
//LINK CHANNEL A
   .axi_rx_tdata_A_RX_i  ( axi_tx_tdata_B_TX_1  ) ,
   .axi_rx_tvalid_A_RX_i ( axi_tx_tvalid_B_TX_1 ) ,
   .axi_rx_tlast_A_RX_i  ( axi_tx_tlast_B_TX_1  ) ,
//LINK CHANNEL B
   .axi_tx_tdata_B_TX_o  ( axi_tx_tdata_B_TX_2  ) ,
   .axi_tx_tvalid_B_TX_o ( axi_tx_tvalid_B_TX_2 ) ,
   .axi_tx_tlast_B_TX_o  ( axi_tx_tlast_B_TX_2  ) ,
   .axi_tx_tready_B_TX_i ( ready ) ,
//AXI   
   .s_axi_awaddr         ( 0 ) ,
   .s_axi_awprot         ( 0 ) ,
   .s_axi_awvalid        ( 0 ) ,
   .s_axi_awready        (   ) ,
   .s_axi_wdata          ( 0 ) ,
   .s_axi_wstrb          ( 0 ) ,
   .s_axi_wvalid         ( 0 ) ,
   .s_axi_wready         (   ) ,
   .s_axi_bresp          (   ) ,
   .s_axi_bvalid         (   ) ,
   .s_axi_bready         ( 0 ) ,
   .s_axi_araddr         ( 0 ) ,
   .s_axi_arprot         ( 0 ) ,
   .s_axi_arvalid        ( 0 ) ,
   .s_axi_arready        (   ) ,
   .s_axi_rdata          (   ) ,
   .s_axi_rresp          (   ) ,
   .s_axi_rvalid         (   ) ,
   .s_axi_rready         (   ) );


      
axis_qick_network  # ( 
   .SIMPLEX   ( 1 ) , 
   .SIM_LEVEL ( SIM_LEVEL ) 
) TNET_3 (
   .gt_refclk1_p        ( gt_refclk1_p         ) ,
   .gt_refclk1_n        ( gt_refclk1_n         ) ,
   .t_clk             ( t_clk              ) ,
   .t_aresetn            ( rst_ni_3             ) ,
   .c_clk             ( c_clk              ) ,
   .c_aresetn            ( rst_ni_3             ) ,
   .ps_clk            ( ps_clk             ) ,
   .ps_aresetn           ( rst_ni_3            ) ,
   .t_time_abs          ( t_time_abs3           ) ,
   .net_sync_i          ( sync_pulse         ) ,
   .net_sync_o          (            ) ,
//CONTROL
   .c_cmd_i             ( c_cmd_i              ) ,
   .c_op_i              ( c_op_i               ) ,
   .c_dt1_i             ( c_dt_1_i              ) ,
   .c_dt2_i             ( c_dt_2_i              ) ,
   .c_dt3_i             ( c_dt_3_i              ) ,
   .c_ready_o           ( ready_3            ) ,
   .core_start_o        ( core_start_3         ) ,
   .core_stop_o         ( core_stop_3          ) ,
   .time_rst_o          ( time_rst_3           ) ,
   .time_init_o         ( time_init_3          ) ,
   .time_updt_o         ( time_updt_3          ) ,
   .time_off_dt_o       ( time_off_dt_3        ) ,
   .tnet_dt1_o          ( tnet_dt1_3           ) ,
   .tnet_dt2_o          ( tnet_dt2_3           ) ,
// SIMULATION
   .rxn_A_i              ( txn_B_2              ) ,
   .rxp_A_i              ( txp_B_2              ) ,
   .txn_B_o              ( txn_B_3              ) ,
   .txp_B_o              ( txp_B_3              ) ,
//LINK CHANNEL A
   .axi_rx_tdata_A_RX_i  ( axi_tx_tdata_B_TX_2  ) ,
   .axi_rx_tvalid_A_RX_i ( axi_tx_tvalid_B_TX_2 ) ,
   .axi_rx_tlast_A_RX_i  ( axi_tx_tlast_B_TX_2  ) ,
//LINK CHANNEL B
   .axi_tx_tdata_B_TX_o  ( axi_tx_tdata_B_TX_3  ) ,
   .axi_tx_tvalid_B_TX_o ( axi_tx_tvalid_B_TX_3 ) ,
   .axi_tx_tlast_B_TX_o  ( axi_tx_tlast_B_TX_3  ) ,
   .axi_tx_tready_B_TX_i ( ready ) ,
//AXI   
   .s_axi_awaddr         ( 0 ) ,
   .s_axi_awprot         ( 0 ) ,
   .s_axi_awvalid        ( 0 ) ,
   .s_axi_awready        (   ) ,
   .s_axi_wdata          ( 0 ) ,
   .s_axi_wstrb          ( 0 ) ,
   .s_axi_wvalid         ( 0 ) ,
   .s_axi_wready         (   ) ,
   .s_axi_bresp          (   ) ,
   .s_axi_bvalid         (   ) ,
   .s_axi_bready         ( 0 ) ,
   .s_axi_araddr         ( 0 ) ,
   .s_axi_arprot         ( 0 ) ,
   .s_axi_arvalid        ( 0 ) ,
   .s_axi_arready        (   ) ,
   .s_axi_rdata          (   ) ,
   .s_axi_rresp          (   ) ,
   .s_axi_rvalid         (   ) ,
   .s_axi_rready         (   ) );

assign axi_rx_tready_RX   = 1;
reg start_delay_1, start_delay_2;

assign rst_ni_2   = start_delay_1 ? 0 : rst_ni;
assign rst_ni_3   = start_delay_2 ? 0 : rst_ni;



reg [ 2:0] h_type  ;
reg [ 5:0] h_cmd   ;
reg [ 4:0] h_flags ;
reg [8:0] h_src  ;
reg [8:0] h_dst  ;


initial begin
   $display("START SIMULATION");
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
   
   
   
  	// Create agents.
	axi_mst_0_agent 	= new("axi_mst_0 VIP Agent",tb_axis_proc_tnet_simplex.axi_mst_0_i.inst.IF);
	// Set tag for agents.
	axi_mst_0_agent.set_agent_tag	("axi_mst_0 VIP");
	// Start agents.
	axi_mst_0_agent.start_master();

   AXIS_QPROC.QPROC.CORE_0.CORE_MEM.D_MEM.RAM = '{default:'0} ;
   AXIS_QPROC.QPROC.CORE_0.CORE_MEM.W_MEM.RAM = '{default:'0} ;
   AXIS_QPROC.QPROC.TRIG_FIFO[0].trig_fifo_inst.fifo_mem.RAM = '{default:'0} ;
   AXIS_QPROC.QPROC.DATA_FIFO[0].data_fifo_inst.fifo_mem.RAM = '{default:'0} ;
   AXIS_QPROC.QPROC.WAVE_FIFO[0].wave_fifo_inst.fifo_mem.RAM = '{default:'0} ;

   $readmemb("/home/mdifeder/repos/IPS/qick_processor/src/TB/prog.bin", AXIS_QPROC.QPROC.CORE_0.CORE_MEM.P_MEM.RAM);
   $readmemb("/home/mdifeder/repos/IPS/qick_processor/src/TB/wave.bin", AXIS_QPROC.QPROC.CORE_0.CORE_MEM.W_MEM.RAM);

   start_delay_1 = 1'b1;
   start_delay_2 = 1'b1;
   
   h_type   = 3'd0 ;
   h_cmd    = 6'd0 ;
   h_flags  = 5'd0 ;
   h_src    = 9'd0 ;
   h_dst    = 9'd0 ;
   rst_ni            = 1'b0;
   proc_start_i   = 1'b0 ;
   proc_stop_i    = 1'b0 ;
   axi_dt            = 0 ;
   axi_dest          = 1'b1 ;
   reset_i           = 1'b0 ;
   init_i            = 1'b0 ;
   start_i           = 1'b0 ;
   stop_i            = 1'b0 ;
   time_updt_i       =  1'b0 ;


   #10 ;

   @ (posedge ps_clk); #0.1;
   rst_ni            = 1'b1;
   #10 ;

   @ (posedge c_clk); #0.1;
   proc_start_i = 1'b1 ;
   @ (posedge c_clk); #0.1;
   proc_start_i = 1'b0 ;

#10000;
start_delay_1 = 1'b0;
#5000;
start_delay_2 = 1'b0;

   WRITE_AXI( REG_AXI_DT1 , 1);
   WRITE_AXI( REG_AXI_DT2 , 2);
   WRITE_AXI( REG_AXI_DT3 , {16'd0, 16'd2});

   //GET NET
   wait (ready_1==1'b1);
   WRITE_AXI( TNET_CTRL, 1); 
   #100;
   //SET_NET
   wait (ready_1==1'b1);
   WRITE_AXI( TNET_CTRL, 2); 
   #100;
   //SYN_1
   wait (ready_1==1'b1);
   WRITE_AXI( TNET_CTRL, 3); 
   #100;
   
   // GET_OFFSET
   #100;
   wait (ready_1==1'b1);
   WRITE_AXI( REG_AXI_DT3    , {16'd0, 16'd2}); // NODE
   WRITE_AXI( TNET_CTRL, 7); 
// GET_OFFSET
   #100;
   wait (ready_1==1'b1);
   WRITE_AXI( REG_AXI_DT3    , {16'd0, 16'd2}); // NODE
   WRITE_AXI( TNET_CTRL, 7); 


   //GET NET
   wait (ready_1==1'b1);
   WRITE_AXI( TNET_CTRL, 1); 
   #100;



   //GET NET
   wait (ready_1==1'b1);
   WRITE_AXI( TNET_CTRL, 1); 
   #100;
   //GET NET
   wait (ready_1==1'b1);
   WRITE_AXI( TNET_CTRL, 1); 
   #100;
   //GET NET
   wait (ready_1==1'b1);
   WRITE_AXI( TNET_CTRL, 1); 
   #100;
   //GET NET
   wait (ready_1==1'b1);
   WRITE_AXI( TNET_CTRL, 1); 
   #100;
   //GET NET
   wait (ready_1==1'b1);
   WRITE_AXI( TNET_CTRL, 1); 
   #100;
   //GET NET
   wait (ready_1==1'b1);
   WRITE_AXI( TNET_CTRL, 1); 
   #100;
   //GET NET
   wait (ready_1==1'b1);
   WRITE_AXI( TNET_CTRL, 1); 
   #100;
   //GET NET
   wait (ready_1==1'b1);
   WRITE_AXI( TNET_CTRL, 1); 
   #100;
   //SET NET
   #1000;
   wait (ready_1==1'b1);
   WRITE_AXI( TNET_CTRL, 2);  
   //SYNC_1
   #1000;
   wait (ready_1==1'b1);
   WRITE_AXI( REG_AXI_DT1 , 7); // DATA1
   WRITE_AXI( REG_AXI_DT2 , 127); // DATA2
   WRITE_AXI( REG_AXI_DT3 , {14'd1460, 10'd0}); // SYNC TIME
   WRITE_AXI( TNET_CTRL, 3);  
   //SYNC_2
   #1000;
   wait (ready_1==1'b1);
   WRITE_AXI( TNET_CTRL, 4);  
   //SYNC_3
   #1000;
   wait (ready_1==1'b1);
   WRITE_AXI( TNET_CTRL, 5);  
   //SYNC_4
   #1000;
   wait (ready_1==1'b1);
   WRITE_AXI( TNET_CTRL, 6);  


   // GET_OFFSET
   #100;
   wait (ready_1==1'b1);
   WRITE_AXI( REG_AXI_DT3    , {16'd0, 16'd2}); // NODE
   WRITE_AXI( TNET_CTRL, 7); 

   //UPDF_OFF
   #100;
   wait (ready_1==1'b1);
   WRITE_AXI( REG_AXI_DT1 , 4); // DATA
   WRITE_AXI( REG_AXI_DT3    , {16'd0, 16'd2}); // NODE
   WRITE_AXI( TNET_CTRL, 8); // UPDT_OFFSET (NODE - DATA) 


   //SET_DT
   #5000;
   wait (ready_1==1'b1);
   WRITE_AXI( REG_AXI_DT1 , 7); // DATA1
   WRITE_AXI( REG_AXI_DT2 , 127); // DATA2
   WRITE_AXI( REG_AXI_DT3 , {16'd0, 16'd2}); // NODE
   WRITE_AXI( TNET_CTRL, 9); // SET_DT (NODE - DATA)

   //GET_DT
   #500;
   wait (ready_1==1'b1);
   WRITE_AXI( REG_AXI_DT3    , {16'd0, 16'd2}); // NODE
   WRITE_AXI( TNET_CTRL, 10); // GET_DT (NODE - DATA)

WRITE_AXI( TNET_CFG, 1); // CHANGE DEBUG SIGNAL 
WRITE_AXI( TNET_CFG, 2); // CHANGE DEBUG SIGNAL 
WRITE_AXI( TNET_CFG, 3); // CHANGE DEBUG SIGNAL 
WRITE_AXI( TNET_CFG, 0); // CHANGE DEBUG SIGNAL 
   
   







   //GET_DT
   #500;
   wait (ready_1==1'b1);
   WRITE_AXI( REG_AXI_DT3    , {16'd0, 16'd3}); // NODE
   WRITE_AXI( TNET_CTRL, 10); // GET_DT (NODE - DATA)
   
   //GET_DT
   #500;
   wait (ready_1==1'b1);
   WRITE_AXI( REG_AXI_DT3    , {16'd0, 16'd4}); // NODE
   WRITE_AXI( TNET_CTRL, 10); // GET_DT (NODE - DATA)
   
   
   
   
  // SYNC_NET
   #10000;
   wait (ready_1==1'b1);
   WRITE_AXI( TNET_CTRL, 8); // SYNC_NET (NO PARAMETER / Automatic > Delay, TimeWait)


   #1000;
   wait (ready_1==1'b1);
   WRITE_AXI( REG_AXI_DT3    , {16'd0, 16'd2}); // NODE
   WRITE_AXI( TNET_CTRL, 5); // GET_OFFSET
   wait (ready_1==1'b1);
   #1000;
   wait (ready_1==1'b1);
   WRITE_AXI( REG_AXI_DT3    , {16'd0, 16'd2}); // NODE
   WRITE_AXI( TNET_CTRL, 5); // GET_OFFSET
   wait (ready_1==1'b1);
   #2000;
   wait (ready_1==1'b1);
   WRITE_AXI( REG_AXI_DT3    , {16'd0, 16'd3}); // NODE
   WRITE_AXI( TNET_CTRL, 5); // GET_OFFSET
   wait (ready_1==1'b1);
   #1000;
   wait (ready_1==1'b1);
   WRITE_AXI( REG_AXI_DT3    , {16'd0, 16'd3}); // NODE
   WRITE_AXI( TNET_CTRL, 5); // GET_OFFSET
   wait (ready_1==1'b1);
   #3000;
   wait (ready_1==1'b1);
   WRITE_AXI( REG_AXI_DT3    , {16'd0, 16'd4}); // NODE
   WRITE_AXI( TNET_CTRL, 5); // GET_OFFSET
   #1000;
   wait (ready_1==1'b1);
   WRITE_AXI( REG_AXI_DT3    , {16'd0, 16'd4}); // NODE
   WRITE_AXI( TNET_CTRL, 5); // GET_OFFSET
   wait (ready_1==1'b1);

   #800;
     
   //SET NET
   #1000;
   wait (ready_1==1'b1);
   #10000;
   WRITE_AXI( TNET_CTRL, 2); // SET_NET  (NO PARAMETER / Automatic > RTD - CD - NN - ID) 


   axi_dest          = 1'b0 ;
   WRITE_AXI( REG_TPROC_CTRL , 8); //STOP
#1000;
   WRITE_AXI( REG_TPROC_CTRL , 4); //START
   axi_dest          = 1'b1 ;



   //UPDF_OFF
   #100;
   wait (ready_1==1'b1);
   WRITE_AXI( REG_AXI_DT1 , 4); // DATA
   WRITE_AXI( REG_AXI_DT3    , {16'd0, 16'd2}); // NODE
   WRITE_AXI( TNET_CTRL, 9); // UPDT_OFFSET (NODE - DATA)

//UPDF_OFF
   #100;
   wait (ready_1==1'b1);
   WRITE_AXI( REG_AXI_DT1 , 2); // DATA
   WRITE_AXI( REG_AXI_DT3    , {16'd2, 16'd3}); // NODE
   WRITE_AXI( TNET_CTRL, 9); // UPDT_OFFSET (NODE - DATA)

//UPDF_OFF
   #100;
   wait (ready_1==1'b1);
   WRITE_AXI( REG_AXI_DT1 , -2); // DATA
   WRITE_AXI( REG_AXI_DT3    , {16'd0, 16'd3}); // NODE
   WRITE_AXI( TNET_CTRL, 9); // UPDT_OFFSET (NODE - DATA)


   //SET_DT
   #100;
   wait (ready_1==1'b1);
   WRITE_AXI( REG_AXI_DT1 , 15); // DATA1
   WRITE_AXI( REG_AXI_DT2 , 255); // DATA2
   WRITE_AXI( REG_AXI_DT3    , {16'd2, 16'd0}); // NODE
   WRITE_AXI( TNET_CTRL, 10); // SET_DT (NODE - DATA)

   //SET_DT
   #100;
   wait (ready_1==1'b1);
   WRITE_AXI( REG_AXI_DT1 , 15); // DATA1
   WRITE_AXI( REG_AXI_DT2 , 255); // DATA2
   WRITE_AXI( TNET_CTRL, 10); // SET_DT (NODE - DATA)

   //SET_DT
   #100;
   wait (ready_1==1'b1);
   WRITE_AXI( REG_AXI_DT1 , 7); // DATA1
   WRITE_AXI( REG_AXI_DT2 , 127); // DATA2
   WRITE_AXI( REG_AXI_DT3    , {16'd3, 16'd0}); // NODE
   WRITE_AXI( TNET_CTRL, 10); // SET_DT (NODE - DATA)

   //GET_DT
   wait (ready_1==1'b1);
   WRITE_AXI( REG_AXI_DT3    , {16'd2, 16'd0}); // NODE
   WRITE_AXI( TNET_CTRL, 11); // GET_DT (NODE - DATA)

   axi_dest          = 1'b0 ;
   WRITE_AXI( REG_READ_SEL, 10); //SELECT READ
   #1000;
   WRITE_AXI( REG_READ_SEL, 11); //SELECT READ
   #1000;
   WRITE_AXI( REG_READ_SEL, 12); //SELECT READ
   #1000;
   WRITE_AXI( REG_READ_SEL, 13); //SELECT READ
   #1000;
   WRITE_AXI( REG_READ_SEL, 14); //SELECT READ
   #1000;
   WRITE_AXI( REG_READ_SEL, 15); //SELECT READ
   #1000;

   axi_dest          = 1'b1 ;



  #1000;
   //GET NET
   #1000;
   wait (ready_1==1'b1);
   WRITE_AXI( TNET_CTRL, 1); // GET_NET (NO PARAMETER)
   //SET NET
   #1000;
   wait (ready_1==1'b1);
   #10000;
   WRITE_AXI( TNET_CTRL, 2); // SET_NET  (NO PARAMETER / Automatic > RTD - CD - NN - ID) 
   // SYNC_NET
   #100;
   wait (ready_1==1'b1);
   WRITE_AXI( TNET_CTRL, 8); // SYNC_NET (NO PARAMETER / Automatic > Delay, TimeWait)
   


end


integer DATA_RD;

task WRITE_AXI(integer PORT_AXI, DATA_AXI); begin
   //$display("Write to AXI");
   //$display("PORT %d",  PORT_AXI);
   //$display("DATA %d",  DATA_AXI);
   @ (posedge ps_clk); #0.1;
   axi_mst_0_agent.AXI4LITE_WRITE_BURST(PORT_AXI, prot, DATA_AXI, resp);
   end
endtask

task READ_AXI(integer ADDR_AXI); begin
   @ (posedge ps_clk); #0.1;
   axi_mst_0_agent.AXI4LITE_READ_BURST(ADDR_AXI, 0, DATA_RD, resp);
      $display("READ AXI_DATA %d",  DATA_RD);
   end
endtask

integer cnt ;
integer axi_addr ;
integer num;

task TEST_AXI (); begin
   $display("-----Writting RANDOM AXI Address");
   for ( cnt = 0 ; cnt  < 16; cnt=cnt+1) begin
      axi_addr = cnt*4;
      axi_dt = cnt+1 ;
      //num = ($random %64)+31;
      //num = ($random %32)+31;
      //num = ($random %16)+15;
      //axi_addr = num*4;
      //axi_dt = num+1 ;
      #100
      $display("WRITE AXI_DATA %d",  axi_dt);
      WRITE_AXI( axi_addr, axi_dt); //SET
   end
   /*
   $display("-----Reading ALL AXI Address");
   for ( cnt = 0 ; cnt  <= 64; cnt=cnt+1) begin
      axi_addr = cnt*4;
      $display("READ AXI_ADDR %d",  axi_addr);
      READ_AXI( axi_addr);
      $display("READ AXI_DATA %d",  DATA_RD);
   end
   $display("-----FINISHED ");
   */
end
endtask


endmodule




