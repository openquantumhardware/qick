// HMC HRL Clinic 25-26
// testbench for behaviroal ADC model

`timescale 1ps/1ps

module adc_tb();

    // Parameters
    parameter int BITS = 16;
    parameter real V_REF =1.0;

    // Testbench signals
    logic clk;
    real analog_in;
    logic [BITS-1:0] digital_out;   // Digital output from ADC
    int              expected_out;  // Expected digital output
    real quantization_step;
    real sine_wave;
    int i;                          // Loop variable
    int num_samples = 100;         // Number of samples for sine wave
    real pi = 3.141592653589793;
    integer errors = 0;             // Error counter

    // ADC Model
    adc_model #(
        .BITS(BITS),
        .V_REF(V_REF)
    ) dut (
        .clk(clk),
        .analog_in(analog_in),
        .digital_out(digital_out)
    );

    // Clock generation: 307.2 MHz (period ~3.255 ns)
    always begin
        clk = 1; #1627.5;
        clk = 0; #1627.5;
    end

    // CSV File Handle
    integer f;

    initial begin

        //waveform dumping
        $dumpfile("adc_test.vcd");
        $dumpvars(0, adc_tb);

        // Initialization
        analog_in = 0.0;
        errors = 0;
        quantization_step = (2.0 * V_REF) / (1 << BITS);

        // Open CSV file
        f = $fopen("adc_test.csv", "w");
        if (f == 0) begin
            $fatal(1, "Failed to open output csv");
        end
        $fwrite(f, "time_ps,analog_in,digital_out,expected_out\n");

        #20000;

        // Sine wave generation + ADC test
        for (i = 0; i < num_samples; i++) begin
            sine_wave = V_REF * $sin((2.0 * pi * i) / num_samples);  // from -Vref to +Vref
            analog_in = sine_wave;  // the sine wave is the analog input

            // Calculate the expected digital output
            expected_out = $rtoi((analog_in + V_REF) / quantization_step);
            if (expected_out >= (1 << BITS)) begin
                expected_out = (1 << BITS) - 1;
            end else if (expected_out < 0) begin
                expected_out = 0;
            end

            @(posedge clk);
            #100;

            // Data logging
            $fwrite(f, "%0t,%f,%0d,%0d\n", $time, analog_in, digital_out, expected_out);

            // Compare ADC output w/ expected output
            if(digital_out != expected_out) begin
                errors++;
            end
        end

        if (errors == 0)
            $display("All tests passed.");
        else
            $display("%0d tests failed.", errors);

        $display("Test completed.");
        $fclose(f);
        $finish;
    end

endmodule
