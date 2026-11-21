`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module axis_tap_unit_test;
  import svunit_pkg::svunit_testcase;

  string name = "axis_tap_ut";
  svunit_testcase svunit_ut;

  localparam CLOCK_FREQUENCY = 250e6; //[Hz]
  localparam DWIDTH          = 32;      // equals the tap NB parameter
  localparam NB              = DWIDTH;

  logic tb_clk  = 1'b0;
  logic tb_rstn = 1'b0;
  logic tb_enable;

  // Observed-stream consumer: axis_tap does NOT drive s_axis.tready,
  // so the TB drives it as the real downstream consumer would.
  logic tb_obs_tready;

  initial begin
    $dumpfile("axis_tap.vcd");
    $dumpvars();
  end

  clk_gen#(
    .FREQ     ( CLOCK_FREQUENCY )
  )u_clk_gen(
    .i_enable ( 1'b1            ),
    .o_clk    ( tb_clk          )
  );

  // Observed stream (TB acts as MASTER to inject beats)
  axi4_stream_if #(
    .TDATA_WIDTH (DWIDTH),
    .HAS_TSTRB   (1'b1),
    .HAS_TKEEP   (1'b0),
    .HAS_TID     (1'b0),
    .HAS_TDEST   (1'b0),
    .HAS_TUSER   (1'b0)
  ) s_axis_if (
    .aclk    (tb_clk),
    .aresetn (tb_rstn)
  );

  // Monitor stream (TB acts as SLAVE to consume the tap output)
  axi4_stream_if #(
    .TDATA_WIDTH (DWIDTH),
    .HAS_TSTRB   (1'b1),
    .HAS_TKEEP   (1'b0),
    .HAS_TID     (1'b0),
    .HAS_TDEST   (1'b0),
    .HAS_TUSER   (1'b0)
  ) m_axis_if (
    .aclk    (tb_clk),
    .aresetn (tb_rstn)
  );

  default clocking cb @(posedge tb_clk);
    default input #1step output #2;
  endclocking

  //===================================
  // UUT
  //===================================
  //  IMPORTANT: axis_tap reads s_axis.tready but does NOT drive it.
  //  The TB drives s_axis.tready via tb_obs_tready (emulated real consumer).
  assign s_axis_if.tready = tb_obs_tready;

  axis_tap#(
    .NB (NB)
  )u_axis_tap(
    .aclk     ( tb_clk        ),
    .aresetn  ( tb_rstn       ),
    .s_axis   ( s_axis_if     ),
    .m_axis   ( m_axis_if     ),
    .i_enable ( tb_enable     )
  );

  //===================================
  // Build
  //===================================
  function void build();
    svunit_ut = new(name);
  endfunction

  //===================================
  // Setup for running the Unit Tests
  //===================================
  task setup();
    svunit_ut.setup();
    // Idle the master driving s_axis
    s_axis_if.m_cb.tdata  <= '0;
    s_axis_if.m_cb.tlast  <= 1'b0;
    s_axis_if.m_cb.tvalid <= 1'b0;
    s_axis_if.m_cb.tstrb  <= '1;
    // Observed-stream consumer ready by default
    tb_obs_tready         = 1'b1;
    // Monitor consumer ready by default
    m_axis_if.s_cb.tready <= 1'b1;
    // Tap disabled by default
    tb_enable             = 1'b0;

    tb_rstn <= 1'b0;
    @(cb);
    tb_rstn <= 1'b1;
    @(cb);
  endtask

  //===================================
  // Teardown after running the Unit Tests
  //===================================
  task teardown();
    svunit_ut.teardown();
  endtask

  //===================================
  // Helper: inject one beat on the observed stream and wait for handshake.
  // It does NOT use s_axis_if.tx() because the tap does not drive tready.
  //===================================
  task automatic drive_obs_beat(input logic [NB-1:0] data,
                                input logic          last = 1'b0,
                                input int            timeout = 1000);
    int cnt = 0;
    s_axis_if.m_cb.tdata  <= data;
    s_axis_if.m_cb.tlast  <= last;
    s_axis_if.m_cb.tstrb  <= '1;
    s_axis_if.m_cb.tvalid <= 1'b1;
    do begin
      @(s_axis_if.m_cb);
      if (++cnt > timeout) $fatal(1, "[TB_FATAL] observed beat timeout");
    end while (!s_axis_if.tready);
    s_axis_if.m_cb.tvalid <= 1'b0;
    s_axis_if.m_cb.tlast  <= 1'b0;
  endtask

  `SVUNIT_TESTS_BEGIN
  `include "axis_tap_tests.sv"
  `SVUNIT_TESTS_END

endmodule
