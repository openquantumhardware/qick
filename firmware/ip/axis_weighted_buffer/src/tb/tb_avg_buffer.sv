module tb();

// Memory depth.
parameter N_AVG = 10;
parameter N_BUF = 10;

// Number of bits.
parameter B = 16;

// Ports.
reg					s_axis_aclk;
reg					s_axis_aresetn;

reg					trigger;

reg					s_axis_tvalid;
wire				s_axis_tready;
reg		[2*B-1:0]	s_axis_tdata;

reg					m_axis_aclk;
reg					m_axis_aresetn;

wire				m0_axis_tvalid;
reg					m0_axis_tready;
wire	[4*B-1:0]	m0_axis_tdata;
wire				m0_axis_tlast;

wire				m1_axis_tvalid;
reg					m1_axis_tready;
wire	[2*B-1:0]	m1_axis_tdata;
wire				m1_axis_tlast;

reg					AVG_START_REG;
reg		[N_AVG-1:0]	AVG_ADDR_REG;
reg		[N_AVG-1:0]	AVG_LEN_REG;
reg					AVG_DR_START_REG;
reg		[N_AVG-1:0]	AVG_DR_ADDR_REG;
reg		[N_AVG-1:0]	AVG_DR_LEN_REG;
reg					BUF_START_REG;
reg		[N_BUF-1:0]	BUF_ADDR_REG;
reg		[N_BUF-1:0]	BUF_LEN_REG;
reg					BUF_DR_START_REG;
reg		[N_BUF-1:0]	BUF_DR_ADDR_REG;
reg		[N_BUF-1:0]	BUF_DR_LEN_REG;

// Input data.
reg		[B-1:0]		di_r,dq_r;

// DUT.
avg_buffer
	#(
		.N_AVG	(N_AVG	),
		.N_BUF	(N_BUF	),
		.B		(B		)
	)
	DUT
	(
		// Reset and clock for s.
		.s_axis_aclk		(s_axis_aclk		),
		.s_axis_aresetn		(s_axis_aresetn		),

		// Trigger input.
		.trigger			(trigger			),

		// AXIS Slave for input data.
		.s_axis_tvalid		(s_axis_tvalid		),
		.s_axis_tready		(s_axis_tready		),
		.s_axis_tdata		(s_axis_tdata		),

		// Reset and clock for m0 and m1.
		.m_axis_aclk		(m_axis_aclk   		),
		.m_axis_aresetn		(m_axis_aresetn		),

		// AXIS Master for averaged output.
		.m0_axis_tvalid		(m0_axis_tvalid		),
		.m0_axis_tready		(m0_axis_tready		),
		.m0_axis_tdata		(m0_axis_tdata		),
		.m0_axis_tlast		(m0_axis_tlast		),

		// AXIS Master for raw output.
		.m1_axis_tvalid		(m1_axis_tvalid		),
		.m1_axis_tready		(m1_axis_tready		),
		.m1_axis_tdata		(m1_axis_tdata		),
		.m1_axis_tlast		(m1_axis_tlast		),

		// Registers.
		.AVG_START_REG		(AVG_START_REG		),
		.AVG_ADDR_REG		(AVG_ADDR_REG		),
		.AVG_LEN_REG		(AVG_LEN_REG		),
		.AVG_DR_START_REG	(AVG_DR_START_REG	),
		.AVG_DR_ADDR_REG	(AVG_DR_ADDR_REG	),
		.AVG_DR_LEN_REG		(AVG_DR_LEN_REG		),
		.BUF_START_REG		(BUF_START_REG		),
		.BUF_ADDR_REG		(BUF_ADDR_REG		),
		.BUF_LEN_REG		(BUF_LEN_REG		),
		.BUF_DR_START_REG	(BUF_DR_START_REG	),
		.BUF_DR_ADDR_REG	(BUF_DR_ADDR_REG	),
		.BUF_DR_LEN_REG		(BUF_DR_LEN_REG		)
	);

assign s_axis_tdata = {dq_r,di_r};

initial begin
	s_axis_aresetn		<= 0;
	trigger				<= 0;
	s_axis_tvalid		<= 1;
	di_r				<= 0;
	dq_r				<= 0;
	AVG_START_REG		<= 0;
	AVG_ADDR_REG		<= 0;
	AVG_LEN_REG			<= 0;
	BUF_START_REG		<= 0;
	BUF_ADDR_REG		<= 0;
	BUF_LEN_REG			<= 0;
	#200;
	s_axis_aresetn		<= 1;

	#200;

	@(posedge s_axis_aclk);
	AVG_ADDR_REG		<= 0;
	AVG_LEN_REG			<= 10;
	BUF_ADDR_REG		<= 0;
	BUF_LEN_REG			<= 10;

	#200;

	@(posedge s_axis_aclk);
	AVG_START_REG		<= 1;
	BUF_START_REG		<= 1;

	#1000;

	for (int i=0; i<10; i = i + 1) begin
		@(posedge s_axis_aclk);
		di_r		<= 2*i;
		dq_r		<= -5*i;
		trigger		<= 1;
		@(posedge s_axis_aclk);
		trigger		<= 0;

		#1000;
	end

	@(posedge s_axis_aclk);
	AVG_START_REG		<= 0;
	BUF_START_REG		<= 0;

	#10000;
end

initial begin
	m_axis_aresetn		<= 0;
	m0_axis_tready		<= 1;
	m1_axis_tready		<= 1;
	AVG_DR_START_REG	<= 0;
	AVG_DR_ADDR_REG		<= 0;
	AVG_DR_LEN_REG		<= 0;
	BUF_DR_START_REG	<= 0;
	BUF_DR_ADDR_REG		<= 0;
	BUF_DR_LEN_REG		<= 0;
	#200;
	m_axis_aresetn	<= 1;

	#20000;

	@(posedge m_axis_aclk);
	AVG_DR_ADDR_REG		<= 0;
	AVG_DR_LEN_REG		<= 10;
	BUF_DR_ADDR_REG		<= 0;
	BUF_DR_LEN_REG		<= 100;

	@(posedge m_axis_aclk);
	AVG_DR_START_REG	<= 1;
	BUF_DR_START_REG	<= 1;

end

always begin
	s_axis_aclk <= 0;
	#15;
	s_axis_aclk <= 1;
	#15;
end

always begin
	m_axis_aclk <= 0;
	#4;
	m_axis_aclk <= 1;
	#4;
end

endmodule

