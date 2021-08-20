module tb();

reg			aclk;
reg			s_axis_phase_tvalid;
wire [71:0]	s_axis_phase_tdata;
wire		m_axis_data_tvalid;
wire [31:0]	m_axis_data_tdata;

reg			resync_r;
reg	[31:0]	poff_r;
reg	[31:0]	pinc_r;

integer i;

// DDS Data Format
//
// | ---------------------------------------|
// | 71 .. 65 | 64     | 63 .. 32 | 31 .. 0 |
// | Unused   | RESYNC | POFF     | PINC    |
// | ---------------------------------------|

// DUT.
dds_compiler_0
	DUT 
	(
  		.aclk					(aclk					),
  		.s_axis_phase_tvalid	(s_axis_phase_tvalid	),
  		.s_axis_phase_tdata		(s_axis_phase_tdata		),
  		.m_axis_data_tvalid		(m_axis_data_tvalid		),
  		.m_axis_data_tdata		(m_axis_data_tdata		)
	);

assign s_axis_phase_tdata = {7'b0000000,resync_r,poff_r,pinc_r};

initial begin
	s_axis_phase_tvalid	<= 0;
	resync_r			<= 0;
	poff_r				<= 0;
	pinc_r				<= 0;
	#200;

	// 1101 pulses of f = 100;
	@(posedge aclk);
	s_axis_phase_tvalid	<= 1;
	resync_r			<= 1;
	poff_r				<= 0;
	pinc_r				<= 10000000;

	for (i=0; i<1100; i=i+1) begin
		@(posedge aclk);
		s_axis_phase_tvalid	<= 1;
		resync_r			<= 0;
	end

	// 2 Dummy to account for internal pipe.
	@(posedge aclk);
	s_axis_phase_tvalid	<= 1;
	resync_r			<= 1;
	@(posedge aclk);
	s_axis_phase_tvalid	<= 1;
	resync_r			<= 1;

	@(posedge aclk);
	s_axis_phase_tvalid	<= 0;

	#200;

	// 801 pulses of f = 1500;
	@(posedge aclk);
	s_axis_phase_tvalid	<= 1;
	resync_r			<= 1;
	poff_r				<= 0;
	pinc_r				<= 1500;

	for (i=0; i<800; i=i+1) begin
		@(posedge aclk);
		s_axis_phase_tvalid	<= 1;
		resync_r			<= 0;
	end

	// 2 Dummy to account for internal pipe.
	@(posedge aclk);
	s_axis_phase_tvalid	<= 1;
	resync_r			<= 1;
	@(posedge aclk);
	s_axis_phase_tvalid	<= 1;
	resync_r			<= 1;

	@(posedge aclk);
	s_axis_phase_tvalid	<= 0;

	#10000;
	
end

always begin
	aclk <= 0;
	#10;
	aclk <= 1;
	#10;
end

endmodule

