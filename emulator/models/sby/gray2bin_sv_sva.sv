module gray2bin_sv_sva #(parameter B = 8) ( // Data Width
    input [B-1:0] din,
    output [B-1:0] dout);

    gray2bin_sv #(B) dut (
        .din(din),
        .dout(dout_sv)
    );

    gray2bin ref (
        .din(din),
        .dout(dout_vhd)
    );

    always_comb begin
        assert (dout_sv == dout_vhd);
    end

endmodule