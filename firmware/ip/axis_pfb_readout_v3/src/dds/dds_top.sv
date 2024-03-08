module dds_top
	(
		// Clock.
		input	wire			aclk		,

		// Input valid.
		input	wire			din_valid	,

		// Output data.
		output	wire			dout_valid	,
		output	wire	[31:0]	dout		,

		// Registers.
		input	wire	[31:0]	PINC_REG	,
		input	wire	[31:0]	POFF_REG
	);

/********************/
/* Internal signals */
/********************/

// DDS control.
wire			ctrl_dout_valid	;
wire	[71:0]	ctrl_dout		;

// DDS.
wire			dds_dout_valid	;
wire	[31:0]	dds_dout		;

/**********************/
/* Begin Architecture */
/**********************/
// DDS control.
// Latency: 9.
dds_ctrl dds_ctrl_i
	(
		// Clock.
		.aclk		(aclk				),

		// Enable input.
		.en			(din_valid			),

		// Output data.
		.dout_valid	(ctrl_dout_valid	),
		.dout		(ctrl_dout			),

		// Registers.
		.PINC_REG	(PINC_REG			),
		.POFF_REG	(POFF_REG			)
	);

// DDS instance.
// Latency: 10.
dds_0 dds_i 
	(
 		.aclk				(aclk				),
  		.s_axis_phase_tvalid(ctrl_dout_valid	),
  		.s_axis_phase_tdata	(ctrl_dout			),
  		.m_axis_data_tvalid	(dds_dout_valid		),
  		.m_axis_data_tdata	(dds_dout			)
	);

// Assign outputs.
assign dout_valid	= dds_dout_valid	;
assign dout			= dds_dout			;

endmodule

