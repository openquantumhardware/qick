// ============================================================================
// File: axis_pfb_readout_v3_tc00.sv
// Description: SVUnit testbench for the axis_pfb_readout_v3 IP.
//
//   - Registers: the legacy axi_slv (tests/ref/axi_slv_pfb_v3_legacy.vhd) sits
//     on the same AXI4-Lite bus as the IP; an always-on checker compares, on
//     every s_axi_aclk falling edge, every AXI output of the two (rdata when
//     rvalid) and the ID/PINC/POFF values each hands to its datapath (mism).
//   - Datapath: tones on the ADC stream, outputs configured over AXI.
//
//   The datapath below the registers (qick:dsp:pfb_readout) is checked
//   against the legacy RTL in its own testbench.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module axis_pfb_readout_v3_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "axis_pfb_readout_v3_ut";
    svunit_testcase svunit_ut;

    localparam real AXI_FREQ  = 100e6;
    localparam real ACLK_FREQ = 300e6;
    localparam real PI = 3.14159265358979323846;

    logic s_axi_aclk = 1'b0, s_axi_aresetn = 1'b1;
    logic aclk = 1'b0, aresetn = 1'b1;
    clk_gen #(.FREQ(AXI_FREQ))  u_axi (.i_enable(1'b1), .o_clk(s_axi_aclk));
    clk_gen #(.FREQ(ACLK_FREQ)) u_a   (.i_enable(1'b1), .o_clk(aclk));

    axi4_lite_if #(.DATA_WIDTH(32), .ADDR_WIDTH(6)) s_axi (.aclk(s_axi_aclk), .aresetn(s_axi_aresetn));

    logic         s_tvalid = 1'b0;
    logic [127:0] s_tdata  = '0;
    logic [3:0]   m_tvalid;
    logic [31:0]  m_tdata [4];

    axis_pfb_readout_v3 dut (
        .s_axi_aclk(s_axi_aclk), .s_axi_aresetn(s_axi_aresetn),
        .s_axi_awaddr(s_axi.awaddr), .s_axi_awprot(s_axi.awprot), .s_axi_awvalid(s_axi.awvalid), .s_axi_awready(s_axi.awready),
        .s_axi_wdata(s_axi.wdata), .s_axi_wstrb(s_axi.wstrb), .s_axi_wvalid(s_axi.wvalid), .s_axi_wready(s_axi.wready),
        .s_axi_bresp(s_axi.bresp), .s_axi_bvalid(s_axi.bvalid), .s_axi_bready(s_axi.bready),
        .s_axi_araddr(s_axi.araddr), .s_axi_arprot(s_axi.arprot), .s_axi_arvalid(s_axi.arvalid), .s_axi_arready(s_axi.arready),
        .s_axi_rdata(s_axi.rdata), .s_axi_rresp(s_axi.rresp), .s_axi_rvalid(s_axi.rvalid), .s_axi_rready(s_axi.rready),
        .aresetn(aresetn), .aclk(aclk),
        .s_axis_tvalid(s_tvalid), .s_axis_tdata(s_tdata),
        .m0_axis_tvalid(m_tvalid[0]), .m0_axis_tdata(m_tdata[0]),
        .m1_axis_tvalid(m_tvalid[1]), .m1_axis_tdata(m_tdata[1]),
        .m2_axis_tvalid(m_tvalid[2]), .m2_axis_tdata(m_tdata[2]),
        .m3_axis_tvalid(m_tvalid[3]), .m3_axis_tdata(m_tdata[3]));

    // Legacy register slave on the same bus.
    logic        l_awready, l_wready, l_bvalid, l_arready, l_rvalid;
    logic [1:0]  l_bresp, l_rresp;
    logic [31:0] l_rdata;
    logic [15:0] l_id [4];
    logic [31:0] l_pinc [4], l_poff [4];

    axi_slv_pfb_v3_legacy ref_slv (
        .aclk(s_axi_aclk), .aresetn(s_axi_aresetn),
        .awaddr(s_axi.awaddr), .awprot(s_axi.awprot), .awvalid(s_axi.awvalid), .awready(l_awready),
        .wdata(s_axi.wdata), .wstrb(s_axi.wstrb), .wvalid(s_axi.wvalid), .wready(l_wready),
        .bresp(l_bresp), .bvalid(l_bvalid), .bready(s_axi.bready),
        .araddr(s_axi.araddr), .arprot(s_axi.arprot), .arvalid(s_axi.arvalid), .arready(l_arready),
        .rdata(l_rdata), .rresp(l_rresp), .rvalid(l_rvalid), .rready(s_axi.rready),
        .ID0_REG(l_id[0]), .ID1_REG(l_id[1]), .ID2_REG(l_id[2]), .ID3_REG(l_id[3]),
        .PINC0_REG(l_pinc[0]), .POFF0_REG(l_poff[0]), .PINC1_REG(l_pinc[1]), .POFF1_REG(l_poff[1]),
        .PINC2_REG(l_pinc[2]), .POFF2_REG(l_poff[2]), .PINC3_REG(l_pinc[3]), .POFF3_REG(l_poff[3]));

    bit cmp_en = 1'b0;
    int mism = 0, n_reads = 0;

    always @(negedge s_axi_aclk) if (cmp_en) begin
        if (s_axi.awready !== l_awready || s_axi.wready !== l_wready || s_axi.bvalid !== l_bvalid ||
            s_axi.arready !== l_arready || s_axi.rvalid !== l_rvalid) mism++;
        if (l_bvalid && s_axi.bresp !== l_bresp) mism++;
        if (l_rvalid && (s_axi.rdata !== l_rdata || s_axi.rresp !== l_rresp)) mism++;
        if (l_rvalid) n_reads++;
        for (int i = 0; i < 4; i++)
            if (dut.id[i] !== l_id[i] || dut.pinc[i] !== l_pinc[i] || dut.poff[i] !== l_poff[i]) mism++;
    end

    // AXI write with a chosen wstrb (axi4_lite_if's axi_write always uses all
    // ones). Plain signals, not the interface's clocking block: driven with
    // non-blocking assignments after a rising edge, ready/valid sampled on
    // the falling edge. (Driven through m_cb, wstrb stayed 0 in one test
    // while awaddr and wdata followed; xsim.)
    task automatic axi_wr(input logic [5:0] addr, input logic [31:0] data, input logic [3:0] strb);
        bit aw_done = 1'b0, w_done = 1'b0;
        @(posedge s_axi_aclk);
        s_axi.awaddr  <= addr;
        s_axi.awprot  <= 3'b000;
        s_axi.awvalid <= 1'b1;
        s_axi.wdata   <= data;
        s_axi.wstrb   <= strb;
        s_axi.wvalid  <= 1'b1;
        s_axi.bready  <= 1'b1;
        while (!(aw_done && w_done)) begin
            @(negedge s_axi_aclk);
            if (s_axi.awready) aw_done = 1'b1;
            if (s_axi.wready)  w_done  = 1'b1;
            @(posedge s_axi_aclk);
            if (aw_done) s_axi.awvalid <= 1'b0;
            if (w_done)  s_axi.wvalid  <= 1'b0;
        end
        do @(negedge s_axi_aclk); while (!s_axi.bvalid);
        @(posedge s_axi_aclk);
        s_axi.bready <= 1'b0;
    endtask

    task automatic axi_rd(input logic [5:0] addr, output logic [31:0] data);
        s_axi.axi_read(addr, data);
    endtask

    // Continuous complex tone, 4 samples per aclk.
    real ph = 0.0;
    task automatic tone(input real f, input real amp, input int nclk);
        for (int t = 0; t < nclk; t++) begin
            @(posedge aclk);
            s_tvalid <= 1'b1;
            for (int i = 0; i < 4; i++) begin
                s_tdata[i*32      +: 16] <= 16'($rtoi(amp * $cos(ph)));
                s_tdata[i*32 + 16 +: 16] <= 16'($rtoi(amp * $sin(ph)));
                ph += 2.0 * PI * f;
            end
        end
    endtask

    int o_i [$], o_q [$];
    int o_idx = 0;
    always @(negedge aclk) if (m_tvalid[o_idx]) begin
        o_i.push_back($signed(m_tdata[o_idx][15:0]));
        o_q.push_back($signed(m_tdata[o_idx][31:16]));
    end

    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        s_axi.awvalid = 1'b0; s_axi.wvalid = 1'b0; s_axi.bready = 1'b0;
        s_axi.arvalid = 1'b0; s_axi.rready = 1'b0;
        s_axi.awaddr = '0; s_axi.araddr = '0; s_axi.wdata = '0; s_axi.wstrb = '0;
        s_axi.awprot = '0; s_axi.arprot = '0;
        // Reset for 100 AXI clocks (300 aclk). A short reset in the middle of
        // the stream can move where the channels sit in the PFB frame (legacy
        // behaviour, see the IP README); the long one here gives the mapping
        // of a fresh start, channel k = {k%8, k/8}.
        s_axi_aresetn <= 1'b0; aresetn <= 1'b0;
        repeat (100) @(posedge s_axi_aclk);
        s_axi_aresetn <= 1'b1; aresetn <= 1'b1;
        repeat (2) @(posedge s_axi_aclk);
        mism = 0; n_reads = 0;
        cmp_en = 1'b1;
    endtask

    task teardown();
        svunit_ut.teardown();
        cmp_en = 1'b0;
    endtask

    `SVUNIT_TESTS_BEGIN
    `include "axis_pfb_readout_v3_tests.sv"
    `SVUNIT_TESTS_END
endmodule
