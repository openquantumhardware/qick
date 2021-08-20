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

wire				mem_we_o;
wire	[N-1:0]		mem_addr_o;
wire 	[4*B-1:0]	mem_di_o;

reg					START_REG;
reg		[N-1:0]		ADDR_REG;
reg		[N-1:0]		LEN_REG;

// Input data.
reg		[B-1:0]		di_r,dq_r;

// DUT.
avg
	#(
		.N	(N),
		.B	(B)
	)
	DUT
	(
		// Reset and clock.
		.rstn		(rstn		),
		.clk		(clk		),

		// Trigger input.
		.trigger_i	(trigger_i	),

		// Data input.
		.din_i		(din_i		),

		// Memory interface.
		.mem_we_o	(mem_we_o	),
		.mem_addr_o	(mem_addr_o	),
		.mem_di_o	(mem_di_o	),

		// Registers.
		.START_REG	(START_REG	),
		.ADDR_REG	(ADDR_REG	),
		.LEN_REG	(LEN_REG	)
		);

assign din_i = {dq_r,di_r};

initial begin
	rstn		<= 0;
	trigger_i	<= 0;
	di_r		<= 0;
	dq_r		<= 0;
	START_REG	<= 0;
	ADDR_REG	<= 0;
	LEN_REG		<= 0;
	#200;
	rstn		<= 1;

	#200;

	@(posedge clk);
	ADDR_REG	<= 0;
	LEN_REG		<= 10;

	#200;

	@(posedge clk);
	START_REG	<= 1;

	#1000;

	for (int i=0; i<10; i = i + 1) begin
		@(posedge clk);
		di_r		<= 2*i;
		dq_r		<= -5*i;
		trigger_i	<= 1;
		@(posedge clk);
		trigger_i	<= 0;

		wait (mem_we_o == 1'b1);

		#100;
	end

	@(posedge clk);
	START_REG	<= 0;

	@(posedge clk);
	ADDR_REG	<= 7;
	LEN_REG		<= 100;
	di_r		<= 123;
	dq_r		<= -37;

	#200;

	@(posedge clk);
	START_REG	<= 1;

	for (int i=0; i<5; i = i + 1) begin
		@(posedge clk);
		trigger_i	<= 1;
		@(posedge clk);
		trigger_i	<= 0;

		wait (mem_we_o == 1'b1);

		#100;
	end

	@(posedge clk);
	START_REG	<= 0;

	#10000;
end

always begin
	clk <= 0;
	#5;
	clk <= 1;
	#5;
end

endmodule

