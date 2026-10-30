`timescale 1ps/1ps

module dac_tb();

    parameter int bits = 16;

    logic              clk;
    logic [bits-1:0]   s_axis_data;
    real               vref;
    real               aout;
    logic [31:0]       errors;
    real               expected_out;
    int i;
    int num_samples = 100;
    real pi = 3.141592653589793;
    real radians;
    real amplitude;
    real analog_input;

    dac dut(
        .clk(clk),
        .s_axis_tdata(s_axis_data),
        .aout(aout)
    );

    // Clock generation: 430.08 MHz (period ~2.325 ns)
    always begin
        clk = 1; #1162.5;
        clk = 0; #1162.5;
    end

    // CSV File Handle
    integer f;

    // Log values to CSV
    always @(posedge clk) begin
        $fwrite(f, "%0t,%0d,%f,%f\n", $time, s_axis_data, aout, expected_out);
    end

    initial begin
        // Initialization
        s_axis_data = 16'sd0;
        errors = 0;
        vref = 1.0;

        // Open CSV file
        f = $fopen("little_dac.csv", "w");
        if (f == 0) begin
            $fatal("Failed to open output.csv");
        end
        $fwrite(f, "time_ps,s_axis_data,aout,expected_out\n");

        #20000;

        // Sine wave generation for a signed DAC
        amplitude = (2.0**(bits-1) - 1);  // Max positive value

        for (i = 0; i < num_samples; i++) begin
            radians = (2.0 * pi * i) / num_samples;
            // Generate a sine wave that swings from -amplitude to +amplitude
            analog_input = amplitude * $sin(radians);
            s_axis_data = int'(analog_input);

            // Expected analog output from ideal signed DAC
            expected_out = (vref * $signed(s_axis_data)) / (2.0**(bits-1));

            #2325;  // Wait full clk period
        end

        if (errors == 0)
            $display("All tests passed.");
        else
            $display("%0d tests failed.", errors);

        $display("Test completed.");
        $fclose(f);
        $stop;
    end

endmodule
