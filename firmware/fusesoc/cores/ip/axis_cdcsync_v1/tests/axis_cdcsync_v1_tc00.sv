// ============================================================================
// File: axis_cdcsync_v1_tc00.sv
// Description: SVUnit testbench for axis_cdcsync_v1.
//
//   Six configurations, each next to the legacy RTL (tests/ref/
//   axis_cdcsync_v1_legacy.sv, the original files with only the module names
//   changed), on two clock pairs:
//     c0: N=4,  B=168  (216 tpv2_std / tpv2_std_rfbv2)   pair 0
//     c1: N=2,  B=168  (216 tpv2_std)                    pair 0
//     c2: N=1,  B=168  (a one-channel tProc v2 firmware)  pair 0
//     c3: N=4,  B=160  (111 tpv1_rfbv2_std, tProc v1)    pair 0
//     c4: N=16, B=8    (every channel)                    pair 0
//     c5: N=4,  B=168  (slow reader: the FIFO fills)      pair 1
//   pair 0: s_axis_aclk 307.2 MHz -> m_axis_aclk 614.4 MHz
//   pair 1: s_axis_aclk 430.08 MHz -> m_axis_aclk 153.6 MHz
//
//   Each pair has one stimulus (tvalid, tdata, tready on all 16 channels);
//   every configuration takes its first N channels and the low B bits.
//   Inputs are driven with a non-blocking assignment right after a rising
//   edge and sampled on the falling edge, where they hold the values the
//   next rising edge acts on.
//
//   Checkers, always running once cmp_en is set:
//   - co-simulation: on every falling edge, the used channels' tvalid (and
//     tdata when tvalid) on m_axis_aclk and tready on s_axis_aclk must match
//     the legacy RTL (cmp_err);
//   - scoreboard: every accepted input word (some used tvalid, tready) must
//     come out whole and in order when the port pops it (all used tready,
//     some tvalid) (sb_err);
//   - channels >= N: tvalid = 0, tdata = 0, tready = 1 (unused_err).
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

// One side of a configuration: the port or the legacy RTL, with the 16
// channels as arrays (both modules have the same port names, so `.*`).
module axis_cdcsync_v1_tb_side #(
    parameter int N = 2,
    parameter int B = 8,
    parameter bit LEGACY = 1'b0
) (
    input  logic         sclk, mclk, srstn,
    input  logic [15:0]  vld,
    input  logic [167:0] dat [16],
    input  logic [15:0]  rdy,
    output logic [15:0]  sready,
    output logic [15:0]  mvalid,
    output logic [167:0] mdata [16]
);
    logic s_axis_aclk, s_axis_aresetn, m_axis_aclk, m_axis_aresetn;
    assign s_axis_aclk    = sclk;
    assign m_axis_aclk    = mclk;
    assign s_axis_aresetn = srstn;
    assign m_axis_aresetn = srstn;

`define CDCSYNC_TB_CH(i) \
    logic s``i``_axis_tready, s``i``_axis_tvalid, m``i``_axis_tready, m``i``_axis_tvalid; \
    logic [B-1:0] s``i``_axis_tdata, m``i``_axis_tdata; \
    assign s``i``_axis_tvalid = vld[i]; \
    assign s``i``_axis_tdata  = dat[i][B-1:0]; \
    assign m``i``_axis_tready = rdy[i]; \
    assign sready[i] = s``i``_axis_tready; \
    assign mvalid[i] = m``i``_axis_tvalid; \
    assign mdata[i]  = 168'(m``i``_axis_tdata);

    `CDCSYNC_TB_CH(0)  `CDCSYNC_TB_CH(1)  `CDCSYNC_TB_CH(2)  `CDCSYNC_TB_CH(3)
    `CDCSYNC_TB_CH(4)  `CDCSYNC_TB_CH(5)  `CDCSYNC_TB_CH(6)  `CDCSYNC_TB_CH(7)
    `CDCSYNC_TB_CH(8)  `CDCSYNC_TB_CH(9)  `CDCSYNC_TB_CH(10) `CDCSYNC_TB_CH(11)
    `CDCSYNC_TB_CH(12) `CDCSYNC_TB_CH(13) `CDCSYNC_TB_CH(14) `CDCSYNC_TB_CH(15)
`undef CDCSYNC_TB_CH

    if (LEGACY) begin : g_ref
        axis_cdcsync_v1_legacy #(.N(N), .B(B)) ref_i (.*);
    end else begin : g_dut
        axis_cdcsync_v1 #(.N(N), .B(B)) dut (.*);
    end
endmodule

module axis_cdcsync_v1_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "axis_cdcsync_v1_ut";
    svunit_testcase svunit_ut;

    localparam int NC = 6;
    localparam int CN [NC] = '{4, 2, 1, 4, 16, 4};
    localparam int CB [NC] = '{168, 168, 168, 160, 8, 168};
    localparam int CP [NC] = '{0, 0, 0, 0, 0, 1};

    // ------------------------------------------------------------------
    // Clocks, reset, stimulus (per clock pair)
    // ------------------------------------------------------------------
    logic sclk [2], mclk [2];
    logic srstn = 1'b1;

    clk_gen #(.FREQ(307.2e6))  u_sclk0 (.i_enable(1'b1), .o_clk(sclk[0]));
    clk_gen #(.FREQ(614.4e6))  u_mclk0 (.i_enable(1'b1), .o_clk(mclk[0]));
    clk_gen #(.FREQ(430.08e6)) u_sclk1 (.i_enable(1'b1), .o_clk(sclk[1]));
    clk_gen #(.FREQ(153.6e6))  u_mclk1 (.i_enable(1'b1), .o_clk(mclk[1]));

    logic [15:0]  vld [2];
    logic [167:0] dat [2][16];
    logic [15:0]  rdy [2];

    // Random traffic: while s_auto[p], each channel is valid with probability
    // s_pct %; while m_auto[p], each output is ready with probability m_pct %.
    // A word pops only when all N outputs are ready (m_pct^N per clock), so
    // m_pct stays high enough for N = 16 to move (0.9^16 = 19 %).
    bit s_auto [2] = '{0, 0};
    bit m_auto [2] = '{0, 0};
    int s_pct = 50, m_pct = 90;

    function automatic logic [167:0] rand168();
        return {$urandom, $urandom, $urandom, $urandom, $urandom, $urandom};
    endfunction

    function automatic logic [15:0] rand_mask(int pct);
        logic [15:0] m;
        for (int i = 0; i < 16; i++) m[i] = ($urandom_range(99) < pct);
        return m;
    endfunction

    for (genvar p = 0; p < 2; p++) begin : g_drv
        always @(posedge sclk[p]) if (s_auto[p]) begin
            vld[p] <= rand_mask(s_pct);
            for (int i = 0; i < 16; i++) dat[p][i] <= rand168();
        end
        always @(posedge mclk[p]) if (m_auto[p]) rdy[p] <= rand_mask(m_pct);
    end

    // ------------------------------------------------------------------
    // Configurations: port and legacy side by side, plus the checkers
    // ------------------------------------------------------------------
    typedef struct packed {
        logic [15:0]        valid;
        logic [15:0][167:0] data;
    } word_t;

    bit cmp_en = 1'b0;
    int cmp_err [NC], sb_err [NC], unused_err [NC], n_push [NC], n_pop [NC];
    word_t sb_q [NC][$];

    logic [15:0]  p_sready [NC], l_sready [NC], p_mvalid [NC], l_mvalid [NC];
    logic [167:0] p_mdata [NC][16], l_mdata [NC][16];

    for (genvar c = 0; c < NC; c++) begin : g_cfg
        localparam int N = CN[c];
        localparam int B = CB[c];
        localparam int P = CP[c];
        localparam logic [15:0]  USED  = 16'((32'd1 << N) - 1);
        localparam logic [167:0] DMASK = 168'((169'd1 << B) - 1);

        axis_cdcsync_v1_tb_side #(.N(N), .B(B), .LEGACY(1'b0)) u_port (
            .sclk(sclk[P]), .mclk(mclk[P]), .srstn(srstn),
            .vld(vld[P]), .dat(dat[P]), .rdy(rdy[P]),
            .sready(p_sready[c]), .mvalid(p_mvalid[c]), .mdata(p_mdata[c]));

        axis_cdcsync_v1_tb_side #(.N(N), .B(B), .LEGACY(1'b1)) u_ref (
            .sclk(sclk[P]), .mclk(mclk[P]), .srstn(srstn),
            .vld(vld[P]), .dat(dat[P]), .rdy(rdy[P]),
            .sready(l_sready[c]), .mvalid(l_mvalid[c]), .mdata(l_mdata[c]));

        // Write side: tready against the legacy RTL, accepted words into the
        // scoreboard, the channels past N.
        always @(negedge sclk[P]) if (cmp_en) begin
            if ((p_sready[c] & USED) !== (l_sready[c] & USED)) cmp_err[c]++;
            if ((p_sready[c] | USED) !== 16'hFFFF) unused_err[c]++;
            if ((vld[P] & USED) != 0 && p_sready[c][0]) begin
                word_t w;
                w.valid = vld[P] & USED;
                for (int i = 0; i < 16; i++) w.data[i] = (i < N) ? (dat[P][i] & DMASK) : '0;
                sb_q[c].push_back(w);
                n_push[c]++;
            end
        end

        // Read side: tvalid/tdata against the legacy RTL, popped words
        // against the scoreboard, the channels past N.
        always @(negedge mclk[P]) if (cmp_en) begin
            if ((p_mvalid[c] & USED) !== (l_mvalid[c] & USED)) cmp_err[c]++;
            for (int i = 0; i < N; i++)
                if (p_mvalid[c][i] && p_mdata[c][i] !== l_mdata[c][i]) cmp_err[c]++;
            if ((p_mvalid[c] & ~USED) !== 16'h0) unused_err[c]++;
            for (int i = N; i < 16; i++)
                if (p_mdata[c][i] !== '0) unused_err[c]++;
            if ((p_mvalid[c] & USED) != 0 && ((rdy[P] | ~USED) == 16'hFFFF)) begin
                word_t w;
                n_pop[c]++;
                if (sb_q[c].size() == 0) sb_err[c]++;
                else begin
                    w = sb_q[c].pop_front();
                    if ((p_mvalid[c] & USED) !== w.valid) sb_err[c]++;
                    for (int i = 0; i < N; i++)
                        if (p_mdata[c][i] !== w.data[i]) sb_err[c]++;
                end
            end
        end
    end

    // ------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------
    // Rising edge of pair p's write clock. xsim cannot elaborate an event
    // control on sclk[p] with a run-time index (it hangs), hence the if.
    task automatic wait_s(input int p);
        if (p == 0) @(posedge sclk[0]); else @(posedge sclk[1]);
    endtask

    task automatic idle_inputs();
        for (int p = 0; p < 2; p++) begin
            s_auto[p] = 1'b0;
            m_auto[p] = 1'b0;
            vld[p] = '0;
            rdy[p] = '1;
            for (int i = 0; i < 16; i++) dat[p][i] = '0;
        end
    endtask

    // Reset the FIFOs and wait until every port accepts again (xpm_fifo_async
    // keeps wr_rst_busy high for a while after the reset is released).
    task automatic reset_all();
        srstn <= 1'b0;
        repeat (30) @(posedge mclk[1]);
        srstn <= 1'b1;
        for (int c = 0; c < NC; c++) begin
            int n = 0;
            while (!p_sready[c][0] && n < 2000) begin wait_s(CP[c]); n++; end
        end
        repeat (10) @(posedge mclk[1]);
    endtask

    // Stop the traffic, open every output and let the FIFOs empty.
    task automatic drain();
        @(posedge sclk[0]); s_auto[0] = 1'b0; vld[0] <= '0;
        @(posedge sclk[1]); s_auto[1] = 1'b0; vld[1] <= '0;
        @(posedge mclk[0]); m_auto[0] = 1'b0; rdy[0] <= '1;
        @(posedge mclk[1]); m_auto[1] = 1'b0; rdy[1] <= '1;
        repeat (60) @(posedge mclk[1]);
    endtask

    // One word on pair p: valid mask and random data, held for one edge.
    task automatic push_word(input int p, input logic [15:0] mask);
        wait_s(p);
        vld[p] <= mask;
        for (int i = 0; i < 16; i++) dat[p][i] <= rand168();
        wait_s(p);
        vld[p] <= '0;
    endtask

    function automatic int total(input int v [NC]);
        int s = 0;
        foreach (v[c]) s += v[c];
        return s;
    endfunction

    function automatic void clear_counters();
        for (int c = 0; c < NC; c++) begin
            cmp_err[c] = 0; sb_err[c] = 0; unused_err[c] = 0;
            n_push[c] = 0; n_pop[c] = 0;
            sb_q[c].delete();
        end
    endfunction

    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        cmp_en = 1'b0;
        idle_inputs();
        reset_all();
        clear_counters();
        cmp_en = 1'b1;
    endtask

    task teardown();
        svunit_ut.teardown();
        cmp_en = 1'b0;
    endtask

    `SVUNIT_TESTS_BEGIN
    `include "axis_cdcsync_v1_tests.sv"
    `SVUNIT_TESTS_END
endmodule
