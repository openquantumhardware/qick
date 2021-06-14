module random_gen
	#(
		parameter W 	= 16	,
		parameter SEED 	= 0
	)
	(
		input					rstn	,
		input 					clk		,
		output 	[W-1 : 0]		dout
	);

reg		[W-1 : 0] 	rand_out;
reg		[W-1 : 0]	rand_ff;

reg		[W-1 : 0]	dout_r1;
reg		[W-1 : 0]	dout_r2;
reg		[W-1 : 0]	dout_r3;
reg		[W-1 : 0]	dout_r4;

localparam seed_int = 24'b 0110_0011_0111_0110_1001_1101 + SEED;
	
// LFSR.
always @(posedge clk) begin
	if(rstn == 1'b 0) begin
		rand_ff[W-1 :0] <= seed_int; // seed for pseudo random number sequencer
		rand_out <= {W-1{1'b 0}};
	end
	else begin
		case (W) 
			24 		:	begin
							rand_ff[W-1 : 0] <= { ( rand_ff[7] ^ rand_ff[2] ^ rand_ff[1] ^ rand_ff[0]) , rand_ff[W-1 : 1] };    				// x^24 + x^23 + x^22 + x^17 + 
							rand_out <=  rand_ff;
						end
			23 		:	begin
							rand_ff[W-1 : 0] <= { ( rand_ff[5] ^ rand_ff[0] ) , rand_ff[W-1 : 1] };    																// x^23+ x^18 + 
							rand_out <=  rand_ff;
						end
			22 		:	begin
							rand_ff[W-1 : 0] <= { ( rand_ff[1] ^ rand_ff[0] ) , rand_ff[W-1 : 1] };    																// x^22+ x^21 + 
							rand_out <=  rand_ff;			
						end
			21 		:	begin
							rand_ff[W-1 : 0] <= { ( rand_ff[2] ^ rand_ff[0] ), rand_ff[W-1 : 1] };         															// x^21+ x^19 + 
							rand_out <=  rand_ff;			
						end
			20		:	begin
							rand_ff[W-1 : 0] <= { ( rand_ff[3] ^ rand_ff[0] ), rand_ff[W-1 : 1] };       																// x^20+ x^17 + 
							rand_out <=  rand_ff;									
						end										
			19		:	begin
							rand_ff[W-1 : 0] <= { ( rand_ff[15] ^ rand_ff[13] ^ rand_ff[0] ), rand_ff[W-1 : 1] };        								// x^19 + x^5 + x^2 + 1 
							rand_out <=  rand_ff;									
						end
			18		:	begin
							rand_ff[W-1 : 0] <= { ( rand_ff[7] ^ rand_ff[0] ) , rand_ff[W-1 : 1] };      																// x^18 + x^11 + 
							rand_out <=  rand_ff;							
						end
			17 		:	begin
							rand_ff[W-1 : 0] <= { ( rand_ff[3] ^ rand_ff[0] ) , rand_ff[W-1 : 1] };      																// x^17 + x^14 + 
							rand_out <=  rand_ff;									
						end										
			16 		:	begin
							rand_ff[W-1 : 0] <= { ( rand_ff[5] ^ rand_ff[3] ^ rand_ff[2] ^ rand_ff[0]) , rand_ff[W-1 : 1] };        			// x^16 + x^14 + x^13 + x^11 + 
							rand_out <=  rand_ff;										
						end
			15		:	begin
							rand_ff[W-1 : 0] <= { ( rand_ff[1] ^ rand_ff[0] ), rand_ff[W-1 : 1] };       																// x^15 + x^14 + 
							rand_out <=  rand_ff;							
						end
			14 		:	begin
							rand_ff[W-1 : 0] <= { ( rand_ff[12] ^ rand_ff[2] ^ rand_ff[1] ^ rand_ff[0]), rand_ff[W-1 : 1] };    				// x^14 + x^13 + x^12 + x^2 + 
							rand_out <=  rand_ff;								
						end
			13		:	begin
							rand_ff[W-1 : 0] <= { ( rand_ff[5] ^ rand_ff[2] ^ rand_ff[1] ^ rand_ff[0] ), rand_ff[W-1 : 1] };       			// x^13 + x^12 + x^11 + x^8 + 
							rand_out <=  rand_ff;							
						end
			12 		:	begin
							rand_ff[W-1 : 0] <= { ( rand_ff[8] ^ rand_ff[2] ^ rand_ff[1] ^ rand_ff[0] ), rand_ff[W-1 : 1] };      			// x^12 + x^11 + x^10 + x^4 + 
							rand_out <=  rand_ff;										
						end
			11 		:	begin
							rand_ff[W-1 : 0] <= { ( rand_ff[1] ^ rand_ff[0] ), rand_ff[W-1 : 1] };      																// x^11 + x^9 + 
							rand_out <=  rand_ff;								
						end
			10 		:	begin
							rand_ff[W-1 : 0] <= { ( rand_ff[3] ^ rand_ff[0] ), rand_ff[W-1 : 1] };   																	// x^10 + x^7 + 
							rand_out <=  rand_ff;	
						end
			9 		:	begin
							rand_ff[W-1 : 0] <= { ( rand_ff[4] ^ rand_ff[0] ), rand_ff[W-1 : 1] };       																// x^9 + x^5 + 
							rand_out <=  rand_ff;								
						end
			8		:	begin
							rand_ff[W-1 : 0] <= { ( rand_ff[4] ^ rand_ff[3] ^ rand_ff[2] ^ rand_ff[0]), rand_ff[W-1 : 1] };     				// x^8 + x^6 + x^5 + x^4 + 
							rand_out <=  rand_ff;								
						end
			7		:	begin
							rand_ff[W-1 : 0] <= { ( rand_ff[1] ^ rand_ff[0] ) , rand_ff[W-1 : 1] };     																// x^7 + x^6 + 
							rand_out <=  rand_ff;
						end
			6		:	begin
							rand_ff[W-1 : 0] <= { ( rand_ff[1] ^ rand_ff[0] ) , rand_ff[W-1 : 1] };       															// x^6 + x^5 + 
							rand_out <=  rand_ff;								
						end
			5 		:	begin
							rand_ff[W-1 : 0] <= { ( rand_ff[2] ^ rand_ff[0] ), rand_ff[W-1 : 1] };      															// x^5 + x^3 + 
							rand_out <=  rand_ff;		
						end
			default	:	begin
							rand_ff[W-1 : 0] <= { (rand_ff[1] ^ rand_ff[0]) , rand_ff[W-1 : 0]};																	// x^4 + x^3 + 
							rand_out <=  rand_ff;										
						end
		endcase
	end
end

// Output register.
always @(posedge clk) begin
	if (rstn == 1'b0) begin
		dout_r1	<= 0;
		dout_r2	<= 0;
		dout_r3	<= 0;
		dout_r4	<= 0;
	end
	else begin
		dout_r1	<= rand_out;
		dout_r2	<= dout_r1;
		dout_r3	<= dout_r2;
		dout_r4	<= dout_r3;
	end
end

assign dout = dout_r4;

endmodule

