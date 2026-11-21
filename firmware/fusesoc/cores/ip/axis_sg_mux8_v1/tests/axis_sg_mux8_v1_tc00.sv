// ============================================================================
// File: axis_sg_mux8_v1_tc00.sv
// Description: SVUnit integration testbench for the axis_sg_mux8_v1 IP.
//
//   Full IP flow: configure per-channel PINC/POFF/GAIN via AXI4-Lite, pulse
//   WE_REG, queue a waveform descriptor over s_axis, and observe m_axis.
//
//   Two clock domains: s_axi_aclk, aclk.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module axis_sg_mux8_v1_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "axis_sg_mux8_v1_ut";
    svunit_testcase svunit_ut;

    localparam real AXI_FREQ  = 100e6;
    localparam real ACLK_FREQ = 200e6;
    localparam int  N_DDS     = 2;

    // Register byte addresses.
    localparam logic [7:0] ADDR_PINC0 = 8'h00;
    localparam logic [7:0] ADDR_POFF0 = 8'h20;
    localparam logic [7:0] ADDR_GAIN0 = 8'h40;
    localparam logic [7:0] ADDR_WE    = 8'h60;

    logic s_axi_aclk    = 1'b0;
    logic s_axi_aresetn = 1'b1;
    logic aclk          = 1'b0;
    logic aresetn       = 1'b1;

    clk_gen #(.FREQ (AXI_FREQ))  u_axi (.i_enable(1'b1), .o_clk(s_axi_aclk));
    clk_gen #(.FREQ (ACLK_FREQ)) u_a   (.i_enable(1'b1), .o_clk(aclk));

    axi4_lite_if #(
        .DATA_WIDTH (32),
        .ADDR_WIDTH (8)
    ) s_axi (
        .aclk    (s_axi_aclk),
        .aresetn (s_axi_aresetn)
    );

    axi4_stream_if #(.TDATA_WIDTH(40))          s_if (.aclk(aclk), .aresetn(aresetn));
    axi4_stream_if #(.TDATA_WIDTH(N_DDS*16))    m_if (.aclk(aclk), .aresetn(aresetn));
    assign m_if.tready = 1'b1;
    assign m_if.tlast  = 1'b0;

    initial begin
        $dumpfile("axis_sg_mux8_v1.vcd");
        $dumpvars();
    end

    axis_sg_mux8_v1 #(
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

        .aclk    (aclk),
        .aresetn (aresetn),

        .s_axis_tdata  (s_if.tdata),
        .s_axis_tvalid (s_if.tvalid),
        .s_axis_tready (s_if.tready),

        .m_axis_tready (m_if.tready),
        .m_axis_tvalid (m_if.tvalid),
        .m_axis_tdata  (m_if.tdata)
    );

    task automatic reg_write(input logic [7:0] addr, input logic [31:0] data);
        s_axi.axi_write(addr, data);
    endtask
    task automatic reg_read(input logic [7:0] addr, output logic [31:0] data);
        s_axi.axi_read(addr, data);
    endtask

    // Configures channel 0's PINC/POFF/GAIN and pulses WE_REG.
    task automatic write_channel0(input logic [31:0] pinc, input logic [31:0] poff, input logic [15:0] gain);
        reg_write(ADDR_PINC0, pinc);
        reg_write(ADDR_POFF0, poff);
        reg_write(ADDR_GAIN0, {16'h0000, gain});
        reg_write(ADDR_WE, 32'd1);
        // CDC margin: we_reg crosses to aclk via cdc_bit_sync (2 stages).
        repeat(10) @(posedge aclk);
        reg_write(ADDR_WE, 32'd0);
        repeat(10) @(posedge aclk);
    endtask

    // Pushes one waveform descriptor {mask, nsamp} on s_axis.
    task automatic queue_descriptor(input logic [7:0] mask, input logic [31:0] nsamp);
        @(posedge aclk);
        s_if.tdata  <= {mask, nsamp};
        s_if.tvalid <= 1'b1;
        @(posedge aclk);
        while (!s_if.tready) @(posedge aclk);
        s_if.tvalid <= 1'b0;
        @(posedge aclk);
    endtask

    // Bounded-poll helper: waits up to max_cycles for m_axis_tvalid to reach
    // `value`.
    task automatic wait_for_mvalid(input logic value, input int max_cycles, output bit reached);
        int n;
        reached = 1'b0;
        for (n = 0; n < max_cycles; n++) begin
            if (m_if.tvalid === value) begin
                reached = 1'b1;
                break;
            end
            @(posedge aclk);
        end
    endtask

    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();

        s_if.tvalid = 1'b0; s_if.tlast = 1'b0; s_if.tdata = '0;
        s_if.tstrb  = '1;   s_if.tkeep = '0;   s_if.tuser = '0;
        s_if.tid    = '0;   s_if.tdest = '0;

        s_axi_aresetn <= 1'b0;
        aresetn       <= 1'b0;
        repeat(20) @(posedge aclk);
        s_axi_aresetn <= 1'b1;
        aresetn       <= 1'b1;

        s_if.m_reset();
        s_axi.reset();
        // mult_32x32/dds pipelines have no reset of their own -- flush
        // their reset-time X's (same margin as sg_mux8's own testbench).
        repeat(20) @(posedge aclk);
    endtask

    task teardown();
        svunit_ut.teardown();
        s_if.m_cb.tvalid <= 1'b0;
        repeat(10) @(posedge aclk);
    endtask

    `SVUNIT_TESTS_BEGIN
    `include "axis_sg_mux8_v1_tests.sv"
    `SVUNIT_TESTS_END

endmodule
