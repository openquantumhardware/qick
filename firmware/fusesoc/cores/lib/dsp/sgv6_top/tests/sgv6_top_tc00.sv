// ============================================================================
// File: sgv6_top_tc00.sv
// Description: SVUnit integration testbench for sgv6_top (signal gen v6 top).
//
//   End-to-end: load an envelope via S0, queue a descriptor via S1, and observe
//   the M_AXIS output. The Xilinx dds_compiler_0 is replaced by a behavioural
//   model (constant controllable cos/sin, latency 10).
//
//   Envelope memory layout (via axis_to_bram_sg_nt one-hot demux):
//     stream sample k -> bank (k % N_DDS), row (k / N_DDS)
//   With N_DDS parallel banks, N_DDS consecutive samples fill one row across
//   all banks; the next N_DDS samples go to the next row.
//
//   A key early test MEASURES the memory read latency to detect any
//   misalignment introduced by replacing bram_dp_xpm (OUT_REG_ENA=1) with
//   bram_tdp.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module sgv6_top_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "sgv6_top_ut";
    svunit_testcase svunit_ut;

    // =========================================================================
    // Parameters
    // =========================================================================
    localparam real AXI_FREQ  = 100e6;   // envelope-load domain (s0_axis_aclk)
    localparam real ACLK_FREQ = 200e6;   // main domain (aclk)
    localparam int  N     = 8;           // small memory for sim (depth 256/bank)
    localparam int  N_DDS = 16;
    localparam int  MAXV  = 2**15 - 2;   // 32766

    // =========================================================================
    // Clocks & Resets (two domains)
    // =========================================================================
    logic tb_aclk    = 1'b0;
    logic tb_aresetn = 1'b1;
    logic tb_s0_aclk = 1'b0;
    logic tb_s0_arstn = 1'b1;

    clk_gen #(.FREQ (ACLK_FREQ)) u_aclk (.i_enable(1'b1), .o_clk(tb_aclk));
    clk_gen #(.FREQ (AXI_FREQ))  u_s0   (.i_enable(1'b1), .o_clk(tb_s0_aclk));

    // =========================================================================
    // Output-domain clocking block (aclk).  All checkers sample through this.
    // =========================================================================
    default clocking m_cb @(posedge tb_aclk);
        default input #1step output #2;
        input  tb_m_tvalid;
        input  tb_m_tdata;
        input  tb_sat;
        output tb_m_tready;
    endclocking

    // =========================================================================
    // DUT signals
    // =========================================================================
    // S0 (envelope load)
    logic [31:0] tb_s0_tdata  = '0;
    logic        tb_s0_tvalid = 1'b0;
    logic        tb_s0_tready;
    // S1 (descriptor)
    logic [159:0] tb_s1_tdata  = '0;
    logic         tb_s1_tvalid = 1'b0;
    logic         tb_s1_tready;
    // M_AXIS (output)
    logic                tb_m_tready = 1'b1;
    logic                tb_m_tvalid;
    logic [N_DDS*16-1:0] tb_m_tdata;
    // Registers
    logic [31:0] tb_start_addr = '0;
    logic        tb_we         = 1'b0;
    logic        tb_sat;

    // =========================================================================
    // Dump
    // =========================================================================
    initial begin
        $dumpfile("sgv6_top.vcd");
        $dumpvars();
    end

    // =========================================================================
    // DUT
    // =========================================================================
    sgv6_top #(
        .N             (N),
        .N_DDS         (N_DDS),
        .GEN_DDS       ("TRUE"),
        .ENVELOPE_TYPE ("COMPLEX")
    ) dut (
        .aresetn          (tb_aresetn),
        .aclk             (tb_aclk),
        .s0_axis_aresetn  (tb_s0_arstn),
        .s0_axis_aclk     (tb_s0_aclk),
        .s0_axis_tdata_i  (tb_s0_tdata),
        .s0_axis_tvalid_i (tb_s0_tvalid),
        .s0_axis_tready_o (tb_s0_tready),
        .s1_axis_tdata_i  (tb_s1_tdata),
        .s1_axis_tvalid_i (tb_s1_tvalid),
        .s1_axis_tready_o (tb_s1_tready),
        .m_axis_tready_i  (tb_m_tready),
        .m_axis_tvalid_o  (tb_m_tvalid),
        .m_axis_tdata_o   (tb_m_tdata),
        .start_addr_reg   (tb_start_addr),
        .we_reg           (tb_we),
        .o_sat            (tb_sat) 
    );


    localparam int TOL = 2;   // LSBs of slack for gain rounding

    // env_val: unique per (row, bank) so any slip is visible immediately.
    // Row in the high byte, bank in the low byte, offset by one so row 0 is
    // never confusable with unwritten memory.
    function automatic logic [15:0] env_val(input int row, input int bank);
        return 16'(((row + 1) << 8) | bank);
    endfunction

    // load_ramp: fill `nrows` rows across all N_DDS banks with env_val().
    task automatic load_ramp(input int nrows);
        logic [15:0] re [];
        logic [15:0] im [];
        re = new[nrows * N_DDS];
        im = new[nrows * N_DDS];
        for (int k = 0; k < nrows * N_DDS; k++) begin
            re[k] = env_val(k / N_DDS, k % N_DDS);
            im[k] = 16'h0000;
        end
        load_envelope(nrows * N_DDS, re, im);
    endtask

    // capture_burst: collect every beat of one burst, all lanes.
    // Returns the beat count; fails the caller if the burst never starts.
    task automatic capture_burst(
        output logic [N_DDS*16-1:0] beats [$],
        input  int                  start_timeout = 400,
        input  int                  max_beats     = 512
    );
        int t = 0;
        beats.delete();
        while (!tb_m_tvalid && t < start_timeout) begin
            @(posedge tb_aclk); t++;
        end
        if (!tb_m_tvalid) return;          // caller checks beats.size()
        while (tb_m_tvalid && beats.size() < max_beats) begin
            beats.push_back(tb_m_tdata);
            @(posedge tb_aclk);
        end
    endtask

    // lane: extract one 16-bit lane from a captured beat.
    function automatic logic [15:0] lane(input logic [N_DDS*16-1:0] beat,
                                         input int l);
        return beat[l*16 +: 16];
    endfunction

    // scale_gain: expected output in "mem" mode — envelope scaled by gain.
    // Pin this against the isolated sgv6 testbench if the datapath rounding
    // differs; TOL absorbs the last-LSB behaviour.
    function automatic int scale_gain(input logic [15:0] env, input int gain);
        return (int'(env) * gain) / 32768;
    endfunction

    function automatic bit close(input int got, input int exp_v);
        return (got > exp_v ? got - exp_v : exp_v - got) <= TOL;
    endfunction

    // =========================================================================
    // Descriptor builder (160-bit, same layout as ctrl_sg_v6).
    // =========================================================================
    function automatic logic [159:0] build_descr(
        input logic [31:0] freq,  input logic [31:0] phase,
        input logic [15:0] addr,  input logic [15:0] gain,
        input logic [15:0] nsamp, input logic [1:0]  outsel,
        input logic mode, input logic stdysel, input logic phrst
    );
        logic [159:0] d = '0;
        d[31:0]=freq; d[63:32]=phase; d[79:64]=addr; d[111:96]=gain;
        d[143:128]=nsamp; d[145:144]=outsel; d[146]=mode;
        d[147]=stdysel; d[148]=phrst;
        return d;
    endfunction


    // =========================================================================
    // load_envelope 
    //
    // Sample k lands in bank (k % N_DDS), row (k / N_DDS).  Streaming N_DDS*R
    // samples therefore fills rows 0..R-1 across every bank.
    // =========================================================================
    task automatic load_envelope(
        input int          count,
        input logic [15:0] re [],
        input logic [15:0] im []
    );
        @(posedge tb_s0_aclk);
        tb_start_addr <= '0;
        tb_we         <= 1'b1;
        repeat (5) @(posedge tb_s0_aclk);   // CDC + FSM reach the write state
 
        for (int k = 0; k < count; k++) begin
            tb_s0_tdata  <= {im[k], re[k]};
            tb_s0_tvalid <= 1'b1;
            // Wait for a real handshake: the value must be on the bus at the
            // edge where tready is sampled, not one edge earlier.
            do @(posedge tb_s0_aclk); while (!tb_s0_tready);
        end
 
        tb_s0_tvalid <= 1'b0;
        repeat (10) @(posedge tb_s0_aclk);  // let the 3-stage pipeline flush
        tb_we <= 1'b0;
        repeat (5) @(posedge tb_s0_aclk);
    endtask
 
    // =========================================================================
    // load_flat / load_ramp — the two stimulus shapes the tests use
    // =========================================================================
 
    // Fill `rows` rows of every bank with a single constant value
    task automatic load_flat(input int rows, input logic [15:0] val);
        logic [15:0] re [];
        logic [15:0] im [];
        re = new[rows * N_DDS];
        im = new[rows * N_DDS];
        for (int k = 0; k < rows * N_DDS; k++) begin
            re[k] = val;
            im[k] = 16'h0000;
        end
        load_envelope(rows * N_DDS, re, im);
    endtask
 
    // =========================================================================
    // Expected datapath scaling
    //
    // In memory-only mode (outsel=2) the DDS is bypassed, so the output is the
    // envelope scaled by gain: out = (env * gain) >>> 15.
    // Verified against the observed run: env=0x4000, gain=32766 -> 0x3FFF.
    // =========================================================================
    function automatic logic [15:0] exp_mem(input logic [15:0] env,
                                            input logic [15:0] gain);
        return 16'(($signed(env) * $signed(gain)) >>> 15);
    endfunction

    // =========================================================================
    // Descriptor queue helper (aclk domain).
    // =========================================================================
    task automatic queue_descriptor(input logic [159:0] d);
        @(posedge tb_aclk);
        tb_s1_tdata  <= d;
        tb_s1_tvalid <= 1'b1;
        @(posedge tb_aclk);
        while (!tb_s1_tready) @(posedge tb_aclk);
        tb_s1_tvalid <= 1'b0;
        @(posedge tb_aclk);
    endtask

    // Wait for the output to become valid; return lane-0 sample.
    task automatic wait_output(output logic [15:0] dout0, input int timeout = 200);
        int t = 0;
        while (!tb_m_tvalid && t < timeout) begin @(posedge tb_aclk); t++; end
        dout0 = tb_m_tdata[15:0];
    endtask

    // load_window: write the WHOLE window the burst will read, in one pass —
    // a ramp over the first `nramp` rows and explicit zeros over the rest.
    //
    // The envelope BRAM is not cleared between SVUnit tests, so "rows I did not
    // load read as zero" is only true in the first test that runs. Any test that
    // depends on what is beyond its own data has to write that region itself.
    task automatic load_window(input int nramp, input int nrows_total);
        logic [15:0] re [];
        logic [15:0] im [];
        re = new[nrows_total * N_DDS];
        im = new[nrows_total * N_DDS];
        for (int k = 0; k < nrows_total * N_DDS; k++) begin
            re[k] = (k / N_DDS < nramp) ? env_val(k / N_DDS, k % N_DDS) : 16'h0000;
            im[k] = 16'h0000;
        end
        load_envelope(nrows_total * N_DDS, re, im);
    endtask

    // capture_n_beats: take exactly `n` beats. Unlike capture_burst it does not
    // stop when tvalid drops, so two bursts that run back to back with no gap
    // cannot be silently merged into one capture.
    task automatic capture_n_beats(
        output logic [N_DDS*16-1:0] beats [$],
        input  int                  n,
        input  int                  timeout = 400
    );
        int t;
        beats.delete();
        for (int i = 0; i < n; i++) begin
            t = 0;
            while (!tb_m_tvalid && t < timeout) begin
                @(posedge tb_aclk); t++;
            end
            if (!tb_m_tvalid) return;      // caller checks beats.size()
            beats.push_back(tb_m_tdata);
            @(posedge tb_aclk);
        end
    endtask

    // =========================================================================
    // SVUnit
    // =========================================================================
    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        tb_aresetn   <= 1'b0;
        tb_s0_arstn  <= 1'b0;
        tb_s0_tvalid <= 1'b0;
        tb_s1_tvalid <= 1'b0;
        tb_m_tready  <= 1'b1;
        tb_we        <= 1'b0;
        tb_start_addr<= '0;
        repeat(20) @(posedge tb_aclk);
        tb_aresetn  <= 1'b1;
        tb_s0_arstn <= 1'b1;
        repeat(20) @(posedge tb_aclk);
    endtask

    task teardown();
        svunit_ut.teardown();
        tb_we        <= 1'b0;
        tb_s0_tvalid <= 1'b0;
        tb_s1_tvalid <= 1'b0;
        repeat(10) @(posedge tb_aclk);
    endtask

    initial begin
        #500_000_000;
        $display("INFO: Global timeout reached");
        $finish;
    end

    `SVUNIT_TESTS_BEGIN
    `include "sgv6_top_tests.sv"
    `SVUNIT_TESTS_END

endmodule
