// ============================================================================
// File: axis_avg_buffer_tc00.sv
// Description: SVUnit integration testbench for the axis_avg_buffer IP.
//
//   avg_top, buffer_top, and avg_buffer each already have dedicated
//   testbenches covering the FSM/datapath details. This testbench only
//   exercises what's NEW at the packaged-IP level: the AXI-Lite register
//   map (matching AxisAvgBufferV1pt2.REGISTERS) driving the datapath
//   through axil_slv.
//
//   Three clock domains: s_axi_aclk, s_axis_aclk, m_axis_aclk.
// ============================================================================

`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module axis_avg_buffer_unit_test;

    import svunit_pkg::svunit_testcase;

    string name = "axis_avg_buffer_ut";
    svunit_testcase svunit_ut;

    localparam real AXI_FREQ  = 100e6;
    localparam real AXIS_FREQ = 200e6;
    localparam int  N_AVG = 8;
    localparam int  N_BUF = 8;
    localparam int  B     = 16;

    // Stimulus is driven (and the streams sampled) TSU after the rising edge,
    // never at it: the DUT's flops and the XPM BRAM model do not resolve a
    // change made AT the edge the same way, and which way depends on the
    // simulator version (TESTBENCH_PATTERNS.md section 19). With the inputs
    // driven at the edge, the first sample of a capture reached the FSM and not
    // the memory (xsim 2025.2), so every readback came out shifted by one word.
    localparam time TSU = 1ns;

    // AXI4-Lite register byte addresses.
    localparam logic [5:0] ADDR_AVG_START       = 6'h00;
    localparam logic [5:0] ADDR_AVG_ADDR        = 6'h04;
    localparam logic [5:0] ADDR_AVG_LEN         = 6'h08;
    localparam logic [5:0] ADDR_AVG_DR_START    = 6'h0C;
    localparam logic [5:0] ADDR_AVG_DR_ADDR     = 6'h10;
    localparam logic [5:0] ADDR_AVG_DR_LEN      = 6'h14;
    localparam logic [5:0] ADDR_BUF_START       = 6'h18;
    localparam logic [5:0] ADDR_BUF_ADDR        = 6'h1C;
    localparam logic [5:0] ADDR_BUF_LEN         = 6'h20;
    localparam logic [5:0] ADDR_BUF_DR_START    = 6'h24;
    localparam logic [5:0] ADDR_BUF_DR_ADDR     = 6'h28;
    localparam logic [5:0] ADDR_BUF_DR_LEN      = 6'h2C;
    localparam logic [5:0] ADDR_AVG_PHOTON_MODE = 6'h30;
    localparam logic [5:0] ADDR_AVG_H_THRSH     = 6'h34;
    localparam logic [5:0] ADDR_AVG_L_THRSH     = 6'h38;

    // -------------------------------------------------------------------------
    // Clocks & Resets (three domains, s_axis and m_axis sharing one clock
    // generator here for simplicity -- same-clock integration is a valid
    // configuration and keeps this IP-level testbench focused on the
    // register map, not CDC, which avg_top/buffer_top's own TBs already
    // exercise with genuinely independent clocks).
    // -------------------------------------------------------------------------
    logic s_axi_aclk    = 1'b0;
    logic s_axi_aresetn = 1'b1;
    logic axis_clk      = 1'b0;
    logic axis_aresetn  = 1'b1;

    clk_gen #(.FREQ (AXI_FREQ))  u_axi_clk  (.i_enable(1'b1), .o_clk(s_axi_aclk));
    clk_gen #(.FREQ (AXIS_FREQ)) u_axis_clk (.i_enable(1'b1), .o_clk(axis_clk));

    // -------------------------------------------------------------------------
    // Interfaces
    // -------------------------------------------------------------------------
    axi4_lite_if #(
        .DATA_WIDTH (32),
        .ADDR_WIDTH (6)
    ) s_axi (
        .aclk    (s_axi_aclk),
        .aresetn (s_axi_aresetn)
    );

    axi4_stream_if #(.TDATA_WIDTH(4*B)) m0_if (.aclk(axis_clk), .aresetn(axis_aresetn));
    axi4_stream_if #(.TDATA_WIDTH(2*B)) m1_if (.aclk(axis_clk), .aresetn(axis_aresetn));
    axi4_stream_if #(.TDATA_WIDTH(4*B)) m2_if (.aclk(axis_clk), .aresetn(axis_aresetn));

    // m2 is the register-readback stream and the DUT drives no tlast on it, by
    // design: neither axis_avg_buffer nor avg_buffer exposes an m2_axis_tlast
    // port, and avg_buffer/weighted_buffer both leave avg_top's m1_axis_tlast
    // unconnected (avg_buffer.sv:143, weighted_buffer.sv:201). Left undriven it
    // floats to X, and AXI4STREAM_ERRM_TLAST_X then fires the moment a readback
    // beat raises m2_if.tvalid -- which is why enabling -d SVUNIT used to turn
    // this suite red. m2 has no framing for a consumer to rely on either:
    // qick_processor takes only tdata/tvalid off it. Tie it low and leave the
    // rest of the m2 checkers live.
    assign m2_if.tlast = 1'b0;

    logic            tb_trigger       = 1'b0;
    logic            tb_s_axis_tvalid = 1'b0;
    logic [2*B-1:0]  tb_s_axis_tdata  = '0;
    logic            tb_s_axis_tready;

    initial begin
        $dumpfile("axis_avg_buffer.vcd");
        $dumpvars();
    end

    // -------------------------------------------------------------------------
    // Unit Under Test
    // -------------------------------------------------------------------------
    axis_avg_buffer #(
        .N_AVG (N_AVG),
        .N_BUF (N_BUF),
        .B     (B)
    ) dut (
        .s_axi_aclk    (s_axi_aclk),
        .s_axi_aresetn (s_axi_aresetn),
        .s_axi_awaddr  (s_axi.awaddr),
        .s_axi_awprot  (s_axi.awprot),
        .s_axi_awvalid (s_axi.awvalid),
        .s_axi_awready (s_axi.awready),
        .s_axi_wdata   (s_axi.wdata),
        .s_axi_wstrb   (s_axi.wstrb),
        .s_axi_wvalid  (s_axi.wvalid),
        .s_axi_wready  (s_axi.wready),
        .s_axi_bresp   (s_axi.bresp),
        .s_axi_bvalid  (s_axi.bvalid),
        .s_axi_bready  (s_axi.bready),
        .s_axi_araddr  (s_axi.araddr),
        .s_axi_arprot  (s_axi.arprot),
        .s_axi_arvalid (s_axi.arvalid),
        .s_axi_arready (s_axi.arready),
        .s_axi_rdata   (s_axi.rdata),
        .s_axi_rresp   (s_axi.rresp),
        .s_axi_rvalid  (s_axi.rvalid),
        .s_axi_rready  (s_axi.rready),

        .trigger (tb_trigger),

        .s_axis_aclk    (axis_clk),
        .s_axis_aresetn (axis_aresetn),
        .s_axis_tvalid  (tb_s_axis_tvalid),
        .s_axis_tready  (tb_s_axis_tready),
        .s_axis_tdata   (tb_s_axis_tdata),

        .m_axis_aclk    (axis_clk),
        .m_axis_aresetn (axis_aresetn),

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
        .m2_axis_tdata  (m2_if.tdata)
    );

    // =========================================================================
    // Helper tasks
    // =========================================================================

    task automatic reg_write(input logic [5:0] addr, input logic [31:0] data);
        s_axi.axi_write(addr, data);
    endtask
    task automatic reg_read(input logic [5:0] addr, output logic [31:0] data);
        s_axi.axi_read(addr, data);
    endtask

    task automatic arm_avg(input logic [31:0] addr, input logic [31:0] len);
        reg_write(ADDR_AVG_ADDR, addr);
        reg_write(ADDR_AVG_LEN, len);
        reg_write(ADDR_AVG_START, 32'h1);
        repeat(4) @(posedge axis_clk);
    endtask

    task automatic arm_buf(input logic [31:0] addr, input logic [31:0] len);
        reg_write(ADDR_BUF_ADDR, addr);
        reg_write(ADDR_BUF_LEN, len);
        reg_write(ADDR_BUF_START, 32'h1);
        repeat(4) @(posedge axis_clk);
    endtask

    task automatic pulse_trigger();
        @(posedge axis_clk); #TSU;
        tb_trigger = 1'b1;
        repeat(3) @(posedge axis_clk);
        #TSU;
        tb_trigger = 1'b0;
        repeat(6) @(posedge axis_clk);
    endtask

    task automatic drive_const_samples(input int count, input logic [2*B-1:0] value);
        int i;
        @(posedge axis_clk); #TSU;
        tb_s_axis_tvalid = 1'b1;
        for (i = 0; i < count; i++) begin
            tb_s_axis_tdata = value;
            @(posedge axis_clk); #TSU;
        end
        tb_s_axis_tvalid = 1'b0;
        tb_s_axis_tdata  = '0;
        repeat(6) @(posedge axis_clk);
    endtask

    // =========================================================================
    // Helpers for the odd-length readout tests
    // =========================================================================

    // Lengths of the odd-length readouts: 9 is the case of the issue (last was
    // raised on the 8th beat and valid stayed high), 7 is the next odd length
    // below it, 1 is the shortest.
    function automatic int odd_len(input int k);
        case (k)
            0:       return 9;
            1:       return 7;
            default: return 1;
        endcase
    endfunction

    // Raw-buffer ramp: every sample is different, so a dropped, repeated or
    // reordered beat shows up (a constant would not).
    function automatic logic [2*B-1:0] ramp_word(input int base, input int idx);
        return {16'(16'h4000 + base + idx), 16'(base + idx + 1)};
    endfunction

    // One averaged address = 2 samples of the same value. I is positive, Q is
    // negative on purpose (sign extension of the accumulator).
    function automatic logic [2*B-1:0] avg_in_word(input int base, input int idx);
        return {16'(-(3 * (idx + 1))), 16'(base + 7 * (idx + 1))};
    endfunction

    function automatic logic [4*B-1:0] avg_out_word(input int base, input int idx);
        return {32'(2 * -(3 * (idx + 1))), 32'(2 * (base + 7 * (idx + 1)))};
    endfunction

    // The source of the real design keeps producing after the capture is
    // complete (TESTBENCH_PATTERNS.md section 26), so a capture is offered more
    // samples than it takes.
    task automatic drive_ramp_samples(input int count, input int base);
        int i;
        @(posedge axis_clk); #TSU;
        tb_s_axis_tvalid = 1'b1;
        for (i = 0; i < count; i++) begin
            tb_s_axis_tdata = ramp_word(base, i);
            @(posedge axis_clk); #TSU;
        end
        tb_s_axis_tvalid = 1'b0;
        tb_s_axis_tdata  = '0;
        repeat(6) @(posedge axis_clk);
    endtask

    // which: 0 = averaged data reader (m0_axis), 1 = raw buffer reader (m1_axis).
    // tready is parked low first so that the beats wait in the reader's FIFO
    // until drain_beats takes them: nothing is lost between the start write
    // and the first sample.
    task automatic start_readout(input int which, input int addr, input int len);
        m0_if.tready = 1'b0;
        m1_if.tready = 1'b0;
        if (which == 0) begin
            reg_write(ADDR_AVG_DR_ADDR,  32'(addr));
            reg_write(ADDR_AVG_DR_LEN,   32'(len));
            reg_write(ADDR_AVG_DR_START, 32'h1);
        end else begin
            reg_write(ADDR_BUF_DR_ADDR,  32'(addr));
            reg_write(ADDR_BUF_DR_LEN,   32'(len));
            reg_write(ADDR_BUF_DR_START, 32'h1);
        end
    endtask

    // Release the reader the way the driver's _stop_transfer() does.
    task automatic stop_readout(input int which);
        reg_write((which == 0) ? ADDR_AVG_DR_START : ADDR_BUF_DR_START, 32'h0);
        repeat(10) @(posedge axis_clk);
        m0_if.tready = 1'b1;
        m1_if.tready = 1'b1;
    endtask

    // drain_beats: if burst_low > 0, tready is also low burst_low cycles in every burst_low + burst_high (a test sets them and puts them back to 0)
    int burst_low  = 0;
    int burst_high = 0;

    // Take exactly n beats from m0 or m1 and report what the stream did around
    // the last one. Sampled TSU after the rising edge: tvalid/tdata/tlast have
    // settled and tready is driven here, so a beat with tvalid && tready at this
    // point is the one the next rising edge transfers (a stream's tvalid does
    // not depend on its tready).
    //   stall_period > 0: tready is low one cycle in every stall_period
    //   last_hold    > 0: tready is held low that many cycles in front of the
    //                     last beat, with the beat on the bus
    // After the n-th beat, 40 more cycles are watched with tready high:
    // extra_beats must be 0 (valid must not stay high, no beat after tlast).
    task automatic drain_beats(
        input  int             which,
        input  int             n,
        input  int             stall_period,
        input  int             last_hold,
        output logic [4*B-1:0] data[],
        output int             early_last,
        output bit             last_ok,
        output int             extra_beats,
        output bit             timed_out
    );
        int count = 0;
        int waited = 0;
        int held = 0;
        int cyc = 0;
        bit rdy, v, l;
        logic [4*B-1:0] d;

        data        = new[n];
        early_last  = 0;
        last_ok     = 1'b0;
        extra_beats = 0;
        timed_out   = 1'b0;

        while (count < n && !timed_out) begin
            @(posedge axis_clk); #TSU;
            v = (which == 0) ? m0_if.tvalid : m1_if.tvalid;
            l = (which == 0) ? m0_if.tlast  : m1_if.tlast;
            d = (which == 0) ? m0_if.tdata  : {{2*B{1'b0}}, m1_if.tdata};

            rdy = 1'b1;
            if (stall_period > 0 && (cyc % stall_period) == 0) rdy = 1'b0;
            // long bursts (qick#361): tready low burst_low cycles, high burst_high, so that the reader's FIFO fills mid-stream
            if (burst_low > 0 && (cyc % (burst_low + burst_high)) < burst_low) rdy = 1'b0;
            if (count == n - 1 && held < last_hold) begin
                rdy = 1'b0;
                if (v) held++;
            end
            m0_if.tready = rdy;
            m1_if.tready = rdy;
            cyc++;

            if (v && rdy) begin
                data[count] = d;
                if (count == n - 1) last_ok = l;
                else if (l)         early_last++;
                count++;
            end else if (++waited > 2000) begin
                timed_out = 1'b1;
            end
        end

        m0_if.tready = 1'b1;
        m1_if.tready = 1'b1;
        repeat(40) begin
            @(posedge axis_clk); #TSU;
            if ((which == 0) ? m0_if.tvalid : m1_if.tvalid) extra_beats++;
        end
    endtask

    function automatic int count_ramp_mismatches(
        input logic [4*B-1:0] data[], input int base, input int first, input int n);
        int bad = 0;
        for (int i = 0; i < n; i++)
            if (data[i] !== {{2*B{1'b0}}, ramp_word(base, first + i)}) bad++;
        return bad;
    endfunction

    // Diagnostic only: what came out against what the capture held.
    task automatic show_beats(
        input logic [4*B-1:0] data[], input int base, input int first, input int is_avg);
        for (int i = 0; i < data.size(); i++)
            $display("[#55]   beat %0d: got %h, expected %h", i, data[i],
                     is_avg ? avg_out_word(base, i) : {{2*B{1'b0}}, ramp_word(base, first + i)});
    endtask

    function automatic int count_avg_mismatches(
        input logic [4*B-1:0] data[], input int base, input int n);
        int bad = 0;
        for (int i = 0; i < n; i++)
            if (data[i] !== avg_out_word(base, i)) bad++;
        return bad;
    endfunction

    // =========================================================================
    // SVUnit build / setup / teardown
    // =========================================================================
    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();

        tb_trigger       = 1'b0;
        tb_s_axis_tvalid = 1'b0;
        tb_s_axis_tdata  = '0;
        m0_if.tready = 1'b1;
        m1_if.tready = 1'b1;
        m2_if.tready = 1'b1;

        s_axi_aresetn <= 1'b0;
        axis_aresetn  <= 1'b0;
        repeat(4) @(posedge axis_clk);
        s_axi_aresetn <= 1'b1;
        axis_aresetn  <= 1'b1;

        s_axi.reset();
        // XPM_FIFO (inside avg_top/buffer_top's bram_to_axis and avg_top's
        // fifo_async) needs a long wr_rst_busy/rd_rst_busy settle window.
        repeat(100) @(posedge axis_clk);
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    `SVUNIT_TESTS_BEGIN
    `include "axis_avg_buffer_tests.sv"
    `SVUNIT_TESTS_END

endmodule
