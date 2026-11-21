// tb_gray2bin.sv
module tb_gray2bin;

    parameter B = 8;
    logic [B-1:0] gray, binary;
    
    gray2bin #(.B(B)) uut (
        .din(gray),
        .dout(binary)
    );
    
    initial begin
        $display("Gray -> Binary test:");
        $display(" Gray      Binary");
        $display("------------------");
        
        // Test with bin2gray output
        for (int i = 0; i < 16; i++) begin
            // Generate Gray code first (using bin2gray)
            gray = i ^ (i >> 1);
            #10;
            $display(" %3b (%2d) -> %3b (%2d)", gray, gray, binary, binary);
            
            // Verify
            if (binary != i) begin
                $display("ERROR: Gray %b -> Binary %b (expected %b)", gray, binary, i);
            end
        end
        
        $display("------------------");
        $display("Test completed");
        $finish;
    end

endmodule
