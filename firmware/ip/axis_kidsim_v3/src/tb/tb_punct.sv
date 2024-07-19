module tb();

// Reset and clock.
reg 		rstn		;
reg 		clk			;

// Input data.
reg			din_valid	;
reg			din_last	;

// Output data.
wire		dout_valid	;
wire		dout_last	;
wire		dout_en		;

// Registers.
reg  [15:0]	ID_REG		;

// DUT.
punct
	DUT
	(
		// Reset and clock.
		.rstn		,
		.clk		,

		// Input data.
		.din_valid	,
		.din_last	,

		// Output data.
		.dout_valid	,
		.dout_last	,
		.dout_en	,

		// Registers.
		.ID_REG
	);

// Main TB.
initial begin
	int n;

	rstn		<= 0;
	ID_REG		<= 330;
	din_valid	<= 0;
	din_last	<= 0;
	#300;
	rstn		<= 1;

	n = 0;
	while (1) begin
		for (int i=0; i<33; i=i+1) begin
			@(posedge clk);
			din_valid	<= 1;	
			din_last	<= 0;
		end
		for (int i=0; i<3; i=i+1) begin
			@(posedge clk);
			din_valid	<= 0;	
			din_last	<= 0;
		end
		for (int i=0; i<23; i=i+1) begin
			@(posedge clk);
			din_valid	<= 1;	
			din_last	<= 0;
		end
		for (int i=0; i<9; i=i+1) begin
			@(posedge clk);
			din_valid	<= 0;	
			din_last	<= 0;
		end
		for (int i=0; i<43; i=i+1) begin
			@(posedge clk);
			din_valid	<= 1;	
			din_last	<= 0;
		end
		@(posedge clk);
		din_valid	<= 1;
		din_last	<= 1;
	end
end

always begin
	clk <= 0;
	#5;
	clk <= 1;
	#5;
end  

endmodule

