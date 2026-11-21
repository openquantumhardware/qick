// ============================================================================
// File: axis_buffer_ddr_tc00.sv
// Description: SVUnit testbench for the axis_buffer_ddr IP.
//
//   The IP and the legacy RTL (tests/ref, the whole axis_buffer_ddr) get the
//   same inputs: the AXI4-Lite bus, the trigger, both streams and the AXI4
//   responses of a behavioural memory driven by the IP's master. Always-on
//   checkers compare, with !==:
//   - on every s_axi_aclk falling edge: the AXI4-Lite outputs (rdata when
//     rvalid) and the six registers each hands to its masters (mism_reg),
//   - on every aclk falling edge: every AXI4 master output (the AR payload while
//     arvalid is up), both streams' outputs and the two debug probes (mism).
//   The golden model is the legacy RTL with three changes (tests/ref/axi_mst_write_legacy.sv: the stream word offered
//   between two bursts is stored, 0 bursts ends, and clearing START disarms); the read master differs from the legacy one only for lengths above
//   256, across 4 kB, or 0.
//   Two tests (reads of more than 256 beats or across 4 kB, a write of 0 bursts) go beyond the legacy RTL and switch the
//   compare off; the other read tests stay inside what the legacy RTL did.
//   Because the outputs are equal on every clock, the responses of the memory
//   are legal for the legacy RTL as well.
//
//   DATA_WIDTH = 64 and BURST_SIZE = 7 (bursts of 8 beats); the deployed IPs
//   use 256 or 512 bits and 15.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module axis_buffer_ddr_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "axis_buffer_ddr_ut";
    svunit_testcase svunit_ut;

    localparam real AXI_FREQ  = 100e6;
    localparam real ACLK_FREQ = 300e6;
    localparam int  DW        = 64;
    localparam int  IDW       = 1;
    localparam int  BURST     = 7;
    localparam logic [31:0] BASE = 32'h4000_0000;
    localparam int  MEM_WORDS = 4096;
    localparam int  WSH       = $clog2(DW / 8);

    logic s_axi_aclk = 1'b0, s_axi_aresetn = 1'b1;
    logic aclk = 1'b0, aresetn = 1'b1;
    clk_gen #(.FREQ(AXI_FREQ))  u_axi (.i_enable(1'b1), .o_clk(s_axi_aclk));
    clk_gen #(.FREQ(ACLK_FREQ)) u_a   (.i_enable(1'b1), .o_clk(aclk));

    axi4_lite_if #(.DATA_WIDTH(32), .ADDR_WIDTH(8)) s_axi (.aclk(s_axi_aclk), .aresetn(s_axi_aresetn));

    // Shared inputs.
    logic                trigger = 1'b0;
    logic                m_axis_tready = 1'b1;
    logic [DW-1:0]       s_axis_tdata = '0;
    logic [DW/8-1:0]     s_axis_tstrb = '1;
    logic                s_axis_tlast = 1'b0, s_axis_tvalid = 1'b0;
    logic                awready = 1'b0, wready = 1'b0, arready = 1'b0;
    logic                bvalid = 1'b0, rvalid = 1'b0, rlast = 1'b0;
    logic [DW-1:0]       rdata = '0;
    logic [1:0]          bresp = 2'b00, rresp = 2'b00;
    logic [IDW-1:0]      bid = '0, rid = '0;

    // IP outputs (p_*) and legacy outputs (l_*) of the aclk domain.
    logic [IDW-1:0]  p_awid, l_awid, p_arid, l_arid;
    logic [31:0]     p_awaddr, l_awaddr, p_araddr, l_araddr;
    logic [7:0]      p_awlen, l_awlen, p_arlen, l_arlen;
    logic [2:0]      p_awsize, l_awsize, p_arsize, l_arsize, p_awprot, l_awprot, p_arprot, l_arprot;
    logic [1:0]      p_awburst, l_awburst, p_arburst, l_arburst;
    logic            p_awlock, l_awlock, p_arlock, l_arlock, p_awvalid, l_awvalid, p_arvalid, l_arvalid;
    logic [3:0]      p_awcache, l_awcache, p_arcache, l_arcache, p_awregion, l_awregion, p_arregion, l_arregion;
    logic [3:0]      p_awqos, l_awqos, p_arqos, l_arqos;
    logic [DW-1:0]   p_wdata, l_wdata, p_m_tdata, l_m_tdata;
    logic [DW/8-1:0] p_wstrb, l_wstrb, p_m_tstrb, l_m_tstrb;
    logic            p_wlast, l_wlast, p_wvalid, l_wvalid, p_bready, l_bready, p_rready, l_rready;
    logic            p_m_tvalid, l_m_tvalid, p_m_tlast, l_m_tlast, p_s_tready, l_s_tready;
    logic [31:0]     p_wdbg, l_wdbg, p_rdbg, l_rdbg;

    // AXI4-Lite outputs.
    logic [1:0]  l_bresp, l_rresp;
    logic        l_awready_l, l_wready_l, l_bvalid_l, l_arready_l, l_rvalid_l;
    logic [31:0] l_rdata_l;

    axis_buffer_ddr #(.TARGET_SLAVE_BASE_ADDR(BASE), .ID_WIDTH(IDW), .DATA_WIDTH(DW), .BURST_SIZE(BURST)) dut (
        .trigger(trigger),
        .s_axi_aclk(s_axi_aclk), .s_axi_aresetn(s_axi_aresetn),
        .s_axi_awaddr(s_axi.awaddr), .s_axi_awprot(s_axi.awprot), .s_axi_awvalid(s_axi.awvalid), .s_axi_awready(s_axi.awready),
        .s_axi_wdata(s_axi.wdata), .s_axi_wstrb(s_axi.wstrb), .s_axi_wvalid(s_axi.wvalid), .s_axi_wready(s_axi.wready),
        .s_axi_bresp(s_axi.bresp), .s_axi_bvalid(s_axi.bvalid), .s_axi_bready(s_axi.bready),
        .s_axi_araddr(s_axi.araddr), .s_axi_arprot(s_axi.arprot), .s_axi_arvalid(s_axi.arvalid), .s_axi_arready(s_axi.arready),
        .s_axi_rdata(s_axi.rdata), .s_axi_rresp(s_axi.rresp), .s_axi_rvalid(s_axi.rvalid), .s_axi_rready(s_axi.rready),
        .aclk(aclk), .aresetn(aresetn),
        .m_axi_awid(p_awid), .m_axi_awaddr(p_awaddr), .m_axi_awlen(p_awlen), .m_axi_awsize(p_awsize),
        .m_axi_awburst(p_awburst), .m_axi_awlock(p_awlock), .m_axi_awcache(p_awcache), .m_axi_awprot(p_awprot),
        .m_axi_awregion(p_awregion), .m_axi_awqos(p_awqos), .m_axi_awvalid(p_awvalid), .m_axi_awready(awready),
        .m_axi_wdata(p_wdata), .m_axi_wstrb(p_wstrb), .m_axi_wlast(p_wlast), .m_axi_wvalid(p_wvalid), .m_axi_wready(wready),
        .m_axi_bid(bid), .m_axi_bresp(bresp), .m_axi_bvalid(bvalid), .m_axi_bready(p_bready),
        .m_axi_arid(p_arid), .m_axi_araddr(p_araddr), .m_axi_arlen(p_arlen), .m_axi_arsize(p_arsize),
        .m_axi_arburst(p_arburst), .m_axi_arlock(p_arlock), .m_axi_arcache(p_arcache), .m_axi_arprot(p_arprot),
        .m_axi_arregion(p_arregion), .m_axi_arqos(p_arqos), .m_axi_arvalid(p_arvalid), .m_axi_arready(arready),
        .m_axi_rid(rid), .m_axi_rdata(rdata), .m_axi_rresp(rresp), .m_axi_rlast(rlast), .m_axi_rvalid(rvalid),
        .m_axi_rready(p_rready),
        .m_axis_tvalid(p_m_tvalid), .m_axis_tdata(p_m_tdata), .m_axis_tstrb(p_m_tstrb), .m_axis_tlast(p_m_tlast),
        .m_axis_tready(m_axis_tready),
        .s_axis_tready(p_s_tready), .s_axis_tdata(s_axis_tdata), .s_axis_tstrb(s_axis_tstrb), .s_axis_tlast(s_axis_tlast),
        .s_axis_tvalid(s_axis_tvalid),
        .mst_write_probe_dbg(p_wdbg), .mst_read_probe_dbg(p_rdbg));

    axis_buffer_ddr_legacy #(.TARGET_SLAVE_BASE_ADDR(BASE), .ID_WIDTH(IDW), .DATA_WIDTH(DW), .BURST_SIZE(BURST)) ref_i (
        .trigger(trigger),
        .s_axi_aclk(s_axi_aclk), .s_axi_aresetn(s_axi_aresetn),
        .s_axi_awaddr(s_axi.awaddr), .s_axi_awprot(s_axi.awprot), .s_axi_awvalid(s_axi.awvalid), .s_axi_awready(l_awready_l),
        .s_axi_wdata(s_axi.wdata), .s_axi_wstrb(s_axi.wstrb), .s_axi_wvalid(s_axi.wvalid), .s_axi_wready(l_wready_l),
        .s_axi_bresp(l_bresp), .s_axi_bvalid(l_bvalid_l), .s_axi_bready(s_axi.bready),
        .s_axi_araddr(s_axi.araddr), .s_axi_arprot(s_axi.arprot), .s_axi_arvalid(s_axi.arvalid), .s_axi_arready(l_arready_l),
        .s_axi_rdata(l_rdata_l), .s_axi_rresp(l_rresp), .s_axi_rvalid(l_rvalid_l), .s_axi_rready(s_axi.rready),
        .aclk(aclk), .aresetn(aresetn),
        .m_axi_awid(l_awid), .m_axi_awaddr(l_awaddr), .m_axi_awlen(l_awlen), .m_axi_awsize(l_awsize),
        .m_axi_awburst(l_awburst), .m_axi_awlock(l_awlock), .m_axi_awcache(l_awcache), .m_axi_awprot(l_awprot),
        .m_axi_awregion(l_awregion), .m_axi_awqos(l_awqos), .m_axi_awvalid(l_awvalid), .m_axi_awready(awready),
        .m_axi_wdata(l_wdata), .m_axi_wstrb(l_wstrb), .m_axi_wlast(l_wlast), .m_axi_wvalid(l_wvalid), .m_axi_wready(wready),
        .m_axi_bid(bid), .m_axi_bresp(bresp), .m_axi_bvalid(bvalid), .m_axi_bready(l_bready),
        .m_axi_arid(l_arid), .m_axi_araddr(l_araddr), .m_axi_arlen(l_arlen), .m_axi_arsize(l_arsize),
        .m_axi_arburst(l_arburst), .m_axi_arlock(l_arlock), .m_axi_arcache(l_arcache), .m_axi_arprot(l_arprot),
        .m_axi_arregion(l_arregion), .m_axi_arqos(l_arqos), .m_axi_arvalid(l_arvalid), .m_axi_arready(arready),
        .m_axi_rid(rid), .m_axi_rdata(rdata), .m_axi_rresp(rresp), .m_axi_rlast(rlast), .m_axi_rvalid(rvalid),
        .m_axi_rready(l_rready),
        .m_axis_tvalid(l_m_tvalid), .m_axis_tdata(l_m_tdata), .m_axis_tstrb(l_m_tstrb), .m_axis_tlast(l_m_tlast),
        .m_axis_tready(m_axis_tready),
        .s_axis_tready(l_s_tready), .s_axis_tdata(s_axis_tdata), .s_axis_tstrb(s_axis_tstrb), .s_axis_tlast(s_axis_tlast),
        .s_axis_tvalid(s_axis_tvalid),
        .mst_write_probe_dbg(l_wdbg), .mst_read_probe_dbg(l_rdbg));

    bit cmp_en = 1'b0;
    int mism = 0, mism_reg = 0, n_reads = 0, n_aw = 0, n_w = 0, n_ar = 0, n_m = 0;

    always @(negedge s_axi_aclk) if (cmp_en) begin
        if (s_axi.awready !== l_awready_l || s_axi.wready !== l_wready_l || s_axi.bvalid !== l_bvalid_l ||
            s_axi.arready !== l_arready_l || s_axi.rvalid !== l_rvalid_l) mism_reg++;
        if (l_bvalid_l && s_axi.bresp !== l_bresp) mism_reg++;
        if (l_rvalid_l && (s_axi.rdata !== l_rdata_l || s_axi.rresp !== l_rresp)) mism_reg++;
        if (l_rvalid_l) n_reads++;
        if (dut.regs[0][0] !== ref_i.RSTART_REG || dut.regs[1] !== ref_i.RADDR_REG || dut.regs[2] !== ref_i.RLENGTH_REG ||
            dut.regs[3][0] !== ref_i.WSTART_REG || dut.regs[4] !== ref_i.WADDR_REG || dut.regs[5] !== ref_i.WNBURST_REG)
            mism_reg++;
    end

    always @(negedge aclk) if (cmp_en) begin
        if (p_awid !== l_awid || p_awaddr !== l_awaddr || p_awlen !== l_awlen || p_awsize !== l_awsize ||
            p_awburst !== l_awburst || p_awlock !== l_awlock || p_awcache !== l_awcache || p_awprot !== l_awprot ||
            p_awregion !== l_awregion || p_awqos !== l_awqos || p_awvalid !== l_awvalid) mism++;
        if (p_wdata !== l_wdata || p_wstrb !== l_wstrb || p_wlast !== l_wlast || p_wvalid !== l_wvalid ||
            p_bready !== l_bready) mism++;
        // The AR payload is compared while arvalid is up: between bursts the IP's araddr and arlen are the next burst's
        // (the legacy RTL kept the first burst's).
        if (p_arvalid !== l_arvalid || p_rready !== l_rready) mism++;
        if (p_arvalid && (p_arid !== l_arid || p_araddr !== l_araddr || p_arlen !== l_arlen || p_arsize !== l_arsize ||
            p_arburst !== l_arburst || p_arlock !== l_arlock || p_arcache !== l_arcache || p_arprot !== l_arprot ||
            p_arregion !== l_arregion || p_arqos !== l_arqos)) mism++;
        if (p_m_tvalid !== l_m_tvalid || p_m_tdata !== l_m_tdata || p_m_tstrb !== l_m_tstrb || p_m_tlast !== l_m_tlast ||
            p_s_tready !== l_s_tready) mism++;
        if (p_wdbg !== l_wdbg || p_rdbg[23:0] !== l_rdbg[23:0]) mism++;   // [31:24] is the AR length (see above)
    end

    // Counters and the AXI 4 kB rule (from the bus-aligned start of the burst), always on (the compare above is off in the tests that go beyond the legacy RTL).
    int viol_4k = 0, n_arvalid = 0;
    bit cap_en = 1'b1;
    always @(posedge aclk) begin
        if (p_arvalid) n_arvalid++;
        if (p_awvalid && awready) begin
            n_aw++;
            if ((int'(p_awaddr[11:0]) / (DW / 8)) * (DW / 8) + (int'(p_awlen) + 1) * (DW / 8) > 4096) viol_4k++;
        end
        if (p_wvalid && wready) n_w++;
        if (p_arvalid && arready) begin
            n_ar++;
            if ((int'(p_araddr[11:0]) / (DW / 8)) * (DW / 8) + (int'(p_arlen) + 1) * (DW / 8) > 4096) viol_4k++;
        end
    end

    // ---------------------------------------------------------------- memory
    logic [DW-1:0] mem [MEM_WORDS];
    int   wr_idx = 0, rd_idx = 0, rd_left = 0;
    bit   wr_resp_pend = 1'b0;
    bit   bresp_err_next = 1'b0;                                      // answer the write bursts with SLVERR
    int   p_aw = 50, p_w = 70, p_ar = 50, p_r = 70, p_b = 50;      // handshake probabilities, %

    function automatic int word_of(input logic [31:0] addr);
        return int'((addr - BASE) >> WSH) % MEM_WORDS;
    endfunction

    always @(posedge aclk) begin
        awready <= ($urandom_range(99) < p_aw);
        wready  <= ($urandom_range(99) < p_w);
        arready <= ($urandom_range(99) < p_ar);
        // write address
        if (p_awvalid && awready) wr_idx = word_of(p_awaddr);
        // write data
        if (p_wvalid && wready) begin
            mem[wr_idx % MEM_WORDS] = p_wdata;
            wr_idx++;
            if (p_wlast) wr_resp_pend = 1'b1;
        end
        // write response
        if (bvalid && p_bready) bvalid <= 1'b0;
        else if (wr_resp_pend && !bvalid && ($urandom_range(99) < p_b)) begin
            bvalid <= 1'b1;
            bresp  <= bresp_err_next ? 2'b10 : 2'b00;
            wr_resp_pend = 1'b0;
        end
        // read address / data
        if (p_arvalid && arready) begin
            rd_idx  = word_of(p_araddr);
            rd_left = int'(p_arlen) + 1;
        end
        if (rvalid && p_rready) begin
            rd_idx++;
            rd_left--;
            rvalid <= 1'b0;
            rlast  <= 1'b0;
        end else if (!rvalid && rd_left > 0 && !(p_arvalid && arready) && ($urandom_range(99) < p_r)) begin
            rvalid <= 1'b1;
            rdata  <= mem[rd_idx % MEM_WORDS];
            rlast  <= (rd_left == 1);
        end
    end

    // Words seen on the output stream.
    logic [DW-1:0] o_data [$];
    always @(negedge aclk) if (cap_en && p_m_tvalid && m_axis_tready) o_data.push_back(p_m_tdata);

    // AXI4-Lite write with a chosen wstrb (see the axis_pfb_readout tests).
    task automatic axi_wr(input logic [7:0] addr, input logic [31:0] data, input logic [3:0] strb);
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

    task automatic axi_rd(input logic [7:0] addr, output logic [31:0] data);
        s_axi.axi_read(addr, data);
    endtask

    task automatic reg_wr(input int r, input logic [31:0] d);
        axi_wr(8'(4 * r), d, 4'hf);
    endtask

    // A word pattern that tells position and run apart.
    function automatic logic [DW-1:0] pat(input int run, input int n);
        return {32'(run), 32'(n)} ^ 64'h0123_4567_89AB_CDEF;
    endfunction

    // Stream `n` words, with random gaps; honours s_axis_tready.
    task automatic send(input int n, input int run, input int pvalid);
        int sent = 0;
        while (sent < n) begin
            @(posedge aclk);
            s_axis_tvalid <= ($urandom_range(99) < pvalid);
            s_axis_tdata  <= pat(run, sent);
            s_axis_tlast  <= (sent == n - 1);
            @(negedge aclk);
            if (s_axis_tvalid && p_s_tready) sent++;
        end
        @(posedge aclk);
        s_axis_tvalid <= 1'b0;
        s_axis_tlast  <= 1'b0;
    endtask

    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        s_axi.awvalid = 1'b0; s_axi.wvalid = 1'b0; s_axi.bready = 1'b0;
        s_axi.arvalid = 1'b0; s_axi.rready = 1'b0;
        s_axi.awaddr = '0; s_axi.araddr = '0; s_axi.wdata = '0; s_axi.wstrb = '0;
        s_axi.awprot = '0; s_axi.arprot = '0;
        trigger = 1'b0; m_axis_tready = 1'b1;
        s_axis_tvalid = 1'b0; s_axis_tlast = 1'b0;
        awready = 1'b0; wready = 1'b0; arready = 1'b0; bvalid = 1'b0; rvalid = 1'b0; rlast = 1'b0;
        wr_idx = 0; rd_idx = 0; rd_left = 0; wr_resp_pend = 1'b0; bresp_err_next = 1'b0; bresp = 2'b00;
        p_aw = 50; p_w = 70; p_ar = 50; p_r = 70; p_b = 50;
        for (int i = 0; i < MEM_WORDS; i++) mem[i] = '0;
        o_data.delete();
        s_axi_aresetn <= 1'b0; aresetn <= 1'b0;
        repeat (20) @(posedge s_axi_aclk);
        s_axi_aresetn <= 1'b1; aresetn <= 1'b1;
        repeat (4) @(posedge s_axi_aclk);
        mism = 0; mism_reg = 0; n_reads = 0; n_aw = 0; n_w = 0; n_ar = 0; n_m = 0; viol_4k = 0; n_arvalid = 0;
        cmp_en = 1'b1;
        cap_en = 1'b1;
    endtask

    task teardown();
        svunit_ut.teardown();
        cmp_en = 1'b0;
    endtask

    `SVUNIT_TESTS_BEGIN
    `include "axis_buffer_ddr_tests.sv"
    `SVUNIT_TESTS_END
endmodule
