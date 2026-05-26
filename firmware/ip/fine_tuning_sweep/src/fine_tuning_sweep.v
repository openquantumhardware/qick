`timescale 1ns / 1ps
//------------------------------------------------------------------------------
// fine_tuning_sweep -- dual-clock top wrapper.
//
//   amplitude_calculator runs in the s_axis_aclk (ADC/readout-clock) domain.
//   peak_finder + QP2 opcode FSM run in the clk (c_clk / FPGA) domain.
//
// QP2 opcode map:
//   OP 0: dt1=nsamp                              -- one-time burst config
//   OP 1: dt1=current_freq                       -- freq for the upcoming TRIG
//   OP 2: IP-> dt1=freq_at_max dt2={31'd0,burst_done_sticky} -- poll burst done
//   OP 3: (no data)                              -- reset_max pulse
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
    // c_clk: rising-edge detect on qtag_en_i
    // =========================================================
    reg  en_d;
    wire en_rise = qtag_en_i & ~en_d;

    always @(posedge clk) begin
        if (!rst_n) en_d <= 1'b0;
        else        en_d <= qtag_en_i;
    end

    // Named strobes -- testbench accesses these via hierarchical reference
    wire set_current_freq_now = en_rise & (qtag_op_i == 5'd1);
    wire reset_max_now        = en_rise & (qtag_op_i == 5'd3);

    // =========================================================
    // c_clk: config registers + QP2 opcode FSM
    // =========================================================
    reg [31:0] reg_nsamp;

    wire [51:0] max_amplitude;
    wire [31:0] freq_at_max;

    always @(posedge clk) begin
        if (!rst_n) begin
            qtag_rdy_o <= 1'b1;
            qtag_vld_o <= 1'b0;
            qtag_dt1_o <= 32'd0;
            qtag_dt2_o <= 32'd0;
            reg_nsamp  <= 32'd256;
        end else begin
            qtag_vld_o <= 1'b0;
            if (en_rise) begin
                case (qtag_op_i)
                    5'd0: reg_nsamp <= qtag_dt1_i;
                    5'd1: ; // set_current_freq_now pulse drives peak_finder directly
                    5'd2: begin
                        qtag_dt1_o <= freq_at_max;
                        qtag_dt2_o <= {31'd0, burst_done_sticky};
                        qtag_vld_o <= 1'b1;
                    end
                    5'd3: ; // reset_max_now pulse drives peak_finder directly
                    default: ;
                endcase
            end
        end
    end

    // =========================================================
    // CDC: c_clk -> s_axis_aclk
    // =========================================================
    localparam AVG_BITS = $clog2(MAX_AVG);

    wire [31:0]          nsamp_ro;
    wire [AVG_BITS-1:0]  averager_value_ro = {AVG_BITS{1'b0}};
    wire                 trigger_ro;

    synchronizer #(.WIDTH(32)) u_sync_nsamp (
        .clk   (s_axis_aclk),
        .rst_n (s_axis_aresetn),
        .d_in  (reg_nsamp),
        .d_out (nsamp_ro)
    );

    synchronizer_pulse u_trig_cdc (
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
    // CDC: s_axis_aclk -> c_clk  (amplitude data + burst-done pulse)
    // =========================================================
    wire [51:0] amp_data_c;
    wire        amp_valid_c;
    wire        burst_done_c;

    synchronizer_pulse u_burst_cdc (
        .clk_src  (s_axis_aclk),
        .rst_n_src(s_axis_aresetn),
        .clk_dst  (clk),
        .rst_n_dst(rst_n),
        .p_in     (burst_done_ro),
        .p_out    (burst_done_c)
    );

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
    // c_clk: burst_done sticky flag
    //   - cleared by OP 1 (set_current_freq_now) at the START of each step
    //   - set by burst_done_c when amplitude_calculator finishes
    //   Clearing on OP 1 (not OP 2) avoids any race between the clear and
    //   burst_done_c: by the time the next OP 1 fires the current burst is
    //   already confirmed done and burst_done_c is long gone.
    // =========================================================
    reg burst_done_sticky;

    always @(posedge clk) begin
        if (!rst_n)
            burst_done_sticky <= 1'b0;
        else if (set_current_freq_now)
            burst_done_sticky <= 1'b0;
        else if (burst_done_c)
            burst_done_sticky <= 1'b1;
    end

    // =========================================================
    // c_clk: peak_finder (max-tracker)
    // =========================================================
    peak_finder #(
        .ACCUM_WIDTH (52)
    ) u_peak_finder_v2 (
        .clk             (clk),
        .rstn            (rst_n),
        .reset_max       (reset_max_now),
        .set_current_freq(set_current_freq_now),
        .current_freq_i  (qtag_dt1_i),   // valid on the cycle set_current_freq_now is high
        .amp_valid       (amp_valid_c),
        .amp_data        (amp_data_c),
        .max_amplitude   (max_amplitude),
        .freq_at_max     (freq_at_max)
    );

endmodule
