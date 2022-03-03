module tb();

reg			rstn;
reg			clk;

wire		fifo_rd_en_o;
reg			fifo_empty_i;
wire[39:0]	fifo_dout_i;

wire[7:0]	mask_o;

wire		en_o;

// Fifo fields.
reg	[31:0]	nsamp_r;
reg	[7:0]	mask_r;

assign fifo_dout_i = {mask_r,nsamp_r};

// DUT.
ctrl DUT	
 	(
		// Reset and clock.
		.rstn			(rstn			),
		.clk			(clk			),

		// Fifo interface.
		.fifo_rd_en_o	(fifo_rd_en_o	),
		.fifo_empty_i	(fifo_empty_i	),
		.fifo_dout_i	(fifo_dout_i	),

		// Mask output.
		.mask_o			(mask_o			),

		// Output enable.
		.en_o			(en_o			)
	);

initial begin
	// Reset sequence.
	rstn			<= 0;
	fifo_empty_i	<= 1'b1;
	nsamp_r			<= 0;
	mask_r			<= 0;
	#500;
	rstn 	<= 1;

	#1000;
	
	@(posedge clk);
	nsamp_r	<= 12;
	mask_r	<= 8'b0010_1110;
	fifo_empty_i	<= 1'b0;

	@(posedge clk);
	@(posedge clk);
	@(posedge clk);
	nsamp_r	<= 7;
	mask_r	<= 8'b0000_0011;

	wait (fifo_rd_en_o);

	@(posedge clk);
	fifo_empty_i	<= 1'b1;
end

always begin
	clk <= 0;
	#5;
	clk <= 1;
	#5;
end  

endmodule

