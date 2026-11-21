// ============================================================================
// File: weighted_buffer_tc00.sv
// Description: SVUnit testbench top-level for weighted_buffer.
//
//   matched_filter, avg_top and buffer_top each already have dedicated
//   testbenches (matched_filter's own multiply/latency correctness;
//   avg_top/buffer_top's arm/trigger/capture/readback). This testbench
//   focuses on what's NEW at the weighted_buffer composition level: a
//   weight loaded via s1_axis actually reaching the datapath (buf
//   readback shows the FILTERED product, not the raw input), and the
//   shared external trigger reaching avg_top/buffer_top through
//   matched_filter's own DSP-latency-compensated trigger_o.
// ============================================================================

`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module weighted_buffer_unit_test;

    import svunit_pkg::svunit_testcase;

    string name = "weighted_buffer_ut";
    svunit_testcase svunit_ut;

    localparam real CLOCK_FREQUENCY = 200e6;
    localparam int  N_AVG = 8;
    localparam int  N_BUF = 8;
    localparam int  N_WGT = 8;
    localparam int  B     = 16;

    // -------------------------------------------------------------------------
    // Clock & Reset (single clock domain: s_axis, s_axi and m_axis share the
    // same clock, matching avg_buffer's own TB)
    // -------------------------------------------------------------------------
    logic tb_clk  = 1'b0;
    logic tb_rstn = 1'b1;

    clk_gen #(.FREQ (CLOCK_FREQUENCY)) u_clk_gen (.i_enable(1'b1), .o_clk(tb_clk));

    // -------------------------------------------------------------------------
    // Interfaces
    // -------------------------------------------------------------------------
    axi4_stream_if #(.TDATA_WIDTH(2*B)) wgt_if (.aclk(tb_clk), .aresetn(tb_rstn));
    axi4_stream_if #(.TDATA_WIDTH(4*B)) m0_if  (.aclk(tb_clk), .aresetn(tb_rstn));
    axi4_stream_if #(.TDATA_WIDTH(2*B)) m1_if  (.aclk(tb_clk), .aresetn(tb_rstn));
    axi4_stream_if #(.TDATA_WIDTH(4*B)) m2_if  (.aclk(tb_clk), .aresetn(tb_rstn));

    // m2 is the register-readback stream and the DUT drives no tlast on it, by
    // design: weighted_buffer exposes no m2_axis_tlast port and leaves
    // avg_top's m1_axis_tlast unconnected (weighted_buffer.sv:201). Left
    // undriven it floats to X, and AXI4STREAM_ERRM_TLAST_X then fires the moment
    // a readback beat raises m2_if.tvalid. m2 has no framing for a consumer to
    // rely on either: qick_processor takes only tdata/tvalid off it. Tie it low
    // and leave the rest of the m2 checkers live.
    assign m2_if.tlast = 1'b0;

    // -------------------------------------------------------------------------
    // Discrete signals
    // -------------------------------------------------------------------------
    logic            tb_trigger       = 1'b0;
    logic            tb_s_axis_tvalid = 1'b0;
    logic [2*B-1:0]  tb_s_axis_tdata  = '0;
    logic            tb_s_axis_tready;

    logic               tb_avg_start_reg       = 1'b0;
    logic [N_AVG-1:0]   tb_avg_addr_reg        = '0;
    logic [31:0]        tb_avg_len_reg         = '0;
    logic               tb_avg_photon_mode_reg = 1'b0;
    logic [B-1:0]       tb_avg_h_thrsh_reg     = '0;
    logic [B-1:0]       tb_avg_l_thrsh_reg     = '0;
    logic               tb_avg_dr_start_reg    = 1'b0;
    logic [N_AVG-1:0]   tb_avg_dr_addr_reg     = '0;
    logic [N_AVG:0]     tb_avg_dr_len_reg      = '0;

    logic               tb_buf_start_reg    = 1'b0;
    logic [N_BUF-1:0]   tb_buf_addr_reg     = '0;
    logic [N_BUF-1:0]   tb_buf_len_reg      = '0;
    logic               tb_buf_dr_start_reg = 1'b0;
    logic [N_BUF-1:0]   tb_buf_dr_addr_reg  = '0;
    logic [N_BUF:0]     tb_buf_dr_len_reg   = '0;

    logic [N_WGT-1:0]   tb_wgt_dw_addr_reg  = '0;
    logic               tb_wgt_dw_start_reg = 1'b0;

    // -------------------------------------------------------------------------
    // Waveform dump
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("weighted_buffer.vcd");
        $dumpvars();
    end

    // -------------------------------------------------------------------------
    // Unit Under Test
    // -------------------------------------------------------------------------
    weighted_buffer #(
        .N_AVG (N_AVG),
        .N_BUF (N_BUF),
        .N_WGT (N_WGT),
        .B     (B)
    ) dut (
        .s_axis_aclk    (tb_clk),
        .s_axis_aresetn (tb_rstn),

        .s_axi_aclk    (tb_clk),
        .s_axi_aresetn (tb_rstn),

        .trigger (tb_trigger),

        .s1_axis_tvalid (wgt_if.tvalid),
        .s1_axis_tready (wgt_if.tready),
        .s1_axis_tdata  (wgt_if.tdata),

        .s_axis_tvalid (tb_s_axis_tvalid),
        .s_axis_tready (tb_s_axis_tready),
        .s_axis_tdata  (tb_s_axis_tdata),

        .m_axis_aclk    (tb_clk),
        .m_axis_aresetn (tb_rstn),

        .m0_axis_tvalid (m0_if.tvalid),
        .m0_axis_tready (m0_if.tready),
        .m0_axis_tdata  (m0_if.tdata),
        .m0_axis_tlast  (m0_if.tlast),

        .m1_axis_tvalid (m1_if.tvalid),
        .m1_axis_tready (m1_if.tready),
        .m1_axis_tdata  (m1_if.tdata),
        .m1_axis_tlast  (m1_if.tlast),

        .m2_axis_tvalid (m2_if.tvalid),
        .m2_axis_tready (m2_if.tready),
        .m2_axis_tdata  (m2_if.tdata),

        .avg_start_reg       (tb_avg_start_reg),
        .avg_addr_reg        (tb_avg_addr_reg),
        .avg_len_reg         (tb_avg_len_reg),
        .avg_photon_mode_reg (tb_avg_photon_mode_reg),
        .avg_h_thrsh_reg     (tb_avg_h_thrsh_reg),
        .avg_l_thrsh_reg     (tb_avg_l_thrsh_reg),
        .avg_dr_start_reg    (tb_avg_dr_start_reg),
        .avg_dr_addr_reg     (tb_avg_dr_addr_reg),
        .avg_dr_len_reg      (tb_avg_dr_len_reg),

        .buf_start_reg    (tb_buf_start_reg),
        .buf_addr_reg     (tb_buf_addr_reg),
        .buf_len_reg      (tb_buf_len_reg),
        .buf_dr_start_reg (tb_buf_dr_start_reg),
        .buf_dr_addr_reg  (tb_buf_dr_addr_reg),
        .buf_dr_len_reg   (tb_buf_dr_len_reg),

        .wgt_dw_addr_reg  (tb_wgt_dw_addr_reg),
        .wgt_dw_start_reg (tb_wgt_dw_start_reg)
    );

    // =========================================================================
    // Helper tasks
    // =========================================================================

    task automatic reset_dut();
        tb_rstn = 1'b0;
        repeat(4) @(posedge tb_clk);
        tb_rstn = 1'b1;
        // XPM_FIFO (fifo_async inside avg_top, XPM_FIFO_SYNC inside
        // bram_to_axis) needs a long wr_rst_busy/rd_rst_busy settle window.
        repeat(100) @(posedge tb_clk);
    endtask

    // Loads the SAME weight value across the first count table entries.
    task automatic load_constant_weight(input logic [2*B-1:0] value, input int count = 16);
        int i;
        tb_wgt_dw_addr_reg  = '0;
        tb_wgt_dw_start_reg = 1'b1;
        repeat(4) @(posedge tb_clk);
        for (i = 0; i < count; i++) begin
            wgt_if.tx(value);
        end
        tb_wgt_dw_start_reg = 1'b0;
        repeat(5) @(posedge tb_clk);
    endtask

    // Loads weights w[k] = I (k+1)*256, Q 0 into the first count entries.
    task automatic load_ramp_weight(input int count);
        int k;
        tb_wgt_dw_addr_reg  = '0;
        tb_wgt_dw_start_reg = 1'b1;
        repeat(4) @(posedge tb_clk);
        for (k = 0; k < count; k++) begin
            wgt_if.tx({16'h0000, 16'((k+1)*256)});
        end
        tb_wgt_dw_start_reg = 1'b0;
        repeat(5) @(posedge tb_clk);
    endtask

    // Streams s_axis continuously, with tvalid high one cycle out of every
    // stride, and pulses the trigger in the middle of it (the readout's
    // output never stops, so the window must open on whatever sample comes
    // first after the trigger). Samples are 0.5 (I 0x4000), or, with
    // ramp_data, (n+1)*256 for the n-th valid sample of the window and 0
    // before it. One loop drives trigger and data, #1 after each edge, so
    // nothing races the DUT or itself.
    //
    // The window opens with the sample on the bus in the cycle after
    // TRIG_TO_WIN edges: 2 for trigger's cdc_bit_sync, 1 for matched_filter's
    // WAIT_ST -> READ_ST.
    localparam int TRIG_CYC    = 20;
    localparam int TRIG_TO_WIN = 3;

    task automatic stream_window(input int n_smp, input int stride, input bit ramp_data);
        int cyc, beat;
        bit in_win;
        beat = 0;
        for (cyc = 0; cyc < TRIG_CYC + TRIG_TO_WIN + n_smp*stride + 40; cyc++) begin
            tb_trigger       = (cyc >= TRIG_CYC) && (cyc < TRIG_CYC + TRIG_TO_WIN);
            in_win           = (cyc >= TRIG_CYC + TRIG_TO_WIN);
            tb_s_axis_tvalid = (cyc % stride) == 0;
            if (!ramp_data)
                tb_s_axis_tdata = {16'h0000, 16'h4000};
            else
                tb_s_axis_tdata = in_win ? {16'h0000, 16'((beat+1)*256)} : '0;
            if (in_win && tb_s_axis_tvalid) beat++;
            @(posedge tb_clk); #1;
        end
        tb_trigger       = 1'b0;
        tb_s_axis_tvalid = 1'b0;
        tb_s_axis_tdata  = '0;
        repeat(10) @(posedge tb_clk);
    endtask

    // Reads count words from the raw buffer (m1_axis) starting at address 0.
    task automatic read_buf(input int count, output logic [2*B-1:0] data[$]);
        int cyc;
        data.delete();
        tb_buf_dr_addr_reg  = '0;
        tb_buf_dr_len_reg   = (N_BUF+1)'(count);
        tb_buf_dr_start_reg = 1'b1;
        cyc = 0;
        while (data.size() < count && cyc < 2000) begin
            @(posedge tb_clk);
            if (m1_if.tvalid && m1_if.tready) data.push_back(m1_if.tdata);
            cyc++;
        end
        tb_buf_dr_start_reg = 1'b0;
        repeat(20) @(posedge tb_clk);
    endtask

    task automatic arm_avg(input logic [N_AVG-1:0] addr, input logic [31:0] len);
        tb_avg_addr_reg  = addr;
        tb_avg_len_reg   = len;
        tb_avg_start_reg = 1'b1;
        repeat(4) @(posedge tb_clk);
    endtask

    task automatic arm_buf(input logic [N_BUF-1:0] addr, input logic [N_BUF-1:0] len);
        tb_buf_addr_reg  = addr;
        tb_buf_len_reg   = len;
        tb_buf_start_reg = 1'b1;
        repeat(4) @(posedge tb_clk);
    endtask

    task automatic pulse_trigger();
        tb_trigger = 1'b1;
        repeat(3) @(posedge tb_clk); // cdc_bit_sync settle margin
        tb_trigger = 1'b0;
        repeat(3) @(posedge tb_clk);
    endtask

    task automatic inject_data(input int count, input logic [2*B-1:0] value);
        int i;
        tb_s_axis_tvalid = 1'b1;
        for (i = 0; i < count; i++) begin
            tb_s_axis_tdata = value;
            @(posedge tb_clk);
        end
        tb_s_axis_tvalid = 1'b0;
        tb_s_axis_tdata  = '0;
        repeat(10) @(posedge tb_clk);
    endtask

    // =========================================================================
    // SVUnit build / setup / teardown
    // =========================================================================
    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        tb_trigger             = 1'b0;
        tb_s_axis_tvalid       = 1'b0;
        tb_s_axis_tdata        = '0;
        tb_avg_start_reg       = 1'b0;
        tb_avg_addr_reg        = '0;
        tb_avg_len_reg         = '0;
        tb_avg_photon_mode_reg = 1'b0;
        tb_avg_h_thrsh_reg     = '0;
        tb_avg_l_thrsh_reg     = '0;
        tb_avg_dr_start_reg    = 1'b0;
        tb_avg_dr_addr_reg     = '0;
        tb_avg_dr_len_reg      = '0;
        tb_buf_start_reg       = 1'b0;
        tb_buf_addr_reg        = '0;
        tb_buf_len_reg         = '0;
        tb_buf_dr_start_reg    = 1'b0;
        tb_buf_dr_addr_reg     = '0;
        tb_buf_dr_len_reg      = '0;
        tb_wgt_dw_addr_reg     = '0;
        tb_wgt_dw_start_reg    = 1'b0;
        // wgt_if.tready is driven by the DUT's weight writer: park only the
        // master side, through the same clocking block tx() drives. Forcing
        // tready here made the writer lose the first weight.
        wgt_if.m_cb.tvalid <= 1'b0;
        wgt_if.m_cb.tdata  <= '0;
        wgt_if.m_cb.tlast  <= 1'b0;
        m0_if.tready  = 1'b1;
        m1_if.tready  = 1'b1;
        m2_if.tready  = 1'b1;
        reset_dut();
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    `SVUNIT_TESTS_BEGIN
    `include "weighted_buffer_tests.sv"
    `SVUNIT_TESTS_END

endmodule
