`timescale 1ps/1ps

module dac_top_tb_mem();

    // Parameters
    parameter int bits = 256;
    parameter int N_DAC = 16;
    parameter int DAC_BITS = 16;

    // Memfile Parameters
    parameter string MEM_FILE = "stimulus.mem";
    parameter string LOG_FILE = "top_dac_mem.csv";
    parameter int STIM_DEPTH = 1600; // 16 channels * 100 samples
    parameter int STIM_WIDTH = 20;   // 4 bits for channel + 16 bits for data

    // Signals
    logic              clk;
    logic [bits-1:0]   s_axis_tdata;
    logic              s_axis_tvalid;
    real               vref;
    real               dac_out [N_DAC];
    
    logic [STIM_WIDTH-1:0] stim_memory [0:STIM_DEPTH-1];

    integer f_log_out;
    
    // Data for logger 
    int unsigned active_channel_for_logger;
    shortint     data_16bit_for_logger; // Stored from negedge to be used at posedge
    real         expected_out_for_logger;
    bit          log_enable;

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

    // Log the output of the DAC to the CSV file
    always @(posedge clk) begin
        if (s_axis_tvalid && log_enable) begin
            // We MUST recalculate the expected value here, as it's not in the memfile
            expected_out_for_logger <= (vref * $signed(data_16bit_for_logger)) / (2.0**(DAC_BITS-1));

            $fwrite(f_log_out, "%0t,%0d,%f,%f\n", 
                    $time, 
                    active_channel_for_logger, 
                    dac_out[active_channel_for_logger], 
                    expected_out_for_logger); // Log the re-calculated, non-delayed value
        end
    end

    initial begin
        $dumpfile("waves.vcd");
        $dumpvars(0, dac_top_tb_mem);  

        // Initialization
        s_axis_tdata = 0;
        s_axis_tvalid = 0;
        log_enable = 0;
        vref = 1.0;

        // Load the stimulus from the memfile
        $readmemh(MEM_FILE, stim_memory);

        // Open log file
        f_log_out = $fopen(LOG_FILE, "w");
        if (f_log_out == 0) begin
            $fatal(1, "Failed to open log file: %s", LOG_FILE);
        end
        $fwrite(f_log_out, "time_ps,active_channel,aout_active,expected_out\n");

        #20000;
        s_axis_tvalid = 1;

        // Loop through the entire stimulus memory
        for (int i = 0; i < STIM_DEPTH; i = i + 1) begin
            // FIX: Declarations must come before procedural statements 
            logic [STIM_WIDTH-1:0] current_stim;
            logic [3:0]            channel_from_mem;
            logic [15:0]           data_from_mem;

            @(negedge clk);
            log_enable = 1;

            // Unpack the 20-bit stimulus vector
            current_stim = stim_memory[i]; // Now this is an assignment
            channel_from_mem = current_stim[19:16];
            data_from_mem = current_stim[15:0];
            
            // Apply stimulus
            s_axis_tdata = '0;
            s_axis_tdata[channel_from_mem*16 +: 16] = data_from_mem;

            // Store info for the posedge logger
            active_channel_for_logger = int'(channel_from_mem);
            data_16bit_for_logger = shortint'(data_from_mem);
        end

        // --- End of Simulation ---
        s_axis_tvalid = 0;
        log_enable = 0;
        #5000;
        
        $display("Test completed. Data logged to %s", LOG_FILE);
        $fclose(f_log_out);
        
        `ifdef VERILATOR
            $finish;
        `else
            $stop;
        `endif
    end

endmodule
