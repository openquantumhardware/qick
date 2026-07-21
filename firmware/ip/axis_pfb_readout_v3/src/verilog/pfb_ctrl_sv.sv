// -----------------------------------------------------------------------------
// pfb_ctrl_sv : SystemVerilog translation of pfb_ctrl.vhd
// -----------------------------------------------------------------------------
// Structural wrapper: instantiates pfb_cfg_sv (FIR reload/config stream) and
// pfb_framing_sv (framing pulse generator).
//
// Literal translation of the original VHDL structural architecture.
// -----------------------------------------------------------------------------
`timescale 1ns / 1ps

module pfb_ctrl_sv #(
    // Number of channels.
    parameter int N = 8
)(
    input  logic        aresetn,
    input  logic        aclk,

    // M_AXIS for Configuration.
    output logic        m_axis_config_tvalid,
    input  logic        m_axis_config_tready,
    output logic        m_axis_config_tlast,
    output logic [7:0]  m_axis_config_tdata,

    // Filter config.
    input  logic        cfg_en,

    // Framing.
    input  logic        tready,
    input  logic        tvalid,
    input  logic        fr_sync,
    output logic        fr_out
);

    // PFB configuration.
    pfb_cfg_sv #(
        .N (N)
    ) cfg_i (
        .rstn   (aresetn),
        .clk    (aclk),
        .cfg_en (cfg_en),
        .tready (m_axis_config_tready),
        .tvalid (m_axis_config_tvalid),
        .tlast  (m_axis_config_tlast),
        .tdata  (m_axis_config_tdata)
    );

    // PFB framing.
    pfb_framing_sv #(
        .N (N)
    ) framing_i (
        .rstn    (aresetn),
        .clk     (aclk),
        .tready  (tready),
        .tvalid  (tvalid),
        .fr_sync (fr_sync),
        .fr_out  (fr_out)
    );

endmodule
