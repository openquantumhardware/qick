// ============================================================================
// File: down_conversion_ro_v3_tc00.sv
// Description: SVUnit testbench top-level for down_conversion_ro_v3.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module down_conversion_ro_v3_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "down_conversion_ro_v3_ut";
    svunit_testcase svunit_ut;

    localparam real CLOCK_FREQUENCY = 200e6;
    localparam int  N = 4;

    logic tb_clk  = 1'b0;
    logic tb_rstn = 1'b1;

    clk_gen #(.FREQ (CLOCK_FREQUENCY)) u_clk (.i_enable(1'b1), .o_clk(tb_clk));

    logic              tb_s_axis_tready;
    logic              tb_s_axis_tvalid;
    logic [N*16-1:0]   tb_s_axis_tdata;

    logic              tb_m_axis_tready;
    logic              tb_m_axis_tvalid;
    logic [N*32-1:0]   tb_m_axis_tdata;

    logic         tb_fifo_rd_en;
    logic         tb_fifo_empty;
    logic [87:0]  tb_fifo_dout;

    initial begin
        $dumpfile("down_conversion_ro_v3.vcd");
        $dumpvars();
    end

    down_conversion_ro_v3 #(
        .N (N)
    ) dut (
        .aresetn (tb_rstn),
        .aclk    (tb_clk),

        .fifo_rd_en (tb_fifo_rd_en),
        .fifo_empty (tb_fifo_empty),
        .fifo_dout  (tb_fifo_dout),

        .s_axis_tready (tb_s_axis_tready),
        .s_axis_tvalid (tb_s_axis_tvalid),
        .s_axis_tdata  (tb_s_axis_tdata),

        .m_axis_tready (tb_m_axis_tready),
        .m_axis_tvalid (tb_m_axis_tvalid),
        .m_axis_tdata  (tb_m_axis_tdata)
    );

    function automatic logic [31:0] lane_out(int lane);
        return tb_m_axis_tdata[lane*32+:32];
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

    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        tb_s_axis_tvalid = 1'b1;
        tb_s_axis_tdata  = '0;
        tb_fifo_empty    = 1'b1;
        tb_fifo_dout     = '0;
        tb_m_axis_tready = 1'b1;
        reset_dut();
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    task automatic reset_dut();
        tb_rstn = 1'b0;
        repeat(4) @(posedge tb_clk);
        tb_rstn = 1'b1;
        repeat(25) @(posedge tb_clk);
    endtask

    task automatic push_descriptor(input logic [87:0] descr);
        @(negedge tb_clk);
        tb_fifo_dout  = descr;
        tb_fifo_empty = 1'b0;
        wait (tb_fifo_rd_en === 1'b1);
        @(posedge tb_clk);
        @(negedge tb_clk);
        tb_fifo_empty = 1'b1;
        repeat(25) @(posedge tb_clk);
        @(negedge tb_clk);
    endtask

    task automatic drive_const_input(input logic [15:0] v);
        int i;
        for (i = 0; i < N; i++)
            tb_s_axis_tdata[i*16+:16] = v;
    endtask

    `SVUNIT_TESTS_BEGIN
    `include "down_conversion_ro_v3_tests.sv"
    `SVUNIT_TESTS_END

endmodule
