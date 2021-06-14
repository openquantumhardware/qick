// Simplified Signal Generator Simulator.
// The block reads from the queue and implements the periodic
// and non-periodic mode, using the lower 16 bits for the number
// of samples and the next bit for mode.
module gen_sim
	(
		clk				,
		rstn			,
		s_axis_tdata	,
		s_axis_tvalid	,
		s_axis_tready
	);

input	clk;
input	rstn;

input	[159:0]	s_axis_tdata;
input			s_axis_tvalid;
output			s_axis_tready;

// States.
typedef enum	{	READ_ST	,
					CNT_ST
				} state_t;

(* fsm_encoding = "one_hot" *) state_t state;

reg				fifo_rd_en;
wire	[159:0]	fifo_dout;
wire			fifo_full;
wire			fifo_empty;

// Fifo fields.
wire	[15:0]	nsamp_int;
reg		[15:0]	nsamp_r;
wire			mode_int;
reg				mode_r;

// Counter.
reg		[15:0]	cnt;

// Register enable.
wire			en;
reg				en_r;

// Fifo.
fifo
    #(
        // Data width.
        .B	(160	),
        
        // Fifo depth.
        .N	(16		)
    )
    fifo_i
    ( 
        .rstn	(rstn			),
        .clk 	(clk			),

        // Write I/F.
        .wr_en	(s_axis_tvalid	),
        .din    (s_axis_tdata	),
        
        // Read I/F.
        .rd_en 	(fifo_rd_en		),
        .dout  	(fifo_dout		),
        
        // Flags.
        .full   (fifo_full		),
        .empty  (fifo_empty		)
    );

// Fifo fields.
assign nsamp_int	= fifo_dout[15:0];
assign mode_int		= fifo_dout[16];

// Register enable.
assign en			= fifo_rd_en & ~fifo_empty;

// Registers.
always @(posedge clk) begin
	if (~rstn) begin
		// State register.
		state	<= READ_ST;

		// Fifo fields.
		nsamp_r	<= 0;
		mode_r	<= 0;

		// Counter.
		cnt		<= 0;

		// Register enable.
		en_r	<= 0;
	end
	else begin
		// State register.
		case (state)
			READ_ST:
				if (mode_r == 1'b1 || fifo_empty == 1'b0)
					state <= CNT_ST;

			CNT_ST:
				if (cnt == nsamp_r-2)
					state <= READ_ST;
		endcase

		// Counter.
		if (fifo_rd_en == 1'b0)
			cnt <= cnt + 1;
		else
			cnt	<= 0;

		// Fifo fields.
		if (en_r == 1'b1) begin
			nsamp_r	<= nsamp_int;
			mode_r	<= mode_int;
		end
		
		// Register enable.
		en_r	<= en;
	end
end

// FSM outputs.
always_comb	begin
	// Default.
	fifo_rd_en	= 1'b0;
	
	case (state)
		READ_ST: begin
			fifo_rd_en	= 1'b1;
		end
		
		//CNT_ST:
	endcase
end

assign s_axis_tready = ~fifo_full;

endmodule

