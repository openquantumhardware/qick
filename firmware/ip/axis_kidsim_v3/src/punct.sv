module punct
	(
		// Reset and clock.
		input 	wire 		rstn		,
		input 	wire 		clk			,

		// Input data.
		input	wire		din_valid	,
		input	wire		din_last	,

		// Output data.
		output	wire		dout_valid	,
		output 	wire		dout_last	,
		output	wire		dout_en		,

		// Registers.
		input	wire [15:0]	ID_REG
	);

/*************/
/* Internals */
/*************/;

// Pipeline registers.
reg				valid_r1	;
reg				valid_r2	;
reg				last_r1		;
reg				last_r2		;

// Counter.
reg		[15:0]	cnt			;

// Flag.
wire			flag		;

// Registers.
reg 	[15:0]	ID_REG_r	;

/****************/
/* Architecture */
/****************/

// Flag.
assign flag = (ID_REG_r == cnt);

always @(posedge clk) begin
	if (~rstn) begin
		// Pipeline registers.
		valid_r1	<= 0;
		valid_r2	<= 0;
		last_r1		<= 0;
		last_r2		<= 0;

		// Counter.
		cnt			<= 0;

		// Registers.
		ID_REG_r	<= 0;
	end
	else begin
		// Pipeline registers.
		valid_r1	<= din_valid;
		valid_r2	<= valid_r1;
		last_r1		<= din_last;
		last_r2		<= last_r1;

		// Counter.
		if ( valid_r2 == 1'b1 )
			if ( last_r2 == 1'b1 )
				cnt	<= 0;
			else
				cnt <= cnt + 1;

		// Registers.
		ID_REG_r	<= ID_REG;

	end
end

// Assign outputs.
assign dout_valid 	= valid_r2;
assign dout_last	= last_r2;
assign dout_en		= flag;


endmodule
