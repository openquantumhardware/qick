// VIP: axi_mst_0
// DUT: axis_readout_v1
// 	IF: s_axi -> axi_mst_0

import axi_vip_pkg::*;
import axi_mst_0_pkg::*;

module tb();

localparam N_AVG 	= 10;
localparam N_BUF 	= 16;
localparam B 		= 16;

// s_axi interfase.
reg						s_axi_aclk;
reg						s_axi_aresetn;
wire 	[5:0]			s_axi_araddr;
wire 	[2:0]			s_axi_arprot;
wire					s_axi_arready;
wire					s_axi_arvalid;
wire 	[5:0]			s_axi_awaddr;
wire 	[2:0]			s_axi_awprot;
wire					s_axi_awready;
wire					s_axi_awvalid;
wire					s_axi_bready;
wire 	[1:0]			s_axi_bresp;
wire					s_axi_bvalid;
wire 	[31:0]			s_axi_rdata;
wire					s_axi_rready;
wire 	[1:0]			s_axi_rresp;
wire					s_axi_rvalid;
wire 	[31:0]			s_axi_wdata;
wire					s_axi_wready;
wire 	[3:0]			s_axi_wstrb;
wire					s_axi_wvalid;

reg						trigger;

reg						s_axis_aclk;
reg						s_axis_aresetn;
reg						s_axis_tvalid;
wire					s_axis_tready;
reg		[2*B-1:0]		s_axis_tdata;

reg						m_axis_aclk;
reg						m_axis_aresetn;

wire					m0_axis_tvalid;
reg						m0_axis_tready;
wire	[4*B-1:0]		m0_axis_tdata;
wire					m0_axis_tlast;

wire					m1_axis_tvalid;
reg						m1_axis_tready;
wire	[2*B-1:0]		m1_axis_tdata;
wire					m1_axis_tlast;

wire					m2_axis_tvalid;
reg						m2_axis_tready;
wire	[4*B-1:0]		m2_axis_tdata;

// AXI VIP master address.
xil_axi_ulong   avg_start_reg		= 0;
xil_axi_ulong   avg_addr_reg		= 1;
xil_axi_ulong   avg_len_reg			= 2;
xil_axi_ulong   avg_dr_start_reg	= 3;
xil_axi_ulong   avg_dr_addr_reg		= 4;
xil_axi_ulong   avg_dr_len_reg		= 5;
xil_axi_ulong   buf_start_reg		= 6;
xil_axi_ulong   buf_addr_reg		= 7;
xil_axi_ulong   buf_len_reg			= 8;
xil_axi_ulong   buf_dr_start_reg	= 9;
xil_axi_ulong   buf_dr_addr_reg		= 10;
xil_axi_ulong   buf_dr_len_reg		= 11;

xil_axi_prot_t  prot        = 0;
reg[31:0]       data_wr     = 32'h12345678;
reg[31:0]       data;
xil_axi_resp_t  resp;

// Test bench control.
reg tb_input		= 0;
reg tb_input_done	= 0;

// axi_mst_0.
axi_mst_0 axi_mst_0_i
	(
		.aclk			(s_axi_aclk		),
		.aresetn		(s_axi_aresetn	),
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

axis_avg_buffer
	#
	(
		.N_AVG	(N_AVG	),
		.N_BUF	(N_BUF	),
		.B		(B		)
	)
	DUT 
	( 
		// AXI Slave I/F for configuration.
		.s_axi_aclk		(s_axi_aclk		),
		.s_axi_aresetn	(s_axi_aresetn	),
		.s_axi_araddr	(s_axi_araddr	),
		.s_axi_arprot	(s_axi_arprot	),
		.s_axi_arready	(s_axi_arready	),
		.s_axi_arvalid	(s_axi_arvalid	),
		.s_axi_awaddr	(s_axi_awaddr	),
		.s_axi_awprot	(s_axi_awprot	),
		.s_axi_awready	(s_axi_awready	),
		.s_axi_awvalid	(s_axi_awvalid	),
		.s_axi_bready	(s_axi_bready	),
		.s_axi_bresp	(s_axi_bresp	),
		.s_axi_bvalid	(s_axi_bvalid	),
		.s_axi_rdata	(s_axi_rdata	),
		.s_axi_rready	(s_axi_rready	),
		.s_axi_rresp	(s_axi_rresp	),
		.s_axi_rvalid	(s_axi_rvalid	),
		.s_axi_wdata	(s_axi_wdata	),
		.s_axi_wready	(s_axi_wready	),
		.s_axi_wstrb	(s_axi_wstrb	),
		.s_axi_wvalid	(s_axi_wvalid	),

		// Trigger input.
		.trigger		(trigger		),

		// AXIS Slave for input data.
		.s_axis_aclk	(s_axis_aclk	),
		.s_axis_aresetn	(s_axis_aresetn	),
		.s_axis_tvalid	(s_axis_tvalid	),
		.s_axis_tready	(s_axis_tready	),
		.s_axis_tdata	(s_axis_tdata	),

		// Reset and clock for m0 and m1.
		.m_axis_aclk	(m_axis_aclk   	),
		.m_axis_aresetn	(m_axis_aresetn	),

		// AXIS Master for averaged output.
		.m0_axis_tvalid	(m0_axis_tvalid	),
		.m0_axis_tready	(m0_axis_tready	),
		.m0_axis_tdata	(m0_axis_tdata	),
		.m0_axis_tlast	(m0_axis_tlast	),

		// AXIS Master for raw output.
		.m1_axis_tvalid	(m1_axis_tvalid	),
		.m1_axis_tready	(m1_axis_tready	),
		.m1_axis_tdata	(m1_axis_tdata	),
		.m1_axis_tlast	(m1_axis_tlast	),

		// AXIS Master for register output.
		.m2_axis_tvalid	(m2_axis_tvalid	),
		.m2_axis_tready	(m2_axis_tready	),
		.m2_axis_tdata	(m2_axis_tdata	)
	);

// VIP Agents
axi_mst_0_mst_t 	axi_mst_0_agent;

// Main TB Control.
initial begin
	// Create agents.
	axi_mst_0_agent 	= new("axi_mst_0 VIP Agent",tb.axi_mst_0_i.inst.IF);

	// Set tag for agents.
	axi_mst_0_agent.set_agent_tag	("axi_mst_0 VIP");

	// Start agents.
	axi_mst_0_agent.start_master();

	// Reset sequence.
	s_axi_aresetn 	<= 0;
	s_axis_aresetn 	<= 0;
	m_axis_aresetn	<= 0;
	m0_axis_tready	<= 1;
	m1_axis_tready	<= 1;
	m2_axis_tready	<= 1;
	trigger			<= 0;
	#500;
	s_axi_aresetn 	<= 1;
	s_axis_aresetn 	<= 1;
	m_axis_aresetn	<= 1;

	#1000;
	
	$display("##############");
	$display("### Test 0 ###");
	$display("##############");
	$display("t = %0t", $time);
	// Average/buffer:
	// * addr 	= 0.
	// * len	= 1280.

	// avg_addr_reg
	data_wr = 0;
	axi_mst_0_agent.AXI4LITE_WRITE_BURST(4*avg_addr_reg, prot, data_wr, resp);
	#10;	

	// avg_len_reg
	data_wr = 1280;
	axi_mst_0_agent.AXI4LITE_WRITE_BURST(4*avg_len_reg, prot, data_wr, resp);
	#10;	

	// buf_addr_reg
	data_wr = 0;
	axi_mst_0_agent.AXI4LITE_WRITE_BURST(4*buf_addr_reg, prot, data_wr, resp);
	#10;	

	// buf_len_reg
	data_wr = 1280;
	axi_mst_0_agent.AXI4LITE_WRITE_BURST(4*buf_len_reg, prot, data_wr, resp);
	#10;	

	// avg_start_reg
	data_wr = 1;
	axi_mst_0_agent.AXI4LITE_WRITE_BURST(4*avg_start_reg, prot, data_wr, resp);
	#10;	

	// buf_start_reg
	data_wr = 1;
	axi_mst_0_agent.AXI4LITE_WRITE_BURST(4*buf_start_reg, prot, data_wr, resp);
	#10;	

	// Start sending input data.
	tb_input	<= 1;

	trigger_gen(5,4*1280);

	wait (tb_input_done);

	tb_input	<= 0;

	// avg_start_reg
	data_wr = 0;
	axi_mst_0_agent.AXI4LITE_WRITE_BURST(4*avg_start_reg, prot, data_wr, resp);
	#10;	

	// buf_start_reg
	data_wr = 0;
	axi_mst_0_agent.AXI4LITE_WRITE_BURST(4*buf_start_reg, prot, data_wr, resp);
	#10;	

	// Average DR.
	// * addr	= 0.
	// * len	= 10;

	// avg_dr_addr_reg
	data_wr = 0;
	axi_mst_0_agent.AXI4LITE_WRITE_BURST(4*avg_dr_addr_reg, prot, data_wr, resp);
	#10;	

	// avg_dr_len_reg
	data_wr = 10;
	axi_mst_0_agent.AXI4LITE_WRITE_BURST(4*avg_dr_len_reg, prot, data_wr, resp);
	#10;	

	// avg_dr_start_reg
	data_wr = 1;
	axi_mst_0_agent.AXI4LITE_WRITE_BURST(4*avg_dr_start_reg, prot, data_wr, resp);
	#10;	

	// avg_dr_start_reg
	data_wr = 0;
	axi_mst_0_agent.AXI4LITE_WRITE_BURST(4*avg_dr_start_reg, prot, data_wr, resp);
	#10;	

	#100;

	// Buffer DR.
	// * addr	= 0.
	// * len	= 1280*5 = 6400, I use 7000;

	// buf_dr_addr_reg
	data_wr = 0;
	axi_mst_0_agent.AXI4LITE_WRITE_BURST(4*buf_dr_addr_reg, prot, data_wr, resp);
	#10;	

	// buf_dr_len_reg
	data_wr = 7000;
	axi_mst_0_agent.AXI4LITE_WRITE_BURST(4*buf_dr_len_reg, prot, data_wr, resp);
	#10;	

	// buf_dr_start_reg
	data_wr = 1;
	axi_mst_0_agent.AXI4LITE_WRITE_BURST(4*buf_dr_start_reg, prot, data_wr, resp);
	#10;	

	// buf_dr_start_reg
	data_wr = 0;
	axi_mst_0_agent.AXI4LITE_WRITE_BURST(4*buf_dr_start_reg, prot, data_wr, resp);
	#10;	

	#20000;
end

// Input data.
initial begin
	int fd;
	int vali, valq;

	s_axis_tvalid	<= 0;
	s_axis_tdata	<= 0;
	tb_input_done	<= 0;
	
	wait (tb_input);

	fd = $fopen("../../../../../tb/data_iq.txt","r");
	
	while ($fscanf(fd,"%d,%d", vali, valq) == 2) begin
		$display("Time %t: I = %d, Q = %d", $time, vali, valq);		
		@(posedge s_axis_aclk);
		s_axis_tvalid	<= 1;
		s_axis_tdata[0 +: 16] <= vali;
		s_axis_tdata[16 +: 16] <= valq;
		@(posedge s_axis_aclk);
		s_axis_tvalid	<= 0;
		@(posedge s_axis_aclk);
		@(posedge s_axis_aclk);
	end

	@(posedge s_axis_aclk);
	s_axis_tvalid	<= 0;
	tb_input_done	<= 1;
	
end

// s_axi_aclk.
always begin
	s_axi_aclk <= 0;
	#10;
	s_axi_aclk <= 1;
	#10;
end

// s_axis_aclk.
always begin
	s_axis_aclk <= 0;
	#7;
	s_axis_aclk <= 1;
	#7;
end

// m_axis_aclk.
always begin
	m_axis_aclk <= 0;
	#3;
	m_axis_aclk <= 1;
	#3;
end  

task trigger_gen (input int cnt, input int waitc);
	for (int i=0; i<cnt; i = i+1) begin
		@(posedge s_axis_aclk);
		trigger	<= 1;
		@(posedge s_axis_aclk);
		@(posedge s_axis_aclk);
		@(posedge s_axis_aclk);
		@(posedge s_axis_aclk);
		trigger	<= 0;

		for (int j=0; j<waitc; j = j+1) begin
			@(posedge s_axis_aclk);
		end
		
	end	
endtask

endmodule

