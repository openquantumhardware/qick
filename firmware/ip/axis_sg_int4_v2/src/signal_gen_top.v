module signal_gen_top 
	(
		// Reset and clock.
    	aresetn				,
		aclk				,

    	// AXIS Slave to load memory samples.
    	s0_axis_aresetn	    ,
		s0_axis_aclk		,
		s0_axis_tdata_i		,
		s0_axis_tvalid_i	,
		s0_axis_tready_o	,

    	// AXIS Slave to queue waveforms.
		s1_axis_tdata_i		,
		s1_axis_tvalid_i	,
		s1_axis_tready_o	,

		// M_AXIS for output.
		m_axis_tready_i		,
		m_axis_tvalid_o		,
		m_axis_tdata_o		,

		// Registers.
		START_ADDR_REG		,
		WE_REG
	);

/**************/
/* Parameters */
/**************/
// Memory address size.
parameter N = 16;

// Number of parallel dds blocks.
parameter [31:0] N_DDS = 4;

/*********/
/* Ports */
/*********/
input					aresetn;
input					aclk;

input					s0_axis_aresetn;
input					s0_axis_aclk;
input 	[31:0]			s0_axis_tdata_i;
input					s0_axis_tvalid_i;
output					s0_axis_tready_o;

input 	[159:0]			s1_axis_tdata_i;
input					s1_axis_tvalid_i;
output					s1_axis_tready_o;

input					m_axis_tready_i;
output					m_axis_tvalid_o;
output	[N_DDS*32-1:0]	m_axis_tdata_o;

input   [31:0]  		START_ADDR_REG;
input           		WE_REG;

/********************/
/* Internal signals */
/********************/
// Fifo.
wire					fifo_wr_en;
wire	[159:0]			fifo_din;
wire					fifo_rd_en;
wire	[159:0]			fifo_dout;
wire					fifo_full;
wire					fifo_empty;

// Memory.
wire					mem_ena;
wire					mem_wea;
wire	[N-1:0]			mem_addra;
wire	[31:0]			mem_dia;
wire	[N-1:0]			mem_addrb;
wire	[15:0]			mem_dob_real;
wire	[15:0]			mem_dob_imag;

/**********************/
/* Begin Architecture */
/**********************/

// Fifo.
fifo
    #(
        // Data width.
        .B	(160),
        
        // Fifo depth.
        .N	(16)
    )
    fifo_i
	( 
        .rstn	(aresetn	),
        .clk 	(aclk		),

        // Write I/F.
        .wr_en 	(fifo_wr_en	),
        .din    (fifo_din	),
        
        // Read I/F.
        .rd_en 	(fifo_rd_en	),
        .dout  	(fifo_dout	),
        
        // Flags.
        .full   (fifo_full	),
        .empty  (fifo_empty	)
    );

assign fifo_wr_en	= s1_axis_tvalid_i;
assign fifo_din		= s1_axis_tdata_i;

// Data writer.
data_writer
    #(
        // Address map of memory.
        .N	(N		),
        // Data width.
        .B	(32		)
    )
    data_writer_i
    (
        .rstn           (s0_axis_aresetn	),
        .clk            (s0_axis_aclk       ),
        
        // AXI Stream I/F.
        .s_axis_tready	(s0_axis_tready_o	),
		.s_axis_tdata	(s0_axis_tdata_i	),
		.s_axis_tvalid	(s0_axis_tvalid_i	),
		
		// Memory I/F.
		.mem_en         (mem_ena			),
		.mem_we         (mem_wea			),
		.mem_addr       (mem_addra			),
		.mem_di         (mem_dia			),
		
		// Registers.
		.START_ADDR_REG (START_ADDR_REG		),
		.WE_REG			(WE_REG				)
    );

// Memory for Real Part.
bram_dp
    #(
        // Memory address size.
        .N	(N),
        // Data width.
        .B	(16)
    )
    mem_real_i
	( 
		.clka    (s0_axis_aclk	),
        .clkb    (aclk			),
        .ena     (mem_ena		),
        .enb     (1'b1			),
        .wea     (mem_wea		),
        .web     (1'b0			),
        .addra   (mem_addra		),
        .addrb   (mem_addrb		),
        .dia     (mem_dia[15:0]	),
        .dib     (16'h0000		),
        .doa     (				),
        .dob     (mem_dob_real	)
    );

// Memory for Imaginary Part.
bram_dp
    #(
        // Memory address size.
        .N	(N),
        // Data width.
        .B	(16)
    )
    mem_imag_i
	( 
		.clka    (s0_axis_aclk		),
        .clkb    (aclk				),
        .ena     (mem_ena			),
        .enb     (1'b1				),
        .wea     (mem_wea			),
        .web     (1'b0				),
        .addra   (mem_addra			),
        .addrb   (mem_addrb			),
        .dia     (mem_dia[31:16]	),
        .dib     (16'h0000			),
        .doa     (					),
        .dob     (mem_dob_imag		)
    );

// Signal gen. 
signal_gen 
	#(
		.N		(N		),
		.N_DDS	(N_DDS	)
	)
	signal_gen_i
	(
		// Reset and clock.
		.rstn				(aresetn			),
		.clk				(aclk				),

		// Fifo interface.
		.fifo_rd_en_o		(fifo_rd_en			),
		.fifo_empty_i		(fifo_empty			),
		.fifo_dout_i		(fifo_dout			),

		// Memory interface.
		.mem_addr_o			(mem_addrb			),
		.mem_dout_real_i	(mem_dob_real		),
		.mem_dout_imag_i	(mem_dob_imag		),

		// M_AXIS for output.
		.m_axis_tready_i	(m_axis_tready_i	),
		.m_axis_tvalid_o	(m_axis_tvalid_o	),
		.m_axis_tdata_o		(m_axis_tdata_o		)
	);


// Assign outputs.
assign s1_axis_tready_o	= ~fifo_full;

endmodule

