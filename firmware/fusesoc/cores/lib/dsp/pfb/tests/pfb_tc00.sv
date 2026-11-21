// ============================================================================
// File: pfb_tc00.sv
// Description: SVUnit testbench for pfb.
//
//   - Wiring: the port next to the legacy pfb.sv (tests/ref/pfb_legacy.sv,
//     built on the same ported children), N = 64, L = 4 as deployed; an
//     always-on checker compares m_axis_tvalid/tlast/tdata with !== on every
//     falling edge (mism).
//   - Function: complex tones at channel centres, output power per frame
//     position (clock in frame x lane).
//
//   Inputs are driven with a non-blocking assignment right after a rising
//   edge; outputs are sampled on the falling edge.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module pfb_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "pfb_ut";
    svunit_testcase svunit_ut;

    localparam real CLOCK_FREQUENCY = 300e6;
    localparam real PI = 3.14159265358979323846;
    localparam int  N = 64, L = 4;
    localparam int  NFR = N / (2 * L);   // clocks per output frame

    logic aclk = 1'b0;
    logic aresetn = 1'b1;
    clk_gen #(.FREQ(CLOCK_FREQUENCY)) u_clk (.i_enable(1'b1), .o_clk(aclk));

    logic              s_tvalid = 1'b0;
    logic [L*32-1:0]   s_tdata  = '0;
    logic [7:0]        qout     = 8'd0;
    logic              p_tvalid, l_tvalid, p_tlast, l_tlast;
    logic [2*L*32-1:0] p_tdata, l_tdata;

    pfb #(.N(N), .L(L)) dut (
        .aresetn(aresetn), .aclk(aclk),
        .s_axis_tvalid(s_tvalid), .s_axis_tdata(s_tdata),
        .m_axis_tvalid(p_tvalid), .m_axis_tlast(p_tlast), .m_axis_tdata(p_tdata),
        .qout_reg(qout));

    pfb_legacy #(.N(N), .L(L)) ref_i (
        .aresetn(aresetn), .aclk(aclk),
        .s_axis_tvalid(s_tvalid), .s_axis_tdata(s_tdata),
        .m_axis_tvalid(l_tvalid), .m_axis_tlast(l_tlast), .m_axis_tdata(l_tdata),
        .QOUT_REG(qout));

    bit cmp_en = 1'b0;
    int mism = 0, n_valid = 0;

    always @(negedge aclk) if (cmp_en) begin
        if (p_tvalid !== l_tvalid || p_tlast !== l_tlast || p_tdata !== l_tdata) mism++;
        if (l_tvalid) n_valid++;
    end

    // Power accumulated per frame position [clock in frame][output lane],
    // counted from the clock after tlast.
    real pw [NFR][2*L];
    bit  acc_en = 1'b0;
    int  fpos = 0;
    always @(negedge aclk) if (p_tvalid) begin
        if (acc_en)
            for (int l = 0; l < 2 * L; l++) begin
                real i = $signed(p_tdata[l*32      +: 16]);
                real q = $signed(p_tdata[l*32 + 16 +: 16]);
                pw[fpos][l] += i * i + q * q;
            end
        fpos = p_tlast ? 0 : (fpos + 1) % NFR;
    end

    // Continuous complex tone A*exp(j*2*pi*f*n), f in cycles per sample,
    // L samples per clock (lane i = sample 4t + i), for n clocks.
    real ph = 0.0;
    task automatic tone(input real f, input real amp, input int nclk);
        for (int t = 0; t < nclk; t++) begin
            @(posedge aclk);
            s_tvalid <= 1'b1;
            for (int i = 0; i < L; i++) begin
                s_tdata[i*32      +: 16] <= 16'($rtoi(amp * $cos(ph)));
                s_tdata[i*32 + 16 +: 16] <= 16'($rtoi(amp * $sin(ph)));
                ph += 2.0 * PI * f;
            end
        end
    endtask

    function automatic void clear_pw();
        for (int t = 0; t < NFR; t++) for (int l = 0; l < 2 * L; l++) pw[t][l] = 0.0;
    endfunction

    task automatic reset_dut();
        @(posedge aclk);
        aresetn <= 1'b0;
        repeat (3) @(posedge aclk);
        aresetn <= 1'b1;
    endtask

    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        cmp_en = 1'b1;
        reset_dut();
        mism = 0; n_valid = 0;
    endtask

    task teardown();
        svunit_ut.teardown();
        cmp_en = 1'b0;
    endtask

    `SVUNIT_TESTS_BEGIN
    `include "pfb_tests.sv"
    `SVUNIT_TESTS_END
endmodule
