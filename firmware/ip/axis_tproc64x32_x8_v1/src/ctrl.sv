/* tProcessor control state machine.
This version works with 32-bit registers. To avoid modifying the whole instruction structure,
immediate value from instruction is 31 bits. It's sign-extended to get the 32-bit register
value before operating with it. It applies to I-Type instructions only.
*/
//
// Instructions:
//
// ##############
// ### I-Type ###
// ##############
//
// I-Type: immediate type. Three registers and an immediate value.
//
// |----------|----------|----------|----------|----------|----------|----------|---------|
// | 63 .. 56 | 55 .. 53 | 52 .. 50 | 49 .. 46 | 45 .. 41 | 40 .. 36 | 35 .. 31 | 30 .. 0 |
// |----------|----------|----------|----------|----------|----------|----------|---------|
// | opcode   | page     | channel  | oper     | ra       | rb       | rc       | imm     |
// |----------|----------|----------|----------|----------|----------|----------|---------|
//
// pushi p, $ra, $rb, imm : push the content of register $ra into the stack. Load register
// $rb with imm value. Registers $ra and $rb can be the same. $p indicates the page of the
// regfile.
// |----------|----------|----------|----------|----------|----------|----------|---------|
// | 63 .. 56 | 55 .. 53 | 52 .. 50 | 49 .. 46 | 45 .. 41 | 40 .. 36 | 35 .. 31 | 30 .. 0 |
// |----------|----------|----------|----------|----------|----------|----------|---------|
// | 00010000 | page     | xxxxxxx  | xxxx     | rb       | ra       | xx       | imm     |
// |----------|----------|----------|----------|----------|----------|----------|---------|
//
// popi $p, $r : pop the content of the stack into register $r.
// |----------|----------|----------|----------|----------|----------|----------|---------|
// | 63 .. 56 | 55 .. 53 | 52 .. 50 | 49 .. 46 | 45 .. 41 | 40 .. 36 | 35 .. 31 | 30 .. 0 |
// |----------|----------|----------|----------|----------|----------|----------|---------|
// | 00010001 | page     | xxxxxxx  | xxxx     | r        | xx       | xx       | xxx     |
// |----------|----------|----------|----------|----------|----------|----------|---------|
//
// mathi $p, $ra, $rb oper imm : operation as $ra = $rb oper imm.
// oper :
// 1000 : $rb + imm
// 1001 : $rb - imm
// 1010 : $rb * imm
// |----------|----------|----------|----------|----------|----------|----------|---------|
// | 63 .. 56 | 55 .. 53 | 52 .. 50 | 49 .. 46 | 45 .. 41 | 40 .. 36 | 35 .. 31 | 30 .. 0 |
// |----------|----------|----------|----------|----------|----------|----------|---------|
// | 00010010 | page     | xxxxxxx  | oper     | ra       | rb       | xx       | imm     |
// |----------|----------|----------|----------|----------|----------|----------|---------|
//
// seti ch, p, $r, t : set value on register $r at time t for channel ch.
// |----------|----------|----------|----------|----------|----------|----------|---------|
// | 63 .. 56 | 55 .. 53 | 52 .. 50 | 49 .. 46 | 45 .. 41 | 40 .. 36 | 35 .. 31 | 30 .. 0 |
// |----------|----------|----------|----------|----------|----------|----------|---------|
// | 00010011 | page     | channel  | xxxx     | xx       | r        | xx       | t       |
// |----------|----------|----------|----------|----------|----------|----------|---------|
//
// synci t : sync master clock to t for upcoming instructions.
// |----------|----------|----------|----------|----------|----------|----------|---------|
// | 63 .. 56 | 55 .. 53 | 52 .. 50 | 49 .. 46 | 45 .. 41 | 40 .. 36 | 35 .. 31 | 30 .. 0 |
// |----------|----------|----------|----------|----------|----------|----------|---------|
// | 00010100 | xxxx     | xxxxxxx  | xxxx     | xx       | xx       | xx       | t       |
// |----------|----------|----------|----------|----------|----------|----------|---------|
//
// waiti ch, t : wait until master clock = t on channel ch.
// |----------|----------|----------|----------|----------|----------|----------|---------|
// | 63 .. 56 | 55 .. 53 | 52 .. 50 | 49 .. 46 | 45 .. 41 | 40 .. 36 | 35 .. 31 | 30 .. 0 |
// |----------|----------|----------|----------|----------|----------|----------|---------|
// | 00010101 | xxxx     | channel  | xxxx     | xx       | xx       | xx       | t       |
// |----------|----------|----------|----------|----------|----------|----------|---------|
//
// bitwi p, $ra, $rb oper imm : perform the bit-wise operation $rb oper imm and write the result
// into register $ra.
// oper :
// 0000 : $rb & imm 	(and)
// 0001 : $rb | imm 	(or)
// 0010 : $rb ^ imm 	(xor)
// 0011 : ~imm			(not)
// 0100 : $rb << imm	(left shift)
// 0101 : $rb >> imm	(right shift)
// |----------|----------|----------|----------|----------|----------|----------|---------|
// | 63 .. 56 | 55 .. 53 | 52 .. 50 | 49 .. 46 | 45 .. 41 | 40 .. 36 | 35 .. 31 | 30 .. 0 |
// |----------|----------|----------|----------|----------|----------|----------|---------|
// | 00010110 | page     | xxxxxxx  | oper     | ra       | rb       | xx       | imm     |
// |----------|----------|----------|----------|----------|----------|----------|---------|
//
// NOTE: the not operation operates on a single operand. The syntax is slightly different:
// bitwi p, $ra, ~imm
//
// memri p, $r, imm : read memory at address imm and write value into register: $r = mem[imm].
// |----------|----------|----------|----------|----------|----------|----------|---------|
// | 63 .. 56 | 55 .. 53 | 52 .. 50 | 49 .. 46 | 45 .. 41 | 40 .. 36 | 35 .. 31 | 30 .. 0 |
// |----------|----------|----------|----------|----------|----------|----------|---------|
// | 00010111 | page     | xxxxxxx  | xxxx     | r        | xx       | xx       | imm     |
// |----------|----------|----------|----------|----------|----------|----------|---------|
//
// memwi p, $r, imm : write register contents into address imm of memory: mem[imm] = $r.
// |----------|----------|----------|----------|----------|----------|----------|---------|
// | 63 .. 56 | 55 .. 53 | 52 .. 50 | 49 .. 46 | 45 .. 41 | 40 .. 36 | 35 .. 31 | 30 .. 0 |
// |----------|----------|----------|----------|----------|----------|----------|---------|
// | 00011000 | page     | xxxxxxx  | xxxx     | xx       | xx       | r        | imm     |
// |----------|----------|----------|----------|----------|----------|----------|---------|
//
// regwi p, $r, imm : write imm value into register.
// |----------|----------|----------|----------|----------|----------|----------|---------|
// | 63 .. 56 | 55 .. 53 | 52 .. 50 | 49 .. 46 | 45 .. 41 | 40 .. 36 | 35 .. 31 | 30 .. 0 |
// |----------|----------|----------|----------|----------|----------|----------|---------|
// | 00011001 | page     | xxxxxxx  | xxxx     | r        | xx       | xx       | imm     |
// |----------|----------|----------|----------|----------|----------|----------|---------|
//
// setbi ch, p, $r, t : set value on register $r at time t for channel ch (blocking).
// |----------|----------|----------|----------|----------|----------|----------|---------|
// | 63 .. 56 | 55 .. 53 | 52 .. 50 | 49 .. 46 | 45 .. 41 | 40 .. 36 | 35 .. 31 | 30 .. 0 |
// |----------|----------|----------|----------|----------|----------|----------|---------|
// | 00011010 | page     | channel  | xxxx     | xx       | r        | xx       | t       |
// |----------|----------|----------|----------|----------|----------|----------|---------|
//
// ##############
// ### J-Type ###
// ##############
//
// J-Type: jump type. Three registers and an address for jump.
//
// |----------|----------|----------|----------|----------|----------|----------|----------|---------|
// | 63 .. 56 | 55 .. 53 | 52 .. 50 | 49 .. 46 | 45 .. 41 | 40 .. 36 | 35 .. 31 | 30 .. 16 | 15 .. 0 |
// |----------|----------|----------|----------|----------|----------|----------|----------|---------|
// | opcode   | page     | xxxxxxx  | oper     | ra       | rb       | rc       | xxx      | addr    |
// |----------|----------|----------|----------|----------|----------|----------|----------|---------|
//
// loopnz $p, $r, addr : jump to address addr if $r is not equal to zero and decrement register.
// If $r is equal to zero, continue with next instruction.
// |----------|----------|----------|----------|----------|----------|----------|----------|---------|
// | 63 .. 56 | 55 .. 53 | 52 .. 50 | 49 .. 46 | 45 .. 41 | 40 .. 36 | 35 .. 31 | 30 .. 16 | 15 .. 0 |
// |----------|----------|----------|----------|----------|----------|----------|----------|---------|
// | 00110000 | page     | xxxxxxx  | 1000     | r        | r        | xx       | xxx      | addr    |
// |----------|----------|----------|----------|----------|----------|----------|----------|---------|
//
// condj p, $ra oper $rb, @label : jump to address @label if condition is true. Operation is defined as:
// oper :
// 0000 : $ra > $rb
// 0001 : $ra >= $rb
// 0010 : $ra < $rb
// 0011 : $ra <= $rb
// 0100 : $ra == $rb
// 0101 : $ra != $rb
// |----------|----------|----------|----------|----------|----------|----------|----------|---------|
// | 63 .. 56 | 55 .. 53 | 52 .. 50 | 49 .. 46 | 45 .. 41 | 40 .. 36 | 35 .. 31 | 30 .. 16 | 15 .. 0 |
// |----------|----------|----------|----------|----------|----------|----------|----------|---------|
// | 00110001 | page     | xxxxxxx  | oper     | xx       | ra       | rb       | xxx      | addr    |
// |----------|----------|----------|----------|----------|----------|----------|----------|---------|
//
// end : jump to END_ST to finish the execution of the program.
// |----------|----------|----------|----------|----------|----------|----------|----------|---------|
// | 63 .. 56 | 55 .. 53 | 52 .. 50 | 49 .. 46 | 45 .. 41 | 40 .. 36 | 35 .. 31 | 30 .. 16 | 15 .. 0 |
// |----------|----------|----------|----------|----------|----------|----------|----------|---------|
// | 00111111 | xxxx     | xxxxxxx  | xxxx     | xx       | xx       | xx       | xxx      | xxxx    |
// |----------|----------|----------|----------|----------|----------|----------|----------|---------|
//

// ##############
// ### R-Type ###
// ##############
//
// R-Type: register type. 8 registers: 1 for writing, 7 for reading.
//
// |----------|----------|----------|----------|----------|----------|----------|----------|----------|----------|----------|---------|--------|
// | 63 .. 56 | 55 .. 53 | 52 .. 50 | 49 .. 46 | 45 .. 41 | 40 .. 36 | 35 .. 31 | 30 .. 26 | 25 .. 21 | 20 .. 16 | 15 .. 11 | 10 .. 6 | 5 .. 0 |
// |----------|----------|----------|----------|----------|----------|----------|----------|----------|----------|----------|---------|--------|
// | opcode   | page     | channel  | oper     | ra       | rb       | rc       | rd       | re       | rf       | rg       | rh      | xxx    |
// |----------|----------|----------|----------|----------|----------|----------|----------|----------|----------|----------|---------|--------|
//
// add $p, $ra, $rb oper $rc : apply operation on registers $rb and $rc and store the result into register $ra. Registers are on page $p.
// oper :
// 1000 : $rb + $rc
// 1001 : $rb - $rc
// 1010 : $rb * $rc
// |----------|----------|----------|----------|----------|----------|----------|----------|----------|----------|----------|---------|--------|
// | 63 .. 56 | 55 .. 53 | 52 .. 50 | 49 .. 46 | 45 .. 41 | 40 .. 36 | 35 .. 31 | 30 .. 26 | 25 .. 21 | 20 .. 16 | 15 .. 11 | 10 .. 6 | 5 .. 0 |
// |----------|----------|----------|----------|----------|----------|----------|----------|----------|----------|----------|---------|--------|
// | 01010000 | page     | xxxxxxx  | oper     | ra       | rb       | rc       | xx       | xx       | xx       | xx       | xx      | xxx    |
// |----------|----------|----------|----------|----------|----------|----------|----------|----------|----------|----------|---------|--------|
//
// set ch, p, $ra, $rb, $rc, $rd, $re, $rt : set value on {$re,$rd,$rc,$rb,$ra} at time $rt for chhanel ch.
// $ra is the lower 32 bits and $re are the 32 most significant bits.
// |----------|----------|----------|----------|----------|----------|----------|----------|----------|----------|----------|---------|--------|
// | 63 .. 56 | 55 .. 53 | 52 .. 50 | 49 .. 46 | 45 .. 41 | 40 .. 36 | 35 .. 31 | 30 .. 26 | 25 .. 21 | 20 .. 16 | 15 .. 11 | 10 .. 6 | 5 .. 0 |
// |----------|----------|----------|----------|----------|----------|----------|----------|----------|----------|----------|---------|--------|
// | 01010001 | page     | channel  | xxxx     | xx       | ra       | rt       | rb       | rc       | rd       | re       | xx      | xxx    |
// |----------|----------|----------|----------|----------|----------|----------|----------|----------|----------|----------|---------|--------|
//
// sync $p, $r : sync master clock to $r for upcoming instructions.
// |----------|----------|----------|----------|----------|----------|----------|----------|----------|----------|----------|---------|--------|
// | 63 .. 56 | 55 .. 53 | 52 .. 50 | 49 .. 46 | 45 .. 41 | 40 .. 36 | 35 .. 31 | 30 .. 26 | 25 .. 21 | 20 .. 16 | 15 .. 11 | 10 .. 6 | 5 .. 0 |
// |----------|----------|----------|----------|----------|----------|----------|----------|----------|----------|----------|---------|--------|
// | 01010010 | page     | xxxxxxx  | xxxx     | xx       | xx       | r        | xx       | xx       | xx       | xx       | xx      | xxx    |
// |----------|----------|----------|----------|----------|----------|----------|----------|----------|----------|----------|---------|--------|
//
// read ch, $p, oper $r : read input data port "channel" (s?_axis) into register $r.
// oper:
// 1010 : upper 32 bits.
// else : lower 32 bits.
// |----------|----------|----------|----------|----------|----------|----------|----------|----------|----------|----------|---------|--------|
// | 63 .. 56 | 55 .. 53 | 52 .. 50 | 49 .. 46 | 45 .. 41 | 40 .. 36 | 35 .. 31 | 30 .. 26 | 25 .. 21 | 20 .. 16 | 15 .. 11 | 10 .. 6 | 5 .. 0 |
// |----------|----------|----------|----------|----------|----------|----------|----------|----------|----------|----------|---------|--------|
// | 01010011 | page     | channel  | oper     | r        | xx       | xx       | xx       | xx       | xx       | xx       | xx      | xxx    |
// |----------|----------|----------|----------|----------|----------|----------|----------|----------|----------|----------|---------|--------|
// Example:
// read 0, 2, upper $3: read upper 32 bits of channel 0 into register 3 on page 2.
//
// wait ch, p, $r : wait until master clock reaches time specified by register $r on channel ch.
// |----------|----------|----------|----------|----------|----------|----------|----------|----------|----------|----------|---------|--------|
// | 63 .. 56 | 55 .. 53 | 52 .. 50 | 49 .. 46 | 45 .. 41 | 40 .. 36 | 35 .. 31 | 30 .. 26 | 25 .. 21 | 20 .. 16 | 15 .. 11 | 10 .. 6 | 5 .. 0 |
// |----------|----------|----------|----------|----------|----------|----------|----------|----------|----------|----------|---------|--------|
// | 01010100 | page     | channel  | xxxx     | xx       | xx       | r        | xx       | xx       | xx       | xx       | xx      | xxx    |
// |----------|----------|----------|----------|----------|----------|----------|----------|----------|----------|----------|---------|--------|
//
// bitw p, $ra, $rb oper $rc : perform the bit-wise operation $rb oper $rc and write the result into register $ra.
// oper :
// 0000 : $rb & $rc 	(and)
// 0001 : $rb | $rc 	(or)
// 0010 : $rb ^ $rc 	(xor)
// 0011 : ~$rc			(not)
// 0100 : $rb << $rc	(left shift)
// 0101 : $rb >> $rc	(right shift)
// |----------|----------|----------|----------|----------|----------|----------|----------|----------|----------|----------|---------|--------|
// | 63 .. 56 | 55 .. 53 | 52 .. 50 | 49 .. 46 | 45 .. 41 | 40 .. 36 | 35 .. 31 | 30 .. 26 | 25 .. 21 | 20 .. 16 | 15 .. 11 | 10 .. 6 | 5 .. 0 |
// |----------|----------|----------|----------|----------|----------|----------|----------|----------|----------|----------|---------|--------|
// | 01010101 | page     | xxxxxxx  | oper     | ra       | rb       | rc       | xx       | xx       | xx       | xx       | xx      | xxx    |
// |----------|----------|----------|----------|----------|----------|----------|----------|----------|----------|----------|---------|--------|
//
// NOTE: the not operation operates on a single operand. The syntax is slightly different:
// bitw p, $ra, ~$rc
//
// memr p, $ra, $rb : read memory at address $rb and write value into register $ra: $ra = mem[$rb].
// |----------|----------|----------|----------|----------|----------|----------|----------|----------|----------|----------|---------|--------|
// | 63 .. 56 | 55 .. 53 | 52 .. 50 | 49 .. 46 | 45 .. 41 | 40 .. 36 | 35 .. 31 | 30 .. 26 | 25 .. 21 | 20 .. 16 | 15 .. 11 | 10 .. 6 | 5 .. 0 |
// |----------|----------|----------|----------|----------|----------|----------|----------|----------|----------|----------|---------|--------|
// | 01010110 | page     | xxxxxxx  | xxxx     | ra       | rb       | xx       | xx       | xx       | xx       | xx       | xx      | xxx    |
// |----------|----------|----------|----------|----------|----------|----------|----------|----------|----------|----------|---------|--------|
//
// memw p, $ra, $rb : write value of register $ra into memory at address $rb: $mem[$rb] = $ra.
// |----------|----------|----------|----------|----------|----------|----------|----------|----------|----------|----------|---------|--------|
// | 63 .. 56 | 55 .. 53 | 52 .. 50 | 49 .. 46 | 45 .. 41 | 40 .. 36 | 35 .. 31 | 30 .. 26 | 25 .. 21 | 20 .. 16 | 15 .. 11 | 10 .. 6 | 5 .. 0 |
// |----------|----------|----------|----------|----------|----------|----------|----------|----------|----------|----------|---------|--------|
// | 01010111 | page     | xxxxxxx  | xxxx     | xx       | rb       | ra       | xx       | xx       | xx       | xx       | xx      | xxx    |
// |----------|----------|----------|----------|----------|----------|----------|----------|----------|----------|----------|---------|--------|
//
// setb ch, p, $ra, $rb, $rc, $rd, $re, $rt : set value on {$re,$rd,$rc,$rb,$ra} at time $rt for chhanel ch.
// $ra is the lower 32 bits and $re are the 32 most significant bits (blocking).
// |----------|----------|----------|----------|----------|----------|----------|----------|----------|----------|----------|---------|--------|
// | 63 .. 56 | 55 .. 53 | 52 .. 50 | 49 .. 46 | 45 .. 41 | 40 .. 36 | 35 .. 31 | 30 .. 26 | 25 .. 21 | 20 .. 16 | 15 .. 11 | 10 .. 6 | 5 .. 0 |
// |----------|----------|----------|----------|----------|----------|----------|----------|----------|----------|----------|---------|--------|
// | 01011000 | page     | channel  | xxxx     | xx       | ra       | rt       | rb       | rc       | rd       | re       | xx      | xxx    |
// |----------|----------|----------|----------|----------|----------|----------|----------|----------|----------|----------|---------|--------|
//

module ctrl
	(
		// Clock and reset.
        clk    		,
		rstn		,

		// Start/stop.
		start		,

		// Opcode.
		opcode		,

		// IR control.
		ir_en		,
		
		// Pogram counter out (jump instructions).
		pc_src		,
		pc_en		,
		pc_rst		,

		// Alu control.
		alu_src_b	,
		alu_zero	,

		// Alu Time control.
		alut_src_b	,

		// Register write control.
		reg_src		,
		reg_wen		,

		// Conditional control.
		cond_flag	,

		// Stack control.
		stack_en	,
		stack_op	,
		stack_full	,
		stack_empty	,

		// Fifo time control.
		fifo_wr_en	,
		fifo_full	,

		// Data Memory control.
		dmem_we		,
		addr_src	,

		// Master clock control.
		t_en		,
		t_sync_en	,

		// Wait handshake.
		waitt		,
		waitt_ack
    );

// Ports.
input 	clk;
input 	rstn;

input	start;

input	[7:0]	opcode;

output			ir_en;

output			pc_src;
output			pc_en;
output			pc_rst;

output	[1:0]	alu_src_b;
input			alu_zero;

output			alut_src_b;

output	[2:0]	reg_src;
output			reg_wen;

input			cond_flag;

output			stack_en;
output			stack_op;
input			stack_full;
input			stack_empty;

output			fifo_wr_en;
input			fifo_full;

output			dmem_we;
output			addr_src;

output			t_en;
output			t_sync_en;

input			waitt;
output			waitt_ack;

// States.
typedef enum	{	INIT_ST		,
					PC_RST_ST	,
					START_MC_ST	,
					FETCH_ST	,
					DECODE_ST	,
					MATHI0_ST	,
					MATHI1_ST	,
					MATHI2_ST	,
					MATHI3_ST	,
					BITWI0_ST	,
					BITWI1_ST	,
					BITWI2_ST	,
					BITWI3_ST	,
					MATH0_ST	,
					MATH1_ST	,
					MATH2_ST	,
					MATH3_ST	,
					BITW0_ST	,
					BITW1_ST	,
					BITW2_ST	,
					BITW3_ST	,
					PUSHI0_ST	,
					POPI0_ST	,
					POPI1_ST	,
					POPI2_ST	,
					LOOPNZ0_ST	,
					LOOPNZ1_ST	,
					LOOPNZ2_ST	,
					LOOPNZ3_ST	,
					SETI0_ST	,
					SETI1_ST	,
					SET0_ST		,
					SET1_ST		,
					SYNCI0_ST	,
					SYNCI1_ST	,
					SYNC0_ST	,
					SYNC1_ST	,
					CONDJ0_ST	,
					CONDJ1_ST	,
					CONDJ2_ST	,
					READ0_ST	,
					MEMRI0_ST	,
					MEMRI1_ST	,
					MEMRI2_ST	,
					MEMR0_ST	,
					MEMR1_ST	,
					MEMR2_ST	,
					MEMWI0_ST	,
					MEMW0_ST	,
					REGWI0_ST	,
					WAITI0_ST	,
					WAITI1_ST	,
					WAIT0_ST	,
					WAIT1_ST	,
					WAIT_ACK_ST	,
					ERR_INSTR_ST,
					ERR_STACK_ST,
					END_ST		
				} state_t;

(* fsm_encoding = "one_hot" *) state_t state;

reg 			state_loopnz;
reg 			state_condj;

// IR control.
reg 			ir_en_i;

// Pogram counter out (jump instructions).
reg				pc_src_i;		// 0: pc + 1, 1: jump.
reg 			pc_en_i;
reg				pc_rst_i;

// Alu control.
reg		[1:0]	alu_src_b_i;	// 00: imm, 01: D1, 10: -1.

// ALU Time control.
reg				alut_src_b_i;	// 0: D1, 1: imm.

// Register write control.
reg		[2:0]	reg_src_i;		// 000: imm, 001: Alu out, 010: Stack Out, 011: Input Port (s_axis), 100: memory.
reg 			reg_wen_i;

// Stack control.
reg				stack_en_i;
reg 			stack_op_i;		// 0: pop, 1: push.

// Fifo Time control.
reg				fifo_wr_en_i;

// Data memory control.
reg				dmem_we_i;
reg				addr_src_i;		// 0: imm, 1: reg.

// Master clock control.
reg				t_en_i;
reg				t_sync_en_i;

// Wait handshake.
reg				waitt_ack_i;

// Registers.
always @(posedge clk) begin
	if (~rstn) begin
		// State register.
		state <= INIT_ST;
	end 
	else begin
		// State register.
		case (state)
			INIT_ST:
				if (start)
					state <= PC_RST_ST;

			PC_RST_ST:
				state <= START_MC_ST;

			START_MC_ST:
				state <= FETCH_ST;
				
			FETCH_ST:
				state <= DECODE_ST;

			DECODE_ST:
				// pushi
				if ( opcode == 8'b00010000 )
					state <= PUSHI0_ST;

				// popi
				else if ( opcode == 8'b00010001 )
					state <= POPI0_ST;

				// mathi
				else if ( opcode == 8'b00010010 )
					state <= MATHI0_ST;

				// seti/setbi
				else if ( opcode == 8'b00010011 || opcode == 8'b00011010 )
					state <= SETI0_ST;

				// synci
				else if ( opcode == 8'b00010100 )
					state <= SYNCI0_ST;

				// waiti
				else if ( opcode == 8'b00010101 )
					state <= WAITI0_ST;

				// bitwi
				else if ( opcode == 8'b00010110 )
					state <= BITWI0_ST;

				// memri
				else if ( opcode == 8'b00010111 )
					state <= MEMRI0_ST;

				// memwi
				else if ( opcode == 8'b00011000 )
					state <= MEMWI0_ST;

				// regwi
				else if ( opcode == 8'b00011001 )
					state <= REGWI0_ST;

				// loopnz
				else if ( opcode == 8'b00110000 )
					state <= LOOPNZ0_ST;

				// condj
				else if ( opcode == 8'b00110001 )
					state <= CONDJ0_ST;

				// end
				else if ( opcode == 8'b00111111 )
					state <= END_ST;

				// math
				else if ( opcode == 8'b01010000 )
					state <= MATH0_ST;

				// set/setb
				else if ( opcode == 8'b01010001 || opcode == 8'b01011000 )
					state <= SET0_ST;

				// sync
				else if ( opcode == 8'b01010010 )
					state <= SYNC0_ST;
			
				// read
				else if ( opcode == 8'b01010011 )
					state <= READ0_ST;

				// wait
				else if ( opcode == 8'b01010100 )
					state <= WAIT0_ST;

				// bitw
				else if ( opcode == 8'b01010101 )
					state <= BITW0_ST;

				// memr
				else if ( opcode == 8'b01010110 )
					state <= MEMR0_ST;

				// memw
				else if ( opcode == 8'b01010111 )
					state <= MEMW0_ST;

				// Instruction not recognized.
				else
					state <= ERR_INSTR_ST;

			MATHI0_ST:
				state <= MATHI1_ST;

			MATHI1_ST:
				state <= MATHI2_ST;

			MATHI2_ST:
				state <= MATHI3_ST;

			MATHI3_ST:
				state <= DECODE_ST;

			BITWI0_ST:
				state <= BITWI1_ST;

			BITWI1_ST:
				state <= BITWI2_ST;

			BITWI2_ST:
				state <= BITWI3_ST;

			BITWI3_ST:
				state <= DECODE_ST;

			MATH0_ST:
				state <= MATH1_ST;

			MATH1_ST:
				state <= MATH2_ST;

			MATH2_ST:
				state <= MATH3_ST;

			MATH3_ST:
				state <= DECODE_ST;

			BITW0_ST:
				state <= BITW1_ST;

			BITW1_ST:
				state <= BITW2_ST;

			BITW2_ST:
				state <= BITW3_ST;

			BITW3_ST:
				state <= DECODE_ST;

			PUSHI0_ST:
				if (stack_full)
					state <= ERR_STACK_ST;
				else
					state <= DECODE_ST;

			POPI0_ST:
				if (stack_empty)
					state <= ERR_STACK_ST;
				else
					state <= POPI1_ST;

			POPI1_ST:
				state <= POPI2_ST;

			POPI2_ST:
				state <= DECODE_ST;

			LOOPNZ0_ST:
				if (alu_zero)
					// If zero, skip to next instruction.
					state <= FETCH_ST;
				else
					// If not zero, jump to address.
					state <= LOOPNZ1_ST;

			LOOPNZ1_ST:
				state <= LOOPNZ2_ST;

			LOOPNZ2_ST:
				state <= LOOPNZ3_ST;

			LOOPNZ3_ST:
				state <= FETCH_ST;

			SETI0_ST:
				state <= SETI1_ST;

			SETI1_ST:
				if (~fifo_full)
					state <= FETCH_ST;

			SET0_ST:
				state <= SET1_ST;

			SET1_ST:
				if (~fifo_full)
					state <= FETCH_ST;

			SYNCI0_ST:
				state <= SYNCI1_ST;

			SYNCI1_ST:
				state <= DECODE_ST;

			SYNC0_ST:
				state <= SYNC1_ST;

			SYNC1_ST:
				state <= DECODE_ST;

			CONDJ0_ST:
				state <= CONDJ1_ST;

			CONDJ1_ST:
				if (cond_flag)
					// Jump.
					state <= CONDJ2_ST;
				else
					// Continue without jump.
					state <= FETCH_ST;

			CONDJ2_ST:
				state <= FETCH_ST;

			READ0_ST:
				state <= DECODE_ST;

			MEMRI0_ST:
				state <= MEMRI1_ST;

			MEMRI1_ST:
				state <= MEMRI2_ST;

			MEMRI2_ST:
				state <= DECODE_ST;

			MEMR0_ST:
				state <= MEMR1_ST;

			MEMR1_ST:
				state <= MEMR2_ST;

			MEMR2_ST:
				state <= DECODE_ST;

			MEMWI0_ST:
				state <= DECODE_ST;

			MEMW0_ST:
				state <= DECODE_ST;

			REGWI0_ST:
				state <= DECODE_ST;

			WAITI0_ST:
				state <= WAITI1_ST;

			WAITI1_ST:
				if (~fifo_full)
					state <= WAIT_ACK_ST;

			WAIT0_ST:
				state <= WAIT1_ST;

			WAIT1_ST:
				if (~fifo_full)
					state <= WAIT_ACK_ST;

			WAIT_ACK_ST:
				if (waitt)
					state <= FETCH_ST;

			ERR_INSTR_ST:
				state <= END_ST;

			ERR_STACK_ST:
				state <= END_ST;

			END_ST:
				if (~start)
					state <= INIT_ST;
		endcase
	end
end

// FSM outputs.
always_comb	begin
	// Default.
	state_loopnz	= 1'b0;
	state_condj		= 1'b0;
	ir_en_i			= 1'b0;
	pc_src_i		= 1'b0;
	pc_en_i			= 1'b0;
	pc_rst_i		= 1'b0;
	alu_src_b_i		= 2'b00;
	alut_src_b_i	= 1'b0;
	reg_src_i		= 3'b000;
	reg_wen_i		= 1'b0;
	stack_en_i		= 1'b0;
	stack_op_i		= 1'b0;
	fifo_wr_en_i	= 1'b0;
	dmem_we_i		= 1'b0;
	addr_src_i		= 1'b0;
	t_en_i			= 1'b1;
	t_sync_en_i		= 1'b0;
	waitt_ack_i		= 1'b0;

	case (state)
		//INIT_ST:

		PC_RST_ST:
			pc_rst_i		= 1'b1;

		START_MC_ST:
			t_en_i			= 1'b0;

		FETCH_ST: begin
			ir_en_i			= 1'b1;
			pc_src_i		= 1'b0;		// pc + 1.
			pc_en_i			= 1'b1;
		end

		//DECODE_ST:

		MATHI0_ST:
			alu_src_b_i		= 2'b00;	// imm.

		MATHI1_ST:
			alu_src_b_i		= 2'b00;	// imm.

		MATHI2_ST:
			alu_src_b_i		= 2'b00;	// imm.

		MATHI3_ST: begin
			ir_en_i			= 1'b1;
			pc_src_i		= 1'b0;		// pc + 1.
			pc_en_i			= 1'b1;
			reg_src_i		= 3'b001;	// Alu out.
			reg_wen_i		= 1'b1;
		end

		BITWI0_ST:
			alu_src_b_i		= 2'b00;	// imm.

		BITWI1_ST:
			alu_src_b_i		= 2'b00;	// imm.

		BITWI2_ST:
			alu_src_b_i		= 2'b00;	// imm.

		BITWI3_ST: begin
			ir_en_i			= 1'b1;
			pc_src_i		= 1'b0;		// pc + 1.
			pc_en_i			= 1'b1;
			reg_src_i		= 3'b001;	// Alu out.
			reg_wen_i		= 1'b1;
		end

		MATH0_ST:
			alu_src_b_i		= 2'b01;	// D1.

		MATH1_ST:
			alu_src_b_i		= 2'b01;	// D1.

		MATH2_ST:
			alu_src_b_i		= 2'b01;	// D1.

		MATH3_ST: begin
			ir_en_i			= 1'b1;
			pc_src_i		= 1'b0;		// pc + 1.
			pc_en_i			= 1'b1;
			reg_src_i		= 3'b001;	// Alu out.
			reg_wen_i		= 1'b1;
		end

		BITW0_ST:
			alu_src_b_i		= 2'b01;	// D1.

		BITW1_ST:
			alu_src_b_i		= 2'b01;	// D1.

		BITW2_ST:
			alu_src_b_i		= 2'b01;	// D1.

		BITW3_ST: begin
			ir_en_i			= 1'b1;
			pc_src_i		= 1'b0;		// pc + 1.
			pc_en_i			= 1'b1;
			reg_src_i		= 3'b001;	// Alu out.
			reg_wen_i		= 1'b1;
		end

		PUSHI0_ST: begin
			ir_en_i			= 1'b1;
			pc_src_i		= 1'b0;		// pc + 1.
			pc_en_i			= 1'b1;
			reg_src_i		= 3'b000;	// imm.
			reg_wen_i		= 1'b1;
			stack_en_i		= 1'b1;
			stack_op_i		= 1'b1;		// push.
		end

		POPI0_ST: begin
			stack_en_i		= 1'b1;
			stack_op_i		= 1'b0;		// pop.
		end

		POPI1_ST: begin
			reg_src_i		= 3'b010;	// Stack Out.
		end

		POPI2_ST: begin
			ir_en_i			= 1'b1;
			pc_src_i		= 1'b0;		// pc + 1.
			pc_en_i			= 1'b1;
			reg_src_i		= 3'b010;	// Stack Out.
			reg_wen_i		= 1'b1;
		end

		LOOPNZ0_ST: begin
			state_loopnz	= 1'b1;
			pc_src_i		= 1'b1;		// jump.
			pc_en_i			= 1'b1;
			alu_src_b_i		= 2'b10;	// -1.
		end

		LOOPNZ1_ST: begin
			state_loopnz	= 1'b1;
			pc_src_i		= 1'b1;		// jump.
			pc_en_i			= 1'b1;
			alu_src_b_i		= 2'b10;	// -1.
		end

		LOOPNZ2_ST: begin
			state_loopnz	= 1'b1;
			pc_src_i		= 1'b1;		// jump.
			pc_en_i			= 1'b1;
			alu_src_b_i		= 2'b10;	// -1.
		end

		LOOPNZ3_ST: begin
			reg_src_i		= 3'b001;	// ALU out reg.
			reg_wen_i		= 1'b1;
		end

		SETI0_ST:
			alut_src_b_i	= 1'b1;

		SETI1_ST: begin
			alut_src_b_i	= 1'b1;
			fifo_wr_en_i	= 1'b1;
		end

		SET0_ST:
			alut_src_b_i	= 1'b0;

		SET1_ST: begin
			alut_src_b_i	= 1'b0;
			fifo_wr_en_i	= 1'b1;
		end

		SYNCI0_ST:
			alut_src_b_i	= 1'b1;

		SYNCI1_ST: begin
			ir_en_i			= 1'b1;
			pc_src_i		= 1'b0;		// pc + 1.
			pc_en_i			= 1'b1;
			alut_src_b_i	= 1'b1;
			t_sync_en_i		= 1'b1;
		end

		SYNC0_ST:
			alut_src_b_i	= 1'b0;

		SYNC1_ST: begin
			ir_en_i			= 1'b1;
			pc_src_i		= 1'b0;		// pc + 1.
			pc_en_i			= 1'b1;
			alut_src_b_i	= 1'b0;
			t_sync_en_i		= 1'b1;
		end

		CONDJ0_ST: 
			state_condj		= 1'b1;

		CONDJ1_ST: begin
			state_condj		= 1'b1;
			pc_src_i		= 1'b1;		// jump.
			pc_en_i			= 1'b1;
		end

		CONDJ2_ST:
			state_condj		= 1'b1;

		READ0_ST: begin
			ir_en_i			= 1'b1;
			pc_src_i		= 1'b0;		// pc + 1.
			pc_en_i			= 1'b1;
			reg_src_i		= 3'b011;	// Input Port (s_axis).
			reg_wen_i		= 1'b1;
		end

		MEMRI0_ST: begin
			reg_src_i		= 3'b100;	// Memory.
			dmem_we_i		= 1'b0;		// Read.
			addr_src_i		= 1'b0;		// imm.
		end

		MEMRI1_ST: begin
			reg_src_i		= 3'b100;	// Memory.
			dmem_we_i		= 1'b0;		// Read.
			addr_src_i		= 1'b0;		// imm.
		end

		MEMRI2_ST: begin
			ir_en_i			= 1'b1;
			pc_src_i		= 1'b0;		// pc + 1.
			pc_en_i			= 1'b1;
			reg_src_i		= 3'b100;	// Memory.
			reg_wen_i		= 1'b1;
			dmem_we_i		= 1'b0;		// Read.
			addr_src_i		= 1'b0;		// imm.
		end

		MEMR0_ST: begin
			reg_src_i		= 3'b100;	// Memory.
			dmem_we_i		= 1'b0;		// Read.
			addr_src_i		= 1'b1;		// reg.
		end

		MEMR1_ST: begin
			reg_src_i		= 3'b100;	// Memory.
			dmem_we_i		= 1'b0;		// Read.
			addr_src_i		= 1'b1;		// reg.
		end

		MEMR2_ST: begin
			ir_en_i			= 1'b1;
			pc_src_i		= 1'b0;		// pc + 1.
			pc_en_i			= 1'b1;
			reg_src_i		= 3'b100;	// Memory.
			reg_wen_i		= 1'b1;
			dmem_we_i		= 1'b0;		// Read.
			addr_src_i		= 1'b1;		// reg.
		end

		MEMWI0_ST: begin
			ir_en_i			= 1'b1;
			pc_src_i		= 1'b0;		// pc + 1.
			pc_en_i			= 1'b1;
			dmem_we_i		= 1'b1;		// Write.
			addr_src_i		= 1'b0;		// imm.
		end

		MEMW0_ST: begin
			ir_en_i			= 1'b1;
			pc_src_i		= 1'b0;		// pc + 1.
			pc_en_i			= 1'b1;
			dmem_we_i		= 1'b1;		// Write.
			addr_src_i		= 1'b1;		// reg.
		end

		REGWI0_ST: begin
			ir_en_i			= 1'b1;
			pc_src_i		= 1'b0;		// pc + 1.
			pc_en_i			= 1'b1;
			reg_src_i		= 3'b000;	// imm.
			reg_wen_i		= 1'b1;
		end

		WAITI0_ST:
			alut_src_b_i	= 1'b1;

		WAITI1_ST: begin
			alut_src_b_i	= 1'b1;
			fifo_wr_en_i	= 1'b1;
		end

		WAIT0_ST:
			alut_src_b_i	= 1'b0;

		WAIT1_ST: begin
			alut_src_b_i	= 1'b0;
			fifo_wr_en_i	= 1'b1;
		end

		WAIT_ACK_ST:
			waitt_ack_i		= 1'b1;

		//ERR_INSTR_ST:

		//ERR_STACK_ST:

		//END_ST:

	endcase
end

// Assign outputs.
assign ir_en		= ir_en_i;

assign pc_src		= (state_condj == 1'b1)? pc_src_i & cond_flag : pc_src_i;
assign pc_en		= 	(state_loopnz == 1'b1 && state_condj == 1'b0)? pc_en_i & ~alu_zero	:
						(state_loopnz == 1'b0 && state_condj == 1'b1)? pc_en_i & cond_flag	:
						pc_en_i;

assign pc_rst		= pc_rst_i;

assign alu_src_b	= alu_src_b_i;
assign alut_src_b	= alut_src_b_i;

assign reg_src		= reg_src_i;
assign reg_wen		= reg_wen_i;

assign stack_en		= stack_en_i;
assign stack_op		= stack_op_i;

assign fifo_wr_en	= fifo_wr_en_i;

assign dmem_we		= dmem_we_i;
assign addr_src		= addr_src_i;

assign t_en			= t_en_i;
assign t_sync_en	= t_sync_en_i;

assign waitt_ack	= waitt_ack_i;

endmodule

