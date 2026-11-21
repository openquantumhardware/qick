///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Interface : axi4_lite_if
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    axi4_lite_if.sv
//!
//! @brief   AXI4-Lite Interface
//!
//! @details
//!
//!
//! SystemVerilog interface
//! encapsulating the AXI4-Lite protocol signals and verification tasks.
//!
//! This interface provides standard hardware modports for RTL
//! integration alongside specialized automated tasks for testbench environments
//! (e.g., SVUnit).  It uses synchronous non-blocking assignments to prevent race
//! conditions and simulator crashes.  Fully compatible with TerosHDL
//! documentation parsers.
//!
//! @note  Clocking blocks (m_cb/s_cb) and the verification tasks are simulation-only:
//!        synthesis sees only the AXI signals + master/slave modports, xsim gets the
//!        clocking-block tasks, and Verilator (which does not take the clocking blocks)
//!        gets, when compiled with -DQICK_VERILATOR_TB (and --timing), the same master tasks
//!        axi_write / axi_read / reset / wait_idle, written
//!        with plain edges: driven on the falling edge of aclk, handshakes read on the rising edge.
//!
//! @author  QICK Development Team
//!
//! @version 1.0

interface axi4_lite_if#(
  parameter int DATA_WIDTH = 32, //! The AXI4-Lite data bus width (must be 32 or 64 bits).
  parameter int ADDR_WIDTH = 32  //! The AXI4-Lite address bus width in bits.
)(
  input logic aclk,    //! Global system clock source.
  input logic aresetn  //! Global synchronous active-low reset.
);

  generate
    if ((DATA_WIDTH != 32) && (DATA_WIDTH != 64)) begin : g_check_data_width
      $fatal(1, "The AXI4-Lite data bus width must be 32 or 64 bits wide (%0d not supported).", DATA_WIDTH);
    end
  endgenerate

  // ==========================================================================
  // AXI4-LITE SIGNALS
  // ==========================================================================

  logic                    awready; //! Write address ready. Indicates the slave is ready to accept an address.
  logic                    awvalid; //! Write address valid. Indicates the master is signaling a valid address.
  logic [ADDR_WIDTH-1:0]   awaddr;  //! Write address bus.
  logic [2:0]              awprot;  //! Write protection type. Indicates the privilege and security level.

  logic                    wready;  //! Write data ready. Indicates the slave can accept the write data.
  logic                    wvalid;  //! Write data valid. Indicates valid write data and strobes are available.
  logic [DATA_WIDTH-1:0]   wdata;   //! Write data bus.
  logic [DATA_WIDTH/8-1:0] wstrb;   //! Write strobes. Indicates which byte lanes hold valid data.

  logic                    bready;  //! Write response ready. Indicates the master can accept a write response.
  logic                    bvalid;  //! Write response valid. Indicates the channel is signaling a valid write response.
  logic [1:0]              bresp;   //! Write response status. Indicates the status of the write transaction.

  logic                    arready; //! Read address ready. Indicates the slave is ready to accept an address.
  logic                    arvalid; //! Read address valid. Indicates the channel is signaling valid read address info.
  logic [ADDR_WIDTH-1:0]   araddr;  //! Read address bus.
  logic [2:0]              arprot;  //! Read protection type. Indicates the privilege and security level.

  logic                    rready;  //! Read data ready. Indicates the master can accept the read data and response.
  logic                    rvalid;  //! Read data valid. Indicates the channel is signaling the required read data.
  logic [DATA_WIDTH-1:0]   rdata;   //! Read data bus.
  logic [1:0]              rresp;   //! Read response status. Indicates the status of the read transfer.

  // ==========================================================================
  // RTL MODPORTS
  // ==========================================================================

  /** Modport for capturing RTL Master port assignments. */
  modport master (
    input  awready,
    output awvalid,
    output awaddr,
    output awprot,

    input  wready,
    output wvalid,
    output wdata,
    output wstrb,

    output bready,
    input  bvalid,
    input  bresp,

    input  arready,
    output arvalid,
    output araddr,
    output arprot,

    output rready,
    input  rvalid,
    input  rdata,
    input  rresp
  );

  /** Modport for capturing RTL Slave port assignments. */
  modport slave (
    output awready,
    input  awvalid,
    input  awaddr,
    input  awprot,

    output wready,
    input  wvalid,
    input  wdata,
    input  wstrb,

    input  bready,
    output bvalid,
    output bresp,

    output arready,
    input  arvalid,
    input  araddr,
    input  arprot,

    input  rready,
    output rvalid,
    output rdata,
    output rresp
  );

  // ==========================================================================
  // TESTBENCH CLOCKING BLOCKS (For cycle-accurate UVM/SVUnit driving)
  // ==========================================================================

  `ifdef SYNTHESIS
  `elsif VERILATOR
  `ifdef QICK_VERILATOR_TB

  // Testbench master for Verilator (compile with -DQICK_VERILATOR_TB and --timing; lint without --timing and the
  // cores that only use the interface as ports do not see it). Same tasks and arguments as the clocking-block ones
  // below. The signals are driven on the falling edge of aclk and the handshakes are read on the rising edge,
  // before the slave's registers change, so there is no race with the design (a driver that changes a signal on the
  // very edge the design samples it is resolved either way by Verilator): a handshake is a valid and a ready both
  // high at the same rising edge, and the valid goes low on the falling edge after it.

  task automatic axi_write(
    input  logic [ADDR_WIDTH-1:0] addr,
    input  logic [DATA_WIDTH-1:0] data,
    input  int                    timeout = 100
  );
    int  c;
    bit  aw_done, w_done, b_done;
    @(negedge aclk);
    awaddr  <= addr;
    awvalid <= 1'b1;
    awprot  <= 3'b000;
    wdata   <= data;
    wstrb   <= {(DATA_WIDTH/8){1'b1}};
    wvalid  <= 1'b1;
    bready  <= 1'b1;
    c = 0; aw_done = 1'b0; w_done = 1'b0;
    while ((!aw_done || !w_done) && c < timeout) begin
      @(posedge aclk);
      c++;
      if (!aw_done && awready) aw_done = 1'b1;
      if (!w_done  && wready)  w_done  = 1'b1;
      @(negedge aclk);
      if (aw_done) awvalid <= 1'b0;
      if (w_done)  wvalid  <= 1'b0;
    end
    if (!aw_done) $error("[%0t] AXI Write: Timeout waiting for awready", $time);
    if (!w_done)  $error("[%0t] AXI Write: Timeout waiting for wready", $time);
    awvalid <= 1'b0;
    wvalid  <= 1'b0;
    c = 0; b_done = 1'b0;
    while (!b_done && c < timeout) begin
      @(posedge aclk);
      c++;
      if (bvalid) begin
        b_done = 1'b1;
        if (bresp !== 2'b00) $warning("[%0t] AXI Write: Received error response: 'b%b", $time, bresp);
      end
    end
    if (!b_done) $error("[%0t] AXI Write: Timeout waiting for bvalid", $time);
    @(negedge aclk);
    bready <= 1'b0;
  endtask

  task automatic axi_read(
    input  logic [ADDR_WIDTH-1:0]  addr,
    output logic [DATA_WIDTH-1:0]  data,
    input  int                     timeout = 100
  );
    int c;
    bit ar_done, r_done;
    @(negedge aclk);
    araddr  <= addr;
    arvalid <= 1'b1;
    arprot  <= 3'b000;
    rready  <= 1'b1;
    c = 0; ar_done = 1'b0;
    while (!ar_done && c < timeout) begin
      @(posedge aclk);
      c++;
      if (arready) ar_done = 1'b1;
      @(negedge aclk);
      if (ar_done) arvalid <= 1'b0;
    end
    if (!ar_done) $error("[%0t] AXI Read: Timeout waiting for arready", $time);
    arvalid <= 1'b0;
    c = 0; r_done = 1'b0; data = '0;
    while (!r_done && c < timeout) begin
      @(posedge aclk);
      c++;
      if (rvalid) begin
        r_done = 1'b1;
        data   = rdata;
        if (rresp !== 2'b00) $warning("[%0t] AXI Read: Received error response: 'b%b", $time, rresp);
      end
    end
    if (!r_done) $error("[%0t] AXI Read: Timeout waiting for rvalid", $time);
    @(negedge aclk);
    rready <= 1'b0;
  endtask

  task automatic reset();
    awaddr  <= '0;
    awvalid <= 1'b0;
    awprot  <= 3'b000;
    wdata   <= '0;
    wstrb   <= '0;
    wvalid  <= 1'b0;
    bready  <= 1'b0;
    araddr  <= '0;
    arvalid <= 1'b0;
    arprot  <= 3'b000;
    rready  <= 1'b0;
    if (aresetn === 1'b0) wait (aresetn === 1'b1);
    @(negedge aclk);
  endtask

  task automatic wait_idle(int timeout = 100);
    int cycles_wait = 0;
    while ((awvalid || wvalid || arvalid || bvalid || rvalid) && cycles_wait < timeout) begin
      @(posedge aclk);
      cycles_wait++;
    end
    if (cycles_wait >= timeout) $warning("[%0t] AXI Interface not idle after timeout", $time);
  endtask

  `endif // QICK_VERILATOR_TB
  `else

    /** Modport for testbench master using cycle-accurate clocking block. */
    modport tb_master(clocking m_cb);

    /** Modport for testbench slave using cycle-accurate clocking block. */
    modport tb_slave(clocking s_cb);

    /**
     * @brief Master Clocking Block
     * @details Synchronizes master stimulus and sampling to the clock edge,
     * preventing race conditions in cycle-level testbench manipulation.
     */
    clocking m_cb @(posedge aclk);
      default input #1step output #2;

      input  awready;
      output awvalid;
      output awaddr;
      output awprot;

      input  wready;
      output wvalid;
      output wdata;
      output wstrb;

      output bready;
      input  bvalid;
      input  bresp;

      input  arready;
      output arvalid;
      output araddr;
      output arprot;

      output rready;
      input  rvalid;
      input  rdata;
      input  rresp;
    endclocking

    /**
     * @brief Slave Clocking Block
     * @details Synchronizes slave stimulus and sampling to the clock edge,
     * preventing race conditions in cycle-level testbench manipulation.
     */
    clocking s_cb @(posedge aclk);
      default input #1step output #2;

      output awready;
      input  awvalid;
      input  awaddr;
      input  awprot;

      output wready;
      input  wvalid;
      input  wdata;
      input  wstrb;

      input  bready;
      output bvalid;
      output bresp;

      output arready;
      input  arvalid;
      input  araddr;
      input  arprot;

      input  rready;
      output rvalid;
      output rdata;
      output rresp;
    endclocking

  // ==========================================================================
  // ENHANCED TASKS (Robust & XSim-Safe Timeout Control)
  // ==========================================================================

  /**
   * @task axi_write
   * @brief Enhanced write task with built-in timeout and response error checking.
   * @param addr The destination address.
   * @param data The data payload to transmit.
   * @param timeout Maximum clock cycles to wait for slave handshake before throwing a fatal error.
   */
  task automatic axi_write(
    input  logic [ADDR_WIDTH-1:0] addr,
    input  logic [DATA_WIDTH-1:0] data,
    input  int                    timeout = 100
  );
    @(m_cb);
    m_cb.awaddr  <= addr;
    m_cb.awvalid <= 1'b1;
    m_cb.awprot  <= 3'b000;
    m_cb.wdata   <= data;
    m_cb.wstrb   <= {(DATA_WIDTH/8){1'b1}};
    m_cb.wvalid  <= 1'b1;
    m_cb.bready  <= 1'b1;

    fork
      // Address Channel (AW)
      begin : aw_handshake
        int c = 0;
        do begin
          @(m_cb);
          c++;
        end while (!m_cb.awready && c < timeout);
        if (c >= timeout) $error("[%0t] AXI Write: Timeout waiting for awready", $time);
        m_cb.awvalid <= 1'b0;
      end

      // Data Channel (W)
      begin : w_handshake
        int c = 0;
        while (!m_cb.wready && c < timeout) begin
          @(m_cb);
          c++;
        end
        if (c >= timeout) $error("[%0t] AXI Write: Timeout waiting for wready", $time);
        m_cb.wvalid <= 1'b0;
      end
    join

    // Response Channel (B)
    begin
      int c = 0;
      while (!m_cb.bvalid && c < timeout) begin
        @(m_cb);
        c++;
      end

      if (c >= timeout) begin
        $error("[%0t] AXI Write: Timeout waiting for bvalid", $time);
      end else if (m_cb.bresp !== 2'b00) begin
        $warning("[%0t] AXI Write: Received error response: 'b%b", $time, m_cb.bresp);
      end
    end

    m_cb.bready <= 1'b0;
    @(m_cb);
  endtask

  /**
   * @task axi_read
   * @brief Enhanced read task with built-in timeout and response error checking.
   * @param addr The target read address.
   * @param data Output variable to capture the returned data.
   * @param timeout Maximum clock cycles to wait for slave handshake before throwing a fatal error.
   */
  task automatic axi_read(
    input  logic [ADDR_WIDTH-1:0]  addr,
    output logic [DATA_WIDTH-1:0]  data,
    input  int                     timeout = 100
  );
    @(m_cb);
    m_cb.araddr  <= addr;
    m_cb.arvalid <= 1'b1;
    m_cb.arprot  <= 3'b000;
    m_cb.rready  <= 1'b1;

    begin
      int c = 0;
      while (!m_cb.arready && c < timeout) begin
        @(m_cb);
        c++;
      end
      if (c >= timeout) $error("[%0t] AXI Read: Timeout waiting for arready", $time);
      m_cb.arvalid <= 1'b0;
    end

    begin
      int c = 0;
      while (!m_cb.rvalid && c < timeout) begin
        @(m_cb);
        c++;
      end

      if (c >= timeout) begin
        $error("[%0t] AXI Read: Timeout waiting for rvalid", $time);
      end else if (m_cb.rresp !== 2'b00) begin
        $warning("[%0t] AXI Read: Received error response: 'b%b", $time, m_cb.rresp);
      end
    end

    data = m_cb.rdata;
    m_cb.rready <= 1'b0;
    @(m_cb);
  endtask

  /**
   * @task write_field
   * @brief Performs a read-modify-write operation on a specific register field.
   * @param addr The address of the register.
   * @param data The new data value to be inserted into the field (un-shifted).
   * @param mask The bitmask defining the field (shifted to its target position).
   * @param offset The bit offset position where the data should be shifted.
   */
  task automatic write_field (
    input logic [ADDR_WIDTH        -1:0] addr,
    input logic [DATA_WIDTH        -1:0] data,
    input logic [DATA_WIDTH        -1:0] mask,
    input logic [$clog2(ADDR_WIDTH)  :0] offset
  );
    begin
      logic [DATA_WIDTH-1:0] rd_data, wr_data;
      axi_read(addr, rd_data);
      wr_data = (rd_data & ~mask) | ((data << offset) & mask);
      axi_write(addr, wr_data);
    end
  endtask

  /**
   * @task read_field
   * @brief Reads a specific field from a register and returns the un-shifted value.
   * @param addr The address of the register.
   * @param data The variable to store the extracted field value.
   * @param mask The bitmask defining the field (shifted to its target position).
   * @param offset The bit offset position of the field.
   */
  task automatic read_field (
    input  logic [ADDR_WIDTH        -1:0] addr,
    output logic [DATA_WIDTH        -1:0] data,
    input  logic [DATA_WIDTH        -1:0] mask,
    input  logic [$clog2(ADDR_WIDTH)  :0] offset
  );
    begin
      logic [DATA_WIDTH-1:0] tmp_data;
      axi_read(addr, tmp_data);
      data = (tmp_data & mask) >> offset;
    end
  endtask

  /**
   * @task axi_bulk_write
   * @brief Sequentially writes an array of data to consecutive register addresses.
   * @param base_addr The starting address for the bulk write.
   * @param data_array The array of data words to write.
   * @param timeout Timeout limit per transaction.
   */
  task automatic axi_bulk_write(
    input  logic [ADDR_WIDTH-1:0] base_addr,
    input  logic [DATA_WIDTH-1:0] data_array [],
    input  int                    timeout = 100
  );
    foreach (data_array[i]) begin
      axi_write(base_addr + (i * (DATA_WIDTH/8)), data_array[i], timeout);
    end
  endtask

  /**
   * @task axi_bulk_read
   * @brief Sequentially reads multiple registers starting from a base address.
   * @param base_addr The starting address for the bulk read.
   * @param data_array Dynamic array to be populated with the read data.
   * @param num_regs The number of consecutive registers to read.
   * @param timeout Timeout limit per transaction.
   */
  task automatic axi_bulk_read(
    input  logic [ADDR_WIDTH-1:0]  base_addr,
    output logic [DATA_WIDTH-1:0]  data_array [],
    input  int                      num_regs,
    input  int                     timeout = 100
  );
    data_array = new[num_regs];
    for (int i = 0; i < num_regs; i++) begin
      axi_read(base_addr + (i * (DATA_WIDTH/8)), data_array[i], timeout);
    end
  endtask

  /**
   * @task reset
   * @brief Initializes all master-driven AXI4-Lite channels to their default idle states.
   * @details Halts execution until the global `aresetn` signal is deasserted.
   */
  task automatic reset();
    m_cb.awaddr   <= '0;
    m_cb.awvalid  <= 1'b0;
    m_cb.awprot   <= 3'b000;
    m_cb.wdata    <= '0;
    m_cb.wstrb    <= '0;
    m_cb.wvalid   <= 1'b0;
    m_cb.bready   <= 1'b0;
    m_cb.araddr   <= '0;
    m_cb.arvalid  <= 1'b0;
    m_cb.arprot   <= 3'b000;
    m_cb.rready   <= 1'b0;

    if (aresetn === 1'b0) begin
      wait(aresetn === 1'b1);
    end
    @(m_cb);
  endtask

  /**
   * @task wait_idle
   * @brief Blocks execution until all AXI4-Lite channels return to an idle state.
   * @param timeout Maximum cycles to wait before throwing a warning.
   */
  task automatic wait_idle(int timeout = 100);
    int cycles_wait = 0;
    while ((awvalid || wvalid || arvalid || bvalid || rvalid) && cycles_wait < timeout) begin
      @(m_cb);
      cycles_wait++;
    end
    if (cycles_wait >= timeout) begin
      $warning("[%0t] AXI Interface not idle after timeout", $time);
    end
  endtask

  `endif //SYNTHESIS
endinterface
