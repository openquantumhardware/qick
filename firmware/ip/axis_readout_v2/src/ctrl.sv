//Format of waveform interface:
// |------|----------|----------|----------|---------|
// |   82 | 81 .. 80 | 79 .. 64 | 63 .. 32 | 31 .. 0 |
// |------|----------|----------|----------|---------|
// | mode |   outsel |    nsamp |    phase |    freq |
// |------|----------|----------|----------|---------|
// freq 	: 32 bits
// phase 	: 32 bits
// nsamp 	: 16 bits
// outsel 	: 2 bits
// mode 	: 1 bit
//
// Fifo : 83 bits.
module ctrl (
	// Reset and clock.
	rstn			,
	clk				,

	// Fifo interface.
	fifo_rd_en_o	,
	fifo_empty_i	,
	fifo_dout_i		,

	// dds control.
	dds_ctrl_o		,

	// Output source selection.
	outsel_o		);

// Number of parallel dds blocks.
parameter [31:0] N_DDS = 16;

// Ports.
input					rstn;
input					clk;
output					fifo_rd_en_o;
input					fifo_empty_i;
input	[82:0]			fifo_dout_i;
output 	[N_DDS*72-1:0]	dds_ctrl_o;
output	[1:0]			outsel_o;

// States.
typedef enum	{	READ_ST	,
					CNT_ST
				} state_t;

// State register.
(* fsm_encoding = "one_hot" *) state_t state;

// Fifo dout register.
reg		[82:0]	fifo_dout_r;

// Non-stop counter for time calculation (adds N_DDS samples each clock tick).
reg		[31:0]	cnt_n;
reg		[31:0]	cnt_n_reg;

// Pinc/phase.
wire	[31:0]	pinc_int;
reg		[31:0]	pinc_r1;
wire	[31:0]	pinc_N;
reg		[31:0]	pinc_N_r1;
reg		[31:0]	pinc_N_r2;
reg		[31:0]	pinc_N_r3;
wire	[31:0]	pinc_Nm;
reg		[31:0]	pinc_Nm_r1;

wire	[31:0]	phase_int;
reg		[31:0]	phase_r1; 
reg		[31:0]	phase_r2; 
wire	[31:0]	phase_0;
reg		[31:0]	phase_0_r1;

// Phase vectors.
wire	[31:0]	phase_v0 	[0:N_DDS-1];
reg		[31:0]	phase_v0_r1 [0:N_DDS-1];
reg		[31:0]	phase_v0_r2 [0:N_DDS-1];
wire	[31:0]	phase_v1 	[0:N_DDS-1];
reg		[31:0]	phase_v1_r1 [0:N_DDS-1];

// sync.
reg				sync_reg;
reg				sync_reg_r1;
reg				sync_reg_r2;
reg				sync_reg_r3;
reg				sync_reg_r4;

// Number of samples.
wire	[15:0]	nsamp_int;

// Output selection.
wire	[1:0]	outsel_int;
reg		[1:0]	outsel_r1;
reg		[1:0]	outsel_r2;
reg		[1:0]	outsel_r3;
reg		[1:0]	outsel_r4;

// Mode.
wire			mode_int;

// Load enable flag.
wire			load_int;
reg				load_r;

// Fifo Read Enable.
reg			    rd_en_int;
reg				rd_en_r1;
reg				rd_en_r2;

// Counter.
reg		[15:0]	cnt;

// Registers.
always @(posedge clk) begin
	if (~rstn) begin
		// State register.
		state 			<= READ_ST;

		// Fifo dout register.
		fifo_dout_r		<= 0;

		// Non-stop counter for time calculation.
		cnt_n			<= 0;
		cnt_n_reg		<= 0;

		// Pinc/phase/sync.
		pinc_r1			<= 0;
		pinc_N_r1		<= 0;
		pinc_N_r2		<= 0;
		pinc_N_r3		<= 0;
		pinc_Nm_r1		<= 0;

		phase_r1		<= 0;
		phase_r2		<= 0;
		phase_0_r1		<= 0;

		sync_reg		<= 0;
		sync_reg_r1		<= 0;
		sync_reg_r2		<= 0;
		sync_reg_r3		<= 0;
		sync_reg_r4		<= 0;

		// Output selection.
		outsel_r1		<= 0;
		outsel_r2		<= 0;
		outsel_r3		<= 0;
		outsel_r4		<= 0;

		// Load enable flag.
		load_r			<= 0;

		// Fifo Read Enable.
		rd_en_r1		<= 0;
		rd_en_r2		<= 0;

		// Counter.
		cnt				<= 0;
	end
	else begin
		// State register.
		case (state)
			READ_ST:
				if (mode_int || ~fifo_empty_i)
					state <= CNT_ST;
			CNT_ST:
				if ( cnt == nsamp_int-2 )
					state <= READ_ST;
		endcase

		// Fifo dout register.
		if (load_r)
			fifo_dout_r	<= fifo_dout_i;

		// Non-stop counter for time calculation.
		cnt_n			<= cnt_n + N_DDS;
		if (sync_reg)
			cnt_n_reg	<= cnt_n;

		// Pinc/phase/sync.
		pinc_r1			<= pinc_int;
		pinc_N_r1		<= pinc_N;
		pinc_N_r2		<= pinc_N_r1;
		pinc_N_r3		<= pinc_N_r2;
		pinc_Nm_r1		<= pinc_Nm;

		phase_r1		<= phase_int;
		phase_r2		<= phase_r1;
		phase_0_r1		<= phase_0;

		sync_reg		<= load_r;
		sync_reg_r1		<= sync_reg;
		sync_reg_r2		<= sync_reg_r1;
		sync_reg_r3		<= sync_reg_r2;
		sync_reg_r4		<= sync_reg_r3;

		// Output selection.
		outsel_r1		<= outsel_int;
		outsel_r2		<= outsel_r1;
		outsel_r3		<= outsel_r2;
		outsel_r4		<= outsel_r3;

		// Load enable flag.
		load_r			<= load_int;

		// Fifo Read Enable.
		rd_en_r1		<= rd_en_int;
		rd_en_r2		<= rd_en_r1;

		// Counter.
		if (rd_en_int)
			cnt	<= 0;
		else
			cnt <= cnt + 1;	
    end			
end 

// FSM outputs.
always_comb	begin
	// Default.
	rd_en_int = 0;

	case (state)
		READ_ST:
			rd_en_int = 1;

		CNT_ST:
			rd_en_int = 0;
	endcase
end

// Fifo output fields.
assign pinc_int		= fifo_dout_r[31:0];
assign phase_int	= fifo_dout_r[63:32];
assign nsamp_int	= fifo_dout_r[79:64];
assign outsel_int	= fifo_dout_r[81:80];
assign mode_int		= fifo_dout_r[82];

// Frequency calculation.
assign pinc_N		= pinc_r1*N_DDS;

// Phase calculation.
assign pinc_Nm		= pinc_r1*cnt_n_reg;
assign phase_0		= pinc_Nm_r1 + phase_r2;

// Phase vectors.
generate
genvar i;
	for (i=0; i < N_DDS; i = i + 1) begin : GEN_phase
		// Registers.
		always @(posedge clk) begin
			if (~rstn) begin
				// v0.
				phase_v0_r1[i]	<= 0;	
				phase_v0_r2[i]	<= 0;	

				// v1.
				phase_v1_r1[i]	<= 0;
			end
			else begin
				// v0.
				phase_v0_r1[i] 	<= phase_v0[i];	
				phase_v0_r2[i] 	<= phase_v0_r1[i];	

				// v1.
				phase_v1_r1[i]	<= phase_v1[i];
			end
		end

		// v0.
		assign phase_v0[i] 		= pinc_r1*i;

		// v1.
		assign phase_v1[i] 		= phase_v0_r2[i] + phase_0_r1;

		// dds_ctrl_o output.
		assign dds_ctrl_o[i*72 +: 72]	= {7'h00,sync_reg_r4,phase_v1_r1[i],pinc_N_r3};
	end
endgenerate

// load_int.
assign load_int 	= rd_en_int & ~fifo_empty_i;

// Assign outputs.
assign fifo_rd_en_o	= rd_en_int;
assign outsel_o		= outsel_r4;

endmodule

