`timescale 1ns / 1ps
//
// readout_capture.v
//
// Snoops the m1_axis output of axis_dyn_readout_v1 (32-bit packed I/Q on
// ro_clk = 307.2 MHz), gates by an external trigger, optionally counts a
// fixed window of N samples, and surfaces decoded I/Q on the c_clk domain
// (200 MHz) through an asynchronous BRAM FIFO.
//
// Snoop semantics: drives s_ro_axis_tready=1 always.  This means the
// upstream writer (the readout) is never back-pressured by us, so the
// existing avg_buffer consumer is unaffected.  The price is that if our
// FIFO ever fills up we silently drop samples -- size the FIFO so this
// can't happen for the configured n_samples.
//
// Two CDC paths:
//   arm_pulse        : c_clk -> ro_clk (level toggled into a Gray bit then
//                      synced; we synthesize a 1-cycle ro_clk pulse from a
//                      rising edge).
//   capture_done     : ro_clk -> c_clk (synced level then edge-detected).
//
// FIFO: xpm_fifo_async, 32-bit data, 64 deep, FWFT.  ~1 BRAM18.
//

module readout_capture #(
    parameter integer IQ_WIDTH         = 16,
    parameter integer FIFO_DEPTH_LOG2  = 6,           // 2^6 = 64
    parameter integer COUNT_WIDTH      = 16
)(
    // ----------- c_clk domain -----------
    input  wire                        clk,
    input  wire                        rst_n,

    // Capture control (from adaptive_sweep_control)
    input  wire                        arm_pulse,                 // 1-cycle pulse to start a window
    input  wire [COUNT_WIDTH-1:0]      n_samples,                 // window length
    output reg                         capture_done_o,            // sticky high until next arm

    // Decoded sample stream consumed by polyak_averager + iq_power
    output wire signed [IQ_WIDTH-1:0]  i_out,
    output wire signed [IQ_WIDTH-1:0]  q_out,
    output wire                        iq_valid,
    input  wire                        iq_ready,                  // back-pressure to consumers
    output wire [COUNT_WIDTH-1:0]      samples_remaining,

    // ----------- ro_clk domain -----------
    input  wire                        s_ro_axis_aclk,
    input  wire                        s_ro_axis_aresetn,
    input  wire        [2*IQ_WIDTH-1:0] s_ro_axis_tdata,           // {Q[15:0], I[15:0]}
    input  wire                        s_ro_axis_tvalid,
    output wire                        s_ro_axis_tready,          // tied to 1
    input  wire                        trigger_i                  // external trigger (ro_clk async)
);

    // ----------------------------------------------------------------
    //  c_clk -> ro_clk : arm_pulse to ro_clk-domain "armed" enable
    // ----------------------------------------------------------------
    // Implement as a toggle FF in c_clk; synchronize the toggle into
    // ro_clk; edge-detect the synchronized toggle into a 1-cycle ro_clk
    // pulse.  Standard XPM_CDC_PULSE pattern done by hand to keep the
    // module portable.
    reg arm_toggle_c;
    always @(posedge clk) begin
        if (!rst_n)         arm_toggle_c <= 1'b0;
        else if (arm_pulse) arm_toggle_c <= ~arm_toggle_c;
    end

    (* ASYNC_REG = "TRUE" *) reg arm_tog_sync_0, arm_tog_sync_1, arm_tog_sync_2;
    always @(posedge s_ro_axis_aclk) begin
        if (!s_ro_axis_aresetn) begin
            arm_tog_sync_0 <= 1'b0;
            arm_tog_sync_1 <= 1'b0;
            arm_tog_sync_2 <= 1'b0;
        end else begin
            arm_tog_sync_0 <= arm_toggle_c;
            arm_tog_sync_1 <= arm_tog_sync_0;
            arm_tog_sync_2 <= arm_tog_sync_1;
        end
    end
    wire arm_pulse_ro = arm_tog_sync_1 ^ arm_tog_sync_2;

    // ----------------------------------------------------------------
    //  c_clk -> ro_clk : n_samples (slow-changing config) -- 2-FF sync
    //  Safe to sync as a multibit because the value is only consumed
    //  when arm_pulse_ro fires, and arm_pulse_ro is at least 3 ro_clk
    //  cycles after n_samples is stable in c_clk.
    // ----------------------------------------------------------------
    (* ASYNC_REG = "TRUE" *) reg [COUNT_WIDTH-1:0] n_samples_sync_0, n_samples_sync_1;
    always @(posedge s_ro_axis_aclk) begin
        if (!s_ro_axis_aresetn) begin
            n_samples_sync_0 <= 0;
            n_samples_sync_1 <= 0;
        end else begin
            n_samples_sync_0 <= n_samples;
            n_samples_sync_1 <= n_samples_sync_0;
        end
    end

    // ----------------------------------------------------------------
    //  ro_clk side: trigger gate, sample counter, FIFO writes
    // ----------------------------------------------------------------
    reg                       armed_ro;
    reg [COUNT_WIDTH-1:0]     remaining_ro;
    reg                       trigger_d;
    wire                      trigger_rise = trigger_i & ~trigger_d;

    wire                      fifo_full;
    wire                      fifo_wr_en;

    // Write enable: armed AND tvalid AND not full.  If full, drop sample
    // (simulation will assert).
    assign fifo_wr_en = armed_ro & s_ro_axis_tvalid & ~fifo_full;
    assign s_ro_axis_tready = 1'b1;     // snoop never stalls writer

    always @(posedge s_ro_axis_aclk) begin
        if (!s_ro_axis_aresetn) begin
            armed_ro     <= 1'b0;
            remaining_ro <= 0;
            trigger_d    <= 1'b0;
        end else begin
            trigger_d <= trigger_i;

            // arm_pulse_ro loads the counter and arms (waits for trigger)
            if (arm_pulse_ro) begin
                armed_ro     <= 1'b0;        // not yet capturing
                remaining_ro <= n_samples_sync_1;
            end

            // Trigger starts capture only if a window is loaded
            if (trigger_rise && remaining_ro != 0) begin
                armed_ro <= 1'b1;
            end

            // While capturing, decrement on each accepted write
            if (armed_ro && fifo_wr_en) begin
                if (remaining_ro == 1) begin
                    armed_ro     <= 1'b0;     // last sample
                    remaining_ro <= 0;
                end else begin
                    remaining_ro <= remaining_ro - 1'b1;
                end
            end
        end
    end

    // capture_done_ro: pulse-toggle into c_clk for capture_done_o
    reg capture_done_tog_ro;
    always @(posedge s_ro_axis_aclk) begin
        if (!s_ro_axis_aresetn)
            capture_done_tog_ro <= 1'b0;
        else if (armed_ro && fifo_wr_en && remaining_ro == 1)
            capture_done_tog_ro <= ~capture_done_tog_ro;
    end

    (* ASYNC_REG = "TRUE" *) reg cap_done_sync_0, cap_done_sync_1, cap_done_sync_2;
    always @(posedge clk) begin
        if (!rst_n) begin
            cap_done_sync_0 <= 1'b0;
            cap_done_sync_1 <= 1'b0;
            cap_done_sync_2 <= 1'b0;
            capture_done_o  <= 1'b0;
        end else begin
            cap_done_sync_0 <= capture_done_tog_ro;
            cap_done_sync_1 <= cap_done_sync_0;
            cap_done_sync_2 <= cap_done_sync_1;
            // arm_pulse clears the sticky done flag
            if (arm_pulse) capture_done_o <= 1'b0;
            else if (cap_done_sync_1 ^ cap_done_sync_2) capture_done_o <= 1'b1;
        end
    end

    // ----------------------------------------------------------------
    //  Async FIFO  (xpm_fifo_async, 32 wide, 64 deep, FWFT)
    // ----------------------------------------------------------------
    wire [2*IQ_WIDTH-1:0] fifo_dout;
    wire                  fifo_empty;
    wire                  fifo_rd_en;

    assign fifo_rd_en = ~fifo_empty & iq_ready;

    xpm_fifo_async #(
        .CDC_SYNC_STAGES   (2),
        .DOUT_RESET_VALUE  ("0"),
        .ECC_MODE          ("no_ecc"),
        .FIFO_MEMORY_TYPE  ("block"),
        .FIFO_READ_LATENCY (0),                  // FWFT
        .FIFO_WRITE_DEPTH  (1 << FIFO_DEPTH_LOG2),
        .FULL_RESET_VALUE  (0),
        .READ_DATA_WIDTH   (2*IQ_WIDTH),
        .READ_MODE         ("fwft"),
        .RELATED_CLOCKS    (0),
        .USE_ADV_FEATURES  ("0000"),
        .WAKEUP_TIME       (0),
        .WRITE_DATA_WIDTH  (2*IQ_WIDTH),
        .WR_DATA_COUNT_WIDTH(1)
    ) u_fifo (
        .rst        (~s_ro_axis_aresetn),         // active high
        .wr_clk     (s_ro_axis_aclk),
        .wr_en      (fifo_wr_en),
        .din        (s_ro_axis_tdata),
        .full       (fifo_full),
        .rd_clk     (clk),
        .rd_en      (fifo_rd_en),
        .dout       (fifo_dout),
        .empty      (fifo_empty),
        // Unused
        .injectdbiterr(1'b0),
        .injectsbiterr(1'b0),
        .sleep        (1'b0),
        .almost_empty (), .almost_full (), .data_valid (),
        .dbiterr      (), .overflow    (), .prog_empty (),
        .prog_full    (), .rd_data_count(), .rd_rst_busy(),
        .sbiterr      (), .underflow   (), .wr_data_count(),
        .wr_rst_busy  ()
    );

    assign i_out    = fifo_dout[IQ_WIDTH-1:0];
    assign q_out    = fifo_dout[2*IQ_WIDTH-1:IQ_WIDTH];
    assign iq_valid = ~fifo_empty;

    // c_clk-side samples_remaining mirror (lossy view, for tProc status reads).
    // Snapshot at arm_pulse, decrement when sample is consumed downstream.
    reg [COUNT_WIDTH-1:0] remaining_c;
    always @(posedge clk) begin
        if (!rst_n) begin
            remaining_c <= 0;
        end else begin
            if (arm_pulse)              remaining_c <= n_samples;
            else if (fifo_rd_en && remaining_c != 0)
                                        remaining_c <= remaining_c - 1'b1;
        end
    end
    assign samples_remaining = remaining_c;

endmodule
