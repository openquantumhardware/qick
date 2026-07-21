// -----------------------------------------------------------------------------
// zn_nb_sv : SystemVerilog behavioural translation of zn_nb.vhd
// -----------------------------------------------------------------------------
// N-deep shift-register delay line. Data advances one stage each time
// s_axis_tvalid is high. Output is the deepest stage.
//
// Cycle-accurate, literal translation of the original VHDL.
// -----------------------------------------------------------------------------
`timescale 1ns / 1ps

module zn_nb_sv #(
    // Number of bits.
    parameter int B = 16,
    // Delay.
    parameter int N = 4
)(
    input  logic            aclk,
    input  logic            aresetn,

    // S_AXIS for input.
    input  logic            s_axis_tvalid,
    input  logic [B-1:0]    s_axis_tdata,

    // M_AXIS for output.
    output logic            m_axis_tvalid,
    output logic [B-1:0]    m_axis_tdata
);

    // Shift register for data. Index 0 = newest, N-1 = oldest (output).
    logic [B-1:0] shift_reg_tdata [0:N-1];

    // Registers.
    always_ff @(posedge aclk) begin
        if (s_axis_tvalid == 1'b1) begin
            // shift_reg <= shift_reg(N-2 downto 0) & s_axis_tdata;
            for (int i = N-1; i > 0; i = i - 1) begin
                shift_reg_tdata[i] <= shift_reg_tdata[i-1];
            end
            shift_reg_tdata[0] <= s_axis_tdata;
        end
    end

    // Assign outputs.
    assign m_axis_tdata  = shift_reg_tdata[N-1];
    assign m_axis_tvalid = s_axis_tvalid;

endmodule
