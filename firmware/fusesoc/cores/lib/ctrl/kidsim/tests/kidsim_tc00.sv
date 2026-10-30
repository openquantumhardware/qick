// ============================================================================
// File: kidsim_tc00.sv
// Description: SVUnit testbench top-level for the kidsim internal datapath.
//   dds_chirp -> prod0 (demod) -> iir_iq (resonator) -> prod1 (remod) -> mux.
//   Main path latency = DDS_LATENCY(2) + cmult(4) + iir(4) + cmult(4) = 14
//   clocks (the DDS IP adds 0 clocks: its output valid is its input valid).
//   Verifies latency, the OUTSEL mux paths, CW pass-through, and that the
//   chirp is aligned end-to-end.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module kidsim_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "kidsim_ut";
    svunit_testcase svunit_ut;

    // =========================================================================
    // Parameters
    // =========================================================================
    localparam real CLOCK_FREQUENCY = 250e6;
    localparam int  MAIN_LAT = 14;   //! din_valid -> o_dout (main path, OUTSEL=0)

    // =========================================================================
    // Clock & Reset
    // =========================================================================
    logic tb_clk  = 1'b0;
    logic tb_rstn = 1'b1;
    clk_gen #(.FREQ (CLOCK_FREQUENCY)) u_clk (.i_enable(1'b1), .o_clk(tb_clk));

    // =========================================================================
    // DUT signals
    // =========================================================================
    logic        tb_trigger    = 1'b0;
    logic [31:0] tb_din        = '0;
    logic        tb_din_valid  = 1'b0;
    logic [31:0] tb_dout;
    logic        tb_dout_valid;

    logic [15:0] tb_dds_bval  = '0;
    logic [15:0] tb_dds_slope = '0;
    logic [15:0] tb_dds_steps = '0;
    logic [15:0] tb_dds_wait  = '0;
    logic [15:0] tb_dds_freq  = '0;
    logic [15:0] tb_iir_c0    = '0;
    logic [15:0] tb_iir_c1    = '0;
    logic [15:0] tb_iir_g     = '0;
    logic [ 1:0] tb_outsel    = '0;

    // Split I/Q of din and dout for inspection.
    logic signed [15:0] tb_din_i,  tb_din_q;
    logic signed [15:0] tb_dout_i, tb_dout_q;
    assign tb_din_i  = tb_din[15:0];
    assign tb_din_q  = tb_din[31:16];
    assign tb_dout_i = tb_dout[15:0];
    assign tb_dout_q = tb_dout[31:16];

    // =========================================================================
    // Clocking block
    // =========================================================================
    default clocking tb_cb @(posedge tb_clk);
        default input #1step output #2;
        output tb_rstn;
        output tb_trigger;
        output tb_din;
        output tb_din_valid;
        output tb_dds_bval;
        output tb_dds_slope;
        output tb_dds_steps;
        output tb_dds_wait;
        output tb_dds_freq;
        output tb_iir_c0;
        output tb_iir_c1;
        output tb_iir_g;
        output tb_outsel;
        input  tb_dout;
        input  tb_dout_valid;
        input  tb_dout_i;
        input  tb_dout_q;
    endclocking

    // =========================================================================
    // Dump
    // =========================================================================
    initial begin
        $dumpfile("kidsim.vcd");
        $dumpvars();
    end

    // =========================================================================
    // DUT
    // =========================================================================
    kidsim #(
        .DDS_LATENCY (2)
    ) dut (
        .i_clk           (tb_clk),
        .i_rstn          (tb_rstn),
        .i_trigger       (tb_trigger),
        .i_din           (tb_din),
        .i_din_valid     (tb_din_valid),
        .o_dout          (tb_dout),
        .o_dout_valid    (tb_dout_valid),
        .i_dds_bval_reg  (tb_dds_bval),
        .i_dds_slope_reg (tb_dds_slope),
        .i_dds_steps_reg (tb_dds_steps),
        .i_dds_wait_reg  (tb_dds_wait),
        .i_dds_freq_reg  (tb_dds_freq),
        .i_iir_c0_reg    (tb_iir_c0),
        .i_iir_c1_reg    (tb_iir_c1),
        .i_iir_g_reg     (tb_iir_g),
        .i_outsel_reg    (tb_outsel)
    );

    // =========================================================================
    // Helpers
    // =========================================================================
    task automatic reset_dut();
        tb_cb.tb_rstn       <= 1'b0;
        tb_cb.tb_trigger    <= 1'b0;
        tb_cb.tb_din        <= '0;
        tb_cb.tb_din_valid  <= 1'b0;
        tb_cb.tb_dds_bval   <= '0;
        tb_cb.tb_dds_slope  <= '0;
        tb_cb.tb_dds_steps  <= '0;
        tb_cb.tb_dds_wait   <= '0;
        tb_cb.tb_dds_freq   <= '0;
        tb_cb.tb_iir_c0     <= '0;
        tb_cb.tb_iir_c1     <= '0;
        tb_cb.tb_iir_g      <= '0;
        tb_cb.tb_outsel     <= '0;
        repeat(5) @(tb_cb);
        tb_cb.tb_rstn <= 1'b1;
        repeat(2) @(tb_cb);
    endtask

    // Pack {Q, I} into a 32-bit sample.
    function automatic logic [31:0] pack_qi(input int q, input int i);
        return {q[15:0], i[15:0]};
    endfunction

    // =========================================================================
    // SVUnit
    // =========================================================================
    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        reset_dut();
    endtask

    task teardown();
        svunit_ut.teardown();
        tb_cb.tb_din_valid <= 1'b0;
        tb_cb.tb_trigger   <= 1'b0;
        repeat(2) @(tb_cb);
    endtask

    `SVUNIT_TESTS_BEGIN
    `include "kidsim_tests.sv"
    `SVUNIT_TESTS_END

endmodule