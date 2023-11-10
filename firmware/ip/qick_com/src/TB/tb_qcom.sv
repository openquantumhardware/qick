///////////////////////////////////////////////////////////////////////////////
//  FERMI RESEARCH LAB
///////////////////////////////////////////////////////////////////////////////
//  Author         : mdife
///////////////////////////////////////////////////////////////////////////////

`timescale 1ns/10ps

import axi_vip_pkg::*;
import axi_mst_0_pkg::*;

`define T_C_CLK         5 // 1.66 // Half Clock Period for Simulation
`define T_PS_CLK        25  // Half Clock Period for Simulation

localparam DEBUG    =     1;  // Debugging

module tb_qcom();

///////////////////////////////////////////////////////////////////////////////

// VIP Agent
axi_mst_0_mst_t 	axi_mst_0_agent;
xil_axi_prot_t  prot        = 0;
xil_axi_resp_t  resp;

// Signals
reg c_clk, ps_clk;
reg rst_ni;
reg[31:0]       data_wr     = 32'h12345678;

//AXI-LITE
wire [7:0]             s_axi_awaddr  ;
wire [2:0]             s_axi_awprot  ;
wire                   s_axi_awvalid ;
wire                   s_axi_awready ;
wire [31:0]            s_axi_wdata   ;
wire [3:0]             s_axi_wstrb   ;
wire                   s_axi_wvalid  ;
wire                   s_axi_wready  ;
wire  [1:0]            s_axi_bresp   ;
wire                   s_axi_bvalid  ;
wire                   s_axi_bready  ;
wire [7:0]             s_axi_araddr  ;
wire [2:0]             s_axi_arprot  ;
wire                   s_axi_arvalid ;
wire                   s_axi_arready ;
wire  [31:0]           s_axi_rdata   ;
wire  [1:0]            s_axi_rresp   ;
wire                   s_axi_rvalid  ;
wire                   s_axi_rready  ;

reg sync_i;
//////////////////////////////////////////////////////////////////////////
//  CLK Generation
initial begin
  c_clk = 1'b0;
  forever # (`T_C_CLK) c_clk = ~c_clk;
end
initial begin
  ps_clk = 1'b0;
  forever # (`T_PS_CLK) ps_clk = ~ps_clk;
end
initial begin
  sync_i = 1'b0;
  forever # (1000) sync_i = ~sync_i;
end




reg         c_cmd_i  ;
reg [4 :0]  c_op_i;


//////////////////////////////////////////////////////////////////////////
//  AXI AGENT
axi_mst_0 axi_mst_0_i (
   .aclk			   (ps_clk		   ),
   .aresetn		   (rst_ni	      ),
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

reg [ 3:0] pmod_si  ;
wire[ 3:0] pmod_o1, pmod_o2, pmod_i ;
reg [31:0] c_dt1_i, c_dt2_i, c_dt3_i ;

//////////////////////////////////////////////////////////////////////////
//  QCOM1
axis_qick_com # (
   .DEBUG         ( DEBUG )
) QICK_COM_1 (
   .c_clk         ( c_clk         ) ,
   .c_aresetn     ( rst_ni        ) ,
   .ps_clk        ( ps_clk        ) ,
   .ps_aresetn    ( rst_ni        ) ,
   .sync_i        ( sync_i        ) ,
   .qcom_en_i     ( c_cmd_i       ) ,
   .qcom_op_i     ( c_op_i        ) ,
   .qcom_dt1_i    ( c_dt1_i       ) ,
   .qcom_rdy_o    ( ready         ) ,
   .qcom_dt1_o    ( qcom_dt1_o    ) ,
   .qcom_dt2_o    ( qcom_dt2_o    ) ,
   .qcom_vld_o    ( qcom_vld_o    ) ,
   .qcom_flag_o   ( qcom_flag_o   ) ,
   .qproc_start_o ( qproc_start_o1 ) ,
   .pmod_i        ( pmod_i        ) ,
   .pmod_o        ( pmod_o1        ) ,
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
//////////////////////////////////////////////////////////////////////////
//  QCOM
axis_qick_com # (
   .DEBUG         ( DEBUG )
) QICK_COM_2 (
   .c_clk         ( c_clk         ) ,
   .c_aresetn     ( rst_ni        ) ,
   .ps_clk        ( ps_clk        ) ,
   .ps_aresetn    ( rst_ni        ) ,
   .sync_i        ( sync_i        ) ,
   .qcom_en_i     ( 0 ) ,
   .qcom_op_i     ( 0 ) ,
   .qcom_dt1_i    ( 0 ) ,
   .qcom_rdy_o    (   ) ,
   .qcom_dt1_o    (   ) ,
   .qcom_dt2_o    (   ) ,
   .qcom_vld_o    (   ) ,
   .qcom_flag_o   (   ) ,
   .qproc_start_o ( qproc_start_o2 ) ,
   .pmod_i        ( pmod_o1        ) ,
   .pmod_o        ( pmod_o2        ) ,
   .s_axi_awaddr  ( 0 ) ,
   .s_axi_awprot  ( 0 ) ,
   .s_axi_awvalid ( 0 ) ,
   .s_axi_awready (  ) ,
   .s_axi_wdata   ( 0 ) ,
   .s_axi_wstrb   ( 0 ) ,
   .s_axi_wvalid  ( 0 ) ,
   .s_axi_wready  (  ) ,
   .s_axi_bresp   (  ) ,
   .s_axi_bvalid  (  ) ,
   .s_axi_bready  (  ) ,
   .s_axi_araddr  ( 0 ) ,
   .s_axi_arprot  ( 0 ) ,
   .s_axi_arvalid ( 0 ) ,
   .s_axi_arready (  ) ,
   .s_axi_rdata   (  ) ,
   .s_axi_rresp   (  ) ,
   .s_axi_rvalid  (  ) ,
   .s_axi_rready  (  ) ,         
   .qcom_do       (  ) 
);



reg tx_loop;

initial begin
   START_SIMULATION();
   // SIM_RX();
   SIM_TX();

end

assign  pmod_i = tx_loop  ? pmod_o1 : pmod_si;

task SIM_TX(); begin
   $display("SIM TX");

   tx_loop  = 1'b0 ;
   c_cmd_i  = 1'b0 ;
   c_op_i   = 4'd0;
   c_dt1_i  = 0;
   c_dt2_i  = 0;
   c_dt3_i  = 0;

   wait (ready == 1'b1)
   @ (posedge c_clk); #0.1;
   c_op_i   = 5'b0001_0; //SET FLAG
   c_cmd_i  = 1'b1 ;
   @ (posedge c_clk); #0.1;
   c_cmd_i  = 1'b0 ;
   @ (posedge c_clk); #0.1;

   wait (ready == 1'b1)
   # (5 * `T_C_CLK);

   @ (posedge c_clk); #0.1;
   c_op_i   = 5'b0000_0; //CLR FLAG
   c_cmd_i  = 1'b1 ;
   @ (posedge c_clk); #0.1;
   c_cmd_i  = 1'b0 ;
   @ (posedge c_clk); #0.1;

   wait (ready == 1'b1)
   # (5 * `T_C_CLK);

   @ (posedge c_clk); #0.1;
   c_op_i   = 5'b0010_0; //SEND 8_BIT
   c_dt1_i  = 8'b10101010 ;
   c_cmd_i  = 1'b1 ;
   @ (posedge c_clk); #0.1;
   c_cmd_i  = 1'b0 ;
   @ (posedge c_clk); #0.1;

   wait (ready == 1'b1)
   # (5 * `T_C_CLK);

   @ (posedge c_clk); #0.1;
   c_op_i   = 5'b0100_0; //SEND 16_BIT
   c_dt1_i  = 16'b0100_0011_0010_0001 ;
   c_cmd_i  = 1'b1 ;
   @ (posedge c_clk); #0.1;
   c_cmd_i  = 1'b0 ;
   @ (posedge c_clk); #0.1;

   wait (ready == 1'b1)
   # (5 * `T_C_CLK);

   @ (posedge c_clk); #0.1;
   c_op_i   = 5'b0110_0; //SEND 32_BIT
   c_dt1_i  = 4660;
   c_cmd_i  = 1'b1 ;
   @ (posedge c_clk); #0.1;
   c_cmd_i  = 1'b0 ;
   @ (posedge c_clk); #0.1;

   wait (ready == 1'b1)
   # (5 * `T_C_CLK);

   @ (posedge c_clk); #0.1;
   c_op_i   = 5'b0110_1; //SEND 32_BIT
   c_dt1_i  =53758;
   c_cmd_i  = 1'b1 ;
   @ (posedge c_clk); #0.1;
   c_cmd_i  = 1'b0 ;
   @ (posedge c_clk); #0.1;

   wait (ready == 1'b1)
   # (5 * `T_C_CLK);

   @ (posedge c_clk); #0.1;
   c_op_i   = 5'b0011_0; //SYNC
   c_dt1_i  =53758;
   c_cmd_i  = 1'b1 ;
   @ (posedge c_clk); #0.1;
   c_cmd_i  = 1'b0 ;
   @ (posedge c_clk); #0.1;

   end
endtask

task SIM_RX(); begin
   tx_loop  = 1'b0 ;
   # (5 * `T_C_CLK);
   @ (posedge c_clk); #0.1;
   pmod_si = 4'b0001; // DATA
   @ (posedge c_clk); #0.1;
   pmod_si = 4'b1001; // Same DATA CLK
   # (5 * `T_C_CLK);
   @ (posedge c_clk); #0.1;
   pmod_si = 4'b1001; // DATA
   @ (posedge c_clk); #0.1;
   pmod_si = 4'b0001; // Same DATA CLK
   # (5 * `T_C_CLK);
   @ (posedge c_clk); #0.1;
   pmod_si = 4'b0000; // DATA
   @ (posedge c_clk); #0.1;
   pmod_si = 4'b1000; // Same DATA CLK
   # (5 * `T_C_CLK);
   @ (posedge c_clk); #0.1;
   pmod_si = 4'b1110; // DATA
   @ (posedge c_clk); #0.1;
   pmod_si = 4'b0110; // Same DATA CLK
   # (5 * `T_C_CLK);
   @ (posedge c_clk); #0.1;
   pmod_si = 4'b0100; // DATA
   @ (posedge c_clk); #0.1;
   pmod_si = 4'b1100; // Same DATA CLK

   # (33 * `T_C_CLK);
   pmod_si = 4'b011; // Same DATA CLK

   # (18 * `T_C_CLK);
   @ (posedge c_clk); #0.1;
   pmod_si = 4'b0111; // DATA
   @ (posedge c_clk); #0.1;
   pmod_si = 4'b1111; // Same DATA CLK
   # (5 * `T_C_CLK);
   @ (posedge c_clk); #0.1;
   pmod_si = 4'b1110; // DATA
   @ (posedge c_clk); #0.1;
   pmod_si = 4'b0110; // Same DATA CLK
   # (5 * `T_C_CLK);
   @ (posedge c_clk); #0.1;
   pmod_si = 4'b0101; // DATA
   @ (posedge c_clk); #0.1;
   pmod_si = 4'b1101; // Same DATA CLK
   # (5 * `T_C_CLK);
   @ (posedge c_clk); #0.1;
   pmod_si = 4'b1100; // DATA
   @ (posedge c_clk); #0.1;
   pmod_si = 4'b0100; // Same DATA CLK
   end
endtask


task START_SIMULATION (); begin
   $display("START SIMULATION");
  	// Create agents.
	axi_mst_0_agent 	= new("axi_mst_0 VIP Agent",tb_qcom.axi_mst_0_i.inst.IF);
	// Set tag for agents.
	axi_mst_0_agent.set_agent_tag	("axi_mst_0 VIP");
	// Start agents.
	axi_mst_0_agent.start_master();
   rst_ni   = 1'b0;
   c_cmd_i  = 1'b0 ;
   c_op_i   = 4'd0;
   c_dt1_i  = 0;
   c_dt2_i  = 0;
   c_dt3_i  = 0;
   pmod_si   = 0;
   tx_loop  = 1'b0 ;

   @ (posedge ps_clk); #0.1;
   rst_ni            = 1'b1;

   end
endtask


endmodule




