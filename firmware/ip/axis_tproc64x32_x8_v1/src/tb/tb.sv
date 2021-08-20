// VIP: axi_mst_0
// VIP: axis_mst_0
// VIP: axis_slv_0
// DUT: axis_tproc6664_x8
// 	IF: s_axi -> axi_mst_0
// 	IF: m0_axis -> axis_slv_0
// 	IF: s0_axis -> axis_mst_0

import axi_vip_pkg::*;
import axi4stream_vip_pkg::*;
import axi_mst_0_pkg::*;
import axis_mst_0_pkg::*;
import axis_slv_0_pkg::*;

module tb();

localparam	PMEM_N		= 16;			// Program Memory Depth.
localparam	DMEM_N 		= 10;			// Data Memory Depth.
localparam	DMEM_OFFSET	= 256;

///////////////////////
// s_axi_aclk domain //
///////////////////////
reg							s_axi_aclk;
reg							s_axi_aresetn;

wire	[31:0]	            s_axi_awaddr;
wire	[2:0]				s_axi_awprot;
wire						s_axi_awvalid;
wire						s_axi_awready;

wire	[31:0]				s_axi_wdata;
wire 	[3:0]				s_axi_wstrb;
wire 						s_axi_wvalid;
wire 						s_axi_wready;

wire	[1:0]				s_axi_bresp;
wire						s_axi_bvalid;
wire						s_axi_bready;

wire	[31:0]	            s_axi_araddr;
wire 	[2:0]				s_axi_arprot;
wire 						s_axi_arvalid;
wire						s_axi_arready;

wire	[31:0]				s_axi_rdata;
wire	[1:0]				s_axi_rresp;
wire 						s_axi_rvalid;
wire						s_axi_rready;

wire	[31:0]				s0_axis_tdata;
wire 						s0_axis_tlast;
wire 						s0_axis_tvalid;
wire 						s0_axis_tready;

wire	[31:0]				m0_axis_tdata;
wire 						m0_axis_tlast;
wire 						m0_axis_tvalid;
wire 						m0_axis_tready;

/////////////////
// aclk domain //
/////////////////
reg					aclk;
reg					aresetn;

reg					start;

wire [PMEM_N-1:0]	pmem_addr;
wire [63:0]			pmem_do;

reg [63:0]			s1_axis_tdata;
reg 				s1_axis_tvalid;
wire 				s1_axis_tready;

reg [63:0]			s2_axis_tdata;
reg 				s2_axis_tvalid;
wire 				s2_axis_tready;

reg [63:0]			s3_axis_tdata;
reg 				s3_axis_tvalid;
wire 				s3_axis_tready;

reg [63:0]			s4_axis_tdata;
reg 				s4_axis_tvalid;
wire 				s4_axis_tready;

wire [159:0]		m1_axis_tdata;
wire				m1_axis_tvalid;
reg					m1_axis_tready;

wire [159:0]		m2_axis_tdata;
wire				m2_axis_tvalid;
reg					m2_axis_tready;

wire [159:0]		m3_axis_tdata;
wire				m3_axis_tvalid;
reg					m3_axis_tready;

wire [159:0]		m4_axis_tdata;
wire				m4_axis_tvalid;
reg					m4_axis_tready;

wire [159:0]		m5_axis_tdata;
wire				m5_axis_tvalid;
reg					m5_axis_tready;

wire [159:0]		m6_axis_tdata;
wire				m6_axis_tvalid;
reg					m6_axis_tready;

wire [159:0]		m7_axis_tdata;
wire				m7_axis_tvalid;
reg					m7_axis_tready;

wire [159:0]		m8_axis_tdata;
wire				m8_axis_tvalid;
wire				m8_axis_tready;

xil_axi_prot_t  prot        = 0;
reg[31:0]       data_wr     = 32'h12345678;
reg[31:0]       data;
xil_axi_resp_t  resp;

// Ready generator for axis slave.
axi4stream_ready_gen ready_gen_0;
// Program memory.
bram 
    #(
        // Memory address size.
        .N	(PMEM_N	),
        // Data width.
        .B	(64		)
    )
    pmem_i ( 
        .clk    (aclk						    	),
        .ena    (1'b1								),
        .wea    (1'b0								),
        .addra  ({3'b000,pmem_addr[PMEM_N-1:3]}	),
        .dia    ({64{1'b0}}							),
        .doa    (pmem_do							)
    );

// AXIS master.
axis_mst_0 axis_mst_0_i
	(
		.aclk			(s_axi_aclk		),
		.aresetn		(s_axi_aresetn	),
		.m_axis_tdata	(s0_axis_tdata	),
		.m_axis_tlast	(s0_axis_tlast	),
		.m_axis_tready	(s0_axis_tready	),
		.m_axis_tstrb	(				),
		.m_axis_tvalid	(s0_axis_tvalid	)
	);

// AXIS slave.
axis_slv_0 axis_slv_0_i
	(
		.aclk			(s_axi_aclk		),
		.aresetn		(s_axi_aresetn	),
		.s_axis_tdata	(m0_axis_tdata	),
		.s_axis_tlast	(m0_axis_tlast	),
		.s_axis_tready	(m0_axis_tready	),
		.s_axis_tstrb	(				),
		.s_axis_tvalid	(m0_axis_tvalid	)
	);

// AXI master.
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
axis_tproc64x32_x8
	DUT 
	(
		///////////////////////
		// s_axi_aclk domain //
		///////////////////////
		.s_axi_aclk		(s_axi_aclk		),
		.s_axi_aresetn	(s_axi_aresetn	),
		
		// AXI Slave I/F for configuration.
		.s_axi_awaddr	(s_axi_awaddr	),
		.s_axi_awprot	(s_axi_awprot	),
		.s_axi_awvalid	(s_axi_awvalid	),
		.s_axi_awready	(s_axi_awready	),

		.s_axi_wdata	(s_axi_wdata 	),
		.s_axi_wstrb	(s_axi_wstrb 	),
		.s_axi_wvalid	(s_axi_wvalid	),
		.s_axi_wready	(s_axi_wready	),

		.s_axi_bresp	(s_axi_bresp 	),
		.s_axi_bvalid	(s_axi_bvalid	),
		.s_axi_bready	(s_axi_bready	),

		.s_axi_araddr	(s_axi_araddr 	),
		.s_axi_arprot	(s_axi_arprot 	),
		.s_axi_arvalid	(s_axi_arvalid	),
		.s_axi_arready	(s_axi_arready	),

		.s_axi_rdata	(s_axi_rdata 	),
		.s_axi_rresp	(s_axi_rresp 	),
		.s_axi_rvalid	(s_axi_rvalid	),
		.s_axi_rready	(s_axi_rready	),

		// Slave AXIS for writing into Data Memory.
		.s0_axis_tdata	(s0_axis_tdata 	),
		.s0_axis_tlast	(s0_axis_tlast 	),
		.s0_axis_tvalid	(s0_axis_tvalid	),
		.s0_axis_tready	(s0_axis_tready	),

		// Master AXIS 0 to read from Data Memory.
		.m0_axis_tdata	(m0_axis_tdata	),
		.m0_axis_tlast	(m0_axis_tlast	),
		.m0_axis_tvalid	(m0_axis_tvalid	),
		.m0_axis_tready	(m0_axis_tready	),

		/////////////////
		// aclk domain //
		/////////////////
		.aclk			(aclk			),
		.aresetn		(aresetn		),

		// Start/stop.
		.start			(start			),

		// Program Memory Interface.
		.pmem_addr		(pmem_addr		),
		.pmem_do		(pmem_do		),

		// Slave AXIS 0: "read" on tProcessor.
		.s1_axis_tdata	(s1_axis_tdata 	),
		.s1_axis_tvalid	(s1_axis_tvalid	),
		.s1_axis_tready	(s1_axis_tready	),

		// Slave AXIS 1: "read" on tProcessor.
		.s2_axis_tdata	(s2_axis_tdata 	),
		.s2_axis_tvalid	(s2_axis_tvalid	),
		.s2_axis_tready	(s2_axis_tready	),

		// Slave AXIS 2: "read" on tProcessor.
		.s3_axis_tdata	(s3_axis_tdata 	),
		.s3_axis_tvalid	(s3_axis_tvalid	),
		.s3_axis_tready	(s3_axis_tready	),

		// Slave AXIS 3: "read" on tProcessor.
		.s4_axis_tdata	(s4_axis_tdata 	),
		.s4_axis_tvalid	(s4_axis_tvalid	),
		.s4_axis_tready	(s4_axis_tready	),

		// Master AXIS 1 for Channel 0.
		.m1_axis_tdata	(m1_axis_tdata 	),
		.m1_axis_tvalid	(m1_axis_tvalid	),
		.m1_axis_tready	(m1_axis_tready	),

		// Master AXIS 2 for Channel 1.
		.m2_axis_tdata	(m2_axis_tdata	),
		.m2_axis_tvalid	(m2_axis_tvalid	),
		.m2_axis_tready	(m2_axis_tready	),

		// Master AXIS 3 for Channel 2.
		.m3_axis_tdata	(m3_axis_tdata 	),
		.m3_axis_tvalid	(m3_axis_tvalid	),
		.m3_axis_tready	(m3_axis_tready	),

		// Master AXIS 4 for Channel 3.
		.m4_axis_tdata	(m4_axis_tdata 	),
		.m4_axis_tvalid	(m4_axis_tvalid	),
		.m4_axis_tready	(m4_axis_tready	),

		// Master AXIS 5 for Channel 4.
		.m5_axis_tdata	(m5_axis_tdata	),
		.m5_axis_tvalid	(m5_axis_tvalid	),
		.m5_axis_tready	(m5_axis_tready	),

		// Master AXIS 6 for Channel 5.
		.m6_axis_tdata	(m6_axis_tdata 	),
		.m6_axis_tvalid	(m6_axis_tvalid	),
		.m6_axis_tready	(m6_axis_tready	),

		// Master AXIS 7 for Channel 6.
		.m7_axis_tdata	(m7_axis_tdata 	),
		.m7_axis_tvalid	(m7_axis_tvalid	),
		.m7_axis_tready	(m7_axis_tready	),

		// Master AXIS 8 for Channel 7.
		.m8_axis_tdata	(m8_axis_tdata 	),
		.m8_axis_tvalid	(m8_axis_tvalid	),
		.m8_axis_tready	(m8_axis_tready	)
);

// Simple Signal Generator Simulator.
gen_sim
	gen_sim_i
	(
		.clk			(aclk			),
		.rstn			(aresetn		),
		.s_axis_tdata	(m8_axis_tdata	),
		.s_axis_tvalid	(m8_axis_tvalid	),
		.s_axis_tready	(m8_axis_tready	)
	);


// VIP Agents
axi_mst_0_mst_t 	axi_mst_0_agent;
axis_mst_0_mst_t 	axis_mst_0_agent;
axis_slv_0_slv_t 	axis_slv_0_agent;

initial begin
	// Create agents.
	axi_mst_0_agent 	= new("axi_mst_0 VIP Agent",tb.axi_mst_0_i.inst.IF);
	axis_mst_0_agent 	= new("axis_mst_0 VIP Agent",tb.axis_mst_0_i.inst.IF);
	axis_slv_0_agent 	= new("axis_slv_0 VIP Agent",tb.axis_slv_0_i.inst.IF);

	// Set tag for agents.
	axi_mst_0_agent.set_agent_tag	("axi_mst_0 VIP");
	axis_mst_0_agent.set_agent_tag	("axis_mst_0 VIP");
	axis_slv_0_agent.set_agent_tag	("axis_slv_0 VIP");

	// Drive everything to 0 to avoid assertion from axi_protocol_checker.
	axis_mst_0_agent.vif_proxy.set_dummy_drive_type(XIL_AXI4STREAM_VIF_DRIVE_NONE);
	axis_slv_0_agent.vif_proxy.set_dummy_drive_type(XIL_AXI4STREAM_VIF_DRIVE_NONE);

	// Ready generator.
	ready_gen_0 = axis_slv_0_agent.driver.create_ready("ready gen 0");
	ready_gen_0.set_ready_policy(XIL_AXI4STREAM_READY_GEN_EVENTS);
	ready_gen_0.set_low_time(5);
	ready_gen_0.set_event_count(6);

	// Start agents.
	axi_mst_0_agent.start_master();
	axis_mst_0_agent.start_master();
	axis_slv_0_agent.start_slave();

	// Reset sequence.
	s_axi_aresetn	<= 0;
	aresetn			<= 0;
	start 			<= 0;
	s1_axis_tdata 	<= 0;
	s1_axis_tvalid 	<= 0;
	s2_axis_tdata 	<= 0;
	s2_axis_tvalid 	<= 0;
	s3_axis_tdata 	<= 0;
	s3_axis_tvalid 	<= 0;
	s4_axis_tdata 	<= 0;
	s4_axis_tvalid 	<= 0;
	m1_axis_tready 	<= 1;
	m2_axis_tready 	<= 1;
	m3_axis_tready 	<= 1;
	m4_axis_tready 	<= 1;
	m5_axis_tready 	<= 1;
	m6_axis_tready 	<= 1;
	m7_axis_tready 	<= 1;
	#1000;
	s_axi_aresetn	<= 1;
	aresetn			<= 1;
	
	// Load program memory.
	$readmemb("../../../../../soft/prog.bin", pmem_i.RAM);

	// Change ready policy for AXIS slave.
	axis_slv_0_agent.driver.send_tready(ready_gen_0);

	#300;

	// Write input ports.
	@(posedge aclk)
	s1_axis_tdata 	<= 64'h12345678_87654321;
	s1_axis_tvalid	<= 1;
	s2_axis_tdata 	<= 64'h55555555_aaaaaaaa;
	s2_axis_tvalid	<= 1;
	s3_axis_tdata 	<= 64'habcdef00_01234567;
	s3_axis_tvalid	<= 1;
	s4_axis_tdata 	<= 64'h01012323_ababcdcd;
	s4_axis_tvalid	<= 1;

	@(posedge aclk)
	s1_axis_tvalid	<= 0;
	s2_axis_tvalid	<= 0;
	s3_axis_tvalid	<= 0;
	s4_axis_tvalid	<= 0;


	// Register Map:
	//
	// 0 : START_SRC_REG
	// 1 : START_REG
	// 2 : MEM_MODE_REG
	// 3 : MEM_START_REG
	// 4 : MEM_ADDR_REG
	// 5 : MEM_LEN_REG
		
	// START_SRC_REG
	// * 0 : Internal Start.
	// * 1 : External Start.
	data_wr = 0;
	axi_mst_0_agent.AXI4LITE_WRITE_BURST(4*0, prot, data_wr, resp);
	#10;

	// START_REG
	data_wr = 1;
	axi_mst_0_agent.AXI4LITE_WRITE_BURST(4*1, prot, data_wr, resp);
	#10;

	#50000;

	//// Read back flag to signal start of next step.
	//$display("#####################");
	//$display("### Wait for flag ###");
	//$display("#####################");
	//$display("t = %0t", $time);

	//// Flag: tProcessor data memory @100.
	//// Memory is accessed using the upper part of the memory map.
	//// Addresses are byte-based.
	//// address = DMEM_OFFSET + 4*100
	//while (1) begin
	//	axi_mst_0_agent.AXI4LITE_READ_BURST(DMEM_OFFSET + 4*100, prot, data, resp);
	//	#200;
	//	
	//	if (data == 32'h0abcd) 
	//		break;
	//end

	//// Flag: tProcessor data memory @101.
	//// Memory is accessed using the upper half of the memory map.
	//// address = DMEM_OFFSET + 4*101
	//data_wr = 32'h01234;
	//axi_mst_0_agent.AXI4LITE_WRITE_BURST(DMEM_OFFSET + 4*101, prot, data_wr, resp);
	//#200;
	//	

	//// Single write.
	//$display("##############################");
	//$display("### Single read/write mode ###");
	//$display("##############################");
	//$display("t = %0t", $time);
	//
	//// Write memory (upper address map).
	//for (int i=0;i<55;i++) begin
	//	data_wr = i;
	//	axi_mst_0_agent.AXI4LITE_WRITE_BURST(DMEM_OFFSET + 4*i, prot, data_wr, resp);
	//	#10;
	//end 

	//#500;

	//// Read back flag to signal start of next step.
	//$display("#####################");
	//$display("### Wait for flag ###");
	//$display("#####################");
	//$display("t = %0t", $time);

	//// Flag: tProcessor data memory @100.
	//// Memory is accessed using the upper part of the memory map.
	//// Addresses are byte-based.
	//// address = DMEM_OFFSET + 4*100
	//while (1) begin
	//	axi_mst_0_agent.AXI4LITE_READ_BURST(DMEM_OFFSET + 4*100, prot, data, resp);
	//	#200;
	//	
	//	if (data == 32'h0abcd) 
	//		break;
	//end

	//// Flag: tProcessor data memory @101.
	//// Memory is accessed using the upper half of the memory map.
	//// address = DMEM_OFFSET + 4*101
	//data_wr = 32'h01234;
	//axi_mst_0_agent.AXI4LITE_WRITE_BURST(DMEM_OFFSET + 4*101, prot, data_wr, resp);
	//#200;

	//// Read back flag to signal end of transfer.
	//$display("#####################################");
	//$display("### Wait for end-of-transfer flag ###");
	//$display("#####################################");
	//$display("t = %0t", $time);

	//// Flag: tProcessor data memory @200.
	//// Memory is accessed using the upper half of the memory map.
	//// address = 200 + 2^DMEM_N
	//while (1) begin
	//	axi_mst_0_agent.AXI4LITE_READ_BURST(2**DMEM_N + 4*200, prot, data, resp);
	//	#200;
	//	
	//	if (data == 16'h5a5a) 
	//		break;
	//end

	//// AXIS read (from memory to m0_axis).
	//$display("##########################################");
	//$display("### AXIS read (from memory to m0_axis) ###");
	//$display("##########################################");
	//$display("t = %0t", $time);

	///*
	//	MEM_MODE_REG	= 0;
	//	MEM_START_REG	= 1;
	//	MEM_ADDR_REG	= 0;
	//	MEM_LEN_REG		= 100;
	//*/

	//// MEM_MODE_REG
	//data_wr = 0;
	//axi_mst_0_agent.AXI4LITE_WRITE_BURST(4*2, prot, data_wr, resp);
	//#10;

	//// MEM_ADDR_REG
	//data_wr = 0;
	//axi_mst_0_agent.AXI4LITE_WRITE_BURST(4*4, prot, data_wr, resp);
	//#10;

	//// MEM_LEN_REG
	//data_wr = 100;
	//axi_mst_0_agent.AXI4LITE_WRITE_BURST(4*5, prot, data_wr, resp);
	//#10;

	//// MEM_START_REG
	//data_wr = 1;
	//axi_mst_0_agent.AXI4LITE_WRITE_BURST(4*3, prot, data_wr, resp);
	//#10;

	//// Wait until transaction is done.
	//while (1) begin
	//	@(posedge aclk);
	//	if (m0_axis_tlast == 1'b1 && m0_axis_tvalid == 1'b1 && m0_axis_tready == 1'b1)
	//		break;
	//end

	//// MEM_START_REG
	//data_wr = 0;
	//axi_mst_0_agent.AXI4LITE_WRITE_BURST(4*3, prot, data_wr, resp);
	//#10;

	//// AXIS write (from s0_axis to memory).
	//$display("###########################################");
	//$display("### AXIS write (from s0_axis to memory) ###");
	//$display("###########################################");
	//$display("t = %0t", $time);

	///*
	//	MEM_MODE_REG	= 1;
	//	MEM_START_REG	= 1;
	//	MEM_ADDR_REG	= 50;
	//*/

	//// MEM_MODE_REG
	//data_wr = 1;
	//axi_mst_0_agent.AXI4LITE_WRITE_BURST(4*2, prot, data_wr, resp);
	//#10;

	//// MEM_ADDR_REG
	//data_wr = 50;
	//axi_mst_0_agent.AXI4LITE_WRITE_BURST(4*4, prot, data_wr, resp);
	//#10;

	//// MEM_START_REG
	//data_wr = 1;
	//axi_mst_0_agent.AXI4LITE_WRITE_BURST(4*3, prot, data_wr, resp);
	//#10;

    //// Send data.
	//fork
    //	gen_0(44,0);   
	//join

	//// MEM_START_REG
	//data_wr = 0;
	//axi_mst_0_agent.AXI4LITE_WRITE_BURST(4*3, prot, data_wr, resp);
	//#10;

	//// Flag to signal data has been transferred.
	//data_wr = 32'h0000cdef;
	//axi_mst_0_agent.AXI4LITE_WRITE_BURST(2**DMEM_N + 4*200, prot, data_wr, resp);
	//#10;

	//// Read back flag to signal end of memory operation.
	//$display("######################################");
	//$display("### Wait for end-of-operation flag ###");
	//$display("######################################");
	//$display("t = %0t", $time);

	//// Flag: tProcessor data memory @200.
	//// Memory is accessed using the upper half of the memory map.
	//// address = 200 + 2^DMEM_N
	//while (1) begin
	//	axi_mst_0_agent.AXI4LITE_READ_BURST(2**DMEM_N + 4*200, prot, data, resp);
	//	#200;
	//	
	//	if (data == 16'h5a5a) 
	//		break;
	//end

	//// AXIS read (from memory to m0_axis).
	//$display("##########################################");
	//$display("### AXIS read (from memory to m0_axis) ###");
	//$display("##########################################");
	//$display("t = %0t", $time);

	///*
	//	MEM_MODE_REG	= 0;
	//	MEM_START_REG	= 1;
	//	MEM_ADDR_REG	= 50;
	//	MEM_LEN_REG		= 44;
	//*/

	//// MEM_MODE_REG
	//data_wr = 0;
	//axi_mst_0_agent.AXI4LITE_WRITE_BURST(4*2, prot, data_wr, resp);
	//#10;

	//// MEM_ADDR_REG
	//data_wr = 50;
	//axi_mst_0_agent.AXI4LITE_WRITE_BURST(4*4, prot, data_wr, resp);
	//#10;

	//// MEM_LEN_REG
	//data_wr = 44;
	//axi_mst_0_agent.AXI4LITE_WRITE_BURST(4*5, prot, data_wr, resp);
	//#10;

	//// MEM_START_REG
	//data_wr = 1;
	//axi_mst_0_agent.AXI4LITE_WRITE_BURST(4*3, prot, data_wr, resp);
	//#10;

	//// Wait until transaction is done.
	//while (1) begin
	//	@(posedge aclk);
	//	if (m0_axis_tlast == 1'b1 && m0_axis_tvalid == 1'b1 && m0_axis_tready == 1'b1)
	//		break;
	//end

	//// MEM_START_REG
	//data_wr = 0;
	//axi_mst_0_agent.AXI4LITE_WRITE_BURST(4*3, prot, data_wr, resp);
	//#10;

	#1000;

end

always
begin
	s_axi_aclk <= 0;
	#5;
	s_axi_aclk <= 1;
	#5;
end

always
begin
	aclk <= 0;
	#1;
	aclk <= 1;
	#1;
end

task gen_0(input int cnt, input int delay);        
    // Create transaction.
    axi4stream_transaction wr_transaction;
    wr_transaction = axis_mst_0_agent.driver.create_transaction("Master 0 VIP write transaction");
    
    // Set transaction parameters.
    wr_transaction.set_xfer_alignment(XIL_AXI4STREAM_XFER_RANDOM);
    
    // Send transactions.
    for (int i=0; i < cnt-1; i++)
    begin
        WR_TRANSACTION_FAIL: assert(wr_transaction.randomize());
		wr_transaction.set_last(0);
        wr_transaction.set_delay(delay);
        axis_mst_0_agent.driver.send(wr_transaction);
    end

	// Last.
    WR_TRANSACTION_FAIL: assert(wr_transaction.randomize());
	wr_transaction.set_last(1);
    wr_transaction.set_delay(delay);
    axis_mst_0_agent.driver.send(wr_transaction);

endtask  

endmodule

