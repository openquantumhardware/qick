//-------------------------------------------------------------------------------------------------//
// tests.sv
// Se incluye entre `SVUNIT_TESTS_BEGIN y `SVUNIT_TESTS_END dentro de axis_pipe_unit_test
//-------------------------------------------------------------------------------------------------//

`SVTEST(test00_reset)
  m_axis_if.s_cb.tready <= 1'b1; // evitar X propagation
  repeat(2) @(cb);

  // Estado después de reset
  `FAIL_UNLESS(m_axis_if.s_cb.tvalid == 1'b0);
  `FAIL_UNLESS(s_axis_if.m_cb.tready == 1'b1);

  for (int k = 0; k < 10; k++) begin
    tb_rstn <= 1'b0;
    @(cb);
    tb_rstn <= 1'b1;
    @(cb);
    `FAIL_UNLESS(m_axis_if.s_cb.tvalid == 1'b0);
    `FAIL_UNLESS(s_axis_if.m_cb.tready == 1'b1);
  end
`SVTEST_END

//-------------------------------------------------------------------------------------------------//

`SVTEST(test00_data)
  m_axis_if.s_cb.tready <= 1'b1;
  s_axis_if.m_cb.tvalid <= 1'b0;
  @(cb);

  for (int k = 0; k < 10; k++) begin
    // Inyecta el dato k, con tlast en la última palabra
    s_axis_if.tx(k, (k == 9) ? 1'b1 : 1'b0);
    @(m_axis_if.s_cb);
    `FAIL_UNLESS(m_axis_if.s_cb.tvalid == 1'b1);
    `FAIL_UNLESS(m_axis_if.s_cb.tdata  == k);
    `FAIL_UNLESS(m_axis_if.s_cb.tlast  == (k == 9));
    `FAIL_UNLESS(m_axis_if.s_cb.tstrb  == '1);
  end

  s_axis_if.m_cb.tvalid <= 1'b0;
  m_axis_if.s_cb.tready <= 1'b0;
  repeat(10) @(cb);
`SVTEST_END

//-------------------------------------------------------------------------------------------------//
`SVTEST(test01_backpressure)
  // Random tready: every beat comes out once, in order, with its tlast, and
  // the interface checkers see tdata/tlast held during each stall
  int n_rx;
  logic rdy;
  n_rx = 0;
  fork
    begin
      for (int k = 0; k < 50; k++) s_axis_if.tx(k, (k == 49) ? 1'b1 : 1'b0);
    end
    begin
      while (n_rx < 50) begin
        rdy = 1'($urandom_range(1));
        m_axis_if.s_cb.tready <= rdy;
        @(m_axis_if.s_cb);
        if (m_axis_if.s_cb.tvalid && rdy) begin
          `FAIL_UNLESS(m_axis_if.s_cb.tdata == n_rx);
          `FAIL_UNLESS(m_axis_if.s_cb.tlast == (n_rx == 49));
          n_rx++;
        end
      end
    end
  join

  s_axis_if.m_cb.tvalid <= 1'b0;
  m_axis_if.s_cb.tready <= 1'b0;
  repeat(10) @(cb);
`SVTEST_END

//-------------------------------------------------------------------------------------------------//
