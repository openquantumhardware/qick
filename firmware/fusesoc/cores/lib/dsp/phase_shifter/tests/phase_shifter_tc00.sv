// ============================================================================
// File: phase_shifter_tc00.sv
// Description: SVUnit testbench top-level for phase_shifter.
//   Verifies the pipelined CORDIC/LUT-based complex phase rotation.
//   Includes a bit-true software reference model for Q1.15 math and saturation.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module phase_shifter_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "phase_shifter_ut";
    svunit_testcase svunit_ut;

    // =========================================================================
    // Parameters (match the DUT defaults)
    // =========================================================================
    localparam real CLOCK_FREQUENCY = 250e6;
    localparam int  DW  = 16;
    localparam int  PW  = 16;
    localparam int  LAW = 11;
    
    // As per RTL tracking, latency is 7 cycles (not 5 as per header comments).
    localparam int  LATENCY = 7;
    localparam int  LUT_DEPTH = (1 << LAW);

    // =========================================================================
    // Clock & Reset
    // =========================================================================
    logic tb_aclk    = 1'b0;
    logic tb_aresetn = 1'b0;

    clk_gen #(.FREQ (CLOCK_FREQUENCY)) u_clk (.i_enable(1'b1), .o_clk(tb_aclk));

    // =========================================================================
    // DUT signals
    // =========================================================================
    logic signed [DW-1:0] tb_i_in = '0;
    logic signed [DW-1:0] tb_q_in = '0;
    logic        [PW-1:0] tb_phase = '0;
    logic signed [DW-1:0] tb_i_out;
    logic signed [DW-1:0] tb_q_out;

    // =========================================================================
    // Clocking block
    // =========================================================================
    default clocking tb_cb @(posedge tb_aclk);
        default input #1step output #2;
        output tb_aresetn;
        output tb_i_in;
        output tb_q_in;
        output tb_phase;
        input  tb_i_out;
        input  tb_q_out;
    endclocking

    // =========================================================================
    // DUT
    // =========================================================================
    phase_shifter #(
        .DW  (DW),
        .PW  (PW),
        .LAW (LAW)
    ) dut (
        .aclk    (tb_aclk),
        .aresetn (tb_aresetn),
        .i_in    (tb_i_in),
        .q_in    (tb_q_in),
        .phase   (tb_phase),
        .i_out   (tb_i_out),
        .q_out   (tb_q_out)
    );

    // =========================================================================
    // Dump
    // =========================================================================
    initial begin
        $dumpfile("phase_shifter.vcd");
        $dumpvars();
    end
    // =========================================================================
    // Testbench Internal LUT & Golden Model
    // =========================================================================
    logic signed [DW-1:0] tb_cos_lut [LUT_DEPTH];
    logic signed [DW-1:0] tb_sin_lut [LUT_DEPTH];

    typedef struct {
        logic signed [DW-1:0] i;
        logic signed [DW-1:0] q;
    } iq_t;

    // Populate the reference LUT in the TB. It is built independently of the RTL
    // table, with the formula the RTL table was generated from, and is NOT
    // injected into the DUT: the tests compare against the DUT's own ROM, so a
    // wrong entry in phase_shifter.sv fails here.
    initial begin
        real pi = $acos(-1.0);
        for (int i = 0; i < LUT_DEPTH; i++) begin
            real angle = (2.0 * pi * i) / LUT_DEPTH;
            // Q1.15 with a full scale of 32767: round(32767 * cos), round(32767 * sin)
            longint c_val = longint'($floor($cos(angle) * 32767.0 + 0.5));
            longint s_val = longint'($floor($sin(angle) * 32767.0 + 0.5));

            tb_cos_lut[i] = c_val[DW-1:0];
            tb_sin_lut[i] = s_val[DW-1:0];
        end
    end

    // Bit-true reference model matching DUT's DSP and rounding logic
    function automatic iq_t golden_model(
        input logic signed [DW-1:0] i_in,
        input logic signed [DW-1:0] q_in,
        input logic        [PW-1:0] phase
    );
        logic [LAW-1:0] lut_addr;
        logic signed [DW-1:0] c, s;
        logic signed [2*DW-1:0] i_cos, i_sin, q_cos, q_sin;
        logic signed [2*DW-1:0] i_res, q_res;
        logic signed [2*DW-1:0] i_rnd, q_rnd;
        iq_t out;

        lut_addr = phase[PW-1 -: LAW];
        c = tb_cos_lut[lut_addr];
        s = tb_sin_lut[lut_addr];

        i_cos = i_in * c;
        i_sin = i_in * s;
        q_cos = q_in * c;
        q_sin = q_in * s;

        i_res = i_cos - q_sin;
        q_res = i_sin + q_cos;

        // Round and scale Q2.30 -> Q1.15
        i_rnd = (i_res + (1 <<< 14)) >>> 15;
        q_rnd = (q_res + (1 <<< 14)) >>> 15;

        // Saturate
        out.i = (i_rnd > 32767) ? 32767 : ((i_rnd < -32768) ? -32768 : i_rnd[DW-1:0]);
        out.q = (q_rnd > 32767) ? 32767 : ((q_rnd < -32768) ? -32768 : q_rnd[DW-1:0]);
        
        return out;
    endfunction

    // =========================================================================
    // Helpers
    // =========================================================================
    task automatic reset_dut();
        tb_cb.tb_aresetn <= 1'b0;
        tb_cb.tb_i_in    <= '0;
        tb_cb.tb_q_in    <= '0;
        tb_cb.tb_phase   <= '0;
        repeat(5) @(tb_cb);
        tb_cb.tb_aresetn <= 1'b1;
        repeat(2) @(tb_cb);
    endtask

    // Pipeline driver and monitor. Streams `count` samples back-to-back.
    task automatic test_stream(input int count);
        iq_t expected_q[$];
        
        fork
            // Driver thread
            begin
                for (int n = 0; n < count; n++) begin
                    logic signed [DW-1:0] rnd_i = $urandom;
                    logic signed [DW-1:0] rnd_q = $urandom;
                    logic        [PW-1:0] rnd_p = $urandom;
                    
                    tb_cb.tb_i_in  <= rnd_i;
                    tb_cb.tb_q_in  <= rnd_q;
                    tb_cb.tb_phase <= rnd_p;
                    
                    expected_q.push_back(golden_model(rnd_i, rnd_q, rnd_p));
                    @(tb_cb);
                end
                // Flush pipeline with zeros
                tb_cb.tb_i_in  <= '0;
                tb_cb.tb_q_in  <= '0;
                tb_cb.tb_phase <= '0;
            end
            
            // Monitor thread (delayed by LATENCY)
            begin
                repeat(LATENCY + 1) @(tb_cb);
                for (int n = 0; n < count; n++) begin
                    iq_t exp = expected_q.pop_front();
                    if (tb_cb.tb_i_out !== exp.i || tb_cb.tb_q_out !== exp.q) begin
                        $display("STREAM MISMATCH n=%0d: exp(I,Q)=(%0d,%0d) got(I,Q)=(%0d,%0d)", 
                                  n, exp.i, exp.q, signed'(tb_cb.tb_i_out), signed'(tb_cb.tb_q_out));
                        `FAIL_IF(1);
                    end
                    @(tb_cb);
                end
            end
        join
    endtask

    // Drives every one of the 2048 ROM entries with two probes, (I,Q) = (MAX, 0)
    // and (0, MAX), so each cos and each sin value reaches the output, and checks
    // both against the reference table. The low 5 phase bits are random: they must
    // not change the ROM address.
    task automatic test_rom_sweep();
        iq_t expected_q[$];
        int  total = 2 * LUT_DEPTH;

        fork
            begin
                for (int k = 0; k < LUT_DEPTH; k++) begin
                    logic [PW-1:0] p = {k[LAW-1:0], 5'($urandom)};
                    tb_cb.tb_phase <= p;
                    tb_cb.tb_i_in  <= 16'sd32767;
                    tb_cb.tb_q_in  <= 16'sd0;
                    expected_q.push_back(golden_model(16'sd32767, 16'sd0, p));
                    @(tb_cb);
                    tb_cb.tb_i_in  <= 16'sd0;
                    tb_cb.tb_q_in  <= 16'sd32767;
                    expected_q.push_back(golden_model(16'sd0, 16'sd32767, p));
                    @(tb_cb);
                end
                tb_cb.tb_i_in  <= '0;
                tb_cb.tb_q_in  <= '0;
                tb_cb.tb_phase <= '0;
            end

            begin
                repeat(LATENCY + 1) @(tb_cb);
                for (int n = 0; n < total; n++) begin
                    iq_t exp = expected_q.pop_front();
                    if (tb_cb.tb_i_out !== exp.i || tb_cb.tb_q_out !== exp.q) begin
                        $display("ROM MISMATCH entry %0d probe %0d: exp(I,Q)=(%0d,%0d) got(I,Q)=(%0d,%0d)",
                                 n / 2, n % 2, exp.i, exp.q,
                                 signed'(tb_cb.tb_i_out), signed'(tb_cb.tb_q_out));
                        `FAIL_IF(1);
                    end
                    @(tb_cb);
                end
            end
        join
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
        tb_cb.tb_i_in  <= '0;
        tb_cb.tb_q_in  <= '0;
        tb_cb.tb_phase <= '0;
        repeat(2) @(tb_cb);
    endtask

    `SVUNIT_TESTS_BEGIN
    `include "phase_shifter_tests.sv"
    `SVUNIT_TESTS_END

endmodule
