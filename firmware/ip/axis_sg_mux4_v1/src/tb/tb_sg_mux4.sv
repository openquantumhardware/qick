module tb();

parameter N_DDS = 3;

reg					aresetn;
reg					aclk;

wire[39:0]			s_axis_tdata_i;
reg					s_axis_tvalid_i;
wire				s_axis_tready_o;

reg					m_axis_tready_i;
wire				m_axis_tvalid_o;
wire[N_DDS*32-1:0]	m_axis_tdata_o;

reg	[15:0]			PINC0_REG;
reg	[15:0]			PINC1_REG;
reg	[15:0]			PINC2_REG;
reg	[15:0]			PINC3_REG;
reg					WE_REG;

// Waveform fields.
reg	[31:0]			nsamp_r;
reg	[7:0]			mask_r;

// Assignment of data out for debugging.
wire[31:0]			dout_ii [0:N_DDS-1];

// TB control.
reg	tb_load_wave		= 0;
reg tb_load_wave_done	= 0;
reg	tb_write_out 		= 0;

// Waveform fields.
assign s_axis_tdata_i = {mask_r,nsamp_r};

// Debug.
generate
genvar ii;
for (ii = 0; ii < N_DDS; ii = ii + 1) begin : GEN_debug
    assign dout_ii[ii] = m_axis_tdata_o[32*ii +: 32];
end
endgenerate

// DUT.
sg_mux4 
	#(
		.N_DDS(N_DDS)
	)
	DUT
	(
		// Reset and clock.
		.aresetn		(aresetn			),
		.aclk			(aclk				),

    	// S_AXIS to queue waveforms.
		.s_axis_tready_o(s_axis_tready_o	),
		.s_axis_tvalid_i(s_axis_tvalid_i	),
		.s_axis_tdata_i	(s_axis_tdata_i		),

		// M_AXIS for output.
		.m_axis_tready_i(m_axis_tready_i	),
		.m_axis_tvalid_o(m_axis_tvalid_o	),
		.m_axis_tdata_o	(m_axis_tdata_o		),

		// Registers.
		.PINC0_REG		(PINC0_REG			),
		.PINC1_REG		(PINC1_REG			),
		.PINC2_REG		(PINC2_REG	 		),
		.PINC3_REG		(PINC3_REG	 		),
		.WE_REG			(WE_REG				)
	);

initial begin
	// Reset sequence.
	aresetn			<= 0;
	m_axis_tready_i	<= 1;
	PINC0_REG		<= 0;
	PINC1_REG		<= 0;
	PINC2_REG		<= 0;
	PINC3_REG		<= 0;
	WE_REG			<= 0;
	#500;
	aresetn 	<= 1;

	#1000;

	/***********************/
	/* Program Frequencies */
	/***********************/
	PINC0_REG	<= freq_calc(100, N_DDS, 1);
	PINC1_REG 	<= freq_calc(100, N_DDS, 11);
	PINC2_REG 	<= freq_calc(100, N_DDS, 27);
	PINC3_REG 	<= freq_calc(100, N_DDS, 115);
	WE_REG		<= 1;
	#100;
	WE_REG		<= 0;

	#200;

	/*******************/
	/* Queue waveforms */
	/*******************/
	tb_load_wave <= 1;
	tb_write_out <= 1;
	wait (tb_load_wave_done);
	#10000;
	tb_write_out <= 0;
	
end

initial begin
	s_axis_tvalid_i	<= 0;
	nsamp_r			<= 0;
	mask_r			<= 0;

	wait (tb_load_wave);
	wait (s_axis_tready_o);

	@(posedge aclk);
	$display("t = %0t", $time);
	s_axis_tvalid_i	<= 1;
	nsamp_r			<= 550;
	mask_r			<= 8'b0000_1000;

	//@(posedge aclk);
	//$display("t = %0t", $time);
	//s_axis_tvalid_i	<= 1;
	//nsamp_r			<= 25;
	//mask_r			<= 8'b0000_0010;

	//@(posedge aclk);
	//$display("t = %0t", $time);
	//s_axis_tvalid_i	<= 1;
	//nsamp_r			<= 35;
	//mask_r			<= 8'b0000_0100;

	//@(posedge aclk);
	//$display("t = %0t", $time);
	//s_axis_tvalid_i	<= 1;
	//nsamp_r			<= 63;
	//mask_r			<= 8'b0000_1000;
	
	@(posedge aclk);
	s_axis_tvalid_i	<= 0;
	tb_load_wave_done <= 1;
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
		@(posedge aclk);
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
	s_axi_aclk <= 0;
	#9;
	s_axi_aclk <= 1;
	#9;
end  

always begin
	aclk <= 0;
	#5;
	aclk <= 1;
	#5;
end  

// Function to compute frequency register.
function [15:0] freq_calc;
    input int fclk;
    input int ndds;
    input int f;
    
	// All input frequencies are in MHz.
	real fs,temp;
	fs = fclk*ndds;
	temp = f/fs*2**16;
	freq_calc = int'(temp);
endfunction

endmodule

