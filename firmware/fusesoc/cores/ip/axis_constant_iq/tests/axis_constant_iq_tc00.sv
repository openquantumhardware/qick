// ============================================================================
// File: axis_constant_iq_tc00.sv
// Description: SVUnit testbench top-level for axis_constant_iq.
// ============================================================================

`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module axis_constant_iq_unit_test;

    import svunit_pkg::svunit_testcase;

    string name = "axis_constant_iq_ut";
    svunit_testcase svunit_ut;

    // =========================================================================
    // Parameters
    // =========================================================================
    localparam real AXI_CLOCK_FREQ = 100e6;
    localparam real AXIS_CLOCK_FREQ = 200e6;
    localparam int  IQ_WIDTH  = 16;
    localparam int  BYTES     = IQ_WIDTH / 8;
    localparam int  NUM_CHANNELS     = 4;                 
    
    // Parameters for the AXI-Lite register bank 
    localparam int  AXI_DW   = 2*IQ_WIDTH;
    localparam int  AXI_AW   = 6;
    localparam int  NUM_REGS = 4;

    // AXI4-Lite register byte addresses
    localparam logic [AXI_AW-1:0] REAL_REG       = 6'h00;
    localparam logic [AXI_AW-1:0] IMAG_REG       = 6'h04;
    localparam logic [AXI_AW-1:0] WE_REG         = 6'h08;

    // =========================================================================
    // Clock & Reset
    // =========================================================================
    logic axi_clk   = 1'b0;
    logic axis_clk  = 1'b0;
    logic axi_rstn  = 1'b1;
    logic axis_rstn = 1'b1;

    // =========================================================================
    // Interfaces
    // =========================================================================
    axi4_lite_if #(
        .DATA_WIDTH(AXI_DW), 
        .ADDR_WIDTH(AXI_AW) // Enough to address real, imag, we, reserved
        ) s_axi(
            .aclk   (axi_clk ), 
            .aresetn(axi_rstn)
        );

    axi4_stream_if #(
        .TDATA_WIDTH (2* IQ_WIDTH * NUM_CHANNELS), // Total bytes for N parallel I/Q outputs
        .HAS_TSTRB     (1'b0),
        .HAS_TKEEP     (1'b0),
        .HAS_TID       (1'b0),
        .HAS_TDEST     (1'b0),
        .HAS_TUSER     (1'b0)
    ) axis_if (
        .aclk  (axis_clk),
        .aresetn (axis_rstn)
    );

    // =========================================================================
    // Clock generator
    // =========================================================================
    initial begin
        $dumpfile("axis_constant_iq.vcd");
        $dumpvars();
    end

    clk_gen #(.FREQ (AXI_CLOCK_FREQ)) axi_clk_gen (
        .i_enable (1'b1),
        .o_clk    (axi_clk)
    );

    clk_gen #(.FREQ (AXIS_CLOCK_FREQ)) axis_clk_gen (
        .i_enable (1'b1),
        .o_clk    (axis_clk)
    );

    // =========================================================================
    // Clocking block
    // =========================================================================
    default clocking axi_cb @(posedge axi_clk);
        default input #1step output #2;
        output axi_rstn;
    endclocking

    clocking axis_cb @(posedge axis_clk);
        default input #1step output #2;
        output axis_rstn;
    endclocking
    // =========================================================================
    // DUT
    // =========================================================================
    axis_constant_iq #(
        .IQ_WIDTH (IQ_WIDTH),
        .NUM_CHANNELS (NUM_CHANNELS)
    ) dut (
        .s_axi_aclk     (axi_clk),
        .s_axi_aresetn  (axi_rstn),
        .s_axi_awaddr   (s_axi.awaddr),
        .s_axi_awprot   (s_axi.awprot),
        .s_axi_awvalid  (s_axi.awvalid),
        .s_axi_awready  (s_axi.awready),
        .s_axi_wdata    (s_axi.wdata),
        .s_axi_wstrb    (s_axi.wstrb),
        .s_axi_wvalid   (s_axi.wvalid),
        .s_axi_wready   (s_axi.wready),
        .s_axi_bresp    (s_axi.bresp),
        .s_axi_bvalid   (s_axi.bvalid),
        .s_axi_bready   (s_axi.bready),
        .s_axi_araddr   (s_axi.araddr),
        .s_axi_arprot   (s_axi.arprot),
        .s_axi_arvalid  (s_axi.arvalid),
        .s_axi_arready  (s_axi.arready),
        .s_axi_rdata    (s_axi.rdata),
        .s_axi_rresp    (s_axi.rresp),
        .s_axi_rvalid   (s_axi.rvalid),
        .s_axi_rready   (s_axi.rready),
        .m_axis_aclk    (axis_clk),
        .m_axis_aresetn (axis_rstn),
        .m_axis_tdata   (axis_if.tdata),
        .m_axis_tvalid  (axis_if.tvalid),
        .m_axis_tlast   (axis_if.tlast),
        .m_axis_tready  (axis_if.tready)
    );

    // =========================================================================
    // Helper Tasks
    // =========================================================================

    task automatic reset_dut();
        axi_cb.axi_rstn <= 1'b0;
        axis_cb.axis_rstn <= 1'b0;
        repeat(20) @(axi_cb); 
        axi_cb.axi_rstn <= 1'b1;
        axis_cb.axis_rstn <= 1'b1;
        repeat(50) @(axi_cb);
    endtask

    // =========================================================================
    // SVUnit build / setup / teardown
    // =========================================================================
    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        
        axis_if.s_cb.tready <= 1'b0;
        axi_rstn  = 1'b0;
        axis_rstn = 1'b0;
        repeat(5) @(posedge axi_clk);
        axi_rstn  = 1'b1;
        axis_rstn = 1'b1;

        s_axi.reset();

        @(axi_cb);
        reset_dut(); 
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    // =========================================================================
    // Test cases
    // =========================================================================
    `SVUNIT_TESTS_BEGIN
    `include "axis_constant_iq_tests.sv"
    `SVUNIT_TESTS_END

endmodule
