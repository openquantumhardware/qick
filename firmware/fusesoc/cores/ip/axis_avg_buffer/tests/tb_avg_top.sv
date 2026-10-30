module tb();

// Memory depth.
parameter N = 10;

// Number of bits.
parameter B = 16;

// Ports.
reg					rstn;
reg					clk;

reg					trigger_i;

wire	[2*B-1:0]	din_i;

reg					m_axis_aclk;
reg					m_axis_aresetn;
wire				m_axis_tvalid;
reg					m_axis_tready;
wire	[4*B-1:0]	m_axis_tdata;
wire				m_axis_tlast;

reg					AVG_START_REG;
reg		[N-1:0]		AVG_ADDR_REG;
reg		[N-1:0]		AVG_LEN_REG;
reg					DR_START_REG;
reg		[N-1:0]		DR_ADDR_REG;
reg		[N-1:0]		DR_LEN_REG;

// Input data.
reg		[B-1:0]		di_r,dq_r;

// DUT.
avg_top
	#(
		.N	(N),
		.B	(B)
	)
	DUT
	(
		// Reset and clock.
		.rstn			(rstn			),
		.clk			(clk			),

		// Trigger input.
		.trigger_i		(trigger_i		),

		// Data input.
		.din_i			(din_i			),

		// AXIS Master for output.
		.m_axis_aclk	(m_axis_aclk	),
		.m_axis_aresetn	(m_axis_aresetn	),
		.m_axis_tvalid	(m_axis_tvalid	),
		.m_axis_tready	(m_axis_tready	),
		.m_axis_tdata	(m_axis_tdata	),
		.m_axis_tlast	(m_axis_tlast	),

		// Registers.
		.AVG_START_REG	(AVG_START_REG	),
		.AVG_ADDR_REG	(AVG_ADDR_REG	),
		.AVG_LEN_REG	(AVG_LEN_REG	),
		.DR_START_REG	(DR_START_REG	),
		.DR_ADDR_REG	(DR_ADDR_REG	),
		.DR_LEN_REG		(DR_LEN_REG		)
		);

assign din_i = {dq_r,di_r};

initial begin
	rstn			<= 0;
	trigger_i		<= 0;
	di_r			<= 0;
	dq_r			<= 0;
	AVG_START_REG	<= 0;
	AVG_ADDR_REG	<= 0;
	AVG_LEN_REG		<= 0;
	#200;
	rstn			<= 1;

	#200;

	@(posedge clk);
	AVG_ADDR_REG	<= 0;
	AVG_LEN_REG		<= 10;

	#200;

	@(posedge clk);
	AVG_START_REG	<= 1;

	#1000;

	for (int i=0; i<10; i = i + 1) begin
		@(posedge clk);
		di_r		<= 2*i;
		dq_r		<= -5*i;
		trigger_i	<= 1;
		@(posedge clk);
		trigger_i	<= 0;

		#1000;
	end

	@(posedge clk);
	AVG_START_REG	<= 0;

	#10000;
end

initial begin
	m_axis_aresetn	<= 0;
	m_axis_tready	<= 1;
	DR_START_REG	<= 0;
	DR_ADDR_REG		<= 0;
	DR_LEN_REG		<= 0;
	#200;
	m_axis_aresetn	<= 1;

	#20000;

	@(posedge m_axis_aclk);
	DR_ADDR_REG		<= 0;
	DR_LEN_REG		<= 10;

	@(posedge m_axis_aclk);
	DR_START_REG	<= 1;


end

always begin
	clk <= 0;
	#15;
	clk <= 1;
	#15;
end

always begin
	m_axis_aclk <= 0;
	#4;
	m_axis_aclk <= 1;
	#4;
end

endmodule

