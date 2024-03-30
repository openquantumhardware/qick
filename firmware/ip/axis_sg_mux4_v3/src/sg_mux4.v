/*
 * Signal Generator with 4 output waves, independently masked.
 * Waveforms are created using parallel DDSs to cover a larger bandwidth.
 *
 */
module sg_mux4 (
	// Reset and clock.
	aresetn			,
	aclk			,

    // S_AXIS to queue waveforms.
	s_axis_tready_o	,
	s_axis_tvalid_i	,
	s_axis_tdata_i	,

	// M_AXIS for output.
	m_axis_tready_i	,
	m_axis_tvalid_o	,
	m_axis_tdata_o	,	

	// Registers.
	PINC0_REG		,
	PINC1_REG		,
	PINC2_REG		,
	PINC3_REG		,
	GAIN0_REG		,
	GAIN1_REG		,
	GAIN2_REG		,
	GAIN3_REG		,
	WE_REG
	);

/***************/
/* Parameters */
/**************/
// Number of parallel dds blocks.
parameter N_DDS = 2;

/*********/
/* Ports */
/*********/
input					aresetn;
input					aclk;

input 	[39:0]			s_axis_tdata_i;
input					s_axis_tvalid_i;
output					s_axis_tready_o;

input					m_axis_tready_i;
output					m_axis_tvalid_o;
output	[N_DDS*16-1:0]	m_axis_tdata_o;

input	[31:0]			PINC0_REG;
input	[31:0]			PINC1_REG;
input	[31:0]			PINC2_REG;
input	[31:0]			PINC3_REG;
input	[15:0]			GAIN0_REG;
input	[15:0]			GAIN1_REG;
input	[15:0]			GAIN2_REG;
input	[15:0]			GAIN3_REG;
input					WE_REG;

/********************/
/* Local Parameters */
/********************/
// Number of output waves.
localparam N_OUT = 4;

/********************/
/* Internal signals */
/********************/
// Fifo.
wire			fifo_wr_en;
wire	[39:0]	fifo_din;
wire			fifo_rd_en;
wire	[39:0]	fifo_dout;
wire			fifo_full;
wire			fifo_empty;

// PINC/GAIN registers vector.
wire	[31:0]	PINC_REG_v	[0:N_OUT-1];
wire	[15:0]	GAIN_REG_v	[0:N_OUT-1];

// DDS output.
wire 	[N_DDS*16-1:0]	dds_dout	[0:N_OUT-1];
wire	[N_DDS*16-1:0]	dds_dout_la	[0:N_OUT-1];

// Muxed DDS output.
wire	[N_DDS*16-1:0]	dds_mux		[0:N_OUT-1];
wire	[15:0]			dds_mux_v	[0:N_OUT-1][0:N_DDS-1];
wire	[15:0]			dds_real_v	[0:N_OUT-1][0:N_DDS-1];


// Addition vectors.
wire signed [15:0]	add0_real	[0:N_DDS-1];
wire signed [15:0]	add1_real	[0:N_DDS-1];
wire signed [15:0]	add2_real	[0:N_DDS-1];
wire signed [15:0]	add3_real	[0:N_DDS-1];
reg  signed [17:0]	add0_real_r	[0:N_DDS-1];
reg  signed [17:0]	add1_real_r	[0:N_DDS-1];
reg  signed [17:0]	add2_real_r	[0:N_DDS-1];
reg  signed [17:0]	add3_real_r	[0:N_DDS-1];

// Addition results.
wire signed [17:0]	sum0_real	[0:N_DDS-1];
wire signed [17:0]	sum1_real	[0:N_DDS-1];
wire signed [17:0]	sum2_real	[0:N_DDS-1];
reg  signed [17:0]	sum0_real_r	[0:N_DDS-1];
reg  signed [17:0]	sum1_real_r	[0:N_DDS-1];
reg  signed [17:0]	sum2_real_r	[0:N_DDS-1];

// Quantized output.
wire  		[15:0]	dout_real	[0:N_DDS-1];

// Mask.
wire	[7:0]	mask_int;

// Output enable.
wire			en_int;
wire			en_int_la;

// Output selection quantization.
// NOTE: change this if N_OUT changes.
wire	[3:0]	qsel;
wire	[3:0]	qsel_la;

/**********************/
/* Begin Architecture */
/**********************/
// PINC/GAIN registers vectors.
assign PINC_REG_v[0] = PINC0_REG;
assign PINC_REG_v[1] = PINC1_REG;
assign PINC_REG_v[2] = PINC2_REG;
assign PINC_REG_v[3] = PINC3_REG;
assign GAIN_REG_v[0] = GAIN0_REG;
assign GAIN_REG_v[1] = GAIN1_REG;
assign GAIN_REG_v[2] = GAIN2_REG;
assign GAIN_REG_v[3] = GAIN3_REG;

// Fifo.
fifo
    #(
        // Data width.
        .B	(40),
        
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

assign fifo_wr_en	= s_axis_tvalid_i;
assign fifo_din		= s_axis_tdata_i;

generate
genvar i,j;
	// Loop over N_OUT.
	for (i=0; i<N_OUT; i=i+1) begin : GEN_out
		/***********************/
		/* Block instantiation */
		/***********************/
		// DDS.
		dds_top 
			#(
				.N_DDS(N_DDS)
			)
			dds_top_i
			(
				// Reset and clock.
				.rstn			(aresetn		),
				.clk			(aclk			),
		
				// DDS output.
				.dds_dout_o		(dds_dout[i]	),
		
				// Registers.
				.PINC_REG		(PINC_REG_v[i]	),
				.GAIN_REG		(GAIN_REG_v[i]	),
				.WE_REG			(WE_REG			)
			);

		// Latency for dds_dout.
		latency_reg
			#(
				.N(4),
				.B(N_DDS*32)
			)
			dds_dout_latency_reg_i
			(
				.rstn	(aresetn		),
				.clk	(aclk			),
		
				.din	(dds_dout[i]	),
				.dout	(dds_dout_la[i]	)
			);

		/*****************************/
		/* Combinatorial assignments */
		/*****************************/
		// Muxed DDS output.
		assign dds_mux	[i]	= (mask_int[i] == 1'b1)? dds_dout_la[i] : 16'h0000;

		// Loop over N_DDS.
		for (j=0; j<N_DDS; j=j+1) begin : GEN_out_dds
			assign dds_mux_v[i][j] 	= dds_mux[i][16*j +: 16];
			assign dds_real_v[i][j]	= dds_mux_v[i][j];
		end
	end
endgenerate 

generate
	// Loop over N_DDS.
	for (i=0; i<N_DDS; i=i+1) begin : GEN_add

		// Registers.
		always @(posedge aclk) begin
			// Addition vectors.
			add0_real_r	[i] <= {{2{add0_real[i][15]}},add0_real[i]};
			add1_real_r	[i] <= {{2{add1_real[i][15]}},add1_real[i]};
			add2_real_r	[i] <= {{2{add2_real[i][15]}},add2_real[i]};
			add3_real_r	[i] <= {{2{add3_real[i][15]}},add3_real[i]};

			// Addition results.
			sum0_real_r	[i] <= sum0_real[i];
			sum1_real_r	[i] <= sum1_real[i];
			sum2_real_r	[i] <= sum2_real[i];
		end

		/*****************************/
		/* Combinatorial assignments */
		/*****************************/
		// Addition vectors.
		assign add0_real[i] = dds_real_v[0][i];
		assign add1_real[i] = dds_real_v[1][i];
		assign add2_real[i] = dds_real_v[2][i];
		assign add3_real[i] = dds_real_v[3][i];

		// Addition results.
		assign sum0_real[i]	= add0_real_r[i] + add1_real_r[i];
		assign sum1_real[i]	= add2_real_r[i] + add3_real_r[i];
		assign sum2_real[i]	= sum0_real_r[i] + sum1_real_r[i];

		// Quantized output: 0, 3 and 4 have the same quantization.
		assign dout_real[i] =	(qsel_la == 1)?	sum2_real_r[i][15:0]	:
								(qsel_la == 2)? sum2_real_r[i][16:1]	:		
								sum2_real_r[i][17:2];

		/***********/
		/* Outputs */
		/***********/
		assign m_axis_tdata_o[i*16 +: 16] = (en_int_la == 1'b1)? dout_real[i] : 16'h0000;
	end
endgenerate

// Control block.
ctrl ctrl_i
 	(
		// Reset and clock.
		.rstn			(aresetn		),
		.clk			(aclk			),

		// Fifo interface.
		.fifo_rd_en_o	(fifo_rd_en		),
		.fifo_empty_i	(fifo_empty		),
		.fifo_dout_i	(fifo_dout		),

		// Mask output.
		.mask_o			(mask_int		),

		// Output enable.
		.en_o			(en_int			)
	);

// Latency en_int
latency_reg
	#(
		.N(3),
		.B(1)
	)
	en_int_latency_reg_i
	(
		.rstn	(aresetn	),
		.clk	(aclk		),

		.din	(en_int 	),
		.dout	(en_int_la	)
	);

// Latency qsel.
latency_reg
	#(
		.N(3),
		.B(4)
	)
	qsel_latency_reg_i
	(
		.rstn	(aresetn	),
		.clk	(aclk		),

		.din	(qsel 		),
		.dout	(qsel_la	)
	);

// Output selection quantization.
assign qsel = mask_int[0] + mask_int[1] + mask_int[2] + mask_int[3];


// Assign outputs.
assign s_axis_tready_o = ~fifo_full;
assign m_axis_tvalid_o = en_int_la;

endmodule

