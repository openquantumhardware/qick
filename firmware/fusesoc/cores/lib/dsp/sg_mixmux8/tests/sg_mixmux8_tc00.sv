// ============================================================================
// File: sg_mixmux8_tc00.sv
// Description: SVUnit testbench top-level for sg_mixmux8.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module sg_mixmux8_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "sg_mixmux8_ut";
    svunit_testcase svunit_ut;

    localparam real CLOCK_FREQUENCY = 200e6;
    localparam int  N_DDS           = 2;

    logic tb_clk     = 1'b0;
    logic tb_aresetn = 1'b1;

    clk_gen #(.FREQ (CLOCK_FREQUENCY)) u_clk (.i_enable(1'b1), .o_clk(tb_clk));

    logic                tb_s_axis_tready_o;
    logic                tb_s_axis_tvalid_i;
    logic [39:0]         tb_s_axis_tdata_i;

    logic                tb_m_axis_tready_i;
    logic                tb_m_axis_tvalid_o;
    logic [N_DDS*32-1:0] tb_m_axis_tdata_o;

    logic [31:0] tb_pinc_reg [8];
    logic [31:0] tb_poff_reg [8];
    logic [15:0] tb_gain_reg [8];
    logic        tb_we_reg;

    initial begin
        $dumpfile("sg_mixmux8.vcd");
        $dumpvars();
    end

    sg_mixmux8 #(
        .N_DDS (N_DDS)
    ) dut (
        .aresetn (tb_aresetn),
        .aclk    (tb_clk),

        .s_axis_tready_o (tb_s_axis_tready_o),
        .s_axis_tvalid_i (tb_s_axis_tvalid_i),
        .s_axis_tdata_i  (tb_s_axis_tdata_i),

        .m_axis_tready_i (tb_m_axis_tready_i),
        .m_axis_tvalid_o (tb_m_axis_tvalid_o),
        .m_axis_tdata_o  (tb_m_axis_tdata_o),

        .pinc0_reg (tb_pinc_reg[0]), .pinc1_reg (tb_pinc_reg[1]),
        .pinc2_reg (tb_pinc_reg[2]), .pinc3_reg (tb_pinc_reg[3]),
        .pinc4_reg (tb_pinc_reg[4]), .pinc5_reg (tb_pinc_reg[5]),
        .pinc6_reg (tb_pinc_reg[6]), .pinc7_reg (tb_pinc_reg[7]),
        .poff0_reg (tb_poff_reg[0]), .poff1_reg (tb_poff_reg[1]),
        .poff2_reg (tb_poff_reg[2]), .poff3_reg (tb_poff_reg[3]),
        .poff4_reg (tb_poff_reg[4]), .poff5_reg (tb_poff_reg[5]),
        .poff6_reg (tb_poff_reg[6]), .poff7_reg (tb_poff_reg[7]),
        .gain0_reg (tb_gain_reg[0]), .gain1_reg (tb_gain_reg[1]),
        .gain2_reg (tb_gain_reg[2]), .gain3_reg (tb_gain_reg[3]),
        .gain4_reg (tb_gain_reg[4]), .gain5_reg (tb_gain_reg[5]),
        .gain6_reg (tb_gain_reg[6]), .gain7_reg (tb_gain_reg[7]),
        .we_reg    (tb_we_reg)
    );

    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        tb_s_axis_tvalid_i = 1'b0;
        tb_s_axis_tdata_i  = '0;
        tb_m_axis_tready_i = 1'b1;
        tb_we_reg          = 1'b0;
        for (int i = 0; i < 8; i++) begin
            tb_pinc_reg[i] = '0;
            tb_poff_reg[i] = '0;
            tb_gain_reg[i] = '0;
        end
        reset_dut();
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    task automatic reset_dut();
        tb_aresetn = 1'b0;
        repeat(4) @(posedge tb_clk);
        tb_aresetn = 1'b1;
        repeat(20) @(posedge tb_clk);
    endtask

    task automatic write_channel_regs(input int ch, input logic [31:0] pinc, input logic [31:0] poff, input logic [15:0] gain);
        @(negedge tb_clk);
        tb_pinc_reg[ch] = pinc;
        tb_poff_reg[ch] = poff;
        tb_gain_reg[ch] = gain;
        tb_we_reg       = 1'b1;
        repeat(4) @(posedge tb_clk);
        @(negedge tb_clk);
        tb_we_reg = 1'b0;
    endtask

    task automatic push_descriptor(input logic [7:0] mask, input logic [31:0] nsamp);
        @(negedge tb_clk);
        tb_s_axis_tdata_i  = {mask, nsamp};
        tb_s_axis_tvalid_i = 1'b1;
        @(posedge tb_clk);
        @(negedge tb_clk);
        tb_s_axis_tvalid_i = 1'b0;
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
    `include "sg_mixmux8_tests.sv"
    `SVUNIT_TESTS_END

endmodule
