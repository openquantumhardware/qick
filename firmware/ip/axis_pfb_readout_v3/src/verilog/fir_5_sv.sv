`timescale 1ns / 1ps

module fir_5_sv (
    input  logic        aclk,
    input  logic        aresetn,
    input  logic        s_axis_data_tvalid,
    output logic        s_axis_data_tready,
    input  logic        s_axis_data_tlast,
    input  logic [31:0] s_axis_data_tdata,
    input  logic        s_axis_config_tvalid,
    output logic        s_axis_config_tready,
    input  logic        s_axis_config_tlast,
    input  logic [7:0]  s_axis_config_tdata,
    output logic        m_axis_data_tvalid,
    output logic        m_axis_data_tlast,
    output logic [31:0] m_axis_data_tdata,
    output logic        event_s_data_tlast_missing,
    output logic        event_s_data_tlast_unexpected,
    output logic        event_s_config_tlast_missing,
    output logic        event_s_config_tlast_unexpected
);

    localparam int signed COEFFS [0:55] = '{
        -158,1263,-3208,21629,-3509,223,-5,-103,1033,-3789,22517,-3885,489,-26,
        -59,766,-3999,22818,-3999,766,-59,-26,489,-3885,22517,-3789,1033,-103,
        -5,223,-3509,21629,-3208,1263,-158,7,-13,-2937,20199,-2227,1430,-224,
        12,-208,-2241,18300,-839,1505,-295,12,-355,-1490,16026,940,1466,-367
    };

    fir_axis_model_sv #(
        .COEFFS(COEFFS)
    ) u_model (
        .*
    );

endmodule
