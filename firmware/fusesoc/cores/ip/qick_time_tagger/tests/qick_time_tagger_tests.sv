// ============================================================================
// File: qick_time_tagger_tests.sv
// Description: SVUnit test cases for axi_qick_time_tagger. Included by
//   qick_time_tagger_tc00.sv.
// ============================================================================

`SVTEST(tc_ctrl_self_clears)
   logic [31:0] data;

   send_ctrl_cmd(OP_ARM);
   repeat(10) @(posedge ps_clk);
   s_axi.axi_read(ADDR_CTRL, data);
   `FAIL_UNLESS_LOG(data === 32'd0,
      $sformatf("CTRL_REG=0x%08h, expected 0 (AUTO_CLEAR_BIT0 self-clear)", data));

   // Disarm again so this test doesn't leave the DUT armed for the next one.
   send_ctrl_cmd(OP_DISARM);
`SVTEST_END

`SVTEST(tc_cfg_register_is_plain_rw)
   logic [31:0] data;

   s_axi.axi_write(ADDR_CFG, 32'h0000_0401);
   s_axi.axi_read(ADDR_CFG, data);
   `FAIL_UNLESS_LOG(data === 32'h0000_0401,
      $sformatf("CFG_REG=0x%08h, expected 0x00000401 (plain read/write, no self-clear)", data));
`SVTEST_END

`SVTEST(tc_ro_register_ignores_writes)
   logic [31:0] data;

   // PROC_DT_REG is read-only (axil_slv's i_reg_is_readonly): a write must
   // not land, and reading it back must return the hardware-driven value
   // (0 here, nothing has been popped yet), not the garbage just written.
   s_axi.axi_write(ADDR_PROC_DT, 32'hDEAD_BEEF);
   s_axi.axi_read(ADDR_PROC_DT, data);
   `FAIL_IF_LOG(data === 32'hDEAD_BEEF,
      "PROC_DT_REG accepted a write - i_reg_is_readonly is not gating this register");
   `FAIL_UNLESS_LOG(data === 32'd0,
      $sformatf("PROC_DT_REG=0x%08h, expected 0 (nothing popped yet)", data));
`SVTEST_END

`SVTEST(tc_axi_arm_trigger_dma_readback)
   logic [31:0] data;
   bit ok;

   // Stage and issue SET_THRESHOLD.
   s_axi.axi_write(ADDR_AXI_DT1, 32'd150);
   send_ctrl_cmd(OP_SET_TH);
   repeat(5) @(posedge ps_clk);

   // Arm.
   send_ctrl_cmd(OP_ARM);
   repeat(5) @(posedge ps_clk);

   // Monotonically increasing samples: index 1 (200) is the first to cross
   // th=150 (same pattern already proven at the qtt_tag_calc/qick_time_tagger
   // Tier 2 level). Held for many cycles so it survives the whole
   // filter/compare/encoder/interpolator pipeline.
   adc0_dt <= pack_burst(50, 200, 300, 400, 400, 400, 400, 400);
   repeat(80) @(posedge adc_clk);
   adc0_dt <= '0;

   // Let the tag propagate into the ring buffer, then read it back over
   // the DMA AXI-stream (dma_cfg: length=1, mem_sel=0 -> tag channel 0).
   repeat(60) @(posedge ps_clk);
   dma_read_one(24'h000_01_0, data, ok); // length=1 in bits[23:4], mem_sel=0 in bits[2:0]
   `FAIL_UNLESS_LOG(ok, "AXI-driven DMA readback of the tag channel never completed (tlast not seen)");
   `FAIL_UNLESS_LOG(data[2:0] === 3'd1,
      $sformatf("tag_dt_o[2:0]=%0d, expected 1 (sample index 200 was the first to cross th=150)", data[2:0]));

   send_ctrl_cmd(OP_DISARM);
`SVTEST_END

// ---- reset ("reset does not clear the memories reliably / locks up the time tagger") ----

`SVTEST(tc_reset_idle_clears_memories)
   logic [31:0] t0, a0, t1, a1;

   configure_th_inh();
   send_ctrl_cmd(OP_ARM);
   repeat(5) @(posedge ps_clk);
   pulse_and_settle();
   send_ctrl_cmd(OP_DISARM);
   settle();
   read_qtys(t0, a0);
   `FAIL_UNLESS_LOG(t0 >= 1, $sformatf("TAG0_QTY=%0d before the reset, expected at least 1 tag", t0));
   `FAIL_UNLESS_LOG(a0 === 32'd1, $sformatf("ARM_QTY=%0d before the reset, expected 1 arm session", a0));

   send_ctrl_cmd(OP_RESET);
   settle();
   read_qtys(t1, a1);
   `FAIL_UNLESS_LOG(t1 === 32'd0, $sformatf("TAG0_QTY=%0d after reset while idle, expected 0", t1));
   `FAIL_UNLESS_LOG(a1 === 32'd0, $sformatf("ARM_QTY=%0d after reset while idle, expected 0", a1));
`SVTEST_END

`SVTEST(tc_reset_idle_then_tagger_still_works)
   logic [31:0] t0, a0;

   configure_th_inh();
   send_ctrl_cmd(OP_RESET);
   settle();
   send_ctrl_cmd(OP_ARM);
   repeat(5) @(posedge ps_clk);
   pulse_and_settle();
   read_qtys(t0, a0);
   `FAIL_UNLESS_LOG(t0 >= 1, $sformatf("TAG0_QTY=%0d after reset + arm + pulse: the tagger did not tag (locked up?)", t0));
   send_ctrl_cmd(OP_DISARM);
`SVTEST_END

`SVTEST(tc_reset_while_armed)
   logic [31:0] t0, a0, t1, a1, t2, a2;

   configure_th_inh();
   send_ctrl_cmd(OP_ARM);
   repeat(5) @(posedge ps_clk);
   pulse_and_settle();
   read_qtys(t0, a0);
   `FAIL_UNLESS_LOG(t0 >= 1, $sformatf("TAG0_QTY=%0d before the reset, expected at least 1 tag", t0));

   send_ctrl_cmd(OP_RESET);
   settle();
   read_qtys(t1, a1);
   `FAIL_UNLESS_LOG(t1 === 32'd0, $sformatf("TAG0_QTY=%0d after reset while armed, expected 0", t1));

   // still armed: a new pulse must be tagged
   pulse_and_settle();
   read_qtys(t2, a2);
   `FAIL_UNLESS_LOG(t2 >= 1, $sformatf("TAG0_QTY=%0d: no tag after the reset while armed (locked up?)", t2));
   send_ctrl_cmd(OP_DISARM);
`SVTEST_END

`SVTEST(tc_reset_twice_in_a_row)
   logic [31:0] t0, a0;

   configure_th_inh();
   send_ctrl_cmd(OP_RESET);
   repeat(3) @(posedge ps_clk);
   send_ctrl_cmd(OP_RESET);
   settle();
   send_ctrl_cmd(OP_ARM);
   repeat(5) @(posedge ps_clk);
   pulse_and_settle();
   read_qtys(t0, a0);
   `FAIL_UNLESS_LOG(t0 >= 1, $sformatf("TAG0_QTY=%0d after two resets: the tagger did not tag", t0));
   send_ctrl_cmd(OP_DISARM);
`SVTEST_END
