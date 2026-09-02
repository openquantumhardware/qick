// -----------------------------------------------------------------------------
// tlast_gen_sv : SystemVerilog behavioural translation of tlast_gen.vhd
// -----------------------------------------------------------------------------
// Generates a tlast pulse every NTRAN = NFFT/SSR transactions (while en=1).
// o_tlast is high (combinationally) when the counter is at NTRAN-1.
//
// Cycle-accurate, literal translation of the original VHDL.
// Note: ceil(log2(NTRAN)) -> $clog2(NTRAN).
// -----------------------------------------------------------------------------
`timescale 1ns / 1ps

module tlast_gen_sv #(
    // SSR and FFT Length.
    parameter int NFFT = 16,
    parameter int SSR  = 4
)(
    // Input reset and clock.
    input  logic rstn,
    input  logic clk,

    // Input enable.
    input  logic en,

    // TLAST output.
    output logic o_tlast
);

    // Number of transactions.
    localparam int NTRAN      = NFFT/SSR;
    localparam int NTRAN_LOG2 = (NTRAN > 1) ? $clog2(NTRAN) : 1;

    // Counter for transactions.
    logic [NTRAN_LOG2-1:0] cnt;

    // Registers.
    always_ff @(posedge clk) begin
        if (rstn == 1'b0) begin
            cnt <= '0;
        end else begin
            if (en == 1'b1) begin
                if (cnt < NTRAN_LOG2'(NTRAN-1)) begin
                    cnt <= cnt + 1'b1;
                end else begin
                    cnt <= '0;
                end
            end
        end
    end

    // Assign outputs.
    assign o_tlast = (cnt == NTRAN_LOG2'(NTRAN-1)) ? 1'b1 : 1'b0;

endmodule
