///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : tpv2_dsp_macro
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    tpv2_dsp_macro.sv
//!
//! @brief   Behavioural model (sim/lint only) of the Xilinx "DSP Macro" IP
//! instance used by tprocv2's `arith` peripheral (`dsp_macro_0.xci`,
//! `xilinx.com:ip:dsp_macro:1.0`, DSP48E2-backed).
//!
//! @details
//!
//! Ground truth for the instruction set and widths was read from the actual
//! Vivado-generated wrapper checked into this repo
//! (`firmware/Projects/.../src/dsp_macro_0/synth/dsp_macro_0.vhd`, generic
//! `C_OPMODES`), not guessed from the `.xci` alone. `sel_i` selects one of 9
//! instructions, assumed indexed in the order they were configured
//! (`instruction1`..`instruction8`, `instruction_list`) — this is the
//! standard behavior of the Xilinx DSP Macro wizard's "instruction list"
//! mode; not independently confirmed against Xilinx's internal (proprietary,
//! "DO NOT MODIFY") `dsp_macro_v1_0_3` implementation, which this model does
//! not read from or copy.
//!
//! | sel_i | Instruction  |
//! |-------|--------------|
//! | 0     | A*B          |
//! | 1     | A*B+C        |
//! | 2     | A*B-C        |
//! | 3     | (A+D)*B      |
//! | 4     | (A+D)*B+C    |
//! | 5     | (A+D)*B-C    |
//! | 6     | (D-A)*B      |
//! | 7     | (D-A)*B+C    |
//! | 8     | (D-A)*B-C    |
//!
//! Widths (from the .xci: a_width=27, b_width=18, c_width=32, d_width=27,
//! p_width=46) and the pre-adder width (27 bits, matching the multiplier's A
//! input, so `A+D`/`D-A` wrap the same way a real DSP48E2 pre-adder would)
//! are reproduced exactly. The internal DSP48E2 register topology (A1/A2/AD/
//! M/P stages, `C_REG_CONFIG`) is NOT reproduced — only a parameterized
//! output latency, same simplification already used by
//! `dds_compiler_model.sv` for other Xilinx DSP48-based IP. This is safe
//! because the only consumer, `tpv2_arith`, never reads `p_o` before its own
//! `ready_o` (which encodes a fixed, independently-verified 4-cycle latency
//! from `firmware/ip/qick_processor/src/_qproc_ips.sv`'s `arith` module, not
//! derived from this model).
//!
//! For synthesis/packaging use the real `.xci`
//! (`rtl_lib/xci/tpv2_dsp_macro/dsp_macro_0.xci`), not this model.
//!
//! @author  QICK Development Team
//!
//! @version 1.0
module tpv2_dsp_macro #(
    parameter int LATENCY = 1  //! output pipeline depth (behavioral only, see @details)
)(
    input  logic                clk_i,
    input  logic         [3:0]  sel_i,
    input  logic signed [26:0]  a_i,
    input  logic signed [17:0]  b_i,
    input  logic signed [31:0]  c_i,
    input  logic signed [26:0]  d_i,
    output logic signed [45:0]  p_o
);

    logic signed [26:0] apd, dma;  // A+D, D-A (27-bit pre-adder, matches DSP48E2 AD path width)
    logic signed [44:0] ab_prod, apdb_prod, dmab_prod;
    logic signed [45:0] result;

    assign apd = a_i + d_i;
    assign dma = d_i - a_i;

    assign ab_prod   = a_i * b_i;
    assign apdb_prod = apd * b_i;
    assign dmab_prod = dma * b_i;

    always_comb begin
        unique case (sel_i)
            4'd0: result = 46'(ab_prod);
            4'd1: result = 46'(ab_prod)   + 46'(c_i);
            4'd2: result = 46'(ab_prod)   - 46'(c_i);
            4'd3: result = 46'(apdb_prod);
            4'd4: result = 46'(apdb_prod) + 46'(c_i);
            4'd5: result = 46'(apdb_prod) - 46'(c_i);
            4'd6: result = 46'(dmab_prod);
            4'd7: result = 46'(dmab_prod) + 46'(c_i);
            4'd8: result = 46'(dmab_prod) - 46'(c_i);
            default: result = '0;
        endcase
    end

    logic signed [45:0] pipe [LATENCY];
    always_ff @(posedge clk_i) begin
        pipe[0] <= result;
        for (int i = 1; i < LATENCY; i++) pipe[i] <= pipe[i-1];
    end
    assign p_o = pipe[LATENCY-1];

endmodule
