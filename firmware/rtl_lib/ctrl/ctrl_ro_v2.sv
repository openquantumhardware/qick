`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : ctrl_ro_v2
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    ctrl_ro_v2.sv
//!
//! @brief   Phase-coherent DDS controller for axis_readout_v2.
//!
//! @details
//! Faithful port of axis_readout_v2's ctrl.sv. Nearly identical to
//! ctrl_dyn_ro (same phase-coherent pinc*N/pinc*cnt_n construction), but:
//!
//! - Descriptor is 83 bits, no phrst field (this IP is AXI-Lite/PS
//!   configured, not tProc-streamed, so there is no per-descriptor
//!   phase-reset request -- cnt_n free-runs unconditionally, never reset).
//! - The "new descriptor is valid downstream" pulse is built from a
//!   straight 8-stage load_r1..load_r8 shift register (no separate
//!   sync_reg tier) -- same purpose as ctrl_dyn_ro's sync_reg_r7, simpler
//!   pipeline since there's one less register (no sync_reg feeding load_r
//!   in reverse).
//!
//! Descriptor layout (83 bits):
//!
//! | bits      | field   | width | meaning                                |
//! |-----------|---------|-------|----------------------------------------|
//! | 82        | mode    |   1   | mode (1 = periodic/non-stop)           |
//! | 81 .. 80  | outsel  |   2   | output source: 0=prod,1=dds,2=input    |
//! | 79 .. 64  | nsamp   |  16   | number of output samples               |
//! | 63 .. 32  | phase   |  32   | initial phase                          |
//! | 31 ..  0  | freq    |  32   | phase increment (pinc), sets frequency |
//!
//! FSM (one-hot): READ_ST (assert fifo_rd_en; when mode is periodic or a
//! descriptor is available, latch it and move to CNT_ST) -> CNT_ST (count
//! samples; when cnt reaches nsamp-2, return to READ_ST). A descriptor lasts
//! nsamp clocks, at least 3: the descriptor is latched one clock after the
//! pop (load_r) from the FIFO's held output (fifo_sync with HOLD_DOUT), so
//! its fields reach fifo_dout_r two clocks after the pop, and the earliest
//! end the new nsamp can set is cnt = 1. nsamp 0, 1 and 2 last 3 clocks.
//!
//! 1.0.1: the end of the count, max(nsamp, 3) - 2, is
//! registered with the descriptor (cnt_end), as in ctrl_dyn_ro 1.0.1. 1.0.0
//! (and the legacy ctrl.sv) compared cnt with nsamp - 2 in 16 bits: with
//! nsamp 0, 1 or 2 that wrapped, or was compared at cnt = 0 against the
//! previous descriptor's nsamp, and no descriptor was read for about 2^16
//! clocks. The qick_lib driver writes nsamp 10, so it sees no change.
//!
//! @author  QICK Development Team
//!
//! @version 1.0.1
///////////////////////////////////////////////////////////////////////////////
module ctrl_ro_v2 #(
    parameter int N_DDS = 8  //! Number of parallel DDS/demodulator lanes.
)(
    input  logic                aresetn,     //! Synchronous active-low reset (legacy port name: rstn).
    input  logic                aclk,        //! Clock (legacy port name: clk).

    // Fifo interface.
    output logic                 fifo_rd_en_o,
    input  logic                  fifo_empty_i,
    input  logic [82:0]           fifo_dout_i,

    // dds control.
    output logic [N_DDS*72-1:0]   dds_ctrl_o,

    // Output source selection.
    output logic [1:0]            outsel_o
);

    typedef enum logic [1:0] {
        READ_ST,
        CNT_ST
    } state_t;

    (* fsm_encoding = "one_hot" *) state_t state;

    // Fifo dout register.
    logic [82:0] fifo_dout_r;

    // Non-stop counter for time calculation (adds N_DDS samples each clock tick).
    logic [31:0] cnt_n;
    logic [31:0] cnt_n_reg;

    // Pinc/phase.
    logic [31:0] pinc_int;
    logic [31:0] pinc_r1;
    logic [31:0] pinc_r2;
    logic [31:0] pinc_n;
    logic [31:0] pinc_n_r1;
    logic [31:0] pinc_n_r2;
    logic [31:0] pinc_n_r3;
    logic [31:0] pinc_n_r4;
    logic [31:0] pinc_n_r5;
    logic [31:0] pinc_nm;
    logic [31:0] pinc_nm_r1;
    logic [31:0] pinc_nm_r2;
    logic [31:0] pinc_nm_r3;

    logic [31:0] phase_int;
    logic [31:0] phase_r1;
    logic [31:0] phase_r2;
    logic [31:0] phase_r3;
    logic [31:0] phase_r4;
    logic [31:0] phase_r5;
    logic [31:0] phase_0;
    logic [31:0] phase_0_r1;

    // Phase vectors.
    logic [31:0] phase_v0    [N_DDS];
    logic [31:0] phase_v0_r1 [N_DDS];
    logic [31:0] phase_v0_r2 [N_DDS];
    logic [31:0] phase_v0_r3 [N_DDS];
    logic [31:0] phase_v0_r4 [N_DDS];
    logic [31:0] phase_v1    [N_DDS];
    logic [31:0] phase_v1_r1 [N_DDS];

    // End of the sample count: max(nsamp, 3) - 2, at least 1 so that the
    // previous descriptor's value is never matched at cnt = 0.
    logic [15:0] cnt_end;

    // Output selection.
    logic [1:0] outsel_int;
    logic [1:0] outsel_r1;
    logic [1:0] outsel_r2;
    logic [1:0] outsel_r3;
    logic [1:0] outsel_r4;
    logic [1:0] outsel_r5;
    logic [1:0] outsel_r6;
    logic [1:0] outsel_r7;

    // Mode.
    logic mode_int;

    // Load enable flag.
    logic load_int;
    logic load_r1;
    logic load_r2;
    logic load_r3;
    logic load_r4;
    logic load_r5;
    logic load_r6;
    logic load_r7;
    logic load_r8;

    // Fifo Read Enable.
    logic rd_en_int;

    // Counter.
    logic [15:0] cnt;

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            state <= READ_ST;

            fifo_dout_r <= '0;

            cnt_n     <= '0;
            cnt_n_reg <= '0;

            pinc_r1 <= '0;
            pinc_r2 <= '0;
            pinc_n_r1 <= '0;
            pinc_n_r2 <= '0;
            pinc_n_r3 <= '0;
            pinc_n_r4 <= '0;
            pinc_n_r5 <= '0;
            pinc_nm_r1 <= '0;
            pinc_nm_r2 <= '0;
            pinc_nm_r3 <= '0;

            phase_r1 <= '0;
            phase_r2 <= '0;
            phase_r3 <= '0;
            phase_r4 <= '0;
            phase_r5 <= '0;
            phase_0_r1 <= '0;

            outsel_r1 <= '0;
            outsel_r2 <= '0;
            outsel_r3 <= '0;
            outsel_r4 <= '0;
            outsel_r5 <= '0;
            outsel_r6 <= '0;
            outsel_r7 <= '0;

            load_r1 <= 1'b0;
            load_r2 <= 1'b0;
            load_r3 <= 1'b0;
            load_r4 <= 1'b0;
            load_r5 <= 1'b0;
            load_r6 <= 1'b0;
            load_r7 <= 1'b0;
            load_r8 <= 1'b0;

            cnt <= '0;
            cnt_end <= 16'd1;
        end else begin
            // State register.
            case (state)
                READ_ST:
                    if (mode_int || !fifo_empty_i)
                        state <= CNT_ST;
                CNT_ST:
                    if (cnt == cnt_end)
                        state <= READ_ST;
                default:
                    state <= READ_ST;
            endcase

            // Fifo dout register.
            if (load_r1) begin
                fifo_dout_r <= fifo_dout_i;
                cnt_end     <= (fifo_dout_i[79:64] < 16'd3) ? 16'd1 : fifo_dout_i[79:64] - 16'd2;
            end

            // Non-stop counter for time calculation.
            cnt_n <= cnt_n + 32'(N_DDS);
            if (load_r2)
                cnt_n_reg <= cnt_n;

            // Pinc/phase.
            pinc_r1 <= pinc_int;
            pinc_r2 <= pinc_r1;
            pinc_n_r1 <= pinc_n;
            pinc_n_r2 <= pinc_n_r1;
            pinc_n_r3 <= pinc_n_r2;
            pinc_n_r4 <= pinc_n_r3;
            pinc_n_r5 <= pinc_n_r4;
            pinc_nm_r1 <= pinc_nm;
            pinc_nm_r2 <= pinc_nm_r1;
            pinc_nm_r3 <= pinc_nm_r2;

            phase_r1 <= phase_int;
            phase_r2 <= phase_r1;
            phase_r3 <= phase_r2;
            phase_r4 <= phase_r3;
            phase_r5 <= phase_r4;
            phase_0_r1 <= phase_0;

            // Output selection.
            outsel_r1 <= outsel_int;
            outsel_r2 <= outsel_r1;
            outsel_r3 <= outsel_r2;
            outsel_r4 <= outsel_r3;
            outsel_r5 <= outsel_r4;
            outsel_r6 <= outsel_r5;
            outsel_r7 <= outsel_r6;

            // Load enable flag.
            load_r1 <= load_int;
            load_r2 <= load_r1;
            load_r3 <= load_r2;
            load_r4 <= load_r3;
            load_r5 <= load_r4;
            load_r6 <= load_r5;
            load_r7 <= load_r6;
            load_r8 <= load_r7;

            // Counter.
            if (rd_en_int)
                cnt <= '0;
            else
                cnt <= cnt + 16'd1;
        end
    end

    // FSM outputs.
    always_comb begin
        rd_en_int = 1'b0;
        case (state)
            READ_ST: rd_en_int = 1'b1;
            CNT_ST:  rd_en_int = 1'b0;
            default: rd_en_int = 1'b0;
        endcase
    end

    // Fifo output fields.
    assign pinc_int   = fifo_dout_r[31:0];
    assign phase_int  = fifo_dout_r[63:32];
    assign outsel_int = fifo_dout_r[81:80];
    assign mode_int   = fifo_dout_r[82];

    // Frequency calculation.
    assign pinc_n = pinc_r2 * 32'(N_DDS);

    // Phase calculation.
    assign pinc_nm = pinc_r2 * cnt_n_reg;
    assign phase_0 = pinc_nm_r3 + phase_r5;

    // Phase vectors.
    for (genvar i = 0; i < N_DDS; i = i + 1) begin : g_phase
        always_ff @(posedge aclk) begin
            if (!aresetn) begin
                phase_v0_r1[i] <= '0;
                phase_v0_r2[i] <= '0;
                phase_v0_r3[i] <= '0;
                phase_v0_r4[i] <= '0;
                phase_v1_r1[i] <= '0;
            end else begin
                phase_v0_r1[i] <= phase_v0[i];
                phase_v0_r2[i] <= phase_v0_r1[i];
                phase_v0_r3[i] <= phase_v0_r2[i];
                phase_v0_r4[i] <= phase_v0_r3[i];
                phase_v1_r1[i] <= phase_v1[i];
            end
        end

        assign phase_v0[i] = pinc_r2 * 32'(i);
        assign phase_v1[i] = phase_v0_r4[i] + phase_0_r1;

        assign dds_ctrl_o[i*72+:72] = {7'h00, load_r8, phase_v1_r1[i], pinc_n_r5};
    end

    // load_int.
    assign load_int = rd_en_int & ~fifo_empty_i;

    // Assign outputs.
    assign fifo_rd_en_o = rd_en_int;
    assign outsel_o      = outsel_r7;

endmodule
