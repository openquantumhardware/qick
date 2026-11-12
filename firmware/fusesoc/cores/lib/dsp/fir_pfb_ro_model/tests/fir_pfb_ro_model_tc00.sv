// ============================================================================
// File: fir_pfb_ro_model_tc00.sv
// Description: SVUnit testbench for fir_pfb_ro_model.
//
//   These tests pin down the modelled behaviour with coefficients chosen to
//   make every output easy to predict; fidelity to the real FIR Compiler is
//   checked separately, per .xci, by tests/vendor/run_vendor_check.sh.
//
//   Coefficient sets (NTAPS = 7, set-major):
//     set 0: tap 0 = 16384 (y = x/2: rounding ties)
//     set 1: tap 1 = 8192  (y = x[n-2 vectors]/4: zero-packing spacing)
//     set 2: tap 0 = 32767 (y = x, within 1)
//     sets 3..7: tap 0 = 4096 * set
//
//   Inputs are driven with a non-blocking assignment right after a rising
//   edge; `edge_n` counts rising edges, and outputs are sampled on the
//   falling edge (so an output seen after edge n is tagged n).
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module fir_pfb_ro_model_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "fir_pfb_ro_model_ut";
    svunit_testcase svunit_ut;

    localparam real CLOCK_FREQUENCY = 300e6;
    localparam int  NCH = 8, NTAPS = 7;

    function automatic int coef(int s, int k);
        if (s == 0) return (k == 0) ? 16384 : 0;
        if (s == 1) return (k == 1) ? 8192 : 0;
        if (s == 2) return (k == 0) ? 32767 : 0;
        return (k == 0) ? 4096 * s : 0;
    endfunction

    typedef int signed coef_t [NCH*NTAPS];
    function automatic coef_t mk_coeffs();
        coef_t c;
        for (int s = 0; s < NCH; s++) for (int k = 0; k < NTAPS; k++) c[s*NTAPS + k] = coef(s, k);
        return c;
    endfunction
    localparam coef_t COEFFS = mk_coeffs();

    logic aclk = 1'b0;
    clk_gen #(.FREQ(CLOCK_FREQUENCY)) u_clk (.i_enable(1'b1), .o_clk(aclk));

    logic        s_valid = 1'b0, s_last = 1'b0;
    logic [31:0] s_data  = '0;
    logic        c_valid = 1'b0, c_last = 1'b0;
    logic [7:0]  c_data  = '0;
    logic        s_ready, c_ready, m_valid, m_last;
    logic [31:0] m_data;
    logic        ev_miss, ev_unexp, ev_cmiss, ev_cunexp;

    fir_pfb_ro_model #(.NCH(NCH), .NTAPS(NTAPS), .COEFFS(COEFFS)) dut (
        .aclk                            (aclk),
        .s_axis_data_tvalid              (s_valid),
        .s_axis_data_tready              (s_ready),
        .s_axis_data_tlast               (s_last),
        .s_axis_data_tdata               (s_data),
        .s_axis_config_tvalid            (c_valid),
        .s_axis_config_tready            (c_ready),
        .s_axis_config_tlast             (c_last),
        .s_axis_config_tdata             (c_data),
        .m_axis_data_tvalid              (m_valid),
        .m_axis_data_tlast               (m_last),
        .m_axis_data_tdata               (m_data),
        .event_s_data_tlast_missing      (ev_miss),
        .event_s_data_tlast_unexpected   (ev_unexp),
        .event_s_config_tlast_missing    (ev_cmiss),
        .event_s_config_tlast_unexpected (ev_cunexp)
    );

    int edge_n = 0;
    always @(posedge aclk) edge_n++;

    // Output log, one entry per valid output: edge, I, Q, tlast.
    int          o_edge [$];
    int          o_i [$], o_q [$];
    bit          o_last [$];
    int          e_miss [$], e_unexp [$], e_cmiss [$], e_cunexp [$];

    always @(negedge aclk) begin
        if (m_valid) begin
            o_edge.push_back(edge_n);
            o_i.push_back($signed(m_data[15:0]));
            o_q.push_back($signed(m_data[31:16]));
            o_last.push_back(m_last);
        end
        if (ev_miss)   e_miss.push_back(edge_n);
        if (ev_unexp)  e_unexp.push_back(edge_n);
        if (ev_cmiss)  e_cmiss.push_back(edge_n);
        if (ev_cunexp) e_cunexp.push_back(edge_n);
    end

    // Drive one input on the next edge; returns the edge that accepts it.
    task automatic push(input int i, input int q, input bit last, output int acc_edge);
        @(posedge aclk);
        s_valid <= 1'b1;
        s_data  <= {16'(q), 16'(i)};
        s_last  <= last;
        acc_edge = edge_n + 1;
    endtask

    task automatic idle(input int n);
        repeat (n) begin
            @(posedge aclk);
            s_valid <= 1'b0; s_last <= 1'b0;
        end
    endtask

    // One vector, all channels with the same (i, q), tlast on the last one.
    task automatic vector(input int i, input int q);
        int e;
        for (int c = 0; c < NCH; c++) push(i, q, c == NCH - 1, e);
    endtask

    task automatic send_config(input int set_of_ch [NCH], input int last_at = NCH - 1);
        for (int c = 0; c < NCH; c++) begin
            @(posedge aclk);
            c_valid <= 1'b1;
            c_data  <= 8'(set_of_ch[c]);
            c_last  <= (c == last_at);
        end
        @(posedge aclk);
        c_valid <= 1'b0; c_last <= 1'b0;
    endtask

    function automatic void clear_logs();
        o_edge.delete(); o_i.delete(); o_q.delete(); o_last.delete();
        e_miss.delete(); e_unexp.delete(); e_cmiss.delete(); e_cunexp.delete();
    endfunction

    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    `SVUNIT_TESTS_BEGIN
    `include "fir_pfb_ro_model_tests.sv"
    `SVUNIT_TESTS_END
endmodule
