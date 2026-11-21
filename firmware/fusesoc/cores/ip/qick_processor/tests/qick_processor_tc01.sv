// ============================================================================
// File: qick_processor_tc01.sv
// Description: SVUnit testbench for qick_processor, FIFO-full pause stimuli.
//
// Same DUT wiring as qick_processor_tc00, with what the pause needs and tc00
// does not have: two wave ports, a different clock for each domain (c_clk
// 200 MHz, t_clk 384 MHz, ps_clk 100 MHz), small FIFOs (FIFO_DEPTH = 4, 16
// entries) and an m1 stream whose tready the test controls.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module qick_processor_pause_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "qick_processor_pause_ut";
    svunit_testcase svunit_ut;

    // =========================================================================
    // Parameters
    // =========================================================================
    localparam real CLOCK_FREQUENCY = 200e6;

    localparam logic [2:0] C_RUN = 3'd5; // core_st_ds encoding (qproc_ctrl.sv)

    // Register map (byte-addressed, matches qproc_axi_reg.sv's header).
    localparam int ADDR_TPROC_CTRL = 'h00;
    localparam int ADDR_TPROC_CFG  = 'h04;
    localparam int ADDR_MEM_ADDR   = 'h08;
    localparam int ADDR_MEM_LEN    = 'h0C;
    localparam int ADDR_CORE_CFG   = 'h1C;
    localparam int ADDR_FIXED_ID   = 'h24;

    // =========================================================================
    // Clock & reset
    // =========================================================================
    logic tb_clk  = 1'b0;
    logic tb_rstn = 1'b1;

    // tb_clk is ps_clk (AXI-Lite and DMA); the core and the time base have their own
    logic tb_c_clk = 1'b0;
    logic tb_t_clk = 1'b0;
    clk_gen #(.FREQ (100e6)) u_clk_gen_ps (.i_enable (1'b1), .o_clk (tb_clk));
    clk_gen #(.FREQ (200e6)) u_clk_gen_c  (.i_enable (1'b1), .o_clk (tb_c_clk));
    clk_gen #(.FREQ (384e6)) u_clk_gen_t  (.i_enable (1'b1), .o_clk (tb_t_clk));

    // =========================================================================
    // AXI-Lite master interface (wired to the DUT's flat s_axi_* pins below)
    // =========================================================================
    axi4_lite_if #(
        .DATA_WIDTH (32),
        .ADDR_WIDTH (8)
    ) s_axi (
        .aclk    (tb_clk),
        .aresetn (tb_rstn)
    );

    // =========================================================================
    // DUT signals
    // =========================================================================
    logic tb_ext_flag_i    = 1'b0;
    logic tb_proc_start_i  = 1'b0;
    logic tb_proc_stop_i   = 1'b0;
    logic tb_core_start_i  = 1'b0;
    logic tb_core_stop_i   = 1'b0;
    logic tb_time_rst_i    = 1'b0;
    logic tb_time_init_i   = 1'b0;
    logic tb_time_updt_i   = 1'b0;
    logic [31:0] tb_time_dt_i = '0;
    logic [47:0] tb_t_time_abs_o;
    logic        tb_pulse_sync_o;

    logic        tb_qnet_en_o;
    logic [4:0]  tb_qnet_op_o;
    logic [31:0] tb_qnet_a_dt_o, tb_qnet_b_dt_o, tb_qnet_c_dt_o;
    logic        tb_qnet_rdy_i = 1'b0;
    logic [31:0] tb_qnet_dt1_i = '0, tb_qnet_dt2_i = '0;
    logic        tb_qnet_vld_i = 1'b0, tb_qnet_flag_i = 1'b0;

    logic        tb_qcom_en_o;
    logic [4:0]  tb_qcom_op_o;
    logic [31:0] tb_qcom_dt_o;
    logic        tb_qcom_rdy_i = 1'b0;
    logic [31:0] tb_qcom_dt1_i = '0, tb_qcom_dt2_i = '0;
    logic        tb_qcom_vld_i = 1'b0, tb_qcom_flag_i = 1'b0;

    logic        tb_qp1_en_o;
    logic [4:0]  tb_qp1_op_o;
    logic [31:0] tb_qp1_a_dt_o, tb_qp1_b_dt_o, tb_qp1_c_dt_o, tb_qp1_d_dt_o;
    logic        tb_qp1_rdy_i = 1'b0;
    logic [31:0] tb_qp1_dt1_i = '0, tb_qp1_dt2_i = '0;
    logic        tb_qp1_vld_i = 1'b0, tb_qp1_flag_i = 1'b0;

    logic        tb_qp2_en_o;
    logic [4:0]  tb_qp2_op_o;
    logic [31:0] tb_qp2_a_dt_o, tb_qp2_b_dt_o, tb_qp2_c_dt_o, tb_qp2_d_dt_o;
    logic        tb_qp2_rdy_i = 1'b0;
    logic [31:0] tb_qp2_dt1_i = '0, tb_qp2_dt2_i = '0;
    logic        tb_qp2_vld_i = 1'b0;

    logic [255:0] tb_s_dma_axis_tdata_i  = '0;
    logic         tb_s_dma_axis_tlast_i  = 1'b0;
    logic         tb_s_dma_axis_tvalid_i = 1'b0;
    logic         tb_s_dma_axis_tready_o;
    logic [255:0] tb_m_dma_axis_tdata_o;
    logic         tb_m_dma_axis_tlast_o;
    logic         tb_m_dma_axis_tvalid_o;
    logic         tb_m_dma_axis_tready_i = 1'b0;

    logic [63:0] tb_s0_axis_tdata = '0; logic tb_s0_axis_tvalid = 1'b0; logic tb_s0_axis_tready;
    logic [63:0] tb_s1_axis_tdata = '0; logic tb_s1_axis_tvalid = 1'b0; logic tb_s1_axis_tready;

    logic [167:0] tb_m0_axis_tdata; logic tb_m0_axis_tvalid; logic tb_m0_axis_tready = 1'b0;
    logic [167:0] tb_m1_axis_tdata; logic tb_m1_axis_tvalid; logic tb_m1_axis_tready = 1'b0;

    logic tb_trig_0_o, tb_trig_1_o, tb_trig_2_o, tb_trig_5_o, tb_trig_31_o;
    logic [3:0] tb_port_0_dt_o, tb_port_1_dt_o;

    logic [31:0] tb_ps_debug_do, tb_t_debug_do, tb_t_fifo_do;
    logic [31:0] tb_c_time_usr_do, tb_c_debug_do, tb_c_time_ref_do;
    logic [31:0] tb_c_proc_do, tb_c_port_do, tb_c_core_do;

    // Dumped into the VCD that qick_processor_tc00 opens: xsim allows one VCD per simulation, and
    // $dumpvars() with no arguments dumps the scope of the module that calls it.
    initial $dumpvars();

    // =========================================================================
    // DUT
    // =========================================================================
    qick_processor #(
        .DUAL_CORE     (0),
        .GEN_SYNC      (0),
        .DEBUG         (3),
        .LFSR          (1),
        .DIVIDER       (1),
        .ARITH         (1),
        .TIME_READ     (1),
        .FIFO_DEPTH    (4),   // 16 entries per wave/trigger/data FIFO: a short train fills it
        .PMEM_AW       (8),
        .DMEM_AW       (8),
        .WMEM_AW       (8),
        .REG_AW        (4),
        .IN_PORT_QTY   (1),
        .OUT_TRIG_QTY  (2),
        .OUT_DPORT_QTY (1),
        .OUT_DPORT_DW  (4),
        .OUT_WPORT_QTY (2)
    ) u_dut (
        .t_clk_i   (tb_t_clk),
        .t_resetn  (tb_rstn),
        .c_clk_i   (tb_c_clk),
        .c_resetn  (tb_rstn),
        .ps_clk_i  (tb_clk),
        .ps_resetn (tb_rstn),
        .ext_flag_i   (tb_ext_flag_i),
        .proc_start_i (tb_proc_start_i),
        .proc_stop_i  (tb_proc_stop_i),
        .core_start_i (tb_core_start_i),
        .core_stop_i  (tb_core_stop_i),
        .time_rst_i   (tb_time_rst_i),
        .time_init_i  (tb_time_init_i),
        .time_updt_i  (tb_time_updt_i),
        .time_dt_i    (tb_time_dt_i),
        .t_time_abs_o (tb_t_time_abs_o),
        .pulse_sync_o (tb_pulse_sync_o),
        .qnet_en_o (tb_qnet_en_o), .qnet_op_o (tb_qnet_op_o),
        .qnet_a_dt_o (tb_qnet_a_dt_o), .qnet_b_dt_o (tb_qnet_b_dt_o), .qnet_c_dt_o (tb_qnet_c_dt_o),
        .qnet_rdy_i (tb_qnet_rdy_i), .qnet_dt1_i (tb_qnet_dt1_i), .qnet_dt2_i (tb_qnet_dt2_i),
        .qnet_vld_i (tb_qnet_vld_i), .qnet_flag_i (tb_qnet_flag_i),
        .qcom_en_o (tb_qcom_en_o), .qcom_op_o (tb_qcom_op_o), .qcom_dt_o (tb_qcom_dt_o),
        .qcom_rdy_i (tb_qcom_rdy_i), .qcom_dt1_i (tb_qcom_dt1_i), .qcom_dt2_i (tb_qcom_dt2_i),
        .qcom_vld_i (tb_qcom_vld_i), .qcom_flag_i (tb_qcom_flag_i),
        .qp1_en_o (tb_qp1_en_o), .qp1_op_o (tb_qp1_op_o),
        .qp1_a_dt_o (tb_qp1_a_dt_o), .qp1_b_dt_o (tb_qp1_b_dt_o), .qp1_c_dt_o (tb_qp1_c_dt_o), .qp1_d_dt_o (tb_qp1_d_dt_o),
        .qp1_rdy_i (tb_qp1_rdy_i), .qp1_dt1_i (tb_qp1_dt1_i), .qp1_dt2_i (tb_qp1_dt2_i),
        .qp1_vld_i (tb_qp1_vld_i), .qp1_flag_i (tb_qp1_flag_i),
        .qp2_en_o (tb_qp2_en_o), .qp2_op_o (tb_qp2_op_o),
        .qp2_a_dt_o (tb_qp2_a_dt_o), .qp2_b_dt_o (tb_qp2_b_dt_o), .qp2_c_dt_o (tb_qp2_c_dt_o), .qp2_d_dt_o (tb_qp2_d_dt_o),
        .qp2_rdy_i (tb_qp2_rdy_i), .qp2_dt1_i (tb_qp2_dt1_i), .qp2_dt2_i (tb_qp2_dt2_i),
        .qp2_vld_i (tb_qp2_vld_i),
        .s_dma_axis_tdata_i  (tb_s_dma_axis_tdata_i),
        .s_dma_axis_tlast_i  (tb_s_dma_axis_tlast_i),
        .s_dma_axis_tvalid_i (tb_s_dma_axis_tvalid_i),
        .s_dma_axis_tready_o (tb_s_dma_axis_tready_o),
        .m_dma_axis_tdata_o  (tb_m_dma_axis_tdata_o),
        .m_dma_axis_tlast_o  (tb_m_dma_axis_tlast_o),
        .m_dma_axis_tvalid_o (tb_m_dma_axis_tvalid_o),
        .m_dma_axis_tready_i (tb_m_dma_axis_tready_i),
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
        .s0_axis_tdata (tb_s0_axis_tdata), .s0_axis_tvalid (tb_s0_axis_tvalid), .s0_axis_tready (tb_s0_axis_tready),
        .s1_axis_tdata (tb_s1_axis_tdata), .s1_axis_tvalid (tb_s1_axis_tvalid), .s1_axis_tready (tb_s1_axis_tready),
        .s2_axis_tdata ('0), .s2_axis_tvalid (1'b0), .s2_axis_tready (),
        .s3_axis_tdata ('0), .s3_axis_tvalid (1'b0), .s3_axis_tready (),
        .s4_axis_tdata ('0), .s4_axis_tvalid (1'b0), .s4_axis_tready (),
        .s5_axis_tdata ('0), .s5_axis_tvalid (1'b0), .s5_axis_tready (),
        .s6_axis_tdata ('0), .s6_axis_tvalid (1'b0), .s6_axis_tready (),
        .s7_axis_tdata ('0), .s7_axis_tvalid (1'b0), .s7_axis_tready (),
        .s8_axis_tdata ('0), .s8_axis_tvalid (1'b0), .s8_axis_tready (),
        .s9_axis_tdata ('0), .s9_axis_tvalid (1'b0), .s9_axis_tready (),
        .s10_axis_tdata ('0), .s10_axis_tvalid (1'b0), .s10_axis_tready (),
        .s11_axis_tdata ('0), .s11_axis_tvalid (1'b0), .s11_axis_tready (),
        .s12_axis_tdata ('0), .s12_axis_tvalid (1'b0), .s12_axis_tready (),
        .s13_axis_tdata ('0), .s13_axis_tvalid (1'b0), .s13_axis_tready (),
        .s14_axis_tdata ('0), .s14_axis_tvalid (1'b0), .s14_axis_tready (),
        .s15_axis_tdata ('0), .s15_axis_tvalid (1'b0), .s15_axis_tready (),
        .m0_axis_tdata (tb_m0_axis_tdata), .m0_axis_tvalid (tb_m0_axis_tvalid), .m0_axis_tready (tb_m0_axis_tready),
        .m1_axis_tdata (tb_m1_axis_tdata), .m1_axis_tvalid (tb_m1_axis_tvalid), .m1_axis_tready (tb_m1_axis_tready),
        .m2_axis_tdata (), .m2_axis_tvalid (), .m2_axis_tready (1'b0),
        .m3_axis_tdata (), .m3_axis_tvalid (), .m3_axis_tready (1'b0),
        .m4_axis_tdata (), .m4_axis_tvalid (), .m4_axis_tready (1'b0),
        .m5_axis_tdata (), .m5_axis_tvalid (), .m5_axis_tready (1'b0),
        .m6_axis_tdata (), .m6_axis_tvalid (), .m6_axis_tready (1'b0),
        .m7_axis_tdata (), .m7_axis_tvalid (), .m7_axis_tready (1'b0),
        .m8_axis_tdata (), .m8_axis_tvalid (), .m8_axis_tready (1'b0),
        .m9_axis_tdata (), .m9_axis_tvalid (), .m9_axis_tready (1'b0),
        .m10_axis_tdata (), .m10_axis_tvalid (), .m10_axis_tready (1'b0),
        .m11_axis_tdata (), .m11_axis_tvalid (), .m11_axis_tready (1'b0),
        .m12_axis_tdata (), .m12_axis_tvalid (), .m12_axis_tready (1'b0),
        .m13_axis_tdata (), .m13_axis_tvalid (), .m13_axis_tready (1'b0),
        .m14_axis_tdata (), .m14_axis_tvalid (), .m14_axis_tready (1'b0),
        .m15_axis_tdata (), .m15_axis_tvalid (), .m15_axis_tready (1'b0),
        .trig_0_o (tb_trig_0_o), .trig_1_o (tb_trig_1_o), .trig_2_o (tb_trig_2_o),
        .trig_3_o (), .trig_4_o (), .trig_5_o (tb_trig_5_o), .trig_6_o (), .trig_7_o (),
        .trig_8_o (), .trig_9_o (), .trig_10_o (), .trig_11_o (), .trig_12_o (), .trig_13_o (),
        .trig_14_o (), .trig_15_o (), .trig_16_o (), .trig_17_o (), .trig_18_o (), .trig_19_o (),
        .trig_20_o (), .trig_21_o (), .trig_22_o (), .trig_23_o (), .trig_24_o (), .trig_25_o (),
        .trig_26_o (), .trig_27_o (), .trig_28_o (), .trig_29_o (), .trig_30_o (), .trig_31_o (tb_trig_31_o),
        .port_0_dt_o (tb_port_0_dt_o), .port_1_dt_o (tb_port_1_dt_o), .port_2_dt_o (), .port_3_dt_o (),
        .ps_debug_do (tb_ps_debug_do),
        .t_debug_do  (tb_t_debug_do),
        .t_fifo_do   (tb_t_fifo_do),
        .c_time_usr_do (tb_c_time_usr_do),
        .c_debug_do    (tb_c_debug_do),
        .c_time_ref_do (tb_c_time_ref_do),
        .c_proc_do     (tb_c_proc_do),
        .c_port_do     (tb_c_port_do),
        .c_core_do     (tb_c_core_do)
    );

    // PMEM row (256 bits, instruction in the low 72) of `WPORT_WR p0 wmem [&a] @t`,
    // as tprocv2_assembler.py emits it, and of a BRANCH-always to `target`.
    function automatic logic [255:0] mk_pw(input int a, input int tm);
        logic [15:0] op_code;
        logic [55:0] op_data;
        op_code = {3'b110, 1'b1, 2'b11, 3'b001, 1'b1, 1'b1, 5'b0};
        op_data = {11'(a), 6'd0, 32'(tm), 7'd0};
        mk_pw = {184'd0, op_code, op_data};
    endfunction
    function automatic logic [255:0] mk_jump(input logic [10:0] target);
        logic [15:0] op_code;
        logic [55:0] op_data;
        op_code = {3'b001, 1'b1, 2'b00, 3'b000, 1'b0, 1'b0, 5'b0};
        op_data = {target, 45'b0};
        mk_jump = {184'd0, op_code, op_data};
    endfunction

    // Cycles with a dispatcher FIFO full (the core pauses on it): proves the
    // FIFO-full test below really fills the FIFO.
    int unsigned fifo_full_cycles = 0;
    always @(posedge tb_c_clk) if (u_dut.qproc_i.some_fifo_full) fifo_full_cycles <= fifo_full_cycles + 1;

    // Wave words that leave m0_axis (one per accepted beat), for the FIFO-full
    // regression test below.
    logic [167:0] m0_words [$];
    logic [167:0] m1_words [$];
    longint       m0_time  [$];
    longint       m1_time  [$];
    always @(negedge tb_t_clk) begin
        if (tb_m0_axis_tvalid && tb_m0_axis_tready) begin
            m0_words.push_back(tb_m0_axis_tdata); m0_time.push_back(longint'(tb_t_time_abs_o));
        end
        if (tb_m1_axis_tvalid && tb_m1_axis_tready) begin
            m1_words.push_back(tb_m1_axis_tdata); m1_time.push_back(longint'(tb_t_time_abs_o));
        end
    end

    // trigger 0 edges with the absolute time (t_clk ticks)
    logic tb_trig_0_q = 1'b0;
    longint trig_rise [$];
    longint trig_fall [$];
    always @(negedge tb_t_clk) begin
        tb_trig_0_q <= tb_trig_0_o;
        if (tb_trig_0_o && !tb_trig_0_q) trig_rise.push_back(longint'(tb_t_time_abs_o));
        if (!tb_trig_0_o && tb_trig_0_q) trig_fall.push_back(longint'(tb_t_time_abs_o));
    end

    // instruction words
    //   WPORT_WR pP wmem [&a] @t            (immediate time)
    //   WPORT_WR pP r_wave @t
    //   REG_WR r_wave wmem [&a]
    //   TIME inc_ref #k
    //   WPORT_WR pP wmem [&a]               (time from the time register)
    //   TRIG set|clr p0 @t
    function automatic logic [255:0] mk_pwp(input int port, input int a, input int tm);
        mk_pwp = {184'd0, 16'hdce0, 11'(a), 6'(port), 32'(tm), 7'd0};
    endfunction
    function automatic logic [255:0] mk_pwr(input int port, input int tm);
        mk_pwr = {184'd0, 16'hcde0, 11'd0, 6'(port), 32'(tm), 7'd0};
    endfunction
    function automatic logic [255:0] mk_rw_load(input int a);
        mk_rw_load = {184'd0, 16'h9c40, 11'(a), 45'd0};
    endfunction
    function automatic logic [255:0] mk_time_inc(input int k);
        mk_time_inc = {184'd0, 16'h4c08, 17'd0, 32'(k), 7'd0};
    endfunction
    function automatic logic [255:0] mk_pst(input int port, input int a);
        mk_pst = {184'd0, 16'hdcc0, 11'(a), 6'(port), 39'd0};
    endfunction
    function automatic logic [255:0] mk_trig_t(input bit set, input int tm);
        mk_trig_t = {184'd0, 16'hdda0, 10'd0, set, 1'b1, 5'd0, 32'(tm), 7'd0};
    endfunction
    function automatic logic [255:0] mk_wrow(input int i);
        logic [255:0] r;
        r = '0;
        for (int k = 0; k < 6; k++) r[32*k +: 32] = {8'(i + 1), 8'(k + 1), 16'h5aa5};
        mk_wrow = r;
    endfunction

    // Writes `n` 256-bit rows into PMEM (mem_type 1) or WMEM (mem_type 3) from
    // address 0 through the DMA stream, as the driver's load_mem() does:
    // MEM_ADDR, MEM_LEN, TPROC_CFG = start | write | type, one beat per row,
    // then TPROC_CFG back to 0.
    task automatic dma_load(input int mem_type, input logic [255:0] rows[$]);
        s_axi.axi_write(ADDR_MEM_ADDR, 32'd0);
        s_axi.axi_write(ADDR_MEM_LEN, 32'(rows.size()));
        s_axi.axi_write(ADDR_TPROC_CFG, 32'(3 | (mem_type << 2)));
        foreach (rows[i]) begin
            @(negedge tb_clk);
            tb_s_dma_axis_tdata_i  = rows[i];
            tb_s_dma_axis_tlast_i  = (i == rows.size() - 1);
            tb_s_dma_axis_tvalid_i = 1'b1;
            do @(posedge tb_clk); while (!tb_s_dma_axis_tready_o);
        end
        @(negedge tb_clk);
        tb_s_dma_axis_tvalid_i = 1'b0;
        tb_s_dma_axis_tlast_i  = 1'b0;
        repeat (4) @(posedge tb_clk);
        s_axi.axi_write(ADDR_TPROC_CFG, 32'd0);
    endtask

    // ------------------------------------------------------------------
    // Run helpers: load the 8 WMEM rows and a program, start, wait for RUN
    // ------------------------------------------------------------------
    logic [167:0] golden [8];

    task automatic clear_captures();
        m0_words.delete(); m1_words.delete(); m0_time.delete(); m1_time.delete();
        trig_rise.delete(); trig_fall.delete();
        fifo_full_cycles = 0;
    endtask

    task automatic load_and_start(input logic [255:0] prog[$]);
        logic [255:0] rows[$];
        bit reached;
        for (int i = 0; i < 8; i++) rows.push_back(mk_wrow(i));
        dma_load(3, rows);
        dma_load(1, prog);
        clear_captures();
        s_axi.axi_write(ADDR_TPROC_CTRL, 32'h0000_0004);
        wait_for_core_st(C_RUN, reached);
        if (!reached) $display("PAUSE_TB core did not reach RUN");
    endtask

    // The 8 wave words, from 8 isolated pulses on port 0 (nothing near a full FIFO)
    task automatic make_golden();
        logic [255:0] prog[$];
        reset_dut();
        tb_m0_axis_tready = 1'b1;
        tb_m1_axis_tready = 1'b1;
        prog = '{256'd0};
        for (int a = 0; a < 8; a++) prog.push_back(mk_pwp(0, a, 2000 + 20 * a));
        prog.push_back(mk_jump(11'(prog.size())));
        load_and_start(prog);
        repeat (2500) @(posedge tb_c_clk);
        if (m0_words.size() == 8) for (int a = 0; a < 8; a++) golden[a] = m0_words[a];
        else $display("PAUSE_TB golden: %0d words instead of 8", m0_words.size());
    endtask

    function automatic logic [2:0] core_st();
        return tb_c_debug_do[2:0];
    endfunction

    // =========================================================================
    // Helper tasks
    // =========================================================================
    task automatic reset_dut();
        tb_ext_flag_i   = 1'b0;
        tb_proc_start_i = 1'b0;
        tb_proc_stop_i  = 1'b0;
        tb_core_start_i = 1'b0;
        tb_core_stop_i  = 1'b0;
        tb_rstn = 1'b0;
        repeat(10) @(posedge tb_clk);
        tb_rstn = 1'b1;
        // Let the XPM FIFOs inside qproc_dispatcher clear wr_rst_busy (see
        // qproc_dispatcher's own testbench notes).
        repeat(100) @(posedge tb_clk);
    endtask

    task automatic wait_for_core_st(input logic [2:0] target, output bit reached, input int max_cycles = 200);
        reached = 1'b0;
        for (int n = 0; n < max_cycles; n++) begin
            @(posedge tb_clk);
            if (core_st() == target) begin
                reached = 1'b1;
                return;
            end
        end
    endtask

    // =========================================================================
    // SVUnit build / setup / teardown
    // =========================================================================
    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        reset_dut();
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    // =========================================================================
    // Test cases
    // =========================================================================
    `SVUNIT_TESTS_BEGIN
    `include "qick_processor_pause_tests.sv"
    `SVUNIT_TESTS_END

endmodule
