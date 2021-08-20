// Assembled memory access module. Three modes of accessing the memory:
//
// * Single access using the in/out ports. It's only available when busy_o = 0.
//
// * AXIS read: this mode allows to send data using m_axis_* interface, using
// ADDR_REG as the starting address and LEN_REG to indicate the number of
// samples to be transferred. The last sample will assert m_axis_tlast_o to
// indicate the external block transaction is done. Similar to AXIS write
// mode, the user needs to set START_REG = 1 to start the process.
//
// * AXIS write: this mode receives data from s_axis_* interface and writes
// into the memory using ADDR_REG as the starting address. The user must also
// provide the START_REG = 1 to allow starting receiving data. The block will
// rely on s_axis_tlast_i = 1 to finish the writing process.
//
// When not performing any AXIS transaction, the block will grant access to
// the memory using the single access interface. This is a very basic
// handshake interface to allow external blocks to easily communicate and
// perform single-access transaction. 
//
// Once a AXIS transaction is done, the user must set START_REG = 0 and back
// to 1 if a new AXIS transaction needs to be executed. START_REG = 1 steady
// will not allow further AXIS transactions, and will only allow
// single-access.
//
// Registers:
//
// MODE_REG : indicates the type of the next AXIS transaction.
// * 0 : AXIS Read (from memory to m_axis).
// * 1 : AXIS Write (from s_axis to memory).
//
// START_REG : starts execution of indicated AXIS transaction.
// * 0 : Stop.
// * 1 : Execute Operation.
//
// ADDR_REG : starting memory address for either AXIS read or write.
//
// LEN_REG : number of samples to be transferred in AXIS read mode.
//
module data_mem (
	// Reset and clock.
	aclk_i			,
	aresetn_i		,

	// Single Access Handshake.
	busy_o			,
	oper_i			,
	addr_i			,
	din_i			,
	dout_o			,
	exec_i			,
	exec_ack_o		,

	// Memory interface.
	mem_we_o		,
	mem_di_o		,
	mem_do_i		,
	mem_addr_o		,

	// AXIS Slave for receiving data.
	s_axis_tdata_i	,
	s_axis_tlast_i	,
	s_axis_tvalid_i	,
	s_axis_tready_o	,

	// AXIS Master for sending data.
	m_axis_tdata_o	,
	m_axis_tlast_o	,
	m_axis_tvalid_o	,
	m_axis_tready_i	,

	// Registers.
	MODE_REG		,
	START_REG		,
	ADDR_REG		,
	LEN_REG
);

// Parameters.
parameter N = 16;
parameter B = 32;

// Ports.
input			aclk_i;
input 			aresetn_i;

output 			busy_o;
input			oper_i;
input	[N-1:0]	addr_i;
input	[B-1:0]	din_i;
output	[B-1:0]	dout_o;
input			exec_i;
output			exec_ack_o;

output 			mem_we_o;
output	[B-1:0]	mem_di_o;
input	[B-1:0]	mem_do_i;
output	[N-1:0]	mem_addr_o;

// AXIS Slave for receiving data.
input	[B-1:0]	s_axis_tdata_i;
input			s_axis_tlast_i;
input			s_axis_tvalid_i;
output			s_axis_tready_o;

// AXIS Master for sending data.
output	[B-1:0]	m_axis_tdata_o;
output			m_axis_tlast_o;
output			m_axis_tvalid_o;
input			m_axis_tready_i;

input			MODE_REG;
input			START_REG;
input	[N-1:0]	ADDR_REG;
input	[N-1:0]	LEN_REG;

// Internals.
wire	[1:0]	sel;
wire			ar_exec;
wire			ar_exec_ack;
wire			aw_exec;
wire			aw_exec_ack;

// Memory Single.
wire			mem_we_single;
wire	[B-1:0]	mem_di_single;
wire	[N-1:0]	mem_addr_single;

// Memory AXIS Read.
wire			mem_we_aread;
wire	[N-1:0]	mem_addr_aread;

// Memory AXIS Write.
wire			mem_we_awrite;
wire	[B-1:0]	mem_di_awrite;
wire	[N-1:0]	mem_addr_awrite;

data_mem_ctrl 
	#(
		.N(N)
	)
	data_mem_ctrl_i
	(
		// Reset and clock.
		.aclk_i			(aclk_i	  		),
		.aresetn_i		(aresetn_i		),

		// Selector.
		.sel_o			(sel			),

		// axis_read handshake.
		.ar_exec_o		(ar_exec		),  
		.ar_exec_ack_i	(ar_exec_ack	),

		// axis_write handshake.
		.aw_exec_o		(aw_exec		),  
		.aw_exec_ack_i	(aw_exec_ack	),

		// Busy flag.
		.busy_o			(busy_o			),

		// Registers.
		.MODE_REG		(MODE_REG		),
		.START_REG		(START_REG		)
	);

mem_rw 
	#(
		.N(N),
		.B(B)
	)
	mem_rw_i
	(
		// Reset and clock.
		.aclk_i		(aclk_i	  			),
		.aresetn_i	(aresetn_i			),

		// Operation.
		.rw_i		(oper_i				),

		// Handshake.
		.exec_i		(exec_i				),
		.exec_ack_o	(exec_ack_o			),

		// Address.
		.addr_i		(addr_i				),

		// Input/Output data.
		.di_i		(din_i				),
		.do_o		(dout_o				),

		// Memory interface.
		.mem_we_o	(mem_we_single		),
		.mem_di_o	(mem_di_single		),
		.mem_do_i	(mem_do_i			),
		.mem_addr_o	(mem_addr_single	)
	);

axis_read
	#(
		.N(N),
		.B(B)
	)
	axis_read_i
	(
		// Reset and clock.
		.aclk_i				(aclk_i	  	),
		.aresetn_i			(aresetn_i	),

		// AXIS Master for sending data.
		.m_axis_tdata_o		(m_axis_tdata_o		),
		.m_axis_tlast_o		(m_axis_tlast_o		),
		.m_axis_tvalid_o	(m_axis_tvalid_o	),
		.m_axis_tready_i	(m_axis_tready_i	),

		// Memory interface.
		.mem_we_o			(mem_we_aread		),
		.mem_do_i			(mem_do_i			),
		.mem_addr_o			(mem_addr_aread		),

		// Handshake.
		.exec_i				(ar_exec			),
		.exec_ack_o			(ar_exec_ack		),

		// Start address.
		.addr_i				(ADDR_REG			),
		
		// Length.
		.len_i				(LEN_REG			)
	);

axis_write
	#(
		.N(N),
		.B(B)
	)
	axis_write_i
	(
		// Reset and clock.
		.aclk_i				(aclk_i	  			),
		.aresetn_i			(aresetn_i			),

		// AXIS Slave for receiving data.
		.s_axis_tdata_i		(s_axis_tdata_i		),
		.s_axis_tlast_i		(s_axis_tlast_i		),
		.s_axis_tvalid_i	(s_axis_tvalid_i	),
		.s_axis_tready_o	(s_axis_tready_o	),

		// Memory interface.
		.mem_we_o			(mem_we_awrite		),
		.mem_di_o			(mem_di_awrite		),
		.mem_addr_o			(mem_addr_awrite	),

		// Start.
		.exec_i				(aw_exec			),
		.exec_ack_o			(aw_exec_ack		),

		// Start address.
		.addr_i				(ADDR_REG			)
	);

// Assign outputs.
assign mem_we_o		= 	(sel == 0)? mem_we_single 	: 
						(sel == 1)? mem_we_aread	:
						(sel == 2)? mem_we_awrite	:
						1'b0;
assign mem_di_o		=	(sel == 0)? mem_di_single	:
						(sel == 2)? mem_di_awrite	:
						{B{1'b0}};
assign mem_addr_o	= 	(sel == 0)? mem_addr_single	:
						(sel == 1)?	mem_addr_aread	:
						(sel == 2)? mem_addr_awrite	:
						{N{1'b0}};

endmodule

