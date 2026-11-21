///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Interface : bram_if
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    bram_if.sv
//!
//! @brief   Single‑port BRAM interface with optional byte‑enable support.
//!
//! @details
//!
//!
//! For a true dual‑port RAM instantiate this interface twice (port_a, port_b).
//!
//! • `en`  – enable (read or write)
//!
//! • `we`  – write enable (1 = write, 0 = read)  (single‑bit version)
//!
//! • `we_be` – byte‑enable vector, each bit corresponds to a byte of `din`.
//! For a full‑word write set `we_be = {(NB_DATA/8){1'b1}}`.
//!
//! • `addr` – address
//!
//! • `din`  – data to write
//!
//! • `dout` – data read (registered output of the BRAM)
//!
//! @author  QICK Development Team
//!
//! 0.1.1: the tb_cb clocking block is inside the `ifndef SYNTHESIS / `ifndef VERILATOR guard with the tasks that
//! use it (Verilator 5.052 lint: MULTIDRIVENPROC on en, we, we_be, addr, din).
//!
//! @version 0.1.1

interface bram_if #(
    parameter int unsigned NB_DATA = 32,
    parameter int unsigned NB_ADDR = 10
) (
    input  logic i_clk,
    input  logic i_rst
);
    // -----------------------------------------------------------------
    // 1.  Signals visible to the DUT
    // -----------------------------------------------------------------
    logic                     en;     // enable
    logic                     we;     // write‑enable (single bit)
    // Byte‑enable (optional).  If not used, keep it tied to 1.
    logic [(NB_DATA/8)-1:0]  we_be;  // one bit per byte
    logic [NB_ADDR-1:0]       addr;
    logic [NB_DATA-1:0]       din;    // data into the RAM
    logic [NB_DATA-1:0]       dout;   // data out of the RAM (registered)

    // -----------------------------------------------------------------
    // 3.  Modports
    // -----------------------------------------------------------------
    // DUT (master) drives everything except dout.
    modport master (
        output en, we, we_be, addr, din,
        input  dout
    );

    // DUT (slave) reads inputs and drives dout.
    modport slave (
        input  en, we, we_be, addr, din,
        output dout
    );

     // ============================================================
  // SIMULATION-ONLY CODE
  // ============================================================
  `ifndef SYNTHESIS
    `ifndef VERILATOR

      // ------------------------------------------------------------
      // CLOCKING BLOCKS
      // ------------------------------------------------------------
    // Testbench-only, like the tasks below: outside this guard Verilator lint reports every signal it drives
    // as MULTIDRIVENPROC (written by the clocking block and by the design, IEEE 1800 14.3).
    clocking tb_cb @(posedge i_clk);
        default input #1step output #2;
        output en, we, we_be, addr, din;
        input  dout;
    endclocking

    // Testbench uses the clocking block.
    modport tb_master (
        clocking tb_cb
    );

    // -----------------------------------------------------------------
    // 4.  Test‑bench tasks (automatic, use tb_cb for correct timing)
    // -----------------------------------------------------------------
    // idle: drive all outputs to safe defaults
    task automatic idle();
        tb_cb.en   <= 1'b0;
        tb_cb.we   <= 1'b0;
        tb_cb.we_be <= '0;
        tb_cb.addr <= '0;
        tb_cb.din  <= '0;
    endtask

    /** Write a whole word (all bytes enabled). */
    task automatic write_data(
        input logic [NB_ADDR-1:0] w_addr,
        input logic [NB_DATA-1:0] w_data
    );
        @(tb_cb); // ensure we start on a clock edge
        tb_cb.en   <= 1'b1;
        tb_cb.we   <= 1'b1;
        tb_cb.we_be <= {(NB_DATA/8){1'b1}}; // full‑word enable
        tb_cb.addr <= w_addr;
        tb_cb.din  <= w_data;
        @(tb_cb);               // latch on this posedge
        tb_cb.en   <= 1'b0;
        tb_cb.we   <= 1'b0;
        tb_cb.we_be <= '0;
        @(tb_cb);               // margin before next operation
    endtask

    /** Read a whole word.  The data is returned in *r_data*. */
    task automatic read_data(
        input  logic [NB_ADDR-1:0] r_addr,
        output logic [NB_DATA-1:0] r_data
    );
        @(tb_cb);               // ensure we start on a clock edge
        tb_cb.en   <= 1'b1;
        tb_cb.we   <= 1'b0;
        tb_cb.we_be <= '0;
        tb_cb.addr <= r_addr;
        @(tb_cb);               // address registered
        tb_cb.en   <= 1'b0;
        @(tb_cb);               // dout stable (one cycle after addr)
        r_data = tb_cb.dout;
    endtask


    `endif // VERILATOR
  `endif // SYNTHESIS

endinterface : bram_if
