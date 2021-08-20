module tb();

// Define Behavioral or Post-Synthesis simulation.
`define SYNTH_SIMU

localparam N_DDS = 8;

// Ports.
reg						rstn;
reg						clk;

wire					fifo_rd_en_o;
reg						fifo_empty_i;
wire	[15:0]			fifo_dout_i;

wire					s_axis_tready_o;
reg						s_axis_tvalid_i;
reg		[N_DDS*16-1:0]	s_axis_tdata_i;

reg						m0_axis_tready_i;
wire					m0_axis_tvalid_o;
wire	[N_DDS*32-1:0]	m0_axis_tdata_o;

reg						m1_axis_tready_i;
wire					m1_axis_tvalid_o;
wire	[32-1:0]		m1_axis_tdata_o;

reg		[1:0]			OUTSEL_REG;

// Fifo Dout Fields.
reg		[15:0]			freq_r;

// Assignment of data out for debugging.
wire	[31:0]			dout_ii [0:N_DDS-1];

// Test bench control.
reg tb_data_in		= 0;
reg tb_data_in_done	= 0;
reg	tb_write_out 	= 0;

generate
genvar ii;
for (ii = 0; ii < N_DDS; ii = ii + 1) begin : GEN_debug
    assign dout_ii[ii] = m0_axis_tdata_o[32*ii +: 32];
end
endgenerate

// DUT.
down_conversion_fir
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

		// M0_AXIS for output data (before filter and decimation).
		.m0_axis_tready_i	(m0_axis_tready_i	),
		.m0_axis_tvalid_o	(m0_axis_tvalid_o	),
		.m0_axis_tdata_o	(m0_axis_tdata_o	),

		// M1_AXIS for output data.
		.m1_axis_tready_i	(m1_axis_tready_i	),
		.m1_axis_tvalid_o	(m1_axis_tvalid_o	),
		.m1_axis_tdata_o	(m1_axis_tdata_o	),

		// Registers.
		.OUTSEL_REG			(OUTSEL_REG			)
		);

assign fifo_dout_i = freq_r;

initial begin
	rstn				<= 0;
	fifo_empty_i		<= 1;
	m0_axis_tready_i	<= 1;
	m1_axis_tready_i	<= 1;
	freq_r				<= 0;
	OUTSEL_REG			<= 0;
	#200;
	rstn				<= 1;

	#200;

	/////////////////////////////
	// Start Recording Outputs //
	/////////////////////////////
	tb_write_out	<= 1;

	/////////////////
	// Program DDS //
	/////////////////
	@(posedge clk);
	fifo_empty_i	<= 0;
	freq_r			<= freq_calc(100, N_DDS, 625);

	#220;

	@(posedge clk);
	fifo_empty_i	<= 1;

	/////////////////////
	// Send Input Data //
	/////////////////////
	@(posedge clk);
	tb_data_in		<= 1;

	wait (tb_data_in_done);

	#1000;

	////////////////////////////
	// Stop Recording Outputs //
	////////////////////////////
	tb_write_out	<= 0;

	#10000;
end

// Input data.
initial begin
	int fd, i;
	bit signed [15:0] vali, valq;

	tb_data_in_done		<= 0;
	s_axis_tvalid_i	<= 1;
	s_axis_tdata_i	<= 0;

	wait (tb_data_in);

	#1000;

	// Open file with input data.
	// Format: I, Q.
	`ifdef SYNTH_SIMU
		fd = $fopen("../../../../../../tb/data_iq.txt","r");
	`else
		fd = $fopen("../../../../../tb/data_iq.txt","r");
	`endif
	
	//i = N_DDS;
	i = 0;
	while ($fscanf(fd,"%d,%d", vali, valq) == 2) begin
		$display("Time %t: Line %d, I = %d, Q = %d", $time, i, vali, valq);		
		//s_axis_tdata_i[(i-1)*16 +: 16] <= vali;
		s_axis_tdata_i[i*16 +: 16] <= vali;
		//i = i - 1;
		i = i + 1;
		//if ( i == 0) begin
		if ( i == N_DDS) begin
			//i = N_DDS;
			i = 0;
			@(posedge clk);
		end
	end
	
	#1000;
	
	@(posedge clk);
	tb_data_in_done		<= 1;

end

// Write output into file.
initial begin
	int fd;
	int i;
	shortint real_d, imag_d;

	// Output file.
	`ifdef SYNTH_SIMU
		fd = $fopen("../../../../../../tb/dout_fs.csv","w");
	`else
		fd = $fopen("../../../../../tb/dout_fs.csv","w");
	`endif

	// Data format.
	$fdisplay(fd, "valid, idx, real, imag");

	wait (tb_write_out);

	while (tb_write_out) begin
		@(posedge clk);
		for (i=0; i<N_DDS; i = i+1) begin
			real_d = dout_ii[i][15:0];
			imag_d = dout_ii[i][31:16];
			$fdisplay(fd, "%d, %d, %d, %d", m0_axis_tvalid_o, i, real_d, imag_d);
		end
	end

	$display("Closing file, t = %0t", $time);
	$fclose(fd);
end

// Write output into file.
initial begin
	int fd;
	int i;
	shortint real_d, imag_d;

	// Output file.
	`ifdef SYNTH_SIMU
		fd = $fopen("../../../../../../tb/dout.csv","w");
	`else
		fd = $fopen("../../../../../tb/dout.csv","w");
	`endif

	// Data format.
	$fdisplay(fd, "valid, real, imag");

	wait (tb_write_out);

	while (tb_write_out) begin
		@(posedge clk);
		real_d = m1_axis_tdata_o[15:0];
		imag_d = m1_axis_tdata_o[31:16];
		$fdisplay(fd, "%d, %d, %d", m1_axis_tvalid_o, real_d, imag_d);
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

