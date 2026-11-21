///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : dmem
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    dmem.sv
//!
//! @brief   Top-level data memory controller for the QICK tProcV1 processor.
//!
//! @details
//!
//!
//! Assembles three submodules and arbitrates between three access modes:
//!
//! Mode 0 (sel=0) — Single access
//! Accessed by the processor via exec/exec_ack handshake.
//! Available only when busy_o = 0 (no AXIS transaction in progress).
//!
//! Mode 1 (sel=1) — AXIS Read
//! Reads 'len_reg' words from memory starting at 'addr_reg' and
//! streams them out via m_axis. Initiated by start_reg=1, mode_reg=0.
//!
//! Mode 2 (sel=2) — AXIS Write
//! Receives a burst on s_axis (terminated by tlast) and writes it to
//! memory starting at 'addr_reg'. Initiated by start_reg=1, mode_reg=1.
//!
//! After each AXIS transaction completes, the user must deassert start_reg
//! and reassert it to initiate a new transaction.
//!
//! Submodules:
//! dmem_ctrl        — FSM arbiter (sel, busy, exec handshakes)
//! dmem_single_rw   — Single read/write with exec handshake
//! dmem_axis_reader — BRAM → AXI4-Stream master
//! dmem_axis_writer — AXI4-Stream slave → BRAM
//!
//! External memory interface:
//! The BRAM itself is instantiated outside this module. dmem drives
//! mem_we_o, mem_di_o, mem_addr_o and reads mem_do_i.
//! The address/data mux (sel) selects which submodule drives the BRAM.
//!
//! @author  QICK Development Team
//!
//! @version 1.0
module dmem #(
    //! memory address width (depth = 2**N words)
    parameter int N = 16,
    //! data width in bits
    parameter int B = 32
)(
    input  logic        clk,
    input  logic        rstn,

    //--------------------------------------------------------------------------
    // Single-access handshake interface
    //--------------------------------------------------------------------------
    output logic        busy_o,
    input  logic        oper_i,     // 0 = read, 1 = write
    input  logic [N-1:0] addr_i,
    input  logic [B-1:0] din_i,
    output logic [B-1:0] dout_o,
    input  logic        exec_i,
    output logic        exec_ack_o,

    //--------------------------------------------------------------------------
    // External BRAM interface (flat ports — BRAM instantiated outside)
    //--------------------------------------------------------------------------
    output logic        mem_we_o,
    output logic [B-1:0] mem_di_o,
    input  logic [B-1:0] mem_do_i,
    output logic [N-1:0] mem_addr_o,

    //--------------------------------------------------------------------------
    // AXI4-Stream slave (data in → write to memory)
    //--------------------------------------------------------------------------
    axi4_stream_if.slave  s_axis,

    //--------------------------------------------------------------------------
    // AXI4-Stream master (read from memory → data out)
    //--------------------------------------------------------------------------
    axi4_stream_if.master m_axis,

    //--------------------------------------------------------------------------
    // Control registers
    //--------------------------------------------------------------------------
    input  logic        mode_reg,
    input  logic        start_reg,
    input  logic [N-1:0] addr_reg,
    input  logic [N-1:0] len_reg
);

    //--------------------------------------------------------------------------
    // Internal arbiter signals
    //--------------------------------------------------------------------------
    logic [1:0] sel;
    logic       ar_exec;
    logic       ar_exec_ack;
    logic       aw_exec;
    logic       aw_exec_ack;

    //--------------------------------------------------------------------------
    // Internal BRAM interface instances
    // One per submodule; the mux below selects which drives the external BRAM.
    //--------------------------------------------------------------------------

    // Dummy clock/rst for bram_if (tied to module ports)
    // bram_if requires i_clk/i_rst in its parameter list but the signals
    // are only used by the clocking block (simulation-only).
    bram_if #(.NB_DATA(B), .NB_ADDR(N)) bram_single (.i_clk(clk), .i_rst(~rstn));
    bram_if #(.NB_DATA(B), .NB_ADDR(N)) bram_reader (.i_clk(clk), .i_rst(~rstn));
    bram_if #(.NB_DATA(B), .NB_ADDR(N)) bram_writer (.i_clk(clk), .i_rst(~rstn));

    // Thread mem_do_i into all BRAM slaves (read data is broadcast)
    assign bram_single.dout = mem_do_i;
    assign bram_reader.dout = mem_do_i;
    assign bram_writer.dout = mem_do_i;

    //--------------------------------------------------------------------------
    // Submodule: dmem_ctrl — access arbiter
    //--------------------------------------------------------------------------
    dmem_ctrl #(.N(N)) ctrl_i (
        .clk          (clk),
        .rstn         (rstn),
        .sel_o        (sel),
        .ar_exec_o    (ar_exec),
        .ar_exec_ack_i(ar_exec_ack),
        .aw_exec_o    (aw_exec),
        .aw_exec_ack_i(aw_exec_ack),
        .busy_o       (busy_o),
        .mode_reg     (mode_reg),
        .start_reg    (start_reg)
    );

    //--------------------------------------------------------------------------
    // Submodule: dmem_single_rw — processor single access
    //--------------------------------------------------------------------------
    dmem_single_rw #(.N(N), .B(B)) single_rw_i (
        .clk       (clk),
        .rstn      (rstn),
        .rw_i      (oper_i),
        .exec_i    (exec_i),
        .exec_ack_o(exec_ack_o),
        .addr_i    (addr_i),
        .din_i     (din_i),
        .do_o      (dout_o),
        .bram      (bram_single)
    );

    //--------------------------------------------------------------------------
    // Submodule: dmem_axis_reader — BRAM → AXI4-Stream
    //--------------------------------------------------------------------------
    dmem_axis_reader #(.N(N), .B(B)) axis_reader_i (
        .clk        (clk),
        .rstn       (rstn),
        .exec_i     (ar_exec),
        .exec_ack_o (ar_exec_ack),
        .addr_i     (addr_reg),
        .len_i      (len_reg),
        .bram       (bram_reader),
        .axis       (m_axis)
    );

    //--------------------------------------------------------------------------
    // Submodule: dmem_axis_writer — AXI4-Stream → BRAM
    //--------------------------------------------------------------------------
    dmem_axis_writer #(.N(N), .B(B)) axis_writer_i (
        .clk        (clk),
        .rstn       (rstn),
        .exec_i     (aw_exec),
        .exec_ack_o (aw_exec_ack),
        .addr_i     (addr_reg),
        .bram       (bram_writer),
        .axis       (s_axis)
    );

    //--------------------------------------------------------------------------
    // BRAM output mux — sel selects which submodule drives the external BRAM
    //   sel = 0 : single_rw
    //   sel = 1 : axis_reader
    //   sel = 2 : axis_writer
    //--------------------------------------------------------------------------
    always_comb begin
        unique case (sel)
            2'd0: begin
                mem_we_o   = bram_single.we;
                mem_di_o   = bram_single.din;
                mem_addr_o = bram_single.addr;
            end
            2'd1: begin
                mem_we_o   = bram_reader.we;
                mem_di_o   = bram_reader.din;
                mem_addr_o = bram_reader.addr;
            end
            2'd2: begin
                mem_we_o   = bram_writer.we;
                mem_di_o   = bram_writer.din;
                mem_addr_o = bram_writer.addr;
            end
            default: begin
                mem_we_o   = 1'b0;
                mem_di_o   = '0;
                mem_addr_o = '0;
            end
        endcase
    end

endmodule
