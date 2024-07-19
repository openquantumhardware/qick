// This block implements a linear function. When the trigger
// is received, the block starts creating a function like:
// 
// y = -m*n + b
// 
// where M_REG is the slope and B_REG the starting value. The
// number of n steps is given by N_REG. One step is taken every
// W_REG cycles.
// Once the function is completed, the output goes to 0.
module mod_ctrl
	#(
		parameter B = 8
	)
	(
		// Reset and clock.
		input 	wire 			rstn	,
		input 	wire 			clk		,
	
		// Trigger.
		input 	wire			trigger	,

		// Enable.
		input	wire			en		,

		// Modulation Output.
		output 	wire [B-1:0]	y		,

		// Registers.
		input	wire [B-1:0]	B_REG	,
		input	wire [B-1:0]	M_REG	,
		input	wire [B-1:0]	N_REG	,
		input	wire [B-1:0]	W_REG
	);

/*************/
/* Internals */
/*************/

// States.
typedef enum	{	INIT_ST	,
					CNT_ST	,
					WAIT_ST	,
					END_ST
				} state_t;

// State register.
(* fsm_encoding = "one_hot" *) state_t state;

reg		init_state		;
reg		cnt_state		;
reg		wait_state		;
reg		end_state		;

// Re-synced signals.
wire	trigger_resync	;

// Registers.
reg	signed	[B-1:0]	B_REG_r	;
reg	signed	[B-1:0]	M_REG_r	;
reg			[B-1:0]	N_REG_r	;
reg			[B-1:0]	W_REG_r	;

// Counter.
reg	    	[B-1:0]	cnt		;

// Wait counter.
reg			[B-1:0]	wcnt	;

// B.
wire signed [B-1:0]	bs		;
reg			[B-1:0]	bs_r	;

// M.
wire signed	[B-1:0]	ms		;
reg	 signed	[B-1:0]	ms_r	;

/****************/
/* Architecture */
/****************/

// trigger_resync.
synchronizer_n trigger_resync_i
	(
		.rstn	    (rstn			),
		.clk 		(clk			),
		.data_in	(trigger		),
		.data_out	(trigger_resync	)
	);

// B.
assign bs = B_REG_r - ms_r;

// M.
assign ms = M_REG_r + ms_r;

// Registers.
always @(posedge clk) begin
	if (rstn == 1'b0) begin
		// State register.
		state 	<= INIT_ST;

		// Registers.
		B_REG_r	<= 0;
		M_REG_r	<= 0;
		N_REG_r	<= 0;
		W_REG_r	<= 0;

		// Counter.
		cnt		<= 0;

		// Wait counter.
		wcnt	<= 0;

		// B.
		bs_r	<= 0;
		
		// M.
		ms_r	<= 0;
	end
	else begin
		// State register.
		case (state)
			INIT_ST:
				if (trigger_resync == 1'b1)
					state <= CNT_ST;

			CNT_ST:
				if ( en == 1'b1) begin
					if (cnt == N_REG_r)
						state <= END_ST;
					else if (W_REG_r != '0)
						state <= WAIT_ST;
				end

			WAIT_ST:
				if ( en == 1'b1 ) begin
					if (wcnt == W_REG_r-1)
						state <= CNT_ST;
				end

			END_ST:
				if (trigger_resync == 1'b0)
					state <= INIT_ST;
		endcase

		// Registers.
		if ( init_state == 1'b1) begin
			B_REG_r	<= B_REG	;
			M_REG_r	<= M_REG	;
			N_REG_r	<= N_REG	;
			W_REG_r	<= W_REG	;
		end

		// Counter.
		if ( init_state == 1'b1 ) begin
			cnt	<= 0;
		end
		else if ( cnt_state == 1'b1 ) begin
			if (en == 1'b1) begin
				cnt <= cnt + 1;
			end
		end

		// Wait counter.
		if ( wait_state == 1'b1 ) begin
			if (en == 1'b1) begin
				wcnt <= wcnt + 1;
			end
		end
		else begin
			wcnt <= 0;
		end

		if ( init_state == 1'b1 ) begin
			// B.
			bs_r <= 0;

			// M.
			ms_r <= 0;
		end
		else if ( (cnt_state == 1'b1) && (en == 1'b1) ) begin
			// B.
			bs_r <= bs;

			// M.
			ms_r <= ms;
		end
	end
end

// FSM outputs.
always_comb	begin
	// Default.
	init_state	= 0;
	cnt_state	= 0;
	wait_state	= 0;
	end_state	= 0;

	case (state)
		INIT_ST:
			init_state 	= 1'b1;

		CNT_ST:
			cnt_state 	= 1'b1;

		WAIT_ST:
			wait_state	= 1'b1;

		END_ST:
			end_state	= 1'b1;
	endcase
end

// Assign outputs.
assign y = (init_state == 1'b1 || end_state == 1'b1)? 0 : bs_r;

endmodule

