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
		m_axis_tlast	,
		m_axis_tdata
	);

/**************/
/* Parameters */
/**************/
// Number of channels.
parameter N = 32;

// Number of Lanes (Input).
parameter L = 4;

/*********/
/* Ports */
/*********/
input					aresetn;
input					aclk;

output					s_axis_tready;
input					s_axis_tvalid;
input	[L*32-1:0]		s_axis_tdata;

output					m_axis_tvalid;
output					m_axis_tlast;
output	[2*L*32-1:0]	m_axis_tdata;

/********************/
/* Internal signals */
/********************/
// FIR Configuration interface.
wire			config_tvalid;
wire			config_tready;
wire			config_tlast;
wire[7:0]		config_tdata;

// Framing.
wire			fr_sync;
wire			fr_out;

// Input delay.
wire[L*32-1:0]	data_d;
reg	[31:0]		data_r1_v[0:L-1];
reg	[31:0]		data_r2_v[0:L-1];

// Valid input.
reg				valid_r;

// FIR outputs.
wire[31:0]		dout_v [0:2*L-1];

/**********************/
/* Begin Architecture */
/**********************/
genvar i;
generate
	for (i=0; i<L; i=i+1) begin
		// Assign data to vector.
		assign data_r1_v[i] = s_axis_tdata	[i*32 +: 32];
		assign data_r2_v[i] = data_d		[i*32 +: 32];

		// Assign fir data to output.
		assign m_axis_tdata[i*32 +: 32]		= dout_v[i];
		assign m_axis_tdata[(L+i)*32 +: 32]	= dout_v[L+i];
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

// PFB Control.
pfb_ctrl
	#(
		// Number of channels.
		.N(N/(2*L))
    )
    pfb_ctrl_i
	(
		.aresetn				(aresetn			),
		.aclk     				(aclk   			),
		
		// M_AXIS for Configuration.
		.m_axis_config_tready	(config_tready		),
		.m_axis_config_tvalid 	(config_tvalid		),
		.m_axis_config_tlast  	(config_tlast 		),
		.m_axis_config_tdata  	(config_tdata 		),
		
		// Filter config.
		.cfg_en					(1'b1				),
		
		// Framing.
		.tready					(m_axis_tvalid		),
		.tvalid					(m_axis_tvalid		),
		.fr_sync				(fr_sync			),
		.fr_out  				(fr_out				)
        );

// Delayed data.
zn_nb
	#(
		// Number of bits.
		.B(L*32),

		// Delay.
		.N(32)
	)
	zn_nb_i
	(
		.aclk	 		(aclk			),
		.aresetn		(aresetn		),
	
		// S_AXIS for intput.
		.s_axis_tvalid	(s_axis_tvalid	),
		.s_axis_tdata	(s_axis_tdata	),
	
		// M_AXIS for output.
		.m_axis_tvalid	(				),
		.m_axis_tdata	(data_d			)
	
	);


// Delayed samples go to first half of firs. This is equivalent
// to a time advance z^k over the second half (non-causal).
// First half of FIRs.
fir_0 fir0_i 
	(
		.aclk							(aclk			),
		.s_axis_data_tvalid				(valid_r		),
		.s_axis_data_tready				(				),
		.s_axis_data_tlast				(fr_out			),
		.s_axis_data_tdata				(data_r2_v[0]	),
		.s_axis_config_tvalid			(config_tvalid	),
		.s_axis_config_tready			(config_tready	),
		.s_axis_config_tlast			(config_tlast	),
		.s_axis_config_tdata			(config_tdata	),
		.m_axis_data_tvalid				(m_axis_tvalid	),
		.m_axis_data_tlast				(m_axis_tlast	),
		.m_axis_data_tdata				(dout_v[0]		),
		.event_s_data_tlast_missing		(fr_sync		),
		.event_s_data_tlast_unexpected	(				),
		.event_s_config_tlast_missing	(				),
		.event_s_config_tlast_unexpected(				)
	);

fir_1 fir1_i 
	(
		.aclk							(aclk			),
		.s_axis_data_tvalid				(valid_r		),
		.s_axis_data_tready				(				),
		.s_axis_data_tlast				(fr_out			),
		.s_axis_data_tdata				(data_r1_v[0]	),
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
		.s_axis_data_tvalid				(valid_r		),
		.s_axis_data_tready				(				),
		.s_axis_data_tlast				(fr_out			),
		.s_axis_data_tdata				(data_r2_v[1]	),
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
		.s_axis_data_tvalid				(valid_r		),
		.s_axis_data_tready				(				),
		.s_axis_data_tlast				(fr_out			),
		.s_axis_data_tdata				(data_r1_v[1]	),
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
		.s_axis_data_tvalid				(valid_r		),
		.s_axis_data_tready				(				),
		.s_axis_data_tlast				(fr_out			),
		.s_axis_data_tdata				(data_r2_v[2]	),
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
		.s_axis_data_tvalid				(valid_r		),
		.s_axis_data_tready				(				),
		.s_axis_data_tlast				(fr_out			),
		.s_axis_data_tdata				(data_r1_v[2]	),
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
		.s_axis_data_tvalid				(valid_r		),
		.s_axis_data_tready				(				),
		.s_axis_data_tlast				(fr_out			),
		.s_axis_data_tdata				(data_r2_v[3]	),
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
		.s_axis_data_tvalid				(valid_r		),
		.s_axis_data_tready				(				),
		.s_axis_data_tlast				(fr_out			),
		.s_axis_data_tdata				(data_r1_v[3]	),
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
assign s_axis_tready = 1'b1;

endmodule

