//-------------------------------------------------------------------------------------------------//
// tests.sv
// Included between `SVUNIT_TESTS_BEGIN and `SVUNIT_TESTS_END inside axis_tap_unit_test
//-------------------------------------------------------------------------------------------------//

`SVTEST(test00_reset)
  // After reset, the monitor must not have a valid beat
  m_axis_if.s_cb.tready <= 1'b1; // avoid X propagation
  repeat(2) @(cb);
  `FAIL_UNLESS(m_axis_if.s_cb.tvalid == 1'b0);

  // Repeated reset cycles
  for (int k = 0; k < 10; k++) begin
    tb_rstn <= 1'b0;
    @(cb);
    tb_rstn <= 1'b1;
    @(cb);
    `FAIL_UNLESS(m_axis_if.s_cb.tvalid == 1'b0);
  end
`SVTEST_END

//-------------------------------------------------------------------------------------------------//
// With i_enable=0 the tap must NOT capture even if the observed handshake occurs
`SVTEST(test01_disabled_no_capture)
  tb_enable             = 1'b0;
  tb_obs_tready         = 1'b1;
  m_axis_if.s_cb.tready <= 1'b1;
  @(cb);

  drive_obs_beat(32'hAAAA_5555, 1'b0);
  @(cb);
  `FAIL_UNLESS(m_axis_if.s_cb.tvalid == 1'b0);
`SVTEST_END

//-------------------------------------------------------------------------------------------------//
// With i_enable=1 the tap captures tdata and forwards it on the monitor
`SVTEST(test02_enabled_captures_tdata)
  logic [DWIDTH-1:0] got_data;
  logic              got_last;

  tb_enable     = 1'b1;
  tb_obs_tready = 1'b1;
  @(cb);

  drive_obs_beat(32'h1234_5678, 1'b0);

  // Consume from the monitor using the interface rx() task
  m_axis_if.rx(got_data, got_last);
  `FAIL_UNLESS(got_data == 32'h1234_5678);
`SVTEST_END

//-------------------------------------------------------------------------------------------------//
// tlast is propagated to the monitor
`SVTEST(test03_tlast_propagates)
  logic [DWIDTH-1:0] got_data;
  logic              got_last;

  tb_enable     = 1'b1;
  tb_obs_tready = 1'b1;
  @(cb);

  drive_obs_beat(32'hCAFE_BABE, 1'b1);

  m_axis_if.rx(got_data, got_last);
  `FAIL_UNLESS(got_data == 32'hCAFE_BABE);
  `FAIL_UNLESS(got_last == 1'b1);
`SVTEST_END

//-------------------------------------------------------------------------------------------------//
// Without an observed handshake (tvalid high but obs_tready low) nothing is captured
`SVTEST(test04_no_capture_without_handshake)
  tb_enable             = 1'b1;
  tb_obs_tready         = 1'b0;       // no downstream consumer
  m_axis_if.s_cb.tready <= 1'b1;

  s_axis_if.m_cb.tdata  <= 32'hDEAD_BEEF;
  s_axis_if.m_cb.tstrb  <= '1;
  s_axis_if.m_cb.tvalid <= 1'b1;
  repeat(4) @(cb);
  `FAIL_UNLESS(m_axis_if.s_cb.tvalid == 1'b0);

  // release
  s_axis_if.m_cb.tvalid <= 1'b0;
  tb_obs_tready         = 1'b1;
  @(cb);
`SVTEST_END

//-------------------------------------------------------------------------------------------------//
// "Snapshot" semantics (NOT a FIFO): with the monitor stalled,
// two consecutive beats -> the LAST one is kept.
`SVTEST(test05_snapshot_last_value)
  logic [DWIDTH-1:0] got_data;
  logic              got_last;

  tb_enable             = 1'b1;
  tb_obs_tready         = 1'b1;
  m_axis_if.s_cb.tready <= 1'b0;      // stall the monitor consumer
  @(cb);

  drive_obs_beat(32'h0000_0001, 1'b0);
  drive_obs_beat(32'h0000_0002, 1'b0); // overwrites the previous one

  // Now consume: expect the last captured value (0x2)
  m_axis_if.rx(got_data, got_last);
  `FAIL_UNLESS(got_data == 32'h0000_0002);
`SVTEST_END

//-------------------------------------------------------------------------------------------------//
// Burst of several beats with enable active: each consumed beat matches
`SVTEST(test06_burst_capture)
  logic [DWIDTH-1:0] got_data;
  logic              got_last;

  tb_enable             = 1'b1;
  tb_obs_tready         = 1'b1;
  m_axis_if.s_cb.tready <= 1'b1;
  @(cb);

  for (int k = 0; k < 8; k++) begin
    // Inject beat k and consume it immediately (monitor always ready)
    fork
      drive_obs_beat(k, (k == 7));
      begin
        m_axis_if.rx(got_data, got_last);
        `FAIL_UNLESS(got_data == k);
      end
    join
  end
`SVTEST_END

//-------------------------------------------------------------------------------------------------//
