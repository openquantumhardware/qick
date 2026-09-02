`timescale 1ns / 1ps

module fir_1_sv (
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
        -190,1356,-2768,20978,-3243,101,2,-129,1154,-3547,22144,-3726,353,-14,
        -79,903,-3937,22742,-3979,627,-41,-41,627,-3979,22742,-3937,903,-79,
        -14,353,-3726,22144,-3547,1154,-129,2,101,-3243,20978,-2768,1356,-190,
        10,-116,-2600,19303,-1584,1480,-259,12,-288,-1868,17203,4,1501,-331
    };

    fir_axis_model_sv #(
        .COEFFS(COEFFS)
    ) u_model (
        .*
    );

endmodule
