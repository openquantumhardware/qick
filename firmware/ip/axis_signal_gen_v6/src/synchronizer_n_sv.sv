// synchronizer_n.sv
// SystemVerilog translation of synchronizer_n.vhd

module synchronizer_n_sv #(parameter N = 2)(
    input logic clk,
    input logic rstn,
    input logic data_in,
    output logic data_out
);

    (* ASYNC_REG = "TRUE" *) logic [N-1:0] data_int_reg;
    
    always_ff@(posedge clk)
        if (~rstn)
            data_int_reg <= 0;
        else 
            data_int_reg <= {data_int_reg[N-2:0], data_in};

    assign data_out = data_int_reg[N-1];
endmodule 
