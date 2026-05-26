`timescale 1ns / 1ps
//------------------------------------------------------------------------------
// synchronizer.v -- Clock-domain-crossing primitives for the fine_tuning_sweep
// IP. Three modules:
//
//   synchronizer            -- 2-FF synchronizer for slow-changing multi-bit
//                              signals (e.g. nsamp, averager_value held stable
//                              for many destination cycles).
//   synchronizer_pulse      -- toggle-based pulse CDC (single 1-cycle source
//                              pulse -> single 1-cycle dest pulse).
//   synchronizer_handshake  -- req/ack handshake for wide data + valid
//                              (one transfer per nsamp*averager_value burst).
//
// All blocks use synchronous reset (`always @(posedge clk)` with `if (!rst_n)`)
// so they stay friendly to Vivado's synthesis. Reset values are zero.
//------------------------------------------------------------------------------


//------------------------------------------------------------------------------
// 2-FF synchronizer for slow-changing multi-bit signals.
//
// Caller MUST hold d_in stable across enough clk cycles for the 2 FFs to
// settle (true for nsamp / averager_value which are written once via QP2 and
// held). Do not feed pulses through this -- use synchronizer_pulse instead.
//------------------------------------------------------------------------------
module synchronizer #(parameter WIDTH = 1) (
    input  wire             clk,
    input  wire             rst_n,
    input  wire [WIDTH-1:0] d_in,
    output wire [WIDTH-1:0] d_out
);
    (* ASYNC_REG = "TRUE" *) reg [WIDTH-1:0] s0;
    (* ASYNC_REG = "TRUE" *) reg [WIDTH-1:0] s1;

    always @(posedge clk) begin
        if (!rst_n) begin
            s0 <= {WIDTH{1'b0}};
            s1 <= {WIDTH{1'b0}};
        end else begin
            s0 <= d_in;
            s1 <= s0;
        end
    end

    assign d_out = s1;
endmodule


//------------------------------------------------------------------------------
// Pulse CDC: toggle on each input pulse on src side, 2-FF sync on dst side,
// edge-detect to recover a one-cycle pulse.
//
// Assumes p_in is a single-src-cycle pulse (true for tProc trig_X_o and for
// amplitude_calculator's one_burst_done). Total latency: ~3 dst cycles.
//------------------------------------------------------------------------------
module synchronizer_pulse (
    input  wire clk_src,
    input  wire rst_n_src,
    input  wire clk_dst,
    input  wire rst_n_dst,
    input  wire p_in,
    output reg  p_out
);
    reg tog_src;
    always @(posedge clk_src) begin
        if (!rst_n_src) tog_src <= 1'b0;
        else if (p_in)  tog_src <= ~tog_src;
    end

    (* ASYNC_REG = "TRUE" *) reg tog_s0;
    (* ASYNC_REG = "TRUE" *) reg tog_s1;
    reg                       tog_s2;

    always @(posedge clk_dst) begin
        if (!rst_n_dst) begin
            tog_s0 <= 1'b0;
            tog_s1 <= 1'b0;
            tog_s2 <= 1'b0;
            p_out  <= 1'b0;
        end else begin
            tog_s0 <= tog_src;
            tog_s1 <= tog_s0;
            tog_s2 <= tog_s1;
            p_out  <= tog_s1 ^ tog_s2;
        end
    end
endmodule


//------------------------------------------------------------------------------
// Handshake CDC: transfers a wide data word + valid pulse across clock
// domains.
//
// src latches data + toggles req on valid_in (only when idle). dst 2-FF-syncs
// req, captures data on the req-toggle edge, emits a 1-cycle valid_out, and
// toggles ack back. src reads ack via its own 2-FF sync and returns to idle
// when ack matches req.
//
// Throughput limited to ~1 sample per 6-8 cycles total, which is fine: the
// amplitude pulse this carries is emitted once per (nsamp*averager_value) ADC
// samples. Total latency: ~5-6 dst cycles.
//------------------------------------------------------------------------------
module synchronizer_handshake #(parameter WIDTH = 64) (
    input  wire             clk_src,
    input  wire             rst_n_src,
    input  wire             clk_dst,
    input  wire             rst_n_dst,
    input  wire             valid_in,
    input  wire [WIDTH-1:0] data_in,
    output reg              valid_out,
    output reg  [WIDTH-1:0] data_out
);
    // ---- src side ----
    reg              req_src;
    reg  [WIDTH-1:0] data_latch;
    (* ASYNC_REG = "TRUE" *) reg ack_s0;
    (* ASYNC_REG = "TRUE" *) reg ack_s1;
    wire src_idle = (req_src == ack_s1);

    always @(posedge clk_src) begin
        if (!rst_n_src) begin
            req_src    <= 1'b0;
            data_latch <= {WIDTH{1'b0}};
            ack_s0     <= 1'b0;
            ack_s1     <= 1'b0;
        end else begin
            ack_s0 <= ack_dst;
            ack_s1 <= ack_s0;
            if (valid_in && src_idle) begin
                req_src    <= ~req_src;
                data_latch <= data_in;
            end
        end
    end

    // ---- dst side ----
    (* ASYNC_REG = "TRUE" *) reg req_s0;
    (* ASYNC_REG = "TRUE" *) reg req_s1;
    reg                       req_s2;
    reg                       ack_dst;

    wire req_edge = (req_s1 ^ req_s2);

    always @(posedge clk_dst) begin
        if (!rst_n_dst) begin
            req_s0    <= 1'b0;
            req_s1    <= 1'b0;
            req_s2    <= 1'b0;
            ack_dst   <= 1'b0;
            valid_out <= 1'b0;
            data_out  <= {WIDTH{1'b0}};
        end else begin
            req_s0    <= req_src;
            req_s1    <= req_s0;
            req_s2    <= req_s1;
            valid_out <= req_edge;
            if (req_edge) begin
                data_out <= data_latch;
                ack_dst  <= req_s1;
            end
        end
    end
endmodule
