`timescale 1ns / 1ps
//------------------------------------------------------------------------------
// synchronizer.v -- Clock-domain-crossing primitives for the fine_tuning_sweep
// IP, matching how QICK's axis_avg_buffer handles CDC. Two modules:
//
//   synchronizer            -- 2-FF level synchronizer (ASYNC_REG), the SAME
//                              primitive as avg_buffer's synchronizer_n #(.N(2)).
//                              Used for the TRIGGER (crossed straight into the
//                              s_axis/ADC clock, then edge-detected by the
//                              consumer -- exactly like avg_buffer) and for
//                              quasi-static config (nsamp, averager_value, held
//                              stable for many destination cycles).
//   synchronizer_handshake  -- req/ack handshake carrying the single averaged
//                              |IQ|^2 result + valid from s_axis back to c_clk.
//                              (avg_buffer instead parks its capture ARRAY in a
//                              dual-clock BRAM; we push ONE scalar per point, so
//                              a handshake is the right equivalent.)
//
// All blocks use synchronous reset (`always @(posedge clk)` with `if (!rst_n)`)
// so they stay friendly to Vivado's synthesis. Reset values are zero.
//
// NOTE: the old toggle-based `synchronizer_pulse` was removed -- with the
// avg_buffer-style level sync the trigger no longer makes a c_clk hop, so a
// pulse CDC is no longer needed (avg_buffer has none either).
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
    // ack_dst is driven on the dst side below but read on the src side; declare
    // it up here so strict analyzers (xsim/xvlog) don't flag a forward use.
    reg ack_dst;

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

    // ---- dst side ----  (ack_dst declared above)
    (* ASYNC_REG = "TRUE" *) reg req_s0;
    (* ASYNC_REG = "TRUE" *) reg req_s1;
    reg                       req_s2;

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
