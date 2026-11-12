// HMC HRL Clinic 25-26
// SystemVerilog behavioral model of DAC

module dac #(
    parameter integer BITS = 16,         // Bit resolution
    parameter real V_REF = 1.0           // Reference voltage
) (
    input  logic              clk,
    input  logic [BITS-1:0]   s_axis_tdata,
    input  logic              s_axis_tvalid,  // Added valid signal
    output real               aout
);    
    real aout_reg;

    always @(posedge clk) begin
        if (s_axis_tvalid) begin
            // Convert digital input to real and scale
            aout_reg <= V_REF * ($signed(s_axis_tdata)) / (2.0**(BITS-1));
        end else begin
            aout_reg <= 0.0;  // Output 0 when not valid
        end
    end

    assign aout = aout_reg;

endmodule
