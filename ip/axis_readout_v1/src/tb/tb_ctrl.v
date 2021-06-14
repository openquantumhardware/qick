module tb();

// Number of parallel dds blocks.
parameter N_DDS = 4;

// Ports.
reg				rstn;
reg				clk;
wire			fifo_rd_en_o;
reg				fifo_empty_i;
wire	[17:0]	fifo_dout_i;
wire 	[N_DDS*40-1:0]	dds_ctrl_o;
wire	[1:0]	outsel_o;

// Fifo Dout Fields.
reg		[15:0]	freq_r;
reg		[1:0]	outsel_r;

// Assignment of DDSs for debugging.
wire	[39:0]	dds_ctrl_ii [0:N_DDS-1];

integer i;

generate
genvar ii;
for (ii = 0; ii < N_DDS; ii = ii + 1) begin : GEN_debug
    assign dds_ctrl_ii[ii] = dds_ctrl_o[40*ii +: 40];
end
endgenerate

// DUT.
ctrl 
	#(
		.N_DDS	(N_DDS	)
	)
	DUT
	(
		// Reset and clock.
		.rstn			(rstn			),
		.clk			(clk			),

		// Fifo interface.
		.fifo_rd_en_o	(fifo_rd_en_o	),
		.fifo_empty_i	(fifo_empty_i	),
		.fifo_dout_i	(fifo_dout_i	),

		// dds control.
		.dds_ctrl_o		(dds_ctrl_o		),

		// Output source selection.
		.outsel_o		(outsel_o		)
		);

assign fifo_dout_i = {outsel_r,freq_r};

initial begin
	rstn			<= 0;
	fifo_empty_i	<= 1;
	freq_r			<= 0;
	outsel_r		<= 0;
	#200;
	rstn			<= 1;

	#200;

	@(posedge clk);
	fifo_empty_i	<= 0;

	@(posedge clk);
	fifo_empty_i	<= 1;
	freq_r			<= 100;
	outsel_r		<= 2;

	#220;

	//@(posedge clk);
	//fifo_empty_i	<= 0;

	//wait (fifo_rd_en_o);

	//@(posedge clk);
	//fifo_empty_i	<= 1;
	//freq_r			<= 3516;
	//phase_r			<= 2345;
	//gain_r			<= 4;
	//nsamp_r			<= 5;
	//outsel_r		<= 1;
	//mode_r			<= 0;
	#10000;
	
end

always begin
	clk <= 0;
	#10;
	clk <= 1;
	#10;
end

endmodule

