module tb():

logic[15:0] val;
logic[31:0] seed;

initial begin
    for(integer i=0; i<10; i+=1) begin
        val = $random(seed) % 3;
        $$display("i=%0d seed=%0d val=0x%0h val=%0d", i, seed, val, val);
    end
end

endmodule