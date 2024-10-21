// Data is I,Q.
// I: lower B bits.
// Q: upper B bits.
module buffer (
	// Reset and clock.
	rstn		,
	clk			,

	// Trigger input.
	trigger_i	,

	// Data input.
	din_valid_i	,
	din_i		,

	// Memory interface.
	mem_we_o	,
	mem_addr_o	,
	mem_di_o	,

	// Registers.
	START_REG	,
	ADDR_REG	,
	LEN_REG
	);

////////////////
// Parameters //
////////////////
// Memory depth.
parameter N = 10;

// Number of bits.
parameter B = 16;

///////////
// Ports //
///////////
input				rstn;
input				clk;

input				trigger_i;

input				din_valid_i;
input	[2*B-1:0]	din_i;

output				mem_we_o;
output	[N-1:0]		mem_addr_o;
output 	[2*B-1:0]	mem_di_o;

input				START_REG;
input	[N-1:0]		ADDR_REG;
input	[N-1:0]		LEN_REG;

//////////////////////
// Internal signals //
//////////////////////
// States.
typedef enum	{	INIT_ST			,
					START_ST		,
					TRIGGER_ST		,
					MEMW_ST			,
					WAIT_TRIGGER_ST
				} state_t;

// State register.
(* fsm_encoding = "one_hot" *) state_t state;

reg			start_state;
reg			trigger_state;
reg			memw_state;

// Counter.
reg			[N-1:0]		cnt;

// Registers.
reg			[N-1:0]		addr_r;
reg			[N-1:0]		len_r;

//////////////////
// Architecture //
//////////////////

// Registers.
always @(posedge clk) begin
	if (~rstn) begin
		// State register.
		state 	<= INIT_ST;

		// Counter.
		cnt		<= 0;

		// Registers.
		addr_r	<= 0;
		len_r	<= 0;
	end
	else begin
		// State register.
		case (state)
			INIT_ST:
				state <= START_ST;

			START_ST:
				if ( START_REG == 1'b1)
					state <= TRIGGER_ST;

			TRIGGER_ST:
				if ( START_REG == 1'b0 ) 
					state <= START_ST;
				else if ( trigger_i == 1'b1 )
					state <= MEMW_ST;

			MEMW_ST:
				if ( cnt == len_r-1 && din_valid_i == 1'b1 )
					state <= WAIT_TRIGGER_ST;

			WAIT_TRIGGER_ST:
				if ( START_REG == 1'b0 )
					state <= START_ST;
				else if ( trigger_i == 1'b0 ) begin
					state <= TRIGGER_ST;
				end
		endcase

		// Counter.
		if ( memw_state == 1'b1 ) begin
			if (din_valid_i == 1'b1)
				cnt	<= cnt + 1;
		end
		else begin
			cnt <= 0;
		end

		// Registers.
		if ( start_state == 1'b1 ) begin
			addr_r	<= ADDR_REG;
			len_r	<= LEN_REG;
		end
		else if ( memw_state == 1'b1 && din_valid_i == 1'b1) begin
			addr_r	<= addr_r + 1;
		end
	end
end 

// FSM outputs.
always_comb	begin
	// Default.
	start_state		= 0;
	trigger_state	= 0;
	memw_state		= 0;

	case (state)
		//INIT_ST:

		START_ST:
			start_state		= 1'b1;

		TRIGGER_ST:
			trigger_state	= 1'b1;

		MEMW_ST:
			memw_state		= 1'b1;

		//WAIT_TRIGGER_ST:
	endcase
end

// Assign outputs.
assign mem_we_o		= memw_state & din_valid_i;
assign mem_addr_o	= addr_r;
assign mem_di_o		= din_i;

endmodule

