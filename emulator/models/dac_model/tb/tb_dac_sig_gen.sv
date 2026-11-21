// testbench for big dac + xilinx dds + axis_sig_gen_v6

`timescale 1ns/1ps
// `include "_qproc_defines.svh"

import axi_vip_pkg::*;
import axi_mst_0_pkg::*;

real T_SG_CLK   = 1.162;  // Half Clock Period for Signal Gens (430MHz)
real T_SCLK     = 5.0;    // Half Clock Period for PS & AXI (100MHz)

module tb();

//------------------------------------------------------------------------
// Define Test to run
//------------------------------------------------------------------------
string TEST_NAME = "test_basic_pulses";


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
parameter BITS              = N_DDS*16 - 1; // each baby dac is 16 bits
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
logic           sg_clk;
logic [4:0]     dac_fs_gen;
logic           dac_fs;

initial begin
  s_ps_dma_aclk = 1'b0;
  #0.5ns
  forever # (T_SCLK*1.0ns) s_ps_dma_aclk = ~s_ps_dma_aclk;
end

initial begin
   dac_fs_gen = 'd0;
   forever # (T_SG_CLK*1.0ns/N_DDS) dac_fs_gen = dac_fs_gen + 'd1;
end
assign dac_fs  = dac_fs_gen[0];
assign sg_clk  = dac_fs_gen[4];

//  RST Generation
logic rst_ni;
assign s_ps_dma_aresetn  = rst_ni;


// -----------------------------------------------------------------------
// Signal Generator
// -----------------------------------------------------------------------

// signal generator s0_axis interface
logic [31:0]     s0_axis_sg_tdata;
logic            s0_axis_sg_tvalid;
logic            s0_axis_sg_tready;

// signal generator s1_axis interface
// logic           rst_nt;
// logic           sg_clk;

logic [159:0]    s1_axis_sg_tdata;
logic            s1_axis_sg_tvalid;
logic            s1_axis_sg_tready;

// Waveform Fields.
reg      [31:0]         freq_r;
reg      [31:0]         phase_r;
reg      [15:0]         addr_r;
reg      [15:0]         gain_r;
reg      [15:0]         nsamp_r;
reg      [1:0]          outsel_r;
reg                     mode_r;
reg                     stdysel_r;
reg                     phrst_r;

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
   
    .m_axi_araddr   (s_axi_sg_araddr  ),
    .m_axi_arprot   (s_axi_sg_arprot  ),
    .m_axi_arvalid  (s_axi_sg_arvalid ),
    .m_axi_arready  (s_axi_sg_arready ),
 
    .m_axi_awaddr   (s_axi_sg_awaddr  ),
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
    .ENVELOPE_TYPE  (ENVELOPE_TYPE  )
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
    .s_axi_arvalid  (s_axi_sg_arvalid   ),
    .s_axi_arready  (s_axi_sg_arready   ),

    .s_axi_rdata    (s_axi_sg_rdata     ),
    .s_axi_rresp    (s_axi_sg_rresp     ),
    .s_axi_rvalid   (s_axi_sg_rvalid    ),
    .s_axi_rready   (s_axi_sg_rready    ),

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
assign s1_axis_sg_tdata = {{10{1'b0}},phrst_r,stdysel_r,mode_r,outsel_r,nsamp_r,{16{1'b0}},gain_r,{16{1'b0}},addr_r,phase_r,freq_r};
real    dac_out[N_DAC];

dac_top #(
    .bits       (BITS   ),
    .N_DAC      (N_DAC  )
) u_dac_top (
    .clk            (sg_clk),
    .s_axis_tdata   (m_axis_sg_tdata),
    .s_axis_tvalid  (m_axis_sg_tvalid),
    .dac_out        (dac_out)
);

// DAC interfaces
localparam  int DAC_BITS   = 16;
real        vref           = 1.0;      // reference voltage
real        expected_out [N_DAC];      // per lane expected output
integer     f_csv;
wire  [15:0]         dout_ii [0:N_DDS-1];
reg   [15:0]         dout_f;

assign m_axis_sg_tready = 1'b1;       // always ready/consume

// Write one line per lane for each valid vector from signal-gen
always @(posedge sg_clk) begin
  if (rst_ni && m_axis_sg_tvalid) begin
    for (int k = 0; k < N_DAC; k++) begin
      automatic int signed code = $signed(m_axis_sg_tdata[k*DAC_BITS +: DAC_BITS]);
      expected_out[k] = (vref * code) / (2.0 ** (DAC_BITS-1));

      // time_ns,channel,code,aout,expected
      $fwrite(f_csv, "%0t,%0d,%0d,%f,%f\n",
              $realtime, k, code, dac_out[k], expected_out[k]);
    end
  end
end


//--------------------------------------
// TEST STIMULI
//--------------------------------------
logic tb_load_mem, tb_load_mem_done;
logic tb_test_run_start, tb_test_run_done;
logic tb_test_read_start, tb_test_read_done;

logic tb_load_wave, tb_load_wave_done;
logic tb_load_out, tb_write_out;

wire s0_axis_sg_aclk = s_ps_dma_aclk;




initial begin
    // create agent
    axi_mst_sg_agent = new("axi_mst_sg_0 VIP Agent", tb.u_axi_mst_sg_0.inst.IF);
    // set tag for agent
    axi_mst_sg_agent.set_agent_tag("axi_mst_sg_0 VIP");
    // start agent
    axi_mst_sg_agent.start_master();

    $display("*** Start Test ***");

    // Reset Sequence
    s_axi_aresetn       <= 0;
    s_ps_dma_aresetn    <= 0;
    rst_ni              <= 0;

    #500;
    s_axi_aresetn       <= 1;
    s_ps_dma_aresetn    <= 1;
    rst_ni              <= 1;
    #1000

    $display("############################");
    $display("### Load data into Table ###");
    $display("############################");
    $display("t = %0t", $time);

    data_wr     = 0;
    axi_mst_sg_agent.AXI4LITE_WRITE_BURST(SG_ADDR_START_ADDR, prot, data_wr, resp);
    #100ns;

    data_wr     = 1;
    axi_mst_sg_agent.AXI4LITE_WRITE_BURST(SG_ADDR_WE, prot, data_wr, resp);
    #100ns;

    //Load Envelope table Memory
    tb_load_mem <= 1;
    wait(tb_load_mem_done);
    #100ns;

    data_wr = 0;
    axi_mst_sg_agent.AXI4LITE_WRITE_BURST(SG_ADDR_WE, prot, data_wr, resp);
    #100ns;

    $display("#######################");
    $display("### Queue Waveforms ###");
    $display("#######################");
    $display("t = %0t", $time);

    tb_load_wave    <= 1;
    tb_load_out     <= 1;
    wait(tb_load_wave_done);

    #10us;

    tb_write_out <= 0;

    #5us;

    $finish();
end

// Load pulse data into memory
initial begin
    int fd, vali, valq;
    bit signed [15:0]   ii, qq;

    s0_axis_sg_tvalid   <= 0;
    s0_axis_sg_tdata    <= 0;

    wait(tb_load_mem);

    fd = $fopen("./sg_mem", "r");

    wait(s0_axis_sg_tready);

    while($fscanf(fd, "%d", "%d", vali, valq) == 2) begin 
        $display("I,Q: %d, %d", vali,valq);
        ii = vali;
        qq = valq;
        @(posedge s0_axis_sg_aclk);
        s0_axis_sg_tvalid   <= 1;
        s0_axis_sg_tdata    <= {qq, ii};
    end

    @(posedge s0_axis_sg_aclk);
    s0_axis_sg_tvalid  <= 0;

    $fclose(fd);
    tb_load_mem_done    <= 1;
end

initial begin
    s1_axis_sg_tvalid   <= 0;
    freq_r              <= 0;
    phase_r             <= 0;
    addr_r              <= 0;
    gain_r              <= 0;
    nsamp_r             <= 0;
    outsel_r            <= 0;
    mode_r              <= 0;
    stdysel_r           <= 0;
    phrst_r             <= 0;

    wait (tb_load_wave);
    wait (s1_axis_sg_tready);

    @(posedge sg_clk);
    $display("t = %0t", $time);
    s1_axis_sg_tvalid <= 1;
    freq_r         <= freq_calc(0, N_DDS, 4);  // 120 MHz.
    phase_r        <= 0;
    addr_r         <= 22;
    gain_r         <= 12000;
    nsamp_r        <= 80;
    outsel_r       <= 0; // 0: prod, 1: dds, 2: mem
    mode_r         <= 0; // 0: nsamp, 1: periodic
    stdysel_r      <= 0; // 0: last, 1: zero.
    phrst_r        <= 0;

    #5us;

    @(posedge sg_clk);
    $display("t = %0t", $time);
    s1_axis_sg_tvalid <= 1;
    freq_r         <= freq_calc(0, N_DDS, 4);  // 120 MHz.
    phase_r        <= 0;
    addr_r         <= 22;
    gain_r         <= 12000;
    nsamp_r        <= 80;
    outsel_r       <= 1; // 0: prod, 1: dds, 2: mem
    mode_r         <= 0; // 0: nsamp, 1: periodic
    stdysel_r      <= 0; // 0: last, 1: zero.
    phrst_r        <= 0;

    #5us;

    @(posedge sg_clk);
    $display("t = %0t", $time);
    s1_axis_sg_tvalid <= 1;
    freq_r         <= freq_calc(0, N_DDS, 4);  // 120 MHz.
    phase_r        <= 0;
    addr_r         <= 22;
    gain_r         <= 12000;
    nsamp_r        <= 80;
    outsel_r       <= 2; // 0: prod, 1: dds, 2: mem
    mode_r         <= 0; // 0: nsamp, 1: periodic
    stdysel_r      <= 0; // 0: last, 1: zero.
    phrst_r        <= 0;

    #5us;

    @(posedge sg_clk);
    s1_axis_sg_tvalid <= 0;
    tb_load_wave_done <= 1;

end

initial begin
    int fd;
    int i;
    shortint real_d;

    // Output file.
    fd = $fopen("./sg_out.csv","w");

    // Data format.
    $fdisplay(fd, "valid, idx, real");

    wait (tb_write_out);

    while (tb_write_out) begin
        @(posedge sg_clk);
        for (i=0; i<N_DDS; i = i+1) begin
            real_d = dout_ii[i][15:0];
            $fdisplay(fd, "%d, %d, %d", m_axis_sg_tdata, i, real_d);
        end
    end

    $display("Closing file, t = %0t", $time);
    $fclose(fd);
end


// Function to compute frequency register.
function [31:0] freq_calc;
    input int fclk;
    input int ndds;
    input int f;
    
   // All input frequencies are in MHz.
   real fs,temp;
   fs = fclk*ndds;
   temp = f/fs*2**30;
   freq_calc = {int'(temp),2'b00};
endfunction


endmodule
