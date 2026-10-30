`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : ctrl_sgmux8
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    ctrl_sgmux8.sv
//!
//! @brief   Waveform-descriptor sequencer for axis_sg_mux8_v1.
//!
//! @details
//! Reads one 40-bit waveform descriptor per envelope from the mask FIFO:
//!
//! | bits      | field | width | meaning                              |
//! |-----------|-------|-------|--------------------------------------|
//! | 39 .. 32  | mask  |   8   | per-channel enable mask               |
//! | 31 .. 0   | nsamp |  32   | number of output samples to play      |
//!
//! FSM: READ_ST (wait for a descriptor, pop it when fifo_empty_i is low) ->
//! CNT0_ST (one bubble cycle for the descriptor register to settle) ->
//! CNT_ST (drive mask_o/en_o for nsamp+1 cycles, counting cnt up from 0
//! until it equals nsamp) -> back to READ_ST.
//!
//! en_o is only updated while in READ_ST (dangling-else binds to the inner
//! `if (!fifo_empty_i)` in the legacy Verilog -- preserved here explicitly):
//! it is set high if a descriptor was available, low otherwise, and HELD at
//! that value through CNT0_ST/CNT_ST so it stays asserted for the whole
//! playback.
//!
//! mask_o/en_o are pipelined 2/3 cycles respectively (delay_line, replaces
//! the legacy latency_reg) to align with sg_mux8's DDS + adder-tree latency.
//!
//! @author  QICK Development Team
//!
//! @version 1.0
///////////////////////////////////////////////////////////////////////////////
module ctrl_sgmux8 (
    input  logic        rstn,          //! Synchronous active-low reset.
    input  logic        clk,           //! Clock.

    // Fifo interface.
    output logic        fifo_rd_en_o,  //! Fifo read enable (pop).
    input  logic        fifo_empty_i,  //! Fifo empty flag.
    input  logic [39:0] fifo_dout_i,   //! Fifo output: {mask, nsamp}.

    // Mask output.
    output logic [7:0]  mask_o,        //! Per-channel enable mask, latency 2.

    // Output enable.
    output logic         en_o          //! Output enable, latency 3.
);

    typedef enum logic [1:0] {
        READ_ST,
        CNT0_ST,
        CNT_ST
    } state_t;

    (* fsm_encoding = "one_hot" *) state_t state;

    logic        rd_en_int;
    logic        load_int;

    // Fifo dout register.
    logic [39:0] fifo_dout_r;

    // Number of samples / mask.
    logic [31:0] nsamp_int;
    logic [7:0]  mask_int;
    logic [7:0]  mask_la;

    // Counter.
    logic [31:0] cnt;

    // Output enable register.
    logic        en_reg;
    logic        en_reg_la;

    // Load register.
    logic        load_r;

    // Latency for mask.
    delay_line #(
        .N (2),
        .M (8)
    ) mask_delay_i (
        .i_clk  (clk),
        .i_rstn (rstn),
        .i_data (mask_int),
        .o_data (mask_la)
    );

    // Latency for en_reg.
    delay_line #(
        .N (3),
        .M (1)
    ) en_reg_delay_i (
        .i_clk  (clk),
        .i_rstn (rstn),
        .i_data (en_reg),
        .o_data (en_reg_la)
    );

    always_ff @(posedge clk) begin
        if (!rstn) begin
            // State register.
            state <= READ_ST;

            // Fifo dout register.
            fifo_dout_r <= '0;

            // Counter.
            cnt <= '0;

            // Output enable register.
            en_reg <= 1'b0;

            // Load enable flag.
            load_r <= 1'b0;
        end else begin
            // State register.
            case (state)
                READ_ST:
                    if (!fifo_empty_i)
                        state <= CNT0_ST;

                CNT0_ST:
                    state <= CNT_ST;

                CNT_ST:
                    if (cnt == nsamp_int)
                        state <= READ_ST;

                default:
                    state <= READ_ST;
            endcase

            // Fifo dout register.
            if (load_r)
                fifo_dout_r <= fifo_dout_i;

            // Load enable flag.
            load_r <= load_int;

            // Counter.
            if (rd_en_int)
                cnt <= '0;
            else
                cnt <= cnt + 32'd1;

            // Output enable register: only updated in READ_ST (matches the
            // legacy dangling-else binding to the inner `if`), held
            // through CNT0_ST/CNT_ST otherwise.
            if (rd_en_int) begin
                if (!fifo_empty_i)
                    en_reg <= 1'b1;
                else
                    en_reg <= 1'b0;
            end
        end
    end

    // FSM outputs.
    always_comb begin
        rd_en_int = 1'b0;

        case (state)
            READ_ST:  rd_en_int = 1'b1;
            CNT0_ST:  rd_en_int = 1'b0;
            CNT_ST:   rd_en_int = 1'b0;
            default:  rd_en_int = 1'b0;
        endcase
    end

    // Fifo output fields.
    assign nsamp_int = fifo_dout_r[31:0];
    assign mask_int  = fifo_dout_r[39:32];

    // load_int.
    assign load_int = rd_en_int & ~fifo_empty_i;

    // Outputs.
    assign fifo_rd_en_o = rd_en_int;
    assign mask_o        = mask_la;
    assign en_o          = en_reg_la;

endmodule
