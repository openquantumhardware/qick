module avg_top (
	// Reset and clock.
	rstn			,
	clk				,

	// Trigger input.
	trigger_i		,

	// Data input.
	din_valid_i		,
	din_i			,

	// Reset and clock for M_AXIS_*
	m_axis_aclk		,
	m_axis_aresetn	,

	// AXIS Master for output.
	m0_axis_tvalid	,
	m0_axis_tready	,
	m0_axis_tdata	,
	m0_axis_tlast	,

	// AXIS Master for register output.
	m1_axis_tvalid	,
	m1_axis_tready	,
	m1_axis_tdata	,

	// Registers.
	AVG_START_REG	,
	AVG_ADDR_REG	,
	AVG_LEN_REG		,
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

output				m0_axis_tvalid;
input				m0_axis_tready;
output	[4*B-1:0]	m0_axis_tdata;
output				m0_axis_tlast;

output				m1_axis_tvalid;
input				m1_axis_tready;
output	[4*B-1:0]	m1_axis_tdata;

input				AVG_START_REG;
input	[N-1:0]		AVG_ADDR_REG;
input	[31:0]		AVG_LEN_REG;
input				DR_START_REG;
input	[N-1:0]		DR_ADDR_REG;
input	[N-1:0]		DR_LEN_REG;

//////////////////////
// Internal signals //
//////////////////////
wire				mem_we_int;
wire	[N-1:0]		mem_addra_int, mem_addrb_int;
wire	[4*B-1:0]	mem_di_int, mem_do_int;

wire				AVG_START_REG_resync;
wire				DR_START_REG_resync;

wire				fifo_empty;

//////////////////
// Architecture //
//////////////////

// AVG_START_REG_resync
synchronizer_n
	#(
		.N	(2)
	)
	AVG_START_REG_resync_i (
		.rstn	    (rstn					),
		.clk 		(clk					),
		.data_in	(AVG_START_REG			),
		.data_out	(AVG_START_REG_resync	)
	);

// DR_START_REG_resync
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

// Average block.
avg 
	#(
		.N	(N),
		.B	(B)
	)
	avg_i
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
		.START_REG		(AVG_START_REG_resync	),
		.ADDR_REG		(AVG_ADDR_REG			),
		.LEN_REG		(AVG_LEN_REG			)
	);

// Dual port BRAM.
bram_dp
    #(
		.N	(N	),
        .B 	(4*B)
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
		.B	(4*B)
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
        .dout       (m0_axis_tdata			),
        .dready     (m0_axis_tready			),
        .dvalid     (m0_axis_tvalid			),
        .dlast      (m0_axis_tlast			),

        // Registers.
		.START_REG	(DR_START_REG_resync	),
		.ADDR_REG	(DR_ADDR_REG			),
		.LEN_REG	(DR_LEN_REG				)
    );

// Output data register (dc fifo to cross domain).
fifo_dc_axi
    #(
        // Data width.
        .B	(4*B	),
        
        // Fifo depth.
        .N	(4		)
    )
    fifo_i
    ( 
        .wr_rstn	(rstn			),
        .wr_clk 	(clk			),

        .rd_rstn	(m_axis_aresetn	),
        .rd_clk 	(m_axis_aclk	),
        
        // Write I/F.
        .wr_en  	(mem_we_int		),
        .din     	(mem_di_int		),
        
        // Read I/F.
        .rd_en  	(m1_axis_tready	),
        .dout   	(m1_axis_tdata	),
        
        // Flags.
        .full    	(				),
        .empty   	(fifo_empty		)
    );

// Assign outputs.
assign m1_axis_tvalid	= ~fifo_empty;

endmodule

