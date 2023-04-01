/*
 * This block performs product between input data and dds.
 * input tvalid is not taken into account.
 * output tready is not taken into account.
 */
module down_conversion
	#(
		parameter N = 4
	)
	(
		// Reset and clock.
		input	wire				aresetn			,
		input	wire				aclk			,

		// Fifo interface.
		output	wire				fifo_rd_en		,
		input	wire				fifo_empty		,
		input	wire	[87:0]		fifo_dout		,

    	// s_axis for input data (N samples per clock).
		output	wire				s_axis_tready	,
		input	wire				s_axis_tvalid	,
		input	wire	[N*16-1:0]	s_axis_tdata	,

		// m_axis for output data.
		input	wire				m_axis_tready	,
		output	wire				m_axis_tvalid	,
		output	wire	[N*32-1:0]	m_axis_tdata
	);

/********************/
/* Internal signals */
/********************/
// Input data.
reg			[15:0]		din_real_r1		[N]	;
wire		[15:0]		din_real_la		[N]	;
wire		[15:0]		din_la_mux		[N]	;

// DDS input control.
reg						dds_tvalid_r		;
wire 		[N*72-1:0]	dds_ctrl_int		;
reg 		[N*72-1:0]	dds_ctrl_int_r		;

// DDS output.
wire 		[31:0]		dds_dout		[N]	;
reg			[31:0]		dds_dout_r1		[N]	;
wire		[31:0]		dds_dout_la		[N]	;
wire		[31:0]		dds_la_mux		[N]	;

// Product.
wire signed	[15:0]		prod_a_real			[N]	;
wire signed	[15:0]		prod_b_real			[N]	;
wire signed	[15:0]		prod_b_imag			[N]	;
wire signed [31:0]		prod_y_real			[N]	;
wire signed [31:0]		prod_y_imag			[N]	;
wire signed [15:0]		prod_y_real_round	[N]	;
wire signed [15:0]		prod_y_imag_round	[N]	;
wire		[31:0] 		prod_y				[N]	;
reg			[31:0]		prod_y_r1			[N]	;
reg			[31:0]		prod_y_r2			[N]	;

// Muxed output.
wire		[31:0]		dout_mux			[N]	;
reg			[31:0]		dout_mux_r1			[N]	;

// Output source selection.
wire		[1:0]		outsel_int				;
wire		[1:0]		outsel_la				;

// Output enable.
wire					en_int					;
wire					en_la					;

/**********************/
/* Begin Architecture */
/**********************/
// Control block.
ctrl 
	#(
		.N(N)
	)
	ctrl_i
	(
		// Reset and clock.
		.aresetn	(aresetn		),
		.aclk		(aclk			),

		// Fifo interface.
		.fifo_rd_en	(fifo_rd_en		),
		.fifo_empty	(fifo_empty		),
		.fifo_dout	(fifo_dout		),

		// dds control.
		.dds_ctrl	(dds_ctrl_int	),

		// Output source selection.
		.outsel		(outsel_int		),
		
		// Output enable.
		.en			(en_int			)
		);

generate
genvar i;
	for (i=0; i<N; i=i+1) begin : GEN_dds
		/***********************/
		/* Block instantiation */
		/***********************/
		// DDS.
		// Latency: 10.
		dds_0 dds_i 
			(
		  		.aclk					(aclk						),
		  		.s_axis_phase_tvalid	(dds_tvalid_r				),
		  		.s_axis_phase_tdata		(dds_ctrl_int_r[i*72 +: 72]	),
		  		.m_axis_data_tvalid		(							),
		  		.m_axis_data_tdata		(dds_dout[i]				)
			);

		// Latency for input data (product).
		latency_reg
			#(
				.N(12),
				.B(16)
			)
			din_latency_reg_i
			(
				.rstn	(aresetn		),
				.clk	(aclk			),
		
				.din	(din_real_r1[i]	),
				.dout	(din_real_la[i]	)
			);

		// Latency for dds_dout (product).
		latency_reg
			#(
				.N(1),
				.B(32)
			)
			dds_dout_latency_reg_i
			(
				.rstn	(aresetn		),
				.clk	(aclk			),
		
				.din	(dds_dout_r1[i]	),
				.dout	(dds_dout_la[i]	)
			);

		// Latency for input data (mux).
		latency_reg
			#(
				.N(2),
				.B(16)
			)
			din_mux_latency_reg_i
			(
				.rstn	(aresetn		),
				.clk	(aclk			),
		
				.din	(din_real_la[i]	),
				.dout	(din_la_mux[i]	)
			);

		// Latency for dds_dout (mux).
		latency_reg
			#(
				.N(3),
				.B(32)
			)
			dds_mux_latency_reg_i
			(
				.rstn	(aresetn		),
				.clk	(aclk			),
		
				.din	(dds_dout_la[i]	),
				.dout	(dds_la_mux[i]	)
			);

		/*************/
		/* Registers */
		/*************/
		always @(posedge aclk) begin
			if (~aresetn) begin
				// Input data.
				din_real_r1	[i]	<= 0;

				// DDS output.
				dds_dout_r1	[i]	<= 0;

				// Product.
				prod_y_r1	[i]	<= 0;
				prod_y_r2	[i]	<= 0;

				// Muxed output.
				dout_mux_r1	[i]	<= 0;
			end
			else begin
				// Input data.
				din_real_r1	[i]	<= s_axis_tdata	[i*16 +: 16];

				// DDS output.
				dds_dout_r1	[i]	<= dds_dout		[i];

				// Product.
				prod_y_r1	[i]	<= prod_y		[i];
				prod_y_r2	[i]	<= prod_y_r1	[i];

				// Muxed output.
				dout_mux_r1	[i]	<= dout_mux		[i];
			end
		end

		/*****************************/
		/* Combinatorial assignments */
		/*****************************/
		// Product.
		assign prod_a_real		[i]	= din_real_la[i];
		assign prod_b_real		[i]	= dds_dout_la[i][15:0];
		assign prod_b_imag		[i]	= dds_dout_la[i][31:16];
		assign prod_y_real		[i]	= prod_a_real[i]*prod_b_real[i];
		assign prod_y_imag		[i]	= prod_a_real[i]*prod_b_imag[i];
		assign prod_y_real_round[i]	= prod_y_real[i][30 -: 16];
		assign prod_y_imag_round[i]	= prod_y_imag[i][30 -: 16];
		assign prod_y			[i]	= {prod_y_imag_round[i],prod_y_real_round[i]};

		// Muxed output.
		assign dout_mux[i] 			=	(outsel_la == 0)? prod_y_r2[i]	: 
										(outsel_la == 1)? dds_la_mux[i]	:
										(outsel_la == 2)? din_la_mux[i]	:
										32'h0000_0000;
		/***********/
		/* Outputs */
		/***********/
		// Always on output (not using en like in signal_gen_v6).
		assign m_axis_tdata[i*32 +: 32] =	dout_mux_r1[i];

	end
endgenerate 

// Latency for source selection.
latency_reg
	#(
		.N(15),
		.B(2)
	)
	outsel_latency_reg_i
	(
		.rstn	(aresetn	),
		.clk	(aclk		),

		.din	(outsel_int	),
		.dout	(outsel_la	)
	);

// Latency for output enable.
latency_reg
	#(
		.N(19),
		.B(16)
	)
	en_latency_reg_i
	(
		.rstn	(aresetn),
		.clk	(aclk	),

		.din	(en_int	),
		.dout	(en_la	)
	);

// Registers.
always @(posedge aclk) begin
	if (~aresetn) begin
		// DDS intput control.
		dds_tvalid_r	<= 0;
		dds_ctrl_int_r	<= 0;
	end
	else begin
		// DDS intput control.
		dds_tvalid_r	<= 1;
		dds_ctrl_int_r	<= dds_ctrl_int;
	end
end

// Outputs.
assign s_axis_tready	= 1'b1;
assign m_axis_tvalid 	= 1'b1;

endmodule

