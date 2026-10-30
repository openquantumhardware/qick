// ============================================================================
// File: axis_register_slice_nb_tc00.sv
// Description: SVUnit testbench for axis_register_slice_nb.
//
//   Three instances run side by side on the same clock:
//     d_def : B=16,  N=4  (the packaged IP's defaults)
//     d_adc : B=128, N=2  (the configuration in the standard Top BDs, between
//                          the RFDC ADC and the readouts)
//     d_one : B=8,   N=1  (edge case the legacy VHDL could not build)
//
//   Sampling convention (no clocking block): inputs are driven with a
//   non-blocking assignment right after a rising edge; outputs are read
//   TSU after a rising edge. hist[t] is the input driven after edge t, so
//   after edge T an N-stage pipeline must show hist[T-N].
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module axis_register_slice_nb_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "axis_register_slice_nb_ut";
    svunit_testcase svunit_ut;

    localparam real CLOCK_FREQUENCY = 250e6;
    localparam time TSU = 1ns;
    localparam int  HMAX = 4096;

    logic aclk    = 1'b0;
    logic aresetn = 1'b1;

    clk_gen #(.FREQ(CLOCK_FREQUENCY)) u_clk (.i_enable(1'b1), .o_clk(aclk));

    // Shared stimulus: every instance sees (a slice of) the same 128-bit word.
    logic [127:0] s_tdata  = '0;
    logic         s_tvalid = 1'b1;
    logic         m_tready = 1'b1;

    logic [15:0]  def_tdata;  logic def_tready, def_tvalid;
    logic [127:0] adc_tdata;  logic adc_tready, adc_tvalid;
    logic [7:0]   one_tdata;  logic one_tready, one_tvalid;

    axis_register_slice_nb #(.B(16), .N(4)) d_def (
        .aclk(aclk), .aresetn(aresetn),
        .s_axis_tdata(s_tdata[15:0]), .s_axis_tvalid(s_tvalid), .s_axis_tready(def_tready),
        .m_axis_tdata(def_tdata), .m_axis_tvalid(def_tvalid), .m_axis_tready(m_tready));

    axis_register_slice_nb #(.B(128), .N(2)) d_adc (
        .aclk(aclk), .aresetn(aresetn),
        .s_axis_tdata(s_tdata), .s_axis_tvalid(s_tvalid), .s_axis_tready(adc_tready),
        .m_axis_tdata(adc_tdata), .m_axis_tvalid(adc_tvalid), .m_axis_tready(m_tready));

    axis_register_slice_nb #(.B(8), .N(1)) d_one (
        .aclk(aclk), .aresetn(aresetn),
        .s_axis_tdata(s_tdata[7:0]), .s_axis_tvalid(s_tvalid), .s_axis_tready(one_tready),
        .m_axis_tdata(one_tdata), .m_axis_tvalid(one_tvalid), .m_axis_tready(m_tready));

    logic [127:0] hist [HMAX];
    int           t_now;     // index of the last rising edge (drive/sample reference)

    // Drive a new random word after the next edge and record it; return after
    // the outputs of that edge have settled (TSU).
    task automatic step_random();
        @(posedge aclk);
        t_now++;
        hist[t_now] = {$urandom, $urandom, $urandom, $urandom};
        s_tdata <= hist[t_now];
        #TSU;
    endtask

    // Expected output of an N-stage pipeline after edge t_now.
    function automatic logic [127:0] expected(int n);
        return (t_now - n >= 0) ? hist[t_now - n] : '0;
    endfunction

    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        s_tvalid = 1'b1;
        m_tready = 1'b1;
        s_tdata  = '0;
        aresetn <= 1'b0;
        repeat (4) @(posedge aclk);
        aresetn <= 1'b1;
        // After reset the pipelines hold 0; count edges from here with hist = 0.
        t_now = 0;
        hist[0] = '0;
        #TSU;
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    `SVUNIT_TESTS_BEGIN
    `include "axis_register_slice_nb_tests.sv"
    `SVUNIT_TESTS_END
endmodule
