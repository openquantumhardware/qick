///////////////////////////////////////////////////////////////////////////////
//  Fermilab National Accelerator Laboratory
///////////////////////////////////////////////////////////////////////////////
// Description: 
// Test Bench for Qick Project
//////////////////////////////////////////////////////////////////////////////

`include "_qproc_defines.svh"

import axi_vip_pkg::*;
import axi_mst_0_pkg::*;

`define T_TCLK         1.302  // Half Clock Period for Simulation
`define T_CCLK         2.5    // Half Clock Period for Simulation
`define T_SCLK         5      // Half Clock Period for Simulation


`define GEN_SYNC         1
`define DUAL_CORE        0
`define IO_CTRL          1
`define DEBUG            3
`define TNET             0
`define QCOM             0
`define CUSTOM_PERIPH    1
`define LFSR             1
`define DIVIDER          1
`define ARITH            1
`define TIME_READ        1
`define FIFO_DEPTH       8
`define PMEM_AW          12 
`define DMEM_AW          14 
`define WMEM_AW          10
`define REG_AW           4 
`define IN_PORT_QTY      1
`define OUT_TRIG_QTY     1
`define OUT_DPORT_QTY    1
`define OUT_DPORT_DW     8
`define OUT_WPORT_QTY    1 

module tb_qick ();


// VIP Agents
axi_mst_0_mst_t     axi_mst_tproc_agent;
axi_mst_0_mst_t     axi_mst_sg_agent;


xil_axi_prot_t  prot        = 0;
reg[31:0]       data_wr     = 32'h12345678;
xil_axi_resp_t  resp;

//AXI-LITE TPROC
//wire                   s_axi_tproc_aclk       ;
wire                   s_ps_dma_aresetn    ;
wire [7:0]             s_axi_tproc_awaddr     ;
wire [2:0]             s_axi_tproc_awprot     ;
wire                   s_axi_tproc_awvalid    ;
wire                   s_axi_tproc_awready    ;
wire [31:0]            s_axi_tproc_wdata      ;
wire [3:0]             s_axi_tproc_wstrb      ;
wire [3:0]             s_axi_tproc_wstrb      ;
wire                   s_axi_tproc_wvalid     ;
wire                   s_axi_tproc_wready     ;
wire  [1:0]            s_axi_tproc_bresp      ;
wire                   s_axi_tproc_bvalid     ;
wire                   s_axi_tproc_bready     ;
wire [7:0]             s_axi_tproc_araddr     ;
wire [2:0]             s_axi_tproc_arprot     ;
wire                   s_axi_tproc_arvalid    ;
wire                   s_axi_tproc_arready    ;
wire  [31:0]           s_axi_tproc_rdata      ;
wire  [1:0]            s_axi_tproc_rresp      ;
wire                   s_axi_tproc_rvalid     ;
wire                   s_axi_tproc_rready     ;

//////////////////////////////////////////////////////////////////////////
//  CLK Generation
logic   c_clk, t_clk, s_ps_dma_aclk, rst_ni;

initial begin
  t_clk = 1'b0;
  forever # (`T_TCLK) t_clk = ~t_clk;
end

initial begin
  c_clk = 1'b0;
  forever # (`T_CCLK) c_clk = ~c_clk;
end

initial begin
  s_ps_dma_aclk = 1'b0;
  #0.5
  forever # (`T_SCLK) s_ps_dma_aclk = ~s_ps_dma_aclk;
end

assign s_ps_dma_aresetn  = rst_ni;
//////////////////////////////////////////////////////////////////////////


reg [255:0] max_value ;
reg axis_dma_start  ;

   

  
reg [255 :0]       s_dma_axis_tdata_i   ;
reg                s_dma_axis_tlast_i   ;
reg                s_dma_axis_tvalid_i  ;
reg                m_dma_axis_tready_i  ;
wire [63 :0]       port_0_dt_i          ;
reg [63 :0]        port_1_dt_i          ;


logic              m0_axis_tready;
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


wire [167:0]       tproc_sgt_0_axis_tdata ;
wire               tproc_sgt_0_axis_tvalid;
logic              tproc_sgt_0_axis_tready;

wire [159:0]       sgt_sg_0_axis_tdata ;
wire               sgt_sg_0_axis_tvalid;
logic              sgt_sg_0_axis_tready;


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


// Register ADDRESS
parameter REG_TPROC_CTRL      = 0  * 4 ;
parameter REG_TPROC_CFG       = 1  * 4 ;
parameter REG_MEM_ADDR        = 2  * 4 ;
parameter REG_MEM_LEN         = 3  * 4 ;
parameter REG_MEM_DT_I        = 4  * 4 ;
parameter REG_AXI_W_DT1       = 5  * 4 ;
parameter REG_AXI_W_DT2       = 6  * 4 ;
parameter REG_CORE_CFG        = 7  * 4 ;
parameter REG_AXI_DT_SRC      = 8  * 4 ;
parameter REG_MEM_DT_O        = 10  * 4 ;
parameter REG_AXI_R_DT1       = 11  * 4 ;
parameter REG_AXI_R_DT2       = 12  * 4 ;
parameter REG_TIME_USR        = 13  * 4 ;
parameter REG_TPROC_STATUS    = 14  * 4 ;
parameter REG_TPROC_DEBUG     = 15  * 4 ;



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

wire port_0_vld, qnet_vld_i, qnet_flag_i, periph_flag_i, ext_flag_i;
assign port_0_dt_i     = port_1_dt_o;
assign port_0_vld      = port_0_dt_o[0];
assign qnet_vld_i      = t_time_abs_o[3]&t_time_abs_o[2]&t_time_abs_o[1] ;
assign qnet_flag_i       = ~t_time_abs_o[5] & ~t_time_abs_o[4] & t_time_abs_o[3] ;
assign periph_flag_i     = ~t_time_abs_o[5] &  t_time_abs_o[4] & t_time_abs_o[3] ;
assign ext_flag_i        =  t_time_abs_o[5] &  t_time_abs_o[4] & t_time_abs_o[3] ;

reg  periph_vld_i  ;
reg qcom_rdy_i, qpb_rdy_i;

   //--------------------------------------
   // QICK PROCESSOR
   //--------------------------------------

   axi_mst_0 u_axi_mst_tproc_0 (
      .aclk          (s_ps_dma_aclk       ),
      .aresetn       (s_ps_dma_aresetn    ),
      .m_axi_araddr  (s_axi_tproc_araddr  ),
      .m_axi_arprot  (s_axi_tproc_arprot  ),
      .m_axi_arready (s_axi_tproc_arready ),
      .m_axi_arvalid (s_axi_tproc_arvalid ),
      .m_axi_awaddr  (s_axi_tproc_awaddr  ),
      .m_axi_awprot  (s_axi_tproc_awprot  ),
      .m_axi_awready (s_axi_tproc_awready ),
      .m_axi_awvalid (s_axi_tproc_awvalid ),
      .m_axi_bready  (s_axi_tproc_bready  ),
      .m_axi_bresp   (s_axi_tproc_bresp   ),
      .m_axi_bvalid  (s_axi_tproc_bvalid  ),
      .m_axi_rdata   (s_axi_tproc_rdata   ),
      .m_axi_rready  (s_axi_tproc_rready  ),
      .m_axi_rresp   (s_axi_tproc_rresp   ),
      .m_axi_rvalid  (s_axi_tproc_rvalid  ),
      .m_axi_wdata   (s_axi_tproc_wdata   ),
      .m_axi_wready  (s_axi_tproc_wready  ),
      .m_axi_wstrb   (s_axi_tproc_wstrb   ),
      .m_axi_wvalid  (s_axi_tproc_wvalid  )
   );

   axis_qick_processor # (
      .DUAL_CORE           (  `DUAL_CORE        ) ,
      .GEN_SYNC            (  `GEN_SYNC         ) ,
      .IO_CTRL             (  `IO_CTRL          ) ,
      .DEBUG               (  `DEBUG            ) ,
      .TNET                (  `TNET             ) ,
      .QCOM                (  `QCOM             ) ,
      .CUSTOM_PERIPH       (  `CUSTOM_PERIPH    ) ,
      .LFSR                (  `LFSR             ) ,
      .DIVIDER             (  `DIVIDER          ) ,
      .ARITH               (  `ARITH            ) ,
      .TIME_READ           (  `TIME_READ        ) ,
      .FIFO_DEPTH          (  `FIFO_DEPTH       ) ,
      .PMEM_AW             (  `PMEM_AW          ) ,
      .DMEM_AW             (  `DMEM_AW          ) ,
      .WMEM_AW             (  `WMEM_AW          ) ,
      .REG_AW              (  `REG_AW           ) ,
      .IN_PORT_QTY         (  `IN_PORT_QTY      ) ,
      .OUT_TRIG_QTY        (  `OUT_TRIG_QTY     ) ,
      .OUT_DPORT_QTY       (  `OUT_DPORT_QTY    ) ,
      .OUT_DPORT_DW        (  `OUT_DPORT_DW     ) , 
      .OUT_WPORT_QTY       (  `OUT_WPORT_QTY    ) 
   ) AXIS_QPROC (
      .t_clk_i             ( t_clk              ) ,
      .t_resetn            ( rst_ni             ) ,
      .c_clk_i             ( c_clk              ) ,
      .c_resetn            ( rst_ni             ) ,
      .ps_clk_i            ( s_ps_dma_aclk      ) ,
      .ps_resetn           ( s_ps_dma_aresetn   ) ,
      .ext_flag_i          ( ext_flag_i         ) ,
      .proc_start_i        ( proc_start_i       ) ,
      .proc_stop_i         ( proc_stop_i        ) ,
      .core_start_i        ( core_start_i       ) ,
      .core_stop_i         ( core_stop_i        ) ,
      .time_rst_i          ( time_rst_i         ) ,
      .time_init_i         ( time_init_i        ) ,
      .time_updt_i         ( time_updt_i        ) ,
      .time_dt_i           ( offset_dt_i        ) ,
      .t_time_abs_o        ( t_time_abs_o       ) ,
      .ps_debug_do         ( ps_debug_do        ) , 

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
      .s0_axis_tvalid       ( port_0_vld     ) ,
      .s1_axis_tdata        ( port_1_dt_i    ) ,
      .s1_axis_tvalid       ( s1_axis_tvalid ) ,
      .s2_axis_tdata        ( 64'd2          ) ,
      .s2_axis_tvalid       ( 1'b0           ) ,
      .s3_axis_tdata        ( 64'd3          ) ,
      .s3_axis_tvalid       ( 1'b0           ) ,
      .s4_axis_tdata        ( 64'd4          ) ,
      .s4_axis_tvalid       ( 1'b0           ) ,
      .s5_axis_tdata        ( 64'd5          ) ,
      .s5_axis_tvalid       ( 1'b0           ) ,
      .s6_axis_tdata        ( 64'd6          ) ,
      .s6_axis_tvalid       ( 1'b0           ) ,
      .s7_axis_tdata        ( 64'd7          ) ,
      .s7_axis_tvalid       ( 1'b0           ) ,

      .s_axi_awaddr         ( s_axi_tproc_awaddr[7:0]   ) ,
      .s_axi_awprot         ( s_axi_tproc_awprot        ) ,
      .s_axi_awvalid        ( s_axi_tproc_awvalid       ) ,
      .s_axi_awready        ( s_axi_tproc_awready       ) ,
      .s_axi_wdata          ( s_axi_tproc_wdata         ) ,
      .s_axi_wstrb          ( s_axi_tproc_wstrb         ) ,
      .s_axi_wvalid         ( s_axi_tproc_wvalid        ) ,
      .s_axi_wready         ( s_axi_tproc_wready        ) ,
      .s_axi_bresp          ( s_axi_tproc_bresp         ) ,
      .s_axi_bvalid         ( s_axi_tproc_bvalid        ) ,
      .s_axi_bready         ( s_axi_tproc_bready        ) ,
      .s_axi_araddr         ( s_axi_tproc_araddr[7:0]   ) ,
      .s_axi_arprot         ( s_axi_tproc_arprot        ) ,
      .s_axi_arvalid        ( s_axi_tproc_arvalid       ) ,
      .s_axi_arready        ( s_axi_tproc_arready       ) ,
      .s_axi_rdata          ( s_axi_tproc_rdata         ) ,
      .s_axi_rresp          ( s_axi_tproc_rresp         ) ,
      .s_axi_rvalid         ( s_axi_tproc_rvalid        ) ,
      .s_axi_rready         ( s_axi_tproc_rready        ) ,

      .m0_axis_tdata        ( tproc_sgt_0_axis_tdata  ) ,
      .m0_axis_tvalid       ( tproc_sgt_0_axis_tvalid ) ,
      .m0_axis_tready       ( tproc_sgt_0_axis_tready ) ,
      .m1_axis_tdata        ( /*m1_axis_tdata*/       ) ,
      .m1_axis_tvalid       ( /*m1_axis_tvalid*/      ) ,
      .m1_axis_tready       ( m1_axis_tready          ) ,
      .m2_axis_tdata        ( /*m2_axis_tdata*/       ) ,
      .m2_axis_tvalid       ( /*m2_axis_tvalid*/      ) ,
      .m2_axis_tready       ( m2_axis_tready          ) ,
      .m3_axis_tdata        ( /*m3_axis_tdata*/       ) ,
      .m3_axis_tvalid       ( /*m3_axis_tvalid*/      ) ,
      .m3_axis_tready       ( m3_axis_tready          ) ,
      .m4_axis_tdata        ( /*m4_axis_tdata*/       ) ,
      .m4_axis_tvalid       ( /*m4_axis_tvalid*/      ) ,
      .m4_axis_tready       ( m4_axis_tready          ) ,
      .m5_axis_tdata        ( /*m5_axis_tdata*/       ) ,
      .m5_axis_tvalid       ( /*m5_axis_tvalid*/      ) ,
      .m5_axis_tready       ( m5_axis_tready          ) ,
      .m6_axis_tdata        ( /*m6_axis_tdata*/       ) ,
      .m6_axis_tvalid       ( /*m6_axis_tvalid*/      ) ,
      .m6_axis_tready       ( m6_axis_tready          ) ,
      .m7_axis_tdata        ( /*m7_axis_tdata*/       ) ,
      .m7_axis_tvalid       ( /*m7_axis_tvalid*/      ) ,
      .m7_axis_tready       ( m7_axis_tready          ) ,
      .port_0_dt_o          ( port_0_dt_o             ) ,
      .port_1_dt_o          ( port_1_dt_o             ) ,
      .port_2_dt_o          ( port_2_dt_o             ) ,
      .port_3_dt_o          ( port_3_dt_o             ) 
   );

   //--------------------------------------
   // SIGNAL GENERATOR
   //--------------------------------------

   wire  [5:0]       s_axi_sg_araddr;
   wire  [2:0]       s_axi_sg_arprot;
   wire              s_axi_sg_arready;
   wire              s_axi_sg_arvalid;
   wire  [5:0]       s_axi_sg_awaddr;
   wire  [2:0]       s_axi_sg_awprot;
   wire              s_axi_sg_awready;
   wire              s_axi_sg_awvalid;
   wire              s_axi_sg_bready;
   wire  [1:0]       s_axi_sg_bresp;
   wire              s_axi_sg_bvalid;
   wire  [31:0]      s_axi_sg_rdata;
   wire              s_axi_sg_rready;
   wire  [1:0]       s_axi_sg_rresp;
   wire              s_axi_sg_rvalid;
   wire  [31:0]      s_axi_sg_wdata;
   wire              s_axi_sg_wready;
   wire  [3:0]       s_axi_sg_wstrb;
   wire              s_axi_sg_wvalid;

   // AXI VIP master address.
   xil_axi_ulong     SG_ADDR_START_ADDR   = 32'h40000000; // 0
   xil_axi_ulong     SG_ADDR_WE           = 32'h40000004; // 1

   xil_axi_prot_t    prot                 = 0;
   reg [31:0]        data_wr              = 32'h12345678;
   reg [31:0]        data;
   xil_axi_resp_t    resp;



   axi_mst_0 u_axi_mst_sg_0 (
      .aclk          (s_ps_dma_aclk    ),
      .aresetn       (s_ps_dma_aresetn ),
      .m_axi_araddr  (s_axi_sg_araddr  ),
      .m_axi_arprot  (s_axi_sg_arprot  ),
      .m_axi_arready (s_axi_sg_arready ),
      .m_axi_arvalid (s_axi_sg_arvalid ),
      .m_axi_awaddr  (s_axi_sg_awaddr  ),
      .m_axi_awprot  (s_axi_sg_awprot  ),
      .m_axi_awready (s_axi_sg_awready ),
      .m_axi_awvalid (s_axi_sg_awvalid ),
      .m_axi_bready  (s_axi_sg_bready  ),
      .m_axi_bresp   (s_axi_sg_bresp   ),
      .m_axi_bvalid  (s_axi_sg_bvalid  ),
      .m_axi_rdata   (s_axi_sg_rdata   ),
      .m_axi_rready  (s_axi_sg_rready  ),
      .m_axi_rresp   (s_axi_sg_rresp   ),
      .m_axi_rvalid  (s_axi_sg_rvalid  ),
      .m_axi_wdata   (s_axi_sg_wdata   ),
      .m_axi_wready  (s_axi_sg_wready  ),
      .m_axi_wstrb   (s_axi_sg_wstrb   ),
      .m_axi_wvalid  (s_axi_sg_wvalid  )
   );

   wire sg_s0_axis_aclk = s_ps_dma_aclk;
   logic   [31:0]       sg_s0_axis_tdata;
   logic                sg_s0_axis_tready;
   logic                sg_s0_axis_tvalid;

   logic tb_load_mem, tb_load_mem_done;

   sg_translator # (
      .OUT_TYPE               (0) // (0:gen_v6, 1:int4_v1, 2:mux4_v1, 3:readout)
   ) 
   u_sg_translator_0 (
      // Reset and clock.
      .aresetn                (1'bx),  // not used
      .aclk                   (1'bx),  // not used
      // IN WAVE PORT
      .s_axis_tdata           (tproc_sgt_0_axis_tdata),
      .s_axis_tvalid          (tproc_sgt_0_axis_tvalid),
      .s_axis_tready          (tproc_sgt_0_axis_tready),
      // OUT DATA gen_v6 (SEL:0)
      .m_gen_v6_axis_tdata    (sgt_sg_0_axis_tdata),
      .m_gen_v6_axis_tvalid   (sgt_sg_0_axis_tvalid),
      .m_gen_v6_axis_tready   (sgt_sg_0_axis_tready),
      // OUT DATA int4_v1 (SEL:1)
      .m_int4_axis_tdata      (),
      .m_int4_axis_tvalid     (),
      .m_int4_axis_tready     (),
      // OUT DATA mux4_v1 (SEL:2)
      .m_mux4_axis_tdata      (),
      .m_mux4_axis_tvalid     (),
      .m_mux4_axis_tready     (),
      // OUT DATA readout_v3 (SEL:3)
      .m_readout_axis_tdata   (),
      .m_readout_axis_tvalid  (),
      .m_readout_axis_tready  ()
   );

   // axis_signal_gen_v6_0 generics.
   localparam N       = 10;
   localparam N_DDS   = 4;

   axis_signal_gen_v6 #(
      .N                   (N                ),
      .N_DDS               (N_DDS            ),
      .GEN_DDS             ("FALSE"          ),
      .ENVELOPE_TYPE       ("REAL"           )
   )
   u_axis_signal_gen_v6_0 ( 
      // AXI Slave I/F for configuration.
      .s_axi_aclk          (s_ps_dma_aclk    ),
      .s_axi_aresetn       (s_ps_dma_aresetn ),
      .s_axi_araddr        (s_axi_sg_araddr  ),
      .s_axi_arprot        (s_axi_sg_arprot  ),
      .s_axi_arready       (s_axi_sg_arready ),
      .s_axi_arvalid       (s_axi_sg_arvalid ),
      .s_axi_awaddr        (s_axi_sg_awaddr  ),
      .s_axi_awprot        (s_axi_sg_awprot  ),
      .s_axi_awready       (s_axi_sg_awready ),
      .s_axi_awvalid       (s_axi_sg_awvalid ),
      .s_axi_bready        (s_axi_sg_bready  ),
      .s_axi_bresp         (s_axi_sg_bresp   ),
      .s_axi_bvalid        (s_axi_sg_bvalid  ),
      .s_axi_rdata         (s_axi_sg_rdata   ),
      .s_axi_rready        (s_axi_sg_rready  ),
      .s_axi_rresp         (s_axi_sg_rresp   ),
      .s_axi_rvalid        (s_axi_sg_rvalid  ),
      .s_axi_wdata         (s_axi_sg_wdata   ),
      .s_axi_wready        (s_axi_sg_wready  ),
      .s_axi_wstrb         (s_axi_sg_wstrb   ),
      .s_axi_wvalid        (s_axi_sg_wvalid  ),

      // AXIS Slave to load data into memory.
      .s0_axis_aclk        (s_ps_dma_aclk      ),
      .s0_axis_aresetn     (s_ps_dma_aresetn   ),
      .s0_axis_tdata       (sg_s0_axis_tdata   ),
      .s0_axis_tvalid      (sg_s0_axis_tvalid  ),
      .s0_axis_tready      (sg_s0_axis_tready  ),

      // s1_* and m_* reset/clock.
      .aresetn             (rst_ni           ),
      .aclk                (t_clk            ),

      // AXIS Slave to queue waveforms - From TPROC
      .s1_axis_tdata       (sgt_sg_0_axis_tdata    ),
      .s1_axis_tvalid      (sgt_sg_0_axis_tvalid   ),
      .s1_axis_tready      (sgt_sg_0_axis_tready   ),

      // AXIS Master for output data.
      .m_axis_tready       (/*m_axis_tready*/ ),
      .m_axis_tvalid       (/*m_axis_tvalid*/ ),
      .m_axis_tdata        (/*m_axis_tdata*/  )
   );


//--------------------------------------
// TEST STIMULI
//--------------------------------------

initial begin

   // Create agents.
   axi_mst_tproc_agent  = new("axi_mst_tproc VIP Agent",tb_qick.u_axi_mst_tproc_0.inst.IF);
   // Set tag for agents.
   axi_mst_tproc_agent.set_agent_tag("axi_mst_tproc VIP");
   // Start agents.
   axi_mst_tproc_agent.start_master();

   // Create agents.
   axi_mst_sg_agent   = new("axi_mst_sg_0 VIP Agent",tb_qick.u_axi_mst_sg_0.inst.IF);
   // Set tag for agents.
   axi_mst_sg_agent.set_agent_tag("axi_mst_sg_0 VIP");
   // Start agents.
   axi_mst_sg_agent.start_master();

   $display("*** Start Test ***");
   
   $display("AXI_WDATA_WIDTH %0d",  `AXI_WDATA_WIDTH);

   $display("LFSR %0d",  `LFSR);
   $display("DIVIDER %0d",  `DIVIDER);
   $display("ARITH %0d",  `ARITH);
   $display("TIME_READ %0d",  `TIME_READ);

   $display("DMEM_AW %0d",  `DMEM_AW);
   $display("WMEM_AW %0d",  `WMEM_AW);
   $display("REG_AW %0d",  `REG_AW);
   $display("IN_PORT_QTY %0d",  `IN_PORT_QTY);
   $display("OUT_DPORT_QTY %0d",  `OUT_DPORT_QTY);
   $display("OUT_WPORT_QTY %0d",  `OUT_WPORT_QTY);
   
  

   AXIS_QPROC.QPROC.DISPATCHER.TRIG_FIFO[0].trig_fifo_inst.fifo_mem.RAM = '{default:'0} ;
   AXIS_QPROC.QPROC.DISPATCHER.DATA_FIFO[0].data_fifo_inst.fifo_mem.RAM = '{default:'0} ;
   AXIS_QPROC.QPROC.DISPATCHER.WAVE_FIFO[0].wave_fifo_inst.fifo_mem.RAM = '{default:'0} ;


   // Load Memories 
   
   $readmemh("prog.mem", AXIS_QPROC.QPROC.CORE_0.CORE_MEM.P_MEM.RAM);
   $readmemh("wave.mem", AXIS_QPROC.QPROC.CORE_0.CORE_MEM.W_MEM.RAM);
   $readmemh("dmem.mem", AXIS_QPROC.QPROC.CORE_0.CORE_MEM.D_MEM.RAM);


   // INITIAL VALUES

   qnet_dt_i               = '{default:'0} ;
   rst_ni                  = 1'b0;
   axi_dt                  = 0 ;
   axis_dma_start          = 1'b0;
   s1_axis_tvalid          = 1'b0 ;
   port_1_dt_i             = 0;
   qcom_rdy_i              = 0 ;
   qpb_rdy_i               = 0 ;
   periph_dt_i             = {0,0} ;
   qnet_rdy_i              = 0 ;
   qnet_dt_i [2]           = {0,0} ;
   proc_start_i            = 1'b0;
   proc_stop_i             = 1'b0;
   core_start_i            = 1'b0;
   core_stop_i             = 1'b0;
   time_rst_i              = 1'b0;
   time_init_i             = 1'b0;
   time_updt_i             = 1'b0;
   offset_dt_i             = 0 ;
   periph_vld_i            = 1'b0;

   tb_load_mem             = 1'b0;
   tb_load_mem_done        = 1'b0;

   sg_s0_axis_tvalid       = 0;
   sg_s0_axis_tdata        = 0;


   m_dma_axis_tready_i     = 1'b1; 
   max_value               = 0;
   #10ns;

   // Hold Reset
   repeat(16) @ (posedge s_ps_dma_aclk); #0.1ns;
   // Release Reset
   rst_ni = 1'b1;

   #1us;

   $display("################################");
   $display("### Load envelope into Table ###");
   $display("################################");
   $display("t = %0t", $time);

   // start_addr.
   data_wr = 0;
   axi_mst_sg_agent.AXI4LITE_WRITE_BURST(SG_ADDR_START_ADDR, prot, data_wr, resp);
   #100ns;
   
   // we.
   data_wr = 1;
   axi_mst_sg_agent.AXI4LITE_WRITE_BURST(SG_ADDR_WE, prot, data_wr, resp);
   #100ns;
   
   // Load Envelope Table Memory.
   tb_load_mem    = 1;
   sg_load_mem(tb_load_mem, tb_load_mem_done);
   // wait (tb_load_mem_done);
   tb_load_mem    = 0;

   #1us;

   repeat (2) begin

      WRITE_AXI( REG_TPROC_CTRL , 4); //PROC_START

      #5us;

      WRITE_AXI( REG_TPROC_CTRL , 8); //PROC_STOP

      #5us;
   end
    
//   WRITE_AXI( REG_TPROC_CTRL , 16); //CORE_START
//   #1000;
//   WRITE_AXI( REG_TPROC_CTRL , 128); //PROC_RUN
//   #900;
   
   #1us;

   $display("*** End Test ***");
   $finish();
end


task WRITE_AXI(integer PORT_AXI, DATA_AXI);
   $display("Running WRITE_AXI() Task");
   //$display("PORT %d",  PORT_AXI);
   //$display("DATA %d",  DATA_AXI);
   @(posedge s_ps_dma_aclk); #0.1;
   axi_mst_tproc_agent.AXI4LITE_WRITE_BURST(PORT_AXI, prot, DATA_AXI, resp);
endtask

task READ_AXI(integer ADDR_AXI);
   integer DATA_RD;
   $display("Running READ_AXI() Task");
   @(posedge s_ps_dma_aclk); #0.1;
   axi_mst_tproc_agent.AXI4LITE_READ_BURST(ADDR_AXI, 0, DATA_RD, resp);
   $display("READ AXI_DATA %d",  DATA_RD);
endtask


// Load pulse data into memory.
task sg_load_mem(input logic tb_load_mem, output logic tb_load_mem_done);
   int fd,vali,valq;
   bit signed [15:0] ii,qq;
   
   $display("### Task sg_load_mem() start ###");

   sg_s0_axis_tvalid = 0;
   sg_s0_axis_tdata  = 0;
   
   wait (tb_load_mem);

   // File must be in the same directory from where the simulation is run
   fd = $fopen("./sg_0.mem","r");

   wait (sg_s0_axis_tready);

   while($fscanf(fd,"%d,%d", vali,valq) == 2) begin
      $display("I,Q: %d, %d", vali,valq);
      ii = vali;
      qq = valq;
      @(posedge sg_s0_axis_aclk);
      sg_s0_axis_tvalid    = 1;
      sg_s0_axis_tdata     = {qq,ii};
   end
   $fclose(fd);

   @(posedge sg_s0_axis_aclk);
   sg_s0_axis_tvalid    = 0;

   tb_load_mem_done = 1;

   $display("### Task sg_load_mem() end ###");
endtask



endmodule
