`SVTEST(test00_reset)

//     `ASSERT_IMMEDIATE(tb_i_data  == '0);     
     repeat(5) @(cb);
        for (integer k = 0; k < 10; k = k + 1) begin
        tb_time_rstn <= 1'b0;
        @(cb);
        tb_time_rstn <= 1'b1;
        @(cb);
//     `ASSERT_IMMEDIATE(tb_o_data  == '0);     
     @(cb);
 end

     repeat(5) @(cb_core);
        for (integer k = 0; k < 10; k = k + 1) begin
        tb_core_rstn <= 1'b0;
        @(cb_core);
        tb_core_rstn <= 1'b1;
        @(cb_core);
//     `ASSERT_IMMEDIATE(tb_o_data  == '0);     
     @(cb_core);
    end

     repeat(2) @(cb_ps);
        for (integer k = 0; k < 10; k = k + 1) begin
        tb_ps_rstn   <= 1'b0;
        @(cb_ps);
        tb_ps_rstn   <= 1'b1;
        @(cb_ps);
//     `ASSERT_IMMEDIATE(tb_o_data  == '0);     
     @(cb_ps);
 end
     
`SVTEST_END
//-------------------------------------------------------------------------------------------------//
`SVTEST(test01_core_to_time)

    @(cb_core);
    tb_i_core_op    <= 5'b0_1000;     
    tb_i_core_data1 <= 32'h0000_0002;     
    tb_i_core_data2 <= 32'h0000_0004;     
    tb_i_core_en    <= 1'b1;     
    @(cb_core);
    tb_i_core_en    <= 1'b0;     
    for (integer k = 0; k < 10; k = k + 1) begin
        tb_i_core_data1 <= k;
        tb_i_core_data2 <= k+1;
        @(cb_core);
        
        //if (k > 1) 
        //    `ASSERT_IMMEDIATE(tb_o_data  == k-1);     
    end
    repeat(5) @(cb_core);

`SVTEST_END
//-------------------------------------------------------------------------------------------------//
// A single Python/AXI command (one CTRL_REG write) must be executed exactly once. Before the
// AUTO_CLEAR_BIT0 + xcom_cmd_hold fix, CTRL_REG never cleared itself and req_ack_cmd's level-sensitive
// FSM re-issued the same command forever (measured: 13 repeats in 300 i_ps_clk cycles).
`SVTEST(test02_axi_command_executes_once)
    logic [31:0] cntr0, cntr1, cntr2;
    s_axi.reset();
    repeat(20) @(posedge tb_ps_clk);
    s_axi.axi_write(6'h08, 32'd5);                 // AXI_DATA1 = 5
    s_axi.axi_write(6'h0C, 32'd0);                 // AXI_DATA2
    cntr0 = u_xcom.s_cmd_cntr;
    s_axi.axi_write(6'h00, 32'd1 + 32'd2*16);      // CTRL = strobe + XCOM_SET_ID (local command)
    repeat(300) @(posedge tb_ps_clk);
    cntr1 = u_xcom.s_cmd_cntr;
    repeat(300) @(posedge tb_ps_clk);
    cntr2 = u_xcom.s_cmd_cntr;
    `FAIL_UNLESS_LOG(((cntr1 - cntr0) & 32'hF) == 1,
        $sformatf("one CTRL write executed %0d times after 300 PS clocks", (cntr1 - cntr0) & 32'hF));
    `FAIL_UNLESS_LOG(cntr2 == cntr1, "the command counter keeps changing: the command repeats");
`SVTEST_END
//-------------------------------------------------------------------------------------------------//
// DEBUG_REG is 32 bits since 1.0.0: the cfg tick (bits [31:29] before, its MSB truncated) is out. With tick 7 the old bus
// read 3'b111 there. TX_RX_DDR_REG (index 5) reads back what was written.
`SVTEST(test03_debug_reg_has_no_tick)
    logic [31:0] cfg, dbg, ddr;
    s_axi.reset();
    repeat(20) @(posedge tb_ps_clk);
    s_axi.axi_write(6'h04, 32'h0000_0407);         // CFG = tick 7, auto phase
    s_axi.axi_write(6'h14, 32'h0123_8ABC);         // TX_RX_DDR
    repeat(100) @(posedge tb_ps_clk);
    s_axi.axi_read(6'h04, cfg);
    s_axi.axi_read(6'h3C, dbg);
    s_axi.axi_read(6'h14, ddr);
    `FAIL_UNLESS_LOG(cfg == 32'h0000_0407, $sformatf("CFG reads %08h", cfg));
    `FAIL_UNLESS_LOG(dbg[31:29] == 3'b000, $sformatf("DEBUG[31:29] = %03b, the tick is still in the bus", dbg[31:29]));
    `FAIL_UNLESS_LOG(ddr == 32'h0123_8ABC, $sformatf("TX_RX_DDR reads %08h", ddr));
`SVTEST_END
//-------------------------------------------------------------------------------------------------//
