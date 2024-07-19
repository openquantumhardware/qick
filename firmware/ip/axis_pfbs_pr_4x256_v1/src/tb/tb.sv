import axi_vip_pkg::*;
import axi_mst_0_pkg::*;

module tb();

`timescale 1ns/1ps

parameter N = 256;
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

wire 	[8*32-1:0]		s_axis_tdata;
reg						s_axis_tlast;
reg						s_axis_tvalid;
wire					s_axis_tready;

wire	[4*32-1:0]		m_axis_tdata;
wire					m_axis_tvalid;


xil_axi_prot_t  prot        = 0;
reg[31:0]       data_wr     = 32'h12345678;
reg[31:0]       data;
xil_axi_resp_t  resp;

// Input data.
wire[31:0]	din_ii 		[2*L];
reg signed [15:0]	din_real_ii [2*L];
reg signed [15:0]	din_imag_ii [2*L];

// Output data.
wire[31:0]	dout_ii 	[L];
wire[15:0]	dout_real_ii[L];
wire[15:0]	dout_imag_ii[L];

// Debug.
reg				faclk;
reg	[31:0]		debug_v;
reg	[15:0]		debug_v_real;
reg	[15:0]		debug_v_imag;

// Test bench control.
reg tb_data		= 0;
reg tb_data_done= 0;
reg	tb_write_out= 0;

generate
genvar ii;
for (ii = 0; ii < L; ii = ii + 1) begin
	// Input data.
	assign din_ii		[ii]				= {din_imag_ii[ii]	, din_real_ii[ii]};
	assign din_ii		[ii+L]				= {din_imag_ii[ii+L], din_real_ii[ii+L]};

    assign s_axis_tdata	[32*ii 		+: 32] 	= din_ii[ii];
    assign s_axis_tdata	[32*(ii+L) 	+: 32] 	= din_ii[ii+L];

	assign dout_ii		[ii] 				= m_axis_tdata[32*ii +: 32];
	assign dout_real_ii	[ii] 				= dout_ii[ii][15:0];
	assign dout_imag_ii	[ii] 				= dout_ii[ii][31:16];
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

axis_pfbsynth_4x256_v1
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
		.s_axis_tdata	,
		.s_axis_tlast	,
		.s_axis_tvalid	,
		.s_axis_tready	,

		// M_AXIS for data output.
		.m_axis_tdata	,
		.m_axis_tvalid
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
	data_wr = 4;
	axi_mst_0_agent.AXI4LITE_WRITE_BURST(0*4, prot, data_wr, resp);
	#10;	

	// Start data.
	tb_data 		<= 1;
	#10000;
	tb_write_out 	<= 1;
	wait (tb_data_done);
	tb_write_out 	<= 0;
end

// Input data.
initial begin
	real pi;
	real w;
	real a;
	int n;

	s_axis_tlast	<= 0;
	s_axis_tvalid 	<= 0;

	wait(tb_data);
	@(posedge aclk);
	
	n = 0;
	pi = 3.1415;
	w  = 0.07;
	a = 0.9;
	for (int k=0; k<500; k=k+1) begin
		for (int i=0; i<N/(2*L); i=i+1) begin
			@(posedge aclk);
			s_axis_tvalid	<= 1;
			if (i == (N/(2*L))-1)
				s_axis_tlast <= 1;
			else
				s_axis_tlast <= 0;

			for (int j=0; j<2*L; j=j+1) begin
				if (i == 0) begin
					if (j == 3) begin
						din_real_ii [j] <= a*(2**15-1);
						din_imag_ii [j] <= 0;
					end
					//else if (j == 5) begin
					//	din_real_ii [j] <= 12345;
					//	din_imag_ii [j] <= 0;
					//end
					else begin
						din_real_ii [j] <= ($urandom_range(0,10)-5);
						din_imag_ii [j] <= ($urandom_range(0,10)-5);
					end
				end
				//else if (i == 1) begin
				//	if (j == 0) begin
				//		din_real_ii [j] <= -2232;
				//		din_imag_ii [j] <= 4444;
				//	end
				//	else if (j == 7) begin
				//		din_real_ii [j] <= 2232;
				//		din_imag_ii [j] <= -4444;
				//	end
				//	else begin
				//		din_real_ii [j] <= ($urandom_range(0,10)-5);
				//		din_imag_ii [j] <= ($urandom_range(0,10)-5);
				//	end
				//end
				//else if (i == 3) begin
				//	if (j == 1) begin
				//		//din_real_ii [j] <= 2232;
				//		//din_imag_ii [j] <= -4444;
				//		din_real_ii [j]	<= a*(2**15-1)*$cos(2*pi*w*n);
				//		din_imag_ii [j]	<= a*(2**15-1)*$sin(2*pi*w*n);
				//		n = n + 1;
				//	end
				//	else begin
				//		din_real_ii [j] <= ($urandom_range(0,10)-5);
				//		din_imag_ii [j] <= ($urandom_range(0,10)-5);
				//	end
				//end
				else begin
					din_real_ii [j] <= ($urandom_range(0,10)-5);
					din_imag_ii [j] <= ($urandom_range(0,10)-5);
				end
			end
		end
	end

	@(posedge aclk);
	tb_data_done <= 1;

end

// Parallel to serial conversion.
initial begin
    while(1) begin
		@(posedge aclk);
		for (int i=0; i<L; i=i+1) begin
			@(posedge faclk);
			debug_v 		<= m_axis_tdata [i*32 +: 32];
			debug_v_real	<= debug_v[15:0];
			debug_v_imag	<= debug_v[31:16];
		end
	end
end

// Write output into file.
initial begin
	int fd;
	int i;
	shortint real_d, imag_d;

	// Output file.
	fd = $fopen("../../../../../tb/dout.csv","w");

	// Data format.
	$fdisplay(fd, "real, imag");

	wait (tb_write_out);

	while (tb_write_out) begin
		@(posedge faclk);
		real_d = debug_v_real;
		imag_d = debug_v_imag;
		$fdisplay(fd,"%d,%d",real_d,imag_d);
	end

	$display("Closing file, t = %0t", $time);
	$fclose(fd);
end

always begin
	s_axi_aclk <= 0;
	#5;
	s_axi_aclk <= 1;
	#5;
end

always begin
	aclk <= 0;
	#8;
	aclk <= 1;
	#8;
end  

always begin
	faclk <= 0;
	#2;
	faclk <= 1;
	#2;
end  

endmodule

