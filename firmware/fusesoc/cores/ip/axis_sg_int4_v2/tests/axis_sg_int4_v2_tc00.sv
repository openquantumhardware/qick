// ============================================================================
// File: axis_sg_int4_v2_tc00.sv
// Description: SVUnit integration testbench for the axis_sg_int4_v2 IP.
//
//   Full IP flow: write an envelope via s0_axis, queue a waveform descriptor
//   via s1_axis (with AXI4-Lite start_addr/we control), observe m_axis.
//
//   Three clock domains: s_axi_aclk, s0_axis_aclk, aclk.
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module axis_sg_int4_v2_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "axis_sg_int4_v2_ut";
    svunit_testcase svunit_ut;

    localparam real AXI_FREQ  = 100e6;
    localparam real S0_FREQ   = 100e6;
    localparam real ACLK_FREQ = 200e6;
    localparam int  N     = 8;   // small memory for sim
    localparam int  N_DDS = 4;

    // Register byte addresses.
    localparam logic [5:0] REG_START_ADDR = 6'h00;
    localparam logic [5:0] REG_WE         = 6'h04;

    logic s_axi_aclk    = 1'b0;
    logic s_axi_aresetn = 1'b1;
    logic s0_axis_aclk  = 1'b0;
    logic s0_axis_arstn = 1'b1;
    logic aclk          = 1'b0;
    logic aresetn       = 1'b1;

    clk_gen #(.FREQ (AXI_FREQ))  u_axi (.i_enable(1'b1), .o_clk(s_axi_aclk));
    clk_gen #(.FREQ (S0_FREQ))   u_s0  (.i_enable(1'b1), .o_clk(s0_axis_aclk));
    clk_gen #(.FREQ (ACLK_FREQ)) u_a   (.i_enable(1'b1), .o_clk(aclk));

    axi4_lite_if #(
        .DATA_WIDTH (32),
        .ADDR_WIDTH (6)
    ) s_axi (
        .aclk    (s_axi_aclk),
        .aresetn (s_axi_aresetn)
    );

    axi4_stream_if #(.TDATA_WIDTH(32))       s0_if (.aclk(s0_axis_aclk), .aresetn(s0_axis_arstn));
    axi4_stream_if #(.TDATA_WIDTH(160))      s1_if (.aclk(aclk),         .aresetn(aresetn));
    axi4_stream_if #(.TDATA_WIDTH(N_DDS*32)) m_if  (.aclk(aclk),         .aresetn(aresetn));
    assign m_if.tready = 1'b1;
    assign m_if.tlast  = 1'b0;

    initial begin
        $dumpfile("axis_sg_int4_v2.vcd");
        $dumpvars();
    end

    axis_sg_int4_v2 #(
        .N     (N),
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

        .s0_axis_aclk    (s0_axis_aclk),
        .s0_axis_aresetn (s0_axis_arstn),
        .s0_axis_tdata   (s0_if.tdata),
        .s0_axis_tvalid  (s0_if.tvalid),
        .s0_axis_tready  (s0_if.tready),

        .aclk    (aclk),
        .aresetn (aresetn),

        .s1_axis_tdata  (s1_if.tdata),
        .s1_axis_tvalid (s1_if.tvalid),
        .s1_axis_tready (s1_if.tready),

        .m_axis_tready (m_if.tready),
        .m_axis_tvalid (m_if.tvalid),
        .m_axis_tdata  (m_if.tdata)
    );

    task automatic reg_write(input logic [5:0] addr, input logic [31:0] data);
        s_axi.axi_write(addr, data);
    endtask
    task automatic reg_read(input logic [5:0] addr, output logic [31:0] data);
        s_axi.axi_read(addr, data);
    endtask

    function automatic logic [159:0] build_descr(
        input logic [31:0] freq,  input logic [31:0] phase,
        input logic [15:0] addr,  input logic [15:0] gain,
        input logic [15:0] nsamp, input logic [1:0]  outsel,
        input logic mode, input logic stdysel, input logic phrst
    );
        logic [159:0] d = '0;
        d[31:0]   = freq;
        d[63:32]  = phase;
        d[79:64]  = addr;
        d[111:96] = gain;
        d[143:128]= nsamp;
        d[145:144]= outsel;
        d[146]    = mode;
        d[147]    = stdysel;
        d[148]    = phrst;
        return d;
    endfunction

    task automatic load_envelope(input int count, input logic [15:0] re [], input logic [15:0] im []);
        int k;
        reg_write(REG_START_ADDR, 32'd0);
        reg_write(REG_WE, 32'd1);
        repeat(10) @(posedge s0_axis_aclk);

        s0_if.m_cb.tvalid <= 1'b1;
        s0_if.m_cb.tdata  <= {im[0], re[0]};
        @(s0_if.m_cb);

        for (k = 0; k < count; ) begin
            @(s0_if.m_cb);
            if (s0_if.m_cb.tready) begin
                k++;
                if (k < count)
                    s0_if.m_cb.tdata <= {im[k], re[k]};
            end
        end

        s0_if.m_cb.tvalid <= 1'b0;
        s0_if.m_cb.tdata  <= '0;
        repeat(5) @(posedge s0_axis_aclk);
        reg_write(REG_WE, 32'd0);
        repeat(10) @(posedge s0_axis_aclk);
    endtask

    task automatic const_envelope(input int count, input logic [15:0] val,
                                   output logic [15:0] re [], output logic [15:0] im []);
        re = new[count]; im = new[count];
        for (int k = 0; k < count; k++) begin re[k] = val; im[k] = 16'h0000; end
    endtask

    task automatic queue_descriptor(input logic [159:0] d);
        @(posedge aclk);
        s1_if.tdata  <= d;
        s1_if.tvalid <= 1'b1;
        @(posedge aclk);
        while (!s1_if.tready) @(posedge aclk);
        s1_if.tvalid <= 1'b0;
        @(posedge aclk);
    endtask

    task automatic wait_for_mvalid(input logic value, input int max_cycles, output bit reached);
        int n;
        reached = 1'b0;
        for (n = 0; n < max_cycles; n++) begin
            if (m_if.tvalid === value) begin
                reached = 1'b1;
                break;
            end
            @(m_if.s_cb);
        end
    endtask

    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();

        s0_if.tvalid = 1'b0; s0_if.tlast = 1'b0; s0_if.tdata = '0;
        s0_if.tstrb  = '1;   s0_if.tkeep = '0;   s0_if.tuser = '0;
        s0_if.tid    = '0;   s0_if.tdest = '0;
        s1_if.tvalid = 1'b0; s1_if.tlast = 1'b0; s1_if.tdata = '0;
        s1_if.tstrb  = '1;   s1_if.tkeep = '0;   s1_if.tuser = '0;
        s1_if.tid    = '0;   s1_if.tdest = '0;

        s_axi_aresetn <= 1'b0;
        s0_axis_arstn <= 1'b0;
        aresetn       <= 1'b0;
        repeat(20) @(posedge aclk);
        s_axi_aresetn <= 1'b1;
        s0_axis_arstn <= 1'b1;
        aresetn       <= 1'b1;

        s0_if.m_reset();
        s1_if.m_reset();
        s_axi.reset();
        repeat(40) @(posedge aclk);
    endtask

    task teardown();
        svunit_ut.teardown();
        s0_if.m_cb.tvalid <= 1'b0;
        s1_if.m_cb.tvalid <= 1'b0;
        repeat(10) @(posedge aclk);
    endtask

    `SVUNIT_TESTS_BEGIN
    `include "axis_sg_int4_v2_tests.sv"
    `SVUNIT_TESTS_END

endmodule
