// ============================================================================
// File: avg_tc00.sv
// Description: SVUnit testbench top-level for the avg module.
// ============================================================================

`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module avg_unit_test;

    import svunit_pkg::svunit_testcase;

    string name = "avg_ut";
    svunit_testcase svunit_ut;

    localparam real CLOCK_FREQUENCY = 200e6;
    localparam int  N = 10;
    localparam int  B = 16;

    // -------------------------------------------------------------------------
    // Clock & Reset
    // -------------------------------------------------------------------------
    logic tb_clk  = 1'b0;
    logic tb_rstn = 1'b1;

    // -------------------------------------------------------------------------
    // UUT interfaces
    // -------------------------------------------------------------------------
    logic            tb_trigger_i       = 1'b0;
    logic            tb_din_valid_i     = 1'b0;
    logic [2*B-1:0]  tb_din_i           = '0;

    logic            tb_mem_we_o;
    logic [N-1:0]    tb_mem_addr_o;
    logic [4*B-1:0]  tb_mem_di_o;

    logic            tb_start_reg       = 1'b0;
    logic [N-1:0]    tb_addr_reg        = '0;
    logic [31:0]     tb_len_reg         = '0;
    logic            tb_photon_mode_reg = 1'b0;
    logic [B-1:0]    tb_h_thrsh_reg     = '0;
    logic [B-1:0]    tb_l_thrsh_reg     = '0;

    // -------------------------------------------------------------------------
    // Waveform dump
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("avg.vcd");
        $dumpvars();
    end

    // -------------------------------------------------------------------------
    // Clock generator
    // -------------------------------------------------------------------------
    clk_gen #(
        .FREQ (CLOCK_FREQUENCY)
    ) u_clk_gen (
        .i_enable (1'b1),
        .o_clk    (tb_clk)
    );

    // -------------------------------------------------------------------------
    // Clocking block
    // -------------------------------------------------------------------------
    default clocking cb @(posedge tb_clk);
        output tb_rstn;
        output tb_trigger_i;
        output tb_din_valid_i;
        output tb_din_i;
        output tb_start_reg;
        output tb_addr_reg;
        output tb_len_reg;
        output tb_photon_mode_reg;
        output tb_h_thrsh_reg;
        output tb_l_thrsh_reg;
        input  tb_mem_we_o;
        input  tb_mem_addr_o;
        input  tb_mem_di_o;
    endclocking

    // -------------------------------------------------------------------------
    // Unit Under Test
    // -------------------------------------------------------------------------
    avg #(
        .N (N),
        .B (B)
    ) u_avg (
        .rstn            (tb_rstn),
        .clk             (tb_clk),
        .trigger_i       (tb_trigger_i),
        .din_valid_i     (tb_din_valid_i),
        .din_i           (tb_din_i),
        .mem_we_o        (tb_mem_we_o),
        .mem_addr_o      (tb_mem_addr_o),
        .mem_di_o        (tb_mem_di_o),
        .start_reg       (tb_start_reg),
        .addr_reg        (tb_addr_reg),
        .len_reg         (tb_len_reg),
        .photon_mode_reg (tb_photon_mode_reg),
        .h_thrsh_reg     (tb_h_thrsh_reg),
        .l_thrsh_reg     (tb_l_thrsh_reg)
    );

    // =========================================================================
    // Helper tasks — must live in the module scope, NOT inside SVUNIT_TESTS
    // =========================================================================

    // arm_and_trigger: latch config, assert start_reg, wait one cycle for FSM
    // to reach TRIGGER_ST, then pulse trigger_i for one cycle.
    // Leaves FSM in AVG_ST with start_reg=1, trigger_i=0.
    task automatic arm_and_trigger(
        input logic [N-1:0] addr,
        input logic [31:0]  len,
        input logic         photon_mode,
        input logic [B-1:0] h_thrsh,
        input logic [B-1:0] l_thrsh
    );
        cb.tb_addr_reg        <= addr;
        cb.tb_len_reg         <= len;
        cb.tb_photon_mode_reg <= photon_mode;
        cb.tb_h_thrsh_reg     <= h_thrsh;
        cb.tb_l_thrsh_reg     <= l_thrsh;
        cb.tb_start_reg       <= 1'b1;
        @(cb); // FSM: START_ST -> TRIGGER_ST
        cb.tb_trigger_i <= 1'b1;
        @(cb); // FSM: TRIGGER_ST -> AVG_ST
        cb.tb_trigger_i <= 1'b0;
    endtask

    // wait_for_write: poll mem_we_o up to 30 cycles.
    // Sets timed_out=1 if write strobe never appears.
    task automatic wait_for_write(output int timed_out);
        int timeout;
        timed_out = 0;
        timeout   = 0;
        while (cb.tb_mem_we_o == 1'b0) begin
            @(cb);
            timeout++;
            if (timeout > 30) begin
                timed_out = 1;
                return;
            end
        end
    endtask

    // release_fsm: drop start_reg and let FSM settle back to START_ST.
    task automatic release_fsm();
        cb.tb_start_reg <= 1'b0;
        repeat(3) @(cb);
    endtask

    // =========================================================================
    // SVUnit build / setup / teardown
    // =========================================================================
    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        cb.tb_trigger_i       <= 1'b0;
        cb.tb_din_valid_i     <= 1'b0;
        cb.tb_din_i           <= '0;
        cb.tb_start_reg       <= 1'b0;
        cb.tb_addr_reg        <= '0;
        cb.tb_len_reg         <= 32'd0;
        cb.tb_photon_mode_reg <= 1'b0;
        cb.tb_h_thrsh_reg     <= '0;
        cb.tb_l_thrsh_reg     <= '0;
        @(cb);
        cb.tb_rstn <= 1'b0;
        repeat(2) @(cb);
        cb.tb_rstn <= 1'b1;
        repeat(5) @(cb);
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    // =========================================================================
    // Test cases
    // =========================================================================
    `SVUNIT_TESTS_BEGIN
    `include "tests.sv"
    `SVUNIT_TESTS_END

endmodule
