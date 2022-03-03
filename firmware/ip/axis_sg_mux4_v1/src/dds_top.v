module dds_top (
	// Reset and clock.
	rstn			,
	clk				,

	// DDS output.
	dds_dout_o		,

	// Registers.
	PINC_REG		,
	WE_REG
	);

/**************/
/* Parameters */
/**************/
// Number of parallel dds blocks.
parameter [31:0] N_DDS = 2;

/*********/
/* Ports */
/*********/
input						rstn;
input						clk;

output		[N_DDS*32-1:0]	dds_dout_o;

input		[15:0]			PINC_REG;
input						WE_REG;

/********************/
/* Internal signals */
/********************/
// DDS input control.
reg							dds_tvalid_r;
wire 		[N_DDS*40-1:0]	dds_ctrl_int;
reg 		[N_DDS*40-1:0]	dds_ctrl_int_r;

// DDS output.
wire 		[31:0]			dds_dout	[0:N_DDS-1];
wire		[31:0]			dds_dout_la	[0:N_DDS-1];

/**********************/
/* Begin Architecture */
/**********************/
// Phase Control block.
phase_ctrl 
	#(
		.N_DDS	(N_DDS	)
	)
	phase_ctrl_i
	(
		// Reset and clock.
		.rstn		(rstn			),
		.clk		(clk			),

		// dds control.
		.dds_ctrl_o	(dds_ctrl_int	),

		// Registers.
		.PINC_REG	(PINC_REG		),
		.WE_REG		(WE_REG			)
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
		  		.s_axis_phase_tdata		(dds_ctrl_int_r[i*40 +: 40]	),
		  		.m_axis_data_tvalid		(							),
		  		.m_axis_data_tdata		(dds_dout[i]				)
			);

		// Latency for dds_dout.
		latency_reg
			#(
				.N(4),
				.B(32)
			)
			dds_dout_latency_reg_i
			(
				.rstn	(rstn			),
				.clk	(clk			),
		
				.din	(dds_dout[i]	),
				.dout	(dds_dout_la[i]	)
			);

		/***********/
		/* Outputs */
		/***********/
		assign dds_dout_o[i*32 +: 32] = dds_dout_la[i];

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

endmodule

