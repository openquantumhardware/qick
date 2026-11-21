// HMC HRL Clinic 25-26
// SystemVerilog modeling for a DAC that takes in a 256-bit input

module dac_top #(
    parameter int bits = 256,       // Total DAC resolution
    parameter int N_DAC = 16        // Number of DAC channels
)(
    input  logic              clk,
    input  logic [bits-1:0]   s_axis_tdata,
    input  logic              s_axis_tvalid,
    output real               dac_out [N_DAC]
);

    // Generate 16 DAC instances - connect directly to output
    generate
        genvar i;
        for (i = 0; i < N_DAC; i = i + 1) begin : dac_gen
            // Instantiate the 16-bit DAC
            dac dac_inst (
                .clk(clk),
                .s_axis_tdata(s_axis_tdata[i*16 +: 16]),
                .s_axis_tvalid(s_axis_tvalid),
                .aout(dac_out[i])  // Connect directly to output
            );
        end
    endgenerate

endmodule
