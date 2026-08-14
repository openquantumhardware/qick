`timescale 1ns / 1ps

module fir_2_sv (
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
        -432,-928,14140,2508,1349,-417,0,-492,-225,11481,4859,1070,-471,0,
        -510,387,8770,7431,649,-504,0,-491,877,6123,10125,95,-506,0,
        -446,1228,3650,12825,-567,-468,0,-384,1435,1442,15411,-1301,-383,90,
        -313,1507,-430,17763,-2056,-249,12,-241,1458,-1918,19765,-2772,-66,9
    };

    fir_axis_model_sv #(
        .COEFFS(COEFFS)
    ) u_model (
        .*
    );

endmodule
