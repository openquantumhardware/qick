module signal_gen (
	// Reset and clock.
	rstn			,
	clk				,

	// Fifo interface.
	fifo_rd_en_o	,
	fifo_empty_i	,
	fifo_dout_i		,

	// Memory interface.
	mem_addr_o		,
	mem_dout_real_i	,
	mem_dout_imag_i	,

	// M_AXIS for output.
	m_axis_tready_i	,
	m_axis_tvalid_o	,
	m_axis_tdata_o
	);

/**************/
/* Parameters */
/**************/
// Memory address size.
parameter N = 16;

// Number of parallel dds blocks.
parameter [31:0] N_DDS = 16;

/*********/
/* Ports */
/*********/
input						rstn;
input						clk;

output						fifo_rd_en_o;
input						fifo_empty_i;
input		[159:0]			fifo_dout_i;

output 		[N-1:0]			mem_addr_o;
input 		[N_DDS*16-1:0]	mem_dout_real_i;
input 		[N_DDS*16-1:0]	mem_dout_imag_i;

input						m_axis_tready_i;
output						m_axis_tvalid_o;
output		[N_DDS*16-1:0]	m_axis_tdata_o;

/********************/
/* Internal signals */
/********************/
// Memory address.
wire		[N-1:0]			mem_addr_int;
reg			[N-1:0]			mem_addr_int_r;

// DDS input control.
reg							dds_tvalid_r;
wire 		[N_DDS*72-1:0]	dds_ctrl_int;
reg 		[N_DDS*72-1:0]	dds_ctrl_int_r;

// DDS output.
wire 		[31:0]			dds_dout		[0:N_DDS-1];
reg			[31:0]			dds_dout_r1		[0:N_DDS-1];
wire		[31:0]			dds_dout_la		[0:N_DDS-1];
wire		[15:0]			dds_la_mux		[0:N_DDS-1];

// Memory data.
reg			[15:0]			mem_real_r1		[0:N_DDS-1];
reg			[15:0]			mem_imag_r1		[0:N_DDS-1];
wire		[15:0]			mem_real_la		[0:N_DDS-1];
wire		[15:0]			mem_imag_la		[0:N_DDS-1];
wire		[15:0]			mem_la_mux		[0:N_DDS-1];

// Product.
wire signed	[15:0]			prod_a_real			[0:N_DDS-1];
wire signed	[15:0]			prod_a_imag			[0:N_DDS-1];
wire signed	[15:0]			prod_b_real			[0:N_DDS-1];
wire signed	[15:0]			prod_b_imag			[0:N_DDS-1];
wire signed [31:0]			prod_y_full_real_a	[0:N_DDS-1];
wire signed [31:0]			prod_y_full_real_b	[0:N_DDS-1];
reg	 signed [31:0]			prod_y_full_real_a_r[0:N_DDS-1];
reg  signed [31:0]			prod_y_full_real_b_r[0:N_DDS-1];
wire signed [31:0]			prod_y_full_imag_a	[0:N_DDS-1];
wire signed [31:0]			prod_y_full_imag_b	[0:N_DDS-1];
reg  signed [31:0]			prod_y_full_imag_a_r[0:N_DDS-1];
reg  signed [31:0]			prod_y_full_imag_b_r[0:N_DDS-1];
wire signed [31:0]			prod_y_full_real	[0:N_DDS-1];
wire 		[15:0]			prod_y_real			[0:N_DDS-1];
wire		[15:0] 			prod_y				[0:N_DDS-1];
reg			[15:0]			prod_y_r1			[0:N_DDS-1];
reg			[15:0]			prod_y_r2			[0:N_DDS-1];

// Muxed output.
wire		[15:0]			dout_mux			[0:N_DDS-1];
wire		[15:0]			dout_mux_la			[0:N_DDS-1];

// Product with Gain.
wire		[15:0]			gain_int;
wire signed	[15:0]			gain_la;
wire signed	[15:0]			prodg_a_real		[0:N_DDS-1];
wire signed [31:0]			prodg_y_full_real	[0:N_DDS-1];
reg signed 	[31:0]			prodg_y_full_real_r	[0:N_DDS-1];

// Rounding.
wire 		[15:0]			round				[0:N_DDS-1];
reg 		[15:0]			round_r				[0:N_DDS-1];

// Last sample register.
reg 		[15:0]			last_r				[0:N_DDS-1];

// Output source selection.
wire		[1:0]			src_int;
wire		[1:0]			src_la;

// Steady value selection.
wire						stdy_int;
wire						stdy_la;

// Output enable.
wire						en_int;
wire						en_la;
reg							en_la_r;

/**********************/
/* Begin Architecture */
/**********************/
// Control block.
ctrl 
	#(
		.N		(N		),
		.N_DDS	(N_DDS	)
	)
	ctrl_i
	(
		// Reset and clock.
		.rstn			(rstn			),
		.clk			(clk			),

		// Fifo interface.
		.fifo_rd_en_o	(fifo_rd_en_o	),
		.fifo_empty_i	(fifo_empty_i	),
		.fifo_dout_i	(fifo_dout_i	),

		// dds control.
		.dds_ctrl_o		(dds_ctrl_int	),

		// memory control.
		.mem_addr_o		(mem_addr_int	),

		// gain.
		.gain_o			(gain_int		),

		// Output source selection.
		.src_o			(src_int		),
		
		// Steady value selection.
		.stdy_o			(stdy_int		),

		// Output enable.
		.en_o			(en_int			)
		);



generate
genvar i;
	for (i=0; i<N_DDS; i=i+1) begin : GEN_dds
		/***********************/
		/* Block instantiation */
		/***********************/
		// DDS.
		// Latency: 10.
		dds_compiler_0 dds_i 
			(
		  		.aclk					(clk						),
		  		.s_axis_phase_tvalid	(dds_tvalid_r				),
		  		.s_axis_phase_tdata		(dds_ctrl_int_r[i*72 +: 72]	),
		  		.m_axis_data_tvalid		(							),
		  		.m_axis_data_tdata		(dds_dout[i]				)
			);

		// Latency for real memory data (product).
		latency_reg
			#(
				.N(10),
				.B(16)
			)
			mem_real_latency_reg_i
			(
				.rstn	(rstn			),
				.clk	(clk			),
		
				.din	(mem_real_r1[i]	),
				.dout	(mem_real_la[i]	)
			);

		// Latency for imaginary memory data (product).
		latency_reg
			#(
				.N(10),
				.B(16)
			)
			mem_imag_latency_reg_i
			(
				.rstn	(rstn			),
				.clk	(clk			),
		
				.din	(mem_imag_r1[i]	),
				.dout	(mem_imag_la[i]	)
			);

		// Latency for dds_dout (product).
		latency_reg
			#(
				.N(1),
				.B(32)
			)
			dds_dout_latency_reg_i
			(
				.rstn	(rstn			),
				.clk	(clk			),
		
				.din	(dds_dout_r1[i]	),
				.dout	(dds_dout_la[i]	)
			);

		// Latency for real memory data (mux).
		latency_reg
			#(
				.N(3),
				.B(16)
			)
			mem_mux_latency_reg_i
			(
				.rstn	(rstn			),
				.clk	(clk			),
		
				.din	(mem_real_la[i]	),
				.dout	(mem_la_mux[i]	)
			);

		// Latency for dds_dout (mux).
		latency_reg
			#(
				.N(3),
				.B(16)
			)
			dds_mux_latency_reg_i
			(
				.rstn	(rstn					),
				.clk	(clk					),
		
				.din	(dds_dout_la[i][15:0]	),
				.dout	(dds_la_mux[i]			)
			);

		// Latency dout_mux (envelope x dds).
		latency_reg
			#(
				.N(2),
				.B(16)
			)
			dout_mux_latency_reg_i
			(
				.rstn	(rstn			),
				.clk	(clk			),
		
				.din	(dout_mux[i]	),
				.dout	(dout_mux_la[i]	)
			);

		/*************/
		/* Registers */
		/*************/
		always @(posedge clk) begin
			if (~rstn) begin
				// DDS output.
				dds_dout_r1				[i]	<= 0;

				// Memory data.
				mem_real_r1				[i]	<= 0;
				mem_imag_r1				[i]	<= 0;

				// Product.
				prod_y_full_real_a_r	[i]	<= 0;
				prod_y_full_real_b_r	[i]	<= 0;
				prod_y_full_imag_a_r	[i]	<= 0;
				prod_y_full_imag_b_r	[i]	<= 0;
				prod_y_r1				[i]	<= 0;
				prod_y_r2				[i]	<= 0;

				// Product with Gain.
				prodg_y_full_real_r		[i] <= 0;

				// Rounding.
				round_r					[i]	<= 0;

				// Last sample register.
				last_r					[i]	<= 0;
			end
			else begin
				// DDS output.
				dds_dout_r1				[i]	<= dds_dout				[i];

				// Memory data.
				mem_real_r1				[i]	<= mem_dout_real_i		[i*16 +: 16];
				mem_imag_r1				[i]	<= mem_dout_imag_i		[i*16 +: 16];

				// Product.
				prod_y_full_real_a_r	[i]	<= prod_y_full_real_a	[i];
				prod_y_full_real_b_r	[i]	<= prod_y_full_real_b	[i];
				prod_y_full_imag_a_r	[i]	<= prod_y_full_imag_a	[i];
				prod_y_full_imag_b_r	[i]	<= prod_y_full_imag_b	[i];
				prod_y_r1				[i]	<= prod_y				[i];
				prod_y_r2				[i]	<= prod_y_r1			[i];

				// Product with gain.
				prodg_y_full_real_r		[i] <= prodg_y_full_real	[i];

				// Rounding.
				round_r					[i] <= round				[i];

				// Last sample register.
				if (en_la)
					last_r [i]	<= round[N_DDS-1];
			end
		end

		/*****************************/
		/* Combinatorial assignments */
		/*****************************/
		// Product.
		// Inputs.
		assign prod_a_real[i]			= dds_dout_la[i][15:0];
		assign prod_a_imag[i]			= dds_dout_la[i][31:16];
		assign prod_b_real[i]			= mem_real_la[i];
		assign prod_b_imag[i]			= mem_imag_la[i];

		// Partial products.
		assign prod_y_full_real_a[i]	= prod_a_real[i]*prod_b_real[i];
		assign prod_y_full_real_b[i]	= prod_a_imag[i]*prod_b_imag[i];
		assign prod_y_full_imag_a[i]	= prod_a_real[i]*prod_b_imag[i];
		assign prod_y_full_imag_b[i]	= prod_a_imag[i]*prod_b_real[i];

		// Addition or partial products.
		assign prod_y_full_real[i]		= prod_y_full_real_a_r[i] - prod_y_full_real_b_r[i];
		
		// Quantization.	
		assign prod_y_real[i]			= prod_y_full_real[i][31:16];
		assign prod_y[i]				= prod_y_real[i];

		// Muxed output.
		assign dout_mux[i] 			=	(src_la == 0)? prod_y_r2[i]		: 
										(src_la == 1)? dds_la_mux[i]	:
										(src_la == 2)? mem_la_mux[i]	:
										16'h0000;
		// Product with Gain.
		assign prodg_a_real[i]		= dout_mux_la[i];
		assign prodg_y_full_real[i]	= prodg_a_real[i]*gain_la;

		// Rounding.
		assign round[i]				= prodg_y_full_real_r[i][30 -: 16];

		/***********/
		/* Outputs */
		/***********/
		assign m_axis_tdata_o[i*16 +: 16] =	(en_la_r == 1'b1)? round_r[i] 	: 
											(stdy_la == 1'b0)? last_r[i]	:
											16'h0000;

	end
endgenerate 

// Latency for source selection.
latency_reg
	#(
		.N(16),
		.B(2)
	)
	src_latency_reg_i
	(
		.rstn	(rstn		),
		.clk	(clk		),

		.din	(src_int	),
		.dout	(src_la		)
	);

// Latency for gain.
latency_reg
	#(
		.N(18),
		.B(16)
	)
	gain_latency_reg_i
	(
		.rstn	(rstn		),
		.clk	(clk		),

		.din	(gain_int	),
		.dout	(gain_la	)
	);

// Latency for steady value selection.
latency_reg
	#(
		.N(20),
		.B(1)
	)
	stdy_latency_reg_i
	(
		.rstn	(rstn		),
		.clk	(clk		),

		.din	(stdy_int	),
		.dout	(stdy_la	)
	);

// Latency for output enable.
latency_reg
	#(
		.N(19),
		.B(16)
	)
	en_latency_reg_i
	(
		.rstn	(rstn	),
		.clk	(clk	),

		.din	(en_int	),
		.dout	(en_la	)
	);

// Registers.
always @(posedge clk) begin
	if (~rstn) begin
		// Memory address.
		mem_addr_int_r	<= 0;

		// DDS intput control.
		dds_tvalid_r	<= 0;
		dds_ctrl_int_r	<= 0;

		// Output enable.
		en_la_r			<= 0;
	end
	else begin
		// Memory address.
		mem_addr_int_r	<= mem_addr_int;

		// DDS intput control.
		dds_tvalid_r	<= 1;
		dds_ctrl_int_r	<= dds_ctrl_int;

		// Output enable.
		en_la_r			<= en_la;
	end
end

// Outputs.
assign mem_addr_o			= mem_addr_int_r;
assign m_axis_tvalid_o 		= en_la_r;

endmodule

