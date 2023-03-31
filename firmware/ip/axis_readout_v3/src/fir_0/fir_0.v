module fir_0
	(
		input 	wire 			aclk				,
		input 	wire 			s_axis_data_tvalid	,
		output 	wire 			s_axis_data_tready	,
		input 	wire [127:0] 	s_axis_data_tdata	,
		output 	wire 			m_axis_data_tvalid	,
		output 	wire [31:0] 	m_axis_data_tdata
	);

assign s_axis_data_tready	= 1'b1;
assign m_axis_data_tvalid  	= 1'b1;
assign m_axis_data_tdata	= s_axis_data_tdata[0 +: 16];
