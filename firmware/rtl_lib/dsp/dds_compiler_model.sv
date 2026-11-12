///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : dds_compiler_model
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    dds_compiler_model.sv
//!
//! @brief   dds_compiler_model
//!
//! @details
//!
//!
//! Behavioural model of Xilinx DDS Compiler v6.0 (for sim/lint only).
//!
//! Same interface as the real Xilinx IP. Phase accumulator + sin/cos.
//! Generalized to cover all six QICK DDS Compiler configurations found
//! across the codebase (dyn_readout, signal_gen, signal_gen_int,
//! signal_gen_mixmux, signal_gen_mux, readout), which differ only in
//! PHASE_WIDTH, LATENCY, and single- vs dual-output selection. Each
//! instantiation site sets these three parameters to match its own
//! dds_compiler_<variant>.xci (see the parameter table maintained in
//! docs/dds_compiler_variants.md).
//!
//! s_axis_phase_tdata layout (matches the real Xilinx IP width exactly,
//! 2*PHASE_WIDTH+8 bits -- e.g. 72 bits for PHASE_WIDTH=32, 40 bits for
//! PHASE_WIDTH=16 -- so parent RTL that already packs/connects the full
//! descriptor width does not need any adaptation):
//! [2*PHASE_WIDTH-1 : PHASE_WIDTH] = phase (absolute, already accumulated
//! upstream, e.g. by ctrl_sg_v6)
//! [PHASE_WIDTH-1 : 0]             = pinc (unused here directly; phase
//! advance is already folded into the
//! per-cycle phase_in value upstream)
//!
//! m_axis_data_tdata:
//! DUAL_OUTPUT=1 (Output_Selection=Sine_and_Cosine): {sin[15:0],cos[15:0]}
//! DUAL_OUTPUT=0 (Output_Selection=Sine only):        sin[15:0]
//!
//! For a CONSTANT carrier (amplitude tests), drive the descriptor with a
//! fixed phase; phase=0 => cos=0x7FFF, sin=0.
//!
//! @author  QICK Development Team
//!
//! @version 1.0
module dds_compiler_model #(
   //! Output pipeline latency (default 10).
   parameter int LATENCY     = 10,
   //! Width of the phase/pinc fields packed into
   parameter int PHASE_WIDTH = 32,
   //! 1 = Sine_and_Cosine (32-bit packed output),
   parameter bit DUAL_OUTPUT = 1'b1,
   //! 1 = Streaming pinc (accumulate internally);
   parameter bit STREAMING   = 1'b0,  //! 1 = Streaming pinc (accumulate internally);
                                      //! 0 = phase pre-accumulated upstream (signal_gen)
   //! 1 = the real IP's behaviour with Phase_Increment=Streaming and no TREADY,
   //! measured against its xsim model (dds_compiler_v6_0_28): the pipeline moves
   //! only on s_axis_phase_tvalid, m_axis_data_tvalid is s_axis_phase_tvalid of
   //! the same cycle, and the word presented with it is the output of the input
   //! transaction LATENCY transactions earlier (held between valids).
   //! 0 = free-running pipeline with m_axis_data_tvalid tied to 1 (the other
   //! variants, which are fed a valid every clock).
   parameter bit PHASE_GATED = 1'b0,
   //! 1 = the real IP with Phase_Increment=Streaming, Phase_offset=Streaming,
   //! Resync=true, no TREADY (every QICK signal-gen/readout variant): per input
   //! transaction, acc = (resync ? 0 : acc) + pinc and the output is sin/cos of
   //! acc + poff, with tdata = {7'b0, resync, poff, pinc}. Pipeline/valid timing as
   //! PHASE_GATED. Checked against dds_compiler_v6_0_28 for every variant's .xci.
   parameter bit RESYNC      = 1'b0,
   //! RESYNC mode only: 1 = the .xci's Negative_Sine=true (sine output negated).
   parameter bit NEGATIVE_SINE = 1'b0
)(
   input  logic                       aclk,
   input  logic                       s_axis_phase_tvalid,
   input  logic [2*PHASE_WIDTH+8-1:0] s_axis_phase_tdata,
   output logic                       m_axis_data_tvalid,
   output logic [(DUAL_OUTPUT?32:16)-1:0] m_axis_data_tdata
);

   localparam int OUT_WIDTH = DUAL_OUTPUT ? 32 : 16;

   // Phase field: upper PHASE_WIDTH bits of the packed descriptor. The
   // absolute phase is already computed upstream (e.g. by ctrl_sg_v6's
   // phase_v1 pipeline), so we use it directly as the instantaneous phase.
   logic [PHASE_WIDTH-1:0] phase_in;
   logic [PHASE_WIDTH-1:0] phase_acc = '0;   // internal accumulator for streaming mode

   logic signed [15:0] cos_v, sin_v;
   real angle;
   always_comb begin
      angle = 2.0 * 3.14159265358979323846
              * real'(phase_in) / (2.0 ** PHASE_WIDTH);
      cos_v = $rtoi($cos(angle) * 32767.0);
      sin_v = $rtoi($sin(angle) * 32767.0);
   end

   generate
      if (STREAMING) begin : gen_streaming
         // Pinc is in the LOW bits; accumulate it each valid cycle (like the
         // real IP in Phase_Increment=Streaming mode).
         logic [PHASE_WIDTH-1:0] pinc;
         assign pinc = s_axis_phase_tdata[PHASE_WIDTH-1:0];
         always_ff @(posedge aclk) begin
            if (s_axis_phase_tvalid) phase_acc <= phase_acc + pinc;
         end
         assign phase_in = phase_acc;
      end
      else begin : gen_preaccumulated
         // Phase is absolute, in the HIGH bits (signal_gen / ctrl_sg_v6 path).
         assign phase_in = s_axis_phase_tdata[2*PHASE_WIDTH-1 -: PHASE_WIDTH];
      end
   endgenerate

   logic [OUT_WIDTH-1:0] sample;
   generate
      if (DUAL_OUTPUT) begin : gen_dual_output
         assign sample = {sin_v, cos_v};
      end
      else begin : gen_single_output
         assign sample = sin_v;
      end
   endgenerate

   logic [OUT_WIDTH-1:0] pipe [LATENCY];

   generate
      if (PHASE_GATED && RESYNC) begin : gen_resync
         logic [PHASE_WIDTH-1:0] pinc_f, poff_f, acc_n;
         logic [PHASE_WIDTH-1:0] acc_r = '0;
         logic                   resync_f;
         logic signed [15:0]     cos_r, sin_r;
         real                    angle_r;
         assign pinc_f   = s_axis_phase_tdata[PHASE_WIDTH-1:0];
         assign poff_f   = s_axis_phase_tdata[2*PHASE_WIDTH-1 -: PHASE_WIDTH];
         assign resync_f = s_axis_phase_tdata[2*PHASE_WIDTH];
         assign acc_n    = (resync_f ? '0 : acc_r) + pinc_f;
         always_comb begin
            angle_r = 2.0 * 3.14159265358979323846
                      * real'(PHASE_WIDTH'(acc_n + poff_f)) / (2.0 ** PHASE_WIDTH);
            cos_r = 16'($rtoi($cos(angle_r) * 32767.0));
            sin_r = 16'($rtoi($sin(angle_r) * (NEGATIVE_SINE ? -32767.0 : 32767.0)));
         end
         int unsigned fill = 0;
         always_ff @(posedge aclk) begin
            if (s_axis_phase_tvalid) begin
               acc_r   <= acc_n;
               pipe[0] <= DUAL_OUTPUT ? OUT_WIDTH'({sin_r, cos_r}) : OUT_WIDTH'(sin_r);
               for (int k = 1; k < LATENCY; k++)
                  pipe[k] <= pipe[k-1];
               if (fill < LATENCY) fill <= fill + 1;
            end
         end
         assign m_axis_data_tdata  = pipe[LATENCY-1];
         assign m_axis_data_tvalid = s_axis_phase_tvalid && (fill >= LATENCY);
      end
      else if (PHASE_GATED) begin : gen_phase_gated
         // One stage per input transaction; the real IP's word already includes
         // the pinc of its own transaction, so the stage takes the accumulator
         // after this transaction's increment. The word shown with the valid of
         // transaction t is then the phase after transaction t - LATENCY. Like the
         // real IP, no output valid until LATENCY transactions have filled it.
         logic signed [15:0] cos_n, sin_n;
         real angle_n;
         always_comb begin
            angle_n = 2.0 * 3.14159265358979323846
                      * real'(PHASE_WIDTH'(phase_in + s_axis_phase_tdata[PHASE_WIDTH-1:0]))
                      / (2.0 ** PHASE_WIDTH);
            cos_n = 16'($rtoi($cos(angle_n) * 32767.0));
            sin_n = 16'($rtoi($sin(angle_n) * 32767.0));
         end
         int unsigned fill = 0;
         always_ff @(posedge aclk) begin
            if (s_axis_phase_tvalid) begin
               pipe[0] <= DUAL_OUTPUT ? OUT_WIDTH'({sin_n, cos_n}) : OUT_WIDTH'(sin_n);
               for (int k = 1; k < LATENCY; k++)
                  pipe[k] <= pipe[k-1];
               if (fill < LATENCY) fill <= fill + 1;
            end
         end
         assign m_axis_data_tdata  = pipe[LATENCY-1];
         assign m_axis_data_tvalid = s_axis_phase_tvalid && (fill >= LATENCY);
      end
      else begin : gen_free_running
         always_ff @(posedge aclk) begin
            pipe[0] <= sample;
            for (int k = 1; k < LATENCY; k++)
               pipe[k] <= pipe[k-1];
         end
         assign m_axis_data_tdata  = pipe[LATENCY-1];
         assign m_axis_data_tvalid = 1'b1;
      end
   endgenerate

endmodule

