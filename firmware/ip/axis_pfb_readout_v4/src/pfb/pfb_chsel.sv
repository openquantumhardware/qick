// This block will extract 1 channel from the TDM-input.
// It uses ID_REG which is as follows:
// ID_REG [7:0] 	: packet.
// ID_REG [15:8]	: index.
// 
// Input packets are as follows:
//                     |-------|             |-------|
//                     |       |             |       |
// tlast --------------|       |-------------|       |
// 
//       |-----|-------|-------|-----|-------|-------|
// t     | 0   | L     | 2*L   | 0	 | L	 | 2*L   |
// a     | 1   | L+1   | 2*L+1 | 1	 | L+1   | 2*L+1 |
// d     | 2   | L+2   | 2*L+2 | 2	 | L+2   | 2*L+2 |
// a     | .   | .     | .     | .	 | .     | .     |
// t     | .   | .     | .     | .	 | .     | .     |
// a     | .   | .     | .	   | .	 | .     | .	 |
//       | L-1 | 2*L-1 | 3*L-1 | L-1 | 2*L-1 | 3*L-1 |
//       |-----|-------|-------|-----|-------|-------|
// 
// The internal counter counts packets relying on tlast and resets.
// Offset within a packet is given by index.
module pfb_chsel
	#(
		// Bits.
		parameter B = 32,

		// Number of lanes.
		parameter L = 8
	)
	(
		// Clock.
		input wire					aclk			,

		// S_AXIS for input data.
		input wire		[L*B-1:0]	s_axis_tdata	,
		input wire					s_axis_tlast	,

		// M_AXIS for output data.
		output 	wire				m_axis_tvalid	,
		output 	wire	[B-1:0]		m_axis_tdata	,

		// Registers.
		input	wire	[15:0]		ID_REG
	);

/********************/
/* Internal signals */
/********************/
// Packet counter.
reg		[7:0]		cnt = 0;
wire				wr_en;

// Registers.
reg		[7:0]		packet_reg	;
reg		[7:0]		index_reg	;

// Data registers.
reg		[L*B-1:0]	tdata_r		;
reg		[B-1:0]		data_mux_r	;

// Muxed data.
wire	[B-1:0]		data_mux	;

// tlast_pipeline (for tvalid).
reg					tlast_r1	;
reg					tlast_r2	;

/**********************/
/* Begin Architecture */
/**********************/

// Packet counter.
assign wr_en = (cnt == packet_reg)? 1'b1 : 1'b0;

// Muxed data.
assign data_mux = tdata_r [index_reg*B +: B];

// Registers.
always @(posedge aclk) begin
	// Packet counter.
	if (s_axis_tlast == 1'b1)
		cnt <= 0;
	else
		cnt <= cnt + 1;

	// Registers.
	packet_reg	<= ID_REG [7:0];
	index_reg	<= ID_REG [15:8];
	
	// Data registers.
	if (wr_en == 1'b1)
		tdata_r <= s_axis_tdata;
	
	if (tlast_r1 == 1'b1)
		data_mux_r <= data_mux;

	// tlast_pipeline (for tvalid).
	tlast_r1	<= s_axis_tlast;
	tlast_r2	<= tlast_r1;
end

// Assign outputs.
assign m_axis_tvalid 	= tlast_r2;
assign m_axis_tdata		= data_mux_r;

endmodule

