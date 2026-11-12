// ============================================================================
// File: ramp_gen_tc00.sv
// Description: SVUnit testbench top-level for ramp_gen (QICK / axis_kidsim_v3).
//   Linear ramp generator: on trigger emits y = B - n*M for n in [0, N_STEPS],
//   one step every WAIT cycles, with double signed saturation (on n*M and on
//   B - n*M). A software reference model computes the expected samples.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module ramp_gen_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "ramp_gen_ut";
    svunit_testcase svunit_ut;

    // =========================================================================
    // Parameters (match the DUT defaults)
    // =========================================================================
    localparam real CLOCK_FREQUENCY = 250e6;
    localparam int  DATA_W = 16;
    localparam int  CNT_W  = 16;

    localparam longint SAT_MAX =  (1 << (DATA_W-1)) - 1;   //  32767
    localparam longint SAT_MIN = -(1 << (DATA_W-1));       // -32768

    // =========================================================================
    // Clock & Reset
    // =========================================================================
    logic tb_clk  = 1'b0;
    logic tb_rstn = 1'b1;

    clk_gen #(.FREQ (CLOCK_FREQUENCY)) u_clk (.i_enable(1'b1), .o_clk(tb_clk));

    // =========================================================================
    // DUT signals
    // =========================================================================
    logic                     tb_trigger = 1'b0;
    logic                     tb_en      = 1'b0;
    logic signed [DATA_W-1:0] tb_b       = '0;
    logic signed [DATA_W-1:0] tb_m       = '0;
    logic        [CNT_W-1:0]  tb_n_steps = '0;
    logic        [CNT_W-1:0]  tb_wait    = '0;
    logic signed [DATA_W-1:0] tb_y;

    // =========================================================================
    // Clocking block
    // =========================================================================
    default clocking tb_cb @(posedge tb_clk);
        default input #1step output #2;
        output tb_rstn;
        output tb_trigger;
        output tb_en;
        output tb_b;
        output tb_m;
        output tb_n_steps;
        output tb_wait;
        input  tb_y;
    endclocking

    // =========================================================================
    // Dump
    // =========================================================================
    initial begin
        $dumpfile("ramp_gen.vcd");
        $dumpvars();
    end

    // =========================================================================
    // DUT
    // =========================================================================
    ramp_gen #(
        .DATA_W (DATA_W),
        .CNT_W  (CNT_W)
    ) dut (
        .i_clk     (tb_clk),
        .i_rstn    (tb_rstn),
        .i_trigger (tb_trigger),
        .i_en      (tb_en),
        .i_b       (tb_b),
        .i_m       (tb_m),
        .i_n_steps (tb_n_steps),
        .i_wait    (tb_wait),
        .o_y       (tb_y)
    );

    // =========================================================================
    // Reference model
    // =========================================================================
    // Signed saturation to DATA_W (matches RTL clip behaviour).
    function automatic longint sat_data(input longint v);
        if (v > SAT_MAX)      return SAT_MAX;
        else if (v < SAT_MIN) return SAT_MIN;
        else                  return v;
    endfunction

    // Expected ms(n) = sat(ms(n-1) + M), ms(0) = 0.
    function automatic longint golden_ms(input longint m, input int n);
        longint acc;
        acc = 0;
        for (int k = 1; k <= n; k++) acc = sat_data(acc + m);
        return acc;
    endfunction

    // Expected y(n) = sat(B - ms(n)).
    function automatic longint golden_y(input longint b, input longint m, input int n);
        return sat_data(b - golden_ms(m, n));
    endfunction

    // =========================================================================
    // Helpers
    // =========================================================================
    task automatic reset_dut();
        tb_cb.tb_rstn    <= 1'b0;
        tb_cb.tb_trigger <= 1'b0;
        tb_cb.tb_en      <= 1'b0;
        tb_cb.tb_b       <= '0;
        tb_cb.tb_m       <= '0;
        tb_cb.tb_n_steps <= '0;
        tb_cb.tb_wait    <= '0;
        repeat(5) @(tb_cb);
        tb_cb.tb_rstn <= 1'b1;
        repeat(2) @(tb_cb);
    endtask

    // Drive the ramp parameters (latched by DUT while in INIT).
    task automatic set_params(input longint b, input longint m,
                              input int n, input int w);
        tb_cb.tb_b       <= b[DATA_W-1:0];
        tb_cb.tb_m       <= m[DATA_W-1:0];
        tb_cb.tb_n_steps <= n[CNT_W-1:0];
        tb_cb.tb_wait    <= w[CNT_W-1:0];
    endtask

    // One-cycle trigger pulse (assumed already synced to tb_clk).
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
        tb_cb.tb_trigger <= 1'b0;
        tb_cb.tb_en      <= 1'b0;
        repeat(2) @(tb_cb);
    endtask

    `SVUNIT_TESTS_BEGIN
    `include "ramp_gen_tests.sv"
    `SVUNIT_TESTS_END

endmodule