// Custom axi-lite slave block with limited functionality:
//
// * Address map is DATA_WIDTH based, not byte based.
// * Strobe not implemented. Always full access.
//
// The slave supports a maximum of 16-bit address space. The lower portion
// is reserved for registers, the upper portion for external memory.
// Registers: 64 registers, 32-bit each (4 bytes), gives 256 bytes.
//
// AXI RRESP/BRESP: when the external memory arbiter is executing a stream
// operation, memory is busy and cannot be accesses with single read/write
// modes. In this case, the axi slave will return with an error code:
// RRESP/BRESP = 2'b10 (SLVERR, see AXI specification).
//
// In any other access, if the operation is executed properly, the axi slave
// block will return a OKAY standard code:
// RRESP/BRESP = 2'b00 (OKAY, see AXI specification).
//
// This allows to avoid dead-locks due to the bus already taken.
//
module axi_slv_custom (
	// Reset and clock.
	aclk_i			,
	aresetn_i		,

	// Write Address Channel.
	awaddr_i		,
	awprot_i		,
	awvalid_i		,
	awready_o		,
	
	// Write Data Channel.
	wdata_i			,
	wstrb_i			,
	wvalid_i		,
	wready_o		,
	
	// Write Response Channel.
	bresp_o			,
	bvalid_o		,
	bready_i		,
	
	// Read Address Channel.
	araddr_i		,
	arprot_i		,
	arvalid_i		,
	arready_o		,
	
	// Read Data Channel.
	rdata_o			,
	rresp_o			,
	rvalid_o		,
	rready_i		,

	// Single Access Handshake.
	busy_i			,
	oper_o			,
	addr_o			,
	dwrite_o		,
	dread_i			,
	exec_o			,
	exec_ack_i		,
	
	// Registers.
	START_SRC_REG 	,
	START_REG 		,
	MEM_MODE_REG	,
	MEM_START_REG	,
	MEM_ADDR_REG	,
	MEM_LEN_REG
);

// Parameters.
localparam 	DATA_WIDTH 				= 32;
localparam	DATA_WIDTH_BYTE			= DATA_WIDTH/8;
localparam	DATA_WIDTH_BYTE_LOG2	= $clog2(DATA_WIDTH_BYTE);
localparam	NREG					= 64;
localparam	NREG_BYTE				= NREG*DATA_WIDTH_BYTE;

// Ports.
input 						aclk_i;
input 						aresetn_i;

input	[31:0]				awaddr_i;
input 	[2:0]				awprot_i;
input 						awvalid_i;
output reg					awready_o;

input 	[DATA_WIDTH-1:0]	wdata_i;
input 	[DATA_WIDTH/8-1:0]	wstrb_i;
input 						wvalid_i;
output reg					wready_o;

output 	[1:0]				bresp_o;
output reg					bvalid_o;
input 						bready_i;

input 	[31:0]				araddr_i;
input 	[2:0]				arprot_i;
input 						arvalid_i;
output 	reg					arready_o;

output 	[DATA_WIDTH-1:0]	rdata_o;
output 	[1:0]				rresp_o;
output 	reg					rvalid_o;
input 						rready_i;

input 						busy_i;
output	reg					oper_o;
output	[31:0]				addr_o;
output	[DATA_WIDTH-1:0]	dwrite_o;
input	[DATA_WIDTH-1:0]	dread_i;
output reg					exec_o;
input						exec_ack_i;

output 						START_SRC_REG;
output 						START_REG;
output						MEM_MODE_REG;
output						MEM_START_REG;
output	[31:0]				MEM_ADDR_REG;
output	[31:0]				MEM_LEN_REG;

// States.
typedef enum	{	INIT_ST			,
					AWADDR_ST		, 	// Address Write State.
					WDATA_ST		, 	// Write Data State.
					BRESP_ST		, 	// Write Response State.
					ARADDR_ST		, 	// Address Read State.
					RDATA_ST		, 	// Read Data State.
					REG_WR_ST		, 	// Lower address, write internal register map.
					MEM_WR_ST		, 	// Higher address, write external memory.
					REG_RD_ST		, 	// Lower address, read internal register map.
					MEM_RD_ST		, 	// Higher address, read external memory.
					WR_ACK_ST		, 	// Wait acknowledge from single write access interface.
					RD_ACK_ST		, 	// Wait acknowledge from single read access interface.
					BRESP_OK_ST		,	// Set BRESP OKAY response register.
					BRESP_ERR_ST	,	// Set BRESP SLVERR response register.
					RRESP_OK_ST		,	// Set RRESP OKAY response register.
					RRESP_ERR_ST		// Set RRESP SLVERR response register.
				} state_t;

(* fsm_encoding = "one_hot" *) state_t state;

// Flags.
reg				reg_rw;		// 0: register read, 1: register write.
reg				sel_int;	// 0: register, 1: external memory.
reg				data_en;	// Enable data register.
reg				addr_sel;	// 0: awaddr, 1: araddr.

// Address register.
reg 	[31:0] 				addr_r;
wire	[31:0]				addr_mux;

// Output memory address computation.
wire 	[31:0] 				addr_out;

// Data registers.
reg		[DATA_WIDTH-1:0] 	wdata_r;
reg		[DATA_WIDTH-1:0] 	data_r;
wire	[DATA_WIDTH-1:0] 	data_mux;

// Resp register.
reg		[1:0]				resp_r;
reg							resp_en;
reg		[1:0]				resp_int;	// 2'b00: OKAY, 2'b10: SLVERR.

// Register map.
reg 	[DATA_WIDTH-1:0] 	reg0;
reg 	[DATA_WIDTH-1:0] 	reg1;
reg 	[DATA_WIDTH-1:0] 	reg2;
reg 	[DATA_WIDTH-1:0] 	reg3;
reg 	[DATA_WIDTH-1:0] 	reg4;
reg 	[DATA_WIDTH-1:0] 	reg5;
reg 	[DATA_WIDTH-1:0] 	reg6;
reg 	[DATA_WIDTH-1:0] 	reg7;
wire	[DATA_WIDTH-1:0]	reg_int;	// Selected register.

// Registers.
always @(posedge aclk_i) begin
	if (~aresetn_i) begin
		// State register.
		state 		<= INIT_ST;

		// Address register.
		addr_r		<= 0;

		// Data registers.
		wdata_r		<= 0;
		data_r		<= 0;

		// Resp register.
		resp_r		<= 0;

		// Register map.
		reg0		<= 0;
		reg1		<= 0;
		reg2		<= 0;
		reg3		<= 0;
		reg4		<= 0;
		reg5		<= 0;
		reg6		<= 0;
		reg7		<= 0;
	end
	else begin
		// State register.
		case (state)
			INIT_ST:
				if (awvalid_i)
					state <= AWADDR_ST;
				else if (arvalid_i)
					state <= ARADDR_ST;

			AWADDR_ST:
				state <= WDATA_ST;

			WDATA_ST:
				if (wvalid_i)
					if (addr_r < NREG_BYTE)
						// Lower address map, register write.
						state <= REG_WR_ST;
					else
						// Higher address map, memory write.
						if (busy_i)
							state <= BRESP_ERR_ST;
						else
							state <= MEM_WR_ST;

			BRESP_ST:
				if (bready_i)
					state <= INIT_ST;

			ARADDR_ST:
				if (araddr_i < NREG_BYTE)
					// Lower address map, register read.
					state <= REG_RD_ST;
				else
					// Higher address map, memory read.
					if (busy_i)
						state <= RRESP_ERR_ST;
					else
						state <= MEM_RD_ST;

			RDATA_ST:
				if (rready_i)
					state <= INIT_ST;

			REG_WR_ST:
				state <= BRESP_OK_ST;

			MEM_WR_ST:
				if (exec_ack_i)
					state <= WR_ACK_ST;

			REG_RD_ST:
				state <= RRESP_OK_ST;

			MEM_RD_ST:
				if (exec_ack_i)
					state <= RD_ACK_ST;

			WR_ACK_ST:
				if (~exec_ack_i)
					state <= BRESP_OK_ST;

			RD_ACK_ST:
				if (~exec_ack_i)
					state <= RRESP_OK_ST;

			BRESP_OK_ST:
				state <= BRESP_ST;

			BRESP_ERR_ST:
				state <= BRESP_ST;

			RRESP_OK_ST:
				state <= RDATA_ST;

			RRESP_ERR_ST:
				state <= RDATA_ST;

		endcase

		// Address register.
		if ((awvalid_i && awready_o) || (arvalid_i && arready_o))
			addr_r <= addr_mux;

		// Data registers.
		if (wvalid_i && wready_o)
			wdata_r <= wdata_i;

		if (data_en)
			data_r <= data_mux;

		// Resp register.
		if (resp_en)
			resp_r <= resp_int;

		// Register write.
		if (reg_rw)
			case (addr_r)
				0: reg0 <= wdata_r;
				4: reg1 <= wdata_r;
				8: reg2 <= wdata_r;
				12: reg3 <= wdata_r;
				16: reg4 <= wdata_r;
				20: reg5 <= wdata_r;
				24: reg6 <= wdata_r;
				28: reg7 <= wdata_r;
			endcase
	end
end 

// FSM outputs.
always_comb begin
	// Default value.
	awready_o	= 0;
	wready_o	= 0;
	bvalid_o	= 0;
	arready_o	= 0;
	rvalid_o	= 0;
	oper_o		= 0;	// 0: read, 1: write.
	exec_o		= 0;
	reg_rw		= 0;
	sel_int		= 0;
	data_en		= 0;
	addr_sel	= 0;
	resp_en		= 0;
	resp_int	= 0;

	case (state)
		//INIT_ST:

		AWADDR_ST: begin
			awready_o	= 1;
			addr_sel	= 0;
		end

		WDATA_ST:
			wready_o	= 1;

		BRESP_ST:
			bvalid_o	= 1;

		ARADDR_ST: begin
			arready_o	= 1;
			addr_sel	= 1;
		end

		RDATA_ST:
			rvalid_o	= 1;

		REG_WR_ST:
			reg_rw		= 1;

		MEM_WR_ST: begin
			oper_o		= 1;
			exec_o		= 1;
		end

		REG_RD_ST: begin
			reg_rw		= 0;
			sel_int		= 0;
			data_en		= 1;
		end

		MEM_RD_ST: begin
			oper_o		= 0;
			exec_o		= 1;
			sel_int		= 1;
			data_en		= 1;
		end

		//WR_ACK_ST:
		
		//RD_ACK_ST:
		
		BRESP_OK_ST: begin
			resp_en		= 1;	
			resp_int	= 2'b00;
		end

		BRESP_ERR_ST: begin
			resp_en		= 1;	
			resp_int	= 2'b10;
		end

		RRESP_OK_ST: begin
			resp_en		= 1;	
			resp_int	= 2'b00;
		end

		RRESP_ERR_ST: begin
			resp_en		= 1;	
			resp_int	= 2'b10;
		end

	endcase
end

// Output memory address computation.
assign addr_out	= addr_r - NREG_BYTE;

// Address mux.
assign addr_mux	= (addr_sel == 0)? awaddr_i : araddr_i;

// Data mux.
assign data_mux	= (sel_int == 0)? reg_int : dread_i;

// Mux for register.
assign reg_int	= 	(addr_r == 0)? reg0 :
					(addr_r == 4)? reg1 :
					(addr_r == 8)? reg2 :
					(addr_r == 12)? reg3 :
					(addr_r == 16)? reg4 :
					(addr_r == 20)? reg5 :
					(addr_r == 24)? reg6 :
					(addr_r == 28)? reg7 :
					0;

// Assign outputs.
assign bresp_o			= resp_r;
assign rresp_o			= resp_r;
assign rdata_o			= data_r;
assign addr_o			= addr_out[31:DATA_WIDTH_BYTE_LOG2];	// Byte to Sample-based.
assign dwrite_o			= wdata_r;
assign START_SRC_REG	= reg0[0];
assign START_REG 		= reg1[0];
assign MEM_MODE_REG		= reg2[0];
assign MEM_START_REG	= reg3[0];
assign MEM_ADDR_REG		= reg4;
assign MEM_LEN_REG		= reg5;

endmodule

