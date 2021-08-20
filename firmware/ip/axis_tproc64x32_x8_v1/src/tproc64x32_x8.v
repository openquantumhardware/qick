module tproc64x32_x8
( 
	// Clock and reset.
	clk    			,
	rstn			,

	// Start/stop.
	start			,

	// Program Memory Interface.
	pmem_addr		,
	pmem_do			,

	// Data Memory Interface.
	dmem_we			,
	dmem_addr		,
	dmem_di			,
	dmem_do			,

	// Slave AXIS 0 for Input data.
	s0_axis_tdata	,
	s0_axis_tvalid	,
	s0_axis_tready	,

	// Slave AXIS 1 for Input data.
	s1_axis_tdata	,
	s1_axis_tvalid	,
	s1_axis_tready	,

	// Slave AXIS 2 for Input data.
	s2_axis_tdata	,
	s2_axis_tvalid	,
	s2_axis_tready	,

	// Slave AXIS 3 for Input data.
	s3_axis_tdata	,
	s3_axis_tvalid	,
	s3_axis_tready	,

	// Master AXIS 0 for Output data.
	m0_axis_tdata	,
	m0_axis_tvalid	,
	m0_axis_tready	,

	// Master AXIS 1 for Output data.
	m1_axis_tdata	,
	m1_axis_tvalid	,
	m1_axis_tready	,

	// Master AXIS 2 for Output data.
	m2_axis_tdata	,
	m2_axis_tvalid	,
	m2_axis_tready	,

	// Master AXIS 3 for Output data.
	m3_axis_tdata	,
	m3_axis_tvalid	,
	m3_axis_tready	,

	// Master AXIS 4 for Output data.
	m4_axis_tdata	,
	m4_axis_tvalid	,
	m4_axis_tready	,

	// Master AXIS 5 for Output data.
	m5_axis_tdata	,
	m5_axis_tvalid	,
	m5_axis_tready	,

	// Master AXIS 6 for Output data.
	m6_axis_tdata	,
	m6_axis_tvalid	,
	m6_axis_tready	,

	// Master AXIS 7 for Output data.
	m7_axis_tdata	,
	m7_axis_tvalid	,
	m7_axis_tready	,

	// Registers.
	START_SRC_REG 	,
	START_REG
);

// Parameters.
parameter N = 16;	// Program memory depth.
parameter M = 10;	// Data memory depth.

// Ports.
input 			clk;
input 			rstn;

input 			start;

output	[N-1:0]	pmem_addr;
input 	[63:0]	pmem_do;

output			dmem_we;
output	[M-1:0]	dmem_addr;
output	[31:0] 	dmem_di;
input	[31:0] 	dmem_do;

input	[63:0]	s0_axis_tdata;
input			s0_axis_tvalid;
output			s0_axis_tready;

input	[63:0]	s1_axis_tdata;
input			s1_axis_tvalid;
output			s1_axis_tready;

input	[63:0]	s2_axis_tdata;
input			s2_axis_tvalid;
output			s2_axis_tready;

input	[63:0]	s3_axis_tdata;
input			s3_axis_tvalid;
output			s3_axis_tready;

output	[159:0]	m0_axis_tdata;
output			m0_axis_tvalid;
input			m0_axis_tready;

output	[159:0]	m1_axis_tdata;
output			m1_axis_tvalid;
input			m1_axis_tready;

output	[159:0]	m2_axis_tdata;
output			m2_axis_tvalid;
input			m2_axis_tready;

output	[159:0]	m3_axis_tdata;
output			m3_axis_tvalid;
input			m3_axis_tready;

output	[159:0]	m4_axis_tdata;
output			m4_axis_tvalid;
input			m4_axis_tready;

output	[159:0]	m5_axis_tdata;
output			m5_axis_tvalid;
input			m5_axis_tready;

output	[159:0]	m6_axis_tdata;
output			m6_axis_tvalid;
input			m6_axis_tready;

output	[159:0]	m7_axis_tdata;
output			m7_axis_tvalid;
input			m7_axis_tready;

input			START_SRC_REG;
input			START_REG;

// Number of channels.
localparam NCH 	= 8;

// Bit-width.
localparam B	= 32;

// Master Clock Width.
localparam TW	= 48;

// Fifo-width: 5*B (registers) + TW (Master Clock) + 8 (opcode)
localparam FW	= 5*B + TW + 8;

// Synced regs.
wire 				START_SRC_REG_resync;
wire 				START_REG_resync;

// Muxed start.
wire 				start_i;

// Instruction fields.
wire	[7:0]		opcode_i;
wire	[2:0]		page_i;
wire	[2:0]		channel_i;
wire	[3:0]		oper_i;
wire 	[31:0]		imm_i;

// IR enable.
wire 				ir_en_i;

// Pogram counter out (jump instructions).
wire				pc_src_i;
wire				pc_en_i;
wire				pc_rst_i;

// Alu control.
wire	[B-1:0]		alu_a;
wire	[B-1:0]		alu_b;
wire	[1:0]		alu_src_b_i;
wire				alu_zero_i;
wire	[B-1:0]		alu_out;

// Alu Time control
wire				alut_src_b_i;

// Register write control.
wire	[2:0]		reg_src_i;
wire				reg_wen_i;

// Conditional control.
wire				cond_flag_i;

// Stack control.
wire				stack_en_i;
wire				stack_op_i;
wire	[B-1:0]		stack_din_i;
wire	[B-1:0]		stack_dout_i;
wire				stack_full_i;
wire				stack_empty_i;

// Read address.
wire	[4:0]		reg_addr0_i;
wire	[4:0]		reg_addr1_i;
wire	[4:0]		reg_addr2_i;
wire	[4:0]		reg_addr3_i;
wire	[4:0]		reg_addr4_i;
wire	[4:0]		reg_addr5_i;
wire	[4:0]		reg_addr6_i;

// Write address.
wire	[4:0]		reg_addr7_i;

// Write data.
wire	[B-1:0]		reg_din7_i;


// Output registers.
wire	[B-1:0]		reg_dout0_i;
wire	[B-1:0]		reg_dout1_i;
wire	[B-1:0]		reg_dout2_i;
wire	[B-1:0]		reg_dout3_i;
wire	[B-1:0]		reg_dout4_i;
wire	[B-1:0]		reg_dout5_i;
wire	[B-1:0]		reg_dout6_i;

// Program Counter.
wire	[15:0]	 	pc_i;
wire	[15:0]	 	pc_mux;
reg		[15:0]	 	pc_r;

// Instruction register.
reg		[63:0]	 	ir_r;

// Fifo for timed-instructions.
wire 	[NCH-1:0]	fifo_time_wr_en;
wire	[FW-1:0]	fifo_time_din;
wire	[NCH-1:0]	fifo_time_rd_en;
wire	[FW-1:0]	fifo_time_dout	[NCH-1:0];
wire	[NCH-1:0]	fifo_time_full;
wire	[NCH-1:0]	fifo_time_empty;

// Muxed fifo signals for control.
wire			 	fifo_wr_en_mux;
wire			 	fifo_full_mux;

// Data memory control.
wire	[M-1:0]		dmem_addr_mux;
wire				dmem_addr_src;

// Alu for time computation.
wire	[TW-1:0] 	alut_a;
wire	[TW-1:0] 	alut_b;
wire	[TW-1:0] 	alut_out;
reg		[TW-1:0] 	alut_out_r;

// Master clock.
reg		[TW-1:0] 	t_cnt;
wire 			 	t_cnt_en;
reg		[TW-1:0] 	t_cnt_sync;
wire			 	t_cnt_sync_en;

// Data memory output data register.
reg		[B-1:0]		dmem_do_r;

// Stack output register.
reg		[B-1:0]		stack_dout_r;

// Data input from external AXIS ports.
wire	[63:0]	 	din0_i;
wire	[63:0]	 	din1_i;
wire	[63:0]	 	din2_i;
wire	[63:0]	 	din3_i;
wire	[63:0]		din_mux;
wire	[31:0]		din_i;

// Wait handshake.
wire	[NCH-1:0]	waitt_i;
wire	[NCH-1:0]	waitt_ack_i;
wire			 	waitt_mux;
wire			 	waitt_ack_mux;

// Output AXIS.
wire	[159:0]		m_axis_tdata_i [NCH-1:0];
wire	[NCH-1:0]	m_axis_tvalid_i;
wire	[NCH-1:0]	m_axis_tready_i;

// START_SRC_REG_resync
synchronizer_n
	#(
		.N(2)
	)
	START_SRC_REG_resync_i
	(
		.rstn	    (rstn					),
		.clk 		(clk					),
		.data_in	(START_SRC_REG			),
		.data_out	(START_SRC_REG_resync	)
	);

// START_REG_resync
synchronizer_n
	#(
		.N(2)
	)
	START_REG_resync_i
	(
		.rstn	    (rstn				),
		.clk 		(clk				),
		.data_in	(START_REG			),
		.data_out	(START_REG_resync	)
	);

// Control block.
ctrl
    ctrl_i 
	( 
		// Clock and reset.
        .clk    		(clk 			),
		.rstn			(rstn			),

		// Start/stop.
		.start			(start_i		),

		// Opcode.
		.opcode			(opcode_i		),

		// IR control.
		.ir_en			(ir_en_i		),
		
		// Pogram counter out (jump instructions).
		.pc_src			(pc_src_i		),
		.pc_en			(pc_en_i		),
		.pc_rst			(pc_rst_i		),

		// Alu control.
		.alu_src_b		(alu_src_b_i	),
		.alu_zero		(alu_zero_i		),

		// Alu time control.
		.alut_src_b		(alut_src_b_i	),

		// Register write control.
		.reg_src		(reg_src_i		),
		.reg_wen		(reg_wen_i		),

		// Conditional control.
		.cond_flag		(cond_flag_i	),

		// Stack control.
		.stack_en		(stack_en_i 	),
		.stack_op		(stack_op_i  	),
		.stack_full		(stack_full_i	),
		.stack_empty	(stack_empty_i	),

		// Fifo Time control.
		.fifo_wr_en		(fifo_wr_en_mux	),
		.fifo_full		(fifo_full_mux	),

		// Data Memory control.
		.dmem_we		(dmem_we		),
		.addr_src		(dmem_addr_src	),

		// Master clock control.
		.t_en			(t_cnt_en		),
		.t_sync_en		(t_cnt_sync_en	),

		// Wait handshake.
		.waitt			(waitt_mux		),
		.waitt_ack		(waitt_ack_mux	)
    );

// Muxed start.
assign start_i	= (START_SRC_REG_resync == 1)? start : START_REG_resync;

// Instruction fields.
assign opcode_i		= ir_r[63:56];
assign page_i		= ir_r[55:53];
assign channel_i	= ir_r[52:50];
assign oper_i		= ir_r[49:46];
assign imm_i		= {ir_r[30],ir_r[30:0]};	// Sign-extend immediate to be 32-bit.

// Stack block.
stack
    #(
        // Data width.
        .B(B)
    )
    stack_i
	( 
		// Clock and reset.
        .clk    (clk 			),
		.rstn	(rstn			),

		// Enable and operation.
        .en		(stack_en_i		),
		.op		(stack_op_i		),

		// Input/Output data.
        .din   	(stack_din_i	),
        .dout   (stack_dout_i	),

		// Flags.
		.empty	(stack_empty_i	),
		.full	(stack_full_i	)
    );

// Stack input data.
assign stack_din_i	= reg_dout0_i;

// Regfile block.
regfile_8p
    #(
        // Data width.
        .B(B)
    )
    regfile_i 
	( 
		// Clock and reset.
        .clk    (clk    		),
		.rstn	(rstn			),

		// Read address.
        .addr0	(reg_addr0_i	),
		.addr1	(reg_addr1_i	),
        .addr2	(reg_addr2_i	),
		.addr3	(reg_addr3_i	),
		.addr4	(reg_addr4_i	),
		.addr5	(reg_addr5_i	),
		.addr6	(reg_addr6_i	),

		// Write address.
		.addr7	(reg_addr7_i	),

		// Write data.
		.din7	(reg_din7_i		),
		.wen7	(reg_wen_i		),

		// Page number.
		.pnum	(page_i			),

		// Output registers.
		.dout0	(reg_dout0_i	),
		.dout1	(reg_dout1_i	),
		.dout2	(reg_dout2_i	),
		.dout3	(reg_dout3_i	),
		.dout4	(reg_dout4_i	),
		.dout5	(reg_dout5_i	),
		.dout6	(reg_dout6_i	)
    );

// Register address.
assign reg_addr0_i	= ir_r[40:36];
assign reg_addr1_i	= ir_r[35:31];
assign reg_addr2_i	= ir_r[30:26];
assign reg_addr3_i	= ir_r[25:21];
assign reg_addr4_i	= ir_r[20:16];
assign reg_addr5_i	= ir_r[15:11];
assign reg_addr6_i	= ir_r[10:6];
assign reg_addr7_i	= ir_r[45:41];

// Mux for register data input.
assign reg_din7_i	=	(reg_src_i == 3'b000)? imm_i		:
						(reg_src_i == 3'b001)? alu_out		:
						(reg_src_i == 3'b010)? stack_dout_r	:
						(reg_src_i == 3'b011)? din_i		:
						(reg_src_i == 3'b100)? dmem_do_r	:
						imm_i;


// Instantiate fifo and timed_ictrl.
generate
genvar i;
	for (i = 0; i < NCH; i = i + 1 ) begin : GEN_channel
		// Fifo for dispatching timed-instructions.
		fifo
		    #(
		        // Data width.
		        .B	(FW	),
		        
		        // Fifo depth.
		        .N	(16	)
		    )
		    fifo_time_i
		    ( 
		        .rstn	(rstn				),
		        .clk 	(clk				),
		
		        // Write I/F.
		        .wr_en 	(fifo_time_wr_en[i]	),
		        .din    (fifo_time_din		),
		        
		        // Read I/F.
		        .rd_en  (fifo_time_rd_en[i]	),
		        .dout   (fifo_time_dout[i]	),
		        
		        // Flags.
		        .full   (fifo_time_full[i]	),
		        .empty  (fifo_time_empty[i]	)
		    );
	
		// Write enable mux.
		assign fifo_time_wr_en[i]	= (channel_i == i)? fifo_wr_en_mux : 1'b0;

		// Timed-instructions dispatcher control.
		timed_ictrl
		    timed_ictrl_i
			( 
				// Clock and reset.
		        .clk    		(clk				),
				.rstn			(rstn				),
		
				// Master clock.
				.t_cnt			(t_cnt				),
		
				// Fifo Time control.
				.fifo_rd_en		(fifo_time_rd_en[i]	),
				.fifo_dout		(fifo_time_dout[i]	),
				.fifo_empty		(fifo_time_empty[i]	),
		
				// Wait handshake.
				.waitt			(waitt_i[i]			),
				.waitt_ack		(waitt_ack_i[i]		),
		
				// Output AXIS.
				.m_axis_tdata	(m_axis_tdata_i[i]	),
				.m_axis_tvalid	(m_axis_tvalid_i[i]	),
				.m_axis_tready	(m_axis_tready_i[i]	)
		    );

		// Wait handshake.
		assign waitt_ack_i[i]	= (channel_i == i)? waitt_ack_mux : 1'b0;

	end
endgenerate

// Fifo Time input data (shared among channels).
// reg1 is reserved for time specification. reg0, reg2, reg3, reg4, reg5.
assign fifo_time_din = 	{	opcode_i	,
							alut_out_r	,
							reg_dout5_i ,
							reg_dout4_i ,
							reg_dout3_i ,
							reg_dout2_i ,
							reg_dout0_i	};

// Muxed fifo signals for control.
assign fifo_full_mux	= fifo_time_full[channel_i[2:0]];

// Wait handshake.
assign waitt_mux		= waitt_i[channel_i[2:0]];

// m_axis_tready signals.
assign m_axis_tready_i[0]	= m0_axis_tready;
assign m_axis_tready_i[1]	= m1_axis_tready;
assign m_axis_tready_i[2]	= m2_axis_tready;
assign m_axis_tready_i[3]	= m3_axis_tready;
assign m_axis_tready_i[4]	= m4_axis_tready;
assign m_axis_tready_i[5]	= m5_axis_tready;
assign m_axis_tready_i[6]	= m6_axis_tready;
assign m_axis_tready_i[7]	= m7_axis_tready;

// Data memory address mux.
assign dmem_addr_mux		= (dmem_addr_src == 1'b0)? imm_i : reg_dout0_i;

// Conditional logic.
cond
    #(
        // Data width.
        .B(B)
    )
    cond_i
	( 
		// Clock and reset.
        .clk   	(clk			),
		.rstn	(rstn			),

		// Input operands.
		.din_a	(reg_dout0_i	),
		.din_b	(reg_dout1_i	),

		// Operation.
		.op		(oper_i			),

		// Flag.
        .flag   (cond_flag_i	)
    );

// Alu for math and bit-wise operations.
alu
    #(
        // Data width.
        .B(B)
    )
    alu_i
	( 
		// Clock and reset.
        .clk   		(clk		),
		.rstn		(rstn		),

		// Input operands.
		.din_a		(alu_a		),
		.din_b		(alu_b		),

		// Operation.
		.op			(oper_i		),

		// Zero detection.
		.zero_a		(alu_zero_i	),
		.zero_b		(			),

		// Output.
        .dout   	(alu_out	)
    );

// Alu inputs.
assign alu_a	= reg_dout0_i;
assign alu_b	= 	(alu_src_b_i == 2'b00)? imm_i 		:
					(alu_src_b_i == 2'b01)? reg_dout1_i	:
					(alu_src_b_i == 2'b10)? -1			:
					0;

// Slave AXIS 0 read block.
s_axis_read
    #(
        // Data width.
        .B(64)
    )
    s0_axis_read_i
	( 
		// Clock and reset.
        .clk    		(clk			),
		.rstn			(rstn			),

		// AXIS Slave.
		.s_axis_tdata	(s0_axis_tdata 	),
		.s_axis_tvalid	(s0_axis_tvalid	),
		.s_axis_tready	(s0_axis_tready	),

		// Output data.
		.dout			(din0_i			)
    );

// Slave AXIS 1 read block.
s_axis_read
    #(
        // Data width.
        .B(64)
    )
    s1_axis_read_i
	( 
		// Clock and reset.
        .clk    		(clk			),
		.rstn			(rstn			),

		// AXIS Slave.
		.s_axis_tdata	(s1_axis_tdata 	),
		.s_axis_tvalid	(s1_axis_tvalid	),
		.s_axis_tready	(s1_axis_tready	),

		// Output data.
		.dout			(din1_i			)
    );

// Slave AXIS 2 read block.
s_axis_read
    #(
        // Data width.
        .B(64)
    )
    s2_axis_read_i
	( 
		// Clock and reset.
        .clk    		(clk			),
		.rstn			(rstn			),

		// AXIS Slave.
		.s_axis_tdata	(s2_axis_tdata 	),
		.s_axis_tvalid	(s2_axis_tvalid	),
		.s_axis_tready	(s2_axis_tready	),

		// Output data.
		.dout			(din2_i			)
    );

// Slave AXIS 3 read block.
s_axis_read
    #(
        // Data width.
        .B(64)
    )
    s3_axis_read_i
	( 
		// Clock and reset.
        .clk    		(clk			),
		.rstn			(rstn			),

		// AXIS Slave.
		.s_axis_tdata	(s3_axis_tdata 	),
		.s_axis_tvalid	(s3_axis_tvalid	),
		.s_axis_tready	(s3_axis_tready	),

		// Output data.
		.dout			(din3_i			)
    );

// Data input mux.
assign din_mux	=	(channel_i == 0)?	din0_i	:
					(channel_i == 1)?	din1_i	:
					(channel_i == 2)?	din2_i	:
					(channel_i == 3)?	din3_i	:
					0;

// Low/high part selection.
assign din_i	=	(oper_i == 4'b1010)? din_mux[32 +:32]	:
					din_mux[0 +: 32];

// Alu for time inputs.
assign alut_a	= t_cnt_sync;
assign alut_b	= (alut_src_b_i == 0)? reg_dout1_i : imm_i;
assign alut_out	= alut_a + alut_b;

// Registers.
always @(posedge clk) begin
	if (~rstn) begin
		// Program counter.
		pc_r			<= 0;

		// Instruction counter.
		ir_r			<= 0;

		// ALU t output register.
		alut_out_r		<= 0;

		// Master clock.
		t_cnt			<= 0;
		t_cnt_sync		<= 0;

		// Data memory output data register.
		dmem_do_r		<= 0;

		// Stack output register.
		stack_dout_r	<= 0;
	end
	else begin
		// Program counter.
		if (pc_rst_i)
			pc_r <= 0;
		else if (pc_en_i)
			pc_r <= pc_mux;

		// Instruction counter.
		if (ir_en_i)
			ir_r <= pmem_do;

		// ALU t output register.
		alut_out_r	<= alut_out;

		// Master clock.
		if (pc_rst_i)
			t_cnt <= 0;
		else if (t_cnt_en)
			t_cnt <= t_cnt + 1;
		
		if (pc_rst_i)
			t_cnt_sync <= 0;
		else if (t_cnt_sync_en)
			t_cnt_sync	<= alut_out_r;

		// Data memory output data register.
		dmem_do_r		<= dmem_do;

		// Stack output register.
		stack_dout_r	<= stack_dout_i;
	end
end

// Program counter.
assign pc_i				= pc_r + 1;
assign pc_mux			= (pc_src_i == 1)? imm_i : pc_i;

// Assign outputs.
assign pmem_addr		= pc_r;

// Data memory interface.
assign dmem_addr		= dmem_addr_mux;
assign dmem_di			= reg_dout1_i;

// Master AXIS 0 for Output data.
assign m0_axis_tdata	= m_axis_tdata_i[0];
assign m0_axis_tvalid	= m_axis_tvalid_i[0];

// Master AXIS 1 for Output data.
assign m1_axis_tdata	= m_axis_tdata_i[1];
assign m1_axis_tvalid	= m_axis_tvalid_i[1];

// Master AXIS 2 for Output data.
assign m2_axis_tdata	= m_axis_tdata_i[2];
assign m2_axis_tvalid	= m_axis_tvalid_i[2];

// Master AXIS 3 for Output data.
assign m3_axis_tdata	= m_axis_tdata_i[3];
assign m3_axis_tvalid	= m_axis_tvalid_i[3];

// Master AXIS 4 for Output data.
assign m4_axis_tdata	= m_axis_tdata_i[4];
assign m4_axis_tvalid	= m_axis_tvalid_i[4];

// Master AXIS 5 for Output data.
assign m5_axis_tdata	= m_axis_tdata_i[5];
assign m5_axis_tvalid	= m_axis_tvalid_i[5];

// Master AXIS 6 for Output data.
assign m6_axis_tdata	= m_axis_tdata_i[6];
assign m6_axis_tvalid	= m_axis_tvalid_i[6];

// Master AXIS 7 for Output data.
assign m7_axis_tdata	= m_axis_tdata_i[7];
assign m7_axis_tvalid	= m_axis_tvalid_i[7];

endmodule

