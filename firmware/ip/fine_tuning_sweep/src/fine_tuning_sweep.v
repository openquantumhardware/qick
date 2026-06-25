`timescale 1ns / 1ps
//------------------------------------------------------------------------------
// fine_tuning_sweep -- dual-clock top wrapper (autonomous sweep controller).
//
//   peak_finder (sweep FSM + argmax) + the QP2 opcode FSM run on `clk` (the
//   fpga/tProc clock, c_clk).  amplitude_calculator runs on `s_axis_aclk` (the
//   ADC/readout clock) where the IQ stream lives.
//
//   CDC -- each crossing uses the RIGHT primitive for its kind (see
//   synchronizer.v):
//     trigger              fpga_clk -> adc_clk : synchronizer_n (2-FF) + edge
//                          (1-bit; the IQ data is NOT synchronized -- it is born
//                           in adc_clk and consumed there by amplitude_calculator)
//     nsamp/averager_value fpga_clk -> adc_clk : synchronizer (quasi-static bus)
//     accumulated |IQ|^2   adc_clk -> fpga_clk : synchronizer_handshake (req/ack)
//                          -- the MULTI-BIT result crossing back: only the 1-bit
//                           req crosses through FFs; the data is captured while
//                           held, so there is no bit-skew. peak_finder consumes it.
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

    // tProc trigger pulse (generated in the tProc t_clk domain -- async here)
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
    (* mark_debug = "true" *) wire [51:0] max_amplitude;   // running max (argmax state, observable)
    (* mark_debug = "true" *) wire [31:0] freq_at_max;

    // diagnostic counters (declared here so the QP2 FSM / OP5 can read them;
    // driven further below). *_ro = adc clk (from amplitude_calculator),
    // *_c = crossed to clk_core for QP2 + ILA. See the diagnostic block below.
    wire [31:0] dbg_trig_cnt_ro, dbg_tvalid_cnt_ro, dbg_acc_cnt_ro, dbg_emit_cnt_ro;
    (* mark_debug = "true" *) wire [31:0] dbg_trig_cnt_c;
    (* mark_debug = "true" *) wire [31:0] dbg_tvalid_cnt_c;
    (* mark_debug = "true" *) wire [31:0] dbg_acc_cnt_c;
    (* mark_debug = "true" *) wire [31:0] dbg_emit_cnt_c;
    (* mark_debug = "true" *) reg  [31:0] dbg_ampc_cnt;

    // peak_finder internal taps (clk domain) + averager_value crossed BACK to
    // clk_core (quasi-static -> 2-FF exact) to confirm the c->adc avg crossing.
    (* mark_debug = "true" *) wire [1:0]  pf_dbg_state;
    (* mark_debug = "true" *) wire [31:0] pf_dbg_point_idx;
    (* mark_debug = "true" *) wire [31:0] pf_dbg_n_pts;
    (* mark_debug = "true" *) wire [31:0] pf_dbg_cur_step;
    (* mark_debug = "true" *) wire [31:0] pf_dbg_amp_seen;
    (* mark_debug = "true" *) wire [AVG_BITS-1:0] avg_ro_c;

    // sticky handshake flags (so a polling tProc never misses a 1-cycle pulse)
    (* mark_debug = "true" *) reg sticky_freq_valid;
    (* mark_debug = "true" *) reg sticky_finish;

    always @(posedge clk) begin
        if (!rst_n) begin
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
                    5'd5: begin
                        // diagnostic read (no side effects). dt1 selects:
                        //  data path : 0 trig_cnt 1 tvalid_cnt 2 acc_cnt 3 emit_cnt(adc) 4 amp_valid_c(fpga)
                        //  peak_finder: 5 state 6 point_idx 7 n_pts 8 cur_step
                        //  averager   : 9 averager_value(adc, crossed back) 10 reg_avg(clk, OP4)
                        //  decisive   : 11 amp_seen (every amp_valid peak_finder's input saw)
                        case (qtag_dt1_i[3:0])
                            4'd0:  qtag_dt1_o <= dbg_trig_cnt_c;
                            4'd1:  qtag_dt1_o <= dbg_tvalid_cnt_c;
                            4'd2:  qtag_dt1_o <= dbg_acc_cnt_c;
                            4'd3:  qtag_dt1_o <= dbg_emit_cnt_c;
                            4'd4:  qtag_dt1_o <= dbg_ampc_cnt;
                            4'd5:  qtag_dt1_o <= {30'd0, pf_dbg_state};
                            4'd6:  qtag_dt1_o <= pf_dbg_point_idx;
                            4'd7:  qtag_dt1_o <= pf_dbg_n_pts;
                            4'd8:  qtag_dt1_o <= pf_dbg_cur_step;
                            4'd9:  qtag_dt1_o <= {{(32-AVG_BITS){1'b0}}, avg_ro_c};
                            4'd10: qtag_dt1_o <= reg_avg;
                            4'd11: qtag_dt1_o <= pf_dbg_amp_seen;
                            default: qtag_dt1_o <= 32'd0;
                        endcase
                        qtag_dt2_o <= 32'd0;
                        qtag_vld_o <= 1'b1;
                    end
                    default: ;
                endcase
            end
        end
    end

    // sticky_freq_valid: set when peak_finder presents a new point; cleared when
    // the tProc consumes it via an OP2 read. Set wins on a coincidence.
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

    // qtag_rdy_o: "answer ready" the tProc waits on before the next sweep.
    // s_status bit_qpb_rdy (#h0400). reset=1 (idle), low on OP1, high on finish.
    always @(posedge clk) begin
        if (!rst_n)          qtag_rdy_o <= 1'b1;   // idle: ready for a command
        else if (start_now)  qtag_rdy_o <= 1'b0;   // sweep running: busy
        else if (pf_finish)  qtag_rdy_o <= 1'b1;   // sweep done: answer ready
    end

    // =========================================================
    // CDC fpga_clk -> adc_clk
    //   nsamp / averager_value : quasi-static buses -> synchronizer
    //   trigger (trig_0_o)     : 1-bit async -> synchronizer_n (2-FF) + edge,
    //                            EXACTLY like avg_buffer crosses its trigger
    //                            into the ADC clock. The IQ stream itself is
    //                            native to adc_clk and is NOT synchronized.
    // =========================================================
    wire [31:0]          nsamp_ro;
    wire [AVG_BITS-1:0]  averager_value_ro;

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

    wire trig_resync;
    synchronizer_n #(.N(2)) u_trig_sync (
        .clk      (s_axis_aclk),
        .rstn     (s_axis_aresetn),
        .data_in  (trigger),
        .data_out (trig_resync)
    );
    reg trig_resync_d;
    always @(posedge s_axis_aclk) begin
        if (!s_axis_aresetn) trig_resync_d <= 1'b0;
        else                 trig_resync_d <= trig_resync;
    end
    wire trigger_ro = trig_resync & ~trig_resync_d;   // one clean adc-clk pulse

    // =========================================================
    // adc_clk: amplitude_calculator
    //   averages `averager_value` bursts per point -> one accumulated |IQ|^2.
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
        .m_axis_tvalid  (amp_valid_ro),
        .dbg_trig_cnt   (dbg_trig_cnt_ro),
        .dbg_tvalid_cnt (dbg_tvalid_cnt_ro),
        .dbg_acc_cnt    (dbg_acc_cnt_ro),
        .dbg_emit_cnt   (dbg_emit_cnt_ro)
    );

    // =========================================================
    // CDC adc_clk -> fpga_clk: the ACCUMULATED |IQ|^2 + valid (req/ack handshake)
    //   This is the multi-bit result going back to the fpga clock. The handshake
    //   crosses only the 1-bit req/ack through FFs and captures the 52-bit data
    //   while it is held stable -> no bit-skew (a synchronizer would be WRONG
    //   here). avg_buffer uses a dual-clock BRAM for the same purpose.
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
    // Diagnostics: cross the adc-clk counters to clk_core for QP2 OP5.
    //   2-FF per 32-bit counter. A 2-FF sync is bit-exact ONLY when the source
    //   is STATIC -- which trig/acc/emit are at the read point: the host polls
    //   OP5 after the sweep loop, when triggers have stopped, so they are
    //   frozen. (tvalid_cnt free-runs if the readout streams continuously --
    //   read it only as zero-vs-nonzero, "is the stream alive".) Use the
    //   counters for the zero/nonzero SPLIT, not cycle-exact totals. The crossed
    //   copies live in clk_core (slow) -> mark_debug here is ILA-safe (an ILA
    //   would sample at clk_core, never the 552 MHz domain). Cumulative since
    //   rst_n (reload the bitstream for a clean absolute count; the split is
    //   valid regardless).
    // =========================================================
    synchronizer #(.WIDTH(32)) u_dbg_trig   (.clk(clk), .rst_n(rst_n), .d_in(dbg_trig_cnt_ro),   .d_out(dbg_trig_cnt_c));
    synchronizer #(.WIDTH(32)) u_dbg_tvalid (.clk(clk), .rst_n(rst_n), .d_in(dbg_tvalid_cnt_ro), .d_out(dbg_tvalid_cnt_c));
    synchronizer #(.WIDTH(32)) u_dbg_acc    (.clk(clk), .rst_n(rst_n), .d_in(dbg_acc_cnt_ro),    .d_out(dbg_acc_cnt_c));
    synchronizer #(.WIDTH(32)) u_dbg_emit   (.clk(clk), .rst_n(rst_n), .d_in(dbg_emit_cnt_ro),   .d_out(dbg_emit_cnt_c));

    // amp_valid AFTER the back-handshake, counted natively in clk_core. If
    // dbg_emit_cnt(adc) > 0 but THIS stays 0, the handshake is dropping/wedging.
    always @(posedge clk) begin
        if (!rst_n)           dbg_ampc_cnt <= 32'd0;
        else if (amp_valid_c) dbg_ampc_cnt <= dbg_ampc_cnt + 32'd1;
    end

    // =========================================================
    // c_clk: peak_finder (sweep FSM + argmax) -- consumes the handshaked result
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
        .freq_at_max   (freq_at_max),
        .dbg_state     (pf_dbg_state),
        .dbg_point_idx (pf_dbg_point_idx),
        .dbg_n_pts     (pf_dbg_n_pts),
        .dbg_cur_step  (pf_dbg_cur_step),
        .dbg_amp_seen  (pf_dbg_amp_seen)
    );

    // averager_value (adc clk) crossed BACK to clk_core for OP5 sel 9 -- lets
    // SW compare the adc-side value against reg_avg (sel 10) to confirm the
    // c->adc averager crossing (quasi-static -> 2-FF is bit-exact).
    synchronizer #(.WIDTH(AVG_BITS)) u_dbg_avg (
        .clk(clk), .rst_n(rst_n), .d_in(averager_value_ro), .d_out(avg_ro_c));

endmodule
