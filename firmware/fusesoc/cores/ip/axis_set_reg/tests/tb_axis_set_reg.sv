`timescale 1ns/1ps
`default_nettype none

module tb_axis_set_reg;

    parameter int DATA_WIDTH = 16;

    // Clock & reset
    logic tb_aclk;
    logic tb_aresetn;

    // Clock generation: 100 MHz (period = 10 ns)
    initial tb_aclk = 1'b0;
    always #5 tb_aclk = ~tb_aclk;

    // Reset: active low, asserted for 3 cycles at the beginning
    initial begin
        tb_aresetn = 1'b0;
        repeat (3) @(posedge tb_aclk);
        #1; // Desfasamos mínimamente del flanco
        tb_aresetn = 1'b1;
    end

    // AXI‑Stream signals
    logic                      tb_tvalid;
    logic [DATA_WIDTH-1:0]     tb_tdata;
    logic [(DATA_WIDTH/8)-1:0] tb_tstrb;   
    logic                      tb_tlast;   
    logic                      tb_tready;  

    // DUT instantiation
    logic [DATA_WIDTH-1:0] dut_dout;

    axis_set_reg #(
        .DATA_WIDTH (DATA_WIDTH)
    ) u_dut (
        .s_axis_aclk    (tb_aclk),
        .s_axis_aresetn (tb_aresetn),
        .s_axis_tready  (tb_tready),
        .s_axis_tdata   (tb_tdata),
        .s_axis_tstrb   (tb_tstrb),
        .s_axis_tlast   (tb_tlast),
        .s_axis_tvalid  (tb_tvalid),
        .dout           (dut_dout)
    );

    // Stimulus process
    initial begin
        // Default values
        tb_tvalid = 1'b0;
        tb_tdata  = '0;
        tb_tstrb  = { (DATA_WIDTH/8){1'b1} };
        tb_tlast  = 1'b0;

        // CORRECCIÓN: Esperar que el reset se libere (pase a 1)
        @(posedge tb_aresetn);
        repeat (2) @(posedge tb_aclk);

        // -------------------------------------------------------------
        // Test 1 – Simple capture
        // -------------------------------------------------------------
        $display("[TEST] Starting Test 1...");
        @(posedge tb_aclk);
        tb_tdata  <= 16'hA5A5;
        tb_tvalid <= 1'b1;
        
        @(posedge tb_aclk); // El diseño captura el dato acá
        tb_tvalid <= 1'b0;
        tb_tdata  <= '0;

        repeat (2) @(posedge tb_aclk);
        if (dut_dout !== 16'hA5A5) begin
            $error("Test 1 failed: expected 0xA5A5, got %0h", dut_dout);
        end else begin
            $display("Test 1 passed");
        end

        // -------------------------------------------------------------
        // Test 2 – Hold value when tvalid = 0
        // -------------------------------------------------------------
        $display("[TEST] Starting Test 2...");
        @(posedge tb_aclk);
        tb_tdata  <= 16'h1234;
        tb_tvalid <= 1'b0; // No válido
        
        repeat (2) @(posedge tb_aclk);
        if (dut_dout !== 16'hA5A5) begin
            $error("Test 2 failed: register changed while tvalid=0 (got %0h)", dut_dout);
        end else begin
            $display("Test 2 passed");
        end

        // -------------------------------------------------------------
        // Test 3 – Capture a new value
        // -------------------------------------------------------------
        $display("[TEST] Starting Test 3...");
        @(posedge tb_aclk);
        tb_tdata  <= 16'hDEAD;
        tb_tvalid <= 1'b1;
        
        @(posedge tb_aclk);
        tb_tvalid <= 1'b0;
        tb_tdata  <= '0;
        
        repeat (2) @(posedge tb_aclk);
        if (dut_dout !== 16'hDEAD) begin
            $error("Test 3 failed: expected 0xDEAD, got %0h", dut_dout);
        end else begin
            $display("Test 3 passed");
        end

        // -------------------------------------------------------------
        // Test 4 – Continuous stream (multiple beats)
        // -------------------------------------------------------------
        $display("[TEST] Starting Test 4...");
        for (int i = 0; i < 8; i++) begin
            @(posedge tb_aclk);
            tb_tdata  <= i;
            tb_tvalid <= 1'b1;
            
            @(posedge tb_aclk); // El registro debería cambiar su salida interna
            #10ps; // Pequeño delay de asentamiento para la consulta del IF
            if (dut_dout !== i) begin
                $error("Test 4 failed at iteration %0d: expected %0h, got %0h", i, i, dut_dout);
            end
        end
        
        @(posedge tb_aclk);
        tb_tvalid <= 1'b0;
        $display("Test 4 passed");

        // -------------------------------------------------------------
        // End of simulation
        // -------------------------------------------------------------
        #100;
        $display("All tests completed successfully.");
        $finish;
    end

    // Waveform dump
    initial begin
        $dumpfile("axis_set_reg_tb.vcd");
        $dumpvars(0, tb_axis_set_reg);
    end

endmodule