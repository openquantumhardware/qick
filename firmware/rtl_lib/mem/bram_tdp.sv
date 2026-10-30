///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : bram_tdp
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    bram_tdp.sv
//!
//! @brief   True dual-port block RAM (independent clocks and resets).
//!
//! @details
//!
//! - Memory of **NB_DATA** bits per word and **2^NB_ADDR** words.
//! - Each port (`port_a`, `port_b`) operates independently and may read or
//!   write on any clock cycle. Clocks and resets can differ (dual-clock RAM).
//! - If `MEM_BIN_FILE` is not empty the array is initialised from that file
//!   (XPM `.mem` format, hex, one word per line); otherwise it starts at 0.
//! - Implemented on `xpm_memory_tdpram` (write_first on both ports). An
//!   inferred template for this RAM -- two write ports, write-first -- is NOT
//!   mappable by Vivado synthesis: it warns "Infeasible attribute ram_style =
//!   block" and fails with [Synth 8-2914] "Unsupported RAM template"
//!   (qick_processor, whose program/data/wave memories write on both ports).
//!   The same template read-first maps fine, but read-during-write returning
//!   the new data is part of this module's contract, so XPM it is. Simple
//!   dual-port uses (web tied 0) inferred fine before, which is why the
//!   generators and buffers never hit it.
//!
//! READ LATENCY
//!
//! Each port has a mandatory read register, giving a 1-cycle read latency:
//! data presented on `addrX` during cycle n appears on `doX` in cycle n+1.
//!
//! `OUT_REG_A` / `OUT_REG_B` add a second, optional register on the
//! corresponding output, giving 2-cycle latency. This reproduces the behaviour
//! of the Xilinx `bram_dp_xpm` primitive with `OUT_REG_ENA = 1`, which several
//! QICK datapaths were originally timed against.
//!
//! Both default to 0, so existing instantiations are unaffected.
//!
//! Getting this wrong is silent: a datapath whose delay lines were sized for a
//! 2-cycle memory and is then fed by a 1-cycle one reads its data one cycle
//! early, and if consecutive addresses hold consecutive rows the whole result
//! is shifted by a row with no error anywhere. sgv6 hit exactly this when
//! `bram_dp_xpm` (OUT_REG_ENA=1) was replaced with `bram_tdp`; it instantiates
//! the envelope banks with `OUT_REG_B(1)`.
//!
//! The optional register shares the port's `en` input, matching the mandatory
//! stage: with `enX` low the output holds rather than advancing.
//!
//! @generic
//! NB_DATA      : unsigned int – data width of each word (default 32).
//! NB_ADDR      : unsigned int – number of address bits (default 10 -> 1024).
//! MEM_BIN_FILE : string – path to a hex initialisation file (optional).
//! OUT_REG_A    : bit – add a second output register on port A (default 0).
//! OUT_REG_B    : bit – add a second output register on port B (default 0).
//!
//! @author  QICK Development Team
//!
//! @version 1.2
module bram_tdp #(
    parameter int unsigned NB_DATA      = 32,
    parameter int unsigned NB_ADDR      = 10,
    parameter string       MEM_BIN_FILE = "",
    //! 0 = 1-cycle read latency on port A, 1 = 2 cycles
    parameter bit          OUT_REG_A    = 1'b0,
    //! 0 = 1-cycle read latency on port B, 1 = 2 cycles
    parameter bit          OUT_REG_B    = 1'b0
)(
    //port A signals
    input  logic  clka,
    input  logic  rsta,
    input  logic  ena,
    input  logic  wea,
    input  logic [NB_ADDR-1:0] addra,
    input  logic [NB_DATA-1:0] dia,
    output logic [NB_DATA-1:0] doa,

    //port B signals
    input  logic  clkb,
    input  logic  rstb,
    input  logic  enb,
    input  logic  web,
    input  logic [NB_ADDR-1:0] addrb,
    input  logic [NB_DATA-1:0] dib,
    output logic [NB_DATA-1:0] dob
);

    localparam int unsigned DEPTH     = 1 << NB_ADDR;
    localparam string       INIT_FILE = (MEM_BIN_FILE == "") ? "none" : MEM_BIN_FILE;

    // XPM semantics match the previous inferred RAM: rst has priority over en
    // on the read register, a write returns the written word (write_first),
    // and with READ_LATENCY 2 the output stage advances on regce -- tied to
    // the port's en, so with en low the output holds, as documented above.
    xpm_memory_tdpram #(
        .ADDR_WIDTH_A        (NB_ADDR),
        .ADDR_WIDTH_B        (NB_ADDR),
        .AUTO_SLEEP_TIME     (0),
        .BYTE_WRITE_WIDTH_A  (NB_DATA),
        .BYTE_WRITE_WIDTH_B  (NB_DATA),
        .CLOCKING_MODE       ("independent_clock"),
        .ECC_MODE            ("no_ecc"),
        .MEMORY_INIT_FILE    (INIT_FILE),
        .MEMORY_INIT_PARAM   ("0"),
        .MEMORY_OPTIMIZATION ("true"),
        .MEMORY_PRIMITIVE    ("block"),
        .MEMORY_SIZE         (DEPTH * NB_DATA),
        .MESSAGE_CONTROL     (0),
        .READ_DATA_WIDTH_A   (NB_DATA),
        .READ_DATA_WIDTH_B   (NB_DATA),
        .READ_LATENCY_A      (OUT_REG_A ? 2 : 1),
        .READ_LATENCY_B      (OUT_REG_B ? 2 : 1),
        .READ_RESET_VALUE_A  ("0"),
        .READ_RESET_VALUE_B  ("0"),
        .RST_MODE_A          ("SYNC"),
        .RST_MODE_B          ("SYNC"),
        .SIM_ASSERT_CHK      (0),
        .USE_MEM_INIT        (1),
        .WAKEUP_TIME         ("disable_sleep"),
        .WRITE_DATA_WIDTH_A  (NB_DATA),
        .WRITE_DATA_WIDTH_B  (NB_DATA),
        .WRITE_MODE_A        ("write_first"),
        .WRITE_MODE_B        ("write_first")
    ) u_xpm (
        .clka           (clka),
        .rsta           (rsta),
        .ena            (ena),
        .regcea         (ena),
        .wea            (wea),
        .addra          (addra),
        .dina           (dia),
        .douta          (doa),

        .clkb           (clkb),
        .rstb           (rstb),
        .enb            (enb),
        .regceb         (enb),
        .web            (web),
        .addrb          (addrb),
        .dinb           (dib),
        .doutb          (dob),

        .sleep          (1'b0),
        .injectsbiterra (1'b0),
        .injectdbiterra (1'b0),
        .injectsbiterrb (1'b0),
        .injectdbiterrb (1'b0),
        .sbiterra       (),
        .dbiterra       (),
        .sbiterrb       (),
        .dbiterrb       ()
    );

endmodule
