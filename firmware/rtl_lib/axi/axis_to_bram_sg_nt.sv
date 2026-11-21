///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : axis_to_bram_sg_nt
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    axis_to_bram_sg_nt.sv
//!
//! @brief   AXI4-Stream to NT BRAM writer. Identical FSM and pipeline to
//!
//!
//! axis_to_bram_sg but drives NT memories by splitting the full address:
//!
//! addr_full[NT_LOG2-1        : 0]       → mem_en[NT] (one-hot demux)
//! addr_full[NT_LOG2+N-1      : NT_LOG2] → bram.addr  (row address)
//!
//! @details
//!
//! All NT memories share bram.we, bram.addr and bram.din.
//! mem_en selects which of the NT memories is written each cycle.
//!
//! FSM: INIT_ST → READ_START_ADDR_ST → WAIT_TVALID_ST → RW_TDATA_ST
//! (identical to axis_to_bram_sg)
//!
//! Pipeline: 3 register stages align tdata, address high and mem_en
//! with the FSM state transitions (fixes spurious write bug).
//!
//! Interfaces:
//! axis   : axi4_stream_if.slave — incoming data stream
//! bram   : bram_if.master       — shared write port (addr/din/we)
//! mem_en : logic [NT-1:0]       — per-table write enable (one-hot)
//!
//! @note    Ported from axis_signal_gen_v6/src/data_writer.vhd
//!
//! @author  QICK Development Team
//!
//! @version 1.0
`timescale 1ns/1ps

module axis_to_bram_sg_nt #(
    //! number of tables (must be a power of 2)
    parameter int NT = 16,
    //! address width per table (depth = 2**N per table)
    parameter int N  = 16,
    //! data width in bits
    parameter int B  = 16
) (
    input  logic             rstn,
    input  logic             clk,

    // AXI4-Stream slave — incoming data
    axi4_stream_if.slave     axis,

    // BRAM shared write port
    bram_if.master           bram,

    // Per-table write enable (one-hot)
    output logic [NT-1:0]    mem_en,

    // Registers
    input  logic [31:0]      start_addr_reg,
    input  logic             capture_reg
);

    logic handshake;
    assign handshake = axis.tvalid && axis.tready;
    // -------------------------------------------------------------------------
    // Derived parameter
    // -------------------------------------------------------------------------
    localparam int NT_LOG2 = $clog2(NT);

    // -------------------------------------------------------------------------
    // CDC: synchronise capture_reg into clk domain
    // -------------------------------------------------------------------------
    logic capture_sync;

    cdc_gray_sync #(
        .N (2),
        .M (1)
    ) capture_sync_i (
        .i_clk  (clk),
        .i_rstn (rstn),
        .i_d    (capture_reg),
        .o_d    (capture_sync)
    );

    // -------------------------------------------------------------------------
    // FSM state encoding
    // -------------------------------------------------------------------------
    typedef enum logic [1:0] {
        INIT_ST            = 2'd0,
        READ_START_ADDR_ST = 2'd1,
        WAIT_TVALID_ST     = 2'd2,
        RW_TDATA_ST        = 2'd3
    } state_t;

    state_t state;

    // -------------------------------------------------------------------------
    // FSM output decode
    // -------------------------------------------------------------------------
    logic read_start_addr_state;
    logic rw_tdata_state;
    logic tready_i;

    // -------------------------------------------------------------------------
    // Full address and split signals
    // -------------------------------------------------------------------------
    logic [NT_LOG2+N-1:0] addr_full;
    logic [NT_LOG2-1:0]   addr_low;   // selects table → mem_en
    logic [N-1:0]         addr_high;  // row address within table → bram.addr

    assign addr_low  = addr_full[NT_LOG2-1:0];
    assign addr_high = addr_full[NT_LOG2+N-1:NT_LOG2];

    // -------------------------------------------------------------------------
    // mem_en combinational demux
    // -------------------------------------------------------------------------
    logic [NT-1:0] mem_en_i;

    always_comb begin
        mem_en_i = '0;
        mem_en_i[addr_low] = 1'b1;
    end

    // -------------------------------------------------------------------------
    // AXI4-Stream pipeline registers (3 stages)
    // Gated by rw_tdata_state to prevent spurious writes
    // -------------------------------------------------------------------------
    logic             tready_r;
    logic [B-1:0]     d1, d2, d3;
    logic             v1, v2, v3;
    logic [N-1:0]     a1, a2, a3;
    logic [NT-1:0]    e1, e2, e3;

    always_ff @(posedge clk) begin
        if (!rstn) begin
            tready_r  <= '0;
            d1 <= '0; d2 <= '0; d3 <= '0;
            v1 <= '0; v2 <= '0; v3 <= '0;
            a1 <= '0; a2 <= '0; a3 <= '0;
            e1 <= '0; e2 <= '0; e3 <= '0;
            addr_full <= '0;
        end else begin
            tready_r <= tready_i;

            // Stage 1 — capture only when FSM is actively writing
            v1 <= handshake;
            d1 <= axis.tdata[B-1:0];
            a1 <= addr_high;   // pre-increment row address
            e1 <= handshake ? mem_en_i : '0;    // pre-increment table select

            // Stage 2 & 3
            d2 <= d1; d3 <= d2;
            v2 <= v1; v3 <= v2;
            a2 <= a1; a3 <= a2;
            e2 <= e1; e3 <= e2;

            // Full address update
            if (read_start_addr_state)
                addr_full <= (NT_LOG2+N)'(start_addr_reg);
            else if (handshake)
                addr_full <= addr_full + 1'b1;
        end
    end

    // -------------------------------------------------------------------------
    // FSM
    // -------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (!rstn) begin
            state <= INIT_ST;
        end else begin
            unique case (state)
                INIT_ST:
                    if (capture_sync) state <= READ_START_ADDR_ST;

                READ_START_ADDR_ST:
                    state <= WAIT_TVALID_ST;

                WAIT_TVALID_ST:
                    if (!capture_sync)
                        state <= INIT_ST;
                    else if (axis.tvalid)
                        state <= RW_TDATA_ST;

                RW_TDATA_ST:
                    if (!capture_sync)
                        state <= INIT_ST;
                    else if (!axis.tvalid)
                        state <= WAIT_TVALID_ST;

                default: state <= INIT_ST;
            endcase
        end
    end

    // -------------------------------------------------------------------------
    // FSM output decode (combinational)
    // -------------------------------------------------------------------------
    always_comb begin
        read_start_addr_state = 1'b0;
        rw_tdata_state        = 1'b0;
        tready_i              = 1'b0;

        unique case (state)
            INIT_ST:            ;
            READ_START_ADDR_ST: read_start_addr_state = 1'b1;
            WAIT_TVALID_ST:     tready_i              = 1'b1;
            RW_TDATA_ST: begin
                rw_tdata_state = 1'b1;
                tready_i       = 1'b1;
            end
            default: ;
        endcase
    end

    // -------------------------------------------------------------------------
    // Output assignments
    // -------------------------------------------------------------------------
    assign axis.tready = tready_r;
    assign bram.en     = 1'b1;
    assign bram.we     = v3;
    assign bram.addr   = a3;
    assign bram.din    = d3;
    assign mem_en      = e3;

endmodule
