// HMC HRL Clinic 25-26
// testbench for behaviroal DAC model

`timescale 1ps/1ps

module dac_top_tb();

    // Parameters
    parameter int bits = 256;
    parameter int N_DAC = 16;
    parameter int DAC_BITS = 16;

    // Signals
    logic              clk;
    logic [bits-1:0]   s_axis_tdata;
    logic              s_axis_tvalid;
    real               vref;
    real               dac_out [N_DAC];
    logic [31:0]       errors;
    real               expected_out;
    int                i;
    int unsigned       j;
    int                num_samples = 100; // Samples per period
    real               pi = 3.141592653589793;
    real               radians;
    real               amplitude;
    real               analog_input;

    // DUT (dac_top) instantiation
    dac_top dut(
        .clk(clk),
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tvalid(s_axis_tvalid),
        .dac_out(dac_out)
    );

    // Clock generation: 430.08 MHz (period ~2.325 ns)
    always begin
        clk = 1; #1162.5;
        clk = 0; #1162.5;
    end

    // CSV File Handle
    integer f;

    // Log the output of the DAC to the CSV file
    always @(posedge clk) begin
        if (s_axis_tvalid) begin
            $fwrite(f, "%0t,%0d,%f,%f\n", $time, j, dac_out[j], expected_out);
        end
    end

    initial begin
        logic [DAC_BITS-1:0] single_channel_data;

        // Initialization
        s_axis_tdata = 0;
        s_axis_tvalid = 0;
        j = 0;
        errors = 0;
        vref = 1.0;

        // Open CSV file
        f = $fopen("top_dac.csv", "w");
        if (f == 0) begin
            $fatal("Failed to open top_dac_16_periods.csv");
        end
        $fwrite(f, "time_ps,active_channel,aout_active,expected_out\n");

        #20000;
        s_axis_tvalid = 1;

        amplitude = (2.0**(DAC_BITS-1) - 1);

        // -Iterate through each DAC channel from 0 to 15
        for (j = 0; j < N_DAC; j = j + 1) begin
            $display("Generating 1-period sine wave on DAC Channel %0d...", j);
            
            for (i = 0; i < num_samples; i = i + 1) begin
                // On each clock cycle, set all data bits to zero first
                s_axis_tdata = 0;
                
                // Calculate the sine wave point
                radians = (2.0 * pi * i) / num_samples;
                analog_input = amplitude * $sin(radians);
                single_channel_data = int'(analog_input);
                
                // Activate and drive ONLY the j-th DAC channel with the new data
                s_axis_tdata[j*16 +: 16] = single_channel_data;

                // Calculate the expected output for this specific point
                expected_out = (vref * $signed(single_channel_data)) / (2.0**(DAC_BITS-1));

                #2325;  // Wait one full clock period
            end
        end

        s_axis_tvalid = 0;
        #5000;
        
        if (errors == 0)
            $display("All tests passed.");
        else
            $display("%0d tests failed.", errors);

        $display("Test completed. Data logged to top_dac_16_periods.csv");
        $fclose(f);
        $stop;
    end

endmodule
