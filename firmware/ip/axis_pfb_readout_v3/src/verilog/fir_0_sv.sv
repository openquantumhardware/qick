`timescale 1ns / 1ps

module fir_0_sv (
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
        -409,-1113,14782,1965,1397,-401,0,-481,-393,12156,4247,1154,-459,0,
        -509,245,9446,6773,767,-499,0,-499,767,6773,9446,245,-509,0,
        -459,1154,4247,12156,-393,-481,0,-401,1397,1965,14782,-1113,-409,0,
        -331,1501,4,17203,-1868,-288,12,-259,1480,-1584,19303,-2600,-116,10
    };

    fir_axis_model_sv #(
        .COEFFS(COEFFS)
    ) u_model (
        .*
    );

endmodule
