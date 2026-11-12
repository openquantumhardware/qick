// ============================================================================
// File: tprocv2_tc00.sv
// Description: SVUnit testbench top-level for tprocv2.
//
// Single clock drives t_clk_i/c_clk_i/ps_clk_i (the CDC synchronizers still
// add their fixed latency). DEBUG=3 unlocks the raw debug buses
// (c_debug_do/t_debug_do) so the FSM states inside qproc_ctrl are
// observable without adding test-only ports.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module tprocv2_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "tprocv2_ut";
    svunit_testcase svunit_ut;

    // =========================================================================
    // Parameters
    // =========================================================================
    localparam real CLOCK_FREQUENCY = 200e6;
    localparam int  IN_PORT_QTY   = 1;
    localparam int  OUT_TRIG_QTY  = 1;
    localparam int  OUT_DPORT_QTY = 1;
    localparam int  OUT_DPORT_DW  = 4;
    localparam int  OUT_WPORT_QTY = 1;
    localparam int  AXI_AW = 6; // matches qproc_axi_reg's AXI_AW

    // core_st_ds encoding (mirrors qproc_ctrl.sv's core_st_t enum).
    localparam logic [2:0] C_RST_RUN_WAIT = 3'd3;
    localparam logic [2:0] C_RUN = 3'd5;

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

    clk_gen #(.FREQ (CLOCK_FREQUENCY)) u_clk_gen (
        .i_enable (1'b1),
        .o_clk    (tb_clk)
    );

    // =========================================================================
    // AXI-Lite master interface
    // =========================================================================
    axi4_lite_if #(
        .DATA_WIDTH (32),
        .ADDR_WIDTH (AXI_AW)
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
    logic [31:0] tb_time_updt_dt_i = '0;
    logic [47:0] tb_time_abs_o;

    logic [31:0] tb_periph_a_dt_o, tb_periph_b_dt_o, tb_periph_c_dt_o, tb_periph_d_dt_o;
    logic [4:0]  tb_periph_op_o;

    logic        tb_qnet_en_o;
    logic        tb_qnet_rdy_i = 1'b0;
    logic [31:0] tb_qnet_dt_i [2] = '{default: '0};
    logic        tb_qnet_vld_i = 1'b0;
    logic        tb_qnet_flag_i = 1'b0;

    logic        tb_qcom_en_o;
    logic        tb_qcom_rdy_i = 1'b0;
    logic [31:0] tb_qcom_dt_i [2] = '{default: '0};
    logic        tb_qcom_vld_i = 1'b0;
    logic        tb_qcom_flag_i = 1'b0;

    logic        tb_qp1_en_o;
    logic        tb_qp1_rdy_i = 1'b0;
    logic [31:0] tb_qp1_dt_i [2] = '{default: '0};
    logic        tb_qp1_vld_i = 1'b0;
    logic        tb_qp1_flag_i = 1'b0;

    logic        tb_qp2_en_o;
    logic        tb_qp2_rdy_i = 1'b0;
    logic [31:0] tb_qp2_dt_i [2] = '{default: '0};
    logic        tb_qp2_vld_i = 1'b0;

    logic [255:0] tb_s_dma_axis_tdata_i  = '0;
    logic         tb_s_dma_axis_tlast_i  = 1'b0;
    logic         tb_s_dma_axis_tvalid_i = 1'b0;
    logic         tb_s_dma_axis_tready_o;
    logic [255:0] tb_m_dma_axis_tdata_o;
    logic         tb_m_dma_axis_tlast_o;
    logic         tb_m_dma_axis_tvalid_o;
    logic         tb_m_dma_axis_tready_i = 1'b0;

    logic         tb_port_tvalid_i [IN_PORT_QTY] = '{default: 1'b0};
    logic [63:0]  tb_port_tdata_i  [IN_PORT_QTY] = '{default: '0};

    logic         tb_port_trig_o [OUT_TRIG_QTY];
    logic         tb_port_tvalid_o [OUT_DPORT_QTY];
    logic [OUT_DPORT_DW-1:0] tb_port_tdata_o [OUT_DPORT_QTY];

    logic [167:0] tb_m_axis_tdata  [OUT_WPORT_QTY];
    logic         tb_m_axis_tvalid [OUT_WPORT_QTY];
    logic         tb_m_axis_tready [OUT_WPORT_QTY] = '{default: 1'b0};

    logic [3:0]  tb_dport_di = '0;
    logic [31:0] tb_ps_debug_do, tb_t_debug_do, tb_t_fifo_do;
    logic [31:0] tb_c_time_usr_do, tb_c_debug_do, tb_c_time_ref_do;
    logic [31:0] tb_c_proc_do, tb_c_port_do, tb_c_core_do;

    initial begin
        $dumpfile("tprocv2.vcd");
        $dumpvars();
    end

    // =========================================================================
    // DUT
    // =========================================================================
    tprocv2 #(
        .DEBUG         (3),
        .DUAL_CORE     (0),
        .LFSR          (1),
        .DIVIDER       (1),
        .ARITH         (1),
        .TIME_READ     (1),
        .FIFO_DEPTH    (8),
        .PMEM_AW       (8),
        .DMEM_AW       (8),
        .WMEM_AW       (8),
        .REG_AW        (4),
        .IN_PORT_QTY   (IN_PORT_QTY),
        .OUT_TRIG_QTY  (OUT_TRIG_QTY),
        .OUT_DPORT_QTY (OUT_DPORT_QTY),
        .OUT_DPORT_DW  (OUT_DPORT_DW),
        .OUT_WPORT_QTY (OUT_WPORT_QTY)
    ) u_dut (
        .t_clk_i  (tb_clk),
        .t_rst_ni (tb_rstn),
        .c_clk_i  (tb_clk),
        .c_rst_ni (tb_rstn),
        .ps_clk_i (tb_clk),
        .ps_rst_ni (tb_rstn),
        .ext_flag_i     (tb_ext_flag_i),
        .proc_start_i   (tb_proc_start_i),
        .proc_stop_i    (tb_proc_stop_i),
        .core_start_i   (tb_core_start_i),
        .core_stop_i    (tb_core_stop_i),
        .time_rst_i     (tb_time_rst_i),
        .time_init_i    (tb_time_init_i),
        .time_updt_i    (tb_time_updt_i),
        .time_updt_dt_i (tb_time_updt_dt_i),
        .time_abs_o     (tb_time_abs_o),
        .periph_a_dt_o (tb_periph_a_dt_o),
        .periph_b_dt_o (tb_periph_b_dt_o),
        .periph_c_dt_o (tb_periph_c_dt_o),
        .periph_d_dt_o (tb_periph_d_dt_o),
        .periph_op_o   (tb_periph_op_o),
        .qnet_en_o (tb_qnet_en_o), .qnet_rdy_i (tb_qnet_rdy_i), .qnet_dt_i (tb_qnet_dt_i),
        .qnet_vld_i (tb_qnet_vld_i), .qnet_flag_i (tb_qnet_flag_i),
        .qcom_en_o (tb_qcom_en_o), .qcom_rdy_i (tb_qcom_rdy_i), .qcom_dt_i (tb_qcom_dt_i),
        .qcom_vld_i (tb_qcom_vld_i), .qcom_flag_i (tb_qcom_flag_i),
        .qp1_en_o (tb_qp1_en_o), .qp1_rdy_i (tb_qp1_rdy_i), .qp1_dt_i (tb_qp1_dt_i),
        .qp1_vld_i (tb_qp1_vld_i), .qp1_flag_i (tb_qp1_flag_i),
        .qp2_en_o (tb_qp2_en_o), .qp2_rdy_i (tb_qp2_rdy_i), .qp2_dt_i (tb_qp2_dt_i),
        .qp2_vld_i (tb_qp2_vld_i),
        .s_dma_axis_tdata_i  (tb_s_dma_axis_tdata_i),
        .s_dma_axis_tlast_i  (tb_s_dma_axis_tlast_i),
        .s_dma_axis_tvalid_i (tb_s_dma_axis_tvalid_i),
        .s_dma_axis_tready_o (tb_s_dma_axis_tready_o),
        .m_dma_axis_tdata_o  (tb_m_dma_axis_tdata_o),
        .m_dma_axis_tlast_o  (tb_m_dma_axis_tlast_o),
        .m_dma_axis_tvalid_o (tb_m_dma_axis_tvalid_o),
        .m_dma_axis_tready_i (tb_m_dma_axis_tready_i),
        .s_axi (s_axi.slave),
        .port_tvalid_i (tb_port_tvalid_i),
        .port_tdata_i  (tb_port_tdata_i),
        .port_trig_o   (tb_port_trig_o),
        .port_tvalid_o (tb_port_tvalid_o),
        .port_tdata_o  (tb_port_tdata_o),
        .m_axis_tdata  (tb_m_axis_tdata),
        .m_axis_tvalid (tb_m_axis_tvalid),
        .m_axis_tready (tb_m_axis_tready),
        .dport_di      (tb_dport_di),
        .ps_debug_do   (tb_ps_debug_do),
        .t_debug_do    (tb_t_debug_do),
        .t_fifo_do     (tb_t_fifo_do),
        .c_time_usr_do (tb_c_time_usr_do),
        .c_debug_do    (tb_c_debug_do),
        .c_time_ref_do (tb_c_time_ref_do),
        .c_proc_do     (tb_c_proc_do),
        .c_port_do     (tb_c_port_do),
        .c_core_do     (tb_c_core_do)
    );

    // core_st_ds is bits [2:0] of c_debug_do (see tprocv2.sv's
    // DEBUG_OUT block: c_debug_do[2:0] = core_st_ds).
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
        tb_time_rst_i   = 1'b0;
        tb_time_init_i  = 1'b0;
        tb_time_updt_i  = 1'b0;
        tb_time_updt_dt_i = '0;
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
    `include "tprocv2_tests.sv"
    `SVUNIT_TESTS_END

endmodule
