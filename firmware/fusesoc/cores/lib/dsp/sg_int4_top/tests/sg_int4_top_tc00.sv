// ============================================================================
// File: sg_int4_top_tc00.sv
// Description: SVUnit integration testbench for sg_int4_top.
//
//   Full datapath flow: write an envelope via s0_axis, queue a waveform
//   descriptor via s1_axis, observe m_axis.
//
//   Two clock domains: s0_axis_aclk (envelope write), aclk (everything else).
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module sg_int4_top_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "sg_int4_top_ut";
    svunit_testcase svunit_ut;

    localparam real S0_FREQ   = 100e6;
    localparam real ACLK_FREQ = 200e6;
    localparam int  N     = 8;   // small memory for sim
    localparam int  N_DDS = 4;

    logic s0_axis_aclk    = 1'b0;
    logic s0_axis_aresetn = 1'b1;
    logic aclk             = 1'b0;
    logic aresetn          = 1'b1;

    clk_gen #(.FREQ (S0_FREQ))   u_s0 (.i_enable(1'b1), .o_clk(s0_axis_aclk));
    clk_gen #(.FREQ (ACLK_FREQ)) u_a  (.i_enable(1'b1), .o_clk(aclk));

    axi4_stream_if #(.TDATA_WIDTH(32))  s0_if (.aclk(s0_axis_aclk), .aresetn(s0_axis_aresetn));
    axi4_stream_if #(.TDATA_WIDTH(160)) s1_if (.aclk(aclk),         .aresetn(aresetn));
    axi4_stream_if #(.TDATA_WIDTH(N_DDS*32)) m_if (.aclk(aclk),     .aresetn(aresetn));
    assign m_if.tready = 1'b1;
    assign m_if.tlast  = 1'b0;

    logic [31:0] tb_start_addr_reg;
    logic        tb_we_reg;

    initial begin
        $dumpfile("sg_int4_top.vcd");
        $dumpvars();
    end

    sg_int4_top #(
        .N     (N),
        .N_DDS (N_DDS)
    ) dut (
        .aresetn (aresetn),
        .aclk    (aclk),

        .s0_axis_aresetn (s0_axis_aresetn),
        .s0_axis_aclk    (s0_axis_aclk),
        .s0_axis_tdata_i (s0_if.tdata),
        .s0_axis_tvalid_i(s0_if.tvalid),
        .s0_axis_tready_o(s0_if.tready),

        .s1_axis_tdata_i (s1_if.tdata),
        .s1_axis_tvalid_i(s1_if.tvalid),
        .s1_axis_tready_o(s1_if.tready),

        .m_axis_tready_i (m_if.tready),
        .m_axis_tvalid_o (m_if.tvalid),
        .m_axis_tdata_o  (m_if.tdata),

        .start_addr_reg (tb_start_addr_reg),
        .we_reg         (tb_we_reg)
    );

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
        tb_start_addr_reg = 32'd0;
        tb_we_reg         = 1'b1;
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
        tb_we_reg = 1'b0;
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
        tb_start_addr_reg = '0;
        tb_we_reg         = 1'b0;

        s0_axis_aresetn <= 1'b0;
        aresetn         <= 1'b0;
        repeat(20) @(posedge aclk);
        s0_axis_aresetn <= 1'b1;
        aresetn         <= 1'b1;

        s0_if.m_reset();
        s1_if.m_reset();
        repeat(40) @(posedge aclk);
    endtask

    task teardown();
        svunit_ut.teardown();
        s0_if.m_cb.tvalid <= 1'b0;
        s1_if.m_cb.tvalid <= 1'b0;
        repeat(10) @(posedge aclk);
    endtask

    `SVUNIT_TESTS_BEGIN
    `include "sg_int4_top_tests.sv"
    `SVUNIT_TESTS_END

endmodule
