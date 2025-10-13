// testbench for big dac + xilinx dds + axis_sig_gen_v6

`timescale 1ns/1ps

import axi_vip_pkg::*;
import axi_mst_0_pkg::*;

module tb_axis_signal_gen_v6_only;

    // ---------------------------------------------------------------------------
    // Clocks / reset
    // ---------------------------------------------------------------------------
    real T_SCLK   = 5.0;    // 100 MHz AXI/PS
    real T_SG_CLK = 0.833;  // 600 MHz SG

    logic s_ps_dma_aclk;
    logic sg_clk;
    logic rst_ni;

    initial begin
    s_ps_dma_aclk = 1'b0;
    #0.5ns;
    forever #(T_SCLK*1ns) s_ps_dma_aclk = ~s_ps_dma_aclk;
    end

    initial begin
    sg_clk = 1'b0;
    forever #(T_SG_CLK*1ns) sg_clk = ~sg_clk;
    end

    initial begin
    rst_ni = 1'b0;
    repeat (16) @(posedge s_ps_dma_aclk);
    rst_ni = 1'b1;
    end

    wire s_ps_dma_aresetn = rst_ni;

    // ---------------------------------------------------------------------------
    /* AXI-Lite wiring for the SG core */
    // ---------------------------------------------------------------------------
    wire  [5:0]  s_axi_sg_araddr;
    wire  [2:0]  s_axi_sg_arprot;
    wire         s_axi_sg_arready;
    wire         s_axi_sg_arvalid;
    wire  [5:0]  s_axi_sg_awaddr;
    wire  [2:0]  s_axi_sg_awprot;
    wire         s_axi_sg_awready;
    wire         s_axi_sg_awvalid;
    wire         s_axi_sg_bready;
    wire  [1:0]  s_axi_sg_bresp;
    wire         s_axi_sg_bvalid;
    wire  [31:0] s_axi_sg_rdata;
    wire         s_axi_sg_rready;
    wire  [1:0]  s_axi_sg_rresp;
    wire         s_axi_sg_rvalid;
    wire  [31:0] s_axi_sg_wdata;
    wire         s_axi_sg_wready;
    wire  [3:0]  s_axi_sg_wstrb;
    wire         s_axi_sg_wvalid;

    // AXI VIP master address map used in your original TB
    xil_axi_ulong SG_ADDR_START_ADDR = 32'h40000000; // 0
    xil_axi_ulong SG_ADDR_WE         = 32'h40000004; // 1

    // VIP master instance for SG AXI-Lite
    axi_mst_0 u_axi_mst_sg_0 (
    .aclk          (s_ps_dma_aclk    ),
    .aresetn       (s_ps_dma_aresetn ),
    .m_axi_araddr  (s_axi_sg_araddr  ),
    .m_axi_arprot  (s_axi_sg_arprot  ),
    .m_axi_arready (s_axi_sg_arready ),
    .m_axi_arvalid (s_axi_sg_arvalid ),
    .m_axi_awaddr  (s_axi_sg_awaddr  ),
    .m_axi_awprot  (s_axi_sg_awprot  ),
    .m_axi_awready (s_axi_sg_awready ),
    .m_axi_awvalid (s_axi_sg_awvalid ),
    .m_axi_bready  (s_axi_sg_bready  ),
    .m_axi_bresp   (s_axi_sg_bresp   ),
    .m_axi_bvalid  (s_axi_sg_bvalid  ),
    .m_axi_rdata   (s_axi_sg_rdata   ),
    .m_axi_rready  (s_axi_sg_rready  ),
    .m_axi_rresp   (s_axi_sg_rresp   ),
    .m_axi_rvalid  (s_axi_sg_rvalid  ),
    .m_axi_wdata   (s_axi_sg_wdata   ),
    .m_axi_wready  (s_axi_sg_wready  ),
    .m_axi_wstrb   (s_axi_sg_wstrb   ),
    .m_axi_wvalid  (s_axi_sg_wvalid  )
    );

    // ---------------------------------------------------------------------------
    // axis_signal_gen_v6 DUT (identical generics defaulted from your TB)
    // ---------------------------------------------------------------------------
    localparam int N     = 10;
    localparam int N_DDS = 16;

    logic   [31:0] sg_s0_axis_tdata;
    logic          sg_s0_axis_tvalid;
    wire           sg_s0_axis_tready;

    wire                   axis_sg_dac_tvalid;
    wire [N_DDS*16-1:0]    axis_sg_dac_tdata;
    wire                   axis_sg_dac_tready;

    assign axis_sg_dac_tready = 1'b1; // sink always ready

    axis_signal_gen_v6 #(
    .N             (N),
    .N_DDS         (N_DDS),
    .GEN_DDS       ("TRUE"),
    .ENVELOPE_TYPE ("COMPLEX")
    ) u_axis_signal_gen_v6_0 (
    // AXI-Lite config
    .s_axi_aclk     (s_ps_dma_aclk    ),
    .s_axi_aresetn  (s_ps_dma_aresetn ),
    .s_axi_araddr   (s_axi_sg_araddr  ),
    .s_axi_arprot   (s_axi_sg_arprot  ),
    .s_axi_arready  (s_axi_sg_arready ),
    .s_axi_arvalid  (s_axi_sg_arvalid ),
    .s_axi_awaddr   (s_axi_sg_awaddr  ),
    .s_axi_awprot   (s_axi_sg_awprot  ),
    .s_axi_awready  (s_axi_sg_awready ),
    .s_axi_awvalid  (s_axi_sg_awvalid ),
    .s_axi_bready   (s_axi_sg_bready  ),
    .s_axi_bresp    (s_axi_sg_bresp   ),
    .s_axi_bvalid   (s_axi_sg_bvalid  ),
    .s_axi_rdata    (s_axi_sg_rdata   ),
    .s_axi_rready   (s_axi_sg_rready  ),
    .s_axi_rresp    (s_axi_sg_rresp   ),
    .s_axi_rvalid   (s_axi_sg_rvalid  ),
    .s_axi_wdata    (s_axi_sg_wdata   ),
    .s_axi_wready   (s_axi_sg_wready  ),
    .s_axi_wstrb    (s_axi_sg_wstrb   ),
    .s_axi_wvalid   (s_axi_sg_wvalid  ),

    // s0: envelope table load
    .s0_axis_aclk   (s_ps_dma_aclk    ),
    .s0_axis_aresetn(s_ps_dma_aresetn ),
    .s0_axis_tdata  (sg_s0_axis_tdata ),
    .s0_axis_tvalid (sg_s0_axis_tvalid),
    .s0_axis_tready (sg_s0_axis_tready),

    // core clk/rst for s1/m
    .aresetn        (rst_ni),
    .aclk           (sg_clk),

    // s1: queue waveforms (left idle in this minimal TB)
    .s1_axis_tdata  ('0),
    .s1_axis_tvalid (1'b0),
    .s1_axis_tready (/* open */),

    // m: generated samples
    .m_axis_tready  (axis_sg_dac_tready),
    .m_axis_tvalid  (axis_sg_dac_tvalid),
    .m_axis_tdata   (axis_sg_dac_tdata)
    );

    // Optional debug fan-out of m_axis samples (no functional impact)
    logic signed [15:0] axis_sg_dac_tdata_dbg [0:N_DDS-1];
    always @* begin
    for (int i=0;i<N_DDS;i++) axis_sg_dac_tdata_dbg[i] = axis_sg_dac_tdata[16*i +: 16];
    end

    // ---------------------------------------------------------------------------
    // AXI VIP master agent + basic run
    // ---------------------------------------------------------------------------
    axi_mst_0_mst_t axi_mst_sg_agent;
    xil_axi_prot_t  prot = 0;
    xil_axi_resp_t  resp;
    reg [31:0]      data_wr;

    initial begin
    axi_mst_sg_agent = new("axi_mst_sg_0 VIP Agent", tb_axis_signal_gen_v6_only.u_axi_mst_sg_0.inst.IF);
    axi_mst_sg_agent.set_agent_tag("axi_mst_sg_0 VIP");
    axi_mst_sg_agent.start_master();

    // Wait for reset release
    @(posedge s_ps_dma_aclk);
    wait (s_ps_dma_aresetn);

    // Load envelope table (reuses your exact flow)
    sg_load_mem("test_basic_pulses");

    // Let the DUT run for a while
    #20us;

    $display("*** axis_signal_gen_v6-only test done ***");
    $finish;
    end

    // ---------------------------------------------------------------------------
    // Task: load envelope table over s0 (identical handshake/flow to your TB)
    // ---------------------------------------------------------------------------
    task sg_load_mem(string test_name);
    string sg_file;
    int fd, vali, valq;
    bit signed [15:0] ii, qq;

    $display("### %t - Task sg_load_mem() start ###", $realtime());

    sg_s0_axis_tvalid = 0;
    sg_s0_axis_tdata  = 0;

    // start_addr = 0
    data_wr = 0;
    axi_mst_sg_agent.AXI4LITE_WRITE_BURST(SG_ADDR_START_ADDR, prot, data_wr, resp);
    #100ns;

    // we = 1
    data_wr = 1;
    axi_mst_sg_agent.AXI4LITE_WRITE_BURST(SG_ADDR_WE, prot, data_wr, resp);
    #100ns;

    // File path is the same relative path you use
    sg_file = {"../../../../src/tb/", test_name, "/sg_0.mem"};
    fd = $fopen(sg_file,"r");

    // Wait for DUT ready
    wait (sg_s0_axis_tready);

    // Stream I/Q pairs
    while ($fscanf(fd, "%d,%d", vali, valq) == 2) begin
        ii = vali;
        qq = valq;
        @(posedge s_ps_dma_aclk);
        sg_s0_axis_tvalid = 1'b1;
        sg_s0_axis_tdata  = {qq, ii};
    end
    $fclose(fd);

    @(posedge s_ps_dma_aclk);
    sg_s0_axis_tvalid = 1'b0;

    $display("### %t - Task sg_load_mem() end ###", $realtime());
    endtask

endmodule