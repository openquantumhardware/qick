module data_writer_sva #(
    parameter int NT = 16, 
    parameter int N = 16, 
    parameter int B = 16
) (
    input logic clk,
    input logic rstn,
    input logic [B-1:0] s_axis_tdata,
    input logic s_axis_tvalid,
    input logic [31:0] START_ADDR_REG,
    input logic WE_REG,
    
    // SV Outputs (passed from the bound instance)
    input logic            s_axis_tready_sv,
    input logic [NT-1:0]   mem_en_sv,
    input logic            mem_we_sv,
    input logic [N-1:0]    mem_addr_sv,
    input logic [B-1:0]    mem_di_sv
);

    // VHDL Outputs
    wire            s_axis_tready_vhd;
    wire [NT-1:0]   mem_en_vhd;
    wire            mem_we_vhd;
    wire [N-1:0]    mem_addr_vhd;
    wire [B-1:0]    mem_di_vhd;

    // Instantiate VHDL Reference
    data_writer #(
        .NT(NT),
        .N(N),
        .B(B)
    ) ref_vhd (
        .clk(clk),
        .rstn(rstn),
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready_vhd),
        .mem_en(mem_en_vhd),
        .mem_we(mem_we_vhd),
        .mem_addr(mem_addr_vhd),
        .mem_di(mem_di_vhd),
        .START_ADDR_REG(START_ADDR_REG),
        .WE_REG(WE_REG)
    );

    // Assert that every output matches every cycle after reset
    always @(posedge clk) begin
        if (rstn) begin
            assert(s_axis_tready_sv === s_axis_tready_vhd);
            assert(mem_en_sv        === mem_en_vhd);
            assert(mem_we_sv        === mem_we_vhd);
            assert(mem_addr_sv      === mem_addr_vhd);
            assert(mem_di_sv        === mem_di_vhd);
        end
    end

endmodule

// Bind the property module to the SV implementation
bind data_writer_sv data_writer_sva #(
    .NT(NT), .N(N), .B(B)
) formal_check (
    .*, // Automatically connect matching port names
    .s_axis_tready_sv(s_axis_tready),
    .mem_en_sv(mem_en),
    .mem_we_sv(mem_we),
    .mem_addr_sv(mem_addr),
    .mem_di_sv(mem_di)
);