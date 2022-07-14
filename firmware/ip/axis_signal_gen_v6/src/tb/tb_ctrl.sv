module tb();

// Memory address size.
parameter N = 16;

// Number of parallel dds blocks.
parameter N_DDS = 2;

// Ports.
reg					rstn;
reg					clk;

wire				fifo_rd_en_o;
reg					fifo_empty_i;
wire[159:0]			fifo_dout_i;
wire[N_DDS*72-1:0]	dds_ctrl_o;
wire[N-1:0]			mem_addr_o;
wire[15:0]			gain_o;
wire[1:0]			src_o;
wire				stdy_o;
wire				en_o;

// Fifo signals.
reg				fifo_wr_en;
wire[159:0]		fifo_din;
wire			fifo_full;

// Fifo Fields.
reg		[31:0]	freq_r;
reg		[31:0]	phase_r;
reg		[15:0]	addr_r;
reg		[15:0]	gain_r;
reg		[15:0]	nsamp_r;
reg		[1:0]	outsel_r;
reg				mode_r;
reg				stdysel_r;
reg				phrst_r;

// Assignment of DDSs for debugging.
wire	[71:0]	dds_ctrl_ii [0:N_DDS-1];

integer i;

generate
genvar ii;
for (ii = 0; ii < N_DDS; ii = ii + 1) begin : GEN_debug
    assign dds_ctrl_ii[ii] = dds_ctrl_o[72*ii +: 72];
end
endgenerate

// Fifo.
fifo
    #(
        // Data width.
        .B	(160),
        
        // Fifo depth.
        .N	(16)
    )
    fifo_i
	( 
        .rstn	(rstn			),
        .clk 	(clk			),

        // Write I/F.
        .wr_en 	(fifo_wr_en		),
        .din    (fifo_din		),
        
        // Read I/F.
        .rd_en 	(fifo_rd_en_o	),
        .dout  	(fifo_dout_i	),
        
        // Flags.
        .full   (fifo_full		),
        .empty  (fifo_empty_i	)
    );

// DUT.
ctrl 
	#(
		.N		(N		),
		.N_DDS	(N_DDS	)
	)
	DUT
	(
		// Reset and clock.
		.rstn			(rstn			),
		.clk			(clk			),

		// Fifo interface.
		.fifo_rd_en_o	(fifo_rd_en_o	),
		.fifo_empty_i	(fifo_empty_i	),
		.fifo_dout_i	(fifo_dout_i	),

		// dds control.
		.dds_ctrl_o		(dds_ctrl_o		),

		// memory control.
		.mem_addr_o		(mem_addr_o		),

		// gain.
		.gain_o			(gain_o			),

		// Output source selection.
		.src_o			(src_o			),

		// Steady value selection.
		.stdy_o			(stdy_o			),
		
		// Output enable.
		.en_o			(en_o			)
		);

assign fifo_din = {	{11{1'b0}}	,
					phrst_r		,
					stdysel_r	,
					mode_r		,
					outsel_r	,
					nsamp_r		,
					{16{1'b0}}	,
					gain_r		,
					{16{1'b0}}	,
					addr_r		,
					phase_r		,
					freq_r		};

initial begin
	rstn			<= 0;
	fifo_wr_en		<= 0;
	freq_r			<= 0;
	phase_r			<= 0;
	addr_r			<= 0;
	gain_r			<= 0;
	nsamp_r			<= 0;
	outsel_r		<= 0;
	mode_r			<= 0;
	stdysel_r		<= 0;
	phrst_r			<= 0;
	#200;
	rstn			<= 1;

	#200;

	@(posedge clk);
	fifo_wr_en	<= 1;
	freq_r		<= 100;
	phase_r		<= 0;
	addr_r		<= 50;
	gain_r		<= 40;
	nsamp_r		<= 10;
	outsel_r	<= 2;
	mode_r		<= 1;
	stdysel_r	<= 0;
	phrst_r		<= 1;

	@(posedge clk);
	fifo_wr_en	<= 0;

	#1000;

	@(posedge clk);
	fifo_wr_en	<= 1;
	freq_r		<= 3516;
	phase_r		<= 2345;
	addr_r		<= 5;
	gain_r		<= 4;
	nsamp_r		<= 5;
	outsel_r	<= 2;
	mode_r		<= 0;
	stdysel_r	<= 1;
	phrst_r		<= 0;

	@(posedge clk);
	fifo_wr_en	<= 0;

	#10000;
	
end

always begin
	clk <= 0;
	#10;
	clk <= 1;
	#10;
end

endmodule

