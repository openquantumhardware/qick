//Format of waveform interface:
// |----------|-------|------|----------|----------|----------|---------|
// | 87 .. 84 |    83 |   82 | 81 .. 80 | 79 .. 64 | 63 .. 32 | 31 .. 0 |
// |----------|-------|------|----------|----------|----------|---------|
// |     xxxx | phrst | mode |   outsel |    nsamp |    phase |    freq |
// |----------|-------|------|----------|----------|----------|---------|
// freq 	: 32 bits
// phase 	: 32 bits
// nsamp 	: 16 bits
// outsel 	: 2 bits
// mode 	: 1 bit
// phrst	: 1 bit
module ctrl 
	#(
		parameter N = 4
	)
	(
		// Reset and clock.
		input	wire				aresetn		,
		input	wire				aclk		,

		// Fifo interface.
		output	wire				fifo_rd_en	,
		input	wire				fifo_empty	,
		input	wire	[87:0]		fifo_dout	,

		// dds control.
		output 	wire	[N*72-1:0]	dds_ctrl	,

		// Output source selection.
		output	wire	[1:0]		outsel
	
		// Output enable.
//		output	wire				en
	);

// States.
typedef enum	{	READ_ST	,
					CNT_ST
				} state_t;

// State register.
(* fsm_encoding = "one_hot" *) state_t state;

// Fifo dout register.
reg		[87:0]	fifo_dout_r;

// Non-stop counter for time calculation (adds N samples each clock tick).
reg		[31:0]	cnt_n;
reg		[31:0]	cnt_n_reg;

// Pinc/phase.
wire	[31:0]	pinc_int;
reg		[31:0]	pinc_r1;
reg		[31:0]	pinc_r2;
wire	[31:0]	pinc_N;
reg		[31:0]	pinc_N_r1;
reg		[31:0]	pinc_N_r2;
reg		[31:0]	pinc_N_r3;
reg		[31:0]	pinc_N_r4;
reg		[31:0]	pinc_N_r5;
wire	[31:0]	pinc_Nm;
reg		[31:0]	pinc_Nm_r1;
reg		[31:0]	pinc_Nm_r2;
reg		[31:0]	pinc_Nm_r3;

wire	[31:0]	phase_int;
reg		[31:0]	phase_r1; 
reg		[31:0]	phase_r2; 
reg		[31:0]	phase_r3; 
reg		[31:0]	phase_r4; 
reg		[31:0]	phase_r5; 
wire	[31:0]	phase_0;
reg		[31:0]	phase_0_r1;

// Phase vectors.
wire	[31:0]	phase_v0 	[N];
reg		[31:0]	phase_v0_r1 [N];
reg		[31:0]	phase_v0_r2 [N];
reg		[31:0]	phase_v0_r3 [N];
reg		[31:0]	phase_v0_r4 [N];
wire	[31:0]	phase_v1 	[N];
reg		[31:0]	phase_v1_r1 [N];

// sync.
reg				sync_reg;
reg				sync_reg_r1;
reg				sync_reg_r2;
reg				sync_reg_r3;
reg				sync_reg_r4;
reg				sync_reg_r5;
reg				sync_reg_r6;
reg				sync_reg_r7;

// Number of samples.
wire	[15:0]	nsamp_int;

// Output selection.
wire	[1:0]	outsel_int;
reg		[1:0]	outsel_r1;
reg		[1:0]	outsel_r2;
reg		[1:0]	outsel_r3;
reg		[1:0]	outsel_r4;
reg		[1:0]	outsel_r5;
reg		[1:0]	outsel_r6;
reg		[1:0]	outsel_r7;

// Mode.
wire			mode_int;

// Phase reset.
wire			phrst_int;

// Load enable flag.
wire			load_int;
reg				load_r;

// Fifo Read Enable.
reg			    rd_en_int;
reg				rd_en_r1;
reg				rd_en_r2;

// Counter.
reg		[31:0]	cnt;

// Output enable register.
//reg				en_reg;
//reg				en_reg_r1;
//reg				en_reg_r2;
//reg				en_reg_r3;
//reg				en_reg_r4;
//reg				en_reg_r5;
//reg				en_reg_r6;
//reg				en_reg_r7;
//reg				en_reg_r8;

// Registers.
always @(posedge aclk) begin
	if (~aresetn) begin
		// State register.
		state 			<= READ_ST;

		// Fifo dout register.
		fifo_dout_r		<= 0;

		// Non-stop counter for time calculation.
		cnt_n			<= 0;
		cnt_n_reg		<= 0;

		// Pinc/phase/sync.
		pinc_r1			<= 0;
		pinc_r2			<= 0;
		pinc_N_r1		<= 0;
		pinc_N_r2		<= 0;
		pinc_N_r3		<= 0;
		pinc_N_r4		<= 0;
		pinc_N_r5		<= 0;
		pinc_Nm_r1		<= 0;
		pinc_Nm_r2		<= 0;
		pinc_Nm_r3		<= 0;

		phase_r1		<= 0;
		phase_r2		<= 0;
		phase_r3		<= 0;
		phase_r4		<= 0;
		phase_r5		<= 0;
		phase_0_r1		<= 0;

		sync_reg		<= 0;
		sync_reg_r1		<= 0;
		sync_reg_r2		<= 0;
		sync_reg_r3		<= 0;
		sync_reg_r4		<= 0;
		sync_reg_r5		<= 0;
		sync_reg_r6		<= 0;
		sync_reg_r7		<= 0;

		// Output selection.
		outsel_r1		<= 0;
		outsel_r2		<= 0;
		outsel_r3		<= 0;
		outsel_r4		<= 0;
		outsel_r5		<= 0;
		outsel_r6		<= 0;
		outsel_r7		<= 0;

		// Load enable flag.
		load_r			<= 0;

		// Fifo Read Enable.
		rd_en_r1		<= 0;
		rd_en_r2		<= 0;

		// Counter.
		cnt				<= 0;

		// Output enable register.
//		en_reg			<= 0;
//		en_reg_r1		<= 0;
//		en_reg_r2		<= 0;
//		en_reg_r3		<= 0;
//		en_reg_r4		<= 0;
//		en_reg_r5		<= 0;
//		en_reg_r6		<= 0;
//		en_reg_r7		<= 0;
//		en_reg_r8		<= 0;
	end
	else begin
		// State register.
		case (state)
			READ_ST:
				if (mode_int || ~fifo_empty)
					state <= CNT_ST;
			CNT_ST:
				if ( cnt == nsamp_int-2 )
					state <= READ_ST;
		endcase

		// Fifo dout register.
		if (load_r)
			fifo_dout_r	<= fifo_dout;

		// Non-stop counter for time calculation.
		if (sync_reg == 1'b1 && phrst_int == 1'b1)
			cnt_n <= 0;
		else
			cnt_n <= cnt_n + N;

		if (sync_reg_r1 == 1'b1)
			cnt_n_reg <= cnt_n;

		// Pinc/phase/sync.
		pinc_r1			<= pinc_int;
		pinc_r2			<= pinc_r1;
		pinc_N_r1		<= pinc_N;
		pinc_N_r2		<= pinc_N_r1;
		pinc_N_r3		<= pinc_N_r2;
		pinc_N_r4		<= pinc_N_r3;
		pinc_N_r5		<= pinc_N_r4;
		pinc_Nm_r1		<= pinc_Nm;
		pinc_Nm_r2		<= pinc_Nm_r1;
		pinc_Nm_r3		<= pinc_Nm_r2;

		phase_r1		<= phase_int;
		phase_r2		<= phase_r1;
		phase_r3		<= phase_r2;
		phase_r4		<= phase_r3;
		phase_r5		<= phase_r4;
		phase_0_r1		<= phase_0;

		sync_reg		<= load_r;
		sync_reg_r1		<= sync_reg;
		sync_reg_r2		<= sync_reg_r1;
		sync_reg_r3		<= sync_reg_r2;
		sync_reg_r4		<= sync_reg_r3;
		sync_reg_r5		<= sync_reg_r4;
		sync_reg_r6		<= sync_reg_r5;
		sync_reg_r7		<= sync_reg_r6;

		// Output selection.
		outsel_r1		<= outsel_int;
		outsel_r2		<= outsel_r1;
		outsel_r3		<= outsel_r2;
		outsel_r4		<= outsel_r3;
		outsel_r5		<= outsel_r4;
		outsel_r6		<= outsel_r5;
		outsel_r7		<= outsel_r6;

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

		// Output enable register.
//		if (~mode_int && rd_en_int)
//			if (~fifo_empty)
//				en_reg <= 1;	
//			else
//				en_reg <= 0;
			
//		en_reg_r1		<= en_reg;
//		en_reg_r2		<= en_reg_r1;
//		en_reg_r3		<= en_reg_r2;
//		en_reg_r4		<= en_reg_r3;
//		en_reg_r5		<= en_reg_r4;
//		en_reg_r6		<= en_reg_r5;
//		en_reg_r7		<= en_reg_r6;
//		en_reg_r8		<= en_reg_r7;
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
assign phrst_int	= fifo_dout_r[83];

// Frequency calculation.
assign pinc_N		= pinc_r2*N;

// Phase calculation.
assign pinc_Nm		= pinc_r2*cnt_n_reg;
assign phase_0		= pinc_Nm_r3 + phase_r5;

// Phase vectors.
generate
genvar i;
	for (i=0; i < N; i = i + 1) begin : GEN_phase
		// Registers.
		always @(posedge aclk) begin
			if (~aresetn) begin
				// v0.
				phase_v0_r1[i]	<= 0;	
				phase_v0_r2[i]	<= 0;	
				phase_v0_r3[i]	<= 0;	
				phase_v0_r4[i]	<= 0;	

				// v1.
				phase_v1_r1[i]	<= 0;
			end
			else begin
				// v0.
				phase_v0_r1[i] 	<= phase_v0[i];	
				phase_v0_r2[i] 	<= phase_v0_r1[i];	
				phase_v0_r3[i] 	<= phase_v0_r2[i];	
				phase_v0_r4[i] 	<= phase_v0_r3[i];	

				// v1.
				phase_v1_r1[i]	<= phase_v1[i];
			end
		end

		// v0.
		assign phase_v0[i] 		= pinc_r2*i;

		// v1.
		assign phase_v1[i] 		= phase_v0_r4[i] + phase_0_r1;

		// dds_ctrl_o output.
		assign dds_ctrl[i*72 +: 72]	= {7'h00,sync_reg_r7,phase_v1_r1[i],pinc_N_r5};
	end
endgenerate

// load_int.
assign load_int 	= rd_en_int & ~fifo_empty;

// Assign outputs.
assign fifo_rd_en	= rd_en_int;
assign outsel		= outsel_r7;
//assign en			= en_reg_r8;

endmodule

