///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : axis_to_bram_sg
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    axis_to_bram_sg.sv
//!
//! @brief   AXI4-Stream to single BRAM writer with configurable start address.
//!
//! @details
//!
//! Receives a continuous stream and writes it to memory starting at
//! start_addr_reg. capture_reg enables/disables writing and may come from a
//! different clock domain — synchronised internally with cdc_gray_sync.
//!
//! FSM: INIT_ST -> READ_START_ADDR_ST -> WAIT_TVALID_ST -> RW_TDATA_ST
//!
//! INIT_ST            : wait for capture_reg=1
//! READ_START_ADDR_ST : latch start_addr_reg into the address counter (1 cycle)
//! WAIT_TVALID_ST     : assert tready, wait for the first valid beat
//! RW_TDATA_ST        : stream active — write on every accepted beat,
//!                      return to WAIT_TVALID_ST if tvalid drops,
//!                      return to INIT_ST if capture_reg deasserts
//!
//! Pipeline: 3 register stages (d1/d2/d3, v1/v2/v3, a1/a2/a3) carry data,
//! write-enable and address together. Because the stages shift unconditionally
//! and bram.we is driven from v3 alone, anything already in the pipeline when
//! capture_reg drops still completes — the tail of a load is never discarded.
//!
//! -------------------------------------------------------------------------
//! v1.1 — end-of-table guard
//!
//! v1.0 let the address counter wrap silently. A stream longer than the table
//! (a mis-sized DMA descriptor, a length register that does not match the
//! bitstream's N) would run past the top address and overwrite the beginning
//! of the table with its own tail, with nothing to indicate it had happened.
//!
//! v1.1 stops writing once the top address has been consumed and raises a
//! sticky o_overflow flag. Beats that arrive after that are still ACCEPTED and
//! discarded rather than back-pressured: stalling the stream would deadlock an
//! AXI DMA mid-descriptor, which is a worse failure than dropping data that was
//! never going to fit. The flag is what makes the condition visible; software
//! is expected to read it after a load.
//!
//! Also: tready is now decoded straight from the FSM state instead of being
//! registered a cycle behind it. The registered form kept tready high for one
//! cycle after capture_reg dropped, so the block accepted one more beat than
//! software expected — written correctly, but one word past the intended end of
//! the load. If that extra cycle of fanout ever becomes a timing problem, the
//! registered form can come back, but then it must be qualified with
//! capture_sync so the extra beat is not accepted.
//! -------------------------------------------------------------------------
//!
//! Interfaces:
//! axis : axi4_stream_if.slave  — incoming data stream
//! bram : bram_if.master        — write-only BRAM port
//!
//! @note    Ported from axis_sg_int4_v2/src/data_writer.vhd
//!
//! @author  QICK Development Team
//!
//! @version 1.1
`timescale 1ns/1ps

module axis_to_bram_sg #(
    //! BRAM address width (depth = 2**N)
    parameter int N = 16,
    //! data width in bits
    parameter int B = 16
) (
    input  logic             rstn,
    input  logic             clk,

    // AXI4-Stream slave — incoming data
    axi4_stream_if.slave     axis,

    // BRAM master — write only
    bram_if.master           bram,

    // Registers (start_addr_reg may be wide; capture_reg may be CDC)
    input  logic [31:0]      start_addr_reg,
    input  logic             capture_reg,

    //! Sticky: at least one beat was accepted after the table was full and had
    //! to be discarded. Cleared when the writer is re-armed.
    output logic             o_overflow
);

    logic handshake;
    assign handshake = axis.tvalid && axis.tready;

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
    // AXI4-Stream pipeline registers (3 stages)
    // -------------------------------------------------------------------------
    logic [B-1:0]     d1, d2, d3;
    logic             v1, v2, v3;
    logic [N-1:0]     a1, a2, a3;

    // -------------------------------------------------------------------------
    // Memory address and end-of-table guard
    // -------------------------------------------------------------------------
    logic [N-1:0] addr_full;
    //! Set once the top address of the table has been written; blocks any
    //! further writes so a long stream cannot wrap and eat its own start
    logic         table_full;
    logic         overflow_r;

    assign o_overflow = overflow_r;

    // -------------------------------------------------------------------------
    // Datapath registers
    // -------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (!rstn) begin
            d1 <= '0; d2 <= '0; d3 <= '0;
            v1 <= '0; v2 <= '0; v3 <= '0;
            a1 <= '0; a2 <= '0; a3 <= '0;
            addr_full  <= '0;
            table_full <= 1'b0;
            overflow_r <= 1'b0;
        end else begin
            // Stage 1: sample AXI inputs.  The write-enable is qualified here,
            // once, so the guard travels with the beat it belongs to instead of
            // being re-evaluated three cycles later against a stale counter.
            d1 <= axis.tdata[B-1:0];
            v1 <= handshake && !table_full;
            a1 <= addr_full;

            // Stage 2 & 3: pipeline to align with FSM latency
            d2 <= d1; d3 <= d2;
            v2 <= v1; v3 <= v2;
            a2 <= a1; a3 <= a2;

            // Address: latch the start address on arm, then advance per beat
            if (read_start_addr_state) begin
                addr_full  <= start_addr_reg[N-1:0];
                table_full <= 1'b0;
                overflow_r <= 1'b0;
            end else if (handshake) begin
                if (!table_full) begin
                    addr_full <= addr_full + 1'b1;
                    // The top address has just been consumed: stop here rather
                    // than wrapping around to the start of the table
                    if (addr_full == '1)
                        table_full <= 1'b1;
                end else begin
                    // Accepted, but there is nowhere to put it
                    overflow_r <= 1'b1;
                end
            end
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
    // tready follows the state directly.  Registering it kept the block
    // accepting for one cycle after the FSM had already left RW_TDATA_ST.
    // Note tready stays asserted while table_full: over-length streams are
    // drained and flagged, not back-pressured, so a DMA cannot deadlock here.
    assign axis.tready = tready_i;

    assign bram.en     = 1'b1;
    assign bram.we     = v3;
    assign bram.addr   = a3;
    assign bram.din    = d3;

endmodule

