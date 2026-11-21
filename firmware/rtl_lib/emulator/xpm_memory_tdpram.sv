///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : xpm_memory_tdpram
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    xpm_memory_tdpram.sv
//!
//! @brief   Behavioural model of the Xilinx XPM macro xpm_memory_tdpram, for the Verilator emulator.
//!
//! @details
//! Same module name, parameters and ports as the macro, so that the cores that instantiate it
//! (qick:mem:bram_tdp) elaborate unchanged in Verilator, which cannot read the XPM sources. It is
//! compiled only by the emulator targets; xsim keeps using the real macro (-L xpm).
//!
//! Implemented (everything the QICK cores use, checked cycle by cycle against the macro in xsim,
//! see tests/vendor):
//! - Two ports, each with its own clock, enable, synchronous reset, byte-write enables
//!   (WRITE_DATA_WIDTH / BYTE_WRITE_WIDTH columns) and the three write modes (write_first,
//!   read_first, no_change).
//! - READ_LATENCY 1 (the reset has priority over the enable on the read register) and 2 (the reset
//!   and regce act on the second stage, the first one follows the enable).
//! - MEMORY_INIT_FILE (read with $readmemh) or zeros.
//! Not implemented, rejected at elaboration: asynchronous reset, ECC, READ_LATENCY > 2, a read width
//! different from the write width, READ_RESET_VALUE other than "0", the sleep pins (ignored).
//!
//! Two ports accessing the same address at the same instant is undefined in the macro and here.
//! Initial content is zeros when there is no init file; the macro leaves it undefined in some
//! configurations (this model is 2-state).
//!
//! @author  QICK Development Team
//!
//! @version 1.0
// The model keeps the full interface of the macro; the parameters and pins it does not model are unused,
// and the memory array is written from two clocks, as in the macro.
/* verilator lint_off UNUSEDPARAM */
/* verilator lint_off UNUSEDSIGNAL */
/* verilator lint_off MULTIDRIVEN */
module xpm_memory_tdpram #(
  // Common module parameters
  parameter integer MEMORY_SIZE             = 2048,
  parameter         MEMORY_PRIMITIVE        = "auto",
  parameter         CLOCKING_MODE           = "common_clock",
  parameter         ECC_MODE                = "no_ecc",
  parameter         ECC_TYPE                = "NONE",
  parameter         ECC_BIT_RANGE           = "[7:0]",
  parameter         MEMORY_INIT_FILE        = "none",
  parameter         MEMORY_INIT_PARAM       = "",
  parameter integer USE_MEM_INIT            = 1,
  parameter integer USE_MEM_INIT_MMI        = 0,
  parameter         WAKEUP_TIME             = "disable_sleep",
  parameter integer AUTO_SLEEP_TIME         = 0,
  parameter integer MESSAGE_CONTROL         = 0,
  parameter integer USE_EMBEDDED_CONSTRAINT = 0,
  parameter         MEMORY_OPTIMIZATION     = "true",
  parameter integer CASCADE_HEIGHT          = 0,
  parameter         RAM_DECOMP              = "auto",
  parameter integer SIM_ASSERT_CHK          = 0,
  parameter integer WRITE_PROTECT           = 1,
  parameter integer IGNORE_INIT_SYNTH       = 0,

  // Port A module parameters
  parameter integer WRITE_DATA_WIDTH_A = 32,
  parameter integer READ_DATA_WIDTH_A  = WRITE_DATA_WIDTH_A,
  parameter integer BYTE_WRITE_WIDTH_A = WRITE_DATA_WIDTH_A,
  parameter integer ADDR_WIDTH_A       = $clog2(MEMORY_SIZE / WRITE_DATA_WIDTH_A),
  parameter         READ_RESET_VALUE_A = "0",
  parameter integer READ_LATENCY_A     = 2,
  parameter         WRITE_MODE_A       = "no_change",
  parameter         RST_MODE_A         = "SYNC",

  // Port B module parameters
  parameter integer WRITE_DATA_WIDTH_B = WRITE_DATA_WIDTH_A,
  parameter integer READ_DATA_WIDTH_B  = WRITE_DATA_WIDTH_B,
  parameter integer BYTE_WRITE_WIDTH_B = WRITE_DATA_WIDTH_B,
  parameter integer ADDR_WIDTH_B       = $clog2(MEMORY_SIZE / WRITE_DATA_WIDTH_B),
  parameter         READ_RESET_VALUE_B = "0",
  parameter integer READ_LATENCY_B     = READ_LATENCY_A,
  parameter         WRITE_MODE_B       = "no_change",
  parameter         RST_MODE_B         = "SYNC"
) (
  // Common module ports
  input  wire                                                sleep,  // verilog_lint: waive unused (not modelled)

  // Port A module ports
  input  wire                                                clka,
  input  wire                                                rsta,
  input  wire                                                ena,
  input  wire                                                regcea,
  input  wire [(WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A)-1:0] wea,
  input  wire [ADDR_WIDTH_A-1:0]                             addra,
  input  wire [WRITE_DATA_WIDTH_A-1:0]                       dina,
  input  wire                                                injectsbiterra,  // verilog_lint: waive unused (no ECC)
  input  wire                                                injectdbiterra,  // verilog_lint: waive unused (no ECC)
  output wire [READ_DATA_WIDTH_A-1:0]                        douta,
  output wire                                                sbiterra,
  output wire                                                dbiterra,

  // Port B module ports
  input  wire                                                clkb,
  input  wire                                                rstb,
  input  wire                                                enb,
  input  wire                                                regceb,
  input  wire [(WRITE_DATA_WIDTH_B/BYTE_WRITE_WIDTH_B)-1:0] web,
  input  wire [ADDR_WIDTH_B-1:0]                             addrb,
  input  wire [WRITE_DATA_WIDTH_B-1:0]                       dinb,
  input  wire                                                injectsbiterrb,  // verilog_lint: waive unused (no ECC)
  input  wire                                                injectdbiterrb,  // verilog_lint: waive unused (no ECC)
  output wire [READ_DATA_WIDTH_B-1:0]                        doutb,
  output wire                                                sbiterrb,
  output wire                                                dbiterrb
);

  localparam int W     = WRITE_DATA_WIDTH_A;
  localparam int DEPTH = MEMORY_SIZE / WRITE_DATA_WIDTH_A;

  // The macro parameters are untyped; copy the strings to typed ones to compare them.
  localparam string S_WRITE_MODE_A = WRITE_MODE_A;
  localparam string S_WRITE_MODE_B = WRITE_MODE_B;
  localparam string S_ECC_MODE     = ECC_MODE;
  localparam string S_RST_MODE_A   = RST_MODE_A;
  localparam string S_RST_MODE_B   = RST_MODE_B;
  localparam string S_RESET_VAL_A  = READ_RESET_VALUE_A;
  localparam string S_RESET_VAL_B  = READ_RESET_VALUE_B;
  localparam string S_INIT_FILE    = MEMORY_INIT_FILE;

  // 0 write_first, 1 read_first, 2 no_change
  localparam int WM_A = (S_WRITE_MODE_A == "write_first" || S_WRITE_MODE_A == "WRITE_FIRST") ? 0 :
                        (S_WRITE_MODE_A == "read_first"  || S_WRITE_MODE_A == "READ_FIRST")  ? 1 : 2;
  localparam int WM_B = (S_WRITE_MODE_B == "write_first" || S_WRITE_MODE_B == "WRITE_FIRST") ? 0 :
                        (S_WRITE_MODE_B == "read_first"  || S_WRITE_MODE_B == "READ_FIRST")  ? 1 : 2;

  if (WRITE_DATA_WIDTH_B != W || READ_DATA_WIDTH_A != W || READ_DATA_WIDTH_B != W) begin : gen_chk_width
    $fatal(1, "xpm_memory_tdpram model: read and write widths of both ports must be equal");
  end
  if (S_ECC_MODE != "no_ecc" && S_ECC_MODE != "NO_ECC") begin : gen_chk_ecc
    $fatal(1, "xpm_memory_tdpram model: ECC is not modelled");
  end
  if (READ_LATENCY_A < 1 || READ_LATENCY_A > 2 || READ_LATENCY_B < 1 || READ_LATENCY_B > 2) begin : gen_chk_latency
    $fatal(1, "xpm_memory_tdpram model: READ_LATENCY must be 1 or 2");
  end
  if (S_RST_MODE_A != "SYNC" || S_RST_MODE_B != "SYNC") begin : gen_chk_rst
    $fatal(1, "xpm_memory_tdpram model: only RST_MODE SYNC is modelled");
  end
  if (S_RESET_VAL_A != "0" || S_RESET_VAL_B != "0") begin : gen_chk_rstval
    $fatal(1, "xpm_memory_tdpram model: only READ_RESET_VALUE \"0\" is modelled");
  end

  logic [W-1:0] mem [DEPTH];
  logic [W-1:0] qa_s1, qa_s2, qb_s1, qb_s2;   // read stages: s1 is the output register for latency 1

  initial begin
    for (int i = 0; i < DEPTH; i++) mem[i] = '0;
    if (S_INIT_FILE != "none" && S_INIT_FILE != "") $readmemh(S_INIT_FILE, mem);
    qa_s1 = '0; qa_s2 = '0; qb_s1 = '0; qb_s2 = '0;
  end

  assign sbiterra = 1'b0;
  assign dbiterra = 1'b0;
  assign sbiterrb = 1'b0;
  assign dbiterrb = 1'b0;

  // ---------------------------------------------------------------------------
  // Port A
  // ---------------------------------------------------------------------------
  localparam int COLS_A = WRITE_DATA_WIDTH_A / BYTE_WRITE_WIDTH_A;

  always @(posedge clka) begin : wr_a
    if (ena)
      for (int c = 0; c < COLS_A; c++)
        if (wea[c]) mem[addra][c*BYTE_WRITE_WIDTH_A +: BYTE_WRITE_WIDTH_A] <=
            dina[c*BYTE_WRITE_WIDTH_A +: BYTE_WRITE_WIDTH_A];
  end

  always @(posedge clka) begin : rd_a
    if (READ_LATENCY_A == 1 && rsta)
      qa_s1 <= '0;
    else if (ena)
      for (int c = 0; c < COLS_A; c++)
        if (wea[c] && WM_A == 0)
          qa_s1[c*BYTE_WRITE_WIDTH_A +: BYTE_WRITE_WIDTH_A] <= dina[c*BYTE_WRITE_WIDTH_A +: BYTE_WRITE_WIDTH_A];
        else if (wea[c] && WM_A == 2)
          qa_s1[c*BYTE_WRITE_WIDTH_A +: BYTE_WRITE_WIDTH_A] <= qa_s1[c*BYTE_WRITE_WIDTH_A +: BYTE_WRITE_WIDTH_A];
        else
          qa_s1[c*BYTE_WRITE_WIDTH_A +: BYTE_WRITE_WIDTH_A] <= mem[addra][c*BYTE_WRITE_WIDTH_A +: BYTE_WRITE_WIDTH_A];
  end

  always @(posedge clka) begin : pipe_a
    if (rsta)        qa_s2 <= '0;
    else if (regcea) qa_s2 <= qa_s1;
  end

  assign douta = (READ_LATENCY_A == 1) ? qa_s1 : qa_s2;

  // ---------------------------------------------------------------------------
  // Port B
  // ---------------------------------------------------------------------------
  localparam int COLS_B = WRITE_DATA_WIDTH_B / BYTE_WRITE_WIDTH_B;

  always @(posedge clkb) begin : wr_b
    if (enb)
      for (int c = 0; c < COLS_B; c++)
        if (web[c]) mem[addrb][c*BYTE_WRITE_WIDTH_B +: BYTE_WRITE_WIDTH_B] <=
            dinb[c*BYTE_WRITE_WIDTH_B +: BYTE_WRITE_WIDTH_B];
  end

  always @(posedge clkb) begin : rd_b
    if (READ_LATENCY_B == 1 && rstb)
      qb_s1 <= '0;
    else if (enb)
      for (int c = 0; c < COLS_B; c++)
        if (web[c] && WM_B == 0)
          qb_s1[c*BYTE_WRITE_WIDTH_B +: BYTE_WRITE_WIDTH_B] <= dinb[c*BYTE_WRITE_WIDTH_B +: BYTE_WRITE_WIDTH_B];
        else if (web[c] && WM_B == 2)
          qb_s1[c*BYTE_WRITE_WIDTH_B +: BYTE_WRITE_WIDTH_B] <= qb_s1[c*BYTE_WRITE_WIDTH_B +: BYTE_WRITE_WIDTH_B];
        else
          qb_s1[c*BYTE_WRITE_WIDTH_B +: BYTE_WRITE_WIDTH_B] <= mem[addrb][c*BYTE_WRITE_WIDTH_B +: BYTE_WRITE_WIDTH_B];
  end

  always @(posedge clkb) begin : pipe_b
    if (rstb)        qb_s2 <= '0;
    else if (regceb) qb_s2 <= qb_s1;
  end

  assign doutb = (READ_LATENCY_B == 1) ? qb_s1 : qb_s2;

endmodule
/* verilator lint_on MULTIDRIVEN */
/* verilator lint_on UNUSEDSIGNAL */
/* verilator lint_on UNUSEDPARAM */
