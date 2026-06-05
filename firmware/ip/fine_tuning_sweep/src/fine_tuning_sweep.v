`timescale 1ns / 1ps
//------------------------------------------------------------------------------
// fine_tuning_sweep -- dual-clock top wrapper (autonomous sweep controller).
//
//   amplitude_calculator runs in the s_axis_aclk (ADC/readout-clock) domain.
//   peak_finder (sweep FSM + argmax) + QP2 opcode FSM run in the clk (c_clk)
//   domain.
//
//   The IP owns the frequency grid. It announces each point to the tProc; the
//   tProc retunes the generator + readout DDC and fires `averager_value`
//   triggers per point. One averaged power comes back per point and feeds the
//   argmax. See peak_finder.v for the FSM.
//
// QP2 opcode map:
//   OP 0: dt1=start_freq dt2=stop_freq dt3=step dt4=nsamp   -- sweep config
//   OP 4: dt1=n_points   dt2=averager_value                 -- sweep config
//   OP 1: (no data)                                         -- start the sweep
//   OP 2: IP-> dt1=freq_word dt2={30'd0,freq_valid,finish}  -- poll handshake
//   OP 3: (no data)                                         -- reset_max pulse
//
//   OP2.dt2 bit0 = finish (sweep complete; dt1 = freq_at_max)
//   OP2.dt2 bit1 = freq_valid (a new point is ready; dt1 = its freq_word)
//
//   tProc loop:  poll OP2 -> if finish: done (read dt1)
//                          -> if freq_valid: retune gen+DDC to dt1,
//                             fire averager_value triggers, poll again
//------------------------------------------------------------------------------

module fine_tuning_sweep #(
    parameter MAX_AVG = 64
)(
    // ---- c_clk domain ----
    input  wire        clk,
    input  wire        rst_n,

    // QP2 (c_clk)
    input  wire        qtag_en_i,
    (* mark_debug = "true" *) input  wire [4:0]  qtag_op_i,
    input  wire [31:0] qtag_dt1_i,
    input  wire [31:0] qtag_dt2_i,
    input  wire [31:0] qtag_dt3_i,
    input  wire [31:0] qtag_dt4_i,
    output reg         qtag_rdy_o,
    (* mark_debug = "true" *) output reg  [31:0] qtag_dt1_o,
    (* mark_debug = "true" *) output reg  [31:0] qtag_dt2_o,
    (* mark_debug = "true" *) output reg         qtag_vld_o,

    // tProc trigger pulse (c_clk) -- one per burst, averager_value per point
    (* mark_debug = "true" *) input  wire        trigger,

    // ---- s_axis_aclk (ro_clk) domain ----
    input  wire        s_axis_aclk,
    input  wire        s_axis_aresetn,
    input  wire        s_axis_tvalid,
    input  wire [31:0] s_axis_tdata
);

    localparam AVG_BITS = $clog2(MAX_AVG);

    // =========================================================
    // c_clk: rising-edge detect on qtag_en_i
    // =========================================================
    reg  en_d;
    (* mark_debug = "true" *) wire en_rise = qtag_en_i & ~en_d;

    always @(posedge clk) begin
        if (!rst_n) en_d <= 1'b0;
        else        en_d <= qtag_en_i;
    end

    // Named strobes -- testbench accesses these via hierarchical reference
    wire start_now     = en_rise & (qtag_op_i == 5'd1);
    wire reset_max_now = en_rise & (qtag_op_i == 5'd3);
    wire op2_read      = en_rise & (qtag_op_i == 5'd2);

    // =========================================================
    // c_clk: config registers + QP2 opcode FSM
    // =========================================================
    reg [31:0] reg_start;
    reg [31:0] reg_stop;
    reg [31:0] reg_step;
    reg [31:0] reg_nsamp;
    reg [31:0] reg_npoints;
    reg [31:0] reg_avg;

    // from peak_finder (c_clk)
    (* mark_debug = "true" *) wire [31:0] pf_freq_word;
    (* mark_debug = "true" *) wire        pf_freq_valid;
    (* mark_debug = "true" *) wire        pf_finish;
    (* mark_debug = "true" *) wire [51:0] max_amplitude;   // running max -- argmax state, kept observable
    (* mark_debug = "true" *) wire [31:0] freq_at_max;

    // sticky handshake flags (so a polling tProc never misses a 1-cycle pulse)
    (* mark_debug = "true" *) reg sticky_freq_valid;
    (* mark_debug = "true" *) reg sticky_finish;

    always @(posedge clk) begin
        if (!rst_n) begin
            qtag_rdy_o  <= 1'b1;
            qtag_vld_o  <= 1'b0;
            qtag_dt1_o  <= 32'd0;
            qtag_dt2_o  <= 32'd0;
            reg_start   <= 32'd0;
            reg_stop    <= 32'hFFFFFFFF;
            reg_step    <= 32'd1;
            reg_nsamp   <= 32'd256;
            reg_npoints <= 32'd1;
            reg_avg     <= 32'd1;
        end else begin
            qtag_vld_o <= 1'b0;
            if (en_rise) begin
                case (qtag_op_i)
                    5'd0: begin
                        reg_start <= qtag_dt1_i;
                        reg_stop  <= qtag_dt2_i;
                        reg_step  <= qtag_dt3_i;
                        reg_nsamp <= qtag_dt4_i;
                    end
                    5'd4: begin
                        reg_npoints <= qtag_dt1_i;
                        reg_avg     <= qtag_dt2_i;
                    end
                    5'd1: ; // start_now pulse drives peak_finder directly
                    5'd2: begin
                        qtag_dt1_o <= pf_freq_word;
                        qtag_dt2_o <= {30'd0, sticky_freq_valid, sticky_finish};
                        qtag_vld_o <= 1'b1;
                    end
                    5'd3: ; // reset_max_now pulse drives peak_finder directly
                    default: ;
                endcase
            end
        end
    end

    // sticky_freq_valid: set when peak_finder presents a new point; cleared when
    // the tProc consumes it via an OP2 read. Set wins on a (rare) coincidence so
    // a point is never dropped.
    always @(posedge clk) begin
        if (!rst_n)              sticky_freq_valid <= 1'b0;
        else if (pf_freq_valid)  sticky_freq_valid <= 1'b1;
        else if (op2_read)       sticky_freq_valid <= 1'b0;
    end

    // sticky_finish: set when the sweep completes; cleared when the next sweep
    // starts (OP1). Survives any number of OP2 polls in between.
    always @(posedge clk) begin
        if (!rst_n)            sticky_finish <= 1'b0;
        else if (pf_finish)    sticky_finish <= 1'b1;
        else if (start_now)    sticky_finish <= 1'b0;
    end

    // =========================================================
    // CDC: c_clk -> s_axis_aclk  (nsamp, averager_value, trigger)
    // =========================================================
    wire [31:0]          nsamp_ro;
    wire [AVG_BITS-1:0]  averager_value_ro;
    wire                 trigger_ro;

    synchronizer #(.WIDTH(32)) u_sync_nsamp (
        .clk   (s_axis_aclk),
        .rst_n (s_axis_aresetn),
        .d_in  (reg_nsamp),
        .d_out (nsamp_ro)
    );

    synchronizer #(.WIDTH(AVG_BITS)) u_sync_avg (
        .clk   (s_axis_aclk),
        .rst_n (s_axis_aresetn),
        .d_in  (reg_avg[AVG_BITS-1:0]),
        .d_out (averager_value_ro)
    );

    // trig_0_o from the tProc is held high for ~10 tProc cycles, but
    // synchronizer_pulse expects a single-cycle pulse. Rising-edge-detect on
    // clk so the CDC -- and the amplitude_calculator re-arm -- see exactly one
    // pulse per trigger.
    reg trig_d;
    always @(posedge clk) begin
        if (!rst_n) trig_d <= 1'b0;
        else        trig_d <= trigger;
    end
    wire trigger_pulse = trigger & ~trig_d;

    synchronizer_pulse u_trig_cdc (
        .clk_src  (clk),
        .rst_n_src(rst_n),
        .clk_dst  (s_axis_aclk),
        .rst_n_dst(s_axis_aresetn),
        .p_in     (trigger_pulse),
        .p_out    (trigger_ro)
    );

    // =========================================================
    // s_axis_aclk: amplitude_calculator
    //   averages `averager_value` bursts per point -> one m_axis beat per point.
    // =========================================================
    wire [51:0] amp_data_ro;
    wire        amp_valid_ro;

    amplitude_calculator #(
        .MAX_AVG     (MAX_AVG),
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
        .m_axis_tvalid  (amp_valid_ro)
    );

    // =========================================================
    // CDC: s_axis_aclk -> c_clk  (averaged amplitude data + valid)
    // =========================================================
    (* mark_debug = "true" *) wire [51:0] amp_data_c;
    (* mark_debug = "true" *) wire        amp_valid_c;

    synchronizer_handshake #(.WIDTH(52)) u_amp_cdc (
        .clk_src  (s_axis_aclk),
        .rst_n_src(s_axis_aresetn),
        .clk_dst  (clk),
        .rst_n_dst(rst_n),
        .valid_in (amp_valid_ro),
        .data_in  (amp_data_ro),
        .valid_out(amp_valid_c),
        .data_out (amp_data_c)
    );

    // =========================================================
    // c_clk: peak_finder (autonomous sweep FSM + argmax)
    // =========================================================
    peak_finder #(
        .ACCUM_WIDTH (52)
    ) u_peak_finder_v2 (
        .clk           (clk),
        .rstn          (rst_n),

        .start         (start_now),
        .start_freq    (reg_start),
        .stop_freq     (reg_stop),
        .step          (reg_step),
        .n_points      (reg_npoints),

        .reset_max     (reset_max_now),

        .amp_valid     (amp_valid_c),
        .amp_data      (amp_data_c),

        .freq_word     (pf_freq_word),
        .freq_valid    (pf_freq_valid),
        .finish        (pf_finish),

        .max_amplitude (max_amplitude),
        .freq_at_max   (freq_at_max)
    );

endmodule
