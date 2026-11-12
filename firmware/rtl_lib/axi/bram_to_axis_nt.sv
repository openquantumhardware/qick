///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : bram_to_axis_nt
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    bram_to_axis_nt.sv
//!
//! @brief   BRAM reader to AXI4-Stream for NT-channel memories.
//!
//! @details
//!
//! Reads ALL channels from ALL BRAM addresses (full depth) and outputs
//! sequential data on AXI4-Stream. "NT" = No Top/No Length register
//! (only start_reg, no addr_reg or len_reg).
//!
//! The reader walks through:
//! 1. All addresses: 0 to 2**N-1
//! 2. All channels: 0 to NT-1 for each address
//!
//! Total words output = 2**N * NT
//! tlast is packed into the FIFO alongside the data so it can never drift out
//! of step with the beat it belongs to.
//!
//! FSM States:
//! INIT_ST        -> Wait for start_reg (and discard any stale FIFO contents)
//! READ_ST        -> Read BRAM data at current address
//! WRITE_ST       -> Write current channel to FIFO, advance channel selector
//! READ_LAST_ST   -> Read last BRAM address
//! WRITE_LAST_ST  -> Write last channel to FIFO
//! FIFO_ST        -> Drain FIFO to AXI Stream
//! END_ST         -> Wait for start_reg to deassert
//!
//! -------------------------------------------------------------------------
//! v1.1 — tail-of-burst fix
//!
//! v1.0 retired FIFO_ST on the FIFO's `empty` flag and gated m_axis_tvalid on
//! the FSM state.  XPM's `empty` deasserts a cycle or two AFTER a write, so
//! FIFO_ST could sample empty=1 while the final words were still in flight,
//! jump to END_ST, drop stream_en, and strand them — including the word
//! carrying tlast.  Downstream this hangs forever: an AXI DMA that never sees
//! tlast never closes the packet.
//!
//! The window was only wide enough to hit when the producer barely outruns the
//! consumer, which is why NT=8 looked healthy and NT=2 lost exactly NT beats.
//!
//! Two changes make the tail unconditional:
//!   - a flight counter (fifo_level) tracks words actually written and read,
//!     derived from fifo_wr_en/fifo_rd_en rather than from a status flag, and
//!     FIFO_ST retires only when it reaches zero
//!   - stream_en is deasserted only in INIT_ST, so even if the FSM retires
//!     early nothing can be stranded behind a gated tvalid
//!
//! INIT_ST additionally flushes any residue from an interrupted burst, so a
//! start_reg pulse always begins from a clean FIFO.
//! -------------------------------------------------------------------------
//!
//! Interfaces:
//! bram   : bram_if.master        — read port (addr only, we=0)
//! axis   : axi4_stream_if.master — output data stream (width = B)
//!
//! @note    Ported from mr_buffer/data_reader.vhd
//!
//! @author  QICK Development Team
//!
//! @version 1.1

`timescale 1ns/1ps

module bram_to_axis_nt #(
    //! number of tables/channels (must be power of 2)
    parameter int NT = 8,
    //! address width per table (depth = 2**N)
    parameter int N  = 8,
    //! AXI data width in bits (output per channel)
    parameter int B  = 16
) (
    // Reset and clock
    input  logic              rstn,
    input  logic              clk,

    // BRAM Interface (read-only, wide input: NT*B bits)
    output logic              mem_en,
    output logic              mem_we,
    output logic [N-1:0]      mem_addr,
    input  logic [NT*B-1:0]   mem_dout,
    output logic [NT*B-1:0]   mem_din,      // Not used, tied to 0

    // AXI4-Stream Master Interface (output)
    input  logic              m_axis_tready,
    output logic [B-1:0]      m_axis_tdata,
    output logic              m_axis_tvalid,
    output logic              m_axis_tlast,

    // Control register (only start_reg, no addr_reg or len_reg)
    input  logic              start_reg
);

    // ---------------------------------------------------------------------
    // Local parameters
    // ---------------------------------------------------------------------
    localparam int NT_LOG2   = $clog2(NT);
    localparam int DEPTH     = 2 ** N;      // Memory depth per table
    localparam int FIFO_N    = 16;          // Output FIFO depth
    localparam int LVL_W     = $clog2(FIFO_N + 1);

    // ---------------------------------------------------------------------
    // FSM State Encoding
    // ---------------------------------------------------------------------
    typedef enum logic [2:0] {
        INIT_ST,
        READ_ST,
        WRITE_ST,
        READ_LAST_ST,
        WRITE_LAST_ST,
        FIFO_ST,
        END_ST
    } state_t;

    state_t current_state, next_state;

    // ---------------------------------------------------------------------
    // Internal Signals
    // ---------------------------------------------------------------------
    logic init_state;
    logic read_state;
    logic write_state;
    logic fifo_state;
    logic stream_en;                    // Enable AXI streaming

    // Counters
    logic [N-1:0]        addr_cnt;      // Address counter (0 to DEPTH-1)
    logic [NT_LOG2-1:0]  sel_cnt;       // Channel selector (0 to NT-1)

    // Registered memory output (pipeline stage)
    logic [NT*B-1:0]     mem_dout_r;

    // FIFO signals (widened by 1 bit to carry tlast)
    logic                fifo_wr_en;
    logic                fifo_rd_en;
    logic                fifo_flush;
    logic [B:0]          fifo_din;      // Bit [B] = tlast, Bits [B-1:0] = data
    logic [B:0]          fifo_dout;
    logic                fifo_full;
    logic                fifo_empty;

    //! Words actually in the FIFO, counted from the write/read strobes.
    //! Independent of XPM's flag latency — this is what retires the burst.
    logic [LVL_W-1:0]    fifo_level;
    logic                fifo_drained;

    // Multiplexer intermediate data and tlast tag
    logic [B-1:0]        mux_data;
    logic                fifo_tlast_bit;

    // AXI handshake
    logic axis_handshake;

    // ---------------------------------------------------------------------
    // FIFO Instantiation (expanded width: B + 1)
    // ---------------------------------------------------------------------
    fifo_sync #(
        .B (B + 1),
        .N (FIFO_N),
        .USE_ADV_FEATURES ("1707"),
        .ENABLE_COUNTERS (1)
    ) fifo_i (
        .rstn  (rstn),
        .clk   (clk),
        .wr_en (fifo_wr_en),
        .din   (fifo_din),
        .rd_en (fifo_rd_en),
        .dout  (fifo_dout),
        .full  (fifo_full),
        .empty (fifo_empty)
    );

    // ---------------------------------------------------------------------
    // Combinational Assignments
    // ---------------------------------------------------------------------

    // FIFO write: from BRAM when in a write state and the FIFO has room
    assign fifo_wr_en = write_state && !fifo_full;

    // Discard residue from an interrupted burst while parked in INIT_ST, so a
    // fresh start_reg never replays stale beats
    assign fifo_flush = init_state && !fifo_empty;

    // FIFO read: the AXI handshake, plus the INIT_ST flush
    assign axis_handshake = m_axis_tvalid && m_axis_tready;
    assign fifo_rd_en     = axis_handshake || fifo_flush;

    // BRAM interface: always enabled for reading
    assign mem_en   = 1'b1;
    assign mem_we   = 1'b0;
    assign mem_addr = addr_cnt;
    assign mem_din  = '0;

    // Multiplexer slicing the current channel out of the registered BRAM word
    always_comb begin
        mux_data = '0;
        for (int i = 0; i < NT; i++) begin
            if (sel_cnt == i) begin
                mux_data = mem_dout_r[(i+1)*B-1 -: B];
            end
        end
    end

    // Identify the very last word of the entire block transfer
    assign fifo_tlast_bit = (current_state == WRITE_LAST_ST) && (sel_cnt == NT-1);

    // Pack data and tlast together into the FIFO input bus
    assign fifo_din = {fifo_tlast_bit, mux_data};

    // AXI4-Stream outputs, unpacked directly from the FIFO output.
    // stream_en is low only in INIT_ST: gating tvalid on the *burst* states is
    // what stranded the tail in v1.0.
    assign m_axis_tdata  = fifo_dout[B-1:0];
    assign m_axis_tlast  = fifo_dout[B];
    assign m_axis_tvalid = stream_en && !fifo_empty;

    assign fifo_drained  = (fifo_level == '0);

    // ---------------------------------------------------------------------
    // Sequential Logic
    // ---------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (!rstn) begin
            current_state <= INIT_ST;
            addr_cnt      <= '0;
            sel_cnt       <= '0;
            mem_dout_r    <= '0;
        end else begin
            current_state <= next_state;

            // INIT state: clear counters
            if (init_state) begin
                mem_dout_r <= '0;
                addr_cnt   <= '0;
                sel_cnt    <= '0;
            end
            // READ states: latch BRAM data and advance the address
            else if (read_state) begin
                mem_dout_r <= mem_dout;
                addr_cnt   <= addr_cnt + 1;
            end
            // WRITE states: advance the channel selector
            else if (write_state && !fifo_full) begin
                sel_cnt <= sel_cnt + 1;
            end
        end
    end

    // ---------------------------------------------------------------------
    // FIFO flight counter
    //
    // Counted from the strobes, not from XPM's empty/full flags, so it is
    // exact on the cycle a word is written or read.  This is the only thing
    // allowed to decide that a burst has fully drained.
    // ---------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (!rstn) begin
            fifo_level <= '0;
        end else begin
            unique case ({fifo_wr_en, fifo_rd_en})
                2'b10:   fifo_level <= fifo_level + 1'b1;
                2'b01:   fifo_level <= fifo_level - 1'b1;
                default: fifo_level <= fifo_level;   // 00 or simultaneous 11
            endcase
        end
    end

    // ---------------------------------------------------------------------
    // Next State Logic
    // ---------------------------------------------------------------------
    always_comb begin
        next_state = current_state;

        case (current_state)
            INIT_ST: begin
                if (start_reg)
                    next_state = READ_ST;
            end

            READ_ST: begin
                next_state = WRITE_ST;
            end

            WRITE_ST: begin
                if (sel_cnt < NT-1 || fifo_full)
                    next_state = WRITE_ST;
                else if (addr_cnt < DEPTH-1)
                    next_state = READ_ST;
                else
                    next_state = READ_LAST_ST;
            end

            READ_LAST_ST: begin
                next_state = WRITE_LAST_ST;
            end

            WRITE_LAST_ST: begin
                if (sel_cnt < NT-1 || fifo_full)
                    next_state = WRITE_LAST_ST;
                else
                    next_state = FIFO_ST;
            end

            FIFO_ST: begin
                // Retire on the flight counter.  The empty flag lags the last
                // write and would let the FSM leave with beats still queued.
                if (fifo_drained)
                    next_state = END_ST;
            end

            END_ST: begin
                if (!start_reg)
                    next_state = INIT_ST;
            end

            default: next_state = INIT_ST;
        endcase
    end

    // ---------------------------------------------------------------------
    // Output Control Signal Logic
    // ---------------------------------------------------------------------
    always_comb begin
        init_state  = 1'b0;
        read_state  = 1'b0;
        write_state = 1'b0;
        fifo_state  = 1'b0;

        case (current_state)
            INIT_ST:       init_state  = 1'b1;
            READ_ST:       read_state  = 1'b1;
            WRITE_ST:      write_state = 1'b1;
            READ_LAST_ST:  read_state  = 1'b1;
            WRITE_LAST_ST: write_state = 1'b1;
            FIFO_ST:       fifo_state  = 1'b1;
            END_ST:        ;                      // no producer activity
            default:       ;
        endcase
    end

    // Streaming is inhibited only while parked in INIT_ST.  Everywhere else the
    // FIFO is allowed to present whatever it holds, so no beat can be trapped
    // behind a state transition.
    assign stream_en = (current_state != INIT_ST);

endmodule
