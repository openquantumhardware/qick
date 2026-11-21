// ============================================================================
// File: dds_chirp_tc00.sv
// Description: SVUnit testbench top-level for dds_chirp.
//   dds_phase_ctrl (lat 2) + DDS IP (streaming pinc, lat 8) = lat 10.
//   Generates e^{jw(t)} whose frequency sweeps linearly on trigger. The DDS
//   model accumulates pinc internally, so the output is a real sine/cosine.
//   We verify (a) the base-frequency carrier at rest and (b) that the
//   instantaneous phase increment tracks the chirp ramp.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module dds_chirp_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "dds_chirp_ut";
    svunit_testcase svunit_ut;

    // =========================================================================
    // Parameters
    // =========================================================================
    localparam real CLOCK_FREQUENCY = 250e6;
    localparam int  LAT = 0;   //! trigger -> first chirped sample (set from trace)

    // =========================================================================
    // Clock & Reset
    // =========================================================================
    logic tb_clk  = 1'b0;
    logic tb_rstn = 1'b1;
    clk_gen #(.FREQ (CLOCK_FREQUENCY)) u_clk (.i_enable(1'b1), .o_clk(tb_clk));

    // =========================================================================
    // DUT signals
    // =========================================================================
    logic        tb_trigger   = 1'b0;
    logic        tb_din_valid = 1'b0;
    logic [15:0] tb_bval_reg  = '0;
    logic [15:0] tb_slope_reg = '0;
    logic [15:0] tb_steps_reg = '0;
    logic [15:0] tb_wait_reg  = '0;
    logic [15:0] tb_freq_reg  = '0;
    logic        tb_dout_valid;
    logic [31:0] tb_dout;

    // Split the packed output {sin[31:16], cos[15:0]}.
    logic signed [15:0] tb_cos, tb_sin;
    assign tb_cos = tb_dout[15:0];
    assign tb_sin = tb_dout[31:16];

    // =========================================================================
    // Clocking block
    // =========================================================================
    default clocking tb_cb @(posedge tb_clk);
        default input #1step output #2;
        output tb_rstn;
        output tb_trigger;
        output tb_din_valid;
        output tb_bval_reg;
        output tb_slope_reg;
        output tb_steps_reg;
        output tb_wait_reg;
        output tb_freq_reg;
        input  tb_dout_valid;
        input  tb_dout;
        input  tb_cos;
        input  tb_sin;
    endclocking

    // =========================================================================
    // Dump
    // =========================================================================
    initial begin
        $dumpfile("dds_chirp.vcd");
        $dumpvars();
    end

    // =========================================================================
    // DUT
    // =========================================================================
    dds_chirp dut (
        .i_clk        (tb_clk),
        .i_rstn       (tb_rstn),
        .i_trigger    (tb_trigger),
        .i_din_valid  (tb_din_valid),
        .o_dout_valid (tb_dout_valid),
        .o_dout       (tb_dout),
        .i_bval_reg   (tb_bval_reg),
        .i_slope_reg  (tb_slope_reg),
        .i_steps_reg  (tb_steps_reg),
        .i_wait_reg   (tb_wait_reg),
        .i_freq_reg   (tb_freq_reg)
    );

    // =========================================================================
    // Helpers
    // =========================================================================
    // Instantaneous phase (radians) of the current output sample, from atan2.
    function automatic real sample_angle();
        return $atan2(real'(tb_sin), real'(tb_cos));
    endfunction

    task automatic reset_dut();
        tb_cb.tb_rstn       <= 1'b0;
        tb_cb.tb_trigger    <= 1'b0;
        tb_cb.tb_din_valid  <= 1'b0;
        tb_cb.tb_bval_reg   <= '0;
        tb_cb.tb_slope_reg  <= '0;
        tb_cb.tb_steps_reg  <= '0;
        tb_cb.tb_wait_reg   <= '0;
        tb_cb.tb_freq_reg   <= '0;
        repeat(5) @(tb_cb);
        tb_cb.tb_rstn <= 1'b1;
        repeat(2) @(tb_cb);
    endtask

    task automatic set_params(input int freq, input int b, input int m,
                              input int n, input int w);
        tb_cb.tb_freq_reg  <= freq[15:0];
        tb_cb.tb_bval_reg  <= b[15:0];
        tb_cb.tb_slope_reg <= m[15:0];
        tb_cb.tb_steps_reg <= n[15:0];
        tb_cb.tb_wait_reg  <= w[15:0];
    endtask

    task automatic pulse_trigger();
        @(tb_cb);
        tb_cb.tb_trigger <= 1'b1;
        @(tb_cb);
        tb_cb.tb_trigger <= 1'b0;
    endtask

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
        tb_cb.tb_trigger   <= 1'b0;
        tb_cb.tb_din_valid <= 1'b0;
        repeat(2) @(tb_cb);
    endtask

    `SVUNIT_TESTS_BEGIN
    `include "dds_chirp_tests.sv"
    `SVUNIT_TESTS_END

endmodule