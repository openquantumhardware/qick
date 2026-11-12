`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : matched_filter
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    matched_filter.sv
//!
//! @brief   Time-domain matched-filter complex multiplier for
//!          axis_weighted_buffer: multiplies the incoming I/Q stream by a
//!          DMA-loaded weight envelope, sample by sample.
//!
//! @details
//!
//! Port of legacy matched_filter.vhd (axis_weighted_buffer v1.3), with the
//! weight alignment and I/Q order corrected in v1.4 (see below).
//! Weight envelope is loaded via a separate AXI4-Stream (s_axis, write_clk
//! domain) into a dual-clock BRAM; din_i/dout_o run in the readout domain
//! (clk). Complex multiply: dout = din * envelope, i.e.
//!   dout_i = din_i*env_i - din_q*env_q   (ac - bd)
//!   dout_q = din_i*env_q + din_q*env_i   (ad + bc)
//! I/Q packing follows the rest of QICK for din_i, dout_o and the weight
//! words alike: I in the lower B bits, Q in the upper B bits.
//! Each partial product is a signed BxB multiply, truncated (not rounded,
//! no saturation) to B bits taken from an arithmetic right shift of the
//! 2B-bit product by trunc_shift_reg. Default trunc_shift_reg = B (tie to
//! `B` if unconnected) reproduces the legacy fixed shift exactly --
//! `filt_*_quant <= filt_*(2*B-1 downto B)`. A different shift trades gain
//! for headroom against a differently-scaled weight envelope; software
//! must reset trunc_shift_reg to B for bit-exact legacy behavior if it
//! ever changes it.
//!
//! Weight writer: reuses axis_to_bram_sg (same block already used by
//! axis_sg_int4_v2 to load its envelope table) in place of the legacy
//! data_writer.vhd instance -- both are faithful ports of the identical
//! FSM (INIT_ST -> READ_START_ADDR_ST -> WAIT_TVALID_ST -> RW_TDATA_ST),
//! confirmed by direct diff of the legacy sources. Envelope memory reuses
//! bram_tdp (1-cycle mandatory read latency per port, matching legacy
//! bram_dp.vhd) in place of bram_dp.vhd, single NB_DATA=2*B bank holding
//! packed I/Q (unlike sg_int4_top's split real/imag banks).
//!
//! Each of the 4 partial-product multiplies is a 3-cycle pipelined signed
//! multiply (mult_pipe3: input register -> product register -> output
//! register), inferred as a DSP48.
//!
//! Alignment: the k-th sample of the window (counted from the first
//! din_valid_i after trigger_i) is multiplied by weight k, with or without
//! gaps in din_valid_i, and dout_valid_o is high exactly in the cycles
//! dout_o holds a product. trigger_o keeps its position relative to the
//! valid samples, so avg_top/buffer_top capture sample 0 * weight 0 first.
//! See the "Latency alignment" block below for the bookkeeping.
//!
//! Differences from legacy v1.3, all fixed in v1.4 (found with a ramp of
//! weights; a constant envelope hides them):
//! - v1.3 delayed din_i by WGT_LATENCY=4 while the envelope path takes 2
//!   cycles, so sample k was multiplied by weight k+2 in the first port of
//!   this block, and by weight k+1 in the legacy IP (its dsp_macro_0
//!   takes 4 cycles, not the DSP_LATENCY=3 the VHDL assumed).
//! - v1.3 raised dout_valid_o one cycle before dout_o held the product
//!   (the output quantizer register was not counted), so avg_top/
//!   buffer_top latched a stale value as the first sample of every window.
//! - v1.3 read I from the upper bits, while the readout, avg_top and the
//!   driver put I in the lower bits, so the result was -1j*(din*weight).
//!
//! @author  QICK Development Team
//!
//! @version 1.0
module matched_filter #(
    //! envelope BRAM address width (depth = 2**N)
    parameter int N = 10,
    //! per-component (I or Q) data width in bits
    parameter int B = 16
) (
    //! readout datapath clock (din_i/dout_o domain)
    input  logic            clk,
    //! readout datapath reset -- NOT present in the legacy VHDL (which is
    //! reset-less in this clock domain, relying on FPGA power-up initial
    //! values only); added here to give the FSM/counters a clean, testable
    //! synchronous reset, matching this session's SV convention. Tie to the
    //! same s_axis_aresetn already used by the sibling avg_top/buffer_top
    //! in the composing weighted_buffer top level.
    input  logic            rstn,

    //! weight-write domain reset/clock
    input  logic            write_rstn,
    input  logic            write_clk,

    input  logic            trigger_i,
    output logic            trigger_o,

    //! AXI4-Stream weight-programming interface (write_clk domain)
    output logic            s_axis_tready,
    input  logic [2*B-1:0]  s_axis_tdata,
    input  logic            s_axis_tvalid,

    //! Readout data in/out (clk domain)
    input  logic            din_valid_i,
    input  logic [2*B-1:0]  din_i,
    output logic [2*B-1:0]  dout_o,
    output logic            dout_valid_o,

    //! Registers
    input  logic [31:0]     len_reg,
    input  logic [31:0]     dw_addr_reg,
    input  logic            we_reg,
    //! Output-quantizer right-shift amount (bits taken from the 2B-bit
    //! product starting at this bit position). Defaults to B, matching
    //! the legacy fixed truncation, if left unconnected.
    input  logic [7:0]      trunc_shift_reg = 8'(B)
);

    // -------------------------------------------------------------------------
    // Weight-envelope writer (write_clk domain) -- reuses axis_to_bram_sg.
    // -------------------------------------------------------------------------
    axi4_stream_if #(.TDATA_WIDTH(2*B)) axis_wr (
        .aclk    (write_clk),
        .aresetn (write_rstn)
    );

    bram_if #(.NB_DATA(2*B), .NB_ADDR(N)) bram_wr (
        .i_clk (write_clk),
        .i_rst (~write_rstn)
    );

    assign axis_wr.tdata  = s_axis_tdata;
    assign axis_wr.tvalid = s_axis_tvalid;
    assign s_axis_tready  = axis_wr.tready;
    assign axis_wr.tlast  = 1'b0;

    axis_to_bram_sg #(
        .N (N),
        .B (2*B)
    ) writer_i (
        .rstn           (write_rstn),
        .clk            (write_clk),
        .axis           (axis_wr.slave),
        .bram           (bram_wr.master),
        .start_addr_reg (dw_addr_reg),
        .capture_reg    (we_reg),
        .o_overflow     ()
    );

    // -------------------------------------------------------------------------
    // Envelope memory: dual-clock, packed I/Q (matches legacy bram_dp #(N,2*B)).
    // -------------------------------------------------------------------------
    logic [2*B-1:0] envelope_iq;
    logic [2*B-1:0] envelope_iq_r;
    logic [N-1:0]   mem_envelope_addrb;

    bram_tdp #(
        .NB_DATA (2*B),
        .NB_ADDR (N)
    ) bram_envelope_iq_i (
        .clka  (write_clk),
        .rsta  (~write_rstn),
        .ena   (1'b1),
        .wea   (bram_wr.we),
        .addra (bram_wr.addr),
        .dia   (bram_wr.din),
        .doa   (),

        .clkb  (clk),
        .rstb  (~rstn),
        .enb   (1'b1),
        .web   (1'b0),
        .addrb (mem_envelope_addrb),
        .dib   ('0),
        .dob   (envelope_iq)
    );

    // -------------------------------------------------------------------------
    // Read-address FSM (clk domain): waits for trigger, then advances the
    // envelope read pointer once per accepted input sample, and goes back to
    // waiting on the len_reg-th sample (len_reg = 0 counts as 1, as in avg),
    // so the next trigger starts again at weight 0. v1.3 left READ_ST only
    // after len_reg+1 samples and through INIT_ST, so a window of exactly
    // len_reg samples left the next window starting at weight len_reg.
    // -------------------------------------------------------------------------
    typedef enum logic [1:0] {
        INIT_ST = 2'd0,
        WAIT_ST = 2'd1,
        READ_ST = 2'd2
    } state_t;

    state_t        state;
    logic [31:0]   cnt;
    logic [31:0]   last_cnt;
    logic          last_sample;

    assign last_cnt           = (len_reg == '0) ? '0 : len_reg - 1'b1;
    assign last_sample        = (state == READ_ST) && din_valid_i && (cnt == last_cnt);
    assign mem_envelope_addrb = cnt[N-1:0];

    always_ff @(posedge clk) begin
        if (!rstn) begin
            state <= INIT_ST;
        end else begin
            unique case (state)
                INIT_ST: state <= WAIT_ST;
                WAIT_ST: if (trigger_i) state <= READ_ST;
                READ_ST: if (last_sample) state <= WAIT_ST;
                default: state <= INIT_ST;
            endcase
        end
    end

    always_ff @(posedge clk) begin
        if (!rstn) begin
            cnt <= '0;
        end else if (state == READ_ST && !last_sample) begin
            if (din_valid_i) cnt <= cnt + 1'b1;
        end else begin
            cnt <= '0;
        end
    end

    // -------------------------------------------------------------------------
    // Latency alignment.
    //
    // cnt counts accepted samples, so weight index k sits on
    // mem_envelope_addrb in the same cycle the k-th windowed sample is on
    // din_i, and reaches envelope_iq_r ENV_LATENCY cycles later (BRAM read +
    // output register). din_i is delayed by the same ENV_LATENCY, so sample k
    // and weight k enter the multipliers together whatever the gaps in
    // din_valid_i. The multipliers add DSP_LATENCY and the quantizer register
    // OUT_LATENCY; din_valid_i and trigger_i are delayed by the whole
    // TOTAL_LATENCY, so dout_valid_o marks the cycles dout_o is valid.
    // -------------------------------------------------------------------------
    localparam int ENV_LATENCY   = 2;  // bram_tdp read + envelope_iq_r
    localparam int DSP_LATENCY   = 3;  // mult_pipe3
    localparam int OUT_LATENCY   = 1;  // filt_*_quant_r
    localparam int TOTAL_LATENCY = ENV_LATENCY + DSP_LATENCY + OUT_LATENCY;

    logic [2*B-1:0] din_reg   [ENV_LATENCY];
    logic           trigger_reg    [TOTAL_LATENCY];
    logic           dout_valid_reg [TOTAL_LATENCY];

    always_ff @(posedge clk) begin
        if (!rstn) begin
            for (int i = 0; i < ENV_LATENCY; i++) din_reg[i] <= '0;
            for (int i = 0; i < TOTAL_LATENCY; i++) begin
                trigger_reg[i]    <= 1'b0;
                dout_valid_reg[i] <= 1'b0;
            end
        end else begin
            din_reg[0] <= din_i;
            for (int i = 1; i < ENV_LATENCY; i++)
                din_reg[i] <= din_reg[i-1];

            trigger_reg[0]    <= trigger_i;
            dout_valid_reg[0] <= din_valid_i;
            for (int i = 1; i < TOTAL_LATENCY; i++) begin
                trigger_reg[i]    <= trigger_reg[i-1];
                dout_valid_reg[i] <= dout_valid_reg[i-1];
            end
        end
    end

    // I in the lower B bits, Q in the upper B bits.
    logic signed [B-1:0] din_ii, din_qq;
    assign din_ii = din_reg[ENV_LATENCY-1][B-1:0];
    assign din_qq = din_reg[ENV_LATENCY-1][2*B-1:B];

    always_ff @(posedge clk) begin
        if (!rstn) envelope_iq_r <= '0;
        else       envelope_iq_r <= envelope_iq;
    end

    logic signed [B-1:0] envelope_ii, envelope_qq;
    assign envelope_ii = envelope_iq_r[B-1:0];
    assign envelope_qq = envelope_iq_r[2*B-1:B];

    // -------------------------------------------------------------------------
    // Complex multiply: 4 partial products, each a 3-cycle pipelined signed
    // multiply (DSP_LATENCY).
    // -------------------------------------------------------------------------
    logic signed [2*B-1:0] ac, bd, ad, bc;

    mult_pipe3 #(.B (B)) mult_ac_i (.clk (clk), .rstn (rstn), .a (din_ii), .b (envelope_ii), .p (ac));
    mult_pipe3 #(.B (B)) mult_bd_i (.clk (clk), .rstn (rstn), .a (din_qq), .b (envelope_qq), .p (bd));
    mult_pipe3 #(.B (B)) mult_ad_i (.clk (clk), .rstn (rstn), .a (din_ii), .b (envelope_qq), .p (ad));
    mult_pipe3 #(.B (B)) mult_bc_i (.clk (clk), .rstn (rstn), .a (din_qq), .b (envelope_ii), .p (bc));

    logic signed [2*B-1:0] filt_ii, filt_qq;
    assign filt_ii = ac - bd;
    assign filt_qq = ad + bc;

    // Configurable truncation (no rounding, no saturation): arithmetic
    // right-shift by trunc_shift_reg, keep the low B bits. Shift = B (the
    // default) is bit-exact with the old fixed filt_*[2*B-1:B] slice.
    logic signed [2*B-1:0] filt_ii_shifted, filt_qq_shifted;
    assign filt_ii_shifted = filt_ii >>> trunc_shift_reg;
    assign filt_qq_shifted = filt_qq >>> trunc_shift_reg;

    logic signed [B-1:0] filt_ii_quant, filt_qq_quant;
    assign filt_ii_quant = filt_ii_shifted[B-1:0];
    assign filt_qq_quant = filt_qq_shifted[B-1:0];

    logic signed [B-1:0] filt_ii_quant_r, filt_qq_quant_r;
    always_ff @(posedge clk) begin
        if (!rstn) begin
            filt_ii_quant_r <= '0;
            filt_qq_quant_r <= '0;
        end else begin
            filt_ii_quant_r <= filt_ii_quant;
            filt_qq_quant_r <= filt_qq_quant;
        end
    end

    assign dout_o       = {filt_qq_quant_r, filt_ii_quant_r};
    assign dout_valid_o = dout_valid_reg[TOTAL_LATENCY-1];
    assign trigger_o    = trigger_reg[TOTAL_LATENCY-1];

endmodule
