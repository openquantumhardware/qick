module phase_ctrl (
	// Reset and clock.
	rstn			,
	clk				,

	// dds control.
	dds_ctrl_o		,

	// Registers.
	PINC_REG		,
	WE_REG			);

// Number of parallel dds blocks.
parameter [31:0] N_DDS = 2;

// Ports.
input					rstn;
input					clk;
output 	[N_DDS*72-1:0]	dds_ctrl_o;
input	[31:0]			PINC_REG;
input					WE_REG;

// Pinc.
reg		[31:0]	pinc_r1a;
reg		[31:0]	pinc_r1b;
wire	[31:0]	pinc_N;
wire	[31:0]	pinc_N_la;

// Phase vectors.
wire	[31:0]	phase_v0 	[0:N_DDS-1];
wire	[31:0]	phase_v0_la [0:N_DDS-1];

// Registers.
reg		[31:0]	PINC_REG_r;
reg				WE_REG_resync;

// WE_REG_resync.
synchronizer_n WE_REG_resync_i
	(
		.rstn	    (rstn			),
		.clk 		(clk			),
		.data_in	(WE_REG			),
		.data_out	(WE_REG_resync	)
	);

// Latency for pinc_N.
latency_reg
	#(
		.N(3),
		.B(32)
	)
	pinc_N_latency_reg_i
	(
		.rstn	(rstn		),
		.clk	(clk		),

		.din	(pinc_N		),
		.dout	(pinc_N_la	)
	);

// Registers.
always @(posedge clk) begin
	if (~rstn) begin
		// Pinc.
		pinc_r1a		<= 0;
		pinc_r1b		<= 0;

		// Registers.
		PINC_REG_r		<= 0;
	end
	else begin
		// Pinc.
		pinc_r1a		<= PINC_REG_r;
		pinc_r1b		<= PINC_REG_r;

		// Registers.
		if (WE_REG_resync == 1'b1)
			PINC_REG_r <= PINC_REG;
		end
end 

// Frequency calculation.
assign pinc_N		= pinc_r1a*N_DDS;

// Phase vectors.
generate
genvar i;
	for (i=0; i < N_DDS; i = i + 1) begin : GEN_phase
	// Latency for phase_v0.
	latency_reg
		#(
			.N(3),
			.B(32)
		)
		phase_v0_latency_reg_i
		(
			.rstn	(rstn			),
			.clk	(clk			),
	
			.din	(phase_v0[i]	),
			.dout	(phase_v0_la[i]	)
		);
		
		// v0.
		assign phase_v0[i] 		= pinc_r1b*i;

		// dds_ctrl_o output.
		assign dds_ctrl_o[i*72 +: 72]	= {8'h00,phase_v0_la[i],pinc_N_la};
	end
endgenerate

endmodule

