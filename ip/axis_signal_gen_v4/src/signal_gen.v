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
	m_axis_tdata_o	,

	// Registers.
	RNDQ_REG		,
	OUTSEL_REG
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

input		[31:0]			RNDQ_REG;
input						OUTSEL_REG;

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
wire 		[31:0]			dds_dout			[0:N_DDS-1];
reg			[31:0]			dds_dout_r1			[0:N_DDS-1];
reg			[31:0]			dds_dout_r2			[0:N_DDS-1];
reg			[31:0]			dds_dout_r3			[0:N_DDS-1];
reg			[31:0]			dds_dout_r4			[0:N_DDS-1];
reg			[31:0]			dds_dout_r5			[0:N_DDS-1];
reg			[31:0]			dds_dout_r6			[0:N_DDS-1];

// Memory data.
reg			[15:0]			mem_dout_real_r1	[0:N_DDS-1];
reg 		[15:0]			mem_dout_real_r2	[0:N_DDS-1];
reg			[15:0]			mem_dout_real_r3	[0:N_DDS-1];
reg signed	[15:0]			mem_dout_real_r4	[0:N_DDS-1];
reg 		[15:0]			mem_dout_real_r5	[0:N_DDS-1];
reg 		[15:0]			mem_dout_real_r6	[0:N_DDS-1];
reg 		[15:0]			mem_dout_real_r7	[0:N_DDS-1];
reg			[15:0]			mem_dout_imag_r1	[0:N_DDS-1];
reg 		[15:0]			mem_dout_imag_r2	[0:N_DDS-1];
reg			[15:0]			mem_dout_imag_r3	[0:N_DDS-1];
reg signed	[15:0]			mem_dout_imag_r4	[0:N_DDS-1];
reg 		[15:0]			mem_dout_imag_r5	[0:N_DDS-1];
reg 		[15:0]			mem_dout_imag_r6	[0:N_DDS-1];
reg 		[15:0]			mem_dout_imag_r7	[0:N_DDS-1];

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
wire signed [31:0]			prod_y_full_imag	[0:N_DDS-1];
wire 		[15:0]			prod_y_real			[0:N_DDS-1];
wire 		[15:0]			prod_y_imag			[0:N_DDS-1];
wire		[31:0] 			prod_y				[0:N_DDS-1];
reg			[31:0]			prod_y_r1			[0:N_DDS-1];
reg			[31:0]			prod_y_r2			[0:N_DDS-1];

// Muxed output.
wire		[31:0]			dout_mux			[0:N_DDS-1];
reg			[31:0]			dout_mux_r1			[0:N_DDS-1];
reg 		[31:0]			dout_mux_r2			[0:N_DDS-1];

// Product with Gain.
wire		[15:0]			gain_int;
reg			[15:0]			gain_int_r1;
reg			[15:0]			gain_int_r2;
reg			[15:0]			gain_int_r3;
reg			[15:0]			gain_int_r4;
reg			[15:0]			gain_int_r5;
reg			[15:0]			gain_int_r6;
reg			[15:0]			gain_int_r7;
reg			[15:0]			gain_int_r8;
reg			[15:0]			gain_int_r9;
reg			[15:0]			gain_int_r10;
reg	signed	[15:0]			gain_int_r11;
wire signed	[15:0]			prodg_a_real		[0:N_DDS-1];
wire signed	[15:0]			prodg_a_imag		[0:N_DDS-1];
wire signed [31:0]			prodg_y_full_real	[0:N_DDS-1];
wire signed [31:0]			prodg_y_full_imag	[0:N_DDS-1];
reg signed 	[31:0]			prodg_y_full_real_r	[0:N_DDS-1];
reg signed 	[31:0]			prodg_y_full_imag_r	[0:N_DDS-1];

// Rounding before truncation.
// 32-bit -> 24-bit before dithering.
// 14-bit: DAC resolution.
// << 2 those 14-bit to left-align before going out to dac.
wire signed [23:0]			round_full_real		[0:N_DDS-1];
wire signed [23:0]			round_full_imag		[0:N_DDS-1];
wire 		[13:0]			round_real			[0:N_DDS-1];
wire 		[13:0]			round_imag			[0:N_DDS-1];
wire 		[31:0]			round				[0:N_DDS-1];
reg 		[15:0]			round_r_real		[0:N_DDS-1];
reg 		[15:0]			round_r_imag		[0:N_DDS-1];
wire 		[15:0]			round_r_mux			[0:N_DDS-1];

// Output source selection.
wire		[1:0]			src_int;
reg			[1:0]			src_int_r1;
reg			[1:0]			src_int_r2;
reg			[1:0]			src_int_r3;
reg			[1:0]			src_int_r4;
reg			[1:0]			src_int_r5;
reg			[1:0]			src_int_r6;
reg			[1:0]			src_int_r7;
reg			[1:0]			src_int_r8;
reg			[1:0]			src_int_r9;

// Steady value selection.
wire						stdy_int;
reg							stdy_int_r1;
reg							stdy_int_r2;
reg							stdy_int_r3;
reg							stdy_int_r4;
reg							stdy_int_r5;
reg							stdy_int_r6;
reg							stdy_int_r7;
reg							stdy_int_r8;
reg							stdy_int_r9;
reg							stdy_int_r10;
reg							stdy_int_r11;
reg							stdy_int_r12;
reg							stdy_int_r13;
reg							stdy_int_r14;

// Output enable.
wire						en_int;
reg							en_int_r1;
reg							en_int_r2;
reg							en_int_r3;
reg							en_int_r4;
reg							en_int_r5;
reg							en_int_r6;
reg							en_int_r7;
reg							en_int_r8;
reg							en_int_r9;
reg							en_int_r10;
reg							en_int_r11;
reg							en_int_r12;
reg							en_int_r13;
reg							en_int_r14;

// Output selection mux.
wire						outmux_sel;

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
		dds_compiler_0 dds_i 
			(
		  		.aclk					(clk						),
		  		.s_axis_phase_tvalid	(dds_tvalid_r				),
		  		.s_axis_phase_tdata		(dds_ctrl_int_r[i*72 +: 72]	),
		  		.m_axis_data_tvalid		(							),
		  		.m_axis_data_tdata		(dds_dout[i]				)
			);

		// Dithering.
		dither
			#(
				.N		(24		),
				.M		(14		),
				.SEED	(2*i	)
			)
			dither_real_i
			(
				.rstn		(rstn				),
				.clk		(clk				),
				.din		(round_full_real[i]	),
				.dout		(round_real[i]		),
				
				// Registers.
				.RNDQ_REG	(RNDQ_REG			)
			);

		dither
			#(
				.N		(24		),
				.M		(14		),
				.SEED	(2*i+1	)
			)
			dither_imag_i
			(
				.rstn		(rstn				),
				.clk		(clk				),
				.din		(round_full_imag[i]	),
				.dout		(round_imag[i]		),
				
				// Registers.
				.RNDQ_REG	(RNDQ_REG			)
			);

		/*************/
		/* Registers */
		/*************/
		always @(posedge clk) begin
			if (~rstn) begin
				// DDS output.
				dds_dout_r1				[i]	<= 0;
				dds_dout_r2				[i]	<= 0;
				dds_dout_r3				[i]	<= 0;
				dds_dout_r4				[i]	<= 0;
				dds_dout_r5				[i]	<= 0;
				dds_dout_r6				[i]	<= 0;

				// Memory data.
				mem_dout_real_r1		[i]	<= 0;
				mem_dout_real_r2		[i]	<= 0;
				mem_dout_real_r3		[i]	<= 0;
				mem_dout_real_r4		[i]	<= 0;
				mem_dout_real_r5		[i]	<= 0;
				mem_dout_real_r6		[i]	<= 0;
				mem_dout_real_r7		[i]	<= 0;
				mem_dout_imag_r1		[i]	<= 0;
				mem_dout_imag_r2		[i]	<= 0;
				mem_dout_imag_r3		[i]	<= 0;
				mem_dout_imag_r4		[i]	<= 0;
				mem_dout_imag_r5		[i]	<= 0;
				mem_dout_imag_r6		[i]	<= 0;
				mem_dout_imag_r7		[i]	<= 0;

				// Product.
				prod_y_full_real_a_r	[i]	<= 0;
				prod_y_full_real_b_r	[i]	<= 0;
				prod_y_full_imag_a_r	[i]	<= 0;
				prod_y_full_imag_b_r	[i]	<= 0;
				prod_y_r1				[i]	<= 0;
				prod_y_r2				[i]	<= 0;

				// Muxed output.
				dout_mux_r1				[i]	<= 0;
				dout_mux_r2				[i]	<= 0;

				// Product with Gain.
				prodg_y_full_real_r		[i] <= 0;
				prodg_y_full_imag_r		[i] <= 0;

				// Rounding before truncation.
				round_r_real			[i]	<= 0;
				round_r_imag			[i]	<= 0;
			end
			else begin
				// DDS output.
				dds_dout_r1				[i]	<= dds_dout				[i];
				dds_dout_r2				[i] <= dds_dout_r1			[i];
				dds_dout_r3				[i] <= dds_dout_r2			[i];
				dds_dout_r4				[i] <= dds_dout_r3			[i];
				dds_dout_r5				[i] <= dds_dout_r4			[i];
				dds_dout_r6				[i] <= dds_dout_r5			[i];

				// Memory data.
				mem_dout_real_r1		[i]	<= mem_dout_real_i		[i*16 +: 16];
				mem_dout_real_r2		[i]	<= mem_dout_real_r1		[i];
				mem_dout_real_r3		[i]	<= mem_dout_real_r2		[i];
				mem_dout_real_r4		[i]	<= mem_dout_real_r3		[i];
				mem_dout_real_r5		[i]	<= mem_dout_real_r4		[i];
				mem_dout_real_r6		[i]	<= mem_dout_real_r5		[i];
				mem_dout_real_r7		[i]	<= mem_dout_real_r6		[i];
				mem_dout_imag_r1		[i]	<= mem_dout_imag_i		[i*16 +: 16];
				mem_dout_imag_r2		[i]	<= mem_dout_imag_r1		[i];
				mem_dout_imag_r3		[i]	<= mem_dout_imag_r2		[i];
				mem_dout_imag_r4		[i]	<= mem_dout_imag_r3		[i];
				mem_dout_imag_r5		[i]	<= mem_dout_imag_r4		[i];
				mem_dout_imag_r6		[i]	<= mem_dout_imag_r5		[i];
				mem_dout_imag_r7		[i]	<= mem_dout_imag_r6		[i];

				// Product.
				prod_y_full_real_a_r	[i]	<= prod_y_full_real_a	[i];
				prod_y_full_real_b_r	[i]	<= prod_y_full_real_b	[i];
				prod_y_full_imag_a_r	[i]	<= prod_y_full_imag_a	[i];
				prod_y_full_imag_b_r	[i]	<= prod_y_full_imag_b	[i];
				prod_y_r1				[i]	<= prod_y				[i];
				prod_y_r2				[i]	<= prod_y_r1			[i];

				// Muxed output.
				dout_mux_r1				[i]	<= dout_mux				[i];
				dout_mux_r2				[i]	<= dout_mux_r1			[i];
		
				// Product with gain.
				prodg_y_full_real_r		[i] <= prodg_y_full_real	[i];
				prodg_y_full_imag_r		[i] <= prodg_y_full_imag	[i];

				// Rounding before truncation (enabled register to retain last value).
				if (en_int_r13)
					round_r_real[i] <= round[i][15:0];
					round_r_imag[i] <= round[i][31:16];
			end
		end

		/*****************************/
		/* Combinatorial assignments */
		/*****************************/
		// Product.
		// Inputs.
		assign prod_a_real[i]			= dds_dout_r3[i][15:0];
		assign prod_a_imag[i]			= dds_dout_r3[i][31:16];
		assign prod_b_real[i]			= mem_dout_real_r4[i];
		assign prod_b_imag[i]			= mem_dout_imag_r4[i];

		// Partial products.
		assign prod_y_full_real_a[i]	= prod_a_real[i]*prod_b_real[i];
		assign prod_y_full_real_b[i]	= prod_a_imag[i]*prod_b_imag[i];
		assign prod_y_full_imag_a[i]	= prod_a_real[i]*prod_b_imag[i];
		assign prod_y_full_imag_b[i]	= prod_a_imag[i]*prod_b_real[i];

		// Addition or partial products.
		assign prod_y_full_real[i]		= prod_y_full_real_a_r[i] - prod_y_full_real_b_r[i];
		assign prod_y_full_imag[i]		= prod_y_full_imag_a_r[i] + prod_y_full_imag_b_r[i];
		
		// Quantization.	
		assign prod_y_real[i]			= prod_y_full_real[i][31:16];
		assign prod_y_imag[i]			= prod_y_full_imag[i][31:16];
		assign prod_y[i]				= {prod_y_imag[i],prod_y_real[i]};

		// Muxed output.
		assign dout_mux[i] 			=	(src_int_r9 == 0)? prod_y_r2[i]								: 
										(src_int_r9 == 1)? dds_dout_r6[i]							:
										(src_int_r9 == 2)? {mem_dout_imag_r7[i],mem_dout_real_r7[i]}:
										32'h0000_0000;
		// Product with Gain.
		assign prodg_a_real[i]		= dout_mux_r2[i][15:0];
		assign prodg_a_imag[i]		= dout_mux_r2[i][31:16];
		assign prodg_y_full_real[i]	= prodg_a_real[i]*gain_int_r11;
		assign prodg_y_full_imag[i]	= prodg_a_imag[i]*gain_int_r11;

		// Rounding before truncation.
		assign round_full_real[i]	= prodg_y_full_real_r[i][30 -: 24];				// 32-bit to 24-bit before dithering.
		assign round_full_imag[i]	= prodg_y_full_imag_r[i][30 -: 24]; 			// 32-bit to 24-bit before dithering.
		assign round[i]				= {round_imag[i],2'b00,round_real[i],2'b00};	// << 2 to left-align and convert to 16-bit.

		// Mux for real/imaginary part selection.
		assign round_r_mux[i]		= (OUTSEL_REG == 0)? round_r_real[i] : round_r_imag[i];

		/***********/
		/* Outputs */
		/***********/
		assign m_axis_tdata_o[i*16 +: 16] = (outmux_sel == 0)? round_r_mux[i] : 16'h0000;

	end
endgenerate 

// Registers.
always @(posedge clk) begin
	if (~rstn) begin
		// Memory address.
		mem_addr_int_r	<= 0;

		// DDS intput control.
		dds_tvalid_r	<= 0;
		dds_ctrl_int_r	<= 0;

		// Gain.
		gain_int_r1		<= 0;
		gain_int_r2		<= 0;
		gain_int_r3		<= 0;
		gain_int_r4		<= 0;
		gain_int_r5		<= 0;
		gain_int_r6		<= 0;
		gain_int_r7		<= 0;
		gain_int_r8		<= 0;
		gain_int_r9		<= 0;
		gain_int_r10	<= 0;
		gain_int_r11	<= 0;
		
		// Output source selection.
		src_int_r1		<= 0;
		src_int_r2		<= 0;
		src_int_r3		<= 0;
		src_int_r4		<= 0;
		src_int_r5		<= 0;
		src_int_r6		<= 0;
		src_int_r7		<= 0;
		src_int_r8		<= 0;
		src_int_r9		<= 0;

		// Steady value selection.
		stdy_int_r1		<= 0;
		stdy_int_r2		<= 0;
		stdy_int_r3		<= 0;
		stdy_int_r4		<= 0;
		stdy_int_r5		<= 0;
		stdy_int_r6		<= 0;
		stdy_int_r7		<= 0;
		stdy_int_r8		<= 0;
		stdy_int_r9		<= 0;
		stdy_int_r10	<= 0;
		stdy_int_r11	<= 0;
		stdy_int_r12	<= 0;
		stdy_int_r13	<= 0;
		stdy_int_r14	<= 0;
		
		// Output enable.
		en_int_r1		<= 0;
		en_int_r2		<= 0;
		en_int_r3		<= 0;
		en_int_r4		<= 0;
		en_int_r5		<= 0;
		en_int_r6		<= 0;
		en_int_r7		<= 0;
		en_int_r8		<= 0;
		en_int_r9		<= 0;
		en_int_r10		<= 0;
		en_int_r11		<= 0;
		en_int_r12		<= 0;
		en_int_r13		<= 0;
		en_int_r14		<= 0;
	end
	else begin
		// Memory address.
		mem_addr_int_r	<= mem_addr_int;

		// DDS intput control.
		dds_tvalid_r	<= 1;
		dds_ctrl_int_r	<= dds_ctrl_int;

		// Product with Gain.
		gain_int_r1		<= gain_int;
		gain_int_r2		<= gain_int_r1;
		gain_int_r3		<= gain_int_r2;
		gain_int_r4		<= gain_int_r3;
		gain_int_r5		<= gain_int_r4;
		gain_int_r6		<= gain_int_r5;
		gain_int_r7		<= gain_int_r6;
		gain_int_r8		<= gain_int_r7;
		gain_int_r9		<= gain_int_r8;
		gain_int_r10	<= gain_int_r9;
		gain_int_r11	<= gain_int_r10;

		// Output source selection.
		src_int_r1		<= src_int;
		src_int_r2		<= src_int_r1;
		src_int_r3		<= src_int_r2;
		src_int_r4		<= src_int_r3;
		src_int_r5		<= src_int_r4;
		src_int_r6		<= src_int_r5;
		src_int_r7		<= src_int_r6;
		src_int_r8		<= src_int_r7;
		src_int_r9		<= src_int_r8;
		
		// Steady value selection.
		stdy_int_r1		<= stdy_int;
		stdy_int_r2		<= stdy_int_r1;
		stdy_int_r3		<= stdy_int_r2;
		stdy_int_r4		<= stdy_int_r3;
		stdy_int_r5		<= stdy_int_r4;
		stdy_int_r6		<= stdy_int_r5;
		stdy_int_r7		<= stdy_int_r6;
		stdy_int_r8		<= stdy_int_r7;
		stdy_int_r9		<= stdy_int_r8;
		stdy_int_r10	<= stdy_int_r9;
		stdy_int_r11	<= stdy_int_r10;
		stdy_int_r12	<= stdy_int_r11;
		stdy_int_r13	<= stdy_int_r12;
		stdy_int_r14	<= stdy_int_r13;

		// Output enable.
		en_int_r1		<= en_int;
		en_int_r2		<= en_int_r1;
		en_int_r3		<= en_int_r2;
		en_int_r4		<= en_int_r3;
		en_int_r5		<= en_int_r4;
		en_int_r6		<= en_int_r5;
		en_int_r7		<= en_int_r6;
		en_int_r8		<= en_int_r7;
		en_int_r9		<= en_int_r8;
		en_int_r10		<= en_int_r9;
		en_int_r11		<= en_int_r10;
		en_int_r12		<= en_int_r11;
		en_int_r13		<= en_int_r12;
		en_int_r14		<= en_int_r13;
	end
end

// Output selection mux.
assign outmux_sel			= ~en_int_r14 & stdy_int_r14;

// Outputs.
assign mem_addr_o			= mem_addr_int_r;
assign m_axis_tvalid_o 		= en_int_r14;

endmodule

