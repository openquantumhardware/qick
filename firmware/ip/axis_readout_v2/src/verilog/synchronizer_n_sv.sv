// Behavioral model of synchronizer_n for emulation
// Original VHDL version: firmware/ip/axis_readout_v2/src/synchronizer_n.vhd

module synchronizer_n_sv #(
    parameter int N = 2
)(
    input logic clk,
    input logic rstn,
    input logic data_in,
    output logic data_out
);

    // Internal register.
    logic [N-1:0] data_int_reg;

    always_ff @(posedge clk) begin
        if (!rstn) begin
            data_int_reg <= '{default: 0};
        end else begin
            data_int_reg <= {data_int_reg[N-2:0], data_in};
        end
    end

    // Assign output.
    assign data_out = data_int_reg[N-1];

endmodule