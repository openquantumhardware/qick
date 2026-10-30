///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : ctrl_sgv4
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    ctrl_sgv4.sv
//!
//! @brief   ctrl_sgv4
//!
//! @details
//!
//!
//! Control / sequencer for the v4 arbitrary signal generator.
//!
//! Reads waveform descriptors from an input FIFO and produces, cycle by cycle,
//! the control signals that drive the sgv4 datapath: the per-DDS phase
//! control word (dds_ctrl_o), the envelope-memory read address (mem_addr_o),
//! the output gain (gain_o), the output source selector (src_o), the steady
//! value selector (stdy_o), the output enable (en_o), and the I/Q output
//! selector (outsel_o).
//!
//! Each FIFO word is a 160-bit waveform descriptor with the following layout
//! (v4 format - note bit 149 for iqsel):
//!
//! | bits      | field   | width | meaning                                |
//! |-----------|---------|-------|----------------------------------------|
//! | 159 .. 150| (unused)|  10   | -                                      |
//! | 149       | iqsel   |   1   | I/Q output selection (0=I/Q, 1=I only) |
//! | 148       | phrst   |   1   | phase reset                            |
//! | 147       | stdysel |   1   | steady-value select (end of waveform)  |
//! | 146       | mode    |   1   | mode (1 = periodic/non-stop)           |
//! | 145 .. 144| outsel  |   2   | output source: 0=prod,1=dds,2=mem      |
//! | 143 .. 128| nsamp   |  16   | number of output samples               |
//! | 127 .. 112| (unused)|  16   | -                                      |
//! | 111 ..  96| gain    |  16   | output gain (signed)                   |
//! |  95 ..  80| (unused)|  16   | -                                      |
//! |  79 ..  64| addr    |  16   | envelope start address in memory       |
//! |  63 ..  32| phase   |  32   | initial phase                          |
//! |  31 ..   0| freq    |  32   | phase increment (pinc), sets frequency |
//!
//! FSM (one-hot):
//! READ_ST : assert fifo_rd_en; when a descriptor is available (or mode is
//! set), latch it and move to CNT_ST.
//! CNT_ST  : count down nsamp; when cnt_nsamp reaches 2, return to READ_ST.
//!
//! Phase generation:
//! The DDS phase per parallel lane i is phase_v1[i] = phase_v0[i] + phase_0,
//! where phase_v0[i] = pinc*i (per-lane offset for the N_DDS parallel DDS
//! blocks) and phase_0 = pinc*cnt_n + phase. The pinc*cnt_n product uses a
//! split multiplier (low/high halves, WL=17) so it maps to DSP slices and
//! meets timing.
//!
//! Pipelines:
//! Most outputs are pushed through fixed delay pipelines (gain_r*, outsel_r*,
//! stdysel_r*, addr_cnt_r*, en_reg_r*) so they line up with the latency of
//! the datapath in sgv4.
//!
//! @author  QICK Development Team
//!
//! @version 1.0
module ctrl_sgv4 #(
   //! Envelope-memory address width in bits (default 16).
   parameter int N     = 16,
   //! Number of parallel DDS lanes (default 8 for v4).
   parameter int N_DDS = 8          // v4 has 8 lanes
)(
   // Reset and clock.
   input  logic                   i_rstn       ,
   input  logic                   i_clk        ,
   // FIFO interface.
   output logic                   o_fifo_rd_en ,
   input  logic                   i_fifo_empty ,
   input  logic [159:0]           i_fifo_dout  ,
   // DDS control.
   output logic [N_DDS*72-1:0]    o_dds_ctrl   ,
   // Memory control.
   output logic [N-1:0]           o_mem_addr   ,
   // Gain.
   output logic [15:0]            o_gain       ,
   // Output source selection.
   output logic [1:0]             o_src        ,
   // Steady value selection.
   output logic                   o_stdy       ,
   // Output enable.
   output logic                   o_en         ,
   // I/Q output selection (v4 specific).
   output logic                   o_iqsel
);

   // --------------------------------------------------------------------------
   // FSM states (one-hot).
   // --------------------------------------------------------------------------
   typedef enum { READ_ST, CNT_ST } state_t;
   (* fsm_encoding = "one_hot" *) state_t state;

   // --------------------------------------------------------------------------
   // FIFO descriptor register.
   // --------------------------------------------------------------------------
   logic [159:0] fifo_dout_r;

   // Non-stop counter for time calculation (adds N_DDS samples each tick).
   logic [31:0] cnt_n;
   logic [31:0] cnt_n_reg;

   // Pinc / phase pipelines.
   logic [31:0] pinc_int;
   logic [31:0] pinc_r1, pinc_r2;
   logic [31:0] pinc_n;
   logic [31:0] pinc_n_r1, pinc_n_r2, pinc_n_r3, pinc_n_r4, pinc_n_r5;
   logic [31:0] phase_int;
   logic [31:0] phase_r1, phase_r2, phase_r3, phase_r4, phase_r5;
   logic [31:0] phase_0;
   logic [31:0] phase_0_r1;

   // Phase vectors (per DDS lane).
   logic [31:0] phase_v0    [N_DDS];
   logic [31:0] phase_v0_r1 [N_DDS];
   logic [31:0] phase_v0_r2 [N_DDS];
   logic [31:0] phase_v0_r3 [N_DDS];
   logic [31:0] phase_v0_r4 [N_DDS];
   logic [31:0] phase_v1    [N_DDS];
   logic [31:0] phase_v1_r1 [N_DDS];

   // Sync pipeline.
   logic sync_reg;
   logic sync_reg_r1, sync_reg_r2, sync_reg_r3, sync_reg_r4;
   logic sync_reg_r5, sync_reg_r6, sync_reg_r7;

   // Address.
   logic [15:0] addr_int;
   logic [15:0] addr_cnt;
   logic [15:0] addr_cnt_r1, addr_cnt_r2, addr_cnt_r3;
   logic [15:0] addr_cnt_r4, addr_cnt_r5, addr_cnt_r6;

   // Gain.
   logic [15:0] gain_int;
   logic [15:0] gain_r1, gain_r2, gain_r3, gain_r4;
   logic [15:0] gain_r5, gain_r6, gain_r7;

   // Number of samples.
   logic [15:0] nsamp_int;

   // Output selection.
   logic [1:0]  outsel_int;
   logic [1:0]  outsel_r1, outsel_r2, outsel_r3, outsel_r4;
   logic [1:0]  outsel_r5, outsel_r6, outsel_r7;

   // I/Q selection (v4 specific).
   logic        iqsel_int;
   logic        iqsel_r1, iqsel_r2, iqsel_r3, iqsel_r4;
   logic        iqsel_r5, iqsel_r6, iqsel_r7;

   // Mode.
   logic mode_int;

   // Steady value selection.
   logic stdysel_int;
   logic stdysel_r1, stdysel_r2, stdysel_r3, stdysel_r4;
   logic stdysel_r5, stdysel_r6, stdysel_r7;

   // Phase reset.
   logic phrst_int;

   // Load enable flag.
   logic load_int;
   logic load_r;

   // FIFO read enable.
   logic rd_en_int;
   logic rd_en_r1, rd_en_r2;

   // Sample counter.
   logic [15:0] cnt_nsamp_r;

   // Output enable pipeline.
   logic en_reg;
   logic en_reg_r1, en_reg_r2, en_reg_r3, en_reg_r4;
   logic en_reg_r5, en_reg_r6, en_reg_r7, en_reg_r8;

   // --------------------------------------------------------------------------
   // Main sequential block.
   // --------------------------------------------------------------------------
   always_ff @(posedge i_clk) begin
      if (~i_rstn) begin
         state          <= READ_ST;
         fifo_dout_r    <= '0;
         cnt_n          <= '0;
         cnt_n_reg      <= '0;
         pinc_r1        <= '0;
         pinc_r2        <= '0;
         pinc_n_r1      <= '0;
         pinc_n_r2      <= '0;
         pinc_n_r3      <= '0;
         pinc_n_r4      <= '0;
         pinc_n_r5      <= '0;
         phase_r1       <= '0;
         phase_r2       <= '0;
         phase_r3       <= '0;
         phase_r4       <= '0;
         phase_r5       <= '0;
         phase_0_r1     <= '0;
         sync_reg       <= '0;
         sync_reg_r1    <= '0;
         sync_reg_r2    <= '0;
         sync_reg_r3    <= '0;
         sync_reg_r4    <= '0;
         sync_reg_r5    <= '0;
         sync_reg_r6    <= '0;
         sync_reg_r7    <= '0;
         addr_cnt       <= '0;
         addr_cnt_r1    <= '0;
         addr_cnt_r2    <= '0;
         addr_cnt_r3    <= '0;
         addr_cnt_r4    <= '0;
         addr_cnt_r5    <= '0;
         addr_cnt_r6    <= '0;
         gain_r1        <= '0;
         gain_r2        <= '0;
         gain_r3        <= '0;
         gain_r4        <= '0;
         gain_r5        <= '0;
         gain_r6        <= '0;
         gain_r7        <= '0;
         outsel_r1      <= '0;
         outsel_r2      <= '0;
         outsel_r3      <= '0;
         outsel_r4      <= '0;
         outsel_r5      <= '0;
         outsel_r6      <= '0;
         outsel_r7      <= '0;
         iqsel_r1       <= '0;
         iqsel_r2       <= '0;
         iqsel_r3       <= '0;
         iqsel_r4       <= '0;
         iqsel_r5       <= '0;
         iqsel_r6       <= '0;
         iqsel_r7       <= '0;
         stdysel_r1     <= '0;
         stdysel_r2     <= '0;
         stdysel_r3     <= '0;
         stdysel_r4     <= '0;
         stdysel_r5     <= '0;
         stdysel_r6     <= '0;
         stdysel_r7     <= '0;
         load_r         <= '0;
         rd_en_r1       <= '0;
         rd_en_r2       <= '0;
         cnt_nsamp_r    <= '0;
         en_reg         <= '0;
         en_reg_r1      <= '0;
         en_reg_r2      <= '0;
         en_reg_r3      <= '0;
         en_reg_r4      <= '0;
         en_reg_r5      <= '0;
         en_reg_r6      <= '0;
         en_reg_r7      <= '0;
         en_reg_r8      <= '0;
      end
      else begin
         // FSM.
         case (state)
            READ_ST:
               if (mode_int || ~i_fifo_empty)
                  state <= CNT_ST;
            CNT_ST:
               if (cnt_nsamp_r <= 2)
                  state <= READ_ST;
            default: state <= READ_ST;
         endcase

         // Descriptor register.
         if (load_r)
            fifo_dout_r <= i_fifo_dout;

         // Non-stop time counter.
         if (sync_reg == 1'b1 && phrst_int == 1'b1)
            cnt_n <= '0;
         else
            cnt_n <= cnt_n + N_DDS;
         if (sync_reg_r1 == 1'b1)
            cnt_n_reg <= cnt_n;

         // Pinc / phase / sync pipelines.
         pinc_r1     <= pinc_int;
         pinc_r2     <= pinc_r1;
         pinc_n_r1   <= pinc_n;
         pinc_n_r2   <= pinc_n_r1;
         pinc_n_r3   <= pinc_n_r2;
         pinc_n_r4   <= pinc_n_r3;
         pinc_n_r5   <= pinc_n_r4;
         phase_r1    <= phase_int;
         phase_r2    <= phase_r1;
         phase_r3    <= phase_r2;
         phase_r4    <= phase_r3;
         phase_r5    <= phase_r4;
         phase_0_r1  <= phase_0;
         sync_reg    <= load_r;
         sync_reg_r1 <= sync_reg;
         sync_reg_r2 <= sync_reg_r1;
         sync_reg_r3 <= sync_reg_r2;
         sync_reg_r4 <= sync_reg_r3;
         sync_reg_r5 <= sync_reg_r4;
         sync_reg_r6 <= sync_reg_r5;
         sync_reg_r7 <= sync_reg_r6;

         // Address counter.
         if (rd_en_r2)
            addr_cnt <= addr_int;
         else
            addr_cnt <= addr_cnt + 1'b1;
         addr_cnt_r1 <= addr_cnt;
         addr_cnt_r2 <= addr_cnt_r1;
         addr_cnt_r3 <= addr_cnt_r2;
         addr_cnt_r4 <= addr_cnt_r3;
         addr_cnt_r5 <= addr_cnt_r4;
         addr_cnt_r6 <= addr_cnt_r5;

         // Gain pipeline.
         gain_r1 <= gain_int;
         gain_r2 <= gain_r1;
         gain_r3 <= gain_r2;
         gain_r4 <= gain_r3;
         gain_r5 <= gain_r4;
         gain_r6 <= gain_r5;
         gain_r7 <= gain_r6;

         // Output-selection pipeline.
         outsel_r1 <= outsel_int;
         outsel_r2 <= outsel_r1;
         outsel_r3 <= outsel_r2;
         outsel_r4 <= outsel_r3;
         outsel_r5 <= outsel_r4;
         outsel_r6 <= outsel_r5;
         outsel_r7 <= outsel_r6;

         // I/Q selection pipeline (v4 specific).
         iqsel_r1 <= iqsel_int;
         iqsel_r2 <= iqsel_r1;
         iqsel_r3 <= iqsel_r2;
         iqsel_r4 <= iqsel_r3;
         iqsel_r5 <= iqsel_r4;
         iqsel_r6 <= iqsel_r5;
         iqsel_r7 <= iqsel_r6;

         // Steady-value pipeline.
         stdysel_r1 <= stdysel_int;
         stdysel_r2 <= stdysel_r1;
         stdysel_r3 <= stdysel_r2;
         stdysel_r4 <= stdysel_r3;
         stdysel_r5 <= stdysel_r4;
         stdysel_r6 <= stdysel_r5;
         stdysel_r7 <= stdysel_r6;

         // Load flag.
         load_r <= load_int;

         // FIFO read-enable pipeline.
         rd_en_r1 <= rd_en_int;
         rd_en_r2 <= rd_en_r1;

         // Sample counter.
         if (rd_en_int)
            cnt_nsamp_r <= i_fifo_dout[143:128];
         else
            cnt_nsamp_r <= cnt_nsamp_r - 1'b1;

         // Output enable register.
         // o_en drives o_axis_tvalid in sgv4; it must stay high for the whole
         // waveform and drop at its end. Updated only when a descriptor is being
         // read (READ_ST); held during CNT_ST.
         if (~mode_int && rd_en_int) begin
            if (~i_fifo_empty)
               en_reg <= 1'b1;
            else
               en_reg <= 1'b0;
         end
         // (mode_int==1 -> continuous: en_reg holds high once set)

         en_reg_r1 <= en_reg;
         en_reg_r2 <= en_reg_r1;
         en_reg_r3 <= en_reg_r2;
         en_reg_r4 <= en_reg_r3;
         en_reg_r5 <= en_reg_r4;
         en_reg_r6 <= en_reg_r5;
         en_reg_r7 <= en_reg_r6;
         en_reg_r8 <= en_reg_r7;
      end
   end

   // --------------------------------------------------------------------------
   // FSM combinational outputs.
   // --------------------------------------------------------------------------
   always_comb begin
      rd_en_int = 1'b0;
      case (state)
         READ_ST: rd_en_int = 1'b1;
         CNT_ST:  rd_en_int = 1'b0;
         default: rd_en_int = 1'b0;
      endcase
   end

   // --------------------------------------------------------------------------
   // FIFO descriptor field decode.
   // --------------------------------------------------------------------------
   assign pinc_int    = fifo_dout_r[31:0];
   assign phase_int   = fifo_dout_r[63:32];
   assign addr_int    = fifo_dout_r[79:64];
   assign gain_int    = fifo_dout_r[111:96];
   assign nsamp_int   = fifo_dout_r[143:128];
   assign outsel_int  = fifo_dout_r[145:144];
   assign mode_int    = fifo_dout_r[146];
   assign stdysel_int = fifo_dout_r[147];
   assign phrst_int   = fifo_dout_r[148];
   assign iqsel_int   = fifo_dout_r[149];   // v4 specific: I/Q selection

   // --------------------------------------------------------------------------
   // Frequency: per-cycle phase advance shared by all lanes.
   // --------------------------------------------------------------------------
   assign pinc_n = pinc_r2 * N_DDS;

   // --------------------------------------------------------------------------
   // Phase calculation: pinc * cnt_n (implicit mod 2^32).
   //
   // Split-multiplier implementation (low/high halves at WL=17),
   // which maps to DSP slices and meets timing.
   // --------------------------------------------------------------------------
   localparam int WL = 17;
   localparam int WH = 32 - WL;

   logic [WL:0] pinc_r2_lo_r,   cnt_n_reg_lo_r;
   logic [WH:0] pinc_r2_hi_r,   cnt_n_reg_hi_r;

   assign pinc_r2_lo_r   = $signed({1'b0, pinc_r2[WL-1:0]});
   assign pinc_r2_hi_r   = $signed({1'b0, pinc_r2[31:WL]});
   assign cnt_n_reg_lo_r = $signed({1'b0, cnt_n_reg[WL-1:0]});
   assign cnt_n_reg_hi_r = $signed({1'b0, cnt_n_reg[31:WL]});

   logic signed [2*(WL+1)-1:0] pinc_nm_dsp_p0_r1, pinc_nm_dsp_p0_r2;
   logic signed [2*(WH+1)-1:0] pinc_nm_dsp_p1_r1, pinc_nm_dsp_p1_r2;
   logic signed [2*(WH+1)-1:0] pinc_nm_dsp_p2_r1, pinc_nm_dsp_p2_r2;
   logic signed [31:0]         pinc_nm_dsp_r3;

   always_ff @(posedge i_clk) begin
      pinc_nm_dsp_p0_r1 <= pinc_r2_lo_r * cnt_n_reg_lo_r;        // WL x WL
      pinc_nm_dsp_p1_r1 <= pinc_r2_hi_r * cnt_n_reg_lo_r;        // WH x WL
      pinc_nm_dsp_p2_r1 <= pinc_r2_lo_r * cnt_n_reg_hi_r;        // WL x WH
      pinc_nm_dsp_p0_r2 <= pinc_nm_dsp_p0_r1;
      pinc_nm_dsp_p1_r2 <= pinc_nm_dsp_p1_r1 << WL;
      pinc_nm_dsp_p2_r2 <= pinc_nm_dsp_p2_r1 << WL;
      pinc_nm_dsp_r3    <= pinc_nm_dsp_p0_r2[31:0]
                         + pinc_nm_dsp_p1_r2
                         + pinc_nm_dsp_p2_r2;
   end

   assign phase_0 = pinc_nm_dsp_r3 + phase_r5;

   // --------------------------------------------------------------------------
   // Per-lane phase vectors and packed DDS control words.
   // --------------------------------------------------------------------------
   generate
      for (genvar i = 0; i < N_DDS; i = i + 1) begin : gen_phase
         always_ff @(posedge i_clk) begin
            if (~i_rstn) begin
               phase_v0_r1[i] <= '0;
               phase_v0_r2[i] <= '0;
               phase_v0_r3[i] <= '0;
               phase_v0_r4[i] <= '0;
               phase_v1_r1[i] <= '0;
            end
            else begin
               phase_v0_r1[i] <= phase_v0[i];
               phase_v0_r2[i] <= phase_v0_r1[i];
               phase_v0_r3[i] <= phase_v0_r2[i];
               phase_v0_r4[i] <= phase_v0_r3[i];
               phase_v1_r1[i] <= phase_v1[i];
            end
         end

         // Per-lane phase offset.
         assign phase_v0[i] = pinc_r2 * i;
         // Per-lane absolute phase.
         assign phase_v1[i] = phase_v0_r4[i] + phase_0_r1;
         // Packed DDS control word: {pad, sync, phase, pinc_n}.
         assign o_dds_ctrl[i*72 +: 72] =
            {7'h00, sync_reg_r7, phase_v1_r1[i], pinc_n_r5};
      end
   endgenerate

   // --------------------------------------------------------------------------
   // Load flag and outputs.
   // --------------------------------------------------------------------------
   assign load_int     = rd_en_int & ~i_fifo_empty;

   assign o_fifo_rd_en = rd_en_int;
   assign o_mem_addr   = addr_cnt_r6;
   assign o_gain       = gain_r7;
   assign o_src        = outsel_r7;
   assign o_stdy       = stdysel_r7;
   assign o_en         = en_reg_r8;
   assign o_iqsel      = iqsel_r7;    // v4 specific

endmodule
