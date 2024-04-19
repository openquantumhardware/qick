module tb();

parameter [31:0] N_DDS = 2;

reg						rstn		;
reg						clk			;

wire	[N_DDS*16-1:0]	dds_dout_o	;

reg		[31:0]			PINC_REG	;
reg		[15:0]			GAIN_REG	;
reg						WE_REG		;


// DUT.
dds_top 
	#(
		.N_DDS(N_DDS)
	)
	DUT
	(
		// Reset and clock.
		.rstn			,
		.clk			,

		// DDS output.
		.dds_dout_o		,

		// Registers.
		.PINC_REG		,
		.GAIN_REG		,
		.WE_REG
	);

initial begin
	rstn <= 1'b0;
	PINC_REG	<= 0;
	GAIN_REG	<= 0;
	WE_REG		<= 0;
	#200;
	rstn <= 1'b1;

	#100;
	
	@(posedge clk);
	PINC_REG 	<= freq_calc(100, N_DDS, 1);
	WE_REG		<= 1'b1;
	#10;

	@(posedge clk);
	WE_REG		<= 1'b0;
end

always begin
	clk <= 0;
	#5;
	clk <= 1;
	#5;
end  

// Function to compute frequency register.
function [31:0] freq_calc;
    input int fclk;
    input int ndds;
    input int f;
    
	// All input frequencies are in MHz.
	real fs,temp;
	fs = fclk*ndds;
	temp = f/fs*2**30;
	freq_calc = {int'(temp),2'b00};
endfunction

endmodule

