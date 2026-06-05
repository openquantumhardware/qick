`timescale 1ns / 1ps
//------------------------------------------------------------------------------
// peak_finder -- autonomous single-pass sweep controller + argmax.
//
//   The IP owns the frequency grid. On OP1 (start) it walks
//       cur_freq = start_freq, start_freq+step, start_freq+2*step, ...
//   announcing each point to the tProc via (freq_word, freq_valid). The tProc
//   retunes the generator + readout DDC to freq_word and fires `averager_value`
//   triggers; amplitude_calculator integrates each trigger and accumulates the
//   bursts, emitting ONE averaged power (amp_valid) per point. peak_finder
//   compares that averaged power, keeps the running argmax, then advances.
//
//   Termination is whichever comes first:
//       point_idx + 1 >= n_points          (point-count budget)
//       cur_freq + step >= stop_freq        (end-frequency clamp)
//   On termination it parks freq_word = freq_at_max and pulses `finish`.
//
//   Two-pass (coarse then fine) is orchestrated by the host: run a pass, read
//   freq_at_max, reload start/stop/step/n_points for the fine window, run again.
//   This block does ONE pass per OP1 -- no internal coarse->fine transition.
//
//   freq_valid / finish are 1-cycle pulses; the wrapper makes them sticky so a
//   polling tProc can catch them over QP2.
//------------------------------------------------------------------------------

module peak_finder #(
    parameter ACCUM_WIDTH = 52
)(
    input  wire                   clk,
    input  wire                   rstn,

    // OP1: latch config + begin the sweep
    input  wire                   start,
    input  wire [31:0]            start_freq,   // freq_word (pinc) of point 0
    input  wire [31:0]            stop_freq,    // end-frequency clamp
    input  wire [31:0]            step,         // per-point increment
    input  wire [31:0]            n_points,     // point-count budget

    // OP3: clear running max while idle (optional; OP1 also clears)
    input  wire                   reset_max,

    // averaged power for the current point (from amplitude_calculator via CDC)
    input  wire                   amp_valid,
    input  wire [ACCUM_WIDTH-1:0] amp_data,

    // handshake to the tProc (wrapper latches these into sticky flags)
    (* mark_debug = "true" *) output reg  [31:0] freq_word,
    (* mark_debug = "true" *) output reg         freq_valid,
    (* mark_debug = "true" *) output reg         finish,

    // result (read back on OP2 via freq_word; max kept for the comparison)
    output reg  [ACCUM_WIDTH-1:0] max_amplitude,
    (* mark_debug = "true" *) output reg  [31:0] freq_at_max
);

    localparam IDLE      = 2'd0;
    localparam SEND_FREQ = 2'd1;
    localparam WAIT_MEAS = 2'd2;

    (* mark_debug = "true" *) reg [1:0]  state;
    (* mark_debug = "true" *) reg [31:0] cur_freq;
    reg [31:0] cur_stop;
    reg [31:0] cur_step;
    reg [31:0] n_pts;
    (* mark_debug = "true" *) reg [31:0] point_idx;

    // last-point test, evaluated on the cycle amp_valid lands
    wire last_point = (point_idx + 32'd1 >= n_pts) ||
                      (cur_freq + cur_step >= cur_stop);

    always @(posedge clk) begin
        if (!rstn) begin
            state         <= IDLE;
            freq_word     <= 32'd0;
            freq_valid    <= 1'b0;
            finish        <= 1'b0;
            max_amplitude <= {ACCUM_WIDTH{1'b0}};
            freq_at_max   <= 32'd0;
            cur_freq      <= 32'd0;
            cur_stop      <= 32'd0;
            cur_step      <= 32'd0;
            n_pts         <= 32'd0;
            point_idx     <= 32'd0;
        end else begin
            freq_valid <= 1'b0;   // default: pulses are 1 cycle
            finish     <= 1'b0;

            // standalone max clear -- only meaningful between passes (IDLE)
            if (reset_max && state == IDLE) begin
                max_amplitude <= {ACCUM_WIDTH{1'b0}};
                freq_at_max   <= 32'd0;
            end

            case (state)
            IDLE: begin
                if (start) begin
                    cur_freq      <= start_freq;
                    cur_stop      <= stop_freq;
                    cur_step      <= step;
                    n_pts         <= n_points;
                    point_idx     <= 32'd0;
                    max_amplitude <= {ACCUM_WIDTH{1'b0}};
                    freq_at_max   <= 32'd0;
                    state         <= SEND_FREQ;
                end
            end

            // announce the current point to the tProc
            SEND_FREQ: begin
                freq_word  <= cur_freq;
                freq_valid <= 1'b1;
                state      <= WAIT_MEAS;
            end

            // wait for the averaged power, compare, then advance or finish
            WAIT_MEAS: begin
                if (amp_valid) begin
                    if (amp_data > max_amplitude) begin
                        max_amplitude <= amp_data;
                        freq_at_max   <= cur_freq;
                    end

                    if (last_point) begin
                        // park the winning freq for the OP2 read (account for a
                        // last-point win, since freq_at_max updates this cycle)
                        freq_word <= (amp_data > max_amplitude) ? cur_freq
                                                               : freq_at_max;
                        finish    <= 1'b1;
                        state     <= IDLE;
                    end else begin
                        cur_freq  <= cur_freq + cur_step;
                        point_idx <= point_idx + 32'd1;
                        state     <= SEND_FREQ;
                    end
                end
            end
            endcase
        end
    end

endmodule
