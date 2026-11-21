`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"
///////////////////////////////////////////////////////////////////////////////
// Fermi National Accelerator Laboratory
// Module : cmult_unit_test
// Project: axis_kidsim_v3
///////////////////////////////////////////////////////////////////////////////
//! @file    cmult_tc00.sv
//! @brief   SVUnit testbench top for cmult (configurable complex multiplier).
//!
//! @details Drives the packed-complex DUT and compares against a bit-exact
//!          golden model mirroring the RTL fixed-point path: guard-bit
//!          accumulate (ACCW=2*BIN+1), round-half-up, saturation to BOUT.
//!          Verifies conjugation combos, { Q, I } packing, latency (=4), bubble
//!          tolerance and correct saturation/rounding. Dumps waves via `ifdef VCD.
//!
//! @author  @lharnaldi
//! @version 1.0
module cmult_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "cmult_ut";
    svunit_testcase svunit_ut;

    //-------------------------------------------------------------------------
    // DUT configuration under test
    //-------------------------------------------------------------------------
    localparam int  BIN          = 16;
    localparam int  BOUT         = 16;
    localparam bit  CONF_DYNAMIC = 1'b1;   // exercise dynamic conj ports
    localparam bit  ROUND        = 1'b1;
    localparam bit  SAT          = 1'b1;

    localparam int  PW    = 2*BIN;
    localparam int  ACCW  = 2*BIN + 1;
    localparam int  SHIFT = (2*BIN-2) - (BOUT-1);
    localparam int  LAT   = 4;
    localparam real CLOCK_FREQUENCY = 200e6;

    localparam logic signed [BOUT-1:0] SAT_MAX =  (1 <<< (BOUT-1)) - 1;
    localparam logic signed [BOUT-1:0] SAT_MIN = -(1 <<< (BOUT-1));

    //-------------------------------------------------------------------------
    // Clock / reset
    //-------------------------------------------------------------------------
    logic tb_clk  = 1'b0;
    logic tb_rstn = 1'b1;
    clk_gen #(.FREQ(CLOCK_FREQUENCY)) u_clk (.i_enable(1'b1), .o_clk(tb_clk));

    //-------------------------------------------------------------------------
    // DUT signals
    //-------------------------------------------------------------------------
    logic                  i_valid;
    logic                  i_conja, i_conjb;
    logic [2*BIN-1:0]      i_dina, i_dinb;
    logic                  o_valid;
    logic [2*BOUT-1:0]     o_dout;

    cmult #(
        .BIN         (BIN),
        .BOUT        (BOUT),
        .CONJA       (1'b0),
        .CONJB       (1'b0),
        .CONF_DYNAMIC(CONF_DYNAMIC),
        .ROUND       (ROUND),
        .SAT         (SAT)
    ) dut (
        .i_clk   (tb_clk),
        .i_rstn  (tb_rstn),
        .i_conja (i_conja),
        .i_conjb (i_conjb),
        .i_valid (i_valid),
        .i_dina  (i_dina),
        .i_dinb  (i_dinb),
        .o_valid (o_valid),
        .o_dout  (o_dout)
    );

    // =========================================================================
    // Dump
    // =========================================================================
    initial begin
        $dumpfile("cmult.vcd");
        $dumpvars();
    end
    //-------------------------------------------------------------------------
    // Golden model (bit-exact with the RTL fixed-point path).
    //-------------------------------------------------------------------------
    function automatic logic signed [BOUT-1:0] requant_ref(input logic signed [ACCW-1:0] acc);
        logic signed [ACCW-1:0] v;
        logic signed [BOUT-1:0] out;
        begin
            v = acc;
            if (ROUND && (SHIFT > 0)) v = v + (1 <<< (SHIFT-1));
            out = BOUT'(v >>> SHIFT);
            if (SAT) begin
                if      ((v >>> SHIFT) > SAT_MAX) out = SAT_MAX;
                else if ((v >>> SHIFT) < SAT_MIN) out = SAT_MIN;
            end
            return out;
        end
    endfunction

    // Compute expected packed output for a given operand pair + conj selects.
    function automatic logic [2*BOUT-1:0] model(input logic [2*BIN-1:0] da,
                                                input logic [2*BIN-1:0] db,
                                                input logic ca, input logic cb);
        logic signed [BIN-1:0]  ar, ai, br, bi;
        logic signed [PW-1:0]   prr, pii, pri, pir;
        logic signed [ACCW-1:0] are, aim;
        logic signed [BOUT-1:0] qre, qim;
        begin
            ar = da[0 +: BIN];
            ai = ca ? -$signed(da[BIN +: BIN]) : $signed(da[BIN +: BIN]);
            br = db[0 +: BIN];
            bi = cb ? -$signed(db[BIN +: BIN]) : $signed(db[BIN +: BIN]);
            prr = ar*br; pii = ai*bi; pri = ar*bi; pir = ai*br;
            are = ACCW'(prr) - ACCW'(pii);
            aim = ACCW'(pri) + ACCW'(pir);
            qre = requant_ref(are);
            qim = requant_ref(aim);
            return {qim, qre};
        end
    endfunction

    // Pack/unpack helpers.
    function automatic logic [2*BIN-1:0] pk(input logic signed [BIN-1:0] i_c,
                                            input logic signed [BIN-1:0] q_c);
        return {q_c, i_c};
    endfunction
    function automatic logic signed [BOUT-1:0] up_i(input logic [2*BOUT-1:0] w);
        return w[0 +: BOUT];
    endfunction
    function automatic logic signed [BOUT-1:0] up_q(input logic [2*BOUT-1:0] w);
        return w[BOUT +: BOUT];
    endfunction

    //-------------------------------------------------------------------------
    // Driver helpers
    //-------------------------------------------------------------------------
    task automatic do_reset();
        i_valid = 1'b0; i_dina = '0; i_dinb = '0;
        i_conja = 1'b0; i_conjb = 1'b0;
        tb_rstn = 1'b0;
        repeat (4) @(posedge tb_clk);
        tb_rstn = 1'b1;
        @(posedge tb_clk);
    endtask

    task automatic bubble(input int n);
        i_valid <= 1'b0;
        repeat (n) @(posedge tb_clk);
    endtask

        // Input-domain saturation corners.
    function automatic logic signed [BIN-1:0] MAX_POS_IN(); return (1 <<< (BIN-1)) - 1; endfunction
    function automatic logic signed [BIN-1:0] SAT_MIN_IN(); return -(1 <<< (BIN-1));     endfunction

    // Drive a single (da,db) sample and check the (latency-aligned) output.
    task automatic drive_one_and_check(input logic [2*BIN-1:0] da,
                                       input logic [2*BIN-1:0] db,
                                       input logic [2*BOUT-1:0] exp);
        int got = 0;
        fork
            begin
                @(posedge tb_clk);
                i_dina <= da; i_dinb <= db; i_valid <= 1'b1;
                @(posedge tb_clk);
                i_valid <= 1'b0;
            end
            begin
                while (got < 1) begin
                    @(posedge tb_clk);
                    if (o_valid) begin
                        `FAIL_UNLESS_LOG(o_dout === exp,
                            $sformatf("sat check: got %08h exp %08h", o_dout, exp))
                        got++;
                    end
                end
            end
        join
    endtask

    //-------------------------------------------------------------------------
    function void build(); svunit_ut = new(name); endfunction
    task setup();
        svunit_ut.setup();
        i_valid = 1'b0; i_dina = '0; i_dinb = '0;
        i_conja = 1'b0; i_conjb = 1'b0;
    endtask
    task teardown(); svunit_ut.teardown(); endtask

    `SVUNIT_TESTS_BEGIN
    `include "cmult_tests.sv"
    `SVUNIT_TESTS_END

endmodule