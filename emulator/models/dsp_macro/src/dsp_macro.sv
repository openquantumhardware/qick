module dsp_macro (
    input   logic                    CLK,
    input   logic        [3:0]       SEL,
    input   logic signed [26:0]      A,
    input   logic signed [17:0]      B,
    input   logic signed [31:0]      C,
    input   logic signed [26:0]      D,
    output  logic signed [45:0]      P
);

////////////////////////////////////////////////////////////
// Tier 3 (input registers)
////////////////////////////////////////////////////////////
logic signed [26:0] areg_3;
logic signed [17:0] breg_3;
logic signed [31:0] creg_3;
logic signed [26:0] dreg_3;
logic        [3:0]  opreg_3;

////////////////////////////////////////////////////////////
// Tier 4
////////////////////////////////////////////////////////////
logic signed [26:0] areg_4;
logic signed [17:0] breg_4;
logic signed [31:0] creg_4;
logic        [3:0]  opreg_4;

////////////////////////////////////////////////////////////
// Tier 5
////////////////////////////////////////////////////////////
logic signed [44:0] mreg_5;
logic signed [31:0] creg_5;
logic        [3:0]  opreg_5;

////////////////////////////////////////////////////////////
// Tier 6
////////////////////////////////////////////////////////////
logic signed [45:0] mreg_6;
logic signed [45:0] creg_6;

////////////////////////////////////////////////////////////
// Tier 3: capture inputs
////////////////////////////////////////////////////////////
always_ff @(posedge CLK) begin
    areg_3  <= A;
    breg_3  <= B;
    creg_3  <= C;
    dreg_3  <= D;
    opreg_3 <= SEL;
end

////////////////////////////////////////////////////////////
// Tier 4: pre-adder
////////////////////////////////////////////////////////////
always_ff @(posedge CLK) begin
    breg_4  <= breg_3;
    creg_4  <= creg_3;
    opreg_4 <= opreg_3;

    casez (opreg_3)
        4'b0011, 4'b0100, 4'b0101: areg_4 <= areg_3 + dreg_3; // A + D
        4'b0110, 4'b0111, 4'b1???: areg_4 <= dreg_3 - areg_3; // D - A
        default:                   areg_4 <= areg_3;          // A
    endcase
end

////////////////////////////////////////////////////////////
// Tier 5: multiplier
////////////////////////////////////////////////////////////
always_ff @(posedge CLK) begin
    mreg_5  <= areg_4 * breg_4;
    creg_5  <= creg_4;
    opreg_5 <= opreg_4;
end

////////////////////////////////////////////////////////////
// Tier 6: post-adder
////////////////////////////////////////////////////////////
always_ff @(posedge CLK) begin
    // sign extension
    mreg_6 <= {mreg_5[44], mreg_5};              // 45 ? 46 bits
    creg_6 <= {{14{creg_5[31]}}, creg_5};        // 32 ? 46 bits

    casez (opreg_5)
        4'b0001, 4'b0100, 4'b0111: P <= mreg_6 + creg_6;
        4'b0010, 4'b0101, 4'b1???: P <= mreg_6 - creg_6;
        default:                   P <= mreg_6;
    endcase
end

endmodule