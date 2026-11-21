//-------------------------------------------------------------------------------------------------//
// tests.sv
// Included between `SVUNIT_TESTS_BEGIN and `SVUNIT_TESTS_END in axis_data_concat_unit_test
//-------------------------------------------------------------------------------------------------//

`SVTEST(test00_passthrough)
  // Random values on every input each cycle: the outputs follow them in the
  // same cycle (combinational), with i_offset on top of tdata. The stimulus
  // stays legal AXI-Stream for the interface checkers: during a stall
  // (tvalid && !tready) the beat and i_offset are held.
  logic              v, r, l;
  logic [NB_IN-1:0]  d;
  logic [NB_OFF-1:0] off;
  v = 1'b0;
  r = 1'b0;
  for (int k = 0; k < 200; k++) begin
    if (!(v && !r)) begin
      v   = 1'($urandom());
      l   = 1'($urandom());
      d   = NB_IN'($urandom());
      off = NB_OFF'($urandom());
    end
    r = 1'($urandom());
    s_axis_if.m_cb.tvalid <= v;
    s_axis_if.m_cb.tdata  <= d;
    s_axis_if.m_cb.tlast  <= l;
    m_axis_if.s_cb.tready <= r;
    cb.tb_offset          <= off;
    @(cb);
    `FAIL_UNLESS(m_axis_if.s_cb.tvalid == v);
    `FAIL_UNLESS(s_axis_if.m_cb.tready == r);
    `FAIL_UNLESS(m_axis_if.s_cb.tlast  == l);
    `FAIL_UNLESS(m_axis_if.s_cb.tdata  == {off, d});
  end
  // Accept a beat still pending before going idle
  m_axis_if.s_cb.tready <= 1'b1;
  @(cb);
  s_axis_if.m_cb.tvalid <= 1'b0;
  m_axis_if.s_cb.tready <= 1'b0;
  @(cb);
`SVTEST_END

//-------------------------------------------------------------------------------------------------//

`SVTEST(test01_frame)
  // A 20-beat frame through the interface tasks, with a slave that waits a
  // random number of cycles before each beat; the interface checkers are on.
  logic [NB_IN+NB_OFF-1:0] data;
  logic                    last;
  cb.tb_offset <= 16'hA5C3;
  @(cb);
  fork
    begin
      for (int k = 0; k < 20; k++) s_axis_if.tx(NB_IN'(k * 3 + 1), (k == 19) ? 1'b1 : 1'b0);
    end
    begin
      for (int k = 0; k < 20; k++) begin
        repeat ($urandom_range(3)) @(m_axis_if.s_cb);
        m_axis_if.rx(data, last);
        `FAIL_UNLESS(data == {16'hA5C3, NB_IN'(k * 3 + 1)});
        `FAIL_UNLESS(last == (k == 19));
      end
    end
  join
  repeat(5) @(cb);
`SVTEST_END

//-------------------------------------------------------------------------------------------------//
