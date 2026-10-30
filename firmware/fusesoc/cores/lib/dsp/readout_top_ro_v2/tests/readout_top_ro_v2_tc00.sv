// ============================================================================
// File: readout_top_ro_v2_tc00.sv
// Description: SVUnit integration testbench for readout_top_ro_v2.
//
//   Full datapath flow: drive FREQ/PHASE/NSAMP/OUTSEL/MODE registers, pulse
//   WE_REG (from a separate s_axi_aclk domain), drive a constant ADC
//   sample on s_axis, observe m0_axis (undecimated) and m1_axis (decimated).
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module readout_top_ro_v2_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "readout_top_ro_v2_ut";
    svunit_testcase svunit_ut;

    localparam real AXI_FREQ  = 100e6;
    localparam real ACLK_FREQ = 200e6;
    localparam int  N_DDS = 8;

    logic s_axi_aclk = 1'b0;
    logic tb_aresetn = 1'b1;
    logic tb_aclk    = 1'b0;

    clk_gen #(.FREQ (AXI_FREQ))  u_axi (.i_enable(1'b1), .o_clk(s_axi_aclk));
    clk_gen #(.FREQ (ACLK_FREQ)) u_a   (.i_enable(1'b1), .o_clk(tb_aclk));

    logic                 tb_s_axis_tvalid;
    logic                 tb_s_axis_tready;
    logic [N_DDS*16-1:0]  tb_s_axis_tdata;

    logic                 tb_m0_axis_tready;
    logic                 tb_m0_axis_tvalid;
    logic [N_DDS*32-1:0]  tb_m0_axis_tdata;

    logic         tb_m1_axis_tready;
    logic         tb_m1_axis_tvalid;
    logic [31:0]  tb_m1_axis_tdata;

    logic [31:0] tb_freq_reg;
    logic [31:0] tb_phase_reg;
    logic [15:0] tb_nsamp_reg;
    logic [1:0]  tb_outsel_reg;
    logic        tb_mode_reg;
    logic        tb_we_reg;

    initial begin
        $dumpfile("readout_top_ro_v2.vcd");
        $dumpvars();
    end

    readout_top_ro_v2 #(
        .N_DDS (N_DDS)
    ) dut (
        .aresetn (tb_aresetn),
        .aclk    (tb_aclk),

        .s_axis_tvalid (tb_s_axis_tvalid),
        .s_axis_tready (tb_s_axis_tready),
        .s_axis_tdata  (tb_s_axis_tdata),

        .m0_axis_tready (tb_m0_axis_tready),
        .m0_axis_tvalid (tb_m0_axis_tvalid),
        .m0_axis_tdata  (tb_m0_axis_tdata),

        .m1_axis_tready (tb_m1_axis_tready),
        .m1_axis_tvalid (tb_m1_axis_tvalid),
        .m1_axis_tdata  (tb_m1_axis_tdata),

        .freq_reg   (tb_freq_reg),
        .phase_reg  (tb_phase_reg),
        .nsamp_reg  (tb_nsamp_reg),
        .outsel_reg (tb_outsel_reg),
        .mode_reg   (tb_mode_reg),
        .we_reg     (tb_we_reg)
    );

    function automatic logic [31:0] m0_lane(int lane);
        return tb_m0_axis_tdata[lane*32+:32];
    endfunction

    task automatic push_descriptor(
        input logic [31:0] freq, input logic [31:0] phase,
        input logic [15:0] nsamp, input logic [1:0] outsel,
        input logic mode
    );
        @(negedge s_axi_aclk);
        tb_freq_reg   = freq;
        tb_phase_reg  = phase;
        tb_nsamp_reg  = nsamp;
        tb_outsel_reg = outsel;
        tb_mode_reg   = mode;
        tb_we_reg     = 1'b1;
        repeat(4) @(posedge s_axi_aclk);
        @(negedge s_axi_aclk);
        tb_we_reg = 1'b0;
        // CDC margin (cdc_bit_sync, 2 stages) + descriptor pop/settle.
        repeat(30) @(posedge tb_aclk);
    endtask

    task automatic drive_const_input(input logic [15:0] v);
        int i;
        for (i = 0; i < N_DDS; i++)
            tb_s_axis_tdata[i*16+:16] = v;
    endtask

    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        tb_s_axis_tvalid  = 1'b1;
        tb_s_axis_tdata   = '0;
        tb_m0_axis_tready = 1'b1;
        tb_m1_axis_tready = 1'b1;
        tb_freq_reg   = '0;
        tb_phase_reg  = '0;
        tb_nsamp_reg  = '0;
        tb_outsel_reg = '0;
        tb_mode_reg   = 1'b0;
        tb_we_reg     = 1'b0;
        reset_dut();
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    task automatic reset_dut();
        tb_aresetn = 1'b0;
        repeat(4) @(posedge tb_aclk);
        tb_aresetn = 1'b1;
        // History/pipe flush for fir_decim8_dynro (no reset of its own) +
        // XPM fifo settle.
        repeat(60) @(posedge tb_aclk);
    endtask

    `SVUNIT_TESTS_BEGIN
    `include "readout_top_ro_v2_tests.sv"
    `SVUNIT_TESTS_END

endmodule
