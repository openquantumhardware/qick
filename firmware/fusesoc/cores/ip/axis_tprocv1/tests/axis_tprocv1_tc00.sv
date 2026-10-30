// ============================================================================
// File: axis_tprocv1_tc00.sv
// Description: SVUnit testbench top-level for axis_tprocv1.
//
// Focus: the AXI-Lite / data-memory subsystem (axi_slv_custom + dmem +
// bram_tdp).  The tProcessor core is held idle (no program / start low) so the
// tests exercise the register file and the data-memory access paths:
//
//   Register map (axi_slv_custom, byte-addressed, word-based decode):
//     0x00  reg0  START_SRC_REG  : bit0
//     0x04  reg1  START_REG      : bit0
//     0x08  reg2  MEM_MODE_REG   : bit0 (0=AXIS read, 1=AXIS write)
//     0x0C  reg3  MEM_START_REG  : bit0
//     0x10  reg4  MEM_ADDR_REG   : [DMEM_N-1:0]
//     0x14  reg5  MEM_LEN_REG    : [DMEM_N-1:0]
//
//   Data-memory single-access window:
//     byte >= 0x100 (NREG=64 words) -> single read/write to DMEM.
//     AXI addr = (byte-0x100)/4 = DMEM word address.
//     Returns SLVERR while MEM_START_REG=1 (AXIS transfer in progress).
//
// Clock domains:
//   s_axi_aclk : AXI-Lite + dmem arbiter + BRAM port A
//   aclk       : tProcessor + BRAM port B
// ============================================================================
`include "svunit_defines.svh"
`include "svunit_assert_macros.svh"

module axis_tprocv1_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "axis_tprocv1_ut";
    svunit_testcase svunit_ut;

    // =========================================================================
    // Parameters
    // =========================================================================
    localparam real AXI_FREQ  = 100e6;
    localparam real ACLK_FREQ = 200e6;

    localparam int PMEM_N = 8;    // small program memory for sim
    localparam int DMEM_N = 8;    // small data memory for sim (256 words)

    localparam int AXI_DW = 32;
    localparam int AXI_AW = 16;   // need >= 0x100 + DMEM window
    localparam int DEPTH  = 2**DMEM_N;

    // Register byte addresses
    localparam logic [AXI_AW-1:0] REG_START_SRC = 16'h00;
    localparam logic [AXI_AW-1:0] REG_START     = 16'h04;
    localparam logic [AXI_AW-1:0] REG_MEM_MODE  = 16'h08;
    localparam logic [AXI_AW-1:0] REG_MEM_START = 16'h0C;
    localparam logic [AXI_AW-1:0] REG_MEM_ADDR  = 16'h10;
    localparam logic [AXI_AW-1:0] REG_MEM_LEN   = 16'h14;

    // Data-memory window base (NREG=64 words = 256 bytes)
    localparam int NREG          = 64;
    localparam logic [AXI_AW-1:0] DMEM_BASE = 16'h100;  // NREG*4

    // AXI response codes
    localparam logic [1:0] RESP_OKAY   = 2'b00;
    localparam logic [1:0] RESP_SLVERR = 2'b10;

    // =========================================================================
    // Clocks & Resets
    // =========================================================================
    logic s_axi_aclk    = 1'b0;
    logic s_axi_aresetn = 1'b1;
    logic aclk          = 1'b0;
    logic aresetn       = 1'b1;

    // =========================================================================
    // Interfaces
    // =========================================================================
    axi4_lite_if #(
        .DATA_WIDTH (AXI_DW),
        .ADDR_WIDTH (AXI_AW)
    ) s_axi (
        .aclk    (s_axi_aclk),
        .aresetn (s_axi_aresetn)
    );

    // dmem AXIS write (s0) and read (m0): 32-bit, s_axi_aclk domain
    axi4_stream_if #(.TDATA_WIDTH(32), .HAS_TSTRB(1'b0)) s0_axis_if (
        .aclk(s_axi_aclk), .aresetn(s_axi_aresetn));
    axi4_stream_if #(.TDATA_WIDTH(32), .HAS_TSTRB(1'b0)) m0_axis_if (
        .aclk(s_axi_aclk), .aresetn(s_axi_aresetn));

    // tProc inputs s1..s4 (64-bit) and outputs m1..m8 (160-bit), aclk domain
    axi4_stream_if #(.TDATA_WIDTH(64)) s1_if (.aclk(aclk), .aresetn(aresetn));
    axi4_stream_if #(.TDATA_WIDTH(64)) s2_if (.aclk(aclk), .aresetn(aresetn));
    axi4_stream_if #(.TDATA_WIDTH(64)) s3_if (.aclk(aclk), .aresetn(aresetn));
    axi4_stream_if #(.TDATA_WIDTH(64)) s4_if (.aclk(aclk), .aresetn(aresetn));
    axi4_stream_if #(.TDATA_WIDTH(160)) m1_if (.aclk(aclk), .aresetn(aresetn));
    axi4_stream_if #(.TDATA_WIDTH(160)) m2_if (.aclk(aclk), .aresetn(aresetn));
    axi4_stream_if #(.TDATA_WIDTH(160)) m3_if (.aclk(aclk), .aresetn(aresetn));
    axi4_stream_if #(.TDATA_WIDTH(160)) m4_if (.aclk(aclk), .aresetn(aresetn));
    axi4_stream_if #(.TDATA_WIDTH(160)) m5_if (.aclk(aclk), .aresetn(aresetn));
    axi4_stream_if #(.TDATA_WIDTH(160)) m6_if (.aclk(aclk), .aresetn(aresetn));
    axi4_stream_if #(.TDATA_WIDTH(160)) m7_if (.aclk(aclk), .aresetn(aresetn));
    axi4_stream_if #(.TDATA_WIDTH(160)) m8_if (.aclk(aclk), .aresetn(aresetn));

    // =========================================================================
    // Program memory model (idle: returns "end"-like instruction)
    // =========================================================================
    logic [PMEM_N-1:0] pmem_addr;
    logic [63:0]       pmem_do;
    // Drive a benign program word (high half = 0x3F000000 -> "end" per driver)
    assign pmem_do = 64'h3F000000_00000000;

    // =========================================================================
    // tProc control
    // =========================================================================
    logic start = 1'b0;

    // =========================================================================
    // Clock generators
    // =========================================================================
    clk_gen #(.FREQ (AXI_FREQ))  u_clk_axi  (.i_enable(1'b1), .o_clk(s_axi_aclk));
    clk_gen #(.FREQ (ACLK_FREQ)) u_clk_aclk (.i_enable(1'b1), .o_clk(aclk));

    // =========================================================================
    // Waveform dump
    // =========================================================================
    initial begin
        $dumpfile("axis_tprocv1.vcd");
        $dumpvars();
    end

    // =========================================================================
    // DUT (flat AXIS ports wired to interface instances)
    // =========================================================================
    axis_tprocv1 #(
        .PMEM_N (PMEM_N),
        .DMEM_N (DMEM_N)
    ) dut (
        // AXI-Lite
        .s_axi_aclk    (s_axi_aclk),
        .s_axi_aresetn (s_axi_aresetn),
        .s_axi_awaddr  ({{(32-AXI_AW){1'b0}}, s_axi.awaddr}),
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
        .s_axi_araddr  ({{(32-AXI_AW){1'b0}}, s_axi.araddr}),
        .s_axi_arprot  (s_axi.arprot),
        .s_axi_arvalid (s_axi.arvalid),
        .s_axi_arready (s_axi.arready),
        .s_axi_rdata   (s_axi.rdata),
        .s_axi_rresp   (s_axi.rresp),
        .s_axi_rvalid  (s_axi.rvalid),
        .s_axi_rready  (s_axi.rready),
        // dmem AXIS write (s0)
        .s0_axis_aclk    (s_axi_aclk),
        .s0_axis_aresetn (s_axi_aresetn),
        .s0_axis_tdata   (s0_axis_if.tdata),
        .s0_axis_tlast   (s0_axis_if.tlast),
        .s0_axis_tvalid  (s0_axis_if.tvalid),
        .s0_axis_tready  (s0_axis_if.tready),
        // dmem AXIS read (m0)
        .m0_axis_aclk    (s_axi_aclk),
        .m0_axis_aresetn (s_axi_aresetn),
        .m0_axis_tdata   (m0_axis_if.tdata),
        .m0_axis_tlast   (m0_axis_if.tlast),
        .m0_axis_tvalid  (m0_axis_if.tvalid),
        .m0_axis_tready  (m0_axis_if.tready),
        // tProc domain
        .aclk      (aclk),
        .aresetn   (aresetn),
        .start     (start),
        .pmem_addr (pmem_addr),
        .pmem_do   (pmem_do),
        // tProc slave inputs
        .s1_axis_tdata (s1_if.tdata), .s1_axis_tvalid(s1_if.tvalid), .s1_axis_tready(s1_if.tready),
        .s2_axis_tdata (s2_if.tdata), .s2_axis_tvalid(s2_if.tvalid), .s2_axis_tready(s2_if.tready),
        .s3_axis_tdata (s3_if.tdata), .s3_axis_tvalid(s3_if.tvalid), .s3_axis_tready(s3_if.tready),
        .s4_axis_tdata (s4_if.tdata), .s4_axis_tvalid(s4_if.tvalid), .s4_axis_tready(s4_if.tready),
        // tProc master outputs
        .m1_axis_tdata (m1_if.tdata), .m1_axis_tvalid(m1_if.tvalid), .m1_axis_tready(m1_if.tready),
        .m2_axis_tdata (m2_if.tdata), .m2_axis_tvalid(m2_if.tvalid), .m2_axis_tready(m2_if.tready),
        .m3_axis_tdata (m3_if.tdata), .m3_axis_tvalid(m3_if.tvalid), .m3_axis_tready(m3_if.tready),
        .m4_axis_tdata (m4_if.tdata), .m4_axis_tvalid(m4_if.tvalid), .m4_axis_tready(m4_if.tready),
        .m5_axis_tdata (m5_if.tdata), .m5_axis_tvalid(m5_if.tvalid), .m5_axis_tready(m5_if.tready),
        .m6_axis_tdata (m6_if.tdata), .m6_axis_tvalid(m6_if.tvalid), .m6_axis_tready(m6_if.tready),
        .m7_axis_tdata (m7_if.tdata), .m7_axis_tvalid(m7_if.tvalid), .m7_axis_tready(m7_if.tready),
        .m8_axis_tdata (m8_if.tdata), .m8_axis_tvalid(m8_if.tvalid), .m8_axis_tready(m8_if.tready)
    );

    // =========================================================================
    // Register / memory access helpers (via axi4_lite_if tasks)
    // =========================================================================
    task automatic reg_write(input logic [AXI_AW-1:0] addr, input logic [AXI_DW-1:0] data);
        s_axi.axi_write(addr, data);
    endtask

    task automatic reg_read(input logic [AXI_AW-1:0] addr, output logic [AXI_DW-1:0] data);
        s_axi.axi_read(addr, data);
    endtask

    // Single-access DMEM write/read through the upper AXI window.
    // word_addr is the DMEM word index (driver: array[word_addr + NREG]).
    task automatic dmem_single_write(input int word_addr, input logic [AXI_DW-1:0] data);
        s_axi.axi_write(DMEM_BASE + AXI_AW'(word_addr*4), data);
    endtask

    task automatic dmem_single_read(input int word_addr, output logic [AXI_DW-1:0] data);
        s_axi.axi_read(DMEM_BASE + AXI_AW'(word_addr*4), data);
    endtask

    // Variants that also capture the AXI response (for SLVERR checks).
    // NOTE: requires axi4_lite_if to expose the response; if not, see notes.
    task automatic dmem_single_read_resp(
        input  int                 word_addr,
        output logic [AXI_DW-1:0]  data,
        output logic [1:0]         resp
    );
        s_axi.axi_read(DMEM_BASE + AXI_AW'(word_addr*4), data);
        resp = s_axi.rresp;   // sampled response
    endtask

    // =========================================================================
    // SVUnit
    // =========================================================================
    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        start <= 1'b0;
        // Idle all tProc AXIS inputs / accept all outputs
        s1_if.m_cb.tvalid <= 1'b0; s2_if.m_cb.tvalid <= 1'b0;
        s3_if.m_cb.tvalid <= 1'b0; s4_if.m_cb.tvalid <= 1'b0;
        m1_if.s_cb.tready <= 1'b1; m2_if.s_cb.tready <= 1'b1;
        m3_if.s_cb.tready <= 1'b1; m4_if.s_cb.tready <= 1'b1;
        m5_if.s_cb.tready <= 1'b1; m6_if.s_cb.tready <= 1'b1;
        m7_if.s_cb.tready <= 1'b1; m8_if.s_cb.tready <= 1'b1;
        // dmem AXIS idle
        s0_axis_if.m_cb.tvalid <= 1'b0;
        m0_axis_if.s_cb.tready <= 1'b0;
        // Reset both domains
        s_axi_aresetn = 1'b0;
        aresetn       = 1'b0;
        repeat(20) @(posedge s_axi_aclk);
        s_axi_aresetn = 1'b1;
        aresetn       = 1'b1;
        // Init AXI master to idle
        s_axi.reset();
        repeat(20) @(posedge s_axi_aclk);
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    // Global timeout
    initial begin
        #50_000_000;
        $display("INFO: Global timeout reached");
        $finish;
    end

    // =========================================================================
    // Test cases
    // =========================================================================
    `SVUNIT_TESTS_BEGIN
    `include "axis_tprocv1_tests.sv"
    `SVUNIT_TESTS_END

endmodule
