module pfb_swap
	(
		// Reset and clock.
		aresetn			,
		aclk			,

		// S_AXIS for input data.
		s_axis_tvalid	,
		s_axis_tlast	,
		s_axis_tdata	,

		// M_AXIS for output data.
		m_axis_tvalid	,
		m_axis_tlast	,
		m_axis_tdata
	);

/**************/
/* Parameters */
/**************/
// Bits.
parameter B = 32;

// Number of Lanes.
parameter L = 4;

// Number of channels.
parameter N = 32;

/*********/
/* Ports */
/*********/
input				aresetn;
input				aclk;

input				s_axis_tvalid;
input				s_axis_tlast;
input	[2*L*B-1:0]	s_axis_tdata;

output				m_axis_tvalid;
output				m_axis_tlast;
output	[2*L*B-1:0]	m_axis_tdata;

/********************/
/* Internal signals */
/********************/
// Number of packets.
localparam NP 		= N/(2*L);
localparam NP_LOG2 	= $clog2(NP);

// States.
typedef enum	{	RST_ST	,
					SYNC_ST	,
					RW0_ST	,
					RW1_ST
				} state_t;

// State register.
(* fsm_encoding = "one_hot" *) state_t state;

reg					rst_state;
reg					wr_en;
reg					rw0_state;
reg					rw1_state;

// Write selection.
reg					wr_sel;

// Read selection.
reg					rd_sel;
reg					rd_sel_r;

// Packet counter.
reg	[NP_LOG2-1:0]	cnt;
reg	[NP_LOG2-2:0]	cnt_sel;

// Fifo signals.
wire				fifo0_wr_en;
wire				fifo0_rd_en;
wire	[2*L*B-1:0]	fifo0_dout;
wire				fifo0_full;
wire				fifo0_empty;

wire				fifo1_wr_en;
wire				fifo1_rd_en;
wire	[2*L*B-1:0]	fifo1_dout;
wire				fifo1_full;
wire				fifo1_empty;

// Muxed output.
wire	[2*L*B-1:0]	dmux;

// Tlast.
reg					tlast_r;


/**********************/
/* Begin Architecture */
/**********************/

// Fifo 0.
fifo
	#(
		// Data width.
		.B(2*L*B),
		
		// Fifo depth.
		.N(N/L)
	)
	fifo_0
	( 
	    .rstn	(aresetn		),
	    .clk 	(aclk			),
	
	    // Write I/F.
	    .wr_en  (fifo0_wr_en	),
	    .din    (s_axis_tdata	),
	    
	    // Read I/F.
	    .rd_en  (fifo0_rd_en	),
	    .dout  	(fifo0_dout		),
	    
	    // Flags.
	    .full   (fifo0_full		),
	    .empty  (fifo0_empty	)
	);

assign fifo0_wr_en = (wr_en && ~wr_sel);
assign fifo0_rd_en = rst_state || (rw1_state && ~rd_sel);

// Fifo 1.
fifo
	#(
		// Data width.
		.B(2*L*B),
		
		// Fifo depth.
		.N(N/L)
	)
	fifo_1
	( 
	    .rstn	(aresetn		),
	    .clk 	(aclk			),
	
	    // Write I/F.
	    .wr_en  (fifo1_wr_en	),
	    .din    (s_axis_tdata	),
	    
	    // Read I/F.
	    .rd_en  (fifo1_rd_en	),
	    .dout  	(fifo1_dout		),
	    
	    // Flags.
	    .full   (fifo1_full		),
	    .empty  (fifo1_empty	)
	);

assign fifo1_wr_en = (wr_en && wr_sel);
assign fifo1_rd_en = rst_state || (rw1_state && rd_sel);

// Registers.
always @(posedge aclk) begin
	if (~aresetn) begin
		// State register.
		state 		<= RST_ST;
	
		// Counter for output selection.
		cnt			<= 0;

		// Write selection.
		wr_sel		<= 0;

		// Read selection.
		rd_sel		<= 0;
		rd_sel_r	<= 0;

		// Tlast.
		tlast_r		<= 0;
	end
	else begin
		// State register.
		case (state)
			RST_ST:
				if (fifo0_empty == 1'b1 && fifo1_empty == 1'b1)
					state <= SYNC_ST;

			SYNC_ST:
				if (s_axis_tlast == 1'b1)
					state <= RW0_ST;

			RW0_ST:
				if (cnt == '1 && s_axis_tlast == 1'b1)
					state <= RW1_ST;

			RW1_ST:
				if (cnt == '1 && s_axis_tlast == 1'b0)
					state <= RST_ST;
		endcase

		// Counter for output selection.
		if (wr_en == 1'b1) begin
			cnt 	<= cnt + 1;
			cnt_sel <= cnt_sel + 1;
		end
		else begin
			cnt 	<= 0;
			cnt_sel <= 0;
		end

		// Write selection.
		if (wr_en == 1'b1)
			wr_sel	<= ~wr_sel;
		else
			wr_sel <= 0;

		// Read selection.
		if (rw1_state == 1'b1) begin
			if (cnt_sel == '1)
				rd_sel <= ~rd_sel;
		end
		else
			rd_sel <= 0;

		rd_sel_r	<= rd_sel;

		// Tlast.
		tlast_r		<= s_axis_tlast;
	end
end

// FSM outputs.
always_comb	begin
	// Default.
	wr_en 		= 0;
	rst_state	= 0;
	rw0_state 	= 0;
	rw1_state 	= 0;

	case (state)
		RST_ST:
			rst_state = 1'b1;

		//SYNC_ST:

		RW0_ST: begin
			wr_en 		= 1'b1;
			rw0_state 	= 1'b1;
		end

		RW1_ST: begin
			wr_en 		= 1'b1;
			rw1_state 	= 1'b1;
		end
	endcase
end

// Data mux.
assign dmux = (rd_sel_r == 1'b0)? fifo0_dout : fifo1_dout;

// Assign outputs.
assign m_axis_tvalid 	= 1'b1;
assign m_axis_tlast		= tlast_r;
assign m_axis_tdata		= dmux;

endmodule

