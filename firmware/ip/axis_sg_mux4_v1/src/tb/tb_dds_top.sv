module tb();

// DUT generics.
parameter N_DDS = 3;

reg						rstn;
reg						clk;

wire 	[N_DDS*32-1:0]	dds_dout_o;

reg		[15:0]			PINC_REG;
reg						WE_REG;

// Assignment of data out for debugging.
wire	[31:0]			dout_ii [0:N_DDS-1];

// Test bench control.
reg	tb_write_out 		= 0;

// Debug.
generate
genvar ii;
for (ii = 0; ii < N_DDS; ii = ii + 1) begin : GEN_debug
    assign dout_ii[ii] = dds_dout_o[32*ii +: 32];
end
endgenerate

// DUT.
dds_top
	#(
		.N_DDS(N_DDS)
	)
	DUT	
 	(
		// Reset and clock.
		.rstn			(rstn		),
		.clk			(clk		),

		// DDS output.
		.dds_dout_o		(dds_dout_o	),

		// Registers.
		.PINC_REG		(PINC_REG	),
		.WE_REG			(WE_REG		)
	);

initial begin
	// Reset sequence.
	rstn	<= 0;
	WE_REG	<= 0;
	#500;
	rstn 	<= 1;

	#1000;
	
	PINC_REG	<= freq_calc(100, N_DDS, 10);
	WE_REG		<= 1;
	#100;
	WE_REG		<= 0;

end

always begin
	clk <= 0;
	#5;
	clk <= 1;
	#5;
end  

// Function to compute frequency register.
function [15:0] freq_calc;
    input int fclk;
    input int ndds;
    input int f;
    
	// All input frequencies are in MHz.
	real fs,temp;
	fs = fclk*ndds;
	temp = f/fs*2**16;
	freq_calc = int'(temp);
endfunction

endmodule

