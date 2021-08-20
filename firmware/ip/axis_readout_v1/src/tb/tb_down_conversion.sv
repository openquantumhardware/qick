module tb();

// Number of parallel dds blocks.
parameter N_DDS = 4;

// Ports.
reg						rstn;
reg						clk;

wire					fifo_rd_en_o;
reg						fifo_empty_i;
wire	[17:0]			fifo_dout_i;

wire					s_axis_tready_o;
reg						s_axis_tvalid_i;
reg		[N_DDS*16-1:0]	s_axis_tdata_i;

reg						m_axis_tready_i;
wire					m_axis_tvalid_o;
wire	[N_DDS*32-1:0]	m_axis_tdata_o;

// Fifo Dout Fields.
reg		[15:0]			freq_r;
reg		[1:0]			outsel_r;

// Assignment of data out for debugging.
wire	[31:0]			dout_ii [0:N_DDS-1];

// Test bench control.
reg	tb_write_out = 0;

generate
genvar ii;
for (ii = 0; ii < N_DDS; ii = ii + 1) begin : GEN_debug
    assign dout_ii[ii] = m_axis_tdata_o[32*ii +: 32];
end
endgenerate

// DUT.
down_conversion
	#(
		.N_DDS	(N_DDS	)
	)
	DUT
	(
		// Reset and clock.
		.rstn				(rstn				),
		.clk				(clk				),

		// Fifo interface.
		.fifo_rd_en_o		(fifo_rd_en_o		),
		.fifo_empty_i		(fifo_empty_i		),
		.fifo_dout_i		(fifo_dout_i		),

		// S_AXIS for input.
		.s_axis_tready_o	(s_axis_tready_o	),
		.s_axis_tvalid_i	(s_axis_tvalid_i	),
		.s_axis_tdata_i		(s_axis_tdata_i		),

		// M_AXIS for output.
		.m_axis_tready_i	(m_axis_tready_i	),
		.m_axis_tvalid_o	(m_axis_tvalid_o	),
		.m_axis_tdata_o		(m_axis_tdata_o		)
		);

assign fifo_dout_i = {outsel_r,freq_r};

initial begin
	rstn			<= 0;
	fifo_empty_i	<= 1;
	m_axis_tready_i	<= 1;
	freq_r			<= 0;
	outsel_r		<= 0;
	#200;
	rstn			<= 1;

	#200;

	tb_write_out	<= 1;

	@(posedge clk);
	fifo_empty_i	<= 0;

	@(posedge clk);
	fifo_empty_i	<= 1;
	freq_r			<= freq_calc(100, N_DDS, 18);	// 120 MHz.
	outsel_r		<= 0;

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
	//outsel_r		<= 0;
	//mode_r			<= 0;

	#10000

	tb_write_out	<= 0;

	#10000;
end

// Input data.
initial begin
	s_axis_tvalid_i	<= 0;
	s_axis_tdata_i	<= 0;

	for (int i=0; i<N_DDS; i = i+1) begin
		s_axis_tdata_i[i*16 +: 16] <= 16'd30000;
	end

end

// Write output into file.
initial begin
	int fd;
	int i;
	shortint real_d, imag_d;

	// Output file.
	fd = $fopen("../../../../../tb/dout.csv","w");

	// Data format.
	$fdisplay(fd, "valid, idx, real, imag");

	wait (tb_write_out);

	while (tb_write_out) begin
		@(posedge clk);
		for (i=0; i<N_DDS; i = i+1) begin
			real_d = dout_ii[i][15:0];
			imag_d = dout_ii[i][31:16];
			$fdisplay(fd, "%d, %d, %d, %d", m_axis_tvalid_o, i, real_d, imag_d);
		end
	end

	$display("Closing file, t = %0t", $time);
	$fclose(fd);
end

always begin
	clk <= 0;
	#5;
	clk <= 1;
	#5;
end

// Function to compute frequency register.
function bit [15:0] freq_calc (int fclk, int ndds, int f);
	// All input frequencies are in MHz.
	real fs,temp;
	fs = fclk*ndds;
	temp = f/fs*2**16;
	return int'(temp);
endfunction

endmodule

