// Module Name: lo_spi_mux_v2
// Converted from VHDL to Verilog

module lo_spi_mux_v2 (
    input  wire [2:0] ss_in,
    output wire ss0_out,
    output wire ss1_out,
    output wire ss2_out,
    input  wire sdo0_in,
    input  wire sdo1_in,
    input  wire sdo2_in,
    output wire sdo_out
);

// Assign ss outputs
assign ss0_out = ss_in[0];
assign ss1_out = ss_in[1];
assign ss2_out = ss_in[2];

// SDO mux
assign sdo_out = (ss_in == 3'b110) ? sdo0_in :
                 (ss_in == 3'b101) ? sdo1_in :
                 (ss_in == 3'b011) ? sdo2_in :
                 1'b1;

endmodule
