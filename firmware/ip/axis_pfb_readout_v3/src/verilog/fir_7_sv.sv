`timescale 1ns / 1ps

module fir_7_sv (
    input  logic        aclk,
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
        -143,1211,-3390,21904,-3624,288,-9,-91,969,-3874,22648,-3941,558,-33,
        -49,697,-3999,22799,-3979,835,-68,-20,421,-3813,22349,-3680,1095,-116,
        -1,161,-3381,21320,-3001,1312,-174,9,-66,-2772,19765,-1918,1458,-241,
        12,-249,-2056,17763,-430,1507,-313,90,-383,-1301,15411,1442,1435,-384
    };

    fir_axis_model_sv #(
        .COEFFS(COEFFS)
    ) u_model (
        .*
    );

endmodule
