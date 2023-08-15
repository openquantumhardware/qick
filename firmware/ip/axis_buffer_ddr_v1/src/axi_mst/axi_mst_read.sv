module axi_mst_read
	#(
		// Parameters of AXI Master I/F.
		parameter TARGET_SLAVE_BASE_ADDR	= 32'h40000000	,
		parameter ID_WIDTH					= 1				,
		parameter DATA_WIDTH				= 512
	)
    (
		input	wire						clk				,
		input	wire						rstn			,
		
		// AXI Master Interface.
		output	wire	[ID_WIDTH-1:0]		m_axi_arid		,
		output	wire	[31:0]				m_axi_araddr	,
		output	wire	[7:0]				m_axi_arlen		,
		output	wire	[2:0]				m_axi_arsize	,
		output	wire	[1:0]				m_axi_arburst	,
		output	wire						m_axi_arlock	,
		output	wire	[3:0]				m_axi_arcache	,
		output	wire	[2:0]				m_axi_arprot	,
		output	wire	[3:0]				m_axi_arregion	,
		output	wire	[3:0]				m_axi_arqos		,
		output	wire						m_axi_arvalid	,
		input	wire						m_axi_arready	,

		input	wire	[ID_WIDTH-1:0]		m_axi_rid		,
		input	wire	[DATA_WIDTH-1:0]	m_axi_rdata		,
		input	wire	[1:0]				m_axi_rresp		,
		input	wire						m_axi_rlast		,
		input	wire						m_axi_rvalid	,
		output	wire						m_axi_rready	,
		
		// AXIS Master Interfase.
		output	wire						m_axis_tvalid	,
		output	wire	[DATA_WIDTH-1:0]	m_axis_tdata	,
		output	wire	[DATA_WIDTH/8-1:0]	m_axis_tstrb	,
		output	wire						m_axis_tlast	,
		input	wire						m_axis_tready	,
		
		// Registers.
		input	wire						START_REG		,
		input	wire	[31:0]				ADDR_REG		,
		input	wire	[31:0]				LENGTH_REG
    );

/*************/
/* Internals */
/*************/

// Maximum burst size (4kB boundary).
localparam BYTES_PER_AXI_TRANSFER	= DATA_WIDTH/8;
localparam MAX_BURST_SIZE			= 4096/BYTES_PER_AXI_TRANSFER;

// States.
typedef enum	{	INIT_ST			,
					START_ST		,
					READ_REGS_ST	,
					ADDR_ST			,
					DATA_ST			,
					END_ST
				} state_t;

// State register.
(* fsm_encoding = "one_hot" *) state_t state;

// FSM Signals.
reg 				read_regs_state		;

// START_REG resync. 
wire				start_reg_resync	;

// Registers.
reg		[31:0]		addr_reg_r			;
reg		[31:0]		len_reg_r	        ;

// Fifo.
wire				fifo_full			;
wire				fifo_empty			;

// AXI Master.
reg					axi_arvalid_i		;

// Address.
wire	[31:0]		addr_base			;

// Burst length.
wire	[7:0]		burst_length		;

/****************/
/* Architecture */
/****************/

// start_reg_resync.
synchronizer_n start_reg_resync_i
	(
		.rstn	    (rstn				),
		.clk 		(clk				),
		.data_in	(START_REG			),
		.data_out	(start_reg_resync	)
	);

// Single-clock fifo.
fifo_axi
    #(
		// Data width.
		.B(DATA_WIDTH	),
		
		// Fifo depth.
		.N(64			)
    )
	fifo_i
    ( 
		.rstn	(rstn			),
		.clk 	(clk			),
		
		// Write I/F.
		.wr_en  (m_axi_rvalid	),
		.din    (m_axi_rdata	),
		
		// Read I/F.
		.rd_en  (m_axis_tready	),
		.dout   (m_axis_tdata	),
		
		// Flags.
		.full	(fifo_full		),
		.empty  (fifo_empty		)
    );

assign m_axi_rready		= ~fifo_full;
assign m_axis_tvalid	= ~fifo_empty;

// Burst lenth.
//assign burst_length    	= MAX_BURST_SIZE-1;
assign burst_length		= len_reg_r - 1;

// Base address.
assign addr_base		= TARGET_SLAVE_BASE_ADDR + addr_reg_r;

// Registers.
always @(posedge clk) begin
	if (rstn == 1'b0) begin
		// State register.
		state		<= INIT_ST;
		
		// Registers.
		addr_reg_r	<= 0;
		len_reg_r	<= 0;
	end
	else begin
		// State register.
		case (state)
			INIT_ST:
				state <= START_ST;

			START_ST:
				if (start_reg_resync == 1'b1)
					state <= READ_REGS_ST;

			READ_REGS_ST:
				state <= ADDR_ST;

			ADDR_ST:
				if (m_axi_arready == 1'b1)
					state <= DATA_ST;
			DATA_ST:
				if (m_axi_rvalid == 1'b1 && m_axi_rlast == 1'b1 && fifo_full == 1'b0)
					state <= END_ST;

			END_ST:
				if (start_reg_resync == 1'b0)
					state <= START_ST;
		endcase
	
		// Registers.
		if (read_regs_state == 1'b1) begin
			addr_reg_r	<= ADDR_REG;
			len_reg_r	<= LENGTH_REG;
		end

	end	
end

// Read Address Channel.
// Same ID for all transactions (execute them in order).
assign m_axi_arid	= 0;

// Burst length (must substract 1).
assign m_axi_arlen	= burst_length;

// Size set to transfer complete data bits per beat (64 bytes/transfer).
assign m_axi_arsize	=	(BYTES_PER_AXI_TRANSFER == 1	)?	3'b000	:
						(BYTES_PER_AXI_TRANSFER == 2	)?	3'b001	:
						(BYTES_PER_AXI_TRANSFER == 4	)?	3'b010	:
						(BYTES_PER_AXI_TRANSFER == 8	)?	3'b011	:
						(BYTES_PER_AXI_TRANSFER == 16	)?	3'b100	:
						(BYTES_PER_AXI_TRANSFER == 32	)?	3'b101	:
						(BYTES_PER_AXI_TRANSFER == 64	)?	3'b110	:
						(BYTES_PER_AXI_TRANSFER == 128	)?	3'b111	:
															3'b000	;

// Set arburst to INCR type.
assign m_axi_arburst	= 2'b01;

// Normal access.
assign m_axi_arlock 	= 1'b0;

// Device Non-bufferable.
assign m_axi_arcache	= 4'b0000;

// Data, non-secure, unprivileged.
assign m_axi_arprot 	= 3'b010;

// Not-used.
assign m_axi_arregion	= 4'b0000;

// Not-used qos.
assign m_axi_arqos		= 4'b0000;

// FSM outputs.
always_comb begin
	// Default.
	read_regs_state	= 1'b0;
	axi_arvalid_i	= 1'b0;

    case (state)
		//INIT_ST:

		//START_ST:

		READ_REGS_ST:
			read_regs_state	= 1'b1;

		ADDR_ST:
			axi_arvalid_i	= 1'b1;

		//DATA_ST:

		//END_ST:

    endcase
end

// Assign outputs.
assign m_axi_araddr	 = addr_base;
assign m_axi_arvalid = axi_arvalid_i;

assign m_axis_tstrb	 = '1;
assign m_axis_tlast	 = 1'b0;

endmodule

