module tb();

// Number of parallel dds blocks.
parameter N_DDS = 8;

// Ports.
reg				aclk;
reg				s_axis_data_tvalid;
wire			s_axis_data_tready;
reg		[255:0]	s_axis_data_tdata;
wire			m_axis_data_tvalid;
wire	[31:0]	m_axis_data_tdata;

// Test bench control.
reg tb_data_in		= 0;
reg tb_data_in_done;
reg	tb_write_out 	= 0;

// DUT.
fir_compiler_0 
	DUT 
	(
  		.aclk				(aclk				),
  		.s_axis_data_tvalid	(s_axis_data_tvalid	),
  		.s_axis_data_tready	(s_axis_data_tready	),
  		.s_axis_data_tdata	(s_axis_data_tdata	),
  		.m_axis_data_tvalid	(m_axis_data_tvalid	),
  		.m_axis_data_tdata	(m_axis_data_tdata	)
	);

initial begin
	#1000;

	@(posedge aclk);
	tb_data_in		<= 1;
	tb_write_out	<= 1;

	wait (tb_data_in_done);

	@(posedge aclk);
	tb_write_out	<= 0;

end

// Input data.
initial begin
	int fd, i;
	bit signed [15:0] vali, valq;

	tb_data_in_done		<= 0;
	s_axis_data_tvalid	<= 1;
	s_axis_data_tdata	<= 0;

	wait (tb_data_in);

	#1000;

	// Open file with input data.
	// Format: I, Q.
	fd = $fopen("../../../../../tb/data_iq.txt","r");
	
	i = N_DDS;
	while ($fscanf(fd,"%d,%d", vali, valq) == 2) begin
		$display("Time %t: Line %d, I = %d, Q = %d", $time, i, vali, valq);
		s_axis_data_tdata[(i-1)*32 +: 32] <= {valq,vali};
		i = i - 1;
		if ( i == 0) begin
			i = N_DDS;
			@(posedge aclk);
		end
	end
	
	#1000;
	
	@(posedge aclk);
	tb_data_in_done		<= 1;

end

// Write output into file.
initial begin
	int fd;
	int i;
	shortint real_d, imag_d;

	// Output file.
	fd = $fopen("../../../../../tb/dout.csv","w");

	// Data format.
	$fdisplay(fd, "valid, real, imag");

	wait (tb_write_out);

	while (tb_write_out) begin
		@(posedge aclk);
		real_d = m_axis_data_tdata[15:0];
		imag_d = m_axis_data_tdata[31:16];
		$fdisplay(fd, "%d, %d, %d", m_axis_data_tvalid, real_d, imag_d);
	end

	$display("Closing file, t = %0t", $time);
	$fclose(fd);
end

// aclk.
always begin
	aclk <= 0;
	#5;
	aclk <= 1;
	#5;
end

endmodule

