// ALU block integrating math and bitw.
//
// 0000 : din_a and din_b
// 0001 : din_a or din_b
// 0010 : din_a xor din_b
// 0011 : not(din_a)
// 0100 : din_a << din_b
// 0101 : din_a >> din_b
// 1000 : din_a + 	din_b
// 1001 : din_a - 	din_b
// 1010 : din_a * 	din_b

module alu
	(
		// Clock and reset.
        clk    		,
		rstn		,

		// Input operands.
		din_a		,
		din_b		,

		// Operation.
		op			,

		// Zero detection.
		zero_a		,
		zero_b		,

		// Output.
        dout
    );

// Data width.
parameter B = 16;

// Ports.
input			clk;
input			rstn;

input	[B-1:0]	din_a;
input	[B-1:0]	din_b;

input	[3:0]	op;

output			zero_a;
output			zero_b;

output	[B-1:0]	dout;

// Registers to account latency.
reg		[3:0]	op_r;
reg		[3:0]	op_rr;
reg		[3:0]	op_rrr;

// Operation.
wire	[3:0]	oper_i;
wire			sel;

// Outputs.
wire	[B-1:0]	math_dout;
wire	[B-1:0]	bitw_dout;

// Math block.
math
    #(
        // Data width.
        .B(B)
    )
    math_i
	( 
		// Clock and reset.
        .clk   		(clk		),
		.rstn		(rstn		),

		// Input operands.
		.din_a		(din_a		),
		.din_b		(din_b		),

		// Operation.
		.op			(oper_i		),

		// Zero detection.
		.zero_a		(zero_a		),
		.zero_b		(zero_b		),

		// Output.
        .dout    	(math_dout	)
    );

// Bitw block.
bitw
    #(
        // Data width.
        .B(B)
    )
    bitw_i
	( 
		// Clock and reset.
        .clk   	(clk		),
		.rstn	(rstn		),

		// Input operands.
		.din_a	(din_a		),
		.din_b	(din_b		),

		// Operation.
		.op		(oper_i		),

		// Output.
        .dout   (bitw_dout	)
    );

// Registers.
always @(posedge clk) begin
	if (~rstn) begin
		// Registers to account latency.
		op_r	<= 0;
		op_rr	<= 0;
		op_rrr	<= 0;

	end else
		// Registers to account latency.
		op_r	<= op;
		op_rr	<= op_r;
		op_rrr	<= op_rr;
	begin

	end
end

// Operation.
assign oper_i	= {1'b0,op[2:0]};
assign sel		= op_rrr[3];

// Output mux.
assign dout	= (sel == 0)? bitw_dout : math_dout;

endmodule

