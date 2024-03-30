import axi_vip_pkg::*;
import axi_mst_0_pkg::*;

module tb();

// Number of channels.
parameter N = 64;

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

reg						s_axis_tvalid;
wire	[4*32-1:0]		s_axis_tdata;

wire					m0_axis_tvalid;
reg		[31:0]			m0_axis_tdata;
wire					m1_axis_tvalid;
reg		[31:0]			m1_axis_tdata;
wire					m2_axis_tvalid;
reg		[31:0]			m2_axis_tdata;
wire					m3_axis_tvalid;
reg		[31:0]			m3_axis_tdata;


xil_axi_prot_t  prot        = 0;
reg[31:0]       data_wr     = 32'h12345678;
reg[31:0]       data;
xil_axi_resp_t  resp;

// Input data.
reg	[31:0]	din_ii [0:7];

// Output data.
wire [15:0]	dout0_real;
wire [15:0]	dout0_imag;
wire [15:0]	dout1_real;
wire [15:0]	dout1_imag;
wire [15:0]	dout2_real;
wire [15:0]	dout2_imag;
wire [15:0]	dout3_real;
wire [15:0]	dout3_imag;

// Test bench control.
reg tb_data		= 0;
reg tb_data_done= 0;
reg	tb_write_out= 0;


generate
genvar ii;
for (ii = 0; ii < 8; ii = ii + 1) begin
    assign s_axis_tdata[32*ii +: 32] = din_ii[ii];
end
endgenerate

assign dout0_real = m0_axis_tdata [15:0];
assign dout0_imag = m0_axis_tdata [31:16];
assign dout1_real = m1_axis_tdata [15:0];
assign dout1_imag = m1_axis_tdata [31:16];
assign dout2_real = m2_axis_tdata [15:0];
assign dout2_imag = m2_axis_tdata [31:16];
assign dout3_real = m3_axis_tdata [15:0];
assign dout3_imag = m3_axis_tdata [31:16];

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

axis_pfb_readout_v3
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

    	// S_AXIS for input samples.
		.s_axis_tvalid	(s_axis_tvalid	),
		.s_axis_tdata	(s_axis_tdata 	),

		// M_AXIS for CH0 output.
		.m0_axis_tvalid	(m0_axis_tvalid	),
		.m0_axis_tdata	(m0_axis_tdata 	),

		// M_AXIS for CH1 output.
		.m1_axis_tvalid	(m1_axis_tvalid	),
		.m1_axis_tdata	(m1_axis_tdata 	),

		// M_AXIS for CH2 output.
		.m2_axis_tvalid	(m2_axis_tvalid	),
		.m2_axis_tdata	(m2_axis_tdata 	),

		// M_AXIS for CH3 output.
		.m3_axis_tvalid	(m3_axis_tvalid	),
		.m3_axis_tdata	(m3_axis_tdata 	)
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

	$display("###################");
	$display("### Program DDS ###");
	$display("###################");
	$display("t = %0t", $time);

	// ID0/1/2/3.
	// ID [7:0]: packet
	// ID [15:8]: id
	axi_mst_0_agent.AXI4LITE_WRITE_BURST(0*4, prot, (0 << 8) + 0, resp);
	axi_mst_0_agent.AXI4LITE_WRITE_BURST(1*4, prot, (1 << 8) + 0, resp);
	axi_mst_0_agent.AXI4LITE_WRITE_BURST(2*4, prot, (6 << 8) + 0, resp);
	axi_mst_0_agent.AXI4LITE_WRITE_BURST(3*4, prot, (6 << 8) + 0, resp);
	
	// FREQ0/PHASE0.
	axi_mst_0_agent.AXI4LITE_WRITE_BURST(4*4, prot, 0, resp);
	axi_mst_0_agent.AXI4LITE_WRITE_BURST(5*4, prot, 0, resp);
	
	// FREQ1/PHASE1.
	axi_mst_0_agent.AXI4LITE_WRITE_BURST(6*4, prot, freq(1,10), resp);
	axi_mst_0_agent.AXI4LITE_WRITE_BURST(7*4, prot, 0, resp);

	// FREQ2/PHASE2.
	axi_mst_0_agent.AXI4LITE_WRITE_BURST(8*4, prot, freq(1, 33), resp);
	axi_mst_0_agent.AXI4LITE_WRITE_BURST(9*4, prot, 0, resp);

	// FREQ3/PHASE3.
	axi_mst_0_agent.AXI4LITE_WRITE_BURST(10*4, prot, freq(1, 3), resp);
	axi_mst_0_agent.AXI4LITE_WRITE_BURST(11*4, prot, 0, resp);

	$display("###############################");
	$display("### Start Recording Outputs ###");
	$display("###############################");
	$display("t = %0t", $time);

	tb_data 		<= 1;
	tb_write_out 	<= 1;
	wait (tb_data_done);
	tb_write_out 	<= 0;
		
end

// Input data.
initial begin
	int fd;
	int i;
	bit signed [15:0] vali, valq;
	s_axis_tvalid 	<= 0;

	// Open file with Coefficients.
	fd = $fopen("../../../../../tb/data_iq.txt","r");

	wait(tb_data);
	@(posedge aclk);
	
	i = 0;
	while ($fscanf(fd,"%d,%d", vali, valq) == 2) begin
		//$display("T = %d, i = %d, I = %d, Q = %d", $time, i, vali, valq);		
		din_ii[i] <= {valq,vali};
		i = i + 1;
		if (i == 4) begin
		    i = 0;
			@(posedge aclk);
			s_axis_tvalid <= 1;
		end
	end

	@(posedge aclk);
	s_axis_tvalid <= 0;
	tb_data_done <= 1;

end

// Write output into file.
initial begin
	int fd0, fd1, fd2, fd3;
	int i;
	shortint real_d0, imag_d0;
	shortint real_d1, imag_d1;
	shortint real_d2, imag_d2;
	shortint real_d3, imag_d3;

	// Output file.
	fd0 = $fopen("../../../../../tb/dout_0.csv","w");
	fd1 = $fopen("../../../../../tb/dout_1.csv","w");
	fd2 = $fopen("../../../../../tb/dout_2.csv","w");
	fd3 = $fopen("../../../../../tb/dout_3.csv","w");

	// Data format.
	$fdisplay(fd0, "valid, real, imag");
	$fdisplay(fd1, "valid, real, imag");
	$fdisplay(fd2, "valid, real, imag");
	$fdisplay(fd3, "valid, real, imag");

	wait (tb_write_out);

	while (tb_write_out) begin
		@(posedge aclk);
		real_d0 = m0_axis_tdata[15:0];
		imag_d0 = m0_axis_tdata[31:16];
		real_d1 = m1_axis_tdata[15:0];
		imag_d1 = m1_axis_tdata[31:16];
		real_d2 = m2_axis_tdata[15:0];
		imag_d2 = m2_axis_tdata[31:16];
		real_d3 = m3_axis_tdata[15:0];
		imag_d3 = m3_axis_tdata[31:16];
		$fdisplay(fd0,"%d,%d,%d",m0_axis_tvalid,real_d0,imag_d0);
		$fdisplay(fd1,"%d,%d,%d",m1_axis_tvalid,real_d1,imag_d1);
		$fdisplay(fd2,"%d,%d,%d",m2_axis_tvalid,real_d2,imag_d2);
		$fdisplay(fd3,"%d,%d,%d",m3_axis_tvalid,real_d3,imag_d3);
	end

	$display("Closing file, t = %0t", $time);
	$fclose(fd0);
	$fclose(fd1);
	$fclose(fd2);
	$fclose(fd3);
end

always begin
	s_axi_aclk <= 0;
	#10;
	s_axi_aclk <= 1;
	#10;
end

always begin
	aclk <= 0;
	#1;
	aclk <= 1;
	#1;
end  

function bit [31:0] freq (input real f, fs);
    int ret;
    
	// I use only 16 bits for rounding. Add the remaining later...
	ret = 2**16*f/fs;

	return {ret,16'h0000};
endfunction

function bit [31:0] phase (input real phi);
    int ret;
    
	// I use only 16 bits for rounding. Add the remaining later...
	ret = 2**16*phi/360;

	return {ret,16'h0000};
endfunction

endmodule

