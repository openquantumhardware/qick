module firs 
	(
		// Reset and clock.
		aresetn			,
		aclk			,

		// S_AXIS for input data.
		s_axis_tready	,
		s_axis_tvalid	,
		s_axis_tdata	,

		// M_AXIS for output data.
		m_axis_tvalid	,
		m_axis_tdata
	);

/**************/
/* Parameters */
/**************/
// Number of Lanes (Input).
parameter L = 4;

// Input is interleaved I+Q, compatible with quad ADC (if false, input is not interleaved - compatible with dual ADC + combiner) 
parameter INTERLEAVED_INPUT = 1;

/*********/
/* Ports */
/*********/
input					aresetn;
input					aclk;

output					s_axis_tready;
input					s_axis_tvalid;
input	[L*32-1:0]		s_axis_tdata;

output					m_axis_tvalid;
output	[2*L*32-1:0]	m_axis_tdata;

/********************/
/* Internal signals */
/********************/
// Input delay.
wire[31:0]		data_v	[0:L-1];
reg	[31:0]		data_r1	[0:L-1];
reg	[31:0]		data_r2	[0:L-1];

// Valid input.
reg				valid_r;

// FIR outputs.
wire[2*L-1:0]	valid_v;
wire[31:0]		dout_v [0:2*L-1];

/**********************/
/* Begin Architecture */
/**********************/
genvar i;
generate
	for (i=0; i<L; i=i+1) begin
		// Registers.
		always @(posedge aclk) begin
			if (~aresetn) begin
				// Input delay.
				data_r1	[i] <= 0;
				data_r2	[i] <= 0;				
			end 
			else begin
				// Input delay.
				if (s_axis_tvalid == 1'b1)
					data_r1	[i] <= data_v[i];
				data_r2	[i] <= data_r1[i];
			end
		end

		// Assign input data to vector.
		if (INTERLEAVED_INPUT == 1) begin
    		assign data_v[i] = s_axis_tdata[i*32 +: 32];
        end
        else begin
    		assign data_v[i][15:0] = s_axis_tdata[i*16 +: 16];
    		assign data_v[i][31:16] = s_axis_tdata[L*16+i*16 +: 16];
        end

		// Assign fir data to output (order to match ssrfft).
		// Real part.
		assign m_axis_tdata[i*16 +: 16] 			= dout_v[i][15:0];
		assign m_axis_tdata[(L+i)*16 +: 16] 		= dout_v[L+i][15:0];

		// Imaginary part.
		assign m_axis_tdata[2*L*16+i*16 +: 16] 		= dout_v[i][31:16];
		assign m_axis_tdata[2*L*16+(L+i)*16 +: 16] 	= dout_v[L+i][31:16];
	end
endgenerate

// Registers.
always @(posedge aclk) begin
	if (~aresetn) begin
		// Valid input.
		valid_r <= 0;
	end
	else begin
		// Valid input.
		valid_r <= s_axis_tvalid;
	end
end

// Delayed samples go to first half of firs. This is equivalent
// to a time advance z over the second half (non-causal).
// First half of FIRs.
fir_0 fir0_i 
	(
		.aclk				(aclk		),
		.s_axis_data_tvalid	(valid_r	),
		.s_axis_data_tready	(			),
		.s_axis_data_tdata	(data_r2[0]	),
		.m_axis_data_tvalid	(valid_v[0]	),
		.m_axis_data_tdata	(dout_v[0]	)
	);

fir_2 fir1_i 
	(
		.aclk				(aclk		),
		.s_axis_data_tvalid	(valid_r	),
		.s_axis_data_tready	(			),
		.s_axis_data_tdata	(data_r2[1]	),
		.m_axis_data_tvalid	(valid_v[1]	),
		.m_axis_data_tdata	(dout_v[1]	)
	);

fir_4 fir2_i 
	(
		.aclk				(aclk		),
		.s_axis_data_tvalid	(valid_r	),
		.s_axis_data_tready	(			),
		.s_axis_data_tdata	(data_r2[2]	),
		.m_axis_data_tvalid	(valid_v[2]	),
		.m_axis_data_tdata	(dout_v[2]	)
	);

fir_6 fir3_i 
	(
		.aclk				(aclk		),
		.s_axis_data_tvalid	(valid_r	),
		.s_axis_data_tready	(			),
		.s_axis_data_tdata	(data_r2[3]	),
		.m_axis_data_tvalid	(valid_v[3]	),
		.m_axis_data_tdata	(dout_v[3]	)
	);

// Second half of FIRs.
fir_1 fir4_i 
	(
		.aclk				(aclk		),
		.s_axis_data_tvalid	(valid_r	),
		.s_axis_data_tready	(			),
		.s_axis_data_tdata	(data_r1[0]	),
		.m_axis_data_tvalid	(valid_v[4]	),
		.m_axis_data_tdata	(dout_v[4]	)
	);

fir_3 fir5_i 
	(
		.aclk				(aclk		),
		.s_axis_data_tvalid	(valid_r	),
		.s_axis_data_tready	(			),
		.s_axis_data_tdata	(data_r1[1]	),
		.m_axis_data_tvalid	(valid_v[5]	),
		.m_axis_data_tdata	(dout_v[5]	)
	);

fir_5 fir6_i 
	(
		.aclk				(aclk		),
		.s_axis_data_tvalid	(valid_r	),
		.s_axis_data_tready	(			),
		.s_axis_data_tdata	(data_r1[2]	),
		.m_axis_data_tvalid	(valid_v[6]	),
		.m_axis_data_tdata	(dout_v[6]	)
	);

fir_7 fir7_i 
	(
		.aclk				(aclk		),
		.s_axis_data_tvalid	(valid_r	),
		.s_axis_data_tready	(			),
		.s_axis_data_tdata	(data_r1[3]	),
		.m_axis_data_tvalid	(valid_v[7]	),
		.m_axis_data_tdata	(dout_v[7]	)
	);

// Assign outputs.
assign s_axis_tready = 1'b1;
assign m_axis_tvalid = valid_v[0];

endmodule

