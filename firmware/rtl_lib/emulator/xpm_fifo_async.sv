///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : xpm_fifo_async
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    xpm_fifo_async.sv
//!
//! @brief   Behavioural model of the Xilinx XPM macro xpm_fifo_async (two clocks, first-word fall-through), for the Verilator emulator.
//!
//! @details
//! Same module name, parameters and ports as the macro, so that the cores that instantiate it
//! (qick:mem:fifo_async) elaborate unchanged in Verilator, which cannot read the XPM sources. It is
//! compiled only by the emulator targets; xsim keeps using the real macro (-L xpm).
//!
//! It follows the structure of the macro so that it shows the same latencies for any relation of the
//! two clocks (checked clock by clock against the macro in xsim, see tests/vendor):
//! - Each pointer crosses to the other clock through a register on its own clock, CDC_SYNC_STAGES
//!   flops on the other one and a last register there. The RAM level flags are registered from the
//!   crossed pointers: `ram_full` (write side) and `ram_empty` (read side).
//! - A two-stage first-word-fall-through output (invalid / stage 1 / stage 2 / both) takes words from the
//!   RAM two clocks ahead of the user, which is what makes `empty`, `data_valid` and `dout` behave
//!   as FWFT; the user capacity is FIFO_WRITE_DEPTH + 1 words.
//! - The reset is a handshake between the two clocks: `wr_rst_busy` and `rd_rst_busy` stay high for
//!   tens of clocks and every write or read during them is dropped and flagged as overflow/underflow.
//!   The FIFO also runs this sequence once after power-up.
//! Only READ_MODE "fwft", RELATED_CLOCKS 0, power-of-two depths, no ECC, FULL_RESET_VALUE 0 and
//! DOUT_RESET_VALUE "0" are implemented and everything else is rejected at elaboration.
//! `prog_full`, `prog_empty`, `wr_data_count`, `rd_data_count`, `almost_full`, `almost_empty` and
//! `wr_ack` are NOT modelled and are driven low (no QICK core connects them).
//!
//! The pointers cross as binary values: in simulation the Gray coding of the macro is lossless, so
//! it changes nothing, but two clock edges at the very same instant are resolved as the simulator
//! orders them.
//!
//! @author  QICK Development Team
//!
//! @version 1.0
// The model keeps the full interface of the macro; the parameters and pins it does not model are unused.
/* verilator lint_off UNUSEDPARAM */
/* verilator lint_off UNUSEDSIGNAL */
// Power-up values are declared with the variables, as the macro does, and driven later by the clocked blocks.
/* verilator lint_off PROCASSINIT */
module xpm_fifo_async #(
  // Common module parameters
  parameter         FIFO_MEMORY_TYPE    = "auto",
  parameter         ECC_MODE            = "no_ecc",
  parameter integer RELATED_CLOCKS      = 0,
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
  parameter integer CDC_SYNC_STAGES     = 2,
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
  input  wire                           rd_clk,
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

  localparam int W  = WRITE_DATA_WIDTH;
  localparam int PW = $clog2(FIFO_WRITE_DEPTH);          // pointer bits
  localparam int DEPTH = 1 << PW;
  localparam int SS = CDC_SYNC_STAGES;

  // The macro parameters are untyped; copy the strings to typed ones to compare them.
  localparam string S_READ_MODE = READ_MODE;
  localparam string S_ECC_MODE  = ECC_MODE;
  localparam string S_DOUT_RST  = DOUT_RESET_VALUE;
  localparam string S_ADV       = USE_ADV_FEATURES;

  // USE_ADV_FEATURES is a hex string ("1707"): bit 0 overflow, 8 underflow, 12 data_valid are modelled.
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

  if (S_READ_MODE != "fwft") begin : gen_chk_mode
    $fatal(1, "xpm_fifo_async model: only READ_MODE fwft is modelled");
  end
  if (RELATED_CLOCKS != 0) begin : gen_chk_related
    $fatal(1, "xpm_fifo_async model: RELATED_CLOCKS must be 0");
  end
  if (READ_DATA_WIDTH != WRITE_DATA_WIDTH) begin : gen_chk_width
    $fatal(1, "xpm_fifo_async model: read and write widths must be equal");
  end
  if (DEPTH != FIFO_WRITE_DEPTH || FIFO_WRITE_DEPTH < 16) begin : gen_chk_depth
    $fatal(1, "xpm_fifo_async model: FIFO_WRITE_DEPTH must be a power of two, 16 or more");
  end
  if (S_ECC_MODE != "no_ecc" && S_ECC_MODE != "NO_ECC") begin : gen_chk_ecc
    $fatal(1, "xpm_fifo_async model: ECC is not modelled");
  end
  if (FULL_RESET_VALUE != 0) begin : gen_chk_full_rst
    $fatal(1, "xpm_fifo_async model: only FULL_RESET_VALUE 0 is modelled");
  end
  if (S_DOUT_RST != "0") begin : gen_chk_dout
    $fatal(1, "xpm_fifo_async model: only DOUT_RESET_VALUE \"0\" is modelled");
  end
  if (SS < 2 || SS > 8) begin : gen_chk_sync
    $fatal(1, "xpm_fifo_async model: CDC_SYNC_STAGES must be 2 to 8");
  end

  // ===========================================================================
  // Reset sequence (a handshake between the two clocks)
  // ===========================================================================
  // Write side: power-on reset, then the state machine IDLE -> IN -> OUT -> EXIT (-> GO2IDLE).
  localparam logic [2:0] WRST_IDLE = 3'b000, WRST_IN = 3'b010, WRST_OUT = 3'b111, WRST_EXIT = 3'b110,
                         WRST_GO2IDLE = 3'b100;
  localparam logic [1:0] RRST_IDLE = 2'b00,  RRST_IN = 2'b10,  RRST_OUT = 2'b11,  RRST_EXIT = 2'b01;

  logic [1:0]   power_on_rst = 2'b11;
  logic [2:0]   wrst_state = WRST_IDLE;
  logic [1:0]   rrst_state = RRST_IDLE;
  logic         rst_seq_reentered = 1'b0;
  logic         wr_rst_ic = 1'b0;          // registered reset request to the read side
  logic         wr_busy_ic = 1'b0;         // wr_rst_busy of the sequence
  logic         rd_rst_ic = 1'b0;          // read-domain reset, also rd_rst_busy
  logic [SS-1:0] wrst_to_rd = '0;          // wr_rst_ic crossing to rd_clk
  logic [SS-1:0] rrst_to_wr = '0;          // rd_rst_ic crossing to wr_clk
  logic         rst_d1 = 1'b0;

  wire rst_i         = power_on_rst[1] | rst;
  wire wr_rst_in_rd  = wrst_to_rd[SS-1];
  wire rd_rst_in_wr  = rrst_to_wr[SS-1];
  wire wrst_busy     = wr_busy_ic;
  wire rd_rst_i      = rd_rst_ic;

  logic [2:0] wrst_next;
  logic       wr_rst_nxt, wr_busy_nxt;
  always_comb begin
    wrst_next = wrst_state;
    case (wrst_state)
      WRST_IDLE:    wrst_next = rst_i ? WRST_IN : WRST_IDLE;
      WRST_IN:      wrst_next = rst_i ? WRST_IN : rd_rst_in_wr ? WRST_OUT : WRST_IN;
      WRST_OUT:     wrst_next = rst_i ? WRST_IN : !rd_rst_in_wr ? WRST_EXIT : WRST_OUT;
      WRST_EXIT:    wrst_next = rst_i ? WRST_IN : (!rst && !rst_seq_reentered) ? WRST_GO2IDLE :
                                rst_seq_reentered ? WRST_IDLE : WRST_EXIT;
      WRST_GO2IDLE: wrst_next = WRST_IN;
      default:      wrst_next = WRST_IDLE;
    endcase
    case (wrst_state)
      WRST_IDLE:    wr_rst_nxt = rst_i;
      WRST_IN:      wr_rst_nxt = 1'b1;
      WRST_OUT:     wr_rst_nxt = 1'b0;
      WRST_EXIT:    wr_rst_nxt = 1'b0;
      WRST_GO2IDLE: wr_rst_nxt = 1'b1;
      default:      wr_rst_nxt = wr_rst_ic;
    endcase
    case (wrst_state)
      WRST_IDLE:    wr_busy_nxt = rst_i;
      WRST_IN, WRST_OUT, WRST_EXIT: wr_busy_nxt = 1'b1;
      default:      wr_busy_nxt = wr_busy_ic;
    endcase
  end

  logic [1:0] rrst_next;
  logic       rd_rst_nxt;
  always_comb begin
    case (rrst_state)
      RRST_IDLE: rrst_next = wr_rst_in_rd ? RRST_IN : RRST_IDLE;
      RRST_IN:   rrst_next = RRST_OUT;
      RRST_OUT:  rrst_next = !wr_rst_in_rd ? RRST_EXIT : RRST_OUT;
      RRST_EXIT: rrst_next = RRST_IDLE;
      default:   rrst_next = RRST_IDLE;
    endcase
    case (rrst_state)
      RRST_IDLE: rd_rst_nxt = wr_rst_in_rd;
      RRST_IN:   rd_rst_nxt = 1'b1;
      RRST_OUT:  rd_rst_nxt = 1'b1;
      default:   rd_rst_nxt = 1'b0;
    endcase
  end

  always @(posedge wr_clk) begin : wr_reset
    power_on_rst <= {power_on_rst[0], 1'b0};
    if (rst_i) rst_seq_reentered <= 1'b0;
    else if (wrst_state == WRST_GO2IDLE) rst_seq_reentered <= 1'b1;
    wrst_state <= wrst_next;
    wr_rst_ic  <= wr_rst_nxt;
    wr_busy_ic <= wr_busy_nxt;
    rrst_to_wr <= {rrst_to_wr[SS-2:0], rd_rst_ic};
    rst_d1     <= wrst_busy;
  end

  always @(posedge rd_clk) begin : rd_reset
    rrst_state <= rrst_next;
    rd_rst_ic  <= rd_rst_nxt;
    wrst_to_rd <= {wrst_to_rd[SS-2:0], wr_rst_ic};
  end

  // ===========================================================================
  // Write side
  // ===========================================================================
  logic [W-1:0]  mem [DEPTH];
  logic [PW:0]   wptr_ext = '0;            // write pointer, one extra bit
  logic [PW-1:0] wptr_p1  = PW'(1);        // wptr + 1
  logic [PW-1:0] wptr_p2  = PW'(2);        // wptr + 2
  logic          full_q = 1'b0, ovf_q = 1'b0;
  logic [PW-1:0] wptr_src = '0;                      // write pointer registered for the crossing
  logic [PW-1:0] rptr_src = '0;                      // read pointer registered for the crossing
  logic [PW-1:0] rptr_cross [SS];                    // read pointer crossing to wr_clk (SS flops)
  logic [PW-1:0] rptr_in_wr = '0;                    // ... and the register after them

  wire [PW-1:0] wptr = wptr_ext[PW-1:0];
  wire ram_wr_en = wr_en & ~full_q & ~(wrst_busy | rst_d1);

  always @(posedge wr_clk) begin : wr_side
    if (ram_wr_en) mem[wptr] <= din;
    if (wrst_busy) begin
      wptr_ext <= '0; wptr_p1 <= PW'(1); wptr_p2 <= PW'(2);
    end else if (ram_wr_en) begin
      wptr_ext <= wptr_ext + 1'b1; wptr_p1 <= wptr_p1 + 1'b1; wptr_p2 <= wptr_p2 + 1'b1;
    end
    // read pointer crossing
    rptr_cross[0] <= rptr_src;
    for (int i = 1; i < SS; i++) rptr_cross[i] <= rptr_cross[i-1];
    rptr_in_wr <= wrst_busy ? '0 : rptr_cross[SS-1];
    wptr_src <= wptr;
    // flags
    full_q <= wrst_busy ? 1'b0 :
              ((rptr_in_wr == wptr_p1) | ((rptr_in_wr == wptr_p2) & ram_wr_en));
    ovf_q  <= (wrst_busy | rst_d1 | full_q) & wr_en;
  end

  // ===========================================================================
  // Read side
  // ===========================================================================
  logic [PW:0]   rptr_ext = '0;            // read pointer (words taken from the RAM), one extra bit
  logic [PW-1:0] rptr_p1  = PW'(1);
  logic [PW-1:0] wptr_cross [SS];
  logic [PW-1:0] wptr_in_rd = '0;
  logic          ram_empty_q = 1'b1;
  logic [1:0]    fwft_state = 2'b00;       // 0 invalid, 2 stage 1, 1 stage 2, 3 both
  logic          empty_q = 1'b1, empty_fb = 1'b1, dv_q = 1'b0, unf_q = 1'b0;
  logic [W-1:0]  rd_s1 = '0, rd_s2 = '0;   // RAM read stage and output register

  wire [PW-1:0] rptr = rptr_ext[PW-1:0];

  logic [1:0] fwft_next;
  logic       rd_en_ram, regce, going_empty, leaving_empty;
  always_comb begin
    case (fwft_state)
      2'b00: fwft_next = ram_empty_q ? 2'b00 : 2'b10;
      2'b10: fwft_next = ram_empty_q ? 2'b01 : 2'b11;
      2'b01: fwft_next = (ram_empty_q && rd_en) ? 2'b00 : (!ram_empty_q && rd_en) ? 2'b10 :
                         (!ram_empty_q && !rd_en) ? 2'b11 : 2'b01;
      default: fwft_next = (ram_empty_q && rd_en) ? 2'b01 : 2'b11;
    endcase
    rd_en_ram = (fwft_state == 2'b11) ? (!ram_empty_q && rd_en) : !ram_empty_q;
    regce = (fwft_state == 2'b10) ? 1'b1 : (fwft_state == 2'b11) ? rd_en : 1'b0;
    going_empty   = (fwft_state == 2'b01) && rd_en;
    leaving_empty = (fwft_state == 2'b10);
  end
  wire ram_rd_en = rd_en_ram & ~ram_empty_q;
  wire empty_nxt = going_empty | (~leaving_empty & empty_fb);

  always @(posedge rd_clk) begin : rd_side
    // write pointer crossing
    wptr_cross[0] <= wptr_src;
    for (int i = 1; i < SS; i++) wptr_cross[i] <= wptr_cross[i-1];
    wptr_in_rd <= rd_rst_i ? '0 : wptr_cross[SS-1];
    rptr_src <= rptr;
    // read pointer
    if (rd_rst_i) begin
      rptr_ext <= '0; rptr_p1 <= PW'(1);
    end else if (ram_rd_en) begin
      rptr_ext <= rptr_ext + 1'b1; rptr_p1 <= rptr_p1 + 1'b1;
    end
    // RAM-level empty and the FWFT output
    ram_empty_q <= rd_rst_i ? 1'b1 : (((wptr_in_rd == rptr_p1) & ram_rd_en) | (wptr_in_rd == rptr));
    fwft_state  <= rd_rst_i ? 2'b00 : fwft_next;
    empty_q     <= rd_rst_i ? 1'b1 : empty_nxt;
    empty_fb    <= rd_rst_i ? 1'b1 : empty_nxt;
    dv_q        <= rd_rst_i ? 1'b0 : ~empty_nxt;
    unf_q       <= (rd_rst_i | empty_q) & rd_en;
    // data: RAM read stage and output register
    if (ram_rd_en) rd_s1 <= mem[rptr];
    if (rd_rst_i)    rd_s2 <= '0;
    else if (regce)  rd_s2 <= rd_s1;
  end

  // The crossing registers start at zero, as the macro's do.
  initial begin
    for (int i = 0; i < SS; i++) begin rptr_cross[i] = '0; wptr_cross[i] = '0; end
  end

  assign full          = full_q;
  assign overflow      = ovf_q & ADV[0];
  assign wr_rst_busy   = wrst_busy | rst_d1;
  assign empty         = empty_q;
  assign dout          = rd_s2;
  assign underflow     = unf_q & ADV[8];
  assign rd_rst_busy   = rd_rst_ic;
  assign data_valid    = dv_q & ADV[12];
  assign prog_full     = 1'b0;
  assign prog_empty    = 1'b0;
  assign wr_data_count = '0;
  assign rd_data_count = '0;
  assign almost_full   = 1'b0;
  assign almost_empty  = 1'b0;
  assign wr_ack        = 1'b0;
  assign sbiterr       = 1'b0;
  assign dbiterr       = 1'b0;

endmodule
/* verilator lint_on PROCASSINIT */
/* verilator lint_on UNUSEDSIGNAL */
/* verilator lint_on UNUSEDPARAM */
