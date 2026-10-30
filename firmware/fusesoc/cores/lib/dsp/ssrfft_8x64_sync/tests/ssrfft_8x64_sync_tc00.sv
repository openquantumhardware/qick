// ============================================================================
// File: ssrfft_8x64_sync_tc00.sv
// Description: SVUnit testbench for ssrfft_8x64_sync.
//
//   The port next to the legacy VHDL (tests/ref/*_legacy.vhd, the original
//   files with only the entity names changed), both on the same SysGen FFT
//   core, NFFT = 64, SSR = 8, B = 16 (as deployed). An always-on checker
//   compares m_axis_tdata/tvalid/tlast on every falling edge (mism).
//
//   Inputs are driven with a non-blocking assignment right after a rising
//   edge; outputs are sampled on the falling edge.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module ssrfft_8x64_sync_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "ssrfft_8x64_sync_ut";
    svunit_testcase svunit_ut;

    localparam real CLOCK_FREQUENCY = 300e6;
    localparam int  NFFT = 64, SSR = 8, B = 16;
    localparam int  W = 2 * SSR * B;

    logic aclk = 1'b0;
    logic aresetn = 1'b1;
    clk_gen #(.FREQ(CLOCK_FREQUENCY)) u_clk (.i_enable(1'b1), .o_clk(aclk));

    logic [W-1:0] s_tdata  = '0;
    logic         s_tlast  = 1'b0;
    logic         s_tvalid = 1'b1;
    logic [31:0]  scale    = '0;
    logic [31:0]  qout     = '0;

    logic [W-1:0] p_tdata, l_tdata;
    logic         p_tlast, l_tlast, p_tvalid, l_tvalid;

    ssrfft_8x64_sync #(.NFFT(NFFT), .SSR(SSR), .B(B)) dut (
        .aresetn(aresetn), .aclk(aclk),
        .s_axis_tdata(s_tdata), .s_axis_tlast(s_tlast), .s_axis_tvalid(s_tvalid),
        .m_axis_tdata(p_tdata), .m_axis_tlast(p_tlast), .m_axis_tvalid(p_tvalid),
        .scale_reg(scale), .qout_reg(qout));

    ssrfft_8x64_sync_legacy #(.NFFT(NFFT), .SSR(SSR), .B(B)) ref_i (
        .aresetn(aresetn), .aclk(aclk),
        .s_axis_tdata(s_tdata), .s_axis_tlast(s_tlast), .s_axis_tvalid(s_tvalid),
        .m_axis_tdata(l_tdata), .m_axis_tlast(l_tlast), .m_axis_tvalid(l_tvalid),
        .scale_reg(scale), .qout_reg(qout));

    // Always-on comparison.
    bit cmp_en = 1'b0;
    int mism = 0, n_valid = 0, n_last = 0;

    always @(negedge aclk) if (cmp_en) begin
        if (p_tvalid !== l_tvalid || p_tlast !== l_tlast) mism++;
        if (l_tvalid && p_tdata !== l_tdata) mism++;
        if (l_tvalid) n_valid++;
        if (l_tvalid && l_tlast) n_last++;
    end

    // One input clock: random samples (full scale / 2^shift), tlast as given.
    task automatic step(input logic last, input int shift = 2);
        @(posedge aclk);
        for (int i = 0; i < 2 * SSR; i++) s_tdata[i*B +: B] <= B'($signed(16'($urandom)) >>> shift);
        s_tlast  <= last;
        s_tvalid <= $urandom_range(1);   // ignored by the block
    endtask

    // n frames with tlast on the last clock of each, starting at phase 0.
    task automatic aligned(input int nframes);
        for (int f = 0; f < nframes; f++)
            for (int t = 0; t < NFFT / SSR; t++) step(t == NFFT / SSR - 1);
    endtask

    task automatic reset_dut();
        @(posedge aclk);
        aresetn <= 1'b0;
        repeat (4) @(posedge aclk);
        aresetn <= 1'b1;
    endtask

    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        cmp_en = 1'b0;
        s_tlast = 1'b0; scale = '0; qout = '0;
        reset_dut();
        mism = 0; n_valid = 0; n_last = 0;
        cmp_en = 1'b1;
    endtask

    task teardown();
        svunit_ut.teardown();
        cmp_en = 1'b0;
    endtask

    `SVUNIT_TESTS_BEGIN
    `include "ssrfft_8x64_sync_tests.sv"
    `SVUNIT_TESTS_END
endmodule
