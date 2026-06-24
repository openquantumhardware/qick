`timescale 1ns / 1ps
//------------------------------------------------------------------------------
// synchronizer.v -- Clock-domain-crossing primitives for the fine_tuning_sweep
// IP. Three modules, each for ONE class of crossing:
//
//   synchronizer_n         -- avg_buffer's EXACT primitive (avg_buffer.v uses
//                             `synchronizer_n #(.N(2))`): N-deep 1-bit shift-reg
//                             level sync. Used for the TRIGGER (fpga clk -> adc
//                             clk): cross the 1-bit trigger into s_axis_aclk,
//                             edge-detect locally. 1-bit ONLY.
//
//   synchronizer           -- WIDTH-bit 2-FF level sync for QUASI-STATIC buses
//                             (nsamp / averager_value: written once via QP2 and
//                             held). Safe ONLY because the bus is stable when
//                             sampled (no bit-skew). NOT for live-changing data.
//
//   synchronizer_handshake -- req/ack handshake for the ACCUMULATED |IQ|^2 + its
//                             valid going adc clk -> fpga clk. This is the
//                             CORRECT way to move a MULTI-BIT value across clocks:
//                             only the 1-bit `req` toggle crosses through FFs;
//                             the wide data is latched on the source side and
//                             captured on the destination only after `req` has
//                             crossed, by which time the data has long settled --
//                             so there is no multi-bit bit-skew. (avg_buffer does
//                             the same job with a dual-clock BRAM; for one scalar
//                             per point a handshake is the lighter equivalent.)
//
// All blocks use synchronous reset and zero reset values.
//------------------------------------------------------------------------------


//------------------------------------------------------------------------------
// synchronizer_n -- avg_buffer's 1-bit N-deep shift-register level sync.
//------------------------------------------------------------------------------
module synchronizer_n #(parameter N = 2) (
    input  wire rstn,
    input  wire clk,
    input  wire data_in,
    output wire data_out
);
    (* ASYNC_REG = "TRUE" *) reg [N-1:0] data_int_reg;

    always @(posedge clk) begin
        if (!rstn) data_int_reg <= {N{1'b0}};
        else       data_int_reg <= {data_int_reg[N-2:0], data_in};
    end

    assign data_out = data_int_reg[N-1];
endmodule


//------------------------------------------------------------------------------
// synchronizer -- WIDTH-bit 2-FF level sync for QUASI-STATIC buses only.
// Caller MUST hold d_in stable across enough clk cycles for the FFs to settle.
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
// synchronizer_handshake -- transfers a wide data word + valid across clocks.
//
// src latches data + toggles req on valid_in (only when idle). dst 2-FF-syncs
// req, captures data on the req-toggle edge, emits a 1-cycle valid_out, and
// toggles ack back. src reads ack via its own 2-FF sync and returns to idle when
// ack matches req. Only the 1-bit req/ack cross through FFs; the data is sampled
// on the dst side ONLY when it is already stable (MCP handshake) -> no bit-skew.
//
// Throughput ~1 transfer per 6-8 cycles, which is fine: this carries one
// averaged |IQ|^2 per (nsamp*averager_value) ADC samples.
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
    // ack_dst is driven on the dst side but read on the src side; declare it up
    // here so strict analyzers (xsim/xvlog) don't flag a forward use.
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
