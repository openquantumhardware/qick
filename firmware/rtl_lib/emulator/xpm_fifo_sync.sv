///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : xpm_fifo_sync
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    xpm_fifo_sync.sv
//!
//! @brief   Behavioural model of the Xilinx XPM macro xpm_fifo_sync (first-word fall-through), for the Verilator emulator.
//!
//! @details
//! Same module name, parameters and ports as the macro, so that the cores that instantiate it
//! (qick:mem:fifo_sync) elaborate unchanged in Verilator, which cannot read the XPM sources. It is
//! compiled only by the emulator targets; xsim keeps using the real macro (-L xpm).
//!
//! Timing (from the macro, checked clock by clock against it in xsim, see tests/vendor):
//! - Capacity is FIFO_WRITE_DEPTH + 2 words. `full` is registered: it rises on the clock after the
//!   write that fills the FIFO. A write with `full` high is dropped and flagged in `overflow`.
//! - A word written on clock E reaches the read side on clock E + 2: `empty` falls after that clock,
//!   `dout` shows the head word, `data_valid` follows `empty`. `dout` moves to the next word on the
//!   clock of the read and holds the last word read when the FIFO drains. `empty` rises right after
//!   the read of the last word. A read with `empty` high is flagged in `underflow`.
//! - `wr_data_count` / `rd_data_count` show the occupancy one clock late; `rd_data_count` stays 0
//!   while the first word of a fill is still on its way. `prog_full` is occupancy >= PROG_FULL_THRESH,
//!   `prog_empty` is rd_data_count <= PROG_EMPTY_THRESH.
//! - `rst`: it takes effect on the clock after it is sampled (the state is cleared and `dout` goes to
//!   0), `wr_rst_busy`/`rd_rst_busy` rise right after the first reset clock and fall 4 clocks after the
//!   last one; after power-up they stay high for 6 clocks. Writes and reads while busy are dropped
//!   and flagged as overflow/underflow.
//! Only READ_MODE "fwft" with FIFO_READ_LATENCY 0, equal read and write widths, no ECC and
//! DOUT_RESET_VALUE "0" are implemented and everything else is rejected at elaboration;
//! `almost_full`, `almost_empty` and `wr_ack` are driven low.
//!
//! @author  QICK Development Team
//!
//! @version 1.0
// The model keeps the full interface of the macro; the parameters and pins it does not model are unused.
/* verilator lint_off UNUSEDPARAM */
/* verilator lint_off UNUSEDSIGNAL */
module xpm_fifo_sync #(
  // Common module parameters
  parameter         FIFO_MEMORY_TYPE    = "auto",
  parameter         ECC_MODE            = "no_ecc",
  parameter integer SIM_ASSERT_CHK      = 0,
  parameter         EN_SIM_ASSERT_ERR   = "warning",
  parameter integer CASCADE_HEIGHT      = 0,

  parameter integer FIFO_WRITE_DEPTH    = 2048,
  parameter integer WRITE_DATA_WIDTH    = 32,
  parameter integer WR_DATA_COUNT_WIDTH = 1,
  parameter integer PROG_FULL_THRESH    = 10,
  parameter integer FULL_RESET_VALUE    = 0,
  parameter         USE_ADV_FEATURES    = "0707",

  parameter         READ_MODE           = "std",
  parameter integer FIFO_READ_LATENCY   = 1,
  parameter integer READ_DATA_WIDTH     = WRITE_DATA_WIDTH,
  parameter integer RD_DATA_COUNT_WIDTH = 1,
  parameter integer PROG_EMPTY_THRESH   = 10,
  parameter         DOUT_RESET_VALUE    = "0",

  parameter integer WAKEUP_TIME         = 0
) (
  // Common module ports
  input  wire                           sleep,
  input  wire                           rst,

  // Write Domain ports
  input  wire                           wr_clk,
  input  wire                           wr_en,
  input  wire [WRITE_DATA_WIDTH-1:0]    din,
  output wire                           full,
  output wire                           prog_full,
  output wire [WR_DATA_COUNT_WIDTH-1:0] wr_data_count,
  output wire                           overflow,
  output wire                           wr_rst_busy,
  output wire                           almost_full,
  output wire                           wr_ack,

  // Read Domain ports
  input  wire                           rd_en,
  output wire [READ_DATA_WIDTH-1:0]     dout,
  output wire                           empty,
  output wire                           prog_empty,
  output wire [RD_DATA_COUNT_WIDTH-1:0] rd_data_count,
  output wire                           underflow,
  output wire                           rd_rst_busy,
  output wire                           almost_empty,
  output wire                           data_valid,

  // ECC Related ports
  input  wire                           injectsbiterr,
  input  wire                           injectdbiterr,
  output wire                           sbiterr,
  output wire                           dbiterr
);

  localparam int W   = WRITE_DATA_WIDTH;
  localparam int CAP = FIFO_WRITE_DEPTH + 2;   // words held before `full`
  localparam int M   = CAP + 2;                // storage ring

  // The macro parameters are untyped; copy the strings to typed ones to compare them.
  localparam string S_READ_MODE = READ_MODE;
  localparam string S_ECC_MODE  = ECC_MODE;
  localparam string S_DOUT_RST  = DOUT_RESET_VALUE;
  localparam string S_ADV       = USE_ADV_FEATURES;

  // USE_ADV_FEATURES is a hex string ("1707"): bit 0 overflow, 1 prog_full, 2 wr_data_count,
  // 8 underflow, 9 prog_empty, 10 rd_data_count, 12 data_valid.
  function automatic int hex2int(input string s);
    int v = 0;
    for (int i = 0; i < s.len(); i++) begin
      byte c = s[i];
      v = v * 16 + ((c >= "0" && c <= "9") ? int'(c) - int'("0") :
                    (c >= "a" && c <= "f") ? int'(c) - int'("a") + 10 : int'(c) - int'("A") + 10);
    end
    return v;
  endfunction
  localparam int ADV = hex2int(S_ADV);

  if (S_READ_MODE != "fwft" || FIFO_READ_LATENCY != 0) begin : gen_chk_mode
    $fatal(1, "xpm_fifo_sync model: only READ_MODE fwft with FIFO_READ_LATENCY 0 is modelled");
  end
  if (READ_DATA_WIDTH != WRITE_DATA_WIDTH) begin : gen_chk_width
    $fatal(1, "xpm_fifo_sync model: read and write widths must be equal");
  end
  if (S_ECC_MODE != "no_ecc" && S_ECC_MODE != "NO_ECC") begin : gen_chk_ecc
    $fatal(1, "xpm_fifo_sync model: ECC is not modelled");
  end
  if (S_DOUT_RST != "0") begin : gen_chk_dout
    $fatal(1, "xpm_fifo_sync model: only DOUT_RESET_VALUE \"0\" is modelled");
  end

  logic [W-1:0] ring [M];
  int           wptr, rptr;            // words accepted / words read
  int           occ;                   // accepted - read
  int           avail;                 // words that reached the read side and were not read
  int           wp1, wp2;              // words (0/1) on their way to the read side
  logic         full_q, empty_q, busy_q, rst_d1;
  int           busy_cnt;
  logic [W-1:0] dout_q;
  logic         ovf_q, unf_q, dv_q, pf_q, pe_q;
  logic [31:0]  wdc_q, rdc_q;

  initial begin
    wptr = 0; rptr = 0; occ = 0; avail = 0; wp1 = 0; wp2 = 0;
    full_q = 1'b0; empty_q = 1'b1; busy_q = 1'b1; busy_cnt = -2; rst_d1 = 1'b0;
    dout_q = '0; ovf_q = 1'b0; unf_q = 1'b0; dv_q = 1'b0; pf_q = 1'b0; pe_q = 1'b1;
    wdc_q = '0; rdc_q = '0;
  end

  always @(posedge wr_clk) begin : fifo
    int occ_old, wr_ok, rd_ok, occ_new, avail_new, rptr_new;
    logic empty_new;

    rst_d1 <= rst;

    // busy flags
    if (rst) begin
      busy_q   <= 1'b1;
      busy_cnt <= 0;
    end else if (busy_q) begin
      if (busy_cnt == 3) busy_q <= 1'b0;
      busy_cnt <= busy_cnt + 1;
    end

    ovf_q <= wr_en && (full_q || busy_q);
    unf_q <= rd_en && (empty_q || busy_q);

    if (rst_d1) begin
      wptr <= 0; rptr <= 0; occ <= 0; avail <= 0; wp1 <= 0; wp2 <= 0;
      full_q <= 1'b0; empty_q <= 1'b1; dout_q <= '0; dv_q <= 1'b0;
      wdc_q <= '0; rdc_q <= '0; pf_q <= 1'b0; pe_q <= 1'b1;
    end else begin
      occ_old = occ;
      wr_ok   = (wr_en && !full_q && !busy_q) ? 1 : 0;
      rd_ok   = (rd_en && !empty_q && !busy_q) ? 1 : 0;
      if (wr_ok != 0) ring[wptr % M] <= din;
      occ_new   = occ + wr_ok - rd_ok;
      avail_new = avail + wp2 - rd_ok;
      rptr_new  = rptr + rd_ok;
      empty_new = (avail_new == 0);

      wptr   <= wptr + wr_ok;
      rptr   <= rptr_new;
      occ    <= occ_new;
      avail  <= avail_new;
      wp2    <= wp1;
      wp1    <= wr_ok;
      full_q <= (occ_new >= CAP);
      empty_q <= empty_new;
      dv_q   <= !empty_new;
      if (!empty_new) dout_q <= ring[rptr_new % M];
      wdc_q  <= 32'(occ_old);
      rdc_q  <= (empty_q && empty_new) ? 32'd0 : 32'(occ_old);
      pf_q   <= (occ_old >= PROG_FULL_THRESH);
      pe_q   <= (((empty_q && empty_new) ? 0 : occ_old) <= PROG_EMPTY_THRESH);
    end
  end

  assign full          = full_q;
  assign empty         = empty_q;
  assign dout          = dout_q;
  assign wr_rst_busy   = busy_q;
  assign rd_rst_busy   = busy_q;
  assign overflow      = ovf_q & ADV[0];
  assign underflow     = unf_q & ADV[8];
  assign data_valid    = dv_q & ADV[12];
  assign prog_full     = pf_q & ADV[1];
  assign prog_empty    = pe_q & ADV[9];
  assign wr_data_count = ADV[2]  ? WR_DATA_COUNT_WIDTH'(wdc_q) : '0;
  assign rd_data_count = ADV[10] ? RD_DATA_COUNT_WIDTH'(rdc_q) : '0;
  assign almost_full   = 1'b0;
  assign almost_empty  = 1'b0;
  assign wr_ack        = 1'b0;
  assign sbiterr       = 1'b0;
  assign dbiterr       = 1'b0;

endmodule
/* verilator lint_on UNUSEDSIGNAL */
/* verilator lint_on UNUSEDPARAM */
