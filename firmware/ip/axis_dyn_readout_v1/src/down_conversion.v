module down_conversion (
	// Reset and clock.
	rstn			,
	clk				,

	// S_AXIS for input.
	s_axis_tready_o	,
	s_axis_tvalid_i	,
	s_axis_tdata_i	,

	// M_AXIS for output.
	m_axis_tready_i	,
	m_axis_tvalid_o	,
	m_axis_tdata_o	,

	// Fifo interface.
	fifo_rd_en_o	,
	fifo_empty_i	,
	fifo_dout_i
	);

/**************/
/* Parameters */
/**************/
// Number of parallel dds blocks.
parameter [15:0] N_DDS = 16;

// 0.5 for rounding.
localparam [31:0] RND_0P5 = 2**15;

/*********/
/* Ports */
/*********/
input						rstn;
input						clk;

output						s_axis_tready_o;
input						s_axis_tvalid_i;
input		[N_DDS*16-1:0]	s_axis_tdata_i;

input						m_axis_tready_i;
output						m_axis_tvalid_o;
output		[N_DDS*32-1:0]	m_axis_tdata_o;

output						fifo_rd_en_o;
input						fifo_empty_i;
input		[87:0]			fifo_dout_i;

/********************/
/* Internal signals */
/********************/
// DDS input control.
reg							dds_tvalid_r;
wire 		[N_DDS*72-1:0]	dds_ctrl_int;
reg 		[N_DDS*72-1:0]	dds_ctrl_int_r;

// Output selection.
wire		[1:0]			outsel_int;

// DDS output.
wire 		[31:0]			dds_dout			[0:N_DDS-1];
reg			[31:0]			dds_dout_r1			[0:N_DDS-1];
reg			[31:0]			dds_dout_r2			[0:N_DDS-1];
reg			[31:0]			dds_dout_r3			[0:N_DDS-1];
reg			[31:0]			dds_dout_r4			[0:N_DDS-1];

// Input data.
reg 		[15:0]			din_r1				[0:N_DDS-1];
reg signed	[15:0]			din_r2				[0:N_DDS-1];
reg 		[15:0]			din_r3				[0:N_DDS-1];
reg 		[15:0]			din_r4				[0:N_DDS-1];

// Product.
wire signed	[15:0]			pa_real				[0:N_DDS-1];
wire signed	[15:0]			pa_imag				[0:N_DDS-1];
wire signed [31:0]			py_full_real		[0:N_DDS-1];
wire signed [31:0]			py_full_imag		[0:N_DDS-1];
reg  signed [31:0]			py_full_real_r		[0:N_DDS-1];
reg  signed [31:0]			py_full_imag_r		[0:N_DDS-1];
wire signed [31:0]			py_round_real		[0:N_DDS-1];
wire signed [31:0]			py_round_imag		[0:N_DDS-1];
wire 		[15:0]			py_real				[0:N_DDS-1];
wire 		[15:0]			py_imag				[0:N_DDS-1];
wire		[31:0] 			py					[0:N_DDS-1];
reg			[31:0]			py_r				[0:N_DDS-1];

// Muxed output.
wire		[31:0]			dout_mux			[0:N_DDS-1];
reg			[31:0]			dout_mux_r			[0:N_DDS-1];

/**********************/
/* Begin Architecture */
/**********************/
// Control block.
ctrl 
	#(
		.N (N_DDS	)
	)
	ctrl_i
	(
		// Reset and clock.
		.aresetn		(rstn			),
		.aclk			(clk			),

		// Fifo interface.
		.fifo_rd_en	    (fifo_rd_en_o	),
		.fifo_empty   	(fifo_empty_i	),
		.fifo_dout    	(fifo_dout_i	),

		// dds control.
		.dds_ctrl		(dds_ctrl_int	),

		// Output source selection.
		.outsel   		(outsel_int		)
		);

generate
genvar i;
	for (i=0; i<N_DDS; i=i+1) begin : GEN_dds
		/***********************/
		/* Block instantiation */
		/***********************/
		// DDS.
		dds_compiler_0 dds_i 
			(
		  		.aclk					(clk						),
		  		.s_axis_phase_tvalid	(dds_tvalid_r				),
		  		.s_axis_phase_tdata		(dds_ctrl_int_r[i*72 +: 72]	),
		  		.m_axis_data_tvalid		(							),
		  		.m_axis_data_tdata		(dds_dout[i]				)
			);

		/*************/
		/* Registers */
		/*************/
		always @(posedge clk) begin
			if (~rstn) begin
				// DDS output.
				dds_dout_r1		[i]	<= 0;
				dds_dout_r2		[i]	<= 0;
				dds_dout_r3		[i]	<= 0;
				dds_dout_r4		[i]	<= 0;

				// Input data.
				din_r1			[i]	<= 0;
				din_r2			[i]	<= 0;
				din_r3			[i]	<= 0;
				din_r4			[i]	<= 0;

				// Product.
				py_full_real_r	[i]	<= 0;
				py_full_imag_r	[i]	<= 0;
				py_r			[i]	<= 0;

				// Muxed output.
				dout_mux_r		[i]	<= 0;
			end
			else begin
				// DDS output.
				dds_dout_r1		[i]	<= dds_dout			[i];
				dds_dout_r2		[i] <= dds_dout_r1		[i];
				dds_dout_r3		[i] <= dds_dout_r2		[i];
				dds_dout_r4		[i] <= dds_dout_r3		[i];

				// Input data.
				din_r1			[i]	<= s_axis_tdata_i	[i*16 +: 16];
				din_r2			[i]	<= din_r1			[i];
				din_r3			[i]	<= din_r2			[i];
				din_r4			[i]	<= din_r3			[i];

				// Product.
				py_full_real_r	[i]	<= py_full_real		[i];
				py_full_imag_r	[i]	<= py_full_imag		[i];
				py_r			[i]	<= py				[i];

				// Muxed output.
				dout_mux_r		[i]	<= dout_mux			[i];
			end
		end

		/*****************************/
		/* Combinatorial assignments */
		/*****************************/
		// Product.
		assign pa_real		[i]	= dds_dout_r2[i][15:0];
		assign pa_imag		[i]	= dds_dout_r2[i][31:16];
		assign py_full_real	[i]	= pa_real[i]*din_r2[i];
		assign py_full_imag	[i]	= pa_imag[i]*din_r2[i];
		assign py_round_real[i]	= py_full_real_r[i] + RND_0P5;
		assign py_round_imag[i]	= py_full_imag_r[i] + RND_0P5;
		assign py_real		[i]	= py_round_real[i][31:16];
		assign py_imag		[i]	= py_round_imag[i][31:16];
		assign py			[i]	= {py_imag[i],py_real[i]};

		// Muxed output.
		assign dout_mux		[i]	=	(outsel_int == 0)? py_r[i] 				: 
									(outsel_int == 1)? dds_dout_r4[i]		:
									(outsel_int == 2)? {16'h0000,din_r4[i]} :
									32'h0000_0000;

		/***********/
		/* Outputs */
		/***********/
		assign m_axis_tdata_o[i*32 +: 32] = dout_mux_r[i];

	end
endgenerate 


// Registers.
always @(posedge clk) begin
	if (~rstn) begin
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
assign s_axis_tready_o		= 1'b1;
assign m_axis_tvalid_o 		= 1'b1;

endmodule

