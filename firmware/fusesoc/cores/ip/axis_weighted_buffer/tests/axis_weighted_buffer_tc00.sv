// ============================================================================
// File: axis_weighted_buffer_tc00.sv
// Description: SVUnit integration testbench for the axis_weighted_buffer IP.
//
//   matched_filter, weighted_buffer (composition), avg_top and buffer_top
//   each already have dedicated testbenches. This testbench only
//   exercises what's NEW at the packaged-IP level: the AXI-Lite register
//   map (matching AxisWeightedBuffer.REGISTERS, with its combined
//   start_reg/dr_start_reg fields) driving the datapath through axil_slv.
//
//   Three clock domains: s_axi_aclk, s_axis_aclk, m_axis_aclk.
// ============================================================================

`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module axis_weighted_buffer_unit_test;

    import svunit_pkg::svunit_testcase;

    string name = "axis_weighted_buffer_ut";
    svunit_testcase svunit_ut;

    localparam real AXI_FREQ  = 100e6;
    localparam real AXIS_FREQ = 200e6;
    localparam int  N_AVG = 8;
    localparam int  N_BUF = 8;
    localparam int  N_WGT = 8;
    localparam int  B     = 16;

    // AXI4-Lite register byte addresses.
    localparam logic [5:0] ADDR_START           = 6'h00;
    localparam logic [5:0] ADDR_AVG_ADDR        = 6'h04;
    localparam logic [5:0] ADDR_AVG_LEN         = 6'h08;
    localparam logic [5:0] ADDR_DR_START        = 6'h0C;
    localparam logic [5:0] ADDR_AVG_DR_ADDR     = 6'h10;
    localparam logic [5:0] ADDR_AVG_DR_LEN      = 6'h14;
    localparam logic [5:0] ADDR_BUF_ADDR        = 6'h18;
    localparam logic [5:0] ADDR_BUF_LEN         = 6'h1C;
    localparam logic [5:0] ADDR_BUF_DR_ADDR     = 6'h20;
    localparam logic [5:0] ADDR_BUF_DR_LEN      = 6'h24;
    localparam logic [5:0] ADDR_AVG_PHOTON_MODE = 6'h28;
    localparam logic [5:0] ADDR_AVG_H_THRSH     = 6'h2C;
    localparam logic [5:0] ADDR_AVG_L_THRSH     = 6'h30;
    localparam logic [5:0] ADDR_WGT_DW_ADDR     = 6'h34;
    localparam logic [5:0] ADDR_WGT_TRUNC       = 6'h38;

    // -------------------------------------------------------------------------
    // Clocks & Resets. s_axis and m_axis share one generator for simplicity,
    // matching axis_avg_buffer_tc00's own approach -- genuine independent-
    // clock CDC is already exercised by avg_top/buffer_top's own testbenches.
    // -------------------------------------------------------------------------
    logic s_axi_aclk    = 1'b0;
    logic s_axi_aresetn = 1'b1;
    logic axis_clk      = 1'b0;
    logic axis_aresetn  = 1'b1;

    clk_gen #(.FREQ (AXI_FREQ))  u_axi_clk  (.i_enable(1'b1), .o_clk(s_axi_aclk));
    clk_gen #(.FREQ (AXIS_FREQ)) u_axis_clk (.i_enable(1'b1), .o_clk(axis_clk));

    // -------------------------------------------------------------------------
    // Interfaces
    // -------------------------------------------------------------------------
    axi4_lite_if #(
        .DATA_WIDTH (32),
        .ADDR_WIDTH (6)
    ) s_axi (
        .aclk    (s_axi_aclk),
        .aresetn (s_axi_aresetn)
    );

    axi4_stream_if #(.TDATA_WIDTH(2*B)) wgt_if (.aclk(s_axi_aclk), .aresetn(s_axi_aresetn));
    axi4_stream_if #(.TDATA_WIDTH(4*B)) m0_if  (.aclk(axis_clk), .aresetn(axis_aresetn));
    axi4_stream_if #(.TDATA_WIDTH(2*B)) m1_if  (.aclk(axis_clk), .aresetn(axis_aresetn));
    axi4_stream_if #(.TDATA_WIDTH(4*B)) m2_if  (.aclk(axis_clk), .aresetn(axis_aresetn));

    logic            tb_trigger       = 1'b0;
    logic            tb_s_axis_tvalid = 1'b0;
    logic [2*B-1:0]  tb_s_axis_tdata  = '0;
    logic            tb_s_axis_tready;

    initial begin
        $dumpfile("axis_weighted_buffer.vcd");
        $dumpvars();
    end

    // -------------------------------------------------------------------------
    // Unit Under Test
    // -------------------------------------------------------------------------
    axis_weighted_buffer #(
        .N_AVG (N_AVG),
        .N_BUF (N_BUF),
        .N_WGT (N_WGT),
        .B     (B)
    ) dut (
        .s_axi_aclk    (s_axi_aclk),
        .s_axi_aresetn (s_axi_aresetn),
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

        .trigger (tb_trigger),

        .s1_axis_tvalid (wgt_if.tvalid),
        .s1_axis_tready (wgt_if.tready),
        .s1_axis_tdata  (wgt_if.tdata),

        .s_axis_aclk    (axis_clk),
        .s_axis_aresetn (axis_aresetn),
        .s_axis_tvalid  (tb_s_axis_tvalid),
        .s_axis_tready  (tb_s_axis_tready),
        .s_axis_tdata   (tb_s_axis_tdata),

        .m_axis_aclk    (axis_clk),
        .m_axis_aresetn (axis_aresetn),

        .m0_axis_tvalid (m0_if.tvalid),
        .m0_axis_tready (m0_if.tready),
        .m0_axis_tdata  (m0_if.tdata),
        .m0_axis_tlast  (m0_if.tlast),

        .m1_axis_tvalid (m1_if.tvalid),
        .m1_axis_tready (m1_if.tready),
        .m1_axis_tdata  (m1_if.tdata),
        .m1_axis_tlast  (m1_if.tlast),

        .m2_axis_tvalid (m2_if.tvalid),
        .m2_axis_tready (m2_if.tready),
        .m2_axis_tdata  (m2_if.tdata)
    );

    // =========================================================================
    // Helper tasks
    // =========================================================================

    task automatic reg_write(input logic [5:0] addr, input logic [31:0] data);
        s_axi.axi_write(addr, data);
    endtask
    task automatic reg_read(input logic [5:0] addr, output logic [31:0] data);
        s_axi.axi_read(addr, data);
    endtask

    task automatic load_constant_weight(input logic [2*B-1:0] value, input int count = 16);
        int i;
        reg_write(ADDR_WGT_DW_ADDR, 32'd0);
        reg_write(ADDR_DR_START, 32'h4); // bit2 = WGT_DW_START
        repeat(2) @(posedge s_axi_aclk);
        for (i = 0; i < count; i++) begin
            wgt_if.tx(value);
        end
        reg_write(ADDR_DR_START, 32'h0);
        repeat(5) @(posedge s_axi_aclk);
    endtask

    task automatic arm_avg(input logic [31:0] addr, input logic [31:0] len);
        reg_write(ADDR_AVG_ADDR, addr);
        reg_write(ADDR_AVG_LEN, len);
        reg_write(ADDR_START, 32'h1); // bit0 = AVG_START
        repeat(4) @(posedge axis_clk);
    endtask

    task automatic arm_buf(input logic [31:0] addr, input logic [31:0] len);
        reg_write(ADDR_BUF_ADDR, addr);
        reg_write(ADDR_BUF_LEN, len);
        reg_write(ADDR_START, 32'h2); // bit1 = BUF_START
        repeat(4) @(posedge axis_clk);
    endtask

    task automatic pulse_trigger();
        tb_trigger = 1'b1;
        repeat(3) @(posedge axis_clk);
        tb_trigger = 1'b0;
        repeat(6) @(posedge axis_clk);
    endtask

    task automatic drive_const_samples(input int count, input logic [2*B-1:0] value);
        int i;
        tb_s_axis_tvalid = 1'b1;
        for (i = 0; i < count; i++) begin
            tb_s_axis_tdata = value;
            @(posedge axis_clk);
        end
        tb_s_axis_tvalid = 1'b0;
        tb_s_axis_tdata  = '0;
        repeat(6) @(posedge axis_clk);
    endtask

    // =========================================================================
    // SVUnit build / setup / teardown
    // =========================================================================
    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();

        tb_trigger       = 1'b0;
        tb_s_axis_tvalid = 1'b0;
        tb_s_axis_tdata  = '0;
        // wgt_if.tready is driven by the DUT's weight writer: park only the
        // master side, through the same clocking block tx() drives. Forcing
        // tready here made the writer lose the first weight.
        wgt_if.m_cb.tvalid <= 1'b0;
        wgt_if.m_cb.tdata  <= '0;
        wgt_if.m_cb.tlast  <= 1'b0;
        m0_if.tready  = 1'b1;
        m1_if.tready  = 1'b1;
        m2_if.tready  = 1'b1;

        s_axi_aresetn <= 1'b0;
        axis_aresetn  <= 1'b0;
        repeat(4) @(posedge axis_clk);
        s_axi_aresetn <= 1'b1;
        axis_aresetn  <= 1'b1;

        s_axi.reset();
        // XPM_FIFO settle window (bram_to_axis inside avg_top/buffer_top).
        repeat(100) @(posedge axis_clk);
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    `SVUNIT_TESTS_BEGIN
    `include "axis_weighted_buffer_tests.sv"
    `SVUNIT_TESTS_END

endmodule
