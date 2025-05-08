module sync_nxm #(
    parameter N = 2, //number of stages
    parameter M = 8  //data width
)(
    input logic          i_clk ,
    input logic          i_rstn,
    input logic  [M-1:0] i_d   ,
    output logic [M-1:0] o_d
);

    logic [M-1:0] d_r [N-1:0];
    logic [M-1:0] d_n [N-1:0];

    always_ff @ (posedge i_clk) begin
     if(!i_rstn) begin
       d_r <= '{default:0};
     end else begin
       d_r <= d_n;
     end
    end

    assign d_n = {d_r[N-2:0],i_d};
    assign o_d = d_r[N-1];

endmodule

