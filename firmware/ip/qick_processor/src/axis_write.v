module axis_write (
	// Reset and clock.
	aclk_i			,
	aresetn_i		,

	// AXIS Slave for receiving data.
	s_axis_tdata_i	,
	s_axis_tlast_i	,
	s_axis_tvalid_i	,
	s_axis_tready_o	,

	// Memory interface.
	mem_we_o		,
	mem_di_o		,
	mem_addr_o		,

	// Handshake.
	exec_i			,
	exec_ack_o		,

	// Start address.
	addr_i			
);

// Parameters.
parameter	N = 10;	// Memory depth (2**N).
parameter 	B = 16; // Memory width.

// Ports.
input			aclk_i;
input 			aresetn_i;
input 	[B-1:0]	s_axis_tdata_i;
input			s_axis_tlast_i;
input			s_axis_tvalid_i;
output			s_axis_tready_o;
output 			mem_we_o;
output 	[B-1:0]	mem_di_o;
output 	[N-1:0]	mem_addr_o;
input			exec_i;
output			exec_ack_o;
input	[N-1:0]	addr_i;

// States.
localparam	INIT_ST		= 0;
localparam	WRITE_ST	= 1;
localparam	ACK_ST		= 2;
localparam	END_ST		= 3;

// State register.
reg		[1:0]	state;

// State flags.
reg				init_state;
reg				write_state;
reg				ack_int;

// Address generation.
reg 	[N-1:0] addr_cnt;
reg 	[N-1:0] addr_cnt_r;

// Data.
reg		[B-1:0]	data_r;

// we generation.
wire			we_int;
reg				we_int_r;

// Registers.
always @(posedge aclk_i) begin
	if (~aresetn_i) begin
		// State register.
		state	<= INIT_ST;

		// Address generation.
		addr_cnt	<= 0;
		addr_cnt_r	<= 0;
		
		// Data.
		data_r		<= 0;
		
		// we generation.
		we_int_r		<= 0;
	end
	else begin
		// State register.
		case(state)
			INIT_ST:
				if (exec_i == 1'b1)
					state <= WRITE_ST;

			WRITE_ST:
				if (s_axis_tlast_i && s_axis_tvalid_i)
					state <= ACK_ST;

			ACK_ST:
				state <= END_ST;	

			END_ST:
				if (exec_i == 1'b0)
					state <= INIT_ST;
		endcase
		// Address generation.
		if (init_state)
			addr_cnt	<= addr_i;
		else if (s_axis_tvalid_i)
			addr_cnt	<= addr_cnt + 1;

		addr_cnt_r	<= addr_cnt;
		
		// Data.
		data_r		<= s_axis_tdata_i;
		
		// we generation.
		we_int_r	<= we_int;

	end
end 

// FSM outputs.
always @(state) begin
	// Default.
	init_state	= 0;
	write_state = 0;
	ack_int		= 0;

	case (state)
		INIT_ST:
			init_state	= 1;

		WRITE_ST:
			write_state = 1;

		ACK_ST:
			ack_int		= 1;

		//END_ST:
	endcase
end

// we generation.
assign we_int = s_axis_tvalid_i & write_state;

// Assign outputs.
assign s_axis_tready_o 	= write_state;
assign mem_we_o			= we_int_r;
assign mem_di_o			= data_r;
assign mem_addr_o		  = addr_cnt_r;
assign exec_ack_o		  = ack_int;

endmodule

