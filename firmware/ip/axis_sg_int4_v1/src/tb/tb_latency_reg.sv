module tb_();

// Parameters.
parameter N = 11;	// Latency.
parameter B = 1;	// Data width.

// Ports.
reg 			rstn;
reg 			clk;
reg		[B-1:0]	din;
wire	[B-1:0]	dout;

latency_reg
	#(
		.N(N),
		.B(B)
	)
	dut
	(
		.rstn	(rstn	),
		.clk	(clk	),

		.din	(din	),
		.dout	(dout	)
	);

// Main TB.
initial begin
	rstn	<= 0;
	#200;
	rstn	<= 1;

	#500;

	for (int i=0; i<111; i=i+1) begin
		@(posedge clk);
		din	<= i;
	end
end

// aclk.
always begin
	clk <= 0;
	#5;
	clk <= 1;
	#5;
end

endmodule

