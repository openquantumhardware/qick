///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : sgv6
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    sgv6.sv
//!
//! @brief   sgv6
//!
//! @details
//!
//!
//! Arbitrary signal generator datapath: envelope x DDS, gain and output.
//!
//! Core datapath of the v6 signal generator. For each of N_DDS parallel lanes
//! it reads an envelope sample from memory, optionally up-converts it by
//! multiplying with a DDS carrier, applies an output gain, and drives the
//! 16-bit-per-lane AXI-Stream output. The ctrl_sgv6 control block sequences
//! the operation from the waveform FIFO and produces gain/src/stdy/en plus the
//! per-lane DDS phase control words.
//!
//! Output source (src, from outsel in the descriptor):
//! 0 : product (envelope x DDS)   1 : DDS only   2 : envelope (memory) only
//!
//! AMPLITUDE / SCALING NOTES (current behaviour, under review)
//! The DDS (dds_compiler_0) runs in Full_Range, 16-bit, twos-complement mode,
//! so its sine/cosine span approximately [-2^15, +2^15-1]. The amplitude chain
//! has several fixed-point steps whose scaling is being characterised:
//!
//! (1) Envelope x DDS product:
//! prod_y_full_real = (a_real*b_real) - (a_imag*b_imag)   [signed 32]
//! prod_y           = prod_y_full_real[31:16]
//! Taking [31:16] of a signed 16x16 product keeps the high half. Because a
//! signed 16x16 product effectively fits in 31 bits, this introduces a
//! factor of ~0.5 relative to taking [30:15], and drops one LSB of
//! precision.
//!
//! (2) Product x gain:
//! prodg_y_full_real = dout_mux_la * gain   [signed 32]
//! round             = prodg_y_full_real_r2[30:15]
//! Here bits [30:15] are taken (NOT [31:16] as in step 1). This is
//! inconsistent with step 1 and ignores bit 31, so large gain*envelope
//! products are not represented correctly.
//!
//! (3) Envelope-only path (src=2) uses (mem >> 1) "to match product path
//! scaling", i.e. it bakes in the 0.5 factor from step 1.
//!
//! (4) There is NO saturation anywhere. When gain*envelope*DDS exceeds the
//! 16-bit output range the result WRAPS (jumps from large positive to
//! large negative). With the DDS in Full_Range and envelope/gain near
//! MAXV this is the suspected cause of the unexpected output levels.
//!
//! AMPLITUDE / SCALING (FIXED)
//! Envelope x DDS product quantization uses [30:15] (full Q15 scale). The
//! previous [31:16] dropped a factor of 2 on the product path, so pulses with
//! an envelope came out at half the amplitude of const pulses at the same
//! gain. The baseband path no longer applies >>1 (both paths share the same
//! scale). The gain stage output is saturated to +/- MAXV (32766) to avoid
//! wrap-around at full scale.
//!
//! These points are documented as-is; the testbench compares the RTL against
//! both a faithful reference model (what the RTL does) and the intended
//! behaviour (Q15 scaling with saturation to MAXV).
//!
//! OUTPUT FLOW CONTROL
//! This is a FIXED-RATE source. Once a descriptor starts, one output beat is
//! produced per clock until nsamp beats are done; i_axis_tready is NOT honored
//! and is present only for interface conformance. The downstream consumer must
//! be able to accept a beat every cycle for the whole burst.
//! In sgv6_top the output feeds an axis_register_slice in non-blocking mode
//! (tready always high) and then the DACs, which satisfies this. Do NOT place a
//! blocking element (a FIFO that can fill, a DMA, a resampler that can stall)
//! downstream without adding a tready-gated global enable across the entire
//! pipeline first — a single output FIFO is not enough, since the generator
//! would keep filling it without back-pressuring.
//!
//! @author  QICK Development Team
//!
//! @version 1.0
module sgv6 #(
   //! Envelope-memory address width in bits (default 16).
   parameter int    N       = 16,
   //! Number of parallel DDS lanes (default 16).
   parameter int    N_DDS   = 16,
   //! "TRUE" instantiates the DDS for up-conversion; "FALSE" uses the
   parameter string GEN_DDS = "TRUE"
)(
   // Reset and clock.
   input  logic                 i_rstn          ,
   input  logic                 i_clk           ,
   // FIFO interface.
   output logic                 o_fifo_rd_en    ,
   input  logic                 i_fifo_empty    ,
   input  logic [159:0]         i_fifo_dout     ,
   // Memory interface.
   output logic [N-1:0]         o_mem_addr      ,
   input  logic [N_DDS*16-1:0]  i_mem_dout_real ,
   input  logic [N_DDS*16-1:0]  i_mem_dout_imag ,
   // AXIS output.
   input  logic                 i_axis_tready   , // verilog_lint: waive unused — fixed-rate output, tready not honored (see header)
   output logic                 o_axis_tvalid   ,
   output logic [N_DDS*16-1:0]  o_axis_tdata    ,
   // Saturation flag: asserted when any lane clamps to +/- MAXV this cycle.
   output logic                 o_sat
);

   // --------------------------------------------------------------------------
   // Internal signals.
   // --------------------------------------------------------------------------
   // Memory address.
   logic [N-1:0] mem_addr_int;
   logic [N-1:0] mem_addr_int_r;

   // DDS input control.
   logic                 dds_tvalid_r;
   logic [N_DDS*72-1:0]  dds_ctrl_int;
   logic [N_DDS*72-1:0]  dds_ctrl_int_r;

   // DDS output.
   logic [31:0] dds_dout    [N_DDS];
   logic [31:0] dds_dout_r1 [N_DDS];
   logic [31:0] dds_dout_la [N_DDS];
   logic [15:0] dds_la_mux  [N_DDS];

   // Memory data.
   logic [15:0] mem_real_r1 [N_DDS];
   logic [15:0] mem_imag_r1 [N_DDS];
   logic [15:0] mem_real_la [N_DDS];
   logic [15:0] mem_la_mux  [N_DDS];

   // Product.
   logic signed [31:0] prod_y_full_real_a    [N_DDS];
   logic signed [31:0] prod_y_full_real_b    [N_DDS];
   logic signed [31:0] prod_y_full_real_a_r1 [N_DDS];
   logic signed [31:0] prod_y_full_real_b_r1 [N_DDS];
   logic signed [31:0] prod_y_full_real_a_r2 [N_DDS];
   // Product-only input registers (see gen_dds_regs): equivalent to the
   // *_la registers, kept separate so the DSPs can absorb them.
   (* equivalent_register_removal = "no" *) logic signed [15:0] prod_a_real_r  [N_DDS];
   (* equivalent_register_removal = "no" *) logic signed [15:0] prod_b_real_r  [N_DDS];
   (* equivalent_register_removal = "no" *) logic signed [15:0] prod_a_imag_r  [N_DDS];
   (* equivalent_register_removal = "no" *) logic signed [15:0] prod_b_imag_r  [N_DDS];
   logic signed [15:0] prod_a_imag_rr [N_DDS];
   logic signed [15:0] prod_b_imag_rr [N_DDS];
   logic [15:0] mem_real_la8 [N_DDS];
   logic [15:0] mem_imag_la8 [N_DDS];
   logic signed [31:0] prod_y_full_real      [N_DDS];
   logic        [15:0] prod_y_real           [N_DDS];
   logic        [15:0] prod_y                [N_DDS];
   logic        [15:0] prod_y_r1             [N_DDS];
   logic        [15:0] prod_y_mux            [N_DDS];

   // Muxed output.
   logic [15:0] dout_mux    [N_DDS];
   logic [15:0] dout_mux_la [N_DDS];

   // Product with gain.
   logic        [15:0] gain_int;
   logic signed [15:0] gain_la;
   logic signed [15:0] prodg_a_real        [N_DDS];
   logic signed [31:0] prodg_y_full_real   [N_DDS];
   logic signed [31:0] prodg_y_full_real_r1[N_DDS];
   logic signed [31:0] prodg_y_full_real_r2[N_DDS];

   // Saturation flags of the gain product, computed from its operands and
   // delayed alongside prodg_y_full_real_r1/_r2 (see the rounding below).
   logic sat_hi [N_DDS];
   logic sat_lo [N_DDS];
   logic sat_hi_r1 [N_DDS];
   logic sat_lo_r1 [N_DDS];
   logic sat_hi_r2 [N_DDS];
   logic sat_lo_r2 [N_DDS];

   // Rounding.
   logic [15:0] round [N_DDS];

   // Last sample register.
   logic [15:0] last_r [N_DDS];

   // Output source selection.
   logic [1:0] src_int;
   logic [1:0] src_la;

   // Steady value selection.
   logic stdy_int;
   logic stdy_la;

   // Output enable.
   logic en_int;
   logic en_la;
   logic en_la_r;

   // Saturation detect (per lane).
   logic [N_DDS-1:0] sat_lane;

   // --------------------------------------------------------------------------
   // Control block.
   // --------------------------------------------------------------------------
   ctrl_sgv6 #(
      .N     (N),
      .N_DDS (N_DDS)
   ) ctrl_i (
      .i_rstn       (i_rstn),
      .i_clk        (i_clk),
      .o_fifo_rd_en (o_fifo_rd_en),
      .i_fifo_empty (i_fifo_empty),
      .i_fifo_dout  (i_fifo_dout),
      .o_dds_ctrl   (dds_ctrl_int),
      .o_mem_addr   (mem_addr_int),
      .o_gain       (gain_int),
      .o_src        (src_int),
      .o_stdy       (stdy_int),
      .o_en         (en_int)
   );

   // --------------------------------------------------------------------------
   // Per-lane datapath.
   // --------------------------------------------------------------------------
   generate
      for (genvar i = 0; i < N_DDS; i = i + 1) begin : gen_dds

         if (GEN_DDS == "TRUE") begin : gen_with_dds
            // DDS (Full_Range, 16-bit, latency 10). Output: {sin[15:0], cos[15:0]}.
            dds_compiler_signal_gen dds_i (
               .aclk                (i_clk),
               .s_axis_phase_tvalid (dds_tvalid_r),
               .s_axis_phase_tdata  (dds_ctrl_int_r[i*72 +: 72]),
               .m_axis_data_tvalid  (),
               .m_axis_data_tdata   (dds_dout[i])
            );

            // Latency for dds_dout (product path).
            delay_line #(.N(1), .M(32)) dds_dout_latency_reg_i (
               .i_clk  (i_clk),
               .i_rstn (i_rstn),
               .i_data (dds_dout_r1[i]),
               .o_data (dds_dout_la[i])
            );

            // Latency for dds_dout (mux path).
            delay_line #(.N(3), .M(16)) dds_mux_latency_reg_i (
               .i_clk  (i_clk),
               .i_rstn (i_rstn),
               .i_data (dds_dout_la[i][15:0]),
               .o_data (dds_la_mux[i])
            );
         end

         // Latency for real memory data (product path).
         delay_line #(.N(8), .M(16)) mem_real_latency_reg_i (
            .i_clk  (i_clk),
            .i_rstn (i_rstn),
            .i_data (mem_real_r1[i]),
            .o_data (mem_real_la8[i])
         );

         // Latency for imaginary memory data (product path).
         delay_line #(.N(8), .M(16)) mem_imag_latency_reg_i (
            .i_clk  (i_clk),
            .i_rstn (i_rstn),
            .i_data (mem_imag_r1[i]),
            .o_data (mem_imag_la8[i])
         );

         // Latency for real memory data (mux path).
         delay_line #(.N(3), .M(16)) mem_mux_latency_reg_i (
            .i_clk  (i_clk),
            .i_rstn (i_rstn),
            .i_data (mem_real_la[i]),
            .o_data (mem_la_mux[i])
         );

         // Latency for dout_mux (envelope x dds).
         delay_line #(.N(2), .M(16)) dout_mux_latency_reg_i (
            .i_clk  (i_clk),
            .i_rstn (i_rstn),
            .i_data (dout_mux[i]),
            .o_data (dout_mux_la[i])
         );

         // -----------------------------------------------------------------
         // Registers.
         // -----------------------------------------------------------------
         if (GEN_DDS == "TRUE") begin : gen_dds_regs
            always_ff @(posedge i_clk) begin
               if (~i_rstn) begin
                  dds_dout_r1[i] <= '0;
                  prod_y_r1[i]   <= '0;
               end
               else begin
                  dds_dout_r1[i] <= dds_dout[i];
                  prod_y_r1[i]   <= prod_y[i];
               end
            end
            // Complex real part a*c - b*d as Xilinx's cascaded two-DSP
            // template, one ALU per cycle:
            //   DSP1: A/B = prod_a/b_real_r, M = a_r1, P = a_r2 -> PCOUT
            //   DSP2: A/B = prod_a/b_imag_r, _rr, M = b_r1,
            //         P = PCIN - M = prod_y_r1
            // The legacy structure (inputs straight from the shared *_la
            // registers, a_r2 - b_r2 combinational) left DSP1 without a P
            // register, so both ALUs sat in one 614.4 MHz cycle: -24 ps WNS
            // in a 4x2 debug bench. The input registers here are
            // taken one stage before *_la and replace it for the product, so
            // the latency to prod_y_r1 -- and the output -- is unchanged.
            always_ff @(posedge i_clk) begin
               if (~i_rstn) begin
                  prod_a_real_r[i] <= '0;
                  prod_b_real_r[i] <= '0;
                  prod_a_imag_r[i] <= '0;
                  prod_b_imag_r[i] <= '0;
               end
               else begin
                  prod_a_real_r[i] <= dds_dout_r1[i][15:0];
                  prod_b_real_r[i] <= mem_real_la8[i];
                  prod_a_imag_r[i] <= dds_dout_r1[i][31:16];
                  prod_b_imag_r[i] <= mem_imag_la8[i];
               end
            end
            always_ff @(posedge i_clk) begin
               prod_a_imag_rr[i]        <= prod_a_imag_r[i];
               prod_b_imag_rr[i]        <= prod_b_imag_r[i];
               prod_y_full_real_a_r1[i] <= prod_y_full_real_a[i];
               prod_y_full_real_a_r2[i] <= prod_y_full_real_a_r1[i];
               prod_y_full_real_b_r1[i] <= prod_y_full_real_b[i];
            end
         end

         always_ff @(posedge i_clk) begin
            if (~i_rstn) begin
               mem_real_r1[i] <= '0;
               mem_imag_r1[i] <= '0;
               mem_real_la[i] <= '0;
               last_r[i]      <= '0;
            end
            else begin
               mem_real_r1[i] <= i_mem_dout_real[i*16 +: 16];
               mem_imag_r1[i] <= i_mem_dout_imag[i*16 +: 16];
               // 9th stage of the real-envelope delay (mux path)
               mem_real_la[i] <= mem_real_la8[i];
               if (en_la)
                  last_r[i] <= round[N_DDS-1];
            end
         end

         always_ff @(posedge i_clk) begin
            prodg_y_full_real_r1[i] <= prodg_y_full_real[i];
            prodg_y_full_real_r2[i] <= prodg_y_full_real_r1[i];
            sat_hi_r1[i]            <= sat_hi[i];
            sat_hi_r2[i]            <= sat_hi_r1[i];
            sat_lo_r1[i]            <= sat_lo[i];
            sat_lo_r2[i]            <= sat_lo_r1[i];
         end

         // -----------------------------------------------------------------
         // Combinational assignments.
         // -----------------------------------------------------------------
         if (GEN_DDS == "TRUE") begin : gen_prod_with_dds
            assign prod_y_full_real_a[i] = prod_a_real_r[i] * prod_b_real_r[i];
            assign prod_y_full_real_b[i] = prod_a_imag_rr[i] * prod_b_imag_rr[i];

            // Complex real part: a_real*b_real - a_imag*b_imag.
            assign prod_y_full_real[i] = prod_y_full_real_a_r2[i] - prod_y_full_real_b_r1[i];

            // FIX: [30:15] keeps full Q15 scale (was [31:16] -> lost factor 2).
            assign prod_y_real[i] = prod_y_full_real[i][30:15];
            assign prod_y[i]      = prod_y_real[i];
            assign prod_y_mux[i]  = prod_y_r1[i];
         end
         else begin : gen_prod_no_dds
            // FIX: no >>1 (both paths now share full Q15 scale).
            assign prod_y_mux[i]       = mem_la_mux[i];
            assign dds_la_mux[i][15:0] = (2**15) - 1;
         end

         // Output source mux.
         assign dout_mux[i] = (src_la == 0) ? prod_y_mux[i] :
                              (src_la == 1) ? dds_la_mux[i] :
                              (src_la == 2) ? mem_la_mux[i] :
                              16'h0000;

         // Product with gain.
         assign prodg_a_real[i]      = dout_mux_la[i];
         assign prodg_y_full_real[i] = prodg_a_real[i] * gain_la;

         // FIX: rounding with saturation (clamp to +/- MAXV, avoid wrap).
         // round = prodg_y_full_real_r2[30:15], clamped to +/- MAXV (32766) when
         // prodg_y_full_real_r2[31:15] is outside [-32766, 32766]. For a 16x16
         // signed product that happens for 7 operand pairs only (checked
         // exhaustively over all 2^32 pairs):
         //   > +32766: both operands <= -32767 and at least one is -32768
         //   < -32766: one operand is +32767 and the other <= -32767
         // so the two flags are decoded from the multiplier's operands and
         // registered with the product: same value on the same clock as a
         // comparison on prodg_y_full_real_r2, without its 17-bit compare between
         // the last product register and the output port (it failed timing at
         // 614.4 MHz in 216/tpv2_demo).
         assign sat_hi[i] = (prodg_a_real[i] <= -16'sd32767) && (gain_la <= -16'sd32767) &&
                            ((prodg_a_real[i] == -16'sd32768) || (gain_la == -16'sd32768));
         assign sat_lo[i] = ((prodg_a_real[i] == 16'sd32767) && (gain_la <= -16'sd32767)) ||
                            ((gain_la == 16'sd32767) && (prodg_a_real[i] <= -16'sd32767));
         assign round[i]  = sat_hi_r2[i] ?  16'sd32766 :                        // +MAXV
                            sat_lo_r2[i] ? -16'sd32766 :                        // -MAXV
                            prodg_y_full_real_r2[i][30:15];

         // Saturation flag for this lane (only meaningful while output enabled).
         assign sat_lane[i] = en_la_r & (sat_hi_r2[i] | sat_lo_r2[i]);

         // Output.
         assign o_axis_tdata[i*16 +: 16] = (en_la_r == 1'b1) ? round[i]  :
                                           (stdy_la == 1'b0) ? last_r[i]  :
                                           16'h0000;
      end
   endgenerate

   // --------------------------------------------------------------------------
   // Latency lines for control signals.
   // --------------------------------------------------------------------------
   delay_line #(.N(16), .M(2)) src_latency_reg_i (
      .i_clk (i_clk), .i_rstn (i_rstn), .i_data (src_int), .o_data (src_la)
   );
   delay_line #(.N(18), .M(16)) gain_latency_reg_i (
      .i_clk (i_clk), .i_rstn (i_rstn), .i_data (gain_int), .o_data (gain_la)
   );
   delay_line #(.N(20), .M(1)) stdy_latency_reg_i (
      .i_clk (i_clk), .i_rstn (i_rstn), .i_data (stdy_int), .o_data (stdy_la)
   );
   delay_line #(.N(19), .M(1)) en_latency_reg_i (
      .i_clk (i_clk), .i_rstn (i_rstn), .i_data (en_int), .o_data (en_la)
   );

   // --------------------------------------------------------------------------
   // DDS input control register.
   // --------------------------------------------------------------------------
   generate
      if (GEN_DDS == "TRUE") begin : gen_dds_ctrl_reg
         always_ff @(posedge i_clk) begin
            if (~i_rstn) begin
               dds_tvalid_r   <= '0;
               dds_ctrl_int_r <= '0;
            end
            else begin
               dds_tvalid_r   <= 1'b1;
               dds_ctrl_int_r <= dds_ctrl_int;
            end
         end
      end
   endgenerate

   // --------------------------------------------------------------------------
   // Memory address / output enable registers.
   // --------------------------------------------------------------------------
   always_ff @(posedge i_clk) begin
      if (~i_rstn) begin
         mem_addr_int_r <= '0;
         en_la_r        <= '0;
      end
      else begin
         mem_addr_int_r <= mem_addr_int;
         en_la_r        <= en_la;
      end
   end

   // --------------------------------------------------------------------------
   // Outputs.
   // --------------------------------------------------------------------------
   assign o_mem_addr    = mem_addr_int_r;
   assign o_axis_tvalid = en_la_r;
   assign o_sat         = |sat_lane;  //any lane saturated this cycle

endmodule

