`timescale 1ns / 1ps

module fir_4_sv (
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
        -451,-746,13487,3070,1293,-432,0,-500,-62,10804,5485,978,-482,0,
        -508,522,8098,8098,522,-508,0,-482,978,5485,10804,-62,-500,0,
        -432,1293,3070,13487,-746,-451,0,-367,1466,940,16026,-1490,-355,12,
        -295,1505,-839,18300,-2241,-208,12,-224,1430,-2227,20199,-2937,-13,7
    };

    fir_axis_model_sv #(
        .COEFFS(COEFFS)
    ) u_model (
        .*
    );

endmodule
