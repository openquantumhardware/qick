module cdcsync
	#(
		// Number of inputs/outputs.
		parameter N = 2	,

		// Number of data bits.
		parameter B = 8
	)
	(
		// S_AXIS for input data.
		input	wire			s_axis_aresetn	,
		input	wire			s_axis_aclk		,

		output	wire 			s0_axis_tready	,
		input	wire 			s0_axis_tvalid	,
		input	wire 	[B-1:0]	s0_axis_tdata	,

		output	wire 			s1_axis_tready	,
		input	wire 			s1_axis_tvalid	,
		input	wire 	[B-1:0]	s1_axis_tdata	,

		output	wire			s2_axis_tready	,
		input	wire			s2_axis_tvalid	,
		input	wire	[B-1:0]	s2_axis_tdata	,

		output	wire			s3_axis_tready	,
		input	wire			s3_axis_tvalid	,
		input	wire	[B-1:0]	s3_axis_tdata	,

		output	wire			s4_axis_tready	,
		input	wire			s4_axis_tvalid	,
		input	wire	[B-1:0]	s4_axis_tdata	,

		output	wire			s5_axis_tready	,
		input	wire			s5_axis_tvalid	,
		input	wire	[B-1:0]	s5_axis_tdata	,

		output	wire			s6_axis_tready	,
		input	wire			s6_axis_tvalid	,
		input	wire	[B-1:0]	s6_axis_tdata	,

		output	wire			s7_axis_tready	,
		input	wire			s7_axis_tvalid	,
		input	wire	[B-1:0]	s7_axis_tdata	,

		// M_AXIS for output data.
		input	wire			m_axis_aresetn	,
		input	wire			m_axis_aclk		,

		output	wire			m0_axis_tvalid	,
		output	wire	[B-1:0]	m0_axis_tdata	,

		output	wire			m1_axis_tvalid	,
		output	wire	[B-1:0]	m1_axis_tdata	,

		output	wire			m2_axis_tvalid	,
		output	wire	[B-1:0]	m2_axis_tdata	,

		output	wire			m3_axis_tvalid	,
		output	wire	[B-1:0]	m3_axis_tdata	,

		output	wire			m4_axis_tvalid	,
		output	wire	[B-1:0]	m4_axis_tdata	,

		output	wire			m5_axis_tvalid	,
		output	wire	[B-1:0]	m5_axis_tdata	,

		output	wire			m6_axis_tvalid	,
		output	wire	[B-1:0]	m6_axis_tdata	,

		output	wire			m7_axis_tvalid	,
		output	wire	[B-1:0]	m7_axis_tdata
	);

/********************/
/* Internal signals */
/********************/
// Total bits.
localparam	BD = B + 1;
localparam	BT = N*BD;

// Input data to vector.
wire	[B-1:0]		din_data_v	[8]	;
wire	[7:0]		din_valid_v		;

// Output vector to data.
wire	[B-1:0]		dout_data_v	[8]	;
wire	[7:0]		dout_valid_v	;

wire 				fifo_wr_en		;
wire	[BT-1:0]	fifo_din		;
wire	[BT-1:0]	fifo_dout		;
wire				fifo_full		;
wire				fifo_empty		;

/**********************/
/* Begin Architecture */
/**********************/

// Input data to vector.
assign din_data_v	[0] = s0_axis_tdata		;
assign din_data_v	[1] = s1_axis_tdata		;
assign din_data_v	[2] = s2_axis_tdata		;
assign din_data_v	[3] = s3_axis_tdata		;
assign din_data_v	[4] = s4_axis_tdata		;
assign din_data_v	[5] = s5_axis_tdata		;
assign din_data_v	[6] = s6_axis_tdata		;
assign din_data_v	[7] = s7_axis_tdata		;

assign din_valid_v	[0] = s0_axis_tvalid	;
assign din_valid_v	[1] = s1_axis_tvalid	;
assign din_valid_v	[2] = s2_axis_tvalid	;
assign din_valid_v	[3] = s3_axis_tvalid	;
assign din_valid_v	[4] = s4_axis_tvalid	;
assign din_valid_v	[5] = s5_axis_tvalid	;
assign din_valid_v	[6] = s6_axis_tvalid	;
assign din_valid_v	[7] = s7_axis_tvalid	;

// Output vector to data.
assign m0_axis_tdata	= dout_data_v	[0] ;
assign m1_axis_tdata	= dout_data_v	[1] ;
assign m2_axis_tdata	= dout_data_v	[2] ;
assign m3_axis_tdata	= dout_data_v	[3] ;
assign m4_axis_tdata	= dout_data_v	[4] ;
assign m5_axis_tdata	= dout_data_v	[5] ;
assign m6_axis_tdata	= dout_data_v	[6] ;
assign m7_axis_tdata	= dout_data_v	[7] ;

assign m0_axis_tvalid	= dout_valid_v	[0] & ~fifo_empty;
assign m1_axis_tvalid	= dout_valid_v	[1] & ~fifo_empty;
assign m2_axis_tvalid	= dout_valid_v	[2] & ~fifo_empty;
assign m3_axis_tvalid	= dout_valid_v	[3] & ~fifo_empty;
assign m4_axis_tvalid	= dout_valid_v	[4] & ~fifo_empty;
assign m5_axis_tvalid	= dout_valid_v	[5] & ~fifo_empty;
assign m6_axis_tvalid	= dout_valid_v	[6] & ~fifo_empty;
assign m7_axis_tvalid	= dout_valid_v	[7] & ~fifo_empty;

genvar i;
generate
	for (i=0; i<N; i=i+1) begin : GEN_data
		// Input data to vector.
		assign fifo_din	[BD*i +: BD] 	= {din_valid_v[i],din_data_v[i]};
	
		// Output vector to data.
		assign dout_data_v	[i]			= fifo_dout	[BD*i 		+: B];
		assign dout_valid_v	[i]			= fifo_dout [BD*i +	B		];
	end
endgenerate

// Fifo.
fifo_dc_axi
    #(
        // Data width.
        .B(BT),
        
        // Fifo depth.
        .N(16)
    )
    fifo_i
    ( 
        .wr_rstn	(s_axis_aresetn	),
        .wr_clk 	(s_axis_aclk	),

        .rd_rstn	(m_axis_aresetn	),
        .rd_clk 	(m_axis_aclk	),
        
        // Write I/F.
        .wr_en  	(fifo_wr_en		),
        .din     	(fifo_din		),
        
        // Read I/F.
        .rd_en  	(1'b1			),
        .dout   	(fifo_dout		),
        
        // Flags.
        .full    	(fifo_full		),
        .empty   	(fifo_empty		)
    );

// Or together all valid inputs.
assign fifo_wr_en	= |din_valid_v	;

// Always ready.
assign s0_axis_tready	= 1'b1 ;
assign s1_axis_tready	= 1'b1 ;
assign s2_axis_tready	= 1'b1 ;
assign s3_axis_tready	= 1'b1 ;
assign s4_axis_tready	= 1'b1 ;
assign s5_axis_tready	= 1'b1 ;
assign s6_axis_tready	= 1'b1 ;
assign s7_axis_tready	= 1'b1 ;

endmodule

