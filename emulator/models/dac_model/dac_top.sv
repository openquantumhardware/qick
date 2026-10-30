// HMC HRL Clinic 25-26

// system verilog modeling for a DAC
// that takes in a 256-bit word

module dac_top #(
    parameter int bits = 256,       // Total DAC resolution
    parameter int N_DAC = 16        // Number of DAC channels
)(
    input  logic              clk,
    input  logic [bits-1:0]   s_axis_tdata,
    input  logic              s_axis_tvalid,
    output real               dac_out [N_DAC]
);

    // hold output of the DACs
    real internal_aout [N_DAC];

    // Generate 16 DAC instances
    generate
        genvar i;
        for (i = 0; i < N_DAC; i = i + 1) begin : dac_gen
            // Instantiate the 16-bit DAC
            dac dac_inst (
                .clk(clk),
                .s_axis_tdata(s_axis_tdata[i*16 +: 16]),
                .aout(internal_aout[i])
            );
        end
    endgenerate

    // output controlled by s_axis_tvalid
    always_ff @(posedge clk) begin
        if (s_axis_tvalid) begin
            // Assign values to the output port
            for (int j = 0; j < N_DAC; j = j + 1) begin
                dac_out[j] <= internal_aout[j];
            end
        end
    end

endmodule
