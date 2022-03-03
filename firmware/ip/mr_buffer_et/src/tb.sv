`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/19/2019 01:38:28 PM
// Design Name: 
// Module Name: tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

import axi_vip_pkg::*;
import axi_vip_0_pkg::*;
import axi4stream_vip_pkg::*;
import axi4stream_vip_0_pkg::*;
import axi4stream_vip_1_pkg::*;

module tb(
    );

// AXI signals.
reg aclk = 0;
reg aresetn;
reg trigger;
wire [31:0] m_axi_awaddr;
wire [2:0] m_axi_awprot;
wire m_axi_awvalid;
wire m_axi_awready;
wire [31:0] m_axi_wdata;
wire [3:0] m_axi_wstrb;
wire m_axi_wvalid;
wire m_axi_wready;
wire [1:0] m_axi_bresp;
wire m_axi_bvalid;
wire m_axi_bready;
wire [31:0] m_axi_araddr;
wire [2:0] m_axi_arprot;
wire m_axi_arvalid;
wire m_axi_arready;
wire [31:0] m_axi_rdata;
wire [1:0] m_axi_rresp;
wire m_axi_rvalid;
wire m_axi_rready;

// AXIS Master signals.
reg m_axis_aclk = 0;
reg m_axis_aresetn;
wire m_axis_tvalid;
wire m_axis_tready;
wire [7:0] m_axis_tdata;

// AXIS Slave signals.
reg s_axis_aclk = 0;
reg s_axis_aresetn;
wire s_axis_tready;
wire [31:0] s_axis_tdata;		
wire s_axis_tvalid;

axi4stream_transaction wr_transaction;
axi4stream_ready_gen ready_gen;

xil_axi_ulong addr_DW_CAPTURE_REG   = 32'h44A00000; // 0
xil_axi_ulong addr_DR_START_REG     = 32'h44A00004; // 1

xil_axi_prot_t  prot = 0;
reg[31:0]       data_wr=32'h01234567;
reg[31:0]       data_rd=32'h01234567;
xil_axi_resp_t  resp;

// AXI Master VIP.
axi_vip_0 axi_vip_i (
  .aclk(aclk),                    // input wire aclk
  .aresetn(aresetn),              // input wire aresetn
  .m_axi_awaddr(m_axi_awaddr),    // output wire [31 : 0] m_axi_awaddr
  .m_axi_awprot(m_axi_awprot),    // output wire [2 : 0] m_axi_awprot
  .m_axi_awvalid(m_axi_awvalid),  // output wire m_axi_awvalid
  .m_axi_awready(m_axi_awready),  // input wire m_axi_awready
  .m_axi_wdata(m_axi_wdata),      // output wire [31 : 0] m_axi_wdata
  .m_axi_wstrb(m_axi_wstrb),      // output wire [3 : 0] m_axi_wstrb
  .m_axi_wvalid(m_axi_wvalid),    // output wire m_axi_wvalid
  .m_axi_wready(m_axi_wready),    // input wire m_axi_wready
  .m_axi_bresp(m_axi_bresp),      // input wire [1 : 0] m_axi_bresp
  .m_axi_bvalid(m_axi_bvalid),    // input wire m_axi_bvalid
  .m_axi_bready(m_axi_bready),    // output wire m_axi_bready
  .m_axi_araddr(m_axi_araddr),    // output wire [31 : 0] m_axi_araddr
  .m_axi_arprot(m_axi_arprot),    // output wire [2 : 0] m_axi_arprot
  .m_axi_arvalid(m_axi_arvalid),  // output wire m_axi_arvalid
  .m_axi_arready(m_axi_arready),  // input wire m_axi_arready
  .m_axi_rdata(m_axi_rdata),      // input wire [31 : 0] m_axi_rdata
  .m_axi_rresp(m_axi_rresp),      // input wire [1 : 0] m_axi_rresp
  .m_axi_rvalid(m_axi_rvalid),    // input wire m_axi_rvalid
  .m_axi_rready(m_axi_rready)    // output wire m_axi_rready
);

// AXIS Master VIP.
axi4stream_vip_1 axis_mst_vip_i (
  .aclk(s_axis_aclk),                    // input wire aclk
  .aresetn(s_axis_aresetn),              // input wire aresetn
  .m_axis_tvalid(s_axis_tvalid),  // output wire [0 : 0] m_axis_tvalid
  .m_axis_tready(s_axis_tready),  // input wire [0 : 0] m_axis_tready
  .m_axis_tdata(s_axis_tdata)    // output wire [7 : 0] m_axis_tdata
);

// AXIS Slave VIP.
axi4stream_vip_0 axis_slv_vip_i (
  .aclk(m_axis_aclk),                    // input wire aclk
  .aresetn(m_axis_aresetn),              // input wire aresetn
  .s_axis_tvalid(m_axis_tvalid),  // input wire [0 : 0] s_axis_tvalid
  .s_axis_tready(m_axis_tready),  // output wire [0 : 0] s_axis_tready
  .s_axis_tdata(m_axis_tdata)    // input wire [31 : 0] s_axis_tdata
);

// Instantiate DUT.
mr_buffer_v1_0
        #(.NM(4), .N(4), .B(8))
        DUT (
		.trigger(trigger),
		.s00_axi_aclk(aclk),
		.s00_axi_aresetn(aresetn),
		.s00_axi_awaddr(m_axi_awaddr),
		.s00_axi_awprot(m_axi_awprot),
		.s00_axi_awvalid(m_axi_awvalid),
		.s00_axi_awready(m_axi_awready),
		.s00_axi_wdata(m_axi_wdata),
		.s00_axi_wstrb(m_axi_wstrb),
		.s00_axi_wvalid(m_axi_wvalid),
		.s00_axi_wready(m_axi_wready),
		.s00_axi_bresp(m_axi_bresp),
		.s00_axi_bvalid(m_axi_bvalid),
		.s00_axi_bready(m_axi_bready),
		.s00_axi_araddr(m_axi_araddr),
		.s00_axi_arprot(m_axi_arprot),
		.s00_axi_arvalid(m_axi_arvalid),
		.s00_axi_arready(m_axi_arready),
		.s00_axi_rdata(m_axi_rdata),
		.s00_axi_rresp(m_axi_rresp),
		.s00_axi_rvalid(m_axi_rvalid),
		.s00_axi_rready(m_axi_rready),
		.s00_axis_aclk(s_axis_aclk),
		.s00_axis_aresetn(s_axis_aresetn),
		.s00_axis_tready(s_axis_tready),
		.s00_axis_tdata(s_axis_tdata),
		.s00_axis_tstrb(),
		.s00_axis_tlast(),
		.s00_axis_tvalid(s_axis_tvalid),
		.m00_axis_aclk(m_axis_aclk),
		.m00_axis_aresetn(m_axis_aresetn),
		.m00_axis_tvalid(m_axis_tvalid),
		.m00_axis_tdata(m_axis_tdata),
		.m00_axis_tstrb(),
		.m00_axis_tlast(),
		.m00_axis_tready(m_axis_tready));

// Declare AXI master VIP agent.
axi_vip_0_mst_t mst_agent;

// Declare AXIS master VIP agent.
axi4stream_vip_1_mst_t axis_mst_agent;

// Declare AXIS slave VIP agent.
axi4stream_vip_0_slv_t axis_slv_agent;

initial begin
    // Create agentt.
    mst_agent       = new("axi master vip agent", axi_vip_i.inst.IF);
    axis_mst_agent  = new("axis master vip agent", axis_mst_vip_i.inst.IF);
    axis_slv_agent  = new("axis slave vip agent", axis_slv_vip_i.inst.IF);
    
    // Set tag for agent to ease debug.
    mst_agent.set_agent_tag("AXI Master VIP");
    axis_mst_agent.set_agent_tag("AXIS Master VIP");
    axis_slv_agent.set_agent_tag("AXIS Slave VIP");
    
    // Set print verbosity level.
    mst_agent.set_verbosity(400);
    axis_mst_agent.set_verbosity(400);
    axis_slv_agent.set_verbosity(400);
    
    /***************************************************************************************************
    * When bus is in idle, it must drive everything to 0.otherwise it will 
    * trigger false assertion failure from axi_protocol_chekcer
    ***************************************************************************************************/
    
    axis_mst_agent.vif_proxy.set_dummy_drive_type(XIL_AXI4STREAM_VIF_DRIVE_NONE);
    axis_slv_agent.vif_proxy.set_dummy_drive_type(XIL_AXI4STREAM_VIF_DRIVE_NONE);
    
    /* 
    DW_CAPTURE_REG : 1 bit.
    -> 0 : disable capture.
    -> 1 : enable capture.
 
    DR_START_REG	: 1 bit.
    -> 0 : stop.
    -> 1 : start.

	trigger			: 1 bit.
	-> 0 : wait.
	-> 1 : start capture.
    */
    
    // Start the agent.
    mst_agent.start_master();
    axis_mst_agent.start_master();
    axis_slv_agent.start_slave();
    
    // dready generator.
    ready_gen = axis_slv_agent.driver.create_ready("ready_gen");
    ready_gen.set_ready_policy(XIL_AXI4STREAM_READY_GEN_EVENTS);
    ready_gen.set_low_time(4);
    ready_gen.set_event_count(25);            

	trigger <= 0;
            
    // Reset sequence.
    aresetn = 0;
    m_axis_aresetn = 0;
    s_axis_aresetn = 0;
    #200;
    aresetn = 1;
    m_axis_aresetn = 1;
    s_axis_aresetn = 1;
    #200;
    
    // Write DW_CAPTURE_REG.
    data_wr = 1;
    mst_agent.AXI4LITE_WRITE_BURST(addr_DW_CAPTURE_REG,prot,data_wr,resp);
    #200;

	// Send data.
	fork
		gen_0(8,10);
	join_none
    
    #1000;

	// Trigger.
	trigger <= 1;
    
	// Send data.
	fork
		gen_0(8,0);
	join

	#1000
	trigger <= 0;
    
     // Write DW_CAPTURE_REG.
    data_wr = 0;
    mst_agent.AXI4LITE_WRITE_BURST(addr_DW_CAPTURE_REG,prot,data_wr,resp);
    #200;
    
    #1000;
    
     // Write DW_CAPTURE_REG.
    data_wr = 1;
    mst_agent.AXI4LITE_WRITE_BURST(addr_DW_CAPTURE_REG,prot,data_wr,resp);
    #200;
    
    #200;
    
     // Write DW_CAPTURE_REG.
    data_wr = 0;
    mst_agent.AXI4LITE_WRITE_BURST(addr_DW_CAPTURE_REG,prot,data_wr,resp);
    #200;
    
	// Send data.
	fork
		gen_0(16,10);
	join_none
    
    #100;
	trigger <= 1;
    
    #1000;    
    
     // Write DR_START_REG.
    data_wr = 1;
    mst_agent.AXI4LITE_WRITE_BURST(addr_DR_START_REG,prot,data_wr,resp);
    #200;
    
    // Write DR_START_REG.
    data_wr = 0;
    mst_agent.AXI4LITE_WRITE_BURST(addr_DR_START_REG,prot,data_wr,resp);
    #200;
    
    #2000;
    
    axis_slv_agent.driver.send_tready(ready_gen);
    
    // Write DR_START_REG.
    data_wr = 1;
    mst_agent.AXI4LITE_WRITE_BURST(addr_DR_START_REG,prot,data_wr,resp);
    #200;
    
    // Write DR_START_REG.
    data_wr = 0;
    mst_agent.AXI4LITE_WRITE_BURST(addr_DR_START_REG,prot,data_wr,resp);
    #200;
    
    #1000;    
end

// aclk.
always begin
    #10; aclk = ~aclk;
end    

//m_axis_aclk
always begin
    #4; m_axis_aclk = ~m_axis_aclk;
end

//s_axis_aclk
always begin
    #3; s_axis_aclk = ~s_axis_aclk;
end

task gen_0(input bit [31:0] cnt, input bit [31:0] delay);        
    // Create transaction.
    axi4stream_transaction wr_transaction;
    wr_transaction = axis_mst_agent.driver.create_transaction("Master 0 VIP write transaction");
    
    // Set transaction parameters.
    wr_transaction.set_xfer_alignment(XIL_AXI4STREAM_XFER_RANDOM);
    wr_transaction.set_delay(0);
    
    // Send transactions.
    for (int i=0; i < cnt; i++)
    begin
        WR_TRANSACTION_FAIL: assert(wr_transaction.randomize());
        axis_mst_agent.driver.send(wr_transaction);
    end
endtask    

endmodule
