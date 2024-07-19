module firs 
	#(
		// Number of channels.
		parameter N = 32	,
		
		// Number of Lanes (Input).
		parameter L = 4
	)
	(
		// Reset and clock.
		input wire aresetn			,
		input wire aclk			,

		// S_AXIS for input data.
		input wire [2*L*32-1:0]	s_axis_tdata	,
		input wire				s_axis_tlast	,
		input wire				s_axis_tvalid	,

		// M_AXIS for output data.
		output wire [L*32-1:0]	m_axis_tdata	,
		output wire				m_axis_tvalid
	);

/********************/
/* Internal signals */
/********************/
// FIR Configuration interface.
wire					config_tvalid;
wire					config_tready;
wire					config_tlast;
wire		[7:0]		config_tdata;

// Framing.
wire					tvalid_fr;
wire					fr_sync;

// Input data.
wire 		[31:0]		data_v 		[2*L];

// FIR outputs.
wire signed [31:0]		dout_v 		[2*L];

// Delayed FIR outputs.
wire signed [31:0]		dout_v_d 	[L];

// Addition of FIR outputs.
wire signed [15:0]		sum_real_v 	[L];
wire signed [15:0]		sum_imag_v 	[L];
wire 		[31:0]		sum_v		[L];
wire		[L*32-1:0]	sum;
reg			[L*32-1:0]	sum_r1;

/**********************/
/* Begin Architecture */
/**********************/
genvar i;
generate
	for (i=0; i<L; i=i+1) begin
		// Assign input data to vector.
		assign data_v [i] 	= s_axis_tdata [i*32 		+: 32];
		assign data_v [L+i] = s_axis_tdata [(L+i)*32	+: 32];

		// Delayed FIR outputs (odd FIRs get delayed).
		zn_nb
			#(
				// Number of bits.
				.B(32),
		
				// Delay.
				.N(N/(2*L))
			)
			zn_nb_i
			(
				.aclk	 		(aclk			),
				.aresetn		(aresetn		),
			
				// S_AXIS for intput.
				.s_axis_tvalid	(1'b1			),
				.s_axis_tdata	(dout_v[2*i+1]	),
			
				// M_AXIS for output.
				.m_axis_tvalid	(				),
				.m_axis_tdata	(dout_v_d[i]	)
			);

			// Addition of FIR outputs.
			assign sum_real_v 	[i] 			= dout_v[2*i][15:0]		+ dout_v_d[i][15:0];
			assign sum_imag_v 	[i] 			= dout_v[2*i][31:16] 	+ dout_v_d[i][31:16];
			assign sum_v		[i] 			= {sum_imag_v[i], sum_real_v[i]};
			assign sum			[i*32 +: 32]	= sum_v[i];
	end
endgenerate

// Registers.
always @(posedge aclk) begin
	if (~aresetn) begin
		// Addition of FIR outputs.
		sum_r1	<= 0;
	end
	else begin
		// Addition of FIR outputs.
		sum_r1	<= sum;
	end
end

// PFB Control.
pfb_ctrl
	#(
		// Number of channels.
		.N(N/(2*L))
    )
    pfb_ctrl_i
	(
		.aresetn				(aresetn		),
		.aclk     				(aclk   		),
		
		// M_AXIS for Configuration.
		.m_axis_config_tready	(config_tready	),
		.m_axis_config_tvalid 	(config_tvalid	),
		.m_axis_config_tlast  	(config_tlast 	),
		.m_axis_config_tdata  	(config_tdata 	),
		
		// Filter config.
		.cfg_en					(1'b1			),
		
		// Framing.
		.tvalid					(tvalid_fr		),
		.fr_sync				(fr_sync		)
	);



// 2-FIR cores per lane. FIR outputs are added in pairs to
// Generate the final output samples.
fir_0 fir0_i 
	(
		.aclk							(aclk			),
		.s_axis_data_tvalid				(tvalid_fr		),
		.s_axis_data_tready				(				),
		.s_axis_data_tlast				(s_axis_tlast	),
		.s_axis_data_tdata				(data_v[0]		),
		.s_axis_config_tvalid			(config_tvalid	),
		.s_axis_config_tready			(config_tready	),
		.s_axis_config_tlast			(config_tlast	),
		.s_axis_config_tdata			(config_tdata	),
		.m_axis_data_tvalid				(m_axis_tvalid	),
		.m_axis_data_tlast				(				),
		.m_axis_data_tdata				(dout_v[0]		),
		.event_s_data_tlast_missing		(fr_sync		),
		.event_s_data_tlast_unexpected	(				),
		.event_s_config_tlast_missing	(				),
		.event_s_config_tlast_unexpected(				)
	);

fir_1 fir1_i 
	(
		.aclk							(aclk			),
		.s_axis_data_tvalid				(tvalid_fr		),
		.s_axis_data_tready				(				),
		.s_axis_data_tlast				(s_axis_tlast	),
		.s_axis_data_tdata				(data_v[1]		),
		.s_axis_config_tvalid			(config_tvalid	),
		.s_axis_config_tready			(             	),
		.s_axis_config_tlast			(config_tlast	),
		.s_axis_config_tdata			(config_tdata	),
		.m_axis_data_tvalid				(				),
		.m_axis_data_tlast				(            	),
		.m_axis_data_tdata				(dout_v[1]		),
		.event_s_data_tlast_missing		(       		),
		.event_s_data_tlast_unexpected	(				),
		.event_s_config_tlast_missing	(				),
		.event_s_config_tlast_unexpected(				)
	);

fir_2 fir2_i 
	(
		.aclk							(aclk			),
		.s_axis_data_tvalid				(tvalid_fr		),
		.s_axis_data_tready				(				),
		.s_axis_data_tlast				(s_axis_tlast	),
		.s_axis_data_tdata				(data_v[2]		),
		.s_axis_config_tvalid			(config_tvalid	),
		.s_axis_config_tready			(             	),
		.s_axis_config_tlast			(config_tlast	),
		.s_axis_config_tdata			(config_tdata	),
		.m_axis_data_tvalid				(				),
		.m_axis_data_tlast				(            	),
		.m_axis_data_tdata				(dout_v[2]		),
		.event_s_data_tlast_missing		(       		),
		.event_s_data_tlast_unexpected	(				),
		.event_s_config_tlast_missing	(				),
		.event_s_config_tlast_unexpected(				)
	);

fir_3 fir3_i 
	(
		.aclk							(aclk			),
		.s_axis_data_tvalid				(tvalid_fr		),
		.s_axis_data_tready				(				),
		.s_axis_data_tlast				(s_axis_tlast	),
		.s_axis_data_tdata				(data_v[3]		),
		.s_axis_config_tvalid			(config_tvalid	),
		.s_axis_config_tready			(             	),
		.s_axis_config_tlast			(config_tlast	),
		.s_axis_config_tdata			(config_tdata	),
		.m_axis_data_tvalid				(				),
		.m_axis_data_tlast				(            	),
		.m_axis_data_tdata				(dout_v[3]		),
		.event_s_data_tlast_missing		(       		),
		.event_s_data_tlast_unexpected	(				),
		.event_s_config_tlast_missing	(				),
		.event_s_config_tlast_unexpected(				)
	);

fir_4 fir4_i 
	(
		.aclk							(aclk			),
		.s_axis_data_tvalid				(tvalid_fr		),
		.s_axis_data_tready				(				),
		.s_axis_data_tlast				(s_axis_tlast	),
		.s_axis_data_tdata				(data_v[4]		),
		.s_axis_config_tvalid			(config_tvalid	),
		.s_axis_config_tready			(             	),
		.s_axis_config_tlast			(config_tlast	),
		.s_axis_config_tdata			(config_tdata	),
		.m_axis_data_tvalid				(				),
		.m_axis_data_tlast				(            	),
		.m_axis_data_tdata				(dout_v[4]		),
		.event_s_data_tlast_missing		(       		),
		.event_s_data_tlast_unexpected	(				),
		.event_s_config_tlast_missing	(				),
		.event_s_config_tlast_unexpected(				)
	);

fir_5 fir5_i 
	(
		.aclk							(aclk			),
		.s_axis_data_tvalid				(tvalid_fr		),
		.s_axis_data_tready				(				),
		.s_axis_data_tlast				(s_axis_tlast	),
		.s_axis_data_tdata				(data_v[5]		),
		.s_axis_config_tvalid			(config_tvalid	),
		.s_axis_config_tready			(             	),
		.s_axis_config_tlast			(config_tlast	),
		.s_axis_config_tdata			(config_tdata	),
		.m_axis_data_tvalid				(				),
		.m_axis_data_tlast				(            	),
		.m_axis_data_tdata				(dout_v[5]		),
		.event_s_data_tlast_missing		(       		),
		.event_s_data_tlast_unexpected	(				),
		.event_s_config_tlast_missing	(				),
		.event_s_config_tlast_unexpected(				)
	);

fir_6 fir6_i 
	(
		.aclk							(aclk			),
		.s_axis_data_tvalid				(tvalid_fr		),
		.s_axis_data_tready				(				),
		.s_axis_data_tlast				(s_axis_tlast	),
		.s_axis_data_tdata				(data_v[6]		),
		.s_axis_config_tvalid			(config_tvalid	),
		.s_axis_config_tready			(             	),
		.s_axis_config_tlast			(config_tlast	),
		.s_axis_config_tdata			(config_tdata	),
		.m_axis_data_tvalid				(				),
		.m_axis_data_tlast				(            	),
		.m_axis_data_tdata				(dout_v[6]		),
		.event_s_data_tlast_missing		(       		),
		.event_s_data_tlast_unexpected	(				),
		.event_s_config_tlast_missing	(				),
		.event_s_config_tlast_unexpected(				)
	);

fir_7 fir7_i 
	(
		.aclk							(aclk			),
		.s_axis_data_tvalid				(tvalid_fr		),
		.s_axis_data_tready				(				),
		.s_axis_data_tlast				(s_axis_tlast	),
		.s_axis_data_tdata				(data_v[7]		),
		.s_axis_config_tvalid			(config_tvalid	),
		.s_axis_config_tready			(             	),
		.s_axis_config_tlast			(config_tlast	),
		.s_axis_config_tdata			(config_tdata	),
		.m_axis_data_tvalid				(				),
		.m_axis_data_tlast				(            	),
		.m_axis_data_tdata				(dout_v[7]		),
		.event_s_data_tlast_missing		(       		),
		.event_s_data_tlast_unexpected	(				),
		.event_s_config_tlast_missing	(				),
		.event_s_config_tlast_unexpected(				)
	);


// Assign outputs.
assign m_axis_tdata	 = sum_r1;

endmodule

