module synchronizer_vect_sv_sva #(parameter N = 2, parameter B = 8)
    (   input logic rstn, clk,
        input logic [B-1:0] data_in,
        output logic [B-1:0] data_out);

    logic [B-1:0] data_out_sv, data_out_vhd;

    synchronizer_vect_sv dut (
        .rstn(rstn),
        .clk(clk),
        .data_in(data_in),
        .data_out(data_out_sv)
    );

    synchronizer_vect ref (
        .rstn(rstn),
        .clk(clk),  
        .data_in(data_in),
        .data_out(data_out_vhd)
    );


    assign data_out = data_out_vhd;
endmodule