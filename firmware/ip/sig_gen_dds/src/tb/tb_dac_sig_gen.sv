// testbench for big dac + xilinx dds + axis_sig_gen_v6

`timescale 1ns/1ps
`include "_qproc_defines.svh"

import axi_vip_pkg::*;
import axi_mst_0_pkg::*;

real T_SG_CLK   = 1.162;  // Half Clock Period for Signal Gens (430MHz)
real T_SCLK     = 5.0;    // Half Clock Period for PS & AXI (100MHz)

module tb();

// -----------------------------------------------------------------------
// DUT generics
// -----------------------------------------------------------------------
parameter N                 = 10; // Envelope Table Memory Size (in 2**N words)
parameter N_DDS             = 16; // Number of parallel DDS blocks.

// True: Generate DDS for Envelope Upconversion. 
// False: Remove DDS for Baseband Envelope only
parameter GEN_DDS           = "TRUE"; 

// COMPLEX: Allow Complex Envelope generation. 
// REAL: Allow only Real envelope generation
parameter ENVELOPE_TYPE     = "COMPLEX";

// for BIG DAC
parameter BITS              = DDS*16 - 1; // each baby dac is 16 bits
parameter N_DAC             = N_DDS;      // same as number of DDS in parallel


// -----------------------------------------------------------------------
// VIP Agents
// -----------------------------------------------------------------------
axi_mst_0_mst_t axi_mst_sg_agent;

// AXI Master VIP variables
xil_axi_prot_t  prot        = 0;
reg[31:0]       data_wr     = 32'h12345678;
xil_axi_resp_t  resp;

// AXI VIP master address
xil_axi_ulong   SG_ADDR_START_ADDR = 32'h40000000; // 0 define base addr
xil_axi_ulong   SG_ADDR_WE         = 32'h40000004; // 1 

// -----------------------------------------------------------------------
// Clock Generation
// -----------------------------------------------------------------------
logic           s_ps_dma_aclk, s_ps_dma_aresetn;
logic           sg_clk, rst_ni;

initial begin
    s_ps_dma_aclk = 1'b0;
    forever #(T_SCLK*1.0ns) s_ps_dma_aclk = ~s_ps_dma_aclk;
end

initial begin
    sg_clk = 1'b0;
    forever #(T_SG_CLK*1.0ns) sg_clk = ~sg_clk;
end

initial begin
    s_ps_dma_aresetn = 1'b0;
    rst_ni           = 1'b0;
    repeat (16) @(posedge s_ps_dma_aclk);
    s_ps_dma_aresetn = 1'b1;
    repeat (16) @(posedge sg_clk);
    rst_ni           = 1'b1;
  end

// -----------------------------------------------------------------------
// Signal Generator
// -----------------------------------------------------------------------

// signal generator s0_axis interface
wire [31:0]     s0_axis_sg_tdata;
wire            s0_axis_sg_tvalid;
logic           s0_axis_sg_tready;

// signal generator s1_axis interface
logic           rst_nt;
logic           sg_clk;

wire [159:0]    s1_axis_sg_tdata;
wire            s1_axis_sg_tvalid;
wire            s1_axis_sg_tready;

// DAC data in
logic [N_DDS*16-1:0]    m_axis_sg_tdata;
logic                   m_axis_sg_tready;
logic                   m_axis_sg_tvalid;
// signal generator s_axi interface
reg             s_axi_aclk;
reg             s_axi_aresetn;

// Read Address Channel (AR)
wire [5:0]      s_axi_sg_araddr;    // read address
wire [2:0]      s_axi_sg_arprot;    // read protection type
wire            s_axi_sg_arready;   // read address ready
wire            s_axi_sg_arvalid;   // read address valid

// Write Address Channel (AW)
wire [5:0]      s_axi_sg_awaddr;    // write address
wire [2:0]      s_axi_sg_awprot;    // write protection type
wire            s_axi_sg_awready;   // write address ready
wire            s_axi_sg_awvalid;   // write address valid

// Write Response Channel (B)
wire            s_axi_sg_bready;    // Write Response Ready
wire            s_axi_sg_bvalid;    // Write Response Valid
wire [1:0]      s_axi_sg_bresp;     // Write Response

// Read Data Channel (R)
wire [31:0]     s_axi_sg_rdata;     // Read Data
wire            s_axi_sg_rready;    // Read Data Ready
wire  [1:0]     s_axi_sg_rresp;     // Read Response
wire            s_axi_sg_rvalid;    // Read Valid

// Write Data Channel (W)
wire [31:0]     s_axi_sg_wdata;     // Write Data
wire            s_axi_sg_wready;    // Write Data Ready
wire [3:0]      s_axi_sg_wstrb;     // Write Strobe
wire            s_axi_sg_wvalid;    // Write Valid

axi_mst_0 u_axi_mst_sg_0 (
    .aclk           (s_ps_dma_aclk    ),
    .aresetn        (s_ps_dma_aresetn ),
    .m_axi_araddr   (s_axi_araddr     ),
    .m_axi_arprot   (s_axi_arprot     ),
    .m_axi_awprot   (s_axi_sg_awprot  ),
    .m_axi_awready  (s_axi_sg_awready ),
    .m_axi_awvalid  (s_axi_sg_awvalid ),
    .m_axi_bready   (s_axi_sg_bready  ),
    .m_axi_bresp    (s_axi_sg_bresp   ),
    .m_axi_bvalid   (s_axi_sg_bvalid  ),
    .m_axi_rdata    (s_axi_sg_rdata   ),
    .m_axi_rready   (s_axi_sg_rready  ),
    .m_axi_rresp    (s_axi_sg_rresp   ),
    .m_axi_rvalid   (s_axi_sg_rvalid  ),
    .m_axi_wdata    (s_axi_sg_wdata   ),
    .m_axi_wready   (s_axi_sg_wready  ),
    .m_axi_wstrb    (s_axi_sg_wstrb   ),
    .m_axi_wvalid   (s_axi_sg_wvalid  )
);

axis_signal_gen_v6 #(
    .N              (N              ),
    .N_DDS          (N_DDS          ),
    .GEN_DDS        (GEN_DDS        ),
    .ENVELOPE_TYPE  (ENVELOPE_TYPE  ),
)

u_axis_signal_gen_v6_0 (
    // AXI Slave I/F for configuration.
    .s_axi_aclk     (s_ps_dma_aclk      ),
    .s_axi_aresetn  (s_ps_dma_aresetn   ),

    .s_axi_awaddr   (s_axi_sg_awaddr    ),
    .s_axi_awprot   (s_axi_sg_awprot    ),
    .s_axi_awvalid  (s_axi_sg_awvalid   ),
    .s_axi_awready  (s_axi_sg_awready   ),

    .s_axi_wdata    (s_axi_sg_wdata     ),
    .s_axi_wstrb    (s_axi_sg_wstrb     ),
    .s_axi_wvalid   (s_axi_sg_wvalid    ),
    .s_axi_wready   (s_axi_sg_wready    ),

    .s_axi_bresp    (s_axi_sg_bresp     ),
    .s_axi_bvalid   (s_axi_sg_bvalid    ),
    .s_axi_bready   (s_axi_sg_bready    ),

    .s_axi_araddr   (s_axi_sg_araddr    ),
    .s_axi_arprot   (s_axi_sg_arprot    ),
    .s_axi_arvalid  (s_axi_arvalid      ),
    .s_axi_arready  (s_axi_arready      ),

    .s_axi_rdata    (s_axi_sg_rdata     ),
    .s_axi_rresp    (s_axi_sg_rresp     ),
    .s_axi_rvalid   (s_axi_sg_rvalid    ),
    .s_axi_rready   (s_axi_rready       ),

    // AXIS Slave to load memory samples.
    .s0_axis_aclk       (s_ps_dma_aclk      ),
    .s0_axis_aresetn    (s_ps_dma_aresetn   ),
    .s0_axis_tdata      (s0_axis_sg_tdata   ),
    .s0_axis_tvalid     (s0_axis_sg_tvalid  ),
    .s0_axis_tready     (s0_axis_sg_tready  ),

    // s1_* and m_* reset/clock.
    .aclk               (sg_clk     ),
    .aresetn            (rst_ni     ),

    // AXIS Slave to queue waveforms.
    .s1_axis_tdata      (s1_axis_sg_tdata   ),
    .s1_axis_tvalid     (s1_axis_sg_tvalid  ),
    .s1_axis_tready     (s1_axis_sg_tready  ),

    // AXIS Master for output.
    .m_axis_tready      (m_axis_sg_tready   ),
    .m_axis_tvalid      (m_axis_sg_tvalid   ),
    .m_axis_tdata       (m_axis_sg_tdata    )
);

// -----------------------------------------------------------------------
// DAC
// -----------------------------------------------------------------------
real    dac_out[N_DAC];

dac_top #(
    .bits       (BITS   ),
    .N_DAC      (N_DAC  ),
) u_dac_top (
    .clk            (sg_clk),
    .s_axis_tdata   (m_axis_sg_tdata),
    .s_axis_tvalid  (m_axis_sg_tvalid),
    .dac_out        (dac_out),
)


//--------------------------------------
// TEST STIMULI
//--------------------------------------

initial begin
    // create agent
    axi_mst_sg_agent = new("axi_mst_sg_0 VIP Agent", tb.u_axi_mst_sg_0.inst.IF)
    // set tag for agent
    axi_mst_sg_agent.set_agent_tag("axi_mst_sg_0 VIP");
    // start agent
    axi_mst_sg_agent.start_master()

    $display("*** Start Test ***");

end





endmodule