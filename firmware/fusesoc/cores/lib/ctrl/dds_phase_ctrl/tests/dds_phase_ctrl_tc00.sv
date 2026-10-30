// ============================================================================
// File: dds_phase_ctrl_tc00.sv
// Description: SVUnit testbench top-level for dds_phase_ctrl.
//   DDS phase-increment controller with linear frequency modulation (chirp).
//   pinc = FREQ_REG - ramp(n), ramp(n) = B - n*M (from ramp_gen), no pinc
//   saturation (phase increment is circular / mod 2^16). Trigger is resynced
//   with cdc_bit_sync. A software model computes the expected control word.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module dds_phase_ctrl_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "dds_phase_ctrl_ut";
    svunit_testcase svunit_ut;

    // =========================================================================
    // Parameters
    // =========================================================================
    localparam real CLOCK_FREQUENCY = 250e6;
    localparam int  DATA_W = 16;

    localparam longint SAT_MAX =  (1 << (DATA_W-1)) - 1;
    localparam longint SAT_MIN = -(1 << (DATA_W-1));

    localparam int  LAT = 5;   //! trigger -> pinc(0): cdc(2)+ramp_gen(~1)+pipe(2)

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
    endclocking

    // =========================================================================
    // Dump
    // =========================================================================
    initial begin
        $dumpfile("dds_phase_ctrl.vcd");
        $dumpvars();
    end

    // =========================================================================
    // DUT
    // =========================================================================
    dds_phase_ctrl dut (
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
    // Reference model
    // =========================================================================
    // Signed saturation to DATA_W (ramp_gen behaviour, reused here).
    function automatic longint sat_data(input longint v);
        if (v > SAT_MAX)      return SAT_MAX;
        else if (v < SAT_MIN) return SAT_MIN;
        else                  return v;
    endfunction

    // ramp_gen model: ms(n)=sat(ms(n-1)+M), ms(0)=0; y(n)=sat(B-ms(n)).
    function automatic longint golden_ms(input longint m, input int n);
        longint acc;
        acc = 0;
        for (int k = 1; k <= n; k++) acc = sat_data(acc + m);
        return acc;
    endfunction

    function automatic longint golden_ramp(input longint b, input longint m, input int n);
        return sat_data(b - golden_ms(m, n));
    endfunction

    // Expected DDS control word for ramp index n:
    //   pinc = (FREQ_REG - ramp(n)) mod 2^16 ; dout = {16'b0, pinc}.
    function automatic logic [31:0] golden_dout(input longint freq, input longint b,
                                                input longint m, input int n);
        logic [15:0] ramp16;
        logic [15:0] pinc;
        ramp16 = golden_ramp(b, m, n);        // signed value, low 16 bits
        pinc   = freq[15:0] - ramp16;          // unsigned wrap (mod 2^16)
        return {16'b0, pinc};
    endfunction

    // =========================================================================
    // Helpers
    // =========================================================================
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

    task automatic set_params(input longint freq, input longint b, input longint m,
                              input int n, input int w);
        tb_cb.tb_freq_reg  <= freq[15:0];
        tb_cb.tb_bval_reg  <= b[15:0];
        tb_cb.tb_slope_reg <= m[15:0];
        tb_cb.tb_steps_reg <= n[15:0];
        tb_cb.tb_wait_reg  <= w[15:0];
    endtask

    // One-cycle trigger pulse (async input; cdc_bit_sync resyncs it inside).
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
    `include "dds_phase_ctrl_tests.sv"
    `SVUNIT_TESTS_END

endmodule