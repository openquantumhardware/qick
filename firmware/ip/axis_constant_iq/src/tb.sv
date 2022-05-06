// VIP: axi_mst_0
// DUT: axis_chsel_pfb
// 	IF: s_axi -> axi_mst_0

import axi_vip_pkg::*;
import axi_mst_0_pkg::*;

module tb();

// DUT generics.
parameter B = 16;
parameter N = 8;

// s_axi interfase.
reg					s_axi_aclk;
wire [5:0]			s_axi_araddr;
reg					s_axi_aresetn;
wire [2:0]			s_axi_arprot;
wire				s_axi_arready;
wire				s_axi_arvalid;
wire [5:0]			s_axi_awaddr;
wire [2:0]			s_axi_awprot;
wire				s_axi_awready;
wire				s_axi_awvalid;
wire				s_axi_bready;
wire [1:0]			s_axi_bresp;
wire				s_axi_bvalid;
wire [31:0]			s_axi_rdata;
wire				s_axi_rready;
wire [1:0]			s_axi_rresp;
wire				s_axi_rvalid;
wire [31:0]			s_axi_wdata;
wire				s_axi_wready;
wire [3:0]			s_axi_wstrb;
wire				s_axi_wvalid;

// m_axis interfase.
reg					m_axis_aclk;
reg					m_axis_aresetn;
wire [2*B*N-1:0]	m_axis_tdata;
wire				m_axis_tvalid;

xil_axi_prot_t  prot        = 0;
reg[31:0]       data_wr     = 32'h12345678;
reg[31:0]       data_rd;
reg[31:0]       data;
xil_axi_resp_t  resp;

// TB control.
reg	tb_start;

axi_mst_0 axi_mst_0_i
	(
		.aclk			(s_axi_aclk),
		.aresetn		(s_axi_aresetn),
		.m_axi_araddr	(s_axi_araddr),
		.m_axi_arprot	(s_axi_arprot),
		.m_axi_arready	(s_axi_arready),
		.m_axi_arvalid	(s_axi_arvalid),
		.m_axi_awaddr	(s_axi_awaddr),
		.m_axi_awprot	(s_axi_awprot),
		.m_axi_awready	(s_axi_awready),
		.m_axi_awvalid	(s_axi_awvalid),
		.m_axi_bready	(s_axi_bready),
		.m_axi_bresp	(s_axi_bresp),
		.m_axi_bvalid	(s_axi_bvalid),
		.m_axi_rdata	(s_axi_rdata),
		.m_axi_rready	(s_axi_rready),
		.m_axi_rresp	(s_axi_rresp),
		.m_axi_rvalid	(s_axi_rvalid),
		.m_axi_wdata	(s_axi_wdata),
		.m_axi_wready	(s_axi_wready),
		.m_axi_wstrb	(s_axi_wstrb),
		.m_axi_wvalid	(s_axi_wvalid)
	);

axis_constant_iq
	#(
		.B(B),
		.N(N)
	)
	axis_constant_iq
	(
		// s_axi interfase.
		.s_axi_aclk		(s_axi_aclk),
		.s_axi_araddr	(s_axi_araddr),
		.s_axi_aresetn	(s_axi_aresetn),
		.s_axi_arprot	(s_axi_arprot),
		.s_axi_arready	(s_axi_arready),
		.s_axi_arvalid	(s_axi_arvalid),
		.s_axi_awaddr	(s_axi_awaddr),
		.s_axi_awprot	(s_axi_awprot),
		.s_axi_awready	(s_axi_awready),
		.s_axi_awvalid	(s_axi_awvalid),
		.s_axi_bready	(s_axi_bready),
		.s_axi_bresp	(s_axi_bresp),
		.s_axi_bvalid	(s_axi_bvalid),
		.s_axi_rdata	(s_axi_rdata),
		.s_axi_rready	(s_axi_rready),
		.s_axi_rresp	(s_axi_rresp),
		.s_axi_rvalid	(s_axi_rvalid),
		.s_axi_wdata	(s_axi_wdata),
		.s_axi_wready	(s_axi_wready),
		.s_axi_wstrb	(s_axi_wstrb),
		.s_axi_wvalid	(s_axi_wvalid),

		// m_axis interfase.
		.m_axis_aclk	(m_axis_aclk	),
		.m_axis_aresetn	(m_axis_aresetn	),
		.m_axis_tdata	(m_axis_tdata	),
		.m_axis_tvalid	(m_axis_tvalid	)
	);

// VIP Agents
axi_mst_0_mst_t axi_mst_0_agent;

initial begin
	// Create agents.
	axi_mst_0_agent = new("axi_mst_0 VIP Agent",tb.axi_mst_0_i.inst.IF);

	// Set tag for agents.
	axi_mst_0_agent.set_agent_tag("axi_mst_0 VIP");

	// Start agents.
	axi_mst_0_agent.start_master();

	/* ************* */
	/* Main TB Start */
	/* ************* */

	// Reset sequence.
	s_axi_aresetn 	<= 0;
	m_axis_aresetn 	<= 0;
	tb_start		<= 0;
	#500;
	s_axi_aresetn 	<= 1;
	m_axis_aresetn 	<= 1;

	#1000;

	// Start data.
	tb_start <= 1;

	// REAL_REG
	data_wr = 123;
	axi_mst_0_agent.AXI4LITE_WRITE_BURST(0*4, prot, data_wr, resp);
	#10;

	// IMAG_REG
	data_wr = 14;
	axi_mst_0_agent.AXI4LITE_WRITE_BURST(1*4, prot, data_wr, resp);
	#10;

	// WE_REG
	data_wr = 1;
	axi_mst_0_agent.AXI4LITE_WRITE_BURST(2*4, prot, data_wr, resp);
	#10;

	#1000;

	// REAL_REG
	data_wr = 55;
	axi_mst_0_agent.AXI4LITE_WRITE_BURST(0*4, prot, data_wr, resp);
	#10;

	// IMAG_REG
	data_wr = 66;
	axi_mst_0_agent.AXI4LITE_WRITE_BURST(1*4, prot, data_wr, resp);
	#10;

	// WE_REG
	data_wr = 0;
	axi_mst_0_agent.AXI4LITE_WRITE_BURST(2*4, prot, data_wr, resp);
	#10;

	// WE_REG
	data_wr = 1;
	axi_mst_0_agent.AXI4LITE_WRITE_BURST(2*4, prot, data_wr, resp);
	#10;

end

always begin
	s_axi_aclk <= 0;
	#10;
	s_axi_aclk <= 1;
	#10;
end

always begin
	m_axis_aclk <= 0;
	#3;
	m_axis_aclk <= 1;
	#3;
end

endmodule

