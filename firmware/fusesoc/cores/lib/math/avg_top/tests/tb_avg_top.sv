// ============================================================================
// File: tb_avg_top.sv (Versión compatible con Icarus Verilog)
// Description: Testbench for avg_top module with XPM FIFO primitives
// ============================================================================

`timescale 1ns/1ps

module tb_avg_top;

    //==========================================================================
    // Parameters
    //==========================================================================
    localparam int N = 4;           // 2^4 = 16 samples depth (small for simulation)
    localparam int B = 16;          // 16-bit samples
    localparam int MEM_DEPTH = 2**N; // 16 samples
    localparam int DATA_WIDTH = 4*B; // 64-bit output
    
    // Test parameters
    localparam int CLK_PERIOD = 10;     // 100 MHz
    localparam int M_AXIS_PERIOD = 8;   // 125 MHz (different clock domain)
    
    //==========================================================================
    // Signals
    //==========================================================================
    reg rstn, clk;
    reg m_axis_aresetn, m_axis_aclk;
    reg trigger_i;
    reg din_valid_i;
    reg [2*B-1:0] din_i;
    
    wire m0_axis_tvalid, m0_axis_tlast;
    reg m0_axis_tready;
    wire [4*B-1:0] m0_axis_tdata;
    wire m1_axis_tvalid;
    reg m1_axis_tready;
    wire [4*B-1:0] m1_axis_tdata;
    
    reg avg_start_reg, dr_start_reg, avg_photon_mode_reg;
    reg [N-1:0] avg_addr_reg, dr_addr_reg, dr_len_reg;
    reg [31:0] avg_len_reg;
    reg [B-1:0] avg_h_thrsh_reg, avg_l_thrsh_reg;
    
    // Test control
    integer test_num;
    reg test_passed;
    
    // Data storage for checking
    reg [4*B-1:0] expected_m0_data [0:255];
    reg [4*B-1:0] expected_m1_data [0:255];
    integer expected_m0_cnt, expected_m1_cnt;
    reg m0_check_en, m1_check_en;
    integer m0_samples_received, m1_samples_received;
    
    //==========================================================================
    // DUT Instantiation
    //==========================================================================
    avg_top #(
        .N(N),
        .B(B)
    ) dut (
        .rstn              (rstn),
        .clk               (clk),
        .trigger_i         (trigger_i),
        .din_valid_i       (din_valid_i),
        .din_i             (din_i),
        .m_axis_aclk       (m_axis_aclk),
        .m_axis_aresetn    (m_axis_aresetn),
        .m0_axis_tvalid    (m0_axis_tvalid),
        .m0_axis_tready    (m0_axis_tready),
        .m0_axis_tdata     (m0_axis_tdata),
        .m0_axis_tlast     (m0_axis_tlast),
        .m1_axis_tvalid    (m1_axis_tvalid),
        .m1_axis_tready    (m1_axis_tready),
        .m1_axis_tdata     (m1_axis_tdata),
        .avg_start_reg     (avg_start_reg),
        .avg_addr_reg      (avg_addr_reg),
        .avg_len_reg       (avg_len_reg),
        .dr_start_reg      (dr_start_reg),
        .dr_addr_reg       (dr_addr_reg),
        .dr_len_reg        (dr_len_reg),
        .avg_photon_mode_reg(avg_photon_mode_reg),
        .avg_h_thrsh_reg   (avg_h_thrsh_reg),
        .avg_l_thrsh_reg   (avg_l_thrsh_reg)
    );
    
    //==========================================================================
    // Clock Generation
    //==========================================================================
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    initial begin
        m_axis_aclk = 0;
        forever #(M_AXIS_PERIOD/2) m_axis_aclk = ~m_axis_aclk;
    end
    
    //==========================================================================
    // Helper Functions
    //==========================================================================
    
    // Generate random input data
    function [2*B-1:0] generate_sample;
        input integer seed;
        reg [15:0] rand_val;
    begin
        rand_val = $urandom(seed);
        generate_sample = {{B{1'b0}}, rand_val[B-1:0]};
    end
    endfunction
    
    // Calculate expected average (simple average without photon mode)
    function [4*B-1:0] calculate_average;
        input [2*B-1:0] samples[];
        input integer start_idx;
        input integer len;
        integer i;
        reg [4*B-1:0] sum;
    begin
        sum = 0;
        for (i = 0; i < len; i++) begin
            sum = sum + {{2*B{1'b0}}, samples[start_idx + i][B-1:0]};
        end
        calculate_average = sum / len;
    end
    endfunction
    
    // Calculate expected average with photon mode thresholding
    function [4*B-1:0] calculate_average_photon_mode;
        input [2*B-1:0] samples[];
        input integer start_idx;
        input integer len;
        input [B-1:0] h_thrsh;
        input [B-1:0] l_thrsh;
        integer i;
        integer count;
        reg [4*B-1:0] sum;
        reg [B-1:0] sample_val;
    begin
        sum = 0;
        count = 0;
        
        for (i = 0; i < len; i++) begin
            sample_val = samples[start_idx + i][B-1:0];
            if (sample_val <= h_thrsh && sample_val >= l_thrsh) begin
                sum = sum + {{2*B{1'b0}}, sample_val};
                count = count + 1;
            end
        end
        
        if (count > 0)
            calculate_average_photon_mode = sum / count;
        else
            calculate_average_photon_mode = 0;
    end
    endfunction
    
    //==========================================================================
    // Monitor for m0_axis
    //==========================================================================
    initial begin
        m0_check_en = 0;
        m0_samples_received = 0;
        forever begin
            @(posedge m_axis_aclk);
            if (m0_axis_tvalid && m0_axis_tready && m0_check_en) begin
                if (expected_m0_cnt < 256) begin
                    if (m0_axis_tdata === expected_m0_data[expected_m0_cnt]) begin
                        $display("[%0t] M0[%0d]: DATA MATCH: 0x%0h", 
                                 $time, expected_m0_cnt, m0_axis_tdata);
                    end else begin
                        $display("ERROR: [%0t] M0[%0d]: MISMATCH! Expected: 0x%0h, Got: 0x%0h", 
                                 $time, expected_m0_cnt, 
                                 expected_m0_data[expected_m0_cnt], m0_axis_tdata);
                        test_passed = 0;
                    end
                    expected_m0_cnt = expected_m0_cnt + 1;
                    m0_samples_received = m0_samples_received + 1;
                end
                
                if (m0_axis_tlast) begin
                    $display("[%0t] M0: Last received, total samples: %0d", 
                             $time, m0_samples_received);
                    m0_check_en = 0;
                end
            end
        end
    end
    
    //==========================================================================
    // Monitor for m1_axis
    //==========================================================================
    initial begin
        m1_check_en = 0;
        m1_samples_received = 0;
        forever begin
            @(posedge m_axis_aclk);
            if (m1_axis_tvalid && m1_axis_tready && m1_check_en) begin
                if (expected_m1_cnt < 256) begin
                    if (m1_axis_tdata === expected_m1_data[expected_m1_cnt]) begin
                        $display("[%0t] M1[%0d]: DATA MATCH: 0x%0h", 
                                 $time, expected_m1_cnt, m1_axis_tdata);
                    end else begin
                        $display("ERROR: [%0t] M1[%0d]: MISMATCH! Expected: 0x%0h, Got: 0x%0h", 
                                 $time, expected_m1_cnt,
                                 expected_m1_data[expected_m1_cnt], m1_axis_tdata);
                        test_passed = 0;
                    end
                    expected_m1_cnt = expected_m1_cnt + 1;
                    m1_samples_received = m1_samples_received + 1;
                end
            end
        end
    end
    
    //==========================================================================
    // Main Test Procedure
    //==========================================================================
    initial begin
        // Initialize
        rstn = 0;
        m_axis_aresetn = 0;
        trigger_i = 0;
        din_valid_i = 0;
        din_i = 0;
        avg_start_reg = 0;
        dr_start_reg = 0;
        avg_photon_mode_reg = 0;
        avg_addr_reg = 0;
        avg_len_reg = 0;
        dr_addr_reg = 0;
        dr_len_reg = 0;
        avg_h_thrsh_reg = 0;
        avg_l_thrsh_reg = 0;
        m0_axis_tready = 1;  // Always ready for reads
        m1_axis_tready = 1;
        test_passed = 1;
        test_num = 0;
        
        $display("============================================================================");
        $display("Starting AVG_TOP Testbench with XPM FIFO");
        $display("Parameters: N=%0d, B=%0d, Memory Depth=%0d", N, B, MEM_DEPTH);
        $display("============================================================================\n");
        
        // Reset sequence
        repeat(10) @(posedge clk);
        rstn = 1;
        m_axis_aresetn = 1;
        repeat(5) @(posedge clk);
        $display("[%0t] Reset complete", $time);
        
        // Run tests
        run_basic_average_test();
        run_photon_mode_test();
        run_addressing_test();
        run_multiple_triggers_test();
        run_edge_cases_test();
        
        // Final report
        $display("\n============================================================================");
        if (test_passed) begin
            $display("ALL TESTS PASSED!");
        end else begin
            $display("SOME TESTS FAILED!");
        end
        $display("============================================================================");
        $finish;
    end
    
    //==========================================================================
    // Test 1: Basic average without photon mode
    //==========================================================================
    task run_basic_average_test;
        reg [2*B-1:0] samples [0:MEM_DEPTH-1];
        reg [4*B-1:0] expected_avg;
        integer num_samples, start_addr, i;
        
        test_num = test_num + 1;
        $display("\n--- TEST %0d: Basic Average (No Photon Mode) ---", test_num);
        
        // Configure test
        num_samples = 8;
        start_addr = 0;
        avg_len_reg = num_samples;
        avg_addr_reg = start_addr;
        avg_start_reg = 0;
        avg_photon_mode_reg = 0;
        
        // Generate random samples
        for (i = 0; i < num_samples; i = i + 1) begin
            samples[i] = $urandom() % 65535;
            $display("Sample[%0d]: 0x%0h", i, samples[i]);
        end
        
        // Calculate expected average
        expected_avg = calculate_average(samples, start_addr, num_samples);
        $display("Expected average: 0x%0h (%0d)", expected_avg, expected_avg);
        
        // Prepare expected data for outputs
        expected_m0_data[0] = expected_avg;
        expected_m1_data[0] = expected_avg;
        
        // Send data to DUT
        $display("\nSending samples to DUT...");
        for (i = 0; i < num_samples; i = i + 1) begin
            @(posedge clk);
            din_valid_i = 1;
            din_i = samples[i];
            if (i == num_samples-1) begin
                avg_start_reg = 1;  // Start averaging after last sample
            end
        end
        
        @(posedge clk);
        din_valid_i = 0;
        avg_start_reg = 0;
        
        // Trigger the averaging process
        @(posedge clk);
        trigger_i = 1;
        @(posedge clk);
        trigger_i = 0;
        
        $display("\nWaiting for averaging to complete...");
        
        // Enable monitors
        @(negedge clk);
        m0_check_en = 1;
        m1_check_en = 1;
        expected_m0_cnt = 0;
        expected_m1_cnt = 0;
        
        // Wait for output
        repeat(100) @(posedge m_axis_aclk);
        
        $display("--- TEST %0d Complete ---\n", test_num);
    endtask
    
    //==========================================================================
    // Test 2: Photon mode average with thresholds
    //==========================================================================
    task run_photon_mode_test;
        reg [2*B-1:0] samples [0:MEM_DEPTH-1];
        reg [4*B-1:0] expected_avg;
        integer num_samples, start_addr, i;
        
        test_num = test_num + 1;
        $display("\n--- TEST %0d: Photon Mode Average ---", test_num);
        
        // Configure test
        num_samples = 12;
        start_addr = 2;
        avg_len_reg = num_samples;
        avg_addr_reg = start_addr;
        avg_start_reg = 0;
        avg_photon_mode_reg = 1;
        avg_h_thrsh_reg = 50000;
        avg_l_thrsh_reg = 10000;
        
        $display("Thresholds: High=0x%0h, Low=0x%0h", avg_h_thrsh_reg, avg_l_thrsh_reg);
        
        // Generate samples with some out-of-threshold values
        for (i = 0; i < num_samples; i = i + 1) begin
            if (i % 3 == 0)
                samples[i] = 80000;  // Above high threshold
            else if (i % 3 == 1)
                samples[i] = 5000;   // Below low threshold
            else
                samples[i] = $urandom_range(10000, 50000);  // Within threshold
            $display("Sample[%0d]: 0x%0h", i, samples[i]);
        end
        
        // Calculate expected average with photon mode
        expected_avg = calculate_average_photon_mode(samples, start_addr, num_samples,
                                                      avg_h_thrsh_reg, avg_l_thrsh_reg);
        $display("Expected average (photon mode): 0x%0h (%0d)", expected_avg, expected_avg);
        
        // Prepare expected data
        expected_m0_data[0] = expected_avg;
        expected_m1_data[0] = expected_avg;
        
        // Send data
        $display("\nSending samples to DUT...");
        for (i = 0; i < num_samples; i = i + 1) begin
            @(posedge clk);
            din_valid_i = 1;
            din_i = samples[i];
            if (i == num_samples-1) begin
                avg_start_reg = 1;
            end
        end
        
        @(posedge clk);
        din_valid_i = 0;
        avg_start_reg = 0;
        
        // Trigger
        @(posedge clk);
        trigger_i = 1;
        @(posedge clk);
        trigger_i = 0;
        
        // Enable monitors
        @(negedge clk);
        m0_check_en = 1;
        m1_check_en = 1;
        expected_m0_cnt = 0;
        expected_m1_cnt = 0;
        
        // Wait for output
        repeat(100) @(posedge m_axis_aclk);
        
        $display("--- TEST %0d Complete ---\n", test_num);
    endtask
    
    //==========================================================================
    // Test 3: Different addressing modes
    //==========================================================================
    task run_addressing_test;
        reg [2*B-1:0] samples [0:MEM_DEPTH-1];
        reg [4*B-1:0] expected_avg;
        integer num_samples, start_addr, i;
        
        test_num = test_num + 1;
        $display("\n--- TEST %0d: Different Addressing Modes ---", test_num);
        
        // Fill memory with known patterns
        for (i = 0; i < MEM_DEPTH; i = i + 1) begin
            samples[i] = i * 1000;
        end
        
        // Test 3a: Start at address 5, length 6
        num_samples = 6;
        start_addr = 5;
        avg_len_reg = num_samples;
        avg_addr_reg = start_addr;
        avg_start_reg = 0;
        avg_photon_mode_reg = 0;
        
        expected_avg = calculate_average(samples, start_addr, num_samples);
        $display("Test 3a: Start=%0d, Len=%0d, Expected=0x%0h", 
                 start_addr, num_samples, expected_avg);
        
        expected_m0_data[0] = expected_avg;
        expected_m1_data[0] = expected_avg;
        
        // Send data
        for (i = 0; i < MEM_DEPTH; i = i + 1) begin
            @(posedge clk);
            din_valid_i = 1;
            din_i = samples[i];
            if (i == MEM_DEPTH-1) begin
                avg_start_reg = 1;
            end
        end
        
        @(posedge clk);
        din_valid_i = 0;
        avg_start_reg = 0;
        
        @(posedge clk);
        trigger_i = 1;
        @(posedge clk);
        trigger_i = 0;
        
        @(negedge clk);
        m0_check_en = 1;
        m1_check_en = 1;
        expected_m0_cnt = 0;
        expected_m1_cnt = 0;
        
        repeat(50) @(posedge m_axis_aclk);
        
        $display("--- TEST %0d Complete ---\n", test_num);
    endtask
    
    //==========================================================================
    // Test 4: Multiple triggers and reads
    //==========================================================================
    task run_multiple_triggers_test;
        reg [2*B-1:0] samples [0:MEM_DEPTH-1];
        reg [4*B-1:0] expected_avg1, expected_avg2;
        integer i;
        
        test_num = test_num + 1;
        $display("\n--- TEST %0d: Multiple Triggers and Reads ---", test_num);
        
        // Generate test patterns
        for (i = 0; i < MEM_DEPTH; i = i + 1) begin
            samples[i] = $urandom();
        end
        
        // First capture: address 0, length 8
        avg_addr_reg = 0;
        avg_len_reg = 8;
        expected_avg1 = calculate_average(samples, 0, 8);
        
        // Send data
        for (i = 0; i < MEM_DEPTH; i = i + 1) begin
            @(posedge clk);
            din_valid_i = 1;
            din_i = samples[i];
            if (i == MEM_DEPTH-1) begin
                avg_start_reg = 1;
            end
        end
        
        @(posedge clk);
        din_valid_i = 0;
        avg_start_reg = 0;
        
        // First trigger
        @(posedge clk);
        trigger_i = 1;
        @(posedge clk);
        trigger_i = 0;
        
        // Second capture with different parameters
        avg_addr_reg = 8;
        avg_len_reg = 4;
        expected_avg2 = calculate_average(samples, 8, 4);
        
        // Second trigger
        repeat(20) @(posedge clk);
        @(posedge clk);
        trigger_i = 1;
        @(posedge clk);
        trigger_i = 0;
        
        // Expected outputs in sequence
        expected_m0_data[0] = expected_avg1;
        expected_m0_data[1] = expected_avg2;
        expected_m1_data[0] = expected_avg1;
        expected_m1_data[1] = expected_avg2;
        
        @(negedge clk);
        m0_check_en = 1;
        m1_check_en = 1;
        expected_m0_cnt = 0;
        expected_m1_cnt = 0;
        
        repeat(100) @(posedge m_axis_aclk);
        
        $display("--- TEST %0d Complete ---\n", test_num);
    endtask
    
    //==========================================================================
    // Test 5: Edge cases
    //==========================================================================
    task run_edge_cases_test;
        reg [2*B-1:0] samples [0:MEM_DEPTH-1];
        reg [4*B-1:0] expected_avg;
        integer i;
        
        test_num = test_num + 1;
        $display("\n--- TEST %0d: Edge Cases ---", test_num);
        
        // Test 5a: Single sample
        $display("\nTest 5a: Single sample");
        avg_len_reg = 1;
        avg_addr_reg = 0;
        samples[0] = 12345;
        
        expected_avg = calculate_average(samples, 0, 1);
        
        @(posedge clk);
        din_valid_i = 1;
        din_i = samples[0];
        @(posedge clk);
        din_valid_i = 0;
        avg_start_reg = 1;
        @(posedge clk);
        avg_start_reg = 0;
        
        @(posedge clk);
        trigger_i = 1;
        @(posedge clk);
        trigger_i = 0;
        
        expected_m0_data[0] = expected_avg;
        expected_m1_data[0] = expected_avg;
        
        @(negedge clk);
        m0_check_en = 1;
        m1_check_en = 1;
        expected_m0_cnt = 0;
        expected_m1_cnt = 0;
        
        repeat(50) @(posedge m_axis_aclk);
        
        // Test 5b: Full buffer
        $display("\nTest 5b: Full buffer");
        for (i = 0; i < MEM_DEPTH; i = i + 1) begin
            samples[i] = i * 100;
        end
        
        avg_len_reg = MEM_DEPTH;
        avg_addr_reg = 0;
        expected_avg = calculate_average(samples, 0, MEM_DEPTH);
        
        for (i = 0; i < MEM_DEPTH; i = i + 1) begin
            @(posedge clk);
            din_valid_i = 1;
            din_i = samples[i];
            if (i == MEM_DEPTH-1) begin
                avg_start_reg = 1;
            end
        end
        
        @(posedge clk);
        din_valid_i = 0;
        avg_start_reg = 0;
        
        @(posedge clk);
        trigger_i = 1;
        @(posedge clk);
        trigger_i = 0;
        
        expected_m0_data[0] = expected_avg;
        expected_m1_data[0] = expected_avg;
        
        @(negedge clk);
        m0_check_en = 1;
        m1_check_en = 1;
        expected_m0_cnt = 0;
        expected_m1_cnt = 0;
        
        repeat(100) @(posedge m_axis_aclk);
        
        $display("--- TEST %0d Complete ---\n", test_num);
    endtask
    
endmodule
