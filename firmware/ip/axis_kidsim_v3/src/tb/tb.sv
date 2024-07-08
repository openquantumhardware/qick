import axi_vip_pkg::*;
import axi_mst_0_pkg::*;

module tb();

// Number of lanes.
parameter L	= 8;

// Number of bits.
localparam B 			= 16;
localparam NLAST 		= 4;
//localparam PUNCT_ID 	= NLAST-1;
localparam PUNCT_ID 	= 0;

// Modulation trigger.
reg	[L-1:0]			trigger			;

// AXI Slave I/F for configuration.
reg  				s_axi_aclk		;
reg  				s_axi_aresetn	;

wire [7:0]			s_axi_awaddr	;
wire [2:0]			s_axi_awprot	;
wire  				s_axi_awvalid	;
wire  				s_axi_awready	;

wire [31:0] 		s_axi_wdata		;
wire [3:0]			s_axi_wstrb		;
wire  				s_axi_wvalid	;
wire  				s_axi_wready	;

wire [1:0]			s_axi_bresp		;
wire  				s_axi_bvalid	;
wire  				s_axi_bready	;

wire [7:0] 			s_axi_araddr	;
wire [2:0] 			s_axi_arprot	;
wire  				s_axi_arvalid	;
wire  				s_axi_arready	;

wire [31:0] 		s_axi_rdata		;
wire [1:0]			s_axi_rresp		;
wire  				s_axi_rvalid	;
wire  		        s_axi_rready	;

// Reset and clock for axis_*.
reg 				aresetn			;
reg 				aclk			;

reg					s_axis_tvalid	;
wire	[32*L-1:0]	s_axis_tdata	;
reg					s_axis_tlast	;

// m_axis_* for output.
wire				m_axis_tvalid	;
wire	[32*L-1:0]	m_axis_tdata	;
wire				m_axis_tlast	;

// Input/output data vectors.
reg		[15:0]		din_real_v 	[L]	;
reg		[15:0]		din_imag_v 	[L]	;
wire	[15:0]		dout_real_v	[L]	;
wire	[15:0]		dout_imag_v	[L]	;
wire	[31:0]		dout_v 		[L]	;

// TDM.
reg						tdm_sync				;
wire	[32*NLAST-1:0]	dout_tdm_demux_v	[L]	;
wire	[L-1:0]			dout_valid_tdm_demux	;

// TDM-demuxed data.
wire	[31:0]			dout_tdm_v [L][NLAST]	;
wire	[15:0]			dout_tdm_real_v [L][NLAST];
wire	[15:0]			dout_tdm_imag_v [L][NLAST];

xil_axi_prot_t  prot        = 0;
reg[31:0]       data;
xil_axi_resp_t  resp;

// TB control.
reg tb_trigger = 0;

genvar i,j;
generate 
	for (i=0; i<L; i=i+1) begin : GEN_data
		// Input/Output data.
		assign s_axis_tdata [i*32 +: 32] = {din_imag_v[i], din_real_v[i]};
		assign dout_real_v	[i] = m_axis_tdata[i*32 +: 16];
		assign dout_imag_v	[i] = m_axis_tdata[i*32 + 16 +: 16];
		assign dout_v		[i] = {dout_imag_v[i], dout_real_v[i]};

		// TDM demux.
		tdm_demux
			#(
				.NCH(NLAST	),
				.B	(2*B	)
			)
			tdm_demux_i
			(
				// Reset and clock.
				.rstn		(aresetn				),
				.clk		(aclk					),
		
				// Resync.
				.sync		(tdm_sync				),
		
				// Data input.
				.din		(dout_v[i]				),
				.din_last	(m_axis_tlast			),
				.din_valid	(m_axis_tvalid			),
		
				// Data output.
				.dout		(dout_tdm_demux_v[i]	),
				.dout_valid	(dout_valid_tdm_demux[i])
			);

		// TDM-demuxed data.
		for (j=0; j<NLAST;j=j+1) begin : GEN_data_tdm
			assign dout_tdm_v[i][j] = dout_tdm_demux_v[i][j*32 +: 32];
			assign dout_tdm_real_v[i][j] = dout_tdm_v[i][j][15:0];
			assign dout_tdm_imag_v[i][j] = dout_tdm_v[i][j][31:16];
		end
	end
endgenerate

// AXI Master.
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

// DUT.
axis_kidsim_v3
	#(
		// Number of lanes.
		.L(L)
	)
	DUT
	( 	
		// Modulation trigger.
		.trigger		,

		// AXI Slave I/F for configuration.
		.s_axi_aclk		,
		.s_axi_aresetn	,

		.s_axi_awaddr	,
		.s_axi_awprot	,
		.s_axi_awvalid	,
		.s_axi_awready	,

		.s_axi_wdata	,
		.s_axi_wstrb	,
		.s_axi_wvalid	,
		.s_axi_wready	,

		.s_axi_bresp	,
		.s_axi_bvalid	,
		.s_axi_bready	,

		.s_axi_araddr	,
		.s_axi_arprot	,
		.s_axi_arvalid	,
		.s_axi_arready	,

		.s_axi_rdata	,
		.s_axi_rresp	,
		.s_axi_rvalid	,
		.s_axi_rready	,

		// Reset and clock for axis_*.
		.aresetn		,
		.aclk			,

		// s_axis_* for input.
		.s_axis_tvalid	,
		.s_axis_tdata	,
		.s_axis_tlast	,

		// m_axis_* for output.
		.m_axis_tvalid	,
		.m_axis_tdata	,
		.m_axis_tlast
	);

// VIP Agents
axi_mst_0_mst_t 	axi_mst_0_agent;

// Main TB.
initial begin
    real b, m, n, wc;
	real c0, c1, g, a;

	// Create agents.
	axi_mst_0_agent 	= new("axi_mst_0 VIP Agent",tb.axi_mst_0_i.inst.IF);

	// Set tag for agents.
	axi_mst_0_agent.set_agent_tag("axi_mst_0 VIP");

	// Start agents.
	axi_mst_0_agent.start_master();

	// Reset sequence.
	s_axi_aresetn 	<= 0;
	aresetn 	    <= 0;
	s_axis_tlast	<= 0;
	tdm_sync		<= 0;
	#500;
	s_axi_aresetn 	<= 1;
	aresetn 	    <= 1;

	#1000;

	// set PUNCT_REG > NLAST, so none resonator will be used.
	for (int i=0; i<L; i=i+1) begin
		// PUNCT_ID_REG.
		axi_mst_0_agent.AXI4LITE_WRITE_BURST(4*9, prot, 111, resp);

		// ADDR_REG.
		axi_mst_0_agent.AXI4LITE_WRITE_BURST(4*10, prot, i, resp);

		// WE_REG.
		axi_mst_0_agent.AXI4LITE_WRITE_BURST(4*11, prot, 1, resp);

		// WE_REG.
		axi_mst_0_agent.AXI4LITE_WRITE_BURST(4*11, prot, 0, resp);
	end

	// Configure DDS/Resonator.
	wc				= 0.1;
	b 				= 0.9*wc*2**B;
	m 				= 10;
	n 				= b/m;
	c0 				= 0.95;
	c1 				= 0.8;
	g				= (1+c1)/(1+c0);

	// DDS_BVAL_REG	<= integer'(b);
	//axi_mst_0_agent.AXI4LITE_WRITE_BURST(4*0, prot, integer'(b), resp);
	axi_mst_0_agent.AXI4LITE_WRITE_BURST(4*0, prot, 200, resp);

	// DDS_SLOPE_REG	<= integer'(m);
	//axi_mst_0_agent.AXI4LITE_WRITE_BURST(4*1, prot, integer'(m), resp);
	axi_mst_0_agent.AXI4LITE_WRITE_BURST(4*1, prot, 2, resp);

	// DDS_STEPS_REG	<= integer'(n);
	//axi_mst_0_agent.AXI4LITE_WRITE_BURST(4*2, prot, integer'(n), resp);
	axi_mst_0_agent.AXI4LITE_WRITE_BURST(4*2, prot, 100, resp);

	// DDS_WAIT_REG	<= 50;
	axi_mst_0_agent.AXI4LITE_WRITE_BURST(4*3, prot, 0, resp);

	// DDS_FREQ_REG 	<= wc*2**B;
	//axi_mst_0_agent.AXI4LITE_WRITE_BURST(4*4, prot, wc*2**B, resp);
	axi_mst_0_agent.AXI4LITE_WRITE_BURST(4*4, prot, 273, resp);

	// IIR_C0_REG		<= c0*(2**(B-1));
	axi_mst_0_agent.AXI4LITE_WRITE_BURST(4*5, prot, c0*(2**(B-1)), resp);

	// IIR_C1_REG		<= c1*(2**(B-1));
	axi_mst_0_agent.AXI4LITE_WRITE_BURST(4*6, prot, c1*(2**(B-1)), resp);

	// IIR_G_REG		<= g*(2**(B-1));
	axi_mst_0_agent.AXI4LITE_WRITE_BURST(4*7, prot, g*(2**(B-1)), resp);

	// OUTSEL_ID_REG
	// 0 : Resonator, 1 : DDS, 2 : by-pass.
	axi_mst_0_agent.AXI4LITE_WRITE_BURST(4*8, prot, 1, resp);

	// PUNCT_ID_REG
	axi_mst_0_agent.AXI4LITE_WRITE_BURST(4*9, prot, PUNCT_ID, resp);

	// ADDR_REG.
	axi_mst_0_agent.AXI4LITE_WRITE_BURST(4*10, prot, 0, resp);

	// WE_REG.
	axi_mst_0_agent.AXI4LITE_WRITE_BURST(4*11, prot, 1, resp);

	// WE_REG.
	axi_mst_0_agent.AXI4LITE_WRITE_BURST(4*11, prot, 0, resp);

	// ADDR_REG.
	//axi_mst_0_agent.AXI4LITE_WRITE_BURST(4*10, prot, 1, resp);

	// WE_REG.
	//axi_mst_0_agent.AXI4LITE_WRITE_BURST(4*11, prot, 1, resp);

	// WE_REG.
	//axi_mst_0_agent.AXI4LITE_WRITE_BURST(4*11, prot, 0, resp);

	#10000;

	tb_trigger <= 1;
end

// Data generation.
initial begin
	int n, idx;

	s_axis_tvalid 	<= 1;

	//while (1) begin
	//	@(posedge aclk);
	//	for (int i=0; i<L; i=i+1) begin
	//		din_real_v[i] <= $random;
	//		din_imag_v[i] <= $random;
	//		//din_real_v[i] <= 0;
	//		//din_imag_v[i] <= 0;
	//	end
	//end

	n = 0;
	idx = 0;
	//while (1) begin
	//	@(posedge aclk);
	//	for (int i=0; i<L; i=i+1) begin
	//		// Sine wave on Lane 0.
	//		if ( i == 0 ) begin
	//			din_real_v[i]	<= 0.9*(2**(B-1))*$cos(2*3.14*0.007*n);
	//			din_imag_v[i]	<= 0.9*(2**(B-1))*$sin(2*3.14*0.007*n);
	//			n = n + 1;
	//		end
	//		else begin
	//			//din_real_v[i] <= $random;
	//			//din_imag_v[i] <= $random;
	//			din_real_v[i] <= 0;
	//			din_imag_v[i] <= 0;
	//		end
	//	end
	//end

	while (1) begin
		for (int i=0; i<NLAST-1; i=i+1) begin
			@(posedge aclk);
			s_axis_tlast <= 0;
			for (int j=0; j<L; j=j+1) begin
				din_real_v[j] <= 0;
				din_imag_v[j] <= 0;
			end
		end
		@(posedge aclk);
		s_axis_tlast <= 1;
		for (int j=0; j<L; j=j+1) begin
			// Sine wave on all lanes.
			din_real_v[j]	<= 0.9*(2**(B-1))*$cos(2*3.14*0.007*n);
			din_imag_v[j]	<= 0.9*(2**(B-1))*$sin(2*3.14*0.007*n);
			n = n + 1;
		end
	end
end

// tlast generation.
//initial begin
//	s_axis_tlast	<= 0;
//
//	while (1) begin
//		for (int i=0; i<NLAST-1; i=i+1) begin
//			@(posedge aclk);
//			s_axis_tlast <= 0;
//		end
//		@(posedge aclk);
//		s_axis_tlast <= 1;
//	end
//end

initial begin
	trigger <= 0;

	wait (tb_trigger);

	#10000;

	trigger <= 8'b00000001;
	#100;

	trigger <= 0;
	
end

always begin
	s_axi_aclk <= 0;
	#7;
	s_axi_aclk <= 1;
	#7;
end

always begin
	aclk <= 0;
	#5;
	aclk <= 1;
	#5;
end  

endmodule

