module sync_n #(
    parameter N = 8 //number of stages
)(
    input logic  i_clk ,
    input logic  i_rstn,
    input logic  i_d   ,
    output logic o_d
);

    logic [N-1:0] d_r;
    logic [N-1:0] d_n;

    always_ff @ (posedge i_clk) begin
     if(!i_rstn) begin
       d_r <= '0;
     end else begin
       d_r <= d_n;
     end
    end

    assign d_n = {d_r[N-2:0],i_d};
    assign o_d = d_r[N-1];

endmodule

