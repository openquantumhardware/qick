// Verilog behavioral implementation of the simple bram cell found in qick/firmware/ip/axis_signal_gen_v5/src/fifo/bram_simple_dp.vhd

/* verilator lint-off MULTIDRIVEN */

module bram_simple_dp_behav
    # (
        // Memory address size.
        parameter int N = 16,
        // Data width.
        parameter int B = 16
    )( 
        input  logic           clk,
        input  logic           ena,
        input  logic           enb,
        input  logic           wea,
        input  logic [N-1 : 0] addra,
        input  logic [N-1 : 0] addrb,
        input  logic [B-1 : 0] dia,
        output logic [B-1 : 0] dob
    );


    // Ram type.
    logic [B-1 : 0] RAM [(2**N)-1 : 0];

    always_ff @(posedge clk) begin
        if (ena == 1'b1) begin
            if (wea == 1'b1) begin
                RAM[addra] = dia;
            end
        end
    end

    always_ff @(posedge clk) begin
        if (enb == 1'b1) begin
            dob <= RAM[addrb];
        end
    end


endmodule

/* verilator lint-on MULTIDRIVEN */