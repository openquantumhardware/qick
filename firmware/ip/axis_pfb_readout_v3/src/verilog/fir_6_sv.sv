`timescale 1ns / 1ps

module fir_6_sv (
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
        -468,-567,12825,3650,1228,-446,0,-506,95,10125,6123,877,-491,0,
        -504,649,7431,8770,387,-510,0,-471,1070,4859,11481,-225,-492,0,
        -417,1349,2508,14140,-928,-432,0,-349,1487,461,16624,-1679,-323,12,
        -277,1496,-1224,18814,-2423,-164,11,-206,1396,-2511,20604,-3094,43,5
    };

    fir_axis_model_sv #(
        .COEFFS(COEFFS)
    ) u_model (
        .*
    );

endmodule
