module tdm_demux
	#(
		parameter NCH 	= 16,
		parameter B		= 8
	)
	(
		// Reset and clock.
		input				rstn		,
		input				clk			,

		// Resync.
		input				sync		,

		// Data input.
		input [B-1:0]		din			,
		input				din_last	,
		input				din_valid	,

		// Data output.
		output[NCH*B-1:0]	dout		,
		output				dout_valid
	);

/*************/
/* Internals */
/*************/
// States.
typedef enum	{	SYNC_ST	,
					RUN_ST
				} state_t;

// State register.
(* fsm_encoding = "one_hot" *) state_t state;

// Channel counter.
reg [9:0]	cnt_ch;
reg			cnt_rst;

// Data input registers.
reg	[B-1:0]	din_r [0:NCH-1];
reg			valid_r;

/****************/
/* Architecture */
/****************/
genvar i;
generate
	for (i=0; i<NCH; i=i+1) begin
		always @(posedge clk) begin
			if (rstn == 1'b0) begin
				// Data input registers.
				din_r[i] <= 0;
			end
			else begin
				// Data input registers.
				if (cnt_ch == i)
					if (din_valid == 1'b1)
						din_r[i] <= din;
			end
		end

	// Assign outputs.
	assign dout[i*B +: B] = din_r[i];

	end
endgenerate

always @(posedge clk) begin
	if (rstn == 1'b0) begin
		// State register.
		state 		<= SYNC_ST;

		// Channel counter.
		cnt_ch	<= 0;

		// Data input registers.
		valid_r	<= 0;
	end
	else begin
		// State register.
		case (state)
			SYNC_ST:
				if (din_last == 1'b1)
					state <= RUN_ST;

			RUN_ST:
				if (sync == 1'b1)
					state <= SYNC_ST;
		endcase

		// Channel counter.
		if (cnt_rst == 1'b1 || cnt_ch == NCH-1)
			cnt_ch	<= 0;
		else
			cnt_ch <= cnt_ch + 1;

		// Data input registers.
		valid_r	<= din_valid;
	end
end

// FSM outputs.
always_comb	begin
	// Default.
	cnt_rst		= 0;

	case (state)
		SYNC_ST:
			cnt_rst		= 1'b1;

		//RUN_ST:
	endcase
end
// Assign outputs.
assign dout_valid	= valid_r;

endmodule

