module fir_compiler_0
	(
		input			aclk				,
		input			s_axis_data_tvalid	,
		output			s_axis_data_tready	,
		input	[255:0]	s_axis_data_tdata	,
		output			m_axis_data_tvalid	,
		output	[31:0]	m_axis_data_tdata
);

assign s_axis_data_tready 	= 1'b1;
assign m_axis_data_tvalid	= s_axis_data_tvalid;
assign m_axis_data_tdata	= s_axis_data_tdata[31:0];

endmodule
