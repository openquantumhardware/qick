`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module axis_data_concat_unit_test;
  import svunit_pkg::svunit_testcase;

  string name = "axis_data_concat_ut";
  svunit_testcase svunit_ut;

  localparam CLOCK_FREQUENCY = 250e6; //[Hz]

  localparam NB_IN  = 16;
  localparam NB_OFF = 16;

  logic              tb_clk     = 1'b0;
  logic              tb_rstn    = 1'b0;
  logic [NB_OFF-1:0] tb_offset;

  initial begin
    $dumpfile("axis_data_concat.vcd");
    $dumpvars();
  end

  clk_gen#(
    .FREQ       ( CLOCK_FREQUENCY   )
  )u_clk_gen(
    .i_enable   ( 1'b1              ),
    .o_clk      ( tb_clk            )
  );

axi4_stream_if #(
    .TDATA_WIDTH (NB_IN)
) s_axis_if (.aclk(tb_clk), .aresetn(tb_rstn));

axi4_stream_if #(
    .TDATA_WIDTH (NB_IN + NB_OFF)
) m_axis_if (.aclk(tb_clk), .aresetn(tb_rstn));

  default clocking cb @(posedge tb_clk);
    default input #1step output #2;
    output tb_offset;
  endclocking

  //===================================
  // This is the UUT that we're
  // running the Unit Tests on
  //===================================

  axis_data_concat#(
    .NB_IN    ( NB_IN      ),
    .NB_OFF   ( NB_OFF     )
  )u_axis_data_concat(
    .i_clk    ( tb_clk     ),
    .i_rstn   ( tb_rstn    ),
    .s_axis   ( s_axis_if  ),
    .m_axis   ( m_axis_if  ),
    .i_offset ( tb_offset  )
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
    s_axis_if.m_cb.tlast  <= 1'b0;
    m_axis_if.s_cb.tready <= 1'b0;
    cb.tb_offset          <= '0;

    tb_rstn <= 1'b0;
    repeat(2) @(cb);
    tb_rstn <= 1'b1;
    @(cb);
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
  //===================================

  `SVUNIT_TESTS_BEGIN
    `include "tests.sv"
  `SVUNIT_TESTS_END

endmodule
