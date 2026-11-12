// ============================================================================
// File: axis_signal_gen_v6_tc00.sv
// Description: SVUnit integration testbench for the axis_signal_gen_v6 IP.
//
//   Full IP flow: configure registers via AXI4-Lite (start_addr, we), load an
//   envelope via S0, queue a descriptor via S1, and observe the M_AXIS output.
//   The Xilinx dds_compiler_0 is provided by the shared behavioural model
//   (qick:dsp:dds_compiler_0). Constant carrier via freq=0 in the descriptor.
//
//   Three clock domains: s_axi_aclk, s0_axis_aclk, aclk.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module axis_signal_gen_v6_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "axis_signal_gen_v6_ut";
    svunit_testcase svunit_ut;

    // =========================================================================
    // Parameters
    // =========================================================================
    localparam real AXI_FREQ  = 100e6;
    localparam real S0_FREQ   = 100e6;
    localparam real ACLK_FREQ = 200e6;
    localparam int  N     = 8;           // small memory for sim
    localparam int  N_DDS = 16;
    localparam int  MAXV  = 2**15 - 2;

    // Register byte addresses
    localparam logic [5:0] REG_START_ADDR = 6'h00;
    localparam logic [5:0] REG_WE         = 6'h04;
    localparam logic [5:0] REG_RNDQ       = 6'h08;
    localparam logic [5:0] REG_STATUS     = 6'h0C;
    localparam logic [5:0] REG_CTRL       = 6'h10;



    // =========================================================================
    // Clocks & Resets (three domains)
    // =========================================================================
    logic s_axi_aclk    = 1'b0;
    logic s_axi_aresetn = 1'b1;
    logic s0_axis_aclk  = 1'b0;
    logic s0_axis_arstn = 1'b1;
    logic aclk          = 1'b0;
    logic aresetn       = 1'b1;

    clk_gen #(.FREQ (AXI_FREQ))  u_axi (.i_enable(1'b1), .o_clk(s_axi_aclk));
    clk_gen #(.FREQ (S0_FREQ))   u_s0  (.i_enable(1'b1), .o_clk(s0_axis_aclk));
    clk_gen #(.FREQ (ACLK_FREQ)) u_a   (.i_enable(1'b1), .o_clk(aclk));

    // =========================================================================
    // Interfaces
    // =========================================================================
    axi4_lite_if #(
        .DATA_WIDTH (32),
        .ADDR_WIDTH (6)
    ) s_axi (
        .aclk    (s_axi_aclk),
        .aresetn (s_axi_aresetn)
    );

    // S0 envelope (TB master), S1 descriptor (TB master), M output (TB sink).
    axi4_stream_if #(.TDATA_WIDTH(32))  s0_if (.aclk(s0_axis_aclk), .aresetn(s0_axis_arstn));
    axi4_stream_if #(.TDATA_WIDTH(160)) s1_if (.aclk(aclk),         .aresetn(aresetn));
    axi4_stream_if #(.TDATA_WIDTH(N_DDS*16)) m_if (.aclk(aclk),     .aresetn(aresetn));
    assign m_if.tready = 1'b1;  // <-- Force the sink always ready
    assign m_if.tlast  = 1'b0;  // the generator does not delimit packets

    // =========================================================================
    // Dump
    // =========================================================================
    initial begin
        $dumpfile("axis_signal_gen_v6.vcd");
        $dumpvars();
    end

    // =========================================================================
    // DUT
    // =========================================================================
    axis_signal_gen_v6 #(
        .N             (N),
        .N_DDS         (N_DDS),
        .GEN_DDS       ("TRUE"),
        .ENVELOPE_TYPE ("COMPLEX")
    ) dut (
        // AXI-Lite
        .s_axi_aclk    (s_axi_aclk),
        .s_axi_aresetn (s_axi_aresetn),
        .s_axi_awaddr  (s_axi.awaddr),
        .s_axi_awprot  (s_axi.awprot),
        .s_axi_awvalid (s_axi.awvalid),
        .s_axi_awready (s_axi.awready),
        .s_axi_wdata   (s_axi.wdata),
        .s_axi_wstrb   (s_axi.wstrb),
        .s_axi_wvalid  (s_axi.wvalid),
        .s_axi_wready  (s_axi.wready),
        .s_axi_bresp   (s_axi.bresp),
        .s_axi_bvalid  (s_axi.bvalid),
        .s_axi_bready  (s_axi.bready),
        .s_axi_araddr  (s_axi.araddr),
        .s_axi_arprot  (s_axi.arprot),
        .s_axi_arvalid (s_axi.arvalid),
        .s_axi_arready (s_axi.arready),
        .s_axi_rdata   (s_axi.rdata),
        .s_axi_rresp   (s_axi.rresp),
        .s_axi_rvalid  (s_axi.rvalid),
        .s_axi_rready  (s_axi.rready),
        // S0 envelope
        .s0_axis_aclk    (s0_axis_aclk),
        .s0_axis_aresetn (s0_axis_arstn),
        .s0_axis_tdata   (s0_if.tdata),
        .s0_axis_tvalid  (s0_if.tvalid),
        .s0_axis_tready  (s0_if.tready),
        // aclk domain
        .aclk    (aclk),
        .aresetn (aresetn),
        // S1 descriptor
        .s1_axis_tdata  (s1_if.tdata),
        .s1_axis_tvalid (s1_if.tvalid),
        .s1_axis_tready (s1_if.tready),
        // M output
        .m_axis_tready (m_if.tready),
        .m_axis_tvalid (m_if.tvalid),
        .m_axis_tdata  (m_if.tdata)
    );

    // =========================================================================
    // Descriptor builder (160-bit).
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
    // Register access (AXI-Lite).
    // =========================================================================
    task automatic reg_write(input logic [5:0] addr, input logic [31:0] data);
        s_axi.axi_write(addr, data);
    endtask
    task automatic reg_read(input logic [5:0] addr, output logic [31:0] data);
        s_axi.axi_read(addr, data);
    endtask

    // ============================================================================
    // Corrected load_envelope for tc00.
    //
    // Root cause of the "mem +1 skew": the OLD driver dropped sample 0. Per beat
    // it did `present; @(m_cb); while(!tready) @(m_cb);`. The writer pre-asserts a
    // REGISTERED tready (tready_r) while idle in WAIT_TVALID, so `while(!tready)`
    // never waited and the master advanced after a single edge. With the m_cb
    // output skew the DUT saw the beat one edge LATE - after the master had already
    // moved to sample 1 - so sample 0 was never sampled. Writer RTL is correct;
    // this is a testbench driver artifact (real HW DMA masters hold the beat).
    //
    // Fix: assert tvalid and present the FIRST beat, then take a LEAD edge so the
    // beat becomes visible to the DUT before any tready-based advance. Hold tvalid
    // continuously and advance tdata ONLY on an edge where tready was sampled high
    // (i.e. the beat was actually accepted). Each sample is now presented until it
    // is genuinely taken, so none are dropped and none are duplicated.
    // ============================================================================
    task automatic load_envelope(
        input int          count,
        input logic [15:0] re [],
        input logic [15:0] im []
    );
        int k;
    
        s0_if.m_cb.tlast <= 1'b0;
        // Configure writer registers over AXI-Lite.
        reg_write(REG_START_ADDR, 32'd0);
        reg_write(REG_WE, 32'd1);
        // CDC margin: we_reg crosses to s0_axis_aclk via cdc_gray_sync.
        repeat(10) @(posedge s0_axis_aclk);
    
        // Present the first beat and give it a LEAD edge so the DUT can sample it
        // before we advance on tready (defeats the pre-asserted-tready + m_cb skew
        // race that used to swallow sample 0).
        s0_if.m_cb.tvalid <= 1'b1;
        s0_if.m_cb.tdata  <= {im[0], re[0]};
        @(s0_if.m_cb);
    
        // Accept-driven advance: change tdata to the next sample only after an edge
        // where tready was high (this beat was taken). Hold otherwise.
        for (k = 0; k < count; ) begin
            @(s0_if.m_cb);
            if (s0_if.m_cb.tready) begin
                k++;
                if (k < count)
                    s0_if.m_cb.tdata <= {im[k], re[k]};
            end
        end
    
        s0_if.m_cb.tvalid <= 1'b0;
        s0_if.m_cb.tdata  <= '0;
        repeat(5) @(posedge s0_axis_aclk);
        // Disable writes.
        reg_write(REG_WE, 32'd0);
        repeat(10) @(posedge s0_axis_aclk);
    endtask

    // Fill all banks/row0 with a constant.
    task automatic const_envelope(
        input int count, input logic [15:0] val,
        output logic [15:0] re [], output logic [15:0] im []
    );
        re = new[count]; im = new[count];
        for (int k = 0; k < count; k++) begin re[k]=val; im[k]=16'h0000; end
    endtask

    // =========================================================================
    // Descriptor queue (S1).
    // =========================================================================
    task automatic queue_descriptor(input logic [159:0] d);
        @(posedge aclk);
        s1_if.tdata  <= d;
        s1_if.tvalid <= 1'b1;
        @(posedge aclk);
        while (!s1_if.tready) @(posedge aclk);
        s1_if.tvalid <= 1'b0;
        @(posedge aclk);
    endtask

    // Capture the output burst, return the peak.
    task automatic capture_burst(output logic [15:0] peak, input int timeout = 300);
        int t = 0, n = 0;
        peak = '0;
        m_if.s_cb.tready <= 1'b1;
        while (!m_if.tvalid && t < timeout) begin @(m_if.s_cb); t++; end
        while (m_if.tvalid && n < timeout) begin
            if ($signed(m_if.tdata[15:0]) > $signed(peak)) peak = m_if.tdata[15:0];
            n++;
            @(m_if.s_cb);
        end
    endtask


// ============================================================================
// PASTE INTO tc00 — helpers
// ============================================================================

  localparam int    LANE_TOL = 8;    // LSBs: DDS quantization + gain rounding
  localparam real   PI       = 3.14159265358979323846;

  // ref_cos: the model's cosine for a given 32-bit phase, full scale.
  function automatic int ref_cos(input logic [31:0] phase);
      real ang;
      ang = 2.0 * PI * real'(phase) / (2.0 ** 32);
      return $rtoi($cos(ang) * 32767.0);
  endfunction

  function automatic bit near(input int a, input int b, input int tol);
      return (a > b ? a - b : b - a) <= tol;
  endfunction

//  // wait_steady_frame: advance through the pipeline start-up and return the
//  // first output frame that is stable for two consecutive beats. For a
//  // time-constant stimulus this is the settled datapath output, independent
//  // of how many start-up beats a given src mode inserts.
//  task automatic wait_steady_frame(output logic signed [15:0] lanes [N_DDS],
//                                   input int settle_timeout = 400);
//      logic [N_DDS*16-1:0] prev, curr;
//      int t = 0;
//      bit have_prev = 0;
//
//      // Wait for the first valid beat
//      while (!m_if.s_cb.tvalid && t < settle_timeout) begin @(m_if.s_cb); t++; end
//      `FAIL_IF_LOG(!m_if.s_cb.tvalid, "wait_steady_frame: no output");
//
//      prev = m_if.s_cb.tdata;
//      have_prev = 1;
//      @(m_if.s_cb);
//
//      // Advance until two consecutive valid beats agree
//      while (t < settle_timeout) begin
//          if (m_if.s_cb.tvalid) begin
//              curr = m_if.s_cb.tdata;
//              if (have_prev && curr === prev) begin
//                  for (int i = 0; i < N_DDS; i++)
//                      lanes[i] = curr[i*16 +: 16];
//                  return;
//              end
//              prev = curr;
//              have_prev = 1;
//          end else begin
//              have_prev = 0;   // a gap resets the comparison
//          end
//          @(m_if.s_cb);
//          t++;
//      end
//      `FAIL_IF_LOG(1'b1, "wait_steady_frame: output never settled");
//  endtask
//
//  // For time-VARYING stimulus (a real ramp along the burst), "settle" is not
//  // defined — use skip_startup + capture instead: discard a fixed number of
//  // start-up beats measured once per mode, then sample. But none of the
//  // current tests need this; they all read a constant envelope row.

  // wait_output_frame: hold until the first valid output beat, then return
  // all N_DDS lanes of that beat, sampled entirely through s_cb.
  task automatic wait_output_frame(output logic signed [15:0] lanes [N_DDS],
                                   input int timeout = 400);
      int t = 0;
      while (!m_if.s_cb.tvalid && t < timeout) begin @(m_if.s_cb); t++; end
      `FAIL_IF_LOG(!m_if.s_cb.tvalid, "wait_output_frame: no output");
      for (int i = 0; i < N_DDS; i++)
          lanes[i] = m_if.s_cb.tdata[i*16 +: 16];
  endtask

  // capture_frames: collect `n` consecutive output beats through s_cb.
  task automatic capture_frames(output logic signed [15:0] f [][N_DDS],
                                input int n, input int timeout = 400);
      int t = 0;
      f = new[n];
      while (!m_if.s_cb.tvalid && t < timeout) begin @(m_if.s_cb); t++; end
      `FAIL_IF_LOG(!m_if.s_cb.tvalid, "capture_frames: burst never started");
      for (int r = 0; r < n; r++) begin
          for (int i = 0; i < N_DDS; i++)
              f[r][i] = m_if.s_cb.tdata[i*16 +: 16];
          @(m_if.s_cb);
      end
  endtask

// ============================================================================
    // =========================================================================
    // SVUnit
    // =========================================================================
    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();

        // idle explicit BEFORE the reset, blocking, without m_reset() dependency
        s0_if.tvalid = 1'b0;  s0_if.tlast = 1'b0;  s0_if.tdata = '0;
        s0_if.tstrb  = '1;    s0_if.tkeep = '0;    s0_if.tuser = '0;
        s0_if.tid    = '0;    s0_if.tdest = '0;
        s1_if.tvalid = 1'b0;  s1_if.tlast = 1'b0;  s1_if.tdata = '0;
        s1_if.tstrb  = '1;    s1_if.tkeep = '0;    s1_if.tuser = '0;
        s1_if.tid    = '0;    s1_if.tdest = '0;

        s_axi_aresetn <= 1'b0;
        s0_axis_arstn <= 1'b0;
        aresetn       <= 1'b0;
        repeat(20) @(posedge aclk);
        s_axi_aresetn <= 1'b1;
        s0_axis_arstn <= 1'b1;
        aresetn       <= 1'b1;

        // NOW, give the buses to the drivers of the clocking block
        s0_if.m_reset();
        s1_if.m_reset();
        s_axi.reset();
        repeat(20) @(posedge aclk);
    endtask

    task teardown();
        svunit_ut.teardown();
        s0_if.m_cb.tvalid <= 1'b0;
        s1_if.m_cb.tvalid <= 1'b0;
        repeat(10) @(posedge aclk);
    endtask

    initial begin
        #500_000_000;
        $display("INFO: Global timeout reached");
        $finish;
    end

    `SVUNIT_TESTS_BEGIN
    `include "axis_signal_gen_v6_tests.sv"
    `include "dds_phase_probe.sv"
    `include "mem_skew_probe.sv"
    `include "mem_write_probe.sv"
    `include "write_startup_probe.sv"
    `SVUNIT_TESTS_END

endmodule
