module tb();

// Data width.
localparam B = 32;

reg					clk;
reg					rstn;
reg	signed 	[B-1:0]	din_a;
reg	signed 	[B-1:0]	din_b;
reg			[3:0]	op;
wire				zero_a;
wire				zero_b;
wire signed	[B-1:0]	dout;

// DUT.
alu
    #(
        // Data width.
        .B(32)
    )
    DUT
	( 
		// Clock and reset.
        .clk    	(clk 		),
		.rstn		(rstn		),

		// Input operands.
		.din_a		(din_a		),
		.din_b		(din_b		),

		// Operation.
		.op			(op			),

		// Zero detection.
		.zero_a		(zero_a		),
		.zero_b		(zero_b		),

		// Output.
        .dout    	(dout		)
    );

initial begin
	// Reset sequence.
	rstn	<= 0;
	#1000;
	rstn	<= 1;
	
	// Addition.
	@(posedge clk);
	op	<= 4'b1000;
	din_a	<= 53;
	din_b	<= -38;

	@(posedge clk);
	din_a	<= 530;
	din_b	<= -3000;

	// Substraction.
	@(posedge clk);
	op	<= 4'b1001;
	din_a	<= 5830;
	din_b	<= 5830;

	// Product.
	@(posedge clk);
	op	<= 4'b1010;
	din_a	<= 5830;
	din_b	<= 8;

	#1000;
end

always
begin
	clk <= 0;
	#5;
	clk <= 1;
	#5;
end

endmodule

