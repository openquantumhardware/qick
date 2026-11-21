// HMC HRL Clinic 25-26
// SystemVerilog behavioral model of ADC

module adc_model #(
    parameter integer BITS = 16,          // ADC Resolution in bits
    parameter real V_REF = 1.0          // reference voltage
) (
    input  logic clk,                   // Clock signal
    input  real    analog_in,           // Analog input
    output logic [BITS-1:0] digital_out  // Digital output
);

    // internal signals
    real quantization_step;
    real scaled_input;
    int digital_out_reg;

    initial begin
      // full range is (-2^(BITS-1) to 2^(BITS-1)-1)
        quantization_step = V_REF / (1 << (BITS - 1));
    end

    // Behavioral model of ADC
    always @(negedge clk) begin

        digital_out_reg = $rtoi(analog_in / quantization_step);

        // Clip result to ensure it stays within signed 2's complement
        if (digital_out_reg >= (1 << (BITS - 1))) begin
            digital_out_reg = (1 << (BITS - 1)) - 1;
        end else if (digital_out_reg < -(1 << (BITS - 1))) begin
            digital_out_reg = -(1 << (BITS - 1));
        end

        // Output signal
        digital_out = digital_out_reg;
    end

endmodule