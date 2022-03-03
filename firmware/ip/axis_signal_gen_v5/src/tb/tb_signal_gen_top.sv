module tb();

// Memory address size.
parameter N = 16;

// Number of parallel dds blocks.
parameter N_DDS = 4;

// Ports.
reg						aresetn;
reg						aclk;

reg						s0_axis_aresetn;
reg						s0_axis_aclk;
reg 	[15:0]			s0_axis_tdata_i;
reg						s0_axis_tvalid_i;
wire					s0_axis_tready_o;

wire 	[79:0]			s1_axis_tdata_i;
reg						s1_axis_tvalid_i;
wire					s1_axis_tready_o;

reg						m_axis_tready_i;
wire					m_axis_tvalid_o;
wire	[N_DDS*32-1:0]	m_axis_tdata_o;

reg   	[31:0]  START_ADDR_REG;
reg           	WE_REG;

// Fifo Dout Fields.
reg		[15:0]			freq_r;
reg		[15:0]			phase_r;
reg		[15:0]			addr_r;
reg		[15:0]			gain_r;
reg		[11:0]			nsamp_r;
reg		[1:0]			outsel_r;
reg						mode_r;
reg						stdysel_r;

// Assignment of data out for debugging.
wire	[31:0]			dout_ii [0:N_DDS-1];

// Test bench control.
reg	tb_load_mem 		= 0;
reg tb_load_mem_done	= 0;
reg	tb_load_wave 		= 0;
reg	tb_load_wave_done	= 0;
reg	tb_write_out 		= 0;

generate
genvar ii;
for (ii = 0; ii < N_DDS; ii = ii + 1) begin : GEN_debug
    assign dout_ii[ii] = m_axis_tdata_o[32*ii +: 32];
end
endgenerate

// DUT.
signal_gen_top
	#(
		.N		(N		),
		.N_DDS	(N_DDS	)
	)
	DUT
	(
		// Reset and clock.
    	.aresetn			(aresetn			),
		.aclk				(aclk				),

    	// AXIS Slave to load memory samples.
    	.s0_axis_aresetn	(s0_axis_aresetn 	),
		.s0_axis_aclk		(s0_axis_aclk	 	),
		.s0_axis_tdata_i	(s0_axis_tdata_i 	),
		.s0_axis_tvalid_i	(s0_axis_tvalid_i	),
		.s0_axis_tready_o	(s0_axis_tready_o	),

    	// AXIS Slave to queue waveforms.
		.s1_axis_tdata_i	(s1_axis_tdata_i 	),
		.s1_axis_tvalid_i	(s1_axis_tvalid_i	),
		.s1_axis_tready_o	(s1_axis_tready_o	),

		// M_AXIS for output.
		.m_axis_tready_i	(m_axis_tready_i	),
		.m_axis_tvalid_o	(m_axis_tvalid_o	),
		.m_axis_tdata_o		(m_axis_tdata_o		),

		// Registers.
		.START_ADDR_REG		(START_ADDR_REG		),
		.WE_REG				(WE_REG				)
		);

assign s1_axis_tdata_i = {stdysel_r,mode_r,outsel_r,nsamp_r,gain_r,addr_r,phase_r,freq_r};

// Main TB.
initial begin
	aresetn			<= 0;
	s0_axis_aresetn	<= 0;
	m_axis_tready_i	<= 1;
	#200;
	aresetn			<= 1;
	s0_axis_aresetn	<= 1;

	#200;

	tb_load_mem 	<= 1;
	wait (tb_load_mem_done);

	tb_load_wave 	<= 1;
	tb_write_out	<= 1;

	wait (tb_load_wave_done);

	#20000

	tb_write_out	<= 0;

	#10000;
end

// Load data into memroy.
initial begin
    int fd,val;
    
	s0_axis_tvalid_i<= 0;
	s0_axis_tdata_i	<= 0;
	START_ADDR_REG	<= 0;
	WE_REG			<= 0;
	
	wait (tb_load_mem);

	// Enable writes.
	WE_REG			<= 1;

	fd = $fopen("../../../../../tb/gauss.txt","r");

	wait (s0_axis_tready_o);

	while($fscanf(fd,"%d", val) == 1) begin
		$display("Line: %d", val);
		@(posedge s0_axis_aclk);
		s0_axis_tvalid_i 	<= 1;
		s0_axis_tdata_i 	<= val;
	end

	@(posedge s0_axis_aclk);
	s0_axis_tvalid_i 	<= 0;
	
	$fclose(fd);
	tb_load_mem_done <= 1;

	// Disable writes.
	WE_REG			<= 0;
	
end

// Load waveforms.
initial begin
	s1_axis_tvalid_i<= 0;
	freq_r			<= 0;
	phase_r			<= 0;
	addr_r			<= 0;
	gain_r			<= 0;
	nsamp_r			<= 0;
	outsel_r		<= 0;
	mode_r			<= 0;
	stdysel_r		<= 0;

	wait (tb_load_wave);
	wait (s1_axis_tready_o);

	@(posedge aclk);
	$display("t = %0t", $time);
	s1_axis_tvalid_i<= 1;
	freq_r			<= freq_calc(100, N_DDS, 120);	// 120 MHz.
	phase_r			<= 0;
	addr_r			<= 0;
	gain_r			<= 30000;
	nsamp_r			<= 100/N_DDS;
	outsel_r		<= 0;	// 0: prod, 1: dds, 2: mem
	mode_r			<= 0;	// 0: nsamp, 1: periodic
	stdysel_r		<= 1;	// 0: last, 1: zero.

	@(posedge aclk);
	$display("t = %0t", $time);
	s1_axis_tvalid_i<= 1;
	freq_r			<= freq_calc(100, N_DDS, 19);
	phase_r			<= 0;
	addr_r			<= 0;
	gain_r			<= 30000;
	nsamp_r			<= 55/N_DDS;
	outsel_r		<= 0;	// 0: prod, 1: dds, 2: mem
	mode_r			<= 0;	// 0: nsamp, 1: periodic
	stdysel_r		<= 0;	// 0: last, 1: zero.

	@(posedge aclk);
	$display("t = %0t", $time);
	s1_axis_tvalid_i<= 1;
	freq_r			<= freq_calc(100, N_DDS, 33);
	phase_r			<= 0;
	addr_r			<= 5;
	gain_r			<= 30000;
	nsamp_r			<= 670/N_DDS;
	outsel_r		<= 1;	// 0: prod, 1: dds, 2: mem
	mode_r			<= 0;	// 0: nsamp, 1: periodic
	stdysel_r		<= 1;	// 0: last, 1: zero.

	@(posedge aclk);
	$display("t = %0t", $time);
	s1_axis_tvalid_i<= 1;
	freq_r			<= freq_calc(100, N_DDS, 22);
	phase_r			<= 7689;
	addr_r			<= 0;
	gain_r			<= 30000;
	nsamp_r			<= 70/N_DDS;
	outsel_r		<= 2;	// 0: prod, 1: dds, 2: mem
	mode_r			<= 1;	// 0: nsamp, 1: periodic
	stdysel_r		<= 1;	// 0: last, 1: zero.

	@(posedge aclk);
	s1_axis_tvalid_i<= 0;

	#30000;

	@(posedge aclk);
	$display("t = %0t", $time);
	s1_axis_tvalid_i<= 1;
	freq_r			<= freq_calc(100, N_DDS, 3);
	phase_r			<= 0;
	addr_r			<= 5;
	gain_r			<= 30000;
	nsamp_r			<= 670/N_DDS;
	outsel_r		<= 1;	// 0: prod, 1: dds, 2: mem
	mode_r			<= 0;	// 0: nsamp, 1: periodic
	stdysel_r		<= 1;	// 0: last, 1: zero.

	@(posedge aclk);
	s1_axis_tvalid_i<= 0;
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

// aclk.
always begin
	aclk <= 0;
	#5;
	aclk <= 1;
	#5;
end

// s0_axis_aclk.
always begin
	s0_axis_aclk <= 0;
	#13;
	s0_axis_aclk <= 1;
	#13;
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

