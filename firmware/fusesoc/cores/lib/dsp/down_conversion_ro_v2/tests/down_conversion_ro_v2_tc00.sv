// ============================================================================
// File: down_conversion_ro_v2_tc00.sv
// Description: SVUnit testbench top-level for down_conversion_ro_v2.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module down_conversion_ro_v2_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "down_conversion_ro_v2_ut";
    svunit_testcase svunit_ut;

    localparam real CLOCK_FREQUENCY = 200e6;
    localparam int  N_DDS = 4;  // small for sim

    logic tb_clk  = 1'b0;
    logic tb_rstn = 1'b1;

    clk_gen #(.FREQ (CLOCK_FREQUENCY)) u_clk (.i_enable(1'b1), .o_clk(tb_clk));

    logic                 tb_s_axis_tready_o;
    logic                 tb_s_axis_tvalid_i;
    logic [N_DDS*16-1:0]  tb_s_axis_tdata_i;

    logic                 tb_m_axis_tready_i;
    logic                 tb_m_axis_tvalid_o;
    logic [N_DDS*32-1:0]  tb_m_axis_tdata_o;

    logic         tb_fifo_rd_en_o;
    logic         tb_fifo_empty_i;
    logic [82:0]  tb_fifo_dout_i;

    initial begin
        $dumpfile("down_conversion_ro_v2.vcd");
        $dumpvars();
    end

    down_conversion_ro_v2 #(
        .N_DDS (N_DDS)
    ) dut (
        .rstn (tb_rstn),
        .clk  (tb_clk),

        .s_axis_tready_o (tb_s_axis_tready_o),
        .s_axis_tvalid_i (tb_s_axis_tvalid_i),
        .s_axis_tdata_i  (tb_s_axis_tdata_i),

        .m_axis_tready_i (tb_m_axis_tready_i),
        .m_axis_tvalid_o (tb_m_axis_tvalid_o),
        .m_axis_tdata_o  (tb_m_axis_tdata_o),

        .fifo_rd_en_o (tb_fifo_rd_en_o),
        .fifo_empty_i (tb_fifo_empty_i),
        .fifo_dout_i  (tb_fifo_dout_i)
    );

    function automatic logic [31:0] lane_out(int lane);
        return tb_m_axis_tdata_o[lane*32+:32];
    endfunction

    function automatic logic [82:0] build_descr(
        input logic [31:0] freq, input logic [31:0] phase,
        input logic [15:0] nsamp, input logic [1:0] outsel,
        input logic mode
    );
        logic [82:0] d = '0;
        d[31:0]  = freq;
        d[63:32] = phase;
        d[79:64] = nsamp;
        d[81:80] = outsel;
        d[82]    = mode;
        return d;
    endfunction

    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        tb_s_axis_tvalid_i = 1'b1;
        tb_s_axis_tdata_i  = '0;
        tb_fifo_empty_i    = 1'b1;
        tb_fifo_dout_i     = '0;
        tb_m_axis_tready_i = 1'b1;
        reset_dut();
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    task automatic reset_dut();
        tb_rstn = 1'b0;
        repeat(4) @(posedge tb_clk);
        tb_rstn = 1'b1;
        repeat(20) @(posedge tb_clk);
    endtask

    task automatic push_descriptor(input logic [82:0] descr);
        @(negedge tb_clk);
        tb_fifo_dout_i  = descr;
        tb_fifo_empty_i = 1'b0;
        wait (tb_fifo_rd_en_o === 1'b1);
        @(posedge tb_clk);
        @(negedge tb_clk);
        tb_fifo_empty_i = 1'b1;
        repeat(15) @(posedge tb_clk);
        @(negedge tb_clk);
    endtask

    task automatic drive_const_input(input logic [15:0] v);
        int i;
        for (i = 0; i < N_DDS; i++)
            tb_s_axis_tdata_i[i*16+:16] = v;
    endtask

    `SVUNIT_TESTS_BEGIN
    `include "down_conversion_ro_v2_tests.sv"
    `SVUNIT_TESTS_END

endmodule
