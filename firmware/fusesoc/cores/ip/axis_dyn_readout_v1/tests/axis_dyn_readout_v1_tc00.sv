// ============================================================================
// File: axis_dyn_readout_v1_tc00.sv
// Description: SVUnit integration testbench for the axis_dyn_readout_v1 IP.
//
//   Full IP flow: push a demodulation descriptor via s0_axis, drive a
//   constant ADC sample on s1_axis, observe m0_axis (undecimated) and
//   m1_axis (decimated).
//
//   One clock domain: aclk.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module axis_dyn_readout_v1_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "axis_dyn_readout_v1_ut";
    svunit_testcase svunit_ut;

    localparam real CLOCK_FREQUENCY = 200e6;
    localparam int  N_DDS = 8;

    logic aclk    = 1'b0;
    logic aresetn = 1'b1;

    clk_gen #(.FREQ (CLOCK_FREQUENCY)) u_a (.i_enable(1'b1), .o_clk(aclk));

    axi4_stream_if #(.TDATA_WIDTH(88))          s0_if (.aclk(aclk), .aresetn(aresetn));
    axi4_stream_if #(.TDATA_WIDTH(N_DDS*16))     s1_if (.aclk(aclk), .aresetn(aresetn));
    axi4_stream_if #(.TDATA_WIDTH(N_DDS*32))     m0_if (.aclk(aclk), .aresetn(aresetn));
    axi4_stream_if #(.TDATA_WIDTH(32))           m1_if (.aclk(aclk), .aresetn(aresetn));
    assign m0_if.tready = 1'b1;
    assign m0_if.tlast  = 1'b0;
    assign m1_if.tready = 1'b1;
    assign m1_if.tlast  = 1'b0;

    initial begin
        $dumpfile("axis_dyn_readout_v1.vcd");
        $dumpvars();
    end

    axis_dyn_readout_v1 #(
        .N_DDS (N_DDS)
    ) dut (
        .aresetn (aresetn),
        .aclk    (aclk),

        .s0_axis_tready (s0_if.tready),
        .s0_axis_tvalid (s0_if.tvalid),
        .s0_axis_tdata  (s0_if.tdata),

        .s1_axis_tvalid (s1_if.tvalid),
        .s1_axis_tready (s1_if.tready),
        .s1_axis_tdata  (s1_if.tdata),

        .m0_axis_tready (m0_if.tready),
        .m0_axis_tvalid (m0_if.tvalid),
        .m0_axis_tdata  (m0_if.tdata),

        .m1_axis_tready (m1_if.tready),
        .m1_axis_tvalid (m1_if.tvalid),
        .m1_axis_tdata  (m1_if.tdata)
    );

    function automatic logic [31:0] m0_lane(int lane);
        return m0_if.tdata[lane*32+:32];
    endfunction

    function automatic logic [87:0] build_descr(
        input logic [31:0] freq, input logic [31:0] phase,
        input logic [15:0] nsamp, input logic [1:0] outsel,
        input logic mode, input logic phrst
    );
        logic [87:0] d = '0;
        d[31:0]  = freq;
        d[63:32] = phase;
        d[79:64] = nsamp;
        d[81:80] = outsel;
        d[82]    = mode;
        d[83]    = phrst;
        return d;
    endfunction

    task automatic push_descriptor(input logic [87:0] descr);
        @(posedge aclk);
        s0_if.tdata  <= descr;
        s0_if.tvalid <= 1'b1;
        @(posedge aclk);
        while (!s0_if.tready) @(posedge aclk);
        s0_if.tvalid <= 1'b0;
        @(posedge aclk);
        repeat(30) @(posedge aclk);
    endtask

    task automatic drive_const_input(input logic [15:0] v);
        int i;
        for (i = 0; i < N_DDS; i++)
            s1_if.tdata[i*16+:16] = v;
    endtask

    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();

        s0_if.tvalid = 1'b0; s0_if.tlast = 1'b0; s0_if.tdata = '0;
        s0_if.tstrb  = '1;   s0_if.tkeep = '0;   s0_if.tuser = '0;
        s0_if.tid    = '0;   s0_if.tdest = '0;
        s1_if.tvalid = 1'b1; s1_if.tlast = 1'b0; s1_if.tdata = '0;
        s1_if.tstrb  = '1;   s1_if.tkeep = '0;   s1_if.tuser = '0;
        s1_if.tid    = '0;   s1_if.tdest = '0;

        aresetn <= 1'b0;
        repeat(4) @(posedge aclk);
        aresetn <= 1'b1;

        s0_if.m_reset();
        // History/pipe flush for fir_decim8_dynro (no reset of its own) +
        // XPM fifo settle.
        repeat(60) @(posedge aclk);
    endtask

    task teardown();
        svunit_ut.teardown();
        s0_if.m_cb.tvalid <= 1'b0;
        repeat(10) @(posedge aclk);
    endtask

    `SVUNIT_TESTS_BEGIN
    `include "axis_dyn_readout_v1_tests.sv"
    `SVUNIT_TESTS_END

endmodule
