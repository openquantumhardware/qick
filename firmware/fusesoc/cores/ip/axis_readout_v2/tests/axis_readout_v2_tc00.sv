// ============================================================================
// File: axis_readout_v2_tc00.sv
// Description: SVUnit integration testbench for the axis_readout_v2 IP.
//
//   Full IP flow: configure FREQ/PHASE/NSAMP/OUTSEL/MODE via AXI4-Lite,
//   pulse WE_REG, drive a constant ADC sample on s_axis, observe m0_axis
//   (undecimated) and m1_axis (decimated).
//
//   Two clock domains: s_axi_aclk, aclk.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module axis_readout_v2_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "axis_readout_v2_ut";
    svunit_testcase svunit_ut;

    localparam real AXI_FREQ  = 100e6;
    localparam real ACLK_FREQ = 200e6;
    localparam int  N_DDS = 8;

    // Register byte addresses.
    localparam logic [5:0] ADDR_FREQ   = 6'h00;
    localparam logic [5:0] ADDR_PHASE  = 6'h04;
    localparam logic [5:0] ADDR_NSAMP  = 6'h08;
    localparam logic [5:0] ADDR_OUTSEL = 6'h0C;
    localparam logic [5:0] ADDR_MODE   = 6'h10;
    localparam logic [5:0] ADDR_WE     = 6'h14;

    logic s_axi_aclk    = 1'b0;
    logic s_axi_aresetn = 1'b1;
    logic aclk          = 1'b0;
    logic aresetn       = 1'b1;

    clk_gen #(.FREQ (AXI_FREQ))  u_axi (.i_enable(1'b1), .o_clk(s_axi_aclk));
    clk_gen #(.FREQ (ACLK_FREQ)) u_a   (.i_enable(1'b1), .o_clk(aclk));

    axi4_lite_if #(
        .DATA_WIDTH (32),
        .ADDR_WIDTH (6)
    ) s_axi (
        .aclk    (s_axi_aclk),
        .aresetn (s_axi_aresetn)
    );

    axi4_stream_if #(.TDATA_WIDTH(N_DDS*16)) s_if  (.aclk(aclk), .aresetn(aresetn));
    axi4_stream_if #(.TDATA_WIDTH(N_DDS*32)) m0_if (.aclk(aclk), .aresetn(aresetn));
    axi4_stream_if #(.TDATA_WIDTH(32))       m1_if (.aclk(aclk), .aresetn(aresetn));
    assign m0_if.tready = 1'b1;
    assign m0_if.tlast  = 1'b0;
    assign m1_if.tready = 1'b1;
    assign m1_if.tlast  = 1'b0;

    initial begin
        $dumpfile("axis_readout_v2.vcd");
        $dumpvars();
    end

    axis_readout_v2 #(
        .N_DDS (N_DDS)
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

        .aresetn (aresetn),
        .aclk    (aclk),

        .s_axis_tvalid (s_if.tvalid),
        .s_axis_tready (s_if.tready),
        .s_axis_tdata  (s_if.tdata),

        .m0_axis_tready (m0_if.tready),
        .m0_axis_tvalid (m0_if.tvalid),
        .m0_axis_tdata  (m0_if.tdata),

        .m1_axis_tready (m1_if.tready),
        .m1_axis_tvalid (m1_if.tvalid),
        .m1_axis_tdata  (m1_if.tdata)
    );

    task automatic reg_write(input logic [5:0] addr, input logic [31:0] data);
        s_axi.axi_write(addr, data);
    endtask
    task automatic reg_read(input logic [5:0] addr, output logic [31:0] data);
        s_axi.axi_read(addr, data);
    endtask

    function automatic logic [31:0] m0_lane(int lane);
        return m0_if.tdata[lane*32+:32];
    endfunction

    task automatic push_descriptor(
        input logic [31:0] freq, input logic [31:0] phase,
        input logic [15:0] nsamp, input logic [1:0] outsel,
        input logic mode
    );
        reg_write(ADDR_FREQ, freq);
        reg_write(ADDR_PHASE, phase);
        reg_write(ADDR_NSAMP, {16'h0000, nsamp});
        reg_write(ADDR_OUTSEL, {30'h0, outsel});
        reg_write(ADDR_MODE, {31'h0, mode});
        reg_write(ADDR_WE, 32'd1);
        repeat(10) @(posedge aclk);
        reg_write(ADDR_WE, 32'd0);
        repeat(30) @(posedge aclk);
    endtask

    task automatic drive_const_input(input logic [15:0] v);
        int i;
        for (i = 0; i < N_DDS; i++)
            s_if.tdata[i*16+:16] = v;
    endtask

    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();

        s_if.tvalid = 1'b1; s_if.tlast = 1'b0; s_if.tdata = '0;
        s_if.tstrb  = '1;   s_if.tkeep = '0;   s_if.tuser = '0;
        s_if.tid    = '0;   s_if.tdest = '0;

        s_axi_aresetn <= 1'b0;
        aresetn       <= 1'b0;
        repeat(20) @(posedge aclk);
        s_axi_aresetn <= 1'b1;
        aresetn       <= 1'b1;

        s_axi.reset();
        // History/pipe flush for fir_decim8_dynro (no reset of its own) +
        // XPM fifo settle.
        repeat(60) @(posedge aclk);
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    `SVUNIT_TESTS_BEGIN
    `include "axis_readout_v2_tests.sv"
    `SVUNIT_TESTS_END

endmodule
