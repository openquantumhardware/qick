module phase_ctrl (
	// Reset and clock.
	rstn			,
	clk				,

	// dds control.
	dds_ctrl_o		,

	// Registers.
	PINC_REG		,
	POFF_REG		,
	WE_REG			);

// Number of parallel dds blocks.
parameter [31:0] N_DDS = 2;

// Ports.
input					rstn;
input					clk;
output 	[N_DDS*72-1:0]	dds_ctrl_o;
input	[31:0]			PINC_REG;
input	[31:0]			POFF_REG;
input					WE_REG;

// Pinc.
reg		[31:0]	pinc_r1a = 0;
reg		[31:0]	pinc_r1b = 0;
reg		[31:0]	pinc_r1c = 0;
wire	[63:0]	pinc_Nf;
wire	[31:0]	pinc_N;
reg		[31:0]	pinc_N_r1 = 0;
wire	[63:0]	pinc_Nmf;
wire	[31:0]	pinc_Nm;
reg		[31:0]	pinc_Nm_r1 = 0;

// poff.
reg		[31:0]	poff_r1 = 0;
reg		[31:0]	poff_r2 = 0;

// Phase vectors.
wire	[31:0]	phase_v0 	[0:N_DDS-1];
reg		[31:0]	phase_v0_r1	[0:N_DDS-1];
wire	[31:0]	phase_v1 	[0:N_DDS-1];
reg		[31:0]	phase_v1_r1	[0:N_DDS-1];

// Non-stop counter for phase coherent behavior.
reg		[31:0]	cnt_n = 0;
reg		[31:0]	cnt_n_r1 = 0;

// Registers.
reg		[31:0]	PINC_REG_r = 0;
reg		[31:0]	POFF_REG_r = 0;
reg				WE_REG_resync;

// WE_REG_resync.
synchronizer_n WE_REG_resync_i
	(
		.rstn	    (rstn			),
		.clk 		(clk			),
		.data_in	(WE_REG			),
		.data_out	(WE_REG_resync	)
	);

// PINC x N_DDS: 32x32 product, optimized for full-speed.
(* keep_hierarchy = "true" *) mult_32x32 mult0_i
	(
		.clk	(clk		),
		.din_a	(pinc_r1a	),
		.din_b	(N_DDS		),
		.dout	(pinc_Nf	)
	);

// Preserve lower 32 bits for modulo operation.
assign pinc_N = pinc_Nf [31:0];

// PINC x cnt_n: 32x32 product, optimized for full-speed.
mult_32x32 mult1_i
	(
		.clk	(clk		),
		.din_a	(pinc_r1c	),
		.din_b	(cnt_n_r1	),
		.dout	(pinc_Nmf	)
	);

// Preserve lower 32 bits for modulo operation.
assign pinc_Nm = pinc_Nmf [31:0];

// Registers.
always @(posedge clk) begin
	// Pinc.
	pinc_r1a	<= PINC_REG_r;
	pinc_r1b	<= PINC_REG_r;
	pinc_r1c	<= PINC_REG_r;
	pinc_N_r1	<= pinc_N;
	pinc_Nm_r1	<= pinc_Nm;

	// poff.
	poff_r1		<= POFF_REG_r;
	poff_r2		<= poff_r1;

	// Non-stop counter for phase coherent bahavior.
	cnt_n 		<= cnt_n + N_DDS;
	cnt_n_r1	<= cnt_n;

	// Registers.
	if (WE_REG_resync == 1'b1) begin
		PINC_REG_r <= PINC_REG;
		POFF_REG_r <= POFF_REG;
	end
end 

// Phase vectors.
generate
genvar i;
	for (i=0; i < N_DDS; i = i + 1) begin : GEN_phase
		// v0.
		assign phase_v0[i] 	= pinc_r1b*i;

		// v1.
		assign phase_v1[i]	= phase_v0_r1[i] + pinc_Nm_r1 + poff_r2;

		// dds_ctrl_o output.
		assign dds_ctrl_o[i*72 +: 72]	= {8'h01,phase_v1_r1[i],pinc_N_r1};

		// Registers.
		always @(posedge clk) begin
			// v0.
			phase_v0_r1 [i] <= phase_v0 [i];

			// v1.
			phase_v1_r1 [i] <= phase_v1 [i];
		end
	end
endgenerate

endmodule

