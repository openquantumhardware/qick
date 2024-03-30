import axi_vip_pkg::*;
import axi_mst_0_pkg::*;

module tb();

// DUT generics.
parameter N_DDS = 16;

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
wire	[39:0]			s_axis_tdata;
wire					s_axis_tready;
reg						s_axis_tvalid;

// m_axis interfase.
wire	[N_DDS*16-1:0]	m_axis_tdata;
reg 					m_axis_tready = 1;
wire					m_axis_tvalid;

// Waveform fields.
reg		[31:0]			nsamp_r;
reg		[7:0]			mask_r;

// Assignment of data out for debugging.
wire	[15:0]			dout_ii [0:N_DDS-1];

xil_axi_prot_t  prot        = 0;
reg[31:0]       data_wr     = 32'h12345678;
reg[31:0]       data;
xil_axi_resp_t  resp;

// TB control.
reg	tb_load_wave		= 0;
reg tb_load_wave_done	= 0;
reg	tb_write_out 		= 0;

// Debug.
generate
genvar ii;
for (ii = 0; ii < N_DDS; ii = ii + 1) begin : GEN_debug
    assign dout_ii[ii] = m_axis_tdata[16*ii +: 16];
end
endgenerate

// M_AXI.
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

axis_sg_mux4_v3
    #
    (
		.N_DDS(N_DDS)
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

		// s_* and m_* reset/clock.
		.aresetn		(aresetn		),
		.aclk			(aclk	 		),

        // S_AXIS to queue waveforms.
        .s_axis_tready	(s_axis_tready	),
		.s_axis_tvalid	(s_axis_tvalid	),
		.s_axis_tdata	(s_axis_tdata 	),

		// AXIS Master for output data.
		.m_axis_tready	(m_axis_tready	),
		.m_axis_tvalid	(m_axis_tvalid	),
		.m_axis_tdata	(m_axis_tdata 	)
	);

// VIP Agents
axi_mst_0_mst_t 	axi_mst_0_agent;

// Waveform fields.
assign s_axis_tdata = {mask_r,nsamp_r};


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
	
	$display("###########################");
	$display("### Program Frequencies ###");
	$display("###########################");
	$display("t = %0t", $time);

	// PINC0_REG
	data_wr = freq_calc(100, N_DDS, 1);
	axi_mst_0_agent.AXI4LITE_WRITE_BURST(4*0, prot, data_wr, resp);
	#10;

	// PINC1_REG
	data_wr = freq_calc(100, N_DDS, 11);
	axi_mst_0_agent.AXI4LITE_WRITE_BURST(4*1, prot, data_wr, resp);
	#10;

	// PINC2_REG
	data_wr = freq_calc(100, N_DDS, 27);
	axi_mst_0_agent.AXI4LITE_WRITE_BURST(4*2, prot, data_wr, resp);
	#10;

	// PINC3_REG
	data_wr = freq_calc(100, N_DDS, 115);
	axi_mst_0_agent.AXI4LITE_WRITE_BURST(4*3, prot, data_wr, resp);
	#10;

	// GAIN0_REG
	data_wr = 32000;
	axi_mst_0_agent.AXI4LITE_WRITE_BURST(4*4, prot, data_wr, resp);
	#10;

	// GAIN1_REG
	data_wr = 25000;
	axi_mst_0_agent.AXI4LITE_WRITE_BURST(4*5, prot, data_wr, resp);
	#10;

	// GAIN2_REG
	data_wr = 10000;
	axi_mst_0_agent.AXI4LITE_WRITE_BURST(4*6, prot, data_wr, resp);
	#10;

	// GAIN3_REG
	data_wr = 1000;
	axi_mst_0_agent.AXI4LITE_WRITE_BURST(4*7, prot, data_wr, resp);
	#10;
	
	// we.
	data_wr = 1;
	axi_mst_0_agent.AXI4LITE_WRITE_BURST(4*8, prot, data_wr, resp);
	#10;	

	// we.
	data_wr = 0;
	axi_mst_0_agent.AXI4LITE_WRITE_BURST(4*8, prot, data_wr, resp);
	#10;	
	
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

// Load waveforms.
initial begin
	s_axis_tvalid	<= 0;
	nsamp_r			<= 0;
	mask_r			<= 0;

	wait (tb_load_wave);
	wait (s_axis_tready);

	@(posedge aclk);
	$display("t = %0t", $time);
	s_axis_tvalid	<= 1;
	nsamp_r			<= 550;
	mask_r			<= 8'b0000_1111;
	
	@(posedge aclk);
	$display("t = %0t", $time);
	s_axis_tvalid	<= 1;
	nsamp_r			<= 350;
	mask_r			<= 8'b0000_1111;	

	//@(posedge aclk);
	//$display("t = %0t", $time);
	//s_axis_tvalid_i	<= 1;
	//nsamp_r			<= 25;
	//mask_r			<= 8'b0000_0010;

	//@(posedge aclk);
	//$display("t = %0t", $time);
	//s_axis_tvalid_i	<= 1;
	//nsamp_r			<= 35;
	//mask_r			<= 8'b0000_0100;

	//@(posedge aclk);
	//$display("t = %0t", $time);
	//s_axis_tvalid_i	<= 1;
	//nsamp_r			<= 63;
	//mask_r			<= 8'b0000_1000;
	
	@(posedge aclk);
	s_axis_tvalid	<= 0;
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
			real_d = dout_ii[i];
			$fdisplay(fd, "%d, %d, %d", m_axis_tvalid, i, real_d);
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

