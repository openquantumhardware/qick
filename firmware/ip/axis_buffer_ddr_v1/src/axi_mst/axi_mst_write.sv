module axi_mst_write
    #(
		parameter TARGET_SLAVE_BASE_ADDR	= 32'h40000000	,
		parameter ID_WIDTH					= 1				,
		parameter DATA_WIDTH				= 32			,
		parameter BURST_SIZE				= 15
    )
    (
        input	wire						clk   			,
        input	wire						rstn 			,

		// Trigger.
		input	wire						trigger			,

		// AXI Master Interface.
		output	wire	[ID_WIDTH-1:0]		m_axi_awid		,
		output	wire	[31:0]				m_axi_awaddr	,
		output	wire	[7:0]				m_axi_awlen		,
		output	wire	[2:0]				m_axi_awsize	,
		output	wire	[1:0]				m_axi_awburst	,
		output	wire						m_axi_awlock	,
		output	wire	[3:0]				m_axi_awcache	,
		output	wire	[2:0]				m_axi_awprot	,
		output	wire	[3:0]				m_axi_awregion	,
		output	wire	[3:0]				m_axi_awqos		,
		output	wire						m_axi_awvalid	,
		input	wire						m_axi_awready	,

		output	wire	[DATA_WIDTH-1:0]	m_axi_wdata		,
		output	wire	[DATA_WIDTH/8-1:0]	m_axi_wstrb		,
		output	wire						m_axi_wlast		,
		output	wire						m_axi_wvalid	,
		input	wire						m_axi_wready	,

		input	wire	[ID_WIDTH-1:0]		m_axi_bid		,
		input	wire	[1:0]				m_axi_bresp		,
		input	wire						m_axi_bvalid	,
		output	wire						m_axi_bready	,

		// AXIS Slave Interfase.
		output	wire						s_axis_tready	,
		input	wire	[DATA_WIDTH-1:0]	s_axis_tdata	,
		input	wire	[DATA_WIDTH/8-1:0]	s_axis_tstrb	,
		input	wire						s_axis_tlast	,
		input	wire						s_axis_tvalid	,

		// Registers.
		input	wire						START_REG		,
		input	wire	[31:0]				ADDR_REG		,
		input	wire	[31:0]				NBURST_REG
    );

// Maximum burst size (4kB boundary).
localparam BYTES_PER_AXI_TRANSFER	= DATA_WIDTH/8;
localparam MAX_BURST_SIZE			= 4096/BYTES_PER_AXI_TRANSFER;
//localparam BURST_SIZE				= (MAX_BURST_SIZE >= 256)? 255 : MAX_BURST_SIZE-1;
localparam BYTES_PER_BURST			= (BURST_SIZE + 1)*BYTES_PER_AXI_TRANSFER;

/*************/
/* Internals */
/*************/

// States.
typedef enum 	{	INIT_ST			,
					TRIGGER_ST		,
					READ_REGS_ST	,
					INIT_ADDR_ST	,
                	INCR_ADDR_ST	,
                	ADDR_ST			,
                	DATA_ST			,
                	RESP_ST			,
					NBURST_ST		,
					TRIGGER_END_ST	,
					END_ST
				} state_t;

// State register.
(* fsm_encoding = "one_hot" *) state_t state;

// FSM Signals.
reg 						read_regs_state		;
reg 						init_addr_state		;
reg 						incr_addr_state		;
reg							addr_state			;
reg							data_state			;
reg							resp_state			;

// trigger resync.
wire						trigger_resync		;

// START_REG resync. 
wire						start_reg_resync	;

// Registers.
reg		[31:0]				addr_reg_r			;
reg		[31:0]				nburst_reg_r		;

// Fifo signals.
wire					    fifo_rd_en			;
wire	[DATA_WIDTH-1:0]	fifo_dout			;
reg		[DATA_WIDTH-1:0]	fifo_dout_r			;
wire						fifo_full	        ;
wire						fifo_empty    		;
reg							fifo_empty_r		;

// Address generation.
wire	[31:0]				addr_base			;
wire	[31:0]				addr_acc			;
reg		[31:0]				addr_r				;

// Burst counter.
reg		[7:0]				cnt_burst			;
reg		[31:0]				cnt_nburst			;

/****************/
/* Architecture */
/****************/

// trigger_resync.
synchronizer_n trigger_resync_i
	(
		.rstn	    (rstn			),
		.clk 		(clk			),
		.data_in	(trigger		),
		.data_out	(trigger_resync	)
	);

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
		.N(16			)
    )
	fifo_in_i
    ( 
		.rstn	(rstn			),
		.clk 	(clk			),
		
		// Write I/F.
		.wr_en	(s_axis_tvalid	),
		.din	(s_axis_tdata	),
		
		// Read I/F.
		.rd_en	(fifo_rd_en		),
		.dout	(fifo_dout		),
		
		// Flags.
		.full	(fifo_full		),
		.empty	(fifo_empty		)
    );

// Fifo connections.
assign fifo_rd_en		= m_axi_wready & data_state;
assign s_axis_tready 	= ~fifo_full;

// Write Address Channel.
// Same ID for all transactions (execute them in order).
assign m_axi_awid	= 0;

// Burst size (transactions).
assign m_axi_awlen	= BURST_SIZE;

// Size set to transfer complete data bits per beat.
assign m_axi_awsize	=	(BYTES_PER_AXI_TRANSFER == 1	)?	3'b000	:
						(BYTES_PER_AXI_TRANSFER == 2	)?	3'b001	:
						(BYTES_PER_AXI_TRANSFER == 4	)?	3'b010	:
						(BYTES_PER_AXI_TRANSFER == 8	)?	3'b011	:
						(BYTES_PER_AXI_TRANSFER == 16	)?	3'b100	:
						(BYTES_PER_AXI_TRANSFER == 32	)?	3'b101	:
						(BYTES_PER_AXI_TRANSFER == 64	)?	3'b110	:
						(BYTES_PER_AXI_TRANSFER == 128	)?	3'b111	:
															3'b000	;

// Set arburst to INCR type.
assign m_axi_awburst 	= 2'b01;

// Normal access.
assign m_axi_awlock	 	= 1'b0;

// Device Non-bufferable.
assign m_axi_awcache	= 4'b0000;

// Data, non-secure, unprivileged.
assign m_axi_awprot		= 3'b010;

// Not-used.
assign m_axi_awregion	= 4'b0000;

// Not-used qos.
assign m_axi_awqos		= 4'b0000;

// Write Data Channel.
// All bytes are written.
assign m_axi_wstrb 		= '1;

// Address generation.
assign addr_base		= TARGET_SLAVE_BASE_ADDR + addr_reg_r;
assign addr_acc			= addr_r + BYTES_PER_BURST;

// Registers.
always @(posedge clk) begin
	if (rstn == 1'b0) begin
		// State register.
		state			<= INIT_ST;
		
		// Registers.
		addr_reg_r		<= 0;
		nburst_reg_r	<= 0;
		addr_r			<= 0;

		// Fifo signals.
		fifo_dout_r		<= 0;
		fifo_empty_r	<= 0;

		// Burst counter.
		cnt_burst		<= 0;
		cnt_nburst		<= 0;
	end
	else begin
		// State register.
		case (state)
			INIT_ST:
				if (start_reg_resync == 1'b1)
					state <= TRIGGER_ST;

			TRIGGER_ST:
				if (trigger_resync == 1'b1)
					state <= READ_REGS_ST;

			READ_REGS_ST:
				state <= INIT_ADDR_ST;

			INIT_ADDR_ST:
				state <= ADDR_ST;

			INCR_ADDR_ST:
				state <= ADDR_ST;

			ADDR_ST:
				if (m_axi_awready == 1'b1)
					state <= DATA_ST;

			DATA_ST:
				if (  (m_axi_wready == 1'b1) && (m_axi_wvalid == 1'b1) && (cnt_burst == BURST_SIZE) )
					state <= RESP_ST;

			RESP_ST:
				if (m_axi_bvalid == 1'b1)
					state <= NBURST_ST;

			NBURST_ST:
				if (cnt_nburst == nburst_reg_r)
					state <= TRIGGER_END_ST;
				else
					state <= INCR_ADDR_ST;

			TRIGGER_END_ST:
				if (trigger_resync == 1'b0)
					state <= END_ST;

			END_ST:
				if (start_reg_resync == 1'b0)
					state <= INIT_ST;
		endcase
		
		// Registers.
		if (read_regs_state == 1'b1) begin
			addr_reg_r		<= ADDR_REG;
			nburst_reg_r	<= NBURST_REG;
		end

		// Address generation.
		if (init_addr_state == 1'b1)
			addr_r	<= addr_base;
		else if (incr_addr_state == 1'b1)
			addr_r	<= addr_acc;
		
		// Fifo signals.
		if (fifo_rd_en == 1'b1) begin
			fifo_dout_r		<= fifo_dout;
			fifo_empty_r 	<= fifo_empty;
		end

		// Burst counter.
		if (addr_state == 1'b1)
			cnt_burst	<= 0;
		else if (m_axi_wvalid == 1'b1 && m_axi_wready == 1'b1)
			cnt_burst <= cnt_burst + 1;
		if (read_regs_state == 1'b1)
			cnt_nburst <= 0;
		else if (m_axi_bvalid == 1'b1 && m_axi_bready == 1'b1)
			cnt_nburst <= cnt_nburst + 1;
    end
end

// FSM outputs.
always_comb begin
	// Default.
	read_regs_state		= 1'b0;
	init_addr_state		= 1'b0;
	incr_addr_state		= 1'b0;
	addr_state			= 1'b0;
	data_state			= 1'b0;
	resp_state			= 1'b0;

    case (state)
		//INIT_ST:

		//TRIGGER_ST:

		READ_REGS_ST:
			read_regs_state	= 1'b1;

		INIT_ADDR_ST:
			init_addr_state	= 1'b1;

		INCR_ADDR_ST:
			incr_addr_state	= 1'b1;

		ADDR_ST:
			addr_state		= 1'b1;

		DATA_ST:
			data_state		= 1'b1;

		RESP_ST:
			resp_state		= 1'b1;

		//NBURST_ST:

		//TRIGGER_END_ST:
		
		//END_ST:

    endcase
end

// Assign outputs.
assign m_axi_awaddr		= addr_r;
assign m_axi_awvalid	= addr_state;

assign m_axi_wdata		= fifo_dout_r;
assign m_axi_wlast		= (cnt_burst == BURST_SIZE)? 1'b1 : 1'b0;
assign m_axi_wvalid		= ~fifo_empty_r & data_state;

assign m_axi_bready		= resp_state;


endmodule

