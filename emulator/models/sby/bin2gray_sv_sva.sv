module bin2gray_sv_sva #(parameter B = 8) ( // Data Width
    input [B-1:0] din,
    output [B-1:0] dout);

    logic [B-1:0] dout_sv, dout_vhd;

    bin2gray_sv #(B) dut (
        .din(din),
        .dout(dout_sv)
    );

    bin2gray ref (
        .din(din),
        .dout(dout_vhd) 
    );

    always_comb begin 
        assert (dout_sv == dout_vhd);
    end

endmodule