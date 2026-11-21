// HMC HRL Clinic 25-26
// testbench for DAC-ADC waveform visualization

`timescale 1ps/1ps

module dac_adc_tb();

    // Parameters
    parameter integer BITS = 16;   
    parameter real V_REF = 1.0;
    parameter integer N_DAC = 16;
    parameter integer N_ADC = 8;

    // Clks
    parameter time DAC_FS_CLK = 104;                    // ~9.6 GHz
    parameter time DAC_CLK    = DAC_FS_CLK * N_DAC;     // 1664 ps (~600 MHz)
    parameter time ADC_FS_CLK = 408;                    // ~2.4510 GHz
    parameter time ADC_CLK    = ADC_FS_CLK * N_ADC;     // 3264 ps (~306.4 MHz)

    // Signals
    logic dac_clk = 0;
    logic adc_clk = 0;
    logic dac_fs_clk = 0;
    logic adc_fs_clk = 0;
    
    logic s_axis_tvalid = 0;
    logic [N_DAC*BITS-1:0] s_axis_tdata = 0;
    
    logic m_axis_tvalid;
    logic [N_ADC*BITS-1:0] m_axis_tdata;
    
    logic signed [15:0] ramp_val;
    
    // File handles
    integer f_in, f_out;

    // DUT
    dac_adc_loop #(
        .BITS(BITS),
        .V_REF(V_REF),
        .N_DAC(N_DAC),
        .N_ADC(N_ADC),
        .USE_INTERPOLATION(0)    // ZOH
    ) dut (
        .dac_clk(dac_clk),
        .adc_clk(adc_clk),
        .dac_fs_clk(dac_fs_clk),
        .adc_fs_clk(adc_fs_clk),
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tvalid(s_axis_tvalid),
        .m_axis_tdata(m_axis_tdata),
        .m_axis_tvalid(m_axis_tvalid)
    );

    // Clock Generation
    always begin
        dac_fs_clk = 1; #(DAC_FS_CLK / 2);
        dac_fs_clk = 0; #(DAC_FS_CLK / 2);
    end

    always begin
        dac_clk = 1; #(DAC_CLK / 2);
        dac_clk = 0; #(DAC_CLK / 2);
    end

    always begin
        adc_fs_clk = 1; #(ADC_FS_CLK / 2);
        adc_fs_clk = 0; #(ADC_FS_CLK / 2);
    end

    always begin
        adc_clk = 1; #(ADC_CLK / 2);
        adc_clk = 0; #(ADC_CLK / 2);
    end

    // CSV Logging
    initial begin
        f_in = $fopen("dac_input.csv", "w");
        $fwrite(f_in, "Time_ps,Value\n");
        
        f_out = $fopen("adc_output.csv", "w");
        $fwrite(f_out, "Time_ps,Value\n");
    end

    // Log All DAC Inputs 
    always @(posedge dac_clk) begin
        if (s_axis_tvalid) begin
            for (int k = 0; k < N_DAC; k++) begin
                $fwrite(f_in, "%.0f,%d\n", $realtime + (k * 104.0), $signed(s_axis_tdata[k*BITS +: BITS]));
            end
        end
    end

    // Log All ADC Outputs
    always @(posedge adc_fs_clk) begin
        // Invert the MSB to convert to two's complement
        $fwrite(f_out, "%.0f,%d\n", $realtime, $signed({ ~dut.adc_serial_out[BITS-1], dut.adc_serial_out[BITS-2:0] }));
    end

    // Test Stimulus
    initial begin
        $dumpfile("dac_adc_waves.vcd");
        $dumpvars(0, dac_adc_tb);

        // Initialize
        s_axis_tdata = 0;
        s_axis_tvalid = 0;
        
        #1000;
        s_axis_tvalid = 1;

        // Generate Sine Wave
        for (int i = 0; i < 2000; i++) begin 
            for (int k = 0; k < N_DAC; k++) begin
                ramp_val = $rtoi(16000.0 * $sin(2.0 * 3.14159 * (real'(i * N_DAC + k)) / 200.0)); 
                s_axis_tdata[k*BITS +: BITS] = ramp_val;
            end
            @(posedge dac_clk);
        end

        repeat(50) @(posedge adc_clk);

        #10;
        
        // Close files
        $fclose(f_in);
        $fclose(f_out);
        
        $finish;
    end

endmodule