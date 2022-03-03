//Format of waveform interface:
// |----------|---------|
// | 39 .. 32 | 31 .. 0 |
// |----------|---------|
// |     mask |   nsamp |
// |----------|---------|
// nsamp 	: 32 bits
// mask 	: 8 bits
//
// Total	: 40.
module ctrl (
	// Reset and clock.
	rstn			,
	clk				,

	// Fifo interface.
	fifo_rd_en_o	,
	fifo_empty_i	,
	fifo_dout_i		,

	// Mask output.
	mask_o			,

	// Output enable.
	en_o			);

// Ports.
input					rstn;
input					clk;
output					fifo_rd_en_o;
input					fifo_empty_i;
input	[39:0]			fifo_dout_i;
output	[7:0]			mask_o;
output					en_o;

// States.
typedef enum	{	READ_ST	,
					CNT_ST
				} state_t;

// State register.
(* fsm_encoding = "one_hot" *) state_t state;

reg				rd_en_int;

// Fifo dout register.
reg		[39:0]	fifo_dout_r;

// Number of samples.
wire	[31:0]	nsamp_int;

// Mask.
wire	[7:0]	mask_int;
wire	[7:0]	mask_la;

// Counter.
reg		[31:0]	cnt;

// Output enable register.
reg				en_reg;
wire			en_reg_la;

// Load register.
reg             load_r;

// Latency for mask.
latency_reg
	#(
		.N(2),
		.B(8)
	)
	mask_latency_reg_i
	(
		.rstn	(rstn		),
		.clk	(clk		),

		.din	(mask_int	),
		.dout	(mask_la	)
	);

// Latency for en_reg.
latency_reg
	#(
		.N(3),
		.B(1)
	)
	en_reg_latency_reg_i
	(
		.rstn	(rstn		),
		.clk	(clk		),

		.din	(en_reg		),
		.dout	(en_reg_la	)
	);


// Registers.
always @(posedge clk) begin
	if (~rstn) begin
		// State register.
		state 			<= READ_ST;

		// Fifo dout register.
		fifo_dout_r		<= 0;

		// Counter.
		cnt				<= 0;

		// Output enable register.
		en_reg			<= 0;
		
        // Load enable flag.
        load_r          <= 0;		
	end
	else begin
		// State register.
		case (state)
			READ_ST:
				if (~fifo_empty_i)
					state <= CNT_ST;
			CNT_ST:
				if ( cnt == nsamp_int-2 )
					state <= READ_ST;
		endcase

		// Fifo dout register.
		if (load_r)
			fifo_dout_r	<= fifo_dout_i;

		// Load enable flag.
		load_r			<= load_int;

		// Counter.
		if (rd_en_int)
			cnt	<= 0;
		else
			cnt <= cnt + 1;

		// Output enable register.
		if (rd_en_int)
 			if (!fifo_empty_i)
			en_reg <= 1;	
		else
			en_reg <= 0;
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
assign nsamp_int	= fifo_dout_r[31:0];
assign mask_int		= fifo_dout_r[39:32];

// load_int.
assign load_int 	= rd_en_int & ~fifo_empty_i;

// Assign outputs.
assign fifo_rd_en_o	= rd_en_int;
assign mask_o		= mask_la;
assign en_o			= en_reg_la;

endmodule

