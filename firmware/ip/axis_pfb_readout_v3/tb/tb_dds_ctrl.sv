module tb();

// Reset and clock.
reg 			aclk		;

// Enable input.
reg				en			;

// Output data.
wire			dout_valid	;
wire	[71:0]	dout		;

// Registers.
reg		[31:0]	PINC_REG	;
reg		[31:0]	POFF_REG	;

/**************/
/* Test Bench */
/**************/

/****************/
/* Architecture */
/****************/

// DUT.
dds_ctrl DUT
	(
		// Reset and clock.
		.aclk		,

		// Enable input.
		.en			,

		// Output data.
		.dout_valid	,
		.dout		,

		// Registers.
		.PINC_REG	,
		.POFF_REG
	);

// PINC/POFF.
initial begin
	PINC_REG <= 1234;
	POFF_REG <= 4567;

	#1000;
end

// en.
initial begin
	en <= 0;
	while (1) begin
		for (int i=0; i<10; i=i+1) begin
			@(posedge aclk);
			en <= 0;
		end
		@(posedge aclk);
		en <= 1;
	end
end

always begin
	aclk <= 0;
	#8;
	aclk <= 1;
	#8;
end  

endmodule

