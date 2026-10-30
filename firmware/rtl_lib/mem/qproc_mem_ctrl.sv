///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : qproc_mem_ctrl
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    qproc_mem_ctrl.sv
//!
//! @brief   Assembled external-memory access controller for the tProcessor v2.
//!
//! @details
//!
//!
//! Three modes of accessing the (external) qcore_mem memory banks:
//!
//! * Single access using the mem_dt_i/mem_dt_o register interface. Only
//!   available when busy_o = 0 (no AXIS transaction in progress). Gated to
//!   the data-memory bank only (mem_sel == PMEM/WMEM ignore single writes),
//!   matching the legacy behavior.
//! * AXIS read: streams data out via m_axis_*, using mem_addr as the
//!   starting address and mem_len as the sample count. The user sets
//!   mem_ctrl[0] (start) = 1 to begin; the last sample asserts
//!   m_axis_tlast_o.
//! * AXIS write: receives data via s_axis_* and writes it starting at
//!   mem_addr, relying on s_axis_tlast_i to terminate the burst.
//!
//! Once an AXIS transaction completes, mem_ctrl[0] must be deasserted and
//! reasserted to start a new one.
//!
//! mem_ctrl bit fields:
//! * [0]   start   : 1 = start the operation indicated below, 0 = stop.
//! * [1]   op      : 0 = AXIS read (memory -> m_axis), 1 = AXIS write
//!                   (s_axis -> memory).
//! * [3:2] mem_sel : 01 = program memory, 10 = data memory, 11 = wave
//!                   memory (which qcore_mem bank the transfer targets).
//! * [4]   source  : 0 = AXIS transaction, 1 = single register access.
//! * [6:5] core_sel: which physical core's memory bank is targeted
//!                   (decoded upstream, outside this module).
//!
//! Reuses the already-migrated tProcv1 memory-arbiter cores (dmem_ctrl /
//! dmem_single_rw / dmem_axis_reader / dmem_axis_writer) as generic leaf
//! engines; this module supplies the tProcv2-specific 3-bank
//! (program/data/wave) select mux and wave-memory field packing that those
//! generic cores have no equivalent for.
//!
//! Fixes applied over the legacy Verilog (`qproc_mem_ctrl.v`):
//! - `busy_o` and `end_single_o` are real output ports. Legacy connected
//!   them as if they were declared signals, but neither was ever declared
//!   as a port or a wire, so Verilog silently inferred them as
//!   unconnected 1-bit implicit nets (dead outputs).
//!
//! The wave-memory field packing/unpacking below (freq/phase/env/gain/
//! length/conf <-> ext_mem_w_dt_o / mem_r_dt_axis) is carried over
//! bit-for-bit from the legacy implementation and should not be
//! reinterpreted without full wave-memory packet format context.
//!
//! @author  QICK Development Team
//!
//! @version 1.0

module qproc_mem_ctrl #(
    parameter int PMEM_AW = 16,
    parameter int DMEM_AW = 16,
    parameter int WMEM_AW = 16
)(
    // Clock & reset
    input  logic         clk,
    input  logic         rstn,

    // External memory access (shared bus toward qcore_mem; core selection
    // via ext_core_sel_o is decoded upstream, outside this module)
    output logic [1:0]   ext_core_sel_o,
    output logic [1:0]   ext_mem_sel_o,   // 00=NONE 01=PMEM 10=DMEM 11=WMEM
    output logic         ext_mem_we_o,
    output logic [15:0]  ext_mem_addr_o,
    output logic [167:0] ext_mem_w_dt_o,
    input  logic [167:0] ext_mem_r_dt_i,

    // AXIS slave (data in -> write to memory)
    input  logic [255:0] s_axis_tdata_i,
    input  logic         s_axis_tlast_i,
    input  logic         s_axis_tvalid_i,
    output logic         s_axis_tready_o,

    // AXIS master (memory -> data out)
    output logic [255:0] m_axis_tdata_o,
    output logic         m_axis_tlast_o,
    output logic         m_axis_tvalid_o,
    input  logic         m_axis_tready_i,

    // Control registers
    input  logic [6:0]   mem_ctrl,
    input  logic [15:0]  mem_addr,
    input  logic [15:0]  mem_len,
    input  logic [31:0]  mem_dt_i,
    output logic [31:0]  mem_dt_o,
    output logic [31:0]  debug_o,

    // Status (see header: real ports, fixing a legacy implicit-net bug)
    output logic         busy_o,
    output logic         end_single_o
);

    //--------------------------------------------------------------------------
    // Control-register field decode
    //--------------------------------------------------------------------------
    logic        mem_start, mem_op, mem_source;
    logic [1:0]  mem_sel;
    logic [1:0]  core_sel;
    logic        start_axis, start_single;

    assign mem_start  = mem_ctrl[0];   // 1 = start, go to 0 for next.
    assign mem_op     = mem_ctrl[1];   // 0 = read, 1 = write.
    assign mem_sel    = mem_ctrl[3:2]; // 01 = Pmem, 10 = Dmem, 11 = Wmem.
    assign mem_source = mem_ctrl[4];   // 0 = AXIS, 1 = registers (single).
    assign core_sel   = mem_ctrl[6:5]; // Core selection.

    assign start_axis   = mem_start & ~mem_source;
    assign start_single  = mem_start & mem_source;

    //--------------------------------------------------------------------------
    // dmem_ctrl arbiter (reused from tProcv1): sel_o encodes which engine
    // currently owns the external memory bus (0=single, 1=axis_read,
    // 2=axis_write).
    //--------------------------------------------------------------------------
    logic [1:0] sel;
    logic       ar_exec, ar_exec_ack;
    logic       aw_exec, aw_exec_ack;

    dmem_ctrl #(
        .N (16)
    ) dmem_ctrl_i (
        .clk           (clk),
        .rstn          (rstn),
        .sel_o         (sel),
        .ar_exec_o     (ar_exec),
        .ar_exec_ack_i (ar_exec_ack),
        .aw_exec_o     (aw_exec),
        .aw_exec_ack_i (aw_exec_ack),
        .busy_o        (busy_o),
        .mode_reg      (mem_op),
        .start_reg     (start_axis)
    );

    //--------------------------------------------------------------------------
    // Local BRAM-interface instances: one per engine, muxed onto the
    // external memory bus below (mirrors the dmem.sv assembly pattern).
    //--------------------------------------------------------------------------
    bram_if #(.NB_DATA(32),  .NB_ADDR(16)) bram_single (.i_clk(clk), .i_rst(~rstn));
    bram_if #(.NB_DATA(256), .NB_ADDR(16)) bram_reader (.i_clk(clk), .i_rst(~rstn));
    bram_if #(.NB_DATA(256), .NB_ADDR(16)) bram_writer (.i_clk(clk), .i_rst(~rstn));

    //--------------------------------------------------------------------------
    // Data AXI-Read format: repack the 168-bit qcore_mem read bus into the
    // 256-bit AXIS word, depending on which bank is selected (verbatim from
    // legacy, see file header).
    //--------------------------------------------------------------------------
    logic [255:0] mem_r_dt_axis;

    always_comb begin
        unique case (mem_sel)
            2'b01:   mem_r_dt_axis = {88'd0, ext_mem_r_dt_i};                                                 // PMEM
            2'b10:   mem_r_dt_axis = {88'd0, ext_mem_r_dt_i};                                                 // DMEM
            2'b11:   mem_r_dt_axis = {80'd0, ext_mem_r_dt_i[167:88], 8'd0, ext_mem_r_dt_i[87:0]};             // WMEM
            default: mem_r_dt_axis = '0;
        endcase
    end

    assign bram_single.dout = ext_mem_r_dt_i[31:0];
    assign bram_reader.dout = mem_r_dt_axis;
    assign bram_writer.dout = '0; // Write-only engine; read data unused.

    //--------------------------------------------------------------------------
    // Submodule: dmem_single_rw (reused) - register-style single access.
    //--------------------------------------------------------------------------
    dmem_single_rw #(
        .N (16),
        .B (32)
    ) dmem_single_rw_i (
        .clk        (clk),
        .rstn       (rstn),
        .rw_i       (mem_op),
        .exec_i     (start_single),
        .exec_ack_o (end_single_o),
        .addr_i     (mem_addr),
        .din_i      (mem_dt_i),
        .do_o       (mem_dt_o),
        .bram       (bram_single)
    );

    //--------------------------------------------------------------------------
    // Submodule: dmem_axis_reader (reused) - memory -> m_axis.
    //--------------------------------------------------------------------------
    axi4_stream_if #(.TDATA_WIDTH(256)) m_axis_if (.aclk(clk), .aresetn(rstn));

    dmem_axis_reader #(
        .N (16),
        .B (256)
    ) dmem_axis_reader_i (
        .clk        (clk),
        .rstn       (rstn),
        .exec_i     (ar_exec),
        .exec_ack_o (ar_exec_ack),
        .addr_i     (mem_addr),
        .len_i      (mem_len),
        .bram       (bram_reader),
        .axis       (m_axis_if)
    );

    assign m_axis_tdata_o  = m_axis_if.tdata;
    assign m_axis_tlast_o  = m_axis_if.tlast;
    assign m_axis_tvalid_o = m_axis_if.tvalid;
    assign m_axis_if.tready = m_axis_tready_i;

    //--------------------------------------------------------------------------
    // Submodule: dmem_axis_writer (reused) - s_axis -> memory.
    //--------------------------------------------------------------------------
    axi4_stream_if #(.TDATA_WIDTH(256)) s_axis_if (.aclk(clk), .aresetn(rstn));

    dmem_axis_writer #(
        .N (16),
        .B (256)
    ) dmem_axis_writer_i (
        .clk        (clk),
        .rstn       (rstn),
        .exec_i     (aw_exec),
        .exec_ack_o (aw_exec_ack),
        .addr_i     (mem_addr),
        .bram       (bram_writer),
        .axis       (s_axis_if)
    );

    assign s_axis_if.tdata   = s_axis_tdata_i;
    assign s_axis_if.tlast   = s_axis_tlast_i;
    assign s_axis_if.tvalid  = s_axis_tvalid_i;
    assign s_axis_tready_o   = s_axis_if.tready;

    //--------------------------------------------------------------------------
    // External memory bus mux (single / axis_read / axis_write), selected by
    // dmem_ctrl's sel_o. Preserves the legacy restriction that a single-mode
    // external write is only asserted while the data-memory bank is
    // selected (see header note).
    //--------------------------------------------------------------------------
    logic [15:0]  ext_mem_addr;
    logic         ext_mem_we;
    logic [167:0] ext_pmem_w_dt, ext_dmem_w_dt, ext_wmem_w_dt;
    logic [255:0] mem_w_dt_axis;
    logic [31:0]  freq, phase, gain, lenght, conf;
    logic [31:0]  env;

    assign mem_w_dt_axis = bram_writer.din;

    always_comb begin
        unique case (sel)
            2'd0:    ext_mem_addr = bram_single.addr;
            2'd1:    ext_mem_addr = bram_reader.addr;
            2'd2:    ext_mem_addr = bram_writer.addr;
            default: ext_mem_addr = '0;
        endcase
    end

    // Verbatim from legacy: freq/phase/env/gain/length/conf field extraction
    // from the 256-bit AXIS write word, and their repacking into the 168-bit
    // wave-memory format.
    assign freq   = mem_w_dt_axis[ 31:  0];
    assign phase  = mem_w_dt_axis[ 63: 32];
    assign env    = mem_w_dt_axis[ 95: 64];
    assign gain   = mem_w_dt_axis[127: 96];
    assign lenght = mem_w_dt_axis[159:128];
    assign conf   = mem_w_dt_axis[191:160];

    assign ext_pmem_w_dt = {96'd0, mem_w_dt_axis[71:0]};
    assign ext_dmem_w_dt = {136'd0, mem_source ? bram_single.din : mem_w_dt_axis[31:0]};
    assign ext_wmem_w_dt = {conf[15:0], lenght, gain, env[23:0], phase, freq};

    always_comb begin
        unique case (mem_sel)
            2'b01:   ext_mem_w_dt_o = ext_pmem_w_dt;
            2'b10:   ext_mem_w_dt_o = ext_dmem_w_dt;
            2'b11:   ext_mem_w_dt_o = ext_wmem_w_dt;
            default: ext_mem_w_dt_o = '0;
        endcase
    end

    always_comb begin
        unique case (sel)
            2'd0:    ext_mem_we = bram_single.we & (mem_sel == 2'b10); // Single write: DMEM only.
            2'd1:    ext_mem_we = 1'b0;                                // Read engine never writes.
            2'd2:    ext_mem_we = bram_writer.we;
            default: ext_mem_we = 1'b0;
        endcase
    end

    //--------------------------------------------------------------------------
    // Outputs
    //--------------------------------------------------------------------------
    assign ext_core_sel_o = core_sel;
    assign ext_mem_sel_o  = mem_sel;
    assign ext_mem_we_o   = ext_mem_we;
    assign ext_mem_addr_o = ext_mem_addr;

    assign debug_o[31:24] = 8'd0;
    assign debug_o[23:16] = {mem_op, core_sel, mem_source, mem_sel, ar_exec, aw_exec};
    assign debug_o[15:8]  = ext_mem_addr[7:0];
    assign debug_o[7:0]   = ext_mem_w_dt_o[7:0];

endmodule
