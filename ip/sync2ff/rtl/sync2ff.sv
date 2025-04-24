module sync2ff #(
    parameter NB = 8
)(
    input logic           i_clk ,
    input logic           i_rstn,
    input logic  [NB-1:0] i_d   ,
    output logic [NB-1:0] o_d
);

    logic [NB-1:0] d_r;

    always_ff @ (posedge i_clk) begin
     if(!i_rstn) begin
       d_r <= `{default:0};
     end else begin
       d_r <= {d_r[NB-2:0],i_d};
     end
    end

    assign o_d = d_r[NB-1];

endmodule

