// VIP: axi_mst_0
// DUT: axis_signal_gen_v2
// 	IF: s_axi -> axi_mst_0

import axi_vip_pkg::*;
import axi_mst_0_pkg::*;

module tb();

// DUT generics.
parameter N 	= 10;
parameter N_DDS = 4;

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

// s0_axis interfase.
reg		    			s0_axis_aclk;
reg		    			s0_axis_aresetn;
reg 	[31:0]			s0_axis_tdata;
wire					s0_axis_tready;
reg						s0_axis_tvalid;

reg						aresetn;
reg						aclk;

// Dummy clock for debugging.
reg						aclk4;

// s1_axis interfase.
reg		[159:0]			s1_axis_tdata;
wire					s1_axis_tready;
reg						s1_axis_tvalid;

// m_axis interfase.
wire	[N_DDS*16-1:0]	m_axis_tdata;
reg 					m_axis_tready = 1;
wire					m_axis_tvalid;

// Waveform Fields.
reg		[31:0]			freq_r;
reg		[31:0]			phase_r;
reg		[15:0]			addr_r;
reg		[15:0]			gain_r;
reg		[15:0]			nsamp_r;
reg		[1:0]			outsel_r;
reg						mode_r;
reg						stdysel_r;
reg						phrst_r;

// Assignment of data out for debugging.
wire	[15:0]			dout_ii [0:N_DDS-1];
reg		[15:0]			dout_f;

// AXI VIP master address.
xil_axi_ulong   addr_start_addr	= 32'h40000000; // 0
xil_axi_ulong   addr_we			= 32'h40000004; // 1

xil_axi_prot_t  prot        = 0;
reg[31:0]       data_wr     = 32'h12345678;
reg[31:0]       data;
xil_axi_resp_t  resp;

// Test bench control.
reg	tb_load_mem 		= 0;
reg tb_load_mem_done	= 0;
reg	tb_load_wave 		= 0;
reg	tb_load_wave_done	= 0;
reg	tb_write_out 		= 0;

// Debug.
generate
genvar ii;
for (ii = 0; ii < N_DDS; ii = ii + 1) begin : GEN_debug
    assign dout_ii[ii] = m_axis_tdata[16*ii +: 16];
end
endgenerate
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

axis_signal_gen_v6
    #
    (
		.N		(N		),
		.N_DDS	(N_DDS	)
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

        // AXIS Slave to load data into memory.
		.s0_axis_aclk	(s0_axis_aclk	),
		.s0_axis_aresetn(s0_axis_aresetn),
		.s0_axis_tdata	(s0_axis_tdata 	),
		.s0_axis_tvalid	(s0_axis_tvalid	),
        .s0_axis_tready	(s0_axis_tready	),

		// s1_* and m_* reset/clock.
		.aresetn		(aresetn		),
		.aclk			(aclk	 		),

        // AXIS Slave to queue waveforms.
		.s1_axis_tdata	(s1_axis_tdata 	),
		.s1_axis_tvalid	(s1_axis_tvalid	),
        .s1_axis_tready	(s1_axis_tready	),

		// AXIS Master for output data.
		.m_axis_tready	(m_axis_tready	),
		.m_axis_tvalid	(m_axis_tvalid	),
		.m_axis_tdata	(m_axis_tdata 	)
	);

// VIP Agents
axi_mst_0_mst_t 	axi_mst_0_agent;

assign s1_axis_tdata = {{10{1'b0}},phrst_r,stdysel_r,mode_r,outsel_r,nsamp_r,{16{1'b0}},gain_r,{16{1'b0}},addr_r,phase_r,freq_r};

initial begin
	// Create agents.
	axi_mst_0_agent 	= new("axi_mst_0 VIP Agent",tb.axi_mst_0_i.inst.IF);

	// Set tag for agents.
	axi_mst_0_agent.set_agent_tag	("axi_mst_0 VIP");

	// Start agents.
	axi_mst_0_agent.start_master();

	// Reset sequence.
	s_axi_aresetn 		<= 0;
	s0_axis_aresetn 	<= 0;
	aresetn 			<= 0;
	#500;
	s_axi_aresetn 		<= 1;
	s0_axis_aresetn 	<= 1;
	aresetn 			<= 1;

	#1000;
	
	$display("############################");
	$display("### Load data into Table ###");
	$display("############################");
	$display("t = %0t", $time);

	/*
	ADDR   				= 0
	*/	
		
	// start_addr.
	data_wr = 0;
	axi_mst_0_agent.AXI4LITE_WRITE_BURST(addr_start_addr, prot, data_wr, resp);
	#10;
	
	// we.
	data_wr = 1;
	axi_mst_0_agent.AXI4LITE_WRITE_BURST(addr_we, prot, data_wr, resp);
	#10;	
	
	// Load Table.
	tb_load_mem 	<= 1;
	wait (tb_load_mem_done);
	
	#100;
	
	// we.
	data_wr = 0;
	axi_mst_0_agent.AXI4LITE_WRITE_BURST(addr_we, prot, data_wr, resp);
	#10;	

	#1000;

	$display("#######################");
	$display("### Queue Waveforms ###");
	$display("#######################");
	$display("t = %0t", $time);

	// Queue waveforms and write output while queuing.
	tb_load_wave 	<= 1;
	tb_write_out	<= 1;
	wait (tb_load_wave_done);

	#30000;

	// Stop writing output data.
	tb_write_out 	<= 0;

	#20000;

end

// Load data into memroy.
initial begin
    int fd,vali,valq;
	bit signed [15:0] ii,qq;
    
	s0_axis_tvalid	<= 0;
	s0_axis_tdata	<= 0;
	
	wait (tb_load_mem);

	fd = $fopen("../../../../../tb/gauss.txt","r");

	wait (s0_axis_tready);

	while($fscanf(fd,"%d,%d", valq,vali) == 2) begin
		$display("I,Q: %d, %d", vali,valq);
		ii = vali;
		qq = valq;
		@(posedge s0_axis_aclk);
		s0_axis_tvalid 	<= 1;
		s0_axis_tdata 	<= {qq,ii};
	end

	@(posedge s0_axis_aclk);
	s0_axis_tvalid 	<= 0;
	
	$fclose(fd);
	tb_load_mem_done <= 1;

end

// Load waveforms.
initial begin
	s1_axis_tvalid	<= 0;
	freq_r			<= 0;
	phase_r			<= 0;
	addr_r			<= 0;
	gain_r			<= 0;
	nsamp_r			<= 0;
	outsel_r		<= 0;
	mode_r			<= 0;
	stdysel_r		<= 0;
	phrst_r			<= 0;

	wait (tb_load_wave);
	wait (s1_axis_tready);

	@(posedge aclk);
	$display("t = %0t", $time);
	s1_axis_tvalid	<= 1;
	freq_r			<= freq_calc(100, N_DDS, 4);	// 120 MHz.
	phase_r			<= 0;
	addr_r			<= 22;
	gain_r			<= 12000;
	nsamp_r			<= 80;
	outsel_r		<= 1;	// 0: prod, 1: dds, 2: mem
	mode_r			<= 0;	// 0: nsamp, 1: periodic
	stdysel_r		<= 0;	// 0: last, 1: zero.
	phrst_r			<= 0;

	@(posedge aclk);
	$display("t = %0t", $time);
	s1_axis_tvalid	<= 1;
	freq_r			<= freq_calc(100, N_DDS, 4);	// 120 MHz.
	phase_r			<= 0;
	addr_r			<= 22;
	gain_r			<= 12000;
	nsamp_r			<= 123;
	outsel_r		<= 1;	// 0: prod, 1: dds, 2: mem
	mode_r			<= 0;	// 0: nsamp, 1: periodic
	stdysel_r		<= 0;	// 0: last, 1: zero.
	phrst_r			<= 1;

	@(posedge aclk);
	s1_axis_tvalid	<= 0;

	#5000;

	@(posedge aclk);
	$display("t = %0t", $time);
	s1_axis_tvalid	<= 1;
	freq_r			<= freq_calc(100, N_DDS, 13);
	phase_r			<= 0;
	addr_r			<= 0;
	gain_r			<= 30000;
	nsamp_r			<= 400/N_DDS;
	outsel_r		<= 0;	// 0: prod, 1: dds, 2: mem
	mode_r			<= 0;	// 0: nsamp, 1: periodic
	stdysel_r		<= 1;	// 0: last, 1: zero.
	phrst_r			<= 0;

	//@(posedge aclk);
	//$display("t = %0t", $time);
	//s1_axis_tvalid	<= 1;
	//freq_r			<= freq_calc(100, N_DDS, 33);
	//phase_r			<= 0;
	//addr_r			<= 5;
	//gain_r			<= 30000;
	//nsamp_r			<= 670/N_DDS;
	//outsel_r		<= 1;	// 0: prod, 1: dds, 2: mem
	//mode_r			<= 0;	// 0: nsamp, 1: periodic
	//stdysel_r		<= 1;	// 0: last, 1: zero.

	//@(posedge aclk);
	//$display("t = %0t", $time);
	//s1_axis_tvalid	<= 1;
	//freq_r			<= freq_calc(100, N_DDS, 22);
	//phase_r			<= 7689;
	//addr_r			<= 0;
	//gain_r			<= 30000;
	//nsamp_r			<= 70/N_DDS;
	//outsel_r		<= 2;	// 0: prod, 1: dds, 2: mem
	//mode_r			<= 1;	// 0: nsamp, 1: periodic
	//stdysel_r		<= 1;	// 0: last, 1: zero.

	//@(posedge aclk);
	//s1_axis_tvalid	<= 0;

	//#30000;

	//@(posedge aclk);
	//$display("t = %0t", $time);
	//s1_axis_tvalid	<= 1;
	//freq_r			<= freq_calc(100, N_DDS, 3);
	//phase_r			<= 0;
	//addr_r			<= 5;
	//gain_r			<= 30000;
	//nsamp_r			<= 670/N_DDS;
	//outsel_r		<= 1;	// 0: prod, 1: dds, 2: mem
	//mode_r			<= 0;	// 0: nsamp, 1: periodic
	//stdysel_r		<= 1;	// 0: last, 1: zero.

	@(posedge aclk);
	s1_axis_tvalid	<= 0;
	tb_load_wave_done <= 1;
end

// Write output into file.
initial begin
	int fd;
	int i;
	shortint real_d;

	// Output file.
	fd = $fopen("../../../../../tb/dout.csv","w");

	// Data format.
	$fdisplay(fd, "valid, idx, real");

	wait (tb_write_out);

	while (tb_write_out) begin
		@(posedge aclk);
		for (i=0; i<N_DDS; i = i+1) begin
			real_d = dout_ii[i][15:0];
			$fdisplay(fd, "%d, %d, %d", m_axis_tvalid, i, real_d);
		end
	end

	$display("Closing file, t = %0t", $time);
	$fclose(fd);
end

// Assign output to vector for easy plotting.
initial begin
	dout_f <= 0;

	@(posedge aclk);
	while (1) begin
		for (int i=0; i<N_DDS; i = i+1) begin
			@(posedge aclk4);
			dout_f = dout_ii[i];
		end
	end
end

always begin
	s_axi_aclk <= 0;
	#10;
	s_axi_aclk <= 1;
	#10;
end

always begin
	s0_axis_aclk <= 0;
	#10;
	s0_axis_aclk <= 1;
	#10;
end

always begin
	aclk <= 0;
	aclk4 <= 0;
	#1;
	aclk4 <= 1;
	#1;

	aclk4 <= 0;
	#1;
	aclk4 <= 1;
	#1;

	aclk <= 1;
	aclk4 <= 0;
	#1;
	aclk4 <= 1;
	#1;

	aclk4 <= 0;
	#1;
	aclk4 <= 1;
	#1;
end  

// Function to compute frequency register.
function [31:0] freq_calc;
    input int fclk;
    input int ndds;
    input int f;
    
	// All input frequencies are in MHz.
	real fs,temp;
	fs = fclk*ndds;
	temp = f/fs*2**30;
	freq_calc = {int'(temp),2'b00};
endfunction

endmodule

