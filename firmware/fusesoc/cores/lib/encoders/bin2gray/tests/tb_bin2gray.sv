// tb_bin2gray.sv
module tb_bin2gray;

    parameter B = 8;
    logic [B-1:0] din;
    logic [B-1:0] dout;
    
    bin2gray #(.B(B)) uut (
        .din(din),
        .dout(dout)
    );
    
    initial begin
        $display("Binary -> Gray code test:");
        $display(" Binary    Gray");
        
        for (int i = 0; i < 256; i++) begin
            din = i;
            #10;
            $display("  %0d (%h) -> %0d (%h)", i, din, dout, dout);
        end
        
        $finish;
    end

endmodule
