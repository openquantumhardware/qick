// ============================================================================
// File: sg_int4_tc00.sv
// Description: SVUnit testbench top-level for sg_int4.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module sg_int4_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "sg_int4_ut";
    svunit_testcase svunit_ut;

    localparam real CLOCK_FREQUENCY = 200e6;
    localparam int  N     = 8;   // small memory for sim
    localparam int  N_DDS = 4;

    logic tb_clk  = 1'b0;
    logic tb_rstn = 1'b1;

    clk_gen #(.FREQ (CLOCK_FREQUENCY)) u_clk (.i_enable(1'b1), .o_clk(tb_clk));

    logic         tb_fifo_rd_en_o;
    logic         tb_fifo_empty_i;
    logic [159:0] tb_fifo_dout_i;

    logic [N-1:0] tb_mem_addr_o;
    logic [15:0]  tb_mem_dout_real_i;
    logic [15:0]  tb_mem_dout_imag_i;

    logic                 tb_m_axis_tready_i;
    logic                 tb_m_axis_tvalid_o;
    logic [N_DDS*32-1:0]  tb_m_axis_tdata_o;

    initial begin
        $dumpfile("sg_int4.vcd");
        $dumpvars();
    end

    sg_int4 #(
        .N     (N),
        .N_DDS (N_DDS)
    ) dut (
        .rstn (tb_rstn),
        .clk  (tb_clk),

        .fifo_rd_en_o (tb_fifo_rd_en_o),
        .fifo_empty_i (tb_fifo_empty_i),
        .fifo_dout_i  (tb_fifo_dout_i),

        .mem_addr_o      (tb_mem_addr_o),
        .mem_dout_real_i (tb_mem_dout_real_i),
        .mem_dout_imag_i (tb_mem_dout_imag_i),

        .m_axis_tready_i (tb_m_axis_tready_i),
        .m_axis_tvalid_o (tb_m_axis_tvalid_o),
        .m_axis_tdata_o  (tb_m_axis_tdata_o)
    );

    // Constant envelope: the testbench acts as a trivial "memory" that
    // always returns the same real/imag sample regardless of mem_addr_o
    // (a real BRAM is exercised by axis_to_bram_sg's own testbench and by
    // the full IP's integration test).
    logic [15:0] tb_env_real;
    logic [15:0] tb_env_imag;
    assign tb_mem_dout_real_i = tb_env_real;
    assign tb_mem_dout_imag_i = tb_env_imag;

    // Waveform descriptor builder (v4/int4 160-bit layout, matches ctrl_sgv4).
    function automatic logic [159:0] build_descr(
        input logic [31:0] freq,  input logic [31:0] phase,
        input logic [15:0] addr,  input logic [15:0] gain,
        input logic [15:0] nsamp, input logic [1:0]  outsel,
        input logic mode, input logic stdysel, input logic phrst
    );
        logic [159:0] d = '0;
        d[31:0]   = freq;
        d[63:32]  = phase;
        d[79:64]  = addr;
        d[111:96] = gain;
        d[143:128]= nsamp;
        d[145:144]= outsel;
        d[146]    = mode;
        d[147]    = stdysel;
        d[148]    = phrst;
        return d;
    endfunction

    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        tb_fifo_empty_i    = 1'b1;
        tb_fifo_dout_i     = '0;
        tb_m_axis_tready_i = 1'b1;
        tb_env_real        = 16'sd16384;
        tb_env_imag        = 16'sd0;
        reset_dut();
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    task automatic reset_dut();
        tb_rstn = 1'b0;
        repeat(4) @(posedge tb_clk);
        tb_rstn = 1'b1;
        repeat(40) @(posedge tb_clk);
    endtask

    // Presents one descriptor for exactly one cycle: the DUT is expected to
    // sample it via fifo_rd_en_o while empty is low, same as a real
    // single-entry fifo pop.
    task automatic push_descriptor(input logic [159:0] descr);
        @(negedge tb_clk);
        tb_fifo_dout_i  = descr;
        tb_fifo_empty_i = 1'b0;
        wait (tb_fifo_rd_en_o === 1'b1);
        @(posedge tb_clk);
        @(negedge tb_clk);
        tb_fifo_empty_i = 1'b1;
    endtask

    task automatic wait_for_mvalid(input logic value, input int max_cycles, output bit reached);
        int n;
        reached = 1'b0;
        for (n = 0; n < max_cycles; n++) begin
            if (tb_m_axis_tvalid_o === value) begin
                reached = 1'b1;
                break;
            end
            @(posedge tb_clk);
        end
    endtask

    `SVUNIT_TESTS_BEGIN
    `include "sg_int4_tests.sv"
    `SVUNIT_TESTS_END

endmodule
