`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module axis_pipe_unit_test;
  import svunit_pkg::svunit_testcase;

  string name = "axis_pipe_ut";
  svunit_testcase svunit_ut;

  localparam CLOCK_FREQUENCY = 250e6; //[Hz]

  localparam DWIDTH             = 32;

  logic              tb_clk     = 1'b0;
  logic              tb_rstn    = 1'b0;

  initial begin
    $dumpfile("axis_pipe.vcd");
    $dumpvars();
  end

  clk_gen#(
    .FREQ       ( CLOCK_FREQUENCY   )
  )u_clk_gen(
    .i_enable   ( 1'b1              ),
    .o_clk      ( tb_clk            )
  );

axi4_stream_if #(
    .TDATA_WIDTH (DWIDTH),
    .HAS_TSTRB   (1'b1),
    .HAS_TKEEP   (1'b0),
    .HAS_TID     (1'b0),
    .HAS_TDEST   (1'b0),
    .HAS_TUSER   (1'b0)
) s_axis_if (.aclk(tb_clk), .aresetn(tb_rstn));

axi4_stream_if #(
    .TDATA_WIDTH (DWIDTH),
    .HAS_TSTRB   (1'b1),
    .HAS_TKEEP   (1'b0),
    .HAS_TID     (1'b0),
    .HAS_TDEST   (1'b0),
    .HAS_TUSER   (1'b0)
) m_axis_if (.aclk(tb_clk), .aresetn(tb_rstn));

  default clocking cb @(posedge tb_clk);
    default input #1step output #2;
  endclocking

  //===================================
  // This is the UUT that we're
  // running the Unit Tests on
  //===================================

  axis_pipe#(
    .DWIDTH (DWIDTH)
  )u_axis_pipe(
    .clk      ( tb_clk     ),
    .rstn     ( tb_rstn    ),
    .s_axis   ( s_axis_if  ),
    .m_axis   ( m_axis_if  )
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
    s_axis_if.m_cb.tdata  <= '0;
    s_axis_if.m_cb.tvalid <= 1'b0;
    m_axis_if.s_cb.tready <= 1'b1;

    tb_rstn <= 1'b0;
    @(cb);
    tb_rstn          <= 1'b1;
    
  endtask

  //===================================
  // Here we deconstruct anything we 
  // need after running the Unit Tests
  //===================================
  task teardown();
    svunit_ut.teardown();
  endtask

  //===================================
  // All tests are defined between the
  // SVUNIT_TESTS_BEGIN/END macros
  //
  // Each individual test must be
  // defined between `SVTEST(_NAME_)
  // `SVTEST_END
  //
  // i.e.
  //   `SVTEST(mytest)
  //     <test code>
  //   `SVTEST_END
  //===================================

  //freq valid: n*2.5 - 91.25 [MHz]
  //para todo n entero de de 0 a 73.
  //int freq[NUMBER_FREQ] = {    8.75e6, 
  //11.25e6, 
  //28.75e6, 
  //31.25e6, 
  //38.75e6, 
  //41.25e6, 
  //53.75e6, 
  //56.25e6, 
  //66.25e6, 
  //68.75e6,
  //83.75e6, 
  //88.75e6};

  //int inc_phase_queue[$];

  //longint tick = 0;
  //longint inc_phase;
  //bit flag = 1'b0;
  //int index = 0;

  `SVUNIT_TESTS_BEGIN
  `include "tests.sv"
  `SVUNIT_TESTS_END 

endmodule
