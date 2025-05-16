// Data is I,Q.
// I: lower B bits.
// Q: upper B bits.
module outreg (
	// Reset and clock.
	rstn			,
	clk				,

	// Data input.
	wen				,
	din				,

	// M_AXIS.
	m_axis_tdata	,
	m_axis_tready	,
	m_axis_tvalid
	);

////////////////
// Parameters //
////////////////
// Number of bits.
parameter B = 16;

///////////
// Ports //
///////////
input				rstn;
input				clk;

input				wen;
input	[B-1:0]		din;

output	[B-1:0]		m_axis_tdata;
input				m_axis_tready;
output				m_axis_tvalid;

//////////////////////
// Internal signals //
//////////////////////
// States.
typedef enum	{	WAIT_IN_ST		,
					READ_IN_ST		,
					WRITE_OUT_ST
				} state_t;

// State register.
(* fsm_encoding = "one_hot" *) state_t state;

// Data register.
reg	[B-1:0]	din_r;

reg			din_en_i;
reg			valid_i;

//////////////////
// Architecture //
//////////////////

// Registers.
always @(posedge clk) begin
	if (~rstn) begin
		// State register.
		state 	<= WAIT_IN_ST;

		// Data register.
		din_r	<= 0;
	end
	else begin
		// State register.
		case (state)
			WAIT_IN_ST:
				if ( wen == 1'b1)
					state <= READ_IN_ST;

			READ_IN_ST:
				if ( wen == 1'b0 ) 
					state <= WRITE_OUT_ST;

			WRITE_OUT_ST:
				if ( m_axis_tready == 1'b1 )
					state <= WAIT_IN_ST;
		endcase

		// Data register.
		if (din_en_i == 1'b1)
			din_r <= din;
	end
end 

// FSM outputs.
always_comb	begin
	// Default.
	din_en_i	= 0;
	valid_i		= 0;

	case (state)
		//WAIT_IN_ST:

		READ_IN_ST:
			din_en_i 	= 1'b1;

		WRITE_OUT_ST:
			valid_i		= 1'b1;
	endcase
end

// Assign outputs.
assign m_axis_tdata		= din_r;
assign m_axis_tvalid	= valid_i;

endmodule

