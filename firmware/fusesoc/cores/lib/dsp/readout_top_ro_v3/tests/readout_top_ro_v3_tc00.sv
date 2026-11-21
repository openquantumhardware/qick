// ============================================================================
// File: readout_top_ro_v3_tc00.sv
// Description: SVUnit integration testbench for readout_top_ro_v3.
//
//   Full datapath flow: push a demodulation descriptor via the fifo port,
//   drive a constant ADC sample on s_axis, observe m_axis (decimated).
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module readout_top_ro_v3_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "readout_top_ro_v3_ut";
    svunit_testcase svunit_ut;

    localparam real CLOCK_FREQUENCY = 200e6;
    localparam int  N = 4;

    logic tb_clk     = 1'b0;
    logic tb_aresetn = 1'b1;

    clk_gen #(.FREQ (CLOCK_FREQUENCY)) u_clk (.i_enable(1'b1), .o_clk(tb_clk));

    logic         tb_fifo_wr_en;
    logic         tb_fifo_full;
    logic [87:0]  tb_fifo_din;

    logic             tb_s_axis_tvalid;
    logic             tb_s_axis_tready;
    logic [N*16-1:0]  tb_s_axis_tdata;

    logic         tb_m_axis_tready;
    logic         tb_m_axis_tvalid;
    logic [31:0]  tb_m_axis_tdata;

    initial begin
        $dumpfile("readout_top_ro_v3.vcd");
        $dumpvars();
    end

    readout_top_ro_v3 #(
        .N (N)
    ) dut (
        .aresetn (tb_aresetn),
        .aclk    (tb_clk),

        .fifo_wr_en (tb_fifo_wr_en),
        .fifo_full  (tb_fifo_full),
        .fifo_din   (tb_fifo_din),

        .s_axis_tvalid (tb_s_axis_tvalid),
        .s_axis_tready (tb_s_axis_tready),
        .s_axis_tdata  (tb_s_axis_tdata),

        .m_axis_tready (tb_m_axis_tready),
        .m_axis_tvalid (tb_m_axis_tvalid),
        .m_axis_tdata  (tb_m_axis_tdata)
    );

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
        @(negedge tb_clk);
        tb_fifo_din   = descr;
        tb_fifo_wr_en = 1'b1;
        @(posedge tb_clk);
        @(negedge tb_clk);
        tb_fifo_wr_en = 1'b0;
        repeat(30) @(posedge tb_clk);
        @(negedge tb_clk);
    endtask

    task automatic drive_const_input(input logic [15:0] v);
        int i;
        for (i = 0; i < N; i++)
            tb_s_axis_tdata[i*16+:16] = v;
    endtask

    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        tb_fifo_wr_en    = 1'b0;
        tb_fifo_din      = '0;
        tb_s_axis_tvalid = 1'b1;
        tb_s_axis_tdata  = '0;
        tb_m_axis_tready = 1'b1;
        reset_dut();
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    task automatic reset_dut();
        tb_aresetn = 1'b0;
        repeat(4) @(posedge tb_clk);
        tb_aresetn = 1'b1;
        // History/pipe flush for fir_decim4_ro_v3 (no reset of its own) +
        // XPM fifo settle.
        repeat(60) @(posedge tb_clk);
    endtask

    `SVUNIT_TESTS_BEGIN
    `include "readout_top_ro_v3_tests.sv"
    `SVUNIT_TESTS_END

endmodule
