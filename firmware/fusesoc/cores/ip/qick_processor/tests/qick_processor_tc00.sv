// ============================================================================
// File: qick_processor_tc00.sv
// Description: SVUnit testbench top-level for qick_processor.
//
// Drives the flat AXI-Lite pins through a locally-instantiated axi4_lite_if
// (its axi_write/axi_read tasks), mirroring the interface<->pins wiring
// qick_processor.sv itself does internally. DEBUG=3 unlocks the raw
// debug buses (c_debug_do) so qproc_ctrl's FSM state is observable.
// Default parameters (IN_PORT_QTY=1, OUT_TRIG_QTY=2, OUT_DPORT_QTY=1,
// OUT_WPORT_QTY=1) exercise the "most pins are unused/tied-off" path.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module qick_processor_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "qick_processor_ut";
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
    localparam int ADDR_STATUS     = 'h38;   // TPROC_STATUS (index 14 of Axis_QICK_Proc.REGISTERS)

    // =========================================================================
    // Clock & reset
    // =========================================================================
    logic tb_clk  = 1'b0;
    logic tb_rstn = 1'b1;

    clk_gen #(.FREQ (CLOCK_FREQUENCY)) u_clk_gen (
        .i_enable (1'b1),
        .o_clk    (tb_clk)
    );

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
    logic        tb_qp2_vld_i = 1'b0, tb_qp2_flag_i = 1'b0;

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

    // =========================================================================
    // Inputs of qp1 / qp2: the testbench's own registers (tb_qpN_*), or, with tb_use_loopback, two qick_periph_loopback
    // peripherals answering the commands of the core.
    // =========================================================================
    logic        tb_use_loopback = 1'b0;
    logic        lb1_rdy, lb1_vld, lb1_flag, lb2_rdy, lb2_vld, lb2_flag;
    logic [31:0] lb1_dt1, lb1_dt2, lb1_cmd, lb1_drop, lb2_dt1, lb2_dt2, lb2_cmd, lb2_drop;

    wire        dut_qp1_rdy_i  = tb_use_loopback ? lb1_rdy  : tb_qp1_rdy_i;
    wire [31:0] dut_qp1_dt1_i  = tb_use_loopback ? lb1_dt1  : tb_qp1_dt1_i;
    wire [31:0] dut_qp1_dt2_i  = tb_use_loopback ? lb1_dt2  : tb_qp1_dt2_i;
    wire        dut_qp1_vld_i  = tb_use_loopback ? lb1_vld  : tb_qp1_vld_i;
    wire        dut_qp1_flag_i = tb_use_loopback ? lb1_flag : tb_qp1_flag_i;
    wire        dut_qp2_rdy_i  = tb_use_loopback ? lb2_rdy  : tb_qp2_rdy_i;
    wire [31:0] dut_qp2_dt1_i  = tb_use_loopback ? lb2_dt1  : tb_qp2_dt1_i;
    wire [31:0] dut_qp2_dt2_i  = tb_use_loopback ? lb2_dt2  : tb_qp2_dt2_i;
    wire        dut_qp2_vld_i  = tb_use_loopback ? lb2_vld  : tb_qp2_vld_i;
    wire        dut_qp2_flag_i = tb_use_loopback ? lb2_flag : tb_qp2_flag_i;

    qick_periph_loopback #(.DELAY(3)) u_lb1 (
        .clk_i (tb_clk), .rst_ni (tb_rstn), .en_i (tb_qp1_en_o), .op_i (tb_qp1_op_o),
        .a_i (tb_qp1_a_dt_o), .b_i (tb_qp1_b_dt_o), .c_i (tb_qp1_c_dt_o), .d_i (tb_qp1_d_dt_o),
        .rdy_o (lb1_rdy), .dt1_o (lb1_dt1), .dt2_o (lb1_dt2), .vld_o (lb1_vld), .flag_o (lb1_flag),
        .cmd_cnt_o (lb1_cmd), .drop_cnt_o (lb1_drop));
    qick_periph_loopback #(.DELAY(5)) u_lb2 (
        .clk_i (tb_clk), .rst_ni (tb_rstn), .en_i (tb_qp2_en_o), .op_i (tb_qp2_op_o),
        .a_i (tb_qp2_a_dt_o), .b_i (tb_qp2_b_dt_o), .c_i (tb_qp2_c_dt_o), .d_i (tb_qp2_d_dt_o),
        .rdy_o (lb2_rdy), .dt1_o (lb2_dt1), .dt2_o (lb2_dt2), .vld_o (lb2_vld), .flag_o (lb2_flag),
        .cmd_cnt_o (lb2_cmd), .drop_cnt_o (lb2_drop));

    initial begin
        $dumpfile("qick_processor.vcd");
        $dumpvars();
    end

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
        .OUT_WPORT_QTY (1)
    ) u_dut (
        .t_clk_i   (tb_clk),
        .t_resetn  (tb_rstn),
        .c_clk_i   (tb_clk),
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
        .qp1_rdy_i (dut_qp1_rdy_i), .qp1_dt1_i (dut_qp1_dt1_i), .qp1_dt2_i (dut_qp1_dt2_i),
        .qp1_vld_i (dut_qp1_vld_i), .qp1_flag_i (dut_qp1_flag_i),
        .qp2_en_o (tb_qp2_en_o), .qp2_op_o (tb_qp2_op_o),
        .qp2_a_dt_o (tb_qp2_a_dt_o), .qp2_b_dt_o (tb_qp2_b_dt_o), .qp2_c_dt_o (tb_qp2_c_dt_o), .qp2_d_dt_o (tb_qp2_d_dt_o),
        .qp2_rdy_i (dut_qp2_rdy_i), .qp2_dt1_i (dut_qp2_dt1_i), .qp2_dt2_i (dut_qp2_dt2_i),
        .qp2_vld_i (dut_qp2_vld_i),
        .qp2_flag_i (dut_qp2_flag_i),
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
    always @(posedge tb_clk) if (u_dut.qproc_i.some_fifo_full) fifo_full_cycles <= fifo_full_cycles + 1;

    // Wave words that leave m0_axis (one per accepted beat), for the FIFO-full
    // regression test below.
    logic [167:0] m0_words [$];
    always @(negedge tb_clk) begin
        if (tb_m0_axis_tvalid && tb_m0_axis_tready) m0_words.push_back(tb_m0_axis_tdata);
    end

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
        tb_use_loopback = 1'b0;
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
    // Program loading and a probe of the peripheral ports
    // =========================================================================
    // What the core drove on qp1 / qp2 when `en` was high (the last command and how many there were).
    int          qp1_n, qp2_n;
    logic [4:0]  qp1_op_q, qp2_op_q;
    logic [31:0] qp1_a_q, qp1_b_q, qp1_c_q, qp1_d_q, qp2_a_q, qp2_b_q, qp2_c_q, qp2_d_q;
    initial begin qp1_n = 0; qp2_n = 0; end
    always @(posedge tb_clk) begin
        if (tb_qp1_en_o) begin
            qp1_n    <= qp1_n + 1;
            qp1_op_q <= tb_qp1_op_o;
            qp1_a_q  <= tb_qp1_a_dt_o; qp1_b_q <= tb_qp1_b_dt_o; qp1_c_q <= tb_qp1_c_dt_o; qp1_d_q <= tb_qp1_d_dt_o;
        end
        if (tb_qp2_en_o) begin
            qp2_n    <= qp2_n + 1;
            qp2_op_q <= tb_qp2_op_o;
            qp2_a_q  <= tb_qp2_a_dt_o; qp2_b_q <= tb_qp2_b_dt_o; qp2_c_q <= tb_qp2_c_dt_o; qp2_d_q <= tb_qp2_d_dt_o;
        end
    end

    // Loads the 256-bit rows of a program file (tests/data/gen_prog.py: the repo's assembler) into PMEM with dma_load(), the same
    // helper the FIFO-full tests use: MEM_ADDR, MEM_LEN, TPROC_CFG = start | write | pmem, one beat per row.
    // A row that reads back as x ends the file.
    task automatic load_program(input string fname, output int nrows);
        logic [255:0] mem [0:255];
        logic [255:0] rows [$];
        for (int i = 0; i < 256; i++) mem[i] = 'x;
        $readmemh(fname, mem);
        nrows = 0;
        while (nrows < 256 && ^mem[nrows] !== 1'bx) begin
            rows.push_back(mem[nrows]);
            nrows++;
        end
        dma_load(1, rows);
    endtask

    // Loads the program and starts the core (TPROC_CTRL START, like the driver's start()).
    task automatic run_program(input string fname, input int cycles);
        int n;
        load_program(fname, n);
        s_axi.axi_write(ADDR_TPROC_CTRL, 32'h0000_0004);
        repeat (cycles) @(posedge tb_clk);
    endtask

    task automatic one_clock_pulse_vld(input bit p1, input bit p2);
        @(negedge tb_clk);
        tb_qp1_vld_i = p1;
        tb_qp2_vld_i = p2;
        @(negedge tb_clk);
        tb_qp1_vld_i = 1'b0;
        tb_qp2_vld_i = 1'b0;
    endtask

    // One word of data memory through the single-word AXI access.
    task automatic dmem_read(input int a, output logic [31:0] v);
        localparam int ADDR_MEM_DT_O = 'h28;
        logic [31:0] cfg;
        s_axi.axi_read(ADDR_TPROC_CFG, cfg);
        s_axi.axi_write(ADDR_MEM_ADDR, a);
        s_axi.axi_write(ADDR_TPROC_CFG, (cfg & ~32'h3f) | (32'h11 | (32'd2 << 2)));
        repeat (6) @(posedge tb_clk);
        s_axi.axi_read(ADDR_MEM_DT_O, v);
        s_axi.axi_write(ADDR_TPROC_CFG, cfg & ~32'h3f);
    endtask

    // One word of data memory written through the single-word AXI access (data register first, then the start).
    task automatic dmem_write(input int a, input logic [31:0] v);
        localparam int ADDR_MEM_DT_I = 'h10;
        logic [31:0] cfg;
        s_axi.axi_read(ADDR_TPROC_CFG, cfg);
        s_axi.axi_write(ADDR_MEM_ADDR, a);
        s_axi.axi_write(ADDR_MEM_DT_I, v);
        s_axi.axi_write(ADDR_TPROC_CFG, (cfg & ~32'h3f) | (32'h13 | (32'd2 << 2)));
        repeat (4) @(posedge tb_clk);
        s_axi.axi_write(ADDR_TPROC_CFG, cfg & ~32'h3f);
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
    `include "qick_processor_tests.sv"
    `include "qick_processor_prog_tests.sv"
    `SVUNIT_TESTS_END

endmodule
