//Format of waveform interface:
// |------------|-------|---------|------|------------|------------|------------|-----------|----------|----------|----------|---------|
// | 159 .. 149 |   148 |     147 |  146 | 145 .. 144 | 143 .. 128 | 127 .. 112 | 111 .. 96 | 95 .. 80 | 79 .. 64 | 63 .. 32 | 31 .. 0 |
// |------------|-------|---------|------|------------|------------|------------|-----------|----------|----------|----------|---------|
// |       xxxx | phrst | stdysel | mode |     outsel |      nsamp |       xxxx |      gain |     xxxx |     addr |    phase |    freq |
// |------------|-------|---------|------|------------|------------|------------|-----------|----------|----------|----------|---------|
// freq 	: 32 bits
// phase 	: 32 bits
// addr 	: 16 bits
// gain 	: 16 bits
// nsamp 	: 16 bits
// outsel 	: 2 bits
// mode 	: 1 bit
// stdysel 	: 1 bit
// phrst	: 1 bit
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

	// memory control.
	mem_addr_o		,

	// gain.
	gain_o			,

	// Output source selection.
	src_o			,

	// Steady value selection.
	stdy_o			,
	
	// Output enable.
	en_o			);

// Memory address size.
parameter N = 16;

// Number of parallel dds blocks.
parameter [31:0] N_DDS = 16;

// Ports.
input					rstn;
input					clk;
output					fifo_rd_en_o;
input					fifo_empty_i;
input	[159:0]			fifo_dout_i;
output 	[N_DDS*72-1:0]	dds_ctrl_o;
output	[N-1:0]			mem_addr_o;
output	[15:0]			gain_o;
output	[1:0]			src_o;
output					stdy_o;
output					en_o;

// States.
typedef enum	{	READ_ST	,
					CNT_ST
				} state_t;

// State register.
(* fsm_encoding = "one_hot" *) state_t state;

// Fifo dout register.
reg		[159:0]	fifo_dout_r;

// Non-stop counter for time calculation (adds N_DDS samples each clock tick).
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
wire	[31:0]	phase_v0 	[0:N_DDS-1];
reg		[31:0]	phase_v0_r1 [0:N_DDS-1];
reg		[31:0]	phase_v0_r2 [0:N_DDS-1];
reg		[31:0]	phase_v0_r3 [0:N_DDS-1];
reg		[31:0]	phase_v0_r4 [0:N_DDS-1];
wire	[31:0]	phase_v1 	[0:N_DDS-1];
reg		[31:0]	phase_v1_r1 [0:N_DDS-1];

// sync.
reg				sync_reg;
reg				sync_reg_r1;
reg				sync_reg_r2;
reg				sync_reg_r3;
reg				sync_reg_r4;
reg				sync_reg_r5;
reg				sync_reg_r6;
reg				sync_reg_r7;

// Address.
wire	[15:0]	addr_int;
reg		[15:0]	addr_cnt;
reg		[15:0]	addr_cnt_r1;
reg		[15:0]	addr_cnt_r2;
reg		[15:0]	addr_cnt_r3;
reg		[15:0]	addr_cnt_r4;
reg		[15:0]	addr_cnt_r5;
reg		[15:0]	addr_cnt_r6;

// Gain.
wire	[15:0]	gain_int;
reg		[15:0]	gain_r1;
reg		[15:0]	gain_r2;
reg		[15:0]	gain_r3;
reg		[15:0]	gain_r4;
reg		[15:0]	gain_r5;
reg		[15:0]	gain_r6;
reg		[15:0]	gain_r7;

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

// Steady value selection.
wire			stdysel_int;
reg				stdysel_r1;
reg				stdysel_r2;
reg				stdysel_r3;
reg				stdysel_r4;
reg				stdysel_r5;
reg				stdysel_r6;
reg				stdysel_r7;

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
reg				en_reg;
reg				en_reg_r1;
reg				en_reg_r2;
reg				en_reg_r3;
reg				en_reg_r4;
reg				en_reg_r5;
reg				en_reg_r6;
reg				en_reg_r7;
reg				en_reg_r8;

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

		// Address.
		addr_cnt		<= 0;
		addr_cnt_r1		<= 0;
		addr_cnt_r2		<= 0;
		addr_cnt_r3		<= 0;
		addr_cnt_r4		<= 0;
		addr_cnt_r5		<= 0;
		addr_cnt_r6		<= 0;

		// Gain.
		gain_r1			<= 0;
		gain_r2			<= 0;
		gain_r3			<= 0;
		gain_r4			<= 0;
		gain_r5			<= 0;
		gain_r6			<= 0;
		gain_r7			<= 0;

		// Output selection.
		outsel_r1		<= 0;
		outsel_r2		<= 0;
		outsel_r3		<= 0;
		outsel_r4		<= 0;
		outsel_r5		<= 0;
		outsel_r6		<= 0;
		outsel_r7		<= 0;

		// Steady value selection.
		stdysel_r1		<= 0;
		stdysel_r2		<= 0;
		stdysel_r3		<= 0;
		stdysel_r4		<= 0;
		stdysel_r5		<= 0;
		stdysel_r6		<= 0;
		stdysel_r7		<= 0;

		// Load enable flag.
		load_r			<= 0;

		// Fifo Read Enable.
		rd_en_r1		<= 0;
		rd_en_r2		<= 0;

		// Counter.
		cnt				<= 0;

		// Output enable register.
		en_reg			<= 0;
		en_reg_r1		<= 0;
		en_reg_r2		<= 0;
		en_reg_r3		<= 0;
		en_reg_r4		<= 0;
		en_reg_r5		<= 0;
		en_reg_r6		<= 0;
		en_reg_r7		<= 0;
		en_reg_r8		<= 0;
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
		if (sync_reg == 1'b1 && phrst_int == 1'b1)
			cnt_n <= 0;
		else
			cnt_n <= cnt_n + N_DDS;

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

		// Address.
		if (rd_en_r2)
			addr_cnt	<= addr_int;
		else
			addr_cnt	<= addr_cnt + 1;

		addr_cnt_r1		<= addr_cnt;
		addr_cnt_r2		<= addr_cnt_r1;
		addr_cnt_r3		<= addr_cnt_r2;
		addr_cnt_r4		<= addr_cnt_r3;
		addr_cnt_r5		<= addr_cnt_r4;
		addr_cnt_r6		<= addr_cnt_r5;

		// Gain.
		gain_r1			<= gain_int;
		gain_r2			<= gain_r1;
		gain_r3			<= gain_r2;
		gain_r4			<= gain_r3;
		gain_r5			<= gain_r4;
		gain_r6			<= gain_r5;
		gain_r7			<= gain_r6;

		// Output selection.
		outsel_r1		<= outsel_int;
		outsel_r2		<= outsel_r1;
		outsel_r3		<= outsel_r2;
		outsel_r4		<= outsel_r3;
		outsel_r5		<= outsel_r4;
		outsel_r6		<= outsel_r5;
		outsel_r7		<= outsel_r6;

		// Steady value selection.
		stdysel_r1		<= stdysel_int;
		stdysel_r2		<= stdysel_r1;
		stdysel_r3		<= stdysel_r2;
		stdysel_r4		<= stdysel_r3;
		stdysel_r5		<= stdysel_r4;
		stdysel_r6		<= stdysel_r5;
		stdysel_r7		<= stdysel_r6;

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
		if (~mode_int && rd_en_int)
			if (~fifo_empty_i)
				en_reg <= 1;	
			else
				en_reg <= 0;
			
		en_reg_r1		<= en_reg;
		en_reg_r2		<= en_reg_r1;
		en_reg_r3		<= en_reg_r2;
		en_reg_r4		<= en_reg_r3;
		en_reg_r5		<= en_reg_r4;
		en_reg_r6		<= en_reg_r5;
		en_reg_r7		<= en_reg_r6;
		en_reg_r8		<= en_reg_r7;
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
assign addr_int		= fifo_dout_r[79:64];
assign gain_int		= fifo_dout_r[111:96];
assign nsamp_int	= fifo_dout_r[143:128];
assign outsel_int	= fifo_dout_r[145:144];
assign mode_int		= fifo_dout_r[146];
assign stdysel_int	= fifo_dout_r[147];
assign phrst_int	= fifo_dout_r[148];

// Frequency calculation.
assign pinc_N		= pinc_r2*N_DDS;

// Phase calculation.
assign pinc_Nm		= pinc_r2*cnt_n_reg;
assign phase_0		= pinc_Nm_r3 + phase_r5;

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
		assign dds_ctrl_o[i*72 +: 72]	= {7'h00,sync_reg_r7,phase_v1_r1[i],pinc_N_r5};
	end
endgenerate

// load_int.
assign load_int 	= rd_en_int & ~fifo_empty_i;

// Assign outputs.
assign fifo_rd_en_o	= rd_en_int;
assign mem_addr_o	= addr_cnt_r6;
assign gain_o		= gain_r7;
assign src_o		= outsel_r7;
assign stdy_o		= stdysel_r7;
assign en_o			= en_reg_r8;

endmodule

