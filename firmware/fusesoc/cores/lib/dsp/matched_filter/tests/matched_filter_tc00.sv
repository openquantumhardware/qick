// ============================================================================
// File: matched_filter_tc00.sv
// Description: SVUnit testbench for matched_filter (single clock domain:
//              write_clk == clk, to keep the CDC aspect out of scope --
//              axis_to_bram_sg's own CDC is already covered elsewhere).
// ============================================================================

`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module matched_filter_unit_test;

    import svunit_pkg::svunit_testcase;

    string name = "matched_filter_ut";
    svunit_testcase svunit_ut;

    localparam real CLOCK_FREQ = 200e6;
    localparam int  N = 6;
    localparam int  B = 16;

    logic tb_clk  = 1'b0;
    logic tb_rstn = 1'b1;

    clk_gen #(.FREQ (CLOCK_FREQ)) u_clk_gen (.i_enable(1'b1), .o_clk(tb_clk));

    axi4_stream_if #(.TDATA_WIDTH(2*B)) wgt_if (.aclk(tb_clk), .aresetn(tb_rstn));

    logic            tb_trigger_i;
    logic            tb_trigger_o;
    logic            tb_din_valid_i;
    logic [2*B-1:0]  tb_din_i;
    logic [2*B-1:0]  tb_dout_o;
    logic            tb_dout_valid_o;
    logic [31:0]     tb_len_reg;
    logic [31:0]     tb_dw_addr_reg;
    logic            tb_we_reg;
    logic [7:0]      tb_trunc_shift_reg;

    default clocking cb @(posedge tb_clk);
        default input #1step output #2;
        output tb_rstn;
        output tb_trigger_i;
        output tb_din_valid_i;
        output tb_din_i;
        output tb_len_reg;
        output tb_dw_addr_reg;
        output tb_we_reg;
        output tb_trunc_shift_reg;
        input  tb_trigger_o;
        input  tb_dout_o;
        input  tb_dout_valid_o;
    endclocking

    matched_filter #(
        .N (N),
        .B (B)
    ) dut (
        .clk            (tb_clk),
        .rstn           (tb_rstn),
        .write_rstn     (tb_rstn),
        .write_clk      (tb_clk),
        .trigger_i      (tb_trigger_i),
        .trigger_o      (tb_trigger_o),
        .s_axis_tready  (wgt_if.tready),
        .s_axis_tdata   (wgt_if.tdata),
        .s_axis_tvalid  (wgt_if.tvalid),
        .din_valid_i    (tb_din_valid_i),
        .din_i          (tb_din_i),
        .dout_o         (tb_dout_o),
        .dout_valid_o   (tb_dout_valid_o),
        .len_reg          (tb_len_reg),
        .dw_addr_reg      (tb_dw_addr_reg),
        .we_reg           (tb_we_reg),
        .trunc_shift_reg  (tb_trunc_shift_reg)
    );

    // =========================================================================
    // Helper tasks
    // =========================================================================

    task automatic pulse_trigger();
        cb.tb_trigger_i <= 1'b1;
        @(cb);
        cb.tb_trigger_i <= 1'b0;
    endtask

    // Wait for dout_valid_o and return dout_o from the same cycle.
    task automatic wait_for_output(output logic [2*B-1:0] data, input int timeout_cycles = 50);
        int timeout = 0;
        while (!cb.tb_dout_valid_o) begin
            @(cb);
            timeout++;
            if (timeout > timeout_cycles) begin
                `FAIL_IF_LOG(1, "wait_for_output: timed out waiting for dout_valid_o");
                return;
            end
        end
        data = cb.tb_dout_o;
    endtask

    // Load n_wgt weights starting at address 0: w[k] = I (k+1)*256, Q 0.
    task automatic load_ramp_weights(input int n_wgt);
        cb.tb_dw_addr_reg <= '0;
        cb.tb_we_reg      <= 1'b1;
        repeat(4) @(cb);
        for (int k = 0; k < n_wgt; k++) wgt_if.tx({16'h0000, 16'((k+1)*256)});
        cb.tb_we_reg <= 1'b0;
        repeat(5) @(cb);
    endtask

    // Trigger, then feed n_smp samples of I=0x4000, Q=0 with din_valid_i high
    // one cycle out of every stride, collecting dout_o on every dout_valid_o.
    // With the ramp weights of load_ramp_weights(), the I of each output is
    // (k+1)*64 for weight k, so outs[n] tells which weight sample n met.
    task automatic run_window(input int n_smp, input int stride, output logic [2*B-1:0] outs[$]);
        outs.delete();
        fork
            begin
                pulse_trigger();
                for (int n = 0; n < n_smp; n++) begin
                    cb.tb_din_valid_i <= 1'b1;
                    cb.tb_din_i       <= {16'h0000, 16'h4000};
                    @(cb);
                    if (stride > 1) begin
                        cb.tb_din_valid_i <= 1'b0;
                        repeat(stride-1) @(cb);
                    end
                end
                cb.tb_din_valid_i <= 1'b0;
                cb.tb_din_i       <= '0;
            end
            begin
                repeat(n_smp*stride + 40) begin
                    @(cb);
                    if (cb.tb_dout_valid_o) outs.push_back(cb.tb_dout_o);
                end
            end
        join
    endtask

    // =========================================================================
    // SVUnit build / setup / teardown
    // =========================================================================
    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();

        cb.tb_trigger_i   <= 1'b0;
        cb.tb_din_valid_i <= 1'b0;
        cb.tb_din_i       <= '0;
        cb.tb_len_reg     <= 32'd10;
        cb.tb_dw_addr_reg <= '0;
        cb.tb_we_reg      <= 1'b0;
        // Matches the module port's own default (8'(B)) -- bit-exact with
        // the legacy fixed truncation unless a test overrides it.
        cb.tb_trunc_shift_reg <= 8'(B);
        // wgt_if.tready is driven by the DUT's weight writer: park only the
        // master side, through the same clocking block tx() drives. Forcing
        // tready here made the writer lose the first weight.
        wgt_if.m_cb.tvalid <= 1'b0;
        wgt_if.m_cb.tdata  <= '0;
        wgt_if.m_cb.tlast  <= 1'b0;

        cb.tb_rstn <= 1'b0;
        repeat(4) @(cb);
        cb.tb_rstn <= 1'b1;
        repeat(4) @(cb);
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    `SVUNIT_TESTS_BEGIN
    `include "matched_filter_tests.sv"
    `SVUNIT_TESTS_END

endmodule
