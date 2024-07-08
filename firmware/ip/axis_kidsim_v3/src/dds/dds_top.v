/*
 * DDS Control input format:
 *
 * |----------|---------|
 * | 31 .. 16 | 15 .. 0 |
 * |----------|---------|
 * | phase    | pinc    |
 * |----------|---------|
 *
 */
module dds_top
	(
		// Reset and clock.
		input 	wire 		rstn		,
		input 	wire 		clk			,

		// Modulation trigger.
		input	wire		trigger		,

		// Data input.
		input	wire		din_valid	,

		// Data output.
		output	wire		dout_valid	,
		output 	wire [31:0]	dout		,

		// Registers.
		input	wire [15:0]	BVAL_REG	,
		input	wire [15:0]	SLOPE_REG	,
		input	wire [15:0]	STEPS_REG	,
		input	wire [15:0]	WAIT_REG	,
		input	wire [15:0]	FREQ_REG
	);

/*************/
/* Internals */
/*************/
// DDS control outputs.
wire		dds_ctrl_valid;
wire [31:0]	dds_ctrl_dout;

// DDS outputs.
wire		dds_valid;
wire [31:0]	dds_dout;

/****************/
/* Architecture */
/****************/

// DDS control block.
// Latency = 2.
dds_ctrl
	dds_ctrl_i
	(
		// Reset and clock.
		.rstn		(rstn			),
		.clk		(clk			),

		// Modulation trigger.
		.trigger	(trigger		),

		// Data input.
		.din_valid	(din_valid		),
	
		// DDS control output.
		.dout_valid	(dds_ctrl_valid	),
		.dout		(dds_ctrl_dout	),

		// Registers.
		.BVAL_REG	(BVAL_REG		),
		.SLOPE_REG	(SLOPE_REG		),
		.STEPS_REG	(STEPS_REG		),
		.WAIT_REG	(WAIT_REG		),
		.FREQ_REG	(FREQ_REG		)
	);

// DDS IP.
// Latency = 8.
// The block will generate e^jw.
dds_0
	dds_i
	(
		.aclk					(clk			),
		.s_axis_phase_tvalid	(dds_ctrl_valid	),
		.s_axis_phase_tdata		(dds_ctrl_dout	),
		.m_axis_data_tvalid		(dds_valid		),
		.m_axis_data_tdata		(dds_dout		)
	);

// Assign outputs.
assign dout_valid	= dds_valid;
assign dout			= dds_dout;

endmodule

