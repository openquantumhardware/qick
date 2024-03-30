module tb();

// Reset and clock.
reg 			aclk		;

// Input valid.
reg				din_valid	;

// Output data.
wire			dout_valid	;
wire	[31:0]	dout		;

// Registers.
reg		[31:0]	PINC_REG	;
reg		[31:0]	POFF_REG	;

/**************/
/* Test Bench */
/**************/
wire	[15:0]	dout_real	;
wire	[15:0]	dout_imag	;

/****************/
/* Architecture */
/****************/

assign dout_real = dout[15:0];
assign dout_imag = dout[31:16];

// DUT.
dds_top DUT
	(
		// Reset and clock.
		.aclk		,

		// Input valid.
		.din_valid	,

		// Output data.
		.dout_valid	,
		.dout		,

		// Registers.
		.PINC_REG	,
		.POFF_REG
	);

// PINC/POFF.
initial begin
	PINC_REG <= 12345959;
	POFF_REG <= 4567;

	#1000;
end

// din_valid.
initial begin
	din_valid <= 0;
	while (1) begin
		for (int i=0; i<10; i=i+1) begin
			@(posedge aclk);
			din_valid <= 0;
		end
		@(posedge aclk);
		din_valid <= 1;
	end
end

always begin
	aclk <= 0;
	#8;
	aclk <= 1;
	#8;
end  

endmodule

