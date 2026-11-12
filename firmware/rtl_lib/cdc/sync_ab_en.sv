///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : sync_ab_en
// Project: QICK
///////////////////////////////////////////////////////////////////////////////
//! @file    sync_ab_en.sv
//!
//! @brief   Free-running two-phase CDC handshake that pulses `a_en_o` and
//! `b_en_o` back to back, once per full request/ack round trip
//! between the two clock domains.
//!
//! @details
//!
//! Faithful port of `sync_ab_en` (firmware/ip/qick_processor/src/_qproc_ips.sv),
//! whose only instance in the original is `qproc_ctrl`'s `sync_ab_en_inst`,
//! used to periodically pulse a "latch the absolute time counter" enable in
//! both the AXI-config clock domain (a = c_clk) and the tProcessor clock
//! domain (b = t_clk), so both sides sample the time counter at
//! approximately the same logical instant.
//!
//! Sequence: domain A raises a request, toggle-synchronized into domain B
//! (2-FF `ASYNC_REG` chain) produces one `b_en_o` pulse; domain B's ack is
//! toggle-synchronized back into domain A and produces one `a_en_o` pulse.
//! The cycle then restarts immediately (no external trigger) — this module
//! free-runs at a rate bounded by the round-trip CDC latency, not by any
//! parameter.
//!
//! @author  QICK Development Team
//!
//! @version 1.0
module sync_ab_en (
    input  logic clk_a_i,
    input  logic rst_a_ni,
    input  logic clk_b_i,
    input  logic rst_b_ni,
    output logic a_en_o,
    output logic b_en_o
);

    logic a_pulse_req;
    (* ASYNC_REG = "TRUE" *) logic a_pulse_req_cdc;
    (* ASYNC_REG = "TRUE" *) logic a_pulse_ack;
    (* ASYNC_REG = "TRUE" *) logic b_pulse_ack_cdc;
    (* ASYNC_REG = "TRUE" *) logic b_pulse_req;
    logic pulse_b_req_r;
    logic b_pulse_ack;
    logic pulse_a, pulse_b;

    // REQ: toggle a_pulse_req until acked by domain B (via a_pulse_ack)
    always_ff @(posedge clk_a_i or negedge rst_a_ni) begin
        if (!rst_a_ni) begin
            a_pulse_req <= 1'b0;
        end else begin
            if (a_pulse_ack)       a_pulse_req <= 1'b0;
            else if (!a_pulse_ack) a_pulse_req <= 1'b1;
        end
    end

    // Domain B: synchronize a_pulse_req in, generate one b_en_o pulse per toggle edge
    always_ff @(posedge clk_b_i) begin
        if (!rst_b_ni) begin
            a_pulse_req_cdc <= 1'b0;
            b_pulse_req     <= 1'b0;
            pulse_b_req_r   <= 1'b0;
        end else begin
            a_pulse_req_cdc <= a_pulse_req;
            b_pulse_req     <= a_pulse_req_cdc;
            pulse_b_req_r   <= b_pulse_req;
        end
    end

    assign pulse_b = b_pulse_req ^ pulse_b_req_r;

    // ACK: domain B acknowledges once it has seen the request
    always_ff @(posedge clk_b_i or negedge rst_b_ni) begin
        if (!rst_b_ni) begin
            b_pulse_ack <= 1'b0;
        end else begin
            if (b_pulse_req)       b_pulse_ack <= 1'b1;
            else if (!b_pulse_req) b_pulse_ack <= 1'b0;
        end
    end

    // Domain A: synchronize the ack back in, generate one a_en_o pulse per toggle edge
    always_ff @(posedge clk_a_i) begin
        if (!rst_a_ni) begin
            b_pulse_ack_cdc <= 1'b0;
            a_pulse_ack     <= 1'b0;
        end else begin
            b_pulse_ack_cdc <= b_pulse_ack;
            a_pulse_ack     <= b_pulse_ack_cdc;
        end
    end

    assign pulse_a = a_pulse_req ~^ a_pulse_ack;

    assign a_en_o = pulse_a;
    assign b_en_o = pulse_b;

endmodule
