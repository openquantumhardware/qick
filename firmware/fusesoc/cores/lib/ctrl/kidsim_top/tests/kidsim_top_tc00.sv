// ============================================================================
// File: kidsim_top_tc00.sv
// Description: SVUnit testbench top-level for kidsim_top (QICK / axis_kidsim_v3).
//   Puncturing + kidsim datapath + latency-matched bypass mux. Verifies the
//   WE-resync config latch, the frame-sample selection (punct), the mux
//   (processed vs bypass), and the total latency (16 = 2 din_align + 14 kidsim).
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module kidsim_top_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "kidsim_top_ut";
    svunit_testcase svunit_ut;

    // =========================================================================
    // Parameters
    // =========================================================================
    localparam real CLOCK_FREQUENCY = 250e6;
    localparam int  KIDSIM_LAT = 14;
    //! raw din -> o_dout is KIDSIM_LAT + 2 = 16 register stages. The tests
    //! count clocking events from the one that drives the marker, which sees
    //! the output one event earlier: 15 (the same for valid, bypass and
    //! processed data, see tc_measure_both_paths).
    localparam int  TOP_LAT    = KIDSIM_LAT + 1;

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
    logic        tb_din_valid  = 1'b0;
    logic [31:0] tb_din        = '0;
    logic        tb_din_last   = 1'b0;
    logic        tb_dout_valid;
    logic [31:0] tb_dout;
    logic        tb_dout_last;

    logic [15:0] tb_dds_bval  = '0;
    logic [15:0] tb_dds_slope = '0;
    logic [15:0] tb_dds_steps = '0;
    logic [15:0] tb_dds_wait  = '0;
    logic [15:0] tb_dds_freq  = '0;
    logic [15:0] tb_iir_c0    = '0;
    logic [15:0] tb_iir_c1    = '0;
    logic [15:0] tb_iir_g     = '0;
    logic [ 1:0] tb_outsel    = '0;
    logic [15:0] tb_punct_id  = '0;
    logic        tb_we        = 1'b0;

    // Split I/Q for inspection.
    logic signed [15:0] tb_dout_i, tb_dout_q;
    assign tb_dout_i = tb_dout[15:0];
    assign tb_dout_q = tb_dout[31:16];

    // =========================================================================
    // Clocking block
    // =========================================================================
    default clocking tb_cb @(posedge tb_clk);
        default input #1step output #2;
        output tb_rstn;
        output tb_trigger;
        output tb_din_valid;
        output tb_din;
        output tb_din_last;
        output tb_dds_bval;
        output tb_dds_slope;
        output tb_dds_steps;
        output tb_dds_wait;
        output tb_dds_freq;
        output tb_iir_c0;
        output tb_iir_c1;
        output tb_iir_g;
        output tb_outsel;
        output tb_punct_id;
        output tb_we;
        input  tb_dout_valid;
        input  tb_dout;
        input  tb_dout_last;
        input  tb_dout_i;
        input  tb_dout_q;
    endclocking

    // =========================================================================
    // Dump
    // =========================================================================
    initial begin
        $dumpfile("kidsim_top.vcd");
        $dumpvars();
    end

    // =========================================================================
    // DUT
    // =========================================================================
    kidsim_top #(
        .KIDSIM_LAT (KIDSIM_LAT)
    ) dut (
        .i_clk          (tb_clk),
        .i_rstn         (tb_rstn),
        .i_trigger      (tb_trigger),
        .i_din_valid    (tb_din_valid),
        .i_din          (tb_din),
        .i_din_last     (tb_din_last),
        .o_dout_valid   (tb_dout_valid),
        .o_dout         (tb_dout),
        .o_dout_last    (tb_dout_last),
        .i_dds_bval_reg (tb_dds_bval),
        .i_dds_slope_reg(tb_dds_slope),
        .i_dds_steps_reg(tb_dds_steps),
        .i_dds_wait_reg (tb_dds_wait),
        .i_dds_freq_reg (tb_dds_freq),
        .i_iir_c0_reg   (tb_iir_c0),
        .i_iir_c1_reg   (tb_iir_c1),
        .i_iir_g_reg    (tb_iir_g),
        .i_outsel_reg   (tb_outsel),
        .i_punct_id_reg (tb_punct_id),
        .i_we_reg       (tb_we)
    );

    // =========================================================================
    // Helpers
    // =========================================================================
    task automatic reset_dut();
        tb_cb.tb_rstn       <= 1'b0;
        tb_cb.tb_trigger    <= 1'b0;
        tb_cb.tb_din_valid  <= 1'b0;
        tb_cb.tb_din        <= '0;
        tb_cb.tb_din_last   <= 1'b0;
        tb_cb.tb_dds_bval   <= '0;
        tb_cb.tb_dds_slope  <= '0;
        tb_cb.tb_dds_steps  <= '0;
        tb_cb.tb_dds_wait   <= '0;
        tb_cb.tb_dds_freq   <= '0;
        tb_cb.tb_iir_c0     <= '0;
        tb_cb.tb_iir_c1     <= '0;
        tb_cb.tb_iir_g      <= '0;
        tb_cb.tb_outsel     <= '0;
        tb_cb.tb_punct_id   <= '0;
        tb_cb.tb_we         <= 1'b0;
        repeat(5) @(tb_cb);
        tb_cb.tb_rstn <= 1'b1;
        repeat(2) @(tb_cb);
    endtask

    function automatic logic [31:0] pack_qi(input int q, input int i);
        return {q[15:0], i[15:0]};
    endfunction

    // Drive the register bank and pulse WE (resynced 2 cycles inside the DUT).
    task automatic write_config(input int outsel, input int punct_id,
                                input int freq,   input int c0,
                                input int c1,     input int g);
        tb_cb.tb_outsel    <= outsel[1:0];
        tb_cb.tb_punct_id  <= punct_id[15:0];
        tb_cb.tb_dds_freq  <= freq[15:0];
        tb_cb.tb_iir_c0    <= c0[15:0];
        tb_cb.tb_iir_c1    <= c1[15:0];
        tb_cb.tb_iir_g     <= g[15:0];
        tb_cb.tb_we        <= 1'b1;
        @(tb_cb);
        tb_cb.tb_we <= 1'b0;
        // wait for the cdc resync (2 FF) + the latch cycle to settle
        repeat(5) @(tb_cb);
    endtask

    // The DDS IP gives no output valid for its first 8 input transactions after
    // configuration (its pipeline moves only on valid, and it has no reset).
    // Send one-sample frames through the selected slot until it is full.
    task automatic prime_dds();
        repeat(10) begin
            tb_cb.tb_din_valid <= 1'b1;
            tb_cb.tb_din_last  <= 1'b1;
            @(tb_cb);
            tb_cb.tb_din_valid <= 1'b0;
            tb_cb.tb_din_last  <= 1'b0;
            repeat(3) @(tb_cb);
        end
        repeat(TOP_LAT + 4) @(tb_cb);
    endtask

    // Drive one frame of `len` valid samples (last on the final one).
    // Each sample is a distinct value so we can track selection.
    task automatic send_frame(input int len, input int base);
        for (int k = 0; k < len; k++) begin
            tb_cb.tb_din_valid <= 1'b1;
            tb_cb.tb_din_last  <= (k == len-1);
            tb_cb.tb_din       <= pack_qi(base + k, base + k + 100);
            @(tb_cb);
        end
        tb_cb.tb_din_valid <= 1'b0;
        tb_cb.tb_din_last  <= 1'b0;
        tb_cb.tb_din       <= '0;
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
        tb_cb.tb_din_valid <= 1'b0;
        tb_cb.tb_we        <= 1'b0;
        repeat(2) @(tb_cb);
    endtask

    `SVUNIT_TESTS_BEGIN
    `include "kidsim_top_tests.sv"
    `SVUNIT_TESTS_END

endmodule