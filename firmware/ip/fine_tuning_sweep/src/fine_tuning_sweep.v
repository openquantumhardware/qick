`timescale 1ns / 1ps
//------------------------------------------------------------------------------
// fine_tuning_sweep -- dual-clock top wrapper.
//
//   amplitude_calculator runs in the s_axis_aclk (ADC/readout-clock) domain so
//   snooped IQ samples are integrated natively, without per-sample CDC.
//
//   peak_finder + QP2 opcode FSM run in the clk (c_clk / FPGA) domain so they
//   stay aligned with the tProc.
//
//   CDCs between them:
//     trigger          : clk  -> s_axis_aclk    (pulse, toggle-sync)
//     reg_nsamp        : clk  -> s_axis_aclk    (slow level, 2-FF sync)
//     reg_averager_val : clk  -> s_axis_aclk    (slow level, 2-FF sync)
//     amplitude_data   : s_axis_aclk -> clk     (data + valid, handshake)
//     one_burst_done   : s_axis_aclk -> clk     (pulse, toggle-sync)
//
// QP2 opcode map (5-bit, latched on rising edge of qtag_en_i):
//   OP 0: dt1=start_freq dt2=stop_freq dt3=averager_value dt4=first_sweep_step
//   OP 1: start (w_start_pulse) -- clears sticky_finish/sticky_freq_valid
//   OP 2: read  -> dt1_o=freq_word  dt2_o={30'b0, sticky_freq_valid, sticky_finish}
//                  -- auto-clears sticky_freq_valid
//   OP 3: dt2=second_sweep_step dt3=second_sweep_window
//   OP 4: dt1=nsamp                            <-- NEW (software-programmable)
//------------------------------------------------------------------------------

module fine_tuning_sweep #(
    parameter MAX_AVG = 64
)(
    // ---- c_clk domain ----
    input  wire        clk,
    input  wire        rst_n,

    // QP2 (c_clk)
    input  wire        qtag_en_i,
    input  wire [4:0]  qtag_op_i,
    input  wire [31:0] qtag_dt1_i,
    input  wire [31:0] qtag_dt2_i,
    input  wire [31:0] qtag_dt3_i,
    input  wire [31:0] qtag_dt4_i,
    output reg         qtag_rdy_o,
    output reg  [31:0] qtag_dt1_o,
    output reg  [31:0] qtag_dt2_o,
    output reg         qtag_vld_o,

    // tProc trigger pulse (c_clk)
    input  wire        trigger,

    // ---- s_axis_aclk (ro_clk) domain ----
    input  wire        s_axis_aclk,
    input  wire        s_axis_aresetn,
    input  wire        s_axis_tvalid,
    input  wire [31:0] s_axis_tdata
);

    // =========================================================
    // c_clk: QP2 opcode FSM, sticky flags, config registers
    // =========================================================
    reg sticky_finish;
    reg sticky_freq_valid;

    wire [31:0] freq_word;
    wire        freq_valid;
    wire        finish;

    reg  en_d;
    wire en_rise = qtag_en_i & ~en_d;

    reg [31:0]                 reg_start_freq;
    reg [31:0]                 reg_stop_freq;
    reg [$clog2(MAX_AVG)-1:0]  reg_averager_value;
    reg [31:0]                 reg_first_sweep_step;
    reg [31:0]                 reg_second_sweep_step;
    reg [31:0]                 reg_second_sweep_window;
    reg [31:0]                 reg_nsamp;     // NEW (OP 4)

    wire w_start_pulse = en_rise & (qtag_op_i == 5'd1);
    wire w_read_pulse  = en_rise & (qtag_op_i == 5'd2);

    always @(posedge clk) begin
        if (!rst_n) begin
            sticky_finish     <= 1'b0;
            sticky_freq_valid <= 1'b0;
        end else if (w_start_pulse) begin
            sticky_finish     <= 1'b0;
            sticky_freq_valid <= 1'b0;
        end else begin
            if (finish)            sticky_finish     <= 1'b1;
            if (freq_valid)        sticky_freq_valid <= 1'b1;
            else if (w_read_pulse) sticky_freq_valid <= 1'b0;
        end
    end

    always @(posedge clk) begin
        if (!rst_n) en_d <= 1'b0;
        else        en_d <= qtag_en_i;
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            qtag_rdy_o              <= 1'b1;
            qtag_vld_o              <= 1'b0;
            qtag_dt1_o              <= 32'd0;
            qtag_dt2_o              <= 32'd0;
            reg_start_freq          <= 32'd0;
            reg_stop_freq           <= 32'd0;
            reg_averager_value      <= 0;
            reg_first_sweep_step    <= 32'd0;
            reg_second_sweep_step   <= 32'd0;
            reg_second_sweep_window <= 32'd0;
            reg_nsamp               <= 32'd256;   // safe default until OP 4 writes it
        end else begin
            qtag_vld_o <= 1'b0;

            if (en_rise) begin
                case (qtag_op_i)
                    5'd0: begin
                        reg_start_freq       <= qtag_dt1_i;
                        reg_stop_freq        <= qtag_dt2_i;
                        reg_averager_value   <= qtag_dt3_i[$clog2(MAX_AVG)-1:0];
                        reg_first_sweep_step <= qtag_dt4_i;
                    end
                    5'd1: begin
                        // start: handled by w_start_pulse
                    end
                    5'd2: begin
                        qtag_dt1_o <= freq_word;
                        qtag_dt2_o <= {30'd0, sticky_freq_valid, sticky_finish};
                        qtag_vld_o <= 1'b1;
                    end
                    5'd3: begin
                        reg_second_sweep_step   <= qtag_dt2_i;
                        reg_second_sweep_window <= qtag_dt3_i;
                    end
                    5'd4: begin
                        reg_nsamp <= qtag_dt1_i;
                    end
                    default: ;
                endcase
            end
        end
    end

    // =========================================================
    // CDC: c_clk -> s_axis_aclk
    // =========================================================
    wire [31:0]                  nsamp_ro;
    wire [$clog2(MAX_AVG)-1:0]   averager_value_ro;
    wire                         trigger_ro;

    ftc_sync_array #(.WIDTH(32)) u_sync_nsamp (
        .clk   (s_axis_aclk),
        .rst_n (s_axis_aresetn),
        .d_in  (reg_nsamp),
        .d_out (nsamp_ro)
    );

    ftc_sync_array #(.WIDTH($clog2(MAX_AVG))) u_sync_avg (
        .clk   (s_axis_aclk),
        .rst_n (s_axis_aresetn),
        .d_in  (reg_averager_value),
        .d_out (averager_value_ro)
    );

    ftc_pulse_cdc u_trig_cdc (
        .clk_src  (clk),
        .rst_n_src(rst_n),
        .clk_dst  (s_axis_aclk),
        .rst_n_dst(s_axis_aresetn),
        .p_in     (trigger),
        .p_out    (trigger_ro)
    );

    // =========================================================
    // s_axis_aclk: amplitude_calculator
    // =========================================================
    wire [51:0] amp_data_ro;
    wire        amp_valid_ro;
    wire        burst_done_ro;

    amplitude_calculator #(
        .MAX_AVG     (64),
        .ACCUM_WIDTH (52)
    ) u_amplitude_calculator (
        .clk            (s_axis_aclk),
        .rst_n          (s_axis_aresetn),

        .s_axis_tvalid  (s_axis_tvalid),
        .s_axis_tdata   (s_axis_tdata),

        .trigger        (trigger_ro),
        .nsamp          (nsamp_ro),
        .averager_value (averager_value_ro),

        .m_axis_tdata   (amp_data_ro),
        .m_axis_tvalid  (amp_valid_ro),
        .one_burst_done (burst_done_ro)
    );

    // =========================================================
    // CDC: s_axis_aclk -> c_clk
    // =========================================================
    wire [51:0] amp_data_c;
    wire        amp_valid_c;
    wire        burst_done_c;

    ftc_data_handshake_cdc #(.WIDTH(52)) u_amp_cdc (
        .clk_src  (s_axis_aclk),
        .rst_n_src(s_axis_aresetn),
        .clk_dst  (clk),
        .rst_n_dst(rst_n),
        .valid_in (amp_valid_ro),
        .data_in  (amp_data_ro),
        .valid_out(amp_valid_c),
        .data_out (amp_data_c)
    );

    ftc_pulse_cdc u_burst_cdc (
        .clk_src  (s_axis_aclk),
        .rst_n_src(s_axis_aresetn),
        .clk_dst  (clk),
        .rst_n_dst(rst_n),
        .p_in     (burst_done_ro),
        .p_out    (burst_done_c)
    );

    // =========================================================
    // c_clk: peak_finder
    // =========================================================
    peak_finder #(
        .ADC_DAC_freq (64'd491520000),
        .MAX_AVG      (64),
        .ACCUM_WIDTH  (52)
    ) u_peak_finder_v2 (
        .clk                 (clk),
        .rstn                (rst_n),

        .start               (w_start_pulse),
        .start_freq          (reg_start_freq),
        .stop_freq            (reg_stop_freq),

        .first_sweep_step    (reg_first_sweep_step),
        .second_sweep_step   (reg_second_sweep_step),
        .second_sweep_window (reg_second_sweep_window),

        .amplitude_valid     (amp_valid_c),
        .amplitude_data      (amp_data_c),
        .one_sample_done     (burst_done_c),

        .freq_word           (freq_word),
        .freq_valid          (freq_valid),
        .finish              (finish)
    );

endmodule

//------------------------------------------------------------------------------
// 2-FF synchronizer for slow-changing multi-bit signals. Caller MUST hold d_in
// stable across enough clk_dst cycles for the sync to propagate (true here:
// nsamp / averager_value are written once via QP2 and held).
//------------------------------------------------------------------------------
module ftc_sync_array #(parameter WIDTH = 1) (
    input  wire             clk,
    input  wire             rst_n,
    input  wire [WIDTH-1:0] d_in,
    output wire [WIDTH-1:0] d_out
);
    (* ASYNC_REG = "TRUE" *) reg [WIDTH-1:0] s0;
    (* ASYNC_REG = "TRUE" *) reg [WIDTH-1:0] s1;

    always @(posedge clk or negedge rst_n) begin
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
// Assumes p_in is a single-src-cycle pulse (true for tProc trig_X_o and for
// amplitude_calculator's one_burst_done).
//------------------------------------------------------------------------------
module ftc_pulse_cdc (
    input  wire clk_src,
    input  wire rst_n_src,
    input  wire clk_dst,
    input  wire rst_n_dst,
    input  wire p_in,
    output reg  p_out
);
    reg tog_src;
    always @(posedge clk_src or negedge rst_n_src) begin
        if (!rst_n_src) tog_src <= 1'b0;
        else if (p_in)  tog_src <= ~tog_src;
    end

    (* ASYNC_REG = "TRUE" *) reg tog_s0;
    (* ASYNC_REG = "TRUE" *) reg tog_s1;
    reg                       tog_s2;

    always @(posedge clk_dst or negedge rst_n_dst) begin
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
// domains. src latches data + toggles req on valid_in (only when idle). dst
// 2-FF-syncs req, captures data on the req-toggle edge, emits a 1-cycle
// valid_out, and toggles ack back. src reads ack via its own 2-FF sync and
// returns to idle when ack matches req.
//
// Throughput limited to ~1 sample per 6-8 cycles total, which is fine: an
// amplitude pulse is emitted once per (nsamp x averager_value) ADC samples.
//------------------------------------------------------------------------------
module ftc_data_handshake_cdc #(parameter WIDTH = 64) (
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

    always @(posedge clk_src or negedge rst_n_src) begin
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

    always @(posedge clk_dst or negedge rst_n_dst) begin
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
