module axis_tproc64x32_x8
(
	///////////////////////
	// s_axi_aclk domain //
	///////////////////////
	s_axi_aclk		,
	s_axi_aresetn	,

	// AXI Slave I/F for configuration.
	s_axi_awaddr	,
	s_axi_awprot	,
	s_axi_awvalid	,
	s_axi_awready	,

	s_axi_wdata		,
	s_axi_wstrb		,
	s_axi_wvalid	,
	s_axi_wready	,

	s_axi_bresp		,
	s_axi_bvalid	,
	s_axi_bready	,

	s_axi_araddr	,
	s_axi_arprot	,
	s_axi_arvalid	,
	s_axi_arready	,

	s_axi_rdata		,
	s_axi_rresp		,
	s_axi_rvalid	,
	s_axi_rready	,

	// Slave AXIS for writing into Data Memory.
	s0_axis_aclk	,	// For IF only, not connected.
	s0_axis_aresetn	,	// For IF only, not connected.
	s0_axis_tdata	,
	s0_axis_tlast	,
	s0_axis_tvalid	,
	s0_axis_tready	,

	// Master AXIS 0 to read from Data Memory.
	m0_axis_aclk	,	// For IF only, not connected.
	m0_axis_aresetn	,	// For IF only, not connected.
	m0_axis_tdata	,
	m0_axis_tlast	,
	m0_axis_tvalid	,
	m0_axis_tready	,

	/////////////////
	// aclk domain //
	/////////////////
	aclk			,
	aresetn			,

	// Start/stop.
	start			,

	// Program Memory Interface.
	pmem_addr		,
	pmem_do			,

	// Slave AXIS 0: "read" on tProcessor.
	s1_axis_tdata	,
	s1_axis_tvalid	,
	s1_axis_tready	,

	// Slave AXIS 1: "read" on tProcessor.
	s2_axis_tdata	,
	s2_axis_tvalid	,
	s2_axis_tready	,

	// Slave AXIS 2: "read" on tProcessor.
	s3_axis_tdata	,
	s3_axis_tvalid	,
	s3_axis_tready	,

	// Slave AXIS 3: "read" on tProcessor.
	s4_axis_tdata	,
	s4_axis_tvalid	,
	s4_axis_tready	,

	// Master AXIS 1 for Channel 0.
	m1_axis_tdata	,
	m1_axis_tvalid	,
	m1_axis_tready	,

	// Master AXIS 2 for Channel 1.
	m2_axis_tdata	,
	m2_axis_tvalid	,
	m2_axis_tready	,

	// Master AXIS 3 for Channel 2.
	m3_axis_tdata	,
	m3_axis_tvalid	,
	m3_axis_tready	,

	// Master AXIS 4 for Channel 3.
	m4_axis_tdata	,
	m4_axis_tvalid	,
	m4_axis_tready	,

	// Master AXIS 5 for Channel 4.
	m5_axis_tdata	,
	m5_axis_tvalid	,
	m5_axis_tready	,

	// Master AXIS 6 for Channel 5.
	m6_axis_tdata	,
	m6_axis_tvalid	,
	m6_axis_tready	,

	// Master AXIS 7 for Channel 6.
	m7_axis_tdata	,
	m7_axis_tvalid	,
	m7_axis_tready	,

	// Master AXIS 8 for Channel 7.
	m8_axis_tdata	,
	m8_axis_tvalid	,
	m8_axis_tready

);

// Parameters.
parameter	PMEM_N		= 16;			// Program Memory Depth.
parameter	DMEM_N 		= 10;			// Data Memory Depth.

// Ports.
input	s_axi_aclk;
input	s_axi_aresetn;
input	s0_axis_aclk;
input	s0_axis_aresetn;
input	m0_axis_aclk;
input	m0_axis_aresetn;

input	[31:0]			s_axi_awaddr;
input	[2:0]			s_axi_awprot;
input					s_axi_awvalid;
output					s_axi_awready;

input	[31:0]			s_axi_wdata;
input 	[3:0]			s_axi_wstrb;
input 					s_axi_wvalid;
output 					s_axi_wready;

output	[1:0]			s_axi_bresp;
output					s_axi_bvalid;
input					s_axi_bready;

input	[31:0]			s_axi_araddr;
input 	[2:0]			s_axi_arprot;
input 					s_axi_arvalid;
output					s_axi_arready;

output	[31:0]			s_axi_rdata;
output	[1:0]			s_axi_rresp;
output 					s_axi_rvalid;
input					s_axi_rready;

input	[31:0]			s0_axis_tdata;
input 					s0_axis_tlast;
input 					s0_axis_tvalid;
output 					s0_axis_tready;

output	[31:0]			m0_axis_tdata;
output 					m0_axis_tlast;
output 					m0_axis_tvalid;
input 					m0_axis_tready;

input					aclk;
input					aresetn;

input					start;

output	[PMEM_N-1:0]	pmem_addr;
input	[63:0]			pmem_do;

input	[63:0]			s1_axis_tdata;
input					s1_axis_tvalid;
output					s1_axis_tready;

input	[63:0]			s2_axis_tdata;
input					s2_axis_tvalid;
output					s2_axis_tready;

input	[63:0]			s3_axis_tdata;
input					s3_axis_tvalid;
output					s3_axis_tready;

input	[63:0]			s4_axis_tdata;
input					s4_axis_tvalid;
output					s4_axis_tready;

output	[159:0]			m1_axis_tdata;
output					m1_axis_tvalid;
input					m1_axis_tready;

output	[159:0]			m2_axis_tdata;
output					m2_axis_tvalid;
input					m2_axis_tready;

output	[159:0]			m3_axis_tdata;
output					m3_axis_tvalid;
input					m3_axis_tready;

output	[159:0]			m4_axis_tdata;
output					m4_axis_tvalid;
input					m4_axis_tready;

output	[159:0]			m5_axis_tdata;
output					m5_axis_tvalid;
input					m5_axis_tready;

output	[159:0]			m6_axis_tdata;
output					m6_axis_tvalid;
input					m6_axis_tready;

output	[159:0]			m7_axis_tdata;
output					m7_axis_tvalid;
input					m7_axis_tready;

output	[159:0]			m8_axis_tdata;
output					m8_axis_tvalid;
input					m8_axis_tready;

// Internal connections.
// Program memory address.
wire	[PMEM_N-1:0]		pmem_addr_int;

// axi_slv_custom -> data_mem
wire 						busy_int;
wire 						oper_int;
wire	[DMEM_N-1:0]		addr_int;
wire	[31:0]				dwrite_int;
wire	[31:0]				dread_int;
wire						exec_int;
wire						exec_ack_int;

// data_mem -> dmem (port a).
wire						dmem_wea;
wire	[DMEM_N-1:0]		dmem_addra;
wire	[31:0]				dmem_dia;
wire	[31:0]				dmem_doa;

// tProc -> dmem (port b).
wire						dmem_web;
wire	[DMEM_N-1:0]		dmem_addrb;
wire	[31:0]				dmem_dib;
wire	[31:0]				dmem_dob;

// Registers.
wire 						START_SRC_REG;
wire 						START_REG;
wire						MEM_MODE_REG;
wire						MEM_START_REG;
wire	[DMEM_N-1:0]		MEM_ADDR_REG;
wire	[DMEM_N-1:0]		MEM_LEN_REG;

// AXI Slave.
axi_slv_custom
	axi_slv_i
	(
		// Reset and clock.
		.aclk_i			(s_axi_aclk	 	),
		.aresetn_i		(s_axi_aresetn	),

		// Write Address Channel.
		.awaddr_i		(s_axi_awaddr 	),
		.awprot_i		(s_axi_awprot 	),
		.awvalid_i		(s_axi_awvalid	),
		.awready_o		(s_axi_awready	),
		
		// Write Data Channel.
		.wdata_i		(s_axi_wdata	),
		.wstrb_i		(s_axi_wstrb	),
		.wvalid_i		(s_axi_wvalid	),
		.wready_o		(s_axi_wready	),
		
		// Write Response Channel.
		.bresp_o		(s_axi_bresp	),
		.bvalid_o		(s_axi_bvalid	),
		.bready_i		(s_axi_bready	),
		
		// Read Address Channel.
		.araddr_i		(s_axi_araddr 	),
		.arprot_i		(s_axi_arprot 	),
		.arvalid_i		(s_axi_arvalid	),
		.arready_o		(s_axi_arready	),
		
		// Read Data Channel.
		.rdata_o		(s_axi_rdata	),
		.rresp_o		(s_axi_rresp	),
		.rvalid_o		(s_axi_rvalid	),
		.rready_i		(s_axi_rready	),

		// Single Access Handshake.
		.busy_i			(busy_int		),
		.oper_o			(oper_int		),
		.addr_o			(addr_int		),
		.dwrite_o		(dwrite_int		),
		.dread_i		(dread_int		),
		.exec_o			(exec_int		),
		.exec_ack_i		(exec_ack_int	),
		
		// Registers.
		.START_SRC_REG 	(START_SRC_REG 	),
		.START_REG 		(START_REG 		),
		.MEM_MODE_REG	(MEM_MODE_REG	),
		.MEM_START_REG	(MEM_START_REG	),
		.MEM_ADDR_REG	(MEM_ADDR_REG	),
		.MEM_LEN_REG	(MEM_LEN_REG	)
);

// Data Memory arbiter.
data_mem
	#(
		.N	(DMEM_N	),
		.B	(32		)
	)
	data_mem_i
	(
		// Reset and clock.
		.aclk_i				(s_axi_aclk		),
		.aresetn_i			(s_axi_aresetn	),

		// Single Access Handshake.
		.busy_o				(busy_int		),
		.oper_i				(oper_int		),
		.addr_i				(addr_int		),
		.din_i				(dwrite_int		),
		.dout_o				(dread_int		),
		.exec_i				(exec_int		),
		.exec_ack_o			(exec_ack_int	),

		// Memory interface.
		.mem_we_o			(dmem_wea		),
		.mem_di_o			(dmem_dia		),
		.mem_do_i			(dmem_doa		),
		.mem_addr_o			(dmem_addra		),

		// AXIS Slave for receiving data.
		.s_axis_tdata_i		(s0_axis_tdata 	),
		.s_axis_tlast_i		(s0_axis_tlast 	),
		.s_axis_tvalid_i	(s0_axis_tvalid	),
		.s_axis_tready_o	(s0_axis_tready	),

		// AXIS Master for sending data.
		.m_axis_tdata_o		(m0_axis_tdata 	),
		.m_axis_tlast_o		(m0_axis_tlast 	),
		.m_axis_tvalid_o	(m0_axis_tvalid	),
		.m_axis_tready_i	(m0_axis_tready	),

		// Registers.
		.MODE_REG			(MEM_MODE_REG	),
		.START_REG			(MEM_START_REG	),
		.ADDR_REG			(MEM_ADDR_REG	),
		.LEN_REG			(MEM_LEN_REG	)
);

// Data memory.
bram_dp
    #(
        // Memory address size.
        .N	(DMEM_N	),
        // Data width.
        .B	(32		)
    )
    dmem_i
	( 
        .clka    (s_axi_aclk	),
        .clkb    (aclk			),
        .ena     (1'b1			),
        .enb     (1'b1			),
        .wea     (dmem_wea		),
        .web     (dmem_web		),
        .addra   (dmem_addra	),
        .addrb   (dmem_addrb	),
        .dia     (dmem_dia		),
        .dib     (dmem_dib		),
        .doa     (dmem_doa		),
        .dob     (dmem_dob		)
    );

// tProcessor: 64-bit, 32-bit registers, 8 channels.
tproc64x32_x8
	#(
		// Program memory depth.
		.N	(PMEM_N	),
		
		// Data memory depth.
		.M	(DMEM_N	)
	)
	tproc_i
	( 
		// Clock and reset.
		.clk   			(aclk			),
		.rstn			(aresetn		),

		// Start/stop.
		.start			(start			),

		// Program Memory Interface.
		.pmem_addr		(pmem_addr_int	),
		.pmem_do		(pmem_do		),

		// Data Memory Interface.
		.dmem_we		(dmem_web		),
		.dmem_addr		(dmem_addrb		),
		.dmem_di		(dmem_dib		),
		.dmem_do		(dmem_dob		),

		// Slave AXIS 0 for Input data.
		.s0_axis_tdata	(s1_axis_tdata 	),
		.s0_axis_tvalid	(s1_axis_tvalid	),
		.s0_axis_tready	(s1_axis_tready	),

		// Slave AXIS 1 for Input data.
		.s1_axis_tdata	(s2_axis_tdata 	),
		.s1_axis_tvalid	(s2_axis_tvalid	),
		.s1_axis_tready	(s2_axis_tready	),

		// Slave AXIS 2 for Input data.
		.s2_axis_tdata	(s3_axis_tdata 	),
		.s2_axis_tvalid	(s3_axis_tvalid	),
		.s2_axis_tready	(s3_axis_tready	),

		// Slave AXIS 3 for Input data.
		.s3_axis_tdata	(s4_axis_tdata 	),
		.s3_axis_tvalid	(s4_axis_tvalid	),
		.s3_axis_tready	(s4_axis_tready	),

		// Master AXIS 0 for Output data.
		.m0_axis_tdata	(m1_axis_tdata 	),
		.m0_axis_tvalid	(m1_axis_tvalid	),
		.m0_axis_tready	(m1_axis_tready	),

		// Master AXIS 1 for Output data.
		.m1_axis_tdata	(m2_axis_tdata 	),
		.m1_axis_tvalid	(m2_axis_tvalid	),
		.m1_axis_tready	(m2_axis_tready	),

		// Master AXIS 2 for Output data.
		.m2_axis_tdata	(m3_axis_tdata 	),
		.m2_axis_tvalid	(m3_axis_tvalid	),
		.m2_axis_tready	(m3_axis_tready	),

		// Master AXIS 3 for Output data.
		.m3_axis_tdata	(m4_axis_tdata 	),
		.m3_axis_tvalid	(m4_axis_tvalid	),
		.m3_axis_tready	(m4_axis_tready	),

		// Master AXIS 4 for Output data.
		.m4_axis_tdata	(m5_axis_tdata 	),
		.m4_axis_tvalid	(m5_axis_tvalid	),
		.m4_axis_tready	(m5_axis_tready	),

		// Master AXIS 5 for Output data.
		.m5_axis_tdata	(m6_axis_tdata 	),
		.m5_axis_tvalid	(m6_axis_tvalid	),
		.m5_axis_tready	(m6_axis_tready	),

		// Master AXIS 6 for Output data.
		.m6_axis_tdata	(m7_axis_tdata 	),
		.m6_axis_tvalid	(m7_axis_tvalid	),
		.m6_axis_tready	(m7_axis_tready	),

		// Master AXIS 7 for Output data.
		.m7_axis_tdata	(m8_axis_tdata 	),
		.m7_axis_tvalid	(m8_axis_tvalid	),
		.m7_axis_tready	(m8_axis_tready	),

		// Registers.
		.START_SRC_REG 	(START_SRC_REG 	),
		.START_REG		(START_REG		)
);

// Assign outputs.
assign	pmem_addr = {pmem_addr_int[PMEM_N-4:0],3'b000};	// Multiply address by 8 to convert 64-bit address to 8-bit address.

endmodule

