//Format of waveform interface:
module ctrl (
	// Reset and clock.
	rstn			,
	clk				,

	// dds control.
	dds_ctrl_o		,
	
	// Registers.
	DDS_FREQ_REG
	);

// Number of parallel dds blocks.
parameter [15:0] N_DDS = 16;

// Ports.
input					rstn;
input					clk;
output 	[N_DDS*40-1:0]	dds_ctrl_o;
input   [15:0]          DDS_FREQ_REG;

// DDS_FREQ_REG register.
reg		[15:0]	DDS_FREQ_REG_r;

// Pinc/phase.
wire	[15:0]	pinc_int;
reg		[15:0]	pinc_r1;
wire	[15:0]	pinc_N;
reg		[15:0]	pinc_N_r1;

// Phase vectors.
wire	[15:0]	phase_v0 	[0:N_DDS-1];
reg		[15:0]	phase_v0_r1 [0:N_DDS-1];

// Registers.
always @(posedge clk) begin
	if (~rstn) begin
		// DDS_FREQ_REG register.
		DDS_FREQ_REG_r	<= 0;

		// Pinc.
		pinc_r1			<= 0;
		pinc_N_r1		<= 0;
	end
	else begin
		// DDS_FREQ_REG regisrer.
		DDS_FREQ_REG_r	<= DDS_FREQ_REG;

		// Pinc.
		pinc_r1			<= pinc_int;
		pinc_N_r1		<= pinc_N;
	end
end 

// Frequency.
assign pinc_int		= DDS_FREQ_REG_r;

// Frequency calculation.
assign pinc_N		= pinc_r1*N_DDS;

// Phase vectors.
generate
genvar i;
	for (i=0; i < N_DDS; i = i + 1) begin : GEN_phase
		// Registers.
		always @(posedge clk) begin
			if (~rstn) begin
				phase_v0_r1[i]	<= 0;	
			end
			else begin
				phase_v0_r1[i] 	<= phase_v0[i];	
			end
		end

		// v0.
		assign phase_v0[i] 		= pinc_r1*i;

		// dds_ctrl_o output.
		assign dds_ctrl_o[i*40 +: 40]	= {8'h00,phase_v0_r1[i],pinc_N_r1};
	end
endgenerate

endmodule

