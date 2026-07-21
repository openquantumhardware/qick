// -----------------------------------------------------------------------------
// bram_simple_dp_sv : SystemVerilog behavioural translation of bram_simple_dp.vhd
// -----------------------------------------------------------------------------
// Simple dual-port, single-clock BRAM.
//   Port A: synchronous write (ena & wea).
//   Port B: synchronous read  (enb), 1-cycle registered read latency.
//
// Cycle-accurate, literal translation of the original VHDL. Two separate
// clocked processes mirror the VHDL (write process + registered-read process).
// -----------------------------------------------------------------------------
`timescale 1ns / 1ps

module bram_simple_dp_sv #(
    // Memory address size.
    parameter int N = 16,
    // Data width.
    parameter int B = 16
)(
    input  logic            clk,
    input  logic            ena,
    input  logic            enb,
    input  logic            wea,
    input  logic [N-1:0]    addra,
    input  logic [N-1:0]    addrb,
    input  logic [B-1:0]    dia,
    output logic [B-1:0]    dob
);

    // Ram type.
    logic [B-1:0] RAM [0:(2**N)-1];

    // Write process (Port A).
    always_ff @(posedge clk) begin
        if (ena == 1'b1) begin
            if (wea == 1'b1) begin
                RAM[addra] <= dia;
            end
        end
    end

    // Registered read process (Port B).
    always_ff @(posedge clk) begin
        if (enb == 1'b1) begin
            dob <= RAM[addrb];
        end
    end

endmodule
