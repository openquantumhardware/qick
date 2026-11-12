`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : sg_translator
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    sg_translator.sv
//!
//! @brief   Re-packs a tProc v2 wave-port descriptor for one kind of
//!          generator or readout.
//!
//! @details
//! Faithful port of the legacy QICK IP (openquantumhardware/qick firmware/ip/
//! qick_sg_translator/src/sg_translator.v, QICK:QICK:sg_translator:1.0).
//! Purely combinational. Input: the 168-bit tProc v2 wave-port word
//!
//!   | 167..152 | 151..120 | 119..88 |  87..64 |  63..32 |  31..0 |
//!   |   CONF   |  LENGTH  |  GAIN   |   ENV   |  PHASE  |  FREQ  |
//!
//! with CONF[4]=phrst, [3]=stdysel, [2]=mode, [1:0]=outsel. OUT_TYPE picks
//! the single output that is driven (the others have tvalid=0, data still
//! assigned):
//!
//!   0 -> m_gen_v6_axis     (160 bit, axis_signal_gen_v6 descriptor)
//!   1 -> m_int4_axis       ( 88 bit, axis_sg_int4 descriptor, 16-bit fields)
//!   2 -> m_mux4_axis       ( 40 bit, {CONF[7:0], LENGTH})
//!   3 -> m_readout_v3_axis ( 88 bit, axis_readout_v3 / dyn_readout descriptor)
//!
//! s_tproc_axis_tready follows the selected output's tready (0 for an
//! OUT_TYPE outside 0..3). Field layouts are in the assigns below.
//!
//! Port names differ from the legacy file on purpose: the legacy IP named its
//! interfaces s_tproc_axis / m_readout_v3_axis over ports called s_axis_* /
//! m_readout_axis_*. Here the ports carry the interface names, so the
//! packager infers exactly the legacy interface names (the block designs and
//! qick_lib's trace, which follows 's_tproc_axis', connect by interface).
//!
//! @author  QICK Development Team
//!
//! @version 1.0
///////////////////////////////////////////////////////////////////////////////
module sg_translator #(
    parameter int OUT_TYPE = 0  //! 0: gen_v6, 1: int4, 2: mux4, 3: readout_v3
) (
    input  logic         aresetn,  // verilog_lint: waive unused (combinational, kept for the BD)
    input  logic         aclk,     // verilog_lint: waive unused (combinational, kept for the BD)

    // tProc v2 wave port.
    input  logic [167:0] s_tproc_axis_tdata,
    input  logic         s_tproc_axis_tvalid,
    output logic         s_tproc_axis_tready,

    // OUT_TYPE 0: axis_signal_gen_v6.
    output logic [159:0] m_gen_v6_axis_tdata,
    output logic         m_gen_v6_axis_tvalid,
    input  logic         m_gen_v6_axis_tready,

    // OUT_TYPE 1: axis_sg_int4.
    output logic [87:0]  m_int4_axis_tdata,
    output logic         m_int4_axis_tvalid,
    input  logic         m_int4_axis_tready,

    // OUT_TYPE 2: axis_sg_mux4.
    output logic [39:0]  m_mux4_axis_tdata,
    output logic         m_mux4_axis_tvalid,
    input  logic         m_mux4_axis_tready,

    // OUT_TYPE 3: axis_readout_v3 (also axis_dyn_readout_v1).
    output logic [87:0]  m_readout_v3_axis_tdata,
    output logic         m_readout_v3_axis_tvalid,
    input  logic         m_readout_v3_axis_tready
);

    // Descriptor fields.
    logic [15:0] conf;
    logic [31:0] nsamp, gain, phase, freq;
    logic [23:0] addr;
    logic        phrst, stdysel, mode;
    logic [1:0]  outsel;

    assign conf    = s_tproc_axis_tdata[167:152];
    assign nsamp   = s_tproc_axis_tdata[151:120];
    assign gain    = s_tproc_axis_tdata[119: 88];
    assign addr    = s_tproc_axis_tdata[ 87: 64];
    assign phase   = s_tproc_axis_tdata[ 63: 32];
    assign freq    = s_tproc_axis_tdata[ 31:  0];

    assign phrst   = conf[4];
    assign stdysel = conf[3];
    assign mode    = conf[2];
    assign outsel  = conf[1:0];

    localparam bit GEN_V6_EN  = (OUT_TYPE == 0);
    localparam bit INT4_EN    = (OUT_TYPE == 1);
    localparam bit MUX4_EN    = (OUT_TYPE == 2);
    localparam bit READOUT_EN = (OUT_TYPE == 3);

    assign s_tproc_axis_tready = GEN_V6_EN  ? m_gen_v6_axis_tready     :
                                 INT4_EN    ? m_int4_axis_tready       :
                                 MUX4_EN    ? m_mux4_axis_tready       :
                                 READOUT_EN ? m_readout_v3_axis_tready : 1'b0;

    // axis_signal_gen_v6:
    // | 159..149 | 148   | 147     | 146  | 145..144 | 143..128 | 127..112 | 111..96 | 95..80 | 79..64 | 63..32 | 31..0 |
    // | 0        | phrst | stdysel | mode | outsel   | nsamp    | 0        | gain    | 0      | addr   | phase  | freq  |
    assign m_gen_v6_axis_tdata = {11'd0, phrst, stdysel, mode, outsel, nsamp[15:0],
                                  16'd0, gain[15:0], 16'd0, addr[15:0], phase, freq};
    assign m_gen_v6_axis_tvalid = GEN_V6_EN ? s_tproc_axis_tvalid : 1'b0;

    // axis_sg_int4:
    // | 87..85 | 84    | 83      | 82   | 81..80 | 79..64 | 63..48 | 47..32 | 31..16 | 15..0 |
    // | 0      | phrst | stdysel | mode | outsel | nsamp  | gain   | addr   | phase  | freq  |
    assign m_int4_axis_tdata = {3'd0, phrst, stdysel, mode, outsel, nsamp[15:0],
                                gain[15:0], addr[15:0], phase[15:0], freq[15:0]};
    assign m_int4_axis_tvalid = INT4_EN ? s_tproc_axis_tvalid : 1'b0;

    // axis_sg_mux4: | 39..32 mask = conf[7:0] | 31..0 nsamp |
    assign m_mux4_axis_tdata  = {conf[7:0], nsamp};
    assign m_mux4_axis_tvalid = MUX4_EN ? s_tproc_axis_tvalid : 1'b0;

    // axis_readout_v3:
    // | 87..84 | 83    | 82   | 81..80 | 79..64 | 63..32 | 31..0 |
    // | 0      | phrst | mode | outsel | nsamp  | phase  | freq  |
    assign m_readout_v3_axis_tdata = {4'd0, phrst, mode, outsel, nsamp[15:0], phase, freq};
    assign m_readout_v3_axis_tvalid = READOUT_EN ? s_tproc_axis_tvalid : 1'b0;

endmodule
