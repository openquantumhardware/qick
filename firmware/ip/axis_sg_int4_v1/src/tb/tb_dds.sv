module tb_();

reg 		aclk;
reg 		s_axis_phase_tvalid;
reg [31:0] 	s_axis_phase_tdata;
wire 		m_axis_data_tvalid;
wire [31:0]	m_axis_data_tdata;

// DDS.
dds_compiler_0 dds_i 
	(
  		.aclk					(aclk				),
  		.s_axis_phase_tvalid	(s_axis_phase_tvalid),
  		.s_axis_phase_tdata		(s_axis_phase_tdata	),
  		.m_axis_data_tvalid		(m_axis_data_tvalid	),
  		.m_axis_data_tdata		(m_axis_data_tdata	)
	);

// Main TB.
initial begin
	s_axis_phase_tvalid	<= 0;

	#500;

	for (int i=0; i<111; i=i+1) begin
		@(posedge aclk);
		s_axis_phase_tdata	<= i;
		s_axis_phase_tvalid	<= 1;
	end

	@(posedge aclk);
	s_axis_phase_tvalid	<= 0;
end

// aclk.
always begin
	aclk <= 0;
	#5;
	aclk <= 1;
	#5;
end

endmodule

