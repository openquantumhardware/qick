// ============================================================================
// File: sgv6_tc00.sv
// Description: SVUnit testbench for sgv6 (v6 signal generator datapath).
//
//   Goal: characterise the amplitude/scaling chain (envelope x DDS x gain) and
//   expose the suspected level issues (0.5 scaling, [31:16] vs [30:15] mismatch,
//   missing saturation / wrap-around).
//
//   The Xilinx dds_compiler_0 is replaced by a behavioural model (below) that
//   the testbench drives to a CONSTANT cos/sin (controllable), with latency 10,
//   so the amplitude path can be exercised with a known carrier.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module sgv6_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "sgv6_ut";
    svunit_testcase svunit_ut;

    // =========================================================================
    // Parameters
    // =========================================================================
    localparam real CLOCK_FREQUENCY = 200e6;
    localparam int  N     = 16;
    localparam int  N_DDS = 16;
    localparam int  MAXV  = 2**15 - 2;   // 32766

    // =========================================================================
    // Clock & Reset
    // =========================================================================
    logic tb_clk  = 1'b0;
    logic tb_rstn = 1'b1;
    clk_gen #(.FREQ (CLOCK_FREQUENCY)) u_clk (.i_enable(1'b1), .o_clk(tb_clk));


    // =========================================================================
    // DUT signals
    // =========================================================================
    logic                tb_fifo_rd_en;
    logic                tb_fifo_empty = 1'b1;
    logic [159:0]        tb_fifo_dout  = '0;
    logic [N-1:0]        tb_mem_addr;
    logic [N_DDS*16-1:0] tb_mem_real = '0;
    logic [N_DDS*16-1:0] tb_mem_imag = '0;
    logic                tb_axis_tready = 1'b1;
    logic                tb_axis_tvalid;
    logic [N_DDS*16-1:0] tb_axis_tdata;
    logic                tb_sat;
    // =========================================================================
    // Dump
    // =========================================================================
    initial begin
        $dumpfile("sgv6.vcd");
        $dumpvars();
    end

    // =========================================================================
    // DUT
    // =========================================================================
    sgv6 #(
        .N       (N),
        .N_DDS   (N_DDS),
        .GEN_DDS ("TRUE")
    ) dut (
        .i_rstn          (tb_rstn),
        .i_clk           (tb_clk),
        .o_fifo_rd_en    (tb_fifo_rd_en),
        .i_fifo_empty    (tb_fifo_empty),
        .i_fifo_dout     (tb_fifo_dout),
        .o_mem_addr      (tb_mem_addr),
        .i_mem_dout_real (tb_mem_real),
        .i_mem_dout_imag (tb_mem_imag),
        .i_axis_tready   (tb_axis_tready),
        .o_axis_tvalid   (tb_axis_tvalid),
        .o_axis_tdata    (tb_axis_tdata),
        .o_sat           (tb_sat)  //unused in this testbench
    );

    // =========================================================================
    // Descriptor builder (same layout as ctrl_sg_v6).
    // =========================================================================
    function automatic logic [159:0] build_descr(
        input logic [31:0] freq,
        input logic [31:0] phase,
        input logic [15:0] addr,
        input logic [15:0] gain,
        input logic [15:0] nsamp,
        input logic [1:0]  outsel,
        input logic        mode,
        input logic        stdysel,
        input logic        phrst
    );  
        logic [159:0] d = '0;
        d[31:0]=freq;
        d[63:32]=phase;
        d[79:64]=addr;
        d[111:96]=gain;
        d[143:128]=nsamp;
        d[145:144]=outsel;
        d[146]=mode;
        d[147]=stdysel;
        d[148]=phrst;
        return d;
    endfunction

    // =========================================================================
    // Reference models (single lane, signed 16-bit operands).
    // =========================================================================
    // Faithful model: reproduces the FIXED RTL amplitude chain.
    function automatic logic [15:0] ref_rtl_prod(
        input logic signed [15:0] env_re, input logic signed [15:0] env_im,
        input logic signed [15:0] cos,    input logic signed [15:0] sin,
        input logic signed [15:0] gain
    );
        logic signed [31:0] pa, pb, pfull;
        logic        [15:0] pq_u;
        logic signed [15:0] pq_s;
        logic signed [31:0] pg;
        logic signed [16:0] round_ext;
        begin
            pa    = cos * env_re;
            pb    = sin * env_im;
            pfull = pa - pb;
            pq_u  = pfull[30:15];         // FIX: [30:15] (was [31:16])
            pq_s  = pq_u;
            pg    = pq_s * gain;
            // FIX: saturation to +/- MAXV
            round_ext = pg[31:15];
            if (round_ext >  17'sd32766) return 16'sd32766;
            if (round_ext < -17'sd32766) return -16'sd32766;
            return round_ext[15:0];
        end
    endfunction

    // Ideal model: Q15 multiply chain with saturation to +/- MAXV.
    //   env (Q15) * cos (Q15) -> Q15 ; * gain (Q15) -> Q15 ; saturate.
    function automatic logic signed [15:0] ref_ideal_prod(
        input logic signed [15:0] env_re, input logic signed [15:0] cos,
        input logic signed [15:0] gain
    );
        logic signed [31:0] p1, p2;
        logic signed [31:0] q1, res;
        p1  = cos * env_re;            // Q15*Q15 = Q30
        q1  = p1 >>> 15;               // back to Q15 (round-toward-zero)
        p2  = q1 * gain;               // Q15*Q15 = Q30
        res = p2 >>> 15;               // back to Q15
        // saturate to +/- MAXV
        if (res >  MAXV) res =  MAXV;
        if (res < -MAXV) res = -MAXV;
        return res[15:0];
    endfunction

    // =========================================================================
    // FIFO / stimulus helpers
    // =========================================================================
    task automatic load_descriptor(input logic [159:0] descr);
        tb_fifo_dout  <= descr;
        tb_fifo_empty <= 1'b0;
        @(posedge tb_clk);
        while (!tb_fifo_rd_en) @(posedge tb_clk);
        tb_fifo_empty <= 1'b1;
        @(posedge tb_clk);
    endtask

    // Fill all lanes of the envelope memory with the same (real, imag) value.
    task automatic set_envelope(input logic [15:0] re, input logic [15:0] im);
        for (int i = 0; i < N_DDS; i++) begin
            tb_mem_real[i*16 +: 16] = re;
            tb_mem_imag[i*16 +: 16] = im;
        end
    endtask

    // Wait until the output is valid, then return lane-0 output.
    task automatic wait_output(output logic [15:0] dout0, input int timeout = 100);
        int t = 0;
        while (!tb_axis_tvalid && t < timeout) begin @(posedge tb_clk); t++; end
        dout0 = tb_axis_tdata[15:0];
    endtask

    // =========================================================================
    // SVUnit
    // =========================================================================
    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        tb_rstn        <= 1'b0;
        tb_fifo_empty  <= 1'b1;
        tb_fifo_dout   <= '0;
        tb_mem_real    <= '0;
        tb_mem_imag    <= '0;
        tb_axis_tready <= 1'b1;
        repeat(15) @(posedge tb_clk);
        tb_rstn <= 1'b1;
        repeat(10) @(posedge tb_clk);
    endtask

    task teardown();
        svunit_ut.teardown();
        tb_fifo_empty <= 1'b1;
        repeat(10) @(posedge tb_clk);
    endtask

    initial begin
        #100_000_000;
        $display("INFO: Global timeout reached");
        $finish;
    end

    `SVUNIT_TESTS_BEGIN
    `include "sgv6_tests.sv"
    `SVUNIT_TESTS_END

endmodule

