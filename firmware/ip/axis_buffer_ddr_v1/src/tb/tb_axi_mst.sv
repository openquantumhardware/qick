import axi_vip_pkg::*;
import axi_slv_0_pkg::*;

module tb();

// DUT generics.
parameter TARGET_SLAVE_BASE_ADDR 	= 32'h40000000;
parameter ID_WIDTH 					= 1;
parameter DATA_WIDTH 				= 256;

// Reset and Clock.
reg							m_axi_aclk		;
reg							m_axi_aresetn	;

// Write Address Channel.
wire	[ID_WIDTH-1:0]		m_axi_awid		;
wire	[31:0]				m_axi_awaddr	;
wire	[7:0]				m_axi_awlen		;
wire	[2:0]				m_axi_awsize	;
wire	[1:0]				m_axi_awburst	;
wire						m_axi_awlock	;
wire	[3:0]				m_axi_awcache	;
wire	[2:0]				m_axi_awprot	;
wire	[3:0]				m_axi_awregion	;
wire	[3:0]				m_axi_awqos		;
wire						m_axi_awvalid	;
wire						m_axi_awready	;

// Write Data Channel.
wire	[DATA_WIDTH-1:0]	m_axi_wdata		;
wire	[DATA_WIDTH/8-1:0]	m_axi_wstrb		;
wire						m_axi_wlast		;
wire						m_axi_wvalid	;
wire						m_axi_wready	;

// Write Response Channel.
wire	[ID_WIDTH-1:0]		m_axi_bid		;
wire	[1:0]				m_axi_bresp		;
wire						m_axi_bvalid	;
wire						m_axi_bready	;

// Read Address Channel.
wire	[ID_WIDTH-1:0]		m_axi_arid		;
wire	[31:0]				m_axi_araddr	;
wire	[7:0]				m_axi_arlen		;
wire	[2:0]				m_axi_arsize	;
wire	[1:0]				m_axi_arburst	;
wire						m_axi_arlock	;
wire	[3:0]				m_axi_arcache	;
wire	[2:0]				m_axi_arprot	;
wire	[3:0]				m_axi_arregion	;
wire	[3:0]				m_axi_arqos		;
wire						m_axi_arvalid	;
wire						m_axi_arready	;

// Read Data Channel.
wire	[ID_WIDTH-1:0]		m_axi_rid		;
wire	[DATA_WIDTH-1:0]	m_axi_rdata		;
wire	[1:0]				m_axi_rresp		;
wire						m_axi_rlast		;
wire						m_axi_rvalid	;
wire						m_axi_rready	;

/*************************/
/* AXIS Master Interfase */
/*************************/
wire						m_axis_tvalid	;
wire	[DATA_WIDTH-1:0]	m_axis_tdata	;
wire	[DATA_WIDTH/8-1:0]	m_axis_tstrb	;
wire						m_axis_tlast	;
reg							m_axis_tready	;

/************************/
/* AXIS Slave Interfase */
/************************/
wire						s_axis_tready	;
reg		[DATA_WIDTH-1:0]	s_axis_tdata	;
reg		[DATA_WIDTH/8-1:0]	s_axis_tstrb	;
reg							s_axis_tlast	;
reg							s_axis_tvalid	;

// Registers.
reg							RSTART_REG		;
reg	[31:0]					RADDR_REG		;
reg	[31:0]					RLENGTH_REG		;
reg							WSTART_REG		;
reg	[31:0]					WADDR_REG		;

xil_axi_prot_t  			prot	= 0;
reg	[31:0]       			data_wr	= 32'h12345678;
reg	[31:0]       			data;
reg	[DATA_WIDTH-1:0]        data_mem;
xil_axi_resp_t  			resp;

reg							tb_din_start = 0;
reg							tb_dout_start = 0;

axi_mst
	#(
		// Parameters of AXI Master I/F.
		.TARGET_SLAVE_BASE_ADDR	(TARGET_SLAVE_BASE_ADDR	),
		.ID_WIDTH				(ID_WIDTH				),
		.DATA_WIDTH				(DATA_WIDTH				)
	)
	axi_mst_i
	(
		/**************/
		/* AXI Master */
		/**************/

		// Reset and Clock.
		.m_axi_aclk		,
		.m_axi_aresetn	,

		// Write Address Channel.
		.m_axi_awid		,
		.m_axi_awaddr	,
		.m_axi_awlen	,
		.m_axi_awsize	,
		.m_axi_awburst	,
		.m_axi_awlock	,
		.m_axi_awcache	,
		.m_axi_awprot	,
		.m_axi_awregion	,
		.m_axi_awqos	,
		.m_axi_awvalid	,
		.m_axi_awready	,

		// Write Data Channel.
		.m_axi_wdata	,
		.m_axi_wstrb	,
		.m_axi_wlast	,
		.m_axi_wvalid	,
		.m_axi_wready	,

		// Write Response Channel.
		.m_axi_bid		,
		.m_axi_bresp	,
		.m_axi_bvalid	,
		.m_axi_bready	,

		// Read Address Channel.
		.m_axi_arid		,
		.m_axi_araddr	,
		.m_axi_arlen	,
		.m_axi_arsize	,
		.m_axi_arburst	,
		.m_axi_arlock	,
		.m_axi_arcache	,
		.m_axi_arprot	,
		.m_axi_arregion	,
		.m_axi_arqos	,
		.m_axi_arvalid	,
		.m_axi_arready	,

		// Read Data Channel.
		.m_axi_rid		,
		.m_axi_rdata	,
		.m_axi_rresp	,
		.m_axi_rlast	,
		.m_axi_rvalid	,
		.m_axi_rready	,

		/*************************/
		/* AXIS Master Interfase */
		/*************************/
		.m_axis_tvalid	,
		.m_axis_tdata	,
		.m_axis_tstrb	,
		.m_axis_tlast	,
		.m_axis_tready	,

		/************************/
		/* AXIS Slave Interfase */
		/************************/
		.s_axis_tready	,
		.s_axis_tdata	,
		.s_axis_tstrb	,
		.s_axis_tlast	,
		.s_axis_tvalid	,

		// Registers.
		.RSTART_REG		,
		.RADDR_REG		,
		.RLENGTH_REG	,
		.WSTART_REG		,
		.WADDR_REG
	);

axi_slv_0 axi_slv_0_i
	(
		.aclk			(m_axi_aclk		),
		.aresetn		(m_axi_aresetn	),

		.s_axi_araddr	(m_axi_araddr	),
		.s_axi_arburst	(m_axi_arburst	),
		.s_axi_arcache	(m_axi_arcache	),
		.s_axi_arid		(m_axi_arid		),
		.s_axi_arlen	(m_axi_arlen	),
		.s_axi_arlock	(m_axi_arlock	),
		.s_axi_arprot	(m_axi_arprot	),
		.s_axi_arqos	(m_axi_arqos	),
		.s_axi_arready	(m_axi_arready	),
		.s_axi_arregion	(m_axi_arregion	),
		.s_axi_arsize	(m_axi_arsize	),
		.s_axi_arvalid	(m_axi_arvalid	),

		.s_axi_awaddr	(m_axi_awaddr	),
		.s_axi_awburst	(m_axi_awburst	),
		.s_axi_awcache	(m_axi_awcache	),
		.s_axi_awid		(m_axi_awid		),
		.s_axi_awlen	(m_axi_awlen	),
		.s_axi_awlock	(m_axi_awlock	),
		.s_axi_awprot	(m_axi_awprot	),
		.s_axi_awqos	(m_axi_awqos	),
		.s_axi_awready	(m_axi_awready	),
		.s_axi_awregion	(m_axi_awregion	),
		.s_axi_awsize	(m_axi_awsize	),
		.s_axi_awvalid	(m_axi_awvalid	),

		.s_axi_bid		(m_axi_bid		),
		.s_axi_bready	(m_axi_bready	),
		.s_axi_bresp	(m_axi_bresp	),
		.s_axi_bvalid	(m_axi_bvalid	),

		.s_axi_rdata	(m_axi_rdata	),
		.s_axi_rid		(m_axi_rid		),
		.s_axi_rlast	(m_axi_rlast	),
		.s_axi_rready	(m_axi_rready	),
		.s_axi_rresp	(m_axi_rresp	),
		.s_axi_rvalid	(m_axi_rvalid	),

		.s_axi_wdata	(m_axi_wdata	),
		.s_axi_wlast	(m_axi_wlast	),
		.s_axi_wready	(m_axi_wready	),
		.s_axi_wstrb	(m_axi_wstrb	),
		.s_axi_wvalid	(m_axi_wvalid	)
	);
	
// VIP Agents
axi_slv_0_slv_mem_t axi_slv_0_agent;

initial begin
	// Create agents.
	axi_slv_0_agent = new("axi_slv_0 VIP Agent",tb.axi_slv_0_i.inst.IF);
	
	// AXI Slave (memory model) beat gap.
	axi_slv_0_agent.mem_model.set_inter_beat_gap_delay_policy(XIL_AXI_MEMORY_DELAY_RANDOM);
	axi_slv_0_agent.mem_model.set_inter_beat_gap_range(10,20);

	// Set tag for agents.
	axi_slv_0_agent.set_agent_tag("axi_slv_0 VIP");

	// Start agents.
	axi_slv_0_agent.start_slave();

	// Reset sequence.
	m_axi_aresetn	<= 0;
	RSTART_REG		<= 0;
	RADDR_REG		<= 0;
	RLENGTH_REG		<= 10;
	WSTART_REG		<= 0;
	WADDR_REG		<= 0;
	#5000;
	m_axi_aresetn <= 1;
	
	#1000;
	
	$display("##############");
	$display("### Test 0 ###");
	$display("##############");
	
	#1000;

	// Write data into memory.
	WSTART_REG <= 1;
	tb_din_start <= 1;

	#1000;
	
	// Backdoor memory read.
	for (int addr = TARGET_SLAVE_BASE_ADDR+0; addr < TARGET_SLAVE_BASE_ADDR+0+160; addr = addr + DATA_WIDTH/8) begin
	   data_mem = axi_slv_0_agent.mem_model.backdoor_memory_read(addr);
	   $display("Addr: 0x%04X, Data: 0x%04X", addr, data_mem);
	end 

	#1000;

	WSTART_REG <= 0;
	
	#1000;

	// Read from memory.
	RSTART_REG <= 1;
	tb_dout_start <= 1;
end

// Data input process.
initial begin
	s_axis_tdata 	<= 0;
	s_axis_tstrb 	<= '1;
	s_axis_tlast 	<= 0;
	s_axis_tvalid 	<= 0;

	wait (tb_din_start);

	for (int i=0; i<1000; i=i+1) begin
		wait (s_axis_tready);

		@(posedge m_axi_aclk);
		@(posedge m_axi_aclk);
		s_axis_tdata 	<= i;
		s_axis_tvalid	<= 1;	
		@(posedge m_axi_aclk);
		s_axis_tvalid	<= 0;	
		@(posedge m_axi_aclk);
		@(posedge m_axi_aclk);
		@(posedge m_axi_aclk);
	end
end

// Data output process.
initial begin
	m_axis_tready	<= 0;

	wait (tb_dout_start);

	@(posedge m_axi_aclk);
	m_axis_tready	<= 1;
end

always begin
	m_axi_aclk <= 0;
	#1.7;
	m_axi_aclk <= 1;
	#1.7;
end

endmodule

