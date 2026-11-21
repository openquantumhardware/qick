// Module Name: lo_spi_mux
// Converted from VHDL to Verilog

module lo_spi_mux (
    input  wire [1:0] ss_in,
    output wire ss0_out,
    output wire ss1_out,
    input  wire sdo0_in,
    input  wire sdo1_in,
    output wire sdo_out
);

// Assign ss outputs
assign ss0_out = ss_in[0];
assign ss1_out = ss_in[1];

// SDO mux
assign sdo_out = (ss_in == 2'b10) ? sdo0_in :
                 (ss_in == 2'b01) ? sdo1_in :
                 1'b1;

endmodule
