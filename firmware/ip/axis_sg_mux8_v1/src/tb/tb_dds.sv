module tb();

reg 			aclk				;
reg 			s_axis_phase_tvalid	;
wire	[71:0]	s_axis_phase_tdata	;
wire 			m_axis_data_tvalid	;
wire 	[15:0] 	m_axis_data_tdata	;

reg		[31:0]	pinc_r				;
reg		[31:0]	poff_r				;

assign s_axis_phase_tdata = {8'h00, poff_r, pinc_r};


// DUT.
dds_compiler_0 DUT
	(
  		.aclk					(aclk				),
  		.s_axis_phase_tvalid	(s_axis_phase_tvalid),
  		.s_axis_phase_tdata		(s_axis_phase_tdata	),
  		.m_axis_data_tvalid		(m_axis_data_tvalid	),
  		.m_axis_data_tdata		(m_axis_data_tdata	)
	);

initial begin
	s_axis_phase_tvalid <= 1'b1;
	pinc_r <= 0;
	poff_r <= 0;

	#100;
	
	// PINC3_REG
	@(posedge aclk);
	pinc_r <= freq_calc(100, 1, 1);
	#10;
end

always begin
	aclk <= 0;
	#5;
	aclk <= 1;
	#5;
end  

// Function to compute frequency register.
function [31:0] freq_calc;
    input int fclk;
    input int ndds;
    input int f;
    
	// All input frequencies are in MHz.
	real fs,temp;
	fs = fclk*ndds;
	temp = f/fs*2**30;
	freq_calc = {int'(temp),2'b00};
endfunction

endmodule

