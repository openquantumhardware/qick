`timescale 1ns / 1ps

module fir_3_sv (
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
        -174,1312,-3001,21320,-3381,161,-1,-116,1095,-3680,22349,-3813,421,-20,
        -68,835,-3979,22799,-3999,697,-49,-33,558,-3941,22648,-3874,969,-91,
        -9,288,-3624,21904,-3390,1211,-143,5,43,-3094,20604,-2511,1396,-206,
        11,-164,-2423,18814,-1224,1496,-277,12,-323,-1679,16624,461,1487,-349
    };

    fir_axis_model_sv #(
        .COEFFS(COEFFS)
    ) u_model (
        .*
    );

endmodule
