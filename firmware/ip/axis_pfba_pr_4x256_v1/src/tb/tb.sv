import axi_vip_pkg::*;
import axi_mst_0_pkg::*;

module tb();

parameter L = 4;

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

reg						aresetn;
reg						aclk;

wire					s_axis_tready;
reg						s_axis_tvalid;
reg		[4*32-1:0]		s_axis_tdata;

wire					m_axis_tvalid;
wire					m_axis_tlast;
reg		[8*32-1:0]		m_axis_tdata;


xil_axi_prot_t  prot        = 0;
reg[31:0]       data_wr     = 32'h12345678;
reg[31:0]       data;
xil_axi_resp_t  resp;

// Input data.
reg	[31:0]	din_ii [0:7];

// Output data.
wire[31:0]	dout_ii [0:2*L-1];
wire[15:0]	dout_real_ii [0:2*L-1];
wire[15:0]	dout_imag_ii [0:2*L-1];

// Test bench control.
reg tb_data		= 0;
reg tb_data_done= 0;
reg	tb_write_out= 0;

generate
genvar ii;
for (ii = 0; ii < L; ii = ii + 1) begin
    assign s_axis_tdata[32*ii +: 32] = din_ii[ii];
	assign dout_ii[ii] = m_axis_tdata[32*ii +: 32];
	assign dout_ii[ii+L] = m_axis_tdata[32*(ii+L) +: 32];
	assign dout_real_ii[ii] = m_axis_tdata[32*ii +: 16];
	assign dout_real_ii[ii+L] = m_axis_tdata[32*(ii+L) +: 16];
	assign dout_imag_ii[ii] = m_axis_tdata[32*ii+16 +: 16];
	assign dout_imag_ii[ii+L] = m_axis_tdata[32*(ii+L)+16 +: 16];
end
endgenerate

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

axis_pfba_pr_4x256_v1
	DUT 
	( 
		// AXI Slave I/F for configuration.
		.s_axi_aclk		,
		.s_axi_aresetn	,
		.s_axi_araddr	,
		.s_axi_arprot	,
		.s_axi_arready	,
		.s_axi_arvalid	,
		.s_axi_awaddr	,
		.s_axi_awprot	,
		.s_axi_awready	,
		.s_axi_awvalid	,
		.s_axi_bready	,
		.s_axi_bresp	,
		.s_axi_bvalid	,
		.s_axi_rdata	,
		.s_axi_rready	,
		.s_axi_rresp	,
		.s_axi_rvalid	,
		.s_axi_wdata	,
		.s_axi_wready	,
		.s_axi_wstrb	,
		.s_axi_wvalid	,

		// s_* and m_* reset/clock.
		.aresetn		,
		.aclk			,

    	// S_AXIS for data input.
		.s_axis_tvalid	,
        .s_axis_tready	,
		.s_axis_tdata	,

		// M_AXIS for data output.
		.m_axis_tvalid	,
		.m_axis_tlast	,
		.m_axis_tdata
	);

// VIP Agents
axi_mst_0_mst_t 	axi_mst_0_agent;

initial begin
	// Create agents.
	axi_mst_0_agent 	= new("axi_mst_0 VIP Agent",tb.axi_mst_0_i.inst.IF);

	// Set tag for agents.
	axi_mst_0_agent.set_agent_tag	("axi_mst_0 VIP");

	// Start agents.
	axi_mst_0_agent.start_master();

	// Reset sequence.
	s_axi_aresetn 		<= 0;
	aresetn 			<= 0;
	#500;
	s_axi_aresetn 		<= 1;
	aresetn 			<= 1;

	#1000;

	// QOUT_REG
	data_wr = 8;
	axi_mst_0_agent.AXI4LITE_WRITE_BURST(0*4, prot, data_wr, resp);
	#10;

	// Wait until FIR framing is done.
	#48000;

	// Start data.
	tb_data 		<= 1;
	#3500;
	tb_write_out 	<= 1;
	wait (tb_data_done);
	tb_write_out 	<= 0;
end

// Input data.
initial begin
	int fd;
	int i;
	bit signed [15:0] vali, valq;
	s_axis_tvalid 	<= 1;

	// Open file with Coefficients.
	fd = $fopen("../../../../../tb/data_iq.txt","r");

	wait(tb_data);
	@(posedge aclk);
	
	i = 0;
	while ($fscanf(fd,"%d,%d", vali, valq) == 2) begin
		//$display("T = %d, i = %d, I = %d, Q = %d", $time, i, vali, valq);		
		din_ii[i] <= {valq,vali};
		i = i + 1;
		if (i == L) begin
		    i = 0;
			@(posedge aclk);
			//s_axis_tvalid <= 1;
		end
	end

	@(posedge aclk);
	//s_axis_tvalid <= 0;
	tb_data_done <= 1;

end

// Write output into file.
initial begin
	int fd;
	int i;
	shortint real_d, imag_d;

	// Output file.
	fd = $fopen("../../../../../tb/dout.csv","w");

	// Data format.
	$fdisplay(fd, "valid, last, real, imag");

	wait (tb_write_out);
	wait (m_axis_tlast);
	wait (!m_axis_tlast);

	while (tb_write_out) begin
		@(posedge aclk);
		for (int i=0; i<2*L; i = i+1) begin
			real_d = m_axis_tdata[32*i 		+: 16];
			imag_d = m_axis_tdata[32*i+16	+: 16];
			$fdisplay(fd,"%d,%d,%d,%d",m_axis_tvalid,m_axis_tlast,real_d,imag_d);
		end
	end

	$display("Closing file, t = %0t", $time);
	$fclose(fd);
end

always begin
	s_axi_aclk <= 0;
	#10;
	s_axi_aclk <= 1;
	#10;
end

always begin
	aclk <= 0;
	#5;
	aclk <= 1;
	#5;
end  

endmodule

