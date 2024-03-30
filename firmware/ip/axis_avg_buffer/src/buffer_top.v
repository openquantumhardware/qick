module buffer_top (
	// Reset and clock.
	rstn			,
	clk				,

	// Trigger input.
	trigger_i		,

	// Data input.
	din_valid_i		,
	din_i			,

	// AXIS Master for output.
	m_axis_aclk		,
	m_axis_aresetn	,
	m_axis_tvalid	,
	m_axis_tready	,
	m_axis_tdata	,
	m_axis_tlast	,

	// Registers.
	BUF_START_REG	,
	BUF_ADDR_REG	,
	BUF_LEN_REG		,
	DR_START_REG	,
	DR_ADDR_REG		,
	DR_LEN_REG
	);

////////////////
// Parameters //
////////////////
// Memory depth.
parameter N = 10;

// Number of bits.
parameter B = 16;

///////////
// Ports //
///////////
input				rstn;
input				clk;

input				trigger_i;

input				din_valid_i;
input	[2*B-1:0]	din_i;

input				m_axis_aclk;
input				m_axis_aresetn;
output				m_axis_tvalid;
input				m_axis_tready;
output	[2*B-1:0]	m_axis_tdata;
output				m_axis_tlast;

input				BUF_START_REG;
input	[N-1:0]		BUF_ADDR_REG;
input	[N-1:0]		BUF_LEN_REG;
input				DR_START_REG;
input	[N-1:0]		DR_ADDR_REG;
input	[N-1:0]		DR_LEN_REG;

//////////////////////
// Internal signals //
//////////////////////
wire				mem_we_int;
wire	[N-1:0]		mem_addra_int, mem_addrb_int;
wire	[2*B-1:0]	mem_di_int, mem_do_int;

wire				BUF_START_REG_resync;
wire				DR_START_REG_resync;

//////////////////
// Architecture //
//////////////////

// BUF_START_REG_resync
synchronizer_n
	#(
		.N	(2)
	)
	BUF_START_REG_resync_i (
		.rstn	    (rstn					),
		.clk 		(clk					),
		.data_in	(BUF_START_REG			),
		.data_out	(BUF_START_REG_resync	)
	);

//DR_START_REG_resync
synchronizer_n
	#(
		.N	(2)
	)
	DR_START_REG_resync_i (
		.rstn	    (m_axis_aresetn			),
		.clk 		(m_axis_aclk			),
		.data_in	(DR_START_REG			),
		.data_out	(DR_START_REG_resync	)
	);

// Buffer block.
buffer 
	#(
		.N	(N),
		.B	(B)
	)
	buffer_i
	(
		// Reset and clock.
		.rstn			(rstn					),
		.clk			(clk					),

		// Trigger input.
		.trigger_i		(trigger_i				),

		// Data input.
		.din_valid_i	(din_valid_i			),
		.din_i			(din_i					),

		// Memory interface.
		.mem_we_o		(mem_we_int				),
		.mem_addr_o		(mem_addra_int			),
		.mem_di_o		(mem_di_int				),

		// Registers.
		.START_REG		(BUF_START_REG_resync	),
		.ADDR_REG		(BUF_ADDR_REG			),
		.LEN_REG		(BUF_LEN_REG			)
	);

// Dual port BRAM.
bram_dp
    #(
		.N	(N	),
        .B 	(2*B)
    )
    bram_i 
	( 
		.clka	(clk			),
		.clkb	(m_axis_aclk	),
		.ena    (1'b1			),
		.enb    (1'b1			),
		.wea    (mem_we_int		),
		.web    (1'b0			),
		.addra  (mem_addra_int	),
		.addrb  (mem_addrb_int	),
		.dia    (mem_di_int		),
		.dib    ({4*B{1'b0}}	),
		.doa    (				),
		.dob    (mem_do_int		)
    );

// Data reader.
data_reader
    #(
		.N	(N	),
		.B	(2*B)
    )
    data_reader_i
    (
        // Reset and clock.
        .rstn		(m_axis_aresetn			),
        .clk		(m_axis_aclk			),
        
        // Memory I/F.
        .mem_en     (						),
        .mem_we     (						),
        .mem_addr   (mem_addrb_int			),
        .mem_dout   (mem_do_int				),
        
        // Data out.
        .dout       (m_axis_tdata			),
        .dready     (m_axis_tready			),
        .dvalid     (m_axis_tvalid			),
        .dlast      (m_axis_tlast			),

        // Registers.
		.START_REG	(DR_START_REG_resync	),
		.ADDR_REG	(DR_ADDR_REG			),
		.LEN_REG	(DR_LEN_REG				)
    );

endmodule

