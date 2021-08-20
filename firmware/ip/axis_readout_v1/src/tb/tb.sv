// VIP: axi_mst_0
// DUT: axis_readout_v1
// 	IF: s_axi -> axi_mst_0

import axi_vip_pkg::*;
import axi_mst_0_pkg::*;

module tb();

// Define Behavioral or Post-Synthesis simulation.
//`define SYNTH_SIMU

localparam N_DDS = 8;

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

// s_axis interfase.
wire					s_axis_tready;
reg						s_axis_tvalid;
reg		[N_DDS*16-1:0]	s_axis_tdata;

// m0_axis interfase.
reg 					m0_axis_tready;
wire					m0_axis_tvalid;
reg		[N_DDS*32-1:0]	m0_axis_tdata;

// m1_axis interfase.
reg 					m1_axis_tready;
wire					m1_axis_tvalid;
reg		[32-1:0]		m1_axis_tdata;

// Assignment of data out for debugging.
wire	[31:0]			dout_ii [0:N_DDS-1];

xil_axi_prot_t  prot        = 0;
reg[31:0]       data_wr     = 32'h12345678;
reg[31:0]       data;
xil_axi_resp_t  resp;

// Test bench control.
reg tb_data_in		= 0;
reg tb_data_in_done	= 0;
reg	tb_write_out 	= 0;

// Debug.
generate
genvar ii;
for (ii = 0; ii < N_DDS; ii = ii + 1) begin : GEN_debug
    assign dout_ii[ii] = m0_axis_tdata[32*ii +: 32];
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

axis_readout_v1
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

		// s_* and m_* reset/clock.
		.aresetn		(aresetn		),
		.aclk			(aclk	 		),

    	// S_AXIS: for input data (8x samples per clock).
		.s_axis_tdata	(s_axis_tdata 	),
		.s_axis_tvalid	(s_axis_tvalid	),
        .s_axis_tready	(s_axis_tready	),

		// M0_AXIS: for output data (before filter and decimation, 8x samples
		// per clock).
		.m0_axis_tready	(m0_axis_tready	),
		.m0_axis_tvalid	(m0_axis_tvalid	),
		.m0_axis_tdata	(m0_axis_tdata 	),

		// M1_AXIS: for output data.
		.m1_axis_tready	(m1_axis_tready	),
		.m1_axis_tvalid	(m1_axis_tvalid	),
		.m1_axis_tdata	(m1_axis_tdata 	)
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
	m0_axis_tready		<= 1;
	m1_axis_tready		<= 1;
	aresetn 			<= 0;
	#500;
	s_axi_aresetn 		<= 1;
	aresetn 			<= 1;

	#1000;
	
	$display("###############################");
	$display("### Start Recording Outputs ###");
	$display("###############################");
	$display("t = %0t", $time);

	tb_write_out	<= 1;
		
	
	$display("#############################");
	$display("### Select M0_AXIS output ###");
	$display("#############################");
	$display("t = %0t", $time);

	data_wr = 2;
	axi_mst_0_agent.AXI4LITE_WRITE_BURST(0, prot, data_wr, resp);
	#10;	

	#1000;

	$display("###################");
	$display("### Program DDS ###");
	$display("###################");
	$display("t = %0t", $time);

	data_wr = freq_calc(100, N_DDS, 625);
	axi_mst_0_agent.AXI4LITE_WRITE_BURST(4, prot, data_wr, resp);
	#10;	

	#1000;

	#1000;

	$display("#######################");
	$display("### Send Input Data ###");
	$display("#######################");
	$display("t = %0t", $time);
	tb_data_in		<= 1;

	wait (tb_data_in_done);

	#1000;

	$display("##############################");
	$display("### Stop Recording Outputs ###");
	$display("##############################");
	$display("t = %0t", $time);
	tb_write_out 	<= 0;

	#20000;

end

// Input data.
initial begin
	int fd, i;
	bit signed [15:0] vali, valq;

	tb_data_in_done	<= 0;
	s_axis_tvalid	<= 1;
	s_axis_tdata	<= 0;

	wait (tb_data_in);

	#1000;

	// Open file with input data.
	// Format: I, Q.
	`ifdef SYNTH_SIMU
		fd = $fopen("../../../../../../tb/data_iq.txt","r");
	`else
		fd = $fopen("../../../../../tb/data_iq.txt","r");
	`endif
	
	//i = N_DDS;
	i = 0;
	while ($fscanf(fd,"%d,%d", vali, valq) == 2) begin
		$display("Time %t: Line %d, I = %d, Q = %d", $time, i, vali, valq);		
		//s_axis_tdata_i[(i-1)*16 +: 16] <= vali;
		s_axis_tdata[i*16 +: 16] <= vali;
		//i = i - 1;
		i = i + 1;
		//if ( i == 0) begin
		if ( i == N_DDS) begin
			//i = N_DDS;
			i = 0;
			@(posedge aclk);
		end
	end
	
	#1000;
	
	@(posedge aclk);
	tb_data_in_done		<= 1;

end

// Write output into file.
initial begin
	int fd;
	int i;
	shortint real_d, imag_d;

	// Output file.
	`ifdef SYNTH_SIMU
		fd = $fopen("../../../../../../tb/dout_fs.csv","w");
	`else
		fd = $fopen("../../../../../tb/dout_fs.csv","w");
	`endif

	// Data format.
	$fdisplay(fd, "valid, idx, real, imag");

	wait (tb_write_out);

	while (tb_write_out) begin
		@(posedge aclk);
		for (i=0; i<N_DDS; i = i+1) begin
			real_d = dout_ii[i][15:0];
			imag_d = dout_ii[i][31:16];
			$fdisplay(fd, "%d, %d, %d, %d", m0_axis_tvalid, i, real_d, imag_d);
		end
	end

	$display("Closing file, t = %0t", $time);
	$fclose(fd);
end

// Write output into file.
initial begin
	int fd;
	int i;
	shortint real_d, imag_d;

	// Output file.
	`ifdef SYNTH_SIMU
		fd = $fopen("../../../../../../tb/dout.csv","w");
	`else
		fd = $fopen("../../../../../tb/dout.csv","w");
	`endif

	// Data format.
	$fdisplay(fd, "valid, real, imag");

	wait (tb_write_out);

	while (tb_write_out) begin
		@(posedge aclk);
		real_d = m1_axis_tdata[15:0];
		imag_d = m1_axis_tdata[31:16];
		$fdisplay(fd, "%d, %d, %d", m1_axis_tvalid, real_d, imag_d);
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

// Function to compute frequency register.
function [15:0] freq_calc;
    input int fclk;
    input int ndds;
    input int f;
    
	// All input frequencies are in MHz.
	real fs,temp;
	fs = fclk*ndds;
	temp = f/fs*2**16;
	freq_calc = int'(temp);
endfunction

endmodule

